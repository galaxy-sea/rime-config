-- 仅将 tech_codes 中启用且完整匹配输入的英文置顶。
local M = {}

-- 去重候选可能合并多个来源，逐个检查，避免把标准英文误当作技术词库。
local function from_tech_codes(cand)
  for _, genuine in ipairs(cand:get_genuines()) do
    local phrase = genuine:to_phrase()
    if phrase and phrase.lang_name == 'tech_codes' then return true end
  end
  return false
end

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
      and cand.text:lower() == expected and from_tech_codes(cand) then
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
