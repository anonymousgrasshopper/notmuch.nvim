local H = dofile("tests/helpers.lua")

return {
  {
    name = ":Notmuch opens the tag landing buffer",
    run = function()
      vim.cmd("Notmuch")

      H.eq("Tags", vim.api.nvim_buf_get_name(0):match("([^/]+)$"))
      H.eq("notmuch-hello", vim.bo.filetype)

      local lines = H.current_lines()
      H.contains(lines, "Hints:")
      H.contains(lines, "inbox")
      H.contains(lines, "unread")
    end,
  },
  {
    name = ":NmSearch populates a threads buffer asynchronously",
    run = function()
      vim.cmd("NmSearch tag:inbox")

      H.wait_until(function()
        local lines = H.current_lines()
        return #lines > 1 and table.concat(lines, "\n"):find("thread:", 1, true)
      end, 3000)

      H.eq("notmuch-threads", vim.bo.filetype)
      H.contains(H.current_lines(), "Hints:")
      H.contains(H.current_lines(), "thread:")
    end,
  },
  {
    name = "show_thread renders a thread and sets metadata buffer variables",
    run = function()
      local thread_id = H.first_thread_id("tag:inbox")
      require("notmuch").show_thread("thread:" .. thread_id)

      H.eq("mail", vim.bo.filetype)
      H.ok(vim.b.notmuch_thread, "missing vim.b.notmuch_thread")
      H.ok(vim.b.notmuch_messages, "missing vim.b.notmuch_messages")
      H.eq(thread_id, vim.b.notmuch_thread.id)
      H.ok(vim.b.notmuch_thread.message_count > 0, "expected message_count > 0")
      H.ok(#vim.b.notmuch_messages > 0, "expected message metadata")

      local lines = H.current_lines()
      H.contains(lines, "Hints:")
      H.contains(lines, "Subject:")
      H.contains(lines, "From:")
      H.contains(lines, "}}}")
    end,
  },
}
