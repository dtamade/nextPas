unit nextpas.core.zip.extra;
{**
 * @desc ZIP extra field 共享解析内核：Zip64 ($0001) 与 WinZip AES ($9901)
 *       的链式解析与校验集中于此，消除 reader / sequential / writer 的
 *       重复循环与 magic-number 分散，保证 extra 链畸形、AES 厂商非法等
 *       错误语义单点一致。仅依赖 nextpas.*，无 FPC RTL 直引。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

procedure DecodeCentralExtra(const AExtra: TBytes; var AUSize, ACSize,
  ALocalOffset: UInt64; var AHasAes: Boolean; var AAesVersion,
  AAesVendor, AAesRealMethod: Word; var AAesStrength: Byte);

procedure DecodeLocalExtra(const AExtra: TBytes; var AUSize, ACSize: UInt64;
  var AHasAes: Boolean; var AAesVersion, AAesVendor, AAesRealMethod: Word;
  var AAesStrength: Byte);

implementation

uses
  nextpas.core.exception,
  nextpas.core.zip.base,
  nextpas.core.zip.aes;

function LE16At(const AData: TBytes; AOff: SizeUInt): Word; inline;
begin
  Result := Word(AData[AOff]) or (Word(AData[AOff + 1]) shl 8);
end;

function LE64At(const AData: TBytes; AOff: SizeUInt): UInt64; inline;
var
  LLo, LHi: LongWord;
begin
  LLo := LongWord(AData[AOff]) or (LongWord(AData[AOff + 1]) shl 8) or
    (LongWord(AData[AOff + 2]) shl 16) or (LongWord(AData[AOff + 3]) shl 24);
  LHi := LongWord(AData[AOff + 4]) or (LongWord(AData[AOff + 5]) shl 8) or
    (LongWord(AData[AOff + 6]) shl 16) or (LongWord(AData[AOff + 7]) shl 24);
  Result := UInt64(LLo) or (UInt64(LHi) shl 32);
end;

procedure DecodeCentralExtra(const AExtra: TBytes; var AUSize, ACSize,
  ALocalOffset: UInt64; var AHasAes: Boolean; var AAesVersion,
  AAesVendor, AAesRealMethod: Word; var AAesStrength: Byte);
var
  LPos: SizeUInt;
  LId, LSize: Word;
  LUsed: Integer;
begin
  AHasAes := False;
  AAesVersion := 0;
  AAesVendor := 0;
  AAesRealMethod := 0;
  AAesStrength := 0;
  LPos := 0;
  while LPos + 4 <= SizeUInt(Length(AExtra)) do
  begin
    LId := LE16At(AExtra, LPos);
    LSize := LE16At(AExtra, LPos + 2);
    if LPos + 4 + LSize > SizeUInt(Length(AExtra)) then
      raise EParseError.Create('zip: malformed extra field');
    if LId = C_ZIP64_EXTRA_ID then
    begin
      LUsed := 0;
      if (AUSize = UInt64($FFFFFFFF)) and (LSize - LUsed >= 8) then
      begin
        AUSize := LE64At(AExtra, LPos + 4 + SizeUInt(LUsed));
        Inc(LUsed, 8);
      end;
      if (ACSize = UInt64($FFFFFFFF)) and (LSize - LUsed >= 8) then
      begin
        ACSize := LE64At(AExtra, LPos + 4 + SizeUInt(LUsed));
        Inc(LUsed, 8);
      end;
      if (ALocalOffset = UInt64($FFFFFFFF)) and (LSize - LUsed >= 8) then
      begin
        ALocalOffset := LE64At(AExtra, LPos + 4 + SizeUInt(LUsed));
        Inc(LUsed, 8);
      end;
    end
    else if LId = C_WINZIP_AES_EXTRA_ID then
    begin
      if AHasAes or (LSize <> C_WINZIP_AES_EXTRA_BODY) then
        raise EParseError.Create('zip: malformed WinZip AES extra field');
      AAesVersion := LE16At(AExtra, LPos + 4);
      AAesVendor := LE16At(AExtra, LPos + 6);
      AAesStrength := AExtra[LPos + 8];
      AAesRealMethod := LE16At(AExtra, LPos + 9);
      if AAesVendor <> C_WINZIP_AES_VENDOR_LE then
        raise EParseError.Create('zip: unknown WinZip AES vendor id');
      AHasAes := True;
    end;
    Inc(LPos, 4 + LSize);
  end;
end;

procedure DecodeLocalExtra(const AExtra: TBytes; var AUSize, ACSize: UInt64;
  var AHasAes: Boolean; var AAesVersion, AAesVendor, AAesRealMethod: Word;
  var AAesStrength: Byte);
var
  LPos: SizeUInt;
  LId, LSize: Word;
begin
  AHasAes := False;
  AAesVersion := 0;
  AAesVendor := 0;
  AAesRealMethod := 0;
  AAesStrength := 0;
  LPos := 0;
  while LPos + 4 <= SizeUInt(Length(AExtra)) do
  begin
    LId := LE16At(AExtra, LPos);
    LSize := LE16At(AExtra, LPos + 2);
    if LPos + 4 + LSize > SizeUInt(Length(AExtra)) then
      raise EParseError.Create('zip: malformed extra field');
    if LId = C_ZIP64_EXTRA_ID then
    begin
      if LSize >= 16 then
      begin
        if AUSize = UInt64($FFFFFFFF) then
          AUSize := LE64At(AExtra, LPos + 4);
        if ACSize = UInt64($FFFFFFFF) then
          ACSize := LE64At(AExtra, LPos + 12);
      end
      else if LSize >= 8 then
      begin
        if AUSize = UInt64($FFFFFFFF) then
          AUSize := LE64At(AExtra, LPos + 4);
      end;
    end
    else if LId = C_WINZIP_AES_EXTRA_ID then
    begin
      if AHasAes or (LSize <> C_WINZIP_AES_EXTRA_BODY) then
        raise EParseError.Create('zip: malformed WinZip AES extra field');
      AAesVersion := LE16At(AExtra, LPos + 4);
      AAesVendor := LE16At(AExtra, LPos + 6);
      AAesStrength := AExtra[LPos + 8];
      AAesRealMethod := LE16At(AExtra, LPos + 9);
      if AAesVendor <> C_WINZIP_AES_VENDOR_LE then
        raise EParseError.Create('zip: unknown WinZip AES vendor id');
      AHasAes := True;
    end;
    Inc(LPos, 4 + LSize);
  end;
end;

end.
