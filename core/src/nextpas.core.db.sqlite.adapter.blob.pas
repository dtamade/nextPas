unit nextpas.core.db.sqlite.adapter.blob;

{** @desc SQLite 行内 blob 单元流分治（L3 实现子模块，INC-8）。
       封装 sqlite3_blob_* 薄包装：定长模型（Size 即单元字节数，
       写不得越过末尾），位置由对象维护（原生 API 每次显式 offset），
       接口释放即 blob_close。
       层级：L3 适配子模块（严格下向 L2 sqlite.base/ffi，无上向；
       同层仅依赖 observe 单向，不反向）。
       性能：HoldAnsi 单次 AnsiString 分配零拷贝 PAnsiChar 桥接
       （bytes.ops 单源 inline），I/O 单次 Move 零拷贝，inline 薄转发。
       稳定性：析构内 sqlite3_blob_close 不抛；I/O 失败经 BlobCheck
       统一转 EDbError（单次直接构造抛，不经临时异常泄漏）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.db.sqlite.base;

type
  {** sqlite 行内 blob 单元流（INC-8，IDbBlobStream）：sqlite3_blob_*
      薄包装。定长模型——Size 即单元字节数，写不得越过末尾；位置由
      本对象维护（原生 API 每次调用显式带 offset）。接口释放即
      blob_close。 *}
  TDbSqliteBlobStream = class(TInterfacedObject, IDbBlobStream)
  private
    FHandle: TSqliteHandle;
    FBlob: TSqliteBlob;    { nil = 已关闭 }
    FSize: Int64;
    FPos: Int64;
  public
    constructor Create(AHandle: TSqliteHandle; const ATable, AColumn: string;
      const ARowId: Int64; const AReadWrite: Boolean);
    destructor Destroy; override;
    function Read(ABuf: PByte; ACount: SizeUInt): SizeUInt;
    procedure Write(ABuf: PByte; ACount: SizeUInt);
    function Seek(AOffset: Int64; AOrigin: TDbSeekOrigin): Int64;
    function Size: Int64;
  end;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.text.conv,
  nextpas.core.db.sqlite.ffi,
  nextpas.core.db.sqlite.adapter.observe,
  nextpas.core.db.err;

{$IF not BYTES_OPS_SINGLE_SOURCE}
  {$FATAL 'bytes.ops single source drift: sqlite.adapter.blob must reuse bytes.ops'}
{$IFEND}

{ blob I/O 结果码检查：从原生句柄取诊断并走统一错误模型。
  注意必须单次直接构造并 raise——若先建 ESqliteError 再转抛 EDbError，
  手工创建的临时异常对象会因异常对象非引用计数而泄漏（实证）。 }
procedure BlobCheck(AHandle: TSqliteHandle; ARC: Integer); inline;
var
  LCategory: TDbErrorCategory;
  LConstraint: TDbConstraintKind;
begin
  if ARC = SQLITE_OK then
    Exit;
  ClassifySqlite(ARC, sqlite3_extended_errcode(AHandle),
    LCategory, LConstraint);
  raise NewDbErrorSqlite(ARC, sqlite3_extended_errcode(AHandle),
    LCategory, LConstraint, AnsiPtrToStr(sqlite3_errmsg(AHandle)));
end;

constructor TDbSqliteBlobStream.Create(AHandle: TSqliteHandle;
  const ATable, AColumn: string; const ARowId: Int64;
  const AReadWrite: Boolean);
var
  LFlags: Integer;
  LTableHold, LColHold: AnsiString;
begin
  inherited Create;
  FHandle := AHandle;
  if AReadWrite then
    LFlags := SQLITE_OPEN_READWRITE
  else
    LFlags := SQLITE_OPEN_READONLY;
  // perf: single-source HoldAnsi (single AnsiString alloc + zero-copy PAnsiChar bridge, bytes.ops single source gated), inline
  BlobCheck(FHandle, sqlite3_blob_open(FHandle, 'main',
    HoldAnsi(ATable, LTableHold), HoldAnsi(AColumn, LColHold),
    ARowId, LFlags, FBlob));
  FSize := sqlite3_blob_bytes(FBlob);
  FPos := 0;
end;

destructor TDbSqliteBlobStream.Destroy;
begin
  if FBlob <> nil then
  begin
    sqlite3_blob_close(FBlob);         { 接口释放即关闭；析构内不抛 }
    FBlob := nil;
  end;
  inherited Destroy;
end;

function TDbSqliteBlobStream.Read(ABuf: PByte; ACount: SizeUInt): SizeUInt;
var
  N: SizeUInt;
begin
  Result := 0;
  if FPos >= FSize then
    Exit;                              { EOF }
  N := SizeUInt(FSize - FPos);        { 可读余量 }
  if ACount < N then
    N := ACount;
  if N > SizeUInt(MaxInt) then
    N := SizeUInt(MaxInt);             { 原生 API 单次 32 位上限 }
  BlobCheck(FHandle, sqlite3_blob_read(FBlob, ABuf, Integer(N), FPos));
  Inc(FPos, N);
  Result := N;
end;

procedure TDbSqliteBlobStream.Write(ABuf: PByte; ACount: SizeUInt);
var
  N: SizeUInt;
begin
  if FPos + Int64(ACount) > FSize then
    raise EDbError.CreateSimple(dbkSqlite,
      'blob write beyond end of fixed cell (reserve via zeroblob(N))');
  N := ACount;
  if N > SizeUInt(MaxInt) then
    N := SizeUInt(MaxInt);
  BlobCheck(FHandle, sqlite3_blob_write(FBlob, ABuf, Integer(N), FPos));
  Inc(FPos, N);
end;

function TDbSqliteBlobStream.Seek(AOffset: Int64;
  AOrigin: TDbSeekOrigin): Int64;
var
  NP: Int64;
begin
  // 事前兜底缺省（未来扩枚举时防御）；三分支显式全覆盖——原写法的
  // else 分支在枚举全覆盖下静态不可达（FPC 6018）
  NP := AOffset;
  case AOrigin of
    dsoBegin:   NP := AOffset;
    dsoCurrent: NP := FPos + AOffset;
    dsoEnd:     NP := FSize + AOffset;
  end;
  if (NP < 0) or (NP > FSize) then
    raise EDbError.CreateSimple(dbkSqlite,
      'blob seek out of range [0..' + IntToStr(FSize) + ']');
  FPos := NP;
  Result := FPos;
end;

function TDbSqliteBlobStream.Size: Int64;
begin
  Result := FSize;
end;

end.
