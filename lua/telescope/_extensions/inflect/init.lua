local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local sorters = require("telescope.sorters")
local previewers = require("telescope.previewers")
local make_entry = require('telescope.make_entry')
local fzy = require "telescope.algos.fzy"

local State = {}
function State:new()
  local obj = {
    filter = nil,
    listeners = {}
  }
  setmetatable(obj, self)
  self.__index = self
  return obj
end

function State:set_filter(value)
  self.filter = value
end

function State:get_filter()
  return self.filter
end

local function get_project_root()
  local ok_proj, project = pcall(require, "project_nvim.project")
  if ok_proj and project and project.get_project_root then
    return project.get_project_root()
  end

  local ok_telproj, telescope_project = pcall(require, "telescope._extensions.project")
  if ok_telproj and telescope_project and telescope_project.get_project_root then
    return telescope_project.get_project_root()
  end

  return vim.loop.cwd()
end

local function parse_input(input)
  local rg_pattern, filter = nil, nil
  local rg_args = {}

  -- Case: /pattern/filter
  local is_slash_syntax = input:match("^/.*/")
  if is_slash_syntax then
    local raw_rg, raw_filter = input:match("^/(.-)/(.*)")
    rg_pattern = vim.trim(raw_rg or "")
    filter = vim.trim(raw_filter or "")
    if filter == "" then filter = nil end

    -- Case: #pattern#filter
  elseif input:match("^#.-#") then
    local raw_rg, raw_filter = input:match("^#(.-)#(.*)")
    rg_pattern = vim.trim(raw_rg or "")
    filter = vim.trim(raw_filter or "")
    if filter == "" then filter = nil end

    -- Case: #pattern
  elseif input:match("^#") then
    rg_pattern = vim.trim(input:sub(2))

    -- Fallback: plain
  else
    rg_pattern = vim.trim(input)
  end

  -- Parse rg args: only extract rg args after `--`
  local stripped, opts = rg_pattern:match("^(.-)%s+%-%-%s+(.*)$")
  if opts then
    rg_pattern = vim.trim(stripped)
    for opt in opts:gmatch("[^%s]+") do
      table.insert(rg_args, opt)
    end
  end
  return rg_pattern, rg_args, filter
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

local function escape_regex_special_chars(s)
  return s:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?%{%}%|%\\])", "\\%1")
end

local function escape_pcre2(s)
  return s:gsub("([%[%]%(%)%.%+%-%*%?%^%$%%{}|\\/!~])", "\\%1")
end

local function compile_orderless_from_parts(parts)
  local lookaheads = {}
  for _, word in ipairs(parts) do
    local escaped = escape_regex_special_chars(word)
    table.insert(lookaheads, "(?=.*" .. escaped .. ")")
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

local function ripgrep(opts)
  opts = opts or {}

  local state = State:new()

  local entry_maker = make_entry.gen_from_vimgrep(opts)
  local search_dir = get_project_root()

  local rg_finder = finders.new_job(function(prompt)
    if not prompt or #prompt < 3 then return nil end

    local rg_pattern, rg_args, filter = parse_input(prompt)

    state:set_filter(filter)

    local command_builder = {
      "rg", "--vimgrep",
      "--line-buffered", "--color=never", "--max-columns=1000",
      "--smart-case", "--no-heading", "--with-filename", "--line-number", "--search-zip"
    }

    vim.list_extend(command_builder, rg_args)

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

    return command_builder
  end, entry_maker, opts.max_results, search_dir)

  local OFFSET = -fzy.get_score_floor()
  local sorter = sorters.Sorter:new {
    scoring_function = function(_, _, line)
      local filter = state.filter or ""
      if not fzy.has_match(filter, line) then
        return -1
      end

      local fzy_score = fzy.score(filter, line)

      if fzy_score == fzy.get_score_min() then
        return 1
      end

      return 1 / (fzy_score + OFFSET)
    end,

    highlighter = function(_, prompt, display)
      local pattern, _, _ = parse_input(prompt)
      local filter = state.filter or pattern

      return fzy.positions(filter, display)
    end,
  }

  pickers.new(opts, {
    prompt_title = "Inflect Ripgrep",
    finder = rg_finder,
    previewer = require("telescope.config").values.grep_previewer(opts),
    sorter = sorter,
    push_cursor_on_edit = true,
  }):find()
end

return require("telescope").register_extension({
  exports = {
    ripgrep = ripgrep,
  },
})
