unit nextpas.core.db.sqlite.adapter;

{** @desc IDbConnection/IDbQuery 的 SQLite 适配器。
       包装 nextpas.core.db.sqlite.conn 的类表面并统一错误模型
       （ESqliteError -> EDbError）；事务控制面委托 db.sqlite.tx，
       autocommit 守卫与嵌套计数语义原样保留。

       所有权：适配器持有被包装的 TSqliteDb/TSqliteQuery 并在析构
       时释放；消费方只持有接口引用，不手写 Free。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.db.sqlite.base,
  nextpas.core.db.sqlite.conn;

{ 创建 sqlite 连接并返回统一接口（':memory:' 可用）。
  失败抛 EDbError（BackendCode 携带原生结果码）。 }
function ConnectSqlite(const APath: string): IDbConnection;

implementation

uses
  nextpas.core.db.sqlite.tx;

procedure RaiseSqliteAsDb(const AE: ESqliteError);
begin
  raise EDbError.CreateSqlite(AE.ErrorCode, AE.ExtendedErrorCode,
    AE.Message);
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

type
  TDbSqliteQuery = class(TInterfacedObject, IDbQuery)
  private
    FQuery: TSqliteQuery;
  public
    constructor Create(AQuery: TSqliteQuery);   { 取得所有权 }
    destructor Destroy; override;

    procedure BindText(AIndex: Integer; const AValue: string);
    procedure BindInt64(AIndex: Integer; const AValue: Int64);
    procedure BindDouble(AIndex: Integer; const AValue: Double);
    procedure BindBlob(AIndex: Integer; const AValue: TBytes);
    procedure BindNull(AIndex: Integer);

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

  TDbSqliteConnection = class(TInterfacedObject, IDbConnection, IDbTxControl)
  private
    FDb: TSqliteDb;
  public
    constructor Create(ADb: TSqliteDb);         { 取得所有权 }
    destructor Destroy; override;

    function Kind: TDbKind;
    procedure Exec(const ASql: string);
    function Query(const ASql: string): IDbQuery;
    function Changes: Int64;
    function Raw: Pointer;

    { IDbTxControl：委托 db.sqlite.tx（嵌套计数 + autocommit 守卫） }
    procedure BeginTxn(const AImmediate: Boolean = False);
    procedure CommitTxn;
    procedure RollbackTxn;
    function InTransaction: Boolean;
    function TxDepth: Integer;
    procedure RestoreDepth(const ADepth: Integer);
  end;

{ ---- TDbSqliteQuery ---- }

constructor TDbSqliteQuery.Create(AQuery: TSqliteQuery);
begin
  inherited Create;
  FQuery := AQuery;
end;

destructor TDbSqliteQuery.Destroy;
begin
  FQuery.Free;
  inherited Destroy;
end;

procedure TDbSqliteQuery.BindText(AIndex: Integer; const AValue: string);
begin
  try
    FQuery.BindText(AIndex, AValue);
  except
    on E: ESqliteError do RaiseSqliteAsDb(E);
  end;
end;

procedure TDbSqliteQuery.BindInt64(AIndex: Integer; const AValue: Int64);
begin
  try
    FQuery.BindInt64(AIndex, AValue);
  except
    on E: ESqliteError do RaiseSqliteAsDb(E);
  end;
end;

procedure TDbSqliteQuery.BindDouble(AIndex: Integer; const AValue: Double);
begin
  try
    FQuery.BindDouble(AIndex, AValue);
  except
    on E: ESqliteError do RaiseSqliteAsDb(E);
  end;
end;

procedure TDbSqliteQuery.BindBlob(AIndex: Integer; const AValue: TBytes);
begin
  try
    FQuery.BindBlob(AIndex, AValue);
  except
    on E: ESqliteError do RaiseSqliteAsDb(E);
  end;
end;

procedure TDbSqliteQuery.BindNull(AIndex: Integer);
begin
  try
    FQuery.BindNull(AIndex);
  except
    on E: ESqliteError do RaiseSqliteAsDb(E);
  end;
end;

function TDbSqliteQuery.Step: Boolean;
begin
  try
    Result := FQuery.Step;
  except
    on E: ESqliteError do RaiseSqliteAsDb(E);
  end;
end;

procedure TDbSqliteQuery.Reset;
begin
  try
    FQuery.Reset;
  except
    on E: ESqliteError do RaiseSqliteAsDb(E);
  end;
end;

function TDbSqliteQuery.ColumnCount: Integer;
begin
  try
    Result := FQuery.ColumnCount;
  except
    on E: ESqliteError do RaiseSqliteAsDb(E);
  end;
end;

function TDbSqliteQuery.ColumnName(AIndex: Integer): string;
begin
  try
    Result := FQuery.ColumnName(AIndex);
  except
    on E: ESqliteError do RaiseSqliteAsDb(E);
  end;
end;

function TDbSqliteQuery.ColumnType(AIndex: Integer): TDbColumnType;
begin
  try
    Result := MapColumnType(FQuery.ColumnType(AIndex));
  except
    on E: ESqliteError do RaiseSqliteAsDb(E);
  end;
end;

function TDbSqliteQuery.IsNull(AIndex: Integer): Boolean;
begin
  try
    Result := FQuery.ColumnType(AIndex) = SQLITE_NULL;
  except
    on E: ESqliteError do RaiseSqliteAsDb(E);
  end;
end;

function TDbSqliteQuery.GetInt64(AIndex: Integer): Int64;
begin
  try
    Result := FQuery.GetInt64(AIndex);
  except
    on E: ESqliteError do RaiseSqliteAsDb(E);
  end;
end;

function TDbSqliteQuery.GetDouble(AIndex: Integer): Double;
begin
  try
    Result := FQuery.GetDouble(AIndex);
  except
    on E: ESqliteError do RaiseSqliteAsDb(E);
  end;
end;

function TDbSqliteQuery.GetText(AIndex: Integer): string;
begin
  try
    Result := FQuery.GetText(AIndex);
  except
    on E: ESqliteError do RaiseSqliteAsDb(E);
  end;
end;

function TDbSqliteQuery.GetBlob(AIndex: Integer): TBytes;
begin
  try
    Result := FQuery.GetBlob(AIndex);
  except
    on E: ESqliteError do RaiseSqliteAsDb(E);
  end;
end;

{ ---- TDbSqliteConnection ---- }

constructor TDbSqliteConnection.Create(ADb: TSqliteDb);
begin
  inherited Create;
  FDb := ADb;
end;

destructor TDbSqliteConnection.Destroy;
begin
  FDb.Free;
  inherited Destroy;
end;

function TDbSqliteConnection.Kind: TDbKind;
begin
  Result := dbkSqlite;
end;

procedure TDbSqliteConnection.Exec(const ASql: string);
begin
  try
    FDb.Exec(ASql);
  except
    on E: ESqliteError do RaiseSqliteAsDb(E);
  end;
end;

function TDbSqliteConnection.Query(const ASql: string): IDbQuery;
var
  Q: TSqliteQuery;
begin
  try
    Q := FDb.Query(ASql);
  except
    on E: ESqliteError do RaiseSqliteAsDb(E);
  end;
  Result := TDbSqliteQuery.Create(Q);
end;

function TDbSqliteConnection.Changes: Int64;
begin
  try
    Result := FDb.Changes;
  except
    on E: ESqliteError do RaiseSqliteAsDb(E);
  end;
end;

function TDbSqliteConnection.Raw: Pointer;
begin
  Result := FDb.Handle;
end;

procedure TDbSqliteConnection.BeginTxn(const AImmediate: Boolean);
begin
  try
    nextpas.core.db.sqlite.tx.BeginTxn(FDb, AImmediate);
  except
    on E: ESqliteTxError do
      raise EDbError.CreateSimple(dbkSqlite, E.Message);
  end;
end;

procedure TDbSqliteConnection.CommitTxn;
begin
  try
    nextpas.core.db.sqlite.tx.CommitTxn(FDb);
  except
    on E: ESqliteTxError do
      raise EDbError.CreateSimple(dbkSqlite, E.Message);
  end;
end;

procedure TDbSqliteConnection.RollbackTxn;
begin
  try
    nextpas.core.db.sqlite.tx.RollbackTxn(FDb);
  except
    on E: ESqliteTxError do
      raise EDbError.CreateSimple(dbkSqlite, E.Message);
  end;
end;

function TDbSqliteConnection.InTransaction: Boolean;
begin
  Result := nextpas.core.db.sqlite.tx.InTransaction(FDb);
end;

function TDbSqliteConnection.TxDepth: Integer;
begin
  Result := nextpas.core.db.sqlite.tx.TxDepth(FDb);
end;

procedure TDbSqliteConnection.RestoreDepth(const ADepth: Integer);
begin
  try
    nextpas.core.db.sqlite.tx.SetTxnDepth(FDb, ADepth);
  except
    on E: ESqliteTxError do
      raise EDbError.CreateSimple(dbkSqlite, E.Message);
  end;
end;

{ ---- 工厂 ---- }

function ConnectSqlite(const APath: string): IDbConnection;
var
  Db: TSqliteDb;
begin
  try
    Db := TSqliteDb.Create(APath);
  except
    on E: ESqliteError do RaiseSqliteAsDb(E);
  end;
  Result := TDbSqliteConnection.Create(Db);
end;

end.
