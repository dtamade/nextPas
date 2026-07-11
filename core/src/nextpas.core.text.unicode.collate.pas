unit nextpas.core.text.unicode.collate;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.unicode.types;

type
  // 排序规则强度（UCA 级别）
  TCollationStrength = (
    csPrimary,    // 主要差异（如 a vs b）— 忽略大小写和变音
    csSecondary,  // 次要差异（如 a vs á）— 区分变音，忽略大小写
    csTertiary,   // 三级差异（如 a vs A）— 区分大小写
    csQuaternary, // 四级差异（如平假名 vs 片假名）
    csIdentical   // 完全相同
  );

  // 排序选项
  TCollationOptions = record
    Strength: TCollationStrength;
    CaseLevel: Boolean;       // 大小写作为独立级别（法语排序）
    FrenchAccents: Boolean;   // 法语重音排序（从右到左）
    NumericOrdering: Boolean; // 数字按数值排序
  end;

  // 排序键（字节序列）
  TCollationKey = array of Byte;

  // 排序器接口
  IUnicodeCollator = interface
    ['{C3D4E5F6-A7B8-9012-CDEF-123456789012}']
    function Compare(const A, B: string): Integer;
    function GetSortKey(const AText: string): TCollationKey;
    function TextEquals(const A, B: string): Boolean;
    function StartsWith(const AText, APrefix: string): Boolean;
    function EndsWith(const AText, ASuffix: string): Boolean;
    function IndexOf(const AText, ASubstring: string): SizeInt;
    function Contains(const AText, ASubstring: string): Boolean;
  end;

type
  // 单遍收集的权重三元组
  TWeightTriple = record
    Primary: UInt16;
    Secondary: Byte;
    Tertiary: Byte;
  end;

  // 权重数组（预分配，避免每级重复迭代）
  TWeightArray = array of TWeightTriple;

  // 排序器实现（基于 DUCET 三级权重）
  TUnicodeCollator = class(TInterfacedObject, IUnicodeCollator)
  private
    FOptions: TCollationOptions;
    // 单遍收集所有权重
    function CollectWeights(const ANormalized: string): TWeightArray;
    // 从权重数组生成排序键
    function WeightsToSortKey(const AWeights: TWeightArray): TCollationKey;
    // 从权重数组逐级比较（避免生成完整排序键）
    function CompareWeights(const AWeightsA, AWeightsB: TWeightArray): Integer;
  public
    constructor Create(const AOptions: TCollationOptions);
    function Compare(const A, B: string): Integer;
    function GetSortKey(const AText: string): TCollationKey;
    function TextEquals(const A, B: string): Boolean;
    function StartsWith(const AText, APrefix: string): Boolean;
    function EndsWith(const AText, ASuffix: string): Boolean;
    function IndexOf(const AText, ASubstring: string): SizeInt;
    function Contains(const AText, ASubstring: string): Boolean;
  end;

// 默认排序选项
function DefaultCollationOptions: TCollationOptions;

// 全局排序器实例
function UnicodeCollator: IUnicodeCollator;
function UnicodeCollatorWithOptions(const AOptions: TCollationOptions): IUnicodeCollator;

// 底层查询：获取码点的 DUCET 打包权重
// 返回 0 表示 ignorable（排序时忽略）
// 打包格式: (primary << 16) | (secondary << 8) | tertiary
function GetCollationWeight(const ACp: TUnicodeCodepoint): UInt32;

// 解包权重分量
function UnpackPrimary(const AWeight: UInt32): UInt16;
function UnpackSecondary(const AWeight: UInt32): Byte;
function UnpackTertiary(const AWeight: UInt32): Byte;

implementation

uses
  nextpas.core.text.unicode.normalize,
  nextpas.core.text.unicode.base,
  nextpas.core.text.utf8;

{$I nextpas.core.text.unicode.collate.inc}

