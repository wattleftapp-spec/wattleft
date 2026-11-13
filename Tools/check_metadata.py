#!/usr/bin/env python3
"""Проверяет длину полей в AppStore/metadata.md по лимитам App Store Connect.

Запуск: python3 Tools/check_metadata.py
"""
import re
import sys
from pathlib import Path

LIMITS = {
    "Назва": 30, "Name": 30,
    "Підзаголовок": 30, "Subtitle": 30,
    "Рекламний текст": 170, "Promotional text": 170,
    "Опис": 4000, "Description": 4000,
    "Ключові слова": 100, "Keywords": 100,
}

text = Path(__file__).resolve().parent.parent.joinpath("AppStore/metadata.md").read_text(encoding="utf-8")
ok = True
for m in re.finditer(r"^### (.+?)(?: \(\d+.*?\))?\n```\n(.*?)\n```", text, re.S | re.M):
    title, body = m.group(1).strip(), m.group(2)
    limit = LIMITS.get(title)
    if limit is None:
        continue
    n = len(body)
    flag = "OK " if n <= limit else "TOO LONG"
    ok &= n <= limit
    extra = ""
    if title in ("Ключові слова", "Keywords") and (", " in body):
        flag, ok, extra = "SPACES", False, " (уберите пробелы после запятых)"
    print(f"{flag:8} {title:18} {n:4}/{limit}{extra}")
sys.exit(0 if ok else 1)
