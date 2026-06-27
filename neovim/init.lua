-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"                                                          
if not vim.uv.fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--branch=stable",
    lazyrepo,
    lazypath,
  })

  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
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
    source = true,
  },
})

-- Keymaps
vim.keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "Find files" })
vim.keymap.set("n", "<leader>fg", "<cmd>Telescope live_grep<cr>", { desc = "Live grep" })
vim.keymap.set("n", "<leader>e", "<cmd>Oil<cr>", { desc = "File explorer" })

vim.keymap.set("n", "<leader>r", function()
  local file = vim.fn.expand("%:p")
  local root = vim.fs.root(0, { "pyproject.toml", ".git" }) or vim.fn.getcwd()

  vim.cmd("botright 12split")
  vim.cmd(
    "terminal cd "
      .. vim.fn.shellescape(root)
      .. " && uv run python "
      .. vim.fn.shellescape(file)
  )
  vim.cmd("startinsert")
end, { desc = "Run current Python file with uv" })

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
  { "windwp/nvim-autopairs", opts = {} },
  { "folke/which-key.nvim", opts = {} },
  { "nvim-lualine/lualine.nvim", opts = {} },
  { "lewis6991/gitsigns.nvim", opts = {} },
  { "stevearc/oil.nvim", opts = {} },

  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    opts = {},
  },

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
  },

  {
    "romus204/tree-sitter-manager.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("tree-sitter-manager").setup({
        parser_dir = vim.fn.stdpath("data") .. "/site/parser",
        query_dir = vim.fn.stdpath("data") .. "/site/queries",

        ensure_installed = {
          "rust",
          "python",
          "cpp",
        },

        auto_install = false,

        highlight = {
          "rust",
          "python",
          "cpp",
        },

        noauto_install = {
          "c",
          "lua",
          "markdown",
          "markdown_inline",
          "query",
          "vim",
          "vimdoc",
        },

        nerdfont = true,
      })
    end,
  },

  -- Completion
  {
    "saghen/blink.cmp",
    version = "1.*",
    opts = {
      keymap = {
        preset = "super-tab",
      },

      completion = {
        -- 有 Copilot ghost text 时，不自动弹 blink 菜单。
        menu = {
          auto_show = function() 
            local ok, suggestion = pcall(require, "copilot.suggestion")
            return (not ok) or (not suggestion.is_visible())
          end,
        },

        list = {
          selection = {
            preselect = true,
            auto_insert = false,
          },
        },

        documentation = {
          auto_show = true,
          auto_show_delay_ms = 200,
        },

        -- 避免 blink 自己的 ghost text 和 Copilot ghost text 视觉冲突。
        ghost_text = {
          enabled = false,
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
          "buffer",
        },
        providers = {
          snippets = {
            enabled = false,
          },
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
          "--compile-commands-dir=build",
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
        vim.notify("debugpy-adapter not found. Run: uv tool install debugpy", vim.log.levels.WARN)
      end
    end,
  },

  -- GitHub Copilot: 只保留 inline suggestion + NES
  {
    "zbirenbaum/copilot.lua",
    dependencies = {
      {
        "copilotlsp-nvim/copilot-lsp",
        init = function()
          vim.g.copilot_nes_debounce = 500
        end,
        config = function()
          require("copilot-lsp").setup({
            nes = {
              move_count_threshold = 10,
            },
          })
        end,
      },
    },
    cmd = "Copilot",
    event = "InsertEnter",
    config = function()
      require("copilot").setup({
        -- 禁用 Copilot panel，只保留自动补全和 NES。
        panel = {
          enabled = false,
        },

        -- Insert mode inline suggestion。
        suggestion = {
          enabled = true,
          auto_trigger = true,
          hide_during_completion = true,
          debounce = 75,
          keymap = {
            accept = "<M-l>",
            accept_word = false,
            accept_line = false,
            next = "<M-]>",
            prev = "<M-[>",
            dismiss = "<C-]>",
            toggle_auto_trigger = false,
          },
        },

        -- Normal mode Next Edit Suggestion。
        -- 不绑定 Tab，避免和 blink.cmp 抢键。
        nes = {
          enabled = true,
          auto_trigger = true,
          keymap = {
            accept_and_goto = "<leader>cn",
            accept = false,
            dismiss = "<leader>cd",
          },
        },

        filetypes = {
          python = true,
          cpp = true,
          ["*"] = false,
        },

        copilot_node_command = "node",
      })
    end,
  },
}, {
  git = {
    timeout = 300,
  },
})

