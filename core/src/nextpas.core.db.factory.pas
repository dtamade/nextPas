unit nextpas.core.db.factory;

{** @desc 统一驱动注册工厂，对标 Go sql.Register/Open。内建五驱动自注册，第三方 via IDbDriver 注入；Open 即池复用 V3-C3；详见 CONTRACT §2.10/§2.14。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.text.utils,
  nextpas.core.text.conv,
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.db.pool;

type
  { 已注册驱动名快照（小写规范形，字典序排序）。诊断/运维用。
    显式数组别名：ObjFPC 模式泛型简写在跨单元签名处有坑（家族惯例）。 }
  TDbDriverNames = array of string;

  { 单一驱动抽象：注册键 + 归属声明 + 打开。Name 为注册键（注册时
    归一为小写）；Kind 为内建枚举归属（第三方可诚实返回 dbkUnknown）。 }
  IDbDriver = interface
    ['{8F2E7A64-9C1D-4B0E-A3D7-51C2B90FE101}']
    function Name: string;
    function Kind: TDbKind;
    function Open(const ADsn: string;
      const AOptions: TDbConnectOptions): IDbConnection;
  end;

  { 驱动打开闭包：内建驱动装配用 }
  TDbDriverOpenFunc = reference to function(const ADsn: string;
    const AOptions: TDbConnectOptions): IDbConnection;

{ 注册驱动。nil/空名/重复名一律抛 EDbError(dbkUnknown) fail-closed。
  名字大小写不敏感（注册时归一小写）。 }
procedure DbRegisterDriver(ADriver: IDbDriver);

{ 已注册驱动名快照（小写规范形，字典序排序）。诊断/运维用。 }
function DbRegisteredDrivers: TDbDriverNames;

function DbDriverExists(const AName: string): Boolean;

{ 统一打开入口（Go sql.Open 语义）。未知驱动名抛 EDbError 并携带
  驱动名原文；后端连接错误原样透传（保留各自 EDbError.Backend）。 }
function DbOpen(const ADriver: string; const ADsn: string): IDbConnection;
  overload;
function DbOpen(const ADriver: string; const ADsn: string;
  const AOptions: TDbConnectOptions): IDbConnection; overload;

{ 按内建枚举打开。dbkUnknown 或无对应驱动时先按 Kind 扫描注册表
  （支持第三方占位），仍无则 EDbNotSupported fail-closed。 }
function DbOpen(AKind: TDbKind; const ADsn: string;
  const AOptions: TDbConnectOptions): IDbConnection; overload;

{ Open 即池：以 DbOpen 为连接工厂构建 V3-C3 池（Go *sql.DB 形态）。
  连接选项取 TDbConnectOptions.Default（advisory 惯例；细控场景
  直接持 TDbPool.Create 自组工厂闭包）。预热失败 fail-fast 抛
  原建连错（池 Create 语义）。 }
function DbOpenPool(const ADriver: string; const ADsn: string;
  const APolicy: TDbPoolPolicy): TDbPool; overload;
function DbOpenPool(AKind: TDbKind; const ADsn: string;
  const APolicy: TDbPoolPolicy): TDbPool; overload;

implementation

uses
  nextpas.core.sync.intf,
  nextpas.core.sync.mutex,
  nextpas.core.db.sqlite.adapter,
  nextpas.core.db.pg.adapter,
  nextpas.core.db.mysql.adapter,
  nextpas.core.db.odbc.adapter,
  nextpas.core.db.redis.adapter;

type
  TDbDriverEntry = record
    Name: string;
    Driver: IDbDriver;
  end;

  { 内建驱动装配：名字 + 枚举 + 打开函数三件套 }
  TBuiltinDriver = class(TInterfacedObject, IDbDriver)
  private
    FName: string;
    FKind: TDbKind;
    FOpen: TDbDriverOpenFunc;
  public
    constructor Create(const AName: string; AKind: TDbKind;
      const AOpen: TDbDriverOpenFunc);
    function Name: string;
    function Kind: TDbKind;
    function Open(const ADsn: string;
      const AOptions: TDbConnectOptions): IDbConnection;
  end;

var
  GDrivers: array of TDbDriverEntry;
  GLock: ILock = nil;

function NormalizeName(const AName: string): string;
begin
  Result := NormalizeLowerTrim(AName);
end;

function FindEntryLocked(const AName: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(GDrivers) do
    if GDrivers[I].Name = AName then
      Exit(I);
  Result := -1;
end;

{ 注册驱动。nil/空名/重复名 fail-closed；大小写不敏感。实现注记见 ROADMAP §A5（FPC trunk 临时量缺陷规避）。 }
procedure DbRegisterDriver(ADriver: IDbDriver);
var
  LName: string;
  LEntry: TDbDriverEntry;
  LDup: Boolean;
begin
  if ADriver = nil then
    raise EDbError.CreateSimple(dbkUnknown,
      'db.factory: nil driver registration');
  LName := NormalizeName(ADriver.Name);
  if LName = '' then
    raise EDbError.CreateSimple(dbkUnknown,
      'db.factory: driver name must not be empty');
  GLock.Acquire;
  try
    LDup := FindEntryLocked(LName) >= 0;
    if not LDup then
    begin
      LEntry.Name := LName;
      LEntry.Driver := ADriver;
      SetLength(GDrivers, Length(GDrivers) + 1);
      GDrivers[High(GDrivers)] := LEntry;
    end;
  finally
    GLock.Release;
  end;
  if LDup then
    raise EDbError.CreateSimple(dbkUnknown,
      'db.factory: driver already registered: ' + LName);
end;

function DbDriverExists(const AName: string): Boolean;
var
  LName: string;
begin
  LName := NormalizeName(AName);
  GLock.Acquire;
  try
    Result := FindEntryLocked(LName) >= 0;
  finally
    GLock.Release;
  end;
end;

function DbRegisteredDrivers: TDbDriverNames;
var
  I, J: Integer;
  LTmp: string;
begin
  GLock.Acquire;
  try
    SetLength(Result, Length(GDrivers));
    for I := 0 to High(GDrivers) do
      Result[I] := GDrivers[I].Name;
  finally
    GLock.Release;
  end;
  { 插入排序：注册表个位数量级，稳定且零依赖 }
  for I := 1 to High(Result) do
  begin
    LTmp := Result[I];
    J := I - 1;
    while (J >= 0) and (Result[J] > LTmp) do
    begin
      Result[J + 1] := Result[J];
      Dec(J);
    end;
    Result[J + 1] := LTmp;
  end;
end;

function DriverByNameLocked(const AName: string): IDbDriver;
var
  LIdx: Integer;
begin
  LIdx := FindEntryLocked(AName);
  if LIdx < 0 then
    raise EDbError.CreateSimple(dbkUnknown,
      'db.factory: unknown driver: "' + AName + '"');
  Result := GDrivers[LIdx].Driver;
end;

function DbOpen(const ADriver: string; const ADsn: string;
  const AOptions: TDbConnectOptions): IDbConnection; overload;
var
  LDriver: IDbDriver;
begin
  if ADriver = '' then
    raise EDbError.CreateSimple(dbkUnknown,
      'db.factory: empty driver name');
  GLock.Acquire;
  try
    LDriver := DriverByNameLocked(NormalizeName(ADriver));
  finally
    GLock.Release;
  end;
  { Open 在锁外执行：连接建立可能耗时数秒 }
  Result := LDriver.Open(ADsn, AOptions);
end;

function DbOpen(const ADriver: string; const ADsn: string): IDbConnection;
begin
  Result := DbOpen(ADriver, ADsn, TDbConnectOptions.Default);
end;

function DbOpen(AKind: TDbKind; const ADsn: string;
  const AOptions: TDbConnectOptions): IDbConnection; overload;
var
  I: Integer;
  LDriver: IDbDriver;
begin
  LDriver := nil;
  GLock.Acquire;
  try
    { 先按内建规范名命中，再按第三方声明的 Kind 兜底扫描 }
    case AKind of
      dbkSqlite:   LDriver := DriverByNameLocked('sqlite');
      dbkPostgres: LDriver := DriverByNameLocked('postgres');
      dbkMysql:    LDriver := DriverByNameLocked('mysql');
      dbkOdbc:     LDriver := DriverByNameLocked('odbc');
      dbkRedis:    LDriver := DriverByNameLocked('redis');
    end;
    if LDriver = nil then
      for I := 0 to High(GDrivers) do
        if GDrivers[I].Driver.Kind = AKind then
        begin
          LDriver := GDrivers[I].Driver;
          Break;
        end;
  finally
    GLock.Release;
  end;
  if LDriver = nil then
    raise EDbNotSupported.CreateSimple(dbkUnknown,
      'db.factory: no driver registered for kind');
  Result := LDriver.Open(ADsn, AOptions);
end;

function DbOpenPool(const ADriver: string; const ADsn: string;
  const APolicy: TDbPoolPolicy): TDbPool; overload;
begin
  Result := TDbPool.Create(
    function: IDbConnection
    begin
      Result := DbOpen(ADriver, ADsn, TDbConnectOptions.Default);
    end, APolicy);
end;

function DbOpenPool(AKind: TDbKind; const ADsn: string;
  const APolicy: TDbPoolPolicy): TDbPool; overload;
begin
  Result := TDbPool.Create(
    function: IDbConnection
    begin
      Result := DbOpen(AKind, ADsn, TDbConnectOptions.Default);
    end, APolicy);
end;

{ ---- TBuiltinDriver ---- }

constructor TBuiltinDriver.Create(const AName: string; AKind: TDbKind;
  const AOpen: TDbDriverOpenFunc);
begin
  inherited Create;
  FName := AName;
  FKind := AKind;
  FOpen := AOpen;
end;

function TBuiltinDriver.Name: string;
begin
  Result := FName;
end;

function TBuiltinDriver.Kind: TDbKind;
begin
  Result := FKind;
end;

function TBuiltinDriver.Open(const ADsn: string;
  const AOptions: TDbConnectOptions): IDbConnection;
begin
  Result := FOpen(ADsn, AOptions);
end;

initialization
  GLock := TMutex.Create;
  DbRegisterDriver(TBuiltinDriver.Create('sqlite', dbkSqlite,
    function(const ADsn: string;
      const AOptions: TDbConnectOptions): IDbConnection
    begin
      Result := ConnectSqlite(ADsn, AOptions);
    end));
  DbRegisterDriver(TBuiltinDriver.Create('postgres', dbkPostgres,
    function(const ADsn: string;
      const AOptions: TDbConnectOptions): IDbConnection
    begin
      Result := ConnectPostgres(ADsn, AOptions);
    end));
  DbRegisterDriver(TBuiltinDriver.Create('mysql', dbkMysql,
    function(const ADsn: string;
      const AOptions: TDbConnectOptions): IDbConnection
    begin
      Result := ConnectMysql(ADsn, AOptions);
    end));
  DbRegisterDriver(TBuiltinDriver.Create('odbc', dbkOdbc,
    function(const ADsn: string;
      const AOptions: TDbConnectOptions): IDbConnection
    begin
      Result := ConnectOdbc(ADsn, AOptions);
    end));
  DbRegisterDriver(TBuiltinDriver.Create('redis', dbkRedis,
    function(const ADsn: string;
      const AOptions: TDbConnectOptions): IDbConnection
    begin
      Result := ConnectRedis(ADsn, '', 0, AOptions);
    end));

finalization
  GDrivers := nil;
  GLock := nil;

end.
