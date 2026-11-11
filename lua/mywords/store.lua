local M = {}

local config = {}
local global_words = {}
local project_words = {}
local project_file_path = nil
local project_root = nil

M.find_project_root = function(bufnr)
  bufnr = bufnr or 0
  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == "" or not path then return nil end

  local dir = vim.fs.dirname(path)
  local root = vim.fs.root(dir, config.project_root_patterns)
  return root
end

local function read_json_file(path)
  if not path then return {} end
  local f = io.open(path, "r")
  if not f then return {} end
  local content = f:read("*all")
  f:close()
  if not content or content:gsub("%s", "") == "" then return {} end
  local ok, data = pcall(vim.json.decode, content)
  if ok and type(data) == "table" and #data > 0 then
    return data
  end
  return {}
end

M.get_project_file_path = function(bufnr)
  local root = M.find_project_root(bufnr)
  if not root then
    if project_root ~= nil then
      project_root = nil
      project_file_path = nil
      project_words = {}
    end
    return nil
  end
  if project_root ~= root then
    project_root = root
    project_file_path = vim.fs.joinpath(root, config.project_file)
    project_words = read_json_file(project_file_path)
  end
  return project_file_path
end

local function write_json_file(path, data)
  local dir = vim.fs.dirname(path)
  if dir and not vim.loop.fs_stat(dir) then
    vim.fn.mkdir(dir, "p")
  end
  local f = io.open(path, "w")
  if not f then return false end
  f:write(vim.json.encode(data))
  f:close()
  return true
end

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

M.load_global = function()
  local path = vim.fs.joinpath(config.dir, config.global_file)
  global_words = read_json_file(path)
  return global_words
end

M.load_project = function(bufnr)
  local path = M.get_project_file_path(bufnr)
  if not path then
    project_words = {}
    return project_words
  end
  project_words = read_json_file(path)
  return project_words
end

M.reload = function(bufnr)
  project_file_path = nil
  project_root = nil
  M.load_global()
  M.load_project(bufnr)
end

M.add = function(word, scope, bufnr)
  word = word:gsub("^%s+", ""):gsub("%s+$", "")
  if word == "" then return false end

  if scope == "global" then
    for _, w in ipairs(global_words) do
      if w == word then return true end
    end
    table.insert(global_words, word)
    local path = vim.fs.joinpath(config.dir, config.global_file)
    return write_json_file(path, global_words)
  end

  if scope == "project" then
    local path = M.get_project_file_path(bufnr)
    if not path then
      return false
    end
    for _, w in ipairs(project_words) do
      if w == word then return true end
    end
    table.insert(project_words, word)
    return write_json_file(path, project_words)
  end

  local path = M.get_project_file_path(bufnr)
  if not path then
    return M.add(word, "global", bufnr)
  end

  for _, w in ipairs(project_words) do
    if w == word then return true end
  end
  table.insert(project_words, word)
  return write_json_file(path, project_words)
end

M.delete = function(word, bufnr)
  word = word:gsub("^%s+", ""):gsub("%s+$", "")
  if word == "" then return false end

  for i, w in ipairs(project_words) do
    if w == word then
      table.remove(project_words, i)
      local path = M.get_project_file_path(bufnr)
      if path then
        write_json_file(path, project_words)
      end
      return true
    end
  end

  for i, w in ipairs(global_words) do
    if w == word then
      table.remove(global_words, i)
      local path = vim.fs.joinpath(config.dir, config.global_file)
      write_json_file(path, global_words)
      return true
    end
  end

  return false
end

M.has = function(word, bufnr)
  word = trim(word)
  if word == "" then return false end
  for _, w in ipairs(project_words) do
    if w == word then return true end
  end
  for _, w in ipairs(global_words) do
    if w == word then return true end
  end
  return false
end

M.rename = function(word, new_word, bufnr)
  word = trim(word)
  new_word = trim(new_word)
  if word == "" or new_word == "" then return false end
  if new_word ~= word and M.has(new_word, bufnr) then return false end

  for i, w in ipairs(project_words) do
    if w == word then
      project_words[i] = new_word
      local path = M.get_project_file_path(bufnr)
      if path then
        write_json_file(path, project_words)
      end
      return true
    end
  end

  for i, w in ipairs(global_words) do
    if w == word then
      global_words[i] = new_word
      local path = vim.fs.joinpath(config.dir, config.global_file)
      write_json_file(path, global_words)
      return true
    end
  end

  return false
end

M.move = function(word, target_scope, bufnr)
  word = trim(word)
  if word == "" then return false end
  if target_scope ~= "global" and target_scope ~= "project" then return false end
  if not M.has(word, bufnr) then return false end
  if target_scope == "project" and not M.get_project_file_path(bufnr) then return false end

  for i = #project_words, 1, -1 do
    if project_words[i] == word then
      table.remove(project_words, i)
    end
  end
  for i = #global_words, 1, -1 do
    if global_words[i] == word then
      table.remove(global_words, i)
    end
  end

  if target_scope == "project" then
    table.insert(project_words, word)
    write_json_file(M.get_project_file_path(bufnr), project_words)
  else
    table.insert(global_words, word)
    write_json_file(vim.fs.joinpath(config.dir, config.global_file), global_words)
  end
  return true
end

M.get_words = function(bufnr)
  local seen = {}
  local result = {}
  for _, w in ipairs(project_words) do
    if not seen[w] then
      seen[w] = true
      table.insert(result, w)
    end
  end
  for _, w in ipairs(global_words) do
    if not seen[w] then
      seen[w] = true
      table.insert(result, w)
    end
  end
  return result
end

M.get_words_with_scope = function(bufnr)
  local seen = {}
  local result = {}
  for _, w in ipairs(project_words) do
    if not seen[w] then
      seen[w] = true
      table.insert(result, { word = w, scope = "project" })
    end
  end
  for _, w in ipairs(global_words) do
    if not seen[w] then
      seen[w] = true
      table.insert(result, { word = w, scope = "global" })
    end
  end
  return result
end

M.get_words_by_scope = function(bufnr)
  return {
    global = vim.deepcopy(global_words),
    project = vim.deepcopy(project_words),
  }
end

M.search = function(query, bufnr)
  if not query or query == "" then return M.get_words(bufnr) end
  query = query:lower()
  local results = {}
  local words = M.get_words(bufnr)
  for _, w in ipairs(words) do
    if w:lower():find(query, 1, true) then
      table.insert(results, w)
    end
  end
  return results
end

M.init = function(cfg)
  config = cfg or {}
  if not vim.loop.fs_stat(config.dir) then
    vim.fn.mkdir(config.dir, "p")
  end
  M.load_global()
  M.load_project(0)
end

return M
