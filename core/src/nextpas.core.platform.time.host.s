	.file "nextpas.core.platform.time.host.pas"
# Begin asmlist al_procedures

.section .text.n_nextpas.core.platform.time.host_$$_platform_qpc_to_ns$qword$qword$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_QPC_TO_NS$QWORD$QWORD$$QWORD
	.type	NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_QPC_TO_NS$QWORD$QWORD$$QWORD,@function
NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_QPC_TO_NS$QWORD$QWORD$$QWORD:
.Lc2:
# [nextpas.core.platform.time.host.pas]
# [67] begin
	pushq	%rax
.Lc3:
# Var ACounter located in register rdi
# Var AFrequency located in register rsi
# [68] Result := nextpas.core.platform.windows.math.windows_qpc_to_ns(ACounter, AFrequency);
	movl	$1000000000,%edx
# Var AFrequency located in register rsi
# Var ACounter located in register rdi
	call	NEXTPAS.CORE.PLATFORM.WINDOWS.MATH_$$_WINDOWS_SCALE_UNITS$QWORD$QWORD$QWORD$$QWORD
# Var $result located in register rax
# [69] end;
	popq	%rcx
.Lc4:
	ret
.Lc1:

.section .text.n_nextpas.core.platform.time.host_$$_platform_resolution_from_frequency_ns$qword$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_RESOLUTION_FROM_FREQUENCY_NS$QWORD$$QWORD
	.type	NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_RESOLUTION_FROM_FREQUENCY_NS$QWORD$$QWORD,@function
NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_RESOLUTION_FROM_FREQUENCY_NS$QWORD$$QWORD:
.Lc6:
# Var AFrequency located in register rdi
# [73] begin
# [74] Result := nextpas.core.platform.windows.math.windows_qpc_resolution_ns(AFrequency);
	movl	$1,%eax
	testq	%rdi,%rdi
	cmoveq	%rax,%rcx
	je	.Lj7
	movl	$1,%eax
	cmpq	$1000000000,%rdi
	cmovaeq	%rax,%rcx
	jae	.Lj7
	leaq	1000000000(%rdi),%rax
	subq	$1,%rax
	xorl	%edx,%edx
	divq	%rdi
	movq	%rax,%rcx
	movl	$1,%edx
	testq	%rax,%rax
	cmoveq	%rdx,%rcx
.Lj7:
# Var $result located in register rax
	movq	%rcx,%rax
.Lc7:
# [75] end;
	ret
.Lc5:

.section .text.n_nextpas.core.platform.time.host_$$_platform_timespec_to_ns$int64$int64$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_TIMESPEC_TO_NS$INT64$INT64$$QWORD
	.type	NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_TIMESPEC_TO_NS$INT64$INT64$$QWORD,@function
NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_TIMESPEC_TO_NS$INT64$INT64$$QWORD:
.Lc9:
# [82] begin
	leaq	-24(%rsp),%rsp
.Lc10:
# Var LTime located at rsp+0, size=OS_128
# Var ASec located in register rdi
# Var ANsec located in register rsi
# Var ASec located in register rdi
# [83] LTime.tv_sec := ASec;
	movq	%rdi,(%rsp)
# Var ANsec located in register rsi
# [84] LTime.tv_nsec := ANsec;
	movq	%rsi,8(%rsp)
# [85] Result := platform_posix_timespec_to_ns_u64(@LTime);
	movq	%rsp,%rdx
	xorl	%ecx,%ecx
	testq	%rsp,%rsp
	cmoveq	%rcx,%rax
	je	.Lj16
	cmpq	$0,(%rdx)
	jl	.Lj19
	cmpq	$0,8(%rdx)
	jnl	.Lj21
.Lj19:
	xorl	%eax,%eax
	jmp	.Lj16
	.p2align 4,,10
	.p2align 3
.Lj21:
	movq	(%rdx),%rcx
	movq	$18446744073,%rsi
	movq	$-1,%rdi
	cmpq	%rsi,%rcx
	cmovaq	%rdi,%rax
	ja	.Lj16
	imulq	$1000000000,(%rdx),%rcx
	movq	8(%rdx),%rsi
	movq	$-1,%rdx
	subq	%rsi,%rdx
	movq	$-1,%rax
	cmpq	%rcx,%rdx
	jb	.Lj16
	leaq	(%rcx,%rsi),%rax
