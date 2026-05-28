	.file "nextpas.core.contracts.pas"
# Begin asmlist al_procedures

.section .text.n_nextpas.core.contracts_$$_contractsrequire$boolean$ansistring,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.CONTRACTS_$$_CONTRACTSREQUIRE$BOOLEAN$ANSISTRING
	.type	NEXTPAS.CORE.CONTRACTS_$$_CONTRACTSREQUIRE$BOOLEAN$ANSISTRING,@function
NEXTPAS.CORE.CONTRACTS_$$_CONTRACTSREQUIRE$BOOLEAN$ANSISTRING:
.Lc2:
# [nextpas.core.contracts.pas]
# [18] begin
	pushq	%rbp
.Lc3:
	movq	%rsp,%rbp
.Lc4:
# Var aCondition located in register dil
	movq	%rsi,%rdx
# Var aMessage located in register rdx
# [20] if not aCondition then
	testb	%dil,%dil
	jne	.Lj6
.Lj7:
# [21] raise EInvalidArgument.Create(aMessage);
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EINVALIDARGUMENT,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj7,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj6:
.Lc5:
# [25] end;
	movq	%rbp,%rsp
.Lc6:
	popq	%rbp
	ret
.Lc1:

.section .text.n_nextpas.core.contracts_$$_contractsrequireassigned$boolean$ansistring,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.CONTRACTS_$$_CONTRACTSREQUIREASSIGNED$BOOLEAN$ANSISTRING
	.type	NEXTPAS.CORE.CONTRACTS_$$_CONTRACTSREQUIREASSIGNED$BOOLEAN$ANSISTRING,@function
NEXTPAS.CORE.CONTRACTS_$$_CONTRACTSREQUIREASSIGNED$BOOLEAN$ANSISTRING:
.Lc8:
# Temps allocated between rbp-120 and rbp+0
# [28] begin
	pushq	%rbp
.Lc9:
	movq	%rsp,%rbp
.Lc10:
	leaq	-128(%rsp),%rsp
	movq	%rbx,-120(%rbp)
	movq	%r12,-112(%rbp)
	movb	%dil,%bl
# Var aCondition located in register bl
	movq	%rsi,%r12
# Var aName located in register r12
	movq	$0,-104(%rbp)
	leaq	-24(%rbp),%rdx
	leaq	-88(%rbp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,-92(%rbp)
	testl	%eax,%eax
	jne	.Lj11
# [30] if not aCondition then
	testb	%bl,%bl
	jne	.Lj14
.Lj15:
# [31] raise EArgumentNil.Create(aName + ' is nil');
	leaq	-104(%rbp),%rdi
	call	fpc_ansistr_decr_ref
	movq	$.Ld1,%rdx
	leaq	-104(%rbp),%rdi
	xorl	%ecx,%ecx
	movq	%r12,%rsi
	call	fpc_ansistr_concat
	movq	-104(%rbp),%rdx
	movq	$VMT_$NEXTPAS.CORE.BASE_$$_EARGUMENTNIL,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj15,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj14:
.Lj11:
	call	fpc_popaddrstack
# [35] end;
	leaq	-104(%rbp),%rdi
	call	fpc_ansistr_decr_ref
	cmpl	$0,-92(%rbp)
	je	.Lj10
	call	fpc_reraise
	movl	$0,-92(%rbp)
	jmp	.Lj11
.Lj10:
	movq	-120(%rbp),%rbx
	movq	-112(%rbp),%r12
.Lc11:
	movq	%rbp,%rsp
.Lc12:
	popq	%rbp
	ret
.Lc7:
# End asmlist al_procedures
# Begin asmlist al_typedconsts

.section .rodata.n_.Ld1
	.balign 8
.Ld1$strlab:
	.short	0,1
	.long	-1
	.quad	7
.Ld1:
# [31] raise EArgumentNil.Create(aName + ' is nil');
	.ascii	" is nil\000"
.Le0:
	.size	.Ld1$strlab, .Le0 - .Ld1$strlab
# End asmlist al_typedconsts
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
.Lc17:
	.long	.Lc20-.Lc19
.Lc19:
	.long	.Lc13
	.quad	.Lc8
	.quad	.Lc7-.Lc8
	.byte	2
	.byte	.Lc9-.Lc8
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc10-.Lc9
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc11-.Lc10
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc12-.Lc11
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc20:
# End asmlist al_dwarf_frame
.section .note.GNU-stack,"",%progbits

