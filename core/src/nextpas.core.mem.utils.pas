{
# nextpas.core.mem.utils

## 摘要

提供一组全局的底层的内存操作函数.

本单元所有接口完全遵守 `空操作原则`, 输入参数 `count = 0` 时, 不进行任何操作.

## 声明

转发或者用于自己项目请保留本项目的版权声明,谢谢.

Author:    nextpas.core
Contact:   dtamade@gmail.com | QQ Group: 685403987 | QQ:179033731
Copyright: (c) 2025 nextpas.core. All rights reserved.
}

unit nextpas.core.mem.utils;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  { IsPowerOfTwo / NextPowerOfTwo / MulHash64 live in mem.base.
    Avoid nextpas.core.math / math.scalar facades (pull large stacks; hangs stage0). }
  nextpas.core.mem.base;

{**
 * IsOverlap
 *
 * @desc 检查两个内存块是否重叠
 *
 * @params
 *   aPtr1  指向第一个内存块的指针
 *   aSize1 第一个内存块的大小
 *   aPtr2  指向第二个内存块的指针
 *   aSize2 第二个内存块的大小
 *
 * @return 如果内存块重叠则返回 True, 否则返回 False
 *
 * @exceptions
 *   EOutOfRange If `aSize1` or `aSize2` is too large, causing address calculation to overflow.
 *               当 `aSize1` 或 `aSize2` 太大(恶意巨数)导致指针加法溢出时抛出。
 *}
function IsOverlap(aPtr1: Pointer; aSize1: SizeUInt; aPtr2: Pointer; aSize2: SizeUInt): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

{**
 * IsOverlapUnchecked
 *
 * @desc The unchecked version of `IsOverlap`. Handles overlapping memory.
 *       `IsOverlap` 的无检查版本. 为性能考虑, 此版本不进行安全检查. 能处理重叠内存.
 *
 * @params
 *   aPtr1  Pointer to the first memory block.
 *          指向第一个内存块的指针.
 *
 *   aSize1 Size of the first memory block.
 *          第一个内存块的大小.
 *
 *   aPtr2  Pointer to the second memory block.
 *          指向第二个内存块的指针.
 *
 *   aSize2 Size of the second memory block.
 *          第二个内存块的大小.
 *
 * @return `True` if the blocks overlap, `False` otherwise.
 *         如果内存块重叠则返回 `True`, 否则返回 `False`.
 *
 * @remark
 *   This function performs no safety checks (including nil pointer, bounds, or overflow checks).
 *   The caller is responsible for ensuring that all input parameters are valid and that `PtrUInt(aPtr) + aSize` does not overflow.
 *   此函数不执行任何安全检查 (包括 `nil` 指针、边界或溢出检查).
 *   调用者有责任确保所有输入参数有效, 并且 `PtrUInt(aPtr) + aSize` 不会溢出.
 *
 *   When you are sure that the pointer is valid and aSize is valid and does not cause overflow,
 *   use this function for maximum performance.
 *   当你确定指针有效,并且aSize有效以及不会造成溢出时, 使用此函数以获得最大性能.
 *}
function IsOverlapUnchecked(aPtr1: Pointer; aSize1: SizeUInt; aPtr2: Pointer; aSize2: SizeUInt): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

{**
 * IsOverlap
 *
 * @desc Checks if two memory blocks overlap.
 *       检查两个内存块是否重叠.
 *
 * @params
 *   aPtr1  Pointer to the first memory block.
 *          指向第一个内存块的指针.
 *
 *   aPtr2  Pointer to the second memory block.
 *          指向第二个内存块的指针.
 *
 *   aSize  Size of the memory block.
 *          内存块的大小.
 *
 * @return `True` if the blocks overlap, `False` otherwise.
 *          如果内存块重叠则返回 `True`, 否则返回 `False`.
 *
 * @exceptions
 *   EOutOfRange If `aSize` is too large, causing address calculation to overflow.
 *               当 `aSize` 太大(恶意巨数)导致指针加法溢出时抛出。
 *}
function IsOverlap(aPtr1, aPtr2: Pointer; aSize: SizeUInt): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

{**
 * IsOverlapUnchecked
 *
 * @desc Checks if two memory blocks overlap.
 *       检查两个内存块是否重叠.
 *
 * @params
 *   aPtr1  Pointer to the first memory block.
 *          指向第一个内存块的指针.
 *
 *   aPtr2  Pointer to the second memory block.
 *          指向第二个内存块的指针.
 *
 *   aSize  Size of the memory block.
 *          内存块的大小.
 *
 * @return `True` if the blocks overlap, `False` otherwise.
 *          如果内存块重叠则返回 `True`, 否则返回 `False`.
 *}
function IsOverlapUnchecked(aPtr1, aPtr2: Pointer; aSize: SizeUInt): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

{** @desc 几何增长计算（带溢出保护 + 单调递增保证）。
 *  适用于分段池、可增长块池等需要按比例扩容的场景。
 *  GrowthFactor < 1.1 自动修正为 2.0。
 * @param aCurrentCapacity  当前总容量（字节或块数）。
 * @param aGrowthFactor     增长倍数（如 2.0 表示翻倍）。
 * @return 下一目标容量。
 *}
function CalcGeometricGrowth(aCurrentCapacity: SizeUInt; aGrowthFactor: Double): SizeUInt; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}


{**
 * Copy
 *
 * @desc Copies bytes from a source to a destination, correctly handling overlapping memory areas.
 *       从源内存区域拷贝字节到目标内存区域, 能正确处理重叠的内存区.
 *
 * @params
 *   aSrc  Pointer to the source memory block.
 *         指向源内存块的指针.
 *
 *   aDst  Pointer to the destination memory block.
 *         指向目标内存块的指针.
 *
 *   aSize Number of bytes to copy.
 *         要拷贝的字节数.
 *
 * @remark This function is a safe wrapper around `NpSystemMove`.
 *         本函数是 `NpSystemMove` 的安全包装.
 *
 * @exceptions
 *   EArgumentNil If `aSrc` or `aDst` is `nil`.
 *                当 `aSrc` 或 `aDst` 为 `nil` 时抛出。
 *
 *   EOutOfRange  If `aSize` is too large, causing address calculation to overflow.
 *                当 `aSize` 太大(恶意巨数)导致指针加法溢出时抛出。
 *}
