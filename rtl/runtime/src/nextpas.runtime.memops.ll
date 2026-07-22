; nextpas.runtime.memops.ll — 基础内存操作 (np_memcpy, np_memmove, np_memset, np_memzero)
;
; 从 np_hir_llvm_emitter.pas EmitMemcpyHelper/EmitMemzeroHelper 提取
; 去掉 internal linkage，改为外部可见
;
; Gate 4 Phase 2: runtime 模块
;
; 优化策略:
;   n < 8:   逐字节循环
;   n >= 8:  按 8 字节块拷贝/填充 (qword load/store)
;   剩余字节: 逐字节处理
;
; 使用 qword 级操作替代逐字节，8x 吞吐量提升
; 不使用 rep movsb — LLVM inline asm 的寄存器约束限制太多，
; 正确的 SIMD 优化留待 LLVM opt pass 或后续 native backend

target datalayout = "e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v64:64:64-v128:128:128-a0:0:64-s0:64:64-f80:128:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

; ============================================================
; libc ABI shims — llc lowers llvm.memcpy/memset to memcpy/memset;
; freestanding link of libnprt must not require host -lc for those.
; ============================================================
define ptr @memcpy(ptr %dst, ptr %src, i64 %n) {
entry:
  call void @np_memcpy(ptr %dst, ptr %src, i64 %n)
  ret ptr %dst
}

define ptr @memset(ptr %dst, i32 %c, i64 %n) {
entry:
  %b = trunc i32 %c to i8
  call void @np_memset(ptr %dst, i8 %b, i64 %n)
  ret ptr %dst
}

; ============================================================
; np_memcpy — 不重叠拷贝 (dst != src 区域)
; ============================================================
define void @np_memcpy(ptr %dst, ptr %src, i64 %n) {
entry:
  %cmp0 = icmp eq i64 %n, 0
  br i1 %cmp0, label %done, label %qword_check
qword_check:
  %has_qword = icmp uge i64 %n, 8
  br i1 %has_qword, label %qword_loop, label %byte_loop
qword_loop:
  %qi = phi i64 [ 0, %qword_check ], [ %qi_next, %qword_loop ]
  %qsp = getelementptr i64, ptr %src, i64 %qi
  %qv = load i64, ptr %qsp
  %qdp = getelementptr i64, ptr %dst, i64 %qi
  store i64 %qv, ptr %qdp
  %qi_next = add i64 %qi, 1
  %qcount = lshr i64 %n, 3
  %qcond = icmp ult i64 %qi_next, %qcount
  br i1 %qcond, label %qword_loop, label %tail_setup
tail_setup:
  %qbytes = shl i64 %qcount, 3
  %remaining = sub i64 %n, %qbytes
  %has_tail = icmp ne i64 %remaining, 0
  br i1 %has_tail, label %tail_loop, label %done
tail_loop:
  %ti = phi i64 [ 0, %tail_setup ], [ %ti_next, %tail_loop ]
  %tidx = add i64 %qbytes, %ti
  %tsp = getelementptr i8, ptr %src, i64 %tidx
  %tb = load i8, ptr %tsp
  %tdp = getelementptr i8, ptr %dst, i64 %tidx
  store i8 %tb, ptr %tdp
  %ti_next = add i64 %ti, 1
  %tcond = icmp ult i64 %ti_next, %remaining
  br i1 %tcond, label %tail_loop, label %done
byte_loop:
  %bi = phi i64 [ 0, %qword_check ], [ %bi_next, %byte_loop ]
  %bsp = getelementptr i8, ptr %src, i64 %bi
  %bb = load i8, ptr %bsp
  %bdp = getelementptr i8, ptr %dst, i64 %bi
  store i8 %bb, ptr %bdp
  %bi_next = add i64 %bi, 1
  %bcond = icmp eq i64 %bi_next, %n
  br i1 %bcond, label %done, label %byte_loop
done:
  ret void
}

