unit nextpas.core.db.pg.adapter;

{** @desc IDbConnection/IDbQuery 的 PostgreSQL 适配器。
       包装 nextpas.core.db.pg.conn 的类表面并统一错误模型
       （EPgError -> EDbError，SqlState/Severity/Detail 字段透传）。

       事务控制面：连接内计数式簿记（互斥锁保护），语义对齐
       db.sqlite.tx——嵌套 Begin 加深、内层 Commit 只降计数、任意
       深度 Rollback 回滚整事务并清零。libpq 无 autocommit 探针，
       裸 BEGIN 混用检测不适用本后端（契约差异见 core/docs/db）。

       所有权：适配器持有被包装的 TPgConn/TPgQuery 并在析构时释放。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.db.pg.base,
  nextpas.core.db.pg.conn;

{ 创建 postgres 连接并返回统一接口（libpq key=value 连接串）。
  失败抛 EDbError（SqlState 等字段携带 libpq 诊断）。 }
function ConnectPostgres(const AConnInfo: string): IDbConnection;

implementation

uses
  SysUtils,
  nextpas.core.sync;

procedure RaisePgAsDb(const AE: EPgError);
begin
  raise EDbError.CreatePg(AE.SqlState, AE.Severity, AE.Detail, AE.Message);
end;

{** @desc 统一占位符翻译：把统一契约的 ?（或显式编号 ?N）翻译为
       libpq 的 $N 形态。扫描状态机跳过字符串字面量（'' 转义）、
       双引号标识符、行注释与块注释；dollar-quote 体不识别——与
       nextpas.core.db.pg.conn 的参数计数扫描同一受控边界。
       - ?  -> 下一个顺序编号 $k（1 起，逐个递增）
       - ?N -> 直接映射 $N（不扰动顺序计数） *}
function TranslatePlaceholders(const ASql: string): string;
var
  LB: string;
  I: Integer;
  C: Char;
  InStr, InDq, InLineC, InBlockC: Boolean;
  N: Integer;
  Seq: Integer;
begin
  LB := '';
  Seq := 0;
  InStr := False;
  InDq := False;
  InLineC := False;
  InBlockC := False;
  I := 1;
  while I <= Length(ASql) do
  begin
    C := ASql[I];
    if InLineC then
    begin
      LB := LB + C;
      if C = #10 then
        InLineC := False;
    end
    else if InBlockC then
    begin
      LB := LB + C;
      if (C = '*') and (I < Length(ASql)) and (ASql[I + 1] = '/') then
      begin
        LB := LB + '/';
        InBlockC := False;
        Inc(I);
      end;
    end
    else if InStr then
    begin
      LB := LB + C;
      if C = '''' then
      begin
        if (I < Length(ASql)) and (ASql[I + 1] = '''') then
        begin
          LB := LB + '''';
          Inc(I);
        end
        else
          InStr := False;
      end;
    end
    else if InDq then
    begin
      LB := LB + C;
      if C = '"' then
      begin
        if (I < Length(ASql)) and (ASql[I + 1] = '"') then
        begin
          LB := LB + '"';
          Inc(I);
        end
        else
          InDq := False;
      end;
    end
    else
    begin
      case C of
        '''' :
          begin
            InStr := True;
            LB := LB + C;
          end;
        '"' :
          begin
            InDq := True;
            LB := LB + C;
          end;
        '-' :
          begin
            if (I < Length(ASql)) and (ASql[I + 1] = '-') then
              InLineC := True;
            LB := LB + C;
          end;
        '/' :
          begin
            if (I < Length(ASql)) and (ASql[I + 1] = '*') then
            begin
              InBlockC := True;
              Inc(I);   { '*' 由 InBlockC 分支下一轮带出 }
              Continue;
            end;
            LB := LB + C;
          end;
        '?' :
          begin
            Inc(I);
            N := 0;
            while (I <= Length(ASql)) and (ASql[I] in ['0'..'9']) do
            begin
              N := N * 10 + (Ord(ASql[I]) - Ord('0'));
              Inc(I);
            end;
            if N > 0 then
              LB := LB + '$' + IntToStr(N)
            else
            begin
              Inc(Seq);
              LB := LB + '$' + IntToStr(Seq);
            end;
            Continue;
          end;
      else
        LB := LB + C;
      end;
    end;
    Inc(I);
  end;
  Result := LB;
end;

{ 结果列类型：按 PQftype OID 归入统一列类型；未知类型一律 dbcText
  （文本协议下取值即文本，安全兜底）。 }
function MapColumnType(const AOid: Cardinal): TDbColumnType;
begin
  case AOid of
    17:                       Result := dbcBlob;     { bytea }
    20, 21, 23:               Result := dbcInteger;  { int8/int2/int4 }
    700, 701, 1700:           Result := dbcFloat;    { float4/float8/numeric }
  else
    Result := dbcText;
  end;
end;

type
  TDbPgQuery = class(TInterfacedObject, IDbQuery)
  private
    FQuery: TPgQuery;
  public
    constructor Create(AQuery: TPgQuery);       { 取得所有权 }
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

  TDbPgConnection = class(TInterfacedObject, IDbConnection, IDbTxControl)
  private
    FConn: TPgConn;
    FLock: INativeMutex;
    FDepth: Integer;
    procedure PgExec(const ASql: string);
  public
    constructor Create(AConn: TPgConn);         { 取得所有权 }
    destructor Destroy; override;

    function Kind: TDbKind;
    procedure Exec(const ASql: string);
    function Query(const ASql: string): IDbQuery;
    function Changes: Int64;
    function Raw: Pointer;

    { IDbTxControl }
    procedure BeginTxn(const AImmediate: Boolean = False);
    procedure CommitTxn;
    procedure RollbackTxn;
    function InTransaction: Boolean;
    function TxDepth: Integer;
    procedure RestoreDepth(const ADepth: Integer);
  end;

{ ---- TDbPgQuery ---- }

constructor TDbPgQuery.Create(AQuery: TPgQuery);
begin
  inherited Create;
  FQuery := AQuery;
end;

destructor TDbPgQuery.Destroy;
begin
  FQuery.Free;
  inherited Destroy;
end;

procedure TDbPgQuery.BindText(AIndex: Integer; const AValue: string);
begin
  try
    FQuery.BindText(AIndex, AValue);
  except
    on E: EPgError do RaisePgAsDb(E);
  end;
end;

procedure TDbPgQuery.BindInt64(AIndex: Integer; const AValue: Int64);
begin
  try
    FQuery.BindInt64(AIndex, AValue);
  except
    on E: EPgError do RaisePgAsDb(E);
  end;
end;

procedure TDbPgQuery.BindDouble(AIndex: Integer; const AValue: Double);
begin
  try
    FQuery.BindDouble(AIndex, AValue);
  except
    on E: EPgError do RaisePgAsDb(E);
  end;
end;

procedure TDbPgQuery.BindBlob(AIndex: Integer; const AValue: TBytes);
begin
  try
    FQuery.BindBlob(AIndex, AValue);
  except
    on E: EPgError do RaisePgAsDb(E);
  end;
end;

procedure TDbPgQuery.BindNull(AIndex: Integer);
begin
  try
    FQuery.BindNull(AIndex);
  except
    on E: EPgError do RaisePgAsDb(E);
  end;
end;

function TDbPgQuery.Step: Boolean;
begin
  try
    Result := FQuery.Step;
  except
    on E: EPgError do RaisePgAsDb(E);
  end;
end;

procedure TDbPgQuery.Reset;
begin
  try
    FQuery.Reset;
  except
    on E: EPgError do RaisePgAsDb(E);
  end;
end;

function TDbPgQuery.ColumnCount: Integer;
begin
  try
    Result := FQuery.ColumnCount;
  except
    on E: EPgError do RaisePgAsDb(E);
  end;
end;

function TDbPgQuery.ColumnName(AIndex: Integer): string;
begin
  try
    Result := FQuery.ColumnName(AIndex);
  except
    on E: EPgError do RaisePgAsDb(E);
  end;
end;

function TDbPgQuery.ColumnType(AIndex: Integer): TDbColumnType;
begin
  try
    Result := MapColumnType(FQuery.ColumnFieldOid(AIndex));
  except
    on E: EPgError do RaisePgAsDb(E);
  end;
end;

function TDbPgQuery.IsNull(AIndex: Integer): Boolean;
begin
  try
    Result := FQuery.IsNull(AIndex);
  except
    on E: EPgError do RaisePgAsDb(E);
  end;
end;

function TDbPgQuery.GetInt64(AIndex: Integer): Int64;
begin
  try
    Result := FQuery.GetInt64(AIndex);
  except
    on E: EPgError do RaisePgAsDb(E);
  end;
end;

function TDbPgQuery.GetDouble(AIndex: Integer): Double;
begin
  try
    Result := FQuery.GetDouble(AIndex);
  except
    on E: EPgError do RaisePgAsDb(E);
  end;
end;

function TDbPgQuery.GetText(AIndex: Integer): string;
begin
  try
    Result := FQuery.GetText(AIndex);
  except
    on E: EPgError do RaisePgAsDb(E);
  end;
end;

function TDbPgQuery.GetBlob(AIndex: Integer): TBytes;
begin
  try
    Result := FQuery.GetBlob(AIndex);
  except
    on E: EPgError do RaisePgAsDb(E);
  end;
end;

{ ---- TDbPgConnection ---- }

constructor TDbPgConnection.Create(AConn: TPgConn);
begin
  inherited Create;
  FConn := AConn;
  FLock := nextpas.core.sync.Mutex;
  FDepth := 0;
end;

destructor TDbPgConnection.Destroy;
begin
  FConn.Free;
  inherited Destroy;
end;

procedure TDbPgConnection.PgExec(const ASql: string);
begin
  try
    FConn.Exec(ASql);
  except
    on E: EPgError do RaisePgAsDb(E);
  end;
end;

function TDbPgConnection.Kind: TDbKind;
begin
  Result := dbkPostgres;
end;

procedure TDbPgConnection.Exec(const ASql: string);
begin
  PgExec(ASql);
end;

function TDbPgConnection.Query(const ASql: string): IDbQuery;
var
  Q: TPgQuery;
begin
  try
    Q := FConn.Query(TranslatePlaceholders(ASql));
  except
    on E: EPgError do RaisePgAsDb(E);
  end;
  Result := TDbPgQuery.Create(Q);
end;

function TDbPgConnection.Changes: Int64;
begin
  Result := FConn.Changes;
end;

function TDbPgConnection.Raw: Pointer;
begin
  { TPgQuery/TPgConn 不暴露原生 PGconn*；逃生舱对本后端返回 nil，
    需要原生句柄的特性走 nextpas.core.db.pg 门面直用 TPgConn。 }
  Result := nil;
end;

procedure TDbPgConnection.BeginTxn(const AImmediate: Boolean);
begin
  FLock.Acquire;
  try
    if FDepth = 0 then
    begin
      if AImmediate then
        PgExec('BEGIN IMMEDIATE')
      else
        PgExec('BEGIN');
      FDepth := 1;
    end
    else
      Inc(FDepth);
  finally
    FLock.Release;
  end;
end;

procedure TDbPgConnection.CommitTxn;
begin
  FLock.Acquire;
  try
    if FDepth = 0 then
      raise EDbError.CreateSimple(dbkPostgres,
        'CommitTxn without a matching BeginTxn on this connection');
    if FDepth > 1 then
      Dec(FDepth)
    else
    begin
      PgExec('COMMIT');
      FDepth := 0;
    end;
  finally
    FLock.Release;
  end;
end;

procedure TDbPgConnection.RollbackTxn;
begin
  FLock.Acquire;
  try
    if FDepth = 0 then
      raise EDbError.CreateSimple(dbkPostgres,
        'RollbackTxn without a matching BeginTxn on this connection');
    { 回滚失败吞掉（服务端可能已自行中止事务）；原异常由调用方重抛。 }
    try
      FConn.Exec('ROLLBACK');
    except
    end;
    FDepth := 0;
  finally
    FLock.Release;
  end;
end;

function TDbPgConnection.InTransaction: Boolean;
begin
  Result := TxDepth > 0;
end;

function TDbPgConnection.TxDepth: Integer;
begin
  FLock.Acquire;
  try
    Result := FDepth;
  finally
    FLock.Release;
  end;
end;

procedure TDbPgConnection.RestoreDepth(const ADepth: Integer);
begin
  FLock.Acquire;
  try
    FDepth := ADepth;
  finally
    FLock.Release;
  end;
end;

{ ---- 工厂 ---- }

function ConnectPostgres(const AConnInfo: string): IDbConnection;
var
  Conn: TPgConn;
begin
  try
    Conn := TPgConn.Create(AConnInfo);
  except
    on E: EPgError do RaisePgAsDb(E);
  end;
  Result := TDbPgConnection.Create(Conn);
end;

end.
