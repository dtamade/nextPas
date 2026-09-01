unit nextpas.core.tar.reader;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.tar.base,
  nextpas.core.io.intf;

type
  {** @desc Tar 读器：迭代内存镜像中的条目，零拷贝视图 + bomb 守卫。 *}
  TTarReader = class
  private
    FBuf: TBytes;
    FData: PByte;
    FCount: SizeUInt;
    FPos: SizeUInt;
    FEntryDataOfs: SizeUInt;
    FEntrySize: Int64;
    FPendingLongName: string;
    FPendingLongLink: string;
    FPaxPath: string;
    FPaxLinkPath: string;
    FGlobalPaxPath: string;
    FGlobalPaxLinkPath: string;
    FMaxEntry: SizeUInt;
    FMaxTotal: UInt64;
    FCumTotal: UInt64;
    { — 热路径：块/字段/校验，均 inline 以消除 Next 每 entry 多次调用开销 — }
    function ByteAt(AOfs: SizeUInt): Byte; inline;
    function BlockIsZero(APos: SizeUInt): Boolean; inline;
    function StringField(AOfs, ALen: SizeUInt): string; inline;
    function NumericField(AOfs, ALen: SizeUInt): Int64; inline;
    function MagicHasUStar: Boolean; inline;
    procedure VerifyChecksum; inline;
    function HeaderIsZeroOrValid(APos: SizeUInt): Boolean; inline;
    { — pax/扩展：零拷贝 slice 解析，消除每记录 Copy+BytesToText 分配 — }
    function ParsePaxRecordsSlice(ABase: PByte; ALen: SizeUInt): Boolean;
    function ParsePaxRecords(const AData: TBytes): Boolean;
    { — 扩展载荷：去重 GNU L/K 与 pax 三分支的 SetLength+Move — }
    function GetExtendedPayload(ASize: Int64; out APtr: PByte; out ALen: SizeUInt): Boolean; inline;
    function SliceToString(ABase: PByte; ALen: SizeUInt): string; inline;
  public
    constructor Create(const AData: TBytes); overload;
    constructor Create(AData: PByte; ACount: SizeUInt); overload;
    constructor CreateWithOptions(const AData: TBytes; const AOptions: TTarReadOptions); overload;
    constructor CreateWithOptions(AData: PByte; ACount: SizeUInt; const AOptions: TTarReadOptions); overload;
    function Next(out AHeader: TTarHeader): Boolean;
    function EntryData: TBytes;
    function EntryDataOfs: SizeUInt;
    { 零拷贝视图：返回当前条目载荷在原镜像中的区间（未拷贝） }
    function EntryDataSlice(out AData: PByte; out ACount: SizeUInt): Boolean;
    { 拉式零拷贝流：基于切片的 IReader（随 reader 生命周期，不拥有镜像）}
    function OpenEntryStream: IReader;
    function EntrySize: Int64; inline;
  end;

implementation

uses
  nextpas.core.exception,
  nextpas.core.tar.common,
  nextpas.core.text.conv;

const
  CBlockSize = C_TAR_BLOCK_SIZE;

function TypeFlagToKind(AFlag: Byte): TTarEntryKind;
begin
  case AFlag of
    0, Ord('0'), Ord('7'): Result := tekRegular;
    Ord('1'): Result := tekHardLink;
    Ord('2'): Result := tekSymlink;
    Ord('3'): Result := tekCharDevice;
    Ord('4'): Result := tekBlockDevice;
    Ord('5'): Result := tekDirectory;
    Ord('6'): Result := tekFifo;
  else
    raise EIOError.CreateFmt('tar: unsupported type flag "%c"', [Chr(AFlag)]);
  end;
end;

{ TTarReader }

constructor TTarReader.Create(const AData: TBytes);
begin
  CreateWithOptions(AData, DefaultTarReadOptions);
end;

constructor TTarReader.Create(AData: PByte; ACount: SizeUInt);
begin
  CreateWithOptions(AData, ACount, DefaultTarReadOptions);
end;

constructor TTarReader.CreateWithOptions(const AData: TBytes; const AOptions: TTarReadOptions);
begin
  inherited Create;
  FBuf := AData;
  if Length(AData) > 0 then
    FData := @AData[0]
  else
    FData := nil;
  FCount := SizeUInt(Length(AData));
  FPos := 0;
  FMaxEntry := AOptions.MaxEntrySize;
  FMaxTotal := AOptions.MaxTotalSize;
  FCumTotal := 0;
end;

