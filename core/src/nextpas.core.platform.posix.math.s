	.file "nextpas.core.platform.posix.math.pas"
# Begin asmlist al_procedures

.section .text.n_nextpas.core.platform.posix.math_$$_platform_posix_timespec_to_ns_u64$ptimespec$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.PLATFORM.POSIX.MATH_$$_PLATFORM_POSIX_TIMESPEC_TO_NS_U64$PTIMESPEC$$QWORD
	.type	NEXTPAS.CORE.PLATFORM.POSIX.MATH_$$_PLATFORM_POSIX_TIMESPEC_TO_NS_U64$PTIMESPEC$$QWORD,@function
NEXTPAS.CORE.PLATFORM.POSIX.MATH_$$_PLATFORM_POSIX_TIMESPEC_TO_NS_U64$PTIMESPEC$$QWORD:
.Lc2:
# Var $result located in register rax
# Var ATime located in register rdi
# [nextpas.core.platform.posix.math.pas]
# [36] begin
# [37] if ATime = nil then
	xorl	%ecx,%ecx
	testq	%rdi,%rdi
# [38] Exit(0);
	cmoveq	%rcx,%rax
	je	.Lj3
# [39] if (ATime^.tv_sec < 0) or (ATime^.tv_nsec < 0) then
	cmpq	$0,(%rdi)
	jl	.Lj7
	cmpq	$0,8(%rdi)
	jnl	.Lj9
.Lj7:
# [40] Exit(0);
	xorl	%eax,%eax
	ret
	.p2align 4,,10
	.p2align 3
.Lj9:
# [41] if UInt64(ATime^.tv_sec) > High(UInt64) div PLATFORM_POSIX_NANOSECONDS_PER_SECOND then
	movq	(%rdi),%rdx
	movq	$18446744073,%rcx
	movq	$-1,%rsi
	cmpq	%rcx,%rdx
# [42] Exit(High(UInt64));
	cmovaq	%rsi,%rax
	ja	.Lj3
# Var ATime located in register rdi
# [44] LSecNs := UInt64(ATime^.tv_sec) * PLATFORM_POSIX_NANOSECONDS_PER_SECOND;
	imulq	$1000000000,(%rdi),%rdx
# Var LSecNs located in register rdx
# Var ATime located in register rdi
# Var LNsec located in register rsi
# [45] LNsec := UInt64(ATime^.tv_nsec);
	movq	8(%rdi),%rsi
# [46] if LSecNs > High(UInt64) - LNsec then
	movq	$-1,%rcx
	subq	%rsi,%rcx
# [47] Exit(High(UInt64));
	movq	$-1,%rax
	cmpq	%rdx,%rcx
	jb	.Lj3
# [49] Result := LSecNs + LNsec;
	leaq	(%rdx,%rsi),%rax
.Lj3:
.Lc3:
# [50] end;
	ret
.Lc1:

.section .text.n_nextpas.core.platform.posix.math_$$_platform_posix_timespec_add_ns$timespec$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.PLATFORM.POSIX.MATH_$$_PLATFORM_POSIX_TIMESPEC_ADD_NS$TIMESPEC$QWORD
	.type	NEXTPAS.CORE.PLATFORM.POSIX.MATH_$$_PLATFORM_POSIX_TIMESPEC_ADD_NS$TIMESPEC$QWORD,@function
NEXTPAS.CORE.PLATFORM.POSIX.MATH_$$_PLATFORM_POSIX_TIMESPEC_ADD_NS$TIMESPEC$QWORD:
.Lc5:
# Var ATime located in register rdi
# Var ANanoseconds located in register rsi
# [56] begin
# [57] LSeconds := ANanoseconds div PLATFORM_POSIX_NANOSECONDS_PER_SECOND;
	movq	%rsi,%rcx
	movq	$1360296554856532783,%rax
	mulq	%rcx
	addq	%rcx,%rdx
	rcrq	$1,%rdx
	shrq	$29,%rdx
	movq	%rdx,%rcx
