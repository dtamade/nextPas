	.file "nextpas.core.atomic.core.pas"
# Begin asmlist al_procedures

.section .text.n_nextpas.core.atomic.core_$$_cpu_pause,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.CORE_$$_CPU_PAUSE
	.type	NEXTPAS.CORE.ATOMIC.CORE_$$_CPU_PAUSE,@function
NEXTPAS.CORE.ATOMIC.CORE_$$_CPU_PAUSE:
.Lc2:
# [nextpas.core.atomic.core.pas]
# [73] begin
	pushq	%rbp
.Lc3:
	movq	%rsp,%rbp
.Lc4:
#  CPU X86-64-V1
# [76] pause
	pause
#  CPU X86-64-V1
.Lc5:
# [92] end;
	movq	%rbp,%rsp
.Lc6:
	popq	%rbp
	ret
.Lc1:

.section .text.n_nextpas.core.atomic.core_$$_atomic_thread_fence$memory_order_t,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.CORE_$$_ATOMIC_THREAD_FENCE$MEMORY_ORDER_T
	.type	NEXTPAS.CORE.ATOMIC.CORE_$$_ATOMIC_THREAD_FENCE$MEMORY_ORDER_T,@function
NEXTPAS.CORE.ATOMIC.CORE_$$_ATOMIC_THREAD_FENCE$MEMORY_ORDER_T:
.Lc8:
# [95] begin
	pushq	%rax
.Lc9:
# Var aOrder located in register edi
# [96] case aOrder of
	testl	%edi,%edi
	je	.Lj7
	subl	$1,%edi
	je	.Lj8
	subl	$1,%edi
	je	.Lj9
	subl	$1,%edi
	je	.Lj10
	subl	$1,%edi
	je	.Lj11
	subl	$1,%edi
	je	.Lj12
	jmp	.Lj7
	.balign 16,0x90
.Lj8:
# [98] mo_consume: ReadBarrier;
	call	SYSTEM_$$_READBARRIER
	jmp	.Lj7
	.balign 16,0x90
.Lj9:
# [99] mo_acquire: ReadBarrier;
	call	SYSTEM_$$_READBARRIER
	jmp	.Lj7
	.balign 16,0x90
.Lj10:
# [100] mo_release: WriteBarrier;
	call	SYSTEM_$$_WRITEBARRIER
	jmp	.Lj7
	.balign 16,0x90
.Lj11:
# [101] mo_acq_rel: ReadWriteBarrier;
	call	SYSTEM_$$_READWRITEBARRIER
	jmp	.Lj7
	.balign 16,0x90
.Lj12:
# [102] mo_seq_cst: ReadWriteBarrier;
	call	SYSTEM_$$_READWRITEBARRIER
	.balign 16,0x90
.Lj7:
# [104] end;
	popq	%rcx
.Lc10:
	ret
.Lc7:

.section .text.n_nextpas.core.atomic.core_$$_atomic_signal_fence$memory_order_t,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.CORE_$$_ATOMIC_SIGNAL_FENCE$MEMORY_ORDER_T
	.type	NEXTPAS.CORE.ATOMIC.CORE_$$_ATOMIC_SIGNAL_FENCE$MEMORY_ORDER_T,@function
NEXTPAS.CORE.ATOMIC.CORE_$$_ATOMIC_SIGNAL_FENCE$MEMORY_ORDER_T:
.Lc12:
# [107] begin
	pushq	%rax
.Lc13:
# Var aOrder located in register edi
# [108] case aOrder of
	testl	%edi,%edi
	je	.Lj15
	subl	$1,%edi
	je	.Lj16
	subl	$1,%edi
	je	.Lj17
	subl	$1,%edi
	je	.Lj18
	subl	$1,%edi
	je	.Lj19
	subl	$1,%edi
	je	.Lj20
	jmp	.Lj15
	.balign 16,0x90
