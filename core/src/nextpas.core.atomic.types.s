	.file "nextpas.core.atomic.types.pas"
# Begin asmlist al_procedures

.section .text.n_nextpas.core.atomic.types_$$__cas_success_order$memory_order_t$$memory_order_t,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES_$$__CAS_SUCCESS_ORDER$MEMORY_ORDER_T$$MEMORY_ORDER_T
	.hidden NEXTPAS.CORE.ATOMIC.TYPES_$$__CAS_SUCCESS_ORDER$MEMORY_ORDER_T$$MEMORY_ORDER_T
	.type	NEXTPAS.CORE.ATOMIC.TYPES_$$__CAS_SUCCESS_ORDER$MEMORY_ORDER_T$$MEMORY_ORDER_T,@function
NEXTPAS.CORE.ATOMIC.TYPES_$$__CAS_SUCCESS_ORDER$MEMORY_ORDER_T$$MEMORY_ORDER_T:
.Lc2:
# Var $result located in register eax
# Var AOrder located in register edi
# [nextpas.core.atomic.types.pas]
# [410] begin
# [414] Result := mo_acquire
	movl	$2,%eax
# [413] if AOrder = mo_consume then
	cmpl	$1,%edi
# [416] Result := AOrder;
	cmovnel	%edi,%eax
.Lc3:
# [417] end;
	ret
.Lc1:

.section .text.n_nextpas.core.atomic.types_$$__cas_failure_order$memory_order_t$$memory_order_t,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES_$$__CAS_FAILURE_ORDER$MEMORY_ORDER_T$$MEMORY_ORDER_T
	.hidden NEXTPAS.CORE.ATOMIC.TYPES_$$__CAS_FAILURE_ORDER$MEMORY_ORDER_T$$MEMORY_ORDER_T
	.type	NEXTPAS.CORE.ATOMIC.TYPES_$$__CAS_FAILURE_ORDER$MEMORY_ORDER_T$$MEMORY_ORDER_T,@function
NEXTPAS.CORE.ATOMIC.TYPES_$$__CAS_FAILURE_ORDER$MEMORY_ORDER_T$$MEMORY_ORDER_T:
.Lc5:
# Var $result located in register eax
# Var ASuccessOrder located in register edi
# [420] begin
# [422] case ASuccessOrder of
	testl	%edi,%edi
	je	.Lj12
	subl	$2,%edi
	je	.Lj13
	subl	$1,%edi
	je	.Lj14
	subl	$1,%edi
	je	.Lj15
	subl	$1,%edi
	je	.Lj16
	jmp	.Lj11
	.balign 16,0x90
.Lj12:
# [424] Result := mo_relaxed;
	xorl	%eax,%eax
	ret
	.balign 16,0x90
.Lj13:
# [426] Result := mo_acquire;
	movl	$2,%eax
	ret
	.balign 16,0x90
.Lj14:
# [428] Result := mo_relaxed;
	xorl	%eax,%eax
	ret
	.balign 16,0x90
.Lj15:
# [430] Result := mo_acquire;
	movl	$2,%eax
	ret
	.balign 16,0x90
.Lj16:
# [432] Result := mo_seq_cst;
	movl	$5,%eax
	ret
	.balign 16,0x90
.Lj11:
# [434] Result := mo_relaxed;
	xorl	%eax,%eax
.Lc6:
# [436] end;
	ret
.Lc4:

.section .text.n_nextpas.core.atomic.types$_$tatomicint32_$__$$_create$longint$$tatomicint32,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_CREATE$LONGINT$$TATOMICINT32
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_CREATE$LONGINT$$TATOMICINT32,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_CREATE$LONGINT$$TATOMICINT32:
.Lc8:
# Var $result located in register eax
# Var AValue located in register edi
# [441] begin
# Var AValue located in register edi
# [442] Result.FValue := AValue;
	movl	%edi,%eax
.Lc9:
# [443] end;
	ret
.Lc7:

.section .text.n_nextpas.core.atomic.types$_$tatomicint32_$__$$_is_lock_free$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_IS_LOCK_FREE$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_IS_LOCK_FREE$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_IS_LOCK_FREE$$BOOLEAN:
.Lc11:
# [446] begin
# Var $result located in register al
# [448] Result := True;
	movb	$1,%al
.Lc12:
# [449] end;
	ret
.Lc10:

.section .text.n_nextpas.core.atomic.types$_$tatomicint32_$__$$_load$memory_order_t$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_LOAD$MEMORY_ORDER_T$$LONGINT
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_LOAD$MEMORY_ORDER_T$$LONGINT,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_LOAD$MEMORY_ORDER_T$$LONGINT:
.Lc14:
# [452] begin
	pushq	%rbx
.Lc15:
	pushq	%r12
.Lc16:
	pushq	%rax
.Lc17:
	movq	%rdi,%rbx
# Var $self located in register rbx
# Var AOrder located in register esi
# [453] Result := atomic_load(FValue, AOrder);
	movl	(%rdi),%r12d
	testl	%esi,%esi
	je	.Lj25
	subl	$1,%esi
	jb	.Lj24
	subl	$1,%esi
	jbe	.Lj26
	subl	$1,%esi
	je	.Lj27
	subl	$1,%esi
	je	.Lj26
	subl	$1,%esi
	je	.Lj28
	jmp	.Lj24
	.balign 16,0x90
.Lj25:
	movl	(%rbx),%r12d
	jmp	.Lj24
	.balign 16,0x90
.Lj26:
	movl	(%rbx),%r12d
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	jmp	.Lj24
	.balign 16,0x90
.Lj27:
	movl	(%rbx),%r12d
	jmp	.Lj24
	.balign 16,0x90
.Lj28:
	movl	(%rbx),%r12d
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	.balign 16,0x90
.Lj24:
# Var $result located in register eax
	movl	%r12d,%eax
# [454] end;
	popq	%rcx
	popq	%r12
.Lc18:
	popq	%rbx
.Lc19:
	ret
.Lc13:

.section .text.n_nextpas.core.atomic.types$_$tatomicint32_$__$$_store$longint$memory_order_t,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_STORE$LONGINT$MEMORY_ORDER_T
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_STORE$LONGINT$MEMORY_ORDER_T,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_STORE$LONGINT$MEMORY_ORDER_T:
.Lc21:
# [457] begin
	pushq	%rbx
.Lc22:
	pushq	%r12
.Lc23:
	pushq	%rax
.Lc24:
	movq	%rdi,%rbx
# Var $self located in register rbx
	movl	%esi,%r12d
# Var AValue located in register r12d
# Var AOrder located in register edx
# [458] atomic_store(FValue, AValue, AOrder);
	subl	$2,%edx
	jbe	.Lj32
	subl	$1,%edx
	subl	$1,%edx
	jbe	.Lj33
	subl	$1,%edx
	je	.Lj34
	jmp	.Lj31
	.balign 16,0x90
.Lj32:
	movl	%r12d,(%rbx)
	jmp	.Lj31
	.balign 16,0x90
.Lj33:
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	movl	%r12d,(%rbx)
	jmp	.Lj31
	.balign 16,0x90
.Lj34:
	movq	%rbx,%rdi
	movl	%r12d,%esi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE$LONGINT$LONGINT$$LONGINT
	.balign 16,0x90
.Lj31:
# [459] end;
	popq	%rcx
	popq	%r12
.Lc25:
	popq	%rbx
.Lc26:
	ret
.Lc20:

.section .text.n_nextpas.core.atomic.types$_$tatomicint32_$__$$_exchange$longint$memory_order_t$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_EXCHANGE$LONGINT$MEMORY_ORDER_T$$LONGINT
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_EXCHANGE$LONGINT$MEMORY_ORDER_T$$LONGINT,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_EXCHANGE$LONGINT$MEMORY_ORDER_T$$LONGINT:
.Lc28:
# [462] begin
	pushq	%rax
.Lc29:
# Var $self located in register rdi
# Var AValue located in register esi
# Var AOrder located in register edx
# [463] Result := atomic_exchange(FValue, AValue, AOrder);
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE$LONGINT$LONGINT$$LONGINT
# Var $result located in register eax
# [464] end;
	popq	%rcx
.Lc30:
	ret
.Lc27:

.section .text.n_nextpas.core.atomic.types$_$tatomicint32_$__$$_compareexchangestrong$hsy3bvutumqb,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_COMPAREEXCHANGESTRONG$hsY3BVUTuMqB
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_COMPAREEXCHANGESTRONG$hsY3BVUTuMqB,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_COMPAREEXCHANGESTRONG$hsY3BVUTuMqB:
.Lc32:
# [471] begin
	pushq	%rbx
.Lc33:
# Var $self located in register rdi
	movq	%rsi,%rbx
# Var AExpected located in register rbx
	movl	%edx,%esi
# Var ADesired located in register esi
# Var AOrder located in register ecx
# [472] LSuccessOrder := _cas_success_order(AOrder);
	movl	$2,%eax
	cmpl	$1,%ecx
	cmovnel	%ecx,%eax
# Var LSuccessOrder located in register eax
# [473] LFailureOrder := _cas_failure_order(LSuccessOrder);
	movl	%eax,%edx
	testl	%eax,%eax
	je	.Lj47
	subl	$2,%edx
	je	.Lj48
	subl	$1,%edx
	je	.Lj49
	subl	$1,%edx
	je	.Lj50
	subl	$1,%edx
	je	.Lj51
	jmp	.Lj46
	.balign 16,0x90
.Lj47:
	xorl	%edx,%edx
	jmp	.Lj45
	.balign 16,0x90
.Lj48:
	movl	$2,%edx
	jmp	.Lj45
	.balign 16,0x90
.Lj49:
	xorl	%edx,%edx
	jmp	.Lj45
	.balign 16,0x90
.Lj50:
	movl	$2,%edx
	jmp	.Lj45
	.balign 16,0x90
.Lj51:
	movl	$5,%edx
	jmp	.Lj45
	.balign 16,0x90
.Lj46:
	xorl	%edx,%edx
	.balign 16,0x90
.Lj45:
# Var LFailureOrder located in register edx
# [474] Result := atomic_compare_exchange_strong(FValue, AExpected, ADesired, LSuccessOrder, LFailureOrder);
	movl	(%rbx),%edx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE$LONGINT$LONGINT$LONGINT$$LONGINT
	movl	%eax,%edx
	cmpl	(%rbx),%eax
	seteb	%al
	je	.Lj60
	movl	%edx,(%rbx)
.Lj60:
# Var $result located in register al
# [475] end;
	popq	%rbx
.Lc34:
	ret
.Lc31:

.section .text.n_nextpas.core.atomic.types$_$tatomicint32_$__$$_compareexchangeweak$hsy3bvutumqb,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_COMPAREEXCHANGEWEAK$hsY3BVUTuMqB
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_COMPAREEXCHANGEWEAK$hsY3BVUTuMqB,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_COMPAREEXCHANGEWEAK$hsY3BVUTuMqB:
.Lc36:
# [482] begin
	pushq	%rbx
.Lc37:
# Var $self located in register rdi
	movq	%rsi,%rbx
# Var AExpected located in register rbx
	movl	%edx,%esi
# Var ADesired located in register esi
# Var AOrder located in register ecx
# [483] LSuccessOrder := _cas_success_order(AOrder);
	movl	$2,%eax
	cmpl	$1,%ecx
	cmovnel	%ecx,%eax
# Var LSuccessOrder located in register eax
# [484] LFailureOrder := _cas_failure_order(LSuccessOrder);
	movl	%eax,%edx
	testl	%eax,%eax
	je	.Lj68
	subl	$2,%edx
	je	.Lj69
	subl	$1,%edx
	je	.Lj70
	subl	$1,%edx
	je	.Lj71
	subl	$1,%edx
	je	.Lj72
	jmp	.Lj67
	.balign 16,0x90
.Lj68:
	xorl	%edx,%edx
	jmp	.Lj66
	.balign 16,0x90
.Lj69:
	movl	$2,%edx
	jmp	.Lj66
	.balign 16,0x90
.Lj70:
	xorl	%edx,%edx
	jmp	.Lj66
	.balign 16,0x90
.Lj71:
	movl	$2,%edx
	jmp	.Lj66
	.balign 16,0x90
.Lj72:
	movl	$5,%edx
	jmp	.Lj66
	.balign 16,0x90
.Lj67:
	xorl	%edx,%edx
	.balign 16,0x90
.Lj66:
# Var LFailureOrder located in register edx
# [485] Result := atomic_compare_exchange_weak(FValue, AExpected, ADesired, LSuccessOrder, LFailureOrder);
	movl	(%rbx),%edx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE$LONGINT$LONGINT$LONGINT$$LONGINT
	movl	%eax,%edx
	cmpl	(%rbx),%eax
	seteb	%al
	je	.Lj81
	movl	%edx,(%rbx)
.Lj81:
# Var $result located in register al
# [486] end;
	popq	%rbx
.Lc38:
	ret
.Lc35:

.section .text.n_nextpas.core.atomic.types$_$tatomicint32_$__$$_fetchadd$longint$memory_order_t$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_FETCHADD$LONGINT$MEMORY_ORDER_T$$LONGINT
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_FETCHADD$LONGINT$MEMORY_ORDER_T$$LONGINT,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_FETCHADD$LONGINT$MEMORY_ORDER_T$$LONGINT:
.Lc40:
# [489] begin
	pushq	%rax
.Lc41:
# Var $self located in register rdi
# Var ADelta located in register esi
# Var AOrder located in register edx
# [490] Result := atomic_fetch_add(FValue, ADelta, AOrder);
	call	SYSTEM_$$_INTERLOCKEDEXCHANGEADD$LONGINT$LONGINT$$LONGINT
# Var $result located in register eax
# [491] end;
	popq	%rcx
.Lc42:
	ret
.Lc39:

.section .text.n_nextpas.core.atomic.types$_$tatomicint32_$__$$_fetchsub$longint$memory_order_t$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_FETCHSUB$LONGINT$MEMORY_ORDER_T$$LONGINT
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_FETCHSUB$LONGINT$MEMORY_ORDER_T$$LONGINT,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_FETCHSUB$LONGINT$MEMORY_ORDER_T$$LONGINT:
.Lc44:
# [494] begin
	pushq	%rax
.Lc45:
# Var $self located in register rdi
# Var ADelta located in register esi
# Var AOrder located in register edx
# [495] Result := atomic_fetch_sub(FValue, ADelta, AOrder);
	negl	%esi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGEADD$LONGINT$LONGINT$$LONGINT
# Var $result located in register eax
# [496] end;
	popq	%rcx
.Lc46:
	ret
.Lc43:

.section .text.n_nextpas.core.atomic.types$_$tatomicint32_$__$$_fetchand$longint$memory_order_t$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_FETCHAND$LONGINT$MEMORY_ORDER_T$$LONGINT
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_FETCHAND$LONGINT$MEMORY_ORDER_T$$LONGINT,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_FETCHAND$LONGINT$MEMORY_ORDER_T$$LONGINT:
.Lc48:
# [499] begin
	pushq	%rbx
.Lc49:
	pushq	%r12
.Lc50:
	pushq	%r13
.Lc51:
	pushq	%r14
.Lc52:
	pushq	%rax
.Lc53:
	movq	%rdi,%rbx
# Var $self located in register rbx
	movl	%esi,%r12d
# Var AMask located in register r12d
# Var AOrder located in register edx
	.p2align 4,,10
	.p2align 3
.Lj97:
# [500] Result := atomic_fetch_and(FValue, AMask, AOrder);
	movl	(%rbx),%r13d
	movl	%r13d,%r14d
	andl	%r12d,%r14d
	movq	%rbx,%rdi
	movl	%r13d,%edx
	movl	%r14d,%esi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE$LONGINT$LONGINT$LONGINT$$LONGINT
	cmpl	%r13d,%eax
	je	.Lj99
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
	jmp	.Lj97
.Lj99:
	movl	%r13d,%eax
# Var $result located in register eax
# [501] end;
	popq	%rcx
	popq	%r14
.Lc54:
	popq	%r13
.Lc55:
	popq	%r12
.Lc56:
	popq	%rbx
.Lc57:
	ret
.Lc47:

.section .text.n_nextpas.core.atomic.types$_$tatomicint32_$__$$_fetchor$longint$memory_order_t$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_FETCHOR$LONGINT$MEMORY_ORDER_T$$LONGINT
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_FETCHOR$LONGINT$MEMORY_ORDER_T$$LONGINT,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_FETCHOR$LONGINT$MEMORY_ORDER_T$$LONGINT:
.Lc59:
# [504] begin
	pushq	%rbx
.Lc60:
	pushq	%r12
.Lc61:
	pushq	%r13
.Lc62:
	pushq	%r14
.Lc63:
	pushq	%rax
.Lc64:
	movq	%rdi,%rbx
# Var $self located in register rbx
	movl	%esi,%r12d
# Var AMask located in register r12d
# Var AOrder located in register edx
	.p2align 4,,10
	.p2align 3
.Lj107:
# [505] Result := atomic_fetch_or(FValue, AMask, AOrder);
	movl	(%rbx),%r13d
	movl	%r13d,%r14d
	orl	%r12d,%r14d
	movq	%rbx,%rdi
	movl	%r13d,%edx
	movl	%r14d,%esi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE$LONGINT$LONGINT$LONGINT$$LONGINT
	cmpl	%r13d,%eax
	je	.Lj109
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
	jmp	.Lj107
.Lj109:
	movl	%r13d,%eax
# Var $result located in register eax
# [506] end;
	popq	%rcx
	popq	%r14
.Lc65:
	popq	%r13
.Lc66:
	popq	%r12
.Lc67:
	popq	%rbx
.Lc68:
	ret
.Lc58:

.section .text.n_nextpas.core.atomic.types$_$tatomicint32_$__$$_fetchxor$longint$memory_order_t$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_FETCHXOR$LONGINT$MEMORY_ORDER_T$$LONGINT
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_FETCHXOR$LONGINT$MEMORY_ORDER_T$$LONGINT,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_FETCHXOR$LONGINT$MEMORY_ORDER_T$$LONGINT:
.Lc70:
# [509] begin
	pushq	%rbx
.Lc71:
	pushq	%r12
.Lc72:
	pushq	%r13
.Lc73:
	pushq	%r14
.Lc74:
	pushq	%rax
.Lc75:
	movq	%rdi,%rbx
# Var $self located in register rbx
	movl	%esi,%r12d
# Var AMask located in register r12d
# Var AOrder located in register edx
	.p2align 4,,10
	.p2align 3
.Lj117:
# [510] Result := atomic_fetch_xor(FValue, AMask, AOrder);
	movl	(%rbx),%r13d
	movl	%r13d,%r14d
	xorl	%r12d,%r14d
	movq	%rbx,%rdi
	movl	%r13d,%edx
	movl	%r14d,%esi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE$LONGINT$LONGINT$LONGINT$$LONGINT
	cmpl	%r13d,%eax
	je	.Lj119
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
	jmp	.Lj117
.Lj119:
	movl	%r13d,%eax
# Var $result located in register eax
# [511] end;
	popq	%rcx
	popq	%r14
.Lc76:
	popq	%r13
.Lc77:
	popq	%r12
.Lc78:
	popq	%rbx
.Lc79:
	ret
.Lc69:

.section .text.n_nextpas.core.atomic.types$_$tatomicint32_$__$$_increment$memory_order_t$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_INCREMENT$MEMORY_ORDER_T$$LONGINT
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_INCREMENT$MEMORY_ORDER_T$$LONGINT,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_INCREMENT$MEMORY_ORDER_T$$LONGINT:
.Lc81:
# [514] begin
	pushq	%rax
.Lc82:
# Var $self located in register rdi
# Var AOrder located in register esi
# [515] Result := FetchAdd(1, AOrder) + 1;
	movl	$1,%esi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGEADD$LONGINT$LONGINT$$LONGINT
	addl	$1,%eax
# Var $result located in register eax
# [516] end;
	popq	%rcx
.Lc83:
	ret
.Lc80:

.section .text.n_nextpas.core.atomic.types$_$tatomicint32_$__$$_decrement$memory_order_t$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_DECREMENT$MEMORY_ORDER_T$$LONGINT
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_DECREMENT$MEMORY_ORDER_T$$LONGINT,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_DECREMENT$MEMORY_ORDER_T$$LONGINT:
.Lc85:
# [519] begin
	pushq	%rax
.Lc86:
# Var $self located in register rdi
# Var AOrder located in register esi
# [520] Result := FetchSub(1, AOrder) - 1;
	movl	$-1,%esi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGEADD$LONGINT$LONGINT$$LONGINT
	subl	$1,%eax
# Var $result located in register eax
# [521] end;
	popq	%rcx
.Lc87:
	ret
.Lc84:

.section .text.n_nextpas.core.atomic.types$_$tatomicint32_$__$$_getmut$$plongint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_GETMUT$$PLONGINT
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_GETMUT$$PLONGINT,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_GETMUT$$PLONGINT:
.Lc89:
# [524] begin
	movq	%rdi,%rax
# Var $self located in register rax
# Var $result located in register rax
.Lc90:
# [526] end;
	ret
.Lc88:

.section .text.n_nextpas.core.atomic.types$_$tatomicint32_$__$$_intoinner$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_INTOINNER$$LONGINT
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_INTOINNER$$LONGINT,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT32_$__$$_INTOINNER$$LONGINT:
.Lc92:
# Var $self located in register rdi
# [529] begin
# Var $result located in register eax
# [530] Result := FValue;
	movl	(%rdi),%eax
.Lc93:
# [531] end;
	ret
.Lc91:

.section .text.n_nextpas.core.atomic.types$_$tatomicuint32_$__$$_create$longword$$tatomicuint32,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_CREATE$LONGWORD$$TATOMICUINT32
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_CREATE$LONGWORD$$TATOMICUINT32,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_CREATE$LONGWORD$$TATOMICUINT32:
.Lc95:
# Var $result located in register eax
# Var AValue located in register edi
# [536] begin
# Var AValue located in register edi
# [537] Result.FValue := AValue;
	movl	%edi,%eax
.Lc96:
# [538] end;
	ret
.Lc94:

.section .text.n_nextpas.core.atomic.types$_$tatomicuint32_$__$$_is_lock_free$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_IS_LOCK_FREE$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_IS_LOCK_FREE$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_IS_LOCK_FREE$$BOOLEAN:
.Lc98:
# [541] begin
# Var $result located in register al
# [543] Result := True;
	movb	$1,%al
.Lc99:
# [544] end;
	ret
.Lc97:

.section .text.n_nextpas.core.atomic.types$_$tatomicuint32_$__$$_load$memory_order_t$$longword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_LOAD$MEMORY_ORDER_T$$LONGWORD
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_LOAD$MEMORY_ORDER_T$$LONGWORD,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_LOAD$MEMORY_ORDER_T$$LONGWORD:
.Lc101:
# [547] begin
	pushq	%rbx
.Lc102:
	pushq	%r12
.Lc103:
	pushq	%rax
.Lc104:
	movq	%rdi,%rbx
# Var $self located in register rbx
# Var AOrder located in register esi
# [548] Result := atomic_load(FValue, AOrder);
	movl	(%rdi),%r12d
	testl	%esi,%esi
	je	.Lj144
	subl	$1,%esi
	jb	.Lj143
	subl	$1,%esi
	jbe	.Lj145
	subl	$1,%esi
	je	.Lj146
	subl	$1,%esi
	je	.Lj145
	subl	$1,%esi
	je	.Lj147
	jmp	.Lj143
	.balign 16,0x90
.Lj144:
	movl	(%rbx),%r12d
	jmp	.Lj143
	.balign 16,0x90
.Lj145:
	movl	(%rbx),%r12d
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	jmp	.Lj143
	.balign 16,0x90
.Lj146:
	movl	(%rbx),%r12d
	jmp	.Lj143
	.balign 16,0x90
.Lj147:
	movl	(%rbx),%r12d
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	.balign 16,0x90
.Lj143:
	movl	%r12d,%eax
# Var $result located in register eax
# [549] end;
	popq	%rcx
	popq	%r12
.Lc105:
	popq	%rbx