.Lj16:
# Var $result located in register rax
# [86] end;
	leaq	24(%rsp),%rsp
.Lc11:
	ret
.Lc8:

.section .text.n_nextpas.core.platform.time.host_$$_platform_time_posix_clock_ns_u64$longint$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_TIME_POSIX_CLOCK_NS_U64$LONGINT$$QWORD
	.hidden NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_TIME_POSIX_CLOCK_NS_U64$LONGINT$$QWORD
	.type	NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_TIME_POSIX_CLOCK_NS_U64$LONGINT$$QWORD,@function
NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_TIME_POSIX_CLOCK_NS_U64$LONGINT$$QWORD:
.Lc13:
# [102] begin
	leaq	-24(%rsp),%rsp
.Lc14:
# Var $result located in register rax
# Var LTime located at rsp+0, size=OS_128
# Var AClockId located in register edi
# [103] if clock_gettime(AClockId, @LTime) <> 0 then
	movq	%rsp,%rsi
	call	clock_gettime
	xorl	%ecx,%ecx
	testl	%eax,%eax
# [104] Exit(0);
	cmovneq	%rcx,%rax
	jne	.Lj26
# [105] Result := platform_posix_timespec_to_ns_u64(@LTime);
	movq	%rsp,%rdx
	xorl	%ecx,%ecx
	testq	%rsp,%rsp
	cmoveq	%rcx,%rsi
	je	.Lj30
	cmpq	$0,(%rdx)
	jl	.Lj33
	cmpq	$0,8(%rdx)
	jnl	.Lj35
.Lj33:
	xorl	%esi,%esi
	jmp	.Lj30
	.p2align 4,,10
	.p2align 3
.Lj35:
	movq	(%rdx),%rcx
	movq	$18446744073,%rdi
	movq	$-1,%r8
	cmpq	%rdi,%rcx
	cmovaq	%r8,%rsi
	ja	.Lj30
	imulq	$1000000000,(%rdx),%rcx
	movq	8(%rdx),%rdi
	movq	$-1,%rdx
	subq	%rdi,%rdx
	movq	$-1,%rsi
	cmpq	%rcx,%rdx
	jb	.Lj30
	leaq	(%rcx,%rdi),%rsi
.Lj30:
	movq	%rsi,%rax
.Lj26:
# [106] end;
	leaq	24(%rsp),%rsp
.Lc15:
	ret
.Lc12:

.section .text.n_nextpas.core.platform.time.host_$$_platform_time_posix_clock_resolution_ns_u64$longint$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_TIME_POSIX_CLOCK_RESOLUTION_NS_U64$LONGINT$$QWORD
	.hidden NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_TIME_POSIX_CLOCK_RESOLUTION_NS_U64$LONGINT$$QWORD
	.type	NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_TIME_POSIX_CLOCK_RESOLUTION_NS_U64$LONGINT$$QWORD,@function
NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_TIME_POSIX_CLOCK_RESOLUTION_NS_U64$LONGINT$$QWORD:
.Lc17:
# [111] begin
	leaq	-24(%rsp),%rsp
.Lc18:
# Var $result located in register rax
# Var LTime located at rsp+0, size=OS_128
# Var AClockId located in register edi
# [112] if clock_getres(AClockId, @LTime) <> 0 then
	movq	%rsp,%rsi
	call	clock_getres
	movl	$1,%ecx
	testl	%eax,%eax
# [113] Exit(1);
	cmovneq	%rcx,%rax
	jne	.Lj40
# [114] Result := platform_posix_timespec_to_ns_u64(@LTime);
	movq	%rsp,%rdx
	xorl	%ecx,%ecx
	testq	%rsp,%rsp
	cmoveq	%rcx,%rsi
	je	.Lj44
	cmpq	$0,(%rdx)
	jl	.Lj47
	cmpq	$0,8(%rdx)
	jnl	.Lj49
