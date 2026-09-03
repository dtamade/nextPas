unit nextpas.core.window.hash;

{ window.hash — open-address linear probe (Pointer/UInt32) for window.live.
  Family shard, owner window.impl, not re-exported via facade.
  Capacity/load via window.impl → bytes.ops single source, 0→32→2× pow2. }

{$I nextpas.core.settings.inc}
{$WARN 5024 OFF}

interface

uses
  nextpas.core.window.impl,
  nextpas.core.bytes.ops;

type
  { 具名缓冲：Extract/Adopt 经 ManagedArrayMovePtr 取变量地址转移所有权，open array 形参取址拿到的是描述符（空即 AV），故取址链必须全具名；只读/元素访问仍可用开放数组 }
  generic TWindowHashBuffer<T> = array of T;
  TWindowHashUsed = array of Boolean;

function WindowHashNeedsGrow(const AToken: TWindowFamilyToken; ACount, ACap: Integer): Boolean; inline;
function WindowHashGrowCapacity(const AToken: TWindowFamilyToken; ACap: Integer): Integer; inline;
function WindowHashPtrIdx(const AToken: TWindowFamilyToken; APtr: Pointer; AMask: Integer): Integer; inline;
function WindowHashU32Idx(const AToken: TWindowFamilyToken; AID: UInt32; AMask: Integer): Integer; inline;

procedure WindowHashInsertPtr(const AToken: TWindowFamilyToken; var AKeys: specialize TWindowHashBuffer<Pointer>; var AIdx: specialize TWindowHashBuffer<Integer>; var AUsed: TWindowHashUsed; APtr: Pointer; AIdxVal: Integer); inline;
procedure WindowHashRemovePtr(const AToken: TWindowFamilyToken; var AKeys: specialize TWindowHashBuffer<Pointer>; var AIdx: specialize TWindowHashBuffer<Integer>; var AUsed: TWindowHashUsed; APtr: Pointer); inline;
function WindowHashFindPtr(const AToken: TWindowFamilyToken; const AKeys: array of Pointer; const AIdx: array of Integer; const AUsed: array of Boolean; APtr: Pointer): Integer; inline;
procedure WindowHashRebuildPtr(const AToken: TWindowFamilyToken; var AKeys: array of Pointer; var AIdx: array of Integer; var AUsed: array of Boolean; const AList: array of Pointer; ACount: Integer);

procedure WindowHashInsertU32(const AToken: TWindowFamilyToken; var AKeys: specialize TWindowHashBuffer<UInt32>; var AVals: specialize TWindowHashBuffer<Pointer>; var AUsed: TWindowHashUsed; AID: UInt32; APtr: Pointer); inline;
procedure WindowHashRemoveU32(const AToken: TWindowFamilyToken; var AKeys: specialize TWindowHashBuffer<UInt32>; var AVals: specialize TWindowHashBuffer<Pointer>; var AUsed: TWindowHashUsed; AID: UInt32); inline;
function WindowHashFindU32(const AToken: TWindowFamilyToken; const AKeys: array of UInt32; const AVals: array of Pointer; const AUsed: array of Boolean; AID: UInt32): Pointer; inline;
procedure WindowHashRebuildU32(const AToken: TWindowFamilyToken; var AKeys: array of UInt32; var AVals: array of Pointer; var AUsed: array of Boolean; const AIDs: array of UInt32; const AList: array of Pointer; ACount: Integer);

// ---- generic open-hash record (single source for Ptr/U32) ----
// Live registry operates record directly; raw arrays only via Adopt/Extract.

type
  generic TWindowOpenHash<TKey, TVal> = record
  private
    FKeys: array of TKey;
    FVals: array of TVal;
    FUsed: array of Boolean;
  public
    procedure Clear; inline;
    procedure Insert(const AToken: TWindowFamilyToken; const AKey: TKey; const AVal: TVal); inline;
    procedure Remove(const AToken: TWindowFamilyToken; const AKey: TKey); inline;
    function FindPos(const AToken: TWindowFamilyToken; const AKey: TKey): Integer; inline;
    function Find(const AToken: TWindowFamilyToken; const AKey: TKey): TVal; inline;
    function NeedsGrow(const AToken: TWindowFamilyToken; ACount: Integer): Boolean; inline;
    function Cap: Integer; inline;
    procedure Resize(const AToken: TWindowFamilyToken; ANewCap: Integer); inline;
    procedure ExtractBuffers(var AKeys: specialize TWindowHashBuffer<TKey>; var AVals: specialize TWindowHashBuffer<TVal>; var AUsed: TWindowHashUsed); inline;
    procedure AdoptBuffers(var AKeys: specialize TWindowHashBuffer<TKey>; var AVals: specialize TWindowHashBuffer<TVal>; var AUsed: TWindowHashUsed); inline;
    function ValueAt(APos: Integer): TVal; inline;
  end;

