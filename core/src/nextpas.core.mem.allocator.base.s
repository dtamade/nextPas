	.file "nextpas.core.mem.allocator.base.pas"
# Begin asmlist al_procedures

.section .text.n_nextpas.core.mem.allocator.base_$$_ispoweroftwo$qword$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_ISPOWEROFTWO$QWORD$$BOOLEAN
	.hidden NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_ISPOWEROFTWO$QWORD$$BOOLEAN
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_ISPOWEROFTWO$QWORD$$BOOLEAN,@function
NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_ISPOWEROFTWO$QWORD$$BOOLEAN:
.Lc2:
# Var x located in register rdi
# [nextpas.core.mem.allocator.base.pas]
# [161] begin
# [162] Result := (x <> 0) and ((x and (x - 1)) = 0);
	testq	%rdi,%rdi
	je	.Lj6
	leaq	-1(%rdi),%rax
	andq	%rdi,%rax
	seteb	%al
# Var $result located in register al
	ret
.Lj6:
	xorb	%al,%al
.Lc3:
# [163] end;
	ret
.Lc1:

.section .text.n_nextpas.core.mem.allocator.base_$$_alignupptr$pointer$qword$$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_ALIGNUPPTR$POINTER$QWORD$$POINTER
	.hidden NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_ALIGNUPPTR$POINTER$QWORD$$POINTER
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_ALIGNUPPTR$POINTER$QWORD$$POINTER,@function
NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_ALIGNUPPTR$POINTER$QWORD$$POINTER:
.Lc5:
# Var P located in register rdi
# Var AAlignment located in register rsi
# [168] begin
# Var LAddr located in register rdi
# Var P located in register rdi
# [170] LMask := PtrUInt(AAlignment - 1);
	leaq	-1(%rsi),%rdx
# Var LMask located in register rdx
# [171] Result := Pointer((LAddr + LMask) and not LMask);
	leaq	-1(%rdi,%rsi),%rax
	notq	%rdx
	andq	%rdx,%rax
# Var $result located in register rax
.Lc6:
# [172] end;
	ret
.Lc4:

.section .text.n_nextpas.core.mem.allocator.base$_$tallocator_$__$$_traits$$tallocatortraits,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_TRAITS$$TALLOCATORTRAITS
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_TRAITS$$TALLOCATORTRAITS,@function
NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_TRAITS$$TALLOCATORTRAITS:
.Lc8:
# [175] begin
	pushq	%rax
.Lc9:
# Var $result located at rsp+0, size=OS_32
# Var $self located in register rdi
# [181] Result.ZeroInitialized := False;
	movl	$256,%eax
	movl	$256,(%rsp)
# [185] end;
	popq	%rcx
.Lc10:
	ret
.Lc7:
.Le0:
	.size	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_TRAITS$$TALLOCATORTRAITS, .Le0 - NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_TRAITS$$TALLOCATORTRAITS

.section .text.n_nextpas.core.mem.allocator.base$_$tallocator_$__$$_allocate$qword$$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_ALLOCATE$QWORD$$POINTER
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_ALLOCATE$QWORD$$POINTER,@function
NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_ALLOCATE$QWORD$$POINTER:
.Lc12:
# [188] begin
	pushq	%rax
.Lc13:
# Var $self located in register rdi
# Var ASize located in register rsi
# Var ASize located in register rsi
# Var $self located in register rdi
# [189] Result := GetMem(ASize);
	call	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_GETMEM$QWORD$$POINTER
# Var $result located in register rax
# [190] end;
	popq	%rcx
.Lc14:
	ret
.Lc11:
.Le1:
	.size	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_ALLOCATE$QWORD$$POINTER, .Le1 - NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_ALLOCATE$QWORD$$POINTER

.section .text.n_nextpas.core.mem.allocator.base$_$tallocator_$__$$_reallocate$pointer$qword$$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_REALLOCATE$POINTER$QWORD$$POINTER
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_REALLOCATE$POINTER$QWORD$$POINTER,@function
NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_REALLOCATE$POINTER$QWORD$$POINTER:
.Lc16:
# [193] begin
	pushq	%rax
.Lc17:
# Var $self located in register rdi
# Var APtr located in register rsi
# Var ANewSize located in register rdx
# Var ANewSize located in register rdx
# Var APtr located in register rsi
# Var $self located in register rdi
# [194] Result := ReallocMem(APtr, ANewSize);
	call	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_REALLOCMEM$POINTER$QWORD$$POINTER
# Var $result located in register rax
# [195] end;
	popq	%rcx
.Lc18:
	ret
.Lc15:
.Le2:
	.size	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_REALLOCATE$POINTER$QWORD$$POINTER, .Le2 - NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_REALLOCATE$POINTER$QWORD$$POINTER

.section .text.n_nextpas.core.mem.allocator.base$_$tallocator_$__$$_deallocate$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_DEALLOCATE$POINTER
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_DEALLOCATE$POINTER,@function
NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_DEALLOCATE$POINTER:
.Lc20:
# [198] begin
	pushq	%rax
