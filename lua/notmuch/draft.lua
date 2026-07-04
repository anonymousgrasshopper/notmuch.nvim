--- notmuch.draft -- Draft management module for notmuch.nvim
---
--- Manages the process of creating new drafts, maintaining multiple unique
--- drafts for the reply, keeping open drafts for newly composed messages, etc.
--- in the user's data home directory, controlled by the config option
--- `drafts.folder`
---
--- Drafts by default live in the user's data home like so:
---   vim.fs.joinpath(vim.fn.stdpath("data"), "notmuch.nvim", "drafts")
---
--- Example:
---   $HOME/.local/share/nvim/notmuch.nvim/drafts
---
--- Sample directory structure:
---
---   drafts/         <- [Root drafts directory]
---   ├── compose/    <- [Drafts of newly composed emails]
---   │   ├── compose-20260704T103015Z-a1b2c3d4.eml
---   │   ├── compose-20260704T103015Z-a1b2c3d4.json
---   │   │
---   │   ├── compose-20260704T123400Z-9c0d1e2f.eml
---   │   └── compose-20260704T123400Z-9c0d1e2f.json
---   │
---   └── replies/    <- [Drafts of replies to other messages]
---       ├── 9c7e0a3b1d4e6f8.../  <- [SHA256 hash of original msg-id]
---       │   ├── message.json     <- [Sidecar metadata file of original msg]
---       │   │
---       │   ├── reply-20260704T104455Z-11112222.eml
---       │   ├── reply-20260704T104455Z-11112222.json
---       │   │
---       │   ├── reply-20260704T115902Z-33334444.eml
---       │   └── reply-20260704T115902Z-33334444.json
---       │
---       └── f6a90e17cc3a21.../
---           ├── message.json
---           │
---           ├── reply-20260704T130102Z-cc77dd88.eml
---           ├── reply-20260704T130102Z-cc77dd88.json
---           │
---           ├── reply-20260704T131500Z-ee99ff00.eml
---           ├── reply-20260704T131500Z-ee99ff00.json
---           │
---           ├── reply-20260704T133000Z-1122aabb.eml
---           └── reply-20260704T133000Z-1122aabb.json
---
--- Architecture:
---
--- - The drafts/ root directory is split into two subdirectories
---   - compose/ -- Drafts of newly composed emails
---   - replies/ -- Drafts of *replies* to other messages
---
--- - Compose
---   - For each draft, two files are coupled
---   - compose-<timestamp>-<random-hash>.eml
---     - The actual email content itself
---   - compose-<timestamp>-<random-hash>.json
---     - Sidecar file with attachments/metadata for persistence
---     - When loading the draft later, the sidecar keeps track of previously
---       kept attachments, etc.
---
--- - Replies
---   - Each reply has a subdirectory of the hash of the original message's ID
---   - This is in case you have multiple drafts for one message's reply
---   - `message.json` -- Sidecar metadata file of the original message
---   - `reply-<timestamp>-<random-hash>.eml`
---     - The actual email content itself
---   - `reply-<timestamp>-<random-hash>.json`
---     - Sidecar file with attachments/metadata for persistence

local D = {}

local config = require('notmuch.config')

local function now_utc()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function random_suffix()
  return vim.fn.sha256(vim.fn.tempname()):sub(1, 8)
end

local function ensure_dir(path)
  local stat = vim.uv.fs_stat(path)

  if stat then
    if stat.type ~= 'directory' then
      vim.notify('Draft path exists but is not a directory: ' .. path, vim.log.levels.ERROR)
      return false
    end
    return true
  end

  local ok = vim.fn.mkdir(path, 'p', 448) -- Octal: 0700 permissions drwx------
  if ok == 0 then
    vim.notify('Failed to create draft directory: ' .. path, vim.log.levels.ERROR)
    return false
  end

  return true
end

function D.compose_dir()
  return vim.fs.joinpath(config.options.drafts.folder, 'compose')
end

function D.sidecar_path(eml_path)
  local path = eml_path:gsub('%.eml$', '.json')
  return path
end

function D.read_metadata(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    vim.notify('Failed to read draft metadata: ' .. path, vim.log.levels.ERROR)
    return nil
  end

  local raw = table.concat(lines, '\n')
  local decode_ok, metadata = pcall(vim.json.decode, raw)
  if not decode_ok then
    vim.notify('Failed to decode draft metadata: ' .. path, vim.log.levels.ERROR)
    return nil
  end

  return metadata
end

function D.write_metadata(path, metadata)
  local ok, json = pcall(vim.json.encode, metadata)
  if not ok then
    vim.notify('Failed to encode draft metadata: ' .. json, vim.log.levels.ERROR)
    return false
  end

  local write_ok = vim.fn.writefile({ json }, path)
  if write_ok ~= 0 then
    vim.notify('Failed to write draft metadata: ' .. path, vim.log.levels.ERROR)
    return false
  end

  return true
end

function D.save_attachments(json_path, attachments)
  local metadata = D.read_metadata(json_path)
  if not metadata then
    return false
  end

  metadata.attachments = attachments or {}
  metadata.updated_at = now_utc()

  return D.write_metadata(json_path, metadata)
end

function D.save_buffer_attachments(buf, attachments)
  local ok, json_path = pcall(vim.api.nvim_buf_get_var, buf, 'notmuch_draft_json_path')
  if not ok or not json_path then
    return true
  end

  return D.save_attachments(json_path, attachments)
end

function D.create_compose_draft(lines)
  if type(lines) ~= 'table' then
    vim.notify('create_compose_draft expected lines table', vim.log.levels.ERROR)
    return nil
  end

  for i, line in ipairs(lines) do
    if type(line) ~= 'string' then
      vim.notify(
        string.format('create_compose_draft expected line %d to be a string', i),
	vim.log.levels.ERROR
      )
      return nil
    end
  end

  local dir = D.compose_dir()

  if not ensure_dir(dir) then
    return nil
  end

  local timestamp = os.date("!%Y%m%dT%H%M%SZ")
  local basename = string.format("compose-%s-%s", timestamp, random_suffix())

  local eml_path = vim.fs.joinpath(dir, basename .. '.eml')
  local json_path = D.sidecar_path(eml_path)

  local created_at = now_utc()

  local metadata = {
    schema_version = 1,
    kind = 'compose',
    attachments = {},
    created_at = created_at,
    updated_at = created_at,
    sent_at = vim.NIL,
  }

  local ok_eml = vim.fn.writefile(lines, eml_path)
  if ok_eml ~= 0 then
    vim.notify('Failed to write compose draft: ' .. eml_path, vim.log.levels.ERROR)
    return nil
  end

  if not D.write_metadata(json_path, metadata) then
    vim.fn.delete(eml_path)
    return nil
  end

  return {
    kind = 'compose',
    eml_path = eml_path,
    json_path = json_path,
    metadata = metadata,
  }
end

function D.load_compose_draft(eml_path)
  local json_path = D.sidecar_path(eml_path)
  local metadata = D.read_metadata(json_path)
  if not metadata then
    return nil
  end

  return {
    kind = 'compose',
    eml_path = eml_path,
    json_path = json_path,
    metadata = metadata,
  }
end

return D
