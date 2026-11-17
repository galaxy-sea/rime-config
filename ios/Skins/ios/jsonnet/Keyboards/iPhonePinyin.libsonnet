local Keys = import '../Constants/Keys.libsonnet';
local metrics = import '../Constants/Metrics.libsonnet';
local Button = import '../Components/Button.libsonnet';
local Layout = import '../Components/Layout.libsonnet';
local Preedit = import '../Components/Preedit.libsonnet';
local Style = import '../Components/Style.libsonnet';
local Theme = import '../Components/Theme.libsonnet';
local Toolbar = import '../Components/Toolbar.libsonnet';
local Widths = import '../Components/Widths.libsonnet';

local widths = Widths.iPhone;

local letterRows = ['qwertyuiop', 'asdfghjkl', 'zxcvbnm'];
local keyName(c) = c + 'Button';
local letterNames(row) = [keyName(c) for c in std.stringChars(row)];

local keyboardLayout = [
  Layout.row(letterNames(letterRows[0])),
  Layout.row(letterNames(letterRows[1])),
  Layout.row(['shiftButton'] + letterNames(letterRows[2]) + ['backspaceButton']),
  Layout.row(['numericButton', 'spaceButton', 'enterButton']),
];

{
  new(isPortrait=true)::
    local orientation = if isPortrait then 'portrait' else 'landscape';
    local insets = metrics.keyInsets.iPhone[orientation];
    local hint = { size: metrics.hint.iPhoneSize };
    local key(name, extra={}) = Button.alphabetic(name, Keys[name] + extra, insets, hint);

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
        key(keyName(c), widths.unit)
        for c in std.stringChars(letterRows[0])
      ]),

      key('aButton', widths.homeRowLeft),
      Style.merge([
        key(keyName(c), widths.unit)
        for c in std.stringChars('sdfghjk')
      ]),
      key('lButton', widths.homeRowRight),

      Button.system('shiftButton',
        Keys.shiftButton + widths.sideLeft + {
          uppercasedStateForegroundStyle: Theme.shiftUppercasedForegroundName,
          capsLockedStateForegroundStyle: Theme.shiftCapsLockedForegroundName,
        }),
      Style.merge([
        key(keyName(c), widths.unit)
        for c in std.stringChars(letterRows[2])
      ]),
      Button.system('backspaceButton',
        Keys.backspaceButton + widths.sideRight),

      Button.system('numericButton',
        Keys.numericButton + widths.bottomSide),
      Button.alphabetic('spaceButton',
        Keys.spaceButton, insets, hint=null),
      Button.system('enterButton',
        Keys.enterButton + widths.bottomSide + {
          backgroundStyle: Theme.enterBackgroundStyle,
          foregroundStyle: Theme.enterForegroundStyle,
        }),
    ]),
}

