你这份配置里 **Copilot 自动补全已经能接受了**，关键在这里：

```lua
suggestion = {
  enabled = true,
  auto_trigger = true,
  hide_during_completion = true,
  keymap = {
    accept = "<M-l>",
    accept_word = "<M-w>",
    accept_line = "<M-j>",
    next = "<M-]>",
    prev = "<M-[>",
    dismiss = "<C-]>",
  },
},
```

`auto_trigger = true` 表示进入 Insert 模式后 Copilot 会自动给 ghost text 建议；`accept` / `accept_word` / `accept_line` 分别是接受整段、接受一个词、接受一行。`copilot.lua` 文档也说明了 auto trigger 和 suggestion keymap 的行为。([GitHub][1])

## 1. 如何接受 Copilot 自动补全

在 Insert 模式里：

| 操作              |      快捷键 | 说明         |
| --------------- | -------: | ---------- |
| 接受整条 Copilot 建议 |  `Alt-l` | 对应 `<M-l>` |
| 只接受一个词          |  `Alt-w` | 对应 `<M-w>` |
| 只接受一行           |  `Alt-j` | 对应 `<M-j>` |
| 下一条建议           |  `Alt-]` | 对应 `<M-]>` |
| 上一条建议           |  `Alt-[` | 对应 `<M-[>` |
| 取消建议            | `Ctrl-]` | 对应 `<C-]>` |

这里的 `<M-l>` 就是 **Meta + l**，一般等价于 **Alt + l**。如果你用 macOS Terminal / iTerm2 / WezTerm，有时需要让 Option 键发送 Meta，否则 `Alt-l` 可能不会被 Neovim 识别。

可以在 Neovim 里测试：

```vim
:verbose imap <M-l>
```

如果没有显示 Copilot 的映射，说明终端没有正确把 `Alt-l` 传给 Neovim。

## 2. 如果 Alt 快捷键不好用，建议改成 Ctrl 快捷键

很多终端对 Alt 键支持不稳定。我建议改成下面这样，更稳：

```lua
keymap = {
  accept = "<C-l>",
  accept_word = "<C-w>",
  accept_line = "<C-j>",
  next = "<C-n>",
  prev = "<C-p>",
  dismiss = "<C-]>",
},
```

但注意：`<C-w>` 在 Insert 模式本来是删除前一个单词，如果你常用这个 Vim 原生操作，就不要占用它。更保守的方案是：

```lua
keymap = {
  accept = "<C-l>",
  accept_word = "<M-w>",
  accept_line = "<M-j>",
  next = "<M-]>",
  prev = "<M-[>",
  dismiss = "<C-]>",
},
```

## 3. 为什么有时候看不到 Copilot 建议

你这里有两层隐藏逻辑：

```lua
hide_during_completion = true,
```

以及：

```lua
vim.api.nvim_create_autocmd("User", {
  pattern = "BlinkCmpMenuOpen",
  callback = function()
    vim.b.copilot_suggestion_hidden = true
  end,
})
```

意思是：**当 blink.cmp 的补全菜单打开时，Copilot ghost text 会被隐藏。** 这和 `copilot.lua` 文档里的 blink.cmp 集成方式一致。([GitHub][1])

所以你的实际使用逻辑应该是：

* blink.cmp 菜单出现时，用 `Tab` / `Shift-Tab` / `Enter` 处理 LSP、路径、snippet、buffer 补全。
* 没有 blink.cmp 菜单、但出现灰色 ghost text 时，用 `Alt-l` 接受 Copilot。
* 想优先看 Copilot，就先关掉补全菜单，再等 ghost text 出现。

可以临时检查 Copilot 状态：

```vim
:Copilot status
```

如果还没登录，执行：

```vim
:Copilot auth
```

另外，你现在配置里只开启了这些 filetype：

```lua
filetypes = {
  python = true,
  cpp = true,
  help = false,
  ["."] = false,
},
```

所以 Lua、Markdown、C、JSON 里可能不会启用。建议改成：

```lua
filetypes = {
  python = true,
  cpp = true,
  c = true,
  lua = true,
  markdown = true,
  gitcommit = true,
  help = false,
  ["."] = false,
},
```

## 4. 你现在 Git 插件已经装了，但没有配置快捷键

你装了：

```lua
{ "lewis6991/gitsigns.nvim", config = true },
```

这会显示 Git 变更符号，比如新增、修改、删除行。`gitsigns.nvim` 的核心功能就是在 sign column 显示 Git 变更，并支持 hunk stage、reset、preview、blame、diff 等操作。([GitHub][2])

但 `config = true` 只是默认启用，没有给你绑常用快捷键。建议改成下面这样：

