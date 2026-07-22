unit nextpas.core.text.unicode.script;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.unicode.types;

function GetScript(const ACp: TUnicodeCodepoint): TUnicodeScript; inline;
function IsScript(const ACp: TUnicodeCodepoint; const AScript: TUnicodeScript): Boolean; inline;

{ Script_Extensions (UAX#24). No table entry => set is GetScript only.
  Result True if SCX table hit; False if defaulted to singleton Script. }
function GetScriptExtensions(const ACp: TUnicodeCodepoint;
  out ADst: array of TUnicodeScript; out ACount: Byte): Boolean;
function HasScript(const ACp: TUnicodeCodepoint; const AScript: TUnicodeScript): Boolean;

implementation

uses
  nextpas.core.text.unicode.base;

{$I nextpas.core.text.unicode.script.inc}
{$I nextpas.core.text.unicode.script_extensions.inc}

function GetScript(const ACp: TUnicodeCodepoint): TUnicodeScript;
var
  LLo, LHi, LMid: SizeInt;
begin
  if ACp <= $007F then
  begin
    case ACp of
      $0000..$001F: Result := usCommon;
      $0020..$002F: Result := usCommon;
      $0030..$0039: Result := usCommon;
      $003A..$0040: Result := usCommon;
      $0041..$005A: Result := usLatin;
      $005B..$0060: Result := usCommon;
      $0061..$007A: Result := usLatin;
      $007B..$007F: Result := usCommon;
    else
      Result := usCommon;
    end;
    Exit;
  end;

  LLo := 0;
  LHi := SCRIPT_RANGES_COUNT - 1;
  while LLo <= LHi do
  begin
    LMid := LLo + ((LHi - LLo) div 2);
    if ACp < SCRIPT_RANGES[LMid].Lo then
      LHi := LMid - 1
    else if ACp > SCRIPT_RANGES[LMid].Hi then
      LLo := LMid + 1
    else
      Exit(TUnicodeScript(SCRIPT_RANGES[LMid].Script));
  end;

  Result := usUnknown;
end;

function IsScript(const ACp: TUnicodeCodepoint; const AScript: TUnicodeScript): Boolean;
begin
  Result := GetScript(ACp) = AScript;
end;

function FindScxRange(const ACp: TUnicodeCodepoint): SizeInt;
var
  LLo, LHi, LMid: SizeInt;
begin
  LLo := 0;
  LHi := SCX_RANGES_COUNT - 1;
  while LLo <= LHi do
  begin
    LMid := LLo + ((LHi - LLo) div 2);
    if ACp < SCX_RANGES[LMid].Lo then
      LHi := LMid - 1
    else if ACp > SCX_RANGES[LMid].Hi then
      LLo := LMid + 1
    else
      Exit(LMid);
  end;
  Result := -1;
end;

function GetScriptExtensions(const ACp: TUnicodeCodepoint;
  out ADst: array of TUnicodeScript; out ACount: Byte): Boolean;
var
  LIdx, I, LTake: SizeInt;
  LOff: Word;
  LLen: Byte;
begin
  ACount := 0;
  if ACp > UNICODE_MAX_CODEPOINT then
    Exit(False);
  LIdx := FindScxRange(ACp);
  if LIdx < 0 then
  begin
    if Length(ADst) > 0 then
    begin
      ADst[0] := GetScript(ACp);
      ACount := 1;
    end;
    Exit(False);
  end;
  LOff := SCX_RANGES[LIdx].Off;
  LLen := SCX_RANGES[LIdx].Len;
  LTake := LLen;
  if LTake > Length(ADst) then
    LTake := Length(ADst);
  for I := 0 to LTake - 1 do
    ADst[I] := TUnicodeScript(SCX_POOL[LOff + I]);
  ACount := Byte(LTake);
  Result := True;
end;

function HasScript(const ACp: TUnicodeCodepoint; const AScript: TUnicodeScript): Boolean;
var
  LBuf: array[0..31] of TUnicodeScript;
  LCount: Byte;
  I: Integer;
begin
  GetScriptExtensions(ACp, LBuf, LCount);
  for I := 0 to Integer(LCount) - 1 do
    if LBuf[I] = AScript then
      Exit(True);
  Result := False;
end;

end.
