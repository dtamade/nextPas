	.file "nextpas.core.mem.utils.pas"
# Begin asmlist al_procedures

.section .text.n_nextpas.core.mem.utils_$$_isoverlap$pointer$qword$pointer$qword$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.UTILS_$$_ISOVERLAP$POINTER$QWORD$POINTER$QWORD$$BOOLEAN
	.type	NEXTPAS.CORE.MEM.UTILS_$$_ISOVERLAP$POINTER$QWORD$POINTER$QWORD$$BOOLEAN,@function
NEXTPAS.CORE.MEM.UTILS_$$_ISOVERLAP$POINTER$QWORD$POINTER$QWORD$$BOOLEAN:
.Lc2:
# Temps allocated between rbp-88 and rbp+0
# [nextpas.core.mem.utils.pas]
# [817] begin
	pushq	%rbp
.Lc3:
	movq	%rsp,%rbp
.Lc4:
	leaq	-96(%rsp),%rsp
	movq	%rbx,-88(%rbp)
	movq	%r12,-80(%rbp)
	movq	%r13,-72(%rbp)
	movq	%r14,-64(%rbp)
	movq	%r15,-56(%rbp)
# Var $result located in stack [rbp-48]
# Var aPtr1 located in register rdi
	movq	%rsi,%r15
# Var aSize1 located in register r15
# Var aPtr2 located in register rdx
	movq	%rcx,%r13
# Var aSize2 located in register r13
# [818] if (aPtr1 = nil) or (aPtr2 = nil) or (aSize1 = 0) or (aSize2 = 0) then
	testq	%rdi,%rdi
	seteb	%al
	testq	%rdx,%rdx
	seteb	%cl
	orb	%cl,%al
	testq	%r15,%r15
	seteb	%cl
	orb	%cl,%al
	testq	%r13,%r13
	seteb	%cl
	orb	%cl,%al
	je	.Lj6
# [819] Exit(False);
	movb	$0,-48(%rbp)
	jmp	.Lj3
	.p2align 4,,10
	.p2align 3
.Lj6:
# Var LStart1 located in register rax
# [824] LStart1 := PtrUInt(aPtr1);
	movq	%rdi,%r14
# Var aPtr1 located in register r14
	movq	%rdi,%rax
# Var LStart2 located in register rbx
# [825] LStart2 := PtrUInt(aPtr2);
	movq	%rdx,%r12
# Var aPtr2 located in register r12
	movq	%rdx,%rbx
# [830] if IsAddOverflow(LStart1, aSize1) then
	movq	$-1,%rdx
	subq	%r15,%rdx
	cmpq	%rax,%rdx
	jnb	.Lj8
.Lj9:
# [831] raise EOutOfRange.CreateFmt('aSize1 (%d) is too large for aPtr1 (%p), causing address calculation to overflow.', [aSize1, aPtr1]);
	movq	%r15,-40(%rbp)
	leaq	-40(%rbp),%rax
	movq	%rax,-24(%rbp)
	movq	$17,-32(%rbp)
	movq	%r14,-8(%rbp)
	movq	$5,-16(%rbp)
	leaq	-32(%rbp),%rcx
	movq	$.Ld1,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE,%rdi
	movl	$1,%r8d
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATEFMT$ANSISTRING$array_of_const$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj9,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj8:
# [833] if IsAddOverflow(LStart2, aSize2) then
	movq	$-1,%rax
	subq	%r13,%rax
	cmpq	%rbx,%rax
	jnb	.Lj11
.Lj12:
# [834] raise EOutOfRange.CreateFmt('aSize2 (%d) is too large for aPtr2 (%p), causing address calculation to overflow.', [aSize2, aPtr2]);
	movq	%r13,-40(%rbp)
	leaq	-40(%rbp),%rax
	movq	%rax,-24(%rbp)
	movq	$17,-32(%rbp)
	movq	%r12,-8(%rbp)
	movq	$5,-16(%rbp)
	leaq	-32(%rbp),%rcx
	movq	$.Ld2,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE,%rdi
	movl	$1,%r8d
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATEFMT$ANSISTRING$array_of_const$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj12,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj11:
# [836] Result := IsOverlapUnChecked(aPtr1, aSize1, aPtr2, aSize2);
	movq	%r13,%rcx
# Var aSize2 located in register rcx
	movq	%r12,%rdx
# Var aPtr2 located in register rdx
	movq	%r15,%rsi
# Var aSize1 located in register rsi
	movq	%r14,%rdi
# Var aPtr1 located in register rdi
	call	NEXTPAS.CORE.MEM.UTILS_$$_ISOVERLAPUNCHECKED$POINTER$QWORD$POINTER$QWORD$$BOOLEAN
	movb	%al,-48(%rbp)
.Lj3:
# [837] end;
	movb	-48(%rbp),%al
	movq	-88(%rbp),%rbx
	movq	-80(%rbp),%r12
	movq	-72(%rbp),%r13
	movq	-64(%rbp),%r14
	movq	-56(%rbp),%r15
.Lc5:
	movq	%rbp,%rsp
.Lc6:
	popq	%rbp
	ret
.Lc1:
.Le0:
	.size	NEXTPAS.CORE.MEM.UTILS_$$_ISOVERLAP$POINTER$QWORD$POINTER$QWORD$$BOOLEAN, .Le0 - NEXTPAS.CORE.MEM.UTILS_$$_ISOVERLAP$POINTER$QWORD$POINTER$QWORD$$BOOLEAN

.section .text.n_nextpas.core.mem.utils_$$_isoverlapunchecked$pointer$qword$pointer$qword$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.UTILS_$$_ISOVERLAPUNCHECKED$POINTER$QWORD$POINTER$QWORD$$BOOLEAN
	.type	NEXTPAS.CORE.MEM.UTILS_$$_ISOVERLAPUNCHECKED$POINTER$QWORD$POINTER$QWORD$$BOOLEAN,@function
NEXTPAS.CORE.MEM.UTILS_$$_ISOVERLAPUNCHECKED$POINTER$QWORD$POINTER$QWORD$$BOOLEAN:
.Lc8:
# Var aPtr1 located in register rdi
# Var aSize1 located in register rsi
# Var aPtr2 located in register rdx
# Var aSize2 located in register rcx
# [840] begin
# [842] Result := (PtrUInt(aPtr1) < PtrUInt(aPtr2) + aSize2) and (PtrUInt(aPtr2) < PtrUInt(aPtr1) + aSize1);
	leaq	(%rdx,%rcx),%rax
	cmpq	%rdi,%rax
	setab	%al
	leaq	(%rdi,%rsi),%rcx
	cmpq	%rdx,%rcx
	setab	%dl
	andb	%dl,%al
# Var $result located in register al
.Lc9:
# [844] end;
	ret
.Lc7:
.Le1:
	.size	NEXTPAS.CORE.MEM.UTILS_$$_ISOVERLAPUNCHECKED$POINTER$QWORD$POINTER$QWORD$$BOOLEAN, .Le1 - NEXTPAS.CORE.MEM.UTILS_$$_ISOVERLAPUNCHECKED$POINTER$QWORD$POINTER$QWORD$$BOOLEAN

.section .text.n_nextpas.core.mem.utils_$$_isoverlap$pointer$pointer$qword$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.UTILS_$$_ISOVERLAP$POINTER$POINTER$QWORD$$BOOLEAN
	.type	NEXTPAS.CORE.MEM.UTILS_$$_ISOVERLAP$POINTER$POINTER$QWORD$$BOOLEAN,@function
NEXTPAS.CORE.MEM.UTILS_$$_ISOVERLAP$POINTER$POINTER$QWORD$$BOOLEAN:
.Lc11:
# [847] begin
	pushq	%rax
.Lc12:
# Var aPtr1 located in register rdi
	movq	%rsi,%rax
# Var aPtr2 located in register rax
	movq	%rdx,%rsi
# Var aSize located in register rsi
# Var aSize located in register rsi
# [848] Result := IsOverlap(aPtr1, aSize, aPtr2, aSize);
	movq	%rdx,%rcx
	movq	%rax,%rdx
# Var aPtr2 located in register rdx
# Var aSize located in register rsi
# Var aPtr1 located in register rdi
	call	NEXTPAS.CORE.MEM.UTILS_$$_ISOVERLAP$POINTER$QWORD$POINTER$QWORD$$BOOLEAN
# Var $result located in register al
# [849] end;
	popq	%rcx
.Lc13:
	ret
.Lc10:

.section .text.n_nextpas.core.mem.utils_$$_isoverlapunchecked$pointer$pointer$qword$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.UTILS_$$_ISOVERLAPUNCHECKED$POINTER$POINTER$QWORD$$BOOLEAN
	.type	NEXTPAS.CORE.MEM.UTILS_$$_ISOVERLAPUNCHECKED$POINTER$POINTER$QWORD$$BOOLEAN,@function
NEXTPAS.CORE.MEM.UTILS_$$_ISOVERLAPUNCHECKED$POINTER$POINTER$QWORD$$BOOLEAN:
.Lc15:
# [852] begin
	pushq	%rax
.Lc16:
# Var aPtr1 located in register rdi
	movq	%rsi,%rax
# Var aPtr2 located in register rax
	movq	%rdx,%rsi
# Var aSize located in register rsi
# Var aSize located in register rsi
# [853] Result := IsOverlapUnChecked(aPtr1, aSize, aPtr2, aSize);
	movq	%rdx,%rcx
	movq	%rax,%rdx
# Var aPtr2 located in register rdx
# Var aSize located in register rsi
# Var aPtr1 located in register rdi
	call	NEXTPAS.CORE.MEM.UTILS_$$_ISOVERLAPUNCHECKED$POINTER$QWORD$POINTER$QWORD$$BOOLEAN
# Var $result located in register al
# [854] end;
	popq	%rcx
.Lc17:
	ret
.Lc14:

.section .text.n_nextpas.core.mem.utils_$$_copy$pointer$pointer$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.UTILS_$$_COPY$POINTER$POINTER$QWORD
	.type	NEXTPAS.CORE.MEM.UTILS_$$_COPY$POINTER$POINTER$QWORD,@function
NEXTPAS.CORE.MEM.UTILS_$$_COPY$POINTER$POINTER$QWORD:
.Lc19:
# Temps allocated between rbp-72 and rbp+0
# [857] begin
	pushq	%rbp
.Lc20:
	movq	%rsp,%rbp
.Lc21:
	leaq	-80(%rsp),%rsp
	movq	%rbx,-72(%rbp)
	movq	%r12,-64(%rbp)
	movq	%r13,-56(%rbp)
	movq	%rdi,%rbx
# Var aSrc located in register rbx
	movq	%rsi,%r12
# Var aDst located in register r12
	movq	%rdx,%r13
# Var aSize located in register r13
# [858] if aSize = 0 then
	testq	%rdx,%rdx
	je	.Lj19
# [861] if aSrc = nil then
	testq	%rbx,%rbx
	jne	.Lj24
.Lj25:
# [862] raise EArgumentNil.Create('nextpas.core.mem.utils.Copy: aSrc is nil.');
	movq	$.Ld3,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj25,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj24:
# [864] if aDst = nil then
	testq	%r12,%r12
	jne	.Lj27
.Lj28:
# [865] raise EArgumentNil.Create('nextpas.core.mem.utils.Copy: aDst is nil.');
	movq	$.Ld4,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj28,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj27:
# [869] if aSize > MAX_SIZE_INT then
	movq	$9223372036854775807,%rax
	cmpq	%rax,%r13
	jna	.Lj30
