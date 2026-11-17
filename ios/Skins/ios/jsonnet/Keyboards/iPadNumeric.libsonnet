local Keys = import '../Constants/Keys.libsonnet';
local metrics = import '../Constants/Metrics.libsonnet';
local Button = import '../Components/Button.libsonnet';
local Layout = import '../Components/Layout.libsonnet';
local Preedit = import '../Components/Preedit.libsonnet';
local Style = import '../Components/Style.libsonnet';
local Theme = import '../Components/Theme.libsonnet';
local Toolbar = import '../Components/Toolbar.libsonnet';
local Widths = import '../Components/Widths.libsonnet';

local firstRowStyleName = 'firstRowStyle';

local cornerIconLeft = { center: { x: 0.25, y: 0.6 } };
local cornerIconRight = { center: { x: 0.75, y: 0.6 } };

local numberRow = ['periodButton', 'oneButton', 'twoButton', 'threeButton', 'fourButton', 'fiveButton',
                   'sixButton', 'sevenButton', 'eightButton', 'nineButton', 'zeroButton',
                   'lessThanButton', 'greaterThanButton'];

local rowTwo = {
  left: ['leftChineseBracketButton', 'rightChineseBracketButton',
         'leftChineseBraceButton', 'rightChineseBraceButton', 'hashButton'],
  right: ['percentButton', 'caretButton', 'asteriskButton', 'plusButton', 'equalButton'],
  hidden: ['backslashButton', 'verticalBarButton', 'underscoreButton'],
};

local rowThree = {
  left: ['hyphenButton', 'forwardSlashButton', 'chineseColonButton',
         'chineseSemicolonButton', 'leftChineseParenthesisButton'],
  right: ['rightChineseParenthesisButton', 'dollarButton', 'ampersandButton',
          'atButton', 'leftSingleQuoteButton'],
  hidden: ['euroButton'],
};

local rowFour = {
  left: ['ellipsisButton', 'middleDotButton', 'chinesePeriodButton', 'chineseCommaButton'],
  right: ['ideographicCommaButton', 'questionMarkButton', 'chineseExclamationMarkButton', 'tildeButton'],
  hidden: ['leftCurlyQuoteButton', 'rightCurlyQuoteButton'],
};

local keyboardLayout = [
  Layout.row(numberRow + ['backspaceButton'], firstRowStyleName),
  Layout.row(['tabButton'] + rowTwo.left + rowTwo.right + rowTwo.hidden),
  Layout.row(['asciiModeButton'] + rowThree.left + rowThree.right
             + rowThree.hidden + ['enterButton']),
  Layout.row(['leftshiftButton'] + rowFour.left + rowFour.right
             + rowFour.hidden + ['rightshiftButton']),
  Layout.row([
    'otherKeyboardButton',
    'pinyinButton',
    'spaceButton',
    'pinyinRightButton',
    'dismissButton',
  ]),
];

{
  new(isPortrait=false)::
    local orientation = if isPortrait then 'portrait' else 'landscape';
    local insets = metrics.keyInsets.iPad[orientation];
    local key(name, extra={}) = Button.alphabetic(name, Keys[name] + Widths.iPad.unit + extra, insets, hint={});

    local shift(name) = Button.system(name, Keys.shiftButton + Widths.iPad.shift {
      uppercasedStateForegroundStyle: Theme.shiftUppercasedForegroundName,
      capsLockedStateForegroundStyle: Theme.shiftCapsLockedForegroundName,
    });

    local enterKey(name, size) = Button.system(name, Keys.enterButton + size {
      backgroundStyle: Theme.enterBackgroundStyle,
      foregroundStyle: Theme.enterForegroundStyle,
    });

    Style.merge([
      Preedit.new(metrics.iPadSideInsets),
      Toolbar.new(metrics.iPadSideInsets, metrics.iPadSideInsets),
      Theme.shared(insets),
      {
        keyboardHeight: metrics.keyboardHeight.iPad[orientation],
        keyboardStyle: { backgroundStyle: Theme.keyboardBackgroundName },
        keyboardLayout: keyboardLayout,
        [firstRowStyleName]: {
          size: { height: metrics.iPadFirstRowHeight[orientation] },
        },
      },

      Style.merge([key(name) for name in numberRow]),

      Style.merge([
        key(name)
        for row in [rowTwo, rowThree, rowFour]
        for name in row.left + row.right
      ]),
      Style.merge([
        key(name, {})
        for row in [rowTwo, rowThree, rowFour]
        for name in row.hidden
      ]),

      Button.system('backspaceButton', Keys.backspaceButton + Widths.iPad.backspace + cornerIconRight),
      Button.system('tabButton', Keys.tabButton + Widths.iPad.tab + cornerIconLeft
                                ),
      Button.system('asciiModeButton', Keys.asciiModeButton + Widths.iPad.asciiMode),
      enterKey('enterButton', Widths.iPad.enter),
      shift('leftshiftButton'),
      shift('rightshiftButton'),

      Button.system('otherKeyboardButton', Keys.otherKeyboardButton + Widths.iPad.bottom),
      Button.system('pinyinButton', Keys.pinyinButton + Widths.iPad.bottom),
      Button.alphabetic('spaceButton', Keys.spaceButton, insets, hint=null),
      Button.system('pinyinRightButton', Keys.pinyinButton + Widths.iPad.bottom),
      Button.system('dismissButton', Keys.dismissButton + Widths.iPad.bottom),

    ]),
}

