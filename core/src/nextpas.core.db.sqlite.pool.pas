unit nextpas.core.db.sqlite.pool;

{** @desc SQLite L2 thin connection pool (B7).
       - 按需创建：连接懒创建，Acquire/Release 复用。
       - 容量上限：AMaxConnections 为硬上限；已达上限且无空闲连接时
         Acquire 抛 ESqlitePoolError（薄池不阻塞等待，调用方调参或节流）。
       - 统一初始化：每个创建出的连接（含写连接）统一设置
         PRAGMA journal_mode=WAL（AWal=False 或路径为 ':memory:' 时跳过）
         与 busy timeout（ABusyTimeoutMs）。
       - 单写者语义：池内所有连接指向同一 DB 文件；读走 Acquire/Release，
         写一律走专用 Writer 连接（懒创建、池所有、不可 Release）。
         WAL 快照保证写提交期间读者看到一致数据。*}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.db.sqlite.base,
  nextpas.core.db.sqlite.conn,
  nextpas.core.sync;

type
  { 连接池用法错误（容量耗尽、池已关闭、试图 Release 写连接）。 }
  ESqlitePoolError = class(ENextPasError)
  public
    constructor Create(const AMessage: string);
  end;

  TSqlitePool = class
  private
    FPath: string;
    FMaxConnections: Integer;
    FBusyTimeoutMs: Integer;
    FWal: Boolean;
    FForeignKeys: Boolean;
    FLock: INativeMutex;
    { 空闲读连接（Acquire 弹出 / Release 回收） }
    FIdle: array of TSqliteDb;
    { 已创建的读连接总数（空闲 + 借出），容量核算基数 }
    FOpen: Integer;
    { 专用写连接，懒创建，池所有 }
    FWriter: TSqliteDb;
    FClosed: Boolean;
    function IsMemoryPath: Boolean;
    function CreateConnection: TSqliteDb;
    function PopIdle(out ADb: TSqliteDb): Boolean;
  public
    constructor Create(const APath: string; const AMaxConnections: Integer = 8;
      const ABusyTimeoutMs: Integer = 5000; const AWal: Boolean = True;
      const AForeignKeys: Boolean = False);
    destructor Destroy; override;
    { 取一个读连接；容量耗尽抛 ESqlitePoolError。 }
    function Acquire: TSqliteDb;
    { 归还读连接；池已关闭则直接释放。写连接不得走本方法。 }
    procedure Release(const ADb: TSqliteDb);
    { 专用写连接（池所有，懒创建）；所有写操作经它串行。 }
    function Writer: TSqliteDb;
    { 关闭池：释放空闲连接与写连接；已借出的连接由调用方 Release
      （届时被直接释放）。关闭后 Acquire/Writer 抛错，Close 幂等。 }
    procedure Close;
    function IdleCount: Integer;
    function TotalConnections: Integer;
    property Path: string read FPath;
    property MaxConnections: Integer read FMaxConnections;
    property BusyTimeoutMs: Integer read FBusyTimeoutMs;
    { 每连接 PRAGMA foreign_keys 开关(默认 off = SQLite 引擎默认,
      不改变既有行为); on 时外键约束与 ON DELETE CASCADE 生效。 }
    property ForeignKeys: Boolean read FForeignKeys;
  end;

implementation

constructor ESqlitePoolError.Create(const AMessage: string);
begin
  inherited Create(AMessage);
end;

{ ===== TSqlitePool ===== }

constructor TSqlitePool.Create(const APath: string;
  const AMaxConnections: Integer; const ABusyTimeoutMs: Integer;
  const AWal: Boolean; const AForeignKeys: Boolean);
begin
  inherited Create;
  if AMaxConnections < 1 then
    raise ESqlitePoolError.Create('connection pool max must be >= 1, got ' +
      IntToStr(AMaxConnections));
  FPath := APath;
  FMaxConnections := AMaxConnections;
  FBusyTimeoutMs := ABusyTimeoutMs;
  FWal := AWal;
  FForeignKeys := AForeignKeys;
  FLock := nextpas.core.sync.Mutex;
end;

destructor TSqlitePool.Destroy;
begin
  Close;
  inherited;
end;

function TSqlitePool.IsMemoryPath: Boolean;
begin
  Result := FPath = ':memory:';
end;

{ 新建一条连接并统一初始化（WAL + busy timeout + 可选 foreign_keys）。 }
function TSqlitePool.CreateConnection: TSqliteDb;
begin
  Result := TSqliteDb.Create(FPath);
  try
    if FWal and not IsMemoryPath then
      Result.Exec('PRAGMA journal_mode=WAL');
    if FBusyTimeoutMs > 0 then
      Result.BusyTimeout(FBusyTimeoutMs);
    if FForeignKeys then
      Result.Exec('PRAGMA foreign_keys=ON');
  except
    Result.Free;
    raise;
  end;
end;

function TSqlitePool.PopIdle(out ADb: TSqliteDb): Boolean;
begin
  Result := Length(FIdle) > 0;
  if Result then
  begin
    ADb := FIdle[High(FIdle)];
    SetLength(FIdle, Length(FIdle) - 1);
  end;
end;

function TSqlitePool.Acquire: TSqliteDb;
begin
  FLock.Acquire;
  try
    if FClosed then
      raise ESqlitePoolError.Create('connection pool is closed');
    if not PopIdle(Result) then
    begin
      if FOpen >= FMaxConnections then
        raise ESqlitePoolError.CreateFmt(
          'connection pool exhausted (max %d, no idle connection)', [FMaxConnections]);
      Result := CreateConnection;
      Inc(FOpen);
    end;
  finally
    FLock.Release;
  end;
end;

procedure TSqlitePool.Release(const ADb: TSqliteDb);
begin
  if ADb = nil then
    raise ESqlitePoolError.Create('cannot release a nil connection');
  FLock.Acquire;
  try
    if ADb = FWriter then
      raise ESqlitePoolError.Create(
        'the writer connection is owned by the pool and must not be released');
    if FClosed then
      ADb.Free
    else
    begin
      SetLength(FIdle, Length(FIdle) + 1);
      FIdle[High(FIdle)] := ADb;
    end;
  finally
    FLock.Release;
  end;
end;

function TSqlitePool.Writer: TSqliteDb;
begin
  FLock.Acquire;
  try
    if FClosed then
      raise ESqlitePoolError.Create('connection pool is closed');
    if FWriter = nil then
      FWriter := CreateConnection;
    Result := FWriter;
  finally
    FLock.Release;
  end;
end;

procedure TSqlitePool.Close;
var
  I: Integer;
begin
  FLock.Acquire;
  try
    if FClosed then
      Exit;
    FClosed := True;
    for I := 0 to High(FIdle) do
      FIdle[I].Free;
    FIdle := nil;
    { 已借出连接保持借出语义：调用方 Release 时被直接释放（见 Release）。 }
    if FWriter <> nil then
      FWriter.Free;
    FWriter := nil;
  finally
    FLock.Release;
  end;
end;

function TSqlitePool.IdleCount: Integer;
begin
  FLock.Acquire;
  try
    Result := Length(FIdle);
  finally
    FLock.Release;
  end;
end;

function TSqlitePool.TotalConnections: Integer;
begin
  FLock.Acquire;
  try
    Result := FOpen;
  finally
    FLock.Release;
  end;
end;

end.