.Lc106:
	ret
.Lc100:

.section .text.n_nextpas.core.atomic.types$_$tatomicuint32_$__$$_store$longword$memory_order_t,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_STORE$LONGWORD$MEMORY_ORDER_T
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_STORE$LONGWORD$MEMORY_ORDER_T,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_STORE$LONGWORD$MEMORY_ORDER_T:
.Lc108:
# Temps allocated between rsp+0 and rsp+4
# [552] begin
	pushq	%rbx
.Lc109:
	pushq	%r12
.Lc110:
	pushq	%rax
.Lc111:
	movq	%rdi,%rbx
# Var $self located in register rbx
# Var AValue located in register esi
# Var AOrder located in register edx
# Var AValue located in register esi
# [553] atomic_store(FValue, AValue, AOrder);
	movl	%esi,(%rsp)
	movl	(%rsp),%r12d
	subl	$2,%edx
	jbe	.Lj151
	subl	$1,%edx
	subl	$1,%edx
	jbe	.Lj152
	subl	$1,%edx
	je	.Lj153
	jmp	.Lj150
	.balign 16,0x90
.Lj151:
	movl	%r12d,(%rbx)
	jmp	.Lj150
	.balign 16,0x90
.Lj152:
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	movl	%r12d,(%rbx)
	jmp	.Lj150
	.balign 16,0x90
.Lj153:
	movq	%rbx,%rdi
	movl	%r12d,%esi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE$LONGINT$LONGINT$$LONGINT
	.balign 16,0x90
.Lj150:
# [554] end;
	popq	%rcx
	popq	%r12
.Lc112:
	popq	%rbx
.Lc113:
	ret
.Lc107:

.section .text.n_nextpas.core.atomic.types$_$tatomicuint32_$__$$_exchange$longword$memory_order_t$$longword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_EXCHANGE$LONGWORD$MEMORY_ORDER_T$$LONGWORD
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_EXCHANGE$LONGWORD$MEMORY_ORDER_T$$LONGWORD,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_EXCHANGE$LONGWORD$MEMORY_ORDER_T$$LONGWORD:
.Lc115:
# Temps allocated between rsp+0 and rsp+4
# [557] begin
	pushq	%rax
.Lc116:
# Var $self located in register rdi
# Var AValue located in register esi
# Var AOrder located in register edx
# [558] Result := atomic_exchange(FValue, AValue, AOrder);
	movl	%esi,(%rsp)
	movl	(%rsp),%esi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE$LONGINT$LONGINT$$LONGINT
# Var $result located in register eax
# [559] end;
	popq	%rcx
.Lc117:
	ret
.Lc114:

.section .text.n_nextpas.core.atomic.types$_$tatomicuint32_$__$$_compareexchangestrong$hqj_bm5rqili,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_COMPAREEXCHANGESTRONG$hqj_bM5rQIlI
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_COMPAREEXCHANGESTRONG$hqj_bM5rQIlI,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_COMPAREEXCHANGESTRONG$hqj_bM5rQIlI:
.Lc119:
# Temps allocated between rsp+0 and rsp+4
# [566] begin
	pushq	%rbx
.Lc120:
	leaq	-16(%rsp),%rsp
.Lc121:
# Var $self located in register rdi
	movq	%rsi,%rbx
# Var AExpected located in register rbx
# Var ADesired located in register edx
# Var AOrder located in register ecx
# [567] LSuccessOrder := _cas_success_order(AOrder);
	movl	$2,%eax
	cmpl	$1,%ecx
	cmovnel	%ecx,%eax
# Var LSuccessOrder located in register eax
# [568] LFailureOrder := _cas_failure_order(LSuccessOrder);
	movl	%eax,%ecx
	testl	%eax,%eax
	je	.Lj166
	subl	$2,%ecx
	je	.Lj167
	subl	$1,%ecx
	je	.Lj168
	subl	$1,%ecx
	je	.Lj169
	subl	$1,%ecx
	je	.Lj170
	jmp	.Lj165
	.balign 16,0x90
.Lj166:
	xorl	%ecx,%ecx
	jmp	.Lj164
	.balign 16,0x90
.Lj167:
	movl	$2,%ecx
	jmp	.Lj164
	.balign 16,0x90
.Lj168:
	xorl	%ecx,%ecx
	jmp	.Lj164
	.balign 16,0x90
.Lj169:
	movl	$2,%ecx
	jmp	.Lj164
	.balign 16,0x90
.Lj170:
	movl	$5,%ecx
	jmp	.Lj164
	.balign 16,0x90
.Lj165:
	xorl	%ecx,%ecx
	.balign 16,0x90
.Lj164:
# Var LFailureOrder located in register ecx
# [569] Result := atomic_compare_exchange_strong(FValue, AExpected, ADesired, LSuccessOrder, LFailureOrder);
	movl	%edx,(%rsp)
	movl	(%rsp),%esi
	movl	(%rbx),%edx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE$LONGINT$LONGINT$LONGINT$$LONGINT
	movl	%eax,%edx
	cmpl	(%rbx),%eax
	seteb	%al
	je	.Lj179
	movl	%edx,(%rbx)
.Lj179:
# Var $result located in register al
# [570] end;
	leaq	16(%rsp),%rsp
	popq	%rbx
.Lc122:
	ret
.Lc118:

.section .text.n_nextpas.core.atomic.types$_$tatomicuint32_$__$$_compareexchangeweak$hqj_bm5rqili,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_COMPAREEXCHANGEWEAK$hqj_bM5rQIlI
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_COMPAREEXCHANGEWEAK$hqj_bM5rQIlI,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_COMPAREEXCHANGEWEAK$hqj_bM5rQIlI:
.Lc124:
# Temps allocated between rsp+0 and rsp+4
# [577] begin
	pushq	%rbx
.Lc125:
	leaq	-16(%rsp),%rsp
.Lc126:
# Var $self located in register rdi
	movq	%rsi,%rbx
# Var AExpected located in register rbx
# Var ADesired located in register edx
# Var AOrder located in register ecx
# [578] LSuccessOrder := _cas_success_order(AOrder);
	movl	$2,%eax
	cmpl	$1,%ecx
	cmovnel	%ecx,%eax
# Var LSuccessOrder located in register eax
# [579] LFailureOrder := _cas_failure_order(LSuccessOrder);
	movl	%eax,%ecx
	testl	%eax,%eax
	je	.Lj187
	subl	$2,%ecx
	je	.Lj188
	subl	$1,%ecx
	je	.Lj189
	subl	$1,%ecx
	je	.Lj190
	subl	$1,%ecx
	je	.Lj191
	jmp	.Lj186
	.balign 16,0x90
.Lj187:
	xorl	%ecx,%ecx
	jmp	.Lj185
	.balign 16,0x90
.Lj188:
	movl	$2,%ecx
	jmp	.Lj185
	.balign 16,0x90
.Lj189:
	xorl	%ecx,%ecx
	jmp	.Lj185
	.balign 16,0x90
.Lj190:
	movl	$2,%ecx
	jmp	.Lj185
	.balign 16,0x90
.Lj191:
	movl	$5,%ecx
	jmp	.Lj185
	.balign 16,0x90
.Lj186:
	xorl	%ecx,%ecx
	.balign 16,0x90
.Lj185:
# Var LFailureOrder located in register ecx
# [580] Result := atomic_compare_exchange_weak(FValue, AExpected, ADesired, LSuccessOrder, LFailureOrder);
	movl	%edx,(%rsp)
	movl	(%rsp),%esi
	movl	(%rbx),%edx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE$LONGINT$LONGINT$LONGINT$$LONGINT
	movl	%eax,%edx
	cmpl	(%rbx),%eax
	seteb	%al
	je	.Lj200
	movl	%edx,(%rbx)
.Lj200:
# Var $result located in register al
# [581] end;
	leaq	16(%rsp),%rsp
	popq	%rbx
.Lc127:
	ret
.Lc123:

.section .text.n_nextpas.core.atomic.types$_$tatomicuint32_$__$$_fetchadd$longword$memory_order_t$$longword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_FETCHADD$LONGWORD$MEMORY_ORDER_T$$LONGWORD
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_FETCHADD$LONGWORD$MEMORY_ORDER_T$$LONGWORD,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_FETCHADD$LONGWORD$MEMORY_ORDER_T$$LONGWORD:
.Lc129:
# Temps allocated between rsp+0 and rsp+4
# [584] begin
	pushq	%rax
.Lc130:
# Var $self located in register rdi
# Var ADelta located in register esi
# Var AOrder located in register edx
# [585] Result := atomic_fetch_add(FValue, ADelta, AOrder);
	movl	%esi,(%rsp)
	movl	(%rsp),%esi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGEADD$LONGINT$LONGINT$$LONGINT
# Var $result located in register eax
# [586] end;
	popq	%rcx
.Lc131:
	ret
.Lc128:

.section .text.n_nextpas.core.atomic.types$_$tatomicuint32_$__$$_fetchsub$longword$memory_order_t$$longword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_FETCHSUB$LONGWORD$MEMORY_ORDER_T$$LONGWORD
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_FETCHSUB$LONGWORD$MEMORY_ORDER_T$$LONGWORD,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_FETCHSUB$LONGWORD$MEMORY_ORDER_T$$LONGWORD:
.Lc133:
# Temps allocated between rsp+0 and rsp+4
# [589] begin
	pushq	%rax
.Lc134:
# Var $self located in register rdi
# Var ADelta located in register esi
# Var AOrder located in register edx
# [590] Result := atomic_fetch_sub(FValue, ADelta, AOrder);
	movl	%esi,(%rsp)
	movl	(%rsp),%esi
	negl	%esi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGEADD$LONGINT$LONGINT$$LONGINT
# Var $result located in register eax
# [591] end;
	popq	%rcx
.Lc135:
	ret
.Lc132:

.section .text.n_nextpas.core.atomic.types$_$tatomicuint32_$__$$_fetchand$longword$memory_order_t$$longword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_FETCHAND$LONGWORD$MEMORY_ORDER_T$$LONGWORD
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_FETCHAND$LONGWORD$MEMORY_ORDER_T$$LONGWORD,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_FETCHAND$LONGWORD$MEMORY_ORDER_T$$LONGWORD:
.Lc137:
# Temps allocated between rsp+0 and rsp+4
# [594] begin
	pushq	%rbx
.Lc138:
	pushq	%r12
.Lc139:
	pushq	%r13
.Lc140:
	pushq	%r14
.Lc141:
	pushq	%rax
.Lc142:
	movq	%rdi,%rbx
# Var $self located in register rbx
# Var AMask located in register esi
# Var AOrder located in register edx
# [595] Result := atomic_fetch_and(FValue, AMask, AOrder);
	movl	%esi,(%rsp)
	movl	(%rsp),%r12d
	.p2align 4,,10
	.p2align 3
.Lj216:
	movl	(%rbx),%r13d
	movl	%r13d,%r14d
	andl	%r12d,%r14d
	movq	%rbx,%rdi
	movl	%r13d,%edx
	movl	%r14d,%esi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE$LONGINT$LONGINT$LONGINT$$LONGINT
	cmpl	%r13d,%eax
	je	.Lj218
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
	jmp	.Lj216
.Lj218:
	movl	%r13d,%eax
# Var $result located in register eax
# [596] end;
	popq	%rcx
	popq	%r14
.Lc143:
	popq	%r13
.Lc144:
	popq	%r12
.Lc145:
	popq	%rbx
.Lc146:
	ret
.Lc136:

.section .text.n_nextpas.core.atomic.types$_$tatomicuint32_$__$$_fetchor$longword$memory_order_t$$longword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_FETCHOR$LONGWORD$MEMORY_ORDER_T$$LONGWORD
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_FETCHOR$LONGWORD$MEMORY_ORDER_T$$LONGWORD,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_FETCHOR$LONGWORD$MEMORY_ORDER_T$$LONGWORD:
.Lc148:
# Temps allocated between rsp+0 and rsp+4
# [599] begin
	pushq	%rbx
.Lc149:
	pushq	%r12
.Lc150:
	pushq	%r13
.Lc151:
	pushq	%r14
.Lc152:
	pushq	%rax
.Lc153:
	movq	%rdi,%rbx
# Var $self located in register rbx
# Var AMask located in register esi
# Var AOrder located in register edx
# [600] Result := atomic_fetch_or(FValue, AMask, AOrder);
	movl	%esi,(%rsp)
	movl	(%rsp),%r12d
	.p2align 4,,10
	.p2align 3
.Lj226:
	movl	(%rbx),%r13d
	movl	%r13d,%r14d
	orl	%r12d,%r14d
	movq	%rbx,%rdi
	movl	%r13d,%edx
	movl	%r14d,%esi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE$LONGINT$LONGINT$LONGINT$$LONGINT
	cmpl	%r13d,%eax
	je	.Lj228
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
	jmp	.Lj226
.Lj228:
	movl	%r13d,%eax
# Var $result located in register eax
# [601] end;
	popq	%rcx
	popq	%r14
.Lc154:
	popq	%r13
.Lc155:
	popq	%r12
.Lc156:
	popq	%rbx
.Lc157:
	ret
.Lc147:

.section .text.n_nextpas.core.atomic.types$_$tatomicuint32_$__$$_fetchxor$longword$memory_order_t$$longword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_FETCHXOR$LONGWORD$MEMORY_ORDER_T$$LONGWORD
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_FETCHXOR$LONGWORD$MEMORY_ORDER_T$$LONGWORD,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_FETCHXOR$LONGWORD$MEMORY_ORDER_T$$LONGWORD:
.Lc159:
# Temps allocated between rsp+0 and rsp+4
# [604] begin
	pushq	%rbx
.Lc160:
	pushq	%r12
.Lc161:
	pushq	%r13
.Lc162:
	pushq	%r14
.Lc163:
	pushq	%rax
.Lc164:
	movq	%rdi,%rbx
# Var $self located in register rbx
# Var AMask located in register esi
# Var AOrder located in register edx
# [605] Result := atomic_fetch_xor(FValue, AMask, AOrder);
	movl	%esi,(%rsp)
	movl	(%rsp),%r12d
	.p2align 4,,10
	.p2align 3
.Lj236:
	movl	(%rbx),%r13d
	movl	%r13d,%r14d
	xorl	%r12d,%r14d
	movq	%rbx,%rdi
	movl	%r13d,%edx
	movl	%r14d,%esi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE$LONGINT$LONGINT$LONGINT$$LONGINT
	cmpl	%r13d,%eax
	je	.Lj238
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
	jmp	.Lj236
.Lj238:
	movl	%r13d,%eax
# Var $result located in register eax
# [606] end;
	popq	%rcx
	popq	%r14
.Lc165:
	popq	%r13
.Lc166:
	popq	%r12
.Lc167:
	popq	%rbx
.Lc168:
	ret
.Lc158:

.section .text.n_nextpas.core.atomic.types$_$tatomicuint32_$__$$_increment$memory_order_t$$longword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_INCREMENT$MEMORY_ORDER_T$$LONGWORD
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_INCREMENT$MEMORY_ORDER_T$$LONGWORD,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_INCREMENT$MEMORY_ORDER_T$$LONGWORD:
.Lc170:
# Temps allocated between rsp+0 and rsp+4
# [609] begin
	pushq	%rax
.Lc171:
# Var $self located in register rdi
	movl	%esi,%eax
# Var AOrder located in register eax
# [610] Result := FetchAdd(1, AOrder) + 1;
	movl	$1,%esi
	movl	$1,(%rsp)
	call	SYSTEM_$$_INTERLOCKEDEXCHANGEADD$LONGINT$LONGINT$$LONGINT
	addl	$1,%eax
# Var $result located in register eax
# [611] end;
	popq	%rcx
.Lc172:
	ret
.Lc169:

.section .text.n_nextpas.core.atomic.types$_$tatomicuint32_$__$$_decrement$memory_order_t$$longword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_DECREMENT$MEMORY_ORDER_T$$LONGWORD
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_DECREMENT$MEMORY_ORDER_T$$LONGWORD,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_DECREMENT$MEMORY_ORDER_T$$LONGWORD:
.Lc174:
# Temps allocated between rsp+0 and rsp+4
# [614] begin
	pushq	%rax
.Lc175:
# Var $self located in register rdi
	movl	%esi,%eax
# Var AOrder located in register eax
# [615] Result := FetchSub(1, AOrder) - 1;
	movl	$1,%esi
	movl	$1,(%rsp)
	negl	%esi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGEADD$LONGINT$LONGINT$$LONGINT
	subl	$1,%eax
# Var $result located in register eax
# [616] end;
	popq	%rcx
.Lc176:
	ret
.Lc173:

.section .text.n_nextpas.core.atomic.types$_$tatomicuint32_$__$$_getmut$$pdword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_GETMUT$$PDWORD
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_GETMUT$$PDWORD,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_GETMUT$$PDWORD:
.Lc178:
# [619] begin
	movq	%rdi,%rax
# Var $self located in register rax
# Var $result located in register rax
.Lc179:
# [621] end;
	ret
.Lc177:

.section .text.n_nextpas.core.atomic.types$_$tatomicuint32_$__$$_intoinner$$longword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_INTOINNER$$LONGWORD
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_INTOINNER$$LONGWORD,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT32_$__$$_INTOINNER$$LONGWORD:
.Lc181:
# Var $self located in register rdi
# [624] begin
# Var $result located in register eax
# [625] Result := FValue;
	movl	(%rdi),%eax
.Lc182:
# [626] end;
	ret
.Lc180:

.section .text.n_nextpas.core.atomic.types$_$tatomicint64_$__$$_create$int64$$tatomicint64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_CREATE$INT64$$TATOMICINT64
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_CREATE$INT64$$TATOMICINT64,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_CREATE$INT64$$TATOMICINT64:
.Lc184:
# Var $result located in register rax
# [632] begin
	movq	%rdi,%rax
# Var AValue located in register rax
# Var AValue located in register rax
.Lc185:
# [634] end;
	ret
.Lc183:

.section .text.n_nextpas.core.atomic.types$_$tatomicint64_$__$$_is_lock_free$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_IS_LOCK_FREE$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_IS_LOCK_FREE$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_IS_LOCK_FREE$$BOOLEAN:
.Lc187:
# [637] begin
# Var $result located in register al
# [641] Result := True;
	movb	$1,%al
.Lc188:
# [645] end;
	ret
.Lc186:

.section .text.n_nextpas.core.atomic.types$_$tatomicint64_$__$$_load$memory_order_t$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_LOAD$MEMORY_ORDER_T$$INT64
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_LOAD$MEMORY_ORDER_T$$INT64,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_LOAD$MEMORY_ORDER_T$$INT64:
.Lc190:
# [648] begin
	pushq	%rbx
.Lc191:
	pushq	%r12
.Lc192:
	pushq	%rax
.Lc193:
	movq	%rdi,%rbx
# Var $self located in register rbx
# Var AOrder located in register esi
# [649] Result := atomic_load_64(FValue, AOrder);
	movq	(%rdi),%r12
	testl	%esi,%esi
	je	.Lj263
	subl	$1,%esi
	jb	.Lj262
	subl	$1,%esi
	jbe	.Lj264
	subl	$1,%esi
	je	.Lj265
	subl	$1,%esi
	je	.Lj264
	subl	$1,%esi
	je	.Lj266
	jmp	.Lj262
	.balign 16,0x90
.Lj263:
	movq	(%rbx),%r12
	jmp	.Lj262
	.balign 16,0x90
.Lj264:
	movq	(%rbx),%r12
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	jmp	.Lj262
	.balign 16,0x90
.Lj265:
	movq	(%rbx),%r12
	jmp	.Lj262
	.balign 16,0x90
.Lj266:
	movq	(%rbx),%r12
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	.balign 16,0x90
.Lj262:
# Var $result located in register rax
	movq	%r12,%rax
# [650] end;
	popq	%rcx
	popq	%r12
.Lc194:
	popq	%rbx
.Lc195:
	ret
.Lc189:

.section .text.n_nextpas.core.atomic.types$_$tatomicint64_$__$$_store$int64$memory_order_t,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_STORE$INT64$MEMORY_ORDER_T
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_STORE$INT64$MEMORY_ORDER_T,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_STORE$INT64$MEMORY_ORDER_T:
.Lc197:
# [653] begin
	pushq	%rbx
.Lc198:
	pushq	%r12
.Lc199:
	pushq	%rax
.Lc200:
	movq	%rdi,%rbx
# Var $self located in register rbx
	movq	%rsi,%r12
# Var AValue located in register r12
# Var AOrder located in register edx
# [654] atomic_store_64(FValue, AValue, AOrder);
	subl	$2,%edx
	jbe	.Lj270
	subl	$1,%edx
	subl	$1,%edx
	jbe	.Lj271
	subl	$1,%edx
	je	.Lj272
	jmp	.Lj269
	.balign 16,0x90
.Lj270:
	movq	%r12,(%rbx)
	jmp	.Lj269
	.balign 16,0x90
.Lj271:
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	movq	%r12,(%rbx)
	jmp	.Lj269
	.balign 16,0x90
.Lj272:
	movq	%rbx,%rdi
	movq	%r12,%rsi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE64$INT64$INT64$$INT64
	.balign 16,0x90
.Lj269:
# [655] end;
	popq	%rcx
	popq	%r12
.Lc201:
	popq	%rbx
.Lc202:
	ret
.Lc196:

.section .text.n_nextpas.core.atomic.types$_$tatomicint64_$__$$_exchange$int64$memory_order_t$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_EXCHANGE$INT64$MEMORY_ORDER_T$$INT64
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_EXCHANGE$INT64$MEMORY_ORDER_T$$INT64,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_EXCHANGE$INT64$MEMORY_ORDER_T$$INT64:
.Lc204:
# [658] begin
	pushq	%rax
.Lc205:
# Var $self located in register rdi
# Var AValue located in register rsi
# Var AOrder located in register edx
# [659] Result := atomic_exchange_64(FValue, AValue, AOrder);
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE64$INT64$INT64$$INT64
# Var $result located in register rax
# [660] end;
	popq	%rcx
.Lc206:
	ret
.Lc203:

.section .text.n_nextpas.core.atomic.types$_$tatomicint64_$__$$_compareexchangestrong$h4fud1znbg1g,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_COMPAREEXCHANGESTRONG$h4FUD1ZNBG1G
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_COMPAREEXCHANGESTRONG$h4FUD1ZNBG1G,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_COMPAREEXCHANGESTRONG$h4FUD1ZNBG1G:
.Lc208:
# [667] begin
	pushq	%rbx
.Lc209:
# Var $self located in register rdi
	movq	%rsi,%rbx
# Var AExpected located in register rbx
	movq	%rdx,%rsi
# Var ADesired located in register rsi
# Var AOrder located in register ecx
# [668] LSuccessOrder := _cas_success_order(AOrder);
	movl	$2,%eax
	cmpl	$1,%ecx
	cmovnel	%ecx,%eax
# Var LSuccessOrder located in register eax
# [669] LFailureOrder := _cas_failure_order(LSuccessOrder);
	movl	%eax,%edx
	testl	%eax,%eax
	je	.Lj285
	subl	$2,%edx
	je	.Lj286
	subl	$1,%edx
	je	.Lj287
	subl	$1,%edx
	je	.Lj288
	subl	$1,%edx
	je	.Lj289
	jmp	.Lj284
	.balign 16,0x90
.Lj285:
	xorl	%edx,%edx
	jmp	.Lj283
	.balign 16,0x90
.Lj286:
	movl	$2,%edx
	jmp	.Lj283
	.balign 16,0x90
.Lj287:
	xorl	%edx,%edx
	jmp	.Lj283
	.balign 16,0x90
.Lj288:
	movl	$2,%edx
	jmp	.Lj283
	.balign 16,0x90
.Lj289:
	movl	$5,%edx
	jmp	.Lj283
	.balign 16,0x90
.Lj284:
	xorl	%edx,%edx
	.balign 16,0x90
