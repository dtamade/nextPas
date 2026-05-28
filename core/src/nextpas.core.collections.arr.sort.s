	.file "nextpas.core.collections.arr.sort.pas"
# Begin asmlist al_procedures

.section .text.n_nextpas.core.collections.arr.sort_$$_sorti32$plongint$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.ARR.SORT_$$_SORTI32$PLONGINT$QWORD
	.type	NEXTPAS.CORE.COLLECTIONS.ARR.SORT_$$_SORTI32$PLONGINT$QWORD,@function
NEXTPAS.CORE.COLLECTIONS.ARR.SORT_$$_SORTI32$PLONGINT$QWORD:
.Lc2:
# [nextpas.core.collections.arr.sort.inc]
# [175] begin
	pushq	%rax
.Lc3:
# Var aData located at rsp+0, size=OS_64
# Var tmp located in register edx
	movq	%rdi,(%rsp)
# Var aCount located in register rsi
# [176] if aCount < 2 then Exit;
	cmpq	$2,%rsi
	jb	.Lj3
# [178] LEnd := aCount - 2;
	leaq	-2(%rsi),%rax
# Var LEnd located in register rax
# Var i located in register r8
# [179] i := 0;
	xorl	%r8d,%r8d
# [180] while (i <= LEnd) and (aData[i] = aData[i + 1]) do Inc(i);
	jmp	.Lj16
	.p2align 4,,10
	.p2align 3
.Lj15:
	addq	$1,%r8
.Lj16:
	cmpq	%r8,%rax
	jnae	.Lj3
	movq	(%rsp),%rdx
	movl	4(%rdx,%r8,4),%ecx
	cmpl	(%rdx,%r8,4),%ecx
	je	.Lj15
# [181] if i > LEnd then Exit;
	cmpq	%r8,%rax
	jb	.Lj3
	movq	(%rsp),%rcx
# [183] if aData[i] < aData[i + 1] then
	movl	4(%rcx,%r8,4),%edx
	cmpl	(%rcx,%r8,4),%edx
	jng	.Lj24
# [185] Inc(i);
	addq	$1,%r8
# [186] while (i <= LEnd) and (aData[i] <= aData[i + 1]) do Inc(i);
	jmp	.Lj26
	.p2align 4,,10
	.p2align 3
.Lj25:
	addq	$1,%r8
.Lj26:
	cmpq	%r8,%rax
	jnae	.Lj3
	movq	(%rsp),%rcx
	movl	4(%rcx,%r8,4),%edx
	cmpl	(%rcx,%r8,4),%edx
	jge	.Lj25
# [187] if i > LEnd then Exit;
	cmpq	%r8,%rax
	jb	.Lj3
	jmp	.Lj33
	.p2align 4,,10
	.p2align 3
.Lj24:
# [191] Inc(i);
	addq	$1,%r8
# [192] while (i <= LEnd) and (aData[i] >= aData[i + 1]) do Inc(i);
	jmp	.Lj35
	.p2align 4,,10
	.p2align 3
.Lj34:
	addq	$1,%r8
.Lj35:
	cmpq	%r8,%rax
	jnae	.Lj40
	movq	(%rsp),%rdx
	movl	4(%rdx,%r8,4),%ecx
	cmpl	(%rdx,%r8,4),%ecx
	jle	.Lj34
# [193] if i > LEnd then
	cmpq	%r8,%rax
	jnb	.Lj33
.Lj40:
# [195] i := 0; LEnd := aCount - 1;
	xorl	%r8d,%r8d
	leaq	-1(%rsi),%rax
# [196] while i < LEnd do
	cmpq	%r8,%rax
	jna	.Lj3
	.p2align 4,,10
	.p2align 3
.Lj44:
# [198] tmp := aData[i]; aData[i] := aData[LEnd]; aData[LEnd] := tmp;
	movq	(%rsp),%rcx
	movl	(%rcx,%r8,4),%edx
	movq	(%rsp),%rdi
	movl	(%rdi,%rax,4),%ecx
	movl	%ecx,(%rdi,%r8,4)
	movq	(%rsp),%rcx
	movl	%edx,(%rcx,%rax,4)
# [199] Inc(i); Dec(LEnd);
	addq	$1,%r8
	subq	$1,%rax
	cmpq	%r8,%rax
	ja	.Lj44
# [201] Exit;
	jmp	.Lj3
	.p2align 4,,10
	.p2align 3
.Lj33:
# Var LDepth located in register ecx
# [205] LDepth := 0;
	xorl	%ecx,%ecx
# Var LN located in register rax
# Var aCount located in register rsi
# [206] LN := aCount;
	movq	%rsi,%rax
# [207] while LN > 1 do begin LN := LN shr 1; Inc(LDepth); end;
	cmpq	$1,%rsi
	jna	.Lj48
	.p2align 4,,10
	.p2align 3
.Lj49:
	shrq	$1,%rax
	addl	$1,%ecx
	cmpq	$1,%rax
	ja	.Lj49
.Lj48:
# [208] LDepth := LDepth * 2;
	shll	$1,%ecx
# Var LDepth located in register ecx
# [210] IntroSort(0, aCount - 1, LDepth);
	leaq	-1(%rsi),%rdx
	movq	%rsp,%rdi
# Var LDepth located in register ecx
	xorl	%esi,%esi
	call	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI32$PLONGINT$QWORD_$$_INTROSORT$QWORD$QWORD$LONGINT
.Lj3:
# [211] end;
	popq	%rcx
.Lc4:
	ret
.Lc1:

.section .text.n_nextpas.core.collections.arr.sort$_$sorti32$plongint$qword_$$_introsort$qword$qword$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI32$PLONGINT$QWORD_$$_INTROSORT$QWORD$QWORD$LONGINT
	.hidden NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI32$PLONGINT$QWORD_$$_INTROSORT$QWORD$QWORD$LONGINT
	.type	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI32$PLONGINT$QWORD_$$_INTROSORT$QWORD$QWORD$LONGINT,@function
NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI32$PLONGINT$QWORD_$$_INTROSORT$QWORD$QWORD$LONGINT:
.Lc6:
# Temps allocated between rsp+0 and rsp+40
# [115] begin
	pushq	%rbx
.Lc7:
	pushq	%r12
.Lc8:
	pushq	%r13
.Lc9:
	pushq	%r14
.Lc10:
	pushq	%r15
.Lc11:
	leaq	-48(%rsp),%rsp
.Lc12:
# Var lt located in register r13
# Var gt located in register rbx
# Var i located in register r12
# Var LMid located in stack [rsp+8]
# Var pivot located in stack [rsp+16]
# Var tmp located in stack [rsp+32]
	movq	%rdi,%r14
# Var $parentfp located in register r14
	movq	%rsi,%r15
# Var aLeft located in register r15
	movq	%rdx,24(%rsp)
# Var aRight located in stack [rsp+24]
	movl	%ecx,%eax
	movq	%rax,(%rsp)
# Var aDepth located in stack [rsp+0]
# [116] while aLeft < aRight do
	cmpq	%r15,24(%rsp)
	jna	.Lj11
	.p2align 4,,10
	.p2align 3
.Lj54:
# [118] if aRight - aLeft < INSERTION_THRESHOLD then
	movq	24(%rsp),%rax
	subq	%r15,%rax
	cmpq	$24,%rax
	jnb	.Lj58
# [120] InsertionSort(aLeft, aRight);
	movq	24(%rsp),%rdi
	leaq	1(%r15),%rax
	cmpq	%rdi,%rax
	jnbe	.Lj11
	movq	%r15,%rcx
	.p2align 4,,10
	.p2align 3
.Lj61:
	addq	$1,%rcx
	movq	(%r14),%rax
	movl	(%rax,%rcx,4),%r8d
	movq	%rcx,%rsi
	jmp	.Lj65
	.p2align 4,,10
	.p2align 3
.Lj64:
	movq	(%r14),%rdx
	movl	-4(%rdx,%rsi,4),%eax
	movl	%eax,(%rdx,%rsi,4)
	subq	$1,%rsi
.Lj65:
	cmpq	%rsi,%r15
	jnb	.Lj68
	movq	(%r14),%rax
	cmpl	-4(%rax,%rsi,4),%r8d
	jl	.Lj64
.Lj68:
	movq	(%r14),%rax
	movl	%r8d,(%rax,%rsi,4)
	cmpq	%rcx,%rdi
	jnbe	.Lj61
# [121] Exit;
	jmp	.Lj11
	.p2align 4,,10
	.p2align 3
.Lj58:
# [124] if aDepth = 0 then
	cmpl	$0,(%rsp)
	jne	.Lj71
# [126] HeapSort(aLeft, aRight);
	movq	%r14,%rdi
	movq	24(%rsp),%rdx
	movq	%r15,%rsi
	call	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI32$PLONGINT$QWORD_$$_HEAPSORT$QWORD$QWORD
# [127] Exit;
	jmp	.Lj11
	.p2align 4,,10
	.p2align 3
.Lj71:
# [129] Dec(aDepth);
	movl	(%rsp),%eax
	subl	$1,%eax
	movq	%rax,(%rsp)
# [131] LMid := aLeft + (aRight - aLeft) div 2;
	movq	24(%rsp),%rax
	subq	%r15,%rax
	shrq	$1,%rax
	addq	%r15,%rax
	movq	%rax,8(%rsp)
	movq	(%r14),%rcx
# [132] if aData[aLeft] > aData[LMid] then
	movl	(%rcx,%r15,4),%edx
	movq	8(%rsp),%rax
	cmpl	(%rcx,%rax,4),%edx
	jng	.Lj73
# [133] begin tmp := aData[aLeft]; aData[aLeft] := aData[LMid]; aData[LMid] := tmp; end;
	movq	(%r14),%rax
	movl	(%rax,%r15,4),%edx
	movq	%rdx,32(%rsp)
	movq	(%r14),%rcx
	movq	8(%rsp),%rdx
	movl	(%rcx,%rdx,4),%eax
	movl	%eax,(%rcx,%r15,4)
	movq	(%r14),%rcx
	movl	32(%rsp),%edx
	movq	8(%rsp),%rax
	movl	%edx,(%rcx,%rax,4)
.Lj73:
	movq	(%r14),%rdx
# [134] if aData[LMid] > aData[aRight] then
	movq	8(%rsp),%rcx
	movl	(%rdx,%rcx,4),%eax
	movq	24(%rsp),%rcx
	cmpl	(%rdx,%rcx,4),%eax
	jng	.Lj75
# [135] begin tmp := aData[LMid]; aData[LMid] := aData[aRight]; aData[aRight] := tmp; end;
	movq	(%r14),%rax
	movq	8(%rsp),%rdx
	movl	(%rax,%rdx,4),%edx
	movq	%rdx,32(%rsp)
	movq	(%r14),%rdx
	movq	24(%rsp),%rcx
	movl	(%rdx,%rcx,4),%eax
	movq	8(%rsp),%rcx
	movl	%eax,(%rdx,%rcx,4)
	movq	(%r14),%rcx
	movl	32(%rsp),%edx
	movq	24(%rsp),%rax
	movl	%edx,(%rcx,%rax,4)
.Lj75:
	movq	(%r14),%rax
# [136] if aData[aLeft] > aData[LMid] then
	movl	(%rax,%r15,4),%ecx
	movq	8(%rsp),%rdx
	cmpl	(%rax,%rdx,4),%ecx
	jng	.Lj77
# [137] begin tmp := aData[aLeft]; aData[aLeft] := aData[LMid]; aData[LMid] := tmp; end;
	movq	(%r14),%rdx
	movl	(%rdx,%r15,4),%eax
	movq	%rax,32(%rsp)
	movq	(%r14),%rax
	movq	8(%rsp),%rcx
	movl	(%rax,%rcx,4),%edx
	movl	%edx,(%rax,%r15,4)
	movq	(%r14),%rax
	movl	32(%rsp),%ecx
	movq	8(%rsp),%rdx
	movl	%ecx,(%rax,%rdx,4)
.Lj77:
# [138] pivot := aData[LMid];
	movq	(%r14),%rax
	movq	8(%rsp),%rdx
	movl	(%rax,%rdx,4),%edx
	movq	%rdx,16(%rsp)
# [140] lt := aLeft;
	movq	%r15,%r13
# [141] gt := aRight;
	movq	24(%rsp),%rbx
# [142] i := aLeft;
	movq	%r15,%r12
# [143] while i <= gt do
	cmpq	%r15,%rbx
	jnae	.Lj79
	.p2align 4,,10
	.p2align 3
.Lj80:
# [145] if aData[i] < pivot then
	movq	(%r14),%rax
	movl	16(%rsp),%edx
	cmpl	(%rax,%r12,4),%edx
	jng	.Lj84
# [147] tmp := aData[i]; aData[i] := aData[lt]; aData[lt] := tmp;
	movq	(%r14),%rax
	movl	(%rax,%r12,4),%edx
	movq	%rdx,32(%rsp)
	movq	(%r14),%rdx
	movl	(%rdx,%r13,4),%eax
	movl	%eax,(%rdx,%r12,4)
	movq	(%r14),%rax
	movl	32(%rsp),%edx
	movl	%edx,(%rax,%r13,4)
# [148] Inc(lt); Inc(i);
	addq	$1,%r13
	addq	$1,%r12
	jmp	.Lj85
	.p2align 4,,10
	.p2align 3
.Lj84:
# [150] else if aData[i] > pivot then
	movq	(%r14),%rax
	movl	16(%rsp),%edx
	cmpl	(%rax,%r12,4),%edx
	jnl	.Lj87
# [152] tmp := aData[i]; aData[i] := aData[gt]; aData[gt] := tmp;
	movq	(%r14),%rax
	movl	(%rax,%r12,4),%edx
	movq	%rdx,32(%rsp)
	movq	(%r14),%rax
	movl	(%rax,%rbx,4),%edx
	movl	%edx,(%rax,%r12,4)
	movq	(%r14),%rax
	movl	32(%rsp),%edx
	movl	%edx,(%rax,%rbx,4)
# [153] Dec(gt);
	subq	$1,%rbx
	jmp	.Lj85
	.p2align 4,,10
	.p2align 3
.Lj87:
# [156] Inc(i);
	addq	$1,%r12
.Lj85:
	cmpq	%r12,%rbx
	jae	.Lj80
.Lj79:
# [159] if (lt > aLeft) and TryPartialInsertionSort(aLeft, lt - 1) then
	cmpq	%r13,%r15
	jnb	.Lj90
	xorl	%r9d,%r9d
	leaq	-1(%r13),%r10
	leaq	1(%r15),%rax
	cmpq	%r10,%rax
	jnbe	.Lj94
	movq	%r15,%rdi
	.p2align 4,,10
	.p2align 3
.Lj95:
	addq	$1,%rdi
	movq	(%r14),%rax
	movl	(%rax,%rdi,4),%ecx
	movq	%rdi,%r8
	jmp	.Lj99
	.p2align 4,,10
	.p2align 3
.Lj98:
	movq	(%r14),%rax
	movl	-4(%rax,%r8,4),%edx
	movl	%edx,(%rax,%r8,4)
	subq	$1,%r8
	addl	$1,%r9d
	cmpl	$12,%r9d
	jng	.Lj99
	xorb	%sil,%sil
	jmp	.Lj92
	.p2align 4,,10
	.p2align 3
.Lj99:
	cmpq	%r8,%r15
	jnb	.Lj104
	movq	(%r14),%rax
	cmpl	-4(%rax,%r8,4),%ecx
	jl	.Lj98
.Lj104:
	movq	(%r14),%rax
	movl	%ecx,(%rax,%r8,4)
	cmpq	%rdi,%r10
	jnbe	.Lj95
.Lj94:
	movb	$1,%sil
.Lj92:
	testb	%sil,%sil
	jne	.Lj91
.Lj90:
# [161] else if lt > aLeft + 1 then
	leaq	1(%r15),%rax
	cmpq	%r13,%rax
	jnb	.Lj91
