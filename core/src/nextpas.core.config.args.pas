unit nextpas.core.config.args;
{**
 * @desc Shallow CLI bridge: map present TArgParser options into ConfigBuilder
 *       via AddKeyValues. Lives outside nextpas.core.config so the core facade
 *       does not depend on args.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.args,
  nextpas.core.config;

type
  { How to read a present option from TArgParser. }
  TConfigArgValueKind = (
    cavString,
    cavInt,
    cavBool
  );

{ Append one present option as config key/value. No-op if not IsPresent. }
procedure ConfigAppendPresentArg(
  const AParser: TArgParser;
  const AOptName, AConfigKey: string;
  AKind: TConfigArgValueKind;
  var AKeys, AValues: TStringArray;
  var ACount: Integer);

{ Collect all present options; AOptNames/AConfigKeys/AKinds same length. }
procedure ConfigCollectPresentArgs(
  const AParser: TArgParser;
  const AOptNames, AConfigKeys: array of string;
  const AKinds: array of TConfigArgValueKind;
  out AKeys, AValues: TStringArray);

{ Builder convenience: AddKeyValues(collected present args). }
function ConfigBuilderAddPresentArgs(
  const ABuilder: IConfigBuilder;
  const AParser: TArgParser;
  const AOptNames, AConfigKeys: array of string;
  const AKinds: array of TConfigArgValueKind): IConfigBuilder;

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.errors;

procedure ConfigAppendPresentArg(
  const AParser: TArgParser;
  const AOptName, AConfigKey: string;
  AKind: TConfigArgValueKind;
  var AKeys, AValues: TStringArray;
  var ACount: Integer);
var
  LValue: string;
begin
  if not AParser.IsPresent(AOptName) then
    Exit;
  RequireConfigKey(AConfigKey);
  case AKind of
    cavString:
      LValue := AParser.GetString(AOptName);
    cavInt:
      LValue := IntToStr(AParser.GetInt(AOptName));
    cavBool:
      if AParser.GetBool(AOptName) then
        LValue := 'true'
      else
        LValue := 'false';
  end;
  if ACount >= Length(AKeys) then
  begin
    SetLength(AKeys, ACount + 8);
    SetLength(AValues, ACount + 8);
  end;
  AKeys[ACount] := AConfigKey;
  AValues[ACount] := LValue;
  Inc(ACount);
end;

procedure ConfigCollectPresentArgs(
  const AParser: TArgParser;
  const AOptNames, AConfigKeys: array of string;
  const AKinds: array of TConfigArgValueKind;
  out AKeys, AValues: TStringArray);
var
  LI, LCount: Integer;
begin
  if (Length(AOptNames) <> Length(AConfigKeys)) or
     (Length(AOptNames) <> Length(AKinds)) then
    raise EConfigError.Create(
      'ConfigCollectPresentArgs requires equal-length option/key/kind arrays');

  AKeys := nil;
  AValues := nil;
  LCount := 0;
  for LI := 0 to Length(AOptNames) - 1 do
    ConfigAppendPresentArg(AParser, AOptNames[LI], AConfigKeys[LI], AKinds[LI],
      AKeys, AValues, LCount);
  SetLength(AKeys, LCount);
  SetLength(AValues, LCount);
end;

function ConfigBuilderAddPresentArgs(
  const ABuilder: IConfigBuilder;
  const AParser: TArgParser;
  const AOptNames, AConfigKeys: array of string;
  const AKinds: array of TConfigArgValueKind): IConfigBuilder;
var
  LKeys, LValues: TStringArray;
begin
  if ABuilder = nil then
    raise EConfigError.Create('ConfigBuilderAddPresentArgs requires a builder');
  ConfigCollectPresentArgs(AParser, AOptNames, AConfigKeys, AKinds, LKeys, LValues);
  if Length(LKeys) = 0 then
    Exit(ABuilder);
  Result := ABuilder.AddKeyValues(LKeys, LValues);
end;

end.
