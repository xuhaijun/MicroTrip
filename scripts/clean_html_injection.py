"""清除 IDE 预览注入到 HTML 里的 `data-page-node-id` 属性。

背景：`privacy_policy.html` 被编辑器的 HTML 预览打开后，会被回写 37 个
`data-page-node-id="..."` 属性（每个元素一个，id 每次随机）。这不是我们写的代码，
提交进去会污染 diff，也会让「隐私政策页面是否只改了邮箱」这类复核变得不可读。

已发生两次（2026-09-10 两轮），所以固化成脚本。

用法：
    python scripts/clean_html_injection.py                 # 处理 privacy_policy.html
    python scripts/clean_html_injection.py a.html b.html   # 处理指定文件
    python scripts/clean_html_injection.py --check         # 只检查，不修改（返回码 1 表示有残留）

注意：直接改工作区文件。若改动已进入暂存区，请重新 `git add`。
"""
import io
import os
import re
import sys

DEFAULT = ["privacy_policy.html"]
PATTERN = re.compile(r'\s+data-page-node-id="[^"]*"')


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
    out = PATTERN.sub("", s)
    io.open(path, "w", encoding="utf-8", newline="").write(out.replace("\r\n", "\n").replace("\n", nl))
    print(f"已清除 {path} 中 {hits} 处注入属性")
    return True


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    check = "--check" in sys.argv
    targets = args or DEFAULT
    dirty = any(clean(p, check) for p in targets)
    if check and dirty:
        print("\n提示：这些属性由 IDE 预览注入，重新打开预览后会再次出现；提交前跑一次本脚本即可。")
        sys.exit(1)
