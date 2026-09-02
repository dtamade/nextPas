unit nextpas.core.json.writer;
// Streaming JSON serializer. Zero allocation — writes directly to a TStringBuilder.
// Automatically inserts commas between values.
//
// Usage:
//   var B: TStringBuilder; W: TJsonWriter;
//   B.Init(256); W.Init(B);
//   W.BeginObject;
//     W.Key('name'); W.Str('Alice');
//     W.Key('age'); W.Int(30);
//   W.EndObject;
//   WriteLn(B.ToString);  // {"name":"Alice","age":30}
//   B.Done;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view,
  nextpas.core.text.builder;

const
  JSON_WRITER_MAX_DEPTH = 512;

type
  TJsonWriter = record
  private
    FBuilder: ^TStringBuilder;
    FDepth: Int32;
    FRootWritten: Boolean;
    FContainers: array[1..JSON_WRITER_MAX_DEPTH] of Byte;
    FElementCounts: array[1..JSON_WRITER_MAX_DEPTH] of UInt32;
    FObjectAwaitingKey: array[1..JSON_WRITER_MAX_DEPTH] of Boolean;
    procedure ValidateValue; inline;
    procedure WriteValuePrefix; inline;
    procedure BeginValue; inline;
    procedure BeginContainerValue; inline;
    procedure EndValue; inline;
    procedure BeginKey; inline;
    procedure RequireContainerCapacity; inline;
    procedure PushContainer(const AContainer: Byte); inline;
    procedure RequireContainer(const AOperation: string;
      const AContainer: Byte); inline;
  public
    procedure Init(var ABuilder: TStringBuilder); inline;
    procedure BeginObject; inline;
    procedure EndObject; inline;
    procedure BeginArray; inline;
    procedure EndArray; inline;
    procedure Key(const AKey: PAnsiChar; const ALen: SizeUInt); overload;
    procedure Key(const AKey: TStringView); overload; inline;
    procedure Key(const AKey: string); overload; inline;
    procedure Null; inline;
    procedure Bool(const AValue: Boolean); inline;
    procedure Int(const AValue: Int64); inline;
    procedure UInt(const AValue: UInt64); inline;
    procedure Float(const AValue: Double); inline;
    procedure Str(const AValue: PAnsiChar; const ALen: SizeUInt); overload;
    procedure Str(const AValue: TStringView); overload; inline;
    procedure Str(const AValue: string); overload; inline;
    procedure StrClean(const AValue: PAnsiChar; const ALen: SizeUInt);
    procedure KeyClean(const AKey: PAnsiChar; const ALen: SizeUInt);
    procedure RawValue(const AJson: PAnsiChar; const ALen: SizeUInt); inline;
  end;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.errors,
  nextpas.core.text.escape,
  nextpas.core.text.number;

const
  JSON_CONTAINER_OBJECT = 1;
  JSON_CONTAINER_ARRAY = 2;

procedure TJsonWriter.Init(var ABuilder: TStringBuilder);
begin
  FBuilder := @ABuilder;
  FDepth := 0;
  FRootWritten := False;
end;

procedure TJsonWriter.ValidateValue;
begin
  if FDepth = 0 then
  begin
    if FRootWritten then
      raise EInvalidOperationError.Create(
        'TJsonWriter: root value has already been written');
    Exit;
  end;

  if (FContainers[FDepth] = JSON_CONTAINER_OBJECT) and
    FObjectAwaitingKey[FDepth] then
    raise EInvalidOperationError.Create(
      'TJsonWriter: object value requires a key');
end;

procedure TJsonWriter.WriteValuePrefix;
begin
  if (FDepth > 0) and (FContainers[FDepth] = JSON_CONTAINER_ARRAY) and
    (FElementCounts[FDepth] > 0) then
    FBuilder^.AppendChar(',');
end;

procedure TJsonWriter.BeginValue;
begin
  ValidateValue;
  WriteValuePrefix;
end;

procedure TJsonWriter.BeginContainerValue;
begin
  ValidateValue;
  RequireContainerCapacity;
  WriteValuePrefix;
end;

procedure TJsonWriter.EndValue;
begin
  if FDepth = 0 then
  begin
    FRootWritten := True;
    Exit;
  end;

  Inc(FElementCounts[FDepth]);
  if FContainers[FDepth] = JSON_CONTAINER_OBJECT then
    FObjectAwaitingKey[FDepth] := True;
end;

procedure TJsonWriter.BeginKey;
begin
  if (FDepth <= 0) or (FContainers[FDepth] <> JSON_CONTAINER_OBJECT) then
    raise EInvalidOperationError.Create(
      'TJsonWriter: key requires an open object');
  if not FObjectAwaitingKey[FDepth] then
    raise EInvalidOperationError.Create(
      'TJsonWriter: object key requires a preceding value');
  if FElementCounts[FDepth] > 0 then
    FBuilder^.AppendChar(',');
  FObjectAwaitingKey[FDepth] := False;
end;

procedure TJsonWriter.RequireContainerCapacity;
begin
  if FDepth >= JSON_WRITER_MAX_DEPTH then
    raise EResourceExhaustedError.Create(
      'TJsonWriter: container stack limit exceeded');
end;

procedure TJsonWriter.PushContainer(const AContainer: Byte);
begin
  RequireContainerCapacity;
  Inc(FDepth);
  FContainers[FDepth] := AContainer;
  FElementCounts[FDepth] := 0;
  FObjectAwaitingKey[FDepth] := AContainer = JSON_CONTAINER_OBJECT;
end;

procedure TJsonWriter.RequireContainer(const AOperation: string;
  const AContainer: Byte);
