	.file "nextpas.core.math.pas"
# Begin asmlist al_procedures

.section .text.n_nextpas.core.math_$$_isaddoverflow$qword$qword$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MATH_$$_ISADDOVERFLOW$QWORD$QWORD$$BOOLEAN
	.type	NEXTPAS.CORE.MATH_$$_ISADDOVERFLOW$QWORD$QWORD$$BOOLEAN,@function
NEXTPAS.CORE.MATH_$$_ISADDOVERFLOW$QWORD$QWORD$$BOOLEAN:
.Lc2:
# Var aA located in register rdi
# Var aB located in register rsi
# [nextpas.core.math.pas]
# [29] begin
# [30] Result := aA > High(SizeUInt) - aB;
	movq	$-1,%rax
	subq	%rsi,%rax
	cmpq	%rdi,%rax
# Var $result located in register al
	setbb	%al
.Lc3:
# [31] end;
	ret
.Lc1:

.section .text.n_nextpas.core.math_$$_isaddoverflow$longword$longword$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MATH_$$_ISADDOVERFLOW$LONGWORD$LONGWORD$$BOOLEAN
	.type	NEXTPAS.CORE.MATH_$$_ISADDOVERFLOW$LONGWORD$LONGWORD$$BOOLEAN,@function
NEXTPAS.CORE.MATH_$$_ISADDOVERFLOW$LONGWORD$LONGWORD$$BOOLEAN:
.Lc5:
# Var aA located in register edi
# Var aB located in register esi
# [34] begin
# [35] Result := aA > High(UInt32) - aB;
	andl	%esi,%esi
	movl	$4294967295,%eax
	subq	%rsi,%rax
	andl	%edi,%edi
	cmpq	%rdi,%rax
# Var $result located in register al
	setlb	%al
.Lc6:
# [36] end;
	ret
.Lc4:

.section .text.n_nextpas.core.math_$$_ismuloverflow$qword$qword$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MATH_$$_ISMULOVERFLOW$QWORD$QWORD$$BOOLEAN
	.type	NEXTPAS.CORE.MATH_$$_ISMULOVERFLOW$QWORD$QWORD$$BOOLEAN,@function
NEXTPAS.CORE.MATH_$$_ISMULOVERFLOW$QWORD$QWORD$$BOOLEAN:
.Lc8:
# Var aA located in register rdi
# Var aB located in register rsi
# [39] begin
# [40] Result := (aA <> 0) and (aB > High(SizeUInt) div aA);
	testq	%rdi,%rdi
	je	.Lj10
	movq	$-1,%rax
	xorl	%edx,%edx
	divq	%rdi
	cmpq	%rsi,%rax
	setbb	%al
# Var $result located in register al
	ret
.Lj10:
	xorb	%al,%al
.Lc9:
# [41] end;
	ret
.Lc7:

.section .text.n_nextpas.core.math_$$_ismuloverflow$longword$longword$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MATH_$$_ISMULOVERFLOW$LONGWORD$LONGWORD$$BOOLEAN
	.type	NEXTPAS.CORE.MATH_$$_ISMULOVERFLOW$LONGWORD$LONGWORD$$BOOLEAN,@function
NEXTPAS.CORE.MATH_$$_ISMULOVERFLOW$LONGWORD$LONGWORD$$BOOLEAN:
.Lc11:
# Var aA located in register edi
# Var aB located in register esi
# [44] begin
# [45] Result := (aA <> 0) and (aB > High(UInt32) div aA);
	testl	%edi,%edi
	je	.Lj16
	andl	%edi,%edi
	movl	$4294967295,%eax
	xorl	%edx,%edx
	divq	%rdi
	andl	%esi,%esi
	cmpq	%rsi,%rax
	setbb	%al
# Var $result located in register al
	ret
.Lj16:
	xorb	%al,%al
.Lc12:
# [46] end;
	ret
.Lc10:

.section .text.n_nextpas.core.math_$$_min$qword$qword$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MATH_$$_MIN$QWORD$QWORD$$QWORD
	.type	NEXTPAS.CORE.MATH_$$_MIN$QWORD$QWORD$$QWORD,@function
NEXTPAS.CORE.MATH_$$_MIN$QWORD$QWORD$$QWORD:
.Lc14:
# Var aA located in register rdi
# Var aB located in register rsi
# [49] begin
# [50] if aA < aB then
	movq	%rdi,%rax
	cmpq	%rdi,%rsi
	cmovbq	%rsi,%rax
# Var $result located in register rax
.Lc15:
# [54] end;
	ret
