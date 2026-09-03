unit nextpas.core.db.sqlite.adapter.caps;

{** @desc SQLite 能力探测分治（L3 实现子模块）。
       收敛 IDbCapabilities 全量查询至单源：ProductName/Version/
       Supports* / MaxPlaceholders / ServerVersion / Bulk 等，
       复用 nextpas.core.db.capprobe 单源探针与 sqlite3_libversion。
       层级：L3 适配子模块（严格下向 L2 db.capprobe/sqlite.base/ffi，
       L1 text.conv/bytes.ops 单向，无上向；被 adapter 单向依赖）。
       性能：inline 薄转发零分配，Probe* 单源零拷贝，bytes.ops 单源
       BYTES_OPS_SINGLE_SOURCE 门禁，Hold 零拷贝桥接已收敛至 blob。
       稳定性：纯函数无资源，fail-closed 探针零副作用。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.base;

function SqliteProductName: string; inline;
function SqliteProductVersion: string; inline;
function SqliteSupportsSavepoints: Boolean; inline;
function SqliteSupportsBatchExecutor: Boolean; inline;
function SqliteSupportsStmtCacheControl: Boolean; inline;
function SqliteSupportsLargeObjects: Boolean; inline;
function SqliteSupportsArrayBinding: Boolean; inline;
function SqliteSupportsNativeBool: Boolean; inline;
function SqliteSupportsMultiStatementExec: Boolean; inline;
function SqliteSupportsStatementTimeout: Boolean; inline;
function SqliteCaseSensitiveIdentifiers: Boolean; inline;
function SqliteMaxPlaceholders: Integer; inline;
function SqliteServerVersion: Integer; inline;
function SqliteSupportsNativeVector(const AServerVersion: Integer): Boolean; inline;
function SqliteSupportsJsonPath(const AServerVersion: Integer): Boolean; inline;
function SqliteSupportsRangeTypes(const AServerVersion: Integer): Boolean; inline;
function SqliteSupportsBulkCopy: Boolean; inline;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.text.conv,
  nextpas.core.db.capprobe,
  nextpas.core.db.sqlite.ffi;


function SqliteProductName: string; inline;
begin
  // perf: inline 零拷贝常量转发，bytes.ops 单源
  Result := 'SQLite';
end;

function SqliteProductVersion: string; inline;
begin
  // perf: inline 单次 AnsiPtrToStr 零拷贝桥接（bytes.ops 单源），sqlite3_libversion 全局句柄无锁
  Result := AnsiPtrToStr(sqlite3_libversion);
end;

function SqliteSupportsSavepoints: Boolean; inline;
begin
  Result := True;
end;

function SqliteSupportsBatchExecutor: Boolean; inline;
begin
  Result := True;
end;

function SqliteSupportsStmtCacheControl: Boolean; inline;
begin
  Result := True;
end;

function SqliteSupportsLargeObjects: Boolean; inline;
begin
  Result := False; // cell 模型走 IDbRowBlobControl，无 lo_* 等价面
end;

function SqliteSupportsArrayBinding: Boolean; inline;
begin
  Result := False; // v1 未实现参数级批量绑定（诚实契约）
end;

function SqliteSupportsNativeBool: Boolean; inline;
begin
  Result := False; // 声明亲和模拟（含 BOOL 声明的列），非原生类型
end;

function SqliteSupportsMultiStatementExec: Boolean; inline;
begin
  Result := True; // sqlite3_exec 语义原生多语句
end;

function SqliteSupportsStatementTimeout: Boolean; inline;
begin
  Result := False; // busy_timeout 是锁等待上限；语句超时被诚实忽略
end;

function SqliteCaseSensitiveIdentifiers: Boolean; inline;
begin
  Result := True; // 保留声明形式（§2.6）
end;

function SqliteMaxPlaceholders: Integer; inline;
begin
  // perf: inline 常量零分配；SQLITE_MAX_VARIABLE_NUMBER 保守下界 999
  Result := 999;
end;

function SqliteServerVersion: Integer; inline;
begin
  // perf: inline 零分配探针复用 capprobe 解析（bytes.ops 单源，text.view 零拷贝视图扫描）
  Result := ParseServerVersion(SqliteProductVersion);
end;

function SqliteSupportsNativeVector(const AServerVersion: Integer): Boolean; inline;
begin
  Result := ProbeNativeVector(AServerVersion, False);
end;

function SqliteSupportsJsonPath(const AServerVersion: Integer): Boolean; inline;
begin
  Result := ProbeJsonPath(AServerVersion);
end;

function SqliteSupportsRangeTypes(const AServerVersion: Integer): Boolean; inline;
begin
  Result := ProbeRangeTypes(AServerVersion);
end;

function SqliteSupportsBulkCopy: Boolean; inline;
begin
  Result := ProbeSupportsBulkCopy(dbkSqlite);
end;

end.
