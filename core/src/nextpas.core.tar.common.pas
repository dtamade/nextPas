unit nextpas.core.tar.common;
{**
 * @desc Tar 共享内核：reader/writer 单点复用（类型级隔离·门面零 re-export，仅 reader/writer/fs 受信 uses，CONTRACT 双重收敛）。
 *}

{$I nextpas.core.settings.inc}
{ 内核隔离：仅 reader/writer/fs 受信 uses }

interface

uses
  nextpas.core.base,
  nextpas.core.tar.base,
  nextpas.core.bytes.base,
  nextpas.core.bytes.builder,
  nextpas.core.archive.pax;

function TarPadToBlock(ASize: Int64): Int64; inline;

procedure GuardTarEntrySize(const AHeader: TTarHeader; AMaxEntry: SizeUInt);
procedure GuardTarTotalSize(ACum, ANext: UInt64; AMaxTotal: UInt64);
procedure GuardTarNameForRead(const AName: string);

{ 512 块校验和：主入口为 TarComputeChecksumsDual；Unsigned/Signed 为兼容薄封装，推荐 dual }
procedure TarComputeChecksumsDual(ABlock: PByte; out AU, ASig: Int64);
function TarComputeChecksumUnsigned(ABlock: PByte): Int64; deprecated 'use TarComputeChecksumsDual';
function TarComputeChecksumSigned(ABlock: PByte): Int64; deprecated 'use TarComputeChecksumsDual';
function TarStoredChecksum(ABlock: PByte): Int64; inline;
procedure TarVerifyBlockChecksum(ABlock: PByte; APos: SizeUInt); inline;
function TarHeaderIsZeroBlock(ABlock: PByte): Boolean;
function TarHeaderIsZeroOrValid(ABlock: PByte; APos: SizeUInt): Boolean;

function TarParseNumericField(ABase: PByte; ALen: SizeUInt; APos: SizeUInt): Int64;
procedure TarFormatNumericField(ABlock: PByte; AOff, ALen: SizeUInt; AValue: Int64);

procedure TarPutHeaderField(ABlock: PByte; AOff, ALen: SizeUInt; const ASpan: TByteSpan);
procedure TarPutHeaderString(ABlock: PByte; AOff, ALen: SizeUInt; const AValue: string);
procedure TarPutHeaderSlice(ABlock: PByte; AOff, ALen: SizeUInt; AData: PByte; ACount: SizeUInt);
procedure TarFinalizeHeaderChecksum(ABlock: PByte);
procedure TarWriteUStarMagic(ABlock: PByte); inline;
function TarParsePaxRecords(ABase: PByte; ALen: SizeUInt; out APath, ALinkPath: string): Boolean;
function TarParsePaxKVRecords(ABase: PByte; ALen: SizeUInt; const AHandler: TArchivePaxKVHandler): Boolean; inline; overload;
function TarParsePaxKVRecords(ABase: PByte; ALen: SizeUInt; AHandler: TArchivePaxKVHandlerRaw; AUserData: Pointer): Boolean; inline; overload;
procedure TarAppendPaxRecord(const ABuilder: IBytesBuilder; const AKey, AValue: string); inline;

implementation

uses
  nextpas.core.exception,
  nextpas.core.bytes.ops;

type
  PTarPaxCtx = ^TTarPaxCtx;
  TTarPaxCtx = record Path: PString; LinkPath: PString; Found: PBoolean; end;

function TarPadToBlock(ASize: Int64): Int64; inline;
begin
  // 块对齐委托 bytes.ops.AlignUp
  if ASize <= 0 then
    Exit(0);
  Result := Int64(AlignUp(SizeUInt(ASize), SizeUInt(C_TAR_BLOCK_SIZE))) - ASize;
end;

procedure GuardTarEntrySize(const AHeader: TTarHeader; AMaxEntry: SizeUInt);
begin
  if (AMaxEntry = 0) then
    Exit;
  if AHeader.Size > Int64(AMaxEntry) then
    raise EIOError.CreateFmt('tar: entry size exceeds limit for "%s" (%d > %d)',
      [AHeader.Name, AHeader.Size, Int64(AMaxEntry)]);
