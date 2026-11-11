-- Run from the repo root: nvim -l tests/run.lua
local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local store = require("mywords.store")

local passed, failed = 0, 0
local function check(name, cond)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    io.stderr:write("FAIL: " .. name .. "\n")
  end
end

-- Creates a temp global dir and a temp project root (with a .git marker file).
local function fresh_env(name)
  local dir = vim.fn.tempname() .. "/" .. name
  vim.fn.mkdir(dir, "p")
  local proj = dir .. "/proj"
  vim.fn.mkdir(proj, "p")
  vim.fn.writefile({}, proj .. "/.git")
  return dir, proj
end

-- Names buffer 0 inside the project, then (re)initializes the store.
local function init_store(dir, proj_file)
  vim.api.nvim_buf_set_name(0, proj_file)
  store.init({
    dir = dir,
    global_file = "global.json",
    project_file = ".mywords.json",
    project_root_patterns = { ".git" },
  })
end

-- Task 1: store.has
do
  local dir, proj = fresh_env("has")
  init_store(dir, proj .. "/main.lua")

  store.add("alpha", "project", 0)
  store.add("beta", "global", 0)

  check("has: project word", store.has("alpha", 0) == true)
  check("has: global word", store.has("beta", 0) == true)
  check("has: unknown word", store.has("gamma", 0) == false)
  check("has: trims input", store.has("  alpha  ", 0) == true)
  check("has: empty is false", store.has("   ", 0) == false)
end

-- Task 2: project path cache
do
  local dirA = vim.fn.tempname() .. "/cacheA"
  local dirB = vim.fn.tempname() .. "/cacheB"
  local projA = dirA .. "/projA"
  local projB = dirB .. "/projB"
  vim.fn.mkdir(projA, "p")
  vim.fn.mkdir(projB, "p")
  vim.fn.writefile({}, projA .. "/.git")
  vim.fn.writefile({}, projB .. "/.git")

  init_store(dirA, projA .. "/main.lua")
  check("cache: add wordA to project A", store.add("wordA", "project", 0) == true)

  vim.api.nvim_buf_set_name(0, projB .. "/main.lua")
  check("cache: add wordB to project B", store.add("wordB", "project", 0) == true)

  local function readf(p)
    local f = io.open(p, "r")
    if not f then return "{}" end
    local c = f:read("*a")
    f:close()
    return c
  end
  local fileA = readf(projA .. "/.mywords.json")
  local fileB = readf(projB .. "/.mywords.json")
  check("cache: wordA in A file", fileA:find("wordA") ~= nil)
  check("cache: wordB in B file", fileB:find("wordB") ~= nil)
  check("cache: A file untouched by B write", fileA:find("wordB") == nil)
  check("cache: B file has no A word", fileB:find("wordA") == nil)
end

-- Task 3: get_words_with_scope
do
  local dir, proj = fresh_env("scope")
  init_store(dir, proj .. "/main.lua")

  store.add("pword", "project", 0)
  store.add("gword", "global", 0)
  store.add("both", "global", 0)
  store.add("both", "project", 0)

  local entries = store.get_words_with_scope(0)
  local by_word = {}
  for _, e in ipairs(entries) do
    by_word[e.word] = e.scope
  end
  check("scope: project word tagged", by_word["pword"] == "project")
  check("scope: global word tagged", by_word["gword"] == "global")
  check("scope: duplicate deduped to project", by_word["both"] == "project")
  check("scope: first entry is project scope", entries[1].scope == "project")
  check("scope: count is 3", #entries == 3)
end

-- Task 4: rename
do
  local dir, proj = fresh_env("rename")
  init_store(dir, proj .. "/main.lua")

  store.add("oldname", "project", 0)
  store.add("gname", "global", 0)

  check("rename: project scope", store.rename("oldname", "newname", 0) == true)
  check("rename: old name gone", store.has("oldname", 0) == false)
  check("rename: new name present", store.has("newname", 0) == true)

  local f = io.open(proj .. "/.mywords.json", "r")
  local pf = f and f:read("*a") or ""
  if f then f:close() end
  check("rename: persisted to project file", pf:find("newname") ~= nil)

  check("rename: global scope", store.rename("gname", "gname2", 0) == true)
  check("rename: not found returns false", store.rename("nope", "x", 0) == false)

  store.add("taken", "global", 0)
  check("rename: to existing name fails", store.rename("gname2", "taken", 0) == false)
end

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
  vim.cmd("cquit")
end
