unit nextpas.core.zip.writer;
{**
 * @desc ZIP 归档写器实现：local file header + central directory + EOCD，
 *       支持 store 与 deflate（method=8，经 compress.RawDeflate）条目、
 *       目录条目，以及 Zip64：尺寸/偏移/条目数超 ZIP32 宽度时自动启用，
 *       TZipWriteOptions.ForceZip64 可无条件强制。产出任何标准解压器可读的归档。
 *
 * 确定性：未指定时间戳取 DOS 纪元下限，同输入同字节；deflate 载荷由 zlib
 * 版本决定，跨环境不保证字节一致，但始终可被标准解压器还原。
 *
 * 流式输出：StreamOutputTo 绑定任意 IWriter 后逐条目透传（内存上界为单
 * 条目压缩尺寸），FinishTo 直写完整归档；两种模式与缓冲式 Finish 字节级
 * 一致。
 *
 * 描述符直写（INV-15）：AddEntryStream 携带 DataDescriptor 选项时走真流
 * 式路径——local header（bit3+零值占位）立即落盘，压缩字节不经暂存直通
 * 输出管道，Close 补发数据描述符；内存上界降到常数级。描述符条目期间
 * 强制串行化；放弃未关闭的描述符流会在 Finish 时 fail-closed 报错。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.builder,
  nextpas.core.compress.intf,
  nextpas.core.io.intf,
  nextpas.core.zip.base;

type
  {** @desc 写选项：ForceZip64 无条件产出 Zip64 结构（预知超大归档/测试用） *}
  TZipWriteOptions = record
    ForceZip64: Boolean;
  end;

  {** @desc 单条目添加选项：Method 缺省 store；ModTimeUnixSec < 0 取 DOS 纪元
       下限；Mode 为 unix 模式字（S_IFMT|rwx），0 取按条目类型的默认值；
       Password 非空 → 条目走 WinZip AE-2 加密（压缩后加密，wire 方法 99，
       头部 CRC 置 0）；AesStrength 为强度码 1/2/3 = AES-128/192/256，
       0 取默认 3；DataDescriptor 仅对 AddEntryStream 生效——开启后走
       描述符直写模式（INV-15）：local header 携带 bit3 与零值尺寸立即
       落盘，压缩字节不经暂存直接进输出管道，Close 时补发描述符，
       内存上界为常数 *}
  TZipAddOptions = record
    Method: TZipMethod;
    ModTimeUnixSec: Int64;
    Mode: Word;
    Password: TBytes;
    AesStrength: Byte;
    DataDescriptor: Boolean;
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
        载荷不必整体物化，默认内存上界为单条目压缩尺寸；Options.
        DataDescriptor 开启时走描述符直写模式，上界降到常数级。
        Finish 时存在未 Close 的流则 raise。多个未关闭流按各自 Close
        顺序落盘。 *}
    function AddEntryStream(const AName: string;
      const AOptions: TZipAddOptions): ICompressWriter;
    {** 已添加条目数 *}
    function EntryCount: Integer;
    {** 绑定流式输出端：分块排空已暂存字节，此后逐条目透传（内存上界为
        单条目压缩尺寸）；仅允许绑定一次，重复绑定 raise。绑定后 Finish
        拒绝，终结经 FinishTo(同一 sink) 完成。sink 写入异常原样传播，
        失败后写器应整体弃用（归档已不完整）。 *}
    procedure StreamOutputTo(const ASink: IWriter);
    {** 终结并把完整归档直写 ASink，返回写入总字节数；未绑定时等价于
        StreamOutputTo(ASink) 后终结。产出与缓冲式 Finish 字节级一致。
        ASink 为 nil、与已绑定 sink 不同、或存在未关闭条目流时 raise。 *}
    function FinishTo(const ASink: IWriter): UInt64;
    {** 终结并返回完整归档字节；此后各添加方法与 Finish/FinishTo 均 raise；
        已绑定输出端时拒绝（字节已交付 sink） *}
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
  nextpas.core.checksum.crc32,
  nextpas.core.compress.deflate,
  nextpas.core.zip.aes;

const
  C_ZIP64_LOCAL_EXTRA_LEN = 20;  { id(2)+size(2)+原始/压缩尺寸各 8 }
  C_ZIP64_EOCD_BODY_LEN   = 44;  { zip64 EOCD 记录体（不含签名+尺寸前缀 12 字节） }
  C_STREAM_CHUNK = 256 * 1024;   { 暂存排空分块尺寸 }

{ 向 sink 写满 ACount 字节；短写视为输出端故障 }
procedure WriteAllTo(const ASink: IWriter; const ABuf; const ACount: SizeUInt);
var
  LDone: SizeUInt;
begin
  if ACount = 0 then
    Exit;
  LDone := ASink.Write(ABuf, ACount);
  if LDone <> ACount then
    raise EIOError.Create('zip writer: short write to output sink');
