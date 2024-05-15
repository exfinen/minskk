local M = {
  curr_node = nil,
  curr_depth = 0,
}

local KanaType = {
  Hiragana = 1,
  Katakana = 2,
}

local g_kana_tree = require 'state/kana-tree/tree'
local g_katakana_map = require 'state/kana-tree/katakana-map'
local g_curr_kana_type = nil

M.TraverseResult = {
  Failed = 1,
  MovedNext = 2,
  GotLetter = 3,
}

function M.set_hiragana()
  g_curr_kana_type = KanaType.Hiragana
end

function M.set_katakana()
  g_curr_kana_type = KanaType.Katakana
end

function M.init()
  M.curr_node = g_kana_tree.root
  M.set_hiragana()
end

function M.go_to_root()
  M.curr_node = g_kana_tree.root
  M.curr_depth = 0
end

function M.at_the_root_node()
  return M.curr_node == g_kana_tree.root
end

function M.to_katakana(c)
  local katakana = g_katakana_map.root[c]
  if katakana then
    return katakana
  else
    return c
  end
end

function M.traverse(c)
  if M.curr_node[c] then
    -- move to the child node
    M.curr_node = M.curr_node[c]
    M.curr_depth = M.curr_depth + 1

    -- if intermediate node
    if #M.curr_node == 0 then
      -- still in the middle of valid tree traversal
      return {
        ["type"] = M.TraverseResult.MovedNext,
      }

    -- if kana leaf node
    elseif #M.curr_node == 2 then
      -- found the kana corresponding to the traversal path
      local value = M.curr_node[g_curr_kana_type][1]
      local depth = M.curr_depth

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
    local depth = M.curr_depth
    M.go_to_root()
    return {
      ["type"] = M.TraverseResult.Failed,
      ["depth"] = depth,
    }
  end
end

return M

