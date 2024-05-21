-- state to handle full-width kana input

local M = {}

local g_kana_tree = require 'state/kana-tree/logic'

function M.init(dfa, util)
  g_kana_tree.init()
  M.dfa = dfa
  M.util = util
end

function M.enter()
  g_kana_tree.go_to_root()
  g_kana_tree.set_hiragana()

  M.util.set_dfa_state(M.util.DFAState.DirectInput_Hiragana)
end

function M.handle_ctrl_j()
end

function M.handle_cr()
  vim.api.nvim_feedkeys(M.util.cr, "in", true)
end

function M.handle_bs()
  vim.api.nvim_feedkeys(M.util.bs, "in", true)
end

function M.handle_esc()
  M.util.disable()
end

function M.handle_input(c)
  if c == 'l' then
    M.dfa.go_to_direct_input_hwc_state()
    return ''

  elseif c == 'L' then
    M.dfa.go_to_direct_input_fwc_state()
    return ''

  elseif c == 'q' then
    if g_kana_tree.toggle_kana_type() == g_kana_tree.KanaType.Hiragana then
      M.util.set_dfa_state(M.util.DFAState.DirectInput_Hiragana)
    else
      M.util.set_dfa_state(M.util.DFAState.DirectInput_Katakana)
    end
    return ''

  elseif c == ';' then
    M.dfa.go_to_input_reading_state({})
    return '▽'

  else
    local res = g_kana_tree.traverse(g_kana_tree, M.handle_input, c)
    return res["value"]
  end
end

return M

