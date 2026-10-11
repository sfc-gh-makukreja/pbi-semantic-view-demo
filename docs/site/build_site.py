"""Split README.md into one MkDocs page per step. README stays the single source."""
import re, shutil
from pathlib import Path

root = Path(__file__).resolve().parents[2]
here = Path(__file__).resolve().parent
out = here / ".build"
shutil.rmtree(out, ignore_errors=True)
(out).mkdir()
shutil.copytree(root / "docs" / "images", out / "images")
for f in (here / "pages" / "images").glob("*"):
    shutil.copy(f, out / "images" / f.name)

KIND = {"Tip": "tip", "Note": "note", "Not yet observed": "warning", "Verified independently": "success"}

def admonish(text):
    res = []
    for l in text.split("\n"):
        m = re.match(r"> \*\*([^*]+?)\*\* (.*)$", l)
        if m:
            label = re.sub(r"\s*[—:]$", "", m[1].strip())
            if label in KIND:
                res += ["", f'!!! {KIND[label]} "{label}"', f"    {m[2]}", ""]
                continue
        res.append(l)
    return "\n".join(res)

lines = (root / "README.md").read_text(encoding="utf-8").splitlines()

def shift(block):
    res, fence = [], False
    for l in block:
        if l.lstrip().startswith("```"):
            fence = not fence
        if not fence and re.match(r"#{2,6} ", l):
            l = l[1:]
        res.append(l)
    return res

sections, cur, fence = [], None, False
head = []
for l in lines:
    if l.lstrip().startswith("```"):
        fence = not fence
    if not fence and l.startswith("## "):
        cur = [l]
        sections.append(cur)
    elif cur is None:
        head.append(l)
    else:
        cur.append(l)

nav = []
for i, sec in enumerate(sections):
    title = sec[0][3:].strip()
    if i == 0:
        name, body = "index.md", head + [""] + sec
        intro = (here / "pages" / "intro.md").read_text(encoding="utf-8")
        body_text = intro + "\n" + "\n".join(sec[1:])
        nav.append((title if title != "Overview" else "Overview", name))
    else:
        m = re.match(r"Step (\d+)", title)
        slug = f"step-{m.group(1)}" if m else re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")
        name = f"{slug}.md"
        body_text = "\n".join(shift(sec))
        nav.append((title, name))
    if i == 0:
        # head holds the H1; the section heading becomes a normal H2
        pass
    body_text = admonish(body_text.replace("docs/images/", "images/"))
    (out / name).write_text(body_text + "\n", encoding="utf-8")

(out / "nav.txt").write_text("\n".join(f"{t}|{n}" for t, n in nav), encoding="utf-8")
for f in (here / "pages").glob("*.md"):
    if f.name != "intro.md":
        shutil.copy(f, out / f.name)
print("\n".join(f"{n}  <-  {t}" for t, n in nav))
