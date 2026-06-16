unit nextpas.core.text.unicode.normalize;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.unicode.base,
  nextpas.core.text.utf8;

function NFD(const s: string): string;
function NFC(const s: string): string;
function NFKD(const s: string): string;
function NFKC(const s: string): string;
function IsNormalizedNFD(const s: string): Boolean;
function IsNormalizedNFC(const s: string): Boolean;

implementation

{$I nextpas.core.text.unicode.normalize.inc}

const
  HANGUL_SBASE = TUnicodeCodepoint($AC00);
  HANGUL_LBASE = TUnicodeCodepoint($1100);
  HANGUL_VBASE = TUnicodeCodepoint($1161);
  HANGUL_TBASE = TUnicodeCodepoint($11A7);
  HANGUL_LCOUNT = 19;
  HANGUL_VCOUNT = 21;
  HANGUL_TCOUNT = 28;
  HANGUL_NCOUNT = HANGUL_VCOUNT * HANGUL_TCOUNT;
  HANGUL_SCOUNT = HANGUL_LCOUNT * HANGUL_NCOUNT;

type
  TCodepointBuffer = record
  private
    FItems: array of TUnicodeCodepoint;
    FCount: SizeInt;
  public
    procedure Clear;
    procedure Reserve(const ARequired: SizeInt);
    procedure Append(const ACp: TUnicodeCodepoint);
    procedure ReplaceAt(const AIndex: SizeInt; const ACp: TUnicodeCodepoint);
    procedure DeleteAt(const AIndex: SizeInt);
    function ItemAt(const AIndex: SizeInt): TUnicodeCodepoint;
    property Count: SizeInt read FCount;
  end;

function IsAsciiString(const AValue: string): Boolean;
var
  LIdx: SizeInt;
begin
  for LIdx := 1 to Length(AValue) do
    if Ord(AValue[LIdx]) > $7F then
      Exit(False);
  Result := True;
end;

procedure EnsureOutputCapacity(var AValue: string; const ARequired: SizeInt);
var
  LCapacity: SizeInt;
begin
  if Length(AValue) >= ARequired then
    Exit;

  LCapacity := Length(AValue);
  if LCapacity < 32 then
    LCapacity := 32;
  while LCapacity < ARequired do
    LCapacity := LCapacity * 2;
  SetLength(AValue, LCapacity);
end;

procedure AppendUtf8Codepoint(var ADst: string; var AUsed: SizeInt; const ACp: TUnicodeCodepoint);
var
  LBuf: array[0..3] of Byte;
  LLen: Byte;
  LIdx: Byte;
begin
  LLen := UTF8Encode(ACp, @LBuf[0]);
  if LLen = 0 then
    LLen := UTF8Encode($FFFD, @LBuf[0]);

  EnsureOutputCapacity(ADst, AUsed + LLen);
  for LIdx := 0 to LLen - 1 do
    ADst[AUsed + LIdx + 1] := AnsiChar(LBuf[LIdx]);
  Inc(AUsed, LLen);
end;

function IsHangulSyllable(const ACp: TUnicodeCodepoint): Boolean; inline;
begin
  Result := (ACp >= HANGUL_SBASE) and (ACp < (HANGUL_SBASE + HANGUL_SCOUNT));
end;

function IsHangulL(const ACp: TUnicodeCodepoint): Boolean; inline;
begin
  Result := (ACp >= HANGUL_LBASE) and (ACp < (HANGUL_LBASE + HANGUL_LCOUNT));
end;

function IsHangulV(const ACp: TUnicodeCodepoint): Boolean; inline;
begin
  Result := (ACp >= HANGUL_VBASE) and (ACp < (HANGUL_VBASE + HANGUL_VCOUNT));
end;

function IsHangulT(const ACp: TUnicodeCodepoint): Boolean; inline;
begin
  Result := (ACp > HANGUL_TBASE) and (ACp < (HANGUL_TBASE + HANGUL_TCOUNT));
end;

function IsHangulLV(const ACp: TUnicodeCodepoint): Boolean; inline;
begin
  Result := IsHangulSyllable(ACp) and (((ACp - HANGUL_SBASE) mod HANGUL_TCOUNT) = 0);
end;

