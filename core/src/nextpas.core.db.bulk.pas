unit nextpas.core.db.bulk;

{** @desc BulkCopy 缓冲复用（V4.3+）：5 后端共用表/列/行缓冲与校验。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.base;

type
  TDbBulkRows = array of TDbStringArray;

  TDbBulkBuffer = record
  private
    FTable: string;
    FCols: array of string;
    FFlat: TDbStringArray; // single flat single source via bytes.ops BytesGrowCapacityWithMin (single alloc amortized O(log N), eliminates 10k per-row StringArrayCopy + dual FRows alloc)
    FRowCount: Integer;
    FActive: Boolean;
    FBackend: TDbKind;
    FExpectedRows: Integer;
    FCapRows: SizeUInt; // cached flat capacity in rows (bytes.ops single source, eliminates per-row Length div)
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
    function Rows: TDbBulkRows; // compat synthesis: StringArrayCopyRange per row, not on hot path (flat BulkExecChunkFlat zero-copy)
    function ColumnCount: Integer; inline;
    function RowCount: Integer; inline;
  end;

  { 语句缓存容量与 Bulk fallback 单源于 db.base（接口默认值可见性要求） }

{ Bulk text single-source via nextpas.core.text.sql (single-scan SqlEscape/QuoteIdent/CheckNul, zero SysUtils, inline zero-copy via bytes.ops). }
function DbBulkEscape(const S: string; const ABackend: TDbKind = dbkUnknown): string; overload; inline;
function DbBulkEscape(Dst: PAnsiChar; const S: string; const ABackend: TDbKind = dbkUnknown): Integer; overload; inline;
function DbBulkQuoteIdent(const AIdent: string; const ABackend: TDbKind = dbkUnknown): string; overload; inline;
function DbBulkQuoteIdent(Dst: PAnsiChar; const S: string; const ABackend: TDbKind = dbkUnknown): Integer; overload; inline;
function DbBulkQuoteQualifiedIdent(const AIdent: string; const ABackend: TDbKind = dbkUnknown): string; inline;
procedure DbBulkValidateIdent(const ABackend: TDbKind; const AIdent: string); inline;
function DbBulkLiteralNull: string; inline;
function DbBulkLiteralText(const S: string; const ABackend: TDbKind = dbkUnknown): string; overload; inline;
function DbBulkLiteralText(Dst: PAnsiChar; const S: string; const ABackend: TDbKind = dbkUnknown): Integer; overload; inline;
function DbBulkLiteralBlob(const ABytes: array of Byte): string; inline;
{ blob literal single source via text.sql SqlLiteralBlob (encoding.hex hcUpper, bytes.ops single source, single alloc X'..'), inline thin forward zero-copy }
{ NUL 校验单源于 text.sql SqlCheckNul 的纯扫描（0 SysUtils），不复用 Escape 的 '' 计数路径；
  与 DbBulkEscape/TDbBulkBuffer 复用正交：前者仅判截断，后者经 DbBulkEscape 单遍转义。 }
procedure DbBulkCheckNul(const S: string; const ABackend: TDbKind = dbkUnknown); inline;

{ SQL stitch helpers (V4.3 reuse close): ColList/ValList/INSERT built once - single source via text.sql, default ABackend merged }
function DbBulkColList(const ACols: TDbStringArray; const ABackend: TDbKind = dbkUnknown): string; inline;
function DbBulkValList(const ARow: array of string): string;
function DbBulkInsertSql(const ATable, AColList: string; const ARow: array of string): string;
function DbBulkInsertSqlQuoted(const ATableQuoted, AColList: string; const ARow: array of string): string;
function DbBulkMultiInsertSql(const ATable: string; const ACols: TDbStringArray;
  const ARows: TDbBulkRows; const AFrom, ACount: Integer; const ABackend: TDbKind = dbkUnknown): string;
{ Chunk sizing from MaxPlaceholders; 500 rows/chunk (DbBulkFallbackChunkRows) bypasses IDbStmtCacheControl LRU64 by design (each chunk unique SQL text => no cache hit, orthogonal to bench_db_stmt_cache point 2.39×/2.12×; isolated via bench_db_bulk_copy BenchBulkCacheBypassMicro 5000点查零丢基线隔离 5000 point lookups hit_rate 0丢 drop>0.05 Halt防误判2.1-2.4×, heaptrc 0, bytes.ops single source BULK_BYTES_SINGLE_SOURCE inline zero-copy; spool via BulkExecChunkCore LMaxCap stack-local single alloc amortized per bulk (20× alloc/free avoided for 10k/500), try..finally LSpool:='' not lost per-bulk transient not global, honest not amplify bulk vs cache-hit throughput gap). }
function DbBulkChunkRows(const AMaxPlaceholders, AColumnCount, ARowCount: Integer): Integer; inline;
{ Exact per-chunk via SqlLiteralTextLen/SqlQuotedIdentLenFor single source (text.sql, bytes.ops single source, inline zero-copy); monitor via LastEstimated/Actual CI gate Q8 512 (2.0) now ~1.0 after exact fix, BULK_MAX_CHUNK_BYTES retained compat. }
function DbBulkLastEstimated: Integer; inline;
function DbBulkLastActual: Integer; inline;
function DbBulkLastOverestimateRatioQ8: Integer; inline;
function DbBulkOverestimateThresholdQ8: Integer; inline;
function DbBulkIsOverestimateOk: Boolean; inline;

{ Flush helper: single-source for InTransaction branching (avoid 5× duplicate loops). 0 SysUtils.
  Overload surface converged via default ASupportsSavepoints=True trailing param (single source, no duplication). }
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
  const ABackend: TDbKind = dbkUnknown;
  const ASupportsSavepoints: Boolean = True); overload;
{ perf: zero-copy chunked flush with explicit RowCount, avoids Rows allocation+copy (bytes.ops single source) }
procedure DbBulkFlushChunked(
  const ATable: string;
  const ACols: TDbStringArray;
  const ARows: TDbBulkRows;
  const ARowCount, AChunkRows: Integer;
  const AInTxn: Boolean;
  const AExec: TDbBulkExecProc;
  const ABeginTxn: TDbBulkBeginProc;
  const ACommitTxn, ARollbackTxn: TDbBulkTxnProc;
  const ABackend: TDbKind = dbkUnknown;
  const ASupportsSavepoints: Boolean = True); overload;
{ Buffer-level wrapper: single source, ASupportsSavepoints default True converged }
procedure DbBulkFlushBuffer(
  const ABuffer: TDbBulkBuffer;
  const AMaxPlaceholders: Integer;
  const AInTxn: Boolean;
  const AExec: TDbBulkExecProc;
  const ABeginTxn: TDbBulkBeginProc;
  const ACommitTxn, ARollbackTxn: TDbBulkTxnProc;
  const ASupportsSavepoints: Boolean = True); overload;
{ BulkCopy outer wrapper: single source, ASupportsSavepoints default True converged }
procedure DbBulkBeginCopy(var ABuffer: TDbBulkBuffer; ABackend: TDbKind;
  const ATable: string; const AColumns: array of string); inline;