.Lc21:
# Var $self located in register rdi
# Var APtr located in register rsi
# Var APtr located in register rsi
# Var $self located in register rdi
# [199] FreeMem(APtr);
	call	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_FREEMEM$POINTER
# [200] end;
	popq	%rcx
.Lc22:
	ret
.Lc19:
.Le3:
	.size	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_DEALLOCATE$POINTER, .Le3 - NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_DEALLOCATE$POINTER

.section .text.n_nextpas.core.mem.allocator.base$_$tallocator_$__$$_getmem$qword$$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_GETMEM$QWORD$$POINTER
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_GETMEM$QWORD$$POINTER,@function
NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_GETMEM$QWORD$$POINTER:
.Lc24:
# [203] begin
	pushq	%rbx
.Lc25:
# Var $result located in register rbx
	movq	%rdi,%rax
# Var $self located in register rax
# Var aSize located in register rsi
# [204] if aSize = 0 then
	xorl	%ecx,%ecx
	testq	%rsi,%rsi
# [205] Exit(nil);
	cmoveq	%rcx,%rbx
	je	.Lj19
# Var aSize located in register rsi
# Var $self located in register rax
# [206] Result := DoGetMem(aSize);
	movq	%rax,%rdi
	movq	(%rax),%rax
	call	*200(%rax)
	movq	%rax,%rbx
.Lj19:
# [207] end;
	movq	%rbx,%rax
	popq	%rbx
.Lc26:
	ret
.Lc23:
.Le4:
	.size	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_GETMEM$QWORD$$POINTER, .Le4 - NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_GETMEM$QWORD$$POINTER

.section .text.n_nextpas.core.mem.allocator.base$_$tallocator_$__$$_allocmem$qword$$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_ALLOCMEM$QWORD$$POINTER
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_ALLOCMEM$QWORD$$POINTER,@function
NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_ALLOCMEM$QWORD$$POINTER:
.Lc28:
# [210] begin
	pushq	%rbx
.Lc29:
# Var $result located in register rbx
	movq	%rdi,%rax
# Var $self located in register rax
# Var aSize located in register rsi
# [211] if aSize = 0 then
	xorl	%ecx,%ecx
	testq	%rsi,%rsi
# [212] Exit(nil);
	cmoveq	%rcx,%rbx
	je	.Lj23
# Var aSize located in register rsi
# Var $self located in register rax
# [213] Result := DoAllocMem(aSize);
	movq	%rax,%rdi
	movq	(%rax),%rax
	call	*208(%rax)
	movq	%rax,%rbx
.Lj23:
# [214] end;
	movq	%rbx,%rax
	popq	%rbx
.Lc30:
	ret
.Lc27:
.Le5:
	.size	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_ALLOCMEM$QWORD$$POINTER, .Le5 - NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_ALLOCMEM$QWORD$$POINTER

.section .text.n_nextpas.core.mem.allocator.base$_$tallocator_$__$$_reallocmem$pointer$qword$$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_REALLOCMEM$POINTER$QWORD$$POINTER
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_REALLOCMEM$POINTER$QWORD$$POINTER,@function
NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_REALLOCMEM$POINTER$QWORD$$POINTER:
.Lc32:
# [217] begin
	pushq	%rbx
.Lc33:
	pushq	%r12
.Lc34:
	pushq	%r13
.Lc35:
	pushq	%r14
.Lc36:
	pushq	%rax
.Lc37:
# Var $result located in register r14
	movq	%rdi,%rbx
# Var $self located in register rbx
	movq	%rsi,%r12
# Var aDst located in register r12
	movq	%rdx,%r13
# Var aSize located in register r13
# [218] if aSize = 0 then
	testq	%rdx,%rdx
	jne	.Lj30
# [220] if aDst <> nil then
	testq	%r12,%r12
	je	.Lj32
# [221] DoFreeMem(aDst);
	movq	%r12,%rsi
	movq	%rbx,%rdi
	movq	(%rbx),%rax
	call	*224(%rax)
.Lj32:
# [222] Exit(nil);
	xorl	%r14d,%r14d
	jmp	.Lj27
	.p2align 4,,10
	.p2align 3
.Lj30:
# [224] if aDst = nil then
	testq	%r12,%r12
	jne	.Lj34
# [225] Exit(GetMem(aSize));
	movq	%r13,%rsi
	movq	%rbx,%rdi
	call	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_GETMEM$QWORD$$POINTER
	movq	%rax,%r14
	jmp	.Lj27
	.p2align 4,,10
	.p2align 3
.Lj34:
# [226] Result := DoReallocMem(aDst, aSize);
	movq	%r13,%rdx
# Var aSize located in register rdx
	movq	%r12,%rsi
# Var aDst located in register rsi
# Var $self located in register rbx
	movq	%rbx,%rdi
	movq	(%rbx),%rax
	call	*216(%rax)
	movq	%rax,%r14