type
  TWindowPtrHash = specialize TWindowOpenHash<Pointer, Integer>;
  TWindowU32Hash = specialize TWindowOpenHash<UInt32, Pointer>;

procedure WindowHashRebuild(var AHash: TWindowPtrHash; const AToken: TWindowFamilyToken; const AList: array of Pointer; ACount: Integer); overload; inline;
procedure WindowHashRebuild(var AHash: TWindowU32Hash; const AToken: TWindowFamilyToken; const AIDs: array of UInt32; const AList: array of Pointer; ACount: Integer); overload; inline;
procedure WindowHashEnsureCapacity(var AHash: TWindowPtrHash; const AToken: TWindowFamilyToken; ANewCap: Integer; const AList: array of Pointer; ACount: Integer); overload; inline;
procedure WindowHashEnsureCapacity(var AHash: TWindowU32Hash; const AToken: TWindowFamilyToken; ANewCap: Integer; const AIDs: array of UInt32; const AList: array of Pointer; ACount: Integer); overload; inline;
procedure WindowHashEnsureCapacityPtr(const AToken: TWindowFamilyToken; var AHash: TWindowPtrHash; ANewCap: Integer; const AList: array of Pointer; ACount: Integer);
procedure WindowHashEnsureCapacityU32(const AToken: TWindowFamilyToken; var AHash: TWindowU32Hash; ANewCap: Integer; const AIDs: array of UInt32; const AList: array of Pointer; ACount: Integer);

{ 通用内核前向声明：接口泛型记录方法体仅可引用接口符号，单源实现仍在 implementation }
generic procedure GenClearRaw<TKey, TVal>(var AKeys: array of TKey; var AVals: array of TVal; var AUsed: array of Boolean); inline;
generic procedure GenClearManaged<TKey, TVal>(var AKeys: array of TKey; var AVals: array of TVal; var AUsed: array of Boolean); inline;
generic procedure GenClear<TKey, TVal>(var AKeys: array of TKey; var AVals: array of TVal; var AUsed: array of Boolean); inline;
generic procedure GenInsertUnchecked<TKey, TVal>(const AToken: TWindowFamilyToken; var AKeys: array of TKey; var AVals: array of TVal; var AUsed: array of Boolean; const AKey: TKey; const AVal: TVal);
generic procedure GenInsert<TKey, TVal>(const AToken: TWindowFamilyToken; var AKeys: array of TKey; var AVals: array of TVal; var AUsed: array of Boolean; const AKey: TKey; const AVal: TVal); inline;
generic procedure GenRemoveRaw<TKey, TVal>(const AToken: TWindowFamilyToken; var AKeys: array of TKey; var AVals: array of TVal; var AUsed: array of Boolean; const AKey: TKey);
generic procedure GenRemoveManaged<TKey, TVal>(const AToken: TWindowFamilyToken; var AKeys: array of TKey; var AVals: array of TVal; var AUsed: array of Boolean; const AKey: TKey);
generic procedure GenRemove<TKey, TVal>(const AToken: TWindowFamilyToken; var AKeys: array of TKey; var AVals: array of TVal; var AUsed: array of Boolean; const AKey: TKey); inline;
generic function GenFindPos<TKey>(const AToken: TWindowFamilyToken; const AKeys: array of TKey; const AUsed: array of Boolean; const AKey: TKey): Integer;
function HashIdx(const AToken: TWindowFamilyToken; AKey: Pointer; AMask: Integer): Integer; inline; overload;
function HashIdx(const AToken: TWindowFamilyToken; AKey: UInt32; AMask: Integer): Integer; inline; overload;

implementation

function WindowHashNeedsGrow(const AToken: TWindowFamilyToken; ACount, ACap: Integer): Boolean; inline;
begin
  RequireWindowFamilyToken(AToken);
  Result := nextpas.core.window.impl.WindowHashNeedsGrow(ACount, ACap);
end;

function WindowHashGrowCapacity(const AToken: TWindowFamilyToken; ACap: Integer): Integer; inline;
begin
  RequireWindowFamilyToken(AToken);
  Result := WindowGrowCapacity(ACap);
end;

function WindowHashPtrIdx(const AToken: TWindowFamilyToken; APtr: Pointer; AMask: Integer): Integer; inline;
var H: PtrUInt;
begin
  RequireWindowFamilyToken(AToken);
  H := PtrUInt(APtr) xor (PtrUInt(APtr) shr 16);
  Result := Integer(H and PtrUInt(AMask));
