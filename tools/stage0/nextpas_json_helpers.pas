unit nextpas_json_helpers;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

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
  Index: SizeInt;
begin
  Result := '';
  for Index := 1 to Length(Value) do
    case Value[Index] of
      '\':
        Result := Result + '\\';
      '"':
        Result := Result + '\"';
      #10:
        Result := Result + '\n';
      #13:
        Result := Result + '\r';
      #9:
        Result := Result + '\t';
    else
      Result := Result + Value[Index];
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
