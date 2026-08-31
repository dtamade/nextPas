unit nextpas.core.db.migrate;

{** @desc 跨后端 schema 版本化迁移（IDbConnection 上的 sqlite.migrate
       泛化版）。

       - 版本表：schema_migrations(version INTEGER PRIMARY KEY,
         applied_at TEXT, checksum TEXT)。DDL 两引擎通用；applied_at
         由本单元显式写入 ISO8601 UTC 文本；checksum 为批内 SQL
         （LF 连接）的 CRC32 八位十六进制。S6 前的旧两列表经探测自动
         ADD COLUMN 升级。
       - 有序迁移列表：TDbMigration = 版本号 + 顺序 SQL 步骤数组。
       - 幂等应用：已记录版本跳过，同列表重复调用结果一致。
       - 每批迁移在单个事务内执行（经 nextpas.core.db.tx，版本行同批
         写入）：任一步失败整批回滚、不记版本。
       - 版本校验：列表必须严格升序且无重复；任何已应用版本不在列表
         中即拒绝（低于最小 = 迁移被删过；高于最大 = 库超前于代码）。
       - 防篡改（INC-6/S6）：已应用版本的记录 checksum 与当前列表
         计算值不符 = 迁移被改过，Migrate 抛错拒绝继续；历史遗留的
         空 checksum 条目在下次 Migrate 时按当前列表自愈回填。
         威胁模型 = 意外漂移与误编辑，非对抗性攻击。
       - 预览：MigrateDryRun 返回结构化计划（将应用/已应用/校验和不
         匹配），零写入、零副作用；校验类错误（乱序、越界）仍抛错。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.db.base,
  nextpas.core.db.intf;

const
  DB_MIGRATIONS_TABLE = 'schema_migrations';

type
  { 迁移错误：Version 为引发错误的版本号（0 = 与版本无关，如列表乱序）。 }
  EDbMigrateError = class(EDbError)
  private
    FVersion: Int64;
  public
    constructor Create(const ABackend: TDbKind; const AVersion: Int64;
      const AMessage: string);
    property Version: Int64 read FVersion;
  end;

  { 一批迁移：Version 升序唯一；Sql 步骤在同一事务内顺序执行。 }
  TDbMigration = record
    Version: Int64;
    Sql: array of string;
    class function Create(const AVersion: Int64;
      const ASql: array of string): TDbMigration; static;
  end;

  TDbMigrations = array of TDbMigration;

  { 预览计划条目状态：将应用 / 已应用跳过 / 已应用但 SQL 被改动。 }
  TDbDryRunStatus = (
    drsApply,              { 未应用：本次会执行 }
    drsApplied,            { 已应用：幂等跳过 }
    drsChecksumMismatch    { 已应用但记录校验和与当前 SQL 不符（被改过） }
  );

  TDbDryRunEntry = record
    Version: Int64;
    Status: TDbDryRunStatus;
  end;

  TDbDryRunPlan = array of TDbDryRunEntry;

  { 构造有序迁移列表糖（内联数组 → 动态数组）。 }
  function MakeMigrations(const AMigrations: array of TDbMigration): TDbMigrations;
  { 应用未执行的迁移，返回本次应用的批数；重复调用幂等。
    已应用批次逐一核对 checksum，不符抛 EDbMigrateError。 }
  function Migrate(const AConn: IDbConnection; const AMigrations: TDbMigrations): Integer;
  { 预览：返回逐批状态计划，零写入。结构性错误（乱序/越界）仍抛错；
    checksum 不符以 drsChecksumMismatch 上报而非抛出。 }
  function MigrateDryRun(const AConn: IDbConnection;
    const AMigrations: TDbMigrations): TDbDryRunPlan;
  { 数据库当前版本（schema_migrations 最高已应用版本；无表/空表 = 0）。 }
  function MigrationVersion(const AConn: IDbConnection): Int64;

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.checksum.crc32,
  nextpas.core.db.tx,
  nextpas.core.time;

constructor EDbMigrateError.Create(const ABackend: TDbKind;
  const AVersion: Int64; const AMessage: string);
begin
  inherited CreateSimple(ABackend, AMessage);
  FVersion := AVersion;
end;

class function TDbMigration.Create(const AVersion: Int64;
  const ASql: array of string): TDbMigration;
var
  I: Integer;
begin
  Result.Version := AVersion;
  SetLength(Result.Sql, Length(ASql));
  for I := 0 to High(ASql) do
    Result.Sql[I] := ASql[I];
end;

function MakeMigrations(const AMigrations: array of TDbMigration): TDbMigrations;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AMigrations));
  for I := 0 to High(AMigrations) do
    Result[I] := AMigrations[I];