end;

procedure GuardTarTotalSize(ACum, ANext: UInt64; AMaxTotal: UInt64);
begin
  if AMaxTotal = 0 then
    Exit;
  if ANext > AMaxTotal then
    raise EIOError.CreateFmt('tar: total uncompressed size exceeds limit (%d > %d, cum=%d)', [ANext, AMaxTotal, ACum]);
  if ACum > AMaxTotal - ANext then
    raise EIOError.CreateFmt('tar: total uncompressed size exceeds limit (%d + %d > %d)', [ACum, ANext, AMaxTotal]);
end;

procedure GuardTarNameForRead(const AName: string);
begin
  if not IsSafeTarEntryName(AName) then
    raise EParseError.Create('tar: refusing unsafe entry name: ' + AName);
end;

procedure TarComputeChecksumsDual(ABlock: PByte; out AU, ASig: Int64);
var
  LSum: UInt64;
  LHigh: SizeUInt;
begin
  // 外联：BytesSumAndCountHighBitExclude 经 simd.SumBytes 批量 512B，nil 守卫，避 inline 膨胀
  if ABlock = nil then
  begin
    AU := Int64(UInt64(C_TAR_LAYOUT.Chksum.Len) * Ord(' '));
    ASig := AU;
    Exit;
  end;
  BytesSumAndCountHighBitExclude(ABlock, C_TAR_BLOCK_SIZE, C_TAR_LAYOUT.Chksum.Off, C_TAR_LAYOUT.Chksum.Len, LSum, LHigh);
  AU := Int64(LSum + UInt64(C_TAR_LAYOUT.Chksum.Len) * Ord(' '));
  ASig := AU - Int64(LHigh) * 256;
end;

{ — 校验和：单遍 512 — }
function TarComputeChecksumUnsigned(ABlock: PByte): Int64;
var
  U, S: Int64;
begin
  TarComputeChecksumsDual(ABlock, U, S);
  Result := U;
end;

function TarComputeChecksumSigned(ABlock: PByte): Int64;
var
  U, S: Int64;
begin
  TarComputeChecksumsDual(ABlock, U, S);
  Result := S;
end;

function TarStoredChecksum(ABlock: PByte): Int64; inline;
begin
  Result := TarParseNumericField(@ABlock[C_TAR_LAYOUT.Chksum.Off], C_TAR_LAYOUT.Chksum.Len, C_TAR_LAYOUT.Chksum.Off);
end;

procedure TarVerifyBlockChecksum(ABlock: PByte; APos: SizeUInt); inline;
var
  Stored, U, S: Int64;
begin
  // 薄守卫 inline，零拷贝 PByte 切片
  Stored := TarStoredChecksum(ABlock);
  TarComputeChecksumsDual(ABlock, U, S);
  if (Stored <> U) and (Stored <> S) then
    raise EIOError.CreateFmt('tar: header checksum mismatch at offset %d (stored %d, computed unsigned %d signed %d)', [APos, Stored, U, S]);
end;

function TarHeaderIsZeroBlock(ABlock: PByte): Boolean;
begin
  // 快路径 qword 拒识 + IsZeroBytes
  if ABlock = nil then Exit(True);
  if PQWord(ABlock)^ <> 0 then Exit(False);
  Result := IsZeroBytes(TByteSpan.Create(ABlock, C_TAR_BLOCK_SIZE));
end;

function TarHeaderIsZeroOrValid(ABlock: PByte; APos: SizeUInt): Boolean;
var
  Stored, U, S: Int64;
begin
  Stored := TarStoredChecksum(ABlock);
  if TarHeaderIsZeroBlock(ABlock) then
    Exit(True);
  TarComputeChecksumsDual(ABlock, U, S);
  if (Stored <> U) and (Stored <> S) then
    raise EIOError.CreateFmt('tar: header checksum mismatch at offset %d (stored %d, computed unsigned %d signed %d)', [APos, Stored, U, S]);
  Result := False;
