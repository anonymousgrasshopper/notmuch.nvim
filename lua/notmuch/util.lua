local u = {}
local v = vim.api

--- Checks if the composed emails contains any attachments expected to be sent.
---
--- This is mainly used after composing the email and triggering the email to be
--- sent. More specfically, it returns `true` if the attachment window/buffer
--- contains any attachments to be sent along with the email. This is done by
--- checking if the attachment window has any text in it (if there is no text,
--- then no attachments are included).
---
--- This is particularly useful in figuring out how to formulate the composed
--- message to be fed to the email server.
---
--- - If there are no attachments, the caller will formulate a plain text
---   message with only the body with `build_plain_msg`.
---
--- - If there are attachments, the caller will invoke `build_mime_msg`.
---
--- @param buf_attach integer: buffer ID of the attachment window
--- @return boolean: true if attachment buffer has attachments (any text)
u.empty_attachment_window = function (buf_attach)
  for _, line in ipairs(v.nvim_buf_get_lines(buf_attach, 0, -1, false)) do
    if line:find("%S") then
      return false
    end
  end
  return true
end

u.format_size = function (bytes)
  if bytes == 0 or bytes == nil then
    return "—"
  elseif bytes < 1024 then
    return bytes .. "B"
  elseif bytes < 1024 * 1024 then
    return string.format("%.0fK", bytes / 1024)
  elseif bytes < 1024 * 1024 * 1024 then
    return string.format("%.1fM", bytes / (1024 * 1024))
  else
    return string.format("%.1fG", bytes / (1024 * 1024 * 1024))
  end
end

u.file_exists = function(path)
  local file = io.open(path, 'r')
  if file then
    file:close()
    return true
  else
    return false
  end
end

--- Validates that a file path is readable and suitable for attachment
---
--- This function checks if a file exists, is readable, and is a regular file
--- (not a directory or broken symlink). If validation fails, returns false
--- and an error message suitable for user display.
---
--- @param path string: file path to validate
--- @return boolean: true if file is valid for attachment
--- @return string|nil: error message if validation failed, nil if successful
u.validate_attachment_file = function(path)
  -- Attempt to open file for reading
  local file, err = io.open(path, 'r')

  if not file then
    return false, err
  end

  file:close()

  -- Use vim.uv to check if it's a regular file (not directory/special file)
  local stat = vim.uv.fs_stat(path)
  if not stat then
    return false, "Unable to read file metadata"
  end

  if stat.type ~= 'file' then
    return false, string.format("Path is a %s, not a regular file", stat.type)
  end

  return true, nil
end

-- there is a better way to do this !!!
-- Splits a string given a delimiter
--
-- This function takes in a string and splits it into a table of strings based
-- on some delimiter given by the caller, and returns the result table.
--
-- @param s string: input string
-- @param delim string: delimiter string (can be char or more complex)
--
-- @returns out table: table of strings as split by the function given delim
u.split = function(s, delim)
  local out = {}
  local i = 1
  for entry in string.gmatch(s, delim) do
    out[i] = entry
    i = i + 1
  end
  return out
end

