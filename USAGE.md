# 使用指南

## 菜单栏

启动后，顶部菜单栏会出现 `GPU` 状态项。

状态含义：

- 绿色：所有 GPU 空闲
- 黄色：部分 GPU 空闲
- 红色：所有 GPU 都在使用
- 灰色：服务器离线或连接失败

点击菜单栏 `GPU` 可以查看：

- 服务器连接状态
- GPU 型号
- 显存使用量和总显存
- 温度
- GPU 利用率
- 在 Terminal 中打开 SSH
- 在 VSCode 中打开 SSH
- 手动刷新
- 打开配置文件
- 退出应用

## 桌面 Widget

添加方式：

1. 右键点击桌面空白处
2. 选择“编辑小组件”
3. 搜索 `GPU` 或 `GPU Monitor`
4. 将 `GPU Monitor` 拖到桌面

Widget 会显示：

- 服务器名称
- 服务器 host
- 空闲 GPU 数量
- 最后更新时间

Widget 数据由主 App 写入共享文件。主 App 每次刷新 GPU 状态后会通知 WidgetKit 更新；系统也会按时间线周期自动刷新。

## 配置

配置文件：

```text
~/.config/gpu_monitor/config.json
```

推荐格式：

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

字段说明：

- `refresh_interval`：主 App 刷新间隔，单位秒
- `idle_threshold.utilization`：低于该 GPU 利用率视为空闲
- `idle_threshold.memory_mb`：低于该显存占用视为空闲
- `servers`：服务器列表
- `auth_method`：当前主要使用系统 `ssh`，推荐 key 登录

## 多服务器

在 `servers` 数组中加入多个条目即可：

```json
{
  "refresh_interval": 30,
  "idle_threshold": {
    "utilization": 5,
    "memory_mb": 500
  },
  "servers": [
    {
      "name": "GPU Server A",
      "host": "gpu-a.example.com",
      "port": 22,
      "username": "root",
      "auth_method": "key",
      "key_path": "~/.ssh/id_rsa",
      "password": null
    },
    {
      "name": "GPU Server B",
      "host": "gpu-b.example.com",
      "port": 22022,
      "username": "root",
      "auth_method": "key",
      "key_path": "~/.ssh/id_rsa",
      "password": null
    }
  ]
}
```

## 常见问题

### Widget 搜不到

通常是签名问题。使用 Apple Development 签名重新安装：

```bash
DEVELOPMENT_TEAM=你的TeamID ./run.sh
```

然后重新打开“编辑小组件”面板，搜索 `GPU Monitor`。

### Widget 显示“暂无数据”

先确认主 App 正在运行，并且菜单栏里已经能看到服务器状态。然后：

```bash
ls -l ~/Library/Containers/com.gpumonitor.app.widget/Data/Documents/server-statuses.json
cat ~/Library/Containers/com.gpumonitor.app.widget/Data/Documents/server-statuses.json
```

如果文件存在且有数据，移除桌面 Widget 后重新添加一次。

### 菜单栏显示离线

用同样的 SSH 参数手动测试：

```bash
ssh -p 22 -i ~/.ssh/id_rsa root@gpu.example.com nvidia-smi
```

如果命令行失败，检查：

- host 是否正确
- port 是否正确
- username 是否正确
- key path 是否正确
- 服务器是否允许 SSH
- 服务器是否安装 NVIDIA 驱动

### 出现多个 GPUMonitor

重新运行：

```bash
DEVELOPMENT_TEAM=你的TeamID ./run.sh
```

脚本会清理临时构建产物和旧注册项。之后关闭并重新打开“编辑小组件”面板。

### 双击没有窗口

这是正常行为。GPUMonitor 是菜单栏 App，双击后只会在顶部菜单栏显示 `GPU` 状态项。

## 数据共享位置

主 App 会把 Widget 数据写到：

```text
~/Library/Group Containers/group.com.gpumonitor.shared/server-statuses.json
~/Library/Containers/com.gpumonitor.app.widget/Data/Documents/server-statuses.json
```

第二个路径是给 Widget 沙盒读取的兼容存储。
