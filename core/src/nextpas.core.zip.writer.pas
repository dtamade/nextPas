unit nextpas.core.zip.writer;
{**
 * @desc ZIP 归档写器实现：local file header + central directory + EOCD，
 *       支持 store 与 deflate（method=8，经 compress.RawDeflate）条目、
 *       目录条目，以及 Zip64：尺寸/偏移/条目数超 ZIP32 宽度时自动启用，
 *       TZipWriteOptions.ForceZip64 可无条件强制。产出任何标准解压器可读的归档。
 *
 * 确定性：未指定时间戳取 DOS 纪元下限，同输入同字节；deflate 载荷由 zlib
 * 版本决定，跨环境不保证字节一致，但始终可被标准解压器还原。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.builder,
  nextpas.core.compress.intf,
  nextpas.core.zip.base;

type
  {** @desc 写选项：ForceZip64 无条件产出 Zip64 结构（预知超大归档/测试用） *}
  TZipWriteOptions = record
    ForceZip64: Boolean;
  end;

  {** @desc 单条目添加选项：Method 缺省 store；ModTimeUnixSec < 0 取 DOS 纪元
       下限；Mode 为 unix 模式字（S_IFMT|rwx），0 取按条目类型的默认值 *}
  TZipAddOptions = record
    Method: TZipMethod;
    ModTimeUnixSec: Int64;
    Mode: Word;
  end;

  {** @desc ZIP 归档写器（store/deflate 条目，顺序追加，Finish 一次性终结） *}
  IZipWriter = interface
    ['{A6E4F810-2D53-4B9C-8F71-5C0B9D24E3A8}']
    {** 添加 store 条目；时间戳取 DOS 下限（确定性输出） *}
    procedure AddEntry(const AName: string; const AData: TBytes);
    {** 添加 store 条目，AModTimeUnixSec 为 unix 秒（越界钳制到 DOS 区间） *}
    procedure AddEntryWithTime(const AName: string; const AData: TBytes;
      const AModTimeUnixSec: Int64);
    {** 添加 deflate(method=8) 条目；时间戳取 DOS 下限 *}
    procedure AddEntryDeflate(const AName: string; const AData: TBytes);
    {** 添加 deflate 条目，显式 unix 秒时间戳 *}
    procedure AddEntryDeflateWithTime(const AName: string; const AData: TBytes;
      const AModTimeUnixSec: Int64);
    {** 添加目录条目：名字规范化补尾随 '/'，零载荷，目录外部属性 *}
    procedure AddDirectory(const AName: string);
    {** 同上，显式 unix 秒时间戳 *}
    procedure AddDirectoryWithTime(const AName: string;
      const AModTimeUnixSec: Int64);
    {** 完整选项添加：方法/时间戳/unix 模式字一次给定 *}
    procedure AddEntryWithOptions(const AName: string; const AData: TBytes;
      const AOptions: TZipAddOptions);
    {** 流式添加条目：返回未压缩载荷的推式写入端（ICompressWriter），
        增量计算 CRC32 并按 Method 压缩；Close 后条目落定（析构兜底同义）。
        载荷不必整体物化，内存上界为单条目压缩尺寸；Finish 时存在未 Close
        的流则 raise。多个未关闭流按各自 Close 顺序落盘。 *}
    function AddEntryStream(const AName: string;
      const AOptions: TZipAddOptions): ICompressWriter;
    {** 已添加条目数 *}
    function EntryCount: Integer;
    {** 终结并返回完整归档字节；此后各添加方法与 Finish 均 raise *}
    function Finish: TBytes;
  end;

{** 默认写选项。 *}
function DefaultZipWriteOptions: TZipWriteOptions; inline;

{** 默认单条目选项（store、确定性时间戳、默认属性）。 *}
function DefaultZipAddOptions: TZipAddOptions; inline;

function NewZipWriter: IZipWriter;

{** 带选项构造。 *}
function NewZipWriterWithOptions(const AOptions: TZipWriteOptions): IZipWriter;

implementation

uses
  nextpas.core.exception,
  nextpas.core.io.intf,
  nextpas.core.checksum.crc32,
  nextpas.core.compress.deflate;

const
  C_ZIP64_LOCAL_EXTRA_LEN = 20;  { id(2)+size(2)+原始/压缩尺寸各 8 }
  C_ZIP64_EOCD_BODY_LEN   = 44;  { zip64 EOCD 记录体（不含签名+尺寸前缀 12 字节） }

type
  TZipEntryMeta = record
    FName: string;        { UTF-8 字节序列（Pascal string 直存） }
    FMethod: Word;
    FCrc: LongWord;       { 未压缩载荷的 CRC32 }
    FUSize: UInt64;       { 未压缩尺寸 }
    FCSize: UInt64;       { 压缩后尺寸（store 时等于 FUSize） }
    FDosTime: Word;
    FDosDate: Word;
    FLocalOffset: UInt64;
    FIsDir: Boolean;
    FExtAttrs: LongWord;  { 外部属性（unix 模式字在高 16 位） }
    FNeedsZ64Sizes: Boolean;  { 尺寸走 Zip64 extra（含 Force 场景） }
  end;

  TZipWriter = class(TInterfacedObject, IZipWriter)
  private
    FOut: IBytesBuilder;
    FEntries: array of TZipEntryMeta;
    FCount: Integer;      { 有效条目数；FEntries 按 FCapacity 几何扩容 }
    FCapacity: Integer;
    FFinished: Boolean;
    FForceZip64: Boolean;
    { 未 Close 的流式写入端。弱登记（裸指针，不持引用计数）：
      用户放弃流时对象必然析构并按指针注销；写器只比较/清除指针，
      绝不解引用悬垂指针（在册 ⇔ FOwner<>nil ⇔ 存活外部引用） }
    FOpenSinks: array of Pointer;
    procedure CheckOpen;
    procedure EnsureCapacity(AMinimum: Integer);
    procedure AddEntryInternal(const AName: string; const APayload,
      AData: TBytes; AMethod: Word; const AModTimeUnixSec: Int64;
      AIsDir: Boolean; AMode: Word);
    procedure AddDirectoryInternal(const AName: string;
      const AModTimeUnixSec: Int64);
    procedure RegisterSink(ASink: TObject);
    procedure UnregisterSink(APtr: Pointer);
    procedure DetachSinks;
    { local header + 压缩载荷落盘（元数据已含全部字段，偏移在此捕获） }
    procedure AppendLocalEntry(const AMeta: TZipEntryMeta;
      const APayload: TBytes);
    { 流式条目定稿：登记元数据并落盘 local header + 压缩载荷 }
    procedure CommitStreamEntry(AMeta: TZipEntryMeta; const APayload: TBytes);
  public
    constructor Create(AForceZip64: Boolean);
    destructor Destroy; override;
    procedure AddEntry(const AName: string; const AData: TBytes);
    procedure AddEntryWithTime(const AName: string; const AData: TBytes;
      const AModTimeUnixSec: Int64);
    procedure AddEntryDeflate(const AName: string; const AData: TBytes);
    procedure AddEntryDeflateWithTime(const AName: string; const AData: TBytes;
      const AModTimeUnixSec: Int64);
    procedure AddDirectory(const AName: string);
    procedure AddDirectoryWithTime(const AName: string;
      const AModTimeUnixSec: Int64);
    procedure AddEntryWithOptions(const AName: string; const AData: TBytes;
      const AOptions: TZipAddOptions);
    function AddEntryStream(const AName: string;
      const AOptions: TZipAddOptions): ICompressWriter;
    function EntryCount: Integer;
    function Finish: TBytes;
  end;

function DefaultZipWriteOptions: TZipWriteOptions;
begin
  Result.ForceZip64 := False;
end;

function DefaultZipAddOptions: TZipAddOptions;
begin
  Result.Method := zmStore;
  Result.ModTimeUnixSec := -1;
  Result.Mode := 0;
end;

function NewZipWriter: IZipWriter;
begin
  Result := NewZipWriterWithOptions(DefaultZipWriteOptions);
end;

function NewZipWriterWithOptions(const AOptions: TZipWriteOptions): IZipWriter;
begin
  Result := TZipWriter.Create(AOptions.ForceZip64);
end;

constructor TZipWriter.Create(AForceZip64: Boolean);
begin
  inherited Create;
  FOut := CreateBytesBuilder(256);
  FCount := 0;
  FCapacity := 0;
  FFinished := False;
  FForceZip64 := AForceZip64;
end;

destructor TZipWriter.Destroy;
begin
  DetachSinks;
  inherited;
end;

procedure TZipWriter.CheckOpen;
begin
  if FFinished then
    raise EInvalidOperationError.Create('zip writer already finished');
end;

procedure TZipWriter.EnsureCapacity(AMinimum: Integer);
var
  LNew: Integer;
begin
  if FCapacity >= AMinimum then
    Exit;
  LNew := 8;
  while LNew < AMinimum do
    LNew := LNew * 2;
  SetLength(FEntries, LNew);
  FCapacity := LNew;
end;

{ 条目规格归一化（一次性添加与流式添加共用）：模式字声明目录即按目录处理
  并补尾随 '/'（对齐 Go archive/zip 语义）；低字节 $10 为 MS-DOS 目录属性位，
  unzip 等工具据此识别目录条目 }
procedure ResolveEntrySpec(const AName: string; AIsDir: Boolean; AMode: Word;
  out AEffName: string; out AEffIsDir: Boolean; out AExtAttrs: LongWord);
begin
  AEffIsDir := AIsDir or ((AMode and $4000) <> 0);
  AEffName := AName;
  if AEffIsDir and ((AEffName = '') or (AEffName[Length(AEffName)] <> '/')) then
    AEffName := AEffName + '/';
  ValidateZipEntryName(AEffName);
  if AMode = 0 then
  begin
    if AEffIsDir then
      AExtAttrs := C_ZIP_EXTERNAL_ATTR_DIRECTORY
    else
      AExtAttrs := C_ZIP_EXTERNAL_ATTR_REGULAR;
  end
  else if AEffIsDir then
    AExtAttrs := (LongWord(AMode) shl 16) or $0010
  else
    AExtAttrs := LongWord(AMode) shl 16;
end;

{ IBytesBuilder 的最小 IWriter 适配：供增量压缩器写入压缩载荷缓冲 }
type
  TBuilderSink = class(TInterfacedObject, IWriter)
  private
    FBuilder: IBytesBuilder;
  public
    constructor Create(const ABuilder: IBytesBuilder);
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
  end;

constructor TBuilderSink.Create(const ABuilder: IBytesBuilder);
begin
  inherited Create;
  FBuilder := ABuilder;
end;

function TBuilderSink.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  if ACount > 0 then
    FBuilder.AppendBytes(PByte(@ABuf), ACount);
  Result := ACount;
end;

{ 流式条目写入端：外部写未压缩字节进来，内部增量 CRC + raw deflate；
  Close（或放弃时析构）定稿条目。语义见 IZipWriter.AddEntryStream 注释。 }
type
  TZipEntrySink = class(TInterfacedObject, ICompressWriter)
  private
    FOwner: TZipWriter;          { 弱归属；DetachOwner 置 nil }
    FMeta: TZipEntryMeta;        { Close 时补齐 Crc/USize/CSize/Z64 标记 }
    FTimeUnixSec: Int64;
    FCrc: LongWord;
    FUSize: UInt64;
    FBuffer: IBytesBuilder;      { store 原样 / deflate 压缩输出累积 }
    FDeflate: ICompressWriter;   { deflate 路径的增量压缩器；store 为 nil }
    FClosed: Boolean;
    procedure FinalizeEntry(AOwner: TZipWriter);
  public
    constructor Create(AOwner: TZipWriter; const AMeta: TZipEntryMeta;
      const ATimeUnixSec: Int64);
    destructor Destroy; override;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Flush;
    procedure Close;
    procedure DetachOwner;
  end;

constructor TZipEntrySink.Create(AOwner: TZipWriter; const AMeta: TZipEntryMeta;
  const ATimeUnixSec: Int64);
begin
  inherited Create;
  FOwner := AOwner;
  FMeta := AMeta;
  FTimeUnixSec := ATimeUnixSec;
  FCrc := 0;                     { Crc32Update 标准值语义的运行值 }
  FUSize := 0;
  FBuffer := CreateBytesBuilder(4096);
  if AMeta.FMethod = C_ZIP_METHOD_DEFLATE then
    FDeflate := CreateRawDeflateWriter(TBuilderSink.Create(FBuffer));
end;

procedure TZipEntrySink.DetachOwner;
begin
  FOwner := nil;
end;

destructor TZipEntrySink.Destroy;
begin
  { 显式放弃未关闭的流：仅解除登记，条目不落入归档（见 API 契约）。
    登记为裸指针（弱引用），析构必然可达：用户丢掉最后一个外部
    引用时计数归零走到这里 }
  if FOwner <> nil then
  begin
    FOwner.UnregisterSink(Pointer(Self));
    FOwner := nil;
  end;
  inherited;
end;

function TZipEntrySink.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  if FClosed then
    raise EIOError.Create('zip entry stream: write after close');
  if FOwner = nil then
    raise EInvalidOperationError.Create('zip entry stream: writer released');
  if ACount > 0 then
  begin
    FCrc := Crc32Update(FCrc, @ABuf, ACount);
    Inc(FUSize, ACount);
    if FDeflate <> nil then
      FDeflate.Write(ABuf, ACount)
    else
      FBuffer.AppendBytes(PByte(@ABuf), ACount);
  end;
  Result := ACount;
end;

procedure TZipEntrySink.Flush;
begin
  if FClosed then
    raise EIOError.Create('zip entry stream: flush after close');
  if FOwner = nil then
    raise EInvalidOperationError.Create('zip entry stream: writer released');
  if FDeflate <> nil then
    FDeflate.Flush;
end;

procedure TZipEntrySink.FinalizeEntry(AOwner: TZipWriter);
var
  LPayload: TBytes;
begin
  LPayload := FBuffer.ToBytes;
  FMeta.FCrc := FCrc;
  FMeta.FUSize := FUSize;
  FMeta.FCSize := Length(LPayload);
  FMeta.FNeedsZ64Sizes := AOwner.FForceZip64 or
    (FUSize > C_ZIP_MAX_SIZE32) or
    (UInt64(Length(LPayload)) > C_ZIP_MAX_SIZE32);
  DosDateTimeFromUnix(FTimeUnixSec, FMeta.FDosDate, FMeta.FDosTime);
  AOwner.CommitStreamEntry(FMeta, LPayload);
end;

procedure TZipEntrySink.Close;
var
  LOwner: TZipWriter;
begin
  { 先置 FClosed 再定稿：压缩终结失败时本流已作废，条目不落入归档，
    登记由 finally 保证解除，不阻塞后续 Finish }
  if FClosed then
    Exit;
  FClosed := True;
  LOwner := FOwner;
  if LOwner = nil then
    raise EInvalidOperationError.Create('zip entry stream: writer released');
  try
    if FDeflate <> nil then
      FDeflate.Close;
    FinalizeEntry(LOwner);
  finally
    if FOwner <> nil then
    begin
      FOwner.UnregisterSink(Pointer(Self));
      FOwner := nil;
    end;
  end;
end;

procedure TZipWriter.AddEntryInternal(const AName: string; const APayload,
  AData: TBytes; AMethod: Word; const AModTimeUnixSec: Int64;
  AIsDir: Boolean; AMode: Word);
var
  LMeta: TZipEntryMeta;
  LEffName: string;
  LEffIsDir: Boolean;
begin
  CheckOpen;
  ResolveEntrySpec(AName, AIsDir, AMode, LEffName, LEffIsDir,
    LMeta.FExtAttrs);

  LMeta.FNeedsZ64Sizes := FForceZip64 or
    (UInt64(Length(AData)) > C_ZIP_MAX_SIZE32) or
    (UInt64(Length(APayload)) > C_ZIP_MAX_SIZE32);

  LMeta.FName := LEffName;
  LMeta.FMethod := AMethod;
  LMeta.FCrc := Crc32OfBytes(AData);
  LMeta.FUSize := Length(AData);
  LMeta.FCSize := Length(APayload);
  DosDateTimeFromUnix(AModTimeUnixSec, LMeta.FDosDate, LMeta.FDosTime);
  LMeta.FLocalOffset := FOut.Length;
  LMeta.FIsDir := LEffIsDir;

  EnsureCapacity(FCount + 1);
  FEntries[FCount] := LMeta;
  Inc(FCount);

  AppendLocalEntry(LMeta, APayload);
end;

procedure TZipWriter.AppendLocalEntry(const AMeta: TZipEntryMeta;
  const APayload: TBytes);
var
  LVersion: Word;
begin
  if AMeta.FNeedsZ64Sizes then
    LVersion := C_ZIP_VERSION_ZIP64
  else
    LVersion := C_ZIP_VERSION_DEFAULT;

  FOut.AppendUInt32LE(C_ZIP_LOCAL_SIG);
  FOut.AppendUInt16LE(LVersion);
  FOut.AppendUInt16LE(C_ZIP_FLAG_UTF8);
  FOut.AppendUInt16LE(AMeta.FMethod);
  FOut.AppendUInt16LE(AMeta.FDosTime);
  FOut.AppendUInt16LE(AMeta.FDosDate);
  FOut.AppendUInt32LE(AMeta.FCrc);
  if AMeta.FNeedsZ64Sizes then
  begin
    FOut.AppendUInt32LE(C_ZIP_MAX_SIZE32);  { 实际值在 Zip64 extra }
    FOut.AppendUInt32LE(C_ZIP_MAX_SIZE32);
  end
  else
  begin
    FOut.AppendUInt32LE(LongWord(AMeta.FCSize));
    FOut.AppendUInt32LE(LongWord(AMeta.FUSize));
  end;
  FOut.AppendUInt16LE(Word(Length(AMeta.FName)));
  if AMeta.FNeedsZ64Sizes then
    FOut.AppendUInt16LE(C_ZIP64_LOCAL_EXTRA_LEN)
  else
    FOut.AppendUInt16LE(0);
  if Length(AMeta.FName) > 0 then
    FOut.AppendBytes(PByte(Pointer(AMeta.FName)), Length(AMeta.FName));
  if AMeta.FNeedsZ64Sizes then
  begin
    FOut.AppendUInt16LE(C_ZIP64_EXTRA_ID);
    FOut.AppendUInt16LE(16);
    FOut.AppendUInt64LE(AMeta.FUSize);
    FOut.AppendUInt64LE(AMeta.FCSize);
  end;
  if Length(APayload) > 0 then
    FOut.AppendBytes(PByte(APayload), Length(APayload));
end;

procedure TZipWriter.RegisterSink(ASink: TObject);
begin
  SetLength(FOpenSinks, Length(FOpenSinks) + 1);
  FOpenSinks[High(FOpenSinks)] := Pointer(ASink);
end;

procedure TZipWriter.UnregisterSink(APtr: Pointer);
var
  LI, LJ: Integer;
begin
  for LI := 0 to High(FOpenSinks) do
    if FOpenSinks[LI] = APtr then
    begin
      for LJ := LI to High(FOpenSinks) - 1 do
        FOpenSinks[LJ] := FOpenSinks[LJ + 1];
      SetLength(FOpenSinks, Length(FOpenSinks) - 1);
      Exit;
    end;
end;

procedure TZipWriter.DetachSinks;
var
  LI: Integer;
begin
  { 先分离归属再清登记：流的 Write/Close/析构看到 FOwner=nil 即不再回调写器。
    在册元素必有存活外部引用（见 FOpenSinks 注释），裸指针转型安全 }
  for LI := 0 to High(FOpenSinks) do
    TZipEntrySink(FOpenSinks[LI]).DetachOwner;
  FOpenSinks := nil;
end;

procedure TZipWriter.CommitStreamEntry(AMeta: TZipEntryMeta;
  const APayload: TBytes);
begin
  AMeta.FLocalOffset := FOut.Length;
  EnsureCapacity(FCount + 1);
  FEntries[FCount] := AMeta;
  Inc(FCount);
  AppendLocalEntry(AMeta, APayload);
end;

procedure TZipWriter.AddEntry(const AName: string; const AData: TBytes);
begin
  { DOS 纪元下限：确定性输出（同输入同字节），见单元头注释 }
  AddEntryInternal(AName, AData, AData, C_ZIP_METHOD_STORE, DosMinUnixSec,
    False, 0);
end;

procedure TZipWriter.AddEntryWithTime(const AName: string; const AData: TBytes;
  const AModTimeUnixSec: Int64);
begin
  AddEntryInternal(AName, AData, AData, C_ZIP_METHOD_STORE, AModTimeUnixSec,
    False, 0);
end;

procedure TZipWriter.AddEntryDeflate(const AName: string; const AData: TBytes);
var
  LPayload: TBytes;
begin
  LPayload := RawDeflateCompress(AData);
  AddEntryInternal(AName, LPayload, AData, C_ZIP_METHOD_DEFLATE,
    DosMinUnixSec, False, 0);
end;

procedure TZipWriter.AddEntryDeflateWithTime(const AName: string;
  const AData: TBytes; const AModTimeUnixSec: Int64);
var
  LPayload: TBytes;
begin
  LPayload := RawDeflateCompress(AData);
  AddEntryInternal(AName, LPayload, AData, C_ZIP_METHOD_DEFLATE,
    AModTimeUnixSec, False, 0);
end;

procedure TZipWriter.AddEntryWithOptions(const AName: string;
  const AData: TBytes; const AOptions: TZipAddOptions);
var
  LPayload: TBytes;
  LMethod: Word;
  LTime: Int64;
begin
  if AOptions.Method = zmDeflate then
  begin
    LPayload := RawDeflateCompress(AData);
    LMethod := C_ZIP_METHOD_DEFLATE;
  end
  else
  begin
    LPayload := AData;
    LMethod := C_ZIP_METHOD_STORE;
  end;
  if AOptions.ModTimeUnixSec < 0 then
    LTime := DosMinUnixSec
  else
    LTime := AOptions.ModTimeUnixSec;
  AddEntryInternal(AName, LPayload, AData, LMethod, LTime,
    (Length(AName) > 0) and (AName[Length(AName)] = '/'), AOptions.Mode);
end;

function TZipWriter.AddEntryStream(const AName: string;
  const AOptions: TZipAddOptions): ICompressWriter;
var
  LMethod: Word;
  LTime: Int64;
  LEffName: string;
  LEffIsDir: Boolean;
  LExtAttrs: LongWord;
  LMeta: TZipEntryMeta;
  LSink: TZipEntrySink;
begin
  CheckOpen;
  if AOptions.Method = zmDeflate then
    LMethod := C_ZIP_METHOD_DEFLATE
  else
    LMethod := C_ZIP_METHOD_STORE;
  if AOptions.ModTimeUnixSec < 0 then
    LTime := DosMinUnixSec
  else
    LTime := AOptions.ModTimeUnixSec;
  ResolveEntrySpec(AName,
    (Length(AName) > 0) and (AName[Length(AName)] = '/'), AOptions.Mode,
    LEffName, LEffIsDir, LExtAttrs);
  FillChar(LMeta, SizeOf(LMeta), 0);
  LMeta.FName := LEffName;
  LMeta.FMethod := LMethod;
  LMeta.FExtAttrs := LExtAttrs;
  LMeta.FIsDir := LEffIsDir;
  LSink := TZipEntrySink.Create(Self, LMeta, LTime);
  RegisterSink(LSink);
  Result := LSink;
end;

procedure TZipWriter.AddDirectory(const AName: string);
begin
  AddDirectoryInternal(AName, DosMinUnixSec);
end;

procedure TZipWriter.AddDirectoryWithTime(const AName: string;
  const AModTimeUnixSec: Int64);
begin
  AddDirectoryInternal(AName, AModTimeUnixSec);
end;

procedure TZipWriter.AddDirectoryInternal(const AName: string;
  const AModTimeUnixSec: Int64);
var
  LNorm: string;
begin
  LNorm := AName;
  if (LNorm <> '') and (LNorm[Length(LNorm)] <> '/') then
    LNorm := LNorm + '/';
  AddEntryInternal(LNorm, nil, nil, C_ZIP_METHOD_STORE, AModTimeUnixSec, True,
    0);
end;

function TZipWriter.EntryCount: Integer;
begin
  Result := FCount;
end;

function TZipWriter.Finish: TBytes;
var
  LI: Integer;
  LE: TZipEntryMeta;
  LCDOffset, LCDSize, LCDEnd, LZ64EocdPos: UInt64;
  LCount: Int64;  LNeedsZ64Offset, LAnyZ64, LNeedZ64Eocd: Boolean;
  LVersionMadeBy, LVersionNeeded: Word;
  LExtraLen: Integer;
  LCountField: LongWord;
begin
  CheckOpen;
  if Length(FOpenSinks) > 0 then
    raise EInvalidOperationError.Create(
      'zip writer: streaming entry not closed');
  LCDOffset := FOut.Length;
  for LI := 0 to FCount - 1 do
  begin
    LE := FEntries[LI];
    LNeedsZ64Offset := FForceZip64 or (LE.FLocalOffset > C_ZIP_MAX_SIZE32);
    LAnyZ64 := LE.FNeedsZ64Sizes or LNeedsZ64Offset;
    if LAnyZ64 then
    begin
      LVersionMadeBy := C_ZIP_MADE_BY_HOST_UNIX or C_ZIP_VERSION_ZIP64;
      LVersionNeeded := C_ZIP_VERSION_ZIP64;
    end
    else
    begin
      LVersionMadeBy := C_ZIP_MADE_BY_HOST_UNIX or C_ZIP_VERSION_DEFAULT;
      LVersionNeeded := C_ZIP_VERSION_DEFAULT;
    end;

    FOut.AppendUInt32LE(C_ZIP_CENTRAL_SIG);
    FOut.AppendUInt16LE(LVersionMadeBy);
    FOut.AppendUInt16LE(LVersionNeeded);
    FOut.AppendUInt16LE(C_ZIP_FLAG_UTF8);
    FOut.AppendUInt16LE(LE.FMethod);
    FOut.AppendUInt16LE(LE.FDosTime);
    FOut.AppendUInt16LE(LE.FDosDate);
    FOut.AppendUInt32LE(LE.FCrc);
    if LE.FNeedsZ64Sizes then
    begin
      FOut.AppendUInt32LE(C_ZIP_MAX_SIZE32);
      FOut.AppendUInt32LE(C_ZIP_MAX_SIZE32);
    end
    else
    begin
      FOut.AppendUInt32LE(LongWord(LE.FCSize));
      FOut.AppendUInt32LE(LongWord(LE.FUSize));
    end;
    FOut.AppendUInt16LE(Word(Length(LE.FName)));
    LExtraLen := 0;
    if LE.FNeedsZ64Sizes then
      Inc(LExtraLen, 16);
    if LNeedsZ64Offset then
      Inc(LExtraLen, 8);
    if LExtraLen > 0 then
      FOut.AppendUInt16LE(Word(LExtraLen + 4))
    else
      FOut.AppendUInt16LE(0);
    FOut.AppendUInt16LE(0);  { comment len }
    FOut.AppendUInt16LE(0);  { disk number start }
    FOut.AppendUInt16LE(0);  { internal attrs }
    FOut.AppendUInt32LE(LE.FExtAttrs);
    if LNeedsZ64Offset then
      FOut.AppendUInt32LE(C_ZIP_MAX_SIZE32)
    else
      FOut.AppendUInt32LE(LongWord(LE.FLocalOffset));
    { central 布局固定顺序：固定字段、文件名、extra、注释 }
    if Length(LE.FName) > 0 then
      FOut.AppendBytes(PByte(Pointer(LE.FName)), Length(LE.FName));
    if LExtraLen > 0 then
    begin
      FOut.AppendUInt16LE(C_ZIP64_EXTRA_ID);
      FOut.AppendUInt16LE(Word(LExtraLen));
      { APPNOTE 固定顺序：原始尺寸、压缩尺寸、本地头偏移 }
      if LE.FNeedsZ64Sizes then
      begin
        FOut.AppendUInt64LE(LE.FUSize);
        FOut.AppendUInt64LE(LE.FCSize);
      end;
      if LNeedsZ64Offset then
        FOut.AppendUInt64LE(LE.FLocalOffset);
    end;
  end;

  { central 尺寸必须在写 EOCD 前固化，否则会把 EOCD 自身前缀计入 }
  LCDEnd := FOut.Length;
  LCDSize := LCDEnd - LCDOffset;
  { 注意用有效条目数而非容量（几何扩容后 Length(FEntries) 可能偏大） }
  LCount := FCount;

  LNeedZ64Eocd := FForceZip64 or (LCount > C_ZIP_MAX_ENTRIES32) or
    (LCDSize > C_ZIP_MAX_SIZE32) or (LCDOffset > C_ZIP_MAX_SIZE32);
  if LNeedZ64Eocd then
  begin
    LZ64EocdPos := FOut.Length;
    FOut.AppendUInt32LE(C_ZIP64_EOCD_SIG);
    FOut.AppendUInt64LE(C_ZIP64_EOCD_BODY_LEN);
    FOut.AppendUInt16LE(C_ZIP_MADE_BY_HOST_UNIX or C_ZIP_VERSION_ZIP64);
    FOut.AppendUInt16LE(C_ZIP_VERSION_ZIP64);
    FOut.AppendUInt32LE(0);                  { 本盘号 }
    FOut.AppendUInt32LE(0);                  { central dir 起始盘号 }
    FOut.AppendUInt64LE(UInt64(LCount));     { 本盘条目数 }
    FOut.AppendUInt64LE(UInt64(LCount));     { 总条目数 }
    FOut.AppendUInt64LE(LCDSize);
    FOut.AppendUInt64LE(LCDOffset);
    FOut.AppendUInt32LE(C_ZIP64_EOCD_LOC_SIG);
    FOut.AppendUInt32LE(0);                  { 本盘号 }
    FOut.AppendUInt64LE(LZ64EocdPos);        { zip64 EOCD 偏移 }
    FOut.AppendUInt32LE(1);                  { 总盘数 }
  end;

  FOut.AppendUInt32LE(C_ZIP_EOCD_SIG);
  FOut.AppendUInt16LE(0);  { 本盘号 }
  FOut.AppendUInt16LE(0);  { central dir 起始盘号 }
  if LCount > C_ZIP_MAX_ENTRIES32 then
    LCountField := $FFFF
  else
    LCountField := LongWord(LCount);
  FOut.AppendUInt16LE(Word(LCountField));
  FOut.AppendUInt16LE(Word(LCountField));
  if LCDSize > C_ZIP_MAX_SIZE32 then
    FOut.AppendUInt32LE(C_ZIP_MAX_SIZE32)
  else
    FOut.AppendUInt32LE(LongWord(LCDSize));
  if LCDOffset > C_ZIP_MAX_SIZE32 then
    FOut.AppendUInt32LE(C_ZIP_MAX_SIZE32)
  else
    FOut.AppendUInt32LE(LongWord(LCDOffset));
  FOut.AppendUInt16LE(0);  { 注释长 }
  FFinished := True;
  Result := FOut.ToBytes;
end;

end.
