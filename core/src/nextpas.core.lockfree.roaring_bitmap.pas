{******************************************************************************
  nextpas.core.lockfree.roaring_bitmap

  Roaring Bitmap — compressed bitmap with O(1) bit operations.

  Design:
  - Top 16 bits select a "container" (max 65536 containers)
  - Each container stores 16-bit values in two formats:
    - Array container: sorted uint16 array, O(n) space, O(log n) lookup
    - Bitmap container: 8KB bitmap, O(1) lookup, fixed space
  - Auto-promotion: array → bitmap when count exceeds threshold (4096)
  - Set operations: AND/OR/XOR use container-level merging

  Performance:
  - Add/Contains: O(1) with bitmap, O(log n) with array
  - Cardinality: O(number of containers)
  - AND/OR/XOR: O(min(n, m)) container merge
  - Memory: ~2 bytes per set bit for sparse, ~0.125 bytes for dense

  2026-07-06  Phase 4
******************************************************************************}
{$mode ObjFPC}{$H+}{$J-}
unit nextpas.core.lockfree.roaring_bitmap;

interface

uses
  nextpas.core.errors;

const
  RB_CONTAINER_BITS = 16;
  RB_MAX_CONTAINERS = 1 shl RB_CONTAINER_BITS; { 65536 }
  RB_BITMAP_SIZE = 1 shl (RB_CONTAINER_BITS - 3); { 8192 bytes = 65536 bits }
  RB_ARRAY_LIMIT = 4096; { threshold for array→bitmap promotion }

type
  TRBResult = (
    rbOk,
    rbExists,
    rbNotFound
  );

  TRBContainerKind = (
    rckArray,    { sorted uint16 array }
    rckBitmap    { 8KB bitmap }
  );

  {**
   * Roaring Bitmap container — stores 16-bit values.
   *}
  TRBContainer = record
    Kind: TRBContainerKind;
    Count: Int32;    { number of set bits }
    Values: array of UInt16;        { sorted array (only for rckArray) }
    Bits: array[0..RB_BITMAP_SIZE - 1] of Byte; { 8KB bitmap (only for rckBitmap) }
  end;

  PRBContainer = ^TRBContainer;

  {**
   * Roaring Bitmap — compressed bitmap for large sparse/dense sets.
   *
   * @constraints
   *   - 最大支持 2^32 个位 (UInt32)
   *   - 单线程写，多线程读安全（不可变容器引用）
   *}
  TRoaringBitmap = class
  private
    FContainers: array[0..RB_MAX_CONTAINERS - 1] of PRBContainer;
    FCardinality: UInt64;
    FMinKey: UInt32;
    FMaxKey: UInt32;

    function GetContainer(AKey: UInt16): PRBContainer;
    function EnsureContainer(AKey: UInt16): PRBContainer;
    procedure PromoteToBitmap(AContainer: PRBContainer);
    function AddToContainer(AContainer: PRBContainer; AVal: UInt16): Boolean;
    function RemoveFromContainer(AContainer: PRBContainer; AVal: UInt16): Boolean;
    function ContainsInContainer(AContainer: PRBContainer; AVal: UInt16): Boolean;
    procedure FreeContainer(AContainer: PRBContainer);

    { Binary search in sorted array }
    function ArrayContains(AContainer: PRBContainer; AVal: UInt16): Boolean;
    procedure ArrayInsert(AContainer: PRBContainer; AVal: UInt16);
    procedure ArrayRemove(AContainer: PRBContainer; AVal: UInt16);

  public
    constructor Create;
    destructor Destroy; override;

    {**
     * 添加一个位。如果已存在，返回 rbExists。
     *}
    function Add(AValue: UInt32): TRBResult;

    {**
     * 移除一个位。
     *}
    function Remove(AValue: UInt32): TRBResult;

    {**
     * 检查位是否设置。
     *}
    function Contains(AValue: UInt32): Boolean;

    {**
     * 获取设置的位数。
     *}
    function Cardinality: UInt64;

    {**
     * 检查是否为空。
     *}
    function IsEmpty: Boolean;

    {**
     * 与操作，返回新位图。
     *}
    function AndWith(AOther: TRoaringBitmap): TRoaringBitmap;

    {**
     * 或操作，返回新位图。
     *}
    function OrWith(AOther: TRoaringBitmap): TRoaringBitmap;

    {**
     * 异或操作，返回新位图。
     *}
    function XorWith(AOther: TRoaringBitmap): TRoaringBitmap;

    {**
     * 差集操作，返回新位图。
     *}
    function AndNot(AOther: TRoaringBitmap): TRoaringBitmap;

    {**
     * 获取最小值。
     *}
    function Min(out AValue: UInt32): Boolean;

    {**
     * 获取最大值。
     *}
    function Max(out AValue: UInt32): Boolean;

    {**
     * 清空。
     *}
    procedure Clear;
  end;

