#!/usr/bin/env python3
"""Check that every internal link and anchor in the guide resolves.

Run from the repository root:

    python3 tools/check-links.py

A relative link must name a file that exists with the same letter case, because
that is what GitHub's server does and what a phone's shell does not. An anchor
must name a heading that exists, using GitHub's slug rules. Exit status is 1 when
anything is broken, so CI fails on the sentence a reader would have found broken.
"""

import os
import re
import sys

TEXT_EXTENSIONS = {".md", ".txt", ""}
SKIP_DIRS = {".git"}

LINK = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")
FENCE = re.compile(r"^\s*(```|~~~)")
HEADING = re.compile(r"^(#{1,6})\s+(.*?)\s*$")
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
            base = slug(match.group(2))
            count = seen.get(base, 0)
            found.add(base if count == 0 else "%s-%d" % (base, count))
            seen[base] = count + 1
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


def main():
    root = os.getcwd()
    cache = {}
    checked = 0
    broken = []

    for path in sorted(iter_text_files(root)):
        rel_path = os.path.relpath(path, root)
        in_fence = False
        with open(path, encoding="utf-8", errors="replace") as handle:
            for number, line in enumerate(handle, 1):
                if FENCE.match(line):
                    in_fence = not in_fence
                    continue
                if in_fence:
                    continue
                for match in LINK.finditer(line):
                    target = match.group(1)
                    if re.match(r"^(https?:|mailto:|ftp:)", target):
                        continue
                    checked += 1
                    where = "%s:%d" % (rel_path, number)
                    if target.startswith("#"):
                        resolved, fragment = path, target[1:]
                    elif "#" in target:
                        file_part, fragment = target.split("#", 1)
                        resolved = resolve(os.path.dirname(path), file_part)
                    else:
                        resolved, fragment = resolve(os.path.dirname(path), target), ""
                    if resolved is None:
                        broken.append((where, target, "no such file, or the case differs"))
                        continue
                    if fragment and resolved.lower().endswith(".md"):
                        if resolved not in cache:
                            cache[resolved] = anchors(resolved)
                        if fragment not in cache[resolved]:
                            broken.append((where, target, "no such heading"))

    for where, target, why in broken:
        print("%s: %s -- %s" % (where, target, why))
    print("%d internal links checked, %d broken" % (checked, len(broken)))
    return 1 if broken else 0


if __name__ == "__main__":
    sys.exit(main())
