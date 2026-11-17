# Binnacle

Binnacle is a template for a personal wiki that an LLM maintains for you.
You drop sources (articles, talk notes, PDFs, survey results) into an inbox
and write your own notes beside them. Claude Code reads each new source,
writes and cross-links wiki pages about it, flags contradictions and orphan
pages, and proposes every change as a pull request. You read and browse the
result in Obsidian, synced between your devices with git.

It follows Andrej Karpathy's "LLM Wiki" pattern [TK: link to the gist].
This repository holds the setup scripts, the checklists, and the schema the
LLM follows (`CLAUDE.md`). It holds no content. Each vault you create from
it is a separate private repository.

## How it works

```
capture devices ──► raw/inbox/ ──► bin/binnacle-run (wiki-writer machine)
                                     │  move inbox to raw/sources/<run-id>/
                                     │  Claude Code: ingest, link, lint
                                     ▼
                                pull request ──► gitleaks check ──► auto-merge to main
                                     └─► audit/runs/<run-id>.md
```

1. On any device, you put sources in `raw/inbox/` and your own notes in
   `soundings/`. Obsidian Git (on a Mac) or GitSync (on an iPhone) commits
   and pushes them.
2. On the one machine allowed to write the wiki, `bin/binnacle-run` starts a
   run, by hand or nightly once you schedule it. It works in a temporary
   git worktree, so your checkout and Obsidian stay on `main`. It branches
   from `origin/main` and moves the inbox, unchanged, into
   `raw/sources/<run-id>/`.
3. Claude Code runs headless with `bin/binnacle-run.prompt.md`. Following
   `CLAUDE.md`, it writes a page per source in `wiki/sources/`, creates or
   updates the concept and entity pages the source touches, links them both
   ways, updates `wiki/index.md`, runs a flag-only lint pass, and appends to
   `wiki/log.md`.
4. The script checks that Claude stayed inside its zones, writes the run's
   audit note, pushes, opens a pull request and turns on auto-merge. GitHub
   merges it once the gitleaks secret scan passes.

An empty inbox means no run, no branch and no pull request. A failed run
leaves its pull request open without auto-merge and records the reason in
its audit note. Nothing retries, and the next run refuses to start until you
merge or close that pull request.

### Vault layout

| Path | Holds | Written by |
|---|---|---|
| `raw/inbox/` | New sources: the capture point | You, on any device |
| `raw/sources/<run-id>/` | Ingested sources, never changed again | `bin/binnacle-run`, moved from the inbox byte for byte |
| `soundings/` | Your own hand-written notes | You, on any device. The LLM reads and links to them, never edits them |
| `wiki/` | The wiki: `sources/`, `concepts/`, `entities/`, `syntheses/`, plus `index.md` and `log.md` | Claude Code on the wiki-writer machine, through a pull request |
| `audit/` | One note per AI run, and `runs.base`, an Obsidian Bases table of all runs | `bin/binnacle-run` and Claude Code, through a pull request |
| everything else | Scripts, schema, settings | You |

`CLAUDE.md` is the full schema: page conventions, citation rules, the
index and log formats, and what each operation may do.

## Machines and profiles

A vault has two kinds of machine:

- **The wiki-writer.** The one machine where Claude Code writes the wiki.
  Its clone is marked `git config binnacle.role wiki-writer`, and
  `bin/binnacle-run` refuses to run anywhere else.
- **Capture devices.** Any number of Macs and iPhones that read the whole
  vault and write only to `raw/inbox/` and `soundings/`. A capture Mac's
  clone is marked `binnacle.role capture`.

The template sets up two profiles:

- **Personal vault** (default repository `binnacle-<user>`, in the folder
  `~/binnacle-<user>`). Your own thinking and architectural learnings. One
  wiki-writer, any number of capture devices, and a private repository on
  your GitHub account.
- **Work brain** (`setup/work-brain/`). A separate vault for your job, on
  your work machine, which is its own wiki-writer. It may hold company
  material within fixed limits (see "How Binnacle protects you"). It starts
  with no remote and can later connect to a private repository in your
  employer's GitHub organization.

Every vault is independent: its own repository, tokens, audit trail and
wiki. Nothing is shared but this template.

## Requirements

