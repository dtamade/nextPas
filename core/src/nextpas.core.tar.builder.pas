unit nextpas.core.tar.builder;
{**
 * @desc Tar 链式构造器：薄门面委托 TTarWriter + archive.fs 联邦单缝。
 *  需显式 Finish（两零块）；未 Finish 析构 fail-closed（IsFinished 单源）。
 *  联邦/容量/性能/稳定性详见 CONTRACT §1.4/§3，源码仅保留单缝与单源证据。
 *  收敛：流式 AddEntryFromReader 已收敛至实现层 ITarStreamBuilder（L2→L1 单向，
 *  intf 保持纯 base←intf），复用 bytes.ops 单源 inline 零拷贝 + 64K pooled FIOBuf。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.tar.base,
  nextpas.core.tar.intf,
  nextpas.core.tar.writer;

function TarBuilder: ITarBuilder; inline;
function TarBuilderWithCapacity(const AEstimatedTotal: SizeUInt): ITarBuilder; inline;

type
  {** @desc 流式扩展：实现层承接 L1 IReader，intf 保持纯数据最小依赖。 *}
  ITarStreamBuilder = interface(ITarBuilder)
    ['{B2C3D4E5-F6A7-8901-BCDE-222222222223}']
    function AddEntryFromReader(const AHdr: TTarHeader; const AReader: IReader): ITarBuilder;
  end;

function AsStreamBuilder(const ABuilder: ITarBuilder): ITarStreamBuilder; inline;
function TarBuilderAddFromReader(const ABuilder: ITarBuilder; const AHdr: TTarHeader; const AReader: IReader): ITarBuilder; inline;

implementation

uses
  nextpas.core.exception,
  nextpas.core.archive.fs, // 联邦单缝：唯一入口 archive.fs（bytes.builder 几何扩容与 bytes.ops 单源 inline 零拷贝经 archive.fs 透出）
  nextpas.core.log.intf;

type
  TTarBuilder = class(TInterfacedObject, ITarBuilder, ITarStreamBuilder)
  private
    FBuilder: IArchiveBuilder; // 联邦单源直写切片，bytes.builder 几何扩容单源 inline 零拷贝
    FWriter: TTarWriter; // 薄委托唯一写器，持有 Sink 单缝，IsFinished 单源
  public
    constructor Create; overload;
    constructor CreateWithCapacity(const AEstimatedTotal: SizeUInt); overload;
    destructor Destroy; override;
    function Add(const AName: string; const AData: TBytes): ITarBuilder; inline;
    function AddWithOptions(const AName: string; const AData: TBytes; const AOpts: TTarAddOptions): ITarBuilder; inline;
    function AddDirectory(const AName: string): ITarBuilder; inline;
    function AddDirectoryWithOptions(const AName: string; const AOpts: TTarAddOptions): ITarBuilder; inline;
    function AddEntry(const AHdr: TTarHeader; const AData: TBytes): ITarBuilder; inline;
    function AddEntryFromReader(const AHdr: TTarHeader; const AReader: IReader): ITarBuilder; inline;
    function Finish: TBytes; inline;
  end;

constructor TTarBuilder.Create;
var LSink: IWriter;
begin
  inherited Create;
  // perf: TarBuilderCapacityFor 4K 对齐预扩容，CreateArchiveBuilder 经 archive.fs 联邦透出 bytes.builder 单源 inline 零拷贝（bytes.ops Move）；LSink 局域经 FWriter 单缝持有
  CreateArchiveBuilder(TarBuilderCapacityFor(0), FBuilder, LSink);
  FWriter := TTarWriter.Create(LSink);
end;

constructor TTarBuilder.CreateWithCapacity(const AEstimatedTotal: SizeUInt);
var LCap: SizeUInt; LSink: IWriter;
begin
  inherited Create;
  // perf: TarBuilderCapacityFor 按预估量 4K 对齐，复用 bytes.builder 单源 inline 零拷贝（AppendBytes 单次 Move via bytes.ops）
  LCap := TarBuilderCapacityFor(AEstimatedTotal);
  CreateArchiveBuilder(LCap, FBuilder, LSink);
  FWriter := TTarWriter.Create(LSink);
end;

destructor TTarBuilder.Destroy;
var
  LUnwinding: Boolean;
begin
  // fail-closed 单源 IsFinished；非 unwind 硬失败防截断，unwind 经 log.intf Warn 可观测并抑制次生；try..finally 必释 FWriter
  LUnwinding := IsExceptionUnwinding;
  try
    if (FWriter <> nil) and (not FWriter.IsFinished) then
    begin
      if not LUnwinding then
        raise EInvalidOperationError.Create('tar: builder destroyed without Finish (missing two zero blocks, data truncated)');
      NullLogger.Warn('tar: builder destroyed without Finish (missing two zero blocks, data truncated)');
    end;
  finally
    FWriter.Free;
    inherited Destroy;
  end;
end;

function TTarBuilder.Add(const AName: string; const AData: TBytes): ITarBuilder; inline;
begin
  FWriter.AddFile(AName, AData);
  Result := Self;
end;

function TTarBuilder.AddWithOptions(const AName: string; const AData: TBytes; const AOpts: TTarAddOptions): ITarBuilder; inline;
begin
  FWriter.AddEntryWithOptions(AName, AData, AOpts);
  Result := Self;
end;

function TTarBuilder.AddDirectory(const AName: string): ITarBuilder; inline;
begin
  // 薄门面：复用 writer.AddDir 单源，无重复 H 组装
  FWriter.AddDir(AName);
  Result := Self;
end;

function TTarBuilder.AddDirectoryWithOptions(const AName: string; const AOpts: TTarAddOptions): ITarBuilder; inline;
begin
  // 薄门面：复用 writer.AddDirWithOptions 单源，内部复用 DefaultTarAddOptions/TarDirectoryMode，无重复 H/C_TAR_DEFAULT_DIR_MODE 手写
  FWriter.AddDirWithOptions(AName, AOpts);
  Result := Self;
end;

function TTarBuilder.AddEntry(const AHdr: TTarHeader; const AData: TBytes): ITarBuilder; inline;
begin
  FWriter.AddEntry(AHdr, AData);
  Result := Self;
end;

function TTarBuilder.AddEntryFromReader(const AHdr: TTarHeader; const AReader: IReader): ITarBuilder; inline;
begin
  // 流式零拷贝：64K pooled 复用缓冲分块 Move 单源 bytes.ops，无 TBytes 全量拷贝，委托 writer 单源
  FWriter.AddEntryFromReader(AHdr, AReader);
  Result := Self;
end;

function TTarBuilder.Finish: TBytes; inline;
begin
  // 单层 Finish：委托 FWriter.Finish 写两零块（幂等 via IsFinished），再经 FBuilder.ToBytes 单次分配+Move 零额外拷贝
  FWriter.Finish;
  // 零拷贝直写切片：复用 builder.ToBytes 单次分配+Move，消除 ArchiveSnapshotStream 二次 SetLength+Seek+Read 大块 Move
  Result := FBuilder.ToBytes;
end;

function AsStreamBuilder(const ABuilder: ITarBuilder): ITarStreamBuilder; inline;
begin
  // thin QI: zero-copy, inline, reuse existing TTarBuilder instance; non-stream consumers never QI; QueryInterface single source without SysUtils Supports
  Result := nil;
  if (ABuilder = nil) or (ABuilder.QueryInterface(ITarStreamBuilder, Result) <> 0) or (Result = nil) then
    raise EInvalidOperationError.Create('tar: builder does not support streaming (unexpected)');
end;

function TarBuilderAddFromReader(const ABuilder: ITarBuilder; const AHdr: TTarHeader; const AReader: IReader): ITarBuilder; inline;
begin
  // zero-copy streaming via writer single source (64K pooled FIOBuf, bytes.ops Move), Finish 即释
  Result := AsStreamBuilder(ABuilder).AddEntryFromReader(AHdr, AReader);
end;

function TarBuilder: ITarBuilder; inline;
begin
  Result := TTarBuilder.Create;
end;

function TarBuilderWithCapacity(const AEstimatedTotal: SizeUInt): ITarBuilder; inline;
begin
  Result := TTarBuilder.CreateWithCapacity(AEstimatedTotal);
end;

end.
