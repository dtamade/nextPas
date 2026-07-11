#!/usr/bin/env python3
"""
Unicode 16.0 Script and Block data table generator.

Downloads Scripts.txt and Blocks.txt from unicode.org and produces
compact Pascal include files for nextpas.core.text.unicode modules.

Usage:
    python3 gen_unicode_script_block.py [--version 16.0.0] [--output-dir ../src]

Output:
    - nextpas.core.text.unicode.script.inc
    - nextpas.core.text.unicode.block.inc
"""

import urllib.error
import urllib.request
import argparse
import os
import sys
from typing import Dict, List, Tuple

# ─── Unicode version ───────────────────────────────────────────────
DEFAULT_VERSION = "16.0.0"
UCD_BASE = "https://www.unicode.org/Public/{version}/ucd/"

# ─── Script constants ─────────────────────────────────────────────
SCRIPT_NAMES = {
    "Common": "usCommon",
    "Latin": "usLatin",
    "Greek": "usGreek",
    "Cyrillic": "usCyrillic",
    "Armenian": "usArmenian",
    "Hebrew": "usHebrew",
    "Arabic": "usArabic",
    "Syriac": "usSyriac",
    "Thaana": "usThaana",
    "Devanagari": "usDevanagari",
    "Bengali": "usBengali",
    "Gurmukhi": "usGurmukhi",
    "Gujarati": "usGujarati",
    "Oriya": "usOriya",
    "Tamil": "usTamil",
    "Telugu": "usTelugu",
    "Kannada": "usKannada",
    "Malayalam": "usMalayalam",
    "Sinhala": "usSinhala",
    "Thai": "usThai",
    "Lao": "usLao",
    "Tibetan": "usTibetan",
    "Myanmar": "usMyanmar",
    "Georgian": "usGeorgian",
    "Hangul": "usHangul",
    "Ethiopic": "usEthiopic",
    "Cherokee": "usCherokee",
    "Canadian_Aboriginal": "usCanadianAboriginal",
    "Ogham": "usOgham",
    "Runic": "usRunic",
    "Khmer": "usKhmer",
    "Mongolian": "usMongolian",
    "Hiragana": "usHiragana",
    "Katakana": "usKatakana",
    "Bopomofo": "usBopomofo",
    "Han": "usHan",
    "Yi": "usYi",
    "Old_Italic": "usOldItalic",
    "Gothic": "usGothic",
    "Deseret": "usDeseret",
    "Inherited": "usInherited",
    "Tagalog": "usTagalog",
    "Hanunoo": "usHanunoo",
    "Buhid": "usBuhid",
    "Tagbanwa": "usTagbanwa",
    "Limbu": "usLimbu",
    "Tai_Le": "usTaiLe",
    "Linear_B": "usLinearB",
    "Ugaritic": "usUgaritic",
    "Shavian": "usShavian",
    "Osmanya": "usOsmanya",
    "Cypriot": "usCypriot",
    "Braille": "usBraille",
    "Buginese": "usBuginese",
    "Coptic": "usCoptic",
    "New_Tai_Lue": "usNewTaiLue",
    "Glagolitic": "usGlagolitic",
    "Tifinagh": "usTifinagh",
    "Syloti_Nagri": "usSylotiNagri",
    "Old_Persian": "usOldPersian",
    "Kharoshthi": "usKharoshthi",
    "Balinese": "usBalinese",
    "Cuneiform": "usCuneiform",
    "Phoenician": "usPhoenician",
    "Phags_Pa": "usPhagsPa",
    "Nko": "usNko",
    "Sundanese": "usSundanese",
    "Lepcha": "usLepcha",
    "Ol_Chiki": "usOlChiki",
    "Vai": "usVai",
    "Saurashtra": "usSaurashtra",
    "Kayah_Li": "usKayahLi",
    "Rejang": "usRejang",
    "Cham": "usCham",
    "Tai_Tham": "usTaiTham",
    "Tai_Viet": "usTaiViet",
    "Avestan": "usAvestan",
    "Egyptian_Hieroglyphs": "usEgyptianHieroglyphs",
    "Samaritan": "usSamaritan",
    "Mandaic": "usMandaic",
    "Lisu": "usLisu",
    "Bamum": "usBamum",
    "Javanese": "usJavanese",
    "Meetei_Mayek": "usMeeteiMayek",
    "Imperial_Aramaic": "usImperialAramaic",
    "Old_South_Arabian": "usOldSouthArabian",
    "Inscriptional_Parthian": "usInscriptionalParthian",
    "Inscriptional_Pahlavi": "usInscriptionalPahlavi",
    "Old_Turkic": "usOldTurkic",
    "Kaithi": "usKaithi",
    "Batak": "usBatak",
    "Brahmi": "usBrahmi",
    "Chakma": "usChakma",
    "Meroitic_Cursive": "usMeroiticCursive",
    "Meroitic_Hieroglyphs": "usMeroiticHieroglyphs",
    "Miao": "usMiao",
    "Sharada": "usSharada",
    "Sora_Sompeng": "usSoraSompeng",
    "Takri": "usTakri",
    "Caucasian_Albanian": "usCaucasianAlbanian",
    "Bassa_Vah": "usBassaVah",
    "Duployan": "usDuployan",
    "Elbasan": "usElbasan",
    "Grantha": "usGrantha",
    "Pahawh_Hmong": "usPahawhHmong",
    "Khojki": "usKhojki",
    "Linear_A": "usLinearA",
    "Mahajani": "usMahajani",
    "Manichaean": "usManichaean",
    "Mende_Kikakui": "usMendeKikakui",
    "Modi": "usModi",
    "Mro": "usMro",
    "Old_North_Arabian": "usOldNorthArabian",
    "Nabataean": "usNabataean",
    "Palmyrene": "usPalmyrene",
    "Pau_Cin_Hau": "usPauCinHau",
    "Old_Permic": "usOldPermic",
    "Psalter_Pahlavi": "usPsalterPahlavi",
    "Siddham": "usSiddham",
    "Khudawadi": "usKhudawadi",
    "Tirhuta": "usTirhuta",
    "Warang_Citi": "usWarangCiti",
    "Ahom": "usAhom",
    "Anatolian_Hieroglyphs": "usAnatolianHieroglyphs",
    "Hatran": "usHatran",
    "Multani": "usMultani",
    "Old_Hungarian": "usOldHungarian",
    "SignWriting": "usSignWriting",
    "Adlam": "usAdlam",
    "Bhaiksuki": "usBhaiksuki",
    "Marchen": "usMarchen",
    "Newa": "usNewa",
    "Osage": "usOsage",
    "Tangut": "usTangut",
    "Masaram_Gondi": "usMasaramGondi",
    "Nushu": "usNushu",
    "Soyombo": "usSoyombo",
    "Zanabazar_Square": "usZanabazarSquare",
    "Dogra": "usDogra",
    "Gunjala_Gondi": "usGunjalaGondi",
    "Makasar": "usMakasar",
    "Medefaidrin": "usMedefaidrin",
    "Old_Sogdian": "usOldSogdian",
    "Sogdian": "usSogdian",
    "Chorasmian": "usChorasmian",
    "Elymaic": "usElymaic",
    "Nandinagari": "usNandinagari",
    "Nyiakeng_Puachue_Hmong": "usNyiakengPuachueHmong",
    "Wancho": "usWancho",
    "Yezidi": "usYezidi",
    "Cypro_Minoan": "usCyproMinoan",
    "Tangsa": "usTangsa",
    "Toto": "usToto",
    "Vithkuqi": "usVithkuqi",
    "Kawi": "usKawi",
    "Nag_Mundari": "usNagMundari",
    "Todhri": "usTodhri",
    "Tulu_Tigalari": "usTuluTigalari",
    "Unknown": "usUnknown",
}

