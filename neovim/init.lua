vim.g.mapleader = ' '

vim.iter({
  number = true,
  cursorline = true,
  signcolumn = 'yes',
  scrolloff = 10,
  list = true,
  listchars = 'tab:» ,trail:·,nbsp:␣',
  breakindent = true,
  expandtab = true,
  tabstop = 4,
  shiftwidth = 0,
  ignorecase = true,
  smartcase = true,
  inccommand = 'split',
  splitright = true,
  splitbelow = true,
  undofile = true,
  updatetime = 250,
  confirm = true,
  winborder = 'rounded',
}):each(function(k, v) vim.o[k] = v end)
vim.schedule(function() vim.o.clipboard = 'unnamedplus' end)

-- 解析器版本必须跟随 nvim-treesitter 版本，须在 vim.pack.add 之前注册
vim.api.nvim_create_autocmd('PackChanged', {
  callback = function(ev)
    if ev.data.spec.name == 'nvim-treesitter' and ev.data.kind == 'update' then
      if not ev.data.active then vim.cmd.packadd('nvim-treesitter') end
      vim.cmd('TSUpdate')
    end
  end,
})

local gh = function(repo) return 'https://github.com/' .. repo end
local cb = function(repo) return 'https://codeberg.org/' .. repo end

vim.pack.add({
  { src = gh('rose-pine/neovim'), name = 'rose-pine' },
  gh('nvim-treesitter/nvim-treesitter'),
  gh('neovim/nvim-lspconfig'),
  -- 跟随 v1 tag 才会自动下载预编译模糊匹配库；v2 尚未发布
  { src = gh('saghen/blink.cmp'), version = vim.version.range('1') },
  gh('ibhagwan/fzf-lua'),
  gh('nvim-mini/mini.icons'),
  gh('stevearc/conform.nvim'),
  gh('stevearc/oil.nvim'),
  gh('lewis6991/gitsigns.nvim'),
  gh('esmuellert/codediff.nvim'),
  gh('MeanderingProgrammer/render-markdown.nvim'),
  gh('windwp/nvim-autopairs'),
  gh('GCBallesteros/jupytext.nvim'),
  -- 不指定 version 即跟随 master，nvim-dap-view 需要 master 上的 listeners.on_session
  cb('mfussenegger/nvim-dap'),
  cb('mfussenegger/nvim-dap-python'),
  { src = gh('igorlfs/nvim-dap-view'), version = vim.version.range('1') },
})
vim.cmd.packadd('nvim.undotree')

vim.cmd.colorscheme('rose-pine-dawn')

vim.iter({ 'mini.icons', 'oil', 'gitsigns', 'nvim-autopairs', 'jupytext' })
  :each(function(m) require(m).setup() end)
require('blink.cmp').setup({ signature = { enabled = true } })
require('fzf-lua').register_ui_select()
require('dap-view').setup({ auto_toggle = true, virtual_text = { enabled = true } })
require('conform').setup({
  default_format_opts = { lsp_format = 'fallback' },
  -- C++ 没有统一风格，不在保存时格式化（同 kickstart）
  format_on_save = function(buf) return vim.bo[buf].filetype ~= 'cpp' and {} or nil end,
  formatters_by_ft = {
    python = { 'ruff_organize_imports', 'ruff_format' },
    json = { 'biome' },
    jsonc = { 'biome' },
    toml = { 'tombi' },
    markdown = { 'rumdl' },
  },
})

require('nvim-treesitter').install({ 'python', 'cpp', 'json', 'toml' })
vim.api.nvim_create_autocmd('FileType', {
  callback = function(ev)
    local lang = vim.treesitter.language.get_lang(ev.match)
    if lang and vim.treesitter.language.add(lang) then vim.treesitter.start(ev.buf, lang) end
  end,
})

vim.lsp.config('lua_ls', {
  settings = { Lua = { runtime = { version = 'LuaJIT' }, workspace = { library = { vim.env.VIMRUNTIME } } } },
})
vim.lsp.enable({ 'ty', 'ruff', 'clangd', 'lua_ls', 'jsonls', 'tombi', 'rumdl' })
vim.diagnostic.config({ severity_sort = true, virtual_text = true, float = { source = 'if_many' } })

local dap = require('dap')
require('dap-python').setup('uv')
dap.adapters.native = vim.fn.has('mac') == 1
    and { type = 'executable', command = 'xcrun', args = { 'lldb-dap' } }
  or { type = 'executable', command = 'gdb', args = { '--interpreter=dap', '--eval-command', 'set print pretty on' } }
dap.configurations.cpp = {
  {
    name = 'Launch',
    type = 'native',
    request = 'launch',
    cwd = '${workspaceFolder}',
    program = function() return vim.fn.input('Executable: ', vim.fn.getcwd() .. '/', 'file') end,
  },
}

