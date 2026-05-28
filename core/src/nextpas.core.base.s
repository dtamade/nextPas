	.file "nextpas.core.base.pas"
# Begin asmlist al_procedures

.section .text.n_nextpas.core.base$_$tbytespan_$__$$_create$pbyte$qword$$tbytespan,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.BASE$_$TBYTESPAN_$__$$_CREATE$PBYTE$QWORD$$TBYTESPAN
	.type	NEXTPAS.CORE.BASE$_$TBYTESPAN_$__$$_CREATE$PBYTE$QWORD$$TBYTESPAN,@function
NEXTPAS.CORE.BASE$_$TBYTESPAN_$__$$_CREATE$PBYTE$QWORD$$TBYTESPAN:
.Lc2:
# [nextpas.core.base.pas]
# [131] begin
	leaq	-24(%rsp),%rsp
.Lc3:
# Var $result located at rsp+0, size=OS_128
# Var AData located in register rdi
# Var ALen located in register rsi
# Var AData located in register rdi
# [132] Result.Data := AData;
	movq	%rdi,(%rsp)
# Var ALen located in register rsi
# [133] Result.Len := ALen;
	movq	%rsi,8(%rsp)
# [134] end;
	movq	(%rsp),%rax
	movq	8(%rsp),%rdx
	leaq	24(%rsp),%rsp
.Lc4:
	ret
.Lc1:

.section .text.n_nextpas.core.base$_$tbytespan_$__$$_frombytes$tbytes$$tbytespan,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.BASE$_$TBYTESPAN_$__$$_FROMBYTES$TBYTES$$TBYTESPAN
	.type	NEXTPAS.CORE.BASE$_$TBYTESPAN_$__$$_FROMBYTES$TBYTES$$TBYTESPAN,@function
NEXTPAS.CORE.BASE$_$TBYTESPAN_$__$$_FROMBYTES$TBYTES$$TBYTESPAN:
.Lc6:
# [137] begin
	leaq	-24(%rsp),%rsp
.Lc7:
# Var $result located at rsp+0, size=OS_128
# Var ABytes located in register rdi
# [138] if Length(ABytes) > 0 then
	testq	%rdi,%rdi
	je	.Lj10
# [140] Result.Data := @ABytes[0];
	movq	%rdi,(%rsp)
# [141] Result.Len := SizeUInt(Length(ABytes));
	testq	%rdi,%rdi
	je	.Lj11
	movq	-8(%rdi),%rdi
	addq	$1,%rdi
.Lj11:
	movq	%rdi,8(%rsp)
	jmp	.Lj12
	.p2align 4,,10
	.p2align 3
.Lj10:
# [145] Result.Data := nil;
	movq	$0,(%rsp)
# [146] Result.Len := 0;
	movq	$0,8(%rsp)
.Lj12:
# [148] end;
	movq	(%rsp),%rax
	movq	8(%rsp),%rdx
	leaq	24(%rsp),%rsp
.Lc8:
	ret
.Lc5:

.section .text.n_nextpas.core.base$_$tbytespan_$__$$_empty$$tbytespan,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.BASE$_$TBYTESPAN_$__$$_EMPTY$$TBYTESPAN
	.type	NEXTPAS.CORE.BASE$_$TBYTESPAN_$__$$_EMPTY$$TBYTESPAN,@function
NEXTPAS.CORE.BASE$_$TBYTESPAN_$__$$_EMPTY$$TBYTESPAN:
.Lc10:
# [151] begin
	leaq	-24(%rsp),%rsp
.Lc11:
# Var $result located at rsp+0, size=OS_128
# [152] Result.Data := nil;
	movq	$0,(%rsp)
# [153] Result.Len := 0;
	movq	$0,8(%rsp)
# [154] end;
	movq	(%rsp),%rax
	movq	8(%rsp),%rdx
	leaq	24(%rsp),%rsp
.Lc12:
	ret
.Lc9:

.section .text.n_nextpas.core.base$_$tbytespan_$__$$_isempty$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.BASE$_$TBYTESPAN_$__$$_ISEMPTY$$BOOLEAN
	.type	NEXTPAS.CORE.BASE$_$TBYTESPAN_$__$$_ISEMPTY$$BOOLEAN,@function
NEXTPAS.CORE.BASE$_$TBYTESPAN_$__$$_ISEMPTY$$BOOLEAN:
.Lc14:
# Var $self located in register rdi
# [157] begin
# [158] Result := Len = 0;
	cmpq	$0,8(%rdi)
# Var $result located in register al
	seteb	%al
.Lc15:
# [159] end;
	ret
.Lc13:

.section .text.n_nextpas.core.base$_$tbytespan_$__$$_slice$qword$qword$$tbytespan,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.BASE$_$TBYTESPAN_$__$$_SLICE$QWORD$QWORD$$TBYTESPAN
	.type	NEXTPAS.CORE.BASE$_$TBYTESPAN_$__$$_SLICE$QWORD$QWORD$$TBYTESPAN,@function
NEXTPAS.CORE.BASE$_$TBYTESPAN_$__$$_SLICE$QWORD$QWORD$$TBYTESPAN:
.Lc17:
# Temps allocated between rbp-104 and rbp-16
# [162] begin
	pushq	%rbp
.Lc18:
	movq	%rsp,%rbp
.Lc19:
	leaq	-112(%rsp),%rsp
	movq	%rbx,-104(%rbp)
	movq	%r12,-96(%rbp)
	movq	%r13,-88(%rbp)
# Var $result located at rbp-16, size=OS_128
	movq	%rdi,%rbx
# Var $self located in register rbx
	movq	%rsi,%r12
# Var AOffset located in register r12
	movq	%rdx,%r13
# Var ALength located in register r13
# [163] if AOffset + ALength > Len then
	leaq	(%rsi,%rdx),%rax
	cmpq	8(%rbx),%rax
	jna	.Lj20
.Lj21:
# [165] [AOffset, ALength, Len]);
	movq	%r12,-72(%rbp)
	leaq	-72(%rbp),%rax
	movq	%rax,-56(%rbp)
	movq	$17,-64(%rbp)
	movq	%r13,-80(%rbp)
	leaq	-80(%rbp),%rax
	movq	%rax,-40(%rbp)
	movq	$17,-48(%rbp)
	leaq	8(%rbx),%rax
	movq	%rax,-24(%rbp)
	movq	$17,-32(%rbp)
# [164] raise ERangeError.CreateFmt('TByteSpan.Slice: offset %d + length %d > span length %d',
	leaq	-64(%rbp),%rcx
	movq	$.Ld1,%rdx
	movq	$VMT_$SYSUTILS_$$_ERANGEERROR,%rdi
	movl	$2,%r8d
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATEFMT$ANSISTRING$array_of_const$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj21,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj20:
# [166] Result.Data := Data + AOffset;
	movq	(%rbx),%rax
	addq	%r12,%rax
	movq	%rax,-16(%rbp)
# Var ALength located in register r13
# [167] Result.Len := ALength;
	movq	%r13,-8(%rbp)
# [168] end;
	movq	-16(%rbp),%rax
	movq	-8(%rbp),%rdx
	movq	-104(%rbp),%rbx
	movq	-96(%rbp),%r12
	movq	-88(%rbp),%r13
.Lc20:
	movq	%rbp,%rsp
.Lc21:
	popq	%rbp
	ret
.Lc16:

.section .text.n_nextpas.core.base$_$tbytespan_$__$$_getbyte$qword$$byte,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.BASE$_$TBYTESPAN_$__$$_GETBYTE$QWORD$$BYTE
	.type	NEXTPAS.CORE.BASE$_$TBYTESPAN_$__$$_GETBYTE$QWORD$$BYTE,@function
NEXTPAS.CORE.BASE$_$TBYTESPAN_$__$$_GETBYTE$QWORD$$BYTE:
.Lc23:
# Temps allocated between rbp-64 and rbp+0
# [171] begin
	pushq	%rbp
.Lc24:
	movq	%rsp,%rbp
.Lc25:
	leaq	-64(%rsp),%rsp
	movq	%rbx,-64(%rbp)
	movq	%r12,-56(%rbp)
	movq	%rdi,%rbx
# Var $self located in register rbx
	movq	%rsi,%r12
# Var AIndex located in register r12
# [172] if AIndex >= Len then
	cmpq	8(%rdi),%rsi
	jnae	.Lj25
.Lj26:
# [173] raise ERangeError.CreateFmt('TByteSpan: index %d out of range [0..%d]', [AIndex, Len - 1]);
	movq	%r12,-40(%rbp)
	leaq	-40(%rbp),%rax
	movq	%rax,-24(%rbp)
	movq	$17,-32(%rbp)
	movq	8(%rbx),%rax
	subq	$1,%rax
	movq	%rax,-48(%rbp)
	leaq	-48(%rbp),%rax
	movq	%rax,-8(%rbp)
	movq	$17,-16(%rbp)
	leaq	-32(%rbp),%rcx
	movq	$.Ld2,%rdx
	movq	$VMT_$SYSUTILS_$$_ERANGEERROR,%rdi
	movl	$1,%r8d
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATEFMT$ANSISTRING$array_of_const$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj26,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj25:
# [174] Result := (Data + AIndex)^;
	movq	(%rbx),%rax
# Var $result located in register al
	movb	(%rax,%r12),%al
# [175] end;
	movq	-64(%rbp),%rbx
	movq	-56(%rbp),%r12
.Lc26:
	movq	%rbp,%rsp
.Lc27:
	popq	%rbp
	ret
.Lc22:

.section .text.n_nextpas.core.base_$$_require$boolean$ansistring,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.BASE_$$_REQUIRE$BOOLEAN$ANSISTRING
	.type	NEXTPAS.CORE.BASE_$$_REQUIRE$BOOLEAN$ANSISTRING,@function
NEXTPAS.CORE.BASE_$$_REQUIRE$BOOLEAN$ANSISTRING:
.Lc29:
# [180] begin
	pushq	%rbp
.Lc30:
	movq	%rsp,%rbp
.Lc31:
# Var ACondition located in register dil
	movq	%rsi,%rdx
# Var AMessage located in register rdx
# [181] if not ACondition then
	testb	%dil,%dil
	jne	.Lj30
.Lj31:
# [182] raise EArgumentException.Create(AMessage);
	movq	$VMT_$SYSUTILS_$$_EARGUMENTEXCEPTION,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj31,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj30:
.Lc32:
# [183] end;
	movq	%rbp,%rsp
.Lc33:
	popq	%rbp
	ret
.Lc28:

.section .text.n_nextpas.core.base_$$_ensure$boolean$ansistring,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.BASE_$$_ENSURE$BOOLEAN$ANSISTRING
	.type	NEXTPAS.CORE.BASE_$$_ENSURE$BOOLEAN$ANSISTRING,@function
NEXTPAS.CORE.BASE_$$_ENSURE$BOOLEAN$ANSISTRING:
.Lc35:
# [186] begin
	pushq	%rbp
