{
```text
   ______   ______     ______   ______     ______   ______
  /\  ___\ /\  __ \   /\  ___\ /\  __ \   /\  ___\ /\  __ \
  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \
   \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\
    \/_/     \/_/\/_/   \/_/     \/_/\/_/   \/_/     \/_/\/_/  Studio

```
# nextpas.core.mem.layout - Rust 风格内存布局类型
## Abstract 摘要

Rust-style memory layout types for type-safe allocation.
Rust 风格的内存布局类型，用于类型安全的内存分配。

## Declaration 声明

Author:    fafafaStudio
Contact:   dtamade@gmail.com | QQ Group: 685403987 | QQ:179033731
Copyright: (c) 2025 fafafaStudio. All rights reserved.
}

unit nextpas.core.mem.layout;

{$I nextpas.core.settings.inc}

interface

type
  {**
   * TMemLayout
   *
   * @desc Rust 风格的内存布局描述符
   *       Memory layout descriptor, similar to Rust's std::alloc::Layout
   *
   * @features
   *   - 大小和对齐组合成单一类型
   *   - 编译时和运行时布局计算
   *   - 与 IAlloc 接口配合使用
   *
   * @example
   *   var Layout := TMemLayout.Create(1024, 16);  // 1KB, 16字节对齐
   *   var Layout := TMemLayout.ForType<TMyRecord>;
   *}
  TMemLayout = record
  private
    FSize: SizeUInt;
    FAlign: SizeUInt;
  public
    {** 大小（字节）| Size in bytes *}
    property Size: SizeUInt read FSize;

    {** 对齐要求（字节，必须是2的幂）| Alignment (bytes, must be power of 2) *}
    property Align: SizeUInt read FAlign;

    {**
     * Create
     *
     * @desc 创建指定大小和对齐的布局
     *       Create layout with specified size and alignment
     *
     * @params
     *   aSize: SizeUInt  请求的大小（字节）
     *   aAlign: SizeUInt 对齐要求（字节），必须是2的幂，0表示默认对齐
     *
     * @return 新的 TMemLayout 实例
     *
     * @note 如果 aAlign 不是2的幂，会向上取到最近的2的幂
     *       如果对齐值过大导致溢出，会使用饱和策略（最大2的幂）
     *}
    class function Create(aSize: SizeUInt; aAlign: SizeUInt = 0): TMemLayout; static;

    {**
     * TryCreate
     *
     * @desc 尝试创建指定大小和对齐的布局
     *       Try to create layout with specified size and alignment
     *
     * @params
     *   aSize: SizeUInt   请求的大小（字节）
     *   aAlign: SizeUInt  对齐要求（字节），必须是2的幂，0表示默认对齐
     *   aLayout: out TMemLayout 输出的布局
     *
     * @return True 如果成功创建有效布局，False 如果对齐值会导致溢出
     *
     * @note Rust-style safe constructor，不使用饱和策略
     *}
    class function TryCreate(aSize: SizeUInt; aAlign: SizeUInt; out aLayout: TMemLayout): Boolean; static;

    {**
     * ForType<T>
     *
     * @desc 获取类型 T 的内存布局
     *       Get memory layout for type T
     *
     * @return 类型 T 的 TMemLayout
     *
     * @example
     *   var Layout := TMemLayout.ForType<Integer>;
     *   var Layout := TMemLayout.ForType<TMyRecord>;
     *}
    generic class function ForType<T>: TMemLayout; static;

    {**
     * ForArray<T>
     *
     * @desc 获取 T 类型数组的内存布局
     *       Get memory layout for array of type T
     *
     * @params
     *   aCount: SizeUInt 数组元素数量
     *
     * @return 数组的 TMemLayout
     *}
    generic class function ForArray<T>(aCount: SizeUInt): TMemLayout; static;

    {**
     * IsValid
     *
     * @desc 检查布局是否有效
     *       Check if layout is valid
     *
     * @return True 如果布局有效（对齐是2的幂，大小合理）
     *}
    function IsValid: Boolean; inline;

    {**
     * IsZeroSized
     *
     * @desc 检查是否是零大小布局
     *       Check if this is a zero-sized layout
     *
     * @return True 如果 Size = 0
     *}
    function IsZeroSized: Boolean; inline;

    {**
     * AlignedSize
     *
     * @desc 获取对齐后的大小
     *       Get size after alignment padding
     *
     * @return 对齐到 Align 边界后的大小
     *
     * @note 用于数组布局计算：每个元素占用 AlignedSize 字节
     *}
    function AlignedSize: SizeUInt; inline;

    {**
     * Extend
     *
     * @desc 扩展布局以包含另一个布局
     *       Extend layout to include another layout (for struct layout)
     *
     * @params
     *   aNext: TMemLayout 要追加的布局
     *
     * @return 扩展后的新布局，对齐取两者最大值
     *}
    function Extend(const aNext: TMemLayout): TMemLayout;

    {**
     * Pad
     *
     * @desc 添加填充到指定对齐
     *       Add padding to specified alignment
     *
     * @params
     *   aAlign: SizeUInt 目标对齐
     *
     * @return 填充后的新布局
     *}
    function Pad(aAlign: SizeUInt): TMemLayout;

    {**
     * Empty
     *
     * @desc 获取空布局（零大小，1字节对齐）
     *       Get empty layout (zero size, 1-byte align)
     *}
    class function Empty: TMemLayout; static; inline;

    {**
     * Default alignment for the platform
     * 平台默认对齐
     *}
    class function DefaultAlign: SizeUInt; static; inline;
  end;

  {**
   * TAllocCaps
   *
   * @desc 分配器能力描述
   *       Allocator capabilities descriptor
   *
   * @note 替代旧的 TAllocatorTraits，更诚实地描述分配器能力
   *}
  TAllocCaps = record
    {** 分配时是否自动清零 | Auto zero-fill on allocation *}
    ZeroOnAlloc: Boolean;

    {** 是否线程安全 | Thread-safe *}
    ThreadSafe: Boolean;

    {** 是否能查询已分配块大小 | Can query allocated block size *}
    KnowsSize: Boolean;

    {** 是否原生支持对齐分配 | Native aligned allocation support *}
    NativeAligned: Boolean;

    {** 是否支持 Realloc | Supports reallocation *}
    CanRealloc: Boolean;

    {** 最大支持的对齐（0 = 无限制）| Max supported alignment (0 = unlimited) *}
    MaxAlign: SizeUInt;

    {**
     * Create
     *
     * @desc 创建能力描述
     *}
    class function Create(
      aZeroOnAlloc: Boolean = False;
      aThreadSafe: Boolean = False;
      aKnowsSize: Boolean = False;
      aNativeAligned: Boolean = False;
      aCanRealloc: Boolean = True;
      aMaxAlign: SizeUInt = 0
    ): TAllocCaps; static;

    {**
     * Default
     *
     * @desc 获取默认能力（最小能力集）
     *}
    class function Default: TAllocCaps; static; inline;

    {**
     * ForSystemHeap
     *
     * @desc 获取系统堆的典型能力
     *}
    class function ForSystemHeap: TAllocCaps; static;

    {**
     * SupportsLayout
     *
     * @desc 检查是否支持指定布局
     *
     * @params
     *   aLayout: TMemLayout 要检查的布局
     *
     * @return True 如果支持该布局
     *}
    function SupportsLayout(const aLayout: TMemLayout): Boolean;
  end;

