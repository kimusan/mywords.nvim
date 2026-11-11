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

This registers default keybindings (`<leader>ma`, `<leader>md`, `<leader>ms`, and `<C-s>` in insert mode) and enables completion with auto-detected backend.

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
    add_insert = "<C-s>",  -- insert mode: add current word or the selected completion item
  },
})
```

Note: the default `<C-s>` overrides Neovim's built-in LSP signature-help key in insert mode; set `add_insert = ""` or a different key to change it.

Disable default keybindings by passing empty strings:

```lua
keys = { add = "", delete = "", search = "", add_insert = "" },
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

### Saving from the completion menu

While a completion menu is open (nvim-cmp or built-in), press `<C-s>` to save the
currently highlighted item to the dictionary. Without an open menu it saves the word
under the cursor. This works because the menu is read through `vim.fn.complete_info()`.

### Deleting words

1. Place cursor on a word and press `<leader>md`
2. Or search for it: `<leader>ms`, select it, press `<C-d>` (fzf-lua only)
3. Or call directly: `require("mywords").delete("loremipsum")`

### Browsing and managing the dictionary

Press `<leader>ms` to open the picker. Each row shows the word and its scope
(`project` or `global`). Typing filters the list.

| Key    | Action                                                        |
|--------|---------------------------------------------------------------|
| Enter  | Insert the word at your previous cursor position              |
| Ctrl-d | Delete the word                                               |
| Alt-m  | Move the word between project and global scope                |
| Alt-r  | Rename the word                                               |

Delete, move, and rename are fzf-lua only. Without fzf-lua the picker falls back to
`vim.ui.select` with Enter-to-insert.

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

## Manual Test Checklist

The store and command layer are covered by `tests/run.lua` (run with
`nvim -l tests/run.lua` from the repo root). Picker and completion-menu flows need a
live UI:

- [ ] `<leader>ma` adds the word under the cursor
- [ ] `<leader>md` deletes the word under the cursor
- [ ] `<C-s>` with an open completion menu saves the highlighted item
- [ ] Picker: Enter inserts, Ctrl-d deletes, Alt-m moves scope, Alt-r renames

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
