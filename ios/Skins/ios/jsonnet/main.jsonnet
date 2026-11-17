// 元书「极简」皮肤：在对象层完成所有修改，再一次性输出文件。
local Style = import 'Components/Style.libsonnet';
local iPadNumeric = import 'Keyboards/iPadNumeric.libsonnet';
local iPadPinyin = import 'Keyboards/iPadPinyin.libsonnet';
local iPhoneNumeric = import 'Keyboards/iPhoneNumeric.libsonnet';
local iPhonePinyin = import 'Keyboards/iPhonePinyin.libsonnet';
local iPhoneSymbolic = import 'Keyboards/iPhoneSymbolic.libsonnet';

local get(o, k, d=null) =
  if std.type(o) == 'object' && std.objectHas(o, k) then o[k] else d;

local shadowKeys = {
  normalLowerEdgeColor: true,
  highlightLowerEdgeColor: true,
  normalShadowColor: true,
  highlightShadowColor: true,
};

local removeShadow(x) =
  local t = std.type(x);
  if t == 'object' then {
    [k]: removeShadow(x[k])
    for k in std.objectFields(x)
    if !std.objectHas(shadowKeys, k)
  }
  else if t == 'array' then std.map(removeShadow, x)
  else x;

// 每份键盘只收集一次实际布局中使用的按键名称。
local cells(x) =
  local t = std.type(x);
  if t == 'array' then std.flattenArrays(std.map(cells, x))
  else if t == 'object' then
    if std.type(get(x, 'Cell')) == 'string' then [x.Cell]
    else std.flattenArrays([cells(x[k]) for k in std.objectFields(x)])
  else [];

local keyNames(kb) = [
  k for k in std.set(cells(get(kb, 'keyboardLayout', get(kb, 'keyboard', []))))
  if std.objectHas(kb, k) && std.type(kb[k]) == 'object'
];

local letterBackground(kb, keys) =
  local matches = [
    k for k in keys
    if std.type(get(kb[k], 'backgroundStyle')) == 'string'
    && (
      std.member(['q', 'qbutton'], std.asciiLower(k))
      || get(get(kb[k], 'action'), 'character') == 'q'
    )
  ];
  if std.length(matches) == 0 then null
  else
    local bgName = kb[matches[0]].backgroundStyle;
    { name: bgName, style: get(kb, bgName) };

// 回车保留随类型变化的条件样式，空格及集合控件保留原有背景。
local protected(k, v) =
  local action = get(v, 'action');
  std.member(['enter', 'space'], action)
  || (action == null && std.member([
    'enterbutton', 'returnbutton', 'spacebutton', 'spacebar',
  ], std.asciiLower(k)))
  || std.member([
    'symbols', 'pinyin', 'classifiedSymbols', 'subClassifiedSymbols',
  ], get(v, 'type'));

local unifyButtons(kb, keys, base) =
  if std.type(base) != 'object' || std.type(base.style) != 'object' then kb
  else
    local reuse = get(kb, base.name) == base.style;
    local bgName = if reuse then base.name else 'unifiedLetterBackgroundStyle';
    kb
    + (if reuse then {} else { unifiedLetterBackgroundStyle: base.style })
    + {
      [k]: kb[k] + { backgroundStyle: bgName }
      for k in keys
      if !protected(k, kb[k])
      && get(kb[k], 'backgroundStyle') != bgName
      && (get(kb[k], 'action') != null || get(kb[k], 'backgroundStyle') != null)
    };

