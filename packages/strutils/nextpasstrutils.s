	.file "nextpasstrutils.pas"
# Begin asmlist al_procedures

.section .text.n_nextpasstrutils_$$_lowercase$shortstring$$shortstring,"ax"
	.balign 16,0x90
.globl	NEXTPASSTRUTILS_$$_LOWERCASE$SHORTSTRING$$SHORTSTRING
	.type	NEXTPASSTRUTILS_$$_LOWERCASE$SHORTSTRING$$SHORTSTRING,@function
NEXTPASSTRUTILS_$$_LOWERCASE$SHORTSTRING$$SHORTSTRING:
.Lc2:
	pushq	%rbp
.Lc3:
	movq	%rsp,%rbp
.Lc4:
	leaq	-288(%rsp),%rsp
	movq	%rbx,-288(%rbp)
	movq	%rdi,-16(%rbp)
	movq	%rsi,-8(%rbp)
	movq	-16(%rbp),%rax
	movb	$0,(%rax)
	movq	-8(%rbp),%rax
	movzbl	(%rax),%ebx
	cmpl	$1,%ebx
	jge	.Lj5
	jmp	.Lj6
.Lj5:
	movl	$0,-20(%rbp)
	.p2align 4,,10
	.p2align 3
.Lj7:
	movl	-20(%rbp),%eax
	leal	1(%eax),%eax
	movl	%eax,-20(%rbp)
	movq	-8(%rbp),%rdx
	movzbl	-20(%rbp),%eax
	movb	(%rdx,%rax,1),%al
	movb	%al,-24(%rbp)
	cmpb	$65,-24(%rbp)
	jae	.Lj10
	jmp	.Lj11
.Lj10:
	cmpb	$90,-24(%rbp)
	jbe	.Lj12
	jmp	.Lj11
.Lj12:
	movzbl	-24(%rbp),%eax
	leal	32(%eax),%eax
	movzbl	%al,%eax
	shlq	$8,%rax
	orq	$1,%rax
	movw	%ax,-280(%rbp)
	leaq	-280(%rbp),%rcx
	movq	-16(%rbp),%rdx
	movq	-16(%rbp),%rdi
	movq	$255,%rsi
	call	fpc_shortstr_concat
	jmp	.Lj13
	.p2align 4,,10
	.p2align 3
.Lj11:
	movzbl	-24(%rbp),%eax
	shlq	$8,%rax
	orq	$1,%rax
	movw	%ax,-280(%rbp)
	leaq	-280(%rbp),%rcx
	movq	-16(%rbp),%rdx
	movq	-16(%rbp),%rdi
	movq	$255,%rsi
	call	fpc_shortstr_concat
.Lj13:
	cmpl	-20(%rbp),%ebx
	jle	.Lj9
	jmp	.Lj7
.Lj9:
.Lj6:
	movq	-288(%rbp),%rbx
.Lc5:
	movq	%rbp,%rsp
.Lc6:
	popq	%rbp
	ret
.Lc1:

.section .text.n_nextpasstrutils_$$_uppercase$shortstring$$shortstring,"ax"
	.balign 16,0x90
.globl	NEXTPASSTRUTILS_$$_UPPERCASE$SHORTSTRING$$SHORTSTRING
	.type	NEXTPASSTRUTILS_$$_UPPERCASE$SHORTSTRING$$SHORTSTRING,@function
NEXTPASSTRUTILS_$$_UPPERCASE$SHORTSTRING$$SHORTSTRING:
.Lc8:
	pushq	%rbp
.Lc9:
	movq	%rsp,%rbp
.Lc10:
	leaq	-288(%rsp),%rsp
	movq	%rbx,-288(%rbp)
	movq	%rdi,-16(%rbp)
	movq	%rsi,-8(%rbp)
	movq	-16(%rbp),%rax
	movb	$0,(%rax)
	movq	-8(%rbp),%rax
	movzbl	(%rax),%ebx
	cmpl	$1,%ebx
	jge	.Lj16
	jmp	.Lj17
.Lj16:
	movl	$0,-20(%rbp)
	.p2align 4,,10
	.p2align 3
.Lj18:
	movl	-20(%rbp),%eax
	leal	1(%eax),%eax
	movl	%eax,-20(%rbp)
	movq	-8(%rbp),%rdx
	movzbl	-20(%rbp),%eax
	movb	(%rdx,%rax,1),%al
	movb	%al,-24(%rbp)
	cmpb	$97,-24(%rbp)
	jae	.Lj21
	jmp	.Lj22
.Lj21:
	cmpb	$122,-24(%rbp)
	jbe	.Lj23
	jmp	.Lj22
.Lj23:
	movzbl	-24(%rbp),%eax
	subl	$32,%eax
	movzbl	%al,%eax
	shlq	$8,%rax
	orq	$1,%rax
	movw	%ax,-280(%rbp)
	leaq	-280(%rbp),%rcx
	movq	-16(%rbp),%rdx
	movq	-16(%rbp),%rdi
	movq	$255,%rsi
	call	fpc_shortstr_concat
	jmp	.Lj24
	.p2align 4,,10
	.p2align 3
.Lj22:
	movzbl	-24(%rbp),%eax
	shlq	$8,%rax
	orq	$1,%rax
	movw	%ax,-280(%rbp)
	leaq	-280(%rbp),%rcx
	movq	-16(%rbp),%rdx
	movq	-16(%rbp),%rdi
	movq	$255,%rsi
	call	fpc_shortstr_concat
.Lj24:
	cmpl	-20(%rbp),%ebx
	jle	.Lj20
	jmp	.Lj18
.Lj20:
.Lj17:
	movq	-288(%rbp),%rbx
.Lc11:
	movq	%rbp,%rsp
.Lc12:
	popq	%rbp
	ret
.Lc7:

.section .text.n_nextpasstrutils_$$_trimleft$shortstring$$shortstring,"ax"
	.balign 16,0x90
.globl	NEXTPASSTRUTILS_$$_TRIMLEFT$SHORTSTRING$$SHORTSTRING
	.type	NEXTPASSTRUTILS_$$_TRIMLEFT$SHORTSTRING$$SHORTSTRING,@function
NEXTPASSTRUTILS_$$_TRIMLEFT$SHORTSTRING$$SHORTSTRING:
.Lc14:
	pushq	%rbp
.Lc15:
	movq	%rsp,%rbp
.Lc16:
	leaq	-288(%rsp),%rsp
	movq	%rdi,-16(%rbp)
	movq	%rsi,-8(%rbp)
	movl	$1,-20(%rbp)
	jmp	.Lj28
	.p2align 4,,10
	.p2align 3
.Lj27:
	addl	$1,-20(%rbp)
.Lj28:
	movq	-8(%rbp),%rax
	movzbl	(%rax),%eax
	movslq	-20(%rbp),%rdx
	cmpq	%rdx,%rax
	jge	.Lj30
	jmp	.Lj31
.Lj30:
	movq	-8(%rbp),%rax
	movzbl	-20(%rbp),%edx
	cmpb	$32,(%rax,%rdx,1)
	je	.Lj33
	jmp	.Lj34
.Lj34:
	movq	-8(%rbp),%rax
	movzbl	-20(%rbp),%edx
	cmpb	$9,(%rax,%rdx,1)
	je	.Lj33
	jmp	.Lj35
.Lj33:
	jmp	.Lj32
.Lj35:
	jmp	.Lj31
.Lj32:
	jmp	.Lj27
.Lj31:
	jmp	.Lj29
.Lj29:
	movq	-8(%rbp),%rax
	movzbl	(%rax),%eax
	movslq	-20(%rbp),%rdx
	cmpq	%rdx,%rax
	jl	.Lj36
	jmp	.Lj37
.Lj36:
	movq	-16(%rbp),%rax
	movb	$0,(%rax)
	jmp	.Lj25
	.p2align 4,,10
	.p2align 3
.Lj37:
	movq	-16(%rbp),%rax
	movb	$0,(%rax)
	jmp	.Lj39
	.p2align 4,,10
	.p2align 3
.Lj38:
	movq	-8(%rbp),%rax
	movzbl	-20(%rbp),%edx
	movzbl	(%rax,%rdx,1),%eax
	shlq	$8,%rax
	orq	$1,%rax
	movw	%ax,-276(%rbp)
	leaq	-276(%rbp),%rcx
	movq	-16(%rbp),%rdx
	movq	-16(%rbp),%rdi
	movq	$255,%rsi
	call	fpc_shortstr_concat
	addl	$1,-20(%rbp)
.Lj39:
	movq	-8(%rbp),%rax
	movzbl	(%rax),%edx
	movslq	-20(%rbp),%rax
	cmpq	%rax,%rdx
	jge	.Lj38
	jmp	.Lj40
.Lj40:
.Lj25:
.Lc17:
	movq	%rbp,%rsp
.Lc18:
	popq	%rbp
	ret
.Lc13:
.Le0:
	.size	NEXTPASSTRUTILS_$$_TRIMLEFT$SHORTSTRING$$SHORTSTRING, .Le0 - NEXTPASSTRUTILS_$$_TRIMLEFT$SHORTSTRING$$SHORTSTRING

