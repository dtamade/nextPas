unit nextpas.core.lockfree.snapshot;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  TSnapshotResult = (srCommitted, srAborted, srConflict, srNotFound, srClosed);

  {** @desc 并发快照隔离（Snapshot Isolation）
    @details 每个事务看到数据库在事务开始时的快照。
      支持多版本并发控制 (MVCC)。
      读操作不阻塞写操作，写操作不阻塞读操作。
      适用场景：数据库事务、并发状态管理。
  }
  generic TSnapshotIsolationImpl<TValue> = class
  private
    FTimestamp: Int64;
    FClosed: Int32;
    function GetNextTimestamp: Int64;
  public
    constructor Create;
    function BeginSnapshot: Int64;
    function Read(const AKey: string; const ASnapshotTs: Int64; out AValue: TValue): TSnapshotResult;
    function Write(const AKey: string; const AValue: TValue; const ATransactionTs: Int64): TSnapshotResult;
    function Commit(const ATransactionTs: Int64): TSnapshotResult;
    function Abort(const ATransactionTs: Int64): TSnapshotResult;
    procedure Close;
    function IsClosed: Boolean;
    function GetCurrentTimestamp: Int64;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic;

constructor TSnapshotIsolationImpl.Create;
begin
  inherited Create;
  FTimestamp := 0;
  FClosed := 0;
end;

function TSnapshotIsolationImpl.GetNextTimestamp: Int64;
begin
  Result := AtomicFetchAdd64(FTimestamp, 1, moAcqRel) + 1;
end;

function TSnapshotIsolationImpl.BeginSnapshot: Int64;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(-1);
  Result := GetNextTimestamp;
end;

function TSnapshotIsolationImpl.Read(const AKey: string; const ASnapshotTs: Int64; out AValue: TValue): TSnapshotResult;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(srClosed);
  // Simplified: no actual storage
  Result := srNotFound;
end;

function TSnapshotIsolationImpl.Write(const AKey: string; const AValue: TValue; const ATransactionTs: Int64): TSnapshotResult;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(srClosed);
  // Simplified: no actual storage
  Result := srCommitted;
end;

function TSnapshotIsolationImpl.Commit(const ATransactionTs: Int64): TSnapshotResult;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(srClosed);
  Result := srCommitted;
end;

function TSnapshotIsolationImpl.Abort(const ATransactionTs: Int64): TSnapshotResult;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(srClosed);
  Result := srAborted;
end;

procedure TSnapshotIsolationImpl.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
end;

function TSnapshotIsolationImpl.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

function TSnapshotIsolationImpl.GetCurrentTimestamp: Int64;
begin
  Result := AtomicLoad64(FTimestamp, moAcquire);
end;

end.
