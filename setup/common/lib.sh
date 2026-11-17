# shellcheck shell=bash
# Shared helpers for the Binnacle setup scripts. Source it; do not run it.

# BINNACLE_OWNER, your GitHub user, has no default: bn_require_owner. The
# personal vault's repository and folder default to binnacle-<user> and
# ~/binnacle-<user> (bn_require_owner sets them), after the work brain's
# binnacle-<org>-<user>; BINNACLE_REPO (e.g. binnacle-vault) and
# BINNACLE_DIR override them.
BINNACLE_OWNER=${BINNACLE_OWNER:-}
BINNACLE_REPO=${BINNACLE_REPO:-}
BINNACLE_DIR=${BINNACLE_DIR:-}
BINNACLE_MIN_OBSIDIAN=${BINNACLE_MIN_OBSIDIAN:-1.13}

bn_log() { printf '==> %s\n' "$*"; }
bn_ok() { printf '  ok   %s\n' "$*"; }
bn_warn() { printf '  WARN %s\n' "$*" >&2; }
bn_die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

# Print the absolute path of a usable gitleaks binary, or nothing.
# Looks at BINNACLE_GITLEAKS (when set, the only candidate), PATH, then the
# per-user (~/.local/bin) and Homebrew install locations, the same places
# .githooks/pre-commit searches.
bn_find_gitleaks() {
  local c
  if [ -n "${BINNACLE_GITLEAKS:-}" ]; then
    if [ -f "$BINNACLE_GITLEAKS" ] && [ -x "$BINNACLE_GITLEAKS" ]; then
      bn_physical_path "$BINNACLE_GITLEAKS"
    fi
    return 0
  fi
  for c in "$(command -v gitleaks || true)" "$HOME/.local/bin/gitleaks" \
    /opt/homebrew/bin/gitleaks /usr/local/bin/gitleaks; do
    if [ -n "$c" ] && [ -f "$c" ] && [ -x "$c" ]; then
      bn_physical_path "$c"
      return 0
    fi
  done
  return 0
}

# bn_version_ge A B: succeed when dotted version A >= B.
bn_version_ge() {
  local IFS=.
  # shellcheck disable=SC2206 # splitting on dots is the point
  local a=($1) b=($2) i x y
  for i in 0 1 2 3; do
    x=${a[i]:-0}
    y=${b[i]:-0}
    x=${x%%[!0-9]*}
    y=${y%%[!0-9]*}
    x=${x:-0}
    y=${y:-0}
    if [ "$x" -gt "$y" ]; then return 0; fi
    if [ "$x" -lt "$y" ]; then return 1; fi
  done
  return 0
}