.Lj47:
	xorl	%esi,%esi
	jmp	.Lj44
	.p2align 4,,10
	.p2align 3
.Lj49:
	movq	(%rdx),%rcx
	movq	$18446744073,%rdi
	movq	$-1,%r8
	cmpq	%rdi,%rcx
	cmovaq	%r8,%rsi
	ja	.Lj44
	imulq	$1000000000,(%rdx),%rcx
	movq	8(%rdx),%rdi
	movq	$-1,%rdx
	subq	%rdi,%rdx
	movq	$-1,%rsi
	cmpq	%rcx,%rdx
	jb	.Lj44
	leaq	(%rcx,%rdi),%rsi
.Lj44:
	movq	%rsi,%rax
# [115] if Result = 0 then
	movl	$1,%ecx
	testq	%rsi,%rsi
# [116] Result := 1;
	cmoveq	%rcx,%rax
.Lj40:
# [117] end;
	leaq	24(%rsp),%rsp
.Lc19:
	ret
.Lc16:

.section .text.n_nextpas.core.platform.time.host_$$_platform_time_host_clock_monotonic_ns_u64$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_TIME_HOST_CLOCK_MONOTONIC_NS_U64$$QWORD
	.hidden NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_TIME_HOST_CLOCK_MONOTONIC_NS_U64$$QWORD
	.type	NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_TIME_HOST_CLOCK_MONOTONIC_NS_U64$$QWORD,@function
NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_TIME_HOST_CLOCK_MONOTONIC_NS_U64$$QWORD:
.Lc21:
# Temps allocated between rsp+0 and rsp+16
# [329] begin
	leaq	-24(%rsp),%rsp
.Lc22:
# [333] Result := platform_time_posix_clock_ns_u64(CLOCK_MONOTONIC);
	movq	%rsp,%rsi
	movl	$1,%edi
	call	clock_gettime
	xorl	%ecx,%ecx
	testl	%eax,%eax
	cmovneq	%rcx,%rax
	jne	.Lj58
	movq	%rsp,%rdx
	xorl	%ecx,%ecx
	testq	%rsp,%rsp
	cmoveq	%rcx,%rsi
	je	.Lj61
	cmpq	$0,(%rdx)
	jl	.Lj64
	cmpq	$0,8(%rdx)
	jnl	.Lj66
.Lj64:
	xorl	%esi,%esi
	jmp	.Lj61
	.p2align 4,,10
	.p2align 3
.Lj66:
	movq	(%rdx),%rcx
	movq	$18446744073,%rdi
	movq	$-1,%r8
	cmpq	%rdi,%rcx
	cmovaq	%r8,%rsi
	ja	.Lj61
	imulq	$1000000000,(%rdx),%rcx
	movq	8(%rdx),%rdi
	movq	$-1,%rdx
	subq	%rdi,%rdx
	movq	$-1,%rsi
	cmpq	%rcx,%rdx
	jb	.Lj61
	leaq	(%rcx,%rdi),%rsi
.Lj61:
	movq	%rsi,%rax
.Lj58:
# Var $result located in register rax
# [337] end;
	leaq	24(%rsp),%rsp
.Lc23:
	ret
.Lc20:

.section .text.n_nextpas.core.platform.time.host_$$_platform_time_host_clock_realtime_ns_u64$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_TIME_HOST_CLOCK_REALTIME_NS_U64$$QWORD
	.hidden NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_TIME_HOST_CLOCK_REALTIME_NS_U64$$QWORD
	.type	NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_TIME_HOST_CLOCK_REALTIME_NS_U64$$QWORD,@function
NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_TIME_HOST_CLOCK_REALTIME_NS_U64$$QWORD:
.Lc25:
# Temps allocated between rsp+0 and rsp+16
# [340] begin
	leaq	-24(%rsp),%rsp
