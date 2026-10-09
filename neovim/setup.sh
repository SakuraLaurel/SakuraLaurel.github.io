#!/bin/sh
set -eu

have() { command -v "$1" >/dev/null 2>&1; }
latest_tag() { curl -fsSLo /dev/null -w '%{url_effective}' "https://github.com/$1/releases/latest" | sed 's#.*/##'; }

macos() {
  # clang / lldb / lldb-dap 来自 Command Line Tools；GUI 安装完成后重跑
  xcode-select -p >/dev/null 2>&1 || { xcode-select --install; exit 1; }
  brew install fzf fd ripgrep tree-sitter-cli lua-language-server
  brew install --cask font-jetbrains-mono-nerd-font
}

kubuntu() {
  arch=$(uname -m | sed 's/x86_64/x64/;s/aarch64/arm64/')
  bin="$HOME/.local/bin"
  sudo apt-get update
  sudo apt-get install -y build-essential gdb curl fzf fd-find ripgrep wl-clipboard
  mkdir -p "$bin"

  # apt 里的 tree-sitter-cli 低于 nvim-treesitter 要求的 0.26.1
  have tree-sitter || {
    curl -fsSL "https://github.com/tree-sitter/tree-sitter/releases/latest/download/tree-sitter-linux-$arch.gz" | gunzip >"$bin/tree-sitter"
    chmod +x "$bin/tree-sitter"
  }

  have lua-language-server || {
    tag=$(latest_tag LuaLS/lua-language-server)
    dir="$HOME/.local/share/lua-language-server"
    mkdir -p "$dir"
    curl -fsSL "https://github.com/LuaLS/lua-language-server/releases/download/$tag/lua-language-server-$tag-linux-$arch.tar.gz" | tar xz -C "$dir"
    printf '#!/bin/sh\nexec "%s/bin/lua-language-server" "$@"\n' "$dir" >"$bin/lua-language-server"
    chmod +x "$bin/lua-language-server"
  }

  font="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
  [ -f "$font/JetBrainsMonoNerdFontMono-Regular.ttf" ] || {
    mkdir -p "$font"
    curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz | tar xJ -C "$font"
    fc-cache -f
  }
}

common() {
  uv tool install tombi
  uv tool install rumdl
  uv tool install jupytext
  npm install -g vscode-langservers-extracted @biomejs/biome
}

case "$(uname -s)" in
  Darwin) macos ;;
  Linux) kubuntu ;;
esac
common