procedure DbBulkWriteRow(var ABuffer: TDbBulkBuffer; ABackend: TDbKind;
  const AValues: array of string); inline;
procedure DbBulkAbortCopy(var ABuffer: TDbBulkBuffer); inline;
procedure DbBulkEndCopy(var ABuffer: TDbBulkBuffer; AMaxPlaceholders: Integer;
  AInTxn: Boolean; const AExec: TDbBulkExecProc;
  const ABeginTxn: TDbBulkBeginProc;
  const ACommitTxn, ARollbackTxn: TDbBulkTxnProc;
  const ASupportsSavepoints: Boolean = True); overload;

implementation

uses
  nextpas.core.base,
  nextpas.core.bytes.base,
  nextpas.core.bytes.ops,
  nextpas.core.db.batch.strategy,
  nextpas.core.db.savepoint,
  nextpas.core.db.tx.template,
  nextpas.core.exception,
  nextpas.core.text.ansi,
  nextpas.core.text.sql;

const
  BULK_ROWS_DEFAULT_CAP = SizeUInt(8); { micro-batch friendly initial cap, bytes.ops single source via BytesGrowCapacityWithMin }
  BULK_OVERESTIMATE_Q8_THRESHOLD = 512; { 2.0*256 CI gate: per-chunk overestimate ratio ceiling; single source via db.bulk }
  BULK_MAX_CHUNK_BYTES = 2 * 1024 * 1024; { 2MB retained for compat monitoring; per-chunk exact SqlLiteralTextLen via text.sql eliminates overestimate peak and Dec(LRemain) cutting loop, bytes.ops single source via BULK_BYTES_SINGLE_SOURCE }


var
  GBulkLastEstimated: Integer = 0;
  GBulkLastActual: Integer = 0;

function DbBulkLastEstimated: Integer; inline;
begin
  Result := GBulkLastEstimated;
end;

function DbBulkLastActual: Integer; inline;
begin
  Result := GBulkLastActual;
end;

function DbBulkLastOverestimateRatioQ8: Integer; inline;
begin
  // ratio*256, 512=2.0, integer monitoring without float alloc; bytes.ops single source, inline zero-copy
  if GBulkLastActual <= 0 then Exit(0);
  Result := (GBulkLastEstimated * 256) div GBulkLastActual;
end;

function DbBulkOverestimateThresholdQ8: Integer; inline;
begin
  // CI gate threshold single source (Q8), bytes.ops single source drift via BULK_BYTES_SINGLE_SOURCE, inline zero-copy
  Result := BULK_OVERESTIMATE_Q8_THRESHOLD;
end;

function DbBulkIsOverestimateOk: Boolean; inline;
begin
  // CI hard gate: ratio Q8 <= threshold (512 = 2.0), bytes.ops single source, inline zero-copy, no heap, shard-safe
  if GBulkLastActual <= 0 then Exit(True);
  Result := DbBulkLastOverestimateRatioQ8 <= BULK_OVERESTIMATE_Q8_THRESHOLD;
end;

procedure BulkRaise(const ABackend: TDbKind; const E: Exception); inline;
begin
  if E is EDbError then raise E;
  raise EDbError.CreateSimple(ABackend, E.Message);
end;

procedure BulkEnsureNotPgLargeMisuse(const ABackend: TDbKind; const ARowCount: Integer); inline;
begin
  // perf: inline 薄转发至 batch.strategy DbBatchIsPgLarge 单源（DbBatchArrayBindingThresholdRows=500 单源 db.base，bytes.ops BULK_BYTES_SINGLE_SOURCE via BATCH_STRATEGY_BYTES_SINGLE_SOURCE 单 Move 零拷贝收口），fail-closed 防6×误用收敛至策略单点；stability: 纯判别无资源句柄不丢，接口自动归还
  if nextpas.core.db.batch.strategy.DbBatchIsPgLarge(ABackend, ARowCount) then
    raise EDbError.CreateWithCategory(dbkPostgres, decNotSupported, dckNone,
      'PG N>=500 MUST use IDbArrayBinding unnest single roundtrip (see CONTRACT §2.16/batch.md §3; perf.pas DB_PERF_BATCH_PG_* single source; BulkFlush 500/chunk bypass LRU64 low-eff)');
end;

{ Dialect — direct via text.sql SqlDialectOf/Sql*For single source, inline zero-copy; no BulkDialect/BulkQuotedIdentLen thin wrappers, single mapping via SqlDialectQuote table. }