implementation

{ ---- Binary search helpers ---- }

function TRoaringBitmap.ArrayContains(AContainer: PRBContainer; AVal: UInt16): Boolean;
var
  LLo, LHi, LMid: Int32;
begin
  Result := False;
  if (AContainer = nil) or (AContainer^.Count = 0) then
    Exit;
  LLo := 0;
  LHi := AContainer^.Count - 1;
  while LLo <= LHi do
  begin
    LMid := (LLo + LHi) shr 1;
    if AContainer^.Values[LMid] = AVal then
    begin
      Result := True;
      Exit;
    end
    else if AContainer^.Values[LMid] < AVal then
      LLo := LMid + 1
    else
      LHi := LMid - 1;
  end;
end;

procedure TRoaringBitmap.ArrayInsert(AContainer: PRBContainer; AVal: UInt16);
var
  LLo, LHi, LMid, LPos, I: Int32;
begin
  if AContainer^.Count = 0 then
  begin
    SetLength(AContainer^.Values, 16);
    AContainer^.Values[0] := AVal;
    AContainer^.Count := 1;
    Exit;
  end;

  { Find insertion point }
  LLo := 0;
  LHi := AContainer^.Count - 1;
  LPos := AContainer^.Count;
  while LLo <= LHi do
  begin
    LMid := (LLo + LHi) shr 1;
    if AContainer^.Values[LMid] < AVal then
      LLo := LMid + 1
    else
    begin
      LPos := LMid;
      LHi := LMid - 1;
    end;
  end;

  { Grow array if needed }
  if AContainer^.Count >= Length(AContainer^.Values) then
    SetLength(AContainer^.Values, Length(AContainer^.Values) * 2);

  { Shift and insert }
  for I := AContainer^.Count downto LPos + 1 do
    AContainer^.Values[I] := AContainer^.Values[I - 1];
  AContainer^.Values[LPos] := AVal;
  Inc(AContainer^.Count);
end;

procedure TRoaringBitmap.ArrayRemove(AContainer: PRBContainer; AVal: UInt16);
var
  LLo, LHi, LMid, LPos, I: Int32;
begin
  if AContainer^.Count = 0 then
    Exit;
  LLo := 0;
  LHi := AContainer^.Count - 1;
  LPos := -1;
  while LLo <= LHi do
  begin
    LMid := (LLo + LHi) shr 1;
    if AContainer^.Values[LMid] = AVal then
    begin
      LPos := LMid;
      Break;
    end
    else if AContainer^.Values[LMid] < AVal then
      LLo := LMid + 1
    else
      LHi := LMid - 1;
  end;
  if LPos >= 0 then
  begin
    for I := LPos to AContainer^.Count - 2 do
      AContainer^.Values[I] := AContainer^.Values[I + 1];
    Dec(AContainer^.Count);
  end;
end;

{ ---- Container helpers ---- }

function TRoaringBitmap.GetContainer(AKey: UInt16): PRBContainer;
begin
  Result := FContainers[AKey];
end;

function TRoaringBitmap.EnsureContainer(AKey: UInt16): PRBContainer;
begin
  if FContainers[AKey] = nil then
  begin
    New(FContainers[AKey]);
    FContainers[AKey]^.Kind := rckArray;
    FContainers[AKey]^.Count := 0;
    SetLength(FContainers[AKey]^.Values, 16);
  end;
  Result := FContainers[AKey];
end;

procedure TRoaringBitmap.PromoteToBitmap(AContainer: PRBContainer);
var
  LBits: array[0..RB_BITMAP_SIZE - 1] of Byte;
  I, LBit, LByte: Int32;
begin
  if AContainer^.Kind = rckBitmap then
    Exit;
  FillChar(LBits, SizeOf(LBits), 0);
  for I := 0 to AContainer^.Count - 1 do
  begin
    LBit := AContainer^.Values[I];
    LByte := LBit shr 3;
    LBits[LByte] := LBits[LByte] or (1 shl (LBit and 7));
  end;
  AContainer^.Kind := rckBitmap;
  AContainer^.Bits := LBits;
  { Values array is no longer used, free it }
  SetLength(AContainer^.Values, 0);
