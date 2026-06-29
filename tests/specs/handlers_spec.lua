local H = dofile("tests/helpers.lua")

return {
  {
    name = "handlers.default_open_handler invokes OS opener detached",
    run = function()
      local handlers = require("notmuch.handlers")
      local old_system = vim.system
      local captured_cmd, captured_opts

      vim.system = function(cmd, opts)
        captured_cmd = cmd
        captured_opts = opts
        return { wait = function() return { code = 0, stdout = "" } end }
      end

      handlers.default_open_handler({ path = "/tmp/file.txt" })

      local sysname = vim.uv.os_uname().sysname
      local expected = (sysname == "Darwin" and "open")
        or (sysname == "Linux" and "xdg-open")
        or (sysname:match("Windows") and "start")
        or "xdg-open"

      H.same({ expected, "/tmp/file.txt" }, captured_cmd)
      H.same({ detach = true }, captured_opts)

      vim.system = old_system
    end,
  },
  {
    name = "handlers.default_view_handler reads plain text attachments",
    run = function()
      local handlers = require("notmuch.handlers")
      local dir = H.tmpdir()
      local file = H.write_file(dir .. "/note.txt", "hello viewer\n")

      local output = handlers.default_view_handler({ path = file })
      H.contains(output, "hello viewer")
    end,
  },
}