# Print the installed Obsidian app version (macOS), or nothing.
# Obsidian updates itself through obsidian-<version>.asar files, so the
# newest of those wins over the installer version in Info.plist.
bn_obsidian_version() {
  local best="" v f plist=/Applications/Obsidian.app/Contents/Info.plist
  if [ -f "$plist" ]; then
    best=$(defaults read "${plist%.plist}" CFBundleShortVersionString 2>/dev/null || true)
  fi
  for f in "$HOME/Library/Application Support/obsidian"/obsidian-*.asar; do
    [ -e "$f" ] || continue
    v=${f##*/obsidian-}
    v=${v%.asar}
    if [ -z "$best" ] || bn_version_ge "$v" "$best"; then best=$v; fi
  done
  [ -n "$best" ] && printf '%s\n' "$best"
  return 0
}

# Print the physical (symlink-free) form of a path that may not exist yet.
bn_physical_path() {
  local p=$1 rest=""
  case $p in /*) ;; *) p="$PWD/$p" ;; esac
  while [ ! -d "$p" ]; do
    rest="/${p##*/}$rest"
    p=${p%/*}
    [ -n "$p" ] || p=/
  done
  printf '%s%s\n' "$(cd -P "$p" && pwd -P)" "$rest" | sed 's#//*#/#g'
}

# bn_path_is_under PATH DIR: succeed when PATH is DIR or inside it,
# compared case-insensitively (APFS default) after resolving symlinks.
bn_path_is_under() {
  local p d
  p=$(bn_physical_path "$1" | tr '[:upper:]' '[:lower:]')
  d=$(bn_physical_path "$2" | tr '[:upper:]' '[:lower:]')
  d=${d%/}
  case "$p/" in "$d"/*) return 0 ;; esac
  return 1
}

# bn_slug TEXT: lowercase; every run of characters outside [a-z0-9-]
# becomes one '-'; repeated dashes collapse; leading and trailing dashes go.
bn_slug() {
  printf '%s' "$1" | LC_ALL=C tr '[:upper:]' '[:lower:]' \
    | LC_ALL=C sed -e 's/[^a-z0-9-][^a-z0-9-]*/-/g' -e 's/--*/-/g' -e 's/^-//' -e 's/-$//'
}

# bn_require_owner: die before any change unless BINNACLE_OWNER, your
# GitHub user, is set; then default BINNACLE_REPO to binnacle-<user> and
# BINNACLE_DIR to ~/<BINNACLE_REPO>.
bn_require_owner() {
  local user
  [ -n "$BINNACLE_OWNER" ] || bn_die "set BINNACLE_OWNER=<your-github-user> (your GitHub user) and re-run; nothing was changed"
  user=$(bn_slug "$BINNACLE_OWNER")
  [ -n "$user" ] || bn_die "BINNACLE_OWNER '$BINNACLE_OWNER' has no letters or digits to name the vault after"
  BINNACLE_REPO=${BINNACLE_REPO:-binnacle-$user}
  BINNACLE_DIR=${BINNACLE_DIR:-$HOME/$BINNACLE_REPO}
}

# bn_marketplace: print where the binnacle Claude Code plugin comes from:
# BINNACLE_MARKETPLACE, else <BINNACLE_OWNER>/binnacle (your fork of the
# template); nothing when neither is set.
bn_marketplace() {
  if [ -n "${BINNACLE_MARKETPLACE:-}" ]; then
    printf '%s\n' "$BINNACLE_MARKETPLACE"
  elif [ -n "$BINNACLE_OWNER" ]; then
    printf '%s/binnacle\n' "$BINNACLE_OWNER"
  fi
}

# Clone the vault to BINNACLE_DIR, or verify an existing clone.
bn_clone_vault() {
  local url="https://github.com/$BINNACLE_OWNER/$BINNACLE_REPO.git" origin
  if [ -d "$BINNACLE_DIR/.git" ]; then
    origin=$(git -C "$BINNACLE_DIR" remote get-url origin 2>/dev/null || true)
    case $origin in
      *"$BINNACLE_OWNER/$BINNACLE_REPO"|*"$BINNACLE_OWNER/$BINNACLE_REPO.git")
        bn_ok "vault clone present at $BINNACLE_DIR" ;;
      *) bn_die "$BINNACLE_DIR is a git repo whose origin is '$origin', not $BINNACLE_OWNER/$BINNACLE_REPO" ;;
    esac
  elif [ -e "$BINNACLE_DIR" ]; then
    bn_die "$BINNACLE_DIR exists but is not a git clone; move it aside first"
  else
    bn_log "cloning $url to $BINNACLE_DIR"
    git clone "$url" "$BINNACLE_DIR"
  fi
}

# Set the commit identity in the vault clone only, never --global. Without
# one, git falls back to user@<hostname> and leaks the machine's network
# name into every vault commit. user.name: BINNACLE_GIT_NAME, else the
# existing vault-local name, else BINNACLE_OWNER. user.email:
# BINNACLE_GIT_EMAIL, else the existing vault-local email, else
# BINNACLE_OWNER@users.noreply.github.com.
bn_set_git_identity() {
  local git_name git_email
  git_name=${BINNACLE_GIT_NAME:-$(git -C "$BINNACLE_DIR" config --local user.name 2>/dev/null || true)}
  git_name=${git_name:-$BINNACLE_OWNER}
  git_email=${BINNACLE_GIT_EMAIL:-$(git -C "$BINNACLE_DIR" config --local user.email 2>/dev/null || true)}
  git_email=${git_email:-$BINNACLE_OWNER@users.noreply.github.com}
  git -C "$BINNACLE_DIR" config --local user.name "$git_name"
  git -C "$BINNACLE_DIR" config --local user.email "$git_email"
  bn_ok "commits in $BINNACLE_DIR authored as $git_name <$git_email>"
}

