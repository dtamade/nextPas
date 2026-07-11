unit nextpas.core.text.unicode.collate;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.unicode.types;

type
  // 排序规则强度
  TCollationStrength = (
    csPrimary,    // 主要差异（如 a vs b）
    csSecondary,  // 次要差异（如 a vs á）
    csTertiary,   // 三级差异（如 a vs A）
    csQuaternary, // 四级差异（如平假名 vs 片假名）
    csIdentical   // 完全相同
  );

  // 排序选项
  TCollationOptions = record
    Strength: TCollationStrength;
    CaseLevel: Boolean;
    FrenchAccents: Boolean;
    NumericOrdering: Boolean;
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

  // 默认排序器实现（基于 DUCET 主权重）
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

// 底层查询：获取 codepoint 的 DUCET 主权重
// 返回 0 表示 ignorable（排序时忽略）
function GetCollationPrimaryWeight(const ACp: TUnicodeCodepoint): UInt16;

implementation

uses
  nextpas.core.text.unicode.normalize,
  nextpas.core.text.unicode.base,
  nextpas.core.text.utf8;

{$I nextpas.core.text.unicode.collate.inc}

var
  FUnicodeCollator: IUnicodeCollator;

function GetCollationPrimaryWeight(const ACp: TUnicodeCodepoint): UInt16;
var
  LValue: UInt16;
begin
  if ACp > UNICODE_MAX_CODEPOINT then
    Exit(0);
  if ACp <= $FFFF then
    Exit(COLLATE_BMP_TABLE[Byte(ACp shr 8), Byte(ACp and $FF)]);
  if FindRange16Value(ACp, COLLATE_SMP_RANGES, LValue) then
    Exit(LValue);
  Result := 0;
end;

function DefaultCollationOptions: TCollationOptions;
begin
  Result.Strength := csPrimary;
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
  LWeight: UInt16;
  LKeyPos: SizeInt;
  LKey: TCollationKey;
begin
  if AText = '' then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  // NFD 规范化
  LNormalized := NFD(AText);

  // 预分配：每个 codepoint 2 字节权重 + 2 字节终止符
  SetLength(LKey, (Length(LNormalized) div 2 + 1) * 2 + 2);
  LKeyPos := 0;

  LIter.Init(PByte(PAnsiChar(LNormalized)), SizeUInt(Length(LNormalized)));
  while LIter.Next(LCp) do
  begin
    LWeight := GetCollationPrimaryWeight(LCp);

    // 跳过 ignorable（权重为 0）
    if LWeight = 0 then
      Continue;

    // 确保空间（2 字节权重 + 2 字节终止符）
    if LKeyPos + 4 > Length(LKey) then
      SetLength(LKey, Length(LKey) * 2);

    // 固定 2 字节大端编码（高字节在前）
    LKey[LKeyPos] := Byte(LWeight shr 8);
    LKey[LKeyPos + 1] := Byte(LWeight and $FF);
    Inc(LKeyPos, 2);
  end;

  // 终止符 0x0001（不会与任何有效权重冲突，DUCET 最小非零权重为 0x0200）
  if LKeyPos + 2 > Length(LKey) then
    SetLength(LKey, LKeyPos + 2);
  LKey[LKeyPos] := 0;
  LKey[LKeyPos + 1] := 1;
  Inc(LKeyPos, 2);

  SetLength(LKey, LKeyPos);
  Result := LKey;
end;

function TUnicodeCollator.Compare(const A, B: string): Integer;
var
  LKeyA, LKeyB: TCollationKey;
  LLen: SizeInt;
  LI: SizeInt;
begin
  // 快速路径：相同字符串
  if A = B then
    Exit(0);

  LKeyA := GetSortKey(A);
  LKeyB := GetSortKey(B);

  // 按字节比较排序键
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

  // 长度比较
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

  // 按 codepoint 边界滑动窗口
  LI := 1;
  while LI <= LTextLen - LSubByteLen + 1 do
  begin
    if Compare(Copy(AText, LI, LSubByteLen), ASubstring) = 0 then
      Exit(LI);
    // 推进到下一个 codepoint 边界
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
