local M = {
  curr_node = nil,
}

local KanaType = {
  Hiragana = 1,
  Katakana = 2,
}

local g_kana_tree = require 'kana-tree'
local g_curr_kana_type = nil

M.TraverseResult = {
  None = 1,
  Letter = 2,
  ToKatakana = 3,
  ToLowerCase = 4,
}

function M.init()
  M.root = g_kana_tree.root
  M.curr_node = M.root
  M.set_hiragana()
end

function M.set_hiragana()
  g_curr_kana_type = KanaType.Hiragana
end

function M.set_katakana()
  g_curr_kana_type = KanaType.Katakana
end

function M.go_to_root()
  M.curr_node = g_kana_tree.root
end

function M.traverse(c)
  if M.curr_node[c] then
    -- move to the child node
    M.curr_node = M.curr_node[c]

    if #M.curr_node == 1 then
      -- get the instruction
      local inst = M.curr_node[1][1]

      -- go back to tree root
      M.go_to_root()

      if inst == g_kana_tree.Instruction.ToKatakana then
        return {
          ["type"] = M.TraverseResult.ToKatakana,
        }
      else
        return {
          ["type"] = M.TraverseResult.ToLowerCase,
        }
      end
    elseif #M.curr_node == 2 then
      -- get the kana corresponding to the traversal path
      local value = M.curr_node[g_curr_kana_type][1]

      -- go back to tree root
      M.go_to_root()

      return {
        ["type"] = M.TraverseResult.Letter,
        ["value"] = value,
      }
    end
    -- don't return anything. still in the middle of a tree traversal
  else
    -- invalid traversal. return nothing and go back to tree root
    M.go_to_root()
  end
  return {
    ["type"] = M.TraverseResult.None,
  }
end

return M

