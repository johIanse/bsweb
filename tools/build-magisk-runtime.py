#!/usr/bin/env python3
import os
import subprocess
import urllib.request
from pathlib import Path

BASE = "https://packages.termux.dev/apt/termux-main/"
NEEDED = [
    "php",
    "libsqlite",
    "sqlite",
    "libcurl",
    "curl",
    "openssl",
    "zlib",
    "libiconv",
    "libxml2",
    "oniguruma",
    "pcre2",
    "readline",
    "libandroid-glob",
    "libandroid-support",
    "libcrypt",
    "ncurses",
]


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

    for name in NEEDED:
        meta = packages.get(name)
        if not meta:
            print(f"skip missing package {name}")
            continue
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
        "extension_dir=/data/adb/modules/stepsystem/php/lib/php\n"
        "extension=pdo_sqlite\n"
        "extension=sqlite3\n"
        "extension=curl\n"
        "extension=mbstring\n",
        encoding="utf-8",
    )

    print("Embedded PHP runtime prepared:", php)


if __name__ == "__main__":
    main()
