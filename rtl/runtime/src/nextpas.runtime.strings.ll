; nextpas.runtime.strings.ll — 字符串/IO helper 函数
;
; 从 np_hir_llvm_emitter.pas 提取：
;   EmitStrConcatHelper      → np_str_concat
;   EmitStringOwnershipHelpers → np_string_fault, np_string_release,
;                                np_str_concat_owned, np_str_copy_owned,
;                                np_int_to_str, np_int_to_str_owned
;   EmitWriteIntHelper       → write_i64_decimal
;   EmitModule (inline)      → np_str_cmp, np_str_pos
;
; Gate 4 Phase 4: string/IO runtime 模块

target datalayout = "e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v64:64:64-v128:128:128-a0:0:64-s0:64:64-f80:128:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

declare void @llvm.trap()
declare ptr @np_alloc(i64 %size)
declare void @np_free(ptr %raw, i64 %size)
declare void @np_memcpy(ptr %dst, ptr %src, i64 %n)

; ============================================================
; write_i64_decimal — i64 转十进制直接写 stdout
; ============================================================
define void @write_i64_decimal(i64 %v) {
entry:
  %buf = alloca [24 x i8]
  %is_neg = icmp slt i64 %v, 0
  %neg_v = sub i64 0, %v
  %abs_v = select i1 %is_neg, i64 %neg_v, i64 %v
  %end_ptr = getelementptr [24 x i8], ptr %buf, i64 0, i64 24
  %first_ptr = getelementptr [24 x i8], ptr %buf, i64 0, i64 23
  br label %loop
loop:
  %cur = phi i64 [ %abs_v, %entry ], [ %nxt, %loop ]
  %ptr = phi ptr [ %first_ptr, %entry ], [ %ptr_prev, %loop ]
  %digit = urem i64 %cur, 10
  %digit_i8 = trunc i64 %digit to i8
  %digit_ascii = add i8 %digit_i8, 48
  store i8 %digit_ascii, ptr %ptr
  %nxt = udiv i64 %cur, 10
  %ptr_prev = getelementptr i8, ptr %ptr, i64 -1
  %done = icmp eq i64 %nxt, 0
  br i1 %done, label %neg_check, label %loop
neg_check:
  br i1 %is_neg, label %put_minus, label %finish
put_minus:
  store i8 45, ptr %ptr_prev
  %ptr_minus_prev = getelementptr i8, ptr %ptr_prev, i64 -1
  br label %finish
finish:
  %start_ptr = phi ptr [ %ptr_prev, %neg_check ], [ %ptr_minus_prev, %put_minus ]
  %start_next = getelementptr i8, ptr %start_ptr, i64 1
  %len = ptrtoint ptr %end_ptr to i64
  %start_int = ptrtoint ptr %start_next to i64
  %write_len = sub i64 %len, %start_int
  call void asm sideeffect "movq $$1, %rax; syscall", "{rdi},{rsi},{rdx},~{rax},~{rcx},~{r11},~{memory}"(i64 1, ptr %start_next, i64 %write_len)
  ret void
}

; ============================================================
; np_str_cmp — 字节级比较，相等返回1，否则0
; ============================================================
define i64 @np_str_cmp(ptr %a_ptr, i64 %a_len, ptr %b_ptr, i64 %b_len) {
entry:
  %len_eq = icmp eq i64 %a_len, %b_len
  br i1 %len_eq, label %check_content, label %not_equal
check_content:
  %cmp0 = icmp eq i64 %a_len, 0
  br i1 %cmp0, label %equal, label %loop
loop:
  %i = phi i64 [ 0, %check_content ], [ %i_next, %loop_cont ]
  %ap = getelementptr i8, ptr %a_ptr, i64 %i
  %bp = getelementptr i8, ptr %b_ptr, i64 %i
  %ac = load i8, ptr %ap
  %bc = load i8, ptr %bp
  %eq = icmp eq i8 %ac, %bc
  br i1 %eq, label %loop_cont, label %not_equal
loop_cont:
  %i_next = add i64 %i, 1
  %done = icmp eq i64 %i_next, %a_len
  br i1 %done, label %equal, label %loop
equal:
  ret i64 1
not_equal:
  ret i64 0
}

