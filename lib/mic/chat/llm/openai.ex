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
  @spec handle_call({:msg, String.t(), pid(), String.t()}, any(), state) ::
          {:reply, {:ok, ExOpenAI.Components.ChatCompletionResponseMessage.t()} | {:error, any()},
           state}
          | {:reply, {:ok, reference()}, state}
  def handle_call({:msg, m, streamer_pid, model} = params, from, state) do
    Logger.info("completing with #{model}")

    model_config =
      Application.get_env(:mic, :models)
      |> Enum.find(fn model_config -> model_config.id == model end)

    # Use the truncate_tokens value from the model configuration or a backup value
    # TODO: handle this better
    token_limit =
      if model_config != nil do
        model_config.truncate_tokens || 8000
      else
        8000
      end

    with msgs <- state.messages ++ [new_msg(m)] do
      # strip out things that are over the token limit
      # TODO: which things get stripped? oldest or newest?
      # TODO: need to update this - token limit check
      filtered_msgs =
        msgs
        |> Enum.reverse()
        |> Enum.reduce_while(%{msgs: [], tokens: 0}, fn msg, acc ->
          with msg_tokens <- Mic.Chat.Tokenizer.count_tokens!(msg.content) do
            if msg_tokens + acc.tokens > token_limit do
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

  def transcribe_voice_using_written_file_name(file_name) do
    # TODO: combine this function and transcribe_voice
    # TODO: TEMP: Temporary filename
    file_path = "/Users/francoabaroa/Desktop/Hack_Reactor/Repos/career/mic/#{file_name}"

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

  def generate_speech_no_streaming_no_encoding(input_text) do
    case ExOpenAI.Audio.create_speech(input_text, :"tts-1", :nova) do
      {:ok, audio_data} when is_binary(audio_data) ->
        {:ok, audio_data}

      {:error, reason} ->
        Logger.error("Error in create_speech request: #{inspect(reason)}")
        {:error, reason}

      _ ->
        Logger.error("Unexpected return value from ExOpenAI.Audio.create_speech")
        {:error, :unexpected_return_value}
    end
  end

  def generate_artist_profile_description(input_text) do
    # TODO: The content string in the message object contains placeholder text such as [Artist's Name], [Genre(s)], [Country], etc., which are not dynamically replaced
    msgs = [
      %ExOpenAI.Components.ChatCompletionRequestUserMessage{
        role: :user,
        content:
          "Context: Pretend you are an expert, detailed, wise biography writer. You are able to ask some key questions to a music artist about them and their career and gather enough information to write a detailed, descriptive biography about that music artist.\n\nInstruction: Create a detailed biography of [Artist's Name], a [Genre(s)] artist with a rich background and diverse influences in the music industry. [Artist's Name], hailing from [Country] and born on [Date of Birth], discovered their passion for music [Musical Beginnings], marking the beginning of their musical journey. Their style has been profoundly shaped by artists such as [Influences]. [Artist's Name]'s aspirations include [Aspirations], aiming to leave their own significant mark on the music world. They have achieved notable milestones including [Significant Milestones].\n\nWith [Music Education], [Artist's Name] plays [Instruments Played]. Their experiences performing live, such as [Live Performances], have enriched their connection with audiences, enhancing their stage presence and musical depth. This is their [Spotify Bio], reflecting their achievements, their character and how they view their artistry. Future goals for [Artist's Name] include [Aspirations], with a vision to innovate and inspire within the [Genre(s)] genre. This biography captures the essence of [Artist's Name]'s musical identity, from their roots to their aspirations, instruments mastery, and the impact of their work. Think step by step using chain of thought reasoning to give the best, most detailed biography based on the above information.\n\nInput: " <>
            input_text
      }
    ]

    # TODO: Fix timeout happening with gpt-4-turbo-preview
    model = Application.get_env(:mic, :model) || "gpt-4o"

    case ExOpenAI.Chat.create_chat_completion(msgs, model) do
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

          ## Distribution

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
          """
          # Comprehensive Syllabus for Financial Management and Strategy
          ---
          ## 1. Introduction to Financial Management for Music Artists
          - **Understanding Basic Financial Concepts**
          - Brief overview of key financial terminologies and concepts essential for music artists, including income, expenses, assets, liabilities, and cash flow.
          - Brief introduction to financial statements relevant to artists: Balance Sheets, Income Statements, and Cash Flow Statements.
          - **Importance of Financial Literacy**
          - Discussing why financial literacy is pivotal for career longevity and independence in the music industry.
          - Real-world examples of how financial knowledge can impact an artist's career trajectory.
          ## 2. Revenue Collection
          - **Royalties and Rights Management**
          - Detailed explanation of different types of royalties (mechanical, performance, sync, etc.) and how they are collected.
          - Understanding the role of PROs (Performing Rights Organizations) and mechanical licensing agencies in collecting royalties.
          - Strategies for ensuring accurate royalty tracking and collection.
          - **Digital Sales and Streaming**
          - How revenue is generated from digital sales and streaming platforms, including pay-per-download and streaming royalties.
          - Strategies for maximizing income from digital streams, such as playlist placement and algorithmic optimization.
          - Case studies of artists successfully leveraging digital platforms for revenue generation.
          - **Implementation Steps**
          - Register with relevant PROs and mechanical licensing agencies.
          - Regularly monitor and audit royalty statements.
          - Optimize digital profiles and engage with streaming platforms to increase visibility and revenue potential.
          ## 3. Monetization Strategies Beyond Traditional Means
          - **Merchandising**
          - Creating and marketing artist merchandise as an essential revenue stream.
          - Best practices for designing, pricing, and selling merchandise online and at live events.
          - Case studies on successful merchandising strategies employed by independent artists.
          - **Live Performances**
          - Analyzing the financial aspects of live performances, including booking, promotion, and ticket sales.
          - Strategies for negotiating favorable performance contracts and maximizing revenue from live shows.
          - Exploring alternative performance opportunities, such as house concerts and live-streamed events.
          - **Fan Funding and Crowdfunding**
          - Leveraging platforms like Patreon, Kickstarter, and GoFundMe for project funding and ongoing fan support.
          - Discussing best practices for creating compelling crowdfunding campaigns and rewards.
          - Case studies of artists who have successfully funded projects through crowdfunding.
          - **Implementation Steps**
          - Develop a range of merchandise items that align with your brand and fan preferences.
          - Create a live performance strategy that balances revenue potential and audience engagement.
          - Research and select the most appropriate fan funding or crowdfunding platform for your needs.
          ## 4. Diversifying Revenue Streams
          - **Brand Partnerships and Endorsements**
          - Exploring how artists can collaborate with brands for mutual benefit, such as sponsored content or product endorsements.
          - Navigating the legal and ethical considerations of brand partnerships.
          - Tips for identifying and pitching to potential brand partners.
          - **Sync Licensing**
          - Understanding the sync licensing process and how artists can generate income from placing their music in films, TV shows, advertisements, and video games.
          - Strategies for making your music more discoverable to music supervisors and licensing agencies.
          - Case studies of successful sync placements and their impact on artists' careers.
          - **Teaching and Workshops**
          - Turning expertise into educational opportunities for additional income, such as offering music lessons, masterclasses, or workshops.
          - Tips for developing engaging educational content and marketing your services.
          - Exploring online teaching platforms and resources for reaching a wider audience.
          - **Implementation Steps**
          - Identify brands that align with your values and target audience.
          - Create a sync licensing pitch package, including high-quality recordings and metadata.
          - Develop a teaching curriculum and promotional plan for your educational offerings.
          ## 5. Budgeting & Financial Planning
          - **Creating and Managing Budgets**
          - Step-by-step guide to creating effective budgets for projects (e.g., album releases, tours) and general living expenses.
          - Tips for prioritizing expenses and allocating funds based on career goals.
          - Tools and software recommendations for tracking finances and managing budgets.
          - **Financial Goal Setting**
          - The importance of setting short-term and long-term financial goals for your music career.
          - Strategies for breaking down larger goals into manageable milestones.
          - Case studies of artists who have successfully achieved their financial goals through effective planning.
          - **Cash Flow Management**
          - Understanding the importance of cash flow in a music career, especially when income may be irregular.
          - Strategies for maintaining a positive cash flow, such as diversifying income streams and minimizing unnecessary expenses.
          - Tips for managing cash flow during lean periods or between project payouts.
          - **Emergency Funds and Financial Cushions**
          - The importance of saving for unforeseen expenses or career disruptions.
          - Guidelines for determining how much to save in an emergency fund based on your individual circumstances.
          - Strategies for building and maintaining an emergency fund over time.
          - **Implementation Steps**
          - Create a comprehensive budget template for your music career, including income and expense categories.
          - Set specific, measurable financial goals for the next 6 months, 1 year, and 5 years.
          - Establish a separate savings account for your emergency fund and set up automatic contributions.
          ## 6. Long-term Financial Planning
          - **Investing for the Future**
          - An overview of investment strategies suitable for artists, including retirement accounts, stocks, and real estate.
          - Discussing the risks and benefits of various investment options.
          - Tips for starting small and gradually building an investment portfolio over time.
          - **Retirement Planning**
          - Understanding retirement saving options available to independent artists and musicians, such as SEP IRAs and Solo 401(k)s.
          - Strategies for determining how much to save for retirement based on your desired lifestyle and career trajectory.
          - Case studies of artists who have successfully planned for retirement while navigating the unique challenges of the music industry.
          - **Insurance**
          - Types of insurance policies music artists should consider, such as health insurance, instrument insurance, and liability insurance.
          - Discussing the importance of insurance in protecting your financial well-being and career assets.
          - Tips for finding affordable insurance options and navigating the enrollment process.
          - **Estate Planning**
          - The importance of estate planning for music artists, including creating a will and designating beneficiaries.
          - Overview of the key components of an estate plan, such as power of attorney and healthcare directives.
          - Resources for finding legal assistance with estate planning and understanding the unique considerations for artists.
          - **Implementation Steps**
          - Research investment options and open a retirement account suitable for your needs.
          - Assess your insurance needs and obtain necessary coverage.
          - Begin the estate planning process by creating a will and designating beneficiaries for your assets.
          ## 7. Navigating Taxes
          - **Tax Obligations for Music Artists**
          - Overview of tax responsibilities for self-employed artists, including income tax, self-employment tax, and estimated tax payments.
          - Understanding tax deductions available to artists, such as home office expenses and equipment purchases.
          - Discussion of state and local tax obligations, such as sales tax on merchandise sales.
          - **Record Keeping and Documentation**
          - The importance of maintaining accurate financial records for tax purposes.
          - Best practices for tracking income and expenses throughout the year.
          - Overview of documentation required for common tax deductions, such as receipts and mileage logs.
          - **Strategies for Tax Planning**
          - Tips for minimizing your tax liability through strategic planning, such as timing income and expenses.
          - Discussion of the benefits of working with a tax professional who specializes in the music industry.
          - Case studies of artists who have successfully navigated their tax obligations and minimized their liability.
          - **International Tax Considerations**
          - Overview of tax implications for income earned from international sources, such as touring or merchandise sales abroad.
          - Discussion of tax treaties and how they impact an artist's tax obligations.
          - Resources for finding guidance on international tax issues and ensuring compliance with foreign tax laws.
          - **Implementation Steps**
          - Set up a system for tracking income and expenses, such as using accounting software or a dedicated bank account.
          - Research and implement tax deductions applicable to your music career.
          - Consider working with a tax professional to develop a personalized tax strategy.
          ## 8. Financial Health Check-ups
          - **Regular Financial Reviews**
          - The importance of conducting regular financial health assessments to ensure you're on track to meet your goals.
          - Step-by-step guide to reviewing your financial situation, including assessing income, expenses, savings, and investments.
          - Tips for identifying areas for improvement and making necessary adjustments to your financial plan.
          - **Utilizing Financial Tools and Resources**
          - Overview of financial management tools and resources designed specifically for music artists, such as budgeting apps and royalty tracking software.
          - Discussion of the benefits of working with financial advisors, accountants, and other professionals who specialize in the music industry.
          - Case studies of artists who have successfully utilized financial tools and resources to improve their financial health and achieve their goals.
          - **Continuous Learning and Skill Development**
          - The importance of staying informed about financial trends and best practices in the music industry.
          - Resources for continuing your financial education, such as workshops, webinars, and online courses.
          - Tips for building a network of financial mentors and peers who can provide guidance and support throughout your career.
          - **Implementation Steps**
          - Schedule regular financial check-ins, such as quarterly or semi-annual reviews.
          - Research and implement financial tools and resources that align with your needs and goals.
          - Identify opportunities for continuous learning and skill development in financial management.
          ## 9. Resources for Further Learning
          - **Books and Publications**
          - Curated list of essential books on financial management for music artists, covering topics such as budgeting, investing, and taxes.
          - Recommendations for industry publications and blogs that provide ongoing coverage of financial trends and best practices in the music industry.
          - **Courses and Workshops**
          - Overview of online courses and in-person workshops designed to help music artists improve their financial literacy and management skills.
          - Recommendations for reputable course providers and educational institutions that offer specialized training for artists.
          - **Professional Organizations and Networks**
          - List of professional organizations and networks that provide resources and support for music artists navigating financial challenges, such as the Music Business Association and the American Association of Independent Music.
          - Discussion of the benefits of joining these organizations, such as access to industry events, mentorship opportunities, and collaborative projects.
          - **Financial Advisors and Coaches**
          - Overview of the role of financial advisors and coaches in helping music artists achieve their financial goals.
          - Tips for finding and working with financial professionals who specialize in the music industry, including what to look for in an advisor and how to establish a productive working relationship.
          - Case studies of artists who have successfully worked with financial advisors and coaches to improve their financial situation and achieve long-term success.
          - **Implementation Steps**
          - Create a reading list of recommended books and publications and set aside dedicated time for financial learning.
          - Research and enroll in courses or workshops that align with your learning goals and skill level.
          - Consider joining a professional organization or network to access additional resources and support.
          - Assess your need for personalized financial guidance and consider working with a financial advisor or coach.
          ---
          """

        :mental_wellness ->
          """
          # Comprehensive Syllabus for Mental Wellness for Music Artists
          ---
          ## A. Introduction to Mental Wellness for Music Artists
          ### 1. Understanding Mental Health in the Music Industry
          - **The Unique Challenges Faced by Music Artists**
          - An overview of the specific mental health challenges that music artists encounter, including high stress levels, irregular work schedules, financial instability, and the pressure to maintain a public image.
          - **The Importance of Mental Wellness for Career Longevity**
          - Emphasizing the significance of prioritizing mental well-being to ensure a sustainable and fulfilling career in the music industry. Highlighting the impact of mental health on creativity, productivity, and overall success.
          - **Breaking the Stigma Surrounding Mental Health**
          - Addressing the stigma associated with mental health issues in the music industry and the importance of creating a supportive and open environment for artists to seek help and share their experiences.
          ### 2. Stress Management Strategies
          - **Identifying Sources of Stress**
          - Helping artists recognize and understand the various sources of stress in their personal and professional lives, such as performance pressure, financial concerns, and interpersonal relationships.
          - **Developing Coping Mechanisms**
          - Introducing effective coping strategies for managing stress, including relaxation techniques, time management skills, and healthy outlet activities like exercise, journaling, or engaging in hobbies.
          - **Creating a Support System**
          - Encouraging artists to build a strong support network of family, friends, and industry professionals who can offer guidance, encouragement, and a listening ear during challenging times.
          ### 3. Maintaining Work-Life Balance
          - **Setting Boundaries**
          - Guiding artists on establishing clear boundaries between their personal and professional lives to prevent burnout and maintain a healthy work-life balance.
          - **Prioritizing Self-Care**
          - Emphasizing the importance of self-care practices, such as getting sufficient sleep, maintaining a balanced diet, and engaging in regular physical activity to promote overall well-being.
          - **Scheduling Time for Personal Life**
          - Encouraging artists to intentionally allocate time for personal relationships, hobbies, and relaxation to maintain a sense of balance and perspective outside of their music careers.
          ## B. Coping with Rejection and Criticism
          ### 1. Understanding the Nature of Rejection and Criticism
          - **The Inevitability of Rejection and Criticism**
          - Preparing artists for the reality of facing rejection and criticism as an inherent part of the music industry, and framing it as an opportunity for growth and learning.
          - **Separating Personal Worth from Professional Feedback**
          - Helping artists differentiate between their personal worth and the feedback they receive on their work, emphasizing that criticism of their music does not reflect their value as individuals.
          ### 2. Developing Resilience and Self-Confidence
          - **Cultivating a Growth Mindset**
          - Encouraging artists to adopt a growth mindset, viewing challenges and setbacks as opportunities for learning and improvement rather than personal failures.
          - **Practicing Self-Compassion**
          - Guiding artists in practicing self-compassion, being kind and understanding towards themselves in the face of difficulties, and avoiding harsh self-criticism.
          - **Celebrating Successes and Achievements**
          - Emphasizing the importance of acknowledging and celebrating personal successes and achievements, no matter how small, to build self-confidence and maintain motivation.
          ### 3. Constructively Processing Feedback
          - **Evaluating the Source and Context of Criticism**
          - Teaching artists to assess the credibility and relevance of the feedback they receive, considering the source's expertise and the context in which the criticism is given.
          - **Extracting Valuable Insights**
          - Encouraging artists to approach criticism with an open mind, looking for constructive feedback that can help them improve their craft and grow as professionals.
          - **Developing an Action Plan for Improvement**
          - Guiding artists in creating actionable plans based on the valuable insights gleaned from feedback, setting specific goals and strategies for personal and professional development.
          ## C. Maintaining Healthy Relationships
          ### 1. Building Supportive Professional Relationships
          - **Networking with Integrity**
          - Encouraging artists to build genuine, mutually beneficial relationships within the music industry based on shared values, respect, and support.
          - **Collaborating with Peers**
          - Highlighting the importance of collaborating with fellow artists, producers, and industry professionals to foster a sense of community, share knowledge, and create new opportunities.
          - **Establishing Boundaries in Professional Relationships**
          - Guiding artists in setting clear boundaries in their professional relationships to maintain a healthy work environment and prevent exploitation or burnout.
          ### 2. Nurturing Personal Relationships
          - **Prioritizing Quality Time with Loved Ones**
          - Encouraging artists to make time for meaningful connections with family and friends, recognizing the importance of these relationships for emotional well-being and support.
          - **Communicating Effectively**
          - Providing strategies for open and honest communication with loved ones, sharing the challenges and joys of their music careers, and expressing their needs and boundaries.
          - **Balancing Personal Relationships with Career Demands**
          - Offering guidance on navigating the challenges of balancing personal relationships with the demands of a music career, such as long hours, travel, and public scrutiny.
          ### 3. Navigating Conflict and Resolution
          - **Identifying the Root Causes of Conflict**
          - Teaching artists to recognize and understand the underlying factors contributing to conflicts in their personal and professional relationships.
          - **Practicing Active Listening and Empathy**
          - Encouraging artists to develop active listening skills and practice empathy when addressing conflicts, seeking to understand others' perspectives and emotions.
          - **Implementing Effective Conflict Resolution Strategies**
          - Providing practical strategies for resolving conflicts, such as finding common ground, compromising, and seeking professional mediation when necessary.
          ## D. Self-Care Practices for Musicians
          ### 1. Physical Self-Care
          - **Maintaining a Healthy Diet**
          - Guiding artists in developing healthy eating habits that support their physical and mental well-being, considering the unique challenges of a musician's lifestyle.
          - **Incorporating Regular Exercise**
          - Encouraging artists to engage in regular physical activity to reduce stress, improve mood, and maintain overall health, offering tips for integrating exercise into a busy schedule.
          - **Prioritizing Sleep and Rest**
          - Emphasizing the importance of adequate sleep and rest for mental and physical health, providing strategies for improving sleep quality and creating a restful environment.
          ### 2. Emotional and Mental Self-Care
          - **Practicing Mindfulness and Meditation**
          - Introducing artists to mindfulness and meditation techniques to help manage stress, improve focus, and cultivate emotional resilience.
          - **Engaging in Creative Outlets**
          - Encouraging artists to explore creative outlets beyond music, such as writing, visual arts, or crafts, as a means of self-expression and emotional processing.
          - **Seeking Professional Support**
          - Normalizing the practice of seeking professional mental health support, such as therapy or counseling, to address emotional challenges and maintain mental well-being.
          ### 3. Social Self-Care
          - **Building a Supportive Community**
          - Guiding artists in cultivating a supportive network of friends, family, and industry peers who can offer encouragement, understanding, and a sense of belonging.
          - **Participating in Peer Support Groups**
          - Encouraging artists to join or create peer support groups specifically for musicians, providing a safe space to share experiences, challenges, and coping strategies.
          - **Engaging in Meaningful Social Activities**
          - Promoting the importance of engaging in social activities outside of the music industry, such as volunteering, attending community events, or pursuing shared interests with friends.
          ## E. Managing Performance Anxiety
          ### 1. Understanding Performance Anxiety
          - **The Physiological and Psychological Components**
          - Explaining the physiological and psychological aspects of performance anxiety, including the body's stress response and the role of thoughts and beliefs in perpetuating anxiety.
          - **The Impact on Musical Performance**
          - Discussing the ways in which performance anxiety can affect musical performance, such as decreased technical accuracy, impaired creativity, and diminished stage presence.
          ### 2. Developing Coping Strategies
          - **Cognitive Restructuring Techniques**
          - Teaching artists to identify and challenge negative thought patterns related to performance, replacing them with more realistic and positive self-talk.
          - **Relaxation and Breathing Exercises**
          - Providing practical relaxation and breathing techniques that artists can use before and during performances to reduce physical tension and calm the mind.
          - **Visualization and Mental Rehearsal**
          - Guiding artists in using visualization and mental rehearsal techniques to prepare for performances, build confidence, and create a positive mental state.
          ### 3. Building Confidence and Resilience
          - **Focusing on Process over Perfection**
          - Encouraging artists to shift their focus from achieving perfection to engaging in the process of creating and sharing their music, embracing imperfections as part of the artistic journey.
          - **Celebrating Progress and Accomplishments**
          - Promoting the practice of acknowledging and celebrating personal progress and accomplishments, no matter how small, to build self-confidence and maintain motivation.
          - **Learning from Past Experiences**
          - Guiding artists in reflecting on past performances, both successful and challenging, to identify lessons learned and areas for growth, using these insights to inform future preparation and mindset.
          ## F. Substance Abuse Prevention and Recovery
          ### 1. Understanding Substance Abuse in the Music Industry
          - **The Prevalence and Risk Factors**
          - Discussing the high prevalence of substance abuse within the music industry, exploring the unique risk factors that contribute to this issue, such as stress, pressure, and easy access to drugs and alcohol.
          - **The Impact on Mental and Physical Health**
          - Highlighting the detrimental effects of substance abuse on an artist's mental and physical well-being, including the increased risk of addiction, depression, anxiety, and long-term health complications.
          ### 2. Prevention Strategies
          - **Educating on the Risks and Consequences**
          - Providing comprehensive education on the risks and consequences associated with substance abuse, empowering artists to make informed decisions about their health and well-being.
          - **Promoting Healthy Coping Mechanisms**
          - Encouraging artists to develop and utilize healthy coping mechanisms for stress and pressure, such as exercise, meditation, creative outlets, and seeking support from friends, family, or professionals.
          - **Creating a Supportive Environment**
          - Fostering a supportive and non-judgmental environment within the music community, promoting open communication and encouraging artists to seek help when needed.
          ### 3. Seeking Help and Recovery
          - **Recognizing Signs and Symptoms**
          - Educating artists on recognizing the signs and symptoms of substance abuse in themselves and others, emphasizing the importance of early intervention and seeking help.
          - **Accessing Professional Treatment**
          - Providing information on accessing professional treatment options, such as rehabilitation programs, therapy, and support groups specifically tailored to the needs of musicians.
          - **Maintaining Sobriety and Preventing Relapse**
          - Offering strategies for maintaining sobriety and preventing relapse, including building a strong support network, engaging in ongoing therapy or support groups, and developing a personalized recovery plan.
          ## G. Nurturing Creativity for Mental Well-being
          ### 1. Understanding the Link between Creativity and Mental Health
          - **The Therapeutic Benefits of Creative Expression**
          - Exploring the therapeutic benefits of creative expression, such as reducing stress, processing emotions, and promoting self-awareness and personal growth.
          - **The Importance of a Healthy Creative Process**
          - Emphasizing the significance of a healthy creative process that allows for experimentation, risk-taking, and self-expression without undue pressure or self-judgment.
          ### 2. Cultivating a Creative Mindset
          - **Embracing Curiosity and Openness**
          - Encouraging artists to nurture their curiosity and maintain an open mindset, seeking out new experiences, perspectives, and influences to fuel their creativity.
          - **Overcoming Creative Blocks**
          - Providing strategies for overcoming creative blocks, such as engaging in free-writing or improvisation, taking breaks, and seeking inspiration from diverse sources.
          - **Collaborating and Exchanging Ideas**
          - Promoting the value of collaborating with other artists and exchanging ideas, as this can stimulate creativity, provide fresh perspectives, and foster a sense of community and support.
          ### 3. Balancing Creativity and Self-Care
          - **Setting Realistic Goals and Expectations**
          - Guiding artists in setting realistic goals and expectations for their creative output, taking into account their mental and physical well-being and the need for rest and self-care.
          - **Prioritizing Self-Expression over External Validation**
          - Encouraging artists to prioritize self-expression and personal fulfillment in their creative pursuits, rather than solely seeking external validation or commercial success.
          - **Integrating Self-Care into the Creative Process**
          - Providing strategies for integrating self-care practices into the creative process, such as taking regular breaks, setting boundaries, and engaging in activities that promote mental and physical well-being.
          ## H. Mindfulness and Meditation Techniques
          ### 1. Introduction to Mindfulness and Meditation
          - **Understanding the Concepts and Benefits**
          - Explaining the basic concepts of mindfulness and meditation, highlighting their potential benefits for mental well-being, such as reduced stress, increased focus, and improved emotional regulation.
          - **Debunking Common Myths and Misconceptions**
          - Addressing common myths and misconceptions about mindfulness and meditation, such as the need for a quiet mind or a specific spiritual belief system, to make these practices more accessible and approachable.
          ### 2. Practical Mindfulness Exercises
          - **Breath Awareness and Relaxation Techniques**
          - Teaching simple breath awareness and relaxation techniques that artists can practice throughout their day to promote calmness, reduce stress, and improve focus.
          - **Body Scan and Progressive Muscle Relaxation**
          - Guiding artists through body scan and progressive muscle relaxation exercises, which involve systematically focusing on different parts of the body to release tension and promote relaxation.
          - **Mindful Movement and Stretching**
          - Incorporating mindful movement and stretching exercises, such as gentle yoga or tai chi, to help artists connect with their bodies, reduce physical tension, and cultivate a sense of presence.
          ### 3. Developing a Consistent Meditation Practice
          - **Exploring Different Meditation Styles**
          - Introducing various meditation styles, such as mindfulness meditation, loving-kindness meditation, or visualization, to help artists find a practice that resonates with their preferences and needs.
          - **Creating a Conducive Environment**
          - Providing guidelines for creating a supportive environment for meditation, including finding a quiet space, using comfortable seating or posture, and minimizing distractions.
          - **Integrating Meditation into Daily Life**
          - Offering strategies for integrating meditation into daily life, such as setting aside dedicated time for practice, using reminders or apps, and applying mindfulness principles to everyday activities.
          ## I. Seeking Professional Help and Support
          ### 1. Recognizing When to Seek Help
          - **Signs and Symptoms of Mental Health Challenges**
          - Educating artists on recognizing the signs and symptoms of common mental health challenges, such as depression, anxiety, or burnout, emphasizing the importance of early intervention.
          - **Overcoming Stigma and Barriers to Seeking Help**
          - Addressing the stigma and barriers that may prevent artists from seeking professional help, such as feelings of shame, fear of judgment, or concerns about confidentiality.
          ### 2. Types of Professional Support
          - **Therapy and Counseling**
          - Providing an overview of various therapy and counseling options, such as individual psychotherapy, cognitive-behavioral therapy (CBT), or group therapy, and their potential benefits for addressing mental health concerns.
          - **Coaching and Mentoring**
          - Discussing the role of coaching and mentoring in supporting artists' personal and professional development, offering guidance, accountability, and a safe space to explore challenges and goals.
          - **Support Groups and Peer Networks**
          - Highlighting the value of joining support groups or peer networks specifically designed for musicians, where artists can share experiences, learn from others, and find a sense of community and understanding.
          ### 3. Accessing Resources and Services
          - **Finding Qualified Mental Health Professionals**
          - Providing guidance on finding qualified mental health professionals who specialize in working with artists or have experience addressing the unique challenges faced by those in the music industry.
          - **Navigating Insurance and Financial Considerations**
          - Offering information on navigating insurance coverage for mental health services, as well as exploring affordable or sliding-scale treatment options for artists with limited financial resources.
          - **Utilizing Online Resources and Helplines**
          - Compiling a list of reputable online resources, helplines, and crisis support services that artists can access for information, guidance, or immediate assistance when needed.
          ## J. Mental Health Resources for Music Artists
          ### 1. Industry-Specific Organizations and Initiatives
          - **Music Industry Mental Health Organizations**
          - Providing a comprehensive list of organizations dedicated to supporting the mental health and well-being of music industry professionals, such as Music Minds Matter, Backline, and Tour Support.
          - **Mental Health Workshops and Training Programs**
          - Highlighting workshops, webinars, and training programs designed to educate artists and industry professionals on mental health topics, coping strategies, and self-care practices.
          ### 2. Online Communities and Support Networks
          - **Social Media Groups and Forums**
          - Identifying supportive social media groups and forums where artists can connect with peers, share experiences, and find encouragement and advice related to mental health and well-being.
          - **Artist-Led Initiatives and Campaigns**
          - Showcasing artist-led initiatives and campaigns that aim to raise awareness about mental health in the music industry, break stigmas, and promote a culture of support and understanding.
          ### 3. Educational Resources and Self-Help Tools
          - **Books, Podcasts, and Documentaries**
          - Curating a list of recommended books, podcasts, and documentaries that address mental health topics relevant to music artists, offering insights, strategies, and personal stories of resilience.
          - **Mental Health Apps and Online Tools**
          - Providing a selection of mental health apps and online tools that artists can use to track their moods, practice mindfulness, manage stress, or access professional support remotely.
          ## K. Case Studies and Success Stories
          ### 1. Artists Sharing Their Mental Health Journeys
          - **Personal Narratives and Interviews**
          - Featuring personal narratives and interviews with artists who have openly discussed their mental health challenges, coping strategies, and paths to recovery, offering inspiration and reassurance to others facing similar struggles.
          - **Lessons Learned and Advice for Fellow Artists**
          - Highlighting the key lessons learned and advice shared by artists who have navigated mental health challenges, emphasizing the importance of self-care, seeking support, and maintaining a balanced perspective.
          ### 2. Successful Interventions and Support Programs
          - **Music Industry Mental Health Initiatives**
          - Showcasing successful mental health initiatives and support programs within the music industry, such as peer support networks, mentorship programs, or industry-wide awareness campaigns.
          - **Positive Outcomes and Impact on Artist Well-being**
          - Discussing the positive outcomes and impact of these interventions and support programs on artist well-being, creativity, and career sustainability, emphasizing the importance of a proactive and supportive approach to mental health.
          ### 3. Strategies for Maintaining Mental Wellness
          - **Insights from Mental Health Professionals**
          - Sharing insights and recommendations from mental health professionals who specialize in working with music artists, offering evidence-based strategies for maintaining mental wellness throughout one's career.
          - **Practical Tips and Habits for Long-Term Well-being**
          - Providing practical tips and habits that artists can incorporate into their daily lives to promote long-term mental well-being, such as regular self-reflection, boundary-setting, and cultivating a balanced lifestyle.
          ## L. Developing a Personal Mental Wellness Plan
          ### 1. Assessing Your Mental Health Needs
          - **Self-Reflection and Identifying Stressors**
          - Guiding artists through a process of self-reflection to identify their unique mental health needs, stressors, and triggers, establishing a foundation for developing a personalized wellness plan.
          - **Evaluating Current Coping Strategies**
          - Encouraging artists to evaluate their current coping strategies, recognizing both effective and ineffective approaches to managing stress and maintaining mental well-being.
          ### 2. Setting Goals and Priorities
          - **Defining Short-Term and Long-Term Objectives**
          - Assisting artists in defining clear, achievable short-term and long-term mental wellness goals, prioritizing areas for improvement and growth.
          - **Creating a Realistic Action Plan**
          - Guiding artists in creating a realistic action plan to achieve their mental wellness goals, breaking down larger objectives into smaller, manageable steps and establishing a timeline for implementation.
          ### 3. Implementing and Monitoring Progress
          - **Incorporating Wellness Strategies into Daily Life**
          - Providing guidance on effectively incorporating chosen wellness strategies and self-care practices into daily life, considering the unique demands and challenges of a music career.
          - **Tracking Progress and Adjusting as Needed**
          - Encouraging artists to regularly monitor their progress, celebrate successes, and make adjustments to their mental wellness plan as needed, fostering a flexible and adaptable approach to self-care.
          - **Seeking Accountability and Support**
          - Emphasizing the importance of seeking accountability and support from trusted friends, family members, or professionals in implementing and maintaining a personal mental wellness plan, creating a network of encouragement and guidance.
          ---
          """

        :contract_analyzer ->
          """
          # Comprehensive Syllabus for Contract Analysis
          ---
          ## 1. Understanding Contract Fundamentals
          ### Introduction to Music Contracts
          - The importance of contracts in the music industry
          - How contracts define relationships, obligations, and rights
          ### Types of Music Contracts
          - Recording contracts
          - Publishing contracts
          - Management contracts
          - Live performance contracts
          - Sync licensing contracts
          ### Key Components of a Contract
          - Parties involved
          - Term and duration
          - Scope of rights granted
          - Compensation and royalties
          - Termination clauses
          - Dispute resolution mechanisms

          ## 2. Analyzing Contract Terms
          ### Deciphering Legal Language
          - Understanding legal terminology and jargon
          - Identifying key clauses and their implications
          ### Interpreting Royalty Clauses
          - Types of royalties (mechanical, performance, sync, etc.)
          - Royalty rates and calculations
          - Deductions and withholdings
          ### Understanding Advance Payments
          - Purpose and structure of advances
          - Recoupment and its impact on royalties
          ### Examining Option Clauses
          - Definition and purpose of option clauses
          - Implications for future works and creative control
          ### Analyzing Exclusivity Terms
          - Scope and duration of exclusivity
          - Limitations on outside projects and collaborations
          ### Assessing Creative Control Provisions
          - Approval rights for music, artwork, and branding
          - Creative decision-making processes

          ## 3. Spotting Problematic Clauses
          ### Identifying Red Flags
          - Overly broad or vague language
          - One-sided terms favoring the company
          - Unreasonable demands or restrictions
          ### Unfair Royalty Splits
          - Disproportionate royalty allocations
          - Excessive deductions and fees
          ### Excessive Contract Lengths
          - Long-term commitments limiting career flexibility
          - Lack of options for early termination
          ### Perpetual Rights Clauses
          - Granting rights in perpetuity
          - Challenges in regaining control over works
          ### Broad Recoupment Terms
          - Expansive definitions of recoupable expenses
          - Prolonged periods of recoupment
          ### Restrictive Non-Compete Clauses
          - Limitations on working with other parties
          - Constraints on creative output and opportunities

          ## 4. Financial Implications
          ### Royalty Calculations and Deductions
          - Understanding royalty statements
          - Identifying allowable deductions and their impact
          ### Recoupment and Its Impact on Earnings
          - How advances are recouped from royalties
          - The effect of recoupment on cash flow and income
          ### Hidden Costs and Expenses
          - Identifying often-overlooked expenses
          - Strategies for minimizing and managing costs
          ### Cross-Collateralization Clauses
          - Definition and implications of cross-collateralization
          - Potential impact on overall earnings
          ### Audit Rights and Limitations
          - The importance of audit rights
          - Common limitations and restrictions on audits

          ## 5. Legal Considerations
          ### Intellectual Property Rights
          - Copyright ownership and control
          - Trademarks and branding rights
          ### Copyright Ownership and Transfers
          - Understanding copyright law basics
          - Transfer of rights and ownership provisions
          ### Termination Clauses and Consequences
          - Grounds for termination
          - Notice periods and procedures
          - Impact on rights and obligations post-termination
          ### Dispute Resolution Mechanisms
          - Arbitration vs. litigation
          - Choice of law and jurisdiction clauses
          ### Force Majeure Provisions
          - Definition and scope of force majeure events
          - Implications for performance obligations

          ## 6. Negotiation Strategies
          ### Preparing for Contract Negotiations
          - Setting clear goals and priorities
          - Researching industry standards and benchmarks
          ### Identifying Negotiable Terms
          - Recognizing which terms are open to negotiation
          - Prioritizing key issues for negotiation
          ### Proposing Alternative Clauses
          - Crafting language that balances interests
          - Presenting alternative solutions to problematic terms
          ### Leveraging Industry Standards
          - Using industry norms to support negotiation positions
          - Comparing terms to successful deals in the market
          ### Seeking Professional Advice
          - Knowing when to involve legal counsel or other experts
          - Benefits of having experienced advisors in negotiations

          ## 7. Protection Measures
          ### Importance of Legal Representation
          - The role of music attorneys in contract review
          - Ensuring comprehensive legal protection
          ### Conducting Due Diligence
          - Researching the reputation and track record of companies
          - Identifying potential risks and red flags
          ### Maintaining Accurate Records
          - Keeping thorough documentation of agreements and communications
          - Organizing and safeguarding important contracts and documents
          ### Exercising Audit Rights
          - Regularly reviewing royalty statements and payments
          - Conducting audits to ensure accurate accounting
          ### Staying Informed on Industry Practices
          - Keeping abreast of changes in industry standards and deal terms
          - Networking with peers and industry associations for knowledge sharing
          ---
          """

        :production ->
          """
          # Comprehensive Syllabus for Music Production
          ---
          ## A. Recording
          ### 1. Studio Recording Basics
          - Understanding the recording process and signal flow
          - Types of recording studios and their components
          - Introduction to microphones, preamps, and audio interfaces
          - Basic studio etiquette and communication

          ### 2. Home Studio Recording
          - Essential equipment for a home studio setup
          - Optimizing your recording space for best results
          - Budget-friendly solutions for recording at home
          - Tips for achieving professional-sounding recordings in a home studio

          ### 3. Microphone Techniques
          - Types of microphones and their applications
          - Microphone placement techniques for various instruments and vocals
          - Stereo recording techniques (XY, ORTF, MS)
          - Using room microphones for capturing ambience and natural reverb

          ### 4. Recording Vocals
          - Preparing for a vocal recording session
          - Microphone selection and placement for vocals
          - Creating the right environment for vocal recording
          - Coaching and directing vocal performances

          ### 5. Recording Instruments
          - Microphone techniques for specific instruments (guitars, drums, piano, etc.)
          - Direct Input (DI) recording for electric instruments
          - Recording acoustic instruments in various settings
          - Experimenting with creative recording techniques

          ### 6. Live Recording
          - Capturing live performances in the studio
          - Recording live concerts and events
          - Dealing with challenges in live recording situations
          - Post-production techniques for live recordings

          ## B. Studio Setup
          ### 1. Home Studio Essentials
          - Computer and Digital Audio Workstation (DAW) requirements
          - Essential hardware components (audio interface, monitors, headphones)
          - Acoustic treatment considerations for home studios
          - Cable management and organization tips

          ### 2. Professional Studio Equipment
          - High-end microphones, preamps, and outboard gear
          - Mixing consoles and control surfaces
          - Professional monitoring systems and room acoustics
          - Patchbays and signal routing in professional studios

          ### 3. Acoustic Treatment
          - Understanding room acoustics and their impact on recordings
          - Types of acoustic treatment materials (absorbers, diffusers, bass traps)
          - DIY acoustic treatment solutions
          - Placement and optimization of acoustic treatment

          ### 4. Studio Monitoring
          - Choosing the right studio monitors for your setup
          - Monitor placement and positioning for optimal listening
          - Calibrating your monitoring system
          - Headphone monitoring and mixing

          ### 5. Signal Flow and Routing
          - Understanding signal flow in a recording studio
          - Setting up proper gain staging and levels
          - Routing signals through hardware and software
          - Using patchbays and virtual routing in DAWs

          ## C. Production Techniques
          ### 1. Editing and Arranging
          - Basic editing techniques (cutting, copying, pasting)
          - Arranging and structuring songs in a DAW
          - Comping and consolidating multiple takes
          - Creative editing techniques for unique sounds

          ### 2. MIDI Programming
          - Introduction to MIDI and its applications in music production
          - Programming realistic MIDI instruments
          - Quantization and groove techniques
          - MIDI automation and parameter control

          ### 3. Sampling and Synthesis
          - Understanding sampling and its creative possibilities
          - Designing sounds using synthesis techniques
          - Layering and manipulating samples
          - Legal considerations and clearing samples

          ### 4. Creating Beats
          - Drum programming techniques
          - Using drum loops and one-shots
          - Creating unique rhythms and grooves
          - Layering and processing drum sounds

          ### 5. Sound Design
          - Crafting unique sounds using synthesis and processing
          - Creating soundscapes and textures
          - Designing sound effects for music production
          - Resampling and manipulating audio for sound design

          ### 6. Automation
          - Using automation to add movement and interest to productions
          - Volume, panning, and effect automation techniques
          - Automating MIDI parameters and plugin settings
          - Creative uses of automation for transitions and build-ups

          ## D. Software and Technology
          ### 1. Digital Audio Workstations (DAWs)
          - Overview of popular DAWs (Pro Tools, Ableton Live, Logic Pro, etc.)
          - Choosing the right DAW for your needs
          - Navigating and customizing your DAW
          - Workflow tips and tricks for efficient production

          ### 2. Virtual Instruments and Plugins
          - Types of virtual instruments (samplers, synthesizers, drum machines)
          - Working with effect plugins (EQ, compression, reverb, delay)
          - Plugin management and organization
          - Creative use of plugins for sound design and processing

          ### 3. Hardware Controllers and Interfaces
          - Using MIDI controllers for hands-on control
          - Integrating hardware synths and drum machines
          - Audio interfaces and their features
          - Control surfaces for mixing and production

          ### 4. Music Production Apps
          - Mobile apps for music production and idea generation
          - Integrating mobile devices into your production workflow
          - Cloud-based collaboration and production tools
          - Using apps for live performance and DJing

          ### 5. File Management and Organization
          - Effective file management strategies for music projects
          - Naming conventions and folder structures
          - Backing up and archiving projects
          - Collaborating and sharing files with other producers

          ## E. Mixing
          ### 1. Mixing Basics
          - Understanding the role of mixing in music production
          - Balancing levels and panning
          - Using EQ to shape and sculpt sounds
          - Applying compression for dynamic control

          ### 2. Mixing Vocals
          - EQ techniques for vocals
          - Compression and de-essing for vocal control
          - Using reverb and delay effects on vocals
          - Automation techniques for vocal mixing

          ### 3. Mixing Instruments
          - EQ and compression techniques for specific instruments
          - Balancing and placing instruments in the stereo field
          - Creating space and depth with reverb and delay
          - Mixing drums and bass for impact and low-end control

          ### 4. Mixing Techniques (EQ, Compression, etc.)
          - Advanced EQ techniques (filters, shelving, notching)
          - Multiband and sidechain compression techniques
          - Parallel processing and New York compression
          - Creative mixing techniques (distortion, saturation, modulation effects)

          ### 5. Mixing for Different Genres
          - Genre-specific mixing approaches (rock, hip-hop, electronic, etc.)
          - Adapting your mixing style to suit different genres
          - Referencing commercial tracks for mix balance and sound
          - Catering to genre-specific expectations and trends

          ### 6. Mixing for Stereo and Surround Sound
          - Understanding stereo imaging and width
          - Mixing techniques for immersive stereo experiences
          - Introduction to surround sound formats
          - Considerations for mixing in surround sound

          ## F. Mastering
          ### 1. Mastering Basics
          - Understanding the role of mastering in music production
          - Signal flow and equipment used in mastering
          - Preparing your mix for mastering
          - Listening critically and identifying areas for improvement

          ### 2. Mastering Techniques
          - EQ and compression techniques for mastering
          - Stereo enhancement and imaging
          - Limiting and maximizing for loudness
          - Dithering and bit depth reduction

          ### 3. Mastering for Different Media (Streaming, CD, Vinyl)
          - Optimizing masters for streaming platforms
          - Preparing masters for CD replication
          - Vinyl mastering considerations and techniques
          - Loudness normalization and metering standards

          ### 4. Online Mastering Services
          - Overview of online mastering services
          - Advantages and limitations of online mastering
          - Preparing your files for online mastering
          - Choosing the right online mastering service for your needs

          ### 5. DIY Mastering
          - In-the-box mastering techniques using plugins
          - Mastering with analog emulation plugins
          - DIY mastering vs. professional mastering services
          - Common pitfalls and mistakes to avoid in DIY mastering

          ## G. Collaboration
          ### 1. Remote Collaboration Tools
          - Cloud-based collaboration platforms for music production
          - File sharing and version control for collaborative projects
          - Video conferencing and screen sharing for remote sessions
          - Real-time collaboration tools and plugins

          ### 2. File Sharing and Project Management
          - Strategies for effective file sharing and organization
          - Project management tools for collaborative productions
          - Version control and backup solutions
          - Establishing file naming conventions and folder structures

          ### 3. Communication Strategies
          - Effective communication techniques for remote collaboration
          - Setting clear goals, deadlines, and expectations
          - Providing constructive feedback and critique
          - Resolving creative differences and conflicts

          ### 4. Working with Other Musicians and Producers
          - Collaborating with musicians remotely
          - Producing and arranging for other artists
          - Collaborating with co-producers and beatmakers
          - Navigating creative partnerships and agreements

          ### 5. Collaborating with Mixing and Mastering Engineers
          - Preparing files and sessions for mixing and mastering
          - Communicating mix notes and revisions
          - Understanding the role of mixing and mastering engineers
          - Building long-term relationships with mixing and mastering professionals

          ## H. Additional Topics
          ### 1. Music Theory for Producers
          - Basic music theory concepts (scales, chords, intervals)
          - Harmonic progression and chord substitution
          - Rhythm and meter in music production
          - Applying music theory to composition and arranging

          ### 2. Creative Workflows and Inspiration
          - Developing a creative mindset and overcoming writer's block
          - Techniques for generating ideas and starting projects
          - Workflow optimization and time management strategies
          - Staying inspired and motivated throughout the production process

          ### 3. Sound Synthesis Techniques
          - Subtractive, additive, and FM synthesis
          - Wavetable and granular synthesis
          - Modulation and automation techniques for synthesis
          - Creating unique synth patches and sounds

          ### 4. Remixing and Bootlegs
          - Approaches to remixing and bootleg production
          - Obtaining stems and acapellas for remixing
          - Creative reinterpretation and rearrangement techniques
          - Legal considerations and obtaining permissions for remixes

          ### 5. Producing for Film, TV, and Games
          - Understanding the role of music in visual media
          - Composing and producing for specific scenes and moods
          - Working with directors and audio supervisors
          - Delivery formats and technical requirements for media projects

          ### 6. Live Performance and DJing with Production Software
          - Integrating live instruments and vocals with electronic production
          - Performing and DJing with Ableton Live and other software
          - Designing live sets and performances
          - Synchronizing visuals and lighting with music production software
          ---
          """

        _ ->
          "General recommendations for a well-rounded music artist"
      end

    content = """
    Given:
    1. A detailed subject syllabus (<syllabus>) concerning a specific subject of the music industry, things a well-rounded music artist should know (and advice regarding that subject).
    2. A comprehensive music artist biography (<artist_biography>).

    Your task is to create a personalized insights sheet for the music artist for the given subject with personalized recommendations to improve in that area. Use the syllabus and the artist biography to create a set of personalized, actionable, and useful recommendations. The insights sheet should be tailored to the artist based on their biography.

    Please follow these guidelines for the output:
    - Output must be in a easy-to-read HTML object string organized properly. Need to include ```html and DOCTYPE, plus the other common tags in html needed (head, body, etc). Make sure to bold any headings.
    - Focus solely on including recommendations.
    - Provide the recommendations in a concise format, ideally fitting within two pages of text.
    - Employ step-by-step thinking using chain of thought reasoning to ensure the recommendations are highly personalized and actionable for the artist according to their biography.

    Here are the details you'll base your recommendations on:

    <artist_biography>\n#{artist_description}\n</artist_biography>

    <syllabus>\n#{syllabus}\n</syllabus>
    """

    # TODO: log content to make sure string is formatted correctly
    msgs = [
      %ExOpenAI.Components.ChatCompletionRequestUserMessage{
        role: :user,
        content: content
      }
    ]

    model = Application.get_env(:mic, :model) || "gpt-4o"

    case ExOpenAI.Chat.create_chat_completion(msgs, model) do
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

    model = Application.get_env(:mic, :model) || "gpt-4o"

    case ExOpenAI.Chat.create_chat_completion(msgs, model) do
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