; ============================================================
; np_memmove — 重叠安全拷贝 (支持 src/dst 重叠)
; dst <= src → 正向拷贝 (安全)
; dst > src  → 反向拷贝 (防止覆盖未读源数据)
; ============================================================
define void @np_memmove(ptr %dst, ptr %src, i64 %n) {
entry:
  %cmp0 = icmp eq i64 %n, 0
  br i1 %cmp0, label %done, label %check_overlap
check_overlap:
  %need_backward = icmp ugt ptr %dst, %src
  br i1 %need_backward, label %bwd_entry, label %fwd_entry
fwd_entry:
  %fwd_qword = icmp uge i64 %n, 8
  br i1 %fwd_qword, label %fwd_qloop, label %fwd_bloop
fwd_qloop:
  %fqi = phi i64 [ 0, %fwd_entry ], [ %fqi_next, %fwd_qloop ]
  %fqsp = getelementptr i64, ptr %src, i64 %fqi
  %fqv = load i64, ptr %fqsp
  %fqdp = getelementptr i64, ptr %dst, i64 %fqi
  store i64 %fqv, ptr %fqdp
  %fqi_next = add i64 %fqi, 1
  %fqcount = lshr i64 %n, 3
  %fqcond = icmp ult i64 %fqi_next, %fqcount
  br i1 %fqcond, label %fwd_qloop, label %fwd_tail_setup
fwd_tail_setup:
  %fqbytes = shl i64 %fqcount, 3
  %fremaining = sub i64 %n, %fqbytes
  %fhas_tail = icmp ne i64 %fremaining, 0
  br i1 %fhas_tail, label %fwd_tail, label %done
fwd_tail:
  %fti = phi i64 [ 0, %fwd_tail_setup ], [ %fti_next, %fwd_tail ]
  %ftidx = add i64 %fqbytes, %fti
  %ftsp = getelementptr i8, ptr %src, i64 %ftidx
  %ftb = load i8, ptr %ftsp
  %ftdp = getelementptr i8, ptr %dst, i64 %ftidx
  store i8 %ftb, ptr %ftdp
  %fti_next = add i64 %fti, 1
  %ftcond = icmp ult i64 %fti_next, %fremaining
  br i1 %ftcond, label %fwd_tail, label %done
fwd_bloop:
  %fbi = phi i64 [ 0, %fwd_entry ], [ %fbi_next, %fwd_bloop ]
  %fbsp = getelementptr i8, ptr %src, i64 %fbi
  %fbb = load i8, ptr %fbsp
  %fbdp = getelementptr i8, ptr %dst, i64 %fbi
  store i8 %fbb, ptr %fbdp
  %fbi_next = add i64 %fbi, 1
  %fbcond = icmp eq i64 %fbi_next, %n
  br i1 %fbcond, label %done, label %fwd_bloop
bwd_entry:
  ; 反向拷贝：从尾部向头部
  %start = sub i64 %n, 1
  br label %bwd_loop
bwd_loop:
  %bi2 = phi i64 [ %start, %bwd_entry ], [ %bi2_next, %bwd_loop ]
  %bsp2 = getelementptr i8, ptr %src, i64 %bi2
  %bb2 = load i8, ptr %bsp2
  %bdp2 = getelementptr i8, ptr %dst, i64 %bi2
  store i8 %bb2, ptr %bdp2
  %bi2_next = sub i64 %bi2, 1
  %bcond2 = icmp eq i64 %bi2, 0
  br i1 %bcond2, label %done, label %bwd_loop
done:
  ret void
}