end;


function TRoaringBitmap.AddToContainer(AContainer: PRBContainer; AVal: UInt16): Boolean;
var
  LByte, LBit: Int32;
begin
  Result := False;
  if AContainer^.Kind = rckBitmap then
  begin
    LByte := AVal shr 3;
    LBit := 1 shl (AVal and 7);
    if (AContainer^.Bits[LByte] and LBit) = 0 then
    begin
      AContainer^.Bits[LByte] := AContainer^.Bits[LByte] or LBit;
      Inc(AContainer^.Count);
      Result := True;
    end;
  end
  else
  begin
    if ArrayContains(AContainer, AVal) then
      Exit;
    ArrayInsert(AContainer, AVal);
    Result := True;
    if AContainer^.Count >= RB_ARRAY_LIMIT then
      PromoteToBitmap(AContainer);
  end;
end;

function TRoaringBitmap.RemoveFromContainer(AContainer: PRBContainer;
  AVal: UInt16): Boolean;
var
  LByte, LBit: Int32;
begin
  Result := False;
  if AContainer^.Kind = rckBitmap then
  begin
    LByte := AVal shr 3;
    LBit := 1 shl (AVal and 7);
    if (AContainer^.Bits[LByte] and LBit) <> 0 then
    begin
      AContainer^.Bits[LByte] := AContainer^.Bits[LByte] and (not LBit);
      Dec(AContainer^.Count);
      Result := True;
    end;
  end
  else
  begin
    if not ArrayContains(AContainer, AVal) then
      Exit;
    ArrayRemove(AContainer, AVal);
    Result := True;
  end;
end;

function TRoaringBitmap.ContainsInContainer(AContainer: PRBContainer;
  AVal: UInt16): Boolean;
var
  LByte, LBit: Int32;
begin
  if AContainer = nil then
  begin
    Result := False;
    Exit;
  end;
  if AContainer^.Kind = rckBitmap then
  begin
    LByte := AVal shr 3;
    LBit := 1 shl (AVal and 7);
    Result := (AContainer^.Bits[LByte] and LBit) <> 0;
  end
  else
    Result := ArrayContains(AContainer, AVal);
end;

procedure TRoaringBitmap.FreeContainer(AContainer: PRBContainer);
begin
  if AContainer = nil then
    Exit;
  if AContainer^.Kind = rckArray then
    SetLength(AContainer^.Values, 0);
  Dispose(AContainer);
end;

{ ---- TRoaringBitmap ---- }

constructor TRoaringBitmap.Create;
begin
  inherited Create;
  FillChar(FContainers, SizeOf(FContainers), 0);
  FCardinality := 0;
  FMinKey := $FFFFFFFF;
  FMaxKey := 0;
end;

destructor TRoaringBitmap.Destroy;
begin
  Clear;
  inherited Destroy;
end;

procedure TRoaringBitmap.Clear;
var
  I: Int32;
begin
  for I := 0 to RB_MAX_CONTAINERS - 1 do
  begin
    if FContainers[I] <> nil then
    begin
      FreeContainer(FContainers[I]);
      FContainers[I] := nil;
    end;
  end;
  FCardinality := 0;
  FMinKey := $FFFFFFFF;
  FMaxKey := 0;
end;

function TRoaringBitmap.Add(AValue: UInt32): TRBResult;
var
  LHigh: UInt16;
  LLow: UInt16;
  LContainer: PRBContainer;
begin
  LHigh := UInt16(AValue shr RB_CONTAINER_BITS);
  LLow := UInt16(AValue and $FFFF);
  LContainer := EnsureContainer(LHigh);
  if AddToContainer(LContainer, LLow) then
  begin
    Inc(FCardinality);
    if AValue < FMinKey then
      FMinKey := AValue;
    if AValue > FMaxKey then
      FMaxKey := AValue;
    Result := rbOk;
  end
  else
    Result := rbExists;
end;

function TRoaringBitmap.Remove(AValue: UInt32): TRBResult;
var
  LHigh: UInt16;
  LLow: UInt16;
  LContainer: PRBContainer;
begin
  LHigh := UInt16(AValue shr RB_CONTAINER_BITS);
  LLow := UInt16(AValue and $FFFF);
  LContainer := GetContainer(LHigh);
  if (LContainer <> nil) and RemoveFromContainer(LContainer, LLow) then
  begin
    Dec(FCardinality);
    Result := rbOk;
  end
  else
    Result := rbNotFound;
end;

