#!/bin/sh
# ============================================================
# git clean filter：提交前剥离 IDE 注入的 data-page-node-id 属性。
#
# 由 .gitattributes 的 `privacy_policy.html filter=htmlclean` 触发，
# 由 scripts/install_git_filters.sh 安装 git config 指过来。
#
# 设计原则：**绝不阻断 git 操作**
#   找不到可用的 python 时，原样透传（exec cat）——
#   也就是退回「不清理」的旧行为，而不是让 git add 报错。
#   宁可少做一件事，也不能让提交链路挂掉。
#
# 为什么必须探测而不是直接 `python`：Windows 的 Microsoft Store 会放一个
# python.exe 占位符（未安装时）到 PATH，直接调用会失败或弹出商店页面。
# 这里用 `python -c ""` 做真实可用性探测，探测失败就不使用它。
# 若自动探测都不理想，可用环境变量显式指定：MICROTRIP_PYTHON=/path/to/python
# ============================================================
set -u

# ---------- 解析脚本路径 ----------
# 坑：Git Bash 的 pwd 给出 POSIX 形式（/d/FlutterProjects/...），而 Windows 版 python.exe
# 不会把这个路径当 POSIX 处理 —— 它会以「当前盘符根」解释，变成 D:\d\FlutterProjects\...
# 导致「找不到文件」。所以必须用 cygpath 转成 Windows 路径。
# （这条是实测踩出来的：wrapper 自检若不校验精确输出，空输出会被误判为通过。）
SCRIPT_PATH=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/clean_html_injection.py
if command -v cygpath >/dev/null 2>&1; then
    SCRIPT_PATH=$(cygpath -w "$SCRIPT_PATH" 2>/dev/null || printf '%s' "$SCRIPT_PATH")
fi
# 兜底：git filter 的 cwd 必然是工作区根目录，相对路径一定能命中
[ -f "$SCRIPT_PATH" ] || SCRIPT_PATH="scripts/clean_html_injection.py"

pick_python() {
    if [ -n "${MICROTRIP_PYTHON:-}" ] && "$MICROTRIP_PYTHON" -c "" >/dev/null 2>&1; then
        printf '%s' "$MICROTRIP_PYTHON"
        return 0
    fi
    for candidate in python3 python py; do
        if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c "" >/dev/null 2>&1; then
            printf '%s' "$candidate"
            return 0
        fi
    done
    return 1
}

PY=$(pick_python) || PY=""

if [ -z "$PY" ]; then
    # 无可用 python：原样透传，绝不阻断 git
    exec cat
fi

exec "$PY" "$SCRIPT_PATH" --stdin
