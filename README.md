# rime-config
适用于macOS、iOS、iPadOS和Android的Personal Rime配置，提供统一的输入体验和自动部署功能。


###
```
rime-dotfiles/
├── shared/       # 雾凇拼音、词库、Lua 脚本
├── macos/        # Fcitx5 macOS
├── ios/          # 元书（iPhone、iPad、android）
├── scripts/      # 编译、同步、部署脚本
└── README.md
```


##
```shell
  brew install go-jsonnet fswatch rclone
```

## iOS / iPadOS 自动部署

使用 [pymobiledevice3](https://github.com/doronz88/pymobiledevice3)
将编译后的皮肤资源直接同步至元书输入法，支持 USB 和 Wi-Fi 无线连接。

### 1. 安装依赖（macOS）

推荐通过 uv 安装：

```bash
brew install uv
uv tool install --managed-python pymobiledevice3
uv tool update-shell
pymobiledevice3 version
```
首次连接：

1. 使用 USB 数据线连接 iPhone / iPad。
2. 解锁设备，选择「信任此电脑」。
3. 打开 macOS Finder，选择对应设备。
4. 勾选「连接 Wi-Fi 时显示此 iPhone / iPad」。
5. 点击「应用」。

配置完成后，Mac 与设备处于同一局域网即可尝试无线部署。

```bash
# 检查设备
pymobiledevice3 usbmux list
# 检查是否安装元书输入法：
pymobiledevice3 apps list --type User | grep -i hamster

# 元书 Bundle ID：
# `com.ihsiao.apps.Hamster3`
```

### 4. 编译并部署

```bash
chmod +x scripts/deploy-ios.sh
./scripts/deploy-ios.sh
```



### 相关链接

- [pymobiledevice3](https://github.com/doronz88/pymobiledevice3)
- [pymobiledevice3 官方文档](https://doronz88.github.io/pymobiledevice3/)
- [uv 官方文档](https://docs.astral.sh/uv/)
- [元书输入法](https://ihsiao.com/apps/hamster/v3/docs/)


## Android 上传

开启 USB 调试并授权电脑后运行：

```bash
bash scripts/deploy-android.sh
# 多设备时指定目标：
ANDROID_SERIAL=设备序列号 bash scripts/deploy-android.sh
```

复用 `ios/` 主题和配置，自动调用短语加解密及主题编译，通过 adb + root
自动检测 root 权限。有 root 时直接上传到当前 Android 用户的元书
`files/Documents/` 目录，需要在手机上授权 adb shell 使用 `su`。
无 root（或拒绝授权）时上传到 `Download/rime-config/`，再通过 MT 管理器的
「元书」存储入口手动复制：主题目录替换，配置和脚本按文件合并。
已有编译结果可设置 `SKIP_BUILD=1`。

主题目录按主题替换；`RimeUserData/` 和 `Scripts/` 按文件覆盖合并，不删除其他
Lua 文件及用户词频数据库。自动修正文件属主和 SELinux 标签，不上传
`.DS_Store`、短语密文、哈希缓存及临时文件。上传后在元书中部署并重载皮肤即可。

# 无法实现的功能

>ios/元书

| 功能      | iOS / iPadOS 原生术语                            | 元书皮肤功能需求                         |
| ------- | -------------------------------------------- | -------------------------------- |
| 回车键动态状态 | `hasText`、`enablesReturnKeyAutomatically`    | 支持根据输入框内容及回车键可用状态，动态切换按键样式和启用状态  |
| 删除键动态状态 | `documentContextBeforeInput`、`selectedText`  | 支持根据当前是否存在可删除内容，动态切换删除键样式        |
| 空格键文字过渡 | Keyboard View Lifecycle、Transition Animation | 支持键盘显示时自动触发前景样式切换，以及延时、淡入淡出等过渡效果 |

前两项可以归类为「输入框状态通知」，第三项可以归类为「键盘生命周期通知及过渡动画」。

至于具体通过 `ConditionStyle`、`Notification` 还是 `Animation` 实现，可以由 Author 根据元书自身的架构决定。




> ios
下文联想	根据已经上屏的文字预测下一个词	★★★★★
英文预测	单词补全、大小写匹配	★★★★★
自动纠错	容忍常见的字母误触	★★★★★
智能标点	根据中英文环境选择标点	★★★★☆
自动空格	英文单词上屏后补充空格	★★★★☆
光标移动	空格键滑动控制光标	★★★★☆
剪贴板操作	全选、复制、剪切、粘贴的快捷交互	★★★★☆
长按删除	支持合理的删除加速	★★★☆☆
输入统计	本地统计输入字数和频率	★★☆☆☆






### mac 安装雾凇拼音
RIME="$HOME/.local/share/fcitx5/rime"
TMP="$(mktemp -d)"

git clone --depth 1 \
  https://github.com/iDvel/rime-ice.git \
  "$TMP/rime-ice" &&

mkdir -p "$RIME" &&

rsync -av \
  --exclude='.git/' \
  --exclude='.github/' \
  --exclude='others/' \
  --exclude='build/' \
  --exclude='README.md' \
  --exclude='AGENTS.md' \
  --exclude='LICENSE' \
  --exclude='custom_phrase.txt' \
  --exclude='default.yaml' \
  --exclude='*.custom.yaml' \
  "$TMP/rime-ice/" "$RIME/" &&

{ test -f "$RIME/default.yaml" ||
  cp "$TMP/rime-ice/default.yaml" "$RIME/"; } &&

{ test -f "$RIME/custom_phrase.txt" ||
  cp "$TMP/rime-ice/custom_phrase.txt" "$RIME/"; } &&

rm -rf "$TMP"
