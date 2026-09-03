unit nextpas.core.collections.concurrent.hashmap;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.reflect.base,
  nextpas.core.reflect,
  nextpas.core.base,
  nextpas.core.sync.rwlock,
  nextpas.core.sync.intf,
  nextpas.core.collections.hashmap,
  nextpas.core.collections.hashmap.swiss,
  nextpas.core.collections.concurrent.map.intf;

const
  CONCURRENT_SEGMENT_COUNT = 16;
  CONCURRENT_SEGMENT_MASK = CONCURRENT_SEGMENT_COUNT - 1;

type
  generic TConcurrentHashMap<K, V> = class(TInterfacedObject, specialize IConcurrentMap<K, V>)
  public type
    THashFunc = function(const AKey: K): UInt32;
    TEqualsFunc = function(const A, B: K): Boolean;
    TComputeFunc = function(const AKey: K; var AValue: V; AExists: Boolean): Boolean;
    {** 带上下文指针的原子读-改-写回调：AContext 透传（普通过程变量无法
        捕获局部变量，与 ForEachCtx 同构；供累加/扣减等需要传增量的场景）。 }
    TComputeCtxFunc = function(const AKey: K; var AValue: V; AExists: Boolean;
      AContext: Pointer): Boolean;
    TForEachFunc = procedure(const AKey: K; const AValue: V);
    TForEachCtxFunc = procedure(const AKey: K; const AValue: V; AContext: Pointer);
    TForEachCtxExFunc = function(const AKey: K; const AValue: V; AContext: Pointer): Boolean;
    TKeyArray = array of K;
  private type
    TSegmentTable = specialize TSwissTable<K, V>;
  private
    FSegmentLocks: array[0..CONCURRENT_SEGMENT_COUNT - 1] of IRWLock;
    FSegments: array[0..CONCURRENT_SEGMENT_COUNT - 1] of TSegmentTable;
    FHash: THashFunc;
    FEquals: TEqualsFunc;

    function SegmentIndex(const AKey: K): SizeUInt;
  public
    constructor Create(AHash: THashFunc = nil; AEquals: TEqualsFunc = nil;
      AInitialCapacityPerSegment: SizeUInt = 0);
    destructor Destroy; override;

    function TryGetValue(const AKey: K; out AValue: V): Boolean;
    function ContainsKey(const AKey: K): Boolean;
    procedure Put(const AKey: K; const AValue: V);
    function PutIfAbsent(const AKey: K; const AValue: V): Boolean;
    function Remove(const AKey: K): Boolean;
    function Replace(const AKey: K; const ANewValue: V): Boolean;
    function GetOrInsert(const AKey: K; const ADefault: V): V;
    procedure Compute(const AKey: K; AFunc: TComputeFunc);
    procedure ComputeCtx(const AKey: K; AFunc: TComputeCtxFunc; AContext: Pointer);
    procedure ForEach(AFunc: TForEachFunc);
    {** @desc 遍历所有元素（带上下文指针，回调可捕获外部状态） }
    procedure ForEachCtx(AFunc: TForEachCtxFunc; AContext: Pointer);
    {** @desc 遍历所有元素并支持早停：回调返回 False 即停止遍历（采样/限量场景） }
    procedure ForEachCtxEx(AFunc: TForEachCtxExFunc; AContext: Pointer);
    // Deprecated: Keys() does not provide a consistent snapshot under concurrent
    // modification. Use ForEach() instead for safe iteration.
    function Keys: TKeyArray;
    function IsEmpty: Boolean;
    procedure Clear;

    function GetCount: SizeUInt;
    property Count: SizeUInt read GetCount;
  end;

implementation

{ TConcurrentHashMap }

function TConcurrentHashMap.SegmentIndex(const AKey: K): SizeUInt;
var LHash: UInt32; LKind: TNPTypeKind;
begin
  if Assigned(FHash) then
    LHash := FHash(AKey)
  else
  begin
    LKind := NPTypeKindOf(TNPTypeHandle(TypeInfo(K)));
    if (LKind = nkInteger) and (SizeOf(K) = 4) then
      LHash := InlineHashMix32(PUInt32(@AKey)^)
    else if (LKind = nkInteger) and (SizeOf(K) = 8) then
      LHash := InlineHashMix32(UInt32(PQWord(@AKey)^ xor (PQWord(@AKey)^ shr 32)))
    else if (LKind = nkString) and (GetTypeKind(K) = GetTypeKind(AnsiString)) then
      LHash := HashOfAnsiString(PAnsiString(@AKey)^)
    else if (LKind = nkString) and ((GetTypeKind(K) = GetTypeKind(UnicodeString)) or (GetTypeKind(K) = GetTypeKind(WideString))) then
      LHash := HashOfUnicodeString(PUnicodeString(@AKey)^)
    else
    begin
      case SizeOf(K) of
        1: LHash := InlineHashMix32(UInt32(PByte(@AKey)^));
        2: LHash := InlineHashMix32(UInt32(PWord(@AKey)^));
        4: LHash := InlineHashMix32(PUInt32(@AKey)^);
        8: LHash := InlineHashMix32(UInt32(PQWord(@AKey)^ xor (PQWord(@AKey)^ shr 32)));
      else
        LHash := InlineHashMix32(PUInt32(@AKey)^);
      end;
    end;
  end;
  Result := (LHash shr 28) and CONCURRENT_SEGMENT_MASK;