.Lj27:
# [227] end;
	movq	%r14,%rax
	popq	%rcx
	popq	%r14
.Lc38:
	popq	%r13
.Lc39:
	popq	%r12
.Lc40:
	popq	%rbx
.Lc41:
	ret
.Lc31:
.Le6:
	.size	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_REALLOCMEM$POINTER$QWORD$$POINTER, .Le6 - NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_REALLOCMEM$POINTER$QWORD$$POINTER

.section .text.n_nextpas.core.mem.allocator.base$_$tallocator_$__$$_freemem$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_FREEMEM$POINTER
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_FREEMEM$POINTER,@function
NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_FREEMEM$POINTER:
.Lc43:
# [230] begin
	pushq	%rax
.Lc44:
	movq	%rdi,%rax
# Var $self located in register rax
# Var aDst located in register rsi
# [231] if aDst = nil then
	testq	%rsi,%rsi
	je	.Lj35
# Var aDst located in register rsi
# Var $self located in register rax
# [239] DoFreeMem(aDst);
	movq	%rax,%rdi
	movq	(%rax),%rax
	call	*224(%rax)
.Lj35:
# [240] end;
	popq	%rcx
.Lc45:
	ret
.Lc42:
.Le7:
	.size	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_FREEMEM$POINTER, .Le7 - NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_FREEMEM$POINTER

.section .text.n_nextpas.core.mem.allocator.base$_$tallocator_$__$$_allocaligned$qword$qword$$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_ALLOCALIGNED$QWORD$QWORD$$POINTER
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_ALLOCALIGNED$QWORD$QWORD$$POINTER,@function
NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_ALLOCALIGNED$QWORD$QWORD$$POINTER:
.Lc47:
# Temps allocated between rbp-32 and rbp+0
# [247] begin
	pushq	%rbp
.Lc48:
	movq	%rsp,%rbp
.Lc49:
	leaq	-32(%rsp),%rsp
	movq	%rbx,-32(%rbp)
	movq	%r12,-24(%rbp)
	movq	%r13,-16(%rbp)
	movq	%r14,-8(%rbp)
# Var $result located in register r14
	movq	%rdi,%rbx
# Var $self located in register rbx
	movq	%rsi,%r12
# Var aSize located in register r12
	movq	%rdx,%r13
# Var aAlignment located in register r13
# [248] if aSize = 0 then Exit(nil);
	xorl	%eax,%eax
	testq	%rsi,%rsi
	cmoveq	%rax,%r14
	je	.Lj39
# [249] if (aAlignment < SizeOf(Pointer)) or (not IsPowerOfTwo(aAlignment)) then
	cmpq	$8,%r13
	jb	.Lj49
	testq	%r13,%r13
	je	.Lj49
	leaq	-1(%r13),%rax
	andq	%r13,%rax
	je	.Lj45
.Lj49:
# [250] ContractsRequire(False, 'AllocAligned: alignment must be power of two and >= pointer size');
	movq	$.Ld1,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj49,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj45:
# [252] LNeeded := aSize + aAlignment - 1 + SizeOf(Pointer);
	leaq	7(%r12,%r13),%rsi
# Var LNeeded located in register rsi
# Var LNeeded located in register rsi
# [253] LRaw := GetMem(LNeeded);
	movq	%rbx,%rdi
# Var $self located in register rdi
	call	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_GETMEM$QWORD$$POINTER
# Var LRaw located in register rax
# [254] if LRaw = nil then Exit(nil);
	xorl	%ecx,%ecx
	testq	%rax,%rax
	cmoveq	%rcx,%r14
	je	.Lj39
# [255] Result := AlignUpPtr(Pointer(PtrUInt(LRaw) + SizeOf(Pointer)), aAlignment);
	leaq	-1(%r13),%rcx
	leaq	7(%rax,%r13),%rdx
	notq	%rcx
	andq	%rcx,%rdx
	movq	%rdx,%r14
# [256] LHeaderPtr := PPointer(PtrUInt(Result) - SizeOf(Pointer));
	subq	$8,%rdx
# Var LHeaderPtr located in register rdx
# Var LHeaderPtr located in register rdx
# Var LRaw located in register rax
# [257] LHeaderPtr^ := LRaw;
	movq	%rax,(%rdx)
.Lj39:
# [258] end;
	movq	%r14,%rax
	movq	-32(%rbp),%rbx
	movq	-24(%rbp),%r12
	movq	-16(%rbp),%r13
	movq	-8(%rbp),%r14
.Lc50:
	movq	%rbp,%rsp
.Lc51:
	popq	%rbp
	ret
.Lc46:
.Le8:
	.size	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_ALLOCALIGNED$QWORD$QWORD$$POINTER, .Le8 - NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_ALLOCALIGNED$QWORD$QWORD$$POINTER

