unit nextpas.core.toml.writer;
{ Streaming TOML serializer. Zero allocation — writes directly to a TStringBuilder.
  Supports nested arrays/inline tables via depth-indexed state stack.

  Usage:
    var B: TStringBuilder; W: TTomlWriter;
    B.Init(256); W.Init(B);
    W.Key('name'); W.Str('Alice');
    W.BeginTable('server');
    W.Key('port'); W.Int(8080);
    WriteLn(B.ToString);
    B.Done; }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view,
  nextpas.core.text.builder,
  nextpas.core.toml.base;

type
  TTomlWriter = record
  private
    FBuilder: ^TStringBuilder;
    FInlineDepth: Int32;
    FNeedNewline: Boolean;
    FFirstStack: array[0..31] of Boolean;
    FIsArrayStack: array[0..31] of Boolean;
    procedure WriteEscapedStr(const AValue: PAnsiChar; ALen: SizeUInt);
    procedure WriteBareOrQuotedKey(const AKey: PAnsiChar; ALen: SizeUInt);
    procedure PrepareValue;
  public
    procedure Init(var ABuilder: TStringBuilder);
    procedure BeginTable(const AKey: string);
    procedure BeginArrayTable(const AKey: string);
    procedure Key(const AKey: string); overload;
    procedure Key(const AKey: TStringView); overload;
    procedure Str(const AValue: string); overload;
    procedure Str(const AValue: TStringView); overload;
    procedure Int(const AValue: Int64);
    procedure Float(const AValue: Double);
    procedure Bool(const AValue: Boolean);
    procedure DateTime(const AValue: TTomlDateTime);
    procedure BeginInlineTable;
    procedure EndInlineTable;
    procedure BeginArray;
    procedure EndArray;
    procedure Comment(const AText: string);
    procedure Newline;
  end;

implementation

uses
  nextpas.core.text.number;

function IsBareKeyStr(const AData: PAnsiChar; ALen: SizeUInt): Boolean;
var
  LI: SizeUInt;
  LCh: Byte;
begin
  if ALen = 0 then Exit(False);
  for LI := 0 to ALen - 1 do
  begin
    LCh := Byte(AData[LI]);
    if not (((LCh >= Ord('A')) and (LCh <= Ord('Z')))
      or ((LCh >= Ord('a')) and (LCh <= Ord('z')))
      or ((LCh >= Ord('0')) and (LCh <= Ord('9')))
      or (LCh = Ord('-')) or (LCh = Ord('_'))) then
      Exit(False);
  end;
  Result := True;
end;

procedure TTomlWriter.Init(var ABuilder: TStringBuilder);
begin
  FBuilder := @ABuilder;
  FInlineDepth := 0;
  FNeedNewline := False;
end;

procedure TTomlWriter.WriteEscapedStr(const AValue: PAnsiChar; ALen: SizeUInt);
var
  LI: SizeUInt;
  LCh: Byte;
