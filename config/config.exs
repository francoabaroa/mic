# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :mic,
  ecto_repos: [Mic.Repo],
  generators: [timestamp_type: :utc_datetime],
  # TODO: remove
  # or gpt-3.5-turbo
  # gpt-4-turbo-preview
  model: "gpt-3.5-turbo",
  enabled_models: ["gpt-3.5-turbo", "davinci"],
  default_model: :"gpt-3.5-turbo",
  models: [
    %{
      id: :"gpt-4-turbo-preview",
      truncate_tokens: 127_000
    },
    %{
      id: :"gpt-4",
      truncate_tokens: 8000
    },
    %{
      id: :"gpt-3.5-turbo",
      truncate_tokens: 15000
    },
    %{
      id: :davinci,
      truncate_tokens: 2200
    },
    %{
      id: :"gpt-3.5-turbo-16k",
      truncate_tokens: 15000
    }
  ],
  # TODO: change to true below
  enable_google_oauth: false,
  restrict_email_domains: false,
  allowed_email_domains: ["google.com"]

# Configures the endpoint
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
