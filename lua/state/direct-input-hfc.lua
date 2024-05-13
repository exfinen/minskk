-- state to handle half-width character input

local M = {}

local g_common = require 'common'

function M.init(dfa)
  M.dfa = dfa
end

function M.enter()
  g_common.alert('Direct Input (Half-width Chars)')
end

function M.handle_ctrl_j()
  M.dfa.go_to_direct_input_kana_state()
end

function M.handle_cr()
  g_common.alert("CR in DI hfc")
end

function M.handle_bs()
  g_common.alert("BS in DI hfc")
end

function M.handle_input(c)
  -- return what is typed w/o any processing
  return c
end

return M

