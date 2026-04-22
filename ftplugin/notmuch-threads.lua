vim.opt_local.wrap = false

local nm = require("notmuch")
local r = require("notmuch.refresh")
local s = require("notmuch.sync")
local tag = require("notmuch.tag")

vim.api.nvim_buf_create_user_command(0, "DelThread", function(arg)
  local line1, line2 = arg.line1, arg.line2
  tag.thread_add_tag("del", line1, line2)
  tag.thread_rm_tag("inbox", line1, line2)
  vim.opt_local.modifiable = true
  vim.api.nvim_buf_set_lines(0, math.min(line1, line2) - 1, math.max(line1, line2), true, {})
  vim.opt_local.modifiable = false
end, {
  range = true,
  force = true,
})
vim.api.nvim_buf_create_user_command(0, "TagAdd", function(arg)
  tag.thread_add_tag(arg.args, arg.line1, arg.line2)
end, {
  complete = require("notmuch.completion").comp_tags,
  range = true,
  nargs = "+",
  force = true,
})
vim.api.nvim_buf_create_user_command(0, "TagRm", function(arg)
  tag.thread_rm_tag(arg.args, arg.line1, arg.line2)
end, {
  complete = require("notmuch.completion").comp_tags,
  range = true,
  nargs = "+",
  force = true,
})
vim.api.nvim_buf_create_user_command(0, "TagToggle", function(arg)
  require("notmuch.tag").thread_toggle_tag(arg.args, arg.line1, arg.line2)
end, {
  complete = require("notmuch.completion").comp_tags,
  range = true,
  nargs = "+",
  force = true,
})

vim.keymap.set("n", "<CR>", nm.show_thread, { buffer = true })
vim.keymap.set("n", "r", r.refresh_search_buffer, { buffer = true })
vim.keymap.set("n", "q", "<Cmd>bwipeout<CR>", { buffer = true })
vim.keymap.set("n", "%", s.sync_maildir, { buffer = true })
vim.keymap.set("n", "+", ":TagAdd<Space>", { buffer = true })
vim.keymap.set("x", "+", ":TagAdd<Space>", { buffer = true })
vim.keymap.set("n", "-", ":TagRm<Space>", { buffer = true })
vim.keymap.set("x", "-", ":TagRm<Space>", { buffer = true })
vim.keymap.set("n", "=", ":TagToggle<Space>", { buffer = true })
vim.keymap.set("x", "=", ":TagToggle<Space>", { buffer = true })
vim.keymap.set("n", "a", "<Cmd>TagToggle inbox<CR>j", { buffer = true })
vim.keymap.set("x", "a", ":TagToggle inbox<CR>", { buffer = true })
vim.keymap.set("n", "A", "<Cmd>TagRm inbox unread<CR>j", { buffer = true })
vim.keymap.set("x", "A", ":TagRm inbox unread<CR>", { buffer = true })
vim.keymap.set("n", "x", "<Cmd>TagToggle unread<CR>", { buffer = true })
vim.keymap.set("x", "x", ":TagToggle unread<CR>", { buffer = true })
vim.keymap.set("n", "f", "<Cmd>TagToggle flagged<CR>j", { buffer = true })
vim.keymap.set("x", "f", ":TagToggle flagged<CR>", { buffer = true })
vim.keymap.set("n", "C", require("notmuch.send").compose, { buffer = true })
vim.keymap.set("n", "dd", "<Cmd>DelThread<CR>", { buffer = true })
vim.keymap.set("x", "d", ":DelThread<CR>", { buffer = true })
vim.keymap.set("n", "D", require("notmuch.delete").purge_del, { buffer = true })
vim.keymap.set("n", "o", nm.reverse_sort_threads, { buffer = true })