.Lc26:
# [342] Result := platform_time_posix_clock_ns_u64(CLOCK_REALTIME);
	movq	%rsp,%rsi
	xorl	%edi,%edi
	call	clock_gettime
	xorl	%ecx,%ecx
	testl	%eax,%eax
	cmovneq	%rcx,%rax
	jne	.Lj73
	movq	%rsp,%rdx
	xorl	%ecx,%ecx
	testq	%rsp,%rsp
	cmoveq	%rcx,%rsi
	je	.Lj76
	cmpq	$0,(%rdx)
	jl	.Lj79
	cmpq	$0,8(%rdx)
	jnl	.Lj81
.Lj79:
	xorl	%esi,%esi
	jmp	.Lj76
	.p2align 4,,10
	.p2align 3
.Lj81:
	movq	(%rdx),%rcx
	movq	$18446744073,%rdi
	movq	$-1,%r8
	cmpq	%rdi,%rcx
	cmovaq	%r8,%rsi
	ja	.Lj76
	imulq	$1000000000,(%rdx),%rcx
	movq	8(%rdx),%rdi
	movq	$-1,%rdx
	subq	%rdi,%rdx
	movq	$-1,%rsi
	cmpq	%rcx,%rdx
	jb	.Lj76
	leaq	(%rcx,%rdi),%rsi
.Lj76:
	movq	%rsi,%rax
.Lj73:
# Var $result located in register rax
# [346] end;
	leaq	24(%rsp),%rsp
.Lc27:
	ret
.Lc24:

.section .text.n_nextpas.core.platform.time.host_$$_platform_time_host_clock_monotonic_resolution_ns_u64$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_TIME_HOST_CLOCK_MONOTONIC_RESOLUTION_NS_U64$$QWORD
	.hidden NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_TIME_HOST_CLOCK_MONOTONIC_RESOLUTION_NS_U64$$QWORD
	.type	NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_TIME_HOST_CLOCK_MONOTONIC_RESOLUTION_NS_U64$$QWORD,@function
NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_TIME_HOST_CLOCK_MONOTONIC_RESOLUTION_NS_U64$$QWORD:
.Lc29:
# Temps allocated between rsp+0 and rsp+16
# [349] begin
	leaq	-24(%rsp),%rsp
.Lc30:
# [353] Result := platform_time_posix_clock_resolution_ns_u64(CLOCK_MONOTONIC);
	movq	%rsp,%rsi
	movl	$1,%edi
	call	clock_getres
	movl	$1,%ecx
	testl	%eax,%eax
	cmovneq	%rcx,%rax
	jne	.Lj88
	movq	%rsp,%rdx
	xorl	%ecx,%ecx
	testq	%rsp,%rsp
	cmoveq	%rcx,%rsi
	je	.Lj91
	cmpq	$0,(%rdx)
	jl	.Lj94
	cmpq	$0,8(%rdx)
	jnl	.Lj96
.Lj94:
	xorl	%esi,%esi
	jmp	.Lj91
	.p2align 4,,10
	.p2align 3
.Lj96:
	movq	(%rdx),%rcx
	movq	$18446744073,%rdi
	movq	$-1,%r8
	cmpq	%rdi,%rcx
	cmovaq	%r8,%rsi
	ja	.Lj91
	imulq	$1000000000,(%rdx),%rcx
	movq	8(%rdx),%rdi
	movq	$-1,%rdx
	subq	%rdi,%rdx
	movq	$-1,%rsi
	cmpq	%rcx,%rdx
	jb	.Lj91
	leaq	(%rcx,%rdi),%rsi
.Lj91:
	movq	%rsi,%rax
	movl	$1,%ecx
	testq	%rsi,%rsi
	cmoveq	%rcx,%rax
.Lj88:
# Var $result located in register rax
# [357] end;
	leaq	24(%rsp),%rsp
.Lc31:
	ret
.Lc28:

.section .text.n_nextpas.core.platform.time.host_$$_platform_monotonic_ns$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_MONOTONIC_NS$$QWORD
	.type	NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_MONOTONIC_NS$$QWORD,@function
NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_MONOTONIC_NS$$QWORD:
.Lc33:
# Temps allocated between rsp+0 and rsp+16
# [360] begin
	leaq	-24(%rsp),%rsp
