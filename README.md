## Local development:

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
      {"<leader>Fg", function() require("telescope").extensions.inflect.ripgrep() end }
    }
  end 
}
```