procedure Copy(aSrc, aDst: Pointer; aSize: SizeUInt); {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

{**
 * CopyUnchecked
 *
 * @desc The unchecked version of `Copy`. Handles overlapping memory.
 *       `Copy` 的无检查版本. 为性能考虑, 此版本不进行安全检查. 能处理重叠内存.
 *
 * @params
 *   aSrc  Pointer to the source memory block.
 *         指向源内存块的指针.
 *
 *   aDst  Pointer to the destination memory block.
 *         指向目标内存块的指针.
 *
 *   aSize Number of bytes to copy.
 *         要拷贝的字节数.
 *
 * @remark
 *   This function performs no safety checks (including nil pointer, bounds, or overflow checks).
 *   The caller is responsible for ensuring that all input parameters are valid.
 *   此函数不执行任何安全检查 (包括 `nil` 指针、边界或溢出检查).
 *   调用者有责任确保所有输入参数有效.
 *
 *   Use this for maximum performance when you are certain that pointers are valid.
 *   当你确定指针有效时, 使用此函数以获得最大性能.
 *}
procedure CopyUnchecked(aSrc, aDst: Pointer; aSize: SizeUInt); {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

{**
 * CopyNonOverlap
 *
 * @desc Copies bytes from source to destination. Assumes memory blocks do not overlap.
 *       从源拷贝字节到目标. 假定内存块不重叠.
 *
 * @params
 *   aSrc  Pointer to the source memory block.
 *         指向源内存块的指针.
 *
 *   aDst  Pointer to the destination memory block.
 *         指向目标内存块的指针.
 *
 *   aSize Number of bytes to copy.
 *         要拷贝的字节数.
 *
 * @remark If memory blocks might overlap, use `Copy` instead.
 *         如果内存块可能重叠, 请改用 `Copy`.
 *
 * @exceptions
 *   EArgumentNil If `aSrc` or `aDst` is `nil`.
 *                当 `aSrc` 或 `aDst` 为 `nil` 时抛出。
 *
 *   EOutOfRange  If `aSize` is too large, causing address calculation to overflow.
 *                当 `aSize` 太大(恶意巨数)导致指针加法溢出时抛出。
 *}
procedure CopyNonOverlap(aSrc, aDst: Pointer; aSize: SizeUInt); {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

{**
 * CopyNonOverlapUnchecked
 *
 * @desc The unchecked version of `CopyNonOverlap`. Assumes memory blocks do not overlap.
 *       `CopyNonOverlap` 的无检查版本. 为性能考虑, 此版本不进行安全检查. 假定内存块不重叠.
 *
 * @params
 *   aSrc  Pointer to the source memory block.
 *         指向源内存块的指针.
 *
 *   aDst  Pointer to the destination memory block.
 *         指向目标内存块的指针.
 *
 *   aSize Number of bytes to copy.
 *         要拷贝的字节数.
 *
 * @remark
 *   This function performs no safety checks (including nil pointer, bounds, or overflow checks).
 *   The caller is responsible for ensuring that all input parameters are valid.
 *   此函数不执行任何安全检查 (包括 `nil` 指针、边界或溢出检查).
 *   调用者有责任确保所有输入参数有效.
 *
 *   Use this for maximum performance when you are certain that pointers are valid.
 *   当你确定指针有效时, 使用此函数以获得最大性能.
 *}
procedure CopyNonOverlapUnchecked(aSrc, aDst: Pointer; aSize: SizeUInt); {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}


{**
 * Fill
 *
 * @desc Fills a memory block with a specified 8-bit value.
 *       使用指定的8位值填充内存块.
 *
 * @params
 *   aDst    Pointer to the memory block to fill.
 *           指向要填充的内存块的指针.
 *
 *   aCount  Number of bytes to fill.
 *           要填充的字节数.
 *
 *   aValue  The 8-bit value to fill with.
 *           用于填充的8位值.
 *
 * @exceptions
 *   EArgumentNil If `aDst` is `nil`.
 *                当 `aDst` 为 `nil` 时抛出。
 *}
procedure Fill(aDst: Pointer; aCount: SizeUInt; aValue: UInt8); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

{**
 * Fill
 *
 * @desc Fills a memory block with a specified 8-bit value. Optimized for `SizeInt` counts.
 *       使用指定的8位值填充内存块. 针对 `SizeInt` 数量优化.
 *
 * @params
 *   aDst    Pointer to the memory block to fill.
 *           指向要填充的内存块的指针.
 *
 *   aCount  Number of bytes to fill.
 *           要填充的字节数.
 *
 *   aValue  The 8-bit value to fill with.
 *           用于填充的8位值.
 *
 * @exceptions
 *   EArgumentNil If `aDst` is `nil`.
 *                当 `aDst` 为 `nil` 时抛出。
 *}
procedure Fill(aDst: Pointer; aCount: SizeInt; aValue: UInt8); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

{**
 * Fill8
 *
 * @desc Alias for `Fill`. Fills a memory block with a specified 8-bit value.
 *       `Fill` 的别名. 使用指定的8位值填充内存块.
 *
 * @params
 *   aDst    Pointer to the memory block to fill.
 *           指向要填充的内存块的指针.
 *
 *   aCount  Number of bytes to fill.
 *           要填充的字节数.
 *
 *   aValue  The 8-bit value to fill with.
 *           用于填充的8位值.
 *
 * @exceptions
 *   EArgumentNil If `aDst` is `nil`.
 *                当 `aDst` 为 `nil` 时抛出。
 *}
procedure Fill8(aDst: Pointer; aCount: SizeUInt; aValue: UInt8); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

{**
 * Fill8
 *
 * @desc Fills a memory block with a specified 8-bit value. Optimized for `SizeInt` counts.
 *       使用指定的8位值填充内存块. 针对 `SizeInt` 数量优化.
 *
 * @params
 *   aDst    Pointer to the memory block to fill.
 *           指向要填充的内存块的指针.
 *
 *   aCount  Number of bytes to fill.
 *           要填充的字节数.
 *
 *   aValue  The 8-bit value to fill with.
 *           用于填充的8位值.
 *
 * @exceptions
 *   EArgumentNil If `aDst` is `nil`.
 *                当 `aDst` 为 `nil` 时抛出。
 *}
procedure Fill8(aDst: Pointer; aCount: SizeInt; aValue: UInt8); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

{**
 * Fill16
 *
 * @desc Fills a memory block with a specified 16-bit value.
 *       使用指定的16位值填充内存块.
 *
 * @params
 *   aDst    Pointer to the memory block to fill.
 *           指向要填充的内存块的指针.
 *
 *   aCount  Number of 16-bit words to fill.
 *           要填充的16位字的数量.
 *
 *   aValue  The 16-bit value to fill with.
 *           用于填充的16位值.
 *
 * @exceptions
 *   EArgumentNil If `aDst` is `nil`.
 *                当 `aDst` 为 `nil` 时抛出。
 *}
procedure Fill16(aDst: Pointer; aCount: SizeUInt; aValue: UInt16); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

{**
 * Fill16
 *
 * @desc Fills a memory block with a specified 16-bit value. Optimized for `SizeInt` counts.
 *       使用指定的16位值填充内存块. 针对 `SizeInt` 数量优化.
 *
 * @params
 *   aDst    Pointer to the memory block to fill.
 *           指向要填充的内存块的指针.
 *
 *   aCount  Number of 16-bit words to fill.
 *           要填充的16位字的数量.
 *
 *   aValue  The 16-bit value to fill with.
 *           用于填充的16位值.
 *
 * @exceptions
 *   EArgumentNil If `aDst` is `nil`.
 *                当 `aDst` 为 `nil` 时抛出。
 *}
procedure Fill16(aDst: Pointer; aCount: SizeInt; aValue: UInt16); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

{**
 * Fill32
 *
 * @desc Fills a memory block with a specified 32-bit value.
 *       使用指定的32位值填充内存块.
 *
 * @params
 *   aDst    Pointer to the memory block to fill.
 *           指向要填充的内存块的指针.
 *
 *   aCount  Number of 32-bit dwords to fill.
 *           要填充的32位双字的数量.
 *
 *   aValue  The 32-bit value to fill with.
 *           用于填充的32位值.
 *
 * @exceptions
 *   EArgumentNil If `aDst` is `nil`.
 *                当 `aDst` 为 `nil` 时抛出。
 *}
procedure Fill32(aDst: Pointer; aCount: SizeUInt; aValue: UInt32); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

{**
 * Fill32
 *
 * @desc Fills a memory block with a specified 32-bit value. Optimized for `SizeInt` counts.
 *       使用指定的32位值填充内存块. 针对 `SizeInt` 数量优化.
 *
 * @params
 *   aDst    Pointer to the memory block to fill.
 *           指向要填充的内存块的指针.
 *
 *   aCount  Number of 32-bit dwords to fill.
 *           要填充的32位双字的数量.
 *
 *   aValue  The 32-bit value to fill with.
 *           用于填充的32位值.
 *
 * @exceptions
 *   EArgumentNil If `aDst` is `nil`.
 *                当 `aDst` 为 `nil` 时抛出。
 *}
procedure Fill32(aDst: Pointer; aCount: SizeInt; aValue: UInt32); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

{**
 * Fill64
 *
 * @desc Fills a memory block with a specified 64-bit value.
 *       使用指定的64位值填充内存块.
 *
 * @params
 *   aDst    Pointer to the memory block to fill.
 *           指向要填充的内存块的指针.
 *
 *   aCount  Number of 64-bit qwords to fill.
 *           要填充的64位四字的数量.
 *
 *   aValue  The 64-bit value to fill with.
 *           用于填充的64位值.
 *
 * @exceptions
 *   EArgumentNil If `aDst` is `nil`.
 *                当 `aDst` 为 `nil` 时抛出。
 *}
procedure Fill64(aDst: Pointer; aCount: SizeUInt; const aValue: UInt64); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

{**
 * Fill64
 *
 * @desc Fills a memory block with a specified 64-bit value. Optimized for `SizeInt` counts.
 *       使用指定的64位值填充内存块. 针对 `SizeInt` 数量优化.
 *
 * @params
 *   aDst    Pointer to the memory block to fill.
 *           指向要填充的内存块的指针.
 *
 *   aCount  Number of 64-bit qwords to fill.
 *           要填充的64位四字的数量.
 *
 *   aValue  The 64-bit value to fill with.
 *           用于填充的64位值.
 *
 * @exceptions
 *   EArgumentNil If `aDst` is `nil`.
 *                当 `aDst` 为 `nil` 时抛出。
 *}
procedure Fill64(aDst: Pointer; aCount: SizeInt; const aValue: UInt64); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}


{**
 * Zero
 *
 * @desc Fills a memory block with zeros.
 *       用零填充内存块.
 *
 * @params
 *   aDst  Pointer to the memory block to fill.
 *         指向要填充的内存块的指针.
 *
 *   aSize Number of bytes to zero out.
 *         要清零的字节数.
 *
 * @exceptions
 *   EArgumentNil If `aDst` is `nil`.
 *                当 `aDst` 为 `nil` 时抛出。
 *}
procedure Zero(aDst: Pointer; aSize: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

{**
 * Zero
 *
 * @desc Fills a memory block with zeros.
 *       用零填充内存块. 针对 `SizeInt` 大小优化.
 *
 * @params
 *   aDst  Pointer to the memory block to fill.
 *         指向要填充的内存块的指针.
 *
 *   aSize Number of bytes to zero out.
 *         要清零的字节数.
 *
 * @exceptions
 *   EArgumentNil If `aDst` is `nil`.
 *                当 `aDst` 为 `nil` 时抛出。
 *}
procedure Zero(aDst: Pointer; aSize: SizeInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}


{**
 * Compare
 *
 * @desc Compare two memory blocks byte by byte (alias of `Compare8`).
 *       逐字节比较两个内存块(`Compare8` 的别名).
 *
 * @params
 *   aPtr1 Pointer to the first memory block.
 *         指向第一个内存块的指针.
 *
 *   aPtr2 Pointer to the second memory block.
 *         指向第二个内存块的指针.
 *
 *   aCount Number of bytes to compare.
 *         要比较的字节数.
 *
 * @return < 0 if aPtr1 < aPtr2, 0 if aPtr1 = aPtr2, > 0 if aPtr1 > aPtr2.
 *         如果 aPtr1 < aPtr2 返回 < 0, aPtr1 = aPtr2 返回 0, aPtr1 > aPtr2 返回 > 0.
 *}
function Compare(aPtr1, aPtr2: Pointer; aCount: SizeUInt): Integer; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

{**
 * Compare
 *
 * @desc Compare two memory blocks byte by byte (alias of `Compare8`). Optimized for `SizeInt` counts.
 *       逐字节比较两个内存块(`Compare8` 的别名). 针对 `SizeInt` 数量优化.
 *
 * @params
 *   aPtr1 Pointer to the first memory block.
 *         指向第一个内存块的指针.
 *
 *   aPtr2 Pointer to the second memory block.
 *         指向第二个内存块的指针.
 *
 *   aCount Number of bytes to compare.
 *         要比较的字节数.
 *
 * @return < 0 if aPtr1 < aPtr2, 0 if aPtr1 = aPtr2, > 0 if aPtr1 > aPtr2.
 *         如果 aPtr1 < aPtr2 返回 < 0, aPtr1 = aPtr2 返回 0, aPtr1 > aPtr2 返回 > 0.
 *}
function Compare(aPtr1, aPtr2: Pointer; aCount: SizeInt): Integer; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

{**
 * Compare8
 *
 * @desc Compares two memory blocks UInt8 by UInt8 (8-bit).
 *       逐字节 (8位) 比较两个内存块.
 *
 * @params
 *   aPtr1  Pointer to the first memory block.
 *         指向第一个内存块的指针.
 *
 *   aPtr2  Pointer to the second memory block.
 *         指向第二个内存块的指针.
 *
 *   aCount Number of 8-bit bytes to compare.
 *         要比较的8位字节的数量.
 *
 * @return < 0 if aPtr1 < aPtr2, 0 if aPtr1 = aPtr2, > 0 if aPtr1 > aPtr2.
 *         如果 aPtr1 < aPtr2 返回 < 0, aPtr1 = aPtr2 返回 0, aPtr1 > aPtr2 返回 > 0.
 *}
function Compare8(aPtr1, aPtr2: Pointer; aCount: SizeUInt): Integer; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

{**
 * Compare8
 *
 * @desc Compares two memory blocks UInt8 by UInt8 (8-bit). Optimized for `SizeInt` counts.
 *       逐字节 (8位) 比较两个内存块. 针对 `SizeInt` 数量优化.
 *
 * @params
 *   aPtr1  Pointer to the first memory block.
 *         指向第一个内存块的指针.
 *
 *   aPtr2  Pointer to the second memory block.
 *         指向第二个内存块的指针.
 *
 *   aCount Number of 8-bit bytes to compare.
 *         要比较的8位字节的数量.
 *
 * @return < 0 if aPtr1 < aPtr2, 0 if aPtr1 = aPtr2, > 0 if aPtr1 > aPtr2.
 *         如果 aPtr1 < aPtr2 返回 < 0, aPtr1 = aPtr2 返回 0, aPtr1 > aPtr2 返回 > 0.
 *}
function Compare8(aPtr1, aPtr2: Pointer; aCount: SizeInt): Integer; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

{**
 * Compare16
 *
 * @desc Compares two memory blocks word by word (16-bit).
 *       逐字 (16位) 比较两个内存块.
 *
 * @params
 *   aPtr1  Pointer to the first memory block.
 *         指向第一个内存块的指针.
 *
 *   aPtr2  Pointer to the second memory block.
 *         指向第二个内存块的指针.
 *
 *   aCount Number of 16-bit words to compare.
 *         要比较的16位字的数量.
 *
 * @return < 0 if aPtr1 < aPtr2, 0 if aPtr1 = aPtr2, > 0 if aPtr1 > aPtr2.
 *         如果 aPtr1 < aPtr2 返回 < 0, aPtr1 = aPtr2 返回 0, aPtr1 > aPtr2 返回 > 0.
 *}
function Compare16(aPtr1, aPtr2: Pointer; aCount: SizeUInt): Integer; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

{**
 * Compare16
 *
 * @desc Compares two memory blocks word by word (16-bit). Optimized for `SizeInt` counts.
 *       逐字 (16位) 比较两个内存块. 针对 `SizeInt` 数量优化.
 *
 * @params
 *   aPtr1  Pointer to the first memory block.
 *         指向第一个内存块的指针.
 *
 *   aPtr2  Pointer to the second memory block.
 *         指向第二个内存块的指针.
 *
 *   aCount Number of 16-bit words to compare.
 *         要比较的16位字的数量.
 *
 * @return < 0 if aPtr1 < aPtr2, 0 if aPtr1 = aPtr2, > 0 if aPtr1 > aPtr2.
 *         如果 aPtr1 < aPtr2 返回 < 0, aPtr1 = aPtr2 返回 0, aPtr1 > aPtr2 返回 > 0.
 *}
function Compare16(aPtr1, aPtr2: Pointer; aCount: SizeInt): Integer; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

{**
 * Compare32
 *
 * @desc Compares two memory blocks dword by dword (32-bit).
 *       逐双字 (32位) 比较两个内存块.
 *
 * @params
 *   aPtr1  Pointer to the first memory block.
 *         指向第一个内存块的指针.
 *
 *   aPtr2  Pointer to the second memory block.
 *         指向第二个内存块的指针.
 *
 *   aCount Number of 32-bit dwords to compare.
 *         要比较的32位双字的数量.
 *
 * @return < 0 if aPtr1 < aPtr2, 0 if aPtr1 = aPtr2, > 0 if aPtr1 > aPtr2.
 *         如果 aPtr1 < aPtr2 返回 < 0, aPtr1 = aPtr2 返回 0, aPtr1 > aPtr2 返回 > 0.
 *}
function Compare32(aPtr1, aPtr2: Pointer; aCount: SizeUInt): Integer; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

{**
 * Compare32
 *
 * @desc Compares two memory blocks dword by dword (32-bit). Optimized for `SizeInt` counts.
 *       逐双字 (32位) 比较两个内存块. 针对 `SizeInt` 数量优化.
 *
 * @params
 *   aPtr1  Pointer to the first memory block.
 *          指向第一个内存块的指针.
 *
 *   aPtr2  Pointer to the second memory block.
 *          指向第二个内存块的指针.
 *
 *   aCount Number of 32-bit dwords to compare.
 *         要比较的32位双字的数量.
 *
 * @return < 0 if aPtr1 < aPtr2, 0 if aPtr1 = aPtr2, > 0 if aPtr1 > aPtr2.
 *         如果 aPtr1 < aPtr2 返回 < 0, aPtr1 = aPtr2 返回 0, aPtr1 > aPtr2 返回 > 0.
 *}
function Compare32(aPtr1, aPtr2: Pointer; aCount: SizeInt): Integer; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}


{**
 * Equal
 *
 * @desc Checks if two memory blocks are equal.
 *       检查两个内存块的内容是否相等.
 *
 * @params
 *   aPtr1 Pointer to the first memory block.
 *         指向第一个内存块的指针.
 *
 *   aPtr2 Pointer to the second memory block.
 *         指向第二个内存块的指针.
 *
 *   aSize Number of bytes to compare.
 *         要比较的字节数.
 *
 * @return `True` if the blocks are equal, `False` otherwise.
 *         如果内存块相等则返回 `True`, 否则返回 `False`.
 *}
function Equal(aPtr1, aPtr2: Pointer; aSize: SizeUInt): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

{**
 * Equal
 *
 * @desc Checks if two memory blocks are equal. Optimized for `SizeInt` counts.
 *       检查两个内存块的内容是否相等. 针对 `SizeInt` 大小优化.
 *
 * @params
 *   aPtr1 Pointer to the first memory block.
 *         指向第一个内存块的指针.
 *
 *   aPtr2 Pointer to the second memory block.
 *         指向第二个内存块的指针.
 *
 *   aSize Number of bytes to compare.
 *         要比较的字节数.
 *
 * @return `True` if the blocks are equal, `False` otherwise.
 *         如果内存块相等则返回 `True`, 否则返回 `False`.
 *}
function Equal(aPtr1, aPtr2: Pointer; aSize: SizeInt): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}



{**
 * IsAligned
 *
 * @desc Checks if a pointer is aligned to a specified boundary.
 *       检查一个指针是否按指定的边界对齐.
 *
 * @params
 *   aPtr       Pointer to the pointer to check.
 *              要检查的指针.
 *
 *   aAlignment The alignment boundary, must be a power of two.
 *              对齐边界, 必须是2的幂.
 *              **如果 aAlignment 不是2的幂, 结果未定义。**
 *
 * @return `True` if the pointer is aligned, `False` otherwise.
 *         如果指针已对齐则返回 `True`, 否则返回 `False`.
 *}
function IsAligned(aPtr: Pointer; aAlignment: SizeUInt = SizeOf(Pointer)): Boolean; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

  {**
   * AlignDown
   *
   * @desc Aligns a pointer downwards to the nearest specified boundary.
   *       将指针向下对齐到最近的指定边界。
   * @exceptions
   *   EArgumentNil / EInvalidArgument 同 AlignUp
   *}
  function AlignDown(aPtr: Pointer; aAlignment: SizeUInt = SIZE_PTR): Pointer; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

  {**
   * AlignDownUnchecked
   *
   * @desc Unchecked version of AlignDown (no safety checks).
   *}
  function AlignDownUnchecked(aPtr: Pointer; aAlignment: SizeUInt = SIZE_PTR): Pointer; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}