.Lj16:
# [110] mo_consume: ReadWriteBarrier;
	call	SYSTEM_$$_READWRITEBARRIER
	jmp	.Lj15
	.balign 16,0x90
.Lj17:
# [111] mo_acquire: ReadWriteBarrier;
	call	SYSTEM_$$_READWRITEBARRIER
	jmp	.Lj15
	.balign 16,0x90
.Lj18:
# [112] mo_release: ReadWriteBarrier;
	call	SYSTEM_$$_READWRITEBARRIER
	jmp	.Lj15
	.balign 16,0x90
.Lj19:
# [113] mo_acq_rel: ReadWriteBarrier;
	call	SYSTEM_$$_READWRITEBARRIER
	jmp	.Lj15
	.balign 16,0x90
.Lj20:
# [114] mo_seq_cst: ReadWriteBarrier;
	call	SYSTEM_$$_READWRITEBARRIER
	.balign 16,0x90
.Lj15:
# [116] end;
	popq	%rcx
.Lc14:
	ret
.Lc11:

.section .text.n_nextpas.core.atomic.core_$$_atomic_tagged_ptr$pointer$word$$atomic_tagged_ptr_t,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.CORE_$$_ATOMIC_TAGGED_PTR$POINTER$WORD$$ATOMIC_TAGGED_PTR_T
	.type	NEXTPAS.CORE.ATOMIC.CORE_$$_ATOMIC_TAGGED_PTR$POINTER$WORD$$ATOMIC_TAGGED_PTR_T,@function
NEXTPAS.CORE.ATOMIC.CORE_$$_ATOMIC_TAGGED_PTR$POINTER$WORD$$ATOMIC_TAGGED_PTR_T:
.Lc16:
# Var aPtr located in register rdi
# Var aTag located in register si
# [119] begin
# [132] Result := (PtrUInt(aPtr) and PTR_MASK) or (PtrUInt(aTag) shl TAG_SHIFT);
	movq	TC_$NEXTPAS.CORE.ATOMIC.CORE_$$_PTR_MASK,%rax
	andq	%rdi,%rax
	movzwl	%si,%esi
	shlq	$48,%rsi
	orq	%rsi,%rax
# Var $result located in register rax
.Lc17:
# [137] end;
	ret
.Lc15:

.section .text.n_nextpas.core.atomic.core_$$_atomic_tagged_ptr_get_ptr$atomic_tagged_ptr_t$$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.CORE_$$_ATOMIC_TAGGED_PTR_GET_PTR$ATOMIC_TAGGED_PTR_T$$POINTER
	.type	NEXTPAS.CORE.ATOMIC.CORE_$$_ATOMIC_TAGGED_PTR_GET_PTR$ATOMIC_TAGGED_PTR_T$$POINTER,@function
NEXTPAS.CORE.ATOMIC.CORE_$$_ATOMIC_TAGGED_PTR_GET_PTR$ATOMIC_TAGGED_PTR_T$$POINTER:
.Lc19:
# Var aTaggedPtr located in register rdi
# [140] begin
# [143] Result := Pointer(PtrUInt(aTaggedPtr) and PTR_MASK);
	movq	TC_$NEXTPAS.CORE.ATOMIC.CORE_$$_PTR_MASK,%rax
	andq	%rdi,%rax
# Var $result located in register rax
.Lc20:
# [145] end;
	ret
.Lc18:

.section .text.n_nextpas.core.atomic.core_$$_atomic_tagged_ptr_get_tag$atomic_tagged_ptr_t$$word,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.CORE_$$_ATOMIC_TAGGED_PTR_GET_TAG$ATOMIC_TAGGED_PTR_T$$WORD
	.type	NEXTPAS.CORE.ATOMIC.CORE_$$_ATOMIC_TAGGED_PTR_GET_TAG$ATOMIC_TAGGED_PTR_T$$WORD,@function
NEXTPAS.CORE.ATOMIC.CORE_$$_ATOMIC_TAGGED_PTR_GET_TAG$ATOMIC_TAGGED_PTR_T$$WORD:
.Lc22:
# [148] begin
	movq	%rdi,%rax
