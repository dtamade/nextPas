; nextpas.runtime.objects.ll — 对象生命周期 + 接口引用计数
;
; 从 np_hir_llvm_emitter.pas 提取:
;   EmitObjectAllocHelper, EmitObjectFreeReleaseHelper,
;   EmitObjectReleaseValidHelper, EmitObjectReleaseInvalidHelper,
;   EmitIntfRefCountHelpers
;
; Gate 4 Phase 2: runtime 模块
;
; 对象头布局 (24 bytes):
;   [+0]  payload_size: i64
;   [+8]  magic: i64 (1313882451)
;   [+16] refcount: i64
;   [+24] payload start (returned to caller)

target datalayout = "e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v64:64:64-v128:128:128-a0:0:64-s0:64:64-f80:128:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

declare ptr @np_alloc(i64 %size)
declare void @np_free(ptr %raw, i64 %size)
declare void @np_memzero(ptr %dst, i64 %n)
declare void @np_allocator_fault(i64 %code, i64 %arg0, i64 %arg1)

declare void @llvm.trap()

; ptr @np_object_alloc(i64 %size) — 分配对象，返回 payload 指针
define ptr @np_object_alloc(i64 %size) {
entry:
  %total = add i64 %size, 24
  %total.overflow = icmp ult i64 %total, %size
  br i1 %total.overflow, label %object.alloc.fault.total, label %object.alloc.header
object.alloc.fault.total:
  call void @np_allocator_fault(i64 1, i64 %size, i64 24)
  unreachable
object.alloc.header:
  %raw = call ptr @np_alloc(i64 %total)
  store i64 %size, ptr %raw
  %magicp = getelementptr i8, ptr %raw, i64 8
  store i64 1313882451, ptr %magicp
  %rcp = getelementptr i8, ptr %raw, i64 16
  store i64 1, ptr %rcp
  %obj = getelementptr i8, ptr %raw, i64 24
  call void @np_memzero(ptr %obj, i64 %size)
  ret ptr %obj
}

; void @np_object_free_release(ptr %obj) — 释放对象
define void @np_object_free_release(ptr %obj) {
entry:
  %isnull = icmp eq ptr %obj, null
  br i1 %isnull, label %done, label %header
header:
  %raw = getelementptr i8, ptr %obj, i64 -24
  %size = load i64, ptr %raw
  %magicp = getelementptr i8, ptr %raw, i64 8
  %magic = load i64, ptr %magicp
  %magic.ok = icmp eq i64 %magic, 1313882451
  br i1 %magic.ok, label %release, label %invalid
invalid:
  call void @np_object_release_invalid(ptr %raw, i64 %size, i64 %magic)
  br label %done
release:
  call void @np_object_release_valid(ptr %raw, i64 %size)
  br label %done
done:
  ret void
}

; void @np_object_release_valid(ptr %raw, i64 %size) — 清除 magic 并释放
define void @np_object_release_valid(ptr %raw, i64 %size) {
entry:
  %released.magicp = getelementptr i8, ptr %raw, i64 8
  store i64 0, ptr %released.magicp
  %alloc.size = add i64 %size, 24
  call void @np_free(ptr %raw, i64 %alloc.size)
  ret void
}

; void @np_object_release_invalid(ptr %raw, i64 %size, i64 %magic) — trap
define void @np_object_release_invalid(ptr %raw, i64 %size, i64 %magic) {
entry:
  call void @llvm.trap()
  unreachable
}

; void @np_intf_addref(ptr %obj) — 接口引用计数 +1
define void @np_intf_addref(ptr %obj) {
entry:
  %isnull = icmp eq ptr %obj, null
  br i1 %isnull, label %done, label %inc
inc:
  %rcp = getelementptr i8, ptr %obj, i64 -8
  %old = load i64, ptr %rcp
  %new = add i64 %old, 1
  store i64 %new, ptr %rcp
  br label %done
done:
  ret void
}

; void @np_intf_release(ptr %obj) — 接口引用计数 -1，降为 0 时释放对象
define void @np_intf_release(ptr %obj) {
entry:
  %isnull = icmp eq ptr %obj, null
  br i1 %isnull, label %done, label %dec
dec:
  %rcp = getelementptr i8, ptr %obj, i64 -8
  %old = load i64, ptr %rcp
  %new = sub i64 %old, 1
  store i64 %new, ptr %rcp
  %is_zero = icmp eq i64 %new, 0
  br i1 %is_zero, label %free_obj, label %done
free_obj:
  ; raw = obj - 24 (回到对象头)
  %raw = getelementptr i8, ptr %obj, i64 -24
  ; payload_size 在 [+0]
  %payload_size = load i64, ptr %raw
  ; alloc_size = payload_size + 24 (对象头大小)
  %alloc_size = add i64 %payload_size, 24
  call void @np_free(ptr %raw, i64 %alloc_size)
  br label %done
done:
  ret void
}
