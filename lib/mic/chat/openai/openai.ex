defmodule Mic.Chat.OpenAI do
  use GenServer
  alias MicWeb.Message
  require Logger

  @type init_settings :: %{messages: [], keep_context: boolean()}
  @type state :: %{messages: [], settings: init_settings()}

  @impl true
  @spec init(state) :: {:ok, any}
  def init(opts) do
    {:ok, opts}
  end

  defp new_msg(m) do
    %ExOpenAI.Components.ChatCompletionRequestUserMessage{
      content: m,
      role: :user
    }
  end

  @spec role(String.t()) :: atom()
  defp role(r) when is_binary(r), do: String.to_atom(r)
  @spec role(atom()) :: atom()
  defp role(r) when is_atom(r), do: r

  @spec to_domain(ExOpenAI.Components.ChatCompletionResponseMessage.t()) :: Message.t()
  defp to_domain(msg) do
    %Message{
      content: msg.content,
      sender: role(msg.role),
      id: 0
    }
  end

  @spec from_domain(Message.t()) ::
          ExOpenAI.Components.ChatCompletionRequestUserMessage.t()
          | ExOpenAI.Components.ChatCompletionRequestAssistantMessage.t()
          | ExOpenAI.Components.ChatCompletionRequestSystemMessage.t()
  defp from_domain(msg) do
    case msg.sender do
      :user ->
        %ExOpenAI.Components.ChatCompletionRequestUserMessage{
          content: msg.content,
          role: :user
        }

      :assistant ->
        %ExOpenAI.Components.ChatCompletionRequestAssistantMessage{
          content: msg.content,
          role: :assistant
        }

      :system ->
        %ExOpenAI.Components.ChatCompletionRequestSystemMessage{
          content: msg.content,
          role: :system
        }

      _ ->
        raise ArgumentError, message: "Invalid sender role: #{inspect(msg.sender)}"
    end
  end

  @spec handle_state_update(state, state) :: state
  defp handle_state_update(state, new_state) do
    case Map.get(state, :keep_context, true) do
      true ->
        new_state

      false ->
        state
    end
  end

  @impl true
  def handle_call({:insertmsg, m}, _from, state) do
    new_msg = from_domain(m)

    {:reply, new_msg,
     handle_state_update(state, state |> Map.put(:messages, state.messages ++ [new_msg]))}
  end

  @impl true
  def handle_call(:get_prefers_voice_chat, _from, state) do
    {:reply, Map.get(state, :prefers_voice_chat, false), state}
  end

  @impl true
  def handle_call(:get_language_preference, _from, state) do
    {:reply, Map.get(state, :language_preference, false), state}
  end

  @impl true
  def handle_call({:msg, m, streamer_pid, "davinci"} = params, from, state) do
    Logger.info("completing with davinci")

    with msgs <- state.messages ++ [new_msg(m)] do
      system_msgs =
        msgs
        |> Enum.filter(fn msg -> msg.role == :system end)
        |> Enum.map(fn msg -> msg.content end)
        |> Enum.join("\n")

      system_prompt =
        case String.length(system_msgs) do
          0 -> ""
          _ -> "Here are additional instructions that 'assistant' HAS TO follow: #{system_msgs}"
        end

      # TODO: Need to edit?
      default_prompt =
        "This is a conversation between the 'user' and a helpful AI assistant called 'assistant'. Only those 2 users are in the conversation. 'assistant' is also very knowledgeable in programming, and provides long replies that go into extensive detail, in a conversational matter. 'assistant' uses markdown in replies.\nThe conversation starts after '-----'\n#{system_prompt}\n-----\n\n"

      default_prompt_tokens = Mic.Chat.Tokenizer.count_tokens!(default_prompt)

      prompt =
        msgs
        |> Enum.filter(fn msg -> msg.role != :system end)
        |> Enum.map(fn msg -> "#{Atom.to_string(msg.role)}: #{msg.content}" end)
        # take the newest messages backwards until hitting the limit
        |> Enum.reverse()
        |> Enum.reduce_while("", fn x, acc ->
          with summarized <- x <> "\n\n" <> acc do
            if Mic.Chat.Tokenizer.count_tokens!(summarized) + default_prompt_tokens >= 2200 do
              {:halt, acc}
            else
              {:cont, summarized}
            end
          end
        end)

      prompt = default_prompt <> prompt <> "\n\nassistant:"
      Logger.debug(prompt)

      Logger.debug(
        "prompt size: #{String.length(prompt)} -- #{Mic.Chat.Tokenizer.count_tokens!(prompt)} tokens"
      )

      case ExOpenAI.Completions.create_completion("text-davinci-003",
             prompt: prompt,
             temperature: 0.7,
             stream: true,
             stream_to: streamer_pid,
             max_tokens: 2048
           ) do
        {:ok, res} when is_reference(res) ->
          {:reply, {:ok, res}, handle_state_update(state, state |> Map.put(:messages, msgs))}

        {:ok, res} ->
          first = List.first(res.choices)
          combined = msgs ++ [first.message]

          {:reply, {:ok, to_domain(first.message)},
           handle_state_update(state, state |> Map.put(:messages, combined))}

        {:error, %{"error" => %{"message" => msg}}} ->
          case(
            # if this specific error, retry
            String.contains?(
              msg,
              "The server had an error while processing your request. Sorry about that!"
            )
          ) do
            true ->
              handle_call(params, from, state)

            false ->
              {:reply, {:error, msg}, state}
          end

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    end
  end

  @impl true
  @spec handle_call({:msg, String.t(), pid(), String.t()}, any(), state) ::
          {:reply, {:ok, ExOpenAI.Components.ChatCompletionResponseMessage.t()} | {:error, any()},
           state}
          | {:reply, {:ok, reference()}, state}
  def handle_call({:msg, m, streamer_pid, model} = params, from, state) do
    Logger.info("completing with #{model}")

    with msgs <- state.messages ++ [new_msg(m)] do
      # strip out things that are over the token limit
      # TODO: need to update this - token limit check
      filtered_msgs =
        msgs
        |> Enum.reverse()
        |> Enum.reduce_while(%{msgs: [], tokens: 0}, fn msg, acc ->
          with msg_tokens <- Mic.Chat.Tokenizer.count_tokens!(msg.content) do
            # Depending on model this could be 15_000 or 127_000
            if msg_tokens + acc.tokens > 15000 do
              {:halt, acc}
            else
              {:cont, %{msgs: acc.msgs ++ [msg], tokens: acc.tokens + msg_tokens}}
            end
          end
        end)

      Logger.debug(filtered_msgs |> Enum.reverse())
      Logger.debug("prompt size: #{filtered_msgs.tokens} tokens")

      filtered_msgs
      |> Map.get(:msgs)
      |> Enum.reverse()
      |> ExOpenAI.Chat.create_chat_completion(model,
        temperature: 0.8,
        stream: true,
        stream_to: streamer_pid
      )
      |> case do
        # is reference == streaming
        {:ok, res} when is_reference(res) ->
          {:reply, {:ok, res}, handle_state_update(state, state |> Map.put(:messages, msgs))}

        # normal res = no streaming
        {:ok, res} ->
          first = List.first(res.choices)
          combined = msgs ++ [first.message]

          {:reply, {:ok, to_domain(first.message)},
           handle_state_update(state, state |> Map.put(:messages, combined))}

        {:error, %{"error" => %{"message" => msg}}} ->
          case(
            # if this specific error, retry
            String.contains?(
              msg,
              "The server had an error while processing your request. Sorry about that!"
            )
          ) do
            # if that specific error, recurse and try again
            true ->
              handle_call(params, from, state)

            false ->
              {:reply, {:error, msg}, state}
          end

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    end
  end

  def transcribe_voice(audio_content) do
    # TODO: TEMP: Temporary filename
    file_path = "/Users/francoabaroa/Desktop/Hack_Reactor/Repos/career/mic/temp_audio.mp3"

    # Write audio content to a file
    File.write!(file_path, audio_content)

    # Read the content back from the file
    case File.read(file_path) do
      {:ok, file_content} ->
        case ExOpenAI.Audio.create_transcription(
               {"temp_audio.mp3", file_content},
               "whisper-1"
             ) do
          {:ok, %ExOpenAI.Components.CreateTranscriptionResponse{text: transcription_text}} ->
            # If the transcription is successful, you get the transcribed text here
            # TODO: delete written file
            File.rm(file_path)
            {:ok, transcription_text}

          {:error, reason} ->
            Logger.error("Error in create_transcription request: #{inspect(reason)}")
            {:error, reason}

          _ ->
            Logger.error("Unexpected return value from ExOpenAI.Audio.create_transcription")
            {:error, :unexpected_return_value}
        end

      {:error, read_error} ->
        # Clean up and error handling
        File.rm(file_path)
        Logger.error("Error reading file: #{inspect(read_error)}")
        {:error, read_error}
    end
  end

  def generate_speech(input_text) do
    case ExOpenAI.Audio.create_speech(input_text, :"tts-1", :onyx, stream: true) do
      {:ok, audio_data} when is_binary(audio_data) ->
        base64_audio = Base.encode64(audio_data)

        {:ok, base64_audio}

      {:error, reason} ->
        Logger.error("Error in create_speech request: #{inspect(reason)}")
        {:error, reason}

      _ ->
        Logger.error("Unexpected return value from ExOpenAI.Audio.create_speech")
        {:error, :unexpected_return_value}
    end
  end

  def generate_artist_profile_description(input_text) do
    msgs = [
      %ExOpenAI.Components.ChatCompletionRequestUserMessage{
        role: :user,
        content:
          "Context: Pretend you are an expert, detailed, wise biography writer. You are able to ask some key questions to a music artist about them and their career and gather enough information to write a detailed, descriptive biography about that music artist.\n\nInstruction: Create a detailed biography of [Artist's Name], a [Genre(s)] artist with a rich background and diverse influences in the music industry. [Artist's Name], hailing from [Country] and born on [Date of Birth], discovered their passion for music [Musical Beginnings], marking the beginning of their musical journey. Their style has been profoundly shaped by artists such as [Influences]. [Artist's Name]'s aspirations include [Aspirations], aiming to leave their own significant mark on the music world. They have achieved notable milestones including [Significant Milestones].\n\nWith [Music Education], [Artist's Name] plays [Instruments Played]. Their experiences performing live, such as [Live Performances], have enriched their connection with audiences, enhancing their stage presence and musical depth. This is their [Spotify Bio], reflecting their achievements, their character and how they view their artistry. Future goals for [Artist's Name] include [Aspirations], with a vision to innovate and inspire within the [Genre(s)] genre. This biography captures the essence of [Artist's Name]'s musical identity, from their roots to their aspirations, instruments mastery, and the impact of their work. Think step by step using chain of thought reasoning to give the best, most detailed biography based on the above information.\n\nInput: " <>
            input_text
      }
    ]

    # TODO: Fix timeout happening with gpt-4-turbo-preview
    case ExOpenAI.Chat.create_chat_completion(msgs, "gpt-4-turbo-preview") do
      {:ok, res} ->
        first = List.first(res.choices)
        {:ok, first.message}

      {:error, reason} ->
        Logger.error("Error in generate_artist_profile_description request: #{inspect(reason)}")
        {:error, reason}

      _ ->
        Logger.error("Unexpected return value from Chat Completions")
        {:error, :unexpected_return_value}
    end
  end

  def generate_artist_tailored_content(artist_description, resource_subject) do
    syllabus =
      case resource_subject do
        :distribution ->
          """
          # Comprehensive Syllabus for Distribution

          ---

          ## A. Distribution

          ### 1. Digital Distribution
          - **Digital Distribution Strategies**
            - **Overview of Digital Distribution Platforms**
              - An insight into the variety of platforms available for digital distribution, including major streaming services, download stores, and direct-to-fan options. Understanding the unique benefits and limitations of each platform to tailor your distribution approach effectively.
            - **Integrating Direct-to-Fan Platforms into Distribution Plans**
              - Leveraging direct-to-fan sales platforms such as Bandcamp, SoundCloud, and personal websites. Detailing the importance of offering exclusive content, merchandise, and early releases to cultivate a devoted fanbase and maximize revenue directly from fans.
            - **Understanding Streaming Platforms**
              - **Strategies for Effective Use of Major Streaming Services**
                - Navigating the landscape of streaming services like Spotify, Apple Music, and Tidal. Tips on how to optimize artist profiles, make use of platform-specific features, and understand the algorithms to increase music discoverability and streaming numbers.
              - **Optimizing Content for Discoverability on Streaming Platforms**
                - Techniques to enhance the visibility of your music on streaming platforms. This includes optimizing metadata, using relevant and popular tags, engaging in playlist pitching, and understanding the role of editorial playlists versus algorithmic recommendations.
            - **Building a Release Strategy for Digital Platforms**
              - Designing a release strategy that capitalizes on the strengths of digital platforms. Discussing single versus album releases, timing considerations, and the importance of pre-save campaigns to build anticipation and engagement upon release.
            - **Monetization and Revenue Maximization on Digital Platforms**
              - Exploring different monetization models offered by digital distribution platforms, including streaming royalties, digital downloads, and content ID systems. Strategies for maximizing revenue through these channels, understanding royalty rates, and the importance of regular auditing and claims management.
            - **Data Analysis and Analytics Tools**
              - Utilizing the analytical tools provided by digital distribution platforms to track the performance of your music. Learning how to interpret key metrics such as plays, listener demographics, and engagement trends to inform future distribution and marketing decisions.
            - **Implementing a Multi-Platform Presence**
              - The significance of having a presence across multiple digital platforms to maximize reach and accessibility for various listener preferences. Strategies for managing and coordinating releases across different services while maintaining a coherent brand and marketing message.

          ### 2. Physical Media Distribution
          - **Physical Distribution Tactics**
            - **Best Practices for Vinyl, CDs, and Other Physical Formats**
              - An exploration of the resurgence of vinyl and continued interest in CDs and other tangible music formats. This includes discussing the appeal of physical media to collectors and fans, the importance of quality production, and innovative packaging options to make physical releases stand out.
            - **Tailoring Distributions Plans for Physical Media**
              - Crafting strategies to balance the demand for physical media with the efficient production and distribution to minimize overhead while maximizing reach. This also includes considerations for limited runs, special editions, and the role of pre-orders to gauge interest and fund production.
            - **Partnering with Independent Stores and Major Retailers**
              - Developing relationships with independent music stores and larger retailers for physical distribution. Strategies to make your product appealing for stockists, including consignment arrangements, promotional materials, and in-store performances or signings to boost sales and visibility.
            - **Utilizing Online Platforms for Physical Sales**
              - Leveraging online platforms such as Bandcamp, official artist websites, and specialty marketplaces to reach global audiences with physical merchandise. Includes tips for effective online presentation, international shipping considerations, and using limited edition releases to drive urgency and sales.
            - **Crowdfunding and Pre-Order Campaigns**
              - Implementing successful crowdfunding or pre-order campaigns to fund physical production. This section covers choosing the right platform, setting realistic goals, creating enticing rewards for backers, and marketing the campaign to reach and exceed funding targets.
            - **Environmental Considerations and Innovations in Physical Media**
              - Addressing the environmental impact of producing physical media and highlighting innovative, eco-friendly packaging and production methods. Discusses how sustainability can be a selling point and align with the values of fans and artists alike.
            - **Building a Release Strategy That Incorporates Physical Media**
              - Strategies for timing the release of physical media in the digital age, considering album launch events, merchandise bundles, and incorporating digital downloads with physical purchases to offer added value to fans.
            - **Logistics and Fulfillment Challenges**
              - An overview of logistics considerations for distributing physical media, including inventory management, fulfillment solutions for direct sales, and tips for efficient, cost-effective shipping.
            - **Case Studies: Successful Physical Media Campaigns**
              - Analyzing case studies of artists and labels that have effectively promoted and distributed physical media. This will include insights into their strategies, outcomes, and lessons learned that can apply to future physical releases.

          ### 3. Media and Content Distribution

          - **Music Video Distribution**
            - **Strategies for Leveraging Music Videos to Enhance Brand Visibility**
              - **Concept Development**: Emphasizing the importance of creating unique and creative concepts that align with the artist's brand and the song's message. Discussing how a distinctive music video can set an artist apart in a crowded digital landscape.
              - **Production Quality**: Addressing the balance between high production value and budget constraints. Offering tips for achieving professional-looking videos without breaking the bank, including the use of emerging tech like drones and smartphone cinematography.
              - **Platform-Specific Strategies**: Detailing the approaches for distribution across various platforms such as YouTube, Vimeo, and newer platforms like TikTok. Understanding the algorithm and audience preferences on each platform to maximize views and engagement.
              - **Synergies with Singles**: How to strategically release music videos in conjunction with single releases to enhance the song's market penetration. Discussing timing, teasers, and cross-promotion on social media to build anticipation.
              - **SEO and Metadata Optimization**: Techniques for optimizing video titles, descriptions, and tags to improve visibility on search engines and within video platforms. Highlighting the role of keywords, hashtags, and metadata in driving traffic to music videos.
              - **Engagement and Interaction**: Encouraging direct interaction with viewers through comments, live premieres, and interactive videos. Strategies for fostering a community around the artist's video content to support sustained viewer engagement.
              - **Cross-Promotional Collaborations**: Leveraging collaborations with other artists, influencers, or brands within music videos as a tactic for reaching broader audiences. Discussing the selection process for collaborators, negotiation tips, and ensuring brand alignment.
              - **Analyzing Performance Metrics**: Utilizing platform analytics to gauge the success of music video releases. Interpreting views, watch time, engagement rates, and demographic data to refine future video content strategies.
              - **Legal Considerations and Rights Management**: Overview of copyright issues, music licensing, and obtaining the necessary permissions for visuals and music. Tips for navigating the legal landscape to avoid potential pitfalls in music video distribution.
            - **Implementation Steps**
              - Start with Pre-Production Planning: Develop a concept and storyboard that align with the artist’s brand and message.
              - Budgeting and Resource Allocation: Make informed decisions on allocating resources for production quality versus reach.
              - Platform Selection: Choose the most suitable platforms for distribution based on the target audience and content style.
              - SEO and Metadata: Prepare metadata in advance to ensure immediate optimization upon release.
              - Engagement Plan: Develop a plan for premiere timing, viewer interaction, and cross-promotional efforts.
              - Performance Review: Schedule a review of analytics post-release to assess performance and gather insights for future projects.
          - **Social Media Mastery**
            - **Strategic Planning for Social Media**
              - Understanding the unique demographics and user behaviors on major social platforms (e.g., Instagram, Twitter, Facebook, TikTok) to develop targeted strategies. Emphasizing the importance of a cohesive social media calendar to regularly engage with the audience.
              - **Content Planning and Scheduling**
                - Develop a content calendar to maintain a consistent posting schedule across platforms, ensuring a steady stream of engagement with your audience.
                - Tailor content for each platform (e.g., short-form videos for TikTok, professional photos and stories for Instagram, long-form content on Facebook) to maximize impact.
            - **Content Creation for Social Media**
              - Guidelines for creating engaging, platform-specific content that resonates with followers. This includes the use of live videos, stories, behind-the-scenes content, and interactive posts (polls, Q&As) to foster a community around the music.
              - **Storytelling Through Content**
                - **Narrative Posts**: Share the stories behind your songs, the inspirations from your life, and your journey as a musician. These personal glimpses can deepen fan connections.
                - **Behind-The-Scenes Content**: Offer behind-the-scenes looks into your music-making process, from songwriting to production, using tools like Instagram Stories or TikTok.
              - **Visual Identity**
                - **Consistent Aesthetics**: Maintain consistency in style to enhance brand recognition across all social media content.
                - **Music Visualizers**: Create and share music visualizers for your tracks on platforms like YouTube and Instagram, enhancing your music with captivating visuals.
            - **Leveraging Algorithms for Visibility**
              - Insight into how social media algorithms work and strategies to enhance visibility and engagement of posts. Techniques such as optimal posting times, hashtags, and engagement tricks (comments, shares, saves) to boost organic reach.
            - **Fan Engagement and Community Building**
              - Tactics for converting passive followers into active community members and superfans. Encouraging interaction through direct messaging, comment engagement, fan shout-outs, and exclusive content.
              - **Engagement Strategies**
                - **Interactive Content**: Utilize polls, Q&As, and live streams to directly engage with followers and acquire valuable insights into your audience’s preferences.
                - **Fan Features**: Share user-generated content, such as fans covering your songs or fan art, to foster community and encourage more interaction.
            - **Analytics and Metrics**
              - Utilizing platform analytics to track engagement rates, follower growth, content performance, and more. Analyzing this data to refine and adapt social media strategies for better outcomes.
              - **Analytics and Adaptation**
                - **Monitor Performance**: Regularly review analytics across platforms to understand what content performs best, making necessary adjustments to strategies accordingly.
                - **Feedback Loops**: Encourage and act on feedback from your audience, utilizing it to refine content and improve engagement strategies.
            - **Paid Advertising and Promotion**
              - Overview of paid social advertising options available on platforms like Facebook and Instagram. Setting up target demographics, budgeting, and measuring ROI of paid campaigns to support album releases, concert ticket sales, or merchandising.
            - **Cross-Promotion and Collaborations**
              - Techniques for cross-promoting content across different social platforms to maximize reach. Collaborating with other artists, influencers, and content creators for mutual promotion and audience sharing.
              - **Collaborations and Cross-Promotions**
                - **Influencer Collaborations**: Partner with social media influencers or other musicians for live sessions, takeovers, or shared content, which can expand your reach to new audiences.
                - **Cross-Promotions**: Engage in cross-promotion with artists, brands, or creators who share a similar audience to maximize content reach and benefit all parties involved.
            - **Crisis Management and Brand Protection**
              - Strategies for managing negative feedback, controversies, or social media crises. Maintaining a professional online presence and protecting the artist brand.
            - **Adapting to Social Media Trends**
              - Keeping abreast of the latest social media trends, features, and updates to stay relevant. Flexibility in experimenting with new content forms (e.g., Instagram Reels, TikTok challenges) to engage with newer audiences.
            - **Utilizing Music and Video Platforms**
              - **YouTube Series**: Create a series on YouTube to share your journey, performances, or the stories behind your music, thereby enhancing your digital footprint and SEO.
              - **Spotify Playlists**: Curate playlists on Spotify featuring your music alongside tracks from other artists to encourage follows and shares, increasing your music's exposure.
            - **Implementation and Best Practices**
              - **Authenticity**: Ensure your social media presence remains true to your identity and narrative, resonating authenticity.
              - **Visual Storytelling**: Invest in quality visuals that complement your music’s mood and themes, enhancing brand and music promotion.
              - **Regular Engagement**: Dedicate time daily or weekly to personally engage with your community, responding to comments, messages, and collaborating with other creators to foster a supportive and dynamic fan base.
          - **Collaboration Strategies**
            - Collaborations are a strategic approach to growth in the music industry, helping artists reach new audiences and enrich their music with fresh perspectives.
              - #**Genre-Crossing Collaborations**
                - Collaborate with Artists in Complementary Genres: Engage with artists in complementary genres to create a compelling cross-genre appeal. This strategy not only refreshes an artist's music but also extends their audience reach into new demographic areas.
              - #**Digital Collaborations**
                - Online Songwriting Sessions: Leverage digital platforms like Zoom, Discord, or Instagram Live for co-writing sessions. This allows for a unique blend of sounds and cultural influences by collaborating remotely with artists and producers worldwide.
                - Remote Recording Projects: Utilize digital audio workstations (DAWs) and file-sharing services to engage in remote collaborations that introduce diverse sonic textures to the music.
              - #**Live Performance Collaborations**
                - Guest Appearances at Shows: Enhance live performances by inviting guest artists to participate, offering a unique experience to audiences and fostering community within the music industry.
                - Virtual Concerts: Organize joint virtual concerts or live streams to reach global audiences, especially useful in scenarios where live show options are limited.

              - #**Content Creation Collaborations**
                - Music Video Features: Invite other artists to participate in music videos, expanding reach into their fanbases and introducing novel visual and musical elements.
                - Social Media Challenges: Engage in or initiate social media challenges with other artists to boost platform visibility and engagement.
              - #**Workshops and Masterclasses**
                - Co-host Workshops: Facilitate workshops or masterclasses in collaboration with other artists or industry professionals on topics such as songwriting, production, or music theory, providing value and networking opportunities within the artist community.
              - #**Collaborative Releases**
                - Release Collaborative Singles or EPs: Share the creative and promotional workload by releasing music jointly. These collaborations can generate excitement and anticipation among the fan bases of all artists involved.
              - #**Community Projects**
                - Music Collectives: Participate in or establish music collectives with like-minded artists. These collectives can offer a support network, shared resources, and collective marketing efforts, amplifying reach and impact.
              - **Implementation Steps**
                - Start with Research: Identify potential collaborators.
                - Reach Out: Make initial contact through various platforms.
                - Build Relationships: Engage with content, attend shows, or connect on social media.
          - **Engaging with Music Blogs and Press**
            - Mastering the art of engaging with music blogs and press is essential for expanding your reach and establishing your name in the music industry. This section delves into strategies for capturing the attention of music journalists and bloggers, crafting compelling stories about your music, and leveraging these platforms for increased visibility.
              - **Identify Target Publications**
                - Research and identify blogs, magazines, and e-zines that align with your music genre or style. Understanding the audience of these publications can help tailor your pitches, ensuring they resonate with the right demographic.
              - **Crafting a Press Kit**
                - Developing a professional and comprehensive press kit that includes a bio, high-quality photos, music samples or links, press releases, and contact information. A well-crafted press kit makes it easier for journalists to cover your story.
              - **Writing Effective Press Releases**
                - Learn the structure of an engaging and informative press release. Tips on how to announce new music releases, tours, or noteworthy achievements in a way that captures interest and provides all necessary information for easy publication.
              - **Pitching to Music Journalists and Bloggers**
                - Strategies for reaching out to journalists and bloggers, including personalizing your pitches, understanding the best times to send emails, and following up respectfully. Building a relationship with the press is a long-term investment that can yield significant coverage.
              - **Leveraging Social Media for Press Engagement**
                - Utilizing social media platforms to establish connections with music journalists, bloggers, and influencers in your genre. Engaging with their content, sharing their articles, and gradually building a rapport that can lead to coverage.
              - **Handling Rejection and Negative Press**
                - Developing a thick skin is part of engaging with the press. Learn how to handle rejection professionally and how to deal with negative press constructively, using it as an opportunity for growth and improvement.
              - **Analyzing Press Coverage**
                - Tracking and analyzing the impact of press coverage on your music career. This includes monitoring increases in streaming numbers, social media followers, and website traffic post-coverage to understand the effectiveness of your press engagements.
              - **Implementation Steps**
                - Research and List Potential Publications: Start with compiling a list of relevant music blogs and press contacts.
                - Develop Your Press Kit: Ensure your press kit is up-to-date and readily available for submissions.
                - Craft Your Pitch: Personalize your pitches based on the publication or journalist you're contacting.
                - Engage on Social Media: Actively follow and engage with journalists and influencers on social platforms.
                - Monitor Results: Keep an eye on the outcomes of press coverage, analyzing the impact on your music's reach.
          - **Licensing Opportunities**
            - **Exploring Sync Licensing for Films, TV, Ads, and Games**
              - An introduction to the fundamentals of sync licensing, outlining how artists can leverage their music in various media to generate revenue and wider recognition.
            - **Navigating the Licensing Landscape**
              - Insights into the sync licensing market, including how to find licensing opportunities, what music supervisors look for, and the types of projects that commonly seek music licenses. Discussion on building relationships with music supervisors, licensing agencies, and libraries.
            - **The Licensing Process**
              - A step-by-step guide to the process of licensing music, from initial contact to finalizing contracts. This includes negotiating terms, understanding rights, and ensuring proper compensation. Emphasis on the importance of clear communication and understanding contractual obligations.
            - **Copyrights and Publishing Rights**
              - An overview of the importance of copyright and publishing rights management in sync licensing. How owning or controlling both the master and sync rights can affect licensing opportunities and revenue.
            - **Creating Music with Licensing in Mind**
              - Tips for creating music that is attractive for sync licensing opportunities. Insights into trends in music requests by media projects, the importance of instrumental versions, and tailoring tracks to fit a variety of moods and settings.
            - **Case Studies and Success Stories**
              - Real-world examples of successful sync licensing deals and how they were secured. Analysis of how specific tracks were chosen for particular projects and the impact on the artists' careers and revenue streams.
            - **Legal Considerations and Pitfalls**
              - Advice on navigating the legal aspects of sync licensing, including common pitfalls to avoid. Guidance on seeking legal advice and ensuring all agreements are fair and in the artist's best interest.
            - **Maximizing Revenue and Exposure**
              - Strategies for maximizing both the financial benefits and the exposure that can come from sync licensing. Discussion on how sync placements can lead to increased streams, sales, and bookings, as well as greater visibility within the industry.
            - **Resources and Further Learning**
              - Recommended resources for artists looking to explore sync licensing further. This includes books, online courses, workshops, and industry conferences focused on sync licensing and music supervision.

          ### 4. Performance and Promotion
          - **Live Performance Opportunities**
            - **Booking and Organizing Shows**
              - **Venue Selection**: Understanding how to choose the right venue for your music and audience. Considering factors such as capacity, location, audience demographics, and venue reputation.
              - **Contract Negotiations**: Guidance on negotiating terms with venues or event promoters, including payment, technical requirements, and merchandise sales.
              - **Promotion Strategies**: Best practices for promoting your shows to maximize attendance. Utilizing social media, local press, and concert listing websites.

            - **Touring Strategies**
              - **Routing Your Tour**: Tips on planning an efficient and profitable tour route. Considering geographic locations, audience bases, and logistical costs.
              - **Budgeting**: Managing tour finances, including forecasting costs for travel, accommodation, food, and equipment. Strategies for financially sustaining your tour.
              - **Merchandising on Tour**: Leveraging concerts and tours to sell merchandise. Tips on merchandise selection, pricing, and sales tactics.

            - **Leveraging Technology for Live Performances**
              - **Live Streaming**: Utilizing platforms such as Twitch, YouTube Live, and Instagram Live to reach wider audiences. Planning and executing a live-streamed concert.
              - **Interactive Elements**: Incorporating interactive elements into live and virtual shows to engage audiences, such as live chats, Q&A sessions, and real-time polls.

            - **Audience Engagement and Experience**
              - **Creating Memorable Experiences**: Ideas for making your live shows unforgettable, including unique stage setups, visual effects, and audience participation.
              - **Fan Interaction**: Strategies for engaging with fans during and after shows to build a loyal fanbase. Incorporating meet-and-greets, signings, and exclusive after-show events.

            - **Safety and Compliance**
              - **Health and Safety Measures**: Ensuring the health and safety of your audience, crew, and yourself. Adhering to local regulations and best practices for crowd management and emergency preparedness.
              - **Licensing and Legal Requirements**: Understanding the legal requirements for live performances, including permits, copyright allowances, and venue licenses.

            - **Monetizing Live Performances**
              - **Ticketing Strategies**: Pricing your tickets effectively and utilizing ticketing platforms to maximize revenue and gather audience data.
              - **Sponsorships and Partnerships**: Exploring opportunities for sponsorships and partnerships with brands for live events, enhancing the event experience and securing additional funding.

            - **Virtual Concerts and Beyond**
              - **Innovative Formats**: Examining the future of live performances, including VR concerts, hologram tours, and other innovative concert formats that could shape the future of live music.
          - **Merchandising for Brand Promotion**
            - **Developing Merchandise as Brand Assets**
              - Understanding the role of merchandise as not just products, but as integral assets to an artist's brand. This includes leveraging merchandise to deepen fan relationships, reinforce brand identity, and create additional revenue streams.
            - **Product Selection and Design**
              - Choosing merchandise that resonates with your fan base and reflects your artistic brand. This involves product types (such as apparel, accessories, limited edition items), design considerations, and ensuring quality to enhance brand perception.
            - **E-commerce Platforms and Strategies**
              - Tips on setting up an online merchandise store using platforms like Shopify, Bandcamp, and Big Cartel. Best practices for user experience, storefront design, and integrating these platforms with your existing website and social media for seamless marketing.
            - **Pricing and Inventory Management**
              - Deciding on pricing strategies that balance affordability for fans and profitability for the artist. Approaches to inventory management, including considerations for on-demand production versus pre-made inventory to minimize risk.
            - **Promotional Strategies for Merchandise Sales**
              - Tactics to create buzz and drive sales, including limited-time offers, bundle deals, exclusive merchandise for concerts or events, and using social media for promotions. Importance of storytelling in merchandise promotion to connect with the audience.
            - **Fan Engagement Through Merchandise**
              - Engaging fans through creative means such as merchandise personalization (e.g., signed items, custom designs), fan design contests, and offering merchandise as part of larger fan experiences (e.g., VIP packages, meet-and-greets).
            - **Merchandise at Live Events**
              - Strategies for selling merchandise at live events and tours. This includes display tips, managing transactions efficiently, and personnel considerations. Understanding the differences in merchandising for live events versus online sales.
            - **Analyzing Merchandise Sales Data**
              - Leveraging sales data to inform future merchandise decisions. This includes understanding which products perform well, tracking revenue from merchandise sales, and using data to plan for future product lines or discontinuing underperforming items.
            - **Legal Considerations and Copyright**
              - A brief overview of copyright laws related to merchandise, including the need for clearances for artwork and designs, understanding copyright ownership, and navigating collaborations with designers or other brands.
          - **Fan Engagement Techniques**
            - Engaging fans is crucial for building a sustainable music career. This section explores various strategies artists can use to cultivate a loyal fanbase and maintain an interactive relationship with their audience.
              - **Personalized Content Creation**
                - Sharing behind-the-scenes content, personal stories, and experiences can help fans feel a deeper connection to the artist. Utilizing platforms like Instagram Stories, YouTube, and Patreon to share exclusive content.
              - **Interactive Digital Experiences**
                - Hosting live Q&A sessions, virtual listening parties, and interactive livestreams where fans can participate in real-time discussions and activities, enhancing the fan-artist relationship.
              - **Fan Clubs and Communities**
                - Creating dedicated spaces for fans to interact with each other and the artist. Utilize platforms like Discord or create private Facebook groups to foster a sense of community.
              - **Exclusive Merchandise and Offers**
                - Offering fan club-exclusive merchandise or limited-time offers can incentivize fans to engage more closely with the artist's brand. Implementing fan-first policies for concert ticket sales to reward loyal followers.
              - **Crowdsourcing and Collaborative Projects**
                - Involving fans in creative processes such as music video submissions, artwork competitions, or crowdsourcing setlist choices for live shows. This collaborative approach boosts engagement by giving fans a stake in the artist's creative output.
              - **Regular Communication and Updates**
                - Keeping fans updated through regular newsletters, social media posts, or personalized messages. Transparency about the artist's journey, upcoming projects, and acknowledgments of fan support plays a key role in keeping the fanbase engaged and informed.
              - **Rewarding Fan Loyalty**
                - Implementing loyalty programs that reward fans for streaming music, attending concerts, or purchasing merchandise. Rewards can include exclusive content, early access to tickets, or meet-and-greet opportunities.
              - **Utilizing Gamification**
                - Incorporating game-like elements into fan engagement strategies, such as challenges, badges, and leaderboards, based on fan activities like streaming or social media engagement.
              - **Feedback and Community Input**
                - Actively seeking and responding to fan feedback through surveys, comment sections, and direct messages. This not only informs the artist's decisions but also makes fans feel valued and heard.

          ### 5. Broadcast and Reach Extension
          - **Radio and Podcast Outreach**
            - **Engaging with Radio**
              - **Understanding Radio Formats and Target Audiences**: Insight into different radio formats (e.g., commercial, college, internet) and identifying the right fit for your music. Tailoring your pitch based on the specific audience and format of the radio station.
              - **Creating a Radio Promotion Plan**: Crafting a comprehensive plan for radio promotion, including timelines for single releases, press releases, and follow-ups with radio stations.
              - **Building Relationships with Radio DJs and Program Directors**: Strategies for connecting with key influencers in radio, tips for making your music stand out, and maintaining ongoing relationships to support current and future releases.
              - **Leveraging Local Radio Opportunities**: Capitalizing on local radio stations and community support as a base to expand your reach. Participating in local radio interviews, performances, and community events.

            - **Leveraging Podcasts for Music Promotion**
              - **Identifying Relevant Podcasts**: Researching and compiling a list of podcasts aligned with your music genre, target audience, or themes relevant to your brand and music.
              - **Pitching Your Music to Podcasts**: Best practices for crafting personalized pitches to podcast hosts, emphasizing the mutual benefit and potential value your music brings to their audience.
              - **Collaborating with Podcasters for Interviews and Features**: Engaging in discussions with podcasters for in-depth interviews, music features, or guest appearances to introduce your music to their audience in a more personal and engaging way.
              - **Promotional Strategies Post-Podcast Feature**: Maximizing the impact of your podcast appearances through social media promotion, email newsletters, and leveraging the content across your digital platforms to drive listenership.

            - **Measuring Success and Analyzing Impact**
              - **Tracking Radio Airplay and Listener Responses**: Tools and methods for monitoring where and how often your music is played on radio stations, and analyzing listener engagement and feedback.
              - **Evaluating Podcast Appearances and Audience Growth**: Methods for assessing the success of podcast features through metrics such as listener numbers, social media engagement, and spikes in streaming or sales, to inform future outreach strategies.

            - **Implementation Steps**
              - **Crafting a Compelling Electronic Press Kit (EPK)**: Creating an EPK that effectively showcases your music, biography, high-resolution images, and any notable achievements. Highlighting specific tracks suited for radio play or podcast features.
              - **Research and Outreach**: Methodically identifying potential radio and podcast opportunities, crafting personalized pitches, and following up professionally.
              - **Engagement and Relationship Building**: Actively participating in discussions, expressing appreciation for airplay and features, and nurturing relationships with DJs, program directors, and podcast hosts for future opportunities.
          - **Networking and Community Engagement**
            - Networking and engaging within music and broader artistic communities are crucial for expanding an artist's reach and discovering new opportunities. This section delves into strategies to build meaningful connections and foster a supportive network.
              - **Importance of Networking in the Music Industry**
                - Understanding the role networking plays in career development, collaboration opportunities, and knowledge exchange. Emphasizing the value of genuine relationships over transactional interactions.
              - **Online Networking Strategies**
                - Leveraging social media platforms, online forums, and music collaboration sites to connect with fellow artists, industry professionals, and fans. Tips for effective communication and maintaining an active, engaging online presence.
              - **Offline Networking Tactics**
                - Strategies for engaging with the community offline through attending industry events, music conferences, workshops, and local gigs. The significance of face-to-face interactions and making a lasting impression.
              - **Engaging with Music Collectives and Groups**
                - How joining or forming music collectives can provide a support network, shared resources, and collective marketing efforts. Benefits of collaborative environments for creative inspiration and resource pooling.
              - **Building and Maintaining Professional Relationships**
                - Best practices for nurturing professional relationships over time. Importance of follow-ups, mutual support, and respect in solidifying connections.
              - **Community Engagement and Support**
                - Ways to engage and give back to the community, such as hosting free workshops, participating in local music events, or supporting charitable causes. Strengthening your reputation and presence by contributing positively to the community.
              - **Utilizing Professional Networking Sites**
                - Navigating sites like LinkedIn to connect with industry professionals. Crafting a professional profile that highlights your music career, achievements, and aspirations.
              - **Collaboration as a Networking Tool**
                - Leveraging collaborative projects not only for creative exchange but also as a means to broaden your network. How collaboration can lead to new performance opportunities, joint ventures, and expanded audience reach.
              - **Feedback and Continuous Improvement**
                - Embracing feedback from your network to improve your music, performance, and professional interactions. The role of constructive criticism in personal and career development.
              - **Implementation Steps**
                - **Identify Targets**: Start by identifying potential networking targets who align with your music style and career goals.
                - **Initial Engagement**: Engage with their content on social platforms, attend their events, or reach out directly with personalized messages.
                - **Build and Nurture**: Focus on building relationships through shared interests, collaboration, and supporting one another's endeavors.
          - **Email Newsletter Strategies**
            - **Designing Compelling Email Content**
              - Crafting engaging email content that captivates and retains the reader's interest. Focus on storytelling, highlighting exclusive updates, and providing value to subscribers to encourage open rates and engagement.
            - **Building and Segmenting Your List**
              - Strategies for organically building an email list through website sign-ups, fan interactions, and merchandising opportunities. The importance of segmenting lists based on fan interests, geographic locations, and engagement levels to personalize content and increase relevancy.
            - **Frequency and Timing**
              - Determining the optimal frequency for sending newsletters to balance keeping fans informed without overwhelming them. Discussing the timing of emails to maximize open rates based on your audience’s behavior patterns and time zones.
            - **Integration with Overall Marketing Strategies**
              - Aligning email newsletters with your overall marketing and promotional strategies. Coordinating content across platforms to enhance campaign effectiveness and drive action, such as streaming new releases, attending shows, or purchasing merchandise.
            - **Leveraging Analytics for Improvement**
              - Utilizing email marketing analytics tools to track open rates, click-through rates, and subscriber engagement. Analyzing data to refine subject lines, content, and calls to action for future newsletters. Setting measurable goals and testing different strategies to continually improve the effectiveness of email communication.
            - **Compliance and Best Practices**
              - Adhering to email marketing regulations and best practices, including GDPR compliance for European subscribers. Ensuring subscribers have easy access to unsubscribe options and maintaining transparency about what the email list is used for.
            - **Creative Engagements**
              - Innovative ideas for engaging fans through email, such as exclusive pre-sales, fan Q&A sessions, behind-the-scenes content, or interactive polls. Encouraging direct replies to foster a sense of community and gather feedback directly from fans.

          ### 6. Strategy Adaptation
          - **Adaptation to Industry Changes**
            - **Staying Informed on Industry Trends**
              - Regularly following reputable music industry news sources, blogs, and forums to stay updated on emerging trends, technological advancements, and shifts in consumer behavior. This proactive approach enables artists and industry professionals to adapt their strategies in real-time to the ever-evolving music landscape.
            - **Leveraging New Technologies**
              - Exploring and integrating new technologies such as blockchain for music rights management, virtual reality for immersive music experiences, and AI for music creation and marketing. Understanding these technologies' potential impacts and how they can be used to enhance distribution and engagement.
            - **Responding to Consumer Behavior Shifts**
              - Analyzing listener data and market research to identify changes in how audiences discover, consume, and interact with music. Adapting distribution methods, marketing strategies, and content creation to meet these evolving expectations and preferences.
            - **Innovative Marketing Techniques**
              - Keeping abreast of the latest marketing techniques and platforms that can offer new ways to connect with fans. For example, utilizing TikTok for viral music challenges, leveraging Spotify's playlist pitching feature, or employing Instagram Stories for real-time fan engagement.
            - **Regulatory and Legal Awareness**
              - Staying informed about changes in music licensing, copyright laws, and digital rights management that affect how music is distributed and monetized. This ensures compliance and maximizes revenue while protecting intellectual property.
            - **Networking and Industry Collaboration**
              - Actively participating in music industry events, workshops, and online communities to exchange knowledge and experiences with peers. Collaboration can lead to innovative solutions and strategies for adapting to industry changes.
            - **Continual Learning and Skill Development**
              - Engaging in ongoing learning opportunities, such as online courses, webinars, and mentorship programs, to build skills and knowledge in areas like digital marketing, music tech, and data analytics. This empowers professionals to remain agile and responsive in a competitive and fluctuating industry.
            - **Implementation Action Plan**
              - Developing a flexible and actionable plan to apply insights and adapt strategies based on industry changes. Setting up a regular review process to assess the effectiveness of adaptation efforts and make necessary adjustments to stay aligned with industry dynamics and objectives.
          ---
          """

        :marketing ->
          "Create a message tailored for marketing topics."

        :finance ->
          "Create a message tailored for finance topics."

        :health ->
          "Create a message tailored for health topics."

        :legal ->
          "Create a message tailored for legal topics."

        _ ->
          "Default message for subjects not explicitly handled."
      end

    msgs = [
      %ExOpenAI.Components.ChatCompletionRequestUserMessage{
        role: :user,
        content: """
                Given:
        1. A detailed subject syllabus concerning a specific facet of the music industry (and advice regarding it).
        2. A comprehensive music artist biography.

        Your task is to create a personalized insights sheet for the music artist for the given subject with personalized recommendations to improve in that area. Use the syllabus and the artist biography to create a set of personalized, actionable, and useful recommendations.

        Please follow these guidelines for the output:
        - Output must be in a easy-to-read HTML object string organized properly. Make sure to bold any headings.
        - Focus solely on including recommendations.
        - Provide the recommendations in a concise format, ideally fitting within two pages of text.
        - Employ step-by-step thinking using chain of thought reasoning to ensure the recommendations are highly personalized and actionable for the artist according to their biography.

        Here are the details you'll base your recommendations on:

        Artist Biography: #{artist_description}

        Syllabus: #{syllabus}
        """
      }
    ]

    case ExOpenAI.Chat.create_chat_completion(msgs, "gpt-4-turbo-preview") do
      {:ok, res} ->
        first = List.first(res.choices)
        {:ok, first.message}

      {:error, reason} ->
        Logger.error("Error in generate_artist_tailored_content request: #{inspect(reason)}")
        {:error, reason}

      _ ->
        Logger.error("Unexpected return value from Chat Completions")
        {:error, :unexpected_return_value}
    end
  end

  def generate_iso_8601_date_string(input_text) do
    msgs = [
      %ExOpenAI.Components.ChatCompletionRequestUserMessage{
        role: :user,
        content:
          "Please format the given DOB as ISO-8601 YYYY-MM-DD. DOB: " <>
            input_text <> " ONLY RETURN THE ISO-8601 STRING, NOTHING ELSE."
      }
    ]

    case ExOpenAI.Chat.create_chat_completion(msgs, "gpt-3.5-turbo") do
      {:ok, res} ->
        first = List.first(res.choices)
        {:ok, first.message}

      {:error, reason} ->
        Logger.error("Error in generate_iso_8601_date_string request: #{inspect(reason)}")
        {:error, reason}

      _ ->
        Logger.error("Unexpected return value from Chat Completions")
        {:error, :unexpected_return_value}
    end
  end

  def set_prefers_voice_chat(pid, prefers_voice_chat) do
    GenServer.cast(pid, {:set_prefers_voice_chat, prefers_voice_chat})
  end

  @impl true
  def handle_cast({:set_prefers_voice_chat, prefers_voice_chat}, state) do
    new_state = Map.put(state, :prefers_voice_chat, prefers_voice_chat)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:set_language_preference, language_preference}, state) do
    new_state = Map.put(state, :language_preference, language_preference)
    {:noreply, new_state}
  end

  def set_language_preference(pid, language_preference) do
    GenServer.cast(pid, {:set_language_preference, language_preference})
  end

  def get_prefers_voice_chat(pid) do
    GenServer.call(pid, :get_prefers_voice_chat)
  end

  def get_language_preference(pid) do
    GenServer.call(pid, :get_language_preference)
  end

  @spec start_link(init_settings) :: {:error, any} | {:ok, pid}
  def start_link(init_settings) do
    Logger.debug("starting OpenAI: #{inspect(init_settings)}")
    msgs = Map.get(init_settings, :messages, []) |> Enum.map(&from_domain/1)

    GenServer.start_link(__MODULE__, %{messages: msgs, settings: init_settings}, [])
  end

  def send(pid, msg, model, streamer_pid) do
    GenServer.call(pid, {:msg, msg, streamer_pid, model}, 100_000)
  end

  def insert_message(pid, msg) do
    GenServer.call(pid, {:insertmsg, msg}, 100_000)
  end
end
