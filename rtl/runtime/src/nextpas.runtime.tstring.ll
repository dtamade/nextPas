; nextpas.runtime.tstring.ll — TString 24B SSO+CoW runtime
;
; 所有函数通过 ptr 操作 24-byte TString variant record:
;   [0]  SSOTag: i8       (0 = SSO, $FF = Heap)
;   [1]  SSOLen: i8       (SSO: 长度 [0..15])
;   [2..16] SSOBuf: [15 x i8]  (SSO: 内联数据)
;   [17..23] SSOPad: [7 x i8]  (对齐到 24B)
;
;   [0]  HeapTag: i8      ($FF = Heap, 同 SSOTag 偏移)
;   [1..7] HeapPad: [7 x i8]
;   [8..15] HeapHeader: ptr  (→ TStringHeader: RefCount(4B) + Capacity(4B))
;   [16..23] HeapLen: i64
;
; 与 core/src/nextpas.core.text.tstring.pas 逻辑等价

target datalayout = "e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v64:64:64-v128:128:128-a0:0:64-s0:64:64-f80:128:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

; === External declarations ===
declare void @llvm.memset.p0.i64(ptr nocapture writeonly, i8, i64, i1 immarg)
declare void @llvm.memcpy.p0.p0.i64(ptr nocapture writeonly, ptr nocapture readonly, i64, i1 immarg)
declare void @llvm.trap()
declare ptr @np_alloc(i64 %size)
declare void @np_free(ptr %raw, i64 %size)
declare i64 @np_str_cmp(ptr %a_ptr, i64 %a_len, ptr %b_ptr, i64 %b_len)

; === Constants ===
@.TSTRING_SSO_TAG = private constant i8 0
@.TSTRING_HEAP_TAG = private constant i8 -1   ; 0xFF
@.TSTRING_SSO_MAX = private constant i64 15
@.TSTRING_SIZE = private constant i64 24
@.HEADER_SIZE = private constant i64 8

; ============================================================
; np_tstring_init — 零初始化 24B record (空串 = SSO, len=0)
; ============================================================
define void @np_tstring_init(ptr %s) {
entry:
  call void @llvm.memset.p0.i64(ptr align 8 %s, i8 0, i64 24, i1 false)
  ret void
}

; ============================================================
; np_tstring_fini — 释放 TString (SSO: 仅清零; Heap: decr refcount)
; ============================================================
define void @np_tstring_fini(ptr %s) {
entry:
  %tag_ptr = getelementptr i8, ptr %s, i64 0
  %tag = load i8, ptr %tag_ptr
  %is_heap = icmp eq i8 %tag, -1
  br i1 %is_heap, label %heap_path, label %clear

heap_path:
  ; load HeapHeader ptr at offset 8
  %hdr_ptr_ptr = getelementptr i8, ptr %s, i64 8
  %hdr = load ptr, ptr %hdr_ptr_ptr
  %hdr_null = icmp eq ptr %hdr, null
  br i1 %hdr_null, label %clear, label %check_ref

check_ref:
  ; load RefCount (i32 at offset 0 of header)
  %ref_ptr = getelementptr i8, ptr %hdr, i64 0
  %ref = load i32, ptr %ref_ptr
  %is_literal = icmp slt i32 %ref, 0
  br i1 %is_literal, label %clear, label %check_exclusive

check_exclusive:
  %is_exclusive = icmp eq i32 %ref, 1
  br i1 %is_exclusive, label %free_direct, label %decr_atomic

free_direct:
  ; 独占引用, 直接释放 (不需要原子操作)
  ; alloc_size = SizeOf(Header) + Capacity + 1
  %cap_ptr = getelementptr i8, ptr %hdr, i64 4
  %cap = load i32, ptr %cap_ptr
  %cap64 = zext i32 %cap to i64
  %alloc_size = add i64 12, %cap64   ; 8(header) + 4(padding to align?) no: header=8B
  ; 实际: SizeOf(TStringHeader)=8, 总分配 = 8 + Capacity + 1
  %total = add i64 %cap64, 9         ; 8 + cap + 1
  call void @np_free(ptr %hdr, i64 %total)
  br label %clear

decr_atomic:
  ; 共享引用: 原子递减
  %new_ref = atomicrmw sub ptr %ref_ptr, i32 1 seq_cst
  %was_one = icmp eq i32 %new_ref, 1
  br i1 %was_one, label %free_after_decr, label %clear

free_after_decr:
  ; 递减后为 0, 释放
  %cap_ptr2 = getelementptr i8, ptr %hdr, i64 4
  %cap2 = load i32, ptr %cap_ptr2
  %cap64_2 = zext i32 %cap2 to i64
  %total2 = add i64 %cap64_2, 9
  call void @np_free(ptr %hdr, i64 %total2)
  br label %clear

clear:
  call void @llvm.memset.p0.i64(ptr align 8 %s, i8 0, i64 24, i1 false)
  ret void
}