# [162] IntroSort(aLeft, lt - 1, aDepth);
	leaq	-1(%r13),%rdx
	movq	%r14,%rdi
	movl	(%rsp),%ecx
	movq	%r15,%rsi
	call	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI32$PLONGINT$QWORD_$$_INTROSORT$QWORD$QWORD$LONGINT
.Lj91:
# [164] if (gt < aRight) and TryPartialInsertionSort(gt + 1, aRight) then
	cmpq	%rbx,24(%rsp)
	jna	.Lj109
	xorl	%r9d,%r9d
	movq	24(%rsp),%r10
	leaq	2(%rbx),%rax
	cmpq	%r10,%rax
	jnbe	.Lj113
	leaq	1(%rbx),%rdi
	.p2align 4,,10
	.p2align 3
.Lj114:
	addq	$1,%rdi
	movq	(%r14),%rax
	movl	(%rax,%rdi,4),%ecx
	movq	%rdi,%r8
	jmp	.Lj118
	.p2align 4,,10
	.p2align 3
.Lj117:
	movq	(%r14),%rdx
	movl	-4(%rdx,%r8,4),%eax
	movl	%eax,(%rdx,%r8,4)
	subq	$1,%r8
	addl	$1,%r9d
	cmpl	$12,%r9d
	jng	.Lj118
	xorb	%sil,%sil
	jmp	.Lj111
	.p2align 4,,10
	.p2align 3
.Lj118:
	leaq	1(%rbx),%rax
	cmpq	%r8,%rax
	jnb	.Lj123
	movq	(%r14),%rax
	cmpl	-4(%rax,%r8,4),%ecx
	jl	.Lj117
.Lj123:
	movq	(%r14),%rax
	movl	%ecx,(%rax,%r8,4)
	cmpq	%rdi,%r10
	jnbe	.Lj114
.Lj113:
	movb	$1,%sil
.Lj111:
	testb	%sil,%sil
	jne	.Lj11
	.p2align 4,,10
	.p2align 3
.Lj109:
# [167] aLeft := gt + 1;
	leaq	1(%rbx),%r15
	cmpq	%r15,24(%rsp)
	ja	.Lj54
.Lj11:
# [169] end;
	leaq	48(%rsp),%rsp
	popq	%r15
.Lc13:
	popq	%r14
.Lc14:
	popq	%r13
.Lc15:
	popq	%r12
.Lc16:
	popq	%rbx
.Lc17:
	ret
.Lc5:
.Le0:
	.size	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI32$PLONGINT$QWORD_$$_INTROSORT$QWORD$QWORD$LONGINT, .Le0 - NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI32$PLONGINT$QWORD_$$_INTROSORT$QWORD$QWORD$LONGINT

.section .text.n_nextpas.core.collections.arr.sort$_$sorti32$plongint$qword_$$_heapsort$qword$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI32$PLONGINT$QWORD_$$_HEAPSORT$QWORD$QWORD
	.hidden NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI32$PLONGINT$QWORD_$$_HEAPSORT$QWORD$QWORD
	.type	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI32$PLONGINT$QWORD_$$_HEAPSORT$QWORD$QWORD,@function
NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI32$PLONGINT$QWORD_$$_HEAPSORT$QWORD$QWORD:
.Lc19:
# [66] begin
	pushq	%rbx
.Lc20:
# Var idx located in register rcx
# Var child located in register r9
# Var tmp located in register r10d
# Var $parentfp located in register rdi
# Var aL located in register rsi
# Var aR located in register rdx
# [67] LSize := aR - aL + 1;
	subq	%rsi,%rdx
	leaq	1(%rdx),%rax
# Var LSize located in register rax
# [68] i := LSize div 2;
	movq	%rax,%rdx
	shrq	$1,%rdx
# Var i located in register rdx
	.p2align 4,,10
	.p2align 3
.Lj126:
# [72] idx := i;
	leaq	-1(%rdx),%rcx
# [71] Dec(i);
	subq	$1,%rdx
# [73] tmp := aData[aL + idx];
	movq	(%rdi),%r11
	leaq	(%rsi,%rdx),%r8
	movl	(%r11,%r8,4),%r10d
	.p2align 4,,10
	.p2align 3
.Lj129:
# [76] child := 2 * idx + 1;
	leaq	1(%rcx,%rcx,1),%r9
# [77] if child >= LSize then Break;
	cmpq	%r9,%rax
	jbe	.Lj131
# [78] if (child + 1 < LSize) and (aData[aL + child] < aData[aL + child + 1]) then
	leaq	1(%r9),%r8
	cmpq	%rax,%r8
	jnb	.Lj135
	movq	(%rdi),%r11
	leaq	(%rsi,%r9),%r8
	movl	4(%r11,%r8,4),%ebx
	cmpl	(%r11,%r8,4),%ebx
	setg	%r8b
# [79] Inc(child);
	movzbl	%r8b,%r8d
	addq	%r8,%r9
.Lj135:
# [80] if tmp >= aData[aL + child] then Break;
	movq	(%rdi),%r11
	leaq	(%rsi,%r9),%r8
	cmpl	(%r11,%r8,4),%r10d
	jge	.Lj131
	movq	(%rdi),%r8
# [81] aData[aL + idx] := aData[aL + child];
	leaq	(%rsi,%rcx),%r11
	leaq	(%rsi,%r9),%rbx
	movl	(%r8,%rbx,4),%ebx
	movl	%ebx,(%r8,%r11,4)
# [82] idx := child;
	movq	%r9,%rcx
# [74] while True do
	jmp	.Lj129
.Lj131:
# [84] aData[aL + idx] := tmp;
	movq	(%rdi),%r8
	leaq	(%rsi,%rcx),%r11
	movl	%r10d,(%r8,%r11,4)
# [85] if i = 0 then Break;
	testq	%rdx,%rdx
	jne	.Lj126
# [87] i := LSize - 1;
	leaq	-1(%rax),%rdx
# Var i located in register rdx
# [88] while i > 0 do
	testq	%rdx,%rdx
	je	.Lj142
	.p2align 4,,10
	.p2align 3
.Lj143:
# [90] tmp := aData[aL + i];
	movq	(%rdi),%r8
	leaq	(%rsi,%rdx),%r11
	movl	(%r8,%r11,4),%r10d
	movq	(%rdi),%r11
# [91] aData[aL + i] := aData[aL];
	leaq	(%rsi,%rdx),%rbx
	movl	(%r11,%rsi,4),%r8d
	movl	%r8d,(%r11,%rbx,4)
# [92] aData[aL] := tmp;
	movq	(%rdi),%r8
	movl	%r10d,(%r8,%rsi,4)
# [93] Dec(LSize);
	subq	$1,%rax
# [94] idx := 0;
	xorl	%ecx,%ecx
# [95] tmp := aData[aL];
	movq	(%rdi),%r8
	movl	(%r8,%rsi,4),%r10d
	.p2align 4,,10
	.p2align 3
.Lj146:
# [98] child := 2 * idx + 1;
	leaq	1(%rcx,%rcx,1),%r9
# [99] if child >= LSize then Break;
	cmpq	%r9,%rax
	jbe	.Lj148
# [100] if (child + 1 < LSize) and (aData[aL + child] < aData[aL + child + 1]) then
	leaq	1(%r9),%r8
	cmpq	%rax,%r8
	jnb	.Lj152
	movq	(%rdi),%r11
	leaq	(%rsi,%r9),%r8
	movl	4(%r11,%r8,4),%ebx
	cmpl	(%r11,%r8,4),%ebx
	setg	%r8b
# [101] Inc(child);
	movzbl	%r8b,%r8d
	addq	%r8,%r9
.Lj152:
# [102] if tmp >= aData[aL + child] then Break;
	movq	(%rdi),%r11
	leaq	(%rsi,%r9),%r8
	cmpl	(%r11,%r8,4),%r10d
	jge	.Lj148
	movq	(%rdi),%r11
# [103] aData[aL + idx] := aData[aL + child];
	leaq	(%rsi,%rcx),%r8
	leaq	(%rsi,%r9),%rbx
	movl	(%r11,%rbx,4),%ebx
	movl	%ebx,(%r11,%r8,4)
# [104] idx := child;
	movq	%r9,%rcx
# [96] while True do
	jmp	.Lj146
.Lj148:
# [106] aData[aL + idx] := tmp;
	movq	(%rdi),%r8
	leaq	(%rsi,%rcx),%r11
	movl	%r10d,(%r8,%r11,4)
# [107] Dec(i);
	subq	$1,%rdx
	jne	.Lj143
.Lj142:
# [109] end;
	popq	%rbx
.Lc21:
	ret
.Lc18:
.Le1:
	.size	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI32$PLONGINT$QWORD_$$_HEAPSORT$QWORD$QWORD, .Le1 - NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI32$PLONGINT$QWORD_$$_HEAPSORT$QWORD$QWORD

.section .text.n_nextpas.core.collections.arr.sort$_$sorti32$plongint$qword_$$_trypartialinsertionsort$hhhlmht7g06j,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI32$PLONGINT$QWORD_$$_TRYPARTIALINSERTIONSORT$hhHLmht7G06J
	.hidden NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI32$PLONGINT$QWORD_$$_TRYPARTIALINSERTIONSORT$hhHLmht7G06J
	.type	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI32$PLONGINT$QWORD_$$_TRYPARTIALINSERTIONSORT$hhHLmht7G06J,@function
NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI32$PLONGINT$QWORD_$$_TRYPARTIALINSERTIONSORT$hhHLmht7G06J:
.Lc23:
# [44] begin
	pushq	%rbx
.Lc24:
# Var $result located in register al
# Var i located in register rcx
# Var j located in register r8
# Var tmp located in register r9d
# Var $parentfp located in register rdi
# Var aL located in register rsi
# Var aR located in register rdx
# Var LMoves located in register ebx
# [45] LMoves := 0;
	xorl	%ebx,%ebx
# Var aR located in register rdx
# [46] for i := aL + 1 to aR do
	leaq	1(%rsi),%rax
	cmpq	%rdx,%rax
	jnbe	.Lj157
	movq	%rsi,%rcx
	.p2align 4,,10
	.p2align 3
.Lj158:
	addq	$1,%rcx
# [48] tmp := aData[i];
	movq	(%rdi),%r10
	movl	(%r10,%rcx,4),%r9d
# [49] j := i;
	movq	%rcx,%r8
# [50] while (j > aL) and (aData[j - 1] > tmp) do
	jmp	.Lj162
	.p2align 4,,10
	.p2align 3
.Lj161:
	movq	(%rdi),%r10
# [52] aData[j] := aData[j - 1];
	movl	-4(%r10,%r8,4),%r11d
	movl	%r11d,(%r10,%r8,4)
# [53] Dec(j);
	subq	$1,%r8
# [54] Inc(LMoves);
	addl	$1,%ebx
# [55] if LMoves > PARTIAL_INSERTION_LIMIT then Exit(False);
	cmpl	$12,%ebx
	jng	.Lj162
	xorb	%al,%al
	jmp	.Lj7
	.p2align 4,,10
	.p2align 3
.Lj162:
	cmpq	%r8,%rsi
	jnb	.Lj167
	movq	(%rdi),%r10
	cmpl	-4(%r10,%r8,4),%r9d
	jl	.Lj161
.Lj167:
# [57] aData[j] := tmp;
	movq	(%rdi),%r10
	movl	%r9d,(%r10,%r8,4)
	cmpq	%rcx,%rdx
	jnbe	.Lj158
.Lj157:
# [59] Result := True;
	movb	$1,%al
.Lj7:
# [60] end;
	popq	%rbx
.Lc25:
	ret
.Lc22:

.section .text.n_nextpas.core.collections.arr.sort$_$sorti32$plongint$qword_$$_insertionsort$qword$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI32$PLONGINT$QWORD_$$_INSERTIONSORT$QWORD$QWORD
	.hidden NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI32$PLONGINT$QWORD_$$_INSERTIONSORT$QWORD$QWORD
	.type	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI32$PLONGINT$QWORD_$$_INSERTIONSORT$QWORD$QWORD,@function
NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI32$PLONGINT$QWORD_$$_INSERTIONSORT$QWORD$QWORD:
.Lc27:
# Var i located in register rax
# Var j located in register rcx
# Var tmp located in register r8d
# Var $parentfp located in register rdi
# Var aL located in register rsi
# Var aR located in register rdx
# [25] begin
# Var aR located in register rdx
# [26] for i := aL + 1 to aR do
	leaq	1(%rsi),%rax
	cmpq	%rdx,%rax
	jnbe	.Lj170
	movq	%rsi,%rax
	.p2align 4,,10
	.p2align 3
.Lj171:
	addq	$1,%rax
# [28] tmp := aData[i];
	movq	(%rdi),%r9
	movl	(%r9,%rax,4),%r8d
# [29] j := i;
	movq	%rax,%rcx
# [30] while (j > aL) and (aData[j - 1] > tmp) do
	jmp	.Lj175
	.p2align 4,,10
	.p2align 3
.Lj174:
	movq	(%rdi),%r10
# [32] aData[j] := aData[j - 1];
	movl	-4(%r10,%rcx,4),%r9d
	movl	%r9d,(%r10,%rcx,4)
# [33] Dec(j);
	subq	$1,%rcx
.Lj175:
	cmpq	%rcx,%rsi
	jnb	.Lj178
	movq	(%rdi),%r9
	cmpl	-4(%r9,%rcx,4),%r8d
	jl	.Lj174
.Lj178:
# [35] aData[j] := tmp;
	movq	(%rdi),%r9
	movl	%r8d,(%r9,%rcx,4)
	cmpq	%rax,%rdx
	jnbe	.Lj171
.Lj170:
.Lc28:
# [37] end;
	ret
.Lc26:

.section .text.n_nextpas.core.collections.arr.sort_$$_sorti64$pint64$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.ARR.SORT_$$_SORTI64$PINT64$QWORD
	.type	NEXTPAS.CORE.COLLECTIONS.ARR.SORT_$$_SORTI64$PINT64$QWORD,@function
NEXTPAS.CORE.COLLECTIONS.ARR.SORT_$$_SORTI64$PINT64$QWORD:
.Lc30:
# [nextpas.core.collections.arr.sort.inc]
# [175] begin
	pushq	%rax
.Lc31:
# Var aData located at rsp+0, size=OS_64
# Var tmp located in register rdx
	movq	%rdi,(%rsp)
# Var aCount located in register rsi
# [176] if aCount < 2 then Exit;
	cmpq	$2,%rsi
	jb	.Lj180
# [178] LEnd := aCount - 2;
	leaq	-2(%rsi),%rax
# Var LEnd located in register rax
# Var i located in register r8
# [179] i := 0;
	xorl	%r8d,%r8d
# [180] while (i <= LEnd) and (aData[i] = aData[i + 1]) do Inc(i);
	jmp	.Lj193
	.p2align 4,,10
	.p2align 3
.Lj192:
	addq	$1,%r8
.Lj193:
	cmpq	%r8,%rax
	jnae	.Lj180
	movq	(%rsp),%rdx
	movq	8(%rdx,%r8,8),%rcx
	cmpq	(%rdx,%r8,8),%rcx
	je	.Lj192
# [181] if i > LEnd then Exit;
	cmpq	%r8,%rax
	jb	.Lj180
	movq	(%rsp),%rcx
# [183] if aData[i] < aData[i + 1] then
	movq	8(%rcx,%r8,8),%rdx
	cmpq	(%rcx,%r8,8),%rdx
	jng	.Lj201
# [185] Inc(i);
	addq	$1,%r8
# [186] while (i <= LEnd) and (aData[i] <= aData[i + 1]) do Inc(i);
	jmp	.Lj203
	.p2align 4,,10
	.p2align 3
.Lj202:
	addq	$1,%r8
.Lj203:
	cmpq	%r8,%rax
	jnae	.Lj180
	movq	(%rsp),%rcx
	movq	8(%rcx,%r8,8),%rdx
	cmpq	(%rcx,%r8,8),%rdx
	jge	.Lj202
