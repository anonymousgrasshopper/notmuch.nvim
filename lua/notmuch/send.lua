local s = {}
local u = require('notmuch.util')
local m = require('notmuch.mime')
local thread = require('notmuch.thread')
local v = vim.api

local config = require('notmuch.config')

-- Prompt confirmation for sending an email
--
-- This function utilizes vim's builtin `confirm()` to prompt the user and
-- confirm the action of sending an email. This is applicable for sending newly
-- composed mails or replies by passing the mail file path.
--
-- @param filename string: path to the email message you would like to send
--
-- @usage
--   -- See reply() or compose()
--   vim.keymap.set('n', '<C-c><C-c>', function()
--     confirm_sendmail(reply_filename)
--   end, { buffer = true })
local confirm_sendmail = function()
  local choice = v.nvim_call_function('confirm', {
    'Send email?',
    '&Yes\n&No',
    2 -- Default to no
  })

  if choice == 1 then
    return true
  else
    return false
  end
end

--- Builds plain text msg from contents into single-part MIME message of main
--- msg buffer and outputs it in place.
---
--- If the composed email has no attachments, it makes more sense (cheaper and
--- more idiomatic) to send as a single part (not MIME `multipart/mixed`) of
--- type `text/plain; charset=UTF-8`.
---
--- @param buf integer: buffer ID of the message compose file
local build_plain_msg = function(buf)
  local main_lines = v.nvim_buf_get_lines(buf, 0, -1, false)

  -- Extract attributes and remove from main message buffer `buf`
  local attributes, msg = m.get_msg_attributes(main_lines)
  v.nvim_buf_set_lines(buf, 0, -1, false, msg)
  vim.cmd('silent! write!')

  -- Build MIME single-part email:
  -- - Header
  -- - MIME headers
  -- - Blank line
  -- - Body
  local plain_msg = {}

  -- Add email headers (To, From, Subject, etc.)
  for key, value in pairs(attributes) do
    table.insert(plain_msg, key .. ": " .. value)
  end

  -- Add MIME headers (required for UTF-8 support per RFC2045)
  table.insert(plain_msg, "MIME-Version: 1.0")
  table.insert(plain_msg, "Content-Type: text/plain; charset=utf-8")
  table.insert(plain_msg, "Content-Transfer-Encoding: 8bit")

  -- Add blank line separator (required by RFC5322)
  table.insert(plain_msg, "")

  -- Add message body
  for _, line in ipairs(msg) do
    table.insert(plain_msg, line)
  end

  -- Write complete email to file
  v.nvim_buf_set_lines(buf, 0, -1, false, plain_msg)
  vim.cmd('silent! write!')
end

-- Builds mime msg from contents of main msg buffer and attachment buffer
local build_mime_msg = function(buf, buf_attach, compose_filename)
  local attach_lines = vim.api.nvim_buf_get_lines(buf_attach, 0, -1, false)
  local main_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  -- Extract headers and body (read-only operation)
  local attributes, msg = m.get_msg_attributes(main_lines)

  -- VALIDATE attachments BEFORE modifying buffer/file
  -- If validation fails, error is thrown here and buffer remains intact
  local attachments = m.create_mime_attachments(attach_lines)

  -- Now safe to modify buffer - attachments are validated
  v.nvim_buf_set_lines(buf, 0, -1, false, msg)
  vim.cmd('silent! write!')
  local mimes = { {
    file = compose_filename,
    type = "text/plain; charset=utf-8",
  } }

  for _, v in ipairs(attachments) do
    table.insert(mimes, v)
  end



  local mime_table = {
    version = "Mime-Version: 1.0",
    type = "multipart/mixed", -- or multipart/alternative
    encoding = "8 bit",
    attributes = attributes,
    mime = mimes,
  }


  local mime_msg = m.make_mime_msg(mime_table)
  v.nvim_buf_set_lines(buf, 0, -1, false, mime_msg)


  vim.cmd('silent! write!')
end

