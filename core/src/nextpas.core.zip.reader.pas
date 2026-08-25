unit nextpas.core.zip.reader;
{**
 * @desc ZIP 归档读器实现：解析 EOCD/central directory（含 Zip64 定位记录与
 *       Zip64 extra 字段），按条目提取并强制 CRC32 与尺寸校验。
 *
 * 性能：条目数组按 central count 一次性分配；解析经 bytes.cursor 边界受查
 * 游标完成，无逐条目扩容。
 *
 * 错误模型：结构损坏 → EParseError('zip: ...')；数据完整性失败（CRC/尺寸）→
 * EIOError；不支持的特性（加密、未知压缩方法、多盘归档）→ ENotSupportedError；
 * 索引越界 → EIndexOutOfRangeError；缺失条目 → ENotFoundError。
 * 敌意条目名在提取时以 EParseError 拒绝（zip-slip 防护）。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.zip.base;

type
  {** @desc 读选项：单条目解压输出上限（防 zip bomb）；0 = 采用默认上限 *}
  TZipReadOptions = record
    MaxOutputSize: SizeUInt;
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
  end;

const
  { 未显式配置时的单条目解压默认上限：1 GiB }
  C_ZIP_DEFAULT_MAX_OUTPUT = SizeUInt(1) shl 30;

{** 默认读选项。 *}
function DefaultZipReadOptions: TZipReadOptions; inline;

{** 解析归档字节；结构非法立即 raise。 *}
function NewZipReader(const AData: TBytes): IZipReader;

{** 同上，带输出上限选项（MaxOutputSize=0 取默认上限）。 *}
function NewZipReaderWithOptions(const AData: TBytes;
  const AOptions: TZipReadOptions): IZipReader;

implementation

uses
  nextpas.core.exception,
  nextpas.core.bytes.cursor,
  nextpas.core.checksum.crc32,
  nextpas.core.compress.deflate;

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
    procedure ParseCentralDirectory;
    function CheckIndex(AIndex: Integer): Integer;
    procedure NeedRange(APos, ALen: Int64; const AWhat: string);
    function ExtractIndex(AIndex: Integer): TBytes;
  public
    constructor Create(const AData: TBytes; AMaxOutput: SizeUInt);
    function EntryCount: Integer;
    function Entry(AIndex: Integer): TZipEntryInfo;
    function Find(const AName: string): Integer;
    function ExtractToBytes(AIndex: Integer): TBytes;
    function ExtractToBytesByName(const AName: string): TBytes;
  end;

function DefaultZipReadOptions: TZipReadOptions;
begin
  Result.MaxOutputSize := C_ZIP_DEFAULT_MAX_OUTPUT;
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
  Result := TZipReaderImpl.Create(AData, LMax);
end;

constructor TZipReaderImpl.Create(const AData: TBytes; AMaxOutput: SizeUInt);
begin
  inherited Create;
  FData := AData;
  FC := NewByteCursor(AData);
  FMaxOutputSize := AMaxOutput;
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
  LFlags, LMethodCode, LNameLen, LExtraLen, LCommentFieldLen: Word;
  LDosTime, LDosDate: Word;
  LCrc: LongWord;
  LExtAttrs: LongWord;
  LCSize, LUSize, LLho: UInt64;
  LName: string;
  LExtraLeft, LExtraUsed: Integer;
  LExtraId, LExtraSize: Word;
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
    FC.ReadU16LE;                              { version made by }
    FC.ReadU16LE;                              { version needed }
    LFlags := FC.ReadU16LE;
    LMethodCode := FC.ReadU16LE;
    LDosTime := FC.ReadU16LE;
    LDosDate := FC.ReadU16LE;
    LCrc := FC.ReadU32LE;
    LCSize := FC.ReadU32LE;
    LUSize := FC.ReadU32LE;
    LNameLen := FC.ReadU16LE;
    LExtraLen := FC.ReadU16LE;
    LCommentFieldLen := FC.ReadU16LE;
    FC.ReadU16LE;                              { disk number start }
    FC.ReadU16LE;                              { internal attrs }
    LExtAttrs := FC.ReadU32LE;
    LLho := FC.ReadU32LE;

    NeedRange(Int64(FC.Position),
      Int64(LNameLen) + LExtraLen + LCommentFieldLen, 'central entry body');

    SetLength(LName, LNameLen);
    if LNameLen > 0 then
    begin
      Move(FData[FC.Position], LName[1], LNameLen);
      FC.Seek(FC.Position + SizeUInt(LNameLen));
    end;

    { 扫描 extra 字段链，取 Zip64 宽度值替换经典字段的 $FFFFFFFF 占位。
      APPNOTE 规定 0x0001 内顺序固定为：原始尺寸、压缩尺寸、本地头偏移。 }
    LExtraLeft := LExtraLen;
    while LExtraLeft >= 4 do
    begin
      LExtraId := FC.ReadU16LE;
      LExtraSize := FC.ReadU16LE;
      if Integer(LExtraSize) > LExtraLeft - 4 then
        raise EParseError.Create('zip: malformed extra field');
      if LExtraId = C_ZIP64_EXTRA_ID then
      begin
        LExtraUsed := 0;
        if (LUSize = UInt64($FFFFFFFF)) and (LExtraSize - LExtraUsed >= 8) then
        begin
          LUSize := FC.ReadU64LE;
          Inc(LExtraUsed, 8);
        end;
        if (LCSize = UInt64($FFFFFFFF)) and (LExtraSize - LExtraUsed >= 8) then
        begin
          LCSize := FC.ReadU64LE;
          Inc(LExtraUsed, 8);
        end;
        if (LLho = UInt64($FFFFFFFF)) and (LExtraSize - LExtraUsed >= 8) then
          LLho := FC.ReadU64LE
        else
          FC.Seek(FC.Position + SizeUInt(LExtraSize - LExtraUsed));
      end
      else
        FC.Seek(FC.Position + SizeUInt(LExtraSize));
      Dec(LExtraLeft, 4 + Integer(LExtraSize));
    end;
    FC.Seek(FC.Position + SizeUInt(LCommentFieldLen));

    FEntries[LI].Name := LName;
    if LMethodCode = C_ZIP_METHOD_DEFLATE then
      FEntries[LI].Method := zmDeflate
    else
      FEntries[LI].Method := zmStore;
    FEntries[LI].MethodCode := LMethodCode;
    FEntries[LI].Crc32 := LCrc;
    FEntries[LI].CompressedSize := LCSize;
    FEntries[LI].UncompressedSize := LUSize;
    FEntries[LI].ModTimeUnixSec := UnixFromDosDateTime(LDosDate, LDosTime);
    FEntries[LI].LocalHeaderOffset := LLho;
    FEntries[LI].IsDirectory :=
      ((LNameLen > 0) and (LName[LNameLen] = '/')) or
      (((LExtAttrs shr 16) and $F000) = $4000);
    FEntries[LI].ExternalAttrs := LExtAttrs;
    FEntries[LI].IsSymlink :=
      ((LExtAttrs shr 16) and $F000) = C_ZIP_UNIX_MODE_SYMLINK;
    FFlags[LI] := LFlags;
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

function TZipReaderImpl.ExtractIndex(AIndex: Integer): TBytes;
var
  LE: TZipEntryInfo;
  LLho: Int64;
  LNameLen, LExtraLen: Word;
  LDataOff: Int64;
  LPayload: TBytes;
begin
  LE := FEntries[CheckIndex(AIndex)];
  if (FFlags[AIndex] and C_ZIP_FLAG_ENCRYPTED) <> 0 then
    raise ENotSupportedError.Create(
      'zip: encrypted entry not supported: ' + LE.Name);
  { 条目名来自不可信输入：提取前强制 zip-slip 防护 }
  if not IsSafeZipEntryName(LE.Name) then
    raise EParseError.Create('zip: refusing unsafe entry name: ' + LE.Name);

  LLho := Int64(LE.LocalHeaderOffset);
  NeedRange(LLho, C_LOCAL_HEADER_LEN, 'local header');
  FC.Seek(SizeUInt(LLho));
  if FC.ReadU32LE <> C_ZIP_LOCAL_SIG then
    raise EParseError.Create('zip: bad local header signature');
  FC.ReadU16LE;                    { version needed }
  FC.ReadU16LE;                    { flags（描述符置位的本地尺寸为占位，
                                      尺寸以 central 为准，故天然容忍 bit3） }
  FC.ReadU16LE;                    { method }
  FC.ReadU16LE;                    { DOS time }
  FC.ReadU16LE;                    { DOS date }
  FC.ReadU32LE;                    { local crc }
  FC.ReadU32LE;                    { local compressed size（描述符时为占位） }
  FC.ReadU32LE;                    { local uncompressed size（同上） }
  LNameLen := FC.ReadU16LE;
  LExtraLen := FC.ReadU16LE;
  LDataOff := LLho + C_LOCAL_HEADER_LEN + LNameLen + LExtraLen;
  NeedRange(LDataOff, Int64(LE.CompressedSize), 'entry payload');

  LPayload := Copy(FData, LDataOff, Int64(LE.CompressedSize));

  if LE.MethodCode = C_ZIP_METHOD_DEFLATE then
    Result := RawDeflateDecompressWithMaxOutputSize(LPayload, FMaxOutputSize)
  else if LE.MethodCode = C_ZIP_METHOD_STORE then
    Result := LPayload
  else
    raise ENotSupportedError.Create('zip: unsupported compression method ' +
      IntToStr(LE.MethodCode) + ': ' + LE.Name);

  if UInt64(Length(Result)) <> LE.UncompressedSize then
    raise EIOError.Create('zip: decompressed size mismatch for ' + LE.Name);
  if Crc32OfBytes(Result) <> LE.Crc32 then
    raise EIOError.Create('zip: crc mismatch for ' + LE.Name);
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

end.
