
local M = {}

function M.func(input, env)
  for cand in input:iter() do
    local quality = tonumber(cand.quality) or 0
    local kind = cand.type or "unknown"
    local comment = cand.comment or ""

    -- 显示实际候选评分和候选类型
    local debug_info = string.format(
      "[%.6f %s]",
      quality,
      kind
    )

    cand.comment = comment .. debug_info

    yield(cand)
  end
end

return M