.Lj283:
# Var LFailureOrder located in register edx
# [670] Result := atomic_compare_exchange_strong_64(FValue, AExpected, ADesired, LSuccessOrder, LFailureOrder);
	movq	(%rbx),%rdx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	movq	%rax,%rdx
	cmpq	(%rbx),%rax
	seteb	%al
	je	.Lj290
	movq	%rdx,(%rbx)
	.p2align 4,,10
	.p2align 3
.Lj290:
# Var $result located in register al
# [671] end;
	popq	%rbx
.Lc210:
	ret
.Lc207:

.section .text.n_nextpas.core.atomic.types$_$tatomicint64_$__$$_compareexchangeweak$h4fud1znbg1g,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_COMPAREEXCHANGEWEAK$h4FUD1ZNBG1G
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_COMPAREEXCHANGEWEAK$h4FUD1ZNBG1G,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_COMPAREEXCHANGEWEAK$h4FUD1ZNBG1G:
.Lc212:
# [678] begin
	pushq	%rbx
.Lc213:
# Var $self located in register rdi
	movq	%rsi,%rbx
# Var AExpected located in register rbx
	movq	%rdx,%rsi
# Var ADesired located in register rsi
# Var AOrder located in register ecx
# [679] LSuccessOrder := _cas_success_order(AOrder);
	movl	$2,%eax
	cmpl	$1,%ecx
	cmovnel	%ecx,%eax
# Var LSuccessOrder located in register eax
# [680] LFailureOrder := _cas_failure_order(LSuccessOrder);
	movl	%eax,%edx
	testl	%eax,%eax
	je	.Lj305
	subl	$2,%edx
	je	.Lj306
	subl	$1,%edx
	je	.Lj307
	subl	$1,%edx
	je	.Lj308
	subl	$1,%edx
	je	.Lj309
	jmp	.Lj304
	.balign 16,0x90
.Lj305:
	xorl	%edx,%edx
	jmp	.Lj303
	.balign 16,0x90
.Lj306:
	movl	$2,%edx
	jmp	.Lj303
	.balign 16,0x90
.Lj307:
	xorl	%edx,%edx
	jmp	.Lj303
	.balign 16,0x90
.Lj308:
	movl	$2,%edx
	jmp	.Lj303
	.balign 16,0x90
.Lj309:
	movl	$5,%edx
	jmp	.Lj303
	.balign 16,0x90
.Lj304:
	xorl	%edx,%edx
	.balign 16,0x90
.Lj303:
# Var LFailureOrder located in register edx
# [681] Result := atomic_compare_exchange_weak_64(FValue, AExpected, ADesired, LSuccessOrder, LFailureOrder);
	movq	(%rbx),%rdx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	movq	%rax,%rdx
	cmpq	(%rbx),%rax
	seteb	%al
	je	.Lj310
	movq	%rdx,(%rbx)
	.p2align 4,,10
	.p2align 3
.Lj310:
# Var $result located in register al
# [682] end;
	popq	%rbx
.Lc214:
	ret
.Lc211:

.section .text.n_nextpas.core.atomic.types$_$tatomicint64_$__$$_fetchadd$int64$memory_order_t$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_FETCHADD$INT64$MEMORY_ORDER_T$$INT64
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_FETCHADD$INT64$MEMORY_ORDER_T$$INT64,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_FETCHADD$INT64$MEMORY_ORDER_T$$INT64:
.Lc216:
# [685] begin
	pushq	%rax
.Lc217:
# Var $self located in register rdi
# Var ADelta located in register rsi
# Var AOrder located in register edx
# [686] Result := atomic_fetch_add_64(FValue, ADelta, AOrder);
	call	SYSTEM_$$_INTERLOCKEDEXCHANGEADD64$INT64$INT64$$INT64
# Var $result located in register rax
# [687] end;
	popq	%rcx
.Lc218:
	ret
.Lc215:

.section .text.n_nextpas.core.atomic.types$_$tatomicint64_$__$$_fetchsub$int64$memory_order_t$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_FETCHSUB$INT64$MEMORY_ORDER_T$$INT64
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_FETCHSUB$INT64$MEMORY_ORDER_T$$INT64,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_FETCHSUB$INT64$MEMORY_ORDER_T$$INT64:
.Lc220:
# [690] begin
	pushq	%rax
.Lc221:
# Var $self located in register rdi
# Var ADelta located in register rsi
# Var AOrder located in register edx
# [691] Result := atomic_fetch_sub_64(FValue, ADelta, AOrder);
	negq	%rsi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGEADD64$INT64$INT64$$INT64
# Var $result located in register rax
# [692] end;
	popq	%rcx
.Lc222:
	ret
.Lc219:

.section .text.n_nextpas.core.atomic.types$_$tatomicint64_$__$$_fetchand$int64$memory_order_t$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_FETCHAND$INT64$MEMORY_ORDER_T$$INT64
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_FETCHAND$INT64$MEMORY_ORDER_T$$INT64,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_FETCHAND$INT64$MEMORY_ORDER_T$$INT64:
.Lc224:
# [695] begin
	pushq	%rbx
.Lc225:
	pushq	%r12
.Lc226:
	pushq	%r13
.Lc227:
	pushq	%r14
.Lc228:
	pushq	%rax
.Lc229:
	movq	%rdi,%rbx
# Var $self located in register rbx
	movq	%rsi,%r12
# Var AMask located in register r12
# Var AOrder located in register edx
	.p2align 4,,10
	.p2align 3
.Lj333:
# [696] Result := atomic_fetch_and_64(FValue, AMask, AOrder);
	movq	(%rbx),%r13
	movq	%r13,%r14
	andq	%r12,%r14
	movq	%rbx,%rdi
	movq	%r13,%rdx
	movq	%r14,%rsi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	cmpq	%r13,%rax
	je	.Lj335
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
	jmp	.Lj333
.Lj335:
	movq	%r13,%rax
# Var $result located in register rax
# [697] end;
	popq	%rcx
	popq	%r14
.Lc230:
	popq	%r13
.Lc231:
	popq	%r12
.Lc232:
	popq	%rbx
.Lc233:
	ret
.Lc223:

.section .text.n_nextpas.core.atomic.types$_$tatomicint64_$__$$_fetchor$int64$memory_order_t$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_FETCHOR$INT64$MEMORY_ORDER_T$$INT64
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_FETCHOR$INT64$MEMORY_ORDER_T$$INT64,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_FETCHOR$INT64$MEMORY_ORDER_T$$INT64:
.Lc235:
# [700] begin
	pushq	%rbx
.Lc236:
	pushq	%r12
.Lc237:
	pushq	%r13
.Lc238:
	pushq	%r14
.Lc239:
	pushq	%rax
.Lc240:
	movq	%rdi,%rbx
# Var $self located in register rbx
	movq	%rsi,%r12
# Var AMask located in register r12
# Var AOrder located in register edx
	.p2align 4,,10
	.p2align 3
.Lj343:
# [701] Result := atomic_fetch_or_64(FValue, AMask, AOrder);
	movq	(%rbx),%r13
	movq	%r13,%r14
	orq	%r12,%r14
	movq	%rbx,%rdi
	movq	%r13,%rdx
	movq	%r14,%rsi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	cmpq	%r13,%rax
	je	.Lj345
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
	jmp	.Lj343
.Lj345:
	movq	%r13,%rax
# Var $result located in register rax
# [702] end;
	popq	%rcx
	popq	%r14
.Lc241:
	popq	%r13
.Lc242:
	popq	%r12
.Lc243:
	popq	%rbx
.Lc244:
	ret
.Lc234:

.section .text.n_nextpas.core.atomic.types$_$tatomicint64_$__$$_fetchxor$int64$memory_order_t$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_FETCHXOR$INT64$MEMORY_ORDER_T$$INT64
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_FETCHXOR$INT64$MEMORY_ORDER_T$$INT64,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_FETCHXOR$INT64$MEMORY_ORDER_T$$INT64:
.Lc246:
# [705] begin
	pushq	%rbx
.Lc247:
	pushq	%r12
.Lc248:
	pushq	%r13
.Lc249:
	pushq	%r14
.Lc250:
	pushq	%rax
.Lc251:
	movq	%rdi,%rbx
# Var $self located in register rbx
	movq	%rsi,%r12
# Var AMask located in register r12
# Var AOrder located in register edx
	.p2align 4,,10
	.p2align 3
.Lj353:
# [706] Result := atomic_fetch_xor_64(FValue, AMask, AOrder);
	movq	(%rbx),%r13
	movq	%r13,%r14
	xorq	%r12,%r14
	movq	%rbx,%rdi
	movq	%r13,%rdx
	movq	%r14,%rsi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	cmpq	%r13,%rax
	je	.Lj355
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
	jmp	.Lj353
.Lj355:
	movq	%r13,%rax
# Var $result located in register rax
# [707] end;
	popq	%rcx
	popq	%r14
.Lc252:
	popq	%r13
.Lc253:
	popq	%r12
.Lc254:
	popq	%rbx
.Lc255:
	ret
.Lc245:

.section .text.n_nextpas.core.atomic.types$_$tatomicint64_$__$$_increment$memory_order_t$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_INCREMENT$MEMORY_ORDER_T$$INT64
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_INCREMENT$MEMORY_ORDER_T$$INT64,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_INCREMENT$MEMORY_ORDER_T$$INT64:
.Lc257:
# [710] begin
	pushq	%rax
.Lc258:
# Var $self located in register rdi
# Var AOrder located in register esi
# [711] Result := FetchAdd(1, AOrder) + 1;
	movl	$1,%esi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGEADD64$INT64$INT64$$INT64
	addq	$1,%rax
# Var $result located in register rax
# [712] end;
	popq	%rcx
.Lc259:
	ret
.Lc256:

.section .text.n_nextpas.core.atomic.types$_$tatomicint64_$__$$_decrement$memory_order_t$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_DECREMENT$MEMORY_ORDER_T$$INT64
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_DECREMENT$MEMORY_ORDER_T$$INT64,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_DECREMENT$MEMORY_ORDER_T$$INT64:
.Lc261:
# [715] begin
	pushq	%rax
.Lc262:
# Var $self located in register rdi
# Var AOrder located in register esi
# [716] Result := FetchSub(1, AOrder) - 1;
	movq	$-1,%rsi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGEADD64$INT64$INT64$$INT64
	subq	$1,%rax
# Var $result located in register rax
# [717] end;
	popq	%rcx
.Lc263:
	ret
.Lc260:

.section .text.n_nextpas.core.atomic.types$_$tatomicint64_$__$$_getmut$$pint64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_GETMUT$$PINT64
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_GETMUT$$PINT64,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_GETMUT$$PINT64:
.Lc265:
# [720] begin
	movq	%rdi,%rax
# Var $self located in register rax
# Var $result located in register rax
.Lc266:
# [722] end;
	ret
.Lc264:

.section .text.n_nextpas.core.atomic.types$_$tatomicint64_$__$$_intoinner$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_INTOINNER$$INT64
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_INTOINNER$$INT64,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICINT64_$__$$_INTOINNER$$INT64:
.Lc268:
# Var $self located in register rdi
# [725] begin
# Var $result located in register rax
# [726] Result := FValue;
	movq	(%rdi),%rax
.Lc269:
# [727] end;
	ret
.Lc267:

.section .text.n_nextpas.core.atomic.types$_$tatomicuint64_$__$$_create$qword$$tatomicuint64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_CREATE$QWORD$$TATOMICUINT64
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_CREATE$QWORD$$TATOMICUINT64,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_CREATE$QWORD$$TATOMICUINT64:
.Lc271:
# Var $result located in register rax
# [732] begin
	movq	%rdi,%rax
# Var AValue located in register rax
# Var AValue located in register rax
.Lc272:
# [734] end;
	ret
.Lc270:

.section .text.n_nextpas.core.atomic.types$_$tatomicuint64_$__$$_is_lock_free$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_IS_LOCK_FREE$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_IS_LOCK_FREE$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_IS_LOCK_FREE$$BOOLEAN:
.Lc274:
# [737] begin
# Var $result located in register al
# [741] Result := True;
	movb	$1,%al
.Lc275:
# [745] end;
	ret
.Lc273:

.section .text.n_nextpas.core.atomic.types$_$tatomicuint64_$__$$_load$memory_order_t$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_LOAD$MEMORY_ORDER_T$$QWORD
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_LOAD$MEMORY_ORDER_T$$QWORD,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_LOAD$MEMORY_ORDER_T$$QWORD:
.Lc277:
# [748] begin
	pushq	%rbx
.Lc278:
	pushq	%r12
.Lc279:
	pushq	%rax
.Lc280:
	movq	%rdi,%rbx
# Var $self located in register rbx
# Var AOrder located in register esi
# [749] Result := atomic_load_64(FValue, AOrder);
	movq	(%rdi),%r12
	testl	%esi,%esi
	je	.Lj380
	subl	$1,%esi
	jb	.Lj379
	subl	$1,%esi
	jbe	.Lj381
	subl	$1,%esi
	je	.Lj382
	subl	$1,%esi
	je	.Lj381
	subl	$1,%esi
	je	.Lj383
	jmp	.Lj379
	.balign 16,0x90
.Lj380:
	movq	(%rbx),%r12
	jmp	.Lj379
	.balign 16,0x90
.Lj381:
	movq	(%rbx),%r12
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	jmp	.Lj379
	.balign 16,0x90
.Lj382:
	movq	(%rbx),%r12
	jmp	.Lj379
	.balign 16,0x90
.Lj383:
	movq	(%rbx),%r12
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	.balign 16,0x90
.Lj379:
# Var $result located in register rax
	movq	%r12,%rax
# [750] end;
	popq	%rcx
	popq	%r12
.Lc281:
	popq	%rbx
.Lc282:
	ret
.Lc276:

.section .text.n_nextpas.core.atomic.types$_$tatomicuint64_$__$$_store$qword$memory_order_t,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_STORE$QWORD$MEMORY_ORDER_T
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_STORE$QWORD$MEMORY_ORDER_T,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_STORE$QWORD$MEMORY_ORDER_T:
.Lc284:
# Temps allocated between rsp+0 and rsp+8
# [753] begin
	pushq	%rbx
.Lc285:
	pushq	%r12
.Lc286:
	pushq	%rax
.Lc287:
	movq	%rdi,%rbx
# Var $self located in register rbx
# Var AValue located in register rsi
# Var AOrder located in register edx
# Var AValue located in register rsi
# [754] atomic_store_64(FValue, AValue, AOrder);
	movq	%rsi,(%rsp)
	movq	(%rsp),%r12
	subl	$2,%edx
	jbe	.Lj387
	subl	$1,%edx
	subl	$1,%edx
	jbe	.Lj388
	subl	$1,%edx
	je	.Lj389
	jmp	.Lj386
	.balign 16,0x90
.Lj387:
	movq	%r12,(%rbx)
	jmp	.Lj386
	.balign 16,0x90
.Lj388:
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	movq	%r12,(%rbx)
	jmp	.Lj386
	.balign 16,0x90
.Lj389:
	movq	%rbx,%rdi
	movq	%r12,%rsi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE64$INT64$INT64$$INT64
	.balign 16,0x90
.Lj386:
# [755] end;
	popq	%rcx
	popq	%r12
.Lc288:
	popq	%rbx
.Lc289:
	ret
.Lc283:

.section .text.n_nextpas.core.atomic.types$_$tatomicuint64_$__$$_exchange$qword$memory_order_t$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_EXCHANGE$QWORD$MEMORY_ORDER_T$$QWORD
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_EXCHANGE$QWORD$MEMORY_ORDER_T$$QWORD,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_EXCHANGE$QWORD$MEMORY_ORDER_T$$QWORD:
.Lc291:
# Temps allocated between rsp+0 and rsp+8
# [758] begin
	pushq	%rax
.Lc292:
# Var $self located in register rdi
# Var AValue located in register rsi
# Var AOrder located in register edx
# [759] Result := atomic_exchange_64(FValue, AValue, AOrder);
	movq	%rsi,(%rsp)
	movq	(%rsp),%rsi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE64$INT64$INT64$$INT64
# Var $result located in register rax
# [760] end;
	popq	%rcx
.Lc293:
	ret
.Lc290:

.section .text.n_nextpas.core.atomic.types$_$tatomicuint64_$__$$_compareexchangestrong$hcqmoaqkijrf,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_COMPAREEXCHANGESTRONG$hcQMoaqKIJRF
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_COMPAREEXCHANGESTRONG$hcQMoaqKIJRF,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_COMPAREEXCHANGESTRONG$hcQMoaqKIJRF:
.Lc295:
# Temps allocated between rsp+0 and rsp+8
# [767] begin
	pushq	%rbx
.Lc296:
	leaq	-16(%rsp),%rsp
.Lc297:
# Var $self located in register rdi
	movq	%rsi,%rbx
# Var AExpected located in register rbx
# Var ADesired located in register rdx
# Var AOrder located in register ecx
# [768] LSuccessOrder := _cas_success_order(AOrder);
	movl	$2,%eax
	cmpl	$1,%ecx
	cmovnel	%ecx,%eax
# Var LSuccessOrder located in register eax
# [769] LFailureOrder := _cas_failure_order(LSuccessOrder);
	movl	%eax,%ecx
	testl	%eax,%eax
	je	.Lj402
	subl	$2,%ecx
	je	.Lj403
	subl	$1,%ecx
	je	.Lj404
	subl	$1,%ecx
	je	.Lj405
	subl	$1,%ecx
	je	.Lj406
	jmp	.Lj401
	.balign 16,0x90
.Lj402:
	xorl	%ecx,%ecx
	jmp	.Lj400
	.balign 16,0x90
.Lj403:
	movl	$2,%ecx
	jmp	.Lj400
	.balign 16,0x90
.Lj404:
	xorl	%ecx,%ecx
	jmp	.Lj400
	.balign 16,0x90
.Lj405:
	movl	$2,%ecx
	jmp	.Lj400
	.balign 16,0x90
.Lj406:
	movl	$5,%ecx
	jmp	.Lj400
	.balign 16,0x90
.Lj401:
	xorl	%ecx,%ecx
	.balign 16,0x90
.Lj400:
# Var LFailureOrder located in register ecx
# [770] Result := atomic_compare_exchange_strong_64(FValue, AExpected, ADesired, LSuccessOrder, LFailureOrder);
	movq	%rdx,(%rsp)
	movq	(%rsp),%rsi
	movq	(%rbx),%rdx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	movq	%rax,%rdx
	cmpq	(%rbx),%rax
	seteb	%al
	je	.Lj407
	movq	%rdx,(%rbx)
	.p2align 4,,10
	.p2align 3
.Lj407:
# Var $result located in register al
# [771] end;
	leaq	16(%rsp),%rsp
	popq	%rbx
.Lc298:
	ret
.Lc294:

.section .text.n_nextpas.core.atomic.types$_$tatomicuint64_$__$$_compareexchangeweak$hcqmoaqkijrf,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_COMPAREEXCHANGEWEAK$hcQMoaqKIJRF
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_COMPAREEXCHANGEWEAK$hcQMoaqKIJRF,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_COMPAREEXCHANGEWEAK$hcQMoaqKIJRF:
.Lc300:
# Temps allocated between rsp+0 and rsp+8
# [778] begin
	pushq	%rbx
.Lc301:
	leaq	-16(%rsp),%rsp
.Lc302:
# Var $self located in register rdi
	movq	%rsi,%rbx
# Var AExpected located in register rbx
# Var ADesired located in register rdx
# Var AOrder located in register ecx
# [779] LSuccessOrder := _cas_success_order(AOrder);
	movl	$2,%eax
	cmpl	$1,%ecx
	cmovnel	%ecx,%eax
# Var LSuccessOrder located in register eax
# [780] LFailureOrder := _cas_failure_order(LSuccessOrder);
	movl	%eax,%ecx
	testl	%eax,%eax
	je	.Lj422
	subl	$2,%ecx
	je	.Lj423
	subl	$1,%ecx
	je	.Lj424
	subl	$1,%ecx
	je	.Lj425
	subl	$1,%ecx
	je	.Lj426
	jmp	.Lj421
	.balign 16,0x90
.Lj422:
	xorl	%ecx,%ecx
	jmp	.Lj420
	.balign 16,0x90
.Lj423:
	movl	$2,%ecx
	jmp	.Lj420
	.balign 16,0x90
.Lj424:
	xorl	%ecx,%ecx
	jmp	.Lj420
	.balign 16,0x90
.Lj425:
	movl	$2,%ecx
	jmp	.Lj420
	.balign 16,0x90
.Lj426:
	movl	$5,%ecx
	jmp	.Lj420
	.balign 16,0x90
.Lj421:
	xorl	%ecx,%ecx
	.balign 16,0x90
.Lj420:
# Var LFailureOrder located in register ecx
# [781] Result := atomic_compare_exchange_weak_64(FValue, AExpected, ADesired, LSuccessOrder, LFailureOrder);
	movq	%rdx,(%rsp)
	movq	(%rsp),%rsi
	movq	(%rbx),%rdx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	movq	%rax,%rdx
	cmpq	(%rbx),%rax
	seteb	%al
	je	.Lj427
	movq	%rdx,(%rbx)
	.p2align 4,,10
	.p2align 3
.Lj427:
# Var $result located in register al
# [782] end;
	leaq	16(%rsp),%rsp
	popq	%rbx
.Lc303:
	ret
.Lc299:

.section .text.n_nextpas.core.atomic.types$_$tatomicuint64_$__$$_fetchadd$qword$memory_order_t$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_FETCHADD$QWORD$MEMORY_ORDER_T$$QWORD
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_FETCHADD$QWORD$MEMORY_ORDER_T$$QWORD,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_FETCHADD$QWORD$MEMORY_ORDER_T$$QWORD:
.Lc305:
# Temps allocated between rsp+0 and rsp+8
# [785] begin
	pushq	%rax
.Lc306:
# Var $self located in register rdi
# Var ADelta located in register rsi
# Var AOrder located in register edx
# [786] Result := atomic_fetch_add_64(FValue, ADelta, AOrder);
	movq	%rsi,(%rsp)
	movq	(%rsp),%rsi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGEADD64$INT64$INT64$$INT64
# Var $result located in register rax
# [787] end;
	popq	%rcx
.Lc307:
	ret
.Lc304:

.section .text.n_nextpas.core.atomic.types$_$tatomicuint64_$__$$_fetchsub$qword$memory_order_t$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_FETCHSUB$QWORD$MEMORY_ORDER_T$$QWORD
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_FETCHSUB$QWORD$MEMORY_ORDER_T$$QWORD,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_FETCHSUB$QWORD$MEMORY_ORDER_T$$QWORD:
.Lc309:
# Temps allocated between rsp+0 and rsp+8
# [790] begin
	pushq	%rax
.Lc310:
# Var $self located in register rdi
# Var ADelta located in register rsi
# Var AOrder located in register edx
# [791] Result := atomic_fetch_sub_64(FValue, ADelta, AOrder);
	movq	%rsi,(%rsp)
	movq	(%rsp),%rsi
	negq	%rsi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGEADD64$INT64$INT64$$INT64
# Var $result located in register rax
# [792] end;
	popq	%rcx
.Lc311:
	ret
.Lc308:

.section .text.n_nextpas.core.atomic.types$_$tatomicuint64_$__$$_fetchand$qword$memory_order_t$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_FETCHAND$QWORD$MEMORY_ORDER_T$$QWORD
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_FETCHAND$QWORD$MEMORY_ORDER_T$$QWORD,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_FETCHAND$QWORD$MEMORY_ORDER_T$$QWORD:
.Lc313:
# Temps allocated between rsp+0 and rsp+8
# [795] begin
	pushq	%rbx
.Lc314:
	pushq	%r12
.Lc315:
	pushq	%r13
.Lc316:
	pushq	%r14
.Lc317:
	pushq	%rax
.Lc318:
	movq	%rdi,%rbx
# Var $self located in register rbx
# Var AMask located in register rsi
# Var AOrder located in register edx
# [796] Result := atomic_fetch_and_64(FValue, AMask, AOrder);
	movq	%rsi,(%rsp)
	movq	(%rsp),%r12
	.p2align 4,,10
	.p2align 3
