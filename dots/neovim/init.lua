vim.loader.enable()

-- Leaders
vim.g.mapleader = ' ' -- space

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

vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'lua', 'nix' },
  callback = function(event)
    vim.bo.shiftwidth = 2
    if event.match == 'nix' then
      -- Wrap comments at 80 columns, but never code.
      vim.bo.textwidth = 80
      vim.opt_local.formatoptions:remove('t')
    end
  end,
})

-- Treesitter
vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'bash', 'nix', 'sh' },
  callback = function()
    vim.treesitter.start()
  end,
})

-- Text editing and search
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Window behavior and scrolling
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.scrolloff = 10
vim.opt.diffopt:append('algorithm:histogram')

-- In a diff, drop the temporary side and keep the real file.
vim.keymap.set('n', '<leader>q', function()
  if not vim.wo.diff then
    vim.cmd('silent! close')
    return
  end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.wo[win].diff and vim.bo[vim.api.nvim_win_get_buf(win)].buftype ~= '' then
      vim.api.nvim_win_close(win, false)
    end
  end
  vim.cmd('diffoff!')
end, { desc = 'Close pane' })

-- Responsiveness
vim.opt.updatetime = 250
vim.opt.timeoutlen = 500

-- Persistence and system integration
vim.opt.undofile = true
vim.cmd.packadd('nvim.undotree')
vim.keymap.set('n', '<leader>u', '<cmd>Undotree<CR>', { desc = 'Toggle undo tree' })
vim.opt.clipboard = 'unnamedplus'

-- Completion
vim.opt.completeopt = { 'menu', 'menuone', 'noselect', 'fuzzy', 'popup' }
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
  -- Nested lists are priority tiers: a project config beats a linter config beats .git.
  root_markers = {
    { '.luarc.json', '.luarc.jsonc' },
    { '.luacheckrc' },
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

vim.diagnostic.config({ virtual_lines = { current_line = true } })

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
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, { buffer = event.buf, desc = 'Go to definition' })
  end,
})

-- Statusline
require('lualine').setup({
  options = { theme = 'oxocarbon' },
  sections = {
    lualine_x = { 'lsp_status', 'filetype' },
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
local telescope_actions = require('telescope.actions')

-- Run git in a terminal split so editors and SSH prompts work.
local function git_term(...)
  local root = vim.fs.root(0, '.git')
  vim.cmd('botright new')
  vim.fn.jobstart({ 'git', ... }, { term = true, cwd = root })
  vim.cmd.startinsert()
end

-- The default <CR> detaches HEAD on the selected commit, so show it instead.
local function log_show_on_enter()
  telescope_actions.select_default:replace(function(prompt_bufnr)
    local commit = require('telescope.actions.state').get_selected_entry().value
    telescope_actions.close(prompt_bufnr)
    git_term('show', commit)
  end)
  return true
end

-- The default <CR> runs `git checkout <commit> -- <file>` and discards local
-- edits, so open the read-only comparison that <C-v> gives instead.
local function bcommits_diff_on_enter()
  telescope_actions.select_default:replace(function(prompt_bufnr)
    return telescope_actions.select_vertical(prompt_bufnr)
  end)
  return true
end

require('telescope').setup({
  defaults = {
    file_ignore_patterns = { '^%.git/' },
  },
  pickers = {
    find_files = { hidden = true },
    live_grep = { additional_args = { '--hidden' } },
    git_commits = { attach_mappings = log_show_on_enter },
    git_bcommits = { attach_mappings = bcommits_diff_on_enter },
    git_bcommits_range = { attach_mappings = bcommits_diff_on_enter },
  },
  extensions = {
    ['ui-select'] = {
      require('telescope.themes').get_dropdown(),
    },
  },
})

require('telescope').load_extension('fzf')
require('telescope').load_extension('ui-select')

local builtin = require('telescope.builtin')

vim.keymap.set('n', '<leader><leader>', builtin.find_files, { desc = 'Find files' })
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
vim.keymap.set('n', '<leader>gs', builtin.git_status, { desc = 'Changed files' })
vim.keymap.set('n', '<leader>gl', builtin.git_commits, { desc = 'Git log' })
vim.keymap.set('n', '<leader>gw', builtin.git_branches, { desc = 'Git branches' })
vim.keymap.set('n', '<leader>gS', builtin.git_stash, { desc = 'Git stashes' })
vim.keymap.set('n', '<leader>gB', builtin.git_bcommits, { desc = 'Git buffer commits' })
vim.keymap.set('x', '<leader>gB', builtin.git_bcommits_range, { desc = 'Git selected lines commits' })

-- Gitsigns
local gitsigns = require('gitsigns')

gitsigns.setup()

vim.keymap.set('n', '<leader>gb', gitsigns.blame_line, { desc = 'Blame line' })
vim.keymap.set('n', '<leader>gp', gitsigns.preview_hunk_inline, { desc = 'Preview hunk inline' })
vim.keymap.set('n', '<leader>gv', function()
  local enabled = gitsigns.toggle_deleted()
  gitsigns.toggle_linehl(enabled)
  gitsigns.toggle_word_diff(enabled)
end, { desc = 'Toggle inline diff view' })
vim.keymap.set('n', '<leader>gh', gitsigns.stage_hunk, { desc = 'Stage or unstage hunk' })
vim.keymap.set('n', '<leader>gH', gitsigns.stage_buffer, { desc = 'Stage file' })
vim.keymap.set('n', '<leader>gU', gitsigns.reset_buffer_index, { desc = 'Unstage file' })
vim.keymap.set('n', '<leader>gd', gitsigns.diffthis, { desc = 'Diff file against index' })
vim.keymap.set('n', '<leader>gr', gitsigns.reset_hunk, { desc = 'Discard hunk' })
vim.keymap.set('x', '<leader>gr', function()
  gitsigns.reset_hunk({ vim.fn.line('.'), vim.fn.line('v') })
  vim.cmd('normal! ' .. vim.keycode('<Esc>'))
end, { desc = 'Discard selected lines' })
vim.keymap.set('n', '<leader>gR', gitsigns.reset_buffer, { desc = 'Discard file changes' })
vim.keymap.set('x', '<leader>gh', function()
  gitsigns.stage_hunk({ vim.fn.line('.'), vim.fn.line('v') })
  vim.cmd('normal! ' .. vim.keycode('<Esc>'))
end, { desc = 'Stage selected lines' })
vim.keymap.set('n', ']h', function()
  gitsigns.nav_hunk('next')
end, { desc = 'Next hunk' })
vim.keymap.set('n', '[h', function()
  gitsigns.nav_hunk('prev')
end, { desc = 'Previous hunk' })

-- Git commands
for _, map in ipairs({
  { '<leader>gc', 'Commit staged', 'commit' },
  { '<leader>gC', 'Amend last commit', 'commit', '--amend' },
  { '<leader>gP', 'Push', 'push' },
  { '<leader>gL', 'Pull', 'pull' },
  { '<leader>gf', 'Fetch', 'fetch' },
  { '<leader>gz', 'Stash changes', 'stash' },
}) do
  vim.keymap.set('n', map[1], function()
    git_term(unpack(map, 3))
  end, { desc = map[2] })
end
