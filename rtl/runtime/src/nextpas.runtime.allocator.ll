; nextpas.runtime.allocator.ll — 核心堆分配器 (np_alloc, np_free, np_allocator_fault)
;
; 从 np_hir_llvm_emitter.pas EmitAllocHelper/EmitFreeHelper/EmitAllocatorFaultHelper 提取
; 去掉 internal linkage，改为外部可见
;
; Gate 4 Phase 2: runtime 模块
;
; 分配器布局:
;   小块 (<64K): bump pointer via brk + free list reuse + coalesce
;   大块 (>=64K): mmap with hidden 16-byte prelude (magic + length)
;   free list entry: [size: i64] [next: ptr] (16 bytes header)

target datalayout = "e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v64:64:64-v128:128:128-a0:0:64-s0:64:64-f80:128:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

; Allocator constants (must match NP_ALLOCATOR_* in np_hir_llvm_emitter.pas)
; PAGE_SIZE = 4096, PRELUDE_SIZE = 16, MIN_SMALL_BLOCK_SIZE = 24
; LARGE_THRESHOLD = 65536, LARGE_MAGIC = 131388245100000016

@__heap_cur = global ptr null
@__heap_free = global ptr null

declare void @llvm.trap()

; void @np_allocator_fault(i64 %code, i64 %arg0, i64 %arg1)
define void @np_allocator_fault(i64 %code, i64 %arg0, i64 %arg1) {
entry:
  call void @llvm.trap()
  unreachable
}

; ptr @np_alloc(i64 %size)
define ptr @np_alloc(i64 %size) {
entry:
  %alloc.is.large = icmp uge i64 %size, 65536
  br i1 %alloc.is.large, label %alloc.large, label %alloc.small.normalize
alloc.large:
  %alloc.large.rawlen = add i64 %size, 16
  %alloc.rawlen.overflow = icmp ult i64 %alloc.large.rawlen, %size
  br i1 %alloc.rawlen.overflow, label %alloc.fault.prelude, label %alloc.round
alloc.fault.prelude:
  call void @np_allocator_fault(i64 2, i64 %size, i64 16)
  unreachable
alloc.round:
  %alloc.large.plusmask = add i64 %alloc.large.rawlen, 4095
  %alloc.plusmask.overflow = icmp ult i64 %alloc.large.plusmask, %alloc.large.rawlen
  br i1 %alloc.plusmask.overflow, label %alloc.fault.round, label %alloc.mmap
alloc.fault.round:
  call void @np_allocator_fault(i64 3, i64 %alloc.large.rawlen, i64 4096)
  unreachable
alloc.mmap:
  %alloc.mapped.len = and i64 %alloc.large.plusmask, -4096
  %alloc.mmap.result = call i64 asm sideeffect "movq $$9, %rax\0Axorq %rdi, %rdi\0Amovq $$3, %rdx\0Amovq $$34, %r10\0Amovq $$-1, %r8\0Axorq %r9, %r9\0Asyscall", "={rax},{rsi},~{rcx},~{r11},~{rdi},~{rdx},~{r10},~{r8},~{r9},~{memory}"(i64 %alloc.mapped.len)
  %alloc.mmap.failed = icmp eq i64 %alloc.mmap.result, -1
  br i1 %alloc.mmap.failed, label %alloc.fault.mmap, label %alloc.write.prelude
alloc.fault.mmap:
  call void @np_allocator_fault(i64 4, i64 %size, i64 %alloc.mapped.len)
  unreachable
alloc.write.prelude:
  %alloc.large.base = inttoptr i64 %alloc.mmap.result to ptr
  store i64 131388245100000016, ptr %alloc.large.base
  %alloc.large.lenp = getelementptr i8, ptr %alloc.large.base, i64 8
  store i64 %alloc.mapped.len, ptr %alloc.large.lenp
  %alloc.payload = getelementptr i8, ptr %alloc.large.base, i64 16
  ret ptr %alloc.payload

alloc.small.normalize:
  %alloc.too.small = icmp ult i64 %size, 24
  %alloc.size = select i1 %alloc.too.small, i64 24, i64 %size
  br label %free.scan
free.scan:
  %free.linkslot = phi ptr [ @__heap_free, %alloc.small.normalize ], [ %free.nextslot, %free.advance ]
  %free.head = load ptr, ptr %free.linkslot
  %free.has = icmp ne ptr %free.head, null
  br i1 %free.has, label %free.check, label %init
free.check:
  %free.size = load i64, ptr %free.head
  %free.fits = icmp uge i64 %free.size, %alloc.size
  br i1 %free.fits, label %reuse, label %free.advance
free.advance:
  %free.nextslot = getelementptr i8, ptr %free.head, i64 16
  br label %free.scan
reuse:
  %free.nextp = getelementptr i8, ptr %free.head, i64 16
  %free.next = load ptr, ptr %free.nextp
  store ptr %free.next, ptr %free.linkslot
  ret ptr %free.head
init:
  %cur = load ptr, ptr @__heap_cur
  %is_null = icmp eq ptr %cur, null
  br i1 %is_null, label %heap.init, label %alloc
heap.init:
  %brk0 = call i64 asm sideeffect "movq $$12, %rax\0Axorq %rdi, %rdi\0Asyscall", "={rax},~{rcx},~{r11},~{rdi}"()
  %brk0p = inttoptr i64 %brk0 to ptr
  store ptr %brk0p, ptr @__heap_cur
  br label %alloc
alloc:
  %base = load ptr, ptr @__heap_cur
  %next = getelementptr i8, ptr %base, i64 %alloc.size
  %nexti = ptrtoint ptr %next to i64
  call i64 asm sideeffect "movq $$12, %rax\0Asyscall", "={rax},{rdi},~{rcx},~{r11}"(i64 %nexti)
  store ptr %next, ptr @__heap_cur
  ret ptr %base
}