# ─── Block constants ──────────────────────────────────────────────
BLOCK_NAMES = {
    "Basic Latin": "ubBasicLatin",
    "Latin Extended-A": "ubLatinExtendedA",
    "Latin Extended-B": "ubLatinExtendedB",
    "IPA Extensions": "ubIPAExtensions",
    "Spacing Modifier Letters": "ubSpacingModifierLetters",
    "Combining Diacritical Marks": "ubCombiningDiacriticalMarks",
    "Greek and Coptic": "ubGreekAndCoptic",
    "Cyrillic": "ubCyrillic",
    "Cyrillic Supplement": "ubCyrillicSupplement",
    "Armenian": "ubArmenian",
    "Hebrew": "ubHebrew",
    "Arabic": "ubArabic",
    "Syriac": "ubSyriac",
    "Thaana": "ubThaana",
    "NKo": "ubNKo",
    "Samaritan": "ubSamaritan",
    "Mandaic": "ubMandaic",
    "Syriac Supplement": "ubSyriacSupplement",
    "Arabic Extended-B": "ubArabicExtendedB",
    "Arabic Extended-A": "ubArabicExtendedA",
    "Devanagari": "ubDevanagari",
    "Bengali": "ubBengali",
    "Gurmukhi": "ubGurmukhi",
    "Gujarati": "ubGujarati",
    "Oriya": "ubOriya",
    "Tamil": "ubTamil",
    "Telugu": "ubTelugu",
    "Kannada": "ubKannada",
    "Malayalam": "ubMalayalam",
    "Sinhala": "ubSinhala",
    "Thai": "ubThai",
    "Lao": "ubLao",
    "Tibetan": "ubTibetan",
    "Myanmar": "ubMyanmar",
    "Georgian": "ubGeorgian",
    "Hangul Jamo": "ubHangulJamo",
    "Ethiopic": "ubEthiopic",
    "Ethiopic Supplement": "ubEthiopicSupplement",
    "Cherokee": "ubCherokee",
    "Unified Canadian Aboriginal Syllabics": "ubUnifiedCanadianAboriginalSyllabics",
    "Ogham": "ubOgham",
    "Runic": "ubRunic",
    "Tagalog": "ubTagalog",
    "Hanunoo": "ubHanunoo",
    "Buhid": "ubBuhid",
    "Tagbanwa": "ubTagbanwa",
    "Khmer": "ubKhmer",
    "Mongolian": "ubMongolian",
    "Unified Canadian Aboriginal Syllabics Extended": "ubUnifiedCanadianAboriginalSyllabicsExtended",
    "Limbu": "ubLimbu",
    "Tai Le": "ubTaiLe",
    "New Tai Lue": "ubNewTaiLue",
    "Khmer Symbols": "ubKhmerSymbols",
    "Buginese": "ubBuginese",
    "Tai Tham": "ubTaiTham",
    "Combining Diacritical Marks Extended": "ubCombiningDiacriticalMarksExtended",
    "Balinese": "ubBalinese",
    "Sundanese": "ubSundanese",
    "Batak": "ubBatak",
    "Lepcha": "ubLepcha",
    "Ol Chiki": "ubOlChiki",
    "Cyrillic Extended-C": "ubCyrillicExtendedC",
    "Georgian Extended": "ubGeorgianExtended",
    "Sundanese Supplement": "ubSundaneseSupplement",
    "Vedic Extensions": "ubVedicExtensions",
    "Phonetic Extensions": "ubPhoneticExtensions",
    "Phonetic Extensions Supplement": "ubPhoneticExtensionsSupplement",
    "Combining Diacritical Marks Supplement": "ubCombiningDiacriticalMarksSupplement",
    "Latin Extended Additional": "ubLatinExtendedAdditional",
    "Greek Extended": "ubGreekExtended",
    "General Punctuation": "ubGeneralPunctuation",
    "Superscripts and Subscripts": "ubSuperscriptsAndSubscripts",
    "Currency Symbols": "ubCurrencySymbols",
    "Combining Diacritical Marks for Symbols": "ubCombiningDiacriticalMarksforSymbols",
    "Letterlike Symbols": "ubLetterlikeSymbols",
    "Number Forms": "ubNumberForms",
    "Arrows": "ubArrows",
    "Mathematical Operators": "ubMathematicalOperators",
    "Miscellaneous Technical": "ubMiscellaneousTechnical",
    "Control Pictures": "ubControlPictures",
    "Optical Character Recognition": "ubOpticalCharacterRecognition",
    "Enclosed Alphanumerics": "ubEnclosedAlphanumerics",
    "Box Drawing": "ubBoxDrawing",
    "Block Elements": "ubBlockElements",
    "Geometric Shapes": "ubGeometricShapes",
    "Miscellaneous Symbols": "ubMiscellaneousSymbols",
    "Dingbats": "ubDingbats",
    "Miscellaneous Mathematical Symbols-A": "ubMiscellaneousMathematicalSymbolsA",
    "Supplemental Arrows-A": "ubSupplementalArrowsA",
    "Braille Patterns": "ubBraillePatterns",
    "Supplemental Arrows-B": "ubSupplementalArrowsB",
    "Miscellaneous Mathematical Symbols-B": "ubMiscellaneousMathematicalSymbolsB",
    "Supplemental Mathematical Operators": "ubSupplementalMathematicalOperators",
    "Miscellaneous Symbols and Arrows": "ubMiscellaneousSymbolsAndArrows",
    "Glagolitic": "ubGlagolitic",
    "Latin Extended-C": "ubLatinExtendedC",
    "Coptic": "ubCoptic",
    "Georgian Supplement": "ubGeorgianSupplement",
    "Tifinagh": "ubTifinagh",
    "Ethiopic Extended": "ubEthiopicExtended",
    "Cyrillic Extended-A": "ubCyrillicExtendedA",
    "Supplemental Punctuation": "ubSupplementalPunctuation",
    "CJK Radicals Supplement": "ubCJKRadicalsSupplement",
    "Kangxi Radicals": "ubKangxiRadicals",
    "Ideographic Description Characters": "ubIdeographicDescriptionCharacters",
    "CJK Symbols and Punctuation": "ubCJKSymbolsAndPunctuation",
    "Hiragana": "ubHiragana",
    "Katakana": "ubKatakana",
    "Bopomofo": "ubBopomofo",
    "Hangul Compatibility Jamo": "ubHangulCompatibilityJamo",
    "Kanbun": "ubKanbun",
    "Bopomofo Extended": "ubBopomofoExtended",
    "CJK Strokes": "ubCJKStrokes",
    "Katakana Phonetic Extensions": "ubKatakanaPhoneticExtensions",
    "Enclosed CJK Letters and Months": "ubEnclosedCJKLettersAndMonths",
    "CJK Compatibility": "ubCJKCompatibility",
    "CJK Unified Ideographs Extension A": "ubCJKUnifiedIdeographsExtensionA",
    "Yijing Hexagram Symbols": "ubYijingHexagramSymbols",
    "CJK Unified Ideographs": "ubCJKUnifiedIdeographs",
    "Yi Syllables": "ubYiSyllables",
    "Yi Radicals": "ubYiRadicals",
    "Lisu": "ubLisu",
    "Vai": "ubVai",
    "Cyrillic Extended-B": "ubCyrillicExtendedB",
    "Bamum": "ubBamum",
    "Modifier Tone Letters": "ubModifierToneLetters",
    "Latin Extended-D": "ubLatinExtendedD",
    "Syloti Nagri": "ubSylotiNagri",
    "Common Indic Number Forms": "ubCommonIndicNumberForms",
    "Phags-pa": "ubPhagsPa",
    "Saurashtra": "ubSaurashtra",
    "Devanagari Extended": "ubDevanagariExtended",
    "Kayah Li": "ubKayahLi",
    "Rejang": "ubRejang",
    "Hangul Jamo Extended-A": "ubHangulJamoExtendedA",
    "Javanese": "ubJavanese",
    "Myanmar Extended-B": "ubMyanmarExtendedB",
    "Cham": "ubCham",
    "Myanmar Extended-A": "ubMyanmarExtendedA",
    "Tai Viet": "ubTaiViet",
    "Meetei Mayek Extensions": "ubMeeteiMayekExtensions",
    "Ethiopic Extended-A": "ubEthiopicExtendedA",
    "Latin Extended-E": "ubLatinExtendedE",
    "Cherokee Supplement": "ubCherokeeSupplement",
    "Meetei Mayek": "ubMeeteiMayek",
    "Hangul Syllables": "ubHangulSyllables",
    "Hangul Jamo Extended-B": "ubHangulJamoExtendedB",
    "High Surrogates": "ubHighSurrogates",
    "High Private Use Surrogates": "ubHighPrivateUseSurrogates",
    "Low Surrogates": "ubLowSurrogates",
    "Private Use Area": "ubPrivateUseArea",
    "CJK Compatibility Ideographs": "ubCJKCompatibilityIdeographs",
    "Alphabetic Presentation Forms": "ubAlphabeticPresentationForms",
    "Arabic Presentation Forms-A": "ubArabicPresentationFormsA",
    "Variation Selectors": "ubVariationSelectors",
    "Vertical Forms": "ubVerticalForms",
    "Combining Half Marks": "ubCombiningHalfMarks",
    "CJK Compatibility Forms": "ubCJKCompatibilityForms",
    "Small Form Variants": "ubSmallFormVariants",
    "Arabic Presentation Forms-B": "ubArabicPresentationFormsB",
    "Halfwidth and Fullwidth Forms": "ubHalfwidthAndFullwidthForms",
    "Specials": "ubSpecials",
    "Linear B Syllabary": "ubLinearBSyllabary",
    "Linear B Ideograms": "ubLinearBIdeograms",
    "Aegean Numbers": "ubAegeanNumbers",
    "Ancient Greek Numbers": "ubAncientGreekNumbers",
    "Ancient Symbols": "ubAncientSymbols",
    "Phaistos Disc": "ubPhaistosDisc",
    "Lycian": "ubLycian",
    "Carian": "ubCarian",
    "Coptic Epact Numbers": "ubCopticEpactNumbers",
    "Old Italic": "ubOldItalic",
    "Gothic": "ubGothic",
    "Old Permic": "ubOldPermic",
    "Ugaritic": "ubUgaritic",
    "Old Persian": "ugOldPersian",
    "Deseret": "ubDeseret",
    "Shavian": "ubShavian",
    "Osmanya": "ubOsmanya",
    "Osage": "ubOsage",
    "Elbasan": "ubElbasan",
    "Caucasian Albanian": "ubCaucasianAlbanian",
    "Vithkuqi": "ubVithkuqi",
    "Linear A": "ubLinearA",
    "Latin Extended-F": "ubLatinExtendedF",
    "Cypriot Syllabary": "ubCypriotSyllabary",
    "Imperial Aramaic": "ubImperialAramaic",
    "Palmyrene": "ubPalmyrene",
    "Nabataean": "ubNabataean",
    "Hatran": "ubHatran",
    "Phoenician": "ubPhoenician",
    "Lydian": "ubLydian",
    "Meroitic Hieroglyphs": "ubMeroiticHieroglyphs",
    "Meroitic Cursive": "ubMeroiticCursive",
    "Kharoshthi": "ubKharoshthi",
    "Old South Arabian": "ubOldSouthArabian",
    "Old North Arabian": "ubOldNorthArabian",
    "Manichaean": "ubManichaean",
    "Avestan": "ubAvestan",
    "Inscriptional Parthian": "ubInscriptionalParthian",
    "Inscriptional Pahlavi": "ubInscriptionalPahlavi",
    "Psalter Pahlavi": "ubPsalterPahlavi",
    "Old Turkic": "ubOldTurkic",
    "Old Hungarian": "ubOldHungarian",
    "Hanifi Rohingya": "ubHanifiRohingya",
    "Rumi Numeral Symbols": "ubRumiNumeralSymbols",
    "Yezidi": "ubYezidi",
    "Arabic Extended-C": "ubArabicExtendedC",
    "Old Sogdian": "ugOldSogdian",
    "Sogdian": "ubSogdian",
    "Old Uyghur": "ubOldUyghur",
    "Chorasmian": "ubChorasmian",
    "Elymaic": "ubElymaic",
    "Brahmi": "ubBrahmi",
    "Kaithi": "ubKaithi",
    "Sora Sompeng": "ubSoraSompeng",
    "Chakma": "ubChakma",
    "Mahajani": "ubMahajani",
    "Sharada": "ubSharada",
    "Sinhala Archaic Numbers": "ubSinhalaArchaicNumbers",
    "Khojki": "ubKhojki",
    "Multani": "ubMultani",
    "Khudawadi": "ubKhudawadi",
    "Grantha": "ubGrantha",
    "Newa": "ubNewa",
    "Tirhuta": "ubTirhuta",
    "Siddham": "ubSiddham",
    "Modi": "ubModi",
    "Mongolian Supplement": "ubMongolianSupplement",
    "Takri": "ubTakri",
    "Myanmar Extended-C": "ugMyanmarExtendedC",
    "Ahom": "ugAhom",
    "Dogra": "ubDogra",
    "Nandinagari": "ubNandinagari",
    "Zanabazar Square": "ubZanabazarSquare",
    "Soyombo": "ubSoyombo",
    "Unified Canadian Aboriginal Syllabics Extended-A": "ubUnifiedCanadianAboriginalSyllabicsExtendedA",
    "Pau Cin Hau": "ubPauCinHau",
    "Devanagari Extended-A": "ugDevanagariExtendedA",
    "Bhaiksuki": "ubBhaiksuki",
    "Marchen": "ubMarchen",
    "Masaram Gondi": "ubMasaramGondi",
    "Gunjala Gondi": "ubGunjalaGondi",
    "Makasar": "ubMakasar",
    "Kawi": "ubKawi",
    "Lisu Supplement": "ubLisuSupplement",
    "Tamil Supplement": "ubTamilSupplement",
    "Cuneiform": "ubCuneiform",
    "Cuneiform Numbers and Punctuation": "ubCuneiformNumbersAndPunctuation",
    "Early Dynastic Cuneiform": "ugEarlyDynasticCuneiform",
    "Cypro-Minoan": "ubCyproMinoan",
    "Egyptian Hieroglyphs": "ugEgyptianHieroglyphs",
    "Egyptian Hieroglyphs Extended-A": "ubEgyptianHieroglyphsExtendedA",
    "Anatolian Hieroglyphs": "ugAnatolianHieroglyphs",
    "Gurung Khema": "ugGurungKhema",
    "Bamum Supplement": "ubBamumSupplement",
    "Mro": "ubMro",
    "Tangsa": "ubTangsa",
    "Bassa Vah": "ubBassaVah",
    "Pahawh Hmong": "ubPahawhHmong",
    "Medefaidrin": "ubMedefaidrin",
    "Miao": "ubMiao",
    "Ideographic Symbols and Punctuation": "ubIdeographicSymbolsAndPunctuation",
    "Tangut": "ubTangut",
    "Tangut Components": "ubTangutComponents",
    "Khitan Small Script": "ubKhitanSmallScript",
    "Tangut Supplement": "ubTangutSupplement",
    "Kaktovik Numerals": "ugKaktovikNumerals",
    "Katakana Extended": "ubKatakanaExtended",
    "Katakana Phonetic Extensions Supplement": "ubKatakanaPhoneticExtensionsSupplement",
    "CJK Unified Ideographs Extension B": "ubCJKUnifiedIdeographsExtensionB",
    "CJK Unified Ideographs Extension C": "ubCJKUnifiedIdeographsExtensionC",
    "CJK Unified Ideographs Extension D": "ubCJKUnifiedIdeographsExtensionD",
    "CJK Unified Ideographs Extension E": "ubCJKUnifiedIdeographsExtensionE",
    "CJK Unified Ideographs Extension F": "ubCJKUnifiedIdeographsExtensionF",
    "CJK Unified Ideographs Extension I": "ubCJKUnifiedIdeographsExtensionI",
    "CJK Compatibility Ideographs Supplement": "ubCJKCompatibilityIdeographsSupplement",
    "CJK Unified Ideographs Extension G": "ubCJKUnifiedIdeographsExtensionG",
    "CJK Unified Ideographs Extension H": "ubCJKUnifiedIdeographsExtensionH",
    "Tags": "ubTags",
    "Variation Selectors Supplement": "ubVariationSelectorsSupplement",
    "Supplementary Private Use Area-A": "ubSupplementaryPrivateUseAreaA",
    "Supplementary Private Use Area-B": "ubSupplementaryPrivateUseAreaB",
    "No Block": "ubNoBlock",
}


