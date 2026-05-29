	.file "nextpas.core.atomic.pas"
# Begin asmlist al_pure_assembler

.section .text.n_nextpas.core.atomic_$$__compiler_barrier,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	.hidden NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	.type	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER,@function
NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER:
.Lc6:
# [nextpas.core.atomic.pas]
# [641] asm
#  CPU X86-64-V1
# [642] nop
	nop
#  CPU X86-64-V1
# [643] end;
	ret
.Lc5:
.Le0:
	.size	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER, .Le0 - NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
# End asmlist al_pure_assembler
# Begin asmlist al_procedures

.section .text.n_nextpas.core.atomic_$$_cpu_pause,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
	.type	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE,@function
NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE:
.Lc2:
# [630] begin
	pushq	%rax
.Lc3:
# [631] nextpas.core.atomic.core.cpu_pause;
	call	NEXTPAS.CORE.ATOMIC.CORE_$$_CPU_PAUSE
# [632] end;
	popq	%rcx
.Lc4:
	ret
.Lc1:
.Le1:
	.size	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE, .Le1 - NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE

.section .text.n_nextpas.core.atomic_$$__consume_memory_order$memory_order_t,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$__CONSUME_MEMORY_ORDER$MEMORY_ORDER_T
	.hidden NEXTPAS.CORE.ATOMIC_$$__CONSUME_MEMORY_ORDER$MEMORY_ORDER_T
	.type	NEXTPAS.CORE.ATOMIC_$$__CONSUME_MEMORY_ORDER$MEMORY_ORDER_T,@function
NEXTPAS.CORE.ATOMIC_$$__CONSUME_MEMORY_ORDER$MEMORY_ORDER_T:
.Lc8:
# Var aOrder located in register edi
# [653] begin
.Lc9:
# [656] end;
	ret
.Lc7:

.section .text.n_nextpas.core.atomic_$$__consume_memory_orders$memory_order_t$memory_order_t,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$__CONSUME_MEMORY_ORDERS$MEMORY_ORDER_T$MEMORY_ORDER_T
	.hidden NEXTPAS.CORE.ATOMIC_$$__CONSUME_MEMORY_ORDERS$MEMORY_ORDER_T$MEMORY_ORDER_T
	.type	NEXTPAS.CORE.ATOMIC_$$__CONSUME_MEMORY_ORDERS$MEMORY_ORDER_T$MEMORY_ORDER_T,@function
NEXTPAS.CORE.ATOMIC_$$__CONSUME_MEMORY_ORDERS$MEMORY_ORDER_T$MEMORY_ORDER_T:
.Lc11:
# Var aSuccessOrder located in register edi
# Var aFailureOrder located in register esi
# [659] begin
.Lc12:
# [662] end;
	ret
.Lc10:

.section .text.n_nextpas.core.atomic_$$_atomic_load$longint$memory_order_t$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_LOAD$LONGINT$MEMORY_ORDER_T$$LONGINT
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_LOAD$LONGINT$MEMORY_ORDER_T$$LONGINT,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_LOAD$LONGINT$MEMORY_ORDER_T$$LONGINT:
.Lc14:
# [924] begin
	pushq	%rbx
.Lc15:
	pushq	%r12
.Lc16:
	pushq	%rax
.Lc17:
	movq	%rdi,%rbx
# Var aObj located in register rbx
# Var aOrder located in register esi
# Var $result located in register r12d
# [925] Result := aObj;
	movl	(%rdi),%r12d
# [926] case aOrder of
	testl	%esi,%esi
	je	.Lj20
	subl	$1,%esi
	jb	.Lj19
	subl	$1,%esi
	jbe	.Lj21
	subl	$1,%esi
	je	.Lj22
	subl	$1,%esi
	je	.Lj21
	subl	$1,%esi
	je	.Lj23
	jmp	.Lj19
	.balign 16,0x90
.Lj20:
# [928] Result := aObj;
	movl	(%rbx),%r12d
	jmp	.Lj19
	.balign 16,0x90
.Lj21:
# [932] Result := aObj;
	movl	(%rbx),%r12d
# [934] _compiler_barrier;    // Acquire load on x86: compiler barrier is enough
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	jmp	.Lj19
	.balign 16,0x90
.Lj22:
# [943] Result := aObj;
	movl	(%rbx),%r12d
	jmp	.Lj19
	.balign 16,0x90
.Lj23:
# [952] Result := aObj;
	movl	(%rbx),%r12d
# [953] _compiler_barrier;
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	.balign 16,0x90
.Lj19:
# [961] end;
	movl	%r12d,%eax
	popq	%rcx
	popq	%r12
.Lc18:
	popq	%rbx
.Lc19:
	ret
.Lc13:

.section .text.n_nextpas.core.atomic_$$_atomic_load$longint$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_LOAD$LONGINT$$LONGINT
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_LOAD$LONGINT$$LONGINT,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_LOAD$LONGINT$$LONGINT:
.Lc21:
# Var aObj located in register rdi
# [964] begin
# [966] Result := atomic_load(aObj, mo_relaxed);
	movl	(%rdi),%eax
# Var $result located in register eax
.Lc22:
# [970] end;
	ret
.Lc20:

.section .text.n_nextpas.core.atomic_$$_atomic_load$longword$memory_order_t$$longword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_LOAD$LONGWORD$MEMORY_ORDER_T$$LONGWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_LOAD$LONGWORD$MEMORY_ORDER_T$$LONGWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_LOAD$LONGWORD$MEMORY_ORDER_T$$LONGWORD:
.Lc24:
# [973] begin
	pushq	%rbx
.Lc25:
	pushq	%r12
.Lc26:
	pushq	%rax
.Lc27:
	movq	%rdi,%rbx
# Var aObj located in register rbx
# Var aOrder located in register esi
# [976] Result := UInt32(atomic_load(PInt32(@aObj)^, aOrder));
	movl	(%rdi),%r12d
	testl	%esi,%esi
	je	.Lj31
	subl	$1,%esi
	jb	.Lj30
	subl	$1,%esi
	jbe	.Lj32
	subl	$1,%esi
	je	.Lj33
	subl	$1,%esi
	je	.Lj32
	subl	$1,%esi
	je	.Lj34
	jmp	.Lj30
	.balign 16,0x90
.Lj31:
	movl	(%rbx),%r12d
	jmp	.Lj30
	.balign 16,0x90
.Lj32:
	movl	(%rbx),%r12d
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	jmp	.Lj30
	.balign 16,0x90
.Lj33:
	movl	(%rbx),%r12d
	jmp	.Lj30
	.balign 16,0x90
.Lj34:
	movl	(%rbx),%r12d
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	.balign 16,0x90
.Lj30:
	movl	%r12d,%eax
# Var $result located in register eax
# [978] end;
	popq	%rcx
	popq	%r12
.Lc28:
	popq	%rbx
.Lc29:
	ret
.Lc23:

.section .text.n_nextpas.core.atomic_$$_atomic_load$longword$$longword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_LOAD$LONGWORD$$LONGWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_LOAD$LONGWORD$$LONGWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_LOAD$LONGWORD$$LONGWORD:
.Lc31:
# Var aObj located in register rdi
# [981] begin
# [984] Result := UInt32(atomic_load(PInt32(@aObj)^));
	movl	(%rdi),%eax
# Var $result located in register eax
.Lc32:
# [986] end;
	ret
.Lc30:

.section .text.n_nextpas.core.atomic_$$_atomic_load_64$int64$memory_order_t$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_LOAD_64$INT64$MEMORY_ORDER_T$$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_LOAD_64$INT64$MEMORY_ORDER_T$$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_LOAD_64$INT64$MEMORY_ORDER_T$$INT64:
.Lc34:
# [991] begin
	pushq	%rbx
.Lc35:
	pushq	%r12
.Lc36:
	pushq	%rax
.Lc37:
	movq	%rdi,%rbx
# Var aObj located in register rbx
# Var aOrder located in register esi
# Var $result located in register r12
# [992] Result := aObj;
	movq	(%rdi),%r12
# [1004] case aOrder of
	testl	%esi,%esi
	je	.Lj41
	subl	$1,%esi
	jb	.Lj40
	subl	$1,%esi
	jbe	.Lj42
	subl	$1,%esi
	je	.Lj43
	subl	$1,%esi
	je	.Lj42
	subl	$1,%esi
	je	.Lj44
	jmp	.Lj40
	.balign 16,0x90
.Lj41:
# [1006] Result := aObj;
	movq	(%rbx),%r12
	jmp	.Lj40
	.balign 16,0x90
.Lj42:
# [1010] Result := aObj;
	movq	(%rbx),%r12
# [1012] _compiler_barrier;
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	jmp	.Lj40
	.balign 16,0x90
.Lj43:
# [1019] Result := aObj;
	movq	(%rbx),%r12
	jmp	.Lj40
	.balign 16,0x90
.Lj44:
# [1024] Result := aObj;
	movq	(%rbx),%r12
# [1025] _compiler_barrier;
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	.balign 16,0x90
.Lj40:
# [1034] end;
	movq	%r12,%rax
	popq	%rcx
	popq	%r12
.Lc38:
	popq	%rbx
.Lc39:
	ret
.Lc33:

.section .text.n_nextpas.core.atomic_$$_atomic_load_64$int64$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_LOAD_64$INT64$$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_LOAD_64$INT64$$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_LOAD_64$INT64$$INT64:
.Lc41:
# Var aObj located in register rdi
# [1037] begin
# [1039] Result := atomic_load_64(aObj, mo_relaxed);
	movq	(%rdi),%rax
# Var $result located in register rax
.Lc42:
# [1043] end;
	ret
.Lc40:

.section .text.n_nextpas.core.atomic_$$_atomic_load_64$qword$memory_order_t$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_LOAD_64$QWORD$MEMORY_ORDER_T$$QWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_LOAD_64$QWORD$MEMORY_ORDER_T$$QWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_LOAD_64$QWORD$MEMORY_ORDER_T$$QWORD:
.Lc44:
# [1046] begin
	pushq	%rbx
.Lc45:
	pushq	%r12
.Lc46:
	pushq	%rax
.Lc47:
	movq	%rdi,%rbx
# Var aObj located in register rbx
# Var aOrder located in register esi
# [1049] Result := UInt64(atomic_load_64(PInt64(@aObj)^, aOrder));
	movq	(%rdi),%r12
	testl	%esi,%esi
	je	.Lj52
	subl	$1,%esi
	jb	.Lj51
	subl	$1,%esi
	jbe	.Lj53
	subl	$1,%esi
	je	.Lj54
	subl	$1,%esi
	je	.Lj53
	subl	$1,%esi
	je	.Lj55
	jmp	.Lj51
	.balign 16,0x90
.Lj52:
	movq	(%rbx),%r12
	jmp	.Lj51
	.balign 16,0x90
.Lj53:
	movq	(%rbx),%r12
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	jmp	.Lj51
	.balign 16,0x90
.Lj54:
	movq	(%rbx),%r12
	jmp	.Lj51
	.balign 16,0x90
.Lj55:
	movq	(%rbx),%r12
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	.balign 16,0x90
.Lj51:
# Var $result located in register rax
	movq	%r12,%rax
# [1051] end;
	popq	%rcx
	popq	%r12
.Lc48:
	popq	%rbx
.Lc49:
	ret
.Lc43:

.section .text.n_nextpas.core.atomic_$$_atomic_load_64$qword$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_LOAD_64$QWORD$$QWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_LOAD_64$QWORD$$QWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_LOAD_64$QWORD$$QWORD:
.Lc51:
# Var aObj located in register rdi
# [1054] begin
# [1057] Result := UInt64(atomic_load_64(PInt64(@aObj)^));
	movq	(%rdi),%rax
# Var $result located in register rax
.Lc52:
# [1059] end;
	ret
.Lc50:

.section .text.n_nextpas.core.atomic_$$_atomic_load$pointer$memory_order_t$$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_LOAD$POINTER$MEMORY_ORDER_T$$POINTER
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_LOAD$POINTER$MEMORY_ORDER_T$$POINTER,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_LOAD$POINTER$MEMORY_ORDER_T$$POINTER:
.Lc54:
# [1064] begin
	pushq	%rbx
.Lc55:
	pushq	%r12
.Lc56:
	pushq	%rax
.Lc57:
	movq	%rdi,%rbx
# Var aObj located in register rbx
# Var aOrder located in register esi
# [1070] Result := Pointer(atomic_load_64(PInt64(@aObj)^, aOrder));
	movq	(%rdi),%r12
	testl	%esi,%esi
	je	.Lj63
	subl	$1,%esi
	jb	.Lj62
	subl	$1,%esi
	jbe	.Lj64
	subl	$1,%esi
	je	.Lj65
	subl	$1,%esi
	je	.Lj64
	subl	$1,%esi
	je	.Lj66
	jmp	.Lj62
	.balign 16,0x90
.Lj63:
	movq	(%rbx),%r12
	jmp	.Lj62
	.balign 16,0x90
.Lj64:
	movq	(%rbx),%r12
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	jmp	.Lj62
	.balign 16,0x90
.Lj65:
	movq	(%rbx),%r12
	jmp	.Lj62
	.balign 16,0x90
.Lj66:
	movq	(%rbx),%r12
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	.balign 16,0x90
.Lj62:
# Var $result located in register rax
	movq	%r12,%rax
# [1073] end;
	popq	%rcx
	popq	%r12
.Lc58:
	popq	%rbx
.Lc59:
	ret
.Lc53:

.section .text.n_nextpas.core.atomic_$$_atomic_load$pointer$$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_LOAD$POINTER$$POINTER
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_LOAD$POINTER$$POINTER,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_LOAD$POINTER$$POINTER:
.Lc61:
# Var aObj located in register rdi
# [1076] begin
# [1078] Result := atomic_load(aObj, mo_relaxed);
	movq	(%rdi),%rax
# Var $result located in register rax
.Lc62:
# [1082] end;
	ret
.Lc60:

.section .text.n_nextpas.core.atomic_$$_atomic_load$int64$memory_order_t$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_LOAD$INT64$MEMORY_ORDER_T$$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_LOAD$INT64$MEMORY_ORDER_T$$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_LOAD$INT64$MEMORY_ORDER_T$$INT64:
.Lc64:
# [1086] begin
	pushq	%rbx
.Lc65:
	pushq	%r12
.Lc66:
	pushq	%rax
.Lc67:
	movq	%rdi,%rbx
# Var aObj located in register rbx
# Var aOrder located in register esi
# [1092] Result := PtrInt(atomic_load_64(PInt64(@aObj)^, aOrder));
	movq	(%rdi),%r12
	testl	%esi,%esi
	je	.Lj74
	subl	$1,%esi
	jb	.Lj73
	subl	$1,%esi
	jbe	.Lj75
	subl	$1,%esi
	je	.Lj76
	subl	$1,%esi
	je	.Lj75
	subl	$1,%esi
	je	.Lj77
	jmp	.Lj73
	.balign 16,0x90
.Lj74:
	movq	(%rbx),%r12
	jmp	.Lj73
	.balign 16,0x90
.Lj75:
	movq	(%rbx),%r12
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	jmp	.Lj73
	.balign 16,0x90
.Lj76:
	movq	(%rbx),%r12
	jmp	.Lj73
	.balign 16,0x90
.Lj77:
	movq	(%rbx),%r12
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	.balign 16,0x90
.Lj73:
# Var $result located in register rax
	movq	%r12,%rax
# [1095] end;
	popq	%rcx
	popq	%r12
.Lc68:
	popq	%rbx
.Lc69:
	ret
.Lc63:

.section .text.n_nextpas.core.atomic_$$_atomic_load$int64$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_LOAD$INT64$$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_LOAD$INT64$$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_LOAD$INT64$$INT64:
.Lc71:
# Var aObj located in register rdi
# [1098] begin
# [1100] Result := atomic_load(aObj, mo_relaxed);
	movq	(%rdi),%rax
# Var $result located in register rax
.Lc72:
# [1104] end;
	ret
.Lc70:

.section .text.n_nextpas.core.atomic_$$_atomic_load$qword$memory_order_t$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_LOAD$QWORD$MEMORY_ORDER_T$$QWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_LOAD$QWORD$MEMORY_ORDER_T$$QWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_LOAD$QWORD$MEMORY_ORDER_T$$QWORD:
.Lc74:
# [1108] begin
	pushq	%rbx
.Lc75:
	pushq	%r12
.Lc76:
	pushq	%rax
.Lc77:
	movq	%rdi,%rbx
# Var aObj located in register rbx
# Var aOrder located in register esi
# [1109] Result:= PtrUInt(atomic_load(PPtrInt(@aObj)^, aOrder));
	movq	(%rdi),%r12
	testl	%esi,%esi
	je	.Lj85
	subl	$1,%esi
	jb	.Lj84
	subl	$1,%esi
	jbe	.Lj86
	subl	$1,%esi
	je	.Lj87
	subl	$1,%esi
	je	.Lj86
	subl	$1,%esi
	je	.Lj88
	jmp	.Lj84
	.balign 16,0x90
.Lj85:
	movq	(%rbx),%r12
	jmp	.Lj84
	.balign 16,0x90
.Lj86:
	movq	(%rbx),%r12
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	jmp	.Lj84
	.balign 16,0x90
.Lj87:
	movq	(%rbx),%r12
	jmp	.Lj84
	.balign 16,0x90
.Lj88:
	movq	(%rbx),%r12
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	.balign 16,0x90
.Lj84:
	movq	%r12,%rax
# Var $result located in register rax
# [1110] end;
	popq	%rcx
	popq	%r12
.Lc78:
	popq	%rbx
.Lc79:
	ret
.Lc73:

.section .text.n_nextpas.core.atomic_$$_atomic_load$qword$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_LOAD$QWORD$$QWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_LOAD$QWORD$$QWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_LOAD$QWORD$$QWORD:
.Lc81:
# Var aObj located in register rdi
# [1113] begin
# [1114] Result:= PtrUInt(atomic_load(PPtrInt(@aObj)^));
	movq	(%rdi),%rax
# Var $result located in register rax
.Lc82:
# [1115] end;
	ret
.Lc80:

.section .text.n_nextpas.core.atomic_$$_atomic_store$longint$longint$memory_order_t,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_STORE$LONGINT$LONGINT$MEMORY_ORDER_T
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_STORE$LONGINT$LONGINT$MEMORY_ORDER_T,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_STORE$LONGINT$LONGINT$MEMORY_ORDER_T:
.Lc84:
# [1119] begin
	pushq	%rbx
.Lc85:
	pushq	%r12
.Lc86:
	pushq	%rax
.Lc87:
	movq	%rdi,%rbx
# Var aObj located in register rbx
	movl	%esi,%r12d
# Var aDesired located in register r12d
# Var aOrder located in register edx
# [1120] case aOrder of
	subl	$2,%edx
	jbe	.Lj95
	subl	$1,%edx
	subl	$1,%edx
	jbe	.Lj96
	subl	$1,%edx
	je	.Lj97
	jmp	.Lj94
	.balign 16,0x90
.Lj95:
# [1122] aObj := aDesired;  // store ......... acquire/consume
	movl	%r12d,(%rbx)
	jmp	.Lj94
	.balign 16,0x90
.Lj96:
# [1127] _compiler_barrier; // Release store on x86: compiler barrier is enough
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
# [1131] aObj := aDesired;
	movl	%r12d,(%rbx)
	jmp	.Lj94
	.balign 16,0x90
.Lj97:
# [1137] InterlockedExchange(aObj, aDesired);
	movq	%rbx,%rdi
	movl	%r12d,%esi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE$LONGINT$LONGINT$$LONGINT
	.balign 16,0x90
.Lj94:
# [1139] end;
	popq	%rcx
	popq	%r12
.Lc88:
	popq	%rbx
.Lc89:
	ret
.Lc83:

.section .text.n_nextpas.core.atomic_$$_atomic_store$longint$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_STORE$LONGINT$LONGINT
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_STORE$LONGINT$LONGINT,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_STORE$LONGINT$LONGINT:
.Lc91:
# Var aObj located in register rdi
# Var aDesired located in register esi
# [1142] begin
# Var aDesired located in register esi
# [1144] atomic_store(aObj, aDesired, mo_relaxed);
	movl	%esi,(%rdi)
.Lc92:
# [1148] end;
	ret
.Lc90:

.section .text.n_nextpas.core.atomic_$$_atomic_store$longword$longword$memory_order_t,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_STORE$LONGWORD$LONGWORD$MEMORY_ORDER_T
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_STORE$LONGWORD$LONGWORD$MEMORY_ORDER_T,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_STORE$LONGWORD$LONGWORD$MEMORY_ORDER_T:
.Lc94:
# [1151] begin
	pushq	%rbx
.Lc95:
	pushq	%r12
.Lc96:
	pushq	%rax
.Lc97:
# Var aDesired located at rsp+0, size=OS_32
	movq	%rdi,%rbx
# Var aObj located in register rbx
	movl	%esi,(%rsp)
# Var aOrder located in register edx
# [1154] atomic_store(PInt32(@aObj)^, PInt32(@aDesired)^, aOrder);
	movl	(%rsp),%r12d
	subl	$2,%edx
	jbe	.Lj103
	subl	$1,%edx
	subl	$1,%edx
	jbe	.Lj104
	subl	$1,%edx
	je	.Lj105
	jmp	.Lj102
	.balign 16,0x90
.Lj103:
	movl	%r12d,(%rbx)
	jmp	.Lj102
	.balign 16,0x90
.Lj104:
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	movl	%r12d,(%rbx)
	jmp	.Lj102
	.balign 16,0x90
.Lj105:
	movq	%rbx,%rdi
	movl	%r12d,%esi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE$LONGINT$LONGINT$$LONGINT
	.balign 16,0x90
.Lj102:
# [1156] end;
	popq	%rcx
	popq	%r12
.Lc98:
	popq	%rbx
.Lc99:
	ret
.Lc93:

.section .text.n_nextpas.core.atomic_$$_atomic_store$longword$longword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_STORE$LONGWORD$LONGWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_STORE$LONGWORD$LONGWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_STORE$LONGWORD$LONGWORD:
.Lc101:
# [1159] begin
	pushq	%rax
.Lc102:
# Var aDesired located at rsp+0, size=OS_32
# Var aObj located in register rdi
	movl	%esi,(%rsp)
# [1162] atomic_store(PInt32(@aObj)^, PInt32(@aDesired)^);
	movl	(%rsp),%eax
	movl	%eax,(%rdi)
# [1164] end;
	popq	%rcx
.Lc103:
	ret
.Lc100:

.section .text.n_nextpas.core.atomic_$$_atomic_store_64$int64$int64$memory_order_t,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_STORE_64$INT64$INT64$MEMORY_ORDER_T
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_STORE_64$INT64$INT64$MEMORY_ORDER_T,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_STORE_64$INT64$INT64$MEMORY_ORDER_T:
.Lc105:
# [1168] begin
	pushq	%rbx
.Lc106:
	pushq	%r12
.Lc107:
	pushq	%rax
.Lc108:
	movq	%rdi,%rbx
# Var aObj located in register rbx
	movq	%rsi,%r12
# Var aDesired located in register r12
# Var aOrder located in register edx
# [1180] case aOrder of
	subl	$2,%edx
	jbe	.Lj111
	subl	$1,%edx
	subl	$1,%edx
	jbe	.Lj112
	subl	$1,%edx
	je	.Lj113
	jmp	.Lj110
	.balign 16,0x90
.Lj111:
# [1182] aObj := aDesired;
	movq	%r12,(%rbx)
	jmp	.Lj110
	.balign 16,0x90
.Lj112:
# [1187] _compiler_barrier;
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
# [1191] aObj := aDesired;
	movq	%r12,(%rbx)
	jmp	.Lj110
	.balign 16,0x90
.Lj113:
# [1196] InterlockedExchange64(aObj, aDesired);
	movq	%rbx,%rdi
	movq	%r12,%rsi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE64$INT64$INT64$$INT64
	.balign 16,0x90
.Lj110:
# [1199] end;
	popq	%rcx
	popq	%r12
.Lc109:
	popq	%rbx
.Lc110:
	ret
.Lc104:

.section .text.n_nextpas.core.atomic_$$_atomic_store_64$int64$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_STORE_64$INT64$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_STORE_64$INT64$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_STORE_64$INT64$INT64:
.Lc112:
# Var aObj located in register rdi
# Var aDesired located in register rsi
# [1202] begin
# Var aDesired located in register rsi
# [1204] atomic_store_64(aObj, aDesired, mo_relaxed);
	movq	%rsi,(%rdi)
.Lc113:
# [1208] end;
	ret
.Lc111:

.section .text.n_nextpas.core.atomic_$$_atomic_store_64$qword$qword$memory_order_t,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_STORE_64$QWORD$QWORD$MEMORY_ORDER_T
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_STORE_64$QWORD$QWORD$MEMORY_ORDER_T,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_STORE_64$QWORD$QWORD$MEMORY_ORDER_T:
.Lc115:
# [1211] begin
	pushq	%rbx
.Lc116:
	pushq	%r12
.Lc117:
	pushq	%rax
.Lc118:
# Var aDesired located at rsp+0, size=OS_64
	movq	%rdi,%rbx
# Var aObj located in register rbx
	movq	%rsi,(%rsp)
# Var aOrder located in register edx
# [1214] atomic_store_64(PInt64(@aObj)^, PInt64(@aDesired)^, aOrder);
	movq	(%rsp),%r12
	subl	$2,%edx
	jbe	.Lj119
	subl	$1,%edx
	subl	$1,%edx
	jbe	.Lj120
	subl	$1,%edx
	je	.Lj121
	jmp	.Lj118
	.balign 16,0x90
.Lj119:
	movq	%r12,(%rbx)
	jmp	.Lj118
	.balign 16,0x90
.Lj120:
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	movq	%r12,(%rbx)
	jmp	.Lj118
	.balign 16,0x90
.Lj121:
	movq	%rbx,%rdi
	movq	%r12,%rsi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE64$INT64$INT64$$INT64
	.balign 16,0x90
.Lj118:
# [1216] end;
	popq	%rcx
	popq	%r12
.Lc119:
	popq	%rbx
.Lc120:
	ret
.Lc114:

.section .text.n_nextpas.core.atomic_$$_atomic_store_64$qword$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_STORE_64$QWORD$QWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_STORE_64$QWORD$QWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_STORE_64$QWORD$QWORD:
.Lc122:
# [1219] begin
	pushq	%rax
.Lc123:
# Var aDesired located at rsp+0, size=OS_64
# Var aObj located in register rdi
	movq	%rsi,(%rsp)
# [1222] atomic_store_64(PInt64(@aObj)^, PInt64(@aDesired)^);
	movq	(%rsp),%rax
	movq	%rax,(%rdi)
# [1224] end;
	popq	%rcx
.Lc124:
	ret
.Lc121:

.section .text.n_nextpas.core.atomic_$$_atomic_store$pointer$pointer$memory_order_t,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_STORE$POINTER$POINTER$MEMORY_ORDER_T
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_STORE$POINTER$POINTER$MEMORY_ORDER_T,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_STORE$POINTER$POINTER$MEMORY_ORDER_T:
.Lc126:
# [1228] begin
	pushq	%rbx
.Lc127:
	pushq	%r12
.Lc128:
	pushq	%rax
.Lc129:
# Var aDesired located at rsp+0, size=OS_64
	movq	%rdi,%rbx
# Var aObj located in register rbx
	movq	%rsi,(%rsp)
# Var aOrder located in register edx
# [1234] atomic_store_64(PInt64(@aObj)^, PInt64(@aDesired)^, aOrder);
	movq	(%rsp),%r12
	subl	$2,%edx
	jbe	.Lj127
	subl	$1,%edx
	subl	$1,%edx
	jbe	.Lj128
	subl	$1,%edx
	je	.Lj129
	jmp	.Lj126
	.balign 16,0x90
.Lj127:
	movq	%r12,(%rbx)
	jmp	.Lj126
	.balign 16,0x90
.Lj128:
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	movq	%r12,(%rbx)
	jmp	.Lj126
	.balign 16,0x90
.Lj129:
	movq	%rbx,%rdi
	movq	%r12,%rsi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE64$INT64$INT64$$INT64
	.balign 16,0x90
.Lj126:
# [1237] end;
	popq	%rcx
	popq	%r12
.Lc130:
	popq	%rbx
.Lc131:
	ret
.Lc125:

.section .text.n_nextpas.core.atomic_$$_atomic_store$pointer$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_STORE$POINTER$POINTER
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_STORE$POINTER$POINTER,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_STORE$POINTER$POINTER:
.Lc133:
# Temps allocated between rsp+0 and rsp+8
# [1240] begin
	pushq	%rax
.Lc134:
# Var aObj located in register rdi
# Var aDesired located in register rsi
# Var aDesired located in register rsi
# [1242] atomic_store(aObj, aDesired, mo_relaxed);
	movq	%rsi,(%rsp)
	movq	(%rsp),%rax
	movq	%rax,(%rdi)
# [1246] end;
	popq	%rcx
.Lc135:
	ret
.Lc132:

.section .text.n_nextpas.core.atomic_$$_atomic_store$int64$int64$memory_order_t,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_STORE$INT64$INT64$MEMORY_ORDER_T
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_STORE$INT64$INT64$MEMORY_ORDER_T,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_STORE$INT64$INT64$MEMORY_ORDER_T:
.Lc137:
# [1251] begin
	pushq	%rbx
.Lc138:
	pushq	%r12
.Lc139:
	pushq	%rax
.Lc140:
# Var aDesired located at rsp+0, size=OS_S64
	movq	%rdi,%rbx
# Var aObj located in register rbx
	movq	%rsi,(%rsp)
# Var aOrder located in register edx
# [1257] atomic_store_64(PInt64(@aObj)^, PInt64(@aDesired)^, aOrder);
	movq	(%rsp),%r12
	subl	$2,%edx
	jbe	.Lj135
	subl	$1,%edx
	subl	$1,%edx
	jbe	.Lj136
	subl	$1,%edx
	je	.Lj137
	jmp	.Lj134
	.balign 16,0x90
.Lj135:
	movq	%r12,(%rbx)
	jmp	.Lj134
	.balign 16,0x90
.Lj136:
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	movq	%r12,(%rbx)
	jmp	.Lj134
	.balign 16,0x90
.Lj137:
	movq	%rbx,%rdi
	movq	%r12,%rsi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE64$INT64$INT64$$INT64
	.balign 16,0x90
.Lj134:
# [1260] end;
	popq	%rcx
	popq	%r12
.Lc141:
	popq	%rbx
.Lc142:
	ret
.Lc136:

.section .text.n_nextpas.core.atomic_$$_atomic_store$int64$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_STORE$INT64$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_STORE$INT64$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_STORE$INT64$INT64:
.Lc144:
# Temps allocated between rsp+0 and rsp+8
# [1263] begin
	pushq	%rax
.Lc145:
# Var aObj located in register rdi
# Var aDesired located in register rsi
# Var aDesired located in register rsi
# [1265] atomic_store(aObj, aDesired, mo_relaxed);
	movq	%rsi,(%rsp)
	movq	(%rsp),%rax
	movq	%rax,(%rdi)
# [1269] end;
	popq	%rcx
.Lc146:
	ret
.Lc143:

.section .text.n_nextpas.core.atomic_$$_atomic_store$qword$qword$memory_order_t,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_STORE$QWORD$QWORD$MEMORY_ORDER_T
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_STORE$QWORD$QWORD$MEMORY_ORDER_T,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_STORE$QWORD$QWORD$MEMORY_ORDER_T:
.Lc148:
# Temps allocated between rsp+8 and rsp+16
# [1272] begin
	pushq	%rbx
.Lc149:
	pushq	%r12
.Lc150:
	leaq	-24(%rsp),%rsp
.Lc151:
# Var aDesired located at rsp+0, size=OS_64
	movq	%rdi,%rbx
# Var aObj located in register rbx
	movq	%rsi,(%rsp)
# Var aOrder located in register edx
# [1273] atomic_store(PPtrInt(@aObj)^, PPtrInt(@aDesired)^, aOrder);
	movq	(%rsp),%r12
	movq	%r12,8(%rsp)
	subl	$2,%edx
	jbe	.Lj143
	subl	$1,%edx
	subl	$1,%edx
	jbe	.Lj144
	subl	$1,%edx
	je	.Lj145
	jmp	.Lj142
	.balign 16,0x90
.Lj143:
	movq	%r12,(%rbx)
	jmp	.Lj142
	.balign 16,0x90
.Lj144:
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	movq	%r12,(%rbx)
	jmp	.Lj142
	.balign 16,0x90
.Lj145:
	movq	%rbx,%rdi
	movq	%r12,%rsi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE64$INT64$INT64$$INT64
	.balign 16,0x90
.Lj142:
# [1274] end;
	leaq	24(%rsp),%rsp
	popq	%r12
.Lc152:
	popq	%rbx
.Lc153:
	ret
.Lc147:

.section .text.n_nextpas.core.atomic_$$_atomic_store$qword$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_STORE$QWORD$QWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_STORE$QWORD$QWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_STORE$QWORD$QWORD:
.Lc155:
# Temps allocated between rsp+8 and rsp+16
# [1277] begin
	leaq	-24(%rsp),%rsp
.Lc156:
# Var aDesired located at rsp+0, size=OS_64
# Var aObj located in register rdi
	movq	%rsi,(%rsp)
# [1278] atomic_store(PPtrInt(@aObj)^, PPtrInt(@aDesired)^);
	movq	(%rsp),%rax
	movq	%rax,8(%rsp)
	leaq	8(%rsp),%rax
	movq	(%rax),%rax
	movq	%rax,(%rdi)
# [1279] end;
	leaq	24(%rsp),%rsp
.Lc157:
	ret
.Lc154:

.section .text.n_nextpas.core.atomic_$$_atomic_exchange$longint$longint$memory_order_t$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT:
.Lc159:
# [1285] begin
	pushq	%rax
.Lc160:
# Var aObj located in register rdi
# Var aDesired located in register esi
# Var aOrder located in register edx
# Var aDesired located in register esi
# [1303] Result := InterlockedExchange(aObj, aDesired);
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE$LONGINT$LONGINT$$LONGINT
# Var $result located in register eax
# [1315] end;
	popq	%rcx
.Lc161:
	ret
.Lc158:

.section .text.n_nextpas.core.atomic_$$_atomic_exchange$longint$longint$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE$LONGINT$LONGINT$$LONGINT
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE$LONGINT$LONGINT$$LONGINT,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE$LONGINT$LONGINT$$LONGINT:
.Lc163:
# [1318] begin
	pushq	%rax
.Lc164:
# Var aObj located in register rdi
# Var aDesired located in register esi
# Var aDesired located in register esi
# [1320] Result := atomic_exchange(aObj, aDesired, mo_seq_cst);
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE$LONGINT$LONGINT$$LONGINT
# Var $result located in register eax
# [1321] end;
	popq	%rcx
.Lc165:
	ret
.Lc162:

.section .text.n_nextpas.core.atomic_$$_atomic_exchange$longword$longword$memory_order_t$$longword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE$LONGWORD$LONGWORD$MEMORY_ORDER_T$$LONGWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE$LONGWORD$LONGWORD$MEMORY_ORDER_T$$LONGWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE$LONGWORD$LONGWORD$MEMORY_ORDER_T$$LONGWORD:
.Lc167:
# [1324] begin
	pushq	%rax
.Lc168:
# Var aDesired located at rsp+0, size=OS_32
# Var aObj located in register rdi
	movl	%esi,(%rsp)
# Var aOrder located in register edx
# [1327] Result := UInt32(atomic_exchange(PInt32(@aObj)^, PInt32(@aDesired)^, aOrder));
	movl	(%rsp),%esi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE$LONGINT$LONGINT$$LONGINT
# Var $result located in register eax
# [1329] end;
	popq	%rcx
.Lc169:
	ret
.Lc166:

.section .text.n_nextpas.core.atomic_$$_atomic_exchange$longword$longword$$longword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE$LONGWORD$LONGWORD$$LONGWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE$LONGWORD$LONGWORD$$LONGWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE$LONGWORD$LONGWORD$$LONGWORD:
.Lc171:
# [1332] begin
	pushq	%rax
.Lc172:
# Var aDesired located at rsp+0, size=OS_32
# Var aObj located in register rdi
	movl	%esi,(%rsp)
# [1335] Result := UInt32(atomic_exchange(PInt32(@aObj)^, PInt32(@aDesired)^));
	movl	(%rsp),%esi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE$LONGINT$LONGINT$$LONGINT
# Var $result located in register eax
# [1337] end;
	popq	%rcx
.Lc173:
	ret
.Lc170:

.section .text.n_nextpas.core.atomic_$$_atomic_exchange$int64$int64$memory_order_t$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE$INT64$INT64$MEMORY_ORDER_T$$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE$INT64$INT64$MEMORY_ORDER_T$$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE$INT64$INT64$MEMORY_ORDER_T$$INT64:
.Lc175:
# [1341] begin
	pushq	%rax
.Lc176:
# Var aDesired located at rsp+0, size=OS_S64
# Var aObj located in register rdi
	movq	%rsi,(%rsp)
# Var aOrder located in register edx
# [1347] Result := PtrInt(atomic_exchange_64(PInt64(@aObj)^, PInt64(@aDesired)^, aOrder));
	movq	(%rsp),%rsi
# Var aOrder located in register edx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE_64$INT64$INT64$MEMORY_ORDER_T$$INT64
# Var $result located in register rax
# [1350] end;
	popq	%rcx
.Lc177:
	ret
.Lc174:

.section .text.n_nextpas.core.atomic_$$_atomic_exchange$int64$int64$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE$INT64$INT64$$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE$INT64$INT64$$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE$INT64$INT64$$INT64:
.Lc179:
# Temps allocated between rsp+0 and rsp+8
# [1353] begin
	pushq	%rax
.Lc180:
# Var aObj located in register rdi
# Var aDesired located in register rsi
# Var aDesired located in register rsi
# [1355] Result := atomic_exchange(aObj, aDesired, mo_seq_cst);
	movq	%rsi,(%rsp)
	movq	(%rsp),%rsi
	movl	$5,%edx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE_64$INT64$INT64$MEMORY_ORDER_T$$INT64