{**
 * AlignUp
 *
 * @desc Aligns a pointer upwards to the nearest specified boundary.
 *       将一个指针向上调整到最近的指定对齐边界.
 *
 * @params
 *   aPtr       Pointer to the pointer to align.
 *              要对齐的指针.
 *
 *   aAlignment The alignment boundary, must be a power of two.
 *              对齐边界, 必须是2的幂. **如果 aAlignment 不是2的幂, 结果未定义。**
 *
 * @return The aligned pointer.
 *         对齐后的指针.
 *
 * @exceptions
 *   EArgumentNil     If `aPtr` is `nil`.
 *                    当 `aPtr` 为 `nil` 时抛出。
 *
 *   EInvalidArgument If `aAlignment` is not a power of two.
 *                    当 `aAlignment` 不是2的幂时抛出。
 *}
function AlignUp(aPtr: Pointer; aAlignment: SizeUInt = SIZE_PTR): Pointer; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

{**
 * AlignUpUnchecked
 *
 * @desc Aligns a pointer upwards to the nearest specified boundary. The unchecked version.
 *       将一个指针向上调整到最近的指定对齐边界. 为性能考虑, 此版本不进行安全检查.
 *
 * @params
 *   aPtr       Pointer to the pointer to align.
 *              要对齐的指针.
 *
 *   aAlignment The alignment boundary, must be a power of two.
 *              对齐边界, 必须是2的幂. **如果 aAlignment 不是2的幂, 结果未定义。**
 *
 * @return The aligned pointer.
 *         对齐后的指针.
 *}