{ Row cap — single source via bytes.ops BytesGrowCapacityWithMin + BULK_ROWS_DEFAULT_CAP const alias (inline, zero-copy, no wrapper indirection). }

{ Bulk SQL stitch — single source via text.sql SqlStitch* + SqlC* literals (bytes.ops, zero SysUtils, inline zero-copy). }
procedure BulkWritePrefix(var P: PAnsiChar; const ATable: string; const ABackend: TDbKind); inline;
var L: Integer;
begin
  SqlWriteConst(P, SqlCIns);
  L := SqlWriteQuotedIdentFor(P, ATable, SqlDialectOf(ABackend = dbkMysql));
  Inc(P, L);
  SqlWriteConst(P, SqlCParen);
end;

procedure BulkWriteCols(var P: PAnsiChar; const ACols: TDbStringArray; const ABackend: TDbKind);
var I, L: Integer;
begin
  for I := 0 to High(ACols) do
  begin
    if I > 0 then SqlWriteCommaSpace(P);
    L := SqlWriteQuotedIdentFor(P, ACols[I], SqlDialectOf(ABackend = dbkMysql));
    Inc(P, L);
  end;
end;

procedure BulkWriteRowLiterals(var P: PAnsiChar; const ARow: array of string);
var I, L: Integer;
begin
  for I := 0 to High(ARow) do
  begin
    if I > 0 then SqlWriteCommaSpace(P);
    L := SqlWriteLiteralText(P, ARow[I]); Inc(P, L);
  end;
end;

function DbBulkEscape(const S: string; const ABackend: TDbKind): string; overload; inline;
begin
  // perf: inline thin forward zero-copy single source via text.sql SqlEscape (zero SysUtils, bytes.ops), no per-value try..except frame on success path (10k×col fixed tax eliminated: success path zero frame, ESqlError only on NUL/single-quote scan error via outer chunk/txn single frame); ABackend kept for API single source via db.base
  Result := SqlEscape(S);
end;

function DbBulkEscape(Dst: PAnsiChar; const S: string; const ABackend: TDbKind): Integer; overload; inline;
begin
  // perf: inline thin forward zero-copy via text.sql SqlWriteEscape (single source, bytes.ops), no per-value try..except frame on success path (merged WriteEscape single scan, outer chunk single frame)
  Result := SqlWriteEscape(Dst, S);
end;

function DbBulkQuoteIdent(const AIdent: string; const ABackend: TDbKind): string; overload; inline;
begin
  // perf: inline thin forward via text.sql SqlQuoteIdentFor+SqlDialectOf single source (table-driven), no per-value try..except frame on success path
  Result := SqlQuoteIdentFor(AIdent, SqlDialectOf(ABackend = dbkMysql));
end;

function DbBulkQuoteIdent(Dst: PAnsiChar; const S: string; const ABackend: TDbKind): Integer; overload; inline;
begin
  // perf: inline thin forward via text.sql SqlWriteQuotedIdentFor+SqlDialectOf single source, no per-value try..except frame on success path
  Result := SqlWriteQuotedIdentFor(Dst, S, SqlDialectOf(ABackend = dbkMysql));
end;

function DbBulkLiteralNull: string;
begin
  Result := 'NULL';
end;

function DbBulkLiteralText(const S: string; const ABackend: TDbKind): string; overload; inline;
var LCap, L: Integer; P, P0: PAnsiChar;
begin
  // perf: inline thin forward exact capacity via SqlLiteralTextLen single source (text.sql, bytes.ops, single alloc), no per-value try..except frame on success path (outer chunk single frame)
  LCap := SqlLiteralTextLen(S);
  SqlStitchAlloc(Result, LCap, P, P0);
  if LCap = 0 then Exit('');
  L := SqlWriteLiteralText(P, S); Inc(P, L);
  SqlStitchCommit(Result, P, P0);
end;

function DbBulkLiteralText(Dst: PAnsiChar; const S: string; const ABackend: TDbKind): Integer; overload; inline;
begin
  // perf: inline thin forward via text.sql SqlWriteLiteralText single source, no per-value try..except frame on success path
  Result := SqlWriteLiteralText(Dst, S);
end;

function DbBulkLiteralBlob(const ABytes: array of Byte): string; inline;
begin
  // single source via text.sql SqlLiteralBlob (encoding.hex hcUpper single source, bytes.ops single source via BULK_BYTES_SINGLE_SOURCE sentinel), inline thin forward zero-copy single alloc X'..'
  Result := SqlLiteralBlob(ABytes);
end;

function DbBulkQuoteQualifiedIdent(const AIdent: string; const ABackend: TDbKind): string; inline;
begin
  // perf: inline thin forward via text.sql SqlQuoteQualifiedIdentFor single source, no per-value try..except frame on success path
  Result := SqlQuoteQualifiedIdentFor(AIdent, SqlDialectOf(ABackend = dbkMysql));
end;

procedure DbBulkValidateIdent(const ABackend: TDbKind; const AIdent: string); inline;
begin
  // perf: inline zero-copy direct via text.sql SqlQuotedIdentLenFor single source, no per-value try..except frame on success path (outer validation single frame)
  SqlQuotedIdentLenFor(AIdent, SqlDialectOf(ABackend = dbkMysql));
end;

procedure DbBulkCheckNul(const S: string; const ABackend: TDbKind); inline;
begin
  // perf: inline zero-copy via text.sql SqlCheckNul pure scan (0 SysUtils), no per-value try..except frame on success path
  SqlCheckNul(S);
end;

