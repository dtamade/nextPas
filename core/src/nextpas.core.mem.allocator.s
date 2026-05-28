	.file "nextpas.core.mem.allocator.pas"
# Begin asmlist al_procedures

.section .text.n_nextpas.core.mem.allocator_$$_getrtlallocator$$iallocator,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR_$$_GETRTLALLOCATOR$$IALLOCATOR
	.type	NEXTPAS.CORE.MEM.ALLOCATOR_$$_GETRTLALLOCATOR$$IALLOCATOR,@function
NEXTPAS.CORE.MEM.ALLOCATOR_$$_GETRTLALLOCATOR$$IALLOCATOR:
.Lc2:
# [nextpas.core.mem.allocator.pas]
# [68] begin
	pushq	%rax
.Lc3:
# Var $result located in register rdi
# [69] Result := nextpas.core.mem.allocator.rtl_allocator.GetRtlAllocator;
	call	NEXTPAS.CORE.MEM.ALLOCATOR.RTL_ALLOCATOR_$$_GETRTLALLOCATOR$$IALLOCATOR
# [70] end;
	popq	%rcx
.Lc4:
	ret
.Lc1:

.section .text.n_nextpas.core.mem.allocator_$$_getmimallocallocator$$iallocator,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR_$$_GETMIMALLOCALLOCATOR$$IALLOCATOR
	.type	NEXTPAS.CORE.MEM.ALLOCATOR_$$_GETMIMALLOCALLOCATOR$$IALLOCATOR,@function
NEXTPAS.CORE.MEM.ALLOCATOR_$$_GETMIMALLOCALLOCATOR$$IALLOCATOR:
.Lc6:
# [73] begin
	pushq	%rax
.Lc7:
# Var $result located in register rdi
# [74] Result := nextpas.core.mem.allocator.mimalloc.GetMimallocAllocator;
	call	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_GETMIMALLOCALLOCATOR$$IALLOCATOR
# [75] end;
	popq	%rcx
.Lc8:
	ret
.Lc5:

.section .text.n_nextpas.core.mem.allocator_$$_trygetmimallocallocator$iallocator$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR_$$_TRYGETMIMALLOCALLOCATOR$IALLOCATOR$$BOOLEAN
	.type	NEXTPAS.CORE.MEM.ALLOCATOR_$$_TRYGETMIMALLOCALLOCATOR$IALLOCATOR$$BOOLEAN,@function
NEXTPAS.CORE.MEM.ALLOCATOR_$$_TRYGETMIMALLOCALLOCATOR$IALLOCATOR$$BOOLEAN:
.Lc10:
# [78] begin
	pushq	%rbx
.Lc11:
	movq	%rdi,%rbx
# Var A located in register rbx
	movq	$0,(%rdi)
# [79] Result := nextpas.core.mem.allocator.mimalloc.TryGetMimallocAllocator(A);
	call	fpc_intf_decr_ref
	movq	%rbx,%rdi
	call	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TRYGETMIMALLOCALLOCATOR$IALLOCATOR$$BOOLEAN
# Var $result located in register al
# [80] end;
	popq	%rbx
.Lc12:
	ret
.Lc9:

.section .text.n_nextpas.core.mem.allocator_$$_createcallbackallocator$hckwuv1utt8e,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR_$$_CREATECALLBACKALLOCATOR$hCkwuv1Utt8E
	.type	NEXTPAS.CORE.MEM.ALLOCATOR_$$_CREATECALLBACKALLOCATOR$hCkwuv1Utt8E,@function
NEXTPAS.CORE.MEM.ALLOCATOR_$$_CREATECALLBACKALLOCATOR$hCkwuv1Utt8E:
.Lc14:
# [92] begin
	pushq	%rax
.Lc15:
# Var aGetMem located in register rdi
# Var aAllocMem located in register rsi
# Var aReallocMem located in register rdx
# Var aFreeMem located in register rcx
# Var aFreeMem located in register rcx
# Var aReallocMem located in register rdx
# Var aAllocMem located in register rsi
# Var aGetMem located in register rdi
# [93] Result := nextpas.core.mem.allocator.callback_allocator.CreateCallbackAllocator(aGetMem, aAllocMem, aReallocMem, aFreeMem);
	call	NEXTPAS.CORE.MEM.ALLOCATOR.CALLBACK_ALLOCATOR_$$_CREATECALLBACKALLOCATOR$hCkwuv1Utt8E
# Var $result located in register rax
# [94] end;
	popq	%rcx
.Lc16:
	ret
.Lc13:
# End asmlist al_procedures
# Begin asmlist al_dwarf_frame

.section .debug_frame
.Lc17:
	.long	.Lc19-.Lc18
.Lc18:
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
.Lc19:
	.long	.Lc21-.Lc20
.Lc20:
	.long	.Lc17
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
.Lc21:
	.long	.Lc24-.Lc23
.Lc23:
	.long	.Lc17
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
.Lc24:
	.long	.Lc27-.Lc26
.Lc26:
	.long	.Lc17
	.quad	.Lc10
	.quad	.Lc9-.Lc10
	.byte	2
	.byte	.Lc11-.Lc10
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc12-.Lc11
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc27:
	.long	.Lc30-.Lc29
.Lc29:
	.long	.Lc17
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
.Lc30:
# End asmlist al_dwarf_frame
.section .note.GNU-stack,"",%progbits

