	.file "nextpas.core.collections.base.pas"
# Begin asmlist al_procedures

.section .text.n_nextpas.core.collections.base_$$_compare_bool$boolean$boolean$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_BOOL$BOOLEAN$BOOLEAN$$INT64
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_BOOL$BOOLEAN$BOOLEAN$$INT64,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_BOOL$BOOLEAN$BOOLEAN$$INT64:
.Lc2:
# Var $result located in register rax
# Var aLeft located in register dil
# Var aRight located in register sil
# [nextpas.core.collections.base.pas]
# [642] begin
# [643] if aLeft = aRight then
	xorl	%ecx,%ecx
	cmpb	%dil,%sil
# [644] Result := 0
	cmoveq	%rcx,%rax
	je	.Lj7
# [645] else if aLeft then
	movq	$-1,%rdx
# [646] Result := 1
	movl	$1,%eax
	testb	%dil,%dil
# [648] Result := -1;
	cmoveq	%rdx,%rax
.Lj7:
.Lc3:
# [649] end;
	ret
.Lc1:

.section .text.n_nextpas.core.collections.base_$$_compare_char$ansichar$ansichar$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_CHAR$ANSICHAR$ANSICHAR$$INT64
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_CHAR$ANSICHAR$ANSICHAR$$INT64,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_CHAR$ANSICHAR$ANSICHAR$$INT64:
.Lc5:
# [652] begin
	pushq	%rax
.Lc6:
# Var aLeft located in register dil
# Var aRight located in register sil
# Var aRight located in register sil
# [653] Result := compare_u8(Ord(aLeft), Ord(aRight));
	movzbl	%sil,%esi
# Var aLeft located in register dil
	movzbl	%dil,%edi
	call	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_U8$BYTE$BYTE$$INT64
# Var $result located in register rax
# [654] end;
	popq	%rcx
.Lc7:
	ret
.Lc4:

.section .text.n_nextpas.core.collections.base_$$_compare_wchar$widechar$widechar$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_WCHAR$WIDECHAR$WIDECHAR$$INT64
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_WCHAR$WIDECHAR$WIDECHAR$$INT64,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_WCHAR$WIDECHAR$WIDECHAR$$INT64:
.Lc9:
# [657] begin
	pushq	%rax
.Lc10:
# Var aLeft located in register di
# Var aRight located in register si
# Var aRight located in register si
# [658] Result := compare_u16(Ord(aLeft), Ord(aRight));
	movzwl	%si,%esi
# Var aLeft located in register di
	movzwl	%di,%edi
	call	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_U16$WORD$WORD$$INT64
# Var $result located in register rax
# [659] end;
	popq	%rcx
.Lc11:
	ret
.Lc8:

.section .text.n_nextpas.core.collections.base_$$_compare_i8$shortint$shortint$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_I8$SHORTINT$SHORTINT$$INT64
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_I8$SHORTINT$SHORTINT$$INT64,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_I8$SHORTINT$SHORTINT$$INT64:
.Lc13:
# Var aLeft located in register al
# Var aRight located in register sil
# [662] begin
# [663] Result := aLeft - aRight;
	movsbq	%dil,%rax
	movsbq	%sil,%rsi
	subq	%rsi,%rax
# Var $result located in register rax
.Lc14:
# [664] end;
	ret
.Lc12:

.section .text.n_nextpas.core.collections.base_$$_compare_i16$smallint$smallint$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_I16$SMALLINT$SMALLINT$$INT64
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_I16$SMALLINT$SMALLINT$$INT64,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_I16$SMALLINT$SMALLINT$$INT64:
.Lc16:
# Var aLeft located in register ax
# Var aRight located in register si
# [667] begin
# [668] Result := aLeft - aRight;
	movswq	%di,%rax
	movswq	%si,%rsi
	subq	%rsi,%rax
# Var $result located in register rax
.Lc17:
# [669] end;
	ret
.Lc15:

.section .text.n_nextpas.core.collections.base_$$_compare_i32$longint$longint$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_I32$LONGINT$LONGINT$$INT64
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_I32$LONGINT$LONGINT$$INT64,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_I32$LONGINT$LONGINT$$INT64:
.Lc19:
# Var aLeft located in register eax
# Var aRight located in register esi
# [672] begin
# [674] Result := aLeft - aRight;
	movslq	%edi,%rax
	movslq	%esi,%rsi
	subq	%rsi,%rax
# Var $result located in register rax
.Lc20:
# [683] end;
	ret
.Lc18:

.section .text.n_nextpas.core.collections.base_$$_compare_i64$int64$int64$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_I64$INT64$INT64$$INT64
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_I64$INT64$INT64$$INT64,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_I64$INT64$INT64$$INT64:
.Lc22:
# Var $result located in register rax
# Var aLeft located in register rdi
# Var aRight located in register rsi
# [686] begin
# [687] if aLeft > aRight then
	movl	$1,%ecx
	cmpq	%rdi,%rsi
# [688] Result := 1
	cmovlq	%rcx,%rax
	jl	.Lj25
# [689] else if aLeft < aRight then
	xorl	%edx,%edx
# [690] Result := -1
	movq	$-1,%rax
	cmpq	%rdi,%rsi
# [692] Result := 0;
	cmovngq	%rdx,%rax
.Lj25:
.Lc23:
# [693] end;
	ret
.Lc21:

.section .text.n_nextpas.core.collections.base_$$_compare_u8$byte$byte$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_U8$BYTE$BYTE$$INT64
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_U8$BYTE$BYTE$$INT64,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_U8$BYTE$BYTE$$INT64:
.Lc25:
# Var aLeft located in register al
# Var aRight located in register sil
# [696] begin
# [697] Result := aLeft - aRight;
	movzbl	%dil,%eax
	movzbl	%sil,%esi
	subq	%rsi,%rax
# Var $result located in register rax
.Lc26:
# [698] end;
	ret
.Lc24:
.Le0:
	.size	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_U8$BYTE$BYTE$$INT64, .Le0 - NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_U8$BYTE$BYTE$$INT64

.section .text.n_nextpas.core.collections.base_$$_compare_u16$word$word$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_U16$WORD$WORD$$INT64
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_U16$WORD$WORD$$INT64,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_U16$WORD$WORD$$INT64:
.Lc28:
# Var aLeft located in register ax
# Var aRight located in register si
# [701] begin
# [702] Result := aLeft - aRight;
	movzwl	%di,%eax
	movzwl	%si,%esi
	subq	%rsi,%rax
# Var $result located in register rax
.Lc29:
# [703] end;
	ret
.Lc27:
.Le1:
	.size	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_U16$WORD$WORD$$INT64, .Le1 - NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_U16$WORD$WORD$$INT64

.section .text.n_nextpas.core.collections.base_$$_compare_u32$longword$longword$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_U32$LONGWORD$LONGWORD$$INT64
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_U32$LONGWORD$LONGWORD$$INT64,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_U32$LONGWORD$LONGWORD$$INT64:
.Lc31:
# [706] begin
	movl	%edi,%eax
# Var aLeft located in register eax
# Var aRight located in register esi
# [708] Result := aLeft - aRight;
	andl	%esi,%esi
	subq	%rsi,%rax
# Var $result located in register rax
.Lc32:
# [717] end;
	ret
.Lc30:

.section .text.n_nextpas.core.collections.base_$$_compare_u64$qword$qword$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_U64$QWORD$QWORD$$INT64
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_U64$QWORD$QWORD$$INT64,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_U64$QWORD$QWORD$$INT64:
.Lc34:
# Var $result located in register rax
# Var aLeft located in register rdi
# Var aRight located in register rsi
# [720] begin
# [721] if aLeft > aRight then
	movl	$1,%ecx
	cmpq	%rdi,%rsi
# [722] Result := 1
	cmovbq	%rcx,%rax
	jb	.Lj39
# [723] else if aLeft < aRight then
	xorl	%edx,%edx
# [724] Result := -1
	movq	$-1,%rax
	cmpq	%rdi,%rsi
# [726] Result := 0;
	cmovnaq	%rdx,%rax
.Lj39:
.Lc35:
# [727] end;
	ret
.Lc33:

.section .text.n_nextpas.core.collections.base_$$_compare_single$single$single$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_SINGLE$SINGLE$SINGLE$$INT64
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_SINGLE$SINGLE$SINGLE$$INT64,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_SINGLE$SINGLE$SINGLE$$INT64:
.Lc37:
# Var $result located in register rax
# Var aLeft located in register xmm0
# Var aRight located in register xmm1
# [730] begin
# [731] if aLeft > aRight then
	comiss	%xmm0,%xmm1
	jp	.Lj46
	movl	$1,%ecx
# [732] Result := 1
	cmovbq	%rcx,%rax
	jb	.Lj48
	.p2align 4,,10
	.p2align 3
.Lj46:
# [733] else if aLeft < aRight then
	comiss	%xmm0,%xmm1
	jp	.Lj50
	movq	$-1,%rcx
# [734] Result := -1
	cmovaq	%rcx,%rax
	ja	.Lj48
	.p2align 4,,10
	.p2align 3
.Lj50:
# [736] Result := 0;
	xorl	%eax,%eax
.Lj48:
.Lc38:
# [737] end;
	ret
.Lc36:

.section .text.n_nextpas.core.collections.base_$$_compare_double$double$double$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_DOUBLE$DOUBLE$DOUBLE$$INT64
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_DOUBLE$DOUBLE$DOUBLE$$INT64,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_DOUBLE$DOUBLE$DOUBLE$$INT64:
.Lc40:
# Var $result located in register rax
# Var aLeft located in register xmm0
# Var aRight located in register xmm1
# [740] begin
# [741] if aLeft > aRight then
	comisd	%xmm0,%xmm1
	jp	.Lj56
	movl	$1,%ecx
# [742] Result := 1
	cmovbq	%rcx,%rax
	jb	.Lj58
	.p2align 4,,10
	.p2align 3
.Lj56:
# [743] else if aLeft < aRight then
	comisd	%xmm0,%xmm1
	jp	.Lj60
	movq	$-1,%rcx
# [744] Result := -1
	cmovaq	%rcx,%rax
	ja	.Lj58
	.p2align 4,,10
	.p2align 3
.Lj60:
# [746] Result := 0;
	xorl	%eax,%eax
.Lj58:
.Lc41:
# [747] end;
	ret
.Lc39:

.section .text.n_nextpas.core.collections.base_$$_compare_extended$extended$extended$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_EXTENDED$EXTENDED$EXTENDED$$INT64
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_EXTENDED$EXTENDED$EXTENDED$$INT64,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_EXTENDED$EXTENDED$EXTENDED$$INT64:
.Lc43:
# [750] begin
	pushq	%rbp
.Lc44:
	movq	%rsp,%rbp
.Lc45:
# Var aLeft located at rbp+16, size=OS_F80
# Var aRight located at rbp+32, size=OS_F80
# Var $result located in register rax
# [751] if aLeft > aRight then
	fldt	32(%rsp)
	fldt	16(%rsp)
	fcomip	%st(1),%st(0)
	fstp	%st(0)
	jp	.Lj66
	movl	$1,%ecx
# [752] Result := 1
	cmovaq	%rcx,%rax
	ja	.Lj68
	.p2align 4,,10
	.p2align 3
.Lj66:
# [753] else if aLeft < aRight then
	fldt	32(%rbp)
	fldt	16(%rbp)
	fcomip	%st(1),%st(0)
	fstp	%st(0)
	jp	.Lj70
	movq	$-1,%rcx
# [754] Result := -1
	cmovbq	%rcx,%rax
	jb	.Lj68
	.p2align 4,,10
	.p2align 3
.Lj70:
# [756] Result := 0;
	xorl	%eax,%eax
.Lj68:
.Lc46:
# [757] end;
	movq	%rbp,%rsp
.Lc47:
	popq	%rbp
	ret
.Lc42:

.section .text.n_nextpas.core.collections.base_$$_compare_currency$currency$currency$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_CURRENCY$CURRENCY$CURRENCY$$INT64
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_CURRENCY$CURRENCY$CURRENCY$$INT64,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_CURRENCY$CURRENCY$CURRENCY$$INT64:
.Lc49:
# [760] begin
	leaq	-24(%rsp),%rsp
.Lc50:
# Var aLeft located at rsp+0, size=OS_C64
# Var aRight located at rsp+8, size=OS_C64
# Var $result located in register rax
	movq	%rdi,(%rsp)
	movq	%rsi,8(%rsp)
# [761] if aLeft > aRight then
	fildq	8(%rsp)
	fildq	(%rsp)
	fcomip	%st(1),%st(0)
	fstp	%st(0)
	jp	.Lj76
	movl	$1,%ecx
# [762] Result := 1
	cmovaq	%rcx,%rax
	ja	.Lj78
	.p2align 4,,10
	.p2align 3
.Lj76:
# [763] else if aLeft < aRight then
	fildq	8(%rsp)
	fildq	(%rsp)
	fcomip	%st(1),%st(0)
	fstp	%st(0)
	jp	.Lj80
	movq	$-1,%rcx
# [764] Result := -1
	cmovbq	%rcx,%rax
	jb	.Lj78
	.p2align 4,,10
	.p2align 3
.Lj80:
# [766] Result := 0;
	xorl	%eax,%eax
.Lj78:
# [767] end;
	leaq	24(%rsp),%rsp
.Lc51:
	ret
.Lc48:

.section .text.n_nextpas.core.collections.base_$$_compare_comp$comp$comp$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_COMP$COMP$COMP$$INT64
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_COMP$COMP$COMP$$INT64,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_COMP$COMP$COMP$$INT64:
.Lc53:
# [770] begin
	leaq	-24(%rsp),%rsp
.Lc54:
# Var aLeft located at rsp+0, size=OS_C64
# Var aRight located at rsp+8, size=OS_C64
# Var $result located in register rax
	movq	%rdi,(%rsp)
	movq	%rsi,8(%rsp)
# [771] if aLeft > aRight then
	fildq	(%rsp)
	fildq	8(%rsp)
	fcomip	%st(1),%st(0)
	fstp	%st(0)
	jp	.Lj86
	movl	$1,%ecx
# [772] Result := 1
	cmovbq	%rcx,%rax
	jb	.Lj88
	.p2align 4,,10
	.p2align 3
.Lj86:
# [773] else if aLeft < aRight then
	fildq	(%rsp)
	fildq	8(%rsp)
	fcomip	%st(1),%st(0)
	fstp	%st(0)
	jp	.Lj90
	movq	$-1,%rcx
# [774] Result := -1
	cmovaq	%rcx,%rax
	ja	.Lj88
	.p2align 4,,10
	.p2align 3
.Lj90:
# [776] Result := 0;
	xorl	%eax,%eax
.Lj88:
# [777] end;
	leaq	24(%rsp),%rsp
.Lc55:
	ret
.Lc52:

.section .text.n_nextpas.core.collections.base_$$_compare_variant$variant$variant$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_VARIANT$VARIANT$VARIANT$$INT64
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_VARIANT$VARIANT$VARIANT$$INT64,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_VARIANT$VARIANT$VARIANT$$INT64:
.Lc57:
# Temps allocated between rsp+40 and rsp+516
# [783] begin
	pushq	%rbx
.Lc58:
	leaq	-528(%rsp),%rsp