function TRoaringBitmap.Contains(AValue: UInt32): Boolean;
var
  LHigh: UInt16;
  LLow: UInt16;
begin
  LHigh := UInt16(AValue shr RB_CONTAINER_BITS);
  LLow := UInt16(AValue and $FFFF);
  Result := ContainsInContainer(GetContainer(LHigh), LLow);
end;

function TRoaringBitmap.Cardinality: UInt64;
begin
  Result := FCardinality;
end;

function TRoaringBitmap.IsEmpty: Boolean;
begin
  Result := FCardinality = 0;
end;

function TRoaringBitmap.Min(out AValue: UInt32): Boolean;
var
  I, J: Int32;
begin
  Result := False;
  if FCardinality = 0 then
    Exit;
  for I := 0 to RB_MAX_CONTAINERS - 1 do
  begin
    if (FContainers[I] <> nil) and (FContainers[I]^.Count > 0) then
    begin
      if FContainers[I]^.Kind = rckBitmap then
      begin
        for J := 0 to RB_BITMAP_SIZE - 1 do
          if FContainers[I]^.Bits[J] <> 0 then
          begin
            AValue := (UInt32(I) shl RB_CONTAINER_BITS) or
                      UInt32(J * 8 + BsfByte(FContainers[I]^.Bits[J]));
            Result := True;
            Exit;
          end;
      end
      else
      begin
        AValue := (UInt32(I) shl RB_CONTAINER_BITS) or
                  UInt32(FContainers[I]^.Values[0]);
        Result := True;
        Exit;
      end;
    end;
  end;
end;

function TRoaringBitmap.Max(out AValue: UInt32): Boolean;
var
  I, J: Int32;
begin
  Result := False;
  if FCardinality = 0 then
    Exit;
  for I := RB_MAX_CONTAINERS - 1 downto 0 do
  begin
    if (FContainers[I] <> nil) and (FContainers[I]^.Count > 0) then
    begin
      if FContainers[I]^.Kind = rckBitmap then
      begin
        for J := RB_BITMAP_SIZE - 1 downto 0 do
          if FContainers[I]^.Bits[J] <> 0 then
          begin
            AValue := (UInt32(I) shl RB_CONTAINER_BITS) or
                      UInt32(J * 8 + (7 - BsrByte(FContainers[I]^.Bits[J])));
            Result := True;
            Exit;
          end;
      end
      else
      begin
        AValue := (UInt32(I) shl RB_CONTAINER_BITS) or
                  UInt32(FContainers[I]^.Values[FContainers[I]^.Count - 1]);
        Result := True;
        Exit;
      end;
    end;
  end;
end;

function TRoaringBitmap.AndWith(AOther: TRoaringBitmap): TRoaringBitmap;
var
  I, J, LA, LB: Int32;
  LCA, LCB, LCR: PRBContainer;
begin
  Result := TRoaringBitmap.Create;
  if (AOther = nil) then
    Exit;
  for I := 0 to RB_MAX_CONTAINERS - 1 do
  begin
    LCA := FContainers[I];
    LCB := AOther.FContainers[I];
    if (LCA = nil) or (LCB = nil) then
      Continue;
    { AND: both must have the value }
    LCR := Result.EnsureContainer(UInt16(I));
    if (LCA^.Kind = rckBitmap) and (LCB^.Kind = rckBitmap) then
    begin
      { Bitmap AND Bitmap }
      LCR^.Kind := rckBitmap;
      LCR^.Count := 0;
      for J := 0 to RB_BITMAP_SIZE - 1 do
      begin
        LCR^.Bits[J] := LCA^.Bits[J] and LCB^.Bits[J];
        Inc(LCR^.Count, PopCnt(LCR^.Bits[J]));
      end;
    end
    else if (LCA^.Kind = rckArray) and (LCB^.Kind = rckArray) then
    begin
      { Array AND Array: merge-like }
      LA := 0;
      LB := 0;
      while (LA < LCA^.Count) and (LB < LCB^.Count) do
      begin
        if LCA^.Values[LA] = LCB^.Values[LB] then
        begin
          Result.AddToContainer(LCR, LCA^.Values[LA]);
          Inc(LA);
          Inc(LB);
        end
        else if LCA^.Values[LA] < LCB^.Values[LB] then
          Inc(LA)
        else
          Inc(LB);
      end;
    end
    else
    begin
      { Mixed: iterate smaller }
      if LCA^.Kind = rckArray then
      begin
        for J := 0 to LCA^.Count - 1 do
          if Result.ContainsInContainer(LCB, LCA^.Values[J]) then
            Result.AddToContainer(LCR, LCA^.Values[J]);
      end
      else
      begin
        for J := 0 to LCB^.Count - 1 do
          if Result.ContainsInContainer(LCA, LCB^.Values[J]) then
            Result.AddToContainer(LCR, LCB^.Values[J]);
      end;
    end;
    if LCR^.Count = 0 then
    begin
      Result.FreeContainer(LCR);
      Result.FContainers[I] := nil;
    end
    else
      Inc(Result.FCardinality, LCR^.Count);
  end;
