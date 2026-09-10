"""清除 IDE 预览注入到 HTML 里的 `data-page-node-id` 属性。

背景：`privacy_policy.html` 被编辑器的 HTML 预览打开后，会被回写 37 个
`data-page-node-id="..."` 属性（每个元素一个，id 每次随机）。这不是我们写的代码，
提交进去会污染 diff，也会让「隐私政策页面是否只改了邮箱」这类复核变得不可读。

已发生三次（2026-09-10 三轮），且是**持续回写**：`git checkout` 恢复后 2 秒内又会被重新注入。
因此除手工清理外，另配了 git clean filter（见 scripts/install_git_filters.sh）：
`git add` 时自动剥离，工作区保持被注入的样子也不影响提交内容。

用法：
    python scripts/clean_html_injection.py                 # 处理 privacy_policy.html
    python scripts/clean_html_injection.py a.html b.html   # 处理指定文件
    python scripts/clean_html_injection.py --check         # 只检查，不修改（返回码 1 表示有残留）
    python scripts/clean_html_injection.py --stdin         # 过滤模式：stdin → stdout（供 git filter 调用）
    bash scripts/install_git_filters.sh                    # 一次性安装 clean filter（每台机器一次）

注意：直接改工作区文件。若改动已进入暂存区，请重新 `git add`。
"""
import io
import os
import re
import sys

DEFAULT = ["privacy_policy.html"]
PATTERN = re.compile(r'\s+data-page-node-id="[^"]*"')


def strip_injection(s: str) -> str:
    """剥离注入属性，其余内容（含换行风格）原样保留。"""
    return PATTERN.sub("", s)


def filter_stdin() -> None:
    """
    git clean filter 模式：stdin 内容剥离注入属性后原样写到 stdout。

    刻意<b>不做换行风格转换</b>：filter 下游还有 git 自己的 eol 规范化，
    此处再动一次换行会让文件长期处于「看起来被改过」的状态。
    用 surrogateescape 保证非 UTF-8 字节也能无损通过。
    """
    raw = sys.stdin.buffer.read()
    try:
        text = raw.decode("utf-8", errors="surrogateescape")
    except Exception:
        sys.stdout.buffer.write(raw)
        return
    sys.stdout.buffer.write(strip_injection(text).encode("utf-8", errors="surrogateescape"))


def clean(path: str, check_only: bool = False) -> bool:
    """返回 True 表示发现并（可选地）清除了注入属性。"""
    if not os.path.exists(path):
        print(f"跳过（不存在）: {path}")
        return False
    s = io.open(path, encoding="utf-8").read()
    hits = len(PATTERN.findall(s))
    if hits == 0:
        print(f"干净: {path}")
        return False
    if check_only:
        print(f"⚠️  {path} 含 {hits} 处注入属性（未修改）")
        return True
    # 保留原换行风格：写回时不做转换
    nl = "\r\n" if "\r\n" in s else "\n"
    out = strip_injection(s)
    io.open(path, "w", encoding="utf-8", newline="").write(out.replace("\r\n", "\n").replace("\n", nl))
    print(f"已清除 {path} 中 {hits} 处注入属性")
    return True


if __name__ == "__main__":
    if "--stdin" in sys.argv:
        filter_stdin()
        sys.exit(0)
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    check = "--check" in sys.argv
    targets = args or DEFAULT
    dirty = any(clean(p, check) for p in targets)
    if check and dirty:
        print("\n提示：这些属性由 IDE 预览持续注入。若已安装 git clean filter，"
              "`git add` 会自动剥离，无需手工处理；否则提交前跑一次本脚本。")
        sys.exit(1)
