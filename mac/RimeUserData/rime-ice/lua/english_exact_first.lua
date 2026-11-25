-- 将与完整输入一致的英文候选置顶，不改写候选，保留词频学习能力。
local M = {}

function M.func(input, env)
  local ctx = env.engine.context
  local raw = ctx.input or ''
  if ctx:get_option('ascii_mode') or not raw:match('^[A-Za-z]+$') then
    for cand in input:iter() do yield(cand) end
    return
  end

  local expected = raw:lower()
  local pending = {}
  local promoted = false
  for cand in input:iter() do
    if promoted then
      yield(cand)
    elseif cand._start == 0 and cand._end == #raw
      and cand.text:lower() == expected then
      yield(cand)
      for _, previous in ipairs(pending) do yield(previous) end
      pending = nil
      promoted = true
    else
      pending[#pending + 1] = cand
    end
  end
  if not promoted then
    for _, cand in ipairs(pending) do yield(cand) end
  end
end

return M
