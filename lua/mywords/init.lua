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
    keys = opts.keys or {},
  }

  store.init(_config)

  if _config.completion.enabled then
    local backend = _config.completion.backend or "auto"
    completion.setup(backend)
  end

  -- vim.keymap.set expands <leader> at set-time, so a binding written as
  -- "<leader>ma" sticks to whatever mapleader is when setup() runs. Users who
  -- set mapleader = " " after loading the plugin (very common) would press
  -- <space>ma and hit nothing, with no add and no notification. Bind the
  -- expanded raw key, and re-apply when the leader changes (BufReadPost fires
  -- on every buffer load, which catches a leader set in a file read after setup).
  local default_keys = {
    { mode = "n", lhs = "<leader>ma", rhs = function() M.add() end, desc = "MyWords: Add word" },
    { mode = "n", lhs = "<leader>md", rhs = function() M.delete() end, desc = "MyWords: Delete word" },
    { mode = "n", lhs = "<leader>ms", rhs = function() M.search() end, desc = "MyWords: Search words" },
    { mode = "i", lhs = "<C-s>", rhs = function() M.add_current() end, desc = "MyWords: Add current word or completion" },
  }
  local keys = vim.tbl_deep_extend("force", {
    add = "<leader>ma",
    delete = "<leader>md",
    search = "<leader>ms",
    add_insert = "<C-s>",
  }, _config.keys or {})

  local applied = {}
  local applied_leader = nil

  local function leader_sig()
    return (vim.g.mapleader or "\\") .. "|" .. (vim.g.maplocalleader or "\\")
  end

  local function expand_leader(lhs)
    return lhs
      :gsub("<leader>", function()
        return vim.g.mapleader or "\\"
      end)
      :gsub("<LocalLeader>", function()
        return vim.g.maplocalleader or "\\"
      end)
  end

  local function apply_keymaps()
    for _, m in ipairs(applied) do
      pcall(vim.keymap.del, m.mode, m.lhs)
    end
    applied = {}
    applied_leader = leader_sig()

    local entries = vim.deepcopy(default_keys)
    entries[1].lhs = keys.add
    entries[2].lhs = keys.delete
    entries[3].lhs = keys.search
    entries[4].lhs = keys.add_insert

    for _, e in ipairs(entries) do
      if e.lhs ~= "" then
        local lhs = expand_leader(e.lhs)
        vim.keymap.set(e.mode, lhs, e.rhs, { desc = e.desc })
        table.insert(applied, { mode = e.mode, lhs = lhs })
      end
    end
  end

  apply_keymaps()
  vim.api.nvim_create_autocmd("BufReadPost", {
    group = vim.api.nvim_create_augroup("mywords", {}),
    callback = function()
      if applied_leader ~= leader_sig() then
        apply_keymaps()
      end
    end,
  })

  return M
end

M.add = function(word, scope)
  if not word then
    local ok_expand, w = pcall(vim.fn.expand, "<cWORD>")
    word = ok_expand and w or ""
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

  if store.add(word, scope, 0) then
    vim.notify("Added: " .. word, vim.log.INFO)
  else
    vim.notify("Could not add: " .. word, vim.log.WARN)
  end
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
    local ok_expand, w = pcall(vim.fn.expand, "<cWORD>")
    word = ok_expand and w or ""
  end
  if word == "" then
    word = nil
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