vim.api.nvim_create_autocmd('TextYankPost', { callback = function() vim.hl.on_yank() end })

local fzf, gs = require('fzf-lua'), require('gitsigns')
local cmd = function(c) return '<cmd>' .. c .. '<cr>' end

vim.iter({
  { 'n', '<Esc>', cmd('nohlsearch') },
  { 't', '<Esc><Esc>', '<C-\\><C-n>', 'Exit terminal mode' },
  { 'n', '<C-h>', '<C-w><C-h>', 'Focus left window' },
  { 'n', '<C-l>', '<C-w><C-l>', 'Focus right window' },
  { 'n', '<C-j>', '<C-w><C-j>', 'Focus lower window' },
  { 'n', '<C-k>', '<C-w><C-k>', 'Focus upper window' },
  { 'n', '-', cmd('Oil'), 'Open parent directory' },
  { 'n', '<leader>u', cmd('Undotree'), 'Undotree' },
  { 'n', '<leader>q', vim.diagnostic.setloclist, 'Diagnostic list' },
  { '', '<leader>f', function() require('conform').format({ async = true }) end, 'Format buffer' },
  { 'n', '<leader>th', function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled()) end, 'Toggle inlay hints' },
  { 'n', '<leader>tb', gs.toggle_current_line_blame, 'Toggle line blame' },

  { 'n', '<leader>sh', fzf.helptags, 'Search help' },
  { 'n', '<leader>sk', fzf.keymaps, 'Search keymaps' },
  { 'n', '<leader>sf', fzf.files, 'Search files' },
  { 'n', '<leader>ss', fzf.builtin, 'Search pickers' },
  { 'n', '<leader>sw', fzf.grep_cword, 'Search word' },
  { 'x', '<leader>sw', fzf.grep_visual, 'Search selection' },
  { 'n', '<leader>sg', fzf.live_grep, 'Search by grep' },
  { 'n', '<leader>sd', fzf.diagnostics_workspace, 'Search diagnostics' },
  { 'n', '<leader>sr', fzf.resume, 'Search resume' },
  { 'n', '<leader>s.', fzf.oldfiles, 'Search recent files' },
  { 'n', '<leader>s/', fzf.lines, 'Search open buffers' },
  { 'n', '<leader>sn', function() fzf.files({ cwd = vim.fn.stdpath('config') }) end, 'Search Neovim config' },
  { 'n', '<leader>/', fzf.blines, 'Search current buffer' },
  { 'n', '<leader><leader>', fzf.buffers, 'Find buffers' },

  { 'n', 'grr', fzf.lsp_references, 'References' },
  { 'n', 'gri', fzf.lsp_implementations, 'Implementations' },
  { 'n', 'grd', fzf.lsp_definitions, 'Definitions' },
  { 'n', 'grD', fzf.lsp_declarations, 'Declarations' },
  { 'n', 'grt', fzf.lsp_typedefs, 'Type definitions' },
  { 'n', 'gO', fzf.lsp_document_symbols, 'Document symbols' },
  { 'n', 'gW', fzf.lsp_live_workspace_symbols, 'Workspace symbols' },

  { 'n', ']c', function() gs.nav_hunk('next') end, 'Next hunk' },
  { 'n', '[c', function() gs.nav_hunk('prev') end, 'Prev hunk' },
  { 'n', '<leader>gb', function() gs.blame_line({ full = true }) end, 'Git blame line' },
  { 'n', '<leader>gd', cmd('CodeDiff'), 'Git changes' },
  { 'n', '<leader>gf', cmd('CodeDiff file HEAD'), 'Git diff file vs HEAD' },
  { 'n', '<leader>gh', cmd('CodeDiff history'), 'Git history' },
  { 'x', '<leader>gh', ':CodeDiff history<cr>', 'Git history of selection' },

  { 'n', '<leader>dc', dap.continue, 'Debug: start/continue' },
  { 'n', '<leader>db', dap.toggle_breakpoint, 'Debug: toggle breakpoint' },
  { 'n', '<leader>dB', function() dap.set_breakpoint(vim.fn.input('Condition: ')) end, 'Debug: conditional breakpoint' },
  { 'n', '<leader>di', dap.step_into, 'Debug: step into' },
  { 'n', '<leader>do', dap.step_over, 'Debug: step over' },
  { 'n', '<leader>dO', dap.step_out, 'Debug: step out' },
  { 'n', '<leader>dr', dap.run_last, 'Debug: run last' },
  { 'n', '<leader>dq', dap.terminate, 'Debug: terminate' },
  { 'n', '<leader>dv', cmd('DapViewToggle'), 'Debug: toggle view' },
  { 'n', '<leader>dw', cmd('DapViewWatch'), 'Debug: watch expression' },
}):each(function(m) vim.keymap.set(m[1], m[2], m[3], { desc = m[4] }) end)