; ============================================================
; np_tstring_assign — CoW 赋值 (经典顺序: 先 incr src, 再 decr dst)
; ============================================================
define void @np_tstring_assign(ptr %dst, ptr %src) {
entry:
  ; 自赋值检查
  %is_self = icmp eq ptr %dst, %src
  br i1 %is_self, label %done, label %check_src

check_src:
  %src_tag_ptr = getelementptr i8, ptr %src, i64 0
  %src_tag = load i8, ptr %src_tag_ptr
  %src_is_heap = icmp eq i8 %src_tag, -1
  br i1 %src_is_heap, label %src_heap, label %src_sso

src_sso:
  ; 源是 SSO: 先释放旧目标 (如果是 heap), 再 memcpy 24B
  call void @__tstring_maybe_decr_dst(ptr %dst)
  call void @llvm.memcpy.p0.p0.i64(ptr align 8 %dst, ptr align 8 %src, i64 24, i1 false)
  br label %done

src_heap:
  ; 源是 Heap: 先 incr 源 header, 再 decr 旧目标, 再设置新值
  %src_hdr_ptr_ptr = getelementptr i8, ptr %src, i64 8
  %src_hdr = load ptr, ptr %src_hdr_ptr_ptr
  ; incr 源 (跳过 null 和 literal)
  call void @__tstring_heap_incr(ptr %src_hdr)
  ; decr 旧目标
  call void @__tstring_maybe_decr_dst(ptr %dst)
  ; 设置新值: copy 24B from src
  call void @llvm.memcpy.p0.p0.i64(ptr align 8 %dst, ptr align 8 %src, i64 24, i1 false)
  br label %done

done:
  ret void
}

; ============================================================
; np_tstring_move — 转移 ownership, 源清零
; ============================================================
define void @np_tstring_move(ptr %dst, ptr %src) {
entry:
  %is_self = icmp eq ptr %dst, %src
  br i1 %is_self, label %done, label %do_move

do_move:
  ; 先释放旧目标
  call void @np_tstring_fini(ptr %dst)
  ; memcpy src → dst
  call void @llvm.memcpy.p0.p0.i64(ptr align 8 %dst, ptr align 8 %src, i64 24, i1 false)
  ; 清零源
  call void @llvm.memset.p0.i64(ptr align 8 %src, i8 0, i64 24, i1 false)
  br label %done

done:
  ret void
}

; ============================================================
; np_tstring_len — 查询字符串长度
; ============================================================
define i64 @np_tstring_len(ptr %s) {
entry:
  %tag_ptr = getelementptr i8, ptr %s, i64 0
  %tag = load i8, ptr %tag_ptr
  %is_heap = icmp eq i8 %tag, -1
  br i1 %is_heap, label %heap_len, label %sso_len

sso_len:
  %len_ptr = getelementptr i8, ptr %s, i64 1
  %len8 = load i8, ptr %len_ptr
  %len64 = zext i8 %len8 to i64
  ret i64 %len64

heap_len:
  %hlen_ptr = getelementptr i8, ptr %s, i64 16
  %hlen = load i64, ptr %hlen_ptr
  ret i64 %hlen
}

; ============================================================
; np_tstring_data — 查询数据指针
; ============================================================
define ptr @np_tstring_data(ptr %s) {
entry:
  %tag_ptr = getelementptr i8, ptr %s, i64 0
  %tag = load i8, ptr %tag_ptr
  %is_heap = icmp eq i8 %tag, -1
  br i1 %is_heap, label %heap_data, label %sso_data

sso_data:
  ; SSO: 数据在 offset 2
  %buf_ptr = getelementptr i8, ptr %s, i64 2
  ret ptr %buf_ptr

heap_data:
  ; Heap: payload 在 header 之后 (header = 8B)
  %hdr_ptr_ptr = getelementptr i8, ptr %s, i64 8
  %hdr = load ptr, ptr %hdr_ptr_ptr
  %hdr_null = icmp eq ptr %hdr, null
  br i1 %hdr_null, label %null_ret, label %payload

payload:
  %payload_ptr = getelementptr i8, ptr %hdr, i64 8
  ret ptr %payload_ptr

null_ret:
  ret ptr null
}

