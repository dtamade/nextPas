	.file "nextpas.core.platform.windows.math.pas"
# Begin asmlist al_procedures

.section .text.n_nextpas.core.platform.windows.math_$$_windows_mul_div_floor$qword$qword$qword$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.PLATFORM.WINDOWS.MATH_$$_WINDOWS_MUL_DIV_FLOOR$QWORD$QWORD$QWORD$$QWORD
	.hidden NEXTPAS.CORE.PLATFORM.WINDOWS.MATH_$$_WINDOWS_MUL_DIV_FLOOR$QWORD$QWORD$QWORD$$QWORD
	.type	NEXTPAS.CORE.PLATFORM.WINDOWS.MATH_$$_WINDOWS_MUL_DIV_FLOOR$QWORD$QWORD$QWORD$$QWORD,@function
NEXTPAS.CORE.PLATFORM.WINDOWS.MATH_$$_WINDOWS_MUL_DIV_FLOOR$QWORD$QWORD$QWORD$$QWORD:
.Lc2:
# Var $result located in register r9
# Var AValue located in register rdi
# Var AMultiplier located in register rsi
# [nextpas.core.platform.windows.math.pas]
# [25] begin
	movq	%rdx,%rcx
# Var ADivisor located in register rcx
# [26] if (AValue = 0) or (AMultiplier = 0) then
	testq	%rdi,%rdi
	seteb	%dl
	testq	%rsi,%rsi
	seteb	%al
	xorl	%r8d,%r8d
	orb	%al,%dl
# [27] Exit(0);
	cmovneq	%r8,%r9
	jne	.Lj3
# [28] if ADivisor = 0 then
	movq	$-1,%rax
	testq	%rcx,%rcx
# [29] Exit(High(UInt64));
	cmoveq	%rax,%r9
	je	.Lj3
# Var LFactor located in register rsi
# Var AMultiplier located in register rsi
# Var LQuotient located in register r10
# [32] LQuotient := 0;
	xorl	%r10d,%r10d
# Var LRemainder located in register r11
# [33] LRemainder := 0;
	xorl	%r11d,%r11d
# [34] LTermQuotient := AValue div ADivisor;
	movq	%rdi,%rax
	xorl	%edx,%edx
	divq	%rcx
	movq	%rax,%r8
# Var LTermQuotient located in register r8
# [35] LTermRemainder := AValue mod ADivisor;
	movq	%rdi,%rax
	xorl	%edx,%edx
	divq	%rcx
# Var LTermRemainder located in register rdx
# [37] while LFactor <> 0 do
	testq	%rsi,%rsi
	je	.Lj10
	.p2align 4,,10
	.p2align 3
.Lj11:
# [39] if (LFactor and UInt64(1)) <> 0 then
	testb	$1,%sil
	je	.Lj15
# [41] if LQuotient > High(UInt64) - LTermQuotient then
	movq	$-1,%rax
	subq	%r8,%rax
	movq	$-1,%rdi
	cmpq	%r10,%rax
# [42] Exit(High(UInt64));
	cmovbq	%rdi,%r9
	jb	.Lj3
# [43] LQuotient := LQuotient + LTermQuotient;
	addq	%r8,%r10
# [45] if LTermRemainder <> 0 then
	testq	%rdx,%rdx
	je	.Lj15
# [47] if LRemainder >= ADivisor - LTermRemainder then
	movq	%rcx,%rax
	subq	%rdx,%rax
	cmpq	%r11,%rax
	jnbe	.Lj21
# [49] LRemainder := LRemainder - (ADivisor - LTermRemainder);
	movq	%rcx,%rax
	subq	%rdx,%rax
	subq	%rax,%r11
# [50] if LQuotient = High(UInt64) then
	movq	$-1,%rax
	cmpq	$-1,%r10
# [51] Exit(High(UInt64));
	cmoveq	%rax,%r9
	je	.Lj3
# [52] Inc(LQuotient);
	addq	$1,%r10
	jmp	.Lj15
	.p2align 4,,10
	.p2align 3
.Lj21:
# [55] LRemainder := LRemainder + LTermRemainder;
	addq	%rdx,%r11
.Lj15:
# [59] LFactor := LFactor shr 1;
	shrq	$1,%rsi
# [60] if LFactor = 0 then
	je	.Lj10
# [63] if LTermQuotient > High(UInt64) div 2 then
	movq	$9223372036854775807,%rax
	movq	$-1,%rdi
	cmpq	%rax,%r8
# [64] LTermQuotient := High(UInt64)
	cmovaq	%rdi,%r8
	ja	.Lj29
# [66] LTermQuotient := LTermQuotient * 2;
	shlq	$1,%r8
.Lj29:
# [68] if LTermRemainder <> 0 then
	testq	%rdx,%rdx
	je	.Lj31
# [70] if LTermRemainder >= ADivisor - LTermRemainder then
	movq	%rcx,%rax
	subq	%rdx,%rax
	cmpq	%rdx,%rax
	jnbe	.Lj33
