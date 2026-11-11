local store = require("mywords.store")
local picker = require("mywords.picker")
local completion = require("mywords.completion")

local M = {}
local _config = nil

M.setup = function(opts)
  opts = opts or {}

  _config = {
    dir = opts.dir or vim.fn.stdpath("data") .. "/mywords",
    global_file = opts.global_file or "global.json",
    project_file = opts.project_file or ".mywords.json",
    project_root_patterns = opts.project_root_patterns or { ".git", ".neoconf.json" },
    completion = opts.completion or { enabled = true },
  }

  store.init(_config)

  if _config.completion.enabled then
    local backend = _config.completion.backend or "auto"
    completion.setup(backend)
  end

  local keys = vim.tbl_deep_extend("force", {
    add = "<leader>ma",
    delete = "<leader>md",
    search = "<leader>ms",
    add_insert = "<C-s>",
  }, _config.keys or {})

  vim.keymap.set("n", keys.add, function()
    M.add()
  end, { desc = "MyWords: Add word" })

  vim.keymap.set("n", keys.delete, function()
    M.delete()
  end, { desc = "MyWords: Delete word" })

  vim.keymap.set("n", keys.search, function()
    M.search()
  end, { desc = "MyWords: Search words" })

  if keys.add_insert ~= "" then
    vim.keymap.set("i", keys.add_insert, function()
      M.add_current()
    end, { desc = "MyWords: Add current word or completion" })
  end

  return M
end

M.add = function(word, scope)
  if not word then
    word = vim.fn.expand("<cWORD>")
    if word == "" then
      vim.ui.input({ prompt = "Word: " }, function(input)
        if input and input ~= "" then
          M.add(input, scope)
        end
      end)
      return
    end
  end

  if store.has(word, 0) then
    vim.notify("Word already exists: " .. word, vim.log.INFO)
    return
  end

  store.add(word, scope, 0)
  vim.notify("Added: " .. word, vim.log.INFO)
end

M.add_current = function()
  local word = nil
  if vim.fn.pumvisible() == 1 then
    local info = vim.fn.complete_info()
    local sel = info and info.selected or -1
    if sel >= 0 and info.items and info.items[sel + 1] then
      word = info.items[sel + 1].word
    end
  end
  if not word then
    word = vim.fn.expand("<cWORD>")
  end
  M.add(word)
end

M.delete = function(word)
  if not word then
    word = vim.fn.expand("<cWORD>")
    if word == "" then
      vim.notify("No word under cursor", vim.log.WARN)
      return
    end
  end

  if store.delete(word, 0) then
    vim.notify("Deleted: " .. word, vim.log.INFO)
  else
    vim.notify("Word not found: " .. word, vim.log.WARN)
  end
end

M.search = function(query)
  if not query then
    picker.open({})
    return
  end
  picker.open({ query = query })
end

M.list = function()
  return store.get_words(0)
end

M.get_words = function()
  return store.get_words(0)
end

M.get_words_by_scope = function()
  return store.get_words_by_scope(0)
end

M.reload = function()
  store.reload(0)
  vim.notify("Dictionary reloaded", vim.log.INFO)
end

M.get_source = function()
  return completion.get_source()
end

return M