# Var $result located in register rax
# [1356] end;
	popq	%rcx
.Lc181:
	ret
.Lc178:

.section .text.n_nextpas.core.atomic_$$_atomic_exchange$qword$qword$memory_order_t$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE$QWORD$QWORD$MEMORY_ORDER_T$$QWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE$QWORD$QWORD$MEMORY_ORDER_T$$QWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE$QWORD$QWORD$MEMORY_ORDER_T$$QWORD:
.Lc183:
# Temps allocated between rsp+8 and rsp+16
# [1359] begin
	leaq	-24(%rsp),%rsp
.Lc184:
# Var aDesired located at rsp+0, size=OS_64
# Var aObj located in register rdi
	movq	%rsi,(%rsp)
# Var aOrder located in register edx
# [1360] Result := PtrUInt(atomic_exchange(PPtrInt(@aObj)^, PPtrInt(@aDesired)^, aOrder));
	movq	(%rsp),%rsi
	movq	%rsi,8(%rsp)
# Var aOrder located in register edx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE_64$INT64$INT64$MEMORY_ORDER_T$$INT64
# Var $result located in register rax
# [1361] end;
	leaq	24(%rsp),%rsp
.Lc185:
	ret
.Lc182:

.section .text.n_nextpas.core.atomic_$$_atomic_exchange$qword$qword$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE$QWORD$QWORD$$QWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE$QWORD$QWORD$$QWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE$QWORD$QWORD$$QWORD:
.Lc187:
# Temps allocated between rsp+8 and rsp+16
# [1364] begin
	leaq	-24(%rsp),%rsp
.Lc188:
# Var aDesired located at rsp+0, size=OS_64
# Var aObj located in register rdi
	movq	%rsi,(%rsp)
# [1365] Result := PtrUInt(atomic_exchange(PPtrInt(@aObj)^, PPtrInt(@aDesired)^));
	movq	(%rsp),%rsi
	movq	%rsi,8(%rsp)
	movl	$5,%edx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE_64$INT64$INT64$MEMORY_ORDER_T$$INT64
# Var $result located in register rax
# [1366] end;
	leaq	24(%rsp),%rsp
.Lc189:
	ret
.Lc186:

.section .text.n_nextpas.core.atomic_$$_atomic_exchange_64$int64$int64$memory_order_t$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE_64$INT64$INT64$MEMORY_ORDER_T$$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE_64$INT64$INT64$MEMORY_ORDER_T$$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE_64$INT64$INT64$MEMORY_ORDER_T$$INT64:
.Lc191:
# [1371] begin
	pushq	%rax
.Lc192:
# Var aObj located in register rdi
# Var aDesired located in register rsi
# Var aOrder located in register edx
# Var aDesired located in register rsi
# [1393] Result := InterlockedExchange64(aObj, aDesired);
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE64$INT64$INT64$$INT64
# Var $result located in register rax
# [1406] end;
	popq	%rcx
.Lc193:
	ret
.Lc190:
.Le2:
	.size	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE_64$INT64$INT64$MEMORY_ORDER_T$$INT64, .Le2 - NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE_64$INT64$INT64$MEMORY_ORDER_T$$INT64

.section .text.n_nextpas.core.atomic_$$_atomic_exchange_64$int64$int64$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE_64$INT64$INT64$$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE_64$INT64$INT64$$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE_64$INT64$INT64$$INT64:
.Lc195:
# [1409] begin
	pushq	%rax
.Lc196:
# Var aObj located in register rdi
# Var aDesired located in register rsi
# Var aDesired located in register rsi
# [1411] Result := atomic_exchange_64(aObj, aDesired, mo_seq_cst);
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE64$INT64$INT64$$INT64
# Var $result located in register rax
# [1412] end;
	popq	%rcx
.Lc197:
	ret
.Lc194:

.section .text.n_nextpas.core.atomic_$$_atomic_exchange_64$qword$qword$memory_order_t$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE_64$QWORD$QWORD$MEMORY_ORDER_T$$QWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE_64$QWORD$QWORD$MEMORY_ORDER_T$$QWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE_64$QWORD$QWORD$MEMORY_ORDER_T$$QWORD:
.Lc199:
# [1415] begin
	pushq	%rax
.Lc200:
# Var aDesired located at rsp+0, size=OS_64
# Var aObj located in register rdi
	movq	%rsi,(%rsp)
# Var aOrder located in register edx
# [1418] Result := UInt64(atomic_exchange_64(PInt64(@aObj)^, PInt64(@aDesired)^, aOrder));
	movq	(%rsp),%rsi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE64$INT64$INT64$$INT64
# Var $result located in register rax
# [1420] end;
	popq	%rcx
.Lc201:
	ret
.Lc198:

.section .text.n_nextpas.core.atomic_$$_atomic_exchange_64$qword$qword$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE_64$QWORD$QWORD$$QWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE_64$QWORD$QWORD$$QWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE_64$QWORD$QWORD$$QWORD:
.Lc203:
# [1423] begin
	pushq	%rax
.Lc204:
# Var aDesired located at rsp+0, size=OS_64
# Var aObj located in register rdi
	movq	%rsi,(%rsp)
# [1426] Result := UInt64(atomic_exchange_64(PInt64(@aObj)^, PInt64(@aDesired)^));
	movq	(%rsp),%rsi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE64$INT64$INT64$$INT64
# Var $result located in register rax
# [1428] end;
	popq	%rcx
.Lc205:
	ret
.Lc202:

.section .text.n_nextpas.core.atomic_$$_atomic_exchange$pointer$pointer$memory_order_t$$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE$POINTER$POINTER$MEMORY_ORDER_T$$POINTER
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE$POINTER$POINTER$MEMORY_ORDER_T$$POINTER,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE$POINTER$POINTER$MEMORY_ORDER_T$$POINTER:
.Lc207:
# [1432] begin
	pushq	%rax
.Lc208:
# Var aDesired located at rsp+0, size=OS_64
# Var aObj located in register rdi
	movq	%rsi,(%rsp)
# Var aOrder located in register edx
# [1438] Result := Pointer(atomic_exchange_64(PInt64(@aObj)^, PInt64(@aDesired)^, aOrder));
	movq	(%rsp),%rsi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE64$INT64$INT64$$INT64
# Var $result located in register rax
# [1441] end;
	popq	%rcx
.Lc209:
	ret
.Lc206:

.section .text.n_nextpas.core.atomic_$$_atomic_exchange$pointer$pointer$$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE$POINTER$POINTER$$POINTER
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE$POINTER$POINTER$$POINTER,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_EXCHANGE$POINTER$POINTER$$POINTER:
.Lc211:
# Temps allocated between rsp+0 and rsp+8
# [1444] begin
	pushq	%rax
.Lc212:
# Var aObj located in register rdi
# Var aDesired located in register rsi
# Var aDesired located in register rsi
# [1446] Result := atomic_exchange(aObj, aDesired, mo_seq_cst);
	movq	%rsi,(%rsp)
	movq	(%rsp),%rsi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE64$INT64$INT64$$INT64
# Var $result located in register rax
# [1447] end;
	popq	%rcx
.Lc213:
	ret
.Lc210:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_64$int64$int64$int64$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_64$INT64$INT64$INT64$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_64$INT64$INT64$INT64$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_64$INT64$INT64$INT64$$BOOLEAN:
.Lc215:
# [1451] begin
	pushq	%rax
.Lc216:
# Var aObj located in register rdi
# Var aExpected located in register rsi
# Var aDesired located in register rdx
# [1453] Result := atomic_compare_exchange_strong_64(aObj, aExpected, aDesired, mo_seq_cst, mo_seq_cst);
	movl	$5,%r8d
	movl	$5,%ecx
# Var aDesired located in register rdx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG_64$hGRw81D8Bv5H
# Var $result located in register al
# [1454] end;
	popq	%rcx
.Lc217:
	ret
.Lc214:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_64$qword$qword$qword$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_64$QWORD$QWORD$QWORD$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_64$QWORD$QWORD$QWORD$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_64$QWORD$QWORD$QWORD$$BOOLEAN:
.Lc219:
# [1457] begin
	pushq	%rax
.Lc220:
# Var aDesired located at rsp+0, size=OS_64
# Var aObj located in register rdi
# Var aExpected located in register rsi
	movq	%rdx,(%rsp)
# [1460] Result := atomic_compare_exchange_strong_64(PInt64(@aObj)^, PInt64(@aExpected)^, PInt64(@aDesired)^, mo_seq_cst, mo_seq_cst);
	movq	(%rsp),%rdx
	movl	$5,%r8d
	movl	$5,%ecx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG_64$hGRw81D8Bv5H
# Var $result located in register al
# [1462] end;
	popq	%rcx
.Lc221:
	ret
.Lc218:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange$longint$longint$longint$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE$LONGINT$LONGINT$LONGINT$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE$LONGINT$LONGINT$LONGINT$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE$LONGINT$LONGINT$LONGINT$$BOOLEAN:
.Lc223:
# [1466] begin
	pushq	%rax
.Lc224:
# Var aObj located in register rdi
# Var aExpected located in register rsi
# Var aDesired located in register edx
# [1468] Result := atomic_compare_exchange_strong(aObj, aExpected, aDesired, mo_seq_cst, mo_seq_cst);
	movl	$5,%r8d
	movl	$5,%ecx
# Var aDesired located in register edx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$ha3tEJVtd1eO
# Var $result located in register al
# [1469] end;
	popq	%rcx
.Lc225:
	ret
.Lc222:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange$longword$longword$longword$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE$LONGWORD$LONGWORD$LONGWORD$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE$LONGWORD$LONGWORD$LONGWORD$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE$LONGWORD$LONGWORD$LONGWORD$$BOOLEAN:
.Lc227:
# [1472] begin
	pushq	%rax
.Lc228:
# Var aDesired located at rsp+0, size=OS_32
# Var aObj located in register rdi
# Var aExpected located in register rsi
	movl	%edx,(%rsp)
# [1475] Result := atomic_compare_exchange_strong(PInt32(@aObj)^, PInt32(@aExpected)^, PInt32(@aDesired)^, mo_seq_cst, mo_seq_cst);
	movl	(%rsp),%edx
	movl	$5,%r8d
	movl	$5,%ecx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$ha3tEJVtd1eO
# Var $result located in register al
# [1477] end;
	popq	%rcx
.Lc229:
	ret
.Lc226:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange$int64$int64$int64$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE$INT64$INT64$INT64$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE$INT64$INT64$INT64$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE$INT64$INT64$INT64$$BOOLEAN:
.Lc231:
# [1481] begin
	pushq	%rax
.Lc232:
# Var aObj located in register rdi
# Var aExpected located in register rsi
# Var aDesired located in register rdx
# [1483] Result := atomic_compare_exchange_strong(aObj, aExpected, aDesired, mo_seq_cst, mo_seq_cst);
	movl	$5,%r8d
	movl	$5,%ecx
# Var aDesired located in register rdx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$hGRw81D8Bv5H
# Var $result located in register al
# [1484] end;
	popq	%rcx
.Lc233:
	ret
.Lc230:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange$qword$qword$qword$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE$QWORD$QWORD$QWORD$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE$QWORD$QWORD$QWORD$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE$QWORD$QWORD$QWORD$$BOOLEAN:
.Lc235:
# [1487] begin
	pushq	%rax
.Lc236:
# Var aObj located in register rdi
# Var aExpected located in register rsi
# Var aDesired located in register rdx
# [1489] Result := atomic_compare_exchange_strong(aObj, aExpected, aDesired, mo_seq_cst, mo_seq_cst);
	movl	$5,%r8d
	movl	$5,%ecx
# Var aDesired located in register rdx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$hGgN1AvG799K
# Var $result located in register al
# [1490] end;
	popq	%rcx
.Lc237:
	ret
.Lc234:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange$pointer$pointer$pointer$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE$POINTER$POINTER$POINTER$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE$POINTER$POINTER$POINTER$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE$POINTER$POINTER$POINTER$$BOOLEAN:
.Lc239:
# [1494] begin
	pushq	%rax
.Lc240:
# Var aObj located in register rdi
# Var aExpected located in register rsi
# Var aDesired located in register rdx
# [1496] Result := atomic_compare_exchange_strong(aObj, aExpected, aDesired, mo_seq_cst, mo_seq_cst);
	movl	$5,%r8d
	movl	$5,%ecx
# Var aDesired located in register rdx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$hQsFemyUynKP
# Var $result located in register al
# [1497] end;
	popq	%rcx
.Lc241:
	ret
.Lc238:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_strong$longint$longint$longint$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$LONGINT$LONGINT$LONGINT$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$LONGINT$LONGINT$LONGINT$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$LONGINT$LONGINT$LONGINT$$BOOLEAN:
.Lc243:
# [1500] begin
	pushq	%rax
.Lc244:
# Var aObj located in register rdi
# Var aExpected located in register rsi
# Var aDesired located in register edx
# [1501] Result := atomic_compare_exchange(aObj, aExpected, aDesired);
	movl	$5,%r8d
	movl	$5,%ecx
# Var aDesired located in register edx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$ha3tEJVtd1eO
# Var $result located in register al
# [1502] end;
	popq	%rcx
.Lc245:
	ret
.Lc242:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_strong$longword$longword$longword$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$LONGWORD$LONGWORD$LONGWORD$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$LONGWORD$LONGWORD$LONGWORD$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$LONGWORD$LONGWORD$LONGWORD$$BOOLEAN:
.Lc247:
# [1505] begin
	pushq	%rax
.Lc248:
# Var aDesired located at rsp+0, size=OS_32
# Var aObj located in register rdi
# Var aExpected located in register rsi
	movl	%edx,(%rsp)
# [1508] Result := atomic_compare_exchange(PInt32(@aObj)^, PInt32(@aExpected)^, PInt32(@aDesired)^);
	movl	(%rsp),%edx
	movl	$5,%r8d
	movl	$5,%ecx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$ha3tEJVtd1eO
# Var $result located in register al
# [1510] end;
	popq	%rcx
.Lc249:
	ret
.Lc246:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_strong$int64$int64$int64$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$INT64$INT64$INT64$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$INT64$INT64$INT64$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$INT64$INT64$INT64$$BOOLEAN:
.Lc251:
# [1514] begin
	pushq	%rax
.Lc252:
# Var aObj located in register rdi
# Var aExpected located in register rsi
# Var aDesired located in register rdx
# [1515] Result := atomic_compare_exchange(aObj, aExpected, aDesired);
	movl	$5,%r8d
	movl	$5,%ecx
# Var aDesired located in register rdx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$hGRw81D8Bv5H
# Var $result located in register al
# [1516] end;
	popq	%rcx
.Lc253:
	ret
.Lc250:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_strong$qword$qword$qword$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$QWORD$QWORD$QWORD$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$QWORD$QWORD$QWORD$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$QWORD$QWORD$QWORD$$BOOLEAN:
.Lc255:
# [1519] begin
	pushq	%rax
.Lc256:
# Var aDesired located at rsp+0, size=OS_64
# Var aObj located in register rdi
# Var aExpected located in register rsi
	movq	%rdx,(%rsp)
# [1520] Result := atomic_compare_exchange(PPtrInt(@aObj)^, PPtrInt(@aExpected)^, PPtrInt(@aDesired)^);
	movq	(%rsp),%rdx
	movl	$5,%r8d
	movl	$5,%ecx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$hGRw81D8Bv5H
# Var $result located in register al
# [1521] end;
	popq	%rcx
.Lc257:
	ret
.Lc254:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_strong_64$qword$qword$qword$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG_64$QWORD$QWORD$QWORD$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG_64$QWORD$QWORD$QWORD$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG_64$QWORD$QWORD$QWORD$$BOOLEAN:
.Lc259:
# [1526] begin
	pushq	%rax
.Lc260:
# Var aDesired located at rsp+0, size=OS_64
# Var aObj located in register rdi
# Var aExpected located in register rsi
	movq	%rdx,(%rsp)
# [1529] Result := atomic_compare_exchange_64(PInt64(@aObj)^, PInt64(@aExpected)^, PInt64(@aDesired)^);
	movq	(%rsp),%rdx
	movl	$5,%r8d
	movl	$5,%ecx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG_64$hGRw81D8Bv5H
# Var $result located in register al
# [1531] end;
	popq	%rcx
.Lc261:
	ret
.Lc258:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_strong_64$int64$int64$int64$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG_64$INT64$INT64$INT64$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG_64$INT64$INT64$INT64$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG_64$INT64$INT64$INT64$$BOOLEAN:
.Lc263:
# [1534] begin
	pushq	%rax
.Lc264:
# Var aObj located in register rdi
# Var aExpected located in register rsi
# Var aDesired located in register rdx
# [1535] Result := atomic_compare_exchange_64(aObj, aExpected, aDesired);
	movl	$5,%r8d
	movl	$5,%ecx
# Var aDesired located in register rdx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG_64$hGRw81D8Bv5H
# Var $result located in register al
# [1536] end;
	popq	%rcx
.Lc265:
	ret
.Lc262:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_strong$pointer$pointer$pointer$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$POINTER$POINTER$POINTER$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$POINTER$POINTER$POINTER$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$POINTER$POINTER$POINTER$$BOOLEAN:
.Lc267:
# [1540] begin
	pushq	%rax
.Lc268:
# Var aObj located in register rdi
# Var aExpected located in register rsi
# Var aDesired located in register rdx
# [1541] Result := atomic_compare_exchange(aObj, aExpected, aDesired);
	movl	$5,%r8d
	movl	$5,%ecx
# Var aDesired located in register rdx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$hQsFemyUynKP
# Var $result located in register al
# [1542] end;
	popq	%rcx
.Lc269:
	ret
.Lc266:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_weak$longint$longint$longint$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$LONGINT$LONGINT$LONGINT$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$LONGINT$LONGINT$LONGINT$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$LONGINT$LONGINT$LONGINT$$BOOLEAN:
.Lc271:
# [1545] begin
	pushq	%rax
.Lc272:
# Var aObj located in register rdi
# Var aExpected located in register rsi
# Var aDesired located in register edx
# [1546] Result := atomic_compare_exchange(aObj, aExpected, aDesired);
	movl	$5,%r8d
	movl	$5,%ecx
# Var aDesired located in register edx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$ha3tEJVtd1eO
# Var $result located in register al
# [1547] end;
	popq	%rcx
.Lc273:
	ret
.Lc270:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_weak$longword$longword$longword$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$LONGWORD$LONGWORD$LONGWORD$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$LONGWORD$LONGWORD$LONGWORD$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$LONGWORD$LONGWORD$LONGWORD$$BOOLEAN:
.Lc275:
# [1550] begin
	pushq	%rax
.Lc276:
# Var aDesired located at rsp+0, size=OS_32
# Var aObj located in register rdi
# Var aExpected located in register rsi
	movl	%edx,(%rsp)
# [1553] Result := atomic_compare_exchange(PInt32(@aObj)^, PInt32(@aExpected)^, PInt32(@aDesired)^);
	movl	(%rsp),%edx
	movl	$5,%r8d
	movl	$5,%ecx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$ha3tEJVtd1eO
# Var $result located in register al
# [1555] end;
	popq	%rcx
.Lc277:
	ret
.Lc274:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_weak$int64$int64$int64$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$INT64$INT64$INT64$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$INT64$INT64$INT64$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$INT64$INT64$INT64$$BOOLEAN:
.Lc279:
# [1559] begin
	pushq	%rax
.Lc280:
# Var aObj located in register rdi
# Var aExpected located in register rsi
# Var aDesired located in register rdx
# [1560] Result := atomic_compare_exchange(aObj, aExpected, aDesired);
	movl	$5,%r8d
	movl	$5,%ecx
# Var aDesired located in register rdx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$hGRw81D8Bv5H
# Var $result located in register al
# [1561] end;
	popq	%rcx
.Lc281:
	ret
.Lc278:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_weak$qword$qword$qword$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$QWORD$QWORD$QWORD$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$QWORD$QWORD$QWORD$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$QWORD$QWORD$QWORD$$BOOLEAN:
.Lc283:
# [1564] begin
	pushq	%rax
.Lc284:
# Var aDesired located at rsp+0, size=OS_64
# Var aObj located in register rdi
# Var aExpected located in register rsi
	movq	%rdx,(%rsp)
# [1565] Result := atomic_compare_exchange(PPtrInt(@aObj)^, PPtrInt(@aExpected)^, PPtrInt(@aDesired)^);
	movq	(%rsp),%rdx
	movl	$5,%r8d
	movl	$5,%ecx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$hGRw81D8Bv5H
# Var $result located in register al
# [1566] end;
	popq	%rcx
.Lc285:
	ret
.Lc282:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_weak_64$int64$int64$int64$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK_64$INT64$INT64$INT64$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK_64$INT64$INT64$INT64$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK_64$INT64$INT64$INT64$$BOOLEAN:
.Lc287:
# [1571] begin
	pushq	%rax
.Lc288:
# Var aObj located in register rdi
# Var aExpected located in register rsi
# Var aDesired located in register rdx
# [1572] Result := atomic_compare_exchange_64(aObj, aExpected, aDesired);
	movl	$5,%r8d
	movl	$5,%ecx
# Var aDesired located in register rdx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG_64$hGRw81D8Bv5H
# Var $result located in register al
# [1573] end;
	popq	%rcx
.Lc289:
	ret
.Lc286:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_weak_64$qword$qword$qword$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK_64$QWORD$QWORD$QWORD$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK_64$QWORD$QWORD$QWORD$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK_64$QWORD$QWORD$QWORD$$BOOLEAN:
.Lc291:
# [1576] begin
	pushq	%rax
.Lc292:
# Var aDesired located at rsp+0, size=OS_64
# Var aObj located in register rdi
# Var aExpected located in register rsi
	movq	%rdx,(%rsp)
# [1579] Result := atomic_compare_exchange_64(PInt64(@aObj)^, PInt64(@aExpected)^, PInt64(@aDesired)^);
	movq	(%rsp),%rdx
	movl	$5,%r8d
	movl	$5,%ecx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG_64$hGRw81D8Bv5H
# Var $result located in register al
# [1581] end;
	popq	%rcx
.Lc293:
	ret
.Lc290:

.section .text.n_nextpas.core.atomic_$$_atomic_increment_64$int64$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_INCREMENT_64$INT64$$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_INCREMENT_64$INT64$$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_INCREMENT_64$INT64$$INT64:
.Lc295:
# [1586] begin
	pushq	%rax
.Lc296:
# Var aObj located in register rdi
# [1588] Result := atomic_fetch_add_64(aObj, 1, mo_seq_cst) + 1;
	movl	$5,%edx
	movl	$1,%esi
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD_64$INT64$INT64$MEMORY_ORDER_T$$INT64
	addq	$1,%rax
# Var $result located in register rax
# [1589] end;
	popq	%rcx
.Lc297:
	ret
.Lc294:

.section .text.n_nextpas.core.atomic_$$_atomic_increment_64$qword$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_INCREMENT_64$QWORD$$QWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_INCREMENT_64$QWORD$$QWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_INCREMENT_64$QWORD$$QWORD:
.Lc299:
# [1592] begin
	pushq	%rax
.Lc300:
# Var aObj located in register rdi
# [1595] Result := UInt64(atomic_increment_64(PInt64(@aObj)^));
	movl	$5,%edx
	movl	$1,%esi
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD_64$INT64$INT64$MEMORY_ORDER_T$$INT64
	addq	$1,%rax
# Var $result located in register rax
# [1597] end;
	popq	%rcx
.Lc301:
	ret
.Lc298:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_weak$pointer$pointer$pointer$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$POINTER$POINTER$POINTER$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$POINTER$POINTER$POINTER$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$POINTER$POINTER$POINTER$$BOOLEAN:
.Lc303:
# [1601] begin
	pushq	%rax
.Lc304:
# Var aObj located in register rdi
# Var aExpected located in register rsi
# Var aDesired located in register rdx
# [1602] Result := atomic_compare_exchange(aObj, aExpected, aDesired);
	movl	$5,%r8d
	movl	$5,%ecx
# Var aDesired located in register rdx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$hQsFemyUynKP
# Var $result located in register al
# [1603] end;
	popq	%rcx
.Lc305:
	ret
.Lc302:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_strong$ha3tejvtd1eo,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$ha3tEJVtd1eO
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$ha3tEJVtd1eO,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$ha3tEJVtd1eO:
.Lc307:
# [1613] begin
	pushq	%rbx
.Lc308:
# Var aObj located in register rdi
	movq	%rsi,%rbx
# Var aExpected located in register rbx
	movl	%edx,%esi
# Var aDesired located in register esi
# Var aSuccessOrder located in register ecx
# Var aFailureOrder located in register r8d
# [1631] LOld := InterlockedCompareExchange(aObj, aDesired, aExpected);
	movl	(%rbx),%edx
# Var aDesired located in register esi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE$LONGINT$LONGINT$LONGINT$$LONGINT
	movl	%eax,%edx
# Var LOld located in register edx
# [1632] Result := (LOld = aExpected);
	cmpl	(%rbx),%eax
# Var $result located in register al
	seteb	%al
# [1634] if Result then
	je	.Lj254
# [1650] aExpected := LOld;
	movl	%edx,(%rbx)
.Lj254:
# [1663] end;
	popq	%rbx
.Lc309:
	ret
.Lc306:
.Le3:
	.size	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$ha3tEJVtd1eO, .Le3 - NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$ha3tEJVtd1eO

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_strong$hf3egsouejop,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$hF3EgsouejOP
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$hF3EgsouejOP,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$hF3EgsouejOP:
.Lc311:
# [1667] begin
	pushq	%rbx
.Lc312:
	leaq	-16(%rsp),%rsp
.Lc313:
# Var aDesired located at rsp+0, size=OS_32
# Var aObj located in register rdi
	movq	%rsi,%rbx
# Var aExpected located in register rbx
	movl	%edx,(%rsp)
# Var aSuccessOrder located in register ecx
# Var aFailureOrder located in register r8d
# [1670] Result := atomic_compare_exchange_strong(PInt32(@aObj)^, PInt32(@aExpected)^, PInt32(@aDesired)^,
	movl	(%rsp),%esi
	movl	(%rbx),%edx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE$LONGINT$LONGINT$LONGINT$$LONGINT
	movl	%eax,%edx
	cmpl	(%rbx),%eax
	seteb	%al
	je	.Lj265
	movl	%edx,(%rbx)
.Lj265:
# Var $result located in register al
# [1673] end;
	leaq	16(%rsp),%rsp
	popq	%rbx
.Lc314:
	ret
.Lc310:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_strong$hgrw81d8bv5h,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$hGRw81D8Bv5H
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$hGRw81D8Bv5H,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$hGRw81D8Bv5H:
.Lc316:
# [1680] begin
	pushq	%rbx
.Lc317:
# Var aObj located in register rdi
	movq	%rsi,%rbx
# Var aExpected located in register rbx
	movq	%rdx,%rsi
# Var aDesired located in register rsi
# Var aSuccessOrder located in register ecx
# Var aFailureOrder located in register r8d
# [1697] LOld := InterlockedCompareExchange64(PInt64(@aObj)^, Int64(aDesired), Int64(aExpected));
	movq	(%rbx),%rdx
# Var aDesired located in register rsi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	movq	%rax,%rdx
# Var LOld located in register rdx
# [1698] Result := (LOld = Int64(aExpected));
	cmpq	(%rbx),%rax
# Var $result located in register al
	seteb	%al
# [1700] if Result then
	je	.Lj275
# [1715] aExpected := PtrInt(LOld);
	movq	%rdx,(%rbx)
.Lj275:
# [1727] end;
	popq	%rbx
.Lc318:
	ret
.Lc315:
.Le4:
	.size	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$hGRw81D8Bv5H, .Le4 - NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$hGRw81D8Bv5H

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_strong$hggn1avg799k,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$hGgN1AvG799K
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$hGgN1AvG799K,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$hGgN1AvG799K:
.Lc320:
# [1731] begin
	pushq	%rbx
.Lc321:
	leaq	-16(%rsp),%rsp
.Lc322:
# Var aDesired located at rsp+0, size=OS_64
# Var aObj located in register rdi
	movq	%rsi,%rbx
# Var aExpected located in register rbx
	movq	%rdx,(%rsp)
# Var aSuccessOrder located in register ecx
# Var aFailureOrder located in register r8d
# [1734] Result := atomic_compare_exchange_strong(PPtrInt(@aObj)^, PPtrInt(@aExpected)^, PPtrInt(@aDesired)^,
	movq	(%rsp),%rsi
	movq	(%rbx),%rdx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	movq	%rax,%rdx
	cmpq	(%rbx),%rax
	seteb	%al
	je	.Lj286
	movq	%rdx,(%rbx)
.Lj286:
# Var $result located in register al
# [1737] end;
	leaq	16(%rsp),%rsp
	popq	%rbx
.Lc323:
	ret
.Lc319:
.Le5:
	.size	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$hGgN1AvG799K, .Le5 - NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$hGgN1AvG799K

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_strong_64$hgrw81d8bv5h,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG_64$hGRw81D8Bv5H
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG_64$hGRw81D8Bv5H,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG_64$hGRw81D8Bv5H:
.Lc325:
# [1747] begin
	pushq	%rbx
.Lc326:
# Var aObj located in register rdi
	movq	%rsi,%rbx
# Var aExpected located in register rbx
	movq	%rdx,%rsi
# Var aDesired located in register rsi
# Var aSuccessOrder located in register ecx
# Var aFailureOrder located in register r8d
# [1781] LOld := InterlockedCompareExchange64(aObj, aDesired, aExpected);
	movq	(%rbx),%rdx
# Var aDesired located in register rsi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	movq	%rax,%rdx
# Var LOld located in register rdx
# [1782] Result := (LOld = aExpected);
	cmpq	(%rbx),%rax
# Var $result located in register al
	seteb	%al
# [1784] if not Result then
	je	.Lj287
# [1786] aExpected := LOld;
	movq	%rdx,(%rbx)
	.p2align 4,,10
	.p2align 3
.Lj287:
# [1811] end;
	popq	%rbx
.Lc327:
	ret
.Lc324:
.Le6:
	.size	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG_64$hGRw81D8Bv5H, .Le6 - NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG_64$hGRw81D8Bv5H

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_strong_64$hggn1avg799k,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG_64$hGgN1AvG799K
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG_64$hGgN1AvG799K,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG_64$hGgN1AvG799K:
.Lc329:
# [1815] begin
	pushq	%rbx
.Lc330:
	leaq	-16(%rsp),%rsp
.Lc331:
# Var aDesired located at rsp+0, size=OS_64
# Var aObj located in register rdi
	movq	%rsi,%rbx
# Var aExpected located in register rbx
	movq	%rdx,(%rsp)
# Var aSuccessOrder located in register ecx
# Var aFailureOrder located in register r8d
# [1818] Result := atomic_compare_exchange_strong_64(PInt64(@aObj)^, PInt64(@aExpected)^, PInt64(@aDesired)^,
	movq	(%rsp),%rsi
	movq	(%rbx),%rdx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	movq	%rax,%rdx
	cmpq	(%rbx),%rax
	seteb	%al
	je	.Lj298
	movq	%rdx,(%rbx)
	.p2align 4,,10
	.p2align 3
.Lj298:
# Var $result located in register al
# [1821] end;
	leaq	16(%rsp),%rsp
	popq	%rbx
.Lc332:
	ret
.Lc328:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_strong$hqsfemyuynkp,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$hQsFemyUynKP
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$hQsFemyUynKP,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$hQsFemyUynKP:
.Lc334:
# [1826] begin
	pushq	%rbx
.Lc335:
	leaq	-16(%rsp),%rsp
.Lc336:
# Var aDesired located at rsp+0, size=OS_64
# Var aObj located in register rdi
	movq	%rsi,%rbx
# Var aExpected located in register rbx
	movq	%rdx,(%rsp)
# Var aSuccessOrder located in register ecx
# Var aFailureOrder located in register r8d
# [1833] Result := atomic_compare_exchange_strong_64(PInt64(@aObj)^, PInt64(@aExpected)^, PInt64(@aDesired)^,
	movq	(%rsp),%rsi
	movq	(%rbx),%rdx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	movq	%rax,%rdx
	cmpq	(%rbx),%rax
	seteb	%al
	je	.Lj308
	movq	%rdx,(%rbx)
	.p2align 4,,10
	.p2align 3
.Lj308:
# Var $result located in register al
# [1837] end;
	leaq	16(%rsp),%rsp
	popq	%rbx
.Lc337:
	ret
.Lc333:
.Le7:
	.size	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$hQsFemyUynKP, .Le7 - NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$hQsFemyUynKP

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_weak$ha3tejvtd1eo,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$ha3tEJVtd1eO
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$ha3tEJVtd1eO,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$ha3tEJVtd1eO:
.Lc339:
# [1842] begin
	pushq	%rbx
.Lc340:
# Var aObj located in register rdi
	movq	%rsi,%rbx
# Var aExpected located in register rbx
	movl	%edx,%esi
# Var aDesired located in register esi
# Var aSuccessOrder located in register ecx
# Var aFailureOrder located in register r8d
# [1843] Result := atomic_compare_exchange_strong(aObj, aExpected, aDesired, aSuccessOrder, aFailureOrder);
	movl	(%rbx),%edx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE$LONGINT$LONGINT$LONGINT$$LONGINT
	movl	%eax,%edx
	cmpl	(%rbx),%eax
	seteb	%al
	je	.Lj326
	movl	%edx,(%rbx)
.Lj326:
# Var $result located in register al
# [1844] end;
	popq	%rbx
.Lc341:
	ret
.Lc338:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_weak$hf3egsouejop,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$hF3EgsouejOP
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$hF3EgsouejOP,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$hF3EgsouejOP:
.Lc343:
# Temps allocated between rsp+0 and rsp+4
# [1848] begin
	pushq	%rbx
.Lc344:
	leaq	-16(%rsp),%rsp
.Lc345:
# Var aObj located in register rdi
	movq	%rsi,%rbx
# Var aExpected located in register rbx
# Var aDesired located in register edx
# Var aSuccessOrder located in register ecx
# Var aFailureOrder located in register r8d
# [1849] Result := atomic_compare_exchange_strong(aObj, aExpected, aDesired, aSuccessOrder, aFailureOrder);
	movl	%edx,(%rsp)
	movl	(%rsp),%esi
	movl	(%rbx),%edx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE$LONGINT$LONGINT$LONGINT$$LONGINT
	movl	%eax,%edx
	cmpl	(%rbx),%eax
	seteb	%al
	je	.Lj337
	movl	%edx,(%rbx)
.Lj337:
# Var $result located in register al
# [1850] end;
	leaq	16(%rsp),%rsp
	popq	%rbx
.Lc346:
	ret
.Lc342:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_weak$hgrw81d8bv5h,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$hGRw81D8Bv5H
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$hGRw81D8Bv5H,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$hGRw81D8Bv5H:
.Lc348:
# [1855] begin
	pushq	%rbx
.Lc349:
# Var aObj located in register rdi
	movq	%rsi,%rbx
# Var aExpected located in register rbx
	movq	%rdx,%rsi
# Var aDesired located in register rsi
# Var aSuccessOrder located in register ecx
# Var aFailureOrder located in register r8d
# [1856] Result := atomic_compare_exchange_strong(aObj, aExpected, aDesired, aSuccessOrder, aFailureOrder);
	movq	(%rbx),%rdx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	movq	%rax,%rdx
	cmpq	(%rbx),%rax
	seteb	%al
	je	.Lj348
	movq	%rdx,(%rbx)
.Lj348:
# Var $result located in register al
# [1857] end;
	popq	%rbx
.Lc350:
	ret
.Lc347:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_weak$hggn1avg799k,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$hGgN1AvG799K
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$hGgN1AvG799K,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$hGgN1AvG799K:
.Lc352:
# Temps allocated between rsp+0 and rsp+8
# [1861] begin
	pushq	%rbx
.Lc353:
	leaq	-16(%rsp),%rsp
.Lc354:
# Var aObj located in register rdi
	movq	%rsi,%rbx
# Var aExpected located in register rbx
# Var aDesired located in register rdx
# Var aSuccessOrder located in register ecx
# Var aFailureOrder located in register r8d
# [1862] Result := atomic_compare_exchange_strong(aObj, aExpected, aDesired, aSuccessOrder, aFailureOrder);
	movq	%rdx,(%rsp)
	movq	(%rsp),%rsi
	movq	(%rbx),%rdx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	movq	%rax,%rdx
	cmpq	(%rbx),%rax
	seteb	%al
	je	.Lj359
	movq	%rdx,(%rbx)
.Lj359:
# Var $result located in register al
# [1863] end;
	leaq	16(%rsp),%rsp
	popq	%rbx
.Lc355:
	ret
.Lc351:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_weak_64$hgrw81d8bv5h,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK_64$hGRw81D8Bv5H
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK_64$hGRw81D8Bv5H,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK_64$hGRw81D8Bv5H:
.Lc357:
# [1869] begin
	pushq	%rbx
.Lc358:
# Var aObj located in register rdi
	movq	%rsi,%rbx
# Var aExpected located in register rbx
	movq	%rdx,%rsi
# Var aDesired located in register rsi
# Var aSuccessOrder located in register ecx
# Var aFailureOrder located in register r8d
# [1870] Result := atomic_compare_exchange_strong_64(aObj, aExpected, aDesired, aSuccessOrder, aFailureOrder);
	movq	(%rbx),%rdx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	movq	%rax,%rdx
	cmpq	(%rbx),%rax
	seteb	%al
	je	.Lj362
	movq	%rdx,(%rbx)
	.p2align 4,,10
	.p2align 3
.Lj362:
# Var $result located in register al
# [1871] end;
	popq	%rbx
.Lc359:
	ret
.Lc356:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_weak_64$hggn1avg799k,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK_64$hGgN1AvG799K
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK_64$hGgN1AvG799K,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK_64$hGgN1AvG799K:
.Lc361:
# Temps allocated between rsp+0 and rsp+8
# [1875] begin
	pushq	%rbx
.Lc362:
	leaq	-16(%rsp),%rsp
.Lc363:
# Var aObj located in register rdi
	movq	%rsi,%rbx
