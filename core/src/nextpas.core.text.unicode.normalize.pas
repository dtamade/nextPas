unit nextpas.core.text.unicode.normalize;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.unicode.types,
  nextpas.core.text.unicode.base,
  nextpas.core.text.utf8;

function NFD(const s: string): string;
function NFC(const s: string): string;
function NFKD(const s: string): string;
function NFKC(const s: string): string;
function IsNormalizedNFD(const s: string): Boolean;
function IsNormalizedNFC(const s: string): Boolean;
function IsNormalizedNFKD(const s: string): Boolean;
function IsNormalizedNFKC(const s: string): Boolean;

// 快速检查：返回 True 表示确定已规范化，False 表示可能未规范化
// 比完整规范化快得多，适合"先快速检查再决定是否规范化"的模式
function QuickCheckNFD(const s: string): Boolean;
function QuickCheckNFKD(const s: string): Boolean;
function QuickCheckNFC(const s: string): Boolean;
function QuickCheckNFKC(const s: string): Boolean;

// 获取码点的 Canonical Combining Class (CCC)
// 0 = starter, 1-240 = combining mark ordering
function GetCanonicalCombiningClass(const ACp: TUnicodeCodepoint): Byte;

implementation

uses
  nextpas.core.text.unicode.utils;

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
  // 注意：使用 > 而非 >=，因为 HANGUL_TBASE (U+11A7) 是 filler，
  // 不是真实的 trailing jamo。真实的 T jamo 从 U+11A8 开始。
  // 参见 Unicode Standard 3.12 Hangul Composition。
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
      LCcc := LPrevCcc;  // 移动后继承前一个 CCC，避免下次重复查表
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
        // 组合后重置 LLastCcc：新字符是 starter 的一部分，不是 combining mark
        LLastCcc := 0;
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
  // 先用 QuickCheck 快速判断（O(n) 无分配）
  if QuickCheckNFD(s) then
    Exit(True);
  // QuickCheck 不确定时，回退到完整规范化比较
  Result := NFD(s) = s;
end;

function IsNormalizedNFC(const s: string): Boolean;
begin
  if QuickCheckNFC(s) then
    Exit(True);
  Result := NFC(s) = s;
end;

function IsNormalizedNFKD(const s: string): Boolean;
begin
  if QuickCheckNFKD(s) then
    Exit(True);
  Result := NFKD(s) = s;
end;

function IsNormalizedNFKC(const s: string): Boolean;
begin
  if QuickCheckNFKC(s) then
    Exit(True);
  Result := NFKC(s) = s;
end;

function QuickCheckNFD(const s: string): Boolean;
var
  LIter: TUTF8Iterator;
  LCp: UInt32;
  LPrevCcc: Byte;
  LCcc: Byte;
  LKind: Byte;
begin
  // QuickCheck NFD: 检查是否已经是 NFD 形式
  // 条件：没有规范可分解字符(LKind=1) + combining class 非递减
  // 注意：兼容分解(LKind=2)在 NFD 中是允许的
  if s = '' then
    Exit(True);
  if IsAsciiString(s) then
    Exit(True);

  LPrevCcc := 0;
  LIter.Init(PByte(PAnsiChar(s)), SizeUInt(Length(s)));
  while LIter.Next(LCp) do
  begin
    // 检查是否有规范分解（kind=1）
    LKind := GetDecompositionKind(LCp);
    if LKind = 1 then
      Exit(False); // 有规范可分解字符，不是 NFD

    // 检查 combining class 顺序
    LCcc := GetCanonicalCombiningClass(LCp);
    if (LCcc <> 0) and (LPrevCcc <> 0) and (LCcc < LPrevCcc) then
      Exit(False); // combining class 递减，不是 NFD
    LPrevCcc := LCcc;
  end;
  Result := True;
end;

function QuickCheckNFKD(const s: string): Boolean;
var
  LIter: TUTF8Iterator;
  LCp: UInt32;
  LPrevCcc: Byte;
  LCcc: Byte;
  LKind: Byte;
