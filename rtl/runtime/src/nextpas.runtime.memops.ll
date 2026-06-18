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
