unit nextpas.core.text.sql;

{** @desc SQL 文本单源（L1）：单引号转义 / 标识符引用 / 字面量拼装 / LIKE 模式转义。
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
{ LIKE 模式转义：`\`/`%`/`_` 前加 `\`，调用方配 `ESCAPE '\'`（SQLite/Postgres 通用），NUL 拒绝 }
function SqlLikeEscape(const S: string): string;
function SqlLikeEscapeLen(const S: string): Integer;
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
{ 方言表统一 — 单源分发表（L1 owner）：标准 vs MySQL 引号/转义经表驱动，bulk 等 L2/L3 单次方言映射零重复分支 }
type
  TSqlDialect = (sdStandard, sdMysql);
const
  SqlDialectQuote: array[TSqlDialect] of Char = ('"', '`');
function SqlDialectOf(const AIsMysql: Boolean): TSqlDialect; inline;
function SqlQuotedIdentLenFor(const AIdent: string; ADialect: TSqlDialect): Integer; inline;
function SqlQuoteIdentFor(const AIdent: string; ADialect: TSqlDialect): string; inline;
function SqlWriteQuotedIdentFor(Dst: PAnsiChar; const S: string; ADialect: TSqlDialect): Integer; inline;
function SqlQuoteQualifiedIdentFor(const AIdent: string; ADialect: TSqlDialect): string; inline;
function SqlColListFor(const ACols: array of string; ADialect: TSqlDialect): string; inline;
{ 字面量：NULL / 文本 / blob 十六进制 X'..' }
function SqlLiteralNull: string; inline;
function SqlLiteralText(const S: string): string;
function SqlLiteralTextLen(const S: string): Integer;
function SqlWriteLiteralText(Dst: PAnsiChar; const S: string): Integer;
function SqlWriteEscape(Dst: PAnsiChar; const S: string): Integer;
function SqlLiteralBlob(const ABytes: array of Byte): string;
{ 列名列表： "a", "b" } 
function SqlColList(const ACols: array of string): string;
{ SQL stitch helpers — single source for bulk INSERT stitch (bytes.ops single source, zero SysUtils, inline/zero-copy).
  Bulk 10K-row path previously double-scanned text cols (SqlLiteralTextLen + SqlWriteLiteralText); now capacity uses Length*2+2 overestimate single scan.
  SqlC* stitch literals single source (INSERT/VALUES) converged from db.bulk BulkC* to text.sql owner. }
const
  SqlCIns = 'INSERT INTO ';
  SqlCParen = ' (';
  SqlCValues = ') VALUES ';
  SqlCValuesSingle = ') VALUES (';
  SqlCRParen = ')';
procedure SqlStitchAlloc(var S: string; ACap: Integer; out P, P0: PAnsiChar); inline;
procedure SqlStitchCommit(var S: string; P, P0: PAnsiChar); inline;
procedure SqlWriteConst(var P: PAnsiChar; const AConst: string); inline;
procedure SqlWriteCommaSpace(var P: PAnsiChar); inline;
function SqlLiteralTextOverestimateLen(const S: string): Integer; inline;
function SqlQuotedIdentOverestimateLen(const AIdent: string): Integer; inline;
function SqlQuotedIdentOverestimateLenFor(const AIdent: string; ADialect: TSqlDialect): Integer; inline;
{ PG array literals — single source via text.sql (L1 owner): pg.adapter thin inline forward, bytes.ops single source, zero-copy single alloc overestimate Grow-free for 10K-row multi-col }
function SqlPgTextArrayLiteral(const AValues: array of string; const ANullMask: array of Boolean): string;
function SqlPgInt64ArrayLiteral(const AValues: array of Int64; const ANullMask: array of Boolean): string;
function SqlPgDoubleArrayLiteral(const AValues: array of Double; const ANullMask: array of Boolean): string;
function SqlPgBoolArrayLiteral(const AValues: array of Boolean; const ANullMask: array of Boolean): string;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.text.ansi,
  nextpas.core.text.number;



class function ESqlError.DefaultCategory: TErrorCategory;
begin
  Result := ecInvalidArgument;
end;

{ 方言表统一实现 — 单源表驱动（SqlDialectQuote 表），零重复分支，inline/零拷贝 }
function SqlDialectOf(const AIsMysql: Boolean): TSqlDialect; inline;
begin
  if AIsMysql then Result := sdMysql else Result := sdStandard;
end;

function SqlQuotedIdentLenFor(const AIdent: string; ADialect: TSqlDialect): Integer; inline;
var I, N, Q: Integer; QC: Char;
begin
  N := Length(AIdent);
  if N = 0 then raise ESqlError.Create(SBulkIdentEmpty);
  for I := 1 to N do if AIdent[I] = #0 then raise ESqlError.Create(SBulkIdentNul);
  QC := SqlDialectQuote[ADialect];
  Q := 0;
  for I := 1 to N do if AIdent[I] = QC then Inc(Q);
  Result := N + Q + 2;
end;

function SqlQuoteIdentFor(const AIdent: string; ADialect: TSqlDialect): string; inline;
var I, J, Q, N: Integer; QC: Char;
begin
  N := Length(AIdent);
  if N = 0 then raise ESqlError.Create(SBulkIdentEmpty);
  for I := 1 to N do if AIdent[I] = #0 then raise ESqlError.Create(SBulkIdentNul);
  QC := SqlDialectQuote[ADialect];
  Q := 0;
  for I := 1 to N do if AIdent[I] = QC then Inc(Q);
  SetLength(Result, N + Q + 2);
  Result[1] := QC;
  J := 2;
  for I := 1 to N do if AIdent[I] = QC then begin Result[J] := QC; Result[J+1] := QC; Inc(J, 2); end else begin Result[J] := AIdent[I]; Inc(J); end;
  Result[J] := QC;
end;

function SqlWriteQuotedIdentFor(Dst: PAnsiChar; const S: string; ADialect: TSqlDialect): Integer; inline;
var I, J, N: Integer; QC: Char;
begin
  N := Length(S);
  if N = 0 then raise ESqlError.Create(SBulkIdentEmpty);
  for I := 1 to N do if S[I] = #0 then raise ESqlError.Create(SBulkIdentNul);
  QC := SqlDialectQuote[ADialect];
  Dst[0] := QC;
  J := 1;
  for I := 1 to N do if S[I] = QC then begin Dst[J] := QC; Dst[J+1] := QC; Inc(J, 2); end else begin Dst[J] := S[I]; Inc(J); end;
  Dst[J] := QC;
  Result := J + 1;
end;

function SqlQuoteQualifiedIdentFor(const AIdent: string; ADialect: TSqlDialect): string; inline;
var I, St: Integer; Part: string;
begin
  Result := '';
  St := 1;
  for I := 1 to Length(AIdent) + 1 do if (I > Length(AIdent)) or (AIdent[I] = '.') then
  begin Part := Copy(AIdent, St, I - St); if Result <> '' then Result := Result + '.'; Result := Result + SqlQuoteIdentFor(Part, ADialect); St := I + 1; end;
end;

function SqlColListFor(const ACols: array of string; ADialect: TSqlDialect): string; inline;
var I, LCap: Integer; P, P0: PAnsiChar;
begin
  if Length(ACols) = 0 then Exit('');
  LCap := 0;
  // perf: overestimate Length*2+2 single source via SqlQuotedIdentOverestimateLenFor — single scan zero-copy via SqlWriteQuotedIdentFor inline, avoids double scan SqlQuotedIdentLenFor per col, Commit poke shrink keeps heap block (bytes.ops single source)
  for I := 0 to High(ACols) do begin Inc(LCap, SqlQuotedIdentOverestimateLenFor(ACols[I], ADialect)); if I > 0 then Inc(LCap, 2); end;
  SqlStitchAlloc(Result, LCap, P, P0);
  if LCap = 0 then Exit;
  for I := 0 to High(ACols) do begin if I > 0 then SqlWriteCommaSpace(P); Inc(P, SqlWriteQuotedIdentFor(P, ACols[I], ADialect)); end;
  SqlStitchCommit(Result, P, P0);
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

function SqlLikeEscape(const S: string): string;
var
  I, J, Q, N: Integer;
begin
  N := Length(S);
  for I := 1 to N do
    if S[I] = #0 then
      raise ESqlError.Create(SBulkNul);
  Q := 0;
  for I := 1 to N do
    if (S[I] = '\') or (S[I] = '%') or (S[I] = '_') then Inc(Q);
  if Q = 0 then
    Exit(S);
  SetLength(Result, N + Q);
  J := 1;
  for I := 1 to N do
    if (S[I] = '\') or (S[I] = '%') or (S[I] = '_') then
    begin
      Result[J] := '\';
      Result[J+1] := S[I];
      Inc(J, 2);
    end
    else
    begin
      Result[J] := S[I];
      Inc(J);
    end;
end;

function SqlLikeEscapeLen(const S: string): Integer;
var I, N, Q: Integer;
begin
  N := Length(S);
  for I := 1 to N do if S[I] = #0 then
    raise ESqlError.Create(SBulkNul);
  Q := 0;
  for I := 1 to N do if (S[I] = '\') or (S[I] = '%') or (S[I] = '_') then Inc(Q);
  Result := N + Q;
end;

function SqlQuoteIdent(const AIdent: string): string;
begin
  Result := SqlQuoteIdentFor(AIdent, sdStandard);
end;

function SqlQuotedIdentLen(const AIdent: string): Integer;
begin
  Result := SqlQuotedIdentLenFor(AIdent, sdStandard);
end;

function SqlWriteQuotedIdent(Dst: PAnsiChar; const S: string): Integer;
begin
  Result := SqlWriteQuotedIdentFor(Dst, S, sdStandard);
end;

function SqlQuoteQualifiedIdent(const AIdent: string): string;
begin
  Result := SqlQuoteQualifiedIdentFor(AIdent, sdStandard);
end;

function SqlQuoteIdentMysql(const AIdent: string): string;
begin
  Result := SqlQuoteIdentFor(AIdent, sdMysql);
end;

function SqlQuotedIdentLenMysql(const AIdent: string): Integer;
begin
  Result := SqlQuotedIdentLenFor(AIdent, sdMysql);
end;

function SqlWriteQuotedIdentMysql(Dst: PAnsiChar; const S: string): Integer;
begin
  Result := SqlWriteQuotedIdentFor(Dst, S, sdMysql);
end;

function SqlQuoteQualifiedIdentMysql(const AIdent: string): string;
begin
  Result := SqlQuoteQualifiedIdentFor(AIdent, sdMysql);
end;

function SqlColListMysql(const ACols: array of string): string;
begin
  Result := SqlColListFor(ACols, sdMysql);
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
begin
  Result := SqlColListFor(ACols, sdStandard);
end;

procedure SqlStitchAlloc(var S: string; ACap: Integer; out P, P0: PAnsiChar); inline;
begin
  SetLength(S, ACap);
  if ACap = 0 then begin P := nil; P0 := nil; Exit; end;
  P := PAnsiChar(S); P0 := P;
end;

procedure SqlStitchCommit(var S: string; P, P0: PAnsiChar); inline;
begin
  if P0 = nil then Exit;
  StringSetLengthNoRealloc(S, SizeUInt(P - P0));
end;

procedure SqlWriteConst(var P: PAnsiChar; const AConst: string); inline;
begin
  if Length(AConst) = 0 then Exit;
  Move(PAnsiChar(AConst)^, P^, Length(AConst));
  Inc(P, Length(AConst));
end;

procedure SqlWriteCommaSpace(var P: PAnsiChar); inline;
begin
  P[0] := ','; P[1] := ' '; Inc(P, 2);
end;

function SqlLiteralTextOverestimateLen(const S: string): Integer; inline;
begin
  // overestimate Length*2+2 worst ''-heavy; single source for bulk L2, peak 2x bounded per chunk via BulkFallbackChunkRows=500 (db.base), shrink via bytes.ops StringSetLengthNoRealloc keeps heap block (physical peak = LCap), monitor via heaptrc peak / bench_db_bulk_copy assembled vs estimated ratio (threshold ~2.0), bytes.ops single source, inline zero-copy
  Result := Length(S) * 2 + 2;
end;

function SqlQuotedIdentOverestimateLen(const AIdent: string): Integer; inline;
begin
  // same overestimate contract, peak 2x bounded per chunk, monitor via heaptrc/bench, bytes.ops single source, inline zero-copy
  Result := Length(AIdent) * 2 + 2;
end;

function SqlQuotedIdentOverestimateLenFor(const AIdent: string; ADialect: TSqlDialect): Integer; inline;
begin
  // dialect-agnostic overestimate Length*2+2 (worst ""/`` heavy), single source via SqlDialectQuote table, peak 2x bounded via BulkFallbackChunkRows=500, monitor via heaptrc/bench, bytes.ops single source, inline zero-copy
  Result := Length(AIdent) * 2 + 2;
end;

{ ---- PG array literals single source (L1) ----
  perf: overestimate worst (text: Length*2+2 per elem incl quotes, bytes.ops single source) + SqlStitchAlloc single alloc + direct Move per sparse escaped segment (zero-copy via AppendView-equivalent), no Grow for 10K-row multi-col; stability: single alloc Commit poke shrink keeps heap block, NUL via ESqlError single path
  bytes.ops single source drift gated by TEXT_SQL_BYTES_SINGLE_SOURCE; inline zero-copy via Move/PAnsiChar tail writes }

function SqlPgTextArrayLiteral(const AValues: array of string; const ANullMask: array of Boolean): string;
var
  LCap: SizeUInt;
  P, P0: PAnsiChar;
  K, I: Integer;
  LText: string;
  LLen, LSegStart: Integer;
  LCh: AnsiChar;
  LUseMask: Boolean;
begin
  LUseMask := Length(ANullMask) = Length(AValues);
  // overestimate: braces 2 + commas + per elem worst (quoted text = Length*2+2, NULL=4)
  LCap := 2;
  if Length(AValues) > 0 then
    Inc(LCap, SizeUInt(Length(AValues) - 1));
  for K := 0 to High(AValues) do
    if LUseMask and ANullMask[K] then
      Inc(LCap, 4)
    else
      Inc(LCap, SizeUInt(Length(AValues[K])) * 2 + 2);
  SqlStitchAlloc(Result, Integer(LCap), P, P0);
  if P0 = nil then
    Exit;
  P^ := '{';
  Inc(P);
  for K := 0 to High(AValues) do
  begin
    if K > 0 then
    begin
      P^ := ',';
      Inc(P);
    end;
    if LUseMask and ANullMask[K] then
    begin
      P[0] := 'N'; P[1] := 'U'; P[2] := 'L'; P[3] := 'L';
      Inc(P, 4);
    end
    else
    begin
      P^ := '"';
      Inc(P);
      LText := AValues[K];
      LLen := Length(LText);
      LSegStart := 1;
      for I := 1 to LLen do
      begin
        LCh := LText[I];
        if (LCh = '\') or (LCh = '"') then
        begin
          if I > LSegStart then
          begin
            Move(PAnsiChar(LText)[LSegStart - 1], P^, SizeUInt(I - LSegStart));
            Inc(P, I - LSegStart);
          end;
          if LCh = '\' then
          begin P[0] := '\'; P[1] := '\'; Inc(P, 2); end
          else
          begin P[0] := '\'; P[1] := '"'; Inc(P, 2); end;
          LSegStart := I + 1;
        end
        else if LCh = #0 then
          raise ESqlError.Create(SBulkNul);
      end;
      if LSegStart <= LLen then
      begin
        Move(PAnsiChar(LText)[LSegStart - 1], P^, SizeUInt(LLen - LSegStart + 1));
        Inc(P, LLen - LSegStart + 1);
      end;
      P^ := '"';
      Inc(P);
    end;
  end;
  P^ := '}';
  Inc(P);
  SqlStitchCommit(Result, P, P0);
end;

function SqlPgInt64ArrayLiteral(const AValues: array of Int64; const ANullMask: array of Boolean): string;
var
  LCap: SizeUInt;
  P, P0: PAnsiChar;
  K: Integer;
  LUseMask: Boolean;
  LWritten: Int32;
begin
  LUseMask := Length(ANullMask) = Length(AValues);
  // overestimate: per int64 worst 21 incl sign + braces/comma slack 4 → single alloc Grow-free
  LCap := SizeUInt(Length(AValues)) * 21 + 4;
  if LCap < 2 then LCap := 2;
  SqlStitchAlloc(Result, Integer(LCap), P, P0);
  if P0 = nil then Exit;
  P^ := '{'; Inc(P);
  for K := 0 to High(AValues) do
  begin
    if K > 0 then begin P^ := ','; Inc(P); end;
    if LUseMask and ANullMask[K] then
    begin P[0]:='N'; P[1]:='U'; P[2]:='L'; P[3]:='L'; Inc(P,4); end
    else
    begin
      LWritten := IntToBuffer(AValues[K], P);
      Inc(P, LWritten);
    end;
  end;
  P^ := '}'; Inc(P);
  SqlStitchCommit(Result, P, P0);
end;

function SqlPgDoubleArrayLiteral(const AValues: array of Double; const ANullMask: array of Boolean): string;
var
  LCap: SizeUInt;
  P, P0: PAnsiChar;
  K: Integer;
  LUseMask: Boolean;
  LWritten: Int32;
begin
  LUseMask := Length(ANullMask) = Length(AValues);
  // overestimate: per double worst 25 (Schubfach shortest round-trip) + slack
  LCap := SizeUInt(Length(AValues)) * 25 + 4;
  if LCap < 2 then LCap := 2;
  SqlStitchAlloc(Result, Integer(LCap), P, P0);
  if P0 = nil then Exit;
  P^ := '{'; Inc(P);
  for K := 0 to High(AValues) do
  begin
    if K > 0 then begin P^ := ','; Inc(P); end;
    if LUseMask and ANullMask[K] then
    begin P[0]:='N'; P[1]:='U'; P[2]:='L'; P[3]:='L'; Inc(P,4); end
    else
    begin
      LWritten := FloatToBuffer(AValues[K], P);
      Inc(P, LWritten);
    end;
  end;
  P^ := '}'; Inc(P);
  SqlStitchCommit(Result, P, P0);
end;

function SqlPgBoolArrayLiteral(const AValues: array of Boolean; const ANullMask: array of Boolean): string;
var
  LCap: SizeUInt;
  P, P0: PAnsiChar;
  K: Integer;
  LUseMask: Boolean;
begin
  LUseMask := Length(ANullMask) = Length(AValues);
  // overestimate: per bool worst 6 (NULL 4 + comma) → 1-char 't'/'f' fits, Grow-free
  LCap := SizeUInt(Length(AValues)) * 6 + 4;
  if LCap < 2 then LCap := 2;
  SqlStitchAlloc(Result, Integer(LCap), P, P0);
  if P0 = nil then Exit;
  P^ := '{'; Inc(P);
  for K := 0 to High(AValues) do
  begin
    if K > 0 then begin P^ := ','; Inc(P); end;
    if LUseMask and ANullMask[K] then
    begin P[0]:='N'; P[1]:='U'; P[2]:='L'; P[3]:='L'; Inc(P,4); end
    else if AValues[K] then begin P^ := 't'; Inc(P); end
    else begin P^ := 'f'; Inc(P); end;
  end;
  P^ := '}'; Inc(P);
  SqlStitchCommit(Result, P, P0);
end;

end.