end;

function WindowHashU32Idx(const AToken: TWindowFamilyToken; AID: UInt32; AMask: Integer): Integer; inline;
begin
  RequireWindowFamilyToken(AToken);
  Result := Integer(AID and UInt32(AMask));
end;

// ---- hash dispatch for generic kernels ----

function HashIdx(const AToken: TWindowFamilyToken; AKey: Pointer; AMask: Integer): Integer; inline; overload;
begin
  Result := WindowHashPtrIdx(AToken, AKey, AMask);
end;

function HashIdx(const AToken: TWindowFamilyToken; AKey: UInt32; AMask: Integer): Integer; inline; overload;
begin
  Result := WindowHashU32Idx(AToken, AKey, AMask);
end;

// ---- clear helpers (small, inline) ----

generic procedure GenClearRaw<TKey, TVal>(var AKeys: array of TKey; var AVals: array of TVal; var AUsed: array of Boolean); inline;
var LLenKeys, LLenVals, LLenUsed: Integer;
begin
  LLenKeys := Length(AKeys);
  LLenVals := Length(AVals);
  LLenUsed := Length(AUsed);
  if LLenKeys > 0 then FillChar(AKeys[0], LLenKeys * SizeOf(TKey), 0);
  if LLenVals > 0 then FillChar(AVals[0], LLenVals * SizeOf(TVal), 0);
  if LLenUsed > 0 then FillChar(AUsed[0], LLenUsed * SizeOf(Boolean), 0);
end;

generic procedure GenClearManaged<TKey, TVal>(var AKeys: array of TKey; var AVals: array of TVal; var AUsed: array of Boolean); inline;
var LLenKeys, LLenVals, LLenUsed: Integer;
begin
  LLenKeys := Length(AKeys);
  LLenVals := Length(AVals);
  LLenUsed := Length(AUsed);
  if IsManagedType(TKey) and (LLenKeys > 0) then
  begin
    ManagedFinalizeArray(@AKeys[0], TypeInfo(TKey), LLenKeys);
    FillChar(AKeys[0], LLenKeys * SizeOf(TKey), 0);
  end else if LLenKeys > 0 then
    FillChar(AKeys[0], LLenKeys * SizeOf(TKey), 0);
  if IsManagedType(TVal) and (LLenVals > 0) then
  begin
    ManagedFinalizeArray(@AVals[0], TypeInfo(TVal), LLenVals);
    FillChar(AVals[0], LLenVals * SizeOf(TVal), 0);
  end else if LLenVals > 0 then
    FillChar(AVals[0], LLenVals * SizeOf(TVal), 0);
  if LLenUsed > 0 then
    FillChar(AUsed[0], LLenUsed * SizeOf(Boolean), 0);
end;

generic procedure GenClear<TKey, TVal>(var AKeys: array of TKey; var AVals: array of TVal; var AUsed: array of Boolean); inline;
begin
  if IsManagedType(TKey) or IsManagedType(TVal) then
    specialize GenClearManaged<TKey, TVal>(AKeys, AVals, AUsed)
  else
    specialize GenClearRaw<TKey, TVal>(AKeys, AVals, AUsed);
end;

// ---- probe kernels (contain loops, not inline per redline #2) ----

generic procedure GenInsertUnchecked<TKey, TVal>(const AToken: TWindowFamilyToken; var AKeys: array of TKey; var AVals: array of TVal; var AUsed: array of Boolean; const AKey: TKey; const AVal: TVal);
var LCap, LMask, LIdx, LProbe: Integer;
begin
  LCap := Length(AKeys);
  if (LCap = 0) or (AKey = Default(TKey)) then Exit;
  LMask := LCap - 1;
  LIdx := HashIdx(AToken, AKey, LMask);
  for LProbe := 0 to LCap - 1 do
  begin
    if not AUsed[LIdx] then
    begin
      AKeys[LIdx] := AKey;
      AVals[LIdx] := AVal;
      AUsed[LIdx] := True;
      Exit;
    end;
    if AKeys[LIdx] = AKey then
    begin
      AVals[LIdx] := AVal;
      Exit;
    end;
    LIdx := (LIdx + 1) and LMask;
  end;
end;

generic procedure GenInsert<TKey, TVal>(const AToken: TWindowFamilyToken; var AKeys: array of TKey; var AVals: array of TVal; var AUsed: array of Boolean; const AKey: TKey; const AVal: TVal); inline;
begin
  RequireWindowFamilyToken(AToken);
  specialize GenInsertUnchecked<TKey, TVal>(AToken, AKeys, AVals, AUsed, AKey, AVal);
