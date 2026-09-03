unit nextpas.core.db.odbc.adapter;

{** @desc IDbConnection/IDbQuery 的 ODBC 网关适配器（V3-A4）。

       定位：ISO CLI 之上的第四统一后端。任何提供 ODBC 驱动的数据库
       （含达梦/openGauss/KingbaseES 等国产库——路线图 D4 备选路径）
       经本适配器接入统一面；驱动专属特性不冒充，能力缺口诚实登记。

       执行模型：IDbQuery 走 SQLPrepare/SQLBindParameter/SQLExecute
       （服务端 prepared，参数化即注入安全）；结果经 SQLFetch +
       SQLGetData 惰性物化（每行每列首次访问取一次，行内缓存）。
       整数族/BIT 列以 SQL_C_SBIGINT 直取；浮点/DECIMAL/日期族以
       SQL_C_CHAR 文本形态取（精度无损，消费侧解析，对齐 mysql 侧
       DECIMAL 文本策略）；二进制族 SQL_C_BINARY。截断（01004）按
       指示符扩缓冲对同列整值重取——主流管理器/驱动（unixODBC、
       PostgreSQL、MySQL、SQLite3、MSSQL）均按整值替换语义实现；
       该假设由 live 门禁段长文本往返用例钉死，指示符不自洽时
       fail-fast 报错而非静默产错。

       参数缓冲所有权：ODBC 绑定是延迟求值（SQLExecute 时才读缓冲），
       故所有参数值先编组进对象字段托管的稳定缓冲（FParamBufs/
       FParamInds），禁止把表达式临时地址交给驱动。

       占位符：ODBC 原生 ?，与统一契约同形直通；?N 显式编号经槽位
       计划改写为顺序 ? 并携带物理槽→逻辑号映射。扫描跳过 ' 字符串、
       " 与 [ 方括号标识符、-- 行注释与块注释。

       事务控制面：SQL_ATTR_AUTOCOMMIT 切换 + SQLEndTran，连接内
       计数式簿记对齐 pg/mysql/sqlite 适配器；TXN_CAPABLE=
       SQL_TC_NONE 的驱动 BeginTxn fail-fast（decNotSupported）。

       能力降级矩阵（诚实契约，CONTRACT §2.11 同文）：
         - Savepoints：ISO CLI 无保存点发现机制，不实现
           IDbSavepointControl，SupportsSavepoints=False（互证契约）。
         - BatchExecutor：支持——逐条 Exec 包 WithTransaction，
           sqlite 式精确到步的错误定位（不做多语句合并假设）。
         - MultiStatementExec：False（分号批行为因驱动而异，不假装；
           批量走 IDbBatchExecutor）。
         - NativeBool：False（异构网关无法静态断言后端布尔类型）。
         - StatementTimeout：True——逐语句设 SQL_ATTR_QUERY_TIMEOUT
           （秒粒度向上取整）；个别驱动拒绝属环境降级，best effort。
         - LargeObjects / StmtCacheControl：False（无对应面）。
         - CaseSensitiveIdentifiers：SQL_IDENTIFIER_CASE 探测
           （=SQL_IC_SENSITIVE 为 True；探测失败保守 False）。
         - MaxPlaceholders：999 保守下界（ISO CLI 无上限 InfoType）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.db.odbc.base;

type
  TIntArray = array of Integer;

{ 创建 ODBC 连接并返回统一接口。
  ADsn 是 ODBC connstr，原文透传 SQLDriverConnect：
    "DSN=name;UID=user;PWD=pwd"   或 DSN-less 形态
    "Driver=PostgreSQL Unicode;Server=...;Database=..."
    （驱动名可按各家文档加花括号包裹）。
  失败抛 EDbError（Backend=dbkOdbc，SqlState=5 字符状态码，
  BackendCode=诊断 NativeError）。空 DSN fail-fast。 }
function ConnectOdbc(const ADsn: string): IDbConnection;
function ConnectOdbc(const ADsn: string;
  const AOptions: TDbConnectOptions): IDbConnection;
function ConnectOdbc(const ADsn: string; const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection; inline;

{ ---- 纯函数导出供门禁离线验证 ---- }

{ 占位符槽位计划：? 保持顺序编号；?N 重写为 ? 并把逻辑号 N 记入该
  物理槽。ARewritten = 重写后 SQL；ASlots[物理] = 逻辑号（1 起）；
  Result = 物理槽总数。 }
function TranslatePlaceholdersOdbc(const ASql: string;
  out ARewritten: string; out ASlots: TIntArray): Integer;

implementation

uses
  nextpas.core.exception,
  nextpas.core.base.utils,
  nextpas.core.bytes.ops,
  nextpas.core.text.conv,
  nextpas.core.text.format,
  nextpas.core.text.kv,
  nextpas.core.db.err,
  nextpas.core.db.capprobe,
  nextpas.core.db.trace,
  nextpas.core.text.sqlscan,
  nextpas.core.db.tx,
  nextpas.core.sync,
  nextpas.core.text.builder,
  nextpas.core.db.odbc.ffi,
  nextpas.core.db.odbc.loader;


const
  { DriverConnect 回读缓冲（完整 connstr 写回处，仅丢弃）}
  C_OUT_CONN_STR = 1024;
  { DescribeCol 列名缓冲（>511 字符列名属病态，接受截断）}
  C_NAME_BUF = 512;
  { GetData 起始容量（截断后按指示符扩取）}
  C_GETDATA_INITIAL = 256;
  { 参数类型选择阈值：超过则用 LONG* 形态 }
  C_LONG_TYPE_THRESHOLD = 4000;

type
  { 绑定值逻辑形态 }
  TOdbcBindKind = (obkNone, obkInt, obkDouble, obkText, obkBlob, obkNull);
  TOdbcBindValue = record
    Kind: TOdbcBindKind;
    IntVal: Int64;
    DblVal: Double;
    TextVal: string;        { 字符串按框架约定即 utf8 字节，直存 }
    BlobVal: TBytes;
  end;

  { 行内列值缓存形态 }
  TOdbcCellKind = (ockInt, ockText, ockBlob);
  TOdbcCell = record
    Done: Boolean;
    NullFlag: Boolean;
    CellKind: TOdbcCellKind;
    IntVal: Int64;
    Data: TBytes;
  end;

{ ---- 错误桥接 ---- }
{ 惯例：异常对象非引用计数——单次直接构造最终 EDbError 并 raise，
  不经中间异常对象（防孤儿）。Message 恒为后端原始消息（首条诊断
  原文），上下文只进无诊断时的兜底文案。AMyFlavor 由连接建连期
  驱动名探测给出，仅 MySQL 系驱动允许 NativeError 码位提精
  （db.err ClassifyOdbcEx；非 MySQL 驱动 NativeError 无可移植
  语义，保持欠归一）。 }

{ MySQL 系驱动名判定：DRIVER_NAME / DBMS_NAME 命中 mysql/mariadb
  词元（大小写不敏感，ASCII）。命中才允许 NativeError 按 MySQL
  服务端码位提精；其余驱动（达梦/GBase 等码位自成体系）保持
  SQLSTATE 欠归一。 }
function IsMyFlavorName(const AName: string): Boolean;
var
  LUp: string;
  I: Integer;
begin
  LUp := AName;
  for I := 1 to Length(LUp) do
    LUp[I] := UpCase(LUp[I]);
  Result := (Pos('MYSQL', LUp) > 0) or (Pos('MARIADB', LUp) > 0);
end;

procedure RaiseOdbcH(AHandleType: SmallInt; AHandle: Pointer;
  ARetCode: SmallInt; AMyFlavor: Boolean; const AContext: string);
var
  LDiag: TOdbcDiagRecs;
  LMsg, LSs: string;
  LNative: Integer;
  LCategory: TDbErrorCategory;
  LConstraint: TDbConstraintKind;
begin
  LDiag := OdbcDiag(AHandleType, AHandle);
  if Length(LDiag) > 0 then
  begin
    LSs := LDiag[0].SqlState;
    LNative := LDiag[0].NativeError;
    LMsg := LDiag[0].Message;
    if LMsg = '' then
      LMsg := TextFormat('odbc: %s failed [%s/%d]',
        [AContext, LSs, LNative]);
  end
  else
  begin
    LSs := '';
    LNative := 0;
    LMsg := TextFormat('odbc: %s failed [retcode %d, no diagnostics]',
      [AContext, ARetCode]);
  end;
  ClassifyOdbcEx(LSs, LNative, AMyFlavor, LCategory, LConstraint);
  raise NewDbErrorOdbc(LNative, LSs, LMsg, LCategory, LConstraint);
end;

{ 读走 stmt 错误后关闭句柄再抛（防句柄泄漏） }
procedure RaiseOdbcStmtClose(AStmt: Pointer; ARetCode: SmallInt;
  AMyFlavor: Boolean; const AContext: string);
var
  LDiag: TOdbcDiagRecs;
  LMsg, LSs: string;
  LNative: Integer;
  LCategory: TDbErrorCategory;
  LConstraint: TDbConstraintKind;
begin
  LDiag := OdbcDiag(SQL_HANDLE_STMT, AStmt);
  if Length(LDiag) > 0 then
  begin
    LSs := LDiag[0].SqlState;
    LNative := LDiag[0].NativeError;
    LMsg := LDiag[0].Message;
    if LMsg = '' then
      LMsg := TextFormat('odbc: %s failed [%s/%d]',
        [AContext, LSs, LNative]);
  end
  else
  begin
    LSs := '';
    LNative := 0;
    LMsg := TextFormat('odbc: %s failed [retcode %d, no diagnostics]',
      [AContext, ARetCode]);
  end;
  sql_freeHandle(SQL_HANDLE_STMT, AStmt);
  ClassifyOdbcEx(LSs, LNative, AMyFlavor, LCategory, LConstraint);
  raise NewDbErrorOdbc(LNative, LSs, LMsg, LCategory, LConstraint);
end;

{ ---- 占位符槽位计划 ---- }

function TranslatePlaceholdersOdbc(const ASql: string;
  out ARewritten: string; out ASlots: TIntArray): Integer; inline;
var
  LSlots: nextpas.core.text.sqlscan.TSqlScanSlotArray;
begin
  { V3-C6：词法扫描收敛至 text.sqlscan L1 单源（行为逐字节兼容） }
  // perf: inline 零拷贝直连 L1 单遍引擎（零二层别名间接已消除，直连 text.sqlscan 单源），bytes.ops 单源复用
  // note: db.sqlscan 已物理删除，直连 L1 单源免一跳转发
  Result := nextpas.core.text.sqlscan.SqlScanTranslateQuestion(ASql, nextpas.core.text.sqlscan.SQLSCAN_ODBC,
    ARewritten, LSlots);
  ASlots := TIntArray(LSlots);
end;

{ ---- TOdbcQuery ---- }

type
  TDbOdbcQuery = class(TInterfacedObject, IDbQuery)
  private
    FDbc: Pointer;                    { 连接句柄（归连接对象所有）}
    FStmt: Pointer;
    FSlots: TIntArray;                { 物理槽 -> 逻辑号 }
    FParamCount: Integer;             { 服务端参数计数 }
    FLogical: array of TOdbcBindValue;
    { 执行期 C 侧稳定缓冲（延迟绑定要求存活到 SQLExecute 之后）}
    FParamBufs: array of TBytes;
    FParamInds: array of Int64;
    FExecuted: Boolean;
    FSetupDone: Boolean;              { 结果元数据已读 }
    FHasRow: Boolean;
    FFieldCount: Integer;
    FColMeta: array of record
      Name: string;
      SqlType: SmallInt;
    end;
    FRowCache: array of TOdbcCell;    { 当前行惰性物化缓存 }
    FGetDataBuf: TBytes;              { LoadColumn 复用缓冲：跨行复用免每列每行 GetMem/FreeMem，bytes.ops 单源扩容，零拷贝单 Move 入行缓存 }
    { 观测钩子（V3-B3）：nil = 无枢纽；FEmitted = 本执行周期已发
      OnQuery（首 Step 计时，同周期后续 Step 不再发）}
    FTrace: TDbTraceHub;
    FSql: string;                     { 统一契约原文（? 原样进摘要）}
    FEmitted: Boolean;
    FMyFlavor: Boolean;               { MySQL 系驱动：允许码位提精 }
    procedure CheckIndex(const AIndex: Integer);
    procedure ExecuteIfNeeded;
    procedure MarshalParams;
    procedure SetupMetadata;
    procedure FetchRowOrRaise;
    procedure BeginRowCache;
    procedure LoadColumn(const AIndex: Integer);
    procedure RequireOpenRow(const AIndex: Integer);
    procedure FreeExecutionState;
    function IsIntegerType(const ASqlType: SmallInt): Boolean;
    function IsBinaryType(const ASqlType: SmallInt): Boolean;
  public
    constructor Create(ADbc: Pointer; AStmt: Pointer;
      const ASlots: TIntArray; AServerParamCount: Integer;
      const ASql: string; ATrace: TDbTraceHub; AMyFlavor: Boolean);
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

constructor TDbOdbcQuery.Create(ADbc: Pointer; AStmt: Pointer;
  const ASlots: TIntArray; AServerParamCount: Integer;
  const ASql: string; ATrace: TDbTraceHub; AMyFlavor: Boolean);
var
  I: Integer;
begin
  inherited Create;
  FDbc := ADbc;
  FStmt := AStmt;
  FMyFlavor := AMyFlavor;
  FParamCount := AServerParamCount;
  SetLength(FSlots, Length(ASlots));
  for I := 0 to High(ASlots) do
    FSlots[I] := ASlots[I];
  { 槽位数必须与服务端参数计数一致：翻译器缺陷 fail-fast 在构造期 }
  if Length(FSlots) <> FParamCount then
  begin
    sql_freeHandle(SQL_HANDLE_STMT, FStmt);
    FStmt := nil;
    raise EDbError.CreateSimple(dbkOdbc,
      'placeholder plan produced ' + IntToStr(Length(FSlots)) +
      ' slots but server expects ' + IntToStr(FParamCount));
  end;
  SetLength(FLogical, FParamCount);
  for I := 0 to FParamCount - 1 do
    FLogical[I].Kind := obkNone;
  FSql := ASql;
  FTrace := ATrace;
  FEmitted := False;
end;

destructor TDbOdbcQuery.Destroy;
begin
  FreeExecutionState;
  if FStmt <> nil then
  begin
    sql_freeHandle(SQL_HANDLE_STMT, FStmt);
    FStmt := nil;
  end;
  inherited Destroy;
end;

procedure TDbOdbcQuery.FreeExecutionState;
begin
  SetLength(FRowCache, 0);
  SetLength(FParamBufs, 0);
  SetLength(FParamInds, 0);
  FFieldCount := 0;
  SetLength(FColMeta, 0);
  FSetupDone := False;
  FExecuted := False;
  FHasRow := False;
end;

function TDbOdbcQuery.IsIntegerType(const ASqlType: SmallInt): Boolean;
begin
  Result := (ASqlType = SQL_TINYINT) or (ASqlType = SQL_SMALLINT) or
    (ASqlType = SQL_INTEGER) or (ASqlType = SQL_BIGINT);
end;

function TDbOdbcQuery.IsBinaryType(const ASqlType: SmallInt): Boolean;
begin
  Result := (ASqlType = SQL_BINARY) or (ASqlType = SQL_VARBINARY) or
    (ASqlType = SQL_LONGVARBINARY);
end;

procedure TDbOdbcQuery.CheckIndex(const AIndex: Integer);
begin
  if (AIndex < 1) or (AIndex > FParamCount) then
    raise EDbError.CreateSimple(dbkOdbc,
      'bind index ' + IntToStr(AIndex) + ' out of range 1..' +
      IntToStr(FParamCount));
end;

procedure TDbOdbcQuery.BindText(AIndex: Integer; const AValue: string);
begin
  CheckIndex(AIndex);
  FLogical[AIndex - 1].Kind := obkText;
  FLogical[AIndex - 1].TextVal := AValue;
end;

procedure TDbOdbcQuery.BindInt64(AIndex: Integer; const AValue: Int64);
begin
  CheckIndex(AIndex);
  FLogical[AIndex - 1].Kind := obkInt;
  FLogical[AIndex - 1].IntVal := AValue;
end;

procedure TDbOdbcQuery.BindDouble(AIndex: Integer; const AValue: Double);
begin
  CheckIndex(AIndex);
  FLogical[AIndex - 1].Kind := obkDouble;
  FLogical[AIndex - 1].DblVal := AValue;
end;

procedure TDbOdbcQuery.BindBlob(AIndex: Integer; const AValue: TBytes);
begin
  CheckIndex(AIndex);
  FLogical[AIndex - 1].Kind := obkBlob;
  FLogical[AIndex - 1].BlobVal := Copy(AValue, 0, Length(AValue));
end;

procedure TDbOdbcQuery.BindNull(AIndex: Integer);
begin
  CheckIndex(AIndex);
  FLogical[AIndex - 1].Kind := obkNull;
end;

procedure TDbOdbcQuery.MarshalParams;
var
  I, LLogical, LLen: Integer;
  LRc: SmallInt;
begin
  SetLength(FParamBufs, FParamCount);
  SetLength(FParamInds, FParamCount);
  for I := 0 to FParamCount - 1 do
  begin
    LLogical := FSlots[I] - 1;
    case FLogical[LLogical].Kind of
      obkInt:
        begin
          SetLength(FParamBufs[I], SizeOf(Int64));
          Move(FLogical[LLogical].IntVal, FParamBufs[I][0], SizeOf(Int64));
          FParamInds[I] := SizeOf(Int64);
          LRc := sql_bindParameter(FStmt, Word(I + 1), SQL_PARAM_INPUT,
            SQL_C_SBIGINT, SQL_BIGINT, 19, 0, @FParamBufs[I][0],
            SizeOf(Int64), @FParamInds[I]);
        end;
      obkDouble:
        begin
          SetLength(FParamBufs[I], SizeOf(Double));
          Move(FLogical[LLogical].DblVal, FParamBufs[I][0],
            SizeOf(Double));
          FParamInds[I] := SizeOf(Double);
          LRc := sql_bindParameter(FStmt, Word(I + 1), SQL_PARAM_INPUT,
            SQL_C_DOUBLE, SQL_DOUBLE, 15, 0, @FParamBufs[I][0],
            SizeOf(Double), @FParamInds[I]);
        end;
      obkText:
        begin
          LLen := Length(FLogical[LLogical].TextVal);
          { 至少 1 字节：空串参数也需合法缓冲地址（指示符 0 表零长）}
          if LLen = 0 then
            SetLength(FParamBufs[I], 1)
          else
            SetLength(FParamBufs[I], LLen);
          if LLen > 0 then
            Move(FLogical[LLogical].TextVal[1], FParamBufs[I][0],
              SizeUInt(LLen));
          FParamInds[I] := LLen;
          if LLen > C_LONG_TYPE_THRESHOLD then
            LRc := sql_bindParameter(FStmt, Word(I + 1), SQL_PARAM_INPUT,
              SQL_C_CHAR, SQL_LONGVARCHAR, QWord(LLen), 0,
              @FParamBufs[I][0], LLen, @FParamInds[I])
          else
            LRc := sql_bindParameter(FStmt, Word(I + 1), SQL_PARAM_INPUT,
              SQL_C_CHAR, SQL_VARCHAR, QWord(LLen), 0,
              @FParamBufs[I][0], LLen, @FParamInds[I]);
        end;
      obkBlob:
        begin
          LLen := Length(FLogical[LLogical].BlobVal);
          if LLen = 0 then
            SetLength(FParamBufs[I], 1)
          else
            SetLength(FParamBufs[I], LLen);
          if LLen > 0 then
            Move(FLogical[LLogical].BlobVal[0], FParamBufs[I][0],
              SizeUInt(LLen));
          FParamInds[I] := LLen;
          if LLen > C_LONG_TYPE_THRESHOLD then
            LRc := sql_bindParameter(FStmt, Word(I + 1), SQL_PARAM_INPUT,
              SQL_C_BINARY, SQL_LONGVARBINARY, QWord(LLen), 0,
              @FParamBufs[I][0], LLen, @FParamInds[I])
          else
            LRc := sql_bindParameter(FStmt, Word(I + 1), SQL_PARAM_INPUT,
              SQL_C_BINARY, SQL_VARBINARY, QWord(LLen), 0,
              @FParamBufs[I][0], LLen, @FParamInds[I]);
        end;
    else { obkNull }
      begin
        SetLength(FParamBufs[I], 1);
        FParamBufs[I][0] := 0;
        FParamInds[I] := SQL_NULL_DATA;
        LRc := sql_bindParameter(FStmt, Word(I + 1), SQL_PARAM_INPUT,
          SQL_C_CHAR, SQL_CHAR, 1, 0, @FParamBufs[I][0], 1,
          @FParamInds[I]);
      end;
    end;
    if LRc = SQL_ERROR then
      RaiseOdbcH(SQL_HANDLE_STMT, FStmt, LRc, FMyFlavor,
        'SQLBindParameter(' + IntToStr(I + 1) + ')');
  end;
end;

procedure TDbOdbcQuery.ExecuteIfNeeded;
var
  I: Integer;
  LRc: SmallInt;
begin
  if FExecuted then
    Exit;
  { 未绑定参数 fail-fast：宁报错不传垃圾 }
  for I := 0 to FParamCount - 1 do
    if FLogical[I].Kind = obkNone then
      raise EDbError.CreateSimple(dbkOdbc,
        'parameter ' + IntToStr(I + 1) + ' not bound');
  if FParamCount > 0 then
    MarshalParams;
  LRc := sql_execute(FStmt);
  if LRc = SQL_ERROR then
    RaiseOdbcH(SQL_HANDLE_STMT, FStmt, LRc, FMyFlavor, 'SQLExecute');
  FExecuted := True;
end;

procedure TDbOdbcQuery.SetupMetadata;
var
  LN, LNameLen, LDigits, LNullable: SmallInt;
  LSize: QWord;
  LNameBuf: array[0..C_NAME_BUF - 1] of AnsiChar;
  LRc: SmallInt;
  I: Integer;
begin
  if FSetupDone then
    Exit;
  LN := 0;
  LRc := sql_numResultCols(FStmt, LN);
  if LRc = SQL_ERROR then
    RaiseOdbcH(SQL_HANDLE_STMT, FStmt, LRc, FMyFlavor, 'SQLNumResultCols');
  FFieldCount := Integer(LN);
  if FFieldCount = 0 then
  begin
    FSetupDone := True;   { 无结果集语句 }
    Exit;
  end;
  SetLength(FColMeta, FFieldCount);
  SetLength(FRowCache, FFieldCount);
  for I := 0 to FFieldCount - 1 do
  begin
    FillChar(LNameBuf, SizeOf(LNameBuf), 0);
    LNameLen := 0;
    LDigits := 0;
    LNullable := 0;
    LSize := 0;
    LRc := sql_describeCol(FStmt, Word(I + 1), @LNameBuf[0], C_NAME_BUF,
      LNameLen, FColMeta[I].SqlType, LSize, LDigits, LNullable);
    if LRc = SQL_ERROR then
      RaiseOdbcH(SQL_HANDLE_STMT, FStmt, LRc, FMyFlavor,
        'SQLDescribeCol(' + IntToStr(I + 1) + ')');
    { 硬边界：PAnsiChar 转串一律 StrPas }
    FColMeta[I].Name := StrPas(PAnsiChar(@LNameBuf[0]));
  end;
  FSetupDone := True;
end;

procedure TDbOdbcQuery.BeginRowCache;
var
  I: Integer;
begin
  for I := 0 to High(FRowCache) do
  begin
    FRowCache[I].Done := False;
    FRowCache[I].NullFlag := False;
    FRowCache[I].CellKind := ockText;
    FRowCache[I].IntVal := 0;
    FRowCache[I].Data := nil;
  end;
end;

procedure TDbOdbcQuery.FetchRowOrRaise;
var
  LRc: SmallInt;
begin
  LRc := sql_fetch(FStmt);
  case LRc of
    SQL_SUCCESS, SQL_SUCCESS_WITH_INFO:
      begin
        FHasRow := True;
        BeginRowCache;
      end;
    SQL_NO_DATA:
      FHasRow := False;
    SQL_ERROR:
      RaiseOdbcH(SQL_HANDLE_STMT, FStmt, LRc, FMyFlavor, 'SQLFetch');
  else
    raise EDbError.CreateSimple(dbkOdbc,
      'unexpected SQLFetch retcode: ' + IntToStr(LRc));
  end;
end;

procedure TDbOdbcQuery.LoadColumn(const AIndex: Integer);
// perf: 整数栈上零堆分配 + 文本/二进制复用 FGetDataBuf（bytes.ops 单源 BytesEnsureCapacity/BytesGrowCapacity amortized doubling）消除每列每行 GetMem/ReallocMem/FreeMem，单 Move 零拷贝入行缓存；范围扫 bench_db_stmt_cache 1.1×→2×+ 的堆 churn 成因之一已消除
// note: not inline per red line 1 (Move indexed must not be inline) — I-Cache/constant-propagation guard, 由调用侧 thin forward 保持 inline 零拷贝
const
  C_MAX_RETRY = 32;
var
  LTarget: SmallInt;
  LCap: SizeUInt;
  LInd: Int64;
  LRc: SmallInt;
  LRetry: Integer;
  LCell: TOdbcCell;
  LIntTmp: Int64;
begin
  LCell.Done := True;
  LCell.NullFlag := False;
  LCell.CellKind := ockText;
  LCell.IntVal := 0;
  LCell.Data := nil;
  if IsIntegerType(FColMeta[AIndex].SqlType) or
     (FColMeta[AIndex].SqlType = SQL_BIT) then
  begin
    // perf: 整数族栈变量零分配直取（SQL_C_SBIGINT 固定 8 字节），零 GetMem/零拷贝入 IntVal
    LTarget := SQL_C_SBIGINT;
    LIntTmp := 0;
    LRc := sql_getData(FStmt, Word(AIndex + 1), LTarget, @LIntTmp,
      Int64(SizeOf(Int64)), LInd);
    if LRc = SQL_ERROR then
      RaiseOdbcH(SQL_HANDLE_STMT, FStmt, LRc, FMyFlavor,
        'SQLGetData(' + IntToStr(AIndex + 1) + ')');
    if LInd = SQL_NULL_DATA then
      LCell.NullFlag := True
    else
    begin
      // 截断理论上不发生（固定 8 字节）；若驱动以 SUCCESS_WITH_INFO 提示更大容量则走复用缓冲重试（rare fallback，复用 bytes.ops 单源，不丢语义）
      if LRc = SQL_SUCCESS_WITH_INFO then
      begin
        LCap := C_GETDATA_INITIAL;
        if Length(FGetDataBuf) < Integer(LCap) then
          SetLength(FGetDataBuf, Integer(LCap));
        LRetry := 0;
        while LRc = SQL_SUCCESS_WITH_INFO do
        begin
          Inc(LRetry);
          if LRetry > C_MAX_RETRY then
            raise EDbError.CreateSimple(dbkOdbc,
              'SQLGetData did not converge for column ' +
              IntToStr(AIndex + 1));
          if LInd = SQL_NO_TOTAL then
            LCap := SizeUInt(Length(FGetDataBuf)) * 2
          else if (LInd >= 0) and (SizeUInt(LInd) + 1 > SizeUInt(Length(FGetDataBuf))) then
            LCap := SizeUInt(LInd) + 1
          else
            LCap := SizeUInt(Length(FGetDataBuf)) * 2;
          // perf: bytes.ops 单源扩容（amortized doubling, overflow guard），复用堆块免每列 ReallocMem
          BytesEnsureCapacity(FGetDataBuf, LCap);
          LCap := SizeUInt(Length(FGetDataBuf));
          LRc := sql_getData(FStmt, Word(AIndex + 1), LTarget,
            @FGetDataBuf[0], Int64(LCap), LInd);
          if LRc = SQL_ERROR then
            RaiseOdbcH(SQL_HANDLE_STMT, FStmt, LRc, FMyFlavor,
              'SQLGetData(' + IntToStr(AIndex + 1) + ', retry)');
          if LInd = SQL_NULL_DATA then
          begin
            LCell.NullFlag := True;
            Break;
          end;
        end;
        if not LCell.NullFlag then
        begin
          if (LInd < 0) or (LInd > Int64(Length(FGetDataBuf))) then
            raise EDbError.CreateSimple(dbkOdbc,
              'SQLGetData indicator inconsistent for column ' +
              IntToStr(AIndex + 1));
          // 复用缓冲已含整值，Move 至 IntVal 单次零额外分配
          Move(FGetDataBuf[0], LCell.IntVal, SizeOf(Int64));
          LCell.CellKind := ockInt;
        end;
      end
      else
      begin
        if (LInd < 0) or (LInd > Int64(SizeOf(Int64))) then
          raise EDbError.CreateSimple(dbkOdbc,
            'SQLGetData indicator inconsistent for column ' +
            IntToStr(AIndex + 1));
        LCell.IntVal := LIntTmp;
        LCell.CellKind := ockInt;
      end;
    end;
  end
  else
  begin
    if IsBinaryType(FColMeta[AIndex].SqlType) then
      LTarget := SQL_C_BINARY
    else
      LTarget := SQL_C_CHAR;
    LCap := C_GETDATA_INITIAL;
    // perf: 复用 FGetDataBuf 免每行每列 GetMem/FreeMem，bytes.ops 单源零拷贝（单 Move 入 Data）
    if Length(FGetDataBuf) < Integer(LCap) then
      SetLength(FGetDataBuf, Integer(LCap));
    // stability: FGetDataBuf 跨行复用，try 块已移除但资源由对象生命周期托管不丢；异常不泄漏句柄
    LRc := sql_getData(FStmt, Word(AIndex + 1), LTarget,
      @FGetDataBuf[0], Int64(Length(FGetDataBuf)), LInd);
    if LRc = SQL_ERROR then
      RaiseOdbcH(SQL_HANDLE_STMT, FStmt, LRc, FMyFlavor,
        'SQLGetData(' + IntToStr(AIndex + 1) + ')');
    if LInd = SQL_NULL_DATA then
      LCell.NullFlag := True
    else
    begin
      LRetry := 0;
      while LRc = SQL_SUCCESS_WITH_INFO do
      begin
        Inc(LRetry);
        if LRetry > C_MAX_RETRY then
          raise EDbError.CreateSimple(dbkOdbc,
            'SQLGetData did not converge for column ' +
            IntToStr(AIndex + 1));
        if LInd = SQL_NO_TOTAL then
          LCap := SizeUInt(Length(FGetDataBuf)) * 2
        else if (LInd >= 0) and (SizeUInt(LInd) + 1 > SizeUInt(Length(FGetDataBuf))) then
          LCap := SizeUInt(LInd) + 1
        else
          LCap := SizeUInt(Length(FGetDataBuf)) * 2;
        BytesEnsureCapacity(FGetDataBuf, LCap);
        LCap := SizeUInt(Length(FGetDataBuf));
        LRc := sql_getData(FStmt, Word(AIndex + 1), LTarget,
          @FGetDataBuf[0], Int64(LCap), LInd);
        if LRc = SQL_ERROR then
          RaiseOdbcH(SQL_HANDLE_STMT, FStmt, LRc, FMyFlavor,
            'SQLGetData(' + IntToStr(AIndex + 1) + ', retry)');
        if LInd = SQL_NULL_DATA then
        begin
          LCell.NullFlag := True;
          Break;
        end;
      end;
      if not LCell.NullFlag then
      begin
        if (LInd < 0) or (LInd > Int64(Length(FGetDataBuf))) then
          raise EDbError.CreateSimple(dbkOdbc,
            'SQLGetData indicator inconsistent for column ' +
            IntToStr(AIndex + 1));
        SetLength(LCell.Data, Integer(LInd));
        if LInd > 0 then
          Move(FGetDataBuf[0], LCell.Data[0], SizeUInt(LInd));
        if LTarget = SQL_C_BINARY then
          LCell.CellKind := ockBlob
        else
          LCell.CellKind := ockText;
      end;
    end;
  end;
  FRowCache[AIndex] := LCell;
end;

procedure TDbOdbcQuery.RequireOpenRow(const AIndex: Integer);
begin
  if (AIndex < 0) or (AIndex >= FFieldCount) then
    raise EDbError.CreateSimple(dbkOdbc,
      'column index ' + IntToStr(AIndex) + ' out of range 0..' +
      IntToStr(FFieldCount - 1));
  if not FHasRow then
    raise EDbError.CreateSimple(dbkOdbc,
      'no current row (Step returned False)');
end;

procedure TDbOdbcQuery.Reset;
begin
  FEmitted := False;   { 重执行周期重新计时 }
  if FExecuted then
  begin
    { 回卷执行态：关游标使 stmt 可重执行；NO_DATA/未开游标均合法 }
    sql_closeCursor(FStmt);
    FExecuted := False;
  end;
  FreeExecutionState;
end;

function TDbOdbcQuery.Step: Boolean;
var
  LT0: QWord;
  LTimed: Boolean;
begin
  LT0 := 0;
  LTimed := (FTrace <> nil) and (not FEmitted) and FTrace.BeginOp(LT0);
  try
    ExecuteIfNeeded;
    SetupMetadata;
    if FFieldCount = 0 then
    begin
      FHasRow := False;   { 无结果集语句：永久无行，也是成功执行 }
      Result := False;
    end
    else
    begin
      FetchRowOrRaise;
      Result := FHasRow;
    end;
    if LTimed then
    begin
      FEmitted := True;
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

function TDbOdbcQuery.ColumnCount: Integer;
begin
  Result := FFieldCount;
end;

function TDbOdbcQuery.ColumnName(AIndex: Integer): string;
begin
  RequireOpenRow(AIndex);
  Result := FColMeta[AIndex].Name;
end;

function TDbOdbcQuery.ColumnType(AIndex: Integer): TDbColumnType;
begin
  RequireOpenRow(AIndex);
  if not FRowCache[AIndex].Done then
    LoadColumn(AIndex);
  { NULL 是行级信号（与 sqlite/pg 同契约）：值空一律 dbcNull，
    非空才回落列声明类型 }
  if FRowCache[AIndex].NullFlag then
    Exit(dbcNull);
  case FColMeta[AIndex].SqlType of
    SQL_BIT:
      Result := dbcBool;
    SQL_TINYINT, SQL_SMALLINT, SQL_INTEGER, SQL_BIGINT:
      Result := dbcInteger;
    SQL_REAL, SQL_FLOAT, SQL_DOUBLE:
      Result := dbcFloat;
    SQL_BINARY, SQL_VARBINARY, SQL_LONGVARBINARY:
      Result := dbcBlob;
  else
    Result := dbcText;   { 文本/DECIMAL/日期族/GUID/未知 }
  end;
end;

function TDbOdbcQuery.IsNull(AIndex: Integer): Boolean;
begin
  RequireOpenRow(AIndex);
  if not FRowCache[AIndex].Done then
    LoadColumn(AIndex);
  Result := FRowCache[AIndex].NullFlag;
end;

function TDbOdbcQuery.GetInt64(AIndex: Integer): Int64;
var
  LS: string;
  LCode: Integer;
begin
  RequireOpenRow(AIndex);
  if not FRowCache[AIndex].Done then
    LoadColumn(AIndex);
  if FRowCache[AIndex].NullFlag then
    Exit(0);
  case FRowCache[AIndex].CellKind of
    ockInt:
      Result := FRowCache[AIndex].IntVal;
    ockText:
      begin
        LS := '';
        SetLength(LS, Length(FRowCache[AIndex].Data));
        if Length(FRowCache[AIndex].Data) > 0 then
          Move(FRowCache[AIndex].Data[0], LS[1],
            SizeUInt(Length(FRowCache[AIndex].Data)));
        Val(LS, Result, LCode);
        if LCode <> 0 then
          raise EDbError.CreateSimple(dbkOdbc,
            'not an integer value: "' + LS + '"');
      end;
  else
    raise EDbError.CreateSimple(dbkOdbc,
      'column ' + IntToStr(AIndex) + ' is not an integer value');
  end;
end;

function TDbOdbcQuery.GetDouble(AIndex: Integer): Double;
var
  LS: string;
  LCode: Integer;
begin
  RequireOpenRow(AIndex);
  if not FRowCache[AIndex].Done then
    LoadColumn(AIndex);
  if FRowCache[AIndex].NullFlag then
    Exit(0.0);
  case FRowCache[AIndex].CellKind of
    ockInt:
      Result := Double(FRowCache[AIndex].IntVal);
    ockText:
      begin
        LS := '';
        SetLength(LS, Length(FRowCache[AIndex].Data));
        if Length(FRowCache[AIndex].Data) > 0 then
          Move(FRowCache[AIndex].Data[0], LS[1],
            SizeUInt(Length(FRowCache[AIndex].Data)));
        Val(LS, Result, LCode);
        if LCode <> 0 then
          raise EDbError.CreateSimple(dbkOdbc,
            'not a numeric value: "' + LS + '"');
      end;
  else
    raise EDbError.CreateSimple(dbkOdbc,
      'column ' + IntToStr(AIndex) + ' is not a numeric value');
  end;
end;

function TDbOdbcQuery.GetText(AIndex: Integer): string;
begin
  RequireOpenRow(AIndex);
  if not FRowCache[AIndex].Done then
    LoadColumn(AIndex);
  if FRowCache[AIndex].NullFlag then
    Exit('');
  case FRowCache[AIndex].CellKind of
    ockInt:
      Result := IntToStr(FRowCache[AIndex].IntVal);
  else
    begin
      SetLength(Result, Length(FRowCache[AIndex].Data));
      if Length(FRowCache[AIndex].Data) > 0 then
        Move(FRowCache[AIndex].Data[0], Result[1],
          SizeUInt(Length(FRowCache[AIndex].Data)));
    end;
  end;
end;

function TDbOdbcQuery.GetBlob(AIndex: Integer): TBytes;
var
  LS: string;
begin
  RequireOpenRow(AIndex);
  if not FRowCache[AIndex].Done then
    LoadColumn(AIndex);
  if FRowCache[AIndex].NullFlag then
    Exit(nil);
  case FRowCache[AIndex].CellKind of
    ockInt:
      begin
        LS := IntToStr(FRowCache[AIndex].IntVal);
        SetLength(Result, Length(LS));
        if Length(LS) > 0 then
          Move(LS[1], Result[0], SizeUInt(Length(LS)));
      end;
  else
    Result := Copy(FRowCache[AIndex].Data, 0, Length(FRowCache[AIndex].Data));
  end;
end;

{ ---- TDbOdbcConnection ---- }

type
  TDbOdbcConnection = class(TInterfacedObject, IDbConnection, IDbTxControl,
    IDbBatchExecutor, IDbCapabilities, IDbTraceControl)
  private
    FEnv, FDbc: Pointer;
    FLock: INativeMutex;
    FDepth: Integer;
    FLastChanges: Int64;
    FSupportsTxn: Boolean;      { TXN_CAPABLE <> SQL_TC_NONE；探测失败保守 True }
    FIdentifierCase: SmallInt;  { SQL_IC_*；探测失败 0 }
    FProductName: string;
    FProductVersion: string;
    FDriverName: string;        { SQL_DRIVER_NAME（诊断 + flavor 判定）}
    FMyFlavor: Boolean;         { MySQL 系驱动：错误码位可提精 }
    FStmtTimeoutSec: Integer;   { 0 = 关；>0 每语句设 QUERY_TIMEOUT }
    { 观测钩子枢纽（V3-B3）：监听器存取/摘要/计时/分发统一委托 }
    FTrace: TDbTraceHub;
    procedure ApplyAutoCommit(const AOn: Boolean);
    procedure RestoreAutoCommitOn;
    procedure DoExec(const ASql: string; const ATimeoutSec: Integer);
    function DoQuery(const ASql: string;
      const ATimeoutSec: Integer): IDbQuery;
    function GetInfoSmall(AInfoType: Word; out AVal: SmallInt): Boolean;
    function GetInfoStr(AInfoType: Word): string;
    procedure ProbeCapabilities;
  public
    constructor Create(AEnv, ADbc: Pointer;
      const AOptions: TDbConnectOptions);
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

    { IDbBatchExecutor }
    procedure ExecuteBatch(const ASteps: TDbSqlSteps);

    { IDbCapabilities（V3-B1）——降级矩阵见单元头注 }
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
    function ServerVersion: Integer;
    function SupportsNativeVector: Boolean;
    function SupportsJsonPath: Boolean;
    function SupportsRangeTypes: Boolean;
    function SupportsBulkCopy: Boolean;
    function CaseSensitiveIdentifiers: Boolean;
    function MaxPlaceholders: Integer;
  end;

constructor TDbOdbcConnection.Create(AEnv, ADbc: Pointer;
  const AOptions: TDbConnectOptions);
begin
  inherited Create;
  FEnv := AEnv;
  FDbc := ADbc;
  FLock := nextpas.core.sync.Mutex;
  FDepth := 0;
  FLastChanges := 0;
  FIdentifierCase := 0;
  FSupportsTxn := True;   { 探测前的乐观缺省：真不支持会在 BeginTxn 处 fail-fast }
  FStmtTimeoutSec := 0;
  if AOptions.StatementTimeoutMs > 0 then
    FStmtTimeoutSec := (AOptions.StatementTimeoutMs + 999) div 1000;
  FTrace := TDbTraceHub.Create;
  { OnAcquire 由 SetListener 挂载时补发（§2.12），ctor 不预发 }
  ProbeCapabilities;
end;

{ ---- IDbTraceControl（V3-B3）---- }

procedure TDbOdbcConnection.SetListener(
  const AListener: IDbTraceListener);
begin
  FTrace.SetListener(AListener);
end;

function TDbOdbcConnection.HasListener: Boolean;
begin
  Result := FTrace.Active;
end;

destructor TDbOdbcConnection.Destroy;
begin
  FTrace.NotifyRelease;   { OnRelease = 连接关闭 }
  FreeAndNil(FTrace);
  if FDbc <> nil then
  begin
    sql_disconnect(FDbc);   { 尽力而为：已断连时错误可忽略 }
    sql_freeHandle(SQL_HANDLE_DBC, FDbc);
    FDbc := nil;
  end;
  if FEnv <> nil then
  begin
    sql_freeHandle(SQL_HANDLE_ENV, FEnv);
    FEnv := nil;
  end;
  inherited Destroy;
end;

function TDbOdbcConnection.GetInfoSmall(AInfoType: Word;
  out AVal: SmallInt): Boolean;
var
  LLen: SmallInt;
begin
  AVal := 0;
  Result := sql_getInfo(FDbc, AInfoType, @AVal, SizeOf(SmallInt),
    LLen) = SQL_SUCCESS;
end;

function TDbOdbcConnection.GetInfoStr(AInfoType: Word): string;
var
  LBuf: array[0..C_OUT_CONN_STR - 1] of AnsiChar;
  LLen: SmallInt;
begin
  Result := '';
  FillChar(LBuf, SizeOf(LBuf), 0);
  if sql_getInfo(FDbc, AInfoType, @LBuf[0], C_OUT_CONN_STR, LLen) =
    SQL_SUCCESS then
    Result := StrPas(PAnsiChar(@LBuf[0]));   { 硬边界：一律 StrPas }
end;

procedure TDbOdbcConnection.ProbeCapabilities;
var
  LVal: SmallInt;
begin
  { 探测失败逐项保守降级，不让诊断性查询破坏建连 }
  FProductName := GetInfoStr(SQL_DBMS_NAME);
  FProductVersion := GetInfoStr(SQL_DBMS_VER);
  FDriverName := GetInfoStr(SQL_DRIVER_NAME);
  { flavor 感知：驱动名或 DBMS 名命中 MySQL 词元才允许错误码位提精；
    探测失败（空串）保守 False，行为等同旧 ClassifyOdbc }
  FMyFlavor := IsMyFlavorName(FDriverName) or IsMyFlavorName(FProductName);
  if GetInfoSmall(SQL_IDENTIFIER_CASE, LVal) then
    FIdentifierCase := LVal;
  if GetInfoSmall(SQL_TXN_CAPABLE, LVal) then
    FSupportsTxn := LVal <> SQL_TC_NONE;
end;

procedure TDbOdbcConnection.ApplyAutoCommit(const AOn: Boolean);
var
  LRc: SmallInt;
begin
  LRc := sql_setConnectAttr(FDbc, SQL_ATTR_AUTOCOMMIT,
    Pointer(PtrInt(Ord(AOn))), 0);
  if LRc = SQL_ERROR then
    RaiseOdbcH(SQL_HANDLE_DBC, FDbc, LRc, FMyFlavor,
      'SQLSetConnectAttr(SQL_ATTR_AUTOCOMMIT)');
end;

procedure TDbOdbcConnection.RestoreAutoCommitOn;
begin
  { 先恢复状态再上抛（CommitTxn 语义）：恢复失败吞掉——此时连接
    事务态已定，静默降级好过掩盖原始错误 }
  try
    ApplyAutoCommit(True);
  except
  end;
end;

function TDbOdbcConnection.Kind: TDbKind;
begin
  Result := dbkOdbc;
end;

procedure TDbOdbcConnection.DoExec(const ASql: string;
  const ATimeoutSec: Integer);
var
  S: Pointer;
  LRc: SmallInt;
  LCnt: Int64;
  LT0: QWord;
  LTimed: Boolean;
begin
  S := nil;
  LRc := sql_allocHandle(SQL_HANDLE_STMT, FDbc, S);
  if LRc = SQL_ERROR then
    RaiseOdbcH(SQL_HANDLE_DBC, FDbc, LRc, FMyFlavor, 'SQLAllocHandle(STMT)');
  { 观测单点：Exec 两重载都经此，天然无双发（§2.12）}
  LT0 := 0;
  LTimed := FTrace.BeginOp(LT0);
  try
    try
      { 语句级超时（秒粒度）：属性随句柄消亡，无会话污染 }
      if ATimeoutSec > 0 then
        sql_setStmtAttr(S, SQL_ATTR_QUERY_TIMEOUT,
          Pointer(PtrInt(ATimeoutSec)), 0);
      LRc := sql_execDirect(S, PAnsiChar(AnsiString(ASql)),
        Integer(Length(ASql)));
      if LRc = SQL_ERROR then
        RaiseOdbcH(SQL_HANDLE_STMT, S, LRc, FMyFlavor, 'SQLExecDirect');
      { 影响行数在句柄释放前捕获（Changes 契约 = 最近一次 Exec）}
      LCnt := 0;
      if sql_rowCount(S, LCnt) = SQL_SUCCESS then
      begin
        FLock.Acquire;
        try
          FLastChanges := LCnt;
        finally
          FLock.Release;
        end;
      end;
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
    sql_freeHandle(SQL_HANDLE_STMT, S);
  end;
end;

procedure TDbOdbcConnection.Exec(const ASql: string);
begin
  DoExec(ASql, FStmtTimeoutSec);   { 连接级默认（连接选项），0 = 关 }
end;

procedure TDbOdbcConnection.Exec(const ASql: string;
  const AOptions: TDbExecOptions);
begin
  { 调用级覆盖连接级默认；advisory：0 = 沿用缺省 }
  if AOptions.TimeoutMs > 0 then
    DoExec(ASql, (AOptions.TimeoutMs + 999) div 1000)
  else
    DoExec(ASql, FStmtTimeoutSec);
end;

function TDbOdbcConnection.Query(const ASql: string;
  const AOptions: TDbExecOptions): IDbQuery;
begin
  { 调用级覆盖连接级默认；advisory：0 = 沿用缺省 }
  if AOptions.TimeoutMs > 0 then
    Result := DoQuery(ASql, (AOptions.TimeoutMs + 999) div 1000)
  else
    Result := DoQuery(ASql, FStmtTimeoutSec);
end;

function TDbOdbcConnection.DoQuery(const ASql: string;
  const ATimeoutSec: Integer): IDbQuery;
var
  LRewritten: string;
  LSlots: TIntArray;
  S: Pointer;
  LRc, LN: SmallInt;
begin
  TranslatePlaceholdersOdbc(ASql, LRewritten, LSlots);
  S := nil;
  LRc := sql_allocHandle(SQL_HANDLE_STMT, FDbc, S);
  if LRc = SQL_ERROR then
    RaiseOdbcH(SQL_HANDLE_DBC, FDbc, LRc, FMyFlavor, 'SQLAllocHandle(STMT)');
  { 语句级超时：秒粒度向上取整，属性随句柄消亡；个别驱动拒绝属
    环境降级（best effort）}
  if ATimeoutSec > 0 then
    sql_setStmtAttr(S, SQL_ATTR_QUERY_TIMEOUT,
      Pointer(PtrInt(ATimeoutSec)), 0);
  LRc := sql_prepare(S, PAnsiChar(AnsiString(LRewritten)),
    Integer(Length(LRewritten)));
  if LRc = SQL_ERROR then
    RaiseOdbcStmtClose(S, LRc, FMyFlavor, 'SQLPrepare');
  LN := 0;
  LRc := sql_numParams(S, LN);
  if LRc = SQL_ERROR then
    RaiseOdbcStmtClose(S, LRc, FMyFlavor, 'SQLNumParams');
  { 成功路径句柄移交 TDbOdbcQuery；其构造期槽位失配会自清句柄 }
  Result := TDbOdbcQuery.Create(FDbc, S, LSlots, Integer(LN), ASql,
    FTrace, FMyFlavor);
end;

function TDbOdbcConnection.Query(const ASql: string): IDbQuery;
begin
  Result := DoQuery(ASql, FStmtTimeoutSec);   { 连接级默认 }
end;

function TDbOdbcConnection.Changes: Int64;
begin
  FLock.Acquire;
  try
    Result := FLastChanges;
  finally
    FLock.Release;
  end;
end;

function TDbOdbcConnection.Raw: Pointer;
begin
  { 与 pg/mysql 侧同契约：逃生舱返回 nil；需原生句柄走 odbc 门面直用 }
  Result := nil;
end;

procedure TDbOdbcConnection.BeginTxn(const AImmediate: Boolean);
begin
  if not FSupportsTxn then
    raise NewDbErrorOdbc(0, '',
      'driver reports no transaction support (SQL_TXN_CAPABLE=SQL_TC_NONE)',
      decNotSupported, dckNone);
  { AImmediate 无对应语义（ISO CLI 无 IMMEDIATE 变体），接受为
    no-op——契约差异登记 CONTRACT §2.3 }
  FLock.Acquire;
  try
    if FDepth = 0 then
      ApplyAutoCommit(False);
    Inc(FDepth);
  finally
    FLock.Release;
  end;
end;

procedure TDbOdbcConnection.CommitTxn;
var
  LRc: SmallInt;
begin
  FLock.Acquire;
  try
    if FDepth = 0 then
      raise EDbError.CreateSimple(dbkOdbc,
        'CommitTxn without a matching BeginTxn on this connection');
    if FDepth > 1 then
      Dec(FDepth)
    else
    begin
      LRc := sql_endTran(SQL_HANDLE_DBC, FDbc, SQL_COMMIT);
      RestoreAutoCommitOn;   { 先恢复状态再抛，防连接卡在手动提交 }
      if LRc = SQL_ERROR then
        RaiseOdbcH(SQL_HANDLE_DBC, FDbc, LRc, FMyFlavor, 'SQLEndTran(COMMIT)');
      FDepth := 0;
    end;
  finally
    FLock.Release;
  end;
end;

procedure TDbOdbcConnection.RollbackTxn;
var
  LRc: SmallInt;
begin
  FLock.Acquire;
  try
    if FDepth = 0 then
      raise EDbError.CreateSimple(dbkOdbc,
        'RollbackTxn without a matching BeginTxn on this connection');
    { 任意深度 = 回滚整个事务（对齐 sqlite/pg）；回滚失败吞掉
      （服务端可能已自行中止事务），原异常由调用方重抛 }
    LRc := sql_endTran(SQL_HANDLE_DBC, FDbc, SQL_ROLLBACK);
    RestoreAutoCommitOn;
    FDepth := 0;
  finally
    FLock.Release;
  end;
end;

function TDbOdbcConnection.InTransaction: Boolean;
begin
  Result := TxDepth > 0;
end;

function TDbOdbcConnection.TxDepth: Integer;
begin
  FLock.Acquire;
  try
    Result := FDepth;
  finally
    FLock.Release;
  end;
end;

procedure TDbOdbcConnection.ExecuteBatch(const ASteps: TDbSqlSteps);
var
  K: Integer;
begin
  if Length(ASteps) = 0 then
    Exit;
  { 无多语句合并假设：逐条执行保留精确到步骤的错误定位，任一步
    失败整批回滚。计数器为捕获变量，FPC 禁其用于 for，故用 while }
  K := 0;
  WithTransaction(Self, procedure
  begin
    K := 0;
    while K <= High(ASteps) do
    begin
      Exec(ASteps[K]);
      Inc(K);
    end;
  end);
end;

{ ---- IDbCapabilities（V3-B1；降级矩阵见单元头注）---- }

function TDbOdbcConnection.ProductName: string;
begin
  Result := FProductName;
end;

function TDbOdbcConnection.ProductVersion: string;
begin
  Result := FProductVersion;
end;

function TDbOdbcConnection.SupportsSavepoints: Boolean;
begin
  Result := False;  { ISO CLI 无保存点发现机制；不实现
    IDbSavepointControl（与互证契约一致），不假装支持 }
end;

function TDbOdbcConnection.SupportsBatchExecutor: Boolean;
begin
  Result := True;   { IDbBatchExecutor 已实现（逐条 + 单事务）}
end;

function TDbOdbcConnection.SupportsStmtCacheControl: Boolean;
begin
  Result := False;  { A4 未接语句缓存（C 线排期）}
end;

function TDbOdbcConnection.SupportsLargeObjects: Boolean;
begin
  Result := False;  { 统一层无 LO 面（网关无跨驱动 LO 语义）}
end;

function TDbOdbcConnection.SupportsArrayBinding: Boolean;
begin
  Result := False;   { v1 未实现参数级批量绑定（诚实契约） }
end;

function TDbOdbcConnection.SupportsNativeBool: Boolean;
begin
  Result := False;  { 异构网关无法静态断言后端布尔类型；欠归一 }
end;

function TDbOdbcConnection.SupportsMultiStatementExec: Boolean;
begin
  Result := False;  { 分号批行为因驱动而异；批量走 IDbBatchExecutor }
end;

function TDbOdbcConnection.SupportsStatementTimeout: Boolean;
begin
  Result := True;   { SQL_ATTR_QUERY_TIMEOUT 逐语句应用（秒粒度）；
    个别驱动拒绝属环境降级 }
end;

function TDbOdbcConnection.CaseSensitiveIdentifiers: Boolean;
begin
  Result := FIdentifierCase = SQL_IC_SENSITIVE;   { 探测失败 0 → False }
end;

function TDbOdbcConnection.MaxPlaceholders: Integer;
begin
  Result := 999;    { ISO CLI 无参数上限 InfoType；取与 sqlite 保证值
    同级的保守下界 }
end;

function TDbOdbcConnection.ServerVersion: Integer;
begin
  Result := ParseServerVersion(ProductVersion);
end;

function TDbOdbcConnection.SupportsNativeVector: Boolean;
begin
  Result := ProbeNativeVector(ServerVersion, False);
end;

function TDbOdbcConnection.SupportsJsonPath: Boolean;
begin
  Result := ProbeJsonPath(ServerVersion);
end;

function TDbOdbcConnection.SupportsRangeTypes: Boolean;
begin
  Result := ProbeRangeTypes(ServerVersion);
end;

function TDbOdbcConnection.SupportsBulkCopy: Boolean;
begin
  Result := ProbeSupportsBulkCopy(dbkOdbc);
end;

{ ---- 工厂 ---- }

function ConnectOdbc(const ADsn: string): IDbConnection;
begin
  Result := ConnectOdbc(ADsn, TDbConnectOptions.Default);
end;

procedure ValidateOdbcConnStr(const AConnStr: string);
var
  LErr: string;
begin
  if not ValidateKV(AConnStr, LErr) then
    raise EDbError.CreateSimple(dbkOdbc, LErr);
end;

function ConnectOdbc(const ADsn: string;
  const AOptions: TDbConnectOptions): IDbConnection;
var
  LEnv, LDbc: Pointer;
  LRc: SmallInt;
  LOut: array[0..C_OUT_CONN_STR - 1] of AnsiChar;
  LOutLen: SmallInt;
begin
  ValidateOdbcConnStr(ADsn);
  OdbcEnsureLoaded;
  LEnv := nil;
  LDbc := nil;
  LRc := sql_allocHandle(SQL_HANDLE_ENV, nil, LEnv);
  if LRc = SQL_ERROR then
    raise EDbError.CreateSimple(dbkOdbc, 'SQLAllocHandle(ENV) failed');
  try
    LRc := sql_setEnvAttr(LEnv, SQL_ATTR_ODBC_VERSION,
      Pointer(PtrInt(SQL_OV_ODBC3)), 0);
    if LRc = SQL_ERROR then
      raise EDbError.CreateSimple(dbkOdbc,
        'driver manager does not support ODBC 3.x');
    LRc := sql_allocHandle(SQL_HANDLE_DBC, LEnv, LDbc);
    if LRc = SQL_ERROR then
      raise EDbError.CreateSimple(dbkOdbc, 'SQLAllocHandle(DBC) failed');
    try
      { BusyTimeoutMs 映射建连窗口（诚实表见 db.base）；个别驱动
        不认 LOGIN_TIMEOUT 属环境降级，失败容忍 }
      if AOptions.BusyTimeoutMs > 0 then
        sql_setConnectAttr(LDbc, SQL_ATTR_LOGIN_TIMEOUT,
          Pointer(PtrInt((AOptions.BusyTimeoutMs + 999) div 1000)), 0);
      FillChar(LOut, SizeOf(LOut), 0);
      LOutLen := 0;
      LRc := sql_driverConnect(LDbc, nil, PAnsiChar(AnsiString(ADsn)),
        SQL_NTS, @LOut[0], C_OUT_CONN_STR, LOutLen, SQL_DRIVER_NOPROMPT);
      if LRc = SQL_ERROR then
        { 建连失败：连接对象未建、flavor 未探测，恒按 ISO SQLSTATE
          归一（连接类错误本就不依赖码位提精） }
        RaiseOdbcH(SQL_HANDLE_DBC, LDbc, LRc, False, 'SQLDriverConnect');
      { 句柄所有权在此移交连接对象；构造期不再抛错（探测全为
        best effort），故移交后无双重释放窗口 }
      Result := TDbOdbcConnection.Create(LEnv, LDbc, AOptions);
    except
      sql_freeHandle(SQL_HANDLE_DBC, LDbc);   { 仅覆盖建连窗口 }
      raise;
    end;
  except
    sql_freeHandle(SQL_HANDLE_ENV, LEnv);
    raise;
  end;
end;

function ConnectOdbc(const ADsn: string; const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection;
begin
  Result := ConnectOdbc(ADsn, AOptions);
end;

end.
