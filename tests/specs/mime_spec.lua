local H = dofile("tests/helpers.lua")

return {
  {
    name = "mime.get_msg_attributes parses headers, folded headers, and body",
    run = function()
      local mime = require("notmuch.mime")
      local attrs, body = mime.get_msg_attributes({
        "From: sender@example.com",
        "Subject: hello",
        "\tcontinued subject",
        "X-Empty:",
        "",
        "Body line 1",
        "Body line 2",
      })

      H.eq("sender@example.com", attrs.From)
      H.eq("hello continued subject", attrs.Subject)
      H.eq("", attrs["X-Empty"])
      H.same({ "", "Body line 1", "Body line 2" }, body)
    end,
  },
  {
    name = "mime.get_msg_attributes treats first non-header as body",
    run = function()
      local mime = require("notmuch.mime")
      local attrs, body = mime.get_msg_attributes({ "not a header", "next line" })
      H.same({}, attrs)
      H.same({ "not a header", "next line" }, body)
    end,
  },
  {
    name = "mime.create_mime_attachments validates paths and records metadata",
    run = function()
      local mime = require("notmuch.mime")
      local dir = H.tmpdir()
      local file = H.write_file(dir .. "/note.txt", "hello")

      local attachments = mime.create_mime_attachments({ "", file })
      H.eq(1, #attachments)
      H.eq(file, attachments[1].file)
      H.eq(true, attachments[1].attachment)
      H.eq("base64", attachments[1].encoding)
      H.eq("text/plain", attachments[1].type)
    end,
  },
  {
    name = "mime.create_mime_attachments reports all invalid paths",
    run = function()
      local mime = require("notmuch.mime")
      local ok, err = pcall(function()
        mime.create_mime_attachments({ "/definitely/missing/notmuch.nvim" })
      end)
      H.eq(false, ok)
      H.contains(err, "Failed to attach file(s)")
      H.contains(err, "/definitely/missing/notmuch.nvim")
    end,
  },
  {
    name = "mime.make_mime_msg builds base64 attachment parts with wrapped lines",
    run = function()
      local mime = require("notmuch.mime")
      local dir = H.tmpdir()
      local file = H.write_file(dir .. "/payload.bin", string.rep("a", 80))

      local lines = mime.make_mime_msg({
        file = file,
        type = "application/octet-stream",
        encoding = "base64",
        attachment = true,
      })

      H.contains(lines, "Content-Type: application/octet-stream")
      H.contains(lines, "Content-Transfer-Encoding: base64")
      H.contains(lines, [[Content-Disposition: attachment; filename="payload.bin"]])

      local encoded_lines = {}
      for _, line in ipairs(lines) do
        if line:match("^[A-Za-z0-9+/=]+$") then
          table.insert(encoded_lines, line)
          H.ok(#line <= 76, "base64 line exceeds 76 chars: " .. #line)
        end
      end
      H.ok(#encoded_lines > 1, "expected wrapped base64 output")
    end,
  },
  {
    name = "mime.make_mime_msg builds multipart messages with final boundary",
    run = function()
      local mime = require("notmuch.mime")
      local old_boundary = mime.get_boundary
      mime.get_boundary = function() return "BOUNDARY" end

      local dir = H.tmpdir()
      local file = H.write_file(dir .. "/body.txt", "hello\n")
      local lines = mime.make_mime_msg({
        type = "multipart/mixed",
        attributes = { From = "a@example.com", To = "b@example.com" },
        mime = {
          { file = file, type = "text/plain" },
        },
      })

      mime.get_boundary = old_boundary

      H.contains(lines, "Content-Type: multipart/mixed;")
      H.contains(lines, " boundary=BOUNDARY")
      H.contains(lines, "From: a@example.com")
      H.contains(lines, "--BOUNDARY")
      H.contains(lines, "--BOUNDARY--")
    end,
  },
}