function AlignUpUnchecked(aPtr: Pointer; aAlignment: SizeUInt = SIZE_PTR): Pointer; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

{ Sharded pool utilities }

{** 归一化分片数: <= 0 时取 CPU 数 (clamped 1..32), 非 2 的幂时上取整. }
function NormalizeShardCount(aShardCount, aCPUCount: Integer): Integer;

{** 线程→分片路由: MulHash64(AThreadId) and mask. }
function ChooseShardIndex(AThreadId: QWord; aShardMask: SizeUInt): Integer;

{ Debug poison utilities }

procedure DebugPoisonAlloc(APtr: Pointer; ASize: SizeUInt);
procedure DebugPoisonFree(APtr: Pointer; ASize: SizeUInt);
procedure DebugRecordFree(APtr: Pointer);
function DebugIsDoubleFree(APtr: Pointer): Boolean;

implementation

uses
  nextpas.core.system.heap;

{$IFDEF NEXTPAS_CORE_CRT_MEMCPY}
function memcpy(aDst, aSrc : pointer; aSize : SizeUInt): Pointer; cdecl external {$IFDEF MSWINDOWS}'msvcrt.dll'{$ELSE}'libc'{$ENDIF} name 'memcpy';
{$ENDIF}

{$IFDEF NEXTPAS_CORE_CRT_MEMMOVE}
function memmove(aDst, aSrc : pointer; aSize : SizeUInt): Pointer; cdecl external {$IFDEF MSWINDOWS}'msvcrt.dll'{$ELSE}'libc'{$ENDIF} name 'memmove';
{$ENDIF}