.Lj31:
# [870] raise EOutOfRange.CreateFmt('nextpas.core.mem.utils.Copy: aSize (%d) exceeds maximum allowed for System.Move (%d).', [aSize, MAX_SIZE_INT]);
	movq	%r13,-40(%rbp)
	leaq	-40(%rbp),%rax
	movq	%rax,-24(%rbp)
	movq	$17,-32(%rbp)
	movq	$9223372036854775807,%rax
	movq	%rax,-48(%rbp)
	leaq	-48(%rbp),%rax
	movq	%rax,-8(%rbp)
	movq	$16,-16(%rbp)
	leaq	-32(%rbp),%rcx
	movq	$.Ld5,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE,%rdi
	movl	$1,%r8d
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATEFMT$ANSISTRING$array_of_const$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj31,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj30:
# [873] CopyUnChecked(aSrc, aDst, aSize);
	movq	%r13,%rdx
# Var aSize located in register rdx
	movq	%r12,%rsi
# Var aDst located in register rsi
	movq	%rbx,%rdi
# Var aSrc located in register rdi
	call	NEXTPAS.CORE.MEM.UTILS_$$_COPYUNCHECKED$POINTER$POINTER$QWORD
.Lj19:
# [874] end;
	movq	-72(%rbp),%rbx
	movq	-64(%rbp),%r12
	movq	-56(%rbp),%r13
.Lc22:
	movq	%rbp,%rsp
.Lc23:
	popq	%rbp
	ret
.Lc18:

.section .text.n_nextpas.core.mem.utils_$$_copyunchecked$pointer$pointer$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.UTILS_$$_COPYUNCHECKED$POINTER$POINTER$QWORD
	.type	NEXTPAS.CORE.MEM.UTILS_$$_COPYUNCHECKED$POINTER$POINTER$QWORD,@function
NEXTPAS.CORE.MEM.UTILS_$$_COPYUNCHECKED$POINTER$POINTER$QWORD:
.Lc25:
# [877] begin
	pushq	%rax
.Lc26:
# Var aSrc located in register rdi
# Var aDst located in register rsi
# Var aSize located in register rdx
# Var aDst located in register rsi
# Var aSrc located in register rdi
# Var aSize located in register rdx
# [881] System.Move(aSrc^, aDst^, SizeInt(aSize));
	call	SYSTEM_$$_MOVE$formal$formal$INT64
# [883] end;
	popq	%rcx
.Lc27:
	ret
.Lc24:
.Le2:
	.size	NEXTPAS.CORE.MEM.UTILS_$$_COPYUNCHECKED$POINTER$POINTER$QWORD, .Le2 - NEXTPAS.CORE.MEM.UTILS_$$_COPYUNCHECKED$POINTER$POINTER$QWORD

.section .text.n_nextpas.core.mem.utils_$$_copynonoverlap$pointer$pointer$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.UTILS_$$_COPYNONOVERLAP$POINTER$POINTER$QWORD
	.type	NEXTPAS.CORE.MEM.UTILS_$$_COPYNONOVERLAP$POINTER$POINTER$QWORD,@function
NEXTPAS.CORE.MEM.UTILS_$$_COPYNONOVERLAP$POINTER$POINTER$QWORD:
.Lc29:
# Temps allocated between rbp-72 and rbp+0
# [886] begin
	pushq	%rbp
.Lc30:
	movq	%rsp,%rbp
.Lc31:
	leaq	-80(%rsp),%rsp
	movq	%rbx,-72(%rbp)
	movq	%r12,-64(%rbp)
	movq	%r13,-56(%rbp)
	movq	%rdi,%rbx
# Var aSrc located in register rbx
	movq	%rsi,%r12
# Var aDst located in register r12
	movq	%rdx,%r13
# Var aSize located in register r13
# [887] if aSize = 0 then
	testq	%rdx,%rdx
	je	.Lj34
# [890] if aSrc = nil then
	testq	%rbx,%rbx
	jne	.Lj39
.Lj40:
# [891] raise EArgumentNil.Create('nextpas.core.mem.utils.CopyNonOverlap: aSrc is nil.');
	movq	$.Ld6,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj40,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj39:
# [893] if aDst = nil then
	testq	%r12,%r12
	jne	.Lj42
.Lj43:
# [894] raise EArgumentNil.Create('nextpas.core.mem.utils.CopyNonOverlap: aDst is nil.');
	movq	$.Ld7,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj43,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj42:
# [898] if aSize > MAX_SIZE_INT then
	movq	$9223372036854775807,%rax
	cmpq	%rax,%r13
	jna	.Lj45
.Lj46:
# [899] raise EOutOfRange.CreateFmt('nextpas.core.mem.utils.CopyNonOverlap: aSize (%d) exceeds maximum allowed for System.Move (%d).', [aSize, MAX_SIZE_INT]);
	movq	%r13,-40(%rbp)
	leaq	-40(%rbp),%rax
	movq	%rax,-24(%rbp)
	movq	$17,-32(%rbp)
	movq	$9223372036854775807,%rax
	movq	%rax,-48(%rbp)
	leaq	-48(%rbp),%rax
	movq	%rax,-8(%rbp)
	movq	$16,-16(%rbp)
	leaq	-32(%rbp),%rcx
	movq	$.Ld8,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE,%rdi
	movl	$1,%r8d
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATEFMT$ANSISTRING$array_of_const$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj46,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj45:
# [902] CopyNonOverlapUnChecked(aSrc, aDst, aSize);
	movq	%r13,%rdx
# Var aSize located in register rdx
	movq	%r12,%rsi
# Var aDst located in register rsi
	movq	%rbx,%rdi
# Var aSrc located in register rdi
	call	NEXTPAS.CORE.MEM.UTILS_$$_COPYNONOVERLAPUNCHECKED$POINTER$POINTER$QWORD
.Lj34:
# [903] end;
	movq	-72(%rbp),%rbx
	movq	-64(%rbp),%r12
	movq	-56(%rbp),%r13
.Lc32:
	movq	%rbp,%rsp
.Lc33:
	popq	%rbp
	ret
.Lc28:

.section .text.n_nextpas.core.mem.utils_$$_copynonoverlapunchecked$pointer$pointer$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.UTILS_$$_COPYNONOVERLAPUNCHECKED$POINTER$POINTER$QWORD
	.type	NEXTPAS.CORE.MEM.UTILS_$$_COPYNONOVERLAPUNCHECKED$POINTER$POINTER$QWORD,@function
NEXTPAS.CORE.MEM.UTILS_$$_COPYNONOVERLAPUNCHECKED$POINTER$POINTER$QWORD:
.Lc35:
# [906] begin
	pushq	%rax
.Lc36:
# Var aSrc located in register rdi
# Var aDst located in register rsi
# Var aSize located in register rdx
# Var aDst located in register rsi
# Var aSrc located in register rdi
# Var aSize located in register rdx
# [910] System.Move(aSrc^, aDst^, SizeInt(aSize));
	call	SYSTEM_$$_MOVE$formal$formal$INT64
# [912] end;
	popq	%rcx
.Lc37:
	ret
.Lc34:
.Le3:
	.size	NEXTPAS.CORE.MEM.UTILS_$$_COPYNONOVERLAPUNCHECKED$POINTER$POINTER$QWORD, .Le3 - NEXTPAS.CORE.MEM.UTILS_$$_COPYNONOVERLAPUNCHECKED$POINTER$POINTER$QWORD

.section .text.n_nextpas.core.mem.utils_$$_fill$pointer$int64$byte,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.UTILS_$$_FILL$POINTER$INT64$BYTE
	.type	NEXTPAS.CORE.MEM.UTILS_$$_FILL$POINTER$INT64$BYTE,@function
NEXTPAS.CORE.MEM.UTILS_$$_FILL$POINTER$INT64$BYTE:
.Lc39:
# [915] begin
	pushq	%rax
.Lc40:
# Var aDst located in register rdi
# Var aCount located in register rsi
# Var aValue located in register dl
# Var aValue located in register dl
# [916] Fill8(aDst, aCount, aValue);
	movzbl	%dl,%edx
# Var aCount located in register rsi
# Var aDst located in register rdi
	call	NEXTPAS.CORE.MEM.UTILS_$$_FILL8$POINTER$INT64$BYTE
# [917] end;
	popq	%rcx
.Lc41:
	ret
.Lc38:

.section .text.n_nextpas.core.mem.utils_$$_fill$pointer$qword$byte,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.UTILS_$$_FILL$POINTER$QWORD$BYTE
	.type	NEXTPAS.CORE.MEM.UTILS_$$_FILL$POINTER$QWORD$BYTE,@function
NEXTPAS.CORE.MEM.UTILS_$$_FILL$POINTER$QWORD$BYTE:
.Lc43:
# [920] begin
	pushq	%rax
.Lc44:
# Var aDst located in register rdi
# Var aCount located in register rsi
# Var aValue located in register dl
# Var aValue located in register dl
# [921] Fill8(aDst, aCount, aValue);
	movzbl	%dl,%edx
# Var aCount located in register rsi
# Var aDst located in register rdi
	call	NEXTPAS.CORE.MEM.UTILS_$$_FILL8$POINTER$QWORD$BYTE
# [922] end;
	popq	%rcx
.Lc45:
	ret
.Lc42:

.section .text.n_nextpas.core.mem.utils_$$_fill8$pointer$int64$byte,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.UTILS_$$_FILL8$POINTER$INT64$BYTE
	.type	NEXTPAS.CORE.MEM.UTILS_$$_FILL8$POINTER$INT64$BYTE,@function
NEXTPAS.CORE.MEM.UTILS_$$_FILL8$POINTER$INT64$BYTE:
.Lc47:
# Temps allocated between rbp-24 and rbp+0
# [925] begin
	pushq	%rbp
.Lc48:
	movq	%rsp,%rbp
.Lc49:
	leaq	-32(%rsp),%rsp
	movq	%rbx,-24(%rbp)
	movq	%r12,-16(%rbp)
	movq	%r13,-8(%rbp)
	movq	%rdi,%rbx
# Var aDst located in register rbx
	movq	%rsi,%r12
# Var aCount located in register r12
	movb	%dl,%r13b
# Var aValue located in register r13b
# [926] if aCount = 0 then
	testq	%rsi,%rsi
	je	.Lj53
# [929] if aDst = nil then
	testq	%rbx,%rbx
	jne	.Lj58
.Lj59:
# [930] raise EArgumentNil.Create('nextpas.core.mem.utils.Fill8: aDst is nil');
	movq	$.Ld9,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj59,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj58:
# [932] FillChar(aDst^, aCount, aValue);
	movq	%rbx,%rdi
# Var aDst located in register rdi
# Var aValue located in register dl
	movzbl	%r13b,%edx
	movq	%r12,%rsi
# Var aCount located in register rsi
	call	SYSTEM_$$_FILLCHAR$formal$INT64$BYTE
.Lj53:
# [933] end;
	movq	-24(%rbp),%rbx
	movq	-16(%rbp),%r12
	movq	-8(%rbp),%r13
.Lc50:
	movq	%rbp,%rsp
.Lc51:
	popq	%rbp
	ret
.Lc46:
.Le4:
	.size	NEXTPAS.CORE.MEM.UTILS_$$_FILL8$POINTER$INT64$BYTE, .Le4 - NEXTPAS.CORE.MEM.UTILS_$$_FILL8$POINTER$INT64$BYTE

.section .text.n_nextpas.core.mem.utils_$$_fill8$pointer$qword$byte,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.UTILS_$$_FILL8$POINTER$QWORD$BYTE
	.type	NEXTPAS.CORE.MEM.UTILS_$$_FILL8$POINTER$QWORD$BYTE,@function
NEXTPAS.CORE.MEM.UTILS_$$_FILL8$POINTER$QWORD$BYTE:
.Lc53:
# Temps allocated between rbp-32 and rbp+0
# [940] begin
	pushq	%rbp
.Lc54:
	movq	%rsp,%rbp