end;

constructor TConcurrentHashMap.Create(AHash: THashFunc; AEquals: TEqualsFunc;
  AInitialCapacityPerSegment: SizeUInt);
var i: Integer; LKind: TNPTypeKind;
begin
  inherited Create;

  // Non-ordinal/non-string key types require a custom hash function
  LKind := NPTypeKindOf(TNPTypeHandle(TypeInfo(K)));
  if not Assigned(AHash) then
    if not ((LKind = nkInteger) or (LKind = nkChar) or
            (LKind = nkEnumeration) or (LKind = nkInt64) or
            (LKind = nkQWord) or (LKind = nkString)) then
      raise EInvalidArgument.Create(
        'TConcurrentHashMap.Create: AHash must not be nil for non-ordinal/non-string key types');

  FHash := AHash;
  FEquals := AEquals;
  for i := 0 to CONCURRENT_SEGMENT_COUNT - 1 do
  begin
    FSegmentLocks[i] := TRWLock.Create;
    FSegments[i] := TSegmentTable.Create(AInitialCapacityPerSegment, AHash, AEquals);
  end;
end;

destructor TConcurrentHashMap.Destroy;
var i: Integer;
begin
  for i := 0 to CONCURRENT_SEGMENT_COUNT - 1 do
  begin
    FSegments[i].Free;
    FSegmentLocks[i] := nil;
  end;
  inherited Destroy;
end;

function TConcurrentHashMap.TryGetValue(const AKey: K; out AValue: V): Boolean;
var LSeg: SizeUInt;
begin
  LSeg := SegmentIndex(AKey);
  FSegmentLocks[LSeg].AcquireRead;
  try
    Result := FSegments[LSeg].TryGetValue(AKey, AValue);
  finally
    FSegmentLocks[LSeg].ReleaseRead;
  end;
end;

function TConcurrentHashMap.ContainsKey(const AKey: K): Boolean;
var LSeg: SizeUInt;
begin
  LSeg := SegmentIndex(AKey);
  FSegmentLocks[LSeg].AcquireRead;
  try
    Result := FSegments[LSeg].ContainsKey(AKey);
  finally
    FSegmentLocks[LSeg].ReleaseRead;
  end;
end;

procedure TConcurrentHashMap.Put(const AKey: K; const AValue: V);
var LSeg: SizeUInt;
begin
  LSeg := SegmentIndex(AKey);
  FSegmentLocks[LSeg].AcquireWrite;
  try
    FSegments[LSeg].Put(AKey, AValue);
  finally
    FSegmentLocks[LSeg].ReleaseWrite;
  end;
end;

function TConcurrentHashMap.PutIfAbsent(const AKey: K; const AValue: V): Boolean;
var LSeg: SizeUInt;
begin
  LSeg := SegmentIndex(AKey);
  FSegmentLocks[LSeg].AcquireWrite;
  try
    if FSegments[LSeg].ContainsKey(AKey) then
      Result := False
    else
    begin
      FSegments[LSeg].Put(AKey, AValue);
      Result := True;
    end;
  finally
    FSegmentLocks[LSeg].ReleaseWrite;
  end;
end;

function TConcurrentHashMap.Remove(const AKey: K): Boolean;
var LSeg: SizeUInt;
begin
  LSeg := SegmentIndex(AKey);
  FSegmentLocks[LSeg].AcquireWrite;
  try
    Result := FSegments[LSeg].Remove(AKey);
  finally
    FSegmentLocks[LSeg].ReleaseWrite;
  end;
end;

function TConcurrentHashMap.Replace(const AKey: K; const ANewValue: V): Boolean;
var LSeg: SizeUInt; LDummy: V;
begin
  LSeg := SegmentIndex(AKey);
  FSegmentLocks[LSeg].AcquireWrite;
  try
    if FSegments[LSeg].TryGetValue(AKey, LDummy) then
    begin
      FSegments[LSeg].Put(AKey, ANewValue);
      Result := True;
    end
    else
      Result := False;
  finally
    FSegmentLocks[LSeg].ReleaseWrite;
  end;
end;

function TConcurrentHashMap.GetOrInsert(const AKey: K; const ADefault: V): V;
var LSeg: SizeUInt;
begin
  LSeg := SegmentIndex(AKey);
  FSegmentLocks[LSeg].AcquireWrite;
  try
    if not FSegments[LSeg].TryGetValue(AKey, Result) then
    begin
      FSegments[LSeg].Put(AKey, ADefault);
      Result := ADefault;
    end;
  finally
    FSegmentLocks[LSeg].ReleaseWrite;
  end;
end;

function TConcurrentHashMap.IsEmpty: Boolean;
begin
  Result := GetCount = 0;
end;

