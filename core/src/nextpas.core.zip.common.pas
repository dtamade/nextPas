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
procedure DosDateTimeFromUnix(AUnixSec: Int64; out ADosDate, ADosTime: Word); inline;
function DosMinUnixSec: Int64; inline;
function DosMaxUnixSec: Int64; inline;
function UnixFromDosDateTime(ADosDate, ADosTime: Word): Int64; inline;

procedure GuardCursorRange(const AC: IByteCursor; APos, ALen: Int64; const AWhat: string);
procedure GuardRange(ASize: Int64; APos, ALen: Int64; const AWhat: string);

procedure ParseLocalHeader(const AC: IByteCursor; out ANameLen, AExtraLen: Word);

procedure GuardEntryReadable(const AE: TZipEntryInfo; AFlags: Word);

procedure GuardTotalOutputSize(const AEntries: array of TZipEntryInfo;
  AMaxTotal: UInt64);

function DecompressEntryVerified(const AE: TZipEntryInfo;
  const APayload: TBytes; const APassword: TBytes;
  AMaxOutput: SizeUInt): TBytes;

function DecompressEntryToBuffer(const AE: TZipEntryInfo;
  const APayload: TBytes; const APassword: TBytes;
  const ADst: PByte; const ADstLen: SizeUInt; AMaxOutput: SizeUInt): SizeUInt;

implementation

uses
  nextpas.core.exception,
  nextpas.core.checksum.crc32,
  nextpas.core.compress.deflate,
  nextpas.core.zip.aes;

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

procedure DosDateTimeFromUnix(AUnixSec: Int64; out ADosDate, ADosTime: Word); inline;
begin
  nextpas.core.zip.base.DosDateTimeFromUnix(AUnixSec, ADosDate, ADosTime);
end;

function DosMinUnixSec: Int64; inline;
begin
  Result := nextpas.core.zip.base.DosMinUnixSec;
end;

function DosMaxUnixSec: Int64; inline;
begin
  Result := nextpas.core.zip.base.DosMaxUnixSec;
end;

function UnixFromDosDateTime(ADosDate, ADosTime: Word): Int64; inline;
begin
  Result := nextpas.core.zip.base.UnixFromDosDateTime(ADosDate, ADosTime);
end;

procedure GuardCursorRange(const AC: IByteCursor; APos, ALen: Int64; const AWhat: string);
begin
  if (APos < 0) or (ALen < 0) or (APos + ALen > Int64(AC.Length)) then
    raise EParseError.Create('zip: truncated ' + AWhat);
end;

procedure GuardRange(ASize: Int64; APos, ALen: Int64; const AWhat: string);
begin
  if (APos < 0) or (ALen < 0) or (APos + ALen > ASize) then
    raise EParseError.Create('zip: truncated ' + AWhat);
end;

procedure ParseLocalHeader(const AC: IByteCursor; out ANameLen, AExtraLen: Word);
begin
  if AC.ReadU32LE <> C_ZIP_LOCAL_SIG then
    raise EParseError.Create('zip: bad local header signature');
  AC.ReadU16LE;                    { version needed }
  AC.ReadU16LE;                    { flags }
  AC.ReadU16LE;                    { method }
  AC.ReadU16LE;                    { DOS time }
  AC.ReadU16LE;                    { DOS date }
  AC.ReadU32LE;                    { local crc }
  AC.ReadU32LE;                    { local compressed size }
  AC.ReadU32LE;                    { local uncompressed size }
  ANameLen := AC.ReadU16LE;
  AExtraLen := AC.ReadU16LE;
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
      raise EZipLimitError.Create('zip: total uncompressed size exceeds limit');
    if LCum > AMaxTotal - AEntries[LI].UncompressedSize then
      raise EZipLimitError.Create('zip: total uncompressed size exceeds limit');
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
      raise EZipLimitError.Create('zip: decompressed size exceeds limit for ' +
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
      raise EZipLimitError.Create('zip: decompressed size exceeds limit for ' + AE.Name);
    LOutLen := RawDeflateDecompressToBuffer(LCompressed, ADst, ADstLen, AMaxOutput);
  end
  else if AE.MethodCode = C_ZIP_METHOD_STORE then
  begin
    if (AMaxOutput > 0) and (AE.UncompressedSize > UInt64(AMaxOutput)) then
      raise EZipLimitError.Create('zip: decompressed size exceeds limit for ' + AE.Name);
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
