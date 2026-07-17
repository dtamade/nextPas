use criterion::{criterion_group, criterion_main, Criterion, black_box};
use icu_normalizer::{ComposingNormalizer, DecomposingNormalizer};
use icu_collator::*;
use icu_segmenter::GraphemeClusterSegmenter;
use icu_casemap::CaseMapper;

const ASCII_50: &str = "The quick brown fox jumps over the lazy dog 12345!";
const ASCII_200: &str = "The quick brown fox jumps over the lazy dog. Pack my box with five dozen liquor jugs. How vexingly quick daft zebras jump! The five boxing wizards jump quickly. Crazy Frederick bought many very exquisite opal jewels. Sphinx of black quartz, judge my vow. Two driven jocks help fax my big quiz.";
const BMP_LATIN_50: &str = "ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞßàáâãäåæçèéêëìíîïðñò";
const BMP_CJK_50: &str = "一丁丂七丄丅丆万丈三上下丌不与丏丐丑丒专且丕世丗丘丙业丛东丝丞丟丠両丢丣两严並丧丨丩个丫丬中丮丯丰丱";

// N1-N10: Normalization

fn bench_nfc_ascii50(c: &mut Criterion) {
    let normalizer = ComposingNormalizer::new_nfc();
    c.bench_function("NFC ASCII-50", |b| {
        b.iter(|| black_box(normalizer.normalize(black_box(ASCII_50))))
    });
}

fn bench_nfc_ascii200(c: &mut Criterion) {
    let normalizer = ComposingNormalizer::new_nfc();
    c.bench_function("NFC ASCII-200", |b| {
        b.iter(|| black_box(normalizer.normalize(black_box(ASCII_200))))
    });
}

fn bench_nfd_ascii50(c: &mut Criterion) {
    let normalizer = DecomposingNormalizer::new_nfd();
    c.bench_function("NFD ASCII-50", |b| {
        b.iter(|| black_box(normalizer.normalize(black_box(ASCII_50))))
    });
}

fn bench_nfc_bmp_latin50(c: &mut Criterion) {
    let normalizer = ComposingNormalizer::new_nfc();
    c.bench_function("NFC BMP-Latin-50", |b| {
        b.iter(|| black_box(normalizer.normalize(black_box(BMP_LATIN_50))))
    });
}

fn bench_nfd_bmp_latin50(c: &mut Criterion) {
    let normalizer = DecomposingNormalizer::new_nfd();
    c.bench_function("NFD BMP-Latin-50", |b| {
        b.iter(|| black_box(normalizer.normalize(black_box(BMP_LATIN_50))))
    });
}

fn bench_nfc_bmp_cjk50(c: &mut Criterion) {
    let normalizer = ComposingNormalizer::new_nfc();
    c.bench_function("NFC BMP-CJK-50", |b| {
        b.iter(|| black_box(normalizer.normalize(black_box(BMP_CJK_50))))
    });
}

fn bench_nfd_bmp_cjk50(c: &mut Criterion) {
    let normalizer = DecomposingNormalizer::new_nfd();
    c.bench_function("NFD BMP-CJK-50", |b| {
        b.iter(|| black_box(normalizer.normalize(black_box(BMP_CJK_50))))
    });
}

fn bench_nfkd_bmp_latin50(c: &mut Criterion) {
    let normalizer = DecomposingNormalizer::new_nfkd();
    c.bench_function("NFKD BMP-Latin-50", |b| {
        b.iter(|| black_box(normalizer.normalize(black_box(BMP_LATIN_50))))
    });
}

// G1-G4: Segmentation

fn bench_grapheme_ascii200(c: &mut Criterion) {
    let segmenter = GraphemeClusterSegmenter::new();
    c.bench_function("NextGrapheme ASCII-200", |b| {
        b.iter(|| {
            let mut count = 0;
            for _ in segmenter.segment_str(black_box(ASCII_200)) {
                count += 1;
            }
            black_box(count)
        })
    });
}

fn bench_grapheme_bmp_cjk50(c: &mut Criterion) {
    let segmenter = GraphemeClusterSegmenter::new();
    c.bench_function("NextGrapheme BMP-CJK-50", |b| {
        b.iter(|| {
            let mut count = 0;
            for _ in segmenter.segment_str(black_box(BMP_CJK_50)) {
                count += 1;
            }
            black_box(count)
        })
    });
}

// C1-C5: Collation

fn bench_compare_ascii50(c: &mut Criterion) {
    let collator = Collator::new(&Default::default(), CollatorOptions::new());
    c.bench_function("Compare ASCII-50 vs 200", |b| {
        b.iter(|| black_box(collator.compare(black_box(ASCII_50), black_box(ASCII_200))))
    });
}

fn bench_compare_bmp_latin50(c: &mut Criterion) {
    let collator = Collator::new(&Default::default(), CollatorOptions::new());
    c.bench_function("Compare BMP-Latin-50", |b| {
        b.iter(|| black_box(collator.compare(black_box(BMP_LATIN_50), black_box(BMP_LATIN_50))))
    });
}

fn bench_compare_bmp_cjk50(c: &mut Criterion) {
    let collator = Collator::new(&Default::default(), CollatorOptions::new());
    c.bench_function("Compare BMP-CJK-50", |b| {
        b.iter(|| black_box(collator.compare(black_box(BMP_CJK_50), black_box(BMP_CJK_50))))
    });
}

// F1-F5: Case

fn bench_to_upper_ascii200(c: &mut Criterion) {
    let casemap = CaseMapper::new();
    c.bench_function("ToUpper ASCII-200", |b| {
        b.iter(|| black_box(casemap.uppercase_to_string(black_box(ASCII_200))))
    });
}

fn bench_to_upper_bmp_latin50(c: &mut Criterion) {
    let casemap = CaseMapper::new();
    c.bench_function("ToUpper BMP-Latin-50", |b| {
        b.iter(|| black_box(casemap.uppercase_to_string(black_box(BMP_LATIN_50))))
    });
}

criterion_group!(
    benches,
    bench_nfc_ascii50,
    bench_nfc_ascii200,
    bench_nfd_ascii50,
    bench_nfc_bmp_latin50,
    bench_nfd_bmp_latin50,
    bench_nfc_bmp_cjk50,
    bench_nfd_bmp_cjk50,
    bench_nfkd_bmp_latin50,
    bench_grapheme_ascii200,
    bench_grapheme_bmp_cjk50,
    bench_compare_ascii50,
    bench_compare_bmp_latin50,
    bench_compare_bmp_cjk50,
    bench_to_upper_ascii200,
    bench_to_upper_bmp_latin50,
);
criterion_main!(benches);