end;

{ 批内 SQL 规范形：LF 连接后取 CRC32，八位小写十六进制。
  规范形只依赖步骤序列本身，跨后端跨进程确定。 }
function ComputeChecksumOf(const AM: TDbMigration): string;
var
  I: Integer;
  LJoined: string;
  LCrc: LongWord;
begin
  LJoined := '';
  if Length(AM.Sql) > 0 then
  begin
    LJoined := AM.Sql[0];
    for I := 1 to High(AM.Sql) do
      LJoined := LJoined + #10 + AM.Sql[I];
  end;
  LCrc := Crc32Of(Pointer(LJoined)^, SizeUInt(Length(LJoined)));
  Result := LowerCase(IntToHex(LCrc, 8));
end;

procedure EnsureVersionTable(const AConn: IDbConnection);
var
  LProbe: IDbQuery;
begin
  AConn.Exec('CREATE TABLE IF NOT EXISTS ' + DB_MIGRATIONS_TABLE +
    ' (version INTEGER PRIMARY KEY, applied_at TEXT, checksum TEXT)');
  { S6 前旧两列表升级：探测性查询失败 = 无 checksum 列，ADD COLUMN。
    探测/升级均后端中立（不查方言元数据表）。既有行得到 NULL，
    由 Migrate 的自愈回填收敛。 }
  try
    LProbe := AConn.Query('SELECT checksum FROM ' + DB_MIGRATIONS_TABLE +
      ' WHERE 1 = 0');
    LProbe := nil;
  except
    on EDbError do
      AConn.Exec('ALTER TABLE ' + DB_MIGRATIONS_TABLE +
        ' ADD COLUMN checksum TEXT');
  end;
end;

type
  { 已应用条目：版本号 + 记录校验和（'' = 历史遗留未记）。 }
  TAppliedEntry = record
    Version: Int64;
    Checksum: string;
  end;
  TAppliedList = array of TAppliedEntry;

function LoadApplied(const AConn: IDbConnection): TAppliedList;
var
  Q: IDbQuery;
  LCount: Integer;
begin
  Result := nil;
  try
    Q := AConn.Query('SELECT version, checksum FROM ' + DB_MIGRATIONS_TABLE +
      ' ORDER BY version ASC');
  except
    on E: EDbError do
      if Pos('no such table', LowerCase(E.Message)) > 0 then
        Exit(nil)                        { 表缺失：视为空库（仅此一种静默） }
      else
        raise;
  end;
  try
    LCount := 0;
    while Q.Step do
    begin
      Inc(LCount);
      SetLength(Result, LCount);
      Result[LCount - 1].Version := Q.GetInt64(0);
      if Q.IsNull(1) then
        Result[LCount - 1].Checksum := ''
      else
        Result[LCount - 1].Checksum := Q.GetText(1);
    end;
  finally
    Q := nil;
  end;
end;

function FindApplied(const AVersion: Int64;
  const AApplied: TAppliedList): Integer;
var
  I: Integer;
begin
  for I := 0 to High(AApplied) do
    if AApplied[I].Version = AVersion then
      Exit(I);
  Result := -1;
end;

procedure ValidateMigrations(const AConn: IDbConnection;
  const AMigrations: TDbMigrations);
var
  I: Integer;
