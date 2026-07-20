unit nextpas.core.text.unicode.normalize;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.unicode.types,
  nextpas.core.text.unicode.base,
  nextpas.core.text.utf8;

function NFD(const AText: string): string;
function NFC(const AText: string): string;
function NFKD(const AText: string): string;
function NFKC(const AText: string): string;
function IsNormalizedNFD(const AText: string): Boolean;
function IsNormalizedNFC(const AText: string): Boolean;
function IsNormalizedNFKD(const AText: string): Boolean;
function IsNormalizedNFKC(const AText: string): Boolean;

// 快速检查：返回 True 表示确定已规范化，False 表示可能未规范化
// 比完整规范化快得多，适合"先快速检查再决定是否规范化"的模式
function QuickCheckNFD(const AText: string): Boolean;
function QuickCheckNFKD(const AText: string): Boolean;
function QuickCheckNFC(const AText: string): Boolean;
function QuickCheckNFKC(const AText: string): Boolean;

// 获取码点的 Canonical Combining Class (CCC)
// 0 = starter, 1-240 = combining mark ordering
function GetCanonicalCombiningClass(const ACp: TUnicodeCodepoint): Byte;

// 获取码点的分解映射
// 返回分解长度 (0=无分解, 1=自身, 2+=分解序列)
// AIsCompatibility=True 表示兼容性分解 (NFKC/NFKD 使用)
function GetDecompositionMapping(const ACp: TUnicodeCodepoint;
  out ADst: array of TUnicodeCodepoint; out ALen: Byte;
  out AIsCompatibility: Boolean): Boolean;

// 检查码点是否是组合排除 (Full_Composition_Exclusion)
// 被排除的码点不会在 NFC 组合阶段被生成
function IsCompositionExcluded(const ACp: TUnicodeCodepoint): Boolean;

implementation

uses
  nextpas.core.text.unicode.utils;

{$I nextpas.core.text.unicode.normalize.inc}
{$I nextpas.core.text.unicode.normalize_bmp_index.inc}

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
    function ItemAt(const AIndex: SizeInt): TUnicodeCodepoint; inline;
    procedure SetCount(const ACount: SizeInt); inline;
    property Count: SizeInt read FCount;
  end;

threadvar
  GNormBuffer: TCodepointBuffer;

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
    Exit(DECOMP_KIND_BMP[Byte(ACp shr 8), Byte(ACp and $FF)]);

  if FindRange3Value(ACp, DECOMP_SMP_RANGES, LValue) then
    Exit(LValue);

  Result := 0;
end;

function FindDecomposition(const ACp: TUnicodeCodepoint; out AEntry: TDecompEntry): Boolean;
var
  LLo: SizeInt;
  LHi: SizeInt;
  LMid: SizeInt;
  LIdx: Int32;
begin
  if ACp <= $FFFF then
  begin
    LIdx := DECOMP_BMP_INDEX[Byte(ACp shr 8), Byte(ACp and $FF)];
    if LIdx >= 0 then
    begin
      AEntry := DECOMP_BMP_MAP[LIdx];
      Exit(True);
    end;
    Exit(False);
  end;

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

function GetDecompositionMapping(const ACp: TUnicodeCodepoint;
  out ADst: array of TUnicodeCodepoint; out ALen: Byte;
  out AIsCompatibility: Boolean): Boolean;
var
  LEntry: TDecompEntry;
  LKind: Byte;
  LI: Byte;
begin
  LKind := GetDecompositionKind(ACp);
  if LKind = 0 then
  begin
    ALen := 0;
    AIsCompatibility := False;
    Exit(False);
  end;

  AIsCompatibility := LKind = 2;
  if FindDecomposition(ACp, LEntry) then
  begin
    ALen := LEntry.Len;
    for LI := 0 to LEntry.Len - 1 do
      if LI <= High(ADst) then
        ADst[LI] := LEntry.Map[LI];
    Exit(True);
  end;

  // 无映射表项但有 kind 值：自身即规范形式
  ALen := 1;
  ADst[0] := ACp;
  Result := True;