# Var LSeconds located in register rcx
# [58] LNanos := ANanoseconds mod PLATFORM_POSIX_NANOSECONDS_PER_SECOND;
	movq	$1360296554856532783,%rax
	mulq	%rsi
	movq	%rsi,%rax
	addq	%rsi,%rdx
	rcrq	$1,%rdx
	shrq	$29,%rdx
	imulq	$1000000000,%rdx
	subq	%rdx,%rax
# Var LNanos located in register rax
# [59] ATime.tv_sec := ATime.tv_sec + Int64(LSeconds);
	addq	%rcx,(%rdi)
# [60] ATime.tv_nsec := ATime.tv_nsec + Int64(LNanos);
	addq	%rax,8(%rdi)
# [61] if ATime.tv_nsec >= Int64(PLATFORM_POSIX_NANOSECONDS_PER_SECOND) then
	cmpq	$1000000000,8(%rdi)
	jnge	.Lj17
# [63] Inc(ATime.tv_sec);
	addq	$1,(%rdi)
# [64] Dec(ATime.tv_nsec, Int64(PLATFORM_POSIX_NANOSECONDS_PER_SECOND));
	subq	$1000000000,8(%rdi)
.Lj17:
.Lc6:
# [66] end;
	ret
.Lc4:

.section .text.n_nextpas.core.platform.posix.math_$$_platform_posix_timespec_remaining_ns_u64$hkvwxcasfdia,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.PLATFORM.POSIX.MATH_$$_PLATFORM_POSIX_TIMESPEC_REMAINING_NS_U64$hkVwXcAsFdIA
	.type	NEXTPAS.CORE.PLATFORM.POSIX.MATH_$$_PLATFORM_POSIX_TIMESPEC_REMAINING_NS_U64$hkVwXcAsFdIA,@function
NEXTPAS.CORE.PLATFORM.POSIX.MATH_$$_PLATFORM_POSIX_TIMESPEC_REMAINING_NS_U64$hkVwXcAsFdIA:
.Lc8:
# Var $result located in register rax
# Var ADeadline located in register rdi
# Var ANow located in register rsi
# [74] begin
# [75] LDeadlineNs := platform_posix_timespec_to_ns_u64(ADeadline);
	xorl	%eax,%eax
	testq	%rdi,%rdi
	cmoveq	%rax,%rcx
	je	.Lj20
	cmpq	$0,(%rdi)
	jl	.Lj23
	cmpq	$0,8(%rdi)
	jnl	.Lj25
.Lj23:
	xorl	%ecx,%ecx
	jmp	.Lj20
	.p2align 4,,10
	.p2align 3
.Lj25:
	movq	(%rdi),%rax
	movq	$18446744073,%rdx
	movq	$-1,%r8
	cmpq	%rdx,%rax
	cmovaq	%r8,%rcx
	ja	.Lj20
	imulq	$1000000000,(%rdi),%rax
	movq	8(%rdi),%rdi
	movq	$-1,%rdx
	subq	%rdi,%rdx
	movq	$-1,%rcx
	cmpq	%rax,%rdx
	jb	.Lj20
	leaq	(%rax,%rdi),%rcx
.Lj20:
# Var LDeadlineNs located in register rcx
# [76] LNowNs := platform_posix_timespec_to_ns_u64(ANow);
	xorl	%eax,%eax
	testq	%rsi,%rsi
	cmoveq	%rax,%rdi
	je	.Lj30
	cmpq	$0,(%rsi)
	jl	.Lj33
	cmpq	$0,8(%rsi)
	jnl	.Lj35
.Lj33:
	xorl	%edi,%edi
	jmp	.Lj30
	.p2align 4,,10
	.p2align 3
.Lj35:
	movq	(%rsi),%rax
	movq	$18446744073,%rdx
	movq	$-1,%r8
	cmpq	%rdx,%rax
	cmovaq	%r8,%rdi
	ja	.Lj30
	imulq	$1000000000,(%rsi),%rax
	movq	8(%rsi),%rsi
	movq	$-1,%rdx
	subq	%rsi,%rdx
	movq	$-1,%rdi
	cmpq	%rax,%rdx
	jb	.Lj30
	leaq	(%rax,%rsi),%rdi
