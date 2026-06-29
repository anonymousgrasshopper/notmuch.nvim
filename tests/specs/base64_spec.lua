local H = dofile("tests/helpers.lua")

return {
  {
    name = "base64 encodes known RFC 4648 examples",
    run = function()
      local b64 = require("notmuch.base64")
      H.eq("", b64.encode(""))
      H.eq("Zg==", b64.encode("f"))
      H.eq("Zm8=", b64.encode("fo"))
      H.eq("Zm9v", b64.encode("foo"))
      H.eq("Zm9vYmFy", b64.encode("foobar"))
    end,
  },
  {
    name = "base64 decodes known RFC 4648 examples",
    run = function()
      local b64 = require("notmuch.base64")
      H.eq("", b64.decode(""))
      H.eq("f", b64.decode("Zg=="))
      H.eq("fo", b64.decode("Zm8="))
      H.eq("foo", b64.decode("Zm9v"))
      H.eq("foobar", b64.decode("Zm9vYmFy"))
    end,
  },
  {
    name = "base64 round-trips binary-like input",
    run = function()
      local b64 = require("notmuch.base64")
      local input = string.char(0, 1, 2, 127, 128, 255) .. "hello"
      H.eq(input, b64.decode(b64.encode(input)))
    end,
  },
}