.Lc13:

.section .text.n_nextpas.core.math_$$_max$qword$qword$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MATH_$$_MAX$QWORD$QWORD$$QWORD
	.type	NEXTPAS.CORE.MATH_$$_MAX$QWORD$QWORD$$QWORD,@function
NEXTPAS.CORE.MATH_$$_MAX$QWORD$QWORD$$QWORD:
.Lc17:
# Var aA located in register rdi
# Var aB located in register rsi
# [57] begin
# [58] if aA > aB then
	movq	%rdi,%rax
	cmpq	%rdi,%rsi
	cmovaq	%rsi,%rax
# Var $result located in register rax
.Lc18:
# [62] end;
	ret
.Lc16:

.section .text.n_nextpas.core.math_$$_min$int64$int64$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MATH_$$_MIN$INT64$INT64$$INT64
	.type	NEXTPAS.CORE.MATH_$$_MIN$INT64$INT64$$INT64,@function
NEXTPAS.CORE.MATH_$$_MIN$INT64$INT64$$INT64:
.Lc20:
# Var aA located in register rdi
# Var aB located in register rsi
# [65] begin
# [66] if aA < aB then
	movq	%rdi,%rax
	cmpq	%rdi,%rsi
	cmovlq	%rsi,%rax
# Var $result located in register rax
.Lc21:
# [70] end;
	ret
.Lc19:

.section .text.n_nextpas.core.math_$$_max$int64$int64$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MATH_$$_MAX$INT64$INT64$$INT64
	.type	NEXTPAS.CORE.MATH_$$_MAX$INT64$INT64$$INT64,@function
NEXTPAS.CORE.MATH_$$_MAX$INT64$INT64$$INT64:
.Lc23:
# Var aA located in register rdi
# Var aB located in register rsi
# [73] begin
# [74] if aA > aB then
	movq	%rdi,%rax
	cmpq	%rdi,%rsi
	cmovgq	%rsi,%rax
# Var $result located in register rax
.Lc24:
# [78] end;
	ret
.Lc22:

.section .text.n_nextpas.core.math_$$_min$double$double$$double,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MATH_$$_MIN$DOUBLE$DOUBLE$$DOUBLE
	.type	NEXTPAS.CORE.MATH_$$_MIN$DOUBLE$DOUBLE$$DOUBLE,@function
NEXTPAS.CORE.MATH_$$_MIN$DOUBLE$DOUBLE$$DOUBLE:
.Lc26:
# Var aA located in register xmm0
# Var aB located in register xmm1
# [81] begin
# [82] if aA < aB then
	minsd	%xmm1,%xmm0
# Var $result located in register xmm0
.Lc27:
# [86] end;
	ret
.Lc25:

.section .text.n_nextpas.core.math_$$_max$double$double$$double,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MATH_$$_MAX$DOUBLE$DOUBLE$$DOUBLE
	.type	NEXTPAS.CORE.MATH_$$_MAX$DOUBLE$DOUBLE$$DOUBLE,@function
NEXTPAS.CORE.MATH_$$_MAX$DOUBLE$DOUBLE$$DOUBLE:
.Lc29:
# Var aA located in register xmm0
# Var aB located in register xmm1
# [89] begin
# [90] if aA > aB then
	maxsd	%xmm1,%xmm0
# Var $result located in register xmm0
.Lc30:
# [94] end;
	ret
.Lc28:

.section .text.n_nextpas.core.math_$$_ceil$double$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MATH_$$_CEIL$DOUBLE$$INT64
	.type	NEXTPAS.CORE.MATH_$$_CEIL$DOUBLE$$INT64,@function
NEXTPAS.CORE.MATH_$$_CEIL$DOUBLE$$INT64:
.Lc32:
# Temps allocated between rsp+16 and rsp+24
# [97] begin
	leaq	-24(%rsp),%rsp
.Lc33:
# Var x located in register xmm0
# [98] Result := Int64(Math.Ceil(x));
	movsd	%xmm0,16(%rsp)
	fldl	16(%rsp)
	fstpt	(%rsp)
	call	MATH_$$_CEIL$EXTENDED$$LONGINT
	cltq
# Var $result located in register rax
# [99] end;
	leaq	24(%rsp),%rsp
.Lc34:
	ret
.Lc31:

.section .text.n_nextpas.core.math_$$_isnan$double$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MATH_$$_ISNAN$DOUBLE$$BOOLEAN
	.type	NEXTPAS.CORE.MATH_$$_ISNAN$DOUBLE$$BOOLEAN,@function
