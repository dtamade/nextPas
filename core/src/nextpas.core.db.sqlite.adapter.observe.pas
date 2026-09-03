unit nextpas.core.db.sqlite.adapter.observe;

{** @desc SQLite 适配器观测分治（L3 实现子模块）。
       归一错误模型与列类型映射的单源：RaiseSqliteAsDb / SqliteCategoryOf
       复用 db.err 分类表（ClassifySqlite），Blob 路径经同一表归一；
       MapColumnType 为声明/行值到 TDbColumnType 的纯映射（INC-6）。
       层级：L3 适配子模块（严格下向 L2 db.err/sqlite.base，无上向；
       同层单向：仅被 cache/blob/adapter 依赖，不反向依赖）。
       性能：纯函数薄转发，inline 守 I-Cache（循环体不 inline），
       复用 bytes.ops 单源（契约哨兵）。
       稳定性：纯映射无资源，fail-closed 抛 EDbError，不吞异常。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.base,
  nextpas.core.db.sqlite.base,
  nextpas.core.db.sqlite.conn;

procedure RaiseSqliteAsDb(const AE: ESqliteError);
function SqliteCategoryOf(const AE: ESqliteError): TDbErrorCategory;
function MapColumnType(const ASqliteType: Integer): TDbColumnType;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.db.err;

{$IF not BYTES_OPS_SINGLE_SOURCE}
  {$FATAL 'bytes.ops single source drift: sqlite.adapter.observe must reuse bytes.ops'}
{$IFEND}

procedure RaiseSqliteAsDb(const AE: ESqliteError);
var
  LCategory: TDbErrorCategory;
  LConstraint: TDbConstraintKind;
begin
  ClassifySqlite(AE.ErrorCode, AE.ExtendedErrorCode, LCategory, LConstraint);
  raise NewDbErrorSqlite(AE.ErrorCode, AE.ExtendedErrorCode,
    LCategory, LConstraint, AE.Message);
end;

function SqliteCategoryOf(const AE: ESqliteError): TDbErrorCategory;
var
  LConstraint: TDbConstraintKind;
begin
  { 观测钩子（V3-B3）用：抛前取归一类目，与 RaiseSqliteAsDb 同表 }
  ClassifySqlite(AE.ErrorCode, AE.ExtendedErrorCode, Result, LConstraint);
end;

function MapColumnType(const ASqliteType: Integer): TDbColumnType;
begin
  case ASqliteType of
    SQLITE_INTEGER: Result := dbcInteger;
    SQLITE_FLOAT:   Result := dbcFloat;
    SQLITE_TEXT:    Result := dbcText;
    SQLITE_BLOB:    Result := dbcBlob;
  else
    Result := dbcNull;
  end;
end;

end.
