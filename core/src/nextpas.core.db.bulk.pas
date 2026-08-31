unit nextpas.core.db.bulk;

{** @desc BulkCopy 缓冲复用（V4.3+）：5 后端共用的表/列/行缓冲与校验。
       零后端依赖（仅 db.base 的 TDbKind/EDbError/DbBulk* 文本单源），L3 家族复用件（依托 db.base/text.sql 单源），
       零 SysUtils，PAnsiChar 准长+Tail 直写（LCap 经 DbBulk*Len 准计，零过度预留，无 L1 builder）。
       适配器各持一份实例，BeginCopy/WriteRow/AbortCopy 委托本缓冲，
       EndCopy 的事务分支与 Exec 通道仍由适配器自管（事务模型各异）。
       性能注记：薄包装 DbBulkEscape/DbBulkWriteEscape 按 chunk 单次转译 ESqlError->EDbError（非 per-row 逐格 try），
       500 行/chunk 字面量 INSERT 故意 bypass IDbStmtCacheControl LRU 64（bench_db_stmt_cache 2.1-2.4× 为参数化 point-query 收益，正交 by design vs parameterized bulk）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.base;

type
  TDbBulkRows = array of array of string;

  TDbBulkBuffer = record
  private
    FTable: string;
    FCols: array of string;
    FRows: TDbBulkRows;
    FRowCount: Integer;
    FActive: Boolean;
    FBackend: TDbKind;
  public
    procedure Clear;
    procedure BeginCopy(const ATable: string; const AColumns: array of string); overload;
    procedure BeginCopy(const ATable: string; const AColumns: array of string; const AExpectedRows: Integer); overload;
    procedure BeginCopy(const ABackend: TDbKind; const ATable: string; const AColumns: array of string); overload;
    procedure BeginCopy(const ABackend: TDbKind; const ATable: string; const AColumns: array of string; const AExpectedRows: Integer); overload;
    procedure WriteRow(const ABackend: TDbKind; const AValues: array of string);
    function IsActive: Boolean; inline;
    function TableName: string; inline;
    function Columns: TDbStringArray; inline;
    function Rows: TDbBulkRows; inline;
    function ColumnCount: Integer; inline;
    function RowCount: Integer; inline;
  end;

  { 语句缓存容量与 Bulk fallback 单源于 db.base（接口默认值可见性要求） }

{ Bulk text single-source via nextpas.core.text.sql (SqlEscape/SqlQuoteIdent/SqlCheckNul single scan, 0 SysUtils).
  薄包装转译 ESqlError/通用异常为 EDbError 指定 Backend，零 SysUtils（per-call try 保留，热路径 stitch 按 chunk 单次 try 非 per-row）。
  DbBulkEscapeLen 单源于 SqlEscapeLen ('' 计数)；DbBulkCheckNul 单源于 SqlCheckNul (纯 NUL 扫描，无 '' 计数)，
  避免前者经长度计算附带 NUL 拒绝的语义耦合与后端 NUL 语义掩盖。 }
function DbBulkEscape(const S: string): string; overload;
function DbBulkEscape(const S: string; const ABackend: TDbKind): string; overload;
function DbBulkEscapeLen(const S: string): Integer; overload;
function DbBulkEscapeLen(const S: string; const ABackend: TDbKind): Integer; overload;
function DbBulkWriteEscape(Dst: PAnsiChar; const S: string): Integer; overload;
function DbBulkWriteEscape(Dst: PAnsiChar; const S: string; const ABackend: TDbKind): Integer; overload;
function DbBulkQuoteIdent(const AIdent: string): string; overload;
function DbBulkQuoteIdent(const AIdent: string; const ABackend: TDbKind): string; overload;
function DbBulkQuotedIdentLen(const AIdent: string): Integer; overload;
function DbBulkQuotedIdentLen(const AIdent: string; const ABackend: TDbKind): Integer; overload;
function DbBulkWriteQuotedIdent(Dst: PAnsiChar; const S: string): Integer; overload;
function DbBulkWriteQuotedIdent(Dst: PAnsiChar; const S: string; const ABackend: TDbKind): Integer; overload;
function DbBulkQuoteQualifiedIdent(const AIdent: string): string; overload;
function DbBulkQuoteQualifiedIdent(const AIdent: string; const ABackend: TDbKind): string; overload;
procedure DbBulkValidateIdent(const ABackend: TDbKind; const AIdent: string);
function DbBulkLiteralNull: string; inline;
function DbBulkLiteralText(const S: string): string; overload;
function DbBulkLiteralText(const S: string; const ABackend: TDbKind): string; overload;
function DbBulkLiteralTextLen(const S: string): Integer; overload;
function DbBulkLiteralTextLen(const S: string; const ABackend: TDbKind): Integer; overload;
function DbBulkWriteLiteralText(Dst: PAnsiChar; const S: string): Integer; overload;
function DbBulkWriteLiteralText(Dst: PAnsiChar; const S: string; const ABackend: TDbKind): Integer; overload;
function DbBulkLiteralBlob(const ABytes: array of Byte): string;
{ NUL 校验单源于 text.sql SqlCheckNul 的纯扫描（0 SysUtils），不复用 EscapeLen 的 '' 计数路径；
  与 DbBulkEscape/TDbBulkBuffer 复用正交：前者仅判截断，后者经 DbBulkEscape 单遍转义。 }
procedure DbBulkCheckNul(const S: string); overload;
procedure DbBulkCheckNul(const S: string; const ABackend: TDbKind); overload;

{ SQL stitch helpers (V4.3 reuse close): ColList/ValList/INSERT built once }
function DbBulkColList(const ACols: TDbStringArray): string; overload;
function DbBulkColList(const ACols: TDbStringArray; const ABackend: TDbKind): string; overload;
function DbBulkValList(const ARow: array of string): string;
function DbBulkInsertSql(const ATable, AColList: string; const ARow: array of string): string;
function DbBulkMultiInsertSql(const ATable: string; const ACols: TDbStringArray;
  const ARows: TDbBulkRows; const AFrom, ACount: Integer): string; overload;
function DbBulkMultiInsertSql(const ATable: string; const ACols: TDbStringArray;
  const ARows: TDbBulkRows; const AFrom, ACount: Integer; const ABackend: TDbKind): string; overload;
{ Chunk sizing derived from MaxPlaceholders (conservative 999) and column count
  Literal 500 rows/chunk (DbBulkFallbackChunkRows) intentionally bypasses IDbStmtCacheControl LRU 64
  (2.1-2.4x in bench_db_stmt_cache is parameterized point-query gain, orthogonal by design; each chunk
  generates unique SQL length => no cache hit, vs parameterized bulk trade-off unmeasured). }
function DbBulkChunkRows(const AMaxPlaceholders, AColumnCount, ARowCount: Integer): Integer;

{ Flush helper: single-source for InTransaction branching (avoid 5× duplicate loops). 0 SysUtils. }
type
  TDbBulkExecProc = procedure(const ASql: string) of object;
  TDbBulkBeginProc = procedure(const AImmediate: Boolean) of object;
  TDbBulkTxnProc = procedure of object;
procedure DbBulkFlushChunked(
  const ATable: string;
  const ACols: TDbStringArray;
  const ARows: TDbBulkRows;
  const AChunkRows: Integer;
  const AInTxn: Boolean;
  const AExec: TDbBulkExecProc;
  const ABeginTxn: TDbBulkBeginProc;
  const ACommitTxn, ARollbackTxn: TDbBulkTxnProc;
  const ABackend: TDbKind = dbkUnknown); overload;
procedure DbBulkFlushChunked(
  const ATable: string;
  const ACols: TDbStringArray;
  const ARows: TDbBulkRows;
  const AChunkRows: Integer;
  const AInTxn: Boolean;
  const ASupportsSavepoints: Boolean;
  const AExec: TDbBulkExecProc;
  const ABeginTxn: TDbBulkBeginProc;
  const ACommitTxn, ARollbackTxn: TDbBulkTxnProc;
  const ABackend: TDbKind = dbkUnknown); overload;
{ Buffer-level wrapper: collapses 4× identical LCols/LRows/LChunk/Flush stanza
  (sqlite/odbc/mysql/dm) into single TDbBulkBuffer call. Keeps InTransaction
  branching inside DbBulkFlushChunked; chunk derived from MaxPlaceholders. }
procedure DbBulkFlushBuffer(
  const ABuffer: TDbBulkBuffer;
  const AMaxPlaceholders: Integer;
  const AInTxn: Boolean;
  const AExec: TDbBulkExecProc;
  const ABeginTxn: TDbBulkBeginProc;
  const ACommitTxn, ARollbackTxn: TDbBulkTxnProc); overload;
procedure DbBulkFlushBuffer(
  const ABuffer: TDbBulkBuffer;
  const AMaxPlaceholders: Integer;
  const AInTxn: Boolean;
  const ASupportsSavepoints: Boolean;
  const AExec: TDbBulkExecProc;
  const ABeginTxn: TDbBulkBeginProc;
  const ACommitTxn, ARollbackTxn: TDbBulkTxnProc); overload;
{ BulkCopy outer wrappers (5 adapters × 4-5 lines): single source to avoid
  drift of MaxPlaceholders heterogeneity (999→500 vs 65535→10000) and
  InTransaction SAVEPOINT/BEGIN branching; thin inline delegations. }
procedure DbBulkBeginCopy(var ABuffer: TDbBulkBuffer; ABackend: TDbKind;
  const ATable: string; const AColumns: array of string); inline;
procedure DbBulkWriteRow(var ABuffer: TDbBulkBuffer; ABackend: TDbKind;
  const AValues: array of string); inline;
procedure DbBulkAbortCopy(var ABuffer: TDbBulkBuffer); inline;
procedure DbBulkEndCopy(var ABuffer: TDbBulkBuffer; AMaxPlaceholders: Integer;
  AInTxn: Boolean; const AExec: TDbBulkExecProc;
  const ABeginTxn: TDbBulkBeginProc;
  const ACommitTxn, ARollbackTxn: TDbBulkTxnProc); overload;
procedure DbBulkEndCopy(var ABuffer: TDbBulkBuffer; AMaxPlaceholders: Integer;
  AInTxn: Boolean; ASupportsSavepoints: Boolean; const AExec: TDbBulkExecProc;
  const ABeginTxn: TDbBulkBeginProc;
  const ACommitTxn, ARollbackTxn: TDbBulkTxnProc); overload;

implementation

uses
  nextpas.core.exception,
  nextpas.core.text.sql;

function DbBulkEscape(const S: string): string;
begin
  Result := DbBulkEscape(S, dbkUnknown);
end;

function DbBulkEscape(const S: string; const ABackend: TDbKind): string;
begin
  try
    Result := SqlEscape(S);
  except
    on E: ESqlError do raise EDbError.CreateSimple(ABackend, E.Message);
    on E: Exception do raise EDbError.CreateSimple(ABackend, E.Message);
  end;
end;

function DbBulkQuoteIdent(const AIdent: string): string;
begin
  Result := DbBulkQuoteIdent(AIdent, dbkUnknown);
end;

function DbBulkQuoteIdent(const AIdent: string; const ABackend: TDbKind): string;
begin
  try
    if ABackend = dbkMysql then
      Result := SqlQuoteIdentMysql(AIdent)
    else
      Result := SqlQuoteIdent(AIdent);
  except
    on E: ESqlError do raise EDbError.CreateSimple(ABackend, E.Message);
    on E: Exception do raise EDbError.CreateSimple(ABackend, E.Message);
  end;
end;

function DbBulkLiteralNull: string;
begin
  Result := 'NULL';
end;

function DbBulkLiteralText(const S: string): string;
begin
  Result := DbBulkLiteralText(S, dbkUnknown);
end;

function DbBulkLiteralText(const S: string; const ABackend: TDbKind): string;
begin
  try
    Result := '''' + DbBulkEscape(S, ABackend) + '''';
  except
    on E: EDbError do raise;
    on E: Exception do raise EDbError.CreateSimple(ABackend, E.Message);
  end;
end;

function DbBulkLiteralTextLen(const S: string): Integer;
begin
  Result := DbBulkLiteralTextLen(S, dbkUnknown);
end;

function DbBulkLiteralTextLen(const S: string; const ABackend: TDbKind): Integer;
begin
  try
    Result := DbBulkEscapeLen(S, ABackend) + 2;
  except
    on E: EDbError do raise;
    on E: Exception do raise EDbError.CreateSimple(ABackend, E.Message);
  end;
end;

function DbBulkLiteralBlob(const ABytes: array of Byte): string;
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

function DbBulkEscapeLen(const S: string): Integer;
begin
  Result := DbBulkEscapeLen(S, dbkUnknown);
end;

function DbBulkEscapeLen(const S: string; const ABackend: TDbKind): Integer;
begin
  try
    Result := SqlEscapeLen(S);
  except
    on E: ESqlError do raise EDbError.CreateSimple(ABackend, E.Message);
    on E: Exception do raise EDbError.CreateSimple(ABackend, E.Message);
  end;
end;

function DbBulkQuotedIdentLen(const AIdent: string): Integer;
begin
  Result := DbBulkQuotedIdentLen(AIdent, dbkUnknown);
end;

function DbBulkQuotedIdentLen(const AIdent: string; const ABackend: TDbKind): Integer;
begin
  try
    if ABackend = dbkMysql then
      Result := SqlQuotedIdentLenMysql(AIdent)
    else
      Result := SqlQuotedIdentLen(AIdent);
  except
    on E: ESqlError do raise EDbError.CreateSimple(ABackend, E.Message);
    on E: Exception do raise EDbError.CreateSimple(ABackend, E.Message);
  end;
end;

function DbBulkWriteEscape(Dst: PAnsiChar; const S: string): Integer;
begin
  Result := DbBulkWriteEscape(Dst, S, dbkUnknown);
end;

function DbBulkWriteEscape(Dst: PAnsiChar; const S: string; const ABackend: TDbKind): Integer;
begin
  try
    Result := SqlWriteEscape(Dst, S);
  except
    on E: ESqlError do raise EDbError.CreateSimple(ABackend, E.Message);
    on E: Exception do raise EDbError.CreateSimple(ABackend, E.Message);
  end;
end;

function DbBulkWriteQuotedIdent(Dst: PAnsiChar; const S: string): Integer;
begin
  Result := DbBulkWriteQuotedIdent(Dst, S, dbkUnknown);
end;

function DbBulkWriteQuotedIdent(Dst: PAnsiChar; const S: string; const ABackend: TDbKind): Integer;
begin
  try
    if ABackend = dbkMysql then
      Result := SqlWriteQuotedIdentMysql(Dst, S)
    else
      Result := SqlWriteQuotedIdent(Dst, S);
  except
    on E: ESqlError do raise EDbError.CreateSimple(ABackend, E.Message);
    on E: Exception do raise EDbError.CreateSimple(ABackend, E.Message);
  end;
end;

function DbBulkQuoteQualifiedIdent(const AIdent: string): string;
begin
  Result := DbBulkQuoteQualifiedIdent(AIdent, dbkUnknown);
end;

function DbBulkQuoteQualifiedIdent(const AIdent: string; const ABackend: TDbKind): string;
begin
  try
    if ABackend = dbkMysql then
      Result := SqlQuoteQualifiedIdentMysql(AIdent)
    else
      Result := SqlQuoteQualifiedIdent(AIdent);
  except
    on E: ESqlError do raise EDbError.CreateSimple(ABackend, E.Message);
    on E: Exception do raise EDbError.CreateSimple(ABackend, E.Message);
  end;
end;

function DbBulkWriteLiteralText(Dst: PAnsiChar; const S: string): Integer;
begin
  Result := DbBulkWriteLiteralText(Dst, S, dbkUnknown);
end;

function DbBulkWriteLiteralText(Dst: PAnsiChar; const S: string; const ABackend: TDbKind): Integer;
begin
  try
    Result := SqlWriteLiteralText(Dst, S);
  except
    on E: ESqlError do raise EDbError.CreateSimple(ABackend, E.Message);
    on E: Exception do raise EDbError.CreateSimple(ABackend, E.Message);
  end;
end;

procedure DbBulkValidateIdent(const ABackend: TDbKind; const AIdent: string);
begin
  DbBulkQuotedIdentLen(AIdent, ABackend);
end;

procedure DbBulkCheckNul(const S: string);
begin
  DbBulkCheckNul(S, dbkUnknown);
end;

procedure DbBulkCheckNul(const S: string; const ABackend: TDbKind);
begin
  try
    SqlCheckNul(S);
  except
    on E: ESqlError do raise EDbError.CreateSimple(ABackend, E.Message);
    on E: Exception do raise EDbError.CreateSimple(ABackend, E.Message);
  end;
end;

procedure TDbBulkBuffer.Clear;
var I: Integer;
begin
  FActive := False;
  FTable := '';
  SetLength(FCols, 0);
  for I := 0 to FRowCount - 1 do
    FRows[I] := nil;
  FRowCount := 0;
  FBackend := dbkUnknown;
end;

procedure TDbBulkBuffer.BeginCopy(const ATable: string; const AColumns: array of string);
begin
  BeginCopy(dbkUnknown, ATable, AColumns, 0);
end;

procedure TDbBulkBuffer.BeginCopy(const ATable: string; const AColumns: array of string; const AExpectedRows: Integer);
begin
  BeginCopy(dbkUnknown, ATable, AColumns, AExpectedRows);
end;

procedure TDbBulkBuffer.BeginCopy(const ABackend: TDbKind; const ATable: string; const AColumns: array of string);
begin
  BeginCopy(ABackend, ATable, AColumns, 0);
end;

procedure TDbBulkBuffer.BeginCopy(const ABackend: TDbKind; const ATable: string; const AColumns: array of string; const AExpectedRows: Integer);
var I: Integer;
  procedure ValidateIdent(const S: string);
  begin
    DbBulkValidateIdent(ABackend, S);
  end;
begin
  if FActive then Clear;
  ValidateIdent(ATable);
  if Length(AColumns) = 0 then
    raise EDbError.CreateSimple(ABackend, 'BulkCopy columns empty');
  for I := 0 to High(AColumns) do ValidateIdent(AColumns[I]);
  FTable := ATable;
  SetLength(FCols, Length(AColumns));
  for I := 0 to High(AColumns) do FCols[I] := AColumns[I];
  if AExpectedRows > 0 then
  begin
    if Length(FRows) < AExpectedRows then
      SetLength(FRows, AExpectedRows);
  end;
  FRowCount := 0;
  FBackend := ABackend;
  FActive := True;
end;

procedure TDbBulkBuffer.WriteRow(const ABackend: TDbKind; const AValues: array of string);
var Row: array of string; I, LCap, LNewCap: Integer;
begin
  if not FActive then raise EDbError.CreateSimple(ABackend, 'BulkCopy not started');
  if Length(AValues) <> Length(FCols) then raise EDbError.CreateSimple(ABackend, 'BulkCopy column count mismatch');
  SetLength(Row, Length(AValues));
  for I := 0 to High(AValues) do Row[I] := AValues[I];
  if FRowCount >= Length(FRows) then
  begin
    LCap := Length(FRows);
    if LCap = 0 then LNewCap := 16 else LNewCap := LCap * 2;
    while LNewCap <= FRowCount do LNewCap := LNewCap * 2;
    SetLength(FRows, LNewCap);
  end;
  FRows[FRowCount] := Row;
  Inc(FRowCount);
end;

function TDbBulkBuffer.IsActive: Boolean;
begin
  Result := FActive;
end;

function TDbBulkBuffer.TableName: string;
begin
  Result := FTable;
end;

function TDbBulkBuffer.Columns: TDbStringArray;
begin
  Result := FCols;
end;

function TDbBulkBuffer.Rows: TDbBulkRows;
var I: Integer;
begin
  if FRowCount = 0 then Exit(nil);
  if FRowCount = Length(FRows) then Exit(FRows);
  SetLength(Result, FRowCount);
  for I := 0 to FRowCount - 1 do Result[I] := FRows[I];
end;

function TDbBulkBuffer.ColumnCount: Integer;
begin
  Result := Length(FCols);
end;

function TDbBulkBuffer.RowCount: Integer;
begin
  Result := FRowCount;
end;

{ SQL stitch — PAnsiChar 准长+Tail 直写：LCap 经 Sql*Len 准计（零过度预留，零 L1 builder）；零 SysUtils；ColList 复用 text.sql 单源；
  热路径 ValList/InsertSql/MultiInsertSql 按调用单次 try 转译 ESqlError->EDbError，非 per-row/ per-cell 逐格 try（N=10000 开销收敛至 chunk 级）。 }

function DbBulkColList(const ACols: TDbStringArray): string;
begin
  Result := DbBulkColList(ACols, dbkUnknown);
end;

function DbBulkColList(const ACols: TDbStringArray; const ABackend: TDbKind): string;
begin
  try
    if ABackend = dbkMysql then
      Result := SqlColListMysql(ACols)
    else
      Result := SqlColList(ACols);
  except
    on E: ESqlError do raise EDbError.CreateSimple(ABackend, E.Message);
    on E: Exception do raise EDbError.CreateSimple(ABackend, E.Message);
  end;
end;

function DbBulkValList(const ARow: array of string): string;
var I, L, LCap: Integer; P, P0: PAnsiChar;
begin
  if Length(ARow) = 0 then Exit('');
  try
    LCap := 0;
    for I := 0 to High(ARow) do
    begin
      if I > 0 then Inc(LCap, 2);
      Inc(LCap, SqlLiteralTextLen(ARow[I]));
    end;
    SetLength(Result, LCap);
    if LCap = 0 then Exit;
    P := PAnsiChar(Result); P0 := P;
    for I := 0 to High(ARow) do
    begin
      if I > 0 then begin P[0] := ','; P[1] := ' '; Inc(P, 2); end;
      L := SqlWriteLiteralText(P, ARow[I]); Inc(P, L);
    end;
    SetLength(Result, P - P0);
  except
    on E: ESqlError do raise EDbError.CreateSimple(dbkUnknown, E.Message);
  end;
end;

function DbBulkInsertSql(const ATable, AColList: string; const ARow: array of string): string;
const CIns = 'INSERT INTO '; CParen = ' ('; CValues = ') VALUES ('; CRParen = ')';
var I, L, LCap: Integer; P, P0: PAnsiChar;
begin
  try
    LCap := Length(CIns) + SqlQuotedIdentLen(ATable) + Length(CParen) + Length(AColList) + Length(CValues) + Length(CRParen);
    for I := 0 to High(ARow) do
    begin
      if I > 0 then Inc(LCap, 2);
      Inc(LCap, SqlLiteralTextLen(ARow[I]));
    end;
    SetLength(Result, LCap);
    P := PAnsiChar(Result); P0 := P;
    Move(PAnsiChar(CIns)^, P^, Length(CIns)); Inc(P, Length(CIns));
    L := SqlWriteQuotedIdent(P, ATable); Inc(P, L);
    Move(PAnsiChar(CParen)^, P^, Length(CParen)); Inc(P, Length(CParen));
    if Length(AColList) > 0 then begin Move(PAnsiChar(AColList)^, P^, Length(AColList)); Inc(P, Length(AColList)); end;
    Move(PAnsiChar(CValues)^, P^, Length(CValues)); Inc(P, Length(CValues));
    for I := 0 to High(ARow) do
    begin
      if I > 0 then begin P[0] := ','; P[1] := ' '; Inc(P, 2); end;
      L := SqlWriteLiteralText(P, ARow[I]); Inc(P, L);
    end;
    Move(PAnsiChar(CRParen)^, P^, Length(CRParen)); Inc(P, Length(CRParen));
    SetLength(Result, P - P0);
  except
    on E: ESqlError do raise EDbError.CreateSimple(dbkUnknown, E.Message);
  end;
end;

function DbBulkMultiInsertSql(const ATable: string; const ACols: TDbStringArray;
  const ARows: TDbBulkRows; const AFrom, ACount: Integer): string;
begin
  Result := DbBulkMultiInsertSql(ATable, ACols, ARows, AFrom, ACount, dbkUnknown);
end;

function DbBulkMultiInsertSql(const ATable: string; const ACols: TDbStringArray;
  const ARows: TDbBulkRows; const AFrom, ACount: Integer; const ABackend: TDbKind): string;
const CIns = 'INSERT INTO '; CParen = ' ('; CValues = ') VALUES ';
var I, J, E, L, LCap: Integer; P, P0: PAnsiChar;
  function QuotedLen(const S: string): Integer; inline;
  begin
    if ABackend = dbkMysql then Result := SqlQuotedIdentLenMysql(S)
    else Result := SqlQuotedIdentLen(S);
  end;
  function WriteQuoted(Dst: PAnsiChar; const S: string): Integer; inline;
  begin
    if ABackend = dbkMysql then Result := SqlWriteQuotedIdentMysql(Dst, S)
    else Result := SqlWriteQuotedIdent(Dst, S);
  end;

begin
  if ACount <= 0 then Exit('');
  try
    LCap := Length(CIns) + QuotedLen(ATable) + Length(CParen) + Length(CValues);
    for I := 0 to High(ACols) do
    begin
      if I > 0 then Inc(LCap, 2);
      Inc(LCap, QuotedLen(ACols[I]));
    end;
    E := AFrom + ACount - 1;
    for I := AFrom to E do
    begin
      if I > AFrom then Inc(LCap, 2); // ', ' between rows
      Inc(LCap, 2); // '(' ')'
      for J := 0 to High(ARows[I]) do
      begin
        if J > 0 then Inc(LCap, 2);
        Inc(LCap, SqlLiteralTextLen(ARows[I][J]));
      end;
    end;
    SetLength(Result, LCap);
    P := PAnsiChar(Result); P0 := P;
    Move(PAnsiChar(CIns)^, P^, Length(CIns)); Inc(P, Length(CIns));
    L := WriteQuoted(P, ATable); Inc(P, L);
    Move(PAnsiChar(CParen)^, P^, Length(CParen)); Inc(P, Length(CParen));
    for I := 0 to High(ACols) do
    begin
      if I > 0 then begin P[0] := ','; P[1] := ' '; Inc(P, 2); end;
      L := WriteQuoted(P, ACols[I]); Inc(P, L);
    end;
    Move(PAnsiChar(CValues)^, P^, Length(CValues)); Inc(P, Length(CValues));
    for I := AFrom to E do
    begin
      if I > AFrom then begin P[0] := ','; P[1] := ' '; Inc(P, 2); end;
      P[0] := '('; Inc(P);
      for J := 0 to High(ARows[I]) do
      begin
        if J > 0 then begin P[0] := ','; P[1] := ' '; Inc(P, 2); end;
        L := SqlWriteLiteralText(P, ARows[I][J]); Inc(P, L);
      end;
      P[0] := ')'; Inc(P);
    end;
    SetLength(Result, P - P0);
  except
    on E: ESqlError do raise EDbError.CreateSimple(ABackend, E.Message);
  end;
end;

function DbBulkChunkRows(const AMaxPlaceholders, AColumnCount, ARowCount: Integer): Integer;
var
  LCols, LChunk: Integer;
begin
  LCols := AColumnCount;
  if LCols < 1 then LCols := 1;
  if AMaxPlaceholders <= 0 then
    LChunk := DbBulkFallbackChunkRows
  else
    LChunk := AMaxPlaceholders div LCols;
  if LChunk < 1 then LChunk := 1;
  if (ARowCount > 0) and (LChunk > ARowCount) then
    LChunk := ARowCount;
  Result := LChunk;
end;

procedure DbBulkFlushChunked(
  const ATable: string;
  const ACols: TDbStringArray;
  const ARows: TDbBulkRows;
  const AChunkRows: Integer;
  const AInTxn: Boolean;
  const AExec: TDbBulkExecProc;
  const ABeginTxn: TDbBulkBeginProc;
  const ACommitTxn, ARollbackTxn: TDbBulkTxnProc;
  const ABackend: TDbKind = dbkUnknown); overload;
begin
  DbBulkFlushChunked(ATable, ACols, ARows, AChunkRows, AInTxn, True,
    AExec, ABeginTxn, ACommitTxn, ARollbackTxn, ABackend);
end;

procedure DbBulkFlushChunked(
  const ATable: string;
  const ACols: TDbStringArray;
  const ARows: TDbBulkRows;
  const AChunkRows: Integer;
  const AInTxn: Boolean;
  const ASupportsSavepoints: Boolean;
  const AExec: TDbBulkExecProc;
  const ABeginTxn: TDbBulkBeginProc;
  const ACommitTxn, ARollbackTxn: TDbBulkTxnProc;
  const ABackend: TDbKind = dbkUnknown); overload;
  procedure DoFlush;
  var I, LRemain: Integer;
  begin
    I := 0;
    while I < Length(ARows) do
    begin
      LRemain := Length(ARows) - I;
      if LRemain > AChunkRows then
        AExec(DbBulkMultiInsertSql(ATable, ACols, ARows, I, AChunkRows, ABackend))
      else
        AExec(DbBulkMultiInsertSql(ATable, ACols, ARows, I, LRemain, ABackend));
      Inc(I, AChunkRows);
    end;
  end;
const
  CBulkSp = 'np_bulk_sp';
begin
  if (Length(ARows) = 0) or (AChunkRows <= 0) then Exit;
  if AInTxn then
  begin
    if ASupportsSavepoints then
    begin
      AExec('SAVEPOINT ' + CBulkSp);
      try
        DoFlush;
        try AExec('RELEASE SAVEPOINT ' + CBulkSp); except end;
      except
        try AExec('ROLLBACK TO SAVEPOINT ' + CBulkSp); except end;
        try AExec('RELEASE SAVEPOINT ' + CBulkSp); except end;
        raise;
      end;
    end
    else
      DoFlush;
  end
  else
  begin
    ABeginTxn(False);
    try
      DoFlush;
      ACommitTxn();
    except
      try ARollbackTxn(); except end;
      raise;
    end;
  end;
end;

procedure DbBulkBeginCopy(var ABuffer: TDbBulkBuffer; ABackend: TDbKind;
  const ATable: string; const AColumns: array of string);
begin
  ABuffer.BeginCopy(ABackend, ATable, AColumns);
end;

procedure DbBulkWriteRow(var ABuffer: TDbBulkBuffer; ABackend: TDbKind;
  const AValues: array of string);
begin
  ABuffer.WriteRow(ABackend, AValues);
end;

procedure DbBulkAbortCopy(var ABuffer: TDbBulkBuffer);
begin
  ABuffer.Clear;
end;

procedure DbBulkEndCopy(var ABuffer: TDbBulkBuffer; AMaxPlaceholders: Integer;
  AInTxn: Boolean; const AExec: TDbBulkExecProc;
  const ABeginTxn: TDbBulkBeginProc;
  const ACommitTxn, ARollbackTxn: TDbBulkTxnProc); overload;
begin
  DbBulkEndCopy(ABuffer, AMaxPlaceholders, AInTxn, True,
    AExec, ABeginTxn, ACommitTxn, ARollbackTxn);
end;

procedure DbBulkEndCopy(var ABuffer: TDbBulkBuffer; AMaxPlaceholders: Integer;
  AInTxn: Boolean; ASupportsSavepoints: Boolean; const AExec: TDbBulkExecProc;
  const ABeginTxn: TDbBulkBeginProc;
  const ACommitTxn, ARollbackTxn: TDbBulkTxnProc); overload;
begin
  if not ABuffer.IsActive then Exit;
  try
    if ABuffer.RowCount = 0 then Exit;
    DbBulkFlushBuffer(ABuffer, AMaxPlaceholders, AInTxn, ASupportsSavepoints,
      AExec, ABeginTxn, ACommitTxn, ARollbackTxn);
  finally
    ABuffer.Clear;
  end;
end;

procedure DbBulkFlushBuffer(
  const ABuffer: TDbBulkBuffer;
  const AMaxPlaceholders: Integer;
  const AInTxn: Boolean;
  const AExec: TDbBulkExecProc;
  const ABeginTxn: TDbBulkBeginProc;
  const ACommitTxn, ARollbackTxn: TDbBulkTxnProc); overload;
begin
  DbBulkFlushBuffer(ABuffer, AMaxPlaceholders, AInTxn, True,
    AExec, ABeginTxn, ACommitTxn, ARollbackTxn);
end;

procedure DbBulkFlushBuffer(
  const ABuffer: TDbBulkBuffer;
  const AMaxPlaceholders: Integer;
  const AInTxn: Boolean;
  const ASupportsSavepoints: Boolean;
  const AExec: TDbBulkExecProc;
  const ABeginTxn: TDbBulkBeginProc;
  const ACommitTxn, ARollbackTxn: TDbBulkTxnProc); overload;
var
  LCols: TDbStringArray;
  LRows: TDbBulkRows;
  LChunk: Integer;
begin
  if ABuffer.RowCount = 0 then Exit;
  LCols := ABuffer.Columns;
  LRows := ABuffer.Rows;
  LChunk := DbBulkChunkRows(AMaxPlaceholders, Length(LCols), ABuffer.RowCount);
  DbBulkFlushChunked(ABuffer.TableName, LCols, LRows, LChunk, AInTxn, ASupportsSavepoints,
    AExec, ABeginTxn, ACommitTxn, ARollbackTxn, ABuffer.FBackend);
end;

end.