.Lc55:
	leaq	-32(%rsp),%rsp
	movq	%rbx,-32(%rbp)
	movq	%r12,-24(%rbp)
	movq	%r13,-16(%rbp)
	movq	%r14,-8(%rbp)
# Var LChunkSize located in register r14
	movq	%rdi,%rbx
# Var aDst located in register rbx
	movq	%rsi,%r12
# Var aCount located in register r12
	movb	%dl,%r13b
# Var aValue located in register r13b
# [941] if aCount = 0 then
	testq	%rsi,%rsi
	je	.Lj60
# [944] if aDst = nil then
	testq	%rbx,%rbx
	jne	.Lj68
.Lj66:
# [945] raise EArgumentNil.Create('nextpas.core.mem.utils.Fill8: aDst is nil');
	movq	$.Ld9,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj66,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
# Var LCurrentDst located in register rbx
# Var aDst located in register rbx
# Var LRemainingCount located in register r12
# Var aCount located in register r12
# [952] while LRemainingCount > 0 do
	jmp	.Lj68
	.p2align 4,,10
	.p2align 3
.Lj67:
# [954] if LRemainingCount > MAX_SIZE_INT then
	movq	$9223372036854775807,%rax
# [955] LChunkSize := MAX_SIZE_INT
	movq	$9223372036854775807,%r14
	cmpq	%rax,%r12
# [957] LChunkSize := SizeInt(LRemainingCount);
	cmovnaq	%r12,%r14
# [959] FillChar(Pointer(LCurrentDst)^, LChunkSize, aValue);
	movq	%rbx,%rdi
	movzbl	%r13b,%edx
	movq	%r14,%rsi
	call	SYSTEM_$$_FILLCHAR$formal$INT64$BYTE
# [961] Inc(LCurrentDst, LChunkSize);
	addq	%r14,%rbx
# [962] Dec(LRemainingCount, LChunkSize);
	subq	%r14,%r12
.Lj68:
	testq	%r12,%r12
	jne	.Lj67
.Lj60:
# [965] end;
	movq	-32(%rbp),%rbx
	movq	-24(%rbp),%r12
	movq	-16(%rbp),%r13
	movq	-8(%rbp),%r14
.Lc56:
	movq	%rbp,%rsp
.Lc57:
	popq	%rbp
	ret
.Lc52:
.Le5:
	.size	NEXTPAS.CORE.MEM.UTILS_$$_FILL8$POINTER$QWORD$BYTE, .Le5 - NEXTPAS.CORE.MEM.UTILS_$$_FILL8$POINTER$QWORD$BYTE

.section .text.n_nextpas.core.mem.utils_$$_fill16$pointer$qword$word,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.UTILS_$$_FILL16$POINTER$QWORD$WORD
	.type	NEXTPAS.CORE.MEM.UTILS_$$_FILL16$POINTER$QWORD$WORD,@function
NEXTPAS.CORE.MEM.UTILS_$$_FILL16$POINTER$QWORD$WORD:
.Lc59:
# Temps allocated between rbp-32 and rbp+0
# [972] begin
	pushq	%rbp
.Lc60:
	movq	%rsp,%rbp
.Lc61:
	leaq	-32(%rsp),%rsp
	movq	%rbx,-32(%rbp)
	movq	%r12,-24(%rbp)
	movq	%r13,-16(%rbp)
	movq	%r14,-8(%rbp)
# Var LChunkSize located in register r14
	movq	%rdi,%rbx
# Var aDst located in register rbx
	movq	%rsi,%r12
# Var aCount located in register r12
	movw	%dx,%r13w
# Var aValue located in register r13w
# [973] if aCount = 0 then
	testq	%rsi,%rsi
	je	.Lj73
# [976] if aDst = nil then
	testq	%rbx,%rbx
	jne	.Lj81
.Lj79:
# [977] raise EArgumentNil.Create('nextpas.core.mem.utils.Fill16: aDst is nil');
	movq	$.Ld10,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj79,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
# Var LCurrentDst located in register rbx
# Var aDst located in register rbx
# Var LRemainingCount located in register r12
# Var aCount located in register r12
# [983] while LRemainingCount > 0 do
	jmp	.Lj81
	.p2align 4,,10
	.p2align 3
.Lj80:
# [985] if LRemainingCount > MAX_SIZE_INT then
	movq	$9223372036854775807,%rax
# [986] LChunkSize := MAX_SIZE_INT
	movq	$9223372036854775807,%r14
	cmpq	%rax,%r12
# [988] LChunkSize := SizeInt(LRemainingCount);
	cmovnaq	%r12,%r14
# [990] FillWord(Pointer(LCurrentDst)^, LChunkSize, aValue);
	movq	%rbx,%rdi
	movzwl	%r13w,%edx
	movq	%r14,%rsi
	call	SYSTEM_$$_FILLWORD$formal$INT64$WORD
# [993] if LChunkSize > MAX_SIZE_INT div SIZE_16 then
	movq	$4611686018427387903,%rax
	cmpq	%rax,%r14
	jng	.Lj87
.Lj88:
# [994] raise EOverflow.Create('nextpas.core.mem.utils.Fill16: pointer arithmetic overflow');
	movq	$.Ld11,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EOVERFLOW,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj88,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj87:
# [996] Inc(LCurrentDst, LChunkSize * SIZE_16);
	leaq	(%r14,%r14,1),%rax
	addq	%rax,%rbx
# [997] Dec(LRemainingCount, LChunkSize);
	subq	%r14,%r12
.Lj81:
	testq	%r12,%r12
	jne	.Lj80
.Lj73:
# [1000] end;
	movq	-32(%rbp),%rbx
	movq	-24(%rbp),%r12
	movq	-16(%rbp),%r13
	movq	-8(%rbp),%r14
.Lc62:
	movq	%rbp,%rsp
.Lc63:
	popq	%rbp
	ret
.Lc58:

.section .text.n_nextpas.core.mem.utils_$$_fill16$pointer$int64$word,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.UTILS_$$_FILL16$POINTER$INT64$WORD
	.type	NEXTPAS.CORE.MEM.UTILS_$$_FILL16$POINTER$INT64$WORD,@function
NEXTPAS.CORE.MEM.UTILS_$$_FILL16$POINTER$INT64$WORD:
.Lc65:
# Temps allocated between rbp-24 and rbp+0
# [1003] begin
	pushq	%rbp
.Lc66:
	movq	%rsp,%rbp
.Lc67:
	leaq	-32(%rsp),%rsp
	movq	%rbx,-24(%rbp)
	movq	%r12,-16(%rbp)
	movq	%r13,-8(%rbp)
	movq	%rdi,%rbx
# Var aDst located in register rbx
	movq	%rsi,%r12
# Var aCount located in register r12
	movw	%dx,%r13w
# Var aValue located in register r13w
# [1004] if aCount = 0 then
	testq	%rsi,%rsi
	je	.Lj89
# [1007] if aDst = nil then
	testq	%rbx,%rbx
	jne	.Lj94
.Lj95:
# [1008] raise EArgumentNil.Create('nextpas.core.mem.utils.Fill16: aDst is nil');
	movq	$.Ld10,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj95,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj94:
# [1010] FillWord(aDst^, aCount, aValue);
	movq	%rbx,%rdi
# Var aDst located in register rdi
# Var aValue located in register dx
	movzwl	%r13w,%edx
	movq	%r12,%rsi
# Var aCount located in register rsi
	call	SYSTEM_$$_FILLWORD$formal$INT64$WORD
.Lj89:
# [1011] end;
	movq	-24(%rbp),%rbx
	movq	-16(%rbp),%r12
	movq	-8(%rbp),%r13
.Lc68:
	movq	%rbp,%rsp
.Lc69:
	popq	%rbp
	ret
.Lc64:

.section .text.n_nextpas.core.mem.utils_$$_fill32$pointer$qword$longword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.UTILS_$$_FILL32$POINTER$QWORD$LONGWORD
	.type	NEXTPAS.CORE.MEM.UTILS_$$_FILL32$POINTER$QWORD$LONGWORD,@function
NEXTPAS.CORE.MEM.UTILS_$$_FILL32$POINTER$QWORD$LONGWORD:
.Lc71:
# Temps allocated between rbp-32 and rbp+0
# [1018] begin
	pushq	%rbp
.Lc72:
	movq	%rsp,%rbp
.Lc73:
	leaq	-32(%rsp),%rsp
	movq	%rbx,-32(%rbp)
	movq	%r12,-24(%rbp)
	movq	%r13,-16(%rbp)
	movq	%r14,-8(%rbp)
# Var LChunkSize located in register r14
	movq	%rdi,%rbx
# Var aDst located in register rbx
	movq	%rsi,%r12
# Var aCount located in register r12
	movl	%edx,%r13d
# Var aValue located in register r13d
# [1019] if aCount = 0 then
	testq	%rsi,%rsi
	je	.Lj96
# [1022] if aDst = nil then
	testq	%rbx,%rbx
	jne	.Lj104
.Lj102:
# [1023] raise EArgumentNil.Create('nextpas.core.mem.utils.Fill32: aDst is nil');
	movq	$.Ld12,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj102,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
# Var LCurrentDst located in register rbx
# Var aDst located in register rbx
# Var LRemainingCount located in register r12
# Var aCount located in register r12
# [1029] while LRemainingCount > 0 do
	jmp	.Lj104
	.p2align 4,,10
	.p2align 3
.Lj103:
# [1031] if LRemainingCount > MAX_SIZE_INT then
	movq	$9223372036854775807,%rax
# [1032] LChunkSize := MAX_SIZE_INT
	movq	$9223372036854775807,%r14
	cmpq	%rax,%r12
# [1034] LChunkSize := SizeInt(LRemainingCount);
	cmovnaq	%r12,%r14
# [1036] FillDWord(Pointer(LCurrentDst)^, LChunkSize, aValue);
	movq	%rbx,%rdi
	movl	%r13d,%edx
	movq	%r14,%rsi
	call	SYSTEM_$$_FILLDWORD$formal$INT64$LONGWORD
# [1039] if LChunkSize > MAX_SIZE_INT div SIZE_32 then
	movq	$2305843009213693951,%rax
	cmpq	%rax,%r14
	jng	.Lj110
.Lj111:
# [1040] raise EOverflow.Create('nextpas.core.mem.utils.Fill32: pointer arithmetic overflow');
	movq	$.Ld13,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EOVERFLOW,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj111,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj110:
# [1042] Inc(LCurrentDst, LChunkSize * SIZE_32);
	leaq	(,%r14,4),%rax
	addq	%rax,%rbx
# [1043] Dec(LRemainingCount, LChunkSize);
	subq	%r14,%r12
.Lj104:
	testq	%r12,%r12
	jne	.Lj103
.Lj96:
# [1046] end;
	movq	-32(%rbp),%rbx
	movq	-24(%rbp),%r12
	movq	-16(%rbp),%r13
	movq	-8(%rbp),%r14
.Lc74:
	movq	%rbp,%rsp
.Lc75:
	popq	%rbp
	ret
.Lc70:

.section .text.n_nextpas.core.mem.utils_$$_fill32$pointer$int64$longword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.UTILS_$$_FILL32$POINTER$INT64$LONGWORD
	.type	NEXTPAS.CORE.MEM.UTILS_$$_FILL32$POINTER$INT64$LONGWORD,@function
NEXTPAS.CORE.MEM.UTILS_$$_FILL32$POINTER$INT64$LONGWORD:
.Lc77:
# Temps allocated between rbp-24 and rbp+0
# [1049] begin
	pushq	%rbp
.Lc78:
	movq	%rsp,%rbp
.Lc79:
	leaq	-32(%rsp),%rsp
	movq	%rbx,-24(%rbp)
	movq	%r12,-16(%rbp)
	movq	%r13,-8(%rbp)
	movq	%rdi,%rbx
# Var aDst located in register rbx
	movq	%rsi,%r12