.Lc36:
	movq	%rsp,%rbp
.Lc37:
# Var ACondition located in register dil
	movq	%rsi,%rdx
# Var AMessage located in register rdx
# [187] if not ACondition then
	testb	%dil,%dil
	jne	.Lj35
.Lj36:
# [188] raise EAssertionFailed.Create(AMessage);
	movq	$VMT_$SYSUTILS_$$_EASSERTIONFAILED,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj36,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj35:
.Lc38:
# [189] end;
	movq	%rbp,%rsp
.Lc39:
	popq	%rbp
	ret
.Lc34:

.section .text.n_nextpas.core.base_$$_checkstate$boolean$ansistring,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.BASE_$$_CHECKSTATE$BOOLEAN$ANSISTRING
	.type	NEXTPAS.CORE.BASE_$$_CHECKSTATE$BOOLEAN$ANSISTRING,@function
NEXTPAS.CORE.BASE_$$_CHECKSTATE$BOOLEAN$ANSISTRING:
.Lc41:
# [192] begin
	pushq	%rbp
.Lc42:
	movq	%rsp,%rbp
.Lc43:
# Var ACondition located in register dil
	movq	%rsi,%rdx
# Var AMessage located in register rdx
# [193] if not ACondition then
	testb	%dil,%dil
	jne	.Lj40
.Lj41:
# [194] raise EInvalidOpException.Create(AMessage);
	movq	$VMT_$SYSUTILS_$$_EINVALIDOPEXCEPTION,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj41,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj40:
.Lc44:
# [195] end;
	movq	%rbp,%rsp
.Lc45:
	popq	%rbp
	ret
.Lc40:

.section .text.n_nextpas.core.base_$$_unreachable$ansistring,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.BASE_$$_UNREACHABLE$ANSISTRING
	.type	NEXTPAS.CORE.BASE_$$_UNREACHABLE$ANSISTRING,@function
NEXTPAS.CORE.BASE_$$_UNREACHABLE$ANSISTRING:
.Lc47:
# [198] begin
	pushq	%rbp
.Lc48:
	movq	%rsp,%rbp
.Lc49:
	movq	%rdi,%rdx
# Var AMessage located in register rdx
.Lj44:
# [199] raise EAssertionFailed.Create(AMessage);
	movq	$VMT_$SYSUTILS_$$_EASSERTIONFAILED,%rdi
# Var AMessage located in register rdx
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj44,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lc50:
# [200] end;
	movq	%rbp,%rsp
.Lc51:
	popq	%rbp
	ret
.Lc46:

.section .text.n_nextpas.core.base_$$_hashbytes$pbyte$qword$$longword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.BASE_$$_HASHBYTES$PBYTE$QWORD$$LONGWORD
	.type	NEXTPAS.CORE.BASE_$$_HASHBYTES$PBYTE$QWORD$$LONGWORD,@function
NEXTPAS.CORE.BASE_$$_HASHBYTES$PBYTE$QWORD$$LONGWORD:
.Lc53:
# Var AData located in register rdi
# Var ALen located in register rsi
# [211] begin
# Var $result located in register eax
# [212] Result := FNV_OFFSET_BASIS_32;
	movl	$2166136261,%eax
# [213] for LI := 0 to ALen - 1 do
	leaq	-1(%rsi),%rdx
# Var LI located in register rsi
	movq	$-1,%rsi
	.p2align 4,,10
	.p2align 3
.Lj47:
	addq	$1,%rsi
# [215] Result := Result xor THashCode((AData + LI)^);
	leaq	(%rdi,%rsi),%rcx
	movzbl	(%rcx),%ecx
	xorl	%ecx,%eax
# [216] Result := Result * FNV_PRIME_32;
	imull	$16777619,%eax,%eax
	cmpq	%rsi,%rdx
	jnbe	.Lj47
.Lc54:
# [218] end;
	ret
.Lc52:
.Le0:
	.size	NEXTPAS.CORE.BASE_$$_HASHBYTES$PBYTE$QWORD$$LONGWORD, .Le0 - NEXTPAS.CORE.BASE_$$_HASHBYTES$PBYTE$QWORD$$LONGWORD

.section .text.n_nextpas.core.base_$$_hashstring$ansistring$$longword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.BASE_$$_HASHSTRING$ANSISTRING$$LONGWORD
	.type	NEXTPAS.CORE.BASE_$$_HASHSTRING$ANSISTRING$$LONGWORD,@function
NEXTPAS.CORE.BASE_$$_HASHSTRING$ANSISTRING$$LONGWORD:
.Lc56:
# [221] begin
	pushq	%rax
.Lc57:
# Var $result located in register eax
	movq	%rdi,%rsi
# Var AValue located in register rsi
# [222] if Length(AValue) > 0 then
	testq	%rdi,%rdi
	je	.Lj53
# [223] Result := HashBytes(@AValue[1], SizeUInt(Length(AValue)))
	movq	%rsi,%rdi
	testq	%rsi,%rsi
	je	.Lj54
	movq	-8(%rsi),%rsi
.Lj54:
	call	NEXTPAS.CORE.BASE_$$_HASHBYTES$PBYTE$QWORD$$LONGWORD
	jmp	.Lj55
	.p2align 4,,10
	.p2align 3
.Lj53:
# [225] Result := FNV_OFFSET_BASIS_32;
	movl	$2166136261,%eax
.Lj55:
# [226] end;
	popq	%rcx
.Lc58:
	ret
.Lc55:

.section .text.n_nextpas.core.base_$$_hashinteger$int64$$longword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.BASE_$$_HASHINTEGER$INT64$$LONGWORD
	.type	NEXTPAS.CORE.BASE_$$_HASHINTEGER$INT64$$LONGWORD,@function
NEXTPAS.CORE.BASE_$$_HASHINTEGER$INT64$$LONGWORD:
.Lc60:
# [229] begin
	pushq	%rax
.Lc61:
# Var AValue located at rsp+0, size=OS_S64
	movq	%rdi,(%rsp)
# [230] Result := HashBytes(@AValue, SizeOf(AValue));
	movq	%rsp,%rdi
	movl	$8,%esi
	call	NEXTPAS.CORE.BASE_$$_HASHBYTES$PBYTE$QWORD$$LONGWORD
# Var $result located in register eax
# [231] end;
	popq	%rcx
.Lc62:
	ret
.Lc59:

.section .text.n_nextpas.core.base_$$_hashpointer$pointer$$longword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.BASE_$$_HASHPOINTER$POINTER$$LONGWORD
	.type	NEXTPAS.CORE.BASE_$$_HASHPOINTER$POINTER$$LONGWORD,@function
NEXTPAS.CORE.BASE_$$_HASHPOINTER$POINTER$$LONGWORD:
.Lc64:
# [234] begin
	pushq	%rax
.Lc65:
# Var AValue located at rsp+0, size=OS_64
	movq	%rdi,(%rsp)
# [235] Result := HashBytes(@AValue, SizeOf(AValue));
	movq	%rsp,%rdi
	movl	$8,%esi
	call	NEXTPAS.CORE.BASE_$$_HASHBYTES$PBYTE$QWORD$$LONGWORD
# Var $result located in register eax
# [236] end;
	popq	%rcx
.Lc66:
	ret
.Lc63:
# End asmlist al_procedures
# Begin asmlist al_globals

.section .rodata.n_VMT_$NEXTPAS.CORE.BASE_$$_ECORE
	.balign 8
.globl	VMT_$NEXTPAS.CORE.BASE_$$_ECORE
	.type	VMT_$NEXTPAS.CORE.BASE_$$_ECORE,@object
VMT_$NEXTPAS.CORE.BASE_$$_ECORE:
	.quad	32,-32
	.quad	VMT_$SYSUTILS_$$_EXCEPTION$indirect
	.quad	.Ld3
	.quad	0,0,0
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_ECORE
	.quad	0,0,0,0
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
	.quad	SYSUTILS$_$EXCEPTION_$__$$_TOSTRING$$ANSISTRING
	.quad	SYSUTILS$_$EXCEPTION_$__$$_GETBASEEXCEPTION$$EXCEPTION
	.quad	0
# [238] end.
.Le1:
	.size	VMT_$NEXTPAS.CORE.BASE_$$_ECORE, .Le1 - VMT_$NEXTPAS.CORE.BASE_$$_ECORE

.section .rodata.n_VMT_$NEXTPAS.CORE.BASE_$$_EWOW
	.balign 8
.globl	VMT_$NEXTPAS.CORE.BASE_$$_EWOW
	.type	VMT_$NEXTPAS.CORE.BASE_$$_EWOW,@object
VMT_$NEXTPAS.CORE.BASE_$$_EWOW:
	.quad	32,-32
	.quad	VMT_$NEXTPAS.CORE.BASE_$$_ECORE$indirect
	.quad	.Ld4
	.quad	0,0,0
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_EWOW
	.quad	0,0,0,0
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
	.quad	SYSUTILS$_$EXCEPTION_$__$$_TOSTRING$$ANSISTRING
	.quad	SYSUTILS$_$EXCEPTION_$__$$_GETBASEEXCEPTION$$EXCEPTION
	.quad	0
.Le2:
	.size	VMT_$NEXTPAS.CORE.BASE_$$_EWOW, .Le2 - VMT_$NEXTPAS.CORE.BASE_$$_EWOW

.section .rodata.n_VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL
	.balign 8
.globl	VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL
	.type	VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL,@object
VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL:
	.quad	32,-32
	.quad	VMT_$NEXTPAS.CORE.BASE_$$_ECORE$indirect
	.quad	.Ld5
	.quad	0,0,0
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL
	.quad	0,0,0,0
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
	.quad	SYSUTILS$_$EXCEPTION_$__$$_TOSTRING$$ANSISTRING
	.quad	SYSUTILS$_$EXCEPTION_$__$$_GETBASEEXCEPTION$$EXCEPTION
	.quad	0
.Le3:
	.size	VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL, .Le3 - VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL

.section .rodata.n_VMT_$NEXTPAS.CORE.BASE_$$_EEMPTYCOLLECTION
	.balign 8
.globl	VMT_$NEXTPAS.CORE.BASE_$$_EEMPTYCOLLECTION
	.type	VMT_$NEXTPAS.CORE.BASE_$$_EEMPTYCOLLECTION,@object
VMT_$NEXTPAS.CORE.BASE_$$_EEMPTYCOLLECTION:
	.quad	32,-32
	.quad	VMT_$NEXTPAS.CORE.BASE_$$_ECORE$indirect
	.quad	.Ld6
	.quad	0,0,0
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_EEMPTYCOLLECTION
	.quad	0,0,0,0
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
	.quad	SYSUTILS$_$EXCEPTION_$__$$_TOSTRING$$ANSISTRING
	.quad	SYSUTILS$_$EXCEPTION_$__$$_GETBASEEXCEPTION$$EXCEPTION
	.quad	0