local build_mime_msg_from_attachments = function(buf, attachment_paths, message_filename)
  local main_lines = v.nvim_buf_get_lines(buf, 0, -1, false)

  -- Extract headers and body (read-only operation)
  local attributes, msg = m.get_msg_attributes(main_lines)

  -- VALIDATE attachments BEFORE modifying buffer/file
  local attachments = m.create_mime_attachments(attachment_paths)

  -- Safe to modify buffer now
  v.nvim_buf_set_lines(buf, 0, -1, false, msg)
  vim.cmd('silent! write!')

  -- Build MIME parts: main body + attachments
  local mimes = { {
    file = message_filename,
    type = "text/plain; charset=utf-8",
  } }

  for _, attachment in ipairs(attachments) do
    table.insert(mimes, attachment)
  end

  local mime_table = {
    version = "Mime-Version: 1.0",
    type = "multipart/mixed",
    encoding = "8 bit",
    attributes = attributes,
    mime = mimes,
  }

  local mime_msg = m.make_mime_msg(mime_table)
  v.nvim_buf_set_lines(buf, 0, -1, false, mime_msg)

  vim.cmd('silent! write!')
end

local build_plain_msg_file = function(buf, output_filename)
  local main_lines = v.nvim_buf_get_lines(buf, 0, -1, false)
  local attributes, msg = m.get_msg_attributes(main_lines)
  local plain_msg = {}

  for key, value in pairs(attributes) do
    table.insert(plain_msg, key .. ": " .. value)
  end

  table.insert(plain_msg, "MIME-Version: 1.0")
  table.insert(plain_msg, "Content-Type: text/plain; charset=utf-8")
  table.insert(plain_msg, "Content-Transfer-Encoding: 8bit")
  table.insert(plain_msg, "")

  for _, line in ipairs(msg) do
    table.insert(plain_msg, line)
  end

  return vim.fn.writefile(plain_msg, output_filename) == 0
end

local build_mime_msg_file = function(buf, attachment_paths, output_filename)
  local main_lines = v.nvim_buf_get_lines(buf, 0, -1, false)
  local attributes, msg = m.get_msg_attributes(main_lines)
  local body_filename = vim.fn.tempname() .. '-notmuch-body.txt'

  local ok, err = pcall(function()
    local attachments = m.create_mime_attachments(attachment_paths)

    if vim.fn.writefile(msg, body_filename) ~= 0 then
      error('Failed to write message body temp file: ' .. body_filename)
    end

    local mimes = { {
      file = body_filename,
      type = "text/plain; charset=utf-8",
    } }

    for _, attachment in ipairs(attachments) do
      table.insert(mimes, attachment)
    end

    local mime_table = {
      version = "Mime-Version: 1.0",
      type = "multipart/mixed",
      encoding = "8 bit",
      attributes = attributes,
      mime = mimes,
    }

    local mime_msg = m.make_mime_msg(mime_table)
    if vim.fn.writefile(mime_msg, output_filename) ~= 0 then
      error('Failed to write send temp file: ' .. output_filename)
    end
  end)

  if vim.uv.fs_stat(body_filename) then
    vim.fn.delete(body_filename)
  end

  if not ok then
    vim.notify(tostring(err), vim.log.levels.ERROR)
    return false
  end

  return true
end

local build_send_file = function(buf, attachment_paths)
  local send_filename = vim.fn.tempname() .. '-notmuch-send.eml'
  local ok

  if #attachment_paths == 0 then
    ok = build_plain_msg_file(buf, send_filename)
  else
    ok = build_mime_msg_file(buf, attachment_paths, send_filename)
  end

  if not ok then
    if vim.uv.fs_stat(send_filename) then
      vim.fn.delete(send_filename)
    end
    vim.notify('Failed to build email for sending', vim.log.levels.ERROR)
    return nil
  end

  return send_filename
end

