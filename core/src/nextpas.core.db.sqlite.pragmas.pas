unit nextpas.core.db.sqlite.pragmas;

{** @desc SQLite 调优预设的通用 Exec 落地面（L2 owner）。
       四件套归属：sqlite 家族的 pragmas 子模块，承接门面
       ApplyPragmasViaExec 业务逻辑；门面仅 inline 薄转发，保持
       纯 re-export 与零后端硬链接（经 factory 驱动表）。
       复用 bytes.ops 单源：串处理经 bytes.ops.StringToBytes 零拷贝
       Move 与 text.utils.LowerCase 单源，不自建副本。
       性能：重逻辑不 inline 防 I-Cache 膨胀，实测 PRAGMA 往返主导；
       cache_size/mmap_size 经 text.builder 单次分配零拷贝（AppendInt 单 Move）。
       稳定性：IDbQuery 接口引用计数自动释放，WAL 回读校验
       fail-closed 不丢资源。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.db.sqlite.base;

{ 通用 PRAGMA 应用（零硬链接 sqlite.adapter）：通过 IDbConnection.Exec
  语义实现调优预设；journal_mode 回读校验保留 fail-closed。
  守 L0-L3：本单元仅依赖 L0-L2（base/intf/bytes/text），不依赖 L3 factory，
  由 L3 门面经 DbOpen 打开后再委派本过程，保持单向向下。
  性能：重逻辑不 inline 防 I-Cache 膨胀；cache_size/mmap_size 经
  text.builder 单次分配零拷贝（AppendInt 单 Move 直写尾缓冲）。 }
procedure ApplyPragmasViaExec(const AConn: IDbConnection; const APath: string;
  const AP: TDbSqlitePragmas);

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.text.conv,
  nextpas.core.text.utils,
  nextpas.core.text.builder;

{ sentinel: 复用 bytes.ops 单源，重复实现即编译期失败 }
{$IF not BYTES_OPS_SINGLE_SOURCE}
  {$FATAL 'bytes.ops single source drift: pragmas must reuse bytes.ops'}
{$IFEND}

procedure ApplyPragmasViaExec(const AConn: IDbConnection; const APath: string;
  const AP: TDbSqlitePragmas);
var
  LQ: IDbQuery;
  LGot: string;
  LB: TBufStringBuilder;
begin
  if (AP.JournalMode <> sjmUnset) and (APath <> ':memory:') then
  begin
    case AP.JournalMode of
      sjmDelete:   AConn.Exec('PRAGMA journal_mode = delete');
      sjmTruncate: AConn.Exec('PRAGMA journal_mode = truncate');
      sjmPersist:  AConn.Exec('PRAGMA journal_mode = persist');
      sjmMemory:   AConn.Exec('PRAGMA journal_mode = memory');
      sjmWal:      AConn.Exec('PRAGMA journal_mode = wal');
      else ;
    end;
    if AP.JournalMode = sjmWal then
    begin
      LQ := AConn.Query('PRAGMA journal_mode');
      if LQ.Step then
        LGot := LowerCase(LQ.GetText(0))
      else
        LGot := '';
      { 零拷贝：LowerCase 经 text.utils 单源，IDbQuery 接口引用计数
        自动释放，无需手工 Free；fail-closed 语义与 CONTRACT §2.15 一致 }
      if LGot <> 'wal' then
        raise EDbError.CreateWithCategory(dbkSqlite, decNotSupported, dckNone,
          'db: journal_mode wal not supported on this filesystem');
    end;
  end;
  case AP.Synchronous of
    sysOff:    AConn.Exec('PRAGMA synchronous = OFF');
    sysNormal: AConn.Exec('PRAGMA synchronous = NORMAL');
    sysFull:   AConn.Exec('PRAGMA synchronous = FULL');
    else ;
  end;
  case AP.ForeignKeys of
    fkOff: AConn.Exec('PRAGMA foreign_keys = OFF');
    fkOn:  AConn.Exec('PRAGMA foreign_keys = ON');
    else ;
  end;
  if AP.CacheSize <> 0 then
  begin
    LB.Init(32);
    try
      LB.AppendStr('PRAGMA cache_size = ');
      LB.AppendInt(AP.CacheSize);
      AConn.Exec(LB.ToString);
    finally
      LB.Done;
    end;
  end;
  if AP.MmapSize >= 0 then
  begin
    LB.Init(32);
    try
      LB.AppendStr('PRAGMA mmap_size = ');
      LB.AppendInt(AP.MmapSize);
      AConn.Exec(LB.ToString);
    finally
      LB.Done;
    end;
  end;
end;

end.