# [72] LTermRemainder := LTermRemainder - (ADivisor - LTermRemainder);
	movq	%rcx,%rax
	subq	%rdx,%rax
	subq	%rax,%rdx
# [73] if LTermQuotient <> High(UInt64) then
	cmpq	$-1,%r8
	je	.Lj31
# [74] Inc(LTermQuotient);
	addq	$1,%r8
	jmp	.Lj31
	.p2align 4,,10
	.p2align 3
.Lj33:
# [77] LTermRemainder := LTermRemainder + LTermRemainder;
	addq	%rdx,%rdx
.Lj31:
	testq	%rsi,%rsi
	jne	.Lj11
.Lj10:
# Var LQuotient located in register r10
# [81] Result := LQuotient;
	movq	%r10,%r9
.Lj3:
# [82] end;
	movq	%r9,%rax
.Lc3:
	ret
.Lc1:
.Le0:
	.size	NEXTPAS.CORE.PLATFORM.WINDOWS.MATH_$$_WINDOWS_MUL_DIV_FLOOR$QWORD$QWORD$QWORD$$QWORD, .Le0 - NEXTPAS.CORE.PLATFORM.WINDOWS.MATH_$$_WINDOWS_MUL_DIV_FLOOR$QWORD$QWORD$QWORD$$QWORD

.section .text.n_nextpas.core.platform.windows.math_$$_windows_scale_units$qword$qword$qword$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.PLATFORM.WINDOWS.MATH_$$_WINDOWS_SCALE_UNITS$QWORD$QWORD$QWORD$$QWORD
	.hidden NEXTPAS.CORE.PLATFORM.WINDOWS.MATH_$$_WINDOWS_SCALE_UNITS$QWORD$QWORD$QWORD$$QWORD
	.type	NEXTPAS.CORE.PLATFORM.WINDOWS.MATH_$$_WINDOWS_SCALE_UNITS$QWORD$QWORD$QWORD$$QWORD,@function
NEXTPAS.CORE.PLATFORM.WINDOWS.MATH_$$_WINDOWS_SCALE_UNITS$QWORD$QWORD$QWORD$$QWORD:
.Lc5:
# [93] begin
	pushq	%rbx
.Lc6:
	pushq	%r12
.Lc7:
	pushq	%rax
.Lc8:
# Var $result located in register rbx
# Var LFrac located in register r12
# Var AValue located in register rdi
	movq	%rsi,%rcx
# Var ADivisor located in register rcx
	movq	%rdx,%rsi
# Var AMultiplier located in register rsi
# [94] if AMultiplier = 0 then
	xorl	%eax,%eax
	testq	%rdx,%rdx
# [95] Exit(0);
	cmoveq	%rax,%rbx
	je	.Lj37
# Var LDivisor located in register rcx
# Var ADivisor located in register rcx
# [98] if LDivisor = 0 then
	movl	$1,%eax
	testq	%rcx,%rcx
# [99] LDivisor := 1;
	cmoveq	%rax,%rcx
# [101] LWhole := AValue div LDivisor;
	movq	%rdi,%rax
	xorl	%edx,%edx
	divq	%rcx
	movq	%rax,%r8
# Var LWhole located in register r8
# [102] LRem := AValue mod LDivisor;
	movq	%rdi,%rax
	xorl	%edx,%edx
	divq	%rcx
	movq	%rdx,%rdi
# Var LRem located in register rdi
# [104] if LWhole > High(UInt64) div AMultiplier then
	movq	$-1,%rax
	xorl	%edx,%edx
	divq	%rsi
	movq	$-1,%rdx
	cmpq	%r8,%rax
# [105] Exit(High(UInt64));
	cmovbq	%rdx,%rbx
	jb	.Lj37
# [107] Result := LWhole * AMultiplier;
	imulq	%rsi,%r8
	movq	%r8,%rbx
# [109] if LRem = 0 then
	xorl	%eax,%eax
	testq	%rdi,%rdi
# [110] LFrac := 0
	cmoveq	%rax,%r12
	je	.Lj47
# [111] else if LRem <= High(UInt64) div AMultiplier then
	movq	$-1,%rax
	xorl	%edx,%edx
	divq	%rsi
	cmpq	%rdi,%rax
	jnae	.Lj49
# [112] LFrac := (LRem * AMultiplier) div LDivisor
	movq	%rdi,%rax
	imulq	%rsi,%rax
	xorl	%edx,%edx
	divq	%rcx
	movq	%rax,%r12
	jmp	.Lj47
	.p2align 4,,10
	.p2align 3
.Lj49:
# [114] LFrac := windows_mul_div_floor(LRem, AMultiplier, LDivisor);
	movq	%rcx,%rdx
	call	NEXTPAS.CORE.PLATFORM.WINDOWS.MATH_$$_WINDOWS_MUL_DIV_FLOOR$QWORD$QWORD$QWORD$$QWORD
	movq	%rax,%r12
.Lj47:
# [116] if Result > High(UInt64) - LFrac then
	movq	$-1,%rax
	subq	%r12,%rax
	movq	$-1,%rcx
	cmpq	%rbx,%rax
