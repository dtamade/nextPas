unit nextpas.core.text.unicode.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.unicode.types;

type
  // 重新导出类型以保持向后兼容
  TUnicodeCodepoint = nextpas.core.text.unicode.types.TUnicodeCodepoint;
  TGeneralCategory = nextpas.core.text.unicode.types.TGeneralCategory;
  TBinaryProperty = nextpas.core.text.unicode.types.TBinaryProperty;
  TGeneralCategorySet = nextpas.core.text.unicode.types.TGeneralCategorySet;
  TCodepointRange2 = nextpas.core.text.unicode.types.TCodepointRange2;
  TCodepointRange3 = nextpas.core.text.unicode.types.TCodepointRange3;
  TCodepointRange16 = nextpas.core.text.unicode.types.TCodepointRange16;
  TCodepointRange32 = nextpas.core.text.unicode.types.TCodepointRange32;
  TCaseFoldMap = nextpas.core.text.unicode.types.TCaseFoldMap;
  TCaseFoldEntry = nextpas.core.text.unicode.types.TCaseFoldEntry;
  TUnicodeScript = nextpas.core.text.unicode.types.TUnicodeScript;
  TUnicodeBlock = nextpas.core.text.unicode.types.TUnicodeBlock;

const
  UNICODE_MAX_CODEPOINT = nextpas.core.text.unicode.types.UNICODE_MAX_CODEPOINT;
  UNICODE_SURROGATE_FIRST = nextpas.core.text.unicode.types.UNICODE_SURROGATE_FIRST;
  UNICODE_SURROGATE_LAST = nextpas.core.text.unicode.types.UNICODE_SURROGATE_LAST;

function FindRange2(const ACp: TUnicodeCodepoint; const ARanges: array of TCodepointRange2): Int32; inline;
function FindRange3Value(const ACp: TUnicodeCodepoint; const ARanges: array of TCodepointRange3;
  out AValue: Byte): Boolean; inline;
function FindRange16Value(const ACp: TUnicodeCodepoint; const ARanges: array of TCodepointRange16;
  out AValue: UInt16): Boolean; inline;
function FindRange32Value(const ACp: TUnicodeCodepoint; const ARanges: array of TCodepointRange32;
  out AValue: UInt32): Boolean; inline;

implementation

{ Bodies expanded in-place (no {$I}/IFDEF template). Multi-line DEFINE and
  include-body were unreliable under nextpas preprocess+green attach, which
  left bare @FindRange2 / @FindRange3Value residuals on the L3 ladder. }

function FindRange2(const ACp: TUnicodeCodepoint; const ARanges: array of TCodepointRange2): Int32;
var
  LLo: SizeInt;
  LHi: SizeInt;
  LMid: SizeInt;
begin
  LLo := 0;
  LHi := High(ARanges);
  while LLo <= LHi do
  begin
    LMid := LLo + ((LHi - LLo) div 2);
    if ACp <= ARanges[LMid].Hi then
    begin
      if ACp >= ARanges[LMid].Lo then
        Exit(Int32(LMid));
      LHi := LMid - 1;
    end
    else
      LLo := LMid + 1;
  end;
  Result := -1;
end;

function FindRange3Value(const ACp: TUnicodeCodepoint; const ARanges: array of TCodepointRange3;
  out AValue: Byte): Boolean;
var
  LLo: SizeInt;
  LHi: SizeInt;
  LMid: SizeInt;
begin
  LLo := 0;
  LHi := High(ARanges);
  while LLo <= LHi do
  begin
    LMid := LLo + ((LHi - LLo) div 2);
    if ACp <= ARanges[LMid].Hi then
    begin
      if ACp >= ARanges[LMid].Lo then
      begin
        AValue := ARanges[LMid].Value;
        Exit(True);
      end;
      LHi := LMid - 1;
    end
    else
      LLo := LMid + 1;
  end;
  Result := False;
end;

function FindRange16Value(const ACp: TUnicodeCodepoint; const ARanges: array of TCodepointRange16;
  out AValue: UInt16): Boolean;
var
  LLo: SizeInt;
  LHi: SizeInt;
  LMid: SizeInt;
begin
  LLo := 0;
  LHi := High(ARanges);
  while LLo <= LHi do
  begin
    LMid := LLo + ((LHi - LLo) div 2);
    if ACp <= ARanges[LMid].Hi then
    begin
      if ACp >= ARanges[LMid].Lo then
      begin
        AValue := ARanges[LMid].Value;
        Exit(True);
      end;
      LHi := LMid - 1;
    end
    else
      LLo := LMid + 1;
  end;
  Result := False;
end;

function FindRange32Value(const ACp: TUnicodeCodepoint; const ARanges: array of TCodepointRange32;
  out AValue: UInt32): Boolean;
var
  LLo: SizeInt;
  LHi: SizeInt;
  LMid: SizeInt;
begin
  LLo := 0;
  LHi := High(ARanges);
  while LLo <= LHi do
  begin
    LMid := LLo + ((LHi - LLo) div 2);
    if ACp <= ARanges[LMid].Hi then
    begin
      if ACp >= ARanges[LMid].Lo then
      begin
        AValue := ARanges[LMid].Value;
        Exit(True);
      end;
      LHi := LMid - 1;
    end
    else
      LLo := LMid + 1;
  end;
  Result := False;
end;

end.