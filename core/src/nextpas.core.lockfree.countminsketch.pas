{******************************************************************************
  nextpas.core.lockfree.countminsketch

  Concurrent Count-Min Sketch — probabilistic frequency estimator.

  Design:
  - 2D array of counters: [depth][width]
  - Multiple hash functions for each row
  - CAS increments for concurrent updates
  - Estimate returns minimum across rows (conservative)
  - Reset clears all counters

  Properties:
  - No false negatives
  - Overestimates, never underestimates
  - Memory: O(depth * width * 4 bytes)

  Use cases: network traffic analysis, frequency estimation, rate limiting.

  2026-07-06  Phase 3
******************************************************************************}
{$mode ObjFPC}{$H+}{$J-}
unit nextpas.core.lockfree.countminsketch;

interface

uses
  SysUtils;

type
  TCountMinSketch = class
  private
    FCounters: array of array of Int32;
    FDepth: Int32;
    FWidth: Int32;
    FSeeds: array of UInt32;

    function Hash(AIndex: Int32; const AKey: AnsiString): UInt32;
  public
    constructor Create(ADepth, AWidth: Int32);
    destructor Destroy; override;

    procedure Add(const AKey: AnsiString; ACount: Int32 = 1);
    function Estimate(const AKey: AnsiString): Int64;
    procedure Reset;
    function Depth: Int32;
    function Width: Int32;
  end;

implementation

uses
  nextpas.core.atomic,
  nextpas.core.errors;

function Fnv1aHash(const AData: Pointer; ALength: Int32; ASeed: UInt32): UInt32;
const
  FNV_PRIME = 16777619;
var
  I: Int32;
  LByte: PByte;
begin
  Result := ASeed;
  LByte := PByte(AData);
  for I := 0 to ALength - 1 do
  begin
    Result := Result xor LByte^;
    Result := Result * FNV_PRIME;
    Inc(LByte);
  end;
end;

constructor TCountMinSketch.Create(ADepth, AWidth: Int32);
var
  I, J: Int32;
begin
  inherited Create;
  if ADepth < 1 then
    raise EArgumentError.Create('TCountMinSketch: depth must be > 0');
  if AWidth < 1 then
    raise EArgumentError.Create('TCountMinSketch: width must be > 0');
  FDepth := ADepth;
  FWidth := AWidth;
  SetLength(FCounters, FDepth, FWidth);
  SetLength(FSeeds, FDepth);
  for I := 0 to FDepth - 1 do
  begin
    FSeeds[I] := UInt32(I * 2654435761); { Knuth multiplicative hash }
    for J := 0 to FWidth - 1 do
      FCounters[I, J] := 0;
  end;
end;

destructor TCountMinSketch.Destroy;
begin
  SetLength(FCounters, 0, 0);
  SetLength(FSeeds, 0);
  inherited Destroy;
end;

function TCountMinSketch.Hash(AIndex: Int32; const AKey: AnsiString): UInt32;
begin
  if Length(AKey) = 0 then
    Result := FSeeds[AIndex]
  else
    Result := Fnv1aHash(@AKey[1], Length(AKey), FSeeds[AIndex]);
end;

procedure TCountMinSketch.Add(const AKey: AnsiString; ACount: Int32);
var
  I, LIdx: Int32;
begin
  if ACount <= 0 then
    Exit;
  for I := 0 to FDepth - 1 do
  begin
    LIdx := Hash(I, AKey) mod UInt32(FWidth);
    AtomicFetchAdd32(FCounters[I, LIdx], ACount);
  end;
end;

function TCountMinSketch.Estimate(const AKey: AnsiString): Int64;
var
  I, LIdx: Int32;
  LMin, LVal: Int32;
begin
  LMin := AtomicLoad32(FCounters[0, Hash(0, AKey) mod UInt32(FWidth)], moAcquire);
  for I := 1 to FDepth - 1 do
  begin
    LIdx := Hash(I, AKey) mod UInt32(FWidth);
    LVal := AtomicLoad32(FCounters[I, LIdx], moAcquire);
    if LVal < LMin then
      LMin := LVal;
  end;
  Result := LMin;
end;

procedure TCountMinSketch.Reset;
var
  I, J: Int32;
begin
  for I := 0 to FDepth - 1 do
    for J := 0 to FWidth - 1 do
      AtomicStore32(FCounters[I, J], 0, moRelaxed);
end;

function TCountMinSketch.Depth: Int32;
begin
  Result := FDepth;
end;

function TCountMinSketch.Width: Int32;
begin
  Result := FWidth;
end;

end.
