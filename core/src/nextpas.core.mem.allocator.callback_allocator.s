	.file "nextpas.core.mem.allocator.callback_allocator.pas"
# Begin asmlist al_procedures

.section .text.n_nextpas.core.mem.allocator.callback_allocator$_$tcallbackallocator_$__$$_init$hckwuv1utt8e,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR$_$TCALLBACKALLOCATOR_$__$$_INIT$hCkwuv1Utt8E
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR$_$TCALLBACKALLOCATOR_$__$$_INIT$hCkwuv1Utt8E,@function
NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR$_$TCALLBACKALLOCATOR_$__$$_INIT$hCkwuv1Utt8E:
.Lc2:
# Temps allocated between rbp-244 and rbp-56
# [nextpas.core.mem.allocator.callback_allocator.pas]
# [48] begin
	pushq	%rbp
.Lc3:
	movq	%rsp,%rbp
.Lc4:
	leaq	-256(%rsp),%rsp
# Var aGetMem located at rbp-8, size=OS_64
# Var aAllocMem located at rbp-16, size=OS_64
# Var aReallocMem located at rbp-24, size=OS_64
# Var aFreeMem located at rbp-32, size=OS_64
# Var $vmt located at rbp-40, size=OS_64
# Var $self located at rbp-48, size=OS_64
# Var $vmt_afterconstruction_local located at rbp-56, size=OS_S64
	movq	%rdi,-48(%rbp)
	movq	%rsi,-40(%rbp)
	movq	%rdx,-8(%rbp)
	movq	%rcx,-16(%rbp)
	movq	%r8,-24(%rbp)
	movq	%r9,-32(%rbp)
	cmpq	$1,-40(%rbp)
	jne	.Lj6
	movq	-48(%rbp),%rdi
	movq	%rdi,%rax
	call	*104(%rdi)
	movq	%rax,-48(%rbp)