.section .text.n_nextpas.core.mem.allocator.base$_$tallocator_$__$$_freealigned$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_FREEALIGNED$POINTER
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_FREEALIGNED$POINTER,@function
NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_FREEALIGNED$POINTER:
.Lc53:
# [264] begin
	pushq	%rax
.Lc54:
# Var $self located in register rdi
# Var aPtr located in register rsi
# [265] if aPtr = nil then Exit;
	testq	%rsi,%rsi
	je	.Lj53
# Var LHeaderPtr located in register rax
# Var LHeaderPtr located in register rax
# Var LRaw located in register rsi
# [267] LRaw := LHeaderPtr^;
	movq	-8(%rsi),%rsi
# Var LRaw located in register rsi
# Var $self located in register rdi
# [268] FreeMem(LRaw);
	call	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_FREEMEM$POINTER
.Lj53:
# [269] end;
	popq	%rcx
.Lc55:
	ret
.Lc52:
.Le9:
	.size	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_FREEALIGNED$POINTER, .Le9 - NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_FREEALIGNED$POINTER

.section .text.n_WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$Hva7u717vhZJ,"ax"
	.balign 16,0x90
.globl	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$Hva7u717vhZJ
	.type	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$Hva7u717vhZJ,@function
WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$Hva7u717vhZJ:
# [1] unit nextpas.core.mem.allocator.base;
	subq	$32,%rdi
	jmp	SYSTEM$_$TINTERFACEDOBJECT_$__$$_QUERYINTERFACE$TGUID$formal$$LONGINT
.Le10:
	.size	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$Hva7u717vhZJ, .Le10 - WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$Hva7u717vhZJ

.section .text.n_WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HUkxhL$6u$HN,"ax"
	.balign 16,0x90
.globl	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HUkxhL$6u$HN
	.type	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HUkxhL$6u$HN,@function
WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HUkxhL$6u$HN:
	subq	$32,%rdi
	jmp	SYSTEM$_$TINTERFACEDOBJECT_$__$$__ADDREF$$LONGINT
.Le11:
	.size	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HUkxhL$6u$HN, .Le11 - WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HUkxhL$6u$HN

.section .text.n_WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$Hq3wIdbG_4sB,"ax"
	.balign 16,0x90
.globl	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$Hq3wIdbG_4sB
	.type	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$Hq3wIdbG_4sB,@function
WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$Hq3wIdbG_4sB:
	subq	$32,%rdi
	jmp	SYSTEM$_$TINTERFACEDOBJECT_$__$$__RELEASE$$LONGINT
.Le12:
	.size	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$Hq3wIdbG_4sB, .Le12 - WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$Hq3wIdbG_4sB

.section .text.n_WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HiXzfGnHPSsD,"ax"
	.balign 16,0x90
.globl	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HiXzfGnHPSsD
	.type	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HiXzfGnHPSsD,@function
WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HiXzfGnHPSsD:
# [187] function TAllocator.Allocate(const ASize: SizeUInt): Pointer;
	subq	$32,%rdi
	jmp	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_ALLOCATE$QWORD$$POINTER
.Le13:
	.size	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HiXzfGnHPSsD, .Le13 - WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HiXzfGnHPSsD

.section .text.n_WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HBcMZEhNPFCJ,"ax"
	.balign 16,0x90
.globl	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HBcMZEhNPFCJ
	.type	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HBcMZEhNPFCJ,@function
WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HBcMZEhNPFCJ:
# [192] function TAllocator.Reallocate(const APtr: Pointer; const ANewSize: SizeUInt): Pointer;
	subq	$32,%rdi
	jmp	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_REALLOCATE$POINTER$QWORD$$POINTER
.Le14:
	.size	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HBcMZEhNPFCJ, .Le14 - WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HBcMZEhNPFCJ

.section .text.n_WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HK2PI4wlkvEC,"ax"
	.balign 16,0x90
.globl	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HK2PI4wlkvEC
	.type	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HK2PI4wlkvEC,@function
WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HK2PI4wlkvEC:
# [197] procedure TAllocator.Deallocate(const APtr: Pointer);
	subq	$32,%rdi
	jmp	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_DEALLOCATE$POINTER
.Le15:
	.size	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HK2PI4wlkvEC, .Le15 - WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HK2PI4wlkvEC

.section .text.n_WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HZiu7WNsVY7J,"ax"
	.balign 16,0x90
.globl	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HZiu7WNsVY7J
	.type	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HZiu7WNsVY7J,@function
WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HZiu7WNsVY7J:
# [202] function TAllocator.GetMem(aSize: SizeUInt): Pointer;
	subq	$32,%rdi
	jmp	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_GETMEM$QWORD$$POINTER
.Le16:
	.size	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HZiu7WNsVY7J, .Le16 - WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HZiu7WNsVY7J

.section .text.n_WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HVWN0CaqBqMB,"ax"
	.balign 16,0x90
.globl	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HVWN0CaqBqMB
	.type	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HVWN0CaqBqMB,@function
WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HVWN0CaqBqMB:
# [209] function TAllocator.AllocMem(aSize: SizeUInt): Pointer;
	subq	$32,%rdi
	jmp	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_ALLOCMEM$QWORD$$POINTER
.Le17:
	.size	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HVWN0CaqBqMB, .Le17 - WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HVWN0CaqBqMB

.section .text.n_WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HuyGFWLKYODC,"ax"
	.balign 16,0x90
.globl	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HuyGFWLKYODC
	.type	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HuyGFWLKYODC,@function
WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HuyGFWLKYODC:
# [216] function TAllocator.ReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
	subq	$32,%rdi
	jmp	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_REALLOCMEM$POINTER$QWORD$$POINTER
.Le18:
	.size	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HuyGFWLKYODC, .Le18 - WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HuyGFWLKYODC

.section .text.n_WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HbOtRxqbkBKC,"ax"
	.balign 16,0x90
.globl	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HbOtRxqbkBKC
	.type	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HbOtRxqbkBKC,@function
WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HbOtRxqbkBKC:
# [229] procedure TAllocator.FreeMem(aDst: Pointer);
	subq	$32,%rdi
	jmp	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_FREEMEM$POINTER
.Le19:
	.size	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HbOtRxqbkBKC, .Le19 - WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HbOtRxqbkBKC

.section .text.n_WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HhidK46oz4tF,"ax"
	.balign 16,0x90
.globl	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HhidK46oz4tF
	.type	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HhidK46oz4tF,@function
WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HhidK46oz4tF:
# [242] function TAllocator.AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
	subq	$32,%rdi
	jmp	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_ALLOCALIGNED$QWORD$QWORD$$POINTER
.Le20:
	.size	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HhidK46oz4tF, .Le20 - WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HhidK46oz4tF

.section .text.n_WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HDy5utj$Iw9N,"ax"
	.balign 16,0x90
.globl	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HDy5utj$Iw9N
	.type	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HDy5utj$Iw9N,@function
WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HDy5utj$Iw9N:
# [260] procedure TAllocator.FreeAligned(aPtr: Pointer);
	subq	$32,%rdi
	jmp	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_FREEALIGNED$POINTER
.Le21:
	.size	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HDy5utj$Iw9N, .Le21 - WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HDy5utj$Iw9N

.section .text.n_WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HwdoiCiJSaHL,"ax"
	.balign 16,0x90
.globl	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HwdoiCiJSaHL
	.type	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HwdoiCiJSaHL,@function
WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HwdoiCiJSaHL:
# [174] function TAllocator.Traits: TAllocatorTraits;
	subq	$32,%rdi
	movq	(%rdi),%rax
	jmp	*232(%rax)
.Le22:
	.size	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HwdoiCiJSaHL, .Le22 - WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HwdoiCiJSaHL

.section .text.n_nextpas.core.mem.allocator.base$_$tallocator_$__$$_dogetmem$qword$$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_DOGETMEM$QWORD$$POINTER
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_DOGETMEM$QWORD$$POINTER,@function
NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_DOGETMEM$QWORD$$POINTER:
.Lc57:
	pushq	%rax
.Lc58:
# Var $self located in register rdi
# Var aSize located in register rsi
	call	FPC_ABSTRACTERROR
	popq	%rcx
.Lc59:
	ret
.Lc56:

.section .text.n_nextpas.core.mem.allocator.base$_$tallocator_$__$$_doallocmem$qword$$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_DOALLOCMEM$QWORD$$POINTER
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_DOALLOCMEM$QWORD$$POINTER,@function
NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_DOALLOCMEM$QWORD$$POINTER:
.Lc61:
	pushq	%rax
.Lc62:
# Var $self located in register rdi
# Var aSize located in register rsi
	call	FPC_ABSTRACTERROR
	popq	%rcx
.Lc63:
	ret
.Lc60:

.section .text.n_nextpas.core.mem.allocator.base$_$tallocator_$__$$_doreallocmem$pointer$qword$$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_DOREALLOCMEM$POINTER$QWORD$$POINTER
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_DOREALLOCMEM$POINTER$QWORD$$POINTER,@function
NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_DOREALLOCMEM$POINTER$QWORD$$POINTER:
.Lc65:
	pushq	%rax
.Lc66:
# Var $self located in register rdi
# Var aDst located in register rsi
# Var aSize located in register rdx
	call	FPC_ABSTRACTERROR
	popq	%rcx
.Lc67:
	ret
.Lc64:

.section .text.n_nextpas.core.mem.allocator.base$_$tallocator_$__$$_dofreemem$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_DOFREEMEM$POINTER
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_DOFREEMEM$POINTER,@function
NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_DOFREEMEM$POINTER:
.Lc69:
	pushq	%rax
.Lc70:
# Var $self located in register rdi
# Var aDst located in register rsi
	call	FPC_ABSTRACTERROR
	popq	%rcx
