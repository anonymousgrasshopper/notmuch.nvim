local a = {}
local u = require('notmuch.util')
local draft = require('notmuch.draft')
local v = vim.api

a.attach_handler = function(buf)
  return function(opts)
    local attachments = v.nvim_buf_get_var(buf, 'notmuch_attachments')

    -- Expand and convert filepath to absolute path
    local filepath = vim.fn.expand(opts.args)
    filepath = vim.fn.fnamemodify(filepath, ':p')

    -- Validate file immediately for user feedback (fail-fast if invalid)
    local valid, err = u.validate_attachment_file(filepath)
    if not valid then
      vim.notify('Cannot attach ' .. filepath .. '\n' .. err, vim.log.levels.ERROR)
      return
    end

    -- Check for duplicates in existing `notmuch_attachments` variable
    for _, path in ipairs(attachments) do
      if path == filepath then
        vim.notify('Already attached: ' .. filepath, vim.log.levels.WARN)
        return
      end
    end

    -- Add to `notmuch_attachments` list and update buffer variable
    table.insert(attachments, filepath)
    v.nvim_buf_set_var(buf, 'notmuch_attachments', attachments)

    if not draft.save_buffer_attachments(buf, attachments) then
      table.remove(attachments)
      v.nvim_buf_set_var(buf, 'notmuch_attachments', attachments)
      vim.notify('Failed to persist attachment metadata: ' .. filepath, vim.log.levels.ERROR)
      return
    end

    -- Report success
    vim.notify(string.format('Attached: %s (%d total)', filepath, #attachments), vim.log.levels.INFO)
  end
end

a.remove_handler = function(buf)
  return function(opts)
    local attachments = v.nvim_buf_get_var(buf, 'notmuch_attachments')
    local filepath = vim.fn.expand(opts.args)
    filepath = vim.fn.fnamemodify(filepath, ':p')

    -- Find and remove the file from attachments
    local found_index = nil
    for i, path in ipairs(attachments) do
      if path == filepath then
        found_index = i
      end
    end

    -- Show error if not found
    if not found_index then
      vim.notify('File not in attachments (check with :AttachList): ' .. filepath, vim.log.levels.ERROR)
      return
    end

    -- Remove from `attachments` and update back to buffer
    local removed = table.remove(attachments, found_index)
    v.nvim_buf_set_var(buf, 'notmuch_attachments', attachments)

    if not draft.save_buffer_attachments(buf, attachments) then
      table.insert(attachments, found_index, removed)
      v.nvim_buf_set_var(buf, 'notmuch_attachments', attachments)
      vim.notify('Failed to persist attachment metadata: ' .. filepath, vim.log.levels.ERROR)
      return
    end

    -- Report success
    vim.notify(string.format('Removed: %s (%d remaining)', filepath, #attachments), vim.log.levels.INFO)
  end
end

a.remove_completion = function(buf)
  return function()
    return v.nvim_buf_get_var(buf, 'notmuch_attachments')
  end
end

a.list_handler = function(buf)
  return function()
    local attachments = v.nvim_buf_get_var(buf, 'notmuch_attachments')

    if #attachments == 0 then
      print('No attachments. Try adding with :Attach')
      return
    end

    print(string.format('Attachments (%d):', #attachments))
    for i, path in ipairs(attachments) do
      local stat = vim.uv.fs_stat(path)
      local size_kb = stat and math.floor(stat.size / 1024) or 0
      print(string.format('  [%d] %s (%d KB)', i, path, size_kb))
    end
  end
end

return a
