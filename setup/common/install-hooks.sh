#!/usr/bin/env bash
# Install the Binnacle pre-commit hook into a vault clone. Idempotent.
#
# Usage: setup/common/install-hooks.sh [vault-dir]
#   vault-dir defaults to the repository this script lives in.
#
# Points core.hooksPath at the tracked .githooks/ directory, so hook updates
# arrive with git pull, checks that gitleaks is installed and can scan
# staged changes (the hook refuses every commit without it), warns when its
# version differs from the one .github/workflows/secret-scan.yml pins, and
# records its absolute path in `git config binnacle.gitleaks`, so the hook
# finds it even when a GUI app such as Obsidian runs git with a PATH that
# lacks the install directory.
#
# It never replaces another hook: it stops, changing nothing, when the
# vault's own core.hooksPath already points somewhere else, or when
# .git/hooks holds an active hook that core.hooksPath would switch off. It
# warns when a core.hooksPath from outside the vault's config (global,
# system or environment) would keep .githooks/pre-commit from running.
set -eu

here=$(cd "$(dirname "$0")" && pwd -P)
# shellcheck source=lib.sh
. "$here/lib.sh"

vault=${1:-$here/../..}
vault=$(git -C "$vault" rev-parse --show-toplevel 2>/dev/null) \
  || bn_die "not a git repository: ${1:-$here/../..}"

bn_log "installing hooks in $vault"
[ -f "$vault/.githooks/pre-commit" ] || bn_die "$vault/.githooks/pre-commit is missing"
# Check everything before changing anything.
hooks_path=$(git -C "$vault" config --local --get core.hooksPath || true)
case $hooks_path in
  .githooks | "") ;;
  *) bn_die "core.hooksPath is already '$hooks_path' in $vault; not replacing it, nothing was changed. To fix, either call .githooks/pre-commit from the pre-commit hook in '$hooks_path' (add the line: \"\$(git rev-parse --show-toplevel)/.githooks/pre-commit\" || exit 1), or unset it: git -C \"$vault\" config --unset core.hooksPath. Then re-run your setup script, or setup/common/install-hooks.sh \"$vault\"" ;;
esac
if [ -z "$hooks_path" ]; then
  # core.hooksPath switches off every hook in the default hooks directory.
  default_hooks=$(cd "$vault" && bn_physical_path "$(git rev-parse --git-common-dir)/hooks")
  active=""
  for h in "$default_hooks"/*; do
    [ -f "$h" ] && [ -x "$h" ] || continue
    case $h in *.sample) continue ;; esac
    active="$active $h"
  done
  [ -z "$active" ] \
    || bn_die "active hooks:$active. Setting core.hooksPath=.githooks would silently switch them off (git-lfs hooks included), so nothing was changed. To fix, for each hook either move its logic into $vault/.githooks/ (for example call it from .githooks/<hook-name>), or switch it off: mv <path> <path>.disabled. Then re-run your setup script, or setup/common/install-hooks.sh \"$vault\""
fi

gl=$(bn_find_gitleaks)
if [ -z "$gl" ]; then
  bn_die "gitleaks not found - install it (gitleaks step in setup/<device>/CHECKLIST.md: Homebrew, or the official release binary in ~/.local/bin), then re-run this script; the hook blocks every commit until then"
fi
gl_version=$("$gl" version 2>/dev/null || true)
gl_version=${gl_version#v}
"$gl" git --help 2>/dev/null | grep -q -- '--pre-commit' \
  || bn_die "gitleaks at $gl (version ${gl_version:-unknown}) has no 'gitleaks git --pre-commit --staged' scan (added in gitleaks 8.19); upgrade it, then re-run this script"
bn_ok "gitleaks found: $gl (${gl_version:-unknown version})"
pinned=$(sed -n 's/^[[:space:]]*GITLEAKS_VERSION:[[:space:]]*\([0-9][0-9.]*\).*/\1/p' \
  "$vault/.github/workflows/secret-scan.yml" 2>/dev/null | head -n 1)
if [ -n "$pinned" ] && [ "$gl_version" != "$pinned" ]; then
  bn_warn "gitleaks is ${gl_version:-of unknown version}, but .github/workflows/secret-scan.yml pins $pinned; the hook still scans, but the two may disagree on what counts as a secret. Install $pinned for an exact match"
elif [ -n "$pinned" ]; then
  bn_ok "gitleaks $gl_version matches the version secret-scan.yml pins"
fi

chmod +x "$vault/.githooks/pre-commit"
if [ "$hooks_path" = .githooks ]; then
  bn_ok "core.hooksPath already .githooks"
else
  git -C "$vault" config core.hooksPath .githooks
  bn_ok "core.hooksPath set to .githooks"
fi
effective=$(git -C "$vault" config --get core.hooksPath || true)
[ "$effective" = .githooks ] \
  || bn_warn "core.hooksPath is overridden to '$effective' from outside the vault's config ($(git -C "$vault" config --show-origin --get core.hooksPath | cut -f1)); .githooks/pre-commit does not run while that is set"

if [ "$(git -C "$vault" config --get binnacle.gitleaks || true)" = "$gl" ]; then
  bn_ok "binnacle.gitleaks already $gl"
else
  git -C "$vault" config binnacle.gitleaks "$gl"
  bn_ok "binnacle.gitleaks set to $gl"
fi