begin
  // QuickCheck NFKD: 检查是否已经是 NFKD 形式
  // 条件：没有可分解字符(规范或兼容) + combining class 非递减
  if s = '' then
    Exit(True);
  if IsAsciiString(s) then
    Exit(True);

  LPrevCcc := 0;
  LIter.Init(PByte(PAnsiChar(s)), SizeUInt(Length(s)));
  while LIter.Next(LCp) do
  begin
    // 检查是否有任何分解（kind=1 规范 或 kind=2 兼容）
    LKind := GetDecompositionKind(LCp);
    if LKind <> 0 then
      Exit(False);

    // 检查 combining class 顺序
    LCcc := GetCanonicalCombiningClass(LCp);
    if (LCcc <> 0) and (LPrevCcc <> 0) and (LCcc < LPrevCcc) then
      Exit(False);
    LPrevCcc := LCcc;
  end;
  Result := True;
end;

function QuickCheckNFC(const s: string): Boolean;
var
  LIter: TUTF8Iterator;
  LCp: UInt32;
  LPrevCcc: Byte;
  LCcc: Byte;
  LStarter: TUnicodeCodepoint;
  LHasStarter: Boolean;
  LComposed: TUnicodeCodepoint;
begin
  // QuickCheck NFC: 检查是否已经是 NFC 形式
  // 条件：combining class 非递减 + 没有可组合的 starter+combining 对
  if s = '' then
    Exit(True);
  if IsAsciiString(s) then
    Exit(True);

  LPrevCcc := 0;
  LHasStarter := False;
  LStarter := 0;
  LIter.Init(PByte(PAnsiChar(s)), SizeUInt(Length(s)));
  while LIter.Next(LCp) do
  begin
    LCcc := GetCanonicalCombiningClass(LCp);

    // 检查 combining class 顺序
    if (LCcc <> 0) and (LPrevCcc <> 0) and (LCcc < LPrevCcc) then
      Exit(False);

    // 检查是否可以组合
    if LCcc = 0 then
    begin
      // 新的 starter
      LStarter := LCp;
      LHasStarter := True;
    end
    else if LHasStarter then
    begin
      // combining mark: 检查 starter + combining 是否可以组合
      // 条件：前一个 CCC 为 0 或 < 当前 CCC（即 combining mark 未被阻塞）
      if (LPrevCcc = 0) or (LPrevCcc < LCcc) then
      begin
        if FindComposition(LStarter, LCp, LComposed) and (LComposed <> LStarter) then
          Exit(False); // 可以组合但没有组合，不是 NFC
      end;
    end;

    LPrevCcc := LCcc;
  end;
  Result := True;
end;

function QuickCheckNFKC(const s: string): Boolean;
var
  LIter: TUTF8Iterator;
  LCp: UInt32;
  LPrevCcc: Byte;
  LCcc: Byte;
  LKind: Byte;
  LStarter: TUnicodeCodepoint;
  LHasStarter: Boolean;
  LComposed: TUnicodeCodepoint;
begin
  // QuickCheck NFKC: 检查是否已经是 NFKC 形式
  // 条件：无兼容分解(kind=2) + combining class 非递减 + 无可组合 starter+combining 对
  if s = '' then
    Exit(True);
  if IsAsciiString(s) then
    Exit(True);

  LPrevCcc := 0;
  LHasStarter := False;
  LStarter := 0;
  LIter.Init(PByte(PAnsiChar(s)), SizeUInt(Length(s)));
  while LIter.Next(LCp) do
  begin
    // 检查是否有兼容分解（kind=2）
    LKind := GetDecompositionKind(LCp);
    if LKind = 2 then
      Exit(False); // 有兼容分解字符，不是 NFKC

    LCcc := GetCanonicalCombiningClass(LCp);

    // 检查 combining class 顺序
    if (LCcc <> 0) and (LPrevCcc <> 0) and (LCcc < LPrevCcc) then
      Exit(False);

    // 检查是否可以组合
    if LCcc = 0 then
    begin
      LStarter := LCp;
      LHasStarter := True;
    end
    else if LHasStarter then
    begin
      if (LPrevCcc = 0) or (LPrevCcc < LCcc) then
      begin
        if FindComposition(LStarter, LCp, LComposed) and (LComposed <> LStarter) then
          Exit(False);
      end;
    end;

    LPrevCcc := LCcc;
  end;
  Result := True;
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
