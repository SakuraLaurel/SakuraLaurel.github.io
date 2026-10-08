# 系统

- macOS 27.0.1
- kubuntu 26.04 LTS

# 输出

- 单一neovim init.lua脚本
- 单一依赖安装sh脚本，macOS是zsh，kubuntu是bash

# 脚本风格

- 简洁，幂等性以外无防御性，失败直接退出、我修复后重新运行。
- 先运行sh安装依赖，然后我把init.lua拷贝到目标路径。
- 只保留必要注释
- 函数式

# 偏好

- 50%主流 + 20%轻量 + 20%前卫 + 10%原生
- <leader>用空格键
- 向kickstart.nvim的习惯靠近

# 依赖

- public（已安装）:
  - neovim 0.12+（跑在默认终端上）
  - nodejs（用于安装一些语言的lsp）
  - uv / ruff / ty
  - clangd
- macOS:
  - homebrew（已安装）
  - clang
  - lldb
- kubuntu:
  - gcc
  - gdb

# 支持语言:

- Python
- C++
- markdown
- Lua, JSON, TOML

# 指名

- 主题：rose-pine-dawn，保持浅色
- 插件管理：vim.pack
- 代码补全：blink.cmp
- 模糊查找: fzf-lua
- 格式化：conform.nvim
- 文件管理：oil.nvim
- git: gitsigns.nvim, codediff.nvim, 提交走命令行
- lsp: nvim-lspconfig
- markdown: render-markdown.nvim
- 其他: nvim-autopairs, jupytext.nvim

# 注意点

- 核对最新情况，如treesitter被archive后unarchive，重新成为最佳选择
- 2025 年 3 月，之后 nvim-dap 一直没再发版。nvim-dap-view 1.x 用到了 dap.listeners.on_session，这个接口只在 nvim-dap 的 master 分支上有，0.10.0 里没有。
- 有不确定的，继续问我
