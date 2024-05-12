local M = {}

local g_common = require 'common'

function M.traverse(kana_tree, handle_input, c)
  local res = kana_tree.traverse(c)

  if res["type"] == kana_tree.TraverseResult.GotLetter then
    local depth = res["depth"]
    local letter = res["value"]

    g_common.delete_n_chars_before_cursor(depth - 1)

    return {
      ["value"] = letter,
      ["is_letter"] = true,
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
