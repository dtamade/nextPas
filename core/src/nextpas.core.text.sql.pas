unit nextpas.core.text.sql;

{** @desc SQL 文本单源（L1）：单引号转义 / 标识符引用 / 字面量拼装。
       零 SysUtils，NUL 拒绝，O(N+Q) 单次分配。
       抽取自 db.base 的 BulkCopy 复用收口，供 db 族与未来 http/config 等
       需 SQL 字面量拼装的 L2/L3 复用；L0 语义，L1 层级。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception;

type
  ESqlError = class(ENextPasError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

const
  SBulkNul = 'BulkCopy NUL rejected (text protocol truncation)';
  SBulkIdentEmpty = 'BulkCopy identifier empty';
  SBulkIdentNul = 'BulkCopy identifier NUL rejected';

{ 单引号转义：' → '' 单遍拼装，NUL 拒绝 }
function SqlEscape(const S: string): string;
function SqlEscapeLen(const S: string): Integer;
procedure SqlCheckNul(const S: string);
{ 标识符引用： " → "" 并包双引号，空/NUL 拒绝 }
function SqlQuoteIdent(const AIdent: string): string;
function SqlQuotedIdentLen(const AIdent: string): Integer;
function SqlWriteQuotedIdent(Dst: PAnsiChar; const S: string): Integer;
function SqlQuoteQualifiedIdent(const AIdent: string): string;
{ MySQL 方言：backtick `ident` ， `` → `` 转义，免 ANSI_QUOTES 依赖 }
function SqlQuoteIdentMysql(const AIdent: string): string;
function SqlQuotedIdentLenMysql(const AIdent: string): Integer;
function SqlWriteQuotedIdentMysql(Dst: PAnsiChar; const S: string): Integer;
function SqlQuoteQualifiedIdentMysql(const AIdent: string): string;
function SqlColListMysql(const ACols: array of string): string;
{ 字面量：NULL / 文本 / blob 十六进制 X'..' }
function SqlLiteralNull: string; inline;
function SqlLiteralText(const S: string): string;
function SqlLiteralTextLen(const S: string): Integer;
function SqlWriteLiteralText(Dst: PAnsiChar; const S: string): Integer;
function SqlWriteEscape(Dst: PAnsiChar; const S: string): Integer;
function SqlLiteralBlob(const ABytes: array of Byte): string;
{ 列名列表： "a", "b" } 
function SqlColList(const ACols: array of string): string;

implementation

class function ESqlError.DefaultCategory: TErrorCategory;
begin
  Result := ecInvalidArgument;
end;

function SqlEscape(const S: string): string;
var
  I, J, Q, N: Integer;
begin
  N := Length(S);
  for I := 1 to N do
    if S[I] = #0 then
      raise ESqlError.Create(SBulkNul);
  Q := 0;
  for I := 1 to N do
    if S[I] = '''' then Inc(Q);
  if Q = 0 then
    Exit(S);
  SetLength(Result, N + Q);
  J := 1;
  for I := 1 to N do
    if S[I] = '''' then
    begin
      Result[J] := '''';
      Result[J+1] := '''';
      Inc(J, 2);
    end
    else
    begin
      Result[J] := S[I];
      Inc(J);
    end;
end;

function SqlEscapeLen(const S: string): Integer;
var I, N, Q: Integer;
begin
  N := Length(S);
  for I := 1 to N do if S[I] = #0 then
    raise ESqlError.Create(SBulkNul);
  Q := 0;
  for I := 1 to N do if S[I] = '''' then Inc(Q);
  Result := N + Q;
end;

procedure SqlCheckNul(const S: string);
var I, N: Integer;
begin
  N := Length(S);
  for I := 1 to N do if S[I] = #0 then
    raise ESqlError.Create(SBulkNul);
end;

function SqlQuoteIdent(const AIdent: string): string;
var
  I, J, Q, N: Integer;
begin
  N := Length(AIdent);
  if N = 0 then
    raise ESqlError.Create(SBulkIdentEmpty);
  for I := 1 to N do
    if AIdent[I] = #0 then
      raise ESqlError.Create(SBulkIdentNul);
  Q := 0;
  for I := 1 to N do
    if AIdent[I] = '"' then Inc(Q);
  SetLength(Result, N + Q + 2);
  Result[1] := '"';
  J := 2;
  for I := 1 to N do
    if AIdent[I] = '"' then
    begin
      Result[J] := '"';
      Result[J+1] := '"';
      Inc(J, 2);
    end
    else
    begin
      Result[J] := AIdent[I];
      Inc(J);
    end;
  Result[J] := '"';
end;

function SqlQuotedIdentLen(const AIdent: string): Integer;
var I, N, Q: Integer;
begin
  N := Length(AIdent);
  if N = 0 then
    raise ESqlError.Create(SBulkIdentEmpty);
  for I := 1 to N do if AIdent[I] = #0 then
    raise ESqlError.Create(SBulkIdentNul);
  Q := 0;
  for I := 1 to N do if AIdent[I] = '"' then Inc(Q);
  Result := N + Q + 2;
end;

function SqlWriteQuotedIdent(Dst: PAnsiChar; const S: string): Integer;
var I, J, N: Integer;
begin
  N := Length(S);
  if N = 0 then
    raise ESqlError.Create(SBulkIdentEmpty);
  for I := 1 to N do if S[I] = #0 then
    raise ESqlError.Create(SBulkIdentNul);
  Dst[0] := '"';
  J := 1;
  for I := 1 to N do
    if S[I] = '"' then
    begin Dst[J] := '"'; Dst[J+1] := '"'; Inc(J, 2); end
    else
    begin Dst[J] := S[I]; Inc(J); end;
  Dst[J] := '"';
  Result := J + 1;
end;

function SqlQuoteQualifiedIdent(const AIdent: string): string;
var
  I, St: Integer;
  Part: string;
begin
  Result := '';
  St := 1;
  for I := 1 to Length(AIdent) + 1 do
    if (I > Length(AIdent)) or (AIdent[I] = '.') then
    begin
      Part := Copy(AIdent, St, I - St);
      if Result <> '' then Result := Result + '.';
      Result := Result + SqlQuoteIdent(Part);
      St := I + 1;
    end;
end;

function SqlQuoteIdentMysql(const AIdent: string): string;
var I, J, Q, N: Integer;
begin
  N := Length(AIdent);
  if N = 0 then raise ESqlError.Create(SBulkIdentEmpty);
  for I := 1 to N do if AIdent[I] = #0 then raise ESqlError.Create(SBulkIdentNul);
  Q := 0;
  for I := 1 to N do if AIdent[I] = '`' then Inc(Q);
  SetLength(Result, N + Q + 2);
  Result[1] := '`';
  J := 2;
  for I := 1 to N do if AIdent[I] = '`' then begin Result[J] := '`'; Result[J+1] := '`'; Inc(J, 2); end else begin Result[J] := AIdent[I]; Inc(J); end;
  Result[J] := '`';
end;

function SqlQuotedIdentLenMysql(const AIdent: string): Integer;
var I, N, Q: Integer;
begin
  N := Length(AIdent);
  if N = 0 then raise ESqlError.Create(SBulkIdentEmpty);
  for I := 1 to N do if AIdent[I] = #0 then raise ESqlError.Create(SBulkIdentNul);
  Q := 0;
  for I := 1 to N do if AIdent[I] = '`' then Inc(Q);
  Result := N + Q + 2;
end;

function SqlWriteQuotedIdentMysql(Dst: PAnsiChar; const S: string): Integer;
var I, J, N: Integer;
begin
  N := Length(S);
  if N = 0 then raise ESqlError.Create(SBulkIdentEmpty);
  for I := 1 to N do if S[I] = #0 then raise ESqlError.Create(SBulkIdentNul);
  Dst[0] := '`';
  J := 1;
  for I := 1 to N do if S[I] = '`' then begin Dst[J] := '`'; Dst[J+1] := '`'; Inc(J, 2); end else begin Dst[J] := S[I]; Inc(J); end;
  Dst[J] := '`';
  Result := J + 1;
end;

function SqlQuoteQualifiedIdentMysql(const AIdent: string): string;
var I, St: Integer; Part: string;
begin
  Result := '';
  St := 1;
  for I := 1 to Length(AIdent) + 1 do if (I > Length(AIdent)) or (AIdent[I] = '.') then
  begin Part := Copy(AIdent, St, I - St); if Result <> '' then Result := Result + '.'; Result := Result + SqlQuoteIdentMysql(Part); St := I + 1; end;
end;

function SqlColListMysql(const ACols: array of string): string;
var I, LCap: Integer; P, P0: PAnsiChar;
begin
  if Length(ACols) = 0 then Exit('');
  LCap := 0;
  for I := 0 to High(ACols) do begin Inc(LCap, Length(ACols[I]) * 2 + 2); if I > 0 then Inc(LCap, 2); end;
  SetLength(Result, LCap);
  if LCap = 0 then Exit;
  P := PAnsiChar(Result); P0 := P;
  for I := 0 to High(ACols) do begin if I > 0 then begin P[0] := ','; P[1] := ' '; Inc(P, 2); end; Inc(P, SqlWriteQuotedIdentMysql(P, ACols[I])); end;
  SetLength(Result, P - P0);
end;

function SqlLiteralNull: string;
begin
  Result := 'NULL';
end;

function SqlLiteralText(const S: string): string;
begin
  Result := '''' + SqlEscape(S) + '''';
end;

function SqlLiteralTextLen(const S: string): Integer;
begin
  Result := SqlEscapeLen(S) + 2;
end;

function SqlWriteEscape(Dst: PAnsiChar; const S: string): Integer;
var I, J, N: Integer;
begin
  N := Length(S);
  for I := 1 to N do if S[I] = #0 then
    raise ESqlError.Create(SBulkNul);
  J := 0;
  for I := 1 to N do
    if S[I] = '''' then
    begin Dst[J] := ''''; Dst[J+1] := ''''; Inc(J, 2); end
    else
    begin Dst[J] := S[I]; Inc(J); end;
  Result := J;
end;

function SqlWriteLiteralText(Dst: PAnsiChar; const S: string): Integer;
var I, J, N: Integer;
begin
  N := Length(S);
  for I := 1 to N do if S[I] = #0 then
    raise ESqlError.Create(SBulkNul);
  Dst[0] := '''';
  J := 1;
  for I := 1 to N do
    if S[I] = '''' then
    begin Dst[J] := ''''; Dst[J+1] := ''''; Inc(J, 2); end
    else
    begin Dst[J] := S[I]; Inc(J); end;
  Dst[J] := '''';
  Result := J + 1;
end;

function SqlLiteralBlob(const ABytes: array of Byte): string;
const
  Hex: array[0..15] of Char = ('0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F');
var
  N, I: Integer;
begin
  N := Length(ABytes);
  SetLength(Result, 2 + N*2 + 1);
  Result[1] := 'X';
  Result[2] := '''';
  for I := 0 to N - 1 do
  begin
    Result[3 + I*2] := Hex[(ABytes[I] shr 4) and $F];
    Result[4 + I*2] := Hex[ABytes[I] and $F];
  end;
  Result[Length(Result)] := '''';
end;

function SqlColList(const ACols: array of string): string;
var
  I, LCap: Integer;
  P, P0: PAnsiChar;
begin
  if Length(ACols) = 0 then Exit('');
  LCap := 0;
  for I := 0 to High(ACols) do
  begin
    Inc(LCap, Length(ACols[I]) * 2 + 2);
    if I > 0 then Inc(LCap, 2);
  end;
  SetLength(Result, LCap);
  if LCap = 0 then Exit;
  P := PAnsiChar(Result); P0 := P;
  for I := 0 to High(ACols) do
  begin
    if I > 0 then begin P[0] := ','; P[1] := ' '; Inc(P, 2); end;
    Inc(P, SqlWriteQuotedIdent(P, ACols[I]));
  end;
  SetLength(Result, P - P0);
end;

end.
