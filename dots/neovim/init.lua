-- Leaders
vim.g.mapleader = ' ' -- space
vim.g.maplocalleader = ','

-- Colors
require('theme')(require('palette'))
require('nvim-highlight-colors').setup({
  enable_named_colors = false,
})

-- UI / display
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true
vim.opt.signcolumn = 'yes'

-- Indentation
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.softtabstop = -1

-- Text editing and search
vim.opt.textwidth = 80
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Window behavior and scrolling
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.scrolloff = 10

-- Responsiveness
vim.opt.updatetime = 250
vim.opt.timeoutlen = 500

-- Persistence and system integration
vim.opt.undofile = true
vim.opt.clipboard = 'unnamedplus'

-- Completion
vim.opt.completeopt = { 'menu', 'menuone', 'noselect', 'fuzzy' }
vim.opt.wildoptions:append('fuzzy')

vim.keymap.set('i', '<Tab>', function()
  if vim.fn.pumvisible() == 1 then
    return '<C-n>'
  end
  return '<Tab>'
end, { expr = true, replace_keycodes = true, desc = 'Next completion item' })

vim.keymap.set('i', '<S-Tab>', function()
  if vim.fn.pumvisible() == 1 then
    return '<C-p>'
  end
  return '<S-Tab>'
end, { expr = true, replace_keycodes = true, desc = 'Previous completion item' })

vim.keymap.set('c', '<CR>', function()
  if vim.fn.wildmenumode() == 1 then
    return '<C-y>'
  end
  return '<CR>'
end, {
  expr = true,
  replace_keycodes = true,
  desc = 'Accept command-line completion first',
})

-- LSP
vim.lsp.config('lua_ls', {
  settings = {
    Lua = {
      runtime = {
        version = 'LuaJIT',
        path = { 'lua/?.lua', 'lua/?/init.lua' },
      },
      workspace = {
        checkThirdParty = false,
        library = { vim.env.VIMRUNTIME },
      },
    },
  },
})

vim.lsp.enable({ 'nixd', 'lua_ls' })

vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(event)
    vim.lsp.completion.enable(true, event.data.client_id, event.buf, {
      autotrigger = true,
    })
  end,
})

-- Statusline
require('lualine').setup({
  sections = {
    lualine_x = { 'lsp_status', 'encoding', 'fileformat', 'filetype' },
  },
})

-- which-key
require('which-key').setup({
  preset = 'helix',
  delay = 100,
})

require('which-key').add({
  { '<leader>f', group = 'find' },
  { '<leader>g', group = 'git' },
})

-- Telescope
require('telescope').setup({
  defaults = {
    file_ignore_patterns = { '^%.git/' },
  },
  extensions = {
    fzf = {
      fuzzy = true,
      override_generic_sorter = true,
      override_file_sorter = true,
      case_mode = 'smart_case',
    },
  },
})

require('telescope').load_extension('fzf')

local builtin = require('telescope.builtin')

vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Find files' })
vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Live grep' })
vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Find buffers' })
vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Find help' })
vim.keymap.set('n', '<leader>fd', builtin.diagnostics, { desc = 'Find diagnostics' })
vim.keymap.set('n', '<leader>fr', builtin.resume, { desc = 'Resume search' })

-- Telescope: git
vim.keymap.set('n', '<leader>gs', builtin.git_status, { desc = 'Git status' })
vim.keymap.set('n', '<leader>gc', builtin.git_commits, { desc = 'Git commits' })
vim.keymap.set('n', '<leader>gB', builtin.git_bcommits, { desc = 'Git buffer commits' })
vim.keymap.set('n', '<leader>gS', builtin.git_stash, { desc = 'Git stash' })

-- Neogit
require('neogit').setup({
  integrations = { diffview = true },
  diff_viewer = 'diffview',
})

vim.keymap.set('n', '<leader>gg', '<cmd>Neogit<CR>', { desc = 'Neogit status' })
