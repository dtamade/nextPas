unit nextpas.core.text.unicode.confusable;

{**
 * UTS#39 §4 confusable detection (homograph / spoofing defense).
 * skeleton(X) = NFD(mapConfusables(NFD(X))) over the MA table
 * (confusables.txt); two strings are confusable iff skeletons are equal.
 * L0 error layer: invalid UTF-8 → U+FFFD (consume 1 byte), never raises.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.unicode.types;

const
  { Longest prototype sequence in the MA table (U+FDFA family). }
  CONFUSABLE_MAX_PROTOTYPE = 18;

{ MA-table lookup for a single codepoint. False = no mapping (ACp is its own
  prototype). ADst needs at least CONFUSABLE_MAX_PROTOTYPE elements. }
function GetConfusablePrototype(const ACp: TUnicodeCodepoint;
  out ADst: array of TUnicodeCodepoint; out ALen: Byte): Boolean;

{ UTS#39 skeleton transform. Comparing skeletons byte-wise decides
  confusability; skeletons are NOT display strings. }
function ConfusableSkeleton(const AText: string): string;

function AreConfusable(const A, B: string): Boolean;

implementation

uses
  nextpas.core.text.unicode.normalize,
  nextpas.core.text.utf8;

{$I nextpas.core.text.unicode.confusables.inc}

const
  UNICODE_REPLACEMENT = $FFFD;

function FindConfusableEntry(const ACp: TUnicodeCodepoint): Integer;
var
  LLo, LHi, LMid: Integer;
begin
  LLo := 0;
  LHi := CONFUSABLE_ENTRIES_COUNT - 1;
  while LLo <= LHi do
  begin
    LMid := (LLo + LHi) div 2;
    if ACp < CONFUSABLE_ENTRIES[LMid].Cp then
      LHi := LMid - 1
    else if ACp > CONFUSABLE_ENTRIES[LMid].Cp then
      LLo := LMid + 1
    else
      Exit(LMid);
  end;
  Result := -1;
end;

function GetConfusablePrototype(const ACp: TUnicodeCodepoint;
  out ADst: array of TUnicodeCodepoint; out ALen: Byte): Boolean;
var
  LIdx, I: Integer;
  LOff: UInt32;
begin
  ALen := 0;
  LIdx := FindConfusableEntry(ACp);
  if (LIdx < 0) or (Length(ADst) < Integer(CONFUSABLE_ENTRIES[LIdx].Len)) then
    Exit(False);
  ALen := CONFUSABLE_ENTRIES[LIdx].Len;
  LOff := CONFUSABLE_ENTRIES[LIdx].Offset;
  for I := 0 to Integer(ALen) - 1 do
    ADst[I] := CONFUSABLE_POOL[LOff + UInt32(I)];
  Result := True;
end;

procedure AppendUtf8Cp(var ADst: string; const ACp: TUnicodeCodepoint);
var
  LBuf: array[0..3] of Byte;
  LLen, LOld, I: Integer;
begin
  LLen := Integer(UTF8Encode(ACp, @LBuf[0]));
  if LLen = 0 then
    LLen := Integer(UTF8Encode(UNICODE_REPLACEMENT, @LBuf[0]));
  LOld := Length(ADst);
  SetLength(ADst, LOld + LLen);
  for I := 0 to LLen - 1 do
    ADst[LOld + 1 + I] := AnsiChar(LBuf[I]);
end;

function MapConfusables(const AText: string): string;
var
  LPos, LLen: SizeUInt;
  LDec: TUTF8DecodeResult;
  LProto: array[0..CONFUSABLE_MAX_PROTOTYPE - 1] of TUnicodeCodepoint;
  LProtoLen: Byte;
  I: Integer;
begin
  Result := '';
  LPos := 0;
  LLen := SizeUInt(Length(AText));
  while LPos < LLen do
  begin
    LDec := UTF8Decode(@PByte(PAnsiChar(AText))[LPos], LLen - LPos);
    if LDec.ByteLen = 0 then
    begin
      AppendUtf8Cp(Result, UNICODE_REPLACEMENT);
      Inc(LPos);
      Continue;
    end;
    if GetConfusablePrototype(LDec.CodePoint, LProto, LProtoLen) then
      for I := 0 to Integer(LProtoLen) - 1 do
        AppendUtf8Cp(Result, LProto[I])
    else
      AppendUtf8Cp(Result, LDec.CodePoint);
    Inc(LPos, LDec.ByteLen);
  end;
end;

function ConfusableSkeleton(const AText: string): string;
begin
  if AText = '' then
    Exit('');
  Result := NFD(MapConfusables(NFD(AText)));
end;

function AreConfusable(const A, B: string): Boolean;
begin
  Result := ConfusableSkeleton(A) = ConfusableSkeleton(B);
end;

end.