# Var aTaggedPtr located in register rax
# [150] Result := UInt16(PtrUInt(aTaggedPtr) shr TAG_SHIFT);
	shrq	$48,%rax
# Var $result located in register ax
.Lc23:
# [156] end;
	ret
.Lc21:

.section .text.n_nextpas.core.atomic.core_$$_atomic_tagged_ptr_next$atomic_tagged_ptr_t$$word,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.CORE_$$_ATOMIC_TAGGED_PTR_NEXT$ATOMIC_TAGGED_PTR_T$$WORD
	.type	NEXTPAS.CORE.ATOMIC.CORE_$$_ATOMIC_TAGGED_PTR_NEXT$ATOMIC_TAGGED_PTR_T$$WORD,@function
NEXTPAS.CORE.ATOMIC.CORE_$$_ATOMIC_TAGGED_PTR_NEXT$ATOMIC_TAGGED_PTR_T$$WORD:
.Lc25:
# Var $result located in register ax
# Var aTaggedPtr located in register rdi
# [161] begin
# [162] LTag := atomic_tagged_ptr_get_tag(aTaggedPtr);
	shrq	$48,%rdi
# Var LTag located in register di
# [163] if LTag = MAX_TAG then
	movw	$1,%cx
	cmpw	TC_$NEXTPAS.CORE.ATOMIC.CORE_$$_MAX_TAG,%di
# [164] Result := 1
	cmovew	%cx,%ax
	je	.Lj31
# [166] Result := LTag + 1;
	movzwl	%di,%edi
	leal	1(%rdi),%edx
	movw	%dx,%ax
.Lj31:
.Lc26:
# [167] end;
	ret
.Lc24:
# End asmlist al_procedures
# Begin asmlist al_typedconsts

.section .data.n_TC_$NEXTPAS.CORE.ATOMIC.CORE_$$_PTR_MASK
	.balign 8
.globl	TC_$NEXTPAS.CORE.ATOMIC.CORE_$$_PTR_MASK
	.hidden TC_$NEXTPAS.CORE.ATOMIC.CORE_$$_PTR_MASK
	.type	TC_$NEXTPAS.CORE.ATOMIC.CORE_$$_PTR_MASK,@object
TC_$NEXTPAS.CORE.ATOMIC.CORE_$$_PTR_MASK:
	.quad	281474976710655
# [62] const
.Le0:
	.size	TC_$NEXTPAS.CORE.ATOMIC.CORE_$$_PTR_MASK, .Le0 - TC_$NEXTPAS.CORE.ATOMIC.CORE_$$_PTR_MASK

.section .data.n_TC_$NEXTPAS.CORE.ATOMIC.CORE_$$_MAX_TAG
	.balign 2
.globl	TC_$NEXTPAS.CORE.ATOMIC.CORE_$$_MAX_TAG
	.hidden TC_$NEXTPAS.CORE.ATOMIC.CORE_$$_MAX_TAG
	.type	TC_$NEXTPAS.CORE.ATOMIC.CORE_$$_MAX_TAG,@object
TC_$NEXTPAS.CORE.ATOMIC.CORE_$$_MAX_TAG:
	.short	65535
# [72] procedure cpu_pause;
.Le1:
	.size	TC_$NEXTPAS.CORE.ATOMIC.CORE_$$_MAX_TAG, .Le1 - TC_$NEXTPAS.CORE.ATOMIC.CORE_$$_MAX_TAG
# End asmlist al_typedconsts
# Begin asmlist al_rtti

.section .rodata.n_RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T
	.type	RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T,@object
RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T:
	.byte	3,14