-- Send a completed message
--
-- This function takes a file containing a completed message and send it to the
-- recipient(s) using `msmtp`. Typically you will invoke this function after
-- confirming from a reply or newly composed email message. The invocation of
-- `msmtp` determines by itself the recipient and the sender.
--
-- If the configuration `config.options.logfile` is set, then it invokes
-- `msmtp` with logging capability to that file. Otherwise, it logs to
-- temporary file.
--
-- @param filename string: path to the email message you would like to send
--
-- @return string: The log message provided by `msmtp`
--
-- @usage
--   require('notmuch.send').sendmail('/tmp/my_new_email.eml')
s.sendmail = function(filename, opts)
  opts = opts or {}

  if not vim.loop.fs_stat(filename) then
    vim.notify('❌ Email file not found: ' .. filename, vim.log.levels.ERROR)
    if opts.on_failure then
      opts.on_failure(-1)
    end
    return false
  end

  -- Build msmtp command
  local cmd_parts = { 'msmtp', '-t', '--read-envelope-from' }
  if config.options.logfile then
    table.insert(cmd_parts, '--logfile=' .. vim.fn.shellescape(config.options.logfile))
  end
  local msmtp_cmd = table.concat(cmd_parts, ' ') .. ' <' .. vim.fn.shellescape(filename)

  vim.notify('📤 Sending email via msmtp...', vim.log.levels.INFO)

  -- Open blank terminal first (reliable PTY handling for interactive input)
  vim.cmd('botright 15split | terminal')
  local term_buf = v.nvim_get_current_buf()
  local term_job = vim.b.terminal_job_id

  -- Set up TermClose autocmd BEFORE sending command to avoid race condition
  -- Note: Using pattern='*' instead of buffer=term_buf due to Neovim bug where
  -- buffer-specific TermClose doesn't fire reliably on terminal buffers
  local aug = v.nvim_create_augroup('NotmuchSendmail_' .. term_buf, { clear = true })
  v.nvim_create_autocmd('TermClose', {
    group = aug,
    pattern = '*',
    once = true,
    callback = function(ev)
      -- Only process TermClose for our specific terminal buffer
      if ev.buf ~= term_buf then
        return
      end

      -- Get exit code from v:event.status
      local exit_code = vim.v.event.status or -1

      -- Defer notification on success because of buffer close redraw
      if exit_code == 0 then
        vim.defer_fn(function() vim.notify('✅ Email sent successfully', vim.log.levels.INFO) end, 500)
        if opts.on_success then
          opts.on_success()
        end
      else
        vim.notify('❌ Failed to send email (exit code: ' .. exit_code .. ')', vim.log.levels.ERROR)
        if opts.on_failure then
          opts.on_failure(exit_code)
        end
      end
    end
  })

  -- Send the command to the terminal, then exit shell to trigger TermClose
  vim.fn.chansend(term_job, msmtp_cmd .. ' ; exit\n')

  -- Start in insert mode for immediate interaction (e.g. passphrase prompt)
  vim.cmd('startinsert')

  return true
end