end;

function IsCompositionExcluded(const ACp: TUnicodeCodepoint): Boolean;
var
  LKind: Byte;
  LEntry: TDecompEntry;
  LFirstCCC: Byte;
begin
  // 有兼容性分解的码点总是被排除
  LKind := GetDecompositionKind(ACp);
  if LKind = 2 then
    Exit(True);

  // 单例分解（canonical 分解到单个码点）= excluded
  if LKind = 1 then
  begin
    if FindDecomposition(ACp, LEntry) then
    begin
      if LEntry.Len = 1 then
        Exit(True);  // singleton
      // 非 starter 分解（分解序列首码点 CCC > 0）= excluded
      LFirstCCC := GetCanonicalCombiningClass(LEntry.Map[0]);
      if LFirstCCC > 0 then
        Exit(True);
    end;
  end;

  // Hangul 音节和 Jamo 不参与表组合（有独立组合逻辑）
  if (ACp >= HANGUL_SBASE) and (ACp < HANGUL_SBASE + HANGUL_SCOUNT) then
    Exit(True);
  if (ACp >= HANGUL_LBASE) and (ACp < HANGUL_LBASE + HANGUL_LCOUNT) then
    Exit(True);
  if (ACp >= HANGUL_VBASE) and (ACp < HANGUL_VBASE + HANGUL_VCOUNT) then
    Exit(True);
  if (ACp >= HANGUL_TBASE) and (ACp < HANGUL_TBASE + HANGUL_TCOUNT) then
    Exit(True);

  Result := False;
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
  LCccs: array[0..255] of Byte;
  LCccsDyn: array of Byte;
  PCcc: PByte;
  LJ: SizeInt;
  LCount: SizeInt;
begin
  LCount := ABuffer.Count;
  if LCount - AStartIndex < 2 then
    Exit;

  if LCount <= 256 then
    PCcc := @LCccs[0]
  else
  begin
    SetLength(LCccsDyn, LCount);
    PCcc := @LCccsDyn[0];
  end;

  for LJ := AStartIndex to LCount - 1 do
    PCcc[LJ] := GetCanonicalCombiningClass(ABuffer.ItemAt(LJ));

  for LIdx := AStartIndex + 1 to LCount - 1 do
  begin
    LCp := ABuffer.ItemAt(LIdx);
    LCcc := PCcc[LIdx];
    if LCcc = 0 then
      Continue;

    LPos := LIdx;
    while LPos > AStartIndex do
    begin
      LPrevCcc := PCcc[LPos - 1];
      if (LPrevCcc = 0) or (LPrevCcc <= LCcc) then
        Break;
      ABuffer.ReplaceAt(LPos, ABuffer.ItemAt(LPos - 1));
      PCcc[LPos] := PCcc[LPos - 1];
      Dec(LPos);
    end;
    ABuffer.ReplaceAt(LPos, LCp);
    PCcc[LPos] := LCcc;
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

  { Fast path: single-level expansion (common for Latin precomposed) }
  if LEntry.Len = 2 then
  begin
    if (GetDecompositionKind(LEntry.Map[0]) = 0) and
       ((GetDecompositionKind(LEntry.Map[1]) = 0) or
        ((GetDecompositionKind(LEntry.Map[1]) = 2) and (not ACompatibility))) then
    begin
      ABuffer.Append(LEntry.Map[0]);
      ABuffer.Append(LEntry.Map[1]);
      Exit;
    end;
  end
  else if LEntry.Len = 1 then
  begin
    if GetDecompositionKind(LEntry.Map[0]) = 0 then
    begin
      ABuffer.Append(LEntry.Map[0]);
      Exit;
    end;
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
  { UTF-8 length upper-bounds codepoint count; decomp expands a few × }
  ABuffer.Reserve(Length(AValue) + 16);
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
  LPtr: PByte;
  LBuf: array[0..3] of Byte;
  LLen: Byte;
  LJ: Integer;
