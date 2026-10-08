vim.loader.enable()
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

local function each(t, f) vim.iter(t):each(f) end

local function map(specs, opts)
    each(specs, function(s)
        vim.keymap.set(s[1], s[2], s[3], vim.tbl_extend('force', { desc = s[4] }, opts or {}))
    end)
end

local function gh(repo) return 'https://github.com/' .. repo end

each({
    number = true,
    relativenumber = true,
    signcolumn = 'yes',
    cursorline = true,
    termguicolors = true,
    background = 'light',
    mouse = 'a',
    undofile = true,
    ignorecase = true,
    smartcase = true,
    splitright = true,
    splitbelow = true,
    scrolloff = 8,
    expandtab = true,
    shiftwidth = 4,
    tabstop = 4,
    updatetime = 250,
    timeoutlen = 300,
    confirm = true,
    laststatus = 3,
    winborder = 'rounded',
    inccommand = 'split',
    list = true,
    foldlevelstart = 99,
    foldmethod = 'expr',
    foldexpr = 'v:lua.vim.treesitter.foldexpr()',
}, function(k, v) vim.o[k] = v end)
vim.schedule(function() vim.o.clipboard = 'unnamedplus' end)

-- 必须在 vim.pack.add 之前注册
vim.api.nvim_create_autocmd('PackChanged', {
    callback = function(ev)
        if ev.data.spec.name == 'nvim-treesitter' and ev.data.kind == 'update' then
            if not ev.data.active then vim.cmd.packadd('nvim-treesitter') end
            vim.cmd('TSUpdate')
        end
    end,
})

vim.pack.add({
    { src = gh('rose-pine/neovim'), name = 'rose-pine' },
    gh('nvim-mini/mini.icons'),
    gh('folke/which-key.nvim'),
    gh('nvim-treesitter/nvim-treesitter'),
    gh('neovim/nvim-lspconfig'),
    gh('b0o/SchemaStore.nvim'),
    gh('rafamadriz/friendly-snippets'),
    { src = gh('saghen/blink.cmp'), version = vim.version.range('1.*') },
    gh('ibhagwan/fzf-lua'),
    gh('stevearc/conform.nvim'),
    gh('stevearc/oil.nvim'),
    gh('lewis6991/gitsigns.nvim'),
    gh('esmuellert/codediff.nvim'),
    gh('MeanderingProgrammer/render-markdown.nvim'),
    gh('windwp/nvim-autopairs'),
    gh('GCBallesteros/jupytext.nvim'),
    -- 不指定 version：跟 master，nvim-dap-view 1.x 需要 on_session
    gh('mfussenegger/nvim-dap'),
    gh('mfussenegger/nvim-dap-python'),
    { src = gh('igorlfs/nvim-dap-view'), version = vim.version.range('1.*') },
})

require('rose-pine').setup({ variant = 'dawn', dark_variant = 'dawn' })
vim.cmd.colorscheme('rose-pine-dawn')

require('mini.icons').setup()
MiniIcons.mock_nvim_web_devicons()

require('which-key').setup({
    spec = {
        { '<leader>f', group = 'find' },
        { '<leader>g', group = 'git' },
        { '<leader>h', group = 'hunk' },
        { '<leader>d', group = 'debug' },
        { '<leader>c', group = 'code' },
        { '<leader>t', group = 'toggle' },
    },
})

-- treesitter
require('nvim-treesitter').install({
    'bash', 'c', 'cpp', 'python', 'lua', 'luadoc', 'vim', 'vimdoc', 'query',
    'markdown', 'markdown_inline', 'json', 'yaml', 'toml',
    'diff', 'gitcommit', 'git_config', 'git_rebase', 'regex',
})
vim.api.nvim_create_autocmd('FileType', {
    callback = function(ev)
        if pcall(vim.treesitter.start, ev.buf) then
            vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
    end,
})

-- lsp
vim.lsp.config('lua_ls', {
    settings = {
        Lua = {
            runtime = { version = 'LuaJIT' },
            workspace = { checkThirdParty = false, library = { vim.env.VIMRUNTIME } },
        },
    },
})
vim.lsp.config('jsonls', {
    settings = { json = { schemas = require('schemastore').json.schemas(), validate = { enable = true } } },
})
vim.lsp.config('yamlls', {
    settings = { yaml = { schemaStore = { enable = false, url = '' }, schemas = require('schemastore').yaml.schemas() } },
})
vim.lsp.enable({ 'lua_ls', 'jsonls', 'yamlls', 'tombi', 'ruff', 'ty', 'clangd' })
vim.lsp.inlay_hint.enable()
vim.diagnostic.config({ severity_sort = true, virtual_text = true, float = { source = true } })

