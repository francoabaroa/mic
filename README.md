# Mic

Mic is Incurator's Phoenix application for artist onboarding and music-career
guidance. It provides accounts and preferences, personalized artist profiles,
scenario-based chat, voice input/output, document analysis, and educational
resources. WhatsApp and music-platform integrations are also present, at varying
stages of completion.

## Stack and prerequisites

- Elixir/Phoenix with LiveView, Ecto and PostgreSQL; Oban for background jobs.
- Rust/Cargo and a native C build toolchain for document parsing and bcrypt.
- Node.js 18+ and npm for frontend dependencies and JavaScript regression tests.
- Tailwind CSS, DaisyUI and esbuild for assets.

The checked-in runtime versions differ: [`.tool-versions`](.tool-versions) specifies
Elixir **1.14.2 / OTP 26.0.2**, while the [Dockerfile](Dockerfile) uses
**1.16.1 / OTP 26.2.1**. These have not been reconciled. The locked Credo dependency
fails to compile on the tested host's Elixir 1.18.4 / OTP 28 runtime; see
[validation status](#validation-status) before assuming a fresh setup is green.

## Local setup

1. Start local PostgreSQL. Connection settings are in
   [`config/dev.exs`](config/dev.exs) and [`config/test.exs`](config/test.exs):
   `localhost`, username/password `postgres`, databases `mic_dev` and `mic_test`.
2. For a new checkout, copy [`.env.example`](.env.example) to `.env` and fill in
   `OPENAI_API_KEY` and `OPENAI_ORGANIZATION_KEY`. Runtime configuration currently
   requires both in every environment, including tests. `.env` is gitignored.
3. Remove the `export ..._ENV_SET=` lines for integrations you are not configuring.
   An empty exported value still enables its configuration block. If you already
   loaded the unedited example, unset those switches first:

   ```sh
   unset CHARTMETRIC_ENV_SET SPOTIFY_ENV_SET INSTAGRAM_ENV_SET WHATSAPP_ENV_SET
   ```

4. Load your edited environment file, install dependencies and start the app:

   ```sh
   source .env
   mix local.hex --force
   mix local.rebar --force
   npm install --prefix assets
   mix setup
   mix phx.server
   ```

Open [localhost:4000](http://localhost:4000). The app does not load `.env`
automatically. `mix setup` installs Elixir dependencies, creates/migrates the
development database, runs seeds and builds assets. Rustler compiles native code.
Startup also downloads/caches the `bert-base-multilingual-uncased` tokenizer;
`TOKENIZER_CACHE_DIR` overrides its cache directory. Chat, voice and integration
flows require their configured providers.

Use the package manifest in `assets/` for frontend setup. The older root manifest
has different versions and is not the Docker build's installation path.

## Code map

| Location | Responsibility |
| --- | --- |
| `lib/mic/application.ex` | Supervision, database, jobs, HTTP client, tokenizer and ETS |
| `lib/mic/accounts*` | Users, passwords, session/email tokens and preferences |
| `lib/mic/artists*` | Artist profiles, resources and music-platform clients |
| `lib/mic/chat*` | Chat persistence, provider adapters and prompts |
| `lib/mic/jobs/` | Profile/resource generation and document processing |
| `lib/mic_web/router.ex`, `user_auth.ex` | Routes and authentication boundaries |
| `lib/mic_web/live/` | Onboarding, scenario chat, settings and dashboard |
| `lib/mic_web/controllers/` | Pages, OAuth callbacks and WhatsApp webhook |
| `lib/mic_web/components/` | Shared UI and message rendering |
| `native/documentparser_native/` | Rust PDF, DOCX and text extraction |
| `assets/` | Browser hooks, audio, charts and styles |
| `priv/repo/migrations/`, `test/` | Database history and ExUnit tests |

## Development checks

With dependencies installed and local test PostgreSQL available:

```sh
mix compile
mix format --check-formatted
mix credo
mix test
npm test --prefix assets
mix assets.build
```

`mix test` creates/migrates the test database before running ExUnit. JavaScript tests
use Node's built-in runner and browser doubles; they do not access the microphone or
external providers. No separate JavaScript lint script is configured.

### Validation status

The quick-win batch added regression coverage for bcrypt's 72-byte password boundary,
audio blob URL cleanup, and Chart.js teardown during LiveView navigation. All
**3 focused password tests and 6 JavaScript tests passed**. JavaScript and CSS
bundles also passed using the configured esbuild 0.17.11 and Tailwind 3.3.2 versions.

**The full application build and ExUnit suite have not passed.** On the tested host,
Mix stops in Credo 1.7.5 with `Regex.CompileError: invalid range in character class`
before the suite runs. Existing fixtures also refer to obsolete APIs and disabled
routes. Focused checks do not replace restoring that integration baseline.
See [the codebase review](docs/CODEBASE_REVIEW.md) for reproduction commands and the
prioritized backlog; [PLAN.md](PLAN.md) records the completed batch.

## Deployment

The [GitHub workflow](.github/workflows/fly-deploy.yml) runs
`flyctl deploy --remote-only` on pushes to **main**, using the `FLY_API_TOKEN`
repository secret. It currently has no test gate. [fly.toml](fly.toml) configures
the `mic` app and runs `/app/bin/migrate` as the release command.

Production runtime configuration requires `DATABASE_URL`, `SECRET_KEY_BASE`, and
the OpenAI variables above. Mail uses Postmark (`POSTMARK_API_KEY`); other providers
need their corresponding configuration. See [`config/runtime.exs`](config/runtime.exs)
for complete behavior; `.env.example` is not a complete production manifest.

The review identifies unresolved webhook authentication, generated-HTML sanitization,
document resource limits and job outcome handling. Review those findings before
treating the integrations as production-ready. A successful push does not establish
that a deployment or its migrations succeeded.
