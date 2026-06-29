local H = dofile("tests/helpers.lua")

return {
  {
    name = "attach_cmd.Attach adds absolute validated attachments and rejects duplicates",
    run = function()
      local attach_cmd = require("notmuch.attach_cmd")
      local dir = H.tmpdir()
      local file = H.write_file(dir .. "/doc.txt", "hello")
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_var(buf, "notmuch_attachments", {})

      local old_notify = vim.notify
      local notifications = {}
      vim.notify = function(msg, level)
        table.insert(notifications, { msg = msg, level = level })
      end

      local handler = attach_cmd.attach_handler(buf)
      handler({ args = file })
      handler({ args = file })

      local attachments = vim.api.nvim_buf_get_var(buf, "notmuch_attachments")
      H.same({ vim.fn.fnamemodify(file, ":p") }, attachments)
      H.contains(notifications[1].msg, "Attached:")
      H.contains(notifications[2].msg, "Already attached:")
      H.eq(vim.log.levels.WARN, notifications[2].level)

      vim.notify = old_notify
      vim.api.nvim_buf_delete(buf, { force = true })
    end,
  },
  {
    name = "attach_cmd.Attach rejects missing files",
    run = function()
      local attach_cmd = require("notmuch.attach_cmd")
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_var(buf, "notmuch_attachments", {})

      local old_notify = vim.notify
      local notification
      vim.notify = function(msg, level)
        notification = { msg = msg, level = level }
      end

      attach_cmd.attach_handler(buf)({ args = "/definitely/missing/notmuch.nvim" })

      H.same({}, vim.api.nvim_buf_get_var(buf, "notmuch_attachments"))
      H.contains(notification.msg, "Cannot attach")
      H.eq(vim.log.levels.ERROR, notification.level)

      vim.notify = old_notify
      vim.api.nvim_buf_delete(buf, { force = true })
    end,
  },
  {
    name = "attach_cmd.AttachRemove removes expanded absolute paths",
    run = function()
      local attach_cmd = require("notmuch.attach_cmd")
      local cwd = vim.fn.getcwd()
      local dir = cwd .. "/tests/tmp/attach-cmd"
      vim.fn.mkdir(dir, "p")
      local file = H.write_file(dir .. "/remove-me.txt", "hello")
      vim.cmd("lcd " .. vim.fn.fnameescape(dir))

      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_var(buf, "notmuch_attachments", { vim.fn.fnamemodify(file, ":p") })

      local old_notify = vim.notify
      local notification
      vim.notify = function(msg, level)
        notification = { msg = msg, level = level }
      end

      attach_cmd.remove_handler(buf)({ args = "remove-me.txt" })

      H.same({}, vim.api.nvim_buf_get_var(buf, "notmuch_attachments"))
      H.contains(notification.msg, "Removed:")
      H.eq(vim.log.levels.INFO, notification.level)

      vim.notify = old_notify
      vim.cmd("lcd " .. vim.fn.fnameescape(cwd))
      vim.api.nvim_buf_delete(buf, { force = true })
    end,
  },
  {
    name = "attach_cmd.AttachRemove completion returns current attachments",
    run = function()
      local attach_cmd = require("notmuch.attach_cmd")
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_var(buf, "notmuch_attachments", { "/a", "/b" })
      H.same({ "/a", "/b" }, attach_cmd.remove_completion(buf)())
      vim.api.nvim_buf_delete(buf, { force = true })
    end,
  },
}