procedure TConcurrentHashMap.Clear;
var i: Integer;
begin
  for i := 0 to CONCURRENT_SEGMENT_COUNT - 1 do
  begin
    FSegmentLocks[i].AcquireWrite;
    try
      FSegments[i].Clear;
    finally
      FSegmentLocks[i].ReleaseWrite;
    end;
  end;
end;

procedure TConcurrentHashMap.Compute(const AKey: K; AFunc: TComputeFunc);
var
  LSeg: SizeUInt;
  LValue: V;
  LExists, LKeep: Boolean;
begin
  LSeg := SegmentIndex(AKey);
  FSegmentLocks[LSeg].AcquireWrite;
  try
    LExists := FSegments[LSeg].TryGetValue(AKey, LValue);
    if not LExists then
      LValue := Default(V);
    LKeep := AFunc(AKey, LValue, LExists);
    if LKeep then
      FSegments[LSeg].Put(AKey, LValue)
    else if LExists then
      FSegments[LSeg].Remove(AKey);
  finally
    FSegmentLocks[LSeg].ReleaseWrite;
  end;
end;

procedure TConcurrentHashMap.ComputeCtx(const AKey: K; AFunc: TComputeCtxFunc;
  AContext: Pointer);
var
  LSeg: SizeUInt;
  LValue: V;
  LExists, LKeep: Boolean;
begin
  LSeg := SegmentIndex(AKey);
  FSegmentLocks[LSeg].AcquireWrite;
  try
    LExists := FSegments[LSeg].TryGetValue(AKey, LValue);
    if not LExists then
      LValue := Default(V);
    LKeep := AFunc(AKey, LValue, LExists, AContext);
    if LKeep then
      FSegments[LSeg].Put(AKey, LValue)
    else if LExists then
      FSegments[LSeg].Remove(AKey);
  finally
    FSegmentLocks[LSeg].ReleaseWrite;
  end;
end;

procedure TConcurrentHashMap.ForEach(AFunc: TForEachFunc);
var i: Integer;
begin
  for i := 0 to CONCURRENT_SEGMENT_COUNT - 1 do
  begin
    FSegmentLocks[i].AcquireRead;
    try
      FSegments[i].ForEach(TSegmentTable.TVisitFunc(AFunc));
    finally
      FSegmentLocks[i].ReleaseRead;
    end;
  end;
end;

procedure TConcurrentHashMap.ForEachCtx(AFunc: TForEachCtxFunc; AContext: Pointer);
var i: Integer;
begin
  for i := 0 to CONCURRENT_SEGMENT_COUNT - 1 do
  begin
    FSegmentLocks[i].AcquireRead;
    try
      FSegments[i].ForEachCtx(TSegmentTable.TVisitCtxFunc(AFunc), AContext);
    finally
      FSegmentLocks[i].ReleaseRead;
    end;
  end;
end;

procedure TConcurrentHashMap.ForEachCtxEx(AFunc: TForEachCtxExFunc; AContext: Pointer);
var
  i: Integer;
  LSeg: TSegmentTable;
  j: SizeUInt;
  LContinue: Boolean;
begin
  for i := 0 to CONCURRENT_SEGMENT_COUNT - 1 do
  begin
    FSegmentLocks[i].AcquireRead;
    try
      LSeg := FSegments[i];
      if LSeg.Capacity = 0 then
        Continue;
      for j := 0 to LSeg.Capacity - 1 do
        if LSeg.GetCtrlByte(j) < $80 then
        begin
          LContinue := AFunc(LSeg.GetSlotKey(j), LSeg.GetSlotValue(j), AContext);
          if not LContinue then
            Exit;
        end;
    finally
      FSegmentLocks[i].ReleaseRead;
    end;
  end;
end;

function TConcurrentHashMap.Keys: TKeyArray;
var
  i: Integer;
  LTotal, LIdx, j, LSegCount: SizeUInt;
  LSeg: TSegmentTable;
begin
  LTotal := GetCount;
  Result := nil;
  SetLength(Result, LTotal);
  LIdx := 0;
  for i := 0 to CONCURRENT_SEGMENT_COUNT - 1 do
  begin
    FSegmentLocks[i].AcquireRead;
    try
      LSeg := FSegments[i];
      LSegCount := LSeg.GetCount;
      if (LSegCount > 0) and (LSeg.Capacity > 0) then
        for j := 0 to LSeg.Capacity - 1 do
          if (LIdx < LTotal) and (LSeg.GetCtrlByte(j) < $80) then
          begin
            Result[LIdx] := LSeg.GetSlotKey(j);
            Inc(LIdx);
          end;
    finally
      FSegmentLocks[i].ReleaseRead;
    end;
  end;
  SetLength(Result, LIdx);
end;

function TConcurrentHashMap.GetCount: SizeUInt;
var i: Integer;
begin
  Result := 0;
  for i := 0 to CONCURRENT_SEGMENT_COUNT - 1 do
  begin
    FSegmentLocks[i].AcquireRead;
    try
      Result := Result + FSegments[i].GetCount;
    finally
      FSegmentLocks[i].ReleaseRead;
    end;
  end;
end;

end.
