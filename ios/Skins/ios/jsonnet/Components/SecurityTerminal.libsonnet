// 信安六局 · 视觉皮肤组件（仅装饰，不提供加密或密钥生成）。
// 在 Style.resolve / Style.prune 之后、std.toString 之前调用 apply。
local colors = import '../Constants/Colors.libsonnet';
local Style = import 'Style.libsonnet';

local get(o, k, d=null) =
  if std.type(o) == 'object' && std.objectHas(o, k) then o[k] else d;

local asArray(x) =
  if x == null then [] else if std.type(x) == 'array' then x else [x];

local cells(x) =
  local t = std.type(x);
  if t == 'array' then std.flattenArrays(std.map(cells, x))
  else if t == 'object' then
    if std.type(get(x, 'Cell')) == 'string' then [x.Cell]
    else std.flattenArrays([cells(x[k]) for k in std.objectFields(x)])
  else [];

local label(value, color, fontSize, weight='regular', y=0.5) = {
  buttonStyleType: 'text',
  text: value,
  fontSize: fontSize,
  fontWeight: weight,
  center: { x: 0.5, y: y },
  normalColor: color,
  highlightColor: color,
};

// 只替换工具栏两侧按钮之间的空白区域，不替换任何已有功能键。
local toolbar(kb, isDark) =
  local layout = get(kb, 'toolbarLayout');
  local row = if std.type(layout) == 'array' && std.length(layout) == 1
              then get(layout[0], 'HStack') else null;
  local views = get(row, 'subviews', []);
  local valid = std.type(views) == 'array' && std.length(views) >= 2
                && std.all([std.type(get(v, 'Cell')) == 'string' for v in views]);
  if !valid then kb
  else
    local n = std.length(views);
    local middle = std.slice(views, 1, n - 1, 1);
    local empty = function(v)
      local name = v.Cell;
      local b = get(kb, name, {});
      name == '' || (std.type(b) == 'object'
        && get(b, 'type', 'button') == 'button'
        && std.all([get(b, k) == null for k in [
          'action', 'doubleTapAction', 'longPressAction', 'swipeUpAction',
          'swipeDownAction', 'swipeLeftAction', 'swipeRightAction',
          'foregroundStyle', 'notification', 'hintStyle', 'hintSymbolsStyle',
          'hintSymbolsGridStyle', 'animation',
        ]]));
    if !std.all(std.map(empty, middle)) then kb
    else kb + {
      toolbarLayout: [layout[0] + {
        HStack: row + {
          subviews: [views[0], { Cell: 'securityTerminalTitleButton' }, views[n - 1]],
        },
      }],
      securityTerminalTitleButton: {
        type: 'button',
        foregroundStyle: ['securityTerminalTitle', 'securityTerminalUnit'],
      },
      securityTerminalTitle: label('通信内容 · 严禁涉密',
        if isDark then '#E5E5E7' else '#242426', 15, 'medium', 0.32),
      securityTerminalUnit: label('信安六局',
        if isDark then '#98989D' else '#8E8E93', 10, 'regular', 0.75),
    };

local space(kb, isDark) =
  local keys = std.set(cells(get(kb, 'keyboardLayout', [])));
  local spaces = [
    k for k in keys
    if get(get(kb, k), 'action') == 'space'
  ];
  if std.length(spaces) == 0 then kb
  else kb + {
    securityTerminalGenerating: label('🔒 密钥生成中',
      Style.resolve(colors.standardButtonForegroundColor, isDark), 12),
    securityTerminalReady: label('🔒 数据已加密',
      if isDark then '#8E8E93' else '#AEAEB2', 12),
  } + {
    [k]: kb[k] + {
      foregroundStyle: [
        {
          styleName: 'securityTerminalGenerating',
          conditionKey: 'rime$security_terminal_ready',
          conditionValue: false,
        },
        {
          styleName: 'securityTerminalReady',
          conditionKey: 'rime$security_terminal_ready',
          conditionValue: true,
        },
      ],
      // 原来的 preeditChanged 等通知保留，放在初始化通知后面。
      notification: [k + 'SecurityTerminalOptionReady']
                    + asArray(get(kb[k], 'notification')),
    }
    for k in spaces
  } + {
    [k + 'SecurityTerminalOptionReady']: {
      notificationType: 'rime',
      rimeNotificationType: 'optionChanged',
      rimeOptionName: 'security_terminal_ready',
      rimeOptionValue: true,
      foregroundStyle: 'securityTerminalReady',
      [if get(kb[k], 'backgroundStyle') != null then 'backgroundStyle']: kb[k].backgroundStyle,
    }
    for k in spaces
  };

{
  // 仅根据 RIME Option 切换文字与颜色，不包含计时或过渡动画。
  // 切换时机取决于 RIME 初始化，可能要到首次输入时才触发。
  apply(kb, isDark=false): space(toolbar(kb, isDark), isDark),
}
