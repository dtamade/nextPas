unit nextpas.core.text.unicode.script;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.unicode.types;

function GetScript(const ACp: TUnicodeCodepoint): TUnicodeScript; inline;
function IsScript(const ACp: TUnicodeCodepoint; const AScript: TUnicodeScript): Boolean; inline;

implementation

uses
  nextpas.core.text.unicode.base;

// Script 属性数据表（Unicode 16.0）
// 基于 Scripts.txt 生成
{$I nextpas.core.text.unicode.script.inc}

function GetScript(const ACp: TUnicodeCodepoint): TUnicodeScript;
var
  LLo, LHi, LMid: SizeInt;
begin
  // 快速路径：ASCII 范围通常是 Common 或 Latin
  if ACp <= $007F then
  begin
    case ACp of
      $0000..$001F: Result := usCommon; // 控制字符
      $0020..$002F: Result := usCommon; // 标点符号
      $0030..$0039: Result := usCommon; // 数字
      $003A..$0040: Result := usCommon; // 标点符号
      $0041..$005A: Result := usLatin;  // 大写字母
      $005B..$0060: Result := usCommon; // 标点符号
      $0061..$007A: Result := usLatin;  // 小写字母
      $007B..$007F: Result := usCommon; // 标点符号
    else
      Result := usCommon;
    end;
    Exit;
  end;

  // 二分查找 Script 属性表
  LLo := 0;
  LHi := SCRIPT_RANGES_COUNT - 1;
  while LLo <= LHi do
  begin
    LMid := LLo + ((LHi - LLo) div 2);
    if ACp < SCRIPT_RANGES[LMid].Lo then
      LHi := LMid - 1
    else if ACp > SCRIPT_RANGES[LMid].Hi then
      LLo := LMid + 1
    else
      Exit(TUnicodeScript(SCRIPT_RANGES[LMid].Script));
  end;

  Result := usUnknown;
end;

function IsScript(const ACp: TUnicodeCodepoint; const AScript: TUnicodeScript): Boolean;
begin
  Result := GetScript(ACp) = AScript;
end;

end.