{ 内联字节比较：避免依赖 SysUtils.BytesEqual }
function BytesEqual(const A: PByte; const B: PByte; const ALen: SizeInt): Boolean;
var
  I: SizeInt;
begin
  for I := 0 to ALen - 1 do
    if A[I] <> B[I] then
      Exit(False);
  Result := True;
end;

var
  FUnicodeCollator: IUnicodeCollator;
  FCollatorCS: TRTLCriticalSection;

function GetCollationWeight(const ACp: TUnicodeCodepoint): UInt32;
var
  LValue: UInt32;
begin
  if ACp > UNICODE_MAX_CODEPOINT then
    Exit(0);
  if ACp <= $FFFF then
    Exit(COLLATE_BMP_TABLE[Byte(ACp shr 8), Byte(ACp and $FF)]);
  if FindRange32Value(ACp, COLLATE_SMP_RANGES, LValue) then
    Exit(LValue);
  Result := 0;
end;

function UnpackPrimary(const AWeight: UInt32): UInt16;
begin
  Result := UInt16(AWeight shr 16);
end;

function UnpackSecondary(const AWeight: UInt32): Byte;
begin
  Result := Byte((AWeight shr 8) and $FF);
end;

function UnpackTertiary(const AWeight: UInt32): Byte;
begin
  Result := Byte(AWeight and $FF);
end;

function DefaultCollationOptions: TCollationOptions;
begin
  Result.Strength := csTertiary;
  Result.CaseLevel := False;
  Result.FrenchAccents := False;
  Result.NumericOrdering := False;
end;

function UnicodeCollator: IUnicodeCollator;
begin
  if FUnicodeCollator = nil then
  begin
    EnterCriticalSection(FCollatorCS);
    try
      if FUnicodeCollator = nil then
        FUnicodeCollator := TUnicodeCollator.Create(DefaultCollationOptions);
    finally
      LeaveCriticalSection(FCollatorCS);
    end;
  end;
  Result := FUnicodeCollator;
end;

function UnicodeCollatorWithOptions(const AOptions: TCollationOptions): IUnicodeCollator;
begin
  Result := TUnicodeCollator.Create(AOptions);
end;

{ TUnicodeCollator }

constructor TUnicodeCollator.Create(const AOptions: TCollationOptions);
begin
  inherited Create;
  FOptions := AOptions;
end;

function TUnicodeCollator.CollectWeights(const ANormalized: string): TWeightArray;
var
  LIter: TUTF8Iterator;
  LCp: UInt32;
  LWeight: UInt32;
  LCount: SizeInt;
  LCapacity: SizeInt;
  LWeights: TWeightArray;
  LPrimary: UInt16;
begin
  LCapacity := Length(ANormalized) div 3 + 16;  // UTF-8 最小 3 字节/码点
  SetLength(LWeights, LCapacity);
  LCount := 0;

  LIter.Init(PByte(PAnsiChar(ANormalized)), SizeUInt(Length(ANormalized)));
  while LIter.Next(LCp) do
  begin
    LWeight := GetCollationWeight(LCp);
    if LWeight = 0 then
      Continue;

    LPrimary := UnpackPrimary(LWeight);
    if LPrimary = 0 then
      Continue;

    if LCount >= LCapacity then
    begin
      LCapacity := LCapacity * 2;
      SetLength(LWeights, LCapacity);
    end;

    LWeights[LCount].Primary := LPrimary;
    LWeights[LCount].Secondary := UnpackSecondary(LWeight);
    LWeights[LCount].Tertiary := UnpackTertiary(LWeight);
    Inc(LCount);
  end;

  SetLength(LWeights, LCount);
  Result := LWeights;
end;

function TUnicodeCollator.WeightsToSortKey(const AWeights: TWeightArray): TCollationKey;
var
  LKeyPos: SizeInt;
  LKey: TCollationKey;
  LI: SizeInt;
  LLen: SizeInt;
