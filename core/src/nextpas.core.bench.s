	.file "nextpas.core.bench.pas"
# Begin asmlist al_procedures

.section .text.n_nextpas.core.bench$_$tbenchrunner_$__$$_create$$tbenchrunner,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.BENCH$_$TBENCHRUNNER_$__$$_CREATE$$TBENCHRUNNER
	.type	NEXTPAS.CORE.BENCH$_$TBENCHRUNNER_$__$$_CREATE$$TBENCHRUNNER,@function
NEXTPAS.CORE.BENCH$_$TBENCHRUNNER_$__$$_CREATE$$TBENCHRUNNER:
.Lc2:
# Temps allocated between rsp+24 and rsp+212
# [nextpas.core.bench.pas]
# [41] begin
	leaq	-216(%rsp),%rsp
.Lc3:
# Var $vmt located at rsp+0, size=OS_64
# Var $self located at rsp+8, size=OS_64
# Var $vmt_afterconstruction_local located at rsp+16, size=OS_S64
	movq	%rdi,8(%rsp)
	movq	%rsi,(%rsp)
	cmpq	$1,%rsi
	jne	.Lj6
	movq	8(%rsp),%rdi
	movq	%rdi,%rax
	call	*104(%rdi)
	movq	%rax,8(%rsp)
