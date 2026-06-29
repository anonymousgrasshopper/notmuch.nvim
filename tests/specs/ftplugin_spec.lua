local H = dofile("tests/helpers.lua")

local function map_rhs(mode, lhs, buf)
  local maps = vim.api.nvim_buf_get_keymap(buf, mode)
  for _, m in ipairs(maps) do
    if m.lhs == lhs then return m.rhs or m.callback end
  end
end

return {
  {
    name = "notmuch-hello ftplugin creates buffer-local mappings only",
    run = function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_win_set_buf(0, buf)
      vim.bo.filetype = "notmuch-hello"
      vim.cmd("runtime ftplugin/notmuch-hello.lua")
      H.ok(map_rhs("n", "<CR>", buf), "missing buffer-local <CR>")
      H.ok(map_rhs("n", "c", buf), "missing buffer-local c")
      H.ok(map_rhs("n", "r", buf), "missing buffer-local r")
      H.ok(map_rhs("n", "%", buf), "missing buffer-local %")
      H.ok(map_rhs("n", "C", buf), "missing buffer-local C")
      H.ok(map_rhs("n", "q", buf), "missing buffer-local q")
      for _, m in ipairs(vim.api.nvim_get_keymap("n")) do
        H.ok(m.lhs ~= "<CR>", "ftplugin leaked a global <CR> mapping")
      end
    end,
  },
  {
    name = "notmuch-hello tag action mappings search, count, refresh, sync, compose, and close",
    run = function()
      local nm = require("notmuch")
      local refresh = require("notmuch.refresh")
      local sync = require("notmuch.sync")
      local send = require("notmuch.send")

      local original = {
        search_terms = nm.search_terms,
        count = nm.count,
        refresh_hello_buffer = refresh.refresh_hello_buffer,
        sync_maildir = sync.sync_maildir,
        compose = send.compose,
        notify = vim.notify,
      }
      local calls = {}

      local ok, err = pcall(function()
        nm.search_terms = function(query) calls.search = query end
        nm.count = function(query)
          calls.count = query
          return "counted " .. query
        end
        refresh.refresh_hello_buffer = function() calls.refresh = true end
        sync.sync_maildir = function() calls.sync = true end
        send.compose = function() calls.compose = true end
        vim.notify = function(message) calls.notify = message end

        local buf = vim.api.nvim_create_buf(true, true)
        vim.api.nvim_win_set_buf(0, buf)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Hints: test", "", "inbox" })
        vim.api.nvim_win_set_cursor(0, { 3, 0 })
        vim.bo.filetype = "notmuch-hello"
        vim.cmd("runtime ftplugin/notmuch-hello.lua")

        map_rhs("n", "<CR>", buf)()
        H.eq("tag:inbox", calls.search)

        map_rhs("n", "c", buf)()
        H.eq("tag:inbox", calls.count)
        H.eq("counted tag:inbox", calls.notify)

        map_rhs("n", "r", buf)()
        H.eq(true, calls.refresh)

        map_rhs("n", "%", buf)()
        H.eq(true, calls.sync)

        map_rhs("n", "C", buf)()
        H.eq(true, calls.compose)

        vim.api.nvim_feedkeys("q", "xt", false)
        H.wait_until(function()
          return not vim.api.nvim_buf_is_valid(buf)
        end, 1000)
      end)

      nm.search_terms = original.search_terms
      nm.count = original.count
      refresh.refresh_hello_buffer = original.refresh_hello_buffer
      sync.sync_maildir = original.sync_maildir
      send.compose = original.compose
      vim.notify = original.notify

      if not ok then error(err, 0) end
    end,
  },
  {
    name = "notmuch-threads ftplugin sets nowrap, commands, and mappings buffer-locally",
    run = function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_win_set_buf(0, buf)
      vim.bo.filetype = "notmuch-threads"
      vim.cmd("runtime ftplugin/notmuch-threads.lua")
      H.eq(false, vim.wo.wrap)
      H.ok(map_rhs("n", "<CR>", buf), "missing <CR>")
      H.ok(map_rhs("n", "r", buf), "missing r")
      H.ok(map_rhs("n", "o", buf), "missing o")
      H.ok(map_rhs("n", "%", buf), "missing %")
      H.ok(map_rhs("n", "q", buf), "missing q")
      H.ok(map_rhs("n", "C", buf), "missing C")
      H.ok(map_rhs("n", "+", buf), "missing +")
      H.ok(map_rhs("n", "-", buf), "missing -")
      H.ok(map_rhs("n", "=", buf), "missing =")
      H.ok(map_rhs("x", "+", buf), "missing visual +")
      H.ok(map_rhs("x", "-", buf), "missing visual -")
      H.ok(map_rhs("x", "=", buf), "missing visual =")
      H.ok(map_rhs("n", "A", buf), "missing A")
      H.ok(map_rhs("n", "dd", buf), "missing dd")
      H.ok(map_rhs("x", "d", buf), "missing visual d")
      H.ok(map_rhs("n", "D", buf), "missing D")
      local cmds = vim.api.nvim_buf_get_commands(buf, {})
      H.ok(cmds.TagAdd, "missing TagAdd")
      H.eq("+", cmds.TagAdd.nargs)
      H.ok(cmds.TagRm, "missing TagRm")
      H.ok(cmds.TagToggle, "missing TagToggle")
      H.ok(cmds.DelThread, "missing DelThread")
    end,
  },
  {
    name = "notmuch-threads action mappings open, refresh, sort, sync, compose, purge, and close",
    run = function()
      local nm = require("notmuch")
      local refresh = require("notmuch.refresh")
      local sync = require("notmuch.sync")
      local send = require("notmuch.send")
      local delete = require("notmuch.delete")

      local original = {
        show_thread = nm.show_thread,
        refresh_search_buffer = refresh.refresh_search_buffer,
        reverse_sort_threads = nm.reverse_sort_threads,
        sync_maildir = sync.sync_maildir,
        compose = send.compose,
        purge_del = delete.purge_del,
      }
      local calls = {}

      local ok, err = pcall(function()
        nm.show_thread = function() calls.open = true end
        refresh.refresh_search_buffer = function() calls.refresh = true end
        nm.reverse_sort_threads = function() calls.sort = true end
        sync.sync_maildir = function() calls.sync = true end
        send.compose = function() calls.compose = true end
        delete.purge_del = function() calls.purge = true end

        local buf = vim.api.nvim_create_buf(true, true)
        vim.api.nvim_win_set_buf(0, buf)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Hints: test", "thread:abc subject" })
        vim.api.nvim_win_set_cursor(0, { 2, 0 })
        vim.bo.filetype = "notmuch-threads"
        vim.cmd("runtime ftplugin/notmuch-threads.lua")

        map_rhs("n", "<CR>", buf)()
        H.eq(true, calls.open)

        map_rhs("n", "r", buf)()
        H.eq(true, calls.refresh)

        map_rhs("n", "o", buf)()
        H.eq(true, calls.sort)

        map_rhs("n", "%", buf)()
        H.eq(true, calls.sync)

        map_rhs("n", "C", buf)()
        H.eq(true, calls.compose)

        map_rhs("n", "D", buf)()
        H.eq(true, calls.purge)

        vim.api.nvim_feedkeys("q", "xt", false)
        H.wait_until(function()
          return not vim.api.nvim_buf_is_valid(buf)
        end, 1000)
      end)

      nm.show_thread = original.show_thread
      refresh.refresh_search_buffer = original.refresh_search_buffer
      nm.reverse_sort_threads = original.reverse_sort_threads
      sync.sync_maildir = original.sync_maildir
      send.compose = original.compose
      delete.purge_del = original.purge_del

      if not ok then error(err, 0) end
    end,
  },
  {
    name = "notmuch-threads tag commands and mappings operate on current and ranged threads",
    run = function()
      local tag = require("notmuch.tag")
      local original = {
        add = tag.thread_add_tag,
        rm = tag.thread_rm_tag,
        toggle = tag.thread_toggle_tag,
      }
      local calls = {}

      local ok, err = pcall(function()
        tag.thread_add_tag = function(tags, line1, line2)
          table.insert(calls, { op = "add", tags = tags, line1 = line1, line2 = line2 })
        end
        tag.thread_rm_tag = function(tags, line1, line2)
          table.insert(calls, { op = "rm", tags = tags, line1 = line1, line2 = line2 })
        end
        tag.thread_toggle_tag = function(tags, line1, line2)
          table.insert(calls, { op = "toggle", tags = tags, line1 = line1, line2 = line2 })
        end

        local buf = vim.api.nvim_create_buf(true, true)
        vim.api.nvim_win_set_buf(0, buf)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
          "Hints: test",
          "thread:one subject",
          "thread:two subject",
          "thread:three subject",
        })
        vim.api.nvim_win_set_cursor(0, { 2, 0 })
        vim.bo.filetype = "notmuch-threads"
        vim.cmd("runtime ftplugin/notmuch-threads.lua")

        vim.cmd("2TagAdd foo bar")
        H.same({ op = "add", tags = "foo bar", line1 = 2, line2 = 2 }, calls[#calls])

        vim.cmd("2,3TagRm foo")
        H.same({ op = "rm", tags = "foo", line1 = 2, line2 = 3 }, calls[#calls])

        vim.cmd("3,4TagToggle flagged")
        H.same({ op = "toggle", tags = "flagged", line1 = 3, line2 = 4 }, calls[#calls])

        vim.api.nvim_feedkeys("A", "xt", false)
        H.wait_until(function()
          local last = calls[#calls]
          return last and last.op == "rm" and last.tags == "inbox unread"
        end, 1000)
      end)

      tag.thread_add_tag = original.add
      tag.thread_rm_tag = original.rm
      tag.thread_toggle_tag = original.toggle

      if not ok then error(err, 0) end
    end,
  },
  {
    name = "mail ftplugin only configures thread buffers and sets fold options",
    run = function()
      local plain = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_win_set_buf(0, plain)
      vim.api.nvim_buf_set_name(plain, "plain-mail")
      vim.bo.filetype = "mail"
      vim.cmd("runtime ftplugin/mail.lua")
      H.eq(nil, vim.api.nvim_buf_get_commands(plain, {}).TagAdd)

      local thread = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_win_set_buf(0, thread)
      vim.api.nvim_buf_set_name(thread, "thread:abc123")
      vim.bo.filetype = "mail"
      vim.cmd("runtime ftplugin/mail.lua")
      H.eq("marker", vim.wo.foldmethod)
      H.eq(0, vim.wo.foldlevel)
      H.ok(map_rhs("n", "a", thread), "missing attachment mapping")
      H.ok(vim.api.nvim_buf_get_commands(thread, {}).FollowPatch, "missing FollowPatch")
    end,
  },
  {
    name = "notmuch-attach ftplugin creates attachment action mappings",
    run = function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_win_set_buf(0, buf)
      vim.bo.filetype = "notmuch-attach"
      vim.cmd("runtime ftplugin/notmuch-attach.lua")
      H.ok(map_rhs("n", "q", buf), "missing q")
      H.ok(map_rhs("n", "s", buf), "missing s")
      H.ok(map_rhs("n", "o", buf), "missing o")
      H.ok(map_rhs("n", "v", buf), "missing v")
    end,
  },
}