const
  {** 默认对齐大小（指针大小）*}
  MEM_DEFAULT_ALIGN = SizeOf(Pointer);

  {** 缓存行大小（典型值）*}
  MEM_CACHE_LINE_SIZE = 64;

  {** 页面大小（典型值）*}
  MEM_PAGE_SIZE = 4096;

{**
 * IsPowerOfTwo
 *
 * @desc 检查是否是2的幂
 *}
function IsPowerOfTwo(aValue: SizeUInt): Boolean; inline;

{**
 * NextPowerOfTwo
 *
 * @desc 向上取到最近的2的幂（饱和策略：溢出时返回最大2的幂）
 *       Round up to next power of two (saturation: returns max power of two on overflow)
 *
 * @note 如果 aValue > High(SizeUInt)/2 + 1，返回最大的2的幂（2^63 或 2^31）
 *}
function NextPowerOfTwo(aValue: SizeUInt): SizeUInt;

{**
 * TryNextPowerOfTwo
 *
 * @desc 尝试向上取到最近的2的幂
 *       Try to round up to next power of two
 *
 * @params
 *   aValue: SizeUInt 输入值
 *   aResult: out SizeUInt 输出结果
 *
 * @return True 如果成功，False 如果会溢出
 *}
function TryNextPowerOfTwo(aValue: SizeUInt; out aResult: SizeUInt): Boolean;

{**
 * AlignUp
 *
 * @desc 向上对齐到指定边界
 *}
function AlignUp(aValue, aAlign: SizeUInt): SizeUInt; inline;

{**
 * AlignDown
 *
 * @desc 向下对齐到指定边界
 *}
function AlignDown(aValue, aAlign: SizeUInt): SizeUInt; inline;

implementation

{ Helper functions }

function IsPowerOfTwo(aValue: SizeUInt): Boolean;
begin
  Result := (aValue > 0) and ((aValue and (aValue - 1)) = 0);
end;