.section .text.n_nextpasstrutils_$$_trimright$shortstring$$shortstring,"ax"
	.balign 16,0x90
.globl	NEXTPASSTRUTILS_$$_TRIMRIGHT$SHORTSTRING$$SHORTSTRING
	.type	NEXTPASSTRUTILS_$$_TRIMRIGHT$SHORTSTRING$$SHORTSTRING,@function
NEXTPASSTRUTILS_$$_TRIMRIGHT$SHORTSTRING$$SHORTSTRING:
.Lc20:
	pushq	%rbp
.Lc21:
	movq	%rsp,%rbp
.Lc22:
	leaq	-288(%rsp),%rsp
	movq	%rbx,-288(%rbp)
	movq	%rdi,-16(%rbp)
	movq	%rsi,-8(%rbp)
	movq	-8(%rbp),%rax
	movzbl	(%rax),%eax
	movl	%eax,-20(%rbp)
	jmp	.Lj44
	.p2align 4,,10
	.p2align 3
.Lj43:
	subl	$1,-20(%rbp)
.Lj44:
	cmpl	$1,-20(%rbp)
	jge	.Lj46
	jmp	.Lj47
.Lj46:
	movq	-8(%rbp),%rax
	movzbl	-20(%rbp),%edx
	cmpb	$32,(%rax,%rdx,1)
	je	.Lj49
	jmp	.Lj50
.Lj50:
	movq	-8(%rbp),%rax
	movzbl	-20(%rbp),%edx
	cmpb	$9,(%rax,%rdx,1)
	je	.Lj49
	jmp	.Lj51
.Lj49:
	jmp	.Lj48
.Lj51:
	jmp	.Lj47
.Lj48:
	jmp	.Lj43
.Lj47:
	jmp	.Lj45
.Lj45:
	cmpl	$1,-20(%rbp)
	jl	.Lj52
	jmp	.Lj53
.Lj52:
	movq	-16(%rbp),%rax
	movb	$0,(%rax)
	jmp	.Lj41
	.p2align 4,,10
	.p2align 3
.Lj53:
	movq	-16(%rbp),%rax
	movb	$0,(%rax)
	movl	-20(%rbp),%ebx
	cmpl	$1,%ebx
	jge	.Lj54
	jmp	.Lj55
.Lj54:
	movl	$0,-24(%rbp)
	.p2align 4,,10
	.p2align 3
.Lj56:
	movl	-24(%rbp),%eax
	leal	1(%eax),%eax
	movl	%eax,-24(%rbp)
	movq	-8(%rbp),%rdx
	movzbl	-24(%rbp),%eax
	movzbl	(%rdx,%rax,1),%eax
	shlq	$8,%rax
	orq	$1,%rax
	movw	%ax,-280(%rbp)
	leaq	-280(%rbp),%rcx
	movq	-16(%rbp),%rdx
	movq	-16(%rbp),%rdi
	movq	$255,%rsi
	call	fpc_shortstr_concat
	cmpl	-24(%rbp),%ebx
	jle	.Lj58
	jmp	.Lj56
.Lj58:
.Lj55:
.Lj41:
	movq	-288(%rbp),%rbx
.Lc23:
	movq	%rbp,%rsp
.Lc24:
	popq	%rbp
	ret
.Lc19:
.Le1:
	.size	NEXTPASSTRUTILS_$$_TRIMRIGHT$SHORTSTRING$$SHORTSTRING, .Le1 - NEXTPASSTRUTILS_$$_TRIMRIGHT$SHORTSTRING$$SHORTSTRING

.section .text.n_nextpasstrutils_$$_trim$shortstring$$shortstring,"ax"
	.balign 16,0x90
.globl	NEXTPASSTRUTILS_$$_TRIM$SHORTSTRING$$SHORTSTRING
	.type	NEXTPASSTRUTILS_$$_TRIM$SHORTSTRING$$SHORTSTRING,@function
NEXTPASSTRUTILS_$$_TRIM$SHORTSTRING$$SHORTSTRING:
.Lc26:
	pushq	%rbp
.Lc27:
	movq	%rsp,%rbp
.Lc28:
	leaq	-272(%rsp),%rsp
	movq	%rdi,-16(%rbp)
	movq	%rsi,-8(%rbp)
	movq	-8(%rbp),%rsi
	leaq	-272(%rbp),%rdi
	call	NEXTPASSTRUTILS_$$_TRIMLEFT$SHORTSTRING$$SHORTSTRING
	leaq	-272(%rbp),%rsi
	movq	-16(%rbp),%rdi
	call	NEXTPASSTRUTILS_$$_TRIMRIGHT$SHORTSTRING$$SHORTSTRING
.Lc29:
	movq	%rbp,%rsp
.Lc30:
	popq	%rbp
	ret
.Lc25:

.section .text.n_nextpasstrutils_$$_pos$shortstring$shortstring$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPASSTRUTILS_$$_POS$SHORTSTRING$SHORTSTRING$$LONGINT
	.type	NEXTPASSTRUTILS_$$_POS$SHORTSTRING$SHORTSTRING$$LONGINT,@function
NEXTPASSTRUTILS_$$_POS$SHORTSTRING$SHORTSTRING$$LONGINT:
.Lc32:
	pushq	%rbp
.Lc33:
	movq	%rsp,%rbp
.Lc34:
	leaq	-48(%rsp),%rsp
	movq	%rdi,-8(%rbp)
	movq	%rsi,-16(%rbp)
	movq	-16(%rbp),%rax
	movzbl	(%rax),%eax
	movl	%eax,-32(%rbp)
	movq	-8(%rbp),%rax
	movzbl	(%rax),%eax
	movl	%eax,-36(%rbp)
	cmpl	$0,-36(%rbp)
	je	.Lj63
	jmp	.Lj64
.Lj63:
	movl	$1,-20(%rbp)
	jmp	.Lj61
	.p2align 4,,10
	.p2align 3
.Lj64:
	movl	-36(%rbp),%eax
	cmpl	-32(%rbp),%eax
	jg	.Lj65
	jmp	.Lj66
.Lj65:
	movl	$0,-20(%rbp)
	jmp	.Lj61
	.p2align 4,,10
	.p2align 3
.Lj66:
	movl	-32(%rbp),%eax
	subl	-36(%rbp),%eax
	leal	1(%eax),%eax
	cmpl	$1,%eax
	jge	.Lj67
	jmp	.Lj68
.Lj67:
	movl	$0,-24(%rbp)
	.p2align 4,,10
	.p2align 3
.Lj69:
	movl	-24(%rbp),%edx
	leal	1(%edx),%edx
	movl	%edx,-24(%rbp)
	movb	$1,-40(%rbp)
	movl	-36(%rbp),%ecx
	cmpl	$1,%ecx
	jge	.Lj72
	jmp	.Lj73
.Lj72:
	movl	$0,-28(%rbp)
	.p2align 4,,10
	.p2align 3
.Lj74:
	movl	-28(%rbp),%edx
	leal	1(%edx),%edx
	movl	%edx,-28(%rbp)
	movq	-16(%rbp),%rsi
	movl	-24(%rbp),%edi
	movl	-28(%rbp),%edx
	leal	(%edi,%edx),%edx
	subl	$1,%edx
	movzbl	%dl,%edx
	movq	-8(%rbp),%r8
	movzbl	-28(%rbp),%edi
	movb	(%rsi,%rdx,1),%dl
	cmpb	(%r8,%rdi,1),%dl
	jne	.Lj77
	jmp	.Lj78
.Lj77:
	movb	$0,-40(%rbp)
	jmp	.Lj76
	.p2align 4,,10
	.p2align 3
.Lj78:
	cmpl	-28(%rbp),%ecx
	jle	.Lj76
	jmp	.Lj74
.Lj76:
.Lj73:
	cmpb	$0,-40(%rbp)
	jne	.Lj79
	jmp	.Lj80
.Lj79:
	movl	-24(%rbp),%edx
	movl	%edx,-20(%rbp)
	jmp	.Lj61
	.p2align 4,,10
	.p2align 3
.Lj80:
	cmpl	-24(%rbp),%eax
	jle	.Lj71
	jmp	.Lj69
.Lj71:
.Lj68:
	movl	$0,-20(%rbp)
.Lj61:
	movl	-20(%rbp),%eax
.Lc35:
	movq	%rbp,%rsp
.Lc36:
	popq	%rbp
	ret
.Lc31:
.Le2:
	.size	NEXTPASSTRUTILS_$$_POS$SHORTSTRING$SHORTSTRING$$LONGINT, .Le2 - NEXTPASSTRUTILS_$$_POS$SHORTSTRING$SHORTSTRING$$LONGINT

.section .text.n_nextpasstrutils_$$_charequalignorecase$ansichar$ansichar$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPASSTRUTILS_$$_CHAREQUALIGNORECASE$ANSICHAR$ANSICHAR$$BOOLEAN
	.hidden NEXTPASSTRUTILS_$$_CHAREQUALIGNORECASE$ANSICHAR$ANSICHAR$$BOOLEAN
	.type	NEXTPASSTRUTILS_$$_CHAREQUALIGNORECASE$ANSICHAR$ANSICHAR$$BOOLEAN,@function
