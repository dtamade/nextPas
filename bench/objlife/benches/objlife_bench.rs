// Object lifecycle benchmark — Rust (criterion)
use criterion::{criterion_group, criterion_main, Criterion, black_box};

const N: usize = 100000;

struct Node {
    next: Option<Box<Node>>,
    value: i64,
    pad: [u8; 48],
}

fn bench_alloc_free(c: &mut Criterion) {
    c.bench_function("ObjLife/AllocFree", |b| {
        b.iter(|| {
            let mut head: Option<Box<Node>> = None;
            for i in 0..N {
                head = Some(Box::new(Node {
                    next: head,
                    value: i as i64,
                    pad: [0; 48],
                }));
            }
            black_box(head);
        })
    });
}

fn bench_alloc_free_vec(c: &mut Criterion) {
    c.bench_function("ObjLife/AllocFreeShuffle", |b| {
        b.iter(|| {
            let mut arr: Vec<Box<Node>> = Vec::with_capacity(N);
            for i in 0..N {
                arr.push(Box::new(Node {
                    next: None,
                    value: i as i64,
                    pad: [0; 48],
                }));
            }
            // Drop in reverse
            for i in (0..N).rev() {
                arr.truncate(i);
            }
        })
    });
}

fn bench_linked_build(c: &mut Criterion) {
    c.bench_function("ObjLife/LinkedBuild", |b| {
        b.iter(|| {
            let mut head: Option<Box<Node>> = None;
            for i in 0..N {
                head = Some(Box::new(Node {
                    next: head,
                    value: i as i64,
                    pad: [0; 48],
                }));
            }
            let mut sum: i64 = 0;
            let mut cur = &head;
            while let Some(ref node) = cur {
                sum += node.value;
                cur = &node.next;
            }
            black_box(sum);
        })
    });
}

criterion_group!(benches, bench_alloc_free, bench_alloc_free_vec, bench_linked_build);
criterion_main!(benches);
