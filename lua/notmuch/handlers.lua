local H = {}

--- Default handler for opening attachments externally
---@param attachment table Table with 'path' field containing file path
H.default_open_handler = function(attachment)
  local path = attachment.path

  -- Detect OS and choose appropriate command
  local open_cmd
  local sysname = vim.uv.os_uname()

  if sysname.sysname == 'Darwin' then
    open_cmd = 'open'
  elseif sysname.sysname == 'Linux' then
    open_cmd = 'xdg-open'
  elseif sysname.sysname:match('Windows') then
    open_cmd = 'start'
  else
    open_cmd = 'xdg-open' -- fallback
  end

  -- Execute
  vim.system({ open_cmd, path }, { detach = true })
end

--- Default handler for viewing attachments in the floating window viewer
---@param attachment table Table with 'path' field containing file path
---@return string Text content to display in floating window
H.default_view_handler = function(attachment)
  local path = attachment.path -- Already expanded, careful to escape

  -- Helper function to "try" commands in order until one works
  local try_commands = function(arg)
    return require("notmuch.util").try_commands(arg, path)
  end

  -- Detect file type
  local filetype = vim.fn.system({ "file", "--mime-type", "-b", path }):gsub("%s+$", "")

  local default = {
    {
      mime = "^text/html$",
      desc = "HTML file (install w3m, lynx, or elinks to view)",
      try = {
        { tool = "w3m", command = function(p) return { "w3m", "-T", "text/html", "-dump", p } end },
        { tool = "lynx", command = function(p) return { "lynx", "-dump", "-nolist", p } end },
        { tool = "elinks", command = function(p) return { "elinks", "-dump", "-no-references", p } end },
      },
    },
    {
      mime = "^application/pdf$",
      desc = "PDF file (install pdftotext or mutool to view)",
      try = {
        { tool = "pdftotext", command = function(p) return { "pdftotext", "-layout", p, "-" } end },
        { tool = "mutool", command = function(p) return { "mutool", "draw", "-F", "txt", p } end },
      },
    },
    {
      mime = "^image/",
      desc = "Image file (install chafa, viu, or exiftool to view)",
      try = {
        { tool = "chafa", command = function(p) return { "chafa", "--size", "80x40", p } end },
        { tool = "catimg", command = function(p) return { "catimg", "-w", "80", p } end },
        { tool = "viu", command = function(p) return { "viu", "-w", "80", p } end },
        { tool = "exiftool", command = function(p) return { "exiftool", p } end },
        { tool = "identify", command = function(p) return { "identify", "-verbose", p } end },
      },
    },
    {
      mime = "officedocument",
      desc = "Office document (install pandoc or docx2txt to view)",
      try = {
        { tool = "pandoc", command = function(p) return { "pandoc", "-t", "plain", p } end },
        { tool = "docx2txt", command = function(p) return { "docx2txt", p, "-" } end },
      },
    },
    {
      mime = "^text/markdown$",
      try = {
        { tool = "pandoc", command = function(p) return { "pandoc", "-t", "plain", p } end },
        { tool = "mdcat", command = function(p) return { "mdcat", p } end },
        { tool = "cat", command = function(p) return { "cat", p } end },
      },
    },
    {
      mime = "zip",
      try = {
        { tool = "zip", command = function(p) return { "unzip", "-l", p } end },
      },
    },
    {
      mime = "tar",
      try = {
        { tool = "tar", command = function(p) return { "tar", "-tvf", p } end },
      },
    },
    {
      mime = "^text/",
      try = {
        { tool = "cat", command = function(p) return { "cat", p } end },
      },
    },
    {
      mime = "",
      desc = string.format(
        "Unable to view binary file\nType: %s\nPath: %s",
        filetype,
        path
      ),
      try = {
        { tool = "strings", command = function(p) return { "strings", p } end },
      },
    },
  }

  -- ensure user_config overrides default
  local user_config = require("notmuch.config").options.view_handlers
  local handlers = vim.iter({ user_config, default }):flatten():totable()

  for _, tbl in ipairs(handlers) do
    if filetype:match(tbl.mime) then
      return try_commands(tbl.try) or tbl.desc or ""
    end
  end

  return "No handler found for this filetype"
end

return H

-- vim: tabstop=2:shiftwidth=2:expandtab