.Lc34:
# [361] Result := platform_time_host_clock_monotonic_ns_u64;
	movq	%rsp,%rsi
	movl	$1,%edi
	call	clock_gettime
	xorl	%ecx,%ecx
	testl	%eax,%eax
	cmovneq	%rcx,%rax
	jne	.Lj105
	movq	%rsp,%rdx
	xorl	%ecx,%ecx
	testq	%rsp,%rsp
	cmoveq	%rcx,%rsi
	je	.Lj108
	cmpq	$0,(%rdx)
	jl	.Lj111
	cmpq	$0,8(%rdx)
	jnl	.Lj113
.Lj111:
	xorl	%esi,%esi
	jmp	.Lj108
	.p2align 4,,10
	.p2align 3
.Lj113:
	movq	(%rdx),%rcx
	movq	$18446744073,%rdi
	movq	$-1,%r8
	cmpq	%rdi,%rcx
	cmovaq	%r8,%rsi
	ja	.Lj108
	imulq	$1000000000,(%rdx),%rcx
	movq	8(%rdx),%rdi
	movq	$-1,%rdx
	subq	%rdi,%rdx
	movq	$-1,%rsi
	cmpq	%rcx,%rdx
	jb	.Lj108
	leaq	(%rcx,%rdi),%rsi
.Lj108:
	movq	%rsi,%rax
.Lj105:
# Var $result located in register rax
# [362] end;
	leaq	24(%rsp),%rsp
.Lc35:
	ret
.Lc32:

.section .text.n_nextpas.core.platform.time.host_$$_platform_realtime_ns$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_REALTIME_NS$$QWORD
	.type	NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_REALTIME_NS$$QWORD,@function
NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_REALTIME_NS$$QWORD:
.Lc37:
# Temps allocated between rsp+0 and rsp+16
# [365] begin
	leaq	-24(%rsp),%rsp
.Lc38:
# [366] Result := platform_time_host_clock_realtime_ns_u64;
	movq	%rsp,%rsi
	xorl	%edi,%edi
	call	clock_gettime
	xorl	%ecx,%ecx
	testl	%eax,%eax
	cmovneq	%rcx,%rax
	jne	.Lj120
	movq	%rsp,%rdx
	xorl	%ecx,%ecx
	testq	%rsp,%rsp
	cmoveq	%rcx,%rsi
	je	.Lj123
	cmpq	$0,(%rdx)
	jl	.Lj126
	cmpq	$0,8(%rdx)
	jnl	.Lj128
.Lj126:
	xorl	%esi,%esi
	jmp	.Lj123
	.p2align 4,,10
	.p2align 3
.Lj128:
	movq	(%rdx),%rcx
	movq	$18446744073,%rdi
	movq	$-1,%r8
	cmpq	%rdi,%rcx
	cmovaq	%r8,%rsi
	ja	.Lj123
	imulq	$1000000000,(%rdx),%rcx
	movq	8(%rdx),%rdi
	movq	$-1,%rdx
	subq	%rdi,%rdx
	movq	$-1,%rsi
	cmpq	%rcx,%rdx
	jb	.Lj123
	leaq	(%rcx,%rdi),%rsi
.Lj123:
	movq	%rsi,%rax
.Lj120:
# Var $result located in register rax
# [367] end;
	leaq	24(%rsp),%rsp
.Lc39:
	ret
.Lc36:

.section .text.n_nextpas.core.platform.time.host_$$_platform_monotonic_resolution_ns$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_MONOTONIC_RESOLUTION_NS$$QWORD
	.type	NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_MONOTONIC_RESOLUTION_NS$$QWORD,@function
NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_MONOTONIC_RESOLUTION_NS$$QWORD:
.Lc41:
# Temps allocated between rsp+0 and rsp+16
# [370] begin
	leaq	-24(%rsp),%rsp
.Lc42:
# [371] Result := platform_time_host_clock_monotonic_resolution_ns_u64;
	movq	%rsp,%rsi
	movl	$1,%edi
	call	clock_getres
	movl	$1,%ecx
	testl	%eax,%eax
	cmovneq	%rcx,%rax
	jne	.Lj135
	movq	%rsp,%rdx
	xorl	%ecx,%ecx
	testq	%rsp,%rsp
	cmoveq	%rcx,%rsi
	je	.Lj138
	cmpq	$0,(%rdx)
	jl	.Lj141
	cmpq	$0,8(%rdx)
	jnl	.Lj143