NEXTPASSTRUTILS_$$_CHAREQUALIGNORECASE$ANSICHAR$ANSICHAR$$BOOLEAN:
.Lc38:
	pushq	%rbp
.Lc39:
	movq	%rsp,%rbp
.Lc40:
	leaq	-32(%rsp),%rsp
	movb	%dil,-8(%rbp)
	movb	%sil,-16(%rbp)
	cmpb	$65,-8(%rbp)
	jae	.Lj83
	jmp	.Lj84
.Lj83:
	cmpb	$90,-8(%rbp)
	jbe	.Lj85
	jmp	.Lj84
.Lj85:
	movzbl	-8(%rbp),%eax
	leal	32(%eax),%eax
	movb	%al,-8(%rbp)
.Lj84:
	cmpb	$65,-16(%rbp)
	jae	.Lj86
	jmp	.Lj87
.Lj86:
	cmpb	$90,-16(%rbp)
	jbe	.Lj88
	jmp	.Lj87
.Lj88:
	movzbl	-16(%rbp),%eax
	leal	32(%eax),%eax
	movb	%al,-16(%rbp)
.Lj87:
	movb	-8(%rbp),%al
	cmpb	-16(%rbp),%al
	seteb	-20(%rbp)
	movb	-20(%rbp),%al
.Lc41:
	movq	%rbp,%rsp
.Lc42:
	popq	%rbp
	ret
.Lc37:
.Le3:
	.size	NEXTPASSTRUTILS_$$_CHAREQUALIGNORECASE$ANSICHAR$ANSICHAR$$BOOLEAN, .Le3 - NEXTPASSTRUTILS_$$_CHAREQUALIGNORECASE$ANSICHAR$ANSICHAR$$BOOLEAN

.section .text.n_nextpasstrutils_$$_stringreplace$shortstring$shortstring$shortstring$treplaceflags$$shortstring,"ax"
	.balign 16,0x90
.globl	NEXTPASSTRUTILS_$$_STRINGREPLACE$SHORTSTRING$SHORTSTRING$SHORTSTRING$TREPLACEFLAGS$$SHORTSTRING
	.type	NEXTPASSTRUTILS_$$_STRINGREPLACE$SHORTSTRING$SHORTSTRING$SHORTSTRING$TREPLACEFLAGS$$SHORTSTRING,@function
NEXTPASSTRUTILS_$$_STRINGREPLACE$SHORTSTRING$SHORTSTRING$SHORTSTRING$TREPLACEFLAGS$$SHORTSTRING:
.Lc44:
	pushq	%rbp
.Lc45:
	movq	%rsp,%rbp
.Lc46:
	leaq	-336(%rsp),%rsp
	movq	%rbx,-328(%rbp)
	movq	%rdi,-40(%rbp)
	movq	%rsi,-8(%rbp)
	movq	%rdx,-16(%rbp)
	movq	%rcx,-24(%rbp)
	movl	%r8d,-32(%rbp)
	movq	-8(%rbp),%rax
	movzbl	(%rax),%eax
	movl	%eax,-48(%rbp)
	movq	-16(%rbp),%rax
	movzbl	(%rax),%eax
	movl	%eax,-52(%rbp)
	cmpl	$0,-52(%rbp)
	je	.Lj91
	jmp	.Lj92
.Lj92:
	movl	-52(%rbp),%eax
	cmpl	-48(%rbp),%eax
	jg	.Lj91
	jmp	.Lj93
.Lj91:
	movq	-8(%rbp),%rdx
	movq	-40(%rbp),%rdi
	movq	$255,%rsi
	call	fpc_shortstr_to_shortstr
	jmp	.Lj89
	.p2align 4,,10
	.p2align 3
.Lj93:
	movq	-40(%rbp),%rax
	movb	$0,(%rax)
	movl	$1,-44(%rbp)
	jmp	.Lj95
	.p2align 4,,10
	.p2align 3
.Lj94:
	movslq	-44(%rbp),%rax
	movslq	-52(%rbp),%rdx
	leaq	(%rax,%rdx),%rax
	subq	$1,%rax
	movslq	-48(%rbp),%rdx
	cmpq	%rdx,%rax
	jg	.Lj97
	jmp	.Lj98
.Lj97:
	movb	$0,-56(%rbp)
	jmp	.Lj99
	.p2align 4,,10
	.p2align 3
.Lj98:
	testl	$2,-32(%rbp)
	jne	.Lj100
	jmp	.Lj101
.Lj100:
	movb	$1,-56(%rbp)
	movl	-52(%rbp),%ebx
	cmpl	$1,%ebx
	jge	.Lj102
	jmp	.Lj103
.Lj102:
	movl	$0,-60(%rbp)
	.p2align 4,,10
	.p2align 3
.Lj104:
	movl	-60(%rbp),%eax
	leal	1(%eax),%eax
	movl	%eax,-60(%rbp)
	movq	-8(%rbp),%rdx
	movl	-44(%rbp),%ecx
	movl	-60(%rbp),%eax
	leal	(%ecx,%eax),%eax
	subl	$1,%eax
	movzbl	%al,%eax
	movzbl	(%rdx,%rax,1),%edi
	movq	-16(%rbp),%rax
	movzbl	-60(%rbp),%edx
	movzbl	(%rax,%rdx,1),%esi
	call	NEXTPASSTRUTILS_$$_CHAREQUALIGNORECASE$ANSICHAR$ANSICHAR$$BOOLEAN
	testb	%al,%al
	je	.Lj107
	jmp	.Lj108
.Lj107:
	movb	$0,-56(%rbp)
	jmp	.Lj106
	.p2align 4,,10
	.p2align 3
.Lj108:
	cmpl	-60(%rbp),%ebx
	jle	.Lj106
	jmp	.Lj104
.Lj106:
.Lj103:
	jmp	.Lj109
	.p2align 4,,10
	.p2align 3
.Lj101:
	movb	$1,-56(%rbp)
	movl	-52(%rbp),%edx
	cmpl	$1,%edx
	jge	.Lj110
	jmp	.Lj111
.Lj110:
	movl	$0,-60(%rbp)
	.p2align 4,,10
	.p2align 3
.Lj112:
	movl	-60(%rbp),%eax
	leal	1(%eax),%eax
	movl	%eax,-60(%rbp)
	movq	-8(%rbp),%rcx
	movl	-44(%rbp),%eax
	movl	-60(%rbp),%esi
	leal	(%eax,%esi),%eax
	subl	$1,%eax
	movzbl	%al,%eax
	movq	-16(%rbp),%rsi
	movzbl	-60(%rbp),%edi
	movb	(%rcx,%rax,1),%al
	cmpb	(%rsi,%rdi,1),%al
	jne	.Lj115
	jmp	.Lj116
.Lj115:
	movb	$0,-56(%rbp)
	jmp	.Lj114
	.p2align 4,,10
	.p2align 3
.Lj116:
	cmpl	-60(%rbp),%edx
	jle	.Lj114
	jmp	.Lj112
.Lj114:
.Lj111:
.Lj109:
.Lj99:
	cmpb	$0,-56(%rbp)
	jne	.Lj117
	jmp	.Lj118
.Lj117:
	movq	-24(%rbp),%rcx
	movq	-40(%rbp),%rdx
	movq	-40(%rbp),%rdi
	movq	$255,%rsi
	call	fpc_shortstr_concat
	movl	-44(%rbp),%eax
	movl	-52(%rbp),%edx
	leal	(%eax,%edx),%eax
	movl	%eax,-44(%rbp)
	testl	$1,-32(%rbp)
	je	.Lj119
	jmp	.Lj120
.Lj119:
	jmp	.Lj122
	.p2align 4,,10
	.p2align 3
.Lj121:
	movq	-8(%rbp),%rax
	movzbl	-44(%rbp),%edx
	movzbl	(%rax,%rdx,1),%eax
	shlq	$8,%rax
	orq	$1,%rax
	movw	%ax,-316(%rbp)
	leaq	-316(%rbp),%rcx
	movq	-40(%rbp),%rdx
	movq	-40(%rbp),%rdi
	movq	$255,%rsi
	call	fpc_shortstr_concat
	addl	$1,-44(%rbp)
.Lj122:
	movl	-44(%rbp),%eax
	cmpl	-48(%rbp),%eax
	jle	.Lj121
	jmp	.Lj123
.Lj123:
	jmp	.Lj89
	.p2align 4,,10
	.p2align 3
.Lj120:
	jmp	.Lj124
	.p2align 4,,10
	.p2align 3
.Lj118:
	movq	-8(%rbp),%rax
	movzbl	-44(%rbp),%edx
	movzbl	(%rax,%rdx,1),%eax
	shlq	$8,%rax
	orq	$1,%rax
	movw	%ax,-316(%rbp)
	leaq	-316(%rbp),%rcx
	movq	-40(%rbp),%rdx
	movq	-40(%rbp),%rdi
	movq	$255,%rsi
	call	fpc_shortstr_concat
	addl	$1,-44(%rbp)
