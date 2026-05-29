unit nextpas.core.json.writer;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view,
  nextpas.core.text.builder;

type
  TJsonWriter = record
  private
    FBuilder: ^TStringBuilder;
    FDepth: Int32;
    FNeedComma: Boolean;
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
    procedure RawValue(const AJson: PAnsiChar; const ALen: SizeUInt);
  end;

implementation

uses
  nextpas.core.text.escape,
  nextpas.core.text.number;

procedure TJsonWriter.Init(var ABuilder: TStringBuilder);
begin
  FBuilder := @ABuilder;
  FDepth := 0;
  FNeedComma := False;
end;

procedure TJsonWriter.BeginObject;
begin
  if FNeedComma then FBuilder^.AppendChar(',');
  FBuilder^.AppendChar('{');
  FNeedComma := False;
  Inc(FDepth);
end;

procedure TJsonWriter.EndObject;
begin
  FBuilder^.AppendChar('}');
  Dec(FDepth);
  FNeedComma := True;
end;

procedure TJsonWriter.BeginArray;
begin
  if FNeedComma then FBuilder^.AppendChar(',');
  FBuilder^.AppendChar('[');
  FNeedComma := False;
  Inc(FDepth);
end;

procedure TJsonWriter.EndArray;
begin
  FBuilder^.AppendChar(']');
  Dec(FDepth);
  FNeedComma := True;
end;

procedure TJsonWriter.Key(const AKey: PAnsiChar; const ALen: SizeUInt);
begin
  if FNeedComma then FBuilder^.AppendChar(',');
  FBuilder^.AppendChar('"');
  JsonEscapeToBuilder(TStringView.Create(AKey, ALen), FBuilder^);
  FBuilder^.AppendBytes('":', 2);
  FNeedComma := False;
end;

procedure TJsonWriter.Key(const AKey: TStringView);
begin
  Key(AKey.Data, AKey.Len);
end;

procedure TJsonWriter.Null;
begin
  if FNeedComma then FBuilder^.AppendChar(',');
  FBuilder^.AppendBytes('null', 4);
  FNeedComma := True;
end;

procedure TJsonWriter.Bool(const AValue: Boolean);
begin
  if FNeedComma then FBuilder^.AppendChar(',');
  if AValue then
    FBuilder^.AppendBytes('true', 4)
  else
    FBuilder^.AppendBytes('false', 5);
  FNeedComma := True;
end;

procedure TJsonWriter.Int(const AValue: Int64);
begin
  if FNeedComma then FBuilder^.AppendChar(',');
  FBuilder^.AppendInt(AValue);
  FNeedComma := True;
end;

procedure TJsonWriter.UInt(const AValue: UInt64);
begin
  if FNeedComma then FBuilder^.AppendChar(',');
  FBuilder^.AppendUInt(AValue);
  FNeedComma := True;
end;

procedure TJsonWriter.Float(const AValue: Double);
begin
  if FNeedComma then FBuilder^.AppendChar(',');
  FBuilder^.AppendFloat(AValue);
  FNeedComma := True;
end;

procedure TJsonWriter.Str(const AValue: PAnsiChar; const ALen: SizeUInt);
begin
  if FNeedComma then FBuilder^.AppendChar(',');
  FBuilder^.AppendChar('"');
  JsonEscapeToBuilder(TStringView.Create(AValue, ALen), FBuilder^);
  FBuilder^.AppendChar('"');
  FNeedComma := True;
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

procedure TJsonWriter.RawValue(const AJson: PAnsiChar; const ALen: SizeUInt);
begin
  if FNeedComma then FBuilder^.AppendChar(',');
  FBuilder^.AppendBytes(AJson, ALen);
  FNeedComma := True;
end;

end.