; ============================================================
; np_tstring_is_sso — 是否 SSO 路径
; ============================================================
define i8 @np_tstring_is_sso(ptr %s) {
entry:
  %tag_ptr = getelementptr i8, ptr %s, i64 0
  %tag = load i8, ptr %tag_ptr
  %is_sso = icmp eq i8 %tag, 0
  %result = zext i1 %is_sso to i8
  ret i8 %result
}

; ============================================================
; np_tstring_create — 从 raw bytes 创建 TString
; ============================================================
define void @np_tstring_create(ptr %dst, ptr %data, i64 %len) {
entry:
  ; 先释放旧目标
  call void @np_tstring_fini(ptr %dst)
  ; 判断 SSO/Heap
  %sso_fits = icmp ule i64 %len, 15
  br i1 %sso_fits, label %sso_path, label %heap_path

sso_path:
  ; SSO: 零初始化 + 设置 tag/len + memcpy 数据
  call void @llvm.memset.p0.i64(ptr align 8 %dst, i8 0, i64 24, i1 false)
  ; SSOTag = 0 (已是 0)
  ; SSOLen = len
  %len8 = trunc i64 %len to i8
  %len_ptr = getelementptr i8, ptr %dst, i64 1
  store i8 %len8, ptr %len_ptr
  ; memcpy data to SSOBuf (offset 2)
  %has_data = icmp ne ptr %data, null
  %has_len = icmp ugt i64 %len, 0
  %can_copy = and i1 %has_data, %has_len
  br i1 %can_copy, label %sso_copy, label %done

sso_copy:
  %buf_ptr = getelementptr i8, ptr %dst, i64 2
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %buf_ptr, ptr align 1 %data, i64 %len, i1 false)
  br label %done

heap_path:
  ; Heap: alloc header + payload + null terminator
  %alloc_size = add i64 %len, 9   ; 8(header) + len + 1(null)
  %hdr = call ptr @np_alloc(i64 %alloc_size)
  ; 初始化 header: RefCount=1, Capacity=len
  %ref_ptr = getelementptr i8, ptr %hdr, i64 0
  store i32 1, ptr %ref_ptr
  %cap_ptr = getelementptr i8, ptr %hdr, i64 4
  %len32 = trunc i64 %len to i32
  store i32 %len32, ptr %cap_ptr
  ; null terminator
  %payload_ptr = getelementptr i8, ptr %hdr, i64 8
  %null_ptr = getelementptr i8, ptr %payload_ptr, i64 %len
  store i8 0, ptr %null_ptr
  ; memcpy data
  %has_data2 = icmp ne ptr %data, null
  %has_len2 = icmp ugt i64 %len, 0
  %can_copy2 = and i1 %has_data2, %has_len2
  br i1 %can_copy2, label %heap_copy, label %heap_finish

heap_copy:
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %payload_ptr, ptr align 1 %data, i64 %len, i1 false)
  br label %heap_finish

heap_finish:
  ; 设置 dst: 零初始化 + HeapTag + Header ptr + Len
  call void @llvm.memset.p0.i64(ptr align 8 %dst, i8 0, i64 24, i1 false)
  %dst_tag = getelementptr i8, ptr %dst, i64 0
  store i8 -1, ptr %dst_tag     ; TSTRING_HEAP_TAG = $FF
  %dst_hdr = getelementptr i8, ptr %dst, i64 8
  store ptr %hdr, ptr %dst_hdr
  %dst_len = getelementptr i8, ptr %dst, i64 16
  store i64 %len, ptr %dst_len
  br label %done

done:
  ret void
}

; ============================================================
; np_tstring_from_literal — 从字符串字面量创建 (SSO 或 Heap)
; ============================================================
define void @np_tstring_from_literal(ptr %dst, ptr %lit, i64 %len) {
entry:
  ; 字面量等同于 create, 但不 fini 旧目标 (caller 负责)
  ; 实际上复用 create 逻辑
  call void @np_tstring_create(ptr %dst, ptr %lit, i64 %len)
  ret void
}