.Lj124:
.Lj95:
	movl	-44(%rbp),%eax
	cmpl	-48(%rbp),%eax
	jle	.Lj94
	jmp	.Lj96
.Lj96:
.Lj89:
	movq	-328(%rbp),%rbx
.Lc47:
	movq	%rbp,%rsp
.Lc48:
	popq	%rbp
	ret
.Lc43:

.section .text.n_nextpasstrutils_$$_contains$shortstring$shortstring$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPASSTRUTILS_$$_CONTAINS$SHORTSTRING$SHORTSTRING$$BOOLEAN
	.type	NEXTPASSTRUTILS_$$_CONTAINS$SHORTSTRING$SHORTSTRING$$BOOLEAN,@function
NEXTPASSTRUTILS_$$_CONTAINS$SHORTSTRING$SHORTSTRING$$BOOLEAN:
.Lc50:
	pushq	%rbp
.Lc51:
	movq	%rsp,%rbp
.Lc52:
	leaq	-32(%rsp),%rsp
	movq	%rdi,-8(%rbp)
	movq	%rsi,-16(%rbp)
	movq	-8(%rbp),%rsi
	movq	-16(%rbp),%rdi
	call	NEXTPASSTRUTILS_$$_POS$SHORTSTRING$SHORTSTRING$$LONGINT
	cmpl	$0,%eax
	setgb	-20(%rbp)
	movb	-20(%rbp),%al
.Lc53:
	movq	%rbp,%rsp
.Lc54:
	popq	%rbp
	ret
.Lc49:

.section .text.n_nextpasstrutils_$$_startswith$shortstring$shortstring$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPASSTRUTILS_$$_STARTSWITH$SHORTSTRING$SHORTSTRING$$BOOLEAN
	.type	NEXTPASSTRUTILS_$$_STARTSWITH$SHORTSTRING$SHORTSTRING$$BOOLEAN,@function
NEXTPASSTRUTILS_$$_STARTSWITH$SHORTSTRING$SHORTSTRING$$BOOLEAN:
.Lc56:
	pushq	%rbp
.Lc57:
	movq	%rsp,%rbp
.Lc58:
	leaq	-32(%rsp),%rsp
	movq	%rdi,-8(%rbp)
	movq	%rsi,-16(%rbp)
	movq	-16(%rbp),%rdx
	movq	-8(%rbp),%rax
	movb	(%rdx),%dl
	cmpb	(%rax),%dl
	ja	.Lj129
	jmp	.Lj130
.Lj129:
	movb	$0,-20(%rbp)
	jmp	.Lj127
	.p2align 4,,10
	.p2align 3
.Lj130:
	movq	-16(%rbp),%rax
	movzbl	(%rax),%eax
	cmpl	$1,%eax
	jge	.Lj131
	jmp	.Lj132
.Lj131:
	movl	$0,-24(%rbp)
	.p2align 4,,10
	.p2align 3
.Lj133:
	movl	-24(%rbp),%edx
	leal	1(%edx),%edx
	movl	%edx,-24(%rbp)
	movq	-8(%rbp),%rdi
	movzbl	-24(%rbp),%esi
	movq	-16(%rbp),%rcx
	movzbl	-24(%rbp),%edx
	movb	(%rdi,%rsi,1),%sil
	cmpb	(%rcx,%rdx,1),%sil
	jne	.Lj136
	jmp	.Lj137
.Lj136:
	movb	$0,-20(%rbp)
	jmp	.Lj127
	.p2align 4,,10
	.p2align 3
.Lj137:
	cmpl	-24(%rbp),%eax
	jle	.Lj135
	jmp	.Lj133
.Lj135:
.Lj132:
	movb	$1,-20(%rbp)
.Lj127:
	movb	-20(%rbp),%al
.Lc59:
	movq	%rbp,%rsp
.Lc60:
	popq	%rbp
	ret
.Lc55:

.section .text.n_nextpasstrutils_$$_endswith$shortstring$shortstring$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPASSTRUTILS_$$_ENDSWITH$SHORTSTRING$SHORTSTRING$$BOOLEAN
	.type	NEXTPASSTRUTILS_$$_ENDSWITH$SHORTSTRING$SHORTSTRING$$BOOLEAN,@function
NEXTPASSTRUTILS_$$_ENDSWITH$SHORTSTRING$SHORTSTRING$$BOOLEAN:
.Lc62:
	pushq	%rbp
.Lc63:
	movq	%rsp,%rbp
.Lc64:
	leaq	-32(%rsp),%rsp
	movq	%rdi,-8(%rbp)
	movq	%rsi,-16(%rbp)
	movq	-16(%rbp),%rdx
	movq	-8(%rbp),%rax
	movb	(%rdx),%dl
	cmpb	(%rax),%dl
	ja	.Lj140
	jmp	.Lj141
.Lj140:
	movb	$0,-20(%rbp)
	jmp	.Lj138
	.p2align 4,,10
	.p2align 3
.Lj141:
	movq	-8(%rbp),%rax
	movzbl	(%rax),%eax
	movq	-16(%rbp),%rdx
	movzbl	(%rdx),%edx
	subl	%edx,%eax
	movl	%eax,-24(%rbp)
	movq	-16(%rbp),%rax
	movzbl	(%rax),%eax
	cmpl	$1,%eax
	jge	.Lj142
	jmp	.Lj143
.Lj142:
	movl	$0,-28(%rbp)
	.p2align 4,,10
	.p2align 3
.Lj144:
	movl	-28(%rbp),%edx
	leal	1(%edx),%edx
	movl	%edx,-28(%rbp)
	movq	-8(%rbp),%rcx
	movl	-24(%rbp),%edx
	movl	-28(%rbp),%esi
	leal	(%edx,%esi),%edx
	movzbl	%dl,%edx
	movq	-16(%rbp),%rsi
	movzbl	-28(%rbp),%edi
	movb	(%rcx,%rdx,1),%dl
	cmpb	(%rsi,%rdi,1),%dl
	jne	.Lj147
	jmp	.Lj148
.Lj147:
	movb	$0,-20(%rbp)
	jmp	.Lj138
	.p2align 4,,10
	.p2align 3
.Lj148:
	cmpl	-28(%rbp),%eax
	jle	.Lj146
	jmp	.Lj144
.Lj146:
.Lj143:
	movb	$1,-20(%rbp)
.Lj138:
	movb	-20(%rbp),%al
.Lc65:
	movq	%rbp,%rsp
.Lc66:
	popq	%rbp
	ret
.Lc61:

.section .text.n_nextpasstrutils_$$_split$shortstring$shortstring$$tstringarray,"ax"
	.balign 16,0x90
.globl	NEXTPASSTRUTILS_$$_SPLIT$SHORTSTRING$SHORTSTRING$$TSTRINGARRAY
	.type	NEXTPASSTRUTILS_$$_SPLIT$SHORTSTRING$SHORTSTRING$$TSTRINGARRAY,@function
NEXTPASSTRUTILS_$$_SPLIT$SHORTSTRING$SHORTSTRING$$TSTRINGARRAY:
.Lc68:
	pushq	%rbp
.Lc69:
	movq	%rsp,%rbp
.Lc70:
	leaq	-336(%rsp),%rsp
	movq	%rbx,-336(%rbp)
	movq	%rdi,-24(%rbp)
	movq	%rsi,-8(%rbp)
	movq	%rdx,-16(%rbp)
	movq	-8(%rbp),%rax
	movzbl	(%rax),%eax
	movl	%eax,-44(%rbp)
	movq	-16(%rbp),%rax
	movzbl	(%rax),%eax
	movl	%eax,-48(%rbp)
	cmpl	$0,-44(%rbp)
	je	.Lj151
	jmp	.Lj152
.Lj151:
	movq	$RTTI_$NEXTPASSTRUTILS_$$_TSTRINGARRAY,%rsi
	movq	-24(%rbp),%rdi
	call	fpc_dynarray_clear
	jmp	.Lj149
	.p2align 4,,10
	.p2align 3
.Lj152:
	cmpl	$0,-48(%rbp)
	je	.Lj153
	jmp	.Lj154
.Lj153:
	movq	$1,-72(%rbp)
	leaq	-72(%rbp),%rcx
	movq	$RTTI_$NEXTPASSTRUTILS_$$_TSTRINGARRAY,%rsi
	movq	-24(%rbp),%rdi
	movq	$1,%rdx
	call	fpc_dynarray_setlength
	movq	-24(%rbp),%rax
	movq	(%rax),%rdi
	movq	-8(%rbp),%rdx
	movq	$255,%rsi
	call	fpc_shortstr_to_shortstr
	jmp	.Lj149
	.p2align 4,,10
	.p2align 3
.Lj154:
	movl	$1,-28(%rbp)
	movl	$1,-32(%rbp)
	jmp	.Lj156
	.p2align 4,,10
	.p2align 3
.Lj155:
	movb	$1,-52(%rbp)
	movl	-48(%rbp),%edx
	cmpl	$1,%edx
	jge	.Lj158
	jmp	.Lj159