.Le4:
	.size	VMT_$NEXTPAS.CORE.BASE_$$_EEMPTYCOLLECTION, .Le4 - VMT_$NEXTPAS.CORE.BASE_$$_EEMPTYCOLLECTION

.section .rodata.n_VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT
	.balign 8
.globl	VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT
	.type	VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT,@object
VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT:
	.quad	32,-32
	.quad	VMT_$NEXTPAS.CORE.BASE_$$_ECORE$indirect
	.quad	.Ld7
	.quad	0,0,0
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT
	.quad	0,0,0,0
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
	.quad	SYSUTILS$_$EXCEPTION_$__$$_TOSTRING$$ANSISTRING
	.quad	SYSUTILS$_$EXCEPTION_$__$$_GETBASEEXCEPTION$$EXCEPTION
	.quad	0
.Le5:
	.size	VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT, .Le5 - VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT

.section .rodata.n_VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDRESULT
	.balign 8
.globl	VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDRESULT
	.type	VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDRESULT,@object
VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDRESULT:
	.quad	32,-32
	.quad	VMT_$NEXTPAS.CORE.BASE_$$_ECORE$indirect
	.quad	.Ld8
	.quad	0,0,0
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDRESULT
	.quad	0,0,0,0
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
	.quad	SYSUTILS$_$EXCEPTION_$__$$_TOSTRING$$ANSISTRING
	.quad	SYSUTILS$_$EXCEPTION_$__$$_GETBASEEXCEPTION$$EXCEPTION
	.quad	0
.Le6:
	.size	VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDRESULT, .Le6 - VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDRESULT

.section .rodata.n_VMT_$NEXTPAS.CORE.BASE_$$_ETIMEOUTERROR
	.balign 8
.globl	VMT_$NEXTPAS.CORE.BASE_$$_ETIMEOUTERROR
	.type	VMT_$NEXTPAS.CORE.BASE_$$_ETIMEOUTERROR,@object
VMT_$NEXTPAS.CORE.BASE_$$_ETIMEOUTERROR:
	.quad	32,-32
	.quad	VMT_$NEXTPAS.CORE.BASE_$$_ECORE$indirect
	.quad	.Ld9
	.quad	0,0,0
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_ETIMEOUTERROR
	.quad	0,0,0,0
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
	.quad	SYSUTILS$_$EXCEPTION_$__$$_TOSTRING$$ANSISTRING
	.quad	SYSUTILS$_$EXCEPTION_$__$$_GETBASEEXCEPTION$$EXCEPTION
	.quad	0
.Le7:
	.size	VMT_$NEXTPAS.CORE.BASE_$$_ETIMEOUTERROR, .Le7 - VMT_$NEXTPAS.CORE.BASE_$$_ETIMEOUTERROR

.section .rodata.n_VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDSTATE
	.balign 8
.globl	VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDSTATE
	.type	VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDSTATE,@object
VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDSTATE:
	.quad	32,-32
	.quad	VMT_$NEXTPAS.CORE.BASE_$$_ECORE$indirect
	.quad	.Ld10
	.quad	0,0,0
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDSTATE
	.quad	0,0,0,0
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
	.quad	SYSUTILS$_$EXCEPTION_$__$$_TOSTRING$$ANSISTRING
	.quad	SYSUTILS$_$EXCEPTION_$__$$_GETBASEEXCEPTION$$EXCEPTION
	.quad	0
.Le8:
	.size	VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDSTATE, .Le8 - VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDSTATE

.section .rodata.n_VMT_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE
	.balign 8
.globl	VMT_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE
	.type	VMT_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE,@object
VMT_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE:
	.quad	32,-32
	.quad	VMT_$NEXTPAS.CORE.BASE_$$_ECORE$indirect
	.quad	.Ld11
	.quad	0,0,0
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE
	.quad	0,0,0,0
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
	.quad	SYSUTILS$_$EXCEPTION_$__$$_TOSTRING$$ANSISTRING
	.quad	SYSUTILS$_$EXCEPTION_$__$$_GETBASEEXCEPTION$$EXCEPTION
	.quad	0
.Le9:
	.size	VMT_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE, .Le9 - VMT_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE

.section .rodata.n_VMT_$NEXTPAS.CORE.BASE_$$_ENOTSUPPORTED
	.balign 8
.globl	VMT_$NEXTPAS.CORE.BASE_$$_ENOTSUPPORTED
	.type	VMT_$NEXTPAS.CORE.BASE_$$_ENOTSUPPORTED,@object
VMT_$NEXTPAS.CORE.BASE_$$_ENOTSUPPORTED:
	.quad	32,-32
	.quad	VMT_$NEXTPAS.CORE.BASE_$$_ECORE$indirect
	.quad	.Ld12
	.quad	0,0,0
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_ENOTSUPPORTED
	.quad	0,0,0,0
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
	.quad	SYSUTILS$_$EXCEPTION_$__$$_TOSTRING$$ANSISTRING
	.quad	SYSUTILS$_$EXCEPTION_$__$$_GETBASEEXCEPTION$$EXCEPTION
	.quad	0
.Le10:
	.size	VMT_$NEXTPAS.CORE.BASE_$$_ENOTSUPPORTED, .Le10 - VMT_$NEXTPAS.CORE.BASE_$$_ENOTSUPPORTED

.section .rodata.n_VMT_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE
	.balign 8
.globl	VMT_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE
	.type	VMT_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE,@object
VMT_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE:
	.quad	32,-32
	.quad	VMT_$NEXTPAS.CORE.BASE_$$_ECORE$indirect
	.quad	.Ld13
	.quad	0,0,0
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE
	.quad	0,0,0,0
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
	.quad	SYSUTILS$_$EXCEPTION_$__$$_TOSTRING$$ANSISTRING
	.quad	SYSUTILS$_$EXCEPTION_$__$$_GETBASEEXCEPTION$$EXCEPTION
	.quad	0
.Le11:
	.size	VMT_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE, .Le11 - VMT_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE

.section .rodata.n_VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDOPERATION
	.balign 8
.globl	VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDOPERATION
	.type	VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDOPERATION,@object
VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDOPERATION:
	.quad	32,-32
	.quad	VMT_$NEXTPAS.CORE.BASE_$$_ECORE$indirect
	.quad	.Ld14
	.quad	0,0,0
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDOPERATION
	.quad	0,0,0,0
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
	.quad	SYSUTILS$_$EXCEPTION_$__$$_TOSTRING$$ANSISTRING
	.quad	SYSUTILS$_$EXCEPTION_$__$$_GETBASEEXCEPTION$$EXCEPTION
	.quad	0
.Le12:
	.size	VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDOPERATION, .Le12 - VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDOPERATION

.section .rodata.n_VMT_$NEXTPAS.CORE.BASE_$$_EOUTOFMEMORY
	.balign 8
.globl	VMT_$NEXTPAS.CORE.BASE_$$_EOUTOFMEMORY
	.type	VMT_$NEXTPAS.CORE.BASE_$$_EOUTOFMEMORY,@object
VMT_$NEXTPAS.CORE.BASE_$$_EOUTOFMEMORY:
	.quad	32,-32
	.quad	VMT_$NEXTPAS.CORE.BASE_$$_ECORE$indirect
	.quad	.Ld15
	.quad	0,0,0
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_EOUTOFMEMORY
	.quad	0,0,0,0
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
	.quad	SYSUTILS$_$EXCEPTION_$__$$_TOSTRING$$ANSISTRING
	.quad	SYSUTILS$_$EXCEPTION_$__$$_GETBASEEXCEPTION$$EXCEPTION
	.quad	0
.Le13:
	.size	VMT_$NEXTPAS.CORE.BASE_$$_EOUTOFMEMORY, .Le13 - VMT_$NEXTPAS.CORE.BASE_$$_EOUTOFMEMORY

.section .rodata.n_VMT_$NEXTPAS.CORE.BASE_$$_EOVERFLOW
	.balign 8
.globl	VMT_$NEXTPAS.CORE.BASE_$$_EOVERFLOW
	.type	VMT_$NEXTPAS.CORE.BASE_$$_EOVERFLOW,@object
VMT_$NEXTPAS.CORE.BASE_$$_EOVERFLOW:
	.quad	32,-32
	.quad	VMT_$NEXTPAS.CORE.BASE_$$_ECORE$indirect
	.quad	.Ld16
	.quad	0,0,0
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_EOVERFLOW
	.quad	0,0,0,0
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
	.quad	SYSUTILS$_$EXCEPTION_$__$$_TOSTRING$$ANSISTRING
	.quad	SYSUTILS$_$EXCEPTION_$__$$_GETBASEEXCEPTION$$EXCEPTION
	.quad	0
.Le14:
	.size	VMT_$NEXTPAS.CORE.BASE_$$_EOVERFLOW, .Le14 - VMT_$NEXTPAS.CORE.BASE_$$_EOVERFLOW

.section .rodata.n_IID_$NEXTPAS.CORE.BASE_$$_TPROC
	.balign 8
.globl	IID_$NEXTPAS.CORE.BASE_$$_TPROC
	.type	IID_$NEXTPAS.CORE.BASE_$$_TPROC,@object
IID_$NEXTPAS.CORE.BASE_$$_TPROC:
	.long	0
	.short	0,0
	.byte	0,0,0,0,0,0,0,0
.Le15:
	.size	IID_$NEXTPAS.CORE.BASE_$$_TPROC, .Le15 - IID_$NEXTPAS.CORE.BASE_$$_TPROC

.section .rodata.n_IIDSTR_$NEXTPAS.CORE.BASE_$$_TPROC
	.balign 8
.globl	IIDSTR_$NEXTPAS.CORE.BASE_$$_TPROC
	.type	IIDSTR_$NEXTPAS.CORE.BASE_$$_TPROC,@object
IIDSTR_$NEXTPAS.CORE.BASE_$$_TPROC:
	.byte	0
.Le16:
	.size	IIDSTR_$NEXTPAS.CORE.BASE_$$_TPROC, .Le16 - IIDSTR_$NEXTPAS.CORE.BASE_$$_TPROC

.section .rodata.n_IID_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORREFFUNC
	.balign 8
.globl	IID_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORREFFUNC
	.type	IID_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORREFFUNC,@object
IID_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORREFFUNC:
	.long	0
	.short	0,0
	.byte	0,0,0,0,0,0,0,0
.Le17:
	.size	IID_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORREFFUNC, .Le17 - IID_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORREFFUNC

.section .rodata.n_IIDSTR_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORREFFUNC
	.balign 8
.globl	IIDSTR_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORREFFUNC
	.type	IIDSTR_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORREFFUNC,@object
IIDSTR_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORREFFUNC:
	.byte	0
.Le18:
	.size	IIDSTR_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORREFFUNC, .Le18 - IIDSTR_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORREFFUNC
# End asmlist al_globals
# Begin asmlist al_const

.section .rodata.n_VMT_$NEXTPAS.CORE.BASE_$$_ECORE
	.balign 8