begin
  if ABuffer.Count = 0 then
    Exit('');
  SetLength(Result, ABuffer.Count * 4);
  LPtr := PByte(@Result[1]);
  LUsed := 0;
  for LIdx := 0 to ABuffer.Count - 1 do
  begin
    LLen := UTF8Encode(ABuffer.ItemAt(LIdx), @LBuf[0]);
    if LLen = 0 then
      Continue;
    for LJ := 0 to Integer(LLen) - 1 do
      LPtr[LUsed + LJ] := LBuf[LJ];
    Inc(LUsed, LLen);
  end;
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
  LCanTry: Boolean;
  LStarter: TUnicodeCodepoint;
begin
  if ABuffer.Count = 0 then
    Exit;

  LStarterIndex := 0;
  while LStarterIndex < ABuffer.Count do
  begin
    LStarter := ABuffer.ItemAt(LStarterIndex);
    if GetCanonicalCombiningClass(LStarter) <> 0 then
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

      { UAX #15: unblocked if immediately after starter (LLastCcc=0) or
        LLastCcc < CCC(current). Adjacent starters (CCC=0) must also compose. }
      LCanTry := (LLastCcc = 0) or ((LCcc <> 0) and (LLastCcc < LCcc));
      if LCanTry and
         (ComposeHangulPair(LStarter, LCurrent, LComposed) or
          FindComposition(LStarter, LCurrent, LComposed)) then
      begin
        ABuffer.ReplaceAt(LStarterIndex, LComposed);
        LStarter := LComposed;
        ABuffer.DeleteAt(LLookahead);
        LLastCcc := 0;
        Continue;
      end;

      if LCcc = 0 then
        Break;

      LLastCcc := LCcc;
      Inc(LLookahead);
    end;

    Inc(LStarterIndex);
  end;
end;

function NormalizeDecomposed(const AText: string; const ACompatibility: Boolean): string;
begin
  if AText = '' then
    Exit('');
  if IsAsciiString(AText) then
    Exit(AText);

  DecomposeToBuffer(AText, ACompatibility, GNormBuffer);
  Result := BufferToUtf8(GNormBuffer);
end;

function NormalizeComposed(const AText: string; const ACompatibility: Boolean): string;
begin
  if AText = '' then
    Exit('');
  if IsAsciiString(AText) then
    Exit(AText);

  DecomposeToBuffer(AText, ACompatibility, GNormBuffer);
  ComposeBufferWithHangul(GNormBuffer);
  Result := BufferToUtf8(GNormBuffer);
end;

function NFD(const AText: string): string;
begin
  Result := NormalizeDecomposed(AText, False);
end;

function NFC(const AText: string): string;
begin
  Result := NormalizeComposed(AText, False);
end;

function NFKD(const AText: string): string;
begin
  Result := NormalizeDecomposed(AText, True);
end;

function NFKC(const AText: string): string;
begin
  Result := NormalizeComposed(AText, True);
end;

function IsNormalizedNFD(const AText: string): Boolean;
begin
  // 先用 QuickCheck 快速判断（O(n) 无分配）
  if QuickCheckNFD(AText) then
    Exit(True);
  // QuickCheck 不确定时，回退到完整规范化比较
  Result := NFD(AText) = AText;
end;

function IsNormalizedNFC(const AText: string): Boolean;
begin
  if QuickCheckNFC(AText) then
    Exit(True);
  Result := NFC(AText) = AText;
end;

function IsNormalizedNFKD(const AText: string): Boolean;
begin
  if QuickCheckNFKD(AText) then
    Exit(True);
  Result := NFKD(AText) = AText;
end;

function IsNormalizedNFKC(const AText: string): Boolean;
begin
  if QuickCheckNFKC(AText) then
    Exit(True);
  Result := NFKC(AText) = AText;
end;