.Lj158:
	movl	$0,-36(%rbp)
	.p2align 4,,10
	.p2align 3
.Lj160:
	movl	-36(%rbp),%eax
	leal	1(%eax),%eax
	movl	%eax,-36(%rbp)
	movq	-8(%rbp),%rcx
	movl	-32(%rbp),%esi
	movl	-36(%rbp),%eax
	leal	(%esi,%eax),%eax
	subl	$1,%eax
	movzbl	%al,%eax
	movq	-16(%rbp),%rdi
	movzbl	-36(%rbp),%esi
	movb	(%rcx,%rax,1),%al
	cmpb	(%rdi,%rsi,1),%al
	jne	.Lj163
	jmp	.Lj164
.Lj163:
	movb	$0,-52(%rbp)
	jmp	.Lj162
	.p2align 4,,10
	.p2align 3
.Lj164:
	cmpl	-36(%rbp),%edx
	jle	.Lj162
	jmp	.Lj160
.Lj162:
.Lj159:
	cmpb	$0,-52(%rbp)
	jne	.Lj165
	jmp	.Lj166
.Lj165:
	addl	$1,-28(%rbp)
	movl	-32(%rbp),%edx
	movl	-48(%rbp),%eax
	leal	(%edx,%eax),%eax
	movl	%eax,-32(%rbp)
	jmp	.Lj167
	.p2align 4,,10
	.p2align 3
.Lj166:
	addl	$1,-32(%rbp)
.Lj167:
.Lj156:
	movslq	-44(%rbp),%rdx
	movslq	-48(%rbp),%rax
	subq	%rax,%rdx
	leaq	1(%rdx),%rax
	movslq	-32(%rbp),%rdx
	cmpq	%rdx,%rax
	jge	.Lj155
	jmp	.Lj157
.Lj157:
	movslq	-28(%rbp),%rax
	movq	%rax,-72(%rbp)
	leaq	-72(%rbp),%rcx
	movq	$RTTI_$NEXTPASSTRUTILS_$$_TSTRINGARRAY,%rsi
	movq	-24(%rbp),%rdi
	movq	$1,%rdx
	call	fpc_dynarray_setlength
	movl	$1,-40(%rbp)
	movl	$1,-32(%rbp)
	movl	$0,-60(%rbp)
	jmp	.Lj169
	.p2align 4,,10
	.p2align 3
.Lj168:
	movslq	-44(%rbp),%rax
	movslq	-48(%rbp),%rdx
	subq	%rdx,%rax
	leaq	1(%rax),%rax
	movslq	-32(%rbp),%rdx
	cmpq	%rdx,%rax
	jge	.Lj171
	jmp	.Lj172
.Lj171:
	cmpl	$0,-48(%rbp)
	jg	.Lj173
	jmp	.Lj172
.Lj173:
	movb	$1,-52(%rbp)
	movl	-48(%rbp),%edx
	cmpl	$1,%edx
	jge	.Lj174
	jmp	.Lj175
.Lj174:
	movl	$0,-36(%rbp)
	.p2align 4,,10
	.p2align 3
.Lj176:
	movl	-36(%rbp),%eax
	leal	1(%eax),%eax
	movl	%eax,-36(%rbp)
	movq	-8(%rbp),%rcx
	movl	-32(%rbp),%eax
	movl	-36(%rbp),%esi
	leal	(%eax,%esi),%eax
	subl	$1,%eax
	movzbl	%al,%eax
	movq	-16(%rbp),%rsi
	movzbl	-36(%rbp),%edi
	movb	(%rcx,%rax,1),%al
	cmpb	(%rsi,%rdi,1),%al
	jne	.Lj179
	jmp	.Lj180
.Lj179:
	movb	$0,-52(%rbp)
	jmp	.Lj178
	.p2align 4,,10
	.p2align 3
.Lj180:
	cmpl	-36(%rbp),%edx
	jle	.Lj178
	jmp	.Lj176
.Lj178:
.Lj175:
	jmp	.Lj181
	.p2align 4,,10
	.p2align 3
.Lj172:
	movb	$0,-52(%rbp)
.Lj181:
	cmpb	$0,-52(%rbp)
	jne	.Lj182
	jmp	.Lj183
.Lj182:
	movq	-24(%rbp),%rax
	movq	(%rax),%rdx
	movslq	-60(%rbp),%rax
	shlq	$8,%rax
	movb	$0,(%rdx,%rax)
	movl	-32(%rbp),%eax
	leal	-1(%eax),%eax
	movl	%eax,-56(%rbp)
	movl	-56(%rbp),%eax
	cmpl	-40(%rbp),%eax
	jge	.Lj184
	jmp	.Lj185
.Lj184:
	movl	-56(%rbp),%ebx
	cmpl	-40(%rbp),%ebx
	jge	.Lj186
	jmp	.Lj187
.Lj186:
	movl	-40(%rbp),%eax
	leal	-1(%eax),%eax
	movl	%eax,-36(%rbp)
	.p2align 4,,10
	.p2align 3
.Lj188:
	movl	-36(%rbp),%eax
	leal	1(%eax),%eax
	movl	%eax,-36(%rbp)
	movq	-8(%rbp),%rax
	movzbl	-36(%rbp),%edx
	movzbl	(%rax,%rdx,1),%eax
	shlq	$8,%rax
	orq	$1,%rax
	movw	%ax,-328(%rbp)
	leaq	-328(%rbp),%rcx
	movq	-24(%rbp),%rax
	movq	(%rax),%rdx
	movslq	-60(%rbp),%rax
	shlq	$8,%rax
	leaq	(%rdx,%rax),%rdx
	movq	-24(%rbp),%rax
	movq	(%rax),%rsi
	movslq	-60(%rbp),%rax
	shlq	$8,%rax
	leaq	(%rsi,%rax),%rdi
	movq	$255,%rsi
	call	fpc_shortstr_concat
	cmpl	-36(%rbp),%ebx
	jle	.Lj190
	jmp	.Lj188
.Lj190:
.Lj187:
.Lj185:
	addl	$1,-60(%rbp)
	movl	-32(%rbp),%edx
	movl	-48(%rbp),%eax
	leal	(%edx,%eax),%eax
	movl	%eax,-32(%rbp)
	movl	-32(%rbp),%eax
	movl	%eax,-40(%rbp)
	jmp	.Lj191
	.p2align 4,,10
	.p2align 3
.Lj183:
	addl	$1,-32(%rbp)
.Lj191:
.Lj169:
	movl	-32(%rbp),%eax
	cmpl	-44(%rbp),%eax
	jle	.Lj168
	jmp	.Lj170
.Lj170:
	movl	-40(%rbp),%eax
	cmpl	-44(%rbp),%eax
	jle	.Lj192
	jmp	.Lj193
.Lj192:
	movq	-24(%rbp),%rax
	movq	(%rax),%rdx
	movslq	-60(%rbp),%rax
	shlq	$8,%rax
	movb	$0,(%rdx,%rax)
	movl	-44(%rbp),%ebx
	cmpl	-40(%rbp),%ebx
	jge	.Lj194
	jmp	.Lj195
.Lj194:
	movl	-40(%rbp),%eax
	leal	-1(%eax),%eax
	movl	%eax,-36(%rbp)
	.p2align 4,,10
	.p2align 3
.Lj196:
	movl	-36(%rbp),%eax
	leal	1(%eax),%eax
	movl	%eax,-36(%rbp)
	movq	-8(%rbp),%rdx
	movzbl	-36(%rbp),%eax
	movzbl	(%rdx,%rax,1),%eax
	shlq	$8,%rax
	orq	$1,%rax
	movw	%ax,-320(%rbp)
	leaq	-320(%rbp),%rcx
	movq	-24(%rbp),%rax
	movq	(%rax),%rdx
	movslq	-60(%rbp),%rax
	shlq	$8,%rax
	leaq	(%rdx,%rax),%rdx
	movq	-24(%rbp),%rax
	movq	(%rax),%rsi
	movslq	-60(%rbp),%rax
	shlq	$8,%rax
	leaq	(%rsi,%rax),%rdi
	movq	$255,%rsi
	call	fpc_shortstr_concat
	cmpl	-36(%rbp),%ebx
	jle	.Lj198
	jmp	.Lj196
.Lj198:
.Lj195:
	jmp	.Lj199
	.p2align 4,,10
	.p2align 3
.Lj193:
	movl	-60(%rbp),%eax
	cmpl	-28(%rbp),%eax
	jl	.Lj200
	jmp	.Lj201
.Lj200:
	movq	-24(%rbp),%rax
	movq	(%rax),%rdx
	movslq	-60(%rbp),%rax
	shlq	$8,%rax
	movb	$0,(%rdx,%rax)
.Lj201:
.Lj199:
.Lj149:
	movq	-336(%rbp),%rbx
.Lc71:
	movq	%rbp,%rsp
.Lc72:
	popq	%rbp
	ret
.Lc67:

.section .text.n_nextpasstrutils_$$_join$tstringarray$shortstring$$shortstring,"ax"
	.balign 16,0x90