# Var aExpected located in register rbx
# Var aDesired located in register rdx
# Var aSuccessOrder located in register ecx
# Var aFailureOrder located in register r8d
# [1876] Result := atomic_compare_exchange_strong_64(aObj, aExpected, aDesired, aSuccessOrder, aFailureOrder);
	movq	%rdx,(%rsp)
	movq	(%rsp),%rsi
	movq	(%rbx),%rdx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	movq	%rax,%rdx
	cmpq	(%rbx),%rax
	seteb	%al
	je	.Lj372
	movq	%rdx,(%rbx)
	.p2align 4,,10
	.p2align 3
.Lj372:
# Var $result located in register al
# [1877] end;
	leaq	16(%rsp),%rsp
	popq	%rbx
.Lc364:
	ret
.Lc360:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_weak$hqsfemyuynkp,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$hQsFemyUynKP
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$hQsFemyUynKP,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$hQsFemyUynKP:
.Lc366:
# Temps allocated between rsp+0 and rsp+8
# [1882] begin
	pushq	%rbx
.Lc367:
	leaq	-16(%rsp),%rsp
.Lc368:
# Var aObj located in register rdi
	movq	%rsi,%rbx
# Var aExpected located in register rbx
# Var aDesired located in register rdx
# Var aSuccessOrder located in register ecx
# Var aFailureOrder located in register r8d
# [1883] Result := atomic_compare_exchange_strong(aObj, aExpected, aDesired, aSuccessOrder, aFailureOrder);
	movq	%rdx,(%rsp)
	movq	(%rsp),%rsi
	movq	(%rbx),%rdx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	movq	%rax,%rdx
	cmpq	(%rbx),%rax
	seteb	%al
	je	.Lj382
	movq	%rdx,(%rbx)
	.p2align 4,,10
	.p2align 3
.Lj382:
# Var $result located in register al
# [1884] end;
	leaq	16(%rsp),%rsp
	popq	%rbx
.Lc369:
	ret
.Lc365:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_strong$hdazw3ys85vi,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$hDAZW3YS85VI
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$hDAZW3YS85VI,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$hDAZW3YS85VI:
.Lc371:
# [1891] begin
	pushq	%rbx
.Lc372:
# Var aObj located in register rdi
	movq	%rsi,%rbx
# Var aExpected located in register rbx
	movl	%edx,%esi
# Var aDesired located in register esi
# Var aOrder located in register ecx
# [1892] Result := atomic_compare_exchange_strong(aObj, aExpected, aDesired, aOrder, aOrder);
	movl	(%rbx),%edx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE$LONGINT$LONGINT$LONGINT$$LONGINT
	movl	%eax,%edx
	cmpl	(%rbx),%eax
	seteb	%al
	je	.Lj400
	movl	%edx,(%rbx)
.Lj400:
# Var $result located in register al
# [1893] end;
	popq	%rbx
.Lc373:
	ret
.Lc370:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_strong$huc3ps_2bxhk,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$hUC3PS_2bxHK
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$hUC3PS_2bxHK,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$hUC3PS_2bxHK:
.Lc375:
# Temps allocated between rsp+0 and rsp+4
# [1897] begin
	pushq	%rbx
.Lc376:
	leaq	-16(%rsp),%rsp
.Lc377:
# Var aObj located in register rdi
	movq	%rsi,%rbx
# Var aExpected located in register rbx
# Var aDesired located in register edx
# Var aOrder located in register ecx
# [1898] Result := atomic_compare_exchange_strong(aObj, aExpected, aDesired, aOrder, aOrder);
	movl	%edx,(%rsp)
	movl	(%rsp),%esi
	movl	(%rbx),%edx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE$LONGINT$LONGINT$LONGINT$$LONGINT
	movl	%eax,%edx
	cmpl	(%rbx),%eax
	seteb	%al
	je	.Lj411
	movl	%edx,(%rbx)
.Lj411:
# Var $result located in register al
# [1899] end;
	leaq	16(%rsp),%rsp
	popq	%rbx
.Lc378:
	ret
.Lc374:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_strong$int64$int64$int64$memory_order_t$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$INT64$INT64$INT64$MEMORY_ORDER_T$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$INT64$INT64$INT64$MEMORY_ORDER_T$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$INT64$INT64$INT64$MEMORY_ORDER_T$$BOOLEAN:
.Lc380:
# [1904] begin
	pushq	%rbx
.Lc381:
# Var aObj located in register rdi
	movq	%rsi,%rbx
# Var aExpected located in register rbx
	movq	%rdx,%rsi
# Var aDesired located in register rsi
# Var aOrder located in register ecx
# [1905] Result := atomic_compare_exchange_strong(aObj, aExpected, aDesired, aOrder, aOrder);
	movq	(%rbx),%rdx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	movq	%rax,%rdx
	cmpq	(%rbx),%rax
	seteb	%al
	je	.Lj422
	movq	%rdx,(%rbx)
.Lj422:
# Var $result located in register al
# [1906] end;
	popq	%rbx
.Lc382:
	ret
.Lc379:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_strong$qword$qword$qword$memory_order_t$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$QWORD$QWORD$QWORD$MEMORY_ORDER_T$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$QWORD$QWORD$QWORD$MEMORY_ORDER_T$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$QWORD$QWORD$QWORD$MEMORY_ORDER_T$$BOOLEAN:
.Lc384:
# Temps allocated between rsp+0 and rsp+8
# [1910] begin
	pushq	%rbx
.Lc385:
	leaq	-16(%rsp),%rsp
.Lc386:
# Var aObj located in register rdi
	movq	%rsi,%rbx
# Var aExpected located in register rbx
# Var aDesired located in register rdx
# Var aOrder located in register ecx
# [1911] Result := atomic_compare_exchange_strong(aObj, aExpected, aDesired, aOrder, aOrder);
	movq	%rdx,(%rsp)
	movq	(%rsp),%rsi
	movq	(%rbx),%rdx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	movq	%rax,%rdx
	cmpq	(%rbx),%rax
	seteb	%al
	je	.Lj433
	movq	%rdx,(%rbx)
.Lj433:
# Var $result located in register al
# [1912] end;
	leaq	16(%rsp),%rsp
	popq	%rbx
.Lc387:
	ret
.Lc383:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_strong_64$int64$int64$int64$memory_order_t$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG_64$INT64$INT64$INT64$MEMORY_ORDER_T$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG_64$INT64$INT64$INT64$MEMORY_ORDER_T$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG_64$INT64$INT64$INT64$MEMORY_ORDER_T$$BOOLEAN:
.Lc389:
# [1918] begin
	pushq	%rbx
.Lc390:
# Var aObj located in register rdi
	movq	%rsi,%rbx
# Var aExpected located in register rbx
	movq	%rdx,%rsi
# Var aDesired located in register rsi
# Var aOrder located in register ecx
# [1919] Result := atomic_compare_exchange_strong_64(aObj, aExpected, aDesired, aOrder, aOrder);
	movq	(%rbx),%rdx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	movq	%rax,%rdx
	cmpq	(%rbx),%rax
	seteb	%al
	je	.Lj436
	movq	%rdx,(%rbx)
	.p2align 4,,10
	.p2align 3
.Lj436:
# Var $result located in register al
# [1920] end;
	popq	%rbx
.Lc391:
	ret
.Lc388:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_strong_64$qword$qword$qword$memory_order_t$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG_64$QWORD$QWORD$QWORD$MEMORY_ORDER_T$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG_64$QWORD$QWORD$QWORD$MEMORY_ORDER_T$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG_64$QWORD$QWORD$QWORD$MEMORY_ORDER_T$$BOOLEAN:
.Lc393:
# Temps allocated between rsp+0 and rsp+8
# [1924] begin
	pushq	%rbx
.Lc394:
	leaq	-16(%rsp),%rsp
.Lc395:
# Var aObj located in register rdi
	movq	%rsi,%rbx
# Var aExpected located in register rbx
# Var aDesired located in register rdx
# Var aOrder located in register ecx
# [1925] Result := atomic_compare_exchange_strong_64(aObj, aExpected, aDesired, aOrder, aOrder);
	movq	%rdx,(%rsp)
	movq	(%rsp),%rsi
	movq	(%rbx),%rdx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	movq	%rax,%rdx
	cmpq	(%rbx),%rax
	seteb	%al
	je	.Lj446
	movq	%rdx,(%rbx)
	.p2align 4,,10
	.p2align 3
.Lj446:
# Var $result located in register al
# [1926] end;
	leaq	16(%rsp),%rsp
	popq	%rbx
.Lc396:
	ret
.Lc392:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_strong$hlr6wrmhdneb,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$hlR6WRmhdneB
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$hlR6WRmhdneB,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_STRONG$hlR6WRmhdneB:
.Lc398:
# Temps allocated between rsp+0 and rsp+8
# [1931] begin
	pushq	%rbx
.Lc399:
	leaq	-16(%rsp),%rsp
.Lc400:
# Var aObj located in register rdi
	movq	%rsi,%rbx
# Var aExpected located in register rbx
# Var aDesired located in register rdx
# Var aOrder located in register ecx
# [1932] Result := atomic_compare_exchange_strong(aObj, aExpected, aDesired, aOrder, aOrder);
	movq	%rdx,(%rsp)
	movq	(%rsp),%rsi
	movq	(%rbx),%rdx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	movq	%rax,%rdx
	cmpq	(%rbx),%rax
	seteb	%al
	je	.Lj456
	movq	%rdx,(%rbx)
	.p2align 4,,10
	.p2align 3
.Lj456:
# Var $result located in register al
# [1933] end;
	leaq	16(%rsp),%rsp
	popq	%rbx
.Lc401:
	ret
.Lc397:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_weak$longint$longint$longint$memory_order_t$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$LONGINT$LONGINT$LONGINT$MEMORY_ORDER_T$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$LONGINT$LONGINT$LONGINT$MEMORY_ORDER_T$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$LONGINT$LONGINT$LONGINT$MEMORY_ORDER_T$$BOOLEAN:
.Lc403:
# [1938] begin
	pushq	%rbx
.Lc404:
# Var aObj located in register rdi
	movq	%rsi,%rbx
# Var aExpected located in register rbx
	movl	%edx,%esi
# Var aDesired located in register esi
# Var aOrder located in register ecx
# [1939] Result := atomic_compare_exchange_weak(aObj, aExpected, aDesired, aOrder, aOrder);
	movl	(%rbx),%edx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE$LONGINT$LONGINT$LONGINT$$LONGINT
	movl	%eax,%edx
	cmpl	(%rbx),%eax
	seteb	%al
	je	.Lj474
	movl	%edx,(%rbx)
.Lj474:
# Var $result located in register al
# [1940] end;
	popq	%rbx
.Lc405:
	ret
.Lc402:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_weak$huc3ps_2bxhk,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$hUC3PS_2bxHK
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$hUC3PS_2bxHK,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$hUC3PS_2bxHK:
.Lc407:
# Temps allocated between rsp+0 and rsp+4
# [1944] begin
	pushq	%rbx
.Lc408:
	leaq	-16(%rsp),%rsp
.Lc409:
# Var aObj located in register rdi
	movq	%rsi,%rbx
# Var aExpected located in register rbx
# Var aDesired located in register edx
# Var aOrder located in register ecx
# [1945] Result := atomic_compare_exchange_weak(aObj, aExpected, aDesired, aOrder, aOrder);
	movl	%edx,(%rsp)
	movl	(%rsp),%esi
	movl	(%rbx),%edx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE$LONGINT$LONGINT$LONGINT$$LONGINT
	movl	%eax,%edx
	cmpl	(%rbx),%eax
	seteb	%al
	je	.Lj485
	movl	%edx,(%rbx)
.Lj485:
# Var $result located in register al
# [1946] end;
	leaq	16(%rsp),%rsp
	popq	%rbx
.Lc410:
	ret
.Lc406:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_weak$int64$int64$int64$memory_order_t$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$INT64$INT64$INT64$MEMORY_ORDER_T$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$INT64$INT64$INT64$MEMORY_ORDER_T$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$INT64$INT64$INT64$MEMORY_ORDER_T$$BOOLEAN:
.Lc412:
# [1951] begin
	pushq	%rbx
.Lc413:
# Var aObj located in register rdi
	movq	%rsi,%rbx
# Var aExpected located in register rbx
	movq	%rdx,%rsi
# Var aDesired located in register rsi
# Var aOrder located in register ecx
# [1952] Result := atomic_compare_exchange_weak(aObj, aExpected, aDesired, aOrder, aOrder);
	movq	(%rbx),%rdx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	movq	%rax,%rdx
	cmpq	(%rbx),%rax
	seteb	%al
	je	.Lj496
	movq	%rdx,(%rbx)
.Lj496:
# Var $result located in register al
# [1953] end;
	popq	%rbx
.Lc414:
	ret
.Lc411:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_weak$qword$qword$qword$memory_order_t$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$QWORD$QWORD$QWORD$MEMORY_ORDER_T$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$QWORD$QWORD$QWORD$MEMORY_ORDER_T$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$QWORD$QWORD$QWORD$MEMORY_ORDER_T$$BOOLEAN:
.Lc416:
# Temps allocated between rsp+0 and rsp+8
# [1957] begin
	pushq	%rbx
.Lc417:
	leaq	-16(%rsp),%rsp
.Lc418:
# Var aObj located in register rdi
	movq	%rsi,%rbx
# Var aExpected located in register rbx
# Var aDesired located in register rdx
# Var aOrder located in register ecx
# [1958] Result := atomic_compare_exchange_weak(aObj, aExpected, aDesired, aOrder, aOrder);
	movq	%rdx,(%rsp)
	movq	(%rsp),%rsi
	movq	(%rbx),%rdx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	movq	%rax,%rdx
	cmpq	(%rbx),%rax
	seteb	%al
	je	.Lj507
	movq	%rdx,(%rbx)
.Lj507:
# Var $result located in register al
# [1959] end;
	leaq	16(%rsp),%rsp
	popq	%rbx
.Lc419:
	ret
.Lc415:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_weak_64$int64$int64$int64$memory_order_t$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK_64$INT64$INT64$INT64$MEMORY_ORDER_T$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK_64$INT64$INT64$INT64$MEMORY_ORDER_T$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK_64$INT64$INT64$INT64$MEMORY_ORDER_T$$BOOLEAN:
.Lc421:
# [1965] begin
	pushq	%rbx
.Lc422:
# Var aObj located in register rdi
	movq	%rsi,%rbx
# Var aExpected located in register rbx
	movq	%rdx,%rsi
# Var aDesired located in register rsi
# Var aOrder located in register ecx
# [1966] Result := atomic_compare_exchange_weak_64(aObj, aExpected, aDesired, aOrder, aOrder);
	movq	(%rbx),%rdx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	movq	%rax,%rdx
	cmpq	(%rbx),%rax
	seteb	%al
	je	.Lj510
	movq	%rdx,(%rbx)
	.p2align 4,,10
	.p2align 3
.Lj510:
# Var $result located in register al
# [1967] end;
	popq	%rbx
.Lc423:
	ret
.Lc420:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_weak_64$qword$qword$qword$memory_order_t$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK_64$QWORD$QWORD$QWORD$MEMORY_ORDER_T$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK_64$QWORD$QWORD$QWORD$MEMORY_ORDER_T$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK_64$QWORD$QWORD$QWORD$MEMORY_ORDER_T$$BOOLEAN:
.Lc425:
# Temps allocated between rsp+0 and rsp+8
# [1971] begin
	pushq	%rbx
.Lc426:
	leaq	-16(%rsp),%rsp
.Lc427:
# Var aObj located in register rdi
	movq	%rsi,%rbx
# Var aExpected located in register rbx
# Var aDesired located in register rdx
# Var aOrder located in register ecx
# [1972] Result := atomic_compare_exchange_weak_64(aObj, aExpected, aDesired, aOrder, aOrder);
	movq	%rdx,(%rsp)
	movq	(%rsp),%rsi
	movq	(%rbx),%rdx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	movq	%rax,%rdx
	cmpq	(%rbx),%rax
	seteb	%al
	je	.Lj520
	movq	%rdx,(%rbx)
	.p2align 4,,10
	.p2align 3
.Lj520:
# Var $result located in register al
# [1973] end;
	leaq	16(%rsp),%rsp
	popq	%rbx
.Lc428:
	ret
.Lc424:

.section .text.n_nextpas.core.atomic_$$_atomic_compare_exchange_weak$pointer$pointer$pointer$memory_order_t$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$POINTER$POINTER$POINTER$MEMORY_ORDER_T$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$POINTER$POINTER$POINTER$MEMORY_ORDER_T$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_COMPARE_EXCHANGE_WEAK$POINTER$POINTER$POINTER$MEMORY_ORDER_T$$BOOLEAN:
.Lc430:
# Temps allocated between rsp+0 and rsp+8
# [1978] begin
	pushq	%rbx
.Lc431:
	leaq	-16(%rsp),%rsp
.Lc432:
# Var aObj located in register rdi
	movq	%rsi,%rbx
# Var aExpected located in register rbx
# Var aDesired located in register rdx
# Var aOrder located in register ecx
# [1979] Result := atomic_compare_exchange_weak(aObj, aExpected, aDesired, aOrder, aOrder);
	movq	%rdx,(%rsp)
	movq	(%rsp),%rsi
	movq	(%rbx),%rdx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	movq	%rax,%rdx
	cmpq	(%rbx),%rax
	seteb	%al
	je	.Lj530
	movq	%rdx,(%rbx)
	.p2align 4,,10
	.p2align 3
.Lj530:
# Var $result located in register al
# [1980] end;
	leaq	16(%rsp),%rsp
	popq	%rbx
.Lc433:
	ret
.Lc429:

.section .text.n_nextpas.core.atomic_$$_atomic_increment$longint$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_INCREMENT$LONGINT$$LONGINT
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_INCREMENT$LONGINT$$LONGINT,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_INCREMENT$LONGINT$$LONGINT:
.Lc435:
# [1983] begin
	pushq	%rax
.Lc436:
# Var aObj located in register rdi
# [1985] Result := atomic_fetch_add(aObj, 1, mo_seq_cst) + 1;
	movl	$5,%edx
	movl	$1,%esi
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT
	addl	$1,%eax
# Var $result located in register eax
# [1986] end;
	popq	%rcx
.Lc437:
	ret
.Lc434:

.section .text.n_nextpas.core.atomic_$$_atomic_increment$longword$$longword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_INCREMENT$LONGWORD$$LONGWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_INCREMENT$LONGWORD$$LONGWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_INCREMENT$LONGWORD$$LONGWORD:
.Lc439:
# [1989] begin
	pushq	%rax
.Lc440:
# Var aObj located in register rdi
# [1992] Result := UInt32(atomic_increment(PInt32(@aObj)^));
	movl	$5,%edx
	movl	$1,%esi
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT
	addl	$1,%eax
# Var $result located in register eax
# [1994] end;
	popq	%rcx
.Lc441:
	ret
.Lc438:

.section .text.n_nextpas.core.atomic_$$_atomic_increment$int64$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_INCREMENT$INT64$$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_INCREMENT$INT64$$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_INCREMENT$INT64$$INT64:
.Lc443:
# [1998] begin
	pushq	%rax
.Lc444:
# Var aObj located in register rdi
# [2004] Result := PtrInt(atomic_increment_64(PInt64(@aObj)^));
	movl	$5,%edx
	movl	$1,%esi
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD_64$INT64$INT64$MEMORY_ORDER_T$$INT64
	addq	$1,%rax
# Var $result located in register rax
# [2007] end;
	popq	%rcx
.Lc445:
	ret
.Lc442:

.section .text.n_nextpas.core.atomic_$$_atomic_increment$qword$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_INCREMENT$QWORD$$QWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_INCREMENT$QWORD$$QWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_INCREMENT$QWORD$$QWORD:
.Lc447:
# [2010] begin
	pushq	%rax
.Lc448:
# Var aObj located in register rdi
# [2016] Result := PtrUInt(atomic_increment_64(PInt64(@aObj)^));
	movl	$5,%edx
	movl	$1,%esi
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD_64$INT64$INT64$MEMORY_ORDER_T$$INT64
	addq	$1,%rax
# Var $result located in register rax
# [2019] end;
	popq	%rcx
.Lc449:
	ret
.Lc446:

.section .text.n_nextpas.core.atomic_$$_atomic_decrement_64$int64$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_DECREMENT_64$INT64$$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_DECREMENT_64$INT64$$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_DECREMENT_64$INT64$$INT64:
.Lc451:
# [2024] begin
	pushq	%rax
.Lc452:
# Var aObj located in register rdi
# [2026] Result := atomic_fetch_add_64(aObj, -1, mo_seq_cst) - 1;
	movl	$5,%edx
	movq	$-1,%rsi
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD_64$INT64$INT64$MEMORY_ORDER_T$$INT64
	subq	$1,%rax
# Var $result located in register rax
# [2027] end;
	popq	%rcx
.Lc453:
	ret
.Lc450:

.section .text.n_nextpas.core.atomic_$$_atomic_decrement_64$qword$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_DECREMENT_64$QWORD$$QWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_DECREMENT_64$QWORD$$QWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_DECREMENT_64$QWORD$$QWORD:
.Lc455:
# [2030] begin
	pushq	%rax
.Lc456:
# Var aObj located in register rdi
# [2033] Result := UInt64(atomic_decrement_64(PInt64(@aObj)^));
	movl	$5,%edx
	movq	$-1,%rsi
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD_64$INT64$INT64$MEMORY_ORDER_T$$INT64
	subq	$1,%rax
# Var $result located in register rax
# [2035] end;
	popq	%rcx
.Lc457:
	ret
.Lc454:

.section .text.n_nextpas.core.atomic_$$_atomic_decrement$longint$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_DECREMENT$LONGINT$$LONGINT
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_DECREMENT$LONGINT$$LONGINT,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_DECREMENT$LONGINT$$LONGINT:
.Lc459:
# [2039] begin
	pushq	%rax
.Lc460:
# Var aObj located in register rdi
# [2041] Result := atomic_fetch_add(aObj, -1, mo_seq_cst) - 1;
	movl	$5,%edx
	movl	$-1,%esi
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT
	subl	$1,%eax
# Var $result located in register eax
# [2042] end;
	popq	%rcx
.Lc461:
	ret
.Lc458:

.section .text.n_nextpas.core.atomic_$$_atomic_decrement$longword$$longword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_DECREMENT$LONGWORD$$LONGWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_DECREMENT$LONGWORD$$LONGWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_DECREMENT$LONGWORD$$LONGWORD:
.Lc463:
# [2045] begin
	pushq	%rax
.Lc464:
# Var aObj located in register rdi
# [2048] Result := UInt32(atomic_decrement(PInt32(@aObj)^));
	movl	$5,%edx
	movl	$-1,%esi
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT
	subl	$1,%eax
# Var $result located in register eax
# [2050] end;
	popq	%rcx
.Lc465:
	ret
.Lc462:

.section .text.n_nextpas.core.atomic_$$_atomic_decrement$int64$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_DECREMENT$INT64$$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_DECREMENT$INT64$$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_DECREMENT$INT64$$INT64:
.Lc467:
# [2054] begin
	pushq	%rax
.Lc468:
# Var aObj located in register rdi
# [2060] Result := PtrInt(atomic_decrement_64(PInt64(@aObj)^));
	movl	$5,%edx
	movq	$-1,%rsi
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD_64$INT64$INT64$MEMORY_ORDER_T$$INT64
	subq	$1,%rax
# Var $result located in register rax
# [2063] end;
	popq	%rcx
.Lc469:
	ret
.Lc466:

.section .text.n_nextpas.core.atomic_$$_atomic_decrement$qword$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_DECREMENT$QWORD$$QWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_DECREMENT$QWORD$$QWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_DECREMENT$QWORD$$QWORD:
.Lc471:
# [2066] begin
	pushq	%rax
.Lc472:
# Var aObj located in register rdi
# [2069] Result := PtrUInt(atomic_decrement(PPtrInt(@aObj)^));
	movl	$5,%edx
	movq	$-1,%rsi
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD_64$INT64$INT64$MEMORY_ORDER_T$$INT64
	subq	$1,%rax
# Var $result located in register rax
# [2071] end;
	popq	%rcx
.Lc473:
	ret
.Lc470:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_add_64$int64$int64$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD_64$INT64$INT64$$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD_64$INT64$INT64$$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD_64$INT64$INT64$$INT64:
.Lc475:
# [2076] begin
	pushq	%rax
.Lc476:
# Var aObj located in register rdi
# Var aArg located in register rsi
# [2078] Result := atomic_fetch_add_64(aObj, aArg, mo_seq_cst);
	movl	$5,%edx
# Var aArg located in register rsi
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD_64$INT64$INT64$MEMORY_ORDER_T$$INT64
# Var $result located in register rax
# [2079] end;
	popq	%rcx
.Lc477:
	ret
.Lc474:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_add_64$qword$qword$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD_64$QWORD$QWORD$$QWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD_64$QWORD$QWORD$$QWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD_64$QWORD$QWORD$$QWORD:
.Lc479:
# [2082] begin
	pushq	%rax
.Lc480:
# Var aArg located at rsp+0, size=OS_64
# Var aObj located in register rdi
	movq	%rsi,(%rsp)
# [2085] Result := UInt64(atomic_fetch_add_64(PInt64(@aObj)^, PInt64(@aArg)^, mo_seq_cst));
	movq	(%rsp),%rsi
	movl	$5,%edx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD_64$INT64$INT64$MEMORY_ORDER_T$$INT64
# Var $result located in register rax
# [2087] end;
	popq	%rcx
.Lc481:
	ret
.Lc478:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_add$longint$longint$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD$LONGINT$LONGINT$$LONGINT
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD$LONGINT$LONGINT$$LONGINT,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD$LONGINT$LONGINT$$LONGINT:
.Lc483:
# [2091] begin
	pushq	%rax
.Lc484:
# Var aObj located in register rdi
# Var aArg located in register esi
# [2093] Result := atomic_fetch_add(aObj, aArg, mo_seq_cst);
	movl	$5,%edx
# Var aArg located in register esi
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT
# Var $result located in register eax
# [2094] end;
	popq	%rcx
.Lc485:
	ret
.Lc482:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_add$longword$longword$$longword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD$LONGWORD$LONGWORD$$LONGWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD$LONGWORD$LONGWORD$$LONGWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD$LONGWORD$LONGWORD$$LONGWORD:
.Lc487:
# [2097] begin
	pushq	%rax
.Lc488:
# Var aArg located at rsp+0, size=OS_32
# Var aObj located in register rdi
	movl	%esi,(%rsp)
# [2100] Result := UInt32(atomic_fetch_add(PInt32(@aObj)^, PInt32(@aArg)^, mo_seq_cst));
	movl	(%rsp),%esi
	movl	$5,%edx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT
# Var $result located in register eax
# [2102] end;
	popq	%rcx
.Lc489:
	ret
.Lc486:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_add$int64$int64$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD$INT64$INT64$$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD$INT64$INT64$$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD$INT64$INT64$$INT64:
.Lc491:
# [2106] begin
	pushq	%rax
.Lc492:
# Var aArg located at rsp+0, size=OS_S64
# Var aObj located in register rdi
	movq	%rsi,(%rsp)
# [2110] Result := PtrInt(atomic_fetch_add_64(PInt64(@aObj)^, PInt64(@aArg)^, mo_seq_cst));
	movq	(%rsp),%rsi
	movl	$5,%edx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD_64$INT64$INT64$MEMORY_ORDER_T$$INT64
# Var $result located in register rax
# [2112] end;
	popq	%rcx
.Lc493:
	ret
.Lc490:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_add$qword$qword$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD$QWORD$QWORD$$QWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD$QWORD$QWORD$$QWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD$QWORD$QWORD$$QWORD:
.Lc495:
# [2115] begin
	pushq	%rax
.Lc496:
# Var aArg located at rsp+0, size=OS_64
# Var aObj located in register rdi
	movq	%rsi,(%rsp)
# [2118] Result := PtrUInt(atomic_fetch_add(PPtrInt(@aObj)^, PPtrInt(@aArg)^, mo_seq_cst));
	movq	(%rsp),%rsi
	movl	$5,%edx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD$INT64$INT64$MEMORY_ORDER_T$$INT64
# Var $result located in register rax
# [2120] end;
	popq	%rcx
.Lc497:
	ret
.Lc494:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_add$pointer$int64$$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD$POINTER$INT64$$POINTER
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD$POINTER$INT64$$POINTER,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD$POINTER$INT64$$POINTER:
.Lc499:
# [2124] begin
	pushq	%rax
.Lc500:
# Var aOffset located at rsp+0, size=OS_S64
# Var aObj located in register rdi
	movq	%rsi,(%rsp)
# [2130] Result := Pointer(atomic_fetch_add_64(PInt64(@aObj)^, PInt64(@aOffset)^));
	movq	(%rsp),%rsi
	movl	$5,%edx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD_64$INT64$INT64$MEMORY_ORDER_T$$INT64
# Var $result located in register rax
# [2133] end;
	popq	%rcx
.Lc501:
	ret
.Lc498:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_sub_64$int64$int64$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_SUB_64$INT64$INT64$$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_SUB_64$INT64$INT64$$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_SUB_64$INT64$INT64$$INT64:
.Lc503:
# [2137] begin
	pushq	%rax
.Lc504:
# Var aObj located in register rdi
# Var aArg located in register rsi
# [2138] Result := atomic_fetch_add_64(aObj, -aArg);
	negq	%rsi
	movl	$5,%edx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD_64$INT64$INT64$MEMORY_ORDER_T$$INT64
# Var $result located in register rax
# [2139] end;
	popq	%rcx
.Lc505:
	ret
.Lc502:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_sub_64$qword$qword$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_SUB_64$QWORD$QWORD$$QWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_SUB_64$QWORD$QWORD$$QWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_SUB_64$QWORD$QWORD$$QWORD:
.Lc507:
# [2142] begin
	pushq	%rax
.Lc508:
# Var aArg located at rsp+0, size=OS_64
# Var aObj located in register rdi
	movq	%rsi,(%rsp)
# [2143] Result := UInt64(atomic_fetch_sub_64(PInt64(@aObj)^, PInt64(@aArg)^));
	movq	(%rsp),%rsi
	negq	%rsi
	movl	$5,%edx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD_64$INT64$INT64$MEMORY_ORDER_T$$INT64
# Var $result located in register rax
# [2144] end;
	popq	%rcx
.Lc509:
	ret
.Lc506:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_sub$longint$longint$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_SUB$LONGINT$LONGINT$$LONGINT
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_SUB$LONGINT$LONGINT$$LONGINT,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_SUB$LONGINT$LONGINT$$LONGINT:
.Lc511:
# [2148] begin
	pushq	%rax
.Lc512:
# Var aObj located in register rdi
# Var aArg located in register esi
# [2149] Result := atomic_fetch_add(aObj, -aArg);
	negl	%esi
	movl	$5,%edx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT
# Var $result located in register eax
# [2150] end;
	popq	%rcx
.Lc513:
	ret
.Lc510:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_sub$longword$longword$$longword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_SUB$LONGWORD$LONGWORD$$LONGWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_SUB$LONGWORD$LONGWORD$$LONGWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_SUB$LONGWORD$LONGWORD$$LONGWORD:
.Lc515:
# [2153] begin
	pushq	%rax
.Lc516:
# Var aArg located at rsp+0, size=OS_32
# Var aObj located in register rdi
	movl	%esi,(%rsp)
# [2156] Result := UInt32(atomic_fetch_sub(PInt32(@aObj)^, PInt32(@aArg)^));
	movl	(%rsp),%esi
	negl	%esi
	movl	$5,%edx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT
# Var $result located in register eax
# [2158] end;
	popq	%rcx
.Lc517:
	ret
.Lc514:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_sub$int64$int64$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_SUB$INT64$INT64$$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_SUB$INT64$INT64$$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_SUB$INT64$INT64$$INT64:
.Lc519:
# [2162] begin
	pushq	%rax
.Lc520:
# Var aArg located at rsp+0, size=OS_S64
# Var aObj located in register rdi
	movq	%rsi,(%rsp)
# [2166] Result := PtrInt(atomic_fetch_sub_64(PInt64(@aObj)^, PInt64(@aArg)^));
	movq	(%rsp),%rsi
	negq	%rsi
	movl	$5,%edx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD_64$INT64$INT64$MEMORY_ORDER_T$$INT64
# Var $result located in register rax
# [2168] end;
	popq	%rcx
.Lc521:
	ret
.Lc518:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_sub$qword$qword$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_SUB$QWORD$QWORD$$QWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_SUB$QWORD$QWORD$$QWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_SUB$QWORD$QWORD$$QWORD:
.Lc523:
# Temps allocated between rsp+8 and rsp+16
# [2171] begin
	leaq	-24(%rsp),%rsp
.Lc524:
# Var aArg located at rsp+0, size=OS_64
# Var aObj located in register rdi
	movq	%rsi,(%rsp)
# [2174] Result := PtrUInt(atomic_fetch_sub(PPtrInt(@aObj)^, PPtrInt(@aArg)^));
	movq	(%rsp),%rsi
	movq	%rsi,8(%rsp)
	negq	%rsi
	movl	$5,%edx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD_64$INT64$INT64$MEMORY_ORDER_T$$INT64
# Var $result located in register rax
# [2176] end;
	leaq	24(%rsp),%rsp
.Lc525:
	ret
.Lc522:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_sub$pointer$int64$$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_SUB$POINTER$INT64$$POINTER
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_SUB$POINTER$INT64$$POINTER,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_SUB$POINTER$INT64$$POINTER:
.Lc527:
# Temps allocated between rsp+0 and rsp+8
# [2180] begin
	pushq	%rax
.Lc528:
# Var aObj located in register rdi
# Var aOffset located in register rsi
# [2181] Result := atomic_fetch_add(aObj, -aOffset);
	negq	%rsi
	movq	%rsi,(%rsp)
	movq	(%rsp),%rsi
	movl	$5,%edx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD_64$INT64$INT64$MEMORY_ORDER_T$$INT64
# Var $result located in register rax
# [2182] end;
	popq	%rcx
.Lc529:
	ret
.Lc526:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_and_64$int64$int64$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND_64$INT64$INT64$$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND_64$INT64$INT64$$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND_64$INT64$INT64$$INT64:
.Lc531:
# [2186] begin
	pushq	%rax
.Lc532:
# Var aObj located in register rdi
# Var aArg located in register rsi
# [2188] Result := atomic_fetch_and_64(aObj, aArg, mo_seq_cst);
	movl	$5,%edx
# Var aArg located in register rsi
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND_64$INT64$INT64$MEMORY_ORDER_T$$INT64
# Var $result located in register rax
# [2189] end;
	popq	%rcx
.Lc533:
	ret
.Lc530:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_and_64$qword$qword$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND_64$QWORD$QWORD$$QWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND_64$QWORD$QWORD$$QWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND_64$QWORD$QWORD$$QWORD:
.Lc535:
# [2192] begin
	pushq	%rax
.Lc536:
# Var aArg located at rsp+0, size=OS_64
# Var aObj located in register rdi
	movq	%rsi,(%rsp)
# [2195] Result := UInt64(atomic_fetch_and_64(PInt64(@aObj)^, PInt64(@aArg)^, mo_seq_cst));
	movq	(%rsp),%rsi
	movl	$5,%edx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND_64$INT64$INT64$MEMORY_ORDER_T$$INT64
# Var $result located in register rax
# [2197] end;
	popq	%rcx
.Lc537:
	ret
.Lc534:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_and$longint$longint$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND$LONGINT$LONGINT$$LONGINT
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND$LONGINT$LONGINT$$LONGINT,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND$LONGINT$LONGINT$$LONGINT:
.Lc539:
# [2201] begin
	pushq	%rax
.Lc540:
# Var aObj located in register rdi
# Var aArg located in register esi
# [2204] Result := atomic_fetch_and(aObj, aArg, mo_seq_cst);
	movl	$5,%edx
# Var aArg located in register esi
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT
# Var $result located in register eax
# [2205] end;
	popq	%rcx
.Lc541:
	ret
.Lc538:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_and$longword$longword$$longword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND$LONGWORD$LONGWORD$$LONGWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND$LONGWORD$LONGWORD$$LONGWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND$LONGWORD$LONGWORD$$LONGWORD:
.Lc543:
# [2208] begin
	pushq	%rax
.Lc544:
# Var aArg located at rsp+0, size=OS_32
# Var aObj located in register rdi
	movl	%esi,(%rsp)
# [2211] Result := UInt32(atomic_fetch_and(PInt32(@aObj)^, PInt32(@aArg)^));
	movl	(%rsp),%esi
	movl	$5,%edx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT
# Var $result located in register eax
# [2213] end;
	popq	%rcx
.Lc545:
	ret
.Lc542:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_and$int64$int64$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND$INT64$INT64$$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND$INT64$INT64$$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND$INT64$INT64$$INT64:
.Lc547:
# [2217] begin
	pushq	%rax
.Lc548:
# Var aArg located at rsp+0, size=OS_S64
# Var aObj located in register rdi
	movq	%rsi,(%rsp)
# [2221] Result := PtrInt(atomic_fetch_and_64(PInt64(@aObj)^, PInt64(@aArg)^));
	movq	(%rsp),%rsi
	movl	$5,%edx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND_64$INT64$INT64$MEMORY_ORDER_T$$INT64
# Var $result located in register rax
# [2223] end;
	popq	%rcx
.Lc549:
	ret
.Lc546:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_and$qword$qword$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND$QWORD$QWORD$$QWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND$QWORD$QWORD$$QWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND$QWORD$QWORD$$QWORD:
.Lc551:
# Temps allocated between rsp+0 and rsp+8
# [2226] begin
	pushq	%rax
.Lc552:
# Var aObj located in register rdi
# Var aArg located in register rsi
# Var aArg located in register rsi
# [2227] Result := PtrUInt(atomic_fetch_and(PPtrInt(@aObj)^, PtrInt(aArg)));
	movq	%rsi,(%rsp)
	movq	(%rsp),%rsi
	movl	$5,%edx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND_64$INT64$INT64$MEMORY_ORDER_T$$INT64
# Var $result located in register rax
# [2228] end;
	popq	%rcx
.Lc553:
	ret