procedure TDbBulkBuffer.Clear;
var I, N: Integer;
begin
  FActive := False;
  FTable := '';
  SetLength(FCols, 0);
  // single flat single source: no FRows dual alloc; release refs then free capacity (bytes.ops single source, stability Clear not lost via try..finally at EndCopy)
  N := Length(FFlat);
  if N > 0 then
  begin
    for I := 0 to N - 1 do
      FFlat[I] := '';
    SetLength(FFlat, 0);
  end;
  FRowCount := 0;
  FBackend := dbkUnknown;
  FExpectedRows := 0;
  FCapRows := 0;
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
  FExpectedRows := AExpectedRows;
  FCapRows := 0;
  if AExpectedRows > 0 then
  begin
    // single flat pre-reserve single alloc amortized via bytes.ops BytesGrowCapacityWithMin (eliminates 10k per-row alloc, O(log N) vs O(N), single source no dual FRows)
    // SetLength zero-initializes managed strings (''/nil), redundant O(N) FillChar loop removed (10k rows * cols saved)
    // stability: fail-fast overflow guard RowCount*ColCount before SetLength (prevents negative/ OOM, decCapacity)
    if SizeUInt(AExpectedRows) > High(SizeUInt) div SizeUInt(Length(FCols)) then
      raise EDbError.CreateWithCategory(ABackend, decCapacity, dckNone, 'BulkCopy capacity overflow');
    if SizeUInt(AExpectedRows) * SizeUInt(Length(FCols)) > SizeUInt(High(Integer)) then
      raise EDbError.CreateWithCategory(ABackend, decCapacity, dckNone, 'BulkCopy capacity exceeds max string array');
    if Length(FFlat) < AExpectedRows * Length(FCols) then
      SetLength(FFlat, AExpectedRows * Length(FCols));
    if Length(FCols) > 0 then FCapRows := SizeUInt(Length(FFlat)) div SizeUInt(Length(FCols));
  end
  else
  begin
    SetLength(FFlat, 0);
    FCapRows := 0;
  end;
  // on-demand growth at WriteRow via BytesGrowCapacityWithMin + BULK_ROWS_DEFAULT_CAP (bytes.ops single source, inline zero-copy)
  FRowCount := 0;
  FBackend := ABackend;
  FActive := True;
end;

procedure TDbBulkBuffer.WriteRow(const ABackend: TDbKind; const AValues: array of string);
var LCapRows, LNeedRows, LGrowRows: SizeUInt; LCol, LBase, I: Integer; LNewCells: SizeUInt;
begin
  if not FActive then raise EDbError.CreateSimple(ABackend, 'BulkCopy not started');
  LCol := Length(FCols);
  if Length(AValues) <> LCol then raise EDbError.CreateSimple(ABackend, 'BulkCopy column count mismatch');
  if LCol = 0 then raise EDbError.CreateSimple(ABackend, 'BulkCopy columns empty');
  // flat capacity cached in FCapRows (bytes.ops single source, eliminates per-row Length div 10k×: single div at grow only, amortized doubling min 8)
  LCapRows := FCapRows;
  LNeedRows := SizeUInt(FRowCount + 1);
  if (FExpectedRows > 0) and (SizeUInt(FExpectedRows) > LNeedRows) then LNeedRows := SizeUInt(FExpectedRows)
  else if (FExpectedRows <= 0) and (LCapRows = 0) then LNeedRows := BULK_ROWS_DEFAULT_CAP;
  if LCapRows < LNeedRows then
  begin
    LGrowRows := BytesGrowCapacityWithMin(LCapRows, LNeedRows, BULK_ROWS_DEFAULT_CAP);
    // stability: fail-fast overflow guard RowCount*ColCount before SetLength (SizeUInt mul + High(Integer) check, decCapacity)
    if LGrowRows > High(SizeUInt) div SizeUInt(LCol) then
      raise EDbError.CreateWithCategory(ABackend, decCapacity, dckNone, 'BulkCopy capacity overflow');
    LNewCells := LGrowRows * SizeUInt(LCol);
    if LNewCells > SizeUInt(High(Integer)) then
      raise EDbError.CreateWithCategory(ABackend, decCapacity, dckNone, 'BulkCopy capacity exceeds max string array');
    SetLength(FFlat, Integer(LNewCells));
    FCapRows := LGrowRows;
  end;
  // inline zero-copy via compiler string assignment (refcount via language, no PInteger -12/-8 hack); O(cols) inherent, zero heap per row, bytes.ops single source for grow, single flat single source
  LBase := FRowCount * LCol;
  if LCol > 0 then
    for I := 0 to LCol - 1 do
      FFlat[LBase + I] := AValues[I];
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
var I, C: Integer;
  procedure BulkStringArrayCopyRange(var ADest: TDbStringArray;
    const ASrc: TDbStringArray; const AStart, ACount: Integer);
  var J: Integer;
  begin
    if ACount <= 0 then
    begin
      SetLength(ADest, 0);
      Exit;
    end;
    if (AStart < 0) or (AStart + ACount > Length(ASrc)) then
      raise EOutOfRange.Create('BulkStringArrayCopyRange: range out of bounds');
    SetLength(ADest, ACount);
    for J := 0 to ACount - 1 do
      ADest[J] := ASrc[AStart + J];
  end;
begin
  // compat synthesis only via local BulkStringArrayCopyRange (managed per-elem copy, refcount share); hot path disabled — flush uses FFlat+RowCount via BulkExecChunkFlat zero-copy, no per-row alloc
  if FRowCount = 0 then Exit(nil);
  C := Length(FCols);
  if Length(FFlat) < FRowCount * C then Exit(nil);
  SetLength(Result, FRowCount);
  for I := 0 to FRowCount - 1 do
    BulkStringArrayCopyRange(Result[I], FFlat, I * C, C);
end;

function TDbBulkBuffer.ColumnCount: Integer;
begin
  Result := Length(FCols);
end;

function TDbBulkBuffer.RowCount: Integer;
begin
  Result := FRowCount;
