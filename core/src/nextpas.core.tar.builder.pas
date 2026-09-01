unit nextpas.core.tar.builder;
{**
 * @desc Tar 链式构造器：ZipBuilder 手感的薄门面，委托 TTarWriter。
 * 仅做流畅 API 封装，不含序列化逻辑，保证 bytes 级一致。
 * @note 显式 Finish：析构不自动补两零块，需调用方显式 Finish；单工厂 TarBuilder。
 * 性能：IBytesBuilder 直写切片，inline AppendBytes 零拷贝，Finish 单次 ToBytes 拷贝，
 *       消除 CreateBytesStream + ArchiveSnapshotStream 二次 SetLength+Read 大块 Move。
 *       AddDirectory* 薄门面复用 writer 单源 DefaultTarAddOptions/TarDirectoryMode，无重复 H 组装。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.tar.base,
  nextpas.core.tar.intf,
  nextpas.core.tar.writer;

function TarBuilder: ITarBuilder;

implementation

uses
  nextpas.core.exception,
  nextpas.core.bytes.builder;

type
  { IBytesBuilder 的最小 IWriter 适配：直写切片至 builder，切片零拷贝复用 bytes.ops 单源思想 }
  TBuilderSink = class(TInterfacedObject, IWriter)
  private
    FBuilder: IBytesBuilder;
  public
    constructor Create(const ABuilder: IBytesBuilder);
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt; inline;
  end;

  TTarBuilder = class(TInterfacedObject, ITarBuilder)
  private
    FBuilder: IBytesBuilder;
    FSink: IWriter;
    FWriter: TTarWriter;
  public
    constructor Create;
    destructor Destroy; override;
    function Add(const AName: string; const AData: TBytes): ITarBuilder; inline;
    function AddWithOptions(const AName: string; const AData: TBytes; const AOpts: TTarAddOptions): ITarBuilder; inline;
    function AddDirectory(const AName: string): ITarBuilder; inline;
    function AddDirectoryWithOptions(const AName: string; const AOpts: TTarAddOptions): ITarBuilder; inline;
    function AddEntry(const AHdr: TTarHeader; const AData: TBytes): ITarBuilder; inline;
    function Finish: TBytes; inline;
  end;

constructor TBuilderSink.Create(const ABuilder: IBytesBuilder);
begin
  inherited Create;
  FBuilder := ABuilder;
end;

function TBuilderSink.Write(const ABuf; const ACount: SizeUInt): SizeUInt; inline;
begin
  // perf: inline + AppendBytes 单次 Move（bytes.builder 几何扩容单源，4K 页对齐复用 MEM_PAGE_SIZE），零拷贝切片直写
  if ACount > 0 then
    FBuilder.AppendBytes(PByte(@ABuf), ACount);
  Result := ACount;
end;

constructor TTarBuilder.Create;
begin
  inherited Create;
  // bytes.builder 单源：初始 4K，几何扩容避免大写多次重分配，复用 BYTES_BUILDER_* 常量
  FBuilder := CreateBytesBuilder(4096);
  FSink := TBuilderSink.Create(FBuilder);
  FWriter := TTarWriter.Create(FSink);
end;

destructor TTarBuilder.Destroy;
begin
  // 稳定性：FWriter.Free 兜底补两零块（writer 析构 Finish best-effort），FBuilder/FSink 为接口自动释放，不丢资源
  FWriter.Free;
  inherited Destroy;
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

function TTarBuilder.Finish: TBytes; inline;
begin
  FWriter.Finish;
  // 零拷贝直写切片：复用 builder.ToBytes 单次分配+Move，消除 ArchiveSnapshotStream 二次 SetLength+Seek+Read 大块 Move
  Result := FBuilder.ToBytes;
end;

function TarBuilder: ITarBuilder;
begin
  Result := TTarBuilder.Create;
end;

end.