; ============================================================
; np_tstring_concat — CoW concat: dst := a + b
; ============================================================
define void @np_tstring_concat(ptr %dst, ptr %a, ptr %b) {
entry:
  ; 获取 a 和 b 的长度和数据
  %a_len = call i64 @np_tstring_len(ptr %a)
  %b_len = call i64 @np_tstring_len(ptr %b)
  %total = add i64 %a_len, %b_len

  ; 先释放旧目标
  call void @np_tstring_fini(ptr %dst)

  ; 空串快速路径
  %is_zero = icmp eq i64 %total, 0
  br i1 %is_zero, label %zero, label %check_sso

zero:
  call void @llvm.memset.p0.i64(ptr align 8 %dst, i8 0, i64 24, i1 false)
  ret void

check_sso:
  %sso_fits = icmp ule i64 %total, 15
  br i1 %sso_fits, label %sso_concat, label %heap_concat

sso_concat:
  ; SSO concat: 内联 a + b
  call void @llvm.memset.p0.i64(ptr align 8 %dst, i8 0, i64 24, i1 false)
  %total8 = trunc i64 %total to i8
  %len_ptr = getelementptr i8, ptr %dst, i64 1
  store i8 %total8, ptr %len_ptr
  ; copy a
  %has_a = icmp ugt i64 %a_len, 0
  br i1 %has_a, label %copy_a, label %check_b

copy_a:
  %a_data = call ptr @np_tstring_data(ptr %a)
  %dst_buf = getelementptr i8, ptr %dst, i64 2
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %dst_buf, ptr align 1 %a_data, i64 %a_len, i1 false)
  br label %check_b

check_b:
  %has_b = icmp ugt i64 %b_len, 0
  br i1 %has_b, label %copy_b, label %done

copy_b:
  %b_data = call ptr @np_tstring_data(ptr %b)
  %dst_b = getelementptr i8, ptr %dst, i64 2
  %dst_b_off = getelementptr i8, ptr %dst_b, i64 %a_len
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %dst_b_off, ptr align 1 %b_data, i64 %b_len, i1 false)
  br label %done

heap_concat:
  ; Heap concat: alloc + copy a + copy b
  %alloc_size = add i64 %total, 9   ; 8(header) + total + 1(null)
  %hdr = call ptr @np_alloc(i64 %alloc_size)
  ; header
  %ref_ptr = getelementptr i8, ptr %hdr, i64 0
  store i32 1, ptr %ref_ptr
  %cap_ptr = getelementptr i8, ptr %hdr, i64 4
  %total32 = trunc i64 %total to i32
  store i32 %total32, ptr %cap_ptr
  ; null terminator
  %payload = getelementptr i8, ptr %hdr, i64 8
  %null_ptr = getelementptr i8, ptr %payload, i64 %total
  store i8 0, ptr %null_ptr
  ; copy a
  %has_a2 = icmp ugt i64 %a_len, 0
  br i1 %has_a2, label %hcopy_a, label %hcheck_b

hcopy_a:
  %a_data2 = call ptr @np_tstring_data(ptr %a)
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %payload, ptr align 1 %a_data2, i64 %a_len, i1 false)
  br label %hcheck_b

hcheck_b:
  %has_b2 = icmp ugt i64 %b_len, 0
  br i1 %has_b2, label %hcopy_b, label %hfinish

hcopy_b:
  %b_data2 = call ptr @np_tstring_data(ptr %b)
  %dst_off = getelementptr i8, ptr %payload, i64 %a_len
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %dst_off, ptr align 1 %b_data2, i64 %b_len, i1 false)
  br label %hfinish

hfinish:
  ; 设置 dst
  call void @llvm.memset.p0.i64(ptr align 8 %dst, i8 0, i64 24, i1 false)
  %dst_tag = getelementptr i8, ptr %dst, i64 0
  store i8 -1, ptr %dst_tag
  %dst_hdr_ptr = getelementptr i8, ptr %dst, i64 8
  store ptr %hdr, ptr %dst_hdr_ptr
  %dst_len_ptr = getelementptr i8, ptr %dst, i64 16
  store i64 %total, ptr %dst_len_ptr
  br label %done

done:
  ret void
}