// 展开候选栏：取消底部操作栏，右上角保留收起按钮。
local nativeCandidates(kb, color) =
  if !std.objectHas(kb, 'verticalCandidatesLayout') then kb
  else
    local candidates = [
      k for k in std.objectFields(kb)
      if get(kb[k], 'type') == 'verticalCandidates'
    ];
    if std.length(candidates) == 0 then kb
    else
      local candidate = candidates[0];
      local rows = get(kb[candidate], 'maxRows', 5) + 1;
      kb + {
        verticalCandidatesLayout: [
          { VStack: { subviews: [{ Cell: candidate }] } },
          {
            VStack: {
              style: 'nativeCollapseColumn',
              subviews: [
                { Cell: 'nativeCollapseButton' },
                { Cell: 'nativeCandidatesSpacer' },
              ],
            },
          },
        ],
        [candidate]: kb[candidate] + {
          maxRows: rows,
          size: { height: '1/1' },
        },
        nativeCollapseColumn: { size: { width: 44 } },
        nativeCollapseButton: {
          size: { height: kb.toolbarHeight },
          action: { shortcut: '#candidatesBarStateToggle' },
          foregroundStyle: 'nativeCollapseForeground',
        },
        nativeCollapseForeground: {
          buttonStyleType: 'systemImage',
          systemImageName: 'chevron.up',
          fontSize: 18,
          fontWeight: 'medium',
          center: { x: 0.5, y: 0.5 },
          normalColor: color,
          highlightColor: color,
        },
        nativeCandidatesSpacer: { type: 'button' },
      };

// 独立英文模式：保留原生 Shift 定义，只替换布局中的 Shift 引用。
local mode = 'programmer_english';
local trigger = { rimeOption: mode };
local alphabet = std.stringChars('abcdefghijklmnopqrstuvwxyz');

local rewriteLayout(x, shiftMap) =
  local t = std.type(x);
  if t == 'array' then std.map(function(v) rewriteLayout(v, shiftMap), x)
  else if t == 'object' then {
    [k]:
      if k == 'Cell' && std.type(x[k]) == 'string' && std.objectHas(shiftMap, x[k])
      then shiftMap[x[k]]
      else rewriteLayout(x[k], shiftMap)
    for k in std.objectFields(x)
  }
  else x;

local note(btn, fg) = {
  notificationType: 'rime',
  rimeNotificationType: 'optionChanged',
  rimeOptionName: mode,
  rimeOptionValue: true,
  foregroundStyle: fg,
  [if get(btn, 'backgroundStyle') != null then 'backgroundStyle']: btn.backgroundStyle,
};

local appendNote(btn, n) =
  local old = get(btn, 'notification', []);
  (if old == null then [] else if std.type(old) == 'array' then old else [old]) + [n];

local modeForeground(label, color) = {
  buttonStyleType: 'text',
  text: label,
  fontSize: 17,
  fontWeight: 'medium',
  normalColor: color,
  highlightColor: color,
};

local modeStyles = [
  {
    styleName: 'programmerChineseForeground',
    conditionKey: 'rime$' + mode,
    conditionValue: false,
  },
  {
    styleName: 'programmerEnglishForeground',
    conditionKey: 'rime$' + mode,
    conditionValue: true,
  },
];

local programmerEnglish(kb, keys, color, blue) =
  if !std.objectHas(kb, 'keyboardLayout') then kb
  else
    local shifts = [k for k in keys if get(kb[k], 'action') == 'shift'];
    if std.length(shifts) == 0 then kb
    else
      local shiftMap = { [k]: 'programmerEnglishButton_' + k for k in shifts };
      local letters = [
        k for k in keys
        if std.member(alphabet, get(get(kb[k], 'action'), 'character'))
      ];
      kb + {
        keyboardLayout: rewriteLayout(kb.keyboardLayout, shiftMap),
        programmerChineseForeground: modeForeground('中', color),
        programmerEnglishForeground: modeForeground('En', blue),
      }
      + {
        [shiftMap[k]]:
          local btn = kb[k];
          {
            [field]: btn[field]
            for field in ['size', 'bounds', 'backgroundStyle', 'animation']
            if std.objectHas(btn, field)
          } + {
            type: 'button',
            action: trigger,
            foregroundStyle: modeStyles,
            notification: shiftMap[k] + 'Notification',
          }
        for k in shifts
      }
      + {
        [shiftMap[k] + 'Notification']:
          note(kb[k], 'programmerEnglishForeground') + { action: trigger }
        for k in shifts
      }
      + {
        [k]: kb[k] + { notification: appendNote(kb[k], k + 'ProgrammerEnglishNotification') }
        for k in letters
      }
      + {
        [k + 'ProgrammerEnglishNotification']:
          local btn = kb[k];
          local ch = btn.action.character;
          note(btn, btn.foregroundStyle) + {
            action: { character: ch },
            swipeUpAction: { character: std.asciiUpper(ch) },
          }
        for k in letters
      };

