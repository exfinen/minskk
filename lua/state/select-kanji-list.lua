local M = {
  candidates = {},
  curr_index = 0,
  reading = {},
  buffer = nil,
  window = nil,
}

local g_common = require 'common'

local selector_to_offset = {
  a = 0,
  s = 1,
  d = 2,
  f = 3,
  j = 4,
}
local selectors = {'a', 's', 'd', 'f', 'j'}

local function set_win_line(msg)
  vim.schedule(function ()
    vim.api.nvim_buf_set_lines(M.buffer, 0, -1, false, { msg })

    -- adjust the window width to the msg length
    local cfg = vim.api.nvim_win_get_config(M.window)
    cfg.width = #msg
    vim.api.nvim_win_set_config(M.window, cfg)
  end)
end

local function show_selector(width, row, col)
  vim.schedule(function ()
    M.buffer = vim.api.nvim_create_buf(false, false)

    local opts = {
      style = "minimal",
      relative = "editor",
      width = width,
      height = 1,
      row = row,
      col = col,
      border = "none",
      noautocmd = false,
      focusable = false,
    }
    M.window = vim.api.nvim_open_win(M.buffer, false, opts)
  end)
end

local function hide_selector()
  if vim.api.nvim_win_is_valid(M.window) then
    vim.schedule(function ()
      vim.api.nvim_win_close(M.window, true)
      vim.api.nvim_buf_delete(M.buffer, { force = true })
    end)
  end
end

local function build_selector_line()
  local last_index = math.min(#M.candidates - 1, M.curr_index + #selectors - 1)

  local letter_index = 1
  local line = ''

  for i=M.curr_index, last_index do
    line = string.format('%s %s: %s',
      line, selectors[letter_index], M.candidates[i + 1]
    )
    letter_index = letter_index + 1
  end
  return line
end

function M.init(dfa, util)
  M.dfa = dfa
  M.util = util
end

function M.enter(inst)
  M.util.set_dfa_state(M.util.DFAState.SelectKanjiList)
  M.candidates = inst.candidates
  M.curr_index = inst.curr_index or 0
  M.reading = inst.reading
  M.ac_kana_letter = inst.ac_kana_letter
  M.ac_kana_first_char = inst.ac_kana_first_char

  local line = build_selector_line()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1]
  local col = cursor[2]
  show_selector(#line, row, col)
  set_win_line(line)
end

local function get_candidate_head()
  return M.candidates[M.curr_index + 1]
end

local function select_candidate_head_and_go_to_direct_input_kana()
  hide_selector()

  local candidate_head = get_candidate_head()
  g_common.delete_n_chars_before_cursor(
    #'▼' + #candidate_head,
    0,
    candidate_head
  )
  M.dfa.go_to_direct_input_kana_state()
end

function M.handle_ctrl_j()
  select_candidate_head_and_go_to_direct_input_kana()
end

function M.handle_cr()
  select_candidate_head_and_go_to_direct_input_kana()
end

local function go_back_to_input_reading()
  local a = '▼' .. get_candidate_head()
  local b = '▽' .. g_common.join_str_array(M.reading)
  g_common.delete_n_chars_before_cursor(#a, 0, b)

  hide_selector()

  M.dfa.go_to_input_reading_state({
    reading = M.reading
  })
end

function M.handle_bs()
  local next_index = M.curr_index - #selectors
  if next_index >= 0 then
    -- go back to previous selector
    local curr_candidate_head = get_candidate_head()
    M.curr_index = next_index
    local next_candidate_head = get_candidate_head()

    g_common.delete_n_chars_before_cursor(
      #curr_candidate_head, 0, next_candidate_head
    )
    local line = build_selector_line()
    set_win_line(line)
  else
    -- was showing the first selector. go back to select kanji
    go_back_to_input_reading()
  end
end

function M.handle_esc()
  go_back_to_input_reading()
end

function M.handle_input(c)
  if c == ' ' then
    local curr_candidate_head = get_candidate_head()

    -- if currently the last selector
    if M.curr_index + #selectors > #M.candidates - 1 then
      hide_selector()

      -- start registering word
      local reading = g_common.join_str_array(M.reading)
      local ac_kana = #M.ac_kana_letter > 0 and ('*' .. M.ac_kana_letter) or ''
      local regist_str = string.format('[登録: %s%s]', reading, ac_kana)

      local candidate_head_len = #curr_candidate_head
      g_common.delete_n_chars_before_cursor(
        #'▼' + candidate_head_len,
        0,
        regist_str
      )
      M.dfa.go_to_register_word_state({
        candidates = M.candidates,
        curr_index = M.curr_index,
        reading = M.reading,
        ac_kana_first_char = M.ac_kana_first_char,
        ac_kana_letter = M.ac_kana_letter,
        regist_str_len = #regist_str,
        last_candidate_head = '▼' .. curr_candidate_head
      })
      return ''
    end

    -- update the currrent index
    M.curr_index = M.curr_index + #selectors

    local line = build_selector_line()
    set_win_line(line)

    -- update the candidate head
    local next_candidate_head = get_candidate_head()
    g_common.delete_n_chars_before_cursor(
      #curr_candidate_head, 0, next_candidate_head
    )
    return ''

  elseif selector_to_offset[c] then
    local offset = selector_to_offset[c]

    if M.curr_index + offset < #M.candidates then
      hide_selector()

      -- select candidate
      local candidate = M.candidates[M.curr_index + offset + 1]
      local candidate_head_len = #get_candidate_head()

      g_common.delete_n_chars_before_cursor(
        #'▼' + candidate_head_len,
        0,
        candidate
      )
      M.dfa.go_to_direct_input_kana_state()
    end
    return ''
  end
end

return M