```lua
{
  "lewis6991/gitsigns.nvim",
  config = function()
    require("gitsigns").setup({
      current_line_blame = false,

      on_attach = function(bufnr)
        local gs = require("gitsigns")

        local function map(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, {
            buffer = bufnr,
            desc = desc,
          })
        end

        -- 跳转 Git hunk
        map("n", "]h", function()
          gs.nav_hunk("next")
        end, "Next git hunk")

        map("n", "[h", function()
          gs.nav_hunk("prev")
        end, "Previous git hunk")

        -- 操作当前 hunk
        map("n", "<leader>hs", gs.stage_hunk, "Stage hunk")
        map("n", "<leader>hr", gs.reset_hunk, "Reset hunk")
        map("n", "<leader>hp", gs.preview_hunk, "Preview hunk")
        map("n", "<leader>hi", gs.preview_hunk_inline, "Preview hunk inline")

        -- 视觉模式下只 stage/reset 选中部分
        map("v", "<leader>hs", function()
          gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, "Stage selected hunk")

        map("v", "<leader>hr", function()
          gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, "Reset selected hunk")

        -- 整个 buffer
        map("n", "<leader>hS", gs.stage_buffer, "Stage buffer")
        map("n", "<leader>hR", gs.reset_buffer, "Reset buffer")

        -- blame / diff
        map("n", "<leader>hb", function()
          gs.blame_line({ full = true })
        end, "Blame line")

        map("n", "<leader>hd", gs.diffthis, "Diff this")
        map("n", "<leader>hD", function()
          gs.diffthis("~")
        end, "Diff against previous commit")

        -- toggle
        map("n", "<leader>tb", gs.toggle_current_line_blame, "Toggle git blame")
        map("n", "<leader>tw", gs.toggle_word_diff, "Toggle word diff")
      end,
    })
  end,
}
```

`gitsigns.nvim` 官方 README 也推荐通过 `on_attach` 为当前 buffer 设置 hunk navigation、stage/reset、preview、blame、diff 等映射。([GitHub][2])

## 5. 建议你的 Git 工作流这样用

日常开发时，推荐这个节奏：

```bash
git status
git switch -c feature/xxx
# 写代码
git diff
git add -p
git commit -m "feat: xxx"
git pull --rebase
git push
```

在 Neovim 里对应：

| 场景         | 操作             |
| ---------- | -------------- |
| 看哪里改了      | 左侧 sign column |
| 跳到下一个改动    | `]h`           |
| 跳到上一个改动    | `[h`           |
| 预览当前改动     | `<leader>hp`   |
| 只暂存当前 hunk | `<leader>hs`   |
| 撤销当前 hunk  | `<leader>hr`   |
| 看当前行是谁改的   | `<leader>hb`   |
| 看当前文件 diff | `<leader>hd`   |

最重要的是养成 **小粒度提交**：

```bash
git add -p
git commit -m "fix: handle empty compile_commands path"
```

不要习惯性：

```bash
git add .
git commit -m "update"
```

更好的提交信息格式：

```text
feat: add clangd configuration
fix: prevent copilot ghost text during completion
refactor: simplify lsp attach mappings
docs: update setup instructions
chore: update lazy lockfile
```

## 6. 可以再加一个 Git 命令插件

`gitsigns.nvim` 适合做 buffer 内的 hunk 操作，但它不是完整 Git UI。如果你想在 Neovim 里更舒服地 commit、push、pull、看 log，建议加 `vim-fugitive`：

```lua
{
  "tpope/vim-fugitive",
  cmd = {
    "Git",
    "G",
    "Gdiffsplit",
    "Gread",
    "Gwrite",
    "Ggrep",
    "GMove",
    "GDelete",
    "GBrowse",
  },
}
```

再加几个键：

```lua
vim.keymap.set("n", "<leader>gs", "<cmd>Git<cr>", { desc = "Git status" })
vim.keymap.set("n", "<leader>gc", "<cmd>Git commit<cr>", { desc = "Git commit" })
vim.keymap.set("n", "<leader>gp", "<cmd>Git push<cr>", { desc = "Git push" })
vim.keymap.set("n", "<leader>gl", "<cmd>Git log --oneline --graph --decorate<cr>", { desc = "Git log" })
```

这样分工会很清晰：

* `gitsigns.nvim`：看当前文件变更、stage/reset hunk、blame。
* `vim-fugitive`：commit、push、pull、log、status。
* CLI：复杂 rebase、stash、bisect、cherry-pick。

## 7. 我建议你最终改两处

第一，Copilot 如果 Alt 不稳，换一个更稳定的 accept 键：

```lua
accept = "<C-l>",
```

第二，把 gitsigns 从：

```lua
{ "lewis6991/gitsigns.nvim", config = true },
```

换成上面那段带 `on_attach` 的完整配置。

这样你会得到一个比较顺手的工作流：**blink 负责普通补全，Copilot 负责整段 ghost text，gitsigns 负责精细化 Git hunk 操作。**

[1]: https://github.com/zbirenbaum/copilot.lua "GitHub - zbirenbaum/copilot.lua: Fully featured & enhanced replacement for copilot.vim complete with API for interacting with Github Copilot · GitHub"
[2]: https://github.com/lewis6991/gitsigns.nvim "GitHub - lewis6991/gitsigns.nvim: Git integration for buffers · GitHub"