.Lc71:
	ret
.Lc68:
# End asmlist al_procedures
# Begin asmlist al_globals

.section .rodata.n_IID_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IALLOCATOR
	.balign 8
.globl	IID_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IALLOCATOR
	.type	IID_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IALLOCATOR,@object
IID_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IALLOCATOR:
	.long	485189917
	.short	54584,18642
	.byte	165,196,164,240,161,185,137,40
# [nextpas.core.mem.allocator.base.pas]
# [273] end.
.Le23:
	.size	IID_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IALLOCATOR, .Le23 - IID_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IALLOCATOR

.section .rodata.n_IIDSTR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IALLOCATOR
	.balign 8
.globl	IIDSTR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IALLOCATOR
	.type	IIDSTR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IALLOCATOR,@object
IIDSTR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IALLOCATOR:
	.byte	38
	.ascii	"{1CEB691D-D538-48D2-A5C4-A4F0A1B98928}"
.Le24:
	.size	IIDSTR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IALLOCATOR, .Le24 - IIDSTR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IALLOCATOR

.section .rodata.n_VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR
	.balign 8
.globl	VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR
	.type	VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR,@object
VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR:
	.quad	40,-40
	.quad	VMT_$SYSTEM_$$_TINTERFACEDOBJECT$indirect
	.quad	.Ld2
	.quad	0,0,0
	.quad	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR
	.quad	0,0
	.quad	.Ld4
	.quad	0
	.quad	SYSTEM$_$TINTERFACEDOBJECT_$__$$_DESTROY
	.quad	SYSTEM$_$TINTERFACEDOBJECT_$__$$_NEWINSTANCE$$TOBJECT
	.quad	SYSTEM$_$TOBJECT_$__$$_FREEINSTANCE
	.quad	SYSTEM$_$TOBJECT_$__$$_SAFECALLEXCEPTION$TOBJECT$POINTER$$HRESULT
	.quad	FPC_EMPTYMETHOD
	.quad	SYSTEM$_$TINTERFACEDOBJECT_$__$$_AFTERCONSTRUCTION
	.quad	SYSTEM$_$TINTERFACEDOBJECT_$__$$_BEFOREDESTRUCTION
	.quad	FPC_EMPTYMETHOD
	.quad	SYSTEM$_$TOBJECT_$__$$_DISPATCH$formal
	.quad	SYSTEM$_$TOBJECT_$__$$_DISPATCHSTR$formal
	.quad	SYSTEM$_$TOBJECT_$__$$_EQUALS$TOBJECT$$BOOLEAN
	.quad	SYSTEM$_$TOBJECT_$__$$_GETHASHCODE$$INT64
	.quad	SYSTEM$_$TOBJECT_$__$$_TOSTRING$$ANSISTRING
	.quad	FPC_ABSTRACTERROR
	.quad	FPC_ABSTRACTERROR
	.quad	FPC_ABSTRACTERROR
	.quad	FPC_ABSTRACTERROR
	.quad	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_TRAITS$$TALLOCATORTRAITS
	.quad	0
.Le25:
	.size	VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR, .Le25 - VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR
# End asmlist al_globals
# Begin asmlist al_const

.section .rodata.n_VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR
	.balign 8
.Ld2:
	.byte	10
	.ascii	"TAllocator"
.Le26:
	.size	.Ld2, .Le26 - .Ld2

.section .rodata.n_VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR
	.balign 8
.Ld3:
	.quad	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$Hva7u717vhZJ
	.quad	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HUkxhL$6u$HN
	.quad	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$Hq3wIdbG_4sB
	.quad	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HiXzfGnHPSsD
	.quad	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HBcMZEhNPFCJ
	.quad	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HK2PI4wlkvEC
	.quad	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HZiu7WNsVY7J
	.quad	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HVWN0CaqBqMB
	.quad	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HuyGFWLKYODC
	.quad	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HbOtRxqbkBKC
	.quad	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HhidK46oz4tF
	.quad	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HDy5utj$Iw9N
	.quad	WRPR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR_$_NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IA$HwdoiCiJSaHL
.Le27:
	.size	.Ld3, .Le27 - .Ld3

.section .rodata.n_VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR
	.balign 8
.Ld4:
	.quad	2
	.quad	IID_$NEXTPAS.CORE.MEM.INTF_$$_IALLOCATOR$indirect
	.quad	.Ld3
	.quad	32
	.quad	IIDSTR_$NEXTPAS.CORE.MEM.INTF_$$_IALLOCATOR$indirect
	.long	0
	.byte	0,0,0,0
	.quad	IID_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IALLOCATOR$indirect
	.quad	.Ld3
	.quad	32
	.quad	IIDSTR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IALLOCATOR$indirect
	.long	0
	.byte	0,0,0,0
.Le28:
	.size	.Ld4, .Le28 - .Ld4
# End asmlist al_const
# Begin asmlist al_typedconsts

.section .rodata.n_.Ld1
	.balign 8