-- Splits a string by a given length
--
-- This function takes in a string and splits it into a table of strings based
-- on some length given by the caller, and returns the result table.
--
-- @param s string: input string
-- @param length integer: length integer
--
-- @returns out table: table of strings as split by the function given length
u.split_length = function(s, length)
  local out = {}

  for i=1, #s, length do
    out[#out+1] = s:sub(i, i + length - 1)
  end

  return out
end

-- Indents the header line of a message based on its depth
--
-- This function takes in the buffer and line number of a message header, and
-- the depth of the email message in the thread's reply chain. Accordingly the
-- function will prepend the header with special characters to signify its depth
-- to the user in a user friendly way.
--
-- @param buf int: id of the buffer containing the message header in question
-- @param lineno int: line number of the header which the user wants to indent
-- @param depth int: depth of the message in the reply chain of the thread
--
-- @usage
-- -- See u.process_msgs_in_thread() for invocation example
-- indent_depth(buf, lineno, msg.depth)
local indent_depth = function(buf, lineno, depth)
  local line = vim.fn.getline(lineno)
  local s = ''
  for _=0,depth-1 do s = '────' .. s end
  v.nvim_buf_set_lines(buf, lineno-1, lineno, true, { s .. line })
end

-- Processes the output of `notmuch show` to user friendly buffer format
--
-- This function iterates over the lines of the buffer `buf`, identifying and
-- transforming lines matching certain patterns typically found in `notmuch`
-- message output. Relevant details of each message are extracted and headers
-- are modified for better readability and navigation through logical folds in
-- Neovim.
--
-- @param buf: The buffer id where the message content is located.
--
-- Behavior:
-- - Identifies lines starting with "message{", extracting metadata.
-- - Inserts structural navigation markers "{{{" and "}}}" for message folds.
-- - Deletes unnecessary line information such as envelope or parts detail,
-- 
-- Side Effects:
-- - Modifies the passed `buf` in place by adding, removing, or changing lines of text.
-- - Adds folding marks "{{{" and "}}}" for smooth folding and chaining.
-- - Indents (using `indent_depth()`) based on each msg's depth in reply chain
--
-- Usage Warning:
-- - Expects a valid Neovim buffer with `notmuch` formatted messages.
-- - Subject to change based on format of `notmuch-show` raw output
-- - Designed for synchronous message processing
--   - As of now this is fine, there is no notable performance degradation
--   - If threads are much larger, might need to explore async funcs
u.process_msgs_in_thread = function(buf)
  -- Loop over each line in the buffer and clean up the message output format
  local msg = {} -- Table which stores id, depth, file of a message
  local lineno = 1 -- Start from the top of the buffer
  local last = vim.fn.line('$') -- End at the bottom of the buffer

  while lineno <= last do
    -- Store line contents
    local line = vim.fn.getline(lineno)

    -- Message start : Store message details in `msg` and remove the line
    if string.match(line, "^message{") ~= nil then
      msg.id = string.match(line, 'id:%S+')
      msg.depth = tonumber(string.match(string.match(line, 'depth:%d+'), '%d+'))
      msg.filename = string.match(line, 'filename:%C+')
      v.nvim_buf_set_lines(buf, lineno-1, lineno, true, {})
      lineno = lineno - 1
      last = last - 1 -- Because we removed a line so buffer is shorter

    -- Header fields : Subject, From, To, etc. Indent based on `msg.depth`
    elseif string.match(line, '^header{') ~= nil then
      v.nvim_buf_set_lines(buf, lineno-1, lineno, true, {}) -- Remove "header("
      indent_depth(buf, lineno, msg.depth)
      line = vim.fn.getline(lineno) -- Add fold start identifier '{{{'
      v.nvim_buf_set_lines(buf, lineno-1, lineno, true, { line, msg.id .. ' {{{' })

    -- Pass over "Subject" field and next header fields
    elseif string.match(line, '^Subject:') ~= nil then
      lineno = lineno + 2
      last = last + 1

    -- Closing header field : Delete
    elseif string.match(line, '^header}') ~= nil then
      v.nvim_buf_set_lines(buf, lineno-1, lineno, true, { '' })

    -- Closing message field : Replace with folding closing "}}}"
    elseif string.match(line, '^message}') ~= nil then
      v.nvim_buf_set_lines(buf, lineno-1, lineno, true, { '}}}', '' })
      lineno = lineno + 1
      last = last + 1

    -- Removes extra cruft like "parts", etc.
    elseif string.match(line, '^%a+[{}]') ~= nil then
      v.nvim_buf_set_lines(buf, lineno-1, lineno, true, {})
      lineno = lineno - 1
      last = last - 1
    end

    -- Increment lineno to inspect the next line, next loop
    lineno = lineno + 1
  end
end

-- Retrieves the id of the message under cursor
--
-- This function fetches the id of the message being viewed under the cursor by
-- iteratively scanning each line backwards for the `id:` field. If used
-- incorrectly or no id is found, a helpful message will indicate the same
--
-- @returns id int: id of the email messageo
--
-- @usage
-- local id = require('notmuch.util').find_cursor_msg_id()
-- -- Do something with the mail id (e.g. reply, tag, get attachments)
u.find_cursor_msg_id = function()
  local n = v.nvim_win_get_cursor(0)[1] + 1
  local line = nil
  local id = nil
  while n ~= 1 do
    line = vim.fn.getline(n)
    if string.match(line, '^id:%S+ {{{$') ~= nil then
      id = string.match(line, '%S+', 4)
      return id
    end
    n = n - 1
  end

  -- id not found for the cursor location
  print('No ID found. Make sure cursor is located in a message')
  return nil
end

---@param path string path to file to load
---@return string? content file contents
function u.loadfile(path)
  local fd = vim.uv.fs_open(path, "r", 438)
  if not fd then return end
  local stat = vim.uv.fs_fstat(fd)
  local content = stat and vim.uv.fs_read(fd, stat.size, 0) or nil
  vim.uv.fs_close(fd)
  return content
end

return u

-- vim: tabstop=2:shiftwidth=2:expandtab:foldmethod=indent
