#!/usr/bin/env bash
# 为 Flutter SDK 内 packages/flutter_tools/gradle/settings.gradle.kts 注入阿里云镜像，
# 解决 assembleDebug 仍从 repo.maven.apache.org 下载 Kotlin/依赖过慢的问题。
# Flutter 升级后若合并冲突，可重新执行本脚本或手动对照修改。
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  echo "未找到 flutter 命令，请先加入 PATH。" >&2
  exit 1
fi

FLUTTER_BIN=$(command -v flutter)
# flutter 多为 .../bin/flutter
SDK=$(cd "$(dirname "$FLUTTER_BIN")/.." && pwd)
TARGET="$SDK/packages/flutter_tools/gradle/settings.gradle.kts"

if [[ ! -f "$TARGET" ]]; then
  echo "找不到: $TARGET" >&2
  exit 1
fi

if grep -q 'maven.aliyun.com/repository/central' "$TARGET"; then
  echo "已包含阿里云 central 镜像，跳过: $TARGET"
  exit 0
fi

MARKER='maven { url = uri("https://maven.aliyun.com/repository/google") }'
if grep -q "$MARKER" "$TARGET"; then
  echo "已打过补丁，跳过。"
  exit 0
fi

cp "$TARGET" "${TARGET}.bak.$(date +%Y%m%d%H%M%S)"

python3 << 'PY' "$TARGET"
import pathlib, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
needle = """    repositories {
        google()
        mavenCentral()
"""
insert = """    repositories {
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/central") }
        maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
        google()
        mavenCentral()
"""
if needle not in text:
    print("文件结构已变化，请手动编辑:", path, file=sys.stderr)
    sys.exit(1)
path.write_text(text.replace(needle, insert, 1), encoding="utf-8")
print("已写入镜像:", path)
PY

echo "完成。可执行: cd android && ./gradlew --stop && cd .. && flutter run"