; ============================================================
; np_str_pos — substring 搜索，1-based 或 0
; ============================================================
define i64 @np_str_pos(ptr %sub_ptr, i64 %sub_len, ptr %s_ptr, i64 %s_len) {
entry:
  %max = sub i64 %s_len, %sub_len
  %can = icmp sge i64 %max, 0
  br i1 %can, label %outer_loop, label %not_found
outer_loop:
  %oi = phi i64 [ 0, %entry ], [ %oi_next, %outer_cont ]
  br label %inner_loop
inner_loop:
  %ii = phi i64 [ 0, %outer_loop ], [ %ii_next, %inner_cont ]
  %sp = getelementptr i8, ptr %s_ptr, i64 %oi
  %spi = getelementptr i8, ptr %sp, i64 %ii
  %subp = getelementptr i8, ptr %sub_ptr, i64 %ii
  %sc = load i8, ptr %spi
  %subc = load i8, ptr %subp
  %match = icmp eq i8 %sc, %subc
  br i1 %match, label %inner_cont, label %outer_cont
inner_cont:
  %ii_next = add i64 %ii, 1
  %idone = icmp eq i64 %ii_next, %sub_len
  br i1 %idone, label %found, label %inner_loop
outer_cont:
  %oi_next = add i64 %oi, 1
  %odone = icmp sgt i64 %oi_next, %max
  br i1 %odone, label %not_found, label %outer_loop
found:
  %result = add i64 %oi, 1
  ret i64 %result
not_found:
  ret i64 0
}

; ============================================================
; np_str_concat — 两段拼接，{ptr, len}
; ============================================================
define {ptr, i64} @np_str_concat(ptr %a_ptr, i64 %a_len, ptr %b_ptr, i64 %b_len) {
entry:
  %total = add i64 %a_len, %b_len
  %buf = call ptr @np_alloc(i64 %total)
  call void @np_memcpy(ptr %buf, ptr %a_ptr, i64 %a_len)
  %dst2 = getelementptr i8, ptr %buf, i64 %a_len
  call void @np_memcpy(ptr %dst2, ptr %b_ptr, i64 %b_len)
  %r1 = insertvalue {ptr, i64} undef, ptr %buf, 0
  %r2 = insertvalue {ptr, i64} %r1, i64 %total, 1
  ret {ptr, i64} %r2
}

; ============================================================
; np_string_fault — 字符串操作错误 (trap)
; ============================================================
define void @np_string_fault(i64 %code, i64 %arg0, i64 %arg1) {
entry:
  call void @llvm.trap()
  unreachable
}

; ============================================================
; np_string_release — 释放 owned 字符串
; ============================================================
define void @np_string_release(ptr %owner, i64 %alloc_size) {
entry:
  %isnull = icmp eq ptr %owner, null
  br i1 %isnull, label %done, label %size.check
size.check:
  %size.zero = icmp eq i64 %alloc_size, 0
  br i1 %size.zero, label %size.fault, label %release
size.fault:
  call void @np_string_fault(i64 1, i64 %alloc_size, i64 0)
  unreachable
release:
  call void @np_free(ptr %owner, i64 %alloc_size)
  br label %done
done:
  ret void
}