# [187] if i > LEnd then Exit;
	cmpq	%r8,%rax
	jb	.Lj180
	jmp	.Lj210
	.p2align 4,,10
	.p2align 3
.Lj201:
# [191] Inc(i);
	addq	$1,%r8
# [192] while (i <= LEnd) and (aData[i] >= aData[i + 1]) do Inc(i);
	jmp	.Lj212
	.p2align 4,,10
	.p2align 3
.Lj211:
	addq	$1,%r8
.Lj212:
	cmpq	%r8,%rax
	jnae	.Lj217
	movq	(%rsp),%rdx
	movq	8(%rdx,%r8,8),%rcx
	cmpq	(%rdx,%r8,8),%rcx
	jle	.Lj211
# [193] if i > LEnd then
	cmpq	%r8,%rax
	jnb	.Lj210
.Lj217:
# [195] i := 0; LEnd := aCount - 1;
	xorl	%r8d,%r8d
	leaq	-1(%rsi),%rax
# [196] while i < LEnd do
	cmpq	%r8,%rax
	jna	.Lj180
	.p2align 4,,10
	.p2align 3
.Lj221:
# [198] tmp := aData[i]; aData[i] := aData[LEnd]; aData[LEnd] := tmp;
	movq	(%rsp),%rcx
	movq	(%rcx,%r8,8),%rdx
	movq	(%rsp),%rdi
	movq	(%rdi,%rax,8),%rcx
	movq	%rcx,(%rdi,%r8,8)
	movq	(%rsp),%rcx
	movq	%rdx,(%rcx,%rax,8)
# [199] Inc(i); Dec(LEnd);
	addq	$1,%r8
	subq	$1,%rax
	cmpq	%r8,%rax
	ja	.Lj221
# [201] Exit;
	jmp	.Lj180
	.p2align 4,,10
	.p2align 3
.Lj210:
# Var LDepth located in register ecx
# [205] LDepth := 0;
	xorl	%ecx,%ecx
# Var LN located in register rax
# Var aCount located in register rsi
# [206] LN := aCount;
	movq	%rsi,%rax
# [207] while LN > 1 do begin LN := LN shr 1; Inc(LDepth); end;
	cmpq	$1,%rsi
	jna	.Lj225
	.p2align 4,,10
	.p2align 3
.Lj226:
	shrq	$1,%rax
	addl	$1,%ecx
	cmpq	$1,%rax
	ja	.Lj226
.Lj225:
# [208] LDepth := LDepth * 2;
	shll	$1,%ecx
# Var LDepth located in register ecx
# [210] IntroSort(0, aCount - 1, LDepth);
	leaq	-1(%rsi),%rdx
	movq	%rsp,%rdi
# Var LDepth located in register ecx
	xorl	%esi,%esi
	call	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI64$PINT64$QWORD_$$_INTROSORT$QWORD$QWORD$LONGINT
.Lj180:
# [211] end;
	popq	%rcx
.Lc32:
	ret
.Lc29:

.section .text.n_nextpas.core.collections.arr.sort$_$sorti64$pint64$qword_$$_introsort$qword$qword$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI64$PINT64$QWORD_$$_INTROSORT$QWORD$QWORD$LONGINT
	.hidden NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI64$PINT64$QWORD_$$_INTROSORT$QWORD$QWORD$LONGINT
	.type	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI64$PINT64$QWORD_$$_INTROSORT$QWORD$QWORD$LONGINT,@function
NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI64$PINT64$QWORD_$$_INTROSORT$QWORD$QWORD$LONGINT:
.Lc34:
# Temps allocated between rsp+0 and rsp+40
# [115] begin
	pushq	%rbx
.Lc35:
	pushq	%r12
.Lc36:
	pushq	%r13
.Lc37:
	pushq	%r14
.Lc38:
	pushq	%r15
.Lc39:
	leaq	-48(%rsp),%rsp
.Lc40:
# Var lt located in register r13
# Var gt located in register rbx
# Var i located in register r12
# Var LMid located in stack [rsp+8]
# Var pivot located in stack [rsp+16]
# Var tmp located in stack [rsp+32]
	movq	%rdi,%r14
# Var $parentfp located in register r14
	movq	%rsi,%r15
# Var aLeft located in register r15
	movq	%rdx,24(%rsp)
# Var aRight located in stack [rsp+24]
	movl	%ecx,%eax
	movq	%rax,(%rsp)
# Var aDepth located in stack [rsp+0]
# [116] while aLeft < aRight do
	cmpq	%r15,24(%rsp)
	jna	.Lj188
	.p2align 4,,10
	.p2align 3
.Lj231:
# [118] if aRight - aLeft < INSERTION_THRESHOLD then
	movq	24(%rsp),%rax
	subq	%r15,%rax
	cmpq	$24,%rax
	jnb	.Lj235
# [120] InsertionSort(aLeft, aRight);
	movq	24(%rsp),%rdi
	leaq	1(%r15),%rax
	cmpq	%rdi,%rax
	jnbe	.Lj188
	movq	%r15,%rcx
	.p2align 4,,10
	.p2align 3
.Lj238:
	addq	$1,%rcx
	movq	(%r14),%rax
	movq	(%rax,%rcx,8),%r8
	movq	%rcx,%rsi
	jmp	.Lj242
	.p2align 4,,10
	.p2align 3
.Lj241:
	movq	(%r14),%rdx
	movq	-8(%rdx,%rsi,8),%rax
	movq	%rax,(%rdx,%rsi,8)
	subq	$1,%rsi
.Lj242:
	cmpq	%rsi,%r15
	jnb	.Lj245
	movq	(%r14),%rax
	cmpq	-8(%rax,%rsi,8),%r8
	jl	.Lj241
.Lj245:
	movq	(%r14),%rax
	movq	%r8,(%rax,%rsi,8)
	cmpq	%rcx,%rdi
	jnbe	.Lj238
# [121] Exit;
	jmp	.Lj188
	.p2align 4,,10
	.p2align 3
.Lj235:
# [124] if aDepth = 0 then
	cmpl	$0,(%rsp)
	jne	.Lj248
# [126] HeapSort(aLeft, aRight);
	movq	%r14,%rdi
	movq	24(%rsp),%rdx
	movq	%r15,%rsi
	call	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI64$PINT64$QWORD_$$_HEAPSORT$QWORD$QWORD
# [127] Exit;
	jmp	.Lj188
	.p2align 4,,10
	.p2align 3
.Lj248:
# [129] Dec(aDepth);
	movl	(%rsp),%eax
	subl	$1,%eax
	movq	%rax,(%rsp)
# [131] LMid := aLeft + (aRight - aLeft) div 2;
	movq	24(%rsp),%rax
	subq	%r15,%rax
	shrq	$1,%rax
	addq	%r15,%rax
	movq	%rax,8(%rsp)
	movq	(%r14),%rcx
# [132] if aData[aLeft] > aData[LMid] then
	movq	(%rcx,%r15,8),%rdx
	movq	8(%rsp),%rax
	cmpq	(%rcx,%rax,8),%rdx
	jng	.Lj250
# [133] begin tmp := aData[aLeft]; aData[aLeft] := aData[LMid]; aData[LMid] := tmp; end;
	movq	(%r14),%rax
	movq	(%rax,%r15,8),%rdx
	movq	%rdx,32(%rsp)
	movq	(%r14),%rcx
	movq	8(%rsp),%rdx
	movq	(%rcx,%rdx,8),%rax
	movq	%rax,(%rcx,%r15,8)
	movq	(%r14),%rcx
	movq	32(%rsp),%rdx
	movq	8(%rsp),%rax
	movq	%rdx,(%rcx,%rax,8)
.Lj250:
	movq	(%r14),%rdx
# [134] if aData[LMid] > aData[aRight] then
	movq	8(%rsp),%rcx
	movq	(%rdx,%rcx,8),%rax
	movq	24(%rsp),%rcx
	cmpq	(%rdx,%rcx,8),%rax
	jng	.Lj252
# [135] begin tmp := aData[LMid]; aData[LMid] := aData[aRight]; aData[aRight] := tmp; end;
	movq	(%r14),%rax
	movq	8(%rsp),%rdx
	movq	(%rax,%rdx,8),%rdx
	movq	%rdx,32(%rsp)
	movq	(%r14),%rdx
	movq	24(%rsp),%rcx
	movq	(%rdx,%rcx,8),%rax
	movq	8(%rsp),%rcx
	movq	%rax,(%rdx,%rcx,8)
	movq	(%r14),%rcx
	movq	32(%rsp),%rdx
	movq	24(%rsp),%rax
	movq	%rdx,(%rcx,%rax,8)
.Lj252:
	movq	(%r14),%rax
# [136] if aData[aLeft] > aData[LMid] then
	movq	(%rax,%r15,8),%rcx
	movq	8(%rsp),%rdx
	cmpq	(%rax,%rdx,8),%rcx
	jng	.Lj254
# [137] begin tmp := aData[aLeft]; aData[aLeft] := aData[LMid]; aData[LMid] := tmp; end;
	movq	(%r14),%rdx
	movq	(%rdx,%r15,8),%rax
	movq	%rax,32(%rsp)
	movq	(%r14),%rax
	movq	8(%rsp),%rcx
	movq	(%rax,%rcx,8),%rdx
	movq	%rdx,(%rax,%r15,8)
	movq	(%r14),%rax
	movq	32(%rsp),%rcx
	movq	8(%rsp),%rdx
	movq	%rcx,(%rax,%rdx,8)
.Lj254:
# [138] pivot := aData[LMid];
	movq	(%r14),%rax
	movq	8(%rsp),%rdx
	movq	(%rax,%rdx,8),%rdx
	movq	%rdx,16(%rsp)
# [140] lt := aLeft;
	movq	%r15,%r13
# [141] gt := aRight;
	movq	24(%rsp),%rbx
# [142] i := aLeft;
	movq	%r15,%r12
# [143] while i <= gt do
	cmpq	%r15,%rbx
	jnae	.Lj256
	.p2align 4,,10
	.p2align 3
.Lj257:
# [145] if aData[i] < pivot then
	movq	(%r14),%rax
	movq	16(%rsp),%rdx
	cmpq	(%rax,%r12,8),%rdx
	jng	.Lj261
# [147] tmp := aData[i]; aData[i] := aData[lt]; aData[lt] := tmp;
	movq	(%r14),%rax
	movq	(%rax,%r12,8),%rdx
	movq	%rdx,32(%rsp)
	movq	(%r14),%rdx
	movq	(%rdx,%r13,8),%rax
	movq	%rax,(%rdx,%r12,8)
	movq	(%r14),%rax
	movq	32(%rsp),%rdx
	movq	%rdx,(%rax,%r13,8)
# [148] Inc(lt); Inc(i);
	addq	$1,%r13
	addq	$1,%r12
	jmp	.Lj262
	.p2align 4,,10
	.p2align 3
.Lj261:
# [150] else if aData[i] > pivot then
	movq	(%r14),%rax
	movq	16(%rsp),%rdx
	cmpq	(%rax,%r12,8),%rdx
	jnl	.Lj264
# [152] tmp := aData[i]; aData[i] := aData[gt]; aData[gt] := tmp;
	movq	(%r14),%rax
	movq	(%rax,%r12,8),%rdx
	movq	%rdx,32(%rsp)
	movq	(%r14),%rax
	movq	(%rax,%rbx,8),%rdx
	movq	%rdx,(%rax,%r12,8)
	movq	(%r14),%rax
	movq	32(%rsp),%rdx
	movq	%rdx,(%rax,%rbx,8)
# [153] Dec(gt);
	subq	$1,%rbx
	jmp	.Lj262
	.p2align 4,,10
	.p2align 3
.Lj264:
# [156] Inc(i);
	addq	$1,%r12
.Lj262:
	cmpq	%r12,%rbx
	jae	.Lj257
.Lj256:
# [159] if (lt > aLeft) and TryPartialInsertionSort(aLeft, lt - 1) then
	cmpq	%r13,%r15
	jnb	.Lj267
	xorl	%r9d,%r9d
	leaq	-1(%r13),%r10
	leaq	1(%r15),%rax
	cmpq	%r10,%rax
	jnbe	.Lj271
	movq	%r15,%rdi
	.p2align 4,,10
	.p2align 3
.Lj272:
	addq	$1,%rdi
	movq	(%r14),%rax
	movq	(%rax,%rdi,8),%rcx
	movq	%rdi,%r8
	jmp	.Lj276
	.p2align 4,,10
	.p2align 3
.Lj275:
	movq	(%r14),%rax
	movq	-8(%rax,%r8,8),%rdx
	movq	%rdx,(%rax,%r8,8)
	subq	$1,%r8
	addl	$1,%r9d
	cmpl	$12,%r9d
	jng	.Lj276
	xorb	%sil,%sil
	jmp	.Lj269
	.p2align 4,,10
	.p2align 3
.Lj276:
	cmpq	%r8,%r15
	jnb	.Lj281
	movq	(%r14),%rax
	cmpq	-8(%rax,%r8,8),%rcx
	jl	.Lj275
.Lj281:
	movq	(%r14),%rax
	movq	%rcx,(%rax,%r8,8)
	cmpq	%rdi,%r10
	jnbe	.Lj272
.Lj271:
	movb	$1,%sil
.Lj269:
	testb	%sil,%sil
	jne	.Lj268
.Lj267:
# [161] else if lt > aLeft + 1 then
	leaq	1(%r15),%rax
	cmpq	%r13,%rax
	jnb	.Lj268
# [162] IntroSort(aLeft, lt - 1, aDepth);
	leaq	-1(%r13),%rdx
	movq	%r14,%rdi
	movl	(%rsp),%ecx
	movq	%r15,%rsi
	call	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI64$PINT64$QWORD_$$_INTROSORT$QWORD$QWORD$LONGINT
.Lj268:
# [164] if (gt < aRight) and TryPartialInsertionSort(gt + 1, aRight) then
	cmpq	%rbx,24(%rsp)
	jna	.Lj286
	xorl	%r9d,%r9d
	movq	24(%rsp),%r10
	leaq	2(%rbx),%rax
	cmpq	%r10,%rax
	jnbe	.Lj290
	leaq	1(%rbx),%rdi
	.p2align 4,,10
	.p2align 3
.Lj291:
	addq	$1,%rdi
	movq	(%r14),%rax
	movq	(%rax,%rdi,8),%rcx
	movq	%rdi,%r8
	jmp	.Lj295
	.p2align 4,,10
	.p2align 3
.Lj294:
	movq	(%r14),%rdx
	movq	-8(%rdx,%r8,8),%rax
	movq	%rax,(%rdx,%r8,8)
	subq	$1,%r8
	addl	$1,%r9d
	cmpl	$12,%r9d
	jng	.Lj295
	xorb	%sil,%sil
	jmp	.Lj288
	.p2align 4,,10
	.p2align 3
.Lj295:
	leaq	1(%rbx),%rax
	cmpq	%r8,%rax
	jnb	.Lj300
	movq	(%r14),%rax
	cmpq	-8(%rax,%r8,8),%rcx
	jl	.Lj294
.Lj300:
	movq	(%r14),%rax
	movq	%rcx,(%rax,%r8,8)
	cmpq	%rdi,%r10
	jnbe	.Lj291
.Lj290:
	movb	$1,%sil
.Lj288:
	testb	%sil,%sil
	jne	.Lj188
	.p2align 4,,10
	.p2align 3
.Lj286:
# [167] aLeft := gt + 1;
	leaq	1(%rbx),%r15
	cmpq	%r15,24(%rsp)
	ja	.Lj231
.Lj188:
# [169] end;
	leaq	48(%rsp),%rsp
	popq	%r15
.Lc41:
	popq	%r14
.Lc42:
	popq	%r13
.Lc43:
	popq	%r12
.Lc44:
	popq	%rbx
