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
    function ByteAt(AOfs: SizeUInt): Byte;
    function BlockIsZero(APos: SizeUInt): Boolean;
    function StringField(AOfs, ALen: SizeUInt): string;
    function NumericField(AOfs, ALen: SizeUInt): Int64;
    function MagicHasUStar: Boolean;
    procedure VerifyChecksum;
    function ParsePaxRecords(const AData: TBytes): Boolean;
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

function PadToBlock(ASize: Int64): Int64; inline;
begin
  Result := TarPadToBlock(ASize);
end;

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

function TTarReader.ByteAt(AOfs: SizeUInt): Byte;
begin
  if AOfs >= FCount then
    raise EIOError.Create('tar: truncated stream');
  Result := FData[AOfs];
end;

function TTarReader.BlockIsZero(APos: SizeUInt): Boolean;
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

function TTarReader.StringField(AOfs, ALen: SizeUInt): string;
var
  EndOfs: SizeUInt;
  J: SizeInt;
begin
  EndOfs := AOfs + ALen;
  if EndOfs > FCount then
    raise EIOError.Create('tar: truncated stream');
  J := SizeInt(AOfs);
  while (J < SizeInt(EndOfs)) and (FData[J] <> 0) do
    Inc(J);
  SetLength(Result, J - SizeInt(AOfs));
  if Length(Result) > 0 then
    Move(FData[AOfs], Result[1], Length(Result));
end;

function TTarReader.NumericField(AOfs, ALen: SizeUInt): Int64;
var
  I: SizeUInt;
  B: Byte;
begin
  if AOfs + ALen > FCount then
    raise EIOError.Create('tar: truncated stream');
  if (FData[AOfs] and $80) <> 0 then
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
      raise EIOError.Create('tar: corrupt octal field');
    Result := (Result shl 3) or Int64(B - Ord('0'));
  end;
end;

function TTarReader.MagicHasUStar: Boolean;
begin
  Result := (FPos + 262 < FCount)
    and (FData[FPos + 257] = Ord('u'))
    and (FData[FPos + 258] = Ord('s'))
    and (FData[FPos + 259] = Ord('t'))
    and (FData[FPos + 260] = Ord('a'))
    and (FData[FPos + 261] = Ord('r'));
end;

procedure TTarReader.VerifyChecksum;
var
  StoredSum: Int64;
  UnsignedSum: Int64;
  SignedSum: Int64;
  I: SizeUInt;
  B: Byte;
begin
  StoredSum := NumericField(FPos + 148, 8);
  UnsignedSum := 0;
  SignedSum := 0;
  for I := 0 to CBlockSize - 1 do
  begin
    if (I >= 148) and (I < 156) then
      B := Ord(' ')
    else
      B := FData[FPos + I];
    UnsignedSum := UnsignedSum + B;
    SignedSum := SignedSum + ShortInt(B);
  end;
  if (StoredSum <> UnsignedSum) and (StoredSum <> SignedSum) then
    raise EIOError.Create('tar: header checksum mismatch');
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

function TTarReader.ParsePaxRecords(const AData: TBytes): Boolean;
var
  P, Sp, Eq, RecEnd: SizeInt;
  Key, Value: string;
begin
  Result := False;
  P := 0;
  while P < Length(AData) do
  begin
    Sp := P;
    while (Sp < Length(AData)) and (AData[Sp] <> Ord(' ')) do
      Inc(Sp);
    if Sp >= Length(AData) then
      Exit;
    RecEnd := P + StrToIntDef(BytesToText(Copy(AData, P, Sp - P)), 0);
    if (RecEnd <= P) or (RecEnd > Length(AData)) then
      Exit;
    Eq := Sp + 1;
    while (Eq < RecEnd) and (AData[Eq] <> Ord('=')) do
      Inc(Eq);
    if Eq >= RecEnd then
    begin
      P := RecEnd;
      Continue;
    end;
    SetLength(Key, Eq - Sp - 1);
    Move(AData[Sp + 1], Key[1], Length(Key));
    SetLength(Value, RecEnd - 1 - (Eq + 1));
    if Length(Value) > 0 then
      Move(AData[Eq + 1], Value[1], Length(Value));
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

function TTarReader.Next(out AHeader: TTarHeader): Boolean;
var
  Flag: Byte;
  Size: Int64;
  Pad: Int64;
  Data: TBytes;
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
      raise EIOError.Create('tar: trailing partial block');
    if BlockIsZero(FPos) then
      Exit(False);
    VerifyChecksum;
    Size := NumericField(FPos + 124, 12);
    if Size < 0 then
      raise EIOError.Create('tar: negative entry size');
    Flag := ByteAt(FPos + 156);
    if Flag = Ord('L') then
    begin
      if Size > Int64(FMaxEntry) then
        raise EIOError.Create('tar: entry size exceeds limit');
      Data := nil;
      SetLength(Data, Size);
      if Size > 0 then
        Move(FData[FPos + CBlockSize], Data[0], Size);
      FPendingLongName := BytesToText(Data);
    end
    else if Flag = Ord('K') then
    begin
      Data := nil;
      SetLength(Data, Size);
      if Size > 0 then
        Move(FData[FPos + CBlockSize], Data[0], Size);
      FPendingLongLink := BytesToText(Data);
    end
    else if (Flag = Ord('x')) or (Flag = Ord('g')) then
    begin
      Data := nil;
      SetLength(Data, Size);
      if Size > 0 then
        Move(FData[FPos + CBlockSize], Data[0], Size);
      if ParsePaxRecords(Data) then
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
      AHeader := Default(TTarHeader);
      Name := StringField(FPos, 100);
      if MagicHasUStar then
      begin
        Prefix := StringField(FPos + 345, 155);
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
      AHeader.LinkName := StringField(FPos + 157, 100);
      if FPendingLongLink <> '' then
        AHeader.LinkName := FPendingLongLink
      else if FPaxLinkPath <> '' then
        AHeader.LinkName := FPaxLinkPath
      else if FGlobalPaxLinkPath <> '' then
        AHeader.LinkName := FGlobalPaxLinkPath;
      AHeader.Kind := TypeFlagToKind(Flag);
      AHeader.Mode := Cardinal(NumericField(FPos + 100, 8)) and $FFFF;
      AHeader.UID := Cardinal(NumericField(FPos + 108, 8));
      AHeader.GID := Cardinal(NumericField(FPos + 116, 8));
      if AHeader.Kind = tekDirectory then
        AHeader.Size := 0
      else
        AHeader.Size := Size;
      AHeader.MTimeUnix := NumericField(FPos + 136, 12);
      AHeader.UName := StringField(FPos + 265, 32);
      AHeader.GName := StringField(FPos + 297, 32);
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
        raise EIOError.Create('tar: truncated entry data');
      FPos := FPos + CBlockSize + SizeUInt(Size) + SizeUInt(PadToBlock(Size));
      Result := True;
      Exit;
    end;
    Pad := PadToBlock(Size);
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
    raise EIOError.Create('tar: truncated entry data');
  if UInt64(FEntrySize) > UInt64(FMaxEntry) then
    raise EIOError.Create('tar: entry size exceeds limit');
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
    raise EIOError.Create('tar: truncated entry data');
  AData := FData + FEntryDataOfs;
  ACount := SizeUInt(FEntrySize);
  Result := True;
end;

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
