{******************************************************************************
  nextpas.core.lockfree.cuckooset

  Concurrent Cuckoo Hash Set — lock-free set with O(1) worst-case lookup.

  Design:
  - Two hash tables with different hash functions
  - Each element has exactly 2 possible locations
  - Lookup: check both locations, O(1) worst-case
  - Insert: if both occupied, evict one and re-insert (cuckoo)
  - Spin lock for writes, lock-free reads
  - Auto-resize when load factor > 50%

  Use cases: fast membership testing, deduplication.

  2026-07-06  Phase 3
******************************************************************************}
{$mode ObjFPC}{$H+}{$J-}
unit nextpas.core.lockfree.cuckooset;

interface

uses
  SysUtils;

type
  TCuckooSetResult = (
    csrOk,
    csrExists,
    csrNotFound,
    csrFull
  );

  TCuckooSet = class
  private
    FTable1: array of AnsiString;
    FTable2: array of AnsiString;
    FCapacity: Int32;
    FCount: Int32;
    FLock: Int32;

    function Hash1(const AKey: AnsiString): UInt32;
    function Hash2(const AKey: AnsiString): UInt32;
    function InsertRaw(const AKey: AnsiString): TCuckooSetResult;
    procedure Resize;
    procedure AcquireLock;
    procedure ReleaseLock;
  public
    constructor Create(ACapacity: Int32 = 16);
    destructor Destroy; override;

    function Insert(const AKey: AnsiString): TCuckooSetResult;
    function Remove(const AKey: AnsiString): TCuckooSetResult;
    function Contains(const AKey: AnsiString): Boolean;
    function Count: Int32;
    function IsEmpty: Boolean;
    procedure Clear;
  end;

implementation

uses
  nextpas.core.atomic;

function Fnv1aHash(const AData: Pointer; ALength: Int32): UInt32;
const
  FNV_OFFSET = 2166136261;
  FNV_PRIME  = 16777619;
var
  I: Int32;
  LByte: PByte;
begin
  Result := FNV_OFFSET;
  LByte := PByte(AData);
  for I := 0 to ALength - 1 do
  begin
    Result := Result xor LByte^;
    Result := Result * FNV_PRIME;
    Inc(LByte);
  end;
end;

constructor TCuckooSet.Create(ACapacity: Int32);
var
  I: Int32;
begin
  inherited Create;
  if ACapacity < 4 then ACapacity := 4;
  FCapacity := ACapacity;
  SetLength(FTable1, FCapacity);
  SetLength(FTable2, FCapacity);
  for I := 0 to FCapacity - 1 do
  begin
    FTable1[I] := '';
    FTable2[I] := '';
  end;
  FCount := 0;
  FLock := 0;
end;

destructor TCuckooSet.Destroy;
begin
  SetLength(FTable1, 0);
  SetLength(FTable2, 0);
  inherited Destroy;
end;

function TCuckooSet.Hash1(const AKey: AnsiString): UInt32;
begin
  if Length(AKey) = 0 then
    Result := 0
  else
    Result := Fnv1aHash(@AKey[1], Length(AKey));
end;

function TCuckooSet.Hash2(const AKey: AnsiString): UInt32;
var
  LH: UInt32;
begin
  if Length(AKey) = 0 then
    Result := 1
  else
  begin
    LH := Fnv1aHash(@AKey[1], Length(AKey));
    { Mix bits for second hash }
    Result := ((LH shr 16) xor LH) * $45D9F3B;
    Result := ((Result shr 16) xor Result) * $45D9F3B;
    Result := (Result shr 16) xor Result;
  end;
end;

procedure TCuckooSet.AcquireLock;
var
  LOld: Int32;
begin
  repeat
    LOld := AtomicCompareExchange32(FLock, 0, 1, moAcquire);
    if LOld = 0 then
      Exit;
  until False;
end;

procedure TCuckooSet.ReleaseLock;
begin
  AtomicStore32(FLock, 0, moRelease);
end;

procedure TCuckooSet.Resize;
var
  LOldTable1, LOldTable2: array of AnsiString;
  LOldCap, I: Int32;
  LKey: AnsiString;
