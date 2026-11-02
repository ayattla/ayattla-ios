"""Tests for normalize_azkar.py. Fixtures are placeholders, never real dhikr text."""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(__file__))
import normalize_azkar as na  # noqa: E402

DOC = {"columns": [{"name": n} for n in ["category", "zekr", "description", "count", "reference", "search"]],
       "rows": [["باب أ", "نص ١", "وصف", 3, "مرجع", "x"],
                ["باب ب", "نص ٢", "", "", None, "x"],
                ["باب أ", "نص ٣", None, "bad", "م", "x"],
                ["", "يتجاهل", None, 1, None, "x"]]}


class NormalizeTest(unittest.TestCase):
    def test_groups_in_order_and_keeps_text(self):
        out, n = na.normalize(DOC, "fixture")
        self.assertEqual(n, 3)
        self.assertEqual([c["title"] for c in out["categories"]], ["باب أ", "باب ب"])
        a = out["categories"][0]["items"]
        self.assertEqual([i["text"] for i in a], ["نص ١", "نص ٣"])
        self.assertEqual(a[0]["count"], 3)
        self.assertEqual(a[1]["count"], 1)
        self.assertEqual(out["categories"][1]["items"][0]["note"], None)

    def test_missing_column_rejected(self):
        with self.assertRaises(ValueError):
            na.normalize({"columns": [{"name": "zekr"}], "rows": []}, "x")


if __name__ == "__main__":
    unittest.main()
