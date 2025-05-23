local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local make_entry = require('telescope.make_entry')


local function get_project_root()
  local ok_proj, project = pcall(require, "project_nvim.project")
  if ok_proj and project and project.get_project_root then
    return project.get_project_root()
  end

  local ok_telproj, telescope_project = pcall(require, "telescope._extensions.project")
  if ok_telproj and telescope_project and telescope_project.get_project_root then
    return telescope_project.get_project_root()
  end

  local vim = vim or require("vim")
  return vim.loop.cwd()
end

local function parse_input(input)
  local rg_part, filter = nil, nil
  local rg_opts = {}

  -- Case: /pattern/filter
  local is_slash_syntax = input:match("^/.*/")
  if is_slash_syntax then
    local raw_rg, raw_filter = input:match("^/(.-)/(.*)")
    rg_part = vim.trim(raw_rg or "")
    filter = vim.trim(raw_filter or "")
    if filter == "" then filter = nil end

    -- Case: #pattern#filter
  elseif input:match("^#.-#") then
    local raw_rg, raw_filter = input:match("^#(.-)#(.*)")
    rg_part = vim.trim(raw_rg or "")
    filter = vim.trim(raw_filter or "")
    if filter == "" then filter = nil end

    -- Case: #pattern
  elseif input:match("^#") then
    rg_part = vim.trim(input:sub(2))


    -- Fallback: plain
  else
    rg_part = vim.trim(input)
  end

  -- Parse rg options like: 'foo -- --smart-case --glob=*.lua'
  local main_pattern, opts = rg_part:match("^(.-)%s+%-%-%s+(.*)$")
  if main_pattern then
    rg_part = vim.trim(main_pattern)
    for opt in opts:gmatch("%-%-[^%s]+") do
      table.insert(rg_opts, opt)
    end
  end

  vim.notify(string.format("Parsed input: pattern='%s', options=%s, filter=%s",
    rg_part,
    vim.inspect(rg_opts),
    filter or "nil"
  ), vim.log.levels.INFO)

  return rg_part, rg_opts, filter
end

-- Split rg into individual expressions (space-separated, \-escaped)
local function split_regexps(rg_string)
  local regexps = {}
  local part = ""
  local escaping = false
  for i = 1, #rg_string do
    local c = rg_string:sub(i, i)
    if escaping then
      part = part .. c
      escaping = false
    elseif c == "\\" then
      escaping = true
    elseif c == " " then
      if part ~= "" then table.insert(regexps, part) end
      part = ""
    else
      part = part .. c
    end
  end
  if part ~= "" then table.insert(regexps, part) end
  return regexps
end

local function compile_orderless_from_parts(parts)
  local lookaheads = {}
  for _, word in ipairs(parts) do
    -- escape special characters
    word = word:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    table.insert(lookaheads, "(?=.*" .. word .. ")")
  end
  return table.concat(lookaheads, "")
end


local function rg_supports_pcre2()
  local handle = io.popen("rg --pcre2-version 2>&1")
  if not handle then return false end

  local result = handle:read("*a")
  handle:close()

  return not result:match("error") and not result:match("unknown flag")
end

local function async_rg_finder(prompt)
  if not prompt or #prompt < 3 then return nil end
  local search_dir = get_project_root()

  local rg_pattern, rg_opts, _ = parse_input(prompt)

  local command_builder = {
    "rg", "--vimgrep",
    "--line-buffered", "--color=never", "--max-columns=1000",
    "--path-separator", "/", "--smart-case",
    "--no-heading", "--with-filename", "--line-number", "--search-zip"
  }

  vim.list_extend(command_builder, rg_opts)

  local regexps = split_regexps(rg_pattern)

  if rg_supports_pcre2() and #regexps > 1 then
    table.insert(command_builder, "--pcre2")
    local combined = compile_orderless_from_parts(regexps)
    table.insert(command_builder, combined)
  else
    if #regexps > 1 then
      -- cargo install ripgrep --features 'pcre2'
      vim.notify(
        "Ripgrep PCRE2 support not detected. Using multiple patterns instead (less efficient).",
        vim.log.levels.WARN
      )
    end

    for _, re in ipairs(regexps) do
      table.insert(command_builder, "-e")
      table.insert(command_builder, re)
    end
  end

  table.insert(command_builder, search_dir)

  return command_builder
end

local function ripgrep(opts)
  opts = opts or {}

  local search_dir = opts.search_dir or get_project_root()

  local entry_maker = make_entry.gen_from_vimgrep(opts)

  local picker = pickers.new(vim.tbl_extend("force", opts, {
    prompt_title = "Inflect Ripgrep",

    finder = finders.new_job(
      async_rg_finder,
      entry_maker,
      opts
    ),

    previewer = conf.grep_previewer(opts),
    -- Fix sorting for double filtering
    sorter = nil
    -- sorter = conf.generic_sorter({

    --   filter_function = function(entry, prompt)
    --     local _, _, filter = parse_input(prompt)
    --     if not filter or filter == "" then
    --       return true
    --     end

    --     local positions = require("telescope.algos").fzy_filter(filter, entry.ordinal or "")
    --     return positions ~= nil
    --   end,

    --   scoring_function = function(entry, prompt)
    --     local _, _, filter = parse_input(prompt)
    --     if not filter or filter == "" then
    --       return 1
    --     end

    --     local score = require("telescope.algos").fzy_score(filter, entry.ordinal or "")
    --     return score or -1
    --   end,

    --   highlighter = function(entry, prompt)
    --     local pattern, _, filter = parse_input(prompt)
    --     return require("telescope.algos").fzy_positions(entry.ordinal or "", filter or pattern)
    --   end
    -- })


  }))

  picker:find()
end

return require("telescope").register_extension({
  exports = {
    ripgrep = ripgrep,
  },
})
