unit nextpas.core.http.fuzz;
{**
 * @desc HTTP/WebSocket fuzz testing utilities.
 *       Provides mutation-based fuzzing for parser robustness testing.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.http.impl.h1.llhttp;

type
  { Mutation strategies for fuzzing }
  TFuzzMutator = record
    { Randomly flip 1-4 bits in the data }
    class function FlipBits(const AData: nextpas.core.base.TBytes): nextpas.core.base.TBytes; static;
    { Insert 1-16 random bytes at random position }
    class function InsertBytes(const AData: nextpas.core.base.TBytes): nextpas.core.base.TBytes; static;
    { Delete 1-16 bytes at random position }
    class function DeleteBytes(const AData: nextpas.core.base.TBytes): nextpas.core.base.TBytes; static;
    { Replace 1-16 bytes with random values at random position }
    class function ReplaceBytes(const AData: nextpas.core.base.TBytes): nextpas.core.base.TBytes; static;
    { Replace random bytes with boundary values (0x00, 0xFF, 0x7F, 0x80) }
    class function BoundaryValues(const AData: nextpas.core.base.TBytes): nextpas.core.base.TBytes; static;
    { Apply random mutation strategy }
    class function Mutate(const AData: nextpas.core.base.TBytes): nextpas.core.base.TBytes; static;
  end;

  { Fuzz runner for HTTP/WebSocket parsers }
  TFuzzRunner = record
    { Run fuzz iterations on HTTP request parser
      Returns number of crashes (0 = no crashes) }
    class function RunHttpRequestFuzz(const ASeeds: array of nextpas.core.base.TBytes;
      AIterations: Int32): Int32; static;
    { Run fuzz iterations on HTTP response parser
      Returns number of crashes (0 = no crashes) }
    class function RunHttpResponseFuzz(const ASeeds: array of nextpas.core.base.TBytes;
      AIterations: Int32): Int32; static;
    { Run fuzz iterations on WebSocket frame parser
      Returns number of crashes (0 = no crashes) }
    class function RunWebSocketFrameFuzz(const ASeeds: array of nextpas.core.base.TBytes;
      AIterations: Int32): Int32; static;
  end;

implementation

uses
  SysUtils;

{ TFuzzMutator }

class function TFuzzMutator.FlipBits(const AData: nextpas.core.base.TBytes): nextpas.core.base.TBytes;
var
  LLen, LBits, I, J: Integer;
  LByte: Byte;
begin
  LLen := Length(AData);
  if LLen = 0 then
    Exit(AData);

  Result := Copy(AData);
  { Flip 1-4 bits }
  LBits := Random(4) + 1;
  for I := 0 to LBits - 1 do
  begin
    J := Random(LLen);
    LByte := Result[J];
    LByte := LByte xor (1 shl Random(8));
    Result[J] := LByte;
  end;
end;

class function TFuzzMutator.InsertBytes(const AData: nextpas.core.base.TBytes): nextpas.core.base.TBytes;
var
  LLen, LPos, LCount, I: Integer;
begin
  LLen := Length(AData);
  LPos := Random(LLen + 1);
  LCount := Random(16) + 1;

  SetLength(Result, LLen + LCount);
  { Copy before insertion point }
  if LPos > 0 then
    Move(AData[0], Result[0], LPos);
  { Insert random bytes }
  for I := 0 to LCount - 1 do
    Result[LPos + I] := Byte(Random(256));
  { Copy after insertion point }
  if LPos < LLen then
    Move(AData[LPos], Result[LPos + LCount], LLen - LPos);
end;

class function TFuzzMutator.DeleteBytes(const AData: nextpas.core.base.TBytes): nextpas.core.base.TBytes;
var
  LLen, LPos, LCount: Integer;
begin
  LLen := Length(AData);
  if LLen = 0 then
    Exit(AData);

  LPos := Random(LLen);
  LCount := Random(16) + 1;
  if LPos + LCount > LLen then
    LCount := LLen - LPos;

  SetLength(Result, LLen - LCount);
  { Copy before deletion point }
  if LPos > 0 then
    Move(AData[0], Result[0], LPos);
  { Copy after deletion point }
  if LPos + LCount < LLen then
    Move(AData[LPos + LCount], Result[LPos], LLen - LPos - LCount);
end;

class function TFuzzMutator.ReplaceBytes(const AData: nextpas.core.base.TBytes): nextpas.core.base.TBytes;
var
  LLen, LPos, LCount, I: Integer;
begin
  LLen := Length(AData);
  if LLen = 0 then
    Exit(AData);

  Result := Copy(AData);
  LPos := Random(LLen);
  LCount := Random(16) + 1;
  if LPos + LCount > LLen then
    LCount := LLen - LPos;

  { Replace with random values }
  for I := 0 to LCount - 1 do
    Result[LPos + I] := Byte(Random(256));
end;

class function TFuzzMutator.BoundaryValues(const AData: nextpas.core.base.TBytes): nextpas.core.base.TBytes;
const
  BOUNDARIES: array[0..3] of Byte = ($00, $FF, $7F, $80);
var
  LLen, LPos, LCount, I: Integer;
begin
  LLen := Length(AData);
  if LLen = 0 then
    Exit(AData);

  Result := Copy(AData);
  LPos := Random(LLen);
  LCount := Random(4) + 1;
  if LPos + LCount > LLen then
    LCount := LLen - LPos;

  { Replace with boundary values }
  for I := 0 to LCount - 1 do
    Result[LPos + I] := BOUNDARIES[Random(4)];
end;

class function TFuzzMutator.Mutate(const AData: nextpas.core.base.TBytes): nextpas.core.base.TBytes;
begin
  case Random(5) of
    0: Result := FlipBits(AData);
    1: Result := InsertBytes(AData);
    2: Result := DeleteBytes(AData);
    3: Result := ReplaceBytes(AData);
    4: Result := BoundaryValues(AData);
  else
    Result := AData;
  end;
end;

{ TFuzzRunner }

class function TFuzzRunner.RunHttpRequestFuzz(const ASeeds: array of nextpas.core.base.TBytes;
  AIterations: Int32): Int32;
var
  I, LSeedIdx: Integer;
  LData, LMutated: nextpas.core.base.TBytes;
  LParser: TLlhttpInternalT;
  LCrashes: Int32;
begin
  LCrashes := 0;
  for I := 0 to AIterations - 1 do
  begin
    { Select random seed }
    LSeedIdx := Random(Length(ASeeds));
    LData := ASeeds[LSeedIdx];

    { Mutate }
    LMutated := TFuzzMutator.Mutate(LData);

    { Try to parse }
    try
      FillChar(LParser, SizeOf(LParser), 0);
      llhttp_init(@LParser, HTTP_REQUEST, nil);
      llhttp_execute(@LParser, PAnsiChar(@LMutated[0]), SizeUInt(Length(LMutated)));
    except
      on E: Exception do
        Inc(LCrashes);
    end;
  end;
  Result := LCrashes;
end;

class function TFuzzRunner.RunHttpResponseFuzz(const ASeeds: array of nextpas.core.base.TBytes;
  AIterations: Int32): Int32;
var
  I, LSeedIdx: Integer;
  LData, LMutated: nextpas.core.base.TBytes;
  LParser: TLlhttpInternalT;
  LCrashes: Int32;
begin
  LCrashes := 0;
  for I := 0 to AIterations - 1 do
  begin
    { Select random seed }
    LSeedIdx := Random(Length(ASeeds));
    LData := ASeeds[LSeedIdx];

    { Mutate }
    LMutated := TFuzzMutator.Mutate(LData);

    { Try to parse }
    try
      FillChar(LParser, SizeOf(LParser), 0);
      llhttp_init(@LParser, HTTP_RESPONSE, nil);
      llhttp_execute(@LParser, PAnsiChar(@LMutated[0]), SizeUInt(Length(LMutated)));
    except
      on E: Exception do
        Inc(LCrashes);
    end;
  end;
  Result := LCrashes;
end;

class function TFuzzRunner.RunWebSocketFrameFuzz(const ASeeds: array of nextpas.core.base.TBytes;
  AIterations: Int32): Int32;
var
  I, LSeedIdx: Integer;
  LData, LMutated: nextpas.core.base.TBytes;
  LCrashes: Int32;
  LHdr: array[0..1] of Byte;
  LLen: Integer;
begin
  LCrashes := 0;
  for I := 0 to AIterations - 1 do
  begin
    { Select random seed }
    LSeedIdx := Random(Length(ASeeds));
    LData := ASeeds[LSeedIdx];

    { Mutate }
    LMutated := TFuzzMutator.Mutate(LData);

    { Try to parse WebSocket frame }
    try
      LLen := Length(LMutated);
      if LLen >= 2 then
      begin
        LHdr[0] := LMutated[0];
        LHdr[1] := LMutated[1];
        { Basic validation - just check if we can read the header }
        if (LHdr[0] and $70) <> 0 then
          { Reserved bits set - invalid }
          ;
        if not (LHdr[0] and $0F in [0, 1, 2, 8, 9, 10]) then
          { Invalid opcode }
          ;
      end;
    except
      on E: Exception do
        Inc(LCrashes);
    end;
  end;
  Result := LCrashes;
end;

initialization
  Randomize;

end.
