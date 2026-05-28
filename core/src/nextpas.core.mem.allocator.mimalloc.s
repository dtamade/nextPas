	.file "nextpas.core.mem.allocator.mimalloc.pas"
# Begin asmlist al_procedures

.section .text.n_nextpas.core.mem.allocator.mimalloc_$$_getplatformlibsubdir$$ansistring,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_GETPLATFORMLIBSUBDIR$$ANSISTRING
	.hidden NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_GETPLATFORMLIBSUBDIR$$ANSISTRING
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_GETPLATFORMLIBSUBDIR$$ANSISTRING,@function
NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_GETPLATFORMLIBSUBDIR$$ANSISTRING:
.Lc2:
# Temps allocated between rsp+0 and rsp+136
# [nextpas.core.mem.allocator.mimalloc.pas]
# [61] begin
	pushq	%rbx
.Lc3:
	leaq	-144(%rsp),%rsp
.Lc4:
	movq	%rdi,%rbx
# Var $result located in register rbx
	movq	$0,128(%rsp)
	movq	$0,120(%rsp)
	movq	%rsp,%rdx
	leaq	24(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,88(%rsp)
	testl	%eax,%eax
	jne	.Lj6
# [63] Result := LowerCase({$I %FPCTARGETCPU%}) + '-' + LowerCase({$I %FPCTARGETOS%});
	movq	$.Ld1,%rsi
	leaq	120(%rsp),%rdi
	call	SYSUTILS_$$_LOWERCASE$ANSISTRING$$ANSISTRING
	movq	120(%rsp),%rax
	movq	%rax,96(%rsp)
	movq	$.Ld2,%rax
	movq	%rax,104(%rsp)
	movq	$.Ld3,%rsi
	leaq	128(%rsp),%rdi
	call	SYSUTILS_$$_LOWERCASE$ANSISTRING$$ANSISTRING
	movq	128(%rsp),%rax
	movq	%rax,112(%rsp)
	leaq	96(%rsp),%rsi
	movq	%rbx,%rdi
	xorl	%ecx,%ecx
	movl	$2,%edx
	call	fpc_ansistr_concat_multi
.Lj6:
	call	fpc_popaddrstack
# [64] end;
	leaq	128(%rsp),%rdi
	call	fpc_ansistr_decr_ref
	leaq	120(%rsp),%rdi
	call	fpc_ansistr_decr_ref
	cmpl	$0,88(%rsp)
	je	.Lj5
	call	fpc_reraise
	movl	$0,88(%rsp)
	jmp	.Lj6
.Lj5:
	leaq	144(%rsp),%rsp
	popq	%rbx
.Lc5:
	ret
.Lc1:
.Le0:
	.size	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_GETPLATFORMLIBSUBDIR$$ANSISTRING, .Le0 - NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_GETPLATFORMLIBSUBDIR$$ANSISTRING

.section .text.n_nextpas.core.mem.allocator.mimalloc_$$_tryloadfrompath$ansistring$ansistring$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TRYLOADFROMPATH$ANSISTRING$ANSISTRING$$INT64
	.hidden NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TRYLOADFROMPATH$ANSISTRING$ANSISTRING$$INT64
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TRYLOADFROMPATH$ANSISTRING$ANSISTRING$$INT64,@function
NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TRYLOADFROMPATH$ANSISTRING$ANSISTRING$$INT64:
.Lc7:
# Temps allocated between rsp+8 and rsp+120
# [69] begin
	pushq	%rbx
.Lc8:
	pushq	%r12
.Lc9:
	leaq	-120(%rsp),%rsp
.Lc10:
# Var $result located in register rbx
# Var FullPath located at rsp+0, size=OS_64
	movq	%rdi,%rbx
# Var aBasePath located in register rbx
	movq	%rsi,%r12
# Var aLibName located in register r12
	movq	$0,(%rsp)
	movq	$0,112(%rsp)
	leaq	8(%rsp),%rdx
	leaq	32(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,96(%rsp)
	testl	%eax,%eax
	jne	.Lj11
# [70] FullPath := aBasePath + aLibName;
	movq	%rsp,%rdi
	xorl	%ecx,%ecx
	movq	%r12,%rdx
	movq	%rbx,%rsi
	call	fpc_ansistr_concat
# [71] Result := LoadLibrary(PChar(FullPath));
	movq	(%rsp),%rsi
	testq	%rsi,%rsi
	jne	.Lj13
	movq	$FPC_EMPTYCHAR,%rsi
.Lj13:
	leaq	112(%rsp),%rdi
	xorl	%edx,%edx
	call	fpc_pchar_to_ansistr
	movq	112(%rsp),%rdi
	movq	%rdi,104(%rsp)
	call	SYSTEM_$$_LOADLIBRARY$RAWBYTESTRING$$INT64
	movq	%rax,%rbx
.Lj11:
	call	fpc_popaddrstack
# [72] end;
	leaq	112(%rsp),%rdi
	call	fpc_ansistr_decr_ref
	movq	%rsp,%rdi
	call	fpc_ansistr_decr_ref
	cmpl	$0,96(%rsp)
	je	.Lj10
	call	fpc_reraise
	movl	$0,96(%rsp)
	jmp	.Lj11
.Lj10:
	movq	%rbx,%rax
	leaq	120(%rsp),%rsp
	popq	%r12
.Lc11:
	popq	%rbx
.Lc12:
	ret
.Lc6:
.Le1:
	.size	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TRYLOADFROMPATH$ANSISTRING$ANSISTRING$$INT64, .Le1 - NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TRYLOADFROMPATH$ANSISTRING$ANSISTRING$$INT64

.section .text.n_nextpas.core.mem.allocator.mimalloc_$$_tryloadmimalloclibrary$$int64,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TRYLOADMIMALLOCLIBRARY$$INT64
	.hidden NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TRYLOADMIMALLOCLIBRARY$$INT64
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TRYLOADMIMALLOCLIBRARY$$INT64,@function
NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TRYLOADMIMALLOCLIBRARY$$INT64:
.Lc14:
# Temps allocated between rsp+24 and rsp+184
# [77] begin
	pushq	%rbx
.Lc15:
	leaq	-192(%rsp),%rsp
.Lc16:
# Var $result located in register rbx
# Var EnvPath located at rsp+0, size=OS_64
# Var ExePath located at rsp+8, size=OS_64
# Var LibSubdir located at rsp+16, size=OS_64
	movq	$0,(%rsp)
	movq	$0,8(%rsp)
	movq	$0,16(%rsp)
	movq	$0,144(%rsp)
	movq	$0,136(%rsp)
	movq	$0,128(%rsp)
	leaq	24(%rsp),%rdx
	leaq	48(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,112(%rsp)
	testl	%eax,%eax
	jne	.Lj17
# [78] Result := 0;
	xorl	%ebx,%ebx
# [84] EnvPath := GetEnvironmentVariable('FAFAFA_MIMALLOC_SO');
	movq	$.Ld4,%rsi
	movq	%rsp,%rdi
	call	SYSUTILS_$$_GETENVIRONMENTVARIABLE$ANSISTRING$$ANSISTRING
# [86] if (EnvPath <> '') then
	cmpq	$0,(%rsp)
	je	.Lj20
# [88] Result := LoadLibrary(PChar(EnvPath));
	movq	(%rsp),%rsi
	testq	%rsi,%rsi
	jne	.Lj21
	movq	$FPC_EMPTYCHAR,%rsi
.Lj21:
	leaq	128(%rsp),%rdi
	xorl	%edx,%edx
	call	fpc_pchar_to_ansistr
	movq	128(%rsp),%rdi
	movq	%rdi,120(%rsp)
	call	SYSTEM_$$_LOADLIBRARY$RAWBYTESTRING$$INT64
	movq	%rax,%rbx
# [89] if Result <> 0 then Exit;
	testq	%rax,%rax
	jne	.Lj18
	.p2align 4,,10
	.p2align 3
.Lj20:
# [93] ExePath := ExtractFilePath(ParamStr(0));
	leaq	136(%rsp),%rdi
	xorl	%esi,%esi
	call	OBJPAS_$$_PARAMSTR$LONGINT$$ANSISTRING
	movq	136(%rsp),%rsi
	leaq	8(%rsp),%rdi
	call	SYSUTILS_$$_EXTRACTFILEPATH$RAWBYTESTRING$$RAWBYTESTRING
# [94] LibSubdir := GetPlatformLibSubdir;
	leaq	16(%rsp),%rdi
	call	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_GETPLATFORMLIBSUBDIR$$ANSISTRING
# [95] if LibSubdir <> '' then
	cmpq	$0,16(%rsp)
	je	.Lj25
# [102] Result := TryLoadFromPath(ExePath + 'lib' + DirectorySeparator + LibSubdir + DirectorySeparator, 'libmimalloc.so');
	leaq	144(%rsp),%rdi
	call	fpc_ansistr_decr_ref
	movq	8(%rsp),%rax
	movq	%rax,152(%rsp)
	movq	$.Ld5,%rax
	movq	%rax,160(%rsp)
	movq	16(%rsp),%rax
	movq	%rax,168(%rsp)
	movq	$.Ld6,%rax
	movq	%rax,176(%rsp)
	leaq	152(%rsp),%rsi
	leaq	144(%rsp),%rdi
	xorl	%ecx,%ecx
	movl	$3,%edx
	call	fpc_ansistr_concat_multi
	movq	144(%rsp),%rdi
	movq	$.Ld7,%rsi
	call	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TRYLOADFROMPATH$ANSISTRING$ANSISTRING$$INT64
	movq	%rax,%rbx
# [103] if Result = 0 then
	testq	%rax,%rax
	jne	.Lj27
# [104] Result := TryLoadFromPath(ExePath + 'lib' + DirectorySeparator + LibSubdir + DirectorySeparator, 'libmimalloc.so.2');
	leaq	144(%rsp),%rdi
	call	fpc_ansistr_decr_ref
	movq	8(%rsp),%rax
	movq	%rax,152(%rsp)
	movq	$.Ld5,%rax
	movq	%rax,160(%rsp)
	movq	16(%rsp),%rax
	movq	%rax,168(%rsp)
	movq	$.Ld6,%rax
	movq	%rax,176(%rsp)
	leaq	152(%rsp),%rsi
	leaq	144(%rsp),%rdi
	xorl	%ecx,%ecx
	movl	$3,%edx
	call	fpc_ansistr_concat_multi
	movq	144(%rsp),%rdi
	movq	$.Ld8,%rsi
	call	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TRYLOADFROMPATH$ANSISTRING$ANSISTRING$$INT64
	movq	%rax,%rbx
.Lj27:
# [106] if Result <> 0 then Exit;
	testq	%rbx,%rbx
	jne	.Lj18
	.p2align 4,,10
	.p2align 3
.Lj25:
# [114] Result := LoadLibrary('libmimalloc.so');
	movq	$.Ld7,%rdi
	call	SYSTEM_$$_LOADLIBRARY$RAWBYTESTRING$$INT64
	movq	%rax,%rbx
# [115] if Result = 0 then Result := LoadLibrary('libmimalloc.so.2');
	testq	%rax,%rax
	jne	.Lj31
	movq	$.Ld8,%rdi
	call	SYSTEM_$$_LOADLIBRARY$RAWBYTESTRING$$INT64
	movq	%rax,%rbx
.Lj31:
# [116] if Result = 0 then Result := LoadLibrary('mimalloc');
	testq	%rbx,%rbx
	jne	.Lj33
	movq	$.Ld9,%rdi
	call	SYSTEM_$$_LOADLIBRARY$RAWBYTESTRING$$INT64
	movq	%rax,%rbx
.Lj33:
.Lj17:
	call	fpc_popaddrstack
# [118] end;
	leaq	144(%rsp),%rdi
	call	fpc_ansistr_decr_ref
	leaq	136(%rsp),%rdi
	call	fpc_ansistr_decr_ref
	leaq	128(%rsp),%rdi
	call	fpc_ansistr_decr_ref
	movq	%rsp,%rdi
	call	fpc_ansistr_decr_ref
	leaq	8(%rsp),%rdi
	call	fpc_ansistr_decr_ref
	leaq	16(%rsp),%rdi
	call	fpc_ansistr_decr_ref
	cmpl	$0,112(%rsp)
	je	.Lj16
	call	fpc_reraise
.Lj18:
	movl	$0,112(%rsp)
	jmp	.Lj17
.Lj16:
	movq	%rbx,%rax
	leaq	192(%rsp),%rsp
	popq	%rbx
.Lc17:
	ret
.Lc13:
.Le2:
	.size	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TRYLOADMIMALLOCLIBRARY$$INT64, .Le2 - NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TRYLOADMIMALLOCLIBRARY$$INT64

.section .text.n_nextpas.core.mem.allocator.mimalloc_$$_ensuremimallocloaded$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_ENSUREMIMALLOCLOADED$$BOOLEAN
	.hidden NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_ENSUREMIMALLOCLOADED$$BOOLEAN
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_ENSUREMIMALLOCLOADED$$BOOLEAN,@function
NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_ENSUREMIMALLOCLOADED$$BOOLEAN:
.Lc19:
# Temps allocated between rsp+16 and rsp+108
# [123] begin
	leaq	-120(%rsp),%rsp
.Lc20:
# Var $result located at rsp+0, size=OS_8
# Var LLib located at rsp+8, size=OS_S64
# [124] if _miLoaded then Exit(True);
	cmpb	$0,TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MILOADED
	je	.Lj37
	movb	$1,(%rsp)
	jmp	.Lj34
	.p2align 4,,10
	.p2align 3
.Lj37:
# [125] EnterCriticalSection(GLoadLock);
	movq	$U_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_GLOADLOCK,%rdi
	call	SYSTEM_$$_ENTERCRITICALSECTION$TRTLCRITICALSECTION
# [126] try
	leaq	16(%rsp),%rdx
	leaq	40(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,104(%rsp)
	testl	%eax,%eax
	jne	.Lj39
# [127] if _miLoaded then Exit(True);
	cmpb	$0,TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MILOADED
	je	.Lj42
	movb	$1,(%rsp)
	jmp	.Lj40
	.p2align 4,,10
	.p2align 3
.Lj42:
# [129] LLib := TryLoadMimallocLibrary;
	call	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TRYLOADMIMALLOCLIBRARY$$INT64
	movq	%rax,8(%rsp)
# [130] if LLib = 0 then Exit(False);
	testq	%rax,%rax
	jne	.Lj44
	movb	$0,(%rsp)
	jmp	.Lj40
	.p2align 4,,10
	.p2align 3
.Lj44:
# [131] _miLib := LLib;
	movq	8(%rsp),%rax
	movq	%rax,TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MILIB
# [132] Pointer(_mi_malloc) := GetProcedureAddress(_miLib, 'mi_malloc');
	movq	$.Ld10,%rsi
	movq	TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MILIB,%rdi
	call	SYSTEM_$$_GETPROCEDUREADDRESS$INT64$ANSISTRING$$POINTER
	movq	%rax,TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MI_MALLOC
# [133] Pointer(_mi_calloc) := GetProcedureAddress(_miLib, 'mi_calloc');
	movq	$.Ld11,%rsi
	movq	TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MILIB,%rdi
	call	SYSTEM_$$_GETPROCEDUREADDRESS$INT64$ANSISTRING$$POINTER
	movq	%rax,TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MI_CALLOC
# [134] Pointer(_mi_realloc) := GetProcedureAddress(_miLib, 'mi_realloc');
	movq	$.Ld12,%rsi
	movq	TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MILIB,%rdi
	call	SYSTEM_$$_GETPROCEDUREADDRESS$INT64$ANSISTRING$$POINTER
	movq	%rax,TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MI_REALLOC
# [135] Pointer(_mi_free) := GetProcedureAddress(_miLib, 'mi_free');
	movq	$.Ld13,%rsi
	movq	TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MILIB,%rdi
	call	SYSTEM_$$_GETPROCEDUREADDRESS$INT64$ANSISTRING$$POINTER
	movq	%rax,TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MI_FREE
# [136] _miLoaded := Assigned(_mi_malloc) and Assigned(_mi_calloc) and Assigned(_mi_realloc) and Assigned(_mi_free);
	cmpq	$0,TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MI_MALLOC
	setneb	%al
	cmpq	$0,TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MI_CALLOC
	setneb	%dl
	andb	%dl,%al
	cmpq	$0,TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MI_REALLOC
	setneb	%dl
	andb	%dl,%al
	cmpq	$0,TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MI_FREE
	setneb	%dl
	andb	%dl,%al
	movb	%al,TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MILOADED
# [137] if not _miLoaded then
	testb	%al,%al
	jne	.Lj46
# [139] FreeLibrary(_miLib);
	movq	TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MILIB,%rdi
	call	SYSTEM_$$_UNLOADLIBRARY$INT64$$BOOLEAN
	movb	%al,%dl
# [140] _miLib := 0;
	movq	$0,TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MILIB
.Lj46:
# [142] Result := _miLoaded;
	movb	TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MILOADED,%al
	movb	%al,(%rsp)
.Lj39:
	call	fpc_popaddrstack
# [144] LeaveCriticalSection(GLoadLock);
	movq	$U_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_GLOADLOCK,%rdi
	call	SYSTEM_$$_LEAVECRITICALSECTION$TRTLCRITICALSECTION
	movl	104(%rsp),%eax
	testl	%eax,%eax
	je	.Lj38
	cmpl	$2,%eax
	je	.Lj34
	call	fpc_reraise
.Lj40:
	movl	$2,104(%rsp)
	jmp	.Lj39
.Lj38:
.Lj34:
# [146] end;
	movb	(%rsp),%al
	leaq	120(%rsp),%rsp
.Lc21:
	ret
.Lc18:
.Le3:
	.size	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_ENSUREMIMALLOCLOADED$$BOOLEAN, .Le3 - NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_ENSUREMIMALLOCLOADED$$BOOLEAN

.section .text.n_nextpas.core.mem.allocator.mimalloc$_$tmimallocallocator_$__$$_dogetmem$qword$$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC$_$TMIMALLOCALLOCATOR_$__$$_DOGETMEM$QWORD$$POINTER
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC$_$TMIMALLOCALLOCATOR_$__$$_DOGETMEM$QWORD$$POINTER,@function
NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC$_$TMIMALLOCALLOCATOR_$__$$_DOGETMEM$QWORD$$POINTER:
.Lc23:
# Temps allocated between rbp-8 and rbp+0
# [155] begin
	pushq	%rbp
.Lc24:
	movq	%rsp,%rbp
.Lc25:
	leaq	-16(%rsp),%rsp
	movq	%rbx,-8(%rbp)
# Var $self located in register rdi
	movq	%rsi,%rbx
# Var aSize located in register rbx
# [156] if not EnsureMimallocLoaded then
	call	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_ENSUREMIMALLOCLOADED$$BOOLEAN
	testb	%al,%al
	jne	.Lj50
.Lj51:
# [157] raise Exception.Create('mimalloc not available: cannot load library');
	movq	$.Ld14,%rdx
	movq	$VMT_$SYSUTILS_$$_EXCEPTION,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj51,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj50:
# [158] Result := _mi_malloc(aSize);
	movq	%rbx,%rdi
# Var aSize located in register rdi
	call	*TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MI_MALLOC
# Var $result located in register rax
# [159] end;
	movq	-8(%rbp),%rbx
.Lc26:
	movq	%rbp,%rsp
.Lc27:
	popq	%rbp
	ret
.Lc22:
.Le4:
	.size	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC$_$TMIMALLOCALLOCATOR_$__$$_DOGETMEM$QWORD$$POINTER, .Le4 - NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC$_$TMIMALLOCALLOCATOR_$__$$_DOGETMEM$QWORD$$POINTER

.section .text.n_nextpas.core.mem.allocator.mimalloc$_$tmimallocallocator_$__$$_doallocmem$qword$$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC$_$TMIMALLOCALLOCATOR_$__$$_DOALLOCMEM$QWORD$$POINTER
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC$_$TMIMALLOCALLOCATOR_$__$$_DOALLOCMEM$QWORD$$POINTER,@function
NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC$_$TMIMALLOCALLOCATOR_$__$$_DOALLOCMEM$QWORD$$POINTER:
.Lc29:
# Temps allocated between rbp-8 and rbp+0
# [162] begin
	pushq	%rbp
.Lc30:
	movq	%rsp,%rbp
.Lc31:
	leaq	-16(%rsp),%rsp
	movq	%rbx,-8(%rbp)
# Var $self located in register rdi
	movq	%rsi,%rbx
# Var aSize located in register rbx
# [163] if not EnsureMimallocLoaded then
	call	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_ENSUREMIMALLOCLOADED$$BOOLEAN
	testb	%al,%al
	jne	.Lj55
.Lj56:
# [164] raise Exception.Create('mimalloc not available: cannot load library');
	movq	$.Ld14,%rdx
	movq	$VMT_$SYSUTILS_$$_EXCEPTION,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj56,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj55:
# [165] Result := _mi_calloc(1, aSize);
	movq	%rbx,%rsi
# Var aSize located in register rsi
	movl	$1,%edi
	call	*TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MI_CALLOC
# Var $result located in register rax
# [166] end;
	movq	-8(%rbp),%rbx
.Lc32:
	movq	%rbp,%rsp
.Lc33:
	popq	%rbp
	ret
.Lc28:
.Le5:
	.size	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC$_$TMIMALLOCALLOCATOR_$__$$_DOALLOCMEM$QWORD$$POINTER, .Le5 - NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC$_$TMIMALLOCALLOCATOR_$__$$_DOALLOCMEM$QWORD$$POINTER

.section .text.n_nextpas.core.mem.allocator.mimalloc$_$tmimallocallocator_$__$$_doreallocmem$pointer$qword$$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC$_$TMIMALLOCALLOCATOR_$__$$_DOREALLOCMEM$POINTER$QWORD$$POINTER
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC$_$TMIMALLOCALLOCATOR_$__$$_DOREALLOCMEM$POINTER$QWORD$$POINTER,@function
NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC$_$TMIMALLOCALLOCATOR_$__$$_DOREALLOCMEM$POINTER$QWORD$$POINTER:
.Lc35:
# Temps allocated between rbp-16 and rbp+0
# [169] begin
	pushq	%rbp
.Lc36:
	movq	%rsp,%rbp
.Lc37:
	leaq	-16(%rsp),%rsp
	movq	%rbx,-16(%rbp)
	movq	%r12,-8(%rbp)
# Var $self located in register rdi
	movq	%rsi,%rbx
# Var aDst located in register rbx
	movq	%rdx,%r12
# Var aSize located in register r12
# [170] if not EnsureMimallocLoaded then
	call	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_ENSUREMIMALLOCLOADED$$BOOLEAN
	testb	%al,%al
	jne	.Lj60
.Lj61:
# [171] raise Exception.Create('mimalloc not available: cannot load library');
	movq	$.Ld14,%rdx
	movq	$VMT_$SYSUTILS_$$_EXCEPTION,%rdi
	movl	$1,%esi
	call	SYSUTILS$_$EXCEPTION_$__$$_CREATE$ANSISTRING$$EXCEPTION
	movq	%rax,%rdi
	movq	$.Lj61,%rsi
	movq	%rbp,%rdx
	call	fpc_raiseexception
.Lj60:
# [172] Result := _mi_realloc(aDst, aSize);
	movq	%r12,%rsi
# Var aSize located in register rsi
	movq	%rbx,%rdi
# Var aDst located in register rdi
	call	*TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MI_REALLOC
# Var $result located in register rax
# [173] end;
	movq	-16(%rbp),%rbx
	movq	-8(%rbp),%r12
.Lc38:
	movq	%rbp,%rsp
.Lc39:
	popq	%rbp
	ret
.Lc34:
.Le6:
	.size	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC$_$TMIMALLOCALLOCATOR_$__$$_DOREALLOCMEM$POINTER$QWORD$$POINTER, .Le6 - NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC$_$TMIMALLOCALLOCATOR_$__$$_DOREALLOCMEM$POINTER$QWORD$$POINTER

.section .text.n_nextpas.core.mem.allocator.mimalloc$_$tmimallocallocator_$__$$_dofreemem$pointer,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC$_$TMIMALLOCALLOCATOR_$__$$_DOFREEMEM$POINTER
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC$_$TMIMALLOCALLOCATOR_$__$$_DOFREEMEM$POINTER,@function
NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC$_$TMIMALLOCALLOCATOR_$__$$_DOFREEMEM$POINTER:
.Lc41:
# [176] begin
	pushq	%rbx
.Lc42:
# Var $self located in register rdi
	movq	%rsi,%rbx
# Var aDst located in register rbx
# [177] if not EnsureMimallocLoaded then
	call	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_ENSUREMIMALLOCLOADED$$BOOLEAN
	testb	%al,%al
	je	.Lj62
# [179] _mi_free(aDst);
	movq	%rbx,%rdi
# Var aDst located in register rdi
	call	*TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MI_FREE
.Lj62:
# [180] end;
	popq	%rbx
.Lc43:
	ret
.Lc40:
.Le7:
	.size	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC$_$TMIMALLOCALLOCATOR_$__$$_DOFREEMEM$POINTER, .Le7 - NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC$_$TMIMALLOCALLOCATOR_$__$$_DOFREEMEM$POINTER

.section .text.n_nextpas.core.mem.allocator.mimalloc$_$tmimallocallocator_$__$$_traits$$tallocatortraits,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC$_$TMIMALLOCALLOCATOR_$__$$_TRAITS$$TALLOCATORTRAITS
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC$_$TMIMALLOCALLOCATOR_$__$$_TRAITS$$TALLOCATORTRAITS,@function
NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC$_$TMIMALLOCALLOCATOR_$__$$_TRAITS$$TALLOCATORTRAITS:
.Lc45:
# [183] begin
	pushq	%rax
.Lc46:
# Var $result located at rsp+0, size=OS_32
# Var $self located in register rdi
# Var $self located in register rdi
# [184] Result := inherited Traits;
	call	NEXTPAS.CORE.MEM.ALLOCATOR.BASE$_$TALLOCATOR_$__$$_TRAITS$$TALLOCATORTRAITS
	movl	%eax,(%rsp)
# [189] Result.ZeroInitialized := True;
	movb	$1,(%rsp)
# [190] Result.SupportsAligned := False;
	movb	$0,3(%rsp)
# [191] Result.HasMemSize      := False;
	movb	$0,2(%rsp)
# [192] end;
	movl	(%rsp),%eax
	popq	%rcx
.Lc47:
	ret
.Lc44:
.Le8:
	.size	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC$_$TMIMALLOCALLOCATOR_$__$$_TRAITS$$TALLOCATORTRAITS, .Le8 - NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC$_$TMIMALLOCALLOCATOR_$__$$_TRAITS$$TALLOCATORTRAITS

.section .text.n_nextpas.core.mem.allocator.mimalloc_$$_getmimallocallocator$$iallocator,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_GETMIMALLOCALLOCATOR$$IALLOCATOR
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_GETMIMALLOCALLOCATOR$$IALLOCATOR,@function
NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_GETMIMALLOCALLOCATOR$$IALLOCATOR:
.Lc49:
# Temps allocated between rsp+8 and rsp+208
# [195] begin
	leaq	-216(%rsp),%rsp
.Lc50:
# Var $result located at rsp+0, size=OS_64
	movq	%rdi,(%rsp)
	movq	$0,200(%rsp)
	leaq	8(%rsp),%rdx
	leaq	32(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,96(%rsp)
	testl	%eax,%eax
	jne	.Lj71
# [196] if _MimallocAllocatorObj = nil then
	cmpq	$0,TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MIMALLOCALLOCATOROBJ
	jne	.Lj74
# [198] EnterCriticalSection(GAllocatorLock);
	movq	$U_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_GALLOCATORLOCK,%rdi
	call	SYSTEM_$$_ENTERCRITICALSECTION$TRTLCRITICALSECTION
# [199] try
	leaq	104(%rsp),%rdx
	leaq	128(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,192(%rsp)
	testl	%eax,%eax
	jne	.Lj76
# [200] if _MimallocAllocatorObj = nil then
	cmpq	$0,TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MIMALLOCALLOCATOROBJ
	jne	.Lj79
# [202] _MimallocAllocatorObj := TMimallocAllocator.Create;
	movq	$VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR,%rdi
	movl	$1,%esi
	call	SYSTEM$_$TOBJECT_$__$$_CREATE$$TOBJECT
	movq	%rax,TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MIMALLOCALLOCATOROBJ
# [203] _MimallocAllocatorIntf := _MimallocAllocatorObj as IAllocator; // anchor lifetime
	movq	.Ld15,%rdx
	movq	.Ld15+8,%rcx
	movq	TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MIMALLOCALLOCATOROBJ,%rsi
	leaq	200(%rsp),%rdi
	call	fpc_class_as_intf
	movq	200(%rsp),%rsi
	movq	$TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MIMALLOCALLOCATORINTF,%rdi
	call	fpc_intf_assign
.Lj79:
.Lj76:
	call	fpc_popaddrstack
# [206] LeaveCriticalSection(GAllocatorLock);
	movq	$U_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_GALLOCATORLOCK,%rdi
	call	SYSTEM_$$_LEAVECRITICALSECTION$TRTLCRITICALSECTION
	cmpl	$0,192(%rsp)
	je	.Lj75
	call	fpc_reraise
.Lj75:
.Lj74:
# [209] Result := _MimallocAllocatorIntf;
	movq	TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MIMALLOCALLOCATORINTF,%rsi
	movq	(%rsp),%rdi
	call	fpc_intf_assign
.Lj71:
	call	fpc_popaddrstack
# [210] end;
	leaq	200(%rsp),%rdi
	call	fpc_intf_decr_ref
	cmpl	$0,96(%rsp)
	je	.Lj70
	call	fpc_reraise
	movl	$0,96(%rsp)
	jmp	.Lj71
.Lj70:
	leaq	216(%rsp),%rsp
.Lc51:
	ret
.Lc48:
.Le9:
	.size	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_GETMIMALLOCALLOCATOR$$IALLOCATOR, .Le9 - NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_GETMIMALLOCALLOCATOR$$IALLOCATOR

.section .text.n_nextpas.core.mem.allocator.mimalloc_$$_trygetmimallocallocator$iallocator$$boolean,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TRYGETMIMALLOCALLOCATOR$IALLOCATOR$$BOOLEAN
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TRYGETMIMALLOCALLOCATOR$IALLOCATOR$$BOOLEAN,@function
NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TRYGETMIMALLOCALLOCATOR$IALLOCATOR$$BOOLEAN:
.Lc53:
# Temps allocated between rsp+12 and rsp+308
# [212] begin
	leaq	-312(%rsp),%rsp
.Lc54:
# Var A located at rsp+0, size=OS_64
# Var $result located at rsp+8, size=OS_8
	movq	%rdi,(%rsp)
	movq	$0,(%rdi)
	movq	$0,208(%rsp)
	leaq	16(%rsp),%rdx
	leaq	40(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,104(%rsp)
	testl	%eax,%eax
	jne	.Lj83
# [213] try
	leaq	112(%rsp),%rdx
	leaq	136(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,200(%rsp)
	testl	%eax,%eax
	jne	.Lj89
# [214] A := GetMimallocAllocator;
	leaq	208(%rsp),%rdi
	call	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_GETMIMALLOCALLOCATOR$$IALLOCATOR
	movq	208(%rsp),%rsi
	movq	(%rsp),%rdi
	call	fpc_intf_assign
# [215] Result := True;
	movb	$1,8(%rsp)
.Lj89:
	call	fpc_popaddrstack
	cmpl	$0,200(%rsp)
	je	.Lj87
	leaq	216(%rsp),%rdx
	leaq	240(%rsp),%rsi
	movl	$1,%edi
	call	fpc_pushexceptaddr
	movq	%rax,%rdi
	call	fpc_setjmp
	movl	%eax,304(%rsp)
	testl	%eax,%eax
	jne	.Lj90
# [217] A := nil;
	movq	(%rsp),%rdi
	xorl	%esi,%esi
	call	fpc_intf_assign
# [218] Result := False;
	movb	$0,8(%rsp)
.Lj90:
	call	fpc_popaddrstack
	cmpl	$0,304(%rsp)
	je	.Lj91
	call	fpc_raise_nested
.Lj91:
	call	fpc_doneexception
.Lj87:
.Lj83:
	call	fpc_popaddrstack
# [220] end;
	leaq	208(%rsp),%rdi
	call	fpc_intf_decr_ref
	cmpl	$0,104(%rsp)
	je	.Lj82
	call	fpc_reraise
	movl	$0,104(%rsp)
	jmp	.Lj83
.Lj82:
	movb	8(%rsp),%al
	leaq	312(%rsp),%rsp
.Lc55:
	ret
.Lc52:

.section .text.n_nextpas.core.mem.allocator.mimalloc_$$_init$,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_init$
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_init$,@function
NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_init$:
.globl	INIT$_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC
	.type	INIT$_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC,@function
INIT$_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC:
.Lc57:
# [222] initialization
	pushq	%rax
.Lc58:
# [224] InitCriticalSection(GLoadLock);
	movq	$U_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_GLOADLOCK,%rdi
	call	SYSTEM_$$_INITCRITICALSECTION$TRTLCRITICALSECTION
# [226] InitCriticalSection(GAllocatorLock);
	movq	$U_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_GALLOCATORLOCK,%rdi
	call	SYSTEM_$$_INITCRITICALSECTION$TRTLCRITICALSECTION
# [220] end;
	popq	%rcx
.Lc59:
	ret
.Lc56:

.section .text.n_nextpas.core.mem.allocator.mimalloc_$$_finalize$,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_finalize$
	.type	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_finalize$,@function
NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_finalize$:
.globl	FINALIZE$_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC
	.type	FINALIZE$_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC,@function
FINALIZE$_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC:
.Lc61:
# [227] finalization
	pushq	%rax
.Lc62:
# [228] DoneCriticalSection(GAllocatorLock);
	movq	$U_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_GALLOCATORLOCK,%rdi
	call	SYSTEM_$$_DONECRITICALSECTION$TRTLCRITICALSECTION
# [230] DoneCriticalSection(GLoadLock);
	movq	$U_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_GLOADLOCK,%rdi
	call	SYSTEM_$$_DONECRITICALSECTION$TRTLCRITICALSECTION
# [232] _MimallocAllocatorIntf := nil;
	movq	$TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MIMALLOCALLOCATORINTF,%rdi
	xorl	%esi,%esi
	call	fpc_intf_assign
# [233] _MimallocAllocatorObj := nil;
	movq	$0,TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MIMALLOCALLOCATOROBJ
# [235] if _miLib <> 0 then
	cmpq	$0,TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MILIB
	je	.Lj95
# [236] FreeLibrary(_miLib);
	movq	TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MILIB,%rdi
	call	SYSTEM_$$_UNLOADLIBRARY$INT64$$BOOLEAN
	movb	%al,%dl
.Lj95:
# [237] _miLib := 0;
	movq	$0,TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MILIB
# [241] end.
	movq	$TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MIMALLOCALLOCATORINTF,%rdi
	call	fpc_intf_decr_ref
	popq	%rcx
.Lc63:
	ret
.Lc60:
# End asmlist al_procedures
# Begin asmlist al_globals

.section .bss,"aw",%nobits
	.balign 8
# [58] GLoadLock: TRTLCriticalSection;
	.hidden U_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_GLOADLOCK
	.globl U_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_GLOADLOCK
	.type U_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_GLOADLOCK,@object
	.size U_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_GLOADLOCK,40
U_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_GLOADLOCK:
	.zero 40

.section .bss,"aw",%nobits
	.balign 8
# [152] GAllocatorLock: TRTLCriticalSection;
	.hidden U_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_GALLOCATORLOCK
	.globl U_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_GALLOCATORLOCK
	.type U_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_GALLOCATORLOCK,@object
	.size U_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_GALLOCATORLOCK,40
U_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_GALLOCATORLOCK:
	.zero 40

.section .rodata.n_VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR
	.balign 8
.globl	VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR
	.type	VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR,@object
VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR:
	.quad	40,-40
	.quad	VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR$indirect
	.quad	.Ld16
	.quad	0,0,0
	.quad	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR
	.quad	0,0
	.quad	.Ld17
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
	.quad	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC$_$TMIMALLOCALLOCATOR_$__$$_DOGETMEM$QWORD$$POINTER
	.quad	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC$_$TMIMALLOCALLOCATOR_$__$$_DOALLOCMEM$QWORD$$POINTER
	.quad	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC$_$TMIMALLOCALLOCATOR_$__$$_DOREALLOCMEM$POINTER$QWORD$$POINTER
	.quad	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC$_$TMIMALLOCALLOCATOR_$__$$_DOFREEMEM$POINTER
	.quad	NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC$_$TMIMALLOCALLOCATOR_$__$$_TRAITS$$TALLOCATORTRAITS
	.quad	0
# [241] end.
.Le10:
	.size	VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR, .Le10 - VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR
# End asmlist al_globals
# Begin asmlist al_const

.section .rodata.n_VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR
	.balign 8
.Ld16:
	.byte	18
	.ascii	"TMimallocAllocator"
.Le11:
	.size	.Ld16, .Le11 - .Ld16

.section .rodata.n_VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR
	.balign 8
.Ld17:
	.quad	0
.Le12:
	.size	.Ld17, .Le12 - .Ld17
# End asmlist al_const
# Begin asmlist al_typedconsts

.section .data.n_TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MILIB
	.balign 8
.globl	TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MILIB
	.hidden TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MILIB
	.type	TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MILIB,@object
TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MILIB:
	.quad	0
# [53] _miLoaded: Boolean = False;
.Le13:
	.size	TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MILIB, .Le13 - TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MILIB

.section .data.n_TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MILOADED
.globl	TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MILOADED
	.hidden TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MILOADED
	.type	TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MILOADED,@object
TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MILOADED:
	.byte	0
# [54] _mi_malloc: function(aSize: SizeUInt): Pointer; cdecl = nil;
.Le14:
	.size	TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MILOADED, .Le14 - TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MILOADED

.section .data.n_TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MI_MALLOC
	.balign 8
.globl	TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MI_MALLOC
	.hidden TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MI_MALLOC
	.type	TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MI_MALLOC,@object
TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MI_MALLOC:
	.quad	0
# [55] _mi_calloc: function(aCount, aSize: SizeUInt): Pointer; cdecl = nil;
.Le15:
	.size	TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MI_MALLOC, .Le15 - TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MI_MALLOC

.section .data.n_TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MI_CALLOC
	.balign 8
.globl	TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MI_CALLOC
	.hidden TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MI_CALLOC
	.type	TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MI_CALLOC,@object
TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MI_CALLOC:
	.quad	0
# [56] _mi_realloc: function(aPtr: Pointer; aNewSize: SizeUInt): Pointer; cdecl = nil;
.Le16:
	.size	TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MI_CALLOC, .Le16 - TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MI_CALLOC

.section .data.n_TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MI_REALLOC
	.balign 8
.globl	TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MI_REALLOC
	.hidden TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MI_REALLOC
	.type	TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MI_REALLOC,@object
TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MI_REALLOC:
	.quad	0
# [57] _mi_free: procedure(aPtr: Pointer); cdecl = nil;
.Le17:
	.size	TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MI_REALLOC, .Le17 - TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MI_REALLOC

.section .data.n_TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MI_FREE
	.balign 8
.globl	TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MI_FREE
	.hidden TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MI_FREE
	.type	TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MI_FREE,@object
TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MI_FREE:
	.quad	0
# [58] GLoadLock: TRTLCriticalSection;
.Le18:
	.size	TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MI_FREE, .Le18 - TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MI_FREE

.section .rodata.n_.Ld1
	.balign 8
.Ld1$strlab:
	.short	0,1
	.long	-1
	.quad	6
.Ld1:
# [63] Result := LowerCase({$I %FPCTARGETCPU%}) + '-' + LowerCase({$I %FPCTARGETOS%});
	.ascii	"x86_64\000"
.Le19:
	.size	.Ld1$strlab, .Le19 - .Ld1$strlab

.section .rodata.n_.Ld2
	.balign 8
.Ld2$strlab:
	.short	0,1
	.long	-1
	.quad	1
.Ld2:
	.ascii	"-\000"
.Le20:
	.size	.Ld2$strlab, .Le20 - .Ld2$strlab

.section .rodata.n_.Ld3
	.balign 8
.Ld3$strlab:
	.short	0,1
	.long	-1
	.quad	5
.Ld3:
	.ascii	"Linux\000"
.Le21:
	.size	.Ld3$strlab, .Le21 - .Ld3$strlab

.section .rodata.n_.Ld4
	.balign 8
.Ld4$strlab:
	.short	0,1
	.long	-1
	.quad	18
.Ld4:
# [84] EnvPath := GetEnvironmentVariable('FAFAFA_MIMALLOC_SO');
	.ascii	"FAFAFA_MIMALLOC_SO\000"
.Le22:
	.size	.Ld4$strlab, .Le22 - .Ld4$strlab

.section .rodata.n_.Ld5
	.balign 8
.Ld5$strlab:
	.short	0,1
	.long	-1
	.quad	4
.Ld5:
# [102] Result := TryLoadFromPath(ExePath + 'lib' + DirectorySeparator + LibSubdir + DirectorySeparator, 'libmimalloc.so');
	.ascii	"lib/\000"
.Le23:
	.size	.Ld5$strlab, .Le23 - .Ld5$strlab

.section .rodata.n_.Ld6
	.balign 8
.Ld6$strlab:
	.short	0,1
	.long	-1
	.quad	1
.Ld6:
	.ascii	"/\000"
.Le24:
	.size	.Ld6$strlab, .Le24 - .Ld6$strlab

.section .rodata.n_.Ld7
	.balign 8
.Ld7$strlab:
	.short	0,1
	.long	-1
	.quad	14
.Ld7:
	.ascii	"libmimalloc.so\000"
.Le25:
	.size	.Ld7$strlab, .Le25 - .Ld7$strlab

.section .rodata.n_.Ld8
	.balign 8
.Ld8$strlab:
	.short	0,1
	.long	-1
	.quad	16
.Ld8:
# [104] Result := TryLoadFromPath(ExePath + 'lib' + DirectorySeparator + LibSubdir + DirectorySeparator, 'libmimalloc.so.2');
	.ascii	"libmimalloc.so.2\000"
.Le26:
	.size	.Ld8$strlab, .Le26 - .Ld8$strlab

.section .rodata.n_.Ld9
	.balign 8
.Ld9$strlab:
	.short	0,1
	.long	-1
	.quad	8
.Ld9:
# [116] if Result = 0 then Result := LoadLibrary('mimalloc');
	.ascii	"mimalloc\000"
.Le27:
	.size	.Ld9$strlab, .Le27 - .Ld9$strlab

.section .rodata.n_.Ld10
	.balign 8
.Ld10$strlab:
	.short	0,1
	.long	-1
	.quad	9
.Ld10:
# [132] Pointer(_mi_malloc) := GetProcedureAddress(_miLib, 'mi_malloc');
	.ascii	"mi_malloc\000"
.Le28:
	.size	.Ld10$strlab, .Le28 - .Ld10$strlab

.section .rodata.n_.Ld11
	.balign 8
.Ld11$strlab:
	.short	0,1
	.long	-1
	.quad	9
.Ld11:
# [133] Pointer(_mi_calloc) := GetProcedureAddress(_miLib, 'mi_calloc');
	.ascii	"mi_calloc\000"
.Le29:
	.size	.Ld11$strlab, .Le29 - .Ld11$strlab

.section .rodata.n_.Ld12
	.balign 8
.Ld12$strlab:
	.short	0,1
	.long	-1
	.quad	10
.Ld12:
# [134] Pointer(_mi_realloc) := GetProcedureAddress(_miLib, 'mi_realloc');
	.ascii	"mi_realloc\000"
.Le30:
	.size	.Ld12$strlab, .Le30 - .Ld12$strlab

.section .rodata.n_.Ld13
	.balign 8
.Ld13$strlab:
	.short	0,1
	.long	-1
	.quad	7
.Ld13:
# [135] Pointer(_mi_free) := GetProcedureAddress(_miLib, 'mi_free');
	.ascii	"mi_free\000"
.Le31:
	.size	.Ld13$strlab, .Le31 - .Ld13$strlab

.section .data.n_TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MIMALLOCALLOCATOROBJ
	.balign 8
.globl	TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MIMALLOCALLOCATOROBJ
	.hidden TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MIMALLOCALLOCATOROBJ
	.type	TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MIMALLOCALLOCATOROBJ,@object
TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MIMALLOCALLOCATOROBJ:
	.quad	0
# [151] _MimallocAllocatorIntf: IAllocator = nil;
.Le32:
	.size	TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MIMALLOCALLOCATOROBJ, .Le32 - TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MIMALLOCALLOCATOROBJ

.section .data.n_TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MIMALLOCALLOCATORINTF
	.balign 8
.globl	TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MIMALLOCALLOCATORINTF
	.hidden TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MIMALLOCALLOCATORINTF
	.type	TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MIMALLOCALLOCATORINTF,@object
TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MIMALLOCALLOCATORINTF:
	.quad	0
# [152] GAllocatorLock: TRTLCriticalSection;
.Le33:
	.size	TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MIMALLOCALLOCATORINTF, .Le33 - TC_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$__MIMALLOCALLOCATORINTF

.section .rodata.n_.Ld14
	.balign 8
.Ld14$strlab:
	.short	0,1
	.long	-1
	.quad	43
.Ld14:
# [157] raise Exception.Create('mimalloc not available: cannot load library');
	.ascii	"mimalloc not available: cannot load library\000"
.Le34:
	.size	.Ld14$strlab, .Le34 - .Ld14$strlab

.section .rodata.n_.Ld15
	.balign 16
.Ld15:
	.long	485189917
	.short	54584,18642
	.byte	165,196,164,240,161,185,137,40
# [203] _MimallocAllocatorIntf := _MimallocAllocatorObj as IAllocator; // anchor lifetime
.Le35:
	.size	.Ld15, .Le35 - .Ld15
# End asmlist al_typedconsts
# Begin asmlist al_rtti

.section .rodata.n_INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR
	.balign 8
.globl	INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR
	.type	INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR,@object
INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR:
	.byte	15,18
# [242] 
	.ascii	"TMimallocAllocator"
	.quad	0,0
	.long	8
	.quad	0,0
	.long	0
.Le36:
	.size	INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR, .Le36 - INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR

.section .rodata.n_RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR
	.type	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR,@object
RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR:
	.byte	15,18
	.ascii	"TMimallocAllocator"
	.quad	0
	.quad	VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR
	.quad	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.BASE_$$_TALLOCATOR$indirect
	.short	0
	.byte	35
	.ascii	"nextpas.core.mem.allocator.mimalloc"
	.short	0,0
.Le37:
	.size	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR, .Le37 - RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR

.section .rodata.n_RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_def0000001E
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_def0000001E
	.type	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_def0000001E,@object
RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_def0000001E:
	.byte	12,0
	.quad	0,24,3
	.quad	RTTI_$SYSTEM_$$_RAWBYTESTRING$indirect
	.byte	1
	.quad	RTTI_$SYSTEM_$$_LONGINT$indirect
.Le38:
	.size	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_def0000001E, .Le38 - RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_def0000001E

.section .rodata.n_RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_def0000002D
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_def0000002D
	.type	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_def0000002D,@object
RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_def0000002D:
	.byte	12,0
	.quad	0,32,4
	.quad	RTTI_$SYSTEM_$$_RAWBYTESTRING$indirect
	.byte	1
	.quad	RTTI_$SYSTEM_$$_LONGINT$indirect
.Le39:
	.size	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_def0000002D, .Le39 - RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_def0000002D

.section .rodata.n_RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_def0000002E
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_def0000002E
	.type	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_def0000002E,@object
RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_def0000002E:
	.byte	12,0
	.quad	0,32,4
	.quad	RTTI_$SYSTEM_$$_RAWBYTESTRING$indirect
	.byte	1
	.quad	RTTI_$SYSTEM_$$_LONGINT$indirect
.Le40:
	.size	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_def0000002E, .Le40 - RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_def0000002E
# End asmlist al_rtti
# Begin asmlist al_indirectglobals

.section .rodata.n_VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR
	.balign 8
.globl	VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR$indirect
	.type	VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR$indirect,@object
VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR$indirect:
	.quad	VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR
# [241] end.
.Le41:
	.size	VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR$indirect, .Le41 - VMT_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR$indirect

.section .rodata.n_INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR
	.balign 8
.globl	INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR$indirect
	.type	INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR$indirect,@object
INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR$indirect:
	.quad	INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR
# [242] 
.Le42:
	.size	INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR$indirect, .Le42 - INIT_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR$indirect
	.type	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR$indirect,@object
RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR$indirect:
	.quad	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR
.Le43:
	.size	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR$indirect, .Le43 - RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_TMIMALLOCALLOCATOR$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_def0000001E
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_def0000001E$indirect
	.type	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_def0000001E$indirect,@object
RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_def0000001E$indirect:
	.quad	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_def0000001E
.Le44:
	.size	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_def0000001E$indirect, .Le44 - RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_def0000001E$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_def0000002D
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_def0000002D$indirect
	.type	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_def0000002D$indirect,@object
RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_def0000002D$indirect:
	.quad	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_def0000002D
.Le45:
	.size	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_def0000002D$indirect, .Le45 - RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_def0000002D$indirect

.section .rodata.n_RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_def0000002E
	.balign 8
.globl	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_def0000002E$indirect
	.type	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_def0000002E$indirect,@object
RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_def0000002E$indirect:
	.quad	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_def0000002E
.Le46:
	.size	RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_def0000002E$indirect, .Le46 - RTTI_$NEXTPAS.CORE.MEM.ALLOCATOR.MIMALLOC_$$_def0000002E$indirect
# End asmlist al_indirectglobals
# Begin asmlist al_dwarf_frame

.section .debug_frame
.Lc64:
	.long	.Lc66-.Lc65
.Lc65:
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
.Lc66:
	.long	.Lc68-.Lc67
.Lc67:
	.long	.Lc64
	.quad	.Lc2
	.quad	.Lc1-.Lc2
	.byte	2
	.byte	.Lc3-.Lc2
	.byte	5
	.uleb128	3
	.uleb128	38
	.byte	14
	.uleb128	152
	.byte	2
	.byte	.Lc4-.Lc3
	.byte	14
	.uleb128	160
	.byte	4
	.long	.Lc5-.Lc4
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc68:
	.long	.Lc71-.Lc70
.Lc70:
	.long	.Lc64
	.quad	.Lc7
	.quad	.Lc6-.Lc7
	.byte	2
	.byte	.Lc8-.Lc7
	.byte	5
	.uleb128	3
	.uleb128	34
	.byte	14
	.uleb128	136
	.byte	2
	.byte	.Lc9-.Lc8
	.byte	5
	.uleb128	12
	.uleb128	36
	.byte	14
	.uleb128	144
	.byte	2
	.byte	.Lc10-.Lc9
	.byte	14
	.uleb128	144
	.byte	4
	.long	.Lc11-.Lc10
	.byte	6
	.uleb128	12
	.byte	2
	.byte	.Lc12-.Lc11
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc71:
	.long	.Lc74-.Lc73
.Lc73:
	.long	.Lc64
	.quad	.Lc14
	.quad	.Lc13-.Lc14
	.byte	2
	.byte	.Lc15-.Lc14
	.byte	5
	.uleb128	3
	.uleb128	50
	.byte	14
	.uleb128	200
	.byte	2
	.byte	.Lc16-.Lc15
	.byte	14
	.uleb128	208
	.byte	4
	.long	.Lc17-.Lc16
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc74:
	.long	.Lc77-.Lc76
.Lc76:
	.long	.Lc64
	.quad	.Lc19
	.quad	.Lc18-.Lc19
	.byte	2
	.byte	.Lc20-.Lc19
	.byte	14
	.uleb128	128
	.byte	4
	.long	.Lc21-.Lc20
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc77:
	.long	.Lc80-.Lc79
.Lc79:
	.long	.Lc64
	.quad	.Lc23
	.quad	.Lc22-.Lc23
	.byte	2
	.byte	.Lc24-.Lc23
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc25-.Lc24
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc26-.Lc25
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc27-.Lc26
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc80:
	.long	.Lc83-.Lc82
.Lc82:
	.long	.Lc64
	.quad	.Lc29
	.quad	.Lc28-.Lc29
	.byte	2
	.byte	.Lc30-.Lc29
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc31-.Lc30
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc32-.Lc31
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc33-.Lc32
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc83:
	.long	.Lc86-.Lc85
.Lc85:
	.long	.Lc64
	.quad	.Lc35
	.quad	.Lc34-.Lc35
	.byte	2
	.byte	.Lc36-.Lc35
	.byte	14
	.uleb128	16
	.byte	5
	.uleb128	6
	.uleb128	4
	.byte	2
	.byte	.Lc37-.Lc36
	.byte	13
	.uleb128	6
	.byte	4
	.long	.Lc38-.Lc37
	.byte	13
	.uleb128	7
	.byte	2
	.byte	.Lc39-.Lc38
	.byte	6
	.uleb128	6
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc86:
	.long	.Lc89-.Lc88
.Lc88:
	.long	.Lc64
	.quad	.Lc41
	.quad	.Lc40-.Lc41
	.byte	2
	.byte	.Lc42-.Lc41
	.byte	5
	.uleb128	3
	.uleb128	4
	.byte	14
	.uleb128	16
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc43-.Lc42
	.byte	6
	.uleb128	3
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc89:
	.long	.Lc92-.Lc91
.Lc91:
	.long	.Lc64
	.quad	.Lc45
	.quad	.Lc44-.Lc45
	.byte	2
	.byte	.Lc46-.Lc45
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc47-.Lc46
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc92:
	.long	.Lc95-.Lc94
.Lc94:
	.long	.Lc64
	.quad	.Lc49
	.quad	.Lc48-.Lc49
	.byte	2
	.byte	.Lc50-.Lc49
	.byte	14
	.uleb128	224
	.byte	4
	.long	.Lc51-.Lc50
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc95:
	.long	.Lc98-.Lc97
.Lc97:
	.long	.Lc64
	.quad	.Lc53
	.quad	.Lc52-.Lc53
	.byte	2
	.byte	.Lc54-.Lc53
	.byte	14
	.uleb128	320
	.byte	4
	.long	.Lc55-.Lc54
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc98:
	.long	.Lc101-.Lc100
.Lc100:
	.long	.Lc64
	.quad	.Lc57
	.quad	.Lc56-.Lc57
	.byte	2
	.byte	.Lc58-.Lc57
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc59-.Lc58
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc101:
	.long	.Lc104-.Lc103
.Lc103:
	.long	.Lc64
	.quad	.Lc61
	.quad	.Lc60-.Lc61
	.byte	2
	.byte	.Lc62-.Lc61
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc63-.Lc62
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc104:
# End asmlist al_dwarf_frame
.section .note.GNU-stack,"",%progbits

