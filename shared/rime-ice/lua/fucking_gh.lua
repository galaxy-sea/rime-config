
local M = {}

function M.func(key, env)
  -- 忽略松键和快捷键
  if key:release()
    or key:ctrl()
    or key:alt()
    or key:super() then
    return 2
  end

  local ctx = env.engine.context
  local ch = key:repr()

  -- 英文模式不处理
  if ctx:get_option("ascii_mode")
    or ctx:get_option("programmer_english") then
    return 2
  end

  -- 回车：还原原始拼音并上屏
  if ch == "Return" or ch == "KP_Enter" then
    local raw = ctx.input or ""

    -- 只处理含有 'g 或 'h 的输入
    if ctx:is_composing()
      and raw:find("'[gh]") then

      -- 模拟原始编码上屏：
      -- 保留已确认的片段
      ctx:clear_non_confirmed_composition()

      local text = ctx:get_commit_text()

      -- 移除自动分隔符
      local clean = text:gsub("'([gh])", "%1")

      env.engine:commit_text(clean)
      ctx:clear()

      return 1
    end

    return 2
  end

  -- 只处理 g 和 h
  if ch ~= "g" and ch ~= "h" then
    return 2
  end

  local raw = ctx.input or ""

  -- 光标必须在末尾
  if ctx.caret_pos ~= #raw then
    return 2
  end

  local split = false

  -- g：前面有字母就分隔
  if ch == "g" and raw:match("[a-z]$") then
    split = true
  end

  -- h：前面是 z、c、s 就分隔
  if ch == "h" and raw:match("[zcs]$") then
    split = true
  end

  if split then
    ctx:push_input("'" .. ch)
    return 1
  end

  return 2
end

return M