end;

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
    FAesStrength: Byte;   { WinZip AES 强度码；0 = 未加密条目 }
    FDescriptor: Boolean; { bit3 描述符条目：central flags 镜像置位 }
  end;

  TZipWriter = class(TInterfacedObject, IZipWriter)
  private
    FOut: IBytesBuilder;  { 缓冲模式暂存；绑定输出端后置 nil，全部走透传 }
    FSink: IWriter;       { 流式输出端；nil = 缓冲模式 }
    FSinkPtr: Pointer;    { 已绑定 sink 的身份指针（FinishTo 异源校验用） }
    FTell: UInt64;        { 累计产出字节数（两种模式统一的位置源） }
    FEntries: array of TZipEntryMeta;
    FCount: Integer;      { 有效条目数；FEntries 按 FCapacity 几何扩容 }
    FCapacity: Integer;
    FFinished: Boolean;
    FForceZip64: Boolean;
    { 未 Close 的流式写入端。弱登记（裸指针，不持引用计数）：
      用户放弃流时对象必然析构并按指针注销；写器只比较/清除指针，
      绝不解引用悬垂指针（在册 ⇔ FOwner<>nil ⇔ 存活外部引用） }
    FOpenSinks: array of Pointer;
    FDirectActive: Boolean;  { 描述符直写条目进行中（串行化守卫） }
    procedure CheckOpen;
    procedure EnsureCapacity(AMinimum: Integer);
    { 字节路由：缓冲模式入暂存 builder，绑定后直写 sink；FTell 同步推进。
      结构化序列化一律经 Emit*，保证两种模式字节级一致 }
    procedure EmitU16(AValue: Word);
    procedure EmitU32(AValue: LongWord);
    procedure EmitU64(AValue: UInt64);
    procedure EmitRaw(const ABuf; ACount: SizeUInt);
    procedure SinkWrite(const ABuf; ACount: SizeUInt);
    procedure DrainStaged(const ASink: IWriter);
    procedure AddEntryInternal(const AName: string; const APayload,
      AData: TBytes; AMethod: Word; const AModTimeUnixSec: Int64;
      AIsDir: Boolean; AMode: Word; const APassword: TBytes;
      AAesStrength: Byte);
    { 条目加密封框：Password 非空时把压缩载荷封成 AE-2 帧（salt+口令校验
      值+密文+认证码），元数据同步调整（CRC 置 0、强度落位）；空口令原样
      返回。真实方法保留在 FMethod，wire 99 由发射层翻译 }
    function SealEntryPayload(var AMeta: TZipEntryMeta;
      const ACompressed: TBytes; const APassword: TBytes;
      AAesStrength: Byte): TBytes;
    procedure AddDirectoryInternal(const AName: string;
      const AModTimeUnixSec: Int64);
    procedure RegisterSink(ASink: TObject);
    procedure UnregisterSink(APtr: Pointer);
    procedure DetachSinks;
    { local header + 压缩载荷落盘（元数据已含全部字段，偏移在此捕获）；
      ADescriptorOpen=True 时发描述符开形态（bit3+零尺寸+zip64 占位），
      载荷参数被忽略 }
    procedure AppendLocalEntry(const AMeta: TZipEntryMeta;
      const APayload: TBytes; ADescriptorOpen: Boolean);
    { 描述符条目收尾：sig+crc+尺寸（按实际宽度 32/64 位），经 Emit 路由 }
    procedure EmitDataDescriptor(const AMeta: TZipEntryMeta);
    { 描述符条目定稿：登记元数据、发描述符并解除直写守卫 }
    procedure CommitDescriptorEntry(AMeta: TZipEntryMeta);
    { 描述符直写进行中时禁止其他条目级操作（保证描述符紧贴本条目数据） }
    procedure CheckNoDirectActive;
    { 流式条目定稿：登记元数据并落盘 local header + 压缩载荷 }
    procedure CommitStreamEntry(AMeta: TZipEntryMeta; const APayload: TBytes);
    { central directory + (zip64 EOCD) + EOCD 经 Emit 路由写出；
      Finish 与 FinishTo 共享的终结序列 }
    procedure EmitCentralAndEocd;
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
    procedure StreamOutputTo(const ASink: IWriter);
    function FinishTo(const ASink: IWriter): UInt64;
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
  Result.Password := nil;
  Result.AesStrength := 3;       { AES-256：加密启用时的默认强度 }
  Result.DataDescriptor := False;
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
  FSink := nil;
  FSinkPtr := nil;
  FTell := 0;
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

{ ---- 字节路由层：两种输出模式的唯一分叉点 ---- }

procedure TZipWriter.SinkWrite(const ABuf; ACount: SizeUInt);
begin
  if ACount = 0 then
    Exit;
  WriteAllTo(FSink, ABuf, ACount);
end;

procedure TZipWriter.EmitU16(AValue: Word);
var
  LB: array[0..1] of Byte;
begin
  if FSink = nil then
    FOut.AppendUInt16LE(AValue)
  else
  begin
    LB[0] := Byte(AValue);
    LB[1] := Byte(AValue shr 8);
    SinkWrite(LB, 2);
  end;
  Inc(FTell, 2);
end;

procedure TZipWriter.EmitU32(AValue: LongWord);
var
  LB: array[0..3] of Byte;
begin
  if FSink = nil then
    FOut.AppendUInt32LE(AValue)
  else
  begin
    LB[0] := Byte(AValue);
    LB[1] := Byte(AValue shr 8);
    LB[2] := Byte(AValue shr 16);
    LB[3] := Byte(AValue shr 24);
    SinkWrite(LB, 4);
  end;
  Inc(FTell, 4);
