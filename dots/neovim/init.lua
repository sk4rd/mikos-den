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
  { '<leader>a', group = 'claude' },
  { '<leader>g', group = 'git' },
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

-- Git: lowercase keys act on a hunk, capitals on the whole file or repo.
-- Repo-wide work (status, commit, push, rebase, stash...) lives in Neogit.
local gitsigns = require('gitsigns')
gitsigns.setup()

local function map(mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, { desc = desc })
end

-- Staging needs git to know the file. New files (also ones an "unstage all"
-- turned back into untracked) are first registered with `git add -N`,
-- which stages no content. See with_tracked in
-- lua/walkthrough/stage.lua of the walkthrough.nvim plugin.
local function staging(fn)
  return function()
    require('walkthrough').with_tracked(0, fn)
  end
end

-- Run a gitsigns hunk action on the selected lines, then leave visual mode.
local function on_selection(action)
  return function()
    local range = { vim.fn.line('.'), vim.fn.line('v') }
    vim.cmd('normal! ' .. vim.keycode('<Esc>'))
    local run = function()
      gitsigns[action](range)
    end
    if action == 'stage_hunk' then
      staging(run)()
    else
      run()
    end
  end
end

-- Neogit and diffview
map('n', '<leader>gg', '<cmd>Neogit<CR>', 'Neogit status')
map('n', '<leader>gc', '<cmd>Neogit commit<CR>', 'Commit')
map('n', '<leader>gl', '<cmd>Neogit log<CR>', 'Log')
map('n', '<leader>gB', '<cmd>Neogit branch<CR>', 'Branches')
map('n', '<leader>gD', function()
  if require('diffview.lib').get_current_view() then
    vim.cmd('DiffviewClose')
  else
    vim.cmd('DiffviewOpen')
  end
end, 'Toggle changeset diff')
map({ 'n', 'x' }, '<leader>gF', ':DiffviewFileHistory %<CR>', 'File or selection history')

-- Check what is staged before committing: lists staged vs unstaged files and
-- builds every host from exactly the index (commit-check.sh in the
-- walkthrough skill). Runs in a terminal split so the build progress shows;
-- <leader>ab there sends the result to Claude, q closes it.
map('n', '<leader>gk', function()
  local script = vim.fn.expand('~/.claude/skills/walkthrough/commit-check.sh')
  if vim.fn.executable(script) == 0 then
    vim.notify('commit check: ' .. script .. ' not found', vim.log.levels.WARN)
    return
  end
  local file = vim.api.nvim_buf_get_name(0)
  local dir = (file ~= '' and vim.bo.buftype == '') and vim.fs.dirname(file) or vim.fn.getcwd()
  vim.cmd('botright 15new')
  vim.fn.jobstart({ script }, { term = true, cwd = dir })
  vim.keymap.set('n', 'q', '<cmd>bdelete!<CR>', { buffer = true, desc = 'Close commit check' })
end, 'Check staged commit (build the index)')

-- Hunks (lowercase) and files (capital)
map('n', '<leader>gh', staging(function()
  gitsigns.stage_hunk()
end), 'Stage or unstage hunk')
map('x', '<leader>gh', on_selection('stage_hunk'), 'Stage selected lines')
map('n', '<leader>gH', gitsigns.stage_buffer, 'Stage file')
map('n', '<leader>gU', gitsigns.reset_buffer_index, 'Unstage file')
map('n', '<leader>gr', gitsigns.reset_hunk, 'Discard hunk')
map('x', '<leader>gr', on_selection('reset_hunk'), 'Discard selected lines')
map('n', '<leader>gR', gitsigns.reset_buffer, 'Discard file changes')

-- Looking at changes
map('n', '<leader>gp', gitsigns.preview_hunk_inline, 'Preview hunk inline')
map('n', '<leader>gd', gitsigns.diffthis, 'Diff file against index')
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

-- Neogit setup
require('neogit').setup({
  integrations = { telescope = true, diffview = true },
})

-- Claude Code
-- Runs `claude` in a terminal split and connects over the IDE protocol, so
-- selections go to it as @file#L1-10 references.
-- Which side Claude's terminal opens on. The walkthrough panel goes on the
-- same side of the code, so a tour always reads Claude | notes | code with
-- the explanation in the middle: 'left' gives [ Claude | notes | code ],
-- 'right' gives [ code | notes | Claude ].
local claude_side = 'left'

require('claudecode').setup({
  terminal = { provider = 'native', split_side = claude_side },
  -- Don't attach every visual selection to the next message ("⧉ 3 lines
  -- selected"): selecting is often for staging, not for asking. Lines go to
  -- Claude only on purpose, with <leader>as below.
  track_selection = false,
})
-- Code tours that an agent drives over the server socket. `keys = true` maps
-- ]w [w (steps), ]n [n (notes) and every other action under <leader>w;
-- <leader>w? lists them.
require('walkthrough').setup({ panel_side = claude_side, keys = true })

-- Claude's terminal is always in Terminal mode when its window is entered,
-- so what is typed goes to Claude. claudecode.nvim only does that when the
-- window is opened or focused with its own commands; entering it with a
-- window command (or coming back from another tab) lands in Normal mode,
-- where Claude seems not to react. <C-\><C-n> still leaves Terminal mode on
-- purpose, to scroll or copy Claude's output: that lasts until the window is
-- entered the next time. See :help terminal-input.
local function is_claude_terminal(buf)
  local ok, term = pcall(require, 'claudecode.terminal')
  return ok and vim.bo[buf].buftype == 'terminal' and term.get_active_terminal_bufnr() == buf
end

-- <C-w> is the window prefix inside Claude's terminal too, as everywhere
-- else: <C-w>l goes to the window on the right. Claude Code no longer gets
-- <C-w> (delete the word before the cursor); <M-BS> does the same there.
-- One key follows the prefix, <Esc> cancels. When the command leaves the
-- cursor in Claude's window (no window on that side), typing goes on.
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
        vim.keymap.set('t', '<C-w>', claude_window_command, { buffer = buf, desc = 'Window command' })
        vim.b[buf].claude_window_prefix = true
      end
      if vim.fn.mode() ~= 't' then
        vim.cmd.startinsert()
      end
    end)
  end,
})

-- Buffers without a file (Neogit, help, :messages...) cannot be referenced by
-- path, so their text is dumped to a temp file and added as context instead.
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