begin
  LLen := Length(AWeights);
  // 预分配：每级 N*2 字节 + 分隔符 + 终止符
  if FOptions.Strength >= csTertiary then
    SetLength(LKey, LLen * 6 + 4)
  else if FOptions.Strength >= csSecondary then
    SetLength(LKey, LLen * 4 + 3)
  else
    SetLength(LKey, LLen * 2 + 2);

  LKeyPos := 0;

  // ── Level 1: Primary weights ──
  for LI := 0 to LLen - 1 do
  begin
    LKey[LKeyPos] := Byte(AWeights[LI].Primary shr 8);
    LKey[LKeyPos + 1] := Byte(AWeights[LI].Primary and $FF);
    Inc(LKeyPos, 2);
  end;
  LKey[LKeyPos] := $01;
  Inc(LKeyPos);

  // ── Level 2: Secondary weights ──
  if FOptions.Strength >= csSecondary then
  begin
    for LI := 0 to LLen - 1 do
    begin
      LKey[LKeyPos] := 0;
      LKey[LKeyPos + 1] := AWeights[LI].Secondary;
      Inc(LKeyPos, 2);
    end;
    LKey[LKeyPos] := $01;
    Inc(LKeyPos);
  end;

  // ── Level 3: Tertiary weights ──
  if FOptions.Strength >= csTertiary then
  begin
    for LI := 0 to LLen - 1 do
    begin
      LKey[LKeyPos] := 0;
      LKey[LKeyPos + 1] := AWeights[LI].Tertiary;
      Inc(LKeyPos, 2);
    end;
    LKey[LKeyPos] := $01;
    Inc(LKeyPos);
  end;

  // Terminator
  LKey[LKeyPos] := $00;
  Inc(LKeyPos);

  SetLength(LKey, LKeyPos);
  Result := LKey;
end;

function TUnicodeCollator.CompareWeights(const AWeightsA, AWeightsB: TWeightArray): Integer;
var
  LLenA, LLenB, LMin: SizeInt;
  LI: SizeInt;
begin
  LLenA := Length(AWeightsA);
  LLenB := Length(AWeightsB);
  if LLenA < LLenB then
    LMin := LLenA
  else
    LMin := LLenB;

  // ── Level 1: Primary ──
  for LI := 0 to LMin - 1 do
  begin
    if AWeightsA[LI].Primary < AWeightsB[LI].Primary then
      Exit(-1);
    if AWeightsA[LI].Primary > AWeightsB[LI].Primary then
      Exit(1);
  end;
  if LLenA < LLenB then Exit(-1);
  if LLenA > LLenB then Exit(1);

  // ── Level 2: Secondary ──
  if FOptions.Strength >= csSecondary then
  begin
    for LI := 0 to LMin - 1 do
    begin
      if AWeightsA[LI].Secondary < AWeightsB[LI].Secondary then
        Exit(-1);
      if AWeightsA[LI].Secondary > AWeightsB[LI].Secondary then
        Exit(1);
    end;
  end;

  // ── Level 3: Tertiary ──
  if FOptions.Strength >= csTertiary then
  begin
    for LI := 0 to LMin - 1 do
    begin
      if AWeightsA[LI].Tertiary < AWeightsB[LI].Tertiary then
        Exit(-1);
      if AWeightsA[LI].Tertiary > AWeightsB[LI].Tertiary then
        Exit(1);
    end;
  end;

  Result := 0;
end;

function TUnicodeCollator.GetSortKey(const AText: string): TCollationKey;
var
  LNormalized: string;
  LWeights: TWeightArray;
begin
  if AText = '' then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  // NFD 规范化
  LNormalized := NFD(AText);

  // 单遍收集所有权重
  LWeights := CollectWeights(LNormalized);

  // 从权重数组生成排序键
  Result := WeightsToSortKey(LWeights);
end;