.Lj6:
	cmpq	$0,8(%rsp)
	je	.Lj3
	leaq	24(%rsp),%rdx
	leaq	48(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,112(%rsp)
	testl	%eax,%eax
	jne	.Lj13
	movq	$-1,16(%rsp)
# [42] inherited Create;
	xorl	%esi,%esi
	movq	8(%rsp),%rdi
	call	SYSTEM$_$TOBJECT_$__$$_CREATE$$TOBJECT
# [43] FCount := 0;
	movq	8(%rsp),%rax
	movl	$0,24(%rax)
# [44] SetLength(FResults, 0);
	movq	$INIT_$NEXTPAS.CORE.BENCH_$$_def00000003,%rsi
	movq	8(%rsp),%rax
	leaq	16(%rax),%rdi
	call	fpc_dynarray_clear
# [45] end;
	movq	$1,16(%rsp)
	cmpq	$0,8(%rsp)
	setneb	%al
	cmpq	$0,(%rsp)
	setneb	%dl
	andb	%dl,%al
	je	.Lj15
	movq	8(%rsp),%rdi
	movq	(%rdi),%rax
	call	*136(%rax)
.Lj15:
.Lj13:
	call	fpc_popaddrstack
	cmpl	$0,112(%rsp)
	je	.Lj11
	leaq	120(%rsp),%rdx
	leaq	144(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,208(%rsp)
	testl	%eax,%eax
	jne	.Lj16
	cmpq	$0,(%rsp)
	je	.Lj18
	movq	16(%rsp),%rsi
	movq	8(%rsp),%rdi
	movq	(%rdi),%rax
	call	*96(%rax)
.Lj18:
	call	fpc_popaddrstack
	call	fpc_reraise
.Lj16:
	call	fpc_popaddrstack
	cmpl	$0,208(%rsp)
	je	.Lj19
	call	fpc_raise_nested
.Lj19:
	call	fpc_doneexception
.Lj11:
.Lj3:
	movq	8(%rsp),%rax
	leaq	216(%rsp),%rsp
.Lc4:
	ret
.Lc1:

.section .text.n_nextpas.core.bench$_$tbenchrunner_$__$$_measurens$tbenchproc$int64$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.BENCH$_$TBENCHRUNNER_$__$$_MEASURENS$TBENCHPROC$INT64$$QWORD
	.type	NEXTPAS.CORE.BENCH$_$TBENCHRUNNER_$__$$_MEASURENS$TBENCHPROC$INT64$$QWORD,@function
NEXTPAS.CORE.BENCH$_$TBENCHRUNNER_$__$$_MEASURENS$TBENCHPROC$INT64$$QWORD:
.Lc6:
# [50] begin
	pushq	%rbx
.Lc7:
	pushq	%r12
.Lc8:
	pushq	%r13
.Lc9:
# Var $self located in register rdi
	movq	%rsi,%rbx
# Var aProc located in register rbx
	movq	%rdx,%r12
# Var aIters located in register r12
# [51] LStart := platform_monotonic_ns;
	call	NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_MONOTONIC_NS$$QWORD
	movq	%rax,%r13
# Var LStart located in register r13
# [52] aProc(aIters);
	movq	%r12,%rdi
# Var aIters located in register rdi
	call	*%rbx
# [53] LEnd := platform_monotonic_ns;
	call	NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_MONOTONIC_NS$$QWORD
# Var LEnd located in register rax
# [54] Result := LEnd - LStart;
	subq	%r13,%rax
# Var $result located in register rax
# [55] end;
	popq	%r13
.Lc10:
	popq	%r12
.Lc11:
	popq	%rbx
.Lc12:
	ret
.Lc5:
.Le0:
	.size	NEXTPAS.CORE.BENCH$_$TBENCHRUNNER_$__$$_MEASURENS$TBENCHPROC$INT64$$QWORD, .Le0 - NEXTPAS.CORE.BENCH$_$TBENCHRUNNER_$__$$_MEASURENS$TBENCHPROC$INT64$$QWORD

.section .text.n_nextpas.core.bench$_$tbenchrunner_$__$$_calibrateiterations$tbenchproc$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.BENCH$_$TBENCHRUNNER_$__$$_CALIBRATEITERATIONS$TBENCHPROC$$INT64
	.type	NEXTPAS.CORE.BENCH$_$TBENCHRUNNER_$__$$_CALIBRATEITERATIONS$TBENCHPROC$$INT64,@function
NEXTPAS.CORE.BENCH$_$TBENCHRUNNER_$__$$_CALIBRATEITERATIONS$TBENCHPROC$$INT64:
.Lc14:
# [61] begin
	pushq	%rbx
.Lc15:
	pushq	%r12
.Lc16:
	pushq	%r13
.Lc17:
	pushq	%r14
.Lc18:
	pushq	%r15
.Lc19:
# Var $result located in register r14
# Var LElapsed located in register r13
	movq	%rdi,%r15
# Var $self located in register r15
	movq	%rsi,%rbx
# Var aProc located in register rbx
# [62] aProc(WARMUP_ITERS);
	movl	$5,%edi
	movq	%rsi,%rax
	call	*%rsi
# Var LIters located in register r12
# [64] LIters := 100;
	movl	$100,%r12d
	.p2align 4,,10
	.p2align 3
.Lj24:
# [67] LElapsed := MeasureNs(aProc, LIters);
	movq	%r12,%rdx
	movq	%rbx,%rsi
	movq	%r15,%rdi
	call	NEXTPAS.CORE.BENCH$_$TBENCHRUNNER_$__$$_MEASURENS$TBENCHPROC$INT64$$QWORD
	movq	%rax,%r13
# [68] if LElapsed >= TARGET_NS then
	cmpq	$50000000,%rax
# [70] Result := LIters;
	cmovaeq	%r12,%r14
# [71] Exit;
	jae	.Lj22
# [73] if LElapsed < 1000000 then
	cmpq	$1000000,%r13
	jnb	.Lj30
# [74] LIters := LIters * 10
	leaq	(%r12,%r12,4),%rax
	shlq	$1,%rax
	movq	%rax,%r12
	jmp	.Lj31
	.p2align 4,,10
	.p2align 3
.Lj30:
# [76] LIters := Int64((Double(LIters) * Double(TARGET_NS)) / Double(LElapsed));
	cvtsi2sdq	%r12,%xmm0
	mulsd	.Ld1,%xmm0
	btq	$63,%r13
	cvtsi2sdq	%r13,%xmm1
	jnc	.Lj32
	addsd	.Ld2,%xmm1
.Lj32:
	divsd	%xmm1,%xmm0
	movq	%xmm0,%r12
.Lj31:
# [77] if LIters < 100 then
	movl	$100,%eax
	cmpq	$100,%r12
	cmovngq	%rax,%r12
# [79] if LIters > MAX_ITERS then
	cmpq	$1000,%r12
	jng	.Lj24
# [81] Result := MAX_ITERS;
	movl	$1000,%r14d
	.p2align 4,,10
	.p2align 3
.Lj22:
# [85] end;
	movq	%r14,%rax
	popq	%r15
.Lc20:
	popq	%r14
.Lc21:
	popq	%r13
.Lc22:
	popq	%r12
.Lc23:
	popq	%rbx
.Lc24:
	ret
.Lc13:
.Le1:
	.size	NEXTPAS.CORE.BENCH$_$TBENCHRUNNER_$__$$_CALIBRATEITERATIONS$TBENCHPROC$$INT64, .Le1 - NEXTPAS.CORE.BENCH$_$TBENCHRUNNER_$__$$_CALIBRATEITERATIONS$TBENCHPROC$$INT64

.section .text.n_nextpas.core.bench$_$tbenchrunner_$__$$_run$ansistring$tbenchproc,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.BENCH$_$TBENCHRUNNER_$__$$_RUN$ANSISTRING$TBENCHPROC
	.type	NEXTPAS.CORE.BENCH$_$TBENCHRUNNER_$__$$_RUN$ANSISTRING$TBENCHPROC,@function
NEXTPAS.CORE.BENCH$_$TBENCHRUNNER_$__$$_RUN$ANSISTRING$TBENCHPROC:
.Lc26:
# Temps allocated between rsp+72 and rsp+176
# [95] begin
	pushq	%rbx
.Lc27:
	pushq	%r12
.Lc28:
	pushq	%r13
.Lc29:
	pushq	%r14
.Lc30:
	pushq	%r15
.Lc31:
	leaq	-176(%rsp),%rsp
.Lc32:
# Var LIters located in register r13
# Var LSamples located at rsp+16, size=OS_NO
# Var i located in register r14d
# Var j located in register edx
# Var LTmp located in register rsi
# Var LMedianNs located in register r12
# Var LR located at rsp+40, size=OS_NO
	movq	%rdi,%rbx
# Var $self located in register rbx
	movq	%rsi,%r15
# Var aName located in register r15
	movq	%rdx,%r12
# Var aProc located in register r12
	movq	$INIT_$NEXTPAS.CORE.BENCH_$$_TBENCHRESULT,%rsi
	leaq	40(%rsp),%rdi
	call	fpc_initialize
	leaq	72(%rsp),%rdx
	leaq	96(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,160(%rsp)
	testl	%eax,%eax
	jne	.Lj38
# [96] LIters := CalibrateIterations(aProc);
	movq	%r12,%rsi
	movq	%rbx,%rdi
	call	NEXTPAS.CORE.BENCH$_$TBENCHRUNNER_$__$$_CALIBRATEITERATIONS$TBENCHPROC$$INT64
	movq	%rax,%r13
# [98] for i := 0 to SAMPLES - 1 do
	xorl	%r14d,%r14d
	.p2align 4,,10
	.p2align 3
.Lj40:
# [99] LSamples[i] := MeasureNs(aProc, LIters);
	movq	%r13,%rdx
	movq	%r12,%rsi
	movq	%rbx,%rdi
	call	NEXTPAS.CORE.BENCH$_$TBENCHRUNNER_$__$$_MEASURENS$TBENCHPROC$INT64$$QWORD
	movl	%r14d,%edx
	movq	%rax,16(%rsp,%rdx,8)
	addl	$1,%r14d
	cmpl	$2,%r14d
	jng	.Lj40
# [101] for i := 0 to SAMPLES - 2 do
	xorl	%r14d,%r14d
	.p2align 4,,10
	.p2align 3
.Lj43:
# [102] for j := i + 1 to SAMPLES - 1 do
	leal	1(%r14),%eax
	cmpl	$2,%eax
	jnle	.Lj47
	leal	1(%r14),%edx
	.p2align 4,,10
	.p2align 3
.Lj48:
# [103] if LSamples[j] < LSamples[i] then
	movl	%edx,%eax
	movl	%r14d,%ecx
	movq	16(%rsp,%rax,8),%rax
	cmpq	16(%rsp,%rcx,8),%rax
	jnb	.Lj52
# [105] LTmp := LSamples[i];
	movl	%r14d,%eax
	movq	16(%rsp,%rax,8),%rsi
# [106] LSamples[i] := LSamples[j];
	movl	%r14d,%eax
	movl	%edx,%ecx
	movq	16(%rsp,%rcx,8),%rcx
	movq	%rcx,16(%rsp,%rax,8)
# [107] LSamples[j] := LTmp;
	movl	%edx,%eax
	movq	%rsi,16(%rsp,%rax,8)
.Lj52:
	addl	$1,%edx
	cmpl	$2,%edx
	jng	.Lj48
.Lj47:
	addl	$1,%r14d
	cmpl	$1,%r14d
	jng	.Lj43
# [110] LMedianNs := LSamples[SAMPLES div 2];
	movq	24(%rsp),%r12
# [112] LR.Name := aName;
	leaq	40(%rsp),%rdi
	movq	%r15,%rsi
	call	fpc_ansistr_assign
# [113] LR.Iterations := LIters;
	movq	%r13,48(%rsp)
# [114] LR.NsPerOp := Double(LMedianNs) / Double(LIters);
	btq	$63,%r12
	cvtsi2sdq	%r12,%xmm0
	jnc	.Lj53
	addsd	.Ld3,%xmm0
.Lj53:
	cvtsi2sdq	%r13,%xmm1
	divsd	%xmm1,%xmm0
	movsd	%xmm0,56(%rsp)
# [115] if LR.NsPerOp > 0 then
	xorpd	%xmm0,%xmm0
	comisd	56(%rsp),%xmm0
	jp	.Lj55
	jnb	.Lj55
# [116] LR.OpsPerSec := 1000000000.0 / LR.NsPerOp
	movsd	.Ld4,%xmm0
	divsd	56(%rsp),%xmm0
	movsd	%xmm0,64(%rsp)
	jmp	.Lj57
	.p2align 4,,10
	.p2align 3
.Lj55:
# [118] LR.OpsPerSec := 0;
	xorpd	%xmm0,%xmm0
	movsd	%xmm0,64(%rsp)
.Lj57:
# [120] Inc(FCount);
	addl	$1,24(%rbx)
# [121] SetLength(FResults, FCount);
	movslq	24(%rbx),%rax
	movq	%rax,168(%rsp)
	leaq	168(%rsp),%rcx
	movq	$INIT_$NEXTPAS.CORE.BENCH_$$_def00000003,%rsi
	leaq	16(%rbx),%rdi
	movl	$1,%edx
	call	fpc_dynarray_setlength
# [122] FResults[FCount - 1] := LR;
	movq	$INIT_$NEXTPAS.CORE.BENCH_$$_TBENCHRESULT,%rdx
	movq	16(%rbx),%rcx
	movslq	24(%rbx),%rax
	shlq	$5,%rax
	leaq	-32(%rcx,%rax),%rsi
	leaq	40(%rsp),%rdi
	call	FPC_COPY
# [124] WriteLn('  ', aName:40, LIters:12, ' iters', LR.NsPerOp:10:1, ' ns/op', LR.OpsPerSec:14:0, ' ops/s');
	call	fpc_get_output
	movq	%rax,%rbx
	movq	$.Ld5,%rdx
	movq	%rax,%rsi
	xorl	%edi,%edi
	call	fpc_write_text_shortstr
	call	fpc_iocheck
	movq	%rbx,%rsi
	movq	%r15,%rdx
	movl	$40,%edi
	call	fpc_write_text_ansistr
	call	fpc_iocheck
	movq	%rbx,%rsi
	movq	%r13,%rdx
	movl	$12,%edi
	call	fpc_write_text_sint
	call	fpc_iocheck
	movq	$.Ld6,%rdx
	movq	%rbx,%rsi
	xorl	%edi,%edi
	call	fpc_write_text_shortstr
	call	fpc_iocheck
	fldl	56(%rsp)
	fstpt	(%rsp)
	movq	%rbx,%rcx
	movl	$10,%edx
	movl	$1,%esi
	movl	$1,%edi
	call	fpc_write_text_float
	call	fpc_iocheck
	movq	$.Ld7,%rdx
	movq	%rbx,%rsi
	xorl	%edi,%edi
	call	fpc_write_text_shortstr
	call	fpc_iocheck
	fldl	64(%rsp)
	fstpt	(%rsp)
	movq	%rbx,%rcx
	movl	$14,%edx
	xorl	%esi,%esi
	movl	$1,%edi
	call	fpc_write_text_float
	call	fpc_iocheck
	movq	$.Ld8,%rdx
	movq	%rbx,%rsi
	xorl	%edi,%edi
	call	fpc_write_text_shortstr
	call	fpc_iocheck
	movq	%rbx,%rdi
	call	fpc_writeln_end
	call	fpc_iocheck
.Lj38:
	call	fpc_popaddrstack
# [125] end;
	movq	$INIT_$NEXTPAS.CORE.BENCH_$$_TBENCHRESULT,%rsi
	leaq	40(%rsp),%rdi
	call	fpc_finalize
	cmpl	$0,160(%rsp)
	je	.Lj37
	call	fpc_reraise
	movl	$0,160(%rsp)
	jmp	.Lj38
.Lj37:
	leaq	176(%rsp),%rsp
	popq	%r15
.Lc33:
	popq	%r14
.Lc34:
	popq	%r13
.Lc35:
	popq	%r12
.Lc36:
	popq	%rbx
.Lc37:
	ret
.Lc25:

.section .text.n_nextpas.core.bench$_$tbenchrunner_$__$$_summary,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.BENCH$_$TBENCHRUNNER_$__$$_SUMMARY
	.type	NEXTPAS.CORE.BENCH$_$TBENCHRUNNER_$__$$_SUMMARY,@function
NEXTPAS.CORE.BENCH$_$TBENCHRUNNER_$__$$_SUMMARY:
.Lc39:
# [130] begin
	pushq	%rbx
.Lc40:
	pushq	%r12
.Lc41:
	pushq	%r13
.Lc42:
	pushq	%r14
.Lc43:
	leaq	-24(%rsp),%rsp
.Lc44:
# Var i located in register r14d
	movq	%rdi,%rbx
# Var $self located in register rbx
# [131] WriteLn;
	call	fpc_get_output
	movq	%rax,%rdi
	call	fpc_writeln_end
	call	fpc_iocheck
# [132] WriteLn('=== SUMMARY ===');
	call	fpc_get_output
	movq	%rax,%r12
	movq	$.Ld9,%rdx
	movq	%rax,%rsi
	xorl	%edi,%edi
	call	fpc_write_text_shortstr
	call	fpc_iocheck
	movq	%r12,%rdi
	call	fpc_writeln_end
	call	fpc_iocheck
# [133] WriteLn('  ', 'Benchmark':40, 'ns/op':10, 'ops/s':14);
	call	fpc_get_output
	movq	%rax,%r12
	movq	$.Ld5,%rdx
	movq	%rax,%rsi
	xorl	%edi,%edi
	call	fpc_write_text_shortstr
	call	fpc_iocheck
	movq	$.Ld10,%rdx
	movq	%r12,%rsi
	movl	$40,%edi
	call	fpc_write_text_shortstr
	call	fpc_iocheck
	movq	$.Ld11,%rdx
	movq	%r12,%rsi
	movl	$10,%edi
	call	fpc_write_text_shortstr
	call	fpc_iocheck
	movq	$.Ld12,%rdx
	movq	%r12,%rsi
	movl	$14,%edi
	call	fpc_write_text_shortstr
	call	fpc_iocheck
	movq	%r12,%rdi
	call	fpc_writeln_end
	call	fpc_iocheck
# [134] WriteLn('  ', '':40, '':10, '':14);
	call	fpc_get_output
	movq	%rax,%r12
	movq	$.Ld5,%rdx
	movq	%rax,%rsi
	xorl	%edi,%edi
	call	fpc_write_text_shortstr
	call	fpc_iocheck
	movq	$.Ld13,%rdx
	movq	%r12,%rsi
	movl	$40,%edi
	call	fpc_write_text_shortstr
	call	fpc_iocheck
	movq	$.Ld13,%rdx
	movq	%r12,%rsi
	movl	$10,%edi
	call	fpc_write_text_shortstr
	call	fpc_iocheck
	movq	$.Ld13,%rdx
	movq	%r12,%rsi
	movl	$14,%edi
	call	fpc_write_text_shortstr
	call	fpc_iocheck
	movq	%r12,%rdi
	call	fpc_writeln_end
	call	fpc_iocheck
# [135] for i := 0 to FCount - 1 do
	movl	24(%rbx),%eax
	leal	-1(%rax),%r12d
	testl	%r12d,%r12d
	jnge	.Lj61
	movl	$-1,%r14d
	.p2align 4,,10
	.p2align 3
.Lj62:
	addl	$1,%r14d
# [136] WriteLn('  ', FResults[i].Name:40, FResults[i].NsPerOp:10:1, FResults[i].OpsPerSec:14:0);
	call	fpc_get_output
	movq	%rax,%r13
	movq	$.Ld5,%rdx
	movq	%rax,%rsi
	xorl	%edi,%edi
	call	fpc_write_text_shortstr
	call	fpc_iocheck
	movq	16(%rbx),%rdx
	movslq	%r14d,%rax
	shlq	$5,%rax
	movq	(%rdx,%rax),%rdx
	movq	%r13,%rsi
	movl	$40,%edi
	call	fpc_write_text_ansistr
	call	fpc_iocheck
	movq	16(%rbx),%rdx
	movslq	%r14d,%rax
	shlq	$5,%rax
	fldl	16(%rdx,%rax)
	fstpt	(%rsp)
	movq	%r13,%rcx
	movl	$10,%edx
	movl	$1,%esi
	movl	$1,%edi
	call	fpc_write_text_float
	call	fpc_iocheck
	movq	16(%rbx),%rdx
	movslq	%r14d,%rax
	shlq	$5,%rax
	fldl	24(%rdx,%rax)
	fstpt	(%rsp)
	movq	%r13,%rcx
	movl	$14,%edx
	xorl	%esi,%esi
	movl	$1,%edi
	call	fpc_write_text_float
	call	fpc_iocheck
	movq	%r13,%rdi
	call	fpc_writeln_end
	call	fpc_iocheck
	cmpl	%r14d,%r12d
	jnle	.Lj62
.Lj61:
# [137] end;
	leaq	24(%rsp),%rsp
	popq	%r14
.Lc45:
	popq	%r13
.Lc46:
	popq	%r12
.Lc47:
	popq	%rbx
.Lc48:
	ret
.Lc38:
# End asmlist al_procedures
# Begin asmlist al_globals

.section .rodata.n_VMT_$NEXTPAS.CORE.BENCH_$$_TBENCHRUNNER
	.balign 8
.globl	VMT_$NEXTPAS.CORE.BENCH_$$_TBENCHRUNNER
	.type	VMT_$NEXTPAS.CORE.BENCH_$$_TBENCHRUNNER,@object
VMT_$NEXTPAS.CORE.BENCH_$$_TBENCHRUNNER:
	.quad	32,-32
	.quad	VMT_$SYSTEM_$$_TOBJECT$indirect
	.quad	.Ld14
	.quad	0,0,0
	.quad	RTTI_$NEXTPAS.CORE.BENCH_$$_TBENCHRUNNER
	.quad	INIT_$NEXTPAS.CORE.BENCH_$$_TBENCHRUNNER
	.quad	0,0,0
	.quad	SYSTEM$_$TOBJECT_$__$$_DESTROY
	.quad	SYSTEM$_$TOBJECT_$__$$_NEWINSTANCE$$TOBJECT
	.quad	SYSTEM$_$TOBJECT_$__$$_FREEINSTANCE
	.quad	SYSTEM$_$TOBJECT_$__$$_SAFECALLEXCEPTION$TOBJECT$POINTER$$HRESULT
	.quad	FPC_EMPTYMETHOD
	.quad	FPC_EMPTYMETHOD
	.quad	FPC_EMPTYMETHOD
	.quad	FPC_EMPTYMETHOD
	.quad	SYSTEM$_$TOBJECT_$__$$_DISPATCH$formal
	.quad	SYSTEM$_$TOBJECT_$__$$_DISPATCHSTR$formal
	.quad	SYSTEM$_$TOBJECT_$__$$_EQUALS$TOBJECT$$BOOLEAN
	.quad	SYSTEM$_$TOBJECT_$__$$_GETHASHCODE$$INT64
	.quad	SYSTEM$_$TOBJECT_$__$$_TOSTRING$$ANSISTRING
	.quad	0
# [139] end.
.Le2:
	.size	VMT_$NEXTPAS.CORE.BENCH_$$_TBENCHRUNNER, .Le2 - VMT_$NEXTPAS.CORE.BENCH_$$_TBENCHRUNNER
# End asmlist al_globals
# Begin asmlist al_const

.section .rodata.n_VMT_$NEXTPAS.CORE.BENCH_$$_TBENCHRUNNER
	.balign 8
.Ld14:
	.byte	12
	.ascii	"TBenchRunner"
.Le3:
	.size	.Ld14, .Le3 - .Ld14
# End asmlist al_const
# Begin asmlist al_typedconsts

.section .rodata.n_.Ld1
	.balign 8
.Ld1:
# s64bit real value: 0d+5.0000000000000000E+007
	.byte	0,0,0,0,132,215,135,65
# [76] LIters := Int64((Double(LIters) * Double(TARGET_NS)) / Double(LElapsed));
.Le4:
	.size	.Ld1, .Le4 - .Ld1

.section .rodata.n_.Ld2
	.balign 8
.Ld2:
	.long	0,1139802112

.section .rodata.n_.Ld3
	.balign 8
.Ld3:
	.long	0,1139802112

.section .rodata.n_.Ld4
	.balign 8
.Ld4:
# s64bit real value: 0d+1.0000000000000000E+009
	.byte	0,0,0,0,101,205,205,65
# [116] LR.OpsPerSec := 1000000000.0 / LR.NsPerOp
.Le5:
	.size	.Ld4, .Le5 - .Ld4

.section .rodata.n_.Ld5
	.balign 8
.Ld5:
	.byte	2
# [124] WriteLn('  ', aName:40, LIters:12, ' iters', LR.NsPerOp:10:1, ' ns/op', LR.OpsPerSec:14:0, ' ops/s');
	.ascii	"  \000"
.Le6:
	.size	.Ld5, .Le6 - .Ld5

.section .rodata.n_.Ld6
	.balign 8
.Ld6:
	.byte	6
	.ascii	" iters\000"
.Le7:
	.size	.Ld6, .Le7 - .Ld6

.section .rodata.n_.Ld7
	.balign 8
.Ld7:
	.byte	6
	.ascii	" ns/op\000"
.Le8:
	.size	.Ld7, .Le8 - .Ld7

.section .rodata.n_.Ld8
	.balign 8
.Ld8:
	.byte	6
	.ascii	" ops/s\000"
.Le9:
	.size	.Ld8, .Le9 - .Ld8

.section .rodata.n_.Ld9
	.balign 8
.Ld9:
	.byte	15
# [132] WriteLn('=== SUMMARY ===');
	.ascii	"=== SUMMARY ===\000"
.Le10:
	.size	.Ld9, .Le10 - .Ld9

.section .rodata.n_.Ld10
	.balign 8
.Ld10:
	.byte	9
# [133] WriteLn('  ', 'Benchmark':40, 'ns/op':10, 'ops/s':14);
	.ascii	"Benchmark\000"
.Le11:
	.size	.Ld10, .Le11 - .Ld10

.section .rodata.n_.Ld11
	.balign 8
.Ld11:
	.byte	5
	.ascii	"ns/op\000"
.Le12:
	.size	.Ld11, .Le12 - .Ld11

.section .rodata.n_.Ld12
	.balign 8
.Ld12:
	.byte	5
	.ascii	"ops/s\000"
.Le13:
	.size	.Ld12, .Le13 - .Ld12

.section .rodata.n_.Ld13
	.balign 8
.Ld13:
	.byte	0
# [134] WriteLn('  ', '':40, '':10, '':14);
	.ascii	"\000"
.Le14:
	.size	.Ld13, .Le14 - .Ld13
# End asmlist al_typedconsts
# Begin asmlist al_rtti

.section .rodata.n_RTTI_$NEXTPAS.CORE.BENCH_$$_TBENCHPROC
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BENCH_$$_TBENCHPROC
	.type	RTTI_$NEXTPAS.CORE.BENCH_$$_TBENCHPROC,@object
RTTI_$NEXTPAS.CORE.BENCH_$$_TBENCHPROC:
	.byte	23,10
# [139] end.
	.ascii	"TBenchProc"
	.quad	0
	.byte	0,0
	.quad	0
	.byte	1
	.short	0
	.quad	RTTI_$SYSTEM_$$_INT64$indirect
	.byte	6
	.ascii	"aIters"
.Le15:
	.size	RTTI_$NEXTPAS.CORE.BENCH_$$_TBENCHPROC, .Le15 - RTTI_$NEXTPAS.CORE.BENCH_$$_TBENCHPROC

.section .rodata.n_INIT_$NEXTPAS.CORE.BENCH_$$_TBENCHRESULT
	.balign 8
.globl	INIT_$NEXTPAS.CORE.BENCH_$$_TBENCHRESULT
	.type	INIT_$NEXTPAS.CORE.BENCH_$$_TBENCHRESULT,@object
INIT_$NEXTPAS.CORE.BENCH_$$_TBENCHRESULT:
	.byte	13,12
	.ascii	"TBenchResult"
	.quad	0,0
	.long	32
	.quad	0,0
	.long	1
	.quad	RTTI_$SYSTEM_$$_ANSISTRING$indirect
	.quad	0
.Le16:
	.size	INIT_$NEXTPAS.CORE.BENCH_$$_TBENCHRESULT, .Le16 - INIT_$NEXTPAS.CORE.BENCH_$$_TBENCHRESULT

.section .rodata.n_RTTI_$NEXTPAS.CORE.BENCH_$$_TBENCHRESULT
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BENCH_$$_TBENCHRESULT
	.type	RTTI_$NEXTPAS.CORE.BENCH_$$_TBENCHRESULT,@object
RTTI_$NEXTPAS.CORE.BENCH_$$_TBENCHRESULT:
	.byte	13,12
	.ascii	"TBenchResult"
	.quad	0
	.quad	INIT_$NEXTPAS.CORE.BENCH_$$_TBENCHRESULT
	.long	32,4
	.quad	RTTI_$SYSTEM_$$_ANSISTRING$indirect
	.quad	0
	.quad	RTTI_$SYSTEM_$$_INT64$indirect
	.quad	8
	.quad	RTTI_$SYSTEM_$$_DOUBLE$indirect
	.quad	16
	.quad	RTTI_$SYSTEM_$$_DOUBLE$indirect
	.quad	24
	.short	0,0,0
.Le17:
	.size	RTTI_$NEXTPAS.CORE.BENCH_$$_TBENCHRESULT, .Le17 - RTTI_$NEXTPAS.CORE.BENCH_$$_TBENCHRESULT

.section .rodata.n_INIT_$NEXTPAS.CORE.BENCH_$$_def00000003
	.balign 8
.globl	INIT_$NEXTPAS.CORE.BENCH_$$_def00000003
	.type	INIT_$NEXTPAS.CORE.BENCH_$$_def00000003,@object
INIT_$NEXTPAS.CORE.BENCH_$$_def00000003:
	.byte	21,0
	.quad	0,32
	.quad	INIT_$NEXTPAS.CORE.BENCH_$$_TBENCHRESULT$indirect
	.long	-1
	.quad	INIT_$NEXTPAS.CORE.BENCH_$$_TBENCHRESULT$indirect
	.byte	18
	.ascii	"nextpas.core.bench"
.Le18:
	.size	INIT_$NEXTPAS.CORE.BENCH_$$_def00000003, .Le18 - INIT_$NEXTPAS.CORE.BENCH_$$_def00000003

.section .rodata.n_INIT_$NEXTPAS.CORE.BENCH_$$_TBENCHRUNNER
	.balign 8
.globl	INIT_$NEXTPAS.CORE.BENCH_$$_TBENCHRUNNER
	.type	INIT_$NEXTPAS.CORE.BENCH_$$_TBENCHRUNNER,@object
INIT_$NEXTPAS.CORE.BENCH_$$_TBENCHRUNNER:
	.byte	15,12
	.ascii	"TBenchRunner"
	.quad	0,0
	.long	8
	.quad	0,0
	.long	1
	.quad	INIT_$NEXTPAS.CORE.BENCH_$$_def00000003$indirect
	.quad	16
.Le19:
	.size	INIT_$NEXTPAS.CORE.BENCH_$$_TBENCHRUNNER, .Le19 - INIT_$NEXTPAS.CORE.BENCH_$$_TBENCHRUNNER

.section .rodata.n_RTTI_$NEXTPAS.CORE.BENCH_$$_TBENCHRUNNER
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BENCH_$$_TBENCHRUNNER
	.type	RTTI_$NEXTPAS.CORE.BENCH_$$_TBENCHRUNNER,@object
RTTI_$NEXTPAS.CORE.BENCH_$$_TBENCHRUNNER:
	.byte	15,12
	.ascii	"TBenchRunner"
	.quad	0
	.quad	VMT_$NEXTPAS.CORE.BENCH_$$_TBENCHRUNNER
	.quad	RTTI_$SYSTEM_$$_TOBJECT$indirect
	.short	0
	.byte	18
	.ascii	"nextpas.core.bench"
	.short	0,0
.Le20:
	.size	RTTI_$NEXTPAS.CORE.BENCH_$$_TBENCHRUNNER, .Le20 - RTTI_$NEXTPAS.CORE.BENCH_$$_TBENCHRUNNER
# End asmlist al_rtti
# Begin asmlist al_indirectglobals

.section .rodata.n_VMT_$NEXTPAS.CORE.BENCH_$$_TBENCHRUNNER
	.balign 8
.globl	VMT_$NEXTPAS.CORE.BENCH_$$_TBENCHRUNNER$indirect
	.type	VMT_$NEXTPAS.CORE.BENCH_$$_TBENCHRUNNER$indirect,@object
VMT_$NEXTPAS.CORE.BENCH_$$_TBENCHRUNNER$indirect:
	.quad	VMT_$NEXTPAS.CORE.BENCH_$$_TBENCHRUNNER
.Le21:
	.size	VMT_$NEXTPAS.CORE.BENCH_$$_TBENCHRUNNER$indirect, .Le21 - VMT_$NEXTPAS.CORE.BENCH_$$_TBENCHRUNNER$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.BENCH_$$_TBENCHPROC
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BENCH_$$_TBENCHPROC$indirect
	.type	RTTI_$NEXTPAS.CORE.BENCH_$$_TBENCHPROC$indirect,@object
RTTI_$NEXTPAS.CORE.BENCH_$$_TBENCHPROC$indirect:
	.quad	RTTI_$NEXTPAS.CORE.BENCH_$$_TBENCHPROC
.Le22:
	.size	RTTI_$NEXTPAS.CORE.BENCH_$$_TBENCHPROC$indirect, .Le22 - RTTI_$NEXTPAS.CORE.BENCH_$$_TBENCHPROC$indirect

.section .rodata.n_INIT_$NEXTPAS.CORE.BENCH_$$_TBENCHRESULT
	.balign 8
.globl	INIT_$NEXTPAS.CORE.BENCH_$$_TBENCHRESULT$indirect
	.type	INIT_$NEXTPAS.CORE.BENCH_$$_TBENCHRESULT$indirect,@object
INIT_$NEXTPAS.CORE.BENCH_$$_TBENCHRESULT$indirect:
	.quad	INIT_$NEXTPAS.CORE.BENCH_$$_TBENCHRESULT
.Le23:
	.size	INIT_$NEXTPAS.CORE.BENCH_$$_TBENCHRESULT$indirect, .Le23 - INIT_$NEXTPAS.CORE.BENCH_$$_TBENCHRESULT$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.BENCH_$$_TBENCHRESULT
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BENCH_$$_TBENCHRESULT$indirect
	.type	RTTI_$NEXTPAS.CORE.BENCH_$$_TBENCHRESULT$indirect,@object
RTTI_$NEXTPAS.CORE.BENCH_$$_TBENCHRESULT$indirect:
	.quad	RTTI_$NEXTPAS.CORE.BENCH_$$_TBENCHRESULT
.Le24:
	.size	RTTI_$NEXTPAS.CORE.BENCH_$$_TBENCHRESULT$indirect, .Le24 - RTTI_$NEXTPAS.CORE.BENCH_$$_TBENCHRESULT$indirect

.section .rodata.n_INIT_$NEXTPAS.CORE.BENCH_$$_def00000003
	.balign 8
.globl	INIT_$NEXTPAS.CORE.BENCH_$$_def00000003$indirect
	.type	INIT_$NEXTPAS.CORE.BENCH_$$_def00000003$indirect,@object
INIT_$NEXTPAS.CORE.BENCH_$$_def00000003$indirect:
	.quad	INIT_$NEXTPAS.CORE.BENCH_$$_def00000003
.Le25:
	.size	INIT_$NEXTPAS.CORE.BENCH_$$_def00000003$indirect, .Le25 - INIT_$NEXTPAS.CORE.BENCH_$$_def00000003$indirect

.section .rodata.n_INIT_$NEXTPAS.CORE.BENCH_$$_TBENCHRUNNER
	.balign 8
.globl	INIT_$NEXTPAS.CORE.BENCH_$$_TBENCHRUNNER$indirect
	.type	INIT_$NEXTPAS.CORE.BENCH_$$_TBENCHRUNNER$indirect,@object
INIT_$NEXTPAS.CORE.BENCH_$$_TBENCHRUNNER$indirect:
	.quad	INIT_$NEXTPAS.CORE.BENCH_$$_TBENCHRUNNER
.Le26:
	.size	INIT_$NEXTPAS.CORE.BENCH_$$_TBENCHRUNNER$indirect, .Le26 - INIT_$NEXTPAS.CORE.BENCH_$$_TBENCHRUNNER$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.BENCH_$$_TBENCHRUNNER
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BENCH_$$_TBENCHRUNNER$indirect
	.type	RTTI_$NEXTPAS.CORE.BENCH_$$_TBENCHRUNNER$indirect,@object
RTTI_$NEXTPAS.CORE.BENCH_$$_TBENCHRUNNER$indirect:
	.quad	RTTI_$NEXTPAS.CORE.BENCH_$$_TBENCHRUNNER
.Le27:
	.size	RTTI_$NEXTPAS.CORE.BENCH_$$_TBENCHRUNNER$indirect, .Le27 - RTTI_$NEXTPAS.CORE.BENCH_$$_TBENCHRUNNER$indirect
# End asmlist al_indirectglobals
# Begin asmlist al_dwarf_frame

.section .debug_frame
.Lc49:
	.long	.Lc51-.Lc50
.Lc50:
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
.Lc51:
	.long	.Lc53-.Lc52
.Lc52:
	.long	.Lc49
	.quad	.Lc2
	.quad	.Lc1-.Lc2
	.byte	2
	.byte	.Lc3-.Lc2
	.byte	14
	.uleb128	224
	.byte	4
	.long	.Lc4-.Lc3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc53:
	.long	.Lc56-.Lc55
.Lc55:
	.long	.Lc49
	.quad	.Lc6
	.quad	.Lc5-.Lc6
	.byte	2
	.byte	.Lc7-.Lc6
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc8-.Lc7
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc9-.Lc8
	.byte	5
	.uleb128	13
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc10-.Lc9
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc11-.Lc10
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc12-.Lc11
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc56:
	.long	.Lc59-.Lc58
.Lc58:
	.long	.Lc49
	.quad	.Lc14
	.quad	.Lc13-.Lc14
	.byte	2
	.byte	.Lc15-.Lc14
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc16-.Lc15
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc17-.Lc16
	.byte	5
	.uleb128	13
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc18-.Lc17
	.byte	5
	.uleb128	14
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc19-.Lc18
	.byte	5
	.uleb128	15
	.uleb128	12
	.byte	14
	.uleb128	48
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc20-.Lc19
	.byte	6
	.uleb128	15
	.byte	2
	.byte	.Lc21-.Lc20
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc22-.Lc21
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc23-.Lc22
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc24-.Lc23
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc59:
	.long	.Lc62-.Lc61
.Lc61:
	.long	.Lc49
	.quad	.Lc26
	.quad	.Lc25-.Lc26
	.byte	2
	.byte	.Lc27-.Lc26
	.byte	5
	.uleb128	3
	.uleb128	48
	.byte	14
	.uleb128	192
	.byte	2
	.byte	.Lc28-.Lc27
	.byte	5
	.uleb128	12
	.uleb128	50
	.byte	14
	.uleb128	200
	.byte	2
	.byte	.Lc29-.Lc28
	.byte	5
	.uleb128	13
	.uleb128	52
	.byte	14
	.uleb128	208
	.byte	2
	.byte	.Lc30-.Lc29
	.byte	5
	.uleb128	14
	.uleb128	54
	.byte	14
	.uleb128	216
	.byte	2
	.byte	.Lc31-.Lc30
	.byte	5
	.uleb128	15
	.uleb128	56
	.byte	14
	.uleb128	224
	.byte	2
	.byte	.Lc32-.Lc31
	.byte	14
	.uleb128	224
	.byte	4
	.long	.Lc33-.Lc32
	.byte	6
	.uleb128	15
	.byte	2
	.byte	.Lc34-.Lc33
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc35-.Lc34
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc36-.Lc35
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc37-.Lc36
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc62:
	.long	.Lc65-.Lc64
.Lc64:
	.long	.Lc49
	.quad	.Lc39
	.quad	.Lc38-.Lc39
	.byte	2
	.byte	.Lc40-.Lc39
	.byte	5
	.uleb128	3
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc41-.Lc40
	.byte	5
	.uleb128	12
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc42-.Lc41
	.byte	5
	.uleb128	13
	.uleb128	12
	.byte	14
	.uleb128	48
	.byte	2
	.byte	.Lc43-.Lc42
	.byte	5
	.uleb128	14
	.uleb128	14
	.byte	14
	.uleb128	56
	.byte	2
	.byte	.Lc44-.Lc43
	.byte	14
	.uleb128	64
	.byte	4
	.long	.Lc45-.Lc44
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc46-.Lc45
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc47-.Lc46
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc48-.Lc47
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc65:
# End asmlist al_dwarf_frame
.section .note.GNU-stack,"",%progbits

