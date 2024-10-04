# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :mic, Oban,
  repo: Mic.Repo,
  queues: [default: 10]

config :mic,
  title: "MIC",
  ecto_repos: [Mic.Repo],
  generators: [timestamp_type: :utc_datetime],
  # TODO: remove, make dynamic
  # or gpt-3.5-turbo
  # gpt-4-turbo-preview
  # gpt-4-turbo
  # TODO: can remove these 2 lines below
  # TODO: implement mechanism for free vs paid plan
  model: "gpt-4o-2024-08-06",
  enabled_models: ["gpt-3.5-turbo", "davinci"],
  default_model: :"gpt-4o-2024-08-06",
  models: [
    %{
      id: :"gpt-4o-mini",
      provider: :openai,
      truncate_tokens: 127_000,
      name: "GPT4 Omni Mini (OpenAI)"
    },
    %{
      id: :"gpt-4o-2024-08-06",
      provider: :openai,
      truncate_tokens: 127_000,
      name: "GPT4 Omni 2024-08-06 (OpenAI)"
    },
    %{
      id: :"gpt-4o",
      provider: :openai,
      truncate_tokens: 127_000,
      name: "GPT4 Omni (OpenAI)"
    },
    %{
      id: :"gpt-4-turbo",
      provider: :openai,
      truncate_tokens: 127_000,
      name: "GPT4 Turbo (OpenAI)"
    },
    %{
      id: :"gpt-4-turbo-preview",
      provider: :openai,
      truncate_tokens: 127_000,
      name: "GPT4 Turbo Preview (OpenAI)"
    },
    %{
      id: :"gpt-4",
      truncate_tokens: 8000,
      provider: :openai,
      name: "GPT4 (OpenAI)"
    },
    %{
      id: :"gpt-3.5-turbo",
      provider: :openai,
      truncate_tokens: 15000,
      name: "GPT3.5 Turbo (OpenAI)"
    },
    %{
      id: :"gpt-3.5-turbo-16k",
      provider: :openai,
      truncate_tokens: 15000,
      name: "GPT3.5 Turbo 16k (OpenAI)"
    },
    %{
      id: :"anthropic.claude-3-5-sonnet-20240620-v1:0",
      provider: :anthropic,
      truncate_tokens: 100_000,
      name: "Claude 3.5 Sonnet (Anthropic)"
    },
    %{
      id: :"anthropic.claude-3-opus-20240229-v1:0",
      provider: :anthropic,
      truncate_tokens: 100_000,
      name: "Claude 3 Opus (Anthropic)"
    },
    %{
      id: :"anthropic.claude-3-sonnet-20240229-v1:0",
      provider: :anthropic,
      truncate_tokens: 100_000,
      name: "Claude 3 Sonnet (Anthropic)"
    },
    %{
      id: :"gemini-1.0-pro",
      provider: :google,
      truncate_tokens: 100_000,
      name: "Gemini Pro (Google)"
    }
  ],
  # TODO: change to true below
  enable_google_oauth: false,
  restrict_email_domains: false,
  allowed_email_domains: ["google.com"]

# Configures the endpoint
# TODO: remove pubsub use in app
config :mic, MicWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Phoenix.Endpoint.Cowboy2Adapter,
  render_errors: [
    formats: [html: MicWeb.ErrorHTML, json: MicWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Mic.PubSub,
  live_view: [signing_salt: "tiGUbjXh"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :mic, Mic.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.3.2",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