end;

generic procedure GenRemoveRaw<TKey, TVal>(const AToken: TWindowFamilyToken; var AKeys: array of TKey; var AVals: array of TVal; var AUsed: array of Boolean; const AKey: TKey);
var LCap, LMask, LIdx, LProbe, LNext, LFree, LHome: Integer;
begin
  RequireWindowFamilyToken(AToken);
  LCap := Length(AKeys);
  if (LCap = 0) or (AKey = Default(TKey)) then Exit;
  LMask := LCap - 1;
  LIdx := HashIdx(AToken, AKey, LMask);
  for LProbe := 0 to LCap - 1 do
  begin
    if not AUsed[LIdx] then Exit;
    if AKeys[LIdx] = AKey then Break;
    LIdx := (LIdx + 1) and LMask;
  end;
  if (LIdx >= LCap) or (not AUsed[LIdx]) or (AKeys[LIdx] <> AKey) then Exit;
  FillChar(AKeys[LIdx], SizeOf(TKey), 0);
  FillChar(AVals[LIdx], SizeOf(TVal), 0);
  AUsed[LIdx] := False;
  LFree := LIdx;
  LNext := (LFree + 1) and LMask;
  while AUsed[LNext] do
  begin
    LHome := HashIdx(AToken, AKeys[LNext], LMask);
    if ((LFree - LHome) and LMask) < ((LNext - LHome) and LMask) then
    begin
      Move(AKeys[LNext], AKeys[LFree], SizeOf(TKey));
      FillChar(AKeys[LNext], SizeOf(TKey), 0);
      Move(AVals[LNext], AVals[LFree], SizeOf(TVal));
      FillChar(AVals[LNext], SizeOf(TVal), 0);
      AUsed[LFree] := True;
      AUsed[LNext] := False;
      LFree := LNext;
    end;
    LNext := (LNext + 1) and LMask;
    if LNext = LIdx then Break;
  end;
end;

generic procedure GenRemoveManaged<TKey, TVal>(const AToken: TWindowFamilyToken; var AKeys: array of TKey; var AVals: array of TVal; var AUsed: array of Boolean; const AKey: TKey);
var LCap, LMask, LIdx, LProbe, LNext, LFree, LHome: Integer;
begin
  RequireWindowFamilyToken(AToken);
  LCap := Length(AKeys);
  if (LCap = 0) or (AKey = Default(TKey)) then Exit;
  LMask := LCap - 1;
  LIdx := HashIdx(AToken, AKey, LMask);
  for LProbe := 0 to LCap - 1 do
  begin
    if not AUsed[LIdx] then Exit;
    if AKeys[LIdx] = AKey then Break;
    LIdx := (LIdx + 1) and LMask;
  end;
  if (LIdx >= LCap) or (not AUsed[LIdx]) or (AKeys[LIdx] <> AKey) then Exit;
  ManagedFinalizeArray(@AKeys[LIdx], TypeInfo(TKey), 1);
  FillChar(AKeys[LIdx], SizeOf(TKey), 0);
  ManagedFinalizeArray(@AVals[LIdx], TypeInfo(TVal), 1);
  FillChar(AVals[LIdx], SizeOf(TVal), 0);
  AUsed[LIdx] := False;
  LFree := LIdx;
  LNext := (LFree + 1) and LMask;
  while AUsed[LNext] do
  begin
    LHome := HashIdx(AToken, AKeys[LNext], LMask);
    if ((LFree - LHome) and LMask) < ((LNext - LHome) and LMask) then
    begin
      ManagedCopyArray(@AKeys[LFree], @AKeys[LNext], TypeInfo(TKey), 1);
      ManagedFinalizeArray(@AKeys[LNext], TypeInfo(TKey), 1);
      FillChar(AKeys[LNext], SizeOf(TKey), 0);
      ManagedCopyArray(@AVals[LFree], @AVals[LNext], TypeInfo(TVal), 1);
      ManagedFinalizeArray(@AVals[LNext], TypeInfo(TVal), 1);
      FillChar(AVals[LNext], SizeOf(TVal), 0);
      AUsed[LFree] := True;
      AUsed[LNext] := False;
      LFree := LNext;
    end;
    LNext := (LNext + 1) and LMask;
    if LNext = LIdx then Break;
  end;
end;

