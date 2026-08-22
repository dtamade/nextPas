unit nextpas.core.db.sqlite.tx;

{** @desc SQLite L2 transaction helper (B7).
       - WithTransaction(ADb, AProc)：BEGIN 在前，成功自动 COMMIT；
         任何异常自动 ROLLBACK 并重抛原异常，所有路径收支平衡。
       - 'procedure 式 Exec' 隔离：AProc 内任意次 Exec 全部原子（all-or-nothing）。
       - 嵌套事务保护（计数式）：每连接维护深度计数，内层 WithTransaction
         只加深计数（不再开第二个 SQLite 事务），随最外层 COMMIT/ROLLBACK
         一同生效/回滚。
       - 与裸 Exec('BEGIN') 混用被拒绝（sqlite autocommit 守卫）：
         事务控制必须统一走本助手，避免提交/回滚归属错乱。*}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.db.sqlite.base,
  nextpas.core.db.sqlite.conn,
  nextpas.core.sync;

type
  { 事务误用（Begin/Commit/Rollback 不配对、nil 回调、已开外部事务）。 }
  ESqliteTxError = class(ENextPasError)
  public
    constructor Create(const AMessage: string);
  end;

  { WithTransaction 的回调；AProc 内 Exec 即事务体。 }
  TSqliteTxProc = reference to procedure;

  { 开启事务（计数式；嵌套 Begin 加深同一事务）。
    AImmediate=True 发 BEGIN IMMEDIATE（伊始取写锁）。一行事务一律
    Begin/Commit/Rollback 配对，或直接用 WithTransaction。 }
  procedure BeginTxn(const ADb: TSqliteDb; const AImmediate: Boolean = False);
  { 提交最外层事务（深度 1）；内层调用仅降一层计数。 }
  procedure CommitTxn(const ADb: TSqliteDb);
  { 回滚整个事务（任意深度）并清零计数。 }
  procedure RollbackTxn(const ADb: TSqliteDb);
  { 当前连接上是否有助手开启的事务。 }
  function InTransaction(const ADb: TSqliteDb): Boolean;
  { 当前连接上的助手事务深度（0 = 无）。 }
  function TxDepth(const ADb: TSqliteDb): Integer;
  { 原子执行 AProc：成功自动提交；异常自动回滚并重抛。嵌套安全。 }
  procedure WithTransaction(const ADb: TSqliteDb; const AProc: TSqliteTxProc);
  { 恢复助手簿记深度（不开新事务、不动数据库状态）。供泛化事务层
    （nextpas.core.db.tx）实现嵌套失败路径，消费方不要直接调用。 }
  procedure SetTxnDepth(const ADb: TSqliteDb; const ADepth: Integer);

implementation

uses
  nextpas.core.db.sqlite.ffi;

type
  TSqliteTxEntry = record
    Db: TSqliteDb;
    Depth: Integer;
  end;

var
  TxLock: INativeMutex;
  TxEntries: array of TSqliteTxEntry;

function FindEntryIndex(const ADb: TSqliteDb): Integer;
var
  I: Integer;
begin
  for I := 0 to High(TxEntries) do
    if TxEntries[I].Db = ADb then
      Exit(I);
  Result := -1;
end;

procedure RemoveEntry(const AIndex: Integer);
begin
  TxEntries[AIndex] := TxEntries[High(TxEntries)];
  SetLength(TxEntries, Length(TxEntries) - 1);
end;

procedure SetDepth(const ADb: TSqliteDb; const AValue: Integer);
var
  I: Integer;
begin
  TxLock.Acquire;
  try
    I := FindEntryIndex(ADb);
    if I >= 0 then
      TxEntries[I].Depth := AValue
    else if AValue <> 0 then
      raise ESqliteTxError.Create('transaction bookkeeping lost for this connection');
  finally
    TxLock.Release;
  end;
end;

{ 回滚并清计数；回滚失败吞掉（原异常由调用方重抛）。 }
procedure DropAfterRollback(const ADb: TSqliteDb);
var
  I: Integer;
begin
  TxLock.Acquire;
  try
    I := FindEntryIndex(ADb);
    if I >= 0 then
    begin
      try
        ADb.Exec('ROLLBACK');
      except
      end;
      RemoveEntry(I);
    end;
  finally
    TxLock.Release;
  end;
end;

constructor ESqliteTxError.Create(const AMessage: string);
begin
  inherited Create(AMessage);
end;

procedure BeginTxn(const ADb: TSqliteDb; const AImmediate: Boolean);
var
  I: Integer;
