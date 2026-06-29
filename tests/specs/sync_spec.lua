local H = dofile("tests/helpers.lua")

return {
  {
    name = "sync job helpers forward callbacks, stop jobs, and report running status",
    run = function()
      local sync = require("notmuch.sync")
      local old_jobstart, old_jobstop, old_jobwait = vim.fn.jobstart, vim.fn.jobstop, vim.fn.jobwait
      local started, stopped
      vim.fn.jobstart = function(cmd, opts)
        started = { cmd = cmd, opts = opts }
        return 42
      end
      vim.fn.jobstop = function(job_id) stopped = job_id end
      vim.fn.jobwait = function(jobs, timeout)
        H.same({ 42 }, jobs)
        H.eq(0, timeout)
        return { -1 }
      end

      local cb = function() end
      H.eq(42, sync.create_job("echo ok", { on_stdout = cb, stdout_buffered = true }))
      H.eq("echo ok", started.cmd)
      H.eq(cb, started.opts.on_stdout)
      H.eq(true, started.opts.stdout_buffered)
      H.eq(false, started.opts.stderr_buffered)
      H.eq(true, sync.stop_job(42))
      H.eq(42, stopped)
      H.eq(false, sync.stop_job(nil))
      H.eq(true, sync.is_job_running(42))
      H.eq(nil, sync.is_job_running(nil))
      sync.set_current_sync_job(77)
      H.eq(77, sync.get_current_sync_job())
      sync.set_current_sync_job(nil)

      vim.fn.jobstart, vim.fn.jobstop, vim.fn.jobwait = old_jobstart, old_jobstop, old_jobwait
    end,
  },
  {
    name = "sync buffer mode creates reusable nofile buffer and appends output/status",
    run = function()
      local sync = require("notmuch.sync")
      local config = require("notmuch.config")
      config.options.maildir_sync_cmd = "printf sync"
      config.options.sync = { sync_mode = "buffer" }
      sync.set_current_sync_job(nil)

      local old_create_job = sync.create_job
      local old_notify = vim.notify
      local notes = {}
      vim.notify = function(msg, level) table.insert(notes, { msg = msg, level = level }) end
      sync.create_job = function(cmd, opts)
        H.eq("printf sync ; notmuch new", cmd)
        opts.on_stdout(1, { "line one", "" })
        opts.on_stderr(1, { "warning" })
        opts.on_exit(1, 0)
        return 123
      end

      sync.sync_maildir()
      local buf = vim.api.nvim_get_current_buf()
      H.eq("notmuch-sync", vim.api.nvim_buf_get_name(buf):match("([^/]+)$"))
      H.eq("nofile", vim.bo[buf].buftype)
      H.eq("wipe", vim.bo[buf].bufhidden)
      H.eq(false, vim.bo[buf].swapfile)
      H.eq(false, vim.bo[buf].modifiable)
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      H.contains(lines, "== Syncing")
      H.contains(lines, "line one")
      H.contains(lines, "warning")
      H.contains(lines, "Maildir sync finished successfully!")
      H.ok(#notes >= 2, "expected start and success notifications")

      sync.create_job = old_create_job
      vim.notify = old_notify
      sync.set_current_sync_job(nil)
    end,
  },
  {
    name = "sync background mode avoids buffers and clears current job on exit",
    run = function()
      local sync = require("notmuch.sync")
      local config = require("notmuch.config")
      config.options.maildir_sync_cmd = "true"
      config.options.sync = { sync_mode = "background" }
      sync.set_current_sync_job(nil)
      local before = vim.api.nvim_get_current_buf()

      local old_create_job = sync.create_job
      local old_notify = vim.notify
      local notes = {}
      vim.notify = function(msg, level) table.insert(notes, { msg = msg, level = level }) end
      local exit_cb
      sync.create_job = function(_, opts) exit_cb = opts.on_exit; return 321 end

      sync.sync_maildir()
      H.eq(before, vim.api.nvim_get_current_buf())
      H.eq(321, sync.get_current_sync_job())
      exit_cb(321, 0)
      H.eq(nil, sync.get_current_sync_job())
      H.contains(notes[#notes].msg, "successfully")

      sync.create_job = old_create_job
      vim.notify = old_notify
    end,
  },
  {
    name = "starting sync while a job is running does not start another job",
    run = function()
      local sync = require("notmuch.sync")
      sync.set_current_sync_job(999)
      local old_is_running = sync.is_job_running
      local old_create_job = sync.create_job
      local old_notify = vim.notify
      local created = false
      local note
      sync.is_job_running = function() return true end
      sync.create_job = function() created = true end
      vim.notify = function(msg, level) note = { msg = msg, level = level } end

      sync.sync_maildir()
      H.eq(false, created)
      H.contains(note.msg, "already running")
      H.eq(vim.log.levels.WARN, note.level)

      sync.is_job_running = old_is_running
      sync.create_job = old_create_job
      vim.notify = old_notify
      sync.set_current_sync_job(nil)
    end,
  },
}