# Var aCount located in register r12
	movl	%edx,%r13d
# Var aValue located in register r13d
# [1050] if aCount = 0 then
	testq	%rsi,%rsi
	je	.Lj112
# [1053] if aDst = nil then
	testq	%rbx,%rbx
	jne	.Lj117
.Lj118:
# [1054] raise EArgumentNil.Create('nextpas.core.mem.utils.Fill32: aDst is nil');
	movq	$.Ld12,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj118,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj117:
# [1056] FillDWord(aDst^, aCount, aValue);
	movq	%rbx,%rdi
# Var aDst located in register rdi
	movl	%r13d,%edx
# Var aValue located in register edx
	movq	%r12,%rsi
# Var aCount located in register rsi
	call	SYSTEM_$$_FILLDWORD$formal$INT64$LONGWORD
.Lj112:
# [1057] end;
	movq	-24(%rbp),%rbx
	movq	-16(%rbp),%r12
	movq	-8(%rbp),%r13
.Lc80:
	movq	%rbp,%rsp
.Lc81:
	popq	%rbp
	ret
.Lc76:

.section .text.n_nextpas.core.mem.utils_$$_fill64$pointer$qword$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.UTILS_$$_FILL64$POINTER$QWORD$QWORD
	.type	NEXTPAS.CORE.MEM.UTILS_$$_FILL64$POINTER$QWORD$QWORD,@function
NEXTPAS.CORE.MEM.UTILS_$$_FILL64$POINTER$QWORD$QWORD:
.Lc83:
# Temps allocated between rbp-32 and rbp+0
# [1064] begin
	pushq	%rbp
.Lc84:
	movq	%rsp,%rbp
.Lc85:
	leaq	-32(%rsp),%rsp
	movq	%rbx,-32(%rbp)
	movq	%r12,-24(%rbp)
	movq	%r13,-16(%rbp)
	movq	%r14,-8(%rbp)
# Var LChunkSize located in register r14
	movq	%rdi,%rbx
# Var aDst located in register rbx
	movq	%rsi,%r12
# Var aCount located in register r12
	movq	%rdx,%r13
# Var aValue located in register r13
# [1065] if aCount = 0 then
	testq	%rsi,%rsi
	je	.Lj119
# [1068] if aDst = nil then
	testq	%rbx,%rbx
	jne	.Lj127
.Lj125:
# [1069] raise EArgumentNil.Create('nextpas.core.mem.utils.Fill64: aDst is nil');
	movq	$.Ld14,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj125,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
# Var LCurrentDst located in register rbx
# Var aDst located in register rbx
# Var LRemainingCount located in register r12
# Var aCount located in register r12
# [1075] while LRemainingCount > 0 do
	jmp	.Lj127
	.p2align 4,,10
	.p2align 3
.Lj126:
# [1077] if LRemainingCount > MAX_SIZE_INT then
	movq	$9223372036854775807,%rax
# [1078] LChunkSize := MAX_SIZE_INT
	movq	$9223372036854775807,%r14
	cmpq	%rax,%r12
# [1080] LChunkSize := SizeInt(LRemainingCount);
	cmovnaq	%r12,%r14
# [1082] FillQWord(Pointer(LCurrentDst)^, LChunkSize, aValue);
	movq	%rbx,%rdi
	movq	%r13,%rdx
	movq	%r14,%rsi
	call	SYSTEM_$$_FILLQWORD$formal$INT64$QWORD
# [1085] if LChunkSize > MAX_SIZE_INT div SIZE_64 then
	movq	$1152921504606846975,%rax
	cmpq	%rax,%r14
	jng	.Lj133
.Lj134:
# [1086] raise EOverflow.Create('nextpas.core.mem.utils.Fill64: pointer arithmetic overflow');
	movq	$.Ld15,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EOVERFLOW,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj134,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj133:
# [1088] Inc(LCurrentDst, LChunkSize * SIZE_64);
	leaq	(,%r14,8),%rax
	addq	%rax,%rbx
# [1089] Dec(LRemainingCount, LChunkSize);
	subq	%r14,%r12
.Lj127:
	testq	%r12,%r12
	jne	.Lj126
.Lj119:
# [1092] end;
	movq	-32(%rbp),%rbx
	movq	-24(%rbp),%r12
	movq	-16(%rbp),%r13
	movq	-8(%rbp),%r14
.Lc86:
	movq	%rbp,%rsp
.Lc87:
	popq	%rbp
	ret
.Lc82:

.section .text.n_nextpas.core.mem.utils_$$_fill64$pointer$int64$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.UTILS_$$_FILL64$POINTER$INT64$QWORD
	.type	NEXTPAS.CORE.MEM.UTILS_$$_FILL64$POINTER$INT64$QWORD,@function
NEXTPAS.CORE.MEM.UTILS_$$_FILL64$POINTER$INT64$QWORD:
.Lc89:
# Temps allocated between rbp-24 and rbp+0
# [1095] begin
	pushq	%rbp
.Lc90:
	movq	%rsp,%rbp
.Lc91:
	leaq	-32(%rsp),%rsp
	movq	%rbx,-24(%rbp)
	movq	%r12,-16(%rbp)
	movq	%r13,-8(%rbp)
	movq	%rdi,%rbx
# Var aDst located in register rbx
	movq	%rsi,%r12
# Var aCount located in register r12
	movq	%rdx,%r13
# Var aValue located in register r13
# [1096] if aCount = 0 then
	testq	%rsi,%rsi
	je	.Lj135
# [1099] if aDst = nil then
	testq	%rbx,%rbx
	jne	.Lj140
.Lj141:
# [1100] raise EArgumentNil.Create('nextpas.core.mem.utils.Fill64: aDst is nil');
	movq	$.Ld14,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj141,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj140:
# [1102] FillQWord(aDst^, aCount, aValue);
	movq	%rbx,%rdi
# Var aDst located in register rdi
	movq	%r13,%rdx
# Var aValue located in register rdx
	movq	%r12,%rsi
# Var aCount located in register rsi
	call	SYSTEM_$$_FILLQWORD$formal$INT64$QWORD
.Lj135:
# [1103] end;
	movq	-24(%rbp),%rbx
	movq	-16(%rbp),%r12
	movq	-8(%rbp),%r13
.Lc92:
	movq	%rbp,%rsp
.Lc93:
	popq	%rbp
	ret
.Lc88:

.section .text.n_nextpas.core.mem.utils_$$_zero$pointer$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.UTILS_$$_ZERO$POINTER$QWORD
	.type	NEXTPAS.CORE.MEM.UTILS_$$_ZERO$POINTER$QWORD,@function
NEXTPAS.CORE.MEM.UTILS_$$_ZERO$POINTER$QWORD:
.Lc95:
# [1107] begin
	pushq	%rax
.Lc96:
# Var aDst located in register rdi
# Var aSize located in register rsi
# [1108] Fill8(aDst, aSize, 0);
	xorl	%edx,%edx
# Var aSize located in register rsi
# Var aDst located in register rdi
	call	NEXTPAS.CORE.MEM.UTILS_$$_FILL8$POINTER$QWORD$BYTE
# [1109] end;
	popq	%rcx
.Lc97:
	ret
.Lc94:

.section .text.n_nextpas.core.mem.utils_$$_zero$pointer$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.UTILS_$$_ZERO$POINTER$INT64
	.type	NEXTPAS.CORE.MEM.UTILS_$$_ZERO$POINTER$INT64,@function
NEXTPAS.CORE.MEM.UTILS_$$_ZERO$POINTER$INT64:
.Lc99:
# [1112] begin
	pushq	%rax
.Lc100:
# Var aDst located in register rdi
# Var aSize located in register rsi
# [1113] Fill8(aDst, aSize, 0);
	xorl	%edx,%edx
# Var aSize located in register rsi
# Var aDst located in register rdi
	call	NEXTPAS.CORE.MEM.UTILS_$$_FILL8$POINTER$INT64$BYTE
# [1114] end;
	popq	%rcx
.Lc101:
	ret
.Lc98:

.section .text.n_nextpas.core.mem.utils_$$_compare$pointer$pointer$qword$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.UTILS_$$_COMPARE$POINTER$POINTER$QWORD$$LONGINT
	.type	NEXTPAS.CORE.MEM.UTILS_$$_COMPARE$POINTER$POINTER$QWORD$$LONGINT,@function
NEXTPAS.CORE.MEM.UTILS_$$_COMPARE$POINTER$POINTER$QWORD$$LONGINT:
.Lc103:
# [1117] begin
	pushq	%rax
.Lc104:
# Var aPtr1 located in register rdi
# Var aPtr2 located in register rsi
# Var aCount located in register rdx
# Var aCount located in register rdx
# Var aPtr2 located in register rsi
# Var aPtr1 located in register rdi
# [1118] Result := Compare8(aPtr1, aPtr2, aCount);
	call	NEXTPAS.CORE.MEM.UTILS_$$_COMPARE8$POINTER$POINTER$QWORD$$LONGINT
# Var $result located in register eax
# [1119] end;
	popq	%rcx
.Lc105:
	ret
.Lc102:

.section .text.n_nextpas.core.mem.utils_$$_compare$pointer$pointer$int64$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.UTILS_$$_COMPARE$POINTER$POINTER$INT64$$LONGINT
	.type	NEXTPAS.CORE.MEM.UTILS_$$_COMPARE$POINTER$POINTER$INT64$$LONGINT,@function
NEXTPAS.CORE.MEM.UTILS_$$_COMPARE$POINTER$POINTER$INT64$$LONGINT:
.Lc107:
# [1122] begin
	pushq	%rax
.Lc108:
# Var aPtr1 located in register rdi
# Var aPtr2 located in register rsi
# Var aCount located in register rdx
# Var aCount located in register rdx
# Var aPtr2 located in register rsi
# Var aPtr1 located in register rdi
# [1123] Result := Compare8(aPtr1, aPtr2, aCount);
	call	NEXTPAS.CORE.MEM.UTILS_$$_COMPARE8$POINTER$POINTER$INT64$$LONGINT
# Var $result located in register eax
# [1124] end;
	popq	%rcx
.Lc109:
	ret
.Lc106:

.section .text.n_nextpas.core.mem.utils_$$_compare8$pointer$pointer$qword$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.UTILS_$$_COMPARE8$POINTER$POINTER$QWORD$$LONGINT
	.type	NEXTPAS.CORE.MEM.UTILS_$$_COMPARE8$POINTER$POINTER$QWORD$$LONGINT,@function
NEXTPAS.CORE.MEM.UTILS_$$_COMPARE8$POINTER$POINTER$QWORD$$LONGINT:
.Lc111:
# Temps allocated between rsp+0 and rsp+8
# [1133] begin
	pushq	%rbx
.Lc112:
	pushq	%r12
.Lc113:
	pushq	%r13
.Lc114:
	pushq	%r14
.Lc115:
	pushq	%r15
.Lc116:
	leaq	-16(%rsp),%rsp
.Lc117:
# Var $result located in register r14d
# Var LChunkSize located in register rbx
# Var aPtr1 located in register rdi
# Var aPtr2 located in register rsi
# Var aCount located in register rdx
# Var LCurrentPtr1 located in stack [rsp+0]
# Var aPtr1 located in register rdi
# [1135] LCurrentPtr1    := PtrUInt(aPtr1);
	movq	%rdi,(%rsp)
# Var LCurrentPtr2 located in register r15
# Var aPtr2 located in register rsi
# [1136] LCurrentPtr2    := PtrUInt(aPtr2);
	movq	%rsi,%r15
# Var LRemainingCount located in register r13
# Var aCount located in register rdx
# [1137] LRemainingCount := aCount;
	movq	%rdx,%r13
# Var LResult located in register r12d
# [1138] LResult         := 0;
	xorl	%r12d,%r12d