procedure AppendHangulDecomposition(var ABuffer: TCodepointBuffer; const ACp: TUnicodeCodepoint);
var
  LSIndex: TUnicodeCodepoint;
  LLPart: TUnicodeCodepoint;
  LVPart: TUnicodeCodepoint;
  LTPart: TUnicodeCodepoint;
begin
  LSIndex := ACp - HANGUL_SBASE;
  LLPart := HANGUL_LBASE + (LSIndex div HANGUL_NCOUNT);
  LVPart := HANGUL_VBASE + ((LSIndex mod HANGUL_NCOUNT) div HANGUL_TCOUNT);
  LTPart := HANGUL_TBASE + (LSIndex mod HANGUL_TCOUNT);
  ABuffer.Append(LLPart);
  ABuffer.Append(LVPart);
  if LTPart <> HANGUL_TBASE then
    ABuffer.Append(LTPart);
end;

function GetDecompositionKind(const ACp: TUnicodeCodepoint): Byte;
var
  LValue: Byte;
begin
  if ACp <= $FFFF then
    if FindRange3Value(ACp, DECOMP_BMP_RANGES, LValue) then
      Exit(LValue);

  if FindRange3Value(ACp, DECOMP_SMP_RANGES, LValue) then
    Exit(LValue);

  Result := 0;
end;

function FindDecomposition(const ACp: TUnicodeCodepoint; out AEntry: TDecompEntry): Boolean;
var
  LLo: SizeInt;
  LHi: SizeInt;
  LMid: SizeInt;
begin
  if ACp <= $FFFF then
  begin
    LLo := 0;
    LHi := High(DECOMP_BMP_MAP);
    while LLo <= LHi do
    begin
      LMid := LLo + ((LHi - LLo) div 2);
      if ACp < DECOMP_BMP_MAP[LMid].Cp then
        LHi := LMid - 1
      else if ACp > DECOMP_BMP_MAP[LMid].Cp then
        LLo := LMid + 1
      else
      begin
        AEntry := DECOMP_BMP_MAP[LMid];
        Exit(True);
      end;
    end;
  end
  else
  begin
    LLo := 0;
    LHi := High(DECOMP_SMP_MAP);
    while LLo <= LHi do
    begin
      LMid := LLo + ((LHi - LLo) div 2);
      if ACp < DECOMP_SMP_MAP[LMid].Cp then
        LHi := LMid - 1
      else if ACp > DECOMP_SMP_MAP[LMid].Cp then
        LLo := LMid + 1
      else
      begin
        AEntry := DECOMP_SMP_MAP[LMid];
        Exit(True);
      end;
    end;
  end;

  Result := False;
end;

function GetCanonicalCombiningClass(const ACp: TUnicodeCodepoint): Byte;
var
  LValue: Byte;
begin
  if ACp <= $FFFF then
    Exit(CCC_TABLE[Byte(ACp shr 8), Byte(ACp and $FF)]);

  if FindRange3Value(ACp, CCC_SMP_RANGES, LValue) then
    Exit(LValue);

  Result := 0;
end;

function FindComposition(const AStarter, ACombining: TUnicodeCodepoint; out AResult: TUnicodeCodepoint): Boolean;
var
  LLo: SizeInt;
  LHi: SizeInt;
  LMid: SizeInt;
begin
  LLo := 0;
  LHi := High(COMPOSE_TABLE);
  while LLo <= LHi do
  begin
    LMid := LLo + ((LHi - LLo) div 2);
    if AStarter < COMPOSE_TABLE[LMid].Starter then
      LHi := LMid - 1
    else if AStarter > COMPOSE_TABLE[LMid].Starter then
      LLo := LMid + 1
    else if ACombining < COMPOSE_TABLE[LMid].Combining then
      LHi := LMid - 1
    else if ACombining > COMPOSE_TABLE[LMid].Combining then
      LLo := LMid + 1
    else
    begin
      AResult := COMPOSE_TABLE[LMid].ResultCp;
      Exit(True);
    end;
  end;
  Result := False;
end;

procedure SortCanonicalOrder(var ABuffer: TCodepointBuffer; const AStartIndex: SizeInt);
var
  LIdx: SizeInt;
  LPos: SizeInt;
  LCp: TUnicodeCodepoint;
  LCcc: Byte;
  LPrevCcc: Byte;