vim.api.nvim_create_autocmd('LspAttach', {
    callback = function(ev)
        local client = vim.lsp.get_client_by_id(ev.data.client_id)
        -- hover 交给 ty
        if client and client.name == 'ruff' then client.server_capabilities.hoverProvider = false end
    end,
})

-- 补全 / 编辑
require('blink.cmp').setup({
    keymap = { preset = 'default' },
    completion = { documentation = { auto_show = true } },
    signature = { enabled = true },
    sources = { default = { 'lsp', 'path', 'snippets', 'buffer' } },
    fuzzy = { implementation = 'prefer_rust_with_warning' },
})
require('nvim-autopairs').setup({ check_ts = true })

require('conform').setup({
    formatters_by_ft = {
        python = { 'ruff_organize_imports', 'ruff_format' },
        json = { 'prettier' },
        jsonc = { 'prettier' },
        yaml = { 'prettier' },
        markdown = { 'prettier' },
    },
    default_format_opts = { lsp_format = 'fallback' },
    format_on_save = { timeout_ms = 1000 },
})
vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"

require('render-markdown').setup({})
require('jupytext').setup({ style = 'percent' })
require('oil').setup({ view_options = { show_hidden = true } })

local fzf = require('fzf-lua')
fzf.setup({})
fzf.register_ui_select()

-- git
require('gitsigns').setup({
    on_attach = function(buf)
        local gs = require('gitsigns')
        local function nav(dir, key)
            return function()
                if vim.wo.diff then vim.cmd.normal({ key, bang = true }) else gs.nav_hunk(dir) end
            end
        end
        local function range(f) return function() f({ vim.fn.line('.'), vim.fn.line('v') }) end end
        map({
            { 'n',          ']c',         nav('next', ']c'),                             'Next hunk' },
            { 'n',          '[c',         nav('prev', '[c'),                             'Prev hunk' },
            { 'n',          '<leader>hs', gs.stage_hunk,                                 'Stage hunk' },
            { 'v',          '<leader>hs', range(gs.stage_hunk),                          'Stage hunk' },
            { 'n',          '<leader>hr', gs.reset_hunk,                                 'Reset hunk' },
            { 'v',          '<leader>hr', range(gs.reset_hunk),                          'Reset hunk' },
            { 'n',          '<leader>hS', gs.stage_buffer,                               'Stage buffer' },
            { 'n',          '<leader>hR', gs.reset_buffer,                               'Reset buffer' },
            { 'n',          '<leader>hp', gs.preview_hunk,                               'Preview hunk' },
            { 'n',          '<leader>hi', gs.preview_hunk_inline,                        'Preview hunk inline' },
            { 'n',          '<leader>hb', function() gs.blame_line({ full = true }) end, 'Blame line' },
            { 'n',          '<leader>hB', gs.blame,                                      'Blame buffer' },
            { 'n',          '<leader>hd', gs.diffthis,                                   'Diff this' },
            { 'n',          '<leader>hq', gs.setqflist,                                  'Hunks to quickfix' },
            { 'n',          '<leader>tb', gs.toggle_current_line_blame,                  'Toggle line blame' },
            { 'n',          '<leader>tw', gs.toggle_word_diff,                           'Toggle word diff' },
            { { 'o', 'x' }, 'ih',         gs.select_hunk,                                'Hunk' },
        }, { buffer = buf })
    end,
})

-- dap
local dap = require('dap')
require('dap-view').setup({ auto_toggle = true })
require('dap-python').setup('uv')
dap.adapters.native = vim.fn.has('mac') == 1
    and { type = 'executable', command = 'xcrun', args = { 'lldb-dap' } }
    or { type = 'executable', command = 'gdb', args = { '--interpreter=dap', '--eval-command', 'set print pretty on' } }
each({ 'c', 'cpp' }, function(ft)
    dap.configurations[ft] = {
        { name = 'Launch', type = 'native', request = 'launch', program = '${command:pickFile}', cwd = '${workspaceFolder}' },
    }
end)
vim.fn.sign_define('DapBreakpoint', { text = '●', texthl = 'DiagnosticError' })

