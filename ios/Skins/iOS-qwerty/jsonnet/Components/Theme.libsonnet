// 主题层：全皮肤共用的那几个样式节点，以及引用它们的名字。
//
// 上层（Button / Keyboards）只写名字，具体长什么样全部由本文件决定；
// 反过来，本文件不知道有哪些键。
local colors = import '../Constants/Colors.libsonnet';
local fonts = import '../Constants/Fonts.libsonnet';
local metrics = import '../Constants/Metrics.libsonnet';
local Style = import 'Style.libsonnet';

// ===== 约定的样式名 =====
local keyboardBackgroundName = 'keyboardBackgroundStyle';
local alphabeticBackgroundName = 'alphabeticButtonBackgroundStyle';
local systemBackgroundName = 'systemButtonBackgroundStyle';
local blueBackgroundName = 'blueButtonBackgroundStyle';
local blueForegroundName = 'blueButtonForegroundStyle';
local enterForegroundName = 'enterButtonForegroundStyle';
local hintBackgroundName = 'alphabeticHintBackgroundStyle';
local commitCandidateForegroundName = 'commitCandidateForegroundStyle';
local shiftUppercasedForegroundName = 'shiftButtonUppercasedForegroundStyle';
local shiftCapsLockedForegroundName = 'shiftButtonCapsLockedForegroundStyle';

// ===== 回车键随 returnKeyType 换色 =====
// 普通换行使用字母键背景，其余类型统一蓝底白字。
local plainReturnKeyTypes = [0];
local blueReturnKeyTypes = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];

local enterBackgroundStyle = [
  Style.when('$returnKeyType', plainReturnKeyTypes, alphabeticBackgroundName),
  Style.when('$returnKeyType', blueReturnKeyTypes, blueBackgroundName),
];

// 顺序对应 returnKeyType 0～11。
local returnKeyIcons = [
  'return', 'arrow.right', 'magnifyingglass', 'arrow.right',
  'arrow.right.to.line', 'location.fill', 'magnifyingglass', 'arrow.up',
  'magnifyingglass', 'checkmark', 'phone.fill', 'arrow.right',
];
local androidReturnKeyIcons = [
  'keyboard_return', 'arrow_forward', 'search', 'arrow_forward',
  'last_page', 'navigation', 'search', 'arrow_upward',
  'search', 'check', 'phone', 'arrow_forward',
];
local returnIcon(i) = { ios: returnKeyIcons[i], android: androidReturnKeyIcons[i] };
local returnIconName(i) = 'returnKey' + std.toString(i) + 'ForegroundStyle';
local enterForegroundStyle = [
  Style.when('$returnKeyType', [i], returnIconName(i))
  for i in std.range(0, 11)
];

// 一份按键背景：圆角矩形 + 底部立体边缘。insets 决定键与键之间的缝隙，
// 随设备与方向变化，所以由调用方传进来。
local buttonBackground(insets, normalColor, highlightColor) = Style.geometry({
  insets: insets,
  normalColor: normalColor,
  highlightColor: highlightColor,
  cornerRadius: metrics.key.cornerRadius,
  normalLowerEdgeColor: colors.lowerEdgeOfButtonNormalColor,
  highlightLowerEdgeColor: colors.lowerEdgeOfButtonHighlightColor,
});

{
  keyboardBackgroundName: keyboardBackgroundName,
  alphabeticBackgroundName: alphabeticBackgroundName,
  systemBackgroundName: systemBackgroundName,
  blueBackgroundName: blueBackgroundName,
  blueForegroundName: blueForegroundName,
  enterForegroundName: enterForegroundName,
  hintBackgroundName: hintBackgroundName,
  shiftUppercasedForegroundName: shiftUppercasedForegroundName,
  shiftCapsLockedForegroundName: shiftCapsLockedForegroundName,

  enterBackgroundStyle: enterBackgroundStyle,
  enterForegroundStyle: enterForegroundStyle,

  buttonBackground: buttonBackground,

  // 所有键盘都要带上的共享样式节点。insets 随设备与方向变化，所以做成参数。
  shared(insets):: {
    // 键盘底板。03 约合 0.01 的不透明度，几乎全透，透出系统键盘背景。
    [keyboardBackgroundName]: Style.geometry({ normalColor: colors.keyboardBackgroundColor }),

    [alphabeticBackgroundName]: buttonBackground(
      insets, colors.standardButtonBackgroundColor, colors.standardButtonHighlightedBackgroundColor
    ),
    [systemBackgroundName]: buttonBackground(
      insets, colors.systemButtonBackgroundColor, colors.systemButtonHighlightedBackgroundColor
    ),
    [blueBackgroundName]: buttonBackground(
      insets, colors.blueButtonBackgroundColor, colors.blueButtonHighlightedBackgroundColor
    ),

    // 预编辑中的空格键：键面从「space 图标」换成「选定」两个字，点一下上屏首选。
    [commitCandidateForegroundName]: Style.text({
      normalColor: colors.standardButtonForegroundColor,
      highlightColor: colors.standardButtonHighlightedForegroundColor,
      fontSize: fonts.systemKeyText,
      text: '选定',
    }),

    // 短按气泡的底：与按键同色，靠一条细描边分界
    [hintBackgroundName]: Style.geometry({
      normalColor: colors.standardCalloutBackgroundColor,
      normalBorderColor: colors.standardCalloutBorderColor,
      borderSize: 0.5,
      cornerRadius: metrics.hint.cornerRadius,
    }),

    // Shift 的两个状态态前景
    [shiftUppercasedForegroundName]: Style.systemImage({
      systemImageName: 'shift.fill',
      normalColor: colors.systemButtonForegroundColor,
      highlightColor: colors.systemButtonHighlightedForegroundColor,
      fontSize: fonts.systemKeyImage,
    }),
    [shiftCapsLockedForegroundName]: Style.systemImage({
      systemImageName: 'capslock.fill',
      normalColor: colors.systemButtonForegroundColor,
      highlightColor: colors.systemButtonHighlightedForegroundColor,
      fontSize: fonts.systemKeyImage,
    }),

    // ===== 通知：外部状态变了，按键换一套样式 =====
    // returnKeyType 变化时回车键换色；预编辑开始 / 结束时回车键与空格键换样式。
    preeditChangedForEnterButtonNotification: {
      notificationType: 'preeditChanged',
      backgroundStyle: enterBackgroundStyle,
      foregroundStyle: enterForegroundStyle,
    },
    preeditChangedForSpaceButtonNotification: {
      notificationType: 'preeditChanged',
      backgroundStyle: alphabeticBackgroundName,
      foregroundStyle: commitCandidateForegroundName,
    },
  } + {
    [returnIconName(i)]: Style.systemImage({
      systemImageName: returnIcon(i),
      // 按下时继续显示同一图标，避免客户端使用空的高亮图标。
      highlightSystemImageName: returnIcon(i),
      fontSize: 20,
      fontWeight: 'medium',
      normalColor: if i == 0 then colors.systemButtonForegroundColor else '#FFFFFF',
      highlightColor: if i == 0 then colors.systemButtonHighlightedForegroundColor else '#FFFFFF',
    })
    for i in std.range(0, 11)
  } + {
    ['returnKeyType' + std.toString(i) + 'ChangedNotification']: {
      notificationType: 'returnKeyType',
      returnKeyType: [i],
      backgroundStyle: if i == 0 then alphabeticBackgroundName else blueBackgroundName,
      foregroundStyle: returnIconName(i),
    }
    for i in std.range(0, 11)
  },
}