begin
  if ABuffer.Count - AStartIndex < 2 then
    Exit;

  for LIdx := AStartIndex + 1 to ABuffer.Count - 1 do
  begin
    LCp := ABuffer.ItemAt(LIdx);
    LCcc := GetCanonicalCombiningClass(LCp);
    if LCcc = 0 then
      Continue;

    LPos := LIdx;
    while LPos > AStartIndex do
    begin
      LPrevCcc := GetCanonicalCombiningClass(ABuffer.ItemAt(LPos - 1));
      if (LPrevCcc = 0) or (LPrevCcc <= LCcc) then
        Break;
      ABuffer.ReplaceAt(LPos, ABuffer.ItemAt(LPos - 1));
      Dec(LPos);
    end;
    ABuffer.ReplaceAt(LPos, LCp);
  end;
end;

procedure AppendDecomposition(
  var ABuffer: TCodepointBuffer;
  const ACp: TUnicodeCodepoint;
  const ACompatibility: Boolean
);
var
  LKind: Byte;
  LEntry: TDecompEntry;
  LIdx: Byte;
begin
  if IsHangulSyllable(ACp) then
  begin
    AppendHangulDecomposition(ABuffer, ACp);
    Exit;
  end;

  LKind := GetDecompositionKind(ACp);
  if (LKind = 0) or ((LKind = 2) and (not ACompatibility)) then
  begin
    ABuffer.Append(ACp);
    Exit;
  end;

  if not FindDecomposition(ACp, LEntry) then
  begin
    ABuffer.Append(ACp);
    Exit;
  end;

  for LIdx := 0 to LEntry.Len - 1 do
    AppendDecomposition(ABuffer, LEntry.Map[LIdx], ACompatibility);
end;

procedure DecomposeToBuffer(const AValue: string; const ACompatibility: Boolean; var ABuffer: TCodepointBuffer);
var
  LIter: TUTF8Iterator;
  LCp: UInt32;
  LAppendStart: SizeInt;
  LSortStart: SizeInt;
begin
  ABuffer.Clear;
  LSortStart := 0;
  LIter.Init(PByte(PAnsiChar(AValue)), SizeUInt(Length(AValue)));
  while LIter.Next(LCp) do
  begin
    LAppendStart := ABuffer.Count;
    AppendDecomposition(ABuffer, LCp, ACompatibility);
    if ABuffer.Count = LAppendStart then
      Continue;

    if GetCanonicalCombiningClass(ABuffer.ItemAt(LAppendStart)) = 0 then
      LSortStart := LAppendStart + 1;
    SortCanonicalOrder(ABuffer, LSortStart);
  end;
end;

function BufferToUtf8(const ABuffer: TCodepointBuffer): string;
var
  LUsed: SizeInt;
  LIdx: SizeInt;
begin
  SetLength(Result, ABuffer.Count * 4);
  LUsed := 0;
  for LIdx := 0 to ABuffer.Count - 1 do
    AppendUtf8Codepoint(Result, LUsed, ABuffer.ItemAt(LIdx));
  SetLength(Result, LUsed);
end;

function ComposeHangulPair(const AStarter, ACurrent: TUnicodeCodepoint; out AComposed: TUnicodeCodepoint): Boolean;
var
  LLIndex: TUnicodeCodepoint;
  LVIndex: TUnicodeCodepoint;
  LTIndex: TUnicodeCodepoint;
begin
  if IsHangulL(AStarter) and IsHangulV(ACurrent) then
  begin
    LLIndex := AStarter - HANGUL_LBASE;
    LVIndex := ACurrent - HANGUL_VBASE;
    AComposed := HANGUL_SBASE + ((LLIndex * HANGUL_VCOUNT) + LVIndex) * HANGUL_TCOUNT;
    Exit(True);
  end;

  if IsHangulLV(AStarter) and IsHangulT(ACurrent) then
  begin
    LTIndex := ACurrent - HANGUL_TBASE;
    AComposed := AStarter + LTIndex;
    Exit(True);
  end;

  Result := False;
end;

procedure ComposeBufferWithHangul(var ABuffer: TCodepointBuffer);
var
  LStarterIndex: SizeInt;
  LLookahead: SizeInt;
  LLastCcc: Byte;
  LCcc: Byte;
  LCurrent: TUnicodeCodepoint;
  LComposed: TUnicodeCodepoint;
