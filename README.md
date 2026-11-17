# rime-config
适用于macOS、iOS、iPadOS和Android的Personal Rime配置，提供统一的输入体验和自动部署功能。


###
```
rime-dotfiles/
├── shared/       # 雾凇拼音、词库、Lua 脚本
├── macos/        # 鼠须管
├── ios/          # 元书（iPhone、iPad）
├── android/      # 同文输入法
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

### 5. 更新工具

```bash
# 更新工具
uv tool upgrade pymobiledevice3
# 卸载工具
uv tool uninstall pymobiledevice3
```

### 相关链接

- [pymobiledevice3](https://github.com/doronz88/pymobiledevice3)
- [pymobiledevice3 官方文档](https://doronz88.github.io/pymobiledevice3/)
- [uv 官方文档](https://docs.astral.sh/uv/)
- [元书输入法](https://ihsiao.com/apps/hamster/v3/docs/)


###

