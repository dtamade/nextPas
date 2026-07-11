unit nextpas.core.text.unicode.data;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.unicode.types;

type
  // 数据表管理接口
  IUnicodeDataManager = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    function GetGeneralCategory(const ACp: TUnicodeCodepoint): TGeneralCategory;
    function GetBinaryProperty(const ACp: TUnicodeCodepoint; const AProperty: TBinaryProperty): Boolean;
    function GetScript(const ACp: TUnicodeCodepoint): TUnicodeScript;
    function GetBlock(const ACp: TUnicodeCodepoint): TUnicodeBlock;
    function GetSimpleLowercaseMapping(const ACp: TUnicodeCodepoint): TUnicodeCodepoint;
    function GetSimpleUppercaseMapping(const ACp: TUnicodeCodepoint): TUnicodeCodepoint;
    function GetSimpleTitlecaseMapping(const ACp: TUnicodeCodepoint): TUnicodeCodepoint;
    function GetCaseFoldSimple(const ACp: TUnicodeCodepoint): TUnicodeCodepoint;
    function GetCaseFoldFull(const ACp: TUnicodeCodepoint; out ADst: TCaseFoldMap): Byte;
    function GetDecompositionMapping(const ACp: TUnicodeCodepoint; out ADst: TCaseFoldMap; out AIsCompatibility: Boolean): Byte;
    function GetCanonicalCombiningClass(const ACp: TUnicodeCodepoint): Byte;
    function GetCompositionExclusion(const ACp: TUnicodeCodepoint): Boolean;
  end;

  // 默认数据管理器实现
  TUnicodeDataManager = class(TInterfacedObject, IUnicodeDataManager)
  public
    function GetGeneralCategory(const ACp: TUnicodeCodepoint): TGeneralCategory;
    function GetBinaryProperty(const ACp: TUnicodeCodepoint; const AProperty: TBinaryProperty): Boolean;
    function GetScript(const ACp: TUnicodeCodepoint): TUnicodeScript;
    function GetBlock(const ACp: TUnicodeCodepoint): TUnicodeBlock;
    function GetSimpleLowercaseMapping(const ACp: TUnicodeCodepoint): TUnicodeCodepoint;
    function GetSimpleUppercaseMapping(const ACp: TUnicodeCodepoint): TUnicodeCodepoint;
    function GetSimpleTitlecaseMapping(const ACp: TUnicodeCodepoint): TUnicodeCodepoint;
    function GetCaseFoldSimple(const ACp: TUnicodeCodepoint): TUnicodeCodepoint;
    function GetCaseFoldFull(const ACp: TUnicodeCodepoint; out ADst: TCaseFoldMap): Byte;
    function GetDecompositionMapping(const ACp: TUnicodeCodepoint; out ADst: TCaseFoldMap; out AIsCompatibility: Boolean): Byte;
    function GetCanonicalCombiningClass(const ACp: TUnicodeCodepoint): Byte;
    function GetCompositionExclusion(const ACp: TUnicodeCodepoint): Boolean;
  end;

// 全局数据管理器实例
function UnicodeData: IUnicodeDataManager;

implementation

uses
  nextpas.core.text.unicode.props,
  nextpas.core.text.unicode.casefold,
  nextpas.core.text.unicode.normalize,
  nextpas.core.text.unicode.script,
  nextpas.core.text.unicode.block;

var
  FUnicodeData: IUnicodeDataManager;

function UnicodeData: IUnicodeDataManager;
begin
  if FUnicodeData = nil then
    FUnicodeData := TUnicodeDataManager.Create;
  Result := FUnicodeData;
end;

{ TUnicodeDataManager }

function TUnicodeDataManager.GetGeneralCategory(const ACp: TUnicodeCodepoint): TGeneralCategory;
begin
  Result := nextpas.core.text.unicode.props.GetGeneralCategory(ACp);
end;

function TUnicodeDataManager.GetBinaryProperty(const ACp: TUnicodeCodepoint; const AProperty: TBinaryProperty): Boolean;
begin
  Result := nextpas.core.text.unicode.props.HasBinaryProperty(ACp, AProperty);
end;

function TUnicodeDataManager.GetScript(const ACp: TUnicodeCodepoint): TUnicodeScript;
begin
  Result := nextpas.core.text.unicode.script.GetScript(ACp);
end;

function TUnicodeDataManager.GetBlock(const ACp: TUnicodeCodepoint): TUnicodeBlock;
begin
  Result := nextpas.core.text.unicode.block.GetBlock(ACp);
end;

function TUnicodeDataManager.GetSimpleLowercaseMapping(const ACp: TUnicodeCodepoint): TUnicodeCodepoint;
begin
  Result := nextpas.core.text.unicode.casefold.CodepointToLower(ACp);
end;

function TUnicodeDataManager.GetSimpleUppercaseMapping(const ACp: TUnicodeCodepoint): TUnicodeCodepoint;
begin
  Result := nextpas.core.text.unicode.casefold.CodepointToUpper(ACp);
end;

function TUnicodeDataManager.GetSimpleTitlecaseMapping(const ACp: TUnicodeCodepoint): TUnicodeCodepoint;
begin
  Result := nextpas.core.text.unicode.casefold.CodepointToTitle(ACp);
end;

function TUnicodeDataManager.GetCaseFoldSimple(const ACp: TUnicodeCodepoint): TUnicodeCodepoint;
begin
  Result := nextpas.core.text.unicode.casefold.CaseFoldSimple(ACp);
end;

function TUnicodeDataManager.GetCaseFoldFull(const ACp: TUnicodeCodepoint; out ADst: TCaseFoldMap): Byte;
begin
  Result := nextpas.core.text.unicode.casefold.CaseFoldFull(ACp, ADst);
end;

function TUnicodeDataManager.GetDecompositionMapping(const ACp: TUnicodeCodepoint; out ADst: TCaseFoldMap; out AIsCompatibility: Boolean): Byte;
begin
  // TODO: 实现分解映射查询
  AIsCompatibility := False;
  ADst[0] := ACp;
  Result := 1;
end;

function TUnicodeDataManager.GetCanonicalCombiningClass(const ACp: TUnicodeCodepoint): Byte;
begin
  // TODO: 实现规范组合类查询
  Result := 0;
end;

function TUnicodeDataManager.GetCompositionExclusion(const ACp: TUnicodeCodepoint): Boolean;
begin
  // TODO: 实现组合排除查询
  Result := False;
end;

end.