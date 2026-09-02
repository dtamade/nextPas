unit nextpas.core.text.unicode.punycode;

{**
 * RFC 3492 Punycode (bootstring) for IDNA labels.
 * Encode Unicode codepoint sequences to ACE (ASCII Compatible Encoding).
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.unicode.types;

{ Encode Unicode codepoints to Punycode ASCII (no xn-- prefix).
  Returns empty string on failure. }
function PunycodeEncodeCodepoints(const ACps: array of TUnicodeCodepoint;
  const ACount: SizeInt): string;

{ Decode Punycode ASCII (no xn-- prefix) to codepoints.
  Returns count written to ADst; 0 on failure. }
function PunycodeDecodeToCodepoints(const AAscii: string;
  out ADst: array of TUnicodeCodepoint; out ACount: SizeInt): Boolean;

{ Encode UTF-8 string label (no dots) to Punycode without prefix. }
function PunycodeEncode(const ALabel: string): string;

{ Decode Punycode without xn-- to UTF-8 string. }
function PunycodeDecode(const AAscii: string): string;

implementation

uses
  nextpas.core.text.utf8,
  nextpas.core.bytes.ops;

const
  BASE = 36;
  TMIN = 1;
  TMAX = 26;
  SKEW = 38;
  DAMP = 700;
  INITIAL_BIAS = 72;
  INITIAL_N = 128;
  DELIMITER = '-';

function Adapt(Delta, NumPoints: Int64; FirstTime: Boolean): Int64;
var
  K: Int64;
begin
  if FirstTime then
    Delta := Delta div DAMP
  else
    Delta := Delta div 2;
  Inc(Delta, Delta div NumPoints);
  K := 0;
  while Delta > ((BASE - TMIN) * TMAX) div 2 do
  begin
    Delta := Delta div (BASE - TMIN);
    Inc(K, BASE);
  end;
  Result := K + ((BASE - TMIN + 1) * Delta) div (Delta + SKEW);
end;

function DigitEncode(D: Int64): Char; inline;
begin
  // inline tiny: register only, no alloc; hot path encodes many digits
  if D < 26 then
    Result := Chr(Ord('a') + Integer(D))
  else
    Result := Chr(Ord('0') + Integer(D - 26));
end;

function DigitDecode(C: Char): Integer;
begin
  case C of
    'A'..'Z': Result := Ord(C) - Ord('A');
    'a'..'z': Result := Ord(C) - Ord('a');
    '0'..'9': Result := Ord(C) - Ord('0') + 26;
  else
    Result := -1;
  end;
end;

function PunycodeEncodeCodepoints(const ACps: array of TUnicodeCodepoint;
  const ACount: SizeInt): string;
var
  N, Delta, Bias, H, B, M, Q, K, T: Int64;
  { i386 的 for 不接受 Int64 控制变量；循环界即数组长度域，SizeInt 等价 }
  CI: SizeInt;
  Handled: array of Boolean;
  AllBasic: Boolean;
  LBuf: string;
  LLen, LCap: SizeInt;
  procedure GrowCap(const ANeeded: SizeInt);
  var
    LReq, LNewCap: SizeUInt;
  begin
    // not inline per red-line 2: while loop in BytesGrowCapacity would bloat I-Cache; single source geometric via bytes.ops
    if ANeeded <= 0 then Exit;
    if LLen + ANeeded <= LCap then Exit;
    LReq := SizeUInt(LLen + ANeeded);
    LNewCap := nextpas.core.bytes.ops.BytesGrowCapacity(SizeUInt(LCap), LReq);
    SetLength(LBuf, LNewCap);
    LCap := SizeInt(LNewCap);
  end;
  procedure AppendCharInline(const ACh: Char); inline;
  begin
    // inline hot path: single char store zero-copy, no Move; capacity check delegates to bytes.ops single source
    if LLen >= LCap then
      GrowCap(1);
    LBuf[LLen + 1] := ACh;
    Inc(LLen);
  end;
begin
  Result := '';
  if ACount <= 0 then
    Exit;
  SetLength(Handled, ACount);
  B := 0;
  AllBasic := True;
  for CI := 0 to ACount - 1 do
  begin
    if ACps[CI] < $80 then
    begin
      Inc(B);
      Handled[CI] := True;
    end
    else
    begin
      Handled[CI] := False;
      AllBasic := False;
    end;
  end;
  if AllBasic then
  begin
    // single SetLength+Move zero-copy O(n) not O(n²); pure ASCII identity
    SetLength(Result, B);
    if B > 0 then
      for CI := 0 to ACount - 1 do
        Result[CI + 1] := Chr(ACps[CI]);
    Exit;
  end;

  // perf: preallocated buffer via bytes.ops.BytesGrowCapacity single source geometric amortized O(1)
  // hot AppendCharInline inline single Move zero-copy; GrowCap not inline per red-line 2; final single SetLength trim not inline
  LLen := 0;
  if B > 0 then
    LCap := B + 1 + (ACount - B) * 6
  else
    LCap := (ACount - B) * 6;
  if LCap < 16 then
    LCap := 16;
  SetLength(LBuf, LCap);
  for CI := 0 to ACount - 1 do
    if ACps[CI] < $80 then
      AppendCharInline(Chr(ACps[CI]));
  if B > 0 then
    AppendCharInline(DELIMITER);

  N := INITIAL_N;
  Delta := 0;
  Bias := INITIAL_BIAS;
  H := B;

  while H < ACount do
  begin
    M := $10FFFF;
    for CI := 0 to ACount - 1 do
      if (not Handled[CI]) and (ACps[CI] >= N) and (ACps[CI] < M) then
        M := ACps[CI];
    if M - N > (High(Int64) - Delta) div (H + 1) then
    begin
      SetLength(LBuf, 0);
      Exit('');
    end;
    Inc(Delta, (M - N) * (H + 1));
    N := M;
    for CI := 0 to ACount - 1 do
    begin
      if ACps[CI] < N then
      begin
        Inc(Delta);
        if Delta = 0 then
        begin
          SetLength(LBuf, 0);
          Exit('');
        end;
      end;
      if ACps[CI] = N then
      begin
        Q := Delta;
        K := BASE;
        while True do
        begin
          if K <= Bias then
            T := TMIN
          else if K >= Bias + TMAX then
            T := TMAX
          else
            T := K - Bias;
          if Q < T then
            Break;
          AppendCharInline(DigitEncode(T + ((Q - T) mod (BASE - T))));
          Q := (Q - T) div (BASE - T);
          Inc(K, BASE);
        end;
        AppendCharInline(DigitEncode(Q));
        Bias := Adapt(Delta, H + 1, H = B);
        Delta := 0;
        Inc(H);
        Handled[CI] := True;
      end;
    end;
    Inc(Delta);
    Inc(N);
  end;
  // single SetLength trim to logical length; zero-copy view until here, stability managed string (no leak)
  SetLength(LBuf, LLen);
  Result := LBuf;
end;

function PunycodeDecodeToCodepoints(const AAscii: string;
  out ADst: array of TUnicodeCodepoint; out ACount: SizeInt): Boolean;
var
  N, I, Bias, W, K, Digit, T, OldI, InputLen: Int64;
  Output: array of TUnicodeCodepoint;
  OutLen, BasicLen, J, InPos: SizeInt;
  LastDelim: SizeInt;
  C: Char;
begin
  ACount := 0;
  Result := False;
  InputLen := Length(AAscii);
  if InputLen = 0 then
  begin
    Result := True;
    Exit;
  end;
  for J := 1 to InputLen do
  begin
    C := AAscii[J];
    if not (C in ['A'..'Z', 'a'..'z', '0'..'9', '-']) then
      Exit(False);
  end;

  LastDelim := 0;
  for J := 1 to InputLen do
    if AAscii[J] = DELIMITER then
      LastDelim := J;

  SetLength(Output, InputLen + 16);
  OutLen := 0;
  if LastDelim > 0 then
  begin
    BasicLen := LastDelim - 1;
    for J := 1 to BasicLen do
    begin
      if Ord(AAscii[J]) >= $80 then
        Exit(False);
      if OutLen >= Length(Output) then
        SetLength(Output, Length(Output) * 2);
      Output[OutLen] := Ord(AAscii[J]);
      Inc(OutLen);
    end;
    InPos := LastDelim + 1;
  end
  else
    InPos := 1;

  N := INITIAL_N;
  I := 0;
  Bias := INITIAL_BIAS;

  while InPos <= InputLen do
  begin
    OldI := I;
    W := 1;
    K := BASE;
    while True do
    begin
      if InPos > InputLen then
        Exit(False);
      Digit := DigitDecode(AAscii[InPos]);
      Inc(InPos);
      if Digit < 0 then
        Exit(False);
      if Digit > (High(Int64) - I) div W then
        Exit(False);
      Inc(I, Digit * W);
      if K <= Bias then
        T := TMIN
      else if K >= Bias + TMAX then
        T := TMAX
      else
        T := K - Bias;
      if Digit < T then
        Break;
      if W > High(Int64) div (BASE - T) then
        Exit(False);
      W := W * (BASE - T);
      Inc(K, BASE);
    end;
    Bias := Adapt(I - OldI, OutLen + 1, OldI = 0);
    if I div (OutLen + 1) > High(Int64) - N then
      Exit(False);
    Inc(N, I div (OutLen + 1));
    I := I mod (OutLen + 1);
    if OutLen >= Length(Output) then
      SetLength(Output, Length(Output) * 2);
    { insert N at position I }
    for J := OutLen downto I + 1 do
      Output[J] := Output[J - 1];
    Output[I] := TUnicodeCodepoint(N);
    Inc(OutLen);
    Inc(I);
  end;

  if OutLen > Length(ADst) then
    Exit(False);
  for J := 0 to OutLen - 1 do
    ADst[J] := Output[J];
  ACount := OutLen;
  Result := True;
end;

function PunycodeEncode(const ALabel: string): string;
var
  LCps: array of TUnicodeCodepoint;
  LCount: SizeInt;
  LIter: TUTF8Iterator;
  LCp: UInt32;
begin
  LCount := 0;
  SetLength(LCps, Length(ALabel) + 4);
  LIter.Init(PByte(PAnsiChar(ALabel)), SizeUInt(Length(ALabel)));
  while LIter.Next(LCp) do
  begin
    if LCount >= Length(LCps) then
      SetLength(LCps, Length(LCps) * 2);
    LCps[LCount] := LCp;
    Inc(LCount);
  end;
  Result := PunycodeEncodeCodepoints(LCps, LCount);
end;

function PunycodeDecode(const AAscii: string): string;
var
  LCps: array[0..255] of TUnicodeCodepoint;
  LCount, I, LUsed: SizeInt;
  LBuf: array[0..3] of Byte;
  LLen: Byte;
  J: Integer;
begin
  Result := '';
  if not PunycodeDecodeToCodepoints(AAscii, LCps, LCount) then
    Exit;
  SetLength(Result, LCount * 4 + 4);
  LUsed := 0;
  for I := 0 to LCount - 1 do
  begin
    LLen := UTF8Encode(LCps[I], @LBuf[0]);
    if LLen = 0 then
    begin
      Result := '';
      Exit;
    end;
    if LUsed + LLen > Length(Result) then
      SetLength(Result, (LUsed + LLen) * 2);
    for J := 0 to Integer(LLen) - 1 do
      Result[LUsed + J + 1] := Chr(LBuf[J]);
    Inc(LUsed, LLen);
  end;
  SetLength(Result, LUsed);
end;

end.
