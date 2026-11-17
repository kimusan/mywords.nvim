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
-- Detect blink.cmp without loading it. require("blink.cmp") would force-load a
-- lazy-loaded plugin (and run its autocmds/keymaps) just for a presence check.
local function has_blink_cmp()
  return #vim.api.nvim_get_runtime_file("lua/blink/cmp/init.lua", true) > 0
end

M.setup = function(backend)
  if backend == "cmp" then
    M.source = cmp_source:new()
    return
  end

  if backend == "nvim" then
    nvim_completer.setup()
    return
  end

  -- blink.cmp: the source is declared in the user's own blink.cmp config
  -- (sources.providers.mywords.module = "mywords.source.blink"), which mywords
  -- can't reach at setup time, so there is nothing to install. We must also not
  -- fall through to the built-in completion-list, which would render a second
  -- menu under blink.cmp. Hence a bare return in both blink branches.
  if backend == "blink" then
    return
  end

  -- "auto": detect blink.cmp before nvim-cmp so a blink user never gets the
  -- built-in completion-list (a competing menu).
  if has_blink_cmp() then
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
