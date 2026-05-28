	.file "nextpas.core.mem.allocator.rtl_allocator.pas"
# Begin asmlist al_procedures

.section .text.n_nextpas.core.mem.allocator.rtl_allocator$_$trtlallocator_$__$$_dogetmem$qword$$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR$_$TRTLALLOCATOR_$__$$_DOGETMEM$QWORD$$POINTER
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR$_$TRTLALLOCATOR_$__$$_DOGETMEM$QWORD$$POINTER,@function
NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR$_$TRTLALLOCATOR_$__$$_DOGETMEM$QWORD$$POINTER:
.Lc2:
# [nextpas.core.mem.allocator.rtl_allocator.pas]
# [37] begin
	pushq	%rax
.Lc3:
# Var $self located in register rdi
	movq	%rsi,%rdi
# Var aSize located in register rdi
# Var aSize located in register rdi
# [38] Result := System.GetMem(aSize);
	call	*TC_$SYSTEM_$$_MEMORYMANAGER+8
# Var $result located in register rax
# [39] end;
	popq	%rcx
.Lc4:
	ret
.Lc1:
.Le0:
	.size	NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR$_$TRTLALLOCATOR_$__$$_DOGETMEM$QWORD$$POINTER, .Le0 - NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR$_$TRTLALLOCATOR_$__$$_DOGETMEM$QWORD$$POINTER

.section .text.n_nextpas.core.mem.allocator.rtl_allocator$_$trtlallocator_$__$$_doallocmem$qword$$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR$_$TRTLALLOCATOR_$__$$_DOALLOCMEM$QWORD$$POINTER
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR$_$TRTLALLOCATOR_$__$$_DOALLOCMEM$QWORD$$POINTER,@function
NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR$_$TRTLALLOCATOR_$__$$_DOALLOCMEM$QWORD$$POINTER:
.Lc6:
# [42] begin
	pushq	%rax
.Lc7:
# Var $self located in register rdi
	movq	%rsi,%rdi
# Var aSize located in register rdi
# Var aSize located in register rdi
# [43] Result := System.AllocMem(aSize);
	call	SYSTEM_$$_ALLOCMEM$QWORD$$POINTER
# Var $result located in register rax
# [44] end;
	popq	%rcx
.Lc8:
	ret
.Lc5:
.Le1:
	.size	NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR$_$TRTLALLOCATOR_$__$$_DOALLOCMEM$QWORD$$POINTER, .Le1 - NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR$_$TRTLALLOCATOR_$__$$_DOALLOCMEM$QWORD$$POINTER

.section .text.n_nextpas.core.mem.allocator.rtl_allocator$_$trtlallocator_$__$$_doreallocmem$pointer$qword$$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR$_$TRTLALLOCATOR_$__$$_DOREALLOCMEM$POINTER$QWORD$$POINTER
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR$_$TRTLALLOCATOR_$__$$_DOREALLOCMEM$POINTER$QWORD$$POINTER,@function
NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR$_$TRTLALLOCATOR_$__$$_DOREALLOCMEM$POINTER$QWORD$$POINTER:
.Lc10:
# [47] begin
	pushq	%rax
.Lc11:
# Var aDst located at rsp+0, size=OS_64
# Var $self located in register rdi
	movq	%rsi,(%rsp)
	movq	%rdx,%rsi
# Var aSize located in register rsi
# [48] Result := System.ReallocMem(aDst, aSize);
	movq	%rsp,%rdi
# Var aSize located in register rsi
	call	*TC_$SYSTEM_$$_MEMORYMANAGER+40
# Var $result located in register rax
# [49] end;
	popq	%rcx
.Lc12:
	ret
.Lc9:
.Le2:
	.size	NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR$_$TRTLALLOCATOR_$__$$_DOREALLOCMEM$POINTER$QWORD$$POINTER, .Le2 - NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR$_$TRTLALLOCATOR_$__$$_DOREALLOCMEM$POINTER$QWORD$$POINTER

.section .text.n_nextpas.core.mem.allocator.rtl_allocator$_$trtlallocator_$__$$_dofreemem$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR$_$TRTLALLOCATOR_$__$$_DOFREEMEM$POINTER
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR$_$TRTLALLOCATOR_$__$$_DOFREEMEM$POINTER,@function
NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR$_$TRTLALLOCATOR_$__$$_DOFREEMEM$POINTER:
.Lc14:
# [52] begin
	pushq	%rax
