if vim.fn.has("nvim-0.12") == 0 then
  error("This config requires Neovim 0.12+")
end

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
vim.opt.maxmempattern = 2000000

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
  vim.cmd("silent update")
  vim.cmd(
    "terminal cd "
      .. vim.fn.shellescape(root)
      .. " && uv run python "
      .. vim.fn.shellescape(file)
  )
  vim.cmd("startinsert")
end, { desc = "Run current Python file with uv" })

-- LSP helpers
local lsp_document_highlight_group = vim.api.nvim_create_augroup("LspDocumentHighlight", {
  clear = true,
})

local function buf_supports_lsp_method(bufnr, method)
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    if client:supports_method(method, bufnr) then
      return true
    end
  end

  return false
end

-- LSP keymaps / per-buffer features
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(event)
    local opts = { buf = event.buf }
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
    vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
    vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
    vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
    vim.keymap.set("n", "gt", vim.lsp.buf.type_definition, opts)
    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
    vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts)

    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if not client then
      return
    end

    if client.name == "copilot" then
      vim.lsp.inline_completion.enable(true, {
        bufnr = event.buf,
      })

      vim.keymap.set("i", "<M-l>", function()
        vim.lsp.inline_completion.get({ bufnr = event.buf })
        return ""
      end, {
        buf = event.buf,
        expr = true,
        desc = "Accept Copilot inline completion",
      })

      vim.keymap.set("i", "<M-]>", function()
        vim.lsp.inline_completion.select({
          bufnr = event.buf,
          count = 1,
        })
      end, {
        buffer = event.buf,
        desc = "Next Copilot inline completion",
      })

      vim.keymap.set("i", "<M-[>", function()
        vim.lsp.inline_completion.select({
          bufnr = event.buf,
          count = -1,
        })
      end, {
        buffer = event.buf,
        desc = "Previous Copilot inline completion",
      })
    end

    -- Inlay hints
    if client:supports_method("textDocument/inlayHint", event.buf) then
      vim.lsp.inlay_hint.enable(true, { bufnr = event.buf })
    end

    -- Document highlight:
    -- 只在当前 buffer 至少有一个 LSP 支持 textDocument/documentHighlight 时注册。
    -- 这样可以避免 Copilot LSP / 无 LSP buffer 触发 CursorHold 报错。
    if client:supports_method("textDocument/documentHighlight", event.buf) then
      vim.api.nvim_clear_autocmds({
        group = lsp_document_highlight_group,
        buf = event.buf,
      })
      vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
        group = lsp_document_highlight_group,
        buf = event.buf,
        callback = function(args)
          if buf_supports_lsp_method(args.buf, "textDocument/documentHighlight") then
            vim.lsp.buf.document_highlight()
          end
        end,
      })
      vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufLeave" }, {
        group = lsp_document_highlight_group,
        buffer = event.buf,
        callback = function()
          vim.lsp.buf.clear_references()
        end,
      })
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
        menu = {
          auto_show = true,
        },

        list = {
          selection = {
            preselect = true,
            auto_insert = false,
          },
        },

        -- 避免 blink 自己的 ghost text 和 LSP inline completion 视觉冲突。
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

      -- Copilot LSP:
      -- 给 Neovim 原生 inline completion 和 sidekick.nvim NES 使用。
      vim.lsp.config("copilot", {
        cmd = {
          "copilot-language-server",
          "--stdio",
        },
        root_markers = {
          ".git",
        },
        filetypes = {
          "python",
          "cpp",
          "c",
          "rust",
          "lua",
        },
        init_options = {
          editorInfo = {
            name = "Neovim",
            version = tostring(vim.version()),
          },
          editorPluginInfo = {
            name = "Neovim",
            version = tostring(vim.version()),
          },
        },
      })

      vim.lsp.enable({
        "clangd",
        "pyright",
        "ruff",
        "copilot",
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
        json = { "prettier" },
      },

      formatters = {
        prettier = {
          options = {
            ft_parsers = {
              json = "json",
            },
            ext_parsers = {
              xcs = "json",
            },
          },
        },
      },
    },

    init = function()
      vim.filetype.add({
        extension = {
          xcs = "json",
        },
      })
    end,
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

  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    build = "cd app && npm install",
    init = function()
      vim.g.mkdp_filetypes = { "markdown" }
    end,
    ft = { "markdown" },
  },

  -- AI / NES
  {
    "folke/sidekick.nvim",
    event = {
      "BufReadPost",
      "BufNewFile",
    },
    opts = {
      nes = {
        debounce = 800,

        trigger = {
          events = { "ModeChanged i:n", "TextChanged", "User SidekickNesDone" }
        },

        enabled = function(buf)
          local enabled_filetypes = {
            python = true,
            cpp = true,
            c = true,
            rust = true,
            lua = true,
          }

          return vim.g.sidekick_nes ~= false
            and vim.b[buf].sidekick_nes ~= false
            and enabled_filetypes[vim.bo[buf].filetype] == true
        end,

        diff = {
          inline = "words",
          show = "always",
        },

        signs = false,
        jumplist = false,
      },

      cli = {
        picker = "telescope",
      },
    },
    keys = {
      {
        "<leader>nj",
        function()
          require("sidekick.nes").jump()
        end,
        desc = "Jump to Next Edit Suggestion",
      },
      {
        "<leader>na",
        function()
          require("sidekick.nes").apply()
        end,
        desc = "Apply Next Edit Suggestion",
      },
      {
        "<leader>nu",
        function()
          require("sidekick.nes").update()
        end,
        desc = "Update Next Edit Suggestion",
      },
      {
        "<leader>nd",
        function()
          require("sidekick.nes").clear()
        end,
        desc = "Dismiss Next Edit Suggestion",
      },
      {
        "<leader>nt",
        function()
          require("sidekick.nes").toggle()
        end,
        desc = "Toggle Next Edit Suggestion",
      },
    },
  },
}, {
  git = {
    timeout = 300,
  },
})
