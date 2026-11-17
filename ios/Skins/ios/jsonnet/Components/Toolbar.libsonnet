local colors = import '../Constants/Colors.libsonnet';
local fonts = import '../Constants/Fonts.libsonnet';
local metrics = import '../Constants/Metrics.libsonnet';
local Layout = import 'Layout.libsonnet';
local Style = import 'Style.libsonnet';
local Theme = import 'Theme.libsonnet';

local candidateStyle = {
  highlightBackgroundColor: colors.candidateHighlightColor,
  preferredBackgroundColor: '#00000000',  // 首选候选词不单独显示底色
  preferredIndexColor: colors.candidateForegroundColor,
  preferredTextColor: colors.candidateForegroundColor,
  preferredCommentColor: colors.candidateForegroundColor,
  indexColor: colors.candidateForegroundColor,
  textColor: colors.candidateForegroundColor,
  commentColor: colors.candidateForegroundColor,
  indexFontSize: fonts.candidateIndex,
  textFontSize: fonts.candidateText,
  commentFontSize: fonts.candidateComment,
};

local iconButton(name, systemImageName, action, background=null, size={}) = {
  [name]: {
    action: action,
    foregroundStyle: name + 'ForegroundStyle',
    [if background != null then 'backgroundStyle']: background,
  } + (if size == {} then {} else { size: size }),
  [name + 'ForegroundStyle']: Style.systemImage({
    systemImageName: systemImageName,
    normalColor: colors.toolbarButtonForegroundColor,
    highlightColor: colors.toolbarButtonHighlightedForegroundColor,
    fontSize: fonts.candidateStateButton,
  }),
};

local menuButtonName = 'toolbarMenuButton';
local toolbarSpacerName = 'toolbarSpacer';
local dismissButtonName = 'toolbarDismissButton';

local horizontalName = 'horizontalCandidates';
local expandName = 'expandButton';
local verticalName = 'verticalCandidates';
local lastRowName = 'verticalLastRowStyle';
local pageUpName = 'verticalPageUpButtonStyle';
local pageDownName = 'verticalPageDownButtonStyle';
local returnName = 'verticalReturnButtonStyle';
local backspaceName = 'verticalBackspaceButtonStyle';

{
  new(horizontalInsets={ top: 8, left: 3, bottom: 1 }, verticalInsets=null):: Style.merge([
    {
      toolbarHeight: metrics.toolbar.height,
      toolbarStyle: { backgroundStyle: Theme.keyboardBackgroundName },
      toolbarLayout: [
        { HStack: { subviews:
          [{ Cell: menuButtonName }]
          + [{ Cell: toolbarSpacerName }, { Cell: dismissButtonName }]
        } },
      ],
      [toolbarSpacerName]: {},

      horizontalCandidatesStyle: {
        insets: horizontalInsets,
        backgroundStyle: Theme.keyboardBackgroundName,
      },
      horizontalCandidatesLayout: [Layout.row([horizontalName, expandName])],

      verticalCandidatesStyle: {
        [if verticalInsets != null then 'insets']: verticalInsets,
        backgroundStyle: Theme.keyboardBackgroundName,
      },
      verticalCandidatesLayout: [
        Layout.row([verticalName]),
        Layout.row([pageUpName, pageDownName, returnName, backspaceName], lastRowName),
      ],

      candidateContextMenu: [],

      [horizontalName]: {
        type: 'horizontalCandidates',
        candidateStyle: 'horizontalCandidateStyle',
      },
      horizontalCandidateStyle: candidateStyle,

      [verticalName]: {
        type: 'verticalCandidates',
        insets: { top: 8, left: 8, bottom: 8, right: 8 },
        maxRows: 5,
        maxColumns: 6,
        separatorColor: colors.candidateSeparatorColor,
        candidateStyle: 'verticalCandidateStyle',
      },
      verticalCandidateStyle: candidateStyle { insets: { top: 4, left: 6, bottom: 4, right: 6 } },

      [lastRowName]: { size: { height: 45 } },
    },
    iconButton(menuButtonName, 'square.grid.2x2.fill', { shortcut: '#keyboardMenu' }, null, { width: 44 }),
    iconButton(dismissButtonName, 'chevron.down', 'dismissKeyboard', null, { width: 44 }),
    iconButton(expandName, 'chevron.forward', { shortcut: '#candidatesBarStateToggle' })
    + { [expandName]+: { size: { width: 44 } } },
    iconButton(pageUpName, 'chevron.up', { shortcut: '#verticalCandidatesPageUp' }, Theme.systemBackgroundName),
    iconButton(pageDownName, 'chevron.down', { shortcut: '#verticalCandidatesPageDown' }, Theme.systemBackgroundName),
    iconButton(returnName, 'return', { shortcut: '#candidatesBarStateToggle' }, Theme.systemBackgroundName),
    iconButton(backspaceName, 'delete.left', 'backspace', Theme.systemBackgroundName),
  ]),
}

