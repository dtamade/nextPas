unit nextpas.core.db.sqlite.adapter.pragmas;

{** @desc SQLite 适配器调优 PRAGMA 分治（L3 实现子模块，C5）。
       封装 journal_mode/synchronous/foreign_keys/cache_size/mmap_size
       的受控应用与 unset 形态：零分散、单源复用 bytes.ops 单次 Move
       零拷贝（TBufStringBuilder 单分配，Hold/AppendInt 路径），回读
       校验 fail-closed 绝不静默降级。
       层级：L3 适配子模块（严格下向 L2 sqlite.conn/base + L1
       text.builder/bytes.ops，单向被 adapter 依赖，无环）。
       性能：TBufStringBuilder 单次分配单 Move 零拷贝，AppendInt 单
       次格式化零临时串，inline 薄转发，BYTES_OPS_SINGLE_SOURCE 门禁。
       稳定性：try..finally LB.Done 归还，LQ.Free 不丢，校验抛
       decNotSupported fail-closed。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.sqlite.base,
  nextpas.core.db.sqlite.conn;

function SqlitePragmasUnset: TDbSqlitePragmas; inline;

{ C5：应用调优 PRAGMA（:memory: 过滤 journal_mode，回读校验 fail-closed） }
procedure ApplySqlitePragmas(Db: TSqliteDb; const APath: string;
  const AP: TDbSqlitePragmas);

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.text.conv,
  nextpas.core.text.scan,
  nextpas.core.text.builder,
  nextpas.core.db.base,
  nextpas.core.db.err,
  nextpas.core.db.sqlite.ffi;


function SqlitePragmasUnset: TDbSqlitePragmas; inline;
begin
  Result.JournalMode := sjmUnset;
  Result.Synchronous := sysUnset;
  Result.ForeignKeys := fkUnset;
  Result.CacheSize := 0;
  Result.MmapSize := -1;
end;

procedure ApplySqlitePragmas(Db: TSqliteDb; const APath: string;
  const AP: TDbSqlitePragmas);
const
  JStr: array[TDbSqliteJournalMode] of string = ('', 'delete', 'truncate',
    'persist', 'memory', 'wal');
  SStr: array[TDbSqliteSync] of string = ('', 'off', 'normal', 'full');
var
  LMem: Boolean;
  LQ: TSqliteQuery;
  LGot: string;
  LB: TBufStringBuilder;
begin
  // perf: 统一 TBufStringBuilder 单次分配单 Move 零拷贝（预估经统一辅助 TBufEstimateForTwo/BuilderCapWithMin 单源，bytes.ops 单源 inline/零拷贝，消除分散手写 32+value），bytes.ops 单源 inline/零拷贝；stability: try..finally LB.Done/LQ.Free 不丢，校验 fail-closed
  LMem := (APath = ':memory:') or
    (ScanFindSubstringCI(PChar(APath), Length(APath),
      'mode=memory', 11) >= 0);
  if (AP.JournalMode <> sjmUnset) and (not LMem) then
  begin
    LB.Init(TBufEstimateForTwo(SizeUInt(Length('PRAGMA journal_mode = ')), SizeUInt(Length(JStr[AP.JournalMode]))));
    try
      LB.AppendStr('PRAGMA journal_mode = ');
      LB.AppendStr(JStr[AP.JournalMode]);
      Db.Exec(LB.ToString);
    finally
      LB.Done;
    end;
    LGot := '';
    LQ := Db.Query('PRAGMA journal_mode');
    try
      if LQ.Step then
        LGot := LowerCase(LQ.GetText(0));
    finally
      LQ.Free;
    end;
    if LGot <> JStr[AP.JournalMode] then
      raise NewDbErrorSqlite(SQLITE_ERROR, SQLITE_ERROR,
        decNotSupported, dckNone,
        'sqlite journal_mode=' + JStr[AP.JournalMode] +
        ' rejected (got "' + LGot + '"); filesystem may not support WAL');
  end;
  case AP.Synchronous of
    sysOff, sysNormal, sysFull:
      begin
        LB.Init(TBufEstimateForTwo(SizeUInt(Length('PRAGMA synchronous = ')), SizeUInt(Length(SStr[AP.Synchronous]))));
        try
          LB.AppendStr('PRAGMA synchronous = ');
          LB.AppendStr(SStr[AP.Synchronous]);
          Db.Exec(LB.ToString);
        finally
          LB.Done;
        end;
      end;
  end;
  case AP.ForeignKeys of
    fkOff: Db.Exec('PRAGMA foreign_keys = off');
    fkOn:  Db.Exec('PRAGMA foreign_keys = on');
  end;
  if AP.CacheSize <> 0 then
  begin
    LB.Init(BuilderCapWithMin(BuilderCapForTwo(SizeUInt(Length('PRAGMA cache_size = ')), 12)));
    try
      LB.AppendStr('PRAGMA cache_size = ');
      LB.AppendInt(AP.CacheSize);
      Db.Exec(LB.ToString);
    finally
      LB.Done;
    end;
  end;
  if AP.MmapSize >= 0 then
  begin
    LB.Init(BuilderCapWithMin(BuilderCapForTwo(SizeUInt(Length('PRAGMA mmap_size = ')), 21)));
    try
      LB.AppendStr('PRAGMA mmap_size = ');
      LB.AppendInt(AP.MmapSize);
      Db.Exec(LB.ToString);
    finally
      LB.Done;
    end;
  end;
end;

end.
