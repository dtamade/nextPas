#!/usr/bin/env python3

import importlib.util
import pathlib
import unittest


SCRIPT_PATH = pathlib.Path(__file__).with_name("gen_unicode_data.py")
SPEC = importlib.util.spec_from_file_location("gen_unicode_data", SCRIPT_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


class UnicodeDataGeneratorTests(unittest.TestCase):
    def test_category_table_uses_ucd_category_codes_and_expands_ranges(self):
        sample = "\n".join(
            [
                "0041;LATIN CAPITAL LETTER A;Lu;0;L;;;;;N;;;;0061;",
                "3400;<CJK Ideograph Extension A, First>;Lo;0;L;;;;;N;;;;;",
                "4DBF;<CJK Ideograph Extension A, Last>;Lo;0;L;;;;;N;;;;;",
            ]
        )

        records = MODULE.parse_unicode_data(sample)
        table = MODULE.build_category_table(records)

        self.assertEqual(table[0x00][0x41], 0)
        self.assertIn(0x3401, records)
        self.assertEqual(records[0x3401].category, "Lo")

    def test_property_parser_strips_inline_comments(self):
        sample = "\n".join(
            [
                "0009..000D    ; White_Space # Cc   [5] <control-0009>..<control-000D>",
                "1F3FB..1F3FF  ; Emoji_Modifier # Sk [5] light skin tone..dark skin tone",
            ]
        )

        props = MODULE.build_property_ranges(sample)

        self.assertEqual(props["White_Space"], [(0x0009, 0x000D)])
        self.assertEqual(props["Emoji_Modifier"], [(0x1F3FB, 0x1F3FF)])


if __name__ == "__main__":
    unittest.main()