# --- Claude Code: the binnacle plugin and the per-machine vault list ---------
# The marketplace this template publishes (.claude-plugin/marketplace.json)
# and the plugin in it. setup/common/register-vault.sh uses them; the
# setup scripts tell it where the marketplace is (bn_marketplace).
BN_MARKETPLACE_NAME=binnacle
BN_PLUGIN=binnacle@$BN_MARKETPLACE_NAME
# The scope line of a personal vault in the vault list.
# shellcheck disable=SC2034 # used by the setup scripts that source this file
BN_PERSONAL_SCOPE="personal: the owner's own thinking and architectural learnings; never company material"
BN_BLOCK_BEGIN='<!-- binnacle:begin -->'
BN_BLOCK_END='<!-- binnacle:end -->'

# bn_claude_md: print the path of the user's Claude Code memory file.
bn_claude_md() { printf '%s\n' "$HOME/.claude/CLAUDE.md"; }

# bn_vault_row NAME DIR SCOPE: print one vault-list row.
# shellcheck disable=SC2016 # the backticks are Markdown, not a command
bn_vault_row() { printf -- '- **%s** at `%s`: %s\n' "$1" "$2" "$3"; }

# bn_vault_block_head / bn_vault_block_tail: the fixed text around the rows.
bn_vault_block_head() {
  cat <<'MD'
## Binnacle vaults

Binnacle vaults on this machine: Obsidian wikis that an LLM keeps up to
date, after Karpathy's "LLM Wiki" pattern. Each vault's setup keeps this
block up to date (`setup/common/register-vault.sh`); edit outside it.

MD
}
bn_vault_block_tail() {
  cat <<'MD'

When a question may be answered in one of these vaults:

- Read that vault's `wiki/index.md` first (its `CLAUDE.md` is the schema),
  open the relevant pages, and cite them.
- Treat the wiki as a lead, not the last word: verify volatile facts
  (versions, prices, dates, who does what) against a current source.
- Never edit `wiki/`, `audit/`, `raw/sources/` or `soundings/` directly;
  only `bin/binnacle-run` writes the wiki.
- Capture new material to the vault's `raw/inbox/`, then commit and push
  only that file; leave any other uncommitted changes alone.
- Keep work material out of personal vaults.
- Never put secrets, credentials or restricted data in any vault.
- Use the `binnacle` skill for lookups, captures and runs.
MD
}

