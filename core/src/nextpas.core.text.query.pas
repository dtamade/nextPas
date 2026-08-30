unit nextpas.core.text.query;
{**
 * @desc URI query 辅助（proxy888 subscription.query 反哺，L1 text 纯函数）：
 *       QueryValueOf 单键首值提取；UriWsParams 校验 WS 承载合法性（type/path/host/ed 陷阱）。
 *       零依赖、单遍扫描，适配订阅 URI 解析与通用 URL 查询场景复用。
 *}

{$I nextpas.core.settings.inc}

interface

function QueryValueOf(const AQuery, AKey: string; out AValue: string): Boolean;
function UriWsParams(const AQuery: string; out AIsWs: Boolean;
  out APath, AHost: string): Boolean;

implementation

uses
  nextpas.core.text.conv;

function QueryValueOf(const AQuery, AKey: string; out AValue: string): Boolean;
var
  LSeg, LSegs: string;
  LP: Integer;
begin
  Result := False;
  AValue := '';
  LSegs := AQuery;
  while LSegs <> '' do
  begin
    LP := Pos('&', LSegs);
    if LP > 0 then
    begin
      LSeg := Copy(LSegs, 1, LP - 1);
      LSegs := Copy(LSegs, LP + 1, MaxInt);
    end
    else
    begin
      LSeg := LSegs;
      LSegs := '';
    end;
    LP := Pos('=', LSeg);
    if (LP > 0) and (Copy(LSeg, 1, LP - 1) = AKey) then
    begin
      AValue := Copy(LSeg, LP + 1, MaxInt);
      Exit(True);
    end;
  end;
end;

function UriWsParams(const AQuery: string; out AIsWs: Boolean;
  out APath, AHost: string): Boolean;
var
  LT: string;
begin
  Result := False;
  AIsWs := False;
  APath := '';
  AHost := '';
  QueryValueOf(AQuery, 'type', LT);
  LT := LowerCase(Trim(LT));
  if (LT <> '') and (LT <> 'tcp') and (LT <> 'ws') then
    Exit;
  if LT = 'ws' then
  begin
    AIsWs := True;
    QueryValueOf(AQuery, 'path', APath);
    QueryValueOf(AQuery, 'host', AHost);
    if Pos('?ed=', APath) > 0 then
      Exit(False);
  end;
  Result := True;
end;

end.