begin
  if ADb = nil then
    raise ESqliteTxError.Create('BeginTxn on a nil connection');
  TxLock.Acquire;
  try
    I := FindEntryIndex(ADb);
    if I >= 0 then
      Inc(TxEntries[I].Depth)
    else
    begin
      { autocommit=0 且无助手记录 ⇒ 有裸 Exec('BEGIN') 的事务悬着，拒绝混用。 }
      if sqlite3_get_autocommit(ADb.Handle) = 0 then
        raise ESqliteTxError.Create(
          'a transaction is already open on this connection outside the tx helper; ' +
          'route all transaction control through BeginTxn/WithTransaction');
      if AImmediate then
        ADb.Exec('BEGIN IMMEDIATE')
      else
        ADb.Exec('BEGIN');
      SetLength(TxEntries, Length(TxEntries) + 1);
      TxEntries[High(TxEntries)].Db := ADb;
      TxEntries[High(TxEntries)].Depth := 1;
    end;
  finally
    TxLock.Release;
  end;
end;

procedure CommitTxn(const ADb: TSqliteDb);
var
  I: Integer;
begin
  if ADb = nil then
    raise ESqliteTxError.Create('CommitTxn on a nil connection');
  TxLock.Acquire;
  try
    I := FindEntryIndex(ADb);
    if I < 0 then
      raise ESqliteTxError.Create('CommitTxn without a matching BeginTxn on this connection');
    if TxEntries[I].Depth > 1 then
    begin
      { 内层逻辑提交：只降计数，真实 COMMIT 归最外层。 }
      Dec(TxEntries[I].Depth);
      Exit;
    end;
    { 助手认为在事务内但 autocommit 已开 ⇒ 事务被外部语句偷偷关了，拒绝提交。 }
    if sqlite3_get_autocommit(ADb.Handle) <> 0 then
      raise ESqliteTxError.Create(
        'transaction was closed outside the tx helper; commit aborted');
    ADb.Exec('COMMIT');       { 失败 ⇒ 异常；计数保留，调用方可 RollbackTxn 收拾 }
    RemoveEntry(I);
  finally
    TxLock.Release;
  end;
end;

procedure RollbackTxn(const ADb: TSqliteDb);
var
  I: Integer;
begin
  if ADb = nil then
    raise ESqliteTxError.Create('RollbackTxn on a nil connection');
  TxLock.Acquire;
  try
    I := FindEntryIndex(ADb);
    if I < 0 then
      raise ESqliteTxError.Create('RollbackTxn without a matching BeginTxn on this connection');
    if sqlite3_get_autocommit(ADb.Handle) <> 0 then
    begin
      { 事务已被外部关闭：只清簿记，避免向 SQLite 发无效 ROLLBACK。 }
      RemoveEntry(I);
      Exit;
    end;
    ADb.Exec('ROLLBACK');
    RemoveEntry(I);
  finally
    TxLock.Release;
  end;
end;

function TxDepth(const ADb: TSqliteDb): Integer;
var
  I: Integer;
begin
  TxLock.Acquire;
  try
    I := FindEntryIndex(ADb);
    if I >= 0 then
      Result := TxEntries[I].Depth
    else
      Result := 0;
  finally
    TxLock.Release;
  end;
end;

function InTransaction(const ADb: TSqliteDb): Boolean;
begin
  Result := TxDepth(ADb) > 0;
end;

procedure SetTxnDepth(const ADb: TSqliteDb; const ADepth: Integer);
begin
  SetDepth(ADb, ADepth);
end;

procedure WithTransaction(const ADb: TSqliteDb; const AProc: TSqliteTxProc);
var
  LPrev: Integer;
begin
  if AProc = nil then
    raise ESqliteTxError.Create('nil transaction callback');
  if ADb = nil then
    raise ESqliteTxError.Create('WithTransaction on a nil connection');
  LPrev := TxDepth(ADb);
  if LPrev = 0 then
    BeginTxn(ADb)
  else
    SetDepth(ADb, LPrev + 1);
  try
    AProc();
    if LPrev = 0 then
      CommitTxn(ADb)          { 失败 ⇒ 走 except 回滚再重抛 }
    else
      SetDepth(ADb, LPrev);   { 内层“提交” = 恢复外层计数 }
  except
    if LPrev = 0 then
      DropAfterRollback(ADb)
    else
      SetDepth(ADb, LPrev);
    raise;
  end;
end;

initialization
  TxLock := nextpas.core.sync.Mutex;

finalization
  TxLock := nil;

end.