.Lj450:
	movq	(%rbx),%r13
	movq	%r13,%r14
	andq	%r12,%r14
	movq	%rbx,%rdi
	movq	%r13,%rdx
	movq	%r14,%rsi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	cmpq	%r13,%rax
	je	.Lj452
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
	jmp	.Lj450
.Lj452:
	movq	%r13,%rax
# Var $result located in register rax
# [797] end;
	popq	%rcx
	popq	%r14
.Lc319:
	popq	%r13
.Lc320:
	popq	%r12
.Lc321:
	popq	%rbx
.Lc322:
	ret
.Lc312:

.section .text.n_nextpas.core.atomic.types$_$tatomicuint64_$__$$_fetchor$qword$memory_order_t$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_FETCHOR$QWORD$MEMORY_ORDER_T$$QWORD
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_FETCHOR$QWORD$MEMORY_ORDER_T$$QWORD,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_FETCHOR$QWORD$MEMORY_ORDER_T$$QWORD:
.Lc324:
# Temps allocated between rsp+0 and rsp+8
# [800] begin
	pushq	%rbx
.Lc325:
	pushq	%r12
.Lc326:
	pushq	%r13
.Lc327:
	pushq	%r14
.Lc328:
	pushq	%rax
.Lc329:
	movq	%rdi,%rbx
# Var $self located in register rbx
# Var AMask located in register rsi
# Var AOrder located in register edx
# [801] Result := atomic_fetch_or_64(FValue, AMask, AOrder);
	movq	%rsi,(%rsp)
	movq	(%rsp),%r12
	.p2align 4,,10
	.p2align 3
.Lj460:
	movq	(%rbx),%r13
	movq	%r13,%r14
	orq	%r12,%r14
	movq	%rbx,%rdi
	movq	%r13,%rdx
	movq	%r14,%rsi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	cmpq	%r13,%rax
	je	.Lj462
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
	jmp	.Lj460
.Lj462:
	movq	%r13,%rax
# Var $result located in register rax
# [802] end;
	popq	%rcx
	popq	%r14
.Lc330:
	popq	%r13
.Lc331:
	popq	%r12
.Lc332:
	popq	%rbx
.Lc333:
	ret
.Lc323:

.section .text.n_nextpas.core.atomic.types$_$tatomicuint64_$__$$_fetchxor$qword$memory_order_t$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_FETCHXOR$QWORD$MEMORY_ORDER_T$$QWORD
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_FETCHXOR$QWORD$MEMORY_ORDER_T$$QWORD,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_FETCHXOR$QWORD$MEMORY_ORDER_T$$QWORD:
.Lc335:
# Temps allocated between rsp+0 and rsp+8
# [805] begin
	pushq	%rbx
.Lc336:
	pushq	%r12
.Lc337:
	pushq	%r13
.Lc338:
	pushq	%r14
.Lc339:
	pushq	%rax
.Lc340:
	movq	%rdi,%rbx
# Var $self located in register rbx
# Var AMask located in register rsi
# Var AOrder located in register edx
# [806] Result := atomic_fetch_xor_64(FValue, AMask, AOrder);
	movq	%rsi,(%rsp)
	movq	(%rsp),%r12
	.p2align 4,,10
	.p2align 3
.Lj470:
	movq	(%rbx),%r13
	movq	%r13,%r14
	xorq	%r12,%r14
	movq	%rbx,%rdi
	movq	%r13,%rdx
	movq	%r14,%rsi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	cmpq	%r13,%rax
	je	.Lj472
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
	jmp	.Lj470
.Lj472:
	movq	%r13,%rax
# Var $result located in register rax
# [807] end;
	popq	%rcx
	popq	%r14
.Lc341:
	popq	%r13
.Lc342:
	popq	%r12
.Lc343:
	popq	%rbx
.Lc344:
	ret
.Lc334:

.section .text.n_nextpas.core.atomic.types$_$tatomicuint64_$__$$_increment$memory_order_t$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_INCREMENT$MEMORY_ORDER_T$$QWORD
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_INCREMENT$MEMORY_ORDER_T$$QWORD,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_INCREMENT$MEMORY_ORDER_T$$QWORD:
.Lc346:
# Temps allocated between rsp+0 and rsp+8
# [810] begin
	pushq	%rax
.Lc347:
# Var $self located in register rdi
	movl	%esi,%eax
# Var AOrder located in register eax
# [811] Result := FetchAdd(1, AOrder) + 1;
	movl	$1,%esi
	movq	$1,(%rsp)
	call	SYSTEM_$$_INTERLOCKEDEXCHANGEADD64$INT64$INT64$$INT64
	addq	$1,%rax
# Var $result located in register rax
# [812] end;
	popq	%rcx
.Lc348:
	ret
.Lc345:

.section .text.n_nextpas.core.atomic.types$_$tatomicuint64_$__$$_decrement$memory_order_t$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_DECREMENT$MEMORY_ORDER_T$$QWORD
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_DECREMENT$MEMORY_ORDER_T$$QWORD,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_DECREMENT$MEMORY_ORDER_T$$QWORD:
.Lc350:
# Temps allocated between rsp+0 and rsp+8
# [815] begin
	pushq	%rax
.Lc351:
# Var $self located in register rdi
	movl	%esi,%eax
# Var AOrder located in register eax
# [816] Result := FetchSub(1, AOrder) - 1;
	movl	$1,%esi
	movq	$1,(%rsp)
	negq	%rsi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGEADD64$INT64$INT64$$INT64
	subq	$1,%rax
# Var $result located in register rax
# [817] end;
	popq	%rcx
.Lc352:
	ret
.Lc349:

.section .text.n_nextpas.core.atomic.types$_$tatomicuint64_$__$$_getmut$$puint64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_GETMUT$$PUINT64
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_GETMUT$$PUINT64,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_GETMUT$$PUINT64:
.Lc354:
# [820] begin
	movq	%rdi,%rax
# Var $self located in register rax
# Var $result located in register rax
.Lc355:
# [822] end;
	ret
.Lc353:

.section .text.n_nextpas.core.atomic.types$_$tatomicuint64_$__$$_intoinner$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_INTOINNER$$QWORD
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_INTOINNER$$QWORD,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUINT64_$__$$_INTOINNER$$QWORD:
.Lc357:
# Var $self located in register rdi
# [825] begin
# Var $result located in register rax
# [826] Result := FValue;
	movq	(%rdi),%rax
.Lc358:
# [827] end;
	ret
.Lc356:

.section .text.n_nextpas.core.atomic.types$_$tatomicbool_$__$$_create$boolean$$tatomicbool,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICBOOL_$__$$_CREATE$BOOLEAN$$TATOMICBOOL
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICBOOL_$__$$_CREATE$BOOLEAN$$TATOMICBOOL,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICBOOL_$__$$_CREATE$BOOLEAN$$TATOMICBOOL:
.Lc360:
# Var $result located in register eax
# Var AValue located in register dil
# [833] begin
# [835] Result.FValue := 1
	xorl	%eax,%eax
# [834] if AValue then
	testb	%dil,%dil
	setneb	%al
.Lc361:
# [838] end;
	ret
.Lc359:

.section .text.n_nextpas.core.atomic.types$_$tatomicbool_$__$$_is_lock_free$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICBOOL_$__$$_IS_LOCK_FREE$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICBOOL_$__$$_IS_LOCK_FREE$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICBOOL_$__$$_IS_LOCK_FREE$$BOOLEAN:
.Lc363:
# [841] begin
# Var $result located in register al
# [843] Result := True;
	movb	$1,%al
.Lc364:
# [844] end;
	ret
.Lc362:

.section .text.n_nextpas.core.atomic.types$_$tatomicbool_$__$$_load$memory_order_t$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICBOOL_$__$$_LOAD$MEMORY_ORDER_T$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICBOOL_$__$$_LOAD$MEMORY_ORDER_T$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICBOOL_$__$$_LOAD$MEMORY_ORDER_T$$BOOLEAN:
.Lc366:
# [847] begin
	pushq	%rbx
.Lc367:
	pushq	%r12
.Lc368:
	pushq	%rax
.Lc369:
	movq	%rdi,%rbx
# Var $self located in register rbx
# Var AOrder located in register esi
# [848] Result := atomic_load(FValue, AOrder) <> 0;
	movl	(%rdi),%r12d
	testl	%esi,%esi
	je	.Lj500
	subl	$1,%esi
	jb	.Lj499
	subl	$1,%esi
	jbe	.Lj501
	subl	$1,%esi
	je	.Lj502
	subl	$1,%esi
	je	.Lj501
	subl	$1,%esi
	je	.Lj503
	jmp	.Lj499
	.balign 16,0x90
.Lj500:
	movl	(%rbx),%r12d
	jmp	.Lj499
	.balign 16,0x90
.Lj501:
	movl	(%rbx),%r12d
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	jmp	.Lj499
	.balign 16,0x90
.Lj502:
	movl	(%rbx),%r12d
	jmp	.Lj499
	.balign 16,0x90
.Lj503:
	movl	(%rbx),%r12d
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	.balign 16,0x90
.Lj499:
	testl	%r12d,%r12d
# Var $result located in register al
	setneb	%al
# [849] end;
	popq	%rcx
	popq	%r12
.Lc370:
	popq	%rbx
.Lc371:
	ret
.Lc365:

.section .text.n_nextpas.core.atomic.types$_$tatomicbool_$__$$_store$boolean$memory_order_t,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICBOOL_$__$$_STORE$BOOLEAN$MEMORY_ORDER_T
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICBOOL_$__$$_STORE$BOOLEAN$MEMORY_ORDER_T,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICBOOL_$__$$_STORE$BOOLEAN$MEMORY_ORDER_T:
.Lc373:
# [852] begin
	pushq	%rbx
.Lc374:
	pushq	%r12
.Lc375:
	pushq	%rax
.Lc376:
	movq	%rdi,%rbx
# Var $self located in register rbx
# Var AValue located in register sil
	movl	%edx,%r12d
# Var AOrder located in register r12d
# [853] if AValue then
	testb	%sil,%sil
	je	.Lj507
# [854] atomic_store(FValue, 1, AOrder)
	movl	%r12d,%eax
	subl	$2,%eax
	jbe	.Lj509
	subl	$1,%eax
	subl	$1,%eax
	jbe	.Lj510
	subl	$1,%eax
	je	.Lj511
	jmp	.Lj512
	.balign 16,0x90
.Lj509:
	movl	$1,(%rbx)
	jmp	.Lj512
	.balign 16,0x90
.Lj510:
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	movl	$1,(%rbx)
	jmp	.Lj512
	.balign 16,0x90
.Lj511:
	movq	%rbx,%rdi
	movl	$1,%esi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE$LONGINT$LONGINT$$LONGINT
	jmp	.Lj512
	.p2align 4,,10
	.p2align 3
.Lj507:
# [856] atomic_store(FValue, 0, AOrder);
	subl	$2,%r12d
	jbe	.Lj514
	subl	$1,%r12d
	subl	$1,%r12d
	jbe	.Lj515
	subl	$1,%r12d
	je	.Lj516
	jmp	.Lj512
	.balign 16,0x90
.Lj514:
	movl	$0,(%rbx)
	jmp	.Lj512
	.balign 16,0x90
.Lj515:
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	movl	$0,(%rbx)
	jmp	.Lj512
	.balign 16,0x90
.Lj516:
	movq	%rbx,%rdi
	xorl	%esi,%esi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE$LONGINT$LONGINT$$LONGINT
	.balign 16,0x90
.Lj512:
# [857] end;
	popq	%rcx
	popq	%r12
.Lc377:
	popq	%rbx
.Lc378:
	ret
.Lc372:

.section .text.n_nextpas.core.atomic.types$_$tatomicbool_$__$$_exchange$boolean$memory_order_t$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICBOOL_$__$$_EXCHANGE$BOOLEAN$MEMORY_ORDER_T$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICBOOL_$__$$_EXCHANGE$BOOLEAN$MEMORY_ORDER_T$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICBOOL_$__$$_EXCHANGE$BOOLEAN$MEMORY_ORDER_T$$BOOLEAN:
.Lc380:
# [862] begin
	pushq	%rax
.Lc381:
# Var LNew located in register esi
# Var $self located in register rdi
# Var AValue located in register sil
# Var AOrder located in register edx
# [863] if AValue then LNew := 1 else LNew := 0;
	testb	%sil,%sil
	movl	$0,%esi
	setneb	%sil
# [864] Result := atomic_exchange(FValue, LNew, AOrder) <> 0;
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE$LONGINT$LONGINT$$LONGINT
	testl	%eax,%eax
# Var $result located in register al
	setneb	%al
# [865] end;
	popq	%rcx
.Lc382:
	ret
.Lc379:

.section .text.n_nextpas.core.atomic.types$_$tatomicbool_$__$$_compareexchangestrong$hewqgdywmw6h,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICBOOL_$__$$_COMPAREEXCHANGESTRONG$hewQgdywmw6H
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICBOOL_$__$$_COMPAREEXCHANGESTRONG$hewQgdywmw6H,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICBOOL_$__$$_COMPAREEXCHANGESTRONG$hewQgdywmw6H:
.Lc384:
# [873] begin
	pushq	%rbx
.Lc385:
	leaq	-16(%rsp),%rsp
.Lc386:
# Var LExp located at rsp+0, size=OS_S32
# Var LDes located in register esi
# Var $self located in register rdi
	movq	%rsi,%rbx
# Var AExpected located in register rbx
# Var ADesired located in register dl
# Var AOrder located in register ecx
# [874] if AExpected then LExp := 1 else LExp := 0;
	cmpb	$0,(%rsi)
	je	.Lj528
	movl	$1,(%rsp)
	jmp	.Lj529
	.p2align 4,,10
	.p2align 3
.Lj528:
	movl	$0,(%rsp)
.Lj529:
# [875] if ADesired then LDes := 1 else LDes := 0;
	xorl	%esi,%esi
	testb	%dl,%dl
	setneb	%sil
# [877] LSuccessOrder := _cas_success_order(AOrder);
	movl	$2,%eax
	cmpl	$1,%ecx
	cmovnel	%ecx,%eax
# Var LSuccessOrder located in register eax
# [878] LFailureOrder := _cas_failure_order(LSuccessOrder);
	movl	%eax,%edx
	testl	%eax,%eax
	je	.Lj538
	subl	$2,%edx
	je	.Lj539
	subl	$1,%edx
	je	.Lj540
	subl	$1,%edx
	je	.Lj541
	subl	$1,%edx
	je	.Lj542
	jmp	.Lj537
	.balign 16,0x90
.Lj538:
	xorl	%edx,%edx
	jmp	.Lj536
	.balign 16,0x90
.Lj539:
	movl	$2,%edx
	jmp	.Lj536
	.balign 16,0x90
.Lj540:
	xorl	%edx,%edx
	jmp	.Lj536
	.balign 16,0x90
.Lj541:
	movl	$2,%edx
	jmp	.Lj536
	.balign 16,0x90
.Lj542:
	movl	$5,%edx
	jmp	.Lj536
	.balign 16,0x90
.Lj537:
	xorl	%edx,%edx
	.balign 16,0x90
.Lj536:
# Var LFailureOrder located in register edx
# [880] Result := atomic_compare_exchange_strong(FValue, LExp, LDes, LSuccessOrder, LFailureOrder);
	movl	(%rsp),%edx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE$LONGINT$LONGINT$LONGINT$$LONGINT
	movl	%eax,%edx
	cmpl	(%rsp),%eax
	seteb	%al
	je	.Lj551
	movl	%edx,(%rsp)
.Lj551:
# Var $result located in register al
# [881] AExpected := LExp <> 0;
	cmpl	$0,(%rsp)
	setneb	(%rbx)
# [882] end;
	leaq	16(%rsp),%rsp
	popq	%rbx
.Lc387:
	ret
.Lc383:

.section .text.n_nextpas.core.atomic.types$_$tatomicbool_$__$$_compareexchangeweak$hewqgdywmw6h,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICBOOL_$__$$_COMPAREEXCHANGEWEAK$hewQgdywmw6H
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICBOOL_$__$$_COMPAREEXCHANGEWEAK$hewQgdywmw6H,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICBOOL_$__$$_COMPAREEXCHANGEWEAK$hewQgdywmw6H:
.Lc389:
# [890] begin
	pushq	%rbx
.Lc390:
	leaq	-16(%rsp),%rsp
.Lc391:
# Var LExp located at rsp+0, size=OS_S32
# Var LDes located in register esi
# Var $self located in register rdi
	movq	%rsi,%rbx
# Var AExpected located in register rbx
# Var ADesired located in register dl
# Var AOrder located in register ecx
# [891] if AExpected then LExp := 1 else LExp := 0;
	cmpb	$0,(%rsi)
	je	.Lj555
	movl	$1,(%rsp)
	jmp	.Lj556
	.p2align 4,,10
	.p2align 3
.Lj555:
	movl	$0,(%rsp)
.Lj556:
# [892] if ADesired then LDes := 1 else LDes := 0;
	xorl	%esi,%esi
	testb	%dl,%dl
	setneb	%sil
# [894] LSuccessOrder := _cas_success_order(AOrder);
	movl	$2,%eax
	cmpl	$1,%ecx
	cmovnel	%ecx,%eax
# Var LSuccessOrder located in register eax
# [895] LFailureOrder := _cas_failure_order(LSuccessOrder);
	movl	%eax,%edx
	testl	%eax,%eax
	je	.Lj565
	subl	$2,%edx
	je	.Lj566
	subl	$1,%edx
	je	.Lj567
	subl	$1,%edx
	je	.Lj568
	subl	$1,%edx
	je	.Lj569
	jmp	.Lj564
	.balign 16,0x90
.Lj565:
	xorl	%edx,%edx
	jmp	.Lj563
	.balign 16,0x90
.Lj566:
	movl	$2,%edx
	jmp	.Lj563
	.balign 16,0x90
.Lj567:
	xorl	%edx,%edx
	jmp	.Lj563
	.balign 16,0x90
.Lj568:
	movl	$2,%edx
	jmp	.Lj563
	.balign 16,0x90
.Lj569:
	movl	$5,%edx
	jmp	.Lj563
	.balign 16,0x90
.Lj564:
	xorl	%edx,%edx
	.balign 16,0x90
.Lj563:
# Var LFailureOrder located in register edx
# [897] Result := atomic_compare_exchange_weak(FValue, LExp, LDes, LSuccessOrder, LFailureOrder);
	movl	(%rsp),%edx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE$LONGINT$LONGINT$LONGINT$$LONGINT
	movl	%eax,%edx
	cmpl	(%rsp),%eax
	seteb	%al
	je	.Lj578
	movl	%edx,(%rsp)
.Lj578:
# Var $result located in register al
# [898] AExpected := LExp <> 0;
	cmpl	$0,(%rsp)
	setneb	(%rbx)
# [899] end;
	leaq	16(%rsp),%rsp
	popq	%rbx
.Lc392:
	ret
.Lc388:

.section .text.n_nextpas.core.atomic.types$_$tatomicbool_$__$$_fetchand$boolean$memory_order_t$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICBOOL_$__$$_FETCHAND$BOOLEAN$MEMORY_ORDER_T$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICBOOL_$__$$_FETCHAND$BOOLEAN$MEMORY_ORDER_T$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICBOOL_$__$$_FETCHAND$BOOLEAN$MEMORY_ORDER_T$$BOOLEAN:
.Lc394:
# [904] begin
	pushq	%rbx
.Lc395:
	pushq	%r12
.Lc396:
	pushq	%r13
.Lc397:
	pushq	%r14
.Lc398:
	pushq	%rax
.Lc399:
# Var LMask located in register r13d
	movq	%rdi,%rbx
# Var $self located in register rbx
# Var AValue located in register sil
# Var AOrder located in register edx
# [905] if AValue then LMask := 1 else LMask := 0;
	xorl	%r13d,%r13d
	testb	%sil,%sil
	setneb	%r13b
	.p2align 4,,10
	.p2align 3
.Lj587:
# [906] Result := atomic_fetch_and(FValue, LMask, AOrder) <> 0;
	movl	(%rbx),%r12d
	movl	%r12d,%r14d
	andl	%r13d,%r14d
	movq	%rbx,%rdi
	movl	%r12d,%edx
	movl	%r14d,%esi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE$LONGINT$LONGINT$LONGINT$$LONGINT
	cmpl	%r12d,%eax
	je	.Lj589
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
	jmp	.Lj587
.Lj589:
	testl	%r12d,%r12d
# Var $result located in register al
	setneb	%al
# [907] end;
	popq	%rcx
	popq	%r14
.Lc400:
	popq	%r13
.Lc401:
	popq	%r12
.Lc402:
	popq	%rbx
.Lc403:
	ret
.Lc393:

.section .text.n_nextpas.core.atomic.types$_$tatomicbool_$__$$_fetchor$boolean$memory_order_t$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICBOOL_$__$$_FETCHOR$BOOLEAN$MEMORY_ORDER_T$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICBOOL_$__$$_FETCHOR$BOOLEAN$MEMORY_ORDER_T$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICBOOL_$__$$_FETCHOR$BOOLEAN$MEMORY_ORDER_T$$BOOLEAN:
.Lc405:
# [912] begin
	pushq	%rbx
.Lc406:
	pushq	%r12
.Lc407:
	pushq	%r13
.Lc408:
	pushq	%r14
.Lc409:
	pushq	%rax
.Lc410:
# Var LMask located in register r13d
	movq	%rdi,%rbx
# Var $self located in register rbx
# Var AValue located in register sil
# Var AOrder located in register edx
# [913] if AValue then LMask := 1 else LMask := 0;
	xorl	%r13d,%r13d
	testb	%sil,%sil
	setneb	%r13b
	.p2align 4,,10
	.p2align 3
.Lj600:
# [914] Result := atomic_fetch_or(FValue, LMask, AOrder) <> 0;
	movl	(%rbx),%r12d
	movl	%r12d,%r14d
	orl	%r13d,%r14d
	movq	%rbx,%rdi
	movl	%r12d,%edx
	movl	%r14d,%esi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE$LONGINT$LONGINT$LONGINT$$LONGINT
	cmpl	%r12d,%eax
	je	.Lj602
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
	jmp	.Lj600
.Lj602:
	testl	%r12d,%r12d
# Var $result located in register al
	setneb	%al
# [915] end;
	popq	%rcx
	popq	%r14
.Lc411:
	popq	%r13
.Lc412:
	popq	%r12
.Lc413:
	popq	%rbx
.Lc414:
	ret
.Lc404:

.section .text.n_nextpas.core.atomic.types$_$tatomicbool_$__$$_fetchxor$boolean$memory_order_t$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICBOOL_$__$$_FETCHXOR$BOOLEAN$MEMORY_ORDER_T$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICBOOL_$__$$_FETCHXOR$BOOLEAN$MEMORY_ORDER_T$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICBOOL_$__$$_FETCHXOR$BOOLEAN$MEMORY_ORDER_T$$BOOLEAN:
.Lc416:
# [920] begin
	pushq	%rbx
.Lc417:
	pushq	%r12
.Lc418:
	pushq	%r13
.Lc419:
	pushq	%r14
.Lc420:
	pushq	%rax
.Lc421:
# Var LMask located in register r13d
	movq	%rdi,%rbx
# Var $self located in register rbx
# Var AValue located in register sil
# Var AOrder located in register edx
# [921] if AValue then LMask := 1 else LMask := 0;
	xorl	%r13d,%r13d
	testb	%sil,%sil
	setneb	%r13b
	.p2align 4,,10
	.p2align 3
.Lj613:
# [922] Result := atomic_fetch_xor(FValue, LMask, AOrder) <> 0;
	movl	(%rbx),%r12d
	movl	%r12d,%r14d
	xorl	%r13d,%r14d
	movq	%rbx,%rdi
	movl	%r12d,%edx
	movl	%r14d,%esi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE$LONGINT$LONGINT$LONGINT$$LONGINT
	cmpl	%r12d,%eax
	je	.Lj615
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
	jmp	.Lj613
.Lj615:
	testl	%r12d,%r12d
# Var $result located in register al
	setneb	%al
