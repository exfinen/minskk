local M = {}

-- n           number of chars to delete
-- offset      number of offset chars before start counting n (optional)
-- replacement replacement chars for the deleted chars (optional)
--
function M.delete_n_chars_before_cursor(n, offset, replacement, suffix_len)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  vim.schedule(function()
    local repl_table = {}
    if replacement then
      repl_table = { replacement }
    end
    vim.api.nvim_buf_set_text(
      0,
      row - 1, col - n - (offset or 0),
      row - 1, col - (offset or 0),
      repl_table
    )
    if replacement then
      -- move the cursor to the rightmost position
      suffix_len = suffix_len or 0
      vim.api.nvim_win_set_cursor(0, { row, col + #replacement - n + suffix_len })
    end
  end)
end

function M.join_str_array(array)
  local s = ''
  for _, c in ipairs(array) do
    s = s .. c
  end
  return s
end

function M.alert(message)
  vim.schedule(function ()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { message })

    local width = math.max(20, #message + 4)
    local height = 1
    local opts = {
      style = "minimal",
      relative = "editor",
      width = width,
      height = height,
      row = math.floor((vim.o.lines - height) / 2),
      col = math.floor((vim.o.columns - width) / 2),
      border = "single",
      noautocmd = false,
    }
    local win = vim.api.nvim_open_win(buf, false, opts)

    vim.defer_fn(function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end, 2000)
  end)
end

function M.file_exists(name)
   local f = io.open(name,"r")
   if f then io.close(f) return true else return false end
end

return M