.Ld3:
	.byte	5
	.ascii	"ECore"
.Le19:
	.size	.Ld3, .Le19 - .Ld3

.section .rodata.n_VMT_$NEXTPAS.CORE.BASE_$$_EWOW
	.balign 8
.Ld4:
	.byte	4
	.ascii	"EWow"
.Le20:
	.size	.Ld4, .Le20 - .Ld4

.section .rodata.n_VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL
	.balign 8
.Ld5:
	.byte	12
	.ascii	"EArgumentNil"
.Le21:
	.size	.Ld5, .Le21 - .Ld5

.section .rodata.n_VMT_$NEXTPAS.CORE.BASE_$$_EEMPTYCOLLECTION
	.balign 8
.Ld6:
	.byte	16
	.ascii	"EEmptyCollection"
.Le22:
	.size	.Ld6, .Le22 - .Ld6

.section .rodata.n_VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT
	.balign 8
.Ld7:
	.byte	16
	.ascii	"EInvalidArgument"
.Le23:
	.size	.Ld7, .Le23 - .Ld7

.section .rodata.n_VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDRESULT
	.balign 8
.Ld8:
	.byte	14
	.ascii	"EInvalidResult"
.Le24:
	.size	.Ld8, .Le24 - .Ld8

.section .rodata.n_VMT_$NEXTPAS.CORE.BASE_$$_ETIMEOUTERROR
	.balign 8
.Ld9:
	.byte	13
	.ascii	"ETimeoutError"
.Le25:
	.size	.Ld9, .Le25 - .Ld9

.section .rodata.n_VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDSTATE
	.balign 8
.Ld10:
	.byte	13
	.ascii	"EInvalidState"
.Le26:
	.size	.Ld10, .Le26 - .Ld10

.section .rodata.n_VMT_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE
	.balign 8
.Ld11:
	.byte	11
	.ascii	"EOutOfRange"
.Le27:
	.size	.Ld11, .Le27 - .Ld11

.section .rodata.n_VMT_$NEXTPAS.CORE.BASE_$$_ENOTSUPPORTED
	.balign 8
.Ld12:
	.byte	13
	.ascii	"ENotSupported"
.Le28:
	.size	.Ld12, .Le28 - .Ld12

.section .rodata.n_VMT_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE
	.balign 8
.Ld13:
	.byte	14
	.ascii	"ENotCompatible"
.Le29:
	.size	.Ld13, .Le29 - .Ld13

.section .rodata.n_VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDOPERATION
	.balign 8
.Ld14:
	.byte	17
	.ascii	"EInvalidOperation"
.Le30:
	.size	.Ld14, .Le30 - .Ld14

.section .rodata.n_VMT_$NEXTPAS.CORE.BASE_$$_EOUTOFMEMORY
	.balign 8
.Ld15:
	.byte	12
	.ascii	"EOutOfMemory"
.Le31:
	.size	.Ld15, .Le31 - .Ld15

.section .rodata.n_VMT_$NEXTPAS.CORE.BASE_$$_EOVERFLOW
	.balign 8
.Ld16:
	.byte	9
	.ascii	"EOverflow"
.Le32:
	.size	.Ld16, .Le32 - .Ld16
# End asmlist al_const
# Begin asmlist al_typedconsts

.section .rodata.n_.Ld1
	.balign 8
.Ld1$strlab:
	.short	0,1
	.long	-1
	.quad	55
.Ld1:
# [164] raise ERangeError.CreateFmt('TByteSpan.Slice: offset %d + length %d > span length %d',
	.ascii	"TByteSpan.Slice: offset %d + length %d > span lengt"
	.ascii	"h %d\000"
.Le33:
	.size	.Ld1$strlab, .Le33 - .Ld1$strlab

.section .rodata.n_.Ld2
	.balign 8
.Ld2$strlab:
	.short	0,1
	.long	-1
	.quad	40
.Ld2:
# [173] raise ERangeError.CreateFmt('TByteSpan: index %d out of range [0..%d]', [AIndex, Len - 1]);
	.ascii	"TByteSpan: index %d out of range [0..%d]\000"
.Le34:
	.size	.Ld2$strlab, .Le34 - .Ld2$strlab
# End asmlist al_typedconsts
# Begin asmlist al_rtti

.section .rodata.n_INIT_$NEXTPAS.CORE.BASE_$$_ECORE
	.balign 8
.globl	INIT_$NEXTPAS.CORE.BASE_$$_ECORE
	.type	INIT_$NEXTPAS.CORE.BASE_$$_ECORE,@object
INIT_$NEXTPAS.CORE.BASE_$$_ECORE:
	.byte	15,5
# [239] 
	.ascii	"ECore"
	.quad	0,0
	.long	8
	.quad	0,0
	.long	0
.Le35:
	.size	INIT_$NEXTPAS.CORE.BASE_$$_ECORE, .Le35 - INIT_$NEXTPAS.CORE.BASE_$$_ECORE

.section .rodata.n_RTTI_$NEXTPAS.CORE.BASE_$$_ECORE
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BASE_$$_ECORE
	.type	RTTI_$NEXTPAS.CORE.BASE_$$_ECORE,@object
RTTI_$NEXTPAS.CORE.BASE_$$_ECORE:
	.byte	15,5
	.ascii	"ECore"
	.quad	0
	.quad	VMT_$NEXTPAS.CORE.BASE_$$_ECORE
	.quad	RTTI_$SYSUTILS_$$_EXCEPTION$indirect
	.short	0
	.byte	17
	.ascii	"nextpas.core.base"
	.short	0,0
.Le36:
	.size	RTTI_$NEXTPAS.CORE.BASE_$$_ECORE, .Le36 - RTTI_$NEXTPAS.CORE.BASE_$$_ECORE

.section .rodata.n_INIT_$NEXTPAS.CORE.BASE_$$_EWOW
	.balign 8
.globl	INIT_$NEXTPAS.CORE.BASE_$$_EWOW
	.type	INIT_$NEXTPAS.CORE.BASE_$$_EWOW,@object
INIT_$NEXTPAS.CORE.BASE_$$_EWOW:
	.byte	15,4
	.ascii	"EWow"
	.quad	0,0
	.long	8
	.quad	0,0
	.long	0
.Le37:
	.size	INIT_$NEXTPAS.CORE.BASE_$$_EWOW, .Le37 - INIT_$NEXTPAS.CORE.BASE_$$_EWOW

.section .rodata.n_RTTI_$NEXTPAS.CORE.BASE_$$_EWOW
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BASE_$$_EWOW
	.type	RTTI_$NEXTPAS.CORE.BASE_$$_EWOW,@object
RTTI_$NEXTPAS.CORE.BASE_$$_EWOW:
	.byte	15,4
	.ascii	"EWow"
	.quad	0
	.quad	VMT_$NEXTPAS.CORE.BASE_$$_EWOW
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_ECORE$indirect
	.short	0
	.byte	17
	.ascii	"nextpas.core.base"
	.short	0,0
.Le38:
	.size	RTTI_$NEXTPAS.CORE.BASE_$$_EWOW, .Le38 - RTTI_$NEXTPAS.CORE.BASE_$$_EWOW

.section .rodata.n_INIT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL
	.balign 8
.globl	INIT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL
	.type	INIT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL,@object
INIT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL:
	.byte	15,12
	.ascii	"EArgumentNil"
	.quad	0,0
	.long	8
	.quad	0,0
	.long	0
.Le39:
	.size	INIT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL, .Le39 - INIT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL

.section .rodata.n_RTTI_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL
	.type	RTTI_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL,@object
RTTI_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL:
	.byte	15,12
	.ascii	"EArgumentNil"
	.quad	0
	.quad	VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_ECORE$indirect
	.short	0
	.byte	17
	.ascii	"nextpas.core.base"
	.short	0,0
.Le40:
	.size	RTTI_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL, .Le40 - RTTI_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL

.section .rodata.n_INIT_$NEXTPAS.CORE.BASE_$$_EEMPTYCOLLECTION
	.balign 8
.globl	INIT_$NEXTPAS.CORE.BASE_$$_EEMPTYCOLLECTION
	.type	INIT_$NEXTPAS.CORE.BASE_$$_EEMPTYCOLLECTION,@object
INIT_$NEXTPAS.CORE.BASE_$$_EEMPTYCOLLECTION:
	.byte	15,16
	.ascii	"EEmptyCollection"
	.quad	0,0
	.long	8
	.quad	0,0
	.long	0
.Le41:
	.size	INIT_$NEXTPAS.CORE.BASE_$$_EEMPTYCOLLECTION, .Le41 - INIT_$NEXTPAS.CORE.BASE_$$_EEMPTYCOLLECTION

.section .rodata.n_RTTI_$NEXTPAS.CORE.BASE_$$_EEMPTYCOLLECTION
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BASE_$$_EEMPTYCOLLECTION
	.type	RTTI_$NEXTPAS.CORE.BASE_$$_EEMPTYCOLLECTION,@object
RTTI_$NEXTPAS.CORE.BASE_$$_EEMPTYCOLLECTION:
	.byte	15,16
	.ascii	"EEmptyCollection"
	.quad	0
	.quad	VMT_$NEXTPAS.CORE.BASE_$$_EEMPTYCOLLECTION
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_ECORE$indirect
	.short	0
	.byte	17
	.ascii	"nextpas.core.base"
	.short	0,0
.Le42:
	.size	RTTI_$NEXTPAS.CORE.BASE_$$_EEMPTYCOLLECTION, .Le42 - RTTI_$NEXTPAS.CORE.BASE_$$_EEMPTYCOLLECTION

.section .rodata.n_INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT
	.balign 8
.globl	INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT
	.type	INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT,@object
INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT:
	.byte	15,16
	.ascii	"EInvalidArgument"
	.quad	0,0
	.long	8
	.quad	0,0
	.long	0
.Le43:
	.size	INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT, .Le43 - INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT

.section .rodata.n_RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT
	.type	RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT,@object
RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT:
	.byte	15,16
	.ascii	"EInvalidArgument"
	.quad	0
	.quad	VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_ECORE$indirect
	.short	0
	.byte	17
	.ascii	"nextpas.core.base"
	.short	0,0
.Le44:
	.size	RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT, .Le44 - RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT

.section .rodata.n_INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDRESULT
	.balign 8
.globl	INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDRESULT
	.type	INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDRESULT,@object
INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDRESULT:
	.byte	15,14
	.ascii	"EInvalidResult"
	.quad	0,0
	.long	8
	.quad	0,0
	.long	0
.Le45:
	.size	INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDRESULT, .Le45 - INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDRESULT

.section .rodata.n_RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDRESULT
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDRESULT
	.type	RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDRESULT,@object
RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDRESULT:
	.byte	15,14
	.ascii	"EInvalidResult"
	.quad	0
	.quad	VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDRESULT
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_ECORE$indirect
	.short	0
	.byte	17
	.ascii	"nextpas.core.base"
	.short	0,0
