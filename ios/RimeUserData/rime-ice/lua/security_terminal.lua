-- 视觉皮肤就绪标志，仅反映 RIME 处理器初始化，不提供加密功能。
local M = {}

function M.init(env)
  env.engine.context:set_option('security_terminal_ready', true)
end

function M.func(key, env)
  return 2 -- kNoop：不拦截按键，继续交给其他处理器。
end

return M
