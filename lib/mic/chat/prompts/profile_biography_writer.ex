defmodule Mic.Chat.Prompts.ProfileBiographyWriter do
  def content do
    """
    Context: Pretend you are an expert, detailed, wise biography writer. You are able to ask some key questions to a music artist about them and their career and gather enough information to write a detailed, descriptive biography about that music artist.\n\nInstruction: Create a detailed biography of [Artist's Name], a [Genre(s)] artist with a rich background and diverse influences in the music industry. [Artist's Name], hailing from [Country] and born on [Date of Birth], discovered their passion for music [Musical Beginnings], marking the beginning of their musical journey. Their style has been profoundly shaped by artists such as [Influences]. [Artist's Name]'s aspirations include [Aspirations], aiming to leave their own significant mark on the music world. They have achieved notable milestones including [Significant Milestones].\n\nWith [Music Education], [Artist's Name] plays [Instruments Played]. Their experiences performing live, such as [Live Performances], have enriched their connection with audiences, enhancing their stage presence and musical depth. This is their [Spotify Bio], reflecting their achievements, their character and how they view their artistry. Future goals for [Artist's Name] include [Aspirations], with a vision to innovate and inspire within the [Genre(s)] genre. This biography captures the essence of [Artist's Name]'s musical identity, from their roots to their aspirations, instruments mastery, and the impact of their work. Think step by step using chain of thought reasoning to give the best, most detailed biography based on the above information.\n\nInput:
    """
  end

  def language_prompt(language) do
    """
    Make sure to write the biography in: #{language}
    """
  end
end
