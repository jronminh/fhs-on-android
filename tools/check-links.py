#!/usr/bin/env python3
"""Check the guide's relative Markdown links and anchors.

Run from the repository root:

    python3 tools/check-links.py

A relative link must name a file that exists with the same letter case. A
heading anchor uses GitHub's slug rules. Source line anchors must fall within
the file. Exit status is 1 when a link or anchor is broken.
"""

import os
import re
import sys
from urllib.parse import unquote

TEXT_EXTENSIONS = {".md", ".txt", ""}
SKIP_DIRS = {".git"}

DESTINATION = r"(<[^>\n]*>|[^()\s<>]+)"
TITLE = r"""(?:[ \t\n]+(?:"[^"]*"|'[^']*'|\([^)]*\)))?"""
LINK = re.compile(r"(?<!\\)\[[^\]]*\]\([ \t\n]*" + DESTINATION + TITLE + r"[ \t\n]*\)")
REFERENCE = re.compile(r"^ {0,3}\[[^\]\n]+\]:[ \t]*" + DESTINATION, re.MULTILINE)
FENCE = re.compile(r"^\s*(```|~~~)")
HEADING = re.compile(r"^ {0,3}#{1,6}\s+(.*?)\s*$")
LINE_RANGE = re.compile(r"L([1-9]\d*)(?:-L([1-9]\d*))?")
CODE_SPAN = re.compile(r"(?<!`)(`+)(?!`).*?(?<!`)\1(?!`)", re.DOTALL)
INLINE_CODE = re.compile(r"`([^`]*)`")
INLINE_LINK = re.compile(r"\[([^\]]*)\]\([^)]*\)")
HTML_TAG = re.compile(r"<[^>]+>")
EMPHASIS = re.compile(r"[*~]")
NOT_SLUG = re.compile(r"[^\w\s-]", re.UNICODE)


def iter_text_files(root):
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for name in filenames:
            ext = os.path.splitext(name)[1].lower()
            if ext in TEXT_EXTENSIONS:
                yield os.path.join(dirpath, name)


def slug(text):
    """GitHub's heading slug: lowercase, links unwrapped, punctuation dropped."""
    text = INLINE_LINK.sub(r"\1", text)
    text = INLINE_CODE.sub(r"\1", text)
    text = HTML_TAG.sub("", text)
    text = EMPHASIS.sub("", text)
    text = NOT_SLUG.sub("", text.lower())
    return text.strip().replace(" ", "-")


def anchors(path):
    found, seen = set(), {}
    in_fence = False
    with open(path, encoding="utf-8", errors="replace") as handle:
        for line in handle:
            if FENCE.match(line):
                in_fence = not in_fence
                continue
            if in_fence:
                continue
            match = HEADING.match(line)
            if not match:
                continue
            base = slug(match.group(1))
            heading = base
            count = seen.get(base, 0)
            while heading in found:
                count += 1
                heading = "%s-%d" % (base, count)
            found.add(heading)
            seen[base] = count
    return found


def resolve(base_dir, target):
    """Resolve a relative path, requiring every component to match case."""
    current = base_dir
    for part in target.split("/"):
        if part in ("", "."):
            continue
        if part == "..":
            current = os.path.dirname(current)
            continue
        try:
            entries = os.listdir(current)
        except OSError:
            return None
        if part not in entries:
            return None
        current = os.path.join(current, part)
    return current


def check_anchor(path, fragment, cache):
    if os.path.isdir(path):
        path = resolve(path, "README.md")
        if path is None:
            return "no README.md for directory anchor"
    if path.lower().endswith(".md"):
        if path not in cache:
            cache[path] = anchors(path)
        return None if fragment in cache[path] else "no such heading"

    match = LINE_RANGE.fullmatch(fragment)
    if not match:
        return "no such anchor"
    first = int(match.group(1))
    last = int(match.group(2) or first)
    with open(path, "rb") as handle:
        length = sum(1 for _ in handle)
    return None if first <= last <= length else "line anchor out of range"


def iter_targets(handle):
    """Yield destinations at their opening line, including wrapped inline links."""
    block = []
    first_line = 1
    in_fence = False

    def block_targets():
        # Keep line numbers while hiding link examples in wrapped code spans.
        visible = CODE_SPAN.sub(lambda match: re.sub(r"[^\n]", " ", match[0]), "".join(block))
        for pattern in (LINK, REFERENCE):
            for match in pattern.finditer(visible):
                yield first_line + visible.count("\n", 0, match.start()), match[1]

    for number, line in enumerate(handle, 1):
        if FENCE.match(line):
            yield from block_targets()
            block.clear()
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        if not line.strip():
            yield from block_targets()
            block.clear()
            continue
        if not block:
            first_line = number
        block.append(line)
    yield from block_targets()


def main():
    root = os.getcwd()
    cache = {}
    checked = 0
    broken = []

    for path in sorted(iter_text_files(root)):
        rel_path = os.path.relpath(path, root)
        with open(path, encoding="utf-8", errors="replace") as handle:
            for number, target in iter_targets(handle):
                target = target.removeprefix("<").removesuffix(">")
                if not target or re.match(r"^(?:[\w+.-]+:|//)", target):
                    continue
                checked += 1
                where = "%s:%d" % (rel_path, number)
                file_part, _, fragment = target.partition("#")
                file_part = unquote(file_part.split("?", 1)[0])
                base_dir = root if file_part.startswith("/") else os.path.dirname(path)
                resolved = resolve(base_dir, file_part) if file_part else path
                if resolved is None or os.path.commonpath([root, resolved]) != root:
                    broken.append((where, target, "no such file, or the case differs"))
                    continue
                if fragment:
                    error = check_anchor(resolved, unquote(fragment), cache)
                    if error:
                        broken.append((where, target, error))

    for where, target, why in broken:
        print("%s: %s -- %s" % (where, target, why))
    print("%d internal links checked, %d broken" % (checked, len(broken)))
    return 1 if broken else 0


if __name__ == "__main__":
    sys.exit(main())
