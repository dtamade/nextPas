unit nextpas.core.zip.common;
{**
 * @desc ZIP 共享内核：被 reader / sequential 复用的校验与解压路径。
 *       抽取 GuardEntryReadable / DecompressEntryVerified 等价语义，
 *       以及 LE* / IsKnownZipSig 等字节序助手，消除两读端重复，
 *       保证 fail-closed 与 CRC/尺寸/AES 语义单点一致。
 *       仅依赖 nextpas.*，无 FPC RTL 直接依赖。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.cursor,
  nextpas.core.zip.base;

function LE16At(const AData: TBytes; AOff: SizeUInt): Word; inline;
function LE32At(const AData: TBytes; AOff: SizeUInt): LongWord; inline;
function LE64At(const AData: TBytes; AOff: SizeUInt): UInt64; inline;

function IsKnownZipSig(AValue: LongWord): Boolean; inline;

{ 时间转换（base 纯记录层外的时间逻辑下沉至 common） }
procedure DosDateTimeFromUnix(AUnixSec: Int64; out ADosDate, ADosTime: Word);
function DosMinUnixSec: Int64; inline;
function UnixFromDosDateTime(ADosDate, ADosTime: Word): Int64;

procedure GuardEntryReadable(const AE: TZipEntryInfo; AFlags: Word);

procedure GuardTotalOutputSize(const AEntries: array of TZipEntryInfo;
  AMaxTotal: UInt64);

{ 单点 central 解析：供内存与定位流两读器复用，保持 CRC/尺寸/AES 语义一致 }
procedure NeedRangeIn(const AC: IByteCursor; APos, ALen: Int64; const AWhat: string);
procedure ParseCentralEntry(var AC: IByteCursor; out AE: TZipEntryInfo; out AFlags: Word);
procedure ZipParseCentralEntries(const ACDBuf: TBytes; ACdOffset: UInt64; ACount: Int64;
  AMaxTotal: UInt64; out AEntries: TZipEntryInfoArray; out AFlags: TZipFlagArray);

function DecompressEntryVerified(const AE: TZipEntryInfo;
  const APayload: TBytes; const APassword: TBytes;
  AMaxOutput: SizeUInt): TBytes;

function DecompressEntryToBuffer(const AE: TZipEntryInfo;
  const APayload: TBytes; const APassword: TBytes;
  const ADst: PByte; const ADstLen: SizeUInt; AMaxOutput: SizeUInt): SizeUInt;

implementation

uses
  nextpas.core.exception,
  nextpas.core.bytes.cursor,
  nextpas.core.checksum.crc32,
  nextpas.core.compress,
  nextpas.core.time.date,
  nextpas.core.zip.aes,
  nextpas.core.zip.extra;

function LE16At(const AData: TBytes; AOff: SizeUInt): Word;
begin
  Result := Word(AData[AOff]) or (Word(AData[AOff + 1]) shl 8);
end;

function LE32At(const AData: TBytes; AOff: SizeUInt): LongWord;
begin
  Result := LongWord(AData[AOff]) or (LongWord(AData[AOff + 1]) shl 8) or
    (LongWord(AData[AOff + 2]) shl 16) or (LongWord(AData[AOff + 3]) shl 24);
end;

function LE64At(const AData: TBytes; AOff: SizeUInt): UInt64;
begin
  Result := UInt64(LE32At(AData, AOff)) or (UInt64(LE32At(AData, AOff + 4)) shl 32);
end;

function IsKnownZipSig(AValue: LongWord): Boolean;
begin
  Result := (AValue = C_ZIP_LOCAL_SIG) or (AValue = C_ZIP_CENTRAL_SIG) or
    (AValue = C_ZIP_EOCD_SIG) or (AValue = C_ZIP64_EOCD_SIG) or
    (AValue = C_ZIP64_EOCD_LOC_SIG) or (AValue = C_ZIP_DESCRIPTOR_SIG);
end;

procedure NeedRangeIn(const AC: IByteCursor; APos, ALen: Int64; const AWhat: string);
begin
  if (APos < 0) or (ALen < 0) or (APos + ALen > Int64(AC.Length)) then
    raise EParseError.Create('zip: truncated ' + AWhat);
end;

procedure ParseCentralEntry(var AC: IByteCursor; out AE: TZipEntryInfo; out AFlags: Word);
var
  LMethodCode, LNameLen, LExtraLen, LCommentFieldLen: Word;
  LDosTime, LDosDate: Word;
  LCrc, LExtAttrs: LongWord;
  LCSize, LUSize, LLho: UInt64;
  LNamePtr, LExtraPtr: PByte;
  LAesVersion, LAesVendor, LAesRealMethod: Word;
  LAesStrength: Byte;
  LHasAes: Boolean;
begin
  AC.ReadU16LE;
  AC.ReadU16LE;
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
  AC.ReadU16LE;
  AC.ReadU16LE;
  LExtAttrs := AC.ReadU32LE;
  LLho := AC.ReadU32LE;
  NeedRangeIn(AC, Int64(AC.Position), Int64(LNameLen) + LExtraLen + LCommentFieldLen, 'central entry body');
  LNamePtr := nil;
  if LNameLen > 0 then
    LNamePtr := AC.ReadSpan(LNameLen);
  LExtraPtr := nil;
  if LExtraLen > 0 then
    LExtraPtr := AC.ReadSpan(LExtraLen);
  DecodeCentralExtraBuf(LExtraPtr, SizeUInt(LExtraLen), LUSize, LCSize, LLho,
    LHasAes, LAesVersion, LAesVendor, LAesRealMethod, LAesStrength);
  if (LUSize = UInt64($FFFFFFFF)) or (LCSize = UInt64($FFFFFFFF)) or
     (LLho = UInt64($FFFFFFFF)) then
    raise EParseError.Create('zip: missing Zip64 extra field');
  AC.Seek(AC.Position + SizeUInt(LCommentFieldLen));
  AE.Name := '';
  if LNameLen > 0 then
  begin
    SetLength(AE.Name, LNameLen);
    Move(LNamePtr^, PChar(AE.Name)^, SizeUInt(LNameLen));
  end;
  AE.IsEncrypted := (AFlags and C_ZIP_FLAG_ENCRYPTED) <> 0;
  AE.AesVersion := 0;
  AE.AesStrengthCode := 0;
  if LMethodCode = C_ZIP_METHOD_WINZIP_AES then
  begin
    if not AE.IsEncrypted then
      raise EParseError.Create('zip: method 99 without encryption flag: ' + AE.Name);
    if not LHasAes then
      raise EParseError.Create('zip: missing WinZip AES extra field: ' + AE.Name);
    if (LAesVersion <> C_WINZIP_AES_VERSION_1) and
       (LAesVersion <> C_WINZIP_AES_VERSION_2) then
      raise ENotSupportedError.CreateFmt('zip: unsupported WinZip AES version %d: %s', [LAesVersion, AE.Name]);
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
    ((LNameLen > 0) and (LNamePtr[LNameLen - 1] = Ord('/'))) or
    (((LExtAttrs shr 16) and $F000) = $4000);
  AE.ExternalAttrs := LExtAttrs;
  AE.IsSymlink :=
    ((LExtAttrs shr 16) and $F000) = C_ZIP_UNIX_MODE_SYMLINK;
end;

procedure ZipParseCentralEntries(const ACDBuf: TBytes; ACdOffset: UInt64; ACount: Int64;
  AMaxTotal: UInt64; out AEntries: TZipEntryInfoArray; out AFlags: TZipFlagArray);
var
  LI: Integer;
  LC: IByteCursor;
begin
  if ACount > High(Integer) - 1 then
    raise EParseError.Create('zip: entry count out of range');
  SetLength(AEntries, ACount);
  SetLength(AFlags, ACount);
  LC := NewByteCursor(ACDBuf);
  for LI := 0 to ACount - 1 do
  begin
    NeedRangeIn(LC, Int64(LC.Position), 46, 'central header');
    if LC.ReadU32LE <> C_ZIP_CENTRAL_SIG then
      raise EParseError.Create('zip: bad central header signature at ' +
        IntToStr(Int64(ACdOffset) + Int64(LC.Position) - 4));
    ParseCentralEntry(LC, AEntries[LI], AFlags[LI]);
  end;
  GuardTotalOutputSize(AEntries, AMaxTotal);
end;

procedure DosDateTimeFromUnix(AUnixSec: Int64; out ADosDate, ADosTime: Word);
var
  LMinSec, LMaxSec, LRem: Int64;
  LD: TDate;
begin
  LMinSec := Int64(TDate.Create(C_DOS_MIN_YEAR, 1, 1).ToUnixDays) * 86400;
  LMaxSec := Int64(TDate.Create(C_DOS_MAX_YEAR, 12, 31).ToUnixDays) * 86400 + 86399;
  if AUnixSec < LMinSec then AUnixSec := LMinSec
  else if AUnixSec > LMaxSec then AUnixSec := LMaxSec;
  LD := TDate.FromUnixDays(Integer(AUnixSec div 86400));
  LRem := AUnixSec mod 86400;
  ADosDate := Word(((LD.GetYear - C_DOS_MIN_YEAR) shl 9) or (LD.GetMonth shl 5) or LD.GetDay);
  ADosTime := Word(((LRem div 3600) shl 11) or (((LRem mod 3600) div 60) shl 5) or ((LRem mod 60) div 2));
end;

function DosMinUnixSec: Int64;
begin
  Result := Int64(TDate.Create(C_DOS_MIN_YEAR, 1, 1).ToUnixDays) * 86400;
end;

function UnixFromDosDateTime(ADosDate, ADosTime: Word): Int64;
var
  LYear, LMonth, LDay, LHour, LMin, LSec: Integer;
  LD: TDate;
begin
  LYear := C_DOS_MIN_YEAR + Integer(ADosDate shr 9);
  LMonth := Integer((ADosDate shr 5) and $0F);
  LDay := Integer(ADosDate and $1F);
  LHour := Integer(ADosTime shr 11);
  LMin := Integer((ADosTime shr 5) and $3F);
  LSec := Integer((ADosTime and $1F) shl 1);
  if not TDate.TryCreate(LYear, LMonth, LDay, LD) then
    LD := TDate.Create(C_DOS_MIN_YEAR, 1, 1);
  Result := Int64(LD.ToUnixDays) * 86400 + LHour * 3600 + LMin * 60 + LSec;
end;

procedure GuardEntryReadable(const AE: TZipEntryInfo; AFlags: Word);
begin
  if ((AFlags and C_ZIP_FLAG_ENCRYPTED) <> 0) and (AE.AesVersion = 0) then
    raise ENotSupportedError.Create(
      'zip: legacy ZipCrypto encryption not supported: ' + AE.Name);
  if not IsSafeZipEntryName(AE.Name) then
    raise EParseError.Create('zip: refusing unsafe entry name: ' + AE.Name);
end;

procedure GuardTotalOutputSize(const AEntries: array of TZipEntryInfo;
  AMaxTotal: UInt64);
var
  LI: Integer;
  LCum: UInt64;
begin
  if AMaxTotal = 0 then Exit;
  LCum := 0;
  for LI := 0 to High(AEntries) do
  begin
    if AEntries[LI].UncompressedSize > AMaxTotal then
      raise EIOError.Create('zip: total uncompressed size exceeds limit');
    if LCum > AMaxTotal - AEntries[LI].UncompressedSize then
      raise EIOError.Create('zip: total uncompressed size exceeds limit');
    Inc(LCum, AEntries[LI].UncompressedSize);
  end;
end;

function DecompressEntryVerified(const AE: TZipEntryInfo;
  const APayload: TBytes; const APassword: TBytes;
  AMaxOutput: SizeUInt): TBytes;
var
  LHint: UInt64;
  LCompressed: TBytes;
begin
  if AE.IsEncrypted and (AE.AesVersion > 0) then
    LCompressed := UnsealWinZipAesPayload(APassword, APayload,
      AE.AesStrengthCode, AE.Name)
  else
    LCompressed := APayload;
  if AE.MethodCode = C_ZIP_METHOD_DEFLATE then
  begin
    LHint := AE.UncompressedSize;
    if LHint > UInt64(Length(LCompressed)) * 16 + 65536 then
      LHint := UInt64(Length(LCompressed)) * 16 + 65536;
    Result := RawDeflateDecompressSized(LCompressed, SizeUInt(LHint),
      AMaxOutput);
  end
  else if AE.MethodCode = C_ZIP_METHOD_STORE then
  begin
    if (AMaxOutput > 0) and (AE.UncompressedSize > UInt64(AMaxOutput)) then
      raise EIOError.Create('zip: decompressed size exceeds limit for ' +
        AE.Name);
    Result := LCompressed;
  end
  else
    raise ENotSupportedError.Create('zip: unsupported compression method ' +
      IntToStr(AE.MethodCode) + ': ' + AE.Name);
  if UInt64(Length(Result)) <> AE.UncompressedSize then
    raise EIOError.Create('zip: decompressed size mismatch for ' + AE.Name);
  if AE.AesVersion = C_WINZIP_AES_VERSION_2 then
  begin
    if AE.Crc32 <> 0 then
      raise EParseError.Create(
        'zip: AE-2 entry with nonzero crc field: ' + AE.Name);
  end
  else if Crc32OfBytes(Result) <> AE.Crc32 then
    raise EIOError.Create('zip: crc mismatch for ' + AE.Name);
end;

function DecompressEntryToBuffer(const AE: TZipEntryInfo;
  const APayload: TBytes; const APassword: TBytes;
  const ADst: PByte; const ADstLen: SizeUInt; AMaxOutput: SizeUInt): SizeUInt;
var
  LHint: UInt64;
  LCompressed: TBytes;
  LOutLen: SizeUInt;
  LCrc: LongWord;
begin
  if ADst = nil then
  begin
    if AE.UncompressedSize <> 0 then
      raise EArgumentError.Create('zip: nil dest buffer for ' + AE.Name);
    Exit(0);
  end;
  if AE.IsEncrypted and (AE.AesVersion > 0) then
    LCompressed := UnsealWinZipAesPayload(APassword, APayload,
      AE.AesStrengthCode, AE.Name)
  else
    LCompressed := APayload;
  if AE.MethodCode = C_ZIP_METHOD_DEFLATE then
  begin
    LHint := AE.UncompressedSize;
    if LHint > UInt64(Length(LCompressed)) * 16 + 65536 then
      LHint := UInt64(Length(LCompressed)) * 16 + 65536;
    if ADstLen < AE.UncompressedSize then
      raise EIOError.Create('zip: dest buffer too small for ' + AE.Name);
    if (AMaxOutput > 0) and (AE.UncompressedSize > UInt64(AMaxOutput)) then
      raise EIOError.Create('zip: decompressed size exceeds limit for ' + AE.Name);
    LOutLen := RawDeflateDecompressToBuffer(LCompressed, ADst, ADstLen, AMaxOutput);
  end
  else if AE.MethodCode = C_ZIP_METHOD_STORE then
  begin
    if (AMaxOutput > 0) and (AE.UncompressedSize > UInt64(AMaxOutput)) then
      raise EIOError.Create('zip: decompressed size exceeds limit for ' + AE.Name);
    if ADstLen < AE.UncompressedSize then
      raise EIOError.Create('zip: dest buffer too small for ' + AE.Name);
    if UInt64(Length(LCompressed)) <> AE.UncompressedSize then
      raise EIOError.Create('zip: decompressed size mismatch for ' + AE.Name);
    if AE.UncompressedSize > 0 then
      Move(LCompressed[0], ADst^, SizeUInt(AE.UncompressedSize));
    LOutLen := SizeUInt(AE.UncompressedSize);
  end
  else
    raise ENotSupportedError.Create('zip: unsupported compression method ' +
      IntToStr(AE.MethodCode) + ': ' + AE.Name);
  if UInt64(LOutLen) <> AE.UncompressedSize then
    raise EIOError.Create('zip: decompressed size mismatch for ' + AE.Name);
  if AE.AesVersion = C_WINZIP_AES_VERSION_2 then
  begin
    if AE.Crc32 <> 0 then
      raise EParseError.Create('zip: AE-2 entry with nonzero crc field: ' + AE.Name);
  end
  else
  begin
    if LOutLen = 0 then
      LCrc := 0
    else
      LCrc := Crc32Of(ADst^, LOutLen);
    if LCrc <> AE.Crc32 then
      raise EIOError.Create('zip: crc mismatch for ' + AE.Name);
  end;
  Result := LOutLen;
end;

end.