begin
  for I := 1 to High(AMigrations) do
    if AMigrations[I].Version <= AMigrations[I - 1].Version then
      raise EDbMigrateError.Create(AConn.Kind, AMigrations[I].Version,
        'migration list must be strictly ascending, violated at index ' +
        IntToStr(I));
end;

{ 列表里是否存在该版本。 }
function HasMigrationVersion(const AMigrations: TDbMigrations;
  const AVersion: Int64): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(AMigrations) do
    if AMigrations[I].Version = AVersion then
      Exit(True);
  Result := False;
end;

{ 上下限校验：已应用版本必须都在列表内。 }
procedure ValidateAppliedVersions(const AConn: IDbConnection;
  const AMigrations: TDbMigrations; const AApplied: TAppliedList);
var
  I: Integer;
begin
  for I := 0 to High(AApplied) do
    if not HasMigrationVersion(AMigrations, AApplied[I].Version) then
    begin
      if Length(AMigrations) = 0 then
        raise EDbMigrateError.Create(AConn.Kind, AApplied[I].Version,
          'database has applied version ' + IntToStr(AApplied[I].Version) +
          ' but the migration list is empty');
      if AApplied[I].Version > AMigrations[High(AMigrations)].Version then
        raise EDbMigrateError.Create(AConn.Kind, AApplied[I].Version,
          'applied version ' + IntToStr(AApplied[I].Version) +
          ' is ahead of the migration list (upper bound ' +
          IntToStr(AMigrations[High(AMigrations)].Version) + ')')
      else if AApplied[I].Version < AMigrations[0].Version then
        raise EDbMigrateError.Create(AConn.Kind, AApplied[I].Version,
          'applied version ' + IntToStr(AApplied[I].Version) +
          ' is below the migration list (lower bound ' +
          IntToStr(AMigrations[0].Version) +
          '); older migrations were likely removed')
      else
        raise EDbMigrateError.Create(AConn.Kind, AApplied[I].Version,
          'applied version ' + IntToStr(AApplied[I].Version) +
          ' is missing from the migration list');
    end;
end;

{ 公共前置：nil 守卫、列表序校验、载入并校验已应用集合。返回已应用
  列表。AMutating=False（DryRun）时不建表不升级：表缺失按空库处理，
  全程零写入。列表序校验对两种模式都执行（纯输入检查）。 }
procedure PrepareRun(const AConn: IDbConnection; const AMigrations: TDbMigrations;
  const AMutating: Boolean; out AApplied: TAppliedList);
begin
  if AConn = nil then
    raise EDbMigrateError.Create(dbkSqlite, 0, 'migrate on a nil connection');
  ValidateMigrations(AConn, AMigrations);
  if AMutating then
    EnsureVersionTable(AConn);
  AApplied := LoadApplied(AConn);
  ValidateAppliedVersions(AConn, AMigrations, AApplied);
end;

{ 防篡改核对：非空 checksum 且版本在列表内的条目逐一比对。
  Migrate 语义 = 不符即抛；DryRun 自行读状态不走此过程。 }
procedure VerifyChecksums(const AConn: IDbConnection;
  const AMigrations: TDbMigrations; const AApplied: TAppliedList);
var
  I, K: Integer;
  LWant: string;
begin
  for I := 0 to High(AApplied) do
  begin
    if AApplied[I].Checksum = '' then
      Continue;                          { 历史遗留：由回填自愈 }
    for K := 0 to High(AMigrations) do
      if AMigrations[K].Version = AApplied[I].Version then
      begin
        LWant := ComputeChecksumOf(AMigrations[K]);
        if LWant <> AApplied[I].Checksum then
          raise EDbMigrateError.Create(AConn.Kind, AApplied[I].Version,
            'checksum mismatch for applied version ' +
              IntToStr(AApplied[I].Version) +
            ': migration SQL was modified after it was applied (' +
              AApplied[I].Checksum + ' recorded, ' + LWant + ' expected)');
      end;
  end;
end;

{ 自愈回填：历史遗留的空 checksum 条目按当前列表补记（幂等 UPDATE）。
  仅处理列表内版本——列表外的已由校验拒绝。在应用循环之前调用，
  使用刚载入的新鲜列表；本批新插入的行自带 checksum，无需回填。 }