.Lj30:
# Var LNowNs located in register rdi
# [77] if LDeadlineNs <= LNowNs then
	xorl	%edx,%edx
	cmpq	%rcx,%rdi
# [78] Exit(0);
	cmovaeq	%rdx,%rax
	jae	.Lj18
# [79] Result := LDeadlineNs - LNowNs;
	subq	%rdi,%rcx
	movq	%rcx,%rax
.Lj18:
.Lc9:
# [80] end;
	ret
.Lc7:

.section .text.n_nextpas.core.platform.posix.math_$$_platform_posix_wait_exit_status$longint$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.PLATFORM.POSIX.MATH_$$_PLATFORM_POSIX_WAIT_EXIT_STATUS$LONGINT$$LONGINT
	.type	NEXTPAS.CORE.PLATFORM.POSIX.MATH_$$_PLATFORM_POSIX_WAIT_EXIT_STATUS$LONGINT$$LONGINT,@function
NEXTPAS.CORE.PLATFORM.POSIX.MATH_$$_PLATFORM_POSIX_WAIT_EXIT_STATUS$LONGINT$$LONGINT:
.Lc11:
# [83] begin
	movl	%edi,%eax
# Var AStatus located in register eax
# [84] Result := (AStatus and $FF00) shr 8;
	andl	$65280,%eax
	shrl	$8,%eax
# Var $result located in register eax
.Lc12:
# [85] end;
	ret
.Lc10:

.section .text.n_nextpas.core.platform.posix.math_$$_platform_posix_wait_term_signal$longint$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.PLATFORM.POSIX.MATH_$$_PLATFORM_POSIX_WAIT_TERM_SIGNAL$LONGINT$$LONGINT
	.type	NEXTPAS.CORE.PLATFORM.POSIX.MATH_$$_PLATFORM_POSIX_WAIT_TERM_SIGNAL$LONGINT$$LONGINT,@function
NEXTPAS.CORE.PLATFORM.POSIX.MATH_$$_PLATFORM_POSIX_WAIT_TERM_SIGNAL$LONGINT$$LONGINT:
.Lc14:
# [88] begin
	movl	%edi,%eax
# Var AStatus located in register eax
# [89] Result := AStatus and $7F;
	andl	$127,%eax
# Var $result located in register eax
.Lc15:
# [90] end;
	ret
.Lc13:

.section .text.n_nextpas.core.platform.posix.math_$$_platform_posix_wait_stop_signal$longint$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.PLATFORM.POSIX.MATH_$$_PLATFORM_POSIX_WAIT_STOP_SIGNAL$LONGINT$$LONGINT
	.type	NEXTPAS.CORE.PLATFORM.POSIX.MATH_$$_PLATFORM_POSIX_WAIT_STOP_SIGNAL$LONGINT$$LONGINT,@function
NEXTPAS.CORE.PLATFORM.POSIX.MATH_$$_PLATFORM_POSIX_WAIT_STOP_SIGNAL$LONGINT$$LONGINT:
.Lc17:
# [93] begin
	movl	%edi,%eax
# Var AStatus located in register eax
# [94] Result := platform_posix_wait_exit_status(AStatus);
	andl	$65280,%eax
	shrl	$8,%eax
# Var $result located in register eax
.Lc18:
# [95] end;
	ret
.Lc16:

.section .text.n_nextpas.core.platform.posix.math_$$_platform_posix_wait_if_exited$longint$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.PLATFORM.POSIX.MATH_$$_PLATFORM_POSIX_WAIT_IF_EXITED$LONGINT$$BOOLEAN
	.type	NEXTPAS.CORE.PLATFORM.POSIX.MATH_$$_PLATFORM_POSIX_WAIT_IF_EXITED$LONGINT$$BOOLEAN,@function
NEXTPAS.CORE.PLATFORM.POSIX.MATH_$$_PLATFORM_POSIX_WAIT_IF_EXITED$LONGINT$$BOOLEAN:
.Lc20:
# Var AStatus located in register edi
# [98] begin
# [99] Result := platform_posix_wait_term_signal(AStatus) = 0;
	andl	$127,%edi
