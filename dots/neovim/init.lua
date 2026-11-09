-- Leaders
vim.g.mapleader = ' ' -- space
vim.g.maplocalleader = ','

-- Colors
vim.cmd.colorscheme('oxocarbon')
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

-- Treesitter
vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'bash', 'nix', 'sh' },
  callback = function()
    vim.treesitter.start()
  end,
})

-- Text editing and search
vim.opt.textwidth = 80
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Window behavior and scrolling
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.scrolloff = 10
vim.opt.diffopt = vim.tbl_filter(function(option)
  return not option:match('^algorithm:') and not option:match('^linematch:')
end, vim.opt.diffopt:get())
vim.opt.diffopt:append({ 'algorithm:histogram', 'indent-heuristic', 'linematch:60' })

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
vim.lsp.config('nixd', {
  cmd = { 'nixd' },
  filetypes = { 'nix' },
  root_markers = { 'flake.nix', '.git' },
  settings = {
    nixd = {
      formatting = {
        command = { 'nixfmt' },
      },
    },
  },
})

vim.lsp.config('lua_ls', {
  cmd = { 'lua-language-server' },
  filetypes = { 'lua' },
  -- Nested lists are priority tiers: a project config beats a formatter config beats .git.
  root_markers = {
    { '.emmyrc.json', '.luarc.json', '.luarc.jsonc' },
    { '.luacheckrc', '.stylua.toml', 'stylua.toml', 'selene.toml', 'selene.yml' },
    { '.git' },
  },
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

vim.keymap.set('n', '<leader>cf', function()
  vim.lsp.buf.format()
end, { desc = 'Format buffer' })

vim.api.nvim_create_autocmd('BufWritePre', {
  pattern = '*.nix',
  callback = function(event)
    vim.lsp.buf.format({ bufnr = event.buf, async = false })
  end,
})

vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(event)
    vim.lsp.completion.enable(true, event.data.client_id, event.buf, {
      autotrigger = false,
    })
  end,
})

-- Statusline
require('lualine').setup({
  options = { theme = 'oxocarbon' },
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
  { '<leader>gd', group = 'diff review' },
})

-- Telescope
require('telescope').setup({
  defaults = {
    file_ignore_patterns = { '^%.git/' },
  },
  pickers = {
    find_files = { hidden = true },
    live_grep = { additional_args = { '--hidden' } },
  },
  extensions = {
    fzf = {
      fuzzy = true,
      override_generic_sorter = true,
      override_file_sorter = true,
      case_mode = 'smart_case',
    },
    ['ui-select'] = {
      require('telescope.themes').get_dropdown(),
    },
  },
})

require('telescope').load_extension('fzf')
require('telescope').load_extension('ui-select')

local builtin = require('telescope.builtin')

vim.keymap.set('n', '<leader><leader>', builtin.find_files, { desc = 'Find files' })
vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Find files' })
vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Live grep' })
vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Find buffers' })
vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Find help' })
vim.keymap.set('n', '<leader>fd', builtin.diagnostics, { desc = 'Find diagnostics' })
vim.keymap.set('n', '<leader>fr', builtin.resume, { desc = 'Resume search' })
vim.keymap.set('n', '<leader>fo', builtin.oldfiles, { desc = 'Recent files' })
vim.keymap.set('n', '<leader>fs', builtin.lsp_document_symbols, { desc = 'Symbols in file' })
vim.keymap.set('n', '<leader>/', builtin.current_buffer_fuzzy_find, { desc = 'Search in file' })

-- File tree
local fyler = require('fyler')

fyler.setup({
  kind = 'split_left_most',
  extensions = {
    git = { enabled = true },
    trash = { enabled = true },
    watcher = { enabled = true },
  },
  integrations = { icon = 'nvim_web_devicons' },
  ui = {
    hidden_items = {
      switches = {},
      always_hidden = { '/%.git$' },
    },
  },
})

vim.keymap.set('n', '<leader>e', function()
  fyler.toggle()
end, { desc = 'Toggle file tree' })

