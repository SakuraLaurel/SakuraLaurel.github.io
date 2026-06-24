-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end

vim.opt.rtp:prepend(lazypath)

-- Leader keys
vim.g.mapleader = " "
vim.g.maplocalleader = ","

-- Basic options
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.signcolumn = "yes"
vim.opt.cursorline = true

vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.smartindent = true

vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.opt.splitright = true
vim.opt.splitbelow = true

vim.opt.undofile = true
vim.opt.updatetime = 250
vim.opt.timeoutlen = 400

vim.opt.clipboard = "unnamedplus"

vim.opt.termguicolors = true
vim.opt.background = "light"

vim.opt.foldlevel = 99
vim.opt.foldlevelstart = 99

-- Diagnostics
vim.diagnostic.config({
  virtual_text = true,
  severity_sort = true,
  float = {
    border = "rounded",
    source = "if_many",
  },
})

-- Keymaps
vim.keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "Find files" })
vim.keymap.set("n", "<leader>fg", "<cmd>Telescope live_grep<cr>", { desc = "Live grep" })
vim.keymap.set("n", "<leader>fb", "<cmd>Telescope buffers<cr>", { desc = "Buffers" })
vim.keymap.set("n", "<leader>e", "<cmd>Oil<cr>", { desc = "File explorer" })

-- LSP keymaps
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(event)
    local opts = { buffer = event.buf }

    vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
    vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
    vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
    vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
    vim.keymap.set("n", "gt", vim.lsp.buf.type_definition, opts)
    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
    vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts)

    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if client and client.server_capabilities.inlayHintProvider then
      vim.lsp.inlay_hint.enable(true, { bufnr = event.buf })
    end
  end,
})

require("lazy").setup({
  -- Theme
  {
    "rose-pine/neovim",
    name = "rose-pine",
    config = function()
      require("rose-pine").setup({
        variant = "dawn",
      })
      vim.cmd.colorscheme("rose-pine")
    end,
  },

  -- UI / productivity
  { "nvim-tree/nvim-web-devicons" },
  { "windwp/nvim-autopairs", config = true },
  { "folke/which-key.nvim", config = true },
  { "nvim-lualine/lualine.nvim", config = true },
  { "lewis6991/gitsigns.nvim", config = true },

  {
    "stevearc/oil.nvim",
    config = true,
  },

  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    config = function()
      require("telescope").setup({})
    end,
  },

  -- Treesitter
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "master",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = {
          "bash",
          "c",
          "cpp",
          "cmake",
          "python",
          "markdown",
          "markdown_inline",
          "json",
          "lua",
          "toml",
          "yaml",
          "query",
        },
        highlight = { enable = true },
        indent = { enable = true },
      })
    end,
  },

  -- Completion: blink.cmp
  -- blink.cmp 官方文档支持 lazy.nvim 安装方式。版本稳定性 方面，建议先用 v1。
  -- https://cmp.saghen.dev/
  {
    "saghen/blink.cmp",
    version = "1.*",
    dependencies = {
      "rafamadriz/friendly-snippets",
    },
    opts = {
      keymap = {
        preset = "super-tab",
      },
      appearance = {
        nerd_font_variant = "mono",
      },
      completion = {
        documentation = {
          auto_show = true,
          auto_show_delay_ms = 200,
        },
      },
      signature = {
        enabled = true,
        window = {
          show_documentation = false,
        },
      },
      sources = {
        default = {
          "lsp",
          "path",
          "snippets",
          "buffer",
        },
      },
      fuzzy = {
        implementation = "prefer_rust_with_warning",
      },
    },
    opts_extend = { "sources.default" },
  },

  -- LSP
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "saghen/blink.cmp",
    },
    config = function()
      local capabilities = require("blink.cmp").get_lsp_capabilities()

      vim.lsp.config("clangd", {
        capabilities = capabilities,
        cmd = {
          "clangd",
          "--background-index",
          "--clang-tidy",
          "--completion-style=detailed",
          "--header-insertion=iwyu",
          "--compile-commands-dir=build"
        },
        root_markers = {
          "compile_commands.json",
          "compile_flags.txt",
          ".clangd",
          ".git",
        },
      })

      vim.lsp.config("pyright", {
        capabilities = capabilities,
        settings = {
          python = {
            analysis = {
              typeCheckingMode = "basic",
              autoSearchPaths = true,
              useLibraryCodeForTypes = true,
              diagnosticMode = "workspace",
            },
          },
        },
      })

      vim.lsp.config("ruff", {
        capabilities = capabilities,
      })

      vim.lsp.enable({
        "clangd",
        "pyright",
        "ruff",
      })
    end,
  },

  -- Formatter
  {
    "stevearc/conform.nvim",
    opts = {
      notify_on_error = true,
      notify_no_formatters = false,

      format_on_save = {
        timeout_ms = 1000,
        lsp_format = "fallback",
      },

      formatters_by_ft = {
        c = { "clang_format" },
        cpp = { "clang_format" },
        python = {
          "ruff_organize_imports",
          "ruff_format",
        },
      },
    },
  },

  -- DAP
  {
    "mfussenegger/nvim-dap",
  },

  {
    "mfussenegger/nvim-dap-python",
    dependencies = {
      "mfussenegger/nvim-dap",
    },
    config = function()
      local debugpy = vim.fn.exepath("debugpy-adapter")
      if debugpy ~= "" then
        require("dap-python").setup(debugpy)
      else
        vim.notify("debugpy-adapter not found. Run: pipx install debugpy", vim.log.levels.WARN)
      end
    end,
  },

  -- GitHub Copilot
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    opts = {
      panel = {
        enabled = false,
      },
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
      filetypes = {
        python = true,
        cpp = true,
        help = false,
        ["."] = false,
      },
      copilot_node_command = "node",
    },
  },
}, {
  git = {
    timeout = 300,
  },
})

-- Hide Copilot ghost text when blink.cmp menu is open
vim.api.nvim_create_autocmd("User", {
  pattern = "BlinkCmpMenuOpen",
  callback = function()
    vim.b.copilot_suggestion_hidden = true
  end,
})

vim.api.nvim_create_autocmd("User", {
  pattern = "BlinkCmpMenuClose",
  callback = function()
    vim.b.copilot_suggestion_hidden = false
  end,
})
