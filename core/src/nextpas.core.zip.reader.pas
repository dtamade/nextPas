unit nextpas.core.zip.reader;
{**
 * @desc ZIP 归档读器实现：解析 EOCD/central directory（含 Zip64 定位记录与
 *       Zip64 extra 字段），按条目提取并强制 CRC32 与尺寸校验。
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
    FEntries: array of TZipEntryInfo;
    FFlags: array of Word;
    FMaxOutputSize: SizeUInt;
    procedure ParseCentralDirectory;
    function CheckIndex(AIndex: Integer): Integer;
    function ExtractIndex(AIndex: Integer): TBytes;
    procedure NeedRange(APos, ALen: Int64; const AWhat: string); inline;
    function LE16At(APos: Int64): Word; inline;
    function LE32At(APos: Int64): LongWord; inline;
    function LE64At(APos: Int64): UInt64;
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
  FMaxOutputSize := AMaxOutput;
  ParseCentralDirectory;
end;

procedure TZipReaderImpl.NeedRange(APos, ALen: Int64; const AWhat: string);
begin
  if (APos < 0) or (ALen < 0) or (APos + ALen > Int64(Length(FData))) then
    raise EParseError.Create('zip: truncated ' + AWhat);
end;

function TZipReaderImpl.LE16At(APos: Int64): Word;
begin
  Result := Word(FData[APos]) or (Word(FData[APos + 1]) shl 8);
end;

function TZipReaderImpl.LE32At(APos: Int64): LongWord;
begin
  Result := LongWord(LE16At(APos)) or (LongWord(LE16At(APos + 2)) shl 16);
end;

function TZipReaderImpl.LE64At(APos: Int64): UInt64;
begin
  Result := UInt64(LE32At(APos)) or (UInt64(LE32At(APos + 4)) shl 32);
end;

procedure TZipReaderImpl.ParseCentralDirectory;
var
  LI: Integer;
  LEocdPos, LMinPos, LLocatorPos: Integer;
  LDiskNum, LCdStartDisk, LCount16, LCommentLen: Word;
  LCount: Int64;
  LCdSize, LCdOffset, LZ64EocdOffset: UInt64;
  LP: Int64;
  LFlags, LMethodCode, LNameLen, LExtraLen, LCommentFieldLen: Word;
  LDosTime, LDosDate: Word;
  LCrc: LongWord;
  LExtAttrs: LongWord;
  LCSize, LUSize, LLho: UInt64;
  LName: string;
  LExtraPos: Int64;
  LExtraLeft, LExtraUsed: Integer;
  LExtraId, LExtraSize: Word;
  LInfo: TZipEntryInfo;
begin
  if Length(FData) < C_EOCD_MIN_LEN then
    raise EParseError.Create('zip: truncated archive');

  { 从尾部向前找 EOCD 签名（注释区可含任意字节，取最靠后者） }
  LEocdPos := -1;
  LMinPos := Length(FData) - C_EOCD_MIN_LEN - C_MAX_COMMENT_LEN;
  if LMinPos < 0 then
    LMinPos := 0;
  for LI := Length(FData) - C_EOCD_MIN_LEN downto LMinPos do
    if LE32At(LI) = C_ZIP_EOCD_SIG then
    begin
      LEocdPos := LI;
      Break;
    end;
  if LEocdPos < 0 then
    raise EParseError.Create('zip: end of central directory not found');

  NeedRange(LEocdPos, C_EOCD_MIN_LEN, 'end of central directory');
  LDiskNum := LE16At(LEocdPos + 4);
  LCdStartDisk := LE16At(LEocdPos + 6);
  LCount16 := LE16At(LEocdPos + 10);
  LCdSize := LE32At(LEocdPos + 12);
  LCdOffset := LE32At(LEocdPos + 16);
  LCommentLen := LE16At(LEocdPos + 20);
  if Int64(LEocdPos) + C_EOCD_MIN_LEN + LCommentLen > Int64(Length(FData)) then
    raise EParseError.Create('zip: truncated archive comment');
  if (LDiskNum <> 0) or (LCdStartDisk <> 0) then
    raise ENotSupportedError.Create('zip: multi-disk archives not supported');

  { Zip64：经典字段占位值出现时，经 locator 定位 zip64 EOCD 取真实值 }
  if (LCdOffset = UInt64($FFFFFFFF)) or (LCdSize = UInt64($FFFFFFFF)) or
     (LCount16 = $FFFF) then
  begin
    LLocatorPos := LEocdPos - C_ZIP64_LOCATOR_LEN;
    NeedRange(LLocatorPos, C_ZIP64_LOCATOR_LEN, 'zip64 locator');
    if LE32At(LLocatorPos) <> C_ZIP64_EOCD_LOC_SIG then
      raise EParseError.Create('zip: zip64 records missing');
    LZ64EocdOffset := LE64At(LLocatorPos + 8);
    NeedRange(Int64(LZ64EocdOffset), C_ZIP64_EOCD_LEN,
      'zip64 end of central directory');
    if LE32At(Int64(LZ64EocdOffset)) <> C_ZIP64_EOCD_SIG then
      raise EParseError.Create('zip: bad zip64 EOCD signature');
    LCount := Int64(LE64At(Int64(LZ64EocdOffset) + 32));
    LCdSize := LE64At(Int64(LZ64EocdOffset) + 40);
    LCdOffset := LE64At(Int64(LZ64EocdOffset) + 48);
  end
  else
    LCount := LCount16;

  if (LCdOffset > UInt64(Length(FData))) or
     (Int64(LCdOffset) + Int64(LCdSize) > Int64(Length(FData))) then
    raise EParseError.Create('zip: central directory out of bounds');

  SetLength(FEntries, 0);
  SetLength(FFlags, 0);
  LP := Int64(LCdOffset);
  for LI := 1 to LCount do
  begin
    NeedRange(LP, C_CENTRAL_HEADER_LEN, 'central header');
    if LE32At(LP) <> C_ZIP_CENTRAL_SIG then
      raise EParseError.Create('zip: bad central header signature at ' +
        IntToStr(LP));
    LFlags := LE16At(LP + 8);
    LMethodCode := LE16At(LP + 10);
    LDosTime := LE16At(LP + 12);
    LDosDate := LE16At(LP + 14);
    LCrc := LE32At(LP + 16);
    LCSize := LE32At(LP + 20);
    LUSize := LE32At(LP + 24);
    LNameLen := LE16At(LP + 28);
    LExtraLen := LE16At(LP + 30);
    LCommentFieldLen := LE16At(LP + 32);
    LExtAttrs := LE32At(LP + 38);
    LLho := LE32At(LP + 42);
    Inc(LP, C_CENTRAL_HEADER_LEN);
    NeedRange(LP, Int64(LNameLen) + LExtraLen + LCommentFieldLen,
      'central entry body');

    SetLength(LName, LNameLen);
    if LNameLen > 0 then
      Move(FData[LP], LName[1], LNameLen);
    Inc(LP, LNameLen);

    { 扫描 extra 字段链，取 Zip64 宽度值替换经典字段的 $FFFFFFFF 占位。
      APPNOTE 规定 0x0001 内顺序固定为：原始尺寸、压缩尺寸、本地头偏移。 }
    LExtraPos := LP;
    LExtraLeft := LExtraLen;
    while LExtraLeft >= 4 do
    begin
      LExtraId := LE16At(LExtraPos);
      LExtraSize := LE16At(LExtraPos + 2);
      if Integer(LExtraSize) > LExtraLeft - 4 then
        raise EParseError.Create('zip: malformed extra field');
      if LExtraId = C_ZIP64_EXTRA_ID then
      begin
        LExtraUsed := 0;
        if (LUSize = UInt64($FFFFFFFF)) and (LExtraSize - LExtraUsed >= 8) then
        begin
          LUSize := LE64At(LExtraPos + 4 + LExtraUsed);
          Inc(LExtraUsed, 8);
        end;
        if (LCSize = UInt64($FFFFFFFF)) and (LExtraSize - LExtraUsed >= 8) then
        begin
          LCSize := LE64At(LExtraPos + 4 + LExtraUsed);
          Inc(LExtraUsed, 8);
        end;
        if (LLho = UInt64($FFFFFFFF)) and (LExtraSize - LExtraUsed >= 8) then
          LLho := LE64At(LExtraPos + 4 + LExtraUsed);
      end;
      Inc(LExtraPos, 4 + Integer(LExtraSize));
      Dec(LExtraLeft, 4 + Integer(LExtraSize));
    end;
    Inc(LP, LExtraLen + LCommentFieldLen);

    LInfo.Name := LName;
    if LMethodCode = C_ZIP_METHOD_DEFLATE then
      LInfo.Method := zmDeflate
    else
      LInfo.Method := zmStore;
    LInfo.MethodCode := LMethodCode;
    LInfo.Crc32 := LCrc;
    LInfo.CompressedSize := LCSize;
    LInfo.UncompressedSize := LUSize;
    LInfo.ModTimeUnixSec := UnixFromDosDateTime(LDosDate, LDosTime);
    LInfo.LocalHeaderOffset := LLho;
    LInfo.IsDirectory :=
      ((LNameLen > 0) and (LName[LNameLen] = '/')) or
      (((LExtAttrs shr 16) and $F000) = $4000);

    SetLength(FEntries, Length(FEntries) + 1);
    SetLength(FFlags, Length(FFlags) + 1);
    FEntries[High(FEntries)] := LInfo;
    FFlags[High(FFlags)] := LFlags;
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
  if LE32At(LLho) <> C_ZIP_LOCAL_SIG then
    raise EParseError.Create('zip: bad local header signature');
  LNameLen := LE16At(LLho + 26);
  LExtraLen := LE16At(LLho + 28);
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
