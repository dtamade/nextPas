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
    procedure ValidateValue;
    procedure WriteValuePrefix;
    procedure BeginValue;
    procedure BeginContainerValue;
    procedure EndValue;
    procedure BeginKey;
    procedure RequireContainerCapacity;
    procedure PushContainer(const AContainer: Byte);
    procedure RequireContainer(const AOperation: string;
      const AContainer: Byte);
  public
    procedure Init(var ABuilder: TStringBuilder);
    procedure BeginObject;
    procedure EndObject;
    procedure BeginArray;
    procedure EndArray;
    procedure Key(const AKey: PAnsiChar; const ALen: SizeUInt); overload;
    procedure Key(const AKey: TStringView); overload;
    procedure Key(const AKey: string); overload;
    procedure Null;
    procedure Bool(const AValue: Boolean);
    procedure Int(const AValue: Int64);
    procedure UInt(const AValue: UInt64);
    procedure Float(const AValue: Double);
    procedure Str(const AValue: PAnsiChar; const ALen: SizeUInt); overload;
    procedure Str(const AValue: TStringView); overload;
    procedure Str(const AValue: string); overload;
    procedure StrClean(const AValue: PAnsiChar; const ALen: SizeUInt);
    procedure KeyClean(const AKey: PAnsiChar; const ALen: SizeUInt);
    procedure RawValue(const AJson: PAnsiChar; const ALen: SizeUInt);
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.simd.base,
  nextpas.core.simd.vec,
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
var
  LNeedsEscape: Boolean;
  LPos: SizeUInt;
  LMask: TVecMask;
begin
  BeginKey;
  FBuilder^.AppendChar('"');
  LNeedsEscape := False;
  LPos := 0;
  while LPos + VecWidth <= ALen do
  begin
    LMask := VecCmpEq(@AKey[LPos], Ord('"')) or VecCmpEq(@AKey[LPos], Ord('\')) or
             VecCmpLtU(@AKey[LPos], $20);
    if LMask <> TVecMask(0) then
    begin
      LNeedsEscape := True;
      Break;
    end;
    Inc(LPos, VecWidth);
  end;
  if not LNeedsEscape then
    while LPos < ALen do
    begin
      if (Byte(AKey[LPos]) < $20) or (AKey[LPos] = '"') or (AKey[LPos] = '\') then
      begin
        LNeedsEscape := True;
        Break;
      end;
      Inc(LPos);
    end;
  if LNeedsEscape then
    JsonEscapeToBuilder(TStringView.Create(AKey, ALen), FBuilder^)
  else
    FBuilder^.AppendBytes(AKey, ALen);
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
var
  LNeedsEscape: Boolean;
  LPos: SizeUInt;
  LMask: TVecMask;
begin
  BeginValue;
  FBuilder^.AppendChar('"');
  LNeedsEscape := False;
  LPos := 0;
  while LPos + VecWidth <= ALen do
  begin
    LMask := VecCmpEq(@AValue[LPos], Ord('"')) or
             VecCmpEq(@AValue[LPos], Ord('\')) or
             VecCmpLtU(@AValue[LPos], $20);
    if LMask <> TVecMask(0) then
    begin
      LNeedsEscape := True;
      Break;
    end;
    Inc(LPos, VecWidth);
  end;
  if not LNeedsEscape then
    while LPos < ALen do
    begin
      if (Byte(AValue[LPos]) < $20) or (AValue[LPos] = '"') or (AValue[LPos] = '\') then
      begin
        LNeedsEscape := True;
        Break;
      end;
      Inc(LPos);
    end;
  if LNeedsEscape then
    JsonEscapeToBuilder(TStringView.Create(AValue, ALen), FBuilder^)
  else
    FBuilder^.AppendBytes(AValue, ALen);
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
  Move(AValue^, LP^, ALen); Inc(LP, ALen);
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
  Move(AKey^, LP^, ALen); Inc(LP, ALen);
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
