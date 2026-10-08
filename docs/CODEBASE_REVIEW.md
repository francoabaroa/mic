# Codebase survey and candidate ledger

## Map

- `mix.exs`, `lib/mic/application.ex`: Phoenix 1.7.10 / LiveView 0.20.1,
  Ecto 3.11/PostgreSQL, Oban 2.17.7, Finch, tokenizer NIF and ETS supervision.
- `lib/mic_web/endpoint.ex`, `router.ex`, `user_auth.ex`: browser sessions,
  CSRF, authenticated LiveView mounts; public OAuth and WhatsApp API routes.
- `lib/mic/accounts*`: bcrypt authentication, hashed email tokens, database session
  tokens, settings, confirmation/reset mail. Registration creates settings and
  assistants after inserting the account (`live/user_registration_live.ex`).
- `lib/mic_web/live/onboarding_live/*`: translated questionnaire, audio and document
  input, profile generation and PubSub completion; jobs then create resources.
- `lib/mic_web/live/chat_live/index.ex`: scenario selection, per-user history,
  provider streaming, transactional user/assistant message writes, speech playback.
- `lib/mic/chat*`: contexts/schemas, OpenAI, Bedrock and Vertex adapters; most of
  `llm/openai.ex` and `prompts/*` is prompt content. No payment processor found;
  finance and contract features generate advice and handle sensitive documents.
- `native/documentparser_native`: Rustler 0.32.1 with docx-rs/pdf-extract; synchronous
  file parsing. `jobs/*document*` also serves the WhatsApp flow.
- `lib/mic/artists*`: profiles/resources and Spotify/Instagram/Chartmetric wrappers;
  dashboard calls Chartmetric. Profile/message CRUD LiveViews remain in source but
  their routes are commented out.
- `assets/js/app.js`, `assets/css/app.css`, templates/components: LiveView hooks,
  audio playback/recording, charts, Tailwind/DaisyUI. Marketing/education pages are
  largely static. Generated core components and vendored icons/topbar were skimmed.
- `priv/repo/migrations`, `rel`, `Dockerfile`, `fly.toml`: database enums/foreign
  keys, release migrations and Fly release build. GitHub workflow deploys main;
  there is no test gate. No services were deployed or contacted for app operations.
- Tests: ExUnit contexts, controller/auth and LiveView tests; `mix test` creates and
  migrates its database. Credo/Dialyxir are dependencies; formatter configured in
  `.formatter.exs`. No JavaScript test/lint scripts initially existed.
- Setup drift: `.tool-versions` specifies Elixir 1.14.2/OTP 26.0.2; Docker uses
  1.16.1/26.2.1; host uses 1.18.4/28. Root and assets package manifests disagree,
  and assets has no lockfile. Runtime requires OpenAI credentials in every env;
  tokenizer startup downloads a model. Dependencies initially absent.

## Candidate ledger (priority order)

1. **High, deferred — webhook trust and abuse controls:**
   `lib/mic_web/router.ex:45`, `controllers/whatsapp_controller.ex:10`:
   incoming POST payloads reach paid generation and outbound messaging without
   signature validation or an account boundary. Requires raw-body verification,
   configuration, replay/idempotency policy and integration tests.
2. **High, deferred — safe HTML rendering:**
   `components/message_component.ex:30` renders Earmark output through `raw`;
   `controllers/page_controller.ex:120` only removes code fences before insights
   render raw generated HTML. Introduce a maintained sanitizer with an explicit
   formatting/link policy across both paths. Earmark 1.4.46 explicitly requires
   callers to sanitize untrusted output; escaping is not a sanitizer. Its package
   is now retired. Do not replace rich content with plaintext as a silent change.
   Reference: https://earmark.hexdocs.pm/1.4.46/Earmark.html#module-security
3. **High, planned — password byte boundaries:** `accounts/user.ex:61,75,140`:
   byte validation happens inside the hash pipeline after the validity check;
   validation-only forms omit it and verification accepts oversized inputs.
   Reference: https://bcrypt-elixir.hexdocs.pm/3.1.0/Bcrypt.html
4. **High, deferred — sensitive logging and retention:** chat fallback prints the
   entire socket (`live/chat_live/index.ex:515`); WhatsApp and extraction jobs log
   messages/document text. OpenAI extraction cleanup only runs on a successful
   completion (`chat/llm/text_extractor.ex`). Audit logging and cleanup together.
5. **High, deferred — document resource bounds/error contract:** chat/onboarding
   allow 2 GB uploads, accept unsupported extensions, delete postponed uploads;
   Rust NIFs run on normal schedulers and raise instead of returning the callers'
   expected error tuples. Bound file/decompression sizes and isolate parsing.
6. **Medium, deferred — durable job outcomes:** `jobs/generate_artist_profile_job.ex`
   broadcasts completion regardless of insert outcome; resource generation ignores
   persistence errors. Fix retries/idempotency and uniqueness as one tested unit.
   Registration also needs a deliberate partial-failure recovery policy.
7. **Medium, deferred — usable test baseline:** `test/support/fixtures/chat_fixtures.ex`
   calls removed create arities and supplies obsolete schema fields; message/profile
   LiveView tests target disabled routes. Profile fixtures omit required musical
   beginnings. Restore current contracts with meaningful integration coverage;
   isolate provider/tokenizer startup and add CI before automatic deploys.
8. **Medium, deferred — OAuth correctness:** API callback pipeline has no fetched
   session/flash, Google domain allowlist uses substring matching, Spotify callback
   redirect is hardcoded and its profile decoder expects artist search results.
   Audit state verification and account linking end to end before enabling OAuth.
9. **Medium, deferred — provider/input handling:** unknown scenario dereferences nil,
   query-string model remains a string but persistence calls Atom.to_string;
   voice input destructures Base.decode64 success; OpenAI retry recursion has no
   bound; Bedrock assumes transport chunks contain complete event frames.
10. **Medium, deferred — insights/dashboard:** missing insights raise before fallback
    (`page_controller.ex:66`); dashboard assumes a profile, hardcodes artist 3963,
    and labels followers/views as likes/comments. Chartmetric search double-decodes
    JSON (`artists/chartmetric.ex`). Resolve intended data presentation first.
11. **Low, planned — browser cleanup:** playback blob URLs and chart instances in
    `assets/js/app.js` are never released. Small lifecycle fixes, no new packages.
12. **Low, deferred — dead code and state helpers:** MessageStore has no callers,
    reverses initial history and allocates IDs non-atomically; Anthropic message
    normalization leaks an Agent and inserts separators incorrectly. Confirm
    intended provider support before pruning or repairing alternate implementations.
13. **Medium, deferred — recording lifecycle:** `assets/js/app.js` never stops mic
    tracks, resets chunks at stop and has no permission/duplicate-start handling.
    Needs browser-level recording tests for stop, navigation and permission races.

## Validation and outcomes

Pending. Baseline host build fails in Credo 1.7.5 with Regex.CompileError on OTP 28;
an installed OTP 27 runtime is being checked without changing project dependencies.