generic procedure GenRemove<TKey, TVal>(const AToken: TWindowFamilyToken; var AKeys: array of TKey; var AVals: array of TVal; var AUsed: array of Boolean; const AKey: TKey); inline;
begin
  if IsManagedType(TKey) or IsManagedType(TVal) then
    specialize GenRemoveManaged<TKey, TVal>(AToken, AKeys, AVals, AUsed, AKey)
  else
    specialize GenRemoveRaw<TKey, TVal>(AToken, AKeys, AVals, AUsed, AKey);
end;

generic function GenFindPos<TKey>(const AToken: TWindowFamilyToken; const AKeys: array of TKey; const AUsed: array of Boolean; const AKey: TKey): Integer;
var LCap, LMask, LIdx, LProbe: Integer;
begin
  RequireWindowFamilyToken(AToken);
  Result := -1;
  LCap := Length(AKeys);
  if (LCap = 0) or (AKey = Default(TKey)) then Exit;
  LMask := LCap - 1;
  LIdx := HashIdx(AToken, AKey, LMask);
  for LProbe := 0 to LCap - 1 do
  begin
    if not AUsed[LIdx] then Exit;
    if AKeys[LIdx] = AKey then Exit(LIdx);
    LIdx := (LIdx + 1) and LMask;
  end;
end;

// ---- TWindowOpenHash methods (thin, inline, zero-copy) ----

procedure TWindowOpenHash.Clear; inline;
begin
  specialize GenClear<TKey, TVal>(Self.FKeys, Self.FVals, Self.FUsed);
  SetLength(Self.FKeys, 0);
  SetLength(Self.FVals, 0);
  SetLength(Self.FUsed, 0);
end;

procedure TWindowOpenHash.Insert(const AToken: TWindowFamilyToken; const AKey: TKey; const AVal: TVal); inline;
begin
  specialize GenInsert<TKey, TVal>(AToken, Self.FKeys, Self.FVals, Self.FUsed, AKey, AVal);
end;

procedure TWindowOpenHash.Remove(const AToken: TWindowFamilyToken; const AKey: TKey); inline;
begin
  specialize GenRemove<TKey, TVal>(AToken, Self.FKeys, Self.FVals, Self.FUsed, AKey);
end;

function TWindowOpenHash.FindPos(const AToken: TWindowFamilyToken; const AKey: TKey): Integer; inline;
begin
  Result := specialize GenFindPos<TKey>(AToken, Self.FKeys, Self.FUsed, AKey);
end;

function TWindowOpenHash.Find(const AToken: TWindowFamilyToken; const AKey: TKey): TVal; inline;
var LPos: Integer;
begin
  LPos := specialize GenFindPos<TKey>(AToken, Self.FKeys, Self.FUsed, AKey);
  if LPos < 0 then Exit(Default(TVal));
  Result := Self.FVals[LPos];
end;

function TWindowOpenHash.NeedsGrow(const AToken: TWindowFamilyToken; ACount: Integer): Boolean; inline;
begin
  Result := WindowHashNeedsGrow(AToken, ACount, Length(Self.FKeys));
end;

function TWindowOpenHash.Cap: Integer; inline;
begin
  Result := Length(Self.FKeys);
end;

procedure TWindowOpenHash.Resize(const AToken: TWindowFamilyToken; ANewCap: Integer); inline;
begin
  RequireWindowFamilyToken(AToken);
  SetLength(Self.FKeys, ANewCap);
  SetLength(Self.FVals, ANewCap);
  SetLength(Self.FUsed, ANewCap);
end;

procedure TWindowOpenHash.ExtractBuffers(var AKeys: specialize TWindowHashBuffer<TKey>; var AVals: specialize TWindowHashBuffer<TVal>; var AUsed: TWindowHashUsed); inline;
begin
  // open 数组形参禁直接赋值，指针交换单源 ManagedArrayMove 语义等价（AKeys 需 nil/已托管释放）
  ManagedArrayMovePtr(AKeys, Self.FKeys);
  ManagedArrayMovePtr(AVals, Self.FVals);
  ManagedArrayMovePtr(AUsed, Self.FUsed);
end;

procedure TWindowOpenHash.AdoptBuffers(var AKeys: specialize TWindowHashBuffer<TKey>; var AVals: specialize TWindowHashBuffer<TVal>; var AUsed: TWindowHashUsed); inline;
begin
  // 同上，记录侧 F* 需 nil（fresh/刚 Extract），调用方缓冲移交后置 nil
  ManagedArrayMovePtr(Self.FKeys, AKeys);
  ManagedArrayMovePtr(Self.FVals, AVals);
  ManagedArrayMovePtr(Self.FUsed, AUsed);
end;