.Lc45:
	ret
.Lc33:
.Le2:
	.size	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI64$PINT64$QWORD_$$_INTROSORT$QWORD$QWORD$LONGINT, .Le2 - NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI64$PINT64$QWORD_$$_INTROSORT$QWORD$QWORD$LONGINT

.section .text.n_nextpas.core.collections.arr.sort$_$sorti64$pint64$qword_$$_heapsort$qword$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI64$PINT64$QWORD_$$_HEAPSORT$QWORD$QWORD
	.hidden NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI64$PINT64$QWORD_$$_HEAPSORT$QWORD$QWORD
	.type	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI64$PINT64$QWORD_$$_HEAPSORT$QWORD$QWORD,@function
NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI64$PINT64$QWORD_$$_HEAPSORT$QWORD$QWORD:
.Lc47:
# [66] begin
	pushq	%rbx
.Lc48:
# Var idx located in register rcx
# Var child located in register r9
# Var tmp located in register r10
# Var $parentfp located in register rdi
# Var aL located in register rsi
# Var aR located in register rdx
# [67] LSize := aR - aL + 1;
	subq	%rsi,%rdx
	leaq	1(%rdx),%rax
# Var LSize located in register rax
# [68] i := LSize div 2;
	movq	%rax,%rdx
	shrq	$1,%rdx
# Var i located in register rdx
	.p2align 4,,10
	.p2align 3
.Lj303:
# [72] idx := i;
	leaq	-1(%rdx),%rcx
# [71] Dec(i);
	subq	$1,%rdx
# [73] tmp := aData[aL + idx];
	movq	(%rdi),%r11
	leaq	(%rsi,%rdx),%r8
	movq	(%r11,%r8,8),%r10
	.p2align 4,,10
	.p2align 3
.Lj306:
# [76] child := 2 * idx + 1;
	leaq	1(%rcx,%rcx,1),%r9
# [77] if child >= LSize then Break;
	cmpq	%r9,%rax
	jbe	.Lj308
# [78] if (child + 1 < LSize) and (aData[aL + child] < aData[aL + child + 1]) then
	leaq	1(%r9),%r8
	cmpq	%rax,%r8
	jnb	.Lj312
	movq	(%rdi),%r11
	leaq	(%rsi,%r9),%r8
	movq	8(%r11,%r8,8),%rbx
	cmpq	(%r11,%r8,8),%rbx
	setg	%r8b
# [79] Inc(child);
	movzbl	%r8b,%r8d
	addq	%r8,%r9
.Lj312:
# [80] if tmp >= aData[aL + child] then Break;
	movq	(%rdi),%r11
	leaq	(%rsi,%r9),%r8
	cmpq	(%r11,%r8,8),%r10
	jge	.Lj308
	movq	(%rdi),%r8
# [81] aData[aL + idx] := aData[aL + child];
	leaq	(%rsi,%rcx),%r11
	leaq	(%rsi,%r9),%rbx
	movq	(%r8,%rbx,8),%rbx
	movq	%rbx,(%r8,%r11,8)
# [82] idx := child;
	movq	%r9,%rcx
# [74] while True do
	jmp	.Lj306
.Lj308:
# [84] aData[aL + idx] := tmp;
	movq	(%rdi),%r8
	leaq	(%rsi,%rcx),%r11
	movq	%r10,(%r8,%r11,8)
# [85] if i = 0 then Break;
	testq	%rdx,%rdx
	jne	.Lj303
# [87] i := LSize - 1;
	leaq	-1(%rax),%rdx
# Var i located in register rdx
# [88] while i > 0 do
	testq	%rdx,%rdx
	je	.Lj319
	.p2align 4,,10
	.p2align 3
.Lj320:
# [90] tmp := aData[aL + i];
	movq	(%rdi),%r8
	leaq	(%rsi,%rdx),%r11
	movq	(%r8,%r11,8),%r10
	movq	(%rdi),%r11
# [91] aData[aL + i] := aData[aL];
	leaq	(%rsi,%rdx),%rbx
	movq	(%r11,%rsi,8),%r8
	movq	%r8,(%r11,%rbx,8)
# [92] aData[aL] := tmp;
	movq	(%rdi),%r8
	movq	%r10,(%r8,%rsi,8)
# [93] Dec(LSize);
	subq	$1,%rax
# [94] idx := 0;
	xorl	%ecx,%ecx
# [95] tmp := aData[aL];
	movq	(%rdi),%r8
	movq	(%r8,%rsi,8),%r10
	.p2align 4,,10
	.p2align 3
.Lj323:
# [98] child := 2 * idx + 1;
	leaq	1(%rcx,%rcx,1),%r9
# [99] if child >= LSize then Break;
	cmpq	%r9,%rax
	jbe	.Lj325
# [100] if (child + 1 < LSize) and (aData[aL + child] < aData[aL + child + 1]) then
	leaq	1(%r9),%r8
	cmpq	%rax,%r8
	jnb	.Lj329
	movq	(%rdi),%r11
	leaq	(%rsi,%r9),%r8
	movq	8(%r11,%r8,8),%rbx
	cmpq	(%r11,%r8,8),%rbx
	setg	%r8b
# [101] Inc(child);
	movzbl	%r8b,%r8d
	addq	%r8,%r9
.Lj329:
# [102] if tmp >= aData[aL + child] then Break;
	movq	(%rdi),%r11
	leaq	(%rsi,%r9),%r8
	cmpq	(%r11,%r8,8),%r10
	jge	.Lj325
	movq	(%rdi),%r11
# [103] aData[aL + idx] := aData[aL + child];
	leaq	(%rsi,%rcx),%r8
	leaq	(%rsi,%r9),%rbx
	movq	(%r11,%rbx,8),%rbx
	movq	%rbx,(%r11,%r8,8)
# [104] idx := child;
	movq	%r9,%rcx
# [96] while True do
	jmp	.Lj323
.Lj325:
# [106] aData[aL + idx] := tmp;
	movq	(%rdi),%r8
	leaq	(%rsi,%rcx),%r11
	movq	%r10,(%r8,%r11,8)
# [107] Dec(i);
	subq	$1,%rdx
	jne	.Lj320
.Lj319:
# [109] end;
	popq	%rbx
.Lc49:
	ret
.Lc46:
.Le3:
	.size	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI64$PINT64$QWORD_$$_HEAPSORT$QWORD$QWORD, .Le3 - NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI64$PINT64$QWORD_$$_HEAPSORT$QWORD$QWORD

.section .text.n_nextpas.core.collections.arr.sort$_$sorti64$pint64$qword_$$_trypartialinsertionsort$hhhlmht7g06j,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI64$PINT64$QWORD_$$_TRYPARTIALINSERTIONSORT$hhHLmht7G06J
	.hidden NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI64$PINT64$QWORD_$$_TRYPARTIALINSERTIONSORT$hhHLmht7G06J
	.type	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI64$PINT64$QWORD_$$_TRYPARTIALINSERTIONSORT$hhHLmht7G06J,@function
NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI64$PINT64$QWORD_$$_TRYPARTIALINSERTIONSORT$hhHLmht7G06J:
.Lc51:
# [44] begin
	pushq	%rbx
.Lc52:
# Var $result located in register al
# Var i located in register rcx
# Var j located in register r8
# Var tmp located in register r9
# Var $parentfp located in register rdi
# Var aL located in register rsi
# Var aR located in register rdx
# Var LMoves located in register ebx
# [45] LMoves := 0;
	xorl	%ebx,%ebx
# Var aR located in register rdx
# [46] for i := aL + 1 to aR do
	leaq	1(%rsi),%rax
	cmpq	%rdx,%rax
	jnbe	.Lj334
	movq	%rsi,%rcx
	.p2align 4,,10
	.p2align 3
.Lj335:
	addq	$1,%rcx
# [48] tmp := aData[i];
	movq	(%rdi),%r10
	movq	(%r10,%rcx,8),%r9
# [49] j := i;
	movq	%rcx,%r8
# [50] while (j > aL) and (aData[j - 1] > tmp) do
	jmp	.Lj339
	.p2align 4,,10
	.p2align 3
.Lj338:
	movq	(%rdi),%r10
# [52] aData[j] := aData[j - 1];
	movq	-8(%r10,%r8,8),%r11
	movq	%r11,(%r10,%r8,8)
# [53] Dec(j);
	subq	$1,%r8
# [54] Inc(LMoves);
	addl	$1,%ebx
# [55] if LMoves > PARTIAL_INSERTION_LIMIT then Exit(False);
	cmpl	$12,%ebx
	jng	.Lj339
	xorb	%al,%al
	jmp	.Lj184
	.p2align 4,,10
	.p2align 3
.Lj339:
	cmpq	%r8,%rsi
	jnb	.Lj344
	movq	(%rdi),%r10
	cmpq	-8(%r10,%r8,8),%r9
	jl	.Lj338
.Lj344:
# [57] aData[j] := tmp;
	movq	(%rdi),%r10
	movq	%r9,(%r10,%r8,8)
	cmpq	%rcx,%rdx
	jnbe	.Lj335
.Lj334:
# [59] Result := True;
	movb	$1,%al
.Lj184:
# [60] end;
	popq	%rbx
.Lc53:
	ret
.Lc50:

.section .text.n_nextpas.core.collections.arr.sort$_$sorti64$pint64$qword_$$_insertionsort$qword$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI64$PINT64$QWORD_$$_INSERTIONSORT$QWORD$QWORD
	.hidden NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI64$PINT64$QWORD_$$_INSERTIONSORT$QWORD$QWORD
	.type	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI64$PINT64$QWORD_$$_INSERTIONSORT$QWORD$QWORD,@function
NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTI64$PINT64$QWORD_$$_INSERTIONSORT$QWORD$QWORD:
.Lc55:
# Var i located in register rax
# Var j located in register rcx
# Var tmp located in register r8
# Var $parentfp located in register rdi
# Var aL located in register rsi
# Var aR located in register rdx
# [25] begin
# Var aR located in register rdx
# [26] for i := aL + 1 to aR do
	leaq	1(%rsi),%rax
	cmpq	%rdx,%rax
	jnbe	.Lj347
	movq	%rsi,%rax
	.p2align 4,,10
	.p2align 3
.Lj348:
	addq	$1,%rax
# [28] tmp := aData[i];
	movq	(%rdi),%r9
	movq	(%r9,%rax,8),%r8
# [29] j := i;
	movq	%rax,%rcx
# [30] while (j > aL) and (aData[j - 1] > tmp) do
	jmp	.Lj352
	.p2align 4,,10
	.p2align 3
.Lj351:
	movq	(%rdi),%r10
# [32] aData[j] := aData[j - 1];
	movq	-8(%r10,%rcx,8),%r9
	movq	%r9,(%r10,%rcx,8)
# [33] Dec(j);
	subq	$1,%rcx
.Lj352:
	cmpq	%rcx,%rsi
	jnb	.Lj355
	movq	(%rdi),%r9
	cmpq	-8(%r9,%rcx,8),%r8
	jl	.Lj351
.Lj355:
# [35] aData[j] := tmp;
	movq	(%rdi),%r9
	movq	%r8,(%r9,%rcx,8)
	cmpq	%rax,%rdx
	jnbe	.Lj348
.Lj347:
.Lc56:
# [37] end;
	ret
.Lc54:

.section .text.n_nextpas.core.collections.arr.sort_$$_sortu32$pdword$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.ARR.SORT_$$_SORTU32$PDWORD$QWORD
	.type	NEXTPAS.CORE.COLLECTIONS.ARR.SORT_$$_SORTU32$PDWORD$QWORD,@function
NEXTPAS.CORE.COLLECTIONS.ARR.SORT_$$_SORTU32$PDWORD$QWORD:
.Lc58:
# [nextpas.core.collections.arr.sort.inc]
# [175] begin
	pushq	%rax
.Lc59:
# Var aData located at rsp+0, size=OS_64
# Var tmp located in register edx
	movq	%rdi,(%rsp)
# Var aCount located in register rsi
# [176] if aCount < 2 then Exit;
	cmpq	$2,%rsi
	jb	.Lj357
# [178] LEnd := aCount - 2;
	leaq	-2(%rsi),%rax
# Var LEnd located in register rax
# Var i located in register r8
# [179] i := 0;
	xorl	%r8d,%r8d
# [180] while (i <= LEnd) and (aData[i] = aData[i + 1]) do Inc(i);
	jmp	.Lj370
	.p2align 4,,10
	.p2align 3
.Lj369:
	addq	$1,%r8
.Lj370:
	cmpq	%r8,%rax
	jnae	.Lj357
	movq	(%rsp),%rdx
	movl	4(%rdx,%r8,4),%ecx
	cmpl	(%rdx,%r8,4),%ecx
	je	.Lj369
# [181] if i > LEnd then Exit;
	cmpq	%r8,%rax
	jb	.Lj357
	movq	(%rsp),%rcx
# [183] if aData[i] < aData[i + 1] then
	movl	4(%rcx,%r8,4),%edx
	cmpl	(%rcx,%r8,4),%edx
	jna	.Lj378
# [185] Inc(i);
	addq	$1,%r8
# [186] while (i <= LEnd) and (aData[i] <= aData[i + 1]) do Inc(i);
	jmp	.Lj380
	.p2align 4,,10
	.p2align 3
.Lj379:
	addq	$1,%r8
.Lj380:
	cmpq	%r8,%rax
	jnae	.Lj357
	movq	(%rsp),%rcx
	movl	4(%rcx,%r8,4),%edx
	cmpl	(%rcx,%r8,4),%edx
	jae	.Lj379
# [187] if i > LEnd then Exit;
	cmpq	%r8,%rax
	jb	.Lj357
	jmp	.Lj387
	.p2align 4,,10
	.p2align 3
.Lj378:
# [191] Inc(i);
	addq	$1,%r8
# [192] while (i <= LEnd) and (aData[i] >= aData[i + 1]) do Inc(i);
	jmp	.Lj389
	.p2align 4,,10
	.p2align 3
.Lj388:
	addq	$1,%r8
.Lj389:
	cmpq	%r8,%rax
	jnae	.Lj394
	movq	(%rsp),%rdx
	movl	4(%rdx,%r8,4),%ecx
	cmpl	(%rdx,%r8,4),%ecx
	jbe	.Lj388
# [193] if i > LEnd then
	cmpq	%r8,%rax
	jnb	.Lj387
.Lj394:
# [195] i := 0; LEnd := aCount - 1;
	xorl	%r8d,%r8d
	leaq	-1(%rsi),%rax
# [196] while i < LEnd do
	cmpq	%r8,%rax
	jna	.Lj357
	.p2align 4,,10
	.p2align 3
.Lj398:
# [198] tmp := aData[i]; aData[i] := aData[LEnd]; aData[LEnd] := tmp;
	movq	(%rsp),%rcx
	movl	(%rcx,%r8,4),%edx
	movq	(%rsp),%rdi
	movl	(%rdi,%rax,4),%ecx
	movl	%ecx,(%rdi,%r8,4)
	movq	(%rsp),%rcx
	movl	%edx,(%rcx,%rax,4)
# [199] Inc(i); Dec(LEnd);
	addq	$1,%r8
	subq	$1,%rax
	cmpq	%r8,%rax
	ja	.Lj398
# [201] Exit;
	jmp	.Lj357
	.p2align 4,,10
	.p2align 3
.Lj387:
# Var LDepth located in register ecx
# [205] LDepth := 0;
	xorl	%ecx,%ecx
# Var LN located in register rax
# Var aCount located in register rsi
# [206] LN := aCount;
	movq	%rsi,%rax
# [207] while LN > 1 do begin LN := LN shr 1; Inc(LDepth); end;
	cmpq	$1,%rsi
	jna	.Lj402
	.p2align 4,,10
	.p2align 3
.Lj403:
	shrq	$1,%rax
	addl	$1,%ecx
	cmpq	$1,%rax
	ja	.Lj403