.Lc550:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_or_64$int64$int64$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR_64$INT64$INT64$$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR_64$INT64$INT64$$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR_64$INT64$INT64$$INT64:
.Lc555:
# [2233] begin
	pushq	%rax
.Lc556:
# Var aObj located in register rdi
# Var aArg located in register rsi
# [2235] Result := atomic_fetch_or_64(aObj, aArg, mo_seq_cst);
	movl	$5,%edx
# Var aArg located in register rsi
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR_64$INT64$INT64$MEMORY_ORDER_T$$INT64
# Var $result located in register rax
# [2236] end;
	popq	%rcx
.Lc557:
	ret
.Lc554:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_or_64$qword$qword$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR_64$QWORD$QWORD$$QWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR_64$QWORD$QWORD$$QWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR_64$QWORD$QWORD$$QWORD:
.Lc559:
# [2239] begin
	pushq	%rax
.Lc560:
# Var aArg located at rsp+0, size=OS_64
# Var aObj located in register rdi
	movq	%rsi,(%rsp)
# [2242] Result := UInt64(atomic_fetch_or_64(PInt64(@aObj)^, PInt64(@aArg)^, mo_seq_cst));
	movq	(%rsp),%rsi
	movl	$5,%edx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR_64$INT64$INT64$MEMORY_ORDER_T$$INT64
# Var $result located in register rax
# [2244] end;
	popq	%rcx
.Lc561:
	ret
.Lc558:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_or$longint$longint$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR$LONGINT$LONGINT$$LONGINT
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR$LONGINT$LONGINT$$LONGINT,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR$LONGINT$LONGINT$$LONGINT:
.Lc563:
# [2248] begin
	pushq	%rax
.Lc564:
# Var aObj located in register rdi
# Var aArg located in register esi
# [2249] Result := atomic_fetch_or(aObj, aArg, mo_seq_cst);
	movl	$5,%edx
# Var aArg located in register esi
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT
# Var $result located in register eax
# [2250] end;
	popq	%rcx
.Lc565:
	ret
.Lc562:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_or$longword$longword$$longword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR$LONGWORD$LONGWORD$$LONGWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR$LONGWORD$LONGWORD$$LONGWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR$LONGWORD$LONGWORD$$LONGWORD:
.Lc567:
# [2253] begin
	pushq	%rax
.Lc568:
# Var aArg located at rsp+0, size=OS_32
# Var aObj located in register rdi
	movl	%esi,(%rsp)
# [2256] Result := UInt32(atomic_fetch_or(PInt32(@aObj)^, PInt32(@aArg)^));
	movl	(%rsp),%esi
	movl	$5,%edx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT
# Var $result located in register eax
# [2258] end;
	popq	%rcx
.Lc569:
	ret
.Lc566:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_or$int64$int64$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR$INT64$INT64$$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR$INT64$INT64$$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR$INT64$INT64$$INT64:
.Lc571:
# [2262] begin
	pushq	%rax
.Lc572:
# Var aArg located at rsp+0, size=OS_S64
# Var aObj located in register rdi
	movq	%rsi,(%rsp)
# [2266] Result := PtrInt(atomic_fetch_or_64(PInt64(@aObj)^, PInt64(@aArg)^));
	movq	(%rsp),%rsi
	movl	$5,%edx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR_64$INT64$INT64$MEMORY_ORDER_T$$INT64
# Var $result located in register rax
# [2268] end;
	popq	%rcx
.Lc573:
	ret
.Lc570:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_or$qword$qword$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR$QWORD$QWORD$$QWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR$QWORD$QWORD$$QWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR$QWORD$QWORD$$QWORD:
.Lc575:
# Temps allocated between rsp+0 and rsp+8
# [2271] begin
	pushq	%rax
.Lc576:
# Var aObj located in register rdi
# Var aArg located in register rsi
# Var aArg located in register rsi
# [2272] Result := PtrUInt(atomic_fetch_or(PPtrInt(@aObj)^, PtrInt(aArg)));
	movq	%rsi,(%rsp)
	movq	(%rsp),%rsi
	movl	$5,%edx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR_64$INT64$INT64$MEMORY_ORDER_T$$INT64
# Var $result located in register rax
# [2273] end;
	popq	%rcx
.Lc577:
	ret
.Lc574:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_xor_64$int64$int64$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR_64$INT64$INT64$$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR_64$INT64$INT64$$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR_64$INT64$INT64$$INT64:
.Lc579:
# [2278] begin
	pushq	%rax
.Lc580:
# Var aObj located in register rdi
# Var aArg located in register rsi
# [2280] Result := atomic_fetch_xor_64(aObj, aArg, mo_seq_cst);
	movl	$5,%edx
# Var aArg located in register rsi
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR_64$INT64$INT64$MEMORY_ORDER_T$$INT64
# Var $result located in register rax
# [2281] end;
	popq	%rcx
.Lc581:
	ret
.Lc578:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_xor_64$qword$qword$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR_64$QWORD$QWORD$$QWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR_64$QWORD$QWORD$$QWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR_64$QWORD$QWORD$$QWORD:
.Lc583:
# [2284] begin
	pushq	%rax
.Lc584:
# Var aArg located at rsp+0, size=OS_64
# Var aObj located in register rdi
	movq	%rsi,(%rsp)
# [2287] Result := UInt64(atomic_fetch_xor_64(PInt64(@aObj)^, PInt64(@aArg)^, mo_seq_cst));
	movq	(%rsp),%rsi
	movl	$5,%edx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR_64$INT64$INT64$MEMORY_ORDER_T$$INT64
# Var $result located in register rax
# [2289] end;
	popq	%rcx
.Lc585:
	ret
.Lc582:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_xor$longint$longint$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR$LONGINT$LONGINT$$LONGINT
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR$LONGINT$LONGINT$$LONGINT,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR$LONGINT$LONGINT$$LONGINT:
.Lc587:
# [2293] begin
	pushq	%rax
.Lc588:
# Var aObj located in register rdi
# Var aArg located in register esi
# [2294] Result := atomic_fetch_xor(aObj, aArg, mo_seq_cst);
	movl	$5,%edx
# Var aArg located in register esi
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT
# Var $result located in register eax
# [2295] end;
	popq	%rcx
.Lc589:
	ret
.Lc586:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_xor$longword$longword$$longword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR$LONGWORD$LONGWORD$$LONGWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR$LONGWORD$LONGWORD$$LONGWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR$LONGWORD$LONGWORD$$LONGWORD:
.Lc591:
# [2298] begin
	pushq	%rax
.Lc592:
# Var aArg located at rsp+0, size=OS_32
# Var aObj located in register rdi
	movl	%esi,(%rsp)
# [2301] Result := UInt32(atomic_fetch_xor(PInt32(@aObj)^, PInt32(@aArg)^));
	movl	(%rsp),%esi
	movl	$5,%edx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT
# Var $result located in register eax
# [2303] end;
	popq	%rcx
.Lc593:
	ret
.Lc590:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_xor$int64$int64$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR$INT64$INT64$$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR$INT64$INT64$$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR$INT64$INT64$$INT64:
.Lc595:
# [2307] begin
	pushq	%rax
.Lc596:
# Var aArg located at rsp+0, size=OS_S64
# Var aObj located in register rdi
	movq	%rsi,(%rsp)
# [2311] Result := PtrInt(atomic_fetch_xor_64(PInt64(@aObj)^, PInt64(@aArg)^));
	movq	(%rsp),%rsi
	movl	$5,%edx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR_64$INT64$INT64$MEMORY_ORDER_T$$INT64
# Var $result located in register rax
# [2313] end;
	popq	%rcx
.Lc597:
	ret
.Lc594:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_xor$qword$qword$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR$QWORD$QWORD$$QWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR$QWORD$QWORD$$QWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR$QWORD$QWORD$$QWORD:
.Lc599:
# Temps allocated between rsp+0 and rsp+8
# [2316] begin
	pushq	%rax
.Lc600:
# Var aObj located in register rdi
# Var aArg located in register rsi
# Var aArg located in register rsi
# [2317] Result := PtrUInt(atomic_fetch_xor(PPtrInt(@aObj)^, PtrInt(aArg)));
	movq	%rsi,(%rsp)
	movq	(%rsp),%rsi
	movl	$5,%edx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR_64$INT64$INT64$MEMORY_ORDER_T$$INT64
# Var $result located in register rax
# [2318] end;
	popq	%rcx
.Lc601:
	ret
.Lc598:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_add$longint$longint$memory_order_t$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT:
.Lc603:
# [2327] begin
	pushq	%rax
.Lc604:
# Var aObj located in register rdi
# Var aArg located in register esi
# Var aOrder located in register edx
# Var aArg located in register esi
# [2344] Result := InterlockedExchangeAdd(aObj, aArg);
	call	SYSTEM_$$_INTERLOCKEDEXCHANGEADD$LONGINT$LONGINT$$LONGINT
# Var $result located in register eax
# [2356] end;
	popq	%rcx
.Lc605:
	ret
.Lc602:
.Le8:
	.size	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT, .Le8 - NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_add$longword$longword$memory_order_t$$longword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD$LONGWORD$LONGWORD$MEMORY_ORDER_T$$LONGWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD$LONGWORD$LONGWORD$MEMORY_ORDER_T$$LONGWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD$LONGWORD$LONGWORD$MEMORY_ORDER_T$$LONGWORD:
.Lc607:
# [2359] begin
	pushq	%rax
.Lc608:
# Var aArg located at rsp+0, size=OS_32
# Var aObj located in register rdi
	movl	%esi,(%rsp)
# Var aOrder located in register edx
# [2362] Result := UInt32(atomic_fetch_add(PInt32(@aObj)^, PInt32(@aArg)^, aOrder));
	movl	(%rsp),%esi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGEADD$LONGINT$LONGINT$$LONGINT
# Var $result located in register eax
# [2364] end;
	popq	%rcx
.Lc609:
	ret
.Lc606:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_add$int64$int64$memory_order_t$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD$INT64$INT64$MEMORY_ORDER_T$$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD$INT64$INT64$MEMORY_ORDER_T$$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD$INT64$INT64$MEMORY_ORDER_T$$INT64:
.Lc611:
# [2368] begin
	pushq	%rax
.Lc612:
# Var aArg located at rsp+0, size=OS_S64
# Var aObj located in register rdi
	movq	%rsi,(%rsp)
# Var aOrder located in register edx
# [2372] Result := PtrInt(atomic_fetch_add_64(PInt64(@aObj)^, PInt64(@aArg)^, aOrder));
	movq	(%rsp),%rsi
# Var aOrder located in register edx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD_64$INT64$INT64$MEMORY_ORDER_T$$INT64
# Var $result located in register rax
# [2374] end;
	popq	%rcx
.Lc613:
	ret
.Lc610:
.Le9:
	.size	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD$INT64$INT64$MEMORY_ORDER_T$$INT64, .Le9 - NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD$INT64$INT64$MEMORY_ORDER_T$$INT64

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_add$qword$qword$memory_order_t$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD$QWORD$QWORD$MEMORY_ORDER_T$$QWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD$QWORD$QWORD$MEMORY_ORDER_T$$QWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD$QWORD$QWORD$MEMORY_ORDER_T$$QWORD:
.Lc615:
# Temps allocated between rsp+8 and rsp+16
# [2377] begin
	leaq	-24(%rsp),%rsp
.Lc616:
# Var aArg located at rsp+0, size=OS_64
# Var aObj located in register rdi
	movq	%rsi,(%rsp)
# Var aOrder located in register edx
# [2380] Result := PtrUInt(atomic_fetch_add(PPtrInt(@aObj)^, PPtrInt(@aArg)^, aOrder));
	movq	(%rsp),%rsi
	movq	%rsi,8(%rsp)
# Var aOrder located in register edx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD_64$INT64$INT64$MEMORY_ORDER_T$$INT64
# Var $result located in register rax
# [2382] end;
	leaq	24(%rsp),%rsp
.Lc617:
	ret
.Lc614:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_add_64$int64$int64$memory_order_t$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD_64$INT64$INT64$MEMORY_ORDER_T$$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD_64$INT64$INT64$MEMORY_ORDER_T$$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD_64$INT64$INT64$MEMORY_ORDER_T$$INT64:
.Lc619:
# [2387] begin
	pushq	%rax
.Lc620:
# Var aObj located in register rdi
# Var aArg located in register rsi
# Var aOrder located in register edx
# Var aArg located in register rsi
# [2407] Result := InterlockedExchangeAdd64(aObj, aArg);
	call	SYSTEM_$$_INTERLOCKEDEXCHANGEADD64$INT64$INT64$$INT64
# Var $result located in register rax
# [2420] end;
	popq	%rcx
.Lc621:
	ret
.Lc618:
.Le10:
	.size	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD_64$INT64$INT64$MEMORY_ORDER_T$$INT64, .Le10 - NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD_64$INT64$INT64$MEMORY_ORDER_T$$INT64

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_add_64$qword$qword$memory_order_t$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD_64$QWORD$QWORD$MEMORY_ORDER_T$$QWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD_64$QWORD$QWORD$MEMORY_ORDER_T$$QWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_ADD_64$QWORD$QWORD$MEMORY_ORDER_T$$QWORD:
.Lc623:
# [2423] begin
	pushq	%rax
.Lc624:
# Var aArg located at rsp+0, size=OS_64
# Var aObj located in register rdi
	movq	%rsi,(%rsp)
# Var aOrder located in register edx
# [2426] Result := UInt64(atomic_fetch_add_64(PInt64(@aObj)^, PInt64(@aArg)^, aOrder));
	movq	(%rsp),%rsi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGEADD64$INT64$INT64$$INT64
# Var $result located in register rax
# [2428] end;
	popq	%rcx
.Lc625:
	ret
.Lc622:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_sub$longint$longint$memory_order_t$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_SUB$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_SUB$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_SUB$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT:
.Lc627:
# [2433] begin
	pushq	%rax
.Lc628:
# Var aObj located in register rdi
# Var aArg located in register esi
# Var aOrder located in register edx
# [2434] Result := atomic_fetch_add(aObj, -aArg, aOrder);
	negl	%esi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGEADD$LONGINT$LONGINT$$LONGINT
# Var $result located in register eax
# [2435] end;
	popq	%rcx
.Lc629:
	ret
.Lc626:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_sub$longword$longword$memory_order_t$$longword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_SUB$LONGWORD$LONGWORD$MEMORY_ORDER_T$$LONGWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_SUB$LONGWORD$LONGWORD$MEMORY_ORDER_T$$LONGWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_SUB$LONGWORD$LONGWORD$MEMORY_ORDER_T$$LONGWORD:
.Lc631:
# [2438] begin
	pushq	%rax
.Lc632:
# Var aArg located at rsp+0, size=OS_32
# Var aObj located in register rdi
	movl	%esi,(%rsp)
# Var aOrder located in register edx
# [2441] Result := UInt32(atomic_fetch_sub(PInt32(@aObj)^, PInt32(@aArg)^, aOrder));
	movl	(%rsp),%esi
	negl	%esi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGEADD$LONGINT$LONGINT$$LONGINT
# Var $result located in register eax
# [2443] end;
	popq	%rcx
.Lc633:
	ret
.Lc630:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_sub$int64$int64$memory_order_t$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_SUB$INT64$INT64$MEMORY_ORDER_T$$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_SUB$INT64$INT64$MEMORY_ORDER_T$$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_SUB$INT64$INT64$MEMORY_ORDER_T$$INT64:
.Lc635:
# [2447] begin
	pushq	%rax
.Lc636:
# Var aArg located at rsp+0, size=OS_S64
# Var aObj located in register rdi
	movq	%rsi,(%rsp)
# Var aOrder located in register edx
# [2451] Result := PtrInt(atomic_fetch_sub_64(PInt64(@aObj)^, PInt64(@aArg)^, aOrder));
	movq	(%rsp),%rsi
# Var aOrder located in register edx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_SUB_64$INT64$INT64$MEMORY_ORDER_T$$INT64
# Var $result located in register rax
# [2453] end;
	popq	%rcx
.Lc637:
	ret
.Lc634:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_sub$qword$qword$memory_order_t$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_SUB$QWORD$QWORD$MEMORY_ORDER_T$$QWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_SUB$QWORD$QWORD$MEMORY_ORDER_T$$QWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_SUB$QWORD$QWORD$MEMORY_ORDER_T$$QWORD:
.Lc639:
# Temps allocated between rsp+8 and rsp+16
# [2456] begin
	leaq	-24(%rsp),%rsp
.Lc640:
# Var aArg located at rsp+0, size=OS_64
# Var aObj located in register rdi
	movq	%rsi,(%rsp)
# Var aOrder located in register edx
# [2459] Result := PtrUInt(atomic_fetch_sub(PPtrInt(@aObj)^, PPtrInt(@aArg)^, aOrder));
	movq	(%rsp),%rsi
	movq	%rsi,8(%rsp)
# Var aOrder located in register edx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_SUB_64$INT64$INT64$MEMORY_ORDER_T$$INT64
# Var $result located in register rax
# [2461] end;
	leaq	24(%rsp),%rsp
.Lc641:
	ret
.Lc638:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_sub_64$int64$int64$memory_order_t$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_SUB_64$INT64$INT64$MEMORY_ORDER_T$$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_SUB_64$INT64$INT64$MEMORY_ORDER_T$$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_SUB_64$INT64$INT64$MEMORY_ORDER_T$$INT64:
.Lc643:
# [2466] begin
	pushq	%rax
.Lc644:
# Var aObj located in register rdi
# Var aArg located in register rsi
# Var aOrder located in register edx
# [2467] Result := atomic_fetch_add_64(aObj, -aArg, aOrder);
	negq	%rsi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGEADD64$INT64$INT64$$INT64
# Var $result located in register rax
# [2468] end;
	popq	%rcx
.Lc645:
	ret
.Lc642:
.Le11:
	.size	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_SUB_64$INT64$INT64$MEMORY_ORDER_T$$INT64, .Le11 - NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_SUB_64$INT64$INT64$MEMORY_ORDER_T$$INT64

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_sub_64$qword$qword$memory_order_t$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_SUB_64$QWORD$QWORD$MEMORY_ORDER_T$$QWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_SUB_64$QWORD$QWORD$MEMORY_ORDER_T$$QWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_SUB_64$QWORD$QWORD$MEMORY_ORDER_T$$QWORD:
.Lc647:
# [2471] begin
	pushq	%rax
.Lc648:
# Var aArg located at rsp+0, size=OS_64
# Var aObj located in register rdi
	movq	%rsi,(%rsp)
# Var aOrder located in register edx
# [2474] Result := UInt64(atomic_fetch_sub_64(PInt64(@aObj)^, PInt64(@aArg)^, aOrder));
	movq	(%rsp),%rsi
	negq	%rsi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGEADD64$INT64$INT64$$INT64
# Var $result located in register rax
# [2476] end;
	popq	%rcx
.Lc649:
	ret
.Lc646:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_and$longint$longint$memory_order_t$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT:
.Lc651:
# [2484] begin
	pushq	%rbx
.Lc652:
	pushq	%r12
.Lc653:
	pushq	%r13
.Lc654:
	pushq	%r14
.Lc655:
	pushq	%rax
.Lc656:
# Var LOld located in register r13d
# Var LNew located in register r14d
	movq	%rdi,%rbx
# Var aObj located in register rbx
	movl	%esi,%r12d
# Var aArg located in register r12d
# Var aOrder located in register edx
	.p2align 4,,10
	.p2align 3
.Lj672:
# [2500] LOld := aObj;
	movl	(%rbx),%r13d
# [2501] LNew := LOld and aArg;
	movl	%r13d,%r14d
	andl	%r12d,%r14d
# [2502] if InterlockedCompareExchange(aObj, LNew, LOld) = LOld then
	movq	%rbx,%rdi
	movl	%r13d,%edx
	movl	%r14d,%esi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE$LONGINT$LONGINT$LONGINT$$LONGINT
	cmpl	%r13d,%eax
	je	.Lj674
# [2504] cpu_pause;
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
# [2505] until False;
	jmp	.Lj672
.Lj674:
# Var $result located in register eax
# [2506] Result := LOld;
	movl	%r13d,%eax
# Var LOld located in register eax
# [2517] end;
	popq	%rcx
	popq	%r14
.Lc657:
	popq	%r13
.Lc658:
	popq	%r12
.Lc659:
	popq	%rbx
.Lc660:
	ret
.Lc650:
.Le12:
	.size	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT, .Le12 - NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_and$longword$longword$memory_order_t$$longword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND$LONGWORD$LONGWORD$MEMORY_ORDER_T$$LONGWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND$LONGWORD$LONGWORD$MEMORY_ORDER_T$$LONGWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND$LONGWORD$LONGWORD$MEMORY_ORDER_T$$LONGWORD:
.Lc662:
# [2520] begin
	pushq	%rbx
.Lc663:
	pushq	%r12
.Lc664:
	pushq	%r13
.Lc665:
	pushq	%r14
.Lc666:
	pushq	%rax
.Lc667:
# Var aArg located at rsp+0, size=OS_32
	movq	%rdi,%rbx
# Var aObj located in register rbx
	movl	%esi,(%rsp)
# Var aOrder located in register edx
# [2523] Result := UInt32(atomic_fetch_and(PInt32(@aObj)^, PInt32(@aArg)^, aOrder));
	movl	(%rsp),%r12d
	.p2align 4,,10
	.p2align 3
.Lj682:
	movl	(%rbx),%r13d
	movl	%r13d,%r14d
	andl	%r12d,%r14d
	movq	%rbx,%rdi
	movl	%r13d,%edx
	movl	%r14d,%esi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE$LONGINT$LONGINT$LONGINT$$LONGINT
	cmpl	%r13d,%eax
	je	.Lj684
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
	jmp	.Lj682
.Lj684:
	movl	%r13d,%eax
# Var $result located in register eax
# [2525] end;
	popq	%rcx
	popq	%r14
.Lc668:
	popq	%r13
.Lc669:
	popq	%r12
.Lc670:
	popq	%rbx
.Lc671:
	ret
.Lc661:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_and$int64$int64$memory_order_t$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND$INT64$INT64$MEMORY_ORDER_T$$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND$INT64$INT64$MEMORY_ORDER_T$$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND$INT64$INT64$MEMORY_ORDER_T$$INT64:
.Lc673:
# [2529] begin
	pushq	%rax
.Lc674:
# Var aArg located at rsp+0, size=OS_S64
# Var aObj located in register rdi
	movq	%rsi,(%rsp)
# Var aOrder located in register edx
# [2533] Result := PtrInt(atomic_fetch_and_64(PInt64(@aObj)^, PInt64(@aArg)^, aOrder));
	movq	(%rsp),%rsi
# Var aOrder located in register edx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND_64$INT64$INT64$MEMORY_ORDER_T$$INT64
# Var $result located in register rax
# [2535] end;
	popq	%rcx
.Lc675:
	ret
.Lc672:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_and$qword$qword$memory_order_t$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND$QWORD$QWORD$MEMORY_ORDER_T$$QWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND$QWORD$QWORD$MEMORY_ORDER_T$$QWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND$QWORD$QWORD$MEMORY_ORDER_T$$QWORD:
.Lc677:
# Temps allocated between rsp+0 and rsp+8
# [2538] begin
	pushq	%rax
.Lc678:
# Var aObj located in register rdi
# Var aArg located in register rsi
# Var aOrder located in register edx
# Var aArg located in register rsi
# [2539] Result := PtrUInt(atomic_fetch_and(PPtrInt(@aObj)^, PtrInt(aArg), aOrder));
	movq	%rsi,(%rsp)
	movq	(%rsp),%rsi
# Var aOrder located in register edx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND_64$INT64$INT64$MEMORY_ORDER_T$$INT64
# Var $result located in register rax
# [2540] end;
	popq	%rcx
.Lc679:
	ret
.Lc676:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_and_64$int64$int64$memory_order_t$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND_64$INT64$INT64$MEMORY_ORDER_T$$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND_64$INT64$INT64$MEMORY_ORDER_T$$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND_64$INT64$INT64$MEMORY_ORDER_T$$INT64:
.Lc681:
# [2548] begin
	pushq	%rbx
.Lc682:
	pushq	%r12
.Lc683:
	pushq	%r13
.Lc684:
	pushq	%r14
.Lc685:
	pushq	%rax
.Lc686:
# Var LOld located in register r13
# Var LNew located in register r14
	movq	%rdi,%rbx
# Var aObj located in register rbx
	movq	%rsi,%r12
# Var aArg located in register r12
# Var aOrder located in register edx
	.p2align 4,,10
	.p2align 3
.Lj695:
# [2562] LOld := {$IF DEFINED(CPUX86) AND NOT DEFINED(CPU64)}_atomic_load_64_x86(aObj){$ELSE}aObj{$ENDIF};
	movq	(%rbx),%r13
# [2563] LNew := LOld and aArg;
	movq	%r13,%r14
	andq	%r12,%r14
# [2568] if InterlockedCompareExchange64(aObj, LNew, LOld) = LOld then
	movq	%rbx,%rdi
	movq	%r13,%rdx
	movq	%r14,%rsi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	cmpq	%r13,%rax
	je	.Lj697
# [2571] cpu_pause;
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
# [2572] until False;
	jmp	.Lj695
.Lj697:
# Var $result located in register rax
# [2573] Result := LOld;
	movq	%r13,%rax
# Var LOld located in register rax
# [2582] end;
	popq	%rcx
	popq	%r14
.Lc687:
	popq	%r13
.Lc688:
	popq	%r12
.Lc689:
	popq	%rbx
.Lc690:
	ret
.Lc680:
.Le13:
	.size	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND_64$INT64$INT64$MEMORY_ORDER_T$$INT64, .Le13 - NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND_64$INT64$INT64$MEMORY_ORDER_T$$INT64

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_and_64$qword$qword$memory_order_t$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND_64$QWORD$QWORD$MEMORY_ORDER_T$$QWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND_64$QWORD$QWORD$MEMORY_ORDER_T$$QWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_AND_64$QWORD$QWORD$MEMORY_ORDER_T$$QWORD:
.Lc692:
# [2585] begin
	pushq	%rbx
.Lc693:
	pushq	%r12
.Lc694:
	pushq	%r13
.Lc695:
	pushq	%r14
.Lc696:
	pushq	%rax
.Lc697:
# Var aArg located at rsp+0, size=OS_64
	movq	%rdi,%rbx
# Var aObj located in register rbx
	movq	%rsi,(%rsp)
# Var aOrder located in register edx
# [2586] Result := UInt64(atomic_fetch_and_64(PInt64(@aObj)^, PInt64(@aArg)^, aOrder));
	movq	(%rsp),%r12
	.p2align 4,,10
	.p2align 3
.Lj705:
	movq	(%rbx),%r13
	movq	%r13,%r14
	andq	%r12,%r14
	movq	%rbx,%rdi
	movq	%r13,%rdx
	movq	%r14,%rsi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	cmpq	%r13,%rax
	je	.Lj707
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
	jmp	.Lj705
.Lj707:
	movq	%r13,%rax
# Var $result located in register rax
# [2587] end;
	popq	%rcx
	popq	%r14
.Lc698:
	popq	%r13
.Lc699:
	popq	%r12
.Lc700:
	popq	%rbx
.Lc701:
	ret
.Lc691:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_or$longint$longint$memory_order_t$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT:
.Lc703:
# [2595] begin
	pushq	%rbx
.Lc704:
	pushq	%r12
.Lc705:
	pushq	%r13
.Lc706:
	pushq	%r14
.Lc707:
	pushq	%rax
.Lc708:
# Var LOld located in register r13d
# Var LNew located in register r14d
	movq	%rdi,%rbx
# Var aObj located in register rbx
	movl	%esi,%r12d
# Var aArg located in register r12d
# Var aOrder located in register edx
	.p2align 4,,10
	.p2align 3
.Lj714:
# [2609] LOld := aObj;
	movl	(%rbx),%r13d
# [2610] LNew := LOld or aArg;
	movl	%r13d,%r14d
	orl	%r12d,%r14d
# [2611] if InterlockedCompareExchange(aObj, LNew, LOld) = LOld then
	movq	%rbx,%rdi
	movl	%r13d,%edx
	movl	%r14d,%esi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE$LONGINT$LONGINT$LONGINT$$LONGINT
	cmpl	%r13d,%eax
	je	.Lj716
# [2613] cpu_pause;
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
# [2614] until False;
	jmp	.Lj714
.Lj716:
# Var $result located in register eax
# [2615] Result := LOld;
	movl	%r13d,%eax
# Var LOld located in register eax
# [2624] end;
	popq	%rcx
	popq	%r14
.Lc709:
	popq	%r13
.Lc710:
	popq	%r12
.Lc711:
	popq	%rbx
.Lc712:
	ret
.Lc702:
.Le14:
	.size	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT, .Le14 - NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_or$longword$longword$memory_order_t$$longword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR$LONGWORD$LONGWORD$MEMORY_ORDER_T$$LONGWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR$LONGWORD$LONGWORD$MEMORY_ORDER_T$$LONGWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR$LONGWORD$LONGWORD$MEMORY_ORDER_T$$LONGWORD:
.Lc714:
# [2627] begin
	pushq	%rbx
.Lc715:
	pushq	%r12
.Lc716:
	pushq	%r13
.Lc717:
	pushq	%r14
.Lc718:
	pushq	%rax
.Lc719:
# Var aArg located at rsp+0, size=OS_32
	movq	%rdi,%rbx
# Var aObj located in register rbx
	movl	%esi,(%rsp)
# Var aOrder located in register edx
# [2630] Result := UInt32(atomic_fetch_or(PInt32(@aObj)^, PInt32(@aArg)^, aOrder));
	movl	(%rsp),%r12d
	.p2align 4,,10
	.p2align 3
.Lj724:
	movl	(%rbx),%r13d
	movl	%r13d,%r14d
	orl	%r12d,%r14d
	movq	%rbx,%rdi
	movl	%r13d,%edx
	movl	%r14d,%esi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE$LONGINT$LONGINT$LONGINT$$LONGINT
	cmpl	%r13d,%eax
	je	.Lj726
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
	jmp	.Lj724
.Lj726:
	movl	%r13d,%eax
# Var $result located in register eax
# [2632] end;
	popq	%rcx
	popq	%r14
.Lc720:
	popq	%r13
.Lc721:
	popq	%r12
.Lc722:
	popq	%rbx
.Lc723:
	ret
.Lc713:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_or$int64$int64$memory_order_t$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR$INT64$INT64$MEMORY_ORDER_T$$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR$INT64$INT64$MEMORY_ORDER_T$$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR$INT64$INT64$MEMORY_ORDER_T$$INT64:
.Lc725:
# [2636] begin
	pushq	%rax
.Lc726:
# Var aArg located at rsp+0, size=OS_S64
# Var aObj located in register rdi
	movq	%rsi,(%rsp)
# Var aOrder located in register edx
# [2640] Result := PtrInt(atomic_fetch_or_64(PInt64(@aObj)^, PInt64(@aArg)^, aOrder));
	movq	(%rsp),%rsi
# Var aOrder located in register edx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR_64$INT64$INT64$MEMORY_ORDER_T$$INT64
# Var $result located in register rax
# [2642] end;
	popq	%rcx
.Lc727:
	ret
.Lc724:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_or$qword$qword$memory_order_t$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR$QWORD$QWORD$MEMORY_ORDER_T$$QWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR$QWORD$QWORD$MEMORY_ORDER_T$$QWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR$QWORD$QWORD$MEMORY_ORDER_T$$QWORD:
.Lc729:
# Temps allocated between rsp+0 and rsp+8
# [2645] begin
	pushq	%rax
.Lc730:
# Var aObj located in register rdi
# Var aArg located in register rsi
# Var aOrder located in register edx
# Var aArg located in register rsi
# [2646] Result := PtrUInt(atomic_fetch_or(PPtrInt(@aObj)^, PtrInt(aArg), aOrder));
	movq	%rsi,(%rsp)
	movq	(%rsp),%rsi
# Var aOrder located in register edx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR_64$INT64$INT64$MEMORY_ORDER_T$$INT64
# Var $result located in register rax
# [2647] end;
	popq	%rcx
.Lc731:
	ret
.Lc728:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_or_64$int64$int64$memory_order_t$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR_64$INT64$INT64$MEMORY_ORDER_T$$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR_64$INT64$INT64$MEMORY_ORDER_T$$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR_64$INT64$INT64$MEMORY_ORDER_T$$INT64:
.Lc733:
# [2655] begin
	pushq	%rbx
.Lc734:
	pushq	%r12
.Lc735:
	pushq	%r13
.Lc736:
	pushq	%r14
.Lc737:
	pushq	%rax
.Lc738:
# Var LOld located in register r13
# Var LNew located in register r14
	movq	%rdi,%rbx
# Var aObj located in register rbx
	movq	%rsi,%r12
# Var aArg located in register r12
# Var aOrder located in register edx
	.p2align 4,,10
	.p2align 3
.Lj737:
# [2669] LOld := {$IF DEFINED(CPUX86) AND NOT DEFINED(CPU64)}_atomic_load_64_x86(aObj){$ELSE}aObj{$ENDIF};
	movq	(%rbx),%r13
# [2670] LNew := LOld or aArg;
	movq	%r13,%r14
	orq	%r12,%r14
# [2675] if InterlockedCompareExchange64(aObj, LNew, LOld) = LOld then
	movq	%rbx,%rdi
	movq	%r13,%rdx
	movq	%r14,%rsi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	cmpq	%r13,%rax
	je	.Lj739
# [2678] cpu_pause;
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
# [2679] until False;
	jmp	.Lj737
.Lj739:
# Var $result located in register rax
# [2680] Result := LOld;
	movq	%r13,%rax
# Var LOld located in register rax
# [2689] end;
	popq	%rcx
	popq	%r14
.Lc739:
	popq	%r13
.Lc740:
	popq	%r12
.Lc741:
	popq	%rbx
.Lc742:
	ret
.Lc732:
.Le15:
	.size	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR_64$INT64$INT64$MEMORY_ORDER_T$$INT64, .Le15 - NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR_64$INT64$INT64$MEMORY_ORDER_T$$INT64

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_or_64$qword$qword$memory_order_t$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR_64$QWORD$QWORD$MEMORY_ORDER_T$$QWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR_64$QWORD$QWORD$MEMORY_ORDER_T$$QWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_OR_64$QWORD$QWORD$MEMORY_ORDER_T$$QWORD:
.Lc744:
# [2692] begin
	pushq	%rbx
.Lc745:
	pushq	%r12
.Lc746:
	pushq	%r13
.Lc747:
	pushq	%r14
.Lc748:
	pushq	%rax
.Lc749:
# Var aArg located at rsp+0, size=OS_64
	movq	%rdi,%rbx
# Var aObj located in register rbx
	movq	%rsi,(%rsp)
# Var aOrder located in register edx
# [2693] Result := UInt64(atomic_fetch_or_64(PInt64(@aObj)^, PInt64(@aArg)^, aOrder));
	movq	(%rsp),%r12
	.p2align 4,,10
	.p2align 3
.Lj747:
	movq	(%rbx),%r13
	movq	%r13,%r14
	orq	%r12,%r14
	movq	%rbx,%rdi
	movq	%r13,%rdx
	movq	%r14,%rsi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	cmpq	%r13,%rax
	je	.Lj749
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
	jmp	.Lj747
.Lj749:
	movq	%r13,%rax
# Var $result located in register rax
# [2694] end;
	popq	%rcx
	popq	%r14
.Lc750:
	popq	%r13
.Lc751:
	popq	%r12
.Lc752:
	popq	%rbx
.Lc753:
	ret
.Lc743:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_xor$longint$longint$memory_order_t$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT:
.Lc755:
# [2702] begin
	pushq	%rbx
.Lc756:
	pushq	%r12
.Lc757:
	pushq	%r13
.Lc758:
	pushq	%r14
.Lc759:
	pushq	%rax
.Lc760:
# Var LOld located in register r13d
# Var LNew located in register r14d
	movq	%rdi,%rbx
# Var aObj located in register rbx
	movl	%esi,%r12d
# Var aArg located in register r12d
# Var aOrder located in register edx
	.p2align 4,,10
	.p2align 3
.Lj756:
# [2716] LOld := aObj;
	movl	(%rbx),%r13d
# [2717] LNew := LOld xor aArg;
	movl	%r13d,%r14d
	xorl	%r12d,%r14d
# [2718] if InterlockedCompareExchange(aObj, LNew, LOld) = LOld then
	movq	%rbx,%rdi
	movl	%r13d,%edx
	movl	%r14d,%esi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE$LONGINT$LONGINT$LONGINT$$LONGINT
	cmpl	%r13d,%eax
	je	.Lj758
# [2720] cpu_pause;
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
# [2721] until False;
	jmp	.Lj756
.Lj758:
# Var $result located in register eax
# [2722] Result := LOld;
	movl	%r13d,%eax
# Var LOld located in register eax
# [2731] end;
	popq	%rcx
	popq	%r14
.Lc761:
	popq	%r13
.Lc762:
	popq	%r12
.Lc763:
	popq	%rbx
.Lc764:
	ret
.Lc754:
.Le16:
	.size	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT, .Le16 - NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_xor$longword$longword$memory_order_t$$longword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR$LONGWORD$LONGWORD$MEMORY_ORDER_T$$LONGWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR$LONGWORD$LONGWORD$MEMORY_ORDER_T$$LONGWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR$LONGWORD$LONGWORD$MEMORY_ORDER_T$$LONGWORD:
.Lc766:
# [2734] begin
	pushq	%rbx
.Lc767:
	pushq	%r12
.Lc768:
	pushq	%r13
.Lc769:
	pushq	%r14
.Lc770:
	pushq	%rax
.Lc771:
# Var aArg located at rsp+0, size=OS_32
	movq	%rdi,%rbx
# Var aObj located in register rbx
	movl	%esi,(%rsp)
# Var aOrder located in register edx
# [2737] Result := UInt32(atomic_fetch_xor(PInt32(@aObj)^, PInt32(@aArg)^, aOrder));
	movl	(%rsp),%r12d
	.p2align 4,,10
	.p2align 3
