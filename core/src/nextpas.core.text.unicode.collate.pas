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
  nextpas.core.text.unicode.base;

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
    LCodepointA := 0; // TODO: 实现 UTF-8 解码
    LCodepointB := 0; // TODO: 实现 UTF-8 解码

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

    Inc(LI);
    Inc(LJ);
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
begin
  // 规范化输入
  LNormalized := NFD(AText);

  // 简单实现：生成基本排序键
  SetLength(LKey, Length(LNormalized) * 4); // 预分配空间
  LI := 1;
  while LI <= Length(LNormalized) do
  begin
    // 解码 UTF-8 字符
    LCodepoint := 0; // TODO: 实现 UTF-8 解码

    // 生成排序键
    // TODO: 实现完整的 Unicode Collation Algorithm
    LKey[LI - 1] := Byte(LCodepoint and $FF);
    LKey[LI] := Byte((LCodepoint shr 8) and $FF);
    LKey[LI + 1] := Byte((LCodepoint shr 16) and $FF);
    LKey[LI + 2] := Byte((LCodepoint shr 24) and $FF);

    Inc(LI, 4);
  end;

  // 调整长度
  SetLength(LKey, LI - 1);
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
  LI, LMax: SizeInt;
  LSubLen: SizeInt;
begin
  LSubLen := Length(ASubstring);
  if LSubLen = 0 then
    Exit(1);

  LMax := Length(AText) - LSubLen + 1;
  for LI := 1 to LMax do
  begin
    if Compare(Copy(AText, LI, LSubLen), ASubstring) = 0 then
      Exit(LI);
  end;

  Result := 0;
end;

function TUnicodeCollator.Contains(const AText, ASubstring: string): Boolean;
begin
  Result := IndexOf(AText, ASubstring) > 0;
end;

end.