; ============================================================
; np_str_concat_owned — 拼接两段 owned 字符串，返回新 owned
; ============================================================
define {ptr, i64, ptr, i64} @np_str_concat_owned(ptr %a_ptr, i64 %a_len, ptr %b_ptr, i64 %b_len) {
entry:
  %total = add i64 %a_len, %b_len
  %total.overflow = icmp ult i64 %total, %a_len
  br i1 %total.overflow, label %fault.total, label %zero.check
fault.total:
  call void @np_string_fault(i64 2, i64 %a_len, i64 %b_len)
  unreachable
zero.check:
  %is.zero = icmp eq i64 %total, 0
  br i1 %is.zero, label %zero, label %alloc
zero:
  %z1 = insertvalue {ptr, i64, ptr, i64} undef, ptr null, 0
  %z2 = insertvalue {ptr, i64, ptr, i64} %z1, i64 0, 1
  %z3 = insertvalue {ptr, i64, ptr, i64} %z2, ptr null, 2
  %z4 = insertvalue {ptr, i64, ptr, i64} %z3, i64 0, 3
  ret {ptr, i64, ptr, i64} %z4
alloc:
  %buf = call ptr @np_alloc(i64 %total)
  call void @np_memcpy(ptr %buf, ptr %a_ptr, i64 %a_len)
  %dst2 = getelementptr i8, ptr %buf, i64 %a_len
  call void @np_memcpy(ptr %dst2, ptr %b_ptr, i64 %b_len)
  %r1 = insertvalue {ptr, i64, ptr, i64} undef, ptr %buf, 0
  %r2 = insertvalue {ptr, i64, ptr, i64} %r1, i64 %total, 1
  %r3 = insertvalue {ptr, i64, ptr, i64} %r2, ptr %buf, 2
  %r4 = insertvalue {ptr, i64, ptr, i64} %r3, i64 %total, 3
  ret {ptr, i64, ptr, i64} %r4
}

; ============================================================
; np_str_copy_owned — 取子串 (1-based start, count)
; ============================================================
define {ptr, i64, ptr, i64} @np_str_copy_owned(ptr %src_ptr, i64 %src_len, i64 %start, i64 %count) {
entry:
  %start.invalid = icmp sle i64 %start, 0
  %count.invalid = icmp sle i64 %count, 0
  %start.after = icmp sgt i64 %start, %src_len
  %empty.a = or i1 %start.invalid, %count.invalid
  %empty = or i1 %empty.a, %start.after
  br i1 %empty, label %zero, label %bounds
bounds:
  %offset = sub i64 %start, 1
  %available = sub i64 %src_len, %offset
  %too.long = icmp sgt i64 %count, %available
  %copy.len = select i1 %too.long, i64 %available, i64 %count
  %copy.zero = icmp eq i64 %copy.len, 0
  br i1 %copy.zero, label %zero, label %alloc
alloc:
  %src.slice = getelementptr i8, ptr %src_ptr, i64 %offset
  %buf = call ptr @np_alloc(i64 %copy.len)
  call void @np_memcpy(ptr %buf, ptr %src.slice, i64 %copy.len)
  %r1 = insertvalue {ptr, i64, ptr, i64} undef, ptr %buf, 0
  %r2 = insertvalue {ptr, i64, ptr, i64} %r1, i64 %copy.len, 1
  %r3 = insertvalue {ptr, i64, ptr, i64} %r2, ptr %buf, 2
  %r4 = insertvalue {ptr, i64, ptr, i64} %r3, i64 %copy.len, 3
  ret {ptr, i64, ptr, i64} %r4
zero:
  %z1 = insertvalue {ptr, i64, ptr, i64} undef, ptr null, 0
  %z2 = insertvalue {ptr, i64, ptr, i64} %z1, i64 0, 1
  %z3 = insertvalue {ptr, i64, ptr, i64} %z2, ptr null, 2
  %z4 = insertvalue {ptr, i64, ptr, i64} %z3, i64 0, 3
  ret {ptr, i64, ptr, i64} %z4
}

