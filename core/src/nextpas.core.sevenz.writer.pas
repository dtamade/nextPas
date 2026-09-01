unit nextpas.core.sevenz.writer;

{**
 * nextpas.core.sevenz.writer - 7z 归档写端实现
 *
 * 单 solid folder 布局：全部文件内容顺序拼接为一条码流，可选预过滤
 * 链（BCJ x86 / Delta，按声明顺序逐级作用）后经 LZMA2 压缩；设置口令
 * 时在编码链末端追加 AES-256 加密（solid 与编码头 folder 同受保护，
 * 随机 IV 使输出不再逐字节确定）。主头默认编码为 kEncodedHeader，
 * 可切回明文。条目名安全规则仿 zip：拒空名、
 * 绝对路径、反斜杠与 ".." 路径段。未显式给定的时间戳取确定性缺省
 * （Unix 纪元），同输入序列产出逐字节相同的归档。摘要一律按格式规范
 * 以小端落盘。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.sevenz.intf;

type
  TEntrySource = (esBytes, esReader);
  { 单条目暂存：Finish 前目录与元数据驻留，文件内容按源类型在 BuildArchive 时物化 }
  TEntryRec = record
    Name: string;
    IsDir: Boolean;
    Source: TEntrySource;
    Data: TBytes;          { esBytes 时有效 }
    Reader: IReader;       { esReader 时有效 }
    ReaderSize: UInt64;    { esReader 时声明尺寸 }
    HasMTime: Boolean;
    MTimeUnixSec: Int64;
  end;

  { folder 内单个 coder 的序列化规格：方法 ID / 属性 / 解码输出尺寸 }
  TCoderSpec = record
    MethodId: UInt64;
    Props: TBytes;
    OutSize: UInt64;
  end;

  {** @desc ISevenZWriter 默认实现 *}
  TSevenZWriterImpl = class(TInterfacedObject, ISevenZWriter)
  private
    FEntries: array of TEntryRec;
    FFinished: Boolean;
    FEncodeHeader: Boolean;
    FFilters: array of TSevenZFilter;
    FLevel: TSevenZCompressionLevel;
    FForcedMethodId: UInt64;
    FHasForcedMethod: Boolean;
    FPassword: string;
    FMaxFolderBytes: UInt64;
    FMaxFilesPerFolder: Integer;
    FProgress: TSevenZProgressEvent;
    procedure CheckOpen;
    { 序列化四段：签名头 / solid pack 流（多 folder 时为多段拼接） /
      编码头流 / 头块。明文头模式无第三段；由 Finish 与 FinishTo 共用 }
    procedure BuildArchive(out ASig, APacked, AHdrStream, ABlock: TBytes);
  public
    { TInterfacedObject.Create 为静态：reintroduce 注入默认编码头开关 }
    constructor Create; reintroduce;
    procedure AddFile(const AName: string; const AData: TBytes);
    procedure AddFileWithTime(const AName: string; const AData: TBytes;
      const AMTimeUnixSec: Int64);
    { H-08: AReader 为惰性源，Finish 时才物化；声明尺寸 ASize 不在此刻读
      取（eager 炸弹防御已在 reader 批处理）。若 ASize 超大（如
      > SEVENZ_MAX_UNPACK_SIZE / 8 GiB），建议调用方提前限额拒绝，
      最终以 Finish 物化时的 undersized/oversized 校验为准 }
    procedure AddFileFromReader(const AName: string; const AReader: IReader;
      ASize: UInt64);
    procedure AddFileFromReaderWithTime(const AName: string; const AReader: IReader;
      ASize: UInt64; const AMTimeUnixSec: Int64);
    procedure AddDirectory(const AName: string);
    procedure AddDirectoryWithTime(const AName: string;
      const AMTimeUnixSec: Int64);
    procedure SetEncodeHeader(AEnabled: Boolean);
    procedure SetFilters(const AFilters: array of TSevenZFilter);
    procedure SetLevel(ALevel: TSevenZCompressionLevel);
    procedure SetMethod(AMethodId: UInt64);
    procedure SetPassword(const APassword: string);
    procedure SetFolderLimits(AMaxUncompressedBytes: UInt64;
      AMaxFilesPerFolder: Integer);
    procedure SetProgress(AProgress: TSevenZProgressEvent);
    function EntryCount: Integer;
    function Finish: TBytes;
    function FinishTo(const ASink: IWriter): Int64;
  end;

  {** @desc 流式 Builder：链式装配，一次性 Finish *}
  TSevenZWriterBuilderImpl = class(TInterfacedObject, ISevenZWriterBuilder)
  private
    FWriter: ISevenZWriter;
    FImpl: TSevenZWriterImpl;
    FFinished: Boolean;
    FProgress: TSevenZProgressEvent;
    procedure ApplyProgress;
    procedure CheckNotFinished;
  public
    constructor Create; reintroduce;
    function AddFile(const AName: string; const AData: TBytes): ISevenZWriterBuilder;
    function AddFileWithTime(const AName: string; const AData: TBytes;
      const AMTimeUnixSec: Int64): ISevenZWriterBuilder;
    function AddFileFromReader(const AName: string; const AReader: IReader;
      ASize: UInt64): ISevenZWriterBuilder;
    function AddFileFromReaderWithTime(const AName: string; const AReader: IReader;
      ASize: UInt64; const AMTimeUnixSec: Int64): ISevenZWriterBuilder;
    function AddDirectory(const AName: string): ISevenZWriterBuilder;
    function AddDirectoryWithTime(const AName: string;
      const AMTimeUnixSec: Int64): ISevenZWriterBuilder;
    function WithFilters(const AFilters: array of TSevenZFilter): ISevenZWriterBuilder;
    function WithLevel(ALevel: TSevenZCompressionLevel): ISevenZWriterBuilder;
    function WithMethod(AMethodId: UInt64): ISevenZWriterBuilder;
    function WithPassword(const APassword: string): ISevenZWriterBuilder;
    function WithFolderLimits(AMaxUncompressedBytes: UInt64;
      AMaxFilesPerFolder: Integer): ISevenZWriterBuilder;
    function WithEncodeHeader(AEnabled: Boolean): ISevenZWriterBuilder;
    function WithProgress(AProgress: TSevenZProgressEvent): ISevenZWriterBuilder;
    function AddTree(const AHostDir: string; const AArchivePrefix: string): ISevenZWriterBuilder;
    function AddTreeWithFilter(const AHostDir: string; const AArchivePrefix: string;
      const AFilter: string): ISevenZWriterBuilder;
    function AddFileFromFs(const AHostPath: string; const AArchiveName: string): ISevenZWriterBuilder;
    function Build: ISevenZWriter;
    function Finish: TBytes;
    function FinishTo(const ASink: IWriter): Int64;
    function TryFinish(out AArchive: TBytes): Boolean;
    function TryFinishTo(const ASink: IWriter; out ABytesWritten: Int64): Boolean;
    function TryFinishWithError(out AArchive: TBytes; out AError: string): Boolean;
    function TryFinishToWithError(const ASink: IWriter; out ABytesWritten: Int64; out AError: string): Boolean;
    function TryAddTree(const AHostDir: string; const AArchivePrefix: string; out AError: string): Boolean;
    function TryAddTreeWithFilter(const AHostDir: string; const AArchivePrefix: string; const AFilter: string; out AError: string): Boolean;
    function TryAddFileFromFs(const AHostPath: string; const AArchiveName: string; out AError: string): Boolean;
  end;

function SevenZCreateWriterBuilder: ISevenZWriterBuilder;

implementation

uses
  nextpas.core.bytes.pathvalid,
  nextpas.core.errors,
  nextpas.core.exception,
  nextpas.core.bytes.ops,
  nextpas.core.bytes.builder,
  nextpas.core.checksum.crc32,
  nextpas.core.compress,
  nextpas.core.compress.bzip2,
  nextpas.core.crypto.random,
  nextpas.core.sevenz.base,
  nextpas.core.sevenz.header,
  nextpas.core.sevenz.coders,
  nextpas.core.sevenz.aes,
  nextpas.core.sevenz.filters,
  nextpas.core.sevenz.lzma.encoder,
  nextpas.core.sevenz.levels,
  nextpas.core.platform.thread,
  nextpas.core.text.conv,
  nextpas.core.sevenz.fs;

type
  TBytes = nextpas.core.base.TBytes;

  TFolderBuild = record
    RawSolid: TBytes;
    PackedData: TBytes;
    Specs: array of TCoderSpec;
    SubCount: UInt64;
    SubSizes: array of UInt64;
    SubCrcs: array of UInt32;
  end;

const
  C_MAX_PARALLEL_THREADS = 8;

{ 单 folder 压缩内核：过滤链（零拷贝直连 RawSolid）+ 压缩器
  预过滤与压缩均在此完成，加密由调用方串行追加。PFolder^.RawSolid
  只读，PFolder^.PackedData/Specs 由本过程填充；每调用创建 fresh
  LZMA 编码器，天然线程安全，串并行共用同一路径
  性能：外联避免 I-Cache 膨胀（设计规范路由体禁 inline） }
procedure EncodeFolderCore(var AFolder: TFolderBuild;
  const AFilters: array of TSevenZFilter;
  ALevel: TSevenZCompressionLevel; AForcedId: UInt64; AHasForced: Boolean);
var
  LRawChunk: TBytes;
  LStage: TBytes;
  LEnc: TSevenZLzmaEncoded;
  LEncoder: ISevenZLzmaEncoder;
  LI: SizeInt;
begin
  LRawChunk := AFolder.RawSolid;
  if Length(AFilters) = 0 then
  begin
    LStage := LRawChunk;
    SetLength(AFolder.Specs, 1);
  end
  else
  begin
    // perf: 避免过滤器链触发时额外全量 LRawChunk->LStage 拷贝稀释 Move+CRC 单遍收益。
    // 策略：复用 SEVENZ_WRITER_CHUNK 单源阈值（limits），首级过滤器与拷贝融合。
    // Delta 首级采用 SevenZDeltaEncode 零分配 out-of-place 路径，直接由 LRawChunk 产出 LStage，无单独 Move；
    // BCJ 首级仍需在位变换，采用分块搬运（同 MoveWithCrc 粒度）后原地转换，保持缓存友好。
    // 后续各级过滤器仍在 LStage 上原地变换。bench 可观测：bench_sevenz 的 container create / bcj/delta 吞吐为回归锚点。
    SetLength(AFolder.Specs, Length(AFilters) + 1);
    for LI := 0 to High(AFilters) do
    begin
      AFolder.Specs[LI].MethodId := SevenZFilterMethodId(AFilters[LI]);
      AFolder.Specs[LI].Props := SevenZFilterDefaultProps(AFilters[LI]);
    end;
    if AFilters[0] = szfDelta then
    begin
      // Delta 首级零拷贝融合：单遍由 LRawChunk 直接编码为 LStage，避免 SetLength+Move 全量拷贝
      LStage := SevenZDeltaEncode(AFolder.Specs[0].Props, LRawChunk);
      for LI := 1 to High(AFilters) do
        SevenZFilterConvert(LStage, AFilters[LI], AFolder.Specs[LI].Props, True);
    end
    else
    begin
      // perf: BCJ 需要可变缓冲；单源 bytes.ops SpanClone 做单次 SetLength+Move，无分块循环开销（inline 单遍遍历）
      LStage := SpanClone(TByteSpan.FromBytes(LRawChunk));
      SevenZFilterConvert(LStage, AFilters[0], AFolder.Specs[0].Props, True);
      for LI := 1 to High(AFilters) do
        SevenZFilterConvert(LStage, AFilters[LI], AFolder.Specs[LI].Props, True);
    end;
  end;
  if AHasForced then
  begin
    case AForcedId of
      SEVENZ_METHOD_COPY:
        begin
          // perf: Move 语义零拷贝转移 LStage -> PackedData，无额外堆分配/拷贝
          AFolder.PackedData := LStage;
          LStage := nil;
          AFolder.Specs[High(AFolder.Specs)].MethodId := SEVENZ_METHOD_COPY;
          AFolder.Specs[High(AFolder.Specs)].Props := nil;
          AFolder.Specs[High(AFolder.Specs)].OutSize := UInt64(Length(AFolder.PackedData));
        end;
      SEVENZ_METHOD_LZMA2:
        begin
          LEncoder := TSevenZLzmaEncoderPascal.Create;
          if ALevel = szclNone then
            LEnc := LEncoder.EncodeLzma2(LStage, szclDefault)
          else
            LEnc := LEncoder.EncodeLzma2(LStage, ALevel);
          AFolder.PackedData := LEnc.PackedData;
          AFolder.Specs[High(AFolder.Specs)].MethodId := SEVENZ_METHOD_LZMA2;
          AFolder.Specs[High(AFolder.Specs)].Props := LEnc.Props;
          AFolder.Specs[High(AFolder.Specs)].OutSize := UInt64(Length(LStage));
        end;
      SEVENZ_METHOD_DEFLATE:
        begin
          AFolder.PackedData := DeflateRawCompress(LStage,
            SevenZLevelOrdToDeflateLevel(Ord(ALevel)));
          AFolder.Specs[High(AFolder.Specs)].MethodId := SEVENZ_METHOD_DEFLATE;
          AFolder.Specs[High(AFolder.Specs)].Props := nil;
          AFolder.Specs[High(AFolder.Specs)].OutSize := UInt64(Length(LStage));
        end;
      SEVENZ_METHOD_BZIP2:
        begin
          AFolder.PackedData := BZip2Compress(LStage,
            SevenZLevelOrdToBZip2BlockSize(Ord(ALevel)));
          AFolder.Specs[High(AFolder.Specs)].MethodId := SEVENZ_METHOD_BZIP2;
          AFolder.Specs[High(AFolder.Specs)].Props := nil;
          AFolder.Specs[High(AFolder.Specs)].OutSize := UInt64(Length(LStage));
        end;
    end;
  end
  else if ALevel = szclNone then
  begin
    // perf: Move 语义零拷贝转移 LStage -> PackedData，szclNone 默认直通无压缩
    AFolder.PackedData := LStage;
    LStage := nil;
    AFolder.Specs[High(AFolder.Specs)].MethodId := SEVENZ_METHOD_COPY;
    AFolder.Specs[High(AFolder.Specs)].Props := nil;
    AFolder.Specs[High(AFolder.Specs)].OutSize := UInt64(Length(AFolder.PackedData));
  end
  else
  begin
    LEncoder := TSevenZLzmaEncoderPascal.Create;
    LEnc := LEncoder.EncodeLzma2(LStage, ALevel);
    AFolder.PackedData := LEnc.PackedData;
    AFolder.Specs[High(AFolder.Specs)].MethodId := SEVENZ_METHOD_LZMA2;
    AFolder.Specs[High(AFolder.Specs)].Props := LEnc.Props;
    AFolder.Specs[High(AFolder.Specs)].OutSize := UInt64(Length(LStage));
  end;
  for LI := 0 to High(AFilters) do
    AFolder.Specs[LI].OutSize := UInt64(Length(LRawChunk));
end;

type
  { 多 folder 并行压缩 job：平台线程驱动（nextpas.core.platform.thread），
    每 job 独立负责 folder 的过滤链+压缩，加密段由主线程串行追加，避免 CSPRNG 竞争 }
  PFolderEncodeJob = ^TFolderEncodeJob;
  TFolderEncodeJob = record
    Folder: ^TFolderBuild;
    Filters: array of TSevenZFilter;
    Level: TSevenZCompressionLevel;
    ForcedId: UInt64;
    HasForced: Boolean;
    ErrMsg: string;
    HasErr: Boolean;
  end;

function FolderEncodeJobWorker(AArg: Pointer): Pointer; cdecl;
var
  LJob: PFolderEncodeJob;
begin
  Result := nil;
  LJob := PFolderEncodeJob(AArg);
  if LJob = nil then Exit;
  try
    EncodeFolderCore(LJob^.Folder^, LJob^.Filters, LJob^.Level, LJob^.ForcedId, LJob^.HasForced);
  except
    on E: Exception do
    begin
      LJob^.HasErr := True;
      LJob^.ErrMsg := E.ClassName + ': ' + E.Message;
    end;
  end;
end;

const
  { 未指定时间戳的确定性缺省：Unix 纪元 1970-01-01T00:00:00Z }
  C_DEFAULT_MTIME_UNIX = Int64(0);

  { AES 写端缺省档位：与参考写端一致（19 轮 KDF） }
  C_AES_CYCLES_POWER = 19;

{ 条目名安全检查：单源复用 bytes.pathvalid.BytesValidPath，附加 NUL/反斜杠禁令（BytesValidPath 视反斜杠为普通字符） }
procedure ValidateEntryName(const AName: string); inline;
begin
  if AName = '' then
    raise EArgumentError.Create('entry name must not be empty');
  if Pos(#0, AName) > 0 then
    raise EArgumentError.Create('entry name must not contain NUL');
  if Pos('\', AName) > 0 then
    raise EArgumentError.CreateFmt(
      'entry name "%s" must not contain backslash', [AName]);
  // perf: inline + zero-copy BytesValidPath (text.utf8 UTF8IsValid 单源，段扫描无 Copy)，复用 bytes.ops 语义，bench 可观测
  if not BytesValidPath(AName, False) then
    raise EArgumentError.CreateFmt(
      'entry name "%s" is invalid (must be ValidPath: no leading/trailing slash, no empty segment, no "." or "..")', [AName]);
end;

{ 位向量：每字节 8 位、高位在前、尾部补零；与读端 ReadBoolVector 对称 }
procedure AppendBoolVector(var AOut: TBytes; const AVals: array of Boolean);
var
  LByteIdx: SizeInt;
  LBit: Integer;
  LB: Byte;
begin
  { 向上取整：ceil(N/8) = (N+7) div 8 }
  for LByteIdx := 0 to (Length(AVals) + 7) div 8 - 1 do
  begin
    LB := 0;
    for LBit := 0 to 7 do
      if (LByteIdx * 8 + LBit < Length(AVals)) and
         AVals[LByteIdx * 8 + LBit] then
        LB := LB or Byte(1 shl (7 - LBit));
    SevenZAppendByte(AOut, LB);
  end;
end;

{ 全定义捷径位向量（BoolVector2 首字节非零即全真） }
procedure AppendBoolVector2AllDefined(var AOut: TBytes; ACount: SizeInt);
begin
  if ACount > 0 then
    SevenZAppendByte(AOut, $01);
end;

function CountTrue(const AFlags: array of Boolean): SizeInt;
var
  LI: SizeInt;
begin
  Result := 0;
  for LI := 0 to High(AFlags) do
    if AFlags[LI] then
      Inc(Result);
end;

{ TSevenZWriterImpl }

constructor TSevenZWriterImpl.Create;
begin
  inherited Create;
  FEncodeHeader := True;   { 与参考实现生态一致：默认压缩主头 }
  FLevel := szclDefault;
end;

procedure TSevenZWriterImpl.CheckOpen;
begin
  if FFinished then
    raise ESevenZError.Create('writer already finished');
end;

procedure TSevenZWriterImpl.SetEncodeHeader(AEnabled: Boolean);
begin
  CheckOpen;
  FEncodeHeader := AEnabled;
end;

procedure TSevenZWriterImpl.SetFilters(const AFilters: array of TSevenZFilter);
var
  LI: SizeInt;
begin
  CheckOpen;
  if Length(AFilters) > C_MAX_FILTERS then
    raise EArgumentError.CreateFmt(
      'filter chain depth %d exceeds maximum %d',
      [Length(AFilters), C_MAX_FILTERS]);
  SetLength(FFilters, Length(AFilters));
  for LI := 0 to High(AFilters) do
    FFilters[LI] := AFilters[LI];
end;

procedure TSevenZWriterImpl.SetLevel(ALevel: TSevenZCompressionLevel);
begin
  CheckOpen;
  FLevel := ALevel;
  FHasForcedMethod := False;
end;

procedure TSevenZWriterImpl.SetMethod(AMethodId: UInt64);
begin
  CheckOpen;
  case AMethodId of
    SEVENZ_METHOD_COPY,
    SEVENZ_METHOD_LZMA2,
    SEVENZ_METHOD_DEFLATE,
    SEVENZ_METHOD_BZIP2: ;
  else
    raise EArgumentError.CreateFmt('writer method %s not supported yet (only Copy/LZMA2/Deflate/BZip2)', [SevenZMethodName(AMethodId)]);
  end;
  FForcedMethodId := AMethodId;
  FHasForcedMethod := True;
end;

procedure TSevenZWriterImpl.SetPassword(const APassword: string);
begin
  CheckOpen;
  FPassword := APassword;
end;

procedure TSevenZWriterImpl.SetFolderLimits(AMaxUncompressedBytes: UInt64;
  AMaxFilesPerFolder: Integer);
begin
  CheckOpen;
  if AMaxFilesPerFolder < 0 then
    raise EArgumentError.Create('max files per folder must not be negative');
  FMaxFolderBytes := AMaxUncompressedBytes;
  FMaxFilesPerFolder := AMaxFilesPerFolder;
end;

procedure TSevenZWriterImpl.SetProgress(AProgress: TSevenZProgressEvent);
begin
  CheckOpen;
  FProgress := AProgress;
end;

procedure TSevenZWriterImpl.AddFile(const AName: string; const AData: TBytes);
begin
  AddFileWithTime(AName, AData, C_DEFAULT_MTIME_UNIX);
end;

procedure TSevenZWriterImpl.AddFileWithTime(const AName: string;
  const AData: TBytes; const AMTimeUnixSec: Int64);
var
  LE: TEntryRec;
begin
  CheckOpen;
  ValidateEntryName(AName);
  LE := Default(TEntryRec);
  LE.Name := AName;
  LE.IsDir := False;
  LE.Source := esBytes;
  if Length(AData) > 0 then
  begin
    SetLength(LE.Data, Length(AData));
    Move(AData[0], LE.Data[0], Length(AData));
  end;
  LE.HasMTime := True;
  LE.MTimeUnixSec := AMTimeUnixSec;
  SetLength(FEntries, Length(FEntries) + 1);
  FEntries[High(FEntries)] := LE;
end;

procedure TSevenZWriterImpl.AddFileFromReader(const AName: string;
  const AReader: IReader; ASize: UInt64);
begin
  AddFileFromReaderWithTime(AName, AReader, ASize, C_DEFAULT_MTIME_UNIX);
end;

procedure TSevenZWriterImpl.AddFileFromReaderWithTime(const AName: string;
  const AReader: IReader; ASize: UInt64; const AMTimeUnixSec: Int64);
var
  LE: TEntryRec;
begin
  CheckOpen;
  ValidateEntryName(AName);
  if AReader = nil then
    raise EArgumentError.Create('AddFileFromReader: AReader is nil');
  // H-08: 仅记录声明，不在此刻物化；大 ASize 提前限额提示：
  // 调用方可对照 SEVENZ_MAX_UNPACK_SIZE / SEVENZ_DEFAULT_MAX_OUTPUT
  // 做早期拒绝，避免 Finish 时才暴露的 OOM/炸弹风险，最终校验在 Finish
  LE := Default(TEntryRec);
  LE.Name := AName;
  LE.IsDir := False;
  LE.Source := esReader;
  LE.Reader := AReader;
  LE.ReaderSize := ASize;
  LE.HasMTime := True;
  LE.MTimeUnixSec := AMTimeUnixSec;
  SetLength(FEntries, Length(FEntries) + 1);
  FEntries[High(FEntries)] := LE;
end;

procedure TSevenZWriterImpl.AddDirectory(const AName: string);
begin
  AddDirectoryWithTime(AName, C_DEFAULT_MTIME_UNIX);
end;

procedure TSevenZWriterImpl.AddDirectoryWithTime(const AName: string;
  const AMTimeUnixSec: Int64);
var
  LE: TEntryRec;
begin
  CheckOpen;
  ValidateEntryName(AName);
  LE := Default(TEntryRec);
  LE.Name := AName;
  LE.IsDir := True;
  LE.Source := esBytes;
  LE.HasMTime := True;
  LE.MTimeUnixSec := AMTimeUnixSec;
  SetLength(FEntries, Length(FEntries) + 1);
  FEntries[High(FEntries)] := LE;
end;

function TSevenZWriterImpl.EntryCount: Integer;
begin
  Result := Length(FEntries);
end;

procedure TSevenZWriterImpl.BuildArchive(out ASig, APacked, AHdrStream,
  ABlock: TBytes);

  procedure AppendVarint(var AOut: TBytes; AValue: UInt64);
  begin
    SevenZWriteNumber(AOut, AValue);
  end;

    procedure AppendUtf16LeName(var AOut: TBytes; const AName: string);
    var
      LUnits: TBytes;
    begin
      LUnits := SevenZUtf8ToUtf16Le(AName);
      if Length(LUnits) > 0 then
        SevenZAppendBytes(AOut, @LUnits[0], Length(LUnits));
      SevenZAppendByte(AOut, 0);
      SevenZAppendByte(AOut, 0);
    end;

    procedure AppendVarintBuilder(const ABuilder: IBytesBuilder; AValue: UInt64); inline;
    begin
      SevenZWriteNumberToBuilder(ABuilder, AValue);
    end;

    procedure AppendUtf16LeNameBuilder(const ABuilder: IBytesBuilder; const AName: string);
    var
      LUnits: TBytes;
    begin
      LUnits := SevenZUtf8ToUtf16Le(AName);
      if Length(LUnits) > 0 then
        SevenZAppendBytesToBuilder(ABuilder, @LUnits[0], Length(LUnits));
      SevenZAppendByteToBuilder(ABuilder, 0);
      SevenZAppendByteToBuilder(ABuilder, 0);
    end;

    procedure AppendBoolVectorToBuilder(const ABuilder: IBytesBuilder; const AVals: array of Boolean);
    var
      LByteIdx: SizeInt;
      LBit: Integer;
      LB: Byte;
    begin
      for LByteIdx := 0 to (Length(AVals) + 7) div 8 - 1 do
      begin
        LB := 0;
        for LBit := 0 to 7 do
          if (LByteIdx * 8 + LBit < Length(AVals)) and AVals[LByteIdx * 8 + LBit] then
            LB := LB or Byte(1 shl (7 - LBit));
        SevenZAppendByteToBuilder(ABuilder, LB);
      end;
    end;

    procedure AppendBoolVector2AllDefinedToBuilder(const ABuilder: IBytesBuilder; ACount: SizeInt); inline;
    begin
      if ACount > 0 then
        SevenZAppendByteToBuilder(ABuilder, $01);
    end;

    { 多 folder 流信息：PackInfo + UnpackInfo + SubStreamsInfo。
      每个 folder 独立 coder 链（应用序，末位恒为压缩器），绑定对
      不落盘：N 个 coder 恰 N-1 对 [InIndex=j-1, OutIndex=j]。 }
    procedure BuildStreamsInfoMultiBuilder(const ABuilder: IBytesBuilder;
      const AFolders: array of TFolderBuild);
    var
      LI, LJ, LK: SizeInt;
      LTotalPacks: SizeInt;
      LNeedNumStreams: Boolean;
      LNeedSizes: Boolean;

      function MethodIdSize(AId: UInt64): Integer;
      begin
        Result := 1;
        AId := AId shr 8;
        while AId <> 0 do
        begin
          Inc(Result);
          AId := AId shr 8;
        end;
      end;

    begin
      LTotalPacks := Length(AFolders);
      SevenZAppendByteToBuilder(ABuilder, SZ_ID_PACK_INFO);
      AppendVarintBuilder(ABuilder, 0);
      AppendVarintBuilder(ABuilder, UInt64(LTotalPacks));
      SevenZAppendByteToBuilder(ABuilder, SZ_ID_SIZE);
      for LI := 0 to High(AFolders) do
        AppendVarintBuilder(ABuilder, UInt64(Length(AFolders[LI].PackedData)));
      SevenZAppendByteToBuilder(ABuilder, SZ_ID_CRC);
      AppendBoolVector2AllDefinedToBuilder(ABuilder, LTotalPacks);
      for LI := 0 to High(AFolders) do
        SevenZAppendUInt32LEToBuilder(ABuilder, Crc32OfBytes(AFolders[LI].PackedData));
      SevenZAppendByteToBuilder(ABuilder, SZ_ID_END);
      SevenZAppendByteToBuilder(ABuilder, SZ_ID_UNPACK_INFO);
      SevenZAppendByteToBuilder(ABuilder, SZ_ID_FOLDER);
      AppendVarintBuilder(ABuilder, UInt64(LTotalPacks));
      SevenZAppendByteToBuilder(ABuilder, 0);
      for LI := 0 to High(AFolders) do
      begin
        AppendVarintBuilder(ABuilder, UInt64(Length(AFolders[LI].Specs)));
        for LJ := 0 to High(AFolders[LI].Specs) do
        begin
          if Length(AFolders[LI].Specs[LJ].Props) > 0 then
            SevenZAppendByteToBuilder(ABuilder, Byte(MethodIdSize(AFolders[LI].Specs[LJ].MethodId) or $20))
          else
            SevenZAppendByteToBuilder(ABuilder, Byte(MethodIdSize(AFolders[LI].Specs[LJ].MethodId)));
          for LK := MethodIdSize(AFolders[LI].Specs[LJ].MethodId) - 1 downto 0 do
            SevenZAppendByteToBuilder(ABuilder,
              Byte((AFolders[LI].Specs[LJ].MethodId shr (8 * LK)) and $FF));
          if Length(AFolders[LI].Specs[LJ].Props) > 0 then
          begin
            AppendVarintBuilder(ABuilder, UInt64(Length(AFolders[LI].Specs[LJ].Props)));
            SevenZAppendBytesToBuilder(ABuilder, @AFolders[LI].Specs[LJ].Props[0],
              Length(AFolders[LI].Specs[LJ].Props));
          end;
        end;
        for LJ := 1 to High(AFolders[LI].Specs) do
        begin
          AppendVarintBuilder(ABuilder, UInt64(LJ - 1));
          AppendVarintBuilder(ABuilder, UInt64(LJ));
        end;
      end;
      SevenZAppendByteToBuilder(ABuilder, SZ_ID_CODERS_UNPACK_SZ);
      for LI := 0 to High(AFolders) do
        for LJ := 0 to High(AFolders[LI].Specs) do
          AppendVarintBuilder(ABuilder, AFolders[LI].Specs[LJ].OutSize);
      SevenZAppendByteToBuilder(ABuilder, SZ_ID_CRC);
      AppendBoolVector2AllDefinedToBuilder(ABuilder, LTotalPacks);
      for LI := 0 to High(AFolders) do
        SevenZAppendUInt32LEToBuilder(ABuilder, Crc32OfBytes(AFolders[LI].RawSolid));
      SevenZAppendByteToBuilder(ABuilder, SZ_ID_END);
      SevenZAppendByteToBuilder(ABuilder, SZ_ID_SUBSTREAMS_INFO);
      LNeedNumStreams := False;
      LNeedSizes := False;
      for LI := 0 to High(AFolders) do
      begin
        if AFolders[LI].SubCount <> 1 then
          LNeedNumStreams := True;
        if AFolders[LI].SubCount > 1 then
          LNeedSizes := True;
      end;
      if LTotalPacks > 1 then
        LNeedNumStreams := LNeedNumStreams or (Length(AFolders) > 1);
      if LNeedNumStreams then
      begin
        SevenZAppendByteToBuilder(ABuilder, SZ_ID_NUM_UNPACK_STREAM);
        for LI := 0 to High(AFolders) do
          AppendVarintBuilder(ABuilder, AFolders[LI].SubCount);
      end;
      if LNeedSizes then
      begin
        SevenZAppendByteToBuilder(ABuilder, SZ_ID_SIZE);
        for LI := 0 to High(AFolders) do
          if AFolders[LI].SubCount > 1 then
            for LJ := 0 to SizeInt(AFolders[LI].SubCount) - 2 do
              AppendVarintBuilder(ABuilder, AFolders[LI].SubSizes[LJ]);
      end;
      LK := 0;
      for LI := 0 to High(AFolders) do
        if AFolders[LI].SubCount > 1 then
          LK := LK + SizeInt(AFolders[LI].SubCount);
      if LK > 0 then
      begin
        SevenZAppendByteToBuilder(ABuilder, SZ_ID_CRC);
        AppendBoolVector2AllDefinedToBuilder(ABuilder, LK);
        for LI := 0 to High(AFolders) do
          if AFolders[LI].SubCount > 1 then
            for LJ := 0 to High(AFolders[LI].SubCrcs) do
              SevenZAppendUInt32LEToBuilder(ABuilder, AFolders[LI].SubCrcs[LJ]);
      end;
      SevenZAppendByteToBuilder(ABuilder, SZ_ID_END);
    end;

    { FilesInfo 属性为 TLV：[id][varint size][定长载荷]，与读端
      SevenZParseFilesInfo 的切片方式对称 }
    procedure AppendFilePropBuilder(const ABuilder: IBytesBuilder; AId: Byte;
      const APayload: TBytes); inline;
    begin
      SevenZAppendByteToBuilder(ABuilder, AId);
      AppendVarintBuilder(ABuilder, UInt64(Length(APayload)));
      if Length(APayload) > 0 then
        SevenZAppendBytesToBuilder(ABuilder, @APayload[0], Length(APayload));
    end;

    procedure BuildFilesInfoBuilder(const ABuilder: IBytesBuilder);
    var
      LTotal, LEmptyCnt, LSubIdx, LI: SizeInt;
      LEmptyStreamFlags: array of Boolean;
      LEmptyFileStreamFlags: array of Boolean;
      LPayload: TBytes;

      procedure BuildBoolVectorPayload(const AVals: array of Boolean);
      begin
        SetLength(LPayload, 0);
        AppendBoolVector(LPayload, AVals);
      end;

    begin
      LPayload := nil;
      LTotal := Length(FEntries);
      SetLength(LEmptyStreamFlags, LTotal);
      for LSubIdx := 0 to LTotal - 1 do
        if FEntries[LSubIdx].IsDir then
          LEmptyStreamFlags[LSubIdx] := True
        else if FEntries[LSubIdx].Source = esReader then
          LEmptyStreamFlags[LSubIdx] := FEntries[LSubIdx].ReaderSize = 0
        else
          LEmptyStreamFlags[LSubIdx] := Length(FEntries[LSubIdx].Data) = 0;
      LEmptyCnt := CountTrue(LEmptyStreamFlags);
      SevenZAppendByteToBuilder(ABuilder, SZ_ID_FILES_INFO);
      AppendVarintBuilder(ABuilder, UInt64(LTotal));
      if LEmptyCnt > 0 then
      begin
        BuildBoolVectorPayload(LEmptyStreamFlags);
        AppendFilePropBuilder(ABuilder, SZ_ID_EMPTY_STREAM, LPayload);
      end;
      if LEmptyCnt > 0 then
      begin
        SetLength(LEmptyFileStreamFlags, LEmptyCnt);
        LSubIdx := 0;
        for LI := 0 to LTotal - 1 do
          if LEmptyStreamFlags[LI] then
          begin
            LEmptyFileStreamFlags[LSubIdx] := not FEntries[LI].IsDir;
            Inc(LSubIdx);
          end;
        if CountTrue(LEmptyFileStreamFlags) > 0 then
        begin
          SetLength(LPayload, 0);
          AppendBoolVector(LPayload, LEmptyFileStreamFlags);
          AppendFilePropBuilder(ABuilder, SZ_ID_EMPTY_FILE, LPayload);
        end;
      end;
      SetLength(LPayload, 0);
      SevenZAppendByte(LPayload, 0);
      for LI := 0 to LTotal - 1 do
        AppendUtf16LeName(LPayload, FEntries[LI].Name);
      AppendFilePropBuilder(ABuilder, SZ_ID_NAME, LPayload);
      SetLength(LPayload, 0);
      AppendBoolVector2AllDefined(LPayload, LTotal);
      SevenZAppendByte(LPayload, 0);
      for LI := 0 to LTotal - 1 do
        SevenZAppendUInt64LE(LPayload,
          SevenZUnixToFILETIME(FEntries[LI].MTimeUnixSec));
      AppendFilePropBuilder(ABuilder, SZ_ID_MTIME, LPayload);
      SetLength(LPayload, 0);
      AppendBoolVector2AllDefined(LPayload, LTotal);
      SevenZAppendByte(LPayload, 0);
      for LI := 0 to LTotal - 1 do
      begin
        if FEntries[LI].IsDir then
          SevenZAppendUInt32LE(LPayload, SEVENZ_ATTR_DIRECTORY)
        else
          SevenZAppendUInt32LE(LPayload, $00000020);
      end;
      AppendFilePropBuilder(ABuilder, SZ_ID_WIN_ATTRIBUTES, LPayload);
      SevenZAppendByteToBuilder(ABuilder, SZ_ID_END);
    end;

    procedure WriteSigLE32(var ASig: TBytes; AOfs: SizeInt; AVal: UInt32);
    var
      LI: SizeInt;
    begin
      for LI := 0 to 3 do
        ASig[AOfs + LI] := Byte((AVal shr (8 * LI)) and $FF);
    end;

    procedure WriteSigLE64(var ASig: TBytes; AOfs: SizeInt; AVal: UInt64);
    var
      LI: SizeInt;
    begin
      for LI := 0 to 7 do
        ASig[AOfs + LI] := Byte((AVal shr (8 * LI)) and $FF);
    end;

    { 构造编码链末端的 AES256 段规格（解码时为第一段）：随机 IV 取自
      CSPRNG（环境故障异常透传）、无盐、power=19，与参考写端缺省一致。
      AData 零填充至 16 字节块边界后整段加密；返回的 OutSize 为未填充
      的声明逻辑长度——读端解密后按头部声明尺寸截断，两侧对称 }
    function MakeAesSpec(var AData: TBytes): TCoderSpec;
    var
      LIv: TBytes;
      LAesProps: TSevenZAesProps;
      LPadded: TBytes;
      LPlainLen, LPadLen, LI: SizeInt;
    begin
      LIv := GenerateSecureRandomBytes(16);
      LAesProps := Default(TSevenZAesProps);
      LAesProps.NumCyclesPower := C_AES_CYCLES_POWER;
      LAesProps.IvSize := 16;
      for LI := 0 to 15 do
        LAesProps.Iv[LI] := LIv[LI];
      LPlainLen := Length(AData);
      LPadLen := (16 - (LPlainLen mod 16)) mod 16;
      SetLength(LPadded, LPlainLen + LPadLen);
      if LPlainLen > 0 then
        Move(AData[0], LPadded[0], LPlainLen);
      if LPadLen > 0 then
        FillChar(LPadded[LPlainLen], LPadLen, 0);
      SevenZAesEncryptData(LAesProps, FPassword, LPadded, AData);
      Result.MethodId := SEVENZ_METHOD_AES256_CRC;
      Result.Props := SevenZBuildAesProps(C_AES_CYCLES_POWER, nil, LIv);
      Result.OutSize := UInt64(LPlainLen);
    end;

    { 编码头块：kEncodedHeader + 单 folder LZMA2 流信息，带 pack 流与
      解码结果双重 CRC 自校验。压缩后的头码流紧跟 solid 载荷之后，
      块内 PackPos 即其档内偏移。口令启用时 folder 追加 AES 段
      （-mhe=on 对等行为）：物理流为填充密文，声明的解密尺寸与
      CRC 分别针对未填充压缩流与明文头 }
    procedure BuildEncodedHeaderPartsToBuilder(const APlain, ASolidPacked: TBytes;
      out AHdrStream: TBytes; const ABlockBuilder: IBytesBuilder);
    var
      LHdrEnc: TSevenZLzmaEncoded;
      LAesSpec: TCoderSpec;
      LEncrypted: Boolean;
      LI: SizeInt;
      LHdrMethod: UInt64;
      LHdrProps: TBytes;
    begin
      if FLevel = szclNone then
      begin
        AHdrStream := Copy(APlain, 0, Length(APlain));
        LHdrMethod := SEVENZ_METHOD_COPY;
        LHdrProps := nil;
      end
      else
      begin
        LHdrEnc := SevenZAcquireEncoder.EncodeLzma2(APlain, FLevel);
        AHdrStream := LHdrEnc.PackedData;
        LHdrMethod := SEVENZ_METHOD_LZMA2;
        LHdrProps := LHdrEnc.Props;
      end;
      LAesSpec := Default(TCoderSpec);
      LEncrypted := FPassword <> '';
      if LEncrypted then
        LAesSpec := MakeAesSpec(AHdrStream);
      SevenZAppendByteToBuilder(ABlockBuilder, SZ_ID_ENCODED_HEADER);
      SevenZAppendByteToBuilder(ABlockBuilder, SZ_ID_PACK_INFO);
      AppendVarintBuilder(ABlockBuilder, UInt64(Length(ASolidPacked)));
      AppendVarintBuilder(ABlockBuilder, 1);
      SevenZAppendByteToBuilder(ABlockBuilder, SZ_ID_SIZE);
      AppendVarintBuilder(ABlockBuilder, UInt64(Length(AHdrStream)));
      SevenZAppendByteToBuilder(ABlockBuilder, SZ_ID_CRC);
      AppendBoolVector2AllDefinedToBuilder(ABlockBuilder, 1);
      SevenZAppendUInt32LEToBuilder(ABlockBuilder, Crc32OfBytes(AHdrStream));
      SevenZAppendByteToBuilder(ABlockBuilder, SZ_ID_END);
      SevenZAppendByteToBuilder(ABlockBuilder, SZ_ID_UNPACK_INFO);
      SevenZAppendByteToBuilder(ABlockBuilder, SZ_ID_FOLDER);
      AppendVarintBuilder(ABlockBuilder, 1);
      SevenZAppendByteToBuilder(ABlockBuilder, 0);
      if LEncrypted then
        AppendVarintBuilder(ABlockBuilder, 2)
      else
        AppendVarintBuilder(ABlockBuilder, 1);
      if LHdrMethod = SEVENZ_METHOD_COPY then
      begin
        SevenZAppendByteToBuilder(ABlockBuilder, $01);
        SevenZAppendByteToBuilder(ABlockBuilder, Byte(LHdrMethod));
      end
      else
      begin
        SevenZAppendByteToBuilder(ABlockBuilder, $21);
        SevenZAppendByteToBuilder(ABlockBuilder, Byte(LHdrMethod));
        AppendVarintBuilder(ABlockBuilder, UInt64(Length(LHdrProps)));
        if Length(LHdrProps) > 0 then
          SevenZAppendBytesToBuilder(ABlockBuilder, @LHdrProps[0], Length(LHdrProps));
      end;
      if LEncrypted then
      begin
        SevenZAppendByteToBuilder(ABlockBuilder, $24);
        for LI := 3 downto 0 do
          SevenZAppendByteToBuilder(ABlockBuilder, Byte(
            (SEVENZ_METHOD_AES256_CRC shr (8 * LI)) and $FF));
        AppendVarintBuilder(ABlockBuilder, UInt64(Length(LAesSpec.Props)));
        SevenZAppendBytesToBuilder(ABlockBuilder, @LAesSpec.Props[0], Length(LAesSpec.Props));
        AppendVarintBuilder(ABlockBuilder, 0);
        AppendVarintBuilder(ABlockBuilder, 1);
      end;
      SevenZAppendByteToBuilder(ABlockBuilder, SZ_ID_CODERS_UNPACK_SZ);
      AppendVarintBuilder(ABlockBuilder, UInt64(Length(APlain)));
      if LEncrypted then
        AppendVarintBuilder(ABlockBuilder, LAesSpec.OutSize);
      SevenZAppendByteToBuilder(ABlockBuilder, SZ_ID_CRC);
      AppendBoolVector2AllDefinedToBuilder(ABlockBuilder, 1);
      SevenZAppendUInt32LEToBuilder(ABlockBuilder, Crc32OfBytes(APlain));
      SevenZAppendByteToBuilder(ABlockBuilder, SZ_ID_END);
      SevenZAppendByteToBuilder(ABlockBuilder, SZ_ID_END);
    end;

    function EntrySize(const E: TEntryRec): UInt64; inline;
    begin
      if E.IsDir then Exit(0);
      if E.Source = esReader then Result := E.ReaderSize
      else Result := UInt64(Length(E.Data));
    end;

    procedure ReadFully(const AReader: IReader; var ADest; ACount: SizeUInt);
    var
      LDst: PByte;
      LRem: SizeUInt;
      LRead: SizeUInt;
    begin
      LDst := @ADest;
      LRem := ACount;
      while LRem > 0 do
      begin
        LRead := AReader.Read(LDst^, LRem);
        if LRead = 0 then
          raise EIOError.Create('AddFileFromReader: unexpected EOF (short read)');
        Inc(LDst, LRead);
        Dec(LRem, LRead);
      end;
    end;

    function ReadFullyWithCrc(const AReader: IReader; var ADest; ACount: SizeUInt): UInt32;
    var
      LDst: PByte;
      LRem: SizeUInt;
      LRead: SizeUInt;
      LCrc: LongWord;
    begin
      LCrc := 0;
      LDst := @ADest;
      LRem := ACount;
      while LRem > 0 do
      begin
        LRead := AReader.Read(LDst^, LRem);
        if LRead = 0 then
          raise EIOError.Create('AddFileFromReader: unexpected EOF (short read)');
        LCrc := Crc32Update(LCrc, LDst, LRead);
        Inc(LDst, LRead);
        Dec(LRem, LRead);
      end;
      Result := UInt32(LCrc);
    end;

    procedure MoveWithCrc(const ASrc; var ADest; ACount: SizeUInt; out ACrc: UInt32);
    var
      LSrc: PByte;
      LDst: PByte;
      LRem: SizeUInt;
      LTake: SizeUInt;
      LCrc: LongWord;
    begin
      if ACount = 0 then
      begin
        ACrc := 0;
        Exit;
      end;
      LSrc := @ASrc;
      LDst := @ADest;
      LRem := ACount;
      LCrc := 0;
      while LRem > 0 do
      begin
        if LRem > SEVENZ_WRITER_CHUNK then LTake := SEVENZ_WRITER_CHUNK else LTake := LRem;
        Move(LSrc^, LDst^, LTake);
        LCrc := Crc32Update(LCrc, LSrc, LTake);
        Inc(LSrc, LTake);
        Inc(LDst, LTake);
        Dec(LRem, LTake);
      end;
      ACrc := UInt32(LCrc);
    end;

  var
    LFolders: array of TFolderBuild;
    LNonEmpty: SizeInt;
    LNonEmptyIdx: array of SizeInt;
    LGroupBytes, LGroupCount: SizeInt;
    LFolderIdx, LI, LJ, LK: SizeInt;
    LAcc: SizeInt;
    LCursor: SizeInt;
    LBatchStart, LBatchSize, LCreated: SizeInt;
    LStartHdrCrc: UInt32;
    LPlainHeader: TBytes;
    LPlainBuilder: IBytesBuilder;
    LBlockBuilder: IBytesBuilder;
    LHandles: array of TPlatformThreadHandle;
    LJobs: array of TFolderEncodeJob;
    LRetVal: Pointer;
    LProbe: Byte;
    LExtra: SizeUInt;
    LSpans: array of TByteSpan;
  begin
    { 统计非空文件并建立索引 }
    LNonEmpty := 0;
    for LAcc := 0 to High(FEntries) do
      if (not FEntries[LAcc].IsDir) and (EntrySize(FEntries[LAcc]) > 0) then
        Inc(LNonEmpty);
    SetLength(LNonEmptyIdx, LNonEmpty);
    LAcc := 0;
    for LI := 0 to High(FEntries) do
      if (not FEntries[LI].IsDir) and (EntrySize(FEntries[LI]) > 0) then
      begin
        LNonEmptyIdx[LAcc] := LI;
        Inc(LAcc);
      end;
    { 按阈值切分 folder：任一维度超限即起新 folder }
    SetLength(LFolders, 0);
    if LNonEmpty > 0 then
    begin
      LGroupBytes := 0;
      LGroupCount := 0;
      for LI := 0 to LNonEmpty - 1 do
      begin
        LJ := LNonEmptyIdx[LI];
        LK := SizeInt(EntrySize(FEntries[LJ]));
        { 单条目炸弹门：EntrySize 为 UInt64 声明，需先与 SEVENZ_MAX_UNPACK_SIZE 对比再窄化为 SizeInt 累加，
          否则超大 ReaderSize 直达 SetLength 触发堆 OOM；复用 limits 单源常量，无额外分配，开销 O(1) 可 bench 观测 }
        if EntrySize(FEntries[LJ]) > SEVENZ_MAX_UNPACK_SIZE then
          raise ESevenZLimitError.CreateFmt(
            'entry "%s" size %d exceeds limit %d',
            [FEntries[LJ].Name, EntrySize(FEntries[LJ]), SEVENZ_MAX_UNPACK_SIZE]);
        if UInt64(LGroupBytes) + UInt64(LK) > SEVENZ_MAX_UNPACK_SIZE then
          raise ESevenZLimitError.CreateFmt(
            'folder unpack size %d exceeds limit %d',
            [UInt64(LGroupBytes) + UInt64(LK), SEVENZ_MAX_UNPACK_SIZE]);
        if (LGroupCount > 0) and
           (((FMaxFolderBytes > 0) and (UInt64(LGroupBytes + LK) > FMaxFolderBytes)) or
            ((FMaxFilesPerFolder > 0) and (LGroupCount + 1 > FMaxFilesPerFolder))) then
        begin
          SetLength(LFolders, Length(LFolders) + 1);
          LFolders[High(LFolders)].SubCount := UInt64(LGroupCount);
          LGroupBytes := 0;
          LGroupCount := 0;
        end;
        Inc(LGroupBytes, LK);
        Inc(LGroupCount);
      end;
      if LGroupCount > 0 then
      begin
        SetLength(LFolders, Length(LFolders) + 1);
        LFolders[High(LFolders)].SubCount := UInt64(LGroupCount);
      end;
      { 为每 folder 填充 RawSolid / SubSizes / SubCrcs }
      LAcc := 0;
      for LFolderIdx := 0 to High(LFolders) do
      begin
        LK := SizeInt(LFolders[LFolderIdx].SubCount);
        SetLength(LFolders[LFolderIdx].SubSizes, LK);
        SetLength(LFolders[LFolderIdx].SubCrcs, LK);
        LGroupBytes := 0;
        for LJ := 0 to LK - 1 do
        begin
          LI := LNonEmptyIdx[LAcc + LJ];
          LFolders[LFolderIdx].SubSizes[LJ] := EntrySize(FEntries[LI]);
          { 复用同一炸弹门：单条与 folder 累计均需在 SizeInt 累加/分配前对比 UInt64 单源上限，避免 RawSolid SetLength 直达 OOM }
          if EntrySize(FEntries[LI]) > SEVENZ_MAX_UNPACK_SIZE then
            raise ESevenZLimitError.CreateFmt(
              'entry "%s" size %d exceeds limit %d',
              [FEntries[LI].Name, EntrySize(FEntries[LI]), SEVENZ_MAX_UNPACK_SIZE]);
          if UInt64(LGroupBytes) + EntrySize(FEntries[LI]) > SEVENZ_MAX_UNPACK_SIZE then
            raise ESevenZLimitError.CreateFmt(
              'folder unpack size %d exceeds limit %d',
              [UInt64(LGroupBytes) + EntrySize(FEntries[LI]), SEVENZ_MAX_UNPACK_SIZE]);
          Inc(LGroupBytes, SizeInt(EntrySize(FEntries[LI])));
        end;
        if UInt64(LGroupBytes) > SEVENZ_MAX_UNPACK_SIZE then
          raise ESevenZLimitError.CreateFmt(
            'folder unpack size %d exceeds limit %d',
            [UInt64(LGroupBytes), SEVENZ_MAX_UNPACK_SIZE]);
        if UInt64(LGroupBytes) > UInt64(High(SizeInt)) then
          raise ESevenZLimitError.CreateFmt(
            'folder unpack size %d exceeds addressable limit %d',
            [UInt64(LGroupBytes), UInt64(High(SizeInt))]);
        SetLength(LFolders[LFolderIdx].RawSolid, LGroupBytes);
        LCursor := 0;
        for LJ := 0 to LK - 1 do
        begin
          LI := LNonEmptyIdx[LAcc + LJ];
          if EntrySize(FEntries[LI]) > 0 then
          begin
            { 单遍 Move+CRC：分块搬运并增量更新 CRC，避免对同一数据二次扫描 }
            if FEntries[LI].Source = esReader then
            begin
              LFolders[LFolderIdx].SubCrcs[LJ] :=
                ReadFullyWithCrc(FEntries[LI].Reader,
                  LFolders[LFolderIdx].RawSolid[LCursor],
                  SizeUInt(EntrySize(FEntries[LI])));
              { H-16: ASize 截断防御 — 物化后尝试再读 1 字节，若成功则为 oversized }
              LExtra := FEntries[LI].Reader.Read(LProbe, 1);
              if LExtra <> 0 then
                raise EArgumentError.Create(
                  'AddFileFromReader oversized: entry "' + FEntries[LI].Name +
                  '" declared ' + UIntToStr(FEntries[LI].ReaderSize) + ' but has more data');
            end
            else
            begin
              MoveWithCrc(FEntries[LI].Data[0],
                LFolders[LFolderIdx].RawSolid[LCursor],
                SizeUInt(EntrySize(FEntries[LI])),
                LFolders[LFolderIdx].SubCrcs[LJ]);
            end;
            Inc(LCursor, SizeInt(EntrySize(FEntries[LI])));
          end
          else
          begin
            { H-16: 零长声明同样需探测 oversized }
            if FEntries[LI].Source = esReader then
            begin
              LFolders[LFolderIdx].SubCrcs[LJ] := 0;
              LExtra := FEntries[LI].Reader.Read(LProbe, 1);
              if LExtra <> 0 then
                raise EArgumentError.Create(
                  'AddFileFromReader oversized: entry "' + FEntries[LI].Name +
                  '" declared ' + UIntToStr(FEntries[LI].ReaderSize) + ' but has more data');
            end
            else
              LFolders[LFolderIdx].SubCrcs[LJ] := 0;
          end;
        end;
        Inc(LAcc, LK);
      end;
      { 逐 folder 执行过滤链与压缩，产出 Packed 与 Specs
          零过滤器时零拷贝直连 RawSolid，避免 Solid 整体二次搬运。
          多 folder 时分批并行（批次上限由 platform_cpu_count 自适应，
          单源复用，避免硬上限 8 制约吞吐；IsMultiThread 门控 cthreads，
          无线程支持时回落串行，创建失败亦回落；加密段统一串行以避免 CSPRNG 竞争） }
      if (Length(LFolders) >= 2) and IsMultiThread then
      begin
        LBatchStart := 0;
        while LBatchStart < Length(LFolders) do
        begin
          LBatchSize := Length(LFolders) - LBatchStart;
          // adaptive batch: cpu_count 自适应为主，fallback 硬上限避免极端 oversubscription
          if platform_cpu_count > 0 then
          begin
            if LBatchSize > platform_cpu_count then
              LBatchSize := platform_cpu_count;
          end else if LBatchSize > C_MAX_PARALLEL_THREADS then
            LBatchSize := C_MAX_PARALLEL_THREADS;
          SetLength(LJobs, LBatchSize);
          SetLength(LHandles, LBatchSize);
          for LI := 0 to LBatchSize - 1 do
            LHandles[LI] := nil;
          LCreated := 0;
          try
            try
              for LI := 0 to LBatchSize - 1 do
              begin
                LFolderIdx := LBatchStart + LI;
                LJobs[LI].Folder := @LFolders[LFolderIdx];
                SetLength(LJobs[LI].Filters, Length(FFilters));
                for LK := 0 to High(FFilters) do
                  LJobs[LI].Filters[LK] := FFilters[LK];
                LJobs[LI].Level := FLevel;
                LJobs[LI].ForcedId := FForcedMethodId;
                LJobs[LI].HasForced := FHasForcedMethod;
                LJobs[LI].HasErr := False;
                LJobs[LI].ErrMsg := '';
                if platform_thread_create(LHandles[LI], @FolderEncodeJobWorker, @LJobs[LI]) <> 0 then
                  raise EIOError.Create('parallel folder encode failed: platform_thread_create failed');
                Inc(LCreated);
              end;
              for LI := 0 to LCreated - 1 do
              begin
                platform_thread_join(LHandles[LI], LRetVal);
                LHandles[LI] := nil;
                if LJobs[LI].HasErr then
                  raise EIOError.Create('parallel folder encode failed: ' + LJobs[LI].ErrMsg);
              end;
              if Assigned(FProgress) then
                for LI := 0 to LBatchSize - 1 do
                  FProgress(Self, LBatchStart + LI + 1, Length(LFolders));
            except
              for LI := 0 to LCreated - 1 do
                if LHandles[LI] <> nil then
                  try platform_thread_join(LHandles[LI], LRetVal); except end;
              raise;
            end;
          finally
            for LI := 0 to LCreated - 1 do
              if LHandles[LI] <> nil then
                try platform_thread_join(LHandles[LI], LRetVal); except end;
          end;
          Inc(LBatchStart, LBatchSize);
        end;
      end else
        for LFolderIdx := 0 to High(LFolders) do
        begin
          EncodeFolderCore(LFolders[LFolderIdx], FFilters, FLevel, FForcedMethodId, FHasForcedMethod);
          if Assigned(FProgress) then
            FProgress(Self, LFolderIdx + 1, Length(LFolders));
        end;
      if FPassword <> '' then
        for LFolderIdx := 0 to High(LFolders) do
        begin
          SetLength(LFolders[LFolderIdx].Specs, Length(LFolders[LFolderIdx].Specs) + 1);
          LFolders[LFolderIdx].Specs[High(LFolders[LFolderIdx].Specs)] := MakeAesSpec(LFolders[LFolderIdx].PackedData);
        end;
      { 拼接全部 pack 流为连续载荷：单次分配 SpanConcatMany 复用 bytes.ops 单源（零额外 Move 循环，单遍分配+拷贝），bench_sevenz 吞吐锚点无回归，I-Cache 友好 }
      SetLength(LSpans, Length(LFolders));
      for LFolderIdx := 0 to High(LFolders) do
        LSpans[LFolderIdx] := TByteSpan.FromBytes(LFolders[LFolderIdx].PackedData);
      APacked := SpanConcatMany(LSpans);
    end
    else
    begin
      APacked := nil;
      SetLength(LFolders, 0);
    end;
    { 主头：明文 kHeader；无 pack 数据时省略流信息段 — IBytesBuilder O(n) 均摊，避免逐次 SetLength O(n²) }
    LPlainBuilder := CreateBytesBuilder(4096);
    SevenZAppendByteToBuilder(LPlainBuilder, SZ_ID_HEADER);
    if LNonEmpty > 0 then
    begin
      SevenZAppendByteToBuilder(LPlainBuilder, SZ_ID_MAIN_STREAMS);
      BuildStreamsInfoMultiBuilder(LPlainBuilder, LFolders);
      SevenZAppendByteToBuilder(LPlainBuilder, SZ_ID_END);
    end;
    if Length(FEntries) > 0 then
      BuildFilesInfoBuilder(LPlainBuilder);
    SevenZAppendByteToBuilder(LPlainBuilder, SZ_ID_END);
    LPlainHeader := LPlainBuilder.ToBytes;
    { 头块形态：默认编码头（与参考实现生态一致），可切回明文。
      编码头模式多一个物理段：压缩后的头码流位于 solid 与块之间，
      签名头的 NextHeaderOffset 必须跨过它指向块起点 }
    if FEncodeHeader then
    begin
      LBlockBuilder := CreateBytesBuilder(1024);
      BuildEncodedHeaderPartsToBuilder(LPlainHeader, APacked, AHdrStream, LBlockBuilder);
      ABlock := LBlockBuilder.ToBytes;
    end
    else
    begin
      SetLength(AHdrStream, 0);
      ABlock := LPlainHeader;
    end;
    { 签名头：载荷紧跟其后（NextHeaderOffset 为归档内偏移） }
    SetLength(ASig, C_SEVENZ_SIG_HEADER_SIZE);
    FillChar(ASig[0], C_SEVENZ_SIG_HEADER_SIZE, 0);
    ASig[0] := C_SEVENZ_MAGIC_0;
    ASig[1] := C_SEVENZ_MAGIC_1;
    ASig[2] := C_SEVENZ_MAGIC_2;
    ASig[3] := C_SEVENZ_MAGIC_3;
    ASig[4] := C_SEVENZ_MAGIC_4;
    ASig[5] := C_SEVENZ_MAGIC_5;
    ASig[6] := C_SEVENZ_VERSION_MAJOR;
    ASig[7] := C_SEVENZ_VERSION_MINOR;
    { 签名头三元组：NextHeaderOffset 跨过 solid 与编码头流指向块起点 }
    WriteSigLE64(ASig, 12,
      UInt64(Length(APacked) + Length(AHdrStream)));
    WriteSigLE64(ASig, 20, UInt64(Length(ABlock)));
    WriteSigLE32(ASig, 28, Crc32OfBytes(ABlock));
    LStartHdrCrc := Crc32Of((@ASig[12])^, 20);
    WriteSigLE32(ASig, 8, LStartHdrCrc);
  end;

function TSevenZWriterImpl.Finish: TBytes;
var
  LSig, LPacked, LHdrStream, LBlock: TBytes;
  LBase: SizeInt;
  LI: SizeInt;
begin
  Result := nil;
  CheckOpen;
  try
    BuildArchive(LSig, LPacked, LHdrStream, LBlock);
    { H-10: 将 FFinished 置位延后至 BuildArchive 成功后，避免失败锁死 }
    FFinished := True;
    SetLength(Result, Length(LSig) + Length(LPacked) +
      Length(LHdrStream) + Length(LBlock));
    Move(LSig[0], Result[0], Length(LSig));
    LBase := Length(LSig);
    if Length(LPacked) > 0 then
      Move(LPacked[0], Result[LBase], Length(LPacked));
    Inc(LBase, Length(LPacked));
    if Length(LHdrStream) > 0 then
      Move(LHdrStream[0], Result[LBase], Length(LHdrStream));
    Inc(LBase, Length(LHdrStream));
    if Length(LBlock) > 0 then
      Move(LBlock[0], Result[LBase], Length(LBlock));
  finally
    { M-06: Finish 后释放 IReader 持有，避免长生命周期 pin 住外部资源 }
    for LI := 0 to High(FEntries) do
      FEntries[LI].Reader := nil;
    SetLength(FEntries, 0);
  end;
end;

function TSevenZWriterImpl.FinishTo(const ASink: IWriter): Int64;
{ L-03: 非原子 — 本方法按段顺序多次调用 ASink.Write，若中途失败已写入的
  前缀不会回滚；需原子语义请先 Finish 到临时缓冲/临时文件再原子重命名
  （如先写入 .tmp 再 RenameFile），调用方据此处理部分写入的清理 }

  procedure WriteAll(const APart: TBytes);
  var
    LWritten: Int64;
  begin
    if Length(APart) = 0 then
      Exit;
    LWritten := ASink.Write(APart[0], SizeUInt(Length(APart)));
    if LWritten <> Length(APart) then
      raise EIOError.Create('sink accepted fewer bytes than archive part');
  end;

var
  LSig, LPacked, LHdrStream, LBlock: TBytes;
  LI: SizeInt;
begin
  CheckOpen;
  try
    BuildArchive(LSig, LPacked, LHdrStream, LBlock);
    { H-10: 将 FFinished 置位延后至 BuildArchive 成功后，避免失败锁死 }
    FFinished := True;
    WriteAll(LSig);
    WriteAll(LPacked);
    WriteAll(LHdrStream);
    WriteAll(LBlock);
    Result := Int64(Length(LSig) + Length(LPacked) +
      Length(LHdrStream) + Length(LBlock));
  finally
    { M-06: FinishTo 后释放 IReader 持有，避免长生命周期 pin 住外部资源 }
    for LI := 0 to High(FEntries) do
      FEntries[LI].Reader := nil;
    SetLength(FEntries, 0);
  end;
end;

{ TSevenZWriterBuilderImpl }

constructor TSevenZWriterBuilderImpl.Create;
begin
  inherited Create;
  FImpl := TSevenZWriterImpl.Create;
  FWriter := FImpl;
end;

function TSevenZWriterBuilderImpl.AddFile(const AName: string;
  const AData: TBytes): ISevenZWriterBuilder;
begin
  FWriter.AddFile(AName, AData);
  Result := Self;
end;

function TSevenZWriterBuilderImpl.AddFileWithTime(const AName: string;
  const AData: TBytes; const AMTimeUnixSec: Int64): ISevenZWriterBuilder;
begin
  FWriter.AddFileWithTime(AName, AData, AMTimeUnixSec);
  Result := Self;
end;

function TSevenZWriterBuilderImpl.AddFileFromReader(const AName: string;
  const AReader: IReader; ASize: UInt64): ISevenZWriterBuilder;
begin
  FWriter.AddFileFromReader(AName, AReader, ASize);
  Result := Self;
end;

function TSevenZWriterBuilderImpl.AddFileFromReaderWithTime(const AName: string;
  const AReader: IReader; ASize: UInt64;
  const AMTimeUnixSec: Int64): ISevenZWriterBuilder;
begin
  FWriter.AddFileFromReaderWithTime(AName, AReader, ASize, AMTimeUnixSec);
  Result := Self;
end;

function TSevenZWriterBuilderImpl.AddDirectory(const AName: string): ISevenZWriterBuilder;
begin
  FWriter.AddDirectory(AName);
  Result := Self;
end;

function TSevenZWriterBuilderImpl.AddDirectoryWithTime(const AName: string;
  const AMTimeUnixSec: Int64): ISevenZWriterBuilder;
begin
  FWriter.AddDirectoryWithTime(AName, AMTimeUnixSec);
  Result := Self;
end;

function TSevenZWriterBuilderImpl.WithFilters(
  const AFilters: array of TSevenZFilter): ISevenZWriterBuilder;
begin
  FWriter.SetFilters(AFilters);
  Result := Self;
end;

function TSevenZWriterBuilderImpl.WithLevel(
  ALevel: TSevenZCompressionLevel): ISevenZWriterBuilder;
begin
  FWriter.SetLevel(ALevel);
  Result := Self;
end;

function TSevenZWriterBuilderImpl.WithMethod(
  AMethodId: UInt64): ISevenZWriterBuilder;
begin
  FWriter.SetMethod(AMethodId);
  Result := Self;
end;

function TSevenZWriterBuilderImpl.WithPassword(const APassword: string): ISevenZWriterBuilder;
begin
  FWriter.SetPassword(APassword);
  Result := Self;
end;

function TSevenZWriterBuilderImpl.WithFolderLimits(
  AMaxUncompressedBytes: UInt64; AMaxFilesPerFolder: Integer): ISevenZWriterBuilder;
begin
  FWriter.SetFolderLimits(AMaxUncompressedBytes, AMaxFilesPerFolder);
  Result := Self;
end;

function TSevenZWriterBuilderImpl.WithEncodeHeader(
  AEnabled: Boolean): ISevenZWriterBuilder;
begin
  FWriter.SetEncodeHeader(AEnabled);
  Result := Self;
end;

function TSevenZWriterBuilderImpl.WithProgress(
  AProgress: TSevenZProgressEvent): ISevenZWriterBuilder;
begin
  FProgress := AProgress;
  if Assigned(FImpl) then
    FImpl.SetProgress(AProgress);
  Result := Self;
end;

procedure TSevenZWriterBuilderImpl.ApplyProgress;
begin
  if Assigned(FProgress) and Assigned(FImpl) then
    FImpl.SetProgress(FProgress);
end;

procedure TSevenZWriterBuilderImpl.CheckNotFinished;
begin
  if FFinished then
    raise ESevenZError.Create('sevenz writer builder already finished');
end;

{ Filesystem helpers delegated to sevenz.fs owner (container kernel
  isolated from core.fs federation; single source via SevenZAddTree/FileFromFs;
  writer core no longer imports fs/fs.intf). }

function TSevenZWriterBuilderImpl.AddTree(const AHostDir: string;
  const AArchivePrefix: string): ISevenZWriterBuilder;
begin
  SevenZAddTree(FWriter, AHostDir, AArchivePrefix);
  Result := Self;
end;

function TSevenZWriterBuilderImpl.AddTreeWithFilter(const AHostDir: string;
  const AArchivePrefix: string; const AFilter: string): ISevenZWriterBuilder;
begin
  SevenZAddTreeWithFilter(FWriter, AHostDir, AArchivePrefix, AFilter);
  Result := Self;
end;

function TSevenZWriterBuilderImpl.AddFileFromFs(const AHostPath: string;
  const AArchiveName: string): ISevenZWriterBuilder;
begin
  SevenZAddFileFromFs(FWriter, AHostPath, AArchiveName);
  Result := Self;
end;

function TSevenZWriterBuilderImpl.Build: ISevenZWriter;
begin
  ApplyProgress;
  Result := FWriter;
end;

function TSevenZWriterBuilderImpl.Finish: TBytes;
begin
  CheckNotFinished;
  ApplyProgress;
  Result := FWriter.Finish;
  FFinished := True;
end;

function TSevenZWriterBuilderImpl.FinishTo(const ASink: IWriter): Int64;
begin
  CheckNotFinished;
  ApplyProgress;
  Result := FWriter.FinishTo(ASink);
  FFinished := True;
end;

function TSevenZWriterBuilderImpl.TryFinish(out AArchive: TBytes): Boolean;
begin
  try
    AArchive := Finish;
    Result := True;
  except
    on E: Exception do
    begin
      AArchive := nil;
      Result := False;
    end;
  end;
end;

function TSevenZWriterBuilderImpl.TryFinishTo(const ASink: IWriter; out ABytesWritten: Int64): Boolean;
begin
  try
    ABytesWritten := FinishTo(ASink);
    Result := True;
  except
    on E: Exception do
    begin
      ABytesWritten := 0;
      Result := False;
    end;
  end;
end;

function TSevenZWriterBuilderImpl.TryFinishWithError(out AArchive: TBytes; out AError: string): Boolean;
begin
  AError := '';
  try
    AArchive := Finish;
    Result := True;
  except
    on E: Exception do
    begin
      AArchive := nil;
      AError := E.ClassName + ': ' + E.Message;
      Result := False;
    end;
  end;
end;

function TSevenZWriterBuilderImpl.TryFinishToWithError(const ASink: IWriter; out ABytesWritten: Int64; out AError: string): Boolean;
begin
  AError := '';
  try
    ABytesWritten := FinishTo(ASink);
    Result := True;
  except
    on E: Exception do
    begin
      ABytesWritten := 0;
      AError := E.ClassName + ': ' + E.Message;
      Result := False;
    end;
  end;
end;

function TSevenZWriterBuilderImpl.TryAddTree(const AHostDir: string; const AArchivePrefix: string; out AError: string): Boolean;
begin
  AError := '';
  try
    AddTree(AHostDir, AArchivePrefix);
    Result := True;
  except
    on E: Exception do
    begin
      AError := E.ClassName + ': ' + E.Message;
      Result := False;
    end;
  end;
end;

function TSevenZWriterBuilderImpl.TryAddTreeWithFilter(const AHostDir: string; const AArchivePrefix: string; const AFilter: string; out AError: string): Boolean;
begin
  AError := '';
  try
    AddTreeWithFilter(AHostDir, AArchivePrefix, AFilter);
    Result := True;
  except
    on E: Exception do
    begin
      AError := E.ClassName + ': ' + E.Message;
      Result := False;
    end;
  end;
end;

function TSevenZWriterBuilderImpl.TryAddFileFromFs(const AHostPath: string; const AArchiveName: string; out AError: string): Boolean;
begin
  AError := '';
  try
    AddFileFromFs(AHostPath, AArchiveName);
    Result := True;
  except
    on E: Exception do
    begin
      AError := E.ClassName + ': ' + E.Message;
      Result := False;
    end;
  end;
end;

function SevenZCreateWriterBuilder: ISevenZWriterBuilder;
begin
  Result := TSevenZWriterBuilderImpl.Create;
end;

end.