function QuickCheckNFD(const AText: string): Boolean;
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
  if AText = '' then
    Exit(True);
  if IsAsciiString(AText) then
    Exit(True);

  LPrevCcc := 0;
  LIter.Init(PByte(PAnsiChar(AText)), SizeUInt(Length(AText)));
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

function QuickCheckNFKD(const AText: string): Boolean;
var
  LIter: TUTF8Iterator;
  LCp: UInt32;
  LPrevCcc: Byte;
  LCcc: Byte;
  LKind: Byte;
begin
  // QuickCheck NFKD: 检查是否已经是 NFKD 形式
  // 条件：没有可分解字符(规范或兼容) + combining class 非递减
  if AText = '' then
    Exit(True);
  if IsAsciiString(AText) then
    Exit(True);

  LPrevCcc := 0;
  LIter.Init(PByte(PAnsiChar(AText)), SizeUInt(Length(AText)));
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

{ QuickCheck composed forms: 公共逻辑 }
{ ACheckCompatibility=True  → NFKC（检查 kind=2 兼容分解） }
{ ACheckCompatibility=False → NFC  （仅检查组合可能性） }
function QuickCheckComposed(const AText: string; const ACheckCompatibility: Boolean): Boolean;
var
  LIter: TUTF8Iterator;
  LCp: UInt32;
  LPrevCcc: Byte;
  LCcc: Byte;
  LKind: Byte;
  LStarter: TUnicodeCodepoint;
  LHasStarter: Boolean;
  LComposed: TUnicodeCodepoint;
  LEntry: TDecompEntry;
begin
  if AText = '' then
    Exit(True);
  if IsAsciiString(AText) then
    Exit(True);

  LPrevCcc := 0;
  LHasStarter := False;
  LStarter := 0;
  LIter.Init(PByte(PAnsiChar(AText)), SizeUInt(Length(AText)));
  while LIter.Next(LCp) do
  begin
    // NFKC: 检查兼容分解（kind=2）
    if ACheckCompatibility then
    begin
      LKind := GetDecompositionKind(LCp);
      if LKind = 2 then
        Exit(False);
    end;

    // NFC: 检查 composition exclusion（单例分解、非 starter 分解）
    // 这些字符有规范分解但不会被重新组合，因此不是 NFC 形式
    if not ACheckCompatibility then
    begin
      LKind := GetDecompositionKind(LCp);
      if LKind = 1 then
      begin
        if FindDecomposition(LCp, LEntry) then
        begin
          // 单例分解（分解到单个码点）
          if LEntry.Len = 1 then
            Exit(False);
          // 非 starter 分解（首码点 CCC > 0）
          if GetCanonicalCombiningClass(LEntry.Map[0]) > 0 then
            Exit(False);
        end;
      end;
    end;

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

function QuickCheckNFC(const AText: string): Boolean;
begin
  Result := QuickCheckComposed(AText, False);
end;

function QuickCheckNFKC(const AText: string): Boolean;
begin
  Result := QuickCheckComposed(AText, True);
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
  if FCount >= Length(FItems) then
    Reserve(FCount + 1);
  FItems[FCount] := ACp;
  Inc(FCount);
end;

procedure TCodepointBuffer.ReplaceAt(const AIndex: SizeInt; const ACp: TUnicodeCodepoint);
begin
  FItems[AIndex] := ACp;
end;

procedure TCodepointBuffer.DeleteAt(const AIndex: SizeInt);
begin
  if AIndex < FCount - 1 then
    System.Move(FItems[AIndex + 1], FItems[AIndex],
      SizeUInt(FCount - AIndex - 1) * SizeOf(TUnicodeCodepoint));
  Dec(FCount);
end;

function TCodepointBuffer.ItemAt(const AIndex: SizeInt): TUnicodeCodepoint;
begin
  Result := FItems[AIndex];
end;

procedure TCodepointBuffer.SetCount(const ACount: SizeInt);
begin
  FCount := ACount;
end;

end.