.Lj141:
	xorl	%esi,%esi
	jmp	.Lj138
	.p2align 4,,10
	.p2align 3
.Lj143:
	movq	(%rdx),%rcx
	movq	$18446744073,%rdi
	movq	$-1,%r8
	cmpq	%rdi,%rcx
	cmovaq	%r8,%rsi
	ja	.Lj138
	imulq	$1000000000,(%rdx),%rcx
	movq	8(%rdx),%rdi
	movq	$-1,%rdx
	subq	%rdi,%rdx
	movq	$-1,%rsi
	cmpq	%rcx,%rdx
	jb	.Lj138
	leaq	(%rcx,%rdi),%rsi
.Lj138:
	movq	%rsi,%rax
	movl	$1,%ecx
	testq	%rsi,%rsi
	cmoveq	%rcx,%rax
.Lj135:
# Var $result located in register rax
# [372] end;
	leaq	24(%rsp),%rsp
.Lc43:
	ret
.Lc40:
# End asmlist al_procedures
# Begin asmlist al_dwarf_frame

.section .debug_frame
.Lc44:
	.long	.Lc46-.Lc45
.Lc45:
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
.Lc46:
	.long	.Lc48-.Lc47
.Lc47:
	.long	.Lc44
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
.Lc48:
	.long	.Lc51-.Lc50
.Lc50:
	.long	.Lc44
	.quad	.Lc6
	.quad	.Lc5-.Lc6
	.byte	4
	.long	.Lc7-.Lc6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc51:
	.long	.Lc54-.Lc53
.Lc53:
	.long	.Lc44
	.quad	.Lc9
	.quad	.Lc8-.Lc9
	.byte	2
	.byte	.Lc10-.Lc9
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc11-.Lc10
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc54:
	.long	.Lc57-.Lc56
.Lc56:
	.long	.Lc44
	.quad	.Lc13
	.quad	.Lc12-.Lc13
	.byte	2
	.byte	.Lc14-.Lc13
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc15-.Lc14
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc57:
	.long	.Lc60-.Lc59
.Lc59:
	.long	.Lc44
	.quad	.Lc17
	.quad	.Lc16-.Lc17
	.byte	2
	.byte	.Lc18-.Lc17
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc19-.Lc18
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc60:
	.long	.Lc63-.Lc62
.Lc62:
	.long	.Lc44
	.quad	.Lc21
	.quad	.Lc20-.Lc21
	.byte	2
	.byte	.Lc22-.Lc21
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc23-.Lc22
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc63:
	.long	.Lc66-.Lc65
.Lc65:
	.long	.Lc44
	.quad	.Lc25
	.quad	.Lc24-.Lc25
	.byte	2
	.byte	.Lc26-.Lc25
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc27-.Lc26
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc66:
	.long	.Lc69-.Lc68
.Lc68:
	.long	.Lc44
	.quad	.Lc29
	.quad	.Lc28-.Lc29
	.byte	2
	.byte	.Lc30-.Lc29
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc31-.Lc30
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc69:
	.long	.Lc72-.Lc71
.Lc71:
	.long	.Lc44
	.quad	.Lc33
	.quad	.Lc32-.Lc33
	.byte	2
	.byte	.Lc34-.Lc33
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc35-.Lc34
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc72:
	.long	.Lc75-.Lc74
.Lc74:
	.long	.Lc44
	.quad	.Lc37
	.quad	.Lc36-.Lc37
	.byte	2
	.byte	.Lc38-.Lc37
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc39-.Lc38
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc75:
	.long	.Lc78-.Lc77
.Lc77:
	.long	.Lc44
	.quad	.Lc41
	.quad	.Lc40-.Lc41
	.byte	2
	.byte	.Lc42-.Lc41
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc43-.Lc42
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc78:
# End asmlist al_dwarf_frame
.section .note.GNU-stack,"",%progbits

