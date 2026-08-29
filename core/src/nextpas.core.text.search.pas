unit nextpas.core.text.search;

{*
  零堆大小写不敏感子串匹配。
  查询词已为小写(LowerCase(Trim(Q))), Haystack 原样逐字节 ToLower 比对,
  零 LowerCase 分配, 热路径复用(endpoint/sessfilter 等列表过滤)。
  契约: LowerNeedle = LowerCase(Trim(RawQuery)), 空串→True 恒真。
*}

{$I nextpas.core.settings.inc}

interface

function ContainsLowerNeedle(const S, LowerNeedle: string): Boolean; inline;

implementation

uses
  nextpas.core.text.char;

function ContainsLowerNeedle(const S, LowerNeedle: string): Boolean;
var I, J, N, M: Integer; Match: Boolean;
begin
  M := Length(LowerNeedle);
  if M = 0 then Exit(True);
  N := Length(S);
  if M > N then Exit(False);
  for I := 1 to N - M + 1 do
  begin
    Match := True;
    for J := 1 to M do
      if ToLower(Byte(S[I + J - 1])) <> Byte(LowerNeedle[J]) then
      begin Match := False; Break; end;
    if Match then Exit(True);
  end;
  Result := False;
end;

end.
