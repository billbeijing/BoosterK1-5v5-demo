#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname -- "$SCRIPT_DIR")"

is_valid_ipv4() {
    local ip="$1"
    local -a octets
    local octet

    [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
    IFS='.' read -r -a octets <<< "$ip"
    [[ ${#octets[@]} -eq 4 ]] || return 1

    for octet in "${octets[@]}"; do
        [[ ${#octet} -le 3 ]] || return 1
        # 10# 强制按十进制处理带前导零的数字。
        (( 10#$octet >= 0 && 10#$octet <= 255 )) || return 1
    done
}

while true; do
    IFS= read -r -p "请输入 Game Controller IPv4 地址（输入 1 退出）：" GC_IP || {
        printf '\n未读取到输入，已退出。\n'
        exit 1
    }

    if [[ "$GC_IP" == "1" ]]; then
        echo "已退出，未修改任何文件。"
        exit 0
    fi

    if is_valid_ipv4 "$GC_IP"; then
        break
    fi

    echo "IP 格式错误，请输入有效的 IPv4 地址（例如 192.168.1.112），或输入 1 退出。"
done

python3 - "$PROJECT_DIR" "$GC_IP" <<'PY'
import os
import re
import shutil
import stat
import sys
import tempfile
from pathlib import Path

project_dir = Path(sys.argv[1])
new_ip = sys.argv[2].encode("ascii")
brain_config_dir = project_dir / "brain_config"
main_config = project_dir / "src" / "brain" / "config" / "config.yaml"
launch_file = project_dir / "src" / "game_controller" / "launch" / "launch.py"

game_control_pattern = re.compile(
    rb'(?m)^([ \t]*game_control_ip:[ \t]*")[0-9]+(?:\.[0-9]+){3}("[^\r\n]*)$'
)
white_list_pattern = re.compile(
    rb'("ip_white_list"[ \t]*:[ \t]*\[[ \t\r\n]*")[0-9]+(?:\.[0-9]+){3}(")'
)

if not brain_config_dir.is_dir():
    raise SystemExit(f"错误：目录不存在：{brain_config_dir}")

brain_files = []
for root, dir_names, file_names in os.walk(brain_config_dir, followlinks=False):
    dir_names.sort()
    file_names.sort()
    for name in file_names:
        path = Path(root) / name
        mode = os.lstat(path).st_mode
        if stat.S_ISLNK(mode):
            raise SystemExit(f"错误：为避免修改目录外文件，不处理符号链接：{path}")
        if stat.S_ISREG(mode):
            brain_files.append(path)

if not brain_files:
    raise SystemExit(f"错误：目录中没有配置文件：{brain_config_dir}")

plans = []

def prepare(path, pattern):
    try:
        original = path.read_bytes()
    except OSError as exc:
        raise SystemExit(f"错误：无法读取 {path}：{exc}") from exc

    updated, count = pattern.subn(lambda match: match.group(1) + new_ip + match.group(2), original)
    if count != 1:
        raise SystemExit(
            f"错误：{path} 中目标 IP 应恰好出现 1 次，实际匹配 {count} 次；未修改任何文件。"
        )
    plans.append((path, updated))

for config_file in brain_files:
    prepare(config_file, game_control_pattern)
prepare(main_config, game_control_pattern)
prepare(launch_file, white_list_pattern)

# 全部文件预检通过后才写入；按字节替换可保持中文、换行符和其余内容不变。
for path, updated in plans:
    temp_name = None
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent, prefix=f".{path.name}.", delete=False) as temp:
            temp_name = temp.name
            temp.write(updated)
            temp.flush()
            os.fsync(temp.fileno())
        shutil.copymode(path, temp_name)
        os.replace(temp_name, path)
    except OSError as exc:
        if temp_name is not None:
            try:
                os.unlink(temp_name)
            except OSError:
                pass
        raise SystemExit(f"错误：写入 {path} 失败：{exc}") from exc

print(f"修改成功：Game Controller IP 已设置为 {sys.argv[2]}")
print(f"共更新 {len(brain_files)} 个 brain_config 文件、config.yaml 和 launch.py。")
PY