function IsOverlap(aPtr1: Pointer; aSize1: SizeUInt; aPtr2: Pointer; aSize2: SizeUInt): Boolean;
var
  LStart1, LStart2: PtrUInt;



begin
  if (aPtr1 = nil) or (aPtr2 = nil) or (aSize1 = 0) or (aSize2 = 0) then
    Exit(False);

  // Start1 := PPtrUInt(@aPtr1)^; // 抛弃这种方式,对效率不友好, 多一次内存访问
  // Start2 := PPtrUInt(@aPtr2)^;
  {$PUSH}{$WARN 4055 OFF}
  LStart1 := PtrUInt(aPtr1);
  LStart2 := PtrUInt(aPtr2);
  {$POP}

  { 检查是否溢出（本地实现，避免 uses math.scalar） }

  if LStart1 > High(SizeUInt) - aSize1 then
    raise EOutOfRange.CreateFmt('aSize1 (%d) is too large for aPtr1 (%p), causing address calculation to overflow.', [aSize1, aPtr1]);

  if LStart2 > High(SizeUInt) - aSize2 then
    raise EOutOfRange.CreateFmt('aSize2 (%d) is too large for aPtr2 (%p), causing address calculation to overflow.', [aSize2, aPtr2]);

  Result := IsOverlapUnchecked(aPtr1, aSize1, aPtr2, aSize2);
end;

function IsOverlapUnchecked(aPtr1: Pointer; aSize1: SizeUInt; aPtr2: Pointer; aSize2: SizeUInt): Boolean;
begin
  {$PUSH}{$WARN 4055 OFF}
  Result := (PtrUInt(aPtr1) < PtrUInt(aPtr2) + aSize2) and (PtrUInt(aPtr2) < PtrUInt(aPtr1) + aSize1);
  {$POP}
end;

function IsOverlap(aPtr1, aPtr2: Pointer; aSize: SizeUInt): Boolean;
begin
  Result := IsOverlap(aPtr1, aSize, aPtr2, aSize);
end;

