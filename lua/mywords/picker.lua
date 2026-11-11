local store = require("mywords.store")

local M = {}

local function first_selected(selected)
  if type(selected) ~= "table" or #selected == 0 then
    return nil
  end
  local entry = selected[1]
  if type(entry) == "table" then
    entry = entry[1]
  end
  return entry
end

local function split_row(line)
  if type(line) ~= "string" then
    return nil, nil
  end
  return line:match("^(.-)\t(.*)$")
end

local function insert_at_cursor(word, target)
  if not word then return end
  vim.api.nvim_set_current_buf(target.bufnr)
  vim.api.nvim_win_set_cursor(0, target.pos)
  vim.api.nvim_put({ word }, "l", false, true)
end

local function fzf_picker(entries, bufnr, target)
  local lines = {}
  for _, e in ipairs(entries) do
    table.insert(lines, e.word .. "\t" .. e.scope)
  end

  local actions = {
    ["Default"] = function(selected)
      local word = split_row(first_selected(selected))
      insert_at_cursor(word, target)
    end,
    ["ctrl-d"] = function(selected)
      local word = split_row(first_selected(selected))
      if not word then return end
      if store.delete(word, bufnr) then
        vim.notify("Deleted: " .. word, vim.log.INFO)
      else
        vim.notify("Word not found: " .. word, vim.log.WARN)
      end
    end,
    ["alt-m"] = function(selected)
      local word, scope = split_row(first_selected(selected))
      if not word then return end
      local target_scope = (scope == "project") and "global" or "project"
      if store.move(word, target_scope, bufnr) then
        vim.notify("Moved " .. word .. " to " .. target_scope, vim.log.INFO)
      else
        vim.notify("Cannot move " .. word .. " to " .. target_scope, vim.log.WARN)
      end
    end,
    ["alt-r"] = function(selected)
      local word = split_row(first_selected(selected))
      if not word then return end
      local new_word = vim.fn.input("Rename '" .. word .. "' to: ", word)
      if new_word ~= "" and new_word ~= word then
        if store.rename(word, new_word, bufnr) then
          vim.notify("Renamed " .. word .. " to " .. new_word, vim.log.INFO)
        else
          vim.notify("Rename failed for: " .. word, vim.log.WARN)
        end
      end
    end,
  }

  require("fzf-lua").fzf_exec(lines, {
    prompt = "MyWords > ",
    fzf_opts = { ["--delimiter"] = "\t", ["--with-nth"] = "1" },
    actions = actions,
  })
end

local function ui_select_picker(entries, bufnr, target)
  local words = {}
  for _, e in ipairs(entries) do
    table.insert(words, e.word)
  end
  table.sort(words)
  vim.ui.select(words, {
    prompt = "MyWords: select to insert at cursor",
  }, function(choice)
    if choice then
      insert_at_cursor(choice, target)
    end
  end)
end

M.open = function(opts, bufnr)
  opts = opts or {}
  bufnr = bufnr or 0
  local entries = store.get_words_with_scope(bufnr)

  if #entries == 0 then
    vim.notify("No words in dictionary", vim.log.INFO)
    return
  end

  if opts.query and opts.query ~= "" then
    local q = opts.query:lower()
    local filtered = {}
    for _, e in ipairs(entries) do
      if e.word:lower():find(q, 1, true) then
        table.insert(filtered, e)
      end
    end
    entries = filtered
    if #entries == 0 then
      vim.notify("No matches found", vim.log.INFO)
      return
    end
  end

  local target = {
    bufnr = vim.api.nvim_get_current_buf(),
    pos = vim.api.nvim_win_get_cursor(0),
  }

  local ok = pcall(require, "fzf-lua")
  if ok then
    fzf_picker(entries, bufnr, target)
  else
    ui_select_picker(entries, bufnr, target)
  end
end

return M
