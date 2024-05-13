-- state to handle full-width kana input

local M = {}

local g_kana_tree = require 'state/kana-tree/logic'
local g_kana_tree_common = require 'state/kana-tree/common'
local g_common = require 'common'

function M.init(dfa)
  g_kana_tree.init()
  M.dfa = dfa
end

function M.enter()
  g_kana_tree.go_to_root()
  g_kana_tree.set_hiragana()

  g_common.alert('Direct Input (ひらがな)')
end

function M.handle_ctrl_j()
  -- do nothing
end

function M.handle_cr()
  g_common.alert("CR in DI Kana")
end

function M.handle_bs()
  g_common.alert("BS in DI Kana")
end

function M.handle_input(c)
  if c == 'l' then
    M.dfa.go_to_direct_input_hfc_state()
    return ''

  elseif c == 'q' then
    g_kana_tree.set_katakana()
    g_common.alert("Direct input (カタカナ)")
    return ''

  elseif c == ';' then
    M.dfa.go_to_input_reading_state()
    return '▽'

  else
    local res = g_kana_tree_common.traverse(g_kana_tree, M.handle_input, c)
    return res["value"]
  end
end

return M