-- Reply to an email message
--
-- This function uses `notmuch reply` to generate and prepare a reply draft to a
-- message by scanning for the `id` of the message you want to reply to. The
-- draft file will be stored in `tmp/` and a keymap (default `<C-c><C-c>`) to
-- allow sending directly from within nvim
--
-- @usage
--   -- Typically you would just press `R` on a message in a thread
--   require('notmuch.send').reply()
s.reply = function()
  -- Get msg id of the mail to be replied to
  local id = thread.get_current_message_id()
  if not id then return end

  -- Create new draft mail to hold reply
  local sanitized_id = id:gsub('/', '-')
  local reply_filename = '/tmp/reply-' .. sanitized_id .. '.eml'

  -- Create and edit buffer containing reply file
  local buf = v.nvim_create_buf(true, false)
  v.nvim_win_set_buf(0, buf)
  vim.cmd.edit(reply_filename)

  -- If first time replying, generate draft. Otherwise, no need to duplicate
  if not u.file_exists(reply_filename) then
    vim.cmd('silent 0read! notmuch reply id:' .. id)
  end

  vim.bo.bufhidden = "wipe"          -- Automatically wipe buffer when closed
  v.nvim_win_set_cursor(0, { 1, 0 }) -- Return cursor to top of file

  -- Initialize attachments variable
  -- Sample "attachment" object:
  --   {
  --     file = 'path/to/attachment',
  --     size = uv.fs_stat(),
  --     mime = mime.get_mime_type()
  --     valid = true or false -- u.validate_attachment_file()
  --   }
  vim.api.nvim_buf_set_var(buf, 'notmuch_attachments', {})

  -- Define commands for attachment management (attach_cmd.lua)
  local attach_cmd = require('notmuch.attach_cmd')

  v.nvim_buf_create_user_command(buf, 'Attach', attach_cmd.attach_handler(buf), {
    nargs = 1,
    complete = 'file',
    desc = 'Add file to email attachments'
  })

  v.nvim_buf_create_user_command(buf, 'AttachRemove', attach_cmd.remove_handler(buf), {
    nargs = 1,
    complete = attach_cmd.remove_completion(buf),
    desc = 'Remove attachment by filepath'
  })

  v.nvim_buf_create_user_command(buf, 'AttachList', attach_cmd.list_handler(buf), {
    nargs = 0,
    desc = 'List current email attachments'
  })

  -- Set keymap for sending
  vim.keymap.set('n', config.options.keymaps.sendmail, function()
    if confirm_sendmail() then
      local attachments = v.nvim_buf_get_var(buf, 'notmuch_attachments')

      if #attachments == 0 then
        build_plain_msg(buf)
      else
        build_mime_msg_from_attachments(buf, attachments, reply_filename)
      end

      s.sendmail(reply_filename)
    end
  end, { buffer = true })
end

local attachment_lines = function(buf_attach)
  local lines = v.nvim_buf_get_lines(buf_attach, 0, -1, false)
  local attachments = {}

  for _, line in ipairs(lines) do
    if line:find('%S') then
      local filepath = vim.fn.expand(line)
      filepath = vim.fn.fnamemodify(filepath, ':p')
      table.insert(attachments, filepath)
    end
  end

  return attachments
end

local send_draft = function(buf, buf_attach, draft)
  -- Saves current draft mail content for good measure
  v.nvim_buf_call(buf, function()
    vim.cmd('silent! write')
  end)

  -- Collect attachments for `buf_attach` (scratch) and save to draft metadata
  local attachments = attachment_lines(buf_attach)
  v.nvim_buf_set_var(buf, 'notmuch_attachments', attachments)
  if not require('notmuch.draft').save_attachments(draft.json_path, attachments) then
    vim.notify('Failed to persist draft attachment metadata before sending', vim.log.levels.ERROR)
    return false
  end

  -- Build the MIME-compliant email message in TMP directory
  local send_filename = build_send_file(buf, attachments)
  if not send_filename then
    return false
  end

  -- Send with success and failure callbacks
  return s.sendmail(send_filename, {
    on_success = function()
      vim.fn.delete(send_filename)
      local draft_module = require('notmuch.draft')

      if config.options.drafts.delete_sent then
        draft_module.delete_draft(draft)
      else
        draft_module.mark_sent(draft.json_path)
      end
    end,
    on_failure = function()
      vim.fn.delete(send_filename)
    end,
  })
end