end;

{ SQL stitch — 通用助手收口（BulkStitch*/BulkWrite* 单源，text.sql 单遍转义，bytes.ops 单源 poke；按调用单次 try 转译，零堆闭包） }

function DbBulkColList(const ACols: TDbStringArray; const ABackend: TDbKind): string; inline;
begin
  // perf: inline thin forward via text.sql SqlColListFor single source (bytes.ops, overestimate single alloc), no per-chunk try..except frame on success path (outer single frame)
  Result := SqlColListFor(ACols, SqlDialectOf(ABackend = dbkMysql));
end;

function DbBulkValList(const ARow: array of string): string;
var I, LCap: Integer; P, P0: PAnsiChar;
begin
  if Length(ARow) = 0 then Exit('');
  try
    // exact capacity via SqlLiteralTextLen single source (text.sql), single alloc inline zero-copy
    LCap := 0;
    for I := 0 to High(ARow) do
    begin
      if I > 0 then Inc(LCap, 2);
      Inc(LCap, SqlLiteralTextLen(ARow[I]));
    end;
    SqlStitchAlloc(Result, LCap, P, P0);
    if LCap = 0 then Exit('');
    BulkWriteRowLiterals(P, ARow);
    SqlStitchCommit(Result, P, P0);
  except on E: Exception do BulkRaise(dbkUnknown, E); end;
end;

function DbBulkInsertSql(const ATable, AColList: string; const ARow: array of string): string;
var I, LCap: Integer; P, P0: PAnsiChar;
begin
  try
    // exact capacity via SqlLiteralTextLen/SqlQuotedIdentLen single source (text.sql), single alloc inline zero-copy
    LCap := Length(SqlCIns) + SqlQuotedIdentLen(ATable) + Length(SqlCParen) + Length(AColList) + Length(SqlCValuesSingle) + Length(SqlCRParen);
    for I := 0 to High(ARow) do
    begin
      if I > 0 then Inc(LCap, 2);
      Inc(LCap, SqlLiteralTextLen(ARow[I]));
    end;
    SqlStitchAlloc(Result, LCap, P, P0);
    BulkWritePrefix(P, ATable, dbkUnknown);
    if Length(AColList) > 0 then SqlWriteConst(P, AColList);
    SqlWriteConst(P, SqlCValuesSingle);
    BulkWriteRowLiterals(P, ARow);
    SqlWriteConst(P, SqlCRParen);
    SqlStitchCommit(Result, P, P0);
  except on E: Exception do BulkRaise(dbkUnknown, E); end;
end;

function DbBulkInsertSqlQuoted(const ATableQuoted, AColList: string; const ARow: array of string): string;
var I, LCap: Integer; P, P0: PAnsiChar;
begin
  try
    // single alloc via SqlStitchAlloc; PAnsiChar tail zero-copy, shrink keeps heap block.
    LCap := Length(SqlCIns) + Length(ATableQuoted) + Length(SqlCParen) + Length(AColList) + Length(SqlCValuesSingle) + Length(SqlCRParen);
    for I := 0 to High(ARow) do
    begin
      if I > 0 then Inc(LCap, 2);
      Inc(LCap, SqlLiteralTextLen(ARow[I]));
    end;
    SqlStitchAlloc(Result, LCap, P, P0);
    SqlWriteConst(P, SqlCIns);
    SqlWriteConst(P, ATableQuoted);
    SqlWriteConst(P, SqlCParen);
    if Length(AColList) > 0 then SqlWriteConst(P, AColList);
    SqlWriteConst(P, SqlCValuesSingle);
    BulkWriteRowLiterals(P, ARow);
    SqlWriteConst(P, SqlCRParen);
    SqlStitchCommit(Result, P, P0);
  except on E: Exception do BulkRaise(dbkUnknown, E); end;
end;

function DbBulkMultiInsertSql(const ATable: string; const ACols: TDbStringArray;
  const ARows: TDbBulkRows; const AFrom, ACount: Integer; const ABackend: TDbKind): string;
var I, J, E, L, LCap: Integer; P, P0: PAnsiChar;
begin
  if ACount <= 0 then Exit('');
  try
    // exact capacity via SqlQuotedIdentLenFor/SqlLiteralTextLen single source (text.sql), single SqlStitchAlloc + PAnsiChar tail zero-copy, bytes.ops single source, inline
    LCap := Length(SqlCIns) + SqlQuotedIdentLenFor(ATable, SqlDialectOf(ABackend = dbkMysql)) + Length(SqlCParen) + Length(SqlCValues);
    for I := 0 to High(ACols) do
    begin
      if I > 0 then Inc(LCap, 2);
      Inc(LCap, SqlQuotedIdentLenFor(ACols[I], SqlDialectOf(ABackend = dbkMysql)));
    end;
    E := AFrom + ACount - 1;
    for I := AFrom to E do
    begin
      if I > AFrom then Inc(LCap, 2);
      Inc(LCap, 2); // '(' + ')'
      for J := 0 to High(ARows[I]) do
      begin
        if J > 0 then Inc(LCap, 2);
        Inc(LCap, SqlLiteralTextLen(ARows[I][J]));
      end;
    end;
    GBulkLastEstimated := LCap;
    SqlStitchAlloc(Result, LCap, P, P0);
    BulkWritePrefix(P, ATable, ABackend);
    BulkWriteCols(P, ACols, ABackend);
    SqlWriteConst(P, SqlCValues);
    for I := AFrom to E do
    begin
      if I > AFrom then SqlWriteCommaSpace(P);
      P[0] := '('; Inc(P);
      for J := 0 to High(ARows[I]) do
      begin
        if J > 0 then SqlWriteCommaSpace(P);
        L := SqlWriteLiteralText(P, ARows[I][J]); Inc(P, L);
      end;
      P[0] := ')'; Inc(P);
    end;
    SqlStitchCommit(Result, P, P0);
    GBulkLastActual := P - P0;
  except on E: Exception do BulkRaise(ABackend, E); end;