end;

procedure TZipWriter.EmitU64(AValue: UInt64);
var
  LI: Integer;
  LB: array[0..7] of Byte;
begin
  if FSink = nil then
    FOut.AppendUInt64LE(AValue)
  else
  begin
    for LI := 0 to 7 do
      LB[LI] := Byte(AValue shr (LI * 8));
    SinkWrite(LB, 8);
  end;
  Inc(FTell, 8);
end;

procedure TZipWriter.EmitRaw(const ABuf; ACount: SizeUInt);
begin
  if ACount = 0 then
    Exit;
  if FSink = nil then
    FOut.AppendBytes(PByte(@ABuf), ACount)
  else
    SinkWrite(ABuf, ACount);
  Inc(FTell, ACount);
end;

procedure TZipWriter.DrainStaged(const ASink: IWriter);
var
  LStaged: TBytes;
  LOff, LChunk, LLen: SizeUInt;
begin
  { 排空绑定前暂存的字节。ToBytes 一次性物化——该内容本就驻留内存
    （缓冲模式语义），无额外回退；此后暂存 builder 整体释放 }
  LLen := FOut.Length;
  if LLen = 0 then
    Exit;
  LStaged := FOut.ToBytes;
  LOff := 0;
  while LOff < LLen do
  begin
    LChunk := LLen - LOff;
    if LChunk > C_STREAM_CHUNK then
      LChunk := C_STREAM_CHUNK;
    WriteAllTo(ASink, LStaged[LOff], LChunk);
    Inc(LOff, LChunk);
  end;
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
  Close（或放弃时析构）定稿条目。暂存模式把压缩输出累积在 FBuffer、
  Commit 时一次落盘；描述符直写模式（FDirect，INV-15）把压缩输出经
  TPushSink 即时推入输出管道（可选 AES 封框），内存上界为常数级。
  语义见 IZipWriter.AddEntryStream 注释。 }
type
  TZipEntrySink = class(TInterfacedObject, ICompressWriter)
  private
    FOwner: TZipWriter;          { 弱归属；DetachOwner 置 nil }
    FMeta: TZipEntryMeta;        { Close 时补齐 Crc/USize/CSize/Z64 标记 }
    FTimeUnixSec: Int64;
    FPassword: TBytes;           { 非空 → 定稿走 AE-2 封框 }
    FAesStrength: Byte;
    FCrc: LongWord;
    FUSize: UInt64;
    FBuffer: IBytesBuilder;      { 暂存模式：store 原样 / deflate 压缩输出 }
    FDeflate: ICompressWriter;   { deflate 路径的增量压缩器；store 为 nil }
    FDirect: Boolean;            { 描述符直写模式（INV-15） }
    FSealer: TWinZipAesSealer;   { 直写模式的增量封框器；明文为 nil }
    FCSize: UInt64;              { 直写模式累计已推出的压缩字节数 }
    FScratch: TBytes;            { 加密直推的重用变换缓冲（免逐块分配） }
    FClosed: Boolean;
    procedure FinalizeEntry(AOwner: TZipWriter);
    procedure FinalizeDirect(AOwner: TZipWriter);
    { 压缩字节段直推输出管道；加密时拷入重用缓冲先认证+加密，
      不回写调用方缓冲 }
    procedure PushCompressed(const ABuf; ACount: SizeUInt);
  public
    constructor Create(AOwner: TZipWriter; const AMeta: TZipEntryMeta;
      const ATimeUnixSec: Int64; const APassword: TBytes;
      AAesStrength: Byte);
    destructor Destroy; override;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Flush;
    procedure Close;
    procedure DetachOwner;
  end;

  { 压缩器输出直推适配：deflate 输出段即时进输出管道（弱归属——仅在本
    条目流存活期间被其 FDeflate 接口持有） }
  TPushSink = class(TInterfacedObject, IWriter)
  private
    FSink: TZipEntrySink;
  public
    constructor Create(ASink: TZipEntrySink);
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
  end;

constructor TZipEntrySink.Create(AOwner: TZipWriter; const AMeta: TZipEntryMeta;
  const ATimeUnixSec: Int64; const APassword: TBytes; AAesStrength: Byte);
begin
  inherited Create;
  FOwner := AOwner;
  FMeta := AMeta;
  FTimeUnixSec := ATimeUnixSec;
  FPassword := APassword;
  FAesStrength := AAesStrength;
  FCrc := 0;                     { Crc32Update 标准值语义的运行值 }
  FUSize := 0;
  FCSize := 0;
  FDirect := AMeta.FDescriptor;
  if FDirect then
  begin
    { INV-15 开形态：串行化守卫 → 可选封框器 → local header 立即落盘 →
      salt+pwVerify 头帧。此后压缩字节一律直通输出管道 }
    AOwner.CheckNoDirectActive;
    if FMeta.FAesStrength > 0 then
      FSealer := NewWinZipAesSealer(APassword, FMeta.FAesStrength);
    if FMeta.FMethod = C_ZIP_METHOD_DEFLATE then
      FDeflate := CreateRawDeflateWriter(TPushSink.Create(Self));
    AOwner.AppendLocalEntry(FMeta, nil, True);
    if FSealer <> nil then
      AOwner.EmitRaw(PByte(FSealer.Header)^,
        SizeUInt(Length(FSealer.Header)));
    AOwner.FDirectActive := True;
  end
  else
  begin
    FBuffer := CreateBytesBuilder(4096);
    if AMeta.FMethod = C_ZIP_METHOD_DEFLATE then
      FDeflate := CreateRawDeflateWriter(TBuilderSink.Create(FBuffer));
  end;
