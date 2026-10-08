# macOS: zsh setup.sh    Kubuntu: bash setup.sh
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
bin="$HOME/.local/bin"

gh_latest() { curl -fsSL "https://github.com/$1/releases/latest/download/$2"; }
gh_tag() { basename "$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$1/releases/latest")"; }

mac() {
  brew install fzf ripgrep fd tree-sitter-cli lua-language-server
  brew install --cask font-symbols-only-nerd-font
}

kubuntu() {
  local arch tag dir fonts
  arch=$(uname -m | sed 's/x86_64/x64/;s/aarch64/arm64/')
  sudo apt-get update
  sudo apt-get install -y curl xz-utils fontconfig fzf ripgrep fd-find wl-clipboard
  ln -sf "$(command -v fdfind)" "$bin/fd"

  # apt 的 tree-sitter 是 0.25，nvim-treesitter main 需要 ≥0.26.1
  gh_latest tree-sitter/tree-sitter "tree-sitter-linux-$arch.gz" | gunzip > "$bin/tree-sitter"
  chmod +x "$bin/tree-sitter"

  tag=$(gh_tag LuaLS/lua-language-server)
  dir="$HOME/.local/share/lua-language-server"
  rm -rf "$dir" && mkdir -p "$dir"
  curl -fsSL "https://github.com/LuaLS/lua-language-server/releases/download/$tag/lua-language-server-$tag-linux-$arch.tar.gz" | tar xz -C "$dir"
  printf '#!/bin/sh\nexec "%s/bin/lua-language-server" "$@"\n' "$dir" > "$bin/lua-language-server"
  chmod +x "$bin/lua-language-server"

  fonts="$HOME/.local/share/fonts/NerdFontsSymbolsOnly"
  mkdir -p "$fonts"
  gh_latest ryanoasis/nerd-fonts NerdFontsSymbolsOnly.tar.xz | tar xJ -C "$fonts"
  fc-cache -f "$fonts"
}

tools() {
  uv tool install --upgrade tombi
  uv tool install --upgrade jupytext
  npm install -g --prefix "$HOME/.local" vscode-langservers-extracted yaml-language-server prettier
}

mkdir -p "$bin"
case "$(uname -s)" in
  Darwin) mac ;;
  Linux) kubuntu ;;
esac
tools