# [923] end;
	popq	%rcx
	popq	%r14
.Lc422:
	popq	%r13
.Lc423:
	popq	%r12
.Lc424:
	popq	%rbx
.Lc425:
	ret
.Lc415:

.section .text.n_nextpas.core.atomic.types$_$tatomicbool_$__$$_fetchnand$boolean$memory_order_t$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICBOOL_$__$$_FETCHNAND$BOOLEAN$MEMORY_ORDER_T$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICBOOL_$__$$_FETCHNAND$BOOLEAN$MEMORY_ORDER_T$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICBOOL_$__$$_FETCHNAND$BOOLEAN$MEMORY_ORDER_T$$BOOLEAN:
.Lc427:
# [930] begin
	pushq	%rbx
.Lc428:
	pushq	%r12
.Lc429:
	pushq	%r13
.Lc430:
	pushq	%r14
.Lc431:
	pushq	%r15
.Lc432:
	leaq	-16(%rsp),%rsp
.Lc433:
# Var LOld located at rsp+0, size=OS_S32
# Var LNew located in register r14d
# Var LMask located in register ebx
	movq	%rdi,%r15
# Var $self located in register r15
# Var AValue located in register sil
# Var AOrder located in register edx
# [931] if AValue then LMask := 1 else LMask := 0;
	xorl	%ebx,%ebx
	testb	%sil,%sil
	setneb	%bl
# [933] LSuccessOrder := _cas_success_order(AOrder);
	movl	$2,%eax
	cmpl	$1,%edx
	cmovnel	%edx,%eax
# Var LSuccessOrder located in register r12d
	movl	%eax,%r12d
# [934] LFailureOrder := _cas_failure_order(LSuccessOrder);
	testl	%eax,%eax
	je	.Lj628
	subl	$2,%eax
	je	.Lj629
	subl	$1,%eax
	je	.Lj630
	subl	$1,%eax
	je	.Lj631
	subl	$1,%eax
	je	.Lj632
	jmp	.Lj627
	.balign 16,0x90
.Lj628:
	xorl	%eax,%eax
	jmp	.Lj626
	.balign 16,0x90
.Lj629:
	movl	$2,%eax
	jmp	.Lj626
	.balign 16,0x90
.Lj630:
	xorl	%eax,%eax
	jmp	.Lj626
	.balign 16,0x90
.Lj631:
	movl	$2,%eax
	jmp	.Lj626
	.balign 16,0x90
.Lj632:
	movl	$5,%eax
	jmp	.Lj626
	.balign 16,0x90
.Lj627:
	xorl	%eax,%eax
	.balign 16,0x90
.Lj626:
# Var LFailureOrder located in register r13d
	movl	%eax,%r13d
# [936] LOld := atomic_load(FValue, mo_relaxed);
	movl	(%r15),%eax
	movl	%eax,(%rsp)
	.p2align 4,,10
	.p2align 3
.Lj634:
# [938] LNew := not (LOld and LMask) and 1;  // NAND ............ 0/1
	movl	(%rsp),%eax
	andl	%ebx,%eax
	notl	%eax
	andl	$1,%eax
	movl	%eax,%r14d
# [939] if atomic_compare_exchange_weak(FValue, LOld, LNew, LSuccessOrder, LFailureOrder) then
	movl	(%rsp),%edx
	movq	%r15,%rdi
	movl	%r14d,%esi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE$LONGINT$LONGINT$LONGINT$$LONGINT
	cmpl	(%rsp),%eax
	seteb	%dl
	je	.Lj636
	movl	%eax,(%rsp)
	testb	%dl,%dl
	jne	.Lj636
# [941] cpu_pause;
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
# [942] until False;
	jmp	.Lj634
.Lj636:
# [944] Result := LOld <> 0;
	cmpl	$0,(%rsp)
# Var $result located in register al
	setneb	%al
# [945] end;
	leaq	16(%rsp),%rsp
	popq	%r15
.Lc434:
	popq	%r14
.Lc435:
	popq	%r13
.Lc436:
	popq	%r12
.Lc437:
	popq	%rbx
.Lc438:
	ret
.Lc426:

.section .text.n_nextpas.core.atomic.types$_$tatomicbool_$__$$_getmut$$plongint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICBOOL_$__$$_GETMUT$$PLONGINT
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICBOOL_$__$$_GETMUT$$PLONGINT,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICBOOL_$__$$_GETMUT$$PLONGINT:
.Lc440:
# [948] begin
	movq	%rdi,%rax
# Var $self located in register rax
# Var $result located in register rax
.Lc441:
# [950] end;
	ret
.Lc439:

.section .text.n_nextpas.core.atomic.types$_$tatomicbool_$__$$_intoinner$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICBOOL_$__$$_INTOINNER$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICBOOL_$__$$_INTOINNER$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICBOOL_$__$$_INTOINNER$$BOOLEAN:
.Lc443:
# Var $self located in register rdi
# [953] begin
# [954] Result := FValue <> 0;
	cmpl	$0,(%rdi)
# Var $result located in register al
	setneb	%al
.Lc444:
# [955] end;
	ret
.Lc442:

.section .text.n_nextpas.core.atomic.types$_$tatomicflag_$__$$_create$boolean$$tatomicflag,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICFLAG_$__$$_CREATE$BOOLEAN$$TATOMICFLAG
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICFLAG_$__$$_CREATE$BOOLEAN$$TATOMICFLAG,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICFLAG_$__$$_CREATE$BOOLEAN$$TATOMICFLAG:
.Lc446:
# Var $result located in register eax
# Var AInitialValue located in register dil
# [960] begin
# [962] Result.FValue := 1
	xorl	%eax,%eax
# [961] if AInitialValue then
	testb	%dil,%dil
	setneb	%al
.Lc447:
# [965] end;
	ret
.Lc445:

.section .text.n_nextpas.core.atomic.types$_$tatomicflag_$__$$_is_lock_free$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICFLAG_$__$$_IS_LOCK_FREE$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICFLAG_$__$$_IS_LOCK_FREE$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICFLAG_$__$$_IS_LOCK_FREE$$BOOLEAN:
.Lc449:
# [968] begin
# Var $result located in register al
# [970] Result := True;
	movb	$1,%al
.Lc450:
# [971] end;
	ret
.Lc448:

.section .text.n_nextpas.core.atomic.types$_$tatomicflag_$__$$_test_and_set$memory_order_t$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICFLAG_$__$$_TEST_AND_SET$MEMORY_ORDER_T$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICFLAG_$__$$_TEST_AND_SET$MEMORY_ORDER_T$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICFLAG_$__$$_TEST_AND_SET$MEMORY_ORDER_T$$BOOLEAN:
.Lc452:
# [974] begin
	pushq	%rax
.Lc453:
# Var $self located in register rdi
# Var AOrder located in register esi
# [976] Result := atomic_exchange(FValue, 1, AOrder) <> 0;
	movl	$1,%esi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE$LONGINT$LONGINT$$LONGINT
	testl	%eax,%eax
# Var $result located in register al
	setneb	%al
# [977] end;
	popq	%rcx
.Lc454:
	ret
.Lc451:

.section .text.n_nextpas.core.atomic.types$_$tatomicflag_$__$$_clear$memory_order_t,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICFLAG_$__$$_CLEAR$MEMORY_ORDER_T
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICFLAG_$__$$_CLEAR$MEMORY_ORDER_T,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICFLAG_$__$$_CLEAR$MEMORY_ORDER_T:
.Lc456:
# [980] begin
	pushq	%rbx
.Lc457:
	movq	%rdi,%rbx
# Var $self located in register rbx
# Var AOrder located in register esi
# [982] atomic_store(FValue, 0, AOrder);
	subl	$2,%esi
	jbe	.Lj667
	subl	$1,%esi
	subl	$1,%esi
	jbe	.Lj668
	subl	$1,%esi
	je	.Lj669
	jmp	.Lj666
	.balign 16,0x90
.Lj667:
	movl	$0,(%rbx)
	jmp	.Lj666
	.balign 16,0x90
.Lj668:
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	movl	$0,(%rbx)
	jmp	.Lj666
	.balign 16,0x90
.Lj669:
	movq	%rbx,%rdi
	xorl	%esi,%esi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE$LONGINT$LONGINT$$LONGINT
	.balign 16,0x90
.Lj666:
# [983] end;
	popq	%rbx
.Lc458:
	ret
.Lc455:

.section .text.n_nextpas.core.atomic.types$_$tatomicflag_$__$$_test$memory_order_t$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICFLAG_$__$$_TEST$MEMORY_ORDER_T$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICFLAG_$__$$_TEST$MEMORY_ORDER_T$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICFLAG_$__$$_TEST$MEMORY_ORDER_T$$BOOLEAN:
.Lc460:
# [986] begin
	pushq	%rbx
.Lc461:
	pushq	%r12
.Lc462:
	pushq	%rax
.Lc463:
	movq	%rdi,%rbx
# Var $self located in register rbx
# Var AOrder located in register esi
# [988] Result := atomic_load(FValue, AOrder) <> 0;
	movl	(%rdi),%r12d
	testl	%esi,%esi
	je	.Lj674
	subl	$1,%esi
	jb	.Lj673
	subl	$1,%esi
	jbe	.Lj675
	subl	$1,%esi
	je	.Lj676
	subl	$1,%esi
	je	.Lj675
	subl	$1,%esi
	je	.Lj677
	jmp	.Lj673
	.balign 16,0x90
.Lj674:
	movl	(%rbx),%r12d
	jmp	.Lj673
	.balign 16,0x90
.Lj675:
	movl	(%rbx),%r12d
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	jmp	.Lj673
	.balign 16,0x90
.Lj676:
	movl	(%rbx),%r12d
	jmp	.Lj673
	.balign 16,0x90
.Lj677:
	movl	(%rbx),%r12d
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	.balign 16,0x90
.Lj673:
	testl	%r12d,%r12d
# Var $result located in register al
	setneb	%al
# [989] end;
	popq	%rcx
	popq	%r12
.Lc464:
	popq	%rbx
.Lc465:
	ret
.Lc459:

.section .text.n_nextpas.core.atomic.types$_$tatomicisize_$__$$_create$int64$$tatomicisize,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_CREATE$INT64$$TATOMICISIZE
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_CREATE$INT64$$TATOMICISIZE,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_CREATE$INT64$$TATOMICISIZE:
.Lc467:
# Var $result located in register rax
# [994] begin
	movq	%rdi,%rax
# Var AValue located in register rax
# Var AValue located in register rax
.Lc468:
# [996] end;
	ret
.Lc466:

.section .text.n_nextpas.core.atomic.types$_$tatomicisize_$__$$_is_lock_free$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_IS_LOCK_FREE$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_IS_LOCK_FREE$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_IS_LOCK_FREE$$BOOLEAN:
.Lc470:
# [999] begin
# Var $result located in register al
# [1001] Result := True;
	movb	$1,%al
.Lc471:
# [1002] end;
	ret
.Lc469:

.section .text.n_nextpas.core.atomic.types$_$tatomicisize_$__$$_load$memory_order_t$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_LOAD$MEMORY_ORDER_T$$INT64
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_LOAD$MEMORY_ORDER_T$$INT64,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_LOAD$MEMORY_ORDER_T$$INT64:
.Lc473:
# [1005] begin
	pushq	%rbx
.Lc474:
	pushq	%r12
.Lc475:
	pushq	%rax
.Lc476:
	movq	%rdi,%rbx
# Var $self located in register rbx
# Var AOrder located in register esi
# [1009] Result := PtrInt(atomic_load_64(PInt64(@FValue)^, AOrder));
	movq	(%rdi),%r12
	testl	%esi,%esi
	je	.Lj686
	subl	$1,%esi
	jb	.Lj685
	subl	$1,%esi
	jbe	.Lj687
	subl	$1,%esi
	je	.Lj688
	subl	$1,%esi
	je	.Lj687
	subl	$1,%esi
	je	.Lj689
	jmp	.Lj685
	.balign 16,0x90
.Lj686:
	movq	(%rbx),%r12
	jmp	.Lj685
	.balign 16,0x90
.Lj687:
	movq	(%rbx),%r12
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	jmp	.Lj685
	.balign 16,0x90
.Lj688:
	movq	(%rbx),%r12
	jmp	.Lj685
	.balign 16,0x90
.Lj689:
	movq	(%rbx),%r12
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	.balign 16,0x90
.Lj685:
# Var $result located in register rax
	movq	%r12,%rax
# [1011] end;
	popq	%rcx
	popq	%r12
.Lc477:
	popq	%rbx
.Lc478:
	ret
.Lc472:

.section .text.n_nextpas.core.atomic.types$_$tatomicisize_$__$$_store$int64$memory_order_t,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_STORE$INT64$MEMORY_ORDER_T
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_STORE$INT64$MEMORY_ORDER_T,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_STORE$INT64$MEMORY_ORDER_T:
.Lc480:
# [1014] begin
	pushq	%rbx
.Lc481:
	pushq	%r12
.Lc482:
	pushq	%rax
.Lc483:
	movq	%rdi,%rbx
# Var $self located in register rbx
	movq	%rsi,%r12
# Var AValue located in register r12
# Var AOrder located in register edx
# [1018] atomic_store_64(PInt64(@FValue)^, Int64(AValue), AOrder);
	subl	$2,%edx
	jbe	.Lj693
	subl	$1,%edx
	subl	$1,%edx
	jbe	.Lj694
	subl	$1,%edx
	je	.Lj695
	jmp	.Lj692
	.balign 16,0x90
.Lj693:
	movq	%r12,(%rbx)
	jmp	.Lj692
	.balign 16,0x90
.Lj694:
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	movq	%r12,(%rbx)
	jmp	.Lj692
	.balign 16,0x90
.Lj695:
	movq	%rbx,%rdi
	movq	%r12,%rsi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE64$INT64$INT64$$INT64
	.balign 16,0x90
.Lj692:
# [1020] end;
	popq	%rcx
	popq	%r12
.Lc484:
	popq	%rbx
.Lc485:
	ret
.Lc479:

.section .text.n_nextpas.core.atomic.types$_$tatomicisize_$__$$_exchange$int64$memory_order_t$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_EXCHANGE$INT64$MEMORY_ORDER_T$$INT64
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_EXCHANGE$INT64$MEMORY_ORDER_T$$INT64,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_EXCHANGE$INT64$MEMORY_ORDER_T$$INT64:
.Lc487:
# [1023] begin
	pushq	%rax
.Lc488:
# Var $self located in register rdi
# Var AValue located in register rsi
# Var AOrder located in register edx
# [1027] Result := PtrInt(atomic_exchange_64(PInt64(@FValue)^, Int64(AValue), AOrder));
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE64$INT64$INT64$$INT64
# Var $result located in register rax
# [1029] end;
	popq	%rcx
.Lc489:
	ret
.Lc486:

.section .text.n_nextpas.core.atomic.types$_$tatomicisize_$__$$_compareexchangestrong$h4fud1znbg1g,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_COMPAREEXCHANGESTRONG$h4FUD1ZNBG1G
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_COMPAREEXCHANGESTRONG$h4FUD1ZNBG1G,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_COMPAREEXCHANGESTRONG$h4FUD1ZNBG1G:
.Lc491:
# [1050] begin
	pushq	%rbx
.Lc492:
	leaq	-16(%rsp),%rsp
.Lc493:
# Var LExp located at rsp+0, size=OS_S64
# Var $self located in register rdi
	movq	%rsi,%rbx
# Var AExpected located in register rbx
	movq	%rdx,%rsi
# Var ADesired located in register rsi
# Var AOrder located in register ecx
# [1051] LExp := Int64(AExpected);
	movq	(%rbx),%rax
	movq	%rax,(%rsp)
# [1052] LSuccessOrder := _cas_success_order(AOrder);
	movl	$2,%eax
	cmpl	$1,%ecx
	cmovnel	%ecx,%eax
# Var LSuccessOrder located in register eax
# [1053] LFailureOrder := _cas_failure_order(LSuccessOrder);
	movl	%eax,%edx
	testl	%eax,%eax
	je	.Lj708
	subl	$2,%edx
	je	.Lj709
	subl	$1,%edx
	je	.Lj710
	subl	$1,%edx
	je	.Lj711
	subl	$1,%edx
	je	.Lj712
	jmp	.Lj707
	.balign 16,0x90
.Lj708:
	xorl	%edx,%edx
	jmp	.Lj706
	.balign 16,0x90
.Lj709:
	movl	$2,%edx
	jmp	.Lj706
	.balign 16,0x90
.Lj710:
	xorl	%edx,%edx
	jmp	.Lj706
	.balign 16,0x90
.Lj711:
	movl	$2,%edx
	jmp	.Lj706
	.balign 16,0x90
.Lj712:
	movl	$5,%edx
	jmp	.Lj706
	.balign 16,0x90
.Lj707:
	xorl	%edx,%edx
	.balign 16,0x90
.Lj706:
# Var LFailureOrder located in register edx
# [1054] Result := atomic_compare_exchange_strong_64(PInt64(@FValue)^, LExp, Int64(ADesired), LSuccessOrder, LFailureOrder);
	movq	(%rsp),%rdx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	movq	%rax,%rdx
	cmpq	(%rsp),%rax
	seteb	%al
	je	.Lj713
	movq	%rdx,(%rsp)
	.p2align 4,,10
	.p2align 3
.Lj713:
# Var $result located in register al
# [1055] AExpected := PtrInt(LExp);
	movq	(%rsp),%rdx
	movq	%rdx,(%rbx)
# [1056] end;
	leaq	16(%rsp),%rsp
	popq	%rbx
.Lc494:
	ret
.Lc490:

.section .text.n_nextpas.core.atomic.types$_$tatomicisize_$__$$_compareexchangeweak$h4fud1znbg1g,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_COMPAREEXCHANGEWEAK$h4FUD1ZNBG1G
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_COMPAREEXCHANGEWEAK$h4FUD1ZNBG1G,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_COMPAREEXCHANGEWEAK$h4FUD1ZNBG1G:
.Lc496:
# [1078] begin
	pushq	%rbx
.Lc497:
	leaq	-16(%rsp),%rsp
.Lc498:
# Var LExp located at rsp+0, size=OS_S64
# Var $self located in register rdi
	movq	%rsi,%rbx
# Var AExpected located in register rbx
	movq	%rdx,%rsi
# Var ADesired located in register rsi
# Var AOrder located in register ecx
# [1079] LExp := Int64(AExpected);
	movq	(%rbx),%rax
	movq	%rax,(%rsp)
# [1080] LSuccessOrder := _cas_success_order(AOrder);
	movl	$2,%eax
	cmpl	$1,%ecx
	cmovnel	%ecx,%eax
# Var LSuccessOrder located in register eax
# [1081] LFailureOrder := _cas_failure_order(LSuccessOrder);
	movl	%eax,%edx
	testl	%eax,%eax
	je	.Lj728
	subl	$2,%edx
	je	.Lj729
	subl	$1,%edx
	je	.Lj730
	subl	$1,%edx
	je	.Lj731
	subl	$1,%edx
	je	.Lj732
	jmp	.Lj727
	.balign 16,0x90
.Lj728:
	xorl	%edx,%edx
	jmp	.Lj726
	.balign 16,0x90
.Lj729:
	movl	$2,%edx
	jmp	.Lj726
	.balign 16,0x90
.Lj730:
	xorl	%edx,%edx
	jmp	.Lj726
	.balign 16,0x90
.Lj731:
	movl	$2,%edx
	jmp	.Lj726
	.balign 16,0x90
.Lj732:
	movl	$5,%edx
	jmp	.Lj726
	.balign 16,0x90
.Lj727:
	xorl	%edx,%edx
	.balign 16,0x90
.Lj726:
# Var LFailureOrder located in register edx
# [1082] Result := atomic_compare_exchange_weak_64(PInt64(@FValue)^, LExp, Int64(ADesired), LSuccessOrder, LFailureOrder);
	movq	(%rsp),%rdx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	movq	%rax,%rdx
	cmpq	(%rsp),%rax
	seteb	%al
	je	.Lj733
	movq	%rdx,(%rsp)
	.p2align 4,,10
	.p2align 3
.Lj733:
# Var $result located in register al
# [1083] AExpected := PtrInt(LExp);
	movq	(%rsp),%rdx
	movq	%rdx,(%rbx)
# [1084] end;
	leaq	16(%rsp),%rsp
	popq	%rbx
.Lc499:
	ret
.Lc495:

.section .text.n_nextpas.core.atomic.types$_$tatomicisize_$__$$_fetchadd$int64$memory_order_t$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_FETCHADD$INT64$MEMORY_ORDER_T$$INT64
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_FETCHADD$INT64$MEMORY_ORDER_T$$INT64,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_FETCHADD$INT64$MEMORY_ORDER_T$$INT64:
.Lc501:
# [1088] begin
	pushq	%rax
.Lc502:
# Var $self located in register rdi
# Var ADelta located in register rsi
# Var AOrder located in register edx
# [1092] Result := PtrInt(atomic_fetch_add_64(PInt64(@FValue)^, Int64(ADelta), AOrder));
	call	SYSTEM_$$_INTERLOCKEDEXCHANGEADD64$INT64$INT64$$INT64
# Var $result located in register rax
# [1094] end;
	popq	%rcx
.Lc503:
	ret
.Lc500:

.section .text.n_nextpas.core.atomic.types$_$tatomicisize_$__$$_fetchsub$int64$memory_order_t$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_FETCHSUB$INT64$MEMORY_ORDER_T$$INT64
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_FETCHSUB$INT64$MEMORY_ORDER_T$$INT64,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_FETCHSUB$INT64$MEMORY_ORDER_T$$INT64:
.Lc505:
# [1097] begin
	pushq	%rax
.Lc506:
# Var $self located in register rdi
# Var ADelta located in register rsi
# Var AOrder located in register edx
# [1101] Result := PtrInt(atomic_fetch_sub_64(PInt64(@FValue)^, Int64(ADelta), AOrder));
	negq	%rsi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGEADD64$INT64$INT64$$INT64
# Var $result located in register rax
# [1103] end;
	popq	%rcx
.Lc507:
	ret
.Lc504:

.section .text.n_nextpas.core.atomic.types$_$tatomicisize_$__$$_fetchand$int64$memory_order_t$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_FETCHAND$INT64$MEMORY_ORDER_T$$INT64
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_FETCHAND$INT64$MEMORY_ORDER_T$$INT64,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_FETCHAND$INT64$MEMORY_ORDER_T$$INT64:
.Lc509:
# [1106] begin
	pushq	%rbx
.Lc510:
	pushq	%r12
.Lc511:
	pushq	%r13
.Lc512:
	pushq	%r14
.Lc513:
	pushq	%rax
.Lc514:
	movq	%rdi,%rbx
# Var $self located in register rbx
	movq	%rsi,%r12
# Var AMask located in register r12
# Var AOrder located in register edx
	.p2align 4,,10
	.p2align 3
.Lj756:
# [1110] Result := PtrInt(atomic_fetch_and_64(PInt64(@FValue)^, Int64(AMask), AOrder));
	movq	(%rbx),%r13
	movq	%r13,%r14
	andq	%r12,%r14
	movq	%rbx,%rdi
	movq	%r13,%rdx
	movq	%r14,%rsi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	cmpq	%r13,%rax
	je	.Lj758
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
	jmp	.Lj756
.Lj758:
	movq	%r13,%rax
# Var $result located in register rax
# [1112] end;
	popq	%rcx
	popq	%r14
.Lc515:
	popq	%r13
.Lc516:
	popq	%r12
.Lc517:
	popq	%rbx
.Lc518:
	ret
.Lc508:

.section .text.n_nextpas.core.atomic.types$_$tatomicisize_$__$$_fetchor$int64$memory_order_t$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_FETCHOR$INT64$MEMORY_ORDER_T$$INT64
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_FETCHOR$INT64$MEMORY_ORDER_T$$INT64,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_FETCHOR$INT64$MEMORY_ORDER_T$$INT64:
.Lc520:
# [1115] begin
	pushq	%rbx
.Lc521:
	pushq	%r12