.Lj402:
# [208] LDepth := LDepth * 2;
	shll	$1,%ecx
# Var LDepth located in register ecx
# [210] IntroSort(0, aCount - 1, LDepth);
	leaq	-1(%rsi),%rdx
	movq	%rsp,%rdi
# Var LDepth located in register ecx
	xorl	%esi,%esi
	call	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU32$PDWORD$QWORD_$$_INTROSORT$QWORD$QWORD$LONGINT
.Lj357:
# [211] end;
	popq	%rcx
.Lc60:
	ret
.Lc57:

.section .text.n_nextpas.core.collections.arr.sort$_$sortu32$pdword$qword_$$_introsort$qword$qword$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU32$PDWORD$QWORD_$$_INTROSORT$QWORD$QWORD$LONGINT
	.hidden NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU32$PDWORD$QWORD_$$_INTROSORT$QWORD$QWORD$LONGINT
	.type	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU32$PDWORD$QWORD_$$_INTROSORT$QWORD$QWORD$LONGINT,@function
NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU32$PDWORD$QWORD_$$_INTROSORT$QWORD$QWORD$LONGINT:
.Lc62:
# Temps allocated between rsp+0 and rsp+40
# [115] begin
	pushq	%rbx
.Lc63:
	pushq	%r12
.Lc64:
	pushq	%r13
.Lc65:
	pushq	%r14
.Lc66:
	pushq	%r15
.Lc67:
	leaq	-48(%rsp),%rsp
.Lc68:
# Var lt located in register r13
# Var gt located in register rbx
# Var i located in register r12
# Var LMid located in stack [rsp+8]
# Var pivot located in stack [rsp+16]
# Var tmp located in stack [rsp+32]
	movq	%rdi,%r14
# Var $parentfp located in register r14
	movq	%rsi,%r15
# Var aLeft located in register r15
	movq	%rdx,24(%rsp)
# Var aRight located in stack [rsp+24]
	movl	%ecx,%eax
	movq	%rax,(%rsp)
# Var aDepth located in stack [rsp+0]
# [116] while aLeft < aRight do
	cmpq	%r15,24(%rsp)
	jna	.Lj365
	.p2align 4,,10
	.p2align 3
.Lj408:
# [118] if aRight - aLeft < INSERTION_THRESHOLD then
	movq	24(%rsp),%rax
	subq	%r15,%rax
	cmpq	$24,%rax
	jnb	.Lj412
# [120] InsertionSort(aLeft, aRight);
	movq	24(%rsp),%rdi
	leaq	1(%r15),%rax
	cmpq	%rdi,%rax
	jnbe	.Lj365
	movq	%r15,%rcx
	.p2align 4,,10
	.p2align 3
.Lj415:
	addq	$1,%rcx
	movq	(%r14),%rax
	movl	(%rax,%rcx,4),%r8d
	movq	%rcx,%rsi
	jmp	.Lj419
	.p2align 4,,10
	.p2align 3
.Lj418:
	movq	(%r14),%rdx
	movl	-4(%rdx,%rsi,4),%eax
	movl	%eax,(%rdx,%rsi,4)
	subq	$1,%rsi
.Lj419:
	cmpq	%rsi,%r15
	jnb	.Lj422
	movq	(%r14),%rax
	cmpl	-4(%rax,%rsi,4),%r8d
	jb	.Lj418
.Lj422:
	movq	(%r14),%rax
	movl	%r8d,(%rax,%rsi,4)
	cmpq	%rcx,%rdi
	jnbe	.Lj415
# [121] Exit;
	jmp	.Lj365
	.p2align 4,,10
	.p2align 3
.Lj412:
# [124] if aDepth = 0 then
	cmpl	$0,(%rsp)
	jne	.Lj425
# [126] HeapSort(aLeft, aRight);
	movq	%r14,%rdi
	movq	24(%rsp),%rdx
	movq	%r15,%rsi
	call	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU32$PDWORD$QWORD_$$_HEAPSORT$QWORD$QWORD
# [127] Exit;
	jmp	.Lj365
	.p2align 4,,10
	.p2align 3
.Lj425:
# [129] Dec(aDepth);
	movl	(%rsp),%eax
	subl	$1,%eax
	movq	%rax,(%rsp)
# [131] LMid := aLeft + (aRight - aLeft) div 2;
	movq	24(%rsp),%rax
	subq	%r15,%rax
	shrq	$1,%rax
	addq	%r15,%rax
	movq	%rax,8(%rsp)
	movq	(%r14),%rcx
# [132] if aData[aLeft] > aData[LMid] then
	movl	(%rcx,%r15,4),%edx
	movq	8(%rsp),%rax
	cmpl	(%rcx,%rax,4),%edx
	jna	.Lj427
# [133] begin tmp := aData[aLeft]; aData[aLeft] := aData[LMid]; aData[LMid] := tmp; end;
	movq	(%r14),%rax
	movl	(%rax,%r15,4),%edx
	movq	%rdx,32(%rsp)
	movq	(%r14),%rcx
	movq	8(%rsp),%rdx
	movl	(%rcx,%rdx,4),%eax
	movl	%eax,(%rcx,%r15,4)
	movq	(%r14),%rcx
	movl	32(%rsp),%edx
	movq	8(%rsp),%rax
	movl	%edx,(%rcx,%rax,4)
.Lj427:
	movq	(%r14),%rdx
# [134] if aData[LMid] > aData[aRight] then
	movq	8(%rsp),%rcx
	movl	(%rdx,%rcx,4),%eax
	movq	24(%rsp),%rcx
	cmpl	(%rdx,%rcx,4),%eax
	jna	.Lj429
# [135] begin tmp := aData[LMid]; aData[LMid] := aData[aRight]; aData[aRight] := tmp; end;
	movq	(%r14),%rax
	movq	8(%rsp),%rdx
	movl	(%rax,%rdx,4),%edx
	movq	%rdx,32(%rsp)
	movq	(%r14),%rdx
	movq	24(%rsp),%rcx
	movl	(%rdx,%rcx,4),%eax
	movq	8(%rsp),%rcx
	movl	%eax,(%rdx,%rcx,4)
	movq	(%r14),%rcx
	movl	32(%rsp),%edx
	movq	24(%rsp),%rax
	movl	%edx,(%rcx,%rax,4)
.Lj429:
	movq	(%r14),%rax
# [136] if aData[aLeft] > aData[LMid] then
	movl	(%rax,%r15,4),%ecx
	movq	8(%rsp),%rdx
	cmpl	(%rax,%rdx,4),%ecx
	jna	.Lj431
# [137] begin tmp := aData[aLeft]; aData[aLeft] := aData[LMid]; aData[LMid] := tmp; end;
	movq	(%r14),%rdx
	movl	(%rdx,%r15,4),%eax
	movq	%rax,32(%rsp)
	movq	(%r14),%rax
	movq	8(%rsp),%rcx
	movl	(%rax,%rcx,4),%edx
	movl	%edx,(%rax,%r15,4)
	movq	(%r14),%rax
	movl	32(%rsp),%ecx
	movq	8(%rsp),%rdx
	movl	%ecx,(%rax,%rdx,4)
.Lj431:
# [138] pivot := aData[LMid];
	movq	(%r14),%rax
	movq	8(%rsp),%rdx
	movl	(%rax,%rdx,4),%edx
	movq	%rdx,16(%rsp)
# [140] lt := aLeft;
	movq	%r15,%r13
# [141] gt := aRight;
	movq	24(%rsp),%rbx
# [142] i := aLeft;
	movq	%r15,%r12
# [143] while i <= gt do
	cmpq	%r15,%rbx
	jnae	.Lj433
	.p2align 4,,10
	.p2align 3
.Lj434:
# [145] if aData[i] < pivot then
	movq	(%r14),%rax
	movl	16(%rsp),%edx
	cmpl	(%rax,%r12,4),%edx
	jna	.Lj438
# [147] tmp := aData[i]; aData[i] := aData[lt]; aData[lt] := tmp;
	movq	(%r14),%rax
	movl	(%rax,%r12,4),%edx
	movq	%rdx,32(%rsp)
	movq	(%r14),%rdx
	movl	(%rdx,%r13,4),%eax
	movl	%eax,(%rdx,%r12,4)
	movq	(%r14),%rax
	movl	32(%rsp),%edx
	movl	%edx,(%rax,%r13,4)
# [148] Inc(lt); Inc(i);
	addq	$1,%r13
	addq	$1,%r12
	jmp	.Lj439
	.p2align 4,,10
	.p2align 3
.Lj438:
# [150] else if aData[i] > pivot then
	movq	(%r14),%rax
	movl	16(%rsp),%edx
	cmpl	(%rax,%r12,4),%edx
	jnb	.Lj441
# [152] tmp := aData[i]; aData[i] := aData[gt]; aData[gt] := tmp;
	movq	(%r14),%rax
	movl	(%rax,%r12,4),%edx
	movq	%rdx,32(%rsp)
	movq	(%r14),%rax
	movl	(%rax,%rbx,4),%edx
	movl	%edx,(%rax,%r12,4)
	movq	(%r14),%rax
	movl	32(%rsp),%edx
	movl	%edx,(%rax,%rbx,4)
# [153] Dec(gt);
	subq	$1,%rbx
	jmp	.Lj439
	.p2align 4,,10
	.p2align 3
.Lj441:
# [156] Inc(i);
	addq	$1,%r12
.Lj439:
	cmpq	%r12,%rbx
	jae	.Lj434
.Lj433:
# [159] if (lt > aLeft) and TryPartialInsertionSort(aLeft, lt - 1) then
	cmpq	%r13,%r15
	jnb	.Lj444
	xorl	%r9d,%r9d
	leaq	-1(%r13),%r10
	leaq	1(%r15),%rax
	cmpq	%r10,%rax
	jnbe	.Lj448
	movq	%r15,%rdi
	.p2align 4,,10
	.p2align 3
.Lj449:
	addq	$1,%rdi
	movq	(%r14),%rax
	movl	(%rax,%rdi,4),%ecx
	movq	%rdi,%r8
	jmp	.Lj453
	.p2align 4,,10
	.p2align 3
.Lj452:
	movq	(%r14),%rax
	movl	-4(%rax,%r8,4),%edx
	movl	%edx,(%rax,%r8,4)
	subq	$1,%r8
	addl	$1,%r9d
	cmpl	$12,%r9d
	jng	.Lj453
	xorb	%sil,%sil
	jmp	.Lj446
	.p2align 4,,10
	.p2align 3
.Lj453:
	cmpq	%r8,%r15
	jnb	.Lj458
	movq	(%r14),%rax
	cmpl	-4(%rax,%r8,4),%ecx
	jb	.Lj452
.Lj458:
	movq	(%r14),%rax
	movl	%ecx,(%rax,%r8,4)
	cmpq	%rdi,%r10
	jnbe	.Lj449
.Lj448:
	movb	$1,%sil
.Lj446:
	testb	%sil,%sil
	jne	.Lj445
.Lj444:
# [161] else if lt > aLeft + 1 then
	leaq	1(%r15),%rax
	cmpq	%r13,%rax
	jnb	.Lj445
# [162] IntroSort(aLeft, lt - 1, aDepth);
	leaq	-1(%r13),%rdx
	movq	%r14,%rdi
	movl	(%rsp),%ecx
	movq	%r15,%rsi
	call	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU32$PDWORD$QWORD_$$_INTROSORT$QWORD$QWORD$LONGINT
.Lj445:
# [164] if (gt < aRight) and TryPartialInsertionSort(gt + 1, aRight) then
	cmpq	%rbx,24(%rsp)
	jna	.Lj463
	xorl	%r9d,%r9d
	movq	24(%rsp),%r10
	leaq	2(%rbx),%rax
	cmpq	%r10,%rax
	jnbe	.Lj467
	leaq	1(%rbx),%rdi
	.p2align 4,,10
	.p2align 3
.Lj468:
	addq	$1,%rdi
	movq	(%r14),%rax
	movl	(%rax,%rdi,4),%ecx
	movq	%rdi,%r8
	jmp	.Lj472
	.p2align 4,,10
	.p2align 3
.Lj471:
	movq	(%r14),%rdx
	movl	-4(%rdx,%r8,4),%eax
	movl	%eax,(%rdx,%r8,4)
	subq	$1,%r8
	addl	$1,%r9d
	cmpl	$12,%r9d
	jng	.Lj472
	xorb	%sil,%sil
	jmp	.Lj465
	.p2align 4,,10
	.p2align 3
.Lj472:
	leaq	1(%rbx),%rax
	cmpq	%r8,%rax
	jnb	.Lj477
	movq	(%r14),%rax
	cmpl	-4(%rax,%r8,4),%ecx
	jb	.Lj471
.Lj477:
	movq	(%r14),%rax
	movl	%ecx,(%rax,%r8,4)
	cmpq	%rdi,%r10
	jnbe	.Lj468
.Lj467:
	movb	$1,%sil
.Lj465:
	testb	%sil,%sil
	jne	.Lj365
	.p2align 4,,10
	.p2align 3
.Lj463:
# [167] aLeft := gt + 1;
	leaq	1(%rbx),%r15
	cmpq	%r15,24(%rsp)
	ja	.Lj408
.Lj365:
# [169] end;
	leaq	48(%rsp),%rsp
	popq	%r15
.Lc69:
	popq	%r14
.Lc70:
	popq	%r13
.Lc71:
	popq	%r12
.Lc72:
	popq	%rbx
.Lc73:
	ret
.Lc61:
.Le4:
	.size	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU32$PDWORD$QWORD_$$_INTROSORT$QWORD$QWORD$LONGINT, .Le4 - NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU32$PDWORD$QWORD_$$_INTROSORT$QWORD$QWORD$LONGINT

.section .text.n_nextpas.core.collections.arr.sort$_$sortu32$pdword$qword_$$_heapsort$qword$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU32$PDWORD$QWORD_$$_HEAPSORT$QWORD$QWORD
	.hidden NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU32$PDWORD$QWORD_$$_HEAPSORT$QWORD$QWORD
	.type	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU32$PDWORD$QWORD_$$_HEAPSORT$QWORD$QWORD,@function
NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU32$PDWORD$QWORD_$$_HEAPSORT$QWORD$QWORD:
.Lc75:
# [66] begin
	pushq	%rbx
.Lc76:
# Var idx located in register rcx
# Var child located in register r9
# Var tmp located in register r10d
# Var $parentfp located in register rdi
# Var aL located in register rsi
# Var aR located in register rdx
# [67] LSize := aR - aL + 1;
	subq	%rsi,%rdx
	leaq	1(%rdx),%rax
# Var LSize located in register rax
# [68] i := LSize div 2;
	movq	%rax,%rdx
	shrq	$1,%rdx
# Var i located in register rdx
	.p2align 4,,10
	.p2align 3
.Lj480:
# [72] idx := i;
	leaq	-1(%rdx),%rcx
# [71] Dec(i);
	subq	$1,%rdx
# [73] tmp := aData[aL + idx];
	movq	(%rdi),%r11
	leaq	(%rsi,%rdx),%r8
	movl	(%r11,%r8,4),%r10d
	.p2align 4,,10
	.p2align 3
.Lj483:
# [76] child := 2 * idx + 1;
	leaq	1(%rcx,%rcx,1),%r9
# [77] if child >= LSize then Break;
	cmpq	%r9,%rax
	jbe	.Lj485
# [78] if (child + 1 < LSize) and (aData[aL + child] < aData[aL + child + 1]) then
	leaq	1(%r9),%r8
	cmpq	%rax,%r8
	jnb	.Lj489
	movq	(%rdi),%r11
	leaq	(%rsi,%r9),%r8
	movl	4(%r11,%r8,4),%ebx
	cmpl	(%r11,%r8,4),%ebx
	seta	%r8b
# [79] Inc(child);
	movzbl	%r8b,%r8d
	addq	%r8,%r9