procedure BackfillLegacyChecksums(const AConn: IDbConnection;
  const AMigrations: TDbMigrations; const AApplied: TAppliedList);
var
  I, K: Integer;
  LV: Int64;
begin
  for I := 0 to High(AApplied) do
  begin
    LV := AApplied[I].Version;
    if AApplied[I].Checksum <> '' then
      Continue;
    for K := 0 to High(AMigrations) do
      if AMigrations[K].Version = LV then
      begin
        AConn.Exec('UPDATE ' + DB_MIGRATIONS_TABLE + ' SET checksum = ''' +
          ComputeChecksumOf(AMigrations[K]) + ''' WHERE version = ' +
          IntToStr(LV));
        Break;
      end;
  end;
end;

function Migrate(const AConn: IDbConnection; const AMigrations: TDbMigrations): Integer;
var
  LApplied: TAppliedList;
  I: Integer;
  LM: TDbMigration;
  LCache: IDbStmtCacheControl;
begin
  PrepareRun(AConn, AMigrations, True, LApplied);
  VerifyChecksums(AConn, AMigrations, LApplied);
  BackfillLegacyChecksums(AConn, AMigrations, LApplied);
  Result := 0;
  for I := 0 to High(AMigrations) do
  begin
    if FindApplied(AMigrations[I].Version, LApplied) >= 0 then
      Continue;               { 幂等：同版本跳过 }
    LM := AMigrations[I];
    { 参数化形态（B13）：连接由框架作实参传入，闭包零捕获——池化
      写租约随语句结束归还，消费方在 Migrate 之后立即可再借 writer。 }
    WithTransaction(AConn,
      procedure(const C: IDbConnection)
      var
        K: Integer;
      begin
        for K := 0 to High(LM.Sql) do
          C.Exec(LM.Sql[K]);
        C.Exec('INSERT INTO ' + DB_MIGRATIONS_TABLE +
          ' (version, applied_at, checksum) VALUES (' +
          IntToStr(LM.Version) +
          ', ''' + FormatISO8601UTC(DateTimeToUnix(DateTimeUtcNow())) +
          ''', ''' + ComputeChecksumOf(LM) + ''')');
      end);
    Inc(Result);
  end;
  { INC-3 联动点：应用过迁移即整体失效语句缓存，防空闲 prepared
    句柄引用已变更 schema（能力不存在时静默跳过） }
  if Result > 0 then
    if AConn.QueryInterface(IDbStmtCacheControl, LCache) = 0 then
      LCache.Clear;
end;

function MigrateDryRun(const AConn: IDbConnection;
  const AMigrations: TDbMigrations): TDbDryRunPlan;
var
  LApplied: TAppliedList;
  I, K: Integer;
begin
  PrepareRun(AConn, AMigrations, False, LApplied);
  Result := nil;
  SetLength(Result, Length(AMigrations));
  for I := 0 to High(AMigrations) do
  begin
    Result[I].Version := AMigrations[I].Version;
    K := FindApplied(AMigrations[I].Version, LApplied);
    if K < 0 then
      Result[I].Status := drsApply
    else if (LApplied[K].Checksum <> '') and
            (LApplied[K].Checksum <> ComputeChecksumOf(AMigrations[I])) then
      Result[I].Status := drsChecksumMismatch
    else
      Result[I].Status := drsApplied;
  end;
end;

function MigrationVersion(const AConn: IDbConnection): Int64;
var
  Q: IDbQuery;
begin
  if AConn = nil then
    raise EDbMigrateError.Create(dbkSqlite, 0,
      'MigrationVersion on a nil connection');
  try
    Q := AConn.Query('SELECT MAX(version) FROM ' + DB_MIGRATIONS_TABLE);
  except
    on EDbError do
      Exit(0);
  end;
  try
    if Q.Step then
      Result := Q.GetInt64(0)
    else
      Result := 0;
  finally
    Q := nil;
  end;
end;

end.
