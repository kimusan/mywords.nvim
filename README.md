# mywords.nvim

Personal dictionary plugin for Neovim. Spell checkers and linters flag domain-specific words, internal acronyms, and project jargon as errors. Add these words to a global or per-project dictionary and they'll disappear from noise while showing up in autocomplete.

## Features

- **Global and per-project dictionaries** — shared words live in `~/.local/share/nvim/mywords`, project-specific words stay in `.mywords.json` at the project root. Both scopes are merged during completion.
- **Add words with one keypress** — put cursor on any word (including hyphenated ones like `SCSC-Bug-Id`) and press the add keybinding. If no word is under cursor, you're prompted for input.
- **Delete words** — from cursor, picker, or API call.
- **Fuzzy search** — browse and search all saved words via fzf-lua (with vim.ui.select fallback).
- **Autocomplete** — nvim-cmp source and built-in completion-list support. Triggers on 2+ characters.
- **JSON storage** — dictionaries are plain JSON arrays. Edit them by hand, version-control project dicts, sync globally.

## Installation

### lazy.nvim

```lua
{ "mywords/mywords.nvim" }
```

### Local development

```lua
{ "/home/kschulz/repo/github/mywords.nvim" }
```

## Setup

### Minimal

```lua
require("mywords").setup()
```

This registers default keybindings (`<leader>ma`, `<leader>md`, `<leader>ms>`) and enables completion with auto-detected backend.

### Full configuration

```lua
require("mywords").setup({
  -- Directory for global dictionary storage
  dir = vim.fn.stdpath("data") .. "/mywords",

  -- Filenames for dictionaries
  global_file = "global.json",
  project_file = ".mywords.json",

  -- Patterns used to detect project root
  project_root_patterns = { ".git", ".neoconf.json" },

  -- Completion settings
  completion = {
    enabled = true,
    -- "auto" (detect cmp), "cmp", or "nvim" (built-in completion-list)
    backend = "auto",
  },

  -- Keybindings (override defaults)
  keys = {
    add = "<leader>ma",    -- add word at cursor
    delete = "<leader>md", -- delete word at cursor
    search = "<leader>ms", -- search dictionary
  },
})
```

Disable default keybindings by passing empty strings:

```lua
keys = { add = "", delete = "", search = "" },
```

### nvim-cmp

The `mywords` source is auto-registered when `backend = "cmp"` or `"auto"`. Add it to your cmp sources:

```lua
require("cmp").setup({
  sources = { { name = "mywords" } },
})
```

If you manage cmp sources separately:

```lua
{
  name = "mywords",
  source = require("mywords").get_source(),
}
```

### LazyVim

In `lua/custom/plugins/mywords.lua`:

```lua
return {
  {
    "/home/kschulz/repo/github/mywords.nvim",
    lazy = false,
    opts = {
      completion = { backend = "cmp" },
    },
  },
  {
    "hrsh7th/nvim-cmp",
    opts = function(_, opts)
      table.insert(opts.sources, { name = "mywords" })
    end,
  },
}
```

## Usage

### Adding words

1. Place cursor on a word and press `<leader>ma`
2. Or call it directly: `require("mywords").add("loremipsum")`
3. Or force a scope: `require("mywords").add("word", "global")`

Words are added to the project dictionary if one exists, otherwise to global.

### Deleting words

1. Place cursor on a word and press `<leader>md`
2. Or search for it: `<leader>ms`, select it, press `<C-d>` (fzf-lua only)
3. Or call directly: `require("mywords").delete("loremipsum")`

### Browsing the dictionary

Press `<leader>ms` to open a picker with all saved words. Search filters the list. With fzf-lua, use `<C-d>` to delete the selected word without leaving the picker.

### Programmatic access

```lua
-- Get all words (merged, deduped)
local words = require("mywords").list()

-- Get words by scope
local scoped = require("mywords").get_words_by_scope()
print(scoped.global)  -- { "loremipsum", ... }
print(scoped.project) -- { "internal-api", ... }

-- Search manually
local results = require("mywords").store.search("lorem")

-- Reload after external edits
require("mywords").reload()
```

## Dictionary Storage

| Scope   | Location                                    |
|---------|---------------------------------------------|
| Global  | `~/.local/share/nvim/mywords/global.json`   |
| Project | `.mywords.json` in project root             |

Dictionary files are simple JSON arrays:

```json
["loremipsum", "SCSC-Bug-Id", "internal-api", "mycompany"]
```

Project dictionaries can be committed to version control so teammates share the same words.

## License

Released under the MIT license.

## Credit

Created by Kim Schulz <kim@schulz.dk>