.Lc522:
	pushq	%r13
.Lc523:
	pushq	%r14
.Lc524:
	pushq	%rax
.Lc525:
	movq	%rdi,%rbx
# Var $self located in register rbx
	movq	%rsi,%r12
# Var AMask located in register r12
# Var AOrder located in register edx
	.p2align 4,,10
	.p2align 3
.Lj766:
# [1119] Result := PtrInt(atomic_fetch_or_64(PInt64(@FValue)^, Int64(AMask), AOrder));
	movq	(%rbx),%r13
	movq	%r13,%r14
	orq	%r12,%r14
	movq	%rbx,%rdi
	movq	%r13,%rdx
	movq	%r14,%rsi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	cmpq	%r13,%rax
	je	.Lj768
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
	jmp	.Lj766
.Lj768:
	movq	%r13,%rax
# Var $result located in register rax
# [1121] end;
	popq	%rcx
	popq	%r14
.Lc526:
	popq	%r13
.Lc527:
	popq	%r12
.Lc528:
	popq	%rbx
.Lc529:
	ret
.Lc519:

.section .text.n_nextpas.core.atomic.types$_$tatomicisize_$__$$_fetchxor$int64$memory_order_t$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_FETCHXOR$INT64$MEMORY_ORDER_T$$INT64
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_FETCHXOR$INT64$MEMORY_ORDER_T$$INT64,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_FETCHXOR$INT64$MEMORY_ORDER_T$$INT64:
.Lc531:
# [1124] begin
	pushq	%rbx
.Lc532:
	pushq	%r12
.Lc533:
	pushq	%r13
.Lc534:
	pushq	%r14
.Lc535:
	pushq	%rax
.Lc536:
	movq	%rdi,%rbx
# Var $self located in register rbx
	movq	%rsi,%r12
# Var AMask located in register r12
# Var AOrder located in register edx
	.p2align 4,,10
	.p2align 3
.Lj776:
# [1128] Result := PtrInt(atomic_fetch_xor_64(PInt64(@FValue)^, Int64(AMask), AOrder));
	movq	(%rbx),%r13
	movq	%r13,%r14
	xorq	%r12,%r14
	movq	%rbx,%rdi
	movq	%r13,%rdx
	movq	%r14,%rsi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	cmpq	%r13,%rax
	je	.Lj778
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
	jmp	.Lj776
.Lj778:
	movq	%r13,%rax
# Var $result located in register rax
# [1130] end;
	popq	%rcx
	popq	%r14
.Lc537:
	popq	%r13
.Lc538:
	popq	%r12
.Lc539:
	popq	%rbx
.Lc540:
	ret
.Lc530:

.section .text.n_nextpas.core.atomic.types$_$tatomicisize_$__$$_increment$memory_order_t$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_INCREMENT$MEMORY_ORDER_T$$INT64
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_INCREMENT$MEMORY_ORDER_T$$INT64,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_INCREMENT$MEMORY_ORDER_T$$INT64:
.Lc542:
# [1133] begin
	pushq	%rax
.Lc543:
# Var $self located in register rdi
# Var AOrder located in register esi
# [1134] Result := FetchAdd(1, AOrder) + 1;
	movl	$1,%esi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGEADD64$INT64$INT64$$INT64
	addq	$1,%rax
# Var $result located in register rax
# [1135] end;
	popq	%rcx
.Lc544:
	ret
.Lc541:

.section .text.n_nextpas.core.atomic.types$_$tatomicisize_$__$$_decrement$memory_order_t$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_DECREMENT$MEMORY_ORDER_T$$INT64
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_DECREMENT$MEMORY_ORDER_T$$INT64,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_DECREMENT$MEMORY_ORDER_T$$INT64:
.Lc546:
# [1138] begin
	pushq	%rax
.Lc547:
# Var $self located in register rdi
# Var AOrder located in register esi
# [1139] Result := FetchSub(1, AOrder) - 1;
	movq	$-1,%rsi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGEADD64$INT64$INT64$$INT64
	subq	$1,%rax
# Var $result located in register rax
# [1140] end;
	popq	%rcx
.Lc548:
	ret
.Lc545:

.section .text.n_nextpas.core.atomic.types$_$tatomicisize_$__$$_getmut$$pptrint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_GETMUT$$PPTRINT
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_GETMUT$$PPTRINT,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_GETMUT$$PPTRINT:
.Lc550:
# [1143] begin
	movq	%rdi,%rax
# Var $self located in register rax
# Var $result located in register rax
.Lc551:
# [1145] end;
	ret
.Lc549:

.section .text.n_nextpas.core.atomic.types$_$tatomicisize_$__$$_intoinner$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_INTOINNER$$INT64
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_INTOINNER$$INT64,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICISIZE_$__$$_INTOINNER$$INT64:
.Lc553:
# Var $self located in register rdi
# [1148] begin
# Var $result located in register rax
# [1149] Result := FValue;
	movq	(%rdi),%rax
.Lc554:
# [1150] end;
	ret
.Lc552:

.section .text.n_nextpas.core.atomic.types$_$tatomicusize_$__$$_create$qword$$tatomicusize,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_CREATE$QWORD$$TATOMICUSIZE
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_CREATE$QWORD$$TATOMICUSIZE,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_CREATE$QWORD$$TATOMICUSIZE:
.Lc556:
# Var $result located in register rax
# [1155] begin
	movq	%rdi,%rax
# Var AValue located in register rax
# Var AValue located in register rax
.Lc557:
# [1157] end;
	ret
.Lc555:

.section .text.n_nextpas.core.atomic.types$_$tatomicusize_$__$$_is_lock_free$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_IS_LOCK_FREE$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_IS_LOCK_FREE$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_IS_LOCK_FREE$$BOOLEAN:
.Lc559:
# [1160] begin
# Var $result located in register al
# [1162] Result := True;
	movb	$1,%al
.Lc560:
# [1163] end;
	ret
.Lc558:

.section .text.n_nextpas.core.atomic.types$_$tatomicusize_$__$$_load$memory_order_t$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_LOAD$MEMORY_ORDER_T$$QWORD
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_LOAD$MEMORY_ORDER_T$$QWORD,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_LOAD$MEMORY_ORDER_T$$QWORD:
.Lc562:
# [1166] begin
	pushq	%rbx
.Lc563:
	pushq	%r12
.Lc564:
	pushq	%rax
.Lc565:
	movq	%rdi,%rbx
# Var $self located in register rbx
# Var AOrder located in register esi
# [1170] Result := PtrUInt(atomic_load_64(PUInt64(@FValue)^, AOrder));
	movq	(%rdi),%r12
	testl	%esi,%esi
	je	.Lj803
	subl	$1,%esi
	jb	.Lj802
	subl	$1,%esi
	jbe	.Lj804
	subl	$1,%esi
	je	.Lj805
	subl	$1,%esi
	je	.Lj804
	subl	$1,%esi
	je	.Lj806
	jmp	.Lj802
	.balign 16,0x90
.Lj803:
	movq	(%rbx),%r12
	jmp	.Lj802
	.balign 16,0x90
.Lj804:
	movq	(%rbx),%r12
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	jmp	.Lj802
	.balign 16,0x90
.Lj805:
	movq	(%rbx),%r12
	jmp	.Lj802
	.balign 16,0x90
.Lj806:
	movq	(%rbx),%r12
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	.balign 16,0x90
.Lj802:
	movq	%r12,%rax
# Var $result located in register rax
# [1172] end;
	popq	%rcx
	popq	%r12
.Lc566:
	popq	%rbx
.Lc567:
	ret
.Lc561:

.section .text.n_nextpas.core.atomic.types$_$tatomicusize_$__$$_store$qword$memory_order_t,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_STORE$QWORD$MEMORY_ORDER_T
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_STORE$QWORD$MEMORY_ORDER_T,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_STORE$QWORD$MEMORY_ORDER_T:
.Lc569:
# Temps allocated between rsp+0 and rsp+8
# [1175] begin
	pushq	%rbx
.Lc570:
	pushq	%r12
.Lc571:
	pushq	%rax
.Lc572:
	movq	%rdi,%rbx
# Var $self located in register rbx
# Var AValue located in register rsi
# Var AOrder located in register edx
# Var AValue located in register rsi
# [1179] atomic_store_64(PUInt64(@FValue)^, UInt64(AValue), AOrder);
	movq	%rsi,(%rsp)
	movq	(%rsp),%r12
	subl	$2,%edx
	jbe	.Lj810
	subl	$1,%edx
	subl	$1,%edx
	jbe	.Lj811
	subl	$1,%edx
	je	.Lj812
	jmp	.Lj809
	.balign 16,0x90
.Lj810:
	movq	%r12,(%rbx)
	jmp	.Lj809
	.balign 16,0x90
.Lj811:
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	movq	%r12,(%rbx)
	jmp	.Lj809
	.balign 16,0x90
.Lj812:
	movq	%rbx,%rdi
	movq	%r12,%rsi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE64$INT64$INT64$$INT64
	.balign 16,0x90
.Lj809:
# [1181] end;
	popq	%rcx
	popq	%r12
.Lc573:
	popq	%rbx
.Lc574:
	ret
.Lc568:

.section .text.n_nextpas.core.atomic.types$_$tatomicusize_$__$$_exchange$qword$memory_order_t$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_EXCHANGE$QWORD$MEMORY_ORDER_T$$QWORD
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_EXCHANGE$QWORD$MEMORY_ORDER_T$$QWORD,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_EXCHANGE$QWORD$MEMORY_ORDER_T$$QWORD:
.Lc576:
# Temps allocated between rsp+0 and rsp+8
# [1184] begin
	pushq	%rax
.Lc577:
# Var $self located in register rdi
# Var AValue located in register rsi
# Var AOrder located in register edx
# [1188] Result := PtrUInt(atomic_exchange_64(PUInt64(@FValue)^, UInt64(AValue), AOrder));
	movq	%rsi,(%rsp)
	movq	(%rsp),%rsi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE64$INT64$INT64$$INT64
# Var $result located in register rax
# [1190] end;
	popq	%rcx
.Lc578:
	ret
.Lc575:

.section .text.n_nextpas.core.atomic.types$_$tatomicusize_$__$$_compareexchangestrong$hcqmoaqkijrf,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_COMPAREEXCHANGESTRONG$hcQMoaqKIJRF
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_COMPAREEXCHANGESTRONG$hcQMoaqKIJRF,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_COMPAREEXCHANGESTRONG$hcQMoaqKIJRF:
.Lc580:
# Temps allocated between rsp+8 and rsp+16
# [1211] begin
	pushq	%rbx
.Lc581:
	pushq	%r12
.Lc582:
	leaq	-24(%rsp),%rsp
.Lc583:
# Var LExp located at rsp+0, size=OS_64
# Var $self located in register rdi
	movq	%rsi,%rbx
# Var AExpected located in register rbx
# Var ADesired located in register rdx
# Var AOrder located in register ecx
# [1212] LExp := UInt64(AExpected);
	movq	(%rsi),%rax
	movq	%rax,(%rsp)
# [1213] LSuccessOrder := _cas_success_order(AOrder);
	movl	$2,%eax
	cmpl	$1,%ecx
	cmovnel	%ecx,%eax
# Var LSuccessOrder located in register eax
# [1214] LFailureOrder := _cas_failure_order(LSuccessOrder);
	movl	%eax,%ecx
	testl	%eax,%eax
	je	.Lj825
	subl	$2,%ecx
	je	.Lj826
	subl	$1,%ecx
	je	.Lj827
	subl	$1,%ecx
	je	.Lj828
	subl	$1,%ecx
	je	.Lj829
	jmp	.Lj824
	.balign 16,0x90
.Lj825:
	xorl	%ecx,%ecx
	jmp	.Lj823
	.balign 16,0x90
.Lj826:
	movl	$2,%ecx
	jmp	.Lj823
	.balign 16,0x90
.Lj827:
	xorl	%ecx,%ecx
	jmp	.Lj823
	.balign 16,0x90
.Lj828:
	movl	$2,%ecx
	jmp	.Lj823
	.balign 16,0x90
.Lj829:
	movl	$5,%ecx
	jmp	.Lj823
	.balign 16,0x90
.Lj824:
	xorl	%ecx,%ecx
	.balign 16,0x90
.Lj823:
# Var LFailureOrder located in register ecx
# [1215] Result := atomic_compare_exchange_strong_64(PUInt64(@FValue)^, LExp, UInt64(ADesired), LSuccessOrder, LFailureOrder);
	movq	%rdx,8(%rsp)
	movq	8(%rsp),%rsi
	movq	%rsp,%r12
	movq	(%rsp),%rdx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	movq	%rax,%rdx
	cmpq	(%r12),%rax
	seteb	%al
	je	.Lj830
	movq	%rdx,(%r12)
	.p2align 4,,10
	.p2align 3
.Lj830:
# Var $result located in register al
# [1216] AExpected := PtrUInt(LExp);
	movq	(%rsp),%rdx
	movq	%rdx,(%rbx)
# [1217] end;
	leaq	24(%rsp),%rsp
	popq	%r12
.Lc584:
	popq	%rbx
.Lc585:
	ret
.Lc579:

.section .text.n_nextpas.core.atomic.types$_$tatomicusize_$__$$_compareexchangeweak$hcqmoaqkijrf,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_COMPAREEXCHANGEWEAK$hcQMoaqKIJRF
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_COMPAREEXCHANGEWEAK$hcQMoaqKIJRF,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_COMPAREEXCHANGEWEAK$hcQMoaqKIJRF:
.Lc587:
# Temps allocated between rsp+8 and rsp+16
# [1239] begin
	pushq	%rbx
.Lc588:
	pushq	%r12
.Lc589:
	leaq	-24(%rsp),%rsp
.Lc590:
# Var LExp located at rsp+0, size=OS_64
# Var $self located in register rdi
	movq	%rsi,%rbx
# Var AExpected located in register rbx
# Var ADesired located in register rdx
# Var AOrder located in register ecx
# [1240] LExp := UInt64(AExpected);
	movq	(%rsi),%rax
	movq	%rax,(%rsp)
# [1241] LSuccessOrder := _cas_success_order(AOrder);
	movl	$2,%eax
	cmpl	$1,%ecx
	cmovnel	%ecx,%eax
# Var LSuccessOrder located in register eax
# [1242] LFailureOrder := _cas_failure_order(LSuccessOrder);
	movl	%eax,%ecx
	testl	%eax,%eax
	je	.Lj845
	subl	$2,%ecx
	je	.Lj846
	subl	$1,%ecx
	je	.Lj847
	subl	$1,%ecx
	je	.Lj848
	subl	$1,%ecx
	je	.Lj849
	jmp	.Lj844
	.balign 16,0x90
.Lj845:
	xorl	%ecx,%ecx
	jmp	.Lj843
	.balign 16,0x90
.Lj846:
	movl	$2,%ecx
	jmp	.Lj843
	.balign 16,0x90
.Lj847:
	xorl	%ecx,%ecx
	jmp	.Lj843
	.balign 16,0x90
.Lj848:
	movl	$2,%ecx
	jmp	.Lj843
	.balign 16,0x90
.Lj849:
	movl	$5,%ecx
	jmp	.Lj843
	.balign 16,0x90
.Lj844:
	xorl	%ecx,%ecx
	.balign 16,0x90
.Lj843:
# Var LFailureOrder located in register ecx
# [1243] Result := atomic_compare_exchange_weak_64(PUInt64(@FValue)^, LExp, UInt64(ADesired), LSuccessOrder, LFailureOrder);
	movq	%rdx,8(%rsp)
	movq	8(%rsp),%rsi
	movq	%rsp,%r12
	movq	(%rsp),%rdx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	movq	%rax,%rdx
	cmpq	(%r12),%rax
	seteb	%al
	je	.Lj850
	movq	%rdx,(%r12)
	.p2align 4,,10
	.p2align 3
.Lj850:
# Var $result located in register al
# [1244] AExpected := PtrUInt(LExp);
	movq	(%rsp),%rdx
	movq	%rdx,(%rbx)
# [1245] end;
	leaq	24(%rsp),%rsp
	popq	%r12
.Lc591:
	popq	%rbx
.Lc592:
	ret
.Lc586:

.section .text.n_nextpas.core.atomic.types$_$tatomicusize_$__$$_fetchadd$qword$memory_order_t$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_FETCHADD$QWORD$MEMORY_ORDER_T$$QWORD
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_FETCHADD$QWORD$MEMORY_ORDER_T$$QWORD,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_FETCHADD$QWORD$MEMORY_ORDER_T$$QWORD:
.Lc594:
# Temps allocated between rsp+0 and rsp+8
# [1249] begin
	pushq	%rax
.Lc595:
# Var $self located in register rdi
# Var ADelta located in register rsi
# Var AOrder located in register edx
# [1253] Result := PtrUInt(atomic_fetch_add_64(PUInt64(@FValue)^, UInt64(ADelta), AOrder));
	movq	%rsi,(%rsp)
	movq	(%rsp),%rsi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGEADD64$INT64$INT64$$INT64
# Var $result located in register rax
# [1255] end;
	popq	%rcx
.Lc596:
	ret
.Lc593:

.section .text.n_nextpas.core.atomic.types$_$tatomicusize_$__$$_fetchsub$qword$memory_order_t$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_FETCHSUB$QWORD$MEMORY_ORDER_T$$QWORD
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_FETCHSUB$QWORD$MEMORY_ORDER_T$$QWORD,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_FETCHSUB$QWORD$MEMORY_ORDER_T$$QWORD:
.Lc598:
# Temps allocated between rsp+0 and rsp+8
# [1258] begin
	pushq	%rax
.Lc599:
# Var $self located in register rdi
# Var ADelta located in register rsi
# Var AOrder located in register edx
# [1262] Result := PtrUInt(atomic_fetch_sub_64(PUInt64(@FValue)^, UInt64(ADelta), AOrder));
	movq	%rsi,(%rsp)
	movq	(%rsp),%rsi
	negq	%rsi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGEADD64$INT64$INT64$$INT64
# Var $result located in register rax
# [1264] end;
	popq	%rcx
.Lc600:
	ret
.Lc597:

.section .text.n_nextpas.core.atomic.types$_$tatomicusize_$__$$_fetchand$qword$memory_order_t$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_FETCHAND$QWORD$MEMORY_ORDER_T$$QWORD
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_FETCHAND$QWORD$MEMORY_ORDER_T$$QWORD,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_FETCHAND$QWORD$MEMORY_ORDER_T$$QWORD:
.Lc602:
# Temps allocated between rsp+0 and rsp+8
# [1267] begin
	pushq	%rbx
.Lc603:
	pushq	%r12
.Lc604:
	pushq	%r13
.Lc605:
	pushq	%r14
.Lc606:
	pushq	%rax
.Lc607:
	movq	%rdi,%rbx
# Var $self located in register rbx
# Var AMask located in register rsi
# Var AOrder located in register edx
# [1271] Result := PtrUInt(atomic_fetch_and_64(PUInt64(@FValue)^, UInt64(AMask), AOrder));
	movq	%rsi,(%rsp)
	movq	(%rsp),%r12
	.p2align 4,,10
	.p2align 3
.Lj873:
	movq	(%rbx),%r13
	movq	%r13,%r14
	andq	%r12,%r14
	movq	%rbx,%rdi
	movq	%r13,%rdx
	movq	%r14,%rsi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	cmpq	%r13,%rax
	je	.Lj875
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
	jmp	.Lj873
.Lj875:
	movq	%r13,%rax
# Var $result located in register rax
# [1273] end;
	popq	%rcx
	popq	%r14
.Lc608:
	popq	%r13
.Lc609:
	popq	%r12
.Lc610:
	popq	%rbx
.Lc611:
	ret
.Lc601:

.section .text.n_nextpas.core.atomic.types$_$tatomicusize_$__$$_fetchor$qword$memory_order_t$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_FETCHOR$QWORD$MEMORY_ORDER_T$$QWORD
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_FETCHOR$QWORD$MEMORY_ORDER_T$$QWORD,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_FETCHOR$QWORD$MEMORY_ORDER_T$$QWORD:
.Lc613:
# Temps allocated between rsp+0 and rsp+8
# [1276] begin
	pushq	%rbx
.Lc614:
	pushq	%r12
.Lc615:
	pushq	%r13
.Lc616:
	pushq	%r14
.Lc617:
	pushq	%rax
.Lc618:
	movq	%rdi,%rbx
# Var $self located in register rbx
# Var AMask located in register rsi
# Var AOrder located in register edx
# [1280] Result := PtrUInt(atomic_fetch_or_64(PUInt64(@FValue)^, UInt64(AMask), AOrder));
	movq	%rsi,(%rsp)
	movq	(%rsp),%r12
	.p2align 4,,10
	.p2align 3
.Lj883:
	movq	(%rbx),%r13
	movq	%r13,%r14
	orq	%r12,%r14
	movq	%rbx,%rdi
	movq	%r13,%rdx
	movq	%r14,%rsi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	cmpq	%r13,%rax
	je	.Lj885
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
	jmp	.Lj883
.Lj885:
	movq	%r13,%rax
# Var $result located in register rax
# [1282] end;
	popq	%rcx
	popq	%r14
.Lc619:
	popq	%r13
.Lc620:
	popq	%r12
.Lc621:
	popq	%rbx
.Lc622:
	ret
.Lc612:

.section .text.n_nextpas.core.atomic.types$_$tatomicusize_$__$$_fetchxor$qword$memory_order_t$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_FETCHXOR$QWORD$MEMORY_ORDER_T$$QWORD
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_FETCHXOR$QWORD$MEMORY_ORDER_T$$QWORD,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_FETCHXOR$QWORD$MEMORY_ORDER_T$$QWORD:
.Lc624:
# Temps allocated between rsp+0 and rsp+8
# [1285] begin
	pushq	%rbx
.Lc625:
	pushq	%r12
.Lc626:
	pushq	%r13
.Lc627:
	pushq	%r14
.Lc628:
	pushq	%rax
.Lc629:
	movq	%rdi,%rbx
# Var $self located in register rbx
# Var AMask located in register rsi
# Var AOrder located in register edx
# [1289] Result := PtrUInt(atomic_fetch_xor_64(PUInt64(@FValue)^, UInt64(AMask), AOrder));
	movq	%rsi,(%rsp)
	movq	(%rsp),%r12
	.p2align 4,,10
	.p2align 3
.Lj893:
	movq	(%rbx),%r13
	movq	%r13,%r14
	xorq	%r12,%r14
	movq	%rbx,%rdi
	movq	%r13,%rdx
	movq	%r14,%rsi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	cmpq	%r13,%rax
	je	.Lj895
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
	jmp	.Lj893
.Lj895:
	movq	%r13,%rax
# Var $result located in register rax
# [1291] end;
	popq	%rcx
	popq	%r14
.Lc630:
	popq	%r13
.Lc631:
	popq	%r12
.Lc632:
	popq	%rbx
.Lc633:
	ret
.Lc623:

.section .text.n_nextpas.core.atomic.types$_$tatomicusize_$__$$_increment$memory_order_t$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_INCREMENT$MEMORY_ORDER_T$$QWORD
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_INCREMENT$MEMORY_ORDER_T$$QWORD,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_INCREMENT$MEMORY_ORDER_T$$QWORD:
.Lc635:
# Temps allocated between rsp+0 and rsp+8
# [1294] begin
	pushq	%rax
.Lc636:
# Var $self located in register rdi
	movl	%esi,%eax
# Var AOrder located in register eax
# [1295] Result := FetchAdd(1, AOrder) + 1;
	movl	$1,%esi
	movq	$1,(%rsp)
	call	SYSTEM_$$_INTERLOCKEDEXCHANGEADD64$INT64$INT64$$INT64
	addq	$1,%rax
# Var $result located in register rax
# [1296] end;
	popq	%rcx
.Lc637:
	ret
.Lc634:

.section .text.n_nextpas.core.atomic.types$_$tatomicusize_$__$$_decrement$memory_order_t$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_DECREMENT$MEMORY_ORDER_T$$QWORD
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_DECREMENT$MEMORY_ORDER_T$$QWORD,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_DECREMENT$MEMORY_ORDER_T$$QWORD:
.Lc639:
# Temps allocated between rsp+0 and rsp+8
# [1299] begin
	pushq	%rax
