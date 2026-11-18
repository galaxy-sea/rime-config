// 临时状态探针：红色=false，绿色=true；未匹配时的显示由客户端决定。
// 编译：jsonnet -S -m ios/Skins/iOS-QWERTY ios/Skins/iOS-QWERTY/jsonnet/test-main.jsonnet
// 恢复普通主题：./scripts/compile-ios.sh
local path = 'light/pinyinPortrait.yaml';
local kb = std.parseJson((import 'main.jsonnet')[path]);

local get(o, k, d=null) =
  if std.type(o) == 'object' && std.objectHas(o, k) then o[k] else d;

local tests = {
  q: '$hasText',
  w: '$canDeleteBackward',
  e: '$documentContextBeforeInput',
  r: 'rime$programmer_english',
};

local character(k) = get(get(kb[k], 'action'), 'character');
local condition(key) = [
  { styleName: 'testStateFalse', conditionKey: key, conditionValue: false },
  { styleName: 'testStateTrue', conditionKey: key, conditionValue: true },
];

local result = kb + {
  testStateFalse: {
    buttonStyleType: 'geometry',
    normalColor: '#FF3030',
    highlightColor: '#FF3030',
    cornerRadius: 5,
  },
  testStateTrue: {
    buttonStyleType: 'geometry',
    normalColor: '#00C853',
    highlightColor: '#00C853',
    cornerRadius: 5,
  },
} + {
  [k]: { [field]: kb[k][field] for field in std.objectFields(kb[k]) if field != 'notification' } + {
    backgroundStyle:
      if character(k) == 'q'
      then 'testStateTrue'
      else condition(tests[character(k)]),
  }
  for k in std.objectFields(kb)
  if std.type(character(k)) == 'string' && std.objectHas(tests, character(k))
};

{ [path]: std.toString(result) }