// 10 种布局及对应的拼音背景来源。
local keyboards = {
  pinyinPortrait: iPhonePinyin.new(isPortrait=true),
  pinyinLandscape: iPhonePinyin.new(isPortrait=false),
  numericPortrait: iPhoneNumeric.new(isPortrait=true),
  numericLandscape: iPhoneNumeric.new(isPortrait=false),
  symbolicPortrait: iPhoneSymbolic.new(isPortrait=true),
  symbolicLandscape: iPhoneSymbolic.new(isPortrait=false),
  iPadPinyinPortrait: iPadPinyin.new(isPortrait=true),
  iPadPinyinLandscape: iPadPinyin.new(isPortrait=false),
  iPadNumericPortrait: iPadNumeric.new(isPortrait=true),
  iPadNumericLandscape: iPadNumeric.new(isPortrait=false),
};

local sourceName = {
  pinyinPortrait: 'pinyinPortrait',
  numericPortrait: 'pinyinPortrait',
  symbolicPortrait: 'pinyinPortrait',
  pinyinLandscape: 'pinyinLandscape',
  numericLandscape: 'pinyinLandscape',
  symbolicLandscape: 'pinyinLandscape',
  iPadPinyinPortrait: 'iPadPinyinPortrait',
  iPadNumericPortrait: 'iPadPinyinPortrait',
  iPadPinyinLandscape: 'iPadPinyinLandscape',
  iPadNumericLandscape: 'iPadPinyinLandscape',
};

local names = std.objectFields(keyboards);
local baseNames = ['pinyinPortrait', 'pinyinLandscape', 'iPadPinyinPortrait', 'iPadPinyinLandscape'];

// 每个主题只 resolve/prune 一次；中间结果始终为对象，不再反复解析 JSON。
local compileTheme(isDark) =
  local color = if isDark then '#FFFFFF' else '#000000';
  local blue = if isDark then '#0A84FF' else '#007AFF';
  local prepared = {
    [n]:
      local kb = removeShadow(Style.prune(Style.resolve(keyboards[n], isDark)));
      { keyboard: kb, keys: keyNames(kb) }
    for n in names
  };
  local backgrounds = {
    [n]: letterBackground(prepared[n].keyboard, prepared[n].keys)
    for n in baseNames
  };
  {
    [n]:
      local p = prepared[n];
      local kb = nativeCandidates(unifyButtons(p.keyboard, p.keys, backgrounds[sourceName[n]]), color);
      local final = if std.member(baseNames, n)
                    then programmerEnglish(kb, p.keys, color, blue)
                    else kb;
      std.toString(final)
    for n in names
  };

local compiled = { light: compileTheme(false), dark: compileTheme(true) };

local config = {
  pinyin: {
    phone: { portrait: 'pinyinPortrait', landscape: 'pinyinLandscape' },
    pad: { portrait: 'iPadPinyinPortrait', landscape: 'iPadPinyinLandscape', floating: 'pinyinPortrait' },
  },
  numeric: {
    phone: { portrait: 'numericPortrait', landscape: 'numericLandscape' },
    pad: { portrait: 'iPadNumericPortrait', landscape: 'iPadNumericLandscape', floating: 'numericPortrait' },
  },
  symbolic: {
    phone: { portrait: 'symbolicPortrait', landscape: 'symbolicLandscape' },
    pad: { portrait: 'iPadPinyinPortrait', landscape: 'iPadPinyinLandscape', floating: 'symbolicPortrait' },
  },
};

{
  'config.yaml': std.manifestYamlDoc(config, indent_array_in_object=true, quote_keys=false),
} + {
  [scheme + '/' + name + '.yaml']: compiled[scheme][name]
  for scheme in ['light', 'dark']
  for name in names
}
