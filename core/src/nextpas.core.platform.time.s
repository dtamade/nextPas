	.file "nextpas.core.platform.time.pas"
# Begin asmlist al_procedures

.section .text.n_nextpas.core.platform.time_$$_platform_monotonic_ns$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.PLATFORM.TIME_$$_PLATFORM_MONOTONIC_NS$$QWORD
	.type	NEXTPAS.CORE.PLATFORM.TIME_$$_PLATFORM_MONOTONIC_NS$$QWORD,@function
NEXTPAS.CORE.PLATFORM.TIME_$$_PLATFORM_MONOTONIC_NS$$QWORD:
.Lc2:
# [nextpas.core.platform.time.pas]
# [45] begin
	pushq	%rax
.Lc3:
# [46] Result := nextpas.core.platform.time.host.platform_monotonic_ns;
	call	NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_MONOTONIC_NS$$QWORD
# Var $result located in register rax
# [47] end;
	popq	%rcx
.Lc4:
	ret
.Lc1:

.section .text.n_nextpas.core.platform.time_$$_platform_realtime_ns$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.PLATFORM.TIME_$$_PLATFORM_REALTIME_NS$$QWORD
	.type	NEXTPAS.CORE.PLATFORM.TIME_$$_PLATFORM_REALTIME_NS$$QWORD,@function
NEXTPAS.CORE.PLATFORM.TIME_$$_PLATFORM_REALTIME_NS$$QWORD:
.Lc6:
# [50] begin
	pushq	%rax
.Lc7:
# [51] Result := nextpas.core.platform.time.host.platform_realtime_ns;
	call	NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_REALTIME_NS$$QWORD
# Var $result located in register rax
# [52] end;
	popq	%rcx
.Lc8:
	ret
.Lc5:

.section .text.n_nextpas.core.platform.time_$$_platform_monotonic_resolution_ns$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.PLATFORM.TIME_$$_PLATFORM_MONOTONIC_RESOLUTION_NS$$QWORD
	.type	NEXTPAS.CORE.PLATFORM.TIME_$$_PLATFORM_MONOTONIC_RESOLUTION_NS$$QWORD,@function
NEXTPAS.CORE.PLATFORM.TIME_$$_PLATFORM_MONOTONIC_RESOLUTION_NS$$QWORD:
.Lc10:
# [55] begin
	pushq	%rax
.Lc11:
# [56] Result := nextpas.core.platform.time.host.platform_monotonic_resolution_ns;
	call	NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_MONOTONIC_RESOLUTION_NS$$QWORD
# Var $result located in register rax
# [57] end;
	popq	%rcx
.Lc12:
	ret
.Lc9:

.section .text.n_nextpas.core.platform.time_$$_platform_qpc_to_ns$qword$qword$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.PLATFORM.TIME_$$_PLATFORM_QPC_TO_NS$QWORD$QWORD$$QWORD
	.type	NEXTPAS.CORE.PLATFORM.TIME_$$_PLATFORM_QPC_TO_NS$QWORD$QWORD$$QWORD,@function
NEXTPAS.CORE.PLATFORM.TIME_$$_PLATFORM_QPC_TO_NS$QWORD$QWORD$$QWORD:
.Lc14:
# [62] begin
	pushq	%rax
.Lc15:
# Var ACounter located in register rdi
# Var AFrequency located in register rsi
# Var AFrequency located in register rsi
# Var ACounter located in register rdi
# [63] Result := nextpas.core.platform.time.host.platform_qpc_to_ns(ACounter, AFrequency);
	call	NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_QPC_TO_NS$QWORD$QWORD$$QWORD
# Var $result located in register rax
# [64] end;
	popq	%rcx
.Lc16:
	ret
.Lc13:

.section .text.n_nextpas.core.platform.time_$$_platform_resolution_from_frequency_ns$qword$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.PLATFORM.TIME_$$_PLATFORM_RESOLUTION_FROM_FREQUENCY_NS$QWORD$$QWORD
	.type	NEXTPAS.CORE.PLATFORM.TIME_$$_PLATFORM_RESOLUTION_FROM_FREQUENCY_NS$QWORD$$QWORD,@function
NEXTPAS.CORE.PLATFORM.TIME_$$_PLATFORM_RESOLUTION_FROM_FREQUENCY_NS$QWORD$$QWORD:
.Lc18:
# [68] begin
	pushq	%rax
.Lc19:
# Var AFrequency located in register rdi
# Var AFrequency located in register rdi
# [69] Result := nextpas.core.platform.time.host.platform_resolution_from_frequency_ns(AFrequency);
	call	NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_RESOLUTION_FROM_FREQUENCY_NS$QWORD$$QWORD
# Var $result located in register rax
# [70] end;
	popq	%rcx
.Lc20:
	ret
.Lc17:

.section .text.n_nextpas.core.platform.time_$$_platform_timespec_to_ns$int64$int64$$qword,"ax"
	.balign 16,0x90
.globl	NEXTPAS.CORE.PLATFORM.TIME_$$_PLATFORM_TIMESPEC_TO_NS$INT64$INT64$$QWORD
	.type	NEXTPAS.CORE.PLATFORM.TIME_$$_PLATFORM_TIMESPEC_TO_NS$INT64$INT64$$QWORD,@function
NEXTPAS.CORE.PLATFORM.TIME_$$_PLATFORM_TIMESPEC_TO_NS$INT64$INT64$$QWORD:
.Lc22:
# [75] begin
	pushq	%rax
.Lc23:
# Var ASec located in register rdi
# Var ANsec located in register rsi
# Var ANsec located in register rsi
# Var ASec located in register rdi
# [76] Result := nextpas.core.platform.time.host.platform_timespec_to_ns(ASec, ANsec);
	call	NEXTPAS.CORE.PLATFORM.TIME.HOST_$$_PLATFORM_TIMESPEC_TO_NS$INT64$INT64$$QWORD
# Var $result located in register rax
# [77] end;
	popq	%rcx
.Lc24:
	ret
.Lc21:
# End asmlist al_procedures
# Begin asmlist al_dwarf_frame

.section .debug_frame
.Lc25:
	.long	.Lc27-.Lc26
.Lc26:
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
.Lc27:
	.long	.Lc29-.Lc28
.Lc28:
	.long	.Lc25
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
.Lc29:
	.long	.Lc32-.Lc31
.Lc31:
	.long	.Lc25
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
.Lc32:
	.long	.Lc35-.Lc34
.Lc34:
	.long	.Lc25
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
.Lc35:
	.long	.Lc38-.Lc37
.Lc37:
	.long	.Lc25
	.quad	.Lc14
	.quad	.Lc13-.Lc14
	.byte	2
	.byte	.Lc15-.Lc14
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc16-.Lc15
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc38:
	.long	.Lc41-.Lc40
.Lc40:
	.long	.Lc25
	.quad	.Lc18
	.quad	.Lc17-.Lc18
	.byte	2
	.byte	.Lc19-.Lc18
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc20-.Lc19
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc41:
	.long	.Lc44-.Lc43
.Lc43:
	.long	.Lc25
	.quad	.Lc22
	.quad	.Lc21-.Lc22
	.byte	2
	.byte	.Lc23-.Lc22
	.byte	14
	.uleb128	16
	.byte	4
	.long	.Lc24-.Lc23
	.byte	14
	.uleb128	8
	.balign 8,0
.Lc44:
# End asmlist al_dwarf_frame
.section .note.GNU-stack,"",%progbits

