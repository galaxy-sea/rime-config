local Keys = import '../Constants/Keys.libsonnet';
local metrics = import '../Constants/Metrics.libsonnet';
local Button = import '../Components/Button.libsonnet';
local Layout = import '../Components/Layout.libsonnet';
local Preedit = import '../Components/Preedit.libsonnet';
local Style = import '../Components/Style.libsonnet';
local Theme = import '../Components/Theme.libsonnet';
local Toolbar = import '../Components/Toolbar.libsonnet';
local Widths = import '../Components/Widths.libsonnet';

local pairLeftOffset = { center: { x: 0.35 } };
local pairRightOffset = { center: { x: 0.65 } };

local rowOne = [
  ['leftChineseBracketButton', pairLeftOffset],
  ['rightChineseBracketButton', pairRightOffset],
  ['leftChineseBraceButton', pairLeftOffset],
  ['rightChineseBraceButton', pairRightOffset],
  ['hashButton', {}],
  ['percentButton', {}],
  ['caretButton', {}],
  ['asteriskButton', {}],
  ['plusButton', {}],
  ['equalButton', {}],
];

local rowTwo = [
  ['underscoreButton', {}],
  ['emDashButton', {}],
  ['backslashButton', {}],
  ['verticalBarButton', {}],
  ['tildeButton', {}],
  ['leftBookTitleMarkButton', pairLeftOffset],
  ['rightBookTitleMarkButton', pairRightOffset],
  ['graveButton', {}],
  ['ampersandButton', {}],
  ['middleDotButton', {}],
];

local rowThree = [
  ['ellipsisButton', {}],
  ['commaButton', {}],
  ['periodButton', {}],
  ['questionMarkEnButton', {}],
  ['exclamationMarkButton', {}],
  ['leftSingleQuoteButton', {}],
  ['rightSingleQuoteButton', {}],
];

local names(table) = [entry[0] for entry in table];

local keyboardLayout = [
  Layout.row(names(rowOne)),
  Layout.row(names(rowTwo)),
  Layout.row(['numericButton'] + names(rowThree) + ['backspaceButton']),
  Layout.row(['pinyinButton', 'spaceButton', 'enterButton']),
];

{
  new(isPortrait=true)::
    local orientation = if isPortrait then 'portrait' else 'landscape';
    local insets = metrics.keyInsets.iPhone[orientation];
    local hint = { size: metrics.hint.iPhoneSize };

    local key(entry, extraWidth) = Button.alphabetic(
      entry[0], Keys[entry[0]] + entry[1] + extraWidth, insets, hint
    );

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
        key(entry, Widths.iPhone.unit)
        for entry in rowOne + rowTwo[1:9] + rowThree
      ]),

      key(rowTwo[0], Widths.iPhone.unit),
      key(rowTwo[9], Widths.iPhone.unit),

      Button.system('numericButton',
        Keys.numericButton + Widths.iPhone.sideLeft),
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

