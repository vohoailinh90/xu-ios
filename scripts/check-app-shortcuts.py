#!/usr/bin/env python3
"""Kiểm tra câu lệnh Siri (App Shortcuts) có đủ bản dịch cho mọi ngôn ngữ (docs/08).

- Câu gốc trong App/Xu/XuShortcuts.swift phải trùng đúng tập khoá trong App/Xu/AppShortcuts.xcstrings.
- Mỗi câu có bản dịch en và ja đã dịch ("translated"), và câu nào cũng chứa ${applicationName}.
- Với --bundle <Xu.app>: en.lproj/ja.lproj/AppShortcuts.strings trong bản build có đúng tập khoá đó, giá trị
  nào cũng chứa ${applicationName}.

Chạy: python3 scripts/check-app-shortcuts.py [--bundle path/to/Xu.app]
"""
import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LANGUAGES = ["en", "ja"]
PLACEHOLDER = "${applicationName}"


def source_phrases():
    text = (ROOT / "App/Xu/XuShortcuts.swift").read_text(encoding="utf-8")
    phrases = []
    for block in re.findall(r"phrases:\s*\[(.*?)\]", text, re.S):
        for literal in re.findall(r'"((?:[^"\\]|\\.)*)"', block):
            phrases.append(literal.replace("\\(.applicationName)", PLACEHOLDER))
    return phrases


def check_catalog(phrases, errors):
    catalog = json.loads((ROOT / "App/Xu/AppShortcuts.xcstrings").read_text(encoding="utf-8"))
    strings = catalog.get("strings", {})
    if set(strings) != set(phrases):
        errors.append(f"AppShortcuts.xcstrings có khoá {sorted(strings)}, câu gốc trong XuShortcuts là {sorted(phrases)}")
    for phrase in phrases:
        if PLACEHOLDER not in phrase:
            errors.append(f"Câu gốc thiếu {PLACEHOLDER}: {phrase!r}")
        localizations = strings.get(phrase, {}).get("localizations", {})
        for language in LANGUAGES:
            unit = localizations.get(language, {}).get("stringUnit", {})
            value = unit.get("value", "")
            if unit.get("state") != "translated" or PLACEHOLDER not in value:
                errors.append(f"{language}: thiếu bản dịch (hoặc thiếu {PLACEHOLDER}) cho {phrase!r}")


def check_bundle(app, phrases, errors):
    for language in LANGUAGES:
        path = pathlib.Path(app) / f"{language}.lproj" / "AppShortcuts.strings"
        converted = subprocess.run(["plutil", "-convert", "json", "-o", "-", str(path)],
                                   capture_output=True, text=True)
        if converted.returncode != 0:
            errors.append(f"Không đọc được {path}: {converted.stderr.strip()}")
            continue
        table = json.loads(converted.stdout)
        if set(table) != set(phrases):
            errors.append(f"{path}: khoá {sorted(table)} khác câu gốc {sorted(phrases)}")
        for key, value in table.items():
            if PLACEHOLDER not in value:
                errors.append(f"{path}: bản dịch của {key!r} thiếu {PLACEHOLDER}: {value!r}")


def main(argv):
    phrases = source_phrases()
    errors = []
    if not phrases:
        errors.append("Không tìm thấy câu lệnh nào trong XuShortcuts.swift")
    check_catalog(phrases, errors)
    if len(argv) == 3 and argv[1] == "--bundle":
        check_bundle(argv[2], phrases, errors)
    elif len(argv) != 1:
        errors.append("Cách dùng: check-app-shortcuts.py [--bundle path/to/Xu.app]")
    for error in errors:
        print(f"::error::{error}")
    if errors:
        return 1
    print(f"OK: {len(phrases)} câu lệnh, đủ bản dịch {', '.join(LANGUAGES)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
