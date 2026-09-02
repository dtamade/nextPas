unit nextpas.core.tar.common;
{**
 * @desc Tar 共享内核：reader/writer 单点复用（@internal，四件套外内部核例外形态）。
 * 校验和 / 数值 / 文本与 pax / 守卫单点，消除两端重复，保证 fail-closed 一致。
 * 内部单元：仅供 nextpas.core.tar.* 实现内复用，禁止门面外直引；不属于公共 API。
 * 范式：已在 core/docs/design-conventions.md §2 范式例外备案，CONTRACT 约定内部不 re-export 且门面禁引，由 test_tar_contract 机械门禁。
 * 性能：薄守卫 inline + 零拷贝 PByte 切片；循环体外联守 design-conventions 真实循环体禁 inline。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.tar.base,
  nextpas.core.bytes.base,
  nextpas.core.bytes.builder,
  nextpas.core.archive.pax;

function TarPadToBlock(ASize: Int64): Int64; inline;

{** 校验：单条目尺寸与总量 *}
procedure GuardTarEntrySize(const AHeader: TTarHeader; AMaxEntry: SizeUInt);
procedure GuardTarTotalSize(ACum, ANext: UInt64; AMaxTotal: UInt64);

{** 名安全守卫（写端 EArgumentError，读端/落盘 EParseError 由调用方选） *}
procedure GuardTarNameForRead(const AName: string);

{** 512 块校验和计算与验证 *}
function TarComputeChecksumUnsigned(ABlock: PByte): Int64;
function TarComputeChecksumSigned(ABlock: PByte): Int64;
function TarStoredChecksum(ABlock: PByte): Int64; inline;
procedure TarVerifyBlockChecksum(ABlock: PByte; APos: SizeUInt); inline;
function TarHeaderIsZeroBlock(ABlock: PByte): Boolean;
function TarHeaderIsZeroOrValid(ABlock: PByte; APos: SizeUInt): Boolean;

{** 数值字段：八进制/base-256 双路径编解码 *}
function TarParseNumericField(ABase: PByte; ALen: SizeUInt; APos: SizeUInt): Int64;
procedure TarFormatNumericField(ABlock: PByte; AOff, ALen: SizeUInt; AValue: Int64);

{** 头字段写入，委托 bytes.ops 单源；Move 索引禁 inline *}
procedure TarPutHeaderString(ABlock: PByte; AOff, ALen: SizeUInt; const AValue: string);
procedure TarPutHeaderSlice(ABlock: PByte; AOff, ALen: SizeUInt; AData: PByte; ACount: SizeUInt);
procedure TarFinalizeHeaderChecksum(ABlock: PByte);
{** 写入 ustar 魔数/版本 *}
procedure TarWriteUStarMagic(ABlock: PByte); inline;
{** 生成 pax 记录；含循环/分配，外联 — 单源委托 TarAppendPaxRecord builder 零拷贝路径，禁双复制 SetLength+CopyStringToBuffer 误用；合并双超限单次构建，复用 bytes.builder 几何扩容单源 *}
function TarFormatPaxRecord(const AKey, AValue: string): string;
function TarParsePaxRecords(ABase: PByte; ALen: SizeUInt; out APath, ALinkPath: string): Boolean;
{** 追加 pax 记录至 builder，合并双超限单次构建；外联 — 零拷贝最优路径单源（Reserve+AppendBytes 直写，复用 bytes.ops 单源视图，inline AppendBytes 几何扩容） *}
procedure TarAppendPaxRecord(const ABuilder: IBytesBuilder; const AKey, AValue: string);
{** 通用 pax 键值迭代：零拷贝 PByte 切片，供归档族复用；strict length 前缀校验畸形抛 EIOError，外联 *}
type
  TTarPaxKVHandler = TArchivePaxKVHandler;
function TarParsePaxKVRecords(ABase: PByte; ALen: SizeUInt; const AHandler: TTarPaxKVHandler): Boolean;

implementation

uses
  nextpas.core.exception,
  nextpas.core.bytes.ops,
  nextpas.core.text.conv,
  nextpas.core.text.number;

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

{ — 校验和：单次扫描双累加 — }
procedure TarComputeChecksumsDual(ABlock: PByte; out AU, ASig: Int64);
var
  I: SizeUInt;
  B: Byte;
begin
  AU := 0;
  ASig := 0;
  for I := 0 to C_TAR_LAYOUT.Chksum.Off - 1 do
  begin
    B := ABlock[I];
    AU := AU + B;
    ASig := ASig + ShortInt(B);
  end;
  AU := AU + C_TAR_LAYOUT.Chksum.Len * Ord(' ');
  ASig := ASig + C_TAR_LAYOUT.Chksum.Len * Ord(' ');
  for I := C_TAR_LAYOUT.Chksum.Off + C_TAR_LAYOUT.Chksum.Len to C_TAR_BLOCK_SIZE - 1 do
  begin
    B := ABlock[I];
    AU := AU + B;
    ASig := ASig + ShortInt(B);
  end;
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
  Stored := TarStoredChecksum(ABlock);
  TarComputeChecksumsDual(ABlock, U, S);
  if (Stored <> U) and (Stored <> S) then
    raise EIOError.CreateFmt('tar: header checksum mismatch at offset %d (stored %d, computed unsigned %d signed %d)', [APos, Stored, U, S]);
end;

function TarHeaderIsZeroBlock(ABlock: PByte): Boolean;
begin
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

procedure TarPutHeaderString(ABlock: PByte; AOff, ALen: SizeUInt; const AValue: string);
var
  CopyLen: SizeUInt;
begin
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
  Sum := TarComputeChecksumUnsigned(ABlock);
  for I := 0 to 5 do
    ABlock[C_TAR_LAYOUT.Chksum.Off + I] := Byte(Ord('0') + ((Sum shr ((5 - I) * 3)) and 7));
  ABlock[C_TAR_LAYOUT.Chksum.Off + 6] := 0;
  ABlock[C_TAR_LAYOUT.Chksum.Off + 7] := Ord(' ');
end;

procedure TarWriteUStarMagic(ABlock: PByte); inline;
begin
  TarPutHeaderString(ABlock, C_TAR_LAYOUT.Magic.Off, C_TAR_LAYOUT.Magic.Len, C_TAR_MAGIC_USTAR);
  TarPutHeaderString(ABlock, C_TAR_LAYOUT.Version.Off, C_TAR_LAYOUT.Version.Len, C_TAR_VERSION_00);
end;

{ — pax 长度前缀单源：LBase/LDigits/Len 自洽，复用 UInt64DecimalDigits；消除 TarFormat/TarAppend 双复制，循环体外联 — }
function TarCalcPaxRecordLen(const AKey, AValue: string): Integer;
var
  LBase, LDigits, LNeed: Integer;
begin
  LBase := 1 + Length(AKey) + 1 + Length(AValue) + 1;
  LDigits := 1;
  Result := LBase + LDigits;
  while True do
  begin
    LNeed := UInt64DecimalDigits(UInt64(Result));
    if LNeed = LDigits then
      Break;
    LDigits := LNeed;
    Result := LBase + LDigits;
  end;
end;

function TarFormatPaxRecord(const AKey, AValue: string): string;
var
  LBuilder: IBytesBuilder;
  LSpan: TByteSpan;
begin
  // 性能：单源委托 TarAppendPaxRecord builder 零拷贝直写路径（Reserve+AppendBytes 几何扩容、单源 CopyMemory），消除 SetLength+多次 CopyStringToBuffer 双复制；单次 SpanToString Move 复用 bytes.ops 单源，薄包装外联禁 inline
  LBuilder := CreateBytesBuilder(SizeUInt(TarCalcPaxRecordLen(AKey, AValue)));
  TarAppendPaxRecord(LBuilder, AKey, AValue);
  LSpan := LBuilder.WrittenSpan;
  Result := SpanToString(LSpan);
end;

procedure TarAppendPaxRecord(const ABuilder: IBytesBuilder; const AKey, AValue: string);
var
  LLen: Integer;
  LBuf: array[0..20] of AnsiChar;
  LNumLen: Int32;
begin
  if ABuilder = nil then
    Exit;
  LLen := TarCalcPaxRecordLen(AKey, AValue);
  LNumLen := UIntToBuffer(UInt64(LLen), @LBuf[0]);
  ABuilder.Reserve(SizeUInt(LLen));
  ABuilder.AppendBytes(PByte(@LBuf[0]), SizeUInt(LNumLen));
  ABuilder.AppendByte(Ord(' '));
  if Length(AKey) > 0 then
    ABuilder.AppendBytes(PByte(PAnsiChar(AKey)), SizeUInt(Length(AKey)));
  ABuilder.AppendByte(Ord('='));
  if Length(AValue) > 0 then
    ABuilder.AppendBytes(PByte(PAnsiChar(AValue)), SizeUInt(Length(AValue)));
  ABuilder.AppendByte(10);
end;

{ — pax 解析：零拷贝 PByte 切片 — 单源委托 archive.pax 通用解析器，strict 长度前缀校验畸形抛 EIOError，禁静默 Exit 回退截断名 — }
function TarParsePaxKVRecords(ABase: PByte; ALen: SizeUInt; const AHandler: TTarPaxKVHandler): Boolean;
begin
  // 单源：复用 archive.pax ArchivePaxParseRecords 零拷贝切片+ bytes.ops 单源视图；外联禁 inline，strict fail-closed
  Result := ArchivePaxParseRecords(ABase, ALen, AHandler);
end;

function TarParsePaxRecords(ABase: PByte; ALen: SizeUInt; out APath, ALinkPath: string): Boolean;
var
  LFound: Boolean;
  LPathTmp, LLinkTmp: string;
begin
  APath := '';
  ALinkPath := '';
  LFound := False;
  LPathTmp := '';
  LLinkTmp := '';
  if (ABase = nil) or (ALen = 0) then
    Exit(False);
  // 通用迭代：零拷贝回调仅命中 path/linkpath 时物化，降 O(n) 分配峰值；其余键经 TarParsePaxKVRecords 暴露给归档族处理 atime/mtime/size 等扩展
  ArchivePaxParseRecords(ABase, ALen,
    procedure(const AKey, AValue: TByteSpan)
    begin
      if (AKey.Len = 4) and SpanEqual(AKey, TByteSpan.Create(PByte(PAnsiChar('path')), 4)) then
      begin
        if AValue.Len > 0 then
          LPathTmp := SpanToString(AValue)
        else
          LPathTmp := '';
        LFound := True;
      end
      else if (AKey.Len = 8) and SpanEqual(AKey, TByteSpan.Create(PByte(PAnsiChar('linkpath')), 8)) then
      begin
        if AValue.Len > 0 then
          LLinkTmp := SpanToString(AValue)
        else
          LLinkTmp := '';
        LFound := True;
      end
      else
        ; // 扩展键由调用方通过 TarParsePaxKVRecords 零拷贝迭代处理，不在此静默忽略外抛
    end);
  APath := LPathTmp;
  ALinkPath := LLinkTmp;
  Result := LFound;
end;

end.
