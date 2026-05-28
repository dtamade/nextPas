	.file "nextpas.core.collections.arr.pas"
# Begin asmlist al_procedures

.section .text.n_nextpas.core.collections.arr_$$_memcopyunchecked$pointer$pointer$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.ARR_$$_MEMCOPYUNCHECKED$POINTER$POINTER$QWORD
	.type	NEXTPAS.CORE.COLLECTIONS.ARR_$$_MEMCOPYUNCHECKED$POINTER$POINTER$QWORD,@function
NEXTPAS.CORE.COLLECTIONS.ARR_$$_MEMCOPYUNCHECKED$POINTER$POINTER$QWORD:
.Lc2:
# [nextpas.core.collections.arr.pas]
# [603] begin
	pushq	%rax
.Lc3:
# Var aSrc located in register rdi
# Var aDst located in register rsi
# Var aSize located in register rdx
# Var aSize located in register rdx
# Var aDst located in register rsi
# Var aSrc located in register rdi
# [604] CopyUnChecked(aSrc, aDst, aSize);
	call	NEXTPAS.CORE.MEM.UTILS_$$_COPYUNCHECKED$POINTER$POINTER$QWORD
# [605] end;
	popq	%rcx
.Lc4:
	ret
.Lc1:

.section .text.n_nextpas.core.collections.arr_$$_memisoverlap$pointer$qword$pointer$qword$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.ARR_$$_MEMISOVERLAP$POINTER$QWORD$POINTER$QWORD$$BOOLEAN
	.type	NEXTPAS.CORE.COLLECTIONS.ARR_$$_MEMISOVERLAP$POINTER$QWORD$POINTER$QWORD$$BOOLEAN,@function
NEXTPAS.CORE.COLLECTIONS.ARR_$$_MEMISOVERLAP$POINTER$QWORD$POINTER$QWORD$$BOOLEAN:
.Lc6:
# [608] begin
	pushq	%rax
.Lc7:
# Var aPtr1 located in register rdi
# Var aSize1 located in register rsi
# Var aPtr2 located in register rdx
# Var aSize2 located in register rcx
# Var aSize2 located in register rcx
# Var aPtr2 located in register rdx
# Var aSize1 located in register rsi
# Var aPtr1 located in register rdi
# [609] Result := IsOverlap(aPtr1, aSize1, aPtr2, aSize2);
	call	NEXTPAS.CORE.MEM.UTILS_$$_ISOVERLAP$POINTER$QWORD$POINTER$QWORD$$BOOLEAN
# Var $result located in register al
# [610] end;
	popq	%rcx
.Lc8:
	ret
.Lc5:

.section .text.n_nextpas.core.collections.arr_$$_init$,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.ARR_$$_init$
	.type	NEXTPAS.CORE.COLLECTIONS.ARR_$$_init$,@function
NEXTPAS.CORE.COLLECTIONS.ARR_$$_init$:
.globl	INIT$_$NEXTPAS.CORE.COLLECTIONS.ARR
	.type	INIT$_$NEXTPAS.CORE.COLLECTIONS.ARR,@function
INIT$_$NEXTPAS.CORE.COLLECTIONS.ARR:
.Lc10:
# [3983] initialization
	pushq	%rax
.Lc11:
# [3984] System.Randomize;
	call	SYSTEM_$$_RANDOMIZE
# [3986] end.
	popq	%rcx
.Lc12:
	ret
.Lc9:
# End asmlist al_procedures
# Begin asmlist al_dwarf_frame

.section .debug_frame
.Lc13:
	.long	.Lc15-.Lc14
.Lc14:
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
.Lc15:
	.long	.Lc17-.Lc16
.Lc16:
	.long	.Lc13
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
.Lc17:
	.long	.Lc20-.Lc19
.Lc19:
	.long	.Lc13
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
.Lc20:
	.long	.Lc23-.Lc22
.Lc22:
	.long	.Lc13
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
.Lc23:
# End asmlist al_dwarf_frame
.section .note.GNU-stack,"",%progbits