end;

procedure TZipEntrySink.DetachOwner;
begin
  FOwner := nil;
end;

destructor TZipEntrySink.Destroy;
begin
  { 显式放弃未关闭的流：仅解除登记，条目不落入归档（见 API 契约）。
    登记为裸指针（弱引用），析构必然可达：用户丢掉最后一个外部
    引用时计数归零走到这里。描述符直写路径故意不复位 FDirectActive——
    已落盘的孤儿字节使归档不完整，Finish 必须 fail-closed }
  if FOwner <> nil then
  begin
    FOwner.UnregisterSink(Pointer(Self));
    FOwner := nil;
  end;
  FSealer.Free;
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
      FDeflate.Write(ABuf, ACount)   { 压缩输出经 TPushSink 回推 }
    else if FDirect then
      PushCompressed(ABuf, ACount)   { store 直写：原样即压缩字节 }
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

constructor TPushSink.Create(ASink: TZipEntrySink);
begin
  inherited Create;
  FSink := ASink;
end;

function TPushSink.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  if ACount > 0 then
    FSink.PushCompressed(ABuf, ACount);
  Result := ACount;
end;

procedure TZipEntrySink.PushCompressed(const ABuf; ACount: SizeUInt);
begin
  if ACount = 0 then
    Exit;
  Inc(FCSize, ACount);
  if FSealer <> nil then
  begin
    { 认证+加密是原地变换：先拷入重用缓冲，绝不回写调用方缓冲 }
    if Length(FScratch) < SizeInt(ACount) then
      SetLength(FScratch, SizeInt(ACount));
    Move(ABuf, FScratch[0], ACount);
    FSealer.Transform(FScratch[0], ACount);
    FOwner.EmitRaw(FScratch[0], ACount);
  end
  else
    FOwner.EmitRaw(ABuf, ACount);
end;

procedure TZipEntrySink.FinalizeDirect(AOwner: TZipWriter);
var
  LMac: TBytes;
begin
  { 压缩终结先把残余压缩字节全部推出，再补认证码尾帧；描述符紧随其后，
    保证描述符与本条目数据在输出流中相邻（INV-15 布局不变量） }
  if FDeflate <> nil then
    FDeflate.Close;
  if FSealer <> nil then
  begin
    LMac := FSealer.Finish;
    AOwner.EmitRaw(PByte(LMac)^, SizeUInt(Length(LMac)));
  end;
  FMeta.FCrc := FCrc;
  FMeta.FUSize := FUSize;
  { 加密直写时 FCSize 只含密文体：补上开形态头帧（salt+pwVerify）与
    尾部认证码，与暂存路径的封框后尺寸同语义 }
  FMeta.FCSize := FCSize;
  if FSealer <> nil then
    Inc(FMeta.FCSize, WinZipAesFrameOverhead(FMeta.FAesStrength));
  { Zip64 判定以最终落盘宽度为准（含 AE 帧开销），与暂存路径一致 }
  FMeta.FNeedsZ64Sizes := AOwner.FForceZip64 or
    (FUSize > C_ZIP_MAX_SIZE32) or (FMeta.FCSize > C_ZIP_MAX_SIZE32);
  AOwner.CommitDescriptorEntry(FMeta);
end;

procedure TZipEntrySink.FinalizeEntry(AOwner: TZipWriter);
var
  LPayload: TBytes;
begin
  LPayload := FBuffer.ToBytes;
  FMeta.FCrc := FCrc;
  FMeta.FUSize := FUSize;
  DosDateTimeFromUnix(FTimeUnixSec, FMeta.FDosDate, FMeta.FDosTime);
  { 加密封框在尺寸判定之前，与缓冲路径同一收敛点（SealEntryPayload） }
  LPayload := AOwner.SealEntryPayload(FMeta, LPayload, FPassword,
    FAesStrength);
  FMeta.FCSize := Length(LPayload);
  FMeta.FNeedsZ64Sizes := AOwner.FForceZip64 or
    (FUSize > C_ZIP_MAX_SIZE32) or
    (UInt64(Length(LPayload)) > C_ZIP_MAX_SIZE32);
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
    if FDirect then
      FinalizeDirect(LOwner)
    else
    begin
      if FDeflate <> nil then
        FDeflate.Close;
      FinalizeEntry(LOwner);
    end;
  finally
    if FOwner <> nil then
    begin
      FOwner.UnregisterSink(Pointer(Self));
      FOwner := nil;
    end;
  end;
end;

{ AE 强度码归一化（一次性/流式/直写三路共用）：未加密返回 0，
  未指定强度缺省 AES-256 }
function ResolveAesStrength(const APassword: TBytes;
  AAesStrength: Byte): Byte; inline;