.globl	NEXTPASSTRUTILS_$$_JOIN$TSTRINGARRAY$SHORTSTRING$$SHORTSTRING
	.type	NEXTPASSTRUTILS_$$_JOIN$TSTRINGARRAY$SHORTSTRING$$SHORTSTRING,@function
NEXTPASSTRUTILS_$$_JOIN$TSTRINGARRAY$SHORTSTRING$$SHORTSTRING:
.Lc74:
	pushq	%rbp
.Lc75:
	movq	%rsp,%rbp
.Lc76:
	leaq	-64(%rsp),%rsp
	movq	%rbx,-64(%rbp)
	movq	%rdi,-24(%rbp)
	movq	%rsi,-8(%rbp)
	movq	%rdx,-16(%rbp)
	movq	-24(%rbp),%rax
	movb	$0,(%rax)
	movq	-8(%rbp),%rax
	cmpq	$0,%rax
	je	.Lj204
	movq	-8(%rax),%rax
	addq	$1,%rax
.Lj204:
	testq	%rax,%rax
	je	.Lj205
	jmp	.Lj206
.Lj205:
	jmp	.Lj202
	.p2align 4,,10
	.p2align 3
.Lj206:
	movq	-8(%rbp),%rdx
	movq	-24(%rbp),%rdi
	movq	$255,%rsi
	call	fpc_shortstr_to_shortstr
	movq	-8(%rbp),%rbx
	cmpq	$0,%rbx
	je	.Lj207
	movq	-8(%rbx),%rbx
	addq	$1,%rbx
.Lj207:
	subq	$1,%rbx
	cmpl	$1,%ebx
	jge	.Lj208
	jmp	.Lj209
.Lj208:
	movl	$0,-28(%rbp)
	.p2align 4,,10
	.p2align 3
.Lj210:
	movl	-28(%rbp),%eax
	leal	1(%eax),%eax
	movl	%eax,-28(%rbp)
	movq	-24(%rbp),%rax
	movq	%rax,-56(%rbp)
	movq	-16(%rbp),%rax
	movq	%rax,-48(%rbp)
	movq	-8(%rbp),%rdx
	movslq	-28(%rbp),%rax
	shlq	$8,%rax
	leaq	(%rdx,%rax),%rax
	movq	%rax,-40(%rbp)
	leaq	-56(%rbp),%rdx
	movq	-24(%rbp),%rdi
	movq	$2,%rcx
	movq	$255,%rsi
	call	fpc_shortstr_concat_multi
	cmpl	-28(%rbp),%ebx
	jle	.Lj212
	jmp	.Lj210
.Lj212:
.Lj209:
.Lj202:
	movq	-64(%rbp),%rbx
.Lc77:
	movq	%rbp,%rsp
.Lc78:
	popq	%rbp
	ret
.Lc73:

.section .text.n_nextpasstrutils_$$_comparetext$shortstring$shortstring$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPASSTRUTILS_$$_COMPARETEXT$SHORTSTRING$SHORTSTRING$$LONGINT
	.type	NEXTPASSTRUTILS_$$_COMPARETEXT$SHORTSTRING$SHORTSTRING$$LONGINT,@function
NEXTPASSTRUTILS_$$_COMPARETEXT$SHORTSTRING$SHORTSTRING$$LONGINT:
.Lc80:
	pushq	%rbp
.Lc81:
	movq	%rsp,%rbp
.Lc82:
	leaq	-48(%rsp),%rsp
	movq	%rdi,-8(%rbp)
	movq	%rsi,-16(%rbp)
	movq	-8(%rbp),%rax
	movzbl	(%rax),%eax
	movl	%eax,-24(%rbp)
	movq	-16(%rbp),%rax
	movzbl	(%rax),%eax
	movl	%eax,-28(%rbp)
	movl	$1,-32(%rbp)
	jmp	.Lj216
	.p2align 4,,10
	.p2align 3
.Lj215:
	movq	-8(%rbp),%rdx
	movzbl	-32(%rbp),%eax
	movb	(%rdx,%rax,1),%al
	movb	%al,-36(%rbp)
	movq	-16(%rbp),%rdx
	movzbl	-32(%rbp),%eax
	movb	(%rdx,%rax,1),%al
	movb	%al,-40(%rbp)
	cmpb	$65,-36(%rbp)
	jae	.Lj218
	jmp	.Lj219
.Lj218:
	cmpb	$90,-36(%rbp)
	jbe	.Lj220
	jmp	.Lj219
.Lj220:
	movzbl	-36(%rbp),%eax
	leal	32(%eax),%eax
	movb	%al,-36(%rbp)
.Lj219:
	cmpb	$65,-40(%rbp)
	jae	.Lj221
	jmp	.Lj222
.Lj221:
	cmpb	$90,-40(%rbp)
	jbe	.Lj223
	jmp	.Lj222
.Lj223:
	movzbl	-40(%rbp),%eax
	leal	32(%eax),%eax
	movb	%al,-40(%rbp)
.Lj222:
	movb	-36(%rbp),%al
	cmpb	-40(%rbp),%al
	jne	.Lj224
	jmp	.Lj225
.Lj224:
	movb	-36(%rbp),%al
	cmpb	-40(%rbp),%al
	jb	.Lj226
	jmp	.Lj227
.Lj226:
	movl	$-1,-20(%rbp)
	jmp	.Lj213
	.p2align 4,,10
	.p2align 3
	jmp	.Lj228
	.p2align 4,,10
	.p2align 3
.Lj227:
	movl	$1,-20(%rbp)
	jmp	.Lj213
	.p2align 4,,10
	.p2align 3
.Lj228:
.Lj225:
	addl	$1,-32(%rbp)
.Lj216:
	movl	-32(%rbp),%eax
	cmpl	-24(%rbp),%eax
	jle	.Lj229
	jmp	.Lj230
.Lj229:
	movl	-32(%rbp),%eax
	cmpl	-28(%rbp),%eax
	jle	.Lj231
	jmp	.Lj230
.Lj231:
	jmp	.Lj215
.Lj230:
	jmp	.Lj217
.Lj217:
	movl	-24(%rbp),%eax
	cmpl	-28(%rbp),%eax
	jl	.Lj232
	jmp	.Lj233
.Lj232:
	movl	$-1,-20(%rbp)
	jmp	.Lj213
	.p2align 4,,10
	.p2align 3
.Lj233:
	movl	-24(%rbp),%eax
	cmpl	-28(%rbp),%eax
	jg	.Lj234
	jmp	.Lj235
.Lj234:
	movl	$1,-20(%rbp)
	jmp	.Lj213
	.p2align 4,,10
	.p2align 3
.Lj235:
	movl	$0,-20(%rbp)
.Lj213:
	movl	-20(%rbp),%eax
.Lc83:
	movq	%rbp,%rsp
.Lc84:
	popq	%rbp
	ret
.Lc79:
.Le4:
	.size	NEXTPASSTRUTILS_$$_COMPARETEXT$SHORTSTRING$SHORTSTRING$$LONGINT, .Le4 - NEXTPASSTRUTILS_$$_COMPARETEXT$SHORTSTRING$SHORTSTRING$$LONGINT

.section .text.n_nextpasstrutils_$$_sametext$shortstring$shortstring$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPASSTRUTILS_$$_SAMETEXT$SHORTSTRING$SHORTSTRING$$BOOLEAN
	.type	NEXTPASSTRUTILS_$$_SAMETEXT$SHORTSTRING$SHORTSTRING$$BOOLEAN,@function
NEXTPASSTRUTILS_$$_SAMETEXT$SHORTSTRING$SHORTSTRING$$BOOLEAN:
.Lc86:
	pushq	%rbp
.Lc87:
	movq	%rsp,%rbp
.Lc88:
	leaq	-32(%rsp),%rsp
	movq	%rdi,-8(%rbp)
	movq	%rsi,-16(%rbp)
	movq	-16(%rbp),%rsi
	movq	-8(%rbp),%rdi
	call	NEXTPASSTRUTILS_$$_COMPARETEXT$SHORTSTRING$SHORTSTRING$$LONGINT
	testl	%eax,%eax
	seteb	-20(%rbp)
	movb	-20(%rbp),%al
.Lc89:
	movq	%rbp,%rsp
.Lc90:
	popq	%rbp
	ret
.Lc85:

.section .text.n_nextpasstrutils_$$_padleft$shortstring$longint$ansichar$$shortstring,"ax"
	.balign 16,0x90
.globl	NEXTPASSTRUTILS_$$_PADLEFT$SHORTSTRING$LONGINT$ANSICHAR$$SHORTSTRING
	.type	NEXTPASSTRUTILS_$$_PADLEFT$SHORTSTRING$LONGINT$ANSICHAR$$SHORTSTRING,@function
NEXTPASSTRUTILS_$$_PADLEFT$SHORTSTRING$LONGINT$ANSICHAR$$SHORTSTRING:
.Lc92:
	pushq	%rbp
.Lc93:
	movq	%rsp,%rbp