.Lc640:
# Var $self located in register rdi
	movl	%esi,%eax
# Var AOrder located in register eax
# [1300] Result := FetchSub(1, AOrder) - 1;
	movl	$1,%esi
	movq	$1,(%rsp)
	negq	%rsi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGEADD64$INT64$INT64$$INT64
	subq	$1,%rax
# Var $result located in register rax
# [1301] end;
	popq	%rcx
.Lc641:
	ret
.Lc638:

.section .text.n_nextpas.core.atomic.types$_$tatomicusize_$__$$_getmut$$pptruint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_GETMUT$$PPTRUINT
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_GETMUT$$PPTRUINT,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_GETMUT$$PPTRUINT:
.Lc643:
# [1304] begin
	movq	%rdi,%rax
# Var $self located in register rax
# Var $result located in register rax
.Lc644:
# [1306] end;
	ret
.Lc642:

.section .text.n_nextpas.core.atomic.types$_$tatomicusize_$__$$_intoinner$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_INTOINNER$$QWORD
	.type	NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_INTOINNER$$QWORD,@function
NEXTPAS.CORE.ATOMIC.TYPES$_$TATOMICUSIZE_$__$$_INTOINNER$$QWORD:
.Lc646:
# Var $self located in register rdi
# [1309] begin
# Var $result located in register rax
# [1310] Result := FValue;
	movq	(%rdi),%rax
.Lc647:
# [1311] end;
	ret
.Lc645:
# End asmlist al_procedures
# Begin asmlist al_rtti

.section .rodata.n_INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT32
	.balign 8
.globl	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT32
	.type	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT32,@object
INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT32:
	.byte	13,12
# [1410] 
	.ascii	"TAtomicInt32"
	.quad	0,0
	.long	4
	.quad	0,0
	.long	0
.Le0:
	.size	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT32, .Le0 - INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT32

.section .rodata.n_RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT32
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT32
	.type	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT32,@object
RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT32:
	.byte	13,12
	.ascii	"TAtomicInt32"
	.quad	0
	.quad	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT32
	.long	4,1
	.quad	RTTI_$SYSTEM_$$_LONGINT$indirect
	.quad	0
	.short	0,0,0
.Le1:
	.size	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT32, .Le1 - RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT32

.section .rodata.n_INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT32
	.balign 8
.globl	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT32
	.type	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT32,@object
INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT32:
	.byte	13,13
	.ascii	"TAtomicUInt32"
	.quad	0,0
	.long	4
	.quad	0,0
	.long	0
.Le2:
	.size	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT32, .Le2 - INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT32

.section .rodata.n_RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT32
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT32
	.type	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT32,@object
RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT32:
	.byte	13,13
	.ascii	"TAtomicUInt32"
	.quad	0
	.quad	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT32
	.long	4,1
	.quad	RTTI_$SYSTEM_$$_LONGWORD$indirect
	.quad	0
	.short	0,0,0
.Le3:
	.size	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT32, .Le3 - RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT32

.section .rodata.n_INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT64
	.balign 8
.globl	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT64
	.type	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT64,@object
INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT64:
	.byte	13,12
	.ascii	"TAtomicInt64"
	.quad	0,0
	.long	8
	.quad	0,0
	.long	0
.Le4:
	.size	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT64, .Le4 - INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT64

.section .rodata.n_RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT64
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT64
	.type	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT64,@object
RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT64:
	.byte	13,12
	.ascii	"TAtomicInt64"
	.quad	0
	.quad	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT64
	.long	8,1
	.quad	RTTI_$SYSTEM_$$_INT64$indirect
	.quad	0
	.short	0,0,0
.Le5:
	.size	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT64, .Le5 - RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT64

.section .rodata.n_INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT64
	.balign 8
.globl	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT64
	.type	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT64,@object
INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT64:
	.byte	13,13
	.ascii	"TAtomicUInt64"
	.quad	0,0
	.long	8
	.quad	0,0
	.long	0
.Le6:
	.size	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT64, .Le6 - INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT64

.section .rodata.n_RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT64
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT64
	.type	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT64,@object
RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT64:
	.byte	13,13
	.ascii	"TAtomicUInt64"
	.quad	0
	.quad	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT64
	.long	8,1
	.quad	RTTI_$SYSTEM_$$_QWORD$indirect
	.quad	0
	.short	0,0,0
.Le7:
	.size	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT64, .Le7 - RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT64

.section .rodata.n_INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICBOOL
	.balign 8
.globl	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICBOOL
	.type	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICBOOL,@object
INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICBOOL:
	.byte	13,11
	.ascii	"TAtomicBool"
	.quad	0,0
	.long	4
	.quad	0,0
	.long	0
.Le8:
	.size	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICBOOL, .Le8 - INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICBOOL

.section .rodata.n_RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICBOOL
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICBOOL
	.type	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICBOOL,@object
RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICBOOL:
	.byte	13,11
	.ascii	"TAtomicBool"
	.quad	0
	.quad	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICBOOL
	.long	4,1
	.quad	RTTI_$SYSTEM_$$_LONGINT$indirect
	.quad	0
	.short	0,0,0
.Le9:
	.size	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICBOOL, .Le9 - RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICBOOL

.section .rodata.n_INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICFLAG
	.balign 8
.globl	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICFLAG
	.type	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICFLAG,@object
INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICFLAG:
	.byte	13,11
	.ascii	"TAtomicFlag"
	.quad	0,0
	.long	4
	.quad	0,0
	.long	0
.Le10:
	.size	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICFLAG, .Le10 - INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICFLAG

.section .rodata.n_RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICFLAG
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICFLAG
	.type	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICFLAG,@object
RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICFLAG:
	.byte	13,11
	.ascii	"TAtomicFlag"
	.quad	0
	.quad	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICFLAG
	.long	4,1
	.quad	RTTI_$SYSTEM_$$_LONGINT$indirect
	.quad	0
	.short	0,0,0
.Le11:
	.size	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICFLAG, .Le11 - RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICFLAG

.section .rodata.n_INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICISIZE
	.balign 8
.globl	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICISIZE
	.type	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICISIZE,@object
INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICISIZE:
	.byte	13,12
	.ascii	"TAtomicISize"
	.quad	0,0
	.long	8
	.quad	0,0
	.long	0
.Le12:
	.size	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICISIZE, .Le12 - INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICISIZE

.section .rodata.n_RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICISIZE
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICISIZE
	.type	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICISIZE,@object
RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICISIZE:
	.byte	13,12
	.ascii	"TAtomicISize"
	.quad	0
	.quad	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICISIZE
	.long	8,1
	.quad	RTTI_$SYSTEM_$$_INT64$indirect
	.quad	0
	.short	0,0,0
.Le13:
	.size	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICISIZE, .Le13 - RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICISIZE

.section .rodata.n_INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUSIZE
	.balign 8
.globl	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUSIZE
	.type	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUSIZE,@object
INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUSIZE:
	.byte	13,12
	.ascii	"TAtomicUSize"
	.quad	0,0
	.long	8
	.quad	0,0
	.long	0
.Le14:
	.size	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUSIZE, .Le14 - INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUSIZE

.section .rodata.n_RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUSIZE
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUSIZE
	.type	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUSIZE,@object
RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUSIZE:
	.byte	13,12
	.ascii	"TAtomicUSize"
	.quad	0
	.quad	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUSIZE
	.long	8,1
	.quad	RTTI_$SYSTEM_$$_QWORD$indirect
	.quad	0
	.short	0,0,0
.Le15:
	.size	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUSIZE, .Le15 - RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUSIZE
# End asmlist al_rtti
# Begin asmlist al_indirectglobals

.section .rodata.n_INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT32
	.balign 8
.globl	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT32$indirect
	.type	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT32$indirect,@object
INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT32$indirect:
	.quad	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT32
.Le16:
	.size	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT32$indirect, .Le16 - INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT32$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT32
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT32$indirect
	.type	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT32$indirect,@object
RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT32$indirect:
	.quad	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT32
.Le17:
	.size	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT32$indirect, .Le17 - RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT32$indirect

.section .rodata.n_INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT32
	.balign 8
.globl	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT32$indirect
	.type	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT32$indirect,@object
INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT32$indirect:
	.quad	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT32
.Le18:
	.size	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT32$indirect, .Le18 - INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT32$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT32
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT32$indirect
	.type	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT32$indirect,@object
RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT32$indirect:
	.quad	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT32
.Le19:
	.size	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT32$indirect, .Le19 - RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT32$indirect

.section .rodata.n_INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT64
	.balign 8
.globl	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT64$indirect
	.type	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT64$indirect,@object
INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT64$indirect:
	.quad	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT64
.Le20:
	.size	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT64$indirect, .Le20 - INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT64$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT64
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT64$indirect
	.type	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT64$indirect,@object
RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT64$indirect:
	.quad	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT64
.Le21:
	.size	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT64$indirect, .Le21 - RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICINT64$indirect

.section .rodata.n_INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT64
	.balign 8
.globl	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT64$indirect
	.type	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT64$indirect,@object
INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT64$indirect:
	.quad	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT64
.Le22:
	.size	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT64$indirect, .Le22 - INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT64$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT64
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT64$indirect
	.type	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT64$indirect,@object
RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT64$indirect:
	.quad	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT64
.Le23:
	.size	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT64$indirect, .Le23 - RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUINT64$indirect

.section .rodata.n_INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICBOOL
	.balign 8
.globl	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICBOOL$indirect
	.type	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICBOOL$indirect,@object
INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICBOOL$indirect:
	.quad	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICBOOL
.Le24:
	.size	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICBOOL$indirect, .Le24 - INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICBOOL$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICBOOL
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICBOOL$indirect
	.type	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICBOOL$indirect,@object
RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICBOOL$indirect:
	.quad	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICBOOL
.Le25:
	.size	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICBOOL$indirect, .Le25 - RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICBOOL$indirect

.section .rodata.n_INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICFLAG
	.balign 8
.globl	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICFLAG$indirect
	.type	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICFLAG$indirect,@object
INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICFLAG$indirect:
	.quad	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICFLAG
.Le26:
	.size	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICFLAG$indirect, .Le26 - INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICFLAG$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICFLAG
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICFLAG$indirect
	.type	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICFLAG$indirect,@object
RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICFLAG$indirect:
	.quad	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICFLAG
.Le27:
	.size	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICFLAG$indirect, .Le27 - RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICFLAG$indirect

.section .rodata.n_INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICISIZE
	.balign 8
.globl	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICISIZE$indirect
	.type	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICISIZE$indirect,@object
INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICISIZE$indirect:
	.quad	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICISIZE
.Le28:
	.size	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICISIZE$indirect, .Le28 - INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICISIZE$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICISIZE
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICISIZE$indirect
	.type	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICISIZE$indirect,@object
RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICISIZE$indirect:
	.quad	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICISIZE
.Le29:
	.size	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICISIZE$indirect, .Le29 - RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICISIZE$indirect

.section .rodata.n_INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUSIZE
	.balign 8
.globl	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUSIZE$indirect
	.type	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUSIZE$indirect,@object
INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUSIZE$indirect:
	.quad	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUSIZE
.Le30:
	.size	INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUSIZE$indirect, .Le30 - INIT_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUSIZE$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUSIZE
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUSIZE$indirect
	.type	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUSIZE$indirect,@object
RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUSIZE$indirect:
	.quad	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUSIZE
.Le31:
	.size	RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUSIZE$indirect, .Le31 - RTTI_$NEXTPAS.CORE.ATOMIC.TYPES_$$_TATOMICUSIZE$indirect
# End asmlist al_indirectglobals
# Begin asmlist al_dwarf_frame

.section .debug_frame
.Lc648:
	.long	.Lc650-.Lc649
.Lc649:
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
.Lc650:
	.long	.Lc652-.Lc651
.Lc651:
	.long	.Lc648
	.quad	.Lc2
	.quad	.Lc1-.Lc2
	.byte	4
	.long	.Lc3-.Lc2
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc652:
	.long	.Lc655-.Lc654
.Lc654:
	.long	.Lc648
	.quad	.Lc5
	.quad	.Lc4-.Lc5
	.byte	4
	.long	.Lc6-.Lc5
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc655:
	.long	.Lc658-.Lc657
.Lc657:
	.long	.Lc648
	.quad	.Lc8
	.quad	.Lc7-.Lc8
	.byte	4
	.long	.Lc9-.Lc8
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc658:
	.long	.Lc661-.Lc660
.Lc660:
	.long	.Lc648
	.quad	.Lc11
	.quad	.Lc10-.Lc11
	.byte	4
	.long	.Lc12-.Lc11
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc661:
	.long	.Lc664-.Lc663
.Lc663:
	.long	.Lc648
	.quad	.Lc14
	.quad	.Lc13-.Lc14
	.byte	2
	.byte	.Lc15-.Lc14
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc16-.Lc15
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc17-.Lc16
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc18-.Lc17
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc19-.Lc18
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc664:
	.long	.Lc667-.Lc666
.Lc666:
	.long	.Lc648
	.quad	.Lc21
	.quad	.Lc20-.Lc21
	.byte	2
	.byte	.Lc22-.Lc21
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc23-.Lc22
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc24-.Lc23
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc25-.Lc24
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc26-.Lc25
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc667:
	.long	.Lc670-.Lc669
.Lc669:
	.long	.Lc648
	.quad	.Lc28
	.quad	.Lc27-.Lc28
	.byte	2
	.byte	.Lc29-.Lc28
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc30-.Lc29
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc670:
	.long	.Lc673-.Lc672
.Lc672:
	.long	.Lc648
	.quad	.Lc32
	.quad	.Lc31-.Lc32
	.byte	2
	.byte	.Lc33-.Lc32
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc34-.Lc33
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc673:
	.long	.Lc676-.Lc675
.Lc675:
	.long	.Lc648
	.quad	.Lc36
	.quad	.Lc35-.Lc36
	.byte	2
	.byte	.Lc37-.Lc36
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc38-.Lc37
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc676:
	.long	.Lc679-.Lc678
.Lc678:
	.long	.Lc648
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
.Lc679:
	.long	.Lc682-.Lc681
.Lc681:
	.long	.Lc648
	.quad	.Lc44
	.quad	.Lc43-.Lc44
	.byte	2
	.byte	.Lc45-.Lc44
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc46-.Lc45
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc682:
	.long	.Lc685-.Lc684
.Lc684:
	.long	.Lc648
	.quad	.Lc48
	.quad	.Lc47-.Lc48
	.byte	2
	.byte	.Lc49-.Lc48
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc50-.Lc49
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc51-.Lc50
	.byte	5
	.uleb128	13
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc52-.Lc51
	.byte	5
	.uleb128	14
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc53-.Lc52
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc54-.Lc53
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc55-.Lc54
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc56-.Lc55
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc57-.Lc56
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc685:
	.long	.Lc688-.Lc687
.Lc687:
	.long	.Lc648
	.quad	.Lc59
	.quad	.Lc58-.Lc59
	.byte	2
	.byte	.Lc60-.Lc59
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc61-.Lc60
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc62-.Lc61
	.byte	5
	.uleb128	13
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc63-.Lc62
	.byte	5
	.uleb128	14
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc64-.Lc63
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc65-.Lc64
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc66-.Lc65
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc67-.Lc66
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc68-.Lc67
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc688:
	.long	.Lc691-.Lc690
.Lc690:
	.long	.Lc648
	.quad	.Lc70
	.quad	.Lc69-.Lc70
	.byte	2
	.byte	.Lc71-.Lc70
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc72-.Lc71
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc73-.Lc72
	.byte	5
	.uleb128	13
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc74-.Lc73
	.byte	5
	.uleb128	14
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc75-.Lc74
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc76-.Lc75
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc77-.Lc76
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc78-.Lc77
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc79-.Lc78
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc691:
	.long	.Lc694-.Lc693
.Lc693:
	.long	.Lc648
	.quad	.Lc81
	.quad	.Lc80-.Lc81
	.byte	2
	.byte	.Lc82-.Lc81
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc83-.Lc82
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc694:
	.long	.Lc697-.Lc696
.Lc696:
	.long	.Lc648
	.quad	.Lc85
	.quad	.Lc84-.Lc85
	.byte	2
	.byte	.Lc86-.Lc85
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc87-.Lc86
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc697:
	.long	.Lc700-.Lc699
.Lc699:
	.long	.Lc648
	.quad	.Lc89
	.quad	.Lc88-.Lc89
	.byte	4
	.long	.Lc90-.Lc89
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc700:
	.long	.Lc703-.Lc702
.Lc702:
	.long	.Lc648
	.quad	.Lc92
	.quad	.Lc91-.Lc92
	.byte	4
	.long	.Lc93-.Lc92
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc703:
	.long	.Lc706-.Lc705
.Lc705:
	.long	.Lc648
	.quad	.Lc95
	.quad	.Lc94-.Lc95
	.byte	4
	.long	.Lc96-.Lc95
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc706:
	.long	.Lc709-.Lc708
.Lc708:
	.long	.Lc648
	.quad	.Lc98
	.quad	.Lc97-.Lc98
	.byte	4
	.long	.Lc99-.Lc98
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc709:
	.long	.Lc712-.Lc711
.Lc711:
	.long	.Lc648
	.quad	.Lc101
	.quad	.Lc100-.Lc101
	.byte	2
	.byte	.Lc102-.Lc101
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc103-.Lc102
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc104-.Lc103
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc105-.Lc104
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc106-.Lc105
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc712:
	.long	.Lc715-.Lc714
.Lc714:
	.long	.Lc648
	.quad	.Lc108
	.quad	.Lc107-.Lc108
	.byte	2
	.byte	.Lc109-.Lc108
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc110-.Lc109
	.byte	5
	.uleb128	12
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc111-.Lc110
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc112-.Lc111
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc113-.Lc112
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc715:
	.long	.Lc718-.Lc717
.Lc717:
	.long	.Lc648
	.quad	.Lc115
	.quad	.Lc114-.Lc115
	.byte	2
	.byte	.Lc116-.Lc115
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc117-.Lc116
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc718:
	.long	.Lc721-.Lc720
.Lc720:
	.long	.Lc648
	.quad	.Lc119
	.quad	.Lc118-.Lc119
	.byte	2
	.byte	.Lc120-.Lc119
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc121-.Lc120
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc122-.Lc121
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc721:
	.long	.Lc724-.Lc723
.Lc723:
	.long	.Lc648
	.quad	.Lc124
	.quad	.Lc123-.Lc124
	.byte	2
	.byte	.Lc125-.Lc124
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc126-.Lc125
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc127-.Lc126
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc724:
	.long	.Lc727-.Lc726
.Lc726:
	.long	.Lc648
	.quad	.Lc129
	.quad	.Lc128-.Lc129
	.byte	2
	.byte	.Lc130-.Lc129
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc131-.Lc130
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc727:
	.long	.Lc730-.Lc729
.Lc729:
	.long	.Lc648
	.quad	.Lc133
	.quad	.Lc132-.Lc133
	.byte	2
	.byte	.Lc134-.Lc133
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc135-.Lc134
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc730:
	.long	.Lc733-.Lc732
.Lc732:
	.long	.Lc648
	.quad	.Lc137
	.quad	.Lc136-.Lc137
	.byte	2
	.byte	.Lc138-.Lc137
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc139-.Lc138
	.byte	5
	.uleb128	12
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc140-.Lc139
	.byte	5
	.uleb128	13
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc141-.Lc140
	.byte	5
	.uleb128	14
	.uleb128	12
	.byte	14
	.uleb128	48
	.byte	2
	.byte	.Lc142-.Lc141
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc143-.Lc142
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc144-.Lc143
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc145-.Lc144
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc146-.Lc145
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc733:
	.long	.Lc736-.Lc735
.Lc735:
	.long	.Lc648
	.quad	.Lc148
	.quad	.Lc147-.Lc148
	.byte	2
	.byte	.Lc149-.Lc148
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc150-.Lc149
	.byte	5
	.uleb128	12
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc151-.Lc150
	.byte	5
	.uleb128	13
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc152-.Lc151
	.byte	5
	.uleb128	14
	.uleb128	12
	.byte	14
	.uleb128	48
	.byte	2
	.byte	.Lc153-.Lc152
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc154-.Lc153
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc155-.Lc154
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc156-.Lc155
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc157-.Lc156
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc736:
	.long	.Lc739-.Lc738
.Lc738:
	.long	.Lc648
	.quad	.Lc159
	.quad	.Lc158-.Lc159
	.byte	2
	.byte	.Lc160-.Lc159
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc161-.Lc160
	.byte	5
	.uleb128	12
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc162-.Lc161
	.byte	5
	.uleb128	13
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc163-.Lc162
	.byte	5
	.uleb128	14
	.uleb128	12
	.byte	14
	.uleb128	48
	.byte	2
	.byte	.Lc164-.Lc163
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc165-.Lc164
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc166-.Lc165
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc167-.Lc166
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc168-.Lc167
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc739:
	.long	.Lc742-.Lc741
.Lc741:
	.long	.Lc648
	.quad	.Lc170
	.quad	.Lc169-.Lc170
	.byte	2
	.byte	.Lc171-.Lc170
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc172-.Lc171
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc742:
	.long	.Lc745-.Lc744
.Lc744:
	.long	.Lc648
	.quad	.Lc174
	.quad	.Lc173-.Lc174
	.byte	2
	.byte	.Lc175-.Lc174
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc176-.Lc175
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc745:
	.long	.Lc748-.Lc747
.Lc747:
	.long	.Lc648
	.quad	.Lc178
	.quad	.Lc177-.Lc178
	.byte	4
	.long	.Lc179-.Lc178
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc748:
	.long	.Lc751-.Lc750
.Lc750:
	.long	.Lc648
	.quad	.Lc181
	.quad	.Lc180-.Lc181
	.byte	4
	.long	.Lc182-.Lc181
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc751:
	.long	.Lc754-.Lc753
.Lc753:
	.long	.Lc648
	.quad	.Lc184
	.quad	.Lc183-.Lc184
	.byte	4
	.long	.Lc185-.Lc184
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc754:
	.long	.Lc757-.Lc756
.Lc756:
	.long	.Lc648
	.quad	.Lc187
	.quad	.Lc186-.Lc187
	.byte	4
	.long	.Lc188-.Lc187
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc757:
	.long	.Lc760-.Lc759
.Lc759:
	.long	.Lc648
	.quad	.Lc190
	.quad	.Lc189-.Lc190
	.byte	2
	.byte	.Lc191-.Lc190
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc192-.Lc191
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc193-.Lc192
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc194-.Lc193
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc195-.Lc194
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc760:
	.long	.Lc763-.Lc762
.Lc762:
	.long	.Lc648
	.quad	.Lc197
	.quad	.Lc196-.Lc197
	.byte	2
	.byte	.Lc198-.Lc197
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc199-.Lc198
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc200-.Lc199
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc201-.Lc200
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc202-.Lc201
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc763:
	.long	.Lc766-.Lc765
.Lc765:
	.long	.Lc648
	.quad	.Lc204
	.quad	.Lc203-.Lc204
	.byte	2
	.byte	.Lc205-.Lc204
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc206-.Lc205
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc766:
	.long	.Lc769-.Lc768
.Lc768:
	.long	.Lc648
	.quad	.Lc208
	.quad	.Lc207-.Lc208
	.byte	2
	.byte	.Lc209-.Lc208
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc210-.Lc209
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc769:
	.long	.Lc772-.Lc771
.Lc771:
	.long	.Lc648
	.quad	.Lc212
	.quad	.Lc211-.Lc212
	.byte	2
	.byte	.Lc213-.Lc212
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc214-.Lc213
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc772:
	.long	.Lc775-.Lc774
