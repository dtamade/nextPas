unit nextpas.core.encoding.gbk;

{** @desc GBK (CP936，GB2312 的超集) 双字节 → UTF-8 解码。
  纯 Pascal 表驱动，无平台 / iconv 依赖：Linux / Windows / macOS 行为一致。
  失败语义：输入含非法 GBK 序列（孤立高位字节、越界尾字节、未映射码位）
  时整体返回空串，调用方自行回退（如按 Latin-1 解释）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

function GbkToUtf8(const AStr: string): string;

implementation

{$I nextpas.core.encoding.gbk.table.inc}

function GbkToUtf8(const AStr: string): string;
var
  I, Off, CP: Integer;
  Lead, Trail: Byte;
begin
  Result := '';
  I := 1;
  while I <= Length(AStr) do
  begin
    Lead := Ord(AStr[I]);
    if Lead < $80 then
    begin
      Result := Result + AStr[I];
      Inc(I);
      Continue;
    end;
    if (Lead < $81) or (Lead > $FE) or (I >= Length(AStr)) then
    begin
      Result := '';
      Exit;
    end;
    Trail := Ord(AStr[I + 1]);
    if (Trail < $40) or (Trail > $FE) or (Trail = $7F) then
    begin
      Result := '';
      Exit;
    end;
    Off := ((Lead - $81) * 191 + (Trail - $40)) * 2;
    CP := GBK_TABLE[Off] or (GBK_TABLE[Off + 1] shl 8);
    if CP = 0 then
    begin
      Result := '';
      Exit;
    end;
    if CP < $80 then
      Result := Result + Chr(CP)
    else if CP < $800 then
    begin
      Result := Result + Chr($C0 or (CP shr 6));
      Result := Result + Chr($80 or (CP and $3F));
    end else
    begin
      Result := Result + Chr($E0 or (CP shr 12));
      Result := Result + Chr($80 or ((CP shr 6) and $3F));
      Result := Result + Chr($80 or (CP and $3F));
    end;
    Inc(I, 2);
  end;
end;

end.