begin
  FBuilder^.AppendChar('"');
  if ALen > 0 then
  for LI := 0 to ALen - 1 do
  begin
    LCh := Byte(AValue[LI]);
    case LCh of
      Ord('"'): FBuilder^.AppendBytes('\"', 2);
      Ord('\'): FBuilder^.AppendBytes('\\', 2);
      8: FBuilder^.AppendBytes('\b', 2);
      9: FBuilder^.AppendBytes('\t', 2);
      10: FBuilder^.AppendBytes('\n', 2);
      12: FBuilder^.AppendBytes('\f', 2);
      13: FBuilder^.AppendBytes('\r', 2);
    else
      if LCh < 32 then
      begin
        FBuilder^.AppendBytes('\u00', 4);
        FBuilder^.AppendChar(AnsiChar(Ord('0') + (LCh shr 4)));
        if (LCh and $F) < 10 then
          FBuilder^.AppendChar(AnsiChar(Ord('0') + (LCh and $F)))
        else
          FBuilder^.AppendChar(AnsiChar(Ord('a') + (LCh and $F) - 10));
      end
      else
        FBuilder^.AppendChar(AnsiChar(LCh));
    end;
  end;
  FBuilder^.AppendChar('"');
end;

procedure TTomlWriter.WriteBareOrQuotedKey(const AKey: PAnsiChar; ALen: SizeUInt);
begin
  if IsBareKeyStr(AKey, ALen) then
    FBuilder^.AppendBytes(AKey, ALen)
  else
    WriteEscapedStr(AKey, ALen);
end;

procedure TTomlWriter.PrepareValue;
begin
  if (FInlineDepth > 0) and FIsArrayStack[FInlineDepth] then
  begin
    if not FFirstStack[FInlineDepth] then
      FBuilder^.AppendBytes(', ', 2);
    FFirstStack[FInlineDepth] := False;
  end;
end;

procedure TTomlWriter.BeginTable(const AKey: string);
begin
  if FNeedNewline then FBuilder^.AppendChar(#10);
  FBuilder^.AppendChar('[');
  WriteBareOrQuotedKey(PAnsiChar(AKey), SizeUInt(Length(AKey)));
  FBuilder^.AppendChar(']');
  FBuilder^.AppendChar(#10);
  FNeedNewline := True;
end;

procedure TTomlWriter.BeginArrayTable(const AKey: string);
begin
  if FNeedNewline then FBuilder^.AppendChar(#10);
  FBuilder^.AppendBytes('[[', 2);
  WriteBareOrQuotedKey(PAnsiChar(AKey), SizeUInt(Length(AKey)));
  FBuilder^.AppendBytes(']]', 2);
  FBuilder^.AppendChar(#10);
  FNeedNewline := True;
end;

procedure TTomlWriter.Key(const AKey: string);
begin
  if FInlineDepth > 0 then
  begin
    if not FFirstStack[FInlineDepth] then
      FBuilder^.AppendBytes(', ', 2);
    FFirstStack[FInlineDepth] := False;
  end;
  WriteBareOrQuotedKey(PAnsiChar(AKey), SizeUInt(Length(AKey)));
  FBuilder^.AppendBytes(' = ', 3);
end;

procedure TTomlWriter.Key(const AKey: TStringView);
begin
  if FInlineDepth > 0 then
  begin
    if not FFirstStack[FInlineDepth] then
      FBuilder^.AppendBytes(', ', 2);
    FFirstStack[FInlineDepth] := False;
  end;
  WriteBareOrQuotedKey(AKey.Data, AKey.Len);
  FBuilder^.AppendBytes(' = ', 3);
end;

procedure TTomlWriter.Str(const AValue: string);
begin
  PrepareValue;
  WriteEscapedStr(PAnsiChar(AValue), SizeUInt(Length(AValue)));
  if FInlineDepth = 0 then FBuilder^.AppendChar(#10);
end;

procedure TTomlWriter.Str(const AValue: TStringView);
begin
  PrepareValue;
  WriteEscapedStr(AValue.Data, AValue.Len);
  if FInlineDepth = 0 then FBuilder^.AppendChar(#10);
end;

procedure TTomlWriter.Int(const AValue: Int64);
begin
  PrepareValue;
  FBuilder^.AppendInt(AValue);
  if FInlineDepth = 0 then FBuilder^.AppendChar(#10);
end;

procedure TTomlWriter.Float(const AValue: Double);
var
  LBits: QWord;
  LStart: SizeUInt;
  LView: TStringView;
  LI: SizeUInt;
  LHasDotOrE: Boolean;
begin
  PrepareValue;
  Move(AValue, LBits, 8);
  if (LBits and QWord($7FF0000000000000)) = QWord($7FF0000000000000) then
  begin
    if (LBits and QWord($000FFFFFFFFFFFFF)) <> 0 then
      FBuilder^.AppendBytes('nan', 3)
    else if (LBits and QWord($8000000000000000)) <> 0 then
      FBuilder^.AppendBytes('-inf', 4)
    else
      FBuilder^.AppendBytes('inf', 3);
  end
  else
  begin
    LStart := FBuilder^.Len;
    FBuilder^.AppendFloat(AValue);
    LView := FBuilder^.AsView;
    LHasDotOrE := False;
    for LI := LStart to LView.Len - 1 do
      if (LView.Data[LI] = '.') or (LView.Data[LI] = 'e') or (LView.Data[LI] = 'E') then
      begin
        LHasDotOrE := True;
        Break;
      end;
    if not LHasDotOrE then
      FBuilder^.AppendBytes('.0', 2);
  end;
  if FInlineDepth = 0 then FBuilder^.AppendChar(#10);
end;

procedure TTomlWriter.Bool(const AValue: Boolean);
begin
  PrepareValue;
  if AValue then
    FBuilder^.AppendBytes('true', 4)
  else
    FBuilder^.AppendBytes('false', 5);
  if FInlineDepth = 0 then FBuilder^.AppendChar(#10);
end;

procedure TTomlWriter.DateTime(const AValue: TTomlDateTime);
begin
  PrepareValue;
  if AValue.HasDate then
  begin
    FBuilder^.AppendInt(AValue.Year);
    FBuilder^.AppendChar('-');
    if AValue.Month < 10 then FBuilder^.AppendChar('0');
    FBuilder^.AppendInt(AValue.Month);
    FBuilder^.AppendChar('-');
    if AValue.Day < 10 then FBuilder^.AppendChar('0');
    FBuilder^.AppendInt(AValue.Day);
  end;
  if AValue.HasDate and AValue.HasTime then
    FBuilder^.AppendChar('T');
  if AValue.HasTime then
  begin
    if AValue.Hour < 10 then FBuilder^.AppendChar('0');
    FBuilder^.AppendInt(AValue.Hour);
    FBuilder^.AppendChar(':');
    if AValue.Minute < 10 then FBuilder^.AppendChar('0');
    FBuilder^.AppendInt(AValue.Minute);
    FBuilder^.AppendChar(':');
    if AValue.Second < 10 then FBuilder^.AppendChar('0');
    FBuilder^.AppendInt(AValue.Second);
    if AValue.Nanosecond > 0 then
    begin
      FBuilder^.AppendChar('.');
      FBuilder^.AppendInt(AValue.Nanosecond);
    end;
  end;
  if AValue.HasOffset then
  begin
    if AValue.OffsetMinutes = 0 then
      FBuilder^.AppendChar('Z')
    else
    begin
      if AValue.OffsetMinutes < 0 then
      begin
        FBuilder^.AppendChar('-');
        if (-AValue.OffsetMinutes div 60) < 10 then FBuilder^.AppendChar('0');
        FBuilder^.AppendInt(-AValue.OffsetMinutes div 60);
        FBuilder^.AppendChar(':');
        if (-AValue.OffsetMinutes mod 60) < 10 then FBuilder^.AppendChar('0');
        FBuilder^.AppendInt(-AValue.OffsetMinutes mod 60);
      end
      else
      begin
        FBuilder^.AppendChar('+');
        if (AValue.OffsetMinutes div 60) < 10 then FBuilder^.AppendChar('0');
        FBuilder^.AppendInt(AValue.OffsetMinutes div 60);
        FBuilder^.AppendChar(':');
        if (AValue.OffsetMinutes mod 60) < 10 then FBuilder^.AppendChar('0');
        FBuilder^.AppendInt(AValue.OffsetMinutes mod 60);
      end;
    end;
  end;
  if FInlineDepth = 0 then FBuilder^.AppendChar(#10);
end;

procedure TTomlWriter.BeginInlineTable;
begin
  PrepareValue;
  FBuilder^.AppendBytes('{ ', 2);
  Inc(FInlineDepth);
  FIsArrayStack[FInlineDepth] := False;
  FFirstStack[FInlineDepth] := True;
end;

procedure TTomlWriter.EndInlineTable;
begin
  FBuilder^.AppendBytes(' }', 2);
  Dec(FInlineDepth);
  if FInlineDepth = 0 then FBuilder^.AppendChar(#10);
end;

procedure TTomlWriter.BeginArray;
begin
  PrepareValue;
  FBuilder^.AppendChar('[');
  Inc(FInlineDepth);
  FIsArrayStack[FInlineDepth] := True;
  FFirstStack[FInlineDepth] := True;
end;

procedure TTomlWriter.EndArray;
begin
  FBuilder^.AppendChar(']');
  Dec(FInlineDepth);
  if FInlineDepth = 0 then FBuilder^.AppendChar(#10);
end;

procedure TTomlWriter.Comment(const AText: string);
begin
  FBuilder^.AppendBytes('# ', 2);
  FBuilder^.AppendStr(AText);
  FBuilder^.AppendChar(#10);
end;

procedure TTomlWriter.Newline;
begin
  FBuilder^.AppendChar(#10);
end;

end.
