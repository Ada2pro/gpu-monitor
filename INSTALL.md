# 安装指南

本文档说明如何构建、签名、安装并启动 GPUMonitor。

## 一键安装

推荐使用：

```bash
DEVELOPMENT_TEAM=你的TeamID ./run.sh
```

脚本会执行：

- 构建 `GPUMonitor.app`
- 将应用安装到 `/Applications/GPUMonitor.app`
- 移除 DerivedData 里的临时 App，避免小组件库出现多个 `GPUMonitor`
- 停止旧的 `GPUMonitor` 和 `GPUWidgetExtension`
- 重新注册并启动应用

如果暂时不需要桌面 Widget，只需要菜单栏 App，也可以直接运行：

```bash
./run.sh
```

未使用 Apple Development 签名时，菜单栏 App 通常可以运行，但 macOS 小组件库可能搜不到 Widget。

## Team ID

WidgetKit 对第三方 Widget 的签名要求比较严格。建议使用 Apple Development 签名。

查看 Team ID 的方式：

1. 打开 Xcode
2. 进入 `Xcode > Settings > Accounts`
3. 登录 Apple ID
4. 选择账号，点击 `Manage Certificates...`
5. 创建 `Apple Development` 证书
6. 用下面命令查看证书里的 Team ID：

```bash
security find-certificate -c "Apple Development" -p | openssl x509 -noout -subject
```

输出中的 `OU=...` 就是 Team ID。

也可以查看可用签名身份：

```bash
security find-identity -p codesigning -v
```

## 双击启动

运行一次 `run.sh` 后，应用会安装到：

```text
/Applications/GPUMonitor.app
```

之后可以在 Finder 的“应用程序”中双击 `GPUMonitor` 启动。它是菜单栏应用，双击后不会弹出主窗口；顶部菜单栏出现 `GPU` 状态项表示启动成功。

## 配置文件

首次运行会创建：

```text
~/.config/gpu_monitor/config.json
```

可以用菜单里的“打开配置文件”，或手动打开：

```bash
open ~/.config/gpu_monitor/config.json
```

示例：

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
      "host": "connect.example.com",
      "port": 22,
      "username": "root",
      "auth_method": "key",
      "key_path": "~/.ssh/id_rsa",
      "password": null
    }
  ]
}
```

## SSH 验证

在使用应用前，先确认命令行可以连接服务器：

```bash
ssh -p 22 -i ~/.ssh/id_rsa root@connect.example.com nvidia-smi
```

如果这里失败，应用里也会失败。先修复 SSH key、端口、用户名或服务器安全组。

## 开机自启动

1. 打开“系统设置”
2. 进入“通用” > “登录项”
3. 点击 `+`
4. 选择 `/Applications/GPUMonitor.app`

## 重新安装

日常更新直接重新运行：

```bash
DEVELOPMENT_TEAM=你的TeamID ./run.sh
```

如果 Widget 仍显示旧内容，可以移除桌面上的 Widget 后重新添加；脚本已经会停止旧扩展进程并清理重复注册项。
