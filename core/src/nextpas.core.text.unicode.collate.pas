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
    function Equals(const A, B: string): Boolean;
    function StartsWith(const AText, APrefix: string): Boolean;
    function EndsWith(const AText, ASuffix: string): Boolean;
    function IndexOf(const AText, ASubstring: string): SizeInt;
    function Contains(const AText, ASubstring: string): Boolean;
  end;

  // 排序器实现（基于 DUCET 三级权重）
  TUnicodeCollator = class(TInterfacedObject, IUnicodeCollator)
  private
    FOptions: TCollationOptions;
  public
    constructor Create(const AOptions: TCollationOptions);
    function Compare(const A, B: string): Integer;
    function GetSortKey(const AText: string): TCollationKey;
    function Equals(const A, B: string): Boolean;
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

var
  FUnicodeCollator: IUnicodeCollator;

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
    FUnicodeCollator := TUnicodeCollator.Create(DefaultCollationOptions);
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

function TUnicodeCollator.GetSortKey(const AText: string): TCollationKey;
var
  LNormalized: string;
  LIter: TUTF8Iterator;
  LCp: UInt32;
  LWeight: UInt32;
  LPrimary: UInt16;
  LSecondary: Byte;
  LTertiary: Byte;
  LKeyPos: SizeInt;
  LKey: TCollationKey;
  LPrimaryCount: SizeInt;
begin
  if AText = '' then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  // NFD 规范化
  LNormalized := NFD(AText);

  // 预分配：每个码点最多 2+2+2 字节权重 + 分隔符 + 终止符
  SetLength(LKey, (Length(LNormalized) div 2 + 1) * 8 + 4);
  LKeyPos := 0;
  LPrimaryCount := 0;

  // ── Level 1: Primary weights ──
  LIter.Init(PByte(PAnsiChar(LNormalized)), SizeUInt(Length(LNormalized)));
  while LIter.Next(LCp) do
  begin
    LWeight := GetCollationWeight(LCp);
    if LWeight = 0 then
      Continue;

    LPrimary := UnpackPrimary(LWeight);
    if LPrimary = 0 then
      Continue;

    if LKeyPos + 2 > Length(LKey) then
      SetLength(LKey, Length(LKey) * 2);

    LKey[LKeyPos] := Byte(LPrimary shr 8);
    LKey[LKeyPos + 1] := Byte(LPrimary and $FF);
    Inc(LKeyPos, 2);
    Inc(LPrimaryCount);
  end;

  // Primary level separator
  if LKeyPos + 1 > Length(LKey) then
    SetLength(LKey, LKeyPos + 1);
  LKey[LKeyPos] := $01;  // level separator
  Inc(LKeyPos);

  // ── Level 2: Secondary weights (if strength >= csSecondary) ──
  if FOptions.Strength >= csSecondary then
  begin
    LIter.Init(PByte(PAnsiChar(LNormalized)), SizeUInt(Length(LNormalized)));
    while LIter.Next(LCp) do
    begin
      LWeight := GetCollationWeight(LCp);
      if LWeight = 0 then
        Continue;

      LPrimary := UnpackPrimary(LWeight);
      if LPrimary = 0 then
        Continue;

      LSecondary := UnpackSecondary(LWeight);

      if LKeyPos + 2 > Length(LKey) then
        SetLength(LKey, Length(LKey) * 2);

      // Secondary weights are 0x0020-0x0127, encode as 2 bytes
      LKey[LKeyPos] := Byte(LSecondary shr 8);
      LKey[LKeyPos + 1] := Byte(LSecondary and $FF);
      Inc(LKeyPos, 2);
    end;

    // Secondary level separator
    if LKeyPos + 1 > Length(LKey) then
      SetLength(LKey, LKeyPos + 1);
    LKey[LKeyPos] := $01;
    Inc(LKeyPos);
  end;

  // ── Level 3: Tertiary weights (if strength >= csTertiary) ──
  if FOptions.Strength >= csTertiary then
  begin
    LIter.Init(PByte(PAnsiChar(LNormalized)), SizeUInt(Length(LNormalized)));
    while LIter.Next(LCp) do
    begin
      LWeight := GetCollationWeight(LCp);
      if LWeight = 0 then
        Continue;

      LPrimary := UnpackPrimary(LWeight);
      if LPrimary = 0 then
        Continue;

      LTertiary := UnpackTertiary(LWeight);

      if LKeyPos + 2 > Length(LKey) then
        SetLength(LKey, Length(LKey) * 2);

      // Tertiary weights are 0x0002-0x001E, encode as 2 bytes
      LKey[LKeyPos] := Byte(LTertiary shr 8);
      LKey[LKeyPos + 1] := Byte(LTertiary and $FF);
      Inc(LKeyPos, 2);
    end;

    // Tertiary level separator
    if LKeyPos + 1 > Length(LKey) then
      SetLength(LKey, LKeyPos + 1);
    LKey[LKeyPos] := $01;
    Inc(LKeyPos);
  end;

  // Terminator
  if LKeyPos + 1 > Length(LKey) then
    SetLength(LKey, LKeyPos + 1);
  LKey[LKeyPos] := $00;
  Inc(LKeyPos);

  SetLength(LKey, LKeyPos);
  Result := LKey;
end;

function TUnicodeCollator.Compare(const A, B: string): Integer;
var
  LKeyA, LKeyB: TCollationKey;
  LLen: SizeInt;
  LI: SizeInt;
begin
  if A = B then
    Exit(0);

  LKeyA := GetSortKey(A);
  LKeyB := GetSortKey(B);

  LLen := Length(LKeyA);
  if Length(LKeyB) < LLen then
    LLen := Length(LKeyB);

  for LI := 0 to LLen - 1 do
  begin
    if LKeyA[LI] < LKeyB[LI] then
      Exit(-1);
    if LKeyA[LI] > LKeyB[LI] then
      Exit(1);
  end;

  if Length(LKeyA) < Length(LKeyB) then
    Exit(-1);
  if Length(LKeyA) > Length(LKeyB) then
    Exit(1);
  Result := 0;
end;

function TUnicodeCollator.Equals(const A, B: string): Boolean;
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
  Result := Compare(Copy(AText, LTextLen - LSuffixLen + 1, LSuffixLen), ASuffix) = 0;
end;

function TUnicodeCollator.IndexOf(const AText, ASubstring: string): SizeInt;
var
  LI, LTextLen, LSubByteLen: SizeInt;
  LDecode: TUTF8DecodeResult;
begin
  if Length(ASubstring) = 0 then
    Exit(1);
  LTextLen := Length(AText);
  LSubByteLen := Length(ASubstring);
  if LSubByteLen > LTextLen then
    Exit(0);

  LI := 1;
  while LI <= LTextLen - LSubByteLen + 1 do
  begin
    if Compare(Copy(AText, LI, LSubByteLen), ASubstring) = 0 then
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

end.