constructor TTarReader.CreateWithOptions(AData: PByte; ACount: SizeUInt; const AOptions: TTarReadOptions);
begin
  inherited Create;
  FData := AData;
  FCount := ACount;
  FPos := 0;
  FMaxEntry := AOptions.MaxEntrySize;
  FMaxTotal := AOptions.MaxTotalSize;
  FCumTotal := 0;
end;

function TTarReader.ByteAt(AOfs: SizeUInt): Byte; inline;
begin
  if AOfs >= FCount then
    raise EIOError.CreateFmt('tar: truncated stream at offset %d (need %d, have %d)', [AOfs, AOfs + 1, FCount]);
  Result := FData[AOfs];
end;

function TTarReader.BlockIsZero(APos: SizeUInt): Boolean; inline;
var
  I: SizeUInt;
begin
  if APos + CBlockSize > FCount then
    Exit(False);
  Result := True;
  for I := 0 to CBlockSize - 1 do
    if FData[APos + I] <> 0 then
      Exit(False);
end;

function TTarReader.StringField(AOfs, ALen: SizeUInt): string; inline;
var
  EndOfs: SizeUInt;
  J: SizeInt;
begin
  EndOfs := AOfs + ALen;
  if EndOfs > FCount then
    raise EIOError.CreateFmt('tar: truncated stream at offset %d (field %d+%d > %d)', [AOfs, AOfs, ALen, FCount]);
  J := SizeInt(AOfs);
  while (J < SizeInt(EndOfs)) and (FData[J] <> 0) do
    Inc(J);
  SetLength(Result, J - SizeInt(AOfs));
  if Length(Result) > 0 then
    Move(FData[AOfs], Result[1], Length(Result));
end;

function TTarReader.NumericField(AOfs, ALen: SizeUInt): Int64; inline;
var
  I: SizeUInt;
  B: Byte;
begin
  if AOfs + ALen > FCount then
    raise EIOError.CreateFmt('tar: truncated stream at offset %d (numeric %d+%d > %d)', [AOfs, AOfs, ALen, FCount]);
  if (FData[AOfs] and C_TAR_BASE256_SENTINEL) <> 0 then
  begin
    Result := Int64(FData[AOfs] and $7F);
    for I := AOfs + 1 to AOfs + ALen - 1 do
      Result := (Result shl 8) or Int64(FData[I]);
    Exit;
  end;
  Result := 0;
  for I := AOfs to AOfs + ALen - 1 do
  begin
    B := FData[I];
    if B = 0 then
      Break;
    if B = Ord(' ') then
      Continue;
    if (B < Ord('0')) or (B > Ord('7')) then
      raise EIOError.CreateFmt('tar: corrupt octal field at offset %d (byte %d)', [I, B]);
    Result := (Result shl 3) or Int64(B - Ord('0'));
  end;
end;

function TTarReader.MagicHasUStar: Boolean; inline;
begin
  Result := (FPos + C_TAR_OFF_MAGIC + 5 < FCount)
    and (FData[FPos + C_TAR_OFF_MAGIC] = Ord('u'))
    and (FData[FPos + C_TAR_OFF_MAGIC + 1] = Ord('s'))
    and (FData[FPos + C_TAR_OFF_MAGIC + 2] = Ord('t'))
    and (FData[FPos + C_TAR_OFF_MAGIC + 3] = Ord('a'))
    and (FData[FPos + C_TAR_OFF_MAGIC + 4] = Ord('r'));
end;

procedure TTarReader.VerifyChecksum; inline;
var
  StoredSum: Int64;
  UnsignedSum: Int64;
  SignedSum: Int64;
  I: SizeUInt;
  B: Byte;
begin
  StoredSum := NumericField(FPos + C_TAR_OFF_CHKSUM, C_TAR_LEN_CHKSUM);
  UnsignedSum := 0;
  SignedSum := 0;
  for I := 0 to CBlockSize - 1 do
  begin
    if (I >= C_TAR_OFF_CHKSUM) and (I < C_TAR_OFF_CHKSUM + C_TAR_LEN_CHKSUM) then
      B := Ord(' ')
    else
      B := FData[FPos + I];
    UnsignedSum := UnsignedSum + B;
    SignedSum := SignedSum + ShortInt(B);
  end;
  if (StoredSum <> UnsignedSum) and (StoredSum <> SignedSum) then
    raise EIOError.CreateFmt('tar: header checksum mismatch at offset %d (stored %d, computed unsigned %d signed %d)', [FPos, StoredSum, UnsignedSum, SignedSum]);
