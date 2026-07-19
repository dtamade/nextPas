unit nextpas.core.config.env;

{$I nextpas.core.settings.inc}

interface

function TryConfigEnvNameToKey(const AName, APrefix: string;
  out AKey: string): Boolean;
function NextConfigWindowsEnvBlockEntry(var ACursor: PAnsiChar;
  out AEntry: string): Boolean;

implementation

uses
  SysUtils;

function TryConfigEnvNameToKey(const AName, APrefix: string;
  out AKey: string): Boolean;
var
  LPrefixLen: Integer;
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

  AKey := LowerCase(Copy(AName, LPrefixLen + 1,
    Length(AName) - LPrefixLen));
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