function IsOverlapUnchecked(aPtr1, aPtr2: Pointer; aSize: SizeUInt): Boolean;
begin
  Result := IsOverlapUnchecked(aPtr1, aSize, aPtr2, aSize);
end;

procedure Copy(aSrc, aDst: Pointer; aSize: SizeUInt);
begin
  if aSize = 0 then
    exit;

  if aSrc = nil then
    raise EArgumentNil.Create('nextpas.core.mem.utils.Copy: aSrc is nil.');

  if aDst = nil then
    raise EArgumentNil.Create('nextpas.core.mem.utils.Copy: aDst is nil.');

  {$IFNDEF NEXTPAS_CORE_CRT_MEMMOVE}
  // 当使用 `NpSystemMove` 做后端时, 检查 `aSize` 是否超出 `SizeInt` 的最大值, 以确保与 `NpSystemMove` 兼容
  if aSize > MAX_SIZE_INT then
    raise EOutOfRange.CreateFmt('nextpas.core.mem.utils.Copy: aSize (%d) exceeds maximum allowed for NpSystemMove (%d).', [aSize, MAX_SIZE_INT]);
  {$ENDIF}

  CopyUnchecked(aSrc, aDst, aSize);
end;

procedure CopyUnchecked(aSrc, aDst: Pointer; aSize: SizeUInt);
begin
  {$IFDEF NEXTPAS_CORE_CRT_MEMMOVE}
    memmove(aDst, aSrc, aSize);
  {$ELSE}
    NpSystemMove(aSrc^, aDst^, SizeInt(aSize));
  {$ENDIF}
end;

procedure CopyNonOverlap(aSrc, aDst: Pointer; aSize: SizeUInt);
begin
  if aSize = 0 then
    exit;

  if aSrc = nil then
    raise EArgumentNil.Create('nextpas.core.mem.utils.CopyNonOverlap: aSrc is nil.');

  if aDst = nil then
    raise EArgumentNil.Create('nextpas.core.mem.utils.CopyNonOverlap: aDst is nil.');

  {$IFNDEF NEXTPAS_CORE_CRT_MEMCPY}
  // 当使用 `NpSystemMove` 做后端时, 检查 `aSize` 是否超出 `SizeInt` 的最大值, 以确保与 `NpSystemMove` 兼容
  if aSize > MAX_SIZE_INT then
    raise EOutOfRange.CreateFmt('nextpas.core.mem.utils.CopyNonOverlap: aSize (%d) exceeds maximum allowed for NpSystemMove (%d).', [aSize, MAX_SIZE_INT]);
  {$ENDIF}

  CopyNonOverlapUnchecked(aSrc, aDst, aSize);
end;

procedure CopyNonOverlapUnchecked(aSrc, aDst: Pointer; aSize: SizeUInt);
begin
  {$IFDEF NEXTPAS_CORE_CRT_MEMCPY}
    memcpy(aDst, aSrc, aSize);
  {$ELSE}
    NpSystemMove(aSrc^, aDst^, SizeInt(aSize));
  {$ENDIF}
end;

procedure Fill(aDst: Pointer; aCount: SizeInt; aValue: UInt8);
begin
  Fill8(aDst, aCount, aValue);
end;

procedure Fill(aDst: Pointer; aCount: SizeUInt; aValue: UInt8);
begin
  Fill8(aDst, aCount, aValue);
end;

procedure Fill8(aDst: Pointer; aCount: SizeInt; aValue: UInt8);
begin
  if aCount = 0 then
    exit;

  if aDst = nil then
    raise EArgumentNil.Create('nextpas.core.mem.utils.Fill8: aDst is nil');

  FillChar(aDst^, aCount, aValue);
end;

procedure Fill8(aDst: Pointer; aCount: SizeUInt; aValue: UInt8);
var
  LCurrentDst:     PtrUInt;
  LRemainingCount: SizeUInt;
  LChunkSize:      SizeInt;
begin
  if aCount = 0 then
    exit;

  if aDst = nil then
    raise EArgumentNil.Create('nextpas.core.mem.utils.Fill8: aDst is nil');

  {$PUSH}{$WARN 4055 OFF}
  LCurrentDst     := PtrUInt(aDst);

  LRemainingCount := aCount;

  while LRemainingCount > 0 do
  begin
    if LRemainingCount > MAX_SIZE_INT then
      LChunkSize := MAX_SIZE_INT
    else
      LChunkSize := SizeInt(LRemainingCount);

    FillChar(Pointer(LCurrentDst)^, LChunkSize, aValue);

    Inc(LCurrentDst, LChunkSize);
    Dec(LRemainingCount, LChunkSize);
  end;
  {$POP}
end;

procedure Fill16(aDst: Pointer; aCount: SizeUInt; aValue: UInt16);
var
  LCurrentDst:     PtrUInt;
  LRemainingCount: SizeUInt;
  LChunkSize:      SizeInt;
begin
  if aCount = 0 then
    exit;

  if aDst = nil then
    raise EArgumentNil.Create('nextpas.core.mem.utils.Fill16: aDst is nil');

  {$PUSH}{$WARN 4055 OFF}
  LCurrentDst     := PtrUInt(aDst);
  LRemainingCount := aCount;

  while LRemainingCount > 0 do
  begin
    if LRemainingCount > MAX_SIZE_INT then
      LChunkSize := MAX_SIZE_INT
    else
      LChunkSize := SizeInt(LRemainingCount);

    FillWord(Pointer(LCurrentDst)^, LChunkSize, aValue);

    { 检查乘法溢出风险 }
    if LChunkSize > MAX_SIZE_INT div SIZE_16 then
      raise EOverflow.Create('nextpas.core.mem.utils.Fill16: pointer arithmetic overflow');

    Inc(LCurrentDst, LChunkSize * SIZE_16);
    Dec(LRemainingCount, LChunkSize);
  end;
  {$POP}
end;

procedure Fill16(aDst: Pointer; aCount: SizeInt; aValue: UInt16);
begin
  if aCount = 0 then
    exit;

  if aDst = nil then
    raise EArgumentNil.Create('nextpas.core.mem.utils.Fill16: aDst is nil');

  FillWord(aDst^, aCount, aValue);
end;

procedure Fill32(aDst: Pointer; aCount: SizeUInt; aValue: UInt32);
var
  LCurrentDst:     PtrUInt;
  LRemainingCount: SizeUInt;
  LChunkSize:      SizeInt;