# [170] 
	.ascii	"memory_order_t"
	.quad	0
	.byte	5
	.long	0,5
	.quad	0
	.byte	10
	.ascii	"mo_relaxed"
	.byte	10
	.ascii	"mo_consume"
	.byte	10
	.ascii	"mo_acquire"
	.byte	10
	.ascii	"mo_release"
	.byte	10
	.ascii	"mo_acq_rel"
	.byte	10
	.ascii	"mo_seq_cst"
	.byte	24
	.ascii	"nextpas.core.atomic.core"
	.byte	0
.Le2:
	.size	RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T, .Le2 - RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T

.section .rodata.n_RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T_s2o
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T_s2o
	.type	RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T_s2o,@object
RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T_s2o:
	.long	6,2
	.quad	RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T+63
	.long	4
	.quad	RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T+85
	.long	1
	.quad	RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T+52
	.long	0
	.quad	RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T+41
	.long	3
	.quad	RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T+74
	.long	5
	.quad	RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T+96
.Le3:
	.size	RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T_s2o, .Le3 - RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T_s2o

.section .rodata.n_RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T_o2s
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T_o2s
	.type	RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T_o2s,@object
RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T_o2s:
	.long	0
	.quad	RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T+41
	.quad	RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T+52
	.quad	RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T+63
	.quad	RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T+74
	.quad	RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T+85
	.quad	RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T+96
.Le4:
	.size	RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T_o2s, .Le4 - RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T_o2s

.section .rodata.n_RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_ATOMIC_TAGGED_PTR_T
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_ATOMIC_TAGGED_PTR_T
	.type	RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_ATOMIC_TAGGED_PTR_T,@object
RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_ATOMIC_TAGGED_PTR_T:
	.byte	20,19
	.ascii	"atomic_tagged_ptr_t"
	.quad	0
	.byte	7
	.quad	0,-1
.Le5:
	.size	RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_ATOMIC_TAGGED_PTR_T, .Le5 - RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_ATOMIC_TAGGED_PTR_T
# End asmlist al_rtti
# Begin asmlist al_indirectglobals

.section .rodata.n_RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T$indirect
	.type	RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T$indirect,@object
RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T$indirect:
	.quad	RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T
.Le6:
	.size	RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T$indirect, .Le6 - RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T_s2o
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T_s2o$indirect
	.type	RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T_s2o$indirect,@object
RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T_s2o$indirect:
	.quad	RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T_s2o
.Le7:
	.size	RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T_s2o$indirect, .Le7 - RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T_s2o$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T_o2s
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T_o2s$indirect
	.type	RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T_o2s$indirect,@object
RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T_o2s$indirect:
	.quad	RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T_o2s
.Le8:
	.size	RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T_o2s$indirect, .Le8 - RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_MEMORY_ORDER_T_o2s$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_ATOMIC_TAGGED_PTR_T
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_ATOMIC_TAGGED_PTR_T$indirect
	.type	RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_ATOMIC_TAGGED_PTR_T$indirect,@object
RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_ATOMIC_TAGGED_PTR_T$indirect:
	.quad	RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_ATOMIC_TAGGED_PTR_T
.Le9:
	.size	RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_ATOMIC_TAGGED_PTR_T$indirect, .Le9 - RTTI_$NEXTPAS.CORE.ATOMIC.CORE_$$_ATOMIC_TAGGED_PTR_T$indirect
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
	.byte	4
	.long	.Lc17-.Lc16
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc40:
	.long	.Lc43-.Lc42
.Lc42:
	.long	.Lc27
	.quad	.Lc19
	.quad	.Lc18-.Lc19
	.byte	4
	.long	.Lc20-.Lc19
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc43:
	.long	.Lc46-.Lc45
.Lc45:
	.long	.Lc27
	.quad	.Lc22
	.quad	.Lc21-.Lc22
	.byte	4
	.long	.Lc23-.Lc22
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc46:
	.long	.Lc49-.Lc48
.Lc48:
	.long	.Lc27
	.quad	.Lc25
	.quad	.Lc24-.Lc25
	.byte	4
	.long	.Lc26-.Lc25
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc49:
# End asmlist al_dwarf_frame
.section .note.GNU-stack,"",%progbits

