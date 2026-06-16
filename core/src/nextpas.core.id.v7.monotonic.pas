unit nextpas.core.id.v7.monotonic;
{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.id.uuid;

type
  TUuidV7Generator = record
  private
    FLastMs: UInt64;
    FRandA: UInt16;
  public
    procedure Init;
    function Next: TUuid;
    function NextString: string;
  end;

var
  GlobalV7Gen: TUuidV7Generator;

function UuidV7Monotonic: string;
function UuidV7MonotonicRaw: TUuid;

implementation

uses
  nextpas.core.atomic,
  nextpas.core.base,
  nextpas.core.id.rng,
  nextpas.core.platform.time;

const
  UUID_V7_MAX_TIMESTAMP_MS = UInt64($FFFFFFFFFFFF);

procedure TUuidV7Generator.Init;
begin
  FLastMs := 0;
  FRandA := 0;
end;

function TUuidV7Generator.Next: TUuid;
var
  LMs: UInt64;
  LRandA: UInt16;
  LRandB: array[0..7] of Byte;
begin
  LMs := platform_realtime_ns div 1000000;
  if LMs > UUID_V7_MAX_TIMESTAMP_MS then
    raise EOutOfRange.Create('TUuidV7Generator.Next: timestamp must fit 48 bits');

  if LMs < FLastMs then
    LMs := FLastMs;
  if LMs = FLastMs then
  begin
    LRandA := FRandA + 1;
    if LRandA > $0FFF then
    begin
      if LMs >= UUID_V7_MAX_TIMESTAMP_MS then
        raise EOutOfRange.Create('TUuidV7Generator.Next: logical timestamp exceeds 48 bits');
      Inc(LMs);
      IdRngFillBytes(@LRandA, 2);
      LRandA := LRandA and $0FFF;
    end;
  end
  else
  begin
    IdRngFillBytes(@LRandA, 2);
    LRandA := LRandA and $0FFF;
  end;
  IdRngFillBytes(@LRandB[0], Length(LRandB));
  FLastMs := LMs;
  FRandA := LRandA;

  Result.FBytes[0] := Byte(LMs shr 40);
  Result.FBytes[1] := Byte(LMs shr 32);
  Result.FBytes[2] := Byte(LMs shr 24);
  Result.FBytes[3] := Byte(LMs shr 16);
  Result.FBytes[4] := Byte(LMs shr 8);
  Result.FBytes[5] := Byte(LMs);
  Result.FBytes[6] := $70 or Byte(LRandA shr 8);
  Result.FBytes[7] := Byte(LRandA);
  Move(LRandB[0], Result.FBytes[8], Length(LRandB));
  Result.FBytes[8] := (Result.FBytes[8] and $3F) or $80;
end;

function TUuidV7Generator.NextString: string;
begin
  Result := Next.ToString;
end;

var
  GV7Lock: Int32 = 0;

function UuidV7Monotonic: string;
begin
  while AtomicCompareExchange32(GV7Lock, 0, 1) <> 0 do
    CpuPause;
  try
    Result := GlobalV7Gen.NextString;
  finally
    AtomicStore32(GV7Lock, 0, moRelease);
  end;
end;

function UuidV7MonotonicRaw: TUuid;
begin
  while AtomicCompareExchange32(GV7Lock, 0, 1) <> 0 do
    CpuPause;
  try
    Result := GlobalV7Gen.Next;
  finally
    AtomicStore32(GV7Lock, 0, moRelease);
  end;
end;

initialization
  GlobalV7Gen.Init;

end.
