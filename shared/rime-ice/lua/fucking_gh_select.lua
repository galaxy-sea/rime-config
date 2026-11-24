
local M = {}

-- 判断是否为单个汉字
local function is_single_han(text)
  if not text then
    return false
  end

  local ok, len = pcall(utf8.len, text)
  if not ok or len ~= 1 then
    return false
  end

  local cp = utf8.codepoint(text)

  return (cp >= 0x3400 and cp <= 0x9FFF)
      or (cp >= 0x20000 and cp <= 0x323AF)
end

-- 查找需要保留的 g
local function find_boundary(raw, start, finish)
  -- 跳过当前候选的第一个字母
  local pos = raw:find("g", start + 2, true)

  if not pos then
    return nil
  end

  -- Lua 下标转成 Rime 编码位置
  local boundary = pos - 1

  if boundary > start and boundary < finish then
    return boundary
  end

  return nil
end

function M.func(input, env)
  local ctx = env.engine.context
  local raw = ctx.input or ""

  local disabled =
    ctx:get_option("ascii_mode")
    or ctx:get_option("programmer_english")

  for cand in input:iter() do
    if not disabled and is_single_han(cand.text) then
      local start = cand._start
      local finish = cand._end

      if type(start) == "number"
        and type(finish) == "number" then

        local boundary =
          find_boundary(raw, start, finish)

        if boundary then
          cand._end = boundary
        end
      end
    end

    yield(cand)
  end
end

return M
