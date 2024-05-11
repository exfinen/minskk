local M = {}

local KanaType = {
  Hiragana = 1,
  Katakana = 2,
}

local g_state = {
  curr_node = nil,
  curr_depth = 0,
}
local g_kana_tree = require 'kana-tree'
local g_curr_kana_type = nil

M.TraverseResult = {
  Failed = 1,
  MovedNext = 2,
  GotLetter = 3,
  ToKatakana = 4,
  ToLowerCase = 5,
}

function M.set_hiragana()
  g_curr_kana_type = KanaType.Hiragana
end

function M.set_katakana()
  g_curr_kana_type = KanaType.Katakana
end

function M.init()
  g_state.curr_node = g_kana_tree.root
  M.set_hiragana()
end

function M.go_to_root()
  g_state.curr_node = g_kana_tree.root
  g_state.curr_depth = 0
end

function M.traverse(c)
  if g_state.curr_node[c] then
    -- move to the child node
    g_state.curr_node = g_state.curr_node[c]
    g_state.curr_depth = g_state.curr_depth + 1

    -- if intermediate node
    if #g_state.curr_node == 0 then
      -- still in the middle of valid tree traversal
      return {
        ["type"] = M.TraverseResult.MovedNext,
      }

    -- if instruction leaf node
    elseif #g_state.curr_node == 1 then
      -- get the instruction
      local inst = g_state.curr_node[1][1]

      -- go back to tree root
      M.go_to_root()

      if inst == g_kana_tree.Instruction.ToKatakana then
        return {
          ["type"] = M.TraverseResult.ToKatakana,
        }
      elseif inst == g_kana_tree.Instruction.ToLowerCase then
        return {
          ["type"] = M.TraverseResult.ToLowerCase,
        }
      else
        error('should not be visited. check code (1)')
      end

    -- if kana leaf node
    elseif #g_state.curr_node == 2 then
      -- found the kana corresponding to the traversal path
      local value = g_state.curr_node[g_curr_kana_type][1]
      local depth = g_state.curr_depth

      -- go back to the tree root
      M.go_to_root()

      return {
        ["type"] = M.TraverseResult.GotLetter,
        ["value"] = value,
        ["depth"] = depth,
      }
    else
      error('should not be visited. check code (2)')
    end
  else
    -- tree traversal failed. go back to the tree root.
    local depth = g_state.curr_depth
    M.go_to_root()
    return {
      ["type"] = M.TraverseResult.Failed,
      ["depth"] = depth,
    }
  end
end

return M

