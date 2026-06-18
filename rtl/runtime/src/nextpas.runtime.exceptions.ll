; nextpas.runtime.exceptions.ll — 异常运行时 (freestanding setjmp/longjmp)
;
; 从 np_hir_llvm_emitter.pas EmitExceptionRuntimeHelpers 提取
; globals + try_push/try_pop/raise/finally_end/except_end
; setjmp/longjmp 由 emitter module-level asm 内联（不可外部化）
;
; Gate 4 Phase 4: exception runtime 模块

target datalayout = "e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v64:64:64-v128:128:128-a0:0:64-s0:64:64-f80:128:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

; ============================================================
; 异常栈全局变量
; ============================================================
@__np_exc_stack = global ptr null
@__np_exc_pending = global i1 false
@__np_exc_object = global ptr null

; ============================================================
; np_try_push — 将 setjmp buffer 入栈
; ============================================================
define void @np_try_push(ptr %buf) {
entry:
  %old = load ptr, ptr @__np_exc_stack
  %slot = getelementptr [9 x ptr], ptr %buf, i64 0, i64 8
  store ptr %old, ptr %slot
  store ptr %buf, ptr @__np_exc_stack
  ret void
}

; ============================================================
; np_try_pop — 弹出栈顶 setjmp buffer
; ============================================================
define void @np_try_pop() {
entry:
  %buf = load ptr, ptr @__np_exc_stack
  %slot = getelementptr [9 x ptr], ptr %buf, i64 0, i64 8
  %prev = load ptr, ptr %slot
  store ptr %prev, ptr @__np_exc_stack
  ret void
}

; ============================================================
; np_raise — 抛出异常，longjmp 到栈顶 setjmp buffer
; ============================================================
define void @np_raise() {
entry:
  store i1 true, ptr @__np_exc_pending
  %buf = load ptr, ptr @__np_exc_stack
  %is_null = icmp eq ptr %buf, null
  br i1 %is_null, label %abort, label %do_longjmp
abort:
  ; exit(217) via direct syscall
  call void asm sideeffect "movq $$60, %rax; movq $$217, %rdi; syscall", "~{rax},~{rdi},~{rcx},~{r11}"()
  unreachable
do_longjmp:
  call void @longjmp(ptr %buf, i32 1)
  unreachable
}

; ============================================================
; np_finally_end — finally 块结束时重抛 pending 异常
; ============================================================
define void @np_finally_end() {
entry:
  %pending = load i1, ptr @__np_exc_pending
  br i1 %pending, label %reraise, label %done
reraise:
  call void @np_try_pop()
  call void @np_raise()
  unreachable
done:
  ret void
}

; ============================================================
; np_except_end — except 块结束，清除 pending 标志
; ============================================================
define void @np_except_end() {
entry:
  store i1 false, ptr @__np_exc_pending
  ret void
}

declare void @longjmp(ptr, i32) noreturn nounwind
