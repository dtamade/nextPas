unit nextpas.core.http.fuzz;
{**
 * @desc HTTP/WebSocket fuzz testing utilities.
 *       Provides mutation-based fuzzing for parser robustness testing.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
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
  nextpas.core.exception,
  nextpas.core.http.base,
  nextpas.core.http.websocket;

type
  { Simple IReader implementation for fuzz testing }
  TFuzzReader = class(TInterfacedObject, IReader)
  private
    FData: nextpas.core.base.TBytes;
    FPos: SizeUInt;
  public
    constructor Create(const AData: nextpas.core.base.TBytes);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
  end;

constructor TFuzzReader.Create(const AData: nextpas.core.base.TBytes);
begin
  inherited Create;
  FData := AData;
  FPos := 0;
end;

function TFuzzReader.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LAvail: SizeUInt;
  LCount: SizeUInt;
begin
  LAvail := SizeUInt(Length(FData)) - FPos;
  if LAvail = 0 then
    Exit(0);
  LCount := ACount;
  if LCount > LAvail then
    LCount := LAvail;
  Move(FData[FPos], ABuf, LCount);
  Inc(FPos, LCount);
  Result := LCount;
end;

{ Parse WebSocket frame header - mirrors TWebSocketImpl.ReadFrame logic }
procedure ParseWebSocketFrameHeader(const AData: nextpas.core.base.TBytes);
var
  LLen: Integer;
  LHdr0, LHdr1: Byte;
  LOpcode: Byte;
  LMasked: Boolean;
  LPayloadLen: UInt64;
  LExtLen: array[0..7] of Byte;
  I: Integer;
begin
  LLen := Length(AData);
  if LLen < 2 then
    raise EHttpError.Create(hekProtocol, 'WebSocket: frame too short');

  LHdr0 := AData[0];
  LHdr1 := AData[1];

  { Validate reserved bits }
  if (LHdr0 and $70) <> 0 then
    raise EHttpError.Create(hekProtocol, 'WebSocket: reserved bits set');

  { Validate opcode }
  LOpcode := LHdr0 and $0F;
  case LOpcode of
    $0, $1, $2, $8, $9, $A: ; { Valid opcodes }
  else
    raise EHttpError.Create(hekProtocol, 'WebSocket: reserved or invalid opcode');
  end;

  { Control frames must not be fragmented }
  if (LOpcode >= $08) and ((LHdr0 and $80) = 0) then
    raise EHttpError.Create(hekProtocol, 'WebSocket: control frames must not be fragmented');

  { Parse payload length }
  LMasked := (LHdr1 and $80) <> 0;
  LPayloadLen := LHdr1 and $7F;

  if LPayloadLen = 126 then
  begin
    if LLen < 4 then
      raise EHttpError.Create(hekProtocol, 'WebSocket: frame too short for 16-bit length');
    LPayloadLen := (UInt64(AData[2]) shl 8) or UInt64(AData[3]);
    if LPayloadLen < 126 then
      raise EHttpError.Create(hekProtocol, 'WebSocket: non-canonical payload length');
  end
  else if LPayloadLen = 127 then
  begin
    if LLen < 10 then
      raise EHttpError.Create(hekProtocol, 'WebSocket: frame too short for 64-bit length');
    if (AData[2] and $80) <> 0 then
      raise EHttpError.Create(hekProtocol, 'WebSocket: invalid 64-bit payload length');
    LPayloadLen := 0;
    for I := 2 to 9 do
      LPayloadLen := (LPayloadLen shl 8) or UInt64(AData[I]);
    if LPayloadLen < 65536 then
      raise EHttpError.Create(hekProtocol, 'WebSocket: non-canonical payload length');
  end;

  { Control frame payload size limit }
  if (LOpcode >= $08) and (LPayloadLen > 125) then
    raise EHttpError.Create(hekProtocol, 'WebSocket: control frame payload too large');
end;

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
begin
  LCrashes := 0;
  for I := 0 to AIterations - 1 do
  begin
    { Select random seed }
    LSeedIdx := Random(Length(ASeeds));
    LData := ASeeds[LSeedIdx];

    { Mutate }
    LMutated := TFuzzMutator.Mutate(LData);

    { Try to parse with real WebSocket frame parser logic }
    try
      ParseWebSocketFrameHeader(LMutated);
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