.Lc94:
	leaq	-304(%rsp),%rsp
	movq	%rbx,-304(%rbp)
	movq	%rdi,-32(%rbp)
	movq	%rsi,-8(%rbp)
	movl	%edx,-16(%rbp)
	movb	%cl,-24(%rbp)
	movq	-8(%rbp),%rax
	movzbl	(%rax),%eax
	movslq	-16(%rbp),%rdx
	cmpq	%rdx,%rax
	jge	.Lj240
	jmp	.Lj241
.Lj240:
	movq	-8(%rbp),%rdx
	movq	-32(%rbp),%rdi
	movq	$255,%rsi
	call	fpc_shortstr_to_shortstr
	jmp	.Lj238
	.p2align 4,,10
	.p2align 3
.Lj241:
	movq	-8(%rbp),%rax
	movzbl	(%rax),%edx
	movl	-16(%rbp),%eax
	subl	%edx,%eax
	movl	%eax,-36(%rbp)
	movq	-32(%rbp),%rax
	movb	$0,(%rax)
	movl	-36(%rbp),%ebx
	cmpl	$1,%ebx
	jge	.Lj242
	jmp	.Lj243
.Lj242:
	movl	$0,-40(%rbp)
	.p2align 4,,10
	.p2align 3
.Lj244:
	movl	-40(%rbp),%eax
	leal	1(%eax),%eax
	movl	%eax,-40(%rbp)
	movzbl	-24(%rbp),%eax
	shlq	$8,%rax
	orq	$1,%rax
	movw	%ax,-296(%rbp)
	leaq	-296(%rbp),%rcx
	movq	-32(%rbp),%rdx
	movq	-32(%rbp),%rdi
	movq	$255,%rsi
	call	fpc_shortstr_concat
	cmpl	-40(%rbp),%ebx
	jle	.Lj246
	jmp	.Lj244
.Lj246:
.Lj243:
	movq	-8(%rbp),%rcx
	movq	-32(%rbp),%rdx
	movq	-32(%rbp),%rdi
	movq	$255,%rsi
	call	fpc_shortstr_concat
.Lj238:
	movq	-304(%rbp),%rbx
.Lc95:
	movq	%rbp,%rsp
.Lc96:
	popq	%rbp
	ret
.Lc91:

.section .text.n_nextpasstrutils_$$_padright$shortstring$longint$ansichar$$shortstring,"ax"
	.balign 16,0x90
.globl	NEXTPASSTRUTILS_$$_PADRIGHT$SHORTSTRING$LONGINT$ANSICHAR$$SHORTSTRING
	.type	NEXTPASSTRUTILS_$$_PADRIGHT$SHORTSTRING$LONGINT$ANSICHAR$$SHORTSTRING,@function
NEXTPASSTRUTILS_$$_PADRIGHT$SHORTSTRING$LONGINT$ANSICHAR$$SHORTSTRING:
.Lc98:
	pushq	%rbp
.Lc99:
	movq	%rsp,%rbp
.Lc100:
	leaq	-304(%rsp),%rsp
	movq	%rbx,-304(%rbp)
	movq	%rdi,-32(%rbp)
	movq	%rsi,-8(%rbp)
	movl	%edx,-16(%rbp)
	movb	%cl,-24(%rbp)
	movq	-8(%rbp),%rax
	movzbl	(%rax),%eax
	movslq	-16(%rbp),%rdx
	cmpq	%rdx,%rax
	jge	.Lj249
	jmp	.Lj250
.Lj249:
	movq	-8(%rbp),%rdx
	movq	-32(%rbp),%rdi
	movq	$255,%rsi
	call	fpc_shortstr_to_shortstr
	jmp	.Lj247
	.p2align 4,,10
	.p2align 3
.Lj250:
	movq	-8(%rbp),%rax
	movzbl	(%rax),%eax
	movl	-16(%rbp),%edx
	subl	%eax,%edx
	movl	%edx,-36(%rbp)
	movq	-8(%rbp),%rdx
	movq	-32(%rbp),%rdi
	movq	$255,%rsi
	call	fpc_shortstr_to_shortstr
	movl	-36(%rbp),%ebx
	cmpl	$1,%ebx
	jge	.Lj251
	jmp	.Lj252
.Lj251:
	movl	$0,-40(%rbp)
	.p2align 4,,10
	.p2align 3
.Lj253:
	movl	-40(%rbp),%eax
	leal	1(%eax),%eax
	movl	%eax,-40(%rbp)
	movzbl	-24(%rbp),%eax
	shlq	$8,%rax
	orq	$1,%rax
	movw	%ax,-296(%rbp)
	leaq	-296(%rbp),%rcx
	movq	-32(%rbp),%rdx
	movq	-32(%rbp),%rdi
	movq	$255,%rsi
	call	fpc_shortstr_concat
	cmpl	-40(%rbp),%ebx
	jle	.Lj255
	jmp	.Lj253
.Lj255:
.Lj252:
.Lj247:
	movq	-304(%rbp),%rbx
.Lc101:
	movq	%rbp,%rsp
.Lc102:
	popq	%rbp
	ret
.Lc97:
# End asmlist al_procedures
# Begin asmlist al_typedconsts

.section .rodata.n_.Ld1
	.balign 8
.Ld1:
	.byte	0
	.ascii	"\000"
.Le5:
	.size	.Ld1, .Le5 - .Ld1
# End asmlist al_typedconsts
# Begin asmlist al_rtti

.section .rodata.n_RTTI_$NEXTPASSTRUTILS_$$_def00000000
	.balign 8
.globl	RTTI_$NEXTPASSTRUTILS_$$_def00000000
	.type	RTTI_$NEXTPASSTRUTILS_$$_def00000000,@object
RTTI_$NEXTPASSTRUTILS_$$_def00000000:
	.byte	3,0
	.quad	0
	.byte	5
	.long	0,1
	.quad	0
	.byte	12
	.ascii	"rfReplaceAll"
	.byte	12
	.ascii	"rfIgnoreCase"
	.byte	15
	.ascii	"nextpasstrutils"
	.byte	0
.Le6:
	.size	RTTI_$NEXTPASSTRUTILS_$$_def00000000, .Le6 - RTTI_$NEXTPASSTRUTILS_$$_def00000000

.section .rodata.n_RTTI_$NEXTPASSTRUTILS_$$_def00000000_s2o
	.balign 8
.globl	RTTI_$NEXTPASSTRUTILS_$$_def00000000_s2o
	.type	RTTI_$NEXTPASSTRUTILS_$$_def00000000_s2o,@object
RTTI_$NEXTPASSTRUTILS_$$_def00000000_s2o:
	.long	2,1
	.quad	RTTI_$NEXTPASSTRUTILS_$$_def00000000+40
	.long	0
	.quad	RTTI_$NEXTPASSTRUTILS_$$_def00000000+27
.Le7:
	.size	RTTI_$NEXTPASSTRUTILS_$$_def00000000_s2o, .Le7 - RTTI_$NEXTPASSTRUTILS_$$_def00000000_s2o

.section .rodata.n_RTTI_$NEXTPASSTRUTILS_$$_def00000000_o2s
	.balign 8
.globl	RTTI_$NEXTPASSTRUTILS_$$_def00000000_o2s
	.type	RTTI_$NEXTPASSTRUTILS_$$_def00000000_o2s,@object
RTTI_$NEXTPASSTRUTILS_$$_def00000000_o2s:
	.long	0
	.quad	RTTI_$NEXTPASSTRUTILS_$$_def00000000+27
	.quad	RTTI_$NEXTPASSTRUTILS_$$_def00000000+40
.Le8:
	.size	RTTI_$NEXTPASSTRUTILS_$$_def00000000_o2s, .Le8 - RTTI_$NEXTPASSTRUTILS_$$_def00000000_o2s

.section .rodata.n_RTTI_$NEXTPASSTRUTILS_$$_TREPLACEFLAGS
	.balign 8
.globl	RTTI_$NEXTPASSTRUTILS_$$_TREPLACEFLAGS
	.type	RTTI_$NEXTPASSTRUTILS_$$_TREPLACEFLAGS,@object
RTTI_$NEXTPASSTRUTILS_$$_TREPLACEFLAGS:
	.byte	5,13
	.ascii	"TReplaceFlags"
	.quad	0
	.byte	5
	.quad	4
	.quad	RTTI_$NEXTPASSTRUTILS_$$_def00000000$indirect
.Le9:
	.size	RTTI_$NEXTPASSTRUTILS_$$_TREPLACEFLAGS, .Le9 - RTTI_$NEXTPASSTRUTILS_$$_TREPLACEFLAGS

.section .rodata.n_RTTI_$NEXTPASSTRUTILS_$$_TSTRINGARRAY
	.balign 8
.globl	RTTI_$NEXTPASSTRUTILS_$$_TSTRINGARRAY
	.type	RTTI_$NEXTPASSTRUTILS_$$_TSTRINGARRAY,@object