; ============================================================
; np_memset — 填充 dst 区域为 val
; ============================================================
define void @np_memset(ptr %dst, i8 %val, i64 %n) {
entry:
  %cmp0 = icmp eq i64 %n, 0
  br i1 %cmp0, label %done, label %qword_check
qword_check:
  %has_qword = icmp uge i64 %n, 8
  br i1 %has_qword, label %qword_fill, label %byte_loop
qword_fill:
  ; 将 i8 val 扩展为 i64 pattern: val | (val<<8) | ... | (val<<56)
  %v16 = zext i8 %val to i16
  %v16s = shl i16 %v16, 8
  %v16o = or i16 %v16, %v16s
  %v32 = zext i16 %v16o to i32
  %v32s = shl i32 %v32, 16
  %v32o = or i32 %v32, %v32s
  %v64 = zext i32 %v32o to i64
  %v64s = shl i64 %v64, 32
  %vpattern = or i64 %v64, %v64s
  br label %qword_loop
qword_loop:
  %qi = phi i64 [ 0, %qword_fill ], [ %qi_next, %qword_loop ]
  %qdp = getelementptr i64, ptr %dst, i64 %qi
  store i64 %vpattern, ptr %qdp
  %qi_next = add i64 %qi, 1
  %qcount = lshr i64 %n, 3
  %qcond = icmp ult i64 %qi_next, %qcount
  br i1 %qcond, label %qword_loop, label %tail_setup
tail_setup:
  %qbytes = shl i64 %qcount, 3
  %remaining = sub i64 %n, %qbytes
  %has_tail = icmp ne i64 %remaining, 0
  br i1 %has_tail, label %tail_loop, label %done
tail_loop:
  %ti = phi i64 [ 0, %tail_setup ], [ %ti_next, %tail_loop ]
  %tidx = add i64 %qbytes, %ti
  %tdp = getelementptr i8, ptr %dst, i64 %tidx
  store i8 %val, ptr %tdp
  %ti_next = add i64 %ti, 1
  %tcond = icmp ult i64 %ti_next, %remaining
  br i1 %tcond, label %tail_loop, label %done
byte_loop:
  %bi = phi i64 [ 0, %qword_check ], [ %bi_next, %byte_loop ]
  %bdp = getelementptr i8, ptr %dst, i64 %bi
  store i8 %val, ptr %bdp
  %bi_next = add i64 %bi, 1
  %bcond = icmp eq i64 %bi_next, %n
  br i1 %bcond, label %done, label %byte_loop
done:
  ret void
}

; ============================================================
; np_memzero — 零填充 dst 区域
; ============================================================
define void @np_memzero(ptr %dst, i64 %n) {
entry:
  %cmp0 = icmp eq i64 %n, 0
  br i1 %cmp0, label %done, label %qword_check
qword_check:
  %has_qword = icmp uge i64 %n, 8
  br i1 %has_qword, label %qword_zero, label %byte_loop
qword_zero:
  br label %qword_loop
qword_loop:
  %qi = phi i64 [ 0, %qword_zero ], [ %qi_next, %qword_loop ]
  %qdp = getelementptr i64, ptr %dst, i64 %qi
  store i64 0, ptr %qdp
  %qi_next = add i64 %qi, 1
  %qcount = lshr i64 %n, 3
  %qcond = icmp ult i64 %qi_next, %qcount
  br i1 %qcond, label %qword_loop, label %tail_setup
tail_setup:
  %qbytes = shl i64 %qcount, 3
  %remaining = sub i64 %n, %qbytes
  %has_tail = icmp ne i64 %remaining, 0
  br i1 %has_tail, label %tail_loop, label %done
tail_loop:
  %ti = phi i64 [ 0, %tail_setup ], [ %ti_next, %tail_loop ]
  %tidx = add i64 %qbytes, %ti
  %tdp = getelementptr i8, ptr %dst, i64 %tidx
  store i8 0, ptr %tdp
  %ti_next = add i64 %ti, 1
  %tcond = icmp ult i64 %ti_next, %remaining
  br i1 %tcond, label %tail_loop, label %done
byte_loop:
  %bi = phi i64 [ 0, %qword_check ], [ %bi_next, %byte_loop ]
  %bdp = getelementptr i8, ptr %dst, i64 %bi
  store i8 0, ptr %bdp
  %bi_next = add i64 %bi, 1
  %bcond = icmp eq i64 %bi_next, %n
  br i1 %bcond, label %done, label %byte_loop
done:
  ret void
}