# Var $result located in register al
	seteb	%al
.Lc21:
# [100] end;
	ret
.Lc19:

.section .text.n_nextpas.core.platform.posix.math_$$_platform_posix_wait_if_signaled$longint$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.PLATFORM.POSIX.MATH_$$_PLATFORM_POSIX_WAIT_IF_SIGNALED$LONGINT$$BOOLEAN
	.type	NEXTPAS.CORE.PLATFORM.POSIX.MATH_$$_PLATFORM_POSIX_WAIT_IF_SIGNALED$LONGINT$$BOOLEAN,@function
NEXTPAS.CORE.PLATFORM.POSIX.MATH_$$_PLATFORM_POSIX_WAIT_IF_SIGNALED$LONGINT$$BOOLEAN:
.Lc23:
# Var AStatus located in register edi
# [103] begin
# [104] Result := ((AStatus and $FF) <> $7F) and ((AStatus and $7F) <> 0);
	cmpb	$127,%dil
	setneb	%al
	andl	$127,%edi
	setneb	%dl
	andb	%dl,%al
# Var $result located in register al
.Lc24:
# [105] end;
	ret
.Lc22:

.section .text.n_nextpas.core.platform.posix.math_$$_platform_posix_wait_if_stopped$longint$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.PLATFORM.POSIX.MATH_$$_PLATFORM_POSIX_WAIT_IF_STOPPED$LONGINT$$BOOLEAN
	.type	NEXTPAS.CORE.PLATFORM.POSIX.MATH_$$_PLATFORM_POSIX_WAIT_IF_STOPPED$LONGINT$$BOOLEAN,@function
NEXTPAS.CORE.PLATFORM.POSIX.MATH_$$_PLATFORM_POSIX_WAIT_IF_STOPPED$LONGINT$$BOOLEAN:
.Lc26:
# Var AStatus located in register edi
# [108] begin
# [109] Result := (AStatus and $FF) = $7F;
	cmpb	$127,%dil
# Var $result located in register al
	seteb	%al
.Lc27:
# [110] end;
	ret
.Lc25:

.section .text.n_nextpas.core.platform.posix.math_$$_platform_posix_wait_core_dumped$longint$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.PLATFORM.POSIX.MATH_$$_PLATFORM_POSIX_WAIT_CORE_DUMPED$LONGINT$$BOOLEAN
	.type	NEXTPAS.CORE.PLATFORM.POSIX.MATH_$$_PLATFORM_POSIX_WAIT_CORE_DUMPED$LONGINT$$BOOLEAN,@function
NEXTPAS.CORE.PLATFORM.POSIX.MATH_$$_PLATFORM_POSIX_WAIT_CORE_DUMPED$LONGINT$$BOOLEAN:
.Lc29:
# Var AStatus located in register edi
# [113] begin
# [114] Result := (AStatus and PLATFORM_WAIT_CORE_FLAG) <> 0;
	andl	$128,%edi
# Var $result located in register al
	setneb	%al
.Lc30:
# [115] end;
	ret
.Lc28:

.section .text.n_nextpas.core.platform.posix.math_$$_platform_posix_wait_exit_code$longint$longint$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.PLATFORM.POSIX.MATH_$$_PLATFORM_POSIX_WAIT_EXIT_CODE$LONGINT$LONGINT$$LONGINT
	.type	NEXTPAS.CORE.PLATFORM.POSIX.MATH_$$_PLATFORM_POSIX_WAIT_EXIT_CODE$LONGINT$LONGINT$$LONGINT,@function
NEXTPAS.CORE.PLATFORM.POSIX.MATH_$$_PLATFORM_POSIX_WAIT_EXIT_CODE$LONGINT$LONGINT$$LONGINT:
.Lc32:
# [120] begin
	movl	%edi,%eax
# Var AReturnCode located in register eax
# Var ASignal located in register esi
# [121] Result := (AReturnCode shl 8) or ASignal;
	shll	$8,%eax
	orl	%esi,%eax