.Lc15:
# Var $self located in register rdi
	movq	%rsi,%rdi
# Var aDst located in register rdi
# Var aDst located in register rdi
# [53] System.FreeMem(aDst);
	call	*TC_$SYSTEM_$$_MEMORYMANAGER+16
# [54] end;
	popq	%rcx
.Lc16:
	ret
.Lc13:
.Le3:
	.size	NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR$_$TRTLALLOCATOR_$__$$_DOFREEMEM$POINTER, .Le3 - NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR$_$TRTLALLOCATOR_$__$$_DOFREEMEM$POINTER

.section .text.n_nextpas.core.mem.allocator.rtl_allocator$_$trtlallocator_$__$$_traits$$tallocatortraits,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR$_$TRTLALLOCATOR_$__$$_TRAITS$$TALLOCATORTRAITS
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR$_$TRTLALLOCATOR_$__$$_TRAITS$$TALLOCATORTRAITS,@function
NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR$_$TRTLALLOCATOR_$__$$_TRAITS$$TALLOCATORTRAITS:
.Lc18:
# [57] begin
	pushq	%rax
.Lc19:
# Var $result located at rsp+0, size=OS_32
# Var $self located in register rdi
# Var $self located in register rdi
# [58] Result := inherited Traits;
	call	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_TRAITS$$TALLOCATORTRAITS
	movl	%eax,(%rsp)
# [63] Result.ZeroInitialized := True;
	movb	$1,(%rsp)
# [64] Result.SupportsAligned := False;
	movb	$0,3(%rsp)
# [65] Result.HasMemSize      := False;
	movb	$0,2(%rsp)
# [66] end;
	movl	(%rsp),%eax
	popq	%rcx
.Lc20:
	ret
.Lc17:
.Le4:
	.size	NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR$_$TRTLALLOCATOR_$__$$_TRAITS$$TALLOCATORTRAITS, .Le4 - NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR$_$TRTLALLOCATOR_$__$$_TRAITS$$TALLOCATORTRAITS

.section .text.n_nextpas.core.mem.allocator.rtl_allocator_$$_getrtlallocator$$iallocator,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_GETRTLALLOCATOR$$IALLOCATOR
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_GETRTLALLOCATOR$$IALLOCATOR,@function
NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_GETRTLALLOCATOR$$IALLOCATOR:
.Lc22:
# Temps allocated between rsp+8 and rsp+208
# [69] begin
	leaq	-216(%rsp),%rsp
