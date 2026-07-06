{**
 * @desc nextPas system kernel entry point.
 *
 * This file is included when compiling under nextPas.
 * It defines the compiler root types and runtime contracts.
 * NEVER compiled under FPC — use fpc.inc instead.
 *
 * Sub-modules are included in dependency order:
 *   1. base.inc   — basic types (SizeInt, TBytes, C ABI types)
 *   2. str.inc    — string types (ShortString, AnsiString, etc.)
 *   3. intf.inc   — interface types (IUnknown, TGUID, etc.)
 *   4. cls.inc    — class types (TObject, TClass, VMT)
 *   5. rtti.inc   — RTTI types (TTypeKind, TTypeInfo)
 *   6. except.inc — exception classes (Exception, EAbort, etc.)
 *   7. mem.inc    — memory operations (GetMem, FreeMem, etc.)
 *   8. comp.inc   — compiler internal functions (fpc_* series)
 *
 * NOTE: This file is only included under nextPas.
 * For FPC, see fpc.inc.
 *}
{$I nextpas.core.system.base.inc}
{$I nextpas.core.system.str.inc}
{$I nextpas.core.system.intf.inc}
{$I nextpas.core.system.cls.inc}
{$I nextpas.core.system.rtti.inc}
{$I nextpas.core.system.except.inc}
{$I nextpas.core.system.mem.inc}
{$I nextpas.core.system.memmgr.inc}
{$I nextpas.core.system.lifecycle.inc}
{$I nextpas.core.system.endian.inc}
{$I nextpas.core.system.barrier.inc}
{$I nextpas.core.system.intrinsics.inc}
{$I nextpas.core.system.comp.inc}