function TUnicodeCollator.Compare(const A, B: string): Integer;
var
  LNormalizedA, LNormalizedB: string;
  LWeightsA, LWeightsB: TWeightArray;
begin
  if A = B then
    Exit(0);
  if A = '' then
    Exit(-1);
  if B = '' then
    Exit(1);

  // NFD 规范化
  LNormalizedA := NFD(A);
  LNormalizedB := NFD(B);

  // 单遍收集权重
  LWeightsA := CollectWeights(LNormalizedA);
  LWeightsB := CollectWeights(LNormalizedB);

  // 逐级比较（不需要生成完整排序键）
  Result := CompareWeights(LWeightsA, LWeightsB);
end;

function TUnicodeCollator.TextEquals(const A, B: string): Boolean;
begin
  Result := Compare(A, B) = 0;
end;

function TUnicodeCollator.StartsWith(const AText, APrefix: string): Boolean;
var
  LPrefixLen: SizeInt;
begin
  LPrefixLen := Length(APrefix);
  if LPrefixLen > Length(AText) then
    Exit(False);
  if LPrefixLen = 0 then
    Exit(True);
  // 零拷贝：直接比较前缀字节，避免 Copy 堆分配
  if BytesEqual(@AText[1], @APrefix[1], LPrefixLen) then
    Exit(True);
  Result := Compare(Copy(AText, 1, LPrefixLen), APrefix) = 0;
end;

function TUnicodeCollator.EndsWith(const AText, ASuffix: string): Boolean;
var
  LTextLen, LSuffixLen: SizeInt;
begin
  LSuffixLen := Length(ASuffix);
  LTextLen := Length(AText);
  if LSuffixLen > LTextLen then
    Exit(False);
  if LSuffixLen = 0 then
    Exit(True);
  // 零拷贝：直接比较后缀字节，避免 Copy 堆分配
  if BytesEqual(@AText[LTextLen - LSuffixLen + 1], @ASuffix[1], LSuffixLen) then
    Exit(True);
  Result := Compare(Copy(AText, LTextLen - LSuffixLen + 1, LSuffixLen), ASuffix) = 0;
end;

function TUnicodeCollator.IndexOf(const AText, ASubstring: string): SizeInt;
var
  LI, LTextLen, LSubByteLen: SizeInt;
  LDecode: TUTF8DecodeResult;
  LSubNorm: string;
  LSubWeights: TWeightArray;
  LSubNormLen: SizeInt;
begin
  if Length(ASubstring) = 0 then
    Exit(1);
  LTextLen := Length(AText);
  LSubByteLen := Length(ASubstring);
  if LSubByteLen > LTextLen then
    Exit(0);

  // 预计算子串的规范化形式和权重（避免每次迭代重复计算）
  LSubNorm := NFD(ASubstring);
  LSubWeights := CollectWeights(LSubNorm);
  LSubNormLen := Length(LSubNorm);

  LI := 1;
  while LI <= LTextLen - LSubByteLen + 1 do
  begin
    // 快速路径：字节级相等
    if BytesEqual(@AText[LI], @ASubstring[1], LSubByteLen) then
      Exit(LI);
    // 慢速路径：collation 比较（仅对子串做 NFD + 权重收集）
    if CompareWeights(CollectWeights(NFD(Copy(AText, LI, LSubByteLen))), LSubWeights) = 0 then
      Exit(LI);
    LDecode := UTF8Decode(@AText[LI], LTextLen - LI + 1);
    if LDecode.ByteLen > 0 then
      Inc(LI, LDecode.ByteLen)
    else
      Inc(LI);
  end;
  Result := 0;
end;

function TUnicodeCollator.Contains(const AText, ASubstring: string): Boolean;
begin
  Result := IndexOf(AText, ASubstring) > 0;
end;

initialization
  InitCriticalSection(FCollatorCS);

finalization
  DoneCriticalSection(FCollatorCS);

end.