- macOS on the wiki-writer and on capture Macs. The scripts use the macOS
  keychain, launchd and the Obsidian app in `/Applications`.
  [TK: is Linux or Windows support planned, or should the README say
  macOS only?]
- `git`, the GitHub CLI (`gh`) and `gitleaks`, from Homebrew or, for
  gitleaks, the per-user install the checklists describe.
- Claude Code, logged in, on the wiki-writer.
- Obsidian 1.13 or later, with the Obsidian Git community plugin and the
  Bases core plugin.
- A GitHub plan with branch protection and auto-merge on private
  repositories: GitHub Pro for a personal account, Team or Enterprise for a
  work brain's organization. `setup/github/setup.sh` stops with a message
  if the plan lacks them.
- `python3` for survey intake (standard library only; 3.9 or later for
  time zones).
- On an iPhone: Obsidian and GitSync (free tier). There is no script for
  the phone.

## Setup

Every step is either an idempotent script, safe to re-run, or a checklist
item that names the device it happens on. The checklists are the source of
truth; this section gives the order.

The scripts have no built-in GitHub account: set `BINNACLE_OWNER` to
your GitHub login when you run them, for example
`BINNACLE_OWNER=<your-github-user> setup/github/setup.sh`. Without it the
GitHub, wiki-writer and capture Mac scripts stop before changing
anything. In the checklists' clone URLs, `<your-github-user>` stands for
your GitHub login.

Names follow one pattern. The template, your fork of it and its plugin
marketplace are `binnacle`. A work brain is `binnacle-<org>-<user>`, and
the personal vault defaults to `binnacle-<user>`, in `~/binnacle-<user>`,
where `<user>` is your GitHub login in lower case. `BINNACLE_REPO` names
the personal vault something else and moves its default folder with it,
for example `BINNACLE_REPO=binnacle-vault` for `~/binnacle-vault`;
`BINNACLE_DIR` sets the folder alone. Pass the same values to every
setup script for that vault.

### Personal vault

1. **Your copy of the template.** Fork this repository into your GitHub
   account, keeping the name `binnacle`, and clone your fork:

   ```sh
   git clone https://github.com/<your-github-user>/binnacle.git ~/src/binnacle
   ```

   The GitHub script marks `<your-github-user>/binnacle` as a
   template and creates the vault from it (`BINNACLE_TEMPLATE_REPO` names
   a different repository).
2. **GitHub.** Follow `setup/github/CHECKLIST.md`, then, from your fork's
   clone:

   ```sh
   BINNACLE_OWNER=<your-github-user> setup/github/setup.sh --dry-run   # shows every call, changes nothing
   BINNACLE_OWNER=<your-github-user> setup/github/setup.sh
   ```

   This creates the private repository `<your-github-user>/binnacle`, turns on squash
   auto-merge and delete-branch-on-merge, and protects `main`: the
   `gitleaks` check must pass before a pull request merges, and force
   pushes and branch deletion are blocked. Admins are not enforced, so your
   capture devices can still push straight to `main`.
3. **Wiki-writer machine.** Follow `setup/shoyu/CHECKLIST.md`, then run
   `BINNACLE_OWNER=<your-github-user> ~/binnacle-<user>/setup/shoyu/setup.sh`. It marks the clone as the
   wiki-writer, sets the commit identity in the vault clone only, installs
   the pre-commit hook, checks for `git`, `gh`, `claude` and Obsidian, and
   sets up the Claude Code plugin and the vault's row in
   `~/.claude/CLAUDE.md` (see "Claude Code integration").
   The checklist also covers the device token, Obsidian Git settings, and
   a first run.
4. **Capture Mac** (optional). Follow `setup/workmac/CHECKLIST.md`, then
   run `BINNACLE_OWNER=<your-github-user> ~/binnacle-<user>/setup/workmac/setup.sh`. It marks the clone as capture
   only and sets up the Claude Code plugin and vault row as on the
   wiki-writer. It requires `git config --global binnacle.workDocs <folder>`,
   naming your employer's documents folder, and refuses to put the vault
   inside it. [TK: what should someone set up a capture Mac that is not a
   work computer do about `binnacle.workDocs`?]
5. **iPhone** (optional). Follow `setup/iphone/CHECKLIST.md`: Obsidian,
   GitSync, and two Shortcuts automations that sync when Obsidian opens and
   when it closes.