end;

{ — 融合零块检测与校验和：单遍 512 扫描消除双遍遍历 — }
function TTarReader.HeaderIsZeroOrValid(APos: SizeUInt): Boolean; inline;
var
  StoredSum: Int64;
  UnsignedSum: Int64;
  SignedSum: Int64;
  I: SizeUInt;
  B: Byte;
  IsZero: Boolean;
begin
  // 先判越界：不足一块按非零处理，由调用方走 trailing partial 分支
  if APos + CBlockSize > FCount then
    Exit(False);
  StoredSum := NumericField(APos + C_TAR_OFF_CHKSUM, C_TAR_LEN_CHKSUM);
  IsZero := True;
  UnsignedSum := 0;
  SignedSum := 0;
  for I := 0 to CBlockSize - 1 do
  begin
    B := FData[APos + I];
    if B <> 0 then
      IsZero := False;
    if (I >= C_TAR_OFF_CHKSUM) and (I < C_TAR_OFF_CHKSUM + C_TAR_LEN_CHKSUM) then
      B := Ord(' ');
    UnsignedSum := UnsignedSum + B;
    SignedSum := SignedSum + ShortInt(B);
  end;
  if IsZero then
    Exit(True);
  if (StoredSum <> UnsignedSum) and (StoredSum <> SignedSum) then
    raise EIOError.CreateFmt('tar: header checksum mismatch at offset %d (stored %d, computed unsigned %d signed %d)', [APos, StoredSum, UnsignedSum, SignedSum]);
  Result := False;
end;

function BytesToText(const AData: TBytes): string;
var
  EndPos: SizeInt;
begin
  EndPos := Length(AData);
  while (EndPos > 0) and (AData[EndPos - 1] = 0) do
    Dec(EndPos);
  SetLength(Result, EndPos);
  if EndPos > 0 then
    Move(AData[0], Result[1], EndPos);
end;

function TTarReader.SliceToString(ABase: PByte; ALen: SizeUInt): string; inline;
var
  Trim: SizeUInt;
begin
  Trim := ALen;
  while (Trim > 0) and (ABase[Trim - 1] = 0) do
    Dec(Trim);
  SetLength(Result, Trim);
  if Trim > 0 then
    Move(ABase^, Result[1], Trim);
end;

function TTarReader.GetExtendedPayload(ASize: Int64; out APtr: PByte; out ALen: SizeUInt): Boolean; inline;
begin
  APtr := nil;
  ALen := 0;
  if ASize < 0 then
    raise EIOError.CreateFmt('tar: negative entry size %d at offset %d', [ASize, FPos]);
  if ASize = 0 then
    Exit(True);
  if UInt64(ASize) > UInt64(FMaxEntry) then
    raise EIOError.CreateFmt('tar: entry size %d exceeds limit %d at offset %d', [ASize, Int64(FMaxEntry), FPos]);
  if FPos + CBlockSize + SizeUInt(ASize) > FCount then
    raise EIOError.CreateFmt('tar: truncated entry data at offset %d (need %d, have %d)', [FPos + CBlockSize, ASize, Int64(FCount) - Int64(FPos + CBlockSize)]);
  APtr := FData + FPos + CBlockSize;
  ALen := SizeUInt(ASize);
  Result := True;
end;

function TTarReader.ParsePaxRecordsSlice(ABase: PByte; ALen: SizeUInt): Boolean;
var
  P, Sp, Eq, RecEnd: SizeInt;
  LenVal: SizeInt;
  Key, Value: string;
  I: SizeInt;
  B: Byte;
begin
  Result := False;
  P := 0;
  while P < SizeInt(ALen) do
  begin
    Sp := P;
    while (Sp < SizeInt(ALen)) and (ABase[Sp] <> Ord(' ')) do
      Inc(Sp);
    if Sp >= SizeInt(ALen) then
      Exit;
    // 零拷贝：直接在 slice 上十进制解析长度前缀，无 Copy/BytesToText 分配
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
    SetLength(Key, Eq - Sp - 1);
    if Length(Key) > 0 then
      Move(ABase[Sp + 1], Key[1], Length(Key));
    SetLength(Value, RecEnd - 1 - (Eq + 1));
    if Length(Value) > 0 then
      Move(ABase[Eq + 1], Value[1], Length(Value));
    if Key = 'path' then
    begin
      FPaxPath := Value;
      Result := True;
    end
    else if Key = 'linkpath' then
    begin
      FPaxLinkPath := Value;
      Result := True;
    end;
    P := RecEnd;
  end;
