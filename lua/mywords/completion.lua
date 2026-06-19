local store = require("mywords.store")

local M = {}

------------------------------
-- nvim-cmp source
------------------------------
local cmp_source = {}
cmp_source.__index = cmp_source

function cmp_source:new()
  local s = setmetatable({}, cmp_source)
  s.schema = {
    name = "mywords",
    keyword_length = 2,
  }
  return s
end

function cmp_source:is_available()
  return vim.api.nvim_get_option_value("buftype", { buf = 0 }) ~= "nofile"
end

function cmp_source:get_trigger_characters()
  return { " " }
end

function cmp_source:get_keyword_pattern()
  return [[\k\+]]
end

function cmp_source:complete(params, callback)
  local words = store.get_words(0)
  if #words == 0 then
    callback({})
    return
  end

  local prefix = params.context.cursor_text
  local items = {}

  for _, w in ipairs(words) do
    if w:sub(1, #prefix) == prefix or w:lower():sub(1, #prefix) == prefix:lower() then
      table.insert(items, {
        label = w,
        kind = require("cmp").lsp.CompletionItemKind.Value,
        word = w,
      })
    end
  end

  callback({
    items = items,
    isIncomplete = false,
  })
end

------------------------------
-- completion-list backend
------------------------------
local nvim_completer = {}

function nvim_completer.setup()
  vim.api.nvim_create_autocmd("CompleteChanged", {
    callback = function()
      local line = vim.api.nvim_get_current_line()
      local cursor_col = vim.api.nvim_win_get_cursor(0)[2]
      local prefix = line:sub(1, cursor_col):match("%w*$") or ""

      if #prefix < 2 then return end

      local words = store.get_words(0)
      local matches = {}
      for _, w in ipairs(words) do
        if w:sub(1, #prefix) == prefix or w:lower():sub(1, #prefix) == prefix:lower() then
          table.insert(matches, w)
        end
      end

      if #matches > 0 then
        vim.fn.complete(vim.fn.col("."), matches)
      end
    end,
  })
end

------------------------------
-- Public API
------------------------------
M.setup = function(backend)
  if backend == "cmp" then
    M.source = cmp_source:new()
    return
  end

  if backend == "nvim" then
    nvim_completer.setup()
    return
  end

  local has_cmp, _ = pcall(require, "cmp")
  if has_cmp then
    M.source = cmp_source:new()
  else
    nvim_completer.setup()
  end
end

M.get_source = function()
  return cmp_source:new()
end

return M