# [1140] while LRemainingCount > 0 do
	jmp	.Lj153
	.p2align 4,,10
	.p2align 3
.Lj152:
# [1142] if LRemainingCount > MAX_SIZE_INT then
	movq	$9223372036854775807,%rax
# [1143] LChunkSize := MAX_SIZE_INT
	movq	$9223372036854775807,%rbx
	cmpq	%rax,%r13
# [1145] LChunkSize := SizeInt(LRemainingCount);
	cmovnaq	%r13,%rbx
# [1147] LResult := Compare8(Pointer(LCurrentPtr1), Pointer(LCurrentPtr2), LChunkSize);
	movq	%rbx,%rdx
	movq	%r15,%rsi
	movq	(%rsp),%rdi
	call	NEXTPAS.CORE.MEM.UTILS_$$_COMPARE8$POINTER$POINTER$INT64$$LONGINT
	movl	%eax,%r12d
# [1149] if LResult <> 0 then
	testl	%eax,%eax
# [1150] Exit(LResult);
	cmovnel	%r12d,%r14d
	jne	.Lj150
# [1152] Inc(LCurrentPtr1, LChunkSize);
	addq	%rbx,(%rsp)
# [1153] Inc(LCurrentPtr2, LChunkSize);
	addq	%rbx,%r15
# [1154] Dec(LRemainingCount, LChunkSize);
	subq	%rbx,%r13
.Lj153:
	testq	%r13,%r13
	jne	.Lj152
# Var LResult located in register eax
# [1157] Result := LResult;
	movl	%r12d,%r14d
.Lj150:
# [1158] end;
	movl	%r14d,%eax
	leaq	16(%rsp),%rsp
	popq	%r15
.Lc118:
	popq	%r14
.Lc119:
	popq	%r13
.Lc120:
	popq	%r12
.Lc121:
	popq	%rbx
.Lc122:
	ret
.Lc110:
.Le6:
	.size	NEXTPAS.CORE.MEM.UTILS_$$_COMPARE8$POINTER$POINTER$QWORD$$LONGINT, .Le6 - NEXTPAS.CORE.MEM.UTILS_$$_COMPARE8$POINTER$POINTER$QWORD$$LONGINT

.section .text.n_nextpas.core.mem.utils_$$_compare8$pointer$pointer$int64$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.UTILS_$$_COMPARE8$POINTER$POINTER$INT64$$LONGINT
	.type	NEXTPAS.CORE.MEM.UTILS_$$_COMPARE8$POINTER$POINTER$INT64$$LONGINT,@function
NEXTPAS.CORE.MEM.UTILS_$$_COMPARE8$POINTER$POINTER$INT64$$LONGINT:
.Lc124:
# [1161] begin
	pushq	%rax
.Lc125:
# Var aPtr1 located in register rdi
# Var aPtr2 located in register rsi
# Var aCount located in register rdx
# Var aPtr2 located in register rsi
# Var aPtr1 located in register rdi
# Var aCount located in register rdx
# [1162] Result := System.CompareByte(aPtr1^, aPtr2^, aCount);
	call	SYSTEM_$$_COMPAREBYTE$formal$formal$INT64$$INT64
# Var $result located in register eax
# [1163] end;
	popq	%rcx
.Lc126:
	ret
.Lc123:
.Le7:
	.size	NEXTPAS.CORE.MEM.UTILS_$$_COMPARE8$POINTER$POINTER$INT64$$LONGINT, .Le7 - NEXTPAS.CORE.MEM.UTILS_$$_COMPARE8$POINTER$POINTER$INT64$$LONGINT

.section .text.n_nextpas.core.mem.utils_$$_compare16$pointer$pointer$qword$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.UTILS_$$_COMPARE16$POINTER$POINTER$QWORD$$LONGINT
	.type	NEXTPAS.CORE.MEM.UTILS_$$_COMPARE16$POINTER$POINTER$QWORD$$LONGINT,@function
NEXTPAS.CORE.MEM.UTILS_$$_COMPARE16$POINTER$POINTER$QWORD$$LONGINT:
.Lc128:
# Temps allocated between rsp+0 and rsp+8
# [1172] begin
	pushq	%rbx
.Lc129:
	pushq	%r12
.Lc130:
	pushq	%r13
.Lc131:
	pushq	%r14
.Lc132:
	pushq	%r15
.Lc133:
	leaq	-16(%rsp),%rsp
.Lc134:
# Var $result located in register r14d
# Var LChunkSize located in register rbx
# Var aPtr1 located in register rdi
# Var aPtr2 located in register rsi
# Var aCount located in register rdx
# Var LCurrentPtr1 located in stack [rsp+0]
# Var aPtr1 located in register rdi
# [1174] LCurrentPtr1    := PtrUInt(aPtr1);
	movq	%rdi,(%rsp)
# Var LCurrentPtr2 located in register r15
# Var aPtr2 located in register rsi
# [1175] LCurrentPtr2    := PtrUInt(aPtr2);
	movq	%rsi,%r15
# Var LRemainingCount located in register r13
# Var aCount located in register rdx
# [1176] LRemainingCount := aCount;
	movq	%rdx,%r13
# Var LResult located in register r12d
# [1177] LResult         := 0;
	xorl	%r12d,%r12d
# [1179] while LRemainingCount > 0 do
	jmp	.Lj165
	.p2align 4,,10
	.p2align 3
.Lj164:
# [1181] if LRemainingCount > MAX_SIZE_INT then
	movq	$9223372036854775807,%rax
# [1182] LChunkSize := MAX_SIZE_INT
	movq	$9223372036854775807,%rbx
	cmpq	%rax,%r13
# [1184] LChunkSize := SizeInt(LRemainingCount);
	cmovnaq	%r13,%rbx
# [1186] LResult := Compare16(Pointer(LCurrentPtr1), Pointer(LCurrentPtr2), LChunkSize);
	movq	%rbx,%rdx
	movq	%r15,%rsi
	movq	(%rsp),%rdi
	call	NEXTPAS.CORE.MEM.UTILS_$$_COMPARE16$POINTER$POINTER$INT64$$LONGINT
	movl	%eax,%r12d
# [1188] if LResult <> 0 then
	testl	%eax,%eax
# [1190] Result := LResult;
	cmovnel	%r12d,%r14d
# [1191] Exit;
	jne	.Lj162
# [1194] Inc(LCurrentPtr1, LChunkSize * SizeOf(UInt16));
	leaq	(%rbx,%rbx,1),%rax
	addq	%rax,(%rsp)
# [1195] Inc(LCurrentPtr2, LChunkSize * SizeOf(UInt16));
	leaq	(%rbx,%rbx,1),%rax
	addq	%rax,%r15
# [1196] Dec(LRemainingCount, LChunkSize);
	subq	%rbx,%r13
.Lj165:
	testq	%r13,%r13
	jne	.Lj164
# Var LResult located in register eax
# [1199] Result := LResult;
	movl	%r12d,%r14d
.Lj162:
# [1200] end;
	movl	%r14d,%eax
	leaq	16(%rsp),%rsp
	popq	%r15
.Lc135:
	popq	%r14
.Lc136:
	popq	%r13
.Lc137:
	popq	%r12
.Lc138:
	popq	%rbx
.Lc139:
	ret
.Lc127:

.section .text.n_nextpas.core.mem.utils_$$_compare16$pointer$pointer$int64$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.UTILS_$$_COMPARE16$POINTER$POINTER$INT64$$LONGINT
	.type	NEXTPAS.CORE.MEM.UTILS_$$_COMPARE16$POINTER$POINTER$INT64$$LONGINT,@function
NEXTPAS.CORE.MEM.UTILS_$$_COMPARE16$POINTER$POINTER$INT64$$LONGINT:
.Lc141:
# [1203] begin
	pushq	%rax
.Lc142:
# Var aPtr1 located in register rdi
# Var aPtr2 located in register rsi
# Var aCount located in register rdx
# Var aPtr2 located in register rsi
# Var aPtr1 located in register rdi
# Var aCount located in register rdx
# [1204] Result := System.CompareWord(aPtr1^, aPtr2^, aCount);
	call	SYSTEM_$$_COMPAREWORD$formal$formal$INT64$$INT64
# Var $result located in register eax
# [1205] end;
	popq	%rcx
.Lc143:
	ret
.Lc140:
.Le8:
	.size	NEXTPAS.CORE.MEM.UTILS_$$_COMPARE16$POINTER$POINTER$INT64$$LONGINT, .Le8 - NEXTPAS.CORE.MEM.UTILS_$$_COMPARE16$POINTER$POINTER$INT64$$LONGINT

.section .text.n_nextpas.core.mem.utils_$$_compare32$pointer$pointer$qword$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.UTILS_$$_COMPARE32$POINTER$POINTER$QWORD$$LONGINT
	.type	NEXTPAS.CORE.MEM.UTILS_$$_COMPARE32$POINTER$POINTER$QWORD$$LONGINT,@function
NEXTPAS.CORE.MEM.UTILS_$$_COMPARE32$POINTER$POINTER$QWORD$$LONGINT:
.Lc145:
# Temps allocated between rsp+0 and rsp+8
# [1214] begin
	pushq	%rbx
.Lc146:
	pushq	%r12
.Lc147:
	pushq	%r13
.Lc148:
	pushq	%r14
.Lc149:
	pushq	%r15
.Lc150:
	leaq	-16(%rsp),%rsp
.Lc151:
# Var $result located in register r14d
# Var LChunkSize located in register rbx
# Var aPtr1 located in register rdi
# Var aPtr2 located in register rsi
# Var aCount located in register rdx
# Var LCurrentPtr1 located in stack [rsp+0]
# Var aPtr1 located in register rdi
# [1216] LCurrentPtr1    := PtrUInt(aPtr1);
	movq	%rdi,(%rsp)
# Var LCurrentPtr2 located in register r15
# Var aPtr2 located in register rsi
# [1217] LCurrentPtr2    := PtrUInt(aPtr2);
	movq	%rsi,%r15
# Var LRemainingCount located in register r13
# Var aCount located in register rdx
# [1218] LRemainingCount := aCount;
	movq	%rdx,%r13
# Var LResult located in register r12d
# [1219] LResult         := 0;
	xorl	%r12d,%r12d
# [1221] while LRemainingCount > 0 do
	jmp	.Lj177
	.p2align 4,,10
	.p2align 3
.Lj176:
# [1223] if LRemainingCount > MAX_SIZE_INT then
	movq	$9223372036854775807,%rax
# [1224] LChunkSize := MAX_SIZE_INT
	movq	$9223372036854775807,%rbx
	cmpq	%rax,%r13
# [1226] LChunkSize := SizeInt(LRemainingCount);
	cmovnaq	%r13,%rbx
# [1228] LResult := Compare32(Pointer(LCurrentPtr1), Pointer(LCurrentPtr2), LChunkSize);
	movq	%rbx,%rdx
	movq	%r15,%rsi
	movq	(%rsp),%rdi
	call	NEXTPAS.CORE.MEM.UTILS_$$_COMPARE32$POINTER$POINTER$INT64$$LONGINT
	movl	%eax,%r12d
# [1230] if LResult <> 0 then
	testl	%eax,%eax
# [1232] Result := LResult;
	cmovnel	%r12d,%r14d
# [1233] Exit;
	jne	.Lj174
# [1236] Inc(LCurrentPtr1, LChunkSize * SizeOf(UInt32));
	leaq	(,%rbx,4),%rax
	addq	%rax,(%rsp)
# [1237] Inc(LCurrentPtr2, LChunkSize * SizeOf(UInt32));
	leaq	(,%rbx,4),%rax
	addq	%rax,%r15
# [1238] Dec(LRemainingCount, LChunkSize);
	subq	%rbx,%r13
.Lj177:
	testq	%r13,%r13
	jne	.Lj176
