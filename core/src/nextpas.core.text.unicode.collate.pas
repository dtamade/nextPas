unit nextpas.core.text.unicode.collate;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.unicode.types;

type
  // 排序规则类型
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

  // 排序键
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

  // 默认排序器实现
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

implementation

uses
  nextpas.core.text.unicode.normalize,
  nextpas.core.text.unicode.casefold,
  nextpas.core.text.unicode.props,
  nextpas.core.text.unicode.base,
  nextpas.core.text.utf8;

var
  FUnicodeCollator: IUnicodeCollator;

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

function TUnicodeCollator.Compare(const A, B: string): Integer;
var
  LA, LB: string;
  LI, LJ: SizeInt;
  LCodepointA, LCodepointB: TUnicodeCodepoint;
  LCategoryA, LCategoryB: TGeneralCategory;
  LDecodeA, LDecodeB: TUTF8DecodeResult;
begin
  // 规范化输入
  LA := NFD(A);
  LB := NFD(B);

  // 简单实现：逐字符比较
  LI := 1;
  LJ := 1;
  while (LI <= Length(LA)) and (LJ <= Length(LB)) do
  begin
    // 解码 UTF-8 字符
    LDecodeA := UTF8Decode(@LA[LI], Length(LA) - LI + 1);
    LDecodeB := UTF8Decode(@LB[LJ], Length(LB) - LJ + 1);

    if (LDecodeA.ByteLen = 0) or (LDecodeB.ByteLen = 0) then
    begin
      // 无效的 UTF-8 序列，跳过
      if LDecodeA.ByteLen = 0 then Inc(LI) else Inc(LI, LDecodeA.ByteLen);
      if LDecodeB.ByteLen = 0 then Inc(LJ) else Inc(LJ, LDecodeB.ByteLen);
      Continue;
    end;

    LCodepointA := LDecodeA.CodePoint;
    LCodepointB := LDecodeB.CodePoint;

    // 根据排序强度比较
    case FOptions.Strength of
      csPrimary:
      begin
        // 只比较主要差异
        if LCodepointA <> LCodepointB then
        begin
          if LCodepointA < LCodepointB then
            Exit(-1)
          else
            Exit(1);
        end;
      end;
      csSecondary:
      begin
        // 比较次要差异
        if LCodepointA <> LCodepointB then
        begin
          // 忽略大小写差异
          LCategoryA := GetGeneralCategory(LCodepointA);
          LCategoryB := GetGeneralCategory(LCodepointB);
          if not (LCategoryA in [gcuUppercaseLetter, gcuLowercaseLetter]) or
             not (LCategoryB in [gcuUppercaseLetter, gcuLowercaseLetter]) then
          begin
            if LCodepointA < LCodepointB then
              Exit(-1)
            else
              Exit(1);
          end;
        end;
      end;
      csTertiary:
      begin
        // 比较三级差异（包括大小写）
        if LCodepointA <> LCodepointB then
        begin
          if LCodepointA < LCodepointB then
            Exit(-1)
          else
            Exit(1);
        end;
      end;
      csQuaternary, csIdentical:
      begin
        // 完全比较
        if LCodepointA <> LCodepointB then
        begin
          if LCodepointA < LCodepointB then
            Exit(-1)
          else
            Exit(1);
        end;
      end;
    end;

    Inc(LI, LDecodeA.ByteLen);
    Inc(LJ, LDecodeB.ByteLen);
  end;

  // 长度比较
  if LI <= Length(LA) then
    Result := 1
  else if LJ <= Length(LB) then
    Result := -1
  else
    Result := 0;
end;

function TUnicodeCollator.GetSortKey(const AText: string): TCollationKey;
var
  LNormalized: string;
  LI: SizeInt;
  LCodepoint: TUnicodeCodepoint;
  LKey: TCollationKey;
  LDecode: TUTF8DecodeResult;
  LKeyPos: SizeInt;
begin
  // 规范化输入
  LNormalized := NFD(AText);

  // 简单实现：生成基本排序键
  SetLength(LKey, Length(LNormalized) * 4); // 预分配空间
  LI := 1;
  LKeyPos := 0;
  while LI <= Length(LNormalized) do
  begin
    // 解码 UTF-8 字符
    LDecode := UTF8Decode(@LNormalized[LI], Length(LNormalized) - LI + 1);
    if LDecode.ByteLen = 0 then
    begin
      // 无效的 UTF-8 序列，跳过一个字节
      Inc(LI);
      Continue;
    end;
    LCodepoint := LDecode.CodePoint;

    // 生成排序键
    // TODO: 实现完整的 Unicode Collation Algorithm
    if LKeyPos + 4 <= Length(LKey) then
    begin
      LKey[LKeyPos] := Byte(LCodepoint and $FF);
      LKey[LKeyPos + 1] := Byte((LCodepoint shr 8) and $FF);
      LKey[LKeyPos + 2] := Byte((LCodepoint shr 16) and $FF);
      LKey[LKeyPos + 3] := Byte((LCodepoint shr 24) and $FF);
      Inc(LKeyPos, 4);
    end;

    Inc(LI, LDecode.ByteLen);
  end;

  // 调整长度
  SetLength(LKey, LKeyPos);
  Result := LKey;
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

  // 按 codepoint 边界滑动窗口，避免截断多字节 UTF-8 字符
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