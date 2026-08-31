unit nextpas.compiler.diagnostics.json_helpers;

{$mode objfpc}{$H+}

interface

uses
  nextpas.core.text.view,
  nextpas.core.text.builder,
  nextpas.core.text.escape,
  nextpas.core.text.conv;

function JsonEscape(const Value: string): string;
function JsonString(const Value: string): string;
function BooleanText(const Value: Boolean): string;
procedure AppendJsonField(
  var AFields: string;
  const AName: string;
  const AValue: string
);
procedure AppendJsonStringField(
  var AFields: string;
  const AName: string;
  const AValue: string
);
procedure AppendJsonStringFieldWhenEnabled(
  var AFields: string;
  const AName: string;
  const AValue: string;
  const AEnabled: Boolean
);
procedure AppendJsonIntegerField(
  var AFields: string;
  const AName: string;
  const AValue: LongInt;
  const AEnabled: Boolean
);
procedure AppendJsonBooleanField(
  var AFields: string;
  const AName: string;
  const AValue: Boolean;
  const AEnabled: Boolean
);

implementation

function JsonEscape(const Value: string): string;
var
  View: TStringView;
  Builder: TBufStringBuilder;
begin
  if Value = '' then Exit('');
  View := TStringView.Create(PAnsiChar(@Value[1]), SizeUInt(Length(Value)));
  Builder.Init(SizeUInt(Length(Value) + 16));
  try
    JsonEscapeToBuilder(View, Builder);
    Result := Builder.ToString;
  finally
    Builder.Done;
  end;
end;

function JsonString(const Value: string): string;
begin
  Result := '"' + JsonEscape(Value) + '"';
end;

function BooleanText(const Value: Boolean): string;
begin
  if Value then
    Exit('true');

  Result := 'false';
end;

procedure AppendJsonField(
  var AFields: string;
  const AName: string;
  const AValue: string
);
begin
  if AFields <> '' then
    AFields := AFields + ',';
  AFields := AFields + JsonString(AName) + ':' + AValue;
end;

procedure AppendJsonStringField(
  var AFields: string;
  const AName: string;
  const AValue: string
);
begin
  if AValue = '' then
    Exit;

  AppendJsonField(AFields, AName, JsonString(AValue));
end;

procedure AppendJsonStringFieldWhenEnabled(
  var AFields: string;
  const AName: string;
  const AValue: string;
  const AEnabled: Boolean
);
begin
  if not AEnabled then
    Exit;

  AppendJsonField(AFields, AName, JsonString(AValue));
end;

procedure AppendJsonIntegerField(
  var AFields: string;
  const AName: string;
  const AValue: LongInt;
  const AEnabled: Boolean
);
begin
  if not AEnabled then
    Exit;

  AppendJsonField(AFields, AName, IntToStr(AValue));
end;

procedure AppendJsonBooleanField(
  var AFields: string;
  const AName: string;
  const AValue: Boolean;
  const AEnabled: Boolean
);
begin
  if not AEnabled then
    Exit;

  AppendJsonField(AFields, AName, BooleanText(AValue));
end;

end.
