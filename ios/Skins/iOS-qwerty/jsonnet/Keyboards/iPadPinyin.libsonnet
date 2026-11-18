local Keys = import '../Constants/Keys.libsonnet';
local fonts = import '../Constants/Fonts.libsonnet';
local metrics = import '../Constants/Metrics.libsonnet';
local Button = import '../Components/Button.libsonnet';
local Layout = import '../Components/Layout.libsonnet';
local Preedit = import '../Components/Preedit.libsonnet';
local Style = import '../Components/Style.libsonnet';
local Theme = import '../Components/Theme.libsonnet';
local Toolbar = import '../Components/Toolbar.libsonnet';
local Widths = import '../Components/Widths.libsonnet';

local firstRowStyleName = 'firstRowStyle';

local upperLabel = { center: metrics.key.upperLabelCenter, fontSize: fonts.doubleLabel.iPad };
local lowerLabel = { center: metrics.key.lowerLabelCenter, fontSize: fonts.doubleLabel.iPad };

local cornerIconLeft = { center: { x: 0.25, y: 0.6 } };
local cornerIconRight = { center: { x: 0.75, y: 0.6 } };

local numberRow = [
  ['graveButton', 'tildeButton'],
  ['oneButton', 'exclamationMarkButton'],
  ['twoButton', 'atButton'],
  ['threeButton', 'hashButton'],
  ['fourButton', 'dollarButton'],
  ['fiveButton', 'percentButton'],
  ['sixButton', 'caretButton'],
  ['sevenButton', 'ampersandButton'],
  ['eightButton', 'asteriskButton'],
  ['nineButton', 'leftParenthesisButton'],
  ['zeroButton', 'rightParenthesisButton'],
  ['hyphenButton', 'emDashButton'],
  ['equalButton', 'plusButton'],
];

local topPunctuation = [
  ['leftChineseBracketButton', 'leftChineseAngleQuoteButton'],
  ['rightChineseBracketButton', 'rightChineseAngleQuoteButton'],
  ['ideographicCommaButton', 'verticalBarButton'],
];

local homePunctuation = [
  ['chineseSemicolonButton', 'chineseColonButton'],
  ['leftSingleQuoteButton', 'leftCurlyQuoteButton'],
];

local bottomPunctuation = [
  ['chineseCommaButton', 'leftBookTitleMarkButton'],
  ['chinesePeriodButton', 'rightBookTitleMarkButton'],
  ['forwardSlashButton', 'questionMarkEnButton'],
];

local letterRows = [
  { left: 'qwert', right: 'yuiop' },
  { left: 'asdfg', right: 'hjkl' },
  { left: 'zxcv', right: 'bnm' },
];

local keyName(c) = c + 'Button';
local names(table) = [entry[0] for entry in table];
local letterNames(row) = [keyName(c) for c in std.stringChars(row)];

local keyboardLayout = [
  Layout.row(names(numberRow) + ['backspaceButton'], firstRowStyleName),
  Layout.row(
    ['tabButton'] + letterNames(letterRows[0].left) + letterNames(letterRows[0].right)
    + names(topPunctuation)
  ),
  Layout.row(
    ['asciiModeButton'] + letterNames(letterRows[1].left) + letterNames(letterRows[1].right)
    + names(homePunctuation) + ['enterButton']
  ),
  Layout.row(
    ['leftshiftButton'] + letterNames(letterRows[2].left) + letterNames(letterRows[2].right)
    + names(bottomPunctuation) + ['rightshiftButton']
  ),
  Layout.row([
    'otherKeyboardButton',
    'numericButton',
    'spaceButton',
    'numericRightButton',
    'dismissButton',
  ]),
];

{
  new(isPortrait=false)::
    local orientation = if isPortrait then 'portrait' else 'landscape';
    local insets = metrics.keyInsets.iPad[orientation];

    local key(name, extra={}) = Button.alphabetic(name, Keys[name] + extra, insets, hint={});

    local dualKey(entry, extra={}) = key(entry[0], Widths.iPad.unit + extra {
      layers: [
        { name: entry[1], params: Keys[entry[1]] + upperLabel },
        { name: entry[0], params: Keys[entry[0]] + lowerLabel },
      ],
    });

    local letterKey(c, name=null) =
      local styleName = if name == null then keyName(c) else name;
      Button.alphabetic(
        styleName, Keys[keyName(c)] + Widths.iPad.unit, insets, hint={}
      );

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

      Style.merge([dualKey(entry) for entry in numberRow]),
      Button.system('backspaceButton', Keys.backspaceButton + Widths.iPad.backspace + cornerIconRight),

      Style.merge([
        letterKey(c)
        for row in letterRows
        for c in std.stringChars(row.left + row.right)
      ]),

      Button.system('tabButton', Keys.tabButton + Widths.iPad.tab + cornerIconLeft
                                ),
      Button.system('asciiModeButton', Keys.asciiModeButton + Widths.iPad.asciiMode),
      enterKey('enterButton', Widths.iPad.enter),
      shift('leftshiftButton'),
      shift('rightshiftButton'),

      Style.merge([
        dualKey(entry, {})
        for entry in topPunctuation + homePunctuation + bottomPunctuation
      ]),

      Button.system('otherKeyboardButton', Keys.otherKeyboardButton + Widths.iPad.bottom),
      Button.system('numericButton', Keys.numericButton + Widths.iPad.bottom),
      Button.alphabetic('spaceButton', Keys.spaceButton, insets, hint=null),
      Button.system('numericRightButton', Keys.numericButton + Widths.iPad.bottom),
      Button.system('dismissButton', Keys.dismissButton + Widths.iPad.bottom),

    ]),
}

