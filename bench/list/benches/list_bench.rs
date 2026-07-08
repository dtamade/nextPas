use criterion::{criterion_group, criterion_main, Criterion};
use std::hint::black_box;

const N: usize = 100_000;

struct Node {
    value: i64,
    next: Option<Box<Node>>,
}

fn build_list(count: usize) -> Option<Box<Node>> {
    let mut head: Option<Box<Node>> = None;
    let mut tail: &mut Option<Box<Node>> = &mut head;
    for i in 0..count {
        let node = Box::new(Node { value: i as i64, next: None });
        *tail = Some(node);
        tail = &mut tail.as_mut().unwrap().next;
    }
    head
}

fn traverse_sum(head: &Option<Box<Node>>) -> i64 {
    let mut sum = 0i64;
    let mut cur = head;
    while let Some(n) = cur {
        sum += n.value;
        cur = &n.next;
    }
    sum
}

fn bench_build(c: &mut Criterion) {
    c.bench_function("Build/100k", |b| {
        b.iter(|| {
            let head = build_list(N);
            black_box(&head);
        })
    });
}

fn bench_traverse(c: &mut Criterion) {
    let head = build_list(N);
    c.bench_function("Traverse/100k", |b| {
        b.iter(|| {
            let s = traverse_sum(&head);
            black_box(s);
        })
    });
}

fn bench_build_traverse(c: &mut Criterion) {
    c.bench_function("BuildTraverse/100k", |b| {
        b.iter(|| {
            let head = build_list(N);
            let s = traverse_sum(&head);
            black_box(s);
        })
    });
}

criterion_group!(benches, bench_build, bench_traverse, bench_build_traverse);
criterion_main!(benches);