begin
  if Length(APassword) = 0 then
    Exit(0);
  if AAesStrength = 0 then
    Exit(3);
  Result := AAesStrength;
end;

function TZipWriter.SealEntryPayload(var AMeta: TZipEntryMeta;
  const ACompressed: TBytes; const APassword: TBytes;
  AAesStrength: Byte): TBytes;
begin
  if Length(APassword) = 0 then
    Exit(ACompressed);
  AMeta.FAesStrength := ResolveAesStrength(APassword, AAesStrength);
  AMeta.FCrc := 0;                { AE-2：头部 CRC 置 0，完整性由认证码保证 }
  Result := SealWinZipAesPayload(APassword, AMeta.FAesStrength, ACompressed);
end;

procedure TZipWriter.AddEntryInternal(const AName: string; const APayload,
  AData: TBytes; AMethod: Word; const AModTimeUnixSec: Int64;
  AIsDir: Boolean; AMode: Word; const APassword: TBytes;
  AAesStrength: Byte);
var
  LMeta: TZipEntryMeta;
  LEffName: string;
  LEffIsDir: Boolean;
  LPayload: TBytes;
begin
  CheckOpen;
  CheckNoDirectActive;
  LMeta := Default(TZipEntryMeta);
  ResolveEntrySpec(AName, AIsDir, AMode, LEffName, LEffIsDir,
    LMeta.FExtAttrs);

  LMeta.FNeedsZ64Sizes := False;
  LMeta.FAesStrength := 0;
  LMeta.FName := LEffName;
  LMeta.FMethod := AMethod;
  LMeta.FCrc := Crc32OfBytes(AData);
  LMeta.FUSize := Length(AData);
  DosDateTimeFromUnix(AModTimeUnixSec, LMeta.FDosDate, LMeta.FDosTime);

  { 加密封框在尺寸判定之前：密文含帧开销，Zip64 判定以最终落盘宽度为准 }
  LPayload := SealEntryPayload(LMeta, APayload, APassword, AAesStrength);
  LMeta.FCSize := Length(LPayload);
  LMeta.FNeedsZ64Sizes := FForceZip64 or
    (UInt64(Length(AData)) > C_ZIP_MAX_SIZE32) or
    (UInt64(Length(LPayload)) > C_ZIP_MAX_SIZE32);

  LMeta.FLocalOffset := FTell;
  LMeta.FIsDir := LEffIsDir;

  EnsureCapacity(FCount + 1);
  FEntries[FCount] := LMeta;
  Inc(FCount);

  AppendLocalEntry(LMeta, LPayload, False);
end;

procedure TZipWriter.AppendLocalEntry(const AMeta: TZipEntryMeta;
  const APayload: TBytes; ADescriptorOpen: Boolean);
var
  LVersion, LWireMethod, LExtraLen, LFlags, LZ64Sizes: Integer;
begin
  { 描述符开形态尺寸未知：版本抬到 45 且强制 zip64 占位 extra——流式无法
    回头改写已落盘的头部，只有预先声明 64 位宽度才能容纳事后才知道的
    真实尺寸（对齐 python zipfile 无定位流 + force_zip64 的头部形态） }
  if ADescriptorOpen or AMeta.FNeedsZ64Sizes then
    LVersion := C_ZIP_VERSION_ZIP64
  else
    LVersion := C_ZIP_VERSION_DEFAULT;
  if AMeta.FAesStrength > 0 then
  begin
    LWireMethod := C_ZIP_METHOD_WINZIP_AES;
    if LVersion < C_ZIP_VERSION_AES then
      LVersion := C_ZIP_VERSION_AES;
  end
  else
    LWireMethod := AMeta.FMethod;
  { 加密条目置 general purpose flag bit 0；描述符条目再置 bit3（读端据此
    知道 crc/尺寸以描述符与 central 为准） }
  LFlags := C_ZIP_FLAG_UTF8;
  if AMeta.FAesStrength > 0 then
    LFlags := LFlags or C_ZIP_FLAG_ENCRYPTED;
  if ADescriptorOpen then
    LFlags := LFlags or C_ZIP_FLAG_DESCRIPTOR;

  { local extra：Zip64 尺寸对（20B）与 WinZip AES extra（11B）可并存 }
  LZ64Sizes := Ord(ADescriptorOpen or AMeta.FNeedsZ64Sizes);
  LExtraLen := LZ64Sizes * C_ZIP64_LOCAL_EXTRA_LEN;
  if AMeta.FAesStrength > 0 then
    Inc(LExtraLen, 4 + C_WINZIP_AES_EXTRA_BODY);

  EmitU32(C_ZIP_LOCAL_SIG);
  EmitU16(Word(LVersion));
  EmitU16(Word(LFlags));
  EmitU16(Word(LWireMethod));
  EmitU16(AMeta.FDosTime);
  EmitU16(AMeta.FDosDate);
  if ADescriptorOpen then
    EmitU32(0)                    { CRC 占位 0：真实值在描述符 }
  else
    EmitU32(AMeta.FCrc);
  if LZ64Sizes = 1 then
  begin
    EmitU32(C_ZIP_MAX_SIZE32);    { 实际值在 Zip64 extra 或描述符 }
    EmitU32(C_ZIP_MAX_SIZE32);
  end
  else
  begin
    EmitU32(LongWord(AMeta.FCSize));
    EmitU32(LongWord(AMeta.FUSize));
  end;
  EmitU16(Word(Length(AMeta.FName)));
  EmitU16(Word(LExtraLen));
  if Length(AMeta.FName) > 0 then
    EmitRaw(PByte(Pointer(AMeta.FName))^, SizeUInt(Length(AMeta.FName)));
  if LZ64Sizes = 1 then
  begin
    EmitU16(C_ZIP64_EXTRA_ID);
    EmitU16(16);
    if ADescriptorOpen then
    begin
      EmitU64(0);                 { 尺寸未知，占位零值 }
      EmitU64(0);
    end
    else
    begin
      EmitU64(AMeta.FUSize);
      EmitU64(AMeta.FCSize);
    end;
  end;
  if AMeta.FAesStrength > 0 then
  begin
    EmitU16(C_WINZIP_AES_EXTRA_ID);
    EmitU16(C_WINZIP_AES_EXTRA_BODY);
    EmitRaw(PByte(BuildWinZipAesExtraBody(AMeta.FAesStrength,
      AMeta.FMethod))^, C_WINZIP_AES_EXTRA_BODY);
  end;
  if (Length(APayload) > 0) and (not ADescriptorOpen) then
    EmitRaw(PByte(APayload)^, SizeUInt(Length(APayload)));