.Lj766:
	movl	(%rbx),%r13d
	movl	%r13d,%r14d
	xorl	%r12d,%r14d
	movq	%rbx,%rdi
	movl	%r13d,%edx
	movl	%r14d,%esi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE$LONGINT$LONGINT$LONGINT$$LONGINT
	cmpl	%r13d,%eax
	je	.Lj768
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
	jmp	.Lj766
.Lj768:
	movl	%r13d,%eax
# Var $result located in register eax
# [2739] end;
	popq	%rcx
	popq	%r14
.Lc772:
	popq	%r13
.Lc773:
	popq	%r12
.Lc774:
	popq	%rbx
.Lc775:
	ret
.Lc765:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_xor$int64$int64$memory_order_t$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR$INT64$INT64$MEMORY_ORDER_T$$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR$INT64$INT64$MEMORY_ORDER_T$$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR$INT64$INT64$MEMORY_ORDER_T$$INT64:
.Lc777:
# [2743] begin
	pushq	%rax
.Lc778:
# Var aArg located at rsp+0, size=OS_S64
# Var aObj located in register rdi
	movq	%rsi,(%rsp)
# Var aOrder located in register edx
# [2747] Result := PtrInt(atomic_fetch_xor_64(PInt64(@aObj)^, PInt64(@aArg)^, aOrder));
	movq	(%rsp),%rsi
# Var aOrder located in register edx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR_64$INT64$INT64$MEMORY_ORDER_T$$INT64
# Var $result located in register rax
# [2749] end;
	popq	%rcx
.Lc779:
	ret
.Lc776:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_xor$qword$qword$memory_order_t$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR$QWORD$QWORD$MEMORY_ORDER_T$$QWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR$QWORD$QWORD$MEMORY_ORDER_T$$QWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR$QWORD$QWORD$MEMORY_ORDER_T$$QWORD:
.Lc781:
# Temps allocated between rsp+0 and rsp+8
# [2752] begin
	pushq	%rax
.Lc782:
# Var aObj located in register rdi
# Var aArg located in register rsi
# Var aOrder located in register edx
# Var aArg located in register rsi
# [2753] Result := PtrUInt(atomic_fetch_xor(PPtrInt(@aObj)^, PtrInt(aArg), aOrder));
	movq	%rsi,(%rsp)
	movq	(%rsp),%rsi
# Var aOrder located in register edx
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR_64$INT64$INT64$MEMORY_ORDER_T$$INT64
# Var $result located in register rax
# [2754] end;
	popq	%rcx
.Lc783:
	ret
.Lc780:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_xor_64$int64$int64$memory_order_t$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR_64$INT64$INT64$MEMORY_ORDER_T$$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR_64$INT64$INT64$MEMORY_ORDER_T$$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR_64$INT64$INT64$MEMORY_ORDER_T$$INT64:
.Lc785:
# [2762] begin
	pushq	%rbx
.Lc786:
	pushq	%r12
.Lc787:
	pushq	%r13
.Lc788:
	pushq	%r14
.Lc789:
	pushq	%rax
.Lc790:
# Var LOld located in register r13
# Var LNew located in register r14
	movq	%rdi,%rbx
# Var aObj located in register rbx
	movq	%rsi,%r12
# Var aArg located in register r12
# Var aOrder located in register edx
	.p2align 4,,10
	.p2align 3
.Lj779:
# [2776] LOld := {$IF DEFINED(CPUX86) AND NOT DEFINED(CPU64)}_atomic_load_64_x86(aObj){$ELSE}aObj{$ENDIF};
	movq	(%rbx),%r13
# [2777] LNew := LOld xor aArg;
	movq	%r13,%r14
	xorq	%r12,%r14
# [2782] if InterlockedCompareExchange64(aObj, LNew, LOld) = LOld then
	movq	%rbx,%rdi
	movq	%r13,%rdx
	movq	%r14,%rsi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	cmpq	%r13,%rax
	je	.Lj781
# [2785] cpu_pause;
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
# [2786] until False;
	jmp	.Lj779
.Lj781:
# Var $result located in register rax
# [2787] Result := LOld;
	movq	%r13,%rax
# Var LOld located in register rax
# [2796] end;
	popq	%rcx
	popq	%r14
.Lc791:
	popq	%r13
.Lc792:
	popq	%r12
.Lc793:
	popq	%rbx
.Lc794:
	ret
.Lc784:
.Le17:
	.size	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR_64$INT64$INT64$MEMORY_ORDER_T$$INT64, .Le17 - NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR_64$INT64$INT64$MEMORY_ORDER_T$$INT64

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_xor_64$qword$qword$memory_order_t$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR_64$QWORD$QWORD$MEMORY_ORDER_T$$QWORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR_64$QWORD$QWORD$MEMORY_ORDER_T$$QWORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_XOR_64$QWORD$QWORD$MEMORY_ORDER_T$$QWORD:
.Lc796:
# [2799] begin
	pushq	%rbx
.Lc797:
	pushq	%r12
.Lc798:
	pushq	%r13
.Lc799:
	pushq	%r14
.Lc800:
	pushq	%rax
.Lc801:
# Var aArg located at rsp+0, size=OS_64
	movq	%rdi,%rbx
# Var aObj located in register rbx
	movq	%rsi,(%rsp)
# Var aOrder located in register edx
# [2800] Result := UInt64(atomic_fetch_xor_64(PInt64(@aObj)^, PInt64(@aArg)^, aOrder));
	movq	(%rsp),%r12
	.p2align 4,,10
	.p2align 3
.Lj789:
	movq	(%rbx),%r13
	movq	%r13,%r14
	xorq	%r12,%r14
	movq	%rbx,%rdi
	movq	%r13,%rdx
	movq	%r14,%rsi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	cmpq	%r13,%rax
	je	.Lj791
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
	jmp	.Lj789
.Lj791:
	movq	%r13,%rax
# Var $result located in register rax
# [2801] end;
	popq	%rcx
	popq	%r14
.Lc802:
	popq	%r13
.Lc803:
	popq	%r12
.Lc804:
	popq	%rbx
.Lc805:
	ret
.Lc795:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_max$longint$longint$memory_order_t$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_MAX$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_MAX$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_MAX$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT:
.Lc807:
# [2813] begin
	pushq	%rbx
.Lc808:
	pushq	%r12
.Lc809:
	pushq	%r13
.Lc810:
	pushq	%r14
.Lc811:
	pushq	%rax
.Lc812:
# Var LOld located in register r13d
# Var LNew located in register r14d
	movq	%rdi,%rbx
# Var aObj located in register rbx
	movl	%esi,%r12d
# Var aArg located in register r12d
# Var aOrder located in register edx
	.p2align 4,,10
	.p2align 3
.Lj798:
# [2827] LOld := aObj;
	movl	(%rbx),%r13d
# [2828] if aArg > LOld then
	movl	%r12d,%eax
	cmpl	%r12d,%r13d
	cmovgl	%r13d,%eax
	movl	%eax,%r14d
# [2832] if InterlockedCompareExchange(aObj, LNew, LOld) = LOld then
	movq	%rbx,%rdi
	movl	%r13d,%edx
	movl	%r14d,%esi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE$LONGINT$LONGINT$LONGINT$$LONGINT
	cmpl	%r13d,%eax
	je	.Lj800
# [2834] cpu_pause;
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
# [2835] until False;
	jmp	.Lj798
.Lj800:
# Var $result located in register eax
# [2836] Result := LOld;
	movl	%r13d,%eax
# Var LOld located in register eax
# [2845] end;
	popq	%rcx
	popq	%r14
.Lc813:
	popq	%r13
.Lc814:
	popq	%r12
.Lc815:
	popq	%rbx
.Lc816:
	ret
.Lc806:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_max$longint$longint$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_MAX$LONGINT$LONGINT$$LONGINT
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_MAX$LONGINT$LONGINT$$LONGINT,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_MAX$LONGINT$LONGINT$$LONGINT:
.Lc818:
# [2848] begin
	pushq	%rbx
.Lc819:
	pushq	%r12
.Lc820:
	pushq	%r13
.Lc821:
	pushq	%r14
.Lc822:
	pushq	%rax
.Lc823:
	movq	%rdi,%rbx
# Var aObj located in register rbx
	movl	%esi,%r12d
# Var aArg located in register r12d
	.p2align 4,,10
	.p2align 3
.Lj807:
# [2849] Result := atomic_fetch_max(aObj, aArg, mo_seq_cst);
	movl	(%rbx),%r13d
	movl	%r12d,%eax
	cmpl	%r12d,%r13d
	cmovgl	%r13d,%eax
	movl	%eax,%r14d
	movq	%rbx,%rdi
	movl	%r13d,%edx
	movl	%r14d,%esi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE$LONGINT$LONGINT$LONGINT$$LONGINT
	cmpl	%r13d,%eax
	je	.Lj809
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
	jmp	.Lj807
.Lj809:
	movl	%r13d,%eax
# Var $result located in register eax
# [2850] end;
	popq	%rcx
	popq	%r14
.Lc824:
	popq	%r13
.Lc825:
	popq	%r12
.Lc826:
	popq	%rbx
.Lc827:
	ret
.Lc817:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_max_64$int64$int64$memory_order_t$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_MAX_64$INT64$INT64$MEMORY_ORDER_T$$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_MAX_64$INT64$INT64$MEMORY_ORDER_T$$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_MAX_64$INT64$INT64$MEMORY_ORDER_T$$INT64:
.Lc829:
# [2857] begin
	pushq	%rbx
.Lc830:
	pushq	%r12
.Lc831:
	pushq	%r13
.Lc832:
	pushq	%r14
.Lc833:
	pushq	%rax
.Lc834:
# Var LOld located in register r13
# Var LNew located in register r14
	movq	%rdi,%rbx
# Var aObj located in register rbx
	movq	%rsi,%r12
# Var aArg located in register r12
# Var aOrder located in register edx
	.p2align 4,,10
	.p2align 3
.Lj816:
# [2871] LOld := {$IF DEFINED(CPUX86) AND NOT DEFINED(CPU64)}_atomic_load_64_x86(aObj){$ELSE}aObj{$ENDIF};
	movq	(%rbx),%r13
# [2872] if aArg > LOld then
	movq	%r12,%rax
	cmpq	%r12,%r13
	cmovgq	%r13,%rax
	movq	%rax,%r14
# [2880] if InterlockedCompareExchange64(aObj, LNew, LOld) = LOld then
	movq	%rbx,%rdi
	movq	%r13,%rdx
	movq	%r14,%rsi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	cmpq	%r13,%rax
	je	.Lj818
# [2883] cpu_pause;
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
# [2884] until False;
	jmp	.Lj816
.Lj818:
# Var $result located in register rax
# [2885] Result := LOld;
	movq	%r13,%rax
# Var LOld located in register rax
# [2894] end;
	popq	%rcx
	popq	%r14
.Lc835:
	popq	%r13
.Lc836:
	popq	%r12
.Lc837:
	popq	%rbx
.Lc838:
	ret
.Lc828:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_max_64$int64$int64$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_MAX_64$INT64$INT64$$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_MAX_64$INT64$INT64$$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_MAX_64$INT64$INT64$$INT64:
.Lc840:
# [2897] begin
	pushq	%rbx
.Lc841:
	pushq	%r12
.Lc842:
	pushq	%r13
.Lc843:
	pushq	%r14
.Lc844:
	pushq	%rax
.Lc845:
	movq	%rdi,%rbx
# Var aObj located in register rbx
	movq	%rsi,%r12
# Var aArg located in register r12
	.p2align 4,,10
	.p2align 3
.Lj825:
# [2898] Result := atomic_fetch_max_64(aObj, aArg, mo_seq_cst);
	movq	(%rbx),%r13
	movq	%r12,%rax
	cmpq	%r12,%r13
	cmovgq	%r13,%rax
	movq	%rax,%r14
	movq	%rbx,%rdi
	movq	%r13,%rdx
	movq	%r14,%rsi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	cmpq	%r13,%rax
	je	.Lj827
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
	jmp	.Lj825
.Lj827:
	movq	%r13,%rax
# Var $result located in register rax
# [2899] end;
	popq	%rcx
	popq	%r14
.Lc846:
	popq	%r13
.Lc847:
	popq	%r12
.Lc848:
	popq	%rbx
.Lc849:
	ret
.Lc839:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_min$longint$longint$memory_order_t$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_MIN$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_MIN$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_MIN$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT:
.Lc851:
# [2907] begin
	pushq	%rbx
.Lc852:
	pushq	%r12
.Lc853:
	pushq	%r13
.Lc854:
	pushq	%r14
.Lc855:
	pushq	%rax
.Lc856:
# Var LOld located in register r13d
# Var LNew located in register r14d
	movq	%rdi,%rbx
# Var aObj located in register rbx
	movl	%esi,%r12d
# Var aArg located in register r12d
# Var aOrder located in register edx
	.p2align 4,,10
	.p2align 3
.Lj834:
# [2921] LOld := aObj;
	movl	(%rbx),%r13d
# [2922] if aArg < LOld then
	movl	%r12d,%eax
	cmpl	%r12d,%r13d
	cmovll	%r13d,%eax
	movl	%eax,%r14d
# [2926] if InterlockedCompareExchange(aObj, LNew, LOld) = LOld then
	movq	%rbx,%rdi
	movl	%r13d,%edx
	movl	%r14d,%esi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE$LONGINT$LONGINT$LONGINT$$LONGINT
	cmpl	%r13d,%eax
	je	.Lj836
# [2928] cpu_pause;
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
# [2929] until False;
	jmp	.Lj834
.Lj836:
# Var $result located in register eax
# [2930] Result := LOld;
	movl	%r13d,%eax
# Var LOld located in register eax
# [2939] end;
	popq	%rcx
	popq	%r14
.Lc857:
	popq	%r13
.Lc858:
	popq	%r12
.Lc859:
	popq	%rbx
.Lc860:
	ret
.Lc850:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_min$longint$longint$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_MIN$LONGINT$LONGINT$$LONGINT
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_MIN$LONGINT$LONGINT$$LONGINT,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_MIN$LONGINT$LONGINT$$LONGINT:
.Lc862:
# [2942] begin
	pushq	%rbx
.Lc863:
	pushq	%r12
.Lc864:
	pushq	%r13
.Lc865:
	pushq	%r14
.Lc866:
	pushq	%rax
.Lc867:
	movq	%rdi,%rbx
# Var aObj located in register rbx
	movl	%esi,%r12d
# Var aArg located in register r12d
	.p2align 4,,10
	.p2align 3
.Lj843:
# [2943] Result := atomic_fetch_min(aObj, aArg, mo_seq_cst);
	movl	(%rbx),%r13d
	movl	%r12d,%eax
	cmpl	%r12d,%r13d
	cmovll	%r13d,%eax
	movl	%eax,%r14d
	movq	%rbx,%rdi
	movl	%r13d,%edx
	movl	%r14d,%esi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE$LONGINT$LONGINT$LONGINT$$LONGINT
	cmpl	%r13d,%eax
	je	.Lj845
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
	jmp	.Lj843
.Lj845:
	movl	%r13d,%eax
# Var $result located in register eax
# [2944] end;
	popq	%rcx
	popq	%r14
.Lc868:
	popq	%r13
.Lc869:
	popq	%r12
.Lc870:
	popq	%rbx
.Lc871:
	ret
.Lc861:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_min_64$int64$int64$memory_order_t$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_MIN_64$INT64$INT64$MEMORY_ORDER_T$$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_MIN_64$INT64$INT64$MEMORY_ORDER_T$$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_MIN_64$INT64$INT64$MEMORY_ORDER_T$$INT64:
.Lc873:
# [2951] begin
	pushq	%rbx
.Lc874:
	pushq	%r12
.Lc875:
	pushq	%r13
.Lc876:
	pushq	%r14
.Lc877:
	pushq	%rax
.Lc878:
# Var LOld located in register r13
# Var LNew located in register r14
	movq	%rdi,%rbx
# Var aObj located in register rbx
	movq	%rsi,%r12
# Var aArg located in register r12
# Var aOrder located in register edx
	.p2align 4,,10
	.p2align 3
.Lj852:
# [2965] LOld := {$IF DEFINED(CPUX86) AND NOT DEFINED(CPU64)}_atomic_load_64_x86(aObj){$ELSE}aObj{$ENDIF};
	movq	(%rbx),%r13
# [2966] if aArg < LOld then
	movq	%r12,%rax
	cmpq	%r12,%r13
	cmovlq	%r13,%rax
	movq	%rax,%r14
# [2974] if InterlockedCompareExchange64(aObj, LNew, LOld) = LOld then
	movq	%rbx,%rdi
	movq	%r13,%rdx
	movq	%r14,%rsi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	cmpq	%r13,%rax
	je	.Lj854
# [2977] cpu_pause;
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
# [2978] until False;
	jmp	.Lj852
.Lj854:
# Var $result located in register rax
# [2979] Result := LOld;
	movq	%r13,%rax
# Var LOld located in register rax
# [2988] end;
	popq	%rcx
	popq	%r14
.Lc879:
	popq	%r13
.Lc880:
	popq	%r12
.Lc881:
	popq	%rbx
.Lc882:
	ret
.Lc872:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_min_64$int64$int64$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_MIN_64$INT64$INT64$$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_MIN_64$INT64$INT64$$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_MIN_64$INT64$INT64$$INT64:
.Lc884:
# [2991] begin
	pushq	%rbx
.Lc885:
	pushq	%r12
.Lc886:
	pushq	%r13
.Lc887:
	pushq	%r14
.Lc888:
	pushq	%rax
.Lc889:
	movq	%rdi,%rbx
# Var aObj located in register rbx
	movq	%rsi,%r12
# Var aArg located in register r12
	.p2align 4,,10
	.p2align 3
.Lj861:
# [2992] Result := atomic_fetch_min_64(aObj, aArg, mo_seq_cst);
	movq	(%rbx),%r13
	movq	%r12,%rax
	cmpq	%r12,%r13
	cmovlq	%r13,%rax
	movq	%rax,%r14
	movq	%rbx,%rdi
	movq	%r13,%rdx
	movq	%r14,%rsi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	cmpq	%r13,%rax
	je	.Lj863
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
	jmp	.Lj861
.Lj863:
	movq	%r13,%rax
# Var $result located in register rax
# [2993] end;
	popq	%rcx
	popq	%r14
.Lc890:
	popq	%r13
.Lc891:
	popq	%r12
.Lc892:
	popq	%rbx
.Lc893:
	ret
.Lc883:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_nand$longint$longint$memory_order_t$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_NAND$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_NAND$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_NAND$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT:
.Lc895:
# [3001] begin
	pushq	%rbx
.Lc896:
	pushq	%r12
.Lc897:
	pushq	%r13
.Lc898:
	pushq	%r14
.Lc899:
	pushq	%rax
.Lc900:
# Var LOld located in register r13d
# Var LNew located in register r14d
	movq	%rdi,%rbx
# Var aObj located in register rbx
	movl	%esi,%r12d
# Var aArg located in register r12d
# Var aOrder located in register edx
	.p2align 4,,10
	.p2align 3
.Lj870:
# [3015] LOld := aObj;
	movl	(%rbx),%r13d
# [3016] LNew := not (LOld and aArg);
	movl	%r13d,%eax
	andl	%r12d,%eax
	notl	%eax
	movl	%eax,%r14d
# [3017] if InterlockedCompareExchange(aObj, LNew, LOld) = LOld then
	movq	%rbx,%rdi
	movl	%r13d,%edx
	movl	%r14d,%esi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE$LONGINT$LONGINT$LONGINT$$LONGINT
	cmpl	%r13d,%eax
	je	.Lj872
# [3019] cpu_pause;
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
# [3020] until False;
	jmp	.Lj870
.Lj872:
# Var $result located in register eax
# [3021] Result := LOld;
	movl	%r13d,%eax
# Var LOld located in register eax
# [3030] end;
	popq	%rcx
	popq	%r14
.Lc901:
	popq	%r13
.Lc902:
	popq	%r12
.Lc903:
	popq	%rbx
.Lc904:
	ret
.Lc894:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_nand$longint$longint$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_NAND$LONGINT$LONGINT$$LONGINT
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_NAND$LONGINT$LONGINT$$LONGINT,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_NAND$LONGINT$LONGINT$$LONGINT:
.Lc906:
# [3033] begin
	pushq	%rbx
.Lc907:
	pushq	%r12
.Lc908:
	pushq	%r13
.Lc909:
	pushq	%r14
.Lc910:
	pushq	%rax
.Lc911:
	movq	%rdi,%rbx
# Var aObj located in register rbx
	movl	%esi,%r12d
# Var aArg located in register r12d
	.p2align 4,,10
	.p2align 3
.Lj879:
# [3034] Result := atomic_fetch_nand(aObj, aArg, mo_seq_cst);
	movl	(%rbx),%r13d
	movl	%r13d,%eax
	andl	%r12d,%eax
	notl	%eax
	movl	%eax,%r14d
	movq	%rbx,%rdi
	movl	%r13d,%edx
	movl	%r14d,%esi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE$LONGINT$LONGINT$LONGINT$$LONGINT
	cmpl	%r13d,%eax
	je	.Lj881
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
	jmp	.Lj879
.Lj881:
	movl	%r13d,%eax
# Var $result located in register eax
# [3035] end;
	popq	%rcx
	popq	%r14
.Lc912:
	popq	%r13
.Lc913:
	popq	%r12
.Lc914:
	popq	%rbx
.Lc915:
	ret
.Lc905:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_nand_64$int64$int64$memory_order_t$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_NAND_64$INT64$INT64$MEMORY_ORDER_T$$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_NAND_64$INT64$INT64$MEMORY_ORDER_T$$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_NAND_64$INT64$INT64$MEMORY_ORDER_T$$INT64:
.Lc917:
# [3042] begin
	pushq	%rbx
.Lc918:
	pushq	%r12
.Lc919:
	pushq	%r13
.Lc920:
	pushq	%r14
.Lc921:
	pushq	%rax
.Lc922:
# Var LOld located in register r13
# Var LNew located in register r14
	movq	%rdi,%rbx
# Var aObj located in register rbx
	movq	%rsi,%r12
# Var aArg located in register r12
# Var aOrder located in register edx
	.p2align 4,,10
	.p2align 3
.Lj888:
# [3056] LOld := {$IF DEFINED(CPUX86) AND NOT DEFINED(CPU64)}_atomic_load_64_x86(aObj){$ELSE}aObj{$ENDIF};
	movq	(%rbx),%r13
# [3057] LNew := not (LOld and aArg);
	movq	%r13,%rax
	andq	%r12,%rax
	notq	%rax
	movq	%rax,%r14
# [3062] if InterlockedCompareExchange64(aObj, LNew, LOld) = LOld then
	movq	%rbx,%rdi
	movq	%r13,%rdx
	movq	%r14,%rsi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	cmpq	%r13,%rax
	je	.Lj890
# [3065] cpu_pause;
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
# [3066] until False;
	jmp	.Lj888
.Lj890:
# Var $result located in register rax
# [3067] Result := LOld;
	movq	%r13,%rax
# Var LOld located in register rax
# [3076] end;
	popq	%rcx
	popq	%r14
.Lc923:
	popq	%r13
.Lc924:
	popq	%r12
.Lc925:
	popq	%rbx
.Lc926:
	ret
.Lc916:

.section .text.n_nextpas.core.atomic_$$_atomic_fetch_nand_64$int64$int64$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_NAND_64$INT64$INT64$$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_NAND_64$INT64$INT64$$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FETCH_NAND_64$INT64$INT64$$INT64:
.Lc928:
# [3079] begin
	pushq	%rbx
.Lc929:
	pushq	%r12
.Lc930:
	pushq	%r13
.Lc931:
	pushq	%r14
.Lc932:
	pushq	%rax
.Lc933:
	movq	%rdi,%rbx
# Var aObj located in register rbx
	movq	%rsi,%r12
# Var aArg located in register r12
	.p2align 4,,10
	.p2align 3
.Lj897:
# [3080] Result := atomic_fetch_nand_64(aObj, aArg, mo_seq_cst);
	movq	(%rbx),%r13
	movq	%r13,%rax
	andq	%r12,%rax
	notq	%rax
	movq	%rax,%r14
	movq	%rbx,%rdi
	movq	%r13,%rdx
	movq	%r14,%rsi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	cmpq	%r13,%rax
	je	.Lj899
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
	jmp	.Lj897
.Lj899:
	movq	%r13,%rax
# Var $result located in register rax
# [3081] end;
	popq	%rcx
	popq	%r14
.Lc934:
	popq	%r13
.Lc935:
	popq	%r12
.Lc936:
	popq	%rbx
.Lc937:
	ret
.Lc927:

.section .text.n_nextpas.core.atomic_$$_atomic_flag_test_and_set$atomic_flag_t$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FLAG_TEST_AND_SET$ATOMIC_FLAG_T$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FLAG_TEST_AND_SET$ATOMIC_FLAG_T$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FLAG_TEST_AND_SET$ATOMIC_FLAG_T$$BOOLEAN:
.Lc939:
# [3085] begin
	pushq	%rax
.Lc940:
# Var aFlag located in register rdi
# [3087] Result := (atomic_exchange(PInt32(@aFlag)^, 1, mo_seq_cst) <> 0);
	movl	$1,%esi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE$LONGINT$LONGINT$$LONGINT
	testl	%eax,%eax
# Var $result located in register al
	setneb	%al
# [3088] end;
	popq	%rcx
.Lc941:
	ret
.Lc938:

.section .text.n_nextpas.core.atomic_$$_atomic_flag_test$atomic_flag_t$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FLAG_TEST$ATOMIC_FLAG_T$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FLAG_TEST$ATOMIC_FLAG_T$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FLAG_TEST$ATOMIC_FLAG_T$$BOOLEAN:
.Lc943:
# Var aFlag located in register rdi
# [3091] begin
# [3093] Result := atomic_load(PInt32(@aFlag)^, mo_relaxed) <> 0;
	cmpl	$0,(%rdi)
# Var $result located in register al
	setneb	%al
.Lc944:
# [3097] end;
	ret
.Lc942:

.section .text.n_nextpas.core.atomic_$$_atomic_flag_clear$atomic_flag_t,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FLAG_CLEAR$ATOMIC_FLAG_T
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FLAG_CLEAR$ATOMIC_FLAG_T,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FLAG_CLEAR$ATOMIC_FLAG_T:
.Lc946:
# [3100] begin
	pushq	%rax
.Lc947:
# Var aFlag located in register rdi
# [3102] atomic_store(PInt32(@aFlag)^, 0, mo_seq_cst);
	xorl	%esi,%esi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE$LONGINT$LONGINT$$LONGINT
# [3103] end;
	popq	%rcx
.Lc948:
	ret
.Lc945:

.section .text.n_nextpas.core.atomic_$$_atomic_is_lock_free_32$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_IS_LOCK_FREE_32$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_IS_LOCK_FREE_32$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_IS_LOCK_FREE_32$$BOOLEAN:
.Lc950:
# [3106] begin
# Var $result located in register al
# [3113] Result := True;
	movb	$1,%al
.Lc951:
# [3118] end;
	ret
.Lc949:

.section .text.n_nextpas.core.atomic_$$_atomic_is_lock_free_64$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_IS_LOCK_FREE_64$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_IS_LOCK_FREE_64$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_IS_LOCK_FREE_64$$BOOLEAN:
.Lc953:
# [3122] begin
# Var $result located in register al
# [3128] Result := True;
	movb	$1,%al
.Lc954:
# [3132] end;
	ret
.Lc952:

.section .text.n_nextpas.core.atomic_$$_atomic_is_lock_free_ptr$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_IS_LOCK_FREE_PTR$$BOOLEAN
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_IS_LOCK_FREE_PTR$$BOOLEAN,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_IS_LOCK_FREE_PTR$$BOOLEAN:
.Lc956:
# [3136] begin
# Var $result located in register al
# [3140] Result := atomic_is_lock_free_64;
	movb	$1,%al
.Lc957:
# [3142] end;
	ret
.Lc955:

.section .text.n_nextpas.core.atomic_$$_atomic_tagged_ptr$pointer$word$$atomic_tagged_ptr_t,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR$POINTER$WORD$$ATOMIC_TAGGED_PTR_T
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR$POINTER$WORD$$ATOMIC_TAGGED_PTR_T,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR$POINTER$WORD$$ATOMIC_TAGGED_PTR_T:
.Lc959:
# Var aPtr located in register rdi
# Var aTag located in register si
# [3145] begin
# [3146] Result := nextpas.core.atomic.core.atomic_tagged_ptr(aPtr, aTag);
	movq	TC_$NEXTPAS.CORE.ATOMIC.CORE_$$_PTR_MASK,%rax
	andq	%rdi,%rax
	movzwl	%si,%esi
	shlq	$48,%rsi
	orq	%rsi,%rax
# Var $result located in register rax
.Lc960:
# [3147] end;
	ret
.Lc958:

.section .text.n_nextpas.core.atomic_$$_atomic_tagged_ptr_get_ptr$atomic_tagged_ptr_t$$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_GET_PTR$ATOMIC_TAGGED_PTR_T$$POINTER
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_GET_PTR$ATOMIC_TAGGED_PTR_T$$POINTER,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_GET_PTR$ATOMIC_TAGGED_PTR_T$$POINTER:
.Lc962:
# Var aTaggedPtr located in register rdi
# [3150] begin
# [3151] Result := nextpas.core.atomic.core.atomic_tagged_ptr_get_ptr(aTaggedPtr);
	movq	TC_$NEXTPAS.CORE.ATOMIC.CORE_$$_PTR_MASK,%rax
	andq	%rdi,%rax
# Var $result located in register rax
.Lc963:
# [3152] end;
	ret
.Lc961:

.section .text.n_nextpas.core.atomic_$$_atomic_tagged_ptr_get_tag$atomic_tagged_ptr_t$$word,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_GET_TAG$ATOMIC_TAGGED_PTR_T$$WORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_GET_TAG$ATOMIC_TAGGED_PTR_T$$WORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_GET_TAG$ATOMIC_TAGGED_PTR_T$$WORD:
.Lc965:
# [3155] begin
	movq	%rdi,%rax
# Var aTaggedPtr located in register rax
# [3156] Result := nextpas.core.atomic.core.atomic_tagged_ptr_get_tag(aTaggedPtr);
	shrq	$48,%rax
# Var $result located in register ax
.Lc966:
# [3157] end;
	ret
.Lc964:

.section .text.n_nextpas.core.atomic_$$_atomic_tagged_ptr_load$hkuleewgsbgo,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_LOAD$hkuLEewGsBGO
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_LOAD$hkuLEewGsBGO,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_LOAD$hkuLEewGsBGO:
.Lc968:
# [3160] begin
	pushq	%rbx
.Lc969:
	pushq	%r12
.Lc970:
	pushq	%rax
.Lc971:
# Var $result located at rsp+0, size=OS_64
	movq	%rdi,%rbx
# Var aObj located in register rbx
# Var aOrder located in register esi
# [3166] PInt64(@Result)^ := atomic_load_64(PInt64(@aObj)^, aOrder);
	movq	(%rdi),%r12
	testl	%esi,%esi
	je	.Lj927
	subl	$1,%esi
	jb	.Lj926
	subl	$1,%esi
	jbe	.Lj928
	subl	$1,%esi
	je	.Lj929
	subl	$1,%esi
	je	.Lj928
	subl	$1,%esi
	je	.Lj930
	jmp	.Lj926
	.balign 16,0x90
.Lj927:
	movq	(%rbx),%r12
	jmp	.Lj926
	.balign 16,0x90
.Lj928:
	movq	(%rbx),%r12
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	jmp	.Lj926
	.balign 16,0x90
.Lj929:
	movq	(%rbx),%r12
	jmp	.Lj926
	.balign 16,0x90
.Lj930:
	movq	(%rbx),%r12
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	.balign 16,0x90
.Lj926:
	movq	%r12,(%rsp)
# [3169] end;
	movq	(%rsp),%rax
	popq	%rcx
	popq	%r12
.Lc972:
	popq	%rbx
.Lc973:
	ret
.Lc967:

.section .text.n_nextpas.core.atomic_$$_atomic_tagged_ptr_load$atomic_tagged_ptr_t$$atomic_tagged_ptr_t,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_LOAD$ATOMIC_TAGGED_PTR_T$$ATOMIC_TAGGED_PTR_T
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_LOAD$ATOMIC_TAGGED_PTR_T$$ATOMIC_TAGGED_PTR_T,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_LOAD$ATOMIC_TAGGED_PTR_T$$ATOMIC_TAGGED_PTR_T:
.Lc975:
# Temps allocated between rsp+0 and rsp+8
# [3172] begin
	pushq	%rax
.Lc976:
# Var aObj located in register rdi
# [3174] Result := atomic_tagged_ptr_load(aObj, mo_relaxed);
	movq	(%rdi),%rax
	movq	%rax,(%rsp)
# Var $result located in register rax
# [3178] end;
	popq	%rcx
.Lc977:
	ret
.Lc974:

.section .text.n_nextpas.core.atomic_$$_atomic_tagged_ptr_store$hw5f1griy_$l,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_STORE$hW5F1GRIy_$L
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_STORE$hW5F1GRIy_$L,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_STORE$hW5F1GRIy_$L:
.Lc979:
# [3181] begin
	pushq	%rbx
.Lc980:
	pushq	%r12
.Lc981:
	pushq	%rax
.Lc982:
# Var aDesired located at rsp+0, size=OS_64
	movq	%rdi,%rbx
# Var aObj located in register rbx
	movq	%rsi,(%rsp)
# Var aOrder located in register edx
# [3187] atomic_store_64(PInt64(@aObj)^, PInt64(@aDesired)^, aOrder);
	movq	(%rsp),%r12
	subl	$2,%edx
	jbe	.Lj937
	subl	$1,%edx
	subl	$1,%edx
	jbe	.Lj938
	subl	$1,%edx
	je	.Lj939
	jmp	.Lj936
	.balign 16,0x90
.Lj937:
	movq	%r12,(%rbx)
	jmp	.Lj936
	.balign 16,0x90
.Lj938:
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	movq	%r12,(%rbx)
	jmp	.Lj936
	.balign 16,0x90
.Lj939:
	movq	%rbx,%rdi
	movq	%r12,%rsi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE64$INT64$INT64$$INT64
	.balign 16,0x90
.Lj936:
# [3190] end;
	popq	%rcx
	popq	%r12
.Lc983:
	popq	%rbx
.Lc984:
	ret
.Lc978:

.section .text.n_nextpas.core.atomic_$$_atomic_tagged_ptr_store$atomic_tagged_ptr_t$atomic_tagged_ptr_t,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_STORE$ATOMIC_TAGGED_PTR_T$ATOMIC_TAGGED_PTR_T
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_STORE$ATOMIC_TAGGED_PTR_T$ATOMIC_TAGGED_PTR_T,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_STORE$ATOMIC_TAGGED_PTR_T$ATOMIC_TAGGED_PTR_T:
.Lc986:
# Temps allocated between rsp+0 and rsp+8
# [3193] begin
	pushq	%rax
.Lc987:
# Var aObj located in register rdi
# Var aDesired located in register rsi
# Var aDesired located in register rsi
# [3195] atomic_tagged_ptr_store(aObj, aDesired, mo_relaxed);
	movq	%rsi,(%rsp)
	movq	(%rsp),%rax
	movq	%rax,(%rdi)
# [3199] end;
	popq	%rcx
.Lc988:
	ret
.Lc985:

.section .text.n_nextpas.core.atomic_$$_atomic_tagged_ptr_exchange$hgddxwukap6a,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_EXCHANGE$hGDDxwuKAp6A
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_EXCHANGE$hGDDxwuKAp6A,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_EXCHANGE$hGDDxwuKAp6A:
.Lc990:
# [3202] begin
	pushq	%rbx
.Lc991:
	leaq	-16(%rsp),%rsp
.Lc992:
# Var aDesired located at rsp+0, size=OS_64
# Var $result located at rsp+8, size=OS_64
# Var aObj located in register rdi
	movq	%rsi,(%rsp)
# Var aOrder located in register edx
# [3208] PInt64(@Result)^ := atomic_exchange_64(PInt64(@aObj)^, PInt64(@aDesired)^, aOrder);
	leaq	8(%rsp),%rbx
	movq	(%rsp),%rsi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE64$INT64$INT64$$INT64
	movq	%rax,(%rbx)
# [3211] end;
	movq	8(%rsp),%rax
	leaq	16(%rsp),%rsp
	popq	%rbx
.Lc993:
	ret
.Lc989:

.section .text.n_nextpas.core.atomic_$$_atomic_tagged_ptr_exchange$hbyvgafvnkwl,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_EXCHANGE$hbyVgAfvNKWL
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_EXCHANGE$hbyVgAfvNKWL,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_EXCHANGE$hbyVgAfvNKWL:
.Lc995:
# Temps allocated between rsp+0 and rsp+16
# [3214] begin
	leaq	-24(%rsp),%rsp
.Lc996:
# Var aObj located in register rdi
# Var aDesired located in register rsi
# Var aDesired located in register rsi
# [3216] Result := atomic_tagged_ptr_exchange(aObj, aDesired, mo_seq_cst);
	movq	%rsi,8(%rsp)
	movq	8(%rsp),%rsi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE64$INT64$INT64$$INT64
	movq	%rax,(%rsp)
# Var $result located in register rax
	movq	(%rsp),%rax
# [3217] end;
	leaq	24(%rsp),%rsp
.Lc997:
	ret
.Lc994:

.section .text.n_nextpas.core.atomic_$$_atomic_tagged_ptr_compare_exchange_strong$hlghs$8dhusa,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_COMPARE_EXCHANGE_STRONG$hlGHS$8dHUSA
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_COMPARE_EXCHANGE_STRONG$hlGHS$8dHUSA,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_COMPARE_EXCHANGE_STRONG$hlGHS$8dHUSA:
.Lc999:
# [3227] begin
	pushq	%rbx
.Lc1000:
	leaq	-16(%rsp),%rsp
.Lc1001:
# Var aDesired located at rsp+0, size=OS_64
# Var LExpected64 located at rsp+8, size=OS_S64
# Var aObj located in register rdi
	movq	%rsi,%rbx