# Var LResult located in register eax
# [1241] Result := LResult;
	movl	%r12d,%r14d
.Lj174:
# [1242] end;
	movl	%r14d,%eax
	leaq	16(%rsp),%rsp
	popq	%r15
.Lc152:
	popq	%r14
.Lc153:
	popq	%r13
.Lc154:
	popq	%r12
.Lc155:
	popq	%rbx
.Lc156:
	ret
.Lc144:

.section .text.n_nextpas.core.mem.utils_$$_compare32$pointer$pointer$int64$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.UTILS_$$_COMPARE32$POINTER$POINTER$INT64$$LONGINT
	.type	NEXTPAS.CORE.MEM.UTILS_$$_COMPARE32$POINTER$POINTER$INT64$$LONGINT,@function
NEXTPAS.CORE.MEM.UTILS_$$_COMPARE32$POINTER$POINTER$INT64$$LONGINT:
.Lc158:
# [1245] begin
	pushq	%rax
.Lc159:
# Var aPtr1 located in register rdi
# Var aPtr2 located in register rsi
# Var aCount located in register rdx
# Var aPtr2 located in register rsi
# Var aPtr1 located in register rdi
# Var aCount located in register rdx
# [1248] Result := System.CompareDWord(aPtr1^, aPtr2^, aCount);
	call	SYSTEM_$$_COMPAREDWORD$formal$formal$INT64$$INT64
# Var $result located in register eax
# [1249] end;
	popq	%rcx
.Lc160:
	ret
.Lc157:
.Le9:
	.size	NEXTPAS.CORE.MEM.UTILS_$$_COMPARE32$POINTER$POINTER$INT64$$LONGINT, .Le9 - NEXTPAS.CORE.MEM.UTILS_$$_COMPARE32$POINTER$POINTER$INT64$$LONGINT

.section .text.n_nextpas.core.mem.utils_$$_equal$pointer$pointer$qword$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.UTILS_$$_EQUAL$POINTER$POINTER$QWORD$$BOOLEAN
	.type	NEXTPAS.CORE.MEM.UTILS_$$_EQUAL$POINTER$POINTER$QWORD$$BOOLEAN,@function
NEXTPAS.CORE.MEM.UTILS_$$_EQUAL$POINTER$POINTER$QWORD$$BOOLEAN:
.Lc162:
# [1253] begin
	pushq	%rax
.Lc163:
# Var aPtr1 located in register rdi
# Var aPtr2 located in register rsi
# Var aSize located in register rdx
# [1254] Result := (Compare8(aPtr1, aPtr2, aSize) = 0);
	call	NEXTPAS.CORE.MEM.UTILS_$$_COMPARE8$POINTER$POINTER$QWORD$$LONGINT
	testl	%eax,%eax
# Var $result located in register al
	seteb	%al
# [1255] end;
	popq	%rcx
.Lc164:
	ret
.Lc161:

.section .text.n_nextpas.core.mem.utils_$$_equal$pointer$pointer$int64$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.UTILS_$$_EQUAL$POINTER$POINTER$INT64$$BOOLEAN
	.type	NEXTPAS.CORE.MEM.UTILS_$$_EQUAL$POINTER$POINTER$INT64$$BOOLEAN,@function
NEXTPAS.CORE.MEM.UTILS_$$_EQUAL$POINTER$POINTER$INT64$$BOOLEAN:
.Lc166:
# [1258] begin
	pushq	%rax
.Lc167:
# Var aPtr1 located in register rdi
# Var aPtr2 located in register rsi
# Var aSize located in register rdx
# [1259] Result := (Compare8(aPtr1, aPtr2, aSize) = 0);
	call	NEXTPAS.CORE.MEM.UTILS_$$_COMPARE8$POINTER$POINTER$INT64$$LONGINT
	testl	%eax,%eax
# Var $result located in register al
	seteb	%al
# [1260] end;
	popq	%rcx
.Lc168:
	ret
.Lc165:

.section .text.n_nextpas.core.mem.utils_$$_isaligned$pointer$qword$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.UTILS_$$_ISALIGNED$POINTER$QWORD$$BOOLEAN
	.type	NEXTPAS.CORE.MEM.UTILS_$$_ISALIGNED$POINTER$QWORD$$BOOLEAN,@function
NEXTPAS.CORE.MEM.UTILS_$$_ISALIGNED$POINTER$QWORD$$BOOLEAN:
.Lc170:
# Var aPtr located in register rdi
# Var aAlignment located in register rsi
# [1263] begin
# [1265] Result := (PtrUInt(aPtr) and (aAlignment - 1)) = 0;
	leaq	-1(%rsi),%rax
	andq	%rdi,%rax
# Var $result located in register al
	seteb	%al
.Lc171:
# [1267] end;
	ret
.Lc169:

.section .text.n_nextpas.core.mem.utils_$$_alignup$pointer$qword$$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.UTILS_$$_ALIGNUP$POINTER$QWORD$$POINTER
	.type	NEXTPAS.CORE.MEM.UTILS_$$_ALIGNUP$POINTER$QWORD$$POINTER,@function
NEXTPAS.CORE.MEM.UTILS_$$_ALIGNUP$POINTER$QWORD$$POINTER:
.Lc173:
# Temps allocated between rbp-16 and rbp+0
# [1270] begin
	pushq	%rbp
.Lc174:
	movq	%rsp,%rbp
.Lc175:
	leaq	-16(%rsp),%rsp
	movq	%rbx,-16(%rbp)
	movq	%r12,-8(%rbp)
	movq	%rdi,%rbx
# Var aPtr located in register rbx
	movq	%rsi,%r12
# Var aAlignment located in register r12
# [1271] if aPtr = nil then
	testq	%rdi,%rdi
	jne	.Lj195
.Lj196:
# [1272] raise EArgumentNil.Create('nextpas.core.mem.utils.AlignUp: aPtr is nil');
	movq	$.Ld16,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj196,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj195:
# [1274] if aAlignment = 0 then
	testq	%r12,%r12
	jne	.Lj198
.Lj199:
# [1275] raise EInvalidArgument.Create('nextpas.core.mem.utils.AlignUp: aAlignment is 0');
	movq	$.Ld17,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj199,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj198:
# [1277] if not IsPowerOfTwo(aAlignment) then
	movq	%r12,%rdi
	call	NEXTPAS.CORE.MEM.UTILS_$$_ISPOWEROFTWO$QWORD$$BOOLEAN
	testb	%al,%al
	jne	.Lj201
.Lj202:
# [1278] raise EInvalidArgument.Create('nextpas.core.mem.utils.AlignUp: aAlignment must be a power of two');
	movq	$.Ld18,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj202,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj201:
# [1280] Result := AlignUpUnChecked(aPtr, aAlignment);
	movq	%r12,%rsi
# Var aAlignment located in register rsi
	movq	%rbx,%rdi
# Var aPtr located in register rdi
	call	NEXTPAS.CORE.MEM.UTILS_$$_ALIGNUPUNCHECKED$POINTER$QWORD$$POINTER
# Var $result located in register rax
# [1281] end;
	movq	-16(%rbp),%rbx
	movq	-8(%rbp),%r12
.Lc176:
	movq	%rbp,%rsp
.Lc177:
	popq	%rbp
	ret
.Lc172:

.section .text.n_nextpas.core.mem.utils_$$_alignupunchecked$pointer$qword$$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.UTILS_$$_ALIGNUPUNCHECKED$POINTER$QWORD$$POINTER
	.type	NEXTPAS.CORE.MEM.UTILS_$$_ALIGNUPUNCHECKED$POINTER$QWORD$$POINTER,@function
NEXTPAS.CORE.MEM.UTILS_$$_ALIGNUPUNCHECKED$POINTER$QWORD$$POINTER:
.Lc179:
# Var aPtr located in register rdi
# Var aAlignment located in register rsi
# [1284] begin
# [1286] Result := Pointer((PtrUInt(aPtr) + (aAlignment - 1)) and not (aAlignment - 1));
	leaq	-1(%rsi),%rdx
	leaq	-1(%rdi,%rsi),%rax
	notq	%rdx
	andq	%rdx,%rax
# Var $result located in register rax
.Lc180:
# [1288] end;
	ret
.Lc178:
.Le10:
	.size	NEXTPAS.CORE.MEM.UTILS_$$_ALIGNUPUNCHECKED$POINTER$QWORD$$POINTER, .Le10 - NEXTPAS.CORE.MEM.UTILS_$$_ALIGNUPUNCHECKED$POINTER$QWORD$$POINTER

.section .text.n_nextpas.core.mem.utils_$$_ispoweroftwo$qword$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.UTILS_$$_ISPOWEROFTWO$QWORD$$BOOLEAN
	.type	NEXTPAS.CORE.MEM.UTILS_$$_ISPOWEROFTWO$QWORD$$BOOLEAN,@function
NEXTPAS.CORE.MEM.UTILS_$$_ISPOWEROFTWO$QWORD$$BOOLEAN:
.Lc182:
# Var N located in register rdi
# [1292] begin
# [1293] Result := (N<>0) and ((N and (N-1))=0);
	testq	%rdi,%rdi
	je	.Lj208
	leaq	-1(%rdi),%rax
	andq	%rdi,%rax
	seteb	%al
# Var $result located in register al
	ret
.Lj208:
	xorb	%al,%al
.Lc183:
# [1294] end;
	ret
.Lc181:
.Le11:
	.size	NEXTPAS.CORE.MEM.UTILS_$$_ISPOWEROFTWO$QWORD$$BOOLEAN, .Le11 - NEXTPAS.CORE.MEM.UTILS_$$_ISPOWEROFTWO$QWORD$$BOOLEAN

.section .text.n_nextpas.core.mem.utils_$$_aligndown$pointer$qword$$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.UTILS_$$_ALIGNDOWN$POINTER$QWORD$$POINTER
	.type	NEXTPAS.CORE.MEM.UTILS_$$_ALIGNDOWN$POINTER$QWORD$$POINTER,@function
NEXTPAS.CORE.MEM.UTILS_$$_ALIGNDOWN$POINTER$QWORD$$POINTER:
.Lc185:
# Temps allocated between rbp-16 and rbp+0
# [1297] begin
	pushq	%rbp
.Lc186:
	movq	%rsp,%rbp
.Lc187:
	leaq	-16(%rsp),%rsp
	movq	%rbx,-16(%rbp)
	movq	%r12,-8(%rbp)
	movq	%rdi,%rbx
# Var aPtr located in register rbx
	movq	%rsi,%r12
# Var aAlignment located in register r12
# [1298] if aPtr = nil then
	testq	%rdi,%rdi
	jne	.Lj214
.Lj215:
# [1299] raise EArgumentNil.Create('nextpas.core.mem.utils.AlignDown: aPtr is nil');
	movq	$.Ld19,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj215,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj214:
# [1300] if aAlignment = 0 then
	testq	%r12,%r12
	jne	.Lj217
.Lj218:
# [1301] raise EInvalidArgument.Create('nextpas.core.mem.utils.AlignDown: aAlignment is 0');
	movq	$.Ld20,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj218,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj217:
# [1302] if not IsPowerOfTwo(aAlignment) then
	movq	%r12,%rdi
	call	NEXTPAS.CORE.MEM.UTILS_$$_ISPOWEROFTWO$QWORD$$BOOLEAN
	testb	%al,%al
	jne	.Lj220
.Lj221:
# [1303] raise EInvalidArgument.Create('nextpas.core.mem.utils.AlignDown: aAlignment must be a power of two');
	movq	$.Ld21,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj221,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj220:
# [1304] Result := AlignDownUnChecked(aPtr, aAlignment);
	movq	%r12,%rsi
# Var aAlignment located in register rsi
	movq	%rbx,%rdi
# Var aPtr located in register rdi
	call	NEXTPAS.CORE.MEM.UTILS_$$_ALIGNDOWNUNCHECKED$POINTER$QWORD$$POINTER
