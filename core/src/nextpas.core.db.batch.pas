unit nextpas.core.db.batch;
{**
 * @desc L2 统一批量/流工厂（收敛 §2.9 大对象流与 §2.16 数组批量分面）。
 *  依赖：仅 L0-L2 单向，无上向，无同层循环。
 *  性能/稳定性：见实现段（inline 薄转发/bytes.ops 单源零拷贝，栈 object 零堆，接口自动归还）。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.db.bulk,
  nextpas.core.db.batch.strategy,
  nextpas.core.bytes.ops;

const
  BATCH_BYTES_SINGLE_SOURCE = BYTES_OPS_SINGLE_SOURCE;
  BATCH_BYTES_SINGLE_SOURCE_VERSION = BYTES_OPS_SINGLE_SOURCE_VERSION;
  DB_BLOB_STREAM_THRESHOLD = 65536; { §2.9 大对象流阈值，命名常量语义单源，bytes.ops 单源 inline 零拷贝，fail-closed }

{$I nextpas.core.bytes.ops.single_source.inc}

{ ---- 能力探测统一面（inline 薄转发，零拷贝；capprobe/intf 单源互证，batch 仅统一入口不自建成矩阵） ---- }
{ 单源：SupportsBulkCopy 等布尔与 IDbBulkCopy 等接口存在性由 intf/capprobe 单源定义（ProbeSupportsBulkCopy/Capabilities），batch 仅 inline 转发；API 面 5+4 薄转发为诚实分面收口，已与 capprobe 双处单源索引互证，零重复实现。 }

function DbBatchSupportsBulkCopy(const AConn: IDbConnection): Boolean; inline;
function DbBatchSupportsArrayBinding(const AConn: IDbConnection): Boolean; inline;
function DbBatchSupportsBatchExecutor(const AConn: IDbConnection): Boolean; inline;
function DbBatchSupportsLargeObjects(const AConn: IDbConnection): Boolean; inline;
function DbBatchSupportsRowBlob(const AConn: IDbConnection): Boolean; inline;

{ ---- 可选接口统一探测（nil = 未支持，honest absence；inline 薄转发，capprobe 单源） ---- }

function DbBatchTryBulkCopy(const AConn: IDbConnection; out ABulk: IDbBulkCopy): Boolean; inline;
function DbBatchTryArrayBinding(const AQry: IDbQuery; out ABind: IDbArrayBinding): Boolean; inline;
function DbBatchProbeArrayBinding(const AQry: IDbQuery): IDbArrayBinding; inline;
function DbBatchTryLargeObject(const AConn: IDbConnection; out ALarge: IDbLargeObjectControl): Boolean; inline;
function DbBatchTryRowBlob(const AConn: IDbConnection; out ARow: IDbRowBlobControl): Boolean; inline;
function DbBatchTryBatchExecutor(const AConn: IDbConnection; out AExec: IDbBatchExecutor): Boolean; inline;
function DbBatchShouldUseArrayBinding(const AKind: TDbKind; const ARows: Integer; const ASupportsArray: Boolean): Boolean; inline;
function DbBatchShouldUseArrayBindingForConn(const AConn: IDbConnection; const ARows: Integer): Boolean; inline;

{ ---- 统一批量写入（自适应择优；PG N≥500 MUST自动走IDbArrayBinding unnest单次往返防6×误用见CONTRACT §2.16，其余择优 BulkCopy>BatchExecutor>BulkFlush，单事务语义不变） ---- }
{ 语义不变：单事务批量，失败全回滚，空表无操作。bytes.ops 单源零拷贝由 bulk 承载；ArrayBinding为Query面但Router内自动路由对调用方透明。 }
function DbBatchWriteRows(const AConn: IDbConnection; const ATable: string;
  const ACols: TDbStringArray; const ARows: TDbBulkRows): Integer;

{ ---- 统一流面探测（blob 大小判据同 §2.9） ---- }
function DbBatchBlobUseStream(const ASize: Int64): Boolean; inline;

implementation

uses
  SysUtils,
  nextpas.core.text.builder,
  nextpas.core.text.sql,
  nextpas.core.db.tx.template;

{ ---- 通用 BulkFlush 适配：IDbConnection → TDbBulk*Proc 单源桥接 ---- }
{ 栈 object 零堆，接口自动归还；bulk BulkFlushCore 为事务单源模板。 }
type
  TDbBatchFlushHelper = object
  private
    FConn: IDbConnection;
  public
    procedure Init(const AConn: IDbConnection); inline;
    procedure Exec(const ASql: string); inline;
    procedure BeginTxn(const AImmediate: Boolean); inline;
    procedure CommitTxn; inline;
    procedure RollbackTxn; inline;
  end;

procedure TDbBatchFlushHelper.Init(const AConn: IDbConnection); inline;
begin
  FConn := AConn;
end;

procedure TDbBatchFlushHelper.Exec(const ASql: string); inline;
begin
  FConn.Exec(ASql);
end;

procedure TDbBatchFlushHelper.BeginTxn(const AImmediate: Boolean); inline;
var
  LTx: IDbTxControl;
begin
  if Supports(FConn, IDbTxControl, LTx) and (LTx <> nil) then
    LTx.BeginTxn(AImmediate);
end;

procedure TDbBatchFlushHelper.CommitTxn; inline;
var
  LTx: IDbTxControl;
begin
  if Supports(FConn, IDbTxControl, LTx) and (LTx <> nil) then
    LTx.CommitTxn;
end;

procedure TDbBatchFlushHelper.RollbackTxn; inline;
var
  LTx: IDbTxControl;
begin
  if Supports(FConn, IDbTxControl, LTx) and (LTx <> nil) then
    LTx.RollbackTxn;
end;

function BatchChunkSize(const AMaxPlaceholders, ACols, ARows: Integer): Integer; inline;
begin
  Result := DbBulkChunkRows(AMaxPlaceholders, ACols, ARows);
  if Result <= 0 then Result := DbBulkFallbackChunkRows;
  if (ARows > 0) and (Result > ARows) then Result := ARows;
end;

type
  TDbBatchExecChunkHelper = object
  private
    FTable: string;
    FCols: TDbStringArray;
    FRows: TDbBulkRows;
    FChunk: Integer;
    FRowCount: Integer;
    FKind: TDbKind;
    FExec: IDbBatchExecutor;
  public
    procedure Init(const ATable: string; const ACols: TDbStringArray; const ARows: TDbBulkRows; const AChunk, ARowCount: Integer; const AKind: TDbKind; const AExec: IDbBatchExecutor); inline;
    procedure DoChunks; inline;
  end;

procedure TDbBatchExecChunkHelper.Init(const ATable: string; const ACols: TDbStringArray; const ARows: TDbBulkRows; const AChunk, ARowCount: Integer; const AKind: TDbKind; const AExec: IDbBatchExecutor); inline;
begin
  FTable := ATable; FCols := ACols; FRows := ARows; FChunk := AChunk; FRowCount := ARowCount; FKind := AKind; FExec := AExec;
end;

procedure TDbBatchExecChunkHelper.DoChunks; inline;
var
  I, LRemain: Integer;
  LSteps: TDbSqlSteps;
begin
  SetLength(LSteps, 1);
  try
    I := 0;
    while I < FRowCount do
    begin
      LRemain := FRowCount - I;
      if LRemain > FChunk then LRemain := FChunk;
      LSteps[0] := DbBulkMultiInsertSql(FTable, FCols, FRows, I, LRemain, FKind);
      try
        FExec.ExecuteBatch(LSteps);
      finally
        LSteps[0] := '';
      end;
      Inc(I, LRemain);
    end;
  finally
    if Length(LSteps) > 0 then LSteps[0] := '';
    SetLength(LSteps, 0);
  end;
end;

function DbBatchSupportsBulkCopy(const AConn: IDbConnection): Boolean; inline;
var
  LCap: IDbCapabilities;
begin
  Result := False;
  if AConn = nil then Exit;
  LCap := nil;
  if Supports(AConn, IDbCapabilities, LCap) and (LCap <> nil) then
    Result := LCap.SupportsBulkCopy
  else
    Result := Supports(AConn, IDbBulkCopy);
end;

function DbBatchSupportsArrayBinding(const AConn: IDbConnection): Boolean; inline;
var
  LCap: IDbCapabilities;
begin
  Result := False;
  if AConn = nil then Exit;
  LCap := nil;
  if Supports(AConn, IDbCapabilities, LCap) and (LCap <> nil) then
    Result := LCap.SupportsArrayBinding
  else
    Result := False;
end;

function DbBatchSupportsBatchExecutor(const AConn: IDbConnection): Boolean; inline;
var
  LCap: IDbCapabilities;
begin
  Result := False;
  if AConn = nil then Exit;
  LCap := nil;
  if Supports(AConn, IDbCapabilities, LCap) and (LCap <> nil) then
    Result := LCap.SupportsBatchExecutor
  else
    Result := Supports(AConn, IDbBatchExecutor);
end;

function DbBatchSupportsLargeObjects(const AConn: IDbConnection): Boolean; inline;
var
  LCap: IDbCapabilities;
begin
  Result := False;
  if AConn = nil then Exit;
  LCap := nil;
  if Supports(AConn, IDbCapabilities, LCap) and (LCap <> nil) then
    Result := LCap.SupportsLargeObjects
  else
    Result := Supports(AConn, IDbLargeObjectControl);
end;

function DbBatchSupportsRowBlob(const AConn: IDbConnection): Boolean; inline;
begin
  Result := False;
  if AConn = nil then Exit;
  Result := Supports(AConn, IDbRowBlobControl);
end;

function DbBatchTryBulkCopy(const AConn: IDbConnection; out ABulk: IDbBulkCopy): Boolean; inline;
begin
  ABulk := nil;
  Result := False;
  if AConn = nil then Exit;
  Result := Supports(AConn, IDbBulkCopy, ABulk);
end;

function DbBatchTryArrayBinding(const AQry: IDbQuery; out ABind: IDbArrayBinding): Boolean; inline;
begin
  ABind := nil;
  Result := False;
  if AQry = nil then Exit;
  Result := Supports(AQry, IDbArrayBinding, ABind);
end;

function DbBatchProbeArrayBinding(const AQry: IDbQuery): IDbArrayBinding; inline;
begin
  Result := nil;
  if AQry = nil then Exit;
  Supports(AQry, IDbArrayBinding, Result);
end;

function DbBatchTryLargeObject(const AConn: IDbConnection; out ALarge: IDbLargeObjectControl): Boolean; inline;
begin
  ALarge := nil;
  Result := False;
  if AConn = nil then Exit;
  Result := Supports(AConn, IDbLargeObjectControl, ALarge);
end;

function DbBatchTryRowBlob(const AConn: IDbConnection; out ARow: IDbRowBlobControl): Boolean; inline;
begin
  ARow := nil;
  Result := False;
  if AConn = nil then Exit;
  Result := Supports(AConn, IDbRowBlobControl, ARow);
end;

function DbBatchTryBatchExecutor(const AConn: IDbConnection; out AExec: IDbBatchExecutor): Boolean; inline;
begin
  AExec := nil;
  Result := False;
  if AConn = nil then Exit;
  Result := Supports(AConn, IDbBatchExecutor, AExec);
end;

function DbBatchShouldUseArrayBinding(const AKind: TDbKind; const ARows: Integer; const ASupportsArray: Boolean): Boolean; inline;
begin
  Result := nextpas.core.db.batch.strategy.DbBatchShouldUseArrayBinding(AKind, ARows, ASupportsArray);
end;

function DbBatchShouldUseArrayBindingForConn(const AConn: IDbConnection; const ARows: Integer): Boolean; inline;
var LCap: IDbCapabilities;
begin
  Result := False;
  if (AConn = nil) or (ARows < DbBatchArrayBindingThresholdRows) then Exit;
  LCap := nil;
  if Supports(AConn, IDbCapabilities, LCap) and (LCap <> nil) then
    Result := nextpas.core.db.batch.strategy.DbBatchShouldUseArrayBinding(LCap.Kind, ARows, LCap.SupportsArrayBinding)
  else
    Result := False;
end;

{ ---- 批量策略对象（自适应择优；策略表已分治至 batch.strategy） ---- }
{ PG N>=500 MUST走 IDbArrayBinding unnest 单次往返（CONTRACT §2.16）；其余择优 BulkCopy>BatchExecutor>BulkFlush，阈值以 CONTRACT 为准。 }
type
  TDbBatchRouteCtx = record
    Kind: TDbKind;
    MaxPlaceholders: Integer;
    SupportsBulk: Boolean;
    SupportsBatch: Boolean;
  end;

  TDbBatchRouter = object
  private
    FConn: IDbConnection;
    FTable: string;
    FCols: TDbStringArray;
    FRows: TDbBulkRows;
    function TryArray: Boolean; // PG N>=500 MUST array (CONTRACT §2.16)
    procedure ExecBulk(const ABulk: IDbBulkCopy);
    procedure ExecBatch(const AExec: IDbBatchExecutor; const ACtx: TDbBatchRouteCtx);
    procedure ExecFlush(const ACtx: TDbBatchRouteCtx);
  public
    procedure Init(const AConn: IDbConnection; const ATable: string; const ACols: TDbStringArray; const ARows: TDbBulkRows); inline;
    procedure Run;
  end;

function TDbBatchRouter.TryArray: Boolean;
var
  LQ: IDbQuery;
  LBind: IDbArrayBinding;
  LN, LC, I, R: Integer;
  LSql: string;
  LPlace, LColsQuoted, LTableQuoted: string;
  LColVals: TDbStringArray;
  LB: TBufStringBuilder;
  LCap: SizeUInt;
begin
  Result := False;
  LN := Length(FRows);
  LC := Length(FCols);
  if (FConn = nil) or (LN < DbBatchArrayBindingThresholdRows) or (LC = 0) then Exit;
  if not DbBatchShouldUseArrayBindingForConn(FConn, LN) then Exit;
  // unnest single-roundtrip per CONTRACT §2.16
  LTableQuoted := DbBulkQuoteIdent(FTable, dbkPostgres);
  LCap := TBufEstimateForJoin(SizeUInt(LC) * 9, SizeUInt(LC), 2);
  LB.Init(LCap);
  try
    for I := 0 to LC - 1 do
    begin
      if I > 0 then LB.AppendStr(', ');
      LB.AppendStr('?::text[]');
    end;
    LPlace := LB.ToString;
  finally
    LB.Done;
  end;
  LColsQuoted := SqlColListFor(FCols, sdStandard);
  LCap := BuilderCapForTwo(SizeUInt(Length('INSERT INTO ')) + SizeUInt(Length(LTableQuoted)), SizeUInt(Length(' (')) + SizeUInt(Length(LColsQuoted)));
  LCap := BuilderCapAdd(LCap, SizeUInt(Length(') SELECT * FROM unnest(')) + SizeUInt(Length(LPlace)) + 1);
  LB.Init(LCap);
  try
    LB.AppendStr('INSERT INTO ');
    LB.AppendStr(LTableQuoted);
    LB.AppendStr(' (');
    LB.AppendStr(LColsQuoted);
    LB.AppendStr(') SELECT * FROM unnest(');
    LB.AppendStr(LPlace);
    LB.AppendStr(')');
    LSql := LB.ToString;
  finally
    LB.Done;
  end;
  LQ := FConn.Query(LSql);
  LBind := DbBatchProbeArrayBinding(LQ);
  if LBind = nil then Exit;
  LBind.BeginBind(LN);
  SetLength(LColVals, LN);
  try
    for I := 0 to LC - 1 do
    begin
      for R := 0 to LN - 1 do
        if (R <= High(FRows)) and (I <= High(FRows[R])) then
          LColVals[R] := FRows[R][I]
        else
          LColVals[R] := '';
      LBind.BindTextColumn(I + 1, LColVals);
    end;
  finally
    for R := 0 to LN - 1 do
      LColVals[R] := '';
    SetLength(LColVals, 0);
  end;
  while LQ.Step do ;
  LBind := nil;
  LQ := nil;
  Result := True;
end;

procedure TDbBatchRouter.ExecBulk(const ABulk: IDbBulkCopy);
var
  I: Integer;
begin
  ABulk.BeginCopy(FTable, FCols);
  try
    for I := 0 to High(FRows) do
      ABulk.WriteRow(FRows[I]);
    ABulk.EndCopy;
  except
    try ABulk.AbortCopy; except end;
    raise;
  end;
end;

procedure TDbBatchRouter.ExecBatch(const AExec: IDbBatchExecutor; const ACtx: TDbBatchRouteCtx);
var
  LRows, LChunk: Integer;
  LTx: IDbTxControl;
  LSp: IDbSavepointControl;
  LFlushHelper: TDbBatchFlushHelper;
  LChunkHelper: TDbBatchExecChunkHelper;
  LInTxn, LSupportsSP: Boolean;
begin
  LRows := Length(FRows);
  if LRows = 0 then Exit;
  LChunk := BatchChunkSize(ACtx.MaxPlaceholders, Length(FCols), LRows);
  LTx := nil;
  LInTxn := False;
  if (FConn <> nil) and Supports(FConn, IDbTxControl, LTx) and (LTx <> nil) then
    LInTxn := LTx.InTransaction;
  LSupportsSP := Supports(FConn, IDbSavepointControl, LSp);
  LFlushHelper.Init(FConn);
  LChunkHelper.Init(FTable, FCols, FRows, LChunk, LRows, ACtx.Kind, AExec);
  DbTemplateRunWithSavepointFallback(LInTxn, LSupportsSP, 'np_db_sp_batch', ACtx.Kind,
    @LFlushHelper.Exec, @LFlushHelper.BeginTxn, @LFlushHelper.CommitTxn, @LFlushHelper.RollbackTxn,
    @LChunkHelper.DoChunks);
end;

procedure TDbBatchRouter.ExecFlush(const ACtx: TDbBatchRouteCtx);
var
  LCap: IDbCapabilities;
  LTx: IDbTxControl;
  LSp: IDbSavepointControl;
  LHelper: TDbBatchFlushHelper;
  LMax, LChunk, LRows: Integer;
  LInTxn, LSupportsSP: Boolean;
begin
  LRows := Length(FRows);
  if DbBatchShouldUseArrayBindingForConn(FConn, LRows) then
    raise EDbError.CreateWithCategory(dbkPostgres, decNotSupported, dckNone,
      'PG N>=500 MUST use IDbArrayBinding unnest single roundtrip (see CONTRACT §2.16/batch.md §3; perf.pas DB_PERF_BATCH_PG_* single source)');
  LInTxn := False;
  if Supports(FConn, IDbTxControl, LTx) and (LTx <> nil) then
    LInTxn := LTx.InTransaction;
  LSupportsSP := Supports(FConn, IDbSavepointControl, LSp);
  LMax := ACtx.MaxPlaceholders;
  if (LMax = 0) and Supports(FConn, IDbCapabilities, LCap) and (LCap <> nil) then
  begin
    LMax := LCap.MaxPlaceholders;
    if not LSupportsSP then
      LSupportsSP := LCap.SupportsSavepoints;
  end;
  LHelper.Init(FConn);
  LChunk := BatchChunkSize(LMax, Length(FCols), LRows);
  DbBulkFlushChunked(FTable, FCols, FRows, LChunk, LInTxn,
    @LHelper.Exec, @LHelper.BeginTxn, @LHelper.CommitTxn, @LHelper.RollbackTxn,
    ACtx.Kind, LSupportsSP);
end;

procedure TDbBatchRouter.Init(const AConn: IDbConnection; const ATable: string; const ACols: TDbStringArray; const ARows: TDbBulkRows); inline;
begin
  FConn := AConn;
  FTable := ATable;
  FCols := ACols;
  FRows := ARows;
end;

procedure TDbBatchRouter.Run;
var
  LCtx: TDbBatchRouteCtx;
  LBulk: IDbBulkCopy;
  LExec: IDbBatchExecutor;
  LCap: IDbCapabilities;
  LRows, LCols, LCells: Integer;
  LKind: TDbBatchKind;
begin
  if TryArray then Exit;
  LCtx.Kind := dbkUnknown;
  LCtx.MaxPlaceholders := 0;
  LCtx.SupportsBulk := False;
  LCtx.SupportsBatch := False;
  LBulk := nil; LExec := nil; LCap := nil;
  if FConn <> nil then
  begin
    LCtx.Kind := FConn.Kind;
    if Supports(FConn, IDbCapabilities, LCap) and (LCap <> nil) then
    begin
      LCtx.Kind := LCap.Kind;
      LCtx.MaxPlaceholders := LCap.MaxPlaceholders;
    end;
    LCtx.SupportsBulk := Supports(FConn, IDbBulkCopy, LBulk);
    LCtx.SupportsBatch := Supports(FConn, IDbBatchExecutor, LExec);
  end;
  // not inline: for-loop over strategy table (design-conventions 红线2)
  LRows := Length(FRows);
  LCols := Length(FCols);
  LCells := LRows * LCols;
  LKind := DbBatchStrategyPick(LRows, LCells, LCtx.Kind, LCtx.MaxPlaceholders, LCtx.SupportsBulk, LCtx.SupportsBatch);
  case LKind of
    bkBulkCopy:
      if LBulk <> nil then ExecBulk(LBulk) else ExecFlush(LCtx);
    bkBatchExecutor:
      if LExec <> nil then ExecBatch(LExec, LCtx) else ExecFlush(LCtx);
  else
    ExecFlush(LCtx);
  end;
end;

function DbBatchWriteRows(const AConn: IDbConnection; const ATable: string;
  const ACols: TDbStringArray; const ARows: TDbBulkRows): Integer;
var
  LRouter: TDbBatchRouter;
begin
  Result := 0;
  if (AConn = nil) or (ATable = '') or (Length(ACols) = 0) then Exit;
  if Length(ARows) = 0 then Exit(0);
  LRouter.Init(AConn, ATable, ACols, ARows);
  LRouter.Run;
  Result := Length(ARows);
end;

function DbBatchBlobUseStream(const ASize: Int64): Boolean; inline;
begin
  Result := ASize > DB_BLOB_STREAM_THRESHOLD;
end;

end.