.Lj489:
# [80] if tmp >= aData[aL + child] then Break;
	movq	(%rdi),%r11
	leaq	(%rsi,%r9),%r8
	cmpl	(%r11,%r8,4),%r10d
	jae	.Lj485
	movq	(%rdi),%r8
# [81] aData[aL + idx] := aData[aL + child];
	leaq	(%rsi,%rcx),%r11
	leaq	(%rsi,%r9),%rbx
	movl	(%r8,%rbx,4),%ebx
	movl	%ebx,(%r8,%r11,4)
# [82] idx := child;
	movq	%r9,%rcx
# [74] while True do
	jmp	.Lj483
.Lj485:
# [84] aData[aL + idx] := tmp;
	movq	(%rdi),%r8
	leaq	(%rsi,%rcx),%r11
	movl	%r10d,(%r8,%r11,4)
# [85] if i = 0 then Break;
	testq	%rdx,%rdx
	jne	.Lj480
# [87] i := LSize - 1;
	leaq	-1(%rax),%rdx
# Var i located in register rdx
# [88] while i > 0 do
	testq	%rdx,%rdx
	je	.Lj496
	.p2align 4,,10
	.p2align 3
.Lj497:
# [90] tmp := aData[aL + i];
	movq	(%rdi),%r8
	leaq	(%rsi,%rdx),%r11
	movl	(%r8,%r11,4),%r10d
	movq	(%rdi),%r11
# [91] aData[aL + i] := aData[aL];
	leaq	(%rsi,%rdx),%rbx
	movl	(%r11,%rsi,4),%r8d
	movl	%r8d,(%r11,%rbx,4)
# [92] aData[aL] := tmp;
	movq	(%rdi),%r8
	movl	%r10d,(%r8,%rsi,4)
# [93] Dec(LSize);
	subq	$1,%rax
# [94] idx := 0;
	xorl	%ecx,%ecx
# [95] tmp := aData[aL];
	movq	(%rdi),%r8
	movl	(%r8,%rsi,4),%r10d
	.p2align 4,,10
	.p2align 3
.Lj500:
# [98] child := 2 * idx + 1;
	leaq	1(%rcx,%rcx,1),%r9
# [99] if child >= LSize then Break;
	cmpq	%r9,%rax
	jbe	.Lj502
# [100] if (child + 1 < LSize) and (aData[aL + child] < aData[aL + child + 1]) then
	leaq	1(%r9),%r8
	cmpq	%rax,%r8
	jnb	.Lj506
	movq	(%rdi),%r11
	leaq	(%rsi,%r9),%r8
	movl	4(%r11,%r8,4),%ebx
	cmpl	(%r11,%r8,4),%ebx
	seta	%r8b
# [101] Inc(child);
	movzbl	%r8b,%r8d
	addq	%r8,%r9
.Lj506:
# [102] if tmp >= aData[aL + child] then Break;
	movq	(%rdi),%r11
	leaq	(%rsi,%r9),%r8
	cmpl	(%r11,%r8,4),%r10d
	jae	.Lj502
	movq	(%rdi),%r11
# [103] aData[aL + idx] := aData[aL + child];
	leaq	(%rsi,%rcx),%r8
	leaq	(%rsi,%r9),%rbx
	movl	(%r11,%rbx,4),%ebx
	movl	%ebx,(%r11,%r8,4)
# [104] idx := child;
	movq	%r9,%rcx
# [96] while True do
	jmp	.Lj500
.Lj502:
# [106] aData[aL + idx] := tmp;
	movq	(%rdi),%r8
	leaq	(%rsi,%rcx),%r11
	movl	%r10d,(%r8,%r11,4)
# [107] Dec(i);
	subq	$1,%rdx
	jne	.Lj497
.Lj496:
# [109] end;
	popq	%rbx
.Lc77:
	ret
.Lc74:
.Le5:
	.size	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU32$PDWORD$QWORD_$$_HEAPSORT$QWORD$QWORD, .Le5 - NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU32$PDWORD$QWORD_$$_HEAPSORT$QWORD$QWORD

.section .text.n_nextpas.core.collections.arr.sort$_$sortu32$pdword$qword_$$_trypartialinsertionsort$hhhlmht7g06j,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU32$PDWORD$QWORD_$$_TRYPARTIALINSERTIONSORT$hhHLmht7G06J
	.hidden NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU32$PDWORD$QWORD_$$_TRYPARTIALINSERTIONSORT$hhHLmht7G06J
	.type	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU32$PDWORD$QWORD_$$_TRYPARTIALINSERTIONSORT$hhHLmht7G06J,@function
NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU32$PDWORD$QWORD_$$_TRYPARTIALINSERTIONSORT$hhHLmht7G06J:
.Lc79:
# [44] begin
	pushq	%rbx
.Lc80:
# Var $result located in register al
# Var i located in register rcx
# Var j located in register r8
# Var tmp located in register r9d
# Var $parentfp located in register rdi
# Var aL located in register rsi
# Var aR located in register rdx
# Var LMoves located in register ebx
# [45] LMoves := 0;
	xorl	%ebx,%ebx
# Var aR located in register rdx
# [46] for i := aL + 1 to aR do
	leaq	1(%rsi),%rax
	cmpq	%rdx,%rax
	jnbe	.Lj511
	movq	%rsi,%rcx
	.p2align 4,,10
	.p2align 3
.Lj512:
	addq	$1,%rcx
# [48] tmp := aData[i];
	movq	(%rdi),%r10
	movl	(%r10,%rcx,4),%r9d
# [49] j := i;
	movq	%rcx,%r8
# [50] while (j > aL) and (aData[j - 1] > tmp) do
	jmp	.Lj516
	.p2align 4,,10
	.p2align 3
.Lj515:
	movq	(%rdi),%r10
# [52] aData[j] := aData[j - 1];
	movl	-4(%r10,%r8,4),%r11d
	movl	%r11d,(%r10,%r8,4)
# [53] Dec(j);
	subq	$1,%r8
# [54] Inc(LMoves);
	addl	$1,%ebx
# [55] if LMoves > PARTIAL_INSERTION_LIMIT then Exit(False);
	cmpl	$12,%ebx
	jng	.Lj516
	xorb	%al,%al
	jmp	.Lj361
	.p2align 4,,10
	.p2align 3
.Lj516:
	cmpq	%r8,%rsi
	jnb	.Lj521
	movq	(%rdi),%r10
	cmpl	-4(%r10,%r8,4),%r9d
	jb	.Lj515
.Lj521:
# [57] aData[j] := tmp;
	movq	(%rdi),%r10
	movl	%r9d,(%r10,%r8,4)
	cmpq	%rcx,%rdx
	jnbe	.Lj512
.Lj511:
# [59] Result := True;
	movb	$1,%al
.Lj361:
# [60] end;
	popq	%rbx
.Lc81:
	ret
.Lc78:

.section .text.n_nextpas.core.collections.arr.sort$_$sortu32$pdword$qword_$$_insertionsort$qword$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU32$PDWORD$QWORD_$$_INSERTIONSORT$QWORD$QWORD
	.hidden NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU32$PDWORD$QWORD_$$_INSERTIONSORT$QWORD$QWORD
	.type	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU32$PDWORD$QWORD_$$_INSERTIONSORT$QWORD$QWORD,@function
NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU32$PDWORD$QWORD_$$_INSERTIONSORT$QWORD$QWORD:
.Lc83:
# Var i located in register rax
# Var j located in register rcx
# Var tmp located in register r8d
# Var $parentfp located in register rdi
# Var aL located in register rsi
# Var aR located in register rdx
# [25] begin
# Var aR located in register rdx
# [26] for i := aL + 1 to aR do
	leaq	1(%rsi),%rax
	cmpq	%rdx,%rax
	jnbe	.Lj524
	movq	%rsi,%rax
	.p2align 4,,10
	.p2align 3
.Lj525:
	addq	$1,%rax
# [28] tmp := aData[i];
	movq	(%rdi),%r9
	movl	(%r9,%rax,4),%r8d
# [29] j := i;
	movq	%rax,%rcx
# [30] while (j > aL) and (aData[j - 1] > tmp) do
	jmp	.Lj529
	.p2align 4,,10
	.p2align 3
.Lj528:
	movq	(%rdi),%r10
# [32] aData[j] := aData[j - 1];
	movl	-4(%r10,%rcx,4),%r9d
	movl	%r9d,(%r10,%rcx,4)
# [33] Dec(j);
	subq	$1,%rcx
.Lj529:
	cmpq	%rcx,%rsi
	jnb	.Lj532
	movq	(%rdi),%r9
	cmpl	-4(%r9,%rcx,4),%r8d
	jb	.Lj528
.Lj532:
# [35] aData[j] := tmp;
	movq	(%rdi),%r9
	movl	%r8d,(%r9,%rcx,4)
	cmpq	%rax,%rdx
	jnbe	.Lj525
.Lj524:
.Lc84:
# [37] end;
	ret
.Lc82:

.section .text.n_nextpas.core.collections.arr.sort_$$_sortu64$puint64$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.ARR.SORT_$$_SORTU64$PUINT64$QWORD
	.type	NEXTPAS.CORE.COLLECTIONS.ARR.SORT_$$_SORTU64$PUINT64$QWORD,@function
NEXTPAS.CORE.COLLECTIONS.ARR.SORT_$$_SORTU64$PUINT64$QWORD:
.Lc86:
# [nextpas.core.collections.arr.sort.inc]
# [175] begin
	pushq	%rax
.Lc87:
# Var aData located at rsp+0, size=OS_64
# Var tmp located in register rdx
	movq	%rdi,(%rsp)
# Var aCount located in register rsi
# [176] if aCount < 2 then Exit;
	cmpq	$2,%rsi
	jb	.Lj534
# [178] LEnd := aCount - 2;
	leaq	-2(%rsi),%rax
# Var LEnd located in register rax
# Var i located in register r8
# [179] i := 0;
	xorl	%r8d,%r8d
# [180] while (i <= LEnd) and (aData[i] = aData[i + 1]) do Inc(i);
	jmp	.Lj547
	.p2align 4,,10
	.p2align 3
.Lj546:
	addq	$1,%r8
.Lj547:
	cmpq	%r8,%rax
	jnae	.Lj534
	movq	(%rsp),%rdx
	movq	8(%rdx,%r8,8),%rcx
	cmpq	(%rdx,%r8,8),%rcx
	je	.Lj546
# [181] if i > LEnd then Exit;
	cmpq	%r8,%rax
	jb	.Lj534
	movq	(%rsp),%rcx
# [183] if aData[i] < aData[i + 1] then
	movq	8(%rcx,%r8,8),%rdx
	cmpq	(%rcx,%r8,8),%rdx
	jna	.Lj555
# [185] Inc(i);
	addq	$1,%r8
# [186] while (i <= LEnd) and (aData[i] <= aData[i + 1]) do Inc(i);
	jmp	.Lj557
	.p2align 4,,10
	.p2align 3
.Lj556:
	addq	$1,%r8
.Lj557:
	cmpq	%r8,%rax
	jnae	.Lj534
	movq	(%rsp),%rcx
	movq	8(%rcx,%r8,8),%rdx
	cmpq	(%rcx,%r8,8),%rdx
	jae	.Lj556
# [187] if i > LEnd then Exit;
	cmpq	%r8,%rax
	jb	.Lj534
	jmp	.Lj564
	.p2align 4,,10
	.p2align 3
.Lj555:
# [191] Inc(i);
	addq	$1,%r8
# [192] while (i <= LEnd) and (aData[i] >= aData[i + 1]) do Inc(i);
	jmp	.Lj566
	.p2align 4,,10
	.p2align 3
.Lj565:
	addq	$1,%r8
.Lj566:
	cmpq	%r8,%rax
	jnae	.Lj571
	movq	(%rsp),%rdx
	movq	8(%rdx,%r8,8),%rcx
	cmpq	(%rdx,%r8,8),%rcx
	jbe	.Lj565
# [193] if i > LEnd then
	cmpq	%r8,%rax
	jnb	.Lj564
.Lj571:
# [195] i := 0; LEnd := aCount - 1;
	xorl	%r8d,%r8d
	leaq	-1(%rsi),%rax
# [196] while i < LEnd do
	cmpq	%r8,%rax
	jna	.Lj534
	.p2align 4,,10
	.p2align 3
.Lj575:
# [198] tmp := aData[i]; aData[i] := aData[LEnd]; aData[LEnd] := tmp;
	movq	(%rsp),%rcx
	movq	(%rcx,%r8,8),%rdx
	movq	(%rsp),%rdi
	movq	(%rdi,%rax,8),%rcx
	movq	%rcx,(%rdi,%r8,8)
	movq	(%rsp),%rcx
	movq	%rdx,(%rcx,%rax,8)
# [199] Inc(i); Dec(LEnd);
	addq	$1,%r8
	subq	$1,%rax
	cmpq	%r8,%rax
	ja	.Lj575
# [201] Exit;
	jmp	.Lj534
	.p2align 4,,10
	.p2align 3
.Lj564:
# Var LDepth located in register ecx
# [205] LDepth := 0;
	xorl	%ecx,%ecx
# Var LN located in register rax
# Var aCount located in register rsi
# [206] LN := aCount;
	movq	%rsi,%rax
# [207] while LN > 1 do begin LN := LN shr 1; Inc(LDepth); end;
	cmpq	$1,%rsi
	jna	.Lj579
	.p2align 4,,10
	.p2align 3
.Lj580:
	shrq	$1,%rax
	addl	$1,%ecx
	cmpq	$1,%rax
	ja	.Lj580
.Lj579:
# [208] LDepth := LDepth * 2;
	shll	$1,%ecx
# Var LDepth located in register ecx
# [210] IntroSort(0, aCount - 1, LDepth);
	leaq	-1(%rsi),%rdx
	movq	%rsp,%rdi
# Var LDepth located in register ecx
	xorl	%esi,%esi
	call	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU64$PUINT64$QWORD_$$_INTROSORT$QWORD$QWORD$LONGINT
.Lj534:
# [211] end;
	popq	%rcx
.Lc88:
	ret
.Lc85:

.section .text.n_nextpas.core.collections.arr.sort$_$sortu64$puint64$qword_$$_introsort$qword$qword$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU64$PUINT64$QWORD_$$_INTROSORT$QWORD$QWORD$LONGINT
	.hidden NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU64$PUINT64$QWORD_$$_INTROSORT$QWORD$QWORD$LONGINT
	.type	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU64$PUINT64$QWORD_$$_INTROSORT$QWORD$QWORD$LONGINT,@function
NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU64$PUINT64$QWORD_$$_INTROSORT$QWORD$QWORD$LONGINT:
.Lc90:
# Temps allocated between rsp+0 and rsp+40
# [115] begin
	pushq	%rbx
.Lc91:
	pushq	%r12
.Lc92:
	pushq	%r13
.Lc93:
	pushq	%r14
.Lc94:
	pushq	%r15
.Lc95:
	leaq	-48(%rsp),%rsp
.Lc96:
# Var lt located in register r13
# Var gt located in register rbx
# Var i located in register r12
# Var LMid located in stack [rsp+8]
# Var pivot located in stack [rsp+16]
# Var tmp located in stack [rsp+32]
	movq	%rdi,%r14
# Var $parentfp located in register r14
	movq	%rsi,%r15
# Var aLeft located in register r15
	movq	%rdx,24(%rsp)
# Var aRight located in stack [rsp+24]
	movl	%ecx,%eax
	movq	%rax,(%rsp)
# Var aDepth located in stack [rsp+0]
# [116] while aLeft < aRight do
	cmpq	%r15,24(%rsp)
	jna	.Lj542
	.p2align 4,,10
	.p2align 3
.Lj585:
# [118] if aRight - aLeft < INSERTION_THRESHOLD then
	movq	24(%rsp),%rax
	subq	%r15,%rax
	cmpq	$24,%rax
	jnb	.Lj589
