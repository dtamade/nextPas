unit nextpas.core.tar.builder;
{**
 * @desc Tar 链式构造器：ZipBuilder 手感的薄门面。
 *
 * 薄委托 `TTarWriter`，仅做流畅 API 封装，不含序列化逻辑，
 * 字节形态与写器一致，单工厂 `TarBuilder` / `TarBuilderWithCapacity`。
 *
 * 联邦 — 唯一经 `nextpas.core.archive.fs` 单缝联邦。
 * 与 `tar.fs` 共用单源 `CreateArchiveBuilder` / `IArchiveBuilder` /
 * 几何扩容 / `IWriter` 适配，`bytes.builder` / `bytes.ops` 单源
 * inline 零拷贝经 `archive.fs` 透出；注册表显式登记，消除 L2
 * 同层双引（`bytes.builder` + `archive.fs`）稀释克制感。
 *
 * 容量 — `TarBuilderCapacityFor` 按预估总量 4K 对齐预扩容，
 * 避免大归档多次几何扩容；默认 `C_TAR_BUILDER_INITIAL_CAPACITY`
 * 4K 页对齐。
 *
 * 性能 — `IArchiveBuilder` 联邦单源直写切片（`archive.fs` 透出
 * `bytes.builder` 几何扩容单源），`inline AppendBytes` 零拷贝，
 * `Finish` 单次 `ToBytes` 拷贝，消除 `CreateBytesStream` +
 * `ArchiveSnapshotStream` 二次 `SetLength`+`Read` 大块 `Move`；
 * `AddDirectory*` 薄门面复用 `writer` 单源 `DefaultTarAddOptions` /
 * `TarDirectoryMode`，无重复 `H` 组装；`AddEntryFromReader` 流式
 * 零拷贝 64K pooled 复用缓冲分块 `Move` 单源 `bytes.ops`（经
 * `writer` 单源透出），委托 `writer` 单源。
 *
 * 稳定性 — `Destroy` fail-closed：未 `Finish` 析构即硬失败
 * （缺两零块截断），非 unwind 期抛 `EInvalidOperationError`，
 * unwind 期 `IsExceptionUnwinding` 抑制次生以保原始异常上下文
 * 并经 `log.intf ILogger.Warn` 可观测（`NullLogger` 默认零分配，
 * 无 `System.WriteLn` 直触），避免链式漏 `Finish` 静默丢数据；
 * `try..finally` 必释 `FWriter`，复用 `TTarWriter` 同策略，
 * 无 `System.WriteLn` 直触 RTL 控制台，L2 经 `log.intf` 平台抽象克制。
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
  nextpas.core.log.intf,
  nextpas.core.archive.fs; // federation single seam: 唯一入口 archive.fs，IArchiveBuilder/CreateArchiveBuilder/Sink 单源联邦（bytes.builder 几何扩容与 bytes.ops 单源 inline 零拷贝经 archive.fs 透出），注册表显式登记，消除 L2 同层双引稀释

type
  TTarBuilder = class(TInterfacedObject, ITarBuilder)
  private
    FBuilder: IArchiveBuilder;
    FSink: IWriter;
    FWriter: TTarWriter;
    FFinished: Boolean;
    FLogger: ILogger; // L2 经 log.intf 单缝可观测（NullLogger 默认零分配），不直触 System.StdErr，平台抽象克制
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
  // perf: 预扩容按预估总量 4K 对齐，避免大归档多次几何扩容；默认 TarBuilderCapacityFor 单源，联邦单源 CreateArchiveBuilder 经 archive.fs 透出 bytes.builder 几何扩容单源，inline 零拷贝直写切片（bytes.ops 单源 Move），消除与 tar.fs 同模板重复
  FLogger := NullLogger(); // L2 经 log.intf 平台抽象可观测，默认 no-op 零分配 inline 薄转发，无 StdErr 直触
  CreateArchiveBuilder(TarBuilderCapacityFor(0), FBuilder, FSink);
  FWriter := TTarWriter.Create(FSink);
  FFinished := False;
end;

constructor TTarBuilder.CreateWithCapacity(const AEstimatedTotal: SizeUInt);
var LCap: SizeUInt;
begin
  inherited Create;
  // perf: 按预估总量预扩容 4K 对齐，TarBuilderCapacityFor 单源，避免大归档多次 2× 几何扩容与重分配；inline/零拷贝证据经 archive.fs 联邦透出 bytes.builder 单源（AppendBytes 单次 Move，bytes.ops 单源）
  FLogger := NullLogger(); // 同 Create 单源，log.intf 克制不直触 RTL 控制台
  LCap := TarBuilderCapacityFor(AEstimatedTotal);
  CreateArchiveBuilder(LCap, FBuilder, FSink);
  FWriter := TTarWriter.Create(FSink);
  FFinished := False;
end;

destructor TTarBuilder.Destroy;
var
  LUnwinding: Boolean;
begin
  // fail-closed：未 Finish 即截断（缺两零块）硬失败；IsExceptionUnwinding 判 unwind 期抑制次生以保原始异常，可观测经 log.intf ILogger.Warn 单源薄转发（NullLogger no-op 零拷贝 inline），不直触 System.WriteLn/System.StdErr，L2 平台抽象克制；try..finally 必释 FWriter，复用 TTarWriter 同策略，零额外拷贝
  LUnwinding := IsExceptionUnwinding;
  try
    if not FFinished then
    begin
      if not LUnwinding then
        raise EInvalidOperationError.Create('tar: builder destroyed without Finish (missing two zero blocks, data truncated)');
      // unwind 期仅可观测，不抛次生覆盖原始异常；L2 经 log.intf 单缝，无 RTL 控制台直触
      if FLogger <> nil then
        FLogger.Warn('tar: builder destroyed without Finish (missing two zero blocks, data truncated)');
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
