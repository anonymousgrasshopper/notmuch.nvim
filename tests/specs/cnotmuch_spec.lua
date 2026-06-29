local H = dofile("tests/helpers.lua")

return {
  {
    name = "cnotmuch opens database and lists expected tags",
    run = function()
      local config = require("notmuch.config")
      local db = require("notmuch.cnotmuch")(config.options.notmuch_db_path, 0)
      local tags = db.get_all_tags()
      db.close()

      H.list_contains(tags, "inbox")
      H.list_contains(tags, "unread")
    end,
  },
  {
    name = "cnotmuch can count inbox threads",
    run = function()
      local config = require("notmuch.config")
      local db = require("notmuch.cnotmuch")(config.options.notmuch_db_path, 0)
      local query = db.create_query("tag:inbox")
      local count = query.count_threads()
      db.close()

      H.ok(count > 0, "expected at least one inbox thread")
    end,
  },
  {
    name = "cnotmuch can add and remove a test tag on a thread",
    run = function()
      local config = require("notmuch.config")
      local db = require("notmuch.cnotmuch")(config.options.notmuch_db_path, 1)
      local query = db.create_query("tag:inbox")
      local thread = query.get_threads()[1]
      H.ok(thread, "expected at least one thread")

      thread:add_tag("nvim-test")
      db.close()

      local added = tonumber((H.system({ "notmuch", "count", "tag:nvim-test" }):gsub("%s+", "")))
      H.ok(added and added > 0, "expected tag:nvim-test to match messages after adding tag")

      db = require("notmuch.cnotmuch")(config.options.notmuch_db_path, 1)
      query = db.create_query("tag:nvim-test")
      thread = query.get_threads()[1]
      H.ok(thread, "expected tagged thread before removing test tag")
      thread:rm_tag("nvim-test")
      db.close()

      local removed = tonumber((H.system({ "notmuch", "count", "tag:nvim-test" }):gsub("%s+", "")))
      H.eq(0, removed, "expected test tag to be removed")
    end,
  },
}
