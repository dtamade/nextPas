; nextpas.runtime.memops.ll — 基础内存操作 (np_memcpy, np_memzero)
;
; 从 np_hir_llvm_emitter.pas EmitMemcpyHelper/EmitMemzeroHelper 提取
; 去掉 internal linkage，改为外部可见
;
; Gate 4 Phase 2: runtime 模块

target datalayout = "e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v64:64:64-v128:128:128-a0:0:64-s0:64:64-f80:128:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

; void @np_memcpy(ptr %dst, ptr %src, i64 %n)
define void @np_memcpy(ptr %dst, ptr %src, i64 %n) {
entry:
  %cmp0 = icmp eq i64 %n, 0
  br i1 %cmp0, label %done, label %loop
loop:
  %i = phi i64 [ 0, %entry ], [ %i_next, %loop ]
  %sp = getelementptr i8, ptr %src, i64 %i
  %b = load i8, ptr %sp
  %dp = getelementptr i8, ptr %dst, i64 %i
  store i8 %b, ptr %dp
  %i_next = add i64 %i, 1
  %cond = icmp eq i64 %i_next, %n
  br i1 %cond, label %done, label %loop
done:
  ret void
}

; void @np_memmove(ptr %dst, ptr %src, i64 %n)
; 重叠安全拷贝：Pascal Move(src, dst, n) 必须支持 src/dst 重叠
; dst <= src → 正向拷贝 (安全)
; dst > src → 反向拷贝 (防止覆盖未读源数据)
define void @np_memmove(ptr %dst, ptr %src, i64 %n) {
entry:
  %cmp0 = icmp eq i64 %n, 0
  br i1 %cmp0, label %done, label %check
check:
  %need_backward = icmp ugt ptr %dst, %src
  br i1 %need_backward, label %bwd_init, label %fwd_init
fwd_init:
  br label %fwd_loop
fwd_loop:
  %fi = phi i64 [ 0, %fwd_init ], [ %fi_next, %fwd_loop ]
  %fsp = getelementptr i8, ptr %src, i64 %fi
  %fb = load i8, ptr %fsp
  %fdp = getelementptr i8, ptr %dst, i64 %fi
  store i8 %fb, ptr %fdp
  %fi_next = add i64 %fi, 1
  %fcond = icmp eq i64 %fi_next, %n
  br i1 %fcond, label %done, label %fwd_loop
bwd_init:
  %start = sub i64 %n, 1
  br label %bwd_loop
bwd_loop:
  %bi = phi i64 [ %start, %bwd_init ], [ %bi_next, %bwd_loop ]
  %bsp = getelementptr i8, ptr %src, i64 %bi
  %bb = load i8, ptr %bsp
  %bdp = getelementptr i8, ptr %dst, i64 %bi
  store i8 %bb, ptr %bdp
  %bi_next = sub i64 %bi, 1
  %bcond = icmp eq i64 %bi, 0
  br i1 %bcond, label %done, label %bwd_loop
done:
  ret void
}

; void @np_memset(ptr %dst, i8 %val, i64 %n)
; FillChar(var Dest, Count, Value) maps to: call void @np_memset(ptr %dst, i8 %val, i64 %count)
define void @np_memset(ptr %dst, i8 %val, i64 %n) {
entry:
  %cmp0 = icmp eq i64 %n, 0
  br i1 %cmp0, label %done, label %loop
loop:
  %i = phi i64 [ 0, %entry ], [ %i_next, %loop ]
  %dp = getelementptr i8, ptr %dst, i64 %i
  store i8 %val, ptr %dp
  %i_next = add i64 %i, 1
  %cond = icmp eq i64 %i_next, %n
  br i1 %cond, label %done, label %loop
done:
  ret void
}

; void @np_memzero(ptr %dst, i64 %n)
define void @np_memzero(ptr %dst, i64 %n) {
entry:
  %cmp0 = icmp eq i64 %n, 0
  br i1 %cmp0, label %done, label %loop
loop:
  %i = phi i64 [ 0, %entry ], [ %i_next, %loop ]
  %dp = getelementptr i8, ptr %dst, i64 %i
  store i8 0, ptr %dp
  %i_next = add i64 %i, 1
  %cond = icmp eq i64 %i_next, %n
  br i1 %cond, label %done, label %loop
done:
  ret void
}
