local Keys = import '../Constants/Keys.libsonnet';
local metrics = import '../Constants/Metrics.libsonnet';
local Button = import '../Components/Button.libsonnet';
local Layout = import '../Components/Layout.libsonnet';
local Preedit = import '../Components/Preedit.libsonnet';
local Style = import '../Components/Style.libsonnet';
local Theme = import '../Components/Theme.libsonnet';
local Toolbar = import '../Components/Toolbar.libsonnet';
local Widths = import '../Components/Widths.libsonnet';

local cjkPunctuationOffset = { center: { x: 0.55 } };

local rowOne = ['oneButton', 'twoButton', 'threeButton', 'fourButton', 'fiveButton',
                'sixButton', 'sevenButton', 'eightButton', 'nineButton', 'zeroButton'];

local rowTwo = ['hyphenButton', 'forwardSlashButton', 'colonButton', 'semicolonButton',
                'leftParenthesisButton', 'rightParenthesisButton', 'dollarButton', 'atButton',
                'leftCurlyQuoteButton', 'rightCurlyQuoteButton'];

local rowThreeCjk = ['chinesePeriodButton', 'chineseCommaButton', 'ideographicCommaButton'];
local rowThreeAscii = ['hashButton', 'questionMarkEnButton', 'exclamationMarkButton', 'periodButton'];
local rowThree = rowThreeCjk + rowThreeAscii;

local keyboardLayout = [
  Layout.row(rowOne),
  Layout.row(rowTwo),
  Layout.row(['symbolicButton'] + rowThree + ['backspaceButton']),
  Layout.row(['pinyinButton', 'spaceButton', 'enterButton']),
];

{
  new(isPortrait=true)::
    local orientation = if isPortrait then 'portrait' else 'landscape';
    local insets = metrics.keyInsets.iPhone[orientation];
    local hint = { size: metrics.hint.iPhoneSize };

    local key(name, extraWidth) =
      local offset = if std.count(rowThreeCjk, name) > 0 then cjkPunctuationOffset else {};
      Button.alphabetic(name, Keys[name] + offset + extraWidth, insets, hint);

    Style.merge([
      Preedit.new(),
      Toolbar.new(),
      Theme.shared(insets),
      {
        keyboardHeight: metrics.keyboardHeight.iPhone[orientation],
        keyboardStyle: { backgroundStyle: Theme.keyboardBackgroundName },
        keyboardLayout: keyboardLayout,
      },

      Style.merge([
        key(name, Widths.iPhone.unit)
        for name in rowOne
      ]),

      key(rowTwo[0], Widths.iPhone.unit),
      Style.merge([
        key(name, Widths.iPhone.unit)
        for name in rowTwo[1:9]
      ]),
      key(rowTwo[9], Widths.iPhone.unit),

      Button.system('symbolicButton',
        Keys.symbolicButton + Widths.iPhone.sideLeft),
      Style.merge([key(name, Widths.iPhone.unit) for name in rowThree]),
      Button.system('backspaceButton',
        Keys.backspaceButton + Widths.iPhone.sideRight),

      Button.system('pinyinButton',
        Keys.pinyinButton + Widths.iPhone.bottomSide),
      Button.alphabetic('spaceButton',
        Keys.spaceButton, insets, hint=null),
      Button.system('enterButton',
        Keys.enterButton + Widths.iPhone.bottomSide + {
          backgroundStyle: Theme.enterBackgroundStyle,
          foregroundStyle: Theme.enterForegroundStyle,
        }),
    ]),
}

