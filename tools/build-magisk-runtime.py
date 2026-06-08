#!/usr/bin/env python3
import os
import subprocess
import urllib.request
from pathlib import Path

BASE = "https://packages.termux.dev/apt/termux-main/"
NEEDED = ["php", "curl", "sqlite", "ncurses"]


def parse_packages(text: str):
    packages = {}
    for block in text.split("\n\n"):
        d = {}
        for line in block.splitlines():
            if ": " in line:
                k, v = line.split(": ", 1)
                d[k] = v
        if "Package" in d and "Filename" in d:
            packages[d["Package"]] = d
    return packages


def dep_names(meta):
    raw = meta.get("Depends", "")
    names = []
    for part in raw.split(","):
        part = part.strip()
        if not part:
            continue
        part = part.split(" ", 1)[0].strip()
        part = part.split("|", 1)[0].strip()
        if part:
            names.append(part)
    return names


def resolve_deps(packages, roots):
    todo = list(roots)
    seen = set()
    ordered = []
    while todo:
        name = todo.pop(0)
        if name in seen:
            continue
        seen.add(name)
        meta = packages.get(name)
        if not meta:
            print(f"skip missing package {name}")
            continue
        ordered.append(name)
        for dep in dep_names(meta):
            if dep not in seen:
                todo.append(dep)
    return ordered


def main():
    module_dir = Path(os.environ.get("MODULE_DIR", ".")).resolve()
    out = module_dir / "php"
    debdir = Path("termux-debs")
    root = Path("termux-root")
    out.mkdir(parents=True, exist_ok=True)
    debdir.mkdir(parents=True, exist_ok=True)

    print("Fetching Termux package index...")
    pkg_text = urllib.request.urlopen(
        BASE + "dists/stable/main/binary-aarch64/Packages", timeout=90
    ).read().decode("utf-8", "replace")
    packages = parse_packages(pkg_text)

    for name in resolve_deps(packages, NEEDED):
        meta = packages[name]
        fn = meta["Filename"]
        url = BASE + fn
        path = debdir / Path(fn).name.replace(":", "_")
        print(f"download {name}: {url}")
        urllib.request.urlretrieve(url, path)
        subprocess.run(["dpkg-deb", "-x", str(path), str(root)], check=True)

    src = root / "data/data/com.termux/files/usr"
    if not src.is_dir():
        raise SystemExit("Termux usr path not found after extraction")
    subprocess.run(["rsync", "-a", str(src) + "/", str(out) + "/"], check=True)

    php = out / "bin/php"
    if not php.exists():
        raise SystemExit("php binary not found")
    php.chmod(0o755)

    ini = out / "lib/php.ini"
    ini.parent.mkdir(parents=True, exist_ok=True)
    ini.write_text(
        "date.timezone=Asia/Shanghai\n"
        "display_errors=0\n"
        "log_errors=1\n",
        encoding="utf-8",
    )

    print("Embedded PHP runtime prepared:", php)


if __name__ == "__main__":
    main()
