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
  nextpas.core.zip.base;

function LE16At(const AData: TBytes; AOff: SizeUInt): Word; inline;
function LE32At(const AData: TBytes; AOff: SizeUInt): LongWord; inline;
function LE64At(const AData: TBytes; AOff: SizeUInt): UInt64; inline;

function IsKnownZipSig(AValue: LongWord): Boolean; inline;

procedure GuardEntryReadable(const AE: TZipEntryInfo; AFlags: Word);

function DecompressEntryVerified(const AE: TZipEntryInfo;
  const APayload: TBytes; const APassword: TBytes;
  AMaxOutput: SizeUInt): TBytes;

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

procedure GuardEntryReadable(const AE: TZipEntryInfo; AFlags: Word);
begin
  if ((AFlags and C_ZIP_FLAG_ENCRYPTED) <> 0) and (AE.AesVersion = 0) then
    raise ENotSupportedError.Create(
      'zip: legacy ZipCrypto encryption not supported: ' + AE.Name);
  if not IsSafeZipEntryName(AE.Name) then
    raise EParseError.Create('zip: refusing unsafe entry name: ' + AE.Name);
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

end.
