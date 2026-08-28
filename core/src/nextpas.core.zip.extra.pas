unit nextpas.core.zip.extra;
{**
 * @desc ZIP extra field 共享编解码内核：Zip64 ($0001) 与 WinZip AES ($9901)
 *       的链式解析/编码与校验集中于此，消除 reader / sequential / writer
 *       的重复循环与 magic-number 分散，保证 extra 链畸形、AES 厂商非法、
 *       编码顺序（Zip64→AES）与字段宽度等错误语义与字节形态单点一致。
 *       仅依赖 nextpas.*，无 FPC RTL 直引。
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

function BuildLocalExtra(const AUSize, ACSize: UInt64; ADescriptorOpen,
  ANeedsZip64: Boolean; AAesStrength: Byte; AAesMethod: Word): TBytes;
function BuildCentralExtra(const AUSize, ACSize, ALocalOffset: UInt64;
  ANeedsZ64Sizes, ANeedsZ64Offset: Boolean; AAesStrength: Byte;
  AAesMethod: Word): TBytes;

function EncodeLocalExtra(const AUSize, ACSize: UInt64; ADescriptorOpen,
  ANeedsZip64: Boolean; AAesStrength: Byte; AAesMethod: Word;
  AOut: PByte): SizeUInt;
function EncodeCentralExtra(const AUSize, ACSize, ALocalOffset: UInt64;
  ANeedsZ64Sizes, ANeedsZ64Offset: Boolean; AAesStrength: Byte;
  AAesMethod: Word; AOut: PByte): SizeUInt;

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

procedure WriteLE16(var ADst: TBytes; AOff: SizeUInt; AValue: Word); inline;
begin
  ADst[AOff] := Byte(AValue and $FF);
  ADst[AOff + 1] := Byte((AValue shr 8) and $FF);
end;

procedure WriteLE32(var ADst: TBytes; AOff: SizeUInt; AValue: LongWord); inline;
begin
  ADst[AOff] := Byte(AValue and $FF);
  ADst[AOff + 1] := Byte((AValue shr 8) and $FF);
  ADst[AOff + 2] := Byte((AValue shr 16) and $FF);
  ADst[AOff + 3] := Byte((AValue shr 24) and $FF);
end;

procedure WriteLE64(var ADst: TBytes; AOff: SizeUInt; AValue: UInt64); inline;
begin
  WriteLE32(ADst, AOff, LongWord(AValue and $FFFFFFFF));
  WriteLE32(ADst, AOff + 4, LongWord((AValue shr 32) and $FFFFFFFF));
end;

procedure WriteLE16Buf(AOut: PByte; AOff: SizeUInt; AValue: Word); inline;
begin
  AOut[AOff] := Byte(AValue and $FF);
  AOut[AOff + 1] := Byte((AValue shr 8) and $FF);
end;

procedure WriteLE32Buf(AOut: PByte; AOff: SizeUInt; AValue: LongWord); inline;
begin
  AOut[AOff] := Byte(AValue and $FF);
  AOut[AOff + 1] := Byte((AValue shr 8) and $FF);
  AOut[AOff + 2] := Byte((AValue shr 16) and $FF);
  AOut[AOff + 3] := Byte((AValue shr 24) and $FF);
end;

procedure WriteLE64Buf(AOut: PByte; AOff: SizeUInt; AValue: UInt64); inline;
begin
  WriteLE32Buf(AOut, AOff, LongWord(AValue and $FFFFFFFF));
  WriteLE32Buf(AOut, AOff + 4, LongWord((AValue shr 32) and $FFFFFFFF));
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

function BuildLocalExtra(const AUSize, ACSize: UInt64; ADescriptorOpen,
  ANeedsZip64: Boolean; AAesStrength: Byte; AAesMethod: Word): TBytes;
var
  LBuf: array[0..63] of Byte;
  LLen: SizeUInt;
begin
  LLen := EncodeLocalExtra(AUSize, ACSize, ADescriptorOpen, ANeedsZip64,
    AAesStrength, AAesMethod, @LBuf[0]);
  if LLen = 0 then
    Exit(nil);
  SetLength(Result, LLen);
  Move(LBuf[0], Result[0], LLen);
end;

function BuildCentralExtra(const AUSize, ACSize, ALocalOffset: UInt64;
  ANeedsZ64Sizes, ANeedsZ64Offset: Boolean; AAesStrength: Byte;
  AAesMethod: Word): TBytes;
var
  LBuf: array[0..63] of Byte;
  LLen: SizeUInt;
begin
  LLen := EncodeCentralExtra(AUSize, ACSize, ALocalOffset, ANeedsZ64Sizes,
    ANeedsZ64Offset, AAesStrength, AAesMethod, @LBuf[0]);
  if LLen = 0 then
    Exit(nil);
  SetLength(Result, LLen);
  Move(LBuf[0], Result[0], LLen);
end;

function EncodeLocalExtra(const AUSize, ACSize: UInt64; ADescriptorOpen,
  ANeedsZip64: Boolean; AAesStrength: Byte; AAesMethod: Word;
  AOut: PByte): SizeUInt;
var
  LNeedsZ64: Boolean;
  LPos: SizeUInt;
begin
  Result := 0;
  LNeedsZ64 := ADescriptorOpen or ANeedsZip64;
  if LNeedsZ64 then
  begin
    WriteLE16Buf(AOut, 0, C_ZIP64_EXTRA_ID);
    WriteLE16Buf(AOut, 2, 16);
    if ADescriptorOpen then
    begin
      WriteLE64Buf(AOut, 4, 0);
      WriteLE64Buf(AOut, 12, 0);
    end
    else
    begin
      WriteLE64Buf(AOut, 4, AUSize);
      WriteLE64Buf(AOut, 12, ACSize);
    end;
    Result := 20;
  end;
  if AAesStrength <> 0 then
  begin
    LPos := Result;
    WriteLE16Buf(AOut, LPos, C_WINZIP_AES_EXTRA_ID);
    WriteLE16Buf(AOut, LPos + 2, C_WINZIP_AES_EXTRA_BODY);
    WriteLE16Buf(AOut, LPos + 4, C_WINZIP_AES_VERSION_2);
    WriteLE16Buf(AOut, LPos + 6, C_WINZIP_AES_VENDOR_LE);
    AOut[LPos + 8] := AAesStrength;
    WriteLE16Buf(AOut, LPos + 9, AAesMethod);
    Inc(Result, 4 + C_WINZIP_AES_EXTRA_BODY);
  end;
end;

function EncodeCentralExtra(const AUSize, ACSize, ALocalOffset: UInt64;
  ANeedsZ64Sizes, ANeedsZ64Offset: Boolean; AAesStrength: Byte;
  AAesMethod: Word; AOut: PByte): SizeUInt;
var
  LBodyLen: SizeUInt;
  LPos: SizeUInt;
begin
  Result := 0;
  LBodyLen := 0;
  if ANeedsZ64Sizes then Inc(LBodyLen, 16);
  if ANeedsZ64Offset then Inc(LBodyLen, 8);
  if LBodyLen > 0 then
  begin
    WriteLE16Buf(AOut, 0, C_ZIP64_EXTRA_ID);
    WriteLE16Buf(AOut, 2, Word(LBodyLen));
    LPos := 4;
    if ANeedsZ64Sizes then
    begin
      WriteLE64Buf(AOut, LPos, AUSize);
      WriteLE64Buf(AOut, LPos + 8, ACSize);
      Inc(LPos, 16);
    end;
    if ANeedsZ64Offset then
    begin
      WriteLE64Buf(AOut, LPos, ALocalOffset);
      Inc(LPos, 8);
    end;
    Result := 4 + LBodyLen;
  end;
  if AAesStrength <> 0 then
  begin
    LPos := Result;
    WriteLE16Buf(AOut, LPos, C_WINZIP_AES_EXTRA_ID);
    WriteLE16Buf(AOut, LPos + 2, C_WINZIP_AES_EXTRA_BODY);
    WriteLE16Buf(AOut, LPos + 4, C_WINZIP_AES_VERSION_2);
    WriteLE16Buf(AOut, LPos + 6, C_WINZIP_AES_VENDOR_LE);
    AOut[LPos + 8] := AAesStrength;
    WriteLE16Buf(AOut, LPos + 9, AAesMethod);
    Inc(Result, 4 + C_WINZIP_AES_EXTRA_BODY);
  end;
end;

end.
