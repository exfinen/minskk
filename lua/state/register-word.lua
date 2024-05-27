local M = {}

local g_common = require 'common'

function M.init(dfa, util)
  M.dfa = dfa
  M.util = util
end

function M.enter(inst)
  M.candidates = inst.candidates
  M.curr_index = inst.curr_index
  M.reading = inst.reading
  M.ac_kana_letter = inst.ac_kana_letter
  M.ac_kana_first_char = inst.ac_kana_first_char
  M.regist_str_len = inst.regist_str_len
  M.last_candidate_head = inst.last_candidate_head

  M.util.set_dfa_state(M.util.DFAState.RegisterWord)
end

function M.handle_ctrl_j()
end

function M.handle_cr()
end

function M.handle_bs()
end

local function go_back_to_select_kanji_list_state()
  g_common.delete_n_chars_before_cursor(M.regist_str_len, 0, M.last_candidate_head)

  M.dfa.go_to_select_kanji_list_state({
    candidates = M.candidates,
    curr_index = M.curr_index,
    reading = M.reading,
    ac_kana_letter = M.ac_kana_letter,
    ac_kana_first_char = M.ac_kana_first_char,
  })
end

function M.handle_esc()
  go_back_to_select_kanji_list_state()
end

function M.handle_input(c)
  return c
end

function M.set_user_dict(path)
  M.path = path
end

return M

