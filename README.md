# VidNexus

一个基于 Flutter 的视频分析应用。

## 环境要求

- Flutter SDK 3.9+
- Android Studio + Android SDK
- 后端服务运行在 `localhost:8000`

## 快速开始

```bash
# 安装依赖
flutter pub get

# 在模拟器上运行（默认连接 http://10.0.2.2:8000）
flutter run

# 在模拟器上运行（指定后端地址）
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

---

## Android 真机接入指南

### 一、首次配置（仅需一次）

#### 1. 手机端开启开发者选项

- 打开 **设置 → 我的设备 → 全部参数**
- 连续点击 **MIUI 版本**（或 **版本号**）7 次，直到提示"已进入开发者模式"

#### 2. 开启必要的调试开关

进入 **设置 → 更多设置 → 开发者选项**，开启以下选项：

| 开关 | 说明 |
|------|------|
| **USB 调试** | 允许电脑通过 USB 与手机通信 |
| **USB 安装** | 允许通过 USB 安装应用（小米/HyperOS 必须开启） |
| **USB 调试（安全设置）** | 部分机型需要通过 USB 安装应用时需要 |

> **注意**：小米/HyperOS 手机除了 USB 调试外，还有独立的"USB 安装"开关，必须同时开启，否则会报 `INSTALL_FAILED_USER_RESTRICTED`。

#### 3. 连接手机到电脑

1. 用 USB 数据线连接手机和电脑
2. 手机上会弹出 **"允许 USB 调试"** 对话框，勾选 **"始终允许"** 后点击 **允许**
3. 如果手机通知栏显示 USB 连接模式为"仅充电"，改为 **"传输文件 (MTP)"**

#### 4. 验证连接

```bash
adb devices
```

预期输出：
```
List of devices attached
e8f2a035    device
```

> 如果显示 `unauthorized`，说明手机上还没点"允许 USB 调试"，检查手机屏幕。

---

### 二、首次启动（需编译部署）

```bash
# 1. 建立端口转发（手机 localhost:8000 → 电脑 localhost:8000）
adb reverse tcp:8000 tcp:8000

# 2. 编译并部署到真机（首次会自动持久化后端地址）
flutter run -d e8f2a035 --dart-define=API_BASE_URL=http://localhost:8000
```

> 运行成功后，后端地址 `http://localhost:8000` 会被自动保存到手机本地存储，**此步骤仅首次需要**。

`flutter run` 启动后可用的快捷键：

| 按键 | 功能 |
|------|------|
| `r` | 热重载（Hot reload） |
| `R` | 热重启（Hot restart） |
| `d` | 分离（断开 flutter run，应用保持运行） |
| `q` | 退出应用 |
| `c` | 清屏 |

---

### 三、日常启动（无需编译）

如果只是打开应用测试功能（不改代码）：

```bash
# 1. 建立端口转发（每次重新插拔 USB 后需要重新执行）
adb reverse tcp:8000 tcp:8000

# 2. 直接在手机上点击 VidNexus 图标打开即可

```

> 因为首次启动时已经持久化了后端地址，之后只需确保端口转发已建立，直接打开 App 即可。

---

### 四、查看调试日志

```bash
# 实时查看 Flutter 应用日志
flutter logs
```

或在 Android Studio 中：**底部 Logcat 标签页** → 过滤输入 `flutter`。

---

### 五、常见问题

#### Q: `adb devices` 看不到设备？

```bash
# 重启 ADB 服务
adb kill-server
adb start-server
adb devices
```

如果仍不行，检查：
- USB 线是否支持数据传输（部分充电线不行）
- 手机是否开启了 USB 调试
- 换一个 USB 接口

#### Q: 安装时报 `INSTALL_FAILED_USER_RESTRICTED`？

小米/HyperOS 手机需要额外开启 **"USB 安装"**（在开发者选项中）。

#### Q: 应用连不上后端（`Connection refused` / `Connection reset by peer`）？

检查端口转发是否生效：
```bash
adb reverse --list
# 应输出: UsbFfs tcp:8000 tcp:8000
```

如未生效，重新执行：
```bash
adb reverse tcp:8000 tcp:8000
```

#### Q: 模拟器和真机的地址有什么区别？

| 平台 | 后端地址 | 原因 |
|------|---------|------|
| Android 模拟器 | `http://10.0.2.2:8000` | Android 模拟器将宿主机的 localhost 映射到此 IP |
| Android 真机 (USB) | `http://localhost:8000` | 通过 `adb reverse` 将手机本地端口转发到电脑 |

---

### 六、完整启动流程总结

```bash
# 每次连接手机后执行以下步骤：

# Step 1: 确认设备已连接
adb devices

# Step 2: 建立端口转发
adb reverse tcp:8000 tcp:8000

# Step 3: 启动应用（首次需要，之后直接在手机上打开）
flutter run -d e8f2a035 --dart-define=API_BASE_URL=http://localhost:8000
```

---

## 模拟器启动

```bash
# 启动模拟器（使用默认地址 10.0.2.2）
flutter run

# 或指定后端地址
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

模拟器默认地址 `http://10.0.2.2:8000` 在 `lib/services/api/api_config.dart` 中定义，无需额外配置。