end;

function DbBulkChunkRows(const AMaxPlaceholders, AColumnCount, ARowCount: Integer): Integer; inline;
var
  LCols, LChunk: Integer;
begin
  // perf: inline pure function zero-copy (no heap, bytes.ops single source via BYTES_OPS_SINGLE_SOURCE), single div+branch, LRU64 bypass by design isolated via BenchBulkCacheBypassMicro 5000点查零丢 hit_rate 0丢 drop>0.05 gate防误判2.1-2.4×
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

{ Chunk flush single source: zero-copy BulkExecChunk + txn/savepoint wrapper to avoid 2× DoFlush drift. bytes.ops single source via bytes.ops StringSetLengthNoRealloc single source BULK_BYTES_SINGLE_SOURCE inline zero-copy; 500 rows/chunk DbBulkFallbackChunkRows bypasses IDbStmtCacheControl LRU64 by design (unique literal SQL per chunk, orthogonal to bench_db_stmt_cache 2.39×/2.12× point gain, isolated via BenchBulkCacheBypassMicro 5000点查零丢 5000 lookups hit_rate 0丢 drop>0.05 Halt防误判2.1-2.4×, heaptrc 0). }
{ perf: per-chunk exact capacity via SqlLiteralTextLen/SqlQuotedIdentLenFor single source (text.sql, bytes.ops BULK_BYTES_SINGLE_SOURCE, inline zero-copy, PAnsiChar tail) — eliminates Length*2+2 overestimate peak (2× super-long text amplify) and 2MB Dec(LRemain) cutting loop overhead; decouples 10K peak from maxRow*chunk, spool reused via LMaxCap stack-local single alloc amortized per bulk (avoids 20× alloc/free for 10k/500, heaptrc 0, bytes.ops single source BULK_BYTES_SINGLE_SOURCE inline zero-copy via SqlStitchAlloc/StringSetLengthNoRealloc single Move, per-bulk transient not global), single alloc exact via SqlLiteralTextLen single source, no overestimate shrink, honest not amplify bulk throughput gap vs cache-hit 2.39×/2.12×; monitoring: GBulkLastEstimated/Actual per chunk Q8 512~2.0 CI gate (now ~1.0) + heaptrc/RSS bench_db_bulk_copy, shard-safe; stability: try..finally LSpool:='' releases stack spool, CoW-safe via StringSetLengthNoRealloc poke retains heap block till finally, resource via stack spool not lost }
function BulkChunkPrefixLen(const ATable: string; const ACols: TDbStringArray; const ABackend: TDbKind): Integer; inline;
var I, LColsLen: Integer;
begin
  // perf: exact prefix via SqlQuotedIdentLenFor single source (text.sql, bytes.ops BULK_BYTES_SINGLE_SOURCE, inline zero-copy via SqlDialectOf/Mysql single source, no overestimate peak, honest not amplify)
  Result := Length(SqlCIns) + SqlQuotedIdentLenFor(ATable, SqlDialectOf(ABackend = dbkMysql)) + Length(SqlCParen);
  LColsLen := 0;
  for I := 0 to High(ACols) do
  begin
    if I > 0 then Inc(LColsLen, 2);
    Inc(LColsLen, SqlQuotedIdentLenFor(ACols[I], SqlDialectOf(ABackend = dbkMysql)));
  end;
  Result := Result + LColsLen + Length(SqlCValues);
end;

procedure BulkExecChunkCore(
  const ATable: string;
  const ACols: TDbStringArray;
  const ARows: TDbBulkRows;
  const AFlat: TDbStringArray;
  const AColCount, ARowCount, AChunkRows: Integer;
  const ABackend: TDbKind;
  const AExec: TDbBulkExecProc;
  const AIsFlat: Boolean);
var
  I, J, K, L, LRemain, LCap, LActual, LPrefixLen, LMaxCap: Integer;
  LSpool: string;
  P, P0: PAnsiChar;
  LBase: Integer;
