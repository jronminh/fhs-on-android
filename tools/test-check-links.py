#!/usr/bin/env python3
"""Run the link checker against isolated Markdown fixtures."""

import os
from pathlib import Path
import subprocess
import sys
from tempfile import TemporaryDirectory
import unittest


ROOT = Path(__file__).resolve().parents[1]
CHECKER = ROOT / "tools/check-links.py"
FIXTURE = os.path.join("manual", "links.md")


class LinkChecks(unittest.TestCase):
    def check_links(self, markdown):
        with TemporaryDirectory(dir=ROOT) as folder:
            root = Path(folder)
            (root / "manual").mkdir()
            (root / "README.md").write_text("## Root\n", encoding="utf-8")
            (root / "other doc.md").write_text(
                "## Repeat\n## Repeat-1\n## Repeat\n## Θ\n", encoding="utf-8"
            )
            (root / "code.sh").write_text("echo one\necho two\n", encoding="utf-8")
            (root / FIXTURE).write_text(markdown, encoding="utf-8")
            return subprocess.run(
                [sys.executable, CHECKER], cwd=root, capture_output=True, text=True
            )

    def test_valid_multiline_links(self):
        result = self.check_links(
            "[destination below](\n/README.md#root)\n\n"
            "[label on\ntwo lines](/README.md#root)\n\n"
            '[indented destination and title](\n  </README.md#root>\n  "title"\n)\n'
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("3 internal links checked, 0 broken", result.stdout)

    def test_broken_multiline_links_report_the_opening_line(self):
        result = self.check_links(
            "[text](\nmissing.md#gone)\n\n[two\nlines](/README.md#gone)\n"
        )
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn(f"{FIXTURE}:1: missing.md#gone -- no such file", result.stdout)
        self.assertIn(f"{FIXTURE}:4: /README.md#gone -- no such heading", result.stdout)
        self.assertIn("2 internal links checked, 2 broken", result.stdout)

    def test_links_in_wrapped_code_spans_are_ignored(self):
        result = self.check_links(
            "A `code span\n"
            "[ignored](missing.md#gone)\n"
            "[ignored ref]: missing.md#gone\n"
            "ends here` with a [real link](/README.md#root).\n\n"
            "A double-backtick span ``with a ` literal\n"
            "[ignored](\nmissing.md#gone)``.\n"
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("1 internal links checked, 0 broken", result.stdout)

    def test_existing_link_forms_and_code_examples(self):
        result = self.check_links(
            "## Local\n"
            "[local](#local)\n"
            "[root](/README.md#root)\n"
            "[root directory](/#root)\n"
            "[encoded](../other%20doc.md#%CE%B8)\n"
            '[duplicate](<../other doc.md#repeat-2> "tip")\n'
            "[range](../code.sh#L1-L2)\n"
            "[reference][target]\n"
            "`[literal](#ignored)`\n"
            "```markdown\n[example](\n#ignored)\n```\n\n"
            "[target]: <../other doc.md#repeat-1>\n"
            "\n[interrupted](\n\n#ignored)\n"
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("7 internal links checked, 0 broken", result.stdout)

    def test_existing_failures(self):
        result = self.check_links(
            "[wrong](#missing)\n[wrong ref]: /README.md#missing\n"
            "[bad line](/code.sh#L3)\n[wrong case](/readme.md#root)\n"
        )
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("4 internal links checked, 4 broken", result.stdout)


if __name__ == "__main__":
    unittest.main()
