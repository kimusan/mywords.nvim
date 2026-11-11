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

-- Task 5: move
do
  local dir, proj = fresh_env("move")
  init_store(dir, proj .. "/main.lua")

  store.add("mover", "project", 0)
  check("move: project to global", store.move("mover", "global", 0) == true)

  local scoped = store.get_words_by_scope(0)
  check("move: gone from project", #scoped.project == 0)
  check("move: in global", vim.tbl_contains(scoped.global, "mover") == true)

  local function readf(p)
    local f = io.open(p, "r")
    if not f then return "{}" end
    local c = f:read("*a")
    f:close()
    return c
  end
  check("move: project file no longer has word", readf(proj .. "/.mywords.json"):find("mover") == nil)
  check("move: global file has word", readf(dir .. "/global.json"):find("mover") ~= nil)

  check("move: global to project", store.move("mover", "project", 0) == true)
  scoped = store.get_words_by_scope(0)
  check("move: back in project", vim.tbl_contains(scoped.project, "mover") == true)

  check("move: project file has word again", readf(proj .. "/.mywords.json"):find("mover") ~= nil)
  check("move: global file no longer has word", readf(dir .. "/global.json"):find("mover") == nil)

  check("move: not found returns false", store.move("ghost", "global", 0) == false)
  check("move: invalid scope returns false", store.move("mover", "nowhere", 0) == false)
end

-- Task 5b: move to project without a project file
do
  local dir = vim.fn.tempname() .. "/movenoproj"
  vim.fn.mkdir(dir, "p")
  vim.api.nvim_buf_set_name(0, "")
  store.init({
    dir = dir,
    global_file = "global.json",
    project_file = ".mywords.json",
    project_root_patterns = { ".git" },
  })

  store.add("loner", "global", 0)
  check("move: to project without file fails", store.move("loner", "project", 0) == false)
  check("move: word still in global", store.has("loner", 0) == true)
end

-- Task 6: init.lua
do
  local dir, proj = fresh_env("init")
  init_store(dir, proj .. "/main.lua")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "hello world" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })

  local mywords = require("mywords")
  mywords.setup({ dir = dir })

  local msgs = {}
  local orig_notify = vim.notify
  vim.notify = function(msg, ...)
    msgs[#msgs + 1] = msg
  end
  local function saw(msg_part)
    for _, m in ipairs(msgs) do
      if m:find(msg_part, 1, true) then return true end
    end
    return false
  end

  mywords.add(nil)
  check("init: add word under cursor", saw("Added: hello"))

  msgs = {}
  mywords.add(nil)
  check("init: duplicate reported as existing", saw("already exists"))

  local ok_del = pcall(mywords.delete, nil)
  check("init: delete under cursor does not error", ok_del)
  check("init: word deleted", store.has("hello", 0) == false)

  vim.api.nvim_win_set_cursor(0, { 1, 6 })
  local ok_ac = pcall(mywords.add_current)
  check("init: add_current does not error", ok_ac)
  check("init: add_current uses word under cursor without pum", store.has("world", 0) == true)

  vim.notify = orig_notify

  mywords.setup({ dir = dir, keys = { add_insert = "<M-q>" } })
  check("init: insert mode key registered", vim.fn.maparg("<M-q>", "i") ~= "")
  check("init: add key registered", vim.fn.maparg("<leader>ma", "n") ~= "")
end

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
  vim.cmd("cquit")
end