def download_ucd(version: str, filename: str) -> str:
    """Download a UCD file, return its text content."""
    url = UCD_BASE.format(version=version) + filename
    print(f"  Downloading {url} ...", file=sys.stderr)
    try:
        with urllib.request.urlopen(url, timeout=30) as resp:
            data = resp.read().decode("utf-8", errors="replace")
        return data
    except urllib.error.HTTPError as e:
        print(f"  ERROR: HTTP {e.code} fetching {url}", file=sys.stderr)
        sys.exit(1)


def parse_scripts(text: str) -> List[Tuple[int, int, str]]:
    """Parse Scripts.txt into list of (start, end, script_name)."""
    ranges = []
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        # Format: 0041..005A ; Latin # L&  LATIN CAPITAL LETTER A ...
        parts = line.split(";")
        if len(parts) < 2:
            continue
        cp_range = parts[0].strip()
        script = parts[1].split("#")[0].strip()
        if ".." in cp_range:
            start, end = cp_range.split("..")
            ranges.append((int(start, 16), int(end, 16), script))
        else:
            cp = int(cp_range, 16)
            ranges.append((cp, cp, script))
    return ranges


def parse_blocks(text: str) -> List[Tuple[int, int, str]]:
    """Parse Blocks.txt into list of (start, end, block_name)."""
    ranges = []
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        # Format: 0000..007F; Basic Latin
        parts = line.split(";")
        if len(parts) < 2:
            continue
        cp_range = parts[0].strip()
        block = parts[1].strip()
        if ".." in cp_range:
            start, end = cp_range.split("..")
            ranges.append((int(start, 16), int(end, 16), block))
        else:
            cp = int(cp_range, 16)
            ranges.append((cp, cp, block))
    return ranges


