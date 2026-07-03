use criterion::{criterion_group, criterion_main, Criterion};
use std::hint::black_box;

const N: usize = 100_000;

struct BstNode {
    key: i64,
    left: Option<Box<BstNode>>,
    right: Option<Box<BstNode>>,
}

fn bst_insert(root: Option<Box<BstNode>>, key: i64) -> Option<Box<BstNode>> {
    match root {
        None => Some(Box::new(BstNode { key, left: None, right: None })),
        Some(mut node) => {
            if key < node.key {
                node.left = bst_insert(node.left, key);
            } else {
                node.right = bst_insert(node.right, key);
            }
            Some(node)
        }
    }
}

fn bst_lookup(root: &Option<Box<BstNode>>, key: i64) -> bool {
    let mut cur = root;
    while let Some(n) = cur {
        if key == n.key {
            return true;
        } else if key < n.key {
            cur = &n.left;
        } else {
            cur = &n.right;
        }
    }
    false
}

fn in_order_sum(root: &Option<Box<BstNode>>) -> i64 {
    match root {
        None => 0,
        Some(n) => in_order_sum(&n.left) + n.key + in_order_sum(&n.right),
    }
}

fn make_keys() -> Vec<i64> {
    let mut keys: Vec<i64> = (0..N as i64).collect();
    // Fisher-Yates shuffle with LCG
    let mut seed: u32 = 12345;
    for i in (1..N).rev() {
        seed = seed.wrapping_mul(1103515245).wrapping_add(12345);
        let j = (seed as usize) % (i + 1);
        keys.swap(i, j);
    }
    keys
}

fn bench_insert(c: &mut Criterion) {
    let keys = make_keys();
    c.bench_function("Insert/100k", |b| {
        b.iter(|| {
            let mut root: Option<Box<BstNode>> = None;
            for &k in &keys {
                root = bst_insert(root, k);
            }
            black_box(&root);
        })
    });
}

fn bench_lookup(c: &mut Criterion) {
    let keys = make_keys();
    let mut root: Option<Box<BstNode>> = None;
    for &k in &keys {
        root = bst_insert(root, k);
    }
    c.bench_function("Lookup/100k", |b| {
        b.iter(|| {
            let mut found = false;
            for &k in &keys {
                found = bst_lookup(&root, k);
            }
            black_box(found);
        })
    });
}

fn bench_insert_lookup(c: &mut Criterion) {
    let keys = make_keys();
    c.bench_function("InsertLookup/100k", |b| {
        b.iter(|| {
            let mut root: Option<Box<BstNode>> = None;
            for &k in &keys {
                root = bst_insert(root, k);
            }
            let mut found = false;
            for &k in &keys {
                found = bst_lookup(&root, k);
            }
            black_box(found);
        })
    });
}

fn bench_in_order(c: &mut Criterion) {
    let keys = make_keys();
    let mut root: Option<Box<BstNode>> = None;
    for &k in &keys {
        root = bst_insert(root, k);
    }
    c.bench_function("InOrder/100k", |b| {
        b.iter(|| {
            let s = in_order_sum(&root);
            black_box(s);
        })
    });
}

criterion_group!(benches, bench_insert, bench_lookup, bench_insert_lookup, bench_in_order);
criterion_main!(benches);
