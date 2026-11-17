local M = {}
local MODE = 'programmer_english'
local TAG = MODE

local function active(ctx)
  return ctx:get_option(MODE)
    and not ctx:get_option('ascii_mode')
end

-- 输入处理器
M.processor = {}

function M.processor.init(env)
  local ctx = env.engine.context
  env.had_input = false

  -- 保持与原生中英文切换兼容
  env.option_conn =
    ctx.option_update_notifier:connect(function(c, name)

      if name == 'ascii_mode'
        and c:get_option('ascii_mode') then

        c:set_option(MODE, false)

      elseif name == MODE
        and c:get_option(MODE)
        and c:get_option('ascii_mode') then

        c:set_option('ascii_mode', false)
      end
    end)
end

function M.processor.fini(env)
  if env.option_conn then
    env.option_conn:disconnect()
  end

  if env.update_conn then
    env.update_conn:disconnect()
  end
end

function M.processor.func(key, env)
  local ctx = env.engine.context

  -- 中文模式完全使用原生逻辑
  if not active(ctx)
    or key:release()
    or key:ctrl()
    or key:alt()
    or key:super() then
    return 2
  end

  if key:repr() == 'Escape' then
    ctx:clear()
    return 1
  end

  local code = key.keycode

  -- 保留输入的真实大小写
  if (code >= 65 and code <= 90)
    or (code >= 97 and code <= 122) then

    local ch = string.char(code)

    if key:shift() then
      ch = ch:upper()
    end

    if ctx:push_input(ch) then
      return 1
    end
  end

  return 2
end

-- 英文独立分段
function M.segmentor(segmentation, env)
  if not active(env.engine.context) then
    return true
  end

  local input = segmentation.input

  if segmentation:get_current_start_position() == 0
    and input:match('^[A-Za-z]+$') then

    local seg = Segment(0, #input)
    seg.tags = Set({TAG})

    segmentation:add_segment(seg)
    return false
  end

  return true
end

-- 英文候选生成
M.translator = {}

function M.translator.func(input, seg, env)
  if not active(env.engine.context)
    or not seg:has_tag(TAG)
    or input == '' then
    return
  end

  local function candidate(text, quality)
    local cand = Candidate(
      TAG, seg.start, seg._end, text, ''
    )

    cand.preedit = input
    cand.quality = quality

    return cand
  end

  -- 首选始终保留原始大小写
  yield(candidate(input, 1000))

  -- 延迟加载英文词库
  if env.mem == nil then
    local ok, mem = pcall(function()
      return Memory(env.engine, Schema('melt_eng'))
    end)

    env.mem = ok and mem or false
  end

  if not env.mem then return end

  local lower = input:lower()

  local ok, words = pcall(function()
    local result = {}

    if env.mem:dict_lookup(lower, true, 16) then
      for entry in env.mem:iter_dict() do
        result[#result + 1] = entry.text

        if #result >= 16 then
          break
        end
      end
    end

    return result
  end)

  if not ok then return end

  local seen = {[input] = true}

  for _, word in ipairs(words) do
    if word:match('^[A-Za-z]+$')
      and word:lower():sub(1, #input) == lower then

      local text =
        input .. word:sub(#input + 1):lower()

      if not seen[text] then
        seen[text] = true
        yield(candidate(text, 10))
      end
    end
  end
end

function M.translator.fini(env)
  if env.mem then
    env.mem:disconnect()
  end
end

-- 英文模式过滤其他候选
M.filter = {
  tags_match = function(seg, env)
    return seg:has_tag(TAG)
  end,

  func = function(translation, env)
    for cand in translation:iter() do
      if not active(env.engine.context)
        or cand.type == TAG then
        yield(cand)
      end
    end
  end,
}

return M