; nextpas.runtime.dynarray.ll — 动态数组 helper 函数
;
; 从 np_hir_llvm_emitter.pas EmitDynArrayHelpers 提取
;
; Gate 4 Phase 4: dynarray runtime 模块

target datalayout = "e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v64:64:64-v128:128:128-a0:0:64-s0:64:64-f80:128:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

declare void @llvm.trap()
declare ptr @np_alloc(i64 %size)
declare void @np_free(ptr %raw, i64 %size)
declare void @np_memcpy(ptr %dst, ptr %src, i64 %n)

; ============================================================
; np_dynarray_fault — 动态数组操作错误 (trap)
; ============================================================
define void @np_dynarray_fault(i64 %code, i64 %arg0, i64 %arg1) {
entry:
  call void @llvm.trap()
  unreachable
}

; ============================================================
; np_dynarray_release — 释放动态数组内存
; ============================================================
define void @np_dynarray_release(ptr %ptr, i64 %len, i64 %elem_size) {
entry:
  %release.isnull = icmp eq ptr %ptr, null
  br i1 %release.isnull, label %release.done, label %release.elem.check
release.elem.check:
  %release.elem.zero = icmp eq i64 %elem_size, 0
  br i1 %release.elem.zero, label %release.fault.elem, label %release.size
release.fault.elem:
  call void @np_dynarray_fault(i64 1, i64 %len, i64 %elem_size)
  unreachable
release.size:
  %release.size.bytes = mul i64 %len, %elem_size
  %release.size.div = udiv i64 %release.size.bytes, %elem_size
  %release.size.ok = icmp eq i64 %release.size.div, %len
  br i1 %release.size.ok, label %release.zero.check, label %release.fault.size
release.fault.size:
  call void @np_dynarray_fault(i64 2, i64 %len, i64 %elem_size)
  unreachable
release.zero.check:
  %release.size.zero = icmp eq i64 %release.size.bytes, 0
  br i1 %release.size.zero, label %release.done, label %release.call
release.call:
  call void @np_free(ptr %ptr, i64 %release.size.bytes)
  br label %release.done
release.done:
  ret void
}

; ============================================================
; np_dynarray_resize — 调整数组大小，保留旧数据
; ============================================================
define ptr @np_dynarray_resize(ptr %old_ptr, i64 %old_len, i64 %new_len, i64 %elem_size) {
entry:
  %resize.new.zero = icmp eq i64 %new_len, 0
  br i1 %resize.new.zero, label %resize.release.zero, label %resize.same.check
resize.release.zero:
  call void @np_dynarray_release(ptr %old_ptr, i64 %old_len, i64 %elem_size)
  ret ptr null
resize.same.check:
  %resize.same.len = icmp eq i64 %old_len, %new_len
  br i1 %resize.same.len, label %resize.same, label %resize.elem.check
resize.same:
  ret ptr %old_ptr
resize.elem.check:
  %resize.elem.zero = icmp eq i64 %elem_size, 0
  br i1 %resize.elem.zero, label %resize.fault.elem, label %resize.alloc.size
resize.fault.elem:
  call void @np_dynarray_fault(i64 3, i64 %new_len, i64 %elem_size)
  unreachable
resize.alloc.size:
  %resize.alloc.bytes = mul i64 %new_len, %elem_size
  %resize.alloc.div = udiv i64 %resize.alloc.bytes, %elem_size
  %resize.alloc.ok = icmp eq i64 %resize.alloc.div, %new_len
  br i1 %resize.alloc.ok, label %resize.alloc, label %resize.fault.alloc
resize.fault.alloc:
  call void @np_dynarray_fault(i64 4, i64 %new_len, i64 %elem_size)
  unreachable
resize.alloc:
  %resize.new.ptr = call ptr @np_alloc(i64 %resize.alloc.bytes)
  %resize.old.isnull = icmp eq ptr %old_ptr, null
  br i1 %resize.old.isnull, label %resize.done, label %resize.old.size
resize.old.size:
  %resize.old.bytes = mul i64 %old_len, %elem_size
  %resize.old.div = udiv i64 %resize.old.bytes, %elem_size
  %resize.old.ok = icmp eq i64 %resize.old.div, %old_len
  br i1 %resize.old.ok, label %resize.copy.select, label %resize.fault.old
resize.fault.old:
  call void @np_dynarray_fault(i64 5, i64 %old_len, i64 %elem_size)
  unreachable
resize.copy.select:
  %resize.copy.use.old = icmp ule i64 %old_len, %new_len
  %resize.copy.len = select i1 %resize.copy.use.old, i64 %old_len, i64 %new_len
  %resize.copy.bytes = mul i64 %resize.copy.len, %elem_size
  %resize.copy.div = udiv i64 %resize.copy.bytes, %elem_size
  %resize.copy.ok = icmp eq i64 %resize.copy.div, %resize.copy.len
  br i1 %resize.copy.ok, label %resize.copy.check, label %resize.fault.copy
resize.fault.copy:
  call void @np_dynarray_fault(i64 6, i64 %resize.copy.len, i64 %elem_size)
  unreachable
resize.copy.check:
  %resize.copy.zero = icmp eq i64 %resize.copy.bytes, 0
  br i1 %resize.copy.zero, label %resize.release.old, label %resize.copy
resize.copy:
  call void @np_memcpy(ptr %resize.new.ptr, ptr %old_ptr, i64 %resize.copy.bytes)
  br label %resize.release.old
resize.release.old:
  call void @np_dynarray_release(ptr %old_ptr, i64 %old_len, i64 %elem_size)
  br label %resize.done
resize.done:
  ret ptr %resize.new.ptr
}
