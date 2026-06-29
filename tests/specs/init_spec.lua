local H = dofile("tests/helpers.lua")

local function buffer_basename()
  return vim.api.nvim_buf_get_name(0):match("([^/]+)$") or ""
end

return {
  {
    name = "notmuch_hello reuses existing Tags buffer and leaves it non-modifiable",
    run = function()
      local nm = require("notmuch")
      nm.notmuch_hello()
      local first = vim.api.nvim_get_current_buf()
      vim.cmd("enew")
      nm.notmuch_hello()
      H.eq(first, vim.api.nvim_get_current_buf())
      H.eq("Tags", buffer_basename())
      H.eq(false, vim.bo.modifiable)
      H.eq(3, vim.api.nvim_win_get_cursor(0)[1])
    end,
  },
  {
    name = "search_terms returns on empty query without creating a search buffer",
    run = function()
      vim.cmd("enew")
      local before = vim.api.nvim_get_current_buf()
      local result = require("notmuch").search_terms("")
      H.eq(nil, result)
      H.eq(before, vim.api.nvim_get_current_buf())
      H.eq("", buffer_basename())
    end,
  },
  {
    name = "search_terms opens thread:<id> queries directly in thread view",
    run = function()
      local id = H.first_thread_id("tag:inbox")
      local result = require("notmuch").search_terms("thread:" .. id)
      H.eq(true, result)
      H.eq("thread:" .. id, buffer_basename())
      H.eq("mail", vim.bo.filetype)
    end,
  },
  {
    name = "search_terms names, reuses, and keeps thread buffers non-modifiable",
    run = function()
      local query = "tag:inbox and tag:unread"
      require("notmuch").search_terms(query)
      H.wait_until(function()
        return table.concat(H.current_lines(), "\n"):find("thread:", 1, true)
      end, 3000)
      local first = vim.api.nvim_get_current_buf()
      H.eq(query, buffer_basename())
      H.eq(false, vim.bo.modifiable)
      H.eq(1, vim.api.nvim_win_get_cursor(0)[1])
      vim.cmd("enew")
      H.eq(true, require("notmuch").search_terms(query))
      H.eq(first, vim.api.nvim_get_current_buf())
    end,
  },
  {
    name = "reverse_sort_threads preserves hints and reverses result lines",
    run = function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_win_set_buf(0, buf)
      vim.bo.modifiable = true
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Hints: keep", "thread:1", "thread:2", "thread:3" })
      vim.bo.filetype = "notmuch-threads"
      require("notmuch").reverse_sort_threads()
      H.same({ "Hints: keep", "thread:3", "thread:2", "thread:1" }, H.current_lines())
      H.eq(false, vim.bo.modifiable)
    end,
  },
  {
    name = "show_thread refuses the hints line and reuses existing thread buffer",
    run = function()
      local nm = require("notmuch")
      local id = H.first_thread_id("tag:inbox")
      nm.show_thread("thread:" .. id)
      local first = vim.api.nvim_get_current_buf()
      nm.show_thread("thread:" .. id)
      H.eq(first, vim.api.nvim_get_current_buf())

      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_win_set_buf(0, buf)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Hints: nope" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      H.eq(nil, nm.show_thread())
    end,
  },
}
