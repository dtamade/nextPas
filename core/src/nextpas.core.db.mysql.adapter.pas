unit nextpas.core.db.mysql.adapter;

{** @desc IDbConnection/IDbQuery 的 MySQL/MariaDB 适配器（V3-A2）。

       执行模型：IDbQuery 走 prepared statement 二进制协议
       （mysql_stmt_*），与 pg 侧 execParams 同级——参数化即注入安全。
       执行惰性触发（首个 Step），列元数据在 Step 后可读，与统一层
       消费时序一致。

       结果绑定按声明类型请求：整数族绑 LONGLONG、浮点族绑 DOUBLE、
       其余（文本/blob/DECIMAL/日期/JSON/BIT）一律 VAR_STRING——
       DECIMAL 在二进制协议里本就是 length-prefixed 文本，日期族由
       客户端库转连接字符集文本；截断时按实际长度扩缓冲经
       mysql_stmt_fetch_column 重取。

       双方言 MYSQL_BIND 编组（Oracle 72B / MariaDB 112B，buffer_type
       偏移与宽度不同）在本单元单点实现——A1 ffi 镜像钉死布局，此处
       按 loader 探测的 flavor 选择写法，别处不得触碰原生布局。

       占位符：MySQL 原生 ?。统一契约的 ?N 显式编号经槽位计划重写为
       顺序 ? 并携带物理槽→逻辑号映射；扫描跳过字符串字面量、反引号
       标识符、-- 与 # 行注释、块注释。

       事务控制面：连接内计数式簿记（互斥锁保护），语义对齐 pg/sqlite
       适配器；SAVEPOINT 原生支持（RELEASE 需带 SAVEPOINT 关键字，
       与 pg 方言差异）。BEGIN IMMEDIATE 无对应语义，标志接受但为
       no-op（契约差异登记 CONTRACT §2.3）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.db.base,
  nextpas.core.db.sqlscan,
  nextpas.core.db.intf,
  nextpas.core.db.mysql.base;

type
  TIntArray = array of Integer;

  { 解析后的 DSN 部件（ParseMySqlDsn 输出） }
  TDbMysqlDsnParts = record
    Host: string;      { 缺省 127.0.0.1 }
    Port: Integer;     { 缺省 3306 }
    User: string;
    Password: string;
    Database: string;
    Socket: string;    { unix socket 路径；非空时优先于 host }
  end;

{ 创建 mysql/mariadb 连接并返回统一接口。
  DSN 形态（空格分隔 key=value，值可用 ' 或 " 包裹以含空格/@）：
    host=127.0.0.1 port=3306 user=root password='p@ss wd' db=app
    socket=/var/run/mysqld/mysqld.sock   （socket 存在时优先于 host）
  失败抛 EDbError（Backend=dbkMysql，BackendCode=CR_*/ER_*，
  SqlState 并存）。 }
function ConnectMysql(const ADsn: string): IDbConnection;
{ INC-7：BusyTimeoutMs 映射 MYSQL_OPT_CONNECT_TIMEOUT（秒粒度向上
  取整）；StatementTimeoutMs 仅 mfMysql 且 server ≥8.0 应用
  max_execution_time（SELECT 域；版本探测后静默降级。MariaDB 的
  max_statement_time 语法不同，登记路线图缺口账本）。 }
function ConnectMysql(const ADsn: string;
  const AOptions: TDbConnectOptions): IDbConnection; inline;

{ ---- 纯函数导出供门禁离线验证 ---- }

{ DSN 解析：key=value 空格分词，值可用 ' 或 " 包裹；未知键
  fail-fast。 }
function ParseMySqlDsn(const ADsn: string): TDbMysqlDsnParts;

{ 占位符槽位计划：? 保持顺序编号；?N 重写为 ? 并把逻辑号 N 记入该
  物理槽。ARewritten = 重写后 SQL；ASlots[物理] = 逻辑号（1 起）；
  Result = 物理槽总数。 }
function TranslatePlaceholdersMy(const ASql: string;
  out ARewritten: string; out ASlots: TIntArray): Integer;

{ 把单个物理槽的绑定写入零填充原生块（双方言布局单点实现；
  AError 为截断检测出参指针，参数侧传 nil）。偏移常量来自 A1
  门禁钉死的镜像布局；`inline` 消除批量绑定循环的调用开销（热路径）。 }
procedure WriteBindSlot(ABase: Pointer; const AIndex, ANativeSize: Integer;
  ABufferType: Cardinal; ABuffer: Pointer; ABufferLength: QWord;
  AIsNull: PBoolean; AError: Pointer; ALength: PQWord;
  const AIsUnsigned: Boolean); inline;

implementation

uses
  nextpas.core.exception,
  nextpas.core.base.utils,
  nextpas.core.text.conv,
  nextpas.core.db.err,
  nextpas.core.db.trace,
  nextpas.core.db.tx,
  nextpas.core.sync,
  nextpas.core.text.builder,
  nextpas.core.db.mysql.ffi,
  nextpas.core.db.mysql.loader;

const
  { 参数绑定 buffer_type（enum_field_types 值） }
  MY_PT_LONGLONG = MYSQL_TYPE_LONGLONG;   { Int64 直绑 }
  MY_PT_DOUBLE   = MYSQL_TYPE_DOUBLE;
  MY_PT_STRING   = MYSQL_TYPE_VAR_STRING; { 其余一律请求文本形态 }
  MY_PT_NULL     = MYSQL_TYPE_NULL;
  { 二进制字符集编号：blob/binary/varbinary/bit 家族的 charsetnr }
  MY_BINARY_CHARSET = 63;
  { 结果缓冲起始容量（截断后按实际长度翻倍扩取） }
  MY_BUF_INITIAL = 256;

type
  { 绑定值逻辑形态 }
  TMyBindKind = (mbkNone, mbkInt, mbkDouble, mbkText, mbkBlob, mbkNull);
  TMyBindValue = record
    Kind: TMyBindKind;
    IntVal: Int64;
    DblVal: Double;
    TextVal: string;        { 字符串按框架约定即 utf8 字节，直存 }
    BlobVal: TBytes;
  end;

{ ---- 错误桥接 ---- }
{ 惯例：异常对象非引用计数——单次直接构造最终 EDbError 并 raise，
  不经中间异常对象（防孤儿）。 }

{ 连接句柄错误现场 → EDbError }
procedure RaiseMyConn(AConnH: TMysql);
var
  LCategory: TDbErrorCategory;
  LConstraint: TDbConstraintKind;
  LCode: Integer;
  LMsg, LSs: string;
begin
  LCode := Integer(my_errno(AConnH));
  LMsg := AnsiPtrToStr(my_error(AConnH));
  LSs := AnsiPtrToStr(my_sqlstate(AConnH));
  ClassifyMy(LCode, LSs, LCategory, LConstraint);
  raise EDbError.CreateFullMy(LCode, LSs, LMsg, LCategory, LConstraint);
end;

{ stmt 句柄错误现场 → EDbError }
procedure RaiseMyStmt(AStmt: TMysqlStmt);
var
  LCategory: TDbErrorCategory;
  LConstraint: TDbConstraintKind;
  LCode: Integer;
  LMsg, LSs: string;
begin
  LCode := Integer(my_stmtErrno(AStmt));
  LMsg := AnsiPtrToStr(my_stmtError(AStmt));
  LSs := AnsiPtrToStr(my_stmtSqlstate(AStmt));
  ClassifyMy(LCode, LSs, LCategory, LConstraint);
  raise EDbError.CreateFullMy(LCode, LSs, LMsg, LCategory, LConstraint);
end;

{ 读走 stmt 错误后关闭句柄再抛（防句柄泄漏） }
procedure RaiseMyStmtClose(AStmt: TMysqlStmt);
var
  LCategory: TDbErrorCategory;
  LConstraint: TDbConstraintKind;
  LCode: Integer;
  LMsg, LSs: string;
begin
  LCode := Integer(my_stmtErrno(AStmt));
  LMsg := AnsiPtrToStr(my_stmtError(AStmt));
  LSs := AnsiPtrToStr(my_stmtSqlstate(AStmt));
  my_stmtClose(AStmt);
  ClassifyMy(LCode, LSs, LCategory, LConstraint);
  raise EDbError.CreateFullMy(LCode, LSs, LMsg, LCategory, LConstraint);
end;

{ ---- DSN 解析 ---- }

procedure AssignDsnKey(var ADsn: TDbMysqlDsnParts; const AKey,
  AValue: string);
begin
  if AKey = 'host' then
    ADsn.Host := AValue
  else if AKey = 'port' then
    ADsn.Port := StrToIntDef(AValue, 0)
  else if AKey = 'user' then
    ADsn.User := AValue
  else if AKey = 'password' then
    ADsn.Password := AValue
  else if (AKey = 'db') or (AKey = 'database') then
    ADsn.Database := AValue
  else if AKey = 'socket' then
    ADsn.Socket := AValue
  else
    raise EDbError.CreateSimple(dbkMysql, 'unknown dsn key "' + AKey + '"');
end;

function ParseMySqlDsn(const ADsn: string): TDbMysqlDsnParts;
var
  I, LLen, LQuote, LStart: Integer;
  LKey, LVal: string;
begin
  Result.Host := '127.0.0.1';
  Result.Port := 3306;
  Result.User := '';
  Result.Password := '';
  Result.Database := '';
  Result.Socket := '';
  LLen := Length(ADsn);
  I := 1;
  while I <= LLen do
  begin
    while (I <= LLen) and (ADsn[I] = ' ') do
      Inc(I);
    if I > LLen then
      Break;
    LStart := I;
    while (I <= LLen) and (ADsn[I] <> '=') do
      Inc(I);
    if (I - LStart = 0) or (I > LLen) then
      raise EDbError.CreateSimple(dbkMysql,
        'malformed dsn near offset ' + IntToStr(I));
    LKey := LowerCase(Copy(ADsn, LStart, I - LStart));
    Inc(I);  { skip '=' }
    if (I <= LLen) and ((ADsn[I] = '''') or (ADsn[I] = '"')) then
    begin
      LQuote := Ord(ADsn[I]);
      Inc(I);
      LStart := I;
      while (I <= LLen) and (Ord(ADsn[I]) <> LQuote) do
        Inc(I);
      if I > LLen then
        raise EDbError.CreateSimple(dbkMysql,
          'unterminated quoted dsn value for "' + LKey + '"');
      LVal := Copy(ADsn, LStart, I - LStart);
      Inc(I);  { closing quote }
    end
    else
    begin
      LStart := I;
      while (I <= LLen) and (ADsn[I] <> ' ') do
        Inc(I);
      LVal := Copy(ADsn, LStart, I - LStart);
    end;
    AssignDsnKey(Result, LKey, LVal);
  end;
end;

{ ---- 占位符槽位计划 ---- }

function TranslatePlaceholdersMy(const ASql: string;
  out ARewritten: string; out ASlots: TIntArray): Integer;
var
  LSlots: TDbSqlSlotArray;
begin
  { V3-C6：词法扫描收敛至 db.sqlscan 共享引擎（行为逐字节兼容） }
  Result := SqlScanTranslateQuestion(ASql, DBSQLSCAN_MYSQL,
    ARewritten, LSlots);
  ASlots := LSlots;
end;

{ ---- MYSQL_BIND 双方言编组（唯一允许触碰原生布局的位置） ---- }

procedure WriteBindSlot(ABase: Pointer; const AIndex, ANativeSize: Integer;
  ABufferType: Cardinal; ABuffer: Pointer; ABufferLength: QWord;
  AIsNull: PBoolean; AError: Pointer; ALength: PQWord;
  const AIsUnsigned: Boolean); inline;
var
  P: PByte;
begin
  P := PByte(ABase) + PtrUInt(AIndex * ANativeSize);
  { 公共前四指针两家一致：length@0 / is_null@8 / buffer@16 / error@24 }
  PPointer(P)^ := ALength;
  PPointer(P + 8)^ := AIsNull;
  PPointer(P + 16)^ := ABuffer;
  PPointer(P + 24)^ := AError;
  case ANativeSize of
    SIZE_MYSQL_BIND_MYSQL:
      begin
        PQWord(P + 40)^ := ABufferLength;
        (P + 68)^ := Byte(ABufferType);      { 1 字节 enum }
        if AIsUnsigned then
          (P + 70)^ := 1;
      end;
    SIZE_MYSQL_BIND_MARIADB:
      begin
        PQWord(P + 64)^ := ABufferLength;
        PCardinal(P + 96)^ := ABufferType;   { 4 字节 enum，实测 96（非 100） }
        if AIsUnsigned then
          (P + 101)^ := 1;
      end;
  else
    raise EDbError.CreateSimple(dbkMysql,
      'unknown native bind size: ' + IntToStr(ANativeSize));
  end;
end;

{ ---- TDbMyQuery ---- }

type
  TDbMyQuery = class(TInterfacedObject, IDbQuery)
  private
    FConnH: TMysql;
    FStmt: TMysqlStmt;
    FFlavor: TMysqlFlavor;
    FNativeSize: Integer;
    FSlots: TIntArray;                { 物理槽 -> 逻辑号 }
    FParamCount: Integer;             { 服务端参数计数 }
    FLogical: array of TMyBindValue;  { 逻辑号 -> 值 }
    FExecuted: Boolean;
    FSetupDone: Boolean;              { 结果绑定已建 }
    FStored: Boolean;
    FHasRow: Boolean;
    FFieldCount: Integer;
    FColMeta: array of record
      Name: string;
      Typ: Cardinal;
      CharsetNr: Cardinal;
      BindType: Cardinal;
    end;
    { 执行期/结果期 C 侧内存（每次执行重建） }
    FParamNative: Pointer;
    FParamNulls: PBoolean;
    FParamLens: PQWord;
    FParamBufs: array of TBytes;      { int/double 定长镜像 }
    FResultNative: Pointer;
    FResBufs: array of Pointer;
    FResCap: array of Integer;
    FResNulls: PBoolean;
    FResLens: PQWord;
    FResErrs: PBoolean;
    { 观测钩子（V3-B3）：nil = 无枢纽；FEmitted = 本执行周期已发
      OnQuery（首 Step 计时，同周期后续 Step 不再发）}
    FTrace: TDbTraceHub;
    FSql: string;                     { 统一契约原文（? 原样进摘要）}
    FEmitted: Boolean;
    procedure CheckIndex(const AIndex: Integer);
    procedure RequireAllBound;
    procedure ExecuteIfNeeded;
    procedure SetupResultBinds;
    procedure FetchRowOrRaise;
    procedure RefetchTruncated;
    procedure FreeExecutionState;
    procedure RequireOpenRow(const AIndex: Integer);
    function ColAsString(const AIndex: Integer): string;
  public
    constructor Create(AConnH: TMysql; AStmt: TMysqlStmt;
      const AFlavor: TMysqlFlavor; const ASlots: TIntArray;
      AServerParamCount: Integer; const ASql: string;
      ATrace: TDbTraceHub);
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

  {** @desc MySQL 统一连接：Exec 走文本协议（多语句排空），Query 走
      prepared stmt；事务/保存点计数簿记对齐 pg 适配器。 *}
  TDbMyConnection = class(TInterfacedObject, IDbConnection, IDbTxControl,
    IDbSavepointControl, IDbBatchExecutor, IDbCapabilities, IDbTraceControl)
  private
    FConnH: TMysql;
    FFlavor: TMysqlFlavor;
    FLock: INativeMutex;
    FDepth: Integer;
    { INC-7 语句超时能力在建连期探测定格：仅 Oracle 库且服务端 ≥8.0 }
    FSupportsStmtTimeout: Boolean;
    { 观测钩子枢纽（V3-B3）：监听器存取/摘要/计时/分发统一委托 }
    FTrace: TDbTraceHub;
    procedure MyExecRaw(const ASql: string);
    { 读回 @@session.max_execution_time 当前值（B2 超时恢复基线）；
      MariaDB/旧版无此变量 → 返回 0（advisory 忽略路径） }
    function MySessionMaxExecMs: Int64;
  public
    constructor Create(AConnH: TMysql; const AFlavor: TMysqlFlavor);
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

    { IDbCapabilities（V3-B1）——Kind 由 IDbConnection.Kind 承担 }
    function ProductName: string;
    function ProductVersion: string;
    function SupportsSavepoints: Boolean;
    function SupportsBatchExecutor: Boolean;
    function SupportsStmtCacheControl: Boolean;
    function SupportsLargeObjects: Boolean;
    function SupportsArrayBinding: Boolean;
    function SupportsNativeBool: Boolean;
    function SupportsMultiStatementExec: Boolean;
    function SupportsStatementTimeout: Boolean;
    function CaseSensitiveIdentifiers: Boolean;
    function MaxPlaceholders: Integer;
  end;

constructor TDbMyQuery.Create(AConnH: TMysql; AStmt: TMysqlStmt;
  const AFlavor: TMysqlFlavor; const ASlots: TIntArray;
  AServerParamCount: Integer; const ASql: string; ATrace: TDbTraceHub);
var
  I: Integer;
begin
  inherited Create;
  FConnH := AConnH;
  FStmt := AStmt;
  FFlavor := AFlavor;
  if FFlavor = mfMariadb then
    FNativeSize := SIZE_MYSQL_BIND_MARIADB
  else
    FNativeSize := SIZE_MYSQL_BIND_MYSQL;
  FParamCount := AServerParamCount;
  SetLength(FSlots, Length(ASlots));
  for I := 0 to High(ASlots) do
    FSlots[I] := ASlots[I];
  { 槽位数必须与服务端参数计数一致：翻译器缺陷 fail-fast 在构造期 }
  if Length(FSlots) <> FParamCount then
  begin
    my_stmtClose(FStmt);
    FStmt := nil;
    raise EDbError.CreateSimple(dbkMysql,
      'placeholder plan produced ' + IntToStr(Length(FSlots)) +
      ' slots but server expects ' + IntToStr(FParamCount));
  end;
  SetLength(FLogical, FParamCount);
  for I := 0 to FParamCount - 1 do
    FLogical[I].Kind := mbkNone;
  FSql := ASql;
  FTrace := ATrace;
  FEmitted := False;
end;

destructor TDbMyQuery.Destroy;
begin
  FreeExecutionState;
  if FStmt <> nil then
  begin
    my_stmtClose(FStmt);
    FStmt := nil;
  end;
  inherited Destroy;
end;

procedure TDbMyQuery.FreeExecutionState;
var
  I: Integer;
begin
  if FStored then
  begin
    my_stmtFreeResult(FStmt);
    FStored := False;
  end;
  if FParamNative <> nil then
  begin
    FreeMem(FParamNative);
    FParamNative := nil;
  end;
  if FParamNulls <> nil then
  begin
    FreeMem(FParamNulls);
    FParamNulls := nil;
  end;
  if FParamLens <> nil then
  begin
    FreeMem(FParamLens);
    FParamLens := nil;
  end;
  SetLength(FParamBufs, 0);
  if FResultNative <> nil then
  begin
    FreeMem(FResultNative);
    FResultNative := nil;
  end;
  for I := 0 to High(FResBufs) do
    if FResBufs[I] <> nil then
    begin
      FreeMem(FResBufs[I]);
      FResBufs[I] := nil;
    end;
  SetLength(FResBufs, 0);
  SetLength(FResCap, 0);
  SetLength(FColMeta, 0);
  FFieldCount := 0;
  if FResNulls <> nil then
  begin
    FreeMem(FResNulls);
    FResNulls := nil;
  end;
  if FResLens <> nil then
  begin
    FreeMem(FResLens);
    FResLens := nil;
  end;
  if FResErrs <> nil then
  begin
    FreeMem(FResErrs);
    FResErrs := nil;
  end;
  FSetupDone := False;
  FExecuted := False;
  FHasRow := False;
end;

procedure TDbMyQuery.CheckIndex(const AIndex: Integer);
begin
  if (AIndex < 1) or (AIndex > FParamCount) then
    raise EDbError.CreateSimple(dbkMysql,
      'bind index ' + IntToStr(AIndex) + ' out of range 1..' +
      IntToStr(FParamCount));
end;

procedure TDbMyQuery.BindText(AIndex: Integer; const AValue: string);
begin
  CheckIndex(AIndex);
  FLogical[AIndex - 1].Kind := mbkText;
  FLogical[AIndex - 1].TextVal := AValue;
end;

procedure TDbMyQuery.BindInt64(AIndex: Integer; const AValue: Int64);
begin
  CheckIndex(AIndex);
  FLogical[AIndex - 1].Kind := mbkInt;
  FLogical[AIndex - 1].IntVal := AValue;
end;

procedure TDbMyQuery.BindDouble(AIndex: Integer; const AValue: Double);
begin
  CheckIndex(AIndex);
  FLogical[AIndex - 1].Kind := mbkDouble;
  FLogical[AIndex - 1].DblVal := AValue;
end;

procedure TDbMyQuery.BindBlob(AIndex: Integer; const AValue: TBytes);
begin
  CheckIndex(AIndex);
  FLogical[AIndex - 1].Kind := mbkBlob;
  FLogical[AIndex - 1].BlobVal := Copy(AValue, 0, Length(AValue));
end;

procedure TDbMyQuery.BindNull(AIndex: Integer);
begin
  CheckIndex(AIndex);
  FLogical[AIndex - 1].Kind := mbkNull;
end;

procedure TDbMyQuery.RequireAllBound;
var
  I: Integer;
begin
  { 未绑定参数 fail-fast：宁报错不传垃圾。绑定类编程错误在观测
    窗口外（§2.12：不发 OnError） }
  for I := 0 to FParamCount - 1 do
    if FLogical[I].Kind = mbkNone then
      raise EDbError.CreateSimple(dbkMysql,
        'parameter ' + IntToStr(I + 1) + ' not bound');
end;

procedure TDbMyQuery.ExecuteIfNeeded;
var
  I, LLogical, LLen: Integer;
begin
  if FExecuted then
    Exit;
  RequireAllBound;

  if FParamCount > 0 then
  begin
    GetMem(FParamNative, FParamCount * FNativeSize);
    FillChar(FParamNative^, SizeUInt(FParamCount * FNativeSize), 0);
    GetMem(FParamNulls, SizeUInt(FParamCount));
    FillChar(FParamNulls^, SizeUInt(FParamCount), 0);
    GetMem(FParamLens, SizeUInt(FParamCount) * SizeOf(QWord));
    FillChar(FParamLens^, SizeUInt(FParamCount) * SizeOf(QWord), 0);
    SetLength(FParamBufs, FParamCount);
    for I := 0 to FParamCount - 1 do
    begin
      LLogical := FSlots[I] - 1;
      case FLogical[LLogical].Kind of
        mbkInt:
          begin
            SetLength(FParamBufs[I], SizeOf(Int64));
            Move(FLogical[LLogical].IntVal, FParamBufs[I][0], SizeOf(Int64));
            WriteBindSlot(FParamNative, I, FNativeSize, MY_PT_LONGLONG,
              @FParamBufs[I][0], QWord(SizeOf(Int64)), nil, nil,
              @FParamLens[I], False);
          end;
        mbkDouble:
          begin
            SetLength(FParamBufs[I], SizeOf(Double));
            Move(FLogical[LLogical].DblVal, FParamBufs[I][0],
              SizeOf(Double));
            WriteBindSlot(FParamNative, I, FNativeSize, MY_PT_DOUBLE,
              @FParamBufs[I][0], QWord(SizeOf(Double)), nil, nil,
              @FParamLens[I], False);
          end;
        mbkText:
          begin
            LLen := Length(FLogical[LLogical].TextVal);
            { 至少 1 字节：空串参数也需合法缓冲地址 }
            if LLen = 0 then
              SetLength(FParamBufs[I], 1)
            else
              SetLength(FParamBufs[I], LLen);
            if LLen > 0 then
              Move(FLogical[LLogical].TextVal[1], FParamBufs[I][0],
                SizeUInt(LLen));
            FParamLens[I] := QWord(LLen);
            WriteBindSlot(FParamNative, I, FNativeSize, MY_PT_STRING,
              @FParamBufs[I][0], QWord(LLen), nil, nil,
              @FParamLens[I], False);
          end;
        mbkBlob:
          begin
            LLen := Length(FLogical[LLogical].BlobVal);
            if LLen = 0 then
              SetLength(FParamBufs[I], 1)
            else
              SetLength(FParamBufs[I], LLen);
            if LLen > 0 then
              Move(FLogical[LLogical].BlobVal[0], FParamBufs[I][0],
                SizeUInt(LLen));
            FParamLens[I] := QWord(LLen);
            WriteBindSlot(FParamNative, I, FNativeSize, MY_PT_STRING,
              @FParamBufs[I][0], QWord(LLen), nil, nil,
              @FParamLens[I], False);
          end;
        mbkNull:
          begin
            FParamNulls[I] := True;
            WriteBindSlot(FParamNative, I, FNativeSize, MY_PT_NULL,
              nil, 0, @FParamNulls[I], nil, @FParamLens[I], False);
          end;
      end;
    end;
    if my_stmtBindParam(FStmt, FParamNative) then
      RaiseMyStmt(FStmt);
  end;
  if my_stmtExecute(FStmt) <> 0 then
    RaiseMyStmt(FStmt);
  FExecuted := True;
end;

procedure TDbMyQuery.SetupResultBinds;
var
  LMetaRes: TMysqlRes;
  I: Integer;
  LF: PMysqlFieldRec;
begin
  if FSetupDone then
    Exit;
  LMetaRes := my_stmtResultMetadata(FStmt);
  if LMetaRes = nil then
    raise EDbError.CreateSimple(dbkMysql,
      'stmt reports a resultset but metadata is unavailable');
  try
    FFieldCount := Integer(my_numFields(LMetaRes));
    SetLength(FColMeta, FFieldCount);
    GetMem(FResultNative, FFieldCount * FNativeSize);
    FillChar(FResultNative^, SizeUInt(FFieldCount * FNativeSize), 0);
    GetMem(FResNulls, SizeUInt(FFieldCount));
    FillChar(FResNulls^, SizeUInt(FFieldCount), 0);
    GetMem(FResLens, SizeUInt(FFieldCount) * SizeOf(QWord));
    FillChar(FResLens^, SizeUInt(FFieldCount) * SizeOf(QWord), 0);
    GetMem(FResErrs, SizeUInt(FFieldCount));
    FillChar(FResErrs^, SizeUInt(FFieldCount), 0);
    SetLength(FResBufs, FFieldCount);
    SetLength(FResCap, FFieldCount);
    for I := 0 to FFieldCount - 1 do
    begin
      FResBufs[I] := nil;
      LF := my_fetchFieldDirect(LMetaRes, Cardinal(I));
      FColMeta[I].Name := AnsiPtrToStr(LF^.Name);
      FColMeta[I].Typ := LF^.Typ;
      FColMeta[I].CharsetNr := LF^.CharsetNr;
      case LF^.Typ of
        MYSQL_TYPE_TINY:
          begin FColMeta[I].BindType := MYSQL_TYPE_TINY; FResCap[I] := 1; end;
        MYSQL_TYPE_SHORT, MYSQL_TYPE_YEAR:
          begin FColMeta[I].BindType := MYSQL_TYPE_SHORT; FResCap[I] := 2; end;
        MYSQL_TYPE_LONG, MYSQL_TYPE_INT24:
          begin FColMeta[I].BindType := MYSQL_TYPE_LONG; FResCap[I] := 4; end;
        MYSQL_TYPE_LONGLONG:
          begin FColMeta[I].BindType := MY_PT_LONGLONG; FResCap[I] := 8; end;
        MYSQL_TYPE_FLOAT:
          begin FColMeta[I].BindType := MYSQL_TYPE_FLOAT; FResCap[I] := 4; end;
        MYSQL_TYPE_DOUBLE:
          begin FColMeta[I].BindType := MY_PT_DOUBLE; FResCap[I] := 8; end;
        MYSQL_TYPE_DECIMAL, MYSQL_TYPE_NEWDECIMAL:
          begin FColMeta[I].BindType := MY_PT_STRING; FResCap[I] := MY_BUF_INITIAL; end;
      else
        begin FColMeta[I].BindType := MY_PT_STRING; FResCap[I] := MY_BUF_INITIAL; end;
      end;
      GetMem(FResBufs[I], SizeUInt(FResCap[I]));
      WriteBindSlot(FResultNative, I, FNativeSize, FColMeta[I].BindType,
        FResBufs[I], QWord(FResCap[I]), @FResNulls[I], @FResErrs[I],
        @FResLens[I], False);
    end;
  finally
    my_freeResult(LMetaRes);   { 元数据复制完即释放 }
  end;
  if my_stmtBindResult(FStmt, FResultNative) then
    RaiseMyStmt(FStmt);
  if my_stmtStoreResult(FStmt) <> 0 then
    RaiseMyStmt(FStmt);
  FStored := True;
  FSetupDone := True;
end;

procedure TDbMyQuery.RefetchTruncated;
var
  I, LNewCap: Integer;
begin
  for I := 0 to FFieldCount - 1 do
  begin
    if not FResErrs[I] then
      Continue;
    LNewCap := Integer(FResLens[I]) + 1;
    if LNewCap <= FResCap[I] * 2 then
      LNewCap := FResCap[I] * 2;   { 至少翻倍，防反复截断抖动 }
    ReallocMem(FResBufs[I], SizeUInt(LNewCap));
    FResCap[I] := LNewCap;
    { 缓冲可能已移动：重写槽位后再单列重取 }
    WriteBindSlot(FResultNative, I, FNativeSize, FColMeta[I].BindType,
      FResBufs[I], QWord(FResCap[I]), @FResNulls[I], @FResErrs[I],
      @FResLens[I], False);
    if my_stmtFetchColumn(FStmt,
      Pointer(PByte(FResultNative) + PtrUInt(I * FNativeSize)),
      Cardinal(I), 0) then
      RaiseMyStmt(FStmt);
  end;
end;

procedure TDbMyQuery.FetchRowOrRaise;
var
  LRC: Integer;
begin
  LRC := my_stmtFetch(FStmt);
  if LRC = MYSQL_NO_DATA then
  begin
    FHasRow := False;
    Exit;
  end;
  if LRC = MYSQL_DATA_TRUNCATED then
    RefetchTruncated
  else if LRC <> 0 then
    RaiseMyStmt(FStmt);
  FHasRow := True;
end;

procedure TDbMyQuery.RequireOpenRow(const AIndex: Integer);
begin
  if (AIndex < 0) or (AIndex >= FFieldCount) then
    raise EDbError.CreateSimple(dbkMysql,
      'column index ' + IntToStr(AIndex) + ' out of range 0..' +
      IntToStr(FFieldCount - 1));
  if not FHasRow then
    raise EDbError.CreateSimple(dbkMysql,
      'no current row (Step returned False)');
end;

function TDbMyQuery.Step: Boolean;
var
  LT0: QWord;
  LTimed: Boolean;
begin
  { 编程错误先行 fail-fast：不进观测窗口（§2.12）}
  if not FExecuted then
    RequireAllBound;
  LT0 := 0;
  LTimed := (FTrace <> nil) and (not FEmitted) and FTrace.BeginOp(LT0);
  try
    ExecuteIfNeeded;
    if not FSetupDone then
    begin
      if my_stmtFieldCount(FStmt) = 0 then
      begin
        FHasRow := False;   { 无结果集语句：永久无行 }
        Result := False;
      end
      else
      begin
        SetupResultBinds;
        FetchRowOrRaise;
        Result := FHasRow;
      end;
    end
    else
    begin
      FetchRowOrRaise;
      Result := FHasRow;
    end;
    if LTimed then
    begin
      FEmitted := True;   { 无结果集执行也是成功执行：先记再发 }
      FTrace.NotifyQuery(LT0, FSql);
    end;
  except
    on E: EDbError do
    begin
      if LTimed then
        FTrace.NotifyError(E.Category, FSql);
      raise;
    end;
  end;
end;

procedure TDbMyQuery.Reset;
begin
  FEmitted := False;   { 重执行周期重新计时 }
  { 回卷执行态：结果与缓冲释放，stmt 保持 prepared 可复用 }
  FreeExecutionState;
end;

function TDbMyQuery.ColumnCount: Integer;
begin
  Result := FFieldCount;
end;

function TDbMyQuery.ColumnName(AIndex: Integer): string;
begin
  RequireOpenRow(AIndex);
  Result := FColMeta[AIndex].Name;
end;

function TDbMyQuery.ColumnType(AIndex: Integer): TDbColumnType;
begin
  RequireOpenRow(AIndex);
  if FResNulls[AIndex] then
    Exit(dbcNull);
  case FColMeta[AIndex].BindType of
    MYSQL_TYPE_TINY, MYSQL_TYPE_SHORT, MYSQL_TYPE_LONG,
    MY_PT_LONGLONG, MYSQL_TYPE_INT24, MYSQL_TYPE_YEAR:
      Result := dbcInteger;
    MYSQL_TYPE_FLOAT, MY_PT_DOUBLE:
      Result := dbcFloat;
  else
    if FColMeta[AIndex].CharsetNr = MY_BINARY_CHARSET then
      Result := dbcBlob
    else
      Result := dbcText;
  end;
end;

function TDbMyQuery.IsNull(AIndex: Integer): Boolean;
begin
  RequireOpenRow(AIndex);
  Result := FResNulls[AIndex];
end;

function TDbMyQuery.ColAsString(const AIndex: Integer): string;
var
  LLen: Integer;
begin
  RequireOpenRow(AIndex);
  if FResNulls[AIndex] then
    Exit('');
  LLen := Integer(FResLens[AIndex]);
  if LLen <= 0 then
    Exit('');
  SetLength(Result, LLen);
  Move(FResBufs[AIndex]^, Result[1], SizeUInt(LLen));
end;

function TDbMyQuery.GetInt64(AIndex: Integer): Int64;
var
  LS: string;
  LCode: Integer;
  LD: Double;
  LSg: Single;
begin
  RequireOpenRow(AIndex);
  if FResNulls[AIndex] then
    Exit(0);
  case FColMeta[AIndex].BindType of
    MYSQL_TYPE_TINY:
      Result := ShortInt(PByte(FResBufs[AIndex])^);
    MYSQL_TYPE_SHORT, MYSQL_TYPE_YEAR:
      Result := PSmallInt(FResBufs[AIndex])^;
    MYSQL_TYPE_LONG, MYSQL_TYPE_INT24:
      Result := PInteger(FResBufs[AIndex])^;
    MY_PT_LONGLONG:
      Result := PInt64(FResBufs[AIndex])^;
    MYSQL_TYPE_FLOAT:
      begin
        LSg := PSingle(FResBufs[AIndex])^;
        if (LSg >= 9.3e18) or (LSg <= -9.3e18) then
          raise EDbError.CreateSimple(dbkMysql,
            'float value out of int64 range');
        Result := Trunc(LSg);
      end;
    MY_PT_DOUBLE:
      begin
        LD := PDouble(FResBufs[AIndex])^;
        if (LD >= 9.3e18) or (LD <= -9.3e18) then
          raise EDbError.CreateSimple(dbkMysql,
            'float value out of int64 range');
        Result := Trunc(LD);
      end;
  else
    LS := ColAsString(AIndex);
    Val(LS, Result, LCode);
    if LCode <> 0 then
      raise EDbError.CreateSimple(dbkMysql,
        'not an integer value: "' + LS + '"');
  end;
end;

function TDbMyQuery.GetDouble(AIndex: Integer): Double;
var
  LS: string;
  LCode: Integer;
begin
  RequireOpenRow(AIndex);
  if FResNulls[AIndex] then
    Exit(0.0);
  case FColMeta[AIndex].BindType of
    MYSQL_TYPE_TINY:
      Result := ShortInt(PByte(FResBufs[AIndex])^);
    MYSQL_TYPE_SHORT, MYSQL_TYPE_YEAR:
      Result := PSmallInt(FResBufs[AIndex])^;
    MYSQL_TYPE_LONG, MYSQL_TYPE_INT24:
      Result := PInteger(FResBufs[AIndex])^;
    MY_PT_LONGLONG:
      Result := PInt64(FResBufs[AIndex])^;
    MYSQL_TYPE_FLOAT:
      Result := PSingle(FResBufs[AIndex])^;
    MY_PT_DOUBLE:
      Result := PDouble(FResBufs[AIndex])^;
  else
    begin
      LS := ColAsString(AIndex);
      Val(LS, Result, LCode);
      if LCode <> 0 then
        raise EDbError.CreateSimple(dbkMysql,
          'not a numeric value: "' + LS + '"');
    end;
  end;
end;

function TDbMyQuery.GetText(AIndex: Integer): string;
begin
  Result := ColAsString(AIndex);   { NULL 读作空串（统一契约） }
end;

function TDbMyQuery.GetBlob(AIndex: Integer): TBytes;
var
  LLen: Integer;
begin
  RequireOpenRow(AIndex);
  if FResNulls[AIndex] then
    Exit(nil);
  LLen := Integer(FResLens[AIndex]);
  SetLength(Result, LLen);
  if LLen > 0 then
    Move(FResBufs[AIndex]^, Result[0], SizeUInt(LLen));
end;

{ ---- TDbMyConnection ---- }

constructor TDbMyConnection.Create(AConnH: TMysql;
  const AFlavor: TMysqlFlavor);
begin
  inherited Create;
  FConnH := AConnH;
  FFlavor := AFlavor;
  FLock := nextpas.core.sync.Mutex;
  FDepth := 0;
  { 能力自述在建连期定格：语句超时仅 Oracle 库且服务端 ≥8.0
    （max_execution_time）；MariaDB 的 max_statement_time 语法不同，
    未接入（路线图缺口账本）。 }
  FSupportsStmtTimeout :=
    (AFlavor = mfMysql) and (my_getServerVersion(AConnH) >= 80000);
  FTrace := TDbTraceHub.Create;
  { OnAcquire 由 SetListener 挂载时补发（§2.12），ctor 不预发 }
end;

{ ---- IDbTraceControl（V3-B3）---- }

procedure TDbMyConnection.SetListener(
  const AListener: IDbTraceListener);
begin
  FTrace.SetListener(AListener);
end;

function TDbMyConnection.HasListener: Boolean;
begin
  Result := FTrace.Active;
end;

destructor TDbMyConnection.Destroy;
begin
  FTrace.NotifyRelease;   { OnRelease = 连接关闭 }
  FreeAndNil(FTrace);
  if FConnH <> nil then
  begin
    my_close(FConnH);
    FConnH := nil;
  end;
  inherited Destroy;
end;

procedure TDbMyConnection.MyExecRaw(const ASql: string);
var
  LRes: TMysqlRes;
begin
  if my_realQuery(FConnH, PAnsiChar(AnsiString(ASql)),
    QWord(Length(ASql))) <> 0 then
    RaiseMyConn(FConnH);
  { CLIENT_MULTI_STATEMENTS 下多结果集必须逐个排空，否则协议失步 }
  if my_fieldCount(FConnH) > 0 then
  begin
    LRes := my_storeResult(FConnH);
    if LRes <> nil then
      my_freeResult(LRes);
  end;
  while my_moreResults(FConnH) do
  begin
    if my_nextResult(FConnH) > 0 then
      RaiseMyConn(FConnH);
    if my_fieldCount(FConnH) > 0 then
    begin
      LRes := my_storeResult(FConnH);
      if LRes <> nil then
        my_freeResult(LRes);
    end;
  end;
end;

function TDbMyConnection.Kind: TDbKind;
begin
  Result := dbkMysql;
end;

procedure TDbMyConnection.Exec(const ASql: string);
var
  LT0: QWord;
  LTimed: Boolean;
begin
  LT0 := 0;
  LTimed := FTrace.BeginOp(LT0);
  try
    MyExecRaw(ASql);
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

function TDbMyConnection.MySessionMaxExecMs: Int64;
var
  LRes: TMysqlRes;
  LRow: TMysqlRow;
const
  CProbe = 'SELECT @@session.max_execution_time';
begin
  Result := 0;
  if my_realQuery(FConnH, PAnsiChar(AnsiString(CProbe)),
    QWord(Length(CProbe))) <> 0 then
    Exit;   { 变量不存在（MariaDB/旧服务端）→ 视为 0 }
  if my_fieldCount(FConnH) = 0 then
    Exit;
  LRes := my_storeResult(FConnH);
  if LRes = nil then
    Exit;
  try
    if (my_numRows(LRes) > 0) and (my_numFields(LRes) > 0) then
    begin
      LRow := my_fetchRow(LRes);
      if (LRow <> nil) and ((LRow + 0)^ <> nil) then
        Result := StrToInt64Def(AnsiPtrToStr((LRow + 0)^), 0);
    end;
  finally
    my_freeResult(LRes);
  end;
end;

procedure TDbMyConnection.Exec(const ASql: string;
  const AOptions: TDbExecOptions);
var
  LPrev: Int64;
  LT0: QWord;
  LTimed: Boolean;
begin
  { advisory：能力缺失（MariaDB 方言 / 旧服务端）静默忽略不冒充。
    <=0 / 无能力分支委托已插桩 Exec（无双发）；观测窗口只包用户
    语句（SET SESSION 机制开销不计），见 §2.12 }
  if (AOptions.TimeoutMs <= 0) or (not FSupportsStmtTimeout) then
  begin
    Exec(ASql);
    Exit;
  end;
  LPrev := MySessionMaxExecMs;
  try
    MyExecRaw('SET SESSION max_execution_time=' +
      IntToStr(AOptions.TimeoutMs));
    LT0 := 0;
    LTimed := FTrace.BeginOp(LT0);
    try
      MyExecRaw(ASql);
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
      MyExecRaw('SET SESSION max_execution_time=' + IntToStr(LPrev));
    except
    end;
  end;
end;

function TDbMyConnection.Query(const ASql: string): IDbQuery;
var
  LRewritten: string;
  LSlots: TIntArray;
  S: TMysqlStmt;
  LServerParams: QWord;
begin
  TranslatePlaceholdersMy(ASql, LRewritten, LSlots);
  S := my_stmtInit(FConnH);
  if S = nil then
    raise EDbError.CreateSimple(dbkMysql, 'mysql_stmt_init failed');
  if my_stmtPrepare(S, PAnsiChar(AnsiString(LRewritten)),
    QWord(Length(LRewritten))) <> 0 then
    RaiseMyStmtClose(S);   { 读错误 + 关句柄 + 抛 }
  LServerParams := my_stmtParamCount(S);
  Result := TDbMyQuery.Create(FConnH, S, FFlavor, LSlots,
    Integer(LServerParams), ASql, FTrace);
end;

function TDbMyConnection.Query(const ASql: string;
  const AOptions: TDbExecOptions): IDbQuery;
begin
  { TimeoutMs v1 忽略：执行惰性（首个 Step）且 mysql 无语句级属性，
    会话级变量无法安全限定到查询对象存活期——升级路径登记路线图
    （MariaDB SET STATEMENT .. FOR 前缀 / 客户端 cancel watchdog）。}
  Result := Query(ASql);
end;

function TDbMyConnection.Changes: Int64;
var
  U: TMysqlUll;
begin
  U := my_affectedRows(FConnH);
  { 出错/无上下文时 C API 返回 (my_ulonglong)-1 }
  if U = QWord(Int64(-1)) then
    Result := 0
  else
    Result := Int64(U);
end;

function TDbMyConnection.Raw: Pointer;
begin
  { 与 pg 侧同契约：逃生舱返回 nil；需原生句柄走 mysql 门面直用 }
  Result := nil;
end;

procedure TDbMyConnection.BeginTxn(const AImmediate: Boolean);
begin
  FLock.Acquire;
  try
    if FDepth = 0 then
    begin
      { AImmediate 无对应语义（InnoDB 无 IMMEDIATE 变体），接受为
        no-op——契约差异登记 CONTRACT §2.3 }
      MyExecRaw('START TRANSACTION');
      FDepth := 1;
    end
    else
      Inc(FDepth);
  finally
    FLock.Release;
  end;
end;

procedure TDbMyConnection.CommitTxn;
begin
  FLock.Acquire;
  try
    if FDepth = 0 then
      raise EDbError.CreateSimple(dbkMysql,
        'CommitTxn without a matching BeginTxn on this connection');
    if FDepth > 1 then
      Dec(FDepth)
    else
    begin
      MyExecRaw('COMMIT');
      FDepth := 0;
    end;
  finally
    FLock.Release;
  end;
end;

procedure TDbMyConnection.RollbackTxn;
begin
  FLock.Acquire;
  try
    if FDepth = 0 then
      raise EDbError.CreateSimple(dbkMysql,
        'RollbackTxn without a matching BeginTxn on this connection');
    { 任意深度 = 回滚整个事务（对齐 sqlite/pg）；回滚失败吞掉
      （服务端可能已自行中止事务），原异常由调用方重抛 }
    try
      MyExecRaw('ROLLBACK');
    except
    end;
    FDepth := 0;
  finally
    FLock.Release;
  end;
end;

function TDbMyConnection.InTransaction: Boolean;
begin
  Result := TxDepth > 0;
end;

function TDbMyConnection.TxDepth: Integer;
begin
  FLock.Acquire;
  try
    Result := FDepth;
  finally
    FLock.Release;
  end;
end;

procedure TDbMyConnection.Savepoint(const AName: string);
begin
  ValidateDbSavepointName(dbkMysql, AName);
  MyExecRaw('SAVEPOINT ' + AName);
end;

procedure TDbMyConnection.RollbackTo(const AName: string);
begin
  ValidateDbSavepointName(dbkMysql, AName);
  MyExecRaw('ROLLBACK TO ' + AName);
end;

procedure TDbMyConnection.ReleaseTo(const AName: string);
begin
  ValidateDbSavepointName(dbkMysql, AName);
  { MySQL 方言：RELEASE 必须带 SAVEPOINT 关键字（与 pg 差异） }
  MyExecRaw('RELEASE SAVEPOINT ' + AName);
end;

procedure TDbMyConnection.ExecuteBatch(const ASteps: TDbSqlSteps);
var
  K: Integer;
  LJoined: IStringBuilder;
begin
  if Length(ASteps) = 0 then
    Exit;
  { 连接已请求 CLIENT_MULTI_STATEMENTS：合并单次往返，N 步 = 1 往返；
    Exec 内部负责逐结果排空 }
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

{ ---- IDbCapabilities（V3-B1）---- }

function TDbMyConnection.ProductName: string;
begin
  if FFlavor = mfMariadb then
    Result := 'MariaDB'
  else
    Result := 'MySQL';
end;

function TDbMyConnection.ProductVersion: string;
begin
  Result := IntToStr(my_getServerVersion(FConnH));
end;

function TDbMyConnection.SupportsSavepoints: Boolean;
begin
  Result := True;   { InnoDB 原生 SAVEPOINT/ROLLBACK TO/RELEASE }
end;

function TDbMyConnection.SupportsBatchExecutor: Boolean;
begin
  Result := True;   { CLIENT_MULTI_STATEMENTS 已请求 }
end;

function TDbMyConnection.SupportsStmtCacheControl: Boolean;
begin
  Result := False;  { A2 未接服务端 prepared 缓存（C 线排期） }
end;

function TDbMyConnection.SupportsLargeObjects: Boolean;
begin
  Result := False;  { 统一层无 LO 面（协议无 lo_* 对应物） }
end;

function TDbMyConnection.SupportsArrayBinding: Boolean;
begin
  Result := False;   { v1 未实现参数级批量绑定（诚实契约） }
end;

function TDbMyConnection.SupportsNativeBool: Boolean;
begin
  Result := False;  { TINYINT(1) 约定，非原生类型（§2.6） }
end;

function TDbMyConnection.SupportsMultiStatementExec: Boolean;
begin
  Result := True;   { 连接期已请求 CLIENT_MULTI_STATEMENTS|MULTI_RESULTS }
end;

function TDbMyConnection.SupportsStatementTimeout: Boolean;
begin
  Result := FSupportsStmtTimeout;
end;

function TDbMyConnection.CaseSensitiveIdentifiers: Boolean;
begin
  Result := False;  { 列名不敏感；表名敏感性依平台设置不入契约 }
end;

function TDbMyConnection.MaxPlaceholders: Integer;
begin
  Result := 65535;  { COM_STMT_PREPARE 参数计数为 uint16 }
end;

{ ---- 工厂 ---- }

function ConnectMysql(const ADsn: string): IDbConnection;
begin
  Result := ConnectMysql(ADsn, TDbConnectOptions.Default);
end;

function ConnectMysql(const ADsn: string;
  const AOptions: TDbConnectOptions): IDbConnection;
var
  D: TDbMysqlDsnParts;
  H: TMysql;
  R: TMysql;
  Conn: TDbMyConnection;
  LSec: Cardinal;
  LFlags: QWord;
begin
  MySqlEnsureLoaded;
  D := ParseMySqlDsn(ADsn);
  H := my_init(nil);
  if H = nil then
    raise EDbError.CreateFullMy(CR_OUT_OF_MEMORY, 'HY001',
      'mysql_init failed', decCapacity, dckNone);
  Conn := nil;
  try
    if my_options(H, MYSQL_SET_CHARSET_NAME, PAnsiChar('utf8mb4')) <> 0 then
      raise EDbError.CreateSimple(dbkMysql,
        'mysql_options(SET_CHARSET_NAME utf8mb4) failed');
    if AOptions.BusyTimeoutMs > 0 then
    begin
      LSec := Cardinal((AOptions.BusyTimeoutMs + 999) div 1000);
      my_options(H, MYSQL_OPT_CONNECT_TIMEOUT, @LSec);
    end;
    LFlags := QWord(CLIENT_MULTI_STATEMENTS) or QWord(CLIENT_MULTI_RESULTS);
    if D.Socket <> '' then
      R := my_realConnect(H, nil, PAnsiChar(AnsiString(D.User)),
        PAnsiChar(AnsiString(D.Password)),
        PAnsiChar(AnsiString(D.Database)), 0,
        PAnsiChar(AnsiString(D.Socket)), LFlags)
    else
      R := my_realConnect(H, PAnsiChar(AnsiString(D.Host)),
        PAnsiChar(AnsiString(D.User)),
        PAnsiChar(AnsiString(D.Password)),
        PAnsiChar(AnsiString(D.Database)), Cardinal(D.Port), nil, LFlags);
    if R = nil then
      RaiseMyConn(H);
    Conn := TDbMyConnection.Create(H, MySqlFlavor);
  except
    my_close(H);   { 仅覆盖建连窗口；Conn 成立后句柄归其所有 }
    raise;
  end;
  { INC-7 会话级 SELECT 超时：能力在建连期已定格（Oracle 库且
    服务端 ≥8.0）；不满足则静默跳过。若此处失败，Conn 引用计数为
    0 自动析构关句柄。 }
  if (AOptions.StatementTimeoutMs > 0) and Conn.FSupportsStmtTimeout then
    Conn.MyExecRaw('SET SESSION max_execution_time=' +
      IntToStr(AOptions.StatementTimeoutMs));
  Result := Conn;
end;

end.
