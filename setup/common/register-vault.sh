#!/usr/bin/env bash
# Tell Claude Code on this machine about a Binnacle vault. Idempotent.
#
# Usage: setup/common/register-vault.sh NAME DIR SCOPE
#        setup/common/register-vault.sh --remove DIR
#
#   NAME   the vault's name, e.g. its repository name
#   DIR    where the vault lives on this machine
#   SCOPE  one line saying what the vault may hold
#
# Registers this template's Claude Code plugin marketplace and installs or
# updates the binnacle plugin at user scope (skipped, with a message, when
# claude is not installed), then adds or refreshes DIR's row in the marked
# block of ~/.claude/CLAUDE.md, between <!-- binnacle:begin --> and
# <!-- binnacle:end -->, creating the file or the block when absent. Rows
# are keyed by DIR; nothing outside the block changes. The setup scripts
# run it; run it by hand only to remove a vault.
#
#   --remove DIR  drop DIR's row, and the block once it lists no vault;
#                 the plugin stays installed.
#
# Env: BINNACLE_CLAUDE (claude), BINNACLE_MARKETPLACE
#      (<BINNACLE_OWNER>/binnacle-template, the repository that publishes
#      the marketplace).
# Exits 1 when the plugin step fails; the row is written first either way.
set -eu

here=$(cd "$(dirname "$0")" && pwd -P)
# shellcheck source=lib.sh
. "$here/lib.sh"

usage() { sed -n '2,/^set -eu/p' "$0" | sed '$d; s/^# \{0,1\}//'; }

one_line() { # what, value: die unless value is one non-empty line
  case $2 in
    "" | *$'\n'* | *$'\r'*) bn_die "$1 must be one non-empty line" ;;
  esac
}
vault_path() { # DIR -> its absolute, symlink-free path
  local d=$1
  # A literal leading ~ means $HOME.
  # shellcheck disable=SC2088
  case $d in
    "~") d=$HOME ;;
    "~/"*) d=$HOME/${d#"~/"} ;;
  esac
  one_line DIR "$d"
  d=$(bn_physical_path "$d")
  case $d in *'`'*) bn_die "DIR may not contain a backtick: $d" ;; esac
  printf '%s\n' "${d%/}"
}

md=$(bn_claude_md)
case "${1:-}" in
  -h | --help) usage; exit 0 ;;
  --remove)
    [ "$#" -eq 2 ] || { usage >&2; exit 2; }
    dir=$(vault_path "$2")
    bn_vault_list_edit "$md" "$dir"
    bn_ok "$dir is no longer listed in $md"
    exit 0 ;;
esac
[ "$#" -eq 3 ] || { usage >&2; exit 2; }
one_line NAME "$1"
one_line SCOPE "$3"
dir=$(vault_path "$2")
[ -d "$dir" ] || bn_die "$dir is not a folder"

bn_vault_list_edit "$md" "$dir" "$(bn_vault_row "$1" "$dir" "$3")"
bn_ok "$1 ($dir) listed in $md"
bn_claude_plugin
