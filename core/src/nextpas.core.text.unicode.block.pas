unit nextpas.core.text.unicode.block;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.unicode.types;

function GetBlock(const ACp: TUnicodeCodepoint): TUnicodeBlock; inline;
function IsBlock(const ACp: TUnicodeCodepoint; const ABlock: TUnicodeBlock): Boolean; inline;

implementation

uses
  nextpas.core.text.unicode.base;

// Block 属性数据表（Unicode 16.0）
// 基于 Blocks.txt 生成
{$I nextpas.core.text.unicode.block.inc}

function GetBlock(const ACp: TUnicodeCodepoint): TUnicodeBlock;
begin
  // 快速路径：ASCII 范围是 Basic Latin
  if ACp <= $007F then
  begin
    Result := ubBasicLatin;
    Exit;
  end;

  // 查找 Block 属性表
  // TODO: 实现基于数据表的查找
  Result := ubNoBlock;
end;

function IsBlock(const ACp: TUnicodeCodepoint; const ABlock: TUnicodeBlock): Boolean;
begin
  Result := GetBlock(ACp) = ABlock;
end;

end.