# Var $result located in register rax
# [1305] end;
	movq	-16(%rbp),%rbx
	movq	-8(%rbp),%r12
.Lc188:
	movq	%rbp,%rsp
.Lc189:
	popq	%rbp
	ret
.Lc184:

.section .text.n_nextpas.core.mem.utils_$$_aligndownunchecked$pointer$qword$$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.UTILS_$$_ALIGNDOWNUNCHECKED$POINTER$QWORD$$POINTER
	.type	NEXTPAS.CORE.MEM.UTILS_$$_ALIGNDOWNUNCHECKED$POINTER$QWORD$$POINTER,@function
NEXTPAS.CORE.MEM.UTILS_$$_ALIGNDOWNUNCHECKED$POINTER$QWORD$$POINTER:
.Lc191:
# Var aPtr located in register rdi
# Var aAlignment located in register rsi
# [1308] begin
# [1310] Result := Pointer(PtrUInt(aPtr) and not (aAlignment - 1));
	leaq	-1(%rsi),%rax
	notq	%rax
	andq	%rdi,%rax
# Var $result located in register rax
.Lc192:
# [1312] end;
	ret
.Lc190:
.Le12:
	.size	NEXTPAS.CORE.MEM.UTILS_$$_ALIGNDOWNUNCHECKED$POINTER$QWORD$$POINTER, .Le12 - NEXTPAS.CORE.MEM.UTILS_$$_ALIGNDOWNUNCHECKED$POINTER$QWORD$$POINTER
# End asmlist al_procedures
# Begin asmlist al_typedconsts

.section .rodata.n_.Ld1
	.balign 8
.Ld1$strlab:
	.short	0,1
	.long	-1
	.quad	81
.Ld1:
# [831] raise EOutOfRange.CreateFmt('aSize1 (%d) is too large for aPtr1 (%p), causing address calculation to overflow.', [aSize1, aPtr1]);
	.ascii	"aSize1 (%d) is too large for aPtr1 (%p), causing ad"
	.ascii	"dress calculation to overflow.\000"
.Le13:
	.size	.Ld1$strlab, .Le13 - .Ld1$strlab

.section .rodata.n_.Ld2
	.balign 8
.Ld2$strlab:
	.short	0,1
	.long	-1
	.quad	81
.Ld2:
# [834] raise EOutOfRange.CreateFmt('aSize2 (%d) is too large for aPtr2 (%p), causing address calculation to overflow.', [aSize2, aPtr2]);
	.ascii	"aSize2 (%d) is too large for aPtr2 (%p), causing ad"
	.ascii	"dress calculation to overflow.\000"
.Le14:
	.size	.Ld2$strlab, .Le14 - .Ld2$strlab

.section .rodata.n_.Ld3
	.balign 8
.Ld3$strlab:
	.short	0,1
	.long	-1
	.quad	41
.Ld3:
# [862] raise EArgumentNil.Create('nextpas.core.mem.utils.Copy: aSrc is nil.');
	.ascii	"nextpas.core.mem.utils.Copy: aSrc is nil.\000"
.Le15:
	.size	.Ld3$strlab, .Le15 - .Ld3$strlab

.section .rodata.n_.Ld4
	.balign 8
.Ld4$strlab:
	.short	0,1
	.long	-1
	.quad	41
.Ld4:
# [865] raise EArgumentNil.Create('nextpas.core.mem.utils.Copy: aDst is nil.');
	.ascii	"nextpas.core.mem.utils.Copy: aDst is nil.\000"
.Le16:
	.size	.Ld4$strlab, .Le16 - .Ld4$strlab

.section .rodata.n_.Ld5
	.balign 8
.Ld5$strlab:
	.short	0,1
	.long	-1
	.quad	85
.Ld5:
# [870] raise EOutOfRange.CreateFmt('nextpas.core.mem.utils.Copy: aSize (%d) exceeds maximum allowed for System.Move (%d).', [aSize, MAX_SIZE_INT]);
	.ascii	"nextpas.core.mem.utils.Copy: aSize (%d) exceeds max"
	.ascii	"imum allowed for System.Move (%d).\000"
.Le17:
	.size	.Ld5$strlab, .Le17 - .Ld5$strlab

.section .rodata.n_.Ld6
	.balign 8
.Ld6$strlab:
	.short	0,1
	.long	-1
	.quad	51
.Ld6:
# [891] raise EArgumentNil.Create('nextpas.core.mem.utils.CopyNonOverlap: aSrc is nil.');
	.ascii	"nextpas.core.mem.utils.CopyNonOverlap: aSrc is nil."
	.ascii	"\000"
.Le18:
	.size	.Ld6$strlab, .Le18 - .Ld6$strlab

.section .rodata.n_.Ld7
	.balign 8
.Ld7$strlab:
	.short	0,1
	.long	-1
	.quad	51
.Ld7:
# [894] raise EArgumentNil.Create('nextpas.core.mem.utils.CopyNonOverlap: aDst is nil.');
	.ascii	"nextpas.core.mem.utils.CopyNonOverlap: aDst is nil."
	.ascii	"\000"
.Le19:
	.size	.Ld7$strlab, .Le19 - .Ld7$strlab

.section .rodata.n_.Ld8
	.balign 8
.Ld8$strlab:
	.short	0,1
	.long	-1
	.quad	95
.Ld8:
# [899] raise EOutOfRange.CreateFmt('nextpas.core.mem.utils.CopyNonOverlap: aSize (%d) exceeds maximum allowed for System.Move (%d).', [aSize, MAX_SIZE_INT]);
	.ascii	"nextpas.core.mem.utils.CopyNonOverlap: aSize (%d) e"
	.ascii	"xceeds maximum allowed for System.Move (%d).\000"
.Le20:
	.size	.Ld8$strlab, .Le20 - .Ld8$strlab

.section .rodata.n_.Ld9
	.balign 8
.Ld9$strlab:
	.short	0,1
	.long	-1
	.quad	41
.Ld9:
# [930] raise EArgumentNil.Create('nextpas.core.mem.utils.Fill8: aDst is nil');
	.ascii	"nextpas.core.mem.utils.Fill8: aDst is nil\000"
.Le21:
	.size	.Ld9$strlab, .Le21 - .Ld9$strlab

.section .rodata.n_.Ld10
	.balign 8
.Ld10$strlab:
	.short	0,1
	.long	-1
	.quad	42
.Ld10:
# [977] raise EArgumentNil.Create('nextpas.core.mem.utils.Fill16: aDst is nil');
	.ascii	"nextpas.core.mem.utils.Fill16: aDst is nil\000"
.Le22:
	.size	.Ld10$strlab, .Le22 - .Ld10$strlab

.section .rodata.n_.Ld11
	.balign 8
.Ld11$strlab:
	.short	0,1
	.long	-1
	.quad	58
.Ld11:
# [994] raise EOverflow.Create('nextpas.core.mem.utils.Fill16: pointer arithmetic overflow');
	.ascii	"nextpas.core.mem.utils.Fill16: pointer arithmetic o"
	.ascii	"verflow\000"
.Le23:
	.size	.Ld11$strlab, .Le23 - .Ld11$strlab

.section .rodata.n_.Ld12
	.balign 8
.Ld12$strlab:
	.short	0,1
	.long	-1
	.quad	42
.Ld12:
# [1023] raise EArgumentNil.Create('nextpas.core.mem.utils.Fill32: aDst is nil');
	.ascii	"nextpas.core.mem.utils.Fill32: aDst is nil\000"
.Le24:
	.size	.Ld12$strlab, .Le24 - .Ld12$strlab

.section .rodata.n_.Ld13
	.balign 8
.Ld13$strlab:
	.short	0,1
	.long	-1
	.quad	58
.Ld13:
# [1040] raise EOverflow.Create('nextpas.core.mem.utils.Fill32: pointer arithmetic overflow');
	.ascii	"nextpas.core.mem.utils.Fill32: pointer arithmetic o"
	.ascii	"verflow\000"
.Le25:
	.size	.Ld13$strlab, .Le25 - .Ld13$strlab

.section .rodata.n_.Ld14
	.balign 8
.Ld14$strlab:
	.short	0,1
	.long	-1
	.quad	42
.Ld14:
# [1069] raise EArgumentNil.Create('nextpas.core.mem.utils.Fill64: aDst is nil');
	.ascii	"nextpas.core.mem.utils.Fill64: aDst is nil\000"
.Le26:
	.size	.Ld14$strlab, .Le26 - .Ld14$strlab

.section .rodata.n_.Ld15
	.balign 8
.Ld15$strlab:
	.short	0,1
	.long	-1
	.quad	58
.Ld15:
# [1086] raise EOverflow.Create('nextpas.core.mem.utils.Fill64: pointer arithmetic overflow');
	.ascii	"nextpas.core.mem.utils.Fill64: pointer arithmetic o"
	.ascii	"verflow\000"
.Le27:
	.size	.Ld15$strlab, .Le27 - .Ld15$strlab

.section .rodata.n_.Ld16
	.balign 8
.Ld16$strlab:
	.short	0,1
	.long	-1
	.quad	43
.Ld16:
# [1272] raise EArgumentNil.Create('nextpas.core.mem.utils.AlignUp: aPtr is nil');
	.ascii	"nextpas.core.mem.utils.AlignUp: aPtr is nil\000"
.Le28:
	.size	.Ld16$strlab, .Le28 - .Ld16$strlab

.section .rodata.n_.Ld17
	.balign 8
.Ld17$strlab:
	.short	0,1
	.long	-1
	.quad	47
.Ld17:
# [1275] raise EInvalidArgument.Create('nextpas.core.mem.utils.AlignUp: aAlignment is 0');
	.ascii	"nextpas.core.mem.utils.AlignUp: aAlignment is 0\000"
.Le29:
	.size	.Ld17$strlab, .Le29 - .Ld17$strlab

.section .rodata.n_.Ld18
	.balign 8
.Ld18$strlab:
	.short	0,1
	.long	-1
	.quad	65
.Ld18:
# [1278] raise EInvalidArgument.Create('nextpas.core.mem.utils.AlignUp: aAlignment must be a power of two');
	.ascii	"nextpas.core.mem.utils.AlignUp: aAlignment must be "
	.ascii	"a power of two\000"
.Le30:
	.size	.Ld18$strlab, .Le30 - .Ld18$strlab

.section .rodata.n_.Ld19
	.balign 8
.Ld19$strlab:
	.short	0,1
	.long	-1
	.quad	45
.Ld19:
# [1299] raise EArgumentNil.Create('nextpas.core.mem.utils.AlignDown: aPtr is nil');
	.ascii	"nextpas.core.mem.utils.AlignDown: aPtr is nil\000"
.Le31:
	.size	.Ld19$strlab, .Le31 - .Ld19$strlab

.section .rodata.n_.Ld20
	.balign 8
.Ld20$strlab:
	.short	0,1
	.long	-1
	.quad	49
.Ld20:
# [1301] raise EInvalidArgument.Create('nextpas.core.mem.utils.AlignDown: aAlignment is 0');
	.ascii	"nextpas.core.mem.utils.AlignDown: aAlignment is 0\000"
.Le32:
	.size	.Ld20$strlab, .Le32 - .Ld20$strlab

.section .rodata.n_.Ld21
	.balign 8
.Ld21$strlab:
	.short	0,1
	.long	-1
	.quad	67
.Ld21:
# [1303] raise EInvalidArgument.Create('nextpas.core.mem.utils.AlignDown: aAlignment must be a power of two');
	.ascii	"nextpas.core.mem.utils.AlignDown: aAlignment must b"
	.ascii	"e a power of two\000"
.Le33:
	.size	.Ld21$strlab, .Le33 - .Ld21$strlab
