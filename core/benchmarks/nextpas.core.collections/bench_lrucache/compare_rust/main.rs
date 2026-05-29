use std::collections::HashMap;
use std::time::Instant;

struct Node {
    key: i32,
    val: i32,
    prev: usize,
    next: usize,
}

struct LruCache {
    map: HashMap<i32, usize>,
    nodes: Vec<Node>,
    head: usize,
    tail: usize,
    cap: usize,
    free: Vec<usize>,
}

const SENTINEL: usize = usize::MAX;

impl LruCache {
    fn new(cap: usize) -> Self {
        Self {
            map: HashMap::with_capacity(cap),
            nodes: Vec::with_capacity(cap),
            head: SENTINEL, tail: SENTINEL,
            cap, free: Vec::new(),
        }
    }
    fn detach(&mut self, idx: usize) {
        let p = self.nodes[idx].prev;
        let n = self.nodes[idx].next;
        if p != SENTINEL { self.nodes[p].next = n; } else { self.head = n; }
        if n != SENTINEL { self.nodes[n].prev = p; } else { self.tail = p; }
    }
    fn push_back(&mut self, idx: usize) {
        self.nodes[idx].prev = self.tail;
        self.nodes[idx].next = SENTINEL;
        if self.tail != SENTINEL { self.nodes[self.tail].next = idx; }
        self.tail = idx;
        if self.head == SENTINEL { self.head = idx; }
    }
    fn get(&mut self, key: i32) -> Option<i32> {
        if let Some(&idx) = self.map.get(&key) {
            self.detach(idx);
            self.push_back(idx);
            Some(self.nodes[idx].val)
        } else { None }
    }
    fn put(&mut self, key: i32, val: i32) {
        if let Some(&idx) = self.map.get(&key) {
            self.nodes[idx].val = val;
            self.detach(idx);
            self.push_back(idx);
        } else {
            let idx = if self.map.len() >= self.cap {
                let evict = self.head;
                self.detach(evict);
                self.map.remove(&self.nodes[evict].key);
                self.nodes[evict].key = key;
                self.nodes[evict].val = val;
                evict
            } else if let Some(i) = self.free.pop() {
                self.nodes[i] = Node { key, val, prev: SENTINEL, next: SENTINEL };
                i
            } else {
                self.nodes.push(Node { key, val, prev: SENTINEL, next: SENTINEL });
                self.nodes.len() - 1
            };
            self.push_back(idx);
            self.map.insert(key, idx);
        }
    }
}

const CAP: usize = 1000;
const N: usize = 10000;
const ITERS: usize = 100;

fn main() {
    println!("=== Rust LRU O(1) (Cap={}, N={}) ===", CAP, N);

    let start = Instant::now();
    for _ in 0..ITERS {
        let mut c = LruCache::new(CAP);
        for i in 0..N as i32 { c.put(i, i * 10); }
        std::hint::black_box(&c.map);
    }
    println!("  Put(fill+evict): {:>10.1} ns/op", start.elapsed().as_nanos() as f64 / ITERS as f64);

    let mut c = LruCache::new(CAP);
    for i in 0..CAP as i32 { c.put(i, i * 10); }
    let start = Instant::now();
    let mut sink: i64 = 0;
    for _ in 0..ITERS*10 {
        for i in 0..CAP as i32 {
            if let Some(v) = c.get(i) { sink += v as i64; }
        }
    }
    println!("  Get(hit):        {:>10.1} ns/op", start.elapsed().as_nanos() as f64 / (ITERS * 10) as f64);
    std::hint::black_box(sink);
}
