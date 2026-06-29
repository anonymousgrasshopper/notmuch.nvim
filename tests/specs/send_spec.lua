local H = dofile("tests/helpers.lua")

local function map_callback(mode, lhs, buf)
  local target = lhs:lower()
  for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, mode)) do
    if m.lhs:lower() == target then return m.callback end
  end
end

local function with_send_env(fn)
  local send = require("notmuch.send")
  local config = require("notmuch.config")
  local thread = require("notmuch.thread")
  local old_from = config.options.from
  local old_keymaps = config.options.keymaps
  local old_tempname = vim.fn.tempname
  local old_call_function = vim.api.nvim_call_function
  local old_sendmail = send.sendmail
  local old_path = vim.env.PATH
  local old_get_current_message_id = thread.get_current_message_id
  local dir = H.tmpdir()
  local state = { dir = dir, sent = {} }

  config.options.from = "Sender Name <sender@example.com>"
  config.options.keymaps = {
    sendmail = "<C-g><C-g>",
    attachment_window = "<C-g><C-a>",
  }
  vim.fn.tempname = function() return dir .. "/draft" end

  local ok, err = pcall(fn, state, send, config, thread)

  config.options.from = old_from
  config.options.keymaps = old_keymaps
  vim.fn.tempname = old_tempname
  vim.api.nvim_call_function = old_call_function
  send.sendmail = old_sendmail
  vim.env.PATH = old_path
  thread.get_current_message_id = old_get_current_message_id
  pcall(vim.cmd, "silent! %bwipeout!")

  if not ok then error(err, 0) end
end