; void @np_free(ptr %raw, i64 %size)
define void @np_free(ptr %raw, i64 %size) {
entry:
  %free.is.large = icmp uge i64 %size, 65536
  br i1 %free.is.large, label %free.large, label %free.small
free.large:
  %free.large.base = getelementptr i8, ptr %raw, i64 -16
  %free.large.magic = load i64, ptr %free.large.base
  %free.large.magic.ok = icmp eq i64 %free.large.magic, 131388245100000016
  br i1 %free.large.magic.ok, label %free.large.len.check, label %free.large.magic.fault
free.large.magic.fault:
  call void @np_allocator_fault(i64 5, i64 %size, i64 %free.large.magic)
  unreachable
free.large.len.check:
  %free.large.lenp = getelementptr i8, ptr %free.large.base, i64 8
  %free.large.len = load i64, ptr %free.large.lenp
  %free.large.min = add i64 %size, 16
  %free.large.min.overflow = icmp ult i64 %free.large.min, %size
  br i1 %free.large.min.overflow, label %free.large.len.fault, label %free.large.len.validate
free.large.len.validate:
  %free.large.len.ok = icmp uge i64 %free.large.len, %free.large.min
  br i1 %free.large.len.ok, label %free.large.munmap, label %free.large.len.fault
free.large.len.fault:
  call void @np_allocator_fault(i64 6, i64 %size, i64 %free.large.len)
  unreachable
free.large.munmap:
  %free.large.base.i = ptrtoint ptr %free.large.base to i64
  %free.munmap.result = call i64 asm sideeffect "movq $$11, %rax\0Asyscall", "={rax},{rdi},{rsi},~{rcx},~{r11},~{memory}"(i64 %free.large.base.i, i64 %free.large.len)
  %free.munmap.ok = icmp eq i64 %free.munmap.result, 0
  br i1 %free.munmap.ok, label %free.done, label %free.munmap.fault
free.munmap.fault:
  call void @np_allocator_fault(i64 7, i64 %free.large.base.i, i64 %free.large.len)
  unreachable
free.small:
  %free.too.small = icmp ult i64 %size, 24
  %free.size.normalized = select i1 %free.too.small, i64 24, i64 %size
  %free.end = getelementptr i8, ptr %raw, i64 %free.size.normalized
  %free.cur = load ptr, ptr @__heap_cur
  %free.is.top = icmp eq ptr %free.cur, %free.end
  br i1 %free.is.top, label %free.reclaim, label %free.push
free.reclaim:
  %free.rawi = ptrtoint ptr %raw to i64
  call i64 asm sideeffect "movq $$12, %rax\0Asyscall", "={rax},{rdi},~{rcx},~{r11}"(i64 %free.rawi)
  store ptr %raw, ptr @__heap_cur
  ret void
free.push:
  br label %coalesce.scan
coalesce.scan:
  %coalesce.raw = phi ptr [ %raw, %free.push ], [ %coalesce.raw, %coalesce.advance ], [ %coalesce.raw, %coalesce.merge ], [ %coalesce.head, %coalesce.merge.prev ]
  %coalesce.total = phi i64 [ %free.size.normalized, %free.push ], [ %coalesce.total, %coalesce.advance ], [ %free.merged.total, %coalesce.merge ], [ %free.prev.merged.total, %coalesce.merge.prev ]
  %coalesce.linkslot = phi ptr [ @__heap_free, %free.push ], [ %coalesce.nextslot, %coalesce.advance ], [ @__heap_free, %coalesce.merge ], [ @__heap_free, %coalesce.merge.prev ]
  %coalesce.end = getelementptr i8, ptr %coalesce.raw, i64 %coalesce.total
  %coalesce.head = load ptr, ptr %coalesce.linkslot
  %coalesce.has = icmp ne ptr %coalesce.head, null
  br i1 %coalesce.has, label %coalesce.check, label %free.insert
coalesce.check:
  %coalesce.size = load i64, ptr %coalesce.head
  %coalesce.match = icmp eq ptr %coalesce.end, %coalesce.head
  br i1 %coalesce.match, label %coalesce.merge, label %coalesce.check.prev
coalesce.check.prev:
  %coalesce.prev.end = getelementptr i8, ptr %coalesce.head, i64 %coalesce.size
  %coalesce.prev.match = icmp eq ptr %coalesce.prev.end, %coalesce.raw
  br i1 %coalesce.prev.match, label %coalesce.merge.prev, label %coalesce.advance
coalesce.advance:
  %coalesce.nextslot = getelementptr i8, ptr %coalesce.head, i64 16
  br label %coalesce.scan
coalesce.merge:
  %free.merged.total = add i64 %coalesce.total, %coalesce.size
  %coalesce.nextp = getelementptr i8, ptr %coalesce.head, i64 16
  %coalesce.next = load ptr, ptr %coalesce.nextp
  store ptr %coalesce.next, ptr %coalesce.linkslot
  br label %coalesce.scan
coalesce.merge.prev:
  %free.prev.merged.total = add i64 %coalesce.size, %coalesce.total
  %coalesce.prev.nextp = getelementptr i8, ptr %coalesce.head, i64 16
  %coalesce.prev.next = load ptr, ptr %coalesce.prev.nextp
  store ptr %coalesce.prev.next, ptr %coalesce.linkslot
  br label %coalesce.scan
free.insert:
  store i64 %coalesce.total, ptr %coalesce.raw
  %free.nextp = getelementptr i8, ptr %coalesce.raw, i64 16
  %free.old = load ptr, ptr @__heap_free
  store ptr %free.old, ptr %free.nextp
  store ptr %coalesce.raw, ptr @__heap_free
  br label %free.done
free.done:
  ret void
}
