unit nextpas.core.tar.builder;
{**
 * @desc Tar builder facade
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

implementation

uses
  nextpas.core.exception,
  nextpas.core.archive.fs, // 联邦单缝：唯一入口 archive.fs（bytes.builder 几何扩容与 bytes.ops 单源 inline 零拷贝经 archive.fs 透出）
  nextpas.core.log.intf;

type
  TTarBuilder = class(TInterfacedObject, ITarBuilder)
  private
    FBuilder: IArchiveBuilder; // 联邦单源直写切片，bytes.builder 几何扩容单源 inline 零拷贝
    FWriter: TTarWriter; // 薄委托唯一写器，持有 Sink 单缝，IsFinished 单源
    procedure InitBuilder(const ACap: SizeUInt); inline; // inline 薄转发：联邦单缝，详见 CONTRACT §1.4
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

procedure TTarBuilder.InitBuilder(const ACap: SizeUInt); inline;
var LSink: IWriter;
begin
  CreateArchiveBuilder(ACap, FBuilder, LSink);
  FWriter := TTarWriter.Create(LSink);
end;

constructor TTarBuilder.Create;
begin
  inherited Create;
  InitBuilder(TarBuilderCapacityFor(0));
end;

constructor TTarBuilder.CreateWithCapacity(const AEstimatedTotal: SizeUInt);
begin
  inherited Create;
  InitBuilder(TarBuilderCapacityFor(AEstimatedTotal));
end;

destructor TTarBuilder.Destroy;
begin
  // 稳定性：析构永不抛异常，仅 Warn 可观测，try..finally 必释；IsFinished 单源幂等，见 CONTRACT §1.4
  try
    if (FWriter <> nil) and (not FWriter.IsFinished) then
      NullLogger.Warn('tar: builder destroyed without Finish (missing two zero blocks, data truncated)');
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
  // 流式零拷贝：委托 TTarWriter.AddEntryFromReader 单源，per-entry 局域缓冲 via TarIOBufCapacityFor (AlignUp4K) try..finally 必释无滞留，bytes.ops 单源 inline 零拷贝
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

function TarBuilder: ITarBuilder; inline;
begin
  Result := TTarBuilder.Create;
end;

function TarBuilderWithCapacity(const AEstimatedTotal: SizeUInt): ITarBuilder; inline;
begin
  Result := TTarBuilder.CreateWithCapacity(AEstimatedTotal);
end;

end.
