unit nextpas.core.zip.reader;
{**
 * @desc ZIP 归档读器实现：解析 EOCD/central directory（含 Zip64 定位记录与
 *       Zip64 extra 字段），按条目提取并强制 CRC32 与尺寸校验。
 *
 * 两种来源：整档字节缓冲（NewZipReader*），或可定位流（NewZipReaderFrom*，
 * 经 IReaderAt 定位读按需取数，不整体载入、不改调用方位置、支持多条目
 * 流并发打开）。两者共用条目解析与校验路径。
 *
 * 性能：条目数组按 central count 一次性分配；解析经 bytes.cursor 边界受查
 * 游标完成，无逐条目扩容。
 *
 * 错误模型：结构损坏 → EParseError('zip: ...')；数据完整性失败（CRC/尺寸）→
 * EIOError；不支持的特性（加密、未知压缩方法、多盘归档、源无定位读）→
 * ENotSupportedError；索引越界 → EIndexOutOfRangeError；缺失条目 →
 * ENotFoundError。敌意条目名在提取时以 EParseError 拒绝（zip-slip 防护）。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.compress.intf,
  nextpas.core.io.intf,
  nextpas.core.zip.base;

type
  {** @desc 读选项：MaxOutputSize 为单条目解压输出上限（防 zip bomb），
       0 = 采用默认上限；MaxTotalOutputSize 为跨条目总输出上限（防
       “多小条目绕过单条目上限”型 zip bomb），0 = 不限；Password 供
       WinZip AES 加密条目解密（AE-1/AE-2，遗留 ZipCrypto 不支持），
       空口令遇加密条目 raise *}
  TZipReadOptions = record
    MaxOutputSize: SizeUInt;
    MaxTotalOutputSize: UInt64;
    Password: TBytes;
  end;

  {** @desc ZIP 归档读器（一次性载入字节，随机访问条目） *}
  IZipReader = interface
    ['{7C3E5A21-9B44-4F8E-A6D0-2E51C0F81B37}']
    {** 条目数 *}
    function EntryCount: Integer;
    {** 第 AIndex 个条目元数据（0 基，越界 raise） *}
    function Entry(AIndex: Integer): TZipEntryInfo;
    {** 按名查找，返回索引；缺失 -1；重名取首个 *}
    function Find(const AName: string): Integer;
    {** 提取并校验 CRC32/尺寸；目录条目返回空字节 *}
    function ExtractToBytes(AIndex: Integer): TBytes;
    {** 同上，按名；缺失 raise ENotFoundError *}
    function ExtractToBytesByName(const AName: string): TBytes;
    {** 流式打开条目：pull 式读端，增量解压不物化整体输出；读到 EOF
        （返回 0）时强制校验尺寸与 CRC32；MaxOutputSize 语义同提取路径。
        可同时打开多个流；放弃未读完的流则跳过校验。 *}
    function OpenEntry(AIndex: Integer): IDecompressReader;
    {** 同上，按名；缺失 raise ENotFoundError *}
    function OpenEntryByName(const AName: string): IDecompressReader;
    {** 泵送整个条目到 ADst（EOF 处校验尺寸+CRC32），返回输出字节数 *}
    function CopyEntryTo(AIndex: Integer; const ADst: IWriter): SizeUInt;
  end;

const
  { 未显式配置时的单条目解压默认上限：1 GiB }
  C_ZIP_DEFAULT_MAX_OUTPUT = SizeUInt(1) shl 30;

function DefaultZipReadOptions: TZipReadOptions; inline;

{** 解析归档字节；结构非法立即 raise。 *}
function NewZipReader(const AData: TBytes): IZipReader;

{** 同上，带输出上限选项（MaxOutputSize=0 取默认上限）。 *}
function NewZipReaderWithOptions(const AData: TBytes;
  const AOptions: TZipReadOptions): IZipReader;

{** 从可定位流打开归档：经 IReaderAt 定位读按需取数（EOCD/central/条目
    载荷），不整体载入，不改写调用方流位置。ASource 须同时实现 IStream
    （GetSize）与 IReaderAt（定位读），否则 ENotSupportedError；结构非法
    立即 raise。多条目流可并发打开（各自持独立区间游标）。 *}
function NewZipReaderFrom(const ASource: IStream): IZipReader;

{** 同上，带输出上限选项（MaxOutputSize=0 取默认上限）。 *}
function NewZipReaderFromWithOptions(const ASource: IStream;
  const AOptions: TZipReadOptions): IZipReader;

implementation

uses
  nextpas.core.exception,
  nextpas.core.bytes.cursor,
  nextpas.core.checksum.crc32,
  nextpas.core.compress.deflate,
  nextpas.core.zip.aes,
  nextpas.core.zip.common,
  nextpas.core.zip.extra;

const
  C_EOCD_MIN_LEN       = 22;
  C_ZIP64_LOCATOR_LEN  = 20;
  C_ZIP64_EOCD_LEN     = 56;
  C_CENTRAL_HEADER_LEN = 46;
  C_LOCAL_HEADER_LEN   = 30;
  C_MAX_COMMENT_LEN    = 65535;

type
  TZipReaderImpl = class(TInterfacedObject, IZipReader)
  private
    FData: TBytes;
    FC: IByteCursor;
    FEntries: array of TZipEntryInfo;
    FFlags: array of Word;
    FMaxOutputSize: SizeUInt;
    FMaxTotalOutputSize: UInt64;
    FPassword: TBytes;          { 加密条目解密口令；空 = 未配置 }
    procedure ParseCentralDirectory;
    function CheckIndex(AIndex: Integer): Integer;
    procedure NeedRange(APos, ALen: Int64; const AWhat: string);
    { 加密/安全名守卫 + local header 走查，返回条目载荷起始偏移 }
    function LocatePayload(AIndex: Integer): Int64;
    function ExtractIndex(AIndex: Integer): TBytes;
  public
    constructor Create(const AData: TBytes; AMaxOutput: SizeUInt;
      AMaxTotalOutput: UInt64; const APassword: TBytes);
    function EntryCount: Integer;
    function Entry(AIndex: Integer): TZipEntryInfo;
    function Find(const AName: string): Integer;
    function ExtractToBytes(AIndex: Integer): TBytes;
    function ExtractToBytesByName(const AName: string): TBytes;
    function OpenEntry(AIndex: Integer): IDecompressReader;
    function OpenEntryByName(const AName: string): IDecompressReader;
    function CopyEntryTo(AIndex: Integer; const ADst: IWriter): SizeUInt;
  end;


{ 有界切片只读源：把归档缓冲的一段暴露为 IReader（流式解压的输入端） }
type
  TSliceReader = class(TInterfacedObject, IReader)
  private
    FBase: PByte;
    FRemaining: SizeUInt;
  public
    constructor Create(const AData: TBytes; AOffset, ALength: SizeUInt);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
  end;

{ 校验包装读端：EOF 时强制比对尺寸与 CRC32；store 路径的输出上限在此执行。
  声明于实现节：仅流式打开路径内部使用，不进入公共 API 面 }
type
  TZipVerifyReader = class(TInterfacedObject, IReader, IDecompressReader)
  private
    FInner: IReader;
    FInnerCloser: IDecompressReader;   { inflate 路径非 nil }
    FName: string;
    FExpectedCrc: LongWord;
    FExpectedSize: UInt64;
    FCap: SizeUInt;
    FSeen: UInt64;
    FCrc: LongWord;
    FVerifyCrc: Boolean;         { AE-2 条目为 False：完整性由认证码保证 }
    FClosed: Boolean;
    procedure VerifyAtEof;
  public
    constructor Create(const AInner: IReader;
      const AInnerCloser: IDecompressReader; const AName: string;
      AExpectedCrc: LongWord; AExpectedSize: UInt64; ACap: SizeUInt;
      AVerifyCrc: Boolean);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Close;
  end;

{ 定位区间读端：把 IReaderAt 的 [AOffset, AOffset+ALength) 区间暴露为
  顺序 IReader。不触碰源对象的位置状态，多个实例可并存（多条目流并发）。 }
type
  TSourceSpanReader = class(TInterfacedObject, IReader)
  private
    FAt: IReaderAt;
    FPos: UInt64;
    FRemaining: SizeUInt;
  public
    constructor Create(const AAt: IReaderAt; AOffset: Int64;
      ALength: SizeUInt);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
  end;

{ 可定位流来源的读器：EOCD/central/条目载荷均按需定位取数 }
type
  TZipSourceReader = class(TInterfacedObject, IZipReader)
  private
    FSrc: IStream;              { 保活源对象 }
    FAt: IReaderAt;             { 同一对象的定位读面 }
    FSize: Int64;               { 源总长（构造时缓存） }
    FEntries: array of TZipEntryInfo;
    FFlags: array of Word;
    FMaxOutputSize: SizeUInt;
    FMaxTotalOutputSize: UInt64;
    FPassword: TBytes;          { 加密条目解密口令；空 = 未配置 }
    { 定位取数：[APos, APos+ACount) 越界或短读即结构截断 }
    procedure Fetch(APos: Int64; ACount: SizeUInt; out ADst: TBytes;
      const AWhat: string);
    procedure ParseCentralDirectory;
    function CheckIndex(AIndex: Integer): Integer;
    procedure NeedRange(APos, ALen: Int64; const AWhat: string);
    { 加密/安全名守卫 + local header 走查（定位读），返回载荷起始偏移 }
    function LocatePayload(AIndex: Integer): Int64;
    function ExtractIndex(AIndex: Integer): TBytes;
  public
    constructor Create(const ASource: IStream; AMaxOutput: SizeUInt;
      AMaxTotalOutput: UInt64; const APassword: TBytes);
    function EntryCount: Integer;
    function Entry(AIndex: Integer): TZipEntryInfo;
    function Find(const AName: string): Integer;
    function ExtractToBytes(AIndex: Integer): TBytes;
    function ExtractToBytesByName(const AName: string): TBytes;
    function OpenEntry(AIndex: Integer): IDecompressReader;
    function OpenEntryByName(const AName: string): IDecompressReader;
    function CopyEntryTo(AIndex: Integer; const ADst: IWriter): SizeUInt;
  end;

{ TSliceReader }

constructor TSliceReader.Create(const AData: TBytes; AOffset, ALength: SizeUInt);
begin
  inherited Create;
  if Length(AData) = 0 then
  begin
    FBase := nil;
    FRemaining := 0;
    Exit;
  end;
  FBase := @AData[0];
  Inc(FBase, AOffset);
  FRemaining := ALength;
end;

function TSliceReader.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LN: SizeUInt;
begin
  LN := ACount;
  if LN > FRemaining then
    LN := FRemaining;
  if LN > 0 then
  begin
    Move(FBase^, ABuf, LN);
    Inc(FBase, LN);
    Dec(FRemaining, LN);
  end;
  Result := LN;
end;

{ TZipVerifyReader }

constructor TZipVerifyReader.Create(const AInner: IReader;
  const AInnerCloser: IDecompressReader; const AName: string;
  AExpectedCrc: LongWord; AExpectedSize: UInt64; ACap: SizeUInt;
  AVerifyCrc: Boolean);
begin
  inherited Create;
  FInner := AInner;
  FInnerCloser := AInnerCloser;
  FName := AName;
  FExpectedCrc := AExpectedCrc;
  FExpectedSize := AExpectedSize;
  FCap := ACap;
  FVerifyCrc := AVerifyCrc;
  FCrc := 0;
  FSeen := 0;
  FClosed := False;
end;

function TZipVerifyReader.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
begin
  if FClosed then
    raise EIOError.Create('zip entry stream: read after close');
  Result := FInner.Read(ABuf, ACount);
  if Result > 0 then
  begin
    Inc(FSeen, Result);
    if (FCap > 0) and (FSeen > FCap) then
      raise EIOError.Create('zip: decompressed size exceeds limit for ' + FName);
    FCrc := Crc32Update(FCrc, @ABuf, Result);
  end
  else if not FClosed then
    VerifyAtEof;
end;

procedure TZipVerifyReader.VerifyAtEof;
begin
  if UInt64(FSeen) <> FExpectedSize then
    raise EIOError.Create('zip: decompressed size mismatch for ' + FName);
  if FVerifyCrc and (FCrc <> FExpectedCrc) then
    raise EIOError.Create('zip: crc mismatch for ' + FName);
end;

procedure TZipVerifyReader.Close;
begin
  FClosed := True;
  if FInnerCloser <> nil then
  begin
    FInnerCloser.Close;
    FInnerCloser := nil;
  end;
end;

{ ---- 内存 / 可定位流两种读器共用的解析与校验路径 ---- }

{ 区间 [APos, APos+ALen) 必须落在 AC 缓冲内，否则结构视为截断损坏 }
procedure NeedRangeIn(const AC: IByteCursor; APos, ALen: Int64;
  const AWhat: string);
begin
  if (APos < 0) or (ALen < 0) or (APos + ALen > Int64(AC.Length)) then
    raise EParseError.Create('zip: truncated ' + AWhat);
end;

{ 解析单个 central 条目（游标须已对齐签名处，签名由调用方校验并消费）：
  固定字段、文件名、extra 链（0x0001 内顺序固定：原始尺寸、压缩尺寸、
  本地头偏移）、注释跳过 }
procedure ParseCentralEntry(var AC: IByteCursor; out AE: TZipEntryInfo;
  out AFlags: Word);
var
  LMethodCode, LNameLen, LExtraLen, LCommentFieldLen: Word;
  LDosTime, LDosDate: Word;
  LCrc, LExtAttrs: LongWord;
  LCSize, LUSize, LLho: UInt64;
  LNameBytes: TBytes;
  LExtraBytes: TBytes;
  LAesVersion, LAesVendor, LAesRealMethod: Word;
  LAesStrength: Byte;
  LHasAes: Boolean;
begin
  AC.ReadU16LE;                              { version made by }
  AC.ReadU16LE;                              { version needed }
  AFlags := AC.ReadU16LE;
  LMethodCode := AC.ReadU16LE;
  LDosTime := AC.ReadU16LE;
  LDosDate := AC.ReadU16LE;
  LCrc := AC.ReadU32LE;
  LCSize := AC.ReadU32LE;
  LUSize := AC.ReadU32LE;
  LNameLen := AC.ReadU16LE;
  LExtraLen := AC.ReadU16LE;
  LCommentFieldLen := AC.ReadU16LE;
  AC.ReadU16LE;                              { disk number start }
  AC.ReadU16LE;                              { internal attrs }
  LExtAttrs := AC.ReadU32LE;
  LLho := AC.ReadU32LE;

  NeedRangeIn(AC, Int64(AC.Position),
    Int64(LNameLen) + LExtraLen + LCommentFieldLen, 'central entry body');

  LNameBytes := nil;
  if LNameLen > 0 then
    LNameBytes := AC.ReadBytes(LNameLen);

  LExtraBytes := nil;
  if LExtraLen > 0 then
    LExtraBytes := AC.ReadBytes(LExtraLen);
  DecodeCentralExtra(LExtraBytes, LUSize, LCSize, LLho, LHasAes,
    LAesVersion, LAesVendor, LAesRealMethod, LAesStrength);
  AC.Seek(AC.Position + SizeUInt(LCommentFieldLen));

  AE.Name := '';
  if LNameLen > 0 then
  begin
    SetLength(AE.Name, LNameLen);
    Move(LNameBytes[0], PChar(AE.Name)^, SizeUInt(LNameLen));
  end;

  { 加密条目：wire 方法 99，真实压缩方法与强度取自 0x9901 extra。
    AE-2 头部 CRC 恒为 0（写端契约）；AE-1 保留真实 CRC 走常规校验 }
  AE.IsEncrypted := (AFlags and C_ZIP_FLAG_ENCRYPTED) <> 0;
  AE.AesVersion := 0;
  AE.AesStrengthCode := 0;
  if LMethodCode = C_ZIP_METHOD_WINZIP_AES then
  begin
    if not AE.IsEncrypted then
      raise EParseError.Create(
        'zip: method 99 without encryption flag: ' + AE.Name);
    if not LHasAes then
      raise EParseError.Create(
        'zip: missing WinZip AES extra field: ' + AE.Name);
    if (LAesVersion <> C_WINZIP_AES_VERSION_1) and
       (LAesVersion <> C_WINZIP_AES_VERSION_2) then
      raise ENotSupportedError.CreateFmt(
        'zip: unsupported WinZip AES version %d: %s',
        [LAesVersion, AE.Name]);
    if (LAesStrength < 1) or (LAesStrength > 3) then
      raise EParseError.Create('zip: invalid WinZip AES strength code');
    AE.AesVersion := LAesVersion;
    AE.AesStrengthCode := LAesStrength;
    LMethodCode := LAesRealMethod;
  end;

  if LMethodCode = C_ZIP_METHOD_DEFLATE then
    AE.Method := zmDeflate
  else
    AE.Method := zmStore;
  AE.MethodCode := LMethodCode;
  AE.Crc32 := LCrc;
  AE.CompressedSize := LCSize;
  AE.UncompressedSize := LUSize;
  AE.ModTimeUnixSec := UnixFromDosDateTime(LDosDate, LDosTime);
  AE.LocalHeaderOffset := LLho;
  AE.IsDirectory :=
    ((LNameLen > 0) and (LNameBytes[LNameLen - 1] = Ord('/'))) or
    (((LExtAttrs shr 16) and $F000) = $4000);
  AE.ExternalAttrs := LExtAttrs;
  AE.IsSymlink :=
    ((LExtAttrs shr 16) and $F000) = C_ZIP_UNIX_MODE_SYMLINK;
end;

function DefaultZipReadOptions: TZipReadOptions;
begin
  Result.MaxOutputSize := C_ZIP_DEFAULT_MAX_OUTPUT;
  Result.MaxTotalOutputSize := 0;
  Result.Password := nil;
end;

function NewZipReader(const AData: TBytes): IZipReader;
begin
  Result := NewZipReaderWithOptions(AData, DefaultZipReadOptions);
end;

function NewZipReaderWithOptions(const AData: TBytes;
  const AOptions: TZipReadOptions): IZipReader;
var
  LMax: SizeUInt;
begin
  LMax := AOptions.MaxOutputSize;
  if LMax = 0 then
    LMax := C_ZIP_DEFAULT_MAX_OUTPUT;
  Result := TZipReaderImpl.Create(AData, LMax, AOptions.MaxTotalOutputSize,
    AOptions.Password);
end;

constructor TZipReaderImpl.Create(const AData: TBytes; AMaxOutput: SizeUInt;
  AMaxTotalOutput: UInt64; const APassword: TBytes);
begin
  inherited Create;
  FData := AData;
  FC := NewByteCursor(AData);
  FMaxOutputSize := AMaxOutput;
  FMaxTotalOutputSize := AMaxTotalOutput;
  FPassword := APassword;
  ParseCentralDirectory;
end;

{ 区间 [APos, APos+ALen) 必须落在缓冲区内，否则结构视为截断损坏 }
procedure TZipReaderImpl.NeedRange(APos, ALen: Int64; const AWhat: string);
begin
  if (APos < 0) or (ALen < 0) or (APos + ALen > Int64(FC.Length)) then
    raise EParseError.Create('zip: truncated ' + AWhat);
end;

procedure TZipReaderImpl.ParseCentralDirectory;
var
  LI: Integer;
  LEocdPos, LMinPos, LLocatorPos: Int64;
  LDiskNum, LCdStartDisk, LCount16, LCommentLen: Word;
  LCount: Int64;
  LCdSize, LCdOffset, LZ64EocdOffset: UInt64;
begin
  if FC.Length < C_EOCD_MIN_LEN then
    raise EParseError.Create('zip: truncated archive');

  { 从尾部向前找 EOCD 签名（注释区可含任意字节，取最靠后者） }
  LEocdPos := -1;
  LMinPos := Int64(FC.Length) - C_EOCD_MIN_LEN - C_MAX_COMMENT_LEN;
  if LMinPos < 0 then
    LMinPos := 0;
  LI := Int64(FC.Length) - C_EOCD_MIN_LEN;
  while LI >= LMinPos do
  begin
    if FC.PeekU32LE(SizeUInt(LI)) = C_ZIP_EOCD_SIG then
    begin
      LEocdPos := LI;
      Break;
    end;
    Dec(LI);
  end;
  if LEocdPos < 0 then
    raise EParseError.Create('zip: end of central directory not found');

  FC.Seek(SizeUInt(LEocdPos));
  FC.ReadU32LE;                       { EOCD 签名 }
  LDiskNum := FC.ReadU16LE;
  LCdStartDisk := FC.ReadU16LE;
  FC.ReadU16LE;                       { 本盘条目数（多盘不支持，看总数即可） }
  LCount16 := FC.ReadU16LE;
  LCdSize := FC.ReadU32LE;
  LCdOffset := FC.ReadU32LE;
  LCommentLen := FC.ReadU16LE;
  if LEocdPos + C_EOCD_MIN_LEN + LCommentLen > Int64(FC.Length) then
    raise EParseError.Create('zip: truncated archive comment');
  if (LDiskNum <> 0) or (LCdStartDisk <> 0) then
    raise ENotSupportedError.Create('zip: multi-disk archives not supported');

  { Zip64：经典字段占位值出现时，经 locator 定位 zip64 EOCD 取真实值 }
  if (LCdOffset = UInt64($FFFFFFFF)) or (LCdSize = UInt64($FFFFFFFF)) or
     (LCount16 = $FFFF) then
  begin
    LLocatorPos := LEocdPos - C_ZIP64_LOCATOR_LEN;
    NeedRange(LLocatorPos, C_ZIP64_LOCATOR_LEN, 'zip64 locator');
    FC.Seek(SizeUInt(LLocatorPos));
    if FC.ReadU32LE <> C_ZIP64_EOCD_LOC_SIG then
      raise EParseError.Create('zip: zip64 records missing');
    FC.ReadU32LE;                              { 本盘号 }
    LZ64EocdOffset := FC.ReadU64LE;
    NeedRange(Int64(LZ64EocdOffset), C_ZIP64_EOCD_LEN,
      'zip64 end of central directory');
    FC.Seek(SizeUInt(LZ64EocdOffset));
    if FC.ReadU32LE <> C_ZIP64_EOCD_SIG then
      raise EParseError.Create('zip: bad zip64 EOCD signature');
    FC.ReadU64LE;                              { 记录体尺寸 }
    FC.ReadU16LE;                              { version made by }
    FC.ReadU16LE;                              { version needed }
    FC.ReadU32LE;                              { 本盘号 }
    FC.ReadU32LE;                              { central 起始盘号 }
    FC.ReadU64LE;                              { 本盘条目数 }
    LCount := Int64(FC.ReadU64LE);
    LCdSize := FC.ReadU64LE;
    LCdOffset := FC.ReadU64LE;
  end
  else
    LCount := LCount16;

  if (LCdOffset > FC.Length) or
     (Int64(LCdOffset) + Int64(LCdSize) > Int64(FC.Length)) then
    raise EParseError.Create('zip: central directory out of bounds');

  { 条目数已知：一次性分配，避免逐条目扩容 }
  if LCount > High(Integer) - 1 then
    raise EParseError.Create('zip: entry count out of range');
  SetLength(FEntries, LCount);
  SetLength(FFlags, LCount);

  FC.Seek(SizeUInt(LCdOffset));
  for LI := 0 to LCount - 1 do
  begin
    NeedRange(Int64(FC.Position), C_CENTRAL_HEADER_LEN, 'central header');
    if FC.ReadU32LE <> C_ZIP_CENTRAL_SIG then
      raise EParseError.Create('zip: bad central header signature at ' +
        IntToStr(Int64(FC.Position) - 4));
    ParseCentralEntry(FC, FEntries[LI], FFlags[LI]);
  end;
  if FMaxTotalOutputSize <> 0 then
  begin
    LCdSize := 0;
    for LI := 0 to LCount - 1 do
    begin
      if FEntries[LI].UncompressedSize > FMaxTotalOutputSize then
        raise EIOError.Create('zip: total uncompressed size exceeds limit');
      if LCdSize > FMaxTotalOutputSize - FEntries[LI].UncompressedSize then
        raise EIOError.Create('zip: total uncompressed size exceeds limit');
      Inc(LCdSize, FEntries[LI].UncompressedSize);
    end;
  end;
end;

function TZipReaderImpl.CheckIndex(AIndex: Integer): Integer;
begin
  if (AIndex < 0) or (AIndex >= Length(FEntries)) then
    raise EIndexOutOfRangeError.Create(
      'zip: entry index out of range: ' + IntToStr(AIndex));
  Result := AIndex;
end;

function TZipReaderImpl.EntryCount: Integer;
begin
  Result := Length(FEntries);
end;

function TZipReaderImpl.Entry(AIndex: Integer): TZipEntryInfo;
begin
  Result := FEntries[CheckIndex(AIndex)];
end;

function TZipReaderImpl.Find(const AName: string): Integer;
var
  LI: Integer;
begin
  for LI := 0 to High(FEntries) do
    if FEntries[LI].Name = AName then
      Exit(LI);
  Result := -1;
end;

{ 加密/安全名守卫 + local header 走查，返回条目载荷起始偏移。
  本地头字段逐一消费：尺寸以 central 为准，天然容忍 data descriptor(bit3)。 }
function TZipReaderImpl.LocatePayload(AIndex: Integer): Int64;
var
  LE: TZipEntryInfo;
  LLho: Int64;
  LNameLen, LExtraLen: Word;
begin
  LE := FEntries[CheckIndex(AIndex)];
  GuardEntryReadable(LE, FFlags[AIndex]);

  LLho := Int64(LE.LocalHeaderOffset);
  NeedRange(LLho, C_LOCAL_HEADER_LEN, 'local header');
  FC.Seek(SizeUInt(LLho));
  if FC.ReadU32LE <> C_ZIP_LOCAL_SIG then
    raise EParseError.Create('zip: bad local header signature');
  FC.ReadU16LE;                    { version needed }
  FC.ReadU16LE;                    { flags }
  FC.ReadU16LE;                    { method }
  FC.ReadU16LE;                    { DOS time }
  FC.ReadU16LE;                    { DOS date }
  FC.ReadU32LE;                    { local crc }
  FC.ReadU32LE;                    { local compressed size（描述符时为占位） }
  FC.ReadU32LE;                    { local uncompressed size（同上） }
  LNameLen := FC.ReadU16LE;
  LExtraLen := FC.ReadU16LE;
  Result := LLho + C_LOCAL_HEADER_LEN + LNameLen + LExtraLen;
  NeedRange(Result, Int64(LE.CompressedSize), 'entry payload');
end;

function TZipReaderImpl.ExtractIndex(AIndex: Integer): TBytes;
var
  LE: TZipEntryInfo;
  LPayload: TBytes;
begin
  LE := FEntries[CheckIndex(AIndex)];
  LPayload := Copy(FData, LocatePayload(AIndex), Int64(LE.CompressedSize));
  Result := DecompressEntryVerified(LE, LPayload, FPassword, FMaxOutputSize);
end;

function TZipReaderImpl.ExtractToBytes(AIndex: Integer): TBytes;
begin
  Result := ExtractIndex(CheckIndex(AIndex));
end;

function TZipReaderImpl.ExtractToBytesByName(const AName: string): TBytes;
var
  LIdx: Integer;
begin
  LIdx := Find(AName);
  if LIdx < 0 then
    raise ENotFoundError.Create('zip: entry not found: ' + AName);
  Result := ExtractIndex(LIdx);
end;

function TZipReaderImpl.OpenEntry(AIndex: Integer): IDecompressReader;
var
  LE: TZipEntryInfo;
  LOfs: Int64;
  LSlice: TSliceReader;
  LInflate: IDecompressReader;
  LInner: IReader;
begin
  LE := FEntries[CheckIndex(AIndex)];
  { 缺口令在进入解封层前拒绝：避免异常穿越持有接口实参的调用帧 }
  if LE.IsEncrypted and (Length(FPassword) = 0) then
    raise EInvalidOperationError.Create(
      'zip: entry is encrypted, no password configured: ' + LE.Name);
  LOfs := LocatePayload(AIndex);
  LSlice := TSliceReader.Create(FData, SizeUInt(LOfs),
    SizeUInt(LE.CompressedSize));
  { 加密条目：解封装层夹在切片与解压之间（构造即强校验口令校验值） }
  LInner := LSlice;
  if LE.IsEncrypted and (LE.AesVersion > 0) then
    LInner := NewWinZipAesReader(LSlice, FPassword, LE.AesStrengthCode,
      LE.CompressedSize - WinZipAesFrameOverhead(LE.AesStrengthCode),
      LE.Name);
  LInflate := nil;
  if LE.MethodCode = C_ZIP_METHOD_DEFLATE then
  begin
    LInflate := CreateRawDeflateReaderWithMaxOutputSize(LInner,
      FMaxOutputSize);
    LInner := LInflate;
  end
  else if LE.MethodCode <> C_ZIP_METHOD_STORE then
    raise ENotSupportedError.Create('zip: unsupported compression method ' +
      IntToStr(LE.MethodCode) + ': ' + LE.Name);
  Result := TZipVerifyReader.Create(LInner, LInflate, LE.Name, LE.Crc32,
    LE.UncompressedSize, FMaxOutputSize,
    LE.AesVersion <> C_WINZIP_AES_VERSION_2);
end;

function TZipReaderImpl.OpenEntryByName(const AName: string): IDecompressReader;
var
  LIdx: Integer;
begin
  LIdx := Find(AName);
  if LIdx < 0 then
    raise ENotFoundError.Create('zip: entry not found: ' + AName);
  Result := OpenEntry(LIdx);
end;

function TZipReaderImpl.CopyEntryTo(AIndex: Integer;
  const ADst: IWriter): SizeUInt;
const
  C_BUF = 65536;
var
  LS: IDecompressReader;
  LBuf: array[0..C_BUF - 1] of Byte;
  LN: SizeUInt;
begin
  if ADst = nil then
    raise EArgumentError.Create('zip: destination writer is nil');
  Result := 0;
  LS := OpenEntry(AIndex);
  try
    repeat
      LN := LS.Read(LBuf[0], C_BUF);
      if LN > 0 then
      begin
        if ADst.Write(LBuf[0], LN) <> LN then
          raise EIOError.Create('zip: short write while pumping entry');
        Inc(Result, LN);
      end;
    until LN = 0;
  finally
    LS.Close;
  end;
end;

{ ---- 可定位流来源的读器 ---- }

constructor TSourceSpanReader.Create(const AAt: IReaderAt; AOffset: Int64;
  ALength: SizeUInt);
begin
  inherited Create;
  FAt := AAt;
  FPos := UInt64(AOffset);
  FRemaining := ALength;
end;

function TSourceSpanReader.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LN, LGot: SizeUInt;
begin
  LN := ACount;
  if LN > FRemaining then
    LN := FRemaining;
  if LN = 0 then
    Exit(0);
  { 定位读不触碰共享位置；短读仅发生在源 EOF，交由上层校验语义处理 }
  LGot := FAt.ReadAt(ABuf, LN, Int64(FPos));
  Inc(FPos, LGot);
  Dec(FRemaining, LGot);
  Result := LGot;
end;

constructor TZipSourceReader.Create(const ASource: IStream;
  AMaxOutput: SizeUInt; AMaxTotalOutput: UInt64; const APassword: TBytes);
begin
  inherited Create;
  if ASource = nil then
    raise EArgumentError.Create('zip: nil source stream');
  FSrc := ASource;
  if ASource.QueryInterface(IReaderAt, FAt) <> 0 then
    raise ENotSupportedError.Create(
      'zip: source stream does not support positioned reads (IReaderAt)');
  FSize := ASource.GetSize;
  FMaxOutputSize := AMaxOutput;
  FMaxTotalOutputSize := AMaxTotalOutput;
  FPassword := APassword;
  ParseCentralDirectory;
end;

procedure TZipSourceReader.Fetch(APos: Int64; ACount: SizeUInt;
  out ADst: TBytes; const AWhat: string);
var
  LGot: SizeUInt;
begin
  if (APos < 0) or (APos + Int64(ACount) > FSize) then
    raise EParseError.Create('zip: truncated ' + AWhat);
  SetLength(ADst, ACount);
  if ACount > 0 then
  begin
    LGot := FAt.ReadAt(ADst[0], ACount, APos);
    if LGot <> ACount then
      raise EParseError.Create('zip: truncated ' + AWhat);
  end;
end;

{ 区间 [APos, APos+ALen) 必须落在源长度内，否则结构视为截断损坏 }
procedure TZipSourceReader.NeedRange(APos, ALen: Int64; const AWhat: string);
begin
  if (APos < 0) or (ALen < 0) or (APos + ALen > FSize) then
    raise EParseError.Create('zip: truncated ' + AWhat);
end;

procedure TZipSourceReader.ParseCentralDirectory;
var
  LI: Integer;
  LTailBase, LEocdRel, LEocdAbs, LLocatorPos: Int64;
  LDiskNum, LCdStartDisk, LCount16, LCommentLen: Word;
  LCount: Int64;
  LCdSize, LCdOffset, LZ64EocdOffset: UInt64;
  LTail, LBuf, LCDBuf: TBytes;
  LC: IByteCursor;
begin
  if FSize < C_EOCD_MIN_LEN then
    raise EParseError.Create('zip: truncated archive');

  { 尾窗（注释区最大宽度）内从后向前找 EOCD 签名；字段与 zip64 记录随后
    逐段定位取数 }
  LTailBase := FSize - Int64(C_MAX_COMMENT_LEN) - C_EOCD_MIN_LEN;
  if LTailBase < 0 then
    LTailBase := 0;
  Fetch(LTailBase, SizeUInt(FSize - LTailBase), LTail, 'archive');
  LC := NewByteCursor(LTail);
  LEocdRel := -1;
  LI := Integer(LC.Length) - C_EOCD_MIN_LEN;
  while LI >= 0 do
  begin
    if LC.PeekU32LE(SizeUInt(LI)) = C_ZIP_EOCD_SIG then
    begin
      LEocdRel := LI;
      Break;
    end;
    Dec(LI);
  end;
  if LEocdRel < 0 then
    raise EParseError.Create('zip: end of central directory not found');
  LEocdAbs := LTailBase + LEocdRel;

  Fetch(LEocdAbs, C_EOCD_MIN_LEN, LBuf, 'end of central directory');
  LC := NewByteCursor(LBuf);
  LC.ReadU32LE;                       { EOCD 签名 }
  LDiskNum := LC.ReadU16LE;
  LCdStartDisk := LC.ReadU16LE;
  LC.ReadU16LE;                       { 本盘条目数（多盘不支持，看总数即可） }
  LCount16 := LC.ReadU16LE;
  LCdSize := LC.ReadU32LE;
  LCdOffset := LC.ReadU32LE;
  LCommentLen := LC.ReadU16LE;
  if LEocdAbs + C_EOCD_MIN_LEN + LCommentLen > FSize then
    raise EParseError.Create('zip: truncated archive comment');
  if (LDiskNum <> 0) or (LCdStartDisk <> 0) then
    raise ENotSupportedError.Create('zip: multi-disk archives not supported');

  { Zip64：经典字段占位值出现时，经 locator 定位 zip64 EOCD 取真实值 }
  if (LCdOffset = UInt64($FFFFFFFF)) or (LCdSize = UInt64($FFFFFFFF)) or
     (LCount16 = $FFFF) then
  begin
    LLocatorPos := LEocdAbs - C_ZIP64_LOCATOR_LEN;
    NeedRange(LLocatorPos, C_ZIP64_LOCATOR_LEN, 'zip64 locator');
    Fetch(LLocatorPos, C_ZIP64_LOCATOR_LEN, LBuf, 'zip64 locator');
    LC := NewByteCursor(LBuf);
    if LC.ReadU32LE <> C_ZIP64_EOCD_LOC_SIG then
      raise EParseError.Create('zip: zip64 records missing');
    LC.ReadU32LE;                              { 本盘号 }
    LZ64EocdOffset := LC.ReadU64LE;
    NeedRange(Int64(LZ64EocdOffset), C_ZIP64_EOCD_LEN,
      'zip64 end of central directory');
    Fetch(Int64(LZ64EocdOffset), C_ZIP64_EOCD_LEN, LBuf,
      'zip64 end of central directory');
    LC := NewByteCursor(LBuf);
    if LC.ReadU32LE <> C_ZIP64_EOCD_SIG then
      raise EParseError.Create('zip: bad zip64 EOCD signature');
    LC.ReadU64LE;                              { 记录体尺寸 }
    LC.ReadU16LE;                              { version made by }
    LC.ReadU16LE;                              { version needed }
    LC.ReadU32LE;                              { 本盘号 }
    LC.ReadU32LE;                              { central 起始盘号 }
    LC.ReadU64LE;                              { 本盘条目数 }
    LCount := Int64(LC.ReadU64LE);
    LCdSize := LC.ReadU64LE;
    LCdOffset := LC.ReadU64LE;
  end
  else
    LCount := LCount16;

  if (LCdOffset > UInt64(FSize)) or
     (Int64(LCdOffset) + Int64(LCdSize) > FSize) then
    raise EParseError.Create('zip: central directory out of bounds');

  { 条目数已知：一次性分配，避免逐条目扩容 }
  if LCount > High(Integer) - 1 then
    raise EParseError.Create('zip: entry count out of range');
  SetLength(FEntries, LCount);
  SetLength(FFlags, LCount);

  Fetch(Int64(LCdOffset), SizeUInt(LCdSize), LCDBuf, 'central directory');
  LC := NewByteCursor(LCDBuf);
  for LI := 0 to LCount - 1 do
  begin
    NeedRangeIn(LC, Int64(LC.Position), C_CENTRAL_HEADER_LEN, 'central header');
    if LC.ReadU32LE <> C_ZIP_CENTRAL_SIG then
      raise EParseError.Create('zip: bad central header signature at ' +
        IntToStr(Int64(LCdOffset) + Int64(LC.Position) - 4));
    ParseCentralEntry(LC, FEntries[LI], FFlags[LI]);
  end;
  if FMaxTotalOutputSize <> 0 then
  begin
    LCdSize := 0;
    for LI := 0 to LCount - 1 do
    begin
      if FEntries[LI].UncompressedSize > FMaxTotalOutputSize then
        raise EIOError.Create('zip: total uncompressed size exceeds limit');
      if LCdSize > FMaxTotalOutputSize - FEntries[LI].UncompressedSize then
        raise EIOError.Create('zip: total uncompressed size exceeds limit');
      Inc(LCdSize, FEntries[LI].UncompressedSize);
    end;
  end;
end;

function TZipSourceReader.CheckIndex(AIndex: Integer): Integer;
begin
  if (AIndex < 0) or (AIndex >= Length(FEntries)) then
    raise EIndexOutOfRangeError.Create(
      'zip: entry index out of range: ' + IntToStr(AIndex));
  Result := AIndex;
end;

function TZipSourceReader.EntryCount: Integer;
begin
  Result := Length(FEntries);
end;

function TZipSourceReader.Entry(AIndex: Integer): TZipEntryInfo;
begin
  Result := FEntries[CheckIndex(AIndex)];
end;

function TZipSourceReader.Find(const AName: string): Integer;
var
  LI: Integer;
begin
  for LI := 0 to High(FEntries) do
    if FEntries[LI].Name = AName then
      Exit(LI);
  Result := -1;
end;

{ 加密/安全名守卫 + local header 走查（定位读 30 字节固定头），
  返回条目载荷起始偏移。尺寸以 central 为准，天然容忍 data descriptor。 }
function TZipSourceReader.LocatePayload(AIndex: Integer): Int64;
var
  LE: TZipEntryInfo;
  LLho: Int64;
  LHeader: TBytes;
  LC: IByteCursor;
  LNameLen, LExtraLen: Word;
begin
  LE := FEntries[CheckIndex(AIndex)];
  GuardEntryReadable(LE, FFlags[AIndex]);

  LLho := Int64(LE.LocalHeaderOffset);
  NeedRange(LLho, C_LOCAL_HEADER_LEN, 'local header');
  Fetch(LLho, C_LOCAL_HEADER_LEN, LHeader, 'local header');
  LC := NewByteCursor(LHeader);
  if LC.ReadU32LE <> C_ZIP_LOCAL_SIG then
    raise EParseError.Create('zip: bad local header signature');
  LC.ReadU16LE;                    { version needed }
  LC.ReadU16LE;                    { flags }
  LC.ReadU16LE;                    { method }
  LC.ReadU16LE;                    { DOS time }
  LC.ReadU16LE;                    { DOS date }
  LC.ReadU32LE;                    { local crc }
  LC.ReadU32LE;                    { local compressed size（描述符时为占位） }
  LC.ReadU32LE;                    { local uncompressed size（同上） }
  LNameLen := LC.ReadU16LE;
  LExtraLen := LC.ReadU16LE;
  Result := LLho + C_LOCAL_HEADER_LEN + LNameLen + LExtraLen;
  NeedRange(Result, Int64(LE.CompressedSize), 'entry payload');
end;

function TZipSourceReader.ExtractIndex(AIndex: Integer): TBytes;
var
  LE: TZipEntryInfo;
  LPayload: TBytes;
begin
  LE := FEntries[CheckIndex(AIndex)];
  Fetch(LocatePayload(AIndex), SizeUInt(LE.CompressedSize), LPayload,
    'entry payload');
  Result := DecompressEntryVerified(LE, LPayload, FPassword, FMaxOutputSize);
end;

function TZipSourceReader.ExtractToBytes(AIndex: Integer): TBytes;
begin
  Result := ExtractIndex(CheckIndex(AIndex));
end;

function TZipSourceReader.ExtractToBytesByName(const AName: string): TBytes;
var
  LIdx: Integer;
begin
  LIdx := Find(AName);
  if LIdx < 0 then
    raise ENotFoundError.Create('zip: entry not found: ' + AName);
  Result := ExtractIndex(LIdx);
end;

function TZipSourceReader.OpenEntry(AIndex: Integer): IDecompressReader;
var
  LE: TZipEntryInfo;
  LOfs: Int64;
  LSpan: TSourceSpanReader;
  LInflate: IDecompressReader;
  LInner: IReader;
begin
  LE := FEntries[CheckIndex(AIndex)];
  { 缺口令在进入解封层前拒绝：避免异常穿越持有接口实参的调用帧 }
  if LE.IsEncrypted and (Length(FPassword) = 0) then
    raise EInvalidOperationError.Create(
      'zip: entry is encrypted, no password configured: ' + LE.Name);
  LOfs := LocatePayload(AIndex);
  LSpan := TSourceSpanReader.Create(FAt, LOfs, SizeUInt(LE.CompressedSize));
  { 加密条目：解封装层夹在区间读与解压之间（构造即强校验口令校验值） }
  LInner := LSpan;
  if LE.IsEncrypted and (LE.AesVersion > 0) then
    LInner := NewWinZipAesReader(LSpan, FPassword, LE.AesStrengthCode,
      LE.CompressedSize - WinZipAesFrameOverhead(LE.AesStrengthCode),
      LE.Name);
  LInflate := nil;
  if LE.MethodCode = C_ZIP_METHOD_DEFLATE then
  begin
    LInflate := CreateRawDeflateReaderWithMaxOutputSize(LInner,
      FMaxOutputSize);
    LInner := LInflate;
  end
  else if LE.MethodCode <> C_ZIP_METHOD_STORE then
    raise ENotSupportedError.Create('zip: unsupported compression method ' +
      IntToStr(LE.MethodCode) + ': ' + LE.Name);
  Result := TZipVerifyReader.Create(LInner, LInflate, LE.Name, LE.Crc32,
    LE.UncompressedSize, FMaxOutputSize,
    LE.AesVersion <> C_WINZIP_AES_VERSION_2);
end;

function TZipSourceReader.OpenEntryByName(const AName: string): IDecompressReader;
var
  LIdx: Integer;
begin
  LIdx := Find(AName);
  if LIdx < 0 then
    raise ENotFoundError.Create('zip: entry not found: ' + AName);
  Result := OpenEntry(LIdx);
end;

function TZipSourceReader.CopyEntryTo(AIndex: Integer;
  const ADst: IWriter): SizeUInt;
const
  C_BUF = 65536;
var
  LS: IDecompressReader;
  LBuf: array[0..C_BUF - 1] of Byte;
  LN: SizeUInt;
begin
  if ADst = nil then
    raise EArgumentError.Create('zip: destination writer is nil');
  Result := 0;
  LS := OpenEntry(AIndex);
  try
    repeat
      LN := LS.Read(LBuf[0], C_BUF);
      if LN > 0 then
      begin
        if ADst.Write(LBuf[0], LN) <> LN then
          raise EIOError.Create('zip: short write while pumping entry');
        Inc(Result, LN);
      end;
    until LN = 0;
  finally
    LS.Close;
  end;
end;

{ 工厂 }

function NewZipReaderFrom(const ASource: IStream): IZipReader;
begin
  Result := NewZipReaderFromWithOptions(ASource, DefaultZipReadOptions);
end;

function NewZipReaderFromWithOptions(const ASource: IStream;
  const AOptions: TZipReadOptions): IZipReader;
var
  LMax: SizeUInt;
begin
  LMax := AOptions.MaxOutputSize;
  if LMax = 0 then
    LMax := C_ZIP_DEFAULT_MAX_OUTPUT;
  Result := TZipSourceReader.Create(ASource, LMax,
    AOptions.MaxTotalOutputSize, AOptions.Password);
end;

end.