# [120] InsertionSort(aLeft, aRight);
	movq	24(%rsp),%rdi
	leaq	1(%r15),%rax
	cmpq	%rdi,%rax
	jnbe	.Lj542
	movq	%r15,%rcx
	.p2align 4,,10
	.p2align 3
.Lj592:
	addq	$1,%rcx
	movq	(%r14),%rax
	movq	(%rax,%rcx,8),%r8
	movq	%rcx,%rsi
	jmp	.Lj596
	.p2align 4,,10
	.p2align 3
.Lj595:
	movq	(%r14),%rdx
	movq	-8(%rdx,%rsi,8),%rax
	movq	%rax,(%rdx,%rsi,8)
	subq	$1,%rsi
.Lj596:
	cmpq	%rsi,%r15
	jnb	.Lj599
	movq	(%r14),%rax
	cmpq	-8(%rax,%rsi,8),%r8
	jb	.Lj595
.Lj599:
	movq	(%r14),%rax
	movq	%r8,(%rax,%rsi,8)
	cmpq	%rcx,%rdi
	jnbe	.Lj592
# [121] Exit;
	jmp	.Lj542
	.p2align 4,,10
	.p2align 3
.Lj589:
# [124] if aDepth = 0 then
	cmpl	$0,(%rsp)
	jne	.Lj602
# [126] HeapSort(aLeft, aRight);
	movq	%r14,%rdi
	movq	24(%rsp),%rdx
	movq	%r15,%rsi
	call	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU64$PUINT64$QWORD_$$_HEAPSORT$QWORD$QWORD
# [127] Exit;
	jmp	.Lj542
	.p2align 4,,10
	.p2align 3
.Lj602:
# [129] Dec(aDepth);
	movl	(%rsp),%eax
	subl	$1,%eax
	movq	%rax,(%rsp)
# [131] LMid := aLeft + (aRight - aLeft) div 2;
	movq	24(%rsp),%rax
	subq	%r15,%rax
	shrq	$1,%rax
	addq	%r15,%rax
	movq	%rax,8(%rsp)
	movq	(%r14),%rcx
# [132] if aData[aLeft] > aData[LMid] then
	movq	(%rcx,%r15,8),%rdx
	movq	8(%rsp),%rax
	cmpq	(%rcx,%rax,8),%rdx
	jna	.Lj604
# [133] begin tmp := aData[aLeft]; aData[aLeft] := aData[LMid]; aData[LMid] := tmp; end;
	movq	(%r14),%rax
	movq	(%rax,%r15,8),%rdx
	movq	%rdx,32(%rsp)
	movq	(%r14),%rcx
	movq	8(%rsp),%rdx
	movq	(%rcx,%rdx,8),%rax
	movq	%rax,(%rcx,%r15,8)
	movq	(%r14),%rcx
	movq	32(%rsp),%rdx
	movq	8(%rsp),%rax
	movq	%rdx,(%rcx,%rax,8)
.Lj604:
	movq	(%r14),%rdx
# [134] if aData[LMid] > aData[aRight] then
	movq	8(%rsp),%rcx
	movq	(%rdx,%rcx,8),%rax
	movq	24(%rsp),%rcx
	cmpq	(%rdx,%rcx,8),%rax
	jna	.Lj606
# [135] begin tmp := aData[LMid]; aData[LMid] := aData[aRight]; aData[aRight] := tmp; end;
	movq	(%r14),%rax
	movq	8(%rsp),%rdx
	movq	(%rax,%rdx,8),%rdx
	movq	%rdx,32(%rsp)
	movq	(%r14),%rdx
	movq	24(%rsp),%rcx
	movq	(%rdx,%rcx,8),%rax
	movq	8(%rsp),%rcx
	movq	%rax,(%rdx,%rcx,8)
	movq	(%r14),%rcx
	movq	32(%rsp),%rdx
	movq	24(%rsp),%rax
	movq	%rdx,(%rcx,%rax,8)
.Lj606:
	movq	(%r14),%rax
# [136] if aData[aLeft] > aData[LMid] then
	movq	(%rax,%r15,8),%rcx
	movq	8(%rsp),%rdx
	cmpq	(%rax,%rdx,8),%rcx
	jna	.Lj608
# [137] begin tmp := aData[aLeft]; aData[aLeft] := aData[LMid]; aData[LMid] := tmp; end;
	movq	(%r14),%rdx
	movq	(%rdx,%r15,8),%rax
	movq	%rax,32(%rsp)
	movq	(%r14),%rax
	movq	8(%rsp),%rcx
	movq	(%rax,%rcx,8),%rdx
	movq	%rdx,(%rax,%r15,8)
	movq	(%r14),%rax
	movq	32(%rsp),%rcx
	movq	8(%rsp),%rdx
	movq	%rcx,(%rax,%rdx,8)
.Lj608:
# [138] pivot := aData[LMid];
	movq	(%r14),%rax
	movq	8(%rsp),%rdx
	movq	(%rax,%rdx,8),%rdx
	movq	%rdx,16(%rsp)
# [140] lt := aLeft;
	movq	%r15,%r13
# [141] gt := aRight;
	movq	24(%rsp),%rbx
# [142] i := aLeft;
	movq	%r15,%r12
# [143] while i <= gt do
	cmpq	%r15,%rbx
	jnae	.Lj610
	.p2align 4,,10
	.p2align 3
.Lj611:
# [145] if aData[i] < pivot then
	movq	(%r14),%rax
	movq	16(%rsp),%rdx
	cmpq	(%rax,%r12,8),%rdx
	jna	.Lj615
# [147] tmp := aData[i]; aData[i] := aData[lt]; aData[lt] := tmp;
	movq	(%r14),%rax
	movq	(%rax,%r12,8),%rdx
	movq	%rdx,32(%rsp)
	movq	(%r14),%rdx
	movq	(%rdx,%r13,8),%rax
	movq	%rax,(%rdx,%r12,8)
	movq	(%r14),%rax
	movq	32(%rsp),%rdx
	movq	%rdx,(%rax,%r13,8)
# [148] Inc(lt); Inc(i);
	addq	$1,%r13
	addq	$1,%r12
	jmp	.Lj616
	.p2align 4,,10
	.p2align 3
.Lj615:
# [150] else if aData[i] > pivot then
	movq	(%r14),%rax
	movq	16(%rsp),%rdx
	cmpq	(%rax,%r12,8),%rdx
	jnb	.Lj618
# [152] tmp := aData[i]; aData[i] := aData[gt]; aData[gt] := tmp;
	movq	(%r14),%rax
	movq	(%rax,%r12,8),%rdx
	movq	%rdx,32(%rsp)
	movq	(%r14),%rax
	movq	(%rax,%rbx,8),%rdx
	movq	%rdx,(%rax,%r12,8)
	movq	(%r14),%rax
	movq	32(%rsp),%rdx
	movq	%rdx,(%rax,%rbx,8)
# [153] Dec(gt);
	subq	$1,%rbx
	jmp	.Lj616
	.p2align 4,,10
	.p2align 3
.Lj618:
# [156] Inc(i);
	addq	$1,%r12
.Lj616:
	cmpq	%r12,%rbx
	jae	.Lj611
.Lj610:
# [159] if (lt > aLeft) and TryPartialInsertionSort(aLeft, lt - 1) then
	cmpq	%r13,%r15
	jnb	.Lj621
	xorl	%r9d,%r9d
	leaq	-1(%r13),%r10
	leaq	1(%r15),%rax
	cmpq	%r10,%rax
	jnbe	.Lj625
	movq	%r15,%rdi
	.p2align 4,,10
	.p2align 3
.Lj626:
	addq	$1,%rdi
	movq	(%r14),%rax
	movq	(%rax,%rdi,8),%rcx
	movq	%rdi,%r8
	jmp	.Lj630
	.p2align 4,,10
	.p2align 3
.Lj629:
	movq	(%r14),%rax
	movq	-8(%rax,%r8,8),%rdx
	movq	%rdx,(%rax,%r8,8)
	subq	$1,%r8
	addl	$1,%r9d
	cmpl	$12,%r9d
	jng	.Lj630
	xorb	%sil,%sil
	jmp	.Lj623
	.p2align 4,,10
	.p2align 3
.Lj630:
	cmpq	%r8,%r15
	jnb	.Lj635
	movq	(%r14),%rax
	cmpq	-8(%rax,%r8,8),%rcx
	jb	.Lj629
.Lj635:
	movq	(%r14),%rax
	movq	%rcx,(%rax,%r8,8)
	cmpq	%rdi,%r10
	jnbe	.Lj626
.Lj625:
	movb	$1,%sil
.Lj623:
	testb	%sil,%sil
	jne	.Lj622
.Lj621:
# [161] else if lt > aLeft + 1 then
	leaq	1(%r15),%rax
	cmpq	%r13,%rax
	jnb	.Lj622
# [162] IntroSort(aLeft, lt - 1, aDepth);
	leaq	-1(%r13),%rdx
	movq	%r14,%rdi
	movl	(%rsp),%ecx
	movq	%r15,%rsi
	call	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU64$PUINT64$QWORD_$$_INTROSORT$QWORD$QWORD$LONGINT
.Lj622:
# [164] if (gt < aRight) and TryPartialInsertionSort(gt + 1, aRight) then
	cmpq	%rbx,24(%rsp)
	jna	.Lj640
	xorl	%r9d,%r9d
	movq	24(%rsp),%r10
	leaq	2(%rbx),%rax
	cmpq	%r10,%rax
	jnbe	.Lj644
	leaq	1(%rbx),%rdi
	.p2align 4,,10
	.p2align 3
.Lj645:
	addq	$1,%rdi
	movq	(%r14),%rax
	movq	(%rax,%rdi,8),%rcx
	movq	%rdi,%r8
	jmp	.Lj649
	.p2align 4,,10
	.p2align 3
.Lj648:
	movq	(%r14),%rdx
	movq	-8(%rdx,%r8,8),%rax
	movq	%rax,(%rdx,%r8,8)
	subq	$1,%r8
	addl	$1,%r9d
	cmpl	$12,%r9d
	jng	.Lj649
	xorb	%sil,%sil
	jmp	.Lj642
	.p2align 4,,10
	.p2align 3
.Lj649:
	leaq	1(%rbx),%rax
	cmpq	%r8,%rax
	jnb	.Lj654
	movq	(%r14),%rax
	cmpq	-8(%rax,%r8,8),%rcx
	jb	.Lj648
.Lj654:
	movq	(%r14),%rax
	movq	%rcx,(%rax,%r8,8)
	cmpq	%rdi,%r10
	jnbe	.Lj645
.Lj644:
	movb	$1,%sil
.Lj642:
	testb	%sil,%sil
	jne	.Lj542
	.p2align 4,,10
	.p2align 3
.Lj640:
# [167] aLeft := gt + 1;
	leaq	1(%rbx),%r15
	cmpq	%r15,24(%rsp)
	ja	.Lj585
.Lj542:
# [169] end;
	leaq	48(%rsp),%rsp
	popq	%r15
.Lc97:
	popq	%r14
.Lc98:
	popq	%r13
.Lc99:
	popq	%r12
.Lc100:
	popq	%rbx
.Lc101:
	ret
.Lc89:
.Le6:
	.size	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU64$PUINT64$QWORD_$$_INTROSORT$QWORD$QWORD$LONGINT, .Le6 - NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU64$PUINT64$QWORD_$$_INTROSORT$QWORD$QWORD$LONGINT

.section .text.n_nextpas.core.collections.arr.sort$_$sortu64$puint64$qword_$$_heapsort$qword$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU64$PUINT64$QWORD_$$_HEAPSORT$QWORD$QWORD
	.hidden NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU64$PUINT64$QWORD_$$_HEAPSORT$QWORD$QWORD
	.type	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU64$PUINT64$QWORD_$$_HEAPSORT$QWORD$QWORD,@function
NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU64$PUINT64$QWORD_$$_HEAPSORT$QWORD$QWORD:
.Lc103:
# [66] begin
	pushq	%rbx
.Lc104:
# Var idx located in register rcx
# Var child located in register r9
# Var tmp located in register r10
# Var $parentfp located in register rdi
# Var aL located in register rsi
# Var aR located in register rdx
# [67] LSize := aR - aL + 1;
	subq	%rsi,%rdx
	leaq	1(%rdx),%rax
# Var LSize located in register rax
# [68] i := LSize div 2;
	movq	%rax,%rdx
	shrq	$1,%rdx
# Var i located in register rdx
	.p2align 4,,10
	.p2align 3
.Lj657:
# [72] idx := i;
	leaq	-1(%rdx),%rcx
# [71] Dec(i);
	subq	$1,%rdx
# [73] tmp := aData[aL + idx];
	movq	(%rdi),%r11
	leaq	(%rsi,%rdx),%r8
	movq	(%r11,%r8,8),%r10
	.p2align 4,,10
	.p2align 3
.Lj660:
# [76] child := 2 * idx + 1;
	leaq	1(%rcx,%rcx,1),%r9
# [77] if child >= LSize then Break;
	cmpq	%r9,%rax
	jbe	.Lj662
# [78] if (child + 1 < LSize) and (aData[aL + child] < aData[aL + child + 1]) then
	leaq	1(%r9),%r8
	cmpq	%rax,%r8
	jnb	.Lj666
	movq	(%rdi),%r11
	leaq	(%rsi,%r9),%r8
	movq	8(%r11,%r8,8),%rbx
	cmpq	(%r11,%r8,8),%rbx
	seta	%r8b
# [79] Inc(child);
	movzbl	%r8b,%r8d
	addq	%r8,%r9
.Lj666:
# [80] if tmp >= aData[aL + child] then Break;
	movq	(%rdi),%r11
	leaq	(%rsi,%r9),%r8
	cmpq	(%r11,%r8,8),%r10
	jae	.Lj662
	movq	(%rdi),%r8
# [81] aData[aL + idx] := aData[aL + child];
	leaq	(%rsi,%rcx),%r11
	leaq	(%rsi,%r9),%rbx
	movq	(%r8,%rbx,8),%rbx
	movq	%rbx,(%r8,%r11,8)
# [82] idx := child;
	movq	%r9,%rcx
# [74] while True do
	jmp	.Lj660
.Lj662:
# [84] aData[aL + idx] := tmp;
	movq	(%rdi),%r8
	leaq	(%rsi,%rcx),%r11
	movq	%r10,(%r8,%r11,8)
# [85] if i = 0 then Break;
	testq	%rdx,%rdx
	jne	.Lj657
# [87] i := LSize - 1;
	leaq	-1(%rax),%rdx
# Var i located in register rdx
# [88] while i > 0 do
	testq	%rdx,%rdx
	je	.Lj673
	.p2align 4,,10
	.p2align 3
.Lj674:
# [90] tmp := aData[aL + i];
	movq	(%rdi),%r8
	leaq	(%rsi,%rdx),%r11
	movq	(%r8,%r11,8),%r10
	movq	(%rdi),%r11
# [91] aData[aL + i] := aData[aL];
	leaq	(%rsi,%rdx),%rbx
	movq	(%r11,%rsi,8),%r8
	movq	%r8,(%r11,%rbx,8)
# [92] aData[aL] := tmp;
	movq	(%rdi),%r8
	movq	%r10,(%r8,%rsi,8)
# [93] Dec(LSize);
	subq	$1,%rax
# [94] idx := 0;
	xorl	%ecx,%ecx
# [95] tmp := aData[aL];
	movq	(%rdi),%r8
	movq	(%r8,%rsi,8),%r10
	.p2align 4,,10
	.p2align 3
.Lj677:
# [98] child := 2 * idx + 1;
	leaq	1(%rcx,%rcx,1),%r9
# [99] if child >= LSize then Break;
	cmpq	%r9,%rax
	jbe	.Lj679
# [100] if (child + 1 < LSize) and (aData[aL + child] < aData[aL + child + 1]) then
	leaq	1(%r9),%r8
	cmpq	%rax,%r8
	jnb	.Lj683
	movq	(%rdi),%r11
	leaq	(%rsi,%r9),%r8
	movq	8(%r11,%r8,8),%rbx
	cmpq	(%r11,%r8,8),%rbx
	seta	%r8b
