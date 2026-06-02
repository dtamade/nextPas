unit nextpas.core.tui.text.format;

{**
 * @desc 文本格式化便利函数。
 *
 * 把字节数格式化为人类可读字符串（B / KB / MB / GB，保留一位小数）。
 * 属冷路径（状态栏、诊断显示），不在渲染热路径，使用 Str + 字符串拼接
 * 无性能顾虑。
 *}

{$I nextpas.core.settings.inc}

interface

function FormatBytes(ABytes: Int64): AnsiString;
function FormatBytesKB(AKB: Int64): AnsiString;

implementation

function FormatBytes(ABytes: Int64): AnsiString;
var
  LVal: Double;
  LIntPart, LFracPart: Integer;
  LBuf: string[8];
begin
  if ABytes < 1024 then
  begin
    Str(ABytes, LBuf);
    Result := LBuf + ' B';
  end
  else if ABytes < 1024 * 1024 then
  begin
    LVal := ABytes / 1024;
    LIntPart := Trunc(LVal);
    LFracPart := Trunc((LVal - LIntPart) * 10);
    Str(LIntPart, LBuf);
    if LFracPart > 0 then
      Result := LBuf + '.' + Chr(Ord('0') + LFracPart) + ' KB'
    else
      Result := LBuf + ' KB';
  end
  else if ABytes < Int64(1024) * 1024 * 1024 then
  begin
    LVal := ABytes / (1024 * 1024);
    LIntPart := Trunc(LVal);
    LFracPart := Trunc((LVal - LIntPart) * 10);
    Str(LIntPart, LBuf);
    if LFracPart > 0 then
      Result := LBuf + '.' + Chr(Ord('0') + LFracPart) + ' MB'
    else
      Result := LBuf + ' MB';
  end
  else
  begin
    LVal := ABytes / (Int64(1024) * 1024 * 1024);
    LIntPart := Trunc(LVal);
    LFracPart := Trunc((LVal - LIntPart) * 10);
    Str(LIntPart, LBuf);
    if LFracPart > 0 then
      Result := LBuf + '.' + Chr(Ord('0') + LFracPart) + ' GB'
    else
      Result := LBuf + ' GB';
  end;
end;

function FormatBytesKB(AKB: Int64): AnsiString;
begin
  Result := FormatBytes(AKB * 1024);
end;

end.