.Lc774:
	.long	.Lc648
	.quad	.Lc216
	.quad	.Lc215-.Lc216
	.byte	2
	.byte	.Lc217-.Lc216
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc218-.Lc217
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc775:
	.long	.Lc778-.Lc777
.Lc777:
	.long	.Lc648
	.quad	.Lc220
	.quad	.Lc219-.Lc220
	.byte	2
	.byte	.Lc221-.Lc220
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc222-.Lc221
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc778:
	.long	.Lc781-.Lc780
.Lc780:
	.long	.Lc648
	.quad	.Lc224
	.quad	.Lc223-.Lc224
	.byte	2
	.byte	.Lc225-.Lc224
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc226-.Lc225
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc227-.Lc226
	.byte	5
	.uleb128	13
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc228-.Lc227
	.byte	5
	.uleb128	14
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc229-.Lc228
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc230-.Lc229
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc231-.Lc230
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc232-.Lc231
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc233-.Lc232
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc781:
	.long	.Lc784-.Lc783
.Lc783:
	.long	.Lc648
	.quad	.Lc235
	.quad	.Lc234-.Lc235
	.byte	2
	.byte	.Lc236-.Lc235
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc237-.Lc236
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc238-.Lc237
	.byte	5
	.uleb128	13
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc239-.Lc238
	.byte	5
	.uleb128	14
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc240-.Lc239
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc241-.Lc240
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc242-.Lc241
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc243-.Lc242
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc244-.Lc243
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc784:
	.long	.Lc787-.Lc786
.Lc786:
	.long	.Lc648
	.quad	.Lc246
	.quad	.Lc245-.Lc246
	.byte	2
	.byte	.Lc247-.Lc246
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc248-.Lc247
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc249-.Lc248
	.byte	5
	.uleb128	13
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc250-.Lc249
	.byte	5
	.uleb128	14
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc251-.Lc250
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc252-.Lc251
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc253-.Lc252
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc254-.Lc253
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc255-.Lc254
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc787:
	.long	.Lc790-.Lc789
.Lc789:
	.long	.Lc648
	.quad	.Lc257
	.quad	.Lc256-.Lc257
	.byte	2
	.byte	.Lc258-.Lc257
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc259-.Lc258
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc790:
	.long	.Lc793-.Lc792
.Lc792:
	.long	.Lc648
	.quad	.Lc261
	.quad	.Lc260-.Lc261
	.byte	2
	.byte	.Lc262-.Lc261
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc263-.Lc262
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc793:
	.long	.Lc796-.Lc795
.Lc795:
	.long	.Lc648
	.quad	.Lc265
	.quad	.Lc264-.Lc265
	.byte	4
	.long	.Lc266-.Lc265
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc796:
	.long	.Lc799-.Lc798
.Lc798:
	.long	.Lc648
	.quad	.Lc268
	.quad	.Lc267-.Lc268
	.byte	4
	.long	.Lc269-.Lc268
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc799:
	.long	.Lc802-.Lc801
.Lc801:
	.long	.Lc648
	.quad	.Lc271
	.quad	.Lc270-.Lc271
	.byte	4
	.long	.Lc272-.Lc271
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc802:
	.long	.Lc805-.Lc804
.Lc804:
	.long	.Lc648
	.quad	.Lc274
	.quad	.Lc273-.Lc274
	.byte	4
	.long	.Lc275-.Lc274
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc805:
	.long	.Lc808-.Lc807
.Lc807:
	.long	.Lc648
	.quad	.Lc277
	.quad	.Lc276-.Lc277
	.byte	2
	.byte	.Lc278-.Lc277
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc279-.Lc278
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc280-.Lc279
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc281-.Lc280
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc282-.Lc281
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc808:
	.long	.Lc811-.Lc810
.Lc810:
	.long	.Lc648
	.quad	.Lc284
	.quad	.Lc283-.Lc284
	.byte	2
	.byte	.Lc285-.Lc284
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc286-.Lc285
	.byte	5
	.uleb128	12
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc287-.Lc286
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc288-.Lc287
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc289-.Lc288
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc811:
	.long	.Lc814-.Lc813
.Lc813:
	.long	.Lc648
	.quad	.Lc291
	.quad	.Lc290-.Lc291
	.byte	2
	.byte	.Lc292-.Lc291
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc293-.Lc292
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc814:
	.long	.Lc817-.Lc816
.Lc816:
	.long	.Lc648
	.quad	.Lc295
	.quad	.Lc294-.Lc295
	.byte	2
	.byte	.Lc296-.Lc295
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc297-.Lc296
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc298-.Lc297
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc817:
	.long	.Lc820-.Lc819
.Lc819:
	.long	.Lc648
	.quad	.Lc300
	.quad	.Lc299-.Lc300
	.byte	2
	.byte	.Lc301-.Lc300
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc302-.Lc301
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc303-.Lc302
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc820:
	.long	.Lc823-.Lc822
.Lc822:
	.long	.Lc648
	.quad	.Lc305
	.quad	.Lc304-.Lc305
	.byte	2
	.byte	.Lc306-.Lc305
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc307-.Lc306
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc823:
	.long	.Lc826-.Lc825
.Lc825:
	.long	.Lc648
	.quad	.Lc309
	.quad	.Lc308-.Lc309
	.byte	2
	.byte	.Lc310-.Lc309
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc311-.Lc310
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc826:
	.long	.Lc829-.Lc828
.Lc828:
	.long	.Lc648
	.quad	.Lc313
	.quad	.Lc312-.Lc313
	.byte	2
	.byte	.Lc314-.Lc313
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc315-.Lc314
	.byte	5
	.uleb128	12
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc316-.Lc315
	.byte	5
	.uleb128	13
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc317-.Lc316
	.byte	5
	.uleb128	14
	.uleb128	12
	.byte	14
	.uleb128	48
	.byte	2
	.byte	.Lc318-.Lc317
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc319-.Lc318
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc320-.Lc319
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc321-.Lc320
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc322-.Lc321
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc829:
	.long	.Lc832-.Lc831
.Lc831:
	.long	.Lc648
	.quad	.Lc324
	.quad	.Lc323-.Lc324
	.byte	2
	.byte	.Lc325-.Lc324
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc326-.Lc325
	.byte	5
	.uleb128	12
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc327-.Lc326
	.byte	5
	.uleb128	13
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc328-.Lc327
	.byte	5
	.uleb128	14
	.uleb128	12
	.byte	14
	.uleb128	48
	.byte	2
	.byte	.Lc329-.Lc328
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc330-.Lc329
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc331-.Lc330
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc332-.Lc331
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc333-.Lc332
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc832:
	.long	.Lc835-.Lc834
.Lc834:
	.long	.Lc648
	.quad	.Lc335
	.quad	.Lc334-.Lc335
	.byte	2
	.byte	.Lc336-.Lc335
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc337-.Lc336
	.byte	5
	.uleb128	12
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc338-.Lc337
	.byte	5
	.uleb128	13
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc339-.Lc338
	.byte	5
	.uleb128	14
	.uleb128	12
	.byte	14
	.uleb128	48
	.byte	2
	.byte	.Lc340-.Lc339
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc341-.Lc340
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc342-.Lc341
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc343-.Lc342
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc344-.Lc343
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc835:
	.long	.Lc838-.Lc837
.Lc837:
	.long	.Lc648
	.quad	.Lc346
	.quad	.Lc345-.Lc346
	.byte	2
	.byte	.Lc347-.Lc346
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc348-.Lc347
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc838:
	.long	.Lc841-.Lc840
.Lc840:
	.long	.Lc648
	.quad	.Lc350
	.quad	.Lc349-.Lc350
	.byte	2
	.byte	.Lc351-.Lc350
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc352-.Lc351
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc841:
	.long	.Lc844-.Lc843
.Lc843:
	.long	.Lc648
	.quad	.Lc354
	.quad	.Lc353-.Lc354
	.byte	4
	.long	.Lc355-.Lc354
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc844:
	.long	.Lc847-.Lc846
.Lc846:
	.long	.Lc648
	.quad	.Lc357
	.quad	.Lc356-.Lc357
	.byte	4
	.long	.Lc358-.Lc357
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc847:
	.long	.Lc850-.Lc849
.Lc849:
	.long	.Lc648
	.quad	.Lc360
	.quad	.Lc359-.Lc360
	.byte	4
	.long	.Lc361-.Lc360
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc850:
	.long	.Lc853-.Lc852
.Lc852:
	.long	.Lc648
	.quad	.Lc363
	.quad	.Lc362-.Lc363
	.byte	4
	.long	.Lc364-.Lc363
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc853:
	.long	.Lc856-.Lc855
.Lc855:
	.long	.Lc648
	.quad	.Lc366
	.quad	.Lc365-.Lc366
	.byte	2
	.byte	.Lc367-.Lc366
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc368-.Lc367
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc369-.Lc368
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc370-.Lc369
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc371-.Lc370
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc856:
	.long	.Lc859-.Lc858
.Lc858:
	.long	.Lc648
	.quad	.Lc373
	.quad	.Lc372-.Lc373
	.byte	2
	.byte	.Lc374-.Lc373
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc375-.Lc374
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc376-.Lc375
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc377-.Lc376
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc378-.Lc377
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc859:
	.long	.Lc862-.Lc861
.Lc861:
	.long	.Lc648
	.quad	.Lc380
	.quad	.Lc379-.Lc380
	.byte	2
	.byte	.Lc381-.Lc380
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc382-.Lc381
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc862:
	.long	.Lc865-.Lc864
.Lc864:
	.long	.Lc648
	.quad	.Lc384
	.quad	.Lc383-.Lc384
	.byte	2
	.byte	.Lc385-.Lc384
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc386-.Lc385
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc387-.Lc386
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc865:
	.long	.Lc868-.Lc867
.Lc867:
	.long	.Lc648
	.quad	.Lc389
	.quad	.Lc388-.Lc389
	.byte	2
	.byte	.Lc390-.Lc389
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc391-.Lc390
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc392-.Lc391
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc868:
	.long	.Lc871-.Lc870
.Lc870:
	.long	.Lc648
	.quad	.Lc394
	.quad	.Lc393-.Lc394
	.byte	2
	.byte	.Lc395-.Lc394
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc396-.Lc395
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc397-.Lc396
	.byte	5
	.uleb128	13
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc398-.Lc397
	.byte	5
	.uleb128	14
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc399-.Lc398
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc400-.Lc399
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc401-.Lc400
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc402-.Lc401
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc403-.Lc402
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc871:
	.long	.Lc874-.Lc873
.Lc873:
	.long	.Lc648
	.quad	.Lc405
	.quad	.Lc404-.Lc405
	.byte	2
	.byte	.Lc406-.Lc405
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc407-.Lc406
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc408-.Lc407
	.byte	5
	.uleb128	13
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc409-.Lc408
	.byte	5
	.uleb128	14
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc410-.Lc409
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc411-.Lc410
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc412-.Lc411
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc413-.Lc412
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc414-.Lc413
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc874:
	.long	.Lc877-.Lc876
.Lc876:
	.long	.Lc648
	.quad	.Lc416
	.quad	.Lc415-.Lc416
	.byte	2
	.byte	.Lc417-.Lc416
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc418-.Lc417
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc419-.Lc418
	.byte	5
	.uleb128	13
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc420-.Lc419
	.byte	5
	.uleb128	14
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc421-.Lc420
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc422-.Lc421
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc423-.Lc422
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc424-.Lc423
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc425-.Lc424
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc877:
	.long	.Lc880-.Lc879
.Lc879:
	.long	.Lc648
	.quad	.Lc427
	.quad	.Lc426-.Lc427
	.byte	2
	.byte	.Lc428-.Lc427
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc429-.Lc428
	.byte	5
	.uleb128	12
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc430-.Lc429
	.byte	5
	.uleb128	13
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc431-.Lc430
	.byte	5
	.uleb128	14
	.uleb128	12
	.byte	14
	.uleb128	48
	.byte	2
	.byte	.Lc432-.Lc431
	.byte	5
	.uleb128	15
	.uleb128	14
	.byte	14
	.uleb128	56
	.byte	2
	.byte	.Lc433-.Lc432
	.byte	14
	.uleb128	64
	.byte	4
	.long	.Lc434-.Lc433
	.byte	6
	.uleb128	15
	.byte	2
	.byte	.Lc435-.Lc434
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc436-.Lc435
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc437-.Lc436
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc438-.Lc437
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc880:
	.long	.Lc883-.Lc882
.Lc882:
	.long	.Lc648
	.quad	.Lc440
	.quad	.Lc439-.Lc440
	.byte	4
	.long	.Lc441-.Lc440
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc883:
	.long	.Lc886-.Lc885
.Lc885:
	.long	.Lc648
	.quad	.Lc443
	.quad	.Lc442-.Lc443
	.byte	4
	.long	.Lc444-.Lc443
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc886:
	.long	.Lc889-.Lc888
.Lc888:
	.long	.Lc648
	.quad	.Lc446
	.quad	.Lc445-.Lc446
	.byte	4
	.long	.Lc447-.Lc446
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc889:
	.long	.Lc892-.Lc891
.Lc891:
	.long	.Lc648
	.quad	.Lc449
	.quad	.Lc448-.Lc449
	.byte	4
	.long	.Lc450-.Lc449
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc892:
	.long	.Lc895-.Lc894
.Lc894:
	.long	.Lc648
	.quad	.Lc452
	.quad	.Lc451-.Lc452
	.byte	2
	.byte	.Lc453-.Lc452
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc454-.Lc453
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc895:
	.long	.Lc898-.Lc897
.Lc897:
	.long	.Lc648
	.quad	.Lc456
	.quad	.Lc455-.Lc456
	.byte	2
	.byte	.Lc457-.Lc456
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc458-.Lc457
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc898:
	.long	.Lc901-.Lc900
.Lc900:
	.long	.Lc648
	.quad	.Lc460
	.quad	.Lc459-.Lc460
	.byte	2
	.byte	.Lc461-.Lc460
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc462-.Lc461
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc463-.Lc462
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc464-.Lc463
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc465-.Lc464
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc901:
	.long	.Lc904-.Lc903
.Lc903:
	.long	.Lc648
	.quad	.Lc467
	.quad	.Lc466-.Lc467
	.byte	4
	.long	.Lc468-.Lc467
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc904:
	.long	.Lc907-.Lc906
.Lc906:
	.long	.Lc648
	.quad	.Lc470
	.quad	.Lc469-.Lc470
	.byte	4
	.long	.Lc471-.Lc470
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc907:
	.long	.Lc910-.Lc909
.Lc909:
	.long	.Lc648
	.quad	.Lc473
	.quad	.Lc472-.Lc473
	.byte	2
	.byte	.Lc474-.Lc473
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc475-.Lc474
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc476-.Lc475
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc477-.Lc476
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc478-.Lc477
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc910:
	.long	.Lc913-.Lc912
.Lc912:
	.long	.Lc648
	.quad	.Lc480
	.quad	.Lc479-.Lc480
	.byte	2
	.byte	.Lc481-.Lc480
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc482-.Lc481
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc483-.Lc482
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc484-.Lc483
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc485-.Lc484
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc913:
	.long	.Lc916-.Lc915
.Lc915:
	.long	.Lc648
	.quad	.Lc487
	.quad	.Lc486-.Lc487
	.byte	2
	.byte	.Lc488-.Lc487
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc489-.Lc488
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc916:
	.long	.Lc919-.Lc918
.Lc918:
	.long	.Lc648
	.quad	.Lc491
	.quad	.Lc490-.Lc491
	.byte	2
	.byte	.Lc492-.Lc491
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc493-.Lc492
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc494-.Lc493
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc919:
	.long	.Lc922-.Lc921
.Lc921:
	.long	.Lc648
	.quad	.Lc496
	.quad	.Lc495-.Lc496
	.byte	2
	.byte	.Lc497-.Lc496
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc498-.Lc497
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc499-.Lc498
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc922:
	.long	.Lc925-.Lc924
.Lc924:
	.long	.Lc648
	.quad	.Lc501
	.quad	.Lc500-.Lc501
	.byte	2
	.byte	.Lc502-.Lc501
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc503-.Lc502
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc925:
	.long	.Lc928-.Lc927
.Lc927:
	.long	.Lc648
	.quad	.Lc505
	.quad	.Lc504-.Lc505
	.byte	2
	.byte	.Lc506-.Lc505
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc507-.Lc506
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc928:
	.long	.Lc931-.Lc930
.Lc930:
	.long	.Lc648
	.quad	.Lc509
	.quad	.Lc508-.Lc509
	.byte	2
	.byte	.Lc510-.Lc509
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc511-.Lc510
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc512-.Lc511
	.byte	5
	.uleb128	13
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc513-.Lc512
	.byte	5
	.uleb128	14
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc514-.Lc513
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc515-.Lc514
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc516-.Lc515
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc517-.Lc516
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc518-.Lc517
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc931:
	.long	.Lc934-.Lc933
.Lc933:
	.long	.Lc648
	.quad	.Lc520
	.quad	.Lc519-.Lc520
	.byte	2
	.byte	.Lc521-.Lc520
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc522-.Lc521
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc523-.Lc522
	.byte	5
	.uleb128	13
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc524-.Lc523
	.byte	5
	.uleb128	14
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc525-.Lc524
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc526-.Lc525
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc527-.Lc526
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc528-.Lc527
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc529-.Lc528
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc934:
	.long	.Lc937-.Lc936
.Lc936:
	.long	.Lc648
	.quad	.Lc531
	.quad	.Lc530-.Lc531
	.byte	2
	.byte	.Lc532-.Lc531
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc533-.Lc532
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc534-.Lc533
	.byte	5
	.uleb128	13
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc535-.Lc534
	.byte	5
	.uleb128	14
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc536-.Lc535
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc537-.Lc536
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc538-.Lc537
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc539-.Lc538
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc540-.Lc539
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc937:
	.long	.Lc940-.Lc939
.Lc939:
	.long	.Lc648
	.quad	.Lc542
	.quad	.Lc541-.Lc542
	.byte	2
	.byte	.Lc543-.Lc542
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc544-.Lc543
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc940:
	.long	.Lc943-.Lc942
.Lc942:
	.long	.Lc648
	.quad	.Lc546
	.quad	.Lc545-.Lc546
	.byte	2
	.byte	.Lc547-.Lc546
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc548-.Lc547
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc943:
	.long	.Lc946-.Lc945
.Lc945:
	.long	.Lc648
	.quad	.Lc550
	.quad	.Lc549-.Lc550
	.byte	4
	.long	.Lc551-.Lc550
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc946:
	.long	.Lc949-.Lc948
.Lc948:
	.long	.Lc648
	.quad	.Lc553
	.quad	.Lc552-.Lc553
	.byte	4
	.long	.Lc554-.Lc553
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc949:
	.long	.Lc952-.Lc951
.Lc951:
	.long	.Lc648
	.quad	.Lc556
	.quad	.Lc555-.Lc556
	.byte	4
	.long	.Lc557-.Lc556
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc952:
	.long	.Lc955-.Lc954
.Lc954:
	.long	.Lc648
	.quad	.Lc559
	.quad	.Lc558-.Lc559
	.byte	4
	.long	.Lc560-.Lc559
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc955:
	.long	.Lc958-.Lc957
.Lc957:
	.long	.Lc648
	.quad	.Lc562
	.quad	.Lc561-.Lc562
	.byte	2
	.byte	.Lc563-.Lc562
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc564-.Lc563
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc565-.Lc564
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc566-.Lc565
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc567-.Lc566
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc958:
	.long	.Lc961-.Lc960
.Lc960:
	.long	.Lc648
	.quad	.Lc569
	.quad	.Lc568-.Lc569
	.byte	2
	.byte	.Lc570-.Lc569
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc571-.Lc570
	.byte	5
	.uleb128	12
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc572-.Lc571
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc573-.Lc572
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc574-.Lc573
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc961:
	.long	.Lc964-.Lc963
.Lc963:
	.long	.Lc648
	.quad	.Lc576
	.quad	.Lc575-.Lc576
	.byte	2
	.byte	.Lc577-.Lc576
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc578-.Lc577
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc964:
	.long	.Lc967-.Lc966
.Lc966:
	.long	.Lc648
	.quad	.Lc580
	.quad	.Lc579-.Lc580
	.byte	2
	.byte	.Lc581-.Lc580
	.byte	5
	.uleb128	3
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc582-.Lc581
	.byte	5
	.uleb128	12
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc583-.Lc582
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc584-.Lc583
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc585-.Lc584
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc967:
	.long	.Lc970-.Lc969
.Lc969:
	.long	.Lc648
	.quad	.Lc587
	.quad	.Lc586-.Lc587
	.byte	2
	.byte	.Lc588-.Lc587
	.byte	5
	.uleb128	3
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc589-.Lc588
	.byte	5
	.uleb128	12
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc590-.Lc589
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc591-.Lc590
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc592-.Lc591
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc970:
	.long	.Lc973-.Lc972
.Lc972:
	.long	.Lc648
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
.Lc973:
	.long	.Lc976-.Lc975
.Lc975:
	.long	.Lc648
	.quad	.Lc598
	.quad	.Lc597-.Lc598
	.byte	2
	.byte	.Lc599-.Lc598
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc600-.Lc599
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc976:
	.long	.Lc979-.Lc978
.Lc978:
	.long	.Lc648
	.quad	.Lc602
	.quad	.Lc601-.Lc602
	.byte	2
	.byte	.Lc603-.Lc602
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc604-.Lc603
	.byte	5
	.uleb128	12
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc605-.Lc604
	.byte	5
	.uleb128	13
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc606-.Lc605
	.byte	5
	.uleb128	14
	.uleb128	12
	.byte	14
	.uleb128	48
	.byte	2
	.byte	.Lc607-.Lc606
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc608-.Lc607
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc609-.Lc608
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc610-.Lc609
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc611-.Lc610
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc979:
	.long	.Lc982-.Lc981
.Lc981:
	.long	.Lc648
	.quad	.Lc613
	.quad	.Lc612-.Lc613
	.byte	2
	.byte	.Lc614-.Lc613
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc615-.Lc614
	.byte	5
	.uleb128	12
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc616-.Lc615
	.byte	5
	.uleb128	13
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc617-.Lc616
	.byte	5
	.uleb128	14
	.uleb128	12
	.byte	14
	.uleb128	48
	.byte	2
	.byte	.Lc618-.Lc617
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc619-.Lc618
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc620-.Lc619
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc621-.Lc620
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc622-.Lc621
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc982:
	.long	.Lc985-.Lc984
.Lc984:
	.long	.Lc648
	.quad	.Lc624
	.quad	.Lc623-.Lc624
	.byte	2
	.byte	.Lc625-.Lc624
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc626-.Lc625
	.byte	5
	.uleb128	12
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc627-.Lc626
	.byte	5
	.uleb128	13
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc628-.Lc627
	.byte	5
	.uleb128	14
	.uleb128	12
	.byte	14
	.uleb128	48
	.byte	2
	.byte	.Lc629-.Lc628
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc630-.Lc629
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc631-.Lc630
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc632-.Lc631
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc633-.Lc632
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc985:
	.long	.Lc988-.Lc987
.Lc987:
	.long	.Lc648
	.quad	.Lc635
	.quad	.Lc634-.Lc635
	.byte	2
	.byte	.Lc636-.Lc635
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc637-.Lc636
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc988:
	.long	.Lc991-.Lc990
.Lc990:
	.long	.Lc648
	.quad	.Lc639
	.quad	.Lc638-.Lc639
	.byte	2
	.byte	.Lc640-.Lc639
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc641-.Lc640
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc991:
	.long	.Lc994-.Lc993
.Lc993:
	.long	.Lc648
	.quad	.Lc643
	.quad	.Lc642-.Lc643
	.byte	4
	.long	.Lc644-.Lc643
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc994:
	.long	.Lc997-.Lc996
.Lc996:
	.long	.Lc648
	.quad	.Lc646
	.quad	.Lc645-.Lc646
	.byte	4
	.long	.Lc647-.Lc646
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc997:
# End asmlist al_dwarf_frame
.section .note.GNU-stack,"",%progbits