def generate_script_inc(ranges: List[Tuple[int, int, str]], version: str) -> str:
    """Generate Pascal .inc file for Script property."""
    lines = []
    lines.append(f"// {{Auto-generated by gen_unicode_script_block.py — Unicode {version}}}")
    lines.append("// Script property range tables.")
    lines.append("// Do not edit manually.")
    lines.append("")
    lines.append("const")
    lines.append(f"  SCRIPT_RANGES_COUNT = {len(ranges)};")
    lines.append("")
    lines.append("  // Format: (StartCodepoint, EndCodepoint, ScriptOrdinal)")
    lines.append("  SCRIPT_RANGES: array[0..SCRIPT_RANGES_COUNT - 1] of record")
    lines.append("    Lo: TUnicodeCodepoint;")
    lines.append("    Hi: TUnicodeCodepoint;")
    lines.append("    Script: Byte;")
    lines.append("  end = (")

    for i, (start, end, script) in enumerate(ranges):
        script_name = SCRIPT_NAMES.get(script, "usUnknown")
        comma = "," if i < len(ranges) - 1 else ""
        lines.append(f"    (Lo: ${start:04X}; Hi: ${end:04X}; Script: Ord({script_name})){comma}")

    lines.append("  );")
    return "\n".join(lines)


def generate_block_inc(ranges: List[Tuple[int, int, str]], version: str) -> str:
    """Generate Pascal .inc file for Block property."""
    lines = []
    lines.append(f"// {{Auto-generated by gen_unicode_script_block.py — Unicode {version}}}")
    lines.append("// Block property range tables.")
    lines.append("// Do not edit manually.")
    lines.append("")
    lines.append("const")
    lines.append(f"  BLOCK_RANGES_COUNT = {len(ranges)};")
    lines.append("")
    lines.append("  // Format: (StartCodepoint, EndCodepoint, BlockOrdinal)")
    lines.append("  BLOCK_RANGES: array[0..BLOCK_RANGES_COUNT - 1] of record")
    lines.append("    Lo: TUnicodeCodepoint;")
    lines.append("    Hi: TUnicodeCodepoint;")
    lines.append("    Block: Byte;")
    lines.append("  end = (")

    for i, (start, end, block) in enumerate(ranges):
        block_name = BLOCK_NAMES.get(block, "ubNoBlock")
        comma = "," if i < len(ranges) - 1 else ""
        lines.append(f"    (Lo: ${start:04X}; Hi: ${end:04X}; Block: Ord({block_name})){comma}")

    lines.append("  );")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Generate Unicode Script/Block → Pascal .inc tables")
    parser.add_argument("--version", default=DEFAULT_VERSION, help="Unicode version (e.g. 16.0.0)")
    parser.add_argument("--output-dir", default=".", help="Output directory for .inc files")
    args = parser.parse_args()

    print(f"Generating Unicode {args.version} Script/Block data tables", file=sys.stderr)

    os.makedirs(args.output_dir, exist_ok=True)

    # ── Step 1: Download UCD files ──
    print("Step 1/3: Downloading UCD files...", file=sys.stderr)
    scripts_text = download_ucd(args.version, "Scripts.txt")
    blocks_text = download_ucd(args.version, "Blocks.txt")

    # ── Step 2: Parse ──
    print("Step 2/3: Parsing UCD data...", file=sys.stderr)
    script_ranges = parse_scripts(scripts_text)
    block_ranges = parse_blocks(blocks_text)

    # ── Step 3: Generate .inc files ──
    print("Step 3/3: Writing Pascal .inc files...", file=sys.stderr)

    script_inc = generate_script_inc(script_ranges, args.version)
    block_inc = generate_block_inc(block_ranges, args.version)

    script_path = os.path.join(args.output_dir, "nextpas.core.text.unicode.script.inc")
    block_path = os.path.join(args.output_dir, "nextpas.core.text.unicode.block.inc")

    with open(script_path, "w", encoding="utf-8") as f:
        f.write(script_inc)
    print(f"  Wrote {script_path}", file=sys.stderr)

    with open(block_path, "w", encoding="utf-8") as f:
        f.write(block_inc)
    print(f"  Wrote {block_path}", file=sys.stderr)

    print(f"Done. Generated {len(script_ranges)} script ranges and {len(block_ranges)} block ranges.", file=sys.stderr)


if __name__ == "__main__":
    main()
