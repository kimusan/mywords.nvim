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

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
  vim.cmd("cquit")
end
