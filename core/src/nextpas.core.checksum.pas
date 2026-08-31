{**
 * nextpas.core.checksum - 校验和门面：CRC-32、FNV-1a 32、Adler-32。
 *}

unit nextpas.core.checksum;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.checksum.crc32,
  nextpas.core.checksum.fnv32,
  nextpas.core.checksum.adler32;

const
  FNV1A32_OFFSET = nextpas.core.checksum.fnv32.FNV1A32_OFFSET;
  FNV1A32_PRIME  = nextpas.core.checksum.fnv32.FNV1A32_PRIME;
  ADLER32_INIT   = nextpas.core.checksum.adler32.ADLER32_INIT;
  ADLER32_MOD    = nextpas.core.checksum.adler32.ADLER32_MOD;
  ADLER32_NMAX   = nextpas.core.checksum.adler32.ADLER32_NMAX;

function Crc32Update(ACrc: LongWord; const AData: Pointer; ALen: SizeUInt): LongWord; inline;
function Crc32Of(const ABuf; ALen: SizeUInt): LongWord; inline;
function Crc32OfBytes(const AData: TBytes): LongWord; inline;

function Fnv1a32Update(AHash: LongWord; const AData: Pointer;
  ALen: SizeUInt): LongWord; inline;
function Fnv1a32Of(const ABuf; ALen: SizeUInt): LongWord; inline;
function Fnv1a32OfBytes(const AData: TBytes): LongWord; inline;

function Adler32Update(AAdler: LongWord; const AData: Pointer; ALen: SizeUInt): LongWord; inline;
function Adler32Of(const ABuf; ALen: SizeUInt): LongWord; inline;
function Adler32OfBytes(const AData: TBytes): LongWord; inline;

implementation

function Crc32Update(ACrc: LongWord; const AData: Pointer; ALen: SizeUInt): LongWord;
begin
  Result := nextpas.core.checksum.crc32.Crc32Update(ACrc, AData, ALen);
end;

function Crc32Of(const ABuf; ALen: SizeUInt): LongWord;
begin
  Result := nextpas.core.checksum.crc32.Crc32Of(ABuf, ALen);
end;

function Crc32OfBytes(const AData: TBytes): LongWord;
begin
  Result := nextpas.core.checksum.crc32.Crc32OfBytes(AData);
end;

function Fnv1a32Update(AHash: LongWord; const AData: Pointer;
  ALen: SizeUInt): LongWord;
begin
  Result := nextpas.core.checksum.fnv32.Fnv1a32Update(AHash, AData, ALen);
end;

function Fnv1a32Of(const ABuf; ALen: SizeUInt): LongWord;
begin
  Result := nextpas.core.checksum.fnv32.Fnv1a32Of(ABuf, ALen);
end;

function Fnv1a32OfBytes(const AData: TBytes): LongWord;
begin
  Result := nextpas.core.checksum.fnv32.Fnv1a32OfBytes(AData);
end;

function Adler32Update(AAdler: LongWord; const AData: Pointer; ALen: SizeUInt): LongWord;
begin
  Result := nextpas.core.checksum.adler32.Adler32Update(AAdler, AData, ALen);
end;

function Adler32Of(const ABuf; ALen: SizeUInt): LongWord;
begin
  Result := nextpas.core.checksum.adler32.Adler32Of(ABuf, ALen);
end;

function Adler32OfBytes(const AData: TBytes): LongWord;
begin
  Result := nextpas.core.checksum.adler32.Adler32OfBytes(AData);
end;

end.