# [117] Exit(High(UInt64));
	cmovbq	%rcx,%rbx
	jb	.Lj37
# [119] Result := Result + LFrac;
	addq	%r12,%rbx
.Lj37:
# [120] end;
	movq	%rbx,%rax
	popq	%rcx
	popq	%r12
.Lc9:
	popq	%rbx
.Lc10:
	ret
.Lc4:
.Le1:
	.size	NEXTPAS.CORE.PLATFORM.WINDOWS.MATH_$$_WINDOWS_SCALE_UNITS$QWORD$QWORD$QWORD$$QWORD, .Le1 - NEXTPAS.CORE.PLATFORM.WINDOWS.MATH_$$_WINDOWS_SCALE_UNITS$QWORD$QWORD$QWORD$$QWORD

.section .text.n_nextpas.core.platform.windows.math_$$_windows_qpc_to_ns$qword$qword$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.PLATFORM.WINDOWS.MATH_$$_WINDOWS_QPC_TO_NS$QWORD$QWORD$$QWORD
	.type	NEXTPAS.CORE.PLATFORM.WINDOWS.MATH_$$_WINDOWS_QPC_TO_NS$QWORD$QWORD$$QWORD,@function
NEXTPAS.CORE.PLATFORM.WINDOWS.MATH_$$_WINDOWS_QPC_TO_NS$QWORD$QWORD$$QWORD:
.Lc12:
# [123] begin
	pushq	%rax
.Lc13:
# Var ACounter located in register rdi
# Var AFrequency located in register rsi
# [124] Result := windows_scale_units(ACounter, AFrequency, WINDOWS_NANOSECONDS_PER_SECOND);
	movl	$1000000000,%edx
# Var AFrequency located in register rsi
# Var ACounter located in register rdi
	call	NEXTPAS.CORE.PLATFORM.WINDOWS.MATH_$$_WINDOWS_SCALE_UNITS$QWORD$QWORD$QWORD$$QWORD
# Var $result located in register rax
# [125] end;
	popq	%rcx
.Lc14:
	ret
.Lc11:

.section .text.n_nextpas.core.platform.windows.math_$$_windows_qpc_resolution_ns$qword$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.PLATFORM.WINDOWS.MATH_$$_WINDOWS_QPC_RESOLUTION_NS$QWORD$$QWORD
	.type	NEXTPAS.CORE.PLATFORM.WINDOWS.MATH_$$_WINDOWS_QPC_RESOLUTION_NS$QWORD$$QWORD,@function
NEXTPAS.CORE.PLATFORM.WINDOWS.MATH_$$_WINDOWS_QPC_RESOLUTION_NS$QWORD$$QWORD:
.Lc16:
# Var $result located in register rcx
# Var AFrequency located in register rdi
# [128] begin
# [129] if AFrequency = 0 then
	movl	$1,%eax
	testq	%rdi,%rdi
# [130] Exit(1);
	cmoveq	%rax,%rcx
	je	.Lj55
# [131] if AFrequency >= WINDOWS_NANOSECONDS_PER_SECOND then
	movl	$1,%eax
	cmpq	$1000000000,%rdi
# [132] Exit(1);
	cmovaeq	%rax,%rcx
	jae	.Lj55
# [133] Result := (WINDOWS_NANOSECONDS_PER_SECOND + AFrequency - 1) div AFrequency;
	leaq	1000000000(%rdi),%rax
	subq	$1,%rax
	xorl	%edx,%edx
	divq	%rdi
	movq	%rax,%rcx
# [134] if Result = 0 then
	movl	$1,%edx
	testq	%rax,%rax
# [135] Result := 1;
	cmoveq	%rdx,%rcx
.Lj55:
# [136] end;
	movq	%rcx,%rax
.Lc17:
	ret
.Lc15:
# End asmlist al_procedures
# Begin asmlist al_dwarf_frame

.section .debug_frame
.Lc18:
	.long	.Lc20-.Lc19
.Lc19:
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
.Lc20:
	.long	.Lc22-.Lc21
.Lc21:
	.long	.Lc18
	.quad	.Lc2
	.quad	.Lc1-.Lc2
	.byte	4
	.long	.Lc3-.Lc2
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc22:
	.long	.Lc25-.Lc24
.Lc24:
	.long	.Lc18
	.quad	.Lc5
	.quad	.Lc4-.Lc5
	.byte	2
	.byte	.Lc6-.Lc5
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc7-.Lc6
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc8-.Lc7
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc9-.Lc8
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc10-.Lc9
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc25:
	.long	.Lc28-.Lc27
.Lc27:
	.long	.Lc18
	.quad	.Lc12
	.quad	.Lc11-.Lc12
	.byte	2
	.byte	.Lc13-.Lc12
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc14-.Lc13
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc28:
	.long	.Lc31-.Lc30
.Lc30:
	.long	.Lc18
	.quad	.Lc16
	.quad	.Lc15-.Lc16
	.byte	4
	.long	.Lc17-.Lc16
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc31:
# End asmlist al_dwarf_frame
.section .note.GNU-stack,"",%progbits

