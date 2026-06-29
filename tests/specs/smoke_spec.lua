local H = dofile("tests/helpers.lua")

return {
  {
    name = "fixture notmuch database is available",
    run = function()
      local count = tonumber((H.system({ "notmuch", "count", "*" }):gsub("%s+", "")))
      H.ok(count and count > 0, "expected fixture database to contain messages")
    end,
  },
  {
    name = "plugin user commands are registered",
    run = function()
      H.eq(2, vim.fn.exists(":Notmuch"), ":Notmuch command is missing")
      H.eq(2, vim.fn.exists(":NmSearch"), ":NmSearch command is missing")
      H.eq(2, vim.fn.exists(":Inbox"), ":Inbox command is missing")
      H.eq(2, vim.fn.exists(":ComposeMail"), ":ComposeMail command is missing")
    end,
  },
  {
    name = "notmuch.count returns a thread count string",
    run = function()
      local result = require("notmuch").count("tag:inbox")
      H.contains(result, "[tag:inbox]:")
      H.contains(result, "threads")
    end,
  },
}