.Lc59:
# Var aLeft located at rsp+0, size=OS_64
# Var aRight located at rsp+8, size=OS_64
# Var $result located at rsp+16, size=OS_S64
# Var LLeftString located at rsp+24, size=OS_64
# Var LRightString located at rsp+32, size=OS_64
	movq	%rdi,(%rsp)
	movq	%rsi,8(%rsp)
	movq	$0,24(%rsp)
	movq	$0,32(%rsp)
	leaq	40(%rsp),%rdx
	leaq	64(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,128(%rsp)
	testl	%eax,%eax
	jne	.Lj96
# [784] try
	leaq	136(%rsp),%rdx
	leaq	160(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,224(%rsp)
	testl	%eax,%eax
	jne	.Lj102
# [785] case VarCompareValue(aLeft, aRight) of
	movq	8(%rsp),%rsi
	movq	(%rsp),%rdi
	call	VARIANTS_$$_VARCOMPAREVALUE$VARIANT$VARIANT$$TVARIANTRELATIONSHIP
	testl	%eax,%eax
	je	.Lj106
	subl	$1,%eax
	je	.Lj105
	subl	$1,%eax
	je	.Lj104
	subl	$1,%eax
	je	.Lj107
	jmp	.Lj103
	.balign 16,0x90
.Lj104:
# [787] Exit(1);
	movq	$1,16(%rsp)
	jmp	.Lj98
	.balign 16,0x90
.Lj105:
# [789] Exit(-1);
	movq	$-1,16(%rsp)
	jmp	.Lj98
	.balign 16,0x90
.Lj106:
# [791] Exit(0);
	movq	$0,16(%rsp)
	jmp	.Lj98
	.balign 16,0x90
.Lj107:
# [793] if VarIsEmpty(aLeft) or VarIsNull(aLeft) then
	movq	(%rsp),%rax
	movw	(%rax),%dx
	testw	%dx,%dx
	seteb	%al
	cmpw	$1,%dx
	seteb	%dl
	orb	%dl,%al
	je	.Lj109
# [795] else
	movq	$1,16(%rsp)
# [794] Exit(1)
	jmp	.Lj98
	.p2align 4,,10
	.p2align 3
.Lj109:
# [796] Exit(-1);
	movq	$-1,16(%rsp)
	jmp	.Lj98
	.balign 16,0x90
.Lj103:
.Lj102:
	call	fpc_popaddrstack
	cmpl	$0,224(%rsp)
	je	.Lj100
	leaq	232(%rsp),%rdx
	leaq	256(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,320(%rsp)
	testl	%eax,%eax
	jne	.Lj111
# [799] try
	leaq	328(%rsp),%rdx
	leaq	352(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,416(%rsp)
	testl	%eax,%eax
	jne	.Lj116
# [800] LLeftString  := aLeft;
	movq	(%rsp),%rsi
	leaq	24(%rsp),%rdi
	call	*U_$SYSTEM_$$_VARIANTMANAGER+64
# [801] LRightString := aRight;
	movq	8(%rsp),%rsi
	leaq	32(%rsp),%rdi
	call	*U_$SYSTEM_$$_VARIANTMANAGER+64
# [802] Result := CompareStr(LLeftString, LRightString);
	movq	32(%rsp),%rsi
	movq	24(%rsp),%rdi
	call	SYSUTILS_$$_COMPARESTR$ANSISTRING$ANSISTRING$$LONGINT
	cltq
	movq	%rax,16(%rsp)
.Lj116:
	call	fpc_popaddrstack
	cmpl	$0,416(%rsp)
	je	.Lj114
	leaq	424(%rsp),%rdx
	leaq	448(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,512(%rsp)
	testl	%eax,%eax
	jne	.Lj117
# [804] Result := CompareMemRange(@aLeft, @aRight, SizeOf(System.Variant));
	movq	8(%rsp),%rsi
	movq	(%rsp),%rdi
	xorl	%eax,%eax
	cmpq	%rdi,%rsi
	cmovel	%eax,%ebx
	je	.Lj120
	movl	$24,%edx
	call	SYSTEM_$$_COMPAREBYTE$formal$formal$INT64$$INT64
	movl	%eax,%ebx
.Lj120:
	movslq	%ebx,%rbx
	movq	%rbx,16(%rsp)
.Lj117:
	call	fpc_popaddrstack
	cmpl	$0,512(%rsp)
	je	.Lj121
	call	fpc_raise_nested
.Lj121:
	call	fpc_doneexception
.Lj114:
.Lj111:
	call	fpc_popaddrstack
	cmpl	$0,320(%rsp)
	je	.Lj122
	call	fpc_raise_nested
.Lj122:
	call	fpc_doneexception
	jmp	.Lj100
.Lj98:
	call	fpc_popaddrstack
	jmp	.Lj97
.Lj100:
.Lj96:
	call	fpc_popaddrstack
# [807] end;
	leaq	24(%rsp),%rdi
	call	fpc_ansistr_decr_ref
	leaq	32(%rsp),%rdi
	call	fpc_ansistr_decr_ref
	cmpl	$0,128(%rsp)
	je	.Lj95
	call	fpc_reraise
.Lj97:
	movl	$0,128(%rsp)
	jmp	.Lj96
.Lj95:
	movq	16(%rsp),%rax
	leaq	528(%rsp),%rsp
	popq	%rbx
.Lc60:
	ret
.Lc56:

.section .text.n_nextpas.core.collections.base_$$_compare_string$ansistring$ansistring$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_STRING$ANSISTRING$ANSISTRING$$INT64
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_STRING$ANSISTRING$ANSISTRING$$INT64,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_STRING$ANSISTRING$ANSISTRING$$INT64:
.Lc62:
# [810] begin
	pushq	%rax
.Lc63:
# Var aLeft located in register rdi
# Var aRight located in register rsi
# Var aRight located in register rsi
# Var aLeft located in register rdi
# [811] Result := CompareStr(aLeft, aRight);
	call	SYSUTILS_$$_COMPARESTR$ANSISTRING$ANSISTRING$$LONGINT
	cltq
# Var $result located in register rax
# [812] end;
	popq	%rcx
.Lc64:
	ret
.Lc61:

.section .text.n_nextpas.core.collections.base_$$_compare_method$tmethod$tmethod$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_METHOD$TMETHOD$TMETHOD$$INT64
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_METHOD$TMETHOD$TMETHOD$$INT64,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_METHOD$TMETHOD$TMETHOD$$INT64:
.Lc66:
# [815] begin
	pushq	%rbx
.Lc67:
	leaq	-32(%rsp),%rsp
.Lc68:
# Var aLeft located at rsp+0, size=OS_128
# Var aRight located at rsp+16, size=OS_128
	movq	%rdi,(%rsp)
	movq	%rsi,8(%rsp)
	movq	%rdx,16(%rsp)
	movq	%rcx,24(%rsp)
# [816] Result := CompareMemRange(@aLeft, @aRight, SizeOf(TMethod));
	leaq	16(%rsp),%rsi
	movq	%rsp,%rdi
	xorl	%eax,%eax
	cmpq	%rsp,%rsi
	cmovel	%eax,%ebx
	je	.Lj129
	movl	$16,%edx
	call	SYSTEM_$$_COMPAREBYTE$formal$formal$INT64$$INT64
	movl	%eax,%ebx
.Lj129:
	movslq	%ebx,%rax
# Var $result located in register rax
# [817] end;
	leaq	32(%rsp),%rsp
	popq	%rbx
.Lc69:
	ret
.Lc65:

.section .text.n_nextpas.core.collections.base_$$_compare_dynarray$pointer$pointer$qword$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_DYNARRAY$POINTER$POINTER$QWORD$$INT64
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_DYNARRAY$POINTER$POINTER$QWORD$$INT64,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_DYNARRAY$POINTER$POINTER$QWORD$$INT64:
.Lc71:
# [824] begin
	pushq	%rbx
.Lc72:
	pushq	%r12
.Lc73:
	pushq	%r13
.Lc74:
	pushq	%r14
.Lc75:
	pushq	%r15
.Lc76:
# Var aLeft located in register rdi
	movq	%rsi,%r12
# Var aRight located in register r12
	movq	%rdx,%rbx
# Var aElementSize located in register rbx
# [825] LLeftLen := DynArraySize(aLeft);
	movq	%rdi,%r13
# Var aLeft located in register r13
	call	SYSTEM_$$_DYNARRAYSIZE$POINTER$$INT64
# Var LLeftLen located in register r15
	movq	%rax,%r15
# [826] LRightLen := DynArraySize(aRight);
	movq	%r12,%r14
# Var aRight located in register r14
	movq	%r12,%rdi
	call	SYSTEM_$$_DYNARRAYSIZE$POINTER$$INT64
# Var LRightLen located in register r12
	movq	%rax,%r12
# [828] if LLeftLen > LRightLen then
	movq	%rax,%rdx
	cmpq	%rax,%r15
	cmovlq	%r15,%rdx
# Var LLen located in register rdx
# [833] Result := CompareMemRange(aLeft, aRight, LLen * aElementSize);
	imulq	%rbx,%rdx
	xorl	%eax,%eax
	cmpq	%r13,%r14
	cmovel	%eax,%ebx
	je	.Lj134
	movq	%r14,%rsi
	movq	%r13,%rdi
	call	SYSTEM_$$_COMPAREBYTE$formal$formal$INT64$$INT64
	movl	%eax,%ebx
.Lj134:
	movslq	%ebx,%rax
# Var $result located in register rax
# [835] if Result = 0 then
	testq	%rax,%rax
	jne	.Lj136
# [836] Result := LLeftLen - LRightLen;
	movq	%r15,%rax
	subq	%r12,%rax
.Lj136:
# [837] end;
	popq	%r15
.Lc77:
	popq	%r14
.Lc78:
	popq	%r13
.Lc79:
	popq	%r12
.Lc80:
	popq	%rbx
.Lc81:
	ret
.Lc70:

.section .text.n_nextpas.core.collections.base_$$_checkindex$qword$qword$ansistring,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_CHECKINDEX$QWORD$QWORD$ANSISTRING
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_CHECKINDEX$QWORD$QWORD$ANSISTRING,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_CHECKINDEX$QWORD$QWORD$ANSISTRING:
.Lc83:
# Temps allocated between rbp-64 and rbp+0
# [840] begin
	pushq	%rbp
.Lc84:
	movq	%rsp,%rbp
.Lc85:
	leaq	-64(%rsp),%rsp
# Var aIndex located in register rdi
# Var aMax located in register rsi
# Var aCallerName located in register rdx
# [841] if aIndex >= aMax then
	cmpq	%rdi,%rsi
	jnbe	.Lj140
.Lj141:
# [842] raise EOutOfRange.CreateFmt('%s: Index (%u) out of range [0..%u]', [aCallerName, aIndex, aMax - 1]);
	movq	%rdx,-40(%rbp)
	movq	$11,-48(%rbp)
	movq	%rdi,-56(%rbp)
	leaq	-56(%rbp),%rax
	movq	%rax,-24(%rbp)
	movq	$17,-32(%rbp)
	leaq	-1(%rsi),%rax
	movq	%rax,-64(%rbp)
	leaq	-64(%rbp),%rax
	movq	%rax,-8(%rbp)
	movq	$17,-16(%rbp)
	leaq	-48(%rbp),%rcx
	movq	$.Ld1,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE,%rdi
	movl	$2,%r8d
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATEFMT$ANSISTRING$array_of_const$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj141,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj140:
.Lc86:
# [843] end;
	movq	%rbp,%rsp
.Lc87:
	popq	%rbp
	ret
.Lc82:
.Le2:
	.size	NEXTPAS.CORE.COLLECTIONS.BASE_$$_CHECKINDEX$QWORD$QWORD$ANSISTRING, .Le2 - NEXTPAS.CORE.COLLECTIONS.BASE_$$_CHECKINDEX$QWORD$QWORD$ANSISTRING

.section .text.n_nextpas.core.collections.base_$$_checkbounds$qword$qword$qword$ansistring,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_CHECKBOUNDS$QWORD$QWORD$QWORD$ANSISTRING
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_CHECKBOUNDS$QWORD$QWORD$QWORD$ANSISTRING,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_CHECKBOUNDS$QWORD$QWORD$QWORD$ANSISTRING:
.Lc89:
# Temps allocated between rbp-96 and rbp+0
# [846] begin
	pushq	%rbp
.Lc90:
	movq	%rsp,%rbp
.Lc91:
	leaq	-96(%rsp),%rsp
	movq	%rbx,-96(%rbp)
	movq	%r12,-88(%rbp)
	movq	%r13,-80(%rbp)
	movq	%r14,-72(%rbp)
	movq	%rdi,%rbx
# Var aIndex located in register rbx
	movq	%rsi,%r12
# Var aCount located in register r12
	movq	%rdx,%r13
# Var aMax located in register r13
	movq	%rcx,%r14
# Var aCallerName located in register r14
# Var aCallerName located in register r14
# [847] CheckIndex(aIndex, aMax, aCallerName);
	movq	%rcx,%rdx
# Var aMax located in register r13
	movq	%r13,%rsi
# Var aIndex located in register rbx
	movq	%rbx,%rdi
	call	NEXTPAS.CORE.COLLECTIONS.BASE_$$_CHECKINDEX$QWORD$QWORD$ANSISTRING
# [849] if aCount > (aMax - aIndex) then
	movq	%r13,%rax
	subq	%rbx,%rax
	cmpq	%r12,%rax
	jnb	.Lj145
.Lj146:
# [850] raise EOutOfRange.CreateFmt('%s:Bounds check failed. Count (%u) exceeds available length from index %u.', [aCallerName, aCount, aMax - aIndex - 1]);
	movq	%r14,-40(%rbp)
	movq	$11,-48(%rbp)
	movq	%r12,-56(%rbp)
	leaq	-56(%rbp),%rax
	movq	%rax,-24(%rbp)
	movq	$17,-32(%rbp)
	subq	$1,%r13
	subq	%rbx,%r13
	movq	%r13,-64(%rbp)
	leaq	-64(%rbp),%rax
	movq	%rax,-8(%rbp)
	movq	$17,-16(%rbp)
	leaq	-48(%rbp),%rcx
	movq	$.Ld2,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EOUTOFRANGE,%rdi
	movl	$2,%r8d
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATEFMT$ANSISTRING$array_of_const$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj146,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj145:
# [851] end;
	movq	-96(%rbp),%rbx
	movq	-88(%rbp),%r12
	movq	-80(%rbp),%r13
	movq	-72(%rbp),%r14
.Lc92:
	movq	%rbp,%rsp
.Lc93:
	popq	%rbp
	ret
.Lc88:

.section .text.n_nextpas.core.collections.base_$$_compare_shortstring$shortstring$shortstring$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_SHORTSTRING$SHORTSTRING$SHORTSTRING$$INT64
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_SHORTSTRING$SHORTSTRING$SHORTSTRING$$INT64,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_SHORTSTRING$SHORTSTRING$SHORTSTRING$$INT64:
.Lc95:
# [854] begin
	pushq	%rbx
.Lc96:
	pushq	%r12
.Lc97:
	pushq	%r13
.Lc98:
# Var $result located in register r13
	movq	%rdi,%rbx
# Var aLeft located in register rbx
	movq	%rsi,%r12
# Var aRight located in register r12
# [855] if aLeft > aRight then
	call	fpc_shortstr_compare
	movl	$1,%ecx
	testl	%eax,%eax
# [856] Result := 1
	cmovgq	%rcx,%r13
	jg	.Lj151
# [857] else if aLeft < aRight then
	movq	%r12,%rsi
	movq	%rbx,%rdi
	call	fpc_shortstr_compare
	xorl	%edx,%edx
# [858] Result := -1
	movq	$-1,%r13
	testl	%eax,%eax
# [860] Result := 0;
	cmovnlq	%rdx,%r13
.Lj151:
# [861] end;
	movq	%r13,%rax
	popq	%r13
.Lc99:
	popq	%r12
.Lc100:
	popq	%rbx
.Lc101:
	ret
.Lc94:

.section .text.n_nextpas.core.collections.base_$$_compare_ansistring$ansistring$ansistring$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_ANSISTRING$ANSISTRING$ANSISTRING$$INT64
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_ANSISTRING$ANSISTRING$ANSISTRING$$INT64,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_ANSISTRING$ANSISTRING$ANSISTRING$$INT64:
.Lc103:
# [864] begin
	pushq	%rax
.Lc104:
# Var aLeft located in register rdi
# Var aRight located in register rsi
# [865] Result := AnsiCompareStr(aLeft, aRight);
	call	*U_$SYSTEM_$$_WIDESTRINGMANAGER+72
	movq	%rax,%rdx
	testq	%rax,%rax
	movl	$-1,%eax
	jl	.Lj159
	xorl	%eax,%eax
	testq	%rdx,%rdx
	setgb	%al
	.p2align 4,,10
	.p2align 3
.Lj159:
	cltq
# Var $result located in register rax
# [866] end;
	popq	%rcx
.Lc105:
	ret
.Lc102:

.section .text.n_nextpas.core.collections.base_$$_compare_widestring$widestring$widestring$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_WIDESTRING$WIDESTRING$WIDESTRING$$INT64
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_WIDESTRING$WIDESTRING$WIDESTRING$$INT64,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_WIDESTRING$WIDESTRING$WIDESTRING$$INT64:
.Lc107:
# [869] begin
	pushq	%rax
.Lc108:
# Var aLeft located in register rdi
# Var aRight located in register rsi
# [870] Result := WideCompareStr(aLeft, aRight);
	xorl	%edx,%edx
# Var aRight located in register rsi
# Var aLeft located in register rdi
	call	*U_$SYSTEM_$$_WIDESTRINGMANAGER+32
# Var $result located in register rax
# [871] end;
	popq	%rcx
.Lc109:
	ret
.Lc106:

.section .text.n_nextpas.core.collections.base_$$_compare_unicodestring$unicodestring$unicodestring$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_UNICODESTRING$UNICODESTRING$UNICODESTRING$$INT64
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_UNICODESTRING$UNICODESTRING$UNICODESTRING$$INT64,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_UNICODESTRING$UNICODESTRING$UNICODESTRING$$INT64:
.Lc111:
# [874] begin
	pushq	%rax
.Lc112:
# Var aLeft located in register rdi
# Var aRight located in register rsi
# [875] Result := UnicodeCompareStr(aLeft, aRight);
	xorl	%edx,%edx
# Var aRight located in register rsi
# Var aLeft located in register rdi
	call	*U_$SYSTEM_$$_WIDESTRINGMANAGER+184
# Var $result located in register rax
# [876] end;
	popq	%rcx
.Lc113:
	ret
.Lc110:

.section .text.n_nextpas.core.collections.base_$$_compare_pointer$pointer$pointer$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_POINTER$POINTER$POINTER$$INT64
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_POINTER$POINTER$POINTER$$INT64,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_POINTER$POINTER$POINTER$$INT64:
.Lc115:
# Var $result located in register rax
# Var aLeft located in register rdi
# Var aRight located in register rsi
# [879] begin
# [880] if aLeft > aRight then
	movl	$1,%ecx
	cmpq	%rdi,%rsi
# [881] Result := 1
	cmovbq	%rcx,%rax
	jb	.Lj171
# [882] else if aLeft < aRight then
	xorl	%edx,%edx
# [883] Result := -1
	movq	$-1,%rax
	cmpq	%rdi,%rsi
# [885] Result := 0;
	cmovnaq	%rdx,%rax
.Lj171:
.Lc116:
# [886] end;
	ret
.Lc114:

.section .text.n_nextpas.core.collections.base_$$_compare_bin$pointer$pointer$qword$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_BIN$POINTER$POINTER$QWORD$$INT64
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_BIN$POINTER$POINTER$QWORD$$INT64,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_BIN$POINTER$POINTER$QWORD$$INT64:
.Lc118:
# [889] begin
	pushq	%rbx
.Lc119:
# Var aLeft located in register rdi
# Var aRight located in register rsi
# Var aSize located in register rdx
# [890] Result := CompareMemRange(aLeft, aRight, aSize);
	xorl	%eax,%eax
	cmpq	%rdi,%rsi
	cmovel	%eax,%ebx
	je	.Lj179
	call	SYSTEM_$$_COMPAREBYTE$formal$formal$INT64$$INT64
	movl	%eax,%ebx
.Lj179:
	movslq	%ebx,%rax
# Var $result located in register rax
# [891] end;
	popq	%rbx
.Lc120:
	ret
.Lc117:
.Le3:
	.size	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_BIN$POINTER$POINTER$QWORD$$INT64, .Le3 - NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_BIN$POINTER$POINTER$QWORD$$INT64

.section .text.n_nextpas.core.collections.base_$$_equals_bool$boolean$boolean$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_BOOL$BOOLEAN$BOOLEAN$$BOOLEAN
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_BOOL$BOOLEAN$BOOLEAN$$BOOLEAN,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_BOOL$BOOLEAN$BOOLEAN$$BOOLEAN:
.Lc122:
# Var aLeft located in register dil
# Var aRight located in register sil
# [894] begin
# [895] Result := (aLeft = aRight);
	cmpb	%dil,%sil
# Var $result located in register al
	seteb	%al
.Lc123:
# [896] end;
	ret
.Lc121:

.section .text.n_nextpas.core.collections.base_$$_equals_char$ansichar$ansichar$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_CHAR$ANSICHAR$ANSICHAR$$BOOLEAN
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_CHAR$ANSICHAR$ANSICHAR$$BOOLEAN,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_CHAR$ANSICHAR$ANSICHAR$$BOOLEAN:
.Lc125:
# Var aLeft located in register dil
# Var aRight located in register sil
# [899] begin
# [900] Result := (aLeft = aRight);
	cmpb	%dil,%sil
# Var $result located in register al
	seteb	%al
.Lc126:
# [901] end;
	ret
.Lc124:

.section .text.n_nextpas.core.collections.base_$$_equals_wchar$widechar$widechar$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_WCHAR$WIDECHAR$WIDECHAR$$BOOLEAN
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_WCHAR$WIDECHAR$WIDECHAR$$BOOLEAN,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_WCHAR$WIDECHAR$WIDECHAR$$BOOLEAN:
.Lc128:
# Var aLeft located in register di
# Var aRight located in register si
# [904] begin
# [905] Result := (aLeft = aRight);
	cmpw	%di,%si
# Var $result located in register al
	seteb	%al
.Lc129:
# [906] end;
	ret
.Lc127:

.section .text.n_nextpas.core.collections.base_$$_equals_i8$shortint$shortint$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_I8$SHORTINT$SHORTINT$$BOOLEAN
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_I8$SHORTINT$SHORTINT$$BOOLEAN,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_I8$SHORTINT$SHORTINT$$BOOLEAN:
.Lc131:
# Var aLeft located in register dil
# Var aRight located in register sil
# [909] begin
# [910] Result := (aLeft = aRight);
	cmpb	%dil,%sil
# Var $result located in register al
	seteb	%al
.Lc132:
# [911] end;
	ret
.Lc130:

.section .text.n_nextpas.core.collections.base_$$_equals_i16$smallint$smallint$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_I16$SMALLINT$SMALLINT$$BOOLEAN
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_I16$SMALLINT$SMALLINT$$BOOLEAN,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_I16$SMALLINT$SMALLINT$$BOOLEAN:
.Lc134:
# Var aLeft located in register di
# Var aRight located in register si
# [914] begin
# [915] Result := (aLeft = aRight);
	cmpw	%di,%si
# Var $result located in register al
	seteb	%al
.Lc135:
# [916] end;
	ret
.Lc133:

.section .text.n_nextpas.core.collections.base_$$_equals_i32$longint$longint$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_I32$LONGINT$LONGINT$$BOOLEAN
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_I32$LONGINT$LONGINT$$BOOLEAN,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_I32$LONGINT$LONGINT$$BOOLEAN:
.Lc137:
# Var aLeft located in register edi
# Var aRight located in register esi
# [919] begin
# [920] Result := (aLeft = aRight);
	cmpl	%edi,%esi
# Var $result located in register al
	seteb	%al
.Lc138:
# [921] end;
	ret
.Lc136:

.section .text.n_nextpas.core.collections.base_$$_equals_i64$int64$int64$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_I64$INT64$INT64$$BOOLEAN
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_I64$INT64$INT64$$BOOLEAN,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_I64$INT64$INT64$$BOOLEAN:
.Lc140:
# Var aLeft located in register rdi
# Var aRight located in register rsi
# [924] begin
# [925] Result := (aLeft = aRight);
	cmpq	%rdi,%rsi
# Var $result located in register al
	seteb	%al
.Lc141:
# [926] end;
	ret
.Lc139:

.section .text.n_nextpas.core.collections.base_$$_equals_u8$byte$byte$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_U8$BYTE$BYTE$$BOOLEAN
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_U8$BYTE$BYTE$$BOOLEAN,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_U8$BYTE$BYTE$$BOOLEAN:
.Lc143:
# Var aLeft located in register dil
# Var aRight located in register sil
# [929] begin
# [930] Result := (aLeft = aRight);
	cmpb	%dil,%sil
# Var $result located in register al
	seteb	%al
.Lc144:
# [931] end;
	ret
.Lc142:

.section .text.n_nextpas.core.collections.base_$$_equals_u16$word$word$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_U16$WORD$WORD$$BOOLEAN
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_U16$WORD$WORD$$BOOLEAN,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_U16$WORD$WORD$$BOOLEAN:
.Lc146:
# Var aLeft located in register di
# Var aRight located in register si
# [934] begin
# [935] Result := (aLeft = aRight);
	cmpw	%di,%si
# Var $result located in register al
	seteb	%al
.Lc147:
# [936] end;
	ret
.Lc145:

.section .text.n_nextpas.core.collections.base_$$_equals_u32$longword$longword$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_U32$LONGWORD$LONGWORD$$BOOLEAN
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_U32$LONGWORD$LONGWORD$$BOOLEAN,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_U32$LONGWORD$LONGWORD$$BOOLEAN:
.Lc149:
# Var aLeft located in register edi
# Var aRight located in register esi
# [939] begin
# [940] Result := (aLeft = aRight);
	cmpl	%edi,%esi
# Var $result located in register al
	seteb	%al
.Lc150:
# [941] end;
	ret
.Lc148:

.section .text.n_nextpas.core.collections.base_$$_equals_u64$qword$qword$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_U64$QWORD$QWORD$$BOOLEAN
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_U64$QWORD$QWORD$$BOOLEAN,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_U64$QWORD$QWORD$$BOOLEAN:
.Lc152:
# Var aLeft located in register rdi
# Var aRight located in register rsi
# [944] begin
# [945] Result := (aLeft = aRight);
	cmpq	%rdi,%rsi
# Var $result located in register al
	seteb	%al
.Lc153:
# [946] end;
	ret
.Lc151:

.section .text.n_nextpas.core.collections.base_$$_equals_single$single$single$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_SINGLE$SINGLE$SINGLE$$BOOLEAN
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_SINGLE$SINGLE$SINGLE$$BOOLEAN,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_SINGLE$SINGLE$SINGLE$$BOOLEAN:
.Lc155:
# Var aLeft located in register xmm0
# Var aRight located in register xmm1
# [949] begin
# [950] Result := (aLeft = aRight);
	comiss	%xmm0,%xmm1
# Var $result located in register al
	setnpb	%dl
	seteb	%al
	andb	%dl,%al
.Lc156:
# [951] end;
	ret
.Lc154:

.section .text.n_nextpas.core.collections.base_$$_equals_double$double$double$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_DOUBLE$DOUBLE$DOUBLE$$BOOLEAN
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_DOUBLE$DOUBLE$DOUBLE$$BOOLEAN,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_DOUBLE$DOUBLE$DOUBLE$$BOOLEAN:
.Lc158:
# Var aLeft located in register xmm0
# Var aRight located in register xmm1
# [954] begin
# [955] Result := (aLeft = aRight);
	comisd	%xmm0,%xmm1
# Var $result located in register al
	setnpb	%dl
	seteb	%al
	andb	%dl,%al
.Lc159:
# [956] end;
	ret
.Lc157:

.section .text.n_nextpas.core.collections.base_$$_equals_extended$extended$extended$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_EXTENDED$EXTENDED$EXTENDED$$BOOLEAN
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_EXTENDED$EXTENDED$EXTENDED$$BOOLEAN,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_EXTENDED$EXTENDED$EXTENDED$$BOOLEAN:
.Lc161:
# [959] begin
	pushq	%rbp
.Lc162:
	movq	%rsp,%rbp
.Lc163:
# Var aLeft located at rbp+16, size=OS_F80
# Var aRight located at rbp+32, size=OS_F80
# [960] Result := (aLeft = aRight);
	fldt	32(%rsp)
	fldt	16(%rsp)
	fcomip	%st(1),%st(0)
	fstp	%st(0)
# Var $result located in register al
	setnpb	%dl
	seteb	%al
	andb	%dl,%al
.Lc164:
# [961] end;
	movq	%rbp,%rsp
.Lc165:
	popq	%rbp
	ret
.Lc160:

.section .text.n_nextpas.core.collections.base_$$_equals_currency$currency$currency$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_CURRENCY$CURRENCY$CURRENCY$$BOOLEAN
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_CURRENCY$CURRENCY$CURRENCY$$BOOLEAN,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_CURRENCY$CURRENCY$CURRENCY$$BOOLEAN:
.Lc167:
# [964] begin
	leaq	-24(%rsp),%rsp
.Lc168:
# Var aLeft located at rsp+0, size=OS_C64
# Var aRight located at rsp+8, size=OS_C64
	movq	%rdi,(%rsp)
	movq	%rsi,8(%rsp)
# [965] Result := (aLeft = aRight);
	fildq	8(%rsp)
	fildq	(%rsp)
	fcomip	%st(1),%st(0)
	fstp	%st(0)
# Var $result located in register al
	setnpb	%dl
	seteb	%al
	andb	%dl,%al
# [966] end;
	leaq	24(%rsp),%rsp
.Lc169:
	ret
.Lc166:

.section .text.n_nextpas.core.collections.base_$$_equals_comp$comp$comp$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_COMP$COMP$COMP$$BOOLEAN
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_COMP$COMP$COMP$$BOOLEAN,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_COMP$COMP$COMP$$BOOLEAN:
.Lc171:
# [969] begin
	leaq	-24(%rsp),%rsp
.Lc172:
# Var aLeft located at rsp+0, size=OS_C64
# Var aRight located at rsp+8, size=OS_C64
	movq	%rdi,(%rsp)
	movq	%rsi,8(%rsp)
# [970] Result := (aLeft = aRight);
	fildq	(%rsp)
	fildq	8(%rsp)
	fcomip	%st(1),%st(0)
	fstp	%st(0)
# Var $result located in register al
	setnpb	%dl
	seteb	%al
	andb	%dl,%al
# [971] end;
	leaq	24(%rsp),%rsp
.Lc173:
	ret
.Lc170:

.section .text.n_nextpas.core.collections.base_$$_equals_shortstring$shortstring$shortstring$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_SHORTSTRING$SHORTSTRING$SHORTSTRING$$BOOLEAN
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_SHORTSTRING$SHORTSTRING$SHORTSTRING$$BOOLEAN,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_SHORTSTRING$SHORTSTRING$SHORTSTRING$$BOOLEAN:
.Lc175:
# [974] begin
	pushq	%rax
.Lc176:
# Var aLeft located in register rdi
# Var aRight located in register rsi
# [975] Result := (aLeft = aRight);
	call	fpc_shortstr_compare_equal
	testl	%eax,%eax
# Var $result located in register al
	seteb	%al
# [976] end;
	popq	%rcx
.Lc177:
	ret
.Lc174:

.section .text.n_nextpas.core.collections.base_$$_equals_ansistring$ansistring$ansistring$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_ANSISTRING$ANSISTRING$ANSISTRING$$BOOLEAN
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_ANSISTRING$ANSISTRING$ANSISTRING$$BOOLEAN,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_ANSISTRING$ANSISTRING$ANSISTRING$$BOOLEAN:
.Lc179:
# [979] begin
	pushq	%rax
.Lc180:
# Var aLeft located in register rdi
# Var aRight located in register rsi
# [980] Result := (aLeft = aRight);
	call	fpc_ansistr_compare_equal
	testq	%rax,%rax
# Var $result located in register al
	seteb	%al
# [981] end;
	popq	%rcx
.Lc181:
	ret
.Lc178:

.section .text.n_nextpas.core.collections.base_$$_equals_widestring$widestring$widestring$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_WIDESTRING$WIDESTRING$WIDESTRING$$BOOLEAN
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_WIDESTRING$WIDESTRING$WIDESTRING$$BOOLEAN,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_WIDESTRING$WIDESTRING$WIDESTRING$$BOOLEAN:
.Lc183:
# [984] begin
	pushq	%rax
.Lc184:
# Var aLeft located in register rdi
# Var aRight located in register rsi
# [985] Result := (aLeft = aRight);
	call	fpc_unicodestr_compare_equal
	testq	%rax,%rax
# Var $result located in register al
	seteb	%al
# [986] end;
	popq	%rcx
.Lc185:
	ret
.Lc182:

.section .text.n_nextpas.core.collections.base_$$_equals_unicodestring$unicodestring$unicodestring$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_UNICODESTRING$UNICODESTRING$UNICODESTRING$$BOOLEAN
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_UNICODESTRING$UNICODESTRING$UNICODESTRING$$BOOLEAN,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_UNICODESTRING$UNICODESTRING$UNICODESTRING$$BOOLEAN:
.Lc187:
# [989] begin
	pushq	%rax
.Lc188:
# Var aLeft located in register rdi
# Var aRight located in register rsi
# [990] Result := (aLeft = aRight);
	call	fpc_unicodestr_compare_equal
	testq	%rax,%rax
# Var $result located in register al
	seteb	%al
# [991] end;
	popq	%rcx
.Lc189:
	ret
.Lc186:

.section .text.n_nextpas.core.collections.base_$$_equals_pointer$pointer$pointer$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_POINTER$POINTER$POINTER$$BOOLEAN
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_POINTER$POINTER$POINTER$$BOOLEAN,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_POINTER$POINTER$POINTER$$BOOLEAN:
.Lc191:
# Var aLeft located in register rdi
# Var aRight located in register rsi
# [994] begin
# [995] Result := (aLeft = aRight);
	cmpq	%rdi,%rsi
# Var $result located in register al
	seteb	%al
.Lc192:
# [996] end;
	ret
.Lc190:

.section .text.n_nextpas.core.collections.base_$$_equals_bin$pointer$pointer$qword$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_BIN$POINTER$POINTER$QWORD$$BOOLEAN
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_BIN$POINTER$POINTER$QWORD$$BOOLEAN,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_BIN$POINTER$POINTER$QWORD$$BOOLEAN:
.Lc194:
# [999] begin
	pushq	%rax
.Lc195:
# Var aLeft located in register rdi
# Var aRight located in register rsi
# Var aSize located in register rdx
# [1000] Result := (compare_bin(aLeft, aRight, aSize) = 0);
	call	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_BIN$POINTER$POINTER$QWORD$$INT64
	testq	%rax,%rax
# Var $result located in register al
	seteb	%al
# [1001] end;
	popq	%rcx
.Lc196:
	ret
.Lc193:

.section .text.n_nextpas.core.collections.base_$$_equals_variant$variant$variant$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_VARIANT$VARIANT$VARIANT$$BOOLEAN
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_VARIANT$VARIANT$VARIANT$$BOOLEAN,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_VARIANT$VARIANT$VARIANT$$BOOLEAN:
.Lc198:
# [1004] begin
	pushq	%rax
.Lc199:
# Var aLeft located in register rdi
# Var aRight located in register rsi
# [1005] Result := (VarCompareValue(aLeft, aRight) = vrEqual);
	call	VARIANTS_$$_VARCOMPAREVALUE$VARIANT$VARIANT$$TVARIANTRELATIONSHIP
	testl	%eax,%eax
# Var $result located in register al
	seteb	%al
# [1006] end;
	popq	%rcx
.Lc200:
	ret
.Lc197:

.section .text.n_nextpas.core.collections.base_$$_equals_string$ansistring$ansistring$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_STRING$ANSISTRING$ANSISTRING$$BOOLEAN
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_STRING$ANSISTRING$ANSISTRING$$BOOLEAN,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_STRING$ANSISTRING$ANSISTRING$$BOOLEAN:
.Lc202:
# [1009] begin
	pushq	%rax
.Lc203:
# Var aLeft located in register rdi
# Var aRight located in register rsi
# [1010] Result := (aLeft = aRight);
	call	fpc_ansistr_compare_equal
	testq	%rax,%rax
# Var $result located in register al
	seteb	%al
# [1011] end;
	popq	%rcx
.Lc204:
	ret
.Lc201:

.section .text.n_nextpas.core.collections.base_$$_equals_method$tmethod$tmethod$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_METHOD$TMETHOD$TMETHOD$$BOOLEAN
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_METHOD$TMETHOD$TMETHOD$$BOOLEAN,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_METHOD$TMETHOD$TMETHOD$$BOOLEAN:
.Lc206:
# Var aLeft located in register rsi:rdi
# Var aRight located in register rcx:rdx
# [1014] begin
# [1015] Result := (aLeft.Code = aRight.Code) and (aLeft.Data = aRight.Data);
	cmpq	%rdx,%rdi
	seteb	%al
	cmpq	%rcx,%rsi
	seteb	%dl
	andb	%dl,%al
# Var $result located in register al
.Lc207:
# [1016] end;
	ret
.Lc205:

.section .text.n_nextpas.core.collections.base_$$_equals_dynarray$pointer$pointer$qword$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_DYNARRAY$POINTER$POINTER$QWORD$$BOOLEAN
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_DYNARRAY$POINTER$POINTER$QWORD$$BOOLEAN,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_EQUALS_DYNARRAY$POINTER$POINTER$QWORD$$BOOLEAN:
.Lc209:
# [1021] begin
	pushq	%rbx
.Lc210:
	pushq	%r12
.Lc211:
	pushq	%r13
.Lc212:
	pushq	%r14
.Lc213:
	pushq	%rax
.Lc214:
	movq	%rdi,%rbx
# Var aLeft located in register rbx
	movq	%rsi,%r12
# Var aRight located in register r12
	movq	%rdx,%r13
# Var aElementSize located in register r13
# Var aLeft located in register rbx
# [1022] LLen := DynArraySize(aLeft);
	movq	%rbx,%rdi
	call	SYSTEM_$$_DYNARRAYSIZE$POINTER$$INT64
	movq	%rax,%r14
# Var LLen located in register r14
# [1023] Result := (LLen = DynArraySize(aRight)) and (compare_bin(aLeft, aRight, LLen * aElementSize) = 0);
	movq	%r12,%rdi
	call	SYSTEM_$$_DYNARRAYSIZE$POINTER$$INT64
	cmpq	%r14,%rax
	jne	.Lj233
	movq	%r14,%rdx
	imulq	%r13,%rdx
	movq	%r12,%rsi
	movq	%rbx,%rdi
	call	NEXTPAS.CORE.COLLECTIONS.BASE_$$_COMPARE_BIN$POINTER$POINTER$QWORD$$INT64
	testq	%rax,%rax
	seteb	%al
# Var $result located in register al
	jmp	.Lj235
.Lj233:
	xorb	%al,%al
.Lj235:
# [1024] end;
	popq	%rcx
	popq	%r14
.Lc215:
	popq	%r13
.Lc216:
	popq	%r12
.Lc217:
	popq	%rbx
.Lc218:
	ret
.Lc208:

.section .text.n_nextpas.core.collections.base$_$tptriter_$__$$_init$hcszgdt_ewna,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TPTRITER_$__$$_INIT$hCszGDt_EwnA
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TPTRITER_$__$$_INIT$hCszGDt_EwnA,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TPTRITER_$__$$_INIT$hCszGDt_EwnA:
.Lc220:
# Temps allocated between rbp-48 and rbp+0
# [1028] begin
	pushq	%rbp
.Lc221:
	movq	%rsp,%rbp
.Lc222:
	leaq	-48(%rsp),%rsp
	movq	%rbx,-48(%rbp)
	movq	%r12,-40(%rbp)
	movq	%r13,-32(%rbp)
	movq	%r14,-24(%rbp)
	movq	%r15,-16(%rbp)
	movq	%rdi,-8(%rbp)
# Var $self located in stack [rbp-8]
	movq	%rsi,%rbx
# Var aOwner located in register rbx
	movq	%rdx,%r12
	movq	%rcx,%r13
# Var aGetCurrent located in register r13:r12
	movq	%r8,%r14
	movq	%r9,%r15
# Var aMoveNext located in register r15:r14
# Var aMovePrev located in stack [rbp+24]:[rbp+16]
# Var aData located in stack [rbp+32]
# [1029] if aOwner = nil then
	testq	%rbx,%rbx
	jne	.Lj239
.Lj240:
# [1030] raise EArgumentNil.Create('TPtrIter.Init: Failed to init: aOwner is nil');
	movq	$.Ld3,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj240,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj239:
# [1032] if aGetCurrent = nil then
	testq	%r12,%r12
	jne	.Lj242
.Lj243:
# [1033] raise EArgumentNil.Create('TPtrIter.Init: Failed to init: aGetCurrent is nil');
	movq	$.Ld4,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj243,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj242:
# [1035] if aMoveNext = nil then
	testq	%r14,%r14
	jne	.Lj245
.Lj246:
# [1036] raise EArgumentNil.Create('TPtrIter.Init: Failed to init: aMoveNext is nil');
	movq	$.Ld5,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj246,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj245:
# [1038] Owner            := aOwner;
	movq	-8(%rbp),%rdx
# Var aOwner located in register rax
	movq	%rbx,48(%rdx)
# [1039] Data             := aData;
	movq	32(%rbp),%rax
	movq	-8(%rbp),%rdx
# Var aData located in register rax
	movq	%rax,64(%rdx)
# [1040] Started          := False;
	movq	-8(%rbp),%rax
	movb	$0,56(%rax)
# [1042] FGetCurrent      := aGetCurrent;
	movq	%r12,%rdx
	movq	%r13,%rax
	movq	-8(%rbp),%rcx
# Var aGetCurrent located in register rax:rdx
	movq	%rdx,(%rcx)
	movq	-8(%rbp),%rdx
	movq	%rax,8(%rdx)
# [1043] FMoveNext        := aMoveNext;
	movq	%r14,%rax
	movq	%r15,%rdx
	movq	-8(%rbp),%rcx
# Var aMoveNext located in register rdx:rax
	movq	%rax,16(%rcx)
	movq	-8(%rbp),%rax
	movq	%rdx,24(%rax)
# [1044] FMovePrev        := aMovePrev;
	movq	16(%rbp),%rdx
	movq	24(%rbp),%rax
	movq	-8(%rbp),%rcx
# Var aMovePrev located in register rax:rdx
	movq	%rdx,32(%rcx)
	movq	-8(%rbp),%rdx
	movq	%rax,40(%rdx)
# [1045] end;
	movq	-48(%rbp),%rbx
	movq	-40(%rbp),%r12
	movq	-32(%rbp),%r13
	movq	-24(%rbp),%r14
	movq	-16(%rbp),%r15
.Lc223:
	movq	%rbp,%rsp
.Lc224:
	popq	%rbp
	ret
.Lc219:
.Le4:
	.size	NEXTPAS.CORE.COLLECTIONS.BASE$_$TPTRITER_$__$$_INIT$hCszGDt_EwnA, .Le4 - NEXTPAS.CORE.COLLECTIONS.BASE$_$TPTRITER_$__$$_INIT$hCszGDt_EwnA

.section .text.n_nextpas.core.collections.base$_$tptriter_$__$$_init$hlnvbb47ea$n,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TPTRITER_$__$$_INIT$hLNvbB47ea$N
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TPTRITER_$__$$_INIT$hLNvbB47ea$N,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TPTRITER_$__$$_INIT$hLNvbB47ea$N:
.Lc226:
# [1048] begin
	pushq	%rbp
.Lc227:
	movq	%rsp,%rbp
.Lc228:
	leaq	-64(%rsp),%rsp
# Var $self located in register rdi
# Var aOwner located in register rsi
# Var aGetCurrent located in register rcx:rdx
# Var aMoveNext located in register r9:r8
# Var aData located in stack [rbp+16]
# [1049] Init(aOwner, aGetCurrent, aMoveNext, nil, aData);
	movq	16(%rbp),%rax
# Var aData located in register rax
	movq	%rax,16(%rsp)
	movq	$0,8(%rsp)
	movq	$0,(%rsp)
# Var aMoveNext located in register r9:r8
# Var aGetCurrent located in register rcx:rdx
# Var aOwner located in register rsi
	call	NEXTPAS.CORE.COLLECTIONS.BASE$_$TPTRITER_$__$$_INIT$hCszGDt_EwnA
.Lc229:
# [1050] end;
	movq	%rbp,%rsp
.Lc230:
	popq	%rbp
	ret
.Lc225:

.section .text.n_nextpas.core.collections.base$_$tptriter_$__$$_getstarted$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TPTRITER_$__$$_GETSTARTED$$BOOLEAN
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TPTRITER_$__$$_GETSTARTED$$BOOLEAN,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TPTRITER_$__$$_GETSTARTED$$BOOLEAN:
.Lc232:
# Var $self located in register rdi
# [1053] begin
# Var $result located in register al
# [1054] Result := Started;
	movb	56(%rdi),%al
.Lc233:
# [1055] end;
	ret
.Lc231:

.section .text.n_nextpas.core.collections.base$_$tptriter_$__$$_getcurrent$$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TPTRITER_$__$$_GETCURRENT$$POINTER
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TPTRITER_$__$$_GETCURRENT$$POINTER,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TPTRITER_$__$$_GETCURRENT$$POINTER:
.Lc235:
# [1058] begin
	pushq	%rax
.Lc236:
	movq	%rdi,%rax
# Var $self located in register rax
# [1059] Result := FGetCurrent(@Self);
	movq	%rdi,%rsi
	movq	8(%rdi),%rdi
	call	*(%rax)
# Var $result located in register rax
# [1060] end;
	popq	%rcx
.Lc237:
	ret
.Lc234:

.section .text.n_nextpas.core.collections.base$_$tptriter_$__$$_movenext$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TPTRITER_$__$$_MOVENEXT$$BOOLEAN
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TPTRITER_$__$$_MOVENEXT$$BOOLEAN,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TPTRITER_$__$$_MOVENEXT$$BOOLEAN:
.Lc239:
# [1063] begin
	pushq	%rax
.Lc240:
	movq	%rdi,%rax
# Var $self located in register rax
# [1064] Result := FMoveNext(@Self);
	movq	%rdi,%rsi
	movq	24(%rdi),%rdi
	call	*16(%rax)
# Var $result located in register al
# [1065] end;
	popq	%rcx
.Lc241:
	ret
.Lc238:

.section .text.n_nextpas.core.collections.base$_$tptriter_$__$$_moveprev$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TPTRITER_$__$$_MOVEPREV$$BOOLEAN
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TPTRITER_$__$$_MOVEPREV$$BOOLEAN,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TPTRITER_$__$$_MOVEPREV$$BOOLEAN:
.Lc243:
# [1068] begin
	pushq	%rbx
.Lc244:
	movq	%rdi,%rax
# Var $self located in register rax
# [1069] Result := FMovePrev <> nil;
	cmpq	$0,32(%rdi)
# Var $result located in register bl
	setneb	%bl
# [1071] if Result then
	je	.Lj258
# [1072] Result := FMovePrev(@Self);
	movq	%rax,%rsi
	movq	40(%rax),%rdi
	call	*32(%rax)
	movb	%al,%bl
.Lj258:
# [1073] end;
	movb	%bl,%al
	popq	%rbx
.Lc245:
	ret
.Lc242:

.section .text.n_nextpas.core.collections.base$_$tptriter_$__$$_reset,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TPTRITER_$__$$_RESET
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TPTRITER_$__$$_RESET,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TPTRITER_$__$$_RESET:
.Lc247:
# Var $self located in register rdi
# [1076] begin
# [1077] Started := False;
	movb	$0,56(%rdi)
.Lc248:
# [1078] end;
	ret
.Lc246:

.section .text.n_nextpas.core.collections.base$_$tcollection_$__$$_create$$tcollection,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$$TCOLLECTION
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$$TCOLLECTION,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$$TCOLLECTION:
.Lc250:
# Temps allocated between rsp+24 and rsp+224
# [1121] begin
	leaq	-232(%rsp),%rsp
.Lc251:
# Var $vmt located at rsp+0, size=OS_64
# Var $self located at rsp+8, size=OS_64
# Var $vmt_afterconstruction_local located at rsp+16, size=OS_S64
	movq	%rdi,8(%rsp)
	movq	%rsi,(%rsp)
	movq	$0,216(%rsp)
	cmpq	$1,(%rsp)
	jne	.Lj276
	movq	8(%rsp),%rdi
	movq	%rdi,%rax
	call	*104(%rdi)
	movq	%rax,8(%rsp)
.Lj276:
	cmpq	$0,8(%rsp)
	je	.Lj273
	leaq	24(%rsp),%rdx
	leaq	48(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,112(%rsp)
	testl	%eax,%eax
	jne	.Lj283
	movq	$-1,16(%rsp)
	leaq	120(%rsp),%rdx
	leaq	144(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,208(%rsp)
	testl	%eax,%eax
	jne	.Lj285
# [1122] Create(GetRtlAllocator());
	leaq	216(%rsp),%rdi
	call	NEXTPAS.CORE.MEM.ALLOCATOR_$$_GETRTLALLOCATOR$$IALLOCATOR
	movq	216(%rsp),%rdx
	xorl	%esi,%esi
	movq	8(%rsp),%rdi
	call	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$IALLOCATOR$$TCOLLECTION
.Lj285:
	call	fpc_popaddrstack
# [1123] end;
	leaq	216(%rsp),%rdi
	call	fpc_intf_decr_ref
	cmpl	$0,208(%rsp)
	je	.Lj284
	call	fpc_reraise
	movl	$0,208(%rsp)
	jmp	.Lj285
.Lj284:
	movq	$1,16(%rsp)
	cmpq	$0,8(%rsp)
	setneb	%al
	cmpq	$0,(%rsp)
	setneb	%dl
	andb	%dl,%al
	je	.Lj288
	movq	8(%rsp),%rdi
	movq	(%rdi),%rax
	call	*136(%rax)
.Lj288:
.Lj283:
	call	fpc_popaddrstack
	cmpl	$0,112(%rsp)
	je	.Lj281
	leaq	120(%rsp),%rdx
	leaq	144(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,208(%rsp)
	testl	%eax,%eax
	jne	.Lj289
	cmpq	$0,(%rsp)
	je	.Lj291
	movq	16(%rsp),%rsi
	movq	8(%rsp),%rdi
	movq	(%rdi),%rax
	call	*96(%rax)
.Lj291:
	call	fpc_popaddrstack
	call	fpc_reraise
.Lj289:
	call	fpc_popaddrstack
	cmpl	$0,208(%rsp)
	je	.Lj292
	call	fpc_raise_nested
.Lj292:
	call	fpc_doneexception
.Lj281:
.Lj273:
	movq	8(%rsp),%rax
	leaq	232(%rsp),%rsp
.Lc252:
	ret
.Lc249:

.section .text.n_nextpas.core.collections.base$_$tcollection_$__$$_create$iallocator$$tcollection,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$IALLOCATOR$$TCOLLECTION
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$IALLOCATOR$$TCOLLECTION,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$IALLOCATOR$$TCOLLECTION:
.Lc254:
# Temps allocated between rsp+32 and rsp+220
# [1126] begin
	leaq	-232(%rsp),%rsp
.Lc255:
# Var aAllocator located at rsp+0, size=OS_64
# Var $vmt located at rsp+8, size=OS_64
# Var $self located at rsp+16, size=OS_64
# Var $vmt_afterconstruction_local located at rsp+24, size=OS_S64
	movq	%rdi,16(%rsp)
	movq	%rsi,8(%rsp)
	movq	%rdx,(%rsp)
	movq	%rdx,%rdi
	call	fpc_intf_incr_ref
	cmpq	$1,8(%rsp)
	jne	.Lj296
	movq	16(%rsp),%rdi
	movq	%rdi,%rax
	call	*104(%rdi)
	movq	%rax,16(%rsp)
.Lj296:
	cmpq	$0,16(%rsp)
	je	.Lj293
	leaq	32(%rsp),%rdx
	leaq	56(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,120(%rsp)
	testl	%eax,%eax
	jne	.Lj303
	movq	$-1,24(%rsp)
	leaq	128(%rsp),%rdx
	leaq	152(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,216(%rsp)
	testl	%eax,%eax
	jne	.Lj305
# [1127] Create(aAllocator, nil);
	movq	(%rsp),%rdx
	xorl	%ecx,%ecx
	xorl	%esi,%esi
	movq	16(%rsp),%rdi
	movq	(%rdi),%rax
	call	*208(%rax)
.Lj305:
	call	fpc_popaddrstack
# [1128] end;
	movq	%rsp,%rdi
	call	fpc_intf_decr_ref
	cmpl	$0,216(%rsp)
	je	.Lj304
	call	fpc_reraise
	movl	$0,216(%rsp)
	jmp	.Lj305
.Lj304:
	movq	$1,24(%rsp)
	cmpq	$0,16(%rsp)
	setneb	%al
	cmpq	$0,8(%rsp)
	setneb	%dl
	andb	%dl,%al
	je	.Lj308
	movq	16(%rsp),%rdi
	movq	(%rdi),%rax
	call	*136(%rax)
.Lj308:
.Lj303:
	call	fpc_popaddrstack
	cmpl	$0,120(%rsp)
	je	.Lj301
	leaq	128(%rsp),%rdx
	leaq	152(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,216(%rsp)
	testl	%eax,%eax
	jne	.Lj309
	cmpq	$0,8(%rsp)
	je	.Lj311
	movq	24(%rsp),%rsi
	movq	16(%rsp),%rdi
	movq	(%rdi),%rax
	call	*96(%rax)
.Lj311:
	call	fpc_popaddrstack
	call	fpc_reraise
.Lj309:
	call	fpc_popaddrstack
	cmpl	$0,216(%rsp)
	je	.Lj312
	call	fpc_raise_nested
.Lj312:
	call	fpc_doneexception
.Lj301:
.Lj293:
	movq	16(%rsp),%rax
	leaq	232(%rsp),%rsp
.Lc256:
	ret
.Lc253:
.Le5:
	.size	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$IALLOCATOR$$TCOLLECTION, .Le5 - NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$IALLOCATOR$$TCOLLECTION

.section .text.n_nextpas.core.collections.base$_$tcollection_$__$$_create$iallocator$pointer$$tcollection,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$IALLOCATOR$POINTER$$TCOLLECTION
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$IALLOCATOR$POINTER$$TCOLLECTION,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$IALLOCATOR$POINTER$$TCOLLECTION:
.Lc258:
# Temps allocated between rsp+40 and rsp+240
# [1131] begin
	leaq	-248(%rsp),%rsp
.Lc259:
# Var aAllocator located at rsp+0, size=OS_64
# Var aData located at rsp+8, size=OS_64
# Var $vmt located at rsp+16, size=OS_64
# Var $self located at rsp+24, size=OS_64
# Var $vmt_afterconstruction_local located at rsp+32, size=OS_S64
	movq	%rdi,24(%rsp)
	movq	%rsi,16(%rsp)
	movq	%rdx,(%rsp)
	movq	%rcx,8(%rsp)
	movq	(%rsp),%rdi
	call	fpc_intf_incr_ref
	movq	$0,232(%rsp)
	cmpq	$1,16(%rsp)
	jne	.Lj316
	movq	24(%rsp),%rdi
	movq	%rdi,%rax
	call	*104(%rdi)
	movq	%rax,24(%rsp)
.Lj316:
	cmpq	$0,24(%rsp)
	je	.Lj313
	leaq	40(%rsp),%rdx
	leaq	64(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,128(%rsp)
	testl	%eax,%eax
	jne	.Lj323
	movq	$-1,32(%rsp)
	leaq	136(%rsp),%rdx
	leaq	160(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,224(%rsp)
	testl	%eax,%eax
	jne	.Lj325
# [1132] inherited Create;
	xorl	%esi,%esi
	movq	24(%rsp),%rdi
	call	SYSTEM$_$TOBJECT_$__$$_CREATE$$TOBJECT
# [1133] FData := aData;
	movq	24(%rsp),%rdx
	movq	8(%rsp),%rax
	movq	%rax,32(%rdx)
# [1135] if aAllocator = nil then
	cmpq	$0,(%rsp)
	jne	.Lj328
# [1136] FAllocator := GetRtlAllocator()
	leaq	232(%rsp),%rdi
	call	NEXTPAS.CORE.MEM.ALLOCATOR_$$_GETRTLALLOCATOR$$IALLOCATOR
	movq	232(%rsp),%rsi
	movq	24(%rsp),%rax
	leaq	40(%rax),%rdi
	call	fpc_intf_assign
	jmp	.Lj329
	.p2align 4,,10
	.p2align 3
.Lj328:
# [1138] FAllocator := aAllocator;
	movq	24(%rsp),%rax
	leaq	40(%rax),%rdi
	movq	(%rsp),%rsi
	call	fpc_intf_assign
.Lj329:
.Lj325:
	call	fpc_popaddrstack
# [1139] end;
	movq	%rsp,%rdi
	call	fpc_intf_decr_ref
	leaq	232(%rsp),%rdi
	call	fpc_intf_decr_ref
	cmpl	$0,224(%rsp)
	je	.Lj324
	call	fpc_reraise
	movl	$0,224(%rsp)
	jmp	.Lj325
.Lj324:
	movq	$1,32(%rsp)
	cmpq	$0,24(%rsp)
	setneb	%al
	cmpq	$0,16(%rsp)
	setneb	%dl
	andb	%dl,%al
	je	.Lj331
	movq	24(%rsp),%rdi
	movq	(%rdi),%rax
	call	*136(%rax)
.Lj331:
.Lj323:
	call	fpc_popaddrstack
	cmpl	$0,128(%rsp)
	je	.Lj321
	leaq	136(%rsp),%rdx
	leaq	160(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,224(%rsp)
	testl	%eax,%eax
	jne	.Lj332
	cmpq	$0,16(%rsp)
	je	.Lj334
	movq	32(%rsp),%rsi
	movq	24(%rsp),%rdi
	movq	(%rdi),%rax
	call	*96(%rax)
.Lj334:
	call	fpc_popaddrstack
	call	fpc_reraise
.Lj332:
	call	fpc_popaddrstack
	cmpl	$0,224(%rsp)
	je	.Lj335
	call	fpc_raise_nested
.Lj335:
	call	fpc_doneexception
.Lj321:
.Lj313:
	movq	24(%rsp),%rax
	leaq	248(%rsp),%rsp
.Lc260:
	ret
.Lc257:
.Le6:
	.size	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$IALLOCATOR$POINTER$$TCOLLECTION, .Le6 - NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$IALLOCATOR$POINTER$$TCOLLECTION

.section .text.n_nextpas.core.collections.base$_$tcollection_$__$$_create$tcollection$$tcollection,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$TCOLLECTION$$TCOLLECTION
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$TCOLLECTION$$TCOLLECTION,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$TCOLLECTION$$TCOLLECTION:
.Lc262:
# Temps allocated between rbp-240 and rbp-32
# [1142] begin
	pushq	%rbp
.Lc263:
	movq	%rsp,%rbp
.Lc264:
	leaq	-240(%rsp),%rsp
	movq	%rbx,-240(%rbp)
# Var aSrc located at rbp-8, size=OS_64
# Var $vmt located at rbp-16, size=OS_64
# Var $self located at rbp-24, size=OS_64
# Var $vmt_afterconstruction_local located at rbp-32, size=OS_S64
	movq	%rdi,-24(%rbp)
	movq	%rsi,-16(%rbp)
	movq	%rdx,-8(%rbp)
	movq	$0,-232(%rbp)
	cmpq	$1,-16(%rbp)
	jne	.Lj339
	movq	-24(%rbp),%rdi
	movq	%rdi,%rax
	call	*104(%rdi)
	movq	%rax,-24(%rbp)
.Lj339:
	cmpq	$0,-24(%rbp)
	je	.Lj336
	leaq	-56(%rbp),%rdx
	leaq	-120(%rbp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,-124(%rbp)
	testl	%eax,%eax
	jne	.Lj346
	movq	$-1,-32(%rbp)
	leaq	-152(%rbp),%rdx
	leaq	-216(%rbp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,-220(%rbp)
	testl	%eax,%eax
	jne	.Lj348
# [1143] if aSrc = nil then
	cmpq	$0,-8(%rbp)
	jne	.Lj351
.Lj352:
# [1144] raise EArgumentNil.Create('TCollection.Create: aSrc is nil');
	movq	$.Ld6,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj352,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj351:
# [1146] Create(aSrc, aSrc.GetAllocator, aSrc.Data);
	movq	-8(%rbp),%rdi
	call	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_GETDATA$$POINTER
	movq	%rax,%rbx
	leaq	-232(%rbp),%rsi
	movq	-8(%rbp),%rdi
	call	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_GETALLOCATOR$$IALLOCATOR
	movq	-232(%rbp),%rcx
	movq	-8(%rbp),%rdx
	xorl	%esi,%esi
	movq	-24(%rbp),%rdi
	movq	%rbx,%r8
	call	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$TCOLLECTION$IALLOCATOR$POINTER$$TCOLLECTION
.Lj348:
	call	fpc_popaddrstack
# [1147] end;
	leaq	-232(%rbp),%rdi
	call	fpc_intf_decr_ref
	cmpl	$0,-220(%rbp)
	je	.Lj347
	call	fpc_reraise
	movl	$0,-220(%rbp)
	jmp	.Lj348
.Lj347:
	movq	$1,-32(%rbp)
	cmpq	$0,-24(%rbp)
	setneb	%al
	cmpq	$0,-16(%rbp)
	setneb	%dl
	andb	%dl,%al
	je	.Lj354
	movq	-24(%rbp),%rdi
	movq	(%rdi),%rax
	call	*136(%rax)
.Lj354:
.Lj346:
	call	fpc_popaddrstack
	cmpl	$0,-124(%rbp)
	je	.Lj344
	leaq	-152(%rbp),%rdx
	leaq	-216(%rbp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,-220(%rbp)
	testl	%eax,%eax
	jne	.Lj355
	cmpq	$0,-16(%rbp)
	je	.Lj357
	movq	-32(%rbp),%rsi
	movq	-24(%rbp),%rdi
	movq	(%rdi),%rax
	call	*96(%rax)
.Lj357:
	call	fpc_popaddrstack
	call	fpc_reraise
.Lj355:
	call	fpc_popaddrstack
	cmpl	$0,-220(%rbp)
	je	.Lj358
	call	fpc_raise_nested
.Lj358:
	call	fpc_doneexception
.Lj344:
.Lj336:
	movq	-24(%rbp),%rax
	movq	-240(%rbp),%rbx
.Lc265:
	movq	%rbp,%rsp
.Lc266:
	popq	%rbp
	ret
.Lc261:
.Le7:
	.size	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$TCOLLECTION$$TCOLLECTION, .Le7 - NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$TCOLLECTION$$TCOLLECTION

.section .text.n_nextpas.core.collections.base$_$tcollection_$__$$_create$tcollection$iallocator$$tcollection,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$TCOLLECTION$IALLOCATOR$$TCOLLECTION
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$TCOLLECTION$IALLOCATOR$$TCOLLECTION,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$TCOLLECTION$IALLOCATOR$$TCOLLECTION:
.Lc268:
# Temps allocated between rbp-228 and rbp-40
# [1150] begin
	pushq	%rbp
.Lc269:
	movq	%rsp,%rbp
.Lc270:
	leaq	-240(%rsp),%rsp
# Var aSrc located at rbp-8, size=OS_64
# Var aAllocator located at rbp-16, size=OS_64
# Var $vmt located at rbp-24, size=OS_64
# Var $self located at rbp-32, size=OS_64
# Var $vmt_afterconstruction_local located at rbp-40, size=OS_S64
	movq	%rdi,-32(%rbp)
	movq	%rsi,-24(%rbp)
	movq	%rdx,-8(%rbp)
	movq	%rcx,-16(%rbp)
	movq	%rcx,%rdi
	call	fpc_intf_incr_ref
	cmpq	$1,-24(%rbp)
	jne	.Lj362
	movq	-32(%rbp),%rdi
	movq	%rdi,%rax
	call	*104(%rdi)
	movq	%rax,-32(%rbp)
.Lj362:
	cmpq	$0,-32(%rbp)
	je	.Lj359
	leaq	-64(%rbp),%rdx
	leaq	-128(%rbp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,-132(%rbp)
	testl	%eax,%eax
	jne	.Lj369
	movq	$-1,-40(%rbp)
	leaq	-160(%rbp),%rdx
	leaq	-224(%rbp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,-228(%rbp)
	testl	%eax,%eax
	jne	.Lj371
# [1151] if aSrc = nil then
	cmpq	$0,-8(%rbp)
	jne	.Lj374
.Lj375:
# [1152] raise EArgumentNil.Create('TCollection.Create: aSrc is nil');
	movq	$.Ld6,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj375,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj374:
# [1154] Create(aSrc, aAllocator, aSrc.Data);
	movq	-8(%rbp),%rdi
	call	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_GETDATA$$POINTER
	movq	%rax,%r8
	movq	-16(%rbp),%rcx
	movq	-8(%rbp),%rdx
	xorl	%esi,%esi
	movq	-32(%rbp),%rdi
	call	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$TCOLLECTION$IALLOCATOR$POINTER$$TCOLLECTION
.Lj371:
	call	fpc_popaddrstack
# [1155] end;
	leaq	-16(%rbp),%rdi
	call	fpc_intf_decr_ref
	cmpl	$0,-228(%rbp)
	je	.Lj370
	call	fpc_reraise
	movl	$0,-228(%rbp)
	jmp	.Lj371
.Lj370:
	movq	$1,-40(%rbp)
	cmpq	$0,-32(%rbp)
	setneb	%al
	cmpq	$0,-24(%rbp)
	setneb	%dl
	andb	%dl,%al
	je	.Lj377
	movq	-32(%rbp),%rdi
	movq	(%rdi),%rax
	call	*136(%rax)
.Lj377:
.Lj369:
	call	fpc_popaddrstack
	cmpl	$0,-132(%rbp)
	je	.Lj367
	leaq	-160(%rbp),%rdx
	leaq	-224(%rbp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,-228(%rbp)
	testl	%eax,%eax
	jne	.Lj378
	cmpq	$0,-24(%rbp)
	je	.Lj380
	movq	-40(%rbp),%rsi
	movq	-32(%rbp),%rdi
	movq	(%rdi),%rax
	call	*96(%rax)
.Lj380:
	call	fpc_popaddrstack
	call	fpc_reraise
.Lj378:
	call	fpc_popaddrstack
	cmpl	$0,-228(%rbp)
	je	.Lj381
	call	fpc_raise_nested
.Lj381:
	call	fpc_doneexception
.Lj367:
.Lj359:
	movq	-32(%rbp),%rax
.Lc271:
	movq	%rbp,%rsp
.Lc272:
	popq	%rbp
	ret
.Lc267:

.section .text.n_nextpas.core.collections.base$_$tcollection_$__$$_create$tcollection$iallocator$pointer$$tcollection,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$TCOLLECTION$IALLOCATOR$POINTER$$TCOLLECTION
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$TCOLLECTION$IALLOCATOR$POINTER$$TCOLLECTION,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$TCOLLECTION$IALLOCATOR$POINTER$$TCOLLECTION:
.Lc274:
# Temps allocated between rsp+48 and rsp+236
# [1158] begin
	leaq	-248(%rsp),%rsp
.Lc275:
# Var aSrc located at rsp+0, size=OS_64
# Var aAllocator located at rsp+8, size=OS_64
# Var aData located at rsp+16, size=OS_64
# Var $vmt located at rsp+24, size=OS_64
# Var $self located at rsp+32, size=OS_64
# Var $vmt_afterconstruction_local located at rsp+40, size=OS_S64
	movq	%rdi,32(%rsp)
	movq	%rsi,24(%rsp)
	movq	%rdx,(%rsp)
	movq	%rcx,8(%rsp)
	movq	%r8,16(%rsp)
	movq	8(%rsp),%rdi
	call	fpc_intf_incr_ref
	cmpq	$1,24(%rsp)
	jne	.Lj385
	movq	32(%rsp),%rdi
	movq	%rdi,%rax
	call	*104(%rdi)
	movq	%rax,32(%rsp)
.Lj385:
	cmpq	$0,32(%rsp)
	je	.Lj382
	leaq	48(%rsp),%rdx
	leaq	72(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,136(%rsp)
	testl	%eax,%eax
	jne	.Lj392
	movq	$-1,40(%rsp)
	leaq	144(%rsp),%rdx
	leaq	168(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,232(%rsp)
	testl	%eax,%eax
	jne	.Lj394
# [1159] Create(aAllocator, aData);
	movq	8(%rsp),%rdx
	movq	16(%rsp),%rcx
	xorl	%esi,%esi
	movq	32(%rsp),%rdi
	movq	(%rdi),%rax
	call	*208(%rax)
# [1160] LoadFrom(aSrc);
	movq	(%rsp),%rsi
	movq	32(%rsp),%rdi
	call	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_LOADFROM$TCOLLECTION
.Lj394:
	call	fpc_popaddrstack
# [1161] end;
	leaq	8(%rsp),%rdi
	call	fpc_intf_decr_ref
	cmpl	$0,232(%rsp)
	je	.Lj393
	call	fpc_reraise
	movl	$0,232(%rsp)
	jmp	.Lj394
.Lj393:
	movq	$1,40(%rsp)
	cmpq	$0,32(%rsp)
	setneb	%al
	cmpq	$0,24(%rsp)
	setneb	%dl
	andb	%dl,%al
	je	.Lj397
	movq	32(%rsp),%rdi
	movq	(%rdi),%rax
	call	*136(%rax)
.Lj397:
.Lj392:
	call	fpc_popaddrstack
	cmpl	$0,136(%rsp)
	je	.Lj390
	leaq	144(%rsp),%rdx
	leaq	168(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,232(%rsp)
	testl	%eax,%eax
	jne	.Lj398
	cmpq	$0,24(%rsp)
	je	.Lj400
	movq	40(%rsp),%rsi
	movq	32(%rsp),%rdi
	movq	(%rdi),%rax
	call	*96(%rax)
.Lj400:
	call	fpc_popaddrstack
	call	fpc_reraise
.Lj398:
	call	fpc_popaddrstack
	cmpl	$0,232(%rsp)
	je	.Lj401
	call	fpc_raise_nested
.Lj401:
	call	fpc_doneexception
.Lj390:
.Lj382:
	movq	32(%rsp),%rax
	leaq	248(%rsp),%rsp
.Lc276:
	ret
.Lc273:
.Le8:
	.size	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$TCOLLECTION$IALLOCATOR$POINTER$$TCOLLECTION, .Le8 - NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$TCOLLECTION$IALLOCATOR$POINTER$$TCOLLECTION

.section .text.n_nextpas.core.collections.base$_$tcollection_$__$$_create$pointer$qword$$tcollection,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$POINTER$QWORD$$TCOLLECTION
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$POINTER$QWORD$$TCOLLECTION,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$POINTER$QWORD$$TCOLLECTION:
.Lc278:
# Temps allocated between rsp+40 and rsp+240
# [1164] begin
	leaq	-248(%rsp),%rsp
.Lc279:
# Var aSrc located at rsp+0, size=OS_64
# Var aElementCount located at rsp+8, size=OS_64
# Var $vmt located at rsp+16, size=OS_64
# Var $self located at rsp+24, size=OS_64
# Var $vmt_afterconstruction_local located at rsp+32, size=OS_S64
	movq	%rdi,24(%rsp)
	movq	%rsi,16(%rsp)
	movq	%rdx,(%rsp)
	movq	%rcx,8(%rsp)
	movq	$0,232(%rsp)
	cmpq	$1,16(%rsp)
	jne	.Lj405
	movq	24(%rsp),%rdi
	movq	%rdi,%rax
	call	*104(%rdi)
	movq	%rax,24(%rsp)
.Lj405:
	cmpq	$0,24(%rsp)
	je	.Lj402
	leaq	40(%rsp),%rdx
	leaq	64(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,128(%rsp)
	testl	%eax,%eax
	jne	.Lj412
	movq	$-1,32(%rsp)
	leaq	136(%rsp),%rdx
	leaq	160(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,224(%rsp)
	testl	%eax,%eax
	jne	.Lj414
# [1165] Create(aSrc, aElementCount, GetRtlAllocator(), nil);
	leaq	232(%rsp),%rdi
	call	NEXTPAS.CORE.MEM.ALLOCATOR_$$_GETRTLALLOCATOR$$IALLOCATOR
	movq	232(%rsp),%r8
	xorl	%r9d,%r9d
	movq	8(%rsp),%rcx
	movq	(%rsp),%rdx
	xorl	%esi,%esi
	movq	24(%rsp),%rdi
	call	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$hiVoPFUvGVKE
.Lj414:
	call	fpc_popaddrstack
# [1166] end;
	leaq	232(%rsp),%rdi
	call	fpc_intf_decr_ref
	cmpl	$0,224(%rsp)
	je	.Lj413
	call	fpc_reraise
	movl	$0,224(%rsp)
	jmp	.Lj414
.Lj413:
	movq	$1,32(%rsp)
	cmpq	$0,24(%rsp)
	setneb	%al
	cmpq	$0,16(%rsp)
	setneb	%dl
	andb	%dl,%al
	je	.Lj417
	movq	24(%rsp),%rdi
	movq	(%rdi),%rax
	call	*136(%rax)
.Lj417:
.Lj412:
	call	fpc_popaddrstack
	cmpl	$0,128(%rsp)
	je	.Lj410
	leaq	136(%rsp),%rdx
	leaq	160(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,224(%rsp)
	testl	%eax,%eax
	jne	.Lj418
	cmpq	$0,16(%rsp)
	je	.Lj420
	movq	32(%rsp),%rsi
	movq	24(%rsp),%rdi
	movq	(%rdi),%rax
	call	*96(%rax)
.Lj420:
	call	fpc_popaddrstack
	call	fpc_reraise
.Lj418:
	call	fpc_popaddrstack
	cmpl	$0,224(%rsp)
	je	.Lj421
	call	fpc_raise_nested
.Lj421:
	call	fpc_doneexception
.Lj410:
.Lj402:
	movq	24(%rsp),%rax
	leaq	248(%rsp),%rsp
.Lc280:
	ret
.Lc277:

.section .text.n_nextpas.core.collections.base$_$tcollection_$__$$_create$pointer$qword$iallocator$$tcollection,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$POINTER$QWORD$IALLOCATOR$$TCOLLECTION
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$POINTER$QWORD$IALLOCATOR$$TCOLLECTION,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$POINTER$QWORD$IALLOCATOR$$TCOLLECTION:
.Lc282:
# Temps allocated between rsp+48 and rsp+236
# [1169] begin
	leaq	-248(%rsp),%rsp
.Lc283:
# Var aSrc located at rsp+0, size=OS_64
# Var aElementCount located at rsp+8, size=OS_64
# Var aAllocator located at rsp+16, size=OS_64
# Var $vmt located at rsp+24, size=OS_64
# Var $self located at rsp+32, size=OS_64
# Var $vmt_afterconstruction_local located at rsp+40, size=OS_S64
	movq	%rdi,32(%rsp)
	movq	%rsi,24(%rsp)
	movq	%rdx,(%rsp)
	movq	%rcx,8(%rsp)
	movq	%r8,16(%rsp)
	movq	%r8,%rdi
	call	fpc_intf_incr_ref
	cmpq	$1,24(%rsp)
	jne	.Lj425
	movq	32(%rsp),%rdi
	movq	%rdi,%rax
	call	*104(%rdi)
	movq	%rax,32(%rsp)
.Lj425:
	cmpq	$0,32(%rsp)
	je	.Lj422
	leaq	48(%rsp),%rdx
	leaq	72(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,136(%rsp)
	testl	%eax,%eax
	jne	.Lj432
	movq	$-1,40(%rsp)
	leaq	144(%rsp),%rdx
	leaq	168(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,232(%rsp)
	testl	%eax,%eax
	jne	.Lj434
# [1170] Create(aSrc, aElementCount, aAllocator, nil);
	movq	16(%rsp),%r8
	xorl	%r9d,%r9d
	movq	8(%rsp),%rcx
	movq	(%rsp),%rdx
	xorl	%esi,%esi
	movq	32(%rsp),%rdi
	call	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$hiVoPFUvGVKE
.Lj434:
	call	fpc_popaddrstack
# [1171] end;
	leaq	16(%rsp),%rdi
	call	fpc_intf_decr_ref
	cmpl	$0,232(%rsp)
	je	.Lj433
	call	fpc_reraise
	movl	$0,232(%rsp)
	jmp	.Lj434
.Lj433:
	movq	$1,40(%rsp)
	cmpq	$0,32(%rsp)
	setneb	%al
	cmpq	$0,24(%rsp)
	setneb	%dl
	andb	%dl,%al
	je	.Lj437
	movq	32(%rsp),%rdi
	movq	(%rdi),%rax
	call	*136(%rax)
.Lj437:
.Lj432:
	call	fpc_popaddrstack
	cmpl	$0,136(%rsp)
	je	.Lj430
	leaq	144(%rsp),%rdx
	leaq	168(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,232(%rsp)
	testl	%eax,%eax
	jne	.Lj438
	cmpq	$0,24(%rsp)
	je	.Lj440
	movq	40(%rsp),%rsi
	movq	32(%rsp),%rdi
	movq	(%rdi),%rax
	call	*96(%rax)
.Lj440:
	call	fpc_popaddrstack
	call	fpc_reraise
.Lj438:
	call	fpc_popaddrstack
	cmpl	$0,232(%rsp)
	je	.Lj441
	call	fpc_raise_nested
.Lj441:
	call	fpc_doneexception
.Lj430:
.Lj422:
	movq	32(%rsp),%rax
	leaq	248(%rsp),%rsp
.Lc284:
	ret
.Lc281:

.section .text.n_nextpas.core.collections.base$_$tcollection_$__$$_create$hivopfuvgvke,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$hiVoPFUvGVKE
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$hiVoPFUvGVKE,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$hiVoPFUvGVKE:
.Lc286:
# Temps allocated between rsp+56 and rsp+244
# [1174] begin
	leaq	-248(%rsp),%rsp
.Lc287:
# Var aSrc located at rsp+0, size=OS_64
# Var aElementCount located at rsp+8, size=OS_64
# Var aAllocator located at rsp+16, size=OS_64
# Var aData located at rsp+24, size=OS_64
# Var $vmt located at rsp+32, size=OS_64
# Var $self located at rsp+40, size=OS_64
# Var $vmt_afterconstruction_local located at rsp+48, size=OS_S64
	movq	%rdi,40(%rsp)
	movq	%rsi,32(%rsp)
	movq	%rdx,(%rsp)
	movq	%rcx,8(%rsp)
	movq	%r8,16(%rsp)
	movq	%r9,24(%rsp)
	movq	16(%rsp),%rdi
	call	fpc_intf_incr_ref
	cmpq	$1,32(%rsp)
	jne	.Lj445
	movq	40(%rsp),%rdi
	movq	%rdi,%rax
	call	*104(%rdi)
	movq	%rax,40(%rsp)
.Lj445:
	cmpq	$0,40(%rsp)
	je	.Lj442
	leaq	56(%rsp),%rdx
	leaq	80(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,144(%rsp)
	testl	%eax,%eax
	jne	.Lj452
	movq	$-1,48(%rsp)
	leaq	152(%rsp),%rdx
	leaq	176(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,240(%rsp)
	testl	%eax,%eax
	jne	.Lj454
# [1175] Create(aAllocator, aData);
	movq	16(%rsp),%rdx
	movq	24(%rsp),%rcx
	xorl	%esi,%esi
	movq	40(%rsp),%rdi
	movq	(%rdi),%rax
	call	*208(%rax)
# [1176] LoadFrom(aSrc, aElementCount);
	movq	8(%rsp),%rdx
	movq	(%rsp),%rsi
	movq	40(%rsp),%rdi
	movq	(%rdi),%rax
	call	*264(%rax)
.Lj454:
	call	fpc_popaddrstack
# [1177] end;
	leaq	16(%rsp),%rdi
	call	fpc_intf_decr_ref
	cmpl	$0,240(%rsp)
	je	.Lj453
	call	fpc_reraise
	movl	$0,240(%rsp)
	jmp	.Lj454
.Lj453:
	movq	$1,48(%rsp)
	cmpq	$0,40(%rsp)
	setneb	%al
	cmpq	$0,32(%rsp)
	setneb	%dl
	andb	%dl,%al
	je	.Lj457
	movq	40(%rsp),%rdi
	movq	(%rdi),%rax
	call	*136(%rax)
.Lj457:
.Lj452:
	call	fpc_popaddrstack
	cmpl	$0,144(%rsp)
	je	.Lj450
	leaq	152(%rsp),%rdx
	leaq	176(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,240(%rsp)
	testl	%eax,%eax
	jne	.Lj458
	cmpq	$0,32(%rsp)
	je	.Lj460
	movq	48(%rsp),%rsi
	movq	40(%rsp),%rdi
	movq	(%rdi),%rax
	call	*96(%rax)
.Lj460:
	call	fpc_popaddrstack
	call	fpc_reraise
.Lj458:
	call	fpc_popaddrstack
	cmpl	$0,240(%rsp)
	je	.Lj461
	call	fpc_raise_nested
.Lj461:
	call	fpc_doneexception
.Lj450:
.Lj442:
	movq	40(%rsp),%rax
	leaq	248(%rsp),%rsp
.Lc288:
	ret
.Lc285:
.Le9:
	.size	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$hiVoPFUvGVKE, .Le9 - NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$hiVoPFUvGVKE

.section .text.n_nextpas.core.collections.base$_$tcollection_$__$$_getallocator$$iallocator,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_GETALLOCATOR$$IALLOCATOR
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_GETALLOCATOR$$IALLOCATOR,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_GETALLOCATOR$$IALLOCATOR:
.Lc290:
# [1180] begin
	pushq	%rax
.Lc291:
	movq	%rdi,%rax
# Var $self located in register rax
	movq	%rsi,%rdi
# Var $result located in register rdi
# [1181] Result := FAllocator;
	movq	40(%rax),%rsi
	call	fpc_intf_assign
# [1182] end;
	popq	%rcx
.Lc292:
	ret
.Lc289:
.Le10:
	.size	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_GETALLOCATOR$$IALLOCATOR, .Le10 - NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_GETALLOCATOR$$IALLOCATOR

.section .text.n_nextpas.core.collections.base$_$tcollection_$__$$_isempty$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_ISEMPTY$$BOOLEAN
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_ISEMPTY$$BOOLEAN,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_ISEMPTY$$BOOLEAN:
.Lc294:
# [1185] begin
	pushq	%rax
.Lc295:
# Var $self located in register rax
# [1186] Result := GetCount = 0;
	movq	(%rdi),%rax
	call	*224(%rax)
	testq	%rax,%rax
# Var $result located in register al
	seteb	%al
# [1187] end;
	popq	%rcx
.Lc296:
	ret
.Lc293:
.Le11:
	.size	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_ISEMPTY$$BOOLEAN, .Le11 - NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_ISEMPTY$$BOOLEAN

.section .text.n_nextpas.core.collections.base$_$tcollection_$__$$_getdata$$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_GETDATA$$POINTER
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_GETDATA$$POINTER,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_GETDATA$$POINTER:
.Lc298:
# Var $self located in register rdi
# [1190] begin
# Var $result located in register rax
# [1191] Result := FData;
	movq	32(%rdi),%rax
.Lc299:
# [1192] end;
	ret
.Lc297:
.Le12:
	.size	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_GETDATA$$POINTER, .Le12 - NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_GETDATA$$POINTER

.section .text.n_nextpas.core.collections.base$_$tcollection_$__$$_setdata$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_SETDATA$POINTER
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_SETDATA$POINTER,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_SETDATA$POINTER:
.Lc301:
# Var $self located in register rdi
# Var aData located in register rsi
# [1195] begin
# Var aData located in register rsi
# [1196] FData := aData;
	movq	%rsi,32(%rdi)
.Lc302:
# [1197] end;
	ret
.Lc300:

.section .text.n_nextpas.core.collections.base$_$tcollection_$__$$_clone$$tcollection,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CLONE$$TCOLLECTION
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CLONE$$TCOLLECTION,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CLONE$$TCOLLECTION:
.Lc304:
# Temps allocated between rbp-240 and rbp-24
# [1202] begin
	pushq	%rbp
.Lc305:
	movq	%rsp,%rbp
.Lc306:
	leaq	-240(%rsp),%rsp
# Var $self located at rbp-8, size=OS_64
# Var $result located at rbp-16, size=OS_64
# Var LCollectionClass located at rbp-24, size=OS_64
	movq	%rdi,-8(%rbp)
# [1204] if Self = nil then
	testq	%rdi,%rdi
	jne	.Lj473
.Lj474:
# [1205] raise EArgumentNil.Create('TCollection.Clone: Self is nil');
	movq	$.Ld7,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj474,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj473:
# [1208] if Self.ClassType = nil then
	movq	-8(%rbp),%rax
	cmpq	$0,(%rax)
	jne	.Lj476
.Lj477:
# [1209] raise EInvalidArgument.Create('TCollection.Clone: Self.ClassType is nil');
	movq	$.Ld8,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj477,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj476:
# [1212] try
	leaq	-48(%rbp),%rdx
	leaq	-112(%rbp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,-116(%rbp)
	testl	%eax,%eax
	jne	.Lj482
# [1213] LCollectionClass := TCollectionClass(Self.ClassType);
	movq	-8(%rbp),%rax
	movq	(%rax),%rax
	movq	%rax,-24(%rbp)
.Lj482:
	call	fpc_popaddrstack
	cmpl	$0,-116(%rbp)
	je	.Lj480
# [1216] raise EInvalidArgument.CreateFmt('TCollection.Clone: Invalid class type conversion: %s', [E.Message]);
	movq	$VMT_$SYSUTILS_$$_EXCEPTION,%rdi
	call	fpc_catches
	testq	%rax,%rax
	je	.Lj483
	movq	%rax,-128(%rbp)
	leaq	-152(%rbp),%rdx
	leaq	-216(%rbp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,-220(%rbp)
	testl	%eax,%eax
	jne	.Lj484
.Lj486:
	movq	-128(%rbp),%rax
	movq	16(%rax),%rax
	movq	%rax,-232(%rbp)
	movq	$11,-240(%rbp)
	leaq	-240(%rbp),%rcx
	movq	$.Ld9,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT,%rdi
	xorl	%r8d,%r8d
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATEFMT$ANSISTRING$array_of_const$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj486,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj484:
	call	fpc_popaddrstack
	cmpl	$0,-220(%rbp)
	je	.Lj487
	call	fpc_raise_nested
.Lj487:
	call	fpc_doneexception
	jmp	.Lj480
.Lj483:
	call	fpc_reraise
.Lj480:
# [1220] try
	leaq	-48(%rbp),%rdx
	leaq	-112(%rbp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,-116(%rbp)
	testl	%eax,%eax
	jne	.Lj492
# [1221] Result := LCollectionClass.Create(Self);
	movq	-8(%rbp),%rdx
	movl	$1,%esi
	movq	-24(%rbp),%rdi
	call	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$TCOLLECTION$$TCOLLECTION
	movq	%rax,-16(%rbp)
.Lj492:
	call	fpc_popaddrstack
	cmpl	$0,-116(%rbp)
	je	.Lj490
# [1227] end;
	movq	$VMT_$SYSUTILS_$$_EXCEPTION,%rdi
	call	fpc_catches
	testq	%rax,%rax
	je	.Lj493
	movq	%rax,-128(%rbp)
	leaq	-240(%rbp),%rdx
	leaq	-216(%rbp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,-136(%rbp)
	testl	%eax,%eax
	jne	.Lj494
# [1225] Result := nil;
	movq	$0,-16(%rbp)
.Lj496:
# [1226] raise EInvalidArgument.CreateFmt('TCollection.Clone: Failed to create clone: %s', [E.Message]);
	movq	-128(%rbp),%rax
	movq	16(%rax),%rax
	movq	%rax,-144(%rbp)
	movq	$11,-152(%rbp)
	leaq	-152(%rbp),%rcx
	movq	$.Ld10,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT,%rdi
	xorl	%r8d,%r8d
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATEFMT$ANSISTRING$array_of_const$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj496,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj494:
	call	fpc_popaddrstack
	cmpl	$0,-136(%rbp)
	je	.Lj497
	call	fpc_raise_nested
.Lj497:
	call	fpc_doneexception
	jmp	.Lj490
.Lj493:
	call	fpc_reraise
.Lj490:
# [1229] end;
	movq	-16(%rbp),%rax
.Lc307:
	movq	%rbp,%rsp
.Lc308:
	popq	%rbp
	ret
.Lc303:
.Le13:
	.size	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CLONE$$TCOLLECTION, .Le13 - NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CLONE$$TCOLLECTION

.section .text.n_nextpas.core.collections.base$_$tcollection_$__$$_iscompatible$tcollection$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_ISCOMPATIBLE$TCOLLECTION$$BOOLEAN
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_ISCOMPATIBLE$TCOLLECTION$$BOOLEAN,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_ISCOMPATIBLE$TCOLLECTION$$BOOLEAN:
.Lc310:
# [1232] begin
	pushq	%rax
.Lc311:
# Var $self located in register rdi
# Var aDst located in register rsi
# [1233] Result := (aDst is TCollection);
	movq	$VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION,%rdi
# Var aDst located in register rsi
	call	fpc_do_is
# Var $result located in register al
# [1234] end;
	popq	%rcx
.Lc312:
	ret
.Lc309:
.Le14:
	.size	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_ISCOMPATIBLE$TCOLLECTION$$BOOLEAN, .Le14 - NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_ISCOMPATIBLE$TCOLLECTION$$BOOLEAN

.section .text.n_nextpas.core.collections.base$_$tcollection_$__$$_loadfrom$pointer$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_LOADFROM$POINTER$QWORD
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_LOADFROM$POINTER$QWORD,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_LOADFROM$POINTER$QWORD:
.Lc314:
# Temps allocated between rbp-24 and rbp+0
# [1237] begin
	pushq	%rbp
.Lc315:
	movq	%rsp,%rbp
.Lc316:
	leaq	-32(%rsp),%rsp
	movq	%rbx,-24(%rbp)
	movq	%r12,-16(%rbp)
	movq	%r13,-8(%rbp)
	movq	%rdi,%rbx
# Var $self located in register rbx
	movq	%rsi,%r12
# Var aSrc located in register r12
	movq	%rdx,%r13
# Var aElementCount located in register r13
# [1238] if aSrc = nil then
	testq	%rsi,%rsi
	jne	.Lj503
.Lj504:
# [1239] raise EArgumentNil.Create('TCollection.LoadFrom: Failed to load: aSrc is nil');
	movq	$.Ld11,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj504,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj503:
# [1241] if IsOverlap(aSrc, aElementCount) then
	movq	%r13,%rdx
	movq	%r12,%rsi
	movq	%rbx,%rdi
	movq	(%rbx),%rax
	call	*200(%rax)
	testb	%al,%al
	je	.Lj506
.Lj507:
# [1242] raise EInvalidArgument.Create('TCollection.LoadFrom: Failed to load: aSrc overlaps with current container');
	movq	$.Ld12,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj507,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj506:
# [1244] if aElementCount = 0 then
	testq	%r13,%r13
	jne	.Lj509
# [1246] Clear;
	movq	%rbx,%rdi
	movq	(%rbx),%rax
	call	*232(%rax)
# [1247] exit;
	jmp	.Lj500
	.p2align 4,,10
	.p2align 3
.Lj509:
# [1250] LoadFromUnchecked(aSrc, aElementCount);
	movq	%r13,%rdx
# Var aElementCount located in register rdx
	movq	%r12,%rsi
# Var aSrc located in register rsi
# Var $self located in register rbx
	movq	%rbx,%rdi
	movq	(%rbx),%rax
	call	*272(%rax)
.Lj500:
# [1251] end;
	movq	-24(%rbp),%rbx
	movq	-16(%rbp),%r12
	movq	-8(%rbp),%r13
.Lc317:
	movq	%rbp,%rsp
.Lc318:
	popq	%rbp
	ret
.Lc313:
.Le15:
	.size	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_LOADFROM$POINTER$QWORD, .Le15 - NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_LOADFROM$POINTER$QWORD

.section .text.n_nextpas.core.collections.base$_$tcollection_$__$$_loadfromunchecked$pointer$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_LOADFROMUNCHECKED$POINTER$QWORD
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_LOADFROMUNCHECKED$POINTER$QWORD,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_LOADFROMUNCHECKED$POINTER$QWORD:
.Lc320:
# [1254] begin
	pushq	%rbx
.Lc321:
	pushq	%r12
.Lc322:
	pushq	%r13
.Lc323:
	movq	%rdi,%rbx
# Var $self located in register rbx
	movq	%rsi,%r12
# Var aSrc located in register r12
	movq	%rdx,%r13
# Var aElementCount located in register r13
# Var $self located in register rbx
# [1255] Clear;
	movq	%rbx,%rdi
	movq	(%rbx),%rax
	call	*232(%rax)
# [1256] AppendUnchecked(aSrc, aElementCount);
	movq	%r13,%rdx
# Var aElementCount located in register rdx
	movq	%r12,%rsi
# Var aSrc located in register rsi
# Var $self located in register rbx
	movq	%rbx,%rdi
	movq	(%rbx),%rax
	call	*296(%rax)
# [1257] end;
	popq	%r13
.Lc324:
	popq	%r12
.Lc325:
	popq	%rbx
.Lc326:
	ret
.Lc319:
.Le16:
	.size	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_LOADFROMUNCHECKED$POINTER$QWORD, .Le16 - NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_LOADFROMUNCHECKED$POINTER$QWORD

.section .text.n_nextpas.core.collections.base$_$tcollection_$__$$_tryloadfrom$pointer$qword$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_TRYLOADFROM$POINTER$QWORD$$BOOLEAN
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_TRYLOADFROM$POINTER$QWORD$$BOOLEAN,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_TRYLOADFROM$POINTER$QWORD$$BOOLEAN:
.Lc328:
# Temps allocated between rsp+28 and rsp+220
# [1261] begin
	leaq	-232(%rsp),%rsp
.Lc329:
# Var aSrc located at rsp+0, size=OS_64
# Var aElementCount located at rsp+8, size=OS_64
# Var $self located at rsp+16, size=OS_64
# Var $result located at rsp+24, size=OS_8
	movq	%rdi,16(%rsp)
	movq	%rsi,(%rsp)
	movq	%rdx,8(%rsp)
# [1263] Result := False;
	movb	$0,24(%rsp)
# [1264] if (aSrc = nil) and (aElementCount > 0) then Exit;
	cmpq	$0,(%rsp)
	seteb	%al
	cmpq	$0,8(%rsp)
	setab	%dl
	andb	%dl,%al
	jne	.Lj512
# [1265] if aElementCount = 0 then
	cmpq	$0,8(%rsp)
	jne	.Lj517
# [1267] Clear;
	movq	16(%rsp),%rdi
	movq	(%rdi),%rax
	call	*232(%rax)
# [1268] Result := True;
	movb	$1,24(%rsp)
# [1269] Exit;
	jmp	.Lj512
	.p2align 4,,10
	.p2align 3
.Lj517:
# [1271] if IsOverlap(aSrc, aElementCount) then Exit;
	movq	8(%rsp),%rdx
	movq	(%rsp),%rsi
	movq	16(%rsp),%rdi
	movq	(%rdi),%rax
	call	*200(%rax)
	testb	%al,%al
	jne	.Lj512
# [1272] try
	leaq	32(%rsp),%rdx
	leaq	56(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,120(%rsp)
	testl	%eax,%eax
	jne	.Lj524
# [1273] LoadFromUnchecked(aSrc, aElementCount);
	movq	8(%rsp),%rdx
	movq	(%rsp),%rsi
	movq	16(%rsp),%rdi
	movq	(%rdi),%rax
	call	*272(%rax)
# [1274] Result := True;
	movb	$1,24(%rsp)
.Lj524:
	call	fpc_popaddrstack
	cmpl	$0,120(%rsp)
	je	.Lj522
	leaq	128(%rsp),%rdx
	leaq	152(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,216(%rsp)
	testl	%eax,%eax
	jne	.Lj525
# [1276] Result := False;
	movb	$0,24(%rsp)
.Lj525:
	call	fpc_popaddrstack
	cmpl	$0,216(%rsp)
	je	.Lj526
	call	fpc_raise_nested
.Lj526:
	call	fpc_doneexception
.Lj522:
.Lj512:
# [1278] end;
	movb	24(%rsp),%al
	leaq	232(%rsp),%rsp
.Lc330:
	ret
.Lc327:
.Le17:
	.size	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_TRYLOADFROM$POINTER$QWORD$$BOOLEAN, .Le17 - NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_TRYLOADFROM$POINTER$QWORD$$BOOLEAN

.section .text.n_nextpas.core.collections.base$_$tcollection_$__$$_tryappend$pointer$qword$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_TRYAPPEND$POINTER$QWORD$$BOOLEAN
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_TRYAPPEND$POINTER$QWORD$$BOOLEAN,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_TRYAPPEND$POINTER$QWORD$$BOOLEAN:
.Lc332:
# Temps allocated between rsp+28 and rsp+220
# [1281] begin
	leaq	-232(%rsp),%rsp
.Lc333:
# Var aSrc located at rsp+0, size=OS_64
# Var aElementCount located at rsp+8, size=OS_64
# Var $self located at rsp+16, size=OS_64
# Var $result located at rsp+24, size=OS_8
	movq	%rdi,16(%rsp)
	movq	%rsi,(%rsp)
	movq	%rdx,8(%rsp)
# [1283] Result := False;
	movb	$0,24(%rsp)
# [1284] if aElementCount = 0 then
	cmpq	$0,8(%rsp)
	jne	.Lj530
# [1286] Result := True;
	movb	$1,24(%rsp)
# [1287] Exit;
	jmp	.Lj527
	.p2align 4,,10
	.p2align 3
.Lj530:
# [1289] if aSrc = nil then Exit;
	cmpq	$0,(%rsp)
	je	.Lj527
# [1290] if IsAddOverflow(GetCount, aElementCount) then Exit;
	movq	16(%rsp),%rdi
	movq	(%rdi),%rax
	call	*224(%rax)
	movq	8(%rsp),%rcx
	movq	$-1,%rdx
	subq	%rcx,%rdx
	cmpq	%rax,%rdx
	jb	.Lj527
# [1291] if IsOverlap(aSrc, aElementCount) then Exit;
	movq	8(%rsp),%rdx
	movq	(%rsp),%rsi
	movq	16(%rsp),%rdi
	movq	(%rdi),%rax
	call	*200(%rax)
	testb	%al,%al
	jne	.Lj527
# [1292] try
	leaq	32(%rsp),%rdx
	leaq	56(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,120(%rsp)
	testl	%eax,%eax
	jne	.Lj541
# [1293] AppendUnchecked(aSrc, aElementCount);
	movq	8(%rsp),%rdx
	movq	(%rsp),%rsi
	movq	16(%rsp),%rdi
	movq	(%rdi),%rax
	call	*296(%rax)
# [1294] Result := True;
	movb	$1,24(%rsp)
.Lj541:
	call	fpc_popaddrstack
	cmpl	$0,120(%rsp)
	je	.Lj539
	leaq	128(%rsp),%rdx
	leaq	152(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,216(%rsp)
	testl	%eax,%eax
	jne	.Lj542
# [1296] Result := False;
	movb	$0,24(%rsp)
.Lj542:
	call	fpc_popaddrstack
	cmpl	$0,216(%rsp)
	je	.Lj543
	call	fpc_raise_nested
.Lj543:
	call	fpc_doneexception
.Lj539:
.Lj527:
# [1298] end;
	movb	24(%rsp),%al
	leaq	232(%rsp),%rsp
.Lc334:
	ret
.Lc331:
.Le18:
	.size	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_TRYAPPEND$POINTER$QWORD$$BOOLEAN, .Le18 - NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_TRYAPPEND$POINTER$QWORD$$BOOLEAN

.section .text.n_nextpas.core.collections.base$_$tcollection_$__$$_append$pointer$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_APPEND$POINTER$QWORD
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_APPEND$POINTER$QWORD,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_APPEND$POINTER$QWORD:
.Lc336:
# Temps allocated between rbp-24 and rbp+0
# [1303] begin
	pushq	%rbp
.Lc337:
	movq	%rsp,%rbp
.Lc338:
	leaq	-32(%rsp),%rsp
	movq	%rbx,-24(%rbp)
	movq	%r12,-16(%rbp)
	movq	%r13,-8(%rbp)
	movq	%rdi,%rbx
# Var $self located in register rbx
	movq	%rsi,%r12
# Var aSrc located in register r12
	movq	%rdx,%r13
# Var aElementCount located in register r13
# [1304] if aElementCount = 0 then
	testq	%rdx,%rdx
	je	.Lj544
# [1307] if aSrc = nil then
	testq	%r12,%r12
	jne	.Lj549
.Lj550:
# [1308] raise EArgumentNil.Create('TCollection.Append: Failed to append: aSrc is nil');
	movq	$.Ld13,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj550,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj549:
# [1310] if IsAddOverflow(GetCount, aElementCount) then
	movq	%rbx,%rdi
	movq	(%rbx),%rax
	call	*224(%rax)
	movq	$-1,%rdx
	subq	%r13,%rdx
	cmpq	%rax,%rdx
	jnb	.Lj552
.Lj553:
# [1311] raise EOverflow.Create('TCollection.Append: Failed to append: aElementCount is too large(Overflow)');
	movq	$.Ld14,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EOVERFLOW,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj553,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj552:
# [1314] if IsOverlap(aSrc, aElementCount) then
	movq	%r13,%rdx
	movq	%r12,%rsi
	movq	%rbx,%rdi
	movq	(%rbx),%rax
	call	*200(%rax)
	testb	%al,%al
	je	.Lj555
.Lj556:
# [1315] raise EInvalidArgument.Create('TCollection.Append: source memory overlaps with container memory');
	movq	$.Ld15,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj556,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj555:
# [1317] AppendUnchecked(aSrc, aElementCount);
	movq	%r13,%rdx
# Var aElementCount located in register rdx
	movq	%r12,%rsi
# Var aSrc located in register rsi
# Var $self located in register rbx
	movq	%rbx,%rdi
	movq	(%rbx),%rax
	call	*296(%rax)
.Lj544:
# [1318] end;
	movq	-24(%rbp),%rbx
	movq	-16(%rbp),%r12
	movq	-8(%rbp),%r13
.Lc339:
	movq	%rbp,%rsp
.Lc340:
	popq	%rbp
	ret
.Lc335:
.Le19:
	.size	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_APPEND$POINTER$QWORD, .Le19 - NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_APPEND$POINTER$QWORD

.section .text.n_nextpas.core.collections.base$_$tcollection_$__$$_loadfrom$tcollection,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_LOADFROM$TCOLLECTION
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_LOADFROM$TCOLLECTION,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_LOADFROM$TCOLLECTION:
.Lc342:
# Temps allocated between rbp-16 and rbp+0
# [1321] begin
	pushq	%rbp
.Lc343:
	movq	%rsp,%rbp
.Lc344:
	leaq	-16(%rsp),%rsp
	movq	%rbx,-16(%rbp)
	movq	%r12,-8(%rbp)
	movq	%rdi,%rbx
# Var $self located in register rbx
	movq	%rsi,%r12
# Var aSrc located in register r12
# [1322] if aSrc = nil then
	testq	%rsi,%rsi
	jne	.Lj560
.Lj561:
# [1323] raise EArgumentNil.Create('TCollection.LoadFrom: Failed to load: aCollection is nil');
	movq	$.Ld16,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj561,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj560:
# [1325] if aSrc = Self then
	cmpq	%r12,%rbx
	jne	.Lj563
.Lj564:
# [1326] raise EInvalidArgument.Create('TCollection.LoadFrom: Failed to load: aCollection is self');
	movq	$.Ld17,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj564,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj563:
# [1328] if not IsCompatible(aSrc) then
	movq	%r12,%rsi
	movq	%rbx,%rdi
	movq	(%rbx),%rax
	call	*256(%rax)
	testb	%al,%al
	jne	.Lj566
.Lj567:
# [1329] raise ENotCompatible.Create('TCollection.LoadFrom: Failed to load: aCollection is not compatible');
	movq	$.Ld18,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj567,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj566:
# [1332] if aSrc.GetCount = 0 then
	movq	%r12,%rdi
	movq	(%r12),%rax
	call	*224(%rax)
	testq	%rax,%rax
	jne	.Lj569
# [1334] Clear;
	movq	%rbx,%rdi
	movq	(%rbx),%rax
	call	*232(%rax)
# [1335] exit;
	jmp	.Lj557
	.p2align 4,,10
	.p2align 3
.Lj569:
# [1338] LoadFromUnchecked(aSrc);
	movq	%r12,%rsi
# Var aSrc located in register rsi
# Var $self located in register rbx
	movq	%rbx,%rdi
	movq	(%rbx),%rax
	call	*312(%rax)
.Lj557:
# [1339] end;
	movq	-16(%rbp),%rbx
	movq	-8(%rbp),%r12
.Lc345:
	movq	%rbp,%rsp
.Lc346:
	popq	%rbp
	ret
.Lc341:
.Le20:
	.size	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_LOADFROM$TCOLLECTION, .Le20 - NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_LOADFROM$TCOLLECTION

.section .text.n_nextpas.core.collections.base$_$tcollection_$__$$_loadfromunchecked$tcollection,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_LOADFROMUNCHECKED$TCOLLECTION
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_LOADFROMUNCHECKED$TCOLLECTION,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_LOADFROMUNCHECKED$TCOLLECTION:
.Lc348:
# [1342] begin
	pushq	%rax
.Lc349:
# Var $self located in register rdi
	movq	%rsi,%rax
# Var aSrc located in register rax
# [1343] aSrc.SaveToUnchecked(Self);
	movq	%rdi,%rsi
# Var $self located in register rsi
# Var aSrc located in register rax
	movq	%rax,%rdi
	movq	(%rax),%rax
	call	*336(%rax)
# [1344] end;
	popq	%rcx
.Lc350:
	ret
.Lc347:
.Le21:
	.size	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_LOADFROMUNCHECKED$TCOLLECTION, .Le21 - NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_LOADFROMUNCHECKED$TCOLLECTION

.section .text.n_nextpas.core.collections.base$_$tcollection_$__$$_append$tcollection,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_APPEND$TCOLLECTION
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_APPEND$TCOLLECTION,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_APPEND$TCOLLECTION:
.Lc352:
# Temps allocated between rbp-24 and rbp+0
# [1347] begin
	pushq	%rbp
.Lc353:
	movq	%rsp,%rbp
.Lc354:
	leaq	-32(%rsp),%rsp
	movq	%rbx,-24(%rbp)
	movq	%r12,-16(%rbp)
	movq	%r13,-8(%rbp)
	movq	%rdi,%rbx
# Var $self located in register rbx
	movq	%rsi,%r12
# Var aSrc located in register r12
# [1348] if aSrc = nil then
	testq	%rsi,%rsi
	jne	.Lj575
.Lj576:
# [1349] raise EArgumentNil.Create('TCollection.Append: Failed to append: aCollection is nil');
	movq	$.Ld19,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj576,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj575:
# [1351] if aSrc = Self then
	cmpq	%r12,%rbx
	jne	.Lj578
.Lj579:
# [1352] raise EInvalidArgument.Create('TCollection.Append: Failed to append: aCollection is self');
	movq	$.Ld20,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj579,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj578:
# [1354] if not IsCompatible(aSrc) then
	movq	%r12,%rsi
	movq	%rbx,%rdi
	movq	(%rbx),%rax
	call	*256(%rax)
	testb	%al,%al
	jne	.Lj581
.Lj582:
# [1355] raise ENotCompatible.Create('TCollection.Append: Failed to append: aCollection is not compatible');
	movq	$.Ld21,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj582,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj581:
# [1358] if aSrc.IsEmpty then
	movq	%r12,%rdi
	call	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_ISEMPTY$$BOOLEAN
	testb	%al,%al
	jne	.Lj572
# [1361] if IsAddOverflow(GetCount, aSrc.GetCount) then
	movq	%r12,%rdi
	movq	(%r12),%rax
	call	*224(%rax)
	movq	%rax,%r13
	movq	%rbx,%rdi
	movq	(%rbx),%rax
	call	*224(%rax)
	movq	$-1,%rdx
	subq	%r13,%rdx
	cmpq	%rax,%rdx
	jnb	.Lj586
.Lj587:
# [1362] raise EOverflow.Create('TCollection.Append: Failed to append: aCollection is too large(Overflow)');
	movq	$.Ld22,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EOVERFLOW,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj587,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj586:
# [1364] AppendUnchecked(aSrc);
	movq	%r12,%rsi
# Var aSrc located in register rsi
# Var $self located in register rbx
	movq	%rbx,%rdi
	movq	(%rbx),%rax
	call	*320(%rax)
.Lj572:
# [1365] end;
	movq	-24(%rbp),%rbx
	movq	-16(%rbp),%r12
	movq	-8(%rbp),%r13
.Lc355:
	movq	%rbp,%rsp
.Lc356:
	popq	%rbp
	ret
.Lc351:

.section .text.n_nextpas.core.collections.base$_$tcollection_$__$$_appendunchecked$tcollection,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_APPENDUNCHECKED$TCOLLECTION
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_APPENDUNCHECKED$TCOLLECTION,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_APPENDUNCHECKED$TCOLLECTION:
.Lc358:
# [1368] begin
	pushq	%rbx
.Lc359:
	pushq	%r12
.Lc360:
	pushq	%rax
.Lc361:
	movq	%rdi,%rbx
# Var $self located in register rbx
	movq	%rsi,%r12
# Var aSrc located in register r12
# [1369] if aSrc.IsEmpty then
	movq	%rsi,%rdi
	call	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_ISEMPTY$$BOOLEAN
	testb	%al,%al
	jne	.Lj588
# [1372] aSrc.AppendToUnchecked(Self);
	movq	%rbx,%rsi
# Var $self located in register rsi
# Var aSrc located in register r12
	movq	%r12,%rdi
	movq	(%r12),%rax
	call	*328(%rax)
.Lj588:
# [1373] end;
	popq	%rcx
	popq	%r12
.Lc362:
	popq	%rbx
.Lc363:
	ret
.Lc357:
.Le22:
	.size	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_APPENDUNCHECKED$TCOLLECTION, .Le22 - NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_APPENDUNCHECKED$TCOLLECTION

.section .text.n_nextpas.core.collections.base$_$tcollection_$__$$_appendto$tcollection,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_APPENDTO$TCOLLECTION
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_APPENDTO$TCOLLECTION,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_APPENDTO$TCOLLECTION:
.Lc365:
# Temps allocated between rbp-16 and rbp+0
# [1376] begin
	pushq	%rbp
.Lc366:
	movq	%rsp,%rbp
.Lc367:
	leaq	-16(%rsp),%rsp
	movq	%rbx,-16(%rbp)
	movq	%r12,-8(%rbp)
	movq	%rdi,%rbx
# Var $self located in register rbx
	movq	%rsi,%r12
# Var aDst located in register r12
# [1377] if aDst = nil then
	testq	%rsi,%rsi
	jne	.Lj595
.Lj596:
# [1378] raise EArgumentNil.Create('TCollection.AppendTo: Failed to append: aCollection is nil');
	movq	$.Ld23,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj596,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj595:
# [1380] if not IsCompatible(aDst) then
	movq	%r12,%rsi
	movq	%rbx,%rdi
	movq	(%rbx),%rax
	call	*256(%rax)
	testb	%al,%al
	jne	.Lj598
.Lj599:
# [1381] raise ENotCompatible.Create('TCollection.AppendTo: Failed to append: aCollection is not compatible');
	movq	$.Ld24,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj599,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj598:
# [1383] AppendToUnchecked(aDst);
	movq	%r12,%rsi
# Var aDst located in register rsi
# Var $self located in register rbx
	movq	%rbx,%rdi
	movq	(%rbx),%rax
	call	*328(%rax)
# [1384] end;
	movq	-16(%rbp),%rbx
	movq	-8(%rbp),%r12
.Lc368:
	movq	%rbp,%rsp
.Lc369:
	popq	%rbp
	ret
.Lc364:

.section .text.n_nextpas.core.collections.base$_$tcollection_$__$$_saveto$tcollection,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_SAVETO$TCOLLECTION
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_SAVETO$TCOLLECTION,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_SAVETO$TCOLLECTION:
.Lc371:
# Temps allocated between rbp-16 and rbp+0
# [1387] begin
	pushq	%rbp
.Lc372:
	movq	%rsp,%rbp
.Lc373:
	leaq	-16(%rsp),%rsp
	movq	%rbx,-16(%rbp)
	movq	%r12,-8(%rbp)
	movq	%rdi,%rbx
# Var $self located in register rbx
	movq	%rsi,%r12
# Var aDst located in register r12
# [1388] if aDst = nil then
	testq	%rsi,%rsi
	jne	.Lj603
.Lj604:
# [1389] raise EArgumentNil.Create('TCollection.SaveTo: Failed to save: aCollection is nil');
	movq	$.Ld25,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj604,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj603:
# [1391] if aDst = Self then
	cmpq	%r12,%rbx
	jne	.Lj606
.Lj607:
# [1392] raise EInvalidArgument.Create('TCollection.SaveTo: Failed to save: aCollection is self');
	movq	$.Ld26,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj607,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj606:
# [1394] if not IsCompatible(aDst) then
	movq	%r12,%rsi
	movq	%rbx,%rdi
	movq	(%rbx),%rax
	call	*256(%rax)
	testb	%al,%al
	jne	.Lj609
.Lj610:
# [1395] raise ENotCompatible.Create('TCollection.SaveTo: Failed to save: aCollection is not compatible');
	movq	$.Ld27,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_ENOTCOMPATIBLE,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj610,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj609:
# [1397] SaveToUnchecked(aDst);
	movq	%r12,%rsi
# Var aDst located in register rsi
# Var $self located in register rbx
	movq	%rbx,%rdi
	movq	(%rbx),%rax
	call	*336(%rax)
# [1398] end;
	movq	-16(%rbp),%rbx
	movq	-8(%rbp),%r12
.Lc374:
	movq	%rbp,%rsp
.Lc375:
	popq	%rbp
	ret
.Lc370:

.section .text.n_nextpas.core.collections.base$_$tcollection_$__$$_savetounchecked$tcollection,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_SAVETOUNCHECKED$TCOLLECTION
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_SAVETOUNCHECKED$TCOLLECTION,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_SAVETOUNCHECKED$TCOLLECTION:
.Lc377:
# [1401] begin
	pushq	%rbx
.Lc378:
	pushq	%r12
.Lc379:
	pushq	%rax
.Lc380:
	movq	%rdi,%rbx
# Var $self located in register rbx
	movq	%rsi,%r12
# Var aDst located in register r12
# Var aDst located in register r12
# [1402] aDst.Clear;
	movq	%rsi,%rdi
	movq	(%rsi),%rax
	call	*232(%rax)
# [1404] if IsEmpty then
	movq	%rbx,%rdi
	call	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_ISEMPTY$$BOOLEAN
	testb	%al,%al
	jne	.Lj611
# [1407] aDst.AppendUnchecked(Self);
	movq	%rbx,%rsi
# Var $self located in register rsi
# Var aDst located in register r12
	movq	%r12,%rdi
	movq	(%r12),%rax
	call	*320(%rax)
.Lj611:
# [1408] end;
	popq	%rcx
	popq	%r12
.Lc381:
	popq	%rbx
.Lc382:
	ret
.Lc376:
.Le23:
	.size	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_SAVETOUNCHECKED$TCOLLECTION, .Le23 - NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_SAVETOUNCHECKED$TCOLLECTION

.section .text.n_nextpas.core.collections.base$_$tcollection_$__$$_tryloadfrom$tcollection$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_TRYLOADFROM$TCOLLECTION$$BOOLEAN
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_TRYLOADFROM$TCOLLECTION$$BOOLEAN,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_TRYLOADFROM$TCOLLECTION$$BOOLEAN:
.Lc384:
# Temps allocated between rsp+20 and rsp+212
# [1427] begin
	leaq	-216(%rsp),%rsp
.Lc385:
# Var aSrc located at rsp+0, size=OS_64
# Var $self located at rsp+8, size=OS_64
# Var $result located at rsp+16, size=OS_8
	movq	%rdi,8(%rsp)
	movq	%rsi,(%rsp)
# [1429] Result := False;
	movb	$0,16(%rsp)
# [1430] if aSrc = nil then Exit;
	cmpq	$0,(%rsp)
	je	.Lj617
# [1431] if aSrc = Self then Exit;
	movq	(%rsp),%rax
	cmpq	8(%rsp),%rax
	je	.Lj617
# [1432] if not IsCompatible(aSrc) then Exit;
	movq	(%rsp),%rsi
	movq	8(%rsp),%rdi
	movq	(%rdi),%rax
	call	*256(%rax)
	testb	%al,%al
	je	.Lj617
# [1433] if aSrc.GetCount = 0 then
	movq	(%rsp),%rdi
	movq	(%rdi),%rax
	call	*224(%rax)
	testq	%rax,%rax
	jne	.Lj626
# [1435] Clear;
	movq	8(%rsp),%rdi
	movq	(%rdi),%rax
	call	*232(%rax)
# [1436] Result := True;
	movb	$1,16(%rsp)
# [1437] Exit;
	jmp	.Lj617
	.p2align 4,,10
	.p2align 3
.Lj626:
# [1439] try
	leaq	24(%rsp),%rdx
	leaq	48(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,112(%rsp)
	testl	%eax,%eax
	jne	.Lj631
# [1440] LoadFromUnchecked(aSrc);
	movq	(%rsp),%rsi
	movq	8(%rsp),%rdi
	movq	(%rdi),%rax
	call	*312(%rax)
# [1441] Result := True;
	movb	$1,16(%rsp)
.Lj631:
	call	fpc_popaddrstack
	cmpl	$0,112(%rsp)
	je	.Lj629
	leaq	120(%rsp),%rdx
	leaq	144(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,208(%rsp)
	testl	%eax,%eax
	jne	.Lj632
# [1443] Result := False;
	movb	$0,16(%rsp)
.Lj632:
	call	fpc_popaddrstack
	cmpl	$0,208(%rsp)
	je	.Lj633
	call	fpc_raise_nested
.Lj633:
	call	fpc_doneexception
.Lj629:
.Lj617:
# [1445] end;
	movb	16(%rsp),%al
	leaq	216(%rsp),%rsp
.Lc386:
	ret
.Lc383:

.section .text.n_nextpas.core.collections.base$_$tcollection_$__$$_tryappend$tcollection$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_TRYAPPEND$TCOLLECTION$$BOOLEAN
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_TRYAPPEND$TCOLLECTION$$BOOLEAN,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_TRYAPPEND$TCOLLECTION$$BOOLEAN:
.Lc388:
# Temps allocated between rsp+20 and rsp+212
# [1448] begin
	pushq	%rbx
.Lc389:
	leaq	-224(%rsp),%rsp
.Lc390:
# Var aSrc located at rsp+0, size=OS_64
# Var $self located at rsp+8, size=OS_64
# Var $result located at rsp+16, size=OS_8
	movq	%rdi,8(%rsp)
	movq	%rsi,(%rsp)
# [1450] Result := False;
	movb	$0,16(%rsp)
# [1451] if aSrc = nil then Exit;
	cmpq	$0,(%rsp)
	je	.Lj634
# [1452] if aSrc = Self then Exit;
	movq	(%rsp),%rax
	cmpq	8(%rsp),%rax
	je	.Lj634
# [1453] if not IsCompatible(aSrc) then Exit;
	movq	(%rsp),%rsi
	movq	8(%rsp),%rdi
	movq	(%rdi),%rax
	call	*256(%rax)
	testb	%al,%al
	je	.Lj634
# [1454] if aSrc.IsEmpty then
	movq	(%rsp),%rdi
	call	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_ISEMPTY$$BOOLEAN
	testb	%al,%al
	je	.Lj643
# [1456] Result := True;
	movb	$1,16(%rsp)
# [1457] Exit;
	jmp	.Lj634
	.p2align 4,,10
	.p2align 3
.Lj643:
# [1459] if IsAddOverflow(GetCount, aSrc.GetCount) then Exit;
	movq	(%rsp),%rdi
	movq	(%rdi),%rax
	call	*224(%rax)
	movq	%rax,%rbx
	movq	8(%rsp),%rdi
	movq	(%rdi),%rax
	call	*224(%rax)
	movq	$-1,%rdx
	subq	%rbx,%rdx
	cmpq	%rax,%rdx
	jb	.Lj634
# [1460] try
	leaq	24(%rsp),%rdx
	leaq	48(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,112(%rsp)
	testl	%eax,%eax
	jne	.Lj650
# [1461] AppendUnchecked(aSrc);
	movq	(%rsp),%rsi
	movq	8(%rsp),%rdi
	movq	(%rdi),%rax
	call	*320(%rax)
# [1462] Result := True;
	movb	$1,16(%rsp)
.Lj650:
	call	fpc_popaddrstack
	cmpl	$0,112(%rsp)
	je	.Lj648
	leaq	120(%rsp),%rdx
	leaq	144(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,208(%rsp)
	testl	%eax,%eax
	jne	.Lj651
# [1464] Result := False;
	movb	$0,16(%rsp)
.Lj651:
	call	fpc_popaddrstack
	cmpl	$0,208(%rsp)
	je	.Lj652
	call	fpc_raise_nested
.Lj652:
	call	fpc_doneexception
.Lj648:
.Lj634:
# [1466] end;
	movb	16(%rsp),%al
	leaq	224(%rsp),%rsp
	popq	%rbx
.Lc391:
	ret
.Lc387:

.section .text.n_nextpas.core.collections.base_$$_fixedgrow$qword$$igrowthstrategy,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_FIXEDGROW$QWORD$$IGROWTHSTRATEGY
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_FIXEDGROW$QWORD$$IGROWTHSTRATEGY,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_FIXEDGROW$QWORD$$IGROWTHSTRATEGY:
.Lc393:
# [2363] begin
	pushq	%rbx
.Lc394:
	movq	%rdi,%rbx
# Var $result located in register rbx
	movq	%rsi,%rdx
# Var aStep located in register rdx
# [2364] Result := TFixedGrowStrategy.Create(aStep);
	movq	$VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY,%rdi
# Var aStep located in register rdx
	movl	$1,%esi
	call	NEXTPAS.CORE.COLLECTIONS.BASE$_$TFIXEDGROWSTRATEGY_$__$$_CREATE$QWORD$$TFIXEDGROWSTRATEGY
	movq	%rax,%rsi
	testq	%rax,%rax
	je	.Lj879
	addq	$32,%rsi
.Lj879:
	movq	%rbx,%rdi
	call	fpc_intf_assign
# [2365] end;
	popq	%rbx
.Lc395:
	ret
.Lc392:

.section .text.n_nextpas.core.collections.base_$$_factorgrow$double$$igrowthstrategy,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_FACTORGROW$DOUBLE$$IGROWTHSTRATEGY
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_FACTORGROW$DOUBLE$$IGROWTHSTRATEGY,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_FACTORGROW$DOUBLE$$IGROWTHSTRATEGY:
.Lc397:
# [2368] begin
	pushq	%rbx
.Lc398:
	movq	%rdi,%rbx
# Var $result located in register rbx
# Var aFactor located in register xmm0
# [2369] Result := TFactorGrowStrategy.Create(aFactor);
	cvtsd2ss	%xmm0,%xmm0
	movq	$VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY,%rdi
	movl	$1,%esi
	call	NEXTPAS.CORE.COLLECTIONS.BASE$_$TFACTORGROWSTRATEGY_$__$$_CREATE$SINGLE$$TFACTORGROWSTRATEGY
	movq	%rax,%rsi
	testq	%rax,%rax
	je	.Lj882
	addq	$32,%rsi
.Lj882:
	movq	%rbx,%rdi
	call	fpc_intf_assign
# [2370] end;
	popq	%rbx
.Lc399:
	ret
.Lc396:

.section .text.n_nextpas.core.collections.base_$$_doublinggrow$$igrowthstrategy,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_DOUBLINGGROW$$IGROWTHSTRATEGY
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_DOUBLINGGROW$$IGROWTHSTRATEGY,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_DOUBLINGGROW$$IGROWTHSTRATEGY:
.Lc401:
# [2373] begin
	pushq	%rbx
.Lc402:
	movq	%rdi,%rbx
# Var $result located in register rbx
# [2374] Result := TDoublingGrowStrategy.Create;
	movq	$VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY,%rdi
	movl	$1,%esi
	call	SYSTEM$_$TOBJECT_$__$$_CREATE$$TOBJECT
	movq	%rax,%rsi
	testq	%rax,%rax
	je	.Lj885
	addq	$32,%rsi
.Lj885:
	movq	%rbx,%rdi
	call	fpc_intf_assign
# [2375] end;
	popq	%rbx
.Lc403:
	ret
.Lc400:

.section .text.n_nextpas.core.collections.base_$$_exactgrow$$igrowthstrategy,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EXACTGROW$$IGROWTHSTRATEGY
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_EXACTGROW$$IGROWTHSTRATEGY,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_EXACTGROW$$IGROWTHSTRATEGY:
.Lc405:
# [2378] begin
	pushq	%rbx
.Lc406:
	movq	%rdi,%rbx
# Var $result located in register rbx
# [2379] Result := TExactGrowStrategy.Create;
	movq	$VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY,%rdi
	movl	$1,%esi
	call	SYSTEM$_$TOBJECT_$__$$_CREATE$$TOBJECT
	movq	%rax,%rsi
	testq	%rax,%rax
	je	.Lj888
	addq	$32,%rsi
.Lj888:
	movq	%rbx,%rdi
	call	fpc_intf_assign
# [2380] end;
	popq	%rbx
.Lc407:
	ret
.Lc404:

.section .text.n_nextpas.core.collections.base_$$_goldenratiogrow$$igrowthstrategy,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_GOLDENRATIOGROW$$IGROWTHSTRATEGY
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_GOLDENRATIOGROW$$IGROWTHSTRATEGY,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_GOLDENRATIOGROW$$IGROWTHSTRATEGY:
.Lc409:
# [2383] begin
	pushq	%rbx
.Lc410:
	movq	%rdi,%rbx
# Var $result located in register rbx
# [2384] Result := TGoldenRatioGrowStrategy.Create;
	movq	$VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY,%rdi
	movl	$1,%esi
	call	SYSTEM$_$TOBJECT_$__$$_CREATE$$TOBJECT
	movq	%rax,%rsi
	testq	%rax,%rax
	je	.Lj891
	addq	$32,%rsi
.Lj891:
	movq	%rbx,%rdi
	call	fpc_intf_assign
# [2385] end;
	popq	%rbx
.Lc411:
	ret
.Lc408:

.section .text.n_nextpas.core.collections.base$_$tgrowthstrategy_$__$$_getgrowsize$qword$qword$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TGROWTHSTRATEGY_$__$$_GETGROWSIZE$QWORD$QWORD$$QWORD
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TGROWTHSTRATEGY_$__$$_GETGROWSIZE$QWORD$QWORD$$QWORD,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TGROWTHSTRATEGY_$__$$_GETGROWSIZE$QWORD$QWORD$$QWORD:
.Lc413:
# [2394] begin
	pushq	%rbx
.Lc414:
	pushq	%r12
.Lc415:
	pushq	%rax
.Lc416:
# Var $result located in register r12
	movq	%rdi,%rax
# Var $self located in register rax
# Var aCurrentSize located in register rsi
	movq	%rdx,%rbx
# Var aRequiredSize located in register rbx
# [2395] if aRequiredSize <= aCurrentSize then
	cmpq	%rdx,%rsi
# [2396] Exit(aCurrentSize);
	cmovaeq	%rsi,%r12
	jae	.Lj892
# Var aRequiredSize located in register rbx
# [2398] Result := DoGetGrowSize(aCurrentSize, aRequiredSize);
	movq	%rbx,%rdx
# Var aCurrentSize located in register rsi
# Var $self located in register rax
	movq	%rax,%rdi
	movq	(%rax),%rax
	call	*200(%rax)
	movq	%rax,%r12
# [2399] if Result < aRequiredSize then
	cmpq	%rbx,%r12
	cmovnaq	%rbx,%r12
.Lj892:
# [2401] end;
	movq	%r12,%rax
	popq	%rcx
	popq	%r12
.Lc417:
	popq	%rbx
.Lc418:
	ret
.Lc412:
.Le24:
	.size	NEXTPAS.CORE.COLLECTIONS.BASE$_$TGROWTHSTRATEGY_$__$$_GETGROWSIZE$QWORD$QWORD$$QWORD, .Le24 - NEXTPAS.CORE.COLLECTIONS.BASE$_$TGROWTHSTRATEGY_$__$$_GETGROWSIZE$QWORD$QWORD$$QWORD

.section .text.n_nextpas.core.collections.base$_$tcustomgrowthstrategy_$__$$_getdata$$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCUSTOMGROWTHSTRATEGY_$__$$_GETDATA$$POINTER
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCUSTOMGROWTHSTRATEGY_$__$$_GETDATA$$POINTER,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCUSTOMGROWTHSTRATEGY_$__$$_GETDATA$$POINTER:
.Lc420:
# Var $self located in register rdi
# [2404] begin
# Var $result located in register rax
# [2405] Result := FData;
	movq	40(%rdi),%rax
.Lc421:
# [2406] end;
	ret
.Lc419:

.section .text.n_nextpas.core.collections.base$_$tcustomgrowthstrategy_$__$$_dogetgrowsizefunc$qword$qword$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCUSTOMGROWTHSTRATEGY_$__$$_DOGETGROWSIZEFUNC$QWORD$QWORD$$QWORD
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCUSTOMGROWTHSTRATEGY_$__$$_DOGETGROWSIZEFUNC$QWORD$QWORD$$QWORD,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCUSTOMGROWTHSTRATEGY_$__$$_DOGETGROWSIZEFUNC$QWORD$QWORD$$QWORD:
.Lc423:
# [2409] begin
	pushq	%rax
.Lc424:
	movq	%rdi,%rax
# Var $self located in register rax
	movq	%rsi,%rdi
# Var aCurrentSize located in register rdi
	movq	%rdx,%rsi
# Var aRequiredSize located in register rsi
# [2410] Result := FGrowFunc(aCurrentSize, aRequiredSize, FData);
	movq	40(%rax),%rdx
# Var aRequiredSize located in register rsi
# Var aCurrentSize located in register rdi
	call	*48(%rax)
# Var $result located in register rax
# [2411] end;
	popq	%rcx
.Lc425:
	ret
.Lc422:
.Le25:
	.size	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCUSTOMGROWTHSTRATEGY_$__$$_DOGETGROWSIZEFUNC$QWORD$QWORD$$QWORD, .Le25 - NEXTPAS.CORE.COLLECTIONS.BASE$_$TCUSTOMGROWTHSTRATEGY_$__$$_DOGETGROWSIZEFUNC$QWORD$QWORD$$QWORD

.section .text.n_nextpas.core.collections.base$_$tcustomgrowthstrategy_$__$$_dogetgrowsizemethod$qword$qword$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCUSTOMGROWTHSTRATEGY_$__$$_DOGETGROWSIZEMETHOD$QWORD$QWORD$$QWORD
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCUSTOMGROWTHSTRATEGY_$__$$_DOGETGROWSIZEMETHOD$QWORD$QWORD$$QWORD,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCUSTOMGROWTHSTRATEGY_$__$$_DOGETGROWSIZEMETHOD$QWORD$QWORD$$QWORD:
.Lc427:
# [2414] begin
	pushq	%rax
.Lc428:
	movq	%rdi,%rax
# Var $self located in register rax
# Var aCurrentSize located in register rsi
# Var aRequiredSize located in register rdx
# [2415] Result := FGrowMethod(aCurrentSize, aRequiredSize);
	movq	64(%rdi),%rdi
# Var aRequiredSize located in register rdx
# Var aCurrentSize located in register rsi
	call	*56(%rax)
# Var $result located in register rax
# [2416] end;
	popq	%rcx
.Lc429:
	ret
.Lc426:
.Le26:
	.size	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCUSTOMGROWTHSTRATEGY_$__$$_DOGETGROWSIZEMETHOD$QWORD$QWORD$$QWORD, .Le26 - NEXTPAS.CORE.COLLECTIONS.BASE$_$TCUSTOMGROWTHSTRATEGY_$__$$_DOGETGROWSIZEMETHOD$QWORD$QWORD$$QWORD

.section .text.n_nextpas.core.collections.base$_$tcustomgrowthstrategy_$__$$_dogetgrowsizereffunc$qword$qword$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCUSTOMGROWTHSTRATEGY_$__$$_DOGETGROWSIZEREFFUNC$QWORD$QWORD$$QWORD
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCUSTOMGROWTHSTRATEGY_$__$$_DOGETGROWSIZEREFFUNC$QWORD$QWORD$$QWORD,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCUSTOMGROWTHSTRATEGY_$__$$_DOGETGROWSIZEREFFUNC$QWORD$QWORD$$QWORD:
.Lc431:
# [2419] begin
	pushq	%rax
.Lc432:
# Var $self located in register rax
# Var aCurrentSize located in register rsi
# Var aRequiredSize located in register rdx
# [2420] Result := FGrowRefFunc(aCurrentSize, aRequiredSize);
	movq	72(%rdi),%rdi
# Var aRequiredSize located in register rdx
# Var aCurrentSize located in register rsi
	movq	(%rdi),%rax
	call	*24(%rax)
# Var $result located in register rax
# [2421] end;
	popq	%rcx
.Lc433:
	ret
.Lc430:
.Le27:
	.size	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCUSTOMGROWTHSTRATEGY_$__$$_DOGETGROWSIZEREFFUNC$QWORD$QWORD$$QWORD, .Le27 - NEXTPAS.CORE.COLLECTIONS.BASE$_$TCUSTOMGROWTHSTRATEGY_$__$$_DOGETGROWSIZEREFFUNC$QWORD$QWORD$$QWORD

.section .text.n_nextpas.core.collections.base$_$tcustomgrowthstrategy_$__$$_dogetgrowsize$qword$qword$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCUSTOMGROWTHSTRATEGY_$__$$_DOGETGROWSIZE$QWORD$QWORD$$QWORD
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCUSTOMGROWTHSTRATEGY_$__$$_DOGETGROWSIZE$QWORD$QWORD$$QWORD,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCUSTOMGROWTHSTRATEGY_$__$$_DOGETGROWSIZE$QWORD$QWORD$$QWORD:
.Lc435:
# [2424] begin
	pushq	%rax
.Lc436:
	movq	%rdi,%rax
# Var $self located in register rax
# Var aCurrentSize located in register rsi
# Var aRequiredSize located in register rdx
# [2425] Result := FGrowProxy(aCurrentSize, aRequiredSize);
	movq	88(%rdi),%rdi
# Var aRequiredSize located in register rdx
# Var aCurrentSize located in register rsi
	call	*80(%rax)
# Var $result located in register rax
# [2426] end;
	popq	%rcx
.Lc437:
	ret
.Lc434:
.Le28:
	.size	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCUSTOMGROWTHSTRATEGY_$__$$_DOGETGROWSIZE$QWORD$QWORD$$QWORD, .Le28 - NEXTPAS.CORE.COLLECTIONS.BASE$_$TCUSTOMGROWTHSTRATEGY_$__$$_DOGETGROWSIZE$QWORD$QWORD$$QWORD

.section .text.n_nextpas.core.collections.base$_$tcustomgrowthstrategy_$__$$_create$hoscohd$2nni,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCUSTOMGROWTHSTRATEGY_$__$$_CREATE$hoScOhd$2NnI
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCUSTOMGROWTHSTRATEGY_$__$$_CREATE$hoScOhd$2NnI,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCUSTOMGROWTHSTRATEGY_$__$$_CREATE$hoScOhd$2NnI:
.Lc439:
# Temps allocated between rbp-228 and rbp-40
# [2429] begin
	pushq	%rbp
.Lc440:
	movq	%rsp,%rbp
.Lc441:
	leaq	-240(%rsp),%rsp
# Var aGrowFunc located at rbp-8, size=OS_64
# Var aData located at rbp-16, size=OS_64
# Var $vmt located at rbp-24, size=OS_64
# Var $self located at rbp-32, size=OS_64
# Var $vmt_afterconstruction_local located at rbp-40, size=OS_S64
	movq	%rdi,-32(%rbp)
	movq	%rsi,-24(%rbp)
	movq	%rdx,-8(%rbp)
	movq	%rcx,-16(%rbp)
	cmpq	$1,-24(%rbp)
	jne	.Lj909
	movq	-32(%rbp),%rdi
	movq	%rdi,%rax
	call	*104(%rdi)
	movq	%rax,-32(%rbp)
.Lj909:
	cmpq	$0,-32(%rbp)
	je	.Lj906
	leaq	-64(%rbp),%rdx
	leaq	-128(%rbp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,-132(%rbp)
	testl	%eax,%eax
	jne	.Lj916
	movq	$-1,-40(%rbp)
# [2430] inherited Create;
	xorl	%esi,%esi
	movq	-32(%rbp),%rdi
	call	SYSTEM$_$TOBJECT_$__$$_CREATE$$TOBJECT
# [2432] if aGrowFunc = nil then
	cmpq	$0,-8(%rbp)
	jne	.Lj918
.Lj919:
# [2433] raise EArgumentNil.Create('TCustomGrowthStrategy.Create: aGrowFunc is nil');
	movq	$.Ld28,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj919,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj918:
# [2435] FGrowFunc  := aGrowFunc;
	movq	-32(%rbp),%rdx
	movq	-8(%rbp),%rax
	movq	%rax,48(%rdx)
# [2436] FData      := aData;
	movq	-32(%rbp),%rdx
	movq	-16(%rbp),%rax
	movq	%rax,40(%rdx)
# [2438] FGrowProxy := @DoGetGrowSizeFunc;
	movq	-32(%rbp),%rax
	movq	%rax,%rdx
	movq	$NEXTPAS.CORE.COLLECTIONS.BASE$_$TCUSTOMGROWTHSTRATEGY_$__$$_DOGETGROWSIZEFUNC$QWORD$QWORD$$QWORD,%rcx
	movq	%rcx,80(%rax)
	movq	%rdx,88(%rax)
# [2439] end;
	movq	$1,-40(%rbp)
	cmpq	$0,-32(%rbp)
	setneb	%al
	cmpq	$0,-24(%rbp)
	setneb	%dl
	andb	%dl,%al
	je	.Lj921
	movq	-32(%rbp),%rdi
	movq	(%rdi),%rax
	call	*136(%rax)
.Lj921:
.Lj916:
	call	fpc_popaddrstack
	cmpl	$0,-132(%rbp)
	je	.Lj914
	leaq	-160(%rbp),%rdx
	leaq	-224(%rbp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,-228(%rbp)
	testl	%eax,%eax
	jne	.Lj922
	cmpq	$0,-24(%rbp)
	je	.Lj924
	movq	-40(%rbp),%rsi
	movq	-32(%rbp),%rdi
	movq	(%rdi),%rax
	call	*96(%rax)
.Lj924:
	call	fpc_popaddrstack
	call	fpc_reraise
.Lj922:
	call	fpc_popaddrstack
	cmpl	$0,-228(%rbp)
	je	.Lj925
	call	fpc_raise_nested
.Lj925:
	call	fpc_doneexception
.Lj914:
.Lj906:
	movq	-32(%rbp),%rax
.Lc442:
	movq	%rbp,%rsp
.Lc443:
	popq	%rbp
	ret
.Lc438:

.section .text.n_nextpas.core.collections.base$_$tcustomgrowthstrategy_$__$$_create$h3_a1el2qend,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCUSTOMGROWTHSTRATEGY_$__$$_CREATE$h3_a1El2QeND
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCUSTOMGROWTHSTRATEGY_$__$$_CREATE$h3_a1El2QeND,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCUSTOMGROWTHSTRATEGY_$__$$_CREATE$h3_a1El2QeND:
.Lc445:
# Temps allocated between rbp-256 and rbp-48
# [2442] begin
	pushq	%rbp
.Lc446:
	movq	%rsp,%rbp
.Lc447:
	leaq	-256(%rsp),%rsp
# Var aGrowMethod located at rbp-16, size=OS_128
# Var aData located at rbp-24, size=OS_64
# Var $vmt located at rbp-32, size=OS_64
# Var $self located at rbp-40, size=OS_64
# Var $vmt_afterconstruction_local located at rbp-48, size=OS_S64
	movq	%rdi,-40(%rbp)
	movq	%rsi,-32(%rbp)
	movq	%rdx,-16(%rbp)
	movq	%rcx,-8(%rbp)
	movq	%r8,-24(%rbp)
	cmpq	$1,-32(%rbp)
	jne	.Lj929
	movq	-40(%rbp),%rdi
	movq	%rdi,%rax
	call	*104(%rdi)
	movq	%rax,-40(%rbp)
.Lj929:
	cmpq	$0,-40(%rbp)
	je	.Lj926
	leaq	-72(%rbp),%rdx
	leaq	-136(%rbp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,-140(%rbp)
	testl	%eax,%eax
	jne	.Lj936
	movq	$-1,-48(%rbp)
# [2443] inherited Create;
	xorl	%esi,%esi
	movq	-40(%rbp),%rdi
	call	SYSTEM$_$TOBJECT_$__$$_CREATE$$TOBJECT
# [2445] if aGrowMethod = nil then
	cmpq	$0,-16(%rbp)
	jne	.Lj938
.Lj939:
# [2446] raise EArgumentNil.Create('TCustomGrowthStrategy.Create: aGrowMethod is nil');
	movq	$.Ld29,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj939,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj938:
# [2448] FGrowMethod := aGrowMethod;
	movq	-40(%rbp),%rax
	movdqa	-16(%rbp),%xmm0
	movdqu	%xmm0,56(%rax)
# [2449] FData       := aData;
	movq	-40(%rbp),%rdx
	movq	-24(%rbp),%rax
	movq	%rax,40(%rdx)
# [2451] FGrowProxy  := @DoGetGrowSizeMethod;
	movq	-40(%rbp),%rax
	movq	%rax,%rdx
	movq	$NEXTPAS.CORE.COLLECTIONS.BASE$_$TCUSTOMGROWTHSTRATEGY_$__$$_DOGETGROWSIZEMETHOD$QWORD$QWORD$$QWORD,%rcx
	movq	%rcx,80(%rax)
	movq	%rdx,88(%rax)
# [2452] end;
	movq	$1,-48(%rbp)
	cmpq	$0,-40(%rbp)
	setneb	%al
	cmpq	$0,-32(%rbp)
	setneb	%dl
	andb	%dl,%al
	je	.Lj941
	movq	-40(%rbp),%rdi
	movq	(%rdi),%rax
	call	*136(%rax)
.Lj941:
.Lj936:
	call	fpc_popaddrstack
	cmpl	$0,-140(%rbp)
	je	.Lj934
	leaq	-168(%rbp),%rdx
	leaq	-232(%rbp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,-236(%rbp)
	testl	%eax,%eax
	jne	.Lj942
	cmpq	$0,-32(%rbp)
	je	.Lj944
	movq	-48(%rbp),%rsi
	movq	-40(%rbp),%rdi
	movq	(%rdi),%rax
	call	*96(%rax)
.Lj944:
	call	fpc_popaddrstack
	call	fpc_reraise
.Lj942:
	call	fpc_popaddrstack
	cmpl	$0,-236(%rbp)
	je	.Lj945
	call	fpc_raise_nested
.Lj945:
	call	fpc_doneexception
.Lj934:
.Lj926:
	movq	-40(%rbp),%rax
.Lc448:
	movq	%rbp,%rsp
.Lc449:
	popq	%rbp
	ret
.Lc444:

.section .text.n_nextpas.core.collections.base$_$tcustomgrowthstrategy_$__$$_create$hiw9pgtgr5bm,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCUSTOMGROWTHSTRATEGY_$__$$_CREATE$hIw9pGTgr5BM
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCUSTOMGROWTHSTRATEGY_$__$$_CREATE$hIw9pGTgr5BM,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCUSTOMGROWTHSTRATEGY_$__$$_CREATE$hIw9pGTgr5BM:
.Lc451:
# Temps allocated between rbp-220 and rbp-32
# [2455] begin
	pushq	%rbp
.Lc452:
	movq	%rsp,%rbp
.Lc453:
	leaq	-224(%rsp),%rsp
# Var aGrowRefFunc located at rbp-8, size=OS_64
# Var $vmt located at rbp-16, size=OS_64
# Var $self located at rbp-24, size=OS_64
# Var $vmt_afterconstruction_local located at rbp-32, size=OS_S64
	movq	%rdi,-24(%rbp)
	movq	%rsi,-16(%rbp)
	movq	%rdx,-8(%rbp)
	movq	%rdx,%rdi
	call	fpc_intf_incr_ref
	cmpq	$1,-16(%rbp)
	jne	.Lj949
	movq	-24(%rbp),%rdi
	movq	%rdi,%rax
	call	*104(%rdi)
	movq	%rax,-24(%rbp)
.Lj949:
	cmpq	$0,-24(%rbp)
	je	.Lj946
	leaq	-56(%rbp),%rdx
	leaq	-120(%rbp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,-124(%rbp)
	testl	%eax,%eax
	jne	.Lj956
	movq	$-1,-32(%rbp)
	leaq	-152(%rbp),%rdx
	leaq	-216(%rbp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,-220(%rbp)
	testl	%eax,%eax
	jne	.Lj958
# [2456] inherited Create;
	xorl	%esi,%esi
	movq	-24(%rbp),%rdi
	call	SYSTEM$_$TOBJECT_$__$$_CREATE$$TOBJECT
# [2458] if aGrowRefFunc = nil then
	cmpq	$0,-8(%rbp)
	jne	.Lj961
.Lj962:
# [2459] raise EArgumentNil.Create('TCustomGrowthStrategy.Create: aGrowRefFunc is nil');
	movq	$.Ld30,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj962,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj961:
# [2461] FGrowRefFunc := aGrowRefFunc;
	movq	-24(%rbp),%rax
	leaq	72(%rax),%rdi
	movq	-8(%rbp),%rsi
	call	fpc_intf_assign
# [2462] FData        := nil;
	movq	-24(%rbp),%rax
	movq	$0,40(%rax)
# [2464] FGrowProxy   := @DoGetGrowSizeRefFunc;
	movq	-24(%rbp),%rdx
	movq	%rdx,%rax
	movq	$NEXTPAS.CORE.COLLECTIONS.BASE$_$TCUSTOMGROWTHSTRATEGY_$__$$_DOGETGROWSIZEREFFUNC$QWORD$QWORD$$QWORD,%rcx
	movq	%rcx,80(%rdx)
	movq	%rax,88(%rdx)
.Lj958:
	call	fpc_popaddrstack
# [2465] end;
	leaq	-8(%rbp),%rdi
	call	fpc_intf_decr_ref
	cmpl	$0,-220(%rbp)
	je	.Lj957
	call	fpc_reraise
	movl	$0,-220(%rbp)
	jmp	.Lj958
.Lj957:
	movq	$1,-32(%rbp)
	cmpq	$0,-24(%rbp)
	setneb	%dl
	cmpq	$0,-16(%rbp)
	setneb	%al
	andb	%al,%dl
	je	.Lj964
	movq	-24(%rbp),%rdi
	movq	(%rdi),%rax
	call	*136(%rax)
.Lj964:
.Lj956:
	call	fpc_popaddrstack
	cmpl	$0,-124(%rbp)
	je	.Lj954
	leaq	-152(%rbp),%rdx
	leaq	-216(%rbp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,-220(%rbp)
	testl	%eax,%eax
	jne	.Lj965
	cmpq	$0,-16(%rbp)
	je	.Lj967
	movq	-32(%rbp),%rsi
	movq	-24(%rbp),%rdi
	movq	(%rdi),%rax
	call	*96(%rax)
.Lj967:
	call	fpc_popaddrstack
	call	fpc_reraise
.Lj965:
	call	fpc_popaddrstack
	cmpl	$0,-220(%rbp)
	je	.Lj968
	call	fpc_raise_nested
.Lj968:
	call	fpc_doneexception
.Lj954:
.Lj946:
	movq	-24(%rbp),%rax
.Lc454:
	movq	%rbp,%rsp
.Lc455:
	popq	%rbp
	ret
.Lc450:

.section .text.n_nextpas.core.collections.base$_$tcalcgrowstrategy_$__$$_dogetgrowsize$qword$qword$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCALCGROWSTRATEGY_$__$$_DOGETGROWSIZE$QWORD$QWORD$$QWORD
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCALCGROWSTRATEGY_$__$$_DOGETGROWSIZE$QWORD$QWORD$$QWORD,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCALCGROWSTRATEGY_$__$$_DOGETGROWSIZE$QWORD$QWORD$$QWORD:
.Lc457:
# [2468] begin
	pushq	%rbx
.Lc458:
	pushq	%r12
.Lc459:
	pushq	%r13
.Lc460:
	movq	%rdi,%rbx
# Var $self located in register rbx
	movq	%rsi,%r12
# Var aCurrentSize located in register r12
	movq	%rdx,%r13
# Var aRequiredSize located in register r13
# Var $result located in register r12
# Var aCurrentSize located in register r12
# [2471] while Result < aRequiredSize do
	cmpq	%rsi,%rdx
	jna	.Lj972
	.p2align 4,,10
	.p2align 3
.Lj973:
# [2472] Result := DoCalc(Result);
	movq	%r12,%rsi
	movq	%rbx,%rdi
	movq	(%rbx),%rax
	call	*216(%rax)
	movq	%rax,%r12
	cmpq	%rax,%r13
	ja	.Lj973
.Lj972:
# [2473] end;
	movq	%r12,%rax
	popq	%r13
.Lc461:
	popq	%r12
.Lc462:
	popq	%rbx
.Lc463:
	ret
.Lc456:
.Le29:
	.size	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCALCGROWSTRATEGY_$__$$_DOGETGROWSIZE$QWORD$QWORD$$QWORD, .Le29 - NEXTPAS.CORE.COLLECTIONS.BASE$_$TCALCGROWSTRATEGY_$__$$_DOGETGROWSIZE$QWORD$QWORD$$QWORD

.section .text.n_nextpas.core.collections.base$_$tdoublinggrowstrategy_$__$$_docalc$qword$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TDOUBLINGGROWSTRATEGY_$__$$_DOCALC$QWORD$$QWORD
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TDOUBLINGGROWSTRATEGY_$__$$_DOCALC$QWORD$$QWORD,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TDOUBLINGGROWSTRATEGY_$__$$_DOCALC$QWORD$$QWORD:
.Lc465:
# Var $result located in register rax
# Var $self located in register rdi
# Var aCurrentSize located in register rsi
# [2476] begin
# [2477] if aCurrentSize = 0 then
	movl	$1,%ecx
	testq	%rsi,%rsi
# [2478] Result := 1
	cmoveq	%rcx,%rax
	je	.Lj980
# [2481] if aCurrentSize > High(SizeUInt) div 2 then
	movq	$9223372036854775807,%rdx
# [2482] Result := High(SizeUInt)
	movq	$-1,%rax
	cmpq	%rdx,%rsi
	ja	.Lj980
# [2484] Result := aCurrentSize * 2;
	leaq	(%rsi,%rsi,1),%rax
.Lj980:
.Lc466:
# [2486] end;
	ret
.Lc464:
.Le30:
	.size	NEXTPAS.CORE.COLLECTIONS.BASE$_$TDOUBLINGGROWSTRATEGY_$__$$_DOCALC$QWORD$$QWORD, .Le30 - NEXTPAS.CORE.COLLECTIONS.BASE$_$TDOUBLINGGROWSTRATEGY_$__$$_DOCALC$QWORD$$QWORD

.section .text.n_nextpas.core.collections.base$_$tdoublinggrowstrategy_$__$$_$destroy,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TDOUBLINGGROWSTRATEGY_$__$$_$destroy
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TDOUBLINGGROWSTRATEGY_$__$$_$destroy,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TDOUBLINGGROWSTRATEGY_$__$$_$destroy:
.Lc468:
# [2489] begin
	pushq	%rax
.Lc469:
# [2490] if FGlobal <> nil then
	cmpq	$0,U_$NEXTPAS.CORE.COLLECTIONS.BASE_$$__static_tdoublinggrowstrategy_FGLOBAL
	je	.Lj987
# [2492] FGlobal.Free;
	movq	U_$NEXTPAS.CORE.COLLECTIONS.BASE_$$__static_tdoublinggrowstrategy_FGLOBAL,%rdi
	call	SYSTEM$_$TOBJECT_$__$$_FREE
# [2493] FGlobal := nil;
	movq	$0,U_$NEXTPAS.CORE.COLLECTIONS.BASE_$$__static_tdoublinggrowstrategy_FGLOBAL
.Lj987:
# [2495] end;
	popq	%rcx
.Lc470:
	ret
.Lc467:
.Le31:
	.size	NEXTPAS.CORE.COLLECTIONS.BASE$_$TDOUBLINGGROWSTRATEGY_$__$$_$destroy, .Le31 - NEXTPAS.CORE.COLLECTIONS.BASE$_$TDOUBLINGGROWSTRATEGY_$__$$_$destroy

.section .text.n_nextpas.core.collections.base$_$tdoublinggrowstrategy_$__$$_getglobal$$tdoublinggrowstrategy,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TDOUBLINGGROWSTRATEGY_$__$$_GETGLOBAL$$TDOUBLINGGROWSTRATEGY
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TDOUBLINGGROWSTRATEGY_$__$$_GETGLOBAL$$TDOUBLINGGROWSTRATEGY,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TDOUBLINGGROWSTRATEGY_$__$$_GETGLOBAL$$TDOUBLINGGROWSTRATEGY:
.Lc472:
# [2498] begin
	pushq	%rax
.Lc473:
# [2499] Result := TDoublingGrowStrategy.Create;
	movq	$VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY,%rdi
	movl	$1,%esi
	call	SYSTEM$_$TOBJECT_$__$$_CREATE$$TOBJECT
# Var $result located in register rax
# [2500] end;
	popq	%rcx
.Lc474:
	ret
.Lc471:

.section .text.n_nextpas.core.collections.base$_$tfixedgrowstrategy_$__$$_getfixedsize$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TFIXEDGROWSTRATEGY_$__$$_GETFIXEDSIZE$$QWORD
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TFIXEDGROWSTRATEGY_$__$$_GETFIXEDSIZE$$QWORD,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TFIXEDGROWSTRATEGY_$__$$_GETFIXEDSIZE$$QWORD:
.Lc476:
# Var $self located in register rdi
# [2503] begin
# Var $result located in register rax
# [2504] Result := FFixedSize;
	movq	40(%rdi),%rax
.Lc477:
# [2505] end;
	ret
.Lc475:

.section .text.n_nextpas.core.collections.base$_$tfixedgrowstrategy_$__$$_docalc$qword$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TFIXEDGROWSTRATEGY_$__$$_DOCALC$QWORD$$QWORD
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TFIXEDGROWSTRATEGY_$__$$_DOCALC$QWORD$$QWORD,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TFIXEDGROWSTRATEGY_$__$$_DOCALC$QWORD$$QWORD:
.Lc479:
# Var $self located in register rdi
# Var aCurrentSize located in register rsi
# [2508] begin
# [2509] Result := aCurrentSize + FFixedSize;
	movq	40(%rdi),%rax
	addq	%rsi,%rax
# Var $result located in register rax
.Lc480:
# [2510] end;
	ret
.Lc478:
.Le32:
	.size	NEXTPAS.CORE.COLLECTIONS.BASE$_$TFIXEDGROWSTRATEGY_$__$$_DOCALC$QWORD$$QWORD, .Le32 - NEXTPAS.CORE.COLLECTIONS.BASE$_$TFIXEDGROWSTRATEGY_$__$$_DOCALC$QWORD$$QWORD

.section .text.n_nextpas.core.collections.base$_$tfixedgrowstrategy_$__$$_create$qword$$tfixedgrowstrategy,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TFIXEDGROWSTRATEGY_$__$$_CREATE$QWORD$$TFIXEDGROWSTRATEGY
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TFIXEDGROWSTRATEGY_$__$$_CREATE$QWORD$$TFIXEDGROWSTRATEGY,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TFIXEDGROWSTRATEGY_$__$$_CREATE$QWORD$$TFIXEDGROWSTRATEGY:
.Lc482:
# Temps allocated between rbp-220 and rbp-32
# [2513] begin
	pushq	%rbp
.Lc483:
	movq	%rsp,%rbp
.Lc484:
	leaq	-224(%rsp),%rsp
# Var aFixedSize located at rbp-8, size=OS_64
# Var $vmt located at rbp-16, size=OS_64
# Var $self located at rbp-24, size=OS_64
# Var $vmt_afterconstruction_local located at rbp-32, size=OS_S64
	movq	%rdi,-24(%rbp)
	movq	%rsi,-16(%rbp)
	movq	%rdx,-8(%rbp)
	cmpq	$1,-16(%rbp)
	jne	.Lj997
	movq	-24(%rbp),%rdi
	movq	%rdi,%rax
	call	*104(%rdi)
	movq	%rax,-24(%rbp)
.Lj997:
	cmpq	$0,-24(%rbp)
	je	.Lj994
	leaq	-56(%rbp),%rdx
	leaq	-120(%rbp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,-124(%rbp)
	testl	%eax,%eax
	jne	.Lj1004
	movq	$-1,-32(%rbp)
# [2514] inherited Create;
	xorl	%esi,%esi
	movq	-24(%rbp),%rdi
	call	SYSTEM$_$TOBJECT_$__$$_CREATE$$TOBJECT
# [2516] if aFixedSize = 0 then
	cmpq	$0,-8(%rbp)
	jne	.Lj1006
.Lj1007:
# [2517] raise EInvalidArgument.Create('TFixedGrowStrategy.Create: aFixedSize is 0');
	movq	$.Ld31,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj1007,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj1006:
# [2519] FFixedSize := aFixedSize;
	movq	-24(%rbp),%rdx
	movq	-8(%rbp),%rax
	movq	%rax,40(%rdx)
# [2520] end;
	movq	$1,-32(%rbp)
	cmpq	$0,-24(%rbp)
	setneb	%al
	cmpq	$0,-16(%rbp)
	setneb	%dl
	andb	%dl,%al
	je	.Lj1009
	movq	-24(%rbp),%rdi
	movq	(%rdi),%rax
	call	*136(%rax)
.Lj1009:
.Lj1004:
	call	fpc_popaddrstack
	cmpl	$0,-124(%rbp)
	je	.Lj1002
	leaq	-152(%rbp),%rdx
	leaq	-216(%rbp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,-220(%rbp)
	testl	%eax,%eax
	jne	.Lj1010
	cmpq	$0,-16(%rbp)
	je	.Lj1012
	movq	-32(%rbp),%rsi
	movq	-24(%rbp),%rdi
	movq	(%rdi),%rax
	call	*96(%rax)
.Lj1012:
	call	fpc_popaddrstack
	call	fpc_reraise
.Lj1010:
	call	fpc_popaddrstack
	cmpl	$0,-220(%rbp)
	je	.Lj1013
	call	fpc_raise_nested
.Lj1013:
	call	fpc_doneexception
.Lj1002:
.Lj994:
	movq	-24(%rbp),%rax
.Lc485:
	movq	%rbp,%rsp
.Lc486:
	popq	%rbp
	ret
.Lc481:
.Le33:
	.size	NEXTPAS.CORE.COLLECTIONS.BASE$_$TFIXEDGROWSTRATEGY_$__$$_CREATE$QWORD$$TFIXEDGROWSTRATEGY, .Le33 - NEXTPAS.CORE.COLLECTIONS.BASE$_$TFIXEDGROWSTRATEGY_$__$$_CREATE$QWORD$$TFIXEDGROWSTRATEGY

.section .text.n_nextpas.core.collections.base$_$tfactorgrowstrategy_$__$$_getfactor$$single,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TFACTORGROWSTRATEGY_$__$$_GETFACTOR$$SINGLE
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TFACTORGROWSTRATEGY_$__$$_GETFACTOR$$SINGLE,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TFACTORGROWSTRATEGY_$__$$_GETFACTOR$$SINGLE:
.Lc488:
# Var $self located in register rdi
# [2523] begin
# Var $result located in register xmm0
# [2524] Result := FFactor;
	movss	40(%rdi),%xmm0
.Lc489:
# [2525] end;
	ret
.Lc487:

.section .text.n_nextpas.core.collections.base$_$tfactorgrowstrategy_$__$$_docalc$qword$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TFACTORGROWSTRATEGY_$__$$_DOCALC$QWORD$$QWORD
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TFACTORGROWSTRATEGY_$__$$_DOCALC$QWORD$$QWORD,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TFACTORGROWSTRATEGY_$__$$_DOCALC$QWORD$$QWORD:
.Lc491:
# Temps allocated between rsp+16 and rsp+28
# [2533] begin
	pushq	%rbx
.Lc492:
	leaq	-32(%rsp),%rsp
.Lc493:
# Var $result located in register rbx
# Var LProduct located in stack [rsp+24]
# Var LCeiled located in register rax
# Var $self located in register rdi
# Var aCurrentSize located in register rsi
# [2534] if aCurrentSize = 0 then
	movl	$1,%eax
	testq	%rsi,%rsi
# [2535] Result := 1
	cmoveq	%rax,%rbx
	je	.Lj1020
# [2538] LProduct := aCurrentSize * FFactor;
	btq	$63,%rsi
	cvtsi2ssq	%rsi,%xmm0
	jnc	.Lj1021
	addss	.Ld32,%xmm0
.Lj1021:
	mulss	40(%rdi),%xmm0
	movss	%xmm0,24(%rsp)
# [2539] if (LProduct > MAX_SAFE_SIZEUINT) or IsInfinite(LProduct) or IsNaN(LProduct) then
	comiss	.Ld33,%xmm0
	jp	.Lj1024
	ja	.Lj1022
.Lj1024:
	cvtss2sd	24(%rsp),%xmm0
	call	MATH_$$_ISINFINITE$DOUBLE$$BOOLEAN
	testb	%al,%al
	jne	.Lj1022
	cvtss2sd	24(%rsp),%xmm0
	call	MATH_$$_ISNAN$DOUBLE$$BOOLEAN
	testb	%al,%al
	je	.Lj1026
.Lj1022:
# [2540] Result := MAX_SAFE_SIZEUINT
	movq	$9223372036854775807,%rbx
	jmp	.Lj1020
	.p2align 4,,10
	.p2align 3
.Lj1026:
# [2543] LCeiled := Ceil(LProduct);
	cvtss2sd	24(%rsp),%xmm0
	movsd	%xmm0,16(%rsp)
	fldl	16(%rsp)
	fstpt	(%rsp)
	call	MATH_$$_CEIL$EXTENDED$$LONGINT
	movslq	%eax,%rbx
.Lj1020:
# [2547] end;
	movq	%rbx,%rax
	leaq	32(%rsp),%rsp
	popq	%rbx
.Lc494:
	ret
.Lc490:
.Le34:
	.size	NEXTPAS.CORE.COLLECTIONS.BASE$_$TFACTORGROWSTRATEGY_$__$$_DOCALC$QWORD$$QWORD, .Le34 - NEXTPAS.CORE.COLLECTIONS.BASE$_$TFACTORGROWSTRATEGY_$__$$_DOCALC$QWORD$$QWORD

.section .text.n_nextpas.core.collections.base$_$tfactorgrowstrategy_$__$$_create$single$$tfactorgrowstrategy,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TFACTORGROWSTRATEGY_$__$$_CREATE$SINGLE$$TFACTORGROWSTRATEGY
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TFACTORGROWSTRATEGY_$__$$_CREATE$SINGLE$$TFACTORGROWSTRATEGY,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TFACTORGROWSTRATEGY_$__$$_CREATE$SINGLE$$TFACTORGROWSTRATEGY:
.Lc496:
# Temps allocated between rbp-240 and rbp-32
# [2550] begin
	pushq	%rbp
.Lc497:
	movq	%rsp,%rbp
.Lc498:
	leaq	-240(%rsp),%rsp
# Var aFactor located at rbp-8, size=OS_F32
# Var $vmt located at rbp-16, size=OS_64
# Var $self located at rbp-24, size=OS_64
# Var $vmt_afterconstruction_local located at rbp-32, size=OS_S64
	movq	%rdi,-24(%rbp)
	movq	%rsi,-16(%rbp)
	movss	%xmm0,-8(%rbp)
	cmpq	$1,-16(%rbp)
	jne	.Lj1031
	movq	-24(%rbp),%rdi
	movq	%rdi,%rax
	call	*104(%rdi)
	movq	%rax,-24(%rbp)
.Lj1031:
	cmpq	$0,-24(%rbp)
	je	.Lj1028
	leaq	-56(%rbp),%rdx
	leaq	-120(%rbp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,-124(%rbp)
	testl	%eax,%eax
	jne	.Lj1038
	movq	$-1,-32(%rbp)
# [2551] inherited Create;
	xorl	%esi,%esi
	movq	-24(%rbp),%rdi
	call	SYSTEM$_$TOBJECT_$__$$_CREATE$$TOBJECT
# [2553] if aFactor <= 0 then
	xorps	%xmm0,%xmm0
	comiss	-8(%rbp),%xmm0
	jp	.Lj1040
	jnae	.Lj1040
.Lj1042:
# [2554] raise EInvalidArgument.Create('TFactorGrowStrategy.Create: aFactor is 0');
	movq	$.Ld34,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj1042,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj1040:
# [2556] FFactor := aFactor;
	movq	-24(%rbp),%rdx
	movl	-8(%rbp),%eax
	movl	%eax,40(%rdx)
# [2557] end;
	movq	$1,-32(%rbp)
	cmpq	$0,-24(%rbp)
	setneb	%al
	cmpq	$0,-16(%rbp)
	setneb	%dl
	andb	%dl,%al
	je	.Lj1044
	movq	-24(%rbp),%rdi
	movq	(%rdi),%rax
	call	*136(%rax)
.Lj1044:
.Lj1038:
	call	fpc_popaddrstack
	cmpl	$0,-124(%rbp)
	je	.Lj1036
	leaq	-152(%rbp),%rdx
	leaq	-216(%rbp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,-220(%rbp)
	testl	%eax,%eax
	jne	.Lj1045
	cmpq	$0,-16(%rbp)
	je	.Lj1047
	movq	-32(%rbp),%rsi
	movq	-24(%rbp),%rdi
	movq	(%rdi),%rax
	call	*96(%rax)
.Lj1047:
	call	fpc_popaddrstack
	call	fpc_reraise
.Lj1045:
	call	fpc_popaddrstack
	cmpl	$0,-220(%rbp)
	je	.Lj1048
	call	fpc_raise_nested
.Lj1048:
	call	fpc_doneexception
.Lj1036:
.Lj1028:
	movq	-24(%rbp),%rax
.Lc499:
	movq	%rbp,%rsp
.Lc500:
	popq	%rbp
	ret
.Lc495:
.Le35:
	.size	NEXTPAS.CORE.COLLECTIONS.BASE$_$TFACTORGROWSTRATEGY_$__$$_CREATE$SINGLE$$TFACTORGROWSTRATEGY, .Le35 - NEXTPAS.CORE.COLLECTIONS.BASE$_$TFACTORGROWSTRATEGY_$__$$_CREATE$SINGLE$$TFACTORGROWSTRATEGY

.section .text.n_nextpas.core.collections.base$_$tpoweroftwogrowstrategy_$__$$_$destroy,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TPOWEROFTWOGROWSTRATEGY_$__$$_$destroy
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TPOWEROFTWOGROWSTRATEGY_$__$$_$destroy,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TPOWEROFTWOGROWSTRATEGY_$__$$_$destroy:
.Lc502:
# [2560] begin
	pushq	%rax
.Lc503:
# [2561] if FGlobal <> nil then
	cmpq	$0,U_$NEXTPAS.CORE.COLLECTIONS.BASE_$$__static_tpoweroftwogrowstrategy_FGLOBAL
	je	.Lj1052
# [2563] FGlobal.Free;
	movq	U_$NEXTPAS.CORE.COLLECTIONS.BASE_$$__static_tpoweroftwogrowstrategy_FGLOBAL,%rdi
	call	SYSTEM$_$TOBJECT_$__$$_FREE
# [2564] FGlobal := nil;
	movq	$0,U_$NEXTPAS.CORE.COLLECTIONS.BASE_$$__static_tpoweroftwogrowstrategy_FGLOBAL
.Lj1052:
# [2566] end;
	popq	%rcx
.Lc504:
	ret
.Lc501:
.Le36:
	.size	NEXTPAS.CORE.COLLECTIONS.BASE$_$TPOWEROFTWOGROWSTRATEGY_$__$$_$destroy, .Le36 - NEXTPAS.CORE.COLLECTIONS.BASE$_$TPOWEROFTWOGROWSTRATEGY_$__$$_$destroy

.section .text.n_nextpas.core.collections.base$_$tpoweroftwogrowstrategy_$__$$_getglobal$$tpoweroftwogrowstrategy,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TPOWEROFTWOGROWSTRATEGY_$__$$_GETGLOBAL$$TPOWEROFTWOGROWSTRATEGY
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TPOWEROFTWOGROWSTRATEGY_$__$$_GETGLOBAL$$TPOWEROFTWOGROWSTRATEGY,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TPOWEROFTWOGROWSTRATEGY_$__$$_GETGLOBAL$$TPOWEROFTWOGROWSTRATEGY:
.Lc506:
# [2569] begin
	pushq	%rax
.Lc507:
# [2570] Result := TPowerOfTwoGrowStrategy.Create;
	movq	$VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY,%rdi
	movl	$1,%esi
	call	SYSTEM$_$TOBJECT_$__$$_CREATE$$TOBJECT
# Var $result located in register rax
# [2571] end;
	popq	%rcx
.Lc508:
	ret
.Lc505:

.section .text.n_nextpas.core.collections.base$_$tpoweroftwogrowstrategy_$__$$_dogetgrowsize$qword$qword$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TPOWEROFTWOGROWSTRATEGY_$__$$_DOGETGROWSIZE$QWORD$QWORD$$QWORD
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TPOWEROFTWOGROWSTRATEGY_$__$$_DOGETGROWSIZE$QWORD$QWORD$$QWORD,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TPOWEROFTWOGROWSTRATEGY_$__$$_DOGETGROWSIZE$QWORD$QWORD$$QWORD:
.Lc510:
# Var $result located in register rax
# Var $self located in register rdi
# Var aCurrentSize located in register rsi
# Var aRequiredSize located in register rdx
# [2574] begin
# [2577] Exit(0);
	xorl	%eax,%eax
# [2576] if aRequiredSize = 0 then
	testq	%rdx,%rdx
	je	.Lj1055
# [2578] Result := 1;
	movl	$1,%eax
# [2579] while Result < aRequiredSize do
	cmpq	%rax,%rdx
	jna	.Lj1055
	.p2align 4,,10
	.p2align 3
.Lj1063:
# [2580] Result := Result shl 1;
	shlq	$1,%rax
	cmpq	%rax,%rdx
	ja	.Lj1063
.Lj1055:
.Lc511:
# [2581] end;
	ret
.Lc509:
.Le37:
	.size	NEXTPAS.CORE.COLLECTIONS.BASE$_$TPOWEROFTWOGROWSTRATEGY_$__$$_DOGETGROWSIZE$QWORD$QWORD$$QWORD, .Le37 - NEXTPAS.CORE.COLLECTIONS.BASE$_$TPOWEROFTWOGROWSTRATEGY_$__$$_DOGETGROWSIZE$QWORD$QWORD$$QWORD

.section .text.n_nextpas.core.collections.base$_$tgoldenratiogrowstrategy_$__$$_docalc$qword$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TGOLDENRATIOGROWSTRATEGY_$__$$_DOCALC$QWORD$$QWORD
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TGOLDENRATIOGROWSTRATEGY_$__$$_DOCALC$QWORD$$QWORD,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TGOLDENRATIOGROWSTRATEGY_$__$$_DOCALC$QWORD$$QWORD:
.Lc513:
# Temps allocated between rsp+16 and rsp+28
# [2590] begin
	pushq	%rbx
.Lc514:
	leaq	-32(%rsp),%rsp
.Lc515:
# Var $result located in register rbx
# Var LProduct located in stack [rsp+24]
# Var LCeiled located in register rax
# Var $self located in register rdi
# Var aCurrentSize located in register rsi
# [2591] if aCurrentSize = 0 then
	movl	$1,%eax
	testq	%rsi,%rsi
# [2592] Result := 1
	cmoveq	%rax,%rbx
	je	.Lj1070
# [2595] LProduct := aCurrentSize * GOLDEN_RATIO;
	btq	$63,%rsi
	cvtsi2ssq	%rsi,%xmm0
	jnc	.Lj1071
	addss	.Ld35,%xmm0
.Lj1071:
	mulss	TC_$NEXTPAS.CORE.COLLECTIONS.BASE$_$TGOLDENRATIOGROWSTRATEGY_$_DOCALC$QWORD$$QWORD_$$_GOLDEN_RATIO,%xmm0
	movss	%xmm0,24(%rsp)
# [2596] if (LProduct > MAX_SAFE_SIZEUINT) or IsInfinite(LProduct) or IsNaN(LProduct) then
	comiss	.Ld33,%xmm0
	jp	.Lj1074
	ja	.Lj1072
.Lj1074:
	cvtss2sd	24(%rsp),%xmm0
	call	MATH_$$_ISINFINITE$DOUBLE$$BOOLEAN
	testb	%al,%al
	jne	.Lj1072
	cvtss2sd	24(%rsp),%xmm0
	call	MATH_$$_ISNAN$DOUBLE$$BOOLEAN
	testb	%al,%al
	je	.Lj1076
.Lj1072:
# [2597] Result := MAX_SAFE_SIZEUINT
	movq	$9223372036854775807,%rbx
	jmp	.Lj1070
	.p2align 4,,10
	.p2align 3
.Lj1076:
# [2600] LCeiled := Ceil(LProduct);
	cvtss2sd	24(%rsp),%xmm0
	movsd	%xmm0,16(%rsp)
	fldl	16(%rsp)
	fstpt	(%rsp)
	call	MATH_$$_CEIL$EXTENDED$$LONGINT
	movslq	%eax,%rbx
.Lj1070:
# [2604] end;
	movq	%rbx,%rax
	leaq	32(%rsp),%rsp
	popq	%rbx
.Lc516:
	ret
.Lc512:
.Le38:
	.size	NEXTPAS.CORE.COLLECTIONS.BASE$_$TGOLDENRATIOGROWSTRATEGY_$__$$_DOCALC$QWORD$$QWORD, .Le38 - NEXTPAS.CORE.COLLECTIONS.BASE$_$TGOLDENRATIOGROWSTRATEGY_$__$$_DOCALC$QWORD$$QWORD

.section .text.n_nextpas.core.collections.base$_$tgoldenratiogrowstrategy_$__$$_$destroy,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TGOLDENRATIOGROWSTRATEGY_$__$$_$destroy
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TGOLDENRATIOGROWSTRATEGY_$__$$_$destroy,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TGOLDENRATIOGROWSTRATEGY_$__$$_$destroy:
.Lc518:
# [2607] begin
	pushq	%rax
.Lc519:
# [2608] if FGlobal <> nil then
	cmpq	$0,U_$NEXTPAS.CORE.COLLECTIONS.BASE_$$__static_tgoldenratiogrowstrategy_FGLOBAL
	je	.Lj1081
# [2610] FGlobal.Free;
	movq	U_$NEXTPAS.CORE.COLLECTIONS.BASE_$$__static_tgoldenratiogrowstrategy_FGLOBAL,%rdi
	call	SYSTEM$_$TOBJECT_$__$$_FREE
# [2611] FGlobal := nil;
	movq	$0,U_$NEXTPAS.CORE.COLLECTIONS.BASE_$$__static_tgoldenratiogrowstrategy_FGLOBAL
.Lj1081:
# [2613] end;
	popq	%rcx
.Lc520:
	ret
.Lc517:
.Le39:
	.size	NEXTPAS.CORE.COLLECTIONS.BASE$_$TGOLDENRATIOGROWSTRATEGY_$__$$_$destroy, .Le39 - NEXTPAS.CORE.COLLECTIONS.BASE$_$TGOLDENRATIOGROWSTRATEGY_$__$$_$destroy

.section .text.n_nextpas.core.collections.base$_$tgoldenratiogrowstrategy_$__$$_getglobal$$tgoldenratiogrowstrategy,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TGOLDENRATIOGROWSTRATEGY_$__$$_GETGLOBAL$$TGOLDENRATIOGROWSTRATEGY
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TGOLDENRATIOGROWSTRATEGY_$__$$_GETGLOBAL$$TGOLDENRATIOGROWSTRATEGY,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TGOLDENRATIOGROWSTRATEGY_$__$$_GETGLOBAL$$TGOLDENRATIOGROWSTRATEGY:
.Lc522:
# [2616] begin
	pushq	%rax
.Lc523:
# [2617] Result := TGoldenRatioGrowStrategy.Create;
	movq	$VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY,%rdi
	movl	$1,%esi
	call	SYSTEM$_$TOBJECT_$__$$_CREATE$$TOBJECT
# Var $result located in register rax
# [2618] end;
	popq	%rcx
.Lc524:
	ret
.Lc521:

.section .text.n_nextpas.core.collections.base$_$talignedwrapperstrategy_$__$$_getgrowstrategy$$igrowthstrategy,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TALIGNEDWRAPPERSTRATEGY_$__$$_GETGROWSTRATEGY$$IGROWTHSTRATEGY
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TALIGNEDWRAPPERSTRATEGY_$__$$_GETGROWSTRATEGY$$IGROWTHSTRATEGY,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TALIGNEDWRAPPERSTRATEGY_$__$$_GETGROWSTRATEGY$$IGROWTHSTRATEGY:
.Lc526:
# [2621] begin
	pushq	%rax
.Lc527:
	movq	%rdi,%rax
# Var $self located in register rax
	movq	%rsi,%rdi
# Var $result located in register rdi
# [2622] Result := FGrowStrategy;
	movq	40(%rax),%rsi
	call	fpc_intf_assign
# [2623] end;
	popq	%rcx
.Lc528:
	ret
.Lc525:

.section .text.n_nextpas.core.collections.base$_$talignedwrapperstrategy_$__$$_getalignsize$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TALIGNEDWRAPPERSTRATEGY_$__$$_GETALIGNSIZE$$QWORD
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TALIGNEDWRAPPERSTRATEGY_$__$$_GETALIGNSIZE$$QWORD,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TALIGNEDWRAPPERSTRATEGY_$__$$_GETALIGNSIZE$$QWORD:
.Lc530:
# Var $self located in register rdi
# [2626] begin
# Var $result located in register rax
# [2627] Result := FAlignSize;
	movq	48(%rdi),%rax
.Lc531:
# [2628] end;
	ret
.Lc529:

.section .text.n_nextpas.core.collections.base$_$talignedwrapperstrategy_$__$$_create$h9xta0ywygbd,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TALIGNEDWRAPPERSTRATEGY_$__$$_CREATE$h9Xta0YWYGBD
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TALIGNEDWRAPPERSTRATEGY_$__$$_CREATE$h9Xta0YWYGBD,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TALIGNEDWRAPPERSTRATEGY_$__$$_CREATE$h9Xta0YWYGBD:
.Lc533:
# Temps allocated between rbp-228 and rbp-40
# [2631] begin
	pushq	%rbp
.Lc534:
	movq	%rsp,%rbp
.Lc535:
	leaq	-240(%rsp),%rsp
# Var aGrowStrategy located at rbp-8, size=OS_64
# Var aAlignSize located at rbp-16, size=OS_64
# Var $vmt located at rbp-24, size=OS_64
# Var $self located at rbp-32, size=OS_64
# Var $vmt_afterconstruction_local located at rbp-40, size=OS_S64
	movq	%rdi,-32(%rbp)
	movq	%rsi,-24(%rbp)
	movq	%rdx,-8(%rbp)
	movq	%rcx,-16(%rbp)
	cmpq	$1,-24(%rbp)
	jne	.Lj1091
	movq	-32(%rbp),%rdi
	movq	%rdi,%rax
	call	*104(%rdi)
	movq	%rax,-32(%rbp)
.Lj1091:
	cmpq	$0,-32(%rbp)
	je	.Lj1088
	leaq	-64(%rbp),%rdx
	leaq	-128(%rbp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,-132(%rbp)
	testl	%eax,%eax
	jne	.Lj1098
	movq	$-1,-40(%rbp)
# [2632] inherited Create;
	xorl	%esi,%esi
	movq	-32(%rbp),%rdi
	call	SYSTEM$_$TOBJECT_$__$$_CREATE$$TOBJECT
# [2634] if (aGrowStrategy = nil) then
	cmpq	$0,-8(%rbp)
	jne	.Lj1100
.Lj1101:
# [2635] raise EArgumentNil.Create('TAlignedWrapperStrategy.Create: aGrowStrategy is nil');
	movq	$.Ld36,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj1101,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj1100:
# [2637] if (aAlignSize = 0) then
	cmpq	$0,-16(%rbp)
	jne	.Lj1103
.Lj1104:
# [2638] raise EInvalidArgument.Create('TAlignedWrapperStrategy.Create: aAlignSize is 0');
	movq	$.Ld37,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj1104,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj1103:
# [2640] if ((aAlignSize and (aAlignSize - 1)) <> 0) then
	movq	-16(%rbp),%rax
	subq	$1,%rax
	andq	-16(%rbp),%rax
	je	.Lj1106
.Lj1107:
# [2641] raise EInvalidArgument.Create('TAlignedWrapperStrategy.Create: aAlignSize must be power of two');
	movq	$.Ld38,%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj1107,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj1106:
# [2643] FGrowStrategy := aGrowStrategy;
	movq	-32(%rbp),%rax
	leaq	40(%rax),%rdi
	movq	-8(%rbp),%rsi
	call	fpc_intf_assign
# [2644] FAlignSize    := aAlignSize;
	movq	-32(%rbp),%rdx
	movq	-16(%rbp),%rax
	movq	%rax,48(%rdx)
# [2645] end;
	movq	$1,-40(%rbp)
	cmpq	$0,-32(%rbp)
	setneb	%al
	cmpq	$0,-24(%rbp)
	setneb	%dl
	andb	%dl,%al
	je	.Lj1109
	movq	-32(%rbp),%rdi
	movq	(%rdi),%rax
	call	*136(%rax)
.Lj1109:
.Lj1098:
	call	fpc_popaddrstack
	cmpl	$0,-132(%rbp)
	je	.Lj1096
	leaq	-160(%rbp),%rdx
	leaq	-224(%rbp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,-228(%rbp)
	testl	%eax,%eax
	jne	.Lj1110
	cmpq	$0,-24(%rbp)
	je	.Lj1112
	movq	-40(%rbp),%rsi
	movq	-32(%rbp),%rdi
	movq	(%rdi),%rax
	call	*96(%rax)
.Lj1112:
	call	fpc_popaddrstack
	call	fpc_reraise
.Lj1110:
	call	fpc_popaddrstack
	cmpl	$0,-228(%rbp)
	je	.Lj1113
	call	fpc_raise_nested
.Lj1113:
	call	fpc_doneexception
.Lj1096:
.Lj1088:
	movq	-32(%rbp),%rax
.Lc536:
	movq	%rbp,%rsp
.Lc537:
	popq	%rbp
	ret
.Lc532:

.section .text.n_nextpas.core.collections.base$_$talignedwrapperstrategy_$__$$_dogetgrowsize$qword$qword$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TALIGNEDWRAPPERSTRATEGY_$__$$_DOGETGROWSIZE$QWORD$QWORD$$QWORD
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TALIGNEDWRAPPERSTRATEGY_$__$$_DOGETGROWSIZE$QWORD$QWORD$$QWORD,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TALIGNEDWRAPPERSTRATEGY_$__$$_DOGETGROWSIZE$QWORD$QWORD$$QWORD:
.Lc539:
# [2648] begin
	pushq	%rbx
.Lc540:
	movq	%rdi,%rbx
# Var $self located in register rbx
# Var aCurrentSize located in register rsi
# Var aRequiredSize located in register rdx
# [2649] Result := FGrowStrategy.GetGrowSize(aCurrentSize, aRequiredSize);
	movq	40(%rdi),%rdi
# Var aRequiredSize located in register rdx
# Var aCurrentSize located in register rsi
	movq	(%rdi),%rax
	call	*24(%rax)
# Var $result located in register rax
	movq	48(%rbx),%rcx
# [2650] Result := ((Result + FAlignSize - 1) div FAlignSize) * FAlignSize;
	subq	$1,%rax
	addq	%rcx,%rax
	xorl	%edx,%edx
	divq	%rcx
	imulq	%rcx,%rax
# Var $result located in register rax
# [2651] end;
	popq	%rbx
.Lc541:
	ret
.Lc538:
.Le40:
	.size	NEXTPAS.CORE.COLLECTIONS.BASE$_$TALIGNEDWRAPPERSTRATEGY_$__$$_DOGETGROWSIZE$QWORD$QWORD$$QWORD, .Le40 - NEXTPAS.CORE.COLLECTIONS.BASE$_$TALIGNEDWRAPPERSTRATEGY_$__$$_DOGETGROWSIZE$QWORD$QWORD$$QWORD

.section .text.n_nextpas.core.collections.base$_$texactgrowstrategy_$__$$_$destroy,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TEXACTGROWSTRATEGY_$__$$_$destroy
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TEXACTGROWSTRATEGY_$__$$_$destroy,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TEXACTGROWSTRATEGY_$__$$_$destroy:
.Lc543:
# [2654] begin
	pushq	%rax
.Lc544:
# [2655] if FGlobal <> nil then
	cmpq	$0,U_$NEXTPAS.CORE.COLLECTIONS.BASE_$$__static_texactgrowstrategy_FGLOBAL
	je	.Lj1119
# [2657] FGlobal.Free;
	movq	U_$NEXTPAS.CORE.COLLECTIONS.BASE_$$__static_texactgrowstrategy_FGLOBAL,%rdi
	call	SYSTEM$_$TOBJECT_$__$$_FREE
# [2658] FGlobal := nil;
	movq	$0,U_$NEXTPAS.CORE.COLLECTIONS.BASE_$$__static_texactgrowstrategy_FGLOBAL
.Lj1119:
# [2660] end;
	popq	%rcx
.Lc545:
	ret
.Lc542:
.Le41:
	.size	NEXTPAS.CORE.COLLECTIONS.BASE$_$TEXACTGROWSTRATEGY_$__$$_$destroy, .Le41 - NEXTPAS.CORE.COLLECTIONS.BASE$_$TEXACTGROWSTRATEGY_$__$$_$destroy

.section .text.n_nextpas.core.collections.base$_$texactgrowstrategy_$__$$_getglobal$$texactgrowstrategy,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TEXACTGROWSTRATEGY_$__$$_GETGLOBAL$$TEXACTGROWSTRATEGY
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TEXACTGROWSTRATEGY_$__$$_GETGLOBAL$$TEXACTGROWSTRATEGY,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TEXACTGROWSTRATEGY_$__$$_GETGLOBAL$$TEXACTGROWSTRATEGY:
.Lc547:
# [2663] begin
	pushq	%rax
.Lc548:
# [2664] Result := TExactGrowStrategy.Create;
	movq	$VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY,%rdi
	movl	$1,%esi
	call	SYSTEM$_$TOBJECT_$__$$_CREATE$$TOBJECT
# Var $result located in register rax
# [2665] end;
	popq	%rcx
.Lc549:
	ret
.Lc546:

.section .text.n_nextpas.core.collections.base$_$texactgrowstrategy_$__$$_dogetgrowsize$qword$qword$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TEXACTGROWSTRATEGY_$__$$_DOGETGROWSIZE$QWORD$QWORD$$QWORD
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TEXACTGROWSTRATEGY_$__$$_DOGETGROWSIZE$QWORD$QWORD$$QWORD,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TEXACTGROWSTRATEGY_$__$$_DOGETGROWSIZE$QWORD$QWORD$$QWORD:
.Lc551:
# Var $self located in register rdi
# Var aCurrentSize located in register rsi
# [2668] begin
	movq	%rdx,%rax
# Var aRequiredSize located in register rax
# Var $result located in register rax
# Var aRequiredSize located in register rax
.Lc552:
# [2671] end;
	ret
.Lc550:
.Le42:
	.size	NEXTPAS.CORE.COLLECTIONS.BASE$_$TEXACTGROWSTRATEGY_$__$$_DOGETGROWSIZE$QWORD$QWORD$$QWORD, .Le42 - NEXTPAS.CORE.COLLECTIONS.BASE$_$TEXACTGROWSTRATEGY_$__$$_DOGETGROWSIZE$QWORD$QWORD$$QWORD

.section .text.n_WRPR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY_$_NEXTPAS.CORE.COLLECTIONS.BASE_$$$Hf_EWlOkz_JM,"ax"
	.balign 16,0x90
.globl	WRPR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY_$_NEXTPAS.CORE.COLLECTIONS.BASE_$$$Hf_EWlOkz_JM
	.type	WRPR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY_$_NEXTPAS.CORE.COLLECTIONS.BASE_$$$Hf_EWlOkz_JM,@function
WRPR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY_$_NEXTPAS.CORE.COLLECTIONS.BASE_$$$Hf_EWlOkz_JM:
# [1] unit nextpas.core.collections.base;
	subq	$32,%rdi
	jmp	SYSTEM$_$TINTERFACEDOBJECT_$__$$_QUERYINTERFACE$TGUID$formal$$LONGINT
.Le43:
	.size	WRPR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY_$_NEXTPAS.CORE.COLLECTIONS.BASE_$$$Hf_EWlOkz_JM, .Le43 - WRPR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY_$_NEXTPAS.CORE.COLLECTIONS.BASE_$$$Hf_EWlOkz_JM

.section .text.n_WRPR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY_$_NEXTPAS.CORE.COLLECTIONS.BASE_$$$Hkc2bL$g9buB,"ax"
	.balign 16,0x90
.globl	WRPR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY_$_NEXTPAS.CORE.COLLECTIONS.BASE_$$$Hkc2bL$g9buB
	.type	WRPR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY_$_NEXTPAS.CORE.COLLECTIONS.BASE_$$$Hkc2bL$g9buB,@function
WRPR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY_$_NEXTPAS.CORE.COLLECTIONS.BASE_$$$Hkc2bL$g9buB:
	subq	$32,%rdi
	jmp	SYSTEM$_$TINTERFACEDOBJECT_$__$$__ADDREF$$LONGINT
.Le44:
	.size	WRPR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY_$_NEXTPAS.CORE.COLLECTIONS.BASE_$$$Hkc2bL$g9buB, .Le44 - WRPR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY_$_NEXTPAS.CORE.COLLECTIONS.BASE_$$$Hkc2bL$g9buB

.section .text.n_WRPR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY_$_NEXTPAS.CORE.COLLECTIONS.BASE_$$$H6XRYy8vkiSE,"ax"
	.balign 16,0x90
.globl	WRPR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY_$_NEXTPAS.CORE.COLLECTIONS.BASE_$$$H6XRYy8vkiSE
	.type	WRPR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY_$_NEXTPAS.CORE.COLLECTIONS.BASE_$$$H6XRYy8vkiSE,@function
WRPR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY_$_NEXTPAS.CORE.COLLECTIONS.BASE_$$$H6XRYy8vkiSE:
	subq	$32,%rdi
	jmp	SYSTEM$_$TINTERFACEDOBJECT_$__$$__RELEASE$$LONGINT
.Le45:
	.size	WRPR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY_$_NEXTPAS.CORE.COLLECTIONS.BASE_$$$H6XRYy8vkiSE, .Le45 - WRPR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY_$_NEXTPAS.CORE.COLLECTIONS.BASE_$$$H6XRYy8vkiSE

.section .text.n_WRPR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY_$_NEXTPAS.CORE.COLLECTIONS.BASE_$$$HKkngccTzsNB,"ax"
	.balign 16,0x90
.globl	WRPR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY_$_NEXTPAS.CORE.COLLECTIONS.BASE_$$$HKkngccTzsNB
	.type	WRPR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY_$_NEXTPAS.CORE.COLLECTIONS.BASE_$$$HKkngccTzsNB,@function
WRPR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY_$_NEXTPAS.CORE.COLLECTIONS.BASE_$$$HKkngccTzsNB:
# [2393] function TGrowthStrategy.GetGrowSize(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt;
	subq	$32,%rdi
	movq	(%rdi),%rax
	jmp	*208(%rax)
.Le46:
	.size	WRPR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY_$_NEXTPAS.CORE.COLLECTIONS.BASE_$$$HKkngccTzsNB, .Le46 - WRPR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY_$_NEXTPAS.CORE.COLLECTIONS.BASE_$$$HKkngccTzsNB

.section .text.n_nextpas.core.collections.base$_$tcollection_$__$$_isoverlap$pointer$qword$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_ISOVERLAP$POINTER$QWORD$$BOOLEAN
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_ISOVERLAP$POINTER$QWORD$$BOOLEAN,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_ISOVERLAP$POINTER$QWORD$$BOOLEAN:
.Lc554:
	pushq	%rax
.Lc555:
# Var $self located in register rdi
# Var aSrc located in register rsi
# Var aElementCount located in register rdx
	call	FPC_ABSTRACTERROR
	popq	%rcx
.Lc556:
	ret
.Lc553:

.section .text.n_nextpas.core.collections.base$_$tcollection_$__$$_ptriter$$tptriter,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_PTRITER$$TPTRITER
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_PTRITER$$TPTRITER,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_PTRITER$$TPTRITER:
.Lc558:
	pushq	%rax
.Lc559:
# Var $self located in register rdi
# Var $result located in register rsi
	call	FPC_ABSTRACTERROR
	popq	%rcx
.Lc560:
	ret
.Lc557:

.section .text.n_nextpas.core.collections.base$_$tcollection_$__$$_getcount$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_GETCOUNT$$QWORD
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_GETCOUNT$$QWORD,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_GETCOUNT$$QWORD:
.Lc562:
	pushq	%rax
.Lc563:
# Var $self located in register rdi
	call	FPC_ABSTRACTERROR
	popq	%rcx
.Lc564:
	ret
.Lc561:

.section .text.n_nextpas.core.collections.base$_$tcollection_$__$$_clear,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CLEAR
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CLEAR,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CLEAR:
.Lc566:
	pushq	%rax
.Lc567:
# Var $self located in register rdi
	call	FPC_ABSTRACTERROR
	popq	%rcx
.Lc568:
	ret
.Lc565:

.section .text.n_nextpas.core.collections.base$_$tcollection_$__$$_serializetoarraybuffer$pointer$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_SERIALIZETOARRAYBUFFER$POINTER$QWORD
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_SERIALIZETOARRAYBUFFER$POINTER$QWORD,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_SERIALIZETOARRAYBUFFER$POINTER$QWORD:
.Lc570:
	pushq	%rax
.Lc571:
# Var $self located in register rdi
# Var aDst located in register rsi
# Var aCount located in register rdx
	call	FPC_ABSTRACTERROR
	popq	%rcx
.Lc572:
	ret
.Lc569:

.section .text.n_nextpas.core.collections.base$_$tcollection_$__$$_appendunchecked$pointer$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_APPENDUNCHECKED$POINTER$QWORD
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_APPENDUNCHECKED$POINTER$QWORD,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_APPENDUNCHECKED$POINTER$QWORD:
.Lc574:
	pushq	%rax
.Lc575:
# Var $self located in register rdi
# Var aSrc located in register rsi
# Var aElementCount located in register rdx
	call	FPC_ABSTRACTERROR
	popq	%rcx
.Lc576:
	ret
.Lc573:

.section .text.n_nextpas.core.collections.base$_$tcollection_$__$$_appendtounchecked$tcollection,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_APPENDTOUNCHECKED$TCOLLECTION
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_APPENDTOUNCHECKED$TCOLLECTION,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_APPENDTOUNCHECKED$TCOLLECTION:
.Lc578:
	pushq	%rax
.Lc579:
# Var $self located in register rdi
# Var aDst located in register rsi
	call	FPC_ABSTRACTERROR
	popq	%rcx
.Lc580:
	ret
.Lc577:

.section .text.n_nextpas.core.collections.base$_$tgrowthstrategy_$__$$_dogetgrowsize$qword$qword$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TGROWTHSTRATEGY_$__$$_DOGETGROWSIZE$QWORD$QWORD$$QWORD
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TGROWTHSTRATEGY_$__$$_DOGETGROWSIZE$QWORD$QWORD$$QWORD,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TGROWTHSTRATEGY_$__$$_DOGETGROWSIZE$QWORD$QWORD$$QWORD:
.Lc582:
	pushq	%rax
.Lc583:
# Var $self located in register rdi
# Var aCurrentSize located in register rsi
# Var aRequiredSize located in register rdx
	call	FPC_ABSTRACTERROR
	popq	%rcx
.Lc584:
	ret
.Lc581:

.section .text.n_nextpas.core.collections.base$_$tcalcgrowstrategy_$__$$_docalc$qword$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCALCGROWSTRATEGY_$__$$_DOCALC$QWORD$$QWORD
	.type	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCALCGROWSTRATEGY_$__$$_DOCALC$QWORD$$QWORD,@function
NEXTPAS.CORE.COLLECTIONS.BASE$_$TCALCGROWSTRATEGY_$__$$_DOCALC$QWORD$$QWORD:
.Lc586:
	pushq	%rax
.Lc587:
# Var $self located in register rdi
# Var aCurrentSize located in register rsi
	call	FPC_ABSTRACTERROR
	popq	%rcx
.Lc588:
	ret
.Lc585:

.section .text.n_nextpas.core.collections.base_$$_init_implicit$,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_init_implicit$
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_init_implicit$,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_init_implicit$:
.globl	INIT$_$NEXTPAS.CORE.COLLECTIONS.BASE
	.type	INIT$_$NEXTPAS.CORE.COLLECTIONS.BASE,@function
INIT$_$NEXTPAS.CORE.COLLECTIONS.BASE:
.Lc590:
	pushq	%rax
.Lc591:
	popq	%rcx
.Lc592:
	ret
.Lc589:

.section .text.n_nextpas.core.collections.base_$$_finalize_implicit$,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.COLLECTIONS.BASE_$$_finalize_implicit$
	.type	NEXTPAS.CORE.COLLECTIONS.BASE_$$_finalize_implicit$,@function
NEXTPAS.CORE.COLLECTIONS.BASE_$$_finalize_implicit$:
.globl	FINALIZE$_$NEXTPAS.CORE.COLLECTIONS.BASE
	.type	FINALIZE$_$NEXTPAS.CORE.COLLECTIONS.BASE,@function
FINALIZE$_$NEXTPAS.CORE.COLLECTIONS.BASE:
.Lc594:
	pushq	%rax
.Lc595:
	call	NEXTPAS.CORE.COLLECTIONS.BASE$_$TDOUBLINGGROWSTRATEGY_$__$$_$destroy
	call	NEXTPAS.CORE.COLLECTIONS.BASE$_$TPOWEROFTWOGROWSTRATEGY_$__$$_$destroy
	call	NEXTPAS.CORE.COLLECTIONS.BASE$_$TGOLDENRATIOGROWSTRATEGY_$__$$_$destroy
	call	NEXTPAS.CORE.COLLECTIONS.BASE$_$TEXACTGROWSTRATEGY_$__$$_$destroy
	popq	%rcx
.Lc596:
	ret
.Lc593:
# End asmlist al_procedures
# Begin asmlist al_globals

.section .bss,"aw",%nobits
	.balign 8
# [nextpas.core.collections.base.pas]
# [488] class destructor Destroy;
	.globl U_$NEXTPAS.CORE.COLLECTIONS.BASE_$$__static_tdoublinggrowstrategy_FGLOBAL
	.type U_$NEXTPAS.CORE.COLLECTIONS.BASE_$$__static_tdoublinggrowstrategy_FGLOBAL,@object
	.size U_$NEXTPAS.CORE.COLLECTIONS.BASE_$$__static_tdoublinggrowstrategy_FGLOBAL,8
U_$NEXTPAS.CORE.COLLECTIONS.BASE_$$__static_tdoublinggrowstrategy_FGLOBAL:
	.zero 8

.section .bss,"aw",%nobits
	.balign 8
# [521] class destructor Destroy;
	.globl U_$NEXTPAS.CORE.COLLECTIONS.BASE_$$__static_tpoweroftwogrowstrategy_FGLOBAL
	.type U_$NEXTPAS.CORE.COLLECTIONS.BASE_$$__static_tpoweroftwogrowstrategy_FGLOBAL,@object
	.size U_$NEXTPAS.CORE.COLLECTIONS.BASE_$$__static_tpoweroftwogrowstrategy_FGLOBAL,8
U_$NEXTPAS.CORE.COLLECTIONS.BASE_$$__static_tpoweroftwogrowstrategy_FGLOBAL:
	.zero 8

.section .bss,"aw",%nobits
	.balign 8
# [534] class destructor Destroy;
	.globl U_$NEXTPAS.CORE.COLLECTIONS.BASE_$$__static_tgoldenratiogrowstrategy_FGLOBAL
	.type U_$NEXTPAS.CORE.COLLECTIONS.BASE_$$__static_tgoldenratiogrowstrategy_FGLOBAL,@object
	.size U_$NEXTPAS.CORE.COLLECTIONS.BASE_$$__static_tgoldenratiogrowstrategy_FGLOBAL,8
U_$NEXTPAS.CORE.COLLECTIONS.BASE_$$__static_tgoldenratiogrowstrategy_FGLOBAL:
	.zero 8

.section .bss,"aw",%nobits
	.balign 8
# [560] class destructor Destroy;
	.globl U_$NEXTPAS.CORE.COLLECTIONS.BASE_$$__static_texactgrowstrategy_FGLOBAL
	.type U_$NEXTPAS.CORE.COLLECTIONS.BASE_$$__static_texactgrowstrategy_FGLOBAL,@object
	.size U_$NEXTPAS.CORE.COLLECTIONS.BASE_$$__static_texactgrowstrategy_FGLOBAL,8
U_$NEXTPAS.CORE.COLLECTIONS.BASE_$$__static_texactgrowstrategy_FGLOBAL:
	.zero 8

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION
	.balign 8
.globl	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION
	.type	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION,@object
VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION:
	.quad	48,-48
	.quad	VMT_$SYSTEM_$$_TINTERFACEDOBJECT$indirect
	.quad	.Ld39
	.quad	0,0,0
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION
	.quad	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION
	.quad	0
	.quad	.Ld40
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
	.quad	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CREATE$IALLOCATOR$POINTER$$TCOLLECTION
	.quad	FPC_ABSTRACTERROR
	.quad	FPC_ABSTRACTERROR
	.quad	FPC_ABSTRACTERROR
	.quad	FPC_ABSTRACTERROR
	.quad	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_CLONE$$TCOLLECTION
	.quad	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_ISCOMPATIBLE$TCOLLECTION$$BOOLEAN
	.quad	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_LOADFROM$POINTER$QWORD
	.quad	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_LOADFROMUNCHECKED$POINTER$QWORD
	.quad	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_TRYLOADFROM$POINTER$QWORD$$BOOLEAN
	.quad	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_APPEND$POINTER$QWORD
	.quad	FPC_ABSTRACTERROR
	.quad	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_TRYAPPEND$POINTER$QWORD$$BOOLEAN
	.quad	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_LOADFROMUNCHECKED$TCOLLECTION
	.quad	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_APPENDUNCHECKED$TCOLLECTION
	.quad	FPC_ABSTRACTERROR
	.quad	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCOLLECTION_$__$$_SAVETOUNCHECKED$TCOLLECTION
	.quad	0
# [2673] end.
.Le47:
	.size	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION, .Le47 - VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION

.section .rodata.n_IID_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORREFFUNC
	.balign 8
.globl	IID_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORREFFUNC
	.type	IID_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORREFFUNC,@object
IID_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORREFFUNC:
	.long	0
	.short	0,0
	.byte	0,0,0,0,0,0,0,0
.Le48:
	.size	IID_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORREFFUNC, .Le48 - IID_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORREFFUNC

.section .rodata.n_IIDSTR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORREFFUNC
	.balign 8
.globl	IIDSTR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORREFFUNC
	.type	IIDSTR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORREFFUNC,@object
IIDSTR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORREFFUNC:
	.byte	0
.Le49:
	.size	IIDSTR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORREFFUNC, .Le49 - IIDSTR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORREFFUNC

.section .rodata.n_IID_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_IGROWTHSTRATEGY
	.balign 8
.globl	IID_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_IGROWTHSTRATEGY
	.type	IID_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_IGROWTHSTRATEGY,@object
IID_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_IGROWTHSTRATEGY:
	.long	-56969188
	.short	47005,16988
	.byte	164,83,33,55,195,89,207,131
.Le50:
	.size	IID_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_IGROWTHSTRATEGY, .Le50 - IID_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_IGROWTHSTRATEGY

.section .rodata.n_IIDSTR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_IGROWTHSTRATEGY
	.balign 8
.globl	IIDSTR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_IGROWTHSTRATEGY
	.type	IIDSTR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_IGROWTHSTRATEGY,@object
IIDSTR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_IGROWTHSTRATEGY:
	.byte	38
	.ascii	"{FC9AB81C-B79D-425C-A453-2137C359CF83}"
.Le51:
	.size	IIDSTR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_IGROWTHSTRATEGY, .Le51 - IIDSTR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_IGROWTHSTRATEGY

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY
	.balign 8
.globl	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY
	.type	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY,@object
VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY:
	.quad	40,-40
	.quad	VMT_$SYSTEM_$$_TINTERFACEDOBJECT$indirect
	.quad	.Ld41
	.quad	0,0,0
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY
	.quad	0,0
	.quad	.Ld43
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
	.quad	NEXTPAS.CORE.COLLECTIONS.BASE$_$TGROWTHSTRATEGY_$__$$_GETGROWSIZE$QWORD$QWORD$$QWORD
	.quad	0
.Le52:
	.size	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY, .Le52 - VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY

.section .rodata.n_IID_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWREFFUNC
	.balign 8
.globl	IID_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWREFFUNC
	.type	IID_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWREFFUNC,@object
IID_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWREFFUNC:
	.long	0
	.short	0,0
	.byte	0,0,0,0,0,0,0,0
.Le53:
	.size	IID_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWREFFUNC, .Le53 - IID_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWREFFUNC

.section .rodata.n_IIDSTR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWREFFUNC
	.balign 8
.globl	IIDSTR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWREFFUNC
	.type	IIDSTR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWREFFUNC,@object
IIDSTR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWREFFUNC:
	.byte	0
.Le54:
	.size	IIDSTR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWREFFUNC, .Le54 - IIDSTR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWREFFUNC

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY
	.balign 8
.globl	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY
	.type	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY,@object
VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY:
	.quad	96,-96
	.quad	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY$indirect
	.quad	.Ld44
	.quad	0,0,0
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY
	.quad	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY
	.quad	0
	.quad	.Ld45
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
	.quad	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCUSTOMGROWTHSTRATEGY_$__$$_DOGETGROWSIZE$QWORD$QWORD$$QWORD
	.quad	NEXTPAS.CORE.COLLECTIONS.BASE$_$TGROWTHSTRATEGY_$__$$_GETGROWSIZE$QWORD$QWORD$$QWORD
	.quad	0
.Le55:
	.size	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY, .Le55 - VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY
	.balign 8
.globl	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY
	.type	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY,@object
VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY:
	.quad	40,-40
	.quad	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY$indirect
	.quad	.Ld46
	.quad	0,0,0
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY
	.quad	0,0
	.quad	.Ld47
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
	.quad	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCALCGROWSTRATEGY_$__$$_DOGETGROWSIZE$QWORD$QWORD$$QWORD
	.quad	NEXTPAS.CORE.COLLECTIONS.BASE$_$TGROWTHSTRATEGY_$__$$_GETGROWSIZE$QWORD$QWORD$$QWORD
	.quad	FPC_ABSTRACTERROR
	.quad	0
.Le56:
	.size	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY, .Le56 - VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY
	.balign 8
.globl	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY
	.type	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY,@object
VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY:
	.quad	40,-40
	.quad	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY$indirect
	.quad	.Ld48
	.quad	0,0,0
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY
	.quad	0,0
	.quad	.Ld49
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
	.quad	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCALCGROWSTRATEGY_$__$$_DOGETGROWSIZE$QWORD$QWORD$$QWORD
	.quad	NEXTPAS.CORE.COLLECTIONS.BASE$_$TGROWTHSTRATEGY_$__$$_GETGROWSIZE$QWORD$QWORD$$QWORD
	.quad	NEXTPAS.CORE.COLLECTIONS.BASE$_$TDOUBLINGGROWSTRATEGY_$__$$_DOCALC$QWORD$$QWORD
	.quad	0
.Le57:
	.size	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY, .Le57 - VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY
	.balign 8
.globl	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY
	.type	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY,@object
VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY:
	.quad	48,-48
	.quad	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY$indirect
	.quad	.Ld50
	.quad	0,0,0
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY
	.quad	0,0
	.quad	.Ld51
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
	.quad	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCALCGROWSTRATEGY_$__$$_DOGETGROWSIZE$QWORD$QWORD$$QWORD
	.quad	NEXTPAS.CORE.COLLECTIONS.BASE$_$TGROWTHSTRATEGY_$__$$_GETGROWSIZE$QWORD$QWORD$$QWORD
	.quad	NEXTPAS.CORE.COLLECTIONS.BASE$_$TFIXEDGROWSTRATEGY_$__$$_DOCALC$QWORD$$QWORD
	.quad	0
.Le58:
	.size	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY, .Le58 - VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY
	.balign 8
.globl	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY
	.type	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY,@object
VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY:
	.quad	48,-48
	.quad	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY$indirect
	.quad	.Ld52
	.quad	0,0,0
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY
	.quad	0,0
	.quad	.Ld53
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
	.quad	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCALCGROWSTRATEGY_$__$$_DOGETGROWSIZE$QWORD$QWORD$$QWORD
	.quad	NEXTPAS.CORE.COLLECTIONS.BASE$_$TGROWTHSTRATEGY_$__$$_GETGROWSIZE$QWORD$QWORD$$QWORD
	.quad	NEXTPAS.CORE.COLLECTIONS.BASE$_$TFACTORGROWSTRATEGY_$__$$_DOCALC$QWORD$$QWORD
	.quad	0
.Le59:
	.size	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY, .Le59 - VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY
	.balign 8
.globl	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY
	.type	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY,@object
VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY:
	.quad	40,-40
	.quad	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY$indirect
	.quad	.Ld54
	.quad	0,0,0
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY
	.quad	0,0
	.quad	.Ld55
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
	.quad	NEXTPAS.CORE.COLLECTIONS.BASE$_$TPOWEROFTWOGROWSTRATEGY_$__$$_DOGETGROWSIZE$QWORD$QWORD$$QWORD
	.quad	NEXTPAS.CORE.COLLECTIONS.BASE$_$TGROWTHSTRATEGY_$__$$_GETGROWSIZE$QWORD$QWORD$$QWORD
	.quad	0
.Le60:
	.size	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY, .Le60 - VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY
	.balign 8
.globl	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY
	.type	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY,@object
VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY:
	.quad	40,-40
	.quad	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY$indirect
	.quad	.Ld56
	.quad	0,0,0
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY
	.quad	0,0
	.quad	.Ld57
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
	.quad	NEXTPAS.CORE.COLLECTIONS.BASE$_$TCALCGROWSTRATEGY_$__$$_DOGETGROWSIZE$QWORD$QWORD$$QWORD
	.quad	NEXTPAS.CORE.COLLECTIONS.BASE$_$TGROWTHSTRATEGY_$__$$_GETGROWSIZE$QWORD$QWORD$$QWORD
	.quad	NEXTPAS.CORE.COLLECTIONS.BASE$_$TGOLDENRATIOGROWSTRATEGY_$__$$_DOCALC$QWORD$$QWORD
	.quad	0
.Le61:
	.size	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY, .Le61 - VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY
	.balign 8
.globl	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY
	.type	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY,@object
VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY:
	.quad	56,-56
	.quad	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY$indirect
	.quad	.Ld58
	.quad	0,0,0
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY
	.quad	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY
	.quad	0
	.quad	.Ld59
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
	.quad	NEXTPAS.CORE.COLLECTIONS.BASE$_$TALIGNEDWRAPPERSTRATEGY_$__$$_DOGETGROWSIZE$QWORD$QWORD$$QWORD
	.quad	NEXTPAS.CORE.COLLECTIONS.BASE$_$TGROWTHSTRATEGY_$__$$_GETGROWSIZE$QWORD$QWORD$$QWORD
	.quad	0
.Le62:
	.size	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY, .Le62 - VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY
	.balign 8
.globl	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY
	.type	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY,@object
VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY:
	.quad	40,-40
	.quad	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY$indirect
	.quad	.Ld60
	.quad	0,0,0
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY
	.quad	0,0
	.quad	.Ld61
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
	.quad	NEXTPAS.CORE.COLLECTIONS.BASE$_$TEXACTGROWSTRATEGY_$__$$_DOGETGROWSIZE$QWORD$QWORD$$QWORD
	.quad	NEXTPAS.CORE.COLLECTIONS.BASE$_$TGROWTHSTRATEGY_$__$$_GETGROWSIZE$QWORD$QWORD$$QWORD
	.quad	0
.Le63:
	.size	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY, .Le63 - VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY
# End asmlist al_globals
# Begin asmlist al_const

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION
	.balign 8
.Ld39:
	.byte	11
	.ascii	"TCollection"
.Le64:
	.size	.Ld39, .Le64 - .Ld39

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION
	.balign 8
.Ld40:
	.quad	0
.Le65:
	.size	.Ld40, .Le65 - .Ld40

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY
	.balign 8
.Ld41:
	.byte	15
	.ascii	"TGrowthStrategy"
.Le66:
	.size	.Ld41, .Le66 - .Ld41

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY
	.balign 8
.Ld42:
	.quad	WRPR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY_$_NEXTPAS.CORE.COLLECTIONS.BASE_$$$Hf_EWlOkz_JM
	.quad	WRPR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY_$_NEXTPAS.CORE.COLLECTIONS.BASE_$$$Hkc2bL$g9buB
	.quad	WRPR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY_$_NEXTPAS.CORE.COLLECTIONS.BASE_$$$H6XRYy8vkiSE
	.quad	WRPR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY_$_NEXTPAS.CORE.COLLECTIONS.BASE_$$$HKkngccTzsNB
.Le67:
	.size	.Ld42, .Le67 - .Ld42

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY
	.balign 8
.Ld43:
	.quad	1
	.quad	IID_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_IGROWTHSTRATEGY$indirect
	.quad	.Ld42
	.quad	32
	.quad	IIDSTR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_IGROWTHSTRATEGY$indirect
	.long	0
	.byte	0,0,0,0
.Le68:
	.size	.Ld43, .Le68 - .Ld43

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY
	.balign 8
.Ld44:
	.byte	21
	.ascii	"TCustomGrowthStrategy"
.Le69:
	.size	.Ld44, .Le69 - .Ld44

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY
	.balign 8
.Ld45:
	.quad	0
.Le70:
	.size	.Ld45, .Le70 - .Ld45

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY
	.balign 8
.Ld46:
	.byte	17
	.ascii	"TCalcGrowStrategy"
.Le71:
	.size	.Ld46, .Le71 - .Ld46

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY
	.balign 8
.Ld47:
	.quad	0
.Le72:
	.size	.Ld47, .Le72 - .Ld47

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY
	.balign 8
.Ld48:
	.byte	21
	.ascii	"TDoublingGrowStrategy"
.Le73:
	.size	.Ld48, .Le73 - .Ld48

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY
	.balign 8
.Ld49:
	.quad	0
.Le74:
	.size	.Ld49, .Le74 - .Ld49

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY
	.balign 8
.Ld50:
	.byte	18
	.ascii	"TFixedGrowStrategy"
.Le75:
	.size	.Ld50, .Le75 - .Ld50

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY
	.balign 8
.Ld51:
	.quad	0
.Le76:
	.size	.Ld51, .Le76 - .Ld51

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY
	.balign 8
.Ld52:
	.byte	19
	.ascii	"TFactorGrowStrategy"
.Le77:
	.size	.Ld52, .Le77 - .Ld52

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY
	.balign 8
.Ld53:
	.quad	0
.Le78:
	.size	.Ld53, .Le78 - .Ld53

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY
	.balign 8
.Ld54:
	.byte	23
	.ascii	"TPowerOfTwoGrowStrategy"
.Le79:
	.size	.Ld54, .Le79 - .Ld54

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY
	.balign 8
.Ld55:
	.quad	0
.Le80:
	.size	.Ld55, .Le80 - .Ld55

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY
	.balign 8
.Ld56:
	.byte	24
	.ascii	"TGoldenRatioGrowStrategy"
.Le81:
	.size	.Ld56, .Le81 - .Ld56

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY
	.balign 8
.Ld57:
	.quad	0
.Le82:
	.size	.Ld57, .Le82 - .Ld57

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY
	.balign 8
.Ld58:
	.byte	23
	.ascii	"TAlignedWrapperStrategy"
.Le83:
	.size	.Ld58, .Le83 - .Ld58

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY
	.balign 8
.Ld59:
	.quad	0
.Le84:
	.size	.Ld59, .Le84 - .Ld59

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY
	.balign 8
.Ld60:
	.byte	18
	.ascii	"TExactGrowStrategy"
.Le85:
	.size	.Ld60, .Le85 - .Ld60

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY
	.balign 8
.Ld61:
	.quad	0
.Le86:
	.size	.Ld61, .Le86 - .Ld61
# End asmlist al_const
# Begin asmlist al_typedconsts

.section .rodata.n_.Ld1
	.balign 8
.Ld1$strlab:
	.short	0,1
	.long	-1
	.quad	35
.Ld1:
# [842] raise EOutOfRange.CreateFmt('%s: Index (%u) out of range [0..%u]', [aCallerName, aIndex, aMax - 1]);
	.ascii	"%s: Index (%u) out of range [0..%u]\000"
.Le87:
	.size	.Ld1$strlab, .Le87 - .Ld1$strlab

.section .rodata.n_.Ld2
	.balign 8
.Ld2$strlab:
	.short	0,1
	.long	-1
	.quad	74
.Ld2:
# [850] raise EOutOfRange.CreateFmt('%s:Bounds check failed. Count (%u) exceeds available length from index %u.', [aCallerName, aCount, aMax - aIndex - 1]);
	.ascii	"%s:Bounds check failed. Count (%u) exceeds availabl"
	.ascii	"e length from index %u.\000"
.Le88:
	.size	.Ld2$strlab, .Le88 - .Ld2$strlab

.section .rodata.n_.Ld3
	.balign 8
.Ld3$strlab:
	.short	0,1
	.long	-1
	.quad	44
.Ld3:
# [1030] raise EArgumentNil.Create('TPtrIter.Init: Failed to init: aOwner is nil');
	.ascii	"TPtrIter.Init: Failed to init: aOwner is nil\000"
.Le89:
	.size	.Ld3$strlab, .Le89 - .Ld3$strlab

.section .rodata.n_.Ld4
	.balign 8
.Ld4$strlab:
	.short	0,1
	.long	-1
	.quad	49
.Ld4:
# [1033] raise EArgumentNil.Create('TPtrIter.Init: Failed to init: aGetCurrent is nil');
	.ascii	"TPtrIter.Init: Failed to init: aGetCurrent is nil\000"
.Le90:
	.size	.Ld4$strlab, .Le90 - .Ld4$strlab

.section .rodata.n_.Ld5
	.balign 8
.Ld5$strlab:
	.short	0,1
	.long	-1
	.quad	47
.Ld5:
# [1036] raise EArgumentNil.Create('TPtrIter.Init: Failed to init: aMoveNext is nil');
	.ascii	"TPtrIter.Init: Failed to init: aMoveNext is nil\000"
.Le91:
	.size	.Ld5$strlab, .Le91 - .Ld5$strlab

.section .rodata.n_.Ld6
	.balign 8
.Ld6$strlab:
	.short	0,1
	.long	-1
	.quad	31
.Ld6:
# [1144] raise EArgumentNil.Create('TCollection.Create: aSrc is nil');
	.ascii	"TCollection.Create: aSrc is nil\000"
.Le92:
	.size	.Ld6$strlab, .Le92 - .Ld6$strlab

.section .rodata.n_.Ld7
	.balign 8
.Ld7$strlab:
	.short	0,1
	.long	-1
	.quad	30
.Ld7:
# [1205] raise EArgumentNil.Create('TCollection.Clone: Self is nil');
	.ascii	"TCollection.Clone: Self is nil\000"
.Le93:
	.size	.Ld7$strlab, .Le93 - .Ld7$strlab

.section .rodata.n_.Ld8
	.balign 8
.Ld8$strlab:
	.short	0,1
	.long	-1
	.quad	40
.Ld8:
# [1209] raise EInvalidArgument.Create('TCollection.Clone: Self.ClassType is nil');
	.ascii	"TCollection.Clone: Self.ClassType is nil\000"
.Le94:
	.size	.Ld8$strlab, .Le94 - .Ld8$strlab

.section .rodata.n_.Ld9
	.balign 8
.Ld9$strlab:
	.short	0,1
	.long	-1
	.quad	52
.Ld9:
# [1216] raise EInvalidArgument.CreateFmt('TCollection.Clone: Invalid class type conversion: %s', [E.Message]);
	.ascii	"TCollection.Clone: Invalid class type conversion: %"
	.ascii	"s\000"
.Le95:
	.size	.Ld9$strlab, .Le95 - .Ld9$strlab

.section .rodata.n_.Ld10
	.balign 8
.Ld10$strlab:
	.short	0,1
	.long	-1
	.quad	45
.Ld10:
# [1226] raise EInvalidArgument.CreateFmt('TCollection.Clone: Failed to create clone: %s', [E.Message]);
	.ascii	"TCollection.Clone: Failed to create clone: %s\000"
.Le96:
	.size	.Ld10$strlab, .Le96 - .Ld10$strlab

.section .rodata.n_.Ld11
	.balign 8
.Ld11$strlab:
	.short	0,1
	.long	-1
	.quad	49
.Ld11:
# [1239] raise EArgumentNil.Create('TCollection.LoadFrom: Failed to load: aSrc is nil');
	.ascii	"TCollection.LoadFrom: Failed to load: aSrc is nil\000"
.Le97:
	.size	.Ld11$strlab, .Le97 - .Ld11$strlab

.section .rodata.n_.Ld12
	.balign 8
.Ld12$strlab:
	.short	0,1
	.long	-1
	.quad	74
.Ld12:
# [1242] raise EInvalidArgument.Create('TCollection.LoadFrom: Failed to load: aSrc overlaps with current container');
	.ascii	"TCollection.LoadFrom: Failed to load: aSrc overlaps"
	.ascii	" with current container\000"
.Le98:
	.size	.Ld12$strlab, .Le98 - .Ld12$strlab

.section .rodata.n_.Ld13
	.balign 8
.Ld13$strlab:
	.short	0,1
	.long	-1
	.quad	49
.Ld13:
# [1308] raise EArgumentNil.Create('TCollection.Append: Failed to append: aSrc is nil');
	.ascii	"TCollection.Append: Failed to append: aSrc is nil\000"
.Le99:
	.size	.Ld13$strlab, .Le99 - .Ld13$strlab

.section .rodata.n_.Ld14
	.balign 8
.Ld14$strlab:
	.short	0,1
	.long	-1
	.quad	74
.Ld14:
# [1311] raise EOverflow.Create('TCollection.Append: Failed to append: aElementCount is too large(Overflow)');
	.ascii	"TCollection.Append: Failed to append: aElementCount"
	.ascii	" is too large(Overflow)\000"
.Le100:
	.size	.Ld14$strlab, .Le100 - .Ld14$strlab

.section .rodata.n_.Ld15
	.balign 8
.Ld15$strlab:
	.short	0,1
	.long	-1
	.quad	64
.Ld15:
# [1315] raise EInvalidArgument.Create('TCollection.Append: source memory overlaps with container memory');
	.ascii	"TCollection.Append: source memory overlaps with con"
	.ascii	"tainer memory\000"
.Le101:
	.size	.Ld15$strlab, .Le101 - .Ld15$strlab

.section .rodata.n_.Ld16
	.balign 8
.Ld16$strlab:
	.short	0,1
	.long	-1
	.quad	56
.Ld16:
# [1323] raise EArgumentNil.Create('TCollection.LoadFrom: Failed to load: aCollection is nil');
	.ascii	"TCollection.LoadFrom: Failed to load: aCollection i"
	.ascii	"s nil\000"
.Le102:
	.size	.Ld16$strlab, .Le102 - .Ld16$strlab

.section .rodata.n_.Ld17
	.balign 8
.Ld17$strlab:
	.short	0,1
	.long	-1
	.quad	57
.Ld17:
# [1326] raise EInvalidArgument.Create('TCollection.LoadFrom: Failed to load: aCollection is self');
	.ascii	"TCollection.LoadFrom: Failed to load: aCollection i"
	.ascii	"s self\000"
.Le103:
	.size	.Ld17$strlab, .Le103 - .Ld17$strlab

.section .rodata.n_.Ld18
	.balign 8
.Ld18$strlab:
	.short	0,1
	.long	-1
	.quad	67
.Ld18:
# [1329] raise ENotCompatible.Create('TCollection.LoadFrom: Failed to load: aCollection is not compatible');
	.ascii	"TCollection.LoadFrom: Failed to load: aCollection i"
	.ascii	"s not compatible\000"
.Le104:
	.size	.Ld18$strlab, .Le104 - .Ld18$strlab

.section .rodata.n_.Ld19
	.balign 8
.Ld19$strlab:
	.short	0,1
	.long	-1
	.quad	56
.Ld19:
# [1349] raise EArgumentNil.Create('TCollection.Append: Failed to append: aCollection is nil');
	.ascii	"TCollection.Append: Failed to append: aCollection i"
	.ascii	"s nil\000"
.Le105:
	.size	.Ld19$strlab, .Le105 - .Ld19$strlab

.section .rodata.n_.Ld20
	.balign 8
.Ld20$strlab:
	.short	0,1
	.long	-1
	.quad	57
.Ld20:
# [1352] raise EInvalidArgument.Create('TCollection.Append: Failed to append: aCollection is self');
	.ascii	"TCollection.Append: Failed to append: aCollection i"
	.ascii	"s self\000"
.Le106:
	.size	.Ld20$strlab, .Le106 - .Ld20$strlab

.section .rodata.n_.Ld21
	.balign 8
.Ld21$strlab:
	.short	0,1
	.long	-1
	.quad	67
.Ld21:
# [1355] raise ENotCompatible.Create('TCollection.Append: Failed to append: aCollection is not compatible');
	.ascii	"TCollection.Append: Failed to append: aCollection i"
	.ascii	"s not compatible\000"
.Le107:
	.size	.Ld21$strlab, .Le107 - .Ld21$strlab

.section .rodata.n_.Ld22
	.balign 8
.Ld22$strlab:
	.short	0,1
	.long	-1
	.quad	72
.Ld22:
# [1362] raise EOverflow.Create('TCollection.Append: Failed to append: aCollection is too large(Overflow)');
	.ascii	"TCollection.Append: Failed to append: aCollection i"
	.ascii	"s too large(Overflow)\000"
.Le108:
	.size	.Ld22$strlab, .Le108 - .Ld22$strlab

.section .rodata.n_.Ld23
	.balign 8
.Ld23$strlab:
	.short	0,1
	.long	-1
	.quad	58
.Ld23:
# [1378] raise EArgumentNil.Create('TCollection.AppendTo: Failed to append: aCollection is nil');
	.ascii	"TCollection.AppendTo: Failed to append: aCollection"
	.ascii	" is nil\000"
.Le109:
	.size	.Ld23$strlab, .Le109 - .Ld23$strlab

.section .rodata.n_.Ld24
	.balign 8
.Ld24$strlab:
	.short	0,1
	.long	-1
	.quad	69
.Ld24:
# [1381] raise ENotCompatible.Create('TCollection.AppendTo: Failed to append: aCollection is not compatible');
	.ascii	"TCollection.AppendTo: Failed to append: aCollection"
	.ascii	" is not compatible\000"
.Le110:
	.size	.Ld24$strlab, .Le110 - .Ld24$strlab

.section .rodata.n_.Ld25
	.balign 8
.Ld25$strlab:
	.short	0,1
	.long	-1
	.quad	54
.Ld25:
# [1389] raise EArgumentNil.Create('TCollection.SaveTo: Failed to save: aCollection is nil');
	.ascii	"TCollection.SaveTo: Failed to save: aCollection is "
	.ascii	"nil\000"
.Le111:
	.size	.Ld25$strlab, .Le111 - .Ld25$strlab

.section .rodata.n_.Ld26
	.balign 8
.Ld26$strlab:
	.short	0,1
	.long	-1
	.quad	55
.Ld26:
# [1392] raise EInvalidArgument.Create('TCollection.SaveTo: Failed to save: aCollection is self');
	.ascii	"TCollection.SaveTo: Failed to save: aCollection is "
	.ascii	"self\000"
.Le112:
	.size	.Ld26$strlab, .Le112 - .Ld26$strlab

.section .rodata.n_.Ld27
	.balign 8
.Ld27$strlab:
	.short	0,1
	.long	-1
	.quad	65
.Ld27:
# [1395] raise ENotCompatible.Create('TCollection.SaveTo: Failed to save: aCollection is not compatible');
	.ascii	"TCollection.SaveTo: Failed to save: aCollection is "
	.ascii	"not compatible\000"
.Le113:
	.size	.Ld27$strlab, .Le113 - .Ld27$strlab

.section .rodata.n_.Ld28
	.balign 8
.Ld28$strlab:
	.short	0,1
	.long	-1
	.quad	46
.Ld28:
# [2433] raise EArgumentNil.Create('TCustomGrowthStrategy.Create: aGrowFunc is nil');
	.ascii	"TCustomGrowthStrategy.Create: aGrowFunc is nil\000"
.Le114:
	.size	.Ld28$strlab, .Le114 - .Ld28$strlab

.section .rodata.n_.Ld29
	.balign 8
.Ld29$strlab:
	.short	0,1
	.long	-1
	.quad	48
.Ld29:
# [2446] raise EArgumentNil.Create('TCustomGrowthStrategy.Create: aGrowMethod is nil');
	.ascii	"TCustomGrowthStrategy.Create: aGrowMethod is nil\000"
.Le115:
	.size	.Ld29$strlab, .Le115 - .Ld29$strlab

.section .rodata.n_.Ld30
	.balign 8
.Ld30$strlab:
	.short	0,1
	.long	-1
	.quad	49
.Ld30:
# [2459] raise EArgumentNil.Create('TCustomGrowthStrategy.Create: aGrowRefFunc is nil');
	.ascii	"TCustomGrowthStrategy.Create: aGrowRefFunc is nil\000"
.Le116:
	.size	.Ld30$strlab, .Le116 - .Ld30$strlab

.section .rodata.n_.Ld31
	.balign 8
.Ld31$strlab:
	.short	0,1
	.long	-1
	.quad	42
.Ld31:
# [2517] raise EInvalidArgument.Create('TFixedGrowStrategy.Create: aFixedSize is 0');
	.ascii	"TFixedGrowStrategy.Create: aFixedSize is 0\000"
.Le117:
	.size	.Ld31$strlab, .Le117 - .Ld31$strlab

.section .rodata.n_.Ld32
	.balign 8
.Ld32:
	.long	1602224128

.section .rodata.n_.Ld33
	.balign 4
.Ld33:
# s32bit real value: 0d+9.223372037E+18
	.byte	0,0,0,95
# [2539] if (LProduct > MAX_SAFE_SIZEUINT) or IsInfinite(LProduct) or IsNaN(LProduct) then
.Le118:
	.size	.Ld33, .Le118 - .Ld33

.section .rodata.n_.Ld34
	.balign 8
.Ld34$strlab:
	.short	0,1
	.long	-1
	.quad	40
.Ld34:
# [2554] raise EInvalidArgument.Create('TFactorGrowStrategy.Create: aFactor is 0');
	.ascii	"TFactorGrowStrategy.Create: aFactor is 0\000"
.Le119:
	.size	.Ld34$strlab, .Le119 - .Ld34$strlab

.section .data.n_TC_$NEXTPAS.CORE.COLLECTIONS.BASE$_$TGOLDENRATIOGROWSTRATEGY_$_DOCALC$QWORD$$QWORD_$$_GOLDEN_RATIO
	.balign 4
.globl	TC_$NEXTPAS.CORE.COLLECTIONS.BASE$_$TGOLDENRATIOGROWSTRATEGY_$_DOCALC$QWORD$$QWORD_$$_GOLDEN_RATIO
	.hidden TC_$NEXTPAS.CORE.COLLECTIONS.BASE$_$TGOLDENRATIOGROWSTRATEGY_$_DOCALC$QWORD$$QWORD_$$_GOLDEN_RATIO
	.type	TC_$NEXTPAS.CORE.COLLECTIONS.BASE$_$TGOLDENRATIOGROWSTRATEGY_$_DOCALC$QWORD$$QWORD_$$_GOLDEN_RATIO,@object
TC_$NEXTPAS.CORE.COLLECTIONS.BASE$_$TGOLDENRATIOGROWSTRATEGY_$_DOCALC$QWORD$$QWORD_$$_GOLDEN_RATIO:
# s32bit real value: 0d+1.618034005E+00
	.byte	189,27,207,63
# [2586] MAX_SAFE_SIZEUINT = 9223372036854775807;
.Le120:
	.size	TC_$NEXTPAS.CORE.COLLECTIONS.BASE$_$TGOLDENRATIOGROWSTRATEGY_$_DOCALC$QWORD$$QWORD_$$_GOLDEN_RATIO, .Le120 - TC_$NEXTPAS.CORE.COLLECTIONS.BASE$_$TGOLDENRATIOGROWSTRATEGY_$_DOCALC$QWORD$$QWORD_$$_GOLDEN_RATIO

.section .rodata.n_.Ld35
	.balign 8
.Ld35:
	.long	1602224128

.section .rodata.n_.Ld36
	.balign 8
.Ld36$strlab:
	.short	0,1
	.long	-1
	.quad	52
.Ld36:
# [2635] raise EArgumentNil.Create('TAlignedWrapperStrategy.Create: aGrowStrategy is nil');
	.ascii	"TAlignedWrapperStrategy.Create: aGrowStrategy is ni"
	.ascii	"l\000"
.Le121:
	.size	.Ld36$strlab, .Le121 - .Ld36$strlab

.section .rodata.n_.Ld37
	.balign 8
.Ld37$strlab:
	.short	0,1
	.long	-1
	.quad	47
.Ld37:
# [2638] raise EInvalidArgument.Create('TAlignedWrapperStrategy.Create: aAlignSize is 0');
	.ascii	"TAlignedWrapperStrategy.Create: aAlignSize is 0\000"
.Le122:
	.size	.Ld37$strlab, .Le122 - .Ld37$strlab

.section .rodata.n_.Ld38
	.balign 8
.Ld38$strlab:
	.short	0,1
	.long	-1
	.quad	63
.Ld38:
# [2641] raise EInvalidArgument.Create('TAlignedWrapperStrategy.Create: aAlignSize must be power of two');
	.ascii	"TAlignedWrapperStrategy.Create: aAlignSize must be "
	.ascii	"power of two\000"
.Le123:
	.size	.Ld38$strlab, .Le123 - .Ld38$strlab
# End asmlist al_typedconsts
# Begin asmlist al_rtti

.section .rodata.n_INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION
	.balign 8
.globl	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION
	.type	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION,@object
INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION:
	.byte	15,11
# [2674] 
	.ascii	"TCollection"
	.quad	0,0
	.long	8
	.quad	0,0
	.long	1
	.quad	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_IALLOCATOR$indirect
	.quad	40
.Le124:
	.size	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION, .Le124 - INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION:
	.byte	15,11
	.ascii	"TCollection"
	.quad	0
	.quad	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION
	.quad	RTTI_$SYSTEM_$$_TINTERFACEDOBJECT$indirect
	.short	0
	.byte	29
	.ascii	"nextpas.core.collections.base"
	.short	0,0
.Le125:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION, .Le125 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION

.section .rodata.n_INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPTRITER
	.balign 8
.globl	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPTRITER
	.type	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPTRITER,@object
INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPTRITER:
	.byte	13,8
	.ascii	"TPtrIter"
	.quad	0,0
	.long	72
	.quad	0,0
	.long	0
.Le126:
	.size	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPTRITER, .Le126 - INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPTRITER

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_def00000012
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_def00000012
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_def00000012,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_def00000012:
	.byte	6,24
	.ascii	"TPtrIterGetCurrentMethod"
	.quad	0
	.byte	1,2
	.short	640
	.byte	5
	.ascii	"$self"
	.byte	7
	.ascii	"Pointer"
	.short	0
	.byte	5
	.ascii	"aIter"
	.byte	8
	.ascii	"PPtrIter"
	.byte	7
	.ascii	"Pointer"
	.quad	RTTI_$SYSTEM_$$_POINTER$indirect
	.byte	0
	.quad	RTTI_$SYSTEM_$$_POINTER$indirect
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_PPTRITER$indirect
.Le127:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_def00000012, .Le127 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_def00000012

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_def00000013
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_def00000013
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_def00000013,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_def00000013:
	.byte	6,22
	.ascii	"TPtrIterMoveNextMethod"
	.quad	0
	.byte	1,2
	.short	640
	.byte	5
	.ascii	"$self"
	.byte	7
	.ascii	"Pointer"
	.short	0
	.byte	5
	.ascii	"aIter"
	.byte	8
	.ascii	"PPtrIter"
	.byte	7
	.ascii	"Boolean"
	.quad	RTTI_$SYSTEM_$$_BOOLEAN$indirect
	.byte	0
	.quad	RTTI_$SYSTEM_$$_POINTER$indirect
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_PPTRITER$indirect
.Le128:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_def00000013, .Le128 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_def00000013

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_def00000014
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_def00000014
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_def00000014,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_def00000014:
	.byte	6,22
	.ascii	"TPtrIterMovePrevMethod"
	.quad	0
	.byte	1,2
	.short	640
	.byte	5
	.ascii	"$self"
	.byte	7
	.ascii	"Pointer"
	.short	0
	.byte	5
	.ascii	"aIter"
	.byte	8
	.ascii	"PPtrIter"
	.byte	7
	.ascii	"Boolean"
	.quad	RTTI_$SYSTEM_$$_BOOLEAN$indirect
	.byte	0
	.quad	RTTI_$SYSTEM_$$_POINTER$indirect
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_PPTRITER$indirect
.Le129:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_def00000014, .Le129 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_def00000014

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPTRITER
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPTRITER
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPTRITER,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPTRITER:
	.byte	13,8
	.ascii	"TPtrIter"
	.quad	0
	.quad	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPTRITER
	.long	72,6
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_def00000012$indirect
	.quad	0
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_def00000013$indirect
	.quad	16
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_def00000014$indirect
	.quad	32
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION$indirect
	.quad	48
	.quad	RTTI_$SYSTEM_$$_BOOLEAN$indirect
	.quad	56
	.quad	RTTI_$SYSTEM_$$_POINTER$indirect
	.quad	64
	.short	0,0,0
.Le130:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPTRITER, .Le130 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPTRITER

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_PPTRITER
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_PPTRITER
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_PPTRITER,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_PPTRITER:
	.byte	29,8
	.ascii	"PPtrIter"
	.quad	0
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPTRITER$indirect
.Le131:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_PPTRITER, .Le131 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_PPTRITER

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTIONCLASS
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTIONCLASS
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTIONCLASS,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTIONCLASS:
	.byte	28,16
	.ascii	"TCollectionClass"
	.quad	0
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION$indirect
.Le132:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTIONCLASS, .Le132 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTIONCLASS

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORFUNC
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORFUNC
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORFUNC,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORFUNC:
	.byte	23,20
	.ascii	"TRandomGeneratorFunc"
	.quad	0
	.byte	0,0
	.quad	RTTI_$SYSTEM_$$_INT64$indirect
	.byte	2
	.short	0
	.quad	RTTI_$SYSTEM_$$_INT64$indirect
	.byte	6
	.ascii	"aRange"
	.short	0
	.quad	RTTI_$SYSTEM_$$_POINTER$indirect
	.byte	5
	.ascii	"aData"
.Le133:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORFUNC, .Le133 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORFUNC

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORMETHOD
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORMETHOD
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORMETHOD,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORMETHOD:
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
	.ascii	"aRange"
	.byte	5
	.ascii	"Int64"
	.short	0
	.byte	5
	.ascii	"aData"
	.byte	7
	.ascii	"Pointer"
	.byte	5
	.ascii	"Int64"
	.quad	RTTI_$SYSTEM_$$_INT64$indirect
	.byte	0
	.quad	RTTI_$SYSTEM_$$_POINTER$indirect
	.quad	RTTI_$SYSTEM_$$_INT64$indirect
	.quad	RTTI_$SYSTEM_$$_POINTER$indirect
.Le134:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORMETHOD, .Le134 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORMETHOD

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORREFFUNC
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORREFFUNC
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORREFFUNC,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORREFFUNC:
	.byte	14,23
	.ascii	"TRANDOMGENERATORREFFUNC"
	.quad	0
	.quad	RTTI_$SYSTEM_$$_IUNKNOWN$indirect
	.byte	1
	.long	0
	.short	0,0
	.byte	0,0,0,0,0,0,0,0
	.quad	0
	.byte	29
	.ascii	"nextpas.core.collections.base"
	.short	0,1,65535
.Le135:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORREFFUNC, .Le135 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORREFFUNC

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_IGROWTHSTRATEGY
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_IGROWTHSTRATEGY
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_IGROWTHSTRATEGY,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_IGROWTHSTRATEGY:
	.byte	14,15
	.ascii	"IGrowthStrategy"
	.quad	0
	.quad	RTTI_$SYSTEM_$$_IUNKNOWN$indirect
	.byte	1
	.long	-56969188
	.short	47005,16988
	.byte	164,83,33,55,195,89,207,131
	.quad	0
	.byte	29
	.ascii	"nextpas.core.collections.base"
	.short	0,1,65535
.Le136:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_IGROWTHSTRATEGY, .Le136 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_IGROWTHSTRATEGY

.section .rodata.n_INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY
	.balign 8
.globl	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY
	.type	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY,@object
INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY:
	.byte	15,15
	.ascii	"TGrowthStrategy"
	.quad	0,0
	.long	8
	.quad	0,0
	.long	0
.Le137:
	.size	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY, .Le137 - INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY:
	.byte	15,15
	.ascii	"TGrowthStrategy"
	.quad	0
	.quad	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY
	.quad	RTTI_$SYSTEM_$$_TINTERFACEDOBJECT$indirect
	.short	0
	.byte	29
	.ascii	"nextpas.core.collections.base"
	.short	0,0
.Le138:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY, .Le138 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGYCLASS
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGYCLASS
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGYCLASS,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGYCLASS:
	.byte	28,20
	.ascii	"TGrowthStrategyClass"
	.quad	0
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY$indirect
.Le139:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGYCLASS, .Le139 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGYCLASS

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWFUNC
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWFUNC
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWFUNC,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWFUNC:
	.byte	23,9
	.ascii	"TGrowFunc"
	.quad	0
	.byte	0,0
	.quad	RTTI_$SYSTEM_$$_QWORD$indirect
	.byte	3
	.short	0
	.quad	RTTI_$SYSTEM_$$_QWORD$indirect
	.byte	12
	.ascii	"aCurrentSize"
	.short	0
	.quad	RTTI_$SYSTEM_$$_QWORD$indirect
	.byte	13
	.ascii	"aRequiredSize"
	.short	0
	.quad	RTTI_$SYSTEM_$$_POINTER$indirect
	.byte	5
	.ascii	"aData"
.Le140:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWFUNC, .Le140 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWFUNC

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWMETHOD
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWMETHOD
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWMETHOD,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWMETHOD:
	.byte	6,11
	.ascii	"TGrowMethod"
	.quad	0
	.byte	1,3
	.short	640
	.byte	5
	.ascii	"$self"
	.byte	7
	.ascii	"Pointer"
	.short	0
	.byte	12
	.ascii	"aCurrentSize"
	.byte	5
	.ascii	"QWord"
	.short	0
	.byte	13
	.ascii	"aRequiredSize"
	.byte	5
	.ascii	"QWord"
	.byte	5
	.ascii	"QWord"
	.quad	RTTI_$SYSTEM_$$_QWORD$indirect
	.byte	0
	.quad	RTTI_$SYSTEM_$$_POINTER$indirect
	.quad	RTTI_$SYSTEM_$$_QWORD$indirect
	.quad	RTTI_$SYSTEM_$$_QWORD$indirect
.Le141:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWMETHOD, .Le141 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWMETHOD

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWREFFUNC
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWREFFUNC
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWREFFUNC,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWREFFUNC:
	.byte	14,12
	.ascii	"TGROWREFFUNC"
	.quad	0
	.quad	RTTI_$SYSTEM_$$_IUNKNOWN$indirect
	.byte	1
	.long	0
	.short	0,0
	.byte	0,0,0,0,0,0,0,0
	.quad	0
	.byte	29
	.ascii	"nextpas.core.collections.base"
	.short	0,1,65535
.Le142:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWREFFUNC, .Le142 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWREFFUNC

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWPROXYMETHOD
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWPROXYMETHOD
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWPROXYMETHOD,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWPROXYMETHOD:
	.byte	6,16
	.ascii	"TGrowProxyMethod"
	.quad	0
	.byte	1,3
	.short	640
	.byte	5
	.ascii	"$self"
	.byte	7
	.ascii	"Pointer"
	.short	0
	.byte	12
	.ascii	"aCurrentSize"
	.byte	5
	.ascii	"QWord"
	.short	0
	.byte	13
	.ascii	"aRequiredSize"
	.byte	5
	.ascii	"QWord"
	.byte	5
	.ascii	"QWord"
	.quad	RTTI_$SYSTEM_$$_QWORD$indirect
	.byte	0
	.quad	RTTI_$SYSTEM_$$_POINTER$indirect
	.quad	RTTI_$SYSTEM_$$_QWORD$indirect
	.quad	RTTI_$SYSTEM_$$_QWORD$indirect
.Le143:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWPROXYMETHOD, .Le143 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWPROXYMETHOD

.section .rodata.n_INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY
	.balign 8
.globl	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY
	.type	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY,@object
INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY:
	.byte	15,21
	.ascii	"TCustomGrowthStrategy"
	.quad	0,0
	.long	8
	.quad	0,0
	.long	1
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWREFFUNC$indirect
	.quad	72
.Le144:
	.size	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY, .Le144 - INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY:
	.byte	15,21
	.ascii	"TCustomGrowthStrategy"
	.quad	0
	.quad	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY$indirect
	.short	0
	.byte	29
	.ascii	"nextpas.core.collections.base"
	.short	0,0
.Le145:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY, .Le145 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY

.section .rodata.n_INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY
	.balign 8
.globl	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY
	.type	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY,@object
INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY:
	.byte	15,17
	.ascii	"TCalcGrowStrategy"
	.quad	0,0
	.long	8
	.quad	0,0
	.long	0
.Le146:
	.size	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY, .Le146 - INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY:
	.byte	15,17
	.ascii	"TCalcGrowStrategy"
	.quad	0
	.quad	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY$indirect
	.short	0
	.byte	29
	.ascii	"nextpas.core.collections.base"
	.short	0,0
.Le147:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY, .Le147 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY

.section .rodata.n_INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY
	.balign 8
.globl	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY
	.type	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY,@object
INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY:
	.byte	15,21
	.ascii	"TDoublingGrowStrategy"
	.quad	0,0
	.long	8
	.quad	0,0
	.long	0
.Le148:
	.size	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY, .Le148 - INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY:
	.byte	15,21
	.ascii	"TDoublingGrowStrategy"
	.quad	0
	.quad	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY$indirect
	.short	0
	.byte	29
	.ascii	"nextpas.core.collections.base"
	.short	0,0
.Le149:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY, .Le149 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY

.section .rodata.n_INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY
	.balign 8
.globl	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY
	.type	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY,@object
INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY:
	.byte	15,18
	.ascii	"TFixedGrowStrategy"
	.quad	0,0
	.long	8
	.quad	0,0
	.long	0
.Le150:
	.size	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY, .Le150 - INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY:
	.byte	15,18
	.ascii	"TFixedGrowStrategy"
	.quad	0
	.quad	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY$indirect
	.short	0
	.byte	29
	.ascii	"nextpas.core.collections.base"
	.short	0,0
.Le151:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY, .Le151 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY

.section .rodata.n_INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY
	.balign 8
.globl	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY
	.type	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY,@object
INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY:
	.byte	15,19
	.ascii	"TFactorGrowStrategy"
	.quad	0,0
	.long	8
	.quad	0,0
	.long	0
.Le152:
	.size	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY, .Le152 - INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY:
	.byte	15,19
	.ascii	"TFactorGrowStrategy"
	.quad	0
	.quad	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY$indirect
	.short	0
	.byte	29
	.ascii	"nextpas.core.collections.base"
	.short	0,0
.Le153:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY, .Le153 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY

.section .rodata.n_INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY
	.balign 8
.globl	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY
	.type	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY,@object
INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY:
	.byte	15,23
	.ascii	"TPowerOfTwoGrowStrategy"
	.quad	0,0
	.long	8
	.quad	0,0
	.long	0
.Le154:
	.size	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY, .Le154 - INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY:
	.byte	15,23
	.ascii	"TPowerOfTwoGrowStrategy"
	.quad	0
	.quad	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY$indirect
	.short	0
	.byte	29
	.ascii	"nextpas.core.collections.base"
	.short	0,0
.Le155:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY, .Le155 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY

.section .rodata.n_INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY
	.balign 8
.globl	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY
	.type	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY,@object
INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY:
	.byte	15,24
	.ascii	"TGoldenRatioGrowStrategy"
	.quad	0,0
	.long	8
	.quad	0,0
	.long	0
.Le156:
	.size	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY, .Le156 - INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY:
	.byte	15,24
	.ascii	"TGoldenRatioGrowStrategy"
	.quad	0
	.quad	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY$indirect
	.short	0
	.byte	29
	.ascii	"nextpas.core.collections.base"
	.short	0,0
.Le157:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY, .Le157 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY

.section .rodata.n_INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY
	.balign 8
.globl	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY
	.type	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY,@object
INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY:
	.byte	15,23
	.ascii	"TAlignedWrapperStrategy"
	.quad	0,0
	.long	8
	.quad	0,0
	.long	1
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_IGROWTHSTRATEGY$indirect
	.quad	40
.Le158:
	.size	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY, .Le158 - INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY:
	.byte	15,23
	.ascii	"TAlignedWrapperStrategy"
	.quad	0
	.quad	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY$indirect
	.short	0
	.byte	29
	.ascii	"nextpas.core.collections.base"
	.short	0,0
.Le159:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY, .Le159 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY

.section .rodata.n_INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY
	.balign 8
.globl	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY
	.type	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY,@object
INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY:
	.byte	15,18
	.ascii	"TExactGrowStrategy"
	.quad	0,0
	.long	8
	.quad	0,0
	.long	0
.Le160:
	.size	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY, .Le160 - INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY:
	.byte	15,18
	.ascii	"TExactGrowStrategy"
	.quad	0
	.quad	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY$indirect
	.short	0
	.byte	29
	.ascii	"nextpas.core.collections.base"
	.short	0,0
.Le161:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY, .Le161 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY
# End asmlist al_rtti
# Begin asmlist al_indirectglobals

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION
	.balign 8
.globl	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION$indirect
	.type	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION$indirect,@object
VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION$indirect:
	.quad	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION
# [2673] end.
.Le162:
	.size	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION$indirect, .Le162 - VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION$indirect

.section .rodata.n_IID_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORREFFUNC
	.balign 8
.globl	IID_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORREFFUNC$indirect
	.type	IID_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORREFFUNC$indirect,@object
IID_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORREFFUNC$indirect:
	.quad	IID_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORREFFUNC
.Le163:
	.size	IID_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORREFFUNC$indirect, .Le163 - IID_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORREFFUNC$indirect

.section .rodata.n_IIDSTR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORREFFUNC
	.balign 8
.globl	IIDSTR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORREFFUNC$indirect
	.type	IIDSTR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORREFFUNC$indirect,@object
IIDSTR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORREFFUNC$indirect:
	.quad	IIDSTR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORREFFUNC
.Le164:
	.size	IIDSTR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORREFFUNC$indirect, .Le164 - IIDSTR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORREFFUNC$indirect

.section .rodata.n_IID_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_IGROWTHSTRATEGY
	.balign 8
.globl	IID_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_IGROWTHSTRATEGY$indirect
	.type	IID_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_IGROWTHSTRATEGY$indirect,@object
IID_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_IGROWTHSTRATEGY$indirect:
	.quad	IID_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_IGROWTHSTRATEGY
.Le165:
	.size	IID_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_IGROWTHSTRATEGY$indirect, .Le165 - IID_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_IGROWTHSTRATEGY$indirect

.section .rodata.n_IIDSTR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_IGROWTHSTRATEGY
	.balign 8
.globl	IIDSTR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_IGROWTHSTRATEGY$indirect
	.type	IIDSTR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_IGROWTHSTRATEGY$indirect,@object
IIDSTR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_IGROWTHSTRATEGY$indirect:
	.quad	IIDSTR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_IGROWTHSTRATEGY
.Le166:
	.size	IIDSTR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_IGROWTHSTRATEGY$indirect, .Le166 - IIDSTR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_IGROWTHSTRATEGY$indirect

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY
	.balign 8
.globl	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY$indirect
	.type	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY$indirect,@object
VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY$indirect:
	.quad	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY
.Le167:
	.size	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY$indirect, .Le167 - VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY$indirect

.section .rodata.n_IID_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWREFFUNC
	.balign 8
.globl	IID_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWREFFUNC$indirect
	.type	IID_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWREFFUNC$indirect,@object
IID_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWREFFUNC$indirect:
	.quad	IID_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWREFFUNC
.Le168:
	.size	IID_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWREFFUNC$indirect, .Le168 - IID_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWREFFUNC$indirect

.section .rodata.n_IIDSTR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWREFFUNC
	.balign 8
.globl	IIDSTR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWREFFUNC$indirect
	.type	IIDSTR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWREFFUNC$indirect,@object
IIDSTR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWREFFUNC$indirect:
	.quad	IIDSTR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWREFFUNC
.Le169:
	.size	IIDSTR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWREFFUNC$indirect, .Le169 - IIDSTR_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWREFFUNC$indirect

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY
	.balign 8
.globl	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY$indirect
	.type	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY$indirect,@object
VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY$indirect:
	.quad	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY
.Le170:
	.size	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY$indirect, .Le170 - VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY$indirect

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY
	.balign 8
.globl	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY$indirect
	.type	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY$indirect,@object
VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY$indirect:
	.quad	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY
.Le171:
	.size	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY$indirect, .Le171 - VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY$indirect

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY
	.balign 8
.globl	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY$indirect
	.type	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY$indirect,@object
VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY$indirect:
	.quad	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY
.Le172:
	.size	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY$indirect, .Le172 - VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY$indirect

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY
	.balign 8
.globl	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY$indirect
	.type	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY$indirect,@object
VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY$indirect:
	.quad	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY
.Le173:
	.size	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY$indirect, .Le173 - VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY$indirect

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY
	.balign 8
.globl	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY$indirect
	.type	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY$indirect,@object
VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY$indirect:
	.quad	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY
.Le174:
	.size	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY$indirect, .Le174 - VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY$indirect

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY
	.balign 8
.globl	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY$indirect
	.type	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY$indirect,@object
VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY$indirect:
	.quad	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY
.Le175:
	.size	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY$indirect, .Le175 - VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY$indirect

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY
	.balign 8
.globl	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY$indirect
	.type	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY$indirect,@object
VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY$indirect:
	.quad	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY
.Le176:
	.size	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY$indirect, .Le176 - VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY$indirect

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY
	.balign 8
.globl	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY$indirect
	.type	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY$indirect,@object
VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY$indirect:
	.quad	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY
.Le177:
	.size	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY$indirect, .Le177 - VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY$indirect

.section .rodata.n_VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY
	.balign 8
.globl	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY$indirect
	.type	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY$indirect,@object
VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY$indirect:
	.quad	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY
.Le178:
	.size	VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY$indirect, .Le178 - VMT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY$indirect

.section .rodata.n_INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION
	.balign 8
.globl	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION$indirect
	.type	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION$indirect,@object
INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION$indirect:
	.quad	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION
# [2674] 
.Le179:
	.size	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION$indirect, .Le179 - INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION$indirect
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION$indirect,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION$indirect:
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION
.Le180:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION$indirect, .Le180 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTION$indirect

.section .rodata.n_INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPTRITER
	.balign 8
.globl	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPTRITER$indirect
	.type	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPTRITER$indirect,@object
INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPTRITER$indirect:
	.quad	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPTRITER
.Le181:
	.size	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPTRITER$indirect, .Le181 - INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPTRITER$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_def00000012
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_def00000012$indirect
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_def00000012$indirect,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_def00000012$indirect:
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_def00000012
.Le182:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_def00000012$indirect, .Le182 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_def00000012$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_def00000013
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_def00000013$indirect
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_def00000013$indirect,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_def00000013$indirect:
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_def00000013
.Le183:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_def00000013$indirect, .Le183 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_def00000013$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_def00000014
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_def00000014$indirect
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_def00000014$indirect,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_def00000014$indirect:
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_def00000014
.Le184:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_def00000014$indirect, .Le184 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_def00000014$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPTRITER
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPTRITER$indirect
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPTRITER$indirect,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPTRITER$indirect:
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPTRITER
.Le185:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPTRITER$indirect, .Le185 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPTRITER$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_PPTRITER
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_PPTRITER$indirect
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_PPTRITER$indirect,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_PPTRITER$indirect:
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_PPTRITER
.Le186:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_PPTRITER$indirect, .Le186 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_PPTRITER$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTIONCLASS
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTIONCLASS$indirect
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTIONCLASS$indirect,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTIONCLASS$indirect:
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTIONCLASS
.Le187:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTIONCLASS$indirect, .Le187 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCOLLECTIONCLASS$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORFUNC
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORFUNC$indirect
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORFUNC$indirect,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORFUNC$indirect:
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORFUNC
.Le188:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORFUNC$indirect, .Le188 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORFUNC$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORMETHOD
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORMETHOD$indirect
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORMETHOD$indirect,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORMETHOD$indirect:
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORMETHOD
.Le189:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORMETHOD$indirect, .Le189 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORMETHOD$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORREFFUNC
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORREFFUNC$indirect
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORREFFUNC$indirect,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORREFFUNC$indirect:
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORREFFUNC
.Le190:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORREFFUNC$indirect, .Le190 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TRANDOMGENERATORREFFUNC$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_IGROWTHSTRATEGY
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_IGROWTHSTRATEGY$indirect
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_IGROWTHSTRATEGY$indirect,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_IGROWTHSTRATEGY$indirect:
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_IGROWTHSTRATEGY
.Le191:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_IGROWTHSTRATEGY$indirect, .Le191 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_IGROWTHSTRATEGY$indirect

.section .rodata.n_INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY
	.balign 8
.globl	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY$indirect
	.type	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY$indirect,@object
INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY$indirect:
	.quad	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY
.Le192:
	.size	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY$indirect, .Le192 - INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY$indirect
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY$indirect,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY$indirect:
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY
.Le193:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY$indirect, .Le193 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGY$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGYCLASS
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGYCLASS$indirect
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGYCLASS$indirect,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGYCLASS$indirect:
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGYCLASS
.Le194:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGYCLASS$indirect, .Le194 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWTHSTRATEGYCLASS$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWFUNC
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWFUNC$indirect
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWFUNC$indirect,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWFUNC$indirect:
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWFUNC
.Le195:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWFUNC$indirect, .Le195 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWFUNC$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWMETHOD
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWMETHOD$indirect
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWMETHOD$indirect,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWMETHOD$indirect:
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWMETHOD
.Le196:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWMETHOD$indirect, .Le196 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWMETHOD$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWREFFUNC
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWREFFUNC$indirect
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWREFFUNC$indirect,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWREFFUNC$indirect:
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWREFFUNC
.Le197:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWREFFUNC$indirect, .Le197 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWREFFUNC$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWPROXYMETHOD
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWPROXYMETHOD$indirect
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWPROXYMETHOD$indirect,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWPROXYMETHOD$indirect:
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWPROXYMETHOD
.Le198:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWPROXYMETHOD$indirect, .Le198 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGROWPROXYMETHOD$indirect

.section .rodata.n_INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY
	.balign 8
.globl	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY$indirect
	.type	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY$indirect,@object
INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY$indirect:
	.quad	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY
.Le199:
	.size	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY$indirect, .Le199 - INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY$indirect
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY$indirect,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY$indirect:
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY
.Le200:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY$indirect, .Le200 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCUSTOMGROWTHSTRATEGY$indirect

.section .rodata.n_INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY
	.balign 8
.globl	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY$indirect
	.type	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY$indirect,@object
INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY$indirect:
	.quad	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY
.Le201:
	.size	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY$indirect, .Le201 - INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY$indirect
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY$indirect,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY$indirect:
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY
.Le202:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY$indirect, .Le202 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TCALCGROWSTRATEGY$indirect

.section .rodata.n_INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY
	.balign 8
.globl	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY$indirect
	.type	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY$indirect,@object
INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY$indirect:
	.quad	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY
.Le203:
	.size	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY$indirect, .Le203 - INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY$indirect
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY$indirect,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY$indirect:
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY
.Le204:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY$indirect, .Le204 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TDOUBLINGGROWSTRATEGY$indirect

.section .rodata.n_INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY
	.balign 8
.globl	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY$indirect
	.type	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY$indirect,@object
INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY$indirect:
	.quad	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY
.Le205:
	.size	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY$indirect, .Le205 - INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY$indirect
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY$indirect,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY$indirect:
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY
.Le206:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY$indirect, .Le206 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFIXEDGROWSTRATEGY$indirect

.section .rodata.n_INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY
	.balign 8
.globl	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY$indirect
	.type	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY$indirect,@object
INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY$indirect:
	.quad	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY
.Le207:
	.size	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY$indirect, .Le207 - INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY$indirect
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY$indirect,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY$indirect:
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY
.Le208:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY$indirect, .Le208 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TFACTORGROWSTRATEGY$indirect

.section .rodata.n_INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY
	.balign 8
.globl	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY$indirect
	.type	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY$indirect,@object
INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY$indirect:
	.quad	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY
.Le209:
	.size	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY$indirect, .Le209 - INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY$indirect
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY$indirect,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY$indirect:
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY
.Le210:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY$indirect, .Le210 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TPOWEROFTWOGROWSTRATEGY$indirect

.section .rodata.n_INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY
	.balign 8
.globl	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY$indirect
	.type	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY$indirect,@object
INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY$indirect:
	.quad	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY
.Le211:
	.size	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY$indirect, .Le211 - INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY$indirect
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY$indirect,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY$indirect:
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY
.Le212:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY$indirect, .Le212 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TGOLDENRATIOGROWSTRATEGY$indirect

.section .rodata.n_INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY
	.balign 8
.globl	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY$indirect
	.type	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY$indirect,@object
INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY$indirect:
	.quad	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY
.Le213:
	.size	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY$indirect, .Le213 - INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY$indirect
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY$indirect,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY$indirect:
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY
.Le214:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY$indirect, .Le214 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TALIGNEDWRAPPERSTRATEGY$indirect

.section .rodata.n_INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY
	.balign 8
.globl	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY$indirect
	.type	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY$indirect,@object
INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY$indirect:
	.quad	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY
.Le215:
	.size	INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY$indirect, .Le215 - INIT_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY$indirect
	.type	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY$indirect,@object
RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY$indirect:
	.quad	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY
.Le216:
	.size	RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY$indirect, .Le216 - RTTI_$NEXTPAS.CORE.COLLECTIONS.BASE_$$_TEXACTGROWSTRATEGY$indirect
# End asmlist al_indirectglobals
# Begin asmlist al_dwarf_frame

.section .debug_frame
.Lc597:
	.long	.Lc599-.Lc598
.Lc598:
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
.Lc599:
	.long	.Lc601-.Lc600
.Lc600:
	.long	.Lc597
	.quad	.Lc2
	.quad	.Lc1-.Lc2
	.byte	4
	.long	.Lc3-.Lc2
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc601:
	.long	.Lc604-.Lc603
.Lc603:
	.long	.Lc597
	.quad	.Lc5
	.quad	.Lc4-.Lc5
	.byte	2
	.byte	.Lc6-.Lc5
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc7-.Lc6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc604:
	.long	.Lc607-.Lc606
.Lc606:
	.long	.Lc597
	.quad	.Lc9
	.quad	.Lc8-.Lc9
	.byte	2
	.byte	.Lc10-.Lc9
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc11-.Lc10
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc607:
	.long	.Lc610-.Lc609
.Lc609:
	.long	.Lc597
	.quad	.Lc13
	.quad	.Lc12-.Lc13
	.byte	4
	.long	.Lc14-.Lc13
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc610:
	.long	.Lc613-.Lc612
.Lc612:
	.long	.Lc597
	.quad	.Lc16
	.quad	.Lc15-.Lc16
	.byte	4
	.long	.Lc17-.Lc16
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc613:
	.long	.Lc616-.Lc615
.Lc615:
	.long	.Lc597
	.quad	.Lc19
	.quad	.Lc18-.Lc19
	.byte	4
	.long	.Lc20-.Lc19
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc616:
	.long	.Lc619-.Lc618
.Lc618:
	.long	.Lc597
	.quad	.Lc22
	.quad	.Lc21-.Lc22
	.byte	4
	.long	.Lc23-.Lc22
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc619:
	.long	.Lc622-.Lc621
.Lc621:
	.long	.Lc597
	.quad	.Lc25
	.quad	.Lc24-.Lc25
	.byte	4
	.long	.Lc26-.Lc25
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc622:
	.long	.Lc625-.Lc624
.Lc624:
	.long	.Lc597
	.quad	.Lc28
	.quad	.Lc27-.Lc28
	.byte	4
	.long	.Lc29-.Lc28
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc625:
	.long	.Lc628-.Lc627
.Lc627:
	.long	.Lc597
	.quad	.Lc31
	.quad	.Lc30-.Lc31
	.byte	4
	.long	.Lc32-.Lc31
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc628:
	.long	.Lc631-.Lc630
.Lc630:
	.long	.Lc597
	.quad	.Lc34
	.quad	.Lc33-.Lc34
	.byte	4
	.long	.Lc35-.Lc34
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc631:
	.long	.Lc634-.Lc633
.Lc633:
	.long	.Lc597
	.quad	.Lc37
	.quad	.Lc36-.Lc37
	.byte	4
	.long	.Lc38-.Lc37
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc634:
	.long	.Lc637-.Lc636
.Lc636:
	.long	.Lc597
	.quad	.Lc40
	.quad	.Lc39-.Lc40
	.byte	4
	.long	.Lc41-.Lc40
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc637:
	.long	.Lc640-.Lc639
.Lc639:
	.long	.Lc597
	.quad	.Lc43
	.quad	.Lc42-.Lc43
	.byte	2
	.byte	.Lc44-.Lc43
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc45-.Lc44
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc46-.Lc45
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc47-.Lc46
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc640:
	.long	.Lc643-.Lc642
.Lc642:
	.long	.Lc597
	.quad	.Lc49
	.quad	.Lc48-.Lc49
	.byte	2
	.byte	.Lc50-.Lc49
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc51-.Lc50
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc643:
	.long	.Lc646-.Lc645
.Lc645:
	.long	.Lc597
	.quad	.Lc53
	.quad	.Lc52-.Lc53
	.byte	2
	.byte	.Lc54-.Lc53
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc55-.Lc54
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc646:
	.long	.Lc649-.Lc648
.Lc648:
	.long	.Lc597
	.quad	.Lc57
	.quad	.Lc56-.Lc57
	.byte	2
	.byte	.Lc58-.Lc57
	.byte	5
	.uleb128	3
	.uleb128	134
	.byte	14
	.uleb128	536
	.byte	2
	.byte	.Lc59-.Lc58
	.byte	14
	.uleb128	544
	.byte	4
	.long	.Lc60-.Lc59
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc649:
	.long	.Lc652-.Lc651
.Lc651:
	.long	.Lc597
	.quad	.Lc62
	.quad	.Lc61-.Lc62
	.byte	2
	.byte	.Lc63-.Lc62
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc64-.Lc63
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc652:
	.long	.Lc655-.Lc654
.Lc654:
	.long	.Lc597
	.quad	.Lc66
	.quad	.Lc65-.Lc66
	.byte	2
	.byte	.Lc67-.Lc66
	.byte	5
	.uleb128	3
	.uleb128	12
	.byte	14
	.uleb128	48
	.byte	2
	.byte	.Lc68-.Lc67
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc69-.Lc68
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc655:
	.long	.Lc658-.Lc657
.Lc657:
	.long	.Lc597
	.quad	.Lc71
	.quad	.Lc70-.Lc71
	.byte	2
	.byte	.Lc72-.Lc71
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc73-.Lc72
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc74-.Lc73
	.byte	5
	.uleb128	13
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc75-.Lc74
	.byte	5
	.uleb128	14
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc76-.Lc75
	.byte	5
	.uleb128	15
	.uleb128	12
	.byte	14
	.uleb128	48
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc77-.Lc76
	.byte	6
	.uleb128	15
	.byte	2
	.byte	.Lc78-.Lc77
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc79-.Lc78
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc80-.Lc79
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc81-.Lc80
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc658:
	.long	.Lc661-.Lc660
.Lc660:
	.long	.Lc597
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
.Lc661:
	.long	.Lc664-.Lc663
.Lc663:
	.long	.Lc597
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
.Lc664:
	.long	.Lc667-.Lc666
.Lc666:
	.long	.Lc597
	.quad	.Lc95
	.quad	.Lc94-.Lc95
	.byte	2
	.byte	.Lc96-.Lc95
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc97-.Lc96
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc98-.Lc97
	.byte	5
	.uleb128	13
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc99-.Lc98
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc100-.Lc99
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc101-.Lc100
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc667:
	.long	.Lc670-.Lc669
.Lc669:
	.long	.Lc597
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
.Lc670:
	.long	.Lc673-.Lc672
.Lc672:
	.long	.Lc597
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
.Lc673:
	.long	.Lc676-.Lc675
.Lc675:
	.long	.Lc597
	.quad	.Lc111
	.quad	.Lc110-.Lc111
	.byte	2
	.byte	.Lc112-.Lc111
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc113-.Lc112
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc676:
	.long	.Lc679-.Lc678
.Lc678:
	.long	.Lc597
	.quad	.Lc115
	.quad	.Lc114-.Lc115
	.byte	4
	.long	.Lc116-.Lc115
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc679:
	.long	.Lc682-.Lc681
.Lc681:
	.long	.Lc597
	.quad	.Lc118
	.quad	.Lc117-.Lc118
	.byte	2
	.byte	.Lc119-.Lc118
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc120-.Lc119
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc682:
	.long	.Lc685-.Lc684
.Lc684:
	.long	.Lc597
	.quad	.Lc122
	.quad	.Lc121-.Lc122
	.byte	4
	.long	.Lc123-.Lc122
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc685:
	.long	.Lc688-.Lc687
.Lc687:
	.long	.Lc597
	.quad	.Lc125
	.quad	.Lc124-.Lc125
	.byte	4
	.long	.Lc126-.Lc125
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc688:
	.long	.Lc691-.Lc690
.Lc690:
	.long	.Lc597
	.quad	.Lc128
	.quad	.Lc127-.Lc128
	.byte	4
	.long	.Lc129-.Lc128
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc691:
	.long	.Lc694-.Lc693
.Lc693:
	.long	.Lc597
	.quad	.Lc131
	.quad	.Lc130-.Lc131
	.byte	4
	.long	.Lc132-.Lc131
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc694:
	.long	.Lc697-.Lc696
.Lc696:
	.long	.Lc597
	.quad	.Lc134
	.quad	.Lc133-.Lc134
	.byte	4
	.long	.Lc135-.Lc134
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc697:
	.long	.Lc700-.Lc699
.Lc699:
	.long	.Lc597
	.quad	.Lc137
	.quad	.Lc136-.Lc137
	.byte	4
	.long	.Lc138-.Lc137
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc700:
	.long	.Lc703-.Lc702
.Lc702:
	.long	.Lc597
	.quad	.Lc140
	.quad	.Lc139-.Lc140
	.byte	4
	.long	.Lc141-.Lc140
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc703:
	.long	.Lc706-.Lc705
.Lc705:
	.long	.Lc597
	.quad	.Lc143
	.quad	.Lc142-.Lc143
	.byte	4
	.long	.Lc144-.Lc143
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc706:
	.long	.Lc709-.Lc708
.Lc708:
	.long	.Lc597
	.quad	.Lc146
	.quad	.Lc145-.Lc146
	.byte	4
	.long	.Lc147-.Lc146
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc709:
	.long	.Lc712-.Lc711
.Lc711:
	.long	.Lc597
	.quad	.Lc149
	.quad	.Lc148-.Lc149
	.byte	4
	.long	.Lc150-.Lc149
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc712:
	.long	.Lc715-.Lc714
.Lc714:
	.long	.Lc597
	.quad	.Lc152
	.quad	.Lc151-.Lc152
	.byte	4
	.long	.Lc153-.Lc152
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc715:
	.long	.Lc718-.Lc717
.Lc717:
	.long	.Lc597
	.quad	.Lc155
	.quad	.Lc154-.Lc155
	.byte	4
	.long	.Lc156-.Lc155
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc718:
	.long	.Lc721-.Lc720
.Lc720:
	.long	.Lc597
	.quad	.Lc158
	.quad	.Lc157-.Lc158
	.byte	4
	.long	.Lc159-.Lc158
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc721:
	.long	.Lc724-.Lc723
.Lc723:
	.long	.Lc597
	.quad	.Lc161
	.quad	.Lc160-.Lc161
	.byte	2
	.byte	.Lc162-.Lc161
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc163-.Lc162
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc164-.Lc163
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc165-.Lc164
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc724:
	.long	.Lc727-.Lc726
.Lc726:
	.long	.Lc597
	.quad	.Lc167
	.quad	.Lc166-.Lc167
	.byte	2
	.byte	.Lc168-.Lc167
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc169-.Lc168
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc727:
	.long	.Lc730-.Lc729
.Lc729:
	.long	.Lc597
	.quad	.Lc171
	.quad	.Lc170-.Lc171
	.byte	2
	.byte	.Lc172-.Lc171
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc173-.Lc172
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc730:
	.long	.Lc733-.Lc732
.Lc732:
	.long	.Lc597
	.quad	.Lc175
	.quad	.Lc174-.Lc175
	.byte	2
	.byte	.Lc176-.Lc175
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc177-.Lc176
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc733:
	.long	.Lc736-.Lc735
.Lc735:
	.long	.Lc597
	.quad	.Lc179
	.quad	.Lc178-.Lc179
	.byte	2
	.byte	.Lc180-.Lc179
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc181-.Lc180
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc736:
	.long	.Lc739-.Lc738
.Lc738:
	.long	.Lc597
	.quad	.Lc183
	.quad	.Lc182-.Lc183
	.byte	2
	.byte	.Lc184-.Lc183
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc185-.Lc184
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc739:
	.long	.Lc742-.Lc741
.Lc741:
	.long	.Lc597
	.quad	.Lc187
	.quad	.Lc186-.Lc187
	.byte	2
	.byte	.Lc188-.Lc187
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc189-.Lc188
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc742:
	.long	.Lc745-.Lc744
.Lc744:
	.long	.Lc597
	.quad	.Lc191
	.quad	.Lc190-.Lc191
	.byte	4
	.long	.Lc192-.Lc191
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc745:
	.long	.Lc748-.Lc747
.Lc747:
	.long	.Lc597
	.quad	.Lc194
	.quad	.Lc193-.Lc194
	.byte	2
	.byte	.Lc195-.Lc194
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc196-.Lc195
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc748:
	.long	.Lc751-.Lc750
.Lc750:
	.long	.Lc597
	.quad	.Lc198
	.quad	.Lc197-.Lc198
	.byte	2
	.byte	.Lc199-.Lc198
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc200-.Lc199
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc751:
	.long	.Lc754-.Lc753
.Lc753:
	.long	.Lc597
	.quad	.Lc202
	.quad	.Lc201-.Lc202
	.byte	2
	.byte	.Lc203-.Lc202
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc204-.Lc203
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc754:
	.long	.Lc757-.Lc756
.Lc756:
	.long	.Lc597
	.quad	.Lc206
	.quad	.Lc205-.Lc206
	.byte	4
	.long	.Lc207-.Lc206
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc757:
	.long	.Lc760-.Lc759
.Lc759:
	.long	.Lc597
	.quad	.Lc209
	.quad	.Lc208-.Lc209
	.byte	2
	.byte	.Lc210-.Lc209
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc211-.Lc210
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc212-.Lc211
	.byte	5
	.uleb128	13
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc213-.Lc212
	.byte	5
	.uleb128	14
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc214-.Lc213
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc215-.Lc214
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc216-.Lc215
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc217-.Lc216
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc218-.Lc217
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc760:
	.long	.Lc763-.Lc762
.Lc762:
	.long	.Lc597
	.quad	.Lc220
	.quad	.Lc219-.Lc220
	.byte	2
	.byte	.Lc221-.Lc220
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc222-.Lc221
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc223-.Lc222
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc224-.Lc223
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc763:
	.long	.Lc766-.Lc765
.Lc765:
	.long	.Lc597
	.quad	.Lc226
	.quad	.Lc225-.Lc226
	.byte	2
	.byte	.Lc227-.Lc226
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc228-.Lc227
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc229-.Lc228
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc230-.Lc229
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc766:
	.long	.Lc769-.Lc768
.Lc768:
	.long	.Lc597
	.quad	.Lc232
	.quad	.Lc231-.Lc232
	.byte	4
	.long	.Lc233-.Lc232
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc769:
	.long	.Lc772-.Lc771
.Lc771:
	.long	.Lc597
	.quad	.Lc235
	.quad	.Lc234-.Lc235
	.byte	2
	.byte	.Lc236-.Lc235
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc237-.Lc236
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc772:
	.long	.Lc775-.Lc774
.Lc774:
	.long	.Lc597
	.quad	.Lc239
	.quad	.Lc238-.Lc239
	.byte	2
	.byte	.Lc240-.Lc239
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc241-.Lc240
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc775:
	.long	.Lc778-.Lc777
.Lc777:
	.long	.Lc597
	.quad	.Lc243
	.quad	.Lc242-.Lc243
	.byte	2
	.byte	.Lc244-.Lc243
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc245-.Lc244
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc778:
	.long	.Lc781-.Lc780
.Lc780:
	.long	.Lc597
	.quad	.Lc247
	.quad	.Lc246-.Lc247
	.byte	4
	.long	.Lc248-.Lc247
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc781:
	.long	.Lc784-.Lc783
.Lc783:
	.long	.Lc597
	.quad	.Lc250
	.quad	.Lc249-.Lc250
	.byte	2
	.byte	.Lc251-.Lc250
	.byte	14
	.uleb128	240
	.byte	4
	.long	.Lc252-.Lc251
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc784:
	.long	.Lc787-.Lc786
.Lc786:
	.long	.Lc597
	.quad	.Lc254
	.quad	.Lc253-.Lc254
	.byte	2
	.byte	.Lc255-.Lc254
	.byte	14
	.uleb128	240
	.byte	4
	.long	.Lc256-.Lc255
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc787:
	.long	.Lc790-.Lc789
.Lc789:
	.long	.Lc597
	.quad	.Lc258
	.quad	.Lc257-.Lc258
	.byte	2
	.byte	.Lc259-.Lc258
	.byte	14
	.uleb128	256
	.byte	4
	.long	.Lc260-.Lc259
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc790:
	.long	.Lc793-.Lc792
.Lc792:
	.long	.Lc597
	.quad	.Lc262
	.quad	.Lc261-.Lc262
	.byte	2
	.byte	.Lc263-.Lc262
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc264-.Lc263
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc265-.Lc264
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc266-.Lc265
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc793:
	.long	.Lc796-.Lc795
.Lc795:
	.long	.Lc597
	.quad	.Lc268
	.quad	.Lc267-.Lc268
	.byte	2
	.byte	.Lc269-.Lc268
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc270-.Lc269
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc271-.Lc270
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc272-.Lc271
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc796:
	.long	.Lc799-.Lc798
.Lc798:
	.long	.Lc597
	.quad	.Lc274
	.quad	.Lc273-.Lc274
	.byte	2
	.byte	.Lc275-.Lc274
	.byte	14
	.uleb128	256
	.byte	4
	.long	.Lc276-.Lc275
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc799:
	.long	.Lc802-.Lc801
.Lc801:
	.long	.Lc597
	.quad	.Lc278
	.quad	.Lc277-.Lc278
	.byte	2
	.byte	.Lc279-.Lc278
	.byte	14
	.uleb128	256
	.byte	4
	.long	.Lc280-.Lc279
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc802:
	.long	.Lc805-.Lc804
.Lc804:
	.long	.Lc597
	.quad	.Lc282
	.quad	.Lc281-.Lc282
	.byte	2
	.byte	.Lc283-.Lc282
	.byte	14
	.uleb128	256
	.byte	4
	.long	.Lc284-.Lc283
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc805:
	.long	.Lc808-.Lc807
.Lc807:
	.long	.Lc597
	.quad	.Lc286
	.quad	.Lc285-.Lc286
	.byte	2
	.byte	.Lc287-.Lc286
	.byte	14
	.uleb128	256
	.byte	4
	.long	.Lc288-.Lc287
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc808:
	.long	.Lc811-.Lc810
.Lc810:
	.long	.Lc597
	.quad	.Lc290
	.quad	.Lc289-.Lc290
	.byte	2
	.byte	.Lc291-.Lc290
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc292-.Lc291
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc811:
	.long	.Lc814-.Lc813
.Lc813:
	.long	.Lc597
	.quad	.Lc294
	.quad	.Lc293-.Lc294
	.byte	2
	.byte	.Lc295-.Lc294
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc296-.Lc295
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc814:
	.long	.Lc817-.Lc816
.Lc816:
	.long	.Lc597
	.quad	.Lc298
	.quad	.Lc297-.Lc298
	.byte	4
	.long	.Lc299-.Lc298
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc817:
	.long	.Lc820-.Lc819
.Lc819:
	.long	.Lc597
	.quad	.Lc301
	.quad	.Lc300-.Lc301
	.byte	4
	.long	.Lc302-.Lc301
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc820:
	.long	.Lc823-.Lc822
.Lc822:
	.long	.Lc597
	.quad	.Lc304
	.quad	.Lc303-.Lc304
	.byte	2
	.byte	.Lc305-.Lc304
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc306-.Lc305
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc307-.Lc306
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc308-.Lc307
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc823:
	.long	.Lc826-.Lc825
.Lc825:
	.long	.Lc597
	.quad	.Lc310
	.quad	.Lc309-.Lc310
	.byte	2
	.byte	.Lc311-.Lc310
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc312-.Lc311
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc826:
	.long	.Lc829-.Lc828
.Lc828:
	.long	.Lc597
	.quad	.Lc314
	.quad	.Lc313-.Lc314
	.byte	2
	.byte	.Lc315-.Lc314
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc316-.Lc315
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc317-.Lc316
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc318-.Lc317
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc829:
	.long	.Lc832-.Lc831
.Lc831:
	.long	.Lc597
	.quad	.Lc320
	.quad	.Lc319-.Lc320
	.byte	2
	.byte	.Lc321-.Lc320
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc322-.Lc321
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc323-.Lc322
	.byte	5
	.uleb128	13
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc324-.Lc323
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc325-.Lc324
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc326-.Lc325
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc832:
	.long	.Lc835-.Lc834
.Lc834:
	.long	.Lc597
	.quad	.Lc328
	.quad	.Lc327-.Lc328
	.byte	2
	.byte	.Lc329-.Lc328
	.byte	14
	.uleb128	240
	.byte	4
	.long	.Lc330-.Lc329
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc835:
	.long	.Lc838-.Lc837
.Lc837:
	.long	.Lc597
	.quad	.Lc332
	.quad	.Lc331-.Lc332
	.byte	2
	.byte	.Lc333-.Lc332
	.byte	14
	.uleb128	240
	.byte	4
	.long	.Lc334-.Lc333
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc838:
	.long	.Lc841-.Lc840
.Lc840:
	.long	.Lc597
	.quad	.Lc336
	.quad	.Lc335-.Lc336
	.byte	2
	.byte	.Lc337-.Lc336
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc338-.Lc337
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc339-.Lc338
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc340-.Lc339
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc841:
	.long	.Lc844-.Lc843
.Lc843:
	.long	.Lc597
	.quad	.Lc342
	.quad	.Lc341-.Lc342
	.byte	2
	.byte	.Lc343-.Lc342
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc344-.Lc343
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc345-.Lc344
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc346-.Lc345
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc844:
	.long	.Lc847-.Lc846
.Lc846:
	.long	.Lc597
	.quad	.Lc348
	.quad	.Lc347-.Lc348
	.byte	2
	.byte	.Lc349-.Lc348
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc350-.Lc349
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc847:
	.long	.Lc850-.Lc849
.Lc849:
	.long	.Lc597
	.quad	.Lc352
	.quad	.Lc351-.Lc352
	.byte	2
	.byte	.Lc353-.Lc352
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc354-.Lc353
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc355-.Lc354
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc356-.Lc355
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc850:
	.long	.Lc853-.Lc852
.Lc852:
	.long	.Lc597
	.quad	.Lc358
	.quad	.Lc357-.Lc358
	.byte	2
	.byte	.Lc359-.Lc358
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc360-.Lc359
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc361-.Lc360
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc362-.Lc361
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc363-.Lc362
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc853:
	.long	.Lc856-.Lc855
.Lc855:
	.long	.Lc597
	.quad	.Lc365
	.quad	.Lc364-.Lc365
	.byte	2
	.byte	.Lc366-.Lc365
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc367-.Lc366
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc368-.Lc367
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc369-.Lc368
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc856:
	.long	.Lc859-.Lc858
.Lc858:
	.long	.Lc597
	.quad	.Lc371
	.quad	.Lc370-.Lc371
	.byte	2
	.byte	.Lc372-.Lc371
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc373-.Lc372
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc374-.Lc373
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc375-.Lc374
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc859:
	.long	.Lc862-.Lc861
.Lc861:
	.long	.Lc597
	.quad	.Lc377
	.quad	.Lc376-.Lc377
	.byte	2
	.byte	.Lc378-.Lc377
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc379-.Lc378
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc380-.Lc379
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc381-.Lc380
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc382-.Lc381
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc862:
	.long	.Lc865-.Lc864
.Lc864:
	.long	.Lc597
	.quad	.Lc384
	.quad	.Lc383-.Lc384
	.byte	2
	.byte	.Lc385-.Lc384
	.byte	14
	.uleb128	224
	.byte	4
	.long	.Lc386-.Lc385
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc865:
	.long	.Lc868-.Lc867
.Lc867:
	.long	.Lc597
	.quad	.Lc388
	.quad	.Lc387-.Lc388
	.byte	2
	.byte	.Lc389-.Lc388
	.byte	5
	.uleb128	3
	.uleb128	58
	.byte	14
	.uleb128	232
	.byte	2
	.byte	.Lc390-.Lc389
	.byte	14
	.uleb128	240
	.byte	4
	.long	.Lc391-.Lc390
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc868:
	.long	.Lc871-.Lc870
.Lc870:
	.long	.Lc597
	.quad	.Lc393
	.quad	.Lc392-.Lc393
	.byte	2
	.byte	.Lc394-.Lc393
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc395-.Lc394
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc871:
	.long	.Lc874-.Lc873
.Lc873:
	.long	.Lc597
	.quad	.Lc397
	.quad	.Lc396-.Lc397
	.byte	2
	.byte	.Lc398-.Lc397
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc399-.Lc398
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc874:
	.long	.Lc877-.Lc876
.Lc876:
	.long	.Lc597
	.quad	.Lc401
	.quad	.Lc400-.Lc401
	.byte	2
	.byte	.Lc402-.Lc401
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc403-.Lc402
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc877:
	.long	.Lc880-.Lc879
.Lc879:
	.long	.Lc597
	.quad	.Lc405
	.quad	.Lc404-.Lc405
	.byte	2
	.byte	.Lc406-.Lc405
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc407-.Lc406
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc880:
	.long	.Lc883-.Lc882
.Lc882:
	.long	.Lc597
	.quad	.Lc409
	.quad	.Lc408-.Lc409
	.byte	2
	.byte	.Lc410-.Lc409
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc411-.Lc410
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc883:
	.long	.Lc886-.Lc885
.Lc885:
	.long	.Lc597
	.quad	.Lc413
	.quad	.Lc412-.Lc413
	.byte	2
	.byte	.Lc414-.Lc413
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc415-.Lc414
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc416-.Lc415
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc417-.Lc416
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc418-.Lc417
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc886:
	.long	.Lc889-.Lc888
.Lc888:
	.long	.Lc597
	.quad	.Lc420
	.quad	.Lc419-.Lc420
	.byte	4
	.long	.Lc421-.Lc420
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc889:
	.long	.Lc892-.Lc891
.Lc891:
	.long	.Lc597
	.quad	.Lc423
	.quad	.Lc422-.Lc423
	.byte	2
	.byte	.Lc424-.Lc423
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc425-.Lc424
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc892:
	.long	.Lc895-.Lc894
.Lc894:
	.long	.Lc597
	.quad	.Lc427
	.quad	.Lc426-.Lc427
	.byte	2
	.byte	.Lc428-.Lc427
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc429-.Lc428
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc895:
	.long	.Lc898-.Lc897
.Lc897:
	.long	.Lc597
	.quad	.Lc431
	.quad	.Lc430-.Lc431
	.byte	2
	.byte	.Lc432-.Lc431
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc433-.Lc432
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc898:
	.long	.Lc901-.Lc900
.Lc900:
	.long	.Lc597
	.quad	.Lc435
	.quad	.Lc434-.Lc435
	.byte	2
	.byte	.Lc436-.Lc435
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc437-.Lc436
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc901:
	.long	.Lc904-.Lc903
.Lc903:
	.long	.Lc597
	.quad	.Lc439
	.quad	.Lc438-.Lc439
	.byte	2
	.byte	.Lc440-.Lc439
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc441-.Lc440
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc442-.Lc441
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc443-.Lc442
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc904:
	.long	.Lc907-.Lc906
.Lc906:
	.long	.Lc597
	.quad	.Lc445
	.quad	.Lc444-.Lc445
	.byte	2
	.byte	.Lc446-.Lc445
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc447-.Lc446
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc448-.Lc447
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc449-.Lc448
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc907:
	.long	.Lc910-.Lc909
.Lc909:
	.long	.Lc597
	.quad	.Lc451
	.quad	.Lc450-.Lc451
	.byte	2
	.byte	.Lc452-.Lc451
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc453-.Lc452
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc454-.Lc453
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc455-.Lc454
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc910:
	.long	.Lc913-.Lc912
.Lc912:
	.long	.Lc597
	.quad	.Lc457
	.quad	.Lc456-.Lc457
	.byte	2
	.byte	.Lc458-.Lc457
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc459-.Lc458
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc460-.Lc459
	.byte	5
	.uleb128	13
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc461-.Lc460
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc462-.Lc461
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc463-.Lc462
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc913:
	.long	.Lc916-.Lc915
.Lc915:
	.long	.Lc597
	.quad	.Lc465
	.quad	.Lc464-.Lc465
	.byte	4
	.long	.Lc466-.Lc465
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc916:
	.long	.Lc919-.Lc918
.Lc918:
	.long	.Lc597
	.quad	.Lc468
	.quad	.Lc467-.Lc468
	.byte	2
	.byte	.Lc469-.Lc468
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc470-.Lc469
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc919:
	.long	.Lc922-.Lc921
.Lc921:
	.long	.Lc597
	.quad	.Lc472
	.quad	.Lc471-.Lc472
	.byte	2
	.byte	.Lc473-.Lc472
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc474-.Lc473
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc922:
	.long	.Lc925-.Lc924
.Lc924:
	.long	.Lc597
	.quad	.Lc476
	.quad	.Lc475-.Lc476
	.byte	4
	.long	.Lc477-.Lc476
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc925:
	.long	.Lc928-.Lc927
.Lc927:
	.long	.Lc597
	.quad	.Lc479
	.quad	.Lc478-.Lc479
	.byte	4
	.long	.Lc480-.Lc479
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc928:
	.long	.Lc931-.Lc930
.Lc930:
	.long	.Lc597
	.quad	.Lc482
	.quad	.Lc481-.Lc482
	.byte	2
	.byte	.Lc483-.Lc482
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc484-.Lc483
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc485-.Lc484
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc486-.Lc485
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc931:
	.long	.Lc934-.Lc933
.Lc933:
	.long	.Lc597
	.quad	.Lc488
	.quad	.Lc487-.Lc488
	.byte	4
	.long	.Lc489-.Lc488
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc934:
	.long	.Lc937-.Lc936
.Lc936:
	.long	.Lc597
	.quad	.Lc491
	.quad	.Lc490-.Lc491
	.byte	2
	.byte	.Lc492-.Lc491
	.byte	5
	.uleb128	3
	.uleb128	12
	.byte	14
	.uleb128	48
	.byte	2
	.byte	.Lc493-.Lc492
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc494-.Lc493
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc937:
	.long	.Lc940-.Lc939
.Lc939:
	.long	.Lc597
	.quad	.Lc496
	.quad	.Lc495-.Lc496
	.byte	2
	.byte	.Lc497-.Lc496
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc498-.Lc497
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc499-.Lc498
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc500-.Lc499
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc940:
	.long	.Lc943-.Lc942
.Lc942:
	.long	.Lc597
	.quad	.Lc502
	.quad	.Lc501-.Lc502
	.byte	2
	.byte	.Lc503-.Lc502
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc504-.Lc503
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc943:
	.long	.Lc946-.Lc945
.Lc945:
	.long	.Lc597
	.quad	.Lc506
	.quad	.Lc505-.Lc506
	.byte	2
	.byte	.Lc507-.Lc506
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc508-.Lc507
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc946:
	.long	.Lc949-.Lc948
.Lc948:
	.long	.Lc597
	.quad	.Lc510
	.quad	.Lc509-.Lc510
	.byte	4
	.long	.Lc511-.Lc510
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc949:
	.long	.Lc952-.Lc951
.Lc951:
	.long	.Lc597
	.quad	.Lc513
	.quad	.Lc512-.Lc513
	.byte	2
	.byte	.Lc514-.Lc513
	.byte	5
	.uleb128	3
	.uleb128	12
	.byte	14
	.uleb128	48
	.byte	2
	.byte	.Lc515-.Lc514
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc516-.Lc515
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc952:
	.long	.Lc955-.Lc954
.Lc954:
	.long	.Lc597
	.quad	.Lc518
	.quad	.Lc517-.Lc518
	.byte	2
	.byte	.Lc519-.Lc518
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc520-.Lc519
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc955:
	.long	.Lc958-.Lc957
.Lc957:
	.long	.Lc597
	.quad	.Lc522
	.quad	.Lc521-.Lc522
	.byte	2
	.byte	.Lc523-.Lc522
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc524-.Lc523
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc958:
	.long	.Lc961-.Lc960
.Lc960:
	.long	.Lc597
	.quad	.Lc526
	.quad	.Lc525-.Lc526
	.byte	2
	.byte	.Lc527-.Lc526
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc528-.Lc527
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc961:
	.long	.Lc964-.Lc963
.Lc963:
	.long	.Lc597
	.quad	.Lc530
	.quad	.Lc529-.Lc530
	.byte	4
	.long	.Lc531-.Lc530
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc964:
	.long	.Lc967-.Lc966
.Lc966:
	.long	.Lc597
	.quad	.Lc533
	.quad	.Lc532-.Lc533
	.byte	2
	.byte	.Lc534-.Lc533
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc535-.Lc534
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc536-.Lc535
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc537-.Lc536
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc967:
	.long	.Lc970-.Lc969
.Lc969:
	.long	.Lc597
	.quad	.Lc539
	.quad	.Lc538-.Lc539
	.byte	2
	.byte	.Lc540-.Lc539
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc541-.Lc540
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc970:
	.long	.Lc973-.Lc972
.Lc972:
	.long	.Lc597
	.quad	.Lc543
	.quad	.Lc542-.Lc543
	.byte	2
	.byte	.Lc544-.Lc543
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc545-.Lc544
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc973:
	.long	.Lc976-.Lc975
.Lc975:
	.long	.Lc597
	.quad	.Lc547
	.quad	.Lc546-.Lc547
	.byte	2
	.byte	.Lc548-.Lc547
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc549-.Lc548
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc976:
	.long	.Lc979-.Lc978
.Lc978:
	.long	.Lc597
	.quad	.Lc551
	.quad	.Lc550-.Lc551
	.byte	4
	.long	.Lc552-.Lc551
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc979:
	.long	.Lc982-.Lc981
.Lc981:
	.long	.Lc597
	.quad	.Lc554
	.quad	.Lc553-.Lc554
	.byte	2
	.byte	.Lc555-.Lc554
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc556-.Lc555
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc982:
	.long	.Lc985-.Lc984
.Lc984:
	.long	.Lc597
	.quad	.Lc558
	.quad	.Lc557-.Lc558
	.byte	2
	.byte	.Lc559-.Lc558
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc560-.Lc559
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc985:
	.long	.Lc988-.Lc987
.Lc987:
	.long	.Lc597
	.quad	.Lc562
	.quad	.Lc561-.Lc562
	.byte	2
	.byte	.Lc563-.Lc562
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc564-.Lc563
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc988:
	.long	.Lc991-.Lc990
.Lc990:
	.long	.Lc597
	.quad	.Lc566
	.quad	.Lc565-.Lc566
	.byte	2
	.byte	.Lc567-.Lc566
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc568-.Lc567
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc991:
	.long	.Lc994-.Lc993
.Lc993:
	.long	.Lc597
	.quad	.Lc570
	.quad	.Lc569-.Lc570
	.byte	2
	.byte	.Lc571-.Lc570
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc572-.Lc571
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc994:
	.long	.Lc997-.Lc996
.Lc996:
	.long	.Lc597
	.quad	.Lc574
	.quad	.Lc573-.Lc574
	.byte	2
	.byte	.Lc575-.Lc574
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc576-.Lc575
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc997:
	.long	.Lc1000-.Lc999
.Lc999:
	.long	.Lc597
	.quad	.Lc578
	.quad	.Lc577-.Lc578
	.byte	2
	.byte	.Lc579-.Lc578
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc580-.Lc579
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1000:
	.long	.Lc1003-.Lc1002
.Lc1002:
	.long	.Lc597
	.quad	.Lc582
	.quad	.Lc581-.Lc582
	.byte	2
	.byte	.Lc583-.Lc582
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc584-.Lc583
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1003:
	.long	.Lc1006-.Lc1005
.Lc1005:
	.long	.Lc597
	.quad	.Lc586
	.quad	.Lc585-.Lc586
	.byte	2
	.byte	.Lc587-.Lc586
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc588-.Lc587
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1006:
	.long	.Lc1009-.Lc1008
.Lc1008:
	.long	.Lc597
	.quad	.Lc590
	.quad	.Lc589-.Lc590
	.byte	2
	.byte	.Lc591-.Lc590
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc592-.Lc591
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1009:
	.long	.Lc1012-.Lc1011
.Lc1011:
	.long	.Lc597
	.quad	.Lc594
	.quad	.Lc593-.Lc594
	.byte	2
	.byte	.Lc595-.Lc594
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc596-.Lc595
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1012:
# End asmlist al_dwarf_frame
.section .note.GNU-stack,"",%progbits

