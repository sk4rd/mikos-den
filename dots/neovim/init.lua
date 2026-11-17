vim.loader.enable()

vim.g.mapleader = ' '

vim.cmd.colorscheme(require('palette').name)
require('nvim-highlight-colors').setup({
  enable_named_colors = false,
})

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true
vim.opt.signcolumn = 'yes'

vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.softtabstop = -1

vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'lua', 'nix' },
  callback = function(event)
    vim.bo.shiftwidth = 2
    if event.match == 'nix' then
      vim.bo.textwidth = 80
      vim.opt_local.formatoptions:remove('t')
    end
  end,
})

vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'bash', 'nix', 'sh' },
  callback = function()
    vim.treesitter.start()
  end,
})

vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.scrolloff = 10
vim.opt.diffopt:append('algorithm:histogram')

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

vim.opt.updatetime = 250
vim.opt.timeoutlen = 500

vim.opt.undofile = true
vim.cmd.packadd('nvim.undotree')
vim.keymap.set('n', '<leader>u', '<cmd>Undotree<CR>', { desc = 'Toggle undo tree' })
vim.opt.clipboard = 'unnamedplus'

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

require('lualine').setup({
  options = { theme = require('palette').name },
  sections = {
    lualine_x = { 'lsp_status', 'filetype' },
  },
})

require('which-key').setup({
  preset = 'helix',
  delay = 100,
})

require('which-key').add({
  { '<leader>f', group = 'find' },
  { '<leader>a', group = 'claude' },
  { '<leader>g', group = 'jj' },
})