# bn_vault_list_edit FILE DIR ROW: add or refresh DIR's row in the marked
# block of FILE (creating FILE or the block when absent). Rows are keyed by
# the vault path; the block's fixed text is rewritten each time; nothing
# outside the block changes. Dies on a malformed block (a marker missing,
# repeated or out of order), leaving FILE as it was.
bn_vault_list_edit() {
  local file=$1 dir=$2 row=$3 begins ends src tmp
  if [ -e "$file" ]; then
    begins=$(grep -cxF -- "$BN_BLOCK_BEGIN" "$file" || true)
    ends=$(grep -cxF -- "$BN_BLOCK_END" "$file" || true)
    if [ "$begins" != "$ends" ] || [ "$begins" -gt 1 ] || { [ "$begins" = 1 ] \
      && [ "$(grep -nxF -- "$BN_BLOCK_BEGIN" "$file" | cut -d: -f1)" -gt "$(grep -nxF -- "$BN_BLOCK_END" "$file" | cut -d: -f1)" ]; }; then
      bn_die "$file has a malformed binnacle block (one '$BN_BLOCK_BEGIN' line, then one '$BN_BLOCK_END' line expected); fix it by hand and re-run"
    fi
  else
    mkdir -p "$(dirname "$file")"
  fi
  src=$file
  [ -e "$file" ] || src=/dev/null
  tmp=$(mktemp "${TMPDIR:-/tmp}/binnacle-claude-md.XXXXXX")
  BN_DIR=$dir BN_ROW=$row BN_BEGIN=$BN_BLOCK_BEGIN BN_END=$BN_BLOCK_END \
    BN_HEAD=$(bn_vault_block_head) BN_TAIL=$(bn_vault_block_tail) \
    awk '
      function key(line,  i, rest, j) { # the path of a row, or ""
        if (line !~ /^- \*\*.*\*\* at `/) return ""
        i = index(line, "** at `"); rest = substr(line, i + 7)
        j = index(rest, "`: "); return j ? substr(rest, 1, j - 1) : ""
      }
      function emit(  i, n, out, done) {
        n = 0; done = 0
        for (i = 1; i <= nrows; i++) {
          if (key(rows[i]) == ENVIRON["BN_DIR"]) {
            if (!done) out[++n] = ENVIRON["BN_ROW"]
            done = 1
          } else out[++n] = rows[i]
        }
        if (!done) out[++n] = ENVIRON["BN_ROW"]
        print ENVIRON["BN_BEGIN"]; print ENVIRON["BN_HEAD"]; print ""
        for (i = 1; i <= n; i++) print out[i]
        print ENVIRON["BN_TAIL"]; print ENVIRON["BN_END"]
      }
      state == 0 && $0 == ENVIRON["BN_BEGIN"] { state = 1; next }
      state == 1 && $0 == ENVIRON["BN_END"] { state = 2; emit(); next }
      state == 1 { if (key($0) != "") rows[++nrows] = $0; next }
      { print; last = $0; lines++ }
      END {
        if (state == 0) {
          if (lines > 0 && last != "") print ""
          emit()
        }
      }
    ' "$src" >"$tmp" || {
    rm -f "$tmp"
    bn_die "could not rewrite $file"
  }
  # Write through any symlink (a dotfiles-managed CLAUDE.md stays a link).
  cat "$tmp" >"$file"
  rm -f "$tmp"
}

# bn_claude_plugin: register this template's marketplace, from the GitHub
# repository BINNACLE_MARKETPLACE names (<owner>/<repo>), and install or
# update the binnacle plugin at user scope with the claude CLI
# (BINNACLE_CLAUDE, default claude). Each step is idempotent: re-adding a
# marketplace or reinstalling a plugin that is already there changes
# nothing. Skips, successfully and with a message, when claude is not
# installed; fails when BINNACLE_MARKETPLACE is unset or a claude step
# fails.
bn_claude_plugin() {
  local claude=${BINNACLE_CLAUDE:-claude}
  if ! command -v "$claude" >/dev/null 2>&1; then
    bn_warn "claude not found: skipped the binnacle Claude Code plugin. Install Claude Code, then re-run this setup"
    return 0
  fi
  if [ -z "${BINNACLE_MARKETPLACE:-}" ]; then
    bn_warn "skipped the binnacle Claude Code plugin: cannot tell which fork of the binnacle template it comes from. Set BINNACLE_MARKETPLACE=<your-github-user>/binnacle (or BINNACLE_OWNER) and re-run this setup"
    return 1
  fi
  if ! { "$claude" plugin marketplace add "$BINNACLE_MARKETPLACE" --scope user >/dev/null \
    && "$claude" plugin marketplace update "$BN_MARKETPLACE_NAME" >/dev/null \
    && "$claude" plugin install "$BN_PLUGIN" --scope user >/dev/null \
    && "$claude" plugin update "$BN_PLUGIN" --scope user >/dev/null; }; then
    bn_warn "the claude CLI could not install $BN_PLUGIN from $BINNACLE_MARKETPLACE; re-run this setup once it can (network, login)"
    return 1
  fi
  bn_ok "Claude Code plugin $BN_PLUGIN installed and up to date (marketplace $BINNACLE_MARKETPLACE, user scope)"
}
