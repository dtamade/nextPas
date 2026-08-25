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
{ INC-7：带连接选项版本。BusyTimeoutMs 映射 connect_timeout（建连
  超时）；StatementTimeoutMs 建连后 SET statement_timeout（会话级）。 }
function ConnectPostgres(const AConnInfo: string;
  const AOptions: TDbConnectOptions): IDbConnection;
{ V3-C1：再带语句缓存容量（服务端 prepared statement；0 = 关闭）。
  migrate 的 INC-3 联动钩子经 IDbStmtCacheControl 自动失效缓存。 }
function ConnectPostgres(const AConnInfo: string;
  const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.text.conv,
  nextpas.core.db.err,
  nextpas.core.db.trace,
  nextpas.core.db.pg.ffi,
  nextpas.core.db.tx,
  nextpas.core.sync,
  nextpas.core.text.builder;

procedure RaisePgAsDb(const AE: EPgError);
var
  LCategory: TDbErrorCategory;
  LConstraint: TDbConstraintKind;
begin
  ClassifyPg(AE.SqlState, LCategory, LConstraint);
  raise EDbError.CreateFullPg(AE.SqlState, AE.Severity, AE.Detail,
    AE.Message, LCategory, LConstraint,
    AE.SchemaName, AE.TableName, AE.ColumnName);
end;

function PgCategoryOf(const AE: EPgError): TDbErrorCategory;
var
  LConstraint: TDbConstraintKind;
begin
  { 观测钩子（V3-B3）用：抛前取归一类目，与 RaisePgAsDb 同表 }
  ClassifyPg(AE.SqlState, Result, LConstraint);
end;

{** @desc 统一占位符翻译：把统一契约的 ?（或显式编号 ?N）翻译为
       libpq 的 $N 形态。扫描状态机跳过字符串字面量（'' 转义）、
       双引号标识符、行注释与块注释；dollar-quote 体不识别——与
       nextpas.core.db.pg.conn 的参数计数扫描同一受控边界。
       - ?  -> 下一个顺序编号 $k（1 起，逐个递增）
       - ?N -> 直接映射 $N（不扰动顺序计数） *}
function TranslatePlaceholders(const ASql: string): string;
var
  LB: IStringBuilder;
  I: Integer;
  C: Char;
  InStr, InDq, InLineC, InBlockC: Boolean;
  N: Integer;
  Seq: Integer;
begin
  LB := MakeStringBuilder(SizeUInt(Length(ASql)) + 16);
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
      LB.AppendChar(C);
      if C = #10 then
        InLineC := False;
    end
    else if InBlockC then
    begin
      LB.AppendChar(C);
      if (C = '*') and (I < Length(ASql)) and (ASql[I + 1] = '/') then
      begin
        LB.AppendChar('/');
        InBlockC := False;
        Inc(I);
      end;
    end
    else if InStr then
    begin
      LB.AppendChar(C);
      if C = '''' then
      begin
        if (I < Length(ASql)) and (ASql[I + 1] = '''') then
        begin
          LB.AppendChar('''');
          Inc(I);
        end
        else
          InStr := False;
      end;
    end
    else if InDq then
    begin
      LB.AppendChar(C);
      if C = '"' then
      begin
        if (I < Length(ASql)) and (ASql[I + 1] = '"') then
        begin
          LB.AppendChar('"');
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
            LB.AppendChar(C);
          end;
        '"' :
          begin
            InDq := True;
            LB.AppendChar(C);
          end;
        '-' :
          begin
            if (I < Length(ASql)) and (ASql[I + 1] = '-') then
              InLineC := True;
            LB.AppendChar(C);
          end;
        '/' :
          begin
            if (I < Length(ASql)) and (ASql[I + 1] = '*') then
            begin
              InBlockC := True;
              Inc(I);   { '*' 由 InBlockC 分支下一轮带出 }
              Continue;
            end;
            LB.AppendChar(C);
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
            if N = 0 then
            begin
              Inc(Seq);
              N := Seq;
            end;
            LB.AppendChar('$');
            LB.AppendInt(N);
            Continue;
          end;
      else
        LB.AppendChar(C);
      end;
    end;
    Inc(I);
  end;
  Result := LB.ToString;
end;

{ 结果列类型：按 PQftype OID 归入统一列类型；未知类型一律 dbcText
  （文本协议下取值即文本，安全兜底）。 }
function MapColumnType(const AOid: Cardinal): TDbColumnType;
begin
  case AOid of
    16:                       Result := dbcBool;     { bool（INC-6） }
    17:                       Result := dbcBlob;     { bytea }
    20, 21, 23:               Result := dbcInteger;  { int8/int2/int4 }
    700, 701, 1700:           Result := dbcFloat;    { float4/float8/numeric }
  else
    Result := dbcText;
  end;
end;

{ ---- V3-C2 数组字面量编码（pg 文本格式数组输入）----
  形态 = 花括号包裹、逗号分隔的元素串（如 1,2,3 加花括号）。NULL 掩码
  True 的行写裸 NULL 令牌（任何类型数组输入都接受）。文本元素恒加
  双引号并转义（反斜杠与双引号前置反斜杠）；引号内换行/制表等控制
  字符由文本协议原样承载。双精度经 core.text.number Schubfach 最短
  往返格式化（区域设置无关，NaN/Inf 原生输出，pg float8 输入均接受）。 }

procedure PgRejectNul(const AElem: string);
var
  I: Integer;
begin
  for I := 1 to Length(AElem) do
    if AElem[I] = #0 then
      raise EDbError.CreateSimple(dbkPostgres,
        'array bind: text 元素含 NUL(#0)——文本协议在 NUL 处截断，拒绝静默损坏');
end;

function PgTextArrayLiteral(const AValues: TDbStringArray;
  const ANullMask: TDbBoolArray): string;
var
  LB: IStringBuilder;
  K, I: Integer;
  LCap: Integer;
begin
  { 容量精确预估：括号 + 逗号 + 每元素两引号与原文长度（转义只增不减） }
  LCap := 2;
  if Length(AValues) > 1 then
    Inc(LCap, Length(AValues) - 1);
  for K := 0 to High(AValues) do
    Inc(LCap, Length(AValues[K]) + 2);
  LB := MakeStringBuilder(SizeUInt(LCap));
  LB.AppendChar('{');
  for K := 0 to High(AValues) do
  begin
    if K > 0 then
      LB.AppendChar(',');
    if (ANullMask <> nil) and ANullMask[K] then
      LB.AppendStr('NULL')
    else
    begin
      PgRejectNul(AValues[K]);
      LB.AppendChar('"');
      for I := 1 to Length(AValues[K]) do
        case AValues[K][I] of
          '\': LB.AppendStr('\\');
          '"': LB.AppendStr('\"');
        else
          LB.AppendChar(AValues[K][I]);
        end;
      LB.AppendChar('"');
    end;
  end;
  LB.AppendChar('}');
  Result := LB.ToString;
end;

function PgInt64ArrayLiteral(const AValues: TDbInt64Array;
  const ANullMask: TDbBoolArray): string;
var
  LB: IStringBuilder;
  K: Integer;
begin
  LB := MakeStringBuilder(SizeUInt(Length(AValues)) * 21 + 4);
  LB.AppendChar('{');
  for K := 0 to High(AValues) do
  begin
    if K > 0 then
      LB.AppendChar(',');
    if (ANullMask <> nil) and ANullMask[K] then
      LB.AppendStr('NULL')
    else
      LB.AppendInt(AValues[K]);
  end;
  LB.AppendChar('}');
  Result := LB.ToString;
end;

function PgDoubleArrayLiteral(const AValues: TDbDoubleArray;
  const ANullMask: TDbBoolArray): string;
var
  LB: IStringBuilder;
  K: Integer;
begin
  LB := MakeStringBuilder(SizeUInt(Length(AValues)) * 25 + 4);
  LB.AppendChar('{');
  for K := 0 to High(AValues) do
  begin
    if K > 0 then
      LB.AppendChar(',');
    if (ANullMask <> nil) and ANullMask[K] then
      LB.AppendStr('NULL')
    else
      LB.AppendFloat(AValues[K]);
  end;
  LB.AppendChar('}');
  Result := LB.ToString;
end;

function PgBoolArrayLiteral(const AValues: TDbBoolArray;
  const ANullMask: TDbBoolArray): string;
var
  LB: IStringBuilder;
  K: Integer;
begin
  LB := MakeStringBuilder(SizeUInt(Length(AValues)) * 6 + 4);
  LB.AppendChar('{');
  for K := 0 to High(AValues) do
  begin
    if K > 0 then
      LB.AppendChar(',');
    if (ANullMask <> nil) and ANullMask[K] then
      LB.AppendStr('NULL')
    else if AValues[K] then
      LB.AppendStr('t')
    else
      LB.AppendStr('f');
  end;
  LB.AppendChar('}');
  Result := LB.ToString;
end;

type
  TDbPgQuery = class(TInterfacedObject, IDbQuery, IDbArrayBinding)
  private
    FQuery: TPgQuery;
    { 查询级超时恢复钩（V3-B2）：pg 仅有会话级 statement_timeout 且
      执行惰性（首个 Step），故 Query(opts) 建对象时 SET 新值并记住
      原值，生效窗口 = 本查询对象存活期，析构时恢复原值。析构内只
      做直线 SQL 调用、失败吞掉（不涉闭包回调——C3 硬边界）。 }
    FRestoreConn: TPgConn;     { nil = 无恢复义务 }
    FRestoreSql: string;
    { 观测钩子（V3-B3）：nil = 无枢纽；FEmitted = 本执行周期已发
      OnQuery（首 Step 计时，同周期后续 Step 不再发）}
    FTrace: TDbTraceHub;
    FSql: string;              { 统一契约原文（占位符不翻译进摘要）}
    FEmitted: Boolean;
    { V3-C2 数组绑定状态：FScalarMask = 标量绑定覆盖位图（持久），
      FColMask = 列绑定位图（每次 BeginBind 清零）；两掩码并集是
      Step 全覆盖检查依据。FArrayActive/FArrayRows = 数组模式开关与
      BeginBind 声明的行数。 }
    FScalarMask: array of Boolean;
    FColMask: array of Boolean;
    FArrayRows: Integer;
    FArrayActive: Boolean;
    procedure MarkScalarBound(const AIndex: Integer);
    procedure RequireArrayMode;
    procedure ValidateColumnBind(const AIndex, ACount: Integer;
      const ANullMask: TDbBoolArray);
    procedure CheckCoverageOrFail;
    procedure SetParamLiteral(const AIndex: Integer; const ALiteral: string);
  public
    constructor Create(AQuery: TPgQuery; const ASql: string;
      ATrace: TDbTraceHub); overload;
    constructor Create(AQuery: TPgQuery; ARestoreConn: TPgConn;
      const ARestoreSql: string; const ASql: string;
      ATrace: TDbTraceHub); overload;
    destructor Destroy; override;

    procedure BindText(AIndex: Integer; const AValue: string);
    procedure BindInt64(AIndex: Integer; const AValue: Int64);
    procedure BindDouble(AIndex: Integer; const AValue: Double);
    procedure BindBlob(AIndex: Integer; const AValue: TBytes);
    procedure BindNull(AIndex: Integer);

    { IDbArrayBinding（V3-C2）：参数级批量绑定，unnest 数组展开路径 }
    procedure BeginBind(const ARows: Integer);
    procedure BindInt64Column(const AIndex: Integer;
      const AValues: TDbInt64Array); overload;
    procedure BindInt64Column(const AIndex: Integer;
      const AValues: TDbInt64Array; const ANullMask: TDbBoolArray); overload;
    procedure BindDoubleColumn(const AIndex: Integer;
      const AValues: TDbDoubleArray); overload;
    procedure BindDoubleColumn(const AIndex: Integer;
      const AValues: TDbDoubleArray; const ANullMask: TDbBoolArray); overload;
    procedure BindTextColumn(const AIndex: Integer;
      const AValues: TDbStringArray); overload;
    procedure BindTextColumn(const AIndex: Integer;
      const AValues: TDbStringArray; const ANullMask: TDbBoolArray); overload;
    procedure BindBoolColumn(const AIndex: Integer;
      const AValues: TDbBoolArray); overload;
    procedure BindBoolColumn(const AIndex: Integer;
      const AValues: TDbBoolArray; const ANullMask: TDbBoolArray); overload;

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

  {** pg 大对象流（INC-8，IDbBlobStream）：lo_* fastpath 薄包装。
      位置由服务端 fd 权威维护；接口释放即 lo_close。描述符在事务
      结束时失效——后续调用返回错误码，统一抛 EDbError。 *}
  TDbPgBlobStream = class(TInterfacedObject, IDbBlobStream)
  private
    FConnH: PGconn;
    FFd: Integer;          { <0 = 已关闭 }
  public
    constructor Create(AConnHandle: PGconn; const AOid: Int64;
      const AReadWrite: Boolean);
    destructor Destroy; override;
    function Read(ABuf: PByte; ACount: SizeUInt): SizeUInt;
    procedure Write(ABuf: PByte; ACount: SizeUInt);
    function Seek(AOffset: Int64; AOrigin: TDbSeekOrigin): Int64;
    function Size: Int64;
  end;

  TDbPgConnection = class(TInterfacedObject, IDbConnection, IDbTxControl,
    IDbSavepointControl, IDbBatchExecutor, IDbLargeObjectControl,
    IDbStmtCacheControl, IDbCapabilities, IDbTraceControl,
    IDbCancelControl)
  private
    FConn: TPgConn;
    FLock: INativeMutex;
    FDepth: Integer;
    { V3-B6 取消句柄：建连线程 PQgetCancel 一次，RequestCancel 从
      任意线程 PQcancel（libpq 文档明示线程安全）。nil = 已释放。 }
    FPGCancel: PGcancel;
    { 观测钩子枢纽（V3-B3）：监听器存取/摘要/计时/分发统一委托 }
    FTrace: TDbTraceHub;
    procedure PgExec(const ASql: string);
    { SHOW 会话变量原文（EPgError → EDbError 归一）；B2 超时恢复用 }
    function PgShowVar(const AName: string): string;
    { LO 句柄与事务耦合：无活动事务直接 fail-fast，防静默坏句柄 }
    procedure RequireActiveTxn;
  public
    constructor Create(AConn: TPgConn);          { 取得所有权 }
    destructor Destroy; override;

    { IDbTraceControl }
    procedure SetListener(const AListener: IDbTraceListener);
    function HasListener: Boolean;

    function Kind: TDbKind;
    procedure Exec(const ASql: string); overload;
    procedure Exec(const ASql: string;
      const AOptions: TDbExecOptions); overload;
    function Query(const ASql: string): IDbQuery; overload;
    function Query(const ASql: string;
      const AOptions: TDbExecOptions): IDbQuery; overload;
    function Changes: Int64;
    function Raw: Pointer;

    { IDbTxControl }
    procedure BeginTxn(const AImmediate: Boolean = False);
    procedure CommitTxn;
    procedure RollbackTxn;
    function InTransaction: Boolean;
    function TxDepth: Integer;

    { IDbSavepointControl }
    procedure Savepoint(const AName: string);
    procedure RollbackTo(const AName: string);
    procedure ReleaseTo(const AName: string);

    { IDbBatchExecutor }
    procedure ExecuteBatch(const ASteps: TDbSqlSteps);

    { IDbLargeObjectControl：OID 模型大对象（INC-8） }
    function CreateLO: Int64;
    function OpenLO(const AOid: Int64; const AReadWrite: Boolean): IDbBlobStream;
    procedure UnlinkLO(const AOid: Int64);

    { IDbStmtCacheControl（V3-C1）}
    procedure Clear;
    function Size: Integer;
    function HitRate: Double;

    { IDbCapabilities（V3-B1）——Kind 由 IDbConnection.Kind 承担 }
    function ProductName: string;
    function ProductVersion: string;
    function SupportsSavepoints: Boolean;
    function SupportsBatchExecutor: Boolean;
    function SupportsStmtCacheControl: Boolean;
    function SupportsLargeObjects: Boolean;
    function SupportsArrayBinding: Boolean;
    { 原生布尔列类型：pg bool(OID16)=True；sqlite 靠声明亲和、
      mysql 靠 TINYINT(1) 约定 = False }
    function SupportsNativeBool: Boolean;
    function SupportsMultiStatementExec: Boolean;
    function SupportsStatementTimeout: Boolean;
    function CaseSensitiveIdentifiers: Boolean;
    function MaxPlaceholders: Integer;

    { IDbCancelControl（V3-B6）：Arm/Disarm 为无操作（PQcancel 无需
      武装），RequestCancel 经 PQcancel 尽力中断 }
    function ArmCancel: Boolean;
    procedure DisarmCancel;
    procedure RequestCancel;
  end;

{ ---- TDbPgQuery ---- }

constructor TDbPgQuery.Create(AQuery: TPgQuery; const ASql: string;
  ATrace: TDbTraceHub);
begin
  inherited Create;
  FQuery := AQuery;
  FRestoreConn := nil;
  FRestoreSql := '';
  FSql := ASql;
  FTrace := ATrace;
  FEmitted := False;
  { V3-C2：覆盖位图按语句参数个数分配（TPgQuery 构造时已从 SQL
    扫描出 $N 计数）。 }
  SetLength(FScalarMask, FQuery.ParamCount);
  SetLength(FColMask, FQuery.ParamCount);
  FArrayActive := False;
  FArrayRows := 0;
end;

constructor TDbPgQuery.Create(AQuery: TPgQuery; ARestoreConn: TPgConn;
  const ARestoreSql: string; const ASql: string; ATrace: TDbTraceHub);
begin
  inherited Create;
  FQuery := AQuery;
  FRestoreConn := ARestoreConn;
  FRestoreSql := ARestoreSql;
  FSql := ASql;
  FTrace := ATrace;
  FEmitted := False;
  SetLength(FScalarMask, FQuery.ParamCount);
  SetLength(FColMask, FQuery.ParamCount);
  FArrayActive := False;
  FArrayRows := 0;
end;

{ 标量绑定打点：置标量位并清除同位列位（显式标量替换列绑定，
  last-wins）。 }
procedure TDbPgQuery.MarkScalarBound(const AIndex: Integer);
begin
  if (AIndex >= 1) and (AIndex <= Length(FScalarMask)) then
  begin
    FScalarMask[AIndex - 1] := True;
    FColMask[AIndex - 1] := False;
  end;
end;

destructor TDbPgQuery.Destroy;
begin
  if FRestoreConn <> nil then
  begin
    try
      FRestoreConn.Exec(FRestoreSql);   { 恢复会话超时原值；失败吞掉 }
    except
    end;
    FRestoreConn := nil;
  end;
  FQuery.Free;
  inherited Destroy;
end;

procedure TDbPgQuery.BindText(AIndex: Integer; const AValue: string);
begin
  try
    FQuery.BindText(AIndex, AValue);
    MarkScalarBound(AIndex);   { V3-C2 覆盖位图打点 }
  except
    on E: EPgError do RaisePgAsDb(E);
  end;
end;

procedure TDbPgQuery.BindInt64(AIndex: Integer; const AValue: Int64);
begin
  try
    FQuery.BindInt64(AIndex, AValue);
    MarkScalarBound(AIndex);   { V3-C2 覆盖位图打点 }
  except
    on E: EPgError do RaisePgAsDb(E);
  end;
end;

procedure TDbPgQuery.BindDouble(AIndex: Integer; const AValue: Double);
begin
  try
    FQuery.BindDouble(AIndex, AValue);
    MarkScalarBound(AIndex);   { V3-C2 覆盖位图打点 }
  except
    on E: EPgError do RaisePgAsDb(E);
  end;
end;

procedure TDbPgQuery.BindBlob(AIndex: Integer; const AValue: TBytes);
begin
  try
    FQuery.BindBlob(AIndex, AValue);
    MarkScalarBound(AIndex);   { V3-C2 覆盖位图打点 }
  except
    on E: EPgError do RaisePgAsDb(E);
  end;
end;

procedure TDbPgQuery.BindNull(AIndex: Integer);
begin
  try
    FQuery.BindNull(AIndex);
    MarkScalarBound(AIndex);   { V3-C2 覆盖位图打点 }
  except
    on E: EPgError do RaisePgAsDb(E);
  end;
end;

{ ---- IDbArrayBinding（V3-C2）---- }

procedure TDbPgQuery.RequireArrayMode;
begin
  if not FArrayActive then
    raise EDbError.CreateSimple(dbkPostgres,
      'array bind: BeginBind 未调用——先声明本批行数再绑列');
end;

procedure TDbPgQuery.ValidateColumnBind(const AIndex, ACount: Integer;
  const ANullMask: TDbBoolArray);
begin
  RequireArrayMode;
  if (AIndex < 1) or (AIndex > Length(FColMask)) then
    raise EDbError.CreateSimple(dbkPostgres,
      'array bind: 列索引 ' + IntToStr(AIndex) + ' 越界（本语句占位符共 ' +
      IntToStr(Length(FColMask)) + ' 个）');
  if FColMask[AIndex - 1] then
    raise EDbError.CreateSimple(dbkPostgres,
      'array bind: 列 ' + IntToStr(AIndex) + ' 在本批已绑定（重复绑定拒绝）');
  if ACount <> FArrayRows then
    raise EDbError.CreateSimple(dbkPostgres,
      'array bind: 列 ' + IntToStr(AIndex) + ' 元素个数 ' + IntToStr(ACount) +
      ' ≠ BeginBind 声明的行数 ' + IntToStr(FArrayRows));
  if (ANullMask <> nil) and (Length(ANullMask) <> ACount) then
    raise EDbError.CreateSimple(dbkPostgres,
      'array bind: 列 ' + IntToStr(AIndex) + ' 的 NULL 掩码长度 ' +
      IntToStr(Length(ANullMask)) + ' ≠ 元素个数 ' + IntToStr(ACount));
end;

procedure TDbPgQuery.CheckCoverageOrFail;
var
  I: Integer;
begin
  if not FArrayActive then
    Exit;
  for I := 0 to High(FScalarMask) do
    if not (FScalarMask[I] or FColMask[I]) then
      raise EDbError.CreateSimple(dbkPostgres,
        'array bind: 参数 ' + IntToStr(I + 1) + ' 未绑定——数组模式强制全覆盖' +
        '（防 unnest(NULL) 静默零行）');
end;

procedure TDbPgQuery.SetParamLiteral(const AIndex: Integer;
  const ALiteral: string);
begin
  try
    FQuery.BindText(AIndex, ALiteral);
  except
    on E: EPgError do RaisePgAsDb(E);
  end;
end;

procedure TDbPgQuery.BeginBind(const ARows: Integer);
begin
  if ARows < 0 then
    raise EDbError.CreateSimple(dbkPostgres, 'array bind: 行数不能为负');
  FArrayRows := ARows;
  FArrayActive := True;
  { 新开批：清列标记；标量位保留（常量列跨批仍有效）。
    零占位符语句位图本就为空，跳过。 }
  if Length(FColMask) > 0 then
    FillChar(FColMask[0], Length(FColMask), 0);
end;

procedure TDbPgQuery.BindInt64Column(const AIndex: Integer;
  const AValues: TDbInt64Array);
begin
  BindInt64Column(AIndex, AValues, nil);
end;

procedure TDbPgQuery.BindInt64Column(const AIndex: Integer;
  const AValues: TDbInt64Array; const ANullMask: TDbBoolArray);
begin
  ValidateColumnBind(AIndex, Length(AValues), ANullMask);
  SetParamLiteral(AIndex, PgInt64ArrayLiteral(AValues, ANullMask));
  FColMask[AIndex - 1] := True;
end;

procedure TDbPgQuery.BindDoubleColumn(const AIndex: Integer;
  const AValues: TDbDoubleArray);
begin
  BindDoubleColumn(AIndex, AValues, nil);
end;

procedure TDbPgQuery.BindDoubleColumn(const AIndex: Integer;
  const AValues: TDbDoubleArray; const ANullMask: TDbBoolArray);
begin
  ValidateColumnBind(AIndex, Length(AValues), ANullMask);
  SetParamLiteral(AIndex, PgDoubleArrayLiteral(AValues, ANullMask));
  FColMask[AIndex - 1] := True;
end;

procedure TDbPgQuery.BindTextColumn(const AIndex: Integer;
  const AValues: TDbStringArray);
begin
  BindTextColumn(AIndex, AValues, nil);
end;

procedure TDbPgQuery.BindTextColumn(const AIndex: Integer;
  const AValues: TDbStringArray; const ANullMask: TDbBoolArray);
begin
  ValidateColumnBind(AIndex, Length(AValues), ANullMask);
  SetParamLiteral(AIndex, PgTextArrayLiteral(AValues, ANullMask));
  FColMask[AIndex - 1] := True;
end;

procedure TDbPgQuery.BindBoolColumn(const AIndex: Integer;
  const AValues: TDbBoolArray);
begin
  BindBoolColumn(AIndex, AValues, nil);
end;

procedure TDbPgQuery.BindBoolColumn(const AIndex: Integer;
  const AValues: TDbBoolArray; const ANullMask: TDbBoolArray);
begin
  ValidateColumnBind(AIndex, Length(AValues), ANullMask);
  SetParamLiteral(AIndex, PgBoolArrayLiteral(AValues, ANullMask));
  FColMask[AIndex - 1] := True;
end;

function TDbPgQuery.Step: Boolean;
var
  LT0: QWord;
  LTimed: Boolean;
begin
  { V3-C2 数组模式全覆盖检查：纯客户端校验（编程错误不进观测窗口，
    与 §2.12 口径一致），先于计时开始 }
  CheckCoverageOrFail;
  { 观测窗口 = 本执行周期首个 Step（绑定+服务端执行+首行），见 §2.12 }
  LT0 := 0;
  LTimed := (FTrace <> nil) and (not FEmitted) and FTrace.BeginOp(LT0);
  try
    Result := FQuery.Step;
    if LTimed then
    begin
      FEmitted := True;
      FTrace.NotifyQuery(LT0, FSql);
    end;
  except
    on E: EPgError do
    begin
      if LTimed then
        FTrace.NotifyError(PgCategoryOf(E), FSql);
      RaisePgAsDb(E);
    end;
  end;
end;

procedure TDbPgQuery.Reset;
begin
  FEmitted := False;   { 重执行周期重新计时 }
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
    { NULL 是行级信号（与 sqlite 声明列同契约）：值空一律 dbcNull，
      非空才回落列 OID 类型 }
    if FQuery.IsNull(AIndex) then
      Exit(dbcNull);
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
    { bool 列归一：libpq 文本协议给出 't'/'f'，统一层按 INC-6 映射
      1/0（与 sqlite INTEGER 布尔约定一致）；GetText 保持原文。 }
    if FQuery.ColumnFieldOid(AIndex) = PG_BOOLOID then
      Exit(Ord(FQuery.GetText(AIndex) = 't'));
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
  { V3-B6：取消句柄建连期取一次（PQgetCancel 失败 = 不支持取消，
    RequestCancel 退化为无害 no-op，诚实降级不报错） }
  if pq_getcancel <> nil then
    FPGCancel := pq_getcancel(AConn.Handle)
  else
    FPGCancel := nil;
  FTrace := TDbTraceHub.Create;
  { OnAcquire 由 SetListener 挂载时补发（§2.12），ctor 不预发 }
end;

{ ---- IDbTraceControl（V3-B3）---- }

procedure TDbPgConnection.SetListener(
  const AListener: IDbTraceListener);
begin
  FTrace.SetListener(AListener);
end;

function TDbPgConnection.HasListener: Boolean;
begin
  Result := FTrace.Active;
end;

{ ---- IDbStmtCacheControl（V3-C1）---- }

procedure TDbPgConnection.Clear;
begin
  FConn.ClearPrepared;                     { DEALLOCATE ALL + 清簿记 }
end;

function TDbPgConnection.Size: Integer;
begin
  Result := FConn.PreparedCount;
end;

function TDbPgConnection.HitRate: Double;
begin
  Result := FConn.PreparedHitRate;
end;

{ ---- IDbCapabilities（V3-B1）---- }

function TDbPgConnection.ProductName: string;
begin
  Result := 'PostgreSQL';
end;

function TDbPgConnection.ProductVersion: string;
begin
  Result := IntToStr(FConn.ServerVersion);
end;

function TDbPgConnection.SupportsSavepoints: Boolean;
begin
  Result := True;
end;

function TDbPgConnection.SupportsBatchExecutor: Boolean;
begin
  Result := True;
end;

function TDbPgConnection.SupportsStmtCacheControl: Boolean;
begin
  Result := True;
end;

function TDbPgConnection.SupportsLargeObjects: Boolean;
begin
  Result := True;
end;

function TDbPgConnection.SupportsArrayBinding: Boolean;
begin
  Result := True;   { unnest 数组展开路径，V3-C2 }
end;

{ ---- IDbCancelControl（V3-B6）---- }

function TDbPgConnection.ArmCancel: Boolean;
begin
  Result := True;    { PQcancel 无需武装：句柄建连期已备 }
end;

procedure TDbPgConnection.DisarmCancel;
begin
  { 无操作（对称性保留） }
end;

procedure TDbPgConnection.RequestCancel;
var
  LErr: array[0..255] of AnsiChar;
begin
  { 线程安全（libpq 文档明示）；失败尽力而为——连接已断等场景下
    在途调用本就会以 decConnection 收场。PQcancel 返回值不作为
    取消成功依据：取消是否生效由在途语句的错误码（57014）说话。 }
  if FPGCancel <> nil then
    pq_cancel(FPGCancel, @LErr[0], SizeOf(LErr));
end;

function TDbPgConnection.SupportsNativeBool: Boolean;
begin
  Result := True;   { bool OID16，INC-6 }
end;

function TDbPgConnection.SupportsMultiStatementExec: Boolean;
begin
  Result := True;   { libpq 单次 Exec 原生多语句 }
end;

function TDbPgConnection.SupportsStatementTimeout: Boolean;
begin
  Result := True;   { 会话级 statement_timeout（INC-7 诚实表） }
end;

function TDbPgConnection.CaseSensitiveIdentifiers: Boolean;
begin
  Result := False;  { 未加引号标识符折叠小写（§2.6） }
end;

function TDbPgConnection.MaxPlaceholders: Integer;
begin
  Result := 65535;  { 扩展协议参数上限 }
end;

destructor TDbPgConnection.Destroy;
begin
  { V3-B6：取消句柄先于连接关闭释放（PQcancel 不得引用已关连接） }
  if FPGCancel <> nil then
  begin
    pq_freeCancel(FPGCancel);
    FPGCancel := nil;
  end;
  FTrace.NotifyRelease;   { OnRelease = 连接关闭 }
  FreeAndNil(FTrace);
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
var
  LT0: QWord;
  LTimed: Boolean;
begin
  LT0 := 0;
  LTimed := FTrace.BeginOp(LT0);
  try
    PgExec(ASql);
    if LTimed then
      FTrace.NotifyQuery(LT0, ASql);
  except
    on E: EDbError do
    begin
      if LTimed then
        FTrace.NotifyError(E.Category, ASql);
      raise;
    end;
  end;
end;

procedure TDbPgConnection.Exec(const ASql: string;
  const AOptions: TDbExecOptions);
var
  LPrev: string;
  LT0: QWord;
  LTimed: Boolean;
begin
  if AOptions.TimeoutMs <= 0 then
  begin
    Exec(ASql);   { advisory：0 = 不设置（委托已插桩路径，无双发）}
    Exit;
  end;
  { pq_exec 同步执行窗口内会话级 SET/恢复（SHOW 原样回写，免解析
    'ms'/'s'/'min' 单位形态）；超时触发 57014 → decTimeout。
    观测窗口只包用户语句（SET 机制开销不计），见 §2.12 }
  LPrev := PgShowVar('statement_timeout');
  try
    PgExec('SET statement_timeout = ' + IntToStr(AOptions.TimeoutMs));
    LT0 := 0;
    LTimed := FTrace.BeginOp(LT0);
    try
      PgExec(ASql);
      if LTimed then
        FTrace.NotifyQuery(LT0, ASql);
    except
      on E: EDbError do
      begin
        if LTimed then
          FTrace.NotifyError(E.Category, ASql);
        raise;
      end;
    end;
  finally
    try
      PgExec('SET statement_timeout = ' + LPrev);
    except
    end;
  end;
end;

function TDbPgConnection.PgShowVar(const AName: string): string;
begin
  { SHOW 经底层 TPgConn.ShowVar；EPgError → EDbError 归一 }
  Result := '';
  try
    Result := FConn.ShowVar(AName);
  except
    on E: EPgError do RaisePgAsDb(E);
  end;
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
  Result := TDbPgQuery.Create(Q, ASql, FTrace);
end;

function TDbPgConnection.Query(const ASql: string;
  const AOptions: TDbExecOptions): IDbQuery;
var
  LPrev: string;
  LSet: Boolean;
  Q: TPgQuery;
begin
  if AOptions.TimeoutMs <= 0 then
    Exit(Query(ASql));
  { 执行惰性 → 会话级机制只能以查询对象存活期为生效窗口：
    SET 新值 + 记住原值，TDbPgQuery 析构时恢复。建连失败路径在
    本层先恢复再抛，成功路径恢复义务移交查询对象。 }
  LPrev := PgShowVar('statement_timeout');
  LSet := False;
  try
    PgExec('SET statement_timeout = ' + IntToStr(AOptions.TimeoutMs));
    LSet := True;
    Q := FConn.Query(TranslatePlaceholders(ASql));
  except
    on E: EPgError do
    begin
      if LSet then
        try
          PgExec('SET statement_timeout = ' + LPrev);
        except
        end;
      RaisePgAsDb(E);
    end;
  end;
  Result := TDbPgQuery.Create(Q, FConn,
    'SET statement_timeout = ' + LPrev, ASql, FTrace);
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
    { 任意深度 = 回滚整个事务（对齐 sqlite 侧与 SQL 语义；V2-S2 起
      统一，此前深度 > 1 只降簿记不真回滚）。回滚失败吞掉（服务端
      可能已自行中止事务）；原异常由调用方重抛。 }
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

procedure TDbPgConnection.Savepoint(const AName: string);
begin
  ValidateDbSavepointName(dbkPostgres, AName);
  PgExec('SAVEPOINT ' + AName);
end;

procedure TDbPgConnection.RollbackTo(const AName: string);
begin
  ValidateDbSavepointName(dbkPostgres, AName);
  PgExec('ROLLBACK TO ' + AName);
end;

procedure TDbPgConnection.ReleaseTo(const AName: string);
begin
  ValidateDbSavepointName(dbkPostgres, AName);
  PgExec('RELEASE ' + AName);
end;

procedure TDbPgConnection.ExecuteBatch(const ASteps: TDbSqlSteps);
var
  K: Integer;
  LJoined: IStringBuilder;
begin
  if Length(ASteps) = 0 then
    Exit;
  { 网络协议按往返计价：合并为单次 Exec（libpq 原生多语句），
    N 步 = 1 往返。步骤契约是完整独立语句，';' 连接不改语义 }
  LJoined := MakeStringBuilder(256);
  K := 0;
  while K <= High(ASteps) do
  begin
    if K > 0 then
      LJoined.AppendStr(';'#10);
    LJoined.AppendStr(ASteps[K]);
    Inc(K);
  end;
  WithTransaction(Self, procedure
  begin
    Exec(LJoined.ToString);
  end);
end;

{ ---- 工厂 ---- }

function ConnectPostgres(const AConnInfo: string): IDbConnection;
begin
  Result := ConnectPostgres(AConnInfo, TDbConnectOptions.Default,
    DEFAULT_PG_STMT_CACHE_CAPACITY);
end;

function ConnectPostgres(const AConnInfo: string;
  const AOptions: TDbConnectOptions): IDbConnection;
begin
  Result := ConnectPostgres(AConnInfo, AOptions,
    DEFAULT_PG_STMT_CACHE_CAPACITY);
end;

function ConnectPostgres(const AConnInfo: string;
  const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection;
var
  Conn: TPgConn;
  LConnInfo: string;
begin
  LConnInfo := AConnInfo;
  if AOptions.BusyTimeoutMs > 0 then
    LConnInfo := LConnInfo + ' connect_timeout=' +
      IntToStr(AOptions.BusyTimeoutMs);
  try
    Conn := TPgConn.Create(LConnInfo, AStmtCacheCapacity);
    { 会话级语句超时（INC-7）：触发时 SQLSTATE 57014 → decTimeout。
      SET 本身无参数，不进语句缓存路径。 }
    if AOptions.StatementTimeoutMs > 0 then
      Conn.Exec('SET statement_timeout = ' + IntToStr(AOptions.StatementTimeoutMs));
  except
    on E: EPgError do RaisePgAsDb(E);
  end;
  Result := TDbPgConnection.Create(Conn);
end;

{ ---- TDbPgBlobStream ---- }

constructor TDbPgBlobStream.Create(AConnHandle: PGconn; const AOid: Int64;
  const AReadWrite: Boolean);
var
  LMode: Integer;
begin
  inherited Create;
  FConnH := AConnHandle;
  LMode := INV_READ;
  if AReadWrite then
    Inc(LMode, INV_WRITE);
  FFd := lo_open(FConnH, TOid(AOid), LMode);
  if FFd < 0 then
    raise EDbError.CreateSimple(dbkPostgres,
      'lo_open failed: ' + string(AnsiString(pq_errorMessage(FConnH))));
end;

destructor TDbPgBlobStream.Destroy;
begin
  if FFd >= 0 then
  begin
    lo_close(FConnH, FFd);             { 接口释放即关闭；析构内不抛 }
    FFd := -1;
  end;
  inherited Destroy;
end;

function TDbPgBlobStream.Read(ABuf: PByte; ACount: SizeUInt): SizeUInt;
var
  N: SizeInt;
begin
  N := lo_read(FConnH, FFd, PAnsiChar(ABuf), SizeInt(ACount));
  if N < 0 then
    raise EDbError.CreateSimple(dbkPostgres,
      'lo_read failed: ' + string(AnsiString(pq_errorMessage(FConnH))));
  Result := SizeUInt(N);
end;

procedure TDbPgBlobStream.Write(ABuf: PByte; ACount: SizeUInt);
var
  N: SizeInt;
begin
  if ACount > SizeUInt(High(SizeInt)) then
    raise EDbError.CreateSimple(dbkPostgres, 'lo_write chunk too large');
  N := lo_write(FConnH, FFd, PAnsiChar(ABuf), SizeInt(ACount));
  if (N < 0) or (SizeUInt(N) <> ACount) then
    raise EDbError.CreateSimple(dbkPostgres,
      'lo_write short write: ' + string(AnsiString(pq_errorMessage(FConnH))));
end;

function TDbPgBlobStream.Seek(AOffset: Int64; AOrigin: TDbSeekOrigin): Int64;
var
  R: Int64;
  LWhence: Integer;
begin
  case AOrigin of
    dsoBegin:   LWhence := PG_SEEK_SET;
    dsoCurrent: LWhence := PG_SEEK_CUR;
    dsoEnd:     LWhence := PG_SEEK_END;
  else
    LWhence := PG_SEEK_SET;
  end;
  R := lo_lseek64(FConnH, FFd, AOffset, LWhence);
  if R < 0 then
    raise EDbError.CreateSimple(dbkPostgres,
      'lo_lseek64 failed: ' + string(AnsiString(pq_errorMessage(FConnH))));
  Result := R;
end;

function TDbPgBlobStream.Size: Int64;
var
  LCur, LEnd: Int64;
begin
  LCur := lo_tell64(FConnH, FFd);
  if LCur < 0 then
    raise EDbError.CreateSimple(dbkPostgres, 'lo_tell64 failed');
  LEnd := lo_lseek64(FConnH, FFd, 0, PG_SEEK_END);
  if LEnd < 0 then
    raise EDbError.CreateSimple(dbkPostgres, 'lo_lseek64(END) failed');
  if lo_lseek64(FConnH, FFd, LCur, PG_SEEK_SET) < 0 then
    raise EDbError.CreateSimple(dbkPostgres, 'lo position restore failed');
  Result := LEnd;
end;

{ ---- IDbLargeObjectControl ---- }

procedure TDbPgConnection.RequireActiveTxn;
begin
  if TxDepth = 0 then
    raise EDbError.CreateSimple(dbkPostgres,
      'large object operations require an active transaction ' +
      '(use WithTransaction)');
end;

function TDbPgConnection.CreateLO: Int64;
var
  Oid: TOid;
begin
  RequireActiveTxn;
  Oid := lo_creat(FConn.Handle, INV_READ or INV_WRITE);
  if Oid = PG_INVALID_OID then
    raise EDbError.CreateSimple(dbkPostgres,
      'lo_creat failed: ' + string(AnsiString(pq_errorMessage(FConn.Handle))));
  Result := Int64(Oid);
end;

function TDbPgConnection.OpenLO(const AOid: Int64;
  const AReadWrite: Boolean): IDbBlobStream;
begin
  RequireActiveTxn;
  Result := TDbPgBlobStream.Create(FConn.Handle, AOid, AReadWrite);
end;

procedure TDbPgConnection.UnlinkLO(const AOid: Int64);
begin
  { 反向契约：libpq 的 lo_unlink 非 fastpath，客户端实现自管
    BEGIN/END 执行清理 SQL——事务内调用会嵌套 BEGIN 并提前终结
    外部事务。故强制在事务外调用（fail-fast 防静默提交破坏）。 }
  if TxDepth > 0 then
    raise EDbError.CreateSimple(dbkPostgres,
      'lo_unlink manages its own transaction: call it OUTSIDE ' +
      'WithTransaction');
  { 注意返回值语义：lo_unlink 成功 = 1，失败 = -1（非 0/负惯例） }
  if lo_unlink(FConn.Handle, TOid(AOid)) < 0 then
    raise EDbError.CreateSimple(dbkPostgres,
      'lo_unlink failed: ' +
        string(AnsiString(pq_errorMessage(FConn.Handle))));
end;

end.
