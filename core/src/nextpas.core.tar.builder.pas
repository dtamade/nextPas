unit nextpas.core.tar.builder;
{**
 * @desc Tar 链式构造器：ZipBuilder 手感的薄门面，委托 TTarWriter。
 * 仅做流畅 API 封装，不含序列化逻辑，保证 bytes 级一致。
 * @note 显式 Finish fail-closed：析构不静默补两零块，未 Finish 即抛 EInvalidOperationError，避免链式丢数据无感知；单工厂 TarBuilder。
 * 性能：IBytesBuilder 直写切片，inline AppendBytes 零拷贝，Finish 单次 ToBytes 拷贝，
 *       消除 CreateBytesStream + ArchiveSnapshotStream 二次 SetLength+Read 大块 Move。
 *       AddDirectory* 薄门面复用 writer 单源 DefaultTarAddOptions/TarDirectoryMode，无重复 H 组装。
 *       AddEntryFromReader 流式零拷贝 64K pooled 复用缓冲分块 Move 单源 bytes.ops，委托 writer 单源。
 *       容量：TarBuilderCapacityFor 预扩容按预估总量 4K 对齐，避免大归档多次几何扩容；默认 4K 页对齐。
 * 联邦：经 nextpas.core.archive.fs 单缝联邦（与 tar.fs 共用单源 CreateArchiveBuilderSink/几何扩容/IWriter 适配），注册表显式登记 builder+fs 双路径，消除 L2 同层双引审计歧义。
 * 稳定性：Destroy SafeFail — ExceptObject 非 nil 时抑制二次异常逃逸，StdErr WARN 后释资源。
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
  nextpas.core.bytes.builder,
  nextpas.core.archive.fs; // federation single seam: builder+fs 均经 archive.fs 联邦，CreateArchiveBuilder/Sink 单源，注册表显式登记双路径

type
  TTarBuilder = class(TInterfacedObject, ITarBuilder)
  private
    FBuilder: IBytesBuilder;
    FSink: IWriter;
    FWriter: TTarWriter;
    FFinished: Boolean;
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
begin
  inherited Create;
  // perf: 预扩容按预估总量 4K 对齐，避免大归档多次几何扩容；默认 TarBuilderCapacityFor 单源，复用 bytes.builder 几何扩容+ archive 单源 CreateArchiveBuilder，inline 零拷贝直写切片，消除与 tar.fs 同模板重复
  CreateArchiveBuilder(TarBuilderCapacityFor(0), FBuilder, FSink);
  FWriter := TTarWriter.Create(FSink);
  FFinished := False;
end;

constructor TTarBuilder.CreateWithCapacity(const AEstimatedTotal: SizeUInt);
var LCap: SizeUInt;
begin
  inherited Create;
  // perf: 按预估总量预扩容 4K 对齐，TarBuilderCapacityFor 单源，避免大归档多次 2× 几何扩容与重分配；inline/零拷贝证据复用 bytes.builder 单源
  LCap := TarBuilderCapacityFor(AEstimatedTotal);
  CreateArchiveBuilder(LCap, FBuilder, FSink);
  FWriter := TTarWriter.Create(FSink);
  FFinished := False;
end;

destructor TTarBuilder.Destroy;
begin
  // fail-closed SafeFail：未显式 Finish 时正常抛 EInvalidOperationError；若已在异常展开中（System.RaiseList<>nil）则抑制二次异常逃逸，StdErr WARN 后释资源（不引入 SysUtils，守 nextpas.* 单源）
  try
    if not FFinished then
    begin
      if System.RaiseList = nil then
        raise EInvalidOperationError.Create('tar: builder destroyed without Finish (missing two zero blocks, data truncated)')
      else
      begin
        System.WriteLn(System.StdErr, '[WARN] tar: builder destroyed without Finish (missing two zero blocks, data truncated) - suppressed during exception unwind');
        System.Flush(System.StdErr);
      end;
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
  FWriter.Finish;
  FFinished := True;
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