begin
  if ABuffer.Count = 0 then
    Exit;

  LStarterIndex := 0;
  while LStarterIndex < ABuffer.Count do
  begin
    if GetCanonicalCombiningClass(ABuffer.ItemAt(LStarterIndex)) <> 0 then
    begin
      Inc(LStarterIndex);
      Continue;
    end;

    LLookahead := LStarterIndex + 1;
    LLastCcc := 0;
    while LLookahead < ABuffer.Count do
    begin
      LCurrent := ABuffer.ItemAt(LLookahead);
      LCcc := GetCanonicalCombiningClass(LCurrent);
      if LCcc = 0 then
        Break;

      if ComposeHangulPair(ABuffer.ItemAt(LStarterIndex), LCurrent, LComposed) or
         (FindComposition(ABuffer.ItemAt(LStarterIndex), LCurrent, LComposed) and
          ((LLastCcc = 0) or (LLastCcc < LCcc))) then
      begin
        ABuffer.ReplaceAt(LStarterIndex, LComposed);
        ABuffer.DeleteAt(LLookahead);
        Continue;
      end;

      LLastCcc := LCcc;
      Inc(LLookahead);
    end;

    if (LLookahead < ABuffer.Count) and (GetCanonicalCombiningClass(ABuffer.ItemAt(LLookahead)) = 0) then
    begin
      if ComposeHangulPair(ABuffer.ItemAt(LStarterIndex), ABuffer.ItemAt(LLookahead), LComposed) then
      begin
        ABuffer.ReplaceAt(LStarterIndex, LComposed);
        ABuffer.DeleteAt(LLookahead);
        Continue;
      end;
    end;

    Inc(LStarterIndex);
  end;
end;

function NormalizeDecomposed(const s: string; const ACompatibility: Boolean): string;
var
  LBuffer: TCodepointBuffer;
begin
  if s = '' then
    Exit('');
  if IsAsciiString(s) then
    Exit(s);

  DecomposeToBuffer(s, ACompatibility, LBuffer);
  Result := BufferToUtf8(LBuffer);
end;

function NormalizeComposed(const s: string; const ACompatibility: Boolean): string;
var
  LBuffer: TCodepointBuffer;
begin
  if s = '' then
    Exit('');
  if IsAsciiString(s) then
    Exit(s);

  DecomposeToBuffer(s, ACompatibility, LBuffer);
  ComposeBufferWithHangul(LBuffer);
  Result := BufferToUtf8(LBuffer);
end;

function NFD(const s: string): string;
begin
  Result := NormalizeDecomposed(s, False);
end;

function NFC(const s: string): string;
begin
  Result := NormalizeComposed(s, False);
end;

function NFKD(const s: string): string;
begin
  Result := NormalizeDecomposed(s, True);
end;

function NFKC(const s: string): string;
begin
  Result := NormalizeComposed(s, True);
end;

function IsNormalizedNFD(const s: string): Boolean;
begin
  Result := NFD(s) = s;
end;

function IsNormalizedNFC(const s: string): Boolean;
begin
  Result := NFC(s) = s;
end;

{ TCodepointBuffer }

procedure TCodepointBuffer.Clear;
begin
  FCount := 0;
end;

procedure TCodepointBuffer.Reserve(const ARequired: SizeInt);
var
  LCapacity: SizeInt;
begin
  if Length(FItems) >= ARequired then
    Exit;

  LCapacity := Length(FItems);
  if LCapacity < 32 then
    LCapacity := 32;
  while LCapacity < ARequired do
    LCapacity := LCapacity * 2;
  SetLength(FItems, LCapacity);
end;

procedure TCodepointBuffer.Append(const ACp: TUnicodeCodepoint);
begin
  Reserve(FCount + 1);
  FItems[FCount] := ACp;
  Inc(FCount);
end;

procedure TCodepointBuffer.ReplaceAt(const AIndex: SizeInt; const ACp: TUnicodeCodepoint);
begin
  FItems[AIndex] := ACp;
end;

procedure TCodepointBuffer.DeleteAt(const AIndex: SizeInt);
var
  LIdx: SizeInt;
begin
  for LIdx := AIndex to FCount - 2 do
    FItems[LIdx] := FItems[LIdx + 1];
  Dec(FCount);
end;

function TCodepointBuffer.ItemAt(const AIndex: SizeInt): TUnicodeCodepoint;
begin
  Result := FItems[AIndex];
end;

end.
