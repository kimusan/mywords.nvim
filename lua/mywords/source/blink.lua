local store = require("mywords.store")

local M = {}

local Kind = require("blink.cmp.types").CompletionItemKind
local InsertTextFormat = vim.lsp.protocol.InsertTextFormat

-- blink.cmp calls require(<module>).new(opts). The store is already
-- initialized by mywords.setup, which runs before the user's blink.cmp
-- provider is instantiated, so reading from it here is safe.
function M.new()
  local self = setmetatable({}, { __index = M })
  return self
end

function M:enabled()
  return vim.api.nvim_get_option_value("buftype", { buf = 0 }) ~= "nofile"
end

function M:get_trigger_characters()
  return { " " }
end

-- ctx.cursor is { 1-indexed line, 0-indexed col }; textEdit ranges are
-- 0-indexed with an exclusive end. ctx.bounds.start_col is 1-indexed.
function M:get_completions(ctx, callback)
  local words = store.get_words(0)
  if #words == 0 then
    callback({
      items = {},
      is_incomplete_forward = false,
      is_incomplete_backward = false,
    })
    return
  end

  local line = ctx.cursor[1] - 1
  local start = ctx.bounds.start_col - 1
  local finish = ctx.cursor[2]
  local range = {
    start = { line = line, character = start },
    ["end"] = { line = line, character = finish },
  }

  local items = {}
  for _, w in ipairs(words) do
    table.insert(items, {
      label = w,
      kind = Kind.Value,
      textEdit = {
        newText = w,
        range = range,
      },
      insertTextFormat = InsertTextFormat.PlainText,
    })
  end

  callback({
    items = items,
    is_incomplete_forward = false,
    is_incomplete_backward = false,
  })
end

return M
