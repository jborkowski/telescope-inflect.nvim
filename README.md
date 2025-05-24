
# telescope-inflect.nvim

A Telescope extension that provides a two-layer filtering approach for ripgrep searches, inspired by Emacs' consult-grep + orderless functionality.

## Features

- **Two-layer filtering**: First filter with ripgrep, then refine results with FZY
- **Orderless-style searching**: Search for multiple terms in any order
- **PCRE2 support**: Optimized searching when ripgrep is compiled with PCRE2
- **Project-aware**: Automatically detects and searches within your project root
- **Syntax flexibility**: Multiple input syntaxes to separate ripgrep pattern from FZY filter

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "jborkowski/telescope-inflect.nvim",
  dependencies = {
    "nvim-telescope/telescope.nvim",
  },
  config = function()
    require("telescope").load_extension("inflect")
  end,
}
```

## Usage

### Basic Usage

```lua
-- Search with telescope-inflect
require("telescope").extensions.inflect.ripgrep()

-- Or map it to a key
vim.keymap.set("n", "<leader>fg", function() 
  require("telescope").extensions.inflect.ripgrep() 
end, { desc = "Inflect Ripgrep" })
```

### Input Syntax

telescope-inflect supports several input syntaxes:

1. **Standard search**: Just type your search terms
   ```
   search terms
   ```
   This performs a ripgrep search for "search terms" with smart-case.

2. **Slash syntax**: Use `/pattern/filter` to separate ripgrep pattern from FZY filter
   ```
   /ripgrep pattern/fzy filter
   ```
   This searches with ripgrep for "ripgrep pattern", then filters the results with FZY using "fzy filter".

3. **Hash syntax**: Use `#pattern#filter` as an alternative to slash syntax
   ```
   #ripgrep pattern#fzy filter
   ```
   Same as slash syntax but useful when searching for paths with slashes.

4. **Hash-only syntax**: Use `#pattern` for literal searches
   ```
   #exact pattern
   ```
   This performs a literal search for "exact pattern".

5. **Advanced ripgrep options**: Add `--` followed by ripgrep options
   ```
   search terms -- -g *.lua -i
   ```
   This passes additional options to ripgrep (in this case, only search Lua files and use case-insensitive search).

### Orderless-style Searching

One of the key features is the ability to search for multiple terms in any order:

```
function telescope extension
```

This will find matches containing all three terms ("function", "telescope", and "extension") in any order, similar to Emacs' orderless package.

When ripgrep is compiled with PCRE2 support, this is optimized into a single efficient regex. Otherwise, it falls back to multiple pattern matching.

## Local Development

For local development, you can use this lazy.nvim configuration:

```lua 
return {
  dir = "~/sources/telescope-inflect.nvim/",
  name = "telescope-inflect",
  config = function()
    require("telescope").load_extension("inflect")
  end,
  dev = true,
  keys = function() 
    return {
      { "<leader>fg", function() require("telescope").extensions.inflect.ripgrep() end }
    }
  end 
}
```

## How It Works

telescope-inflect uses a two-layer approach to filtering:

1. **First layer**: ripgrep performs the initial search, which is fast and efficient for searching through large codebases
2. **Second layer**: FZY algorithm filters and sorts the results from ripgrep

This approach combines the speed of ripgrep with the flexibility of fuzzy matching, providing a powerful and efficient search experience.

## Advantages over Telescope's live_grep

- Two-layer filtering approach: ripgrep for initial search + FZY for refined filtering
- Support for orderless-style searching (terms in any order)
- More flexible search syntax with multiple input options
- Ability to pass additional ripgrep options on-the-fly (e.g., filtering by file extensions or including hidden files)

