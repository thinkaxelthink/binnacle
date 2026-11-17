---
name: binnacle
description: Work with the Binnacle vaults on this machine, Obsidian wikis an LLM keeps up to date (Karpathy's "LLM Wiki" pattern). Use when a question may be answered from the user's own notes, wiki or second brain; when the user wants to capture or save something to a vault; or when the user wants to run or dry-run the wiki ingest (bin/binnacle-run).
---

# Binnacle

A Binnacle vault is a git repository holding an Obsidian wiki that an LLM
maintains from the sources the owner drops in. This skill looks things up
in the vaults on this machine, captures new material to a vault's inbox,
and runs the ingest.

## Find the vaults

The vaults on this machine are listed in `~/.claude/CLAUDE.md`, between
`<!-- binnacle:begin -->` and `<!-- binnacle:end -->`, one row each:

```
- **<name>** at `<path>`: <scope>
```

Read that list; never guess a vault path or search the disk for vaults.
With no block or no rows, say that no vault is registered on this machine
and that running the vault's setup script registers it.

Pick the vault whose scope fits the request. If more than one could fit,
ask which. Work material never goes into a personal vault.

Before anything else in a vault, read its `CLAUDE.md`. It is the schema
(zones, page conventions, what the vault may hold) and wins wherever it
differs from this skill.

## Look something up

1. Read `<path>/wiki/index.md` first, then open the relevant pages and
   follow their links. Sources are in `raw/sources/`; the owner's own notes
   are in `soundings/`.
2. Answer with citations: the wiki pages you used (`[[wiki/...]]`) and,
   where a page cites one, the raw source.
3. Treat the wiki as a lead, not the last word. Verify volatile facts
   (versions, prices, dates, who does what) against a current source, and
   say when you could not.
4. Lookups are read-only. Never edit `wiki/`, `audit/`, `raw/sources/` or
   `soundings/`; if something there looks wrong, tell the user. To keep an
   answer as a wiki page, follow the vault's `CLAUDE.md` ("Query").

## Capture a note

1. Check that the material fits the vault's scope and holds no secret
   (password, API key, token, private key, connection string) and nothing
   the vault's `CLAUDE.md` rules out. If it does, stop and say why.
2. Write one new file in `<path>/raw/inbox/`, named
   `<YYYY-MM-DD>-<kebab-case-title>.md`. Never overwrite an existing file.
   Give it a title, the material, and where it came from (a URL, a
   document, or "conversation") with the date.
3. Commit only that file; the pre-commit hook scans it:

   ```sh
   git -C <path> add -- raw/inbox/<file>
   git -C <path> commit -m "capture: <title>" -- raw/inbox/<file>
   ```

   If the hook refuses the commit, report why. Never bypass it
   (`--no-verify`).
4. Push with `git -C <path> push`, unless
   `git -C <path> config binnacle.localOnly` prints `true` (a vault with no
   remote yet: the commit is the capture). If the push is rejected, report
   it; never force-push.
5. Leave every other uncommitted change in the vault alone: do not stage,
   stash, reset, discard or commit it.

## Run the ingest

`bin/binnacle-run` reads `raw/inbox/` into the wiki, lints it, writes an
audit note, and proposes the change as a pull request that merges itself
once the secret scan passes (a local-only vault fast-forwards `main`
instead).

1. It runs only where `git -C <path> config binnacle.role` prints
   `wiki-writer`. Anywhere else, say so and stop.
2. Always offer the dry run first, and show its output:

   ```sh
   <path>/bin/binnacle-run --dry-run
   ```

3. Run `<path>/bin/binnacle-run` only after the user confirms. It runs
   Claude Code headless and can take several minutes. Report the pull
   request URL it prints, or the reason a run skipped or failed (the audit
   note in `<path>/audit/runs/` says why).

## Never

- Never put secrets, credentials or restricted data in a vault.
- Never write to `wiki/` or `audit/` directly; `bin/binnacle-run` writes
  them, and the vault's `CLAUDE.md` names the only exceptions.
- Never change `raw/sources/` or `soundings/`.