begin
  if aCount = 0 then
    exit;

  if aDst = nil then
    raise EArgumentNil.Create('nextpas.core.mem.utils.Fill32: aDst is nil');

  {$PUSH}{$WARN 4055 OFF}
  LCurrentDst     := PtrUInt(aDst);
  LRemainingCount := aCount;

  while LRemainingCount > 0 do
  begin
    if LRemainingCount > MAX_SIZE_INT then
      LChunkSize := MAX_SIZE_INT
    else
      LChunkSize := SizeInt(LRemainingCount);

    FillDWord(Pointer(LCurrentDst)^, LChunkSize, aValue);

    { 检查乘法溢出风险 }
    if LChunkSize > MAX_SIZE_INT div SIZE_32 then
      raise EOverflow.Create('nextpas.core.mem.utils.Fill32: pointer arithmetic overflow');

    Inc(LCurrentDst, LChunkSize * SIZE_32);
    Dec(LRemainingCount, LChunkSize);
  end;
  {$POP}
end;

procedure Fill32(aDst: Pointer; aCount: SizeInt; aValue: UInt32);
begin
  if aCount = 0 then
    exit;

  if aDst = nil then
    raise EArgumentNil.Create('nextpas.core.mem.utils.Fill32: aDst is nil');

  FillDWord(aDst^, aCount, aValue);
end;

procedure Fill64(aDst: Pointer; aCount: SizeUInt; const aValue: UInt64);
var
  LCurrentDst:     PtrUInt;
  LRemainingCount: SizeUInt;
  LChunkSize:      SizeInt;
begin
  if aCount = 0 then
    exit;

  if aDst = nil then
    raise EArgumentNil.Create('nextpas.core.mem.utils.Fill64: aDst is nil');

  {$PUSH}{$WARN 4055 OFF}
  LCurrentDst     := PtrUInt(aDst);
  LRemainingCount := aCount;

  while LRemainingCount > 0 do
  begin
    if LRemainingCount > MAX_SIZE_INT then
      LChunkSize := MAX_SIZE_INT
    else
      LChunkSize := SizeInt(LRemainingCount);

    FillQWord(Pointer(LCurrentDst)^, LChunkSize, aValue);

    { 检查乘法溢出风险 }
    if LChunkSize > MAX_SIZE_INT div SIZE_64 then
      raise EOverflow.Create('nextpas.core.mem.utils.Fill64: pointer arithmetic overflow');

    Inc(LCurrentDst, LChunkSize * SIZE_64);
    Dec(LRemainingCount, LChunkSize);
  end;
  {$POP}
end;

procedure Fill64(aDst: Pointer; aCount: SizeInt; const aValue: UInt64);
begin
  if aCount = 0 then
    exit;

  if aDst = nil then
    raise EArgumentNil.Create('nextpas.core.mem.utils.Fill64: aDst is nil');

  FillQWord(aDst^, aCount, aValue);
end;


procedure Zero(aDst: Pointer; aSize: SizeUInt);
begin
  Fill8(aDst, aSize, 0);
end;

procedure Zero(aDst: Pointer; aSize: SizeInt);
begin
  Fill8(aDst, aSize, 0);
end;

function Compare(aPtr1, aPtr2: Pointer; aCount: SizeUInt): Integer;
begin
  Result := Compare8(aPtr1, aPtr2, aCount);
end;

function Compare(aPtr1, aPtr2: Pointer; aCount: SizeInt): Integer;
begin
  Result := Compare8(aPtr1, aPtr2, aCount);
end;

function Compare8(aPtr1, aPtr2: Pointer; aCount: SizeUInt): Integer;
var
  LCurrentPtr1:    PtrUInt;
  LCurrentPtr2:    PtrUInt;
  LRemainingCount: SizeUInt;
  LChunkSize:      SizeInt;
  LResult:         Integer;
begin
  {$PUSH}{$WARN 4055 OFF}
  LCurrentPtr1    := PtrUInt(aPtr1);
  LCurrentPtr2    := PtrUInt(aPtr2);
  LRemainingCount := aCount;
  LResult         := 0;

  while LRemainingCount > 0 do
  begin
    if LRemainingCount > MAX_SIZE_INT then
      LChunkSize := MAX_SIZE_INT
    else
      LChunkSize := SizeInt(LRemainingCount);

    LResult := Compare8(Pointer(LCurrentPtr1), Pointer(LCurrentPtr2), LChunkSize);

    if LResult <> 0 then
      Exit(LResult);

    Inc(LCurrentPtr1, LChunkSize);
    Inc(LCurrentPtr2, LChunkSize);
    Dec(LRemainingCount, LChunkSize);
  end;
  {$POP}
  Result := LResult;
end;

function Compare8(aPtr1, aPtr2: Pointer; aCount: SizeInt): Integer;
begin
  if aCount = 0 then
    Exit(0);

  if (aPtr1 = nil) or (aPtr2 = nil) then
    raise EArgumentNil.Create('nextpas.core.mem.utils.Compare8: nil pointer');

  Result := System.CompareByte(aPtr1^, aPtr2^, aCount);
end;

function Compare16(aPtr1, aPtr2: Pointer; aCount: SizeUInt): Integer;
var
  LCurrentPtr1:    PtrUInt;
  LCurrentPtr2:    PtrUInt;
  LRemainingCount: SizeUInt;
  LChunkSize:      SizeInt;
  LResult:         Integer;
begin
  {$PUSH}{$WARN 4055 OFF}
  LCurrentPtr1    := PtrUInt(aPtr1);
  LCurrentPtr2    := PtrUInt(aPtr2);
  LRemainingCount := aCount;
  LResult         := 0;

  while LRemainingCount > 0 do
  begin
    if LRemainingCount > MAX_SIZE_INT then
      LChunkSize := MAX_SIZE_INT
    else
      LChunkSize := SizeInt(LRemainingCount);

    LResult := Compare16(Pointer(LCurrentPtr1), Pointer(LCurrentPtr2), LChunkSize);

    if LResult <> 0 then
    begin
      Result := LResult;
      Exit;
    end;

    Inc(LCurrentPtr1, LChunkSize * SizeOf(UInt16));
    Inc(LCurrentPtr2, LChunkSize * SizeOf(UInt16));
    Dec(LRemainingCount, LChunkSize);
  end;
  {$POP}
  Result := LResult;
end;

function Compare16(aPtr1, aPtr2: Pointer; aCount: SizeInt): Integer;
begin
  if aCount = 0 then Exit(0);
  if (aPtr1 = nil) or (aPtr2 = nil) then
    raise EArgumentNil.Create('nextpas.core.mem.utils.Compare16: nil pointer');
  Result := System.CompareWord(aPtr1^, aPtr2^, aCount);
end;

function Compare32(aPtr1, aPtr2: Pointer; aCount: SizeUInt): Integer;
var
  LCurrentPtr1:    PtrUInt;
  LCurrentPtr2:    PtrUInt;
  LRemainingCount: SizeUInt;
  LChunkSize:      SizeInt;
  LResult:         Integer;