.Lc23:
# Var $result located at rsp+0, size=OS_64
	movq	%rdi,(%rsp)
	movq	$0,200(%rsp)
	leaq	8(%rsp),%rdx
	leaq	32(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,96(%rsp)
	testl	%eax,%eax
	jne	.Lj16
# [70] if _RTLAllocatorObj = nil then
	cmpq	$0,TC_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$__RTLALLOCATOROBJ
	jne	.Lj19
# [72] EnterCriticalSection(GRtlAllocLock);
	movq	$U_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_GRTLALLOCLOCK,%rdi
	call	SYSTEM_$$_ENTERCRITICALSECTION$TRTLCRITICALSECTION
# [73] try
	leaq	104(%rsp),%rdx
	leaq	128(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,192(%rsp)
	testl	%eax,%eax
	jne	.Lj21
# [74] if _RTLAllocatorObj = nil then
	cmpq	$0,TC_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$__RTLALLOCATOROBJ
	jne	.Lj24
# [76] _RTLAllocatorObj := TRtlAllocator.Create;
	movq	$VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR,%rdi
	movl	$1,%esi
	call	SYSTEM$_$TOBJECT_$__$$_CREATE$$TOBJECT
	movq	%rax,TC_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$__RTLALLOCATOROBJ
# [77] _RTLAllocatorIntf := _RTLAllocatorObj as IAllocator; // anchor lifetime via interface
	movq	.Ld1,%rdx
	movq	.Ld1+8,%rcx
	movq	TC_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$__RTLALLOCATOROBJ,%rsi
	leaq	200(%rsp),%rdi
	call	fpc_class_as_intf
	movq	200(%rsp),%rsi
	movq	$TC_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$__RTLALLOCATORINTF,%rdi
	call	fpc_intf_assign
.Lj24:
.Lj21:
	call	fpc_popaddrstack
# [80] LeaveCriticalSection(GRtlAllocLock);
	movq	$U_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_GRTLALLOCLOCK,%rdi
	call	SYSTEM_$$_LEAVECRITICALSECTION$TRTLCRITICALSECTION
	cmpl	$0,192(%rsp)
	je	.Lj20
	call	fpc_reraise
.Lj20:
.Lj19:
# [83] Result := _RTLAllocatorIntf;
	movq	TC_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$__RTLALLOCATORINTF,%rsi
	movq	(%rsp),%rdi
	call	fpc_intf_assign
.Lj16:
	call	fpc_popaddrstack
# [84] end;
	leaq	200(%rsp),%rdi
	call	fpc_intf_decr_ref
	cmpl	$0,96(%rsp)
	je	.Lj15
	call	fpc_reraise
	movl	$0,96(%rsp)
	jmp	.Lj16
.Lj15:
	leaq	216(%rsp),%rsp
.Lc24:
	ret
.Lc21:
.Le5:
	.size	NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_GETRTLALLOCATOR$$IALLOCATOR, .Le5 - NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_GETRTLALLOCATOR$$IALLOCATOR

.section .text.n_nextpas.core.mem.allocator.rtl_allocator_$$_trygetrtlallocator$iallocator$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRYGETRTLALLOCATOR$IALLOCATOR$$BOOLEAN
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRYGETRTLALLOCATOR$IALLOCATOR$$BOOLEAN,@function
NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRYGETRTLALLOCATOR$IALLOCATOR$$BOOLEAN:
.Lc26:
# Temps allocated between rsp+12 and rsp+308
# [87] begin
	leaq	-312(%rsp),%rsp
.Lc27:
# Var A located at rsp+0, size=OS_64
# Var $result located at rsp+8, size=OS_8
	movq	%rdi,(%rsp)
	movq	$0,(%rdi)
	movq	$0,208(%rsp)
	leaq	16(%rsp),%rdx
	leaq	40(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,104(%rsp)
	testl	%eax,%eax
	jne	.Lj28
# [88] try
	leaq	112(%rsp),%rdx
	leaq	136(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,200(%rsp)
	testl	%eax,%eax
	jne	.Lj34
# [89] A := GetRtlAllocator;
	leaq	208(%rsp),%rdi
	call	NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_GETRTLALLOCATOR$$IALLOCATOR
	movq	208(%rsp),%rsi
	movq	(%rsp),%rdi
	call	fpc_intf_assign
# [90] Result := True;
	movb	$1,8(%rsp)
.Lj34:
	call	fpc_popaddrstack
	cmpl	$0,200(%rsp)
	je	.Lj32
	leaq	216(%rsp),%rdx
	leaq	240(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,304(%rsp)
	testl	%eax,%eax
	jne	.Lj35
# [92] A := nil;
	movq	(%rsp),%rdi
	xorl	%esi,%esi
	call	fpc_intf_assign
# [93] Result := False;
	movb	$0,8(%rsp)
.Lj35:
	call	fpc_popaddrstack
	cmpl	$0,304(%rsp)
	je	.Lj36
	call	fpc_raise_nested
.Lj36:
	call	fpc_doneexception
.Lj32:
.Lj28:
	call	fpc_popaddrstack
# [95] end;
	leaq	208(%rsp),%rdi
	call	fpc_intf_decr_ref
	cmpl	$0,104(%rsp)
	je	.Lj27
	call	fpc_reraise
	movl	$0,104(%rsp)
	jmp	.Lj28
.Lj27:
	movb	8(%rsp),%al
	leaq	312(%rsp),%rsp
.Lc28:
	ret
.Lc25:

.section .text.n_nextpas.core.mem.allocator.rtl_allocator_$$_init$,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_init$
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_init$,@function
NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_init$:
.globl	INIT$_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR
	.type	INIT$_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR,@function
INIT$_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR:
.Lc30:
# [97] initialization
	pushq	%rax
.Lc31:
# [98] InitCriticalSection(GRtlAllocLock);
	movq	$U_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_GRTLALLOCLOCK,%rdi
	call	SYSTEM_$$_INITCRITICALSECTION$TRTLCRITICALSECTION
# [95] end;
	popq	%rcx
.Lc32:
	ret
.Lc29:

.section .text.n_nextpas.core.mem.allocator.rtl_allocator_$$_finalize$,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_finalize$
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_finalize$,@function
NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_finalize$:
.globl	FINALIZE$_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR
	.type	FINALIZE$_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR,@function
FINALIZE$_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR:
.Lc34:
# [99] finalization
	pushq	%rax
.Lc35:
# [100] DoneCriticalSection(GRtlAllocLock);
	movq	$U_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_GRTLALLOCLOCK,%rdi
	call	SYSTEM_$$_DONECRITICALSECTION$TRTLCRITICALSECTION
# [101] _RTLAllocatorIntf := nil; // release anchor; object will be freed by interface refcount
	movq	$TC_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$__RTLALLOCATORINTF,%rdi
	xorl	%esi,%esi
	call	fpc_intf_assign
# [102] _RTLAllocatorObj := nil;
	movq	$0,TC_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$__RTLALLOCATOROBJ
# [104] end.
	movq	$TC_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$__RTLALLOCATORINTF,%rdi
	call	fpc_intf_decr_ref
	popq	%rcx
.Lc36:
	ret
.Lc33:
# End asmlist al_procedures
# Begin asmlist al_globals

.section .bss,"aw",%nobits
	.balign 8
# [34] GRtlAllocLock: TRTLCriticalSection;
	.hidden U_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_GRTLALLOCLOCK
	.globl U_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_GRTLALLOCLOCK
	.type U_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_GRTLALLOCLOCK,@object
	.size U_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_GRTLALLOCLOCK,40
U_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_GRTLALLOCLOCK:
	.zero 40

.section .rodata.n_VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR
	.balign 8
.globl	VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR
	.type	VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR,@object
VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR:
	.quad	40,-40
	.quad	VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR$indirect
	.quad	.Ld2
	.quad	0,0,0
	.quad	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR
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
	.quad	NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR$_$TRTLALLOCATOR_$__$$_DOGETMEM$QWORD$$POINTER
	.quad	NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR$_$TRTLALLOCATOR_$__$$_DOALLOCMEM$QWORD$$POINTER
	.quad	NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR$_$TRTLALLOCATOR_$__$$_DOREALLOCMEM$POINTER$QWORD$$POINTER
	.quad	NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR$_$TRTLALLOCATOR_$__$$_DOFREEMEM$POINTER
	.quad	NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR$_$TRTLALLOCATOR_$__$$_TRAITS$$TALLOCATORTRAITS
	.quad	0
# [104] end.
.Le6:
	.size	VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR, .Le6 - VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR
# End asmlist al_globals
# Begin asmlist al_const

.section .rodata.n_VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR
	.balign 8
.Ld2:
	.byte	13
	.ascii	"TRtlAllocator"
.Le7:
	.size	.Ld2, .Le7 - .Ld2

.section .rodata.n_VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR
	.balign 8
.Ld3:
	.quad	0
.Le8:
	.size	.Ld3, .Le8 - .Ld3
# End asmlist al_const
# Begin asmlist al_typedconsts

.section .data.n_TC_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$__RTLALLOCATOROBJ
	.balign 8
.globl	TC_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$__RTLALLOCATOROBJ
	.hidden TC_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$__RTLALLOCATOROBJ
	.type	TC_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$__RTLALLOCATOROBJ,@object
TC_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$__RTLALLOCATOROBJ:
	.quad	0
# [33] _RTLAllocatorIntf: IAllocator = nil;
.Le9:
	.size	TC_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$__RTLALLOCATOROBJ, .Le9 - TC_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$__RTLALLOCATOROBJ

.section .data.n_TC_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$__RTLALLOCATORINTF
	.balign 8
.globl	TC_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$__RTLALLOCATORINTF
	.hidden TC_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$__RTLALLOCATORINTF
	.type	TC_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$__RTLALLOCATORINTF,@object
TC_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$__RTLALLOCATORINTF:
	.quad	0
# [34] GRtlAllocLock: TRTLCriticalSection;
.Le10:
	.size	TC_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$__RTLALLOCATORINTF, .Le10 - TC_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$__RTLALLOCATORINTF

.section .rodata.n_.Ld1
	.balign 16
.Ld1:
	.long	485189917
	.short	54584,18642
	.byte	165,196,164,240,161,185,137,40
# [77] _RTLAllocatorIntf := _RTLAllocatorObj as IAllocator; // anchor lifetime via interface
.Le11:
	.size	.Ld1, .Le11 - .Ld1
# End asmlist al_typedconsts
# Begin asmlist al_rtti

.section .rodata.n_INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR
	.balign 8
.globl	INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR
	.type	INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR,@object
INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR:
	.byte	15,13
# [105] 
	.ascii	"TRtlAllocator"
	.quad	0,0
	.long	8
	.quad	0,0
	.long	0
.Le12:
	.size	INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR, .Le12 - INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR

.section .rodata.n_RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR
	.type	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR,@object
RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR:
	.byte	15,13
	.ascii	"TRtlAllocator"
	.quad	0
	.quad	VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR
	.quad	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR$indirect
	.short	0
	.byte	40
	.ascii	"nextpas.core.mem.allocator.rtl_allocator"
	.short	0,0
.Le13:
	.size	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR, .Le13 - RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR
# End asmlist al_rtti
# Begin asmlist al_indirectglobals

.section .rodata.n_VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR
	.balign 8
.globl	VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR$indirect
	.type	VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR$indirect,@object
VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR$indirect:
	.quad	VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR
# [104] end.
.Le14:
	.size	VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR$indirect, .Le14 - VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR$indirect

.section .rodata.n_INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR
	.balign 8
.globl	INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR$indirect
	.type	INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR$indirect,@object
INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR$indirect:
	.quad	INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR
# [105] 
.Le15:
	.size	INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR$indirect, .Le15 - INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR$indirect
	.type	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR$indirect,@object
RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR$indirect:
	.quad	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR
.Le16:
	.size	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR$indirect, .Le16 - RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_TRTLALLOCATOR$indirect
# End asmlist al_indirectglobals
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
	.byte	2
	.byte	.Lc3-.Lc2
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc4-.Lc3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc41:
	.long	.Lc44-.Lc43
.Lc43:
	.long	.Lc37
	.quad	.Lc6
	.quad	.Lc5-.Lc6
	.byte	2
	.byte	.Lc7-.Lc6
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc8-.Lc7
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc44:
	.long	.Lc47-.Lc46
.Lc46:
	.long	.Lc37
	.quad	.Lc10
	.quad	.Lc9-.Lc10
	.byte	2
	.byte	.Lc11-.Lc10
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc12-.Lc11
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc47:
	.long	.Lc50-.Lc49
.Lc49:
	.long	.Lc37
	.quad	.Lc14
	.quad	.Lc13-.Lc14
	.byte	2
	.byte	.Lc15-.Lc14
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc16-.Lc15
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc50:
	.long	.Lc53-.Lc52
.Lc52:
	.long	.Lc37
	.quad	.Lc18
	.quad	.Lc17-.Lc18
	.byte	2
	.byte	.Lc19-.Lc18
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc20-.Lc19
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc53:
	.long	.Lc56-.Lc55
.Lc55:
	.long	.Lc37
	.quad	.Lc22
	.quad	.Lc21-.Lc22
	.byte	2
	.byte	.Lc23-.Lc22
	.byte	14
	.uleb128	224
	.byte	4
	.long	.Lc24-.Lc23
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc56:
	.long	.Lc59-.Lc58
.Lc58:
	.long	.Lc37
	.quad	.Lc26
	.quad	.Lc25-.Lc26
	.byte	2
	.byte	.Lc27-.Lc26
	.byte	14
	.uleb128	320
	.byte	4
	.long	.Lc28-.Lc27
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc59:
	.long	.Lc62-.Lc61
.Lc61:
	.long	.Lc37
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
.Lc62:
	.long	.Lc65-.Lc64
.Lc64:
	.long	.Lc37
	.quad	.Lc34
	.quad	.Lc33-.Lc34
	.byte	2
	.byte	.Lc35-.Lc34
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc36-.Lc35
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc65:
# End asmlist al_dwarf_frame
.section .note.GNU-stack,"",%progbits