end;

procedure TZipWriter.EmitDataDescriptor(const AMeta: TZipEntryMeta);
var
  LZ64: Boolean;
begin
  { 任一尺寸超出 ZIP32 宽度则整个描述符按 64 位发射（字段成对同宽） }
  LZ64 := (AMeta.FCSize > C_ZIP_MAX_SIZE32) or
    (AMeta.FUSize > C_ZIP_MAX_SIZE32);
  EmitU32(C_ZIP_DESCRIPTOR_SIG);
  EmitU32(AMeta.FCrc);
  if LZ64 then
  begin
    EmitU64(AMeta.FCSize);
    EmitU64(AMeta.FUSize);
  end
  else
  begin
    EmitU32(LongWord(AMeta.FCSize));
    EmitU32(LongWord(AMeta.FUSize));
  end;
end;

procedure TZipWriter.CommitDescriptorEntry(AMeta: TZipEntryMeta);
begin
  { 本地偏移已在开形态头部发射前捕获进 FLocalOffset。
    描述符紧贴条目数据补发，携带真实 CRC 与尺寸（对齐 python zipfile：
    即使 AE 条目描述符也写实际值）；AE-2 登记进 central 的头部 CRC
    则置 0（六期契约），两者语义分离 }
  EnsureCapacity(FCount + 1);
  EmitDataDescriptor(AMeta);
  if AMeta.FAesStrength > 0 then
    AMeta.FCrc := 0;
  FEntries[FCount] := AMeta;
  Inc(FCount);
  FDirectActive := False;         { 解除串行化 }
end;

procedure TZipWriter.CheckNoDirectActive;
begin
  if FDirectActive then
    raise EInvalidOperationError.Create(
      'zip writer: descriptor entry stream is active');
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
  AMeta.FLocalOffset := FTell;
  EnsureCapacity(FCount + 1);
  FEntries[FCount] := AMeta;
  Inc(FCount);
  AppendLocalEntry(AMeta, APayload, False);
end;

procedure TZipWriter.AddEntry(const AName: string; const AData: TBytes);
begin
  { DOS 纪元下限：确定性输出（同输入同字节），见单元头注释 }
  AddEntryInternal(AName, AData, AData, C_ZIP_METHOD_STORE, DosMinUnixSec,
    False, 0, nil, 0);
end;

procedure TZipWriter.AddEntryWithTime(const AName: string; const AData: TBytes;
  const AModTimeUnixSec: Int64);
begin
  AddEntryInternal(AName, AData, AData, C_ZIP_METHOD_STORE, AModTimeUnixSec,
    False, 0, nil, 0);
end;

procedure TZipWriter.AddEntryDeflate(const AName: string; const AData: TBytes);
var
  LPayload: TBytes;
begin
  LPayload := RawDeflateCompress(AData);
  AddEntryInternal(AName, LPayload, AData, C_ZIP_METHOD_DEFLATE,
    DosMinUnixSec, False, 0, nil, 0);
end;

procedure TZipWriter.AddEntryDeflateWithTime(const AName: string;
  const AData: TBytes; const AModTimeUnixSec: Int64);
var
  LPayload: TBytes;
