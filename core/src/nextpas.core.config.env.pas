unit nextpas.core.config.env;

{$I nextpas.core.settings.inc}

interface

function TryConfigEnvNameToKey(const AName, APrefix: string;
  out AKey: string): Boolean;
function NextConfigWindowsEnvBlockEntry(var ACursor: PAnsiChar;
  out AEntry: string): Boolean;

implementation

uses
  nextpas.core.text.conv;

function TryConfigEnvNameToKey(const AName, APrefix: string;
  out AKey: string): Boolean;
var
  LPrefixLen: Integer;
  LSuffix: string;
  LI: Integer;
begin
  AKey := '';
  LPrefixLen := Length(APrefix);
  if LPrefixLen = 0 then
    Exit(False);

  if Length(AName) <= LPrefixLen then
    Exit(False);

  {$IFDEF MSWINDOWS}
  { Windows environment names are case-insensitive. }
  Result := SameText(Copy(AName, 1, LPrefixLen), APrefix);
  {$ELSE}
  Result := Copy(AName, 1, LPrefixLen) = APrefix;
  {$ENDIF}
  if not Result then
    Exit;

  { 去前缀后 lower；保留原始分隔符供映射。 }
  LSuffix := Copy(AName, LPrefixLen + 1, Length(AName) - LPrefixLen);

  { 双下划线 → 点：环境变量名无法直接表达 dot-path 嵌套 key
    （server_api_port → server.api_port），这是 wiki/config.md
    「环境变量可覆盖」契约支持嵌套配置项的映射规则。 }
  AKey := '';
  LI := 1;
  while LI <= Length(LSuffix) do
  begin
    if (LSuffix[LI] = '_') and (LI < Length(LSuffix)) and (LSuffix[LI + 1] = '_') then
    begin
      AKey := AKey + '.';
      Inc(LI, 2);
    end
    else
    begin
      AKey := AKey + LSuffix[LI];
      Inc(LI);
    end;
  end;
  AKey := LowerCase(AKey);
  Result := AKey <> '';
  if not Result then
    AKey := '';
end;

function NextConfigWindowsEnvBlockEntry(var ACursor: PAnsiChar;
  out AEntry: string): Boolean;
var
  LStart: PAnsiChar;
begin
  AEntry := '';
  if (ACursor = nil) or (ACursor^ = #0) then
    Exit(False);

  LStart := ACursor;
  while ACursor^ <> #0 do
    Inc(ACursor);
  SetString(AEntry, LStart, ACursor - LStart);
  Inc(ACursor);
  Result := True;
end;

end.