; ============================================================
; np_int_to_str — i64 转 {ptr, len}
; ============================================================
define {ptr, i64} @np_int_to_str(i64 %val) {
entry:
  %buf = call ptr @np_alloc(i64 21)
  %is_neg = icmp slt i64 %val, 0
  %abs_val = select i1 %is_neg, i64 0, i64 %val
  %neg_val = sub i64 0, %val
  %work = select i1 %is_neg, i64 %neg_val, i64 %val
  br label %digit_loop
digit_loop:
  %n = phi i64 [ %work, %entry ], [ %n_next, %digit_loop ]
  %pos = phi i64 [ 20, %entry ], [ %pos_next, %digit_loop ]
  %d = urem i64 %n, 10
  %c = add i64 %d, 48
  %ct = trunc i64 %c to i8
  %pos_next = sub i64 %pos, 1
  %dp = getelementptr i8, ptr %buf, i64 %pos_next
  store i8 %ct, ptr %dp
  %n_next = udiv i64 %n, 10
  %done = icmp eq i64 %n_next, 0
  br i1 %done, label %finish, label %digit_loop
finish:
  %final_pos = phi i64 [ %pos_next, %digit_loop ]
  br i1 %is_neg, label %write_neg, label %ret
write_neg:
  %neg_pos = sub i64 %final_pos, 1
  %negp = getelementptr i8, ptr %buf, i64 %neg_pos
  store i8 45, ptr %negp
  br label %ret
ret:
  %result_pos = phi i64 [ %final_pos, %finish ], [ %neg_pos, %write_neg ]
  %result_ptr = getelementptr i8, ptr %buf, i64 %result_pos
  %result_len = sub i64 20, %result_pos
  %r1 = insertvalue {ptr, i64} undef, ptr %result_ptr, 0
  %r2 = insertvalue {ptr, i64} %r1, i64 %result_len, 1
  ret {ptr, i64} %r2
}

; ============================================================
; np_int_to_str_owned — i64 转 owned 字符串 {ptr, len, alloc_ptr, alloc_size}
; ============================================================
define {ptr, i64, ptr, i64} @np_int_to_str_owned(i64 %val) {
entry:
  %buf = call ptr @np_alloc(i64 21)
  %is_neg = icmp slt i64 %val, 0
  %neg_val = sub i64 0, %val
  %work = select i1 %is_neg, i64 %neg_val, i64 %val
  br label %digit_loop
digit_loop:
  %n = phi i64 [ %work, %entry ], [ %n_next, %digit_loop ]
  %pos = phi i64 [ 20, %entry ], [ %pos_next, %digit_loop ]
  %d = urem i64 %n, 10
  %c = add i64 %d, 48
  %ct = trunc i64 %c to i8
  %pos_next = sub i64 %pos, 1
  %dp = getelementptr i8, ptr %buf, i64 %pos_next
  store i8 %ct, ptr %dp
  %n_next = udiv i64 %n, 10
  %done = icmp eq i64 %n_next, 0
  br i1 %done, label %finish, label %digit_loop
finish:
  %final_pos = phi i64 [ %pos_next, %digit_loop ]
  br i1 %is_neg, label %write_neg, label %ret
write_neg:
  %neg_pos = sub i64 %final_pos, 1
  %negp = getelementptr i8, ptr %buf, i64 %neg_pos
  store i8 45, ptr %negp
  br label %ret
ret:
  %result_pos = phi i64 [ %final_pos, %finish ], [ %neg_pos, %write_neg ]
  %result_ptr = getelementptr i8, ptr %buf, i64 %result_pos
  %result_len = sub i64 20, %result_pos
  %r1 = insertvalue {ptr, i64, ptr, i64} undef, ptr %result_ptr, 0
  %r2 = insertvalue {ptr, i64, ptr, i64} %r1, i64 %result_len, 1
  %r3 = insertvalue {ptr, i64, ptr, i64} %r2, ptr %buf, 2
  %r4 = insertvalue {ptr, i64, ptr, i64} %r3, i64 21, 3
  ret {ptr, i64, ptr, i64} %r4
}
