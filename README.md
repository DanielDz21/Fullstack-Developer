# Fullstack Developer Test — User Management App

A user management application built for Umanni's Modern Fullstack Developer Test:
role-based authentication, an admin dashboard with real-time counters, full user
CRUD, and asynchronous CSV/XLSX spreadsheet import with a live progress bar.

### AI Usage Disclosure

Per Umanni's AI Policy, this is an honest account of the AI assistance actually used:

- **Claude Code** (Anthropic, powered by Claude models — current session running
  **Claude Sonnet 5**) was used throughout the project for code generation,
  refactoring, test writing, and this documentation.
- **Aider** with **Claude 3.7 Sonnet** was tried very early on as an initial,
  exploratory test of the tool. It did not produce any code that remains in the
  current codebase — all application code was written via Claude Code.
- **Gemini** was used to help draft a visual/design redesign roadmap.

## Tech Stack

- **Ruby 4.0** / **Rails 8.1** (Ruby 4's ZJIT enabled in production, see
  [Architecture Decisions](#architecture-decisions))
- **Hotwire** (Turbo 8 + Stimulus) — no React/Inertia, see rationale below
- **Tailwind CSS v4**
- **SQLite** (multi-database: primary/cache/queue/cable, native WAL mode)
- **Solid Cache / Solid Queue / Solid Cable** — no Redis required
- **Pundit** for authorization
- **Rails 8 built-in authentication** (`bin/rails generate authentication`) — no Devise
- **RSpec** + FactoryBot + Faker + Shoulda Matchers + SimpleCov + Capybara/Playwright
  + `parallel_tests`
- **Propshaft** + importmap for asset management
- **Kamal 2** + **Thruster** for deployment, multi-stage **Docker** build

## Requirements

- Ruby 4.0+ (see `.ruby-version`)
- Node.js (only for Playwright's browser binaries used by system specs)
- SQLite 3.8+
- Docker (optional, for containerized run/deploy)

## Setup

```bash
bundle install
bin/rails db:prepare   # creates all 4 databases and loads the schema
bin/rails db:seed      # creates the bootstrap admin user (see below)
```

## Seeding

Public registration always creates a `no_admin` user (enforced server-side in
`RegistrationsController`, ignoring any injected `role` param), so there is no way
to reach an admin account from the UI alone. `db/seeds.rb` creates two users,
idempotently, so the app is usable immediately after setup:

| Role     | Email               | Password      |
|----------|---------------------|----------------|
| Admin    | `admin@example.com` | `password123` |
| Regular  | `user@example.com`  | `password123` |

```bash
bin/rails db:seed
```

Change these default passwords before deploying anywhere reachable by others.

## Running in development

```bash
bin/dev   # runs `bin/rails server` + `bin/rails tailwindcss:watch` via Procfile.dev
```

Visit `http://localhost:3000`, sign in with the seeded admin (or register a new
regular user), and Solid Queue/Solid Cable both run in-process — no extra services to
start. Outgoing mail (password reset / "set your password" for imported users) is
logged to the Rails console (`ApplicationMailer#log_to_console_in_development`,
look for `[Mailer]` lines) and also written to `tmp/mails` — nothing opens
automatically, since a bulk spreadsheet import can send thousands of e-mails at
once.

## Running the test suite

```bash
bin/rails db:test:prepare               # after any new migration
bundle exec rspec                       # full suite, sequential
bundle exec rspec spec/path/to_spec.rb  # a single file
bundle exec parallel_rspec spec/        # parallel, same as CI

# System specs (Playwright) — set this if the Playwright CLI isn't globally resolvable:
PLAYWRIGHT_CLI_EXECUTABLE_PATH=./node_modules/.bin/playwright bundle exec rspec spec/system
```

Quality gates:

```bash
bundle exec rubocop
bundle exec brakeman -q --no-pager
bundle exec bundler-audit check
```

Current state: 0 failures, ≥90% SimpleCov line coverage (enforced via
`SimpleCov.minimum_coverage` — the suite itself fails if coverage regresses below
that bar), 0 RuboCop offenses, 0 Brakeman warnings, 0 bundler-audit vulnerabilities.

## Running with Docker

```bash
docker build -t fullstack_developer .
docker run -d -p 3000:80 \
  -e RAILS_MASTER_KEY="$(cat config/master.key)" \
  -e SOLID_QUEUE_IN_PUMA=true \
  --name fullstack_developer \
  fullstack_developer
```

The image is a non-root, multi-stage build served by **Thruster** (zero-config
asset caching/compression/HTTP proxy) on port 80. `SOLID_QUEUE_IN_PUMA=true` runs
the Solid Queue supervisor inside the same Puma process, so no separate worker
container is needed for this single-server setup. Run `bin/rails db:seed` inside the
container (`docker exec -it fullstack_developer bin/rails db:seed`) to create the
bootstrap admin.

## Deploying with Kamal 2

`config/deploy.yml` is parsed as ERB before YAML, so both the target host and the
container registry are read from environment variables rather than hardcoded —
there is no real production server for this test, so a deploy attempted without
these sane, safe defaults fails fast instead of silently targeting an unrelated
machine:

```bash
KAMAL_WEB_HOST=<your server ip/host> \
KAMAL_REGISTRY_USERNAME=<your github username> \
KAMAL_REGISTRY_PASSWORD=<a GitHub PAT with write:packages> \
bin/kamal deploy
```

`RAILS_MASTER_KEY` is picked up by `.kamal/secrets` from `config/master.key`
automatically.

## Environment Variables

| Variable                 | Used by                       | Purpose                                                              | Default                         |
|---------------------------|--------------------------------|-------------------------------------------------------------------------|----------------------------------|
| `RAILS_MASTER_KEY`        | Rails credentials, Kamal      | Decrypts `config/credentials.yml.enc` in production                  | —  (required in production)     |
| `RAILS_MAX_THREADS`       | Puma, `database.yml`          | Puma thread pool size / SQLite connection pool size                  | `3` (Puma) / `5` (DB pool)       |
| `PORT`                    | Puma                          | Server port                                                            | `3000`                          |
| `SOLID_QUEUE_IN_PUMA`     | `config/puma.rb`, Kamal       | Runs the Solid Queue supervisor inside the Puma process               | unset (off)                     |
| `JOB_CONCURRENCY`         | `config/queue.yml`            | Number of Solid Queue worker processes                               | `1`                              |
| `RAILS_LOG_LEVEL`         | `config/environments/production.rb` | Production log verbosity                                      | `info`                           |
| `KAMAL_WEB_HOST`          | `config/deploy.yml`           | Deploy target host/IP                                                  | `203.0.113.10` (RFC 5737, fails fast) |
| `KAMAL_REGISTRY_USERNAME` | `config/deploy.yml`           | GHCR username / image namespace                                       | `your-github-username`          |
| `KAMAL_REGISTRY_PASSWORD` | `.kamal/secrets`              | GHCR auth (GitHub PAT, `write:packages` scope)                        | —  (required to deploy)         |

## Architecture Decisions

- **Hotwire over React/Inertia** — chosen explicitly for this project to keep a
  classic-modern monolith: Turbo Streams over Solid Cable cover every real-time
  requirement (dashboard counters, import progress) without a client-side JS build
  or state-management layer, and Stimulus covers the handful of purely
  client-side interactions (mobile nav toggle, live password-confirmation
  validation).
- **SQLite in production, multi-database** — `primary`/`cache`/`queue`/`cable`, each
  its own SQLite file under `storage/`, mounted as a single Kamal volume. WAL mode
  is the Rails 8 SQLite adapter's default, so no extra configuration is needed for
  concurrent readers/writers. No Redis, Postgres, or MySQL to provision.
- **Rails 8 built-in authentication**, not Devise — generated via
  `bin/rails generate authentication`, then customized: the generator's
  `email_address` field was renamed to `email` (matching this project's
  requirements), and a `role` enum (`no_admin`/`admin`, default `no_admin`) was
  added. Public registration always forces `no_admin` server-side, even if a `role`
  param is injected in the request.
- **Pundit for authorization** — `ApplicationController#pundit_user` maps to
  `Current.user` (the app uses `Current.user` throughout, not the Devise-style
  `current_user`). `after_action :verify_authorized` is enforced globally, with a
  narrow `skip_after_action` only on the three pre-authentication controllers
  (sessions, passwords, registrations).
- **Spreadsheet import via a single gem (`roo`)** — reads both CSV and XLSX through
  the same API (`Roo::Spreadsheet.open`), avoiding a second gem
  (`roo-xlsx`/`caxlsx`) purely for one format. An admin can mark whether the file
  has a header row; either way, column mapping is purely **positional** (1st column
  = full name, 2nd = email) and a header's text is never used to map columns. Each
  row is validated and processed independently in a dedicated
  `SpreadsheetParser`/`SpreadsheetImportRowImporter` pair of services (the job
  itself only orchestrates: parse, loop, track progress, set final status). A bad
  row is recorded as a `SpreadsheetImportRowError` (row number + message + raw
  data) without aborting the rest of the import. Progress broadcasts are throttled
  to once every 10 rows rather than firing on every single row, to keep large
  imports from flooding Turbo Streams with broadcasts — the final state is always
  covered separately by the status transition at the end of the import, which
  already reflects the finished row count on its own. Imported users get an
  unusable random password and a "set your password" e-mail reusing the existing
  password-reset token mechanism, since they never chose one themselves.
- **Avatar via remote URL** (`app/services/avatar_fetcher.rb`) — fetched with
  `Net::HTTP` (never `URI.open`/`open-uri` on a user-supplied URL) behind an SSRF
  guard: resolves the host and rejects private/loopback/link-local IPs, limits
  redirects, validates `content_type` against an allowlist, and streams the body
  with a size cutoff enforced during download rather than after.
- **Ruby 4 ZJIT in production** — enabled via `RUBYOPT="--zjit"` in the Dockerfile.
  Rails 8.1 enables YJIT by default in production (`config.yjit = !Rails.env.local?`);
  since only one JIT can run per process, `config.yjit = false` is set explicitly in
  `config/environments/production.rb` so ZJIT wins cleanly instead of both JITs
  fighting for the slot and Ruby printing a boot-time conflict warning.
- **Solid Cache for dashboard counts** — `User.dashboard_counts` caches the
  dashboard's total/by-role numbers, written through by the same hook that already
  knew when they changed, rather than recomputing on every render.
- **Playwright over a lighter Capybara driver** — every real-time system spec
  (Turbo Stream/Action Cable delivery, multi-session dashboard updates) needs a
  real JS-executing, WebSocket-capable browser; a lighter driver like Cuprite would
  technically cover the same ground, but Playwright/Capybara is the combination
  this test's own brief names as the expected frontend-testing stack, so it was
  kept as-is rather than swapped for a marginally lighter alternative.

## Security

Covered by `spec/requests/security_spec.rb` and verified manually against a real
running server: parameterized queries via ActiveRecord (no raw SQL, immune to the
classic `' OR '1'='1` injection), ERB auto-escaping everywhere (no `html_safe`/`raw`/
`sanitize` in the codebase — untrusted data, including full names and spreadsheet
row error messages, is always rendered escaped), CSRF protection
(`protect_from_forgery with: :exception`, Rails 8.1's default) rejecting
state-changing requests without a valid authenticity token, rate-limited
authentication endpoints (sign-in, password reset, and registration), strong params
on every controller (no `params.permit!`), and an SSRF-hardened remote avatar
fetcher. `bundle exec brakeman` and `bundle exec bundler-audit check` are both
clean.

Untrusted external input (spreadsheet cell contents during import, remote avatar
URLs) is always treated as inert data, never as instructions to follow — the same
principle applies to any text sourced from outside the application's own code.

## Project Structure Highlights

- `app/models/user.rb` — role enum, avatar validations, dashboard-count broadcast
- `app/services/avatar_fetcher.rb` — SSRF-hardened remote avatar download
- `app/services/spreadsheet_parser.rb` / `spreadsheet_import_row_importer.rb` —
  spreadsheet parsing and per-row user creation, orchestrated by
  `app/jobs/spreadsheet_import_job.rb`
- `app/policies/` — Pundit authorization policies
- `spec/` — RSpec suite (models, requests, jobs, services, policies, system specs)
