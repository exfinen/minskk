local M = {
  curr_node = nil,
  curr_depth = 0,
}

M.KanaType = {
  Hiragana = 1,
  Katakana = 2,
}

local g_common = require 'common'
local g_kana_tree = require 'state/kana-tree/tree'
local g_curr_kana_type = nil

M.TraverseResult = {
  Failed = 1,
  MovedNext = 2,
  GotLetter = 3,
}

function M.set_hiragana()
  g_curr_kana_type = M.KanaType.Hiragana
end

function M.set_katakana()
  g_curr_kana_type = M.KanaType.Katakana
end

function M.toggle_kana_type()
  if g_curr_kana_type == M.KanaType.Katakana then
    M.set_hiragana()
  else
    M.set_katakana()
  end
  return g_curr_kana_type
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

local function traverse_actual(c)
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

function M.traverse(kana_tree, handle_input, c, no_del_upon_got_letter)
  local res = traverse_actual(c)

  if res["type"] == kana_tree.TraverseResult.GotLetter then
    local depth = res["depth"]
    local letter = res["value"]

    if not no_del_upon_got_letter then
      g_common.delete_n_chars_before_cursor(depth - 1)
    end

    return {
      ["value"] = letter,
      ["is_letter"] = true,
      ["depth"] = depth,
    }

  elseif res["type"] == kana_tree.TraverseResult.MovedNext then
    -- show conversion process
    return {
      ["value"] = c,
      ["is_letter"] = false,
    }

  elseif res["type"] == kana_tree.TraverseResult.Failed then
    local depth = res["depth"]

    -- ignore if the char is not the beginning of any valid path
    if depth == 0 then
      return {
        ["value"] = '',
        ["is_letter"] = false,
      }

    else
      -- otherwise, delete the chars typed so far
      g_common.delete_n_chars_before_cursor(depth)

      -- and start traversing again from the root
      kana_tree.go_to_root()

      return {
        ["value"] = handle_input(c),
        ["is_letter"] = false,
      }
    end
  else
    error('should not be visited. check code (direct-input-kana/common.lua 1)')
  end
end

return M