return {
  {
    name = "send.compose creates compose draft with headers, recipient, sender, and attachment window",
    run = function()
      with_send_env(function(_, send, config)
        send.compose("to+tag@example.com")
        local main_buf = vim.api.nvim_get_current_buf()
        H.matches(vim.api.nvim_buf_get_name(main_buf), "%-compose%.eml$", "expected compose draft filename")
        H.same({
          "From: Sender Name <sender@example.com>",
          "To: to+tag@example.com",
          "Cc: ",
          "Subject: ",
          "",
          'Message body goes here. Add attachments with "' .. config.options.keymaps.attachment_window .. '". Send with "' .. config.options.keymaps.sendmail .. '".',
        }, vim.api.nvim_buf_get_lines(main_buf, 0, -1, false))

        local before_wins = #vim.api.nvim_list_wins()
        local attach_cb = map_callback("n", config.options.keymaps.attachment_window, main_buf)
        H.ok(attach_cb, "missing compose attachment-window keymap")
        attach_cb()
        H.ok(#vim.api.nvim_list_wins() > before_wins, "expected attachment split to open")
        H.ok(vim.api.nvim_get_current_buf() ~= main_buf, "expected attachment buffer to become current")
        vim.cmd("close")
      end)
    end,
  },
  {
    name = "send.compose send keymap prompts and No confirmation does not send",
    run = function()
      with_send_env(function(state, send, config)
        local prompted = false
        send.sendmail = function(path)
          table.insert(state.sent, path)
          return true
        end
        vim.api.nvim_call_function = function(name, args)
          H.eq("confirm", name)
          H.eq("Send email?", args[1])
          prompted = true
          return 2
        end

        send.compose()
        local main_buf = vim.api.nvim_get_current_buf()
        local send_cb = map_callback("n", config.options.keymaps.sendmail, main_buf)
        H.ok(send_cb, "missing compose send keymap")
        send_cb()

        H.eq(true, prompted)
        H.eq(0, #state.sent)
        H.contains(vim.api.nvim_buf_get_lines(main_buf, 0, -1, false), "Message body goes here")
      end)
    end,
  },
  {
    name = "send.compose Confirm Yes without attachments builds plain message and sends",
    run = function()
      with_send_env(function(state, send, config)
        send.sendmail = function(path)
          table.insert(state.sent, path)
          return true
        end
        vim.api.nvim_call_function = function() return 1 end

        send.compose("plain@example.com")
        local main_buf = vim.api.nvim_get_current_buf()
        vim.api.nvim_buf_set_lines(main_buf, 5, -1, false, { "Hello plain body" })
        map_callback("n", config.options.keymaps.sendmail, main_buf)()

        H.eq(1, #state.sent)
        H.matches(state.sent[1], "%-compose%.eml$")
        local lines = vim.api.nvim_buf_get_lines(main_buf, 0, -1, false)
        H.contains(lines, "From: Sender Name <sender@example.com>")
        H.contains(lines, "To: plain@example.com")
        H.contains(lines, "MIME-Version: 1.0")
        H.contains(lines, "Content-Type: text/plain; charset=utf-8")
        H.contains(lines, "Content-Transfer-Encoding: 8bit")
        H.contains(lines, "Hello plain body")
        H.ok(not table.concat(lines, "\n"):find("multipart/mixed", 1, true), "plain message should not be multipart")
      end)
    end,
  },
  {
    name = "send.compose Confirm Yes with attachments builds MIME message and sends",
    run = function()
      with_send_env(function(state, send, config)
        local attachment = H.write_file(state.dir .. "/attachment.txt", "attached text\n")
        send.sendmail = function(path)
          table.insert(state.sent, path)
          return true
        end
        vim.api.nvim_call_function = function() return 1 end

        send.compose("mime@example.com")
        local main_buf = vim.api.nvim_get_current_buf()
        vim.api.nvim_buf_set_lines(main_buf, 5, -1, false, { "Hello MIME body" })

        map_callback("n", config.options.keymaps.attachment_window, main_buf)()
        local attach_buf = vim.api.nvim_get_current_buf()
        vim.api.nvim_buf_set_lines(attach_buf, 0, -1, false, { attachment })
        vim.api.nvim_set_current_buf(main_buf)

        map_callback("n", config.options.keymaps.sendmail, main_buf)()

        H.eq(1, #state.sent)
        H.matches(state.sent[1], "%-compose%.eml$")
        local text = table.concat(vim.api.nvim_buf_get_lines(main_buf, 0, -1, false), "\n")
        H.contains(text, "From: Sender Name <sender@example.com>")
        H.contains(text, "To: mime@example.com")
        H.contains(text, "Content-Type: multipart/mixed")
        H.contains(text, "Content-Disposition: attachment; filename=\"attachment.txt\"")
        H.contains(text, "Hello MIME body")
      end)
    end,
  },
  {
    name = "send.reply gets message id, creates sanitized draft, initializes commands, and reads new drafts",
    run = function()
      with_send_env(function(state, send, config, thread)
        local bin = state.dir .. "/bin"
        vim.fn.mkdir(bin, "p")
        local fake_notmuch = bin .. "/notmuch"
        H.write_file(fake_notmuch, "#!/bin/sh\nprintf '%s\n' 'From: Sender Name <sender@example.com>' 'To: Reply Target <target@example.com>' 'Subject: Re: Fixture' '' 'quoted reply body'\n")
        vim.fn.setfperm(fake_notmuch, "rwxr-xr-x")
        vim.env.PATH = bin .. ":" .. vim.env.PATH

        local requested_id
        thread.get_current_message_id = function()
          requested_id = "msg/with/slash"
          return requested_id
        end
        pcall(vim.fn.delete, "/tmp/reply-msg-with-slash.eml")

        send.reply()
        local buf = vim.api.nvim_get_current_buf()
        H.eq("msg/with/slash", requested_id)
        H.eq("reply-msg-with-slash.eml", vim.api.nvim_buf_get_name(buf):match("([^/]+)$"))
        H.eq("wipe", vim.bo[buf].bufhidden)
        H.same({}, vim.b[buf].notmuch_attachments)
        H.contains(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "quoted reply body")

        local cmds = vim.api.nvim_buf_get_commands(buf, {})
        H.ok(cmds.Attach, "missing Attach command")
        H.ok(cmds.AttachRemove, "missing AttachRemove command")
        H.ok(cmds.AttachList, "missing AttachList command")
        H.ok(map_callback("n", config.options.keymaps.sendmail, buf), "missing reply send keymap")
      end)
    end,
  },
  {
    name = "send.reply reuses existing drafts without duplicating notmuch reply output",
    run = function()
      with_send_env(function(state, send, _, thread)
        local bin = state.dir .. "/bin"
        vim.fn.mkdir(bin, "p")
        local fake_notmuch = bin .. "/notmuch"
        H.write_file(fake_notmuch, "#!/bin/sh\nprintf '%s\n' 'SHOULD_NOT_APPEAR'\n")
        vim.fn.setfperm(fake_notmuch, "rwxr-xr-x")
        vim.env.PATH = bin .. ":" .. vim.env.PATH

        local reply_file = "/tmp/reply-existing-id.eml"
        H.write_file(reply_file, "Existing draft\n")
        thread.get_current_message_id = function() return "existing/id" end

        send.reply()
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        H.same({ "Existing draft" }, lines)
        pcall(vim.fn.delete, reply_file)
      end)
    end,
  },
  {
    name = "send.reply send keymap builds plain or MIME messages and calls sendmail",
    run = function()
      with_send_env(function(state, send, config, thread)
        send.sendmail = function(path)
          table.insert(state.sent, path)
          return true
        end
        vim.api.nvim_call_function = function() return 1 end

        thread.get_current_message_id = function() return "plain-reply" end
        pcall(vim.fn.delete, "/tmp/reply-plain-reply.eml")
        send.reply()
        local plain_buf = vim.api.nvim_get_current_buf()
        vim.api.nvim_buf_set_lines(plain_buf, 0, -1, false, {
          "From: Sender Name <sender@example.com>",
          "To: Recipient <recipient@example.com>",
          "Subject: Re: Plain",
          "",
          "Plain reply body",
        })
        map_callback("n", config.options.keymaps.sendmail, plain_buf)()
        H.eq("/tmp/reply-plain-reply.eml", state.sent[#state.sent])
        H.contains(vim.api.nvim_buf_get_lines(plain_buf, 0, -1, false), "MIME-Version: 1.0")

        thread.get_current_message_id = function() return "mime-reply" end
        pcall(vim.fn.delete, "/tmp/reply-mime-reply.eml")
        send.reply()
        local mime_buf = vim.api.nvim_get_current_buf()
        local attachment = H.write_file(state.dir .. "/reply-attachment.txt", "reply attachment\n")
        vim.api.nvim_buf_set_lines(mime_buf, 0, -1, false, {
          "From: Sender Name <sender@example.com>",
          "To: Recipient <recipient@example.com>",
          "Subject: Re: MIME",
          "",
          "MIME reply body",
        })
        vim.b[mime_buf].notmuch_attachments = { attachment }
        map_callback("n", config.options.keymaps.sendmail, mime_buf)()
        H.eq("/tmp/reply-mime-reply.eml", state.sent[#state.sent])
        local text = table.concat(vim.api.nvim_buf_get_lines(mime_buf, 0, -1, false), "\n")
        H.contains(text, "Content-Type: multipart/mixed")
        H.contains(text, "Content-Disposition: attachment; filename=\"reply-attachment.txt\"")
      end)
    end,
  },
}