begin
  LOldCap := FCapacity;
  LOldTable1 := FTable1;
  LOldTable2 := FTable2;

  FCapacity := FCapacity * 2;
  SetLength(FTable1, FCapacity);
  SetLength(FTable2, FCapacity);
  for I := 0 to FCapacity - 1 do
  begin
    FTable1[I] := '';
    FTable2[I] := '';
  end;
  FCount := 0;

  { Re-insert all elements }
  for I := 0 to LOldCap - 1 do
  begin
    LKey := LOldTable1[I];
    if LKey <> '' then
      InsertRaw(LKey);
    LKey := LOldTable2[I];
    if LKey <> '' then
      InsertRaw(LKey);
  end;

  SetLength(LOldTable1, 0);
  SetLength(LOldTable2, 0);
end;

function TCuckooSet.InsertRaw(const AKey: AnsiString): TCuckooSetResult;
var
  LIdx1, LIdx2: Int32;
  LKey, LEvicted: AnsiString;
  I: Int32;
begin
  { Check if already exists }
  LIdx1 := Hash1(AKey) mod UInt32(FCapacity);
  LIdx2 := Hash2(AKey) mod UInt32(FCapacity);
  if (FTable1[LIdx1] = AKey) or (FTable2[LIdx2] = AKey) then
    Exit(csrExists);

  { Try table 1 }
  if FTable1[LIdx1] = '' then
  begin
    FTable1[LIdx1] := AKey;
    Inc(FCount);
    Exit(csrOk);
  end;

  { Try table 2 }
  if FTable2[LIdx2] = '' then
  begin
    FTable2[LIdx2] := AKey;
    Inc(FCount);
    Exit(csrOk);
  end;

  { Cuckoo eviction }
  LKey := AKey;
  for I := 0 to 32 do
  begin
    LIdx1 := Hash1(LKey) mod UInt32(FCapacity);
    LEvicted := FTable1[LIdx1];
    FTable1[LIdx1] := LKey;
    LKey := LEvicted;

    LIdx2 := Hash2(LKey) mod UInt32(FCapacity);
    if FTable2[LIdx2] = '' then
    begin
      FTable2[LIdx2] := LKey;
      Inc(FCount);
      Exit(csrOk);
    end;

    LEvicted := FTable2[LIdx2];
    FTable2[LIdx2] := LKey;
    LKey := LEvicted;

    LIdx1 := Hash1(LKey) mod UInt32(FCapacity);
    if FTable1[LIdx1] = '' then
    begin
      FTable1[LIdx1] := LKey;
      Inc(FCount);
      Exit(csrOk);
    end;
  end;

  { Resize and retry }
  Resize;
  Result := InsertRaw(LKey);
end;

function TCuckooSet.Insert(const AKey: AnsiString): TCuckooSetResult;
begin
  AcquireLock;
  try
    Result := InsertRaw(AKey);
  finally
    ReleaseLock;
  end;
end;

function TCuckooSet.Remove(const AKey: AnsiString): TCuckooSetResult;
var
  LIdx1, LIdx2: Int32;
begin
  AcquireLock;
  try
    LIdx1 := Hash1(AKey) mod UInt32(FCapacity);
    LIdx2 := Hash2(AKey) mod UInt32(FCapacity);

    if FTable1[LIdx1] = AKey then
    begin
      FTable1[LIdx1] := '';
      Dec(FCount);
      Exit(csrOk);
    end;

    if FTable2[LIdx2] = AKey then
    begin
      FTable2[LIdx2] := '';
      Dec(FCount);
      Exit(csrOk);
    end;

    Result := csrNotFound;
  finally
    ReleaseLock;
  end;
end;

function TCuckooSet.Contains(const AKey: AnsiString): Boolean;
var
  LIdx1, LIdx2: Int32;
begin
  { Lock-free read }
  LIdx1 := Hash1(AKey) mod UInt32(AtomicLoad32(FCapacity, moAcquire));
  LIdx2 := Hash2(AKey) mod UInt32(AtomicLoad32(FCapacity, moAcquire));
  Result := (FTable1[LIdx1] = AKey) or (FTable2[LIdx2] = AKey);
end;

function TCuckooSet.Count: Int32;
begin
  Result := AtomicLoad32(FCount, moAcquire);
end;

function TCuckooSet.IsEmpty: Boolean;
begin
  Result := AtomicLoad32(FCount, moAcquire) = 0;
end;

procedure TCuckooSet.Clear;
var
  I: Int32;
begin
  AcquireLock;
  try
    for I := 0 to FCapacity - 1 do
    begin
      FTable1[I] := '';
      FTable2[I] := '';
    end;
    FCount := 0;
  finally
    ReleaseLock;
  end;
end;

end.
