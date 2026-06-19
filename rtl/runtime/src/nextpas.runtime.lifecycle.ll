; nextpas.runtime.lifecycle.ll — 进程生命周期运行时函数
;
; 实现 Gate 3: process_init / process_fini
;   编译器 LLVM IR 中 _start 调用:
;     declare void @np_process_init()
;     declare void @np_process_fini()
;
; Phase 0 (最小可用):
;   np_process_init:
;     - 设置全局进程初始化标志
;     - 初始化标准输出文件描述符 (stdout=1, stderr=2)
;   np_process_fini:
;     - 刷新标准输出/错误输出缓冲区 (fsync)
;     - 清除进程初始化标志
;
; 设计决策:
;   - 参考 FPC 的 fpc_initializeunits / SysFlushStdIO / FinalizeUnits 序列
;   - Phase 0 不做 unit init/fini 遍历 (Gate 2 的职责)
;   - Phase 0 不做堆释放 (Gate 4 的职责)
;   - Phase 0 不做 ExitProc 链 (Gate 5 的职责)
;   - fsync 使用 Linux syscall (syscall 74 = fsync)，不依赖 libc
;   - write 使用 Linux syscall (syscall 1 = write)，不依赖 libc
;   - 进程退出由编译器 _start 中的 halt intrinsic 处理，不在此处

target datalayout = "e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v64:64:64-v128:128:128-a0:0:64-s0:64:64-f80:128:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

; ============================================================
; 全局状态
; ============================================================

; 进程生命周期状态标志:
;   0 = 未初始化
;   1 = 已初始化 (process_init 已执行)
;   2 = 正在终结化 (process_fini 执行中)
;   3 = 已终结化 (process_fini 完成)
; 这个标志用于防止重入和追踪生命周期阶段
@__np_lifecycle_state = global i64 0

; Phase 0: 使用静态固定大小缓冲区做 IO 刷新
; 后续 Phase 可替换为运行时缓冲区管理
; 这里不需要额外缓冲区 — fsync 只需要刷新内核缓冲区

; ============================================================
; Linux x86_64 syscall 常量
; ============================================================
; sys_write = 1
; sys_fsync = 74

; ============================================================
; np_process_init — 进程初始化
;
; 对标 FPC 的:
;   fpc_cpuinit + fpc_InitializeUnits 序列
;
; Phase 0 职责:
;   1. 检查重入 (如果已初始化则直接返回)
;   2. 标记进程为已初始化
;
; 未来扩展点:
;   - 调用编译器生成的 unit init 表 (Gate 2)
;   - 初始化内存管理器 (Gate 4)
;   - 注册信号处理器
; ============================================================
define void @np_process_init() {
entry:
  %state = load i64, ptr @__np_lifecycle_state
  %already_init = icmp ne i64 %state, 0
  br i1 %already_init, label %done, label %init

init:
  ; 标记为已初始化
  store i64 1, ptr @__np_lifecycle_state
  ; Phase 0: 无额外初始化操作
  ; 后续在此插入:
  ;   - call void @np_unit_init_*()  (Gate 2)
  ;   - call void @np_mem_init()     (Gate 4)
  br label %done

done:
  ret void
}

; ============================================================
; np_process_fini — 进程终结化
;
; 对标 FPC 的退出序列:
;   1. SysFlushStdIO  — 刷新标准 IO 缓冲区
;   2. FinalizeUnits  — 逆序终结化各单元
;   3. FinalizeHeap   — 释放堆内存
;
; Phase 0 职责:
;   1. 检查是否已初始化 (未初始化则跳过)
;   2. 防止重入 (正在终结化则跳过)
;   3. fsync(stdout) + fsync(stderr)
;   4. 标记为已终结化
;
; 未来扩展点:
;   - 调用编译器生成的 unit fini 表 (Gate 2)
;   - 执行 ExitProc 链 (Gate 5)
;   - 堆释放 FinalizeHeap (Gate 4)
;
; 设计决策:
;   - 使用 fsync 而非 write(flush)，因为内核缓冲区不需要用户态 write
;   - fsync 失败不阻塞 (Phase 0 最小安全)
;   - 先 fsync 再标记状态，确保数据在状态转换前写出
; ============================================================
define void @np_process_fini() {
entry:
  %state = load i64, ptr @__np_lifecycle_state
  ; 未初始化则直接返回 (无 IO 需要刷新)
  %not_init = icmp eq i64 %state, 0
  br i1 %not_init, label %done, label %check_reentry

check_reentry:
  ; 正在终结化或已终结化则跳过 (防止重入)
  %finishing = icmp uge i64 %state, 2
  br i1 %finishing, label %done, label %flush_io

flush_io:
  ; 标记为正在终结化 (防止重入)
  store i64 2, ptr @__np_lifecycle_state

  ; fsync(stdout) — fd=1, syscall=74
  ; inline asm: movq $74, %rax; movq $1, %rdi; syscall
  ; 返回值在 %rax, 我们忽略失败 (Phase 0 最小安全)
  call void asm sideeffect "movq $$74, %rax; movq $$1, %rdi; syscall", "~{rax},~{rdi},~{rcx},~{r11},~{memory}"()

  ; fsync(stderr) — fd=2, syscall=74
  call void asm sideeffect "movq $$74, %rax; movq $$2, %rdi; syscall", "~{rax},~{rdi},~{rcx},~{r11},~{memory}"()

  ; Phase 0: 无额外终结化操作
  ; 后续在此插入:
  ;   - call void @np_unit_fini_*()  (Gate 2, 逆序)
  ;   - call void @np_exitproc_run() (Gate 5)
  ;   - call void @np_heap_release() (Gate 4)

  ; 标记为已终结化
  store i64 3, ptr @__np_lifecycle_state
  br label %done

done:
  ret void
}
