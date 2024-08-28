defmodule MicWeb.OnboardingLive.QuestionFlow do
  require Logger
  alias MicWeb.Message

  def handle_language_selection(socket, language) do
    send(self(), {:set_language_preference, language})

    new_message = %Message{
      content: String.capitalize(Atom.to_string(language)),
      sender: :user,
      id: 0
    }

    send(self(), {:add_message, new_message})

    content =
      case language do
        :english -> "Perfect. Do you want me to communicate with you via text or voice?"
        :spanish -> "Perfecto. ¿Quieres que me comunique contigo por texto o voz?"
        :portuguese -> "Perfeito. Você quer que eu me comunique com você por texto ou voz?"
      end

    new_message = %Message{
      content: content,
      sender: :assistant,
      id: 0
    }

    send(self(), {:add_message, new_message})

    {:noreply, socket}
  end

  def handle_communication_preference(socket, preference) do
    send(self(), {:set_prefers_voice_chat, preference == :voice})
    language_preference = Mic.Chat.OpenAI.get_language_preference(socket.assigns.openai_pid)

    {message_content, prepended_user_message} =
      case {language_preference, preference} do
        {:english, :text} ->
          {"I'll communicate through text, thanks! What is your artist name?", "Text"}

        {:spanish, :text} ->
          {"Me comunicaré por texto, ¡gracias! ¿Cuál es tu nombre de artista?", "Texto"}

        {:portuguese, :text} ->
          {"Vou me comunicar por texto, obrigado! Qual é o seu nome artístico?", "Texto"}

        {:english, :voice} ->
          {"I'll communicate through voice, thanks! What is your artist name?", "Voice"}

        {:spanish, :voice} ->
          {"Me comunicaré por voz, ¡gracias! ¿Cuál es tu nombre de artista?", "Voz"}

        {:portuguese, :voice} ->
          {"Vou me comunicar por voz, obrigado! Qual é o seu nome artístico?", "Voz"}

        _ ->
          {"I'll communicate through text, thanks! What is your artist name?", "Text"}
      end

    if preference == :voice do
      case Mic.Chat.OpenAI.generate_speech(message_content) do
        {:ok, speech} when is_binary(speech) ->
          send(self(), {:audio_chunk, %{chunk: speech, socket_id: socket.id}})

        {:error, reason} ->
          Logger.error("TTS Error: #{inspect(reason)}")
      end
    end

    new_message = %Message{
      content: prepended_user_message,
      sender: :user,
      id: 0
    }

    send(self(), {:add_message, new_message})

    new_message = %Message{
      content: message_content,
      sender: :assistant,
      id: 0
    }

    send(self(), {:add_message, new_message})

    {:noreply, socket, %{current_question: :artist_name}}
  end

  def handle_user_response(socket, text) do
    profile_data = socket.assigns.profile_data

    updated_profile_data =
      case socket.assigns.current_question do
        :artist_name ->
          Map.put(profile_data, :artist_name, text)

        :genre ->
          Map.put(profile_data, :genre, text)

        :influences ->
          Map.put(profile_data, :influences, text)

        :aspirations ->
          Map.put(profile_data, :aspirations, text)

        :musical_beginnings ->
          Map.put(profile_data, :musical_beginnings, text)

        :spotify_bio ->
          if String.downcase(text) == "no" do
            Map.put(profile_data, :spotify_bio, nil)
          else
            Map.put(profile_data, :spotify_bio, text)
          end

        :music_education ->
          Map.put(profile_data, :music_education, text)

        :instruments_played ->
          Map.put(profile_data, :instruments_played, text)

        :significant_milestones ->
          Map.put(profile_data, :significant_milestones, text)

        :live_performances ->
          Map.put(profile_data, :live_performances, text)

        :country ->
          Map.put(profile_data, :country, text)

        :dob ->
          valid_date_struct = MicWeb.OnboardingLive.Helpers.generate_valid_dob_struct(text)
          Map.put(profile_data, :dob, valid_date_struct)

        :spotify_link ->
          Map.put(profile_data, :website_url, text)

        _ ->
          profile_data
      end

    artist_name = Map.get(updated_profile_data, :artist_name)

    {next_question, next_question_to_set} =
      get_next_question(socket.assigns.current_question, artist_name)

    language_preference =
      socket.assigns.language_preference || socket.assigns.saved_language_preference

    translated_question = translate_question(next_question, language_preference)
    response_detail = get_response_detail(socket.assigns.response_answer_detail)

    message_end =
      if next_question_to_set == :end do
        ""
      else
        ". \n\nALWAYS ANSWER IN #{Atom.to_string(language_preference)}. #{response_detail}"
      end

    full_question_for_ai = translated_question <> message_end

    send(self(), {:add_message, %Message{content: text, sender: :user, id: 0}})

    send(
      self(),
      {:add_message, %Message{content: translated_question, sender: :assistant, id: 0}}
    )

    if next_question_to_set == :end do
      Process.send_after(self(), :generate_profile, 0)
    end

    send(self(), :stop_loading)

    {:noreply, socket,
     %{
       last_user_submission: text,
       current_question: next_question_to_set,
       profile_data: updated_profile_data,
       ai_instruction: full_question_for_ai
     }}
  end

  def get_next_question(current_question, artist_name) do
    case current_question do
      :artist_name ->
        {"What's your music genre, " <> artist_name <> "?", :genre}

      :genre ->
        {"Are there any specific musicians or artists who have inspired or influenced your musical style, " <>
           artist_name <> "?", :influences}

      :influences ->
        {"When did your passion for music first begin, " <> artist_name <> "?",
         :musical_beginnings}

      :musical_beginnings ->
        {"What are your future goals or aspirations in music, " <> artist_name <> "?",
         :aspirations}

      :aspirations ->
        {"Did you have any formal training or education in music or are you self-taught, " <>
           artist_name <> "?", :music_education}

      :music_education ->
        {"What instruments do you play, and how did you learn to play them, " <>
           artist_name <> "?", :instruments_played}

      :instruments_played ->
        {"Can you share any significant milestones or achievements in your musical career so far, " <>
           artist_name <> "?", :significant_milestones}

      :significant_milestones ->
        {"If you have a biography in your Spotify page, can you copy and paste it here please " <>
           artist_name <> ", if not just type no", :spotify_bio}

      :spotify_bio ->
        {"Have you ever performed in front of an audience? If yes, what was that experience like, " <>
           artist_name <> "?", :live_performances}

      :live_performances ->
        {"What's your Spotify artist page link? It should look like https://open.spotify.com/artist/4q3ewBCX7sLwd24euuV69X",
         :spotify_link}

      :spotify_link ->
        {"Which country are you from, " <> artist_name <> "?", :country}

      :country ->
        {"What's your date of birth, " <> artist_name <> "?", :dob}

      :dob ->
        {"Thank you for creating your profile, " <>
           artist_name <> ". You will be redirected to the home page shortly.", :end}

      _ ->
        {"", nil}
    end
  end

  defp get_response_detail(response_answer_detail) do
    case response_answer_detail do
      :super_brief -> "KEEP YOUR ANSWER EXTREMELY BRIEF AND DIRECT."
      :brief -> "KEEP YOUR ANSWER BRIEF AND DIRECT."
      :detailed -> "MAKE SURE YOUR ANSWER IS DETAILED."
      _ -> ""
    end
  end

  def translate_question(question, language) do
    case language do
      :spanish -> translate_to_spanish(question)
      :portuguese -> translate_to_portuguese(question)
      _ -> question
    end
  end

  defp translate_to_spanish(question) do
    case question do
      "What's your music genre, " <> name ->
        "¿Cuál es tu género musical, #{name}?"

      "Are there any specific musicians or artists who have inspired or influenced your musical style, " <>
          name ->
        "¿Hay músicos o artistas específicos que hayan inspirado o influenciado tu estilo musical, #{name}?"

      "When did your passion for music first begin, " <> name ->
        "¿Cuándo comenzó tu pasión por la música, #{name}?"

      "What are your future goals or aspirations in music, " <> name ->
        "¿Cuáles son tus metas o aspiraciones futuras en la música, #{name}?"

      "Did you have any formal training or education in music or are you self-taught, " <> name ->
        "¿Has tenido alguna formación o educación formal en música o eres autodidacta, #{name}?"

      "What instruments do you play, and how did you learn to play them, " <> name ->
        "¿Qué instrumentos tocas y cómo aprendiste a tocarlos, #{name}?"

      "Can you share any significant milestones or achievements in your musical career so far, " <>
          name ->
        "¿Puedes compartir algún hito o logro significativo en tu carrera musical hasta ahora, #{name}?"

      "If you have a biography in your Spotify page, can you copy and paste it here please " <>
          rest ->
        case String.split(rest, ",", parts: 2) do
          [name, " if not just type no"] ->
            "Si tienes una biografía en tu página de Spotify, ¿puedes copiarla y pegarla aquí por favor, #{name}? Si no, simplemente escribe 'no'"

          [name] ->
            "Si tienes una biografía en tu página de Spotify, ¿puedes copiarla y pegarla aquí por favor, #{name}? Si no, simplemente escribe 'no'"
        end

      "Have you ever performed in front of an audience? If yes, what was that experience like, " <>
          name ->
        "¿Alguna vez has actuado frente a una audiencia? Si es así, ¿cómo fue esa experiencia, #{name}?"

      "Which country are you from, " <> name ->
        "¿De qué país eres, #{name}?"

      "What's your date of birth, " <> name ->
        "¿Cuál es tu fecha de nacimiento, #{name}?"

      "Thank you for creating your profile, " <> rest ->
        case String.split(rest, ". ", parts: 2) do
          [name, "You will be redirected to the home page shortly."] ->
            "Gracias por crear tu perfil, #{name}. Serás redirigido a la página de inicio en breve."

          [name] ->
            "Gracias por crear tu perfil, #{name}. Serás redirigido a la página de inicio en breve."
        end

      "What's your Spotify artist page link? It should look like https://open.spotify.com/artist/4q3ewBCX7sLwd24euuV69X" ->
        "¿Cuál es el enlace de tu página de artista en Spotify? Debería verse como https://open.spotify.com/artist/4q3ewBCX7sLwd24euuV69X"

      _ ->
        question
    end
  end

  defp translate_to_portuguese(question) do
    case question do
      "What's your music genre, " <> name ->
        "Qual é o seu gênero musical, #{name}?"

      "Are there any specific musicians or artists who have inspired or influenced your musical style, " <>
          name ->
        "Existem músicos ou artistas específicos que inspiraram ou influenciaram seu estilo musical, #{name}?"

      "When did your passion for music first begin, " <> name ->
        "Quando sua paixão pela música começou, #{name}?"

      "What are your future goals or aspirations in music, " <> name ->
        "Quais são seus objetivos ou aspirações futuras na música, #{name}?"

      "Did you have any formal training or education in music or are you self-taught, " <> name ->
        "Você teve algum treinamento formal ou educação em música ou é autodidata, #{name}?"

      "What instruments do you play, and how did you learn to play them, " <> name ->
        "Quais instrumentos você toca e como aprendeu a tocá-los, #{name}?"

      "Can you share any significant milestones or achievements in your musical career so far, " <>
          name ->
        "Você pode compartilhar marcos ou conquistas significativas em sua carreira musical até agora, #{name}?"

      "If you have a biography in your Spotify page, can you copy and paste it here please " <>
          rest ->
        case String.split(rest, ",", parts: 2) do
          [name, " if not just type no"] ->
            "Se você tem uma biografia na sua página do Spotify, pode copiá-la e colá-la aqui por favor, #{name}? Se não, apenas escreva 'não'"

          [name] ->
            "Se você tem uma biografia na sua página do Spotify, pode copiá-la e colá-la aqui por favor, #{name}? Se não, apenas escreva 'não'"
        end

      "Have you ever performed in front of an audience? If yes, what was that experience like, " <>
          name ->
        "Você já se apresentou na frente de uma plateia? Se sim, como foi essa experiência, #{name}?"

      "Which country are you from, " <> name ->
        "De qual país você é, #{name}?"

      "What's your date of birth, " <> name ->
        "Qual é sua data de nascimento, #{name}?"

      "Thank you for creating your profile, " <> rest ->
        [name, ". You will be redirected to the home page shortly."] = String.split(rest, ".")

        "Obrigado por criar seu perfil, #{name}. Você será redirecionado para a página inicial em breve."

      "What's your Spotify artist page link? It should look like https://open.spotify.com/artist/4q3ewBCX7sLwd24euuV69X" ->
        "Qual é o link da sua página de artista no Spotify? Deve ser parecido com https://open.spotify.com/artist/4q3ewBCX7sLwd24euuV69X"

      _ ->
        question
    end
  end
end
