unit nextpas.core.collections.smallcache;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.ops;

const
  SmallCacheSets = 64;
  SmallCacheWays = 4;
  SmallCacheMask = SmallCacheSets - 1;
  SmallCacheTotal = SmallCacheSets * SmallCacheWays;

{ Fixed 4-way set-assoc micro-cache, zero-alloc, inline. }
type
  generic TSmallCache<K, V> = record
  private
    FKeys: array[0..SmallCacheTotal - 1] of K;
    FVals: array[0..SmallCacheTotal - 1] of V;
    FValid: array[0..SmallCacheTotal - 1] of Boolean;
    FNext: array[0..SmallCacheSets - 1] of Byte;
    function SetIndex(const AKey: K): SizeUInt; inline;
  public
    procedure Init; inline;
    function TryGet(const AKey: K; out AValue: V): Boolean; inline;
    procedure Put(const AKey: K; const AValue: V); inline;
  end;

  { Hot peek cache: SizeUInt -> Int64, direct xor-mix, no FNV. }
  TPeekSmallCache = record
  private
    FKeys: array[0..SmallCacheTotal - 1] of SizeUInt;
    FVals: array[0..SmallCacheTotal - 1] of Int64;
    FValid: array[0..SmallCacheTotal - 1] of Boolean;
    FNext: array[0..SmallCacheSets - 1] of Byte;
    function SetIndex(const AKey: SizeUInt): SizeUInt; inline;
  public
    procedure Init; inline;
    function TryGet(const AKey: SizeUInt; out AValue: Int64): Boolean; inline;
    procedure Put(const AKey: SizeUInt; const AValue: Int64); inline;
  end;

implementation

generic function TSmallCache<K, V>.SetIndex(const AKey: K): SizeUInt; inline;
var
  LHash: UInt32;
begin
  LHash := SpanHashFNV1a(TByteSpan.Create(PByte(@AKey), SizeOf(K)));
  Result := (SizeUInt(LHash) xor (SizeUInt(LHash) shr 6) xor (SizeUInt(LHash) shr 10)) and SmallCacheMask;
end;

generic procedure TSmallCache<K, V>.Init; inline;
begin
  SpanFill(TByteSpan.Create(PByte(@FValid[0]), SizeOf(FValid)), 0);
  SpanFill(TByteSpan.Create(PByte(@FNext[0]), SizeOf(FNext)), 0);
end;

generic function TSmallCache<K, V>.TryGet(const AKey: K; out AValue: V): Boolean; inline;
var
  S, B, I: SizeUInt;
begin
  S := SetIndex(AKey);
  B := S * SmallCacheWays;
  for I := 0 to SmallCacheWays - 1 do
    if FValid[B + I] and (FKeys[B + I] = AKey) then
    begin
      AValue := FVals[B + I];
      Exit(True);
    end;
  Result := False;
end;

generic procedure TSmallCache<K, V>.Put(const AKey: K; const AValue: V); inline;
var
  S, B, I, Victim: SizeUInt;
begin
  S := SetIndex(AKey);
  B := S * SmallCacheWays;
  for I := 0 to SmallCacheWays - 1 do
    if FValid[B + I] and (FKeys[B + I] = AKey) then
    begin
      FVals[B + I] := AValue;
      Exit;
    end;
  Victim := B + FNext[S];
  FKeys[Victim] := AKey;
  FVals[Victim] := AValue;
  FValid[Victim] := True;
  FNext[S] := (FNext[S] + 1) and (SmallCacheWays - 1);
end;

function TPeekSmallCache.SetIndex(const AKey: SizeUInt): SizeUInt; inline;
begin
  Result := (AKey xor (AKey shr 6) xor (AKey shr 10)) and SmallCacheMask;
end;

procedure TPeekSmallCache.Init; inline;
begin
  SpanFill(TByteSpan.Create(PByte(@FValid[0]), SizeOf(FValid)), 0);
  SpanFill(TByteSpan.Create(PByte(@FNext[0]), SizeOf(FNext)), 0);
end;

function TPeekSmallCache.TryGet(const AKey: SizeUInt; out AValue: Int64): Boolean; inline;
var
  S, B, I: SizeUInt;
begin
  S := SetIndex(AKey);
  B := S * SmallCacheWays;
  for I := 0 to SmallCacheWays - 1 do
    if FValid[B + I] and (FKeys[B + I] = AKey) then
    begin
      AValue := FVals[B + I];
      Exit(True);
    end;
  Result := False;
end;

procedure TPeekSmallCache.Put(const AKey: SizeUInt; const AValue: Int64); inline;
var
  S, B, I, Victim: SizeUInt;
begin
  S := SetIndex(AKey);
  B := S * SmallCacheWays;
  for I := 0 to SmallCacheWays - 1 do
    if FValid[B + I] and (FKeys[B + I] = AKey) then
    begin
      FVals[B + I] := AValue;
      Exit;
    end;
  Victim := B + FNext[S];
  FKeys[Victim] := AKey;
  FVals[Victim] := AValue;
  FValid[Victim] := True;
  FNext[S] := (FNext[S] + 1) and (SmallCacheWays - 1);
end;

end.