# Var aExpected located in register rbx
	movq	%rdx,(%rsp)
# Var aSuccessOrder located in register ecx
# Var aFailureOrder located in register r8d
# [3235] LExpected64 := PInt64(@aExpected)^;
	movq	(%rsi),%rax
	movq	%rax,8(%rsp)
# [3236] Result := atomic_compare_exchange_strong_64(PInt64(@aObj)^, LExpected64, PInt64(@aDesired)^, aSuccessOrder, aFailureOrder);
	movq	(%rsp),%rsi
	movq	8(%rsp),%rdx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	movq	%rax,%rdx
	cmpq	8(%rsp),%rax
	seteb	%al
	je	.Lj953
	movq	%rdx,8(%rsp)
	.p2align 4,,10
	.p2align 3
.Lj953:
# Var $result located in register al
# [3237] PInt64(@aExpected)^ := LExpected64;
	movq	8(%rsp),%rdx
	movq	%rdx,(%rbx)
# [3240] end;
	leaq	16(%rsp),%rsp
	popq	%rbx
.Lc1002:
	ret
.Lc998:

.section .text.n_nextpas.core.atomic_$$_atomic_tagged_ptr_compare_exchange_strong$hjvkkf5bj_go,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_COMPARE_EXCHANGE_STRONG$hJVKKf5Bj_GO
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_COMPARE_EXCHANGE_STRONG$hJVKKf5Bj_GO,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_COMPARE_EXCHANGE_STRONG$hJVKKf5Bj_GO:
.Lc1004:
# Temps allocated between rsp+0 and rsp+16
# [3243] begin
	pushq	%rbx
.Lc1005:
	leaq	-16(%rsp),%rsp
.Lc1006:
# Var aObj located in register rdi
	movq	%rsi,%rbx
# Var aExpected located in register rbx
# Var aDesired located in register rdx
# [3245] Result := atomic_tagged_ptr_compare_exchange_strong(aObj, aExpected, aDesired, mo_seq_cst, mo_seq_cst);
	movq	%rdx,(%rsp)
	movq	(%rsi),%rax
	movq	%rax,8(%rsp)
	movq	(%rsp),%rsi
	movq	8(%rsp),%rdx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	movq	%rax,%rdx
	cmpq	8(%rsp),%rax
	seteb	%al
	je	.Lj964
	movq	%rdx,8(%rsp)
	.p2align 4,,10
	.p2align 3
.Lj964:
	movq	8(%rsp),%rdx
	movq	%rdx,(%rbx)
# Var $result located in register al
# [3246] end;
	leaq	16(%rsp),%rsp
	popq	%rbx
.Lc1007:
	ret
.Lc1003:

.section .text.n_nextpas.core.atomic_$$_atomic_tagged_ptr_compare_exchange_weak$hlghs$8dhusa,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_COMPARE_EXCHANGE_WEAK$hlGHS$8dHUSA
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_COMPARE_EXCHANGE_WEAK$hlGHS$8dHUSA,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_COMPARE_EXCHANGE_WEAK$hlGHS$8dHUSA:
.Lc1009:
# [3256] begin
	pushq	%rbx
.Lc1010:
	leaq	-16(%rsp),%rsp
.Lc1011:
# Var aDesired located at rsp+0, size=OS_64
# Var LExpected64 located at rsp+8, size=OS_S64
# Var aObj located in register rdi
	movq	%rsi,%rbx
# Var aExpected located in register rbx
	movq	%rdx,(%rsp)
# Var aSuccessOrder located in register ecx
# Var aFailureOrder located in register r8d
# [3264] LExpected64 := PInt64(@aExpected)^;
	movq	(%rsi),%rax
	movq	%rax,8(%rsp)
# [3265] Result := atomic_compare_exchange_weak_64(PInt64(@aObj)^, LExpected64, PInt64(@aDesired)^, aSuccessOrder, aFailureOrder);
	movq	(%rsp),%rsi
	movq	8(%rsp),%rdx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	movq	%rax,%rdx
	cmpq	8(%rsp),%rax
	seteb	%al
	je	.Lj972
	movq	%rdx,8(%rsp)
	.p2align 4,,10
	.p2align 3
.Lj972:
# Var $result located in register al
# [3266] PInt64(@aExpected)^ := LExpected64;
	movq	8(%rsp),%rdx
	movq	%rdx,(%rbx)
# [3269] end;
	leaq	16(%rsp),%rsp
	popq	%rbx
.Lc1012:
	ret
.Lc1008:

.section .text.n_nextpas.core.atomic_$$_atomic_tagged_ptr_compare_exchange_weak$hjvkkf5bj_go,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_COMPARE_EXCHANGE_WEAK$hJVKKf5Bj_GO
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_COMPARE_EXCHANGE_WEAK$hJVKKf5Bj_GO,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_COMPARE_EXCHANGE_WEAK$hJVKKf5Bj_GO:
.Lc1014:
# Temps allocated between rsp+0 and rsp+16
# [3272] begin
	pushq	%rbx
.Lc1015:
	leaq	-16(%rsp),%rsp
.Lc1016:
# Var aObj located in register rdi
	movq	%rsi,%rbx
# Var aExpected located in register rbx
# Var aDesired located in register rdx
# [3274] Result := atomic_tagged_ptr_compare_exchange_weak(aObj, aExpected, aDesired, mo_seq_cst, mo_seq_cst);
	movq	%rdx,(%rsp)
	movq	(%rsi),%rax
	movq	%rax,8(%rsp)
	movq	(%rsp),%rsi
	movq	8(%rsp),%rdx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	movq	%rax,%rdx
	cmpq	8(%rsp),%rax
	seteb	%al
	je	.Lj983
	movq	%rdx,8(%rsp)
	.p2align 4,,10
	.p2align 3
.Lj983:
	movq	8(%rsp),%rdx
	movq	%rdx,(%rbx)
# Var $result located in register al
# [3275] end;
	leaq	16(%rsp),%rsp
	popq	%rbx
.Lc1017:
	ret
.Lc1013:

.section .text.n_nextpas.core.atomic_$$_atomic_thread_fence$memory_order_t,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_THREAD_FENCE$MEMORY_ORDER_T
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_THREAD_FENCE$MEMORY_ORDER_T,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_THREAD_FENCE$MEMORY_ORDER_T:
.Lc1019:
# [3278] begin
	pushq	%rax
.Lc1020:
# Var aOrder located in register edi
# Var aOrder located in register edi
# [3279] nextpas.core.atomic.core.atomic_thread_fence(aOrder);
	call	NEXTPAS.CORE.ATOMIC.CORE_$$_ATOMIC_THREAD_FENCE$MEMORY_ORDER_T
# [3280] end;
	popq	%rcx
.Lc1021:
	ret
.Lc1018:
.Le18:
	.size	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_THREAD_FENCE$MEMORY_ORDER_T, .Le18 - NEXTPAS.CORE.ATOMIC_$$_ATOMIC_THREAD_FENCE$MEMORY_ORDER_T

.section .text.n_nextpas.core.atomic_$$_atomic_signal_fence$memory_order_t,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_SIGNAL_FENCE$MEMORY_ORDER_T
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_SIGNAL_FENCE$MEMORY_ORDER_T,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_SIGNAL_FENCE$MEMORY_ORDER_T:
.Lc1023:
# [3283] begin
	pushq	%rax
.Lc1024:
# Var aOrder located in register edi
# Var aOrder located in register edi
# [3284] nextpas.core.atomic.core.atomic_signal_fence(aOrder);
	call	NEXTPAS.CORE.ATOMIC.CORE_$$_ATOMIC_SIGNAL_FENCE$MEMORY_ORDER_T
# [3285] end;
	popq	%rcx
.Lc1025:
	ret
.Lc1022:
.Le19:
	.size	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_SIGNAL_FENCE$MEMORY_ORDER_T, .Le19 - NEXTPAS.CORE.ATOMIC_$$_ATOMIC_SIGNAL_FENCE$MEMORY_ORDER_T

.section .text.n_nextpas.core.atomic_$$_atomic_tagged_ptr_next$atomic_tagged_ptr_t$$word,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_NEXT$ATOMIC_TAGGED_PTR_T$$WORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_NEXT$ATOMIC_TAGGED_PTR_T$$WORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_NEXT$ATOMIC_TAGGED_PTR_T$$WORD:
.Lc1027:
# Var aTaggedPtr located in register rdi
# [3288] begin
# [3289] Result := nextpas.core.atomic.core.atomic_tagged_ptr_next(aTaggedPtr);
	shrq	$48,%rdi
	movw	$1,%cx
	cmpw	TC_$NEXTPAS.CORE.ATOMIC.CORE_$$_MAX_TAG,%di
	cmovew	%cx,%ax
	je	.Lj998
	movzwl	%di,%edi
	leal	1(%rdi),%edx
	movw	%dx,%ax
.Lj998:
# Var $result located in register ax
.Lc1028:
# [3290] end;
	ret
.Lc1026:

.section .text.n_nextpas.core.atomic_$$_atomic_tagged_ptr_update$atomic_tagged_ptr_t$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_UPDATE$ATOMIC_TAGGED_PTR_T$POINTER
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_UPDATE$ATOMIC_TAGGED_PTR_T$POINTER,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_UPDATE$ATOMIC_TAGGED_PTR_T$POINTER:
.Lc1030:
# Temps allocated between rsp+8 and rsp+24
# [3295] begin
	pushq	%rbx
.Lc1031:
	pushq	%r12
.Lc1032:
	pushq	%r13
.Lc1033:
	leaq	-32(%rsp),%rsp
.Lc1034:
# Var LOld located at rsp+0, size=OS_64
# Var LNewV located in register r13
	movq	%rdi,%rbx
# Var aObj located in register rbx
	movq	%rsi,%r12
# Var aPtr located in register r12
	.p2align 4,,10
	.p2align 3
.Lj1001:
# [3297] LOld  := atomic_tagged_ptr_load(aObj);
	movq	(%rbx),%rax
	movq	%rax,8(%rsp)
	movq	%rax,(%rsp)
# [3298] LNewV := atomic_tagged_ptr(aPtr, atomic_tagged_ptr_next(LOld));
	shrq	$48,%rax
	movw	$1,%cx
	cmpw	TC_$NEXTPAS.CORE.ATOMIC.CORE_$$_MAX_TAG,%ax
	cmovew	%cx,%dx
	je	.Lj1008
	movzwl	%ax,%eax
	addl	$1,%eax
	movw	%ax,%dx
.Lj1008:
	movq	TC_$NEXTPAS.CORE.ATOMIC.CORE_$$_PTR_MASK,%rax
	andq	%r12,%rax
	movzwl	%dx,%edx
	shlq	$48,%rdx
	orq	%rdx,%rax
	movq	%rax,%r13
# [3299] if atomic_tagged_ptr_compare_exchange_weak(aObj, LOld, LNewV) then
	movq	%rax,8(%rsp)
	movq	(%rsp),%rax
	movq	%rax,16(%rsp)
	movq	8(%rsp),%rsi
	movq	%rbx,%rdi
	movq	16(%rsp),%rdx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	cmpq	16(%rsp),%rax
	seteb	%dl
	je	.Lj1010
	movq	%rax,16(%rsp)
	.p2align 4,,10
	.p2align 3
.Lj1010:
	movq	16(%rsp),%rax
	movq	%rax,(%rsp)
	testb	%dl,%dl
	jne	.Lj1003
# [3301] cpu_pause;
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
# [3302] until False;
	jmp	.Lj1001
.Lj1003:
# [3303] end;
	leaq	32(%rsp),%rsp
	popq	%r13
.Lc1035:
	popq	%r12
.Lc1036:
	popq	%rbx
.Lc1037:
	ret
.Lc1029:

.section .text.n_nextpas.core.atomic_$$_atomic_tagged_ptr_update_tag$atomic_tagged_ptr_t$word,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_UPDATE_TAG$ATOMIC_TAGGED_PTR_T$WORD
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_UPDATE_TAG$ATOMIC_TAGGED_PTR_T$WORD,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMIC_TAGGED_PTR_UPDATE_TAG$ATOMIC_TAGGED_PTR_T$WORD:
.Lc1039:
# Temps allocated between rsp+8 and rsp+24
# [3310] begin
	pushq	%rbx
.Lc1040:
	pushq	%r12
.Lc1041:
	pushq	%r13
.Lc1042:
	pushq	%r14
.Lc1043:
	leaq	-24(%rsp),%rsp
.Lc1044:
# Var LOldTagged located at rsp+0, size=OS_64
# Var LNewTagged located in register r14
# Var LOldPtr located in register r13
	movq	%rdi,%rbx
# Var aObj located in register rbx
	movw	%si,%r12w
# Var aTag located in register r12w
	.p2align 4,,10
	.p2align 3
.Lj1020:
# [3312] LOldTagged := atomic_tagged_ptr_load(aObj);
	movq	(%rbx),%rdx
	movq	%rdx,8(%rsp)
	movq	%rdx,(%rsp)
# [3313] LOldPtr    := atomic_tagged_ptr_get_ptr(LOldTagged);
	movq	TC_$NEXTPAS.CORE.ATOMIC.CORE_$$_PTR_MASK,%r13
	andq	%rdx,%r13
# [3314] LNewTagged := atomic_tagged_ptr(LOldPtr, aTag);
	movq	TC_$NEXTPAS.CORE.ATOMIC.CORE_$$_PTR_MASK,%rdx
	andq	%r13,%rdx
	movzwl	%r12w,%eax
	shlq	$48,%rax
	orq	%rax,%rdx
	movq	%rdx,%r14
# [3315] if atomic_tagged_ptr_compare_exchange_strong(aObj, LOldTagged, LNewTagged) then
	movq	%rdx,8(%rsp)
	movq	(%rsp),%rax
	movq	%rax,16(%rsp)
	movq	8(%rsp),%rsi
	movq	%rbx,%rdi
	movq	16(%rsp),%rdx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	cmpq	16(%rsp),%rax
	seteb	%dl
	je	.Lj1025
	movq	%rax,16(%rsp)
	.p2align 4,,10
	.p2align 3
.Lj1025:
	movq	16(%rsp),%rcx
	movq	%rcx,(%rsp)
	testb	%dl,%dl
	jne	.Lj1022
# [3317] cpu_pause;
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
# [3318] until False;
	jmp	.Lj1020
.Lj1022:
# [3319] end;
	leaq	24(%rsp),%rsp
	popq	%r14
.Lc1045:
	popq	%r13
.Lc1046:
	popq	%r12
.Lc1047:
	popq	%rbx
.Lc1048:
	ret
.Lc1038:

.section .text.n_nextpas.core.atomic_$$_atomiccompatfailureorder$memory_order_t$$memory_order_t,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMICCOMPATFAILUREORDER$MEMORY_ORDER_T$$MEMORY_ORDER_T
	.hidden NEXTPAS.CORE.ATOMIC_$$_ATOMICCOMPATFAILUREORDER$MEMORY_ORDER_T$$MEMORY_ORDER_T
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMICCOMPATFAILUREORDER$MEMORY_ORDER_T$$MEMORY_ORDER_T,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMICCOMPATFAILUREORDER$MEMORY_ORDER_T$$MEMORY_ORDER_T:
.Lc1050:
# Var $result located in register eax
# Var AOrder located in register edi
# [3322] begin
# [3323] case AOrder of
	testl	%edi,%edi
	je	.Lj1037
	subl	$2,%edi
	je	.Lj1038
	subl	$1,%edi
	je	.Lj1039
	subl	$1,%edi
	je	.Lj1040
	subl	$1,%edi
	je	.Lj1041
	jmp	.Lj1036
	.balign 16,0x90
.Lj1037:
# [3325] Result := mo_relaxed;
	xorl	%eax,%eax
	ret
	.balign 16,0x90
.Lj1038:
# [3327] Result := mo_acquire;
	movl	$2,%eax
	ret
	.balign 16,0x90
.Lj1039:
# [3329] Result := mo_relaxed;
	xorl	%eax,%eax
	ret
	.balign 16,0x90
.Lj1040:
# [3331] Result := mo_acquire;
	movl	$2,%eax
	ret
	.balign 16,0x90
.Lj1041:
# [3333] Result := mo_seq_cst;
	movl	$5,%eax
	ret
	.balign 16,0x90
.Lj1036:
# [3335] Result := mo_relaxed;
	xorl	%eax,%eax
.Lc1051:
# [3337] end;
	ret
.Lc1049:

.section .text.n_nextpas.core.atomic_$$_cpupause,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_CPUPAUSE
	.type	NEXTPAS.CORE.ATOMIC_$$_CPUPAUSE,@function
NEXTPAS.CORE.ATOMIC_$$_CPUPAUSE:
.Lc1053:
# [3340] begin
	pushq	%rax
.Lc1054:
# [3341] cpu_pause;
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
# [3342] end;
	popq	%rcx
.Lc1055:
	ret
.Lc1052:

.section .text.n_nextpas.core.atomic_$$_atomicload32$longint$memory_order_t$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMICLOAD32$LONGINT$MEMORY_ORDER_T$$LONGINT
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMICLOAD32$LONGINT$MEMORY_ORDER_T$$LONGINT,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMICLOAD32$LONGINT$MEMORY_ORDER_T$$LONGINT:
.Lc1057:
# [3345] begin
	pushq	%rbx
.Lc1058:
	pushq	%r12
.Lc1059:
	pushq	%rax
.Lc1060:
	movq	%rdi,%rbx
# Var ATarget located in register rbx
# Var AOrder located in register esi
# [3346] Result := atomic_load(ATarget, AOrder);
	movl	(%rdi),%r12d
	testl	%esi,%esi
	je	.Lj1048
	subl	$1,%esi
	jb	.Lj1047
	subl	$1,%esi
	jbe	.Lj1049
	subl	$1,%esi
	je	.Lj1050
	subl	$1,%esi
	je	.Lj1049
	subl	$1,%esi
	je	.Lj1051
	jmp	.Lj1047
	.balign 16,0x90
.Lj1048:
	movl	(%rbx),%r12d
	jmp	.Lj1047
	.balign 16,0x90
.Lj1049:
	movl	(%rbx),%r12d
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	jmp	.Lj1047
	.balign 16,0x90
.Lj1050:
	movl	(%rbx),%r12d
	jmp	.Lj1047
	.balign 16,0x90
.Lj1051:
	movl	(%rbx),%r12d
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	.balign 16,0x90
.Lj1047:
# Var $result located in register eax
	movl	%r12d,%eax
# [3347] end;
	popq	%rcx
	popq	%r12
.Lc1061:
	popq	%rbx
.Lc1062:
	ret
.Lc1056:

.section .text.n_nextpas.core.atomic_$$_atomicstore32$longint$longint$memory_order_t,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMICSTORE32$LONGINT$LONGINT$MEMORY_ORDER_T
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMICSTORE32$LONGINT$LONGINT$MEMORY_ORDER_T,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMICSTORE32$LONGINT$LONGINT$MEMORY_ORDER_T:
.Lc1064:
# [3350] begin
	pushq	%rbx
.Lc1065:
	pushq	%r12
.Lc1066:
	pushq	%rax
.Lc1067:
	movq	%rdi,%rbx
# Var ATarget located in register rbx
	movl	%esi,%r12d
# Var AValue located in register r12d
# Var AOrder located in register edx
# [3351] atomic_store(ATarget, AValue, AOrder);
	subl	$2,%edx
	jbe	.Lj1055
	subl	$1,%edx
	subl	$1,%edx
	jbe	.Lj1056
	subl	$1,%edx
	je	.Lj1057
	jmp	.Lj1054
	.balign 16,0x90
.Lj1055:
	movl	%r12d,(%rbx)
	jmp	.Lj1054
	.balign 16,0x90
.Lj1056:
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	movl	%r12d,(%rbx)
	jmp	.Lj1054
	.balign 16,0x90
.Lj1057:
	movq	%rbx,%rdi
	movl	%r12d,%esi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE$LONGINT$LONGINT$$LONGINT
	.balign 16,0x90
.Lj1054:
# [3352] end;
	popq	%rcx
	popq	%r12
.Lc1068:
	popq	%rbx
.Lc1069:
	ret
.Lc1063:

.section .text.n_nextpas.core.atomic_$$_atomicexchange32$longint$longint$memory_order_t$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMICEXCHANGE32$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMICEXCHANGE32$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMICEXCHANGE32$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT:
.Lc1071:
# [3355] begin
	pushq	%rax
.Lc1072:
# Var ATarget located in register rdi
# Var AValue located in register esi
# Var AOrder located in register edx
# [3356] Result := atomic_exchange(ATarget, AValue, AOrder);
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE$LONGINT$LONGINT$$LONGINT
# Var $result located in register eax
# [3357] end;
	popq	%rcx
.Lc1073:
	ret
.Lc1070:

.section .text.n_nextpas.core.atomic_$$_atomiccompareexchange32$longint$longint$longint$memory_order_t$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMICCOMPAREEXCHANGE32$LONGINT$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMICCOMPAREEXCHANGE32$LONGINT$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMICCOMPAREEXCHANGE32$LONGINT$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT:
.Lc1075:
# [3362] begin
	pushq	%rax
.Lc1076:
# Var LExpected located at rsp+0, size=OS_S32
# Var ATarget located in register rdi
	movl	%esi,%eax
# Var AExpected located in register eax
	movl	%edx,%esi
# Var ADesired located in register esi
# Var AOrder located in register ecx
# Var AExpected located in register eax
# [3363] LExpected := AExpected;
	movl	%eax,(%rsp)
# [3364] atomic_compare_exchange_strong(ATarget, LExpected, ADesired, AOrder, AtomicCompatFailureOrder(AOrder));
	movl	%ecx,%eax
	testl	%ecx,%ecx
	je	.Lj1067
	subl	$2,%eax
	je	.Lj1068
	subl	$1,%eax
	je	.Lj1069
	subl	$1,%eax
	je	.Lj1070
	subl	$1,%eax
	je	.Lj1071
	jmp	.Lj1066
	.balign 16,0x90
.Lj1067:
	xorl	%eax,%eax
	jmp	.Lj1065
	.balign 16,0x90
.Lj1068:
	movl	$2,%eax
	jmp	.Lj1065
	.balign 16,0x90
.Lj1069:
	xorl	%eax,%eax
	jmp	.Lj1065
	.balign 16,0x90
.Lj1070:
	movl	$2,%eax
	jmp	.Lj1065
	.balign 16,0x90
.Lj1071:
	movl	$5,%eax
	jmp	.Lj1065
	.balign 16,0x90
.Lj1066:
	xorl	%eax,%eax
	.balign 16,0x90
.Lj1065:
	movl	(%rsp),%edx
# Var ADesired located in register esi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE$LONGINT$LONGINT$LONGINT$$LONGINT
	cmpl	(%rsp),%eax
	je	.Lj1080
	movl	%eax,(%rsp)
.Lj1080:
# Var $result located in register eax
# [3365] Result := LExpected;
	movl	(%rsp),%eax
# [3366] end;
	popq	%rcx
.Lc1077:
	ret
.Lc1074:

.section .text.n_nextpas.core.atomic_$$_atomicfetchadd32$longint$longint$memory_order_t$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMICFETCHADD32$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMICFETCHADD32$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMICFETCHADD32$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT:
.Lc1079:
# [3369] begin
	pushq	%rax
.Lc1080:
# Var ATarget located in register rdi
# Var AValue located in register esi
# Var AOrder located in register edx
# [3370] Result := atomic_fetch_add(ATarget, AValue, AOrder);
	call	SYSTEM_$$_INTERLOCKEDEXCHANGEADD$LONGINT$LONGINT$$LONGINT
# Var $result located in register eax
# [3371] end;
	popq	%rcx
.Lc1081:
	ret
.Lc1078:

.section .text.n_nextpas.core.atomic_$$_atomicfetchsub32$longint$longint$memory_order_t$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMICFETCHSUB32$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMICFETCHSUB32$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMICFETCHSUB32$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT:
.Lc1083:
# [3374] begin
	pushq	%rax
.Lc1084:
# Var ATarget located in register rdi
# Var AValue located in register esi
# Var AOrder located in register edx
# [3375] Result := atomic_fetch_sub(ATarget, AValue, AOrder);
	negl	%esi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGEADD$LONGINT$LONGINT$$LONGINT
# Var $result located in register eax
# [3376] end;
	popq	%rcx
.Lc1085:
	ret
.Lc1082:

.section .text.n_nextpas.core.atomic_$$_atomicfetchand32$longint$longint$memory_order_t$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMICFETCHAND32$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMICFETCHAND32$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMICFETCHAND32$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT:
.Lc1087:
# [3379] begin
	pushq	%rbx
.Lc1088:
	pushq	%r12
.Lc1089:
	pushq	%r13
.Lc1090:
	pushq	%r14
.Lc1091:
	pushq	%rax
.Lc1092:
	movq	%rdi,%rbx
# Var ATarget located in register rbx
	movl	%esi,%r12d
# Var AValue located in register r12d
# Var AOrder located in register edx
	.p2align 4,,10
	.p2align 3
.Lj1096:
# [3380] Result := atomic_fetch_and(ATarget, AValue, AOrder);
	movl	(%rbx),%r13d
	movl	%r13d,%r14d
	andl	%r12d,%r14d
	movq	%rbx,%rdi
	movl	%r13d,%edx
	movl	%r14d,%esi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE$LONGINT$LONGINT$LONGINT$$LONGINT
	cmpl	%r13d,%eax
	je	.Lj1098
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
	jmp	.Lj1096
.Lj1098:
	movl	%r13d,%eax
# Var $result located in register eax
# [3381] end;
	popq	%rcx
	popq	%r14
.Lc1093:
	popq	%r13
.Lc1094:
	popq	%r12
.Lc1095:
	popq	%rbx
.Lc1096:
	ret
.Lc1086:

.section .text.n_nextpas.core.atomic_$$_atomicfetchor32$longint$longint$memory_order_t$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMICFETCHOR32$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMICFETCHOR32$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMICFETCHOR32$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT:
.Lc1098:
# [3384] begin
	pushq	%rbx
.Lc1099:
	pushq	%r12
.Lc1100:
	pushq	%r13
.Lc1101:
	pushq	%r14
.Lc1102:
	pushq	%rax
.Lc1103:
	movq	%rdi,%rbx
# Var ATarget located in register rbx
	movl	%esi,%r12d
# Var AValue located in register r12d
# Var AOrder located in register edx
	.p2align 4,,10
	.p2align 3
.Lj1106:
# [3385] Result := atomic_fetch_or(ATarget, AValue, AOrder);
	movl	(%rbx),%r13d
	movl	%r13d,%r14d
	orl	%r12d,%r14d
	movq	%rbx,%rdi
	movl	%r13d,%edx
	movl	%r14d,%esi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE$LONGINT$LONGINT$LONGINT$$LONGINT
	cmpl	%r13d,%eax
	je	.Lj1108
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
	jmp	.Lj1106
.Lj1108:
	movl	%r13d,%eax
# Var $result located in register eax
# [3386] end;
	popq	%rcx
	popq	%r14
.Lc1104:
	popq	%r13
.Lc1105:
	popq	%r12
.Lc1106:
	popq	%rbx
.Lc1107:
	ret
.Lc1097:

.section .text.n_nextpas.core.atomic_$$_atomicfetchxor32$longint$longint$memory_order_t$$longint,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMICFETCHXOR32$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMICFETCHXOR32$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMICFETCHXOR32$LONGINT$LONGINT$MEMORY_ORDER_T$$LONGINT:
.Lc1109:
# [3389] begin
	pushq	%rbx
.Lc1110:
	pushq	%r12
.Lc1111:
	pushq	%r13
.Lc1112:
	pushq	%r14
.Lc1113:
	pushq	%rax
.Lc1114:
	movq	%rdi,%rbx
# Var ATarget located in register rbx
	movl	%esi,%r12d
# Var AValue located in register r12d
# Var AOrder located in register edx
	.p2align 4,,10
	.p2align 3
.Lj1116:
# [3390] Result := atomic_fetch_xor(ATarget, AValue, AOrder);
	movl	(%rbx),%r13d
	movl	%r13d,%r14d
	xorl	%r12d,%r14d
	movq	%rbx,%rdi
	movl	%r13d,%edx
	movl	%r14d,%esi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE$LONGINT$LONGINT$LONGINT$$LONGINT
	cmpl	%r13d,%eax
	je	.Lj1118
	call	NEXTPAS.CORE.ATOMIC_$$_CPU_PAUSE
	jmp	.Lj1116
.Lj1118:
	movl	%r13d,%eax
# Var $result located in register eax
# [3391] end;
	popq	%rcx
	popq	%r14
.Lc1115:
	popq	%r13
.Lc1116:
	popq	%r12
.Lc1117:
	popq	%rbx
.Lc1118:
	ret
.Lc1108:

.section .text.n_nextpas.core.atomic_$$_atomicload64$int64$memory_order_t$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMICLOAD64$INT64$MEMORY_ORDER_T$$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMICLOAD64$INT64$MEMORY_ORDER_T$$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMICLOAD64$INT64$MEMORY_ORDER_T$$INT64:
.Lc1120:
# [3394] begin
	pushq	%rbx
.Lc1121:
	pushq	%r12
.Lc1122:
	pushq	%rax
.Lc1123:
	movq	%rdi,%rbx
# Var ATarget located in register rbx
# Var AOrder located in register esi
# [3395] Result := atomic_load_64(ATarget, AOrder);
	movq	(%rdi),%r12
	testl	%esi,%esi
	je	.Lj1125
	subl	$1,%esi
	jb	.Lj1124
	subl	$1,%esi
	jbe	.Lj1126
	subl	$1,%esi
	je	.Lj1127
	subl	$1,%esi
	je	.Lj1126
	subl	$1,%esi
	je	.Lj1128
	jmp	.Lj1124
	.balign 16,0x90
.Lj1125:
	movq	(%rbx),%r12
	jmp	.Lj1124
	.balign 16,0x90
.Lj1126:
	movq	(%rbx),%r12
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	jmp	.Lj1124
	.balign 16,0x90
.Lj1127:
	movq	(%rbx),%r12
	jmp	.Lj1124
	.balign 16,0x90
.Lj1128:
	movq	(%rbx),%r12
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	.balign 16,0x90
.Lj1124:
# Var $result located in register rax
	movq	%r12,%rax
# [3396] end;
	popq	%rcx
	popq	%r12
.Lc1124:
	popq	%rbx
.Lc1125:
	ret
.Lc1119:

.section .text.n_nextpas.core.atomic_$$_atomicstore64$int64$int64$memory_order_t,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMICSTORE64$INT64$INT64$MEMORY_ORDER_T
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMICSTORE64$INT64$INT64$MEMORY_ORDER_T,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMICSTORE64$INT64$INT64$MEMORY_ORDER_T:
.Lc1127:
# [3399] begin
	pushq	%rbx
.Lc1128:
	pushq	%r12
.Lc1129:
	pushq	%rax
.Lc1130:
	movq	%rdi,%rbx
# Var ATarget located in register rbx
	movq	%rsi,%r12
# Var AValue located in register r12
# Var AOrder located in register edx
# [3400] atomic_store_64(ATarget, AValue, AOrder);
	subl	$2,%edx
	jbe	.Lj1132
	subl	$1,%edx
	subl	$1,%edx
	jbe	.Lj1133
	subl	$1,%edx
	je	.Lj1134
	jmp	.Lj1131
	.balign 16,0x90
.Lj1132:
	movq	%r12,(%rbx)
	jmp	.Lj1131
	.balign 16,0x90
.Lj1133:
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	movq	%r12,(%rbx)
	jmp	.Lj1131
	.balign 16,0x90
.Lj1134:
	movq	%rbx,%rdi
	movq	%r12,%rsi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE64$INT64$INT64$$INT64
	.balign 16,0x90
.Lj1131:
# [3401] end;
	popq	%rcx
	popq	%r12
.Lc1131:
	popq	%rbx
.Lc1132:
	ret
.Lc1126:

.section .text.n_nextpas.core.atomic_$$_atomicexchange64$int64$int64$memory_order_t$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMICEXCHANGE64$INT64$INT64$MEMORY_ORDER_T$$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMICEXCHANGE64$INT64$INT64$MEMORY_ORDER_T$$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMICEXCHANGE64$INT64$INT64$MEMORY_ORDER_T$$INT64:
.Lc1134:
# [3404] begin
	pushq	%rax
.Lc1135:
# Var ATarget located in register rdi
# Var AValue located in register rsi
# Var AOrder located in register edx
# [3405] Result := atomic_exchange_64(ATarget, AValue, AOrder);
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE64$INT64$INT64$$INT64
# Var $result located in register rax
# [3406] end;
	popq	%rcx
.Lc1136:
	ret
.Lc1133:

.section .text.n_nextpas.core.atomic_$$_atomiccompareexchange64$int64$int64$int64$memory_order_t$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMICCOMPAREEXCHANGE64$INT64$INT64$INT64$MEMORY_ORDER_T$$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMICCOMPAREEXCHANGE64$INT64$INT64$INT64$MEMORY_ORDER_T$$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMICCOMPAREEXCHANGE64$INT64$INT64$INT64$MEMORY_ORDER_T$$INT64:
.Lc1138:
# [3411] begin
	pushq	%rax
.Lc1139:
# Var $result located in register rax
# Var LExpected located at rsp+0, size=OS_S64
# Var ATarget located in register rdi
	movq	%rsi,%rax
# Var AExpected located in register rax
	movq	%rdx,%rsi
# Var ADesired located in register rsi
# Var AOrder located in register ecx
# Var AExpected located in register rax
# [3412] LExpected := AExpected;
	movq	%rax,(%rsp)
# [3413] atomic_compare_exchange_strong_64(ATarget, LExpected, ADesired, AOrder, AtomicCompatFailureOrder(AOrder));
	movl	%ecx,%eax
	testl	%ecx,%ecx
	je	.Lj1144
	subl	$2,%eax
	je	.Lj1145
	subl	$1,%eax
	je	.Lj1146
	subl	$1,%eax
	je	.Lj1147
	subl	$1,%eax
	je	.Lj1148
	jmp	.Lj1143
	.balign 16,0x90
.Lj1144:
	xorl	%eax,%eax
	jmp	.Lj1142
	.balign 16,0x90
.Lj1145:
	movl	$2,%eax
	jmp	.Lj1142
	.balign 16,0x90
.Lj1146:
	xorl	%eax,%eax
	jmp	.Lj1142
	.balign 16,0x90
.Lj1147:
	movl	$2,%eax
	jmp	.Lj1142
	.balign 16,0x90
.Lj1148:
	movl	$5,%eax
	jmp	.Lj1142
	.balign 16,0x90
.Lj1143:
	xorl	%eax,%eax
	.balign 16,0x90
.Lj1142:
	movq	(%rsp),%rdx
# Var ADesired located in register rsi
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	cmpq	(%rsp),%rax
	je	.Lj1149
	movq	%rax,(%rsp)
	.p2align 4,,10
	.p2align 3
.Lj1149:
# [3414] Result := LExpected;
	movq	(%rsp),%rax
# [3415] end;
	popq	%rcx
.Lc1140:
	ret
.Lc1137:

.section .text.n_nextpas.core.atomic_$$_atomicfetchadd64$int64$int64$memory_order_t$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMICFETCHADD64$INT64$INT64$MEMORY_ORDER_T$$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMICFETCHADD64$INT64$INT64$MEMORY_ORDER_T$$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMICFETCHADD64$INT64$INT64$MEMORY_ORDER_T$$INT64:
.Lc1142:
# [3418] begin
	pushq	%rax
.Lc1143:
# Var ATarget located in register rdi
# Var AValue located in register rsi
# Var AOrder located in register edx
# [3419] Result := atomic_fetch_add_64(ATarget, AValue, AOrder);
	call	SYSTEM_$$_INTERLOCKEDEXCHANGEADD64$INT64$INT64$$INT64
# Var $result located in register rax
# [3420] end;
	popq	%rcx
.Lc1144:
	ret
.Lc1141:

.section .text.n_nextpas.core.atomic_$$_atomicfetchsub64$int64$int64$memory_order_t$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMICFETCHSUB64$INT64$INT64$MEMORY_ORDER_T$$INT64
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMICFETCHSUB64$INT64$INT64$MEMORY_ORDER_T$$INT64,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMICFETCHSUB64$INT64$INT64$MEMORY_ORDER_T$$INT64:
.Lc1146:
# [3423] begin
	pushq	%rax
.Lc1147:
# Var ATarget located in register rdi
# Var AValue located in register rsi
# Var AOrder located in register edx
# [3424] Result := atomic_fetch_sub_64(ATarget, AValue, AOrder);
	negq	%rsi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGEADD64$INT64$INT64$$INT64
# Var $result located in register rax
# [3425] end;
	popq	%rcx
.Lc1148:
	ret
.Lc1145:

.section .text.n_nextpas.core.atomic_$$_atomicloadptr$pointer$memory_order_t$$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMICLOADPTR$POINTER$MEMORY_ORDER_T$$POINTER
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMICLOADPTR$POINTER$MEMORY_ORDER_T$$POINTER,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMICLOADPTR$POINTER$MEMORY_ORDER_T$$POINTER:
.Lc1150:
# [3428] begin
	pushq	%rbx
.Lc1151:
	pushq	%r12
.Lc1152:
	pushq	%rax
.Lc1153:
	movq	%rdi,%rbx
# Var ATarget located in register rbx
# Var AOrder located in register esi
# [3429] Result := atomic_load(ATarget, AOrder);
	movq	(%rdi),%r12
	testl	%esi,%esi
	je	.Lj1171
	subl	$1,%esi
	jb	.Lj1170
	subl	$1,%esi
	jbe	.Lj1172
	subl	$1,%esi
	je	.Lj1173
	subl	$1,%esi
	je	.Lj1172
	subl	$1,%esi
	je	.Lj1174
	jmp	.Lj1170
	.balign 16,0x90
.Lj1171:
	movq	(%rbx),%r12
	jmp	.Lj1170
	.balign 16,0x90
.Lj1172:
	movq	(%rbx),%r12
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	jmp	.Lj1170
	.balign 16,0x90
.Lj1173:
	movq	(%rbx),%r12
	jmp	.Lj1170
	.balign 16,0x90