begin
  LPayload := RawDeflateCompress(AData);
  AddEntryInternal(AName, LPayload, AData, C_ZIP_METHOD_DEFLATE,
    AModTimeUnixSec, False, 0, nil, 0);
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
    (Length(AName) > 0) and (AName[Length(AName)] = '/'), AOptions.Mode,
    AOptions.Password, AOptions.AesStrength);
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
  { 描述符条目期间任何新流都不得插入（暂存式同样会在 Close 时落盘，
    会插进描述符与本条目描述符之间） }
  CheckNoDirectActive;
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
  LMeta := Default(TZipEntryMeta);
  LMeta.FName := LEffName;
  LMeta.FMethod := LMethod;
  LMeta.FExtAttrs := LExtAttrs;
  LMeta.FIsDir := LEffIsDir;
  LMeta.FDescriptor := AOptions.DataDescriptor;
  { DOS 时间前置计算：描述符开形态头部立即落盘，没有定稿时机再补 }
  DosDateTimeFromUnix(LTime, LMeta.FDosDate, LMeta.FDosTime);
  if LMeta.FDescriptor then
  begin
    { 强度提前解析：开形态头部需要 AE extra 与 bit0 标志 }
    LMeta.FAesStrength := ResolveAesStrength(AOptions.Password,
      AOptions.AesStrength);
    LMeta.FLocalOffset := FTell;  { 开形态头部起点即本地偏移 }
  end;
  LSink := TZipEntrySink.Create(Self, LMeta, LTime, AOptions.Password,
    AOptions.AesStrength);
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
    0, nil, 0);
end;

function TZipWriter.EntryCount: Integer;
begin
  Result := FCount;
end;

{ central directory + (zip64 EOCD) + EOCD：Finish 与 FinishTo 共享的终结
  序列，全部经 Emit 路由——两种输出模式字节级一致的结构保证 }
procedure TZipWriter.EmitCentralAndEocd;
var
  LI: Integer;
  LE: TZipEntryMeta;
  LCDOffset, LCDSize, LCDEnd, LZ64EocdPos: UInt64;
  LCount: Int64;  LNeedsZ64Offset, LAnyZ64, LNeedZ64Eocd: Boolean;
  LVersionMadeBy, LVersionNeeded: Word;
  LExtraLen, LZ64BodyLen, LCFlags: Integer;
  LCountField: LongWord;
begin
  LCDOffset := FTell;
  for LI := 0 to FCount - 1 do
  begin
    LE := FEntries[LI];
    LNeedsZ64Offset := FForceZip64 or (LE.FLocalOffset > C_ZIP_MAX_SIZE32);
    LAnyZ64 := LE.FNeedsZ64Sizes or LNeedsZ64Offset;    if LAnyZ64 then
    begin
      LVersionMadeBy := C_ZIP_MADE_BY_HOST_UNIX or C_ZIP_VERSION_ZIP64;
      LVersionNeeded := C_ZIP_VERSION_ZIP64;
    end
    else
    begin
      LVersionMadeBy := C_ZIP_MADE_BY_HOST_UNIX or C_ZIP_VERSION_DEFAULT;
      LVersionNeeded := C_ZIP_VERSION_DEFAULT;
    end;
    if (LE.FAesStrength > 0) and (LVersionNeeded < C_ZIP_VERSION_AES) then
      LVersionNeeded := C_ZIP_VERSION_AES;

    EmitU32(C_ZIP_CENTRAL_SIG);
    EmitU16(LVersionMadeBy);
    EmitU16(LVersionNeeded);
    { central flags 与 local 镜像：bit0 加密 + bit3 描述符 + bit11 UTF8 }
    LCFlags := C_ZIP_FLAG_UTF8;
    if LE.FAesStrength > 0 then
      LCFlags := LCFlags or C_ZIP_FLAG_ENCRYPTED;
    if LE.FDescriptor then
      LCFlags := LCFlags or C_ZIP_FLAG_DESCRIPTOR;
    EmitU16(Word(LCFlags));
    if LE.FAesStrength > 0 then
      EmitU16(C_ZIP_METHOD_WINZIP_AES)
    else
      EmitU16(LE.FMethod);
    EmitU16(LE.FDosTime);
    EmitU16(LE.FDosDate);
    EmitU32(LE.FCrc);
    if LE.FNeedsZ64Sizes then
    begin
      EmitU32(C_ZIP_MAX_SIZE32);
      EmitU32(C_ZIP_MAX_SIZE32);
    end
    else
    begin
      EmitU32(LongWord(LE.FCSize));
      EmitU32(LongWord(LE.FUSize));
    end;
    EmitU16(Word(Length(LE.FName)));
    { central extra：Zip64（内容宽随字段）与 WinZip AES extra（11B）可并存 }
    LZ64BodyLen := 0;
    if LE.FNeedsZ64Sizes then
      Inc(LZ64BodyLen, 16);
    if LNeedsZ64Offset then
      Inc(LZ64BodyLen, 8);
    LExtraLen := LZ64BodyLen;
    if LZ64BodyLen > 0 then
      Inc(LExtraLen, 4);
    if LE.FAesStrength > 0 then
      Inc(LExtraLen, 4 + C_WINZIP_AES_EXTRA_BODY);
    EmitU16(Word(LExtraLen));
    EmitU16(0);  { comment len }
    EmitU16(0);  { disk number start }
    EmitU16(0);  { internal attrs }
    EmitU32(LE.FExtAttrs);
    if LNeedsZ64Offset then
      EmitU32(C_ZIP_MAX_SIZE32)
    else
      EmitU32(LongWord(LE.FLocalOffset));
    { central 布局固定顺序：固定字段、文件名、extra、注释 }
    if Length(LE.FName) > 0 then
      EmitRaw(PByte(Pointer(LE.FName))^, SizeUInt(Length(LE.FName)));
    if LZ64BodyLen > 0 then
    begin
      EmitU16(C_ZIP64_EXTRA_ID);
      EmitU16(Word(LZ64BodyLen));
      { APPNOTE 固定顺序：原始尺寸、压缩尺寸、本地头偏移 }
      if LE.FNeedsZ64Sizes then
      begin
        EmitU64(LE.FUSize);
        EmitU64(LE.FCSize);
      end;
      if LNeedsZ64Offset then
        EmitU64(LE.FLocalOffset);
    end;
    if LE.FAesStrength > 0 then
    begin
      EmitU16(C_WINZIP_AES_EXTRA_ID);
      EmitU16(C_WINZIP_AES_EXTRA_BODY);
      EmitRaw(PByte(BuildWinZipAesExtraBody(LE.FAesStrength,
        LE.FMethod))^, C_WINZIP_AES_EXTRA_BODY);
    end;
  end;

  { central 尺寸必须在写 EOCD 前固化，否则会把 EOCD 自身前缀计入 }
  LCDEnd := FTell;
  LCDSize := LCDEnd - LCDOffset;
  { 注意用有效条目数而非容量（几何扩容后 Length(FEntries) 可能偏大） }
  LCount := FCount;

  LNeedZ64Eocd := FForceZip64 or (LCount > C_ZIP_MAX_ENTRIES32) or
    (LCDSize > C_ZIP_MAX_SIZE32) or (LCDOffset > C_ZIP_MAX_SIZE32);
  if LNeedZ64Eocd then
  begin
    LZ64EocdPos := FTell;
    EmitU32(C_ZIP64_EOCD_SIG);
    EmitU64(C_ZIP64_EOCD_BODY_LEN);
    EmitU16(C_ZIP_MADE_BY_HOST_UNIX or C_ZIP_VERSION_ZIP64);
    EmitU16(C_ZIP_VERSION_ZIP64);
    EmitU32(0);                  { 本盘号 }
    EmitU32(0);                  { central dir 起始盘号 }
    EmitU64(UInt64(LCount));     { 本盘条目数 }
    EmitU64(UInt64(LCount));     { 总条目数 }
    EmitU64(LCDSize);
    EmitU64(LCDOffset);
    EmitU32(C_ZIP64_EOCD_LOC_SIG);
    EmitU32(0);                  { 本盘号 }
    EmitU64(LZ64EocdPos);        { zip64 EOCD 偏移 }
    EmitU32(1);                  { 总盘数 }
  end;

  EmitU32(C_ZIP_EOCD_SIG);
  EmitU16(0);  { 本盘号 }
  EmitU16(0);  { central dir 起始盘号 }
  if LCount > C_ZIP_MAX_ENTRIES32 then
    LCountField := $FFFF
  else
    LCountField := LongWord(LCount);
  EmitU16(Word(LCountField));
  EmitU16(Word(LCountField));
  if LCDSize > C_ZIP_MAX_SIZE32 then
    EmitU32(C_ZIP_MAX_SIZE32)
  else
    EmitU32(LongWord(LCDSize));
  if LCDOffset > C_ZIP_MAX_SIZE32 then
    EmitU32(C_ZIP_MAX_SIZE32)
  else
    EmitU32(LongWord(LCDOffset));
  EmitU16(0);  { 注释长 }