function NextPowerOfTwo(aValue: SizeUInt): SizeUInt;
const
  // 最大的2的幂（取决于平台：32位或64位）
  {$IFDEF CPU64}
  MAX_POWER_OF_TWO: SizeUInt = SizeUInt(1) shl 63;  // 2^63
  {$ELSE}
  MAX_POWER_OF_TWO: SizeUInt = SizeUInt(1) shl 31;  // 2^31
  {$ENDIF}
begin
  if aValue = 0 then
  begin
    Result := 1;
    Exit;
  end;

  // 已经是2的幂
  if IsPowerOfTwo(aValue) then
  begin
    Result := aValue;
    Exit;
  end;

  // 溢出保护：如果 aValue > MAX_POWER_OF_TWO，返回 MAX_POWER_OF_TWO（饱和策略）
  // 因为下一个2的幂会超过 SizeUInt 的表示范围
  if aValue > MAX_POWER_OF_TWO then
  begin
    Result := MAX_POWER_OF_TWO;
    Exit;
  end;

  // 使用位运算快速计算（避免循环，O(1) 复杂度）
  // 原理：将最高位以下的所有位都置1，然后+1
  Result := aValue - 1;
  Result := Result or (Result shr 1);
  Result := Result or (Result shr 2);
  Result := Result or (Result shr 4);
  Result := Result or (Result shr 8);
  Result := Result or (Result shr 16);
  {$IFDEF CPU64}
  Result := Result or (Result shr 32);
  {$ENDIF}
  Result := Result + 1;
end;

function TryNextPowerOfTwo(aValue: SizeUInt; out aResult: SizeUInt): Boolean;
const
  {$IFDEF CPU64}
  MAX_POWER_OF_TWO: SizeUInt = SizeUInt(1) shl 63;  // 2^63
  {$ELSE}
  MAX_POWER_OF_TWO: SizeUInt = SizeUInt(1) shl 31;  // 2^31
  {$ENDIF}
begin
  if aValue = 0 then
  begin
    aResult := 1;
    Result := True;
    Exit;
  end;

  // 已经是2的幂
  if IsPowerOfTwo(aValue) then
  begin
    aResult := aValue;
    Result := True;
    Exit;
  end;

  // 会溢出
  if aValue > MAX_POWER_OF_TWO then
  begin
    aResult := 0;
    Result := False;
    Exit;
  end;

  // 使用位运算快速计算
  aResult := aValue - 1;
  aResult := aResult or (aResult shr 1);
  aResult := aResult or (aResult shr 2);
  aResult := aResult or (aResult shr 4);
  aResult := aResult or (aResult shr 8);
  aResult := aResult or (aResult shr 16);
  {$IFDEF CPU64}
  aResult := aResult or (aResult shr 32);
  {$ENDIF}
  aResult := aResult + 1;
  Result := True;
end;

function AlignUp(aValue, aAlign: SizeUInt): SizeUInt;
begin
  if aAlign <= 1 then
    Result := aValue
  else
    Result := (aValue + aAlign - 1) and not (aAlign - 1);
end;

function AlignDown(aValue, aAlign: SizeUInt): SizeUInt;
begin
  if aAlign <= 1 then
    Result := aValue
  else
    Result := aValue and not (aAlign - 1);
end;

{ TMemLayout }

class function TMemLayout.Create(aSize: SizeUInt; aAlign: SizeUInt): TMemLayout;
begin
  Result.FSize := aSize;

  // 默认对齐 = 指针大小
  if aAlign = 0 then
    Result.FAlign := MEM_DEFAULT_ALIGN
  else if not IsPowerOfTwo(aAlign) then
    Result.FAlign := NextPowerOfTwo(aAlign)  // 使用饱和策略
  else
    Result.FAlign := aAlign;
end;

class function TMemLayout.TryCreate(aSize: SizeUInt; aAlign: SizeUInt; out aLayout: TMemLayout): Boolean;
var
  LAlign: SizeUInt;
begin
  aLayout.FSize := aSize;

  // 默认对齐 = 指针大小
  if aAlign = 0 then
  begin
    aLayout.FAlign := MEM_DEFAULT_ALIGN;
    Result := True;
    Exit;
  end;

  // 已经是2的幂
  if IsPowerOfTwo(aAlign) then
  begin
    aLayout.FAlign := aAlign;
    Result := True;
    Exit;
  end;

  // 尝试计算下一个2的幂（可能溢出）
  if TryNextPowerOfTwo(aAlign, LAlign) then
  begin
    aLayout.FAlign := LAlign;
    Result := True;
  end
  else
  begin
    // 溢出：返回无效布局
    aLayout.FAlign := 0;  // 无效的对齐
    Result := False;
  end;
end;

