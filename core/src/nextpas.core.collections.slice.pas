unit nextpas.core.collections.slice;


{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.collections.base;

type
  {**
   * TReadOnlySpan<T>
   *
   * @desc 只读切片视图 - 对连续内存区域的零拷贝视图
   * @param T 元素类型
   * @note
   *   - 不拥有内存，仅保存指针和长度
   *   - 零拷贝 O(1) 创建
   *   - 随机访问 O(1)
   *   - 适用于函数参数传递，避免复制
   *
   *   警告: 原始数据释放后 Span 变为悬空指针!
   *}
  generic TReadOnlySpan<T> = record
  public type
    PElement = ^T;
  private
    FPtr: Pointer;      // 起始元素指针（只读视图）
    FCount: SizeUInt;   // 元素数量
    FElemSize: SizeUInt;// 元素大小（字节）
  public
    class function FromPointer(aPtr: Pointer; aCount, aElemSize: SizeUInt): TReadOnlySpan; static; inline;
    function  Count: SizeUInt; inline;
    function  IsEmpty: Boolean; inline;
    function  Get(aIndex: SizeUInt): T; inline;
    function  TryGet(aIndex: SizeUInt; out aElement: T): Boolean; inline;
    function  GetPtr(aIndex: SizeUInt): Pointer; inline;
    function  SubSpan(aIndex, aCount: SizeUInt): TReadOnlySpan; inline;
  end;

  {**
   * TReadOnlySpan2<T>
   *
   * @desc 双段只读切片 - 两段不连续内存的逻辑视图
   * @param T 元素类型
   * @note
   *   - 用于环形缓冲区的两段视图 (wrap-around)
   *   - A段 + B段组成逻辑上连续的序列
   *   - B段可能为空
   *   - 随机访问自动跨越两段
   *}
  generic TReadOnlySpan2<T> = record
  public type
    TSpan = specialize TReadOnlySpan<T>;
  private
    FA: TSpan;
    FB: TSpan; // 可能为空段
  public
    class function FromTwo(constref A, B: TSpan): TReadOnlySpan2; static; inline;
    function  ASpan: TSpan; inline;
    function  BSpan: TSpan; inline;
    function  Count: SizeUInt; inline;
    function  IsEmpty: Boolean; inline;
    function  Get(aIndex: SizeUInt): T; inline;
    function  TryGet(aIndex: SizeUInt; out aElement: T): Boolean; inline;
    function  GetPtr(aIndex: SizeUInt): Pointer; inline;
    function  GetBlock(aIndex: SizeUInt; out aPtr: Pointer; out aLen: SizeUInt): Boolean; inline;
    function  SubSpan(aIndex, aCount: SizeUInt): TReadOnlySpan2;
  end;

implementation

{ TReadOnlySpan<T> }

class function TReadOnlySpan.FromPointer(aPtr: Pointer; aCount, aElemSize: SizeUInt): TReadOnlySpan;
begin
  Result.FPtr := aPtr;
  Result.FCount := aCount;
  Result.FElemSize := aElemSize;
end;

function TReadOnlySpan.Count: SizeUInt; inline;
begin
  Result := FCount;
end;

function TReadOnlySpan.IsEmpty: Boolean; inline;
begin
  Result := FCount = 0;
end;

function TReadOnlySpan.Get(aIndex: SizeUInt): T; inline;
begin
  if aIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('Span.Get: index out of range');
  Result := PElement(PByte(FPtr) + aIndex * FElemSize)^;
end;

function TReadOnlySpan.TryGet(aIndex: SizeUInt; out aElement: T): Boolean; inline;
begin
  if aIndex < FCount then
  begin
    aElement := PElement(PByte(FPtr) + aIndex * FElemSize)^;
    Exit(True);
  end;
  Result := False;
end;

function TReadOnlySpan.GetPtr(aIndex: SizeUInt): Pointer; inline;
begin
  if aIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('Span.GetPtr: index out of range');
  Result := Pointer(PByte(FPtr) + aIndex * FElemSize);
end;

function TReadOnlySpan.SubSpan(aIndex, aCount: SizeUInt): TReadOnlySpan; inline;
var
  LMax: SizeUInt;
begin
  if aCount = 0 then Exit(FromPointer(nil, 0, FElemSize));
  LMax := FCount;
  if (aIndex >= LMax) or (aIndex + aCount > LMax) then
    raise nextpas.core.base.EOutOfRange.Create('Span.SubSpan: range out of bounds');
  Result := FromPointer(Pointer(PByte(FPtr) + aIndex * FElemSize), aCount, FElemSize);
end;

{ TReadOnlySpan2<T> }

class function TReadOnlySpan2.FromTwo(constref A, B: TReadOnlySpan2.TSpan): TReadOnlySpan2;
begin
  Result.FA := A;
  Result.FB := B;
end;

function TReadOnlySpan2.ASpan: TReadOnlySpan2.TSpan; inline;
begin
  Result := FA;
end;

function TReadOnlySpan2.BSpan: TReadOnlySpan2.TSpan; inline;
begin
  Result := FB;
end;

function TReadOnlySpan2.Count: SizeUInt; inline;
begin
  Result := FA.Count + FB.Count;
end;

function TReadOnlySpan2.IsEmpty: Boolean; inline;
begin
  Result := (FA.Count = 0) and (FB.Count = 0);
end;

function TReadOnlySpan2.Get(aIndex: SizeUInt): T; inline;
var
  LA: SizeUInt;
begin
  LA := FA.Count;
  if aIndex < LA then Exit(FA.Get(aIndex));
  aIndex := aIndex - LA;
  if aIndex < FB.Count then Exit(FB.Get(aIndex));
  raise nextpas.core.base.EOutOfRange.Create('Span2.Get: index out of range');
end;

function TReadOnlySpan2.TryGet(aIndex: SizeUInt; out aElement: T): Boolean; inline;
var
  LA: SizeUInt;
begin
  LA := FA.Count;
  if aIndex < LA then Exit(FA.TryGet(aIndex, aElement));
  aIndex := aIndex - LA;
  if aIndex < FB.Count then Exit(FB.TryGet(aIndex, aElement));
  Result := False;
end;

function TReadOnlySpan2.GetPtr(aIndex: SizeUInt): Pointer; inline;
var
  LA: SizeUInt;
begin
  LA := FA.Count;
  if aIndex < LA then Exit(FA.GetPtr(aIndex));
  aIndex := aIndex - LA;
  if aIndex < FB.Count then Exit(FB.GetPtr(aIndex));
  raise nextpas.core.base.EOutOfRange.Create('Span2.GetPtr: index out of range');
end;

function TReadOnlySpan2.GetBlock(aIndex: SizeUInt; out aPtr: Pointer; out aLen: SizeUInt): Boolean; inline;
var
  LA: SizeUInt;
begin
  LA := FA.Count;
  if aIndex < LA then
  begin
    aPtr := FA.GetPtr(aIndex);
    aLen := LA - aIndex; // A 段从 aIndex 到 A 末尾连续
    Exit(True);
  end;
  aIndex := aIndex - LA;
  if aIndex < FB.Count then
  begin
    aPtr := FB.GetPtr(aIndex);
    aLen := FB.Count - aIndex;
    Exit(True);
  end;
  aPtr := nil; aLen := 0; Result := False;
end;

function TReadOnlySpan2.SubSpan(aIndex, aCount: SizeUInt): TReadOnlySpan2;
var
  LA: SizeUInt;
  A1, B1: TSpan;
begin
  if aCount = 0 then Exit(FromTwo(TSpan.FromPointer(nil,0,FA.FElemSize), TSpan.FromPointer(nil,0,FA.FElemSize)));
  if aIndex + aCount > Count then
    raise nextpas.core.base.EOutOfRange.Create('Span2.SubSpan: range out of bounds');
  LA := FA.Count;
  if aIndex < LA then
  begin
    // 起点在 A 段
    if aIndex + aCount <= LA then
    begin
      // 完全落在 A
      A1 := FA.SubSpan(aIndex, aCount);
      B1 := TSpan.FromPointer(nil, 0, FA.FElemSize);
      Exit(FromTwo(A1, B1));
    end
    else
    begin
      // 跨越 A 尾到 B 头
      A1 := FA.SubSpan(aIndex, LA - aIndex);
      B1 := FB.SubSpan(0, aCount - A1.Count);
      Exit(FromTwo(A1, B1));
    end;
  end
  else
  begin
    // 起点在 B 段
    aIndex := aIndex - LA;
    A1 := TSpan.FromPointer(nil, 0, FA.FElemSize);
    B1 := FB.SubSpan(aIndex, aCount);
    Exit(FromTwo(A1, B1));
  end;
end;

end.