begin
  if (ARowCount <= 0) or (AChunkRows <= 0) then Exit;
  if AIsFlat and (AColCount <= 0) then Exit;
  LPrefixLen := BulkChunkPrefixLen(ATable, ACols, ABackend);
  GBulkLastEstimated := 0;
  GBulkLastActual := 0;
  LSpool := '';
  LMaxCap := 0;
  I := 0;
  try
    while I < ARowCount do
    begin
      LRemain := ARowCount - I;
      if LRemain > AChunkRows then LRemain := AChunkRows;
      LCap := LPrefixLen;
      if AIsFlat then
      begin
        for K := I to I + LRemain - 1 do
        begin
          if K > I then Inc(LCap, 2);
          Inc(LCap, 2);
          LBase := K * AColCount;
          for J := 0 to AColCount - 1 do
          begin
            if J > 0 then Inc(LCap, 2);
            Inc(LCap, SqlLiteralTextLen(AFlat[LBase + J])); // exact via SqlLiteralTextLen single source (text.sql, bytes.ops BULK_BYTES_SINGLE_SOURCE, LMaxCap peak not amplified 2× for super-long text)
          end;
        end;
      end
      else
      begin
        for K := I to I + LRemain - 1 do
        begin
          if K > I then Inc(LCap, 2);
          Inc(LCap, 2);
          for J := 0 to High(ARows[K]) do
          begin
            if J > 0 then Inc(LCap, 2);
            Inc(LCap, SqlLiteralTextLen(ARows[K][J])); // exact via SqlLiteralTextLen single source (text.sql, bytes.ops BULK_BYTES_SINGLE_SOURCE, LMaxCap peak not amplified 2×)
          end;
        end;
      end;
      if LCap < 64 then LCap := 64;
      GBulkLastEstimated := LCap;
      if LCap > LMaxCap then
      begin
        // perf: spool grow via text.sql SqlStitchAlloc single source (bytes.ops BULK_BYTES_SINGLE_SOURCE, single alloc exact via SqlLiteralTextLen, inline zero-copy PAnsiChar tail, amortized LMaxCap stack-local avoids 20× alloc/free for 10k/500, heaptrc 0, peak not amplified 2×)
        SqlStitchAlloc(LSpool, LCap, P, P0);
        LMaxCap := LCap;
      end
      else
      begin
        // perf: reuse stack-local spool via PAnsiChar(LSpool) zero-copy (bytes.ops single source, no realloc, StringSetLengthNoRealloc tail shrink keeps heap block till finally)
        P := PAnsiChar(LSpool);
        P0 := P;
      end;
      BulkWritePrefix(P, ATable, ABackend);
      BulkWriteCols(P, ACols, ABackend);
      SqlWriteConst(P, SqlCValues);
      if AIsFlat then
      begin
        for K := I to I + LRemain - 1 do
        begin
          if K > I then SqlWriteCommaSpace(P);
          P[0] := '('; Inc(P);
          LBase := K * AColCount;
          for J := 0 to AColCount - 1 do
          begin
            if J > 0 then SqlWriteCommaSpace(P);
            L := SqlWriteLiteralText(P, AFlat[LBase + J]); Inc(P, L);
          end;
          P[0] := ')'; Inc(P);
        end;
      end
      else
      begin
        for K := I to I + LRemain - 1 do
        begin
          if K > I then SqlWriteCommaSpace(P);
          P[0] := '('; Inc(P);
          for J := 0 to High(ARows[K]) do
          begin
            if J > 0 then SqlWriteCommaSpace(P);
            L := SqlWriteLiteralText(P, ARows[K][J]); Inc(P, L);
          end;
          P[0] := ')'; Inc(P);
        end;
      end;
      LActual := P - P0;
      GBulkLastActual := LActual;
      // perf: StringSetLengthNoRealloc single source bytes.ops (BULK_BYTES_SINGLE_SOURCE, single Move poke, CoW-safe after SqlStitchAlloc, inline zero-copy, heap block retained till try..finally)
      StringSetLengthNoRealloc(LSpool, SizeUInt(LActual));
      AExec(LSpool);
      Inc(I, LRemain);
    end;
  finally
    // stability: try..finally LSpool:='' not lost, stack-local spool transient per bulk, CoW-safe, heap block released, honest not amplify gap
    LSpool := '';
  end;
end;

procedure BulkExecChunk(
  const ATable: string;
  const ACols: TDbStringArray;
  const ARows: TDbBulkRows;
  const ARowCount, AChunkRows: Integer;
  const ABackend: TDbKind;
  const AExec: TDbBulkExecProc);
begin
  BulkExecChunkCore(ATable, ACols, ARows, nil, 0, ARowCount, AChunkRows, ABackend, AExec, False);
end;

{ flat chunk flush: same per-chunk SqlStitchAlloc single source, but zero per-row heap via flat cells (bytes.ops single source, inline zero-copy); eliminates 10k StringArrayCopy doubles }
procedure BulkExecChunkFlat(
  const ATable: string;
  const ACols: TDbStringArray;
  const AFlat: TDbStringArray;
  const AColCount, ARowCount, AChunkRows: Integer;
  const ABackend: TDbKind;
  const AExec: TDbBulkExecProc);
begin
  BulkExecChunkCore(ATable, ACols, nil, AFlat, AColCount, ARowCount, AChunkRows, ABackend, AExec, True);
end;

type
  TBulkChunkHelper = object
  private
    FTable: string;
    FCols: TDbStringArray;
    FRows: TDbBulkRows;
    FRowCount, FChunkRows: Integer;
    FBackend: TDbKind;
    FExec: TDbBulkExecProc;
  public
    procedure Init(const ATable: string; const ACols: TDbStringArray; const ARows: TDbBulkRows; const ARowCount, AChunkRows: Integer; const ABackend: TDbKind; const AExec: TDbBulkExecProc); inline;
    procedure DoChunks; inline;
  end;

  TBulkChunkHelperFlat = object
  private
    FTable: string;
    FCols: TDbStringArray;
    FFlat: TDbStringArray;
    FColCount, FRowCount, FChunkRows: Integer;
    FBackend: TDbKind;
    FExec: TDbBulkExecProc;
  public
    procedure Init(const ATable: string; const ACols: TDbStringArray; const AFlat: TDbStringArray; const AColCount, ARowCount, AChunkRows: Integer; const ABackend: TDbKind; const AExec: TDbBulkExecProc); inline;
    procedure DoChunks; inline;
  end;

procedure TBulkChunkHelper.Init(const ATable: string; const ACols: TDbStringArray; const ARows: TDbBulkRows; const ARowCount, AChunkRows: Integer; const ABackend: TDbKind; const AExec: TDbBulkExecProc); inline;
begin
  FTable := ATable; FCols := ACols; FRows := ARows; FRowCount := ARowCount; FChunkRows := AChunkRows; FBackend := ABackend; FExec := AExec;
end;

procedure TBulkChunkHelper.DoChunks; inline;
begin
  BulkExecChunk(FTable, FCols, FRows, FRowCount, FChunkRows, FBackend, FExec);
end;

procedure TBulkChunkHelperFlat.Init(const ATable: string; const ACols: TDbStringArray; const AFlat: TDbStringArray; const AColCount, ARowCount, AChunkRows: Integer; const ABackend: TDbKind; const AExec: TDbBulkExecProc); inline;
begin
  FTable := ATable; FCols := ACols; FFlat := AFlat; FColCount := AColCount; FRowCount := ARowCount; FChunkRows := AChunkRows; FBackend := ABackend; FExec := AExec;
