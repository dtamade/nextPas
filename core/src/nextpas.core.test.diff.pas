{ nextpas.core.test.diff — L0 string diagnostic helpers (ColorDiff)
  =========================================================
  No dependency on test.output / test.check. Used by check, expect, output. }

unit nextpas.core.test.diff;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.test.config;

{ Produce a colored (or plain) diff for expected vs actual strings.
  AnsiMode amOn forces color; amOff forces plain; amAuto follows NEXTPAS_COLOR /
  NO_COLOR env (no TTY probe — keeps L0 free of console coupling beyond env). }
function ColorDiff(const AExpected, AActual: string;
  const AConfig: TTestConfig): string;

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.platform.env;

const
  ESC      = #27'[';
  C_RESET  = ESC + '0m';
  C_BOLD   = ESC + '1m';
  C_GREEN  = ESC + '32m';
  C_RED    = ESC + '31m';
  C_DIM    = ESC + '2m';
  C_STRIKE = ESC + '9m';

function WantAnsi(const AConfig: TTestConfig): Boolean;
var
  LCfg: TTestConfig;
  LColor: string;
begin
  LCfg := ResolveConfig(AConfig);
  case LCfg.AnsiMode of
    amOn:  Exit(True);
    amOff: Exit(False);
    amAuto: ; { 落穿到下方 env 探测 }
  end;
  { amAuto: env only (L0 isolation — no isatty) }
  if string(platform_env_get_str('NO_COLOR')) <> '' then
    Exit(False);
  LColor := string(platform_env_get_str('NEXTPAS_COLOR'));
  if LColor = '0' then
    Exit(False);
  if LColor = '1' then
    Exit(True);
  Result := False; { default plain when not forced }
end;

function ColorDiff(const AExpected, AActual: string;
  const AConfig: TTestConfig): string;
var
  I, LMin, LDiffAt: Integer;
  LUseAnsi: Boolean;
  LExpLine, LActLine: string;
begin
  LUseAnsi := WantAnsi(AConfig);

  LMin := Length(AExpected);
  if Length(AActual) < LMin then
    LMin := Length(AActual);
  LDiffAt := 1;
  while (LDiffAt <= LMin) and (AExpected[LDiffAt] = AActual[LDiffAt]) do
    Inc(LDiffAt);
  if LDiffAt > LMin then
    LDiffAt := LMin + 1;

  if LUseAnsi then
  begin
    if LDiffAt > 1 then
    begin
      LExpLine := C_DIM + Copy(AExpected, 1, LDiffAt - 1) + C_RESET;
      LActLine := C_DIM + Copy(AActual, 1, LDiffAt - 1) + C_RESET;
    end
    else
    begin
      LExpLine := '';
      LActLine := '';
    end;

    if LDiffAt <= Length(AExpected) then
      LExpLine := LExpLine + C_GREEN + C_STRIKE +
        Copy(AExpected, LDiffAt, Length(AExpected) - LDiffAt + 1) + C_RESET
    else
      LExpLine := LExpLine + C_DIM + '(empty)' + C_RESET;

    if LDiffAt <= Length(AActual) then
      LActLine := LActLine + C_RED + C_BOLD +
        Copy(AActual, LDiffAt, Length(AActual) - LDiffAt + 1) + C_RESET
    else
      LActLine := LActLine + C_DIM + '(empty)' + C_RESET;

    Result := 'Strings differ at position ' + IntToStr(LDiffAt) + ':' + #10 +
      '  expected: ' + LExpLine + #10 +
      '    actual: ' + LActLine;
  end
  else
  begin
    Result := 'Strings differ at position ' + IntToStr(LDiffAt) + ':' + #10 +
      '  expected: "' + AExpected + '"'#10 +
      '    actual: "' + AActual + '"'#10 +
      '            ' + StringOfChar(' ', LDiffAt - 1) + '^';
  end;
end;

end.
