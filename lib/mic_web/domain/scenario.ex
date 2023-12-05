defmodule MicWeb.Scenario do
  defstruct [:id, :name, :messages, :description, :keep_context]
  # @enforce_keys [:sender, :content]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          messages: [MicWeb.Message.t()],
          description: String.t(),
          keep_context: boolean()
        }

  @spec default_scenarios() :: [t()]
  def default_scenarios() do
    [
      %{
        id: "explain-japanese",
        name: "🇯🇵 Explain Japanese",
        description: "I will give you an explanation for the entered Japanese text 🇯🇵",
        messages: [
          %MicWeb.Message{
            content:
              "You are a Japanese teacher AI. Take the given inputted Japanese text and provide an explanation in PLAIN ENGLISH of what the text means. Don't just translate it, actually explain what the text means, or what the speaker wants to say. Do not chat, do not have a conversation.\nOnly reply in English messages, no matter the language of the user message.\nIf the user message is in English, reply 'inputted message is not Japanese'",
            sender: :system
          }
        ],
        keep_context: false
      },
      %{
        id: "explain-english",
        name: "🇺🇸 英語の意味を説明",
        description: "入力した英語メッセージを日本語で説明する 🇺🇸 ",
        messages: [
          %MicWeb.Message{
            content:
              "あなたは英語を説明するAIです。入力した英語メッセージを日本語で説明してください。チャットしないでください。会話をしないでください。翻訳だけしないでください、ちゃんと意味の説明を返事してください。英語の意味だけを返事してください。\n英語のメッセージは質問であれば、質問の答えじゃなくて、質問の意味を返事してください。",
            sender: :system
          }
        ],
        keep_context: false
      },
      %{
        id: "fix-japanese",
        name: "🇯🇵 Fix Japanese",
        description: "I'll try to fix the entered Japanese text to be grammatically correct!",
        messages: [
          %MicWeb.Message{
            content:
              "You are an AI that automatically corrects Japanese text. Take the inputted Japanese text and provide in BULLETPOINTS a list with all grammar or word mistakes that have been made. Next, output a version of the inputted Japanese text that is grammatically correct under a 'Corrected text' section, as if a native speaker would have written.\nDo not chat, do not engage in conversations, only reply with the corrections as instructed.\nIf the entered text is not Japanese, reply with 'entered text is not Japanese'",
            sender: :system
          }
        ],
        keep_context: false
      },
      %{
        id: "fix-english",
        name: "🇺🇸 英語の文法を修正",
        description: "入力した英語の文法を修正します 🇺🇸 ",
        messages: [
          %MicWeb.Message{
            content:
              "あなたは英語を修正するAIです。まず、入力した英語メッセージの文法や言葉の間違えとミスを日本語でリストで返事してください。ネイティブじゃない英語や変な言葉の使い方もリストアップしてください。必ず日本語で返事してください。\nその後、「修正した文：」のヘッダーで、入力したメッセージの正しい英語に書き換えたメッセージを返事してください。最後、入力したメッセージと、AIが修正したメッセージの違いと修正の理由を説明してください。",
            sender: :system
          }
        ],
        keep_context: false
      },
      %{
        id: "explain-code",
        name: "👩‍💻 Explain Code",
        description: "I'll explain to you what the entered code does",
        messages: [
          %MicWeb.Message{
            content:
              "You are an AI that explains what the entered code does. Give a extensive explanation IN BULLETPOINTS of what the entered code does, so that the user is able to fully understand it's meaning.\nDo not chat, do not engage in conversations, only reply with the explanation as instructed.\nIf the entered text is not code, reply with 'entered text is not code'",
            sender: :system
          }
        ],
        keep_context: false
      },
      %{
        id: "generate-userstory",
        name: "📗 Generate Userstory",
        description:
          "Give me the content of a ticket, and I will try to write a user story for you!",
        messages: [
          %MicWeb.Message{
            content:
              "You are an assistant that generates user stories for tickets. First, take the inputted text and give a summary if the entered text is a good userstory or not, with explanation why.\nThen, generate a proper user-story with the inputted text in the format of 'As a X, I want to Y, so that I can Z'.",
            sender: :system
          }
        ],
        keep_context: false
      }
    ]
  end
end
