program test_conformance_confusables;

{**
 * UTS #39 §4 confusable Unicode conformance harness (Unicode 16.0).
 *
 * Fixture: ../data/confusables.txt (2024-08-14, UTS#39 16.0.0)
 *
 * Data rows (up to the '#' comment) look like:  source ; target ; MA
 * All 6355 rows are MA (also-ignore); prototypes are mapping fixed points.
 *
 * Assertions per row:
 *   (a) GetConfusablePrototype(src) must return exactly the file's
 *       prototype bytes — 0 tolerance. This is the data-integrity proof
 *       that the generated .inc matches the official table.
 *   (b) Predicate self-consistency: the public AreConfusable(src, proto)
 *       and the skeleton equality ConfusableSkeleton(src) =
 *       ConfusableSkeleton(proto) must agree (both directions).
 *
 * NOTE on skeleton equality: UTS#39 internalSkeleton is
 *   NFD -> drop Default_Ignorable -> map each char -> re-NFD.
 * Canonically-decomposable sources (e.g. U+0227 → a + U+0307) lose their
 * single-codepoint table entry after the first NFD pass, so skeleton(src)
 * may legitimately differ from skeleton(prototype) — the map is applied
 * exactly once. This mirrors the official reference (ICU uspoof): e.g.
 * areConfusable("ȧ","å") = false, areConfusable("ǆ","dž") = false, while
 * areConfusable("paypal","раypal") = true. Semantic anchor pairs are
 * cross-checked against ICU in test_confusable.
 *
 * The harness therefore reports the equal/diff counts (deterministic,
 * informative) and hard-fails only on (a) and (b).
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.fs,
  nextpas.core.text,
  nextpas.core.test,
  nextpas.core.text.utf8,
  nextpas.core.text.unicode;

var
  T: TTestSuite;

{$I ../test_helpers.inc}

function TrimWs(const S: string): string;
var
  A, B: SizeInt;
begin
  A := 1;
  B := Length(S);
  while (A <= B) and (S[A] in [' ', #9]) do
    Inc(A);
  while (B >= A) and (S[B] in [' ', #9]) do
    Dec(B);
  Result := Copy(S, A, B - A + 1);
end;

{ Parse a ' '/#9-separated list of hex codepoints into a UTF-8 string.
  Returns False if any token is not valid hex. }
function ParseHexList(const AField: string; out AValue: string): Boolean;
var
  I, LStart, L, LCode: SizeInt;
  LCpVal: UInt32;
  LTok: string;
begin
  Result := True;
  AValue := '';
  I := 1;
  L := Length(AField);
  while I <= L do
  begin
    while (I <= L) and (AField[I] in [' ', #9]) do
      Inc(I);
    if I > L then
      Break;
    LStart := I;
    while (I <= L) and not (AField[I] in [' ', #9]) do
      Inc(I);
    LTok := Copy(AField, LStart, I - LStart);
    Val('$' + LTok, LCpVal, LCode);
    if LCode <> 0 then
      Exit(False);
    AppendUtf8(AValue, LCpVal);
  end;
end;

procedure TestConfusableConformance;
const
  MAX_REPORT = 40;
  MAXLEN = CONFUSABLE_MAX_PROTOTYPE;
var
  LPath, LBody, LLine, LProtoStr, LSrcStr: string;
  LFile: Text;
  LLineNo, LChecked, LFailed, LSame, LDiff, I: Integer;
  LHash, LFieldIdx, LStart: SizeInt;
  LFields: array[0..2] of string;
  LCpVal: UInt32;
  LCode: Integer;
  LBuf: array[0..MAXLEN - 1] of TUnicodeCodepoint;
  LLen: Byte;
  LFound: Boolean;
  LDecoded: string;
  LSkEq, LPrEq: Boolean;

  function skFlag(const AB: Boolean): string;
  begin
    if AB then
      Result := 'T'
    else
      Result := 'F';
  end;

  procedure ReportFail(const AWhat: string);
  begin
    Inc(LFailed);
    if LFailed <= MAX_REPORT then
      WriteLn('  line ', LLineNo, ' [', AWhat, '] src=U+', LFields[0],
        ' proto="', LProtoStr, '"');
  end;

begin
  LPath := ResolveUnicodeFixture('confusables.txt');
  Check(FileExists(LPath), 'fixture exists: ' + LPath);

  Assign(LFile, LPath);
  Reset(LFile);
  LLineNo := 0;
  LChecked := 0;
  LFailed := 0;
  LSame := 0;
  LDiff := 0;
  try
    while not Eof(LFile) do
    begin
      ReadLn(LFile, LLine);
      Inc(LLineNo);

      LBody := LLine;
      LHash := Pos('#', LBody);
      if LHash > 0 then
        LBody := Copy(LBody, 1, LHash - 1);
      if TrimWs(LBody) = '' then
        Continue;

      LFieldIdx := 0;
      LStart := 1;
      for I := 1 to Length(LBody) + 1 do
      begin
        if (I > Length(LBody)) or (LBody[I] = ';') then
        begin
          if LFieldIdx > 2 then
            Break;
          LFields[LFieldIdx] := TrimWs(Copy(LBody, LStart, I - LStart));
          Inc(LFieldIdx);
          LStart := I + 1;
        end;
      end;
      if LFieldIdx < 2 then
        Continue;
      if (LFieldIdx >= 3) and (LFields[2] <> 'MA') then
        Continue;

      { Source must be a single codepoint. }
      Val('$' + LFields[0], LCpVal, LCode);
      if LCode <> 0 then
        Continue; { multi-codepoint source — out of harness scope }

      if not ParseHexList(LFields[1], LProtoStr) or (LProtoStr = '') then
        Continue;

      { Decode the single source codepoint to real UTF-8. }
      LSrcStr := '';
      AppendUtf8(LSrcStr, LCpVal);

      { (a) GetConfusablePrototype must agree with the file exactly. }
      LFound := GetConfusablePrototype(LCpVal, LBuf, LLen);
      LDecoded := '';
      if LFound then
        for I := 0 to Integer(LLen) - 1 do
          AppendUtf8(LDecoded, LBuf[I]);
      if not LFound then
        ReportFail('prototype not found')
      else if LDecoded <> LProtoStr then
        ReportFail('prototype mismatch')
      else
      begin
        Inc(LChecked);
        { (b) predicate and skeleton equality must never contradict. }
        LSkEq := ConfusableSkeleton(LSrcStr) = ConfusableSkeleton(LProtoStr);
        LPrEq := AreConfusable(LSrcStr, LProtoStr);
        if LSkEq <> LPrEq then
          ReportFail(TextFormat('predicate/equality divergence (sk-eq=%s pred=%s)',
            [skFlag(LSkEq), skFlag(LPrEq)]))
        else if LSkEq then
          Inc(LSame)
        else
          Inc(LDiff);
      end;
    end;
  finally
    Close(LFile);
  end;

  WriteLn('  confusables.txt: ', LChecked, ' rows checked, ', LFailed,
    ' failed | skeleton-equal: ', LSame, ' | skeleton-diff: ', LDiff);
  Check(LChecked >= 6350, TextFormat('expected ~6355 rows, got %d', [LChecked]));
  CheckEqual(Int64(0), Int64(LFailed), 'confusables.txt conformance failures');
end;

begin
  T := TTestSuite.Create('nextpas.core.text.unicode.conformance.confusables');
  T.Test('confusables.txt full suite', @TestConfusableConformance);
  if not T.Run then
    Halt(1);
end.