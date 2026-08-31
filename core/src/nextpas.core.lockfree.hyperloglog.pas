{******************************************************************************
  nextpas.core.lockfree.hyperloglog

  Concurrent HyperLogLog — probabilistic cardinality estimator.

  Design:
  - Uses 2^p registers (buckets)
  - Hash each element, use first p bits as bucket index
  - Count leading zeros in remaining bits
  - Store max leading zeros per bucket
  - Harmonic mean for estimation
  - CAS for concurrent max updates

  Properties:
  - Standard error: 1.04 / sqrt(2^p)
  - Memory: 2^p bytes (typically 1-16 KB)
  - Approximate result may be above or below the exact cardinality

  Use cases: unique count estimation, cardinality estimation.

  2026-07-06  Phase 3
******************************************************************************}
{$mode ObjFPC}{$H+}{$J-}
unit nextpas.core.lockfree.hyperloglog;

interface

uses
  nextpas.core.errors;

type
  THyperLogLog = class
  private
    FRegisters: array of Int32;
    FP: Int32;          { precision: 2^p registers }
    FM: Int32;          { number of registers = 2^p }
    FAlpha: Double;     { bias correction factor }

    function CountLeadingZeros(AHash: UInt32; ABitWidth: Int32): Int32;
    function GetRawEstimate: Double;
  public
    constructor Create(APrecision: Int32 = 14);
    destructor Destroy; override;

    procedure Add(const AKey: AnsiString);
    function Estimate: Int64;
    procedure Reset;
    function Merge(AOther: THyperLogLog): Boolean;
    function RegisterCount: Int32; inline;
  end;

implementation

uses
  nextpas.core.atomic,
  nextpas.core.checksum;

function Fnv1aHash(const AData: Pointer; ALength: Int32): UInt32;
begin
  if ALength <= 0 then
    Result := FNV1A32_OFFSET
  else
    Result := Fnv1a32Update(FNV1A32_OFFSET, AData, SizeUInt(ALength));
end;

constructor THyperLogLog.Create(APrecision: Int32);
var
  I: Int32;
begin
  inherited Create;
  if APrecision < 4 then APrecision := 4;
  if APrecision > 16 then APrecision := 16;
  FP := APrecision;
  FM := 1 shl FP;
  SetLength(FRegisters, FM);
  for I := 0 to FM - 1 do
    FRegisters[I] := 0;

  { Bias correction factor }
  case FP of
    4: FAlpha := 0.673;
    5: FAlpha := 0.697;
    6: FAlpha := 0.709;
  else
    FAlpha := 0.7213 / (1.0 + 1.079 / FM);
  end;
end;

destructor THyperLogLog.Destroy;
begin
  SetLength(FRegisters, 0);
  inherited Destroy;
end;

function THyperLogLog.CountLeadingZeros(AHash: UInt32; ABitWidth: Int32): Int32;
var
  I: Int32;
begin
  if ABitWidth <= 0 then
    Exit(1);
  Result := 1;
  for I := ABitWidth - 1 downto 0 do
  begin
    if ((AHash shr I) and 1) = 0 then
      Inc(Result)
    else
      Break;
  end;
end;

procedure THyperLogLog.Add(const AKey: AnsiString);
var
  LHash: UInt32;
  LIdx, LZeros, LOld, LNew: Int32;
begin
  if Length(AKey) = 0 then
    LHash := Fnv1aHash(nil, 0)
  else
    LHash := Fnv1aHash(@AKey[1], Length(AKey));
  LIdx := Int32(LHash and (UInt32(FM) - 1));
  LZeros := CountLeadingZeros(LHash shr FP, 32 - FP);

  repeat
    LOld := atomic_load(FRegisters[LIdx], mo_acquire);
    if LZeros <= LOld then
      Break;
    LNew := LZeros;
  until atomic_compare_exchange_strong(FRegisters[LIdx], LOld, LNew, mo_acq_rel, mo_acquire);
end;

function THyperLogLog.GetRawEstimate: Double;
var
  I: Int32;
  LSum: Double;
begin
  LSum := 0;
  for I := 0 to FM - 1 do
    LSum := LSum + 1.0 / (1 shl atomic_load(FRegisters[I], mo_acquire));
  Result := FAlpha * FM * FM / LSum;
end;

function THyperLogLog.Estimate: Int64;
var
  LEstimate: Double;
  LV: Int32;
  I: Int32;
begin
  LEstimate := GetRawEstimate;

  { Small range correction }
  if LEstimate <= 2.5 * FM then
  begin
    LV := 0;
    for I := 0 to FM - 1 do
      if atomic_load(FRegisters[I], mo_acquire) = 0 then
        Inc(LV);
    if LV > 0 then
      LEstimate := FM * Ln(Double(FM) / Double(LV));
  end;

  { Large range correction }
  if LEstimate > (1 shl 32) / 30.0 then
    LEstimate := -(1 shl 32) * Ln(1.0 - LEstimate / (1 shl 32));

  Result := Round(LEstimate);
end;

procedure THyperLogLog.Reset;
var
  I: Int32;
begin
  for I := 0 to FM - 1 do
    atomic_store(FRegisters[I], 0, mo_relaxed);
end;

function THyperLogLog.Merge(AOther: THyperLogLog): Boolean;
var
  I: Int32;
  LOtherVal, LOld: Int32;
begin
  Result := False;
  if (AOther = nil) or (AOther.FP <> FP) then
    Exit;
  for I := 0 to FM - 1 do
  begin
    LOtherVal := atomic_load(AOther.FRegisters[I], mo_acquire);
    repeat
      LOld := atomic_load(FRegisters[I], mo_acquire);
      if LOtherVal <= LOld then
        Break;
    until atomic_compare_exchange_strong(FRegisters[I], LOld, LOtherVal, mo_acq_rel, mo_acquire);
  end;
  Result := True;
end;

function THyperLogLog.RegisterCount: Int32; inline;
begin
  Result := FM;
end;

end.