end;

function TRoaringBitmap.OrWith(AOther: TRoaringBitmap): TRoaringBitmap;
var
  I, J: Int32;
  LCA, LCB, LCR: PRBContainer;
begin
  Result := TRoaringBitmap.Create;
  if AOther = nil then
  begin
    { Copy self }
    for I := 0 to RB_MAX_CONTAINERS - 1 do
    begin
      if FContainers[I] <> nil then
      begin
        LCR := Result.EnsureContainer(UInt16(I));
        Result.AddToContainer(LCR, 0); { placeholder }
        { Manual copy }
        LCR^ := FContainers[I]^;
        if LCR^.Kind = rckArray then
          SetLength(LCR^.Values, Length(FContainers[I]^.Values));
        Inc(Result.FCardinality, LCR^.Count);
      end;
    end;
    Exit;
  end;
  for I := 0 to RB_MAX_CONTAINERS - 1 do
  begin
    LCA := FContainers[I];
    LCB := AOther.FContainers[I];
    if (LCA = nil) and (LCB = nil) then
      Continue;
    LCR := Result.EnsureContainer(UInt16(I));
    if (LCA <> nil) and (LCB <> nil) then
    begin
      { OR: union }
      if (LCA^.Kind = rckBitmap) and (LCB^.Kind = rckBitmap) then
      begin
        LCR^.Kind := rckBitmap;
        LCR^.Count := 0;
        for J := 0 to RB_BITMAP_SIZE - 1 do
        begin
          LCR^.Bits[J] := LCA^.Bits[J] or LCB^.Bits[J];
          Inc(LCR^.Count, PopCnt(LCR^.Bits[J]));
        end;
      end
      else
      begin
        { Copy one, add from other }
        if LCA^.Kind = rckBitmap then
        begin
          LCR^ := LCA^;
          for J := 0 to LCB^.Count - 1 do
            if not Result.ContainsInContainer(LCA, LCB^.Values[J]) then
              Result.AddToContainer(LCR, LCB^.Values[J]);
        end
        else
        begin
          LCR^ := LCA^;
          for J := 0 to LCB^.Count - 1 do
            Result.AddToContainer(LCR, LCB^.Values[J]);
        end;
      end;
    end
    else if LCA <> nil then
    begin
      LCR^ := LCA^;
      if LCR^.Kind = rckArray then
        SetLength(LCR^.Values, Length(LCA^.Values));
    end
    else
    begin
      LCR^ := LCB^;
      if LCR^.Kind = rckArray then
        SetLength(LCR^.Values, Length(LCB^.Values));
    end;
    Inc(Result.FCardinality, LCR^.Count);
  end;
end;

function TRoaringBitmap.XorWith(AOther: TRoaringBitmap): TRoaringBitmap;
var
  I, J: Int32;
  LCA, LCB, LCR: PRBContainer;
