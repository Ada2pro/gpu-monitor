# GPU Server Monitor

原生 macOS GPU 监控工具。主应用常驻菜单栏，通过 SSH 连接远程服务器运行 `nvidia-smi`；桌面 Widget 显示当前服务器是否可用、空闲 GPU 数量和更新时间。

## 功能

- 菜单栏显示整体 GPU 状态
- 支持多台远程服务器
- 显示 GPU 型号、显存、温度、利用率
- 可从菜单一键在 Terminal 或 VSCode 中连接服务器
- 提供 macOS 桌面 Widget
- 支持双击 `/Applications/GPUMonitor.app` 启动

## 快速开始

1. 安装到 `/Applications` 并启动：

```bash
DEVELOPMENT_TEAM=你的TeamID ./run.sh
```

如果只需要菜单栏功能，可以直接运行：

```bash
./run.sh
```

2. 编辑配置文件：

```bash
open ~/.config/gpu_monitor/config.json
```

3. 确认本机可以连接服务器：

```bash
ssh -p 22 username@host nvidia-smi
```

4. 添加桌面 Widget：

右键桌面空白处，选择“编辑小组件”，搜索 `GPU Monitor`，拖到桌面。

## 配置示例

```json
{
  "refresh_interval": 30,
  "idle_threshold": {
    "utilization": 5,
    "memory_mb": 500
  },
  "servers": [
    {
      "name": "GPU Server",
      "host": "gpu.example.com",
      "port": 22,
      "username": "root",
      "auth_method": "key",
      "key_path": "~/.ssh/id_rsa",
      "password": null
    }
  ]
}
```

`idle_threshold` 也兼容旧格式：

```json
"idle_threshold": 10
```

旧格式表示 GPU 利用率和显存占用都低于 10% 时视为空闲。

## 文档

- [INSTALL.md](INSTALL.md)：安装、签名、双击启动、开机自启动
- [USAGE.md](USAGE.md)：日常使用、小组件、排障

## 项目结构

```text
SM_gpu/
├── GPUMonitor/                  # 主菜单栏 App
├── GPUWidget/                   # Widget Extension
├── GPUMonitorApp.xcodeproj      # Xcode 工程
├── Sources/                     # 早期 SwiftPM 源码保留
├── config.example.json          # 配置示例
├── run.sh                       # 构建、安装、启动脚本
├── INSTALL.md
├── USAGE.md
└── README.md
```

当前推荐入口是 Xcode 工程和 `run.sh`，因为桌面 Widget 需要打包进 `.app`。

## 系统要求

- macOS 13.0+
- Xcode 或 Xcode Command Line Tools
- 远程服务器已安装 NVIDIA 驱动和 `nvidia-smi`
- 推荐配置 SSH key 登录
