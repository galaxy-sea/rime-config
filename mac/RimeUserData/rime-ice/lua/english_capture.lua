-- 只旁观回车及其上屏结果，不接管按键、不修改候选或输入内容。
local M = {}

local function warn(message)
  log.warning('[EnglishCapture] ' .. message)
end

local function append_word(env, word)
  if not env.output_path or env.output_path == '' then
    if not env.warned then
      warn('未配置仓库词库路径，请运行仓库的 deploy-mac.sh。')
      env.warned = true
    end
    return
  end
  -- 只追加记录，去重及大小写冲突交给离线归类脚本。
  local file, err = io.open(env.output_path, 'a')
  if not file then
    warn('无法追加词库：' .. tostring(err))
    return
  end
  local ok, write_err = file:write('# ' .. word .. '\t' .. word:lower() .. '\t101\n')
  local closed, close_err = file:close()
  if not ok or not closed then
    warn('追加词库失败：' .. tostring(write_err or close_err))
  end
end

local function find_dictionary_candidate(ctx, word)
  local composition = ctx.composition
  if composition:empty() then return false end
  local segment = composition:back()
  local menu = segment and segment.menu
  if not menu then return false end
  local expected = word:lower()
  local index = 0
  while true do
    -- 按需生成后续候选，不能仅检查已经显示的第一页。
    local cand = menu:get_candidate_at(index)
    if not cand then return false end
    if cand._start == 0 and cand._end == #word and cand.text:lower() == expected then
      for _, genuine in ipairs(cand:get_genuines()) do
        local phrase = genuine:to_phrase()
        -- 词库及用户词库候选才代表已收录，排除原样回显、补全和造句。
        if phrase and (phrase.type == 'table' or phrase.type == 'user_table')
          and phrase.lang_name and phrase.lang_name ~= '' then
          return { candidate = genuine, language = phrase.lang_name }
        end
      end
    end
    index = index + 1
  end
end

local function learn_candidate(env, ctx, match)
  local namespaces = { tech_codes = 'tech_codes', melt_eng = 'melt_eng' }
  local namespace = namespaces[match.language]
  if not namespace then
    warn('命中的词库暂不支持回车调频：' .. match.language)
    return
  end
  -- 如果匹配词仍在提交的 composition 中，原生翻译器会学习，不重复计数。
  local selected = ctx:get_selected_candidate()
  if selected then
    for _, genuine in ipairs(selected:get_genuines()) do
      local phrase = genuine:to_phrase()
      if phrase and phrase.lang_name == match.language
        and genuine.text == match.candidate.text then
        return
      end
    end
  end
  local memory = env.memories[namespace]
  if not memory then
    memory = Memory(env.engine, env.engine.schema, namespace)
    env.memories[namespace] = memory
  end
  -- 使用候选自身的编码和来源，不能用输入字符串拼造其他词库的编码。
  memory:start_session()
  local ok, updated = pcall(function()
    return memory:update_candidate(match.candidate, 1)
  end)
  if not ok or not updated then
    memory:discard_session()
    warn('英文词频更新失败：' .. tostring(updated))
    return
  end
  if not memory:finish_session() then warn('英文词频保存失败。') end
end

function M.init(env)
  env.output_path = env.engine.schema.config:get_string('english_capture/output_path')
  env.memories = {}
  env.connection = env.engine.context.commit_notifier:connect(function(ctx)
    local pending = env.pending
    env.pending = nil
    -- 回车最终提交的内容必须与原输入完全相同，排除中文选词等情况。
    if pending and ctx:get_commit_text() == pending.word then
      local ok, err
      if pending.match then
        ok, err = pcall(learn_candidate, env, ctx, pending.match)
      else
        ok, err = pcall(append_word, env, pending.word)
      end
      if not ok then warn(tostring(err)) end
    end
  end)
end

function M.func(key, env)
  -- 松开回车不能清除 pending；下一次按键一定重新校验。
  if key:release() then return 2 end
  env.pending = nil
  if key:ctrl() or key:alt() or key:super() or key:shift() then return 2 end
  local name = key:repr()
  if name ~= 'Return' and name ~= 'KP_Enter' then return 2 end
  local ctx = env.engine.context
  -- 直通英文模式没有完整预编辑内容，不能通过这个处理器收集。
  if ctx:get_option('ascii_mode') or not ctx:is_composing() then return 2 end
  local word = ctx.input or ''
  -- 三个字母及以内的输入由用户手动维护，不自动收集或增加回车词频。
  if #word <= 3 then return 2 end
  if #word <= 64 and word:match('^[A-Za-z]+$') then
    -- 在原生回车处理前检查；之后候选会被清除，不能在 commit 通知中检查。
    local ok, known = pcall(find_dictionary_candidate, ctx, word)
    if not ok then warn('候选检查失败，保留收集记录：' .. tostring(known)) end
    env.pending = { word = word, match = ok and known or nil }
  end
  return 2
end

function M.fini(env)
  if env.connection then env.connection:disconnect() end
  for _, memory in pairs(env.memories or {}) do memory:disconnect() end
  env.memories = nil
end

return M