# End asmlist al_typedconsts
# Begin asmlist al_dwarf_frame

.section .debug_frame
.Lc193:
	.long	.Lc195-.Lc194
.Lc194:
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
.Lc195:
	.long	.Lc197-.Lc196
.Lc196:
	.long	.Lc193
	.quad	.Lc2
	.quad	.Lc1-.Lc2
	.byte	2
	.byte	.Lc3-.Lc2
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc4-.Lc3
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc5-.Lc4
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc6-.Lc5
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc197:
	.long	.Lc200-.Lc199
.Lc199:
	.long	.Lc193
	.quad	.Lc8
	.quad	.Lc7-.Lc8
	.byte	4
	.long	.Lc9-.Lc8
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc200:
	.long	.Lc203-.Lc202
.Lc202:
	.long	.Lc193
	.quad	.Lc11
	.quad	.Lc10-.Lc11
	.byte	2
	.byte	.Lc12-.Lc11
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc13-.Lc12
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc203:
	.long	.Lc206-.Lc205
.Lc205:
	.long	.Lc193
	.quad	.Lc15
	.quad	.Lc14-.Lc15
	.byte	2
	.byte	.Lc16-.Lc15
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc17-.Lc16
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc206:
	.long	.Lc209-.Lc208
.Lc208:
	.long	.Lc193
	.quad	.Lc19
	.quad	.Lc18-.Lc19
	.byte	2
	.byte	.Lc20-.Lc19
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc21-.Lc20
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc22-.Lc21
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc23-.Lc22
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc209:
	.long	.Lc212-.Lc211
.Lc211:
	.long	.Lc193
	.quad	.Lc25
	.quad	.Lc24-.Lc25
	.byte	2
	.byte	.Lc26-.Lc25
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc27-.Lc26
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc212:
	.long	.Lc215-.Lc214
.Lc214:
	.long	.Lc193
	.quad	.Lc29
	.quad	.Lc28-.Lc29
	.byte	2
	.byte	.Lc30-.Lc29
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc31-.Lc30
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc32-.Lc31
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc33-.Lc32
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc215:
	.long	.Lc218-.Lc217
.Lc217:
	.long	.Lc193
	.quad	.Lc35
	.quad	.Lc34-.Lc35
	.byte	2
	.byte	.Lc36-.Lc35
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc37-.Lc36
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc218:
	.long	.Lc221-.Lc220
.Lc220:
	.long	.Lc193
	.quad	.Lc39
	.quad	.Lc38-.Lc39
	.byte	2
	.byte	.Lc40-.Lc39
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc41-.Lc40
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc221:
	.long	.Lc224-.Lc223
.Lc223:
	.long	.Lc193
	.quad	.Lc43
	.quad	.Lc42-.Lc43
	.byte	2
	.byte	.Lc44-.Lc43
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc45-.Lc44
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc224:
	.long	.Lc227-.Lc226
.Lc226:
	.long	.Lc193
	.quad	.Lc47
	.quad	.Lc46-.Lc47
	.byte	2
	.byte	.Lc48-.Lc47
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc49-.Lc48
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc50-.Lc49
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc51-.Lc50
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc227:
	.long	.Lc230-.Lc229
.Lc229:
	.long	.Lc193
	.quad	.Lc53
	.quad	.Lc52-.Lc53
	.byte	2
	.byte	.Lc54-.Lc53
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc55-.Lc54
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc56-.Lc55
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc57-.Lc56
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc230:
	.long	.Lc233-.Lc232
.Lc232:
	.long	.Lc193
	.quad	.Lc59
	.quad	.Lc58-.Lc59
	.byte	2
	.byte	.Lc60-.Lc59
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc61-.Lc60
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc62-.Lc61
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc63-.Lc62
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc233:
	.long	.Lc236-.Lc235
.Lc235:
	.long	.Lc193
	.quad	.Lc65
	.quad	.Lc64-.Lc65
	.byte	2
	.byte	.Lc66-.Lc65
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc67-.Lc66
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc68-.Lc67
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc69-.Lc68
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc236:
	.long	.Lc239-.Lc238
.Lc238:
	.long	.Lc193
	.quad	.Lc71
	.quad	.Lc70-.Lc71
	.byte	2
	.byte	.Lc72-.Lc71
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc73-.Lc72
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc74-.Lc73
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc75-.Lc74
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc239:
	.long	.Lc242-.Lc241
.Lc241:
	.long	.Lc193
	.quad	.Lc77
	.quad	.Lc76-.Lc77
	.byte	2
	.byte	.Lc78-.Lc77
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc79-.Lc78
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc80-.Lc79
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc81-.Lc80
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc242:
	.long	.Lc245-.Lc244
.Lc244:
	.long	.Lc193
	.quad	.Lc83
	.quad	.Lc82-.Lc83
	.byte	2
	.byte	.Lc84-.Lc83
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc85-.Lc84
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc86-.Lc85
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc87-.Lc86
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc245:
	.long	.Lc248-.Lc247
.Lc247:
	.long	.Lc193
	.quad	.Lc89
	.quad	.Lc88-.Lc89
	.byte	2
	.byte	.Lc90-.Lc89
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc91-.Lc90
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc92-.Lc91
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc93-.Lc92
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc248:
	.long	.Lc251-.Lc250
.Lc250:
	.long	.Lc193
	.quad	.Lc95
	.quad	.Lc94-.Lc95
	.byte	2
	.byte	.Lc96-.Lc95
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc97-.Lc96
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc251:
	.long	.Lc254-.Lc253
.Lc253:
	.long	.Lc193
	.quad	.Lc99
	.quad	.Lc98-.Lc99
	.byte	2
	.byte	.Lc100-.Lc99
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc101-.Lc100
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc254:
	.long	.Lc257-.Lc256
.Lc256:
	.long	.Lc193
	.quad	.Lc103
	.quad	.Lc102-.Lc103
	.byte	2
	.byte	.Lc104-.Lc103
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc105-.Lc104
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc257:
	.long	.Lc260-.Lc259
.Lc259:
	.long	.Lc193
	.quad	.Lc107
	.quad	.Lc106-.Lc107
	.byte	2
	.byte	.Lc108-.Lc107
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc109-.Lc108
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc260:
	.long	.Lc263-.Lc262
.Lc262:
	.long	.Lc193
	.quad	.Lc111
	.quad	.Lc110-.Lc111
	.byte	2
	.byte	.Lc112-.Lc111
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc113-.Lc112
	.byte	5
	.uleb128	12
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc114-.Lc113
	.byte	5
	.uleb128	13
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc115-.Lc114
	.byte	5
	.uleb128	14
	.uleb128	12
	.byte	14
	.uleb128	48
	.byte	2
	.byte	.Lc116-.Lc115
	.byte	5
	.uleb128	15
	.uleb128	14
	.byte	14
	.uleb128	56
	.byte	2
	.byte	.Lc117-.Lc116
	.byte	14
	.uleb128	64
	.byte	4
	.long	.Lc118-.Lc117
	.byte	6
	.uleb128	15
	.byte	2
	.byte	.Lc119-.Lc118
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc120-.Lc119
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc121-.Lc120
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc122-.Lc121
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc263:
	.long	.Lc266-.Lc265
.Lc265:
	.long	.Lc193
	.quad	.Lc124
	.quad	.Lc123-.Lc124
	.byte	2
	.byte	.Lc125-.Lc124
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc126-.Lc125
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc266:
	.long	.Lc269-.Lc268
.Lc268:
	.long	.Lc193
	.quad	.Lc128
	.quad	.Lc127-.Lc128
	.byte	2
	.byte	.Lc129-.Lc128
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc130-.Lc129
	.byte	5
	.uleb128	12
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc131-.Lc130
	.byte	5
	.uleb128	13
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc132-.Lc131
	.byte	5
	.uleb128	14
	.uleb128	12
	.byte	14
	.uleb128	48
	.byte	2
	.byte	.Lc133-.Lc132
	.byte	5
	.uleb128	15
	.uleb128	14
	.byte	14
	.uleb128	56
	.byte	2
	.byte	.Lc134-.Lc133
	.byte	14
	.uleb128	64
	.byte	4
	.long	.Lc135-.Lc134
	.byte	6
	.uleb128	15
	.byte	2
	.byte	.Lc136-.Lc135
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc137-.Lc136
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc138-.Lc137
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc139-.Lc138
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc269:
	.long	.Lc272-.Lc271
.Lc271:
	.long	.Lc193
	.quad	.Lc141
	.quad	.Lc140-.Lc141
	.byte	2
	.byte	.Lc142-.Lc141
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc143-.Lc142
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc272:
	.long	.Lc275-.Lc274
.Lc274:
	.long	.Lc193
	.quad	.Lc145
	.quad	.Lc144-.Lc145
	.byte	2
	.byte	.Lc146-.Lc145
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc147-.Lc146
	.byte	5
	.uleb128	12
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc148-.Lc147
	.byte	5
	.uleb128	13
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc149-.Lc148
	.byte	5
	.uleb128	14
	.uleb128	12
	.byte	14
	.uleb128	48
	.byte	2
	.byte	.Lc150-.Lc149
	.byte	5
	.uleb128	15
	.uleb128	14
	.byte	14
	.uleb128	56
	.byte	2
	.byte	.Lc151-.Lc150
	.byte	14
	.uleb128	64
	.byte	4
	.long	.Lc152-.Lc151
	.byte	6
	.uleb128	15
	.byte	2
	.byte	.Lc153-.Lc152
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc154-.Lc153
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc155-.Lc154
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc156-.Lc155
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc275:
	.long	.Lc278-.Lc277
.Lc277:
	.long	.Lc193
	.quad	.Lc158
	.quad	.Lc157-.Lc158
	.byte	2
	.byte	.Lc159-.Lc158
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc160-.Lc159
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc278:
	.long	.Lc281-.Lc280
.Lc280:
	.long	.Lc193
	.quad	.Lc162
	.quad	.Lc161-.Lc162
	.byte	2
	.byte	.Lc163-.Lc162
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc164-.Lc163
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc281:
	.long	.Lc284-.Lc283
.Lc283:
	.long	.Lc193
	.quad	.Lc166
	.quad	.Lc165-.Lc166
	.byte	2
	.byte	.Lc167-.Lc166
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc168-.Lc167
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc284:
	.long	.Lc287-.Lc286
.Lc286:
	.long	.Lc193
	.quad	.Lc170
	.quad	.Lc169-.Lc170
	.byte	4
	.long	.Lc171-.Lc170
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc287:
	.long	.Lc290-.Lc289
.Lc289:
	.long	.Lc193
	.quad	.Lc173
	.quad	.Lc172-.Lc173
	.byte	2
	.byte	.Lc174-.Lc173
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc175-.Lc174
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc176-.Lc175
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc177-.Lc176
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc290:
	.long	.Lc293-.Lc292
.Lc292:
	.long	.Lc193
	.quad	.Lc179
	.quad	.Lc178-.Lc179
	.byte	4
	.long	.Lc180-.Lc179
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc293:
	.long	.Lc296-.Lc295
.Lc295:
	.long	.Lc193
	.quad	.Lc182
	.quad	.Lc181-.Lc182
	.byte	4
	.long	.Lc183-.Lc182
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc296:
	.long	.Lc299-.Lc298
.Lc298:
	.long	.Lc193
	.quad	.Lc185
	.quad	.Lc184-.Lc185
	.byte	2
	.byte	.Lc186-.Lc185
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc187-.Lc186
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc188-.Lc187
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc189-.Lc188
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc299:
	.long	.Lc302-.Lc301
.Lc301:
	.long	.Lc193
	.quad	.Lc191
	.quad	.Lc190-.Lc191
	.byte	4
	.long	.Lc192-.Lc191
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc302:
# End asmlist al_dwarf_frame
.section .note.GNU-stack,"",%progbits

