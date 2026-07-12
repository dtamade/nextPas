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
var
  LLo, LHi, LMid: SizeInt;
begin
  // 快速路径：ASCII 范围是 Basic Latin
  if ACp <= $007F then
  begin
    Result := ubBasicLatin;
    Exit;
  end;

  // 二分查找 Block 属性表
  LLo := 0;
  LHi := BLOCK_RANGES_COUNT - 1;
  while LLo <= LHi do
  begin
    LMid := LLo + ((LHi - LLo) div 2);
    if ACp < BLOCK_RANGES[LMid].Lo then
      LHi := LMid - 1
    else if ACp > BLOCK_RANGES[LMid].Hi then
      LLo := LMid + 1
    else
      Exit(TUnicodeBlock(BLOCK_RANGES[LMid].Block));
  end;

  Result := ubNoBlock;
end;

function IsBlock(const ACp: TUnicodeCodepoint; const ABlock: TUnicodeBlock): Boolean;
begin
  Result := GetBlock(ACp) = ABlock;
end;

end.