generic class function TMemLayout.ForType<T>: TMemLayout;
begin
  Result.FSize := SizeOf(T);
  // Pascal 类型默认对齐通常是类型大小或指针大小中较小者
  if SizeOf(T) >= MEM_DEFAULT_ALIGN then
    Result.FAlign := MEM_DEFAULT_ALIGN
  else if IsPowerOfTwo(SizeOf(T)) then
    Result.FAlign := SizeOf(T)
  else
    Result.FAlign := NextPowerOfTwo(SizeOf(T));
end;

generic class function TMemLayout.ForArray<T>(aCount: SizeUInt): TMemLayout;
var
  LElementSize: SizeUInt;
  LElementAlign: SizeUInt;
begin
  LElementSize := SizeOf(T);

  // 计算元素对齐
  if LElementSize >= MEM_DEFAULT_ALIGN then
    LElementAlign := MEM_DEFAULT_ALIGN
  else if IsPowerOfTwo(LElementSize) then
    LElementAlign := LElementSize
  else
    LElementAlign := NextPowerOfTwo(LElementSize);

  Result.FAlign := LElementAlign;

  // 数组大小 = 元素对齐大小 × 元素数量
  if aCount = 0 then
    Result.FSize := 0
  else
    Result.FSize := AlignUp(LElementSize, LElementAlign) * aCount;
end;

function TMemLayout.IsValid: Boolean;
begin
  // 对齐必须是2的幂
  Result := IsPowerOfTwo(FAlign);
end;

function TMemLayout.IsZeroSized: Boolean;
begin
  Result := FSize = 0;
end;

function TMemLayout.AlignedSize: SizeUInt;
begin
  Result := AlignUp(FSize, FAlign);
end;

function TMemLayout.Extend(const aNext: TMemLayout): TMemLayout;
var
  LNewAlign: SizeUInt;
  LPaddedSize: SizeUInt;
begin
  // 对齐取两者最大值
  if aNext.FAlign > FAlign then
    LNewAlign := aNext.FAlign
  else
    LNewAlign := FAlign;

  // 当前布局填充到 aNext 对齐边界
  LPaddedSize := AlignUp(FSize, aNext.FAlign);

  Result.FSize := LPaddedSize + aNext.FSize;
  Result.FAlign := LNewAlign;
end;

function TMemLayout.Pad(aAlign: SizeUInt): TMemLayout;
var
  LAlign: SizeUInt;
begin
  if not IsPowerOfTwo(aAlign) then
    LAlign := NextPowerOfTwo(aAlign)
  else
    LAlign := aAlign;

  Result.FSize := AlignUp(FSize, LAlign);

  // 对齐取两者最大值
  if LAlign > FAlign then
    Result.FAlign := LAlign
  else
    Result.FAlign := FAlign;
end;

class function TMemLayout.Empty: TMemLayout;
begin
  Result.FSize := 0;
  Result.FAlign := 1;
end;

class function TMemLayout.DefaultAlign: SizeUInt;
begin
  Result := MEM_DEFAULT_ALIGN;
end;

{ TAllocCaps }

class function TAllocCaps.Create(
  aZeroOnAlloc: Boolean;
  aThreadSafe: Boolean;
  aKnowsSize: Boolean;
  aNativeAligned: Boolean;
  aCanRealloc: Boolean;
  aMaxAlign: SizeUInt
): TAllocCaps;
begin
  Result.ZeroOnAlloc := aZeroOnAlloc;
  Result.ThreadSafe := aThreadSafe;
  Result.KnowsSize := aKnowsSize;
  Result.NativeAligned := aNativeAligned;
  Result.CanRealloc := aCanRealloc;
  Result.MaxAlign := aMaxAlign;
end;

class function TAllocCaps.Default: TAllocCaps;
begin
  Result.ZeroOnAlloc := False;
  Result.ThreadSafe := False;
  Result.KnowsSize := False;
  Result.NativeAligned := False;
  Result.CanRealloc := True;
  Result.MaxAlign := 0;
end;

class function TAllocCaps.ForSystemHeap: TAllocCaps;
begin
  Result.ZeroOnAlloc := False;
  Result.ThreadSafe := True;
  Result.KnowsSize := False;
  Result.NativeAligned := False;  // 系统堆通常只保证指针对齐
  Result.CanRealloc := True;
  Result.MaxAlign := MEM_DEFAULT_ALIGN;  // 系统堆默认对齐
end;

function TAllocCaps.SupportsLayout(const aLayout: TMemLayout): Boolean;
begin
  // 检查布局是否有效
  if not aLayout.IsValid then
  begin
    Result := False;
    Exit;
  end;

  // 检查对齐是否在支持范围内
  if NativeAligned then
  begin
    // 原生支持对齐
    if (MaxAlign > 0) and (aLayout.Align > MaxAlign) then
      Result := False
    else
      Result := True;
  end
  else
  begin
    // 不支持对齐分配，只能使用默认对齐
    Result := aLayout.Align <= MEM_DEFAULT_ALIGN;
  end;
end;

end.