; ============================================================
; np_tstring_copy — Copy(): dst := Copy(src, start, count)
; start is 1-based
; ============================================================
define void @np_tstring_copy(ptr %dst, ptr %src, i64 %start, i64 %count) {
entry:
  %src_len = call i64 @np_tstring_len(ptr %src)
  ; bounds check
  %start_valid = icmp sgt i64 %start, 0
  %count_valid = icmp sgt i64 %count, 0
  %start_in_range = icmp sle i64 %start, %src_len
  %valid = and i1 %start_valid, %count_valid
  %valid2 = and i1 %valid, %start_in_range
  br i1 %valid2, label %bounds, label %empty

empty:
  call void @np_tstring_fini(ptr %dst)
  call void @llvm.memset.p0.i64(ptr align 8 %dst, i8 0, i64 24, i1 false)
  ret void

bounds:
  %offset = sub i64 %start, 1
  %available = sub i64 %src_len, %offset
  %too_long = icmp sgt i64 %count, %available
  %copy_len = select i1 %too_long, i64 %available, i64 %count
  %copy_zero = icmp eq i64 %copy_len, 0
  br i1 %copy_zero, label %empty, label %do_copy

do_copy:
  %src_data = call ptr @np_tstring_data(ptr %src)
  %src_slice = getelementptr i8, ptr %src_data, i64 %offset
  call void @np_tstring_create(ptr %dst, ptr %src_slice, i64 %copy_len)
  ret void
}

; ============================================================
; np_tstring_from_int — i64 转 TString
; ============================================================
define void @np_tstring_from_int(ptr %dst, i64 %val) {
entry:
  ; 分配临时 buffer (21 bytes max for i64)
  %buf = alloca [21 x i8], align 1
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
  %dp = getelementptr [21 x i8], ptr %buf, i64 0, i64 %pos_next
  store i8 %ct, ptr %dp
  %n_next = udiv i64 %n, 10
  %done = icmp eq i64 %n_next, 0
  br i1 %done, label %finish, label %digit_loop

finish:
  %final_pos = phi i64 [ %pos_next, %digit_loop ]
  br i1 %is_neg, label %write_neg, label %create

write_neg:
  %neg_pos = sub i64 %final_pos, 1
  %negp = getelementptr [21 x i8], ptr %buf, i64 0, i64 %neg_pos
  store i8 45, ptr %negp
  br label %create

create:
  %result_pos = phi i64 [ %final_pos, %finish ], [ %neg_pos, %write_neg ]
  %result_ptr = getelementptr [21 x i8], ptr %buf, i64 0, i64 %result_pos
  %result_len = sub i64 20, %result_pos
  call void @np_tstring_create(ptr %dst, ptr %result_ptr, i64 %result_len)
  ret void
}

; ============================================================
; np_tstring_equal — 比较两个 TString 是否相等
; ============================================================
define i64 @np_tstring_equal(ptr %a, ptr %b) {
entry:
  %a_len = call i64 @np_tstring_len(ptr %a)
  %b_len = call i64 @np_tstring_len(ptr %b)
  %len_eq = icmp eq i64 %a_len, %b_len
  br i1 %len_eq, label %check_empty, label %not_equal

check_empty:
  %is_empty = icmp eq i64 %a_len, 0
  br i1 %is_empty, label %equal, label %compare

compare:
  %a_data = call ptr @np_tstring_data(ptr %a)
  %b_data = call ptr @np_tstring_data(ptr %b)
  %result = call i64 @np_str_cmp(ptr %a_data, i64 %a_len, ptr %b_data, i64 %b_len)
  ret i64 %result

equal:
  ret i64 1

not_equal:
  ret i64 0
}

; ============================================================
; np_tstring_compare — 三路比较 (lexicographic)
; 返回: -1 (a < b), 0 (a == b), 1 (a > b)
; ============================================================
define i64 @np_tstring_compare(ptr %a, ptr %b) {
entry:
  %a_len = call i64 @np_tstring_len(ptr %a)
  %b_len = call i64 @np_tstring_len(ptr %b)
  %a_data = call ptr @np_tstring_data(ptr %a)
  %b_data = call ptr @np_tstring_data(ptr %b)
  ; min length
  %a_lt_b = icmp ult i64 %a_len, %b_len
  %min_len = select i1 %a_lt_b, i64 %a_len, i64 %b_len
  br label %loop

loop:
  %i = phi i64 [ 0, %entry ], [ %i_next, %loop_next ]
  %done = icmp eq i64 %i, %min_len
  br i1 %done, label %tail, label %loop_body

loop_body:
  %ap = getelementptr i8, ptr %a_data, i64 %i
  %bp = getelementptr i8, ptr %b_data, i64 %i
  %ac = load i8, ptr %ap
  %bc = load i8, ptr %bp
  %a_lt = icmp ult i8 %ac, %bc
  %a_gt = icmp ugt i8 %ac, %bc
  br i1 %a_lt, label %ret_lt, label %check_gt

check_gt:
  br i1 %a_gt, label %ret_gt, label %loop_next

loop_next:
  %i_next = add i64 %i, 1
  br label %loop

tail:
  ; all bytes equal up to min_len, compare lengths
  %len_lt = icmp ult i64 %a_len, %b_len
  %len_gt = icmp ugt i64 %a_len, %b_len
  br i1 %len_lt, label %ret_lt, label %check_len_gt

check_len_gt:
  br i1 %len_gt, label %ret_gt, label %ret_eq

ret_lt:
  ret i64 -1

ret_gt:
  ret i64 1

ret_eq:
  ret i64 0
}

