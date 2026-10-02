#!/usr/bin/env python3
"""Kiểm tra câu lệnh Siri (App Shortcuts) có đủ bản dịch cho mọi ngôn ngữ (docs/08).

- Câu gốc trong App/Xu/XuShortcuts.swift phải trùng đúng tập khoá trong App/Xu/AppShortcuts.xcstrings.
- Mỗi câu có bản dịch en và ja đã dịch ("translated"), và câu nào cũng chứa ${applicationName}.
- Với --bundle <Xu.app>: en.lproj/ja.lproj/AppShortcuts.strings trong bản build có đúng tập khoá đó, và mỗi giá trị
  đúng bằng bản dịch của ngôn ngữ đó trong catalog (không phải câu gốc hay bản cũ).

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


def load_catalog():
    return json.loads((ROOT / "App/Xu/AppShortcuts.xcstrings").read_text(encoding="utf-8")).get("strings", {})


def translation(strings, phrase, language):
    return strings.get(phrase, {}).get("localizations", {}).get(language, {}).get("stringUnit", {})


def check_catalog(strings, phrases, errors):
    if set(strings) != set(phrases):
        errors.append(f"AppShortcuts.xcstrings có khoá {sorted(strings)}, câu gốc trong XuShortcuts là {sorted(phrases)}")
    for phrase in phrases:
        if PLACEHOLDER not in phrase:
            errors.append(f"Câu gốc thiếu {PLACEHOLDER}: {phrase!r}")
        for language in LANGUAGES:
            unit = translation(strings, phrase, language)
            value = unit.get("value", "")
            if unit.get("state") != "translated" or PLACEHOLDER not in value:
                errors.append(f"{language}: thiếu bản dịch (hoặc thiếu {PLACEHOLDER}) cho {phrase!r}")


def check_bundle(app, strings, phrases, errors):
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
            expected = translation(strings, key, language).get("value")
            if value != expected:
                errors.append(f"{path}: {key!r} là {value!r}, catalog ghi {expected!r}")


def main(argv):
    phrases = source_phrases()
    strings = load_catalog()
    errors = []
    if not phrases:
        errors.append("Không tìm thấy câu lệnh nào trong XuShortcuts.swift")
    check_catalog(strings, phrases, errors)
    if len(argv) == 3 and argv[1] == "--bundle":
        check_bundle(argv[2], strings, phrases, errors)
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