RTTI_$NEXTPASSTRUTILS_$$_TSTRINGARRAY:
	.byte	21,12
	.ascii	"TStringArray"
	.quad	0,256
	.quad	RTTI_$SYSTEM_$$_SHORTSTRING$indirect
	.long	-1
	.quad	0
	.byte	15
	.ascii	"nextpasstrutils"
.Le10:
	.size	RTTI_$NEXTPASSTRUTILS_$$_TSTRINGARRAY, .Le10 - RTTI_$NEXTPASSTRUTILS_$$_TSTRINGARRAY
# End asmlist al_rtti
# Begin asmlist al_indirectglobals

.section .rodata.n_RTTI_$NEXTPASSTRUTILS_$$_def00000000
	.balign 8
.globl	RTTI_$NEXTPASSTRUTILS_$$_def00000000$indirect
	.type	RTTI_$NEXTPASSTRUTILS_$$_def00000000$indirect,@object
RTTI_$NEXTPASSTRUTILS_$$_def00000000$indirect:
	.quad	RTTI_$NEXTPASSTRUTILS_$$_def00000000
.Le11:
	.size	RTTI_$NEXTPASSTRUTILS_$$_def00000000$indirect, .Le11 - RTTI_$NEXTPASSTRUTILS_$$_def00000000$indirect

.section .rodata.n_RTTI_$NEXTPASSTRUTILS_$$_def00000000_s2o
	.balign 8
.globl	RTTI_$NEXTPASSTRUTILS_$$_def00000000_s2o$indirect
	.type	RTTI_$NEXTPASSTRUTILS_$$_def00000000_s2o$indirect,@object
RTTI_$NEXTPASSTRUTILS_$$_def00000000_s2o$indirect:
	.quad	RTTI_$NEXTPASSTRUTILS_$$_def00000000_s2o
.Le12:
	.size	RTTI_$NEXTPASSTRUTILS_$$_def00000000_s2o$indirect, .Le12 - RTTI_$NEXTPASSTRUTILS_$$_def00000000_s2o$indirect

.section .rodata.n_RTTI_$NEXTPASSTRUTILS_$$_def00000000_o2s
	.balign 8
.globl	RTTI_$NEXTPASSTRUTILS_$$_def00000000_o2s$indirect
	.type	RTTI_$NEXTPASSTRUTILS_$$_def00000000_o2s$indirect,@object
RTTI_$NEXTPASSTRUTILS_$$_def00000000_o2s$indirect:
	.quad	RTTI_$NEXTPASSTRUTILS_$$_def00000000_o2s
.Le13:
	.size	RTTI_$NEXTPASSTRUTILS_$$_def00000000_o2s$indirect, .Le13 - RTTI_$NEXTPASSTRUTILS_$$_def00000000_o2s$indirect

.section .rodata.n_RTTI_$NEXTPASSTRUTILS_$$_TREPLACEFLAGS
	.balign 8
.globl	RTTI_$NEXTPASSTRUTILS_$$_TREPLACEFLAGS$indirect
	.type	RTTI_$NEXTPASSTRUTILS_$$_TREPLACEFLAGS$indirect,@object
RTTI_$NEXTPASSTRUTILS_$$_TREPLACEFLAGS$indirect:
	.quad	RTTI_$NEXTPASSTRUTILS_$$_TREPLACEFLAGS
.Le14:
	.size	RTTI_$NEXTPASSTRUTILS_$$_TREPLACEFLAGS$indirect, .Le14 - RTTI_$NEXTPASSTRUTILS_$$_TREPLACEFLAGS$indirect

.section .rodata.n_RTTI_$NEXTPASSTRUTILS_$$_TSTRINGARRAY
	.balign 8
.globl	RTTI_$NEXTPASSTRUTILS_$$_TSTRINGARRAY$indirect
	.type	RTTI_$NEXTPASSTRUTILS_$$_TSTRINGARRAY$indirect,@object
RTTI_$NEXTPASSTRUTILS_$$_TSTRINGARRAY$indirect:
	.quad	RTTI_$NEXTPASSTRUTILS_$$_TSTRINGARRAY
.Le15:
	.size	RTTI_$NEXTPASSTRUTILS_$$_TSTRINGARRAY$indirect, .Le15 - RTTI_$NEXTPASSTRUTILS_$$_TSTRINGARRAY$indirect
# End asmlist al_indirectglobals
# Begin asmlist al_dwarf_frame

.section .debug_frame
.Lc103:
	.long	.Lc105-.Lc104
.Lc104:
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
.Lc105:
	.long	.Lc107-.Lc106
.Lc106:
	.long	.Lc103
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
.Lc107:
	.long	.Lc110-.Lc109
.Lc109:
	.long	.Lc103
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
.Lc110:
	.long	.Lc113-.Lc112
.Lc112:
	.long	.Lc103
	.quad	.Lc14
	.quad	.Lc13-.Lc14
	.byte	2
	.byte	.Lc15-.Lc14
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc16-.Lc15
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc17-.Lc16
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc18-.Lc17
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc113:
	.long	.Lc116-.Lc115
.Lc115:
	.long	.Lc103
	.quad	.Lc20
	.quad	.Lc19-.Lc20
	.byte	2
	.byte	.Lc21-.Lc20
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc22-.Lc21
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc23-.Lc22
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc24-.Lc23
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc116:
	.long	.Lc119-.Lc118
.Lc118:
	.long	.Lc103
	.quad	.Lc26
	.quad	.Lc25-.Lc26
	.byte	2
	.byte	.Lc27-.Lc26
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc28-.Lc27
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc29-.Lc28
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc30-.Lc29
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc119:
	.long	.Lc122-.Lc121
.Lc121:
	.long	.Lc103
	.quad	.Lc32
	.quad	.Lc31-.Lc32
	.byte	2
	.byte	.Lc33-.Lc32
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc34-.Lc33
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc35-.Lc34
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc36-.Lc35
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc122:
	.long	.Lc125-.Lc124
.Lc124:
	.long	.Lc103
	.quad	.Lc38
	.quad	.Lc37-.Lc38
	.byte	2
	.byte	.Lc39-.Lc38
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc40-.Lc39
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc41-.Lc40
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc42-.Lc41
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc125:
	.long	.Lc128-.Lc127
.Lc127:
	.long	.Lc103
	.quad	.Lc44
	.quad	.Lc43-.Lc44
	.byte	2
	.byte	.Lc45-.Lc44
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc46-.Lc45
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc47-.Lc46
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc48-.Lc47
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc128:
	.long	.Lc131-.Lc130
.Lc130:
	.long	.Lc103
	.quad	.Lc50
	.quad	.Lc49-.Lc50
	.byte	2
	.byte	.Lc51-.Lc50
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc52-.Lc51
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc53-.Lc52
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc54-.Lc53
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc131:
	.long	.Lc134-.Lc133
.Lc133:
	.long	.Lc103
	.quad	.Lc56
	.quad	.Lc55-.Lc56
	.byte	2
	.byte	.Lc57-.Lc56
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc58-.Lc57
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc59-.Lc58
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc60-.Lc59
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc134:
	.long	.Lc137-.Lc136
.Lc136:
	.long	.Lc103
	.quad	.Lc62
	.quad	.Lc61-.Lc62
	.byte	2
	.byte	.Lc63-.Lc62
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc64-.Lc63
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc65-.Lc64
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc66-.Lc65
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc137:
	.long	.Lc140-.Lc139
.Lc139:
	.long	.Lc103
	.quad	.Lc68
	.quad	.Lc67-.Lc68
	.byte	2
	.byte	.Lc69-.Lc68
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc70-.Lc69
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc71-.Lc70
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc72-.Lc71
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc140:
	.long	.Lc143-.Lc142
.Lc142:
	.long	.Lc103
	.quad	.Lc74
	.quad	.Lc73-.Lc74
	.byte	2
	.byte	.Lc75-.Lc74
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc76-.Lc75
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc77-.Lc76
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc78-.Lc77
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc143:
	.long	.Lc146-.Lc145
.Lc145:
	.long	.Lc103
	.quad	.Lc80
	.quad	.Lc79-.Lc80
	.byte	2
	.byte	.Lc81-.Lc80
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc82-.Lc81
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc83-.Lc82
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc84-.Lc83
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc146:
	.long	.Lc149-.Lc148
.Lc148:
	.long	.Lc103
	.quad	.Lc86
	.quad	.Lc85-.Lc86
	.byte	2
	.byte	.Lc87-.Lc86
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc88-.Lc87
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc89-.Lc88
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc90-.Lc89
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc149:
	.long	.Lc152-.Lc151
.Lc151:
	.long	.Lc103
	.quad	.Lc92
	.quad	.Lc91-.Lc92
	.byte	2
	.byte	.Lc93-.Lc92
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc94-.Lc93
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc95-.Lc94
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc96-.Lc95
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc152:
	.long	.Lc155-.Lc154
.Lc154:
	.long	.Lc103
	.quad	.Lc98
	.quad	.Lc97-.Lc98
	.byte	2
	.byte	.Lc99-.Lc98
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc100-.Lc99
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc101-.Lc100
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc102-.Lc101
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc155:
# End asmlist al_dwarf_frame
.section .note.GNU-stack,"",%progbits

