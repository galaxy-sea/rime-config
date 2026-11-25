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

function M.init(env)
  env.output_path = env.engine.schema.config:get_string('english_capture/output_path')
  env.connection = env.engine.context.commit_notifier:connect(function(ctx)
    local word = env.pending
    env.pending = nil
    -- 回车最终提交的内容必须与原输入完全相同，排除中文选词等情况。
    if word and ctx:get_commit_text() == word then
      local ok, err = pcall(append_word, env, word)
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
  if #word >= 2 and #word <= 64 and word:match('^[A-Za-z]+$') then
    env.pending = word
  end
  return 2
end

function M.fini(env)
  if env.connection then env.connection:disconnect() end
end

return M