local open_draft_buffer = function(draft)
  local draft_filename = draft.eml_path

  -- Create new buffer for the draft
  local buf = v.nvim_create_buf(true, false)
  v.nvim_win_set_buf(0, buf)
  vim.cmd.edit(vim.fn.fnameescape(draft_filename))

  -- Set buffer-local variables for metadata and attachments
  v.nvim_buf_set_var(buf, 'notmuch_draft_json_path', draft.json_path)
  v.nvim_buf_set_var(buf, 'notmuch_attachments', draft.metadata.attachments or {})

  -- Create the attachment manager scratch buffer
  local buf_attach = v.nvim_create_buf(true, true)
  v.nvim_buf_set_lines(buf_attach, 0, -1, false, draft.metadata.attachments or {})

  -- Setup autocmd for auto-syncing text in scratch buffer to attachments list
  v.nvim_create_autocmd({ 'TextChanged', 'TextChangedI', 'BufLeave' }, {
    buffer = buf_attach,
    callback = function()
      local attachments = attachment_lines(buf_attach)
      v.nvim_buf_set_var(buf, 'notmuch_attachments', attachments)
      require('notmuch.draft').save_attachments(draft.json_path, attachments)
    end,
  })

  -- Keymap for showing attachment_window
  vim.keymap.set('n', config.options.keymaps.attachment_window, function()
    vim.api.nvim_open_win(buf_attach, true, {
      split = 'left',
      win = 0
    })
  end, { buffer = true })

  -- Keymap for sending the email
  vim.keymap.set('n', config.options.keymaps.sendmail, function()
    if confirm_sendmail() then
      send_draft(buf, buf_attach, draft)
    end
  end, { buffer = true })
end

-- Compose a new email
--
-- This function creates a new email for the user to edit, with the standard
-- message headers and body. The mail content is stored in the persistent drafts
-- directory so the user can come back to it later if needed.
--
-- @param to string: recipient address (optionaal argument)
--
-- @usage
--   -- Typically you can run this with `:ComposeMail` or pressing `C`
--   require('notmuch.send').compose()
s.compose = function(to)
  to = to or ''

  -- TODO: Add ability to modify default body message and signature
  local headers = {
    'From: ' .. config.options.from,
    'To: ' .. to,
    'Cc: ',
    'Subject: ',
    '',
    'Message body goes here. Add attachments with "' ..
    config.options.keymaps.attachment_window .. '". Send with "' .. config.options.keymaps.sendmail .. '".',
  }

  -- Prepare draft
  local draft = require('notmuch.draft').create_compose_draft(headers)
  if not draft then
    return
  end

  open_draft_buffer(draft)
end

s.open_compose_draft = function(eml_path)
  local draft = require('notmuch.draft').load_compose_draft(eml_path)
  if not draft then
    return
  end

  open_draft_buffer(draft)
end

s.open_reply_draft = function(eml_path)
  local draft = require('notmuch.draft').load_reply_draft(eml_path)
  if not draft then
    return
  end

  open_draft_buffer(draft)
end

local new_compose_draft_item = {
  action = 'new_compose'
}

local function format_draft_timestamp(timestamp)
  if not timestamp or timestamp == vim.NIL or timestamp == '' then
    return 'unknown'
  end

  local date, hour, min = timestamp:match('^(%d%d%d%d%-%d%d%-%d%d)T(%d%d):(%d%d)')
  if not date then
    return timestamp
  end

  return string.format('%s %s:%s', date, hour, min)
end

local format_compose_draft_item = function(item)
  if item.action == 'new_compose' then
    return '➕ Compose new draft'
  end

  local draft = item.draft
  local kind = item.draft.kind
  local timestamp = draft.metadata.updated_at or draft.metadata.created_at
  local updated = format_draft_timestamp(timestamp)
  local subject = draft.subject or '[No subject]'
  local attachments = draft.metadata.attachments or {}
  local attach = #attachments > 0 and ('(📎' .. #attachments .. ')') or ''

  return string.format('[%s] %s - %s %s', kind, updated, subject, attach)
end

s.select_compose_draft = function()
  local drafts = require('notmuch.draft').list_compose_drafts()
  if not drafts then
    return
  end

  local items = {
    new_compose_draft_item,
  }

  for _, draft in ipairs(drafts) do
    table.insert(items, {
      action = 'open_compose',
      draft = draft,
    })
  end

  vim.ui.select(items, {
    prompt = 'Select compose draft:',
    format_item = format_compose_draft_item,
  }, function(choice)
    if not choice then
      return
    end

    if choice.action == 'new_compose' then
      s.compose()
      return
    end

    if choice.action == 'open_compose' then
      s.open_compose_draft(choice.draft.eml_path)
    end
  end)
end

return s
