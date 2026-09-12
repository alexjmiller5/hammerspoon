#!/usr/bin/env python3
# /// script
# requires-python = ">=3.9"
# ///
"""Open URLs or search text supplied on stdin, without shell interpolation."""

import argparse
import re
import subprocess
import sys
from urllib.parse import quote


def destinations(text):
    urls = []
    for line in text.splitlines():
        line = line.strip()
        if re.fullmatch(r"https?://\S+", line):
            urls.append(line)
            continue
        matches = re.findall(r"https?://[^\s<>\"'\[\]`]+", line)
        for url in matches:
            # Markdown's closing parenthesis is outside the URL; balanced ones stay.
            while url.endswith(")") and url.count(")") > url.count("("):
                url = url[:-1]
            urls.append(url)
        if not matches and re.fullmatch(r"(?:[A-Za-z0-9-]+\.)+[A-Za-z]{2,}(?::\d+)?(?:[/?#]\S*)?", line):
            urls.append("https://" + line)
    return urls or ["https://www.google.com/search?q=" + quote(text, safe="")]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=["window", "incognito", "tab"], default="window")
    parser.add_argument("--browser", required=True)
    args = parser.parse_args()
    text = sys.stdin.read()
    if not text.strip():
        return 0
    urls = destinations(text)
    flags = ["--incognito", "--new-window"] if args.mode == "incognito" else ["--new-window"]
    if args.mode == "tab":
        flags, urls = [], urls[:1]
    try:
        return subprocess.call([args.browser, *flags, *urls], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError:
        print("Cannot start the browser executable.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