.Le46:
	.size	RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDRESULT, .Le46 - RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDRESULT

.section .rodata.n_INIT_$NEXTPAS.CORE.BASE_$$_ETIMEOUTERROR
	.balign 8
.globl	INIT_$NEXTPAS.CORE.BASE_$$_ETIMEOUTERROR
	.type	INIT_$NEXTPAS.CORE.BASE_$$_ETIMEOUTERROR,@object
INIT_$NEXTPAS.CORE.BASE_$$_ETIMEOUTERROR:
	.byte	15,13
	.ascii	"ETimeoutError"
	.quad	0,0
	.long	8
	.quad	0,0
	.long	0
.Le47:
	.size	INIT_$NEXTPAS.CORE.BASE_$$_ETIMEOUTERROR, .Le47 - INIT_$NEXTPAS.CORE.BASE_$$_ETIMEOUTERROR

.section .rodata.n_RTTI_$NEXTPAS.CORE.BASE_$$_ETIMEOUTERROR
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BASE_$$_ETIMEOUTERROR
	.type	RTTI_$NEXTPAS.CORE.BASE_$$_ETIMEOUTERROR,@object
RTTI_$NEXTPAS.CORE.BASE_$$_ETIMEOUTERROR:
	.byte	15,13
	.ascii	"ETimeoutError"
	.quad	0
	.quad	VMT_$NEXTPAS.CORE.BASE_$$_ETIMEOUTERROR
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_ECORE$indirect
	.short	0
	.byte	17
	.ascii	"nextpas.core.base"
	.short	0,0
.Le48:
	.size	RTTI_$NEXTPAS.CORE.BASE_$$_ETIMEOUTERROR, .Le48 - RTTI_$NEXTPAS.CORE.BASE_$$_ETIMEOUTERROR

.section .rodata.n_INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDSTATE
	.balign 8
.globl	INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDSTATE
	.type	INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDSTATE,@object
INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDSTATE:
	.byte	15,13
	.ascii	"EInvalidState"
	.quad	0,0
	.long	8
	.quad	0,0
	.long	0
.Le49:
	.size	INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDSTATE, .Le49 - INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDSTATE

.section .rodata.n_RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDSTATE
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDSTATE
	.type	RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDSTATE,@object
RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDSTATE:
	.byte	15,13
	.ascii	"EInvalidState"
	.quad	0
	.quad	VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDSTATE
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_ECORE$indirect
	.short	0
	.byte	17
	.ascii	"nextpas.core.base"
	.short	0,0
.Le50:
	.size	RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDSTATE, .Le50 - RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDSTATE

.section .rodata.n_INIT_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE
	.balign 8
.globl	INIT_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE
	.type	INIT_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE,@object
INIT_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE:
	.byte	15,11
	.ascii	"EOutOfRange"
	.quad	0,0
	.long	8
	.quad	0,0
	.long	0
.Le51:
	.size	INIT_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE, .Le51 - INIT_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE

.section .rodata.n_RTTI_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE
	.type	RTTI_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE,@object
RTTI_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE:
	.byte	15,11
	.ascii	"EOutOfRange"
	.quad	0
	.quad	VMT_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_ECORE$indirect
	.short	0
	.byte	17
	.ascii	"nextpas.core.base"
	.short	0,0
.Le52:
	.size	RTTI_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE, .Le52 - RTTI_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE

.section .rodata.n_INIT_$NEXTPAS.CORE.BASE_$$_ENOTSUPPORTED
	.balign 8
.globl	INIT_$NEXTPAS.CORE.BASE_$$_ENOTSUPPORTED
	.type	INIT_$NEXTPAS.CORE.BASE_$$_ENOTSUPPORTED,@object
INIT_$NEXTPAS.CORE.BASE_$$_ENOTSUPPORTED:
	.byte	15,13
	.ascii	"ENotSupported"
	.quad	0,0
	.long	8
	.quad	0,0
	.long	0
.Le53:
	.size	INIT_$NEXTPAS.CORE.BASE_$$_ENOTSUPPORTED, .Le53 - INIT_$NEXTPAS.CORE.BASE_$$_ENOTSUPPORTED

.section .rodata.n_RTTI_$NEXTPAS.CORE.BASE_$$_ENOTSUPPORTED
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BASE_$$_ENOTSUPPORTED
	.type	RTTI_$NEXTPAS.CORE.BASE_$$_ENOTSUPPORTED,@object
RTTI_$NEXTPAS.CORE.BASE_$$_ENOTSUPPORTED:
	.byte	15,13
	.ascii	"ENotSupported"
	.quad	0
	.quad	VMT_$NEXTPAS.CORE.BASE_$$_ENOTSUPPORTED
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_ECORE$indirect
	.short	0
	.byte	17
	.ascii	"nextpas.core.base"
	.short	0,0
.Le54:
	.size	RTTI_$NEXTPAS.CORE.BASE_$$_ENOTSUPPORTED, .Le54 - RTTI_$NEXTPAS.CORE.BASE_$$_ENOTSUPPORTED

.section .rodata.n_INIT_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE
	.balign 8
.globl	INIT_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE
	.type	INIT_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE,@object
INIT_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE:
	.byte	15,14
	.ascii	"ENotCompatible"
	.quad	0,0
	.long	8
	.quad	0,0
	.long	0
.Le55:
	.size	INIT_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE, .Le55 - INIT_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE

.section .rodata.n_RTTI_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE
	.type	RTTI_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE,@object
RTTI_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE:
	.byte	15,14
	.ascii	"ENotCompatible"
	.quad	0
	.quad	VMT_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_ECORE$indirect
	.short	0
	.byte	17
	.ascii	"nextpas.core.base"
	.short	0,0
.Le56:
	.size	RTTI_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE, .Le56 - RTTI_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE

.section .rodata.n_INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDOPERATION
	.balign 8
.globl	INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDOPERATION
	.type	INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDOPERATION,@object
INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDOPERATION:
	.byte	15,17
	.ascii	"EInvalidOperation"
	.quad	0,0
	.long	8
	.quad	0,0
	.long	0
.Le57:
	.size	INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDOPERATION, .Le57 - INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDOPERATION

.section .rodata.n_RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDOPERATION
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDOPERATION
	.type	RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDOPERATION,@object
RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDOPERATION:
	.byte	15,17
	.ascii	"EInvalidOperation"
	.quad	0
	.quad	VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDOPERATION
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_ECORE$indirect
	.short	0
	.byte	17
	.ascii	"nextpas.core.base"
	.short	0,0
.Le58:
	.size	RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDOPERATION, .Le58 - RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDOPERATION

.section .rodata.n_INIT_$NEXTPAS.CORE.BASE_$$_EOUTOFMEMORY
	.balign 8
.globl	INIT_$NEXTPAS.CORE.BASE_$$_EOUTOFMEMORY
	.type	INIT_$NEXTPAS.CORE.BASE_$$_EOUTOFMEMORY,@object
INIT_$NEXTPAS.CORE.BASE_$$_EOUTOFMEMORY:
	.byte	15,12
	.ascii	"EOutOfMemory"
	.quad	0,0
	.long	8
	.quad	0,0
	.long	0
.Le59:
	.size	INIT_$NEXTPAS.CORE.BASE_$$_EOUTOFMEMORY, .Le59 - INIT_$NEXTPAS.CORE.BASE_$$_EOUTOFMEMORY

.section .rodata.n_RTTI_$NEXTPAS.CORE.BASE_$$_EOUTOFMEMORY
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BASE_$$_EOUTOFMEMORY
	.type	RTTI_$NEXTPAS.CORE.BASE_$$_EOUTOFMEMORY,@object
RTTI_$NEXTPAS.CORE.BASE_$$_EOUTOFMEMORY:
	.byte	15,12
	.ascii	"EOutOfMemory"
	.quad	0
	.quad	VMT_$NEXTPAS.CORE.BASE_$$_EOUTOFMEMORY
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_ECORE$indirect
	.short	0
	.byte	17
	.ascii	"nextpas.core.base"
	.short	0,0
.Le60:
	.size	RTTI_$NEXTPAS.CORE.BASE_$$_EOUTOFMEMORY, .Le60 - RTTI_$NEXTPAS.CORE.BASE_$$_EOUTOFMEMORY

.section .rodata.n_INIT_$NEXTPAS.CORE.BASE_$$_EOVERFLOW
	.balign 8
.globl	INIT_$NEXTPAS.CORE.BASE_$$_EOVERFLOW
	.type	INIT_$NEXTPAS.CORE.BASE_$$_EOVERFLOW,@object
INIT_$NEXTPAS.CORE.BASE_$$_EOVERFLOW:
	.byte	15,9
	.ascii	"EOverflow"
	.quad	0,0
	.long	8
	.quad	0,0
	.long	0
.Le61:
	.size	INIT_$NEXTPAS.CORE.BASE_$$_EOVERFLOW, .Le61 - INIT_$NEXTPAS.CORE.BASE_$$_EOVERFLOW

.section .rodata.n_RTTI_$NEXTPAS.CORE.BASE_$$_EOVERFLOW
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BASE_$$_EOVERFLOW
	.type	RTTI_$NEXTPAS.CORE.BASE_$$_EOVERFLOW,@object
RTTI_$NEXTPAS.CORE.BASE_$$_EOVERFLOW:
	.byte	15,9
	.ascii	"EOverflow"
	.quad	0
	.quad	VMT_$NEXTPAS.CORE.BASE_$$_EOVERFLOW
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_ECORE$indirect
	.short	0
	.byte	17
	.ascii	"nextpas.core.base"
	.short	0,0
.Le62:
	.size	RTTI_$NEXTPAS.CORE.BASE_$$_EOVERFLOW, .Le62 - RTTI_$NEXTPAS.CORE.BASE_$$_EOVERFLOW

.section .rodata.n_RTTI_$NEXTPAS.CORE.BASE_$$_TPROC
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BASE_$$_TPROC
	.type	RTTI_$NEXTPAS.CORE.BASE_$$_TPROC,@object
RTTI_$NEXTPAS.CORE.BASE_$$_TPROC:
	.byte	14,5
	.ascii	"TPROC"
	.quad	0
	.quad	RTTI_$SYSTEM_$$_IUNKNOWN$indirect
	.byte	1
	.long	0
	.short	0,0
	.byte	0,0,0,0,0,0,0,0
	.quad	0
	.byte	17
	.ascii	"nextpas.core.base"
	.short	0,1,65535
.Le63:
	.size	RTTI_$NEXTPAS.CORE.BASE_$$_TPROC, .Le63 - RTTI_$NEXTPAS.CORE.BASE_$$_TPROC

.section .rodata.n_RTTI_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORFUNC
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORFUNC
	.type	RTTI_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORFUNC,@object