end;

function TTarReader.ParsePaxRecords(const AData: TBytes): Boolean;
begin
  if Length(AData) = 0 then
    Exit(False);
  Result := ParsePaxRecordsSlice(@AData[0], SizeUInt(Length(AData)));
end;

function TTarReader.Next(out AHeader: TTarHeader): Boolean;
var
  Flag: Byte;
  Size: Int64;
  Pad: Int64;
  PayloadPtr: PByte;
  PayloadLen: SizeUInt;
  Prefix, Name: string;
begin
  Result := False;
  FPendingLongName := '';
  FPendingLongLink := '';
  FPaxPath := '';
  FPaxLinkPath := '';
  while True do
  begin
    if FPos >= FCount then
      Exit(False);
    if FCount - FPos < CBlockSize then
      raise EIOError.CreateFmt('tar: trailing partial block at offset %d (need %d, have %d)', [FPos, CBlockSize, FCount - FPos]);
    if HeaderIsZeroOrValid(FPos) then
      Exit(False);
    Size := NumericField(FPos + C_TAR_OFF_SIZE, C_TAR_LEN_SIZE);
    if Size < 0 then
      raise EIOError.CreateFmt('tar: negative entry size %d at offset %d', [Size, FPos]);
    Flag := ByteAt(FPos + C_TAR_OFF_TYPEFLAG);
    if Flag = Ord('L') then
    begin
      GetExtendedPayload(Size, PayloadPtr, PayloadLen);
      if PayloadLen > 0 then
        FPendingLongName := SliceToString(PayloadPtr, PayloadLen)
      else
        FPendingLongName := '';
    end
    else if Flag = Ord('K') then
    begin
      GetExtendedPayload(Size, PayloadPtr, PayloadLen);
      if PayloadLen > 0 then
        FPendingLongLink := SliceToString(PayloadPtr, PayloadLen)
      else
        FPendingLongLink := '';
    end
    else if (Flag = Ord('x')) or (Flag = Ord('g')) then
    begin
      GetExtendedPayload(Size, PayloadPtr, PayloadLen);
      if PayloadLen > 0 then
      begin
        if ParsePaxRecordsSlice(PayloadPtr, PayloadLen) then
        begin
          if Flag = Ord('g') then
          begin
            if FPaxPath <> '' then
            begin
              FGlobalPaxPath := FPaxPath;
              FPaxPath := '';
            end;
            if FPaxLinkPath <> '' then
            begin
              FGlobalPaxLinkPath := FPaxLinkPath;
              FPaxLinkPath := '';
            end;
          end;
        end;
      end
      else
      begin
        // 空 pax 块，无记录
      end;
    end
    else
    begin
      AHeader := Default(TTarHeader);
      Name := StringField(FPos + C_TAR_OFF_NAME, C_TAR_LEN_NAME);
      if MagicHasUStar then
      begin
        Prefix := StringField(FPos + C_TAR_OFF_PREFIX, C_TAR_LEN_PREFIX);
        if (Prefix <> '') and (Name <> '') then
          Name := Prefix + '/' + Name
        else if Prefix <> '' then
          Name := Prefix;
      end;
      if FPendingLongName <> '' then
        Name := FPendingLongName
      else if FPaxPath <> '' then
        Name := FPaxPath
      else if FGlobalPaxPath <> '' then
        Name := FGlobalPaxPath;
      AHeader.Name := Name;
      AHeader.LinkName := StringField(FPos + C_TAR_OFF_LINKNAME, C_TAR_LEN_LINKNAME);
      if FPendingLongLink <> '' then
        AHeader.LinkName := FPendingLongLink
      else if FPaxLinkPath <> '' then
        AHeader.LinkName := FPaxLinkPath
      else if FGlobalPaxLinkPath <> '' then
        AHeader.LinkName := FGlobalPaxLinkPath;
      AHeader.Kind := TypeFlagToKind(Flag);
      AHeader.Mode := Cardinal(NumericField(FPos + C_TAR_OFF_MODE, C_TAR_LEN_MODE)) and $FFFF;
      AHeader.UID := Cardinal(NumericField(FPos + C_TAR_OFF_UID, C_TAR_LEN_UID));
      AHeader.GID := Cardinal(NumericField(FPos + C_TAR_OFF_GID, C_TAR_LEN_GID));
      if AHeader.Kind = tekDirectory then
        AHeader.Size := 0
      else
        AHeader.Size := Size;
      AHeader.MTimeUnix := NumericField(FPos + C_TAR_OFF_MTIME, C_TAR_LEN_MTIME);
      AHeader.UName := StringField(FPos + C_TAR_OFF_UNAME, C_TAR_LEN_UNAME);
      AHeader.GName := StringField(FPos + C_TAR_OFF_GNAME, C_TAR_LEN_GNAME);
      { bomb 守卫：单条目与总量单点 }
      GuardTarEntrySize(AHeader, FMaxEntry);
      if AHeader.Kind = tekRegular then
      begin
        GuardTarTotalSize(FCumTotal, UInt64(AHeader.Size), FMaxTotal);
        FCumTotal := FCumTotal + UInt64(AHeader.Size);
        FEntrySize := Size;
      end
      else
        FEntrySize := 0;
      FEntryDataOfs := FPos + CBlockSize;
      if FEntryDataOfs + SizeUInt(Size) > FCount then
        raise EIOError.CreateFmt('tar: truncated entry data at offset %d (need %d, have %d)', [FEntryDataOfs, Size, Int64(FCount) - Int64(FEntryDataOfs)]);
      FPos := FPos + CBlockSize + SizeUInt(Size) + SizeUInt(TarPadToBlock(Size));
      Result := True;
      Exit;
    end;
    Pad := TarPadToBlock(Size);
    FPos := FPos + CBlockSize + SizeUInt(Size) + SizeUInt(Pad);
  end;