function TWindowOpenHash.ValueAt(APos: Integer): TVal; inline;
begin
  if (APos >= 0) and (APos < Length(Self.FVals)) and Self.FUsed[APos] then
    Result := Self.FVals[APos]
  else
    Result := Default(TVal);
end;

// ---- record-level rebuild/capacity (encapsulated, arrays not leaked) ----

procedure WindowHashRebuild(var AHash: TWindowPtrHash; const AToken: TWindowFamilyToken; const AList: array of Pointer; ACount: Integer); overload; inline;
begin
  WindowHashRebuildPtr(AToken, AHash.FKeys, AHash.FVals, AHash.FUsed, AList, ACount);
end;

procedure WindowHashRebuild(var AHash: TWindowU32Hash; const AToken: TWindowFamilyToken; const AIDs: array of UInt32; const AList: array of Pointer; ACount: Integer); overload; inline;
begin
  WindowHashRebuildU32(AToken, AHash.FKeys, AHash.FVals, AHash.FUsed, AIDs, AList, ACount);
end;

procedure WindowHashEnsureCapacity(var AHash: TWindowPtrHash; const AToken: TWindowFamilyToken; ANewCap: Integer; const AList: array of Pointer; ACount: Integer); overload; inline;
begin
  WindowHashEnsureCapacityPtr(AToken, AHash, ANewCap, AList, ACount);
end;

procedure WindowHashEnsureCapacity(var AHash: TWindowU32Hash; const AToken: TWindowFamilyToken; ANewCap: Integer; const AIDs: array of UInt32; const AList: array of Pointer; ACount: Integer); overload; inline;
begin
  WindowHashEnsureCapacityU32(AToken, AHash, ANewCap, AIDs, AList, ACount);
end;

// ---- raw-array wrappers via record Adopt/Extract (single source) ----

procedure WindowHashInsertPtr(const AToken: TWindowFamilyToken; var AKeys: specialize TWindowHashBuffer<Pointer>; var AIdx: specialize TWindowHashBuffer<Integer>; var AUsed: TWindowHashUsed; APtr: Pointer; AIdxVal: Integer); inline;
var LH: TWindowPtrHash;
begin
  LH.AdoptBuffers(AKeys, AIdx, AUsed);
  LH.Insert(AToken, APtr, AIdxVal);
  LH.ExtractBuffers(AKeys, AIdx, AUsed);
end;

procedure WindowHashRemovePtr(const AToken: TWindowFamilyToken; var AKeys: specialize TWindowHashBuffer<Pointer>; var AIdx: specialize TWindowHashBuffer<Integer>; var AUsed: TWindowHashUsed; APtr: Pointer); inline;
var LH: TWindowPtrHash;
begin
  LH.AdoptBuffers(AKeys, AIdx, AUsed);
  LH.Remove(AToken, APtr);
  LH.ExtractBuffers(AKeys, AIdx, AUsed);
end;

function WindowHashFindPtr(const AToken: TWindowFamilyToken; const AKeys: array of Pointer; const AIdx: array of Integer; const AUsed: array of Boolean; APtr: Pointer): Integer; inline;
var LPos: Integer;
begin
  LPos := specialize GenFindPos<Pointer>(AToken, AKeys, AUsed, APtr);
  if LPos < 0 then Exit(-1);
  Result := AIdx[LPos];
end;

procedure BktSortForPtr(
  const AToken: TWindowFamilyToken; const AList: array of Pointer;
  ACount, ACap, AMask: Integer;
  var LBktCnt, LBktPos, LBktCur: array of Integer;
  var LSortedPtr: array of Pointer; var LSortedIdx: array of Integer);
var I, LPos, LHome: Integer;
begin
  if ACap > 0 then FillChar(LBktCnt[0], ACap * SizeOf(Integer), 0);
  for I := 0 to ACount - 1 do if AList[I] <> nil then
  begin
    LHome := WindowHashPtrIdx(AToken, AList[I], AMask);
    Inc(LBktCnt[LHome]);
  end;
  LPos := 0;
  for I := 0 to ACap - 1 do
  begin
    LBktPos[I] := LPos;
    Inc(LPos, LBktCnt[I]);
  end;
  for I := 0 to ACap - 1 do LBktCur[I] := LBktPos[I];
  for I := 0 to ACount - 1 do if AList[I] <> nil then
  begin
    LHome := WindowHashPtrIdx(AToken, AList[I], AMask);
    LPos := LBktCur[LHome];
    LSortedPtr[LPos] := AList[I];
    LSortedIdx[LPos] := I;
    Inc(LBktCur[LHome]);
  end;
end;