begin
  Result := TRoaringBitmap.Create;
  if AOther = nil then
    Exit;
  for I := 0 to RB_MAX_CONTAINERS - 1 do
  begin
    LCA := FContainers[I];
    LCB := AOther.FContainers[I];
    if (LCA = nil) and (LCB = nil) then
      Continue;
    LCR := Result.EnsureContainer(UInt16(I));
    if (LCA <> nil) and (LCB <> nil) then
    begin
      if (LCA^.Kind = rckBitmap) and (LCB^.Kind = rckBitmap) then
      begin
        LCR^.Kind := rckBitmap;
        LCR^.Count := 0;
        for J := 0 to RB_BITMAP_SIZE - 1 do
        begin
          LCR^.Bits[J] := LCA^.Bits[J] xor LCB^.Bits[J];
          Inc(LCR^.Count, PopCnt(LCR^.Bits[J]));
        end;
      end
      else
      begin
        { Mixed: use array approach }
        LCR^.Kind := rckArray;
        LCR^.Count := 0;
        if LCA^.Kind = rckArray then
        begin
          for J := 0 to LCA^.Count - 1 do
            if not Result.ContainsInContainer(LCB, LCA^.Values[J]) then
              Result.AddToContainer(LCR, LCA^.Values[J]);
          if LCB^.Kind = rckBitmap then
          begin
            for J := 0 to RB_BITMAP_SIZE * 8 - 1 do
              if ((LCB^.Bits[J shr 3] and (1 shl (J and 7))) <> 0) and
                 not Result.ContainsInContainer(LCA, UInt16(J)) then
                Result.AddToContainer(LCR, UInt16(J));
          end
          else
          begin
            for J := 0 to LCB^.Count - 1 do
              if not Result.ContainsInContainer(LCA, LCB^.Values[J]) then
                Result.AddToContainer(LCR, LCB^.Values[J]);
          end;
        end
        else
        begin
          { LCA is bitmap, LCB is array }
          for J := 0 to LCB^.Count - 1 do
            if not Result.ContainsInContainer(LCA, LCB^.Values[J]) then
              Result.AddToContainer(LCR, LCB^.Values[J]);
          for J := 0 to RB_BITMAP_SIZE * 8 - 1 do
            if ((LCA^.Bits[J shr 3] and (1 shl (J and 7))) <> 0) and
               not Result.ContainsInContainer(LCB, UInt16(J)) then
              Result.AddToContainer(LCR, UInt16(J));
        end;
      end;
    end
    else if LCA <> nil then
    begin
      LCR^ := LCA^;
      if LCR^.Kind = rckArray then
        SetLength(LCR^.Values, Length(LCA^.Values));
    end
    else
    begin
      LCR^ := LCB^;
      if LCR^.Kind = rckArray then
        SetLength(LCR^.Values, Length(LCB^.Values));
    end;
    Inc(Result.FCardinality, LCR^.Count);
  end;
end;

function TRoaringBitmap.AndNot(AOther: TRoaringBitmap): TRoaringBitmap;
var
  I, J: Int32;
  LCA, LCB, LCR: PRBContainer;
begin
  Result := TRoaringBitmap.Create;
  if AOther = nil then
  begin
    { Copy self }
    for I := 0 to RB_MAX_CONTAINERS - 1 do
    begin
      if FContainers[I] <> nil then
      begin
        LCR := Result.EnsureContainer(UInt16(I));
        LCR^ := FContainers[I]^;
        if LCR^.Kind = rckArray then
          SetLength(LCR^.Values, Length(FContainers[I]^.Values));
        Inc(Result.FCardinality, LCR^.Count);
      end;
    end;
    Exit;
  end;
  for I := 0 to RB_MAX_CONTAINERS - 1 do
  begin
    LCA := FContainers[I];
    LCB := AOther.FContainers[I];
    if LCA = nil then
      Continue;
    LCR := Result.EnsureContainer(UInt16(I));
    if LCB = nil then
    begin
      LCR^ := LCA^;
      if LCR^.Kind = rckArray then
        SetLength(LCR^.Values, Length(LCA^.Values));
    end
    else
    begin
      { AND NOT: in A but not in B }
      if (LCA^.Kind = rckBitmap) and (LCB^.Kind = rckBitmap) then
      begin
        LCR^.Kind := rckBitmap;
        LCR^.Count := 0;
        for J := 0 to RB_BITMAP_SIZE - 1 do
        begin
          LCR^.Bits[J] := LCA^.Bits[J] and (not LCB^.Bits[J]);
          Inc(LCR^.Count, PopCnt(LCR^.Bits[J]));
        end;
      end
      else
      begin
        LCR^.Kind := rckArray;
        LCR^.Count := 0;
        if LCA^.Kind = rckArray then
        begin
          for J := 0 to LCA^.Count - 1 do
            if not Result.ContainsInContainer(LCB, LCA^.Values[J]) then
              Result.AddToContainer(LCR, LCA^.Values[J]);
        end
        else
        begin
          for J := 0 to RB_BITMAP_SIZE * 8 - 1 do
            if ((LCA^.Bits[J shr 3] and (1 shl (J and 7))) <> 0) and
               not Result.ContainsInContainer(LCB, UInt16(J)) then
              Result.AddToContainer(LCR, UInt16(J));
        end;
      end;
    end;
    if LCR^.Count = 0 then
    begin
      Result.FreeContainer(LCR);
      Result.FContainers[I] := nil;
    end
    else
      Inc(Result.FCardinality, LCR^.Count);
  end;
end;

end.
