#!/bin/bash
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/Applications/Xcode.app/Contents/Developer/usr/bin:$PATH"

# GPU Monitor 启动脚本

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
DERIVED_DATA="$PROJECT_DIR/.derivedData"
APP_SRC="$DERIVED_DATA/Build/Products/Release/GPUMonitor.app"
APP_DEST="/Applications/GPUMonitor.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"

cd "$PROJECT_DIR"

# 创建配置目录
CONFIG_DIR="$HOME/.config/gpu_monitor"
CONFIG_FILE="$CONFIG_DIR/config.json"

if [ ! -d "$CONFIG_DIR" ]; then
    echo "创建配置目录: $CONFIG_DIR"
    mkdir -p "$CONFIG_DIR"
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "创建默认配置文件: $CONFIG_FILE"
    cat > "$CONFIG_FILE" << 'EOF'
{
  "refresh_interval": 30,
  "servers": [
    {
      "name": "GPU Server 1",
      "host": "192.168.1.100",
      "port": 22,
      "username": "root",
      "auth_method": "key",
      "key_path": "~/.ssh/id_rsa",
      "password": null
    }
  ],
  "idle_threshold": {
    "utilization": 5,
    "memory_mb": 500
  }
}
EOF
    echo ""
    echo "⚠️  请编辑配置文件以添加你的服务器信息："
    echo "   $CONFIG_FILE"
    echo ""
    read -p "按回车键继续..."
fi

echo "正在构建带桌面小组件的 GPUMonitor.app..."
SIGNING_ARGS=()
if [ -n "${DEVELOPMENT_TEAM:-}" ]; then
    SIGNING_ARGS=(
      -allowProvisioningUpdates
      CODE_SIGN_STYLE=Automatic
      DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM"
      CODE_SIGN_IDENTITY="Apple Development"
    )
elif ! /usr/bin/security find-identity -p codesigning -v 2>/dev/null | /usr/bin/grep -q "Apple Development"; then
    echo "提示：当前没有 Apple Development 签名身份。菜单栏 App 可以运行，但 macOS 小组件面板可能不会展示未正式签名的 Widget。"
    echo "      如需启用系统小组件，请在 Xcode 登录 Apple ID 后用 DEVELOPMENT_TEAM=你的TeamID ./run.sh 重新安装。"
fi

xcodebuild \
  -project GPUMonitorApp.xcodeproj \
  -scheme GPUMonitor \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  "${SIGNING_ARGS[@]}" \
  build >/tmp/gpumonitor_xcodebuild.log

echo "停止旧的 GPU Monitor 实例..."
pkill -x GPUMonitor 2>/dev/null || true
pkill -x GPUWidgetExtension 2>/dev/null || true

echo "清理旧的小组件注册..."
if [ -x "$LSREGISTER" ]; then
    for root in "$HOME/Library/Developer/Xcode/DerivedData" "$PROJECT_DIR/build" "$DERIVED_DATA" "/tmp/SM_gpu_DerivedData"; do
        [ -d "$root" ] || continue
        while IFS= read -r app; do
            "$LSREGISTER" -u "$app" 2>/dev/null || true
        done < <(find "$root" -name GPUMonitor.app -type d -prune 2>/dev/null)
    done

    while IFS= read -r app; do
        "$LSREGISTER" -u "$app" 2>/dev/null || true
    done < <(find /tmp -path "*/Build/Products/*/GPUMonitor.app" -type d -prune 2>/dev/null)
fi

echo "安装应用到 $APP_DEST..."
rm -rf "$APP_DEST"
ditto "$APP_SRC" "$APP_DEST"

echo "删除临时构建产物，避免小组件列表出现重复入口..."
rm -rf "$APP_SRC"
rm -rf "$DERIVED_DATA/Build/Products/Release/GPUWidgetExtension.appex"

if [ -x "$LSREGISTER" ]; then
    "$LSREGISTER" -f -R -trusted "$APP_DEST" 2>/dev/null || true
fi

if [ -d "$APP_DEST/Contents/PlugIns/GPUWidgetExtension.appex" ]; then
    pluginkit -a "$APP_DEST/Contents/PlugIns/GPUWidgetExtension.appex" 2>/dev/null || true
    pluginkit -e use -i com.gpumonitor.app.widget 2>/dev/null || true
fi

echo "启动 GPU Monitor..."
open "$APP_DEST"

echo ""
echo "已启动。若小组件列表仍显示重复项，请重新打开“编辑小组件”面板。"