// Generic counting-sort for U32→Pointer (O(n+cap), not inline).
generic procedure GenBktCountingSort<TKey, TVal>(
  const AToken: TWindowFamilyToken;
  const ASrcKeys: array of TKey; const ASrcVals: array of TVal;
  ACount, ACap, AMask: Integer;
  var LBktCnt, LBktPos, LBktCur: array of Integer;
  var LSortedKeys: array of TKey; var LSortedVals: array of TVal);
var I, LPos, LHome: Integer;
begin
  if ACap > 0 then FillChar(LBktCnt[0], ACap * SizeOf(Integer), 0);
  for I := 0 to ACount - 1 do if ASrcKeys[I] <> Default(TKey) then
  begin
    LHome := HashIdx(AToken, ASrcKeys[I], AMask);
    Inc(LBktCnt[LHome]);
  end;
  LPos := 0;
  for I := 0 to ACap - 1 do
  begin
    LBktPos[I] := LPos;
    Inc(LPos, LBktCnt[I]);
  end;
  for I := 0 to ACap - 1 do LBktCur[I] := LBktPos[I];
  for I := 0 to ACount - 1 do if ASrcKeys[I] <> Default(TKey) then
  begin
    LHome := HashIdx(AToken, ASrcKeys[I], AMask);
    LPos := LBktCur[LHome];
    LSortedKeys[LPos] := ASrcKeys[I];
    LSortedVals[LPos] := ASrcVals[I];
    Inc(LBktCur[LHome]);
  end;
end;

procedure WindowHashRebuildPtr(const AToken: TWindowFamilyToken; var AKeys: array of Pointer; var AIdx: array of Integer; var AUsed: array of Boolean; const AList: array of Pointer; ACount: Integer);
var I, LCap, LMask, LValid: Integer;
  LBktCnt, LBktPos, LBktCur: array of Integer;
  LSortedPtr: array of Pointer;
  LSortedIdx: array of Integer;
  LArena: THashRebuildArena;
  LFromPool: Boolean;
begin
  RequireWindowFamilyToken(AToken);
  if Length(AKeys) = 0 then Exit;
  specialize GenClearRaw<Pointer, Integer>(AKeys, AIdx, AUsed);
  if ACount <= 0 then Exit;
  LCap := Length(AKeys);
  LMask := LCap - 1;
  if ACount > 1024 then
  begin
    LValid := 0;
    for I := 0 to ACount - 1 do if AList[I] <> nil then Inc(LValid);
    if LValid = 0 then Exit;
    LArena := HashRebuildArenaAcquire(LFromPool);
    try
      LArena.EnsureForPtr(LCap, LValid);
      LBktCnt := LArena.BktCnt;
      LBktPos := LArena.BktPos;
      LBktCur := LArena.BktCur;
      LSortedPtr := LArena.SortedPtr;
      LSortedIdx := LArena.SortedIdx;
      BktSortForPtr(AToken, AList, ACount, LCap, LMask, LBktCnt, LBktPos, LBktCur, LSortedPtr, LSortedIdx);
      for I := 0 to LValid - 1 do
        specialize GenInsertUnchecked<Pointer, Integer>(AToken, AKeys, AIdx, AUsed, LSortedPtr[I], LSortedIdx[I]);
      LBktCnt := nil; LBktPos := nil; LBktCur := nil; LSortedPtr := nil; LSortedIdx := nil;
    finally
      HashRebuildArenaRecycle(LArena);
    end;
  end else
  begin
    for I := 0 to ACount - 1 do
      if AList[I] <> nil then
        specialize GenInsertUnchecked<Pointer, Integer>(AToken, AKeys, AIdx, AUsed, AList[I], I);
  end;
end;

function WindowHashAlignCapacity(const AToken: TWindowFamilyToken; ANewCap: Integer): Integer; inline;
begin
  RequireWindowFamilyToken(AToken);
  Result := nextpas.core.window.impl.WindowHashAlignCapacity(ANewCap);
end;

procedure WindowHashEnsureCapacityPtr(const AToken: TWindowFamilyToken; var AHash: TWindowPtrHash; ANewCap: Integer; const AList: array of Pointer; ACount: Integer);
var LCap: Integer;
begin
  RequireWindowFamilyToken(AToken);
  if ANewCap <= Length(AHash.FKeys) then Exit;
  LCap := WindowHashAlignCapacity(AToken, ANewCap);
  SetLength(AHash.FKeys, LCap);
  SetLength(AHash.FVals, LCap);
  SetLength(AHash.FUsed, LCap);
  WindowHashRebuildPtr(AToken, AHash.FKeys, AHash.FVals, AHash.FUsed, AList, ACount);