.Lj1174:
	movq	(%rbx),%r12
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	.balign 16,0x90
.Lj1170:
# Var $result located in register rax
	movq	%r12,%rax
# [3430] end;
	popq	%rcx
	popq	%r12
.Lc1154:
	popq	%rbx
.Lc1155:
	ret
.Lc1149:

.section .text.n_nextpas.core.atomic_$$_atomicstoreptr$pointer$pointer$memory_order_t,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMICSTOREPTR$POINTER$POINTER$MEMORY_ORDER_T
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMICSTOREPTR$POINTER$POINTER$MEMORY_ORDER_T,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMICSTOREPTR$POINTER$POINTER$MEMORY_ORDER_T:
.Lc1157:
# Temps allocated between rsp+0 and rsp+8
# [3433] begin
	pushq	%rbx
.Lc1158:
	pushq	%r12
.Lc1159:
	pushq	%rax
.Lc1160:
	movq	%rdi,%rbx
# Var ATarget located in register rbx
# Var AValue located in register rsi
# Var AOrder located in register edx
# Var AValue located in register rsi
# [3434] atomic_store(ATarget, AValue, AOrder);
	movq	%rsi,(%rsp)
	movq	(%rsp),%r12
	subl	$2,%edx
	jbe	.Lj1178
	subl	$1,%edx
	subl	$1,%edx
	jbe	.Lj1179
	subl	$1,%edx
	je	.Lj1180
	jmp	.Lj1177
	.balign 16,0x90
.Lj1178:
	movq	%r12,(%rbx)
	jmp	.Lj1177
	.balign 16,0x90
.Lj1179:
	call	NEXTPAS.CORE.ATOMIC_$$__COMPILER_BARRIER
	movq	%r12,(%rbx)
	jmp	.Lj1177
	.balign 16,0x90
.Lj1180:
	movq	%rbx,%rdi
	movq	%r12,%rsi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE64$INT64$INT64$$INT64
	.balign 16,0x90
.Lj1177:
# [3435] end;
	popq	%rcx
	popq	%r12
.Lc1161:
	popq	%rbx
.Lc1162:
	ret
.Lc1156:

.section .text.n_nextpas.core.atomic_$$_atomicexchangeptr$pointer$pointer$memory_order_t$$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMICEXCHANGEPTR$POINTER$POINTER$MEMORY_ORDER_T$$POINTER
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMICEXCHANGEPTR$POINTER$POINTER$MEMORY_ORDER_T$$POINTER,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMICEXCHANGEPTR$POINTER$POINTER$MEMORY_ORDER_T$$POINTER:
.Lc1164:
# Temps allocated between rsp+0 and rsp+8
# [3438] begin
	pushq	%rax
.Lc1165:
# Var ATarget located in register rdi
# Var AValue located in register rsi
# Var AOrder located in register edx
# [3439] Result := atomic_exchange(ATarget, AValue, AOrder);
	movq	%rsi,(%rsp)
	movq	(%rsp),%rsi
	call	SYSTEM_$$_INTERLOCKEDEXCHANGE64$INT64$INT64$$INT64
# Var $result located in register rax
# [3440] end;
	popq	%rcx
.Lc1166:
	ret
.Lc1163:

.section .text.n_nextpas.core.atomic_$$_atomiccompareexchangeptr$pointer$pointer$pointer$memory_order_t$$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMICCOMPAREEXCHANGEPTR$POINTER$POINTER$POINTER$MEMORY_ORDER_T$$POINTER
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMICCOMPAREEXCHANGEPTR$POINTER$POINTER$POINTER$MEMORY_ORDER_T$$POINTER,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMICCOMPAREEXCHANGEPTR$POINTER$POINTER$POINTER$MEMORY_ORDER_T$$POINTER:
.Lc1168:
# Temps allocated between rsp+8 and rsp+16
# [3445] begin
	pushq	%rbx
.Lc1169:
	leaq	-16(%rsp),%rsp
.Lc1170:
# Var LExpected located at rsp+0, size=OS_64
# Var ATarget located in register rdi
# Var AExpected located in register rsi
# Var ADesired located in register rdx
# Var AOrder located in register ecx
# Var AExpected located in register rsi
# [3446] LExpected := AExpected;
	movq	%rsi,(%rsp)
# [3447] atomic_compare_exchange_strong(ATarget, LExpected, ADesired, AOrder, AtomicCompatFailureOrder(AOrder));
	movl	%ecx,%eax
	testl	%ecx,%ecx
	je	.Lj1190
	subl	$2,%eax
	je	.Lj1191
	subl	$1,%eax
	je	.Lj1192
	subl	$1,%eax
	je	.Lj1193
	subl	$1,%eax
	je	.Lj1194
	jmp	.Lj1189
	.balign 16,0x90
.Lj1190:
	xorl	%eax,%eax
	jmp	.Lj1188
	.balign 16,0x90
.Lj1191:
	movl	$2,%eax
	jmp	.Lj1188
	.balign 16,0x90
.Lj1192:
	xorl	%eax,%eax
	jmp	.Lj1188
	.balign 16,0x90
.Lj1193:
	movl	$2,%eax
	jmp	.Lj1188
	.balign 16,0x90
.Lj1194:
	movl	$5,%eax
	jmp	.Lj1188
	.balign 16,0x90
.Lj1189:
	xorl	%eax,%eax
	.balign 16,0x90
.Lj1188:
# Var ADesired located in register rdx
	movq	%rdx,8(%rsp)
	movq	8(%rsp),%rsi
	movq	%rsp,%rbx
	movq	(%rsp),%rdx
	call	SYSTEM_$$_INTERLOCKEDCOMPAREEXCHANGE64$INT64$INT64$INT64$$INT64
	cmpq	(%rbx),%rax
	seteb	%dl
	je	.Lj1195
	movq	%rax,(%rbx)
	.p2align 4,,10
	.p2align 3
.Lj1195:
# Var $result located in register rax
# [3448] Result := LExpected;
	movq	(%rsp),%rax
# [3449] end;
	leaq	16(%rsp),%rsp
	popq	%rbx
.Lc1171:
	ret
.Lc1167:

.section .text.n_nextpas.core.atomic_$$_atomicthreadfence$memory_order_t,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMICTHREADFENCE$MEMORY_ORDER_T
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMICTHREADFENCE$MEMORY_ORDER_T,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMICTHREADFENCE$MEMORY_ORDER_T:
.Lc1173:
# [3452] begin
	pushq	%rax
.Lc1174:
# Var AOrder located in register edi
# Var AOrder located in register edi
# [3453] atomic_thread_fence(AOrder);
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_THREAD_FENCE$MEMORY_ORDER_T
# [3454] end;
	popq	%rcx
.Lc1175:
	ret
.Lc1172:

.section .text.n_nextpas.core.atomic_$$_atomicsignalfence$memory_order_t,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.ATOMIC_$$_ATOMICSIGNALFENCE$MEMORY_ORDER_T
	.type	NEXTPAS.CORE.ATOMIC_$$_ATOMICSIGNALFENCE$MEMORY_ORDER_T,@function
NEXTPAS.CORE.ATOMIC_$$_ATOMICSIGNALFENCE$MEMORY_ORDER_T:
.Lc1177:
# [3457] begin
	pushq	%rax
.Lc1178:
# Var AOrder located in register edi
# Var AOrder located in register edi
# [3458] atomic_signal_fence(AOrder);
	call	NEXTPAS.CORE.ATOMIC_$$_ATOMIC_SIGNAL_FENCE$MEMORY_ORDER_T
# [3459] end;
	popq	%rcx
.Lc1179:
	ret
.Lc1176:
# End asmlist al_procedures
# Begin asmlist al_rtti

.section .rodata.n_RTTI_$NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FLAG_T
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FLAG_T
	.type	RTTI_$NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FLAG_T,@object
RTTI_$NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FLAG_T:
	.byte	1,13
# [3471] 
	.ascii	"atomic_flag_t"
	.quad	0
	.byte	4
	.long	-2147483648,2147483647
.Le20:
	.size	RTTI_$NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FLAG_T, .Le20 - RTTI_$NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FLAG_T
# End asmlist al_rtti
# Begin asmlist al_indirectglobals

.section .rodata.n_RTTI_$NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FLAG_T
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FLAG_T$indirect
	.type	RTTI_$NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FLAG_T$indirect,@object
RTTI_$NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FLAG_T$indirect:
	.quad	RTTI_$NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FLAG_T
.Le21:
	.size	RTTI_$NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FLAG_T$indirect, .Le21 - RTTI_$NEXTPAS.CORE.ATOMIC_$$_ATOMIC_FLAG_T$indirect
# End asmlist al_indirectglobals
# Begin asmlist al_dwarf_frame

.section .debug_frame
.Lc1180:
	.long	.Lc1182-.Lc1181
.Lc1181:
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
.Lc1182:
	.long	.Lc1184-.Lc1183
.Lc1183:
	.long	.Lc1180
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
.Lc1184:
	.long	.Lc1187-.Lc1186
.Lc1186:
	.long	.Lc1180
	.quad	.Lc6
	.quad	.Lc5-.Lc6
	.balign 8,0
.Lc1187:
	.long	.Lc1190-.Lc1189
.Lc1189:
	.long	.Lc1180
	.quad	.Lc8
	.quad	.Lc7-.Lc8
	.byte	4
	.long	.Lc9-.Lc8
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1190:
	.long	.Lc1193-.Lc1192
.Lc1192:
	.long	.Lc1180
	.quad	.Lc11
	.quad	.Lc10-.Lc11
	.byte	4
	.long	.Lc12-.Lc11
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1193:
	.long	.Lc1196-.Lc1195
.Lc1195:
	.long	.Lc1180
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
.Lc1196:
	.long	.Lc1199-.Lc1198
.Lc1198:
	.long	.Lc1180
	.quad	.Lc21
	.quad	.Lc20-.Lc21
	.byte	4
	.long	.Lc22-.Lc21
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1199:
	.long	.Lc1202-.Lc1201
.Lc1201:
	.long	.Lc1180
	.quad	.Lc24
	.quad	.Lc23-.Lc24
	.byte	2
	.byte	.Lc25-.Lc24
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc26-.Lc25
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc27-.Lc26
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc28-.Lc27
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc29-.Lc28
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1202:
	.long	.Lc1205-.Lc1204
.Lc1204:
	.long	.Lc1180
	.quad	.Lc31
	.quad	.Lc30-.Lc31
	.byte	4
	.long	.Lc32-.Lc31
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1205:
	.long	.Lc1208-.Lc1207
.Lc1207:
	.long	.Lc1180
	.quad	.Lc34
	.quad	.Lc33-.Lc34
	.byte	2
	.byte	.Lc35-.Lc34
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc36-.Lc35
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc37-.Lc36
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc38-.Lc37
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc39-.Lc38
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1208:
	.long	.Lc1211-.Lc1210
.Lc1210:
	.long	.Lc1180
	.quad	.Lc41
	.quad	.Lc40-.Lc41
	.byte	4
	.long	.Lc42-.Lc41
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1211:
	.long	.Lc1214-.Lc1213
.Lc1213:
	.long	.Lc1180
	.quad	.Lc44
	.quad	.Lc43-.Lc44
	.byte	2
	.byte	.Lc45-.Lc44
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc46-.Lc45
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc47-.Lc46
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc48-.Lc47
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc49-.Lc48
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1214:
	.long	.Lc1217-.Lc1216
.Lc1216:
	.long	.Lc1180
	.quad	.Lc51
	.quad	.Lc50-.Lc51
	.byte	4
	.long	.Lc52-.Lc51
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1217:
	.long	.Lc1220-.Lc1219
.Lc1219:
	.long	.Lc1180
	.quad	.Lc54
	.quad	.Lc53-.Lc54
	.byte	2
	.byte	.Lc55-.Lc54
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc56-.Lc55
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc57-.Lc56
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc58-.Lc57
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc59-.Lc58
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1220:
	.long	.Lc1223-.Lc1222
.Lc1222:
	.long	.Lc1180
	.quad	.Lc61
	.quad	.Lc60-.Lc61
	.byte	4
	.long	.Lc62-.Lc61
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1223:
	.long	.Lc1226-.Lc1225
.Lc1225:
	.long	.Lc1180
	.quad	.Lc64
	.quad	.Lc63-.Lc64
	.byte	2
	.byte	.Lc65-.Lc64
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc66-.Lc65
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc67-.Lc66
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc68-.Lc67
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc69-.Lc68
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1226:
	.long	.Lc1229-.Lc1228
.Lc1228:
	.long	.Lc1180
	.quad	.Lc71
	.quad	.Lc70-.Lc71
	.byte	4
	.long	.Lc72-.Lc71
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1229:
	.long	.Lc1232-.Lc1231
.Lc1231:
	.long	.Lc1180
	.quad	.Lc74
	.quad	.Lc73-.Lc74
	.byte	2
	.byte	.Lc75-.Lc74
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc76-.Lc75
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc77-.Lc76
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc78-.Lc77
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc79-.Lc78
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1232:
	.long	.Lc1235-.Lc1234
.Lc1234:
	.long	.Lc1180
	.quad	.Lc81
	.quad	.Lc80-.Lc81
	.byte	4
	.long	.Lc82-.Lc81
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1235:
	.long	.Lc1238-.Lc1237
.Lc1237:
	.long	.Lc1180
	.quad	.Lc84
	.quad	.Lc83-.Lc84
	.byte	2
	.byte	.Lc85-.Lc84
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc86-.Lc85
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc87-.Lc86
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc88-.Lc87
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc89-.Lc88
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1238:
	.long	.Lc1241-.Lc1240
.Lc1240:
	.long	.Lc1180
	.quad	.Lc91
	.quad	.Lc90-.Lc91
	.byte	4
	.long	.Lc92-.Lc91
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1241:
	.long	.Lc1244-.Lc1243
.Lc1243:
	.long	.Lc1180
	.quad	.Lc94
	.quad	.Lc93-.Lc94
	.byte	2
	.byte	.Lc95-.Lc94
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc96-.Lc95
	.byte	5
	.uleb128	12
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc97-.Lc96
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc98-.Lc97
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc99-.Lc98
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1244:
	.long	.Lc1247-.Lc1246
.Lc1246:
	.long	.Lc1180
	.quad	.Lc101
	.quad	.Lc100-.Lc101
	.byte	2
	.byte	.Lc102-.Lc101
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc103-.Lc102
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1247:
	.long	.Lc1250-.Lc1249
.Lc1249:
	.long	.Lc1180
	.quad	.Lc105
	.quad	.Lc104-.Lc105
	.byte	2
	.byte	.Lc106-.Lc105
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc107-.Lc106
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc108-.Lc107
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc109-.Lc108
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc110-.Lc109
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1250:
	.long	.Lc1253-.Lc1252
.Lc1252:
	.long	.Lc1180
	.quad	.Lc112
	.quad	.Lc111-.Lc112
	.byte	4
	.long	.Lc113-.Lc112
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1253:
	.long	.Lc1256-.Lc1255
.Lc1255:
	.long	.Lc1180
	.quad	.Lc115
	.quad	.Lc114-.Lc115
	.byte	2
	.byte	.Lc116-.Lc115
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc117-.Lc116
	.byte	5
	.uleb128	12
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc118-.Lc117
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc119-.Lc118
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc120-.Lc119
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1256:
	.long	.Lc1259-.Lc1258
.Lc1258:
	.long	.Lc1180
	.quad	.Lc122
	.quad	.Lc121-.Lc122
	.byte	2
	.byte	.Lc123-.Lc122
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc124-.Lc123
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1259:
	.long	.Lc1262-.Lc1261
.Lc1261:
	.long	.Lc1180
	.quad	.Lc126
	.quad	.Lc125-.Lc126
	.byte	2
	.byte	.Lc127-.Lc126
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc128-.Lc127
	.byte	5
	.uleb128	12
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc129-.Lc128
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc130-.Lc129
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc131-.Lc130
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1262:
	.long	.Lc1265-.Lc1264
.Lc1264:
	.long	.Lc1180
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
.Lc1265:
	.long	.Lc1268-.Lc1267
.Lc1267:
	.long	.Lc1180
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
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc141-.Lc140
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc142-.Lc141
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1268:
	.long	.Lc1271-.Lc1270
.Lc1270:
	.long	.Lc1180
	.quad	.Lc144
	.quad	.Lc143-.Lc144
	.byte	2
	.byte	.Lc145-.Lc144
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc146-.Lc145
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1271:
	.long	.Lc1274-.Lc1273
.Lc1273:
	.long	.Lc1180
	.quad	.Lc148
	.quad	.Lc147-.Lc148
	.byte	2
	.byte	.Lc149-.Lc148
	.byte	5
	.uleb128	3
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc150-.Lc149
	.byte	5
	.uleb128	12
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc151-.Lc150
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc152-.Lc151
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc153-.Lc152
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1274:
	.long	.Lc1277-.Lc1276
.Lc1276:
	.long	.Lc1180
	.quad	.Lc155
	.quad	.Lc154-.Lc155
	.byte	2
	.byte	.Lc156-.Lc155
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc157-.Lc156
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1277:
	.long	.Lc1280-.Lc1279
.Lc1279:
	.long	.Lc1180
	.quad	.Lc159
	.quad	.Lc158-.Lc159
	.byte	2
	.byte	.Lc160-.Lc159
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc161-.Lc160
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1280:
	.long	.Lc1283-.Lc1282
.Lc1282:
	.long	.Lc1180
	.quad	.Lc163
	.quad	.Lc162-.Lc163
	.byte	2
	.byte	.Lc164-.Lc163
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc165-.Lc164
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1283:
	.long	.Lc1286-.Lc1285
.Lc1285:
	.long	.Lc1180
	.quad	.Lc167
	.quad	.Lc166-.Lc167
	.byte	2
	.byte	.Lc168-.Lc167
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc169-.Lc168
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1286:
	.long	.Lc1289-.Lc1288
.Lc1288:
	.long	.Lc1180
	.quad	.Lc171
	.quad	.Lc170-.Lc171
	.byte	2
	.byte	.Lc172-.Lc171
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc173-.Lc172
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1289:
	.long	.Lc1292-.Lc1291
.Lc1291:
	.long	.Lc1180
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
.Lc1292:
	.long	.Lc1295-.Lc1294
.Lc1294:
	.long	.Lc1180
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
.Lc1295:
	.long	.Lc1298-.Lc1297
.Lc1297:
	.long	.Lc1180
	.quad	.Lc183
	.quad	.Lc182-.Lc183
	.byte	2
	.byte	.Lc184-.Lc183
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc185-.Lc184
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1298:
	.long	.Lc1301-.Lc1300
.Lc1300:
	.long	.Lc1180
	.quad	.Lc187
	.quad	.Lc186-.Lc187
	.byte	2
	.byte	.Lc188-.Lc187
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc189-.Lc188
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1301:
	.long	.Lc1304-.Lc1303
.Lc1303:
	.long	.Lc1180
	.quad	.Lc191
	.quad	.Lc190-.Lc191
	.byte	2
	.byte	.Lc192-.Lc191
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc193-.Lc192
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1304:
	.long	.Lc1307-.Lc1306
.Lc1306:
	.long	.Lc1180
	.quad	.Lc195
	.quad	.Lc194-.Lc195
	.byte	2
	.byte	.Lc196-.Lc195
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc197-.Lc196
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1307:
	.long	.Lc1310-.Lc1309
.Lc1309:
	.long	.Lc1180
	.quad	.Lc199
	.quad	.Lc198-.Lc199
	.byte	2
	.byte	.Lc200-.Lc199
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc201-.Lc200
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1310:
	.long	.Lc1313-.Lc1312
.Lc1312:
	.long	.Lc1180
	.quad	.Lc203
	.quad	.Lc202-.Lc203
	.byte	2
	.byte	.Lc204-.Lc203
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc205-.Lc204
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1313:
	.long	.Lc1316-.Lc1315
.Lc1315:
	.long	.Lc1180
	.quad	.Lc207
	.quad	.Lc206-.Lc207
	.byte	2
	.byte	.Lc208-.Lc207
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc209-.Lc208
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1316:
	.long	.Lc1319-.Lc1318
.Lc1318:
	.long	.Lc1180
	.quad	.Lc211
	.quad	.Lc210-.Lc211
	.byte	2
	.byte	.Lc212-.Lc211
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc213-.Lc212
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1319:
	.long	.Lc1322-.Lc1321
.Lc1321:
	.long	.Lc1180
	.quad	.Lc215
	.quad	.Lc214-.Lc215
	.byte	2
	.byte	.Lc216-.Lc215
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc217-.Lc216
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1322:
	.long	.Lc1325-.Lc1324
.Lc1324:
	.long	.Lc1180
	.quad	.Lc219
	.quad	.Lc218-.Lc219
	.byte	2
	.byte	.Lc220-.Lc219
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc221-.Lc220
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1325:
	.long	.Lc1328-.Lc1327
.Lc1327:
	.long	.Lc1180
	.quad	.Lc223
	.quad	.Lc222-.Lc223
	.byte	2
	.byte	.Lc224-.Lc223
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc225-.Lc224
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1328:
	.long	.Lc1331-.Lc1330
.Lc1330:
	.long	.Lc1180
	.quad	.Lc227
	.quad	.Lc226-.Lc227
	.byte	2
	.byte	.Lc228-.Lc227
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc229-.Lc228
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1331:
	.long	.Lc1334-.Lc1333
.Lc1333:
	.long	.Lc1180
	.quad	.Lc231
	.quad	.Lc230-.Lc231
	.byte	2
	.byte	.Lc232-.Lc231
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc233-.Lc232
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1334:
	.long	.Lc1337-.Lc1336
.Lc1336:
	.long	.Lc1180
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
.Lc1337:
	.long	.Lc1340-.Lc1339
.Lc1339:
	.long	.Lc1180
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
.Lc1340:
	.long	.Lc1343-.Lc1342
.Lc1342:
	.long	.Lc1180
	.quad	.Lc243
	.quad	.Lc242-.Lc243
	.byte	2
	.byte	.Lc244-.Lc243
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc245-.Lc244
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1343:
	.long	.Lc1346-.Lc1345
.Lc1345:
	.long	.Lc1180
	.quad	.Lc247
	.quad	.Lc246-.Lc247
	.byte	2
	.byte	.Lc248-.Lc247
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc249-.Lc248
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1346:
	.long	.Lc1349-.Lc1348
.Lc1348:
	.long	.Lc1180
	.quad	.Lc251
	.quad	.Lc250-.Lc251
	.byte	2
	.byte	.Lc252-.Lc251
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc253-.Lc252
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1349:
	.long	.Lc1352-.Lc1351
.Lc1351:
	.long	.Lc1180
	.quad	.Lc255
	.quad	.Lc254-.Lc255
	.byte	2
	.byte	.Lc256-.Lc255
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc257-.Lc256
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1352:
	.long	.Lc1355-.Lc1354
.Lc1354:
	.long	.Lc1180
	.quad	.Lc259
	.quad	.Lc258-.Lc259
	.byte	2
	.byte	.Lc260-.Lc259
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc261-.Lc260
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1355:
	.long	.Lc1358-.Lc1357
.Lc1357:
	.long	.Lc1180
	.quad	.Lc263
	.quad	.Lc262-.Lc263
	.byte	2
	.byte	.Lc264-.Lc263
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc265-.Lc264
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1358:
	.long	.Lc1361-.Lc1360
.Lc1360:
	.long	.Lc1180
	.quad	.Lc267
	.quad	.Lc266-.Lc267
	.byte	2
	.byte	.Lc268-.Lc267
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc269-.Lc268
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1361:
	.long	.Lc1364-.Lc1363
.Lc1363:
	.long	.Lc1180
	.quad	.Lc271
	.quad	.Lc270-.Lc271
	.byte	2
	.byte	.Lc272-.Lc271
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc273-.Lc272
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1364:
	.long	.Lc1367-.Lc1366
.Lc1366:
	.long	.Lc1180
	.quad	.Lc275
	.quad	.Lc274-.Lc275
	.byte	2
	.byte	.Lc276-.Lc275
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc277-.Lc276
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1367:
	.long	.Lc1370-.Lc1369
.Lc1369:
	.long	.Lc1180
	.quad	.Lc279
	.quad	.Lc278-.Lc279
	.byte	2
	.byte	.Lc280-.Lc279
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc281-.Lc280
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1370:
	.long	.Lc1373-.Lc1372
.Lc1372:
	.long	.Lc1180
	.quad	.Lc283
	.quad	.Lc282-.Lc283
	.byte	2
	.byte	.Lc284-.Lc283
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc285-.Lc284
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1373:
	.long	.Lc1376-.Lc1375
.Lc1375:
	.long	.Lc1180
	.quad	.Lc287
	.quad	.Lc286-.Lc287
	.byte	2
	.byte	.Lc288-.Lc287
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc289-.Lc288
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1376:
	.long	.Lc1379-.Lc1378
.Lc1378:
	.long	.Lc1180
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
.Lc1379:
	.long	.Lc1382-.Lc1381
.Lc1381:
	.long	.Lc1180
	.quad	.Lc295
	.quad	.Lc294-.Lc295
	.byte	2
	.byte	.Lc296-.Lc295
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc297-.Lc296
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1382:
	.long	.Lc1385-.Lc1384
.Lc1384:
	.long	.Lc1180
	.quad	.Lc299
	.quad	.Lc298-.Lc299
	.byte	2
	.byte	.Lc300-.Lc299
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc301-.Lc300
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1385:
	.long	.Lc1388-.Lc1387
.Lc1387:
	.long	.Lc1180
	.quad	.Lc303
	.quad	.Lc302-.Lc303
	.byte	2
	.byte	.Lc304-.Lc303
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc305-.Lc304
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1388:
	.long	.Lc1391-.Lc1390
.Lc1390:
	.long	.Lc1180
	.quad	.Lc307
	.quad	.Lc306-.Lc307
	.byte	2
	.byte	.Lc308-.Lc307
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc309-.Lc308
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1391:
	.long	.Lc1394-.Lc1393
.Lc1393:
	.long	.Lc1180
	.quad	.Lc311
	.quad	.Lc310-.Lc311
	.byte	2
	.byte	.Lc312-.Lc311
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc313-.Lc312
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc314-.Lc313
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1394:
	.long	.Lc1397-.Lc1396
.Lc1396:
	.long	.Lc1180
	.quad	.Lc316
	.quad	.Lc315-.Lc316
	.byte	2
	.byte	.Lc317-.Lc316
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc318-.Lc317
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1397:
	.long	.Lc1400-.Lc1399
.Lc1399:
	.long	.Lc1180
	.quad	.Lc320
	.quad	.Lc319-.Lc320
	.byte	2
	.byte	.Lc321-.Lc320
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc322-.Lc321
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc323-.Lc322
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1400:
	.long	.Lc1403-.Lc1402
.Lc1402:
	.long	.Lc1180
	.quad	.Lc325
	.quad	.Lc324-.Lc325
	.byte	2
	.byte	.Lc326-.Lc325
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc327-.Lc326
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1403:
	.long	.Lc1406-.Lc1405
.Lc1405:
	.long	.Lc1180
	.quad	.Lc329
	.quad	.Lc328-.Lc329
	.byte	2
	.byte	.Lc330-.Lc329
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc331-.Lc330
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc332-.Lc331
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1406:
	.long	.Lc1409-.Lc1408
.Lc1408:
	.long	.Lc1180
	.quad	.Lc334
	.quad	.Lc333-.Lc334
	.byte	2
	.byte	.Lc335-.Lc334
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc336-.Lc335
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc337-.Lc336
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1409:
	.long	.Lc1412-.Lc1411
.Lc1411:
	.long	.Lc1180
	.quad	.Lc339
	.quad	.Lc338-.Lc339
	.byte	2
	.byte	.Lc340-.Lc339
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc341-.Lc340
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1412:
	.long	.Lc1415-.Lc1414
.Lc1414:
	.long	.Lc1180
	.quad	.Lc343
	.quad	.Lc342-.Lc343
	.byte	2
	.byte	.Lc344-.Lc343
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc345-.Lc344
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc346-.Lc345
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1415:
	.long	.Lc1418-.Lc1417
.Lc1417:
	.long	.Lc1180
	.quad	.Lc348
	.quad	.Lc347-.Lc348
	.byte	2
	.byte	.Lc349-.Lc348
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc350-.Lc349
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1418:
	.long	.Lc1421-.Lc1420
.Lc1420:
	.long	.Lc1180
	.quad	.Lc352
	.quad	.Lc351-.Lc352
	.byte	2
	.byte	.Lc353-.Lc352
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc354-.Lc353
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc355-.Lc354
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1421:
	.long	.Lc1424-.Lc1423
.Lc1423:
	.long	.Lc1180
	.quad	.Lc357
	.quad	.Lc356-.Lc357
	.byte	2
	.byte	.Lc358-.Lc357
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc359-.Lc358
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1424:
	.long	.Lc1427-.Lc1426
.Lc1426:
	.long	.Lc1180
	.quad	.Lc361
	.quad	.Lc360-.Lc361
	.byte	2
	.byte	.Lc362-.Lc361
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc363-.Lc362
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc364-.Lc363
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1427:
	.long	.Lc1430-.Lc1429
.Lc1429:
	.long	.Lc1180
	.quad	.Lc366
	.quad	.Lc365-.Lc366
	.byte	2
	.byte	.Lc367-.Lc366
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc368-.Lc367
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc369-.Lc368
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1430:
	.long	.Lc1433-.Lc1432
.Lc1432:
	.long	.Lc1180
	.quad	.Lc371
	.quad	.Lc370-.Lc371
	.byte	2
	.byte	.Lc372-.Lc371
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc373-.Lc372
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1433:
	.long	.Lc1436-.Lc1435
.Lc1435:
	.long	.Lc1180
	.quad	.Lc375
	.quad	.Lc374-.Lc375
	.byte	2
	.byte	.Lc376-.Lc375
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc377-.Lc376
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc378-.Lc377
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1436:
	.long	.Lc1439-.Lc1438
.Lc1438:
	.long	.Lc1180
	.quad	.Lc380
	.quad	.Lc379-.Lc380
	.byte	2
	.byte	.Lc381-.Lc380
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc382-.Lc381
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1439:
	.long	.Lc1442-.Lc1441
.Lc1441:
	.long	.Lc1180
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
.Lc1442:
	.long	.Lc1445-.Lc1444
.Lc1444:
	.long	.Lc1180
	.quad	.Lc389
	.quad	.Lc388-.Lc389
	.byte	2
	.byte	.Lc390-.Lc389
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc391-.Lc390
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1445:
	.long	.Lc1448-.Lc1447
.Lc1447:
	.long	.Lc1180
	.quad	.Lc393
	.quad	.Lc392-.Lc393
	.byte	2
	.byte	.Lc394-.Lc393
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc395-.Lc394
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc396-.Lc395
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1448:
	.long	.Lc1451-.Lc1450
.Lc1450:
	.long	.Lc1180
	.quad	.Lc398
	.quad	.Lc397-.Lc398
	.byte	2
	.byte	.Lc399-.Lc398
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc400-.Lc399
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc401-.Lc400
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1451:
	.long	.Lc1454-.Lc1453
.Lc1453:
	.long	.Lc1180
	.quad	.Lc403
	.quad	.Lc402-.Lc403
	.byte	2
	.byte	.Lc404-.Lc403
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc405-.Lc404
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1454:
	.long	.Lc1457-.Lc1456
.Lc1456:
	.long	.Lc1180
	.quad	.Lc407
	.quad	.Lc406-.Lc407
	.byte	2
	.byte	.Lc408-.Lc407
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc409-.Lc408
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc410-.Lc409
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1457:
	.long	.Lc1460-.Lc1459
.Lc1459:
	.long	.Lc1180
	.quad	.Lc412
	.quad	.Lc411-.Lc412
	.byte	2
	.byte	.Lc413-.Lc412
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc414-.Lc413
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1460:
	.long	.Lc1463-.Lc1462
.Lc1462:
	.long	.Lc1180
	.quad	.Lc416
	.quad	.Lc415-.Lc416
	.byte	2
	.byte	.Lc417-.Lc416
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc418-.Lc417
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc419-.Lc418
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1463:
	.long	.Lc1466-.Lc1465
.Lc1465:
	.long	.Lc1180
	.quad	.Lc421
	.quad	.Lc420-.Lc421
	.byte	2
	.byte	.Lc422-.Lc421
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc423-.Lc422
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1466:
	.long	.Lc1469-.Lc1468
.Lc1468:
	.long	.Lc1180
	.quad	.Lc425
	.quad	.Lc424-.Lc425
	.byte	2
	.byte	.Lc426-.Lc425
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc427-.Lc426
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc428-.Lc427
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1469:
	.long	.Lc1472-.Lc1471
.Lc1471:
	.long	.Lc1180
	.quad	.Lc430
	.quad	.Lc429-.Lc430
	.byte	2
	.byte	.Lc431-.Lc430
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc432-.Lc431
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc433-.Lc432
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1472:
	.long	.Lc1475-.Lc1474
.Lc1474:
	.long	.Lc1180
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
.Lc1475:
	.long	.Lc1478-.Lc1477
.Lc1477:
	.long	.Lc1180
	.quad	.Lc439
	.quad	.Lc438-.Lc439
	.byte	2
	.byte	.Lc440-.Lc439
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc441-.Lc440
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1478:
	.long	.Lc1481-.Lc1480
.Lc1480:
	.long	.Lc1180
	.quad	.Lc443
	.quad	.Lc442-.Lc443
	.byte	2
	.byte	.Lc444-.Lc443
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc445-.Lc444
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1481:
	.long	.Lc1484-.Lc1483
.Lc1483:
	.long	.Lc1180
	.quad	.Lc447
	.quad	.Lc446-.Lc447
	.byte	2
	.byte	.Lc448-.Lc447
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc449-.Lc448
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1484:
	.long	.Lc1487-.Lc1486
.Lc1486:
	.long	.Lc1180
	.quad	.Lc451
	.quad	.Lc450-.Lc451
	.byte	2
	.byte	.Lc452-.Lc451
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc453-.Lc452
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1487:
	.long	.Lc1490-.Lc1489
.Lc1489:
	.long	.Lc1180
	.quad	.Lc455
	.quad	.Lc454-.Lc455
	.byte	2
	.byte	.Lc456-.Lc455
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc457-.Lc456
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1490:
	.long	.Lc1493-.Lc1492
.Lc1492:
	.long	.Lc1180
	.quad	.Lc459
	.quad	.Lc458-.Lc459
	.byte	2
	.byte	.Lc460-.Lc459
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc461-.Lc460
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1493:
	.long	.Lc1496-.Lc1495
.Lc1495:
	.long	.Lc1180
	.quad	.Lc463
	.quad	.Lc462-.Lc463
	.byte	2
	.byte	.Lc464-.Lc463
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc465-.Lc464
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1496:
	.long	.Lc1499-.Lc1498
.Lc1498:
	.long	.Lc1180
	.quad	.Lc467
	.quad	.Lc466-.Lc467
	.byte	2
	.byte	.Lc468-.Lc467
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc469-.Lc468
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1499:
	.long	.Lc1502-.Lc1501
.Lc1501:
	.long	.Lc1180
	.quad	.Lc471
	.quad	.Lc470-.Lc471
	.byte	2
	.byte	.Lc472-.Lc471
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc473-.Lc472
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1502:
	.long	.Lc1505-.Lc1504
.Lc1504:
	.long	.Lc1180
	.quad	.Lc475
	.quad	.Lc474-.Lc475
	.byte	2
	.byte	.Lc476-.Lc475
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc477-.Lc476
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1505:
	.long	.Lc1508-.Lc1507
.Lc1507:
	.long	.Lc1180
	.quad	.Lc479
	.quad	.Lc478-.Lc479
	.byte	2
	.byte	.Lc480-.Lc479
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc481-.Lc480
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1508:
	.long	.Lc1511-.Lc1510
.Lc1510:
	.long	.Lc1180
	.quad	.Lc483
	.quad	.Lc482-.Lc483
	.byte	2
	.byte	.Lc484-.Lc483
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc485-.Lc484
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1511:
	.long	.Lc1514-.Lc1513
.Lc1513:
	.long	.Lc1180
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
.Lc1514:
	.long	.Lc1517-.Lc1516
.Lc1516:
	.long	.Lc1180
	.quad	.Lc491
	.quad	.Lc490-.Lc491
	.byte	2
	.byte	.Lc492-.Lc491
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc493-.Lc492
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1517:
	.long	.Lc1520-.Lc1519
.Lc1519:
	.long	.Lc1180
	.quad	.Lc495
	.quad	.Lc494-.Lc495
	.byte	2
	.byte	.Lc496-.Lc495
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc497-.Lc496
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1520:
	.long	.Lc1523-.Lc1522
.Lc1522:
	.long	.Lc1180
	.quad	.Lc499
	.quad	.Lc498-.Lc499
	.byte	2
	.byte	.Lc500-.Lc499
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc501-.Lc500
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1523:
	.long	.Lc1526-.Lc1525
.Lc1525:
	.long	.Lc1180
	.quad	.Lc503
	.quad	.Lc502-.Lc503
	.byte	2
	.byte	.Lc504-.Lc503
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc505-.Lc504
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1526:
	.long	.Lc1529-.Lc1528
.Lc1528:
	.long	.Lc1180
	.quad	.Lc507
	.quad	.Lc506-.Lc507
	.byte	2
	.byte	.Lc508-.Lc507
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc509-.Lc508
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1529:
	.long	.Lc1532-.Lc1531
.Lc1531:
	.long	.Lc1180
	.quad	.Lc511
	.quad	.Lc510-.Lc511
	.byte	2
	.byte	.Lc512-.Lc511
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc513-.Lc512
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1532:
	.long	.Lc1535-.Lc1534
.Lc1534:
	.long	.Lc1180
	.quad	.Lc515
	.quad	.Lc514-.Lc515
	.byte	2
	.byte	.Lc516-.Lc515
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc517-.Lc516
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1535:
	.long	.Lc1538-.Lc1537
.Lc1537:
	.long	.Lc1180
	.quad	.Lc519
	.quad	.Lc518-.Lc519
	.byte	2
	.byte	.Lc520-.Lc519
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc521-.Lc520
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1538:
	.long	.Lc1541-.Lc1540