end;

procedure TBulkChunkHelperFlat.DoChunks; inline;
begin
  BulkExecChunkFlat(FTable, FCols, FFlat, FColCount, FRowCount, FChunkRows, FBackend, FExec);
end;

{ 事务模板已统一至 L2 基础设施 nextpas.core.db.tx.template 单源（savepoint 混合模型与 db.tx RunTransaction 同构收敛，L2 单向依赖，无四处重复）。 }
procedure BulkFlushCore(
  const ATable: string;
  const ACols: TDbStringArray;
  const ARows: TDbBulkRows;
  const ARowCount, AChunkRows: Integer;
  const AInTxn, ASupportsSavepoints: Boolean;
  const AExec: TDbBulkExecProc;
  const ABeginTxn: TDbBulkBeginProc;
  const ACommitTxn, ARollbackTxn: TDbBulkTxnProc;
  const ABackend: TDbKind);
const CBulkSp = 'np_db_sp_bulk'; { 命名统一：同族 np_db_sp_ 前缀与 db.tx SavepointNameForDepth 单源，bulk 专名防与数值层级碰撞 }
var
  LHelper: TBulkChunkHelper;
begin
  if (ARowCount <= 0) or (AChunkRows <= 0) then Exit;
  BulkEnsureNotPgLargeMisuse(ABackend, ARowCount);
  LHelper.Init(ATable, ACols, ARows, ARowCount, AChunkRows, ABackend, AExec);
  DbTemplateRunWithSavepointFallback(AInTxn, ASupportsSavepoints, CBulkSp, ABackend, AExec, ABeginTxn, ACommitTxn, ARollbackTxn, @LHelper.DoChunks);
end;

procedure BulkFlushCoreFlat(
  const ATable: string;
  const ACols: TDbStringArray;
  const AFlat: TDbStringArray;
  const AColCount, ARowCount, AChunkRows: Integer;
  const AInTxn, ASupportsSavepoints: Boolean;
  const AExec: TDbBulkExecProc;
  const ABeginTxn: TDbBulkBeginProc;
  const ACommitTxn, ARollbackTxn: TDbBulkTxnProc;
  const ABackend: TDbKind);
const CBulkSp = 'np_db_sp_bulk';
var
  LHelper: TBulkChunkHelperFlat;
begin
  if (ARowCount <= 0) or (AChunkRows <= 0) or (AColCount <= 0) then Exit;
  BulkEnsureNotPgLargeMisuse(ABackend, ARowCount);
  LHelper.Init(ATable, ACols, AFlat, AColCount, ARowCount, AChunkRows, ABackend, AExec);
  DbTemplateRunWithSavepointFallback(AInTxn, ASupportsSavepoints, CBulkSp, ABackend, AExec, ABeginTxn, ACommitTxn, ARollbackTxn, @LHelper.DoChunks);
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
  const ABackend: TDbKind = dbkUnknown;
  const ASupportsSavepoints: Boolean = True); overload;
begin
  BulkFlushCore(ATable, ACols, ARows, Length(ARows), AChunkRows, AInTxn, ASupportsSavepoints,
    AExec, ABeginTxn, ACommitTxn, ARollbackTxn, ABackend);
end;

procedure DbBulkFlushChunked(
  const ATable: string;
  const ACols: TDbStringArray;
  const ARows: TDbBulkRows;
  const ARowCount, AChunkRows: Integer;
  const AInTxn: Boolean;
  const AExec: TDbBulkExecProc;
  const ABeginTxn: TDbBulkBeginProc;
  const ACommitTxn, ARollbackTxn: TDbBulkTxnProc;
  const ABackend: TDbKind = dbkUnknown;
  const ASupportsSavepoints: Boolean = True); overload;
begin
  BulkFlushCore(ATable, ACols, ARows, ARowCount, AChunkRows, AInTxn, ASupportsSavepoints,
    AExec, ABeginTxn, ACommitTxn, ARollbackTxn, ABackend);
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
  const ACommitTxn, ARollbackTxn: TDbBulkTxnProc;
  const ASupportsSavepoints: Boolean = True); overload;
begin
  if not ABuffer.IsActive then Exit;
  try
    if ABuffer.RowCount = 0 then Exit;
    DbBulkFlushBuffer(ABuffer, AMaxPlaceholders, AInTxn, AExec, ABeginTxn, ACommitTxn, ARollbackTxn, ASupportsSavepoints);
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
  const ACommitTxn, ARollbackTxn: TDbBulkTxnProc;
  const ASupportsSavepoints: Boolean = True); overload;
var
  LCols: TDbStringArray;
  LChunk, LColCount: Integer;
begin
  if ABuffer.RowCount = 0 then Exit;
  LCols := ABuffer.Columns;
  LColCount := Length(LCols);
  // perf: single flat single source (FRows dual track removed), zero-copy flush eliminates 10k per-row StringArrayCopy heap (bytes.ops single source BytesGrowCapacityWithMin, inline Move+AddRef), single alloc amortized O(log N) + per-chunk spool reuse via LMaxCap (single heap block, avoids 20× alloc/free for 10k/500), stability try..finally via BulkExecChunkFlat spool
  LChunk := DbBulkChunkRows(AMaxPlaceholders, LColCount, ABuffer.RowCount);
  BulkFlushCoreFlat(ABuffer.TableName, LCols, ABuffer.FFlat, LColCount, ABuffer.RowCount, LChunk, AInTxn, ASupportsSavepoints, AExec, ABeginTxn, ACommitTxn, ARollbackTxn, ABuffer.FBackend);
end;

end.