end;

procedure WindowHashInsertU32(const AToken: TWindowFamilyToken; var AKeys: specialize TWindowHashBuffer<UInt32>; var AVals: specialize TWindowHashBuffer<Pointer>; var AUsed: TWindowHashUsed; AID: UInt32; APtr: Pointer); inline;
var LH: TWindowU32Hash;
begin
  LH.AdoptBuffers(AKeys, AVals, AUsed);
  LH.Insert(AToken, AID, APtr);
  LH.ExtractBuffers(AKeys, AVals, AUsed);
end;

procedure WindowHashRemoveU32(const AToken: TWindowFamilyToken; var AKeys: specialize TWindowHashBuffer<UInt32>; var AVals: specialize TWindowHashBuffer<Pointer>; var AUsed: TWindowHashUsed; AID: UInt32); inline;
var LH: TWindowU32Hash;
begin
  LH.AdoptBuffers(AKeys, AVals, AUsed);
  LH.Remove(AToken, AID);
  LH.ExtractBuffers(AKeys, AVals, AUsed);
end;

function WindowHashFindU32(const AToken: TWindowFamilyToken; const AKeys: array of UInt32; const AVals: array of Pointer; const AUsed: array of Boolean; AID: UInt32): Pointer; inline;
var LPos: Integer;
begin
  LPos := specialize GenFindPos<UInt32>(AToken, AKeys, AUsed, AID);
  if LPos < 0 then Exit(nil);
  Result := AVals[LPos];
end;

procedure WindowHashRebuildU32(const AToken: TWindowFamilyToken; var AKeys: array of UInt32; var AVals: array of Pointer; var AUsed: array of Boolean; const AIDs: array of UInt32; const AList: array of Pointer; ACount: Integer);
var I, LCap, LMask, LValid: Integer;
  LBktCnt, LBktPos, LBktCur: array of Integer;
  LSortedID: array of UInt32;
  LSortedPtr: array of Pointer;
  LArena: THashRebuildArena;
  LFromPool: Boolean;
begin
  RequireWindowFamilyToken(AToken);
  if Length(AKeys) = 0 then Exit;
  specialize GenClearRaw<UInt32, Pointer>(AKeys, AVals, AUsed);
  if ACount <= 0 then Exit;
  LCap := Length(AKeys);
  LMask := LCap - 1;
  if ACount > 1024 then
  begin
    LValid := 0;
    for I := 0 to ACount - 1 do if AIDs[I] <> 0 then Inc(LValid);
    if LValid = 0 then Exit;
    LArena := HashRebuildArenaAcquire(LFromPool);
    try
      LArena.EnsureForU32(LCap, LValid);
      LBktCnt := LArena.BktCnt;
      LBktPos := LArena.BktPos;
      LBktCur := LArena.BktCur;
      LSortedID := LArena.SortedID;
      LSortedPtr := LArena.SortedU32Ptr;
      specialize GenBktCountingSort<UInt32, Pointer>(AToken, AIDs, AList, ACount, LCap, LMask, LBktCnt, LBktPos, LBktCur, LSortedID, LSortedPtr);
      for I := 0 to LValid - 1 do
        specialize GenInsertUnchecked<UInt32, Pointer>(AToken, AKeys, AVals, AUsed, LSortedID[I], LSortedPtr[I]);
      LBktCnt := nil; LBktPos := nil; LBktCur := nil; LSortedID := nil; LSortedPtr := nil;
    finally
      HashRebuildArenaRecycle(LArena);
    end;
  end else
  begin
    for I := 0 to ACount - 1 do
      if AIDs[I] <> 0 then
        specialize GenInsertUnchecked<UInt32, Pointer>(AToken, AKeys, AVals, AUsed, AIDs[I], AList[I]);
  end;
end;

procedure WindowHashEnsureCapacityU32(const AToken: TWindowFamilyToken; var AHash: TWindowU32Hash; ANewCap: Integer; const AIDs: array of UInt32; const AList: array of Pointer; ACount: Integer);
var LCap: Integer;
begin
  RequireWindowFamilyToken(AToken);
  if ANewCap <= Length(AHash.FKeys) then Exit;
  LCap := WindowHashAlignCapacity(AToken, ANewCap);
  SetLength(AHash.FKeys, LCap);
  SetLength(AHash.FVals, LCap);
  SetLength(AHash.FUsed, LCap);
  WindowHashRebuildU32(AToken, AHash.FKeys, AHash.FVals, AHash.FUsed, AIDs, AList, ACount);
end;

end.
