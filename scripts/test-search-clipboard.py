#!/usr/bin/env python3
# /// script
# requires-python = ">=3.9"
# ///
"""Run with python3; fixtures never read the clipboard or launch a browser."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from urllib.parse import parse_qs, urlsplit


with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    output = root / "arguments.json"
    browser = root / "fake browser"
    browser.write_text(
        f"#!{sys.executable}\n"
        "import json, os, sys\n"
        "with open(os.environ['SEARCH_TEST_OUTPUT'], 'w') as output:\n"
        "    json.dump(sys.argv[1:], output)\n"
    )
    browser.chmod(0o755)
    script = Path(__file__).with_name("search-clipboard.py")

    def run(text, mode="window", executable=browser):
        output.unlink(missing_ok=True)
        result = subprocess.run(
            [sys.executable, str(script), "--mode", mode, "--browser", str(executable)],
            input=text,
            text=True,
            capture_output=True,
            env={**os.environ, "SEARCH_TEST_OUTPUT": str(output)},
        )
        return result, json.loads(output.read_text()) if output.exists() else None

    for mode, flags in [("window", ["--new-window"]), ("incognito", ["--incognito", "--new-window"]), ("tab", [])]:
        for query in ["-n", "café 東京 😀", "a & b = c #d", "line one\nline two\n", 'quotes " and \\ slashes']:
            result, args = run(query, mode)
            assert result.returncode == 0, result.stderr
            assert args[:-1] == flags, args
            assert parse_qs(urlsplit(args[-1]).query)["q"] == [query], args
        url = "https://example.invalid/café?q=one&next=two#section"
        result, args = run(url, mode)
        assert result.returncode == 0 and args == flags + [url], args
        result, args = run("", mode)
        assert result.returncode == 0 and args is None

    urls = ["https://example.invalid/a?x=1&y=2#z", "https://example.invalid/b_(c)"]
    result, args = run(f"[first]({urls[0]}) and <{urls[1]}>")
    assert result.returncode == 0 and args == ["--new-window", *urls], args
    result, args = run("example.invalid/path?a=1&b=2#c", "incognito")
    assert result.returncode == 0 and args[-1] == "https://example.invalid/path?a=1&b=2#c", args
    result, args = run("private query", executable=root / "missing")
    assert result.returncode != 0 and args is None
    assert "private query" not in result.stderr

print("search-clipboard: literal queries, Unicode, URLs, modes, and launch failure passed")