end;

function TZipWriter.Finish: TBytes;
begin
  CheckOpen;
  if FSink <> nil then
    raise EInvalidOperationError.Create('zip writer: output sink bound');
  if Length(FOpenSinks) > 0 then
    raise EInvalidOperationError.Create(
      'zip writer: streaming entry not closed');
  { 直写条目被放弃时其字节已进输出流但描述符未补：归档不完整，
    fail-closed 拒绝终结（暂存模式无此形态，弃流不留痕迹） }
  if FDirectActive then
    raise EInvalidOperationError.Create(
      'zip writer: descriptor entry abandoned');
  EmitCentralAndEocd;
  FFinished := True;
  Result := FOut.ToBytes;
end;

procedure TZipWriter.StreamOutputTo(const ASink: IWriter);
begin
  CheckOpen;
  { 描述符条目数据尚未收尾：此刻绑定会插队进条目字节流中间 }
  CheckNoDirectActive;
  if ASink = nil then
    raise EArgumentError.Create('zip writer: nil output sink');
  if FSink <> nil then
    raise EInvalidOperationError.Create(
      'zip writer: output sink already bound');
  DrainStaged(ASink);
  FOut := nil;   { 暂存释放；此后所有产出一律透传 }
  FSink := ASink;
  FSinkPtr := Pointer(ASink);
end;

function TZipWriter.FinishTo(const ASink: IWriter): UInt64;
begin
  CheckOpen;
  if ASink = nil then
    raise EArgumentError.Create('zip writer: nil output sink');
  if Length(FOpenSinks) > 0 then
    raise EInvalidOperationError.Create(
      'zip writer: streaming entry not closed');
  if FDirectActive then
    raise EInvalidOperationError.Create(
      'zip writer: descriptor entry abandoned');
  if FSink = nil then
    StreamOutputTo(ASink)
  else if Pointer(ASink) <> FSinkPtr then
    raise EInvalidOperationError.Create(
      'zip writer: finish sink differs from bound sink');
  EmitCentralAndEocd;
  FFinished := True;
  Result := FTell;
end;

end.