begin
  if FDepth <= 0 then
    raise EInvalidOperationError.Create(
      'TJsonWriter.' + AOperation + ': no container is open');
  if FContainers[FDepth] <> AContainer then
    raise EInvalidOperationError.Create(
      'TJsonWriter.' + AOperation + ': mismatched container end');
  if (AContainer = JSON_CONTAINER_OBJECT) and (not FObjectAwaitingKey[FDepth]) then
    raise EInvalidOperationError.Create(
      'TJsonWriter.' + AOperation + ': object key has no value');
end;

procedure TJsonWriter.BeginObject;
begin
  BeginContainerValue;
  FBuilder^.AppendChar('{');
  PushContainer(JSON_CONTAINER_OBJECT);
end;

procedure TJsonWriter.EndObject;
begin
  RequireContainer('EndObject', JSON_CONTAINER_OBJECT);
  FBuilder^.AppendChar('}');
  Dec(FDepth);
  EndValue;
end;

procedure TJsonWriter.BeginArray;
begin
  BeginContainerValue;
  FBuilder^.AppendChar('[');
  PushContainer(JSON_CONTAINER_ARRAY);
end;

procedure TJsonWriter.EndArray;
begin
  RequireContainer('EndArray', JSON_CONTAINER_ARRAY);
  FBuilder^.AppendChar(']');
  Dec(FDepth);
  EndValue;
end;

procedure TJsonWriter.Key(const AKey: PAnsiChar; const ALen: SizeUInt);
begin
  BeginKey;
  FBuilder^.AppendChar('"');
  // perf: single-pass VecWidth inline via owner text.escape.JsonEscapeToBuilder — zero-copy AppendBytes chunked, inline Reserve/Grow, single source; eliminates double SIMD scan (pre-scan + second scan)
  if ALen > 0 then
    JsonEscapeToBuilder(TStringView.Create(AKey, ALen), FBuilder^);
  FBuilder^.AppendBytes('":', 2);
end;

procedure TJsonWriter.Key(const AKey: TStringView);
begin
  Key(AKey.Data, AKey.Len);
end;

procedure TJsonWriter.Null;
begin
  BeginValue;
  FBuilder^.AppendBytes('null', 4);
  EndValue;
end;

procedure TJsonWriter.Bool(const AValue: Boolean);
begin
  BeginValue;
  if AValue then
    FBuilder^.AppendBytes('true', 4)
  else
    FBuilder^.AppendBytes('false', 5);
  EndValue;
end;

procedure TJsonWriter.Int(const AValue: Int64);
begin
  BeginValue;
  FBuilder^.AppendInt(AValue);
  EndValue;
end;

procedure TJsonWriter.UInt(const AValue: UInt64);
begin
  BeginValue;
  FBuilder^.AppendUInt(AValue);
  EndValue;
end;

procedure TJsonWriter.Float(const AValue: Double);
begin
  BeginValue;
  FBuilder^.AppendFloat(AValue);
  EndValue;
end;

procedure TJsonWriter.Str(const AValue: PAnsiChar; const ALen: SizeUInt);
begin
  BeginValue;
  FBuilder^.AppendChar('"');
  // perf: single-pass VecWidth inline via owner text.escape.JsonEscapeToBuilder — zero-copy AppendBytes chunked, inline Reserve/Grow, single source; eliminates double SIMD scan (pre-scan + second scan)
  if ALen > 0 then
    JsonEscapeToBuilder(TStringView.Create(AValue, ALen), FBuilder^);
  FBuilder^.AppendChar('"');
  EndValue;
end;

procedure TJsonWriter.Str(const AValue: TStringView);
begin
  Str(AValue.Data, AValue.Len);
end;

procedure TJsonWriter.Str(const AValue: string);
begin
  Str(PAnsiChar(AValue), SizeUInt(Length(AValue)));
end;

procedure TJsonWriter.Key(const AKey: string);
begin
  Key(PAnsiChar(AKey), SizeUInt(Length(AKey)));
end;

procedure TJsonWriter.StrClean(const AValue: PAnsiChar; const ALen: SizeUInt);
var
  LNeed: SizeUInt;
  LP: PAnsiChar;
begin
  BeginValue;
  LNeed := ALen + 2;
  FBuilder^.Reserve(LNeed);
  LP := FBuilder^.Tail;
  LP^ := '"'; Inc(LP);
  // perf: zero-copy single Move via bytes.ops single source (BytesCopy inline), Reserve+Tail+AdvanceLen evidence
  if ALen > 0 then begin BytesCopy(LP, AValue, ALen); Inc(LP, ALen); end;
  LP^ := '"'; Inc(LP);
  FBuilder^.AdvanceLen(LNeed);
  EndValue;
end;

procedure TJsonWriter.KeyClean(const AKey: PAnsiChar; const ALen: SizeUInt);
var
  LNeed: SizeUInt;
  LP: PAnsiChar;
begin
  BeginKey;
  LNeed := ALen + 3;
  FBuilder^.Reserve(LNeed);
  LP := FBuilder^.Tail;
  LP^ := '"'; Inc(LP);
  // perf: zero-copy single Move via bytes.ops single source (BytesCopy inline), Reserve+Tail+AdvanceLen evidence
  if ALen > 0 then begin BytesCopy(LP, AKey, ALen); Inc(LP, ALen); end;
  LP^ := '"'; Inc(LP);
  LP^ := ':'; Inc(LP);
  FBuilder^.AdvanceLen(LNeed);
end;

procedure TJsonWriter.RawValue(const AJson: PAnsiChar; const ALen: SizeUInt);
begin
  BeginValue;
  FBuilder^.AppendBytes(AJson, ALen);
  EndValue;
end;

end.
