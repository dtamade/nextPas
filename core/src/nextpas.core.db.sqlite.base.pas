unit nextpas.core.db.sqlite.base;

{** @desc SQLite L2 module: public constants and type aliases.
       Raw ABI declarations live in nextpas.core.db.sqlite.ffi.
       The friendly surface (TSqliteDb / TSqliteQuery / ESqliteError)
       lives in nextpas.core.db.sqlite.conn and is re-exported by the
       nextpas.core.db.sqlite facade. *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

const
  { Result codes (sqlite3.h) — 单源词汇（err 侧别名引用本表，不自持副本） }
  SQLITE_OK          = 0;
  SQLITE_ERROR       = 1;
  SQLITE_BUSY        = 5;
  SQLITE_LOCKED      = 6;
  SQLITE_NOMEM       = 7;
  SQLITE_INTERRUPT   = 9;
  SQLITE_IOERR       = 10;
  SQLITE_CORRUPT     = 11;
  SQLITE_FULL        = 13;
  SQLITE_CANTOPEN    = 14;
  SQLITE_AUTH        = 23;
  SQLITE_ROW         = 100;
  SQLITE_DONE        = 101;

  { Primary constraint violation code + extended subcodes (sqlite3.h).
    sqlite3_step/sqlite3_exec return SQLITE_CONSTRAINT (19); the precise
    kind (UNIQUE/PK/FK/CHECK/...) is only visible via the extended code,
    obtainable through sqlite3_extended_errcode. Constants per sqlite3.h. }
  SQLITE_CONSTRAINT              = 19;
  SQLITE_CONSTRAINT_CHECK        = 275;
  SQLITE_CONSTRAINT_COMMITHOOK   = 531;
  SQLITE_CONSTRAINT_FOREIGNKEY   = 787;
  SQLITE_CONSTRAINT_FUNCTION     = 1043;
  SQLITE_CONSTRAINT_NOTNULL      = 1299;
  SQLITE_CONSTRAINT_PRIMARYKEY   = 1555;
  SQLITE_CONSTRAINT_TRIGGER      = 1811;
  SQLITE_CONSTRAINT_UNIQUE       = 2067;
  SQLITE_CONSTRAINT_VTAB         = 2323;
  SQLITE_CONSTRAINT_ROWID        = 2579;
  SQLITE_CONSTRAINT_PINNED       = 2835;
  SQLITE_CONSTRAINT_DATATYPE     = 3091;

  { sqlite3_open_v2 flags }
  SQLITE_OPEN_READONLY  = $00000001;
  SQLITE_OPEN_READWRITE = $00000002;
  SQLITE_OPEN_CREATE    = $00000004;
  SQLITE_OPEN_URI       = $00000040;
  SQLITE_OPEN_MEMORY    = $00000080;
  SQLITE_OPEN_NOMUTEX   = $00008000;
  SQLITE_OPEN_FULLMUTEX = $00010000;

  { Column data types (sqlite3_column_type) }
  SQLITE_INTEGER = 1;
  SQLITE_FLOAT   = 2;
  SQLITE_TEXT    = 3;
  SQLITE_BLOB    = 4;
  SQLITE_NULL    = 5;

  { Destructor-style values for text/blob binds }
  SQLITE_STATIC    = 0;
  SQLITE_TRANSIENT = -1;

type
  TSqliteHandle = Pointer;   // sqlite3*
  TSqliteStmt   = Pointer;   // sqlite3_stmt*
  TSqliteBlob   = Pointer;   // sqlite3_blob*（INC-8 增量 blob I/O 句柄）

  { Bindable parameter value }
  TSqliteValue = record
    Kind: Integer;  // SQLITE_INTEGER..SQLITE_NULL
    AsInt64: Int64;
    AsDouble: Double;
    AsText: string;
    AsBlob: TBytes;
  end;

  { ---- C5 调优预设（V3-C5）：连接级 PRAGMA 的受控词汇。
    预设即注释即契约：每个字段 unset 语义明确，绝不静默猜测。 ---- }

  { journal_mode；sjmUnset = 不设置（保持 sqlite 缺省 delete）。
    :memory: 库恒过滤（WAL 对内存库无意义）。 }
  TDbSqliteJournalMode = (
    sjmUnset,
    sjmDelete,     { 缺省回滚日志 }
    sjmTruncate,
    sjmPersist,
    sjmMemory,
    sjmWal         { 写前日志：读写并发最佳；文件头持久化，网络 FS 不支持
                     → 应用后回读校验，不符即抛 decNotSupported }
  );

  { synchronous；sysUnset = 不设置（缺省 FULL） }
  TDbSqliteSync = (
    sysUnset,
    sysOff,        { 最快；崩溃可能损坏 }
    sysNormal,     { WAL 模式工业标配：仅断电风险窗口，无损坏 }
    sysFull        { 最保守 }
  );

  { foreign_keys 三态：sqlite 缺省 OFF 是著名陷阱，但默认改写会惊吓
    依赖原语义的消费方——故三态显式表达 }
  TDbSqliteFkMode = (fkUnset, fkOff, fkOn);

  TDbSqlitePragmas = record
    JournalMode: TDbSqliteJournalMode;
    Synchronous: TDbSqliteSync;
    ForeignKeys: TDbSqliteFkMode;
    { 页缓存大小：正 = 页数；负 = KiB（sqlite 语义）；0 = 不设置 }
    CacheSize: Integer;
    { 内存映射 IO 上限字节数；<0 = 不设置；0 = 禁用 mmap }
    MmapSize: Int64;
    class function Default: TDbSqlitePragmas; static;
  end;

implementation

{ C5 安全缺省（文件库）：WAL + synchronous=NORMAL + 外键强制。
  逐字段显式赋值；仅在消费方显式传入 pragmas 重载时生效——
  不经此入口的连接保持 sqlite 原生缺省，行为零变化。 }
class function TDbSqlitePragmas.Default: TDbSqlitePragmas;
begin
  Result.JournalMode := sjmWal;
  Result.Synchronous := sysNormal;
  Result.ForeignKeys := fkOn;
  Result.CacheSize := 0;      { 不设置 }
  Result.MmapSize := -1;      { 不设置 }
end;

end.