begin
  {$PUSH}{$WARN 4055 OFF}
  LCurrentPtr1    := PtrUInt(aPtr1);
  LCurrentPtr2    := PtrUInt(aPtr2);
  LRemainingCount := aCount;
  LResult         := 0;

  while LRemainingCount > 0 do
  begin
    if LRemainingCount > MAX_SIZE_INT then
      LChunkSize := MAX_SIZE_INT
    else
      LChunkSize := SizeInt(LRemainingCount);

    LResult := Compare32(Pointer(LCurrentPtr1), Pointer(LCurrentPtr2), LChunkSize);

    if LResult <> 0 then
    begin
      Result := LResult;
      Exit;
    end;

    Inc(LCurrentPtr1, LChunkSize * SizeOf(UInt32));
    Inc(LCurrentPtr2, LChunkSize * SizeOf(UInt32));
    Dec(LRemainingCount, LChunkSize);
  end;
  {$POP}
  Result := LResult;
end;

function Compare32(aPtr1, aPtr2: Pointer; aCount: SizeInt): Integer;
begin
  if aCount = 0 then Exit(0);
  if (aPtr1 = nil) or (aPtr2 = nil) then
    raise EArgumentNil.Create('nextpas.core.mem.utils.Compare32: nil pointer');
  Result := System.CompareDWord(aPtr1^, aPtr2^, aCount);
end;


function Equal(aPtr1, aPtr2: Pointer; aSize: SizeUInt): Boolean;
begin
  Result := (Compare8(aPtr1, aPtr2, aSize) = 0);
end;

function Equal(aPtr1, aPtr2: Pointer; aSize: SizeInt): Boolean;
begin
  Result := (Compare8(aPtr1, aPtr2, aSize) = 0);
end;

function IsAligned(aPtr: Pointer; aAlignment: SizeUInt): Boolean;
begin
  {$PUSH}{$WARN 4055 OFF}
  Result := (PtrUInt(aPtr) and (aAlignment - 1)) = 0;
  {$POP}
end;

function AlignUp(aPtr: Pointer; aAlignment: SizeUInt): Pointer;
begin
  if aPtr = nil then
    raise EArgumentNil.Create('nextpas.core.mem.utils.AlignUp: aPtr is nil');

  if aAlignment = 0 then
    raise EInvalidArgument.Create('nextpas.core.mem.utils.AlignUp: aAlignment is 0');

  if not IsPowerOfTwo(aAlignment) then
    raise EInvalidArgument.Create('nextpas.core.mem.utils.AlignUp: aAlignment must be a power of two');

  Result := AlignUpUnchecked(aPtr, aAlignment);
end;

function AlignUpUnchecked(aPtr: Pointer; aAlignment: SizeUInt): Pointer;
begin
  {$PUSH}{$WARN 4055 OFF}
  Result := Pointer((PtrUInt(aPtr) + (aAlignment - 1)) and not (aAlignment - 1));
  {$POP}
end;


function AlignDown(aPtr: Pointer; aAlignment: SizeUInt): Pointer;
begin
  if aPtr = nil then
    raise EArgumentNil.Create('nextpas.core.mem.utils.AlignDown: aPtr is nil');
  if aAlignment = 0 then
    raise EInvalidArgument.Create('nextpas.core.mem.utils.AlignDown: aAlignment is 0');
  if not IsPowerOfTwo(aAlignment) then
    raise EInvalidArgument.Create('nextpas.core.mem.utils.AlignDown: aAlignment must be a power of two');
  Result := AlignDownUnchecked(aPtr, aAlignment);
end;

function AlignDownUnchecked(aPtr: Pointer; aAlignment: SizeUInt): Pointer;
begin
  {$PUSH}{$WARN 4055 OFF}
  Result := Pointer(PtrUInt(aPtr) and not (aAlignment - 1));
  {$POP}
end;

{ Sharded pool utilities }

function NormalizeShardCount(aShardCount, aCPUCount: Integer): Integer;
begin
  if aShardCount <= 0 then
  begin
    aShardCount := aCPUCount;
    if aShardCount < 1 then aShardCount := 1;
    if aShardCount > 32 then aShardCount := 32;
  end;
  if not IsPowerOfTwo(SizeUInt(aShardCount)) then
    aShardCount := Integer(NextPowerOfTwo(SizeUInt(aShardCount)));
  if aShardCount < 1 then aShardCount := 1;
  Result := aShardCount;
end;

function ChooseShardIndex(AThreadId: QWord; aShardMask: SizeUInt): Integer;
begin
  if aShardMask = 0 then Exit(0);
  Result := Integer(MulHash64(AThreadId) and QWord(aShardMask));
end;

{ Debug poison utilities }

const
  MEM_POISON_ALLOC = $AB;
  MEM_POISON_FREED = $DE;
  FREED_PTR_RING_SIZE = 256;

var
  GFreedRing: array[0..FREED_PTR_RING_SIZE - 1] of Pointer;
  GFreedRingPos: Integer;

procedure DebugPoisonAlloc(APtr: Pointer; ASize: SizeUInt);
begin
  FillChar(APtr^, ASize, MEM_POISON_ALLOC);
end;

procedure DebugPoisonFree(APtr: Pointer; ASize: SizeUInt);
begin
  FillChar(APtr^, ASize, MEM_POISON_FREED);
end;

procedure DebugRecordFree(APtr: Pointer);
begin
  GFreedRing[GFreedRingPos] := APtr;
  GFreedRingPos := (GFreedRingPos + 1) mod FREED_PTR_RING_SIZE;
end;

function DebugIsDoubleFree(APtr: Pointer): Boolean;
var
  I: Integer;
begin
  for I := 0 to FREED_PTR_RING_SIZE - 1 do
    if GFreedRing[I] = APtr then
      Exit(True);
  Result := False;
end;

{ Geometric growth calculation }

function CalcGeometricGrowth(aCurrentCapacity: SizeUInt; aGrowthFactor: Double): SizeUInt;
var
  LFactor: Double;
  LDesiredF: Double;
  LDesired: SizeUInt;
begin
  LFactor := aGrowthFactor;
  if LFactor < 1.1 then
    LFactor := 2.0;
  LDesiredF := Double(aCurrentCapacity) * LFactor;
  if LDesiredF > Double(High(SizeUInt)) then
    LDesired := High(SizeUInt)
  else
  begin
    LDesired := SizeUInt(Trunc(LDesiredF));
    if Double(LDesired) < LDesiredF then
      Inc(LDesired);
  end;
  if LDesired <= aCurrentCapacity then
  begin
    if aCurrentCapacity > High(SizeUInt) div 2 then
      LDesired := High(SizeUInt)
    else
      LDesired := aCurrentCapacity * 2;
  end;
  Result := LDesired;
end;

end.