NEXTPAS.CORE.MATH_$$_ISNAN$DOUBLE$$BOOLEAN:
.Lc36:
# [102] begin
	pushq	%rax
.Lc37:
# Var x located in register xmm0
# Var x located in register xmm0
# [103] Result := Math.IsNaN(x);
	call	MATH_$$_ISNAN$DOUBLE$$BOOLEAN
# Var $result located in register al
# [104] end;
	popq	%rcx
.Lc38:
	ret
.Lc35:

.section .text.n_nextpas.core.math_$$_isinfinite$double$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MATH_$$_ISINFINITE$DOUBLE$$BOOLEAN
	.type	NEXTPAS.CORE.MATH_$$_ISINFINITE$DOUBLE$$BOOLEAN,@function
NEXTPAS.CORE.MATH_$$_ISINFINITE$DOUBLE$$BOOLEAN:
.Lc40:
# [107] begin
	pushq	%rax
.Lc41:
# Var x located in register xmm0
# Var x located in register xmm0
# [108] Result := Math.IsInfinite(x);
	call	MATH_$$_ISINFINITE$DOUBLE$$BOOLEAN
# Var $result located in register al
# [109] end;
	popq	%rcx
.Lc42:
	ret
.Lc39:
# End asmlist al_procedures
# Begin asmlist al_dwarf_frame

.section .debug_frame
.Lc43:
	.long	.Lc45-.Lc44
.Lc44:
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
.Lc45:
	.long	.Lc47-.Lc46
.Lc46:
	.long	.Lc43
	.quad	.Lc2
	.quad	.Lc1-.Lc2
	.byte	4
	.long	.Lc3-.Lc2
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc47:
	.long	.Lc50-.Lc49
.Lc49:
	.long	.Lc43
	.quad	.Lc5
	.quad	.Lc4-.Lc5
	.byte	4
	.long	.Lc6-.Lc5
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc50:
	.long	.Lc53-.Lc52
.Lc52:
	.long	.Lc43
	.quad	.Lc8
	.quad	.Lc7-.Lc8
	.byte	4
	.long	.Lc9-.Lc8
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc53:
	.long	.Lc56-.Lc55
.Lc55:
	.long	.Lc43
	.quad	.Lc11
	.quad	.Lc10-.Lc11
	.byte	4
	.long	.Lc12-.Lc11
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc56:
	.long	.Lc59-.Lc58
.Lc58:
	.long	.Lc43
	.quad	.Lc14
	.quad	.Lc13-.Lc14
	.byte	4
	.long	.Lc15-.Lc14
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc59:
	.long	.Lc62-.Lc61
.Lc61:
	.long	.Lc43
	.quad	.Lc17
	.quad	.Lc16-.Lc17
	.byte	4
	.long	.Lc18-.Lc17
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc62:
	.long	.Lc65-.Lc64
.Lc64:
	.long	.Lc43
	.quad	.Lc20
	.quad	.Lc19-.Lc20
	.byte	4
	.long	.Lc21-.Lc20
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc65:
	.long	.Lc68-.Lc67
.Lc67:
	.long	.Lc43
	.quad	.Lc23
	.quad	.Lc22-.Lc23
	.byte	4
	.long	.Lc24-.Lc23
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc68:
	.long	.Lc71-.Lc70
.Lc70:
	.long	.Lc43
	.quad	.Lc26
	.quad	.Lc25-.Lc26
	.byte	4
	.long	.Lc27-.Lc26
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc71:
	.long	.Lc74-.Lc73
.Lc73:
	.long	.Lc43
	.quad	.Lc29
	.quad	.Lc28-.Lc29
	.byte	4
	.long	.Lc30-.Lc29
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc74:
	.long	.Lc77-.Lc76
.Lc76:
	.long	.Lc43
	.quad	.Lc32
	.quad	.Lc31-.Lc32
	.byte	2
	.byte	.Lc33-.Lc32
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc34-.Lc33
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc77:
	.long	.Lc80-.Lc79
.Lc79:
	.long	.Lc43
	.quad	.Lc36
	.quad	.Lc35-.Lc36
	.byte	2
	.byte	.Lc37-.Lc36
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc38-.Lc37
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc80:
	.long	.Lc83-.Lc82
.Lc82:
	.long	.Lc43
	.quad	.Lc40
	.quad	.Lc39-.Lc40
	.byte	2
	.byte	.Lc41-.Lc40
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc42-.Lc41
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc83:
# End asmlist al_dwarf_frame
.section .note.GNU-stack,"",%progbits