.Lj6:
	cmpq	$0,-48(%rbp)
	je	.Lj3
	leaq	-80(%rbp),%rdx
	leaq	-144(%rbp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,-148(%rbp)
	testl	%eax,%eax
	jne	.Lj13
	movq	$-1,-56(%rbp)
# [49] inherited Create;
	xorl	%esi,%esi
	movq	-48(%rbp),%rdi
	call	SYSTEM$_$TOBJECT_$__$$_CREATE$$TOBJECT
# [50] if (aGetMem = nil) or (aAllocMem = nil) or (aReallocMem = nil) or (aFreeMem = nil) then
	cmpq	$0,-8(%rbp)
	seteb	%al
	cmpq	$0,-16(%rbp)
	seteb	%dl
	orb	%dl,%al
	cmpq	$0,-24(%rbp)
	seteb	%dl
	orb	%dl,%al
	cmpq	$0,-32(%rbp)
	seteb	%dl
	orb	%dl,%al
	je	.Lj15
.Lj16:
# [53] raise EArgumentNil.Create('TCallbackAllocator.Create: aGetMem, aAllocMem, aReallocMem, aFreeMem cannot be nil.');
	movq	$.Ld1,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj16,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj15:
# [56] FGetMemCallback     := aGetMem;
	movq	-48(%rbp),%rax
	movq	-8(%rbp),%rdx
	movq	%rdx,40(%rax)
# [57] FAllocMemCallback   := aAllocMem;
	movq	-48(%rbp),%rax
	movq	-16(%rbp),%rdx
	movq	%rdx,48(%rax)
# [58] FReallocMemCallback := aReallocMem;
	movq	-48(%rbp),%rax
	movq	-24(%rbp),%rdx
	movq	%rdx,56(%rax)
# [59] FFreeMemCallback    := aFreeMem;
	movq	-48(%rbp),%rax
	movq	-32(%rbp),%rdx
	movq	%rdx,64(%rax)
# [60] end;
	movq	$1,-56(%rbp)
	cmpq	$0,-48(%rbp)
	setneb	%al
	cmpq	$0,-40(%rbp)
	setneb	%dl
	andb	%dl,%al
	je	.Lj18
	movq	-48(%rbp),%rdi
	movq	(%rdi),%rax
	call	*136(%rax)
.Lj18:
.Lj13:
	call	fpc_popaddrstack
	cmpl	$0,-148(%rbp)
	je	.Lj11
	leaq	-176(%rbp),%rdx
	leaq	-240(%rbp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,-244(%rbp)
	testl	%eax,%eax
	jne	.Lj19
	cmpq	$0,-40(%rbp)
	je	.Lj21
	movq	-56(%rbp),%rsi
	movq	-48(%rbp),%rdi
	movq	(%rdi),%rax
	call	*96(%rax)
.Lj21:
	call	fpc_popaddrstack
	call	fpc_reraise
.Lj19:
	call	fpc_popaddrstack
	cmpl	$0,-244(%rbp)
	je	.Lj22
	call	fpc_raise_nested
.Lj22:
	call	fpc_doneexception
.Lj11:
.Lj3:
	movq	-48(%rbp),%rax
.Lc5:
	movq	%rbp,%rsp
.Lc6:
	popq	%rbp
	ret
.Lc1:
.Le0:
	.size	NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR$_$TCALLBACKALLOCATOR_$__$$_INIT$hCkwuv1Utt8E, .Le0 - NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR$_$TCALLBACKALLOCATOR_$__$$_INIT$hCkwuv1Utt8E

.section .text.n_nextpas.core.mem.allocator.callback_allocator$_$tcallbackallocator_$__$$_dogetmem$qword$$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR$_$TCALLBACKALLOCATOR_$__$$_DOGETMEM$QWORD$$POINTER
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR$_$TCALLBACKALLOCATOR_$__$$_DOGETMEM$QWORD$$POINTER,@function
NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR$_$TCALLBACKALLOCATOR_$__$$_DOGETMEM$QWORD$$POINTER:
.Lc8:
# [63] begin
	pushq	%rax
.Lc9:
	movq	%rdi,%rax
# Var $self located in register rax
	movq	%rsi,%rdi
# Var aSize located in register rdi
# Var aSize located in register rdi
# [64] Result := FGetMemCallback(aSize)
	call	*40(%rax)
# Var $result located in register rax
# [65] end;
	popq	%rcx
.Lc10:
	ret
.Lc7:
.Le1:
	.size	NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR$_$TCALLBACKALLOCATOR_$__$$_DOGETMEM$QWORD$$POINTER, .Le1 - NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR$_$TCALLBACKALLOCATOR_$__$$_DOGETMEM$QWORD$$POINTER

.section .text.n_nextpas.core.mem.allocator.callback_allocator$_$tcallbackallocator_$__$$_doallocmem$qword$$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR$_$TCALLBACKALLOCATOR_$__$$_DOALLOCMEM$QWORD$$POINTER
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR$_$TCALLBACKALLOCATOR_$__$$_DOALLOCMEM$QWORD$$POINTER,@function
NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR$_$TCALLBACKALLOCATOR_$__$$_DOALLOCMEM$QWORD$$POINTER:
.Lc12:
# [68] begin
	pushq	%rax
.Lc13:
	movq	%rdi,%rax
# Var $self located in register rax
	movq	%rsi,%rdi
# Var aSize located in register rdi
# Var aSize located in register rdi
# [69] Result := FAllocMemCallback(aSize)
	call	*48(%rax)
# Var $result located in register rax
# [70] end;
	popq	%rcx
.Lc14:
	ret
.Lc11:
.Le2:
	.size	NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR$_$TCALLBACKALLOCATOR_$__$$_DOALLOCMEM$QWORD$$POINTER, .Le2 - NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR$_$TCALLBACKALLOCATOR_$__$$_DOALLOCMEM$QWORD$$POINTER

.section .text.n_nextpas.core.mem.allocator.callback_allocator$_$tcallbackallocator_$__$$_doreallocmem$hoyivg7vwhml,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR$_$TCALLBACKALLOCATOR_$__$$_DOREALLOCMEM$hOyiVg7vWhmL
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR$_$TCALLBACKALLOCATOR_$__$$_DOREALLOCMEM$hOyiVg7vWhmL,@function
NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR$_$TCALLBACKALLOCATOR_$__$$_DOREALLOCMEM$hOyiVg7vWhmL:
.Lc16:
# [73] begin
	pushq	%rax
.Lc17:
	movq	%rdi,%rax
# Var $self located in register rax
	movq	%rsi,%rdi
# Var aDst located in register rdi
	movq	%rdx,%rsi
# Var aSize located in register rsi
# Var aSize located in register rsi
# Var aDst located in register rdi
# [74] Result := FReallocMemCallback(aDst, aSize)
	call	*56(%rax)
# Var $result located in register rax
# [75] end;
	popq	%rcx
.Lc18:
	ret
.Lc15:
.Le3:
	.size	NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR$_$TCALLBACKALLOCATOR_$__$$_DOREALLOCMEM$hOyiVg7vWhmL, .Le3 - NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR$_$TCALLBACKALLOCATOR_$__$$_DOREALLOCMEM$hOyiVg7vWhmL

.section .text.n_nextpas.core.mem.allocator.callback_allocator$_$tcallbackallocator_$__$$_dofreemem$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR$_$TCALLBACKALLOCATOR_$__$$_DOFREEMEM$POINTER
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR$_$TCALLBACKALLOCATOR_$__$$_DOFREEMEM$POINTER,@function
NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR$_$TCALLBACKALLOCATOR_$__$$_DOFREEMEM$POINTER:
.Lc20:
# [78] begin
	pushq	%rax
.Lc21:
	movq	%rdi,%rax
# Var $self located in register rax
	movq	%rsi,%rdi
# Var aDst located in register rdi
# Var aDst located in register rdi
# [79] FFreeMemCallback(aDst)
	call	*64(%rax)
# [80] end;
	popq	%rcx
.Lc22:
	ret
.Lc19:
.Le4:
	.size	NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR$_$TCALLBACKALLOCATOR_$__$$_DOFREEMEM$POINTER, .Le4 - NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR$_$TCALLBACKALLOCATOR_$__$$_DOFREEMEM$POINTER

.section .text.n_nextpas.core.mem.allocator.callback_allocator_$$_createcallbackallocator$hckwuv1utt8e,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_CREATECALLBACKALLOCATOR$hCkwuv1Utt8E
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_CREATECALLBACKALLOCATOR$hCkwuv1Utt8E,@function
NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_CREATECALLBACKALLOCATOR$hCkwuv1Utt8E:
.Lc24:
# [84] begin
	pushq	%rax
.Lc25:
	movq	%rdi,%rax
# Var aGetMem located in register rax
# Var aAllocMem located in register rsi
	movq	%rdx,%r8
# Var aReallocMem located in register r8
	movq	%rcx,%r9
# Var aFreeMem located in register r9
# [85] Result := TCallbackAllocator.Init(aGetMem, aAllocMem, aReallocMem, aFreeMem);
	movq	$VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR,%rdi
# Var aFreeMem located in register r9
# Var aReallocMem located in register r8
	movq	%rsi,%rcx
# Var aAllocMem located in register rcx
	movq	%rax,%rdx
# Var aGetMem located in register rdx
	movl	$1,%esi
	call	NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR$_$TCALLBACKALLOCATOR_$__$$_INIT$hCkwuv1Utt8E
# Var $result located in register rax
# [86] end;
	popq	%rcx
.Lc26:
	ret
.Lc23:
# End asmlist al_procedures
# Begin asmlist al_globals

.section .rodata.n_VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR
	.balign 8
.globl	VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR
	.type	VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR,@object
VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR:
	.quad	72,-72
	.quad	VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR$indirect
	.quad	.Ld2
	.quad	0,0,0
	.quad	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR
	.quad	0,0
	.quad	.Ld3
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
	.quad	NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR$_$TCALLBACKALLOCATOR_$__$$_DOGETMEM$QWORD$$POINTER
	.quad	NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR$_$TCALLBACKALLOCATOR_$__$$_DOALLOCMEM$QWORD$$POINTER
	.quad	NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR$_$TCALLBACKALLOCATOR_$__$$_DOREALLOCMEM$hOyiVg7vWhmL
	.quad	NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR$_$TCALLBACKALLOCATOR_$__$$_DOFREEMEM$POINTER
	.quad	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_TRAITS$$TALLOCATORTRAITS
	.quad	0
# [88] end.
.Le5:
	.size	VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR, .Le5 - VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR
# End asmlist al_globals
# Begin asmlist al_const

.section .rodata.n_VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR
	.balign 8
.Ld2:
	.byte	18
	.ascii	"TCallbackAllocator"
.Le6:
	.size	.Ld2, .Le6 - .Ld2

.section .rodata.n_VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR
	.balign 8
.Ld3:
	.quad	0
.Le7:
	.size	.Ld3, .Le7 - .Ld3
# End asmlist al_const
# Begin asmlist al_typedconsts

.section .rodata.n_.Ld1
	.balign 8
.Ld1$strlab:
	.short	0,1
	.long	-1
	.quad	83
.Ld1:
# [53] raise EArgumentNil.Create('TCallbackAllocator.Create: aGetMem, aAllocMem, aReallocMem, aFreeMem cannot be nil.');
	.ascii	"TCallbackAllocator.Create: aGetMem, aAllocMem, aRea"
	.ascii	"llocMem, aFreeMem cannot be nil.\000"
.Le8:
	.size	.Ld1$strlab, .Le8 - .Ld1$strlab
# End asmlist al_typedconsts
# Begin asmlist al_rtti

.section .rodata.n_RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TGETMEMCALLBACK
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TGETMEMCALLBACK
	.type	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TGETMEMCALLBACK,@object
RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TGETMEMCALLBACK:
	.byte	23,15
# [89] 
	.ascii	"TGetMemCallback"
	.quad	0
	.byte	0,0
	.quad	RTTI_$SYSTEM_$$_POINTER$indirect
	.byte	1
	.short	0
	.quad	RTTI_$SYSTEM_$$_QWORD$indirect
	.byte	5
	.ascii	"aSize"
.Le9:
	.size	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TGETMEMCALLBACK, .Le9 - RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TGETMEMCALLBACK

.section .rodata.n_RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TALLOCMEMCALLBACK
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TALLOCMEMCALLBACK
	.type	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TALLOCMEMCALLBACK,@object
RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TALLOCMEMCALLBACK:
	.byte	23,17
	.ascii	"TAllocMemCallback"
	.quad	0
	.byte	0,0
	.quad	RTTI_$SYSTEM_$$_POINTER$indirect
	.byte	1
	.short	0
	.quad	RTTI_$SYSTEM_$$_QWORD$indirect
	.byte	5
	.ascii	"aSize"
.Le10:
	.size	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TALLOCMEMCALLBACK, .Le10 - RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TALLOCMEMCALLBACK

.section .rodata.n_RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TREALLOCMEMCALLBACK
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TREALLOCMEMCALLBACK
	.type	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TREALLOCMEMCALLBACK,@object
RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TREALLOCMEMCALLBACK:
	.byte	23,19
	.ascii	"TReallocMemCallback"
	.quad	0
	.byte	0,0
	.quad	RTTI_$SYSTEM_$$_POINTER$indirect
	.byte	2
	.short	0
	.quad	RTTI_$SYSTEM_$$_POINTER$indirect
	.byte	4
	.ascii	"aDst"
	.short	0
	.quad	RTTI_$SYSTEM_$$_QWORD$indirect
	.byte	5
	.ascii	"aSize"
.Le11:
	.size	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TREALLOCMEMCALLBACK, .Le11 - RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TREALLOCMEMCALLBACK

.section .rodata.n_RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TFREEMEMCALLBACK
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TFREEMEMCALLBACK
	.type	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TFREEMEMCALLBACK,@object
RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TFREEMEMCALLBACK:
	.byte	23,16
	.ascii	"TFreeMemCallback"
	.quad	0
	.byte	0,0
	.quad	0
	.byte	1
	.short	0
	.quad	RTTI_$SYSTEM_$$_POINTER$indirect
	.byte	4
	.ascii	"aDst"
.Le12:
	.size	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TFREEMEMCALLBACK, .Le12 - RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TFREEMEMCALLBACK

.section .rodata.n_INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR
	.balign 8
.globl	INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR
	.type	INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR,@object
INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR:
	.byte	15,18
	.ascii	"TCallbackAllocator"
	.quad	0,0
	.long	8
	.quad	0,0
	.long	0
.Le13:
	.size	INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR, .Le13 - INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR

.section .rodata.n_RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR
	.type	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR,@object
RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR:
	.byte	15,18
	.ascii	"TCallbackAllocator"
	.quad	0
	.quad	VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR
	.quad	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR$indirect
	.short	0
	.byte	45
	.ascii	"nextpas.core.mem.allocator.callback_allocator"
	.short	0,0
.Le14:
	.size	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR, .Le14 - RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR
# End asmlist al_rtti
# Begin asmlist al_indirectglobals

.section .rodata.n_VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR
	.balign 8
.globl	VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR$indirect
	.type	VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR$indirect,@object
VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR$indirect:
	.quad	VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR
# [88] end.
.Le15:
	.size	VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR$indirect, .Le15 - VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TGETMEMCALLBACK
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TGETMEMCALLBACK$indirect
	.type	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TGETMEMCALLBACK$indirect,@object
RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TGETMEMCALLBACK$indirect:
	.quad	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TGETMEMCALLBACK
# [89] 
.Le16:
	.size	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TGETMEMCALLBACK$indirect, .Le16 - RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TGETMEMCALLBACK$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TALLOCMEMCALLBACK
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TALLOCMEMCALLBACK$indirect
	.type	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TALLOCMEMCALLBACK$indirect,@object
RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TALLOCMEMCALLBACK$indirect:
	.quad	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TALLOCMEMCALLBACK
.Le17:
	.size	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TALLOCMEMCALLBACK$indirect, .Le17 - RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TALLOCMEMCALLBACK$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TREALLOCMEMCALLBACK
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TREALLOCMEMCALLBACK$indirect
	.type	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TREALLOCMEMCALLBACK$indirect,@object
RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TREALLOCMEMCALLBACK$indirect:
	.quad	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TREALLOCMEMCALLBACK
.Le18:
	.size	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TREALLOCMEMCALLBACK$indirect, .Le18 - RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TREALLOCMEMCALLBACK$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TFREEMEMCALLBACK
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TFREEMEMCALLBACK$indirect
	.type	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TFREEMEMCALLBACK$indirect,@object
RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TFREEMEMCALLBACK$indirect:
	.quad	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TFREEMEMCALLBACK
.Le19:
	.size	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TFREEMEMCALLBACK$indirect, .Le19 - RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TFREEMEMCALLBACK$indirect

.section .rodata.n_INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR
	.balign 8
.globl	INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR$indirect
	.type	INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR$indirect,@object
INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR$indirect:
	.quad	INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR
.Le20:
	.size	INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR$indirect, .Le20 - INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR$indirect
	.type	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR$indirect,@object
RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR$indirect:
	.quad	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR
.Le21:
	.size	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR$indirect, .Le21 - RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_TCALLBACKALLOCATOR$indirect
# End asmlist al_indirectglobals
# Begin asmlist al_dwarf_frame

.section .debug_frame
.Lc27:
	.long	.Lc29-.Lc28
.Lc28:
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
.Lc29:
	.long	.Lc31-.Lc30
.Lc30:
	.long	.Lc27
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
.Lc31:
	.long	.Lc34-.Lc33
.Lc33:
	.long	.Lc27
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
.Lc34:
	.long	.Lc37-.Lc36
.Lc36:
	.long	.Lc27
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
.Lc37:
	.long	.Lc40-.Lc39
.Lc39:
	.long	.Lc27
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
.Lc40:
	.long	.Lc43-.Lc42
.Lc42:
	.long	.Lc27
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
.Lc43:
	.long	.Lc46-.Lc45
.Lc45:
	.long	.Lc27
	.quad	.Lc24
	.quad	.Lc23-.Lc24
	.byte	2
	.byte	.Lc25-.Lc24
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc26-.Lc25
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc46:
# End asmlist al_dwarf_frame
.section .note.GNU-stack,"",%progbits