Each device gets its own fine-grained GitHub token, scoped to the vault
repository only, with an expiry. Never use a classic token. The table of
permissions per device is in `setup/github/CHECKLIST.md`.

Once a first run works, three optional additions:

- **Nightly runs.** `~/binnacle-<user>/setup/shoyu/nightly.sh install` adds a
  LaunchAgent that runs `bin/binnacle-nightly` at 03:30 local time
  (`BINNACLE_NIGHTLY_HOUR` and `BINNACLE_NIGHTLY_MINUTE` change it).
  `status` shows the last run and `uninstall` pauses it. Nothing is
  scheduled until you install it. A LaunchAgent runs only while you are
  logged in; the log is `~/Library/Logs/binnacle/nightly.log`. See
  "Nightly runs" in `setup/shoyu/CHECKLIST.md`.
- **A one-time Notion import.** `setup/notion/CHECKLIST.md` and
  `bin/binnacle-import start|finish|status` bring a Notion workspace into
  `soundings/notion/` on a branch, as a pull request you review and merge
  yourself.
- **Google Forms intake.** `setup/forms/GOOGLE-CHECKLIST.md`; see "Survey
  intake" below.

### Work brain

Follow `setup/work-brain/CHECKLIST.md`. Clone your fork of the template
somewhere outside any vault, then:

```sh
BINNACLE_OWNER=<your-github-user> ~/src/binnacle/setup/work-brain/setup.sh \
  --org <github org> --user <github user> --git-email <work email>
```

The vault is named `binnacle-<org>-<user>` and lives at
`~/binnacle-<org>-<user>` (`--dir` picks another folder). The script
refuses a folder that collides with another vault and never touches
`~/binnacle-<user>`. It writes the work brain's content limits into the vault's
`CLAUDE.md` and run prompt, and sets up the Claude Code plugin and the
brain's row in `~/.claude/CLAUDE.md`, with the work scope.

With no remote, runs commit locally through the pre-commit scan and
fast-forward `main`. When you decide to connect a remote, the checklist
walks through the organization settings to check first, then
`setup/work-brain/connect-remote.sh` pushes to an empty private repository
of the same name in the organization. From then on, runs open pull requests
as in the personal vault. Microsoft Forms intake for a work brain is in
`setup/forms/CHECKLIST.md`.

### Another personal vault

The template carries no content, so a second vault is the same steps with
different names, for example `garden` at `~/garden`:

1. GitHub, from your fork's clone: `BINNACLE_OWNER=<your-github-user> BINNACLE_REPO=garden setup/github/setup.sh`.
2. On each Mac, clone the new repository to its folder, then
   `BINNACLE_OWNER=<your-github-user> BINNACLE_REPO=garden BINNACLE_DIR=~/garden ~/garden/setup/<machine>/setup.sh`.
3. On the iPhone, add the repository in GitSync (check that your GitSync
   tier allows another one).
4. Make new tokens scoped to the new repository. Never reuse a token across
   vaults. On the wiki-writer, store its token in the keychain as
   `garden-gh-token`; the setup script points the clone at
   `<repo>-gh-token`.

## Day to day

### Capture

Write sources into `raw/inbox/` and your own notes into `soundings/`. Read
everything else, and leave `wiki/` to the runs. Let Obsidian Git or GitSync
push your captures: a run reads the inbox from `origin/main`, so a capture
not yet pushed waits for the next run.

### Run

On the wiki-writer:

```sh
~/binnacle-<user>/bin/binnacle-run --dry-run   # what would happen; no fetch, no Claude, no GitHub calls
~/binnacle-<user>/bin/binnacle-run
```

Expect a pull request URL with auto-merge on. A run exits 0 without doing
anything when the inbox is empty, when a Notion import is in progress, or
when another run holds the lock.

### Read and review

- Start at `wiki/index.md`, the catalog of every page. `wiki/log.md` is
  the history of what happened to the wiki:
  `grep '^## \[' wiki/log.md | tail -5` shows the last five operations.
- Open `audit/runs.base` in Obsidian for a table of every run: status,
  sources, pages changed, lint flags, pull request, and whether it merged.
  `audit/README.md` explains each field.
- Lint only flags; it never fixes. Each run's audit note lists
  `contradiction`, `orphan`, `stale` and `review` flags for you to act on.

