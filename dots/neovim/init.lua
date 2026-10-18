-- Leaders
vim.g.mapleader = ' ' -- space
vim.g.maplocalleader = ','

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