.Ld1$strlab:
	.short	0,1
	.long	-1
	.quad	64
.Ld1:
# [250] ContractsRequire(False, 'AllocAligned: alignment must be power of two and >= pointer size');
	.ascii	"AllocAligned: alignment must be power of two and >="
	.ascii	" pointer size\000"
.Le29:
	.size	.Ld1$strlab, .Le29 - .Ld1$strlab
# End asmlist al_typedconsts
# Begin asmlist al_rtti

.section .rodata.n_INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATORTRAITS
	.balign 8
.globl	INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATORTRAITS
	.type	INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATORTRAITS,@object
INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATORTRAITS:
	.byte	13,16
# [274] 
	.ascii	"TAllocatorTraits"
	.quad	0,0
	.long	4
	.quad	0,0
	.long	0
.Le30:
	.size	INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATORTRAITS, .Le30 - INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATORTRAITS

.section .rodata.n_RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATORTRAITS
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATORTRAITS
	.type	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATORTRAITS,@object
RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATORTRAITS:
	.byte	13,16
	.ascii	"TAllocatorTraits"
	.quad	0
	.quad	INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATORTRAITS
	.long	4,4
	.quad	RTTI_$SYSTEM_$$_BOOLEAN$indirect
	.quad	0
	.quad	RTTI_$SYSTEM_$$_BOOLEAN$indirect
	.quad	1
	.quad	RTTI_$SYSTEM_$$_BOOLEAN$indirect
	.quad	2
	.quad	RTTI_$SYSTEM_$$_BOOLEAN$indirect
	.quad	3
	.short	0,0,0
.Le31:
	.size	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATORTRAITS, .Le31 - RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATORTRAITS

.section .rodata.n_RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IALLOCATOR
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IALLOCATOR
	.type	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IALLOCATOR,@object
RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IALLOCATOR:
	.byte	14,10
	.ascii	"IAllocator"
	.quad	0
	.quad	RTTI_$NEXTPAS.CORE.MEM.INTF_$$_IALLOCATOR$indirect
	.byte	1
	.long	485189917
	.short	54584,18642
	.byte	165,196,164,240,161,185,137,40
	.quad	0
	.byte	31
	.ascii	"nextpas.core.mem.allocator.base"
	.short	0,7,65535
.Le32:
	.size	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IALLOCATOR, .Le32 - RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IALLOCATOR

.section .rodata.n_INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR
	.balign 8
.globl	INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR
	.type	INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR,@object
INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR:
	.byte	15,10
	.ascii	"TAllocator"
	.quad	0,0
	.long	8
	.quad	0,0
	.long	0
.Le33:
	.size	INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR, .Le33 - INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR

.section .rodata.n_RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR
	.type	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR,@object
RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR:
	.byte	15,10
	.ascii	"TAllocator"
	.quad	0
	.quad	VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR
	.quad	RTTI_$SYSTEM_$$_TINTERFACEDOBJECT$indirect
	.short	0
	.byte	31
	.ascii	"nextpas.core.mem.allocator.base"
	.short	0,0
.Le34:
	.size	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR, .Le34 - RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR
# End asmlist al_rtti
# Begin asmlist al_indirectglobals

.section .rodata.n_IID_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IALLOCATOR
	.balign 8
.globl	IID_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IALLOCATOR$indirect
	.type	IID_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IALLOCATOR$indirect,@object
IID_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IALLOCATOR$indirect:
	.quad	IID_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IALLOCATOR
# [273] end.
.Le35:
	.size	IID_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IALLOCATOR$indirect, .Le35 - IID_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IALLOCATOR$indirect

.section .rodata.n_IIDSTR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IALLOCATOR
	.balign 8
.globl	IIDSTR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IALLOCATOR$indirect
	.type	IIDSTR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IALLOCATOR$indirect,@object
IIDSTR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IALLOCATOR$indirect:
	.quad	IIDSTR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IALLOCATOR
.Le36:
	.size	IIDSTR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IALLOCATOR$indirect, .Le36 - IIDSTR_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IALLOCATOR$indirect

.section .rodata.n_VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR
	.balign 8
.globl	VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR$indirect
	.type	VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR$indirect,@object
VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR$indirect:
	.quad	VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR
.Le37:
	.size	VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR$indirect, .Le37 - VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR$indirect

.section .rodata.n_INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATORTRAITS
	.balign 8
.globl	INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATORTRAITS$indirect
	.type	INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATORTRAITS$indirect,@object
INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATORTRAITS$indirect:
	.quad	INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATORTRAITS
# [274] 
.Le38:
	.size	INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATORTRAITS$indirect, .Le38 - INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATORTRAITS$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATORTRAITS
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATORTRAITS$indirect
	.type	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATORTRAITS$indirect,@object
RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATORTRAITS$indirect:
	.quad	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATORTRAITS
