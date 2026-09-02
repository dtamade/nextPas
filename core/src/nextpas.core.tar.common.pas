unit nextpas.core.tar.common;
{**
 * @desc Tar 共享内核：reader/writer 单点复用（@internal）。
 * 校验和 / 数值 / 文本与 pax / 守卫单点，消除两端重复，保证 fail-closed 一致。
 * 内部单元：仅供 nextpas.core.tar.* 实现内复用，禁止门面外直引；不属于公共 API。
 * 性能：薄守卫 inline + 零拷贝 PByte 切片；循环体外联守 design-conventions 真实循环体禁 inline。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.tar.base;

function TarPadToBlock(ASize: Int64): Int64; inline;

{** 校验：单条目尺寸与总量 *}
procedure GuardTarEntrySize(const AHeader: TTarHeader; AMaxEntry: SizeUInt);
procedure GuardTarTotalSize(ACum, ANext: UInt64; AMaxTotal: UInt64);

{** 名安全守卫（写端 EArgumentError，读端/落盘 EParseError 由调用方选） *}
procedure GuardTarNameForRead(const AName: string);

{** 校验和单点：512 块校验和计算与验证（unsigned/signed 双算，零拷贝 PByte 切片；循环体外联） *}
function TarComputeChecksumUnsigned(ABlock: PByte): Int64;
function TarComputeChecksumSigned(ABlock: PByte): Int64;
function TarStoredChecksum(ABlock: PByte): Int64; inline;
procedure TarVerifyBlockChecksum(ABlock: PByte; APos: SizeUInt); inline;
function TarHeaderIsZeroBlock(ABlock: PByte): Boolean;
function TarHeaderIsZeroOrValid(ABlock: PByte; APos: SizeUInt): Boolean;

{** 数值字段单点：八进制/base-256 双路径编解码（零拷贝 PByte 切片；循环体外联） *}
function TarParseNumericField(ABase: PByte; ALen: SizeUInt; APos: SizeUInt): Int64;
procedure TarFormatNumericField(ABlock: PByte; AOff, ALen: SizeUInt; AValue: Int64);

{** 头字段单点：文本/校验和构造收敛至 common，机械委托 bytes.ops.CopyStringToBuffer/CopyMemory 单源 Move，零拷贝 PByte 切片（Move 索引禁 inline，外联可静态校验） *}
procedure TarPutHeaderString(ABlock: PByte; AOff, ALen: SizeUInt; const AValue: string);
procedure TarPutHeaderSlice(ABlock: PByte; AOff, ALen: SizeUInt; AData: PByte; ACount: SizeUInt);
procedure TarFinalizeHeaderChecksum(ABlock: PByte);
{** ustar 魔数/版本单点：收敛 EmitPaxHeader/WriteHeader 逐字节拼装，复用 C_TAR_MAGIC_USTAR/C_TAR_VERSION_00 常量与 TarPutHeaderString 单源 Move，inline 薄转发零拷贝 *}
procedure TarWriteUStarMagic(ABlock: PByte); inline;
function TarParsePaxRecords(ABase: PByte; ALen: SizeUInt; out APath, ALinkPath: string): Boolean;

implementation

uses
  nextpas.core.exception,
  nextpas.core.bytes.ops,
  nextpas.core.simd;

function TarPadToBlock(ASize: Int64): Int64; inline;
begin
  Result := (C_TAR_BLOCK_SIZE - (ASize mod C_TAR_BLOCK_SIZE)) mod C_TAR_BLOCK_SIZE;
end;

procedure GuardTarEntrySize(const AHeader: TTarHeader; AMaxEntry: SizeUInt);
begin
  if (AMaxEntry = 0) then
    Exit;
  if (AHeader.Kind = tekRegular) and (AHeader.Size > Int64(AMaxEntry)) then
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

{ — 校验和单源：单次扫描双累加，分段无分支，chksum 字段视为空格，循环体外联 — }
procedure TarComputeChecksumsDual(ABlock: PByte; out AU, ASig: Int64);
var
  I: SizeUInt;
  B: Byte;
begin
  AU := 0;
  ASig := 0;
  for I := 0 to C_TAR_OFF_CHKSUM - 1 do
  begin
    B := ABlock[I];
    AU := AU + B;
    ASig := ASig + ShortInt(B);
  end;
  AU := AU + C_TAR_LEN_CHKSUM * Ord(' ');
  ASig := ASig + C_TAR_LEN_CHKSUM * Ord(' ');
  for I := C_TAR_OFF_CHKSUM + C_TAR_LEN_CHKSUM to C_TAR_BLOCK_SIZE - 1 do
  begin
    B := ABlock[I];
    AU := AU + B;
    ASig := ASig + ShortInt(B);
  end;
end;

{ — 校验和单点：单遍 512，chksum 字段视为空格，双算兼容历史 tar 实现（循环体外联） — }
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
  Result := TarParseNumericField(@ABlock[C_TAR_OFF_CHKSUM], C_TAR_LEN_CHKSUM, C_TAR_OFF_CHKSUM);
end;

procedure TarVerifyBlockChecksum(ABlock: PByte; APos: SizeUInt); inline;
var
  Stored, U, S: Int64;
begin
  Stored := TarStoredChecksum(ABlock);
  TarComputeChecksumsDual(ABlock, U, S);
  if (Stored <> U) and (Stored <> S) then
    raise EIOError.CreateFmt('tar: header checksum mismatch at offset %d (stored %d, computed unsigned %d signed %d)', [APos, Stored, U, S]);
end;

function TarHeaderIsZeroBlock(ABlock: PByte): Boolean;
begin
  // 单源：复用 simd.SumBytes 向量化判零，无逐字节分支，万级小文件单次 SIMD 扫描
  Result := SumBytes(ABlock, C_TAR_BLOCK_SIZE) = 0;
end;

function TarHeaderIsZeroOrValid(ABlock: PByte; APos: SizeUInt): Boolean;
var
  Stored, U, S: Int64;
  I: SizeUInt;
  B: Byte;
  IsZero: Boolean;
begin
  Stored := TarParseNumericField(@ABlock[C_TAR_OFF_CHKSUM], C_TAR_LEN_CHKSUM, C_TAR_OFF_CHKSUM);
  IsZero := True;
  U := 0;
  S := 0;
  for I := 0 to C_TAR_OFF_CHKSUM - 1 do
  begin
    B := ABlock[I];
    if B <> 0 then
      IsZero := False;
    U := U + B;
    S := S + ShortInt(B);
  end;
  for I := C_TAR_OFF_CHKSUM to C_TAR_OFF_CHKSUM + C_TAR_LEN_CHKSUM - 1 do
    if ABlock[I] <> 0 then
      IsZero := False;
  U := U + C_TAR_LEN_CHKSUM * Ord(' ');
  S := S + C_TAR_LEN_CHKSUM * Ord(' ');
  for I := C_TAR_OFF_CHKSUM + C_TAR_LEN_CHKSUM to C_TAR_BLOCK_SIZE - 1 do
  begin
    B := ABlock[I];
    if B <> 0 then
      IsZero := False;
    U := U + B;
    S := S + ShortInt(B);
  end;
  if IsZero then
    Exit(True);
  if (Stored <> U) and (Stored <> S) then
    raise EIOError.CreateFmt('tar: header checksum mismatch at offset %d (stored %d, computed unsigned %d signed %d)', [APos, Stored, U, S]);
  Result := False;
end;

{ — 数值字段单点：读端 octal/base-256 解码，写端编码（循环体外联） — }
function TarParseNumericField(ABase: PByte; ALen: SizeUInt; APos: SizeUInt): Int64;
var
  I: SizeUInt;
  B: Byte;
begin
  if (ABase[0] and C_TAR_BASE256_SENTINEL) <> 0 then
  begin
    if ABase[0] = $FF then
      Result := -1
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

{ — 头字段单点：文本与校验和构造收敛至 common，消除 writer 双嵌 PutText/PutOctal/校验和分散（Move[AValue[1]] 禁 inline，外联单源） — }
procedure TarPutHeaderString(ABlock: PByte; AOff, ALen: SizeUInt; const AValue: string);
var
  CopyLen: SizeUInt;
begin
  // 单源：机械委托 bytes.ops.CopyStringToBuffer 单源 Move 语义
  CopyLen := SizeUInt(Length(AValue));
  if CopyLen > ALen then
    CopyLen := ALen;
  if CopyLen > 0 then
    CopyStringToBuffer(AValue, @ABlock[AOff], CopyLen);
end;

procedure TarPutHeaderSlice(ABlock: PByte; AOff, ALen: SizeUInt; AData: PByte; ACount: SizeUInt);
var
  CopyLen: SizeUInt;
begin
  // 单源：机械委托 bytes.ops.CopyMemory 单源 Move 语义
  CopyLen := ACount;
  if CopyLen > ALen then
    CopyLen := ALen;
  if (CopyLen > 0) and (AData <> nil) then
    CopyMemory(AData, @ABlock[AOff], CopyLen);
end;

procedure TarFinalizeHeaderChecksum(ABlock: PByte);
var
  Sum: Int64;
  I: SizeUInt;
begin
  // 单点：校验和计算与八进制格式化收敛至 common，零拷贝 PByte 切片；循环体外联
  Sum := TarComputeChecksumUnsigned(ABlock);
  for I := 0 to 5 do
    ABlock[C_TAR_OFF_CHKSUM + I] := Byte(Ord('0') + ((Sum shr ((5 - I) * 3)) and 7));
  ABlock[C_TAR_OFF_CHKSUM + 6] := 0;
  ABlock[C_TAR_OFF_CHKSUM + 7] := Ord(' ');
end;

procedure TarWriteUStarMagic(ABlock: PByte); inline;
begin
  // 单源：复用 TarPutHeaderString 单源 Move，C_TAR_MAGIC_USTAR/C_TAR_VERSION_00 单点
  TarPutHeaderString(ABlock, C_TAR_OFF_MAGIC, C_TAR_LEN_MAGIC, C_TAR_MAGIC_USTAR);
  TarPutHeaderString(ABlock, C_TAR_OFF_VERSION, C_TAR_LEN_VERSION, C_TAR_VERSION_00);
end;

{ — pax 单点：零拷贝 PByte 切片解析，复用 bytes.ops TByteSpan 零拷贝思想，无 Copy 分配 — }
function TarParsePaxRecords(ABase: PByte; ALen: SizeUInt; out APath, ALinkPath: string): Boolean;
var
  P, Sp, Eq, RecEnd: SizeInt;
  LenVal: SizeInt;
  I: SizeInt;
  B: Byte;
  KeySpan, ValSpan: TByteSpan;
  KeyLen, ValLen: SizeInt;
begin
  APath := '';
  ALinkPath := '';
  Result := False;
  if (ABase = nil) or (ALen = 0) then
    Exit(False);
  P := 0;
  while P < SizeInt(ALen) do
  begin
    Sp := P;
    while (Sp < SizeInt(ALen)) and (ABase[Sp] <> Ord(' ')) do
      Inc(Sp);
    if Sp >= SizeInt(ALen) then
      Exit;
    LenVal := 0;
    for I := P to Sp - 1 do
    begin
      B := ABase[I];
      if (B < Ord('0')) or (B > Ord('9')) then
      begin
        LenVal := 0;
        Break;
      end;
      LenVal := LenVal * 10 + (B - Ord('0'));
      if LenVal > SizeInt(ALen) then
        Break;
    end;
    if LenVal <= 0 then
      Exit;
    RecEnd := P + LenVal;
    if (RecEnd <= P) or (RecEnd > SizeInt(ALen)) then
      Exit;
    Eq := Sp + 1;
    while (Eq < RecEnd) and (ABase[Eq] <> Ord('=')) do
      Inc(Eq);
    if Eq >= RecEnd then
    begin
      P := RecEnd;
      Continue;
    end;
    KeyLen := Eq - Sp - 1;
    ValLen := RecEnd - 1 - (Eq + 1);
    if KeyLen > 0 then
      KeySpan := TByteSpan.Create(@ABase[Sp + 1], SizeUInt(KeyLen))
    else
      KeySpan := TByteSpan.Empty;
    if ValLen > 0 then
      ValSpan := TByteSpan.Create(@ABase[Eq + 1], SizeUInt(ValLen))
    else
      ValSpan := TByteSpan.Empty;
    // 零拷贝：SpanEqual 比对 key，仅命中时物化 value，降 O(n) 分配峰值
    if (KeyLen = 4) and SpanEqual(KeySpan, TByteSpan.Create(PByte(PAnsiChar('path')), 4)) then
    begin
      if ValLen > 0 then
        APath := SpanToString(ValSpan)
      else
        APath := '';
      Result := True;
    end
    else if (KeyLen = 8) and SpanEqual(KeySpan, TByteSpan.Create(PByte(PAnsiChar('linkpath')), 8)) then
    begin
      if ValLen > 0 then
        ALinkPath := SpanToString(ValSpan)
      else
        ALinkPath := '';
      Result := True;
    end;
    P := RecEnd;
  end;
end;

end.