### Ask questions

Open Claude Code in the vault on the wiki-writer and ask. Following
`CLAUDE.md`, it reads `wiki/index.md` first, follows links, and answers
with citations to wiki pages and raw sources. Queries change nothing. To
keep an answer, ask Claude to file it: it becomes a page in
`wiki/syntheses/` on a `binnacle-query/<date>-<slug>` branch, through a
pull request with auto-merge.

### Survey intake

`bin/binnacle-forms-to-inbox` turns a survey's responses export (Microsoft
Forms `.xlsx` or `.csv`, Google Forms or Sheets `.csv`) into one scrubbed
note per form per collection window in `raw/inbox/forms/`. It drops
respondent names, emails, ids and timestamps, summarises ratings as a
distribution and a median, and labels free-text answers in a random order.
It writes nothing at all when an answer matches an email, phone or card
pattern or a term on your local stop-list. It never commits; you read the
note, then commit it.

- Personal vault: `bin/binnacle-forms-google-pull` reads your own Google
  Forms through the Forms API, read-only, once each window has closed, and
  can run before each nightly run (`setup/forms/GOOGLE-CHECKLIST.md`). Or
  run the converter by hand on a downloaded export.
- Work brain: a Power Automate flow and `setup/forms/mover.sh` feed it from
  Microsoft Forms (`setup/forms/CHECKLIST.md`).

A manager's surveys about their own direct reports can get one page per
person in `wiki/people/`. That zone is off unless you run
`git config binnacle.peopleZone true` in the vault; each person page comes
up for a keep-or-delete review once a year.

## Claude Code integration

This repository is also a Claude Code plugin marketplace,
`binnacle` (`.claude-plugin/marketplace.json`), with one plugin,
`binnacle` (`plugins/binnacle/`). Its skill works with the vaults on the
machine it runs on:

- **Look up.** It reads the vault's `CLAUDE.md` and `wiki/index.md` first,
  follows links, and answers with citations. Lookups are read-only.
- **Capture.** It writes one new file to `raw/inbox/`, then commits and
  pushes only that file (commits only, in a work brain with no remote),
  leaving any other uncommitted change alone.
- **Run.** It starts `bin/binnacle-run` only on a clone marked
  `binnacle.role wiki-writer`, always offering `--dry-run` first and
  running for real only once you confirm.

Every vault setup script (`setup/shoyu/setup.sh`,
`setup/workmac/setup.sh`, `setup/work-brain/setup.sh`) calls
`setup/common/register-vault.sh`, which:

1. registers the marketplace in your fork,
   `<your-github-user>/binnacle` (the account in
   `BINNACLE_OWNER`; `BINNACLE_MARKETPLACE` names another) and installs or updates the
   `binnacle` plugin at user scope with the `claude` CLI. Without `claude`
   it skips this step with a message;
2. adds or refreshes the vault's row in a marked block of
   `~/.claude/CLAUDE.md`, creating the file or block when absent, so every
   Claude session on the machine knows which vaults exist, where they
   live, and the rules for using them. The skill finds vaults only through
   this block. Each row reads:

   ```
   <!-- binnacle:begin -->
   ...
   - **binnacle** at `/Users/you/binnacle`: personal: the owner's own thinking and architectural learnings; never company material
   ...
   <!-- binnacle:end -->
   ```

   Rows are keyed by the vault's path. Re-running setup refreshes the row
   and the block's text, never adds a duplicate row or marketplace, and
   never changes anything outside the block.

To install the plugin by hand on a machine with no vault setup, in Claude
Code:

```
/plugin marketplace add <owner>/binnacle
/plugin install binnacle@binnacle
```

## How Binnacle protects you

- **Zones.** The LLM writes only `wiki/` and `audit/`. After Claude Code
  finishes, `bin/binnacle-run` reverts anything it changed elsewhere and
  fails the run. `wiki/log.md` may only grow, and `wiki/people/` may change
  only while the people zone is on.
- **Secret scan, twice.** On every Mac, a pre-commit hook runs gitleaks on
  the staged changes and rejects any staged file over 10 MB. If it cannot
  find gitleaks, it blocks the commit rather than skip the scan. The same
  gitleaks scan runs as a GitHub Action on every push and pull request, and
  `main` requires it before any pull request merges. An iPhone cannot run
  the hook, so the Action is the only check on its commits.
