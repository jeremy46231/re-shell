#!/usr/bin/env bash
# ./re          -> interactive shell inside the RE environment
# ./re claude   -> run one command inside it and exit
#
# Lives in the checkout; normally invoked through a symlink in the workspace
# root, so that $PWD is the workspace root and not the checkout.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$here/re-shell/flake.nix" ]; then
  root="$here"
  flake="$here/re-shell"
elif [ -f "$here/flake.nix" ]; then
  root="$(dirname "$here")"
  flake="$here"
else
  echo "re: no flake.nix next to $0" >&2
  exit 1
fi
cd "$root"

command -v nix >/dev/null 2>&1 || export PATH="/nix/var/nix/profiles/default/bin:$PATH"
mkdir -p "$root/.gcroot"

# --profile also registers a GC root, so `nix store gc` won't drop the ~13 GB closure
shell=(nix develop "$flake" --profile "$root/.gcroot/shell" --command)

if [ "$#" -gt 0 ]; then
  exec "${shell[@]}" "$@"
fi

login_shell=${SHELL:-/bin/zsh}

# An interactive zsh reads ~/.zshrc *after* nix develop has set PATH, and a
# `brew shellenv` line there re-prepends /opt/homebrew/bin, shadowing 80+ pinned
# tools (apktool, jadx, mitmproxy, tshark, nmap, protoc, node...). Run the real
# rc files through a shim ZDOTDIR, then put the dev shell's PATH back in front.
if [ "$(basename "$login_shell")" = zsh ]; then
  zdotdir="${XDG_CACHE_HOME:-$HOME/.cache}/re-shell/zdotdir"
  mkdir -p "$zdotdir"
  cat > "$zdotdir/.zshenv" <<'ZSHENV'
[ -r "$RE_HOME_ZDOTDIR/.zshenv" ] && . "$RE_HOME_ZDOTDIR/.zshenv"
ZSHENV
  cat > "$zdotdir/.zshrc" <<'ZSHRC'
ZDOTDIR="$RE_HOME_ZDOTDIR"
[ -r "$ZDOTDIR/.zshrc" ] && . "$ZDOTDIR/.zshrc"
typeset -U path
path=( ${(s.:.)RE_SHELL_PATH} $path )
export PATH
unset RE_SHELL_PATH RE_HOME_ZDOTDIR
ZSHRC
  exec "${shell[@]}" bash -c \
    'RE_SHELL_PATH="$PATH" RE_HOME_ZDOTDIR="${ZDOTDIR:-$HOME}" ZDOTDIR="$1" exec zsh -i' \
    _ "$zdotdir"
fi

exec "${shell[@]}" "$login_shell"