RTTI_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORFUNC:
	.byte	23,20
	.ascii	"TRandomGeneratorFunc"
	.quad	0
	.byte	0,0
	.quad	RTTI_$SYSTEM_$$_INT64$indirect
	.byte	2
	.short	0
	.quad	RTTI_$SYSTEM_$$_INT64$indirect
	.byte	6
	.ascii	"ARange"
	.short	0
	.quad	RTTI_$SYSTEM_$$_POINTER$indirect
	.byte	5
	.ascii	"AData"
.Le64:
	.size	RTTI_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORFUNC, .Le64 - RTTI_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORFUNC

.section .rodata.n_RTTI_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORMETHOD
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORMETHOD
	.type	RTTI_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORMETHOD,@object
RTTI_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORMETHOD:
	.byte	6,22
	.ascii	"TRandomGeneratorMethod"
	.quad	0
	.byte	1,3
	.short	640
	.byte	5
	.ascii	"$self"
	.byte	7
	.ascii	"Pointer"
	.short	0
	.byte	6
	.ascii	"ARange"
	.byte	5
	.ascii	"Int64"
	.short	0
	.byte	5
	.ascii	"AData"
	.byte	7
	.ascii	"Pointer"
	.byte	5
	.ascii	"Int64"
	.quad	RTTI_$SYSTEM_$$_INT64$indirect
	.byte	0
	.quad	RTTI_$SYSTEM_$$_POINTER$indirect
	.quad	RTTI_$SYSTEM_$$_INT64$indirect
	.quad	RTTI_$SYSTEM_$$_POINTER$indirect
.Le65:
	.size	RTTI_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORMETHOD, .Le65 - RTTI_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORMETHOD

.section .rodata.n_RTTI_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORREFFUNC
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORREFFUNC
	.type	RTTI_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORREFFUNC,@object
RTTI_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORREFFUNC:
	.byte	14,23
	.ascii	"TRANDOMGENERATORREFFUNC"
	.quad	0
	.quad	RTTI_$SYSTEM_$$_IUNKNOWN$indirect
	.byte	1
	.long	0
	.short	0,0
	.byte	0,0,0,0,0,0,0,0
	.quad	0
	.byte	17
	.ascii	"nextpas.core.base"
	.short	0,1,65535
.Le66:
	.size	RTTI_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORREFFUNC, .Le66 - RTTI_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORREFFUNC

.section .rodata.n_INIT_$NEXTPAS.CORE.BASE_$$_TBYTESPAN
	.balign 8
.globl	INIT_$NEXTPAS.CORE.BASE_$$_TBYTESPAN
	.type	INIT_$NEXTPAS.CORE.BASE_$$_TBYTESPAN,@object
INIT_$NEXTPAS.CORE.BASE_$$_TBYTESPAN:
	.byte	13,9
	.ascii	"TByteSpan"
	.quad	0,0
	.long	16
	.quad	0,0
	.long	0
.Le67:
	.size	INIT_$NEXTPAS.CORE.BASE_$$_TBYTESPAN, .Le67 - INIT_$NEXTPAS.CORE.BASE_$$_TBYTESPAN

.section .rodata.n_RTTI_$NEXTPAS.CORE.BASE_$$_TBYTESPAN
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BASE_$$_TBYTESPAN
	.type	RTTI_$NEXTPAS.CORE.BASE_$$_TBYTESPAN,@object
RTTI_$NEXTPAS.CORE.BASE_$$_TBYTESPAN:
	.byte	13,9
	.ascii	"TByteSpan"
	.quad	0
	.quad	INIT_$NEXTPAS.CORE.BASE_$$_TBYTESPAN
	.long	16,2
	.quad	RTTI_$SYSTEM_$$_PBYTE$indirect
	.quad	0
	.quad	RTTI_$SYSTEM_$$_QWORD$indirect
	.quad	8
	.short	0,0,0
.Le68:
	.size	RTTI_$NEXTPAS.CORE.BASE_$$_TBYTESPAN, .Le68 - RTTI_$NEXTPAS.CORE.BASE_$$_TBYTESPAN
# End asmlist al_rtti
# Begin asmlist al_indirectglobals

.section .rodata.n_VMT_$NEXTPAS.CORE.BASE_$$_ECORE
	.balign 8
.globl	VMT_$NEXTPAS.CORE.BASE_$$_ECORE$indirect
	.type	VMT_$NEXTPAS.CORE.BASE_$$_ECORE$indirect,@object
VMT_$NEXTPAS.CORE.BASE_$$_ECORE$indirect:
	.quad	VMT_$NEXTPAS.CORE.BASE_$$_ECORE
# [238] end.
.Le69:
	.size	VMT_$NEXTPAS.CORE.BASE_$$_ECORE$indirect, .Le69 - VMT_$NEXTPAS.CORE.BASE_$$_ECORE$indirect

.section .rodata.n_VMT_$NEXTPAS.CORE.BASE_$$_EWOW
	.balign 8
.globl	VMT_$NEXTPAS.CORE.BASE_$$_EWOW$indirect
	.type	VMT_$NEXTPAS.CORE.BASE_$$_EWOW$indirect,@object
VMT_$NEXTPAS.CORE.BASE_$$_EWOW$indirect:
	.quad	VMT_$NEXTPAS.CORE.BASE_$$_EWOW
.Le70:
	.size	VMT_$NEXTPAS.CORE.BASE_$$_EWOW$indirect, .Le70 - VMT_$NEXTPAS.CORE.BASE_$$_EWOW$indirect

.section .rodata.n_VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL
	.balign 8
.globl	VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL$indirect
	.type	VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL$indirect,@object
VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL$indirect:
	.quad	VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL
.Le71:
	.size	VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL$indirect, .Le71 - VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL$indirect

.section .rodata.n_VMT_$NEXTPAS.CORE.BASE_$$_EEMPTYCOLLECTION
	.balign 8
.globl	VMT_$NEXTPAS.CORE.BASE_$$_EEMPTYCOLLECTION$indirect
	.type	VMT_$NEXTPAS.CORE.BASE_$$_EEMPTYCOLLECTION$indirect,@object
VMT_$NEXTPAS.CORE.BASE_$$_EEMPTYCOLLECTION$indirect:
	.quad	VMT_$NEXTPAS.CORE.BASE_$$_EEMPTYCOLLECTION
.Le72:
	.size	VMT_$NEXTPAS.CORE.BASE_$$_EEMPTYCOLLECTION$indirect, .Le72 - VMT_$NEXTPAS.CORE.BASE_$$_EEMPTYCOLLECTION$indirect

.section .rodata.n_VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT
	.balign 8
.globl	VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT$indirect
	.type	VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT$indirect,@object
VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT$indirect:
	.quad	VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT
.Le73:
	.size	VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT$indirect, .Le73 - VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT$indirect

.section .rodata.n_VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDRESULT
	.balign 8
.globl	VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDRESULT$indirect
	.type	VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDRESULT$indirect,@object
VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDRESULT$indirect:
	.quad	VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDRESULT
.Le74:
	.size	VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDRESULT$indirect, .Le74 - VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDRESULT$indirect

.section .rodata.n_VMT_$NEXTPAS.CORE.BASE_$$_ETIMEOUTERROR
	.balign 8
.globl	VMT_$NEXTPAS.CORE.BASE_$$_ETIMEOUTERROR$indirect
	.type	VMT_$NEXTPAS.CORE.BASE_$$_ETIMEOUTERROR$indirect,@object
VMT_$NEXTPAS.CORE.BASE_$$_ETIMEOUTERROR$indirect:
	.quad	VMT_$NEXTPAS.CORE.BASE_$$_ETIMEOUTERROR
.Le75:
	.size	VMT_$NEXTPAS.CORE.BASE_$$_ETIMEOUTERROR$indirect, .Le75 - VMT_$NEXTPAS.CORE.BASE_$$_ETIMEOUTERROR$indirect

.section .rodata.n_VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDSTATE
	.balign 8
.globl	VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDSTATE$indirect
	.type	VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDSTATE$indirect,@object
VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDSTATE$indirect:
	.quad	VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDSTATE
.Le76:
	.size	VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDSTATE$indirect, .Le76 - VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDSTATE$indirect

.section .rodata.n_VMT_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE
	.balign 8
.globl	VMT_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE$indirect
	.type	VMT_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE$indirect,@object
VMT_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE$indirect:
	.quad	VMT_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE
.Le77:
	.size	VMT_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE$indirect, .Le77 - VMT_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE$indirect

.section .rodata.n_VMT_$NEXTPAS.CORE.BASE_$$_ENOTSUPPORTED
	.balign 8
.globl	VMT_$NEXTPAS.CORE.BASE_$$_ENOTSUPPORTED$indirect
	.type	VMT_$NEXTPAS.CORE.BASE_$$_ENOTSUPPORTED$indirect,@object
VMT_$NEXTPAS.CORE.BASE_$$_ENOTSUPPORTED$indirect:
	.quad	VMT_$NEXTPAS.CORE.BASE_$$_ENOTSUPPORTED
.Le78:
	.size	VMT_$NEXTPAS.CORE.BASE_$$_ENOTSUPPORTED$indirect, .Le78 - VMT_$NEXTPAS.CORE.BASE_$$_ENOTSUPPORTED$indirect

.section .rodata.n_VMT_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE
	.balign 8
.globl	VMT_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE$indirect
	.type	VMT_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE$indirect,@object
VMT_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE$indirect:
	.quad	VMT_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE
.Le79:
	.size	VMT_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE$indirect, .Le79 - VMT_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE$indirect

.section .rodata.n_VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDOPERATION
	.balign 8
.globl	VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDOPERATION$indirect
	.type	VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDOPERATION$indirect,@object
VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDOPERATION$indirect:
	.quad	VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDOPERATION
.Le80:
	.size	VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDOPERATION$indirect, .Le80 - VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDOPERATION$indirect

.section .rodata.n_VMT_$NEXTPAS.CORE.BASE_$$_EOUTOFMEMORY
	.balign 8
.globl	VMT_$NEXTPAS.CORE.BASE_$$_EOUTOFMEMORY$indirect
	.type	VMT_$NEXTPAS.CORE.BASE_$$_EOUTOFMEMORY$indirect,@object
VMT_$NEXTPAS.CORE.BASE_$$_EOUTOFMEMORY$indirect:
	.quad	VMT_$NEXTPAS.CORE.BASE_$$_EOUTOFMEMORY
.Le81:
	.size	VMT_$NEXTPAS.CORE.BASE_$$_EOUTOFMEMORY$indirect, .Le81 - VMT_$NEXTPAS.CORE.BASE_$$_EOUTOFMEMORY$indirect

.section .rodata.n_VMT_$NEXTPAS.CORE.BASE_$$_EOVERFLOW
	.balign 8
.globl	VMT_$NEXTPAS.CORE.BASE_$$_EOVERFLOW$indirect
	.type	VMT_$NEXTPAS.CORE.BASE_$$_EOVERFLOW$indirect,@object