-- keymaps
map({
    { 'n',          '<Esc>',           '<cmd>nohlsearch<cr>' },
    { 'n',          '<C-h>',           '<C-w>h',                                                                      'Window left' },
    { 'n',          '<C-j>',           '<C-w>j',                                                                      'Window down' },
    { 'n',          '<C-k>',           '<C-w>k',                                                                      'Window up' },
    { 'n',          '<C-l>',           '<C-w>l',                                                                      'Window right' },
    { 'n',          '-',               '<cmd>Oil<cr>',                                                                'Parent directory' },

    { 'n',          '<leader><space>', fzf.files,                                                                     'Files' },
    { 'n',          '<leader>/',       fzf.live_grep,                                                                 'Grep' },
    { 'n',          '<leader>ff',      fzf.files,                                                                     'Files' },
    { 'n',          '<leader>fg',      fzf.live_grep,                                                                 'Grep' },
    { { 'n', 'x' }, '<leader>fw',      fzf.grep_cword,                                                                'Grep word' },
    { 'n',          '<leader>fb',      fzf.buffers,                                                                   'Buffers' },
    { 'n',          '<leader>fr',      fzf.oldfiles,                                                                  'Recent' },
    { 'n',          '<leader>fh',      fzf.helptags,                                                                  'Help' },
    { 'n',          '<leader>fk',      fzf.keymaps,                                                                   'Keymaps' },
    { 'n',          '<leader>fd',      fzf.diagnostics_document,                                                      'Diagnostics' },
    { 'n',          '<leader>fD',      fzf.diagnostics_workspace,                                                     'Workspace diagnostics' },
    { 'n',          '<leader>fs',      fzf.lsp_document_symbols,                                                      'Symbols' },
    { 'n',          '<leader>fS',      fzf.lsp_live_workspace_symbols,                                                'Workspace symbols' },
    { 'n',          '<leader>f.',      fzf.resume,                                                                    'Resume' },

    { 'n',          'gd',              fzf.lsp_definitions,                                                           'Definition' },
    { 'n',          'gD',              vim.lsp.buf.declaration,                                                       'Declaration' },
    { { 'n', 'x' }, '<leader>cf',      function() require('conform').format() end,                                    'Format' },
    { 'n',          '<leader>th',      function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled()) end, 'Toggle inlay hints' },

    { 'n',          '<leader>gd',      '<cmd>CodeDiff<cr>',                                                           'Changes (VSCode diff)' },
    { 'n',          '<leader>gh',      '<cmd>CodeDiff history<cr>',                                                   'Repo history' },
    { 'n',          '<leader>gf',      '<cmd>CodeDiff history %<cr>',                                                 'File history' },
    { 'n',          '<leader>gs',      fzf.git_status,                                                                'Status' },
    { 'n',          '<leader>gc',      fzf.git_commits,                                                               'Commits' },
    { 'n',          '<leader>gC',      fzf.git_bcommits,                                                              'Buffer commits' },
    { 'n',          '<leader>gb',      fzf.git_branches,                                                              'Branches' },

    { 'n',          '<F5>',            dap.continue,                                                                  'Debug: continue' },
    { 'n',          '<F9>',            dap.toggle_breakpoint,                                                         'Debug: breakpoint' },
    { 'n',          '<F10>',           dap.step_over,                                                                 'Debug: step over' },
    { 'n',          '<F11>',           dap.step_into,                                                                 'Debug: step into' },
    { 'n',          '<leader>dc',      dap.continue,                                                                  'Continue' },
    { 'n',          '<leader>db',      dap.toggle_breakpoint,                                                         'Breakpoint' },
    { 'n',          '<leader>dB',      function() dap.set_breakpoint(vim.fn.input('Condition: ')) end,                'Conditional breakpoint' },
    { 'n',          '<leader>di',      dap.step_into,                                                                 'Step into' },
    { 'n',          '<leader>dO',      dap.step_over,                                                                 'Step over' },
    { 'n',          '<leader>do',      dap.step_out,                                                                  'Step out' },
    { 'n',          '<leader>dt',      dap.terminate,                                                                 'Terminate' },
    { 'n',          '<leader>dr',      dap.repl.toggle,                                                               'REPL' },
    { 'n',          '<leader>du',      function() require('dap-view').toggle() end,                                   'Debug view' },
    { 'n',          '<leader>dm',      function() require('dap-python').test_method() end,                            'Debug test method' },
})
