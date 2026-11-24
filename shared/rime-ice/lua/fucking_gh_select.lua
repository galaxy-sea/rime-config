
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
          -- Phrase / Simple 支持直接设置 preedit；Shadow / Uniquified
          -- 仍从被包装候选读取文本，不能仅修改外层范围。
          local kind = cand:get_dynamic_type()
          if kind == "Phrase" or kind == "Simple" then
            -- 原 preedit 可能仍包含被保留的 g；若不截短，尾部原始输入
            -- 再显示一次 g 时就会看到 gg。必须与 [start, boundary) 一致。
            cand.preedit = raw:sub(start + 1, boundary)
            cand._end = boundary
          end
        end
      end
    end

    yield(cand)
  end
end

return M
