local store = require("mywords.store")

local M = {}

M.open = function(opts, bufnr)
  opts = opts or {}
  bufnr = bufnr or 0
  local words = store.get_words(bufnr)

  if #words == 0 then
    vim.notify("No words in dictionary", vim.log.INFO)
    return
  end

  if opts.query and opts.query ~= "" then
    words = store.search(opts.query, bufnr)
    if #words == 0 then
      vim.notify("No matches found", vim.log.INFO)
      return
    end
  end

  M._open_picker(words, bufnr)
end

M._open_picker = function(words, bufnr)
  local ok, fzf_lua = pcall(require, "fzf-lua")
  if ok then
    M._fzf_picker(words, bufnr)
  else
    M._ui_select_picker(words, bufnr)
  end
end

M._fzf_picker = function(words, bufnr)
  local fzf_lua = require("fzf-lua")

  local delete_action = function(selected, fzf_opts)
    if #selected == 0 then return end
    local word = selected[1]
    if type(word) == "table" then
      word = word[1]
    end
    if word then
      local result = store.delete(tostring(word), bufnr)
      if result then
        vim.notify("Deleted: " .. word, vim.log.INFO)
      end
      fzf_opts.exit()
    end
  end

  fzf_lua.fzf_exec(words, {
    prompt = "MyWords >",
    fzf_opts = { "--multi" = false },
    actions = {
      ["Default"] = function(selected) end,
      ["Ctrl-d"] = delete_action,
    },
  })
end

M._ui_select_picker = function(words, bufnr)
  table.sort(words)
  vim.ui.select(words, {
    prompt = "MyWords: Search",
  }, function(choice)
    -- Selection returned but no action needed beyond display
  end)
end

return M
