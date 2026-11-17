# 「极简」



## 使用说明

本皮肤内置「中 / En」切换按钮，可在中文输入与自定义英文输入模式之间切换。英文模式保留输入的大小写，支持英文词库补全，也可通过字母键上划输入大写字母。该模式由 `programmer_english` 控制，需配合本仓库的 RIME 自定义配置和 Lua 脚本使用。

## 目录结构

```
jsonnet/
  main.jsonnet            出哪些文件、config.yaml 怎么写
  Constants/
    Colors.libsonnet      配色（每项都是 { light, dark } 一对）
    Fonts.libsonnet       字号
    Metrics.libsonnet     高度、内边距、圆角
    Keys.libsonnet        按键表：一颗键「做什么」（动作、上下划）
  Components/
    Style.libsonnet       样式节点构造、深浅色解析、无用节点裁剪
    Layout.libsonnet      布局语法糖
    Widths.libsonnet      宽度表：一颗键「占一行的多少」
    Button.libsonnet      按键构造器（唯一拼装按键的地方）
    Theme.libsonnet       全皮肤共用的样式节点
    Preedit.libsonnet     预编辑区
    Toolbar.libsonnet     系统菜单/收起键盘 + 候选字栏
  Keyboards/              五份版面，各自只写「哪一行放哪些键」
```

## 自定义皮肤调整说明

- `jsonnet/Constants/Keys.libsonnet`：每颗键做什么。

  想调整某颗键的上下划动，在这里给它加 `swipeUpAction` / `swipeDownAction`。

- `jsonnet/Constants/Metrics.libsonnet`：各区域的高度、键与键之间的缝隙、圆角。

- `jsonnet/Components/Widths.libsonnet`：每颗键占一行的多少。

  **一行里所有键的宽度加起来必须正好是一整行**，多了少了都不会报错，但画出来一定是错的。

## 如何为单个按键设置颜色

在 `jsonnet/Constants/Keys.libsonnet` 中找到对应按键，加上颜色字段即可。
只有加了颜色的键才会单独生成一份键帽样式，其余的键共用同一份。

- `backgroundNormalColor`：背景颜色（正常状态）
- `backgroundHighlightColor`：背景颜色（按下状态）
- `foregroundNormalColor`：前景颜色（正常状态）
- `foregroundHighlightColor`：前景颜色（按下状态）

每种颜色都要分别给 light 与 dark 两个值，以适配系统主题。例如：

```jsonnet
{
  // ...
  qButton: letter('q') {
    backgroundNormalColor: { light: '#fff1bc', dark: '#FFFFFF' },
    backgroundHighlightColor: { light: '#699c78', dark: '#FFFFFF' },
    foregroundNormalColor: { light: '#DD105E', dark: '#FFFFFF' },
    foregroundHighlightColor: { light: '#BDBDD7', dark: '#FFFFFF' },
  },
  // ...
}
```

## 手机端编译

长按皮肤，选择「运行 main.jsonnet」