.Le39:
	.size	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATORTRAITS$indirect, .Le39 - RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATORTRAITS$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IALLOCATOR
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IALLOCATOR$indirect
	.type	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IALLOCATOR$indirect,@object
RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IALLOCATOR$indirect:
	.quad	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IALLOCATOR
.Le40:
	.size	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IALLOCATOR$indirect, .Le40 - RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IALLOCATOR$indirect

.section .rodata.n_INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR
	.balign 8
.globl	INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR$indirect
	.type	INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR$indirect,@object
INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR$indirect:
	.quad	INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR
.Le41:
	.size	INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR$indirect, .Le41 - INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR$indirect
	.type	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR$indirect,@object
RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR$indirect:
	.quad	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR
.Le42:
	.size	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR$indirect, .Le42 - RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR$indirect
# End asmlist al_indirectglobals
# Begin asmlist al_dwarf_frame

.section .debug_frame
.Lc72:
	.long	.Lc74-.Lc73
.Lc73:
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
.Lc74:
	.long	.Lc76-.Lc75
.Lc75:
	.long	.Lc72
	.quad	.Lc2
	.quad	.Lc1-.Lc2
	.byte	4
	.long	.Lc3-.Lc2
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc76:
	.long	.Lc79-.Lc78
.Lc78:
	.long	.Lc72
	.quad	.Lc5
	.quad	.Lc4-.Lc5
	.byte	4
	.long	.Lc6-.Lc5
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc79:
	.long	.Lc82-.Lc81
.Lc81:
	.long	.Lc72
	.quad	.Lc8
	.quad	.Lc7-.Lc8
	.byte	2
	.byte	.Lc9-.Lc8
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc10-.Lc9
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc82:
	.long	.Lc85-.Lc84
.Lc84:
	.long	.Lc72
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
.Lc85:
	.long	.Lc88-.Lc87
.Lc87:
	.long	.Lc72
	.quad	.Lc16
	.quad	.Lc15-.Lc16
	.byte	2
	.byte	.Lc17-.Lc16
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc18-.Lc17
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc88:
	.long	.Lc91-.Lc90
.Lc90:
	.long	.Lc72
	.quad	.Lc20
	.quad	.Lc19-.Lc20
	.byte	2
	.byte	.Lc21-.Lc20
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc22-.Lc21
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc91:
	.long	.Lc94-.Lc93
.Lc93:
	.long	.Lc72
	.quad	.Lc24
	.quad	.Lc23-.Lc24
	.byte	2
	.byte	.Lc25-.Lc24
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc26-.Lc25
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc94:
	.long	.Lc97-.Lc96
.Lc96:
	.long	.Lc72
	.quad	.Lc28
	.quad	.Lc27-.Lc28
	.byte	2
	.byte	.Lc29-.Lc28
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc30-.Lc29
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc97:
	.long	.Lc100-.Lc99
.Lc99:
	.long	.Lc72
	.quad	.Lc32
	.quad	.Lc31-.Lc32
	.byte	2
	.byte	.Lc33-.Lc32
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc34-.Lc33
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc35-.Lc34
	.byte	5
	.uleb128	13
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc36-.Lc35
	.byte	5
	.uleb128	14
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc37-.Lc36
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc38-.Lc37
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc39-.Lc38
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc40-.Lc39
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc41-.Lc40
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc100:
	.long	.Lc103-.Lc102
.Lc102:
	.long	.Lc72
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
.Lc103:
	.long	.Lc106-.Lc105
.Lc105:
	.long	.Lc72
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
.Lc106:
	.long	.Lc109-.Lc108
.Lc108:
	.long	.Lc72
	.quad	.Lc53
	.quad	.Lc52-.Lc53
	.byte	2
	.byte	.Lc54-.Lc53
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc55-.Lc54
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc109:
	.long	.Lc112-.Lc111
.Lc111:
	.long	.Lc72
	.quad	.Lc57
	.quad	.Lc56-.Lc57
	.byte	2
	.byte	.Lc58-.Lc57
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc59-.Lc58
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc112:
	.long	.Lc115-.Lc114
.Lc114:
	.long	.Lc72
	.quad	.Lc61
	.quad	.Lc60-.Lc61
	.byte	2
	.byte	.Lc62-.Lc61
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc63-.Lc62
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc115:
	.long	.Lc118-.Lc117
.Lc117:
	.long	.Lc72
	.quad	.Lc65
	.quad	.Lc64-.Lc65
	.byte	2
	.byte	.Lc66-.Lc65
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc67-.Lc66
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc118:
	.long	.Lc121-.Lc120
.Lc120:
	.long	.Lc72
	.quad	.Lc69
	.quad	.Lc68-.Lc69
	.byte	2
	.byte	.Lc70-.Lc69
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc71-.Lc70
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc121:
# End asmlist al_dwarf_frame
.section .note.GNU-stack,"",%progbits