-- Telescope: git
vim.keymap.set('n', '<leader>gs', builtin.git_status, { desc = 'Git status' })
vim.keymap.set('n', '<leader>gc', builtin.git_commits, { desc = 'Git commits' })
vim.keymap.set('n', '<leader>gB', builtin.git_bcommits, { desc = 'Git buffer commits' })
vim.keymap.set('n', '<leader>gS', builtin.git_stash, { desc = 'Git stash' })

-- Gitsigns
local gitsigns = require('gitsigns')

gitsigns.setup()

vim.keymap.set('n', '<leader>gp', gitsigns.preview_hunk_inline, { desc = 'Preview hunk inline' })
vim.keymap.set('n', '<leader>gP', gitsigns.toggle_deleted, { desc = 'Toggle deleted lines' })
vim.keymap.set('n', '<leader>gn', function()
  if vim.wo.diff then
    vim.cmd.normal({ ']c', bang = true })
  else
    gitsigns.next_hunk()
  end
end, { desc = 'Next hunk' })
vim.keymap.set('n', '<leader>gN', function()
  if vim.wo.diff then
    vim.cmd.normal({ '[c', bang = true })
  else
    gitsigns.prev_hunk()
  end
end, { desc = 'Previous hunk' })

local diff_actions = require('diffview.actions')

local function goto_working_file()
  local tab = require('diffview.lib').get_prev_non_view_tabpage()
  if tab and vim.bo[vim.api.nvim_win_get_buf(vim.api.nvim_tabpage_get_win(tab))].buftype == 'terminal' then
    diff_actions.goto_file_tab()
  else
    diff_actions.goto_file_edit()
  end
end

require('diffview').setup({
  view = {
    default = { layout = 'diff2_horizontal' },
    file_history = { layout = 'diff2_horizontal' },
  },
  keymaps = {
    view = {
      { 'n', ']r', diff_actions.select_next_commit, { desc = 'Next commit' } },
      { 'n', '[r', diff_actions.select_prev_commit, { desc = 'Previous commit' } },
      { 'n', 'gf', goto_working_file, { desc = 'Open working file without replacing terminal' } },
    },
    file_panel = {
      { 'n', 'gf', goto_working_file, { desc = 'Open working file without replacing terminal' } },
    },
    file_history_panel = {
      { 'n', ']r', diff_actions.select_next_commit, { desc = 'Next commit' } },
      { 'n', '[r', diff_actions.select_prev_commit, { desc = 'Previous commit' } },
      { 'n', 'gf', goto_working_file, { desc = 'Open working file without replacing terminal' } },
    },
  },
})

local function file_path()
  local path = vim.api.nvim_buf_get_name(0)
  if vim.bo.buftype ~= '' or path == '' then
    vim.notify('This needs a file buffer', vim.log.levels.WARN)
    return
  end
  return path
end

vim.keymap.set('n', '<leader>gdd', '<cmd>DiffviewOpen<CR>', { desc = 'Review working tree' })
vim.keymap.set('n', '<leader>gds', '<cmd>DiffviewOpen --cached<CR>', { desc = 'Review staged changes' })
vim.keymap.set('n', '<leader>gdh', '<cmd>DiffviewFileHistory<CR>', { desc = 'Review repository history' })
vim.keymap.set('n', '<leader>gdf', function()
  local path = file_path()
  if path then
    require('diffview').file_history(nil, { path, '--follow' })
  end
end, { desc = 'Review file history' })
vim.keymap.set('x', '<leader>gdf', function()
  return file_path() and ':DiffviewFileHistory<CR>' or '<Esc>'
end, { expr = true, desc = 'Review selected lines history' })
vim.keymap.set('n', '<leader>gdr', ':DiffviewOpen ', { desc = 'Review revision or range' })
vim.keymap.set('n', '<leader>gdq', '<cmd>DiffviewClose<CR>', { desc = 'Close diff review' })

-- Neogit
require('neogit').setup({
  integrations = { diffview = true },
  diff_viewer = 'diffview',
})

vim.keymap.set('n', '<leader>gg', '<cmd>Neogit<CR>', { desc = 'Neogit status' })
