vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Clipboard settings
vim.opt.clipboard = 'unnamedplus'  -- Use system clipboard
vim.keymap.set('n', 'y', '"+y')  -- Make y use system clipboard
vim.keymap.set('v', 'y', '"+y')  -- Make y use system clipboard in visual mode
vim.keymap.set('n', 'Y', '"+Y')  -- Make Y use system clipboard
vim.keymap.set('n', 'p', '"+p')  -- Make p use system clipboard
vim.keymap.set('v', 'p', '"+p')  -- Make p use system clipboard in visual mode
vim.keymap.set('n', 'P', '"+P')  -- Make P use system clipboard

vim.o.number = true
-- vim.o.relativenumber = true

vim.o.signcolumn = 'yes'

vim.o.tabstop = 4
vim.o.shiftwidth = 4

vim.o.updatetime = 300

vim.o.termguicolors = true

vim.o.mouse = 'a'
