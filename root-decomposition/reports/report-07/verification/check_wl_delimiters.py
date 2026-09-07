#!/usr/bin/env python3
"""Lexical balance only: not a Wolfram parser or an execution test."""
from pathlib import Path

root = Path(__file__).resolve().parents[1] / "code"
for path in sorted(root.glob("*")):
    text = path.read_text(encoding="utf-8")
    stack = []; i = 0; comment = 0; string = False
    while i < len(text):
        ch = text[i]; two = text[i:i+2]
        if comment:
            if two == "(*": comment += 1; i += 2; continue
            if two == "*)": comment -= 1; i += 2; continue
            i += 1; continue
        if string:
            if ch == "\\": i += 2; continue
            if ch == '"': string = False
            i += 1; continue
        if two == "(*": comment = 1; i += 2; continue
        if ch == '"': string = True; i += 1; continue
        if ch in "[({": stack.append((ch, i))
        elif ch in "])}":
            assert stack, (path, "unmatched closing delimiter", i)
            a, j = stack.pop()
            assert (a, ch) in [("(", ")"), ("[", "]"), ("{", "}")], (path, j, i)
        i += 1
    assert not (stack or string or comment), (path, stack, string, comment)
    print(f"{path.name}: balanced brackets, strings, and nested comments")
