unit nextpas.core.tar.builder;
{**
 * @desc Tar 链式构造器：ZipBuilder 手感的薄门面。
 *
 * 极简两字段薄委托 `FBuilder+FWriter` 单层归属，`FSink` 仅构造期局域
 * 经 `TTarWriter` 单缝持有，零冗余；`FFinished/FLogger` 合并至 `FWriter.IsFinished`
 * 单源，`Destroy` 单层 fail-closed 硬失败防缺两零块截断（非 unwind 抛
 * `EInvalidOperationError`，unwind 期 `IsExceptionUnwinding` 抑制次生并依
 * 赖 `TTarWriter` 内置 `log.intf` 可观测），消除.Builder/Writer双层Finish
 * 语义重叠，门面极简高级感与 ZipBuilder 单 `FWriter` 手感对齐；联邦
 * 单缝经 `nextpas.core.archive.fs` 联邦，字节形态与写器一致，单工厂
 * `TarBuilder` / `TarBuilderWithCapacity`。
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
 * 稳定性 — `Destroy` fail-closed 单源：以 `FWriter.IsFinished` 为
 * 唯一真源判未 `Finish` 即截断，`try..finally` 必释 `FWriter`（其
 * `Destroy` 内置 `IsExceptionUnwinding` 次生抑制 + `ILogger.Warn`
 * `NullLogger` 零分配可观测，L2 经 `log.intf` 单缝），`FBuilder`
 * 接口自动释，零泄漏无 `System.WriteLn` 直触。
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
  nextpas.core.archive.fs; // federation single seam: 唯一入口 archive.fs，IArchiveBuilder/CreateArchiveBuilder/Sink 单源联邦（bytes.builder 几何扩容与 bytes.ops 单源 inline 零拷贝经 archive.fs 透出），注册表显式登记，消除 L2 同层双引稀释

type
  TTarBuilder = class(TInterfacedObject, ITarBuilder)
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
  // perf: 预扩容按预估总量 4K 对齐，避免大归档多次几何扩容；默认 TarBuilderCapacityFor 单源，联邦单源 CreateArchiveBuilder 经 archive.fs 透出 bytes.builder 几何扩容单源，inline 零拷贝直写切片（bytes.ops 单源 Move），消除与 tar.fs 同模板重复；LSink 局域经 FWriter 单缝持有，零字段冗余
  CreateArchiveBuilder(TarBuilderCapacityFor(0), FBuilder, LSink);
  FWriter := TTarWriter.Create(LSink);
end;

constructor TTarBuilder.CreateWithCapacity(const AEstimatedTotal: SizeUInt);
var LCap: SizeUInt; LSink: IWriter;
begin
  inherited Create;
  // perf: 按预估总量预扩容 4K 对齐，TarBuilderCapacityFor 单源，避免大归档多次 2× 几何扩容与重分配；inline/零拷贝证据经 archive.fs 联邦透出 bytes.builder 单源（AppendBytes 单次 Move，bytes.ops 单源）
  LCap := TarBuilderCapacityFor(AEstimatedTotal);
  CreateArchiveBuilder(LCap, FBuilder, LSink);
  FWriter := TTarWriter.Create(LSink);
end;

destructor TTarBuilder.Destroy;
var
  LUnwinding: Boolean;
begin
  // fail-closed 单层：以 FWriter.IsFinished 单源判未 Finish 即截断（缺两零块）硬失败；IsExceptionUnwinding 判 unwind 期抑制次生以保原始异常，可观测由 FWriter.Destroy 内置 log.intf ILogger.Warn 单缝承接（NullLogger no-op 零拷贝 inline），不直触 System.WriteLn；try..finally 必释 FWriter，FBuilder 接口自动释，无 linger 峰值
  LUnwinding := IsExceptionUnwinding;
  try
    if (FWriter <> nil) and (not FWriter.IsFinished) then
    begin
      if not LUnwinding then
        raise EInvalidOperationError.Create('tar: builder destroyed without Finish (missing two zero blocks, data truncated)');
      // unwind 期仅抑制次生，不抛覆盖原始异常；可观测由 FWriter.Destroy 经 log.intf 单缝 Warn
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

function TarBuilder: ITarBuilder; inline;
begin
  Result := TTarBuilder.Create;
end;

function TarBuilderWithCapacity(const AEstimatedTotal: SizeUInt): ITarBuilder; inline;
begin
  Result := TTarBuilder.CreateWithCapacity(AEstimatedTotal);
end;

end.
