"""Tests for build_content_pack.py. Fixtures use placeholder strings, never real religious text."""
import json
import os
import sqlite3
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(__file__))
import build_content_pack as bcp  # noqa: E402


OPENING = "\ufeffمقدمة اختبار"   # placeholder for the opening line, not real text


def fake_edition(ident, text="نص اختبار", opening=False):
    surahs = []
    for n in range(1, 115):
        ayahs = [{"numberInSurah": i, "text": f"{text} {n}:{i}", "page": n, "juz": 1,
                  "hizbQuarter": 1} for i in range(1, 3)]
        if opening:
            if n == 1:
                ayahs[0]["text"] = OPENING
            elif n != 9:
                ayahs[0]["text"] = f"{OPENING} {ayahs[0]['text']}"
        surahs.append({"number": n, "name": f"سُورَةُ {n}", "englishName": f"S{n}",
                       "revelationType": "Meccan", "ayahs": ayahs})
    return {"data": {"edition": {"identifier": ident}, "surahs": surahs}}


class BuildTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.q = os.path.join(self.tmp, "q.json")
        self.t = os.path.join(self.tmp, "t.json")
        self.z = os.path.join(self.tmp, "z.json")
        json.dump(fake_edition("quran-uthmani", "نَصٌّ أَوَّلُ", opening=True), open(self.q, "w", encoding="utf-8"), ensure_ascii=False)
        json.dump(fake_edition("ar.muyassar"), open(self.t, "w", encoding="utf-8"), ensure_ascii=False)
        json.dump({"source": "fixture", "categories": [{"id": 1, "title": "باب", "items": [
            {"id": 1, "text": "ذكر اختبار", "count": 3, "reference": "مرجع"}]}]},
                  open(self.z, "w", encoding="utf-8"), ensure_ascii=False)
        self.out = os.path.join(self.tmp, "content-v1.sqlite")

    def run_build(self, *extra):
        return bcp.build(bcp.argparse.Namespace(version=1, quran=self.q, edition=list(extra) or None,
                                                azkar=self.z, out=self.out, allow_partial=True))

    def test_counts_and_text_kept_exactly(self):
        r = self.run_build(f"muyassar={self.t}")
        db = sqlite3.connect(self.out)
        self.assertEqual(db.execute("select count(*) from surah").fetchone()[0], 114)
        self.assertEqual(r["ayat"], 228)
        self.assertEqual(db.execute("select text_uthmani from ayah where surah=2 and ayah=2").fetchone()[0],
                         "نَصٌّ أَوَّلُ 2:2")
        self.assertEqual(db.execute("select count(*) from translation").fetchone()[0], 228)
        self.assertEqual(db.execute("select count from azkar where id=1").fetchone()[0], 3)

    def test_opening_line_split_from_first_ayah(self):
        r = self.run_build()
        db = sqlite3.connect(self.out)
        self.assertEqual(r["basmala_surahs"], 112)
        self.assertEqual(db.execute("select value from meta where key='basmala'").fetchone()[0], "مقدمة اختبار")
        self.assertEqual(db.execute("select text_uthmani from ayah where surah=1 and ayah=1").fetchone()[0], "مقدمة اختبار")
        self.assertEqual(db.execute("select text_uthmani from ayah where surah=2 and ayah=1").fetchone()[0], "نَصٌّ أَوَّلُ 2:1")
        self.assertEqual(db.execute("select basmala from surah where id in (1,2,9) order by id").fetchall(), [(0,), (1,), (0,)])
        self.assertEqual(db.execute("select text_uthmani from ayah where surah=9 and ayah=1").fetchone()[0], "نَصٌّ أَوَّلُ 9:1")
        self.assertEqual(db.execute("select name_plain from surah where id=5").fetchone()[0], "سورة 5")

    def test_search_ignores_tashkeel(self):
        self.run_build()
        db = sqlite3.connect(self.out)
        rows = db.execute("select count(*) from ayah_fts where ayah_fts match 'نص'").fetchone()[0]
        self.assertEqual(rows, 227)   # 1:1 is the placeholder opening line

    def test_full_count_enforced(self):
        with self.assertRaises(ValueError):
            bcp.build(bcp.argparse.Namespace(version=1, quran=self.q, edition=None, azkar=None,
                                             out=self.out + "2", allow_partial=False))

    def test_edition_mismatch_rejected(self):
        bad = fake_edition("x")
        bad["data"]["surahs"][0]["ayahs"].pop()
        json.dump(bad, open(self.t, "w", encoding="utf-8"), ensure_ascii=False)
        with self.assertRaises(ValueError):
            self.run_build(f"x={self.t}")

    def test_sha_file_written(self):
        r = self.run_build()
        with open(self.out + ".sha256") as f:
            self.assertTrue(f.read().startswith(r["sha256"]))


if __name__ == "__main__":
    unittest.main()
