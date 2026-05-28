	.file "nextpas.core.collections.vec.pas"
# Begin asmlist al_procedures

.section .text.n_nextpas.core.collections.vec_$$_memisoverlap$pointer$qword$pointer$qword$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.VEC_$$_MEMISOVERLAP$POINTER$QWORD$POINTER$QWORD$$BOOLEAN
	.type	NEXTPAS.CORE.COLLECTIONS.VEC_$$_MEMISOVERLAP$POINTER$QWORD$POINTER$QWORD$$BOOLEAN,@function
NEXTPAS.CORE.COLLECTIONS.VEC_$$_MEMISOVERLAP$POINTER$QWORD$POINTER$QWORD$$BOOLEAN:
.Lc2:
# [nextpas.core.collections.vec.pas]
# [789] begin
	pushq	%rax
.Lc3:
# Var aPtr1 located in register rdi
# Var aSize1 located in register rsi
# Var aPtr2 located in register rdx
# Var aSize2 located in register rcx
# Var aSize2 located in register rcx
# Var aPtr2 located in register rdx
# Var aSize1 located in register rsi
# Var aPtr1 located in register rdi
# [790] Result := IsOverlap(aPtr1, aSize1, aPtr2, aSize2);
	call	NEXTPAS.CORE.MEM.UTILS_$$_ISOVERLAP$POINTER$QWORD$POINTER$QWORD$$BOOLEAN
# Var $result located in register al
# [791] end;
	popq	%rcx
.Lc4:
	ret
.Lc1:
# End asmlist al_procedures
# Begin asmlist al_dwarf_frame

.section .debug_frame
.Lc5:
	.long	.Lc7-.Lc6
.Lc6:
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
.Lc7:
	.long	.Lc9-.Lc8
.Lc8:
	.long	.Lc5
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
.Lc9:
# End asmlist al_dwarf_frame
.section .note.GNU-stack,"",%progbits

