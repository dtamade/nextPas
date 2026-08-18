{**
 * nextpas.core.checksum - 校验和门面：CRC-32。
 *}

unit nextpas.core.checksum;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.checksum.crc32;

function Crc32Update(ACrc: LongWord; const AData: Pointer; ALen: SizeUInt): LongWord; inline;
function Crc32Of(const ABuf; ALen: SizeUInt): LongWord; inline;
function Crc32OfBytes(const AData: TBytes): LongWord; inline;

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

end.