end;

function TTarReader.EntryData: TBytes;
var
  N: SizeInt;
begin
  Result := nil;
  if (FEntryDataOfs = 0) or (FEntrySize <= 0) then
    Exit;
  if FEntryDataOfs + SizeUInt(FEntrySize) > FCount then
    raise EIOError.CreateFmt('tar: truncated entry data at offset %d (need %d, have %d)', [FEntryDataOfs, FEntrySize, Int64(FCount) - Int64(FEntryDataOfs)]);
  if UInt64(FEntrySize) > UInt64(FMaxEntry) then
    raise EIOError.CreateFmt('tar: entry size %d exceeds limit %d at offset %d', [FEntrySize, Int64(FMaxEntry), FEntryDataOfs]);
  N := SizeInt(FEntrySize);
  SetLength(Result, N);
  Move(FData[FEntryDataOfs], Result[0], N);
end;

function TTarReader.EntryDataOfs: SizeUInt;
begin
  Result := FEntryDataOfs;
end;

function TTarReader.EntryDataSlice(out AData: PByte; out ACount: SizeUInt): Boolean;
begin
  if (FEntryDataOfs = 0) or (FEntrySize <= 0) then
  begin
    AData := nil;
    ACount := 0;
    Exit(False);
  end;
  if FEntryDataOfs + SizeUInt(FEntrySize) > FCount then
    raise EIOError.CreateFmt('tar: truncated entry data at offset %d (need %d, have %d)', [FEntryDataOfs, FEntrySize, Int64(FCount) - Int64(FEntryDataOfs)]);
  AData := FData + FEntryDataOfs;
  ACount := SizeUInt(FEntrySize);
  Result := True;
end;

{ — TTarSliceReader：零拷贝切片的拉式 IReader（职责解耦：流不与块解析混杂） — }
type
  TTarSliceReader = class(TInterfacedObject, IReader)
  private
    FBase: PByte;
    FSize: SizeUInt;
    FPos: SizeUInt;
  public
    constructor Create(ABase: PByte; ASize: SizeUInt);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
  end;

constructor TTarSliceReader.Create(ABase: PByte; ASize: SizeUInt);
begin
  inherited Create;
  FBase := ABase;
  FSize := ASize;
  FPos := 0;
end;

function TTarSliceReader.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  Avail: SizeUInt;
  LCount: SizeUInt;
begin
  if FPos >= FSize then
    Exit(0);
  Avail := FSize - FPos;
  LCount := ACount;
  if LCount > Avail then
    LCount := Avail;
  if LCount > 0 then
  begin
    Move((FBase + FPos)^, ABuf, LCount);
    Inc(FPos, LCount);
  end;
  Result := LCount;
end;

function TTarReader.OpenEntryStream: IReader;
var
  P: PByte;
  C: SizeUInt;
begin
  if not EntryDataSlice(P, C) then
  begin
    P := nil;
    C := 0;
  end;
  Result := TTarSliceReader.Create(P, C);
end;

function TTarReader.EntrySize: Int64;
begin
  Result := FEntrySize;
end;

end.