# Var $result located in register eax
.Lc33:
# [122] end;
	ret
.Lc31:

.section .text.n_nextpas.core.platform.posix.math_$$_platform_posix_wait_stop_code$longint$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.PLATFORM.POSIX.MATH_$$_PLATFORM_POSIX_WAIT_STOP_CODE$LONGINT$$LONGINT
	.type	NEXTPAS.CORE.PLATFORM.POSIX.MATH_$$_PLATFORM_POSIX_WAIT_STOP_CODE$LONGINT$$LONGINT,@function
NEXTPAS.CORE.PLATFORM.POSIX.MATH_$$_PLATFORM_POSIX_WAIT_STOP_CODE$LONGINT$$LONGINT:
.Lc35:
# [125] begin
	movl	%edi,%eax
# Var ASignal located in register eax
# [126] Result := (ASignal shl 8) or $7F;
	shll	$8,%eax
	orl	$127,%eax
# Var $result located in register eax
.Lc36:
# [127] end;
	ret
.Lc34:
# End asmlist al_procedures
# Begin asmlist al_dwarf_frame

.section .debug_frame
.Lc37:
	.long	.Lc39-.Lc38
.Lc38:
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
.Lc39:
	.long	.Lc41-.Lc40
.Lc40:
	.long	.Lc37
	.quad	.Lc2
	.quad	.Lc1-.Lc2
	.byte	4
	.long	.Lc3-.Lc2
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc41:
	.long	.Lc44-.Lc43
.Lc43:
	.long	.Lc37
	.quad	.Lc5
	.quad	.Lc4-.Lc5
	.byte	4
	.long	.Lc6-.Lc5
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc44:
	.long	.Lc47-.Lc46
.Lc46:
	.long	.Lc37
	.quad	.Lc8
	.quad	.Lc7-.Lc8
	.byte	4
	.long	.Lc9-.Lc8
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc47:
	.long	.Lc50-.Lc49
.Lc49:
	.long	.Lc37
	.quad	.Lc11
	.quad	.Lc10-.Lc11
	.byte	4
	.long	.Lc12-.Lc11
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc50:
	.long	.Lc53-.Lc52
.Lc52:
	.long	.Lc37
	.quad	.Lc14
	.quad	.Lc13-.Lc14
	.byte	4
	.long	.Lc15-.Lc14
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc53:
	.long	.Lc56-.Lc55
.Lc55:
	.long	.Lc37
	.quad	.Lc17
	.quad	.Lc16-.Lc17
	.byte	4
	.long	.Lc18-.Lc17
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc56:
	.long	.Lc59-.Lc58
.Lc58:
	.long	.Lc37
	.quad	.Lc20
	.quad	.Lc19-.Lc20
	.byte	4
	.long	.Lc21-.Lc20
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc59:
	.long	.Lc62-.Lc61
.Lc61:
	.long	.Lc37
	.quad	.Lc23
	.quad	.Lc22-.Lc23
	.byte	4
	.long	.Lc24-.Lc23
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc62:
	.long	.Lc65-.Lc64
.Lc64:
	.long	.Lc37
	.quad	.Lc26
	.quad	.Lc25-.Lc26
	.byte	4
	.long	.Lc27-.Lc26
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc65:
	.long	.Lc68-.Lc67
.Lc67:
	.long	.Lc37
	.quad	.Lc29
	.quad	.Lc28-.Lc29
	.byte	4
	.long	.Lc30-.Lc29
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc68:
	.long	.Lc71-.Lc70
.Lc70:
	.long	.Lc37
	.quad	.Lc32
	.quad	.Lc31-.Lc32
	.byte	4
	.long	.Lc33-.Lc32
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc71:
	.long	.Lc74-.Lc73
.Lc73:
	.long	.Lc37
	.quad	.Lc35
	.quad	.Lc34-.Lc35
	.byte	4
	.long	.Lc36-.Lc35
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc74:
# End asmlist al_dwarf_frame
.section .note.GNU-stack,"",%progbits

