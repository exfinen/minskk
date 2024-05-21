local M = {
  msg = '-',
  showing_alert = false,
  next_msg = '',
}

function M.get()
  return M.msg
end

function M.set(msg)
  if M.showing_alert then
    M.next_msg = msg
  else
    M.msg = msg
  end
end

function M.show_alert(msg, ms)
  ms = ms or 2000
  M.showing_alert = true

  M.next_msg = M.msg
  M.msg = msg

  vim.defer_fn(function()
    M.showing_alert = false
    M.msg = M.next_msg
  end, ms)
end

return M