VMT_$NEXTPAS.CORE.BASE_$$_EOVERFLOW$indirect:
	.quad	VMT_$NEXTPAS.CORE.BASE_$$_EOVERFLOW
.Le82:
	.size	VMT_$NEXTPAS.CORE.BASE_$$_EOVERFLOW$indirect, .Le82 - VMT_$NEXTPAS.CORE.BASE_$$_EOVERFLOW$indirect

.section .rodata.n_IID_$NEXTPAS.CORE.BASE_$$_TPROC
	.balign 8
.globl	IID_$NEXTPAS.CORE.BASE_$$_TPROC$indirect
	.type	IID_$NEXTPAS.CORE.BASE_$$_TPROC$indirect,@object
IID_$NEXTPAS.CORE.BASE_$$_TPROC$indirect:
	.quad	IID_$NEXTPAS.CORE.BASE_$$_TPROC
.Le83:
	.size	IID_$NEXTPAS.CORE.BASE_$$_TPROC$indirect, .Le83 - IID_$NEXTPAS.CORE.BASE_$$_TPROC$indirect

.section .rodata.n_IIDSTR_$NEXTPAS.CORE.BASE_$$_TPROC
	.balign 8
.globl	IIDSTR_$NEXTPAS.CORE.BASE_$$_TPROC$indirect
	.type	IIDSTR_$NEXTPAS.CORE.BASE_$$_TPROC$indirect,@object
IIDSTR_$NEXTPAS.CORE.BASE_$$_TPROC$indirect:
	.quad	IIDSTR_$NEXTPAS.CORE.BASE_$$_TPROC
.Le84:
	.size	IIDSTR_$NEXTPAS.CORE.BASE_$$_TPROC$indirect, .Le84 - IIDSTR_$NEXTPAS.CORE.BASE_$$_TPROC$indirect

.section .rodata.n_IID_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORREFFUNC
	.balign 8
.globl	IID_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORREFFUNC$indirect
	.type	IID_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORREFFUNC$indirect,@object
IID_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORREFFUNC$indirect:
	.quad	IID_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORREFFUNC
.Le85:
	.size	IID_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORREFFUNC$indirect, .Le85 - IID_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORREFFUNC$indirect

.section .rodata.n_IIDSTR_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORREFFUNC
	.balign 8
.globl	IIDSTR_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORREFFUNC$indirect
	.type	IIDSTR_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORREFFUNC$indirect,@object
IIDSTR_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORREFFUNC$indirect:
	.quad	IIDSTR_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORREFFUNC
.Le86:
	.size	IIDSTR_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORREFFUNC$indirect, .Le86 - IIDSTR_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORREFFUNC$indirect

.section .rodata.n_INIT_$NEXTPAS.CORE.BASE_$$_ECORE
	.balign 8
.globl	INIT_$NEXTPAS.CORE.BASE_$$_ECORE$indirect
	.type	INIT_$NEXTPAS.CORE.BASE_$$_ECORE$indirect,@object
INIT_$NEXTPAS.CORE.BASE_$$_ECORE$indirect:
	.quad	INIT_$NEXTPAS.CORE.BASE_$$_ECORE
# [239] 
.Le87:
	.size	INIT_$NEXTPAS.CORE.BASE_$$_ECORE$indirect, .Le87 - INIT_$NEXTPAS.CORE.BASE_$$_ECORE$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.BASE_$$_ECORE
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BASE_$$_ECORE$indirect
	.type	RTTI_$NEXTPAS.CORE.BASE_$$_ECORE$indirect,@object
RTTI_$NEXTPAS.CORE.BASE_$$_ECORE$indirect:
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_ECORE
.Le88:
	.size	RTTI_$NEXTPAS.CORE.BASE_$$_ECORE$indirect, .Le88 - RTTI_$NEXTPAS.CORE.BASE_$$_ECORE$indirect

.section .rodata.n_INIT_$NEXTPAS.CORE.BASE_$$_EWOW
	.balign 8
.globl	INIT_$NEXTPAS.CORE.BASE_$$_EWOW$indirect
	.type	INIT_$NEXTPAS.CORE.BASE_$$_EWOW$indirect,@object
INIT_$NEXTPAS.CORE.BASE_$$_EWOW$indirect:
	.quad	INIT_$NEXTPAS.CORE.BASE_$$_EWOW
.Le89:
	.size	INIT_$NEXTPAS.CORE.BASE_$$_EWOW$indirect, .Le89 - INIT_$NEXTPAS.CORE.BASE_$$_EWOW$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.BASE_$$_EWOW
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BASE_$$_EWOW$indirect
	.type	RTTI_$NEXTPAS.CORE.BASE_$$_EWOW$indirect,@object
RTTI_$NEXTPAS.CORE.BASE_$$_EWOW$indirect:
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_EWOW
.Le90:
	.size	RTTI_$NEXTPAS.CORE.BASE_$$_EWOW$indirect, .Le90 - RTTI_$NEXTPAS.CORE.BASE_$$_EWOW$indirect

.section .rodata.n_INIT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL
	.balign 8
.globl	INIT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL$indirect
	.type	INIT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL$indirect,@object
INIT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL$indirect:
	.quad	INIT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL
.Le91:
	.size	INIT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL$indirect, .Le91 - INIT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL$indirect
	.type	RTTI_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL$indirect,@object
RTTI_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL$indirect:
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL
.Le92:
	.size	RTTI_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL$indirect, .Le92 - RTTI_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL$indirect

.section .rodata.n_INIT_$NEXTPAS.CORE.BASE_$$_EEMPTYCOLLECTION
	.balign 8
.globl	INIT_$NEXTPAS.CORE.BASE_$$_EEMPTYCOLLECTION$indirect
	.type	INIT_$NEXTPAS.CORE.BASE_$$_EEMPTYCOLLECTION$indirect,@object
INIT_$NEXTPAS.CORE.BASE_$$_EEMPTYCOLLECTION$indirect:
	.quad	INIT_$NEXTPAS.CORE.BASE_$$_EEMPTYCOLLECTION
.Le93:
	.size	INIT_$NEXTPAS.CORE.BASE_$$_EEMPTYCOLLECTION$indirect, .Le93 - INIT_$NEXTPAS.CORE.BASE_$$_EEMPTYCOLLECTION$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.BASE_$$_EEMPTYCOLLECTION
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BASE_$$_EEMPTYCOLLECTION$indirect
	.type	RTTI_$NEXTPAS.CORE.BASE_$$_EEMPTYCOLLECTION$indirect,@object
RTTI_$NEXTPAS.CORE.BASE_$$_EEMPTYCOLLECTION$indirect:
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_EEMPTYCOLLECTION
.Le94:
	.size	RTTI_$NEXTPAS.CORE.BASE_$$_EEMPTYCOLLECTION$indirect, .Le94 - RTTI_$NEXTPAS.CORE.BASE_$$_EEMPTYCOLLECTION$indirect

.section .rodata.n_INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT
	.balign 8
.globl	INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT$indirect
	.type	INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT$indirect,@object
INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT$indirect:
	.quad	INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT
.Le95:
	.size	INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT$indirect, .Le95 - INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT$indirect
	.type	RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT$indirect,@object
RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT$indirect:
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT
.Le96:
	.size	RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT$indirect, .Le96 - RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT$indirect

.section .rodata.n_INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDRESULT
	.balign 8
.globl	INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDRESULT$indirect
	.type	INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDRESULT$indirect,@object
INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDRESULT$indirect:
	.quad	INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDRESULT
.Le97:
	.size	INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDRESULT$indirect, .Le97 - INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDRESULT$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDRESULT
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDRESULT$indirect
	.type	RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDRESULT$indirect,@object
RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDRESULT$indirect:
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDRESULT
.Le98:
	.size	RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDRESULT$indirect, .Le98 - RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDRESULT$indirect

.section .rodata.n_INIT_$NEXTPAS.CORE.BASE_$$_ETIMEOUTERROR
	.balign 8
.globl	INIT_$NEXTPAS.CORE.BASE_$$_ETIMEOUTERROR$indirect
	.type	INIT_$NEXTPAS.CORE.BASE_$$_ETIMEOUTERROR$indirect,@object
INIT_$NEXTPAS.CORE.BASE_$$_ETIMEOUTERROR$indirect:
	.quad	INIT_$NEXTPAS.CORE.BASE_$$_ETIMEOUTERROR
.Le99:
	.size	INIT_$NEXTPAS.CORE.BASE_$$_ETIMEOUTERROR$indirect, .Le99 - INIT_$NEXTPAS.CORE.BASE_$$_ETIMEOUTERROR$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.BASE_$$_ETIMEOUTERROR
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BASE_$$_ETIMEOUTERROR$indirect
	.type	RTTI_$NEXTPAS.CORE.BASE_$$_ETIMEOUTERROR$indirect,@object
RTTI_$NEXTPAS.CORE.BASE_$$_ETIMEOUTERROR$indirect:
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_ETIMEOUTERROR
.Le100:
	.size	RTTI_$NEXTPAS.CORE.BASE_$$_ETIMEOUTERROR$indirect, .Le100 - RTTI_$NEXTPAS.CORE.BASE_$$_ETIMEOUTERROR$indirect

.section .rodata.n_INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDSTATE
	.balign 8
.globl	INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDSTATE$indirect
	.type	INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDSTATE$indirect,@object
INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDSTATE$indirect:
	.quad	INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDSTATE
.Le101:
	.size	INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDSTATE$indirect, .Le101 - INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDSTATE$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDSTATE
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDSTATE$indirect
	.type	RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDSTATE$indirect,@object
RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDSTATE$indirect:
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDSTATE
.Le102:
	.size	RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDSTATE$indirect, .Le102 - RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDSTATE$indirect

.section .rodata.n_INIT_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE
	.balign 8
.globl	INIT_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE$indirect
	.type	INIT_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE$indirect,@object
INIT_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE$indirect:
	.quad	INIT_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE
.Le103:
	.size	INIT_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE$indirect, .Le103 - INIT_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE$indirect
	.type	RTTI_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE$indirect,@object
RTTI_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE$indirect:
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE
.Le104:
	.size	RTTI_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE$indirect, .Le104 - RTTI_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE$indirect

.section .rodata.n_INIT_$NEXTPAS.CORE.BASE_$$_ENOTSUPPORTED
	.balign 8
.globl	INIT_$NEXTPAS.CORE.BASE_$$_ENOTSUPPORTED$indirect
	.type	INIT_$NEXTPAS.CORE.BASE_$$_ENOTSUPPORTED$indirect,@object
INIT_$NEXTPAS.CORE.BASE_$$_ENOTSUPPORTED$indirect:
	.quad	INIT_$NEXTPAS.CORE.BASE_$$_ENOTSUPPORTED