; ============================================================
; np_tstring_field_assign — 字段赋值: 先 fini old, 再 assign new
; ============================================================
define void @np_tstring_field_assign(ptr %dst, ptr %src) {
entry:
  ; 先 fini 旧值
  call void @np_tstring_fini(ptr %dst)
  ; 再 assign 新值
  call void @np_tstring_assign(ptr %dst, ptr %src)
  ret void
}

; ============================================================
; np_tstring_field_fini — 字段清理: fini + clear
; ============================================================
define void @np_tstring_field_fini(ptr %s) {
entry:
  call void @np_tstring_fini(ptr %s)
  ret void
}

; ============================================================
; np_tstring_ret_move — sret: 移动到 sret 指针
; ============================================================
define void @np_tstring_ret_move(ptr %sret_dst, ptr %src) {
entry:
  call void @llvm.memcpy.p0.p0.i64(ptr align 8 %sret_dst, ptr align 8 %src, i64 24, i1 false)
  ; 清零源 (ownership 已转移)
  call void @llvm.memset.p0.i64(ptr align 8 %src, i8 0, i64 24, i1 false)
  ret void
}

; ============================================================
; np_tstring_ret_copy — sret: 拷贝到 sret 指针 (CoW bump)
; ============================================================
define void @np_tstring_ret_copy(ptr %sret_dst, ptr %src) {
entry:
  call void @np_tstring_assign(ptr %sret_dst, ptr %src)
  ret void
}

; ============================================================
; Internal helpers
; ============================================================

; __tstring_heap_incr — 原子递增 refcount (跳过 null 和 literal)
define private void @__tstring_heap_incr(ptr %hdr) {
entry:
  %is_null = icmp eq ptr %hdr, null
  br i1 %is_null, label %done, label %check_ref

check_ref:
  %ref_ptr = getelementptr i8, ptr %hdr, i64 0
  %ref = load i32, ptr %ref_ptr
  %is_literal = icmp slt i32 %ref, 0
  br i1 %is_literal, label %done, label %incr

incr:
  atomicrmw add ptr %ref_ptr, i32 1 seq_cst
  br label %done

done:
  ret void
}

; __tstring_maybe_decr_dst — 如果 dst 是 heap, decr refcount
define private void @__tstring_maybe_decr_dst(ptr %s) {
entry:
  %tag_ptr = getelementptr i8, ptr %s, i64 0
  %tag = load i8, ptr %tag_ptr
  %is_heap = icmp eq i8 %tag, -1
  br i1 %is_heap, label %heap, label %done

heap:
  %hdr_ptr_ptr = getelementptr i8, ptr %s, i64 8
  %hdr = load ptr, ptr %hdr_ptr_ptr
  %hdr_null = icmp eq ptr %hdr, null
  br i1 %hdr_null, label %done, label %check_ref

check_ref:
  %ref_ptr = getelementptr i8, ptr %hdr, i64 0
  %ref = load i32, ptr %ref_ptr
  %is_literal = icmp slt i32 %ref, 0
  br i1 %is_literal, label %done, label %check_excl

check_excl:
  %is_excl = icmp eq i32 %ref, 1
  br i1 %is_excl, label %free_direct, label %decr

free_direct:
  %cap_ptr = getelementptr i8, ptr %hdr, i64 4
  %cap = load i32, ptr %cap_ptr
  %cap64 = zext i32 %cap to i64
  %total = add i64 %cap64, 9
  call void @np_free(ptr %hdr, i64 %total)
  br label %done

decr:
  %new_ref = atomicrmw sub ptr %ref_ptr, i32 1 seq_cst
  %was_one = icmp eq i32 %new_ref, 1
  br i1 %was_one, label %free_after, label %done

free_after:
  %cap_ptr2 = getelementptr i8, ptr %hdr, i64 4
  %cap2 = load i32, ptr %cap_ptr2
  %cap64_2 = zext i32 %cap2 to i64
  %total2 = add i64 %cap64_2, 9
  call void @np_free(ptr %hdr, i64 %total2)
  br label %done

done:
  ret void
}
