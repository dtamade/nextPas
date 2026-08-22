unit nextpas.core.db.intf;

{** @desc nextpas.core.db L3 家族：统一接口契约。
       只依赖 db.base；具体后端在各自的 *.adapter 单元实现这些接口。

       所有权模型：对外一律 interface（COM 引用计数），消费方不手写
       Free。IDbConnection.Query 返回的 IDbQuery 由引用计数释放。

       约定：
       - 参数化 SQL 一律使用顺序 ? 占位符（1-based 绑定索引对应第 k
         个 ?）；后端方言翻译由适配器负责（pg: ? -> $N）。
       - Exec 不做参数绑定，SQL 原文透传。
       - 绑定索引 1-based；列索引 0-based。
       - Raw 是逃生舱（sqlite3* / PGconn*），仅限抽象层未覆盖的特性；
         使用纪律见 core/docs/db/CONTRACT.md。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.db.base;

type
  {** 参数化语句 + 行游标（对齐两后端现状：query 对象合一两者）。 *}
  IDbQuery = interface
    ['{8F2E7A64-9C1D-4B0E-A3D7-51C2B90FE001}']
    procedure BindText(AIndex: Integer; const AValue: string);
    procedure BindInt64(AIndex: Integer; const AValue: Int64);
    procedure BindDouble(AIndex: Integer; const AValue: Double);
    procedure BindBlob(AIndex: Integer; const AValue: TBytes);
    procedure BindNull(AIndex: Integer);

    { True=有行；首次调用触发执行 }
    function Step: Boolean;
    procedure Reset;
    function ColumnCount: Integer;
    function ColumnName(AIndex: Integer): string;
    function ColumnType(AIndex: Integer): TDbColumnType;
    function IsNull(AIndex: Integer): Boolean;
    function GetInt64(AIndex: Integer): Int64;
    function GetDouble(AIndex: Integer): Double;
    function GetText(AIndex: Integer): string;
    function GetBlob(AIndex: Integer): TBytes;
  end;

  {** 事务控制面。由支持事务的连接适配器实现；泛化事务助手
      （nextpas.core.db.tx）经 QueryInterface 取用。
      语义与 db.sqlite.tx 一致：计数式嵌套，Begin 加深、内层 Commit
      只降计数、任意深度 Rollback 回滚整事务并清簿记。 *}
  IDbTxControl = interface
    ['{8F2E7A64-9C1D-4B0E-A3D7-51C2B90FE002}']
    procedure BeginTxn(const AImmediate: Boolean = False);
    procedure CommitTxn;
    procedure RollbackTxn;
    function InTransaction: Boolean;
    function TxDepth: Integer;
    { 恢复簿记深度（不开新事务、不动数据库状态）。仅供泛化事务
      助手实现嵌套失败路径使用，消费方不要直接调用。 }
    procedure RestoreDepth(const ADepth: Integer);
  end;

  {** 统一连接表面。 *}
  IDbConnection = interface
    ['{8F2E7A64-9C1D-4B0E-A3D7-51C2B90FE003}']
    function Kind: TDbKind;
    { 多语句 DDL/DML；SQL 原文透传，不做占位符翻译 }
    procedure Exec(const ASql: string);
    { 参数化查询；SQL 用顺序 ? 占位符 }
    function Query(const ASql: string): IDbQuery;
    { 最近一次写入影响行数 }
    function Changes: Int64;
    { 原生句柄逃生舱：sqlite3* / PGconn*。仅限 LastInsertRowId、
      BusyTimeout、Checkpoint、LISTEN/NOTIFY 等未覆盖特性。 }
    function Raw: Pointer;
  end;

implementation

end.