.Lc1540:
	.long	.Lc1180
	.quad	.Lc523
	.quad	.Lc522-.Lc523
	.byte	2
	.byte	.Lc524-.Lc523
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc525-.Lc524
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1541:
	.long	.Lc1544-.Lc1543
.Lc1543:
	.long	.Lc1180
	.quad	.Lc527
	.quad	.Lc526-.Lc527
	.byte	2
	.byte	.Lc528-.Lc527
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc529-.Lc528
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1544:
	.long	.Lc1547-.Lc1546
.Lc1546:
	.long	.Lc1180
	.quad	.Lc531
	.quad	.Lc530-.Lc531
	.byte	2
	.byte	.Lc532-.Lc531
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc533-.Lc532
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1547:
	.long	.Lc1550-.Lc1549
.Lc1549:
	.long	.Lc1180
	.quad	.Lc535
	.quad	.Lc534-.Lc535
	.byte	2
	.byte	.Lc536-.Lc535
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc537-.Lc536
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1550:
	.long	.Lc1553-.Lc1552
.Lc1552:
	.long	.Lc1180
	.quad	.Lc539
	.quad	.Lc538-.Lc539
	.byte	2
	.byte	.Lc540-.Lc539
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc541-.Lc540
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1553:
	.long	.Lc1556-.Lc1555
.Lc1555:
	.long	.Lc1180
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
.Lc1556:
	.long	.Lc1559-.Lc1558
.Lc1558:
	.long	.Lc1180
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
.Lc1559:
	.long	.Lc1562-.Lc1561
.Lc1561:
	.long	.Lc1180
	.quad	.Lc551
	.quad	.Lc550-.Lc551
	.byte	2
	.byte	.Lc552-.Lc551
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc553-.Lc552
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1562:
	.long	.Lc1565-.Lc1564
.Lc1564:
	.long	.Lc1180
	.quad	.Lc555
	.quad	.Lc554-.Lc555
	.byte	2
	.byte	.Lc556-.Lc555
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc557-.Lc556
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1565:
	.long	.Lc1568-.Lc1567
.Lc1567:
	.long	.Lc1180
	.quad	.Lc559
	.quad	.Lc558-.Lc559
	.byte	2
	.byte	.Lc560-.Lc559
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc561-.Lc560
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1568:
	.long	.Lc1571-.Lc1570
.Lc1570:
	.long	.Lc1180
	.quad	.Lc563
	.quad	.Lc562-.Lc563
	.byte	2
	.byte	.Lc564-.Lc563
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc565-.Lc564
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1571:
	.long	.Lc1574-.Lc1573
.Lc1573:
	.long	.Lc1180
	.quad	.Lc567
	.quad	.Lc566-.Lc567
	.byte	2
	.byte	.Lc568-.Lc567
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc569-.Lc568
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1574:
	.long	.Lc1577-.Lc1576
.Lc1576:
	.long	.Lc1180
	.quad	.Lc571
	.quad	.Lc570-.Lc571
	.byte	2
	.byte	.Lc572-.Lc571
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc573-.Lc572
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1577:
	.long	.Lc1580-.Lc1579
.Lc1579:
	.long	.Lc1180
	.quad	.Lc575
	.quad	.Lc574-.Lc575
	.byte	2
	.byte	.Lc576-.Lc575
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc577-.Lc576
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1580:
	.long	.Lc1583-.Lc1582
.Lc1582:
	.long	.Lc1180
	.quad	.Lc579
	.quad	.Lc578-.Lc579
	.byte	2
	.byte	.Lc580-.Lc579
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc581-.Lc580
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1583:
	.long	.Lc1586-.Lc1585
.Lc1585:
	.long	.Lc1180
	.quad	.Lc583
	.quad	.Lc582-.Lc583
	.byte	2
	.byte	.Lc584-.Lc583
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc585-.Lc584
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1586:
	.long	.Lc1589-.Lc1588
.Lc1588:
	.long	.Lc1180
	.quad	.Lc587
	.quad	.Lc586-.Lc587
	.byte	2
	.byte	.Lc588-.Lc587
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc589-.Lc588
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1589:
	.long	.Lc1592-.Lc1591
.Lc1591:
	.long	.Lc1180
	.quad	.Lc591
	.quad	.Lc590-.Lc591
	.byte	2
	.byte	.Lc592-.Lc591
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc593-.Lc592
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1592:
	.long	.Lc1595-.Lc1594
.Lc1594:
	.long	.Lc1180
	.quad	.Lc595
	.quad	.Lc594-.Lc595
	.byte	2
	.byte	.Lc596-.Lc595
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc597-.Lc596
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1595:
	.long	.Lc1598-.Lc1597
.Lc1597:
	.long	.Lc1180
	.quad	.Lc599
	.quad	.Lc598-.Lc599
	.byte	2
	.byte	.Lc600-.Lc599
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc601-.Lc600
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1598:
	.long	.Lc1601-.Lc1600
.Lc1600:
	.long	.Lc1180
	.quad	.Lc603
	.quad	.Lc602-.Lc603
	.byte	2
	.byte	.Lc604-.Lc603
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc605-.Lc604
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1601:
	.long	.Lc1604-.Lc1603
.Lc1603:
	.long	.Lc1180
	.quad	.Lc607
	.quad	.Lc606-.Lc607
	.byte	2
	.byte	.Lc608-.Lc607
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc609-.Lc608
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1604:
	.long	.Lc1607-.Lc1606
.Lc1606:
	.long	.Lc1180
	.quad	.Lc611
	.quad	.Lc610-.Lc611
	.byte	2
	.byte	.Lc612-.Lc611
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc613-.Lc612
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1607:
	.long	.Lc1610-.Lc1609
.Lc1609:
	.long	.Lc1180
	.quad	.Lc615
	.quad	.Lc614-.Lc615
	.byte	2
	.byte	.Lc616-.Lc615
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc617-.Lc616
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1610:
	.long	.Lc1613-.Lc1612
.Lc1612:
	.long	.Lc1180
	.quad	.Lc619
	.quad	.Lc618-.Lc619
	.byte	2
	.byte	.Lc620-.Lc619
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc621-.Lc620
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1613:
	.long	.Lc1616-.Lc1615
.Lc1615:
	.long	.Lc1180
	.quad	.Lc623
	.quad	.Lc622-.Lc623
	.byte	2
	.byte	.Lc624-.Lc623
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc625-.Lc624
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1616:
	.long	.Lc1619-.Lc1618
.Lc1618:
	.long	.Lc1180
	.quad	.Lc627
	.quad	.Lc626-.Lc627
	.byte	2
	.byte	.Lc628-.Lc627
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc629-.Lc628
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1619:
	.long	.Lc1622-.Lc1621
.Lc1621:
	.long	.Lc1180
	.quad	.Lc631
	.quad	.Lc630-.Lc631
	.byte	2
	.byte	.Lc632-.Lc631
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc633-.Lc632
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1622:
	.long	.Lc1625-.Lc1624
.Lc1624:
	.long	.Lc1180
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
.Lc1625:
	.long	.Lc1628-.Lc1627
.Lc1627:
	.long	.Lc1180
	.quad	.Lc639
	.quad	.Lc638-.Lc639
	.byte	2
	.byte	.Lc640-.Lc639
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc641-.Lc640
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1628:
	.long	.Lc1631-.Lc1630
.Lc1630:
	.long	.Lc1180
	.quad	.Lc643
	.quad	.Lc642-.Lc643
	.byte	2
	.byte	.Lc644-.Lc643
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc645-.Lc644
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1631:
	.long	.Lc1634-.Lc1633
.Lc1633:
	.long	.Lc1180
	.quad	.Lc647
	.quad	.Lc646-.Lc647
	.byte	2
	.byte	.Lc648-.Lc647
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc649-.Lc648
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1634:
	.long	.Lc1637-.Lc1636
.Lc1636:
	.long	.Lc1180
	.quad	.Lc651
	.quad	.Lc650-.Lc651
	.byte	2
	.byte	.Lc652-.Lc651
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc653-.Lc652
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc654-.Lc653
	.byte	5
	.uleb128	13
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc655-.Lc654
	.byte	5
	.uleb128	14
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc656-.Lc655
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc657-.Lc656
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc658-.Lc657
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc659-.Lc658
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc660-.Lc659
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1637:
	.long	.Lc1640-.Lc1639
.Lc1639:
	.long	.Lc1180
	.quad	.Lc662
	.quad	.Lc661-.Lc662
	.byte	2
	.byte	.Lc663-.Lc662
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc664-.Lc663
	.byte	5
	.uleb128	12
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc665-.Lc664
	.byte	5
	.uleb128	13
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc666-.Lc665
	.byte	5
	.uleb128	14
	.uleb128	12
	.byte	14
	.uleb128	48
	.byte	2
	.byte	.Lc667-.Lc666
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc668-.Lc667
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc669-.Lc668
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc670-.Lc669
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc671-.Lc670
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1640:
	.long	.Lc1643-.Lc1642
.Lc1642:
	.long	.Lc1180
	.quad	.Lc673
	.quad	.Lc672-.Lc673
	.byte	2
	.byte	.Lc674-.Lc673
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc675-.Lc674
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1643:
	.long	.Lc1646-.Lc1645
.Lc1645:
	.long	.Lc1180
	.quad	.Lc677
	.quad	.Lc676-.Lc677
	.byte	2
	.byte	.Lc678-.Lc677
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc679-.Lc678
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1646:
	.long	.Lc1649-.Lc1648
.Lc1648:
	.long	.Lc1180
	.quad	.Lc681
	.quad	.Lc680-.Lc681
	.byte	2
	.byte	.Lc682-.Lc681
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc683-.Lc682
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc684-.Lc683
	.byte	5
	.uleb128	13
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc685-.Lc684
	.byte	5
	.uleb128	14
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc686-.Lc685
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc687-.Lc686
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc688-.Lc687
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc689-.Lc688
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc690-.Lc689
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1649:
	.long	.Lc1652-.Lc1651
.Lc1651:
	.long	.Lc1180
	.quad	.Lc692
	.quad	.Lc691-.Lc692
	.byte	2
	.byte	.Lc693-.Lc692
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc694-.Lc693
	.byte	5
	.uleb128	12
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc695-.Lc694
	.byte	5
	.uleb128	13
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc696-.Lc695
	.byte	5
	.uleb128	14
	.uleb128	12
	.byte	14
	.uleb128	48
	.byte	2
	.byte	.Lc697-.Lc696
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc698-.Lc697
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc699-.Lc698
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc700-.Lc699
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc701-.Lc700
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1652:
	.long	.Lc1655-.Lc1654
.Lc1654:
	.long	.Lc1180
	.quad	.Lc703
	.quad	.Lc702-.Lc703
	.byte	2
	.byte	.Lc704-.Lc703
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc705-.Lc704
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc706-.Lc705
	.byte	5
	.uleb128	13
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc707-.Lc706
	.byte	5
	.uleb128	14
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc708-.Lc707
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc709-.Lc708
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc710-.Lc709
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc711-.Lc710
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc712-.Lc711
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1655:
	.long	.Lc1658-.Lc1657
.Lc1657:
	.long	.Lc1180
	.quad	.Lc714
	.quad	.Lc713-.Lc714
	.byte	2
	.byte	.Lc715-.Lc714
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc716-.Lc715
	.byte	5
	.uleb128	12
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc717-.Lc716
	.byte	5
	.uleb128	13
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc718-.Lc717
	.byte	5
	.uleb128	14
	.uleb128	12
	.byte	14
	.uleb128	48
	.byte	2
	.byte	.Lc719-.Lc718
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc720-.Lc719
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc721-.Lc720
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc722-.Lc721
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc723-.Lc722
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1658:
	.long	.Lc1661-.Lc1660
.Lc1660:
	.long	.Lc1180
	.quad	.Lc725
	.quad	.Lc724-.Lc725
	.byte	2
	.byte	.Lc726-.Lc725
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc727-.Lc726
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1661:
	.long	.Lc1664-.Lc1663
.Lc1663:
	.long	.Lc1180
	.quad	.Lc729
	.quad	.Lc728-.Lc729
	.byte	2
	.byte	.Lc730-.Lc729
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc731-.Lc730
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1664:
	.long	.Lc1667-.Lc1666
.Lc1666:
	.long	.Lc1180
	.quad	.Lc733
	.quad	.Lc732-.Lc733
	.byte	2
	.byte	.Lc734-.Lc733
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc735-.Lc734
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc736-.Lc735
	.byte	5
	.uleb128	13
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc737-.Lc736
	.byte	5
	.uleb128	14
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc738-.Lc737
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc739-.Lc738
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc740-.Lc739
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc741-.Lc740
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc742-.Lc741
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1667:
	.long	.Lc1670-.Lc1669
.Lc1669:
	.long	.Lc1180
	.quad	.Lc744
	.quad	.Lc743-.Lc744
	.byte	2
	.byte	.Lc745-.Lc744
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc746-.Lc745
	.byte	5
	.uleb128	12
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc747-.Lc746
	.byte	5
	.uleb128	13
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc748-.Lc747
	.byte	5
	.uleb128	14
	.uleb128	12
	.byte	14
	.uleb128	48
	.byte	2
	.byte	.Lc749-.Lc748
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc750-.Lc749
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc751-.Lc750
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc752-.Lc751
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc753-.Lc752
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1670:
	.long	.Lc1673-.Lc1672
.Lc1672:
	.long	.Lc1180
	.quad	.Lc755
	.quad	.Lc754-.Lc755
	.byte	2
	.byte	.Lc756-.Lc755
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc757-.Lc756
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc758-.Lc757
	.byte	5
	.uleb128	13
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc759-.Lc758
	.byte	5
	.uleb128	14
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc760-.Lc759
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc761-.Lc760
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc762-.Lc761
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc763-.Lc762
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc764-.Lc763
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1673:
	.long	.Lc1676-.Lc1675
.Lc1675:
	.long	.Lc1180
	.quad	.Lc766
	.quad	.Lc765-.Lc766
	.byte	2
	.byte	.Lc767-.Lc766
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc768-.Lc767
	.byte	5
	.uleb128	12
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc769-.Lc768
	.byte	5
	.uleb128	13
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc770-.Lc769
	.byte	5
	.uleb128	14
	.uleb128	12
	.byte	14
	.uleb128	48
	.byte	2
	.byte	.Lc771-.Lc770
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc772-.Lc771
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc773-.Lc772
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc774-.Lc773
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc775-.Lc774
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1676:
	.long	.Lc1679-.Lc1678
.Lc1678:
	.long	.Lc1180
	.quad	.Lc777
	.quad	.Lc776-.Lc777
	.byte	2
	.byte	.Lc778-.Lc777
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc779-.Lc778
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1679:
	.long	.Lc1682-.Lc1681
.Lc1681:
	.long	.Lc1180
	.quad	.Lc781
	.quad	.Lc780-.Lc781
	.byte	2
	.byte	.Lc782-.Lc781
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc783-.Lc782
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1682:
	.long	.Lc1685-.Lc1684
.Lc1684:
	.long	.Lc1180
	.quad	.Lc785
	.quad	.Lc784-.Lc785
	.byte	2
	.byte	.Lc786-.Lc785
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc787-.Lc786
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc788-.Lc787
	.byte	5
	.uleb128	13
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc789-.Lc788
	.byte	5
	.uleb128	14
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc790-.Lc789
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc791-.Lc790
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc792-.Lc791
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc793-.Lc792
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc794-.Lc793
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1685:
	.long	.Lc1688-.Lc1687
.Lc1687:
	.long	.Lc1180
	.quad	.Lc796
	.quad	.Lc795-.Lc796
	.byte	2
	.byte	.Lc797-.Lc796
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc798-.Lc797
	.byte	5
	.uleb128	12
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc799-.Lc798
	.byte	5
	.uleb128	13
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc800-.Lc799
	.byte	5
	.uleb128	14
	.uleb128	12
	.byte	14
	.uleb128	48
	.byte	2
	.byte	.Lc801-.Lc800
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc802-.Lc801
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc803-.Lc802
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc804-.Lc803
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc805-.Lc804
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1688:
	.long	.Lc1691-.Lc1690
.Lc1690:
	.long	.Lc1180
	.quad	.Lc807
	.quad	.Lc806-.Lc807
	.byte	2
	.byte	.Lc808-.Lc807
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc809-.Lc808
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc810-.Lc809
	.byte	5
	.uleb128	13
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc811-.Lc810
	.byte	5
	.uleb128	14
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc812-.Lc811
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc813-.Lc812
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc814-.Lc813
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc815-.Lc814
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc816-.Lc815
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1691:
	.long	.Lc1694-.Lc1693
.Lc1693:
	.long	.Lc1180
	.quad	.Lc818
	.quad	.Lc817-.Lc818
	.byte	2
	.byte	.Lc819-.Lc818
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc820-.Lc819
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc821-.Lc820
	.byte	5
	.uleb128	13
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc822-.Lc821
	.byte	5
	.uleb128	14
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc823-.Lc822
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc824-.Lc823
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc825-.Lc824
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc826-.Lc825
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc827-.Lc826
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1694:
	.long	.Lc1697-.Lc1696
.Lc1696:
	.long	.Lc1180
	.quad	.Lc829
	.quad	.Lc828-.Lc829
	.byte	2
	.byte	.Lc830-.Lc829
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc831-.Lc830
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc832-.Lc831
	.byte	5
	.uleb128	13
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc833-.Lc832
	.byte	5
	.uleb128	14
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc834-.Lc833
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc835-.Lc834
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc836-.Lc835
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc837-.Lc836
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc838-.Lc837
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1697:
	.long	.Lc1700-.Lc1699
.Lc1699:
	.long	.Lc1180
	.quad	.Lc840
	.quad	.Lc839-.Lc840
	.byte	2
	.byte	.Lc841-.Lc840
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc842-.Lc841
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc843-.Lc842
	.byte	5
	.uleb128	13
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc844-.Lc843
	.byte	5
	.uleb128	14
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc845-.Lc844
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc846-.Lc845
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc847-.Lc846
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc848-.Lc847
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc849-.Lc848
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1700:
	.long	.Lc1703-.Lc1702
.Lc1702:
	.long	.Lc1180
	.quad	.Lc851
	.quad	.Lc850-.Lc851
	.byte	2
	.byte	.Lc852-.Lc851
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc853-.Lc852
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc854-.Lc853
	.byte	5
	.uleb128	13
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc855-.Lc854
	.byte	5
	.uleb128	14
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc856-.Lc855
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc857-.Lc856
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc858-.Lc857
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc859-.Lc858
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc860-.Lc859
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1703:
	.long	.Lc1706-.Lc1705
.Lc1705:
	.long	.Lc1180
	.quad	.Lc862
	.quad	.Lc861-.Lc862
	.byte	2
	.byte	.Lc863-.Lc862
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc864-.Lc863
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc865-.Lc864
	.byte	5
	.uleb128	13
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc866-.Lc865
	.byte	5
	.uleb128	14
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc867-.Lc866
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc868-.Lc867
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc869-.Lc868
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc870-.Lc869
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc871-.Lc870
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1706:
	.long	.Lc1709-.Lc1708
.Lc1708:
	.long	.Lc1180
	.quad	.Lc873
	.quad	.Lc872-.Lc873
	.byte	2
	.byte	.Lc874-.Lc873
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc875-.Lc874
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc876-.Lc875
	.byte	5
	.uleb128	13
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc877-.Lc876
	.byte	5
	.uleb128	14
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc878-.Lc877
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc879-.Lc878
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc880-.Lc879
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc881-.Lc880
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc882-.Lc881
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1709:
	.long	.Lc1712-.Lc1711
.Lc1711:
	.long	.Lc1180
	.quad	.Lc884
	.quad	.Lc883-.Lc884
	.byte	2
	.byte	.Lc885-.Lc884
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc886-.Lc885
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc887-.Lc886
	.byte	5
	.uleb128	13
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc888-.Lc887
	.byte	5
	.uleb128	14
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc889-.Lc888
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc890-.Lc889
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc891-.Lc890
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc892-.Lc891
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc893-.Lc892
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1712:
	.long	.Lc1715-.Lc1714
.Lc1714:
	.long	.Lc1180
	.quad	.Lc895
	.quad	.Lc894-.Lc895
	.byte	2
	.byte	.Lc896-.Lc895
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc897-.Lc896
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc898-.Lc897
	.byte	5
	.uleb128	13
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc899-.Lc898
	.byte	5
	.uleb128	14
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc900-.Lc899
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc901-.Lc900
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc902-.Lc901
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc903-.Lc902
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc904-.Lc903
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1715:
	.long	.Lc1718-.Lc1717
.Lc1717:
	.long	.Lc1180
	.quad	.Lc906
	.quad	.Lc905-.Lc906
	.byte	2
	.byte	.Lc907-.Lc906
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc908-.Lc907
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc909-.Lc908
	.byte	5
	.uleb128	13
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc910-.Lc909
	.byte	5
	.uleb128	14
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc911-.Lc910
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc912-.Lc911
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc913-.Lc912
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc914-.Lc913
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc915-.Lc914
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1718:
	.long	.Lc1721-.Lc1720
.Lc1720:
	.long	.Lc1180
	.quad	.Lc917
	.quad	.Lc916-.Lc917
	.byte	2
	.byte	.Lc918-.Lc917
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc919-.Lc918
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc920-.Lc919
	.byte	5
	.uleb128	13
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc921-.Lc920
	.byte	5
	.uleb128	14
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc922-.Lc921
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc923-.Lc922
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc924-.Lc923
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc925-.Lc924
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc926-.Lc925
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1721:
	.long	.Lc1724-.Lc1723
.Lc1723:
	.long	.Lc1180
	.quad	.Lc928
	.quad	.Lc927-.Lc928
	.byte	2
	.byte	.Lc929-.Lc928
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc930-.Lc929
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc931-.Lc930
	.byte	5
	.uleb128	13
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc932-.Lc931
	.byte	5
	.uleb128	14
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc933-.Lc932
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc934-.Lc933
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc935-.Lc934
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc936-.Lc935
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc937-.Lc936
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1724:
	.long	.Lc1727-.Lc1726
.Lc1726:
	.long	.Lc1180
	.quad	.Lc939
	.quad	.Lc938-.Lc939
	.byte	2
	.byte	.Lc940-.Lc939
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc941-.Lc940
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1727:
	.long	.Lc1730-.Lc1729
.Lc1729:
	.long	.Lc1180
	.quad	.Lc943
	.quad	.Lc942-.Lc943
	.byte	4
	.long	.Lc944-.Lc943
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1730:
	.long	.Lc1733-.Lc1732
.Lc1732:
	.long	.Lc1180
	.quad	.Lc946
	.quad	.Lc945-.Lc946
	.byte	2
	.byte	.Lc947-.Lc946
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc948-.Lc947
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1733:
	.long	.Lc1736-.Lc1735
.Lc1735:
	.long	.Lc1180
	.quad	.Lc950
	.quad	.Lc949-.Lc950
	.byte	4
	.long	.Lc951-.Lc950
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1736:
	.long	.Lc1739-.Lc1738
.Lc1738:
	.long	.Lc1180
	.quad	.Lc953
	.quad	.Lc952-.Lc953
	.byte	4
	.long	.Lc954-.Lc953
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1739:
	.long	.Lc1742-.Lc1741
.Lc1741:
	.long	.Lc1180
	.quad	.Lc956
	.quad	.Lc955-.Lc956
	.byte	4
	.long	.Lc957-.Lc956
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1742:
	.long	.Lc1745-.Lc1744
.Lc1744:
	.long	.Lc1180
	.quad	.Lc959
	.quad	.Lc958-.Lc959
	.byte	4
	.long	.Lc960-.Lc959
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1745:
	.long	.Lc1748-.Lc1747
.Lc1747:
	.long	.Lc1180
	.quad	.Lc962
	.quad	.Lc961-.Lc962
	.byte	4
	.long	.Lc963-.Lc962
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1748:
	.long	.Lc1751-.Lc1750
.Lc1750:
	.long	.Lc1180
	.quad	.Lc965
	.quad	.Lc964-.Lc965
	.byte	4
	.long	.Lc966-.Lc965
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1751:
	.long	.Lc1754-.Lc1753
.Lc1753:
	.long	.Lc1180
	.quad	.Lc968
	.quad	.Lc967-.Lc968
	.byte	2
	.byte	.Lc969-.Lc968
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc970-.Lc969
	.byte	5
	.uleb128	12
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc971-.Lc970
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc972-.Lc971
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc973-.Lc972
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1754:
	.long	.Lc1757-.Lc1756
.Lc1756:
	.long	.Lc1180
	.quad	.Lc975
	.quad	.Lc974-.Lc975
	.byte	2
	.byte	.Lc976-.Lc975
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc977-.Lc976
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1757:
	.long	.Lc1760-.Lc1759
.Lc1759:
	.long	.Lc1180
	.quad	.Lc979
	.quad	.Lc978-.Lc979
	.byte	2
	.byte	.Lc980-.Lc979
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc981-.Lc980
	.byte	5
	.uleb128	12
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc982-.Lc981
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc983-.Lc982
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc984-.Lc983
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1760:
	.long	.Lc1763-.Lc1762
.Lc1762:
	.long	.Lc1180
	.quad	.Lc986
	.quad	.Lc985-.Lc986
	.byte	2
	.byte	.Lc987-.Lc986
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc988-.Lc987
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1763:
	.long	.Lc1766-.Lc1765
.Lc1765:
	.long	.Lc1180
	.quad	.Lc990
	.quad	.Lc989-.Lc990
	.byte	2
	.byte	.Lc991-.Lc990
	.byte	5
	.uleb128	3
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc992-.Lc991
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc993-.Lc992
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1766:
	.long	.Lc1769-.Lc1768
.Lc1768:
	.long	.Lc1180
	.quad	.Lc995
	.quad	.Lc994-.Lc995
	.byte	2
	.byte	.Lc996-.Lc995
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc997-.Lc996
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1769:
	.long	.Lc1772-.Lc1771
.Lc1771:
	.long	.Lc1180
	.quad	.Lc999
	.quad	.Lc998-.Lc999
	.byte	2
	.byte	.Lc1000-.Lc999
	.byte	5
	.uleb128	3
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc1001-.Lc1000
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc1002-.Lc1001
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1772:
	.long	.Lc1775-.Lc1774
.Lc1774:
	.long	.Lc1180
	.quad	.Lc1004
	.quad	.Lc1003-.Lc1004
	.byte	2
	.byte	.Lc1005-.Lc1004
	.byte	5
	.uleb128	3
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc1006-.Lc1005
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc1007-.Lc1006
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1775:
	.long	.Lc1778-.Lc1777
.Lc1777:
	.long	.Lc1180
	.quad	.Lc1009
	.quad	.Lc1008-.Lc1009
	.byte	2
	.byte	.Lc1010-.Lc1009
	.byte	5
	.uleb128	3
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc1011-.Lc1010
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc1012-.Lc1011
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1778:
	.long	.Lc1781-.Lc1780
.Lc1780:
	.long	.Lc1180
	.quad	.Lc1014
	.quad	.Lc1013-.Lc1014
	.byte	2
	.byte	.Lc1015-.Lc1014
	.byte	5
	.uleb128	3
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc1016-.Lc1015
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc1017-.Lc1016
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1781:
	.long	.Lc1784-.Lc1783
.Lc1783:
	.long	.Lc1180
	.quad	.Lc1019
	.quad	.Lc1018-.Lc1019
	.byte	2
	.byte	.Lc1020-.Lc1019
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc1021-.Lc1020
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1784:
	.long	.Lc1787-.Lc1786
.Lc1786:
	.long	.Lc1180
	.quad	.Lc1023
	.quad	.Lc1022-.Lc1023
	.byte	2
	.byte	.Lc1024-.Lc1023
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc1025-.Lc1024
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1787:
	.long	.Lc1790-.Lc1789
.Lc1789:
	.long	.Lc1180
	.quad	.Lc1027
	.quad	.Lc1026-.Lc1027
	.byte	4
	.long	.Lc1028-.Lc1027
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1790:
	.long	.Lc1793-.Lc1792
.Lc1792:
	.long	.Lc1180
	.quad	.Lc1030
	.quad	.Lc1029-.Lc1030
	.byte	2
	.byte	.Lc1031-.Lc1030
	.byte	5
	.uleb128	3
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc1032-.Lc1031
	.byte	5
	.uleb128	12
	.uleb128	12
	.byte	14
	.uleb128	48
	.byte	2
	.byte	.Lc1033-.Lc1032
	.byte	5
	.uleb128	13
	.uleb128	14
	.byte	14
	.uleb128	56
	.byte	2
	.byte	.Lc1034-.Lc1033
	.byte	14
	.uleb128	64
	.byte	4
	.long	.Lc1035-.Lc1034
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc1036-.Lc1035
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc1037-.Lc1036
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1793:
	.long	.Lc1796-.Lc1795
.Lc1795:
	.long	.Lc1180
	.quad	.Lc1039
	.quad	.Lc1038-.Lc1039
	.byte	2
	.byte	.Lc1040-.Lc1039
	.byte	5
	.uleb128	3
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc1041-.Lc1040
	.byte	5
	.uleb128	12
	.uleb128	12
	.byte	14
	.uleb128	48
	.byte	2
	.byte	.Lc1042-.Lc1041
	.byte	5
	.uleb128	13
	.uleb128	14
	.byte	14
	.uleb128	56
	.byte	2
	.byte	.Lc1043-.Lc1042
	.byte	5
	.uleb128	14
	.uleb128	16
	.byte	14
	.uleb128	64
	.byte	2
	.byte	.Lc1044-.Lc1043
	.byte	14
	.uleb128	64
	.byte	4
	.long	.Lc1045-.Lc1044
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc1046-.Lc1045
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc1047-.Lc1046
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc1048-.Lc1047
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1796:
	.long	.Lc1799-.Lc1798
.Lc1798:
	.long	.Lc1180
	.quad	.Lc1050
	.quad	.Lc1049-.Lc1050
	.byte	4
	.long	.Lc1051-.Lc1050
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1799:
	.long	.Lc1802-.Lc1801
.Lc1801:
	.long	.Lc1180
	.quad	.Lc1053
	.quad	.Lc1052-.Lc1053
	.byte	2
	.byte	.Lc1054-.Lc1053
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc1055-.Lc1054
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1802:
	.long	.Lc1805-.Lc1804
.Lc1804:
	.long	.Lc1180
	.quad	.Lc1057
	.quad	.Lc1056-.Lc1057
	.byte	2
	.byte	.Lc1058-.Lc1057
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc1059-.Lc1058
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc1060-.Lc1059
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc1061-.Lc1060
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc1062-.Lc1061
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1805:
	.long	.Lc1808-.Lc1807
.Lc1807:
	.long	.Lc1180
	.quad	.Lc1064
	.quad	.Lc1063-.Lc1064
	.byte	2
	.byte	.Lc1065-.Lc1064
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc1066-.Lc1065
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc1067-.Lc1066
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc1068-.Lc1067
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc1069-.Lc1068
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1808:
	.long	.Lc1811-.Lc1810
.Lc1810:
	.long	.Lc1180
	.quad	.Lc1071
	.quad	.Lc1070-.Lc1071
	.byte	2
	.byte	.Lc1072-.Lc1071
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc1073-.Lc1072
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1811:
	.long	.Lc1814-.Lc1813
.Lc1813:
	.long	.Lc1180
	.quad	.Lc1075
	.quad	.Lc1074-.Lc1075
	.byte	2
	.byte	.Lc1076-.Lc1075
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc1077-.Lc1076
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1814:
	.long	.Lc1817-.Lc1816
.Lc1816:
	.long	.Lc1180
	.quad	.Lc1079
	.quad	.Lc1078-.Lc1079
	.byte	2
	.byte	.Lc1080-.Lc1079
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc1081-.Lc1080
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1817:
	.long	.Lc1820-.Lc1819
.Lc1819:
	.long	.Lc1180
	.quad	.Lc1083
	.quad	.Lc1082-.Lc1083
	.byte	2
	.byte	.Lc1084-.Lc1083
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc1085-.Lc1084
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1820:
	.long	.Lc1823-.Lc1822
.Lc1822:
	.long	.Lc1180
	.quad	.Lc1087
	.quad	.Lc1086-.Lc1087
	.byte	2
	.byte	.Lc1088-.Lc1087
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc1089-.Lc1088
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc1090-.Lc1089
	.byte	5
	.uleb128	13
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc1091-.Lc1090
	.byte	5
	.uleb128	14
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc1092-.Lc1091
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc1093-.Lc1092
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc1094-.Lc1093
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc1095-.Lc1094
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc1096-.Lc1095
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1823:
	.long	.Lc1826-.Lc1825
.Lc1825:
	.long	.Lc1180
	.quad	.Lc1098
	.quad	.Lc1097-.Lc1098
	.byte	2
	.byte	.Lc1099-.Lc1098
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc1100-.Lc1099
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc1101-.Lc1100
	.byte	5
	.uleb128	13
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc1102-.Lc1101
	.byte	5
	.uleb128	14
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc1103-.Lc1102
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc1104-.Lc1103
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc1105-.Lc1104
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc1106-.Lc1105
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc1107-.Lc1106
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1826:
	.long	.Lc1829-.Lc1828
.Lc1828:
	.long	.Lc1180
	.quad	.Lc1109
	.quad	.Lc1108-.Lc1109
	.byte	2
	.byte	.Lc1110-.Lc1109
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc1111-.Lc1110
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc1112-.Lc1111
	.byte	5
	.uleb128	13
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc1113-.Lc1112
	.byte	5
	.uleb128	14
	.uleb128	10
	.byte	14
	.uleb128	40
	.byte	2
	.byte	.Lc1114-.Lc1113
	.byte	14
	.uleb128	48
	.byte	4
	.long	.Lc1115-.Lc1114
	.byte	6
	.uleb128	14
	.byte	2
	.byte	.Lc1116-.Lc1115
	.byte	6
	.uleb128	13
	.byte	2
	.byte	.Lc1117-.Lc1116
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc1118-.Lc1117
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1829:
	.long	.Lc1832-.Lc1831
.Lc1831:
	.long	.Lc1180
	.quad	.Lc1120
	.quad	.Lc1119-.Lc1120
	.byte	2
	.byte	.Lc1121-.Lc1120
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc1122-.Lc1121
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc1123-.Lc1122
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc1124-.Lc1123
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc1125-.Lc1124
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1832:
	.long	.Lc1835-.Lc1834
.Lc1834:
	.long	.Lc1180
	.quad	.Lc1127
	.quad	.Lc1126-.Lc1127
	.byte	2
	.byte	.Lc1128-.Lc1127
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc1129-.Lc1128
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc1130-.Lc1129
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc1131-.Lc1130
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc1132-.Lc1131
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1835:
	.long	.Lc1838-.Lc1837
.Lc1837:
	.long	.Lc1180
	.quad	.Lc1134
	.quad	.Lc1133-.Lc1134
	.byte	2
	.byte	.Lc1135-.Lc1134
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc1136-.Lc1135
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1838:
	.long	.Lc1841-.Lc1840
.Lc1840:
	.long	.Lc1180
	.quad	.Lc1138
	.quad	.Lc1137-.Lc1138
	.byte	2
	.byte	.Lc1139-.Lc1138
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc1140-.Lc1139
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1841:
	.long	.Lc1844-.Lc1843
.Lc1843:
	.long	.Lc1180
	.quad	.Lc1142
	.quad	.Lc1141-.Lc1142
	.byte	2
	.byte	.Lc1143-.Lc1142
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc1144-.Lc1143
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1844:
	.long	.Lc1847-.Lc1846
.Lc1846:
	.long	.Lc1180
	.quad	.Lc1146
	.quad	.Lc1145-.Lc1146
	.byte	2
	.byte	.Lc1147-.Lc1146
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc1148-.Lc1147
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1847:
	.long	.Lc1850-.Lc1849
.Lc1849:
	.long	.Lc1180
	.quad	.Lc1150
	.quad	.Lc1149-.Lc1150
	.byte	2
	.byte	.Lc1151-.Lc1150
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	2
	.byte	.Lc1152-.Lc1151
	.byte	5
	.uleb128	12
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc1153-.Lc1152
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc1154-.Lc1153
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc1155-.Lc1154
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1850:
	.long	.Lc1853-.Lc1852
.Lc1852:
	.long	.Lc1180
	.quad	.Lc1157
	.quad	.Lc1156-.Lc1157
	.byte	2
	.byte	.Lc1158-.Lc1157
	.byte	5
	.uleb128	3
	.uleb128	6
	.byte	14
	.uleb128	24
	.byte	2
	.byte	.Lc1159-.Lc1158
	.byte	5
	.uleb128	12
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc1160-.Lc1159
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc1161-.Lc1160
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc1162-.Lc1161
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1853:
	.long	.Lc1856-.Lc1855
.Lc1855:
	.long	.Lc1180
	.quad	.Lc1164
	.quad	.Lc1163-.Lc1164
	.byte	2
	.byte	.Lc1165-.Lc1164
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc1166-.Lc1165
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1856:
	.long	.Lc1859-.Lc1858
.Lc1858:
	.long	.Lc1180
	.quad	.Lc1168
	.quad	.Lc1167-.Lc1168
	.byte	2
	.byte	.Lc1169-.Lc1168
	.byte	5
	.uleb128	3
	.uleb128	8
	.byte	14
	.uleb128	32
	.byte	2
	.byte	.Lc1170-.Lc1169
	.byte	14
	.uleb128	32
	.byte	4
	.long	.Lc1171-.Lc1170
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1859:
	.long	.Lc1862-.Lc1861
.Lc1861:
	.long	.Lc1180
	.quad	.Lc1173
	.quad	.Lc1172-.Lc1173
	.byte	2
	.byte	.Lc1174-.Lc1173
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc1175-.Lc1174
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1862:
	.long	.Lc1865-.Lc1864
.Lc1864:
	.long	.Lc1180
	.quad	.Lc1177
	.quad	.Lc1176-.Lc1177
	.byte	2
	.byte	.Lc1178-.Lc1177
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc1179-.Lc1178
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc1865:
# End asmlist al_dwarf_frame
.section .note.GNU-stack,"",%progbits