end;

{ — 数值字段：octal/base-256 编解码 — }
function TarParseNumericField(ABase: PByte; ALen: SizeUInt; APos: SizeUInt): Int64;
var
  I: SizeUInt;
  B: Byte;
begin
  if (ABase[0] and C_TAR_BASE256_SENTINEL) <> 0 then
  begin
    // 修复 base-256 两补：首字节按 ShortInt 符号扩展，bit6=1 为负 (含 $FF=-1, $FE=-2 等大负值) 否则掩 $7F 正向；消除原仅 $FF 特判导致的边界负尺寸误判/溢出
    if (ABase[0] and $40) <> 0 then
      Result := Int64(ShortInt(ABase[0]))
    else
      Result := Int64(ABase[0] and $7F);
    for I := 1 to ALen - 1 do
    begin
      if (Result > High(Int64) div 256) or (Result < Low(Int64) div 256) then
        raise EIOError.CreateFmt('tar: base-256 overflow at offset %d', [APos]);
      Result := (Result shl 8) or Int64(ABase[I]);
    end;
    Exit;
  end;
  Result := 0;
  for I := 0 to ALen - 1 do
  begin
    B := ABase[I];
    if B = 0 then
      Break;
    if B = Ord(' ') then
      Continue;
    if (B < Ord('0')) or (B > Ord('7')) then
      raise EIOError.CreateFmt('tar: corrupt octal field at offset %d (byte %d)', [APos + I, B]);
    Result := (Result shl 3) or Int64(B - Ord('0'));
  end;
end;

procedure TarFormatNumericField(ABlock: PByte; AOff, ALen: SizeUInt; AValue: Int64);
var
  I: SizeInt;
  MaxBase256: Int64;
begin
  if AValue < 0 then
    raise EIOError.CreateFmt('tar: negative numeric field %d at offset %d', [AValue, AOff]);
  if AValue >= (Int64(1) shl ((ALen - 1) * 3)) then
  begin
    if ALen <= 1 then
      raise EIOError.Create('tar: numeric field too small for base-256');
    if ((ALen - 1) * 8 + 7) >= 63 then
      MaxBase256 := High(Int64)
    else
      MaxBase256 := (Int64(1) shl ((ALen - 1) * 8 + 7)) - 1;
    if AValue > MaxBase256 then
      raise EIOError.CreateFmt('tar: numeric field %d exceeds base-256 capacity %d at offset %d', [AValue, MaxBase256, AOff]);
    ABlock[AOff] := C_TAR_BASE256_SENTINEL;
    for I := ALen - 1 downto 1 do
    begin
      ABlock[AOff + I] := Byte(AValue and $FF);
      AValue := AValue shr 8;
    end;
    Exit;
  end;
  ABlock[AOff + ALen - 1] := 0;
  for I := ALen - 2 downto 0 do
  begin
    ABlock[AOff + I] := Byte(Ord('0') + (AValue and 7));
    AValue := AValue shr 3;
  end;
end;

procedure TarPutHeaderField(ABlock: PByte; AOff, ALen: SizeUInt; const ASpan: TByteSpan);
var
  CopyLen: SizeUInt;
begin
  // 收敛 string/slice 双路径，单次 CopyMemory
  if (ABlock = nil) or (ALen = 0) or (ASpan.Len = 0) or (ASpan.Data = nil) then
    Exit;
  CopyLen := ASpan.Len;
  if CopyLen > ALen then
    CopyLen := ALen;
  CopyMemory(ASpan.Data, @ABlock[AOff], CopyLen);
end;

procedure TarPutHeaderString(ABlock: PByte; AOff, ALen: SizeUInt; const AValue: string);
begin
  // 薄转发至 TByteSpan 视图
  if (ABlock = nil) or (ALen = 0) or (Length(AValue) = 0) then
    Exit;
  TarPutHeaderField(ABlock, AOff, ALen, TByteSpan.Create(PByte(PAnsiChar(AValue)), SizeUInt(Length(AValue))));