require('telescope').setup({
  defaults = {
    file_ignore_patterns = { '^%.git/' },
  },
  pickers = {
    find_files = { hidden = true },
    live_grep = { additional_args = { '--hidden' } },
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

local gitsigns = require('gitsigns')
gitsigns.setup()

local function map(mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, { desc = desc })
end

local function on_selection(action)
  return function()
    local range = { vim.fn.line('.'), vim.fn.line('v') }
    vim.cmd('normal! ' .. vim.keycode('<Esc>'))
    gitsigns[action](range)
  end
end

local function jj(args, message)
  vim.system(
    vim.list_extend({ 'jj' }, args),
    { text = true },
    vim.schedule_wrap(function(result)
      if result.code ~= 0 then
        vim.notify(vim.trim(result.stderr), vim.log.levels.ERROR)
      elseif message then
        vim.notify(message)
      end
      vim.cmd.checktime()
    end)
  )
end

map('n', '<leader>gg', function()
  vim.cmd.tabnew()
  local buf = vim.api.nvim_get_current_buf()
  vim.fn.jobstart({ 'jjui' }, {
    term = true,
    on_exit = function()
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
      vim.cmd.checktime()
    end,
  })
  vim.cmd.startinsert()
end, 'jjui')
map('n', '<leader>gc', function()
  local current = vim.system({ 'jj', 'log', '--no-graph', '-r', '@', '-T', 'description' }, { text = true }):wait()
  vim.ui.input({ prompt = 'Describe: ', default = vim.trim(current.stdout or '') }, function(message)
    if message and message ~= '' then
      jj({ 'describe', '-m', message }, 'jj: described')
    end
  end)
end, 'Describe change')
map('n', '<leader>gn', function()
  jj({ 'new' }, 'jj: new change')
end, 'New change')
map('n', '<leader>gl', function()
  vim.cmd('botright 15new')
  vim.fn.jobstart({ 'jj', '--no-pager', 'log' }, { term = true })
end, 'Log')
require('diffview').setup({ preferred_adapter = 'jj' })
map('n', '<leader>gD', function()
  if require('diffview.lib').get_current_view() then
    vim.cmd('DiffviewClose')
  else
    vim.cmd('DiffviewOpen')
  end
end, 'Toggle changeset diff')
map('n', '<leader>gF', '<Cmd>DiffviewFileHistory %<CR>', 'File history')

map('n', '<leader>gr', gitsigns.reset_hunk, 'Discard hunk')
map('x', '<leader>gr', on_selection('reset_hunk'), 'Discard selected lines')
map('n', '<leader>gR', gitsigns.reset_buffer, 'Discard file changes')

map('n', '<leader>gp', gitsigns.preview_hunk_inline, 'Preview hunk inline')
map('n', '<leader>gd', gitsigns.diffthis, 'Diff file against the parent change')
map('n', '<leader>gb', gitsigns.blame_line, 'Blame line')
map('n', '<leader>gv', function()
  local enabled = gitsigns.toggle_deleted()
  gitsigns.toggle_linehl(enabled)
  gitsigns.toggle_word_diff(enabled)
end, 'Toggle inline diff view')
map('n', ']h', function()
  gitsigns.nav_hunk('next')
end, 'Next hunk')
map('n', '[h', function()
  gitsigns.nav_hunk('prev')
end, 'Previous hunk')

require('hunk').setup()

require('claudecode').setup({
  terminal = { provider = 'native', split_side = 'left' },
  track_selection = false,
})

local function is_claude_terminal(buf)
  local ok, term = pcall(require, 'claudecode.terminal')
  return ok and vim.bo[buf].buftype == 'terminal' and term.get_active_terminal_bufnr() == buf
end

local function claude_window_command()
  local key = vim.fn.getcharstr()
  if key == vim.keycode('<Esc>') then
    return
  end
  local win = vim.api.nvim_get_current_win()
  if #key == 1 then
    pcall(vim.cmd.wincmd, key)
  else
    -- A special key (an arrow): typed as in Normal mode.
    vim.api.nvim_feedkeys(vim.keycode('<C-\\><C-n><C-w>') .. key, 'n', false)
  end
  vim.schedule(function()
    local here = vim.api.nvim_get_current_win() == win
    if here and vim.fn.mode() ~= 't' then
      vim.cmd.startinsert()
    elseif not here and vim.fn.mode() == 't' then
      -- The other window is a terminal too: it is entered in Normal mode,
      -- as with a window command from anywhere else.
      vim.cmd.stopinsert()
    end
  end)
end

-- claudecode.nvim enters Terminal mode only when its own commands open or focus the window.
vim.api.nvim_create_autocmd({ 'TermOpen', 'BufEnter', 'WinEnter' }, {
  group = vim.api.nvim_create_augroup('claude_terminal_mode', { clear = true }),
  callback = function()
    -- After the event: the window being entered is the current one, and
    -- claudecode.nvim knows the terminal it has just opened.
    vim.schedule(function()
      local buf = vim.api.nvim_get_current_buf()
      if not is_claude_terminal(buf) then
        return
      end
      if not vim.b[buf].claude_window_prefix then
        -- Costs Claude Code its own <C-w> (delete word); <M-BS> does the same there.
        vim.keymap.set('t', '<C-w>', claude_window_command, { buffer = buf, desc = 'Window command' })
        vim.b[buf].claude_window_prefix = true
      end
      if vim.fn.mode() ~= 't' then
        vim.cmd.startinsert()
      end
    end)
  end,
})

local function claude_add_text(lines, name)
  local tmp = vim.fn.tempname() .. '-' .. name .. '.txt'
  vim.fn.writefile(lines, tmp)
  vim.cmd('ClaudeCodeAdd ' .. vim.fn.fnameescape(tmp))
end

local function is_file_buffer()
  return vim.bo.buftype == '' and vim.api.nvim_buf_get_name(0) ~= ''
end

map('n', '<leader>ac', '<cmd>ClaudeCode<CR>', 'Toggle Claude')
map('n', '<leader>aC', '<cmd>ClaudeCode --continue<CR>', 'Continue last conversation')
map('n', '<leader>af', '<cmd>ClaudeCodeFocus<CR>', 'Focus Claude')
map('n', '<leader>ab', function()
  if is_file_buffer() then
    vim.cmd('ClaudeCodeAdd %')
  else
    claude_add_text(vim.api.nvim_buf_get_lines(0, 0, -1, false), vim.bo.filetype)
  end
end, 'Add buffer to Claude')
map('x', '<leader>as', function()
  if is_file_buffer() then
    -- ClaudeCodeSend needs selection tracking (off above); ClaudeCodeAdd
    -- with a line range sends the same @file#L reference without it.
    local from, to = vim.fn.line('v'), vim.fn.line('.')
    vim.cmd('normal! ' .. vim.keycode('<Esc>'))
    vim.cmd(('ClaudeCodeAdd %s %d %d'):format(vim.fn.expand('%:p'), math.min(from, to), math.max(from, to)))
  else
    local lines = vim.fn.getregion(vim.fn.getpos('v'), vim.fn.getpos('.'), { type = vim.fn.mode() })
    vim.cmd('normal! ' .. vim.keycode('<Esc>'))
    claude_add_text(lines, vim.bo.filetype)
  end
end, 'Send selection to Claude')
map('n', '<leader>aa', '<cmd>ClaudeCodeDiffAccept<CR>', 'Accept Claude diff')
map('n', '<leader>ad', '<cmd>ClaudeCodeDiffDeny<CR>', 'Deny Claude diff')

-- Loaded from its checkout until it is published, so an edit to it needs only a restart.
local feedback = vim.fn.expand('~/Projects/feedback.nvim')
if vim.uv.fs_stat(feedback) then
  vim.opt.runtimepath:append(feedback)
  map({ 'n', 'x' }, '<leader>n', ':FeedbackAdd<CR>', 'Add feedback note')
  map('n', '<leader>N', '<cmd>FeedbackSend<CR>', 'Send feedback')
end