.Le105:
	.size	INIT_$NEXTPAS.CORE.BASE_$$_ENOTSUPPORTED$indirect, .Le105 - INIT_$NEXTPAS.CORE.BASE_$$_ENOTSUPPORTED$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.BASE_$$_ENOTSUPPORTED
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BASE_$$_ENOTSUPPORTED$indirect
	.type	RTTI_$NEXTPAS.CORE.BASE_$$_ENOTSUPPORTED$indirect,@object
RTTI_$NEXTPAS.CORE.BASE_$$_ENOTSUPPORTED$indirect:
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_ENOTSUPPORTED
.Le106:
	.size	RTTI_$NEXTPAS.CORE.BASE_$$_ENOTSUPPORTED$indirect, .Le106 - RTTI_$NEXTPAS.CORE.BASE_$$_ENOTSUPPORTED$indirect

.section .rodata.n_INIT_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE
	.balign 8
.globl	INIT_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE$indirect
	.type	INIT_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE$indirect,@object
INIT_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE$indirect:
	.quad	INIT_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE
.Le107:
	.size	INIT_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE$indirect, .Le107 - INIT_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE$indirect
	.type	RTTI_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE$indirect,@object
RTTI_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE$indirect:
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE
.Le108:
	.size	RTTI_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE$indirect, .Le108 - RTTI_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE$indirect

.section .rodata.n_INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDOPERATION
	.balign 8
.globl	INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDOPERATION$indirect
	.type	INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDOPERATION$indirect,@object
INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDOPERATION$indirect:
	.quad	INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDOPERATION
.Le109:
	.size	INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDOPERATION$indirect, .Le109 - INIT_$NEXTPAS.CORE.BASE_$$_EINVALIDOPERATION$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDOPERATION
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDOPERATION$indirect
	.type	RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDOPERATION$indirect,@object
RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDOPERATION$indirect:
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDOPERATION
.Le110:
	.size	RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDOPERATION$indirect, .Le110 - RTTI_$NEXTPAS.CORE.BASE_$$_EINVALIDOPERATION$indirect

.section .rodata.n_INIT_$NEXTPAS.CORE.BASE_$$_EOUTOFMEMORY
	.balign 8
.globl	INIT_$NEXTPAS.CORE.BASE_$$_EOUTOFMEMORY$indirect
	.type	INIT_$NEXTPAS.CORE.BASE_$$_EOUTOFMEMORY$indirect,@object
INIT_$NEXTPAS.CORE.BASE_$$_EOUTOFMEMORY$indirect:
	.quad	INIT_$NEXTPAS.CORE.BASE_$$_EOUTOFMEMORY
.Le111:
	.size	INIT_$NEXTPAS.CORE.BASE_$$_EOUTOFMEMORY$indirect, .Le111 - INIT_$NEXTPAS.CORE.BASE_$$_EOUTOFMEMORY$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.BASE_$$_EOUTOFMEMORY
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BASE_$$_EOUTOFMEMORY$indirect
	.type	RTTI_$NEXTPAS.CORE.BASE_$$_EOUTOFMEMORY$indirect,@object
RTTI_$NEXTPAS.CORE.BASE_$$_EOUTOFMEMORY$indirect:
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_EOUTOFMEMORY
.Le112:
	.size	RTTI_$NEXTPAS.CORE.BASE_$$_EOUTOFMEMORY$indirect, .Le112 - RTTI_$NEXTPAS.CORE.BASE_$$_EOUTOFMEMORY$indirect

.section .rodata.n_INIT_$NEXTPAS.CORE.BASE_$$_EOVERFLOW
	.balign 8
.globl	INIT_$NEXTPAS.CORE.BASE_$$_EOVERFLOW$indirect
	.type	INIT_$NEXTPAS.CORE.BASE_$$_EOVERFLOW$indirect,@object
INIT_$NEXTPAS.CORE.BASE_$$_EOVERFLOW$indirect:
	.quad	INIT_$NEXTPAS.CORE.BASE_$$_EOVERFLOW
.Le113:
	.size	INIT_$NEXTPAS.CORE.BASE_$$_EOVERFLOW$indirect, .Le113 - INIT_$NEXTPAS.CORE.BASE_$$_EOVERFLOW$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.BASE_$$_EOVERFLOW
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BASE_$$_EOVERFLOW$indirect
	.type	RTTI_$NEXTPAS.CORE.BASE_$$_EOVERFLOW$indirect,@object
RTTI_$NEXTPAS.CORE.BASE_$$_EOVERFLOW$indirect:
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_EOVERFLOW
.Le114:
	.size	RTTI_$NEXTPAS.CORE.BASE_$$_EOVERFLOW$indirect, .Le114 - RTTI_$NEXTPAS.CORE.BASE_$$_EOVERFLOW$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.BASE_$$_TPROC
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BASE_$$_TPROC$indirect
	.type	RTTI_$NEXTPAS.CORE.BASE_$$_TPROC$indirect,@object
RTTI_$NEXTPAS.CORE.BASE_$$_TPROC$indirect:
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_TPROC
.Le115:
	.size	RTTI_$NEXTPAS.CORE.BASE_$$_TPROC$indirect, .Le115 - RTTI_$NEXTPAS.CORE.BASE_$$_TPROC$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORFUNC
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORFUNC$indirect
	.type	RTTI_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORFUNC$indirect,@object
RTTI_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORFUNC$indirect:
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORFUNC
.Le116:
	.size	RTTI_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORFUNC$indirect, .Le116 - RTTI_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORFUNC$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORMETHOD
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORMETHOD$indirect
	.type	RTTI_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORMETHOD$indirect,@object
RTTI_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORMETHOD$indirect:
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORMETHOD
.Le117:
	.size	RTTI_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORMETHOD$indirect, .Le117 - RTTI_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORMETHOD$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORREFFUNC
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORREFFUNC$indirect
	.type	RTTI_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORREFFUNC$indirect,@object
RTTI_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORREFFUNC$indirect:
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORREFFUNC
.Le118:
	.size	RTTI_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORREFFUNC$indirect, .Le118 - RTTI_$NEXTPAS.CORE.BASE_$$_TRANDOMGENERATORREFFUNC$indirect

.section .rodata.n_INIT_$NEXTPAS.CORE.BASE_$$_TBYTESPAN
	.balign 8
.globl	INIT_$NEXTPAS.CORE.BASE_$$_TBYTESPAN$indirect
	.type	INIT_$NEXTPAS.CORE.BASE_$$_TBYTESPAN$indirect,@object
INIT_$NEXTPAS.CORE.BASE_$$_TBYTESPAN$indirect:
	.quad	INIT_$NEXTPAS.CORE.BASE_$$_TBYTESPAN
.Le119:
	.size	INIT_$NEXTPAS.CORE.BASE_$$_TBYTESPAN$indirect, .Le119 - INIT_$NEXTPAS.CORE.BASE_$$_TBYTESPAN$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.BASE_$$_TBYTESPAN
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.BASE_$$_TBYTESPAN$indirect
	.type	RTTI_$NEXTPAS.CORE.BASE_$$_TBYTESPAN$indirect,@object
RTTI_$NEXTPAS.CORE.BASE_$$_TBYTESPAN$indirect:
	.quad	RTTI_$NEXTPAS.CORE.BASE_$$_TBYTESPAN
.Le120:
	.size	RTTI_$NEXTPAS.CORE.BASE_$$_TBYTESPAN$indirect, .Le120 - RTTI_$NEXTPAS.CORE.BASE_$$_TBYTESPAN$indirect
# End asmlist al_indirectglobals
# Begin asmlist al_dwarf_frame

.section .debug_frame
.Lc67:
	.long	.Lc69-.Lc68
.Lc68:
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
.Lc69:
	.long	.Lc71-.Lc70
.Lc70:
	.long	.Lc67
	.quad	.Lc2
	.quad	.Lc1-.Lc2
	.byte	2
	.byte	.Lc3-.Lc2
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc4-.Lc3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc71:
	.long	.Lc74-.Lc73
.Lc73:
	.long	.Lc67
	.quad	.Lc6
	.quad	.Lc5-.Lc6
	.byte	2
	.byte	.Lc7-.Lc6
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc8-.Lc7
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc74:
	.long	.Lc77-.Lc76
.Lc76:
	.long	.Lc67
	.quad	.Lc10
	.quad	.Lc9-.Lc10
	.byte	2
	.byte	.Lc11-.Lc10
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc12-.Lc11
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc77:
	.long	.Lc80-.Lc79
.Lc79:
	.long	.Lc67
	.quad	.Lc14
	.quad	.Lc13-.Lc14
	.byte	4
	.long	.Lc15-.Lc14
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc80:
	.long	.Lc83-.Lc82
.Lc82:
	.long	.Lc67
	.quad	.Lc17
	.quad	.Lc16-.Lc17
	.byte	2
	.byte	.Lc18-.Lc17
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc19-.Lc18
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc20-.Lc19
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc21-.Lc20
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc83:
	.long	.Lc86-.Lc85
.Lc85:
	.long	.Lc67
	.quad	.Lc23
	.quad	.Lc22-.Lc23
	.byte	2
	.byte	.Lc24-.Lc23
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc25-.Lc24
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc26-.Lc25
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc27-.Lc26
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc86:
	.long	.Lc89-.Lc88
.Lc88:
	.long	.Lc67
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
.Lc89:
	.long	.Lc92-.Lc91
.Lc91:
	.long	.Lc67
	.quad	.Lc35
	.quad	.Lc34-.Lc35
	.byte	2
	.byte	.Lc36-.Lc35
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc37-.Lc36
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc38-.Lc37
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc39-.Lc38
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc92:
	.long	.Lc95-.Lc94
.Lc94:
	.long	.Lc67
	.quad	.Lc41
	.quad	.Lc40-.Lc41
	.byte	2
	.byte	.Lc42-.Lc41
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc43-.Lc42
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc44-.Lc43
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc45-.Lc44
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc95:
	.long	.Lc98-.Lc97
.Lc97:
	.long	.Lc67
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
.Lc98:
	.long	.Lc101-.Lc100
.Lc100:
	.long	.Lc67
	.quad	.Lc53
	.quad	.Lc52-.Lc53
	.byte	4
	.long	.Lc54-.Lc53
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc101:
	.long	.Lc104-.Lc103
.Lc103:
	.long	.Lc67
	.quad	.Lc56
	.quad	.Lc55-.Lc56
	.byte	2
	.byte	.Lc57-.Lc56
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc58-.Lc57
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc104:
	.long	.Lc107-.Lc106
.Lc106:
	.long	.Lc67
	.quad	.Lc60
	.quad	.Lc59-.Lc60
	.byte	2
	.byte	.Lc61-.Lc60
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc62-.Lc61
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc107:
	.long	.Lc110-.Lc109
.Lc109:
	.long	.Lc67
	.quad	.Lc64
	.quad	.Lc63-.Lc64
	.byte	2
	.byte	.Lc65-.Lc64
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc66-.Lc65
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc110:
# End asmlist al_dwarf_frame
.section .note.GNU-stack,"",%progbits