end;

procedure TarPutHeaderSlice(ABlock: PByte; AOff, ALen: SizeUInt; AData: PByte; ACount: SizeUInt);
begin
  TarPutHeaderField(ABlock, AOff, ALen, TByteSpan.Create(AData, ACount));
end;

procedure TarFinalizeHeaderChecksum(ABlock: PByte);
var
  U, S: Int64;
  I: SizeUInt;
begin
  TarComputeChecksumsDual(ABlock, U, S);
  for I := 0 to 5 do
    ABlock[C_TAR_LAYOUT.Chksum.Off + I] := Byte(Ord('0') + ((U shr ((5 - I) * 3)) and 7));
  ABlock[C_TAR_LAYOUT.Chksum.Off + 6] := 0;
  ABlock[C_TAR_LAYOUT.Chksum.Off + 7] := Ord(' ');
end;

procedure TarWriteUStarMagic(ABlock: PByte); inline;
begin
  TarPutHeaderString(ABlock, C_TAR_LAYOUT.Magic.Off, C_TAR_LAYOUT.Magic.Len, C_TAR_MAGIC_USTAR);
  TarPutHeaderString(ABlock, C_TAR_LAYOUT.Version.Off, C_TAR_LAYOUT.Version.Len, C_TAR_VERSION_00);
end;

procedure TarAppendPaxRecord(const ABuilder: IBytesBuilder; const AKey, AValue: string); inline;
begin
  ArchivePaxAppendRecord(ABuilder, AKey, AValue);
end;

procedure TarPaxPathHandler(const AKey, AValue: TByteSpan; AUserData: Pointer);
var
  Ctx: PTarPaxCtx;
begin
  // plain procedural + UserData，无闭包
  Ctx := PTarPaxCtx(AUserData);
  if (AKey.Len = 4) and SpanEqual(AKey, TByteSpan.Create(PByte(PAnsiChar('path')), 4)) then
  begin
    if AValue.Len > 0 then Ctx^.Path^ := SpanToString(AValue) else Ctx^.Path^ := '';
    Ctx^.Found^ := True;
  end
  else if (AKey.Len = 8) and SpanEqual(AKey, TByteSpan.Create(PByte(PAnsiChar('linkpath')), 8)) then
  begin
    if AValue.Len > 0 then Ctx^.LinkPath^ := SpanToString(AValue) else Ctx^.LinkPath^ := '';
    Ctx^.Found^ := True;
  end;
end;

function TarParsePaxKVRecords(ABase: PByte; ALen: SizeUInt; const AHandler: TArchivePaxKVHandler): Boolean; inline;
begin
  Result := ArchivePaxParseRecords(ABase, ALen, AHandler);
end;

function TarParsePaxKVRecords(ABase: PByte; ALen: SizeUInt; AHandler: TArchivePaxKVHandlerRaw; AUserData: Pointer): Boolean; inline;
begin
  Result := ArchivePaxParseRecords(ABase, ALen, AHandler, AUserData);
end;

function TarParsePaxRecords(ABase: PByte; ALen: SizeUInt; out APath, ALinkPath: string): Boolean;
var
  LFound: Boolean;
  LPathTmp, LLinkTmp: string;
  LCtx: TTarPaxCtx;
begin
  APath := '';
  ALinkPath := '';
  LFound := False;
  LPathTmp := '';
  LLinkTmp := '';
  if (ABase = nil) or (ALen = 0) then
    Exit(False);
  LCtx.Path := @LPathTmp;
  LCtx.LinkPath := @LLinkTmp;
  LCtx.Found := @LFound;
  ArchivePaxParseRecords(ABase, ALen, @TarPaxPathHandler, @LCtx);
  APath := LPathTmp;
  ALinkPath := LLinkTmp;
  Result := LFound;
end;

end.