- **AI changes go through pull requests.** Your own captures push straight
  to `main`; the scan runs on those pushes and reports, but cannot block
  them. AI changes always arrive through a pull request that merges only on
  a green scan.
- **One writer.** Only the clone marked `wiki-writer` can run AI writes.
- **Tokens.** One fine-grained token per device, scoped to one repository,
  with an expiry, kept in the macOS keychain or a mode-600 file outside the
  vault. No token goes into the vault, a script or `.obsidian/`. The
  nightly log masks anything shaped like a GitHub, Anthropic or Google
  token.
- **What stays local.** `.obsidian/` is committed so devices share plugins
  and settings, except window layout, caches, Obsidian Git and Importer
  settings, and any file named like a token, secret, credential or
  password. Survey settings and the stop-list live in `.binnacle/`, which
  git ignores.
- **What a vault may hold.** The personal vault holds no company data, no
  member or customer data, no payment or contract material and no
  credentials, and no company system connects to it. A work brain may hold
  company material, but never customer or member personal data, payment
  data, minors' names, health or waiver records, or credentials. Claude
  Code skips any source that holds a secret or out-of-scope material, and
  says so in the run's audit note without repeating it. Your employer's
  own policies win over these lists.
- **Who can see a work brain.** Until you connect a remote it exists only
  on your machine. Connected, the organization's owners can always read
  it. Others can read it unless the organization's base repository
  permission is "No permission" and no GitHub App is installed on all of
  its repositories; `connect-remote.sh` checks both and warns with the fix.

## Updating

- **Re-running setup.** Every setup script is idempotent; re-run one after
  changing its environment variables, or to repair a machine. A re-run
  also updates the `binnacle` plugin and refreshes the vault's row in
  `~/.claude/CLAUDE.md`. Between re-runs,
  `claude plugin marketplace update binnacle` and
  `claude plugin update binnacle@binnacle` update the plugin.
- **A work brain.** From an up-to-date template checkout outside the vault:

  ```sh
  git -C ~/src/binnacle pull
  ~/src/binnacle/setup/work-brain/update.sh ~/binnacle-<org>-<user>
  ```

  It finds the template commit the brain was built from, stops and names
  any template file you edited in the brain, then copies what changed
  upstream onto a `binnacle-update/<id>` branch with the work content rules
  re-applied. It never touches `wiki/`, `raw/`, `soundings/` or `audit/`.
  Local only, it fast-forwards `main`; connected, it opens a pull request,
  without auto-merge, for you to review and merge.
- **A personal vault.** [TK: there is no documented update path.
  `update.sh` refuses personal vaults. How should a personal vault pick up
  template changes?]

## Contributing

`CLAUDE.md` in this repository describes the vault the template produces,
not this repository. Changes here are ordinary reviewed code changes.

- `bin/` holds the run, import, nightly and survey scripts;
  `setup/<profile>/` holds each profile's script and checklist; the
  pre-commit hook is in `.githooks/`; CI is in `.github/workflows/`; the
  Claude Code marketplace is `.claude-plugin/marketplace.json` and the
  plugin is in `plugins/binnacle/`. Bump the plugin's `version` in
  `plugins/binnacle/.claude-plugin/plugin.json` when its skill changes,
  and check both with `claude plugin validate <dir> --strict` (the
  self-test does when `claude` is installed).
- Run `test/selftest.sh` before opening a pull request. It builds
  throwaway repositories from the template's own files, stubs `claude`,
  `gh`, `launchctl` and Google, makes no network calls, and runs
  shellcheck when it is installed. CI runs it whenever scripts, the hook,
  tests or the gitleaks config change, and runs the secret scan on every
  push.
- When a change alters what a person does, update the matching
  `CHECKLIST.md`; each item names the device it happens on. When it alters
  what the LLM does, update `CLAUDE.md` and `bin/binnacle-run.prompt.md`.
- The CI job named `gitleaks` is the required status check on every vault's
  `main`. Renaming it means updating `BINNACLE_SCAN_CHECK` in
  `setup/github/setup.sh` and the branch protection rule.

Outside pull requests are welcome: fork the repository, make the change on
a branch with `test/selftest.sh` passing, and open a pull request against
`main`.

[TK: license]
