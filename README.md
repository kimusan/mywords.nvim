# mywords.nvim

Personal dictionary plugin for Neovim. Add special words to a global or per-project dictionary and get autocomplete support.

## Features

- Global and per-project word storage
- Add/delete words from the current buffer or via picker
- Fuzzy search with fzf-lua (falls back to vim.ui.select)
- nvim-cmp and built-in completion-list support
- JSON file storage, no external dependencies beyond Neovim

## Installation

### lazy.nvim
```lua
{ "mywords/mywords.nvim" }
```

## Setup

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
})
```

### Keybindings

No defaults. Wire them up yourself:

```lua
vim.keymap.set("n", "<leader>ma", function()
  require("mywords").add()
end, { desc = "Add word to dictionary" })

vim.keymap.set("n", "<leader>md", function()
  require("mywords").delete()
end, { desc = "Delete word from dictionary" })

vim.keymap.set("n", "<leader>ms", function()
  require("mywords").search()
end, { desc = "Search dictionary" })
```

### nvim-cmp

```lua
require("cmp").setup({
  sources = { { name = "mywords" } },
})
```

Or register it manually:

```lua
require("cmp").setup({
  sources = {
    { name = "mywords", source = require("mywords").get_source() },
  },
})
```

## Usage

- **Add word**: Place cursor on a word and trigger `add()`, or call `add("myword")` directly. If no word is under cursor, you'll be prompted for input.
- **Add to global scope**: `require("mywords").add("word", "global")`
- **Add to project scope**: `require("mywords").add("word", "project")`
- **Delete word**: Place cursor on a word and trigger `delete()`, or call `delete("myword")`
- **Search**: `require("mywords").search()` opens a picker. `require("mywords").search("lorem")` pre-filters.
- **Delete from picker**: Press `<C-d>` in fzf-lua picker to delete the selected word.
- **List words**: `require("mywords").list()` returns all merged words.
- **Reload**: `require("mywords").reload()` re-reads dictionary files from disk.

## Dictionary Storage

- **Global**: `~/.local/share/nvim/mywords/global.json`
- **Project**: `.mywords.json` in the detected project root (nearest parent with `.git` or `.neoconf.json`)

Words are stored as simple JSON arrays. Edit them directly if you prefer.

## License

Released under the MIT license.

## Credit

Created by Kim Schulz <kim@schulz.dk>