# [101] Inc(child);
	movzbl	%r8b,%r8d
	addq	%r8,%r9
.Lj683:
# [102] if tmp >= aData[aL + child] then Break;
	movq	(%rdi),%r11
	leaq	(%rsi,%r9),%r8
	cmpq	(%r11,%r8,8),%r10
	jae	.Lj679
	movq	(%rdi),%r11
# [103] aData[aL + idx] := aData[aL + child];
	leaq	(%rsi,%rcx),%r8
	leaq	(%rsi,%r9),%rbx
	movq	(%r11,%rbx,8),%rbx
	movq	%rbx,(%r11,%r8,8)
# [104] idx := child;
	movq	%r9,%rcx
# [96] while True do
	jmp	.Lj677
.Lj679:
# [106] aData[aL + idx] := tmp;
	movq	(%rdi),%r8
	leaq	(%rsi,%rcx),%r11
	movq	%r10,(%r8,%r11,8)
# [107] Dec(i);
	subq	$1,%rdx
	jne	.Lj674
.Lj673:
# [109] end;
	popq	%rbx
.Lc105:
	ret
.Lc102:
.Le7:
	.size	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU64$PUINT64$QWORD_$$_HEAPSORT$QWORD$QWORD, .Le7 - NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU64$PUINT64$QWORD_$$_HEAPSORT$QWORD$QWORD

.section .text.n_nextpas.core.collections.arr.sort$_$sortu64$puint64$qword_$$_trypartialinsertionsort$hhhlmht7g06j,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU64$PUINT64$QWORD_$$_TRYPARTIALINSERTIONSORT$hhHLmht7G06J
	.hidden NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU64$PUINT64$QWORD_$$_TRYPARTIALINSERTIONSORT$hhHLmht7G06J
	.type	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU64$PUINT64$QWORD_$$_TRYPARTIALINSERTIONSORT$hhHLmht7G06J,@function
NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU64$PUINT64$QWORD_$$_TRYPARTIALINSERTIONSORT$hhHLmht7G06J:
.Lc107:
# [44] begin
	pushq	%rbx
.Lc108:
# Var $result located in register al
# Var i located in register rcx
# Var j located in register r8
# Var tmp located in register r9
# Var $parentfp located in register rdi
# Var aL located in register rsi
# Var aR located in register rdx
# Var LMoves located in register ebx
# [45] LMoves := 0;
	xorl	%ebx,%ebx
# Var aR located in register rdx
# [46] for i := aL + 1 to aR do
	leaq	1(%rsi),%rax
	cmpq	%rdx,%rax
	jnbe	.Lj688
	movq	%rsi,%rcx
	.p2align 4,,10
	.p2align 3
.Lj689:
	addq	$1,%rcx
# [48] tmp := aData[i];
	movq	(%rdi),%r10
	movq	(%r10,%rcx,8),%r9
# [49] j := i;
	movq	%rcx,%r8
# [50] while (j > aL) and (aData[j - 1] > tmp) do
	jmp	.Lj693
	.p2align 4,,10
	.p2align 3
.Lj692:
	movq	(%rdi),%r10
# [52] aData[j] := aData[j - 1];
	movq	-8(%r10,%r8,8),%r11
	movq	%r11,(%r10,%r8,8)
# [53] Dec(j);
	subq	$1,%r8
# [54] Inc(LMoves);
	addl	$1,%ebx
# [55] if LMoves > PARTIAL_INSERTION_LIMIT then Exit(False);
	cmpl	$12,%ebx
	jng	.Lj693
	xorb	%al,%al
	jmp	.Lj538
	.p2align 4,,10
	.p2align 3
.Lj693:
	cmpq	%r8,%rsi
	jnb	.Lj698
	movq	(%rdi),%r10
	cmpq	-8(%r10,%r8,8),%r9
	jb	.Lj692
.Lj698:
# [57] aData[j] := tmp;
	movq	(%rdi),%r10
	movq	%r9,(%r10,%r8,8)
	cmpq	%rcx,%rdx
	jnbe	.Lj689
.Lj688:
# [59] Result := True;
	movb	$1,%al
.Lj538:
# [60] end;
	popq	%rbx
.Lc109:
	ret
.Lc106:

.section .text.n_nextpas.core.collections.arr.sort$_$sortu64$puint64$qword_$$_insertionsort$qword$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU64$PUINT64$QWORD_$$_INSERTIONSORT$QWORD$QWORD
	.hidden NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU64$PUINT64$QWORD_$$_INSERTIONSORT$QWORD$QWORD
	.type	NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU64$PUINT64$QWORD_$$_INSERTIONSORT$QWORD$QWORD,@function
NEXTPAS.CORE.COLLECTIONS.ARR.SORT$_$SORTU64$PUINT64$QWORD_$$_INSERTIONSORT$QWORD$QWORD:
.Lc111:
# Var i located in register rax
# Var j located in register rcx
# Var tmp located in register r8
# Var $parentfp located in register rdi
# Var aL located in register rsi
# Var aR located in register rdx
# [25] begin
# Var aR located in register rdx
# [26] for i := aL + 1 to aR do
	leaq	1(%rsi),%rax
	cmpq	%rdx,%rax
	jnbe	.Lj701
	movq	%rsi,%rax
	.p2align 4,,10
	.p2align 3
.Lj702:
	addq	$1,%rax
# [28] tmp := aData[i];
	movq	(%rdi),%r9
	movq	(%r9,%rax,8),%r8
# [29] j := i;
	movq	%rax,%rcx
# [30] while (j > aL) and (aData[j - 1] > tmp) do
	jmp	.Lj706
	.p2align 4,,10
	.p2align 3
.Lj705:
	movq	(%rdi),%r10
# [32] aData[j] := aData[j - 1];
	movq	-8(%r10,%rcx,8),%r9
	movq	%r9,(%r10,%rcx,8)
# [33] Dec(j);
	subq	$1,%rcx
.Lj706:
	cmpq	%rcx,%rsi
	jnb	.Lj709
	movq	(%rdi),%r9
	cmpq	-8(%r9,%rcx,8),%r8
	jb	.Lj705
.Lj709:
# [35] aData[j] := tmp;
	movq	(%rdi),%r9
	movq	%r8,(%r9,%rcx,8)
	cmpq	%rax,%rdx
	jnbe	.Lj702
.Lj701:
.Lc112:
# [37] end;
	ret
.Lc110:
# End asmlist al_procedures
# Begin asmlist al_dwarf_frame

.section .debug_frame
.Lc113:
	.long	.Lc115-.Lc114
.Lc114:
	.long	-1
	.byte	1
	.byte	0
	.uleb128	1
	.sleb128	-4
	.byte	16
	.byte	12
	.uleb128	7
	.uleb128	8
	.byte	5
	.uleb128	16
	.uleb128	2
	.balign 8,0
.Lc115:
	.long	.Lc117-.Lc116
.Lc116:
	.long	.Lc113
	.quad	.Lc2
	.quad	.Lc1-.Lc2
	.byte	2
	.byte	.Lc3-.Lc2
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc4-.Lc3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc117:
	.long	.Lc120-.Lc119
.Lc119:
	.long	.Lc113
	.quad	.Lc6
	.quad	.Lc5-.Lc6
	.byte	2
	.byte	.Lc7-.Lc6
	.byte	5
	.uleb128	3
	.uleb128	14
	.byte	14
	.uleb128	56
	.byte	2
	.byte	.Lc8-.Lc7
	.byte	5
	.uleb128	12
	.uleb128	16
	.byte	14
	.uleb128	64
	.byte	2
	.byte	.Lc9-.Lc8
	.byte	5
	.uleb128	13
	.uleb128	18
	.byte	14
	.uleb128	72
	.byte	2
	.byte	.Lc10-.Lc9
	.byte	5
	.uleb128	14
	.uleb128	20
	.byte	14
	.uleb128	80
	.byte	2
	.byte	.Lc11-.Lc10
	.byte	5
	.uleb128	15
	.uleb128	22
	.byte	14
	.uleb128	88
	.byte	2
	.byte	.Lc12-.Lc11
	.byte	14
	.uleb128	96
	.byte	4
	.long	.Lc13-.Lc12
	.byte	6
	.uleb128	15
	.byte	2
	.byte	.Lc14-.Lc13
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc15-.Lc14
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc16-.Lc15
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc17-.Lc16
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc120:
	.long	.Lc123-.Lc122
.Lc122:
	.long	.Lc113
	.quad	.Lc19
	.quad	.Lc18-.Lc19
	.byte	2
	.byte	.Lc20-.Lc19
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc21-.Lc20
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc123:
	.long	.Lc126-.Lc125
.Lc125:
	.long	.Lc113
	.quad	.Lc23
	.quad	.Lc22-.Lc23
	.byte	2
	.byte	.Lc24-.Lc23
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc25-.Lc24
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc126:
	.long	.Lc129-.Lc128
.Lc128:
	.long	.Lc113
	.quad	.Lc27
	.quad	.Lc26-.Lc27
	.byte	4
	.long	.Lc28-.Lc27
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc129:
	.long	.Lc132-.Lc131
.Lc131:
	.long	.Lc113
	.quad	.Lc30
	.quad	.Lc29-.Lc30
	.byte	2
	.byte	.Lc31-.Lc30
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc32-.Lc31
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc132:
	.long	.Lc135-.Lc134
.Lc134:
	.long	.Lc113
	.quad	.Lc34
	.quad	.Lc33-.Lc34
	.byte	2
	.byte	.Lc35-.Lc34
	.byte	5
	.uleb128	3
	.uleb128	14
	.byte	14
	.uleb128	56
	.byte	2
	.byte	.Lc36-.Lc35
	.byte	5
	.uleb128	12
	.uleb128	16
	.byte	14
	.uleb128	64
	.byte	2
	.byte	.Lc37-.Lc36
	.byte	5
	.uleb128	13
	.uleb128	18
	.byte	14
	.uleb128	72
	.byte	2
	.byte	.Lc38-.Lc37
	.byte	5
	.uleb128	14
	.uleb128	20
	.byte	14
	.uleb128	80
	.byte	2
	.byte	.Lc39-.Lc38
	.byte	5
	.uleb128	15
	.uleb128	22
	.byte	14
	.uleb128	88
	.byte	2
	.byte	.Lc40-.Lc39
	.byte	14
	.uleb128	96
	.byte	4
	.long	.Lc41-.Lc40
	.byte	6
	.uleb128	15
	.byte	2
	.byte	.Lc42-.Lc41
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc43-.Lc42
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc44-.Lc43
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc45-.Lc44
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc135:
	.long	.Lc138-.Lc137
.Lc137:
	.long	.Lc113
	.quad	.Lc47
	.quad	.Lc46-.Lc47
	.byte	2
	.byte	.Lc48-.Lc47
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc49-.Lc48
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc138:
	.long	.Lc141-.Lc140
.Lc140:
	.long	.Lc113
	.quad	.Lc51
	.quad	.Lc50-.Lc51
	.byte	2
	.byte	.Lc52-.Lc51
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc53-.Lc52
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc141:
	.long	.Lc144-.Lc143
.Lc143:
	.long	.Lc113
	.quad	.Lc55
	.quad	.Lc54-.Lc55
	.byte	4
	.long	.Lc56-.Lc55
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc144:
	.long	.Lc147-.Lc146
.Lc146:
	.long	.Lc113
	.quad	.Lc58
	.quad	.Lc57-.Lc58
	.byte	2
	.byte	.Lc59-.Lc58
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc60-.Lc59
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc147:
	.long	.Lc150-.Lc149
.Lc149:
	.long	.Lc113
	.quad	.Lc62
	.quad	.Lc61-.Lc62
	.byte	2
	.byte	.Lc63-.Lc62
	.byte	5
	.uleb128	3
	.uleb128	14
	.byte	14
	.uleb128	56
	.byte	2
	.byte	.Lc64-.Lc63
	.byte	5
	.uleb128	12
	.uleb128	16
	.byte	14
	.uleb128	64
	.byte	2
	.byte	.Lc65-.Lc64
	.byte	5
	.uleb128	13
	.uleb128	18
	.byte	14
	.uleb128	72
	.byte	2
	.byte	.Lc66-.Lc65
	.byte	5
	.uleb128	14
	.uleb128	20
	.byte	14
	.uleb128	80
	.byte	2
	.byte	.Lc67-.Lc66
	.byte	5
	.uleb128	15
	.uleb128	22
	.byte	14
	.uleb128	88
	.byte	2
	.byte	.Lc68-.Lc67
	.byte	14
	.uleb128	96
	.byte	4
	.long	.Lc69-.Lc68
	.byte	6
	.uleb128	15
	.byte	2
	.byte	.Lc70-.Lc69
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc71-.Lc70
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc72-.Lc71
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc73-.Lc72
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc150:
	.long	.Lc153-.Lc152
.Lc152:
	.long	.Lc113
	.quad	.Lc75
	.quad	.Lc74-.Lc75
	.byte	2
	.byte	.Lc76-.Lc75
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc77-.Lc76
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc153:
	.long	.Lc156-.Lc155
.Lc155:
	.long	.Lc113
	.quad	.Lc79
	.quad	.Lc78-.Lc79
	.byte	2
	.byte	.Lc80-.Lc79
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc81-.Lc80
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc156:
	.long	.Lc159-.Lc158
.Lc158:
	.long	.Lc113
	.quad	.Lc83
	.quad	.Lc82-.Lc83
	.byte	4
	.long	.Lc84-.Lc83
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc159:
	.long	.Lc162-.Lc161
.Lc161:
	.long	.Lc113
	.quad	.Lc86
	.quad	.Lc85-.Lc86
	.byte	2
	.byte	.Lc87-.Lc86
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc88-.Lc87
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc162:
	.long	.Lc165-.Lc164
.Lc164:
	.long	.Lc113
	.quad	.Lc90
	.quad	.Lc89-.Lc90
	.byte	2
	.byte	.Lc91-.Lc90
	.byte	5
	.uleb128	3
	.uleb128	14
	.byte	14
	.uleb128	56
	.byte	2
	.byte	.Lc92-.Lc91
	.byte	5
	.uleb128	12
	.uleb128	16
	.byte	14
	.uleb128	64
	.byte	2
	.byte	.Lc93-.Lc92
	.byte	5
	.uleb128	13
	.uleb128	18
	.byte	14
	.uleb128	72
	.byte	2
	.byte	.Lc94-.Lc93
	.byte	5
	.uleb128	14
	.uleb128	20
	.byte	14
	.uleb128	80
	.byte	2
	.byte	.Lc95-.Lc94
	.byte	5
	.uleb128	15
	.uleb128	22
	.byte	14
	.uleb128	88
	.byte	2
	.byte	.Lc96-.Lc95
	.byte	14
	.uleb128	96
	.byte	4
	.long	.Lc97-.Lc96
	.byte	6
	.uleb128	15
	.byte	2
	.byte	.Lc98-.Lc97
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc99-.Lc98
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc100-.Lc99
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc101-.Lc100
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc165:
	.long	.Lc168-.Lc167
.Lc167:
	.long	.Lc113
	.quad	.Lc103
	.quad	.Lc102-.Lc103
	.byte	2
	.byte	.Lc104-.Lc103
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc105-.Lc104
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc168:
	.long	.Lc171-.Lc170
.Lc170:
	.long	.Lc113
	.quad	.Lc107
	.quad	.Lc106-.Lc107
	.byte	2
	.byte	.Lc108-.Lc107
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc109-.Lc108
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc171:
	.long	.Lc174-.Lc173
.Lc173:
	.long	.Lc113
	.quad	.Lc111
	.quad	.Lc110-.Lc111
	.byte	4
	.long	.Lc112-.Lc111
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc174:
# End asmlist al_dwarf_frame
.section .note.GNU-stack,"",%progbits

