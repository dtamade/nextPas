unit nextpas.core.tar.writer;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.tar.base,
  nextpas.core.io.intf;

type
  {** @desc Tar 写器：以 IWriter 为目标产出 ustar 流（两零块收尾，可对接 gzip）。 *}
  TTarWriter = class
  private
    FDst: IWriter;
    FFinished: Boolean;
    procedure WriteBlock(const ABlock: array of Byte);
    procedure EmitEntry(const AHdr: TTarHeader; const AData: TBytes);
  public
    constructor Create(const ADst: IWriter);
    procedure AddEntry(const AHdr: TTarHeader; const AData: TBytes);
    procedure AddEntryWithOptions(const AName: string; const AData: TBytes; const AOpts: TTarAddOptions); overload;
    procedure AddFile(const AName: string; const AData: TBytes; AMode: Cardinal = C_TAR_DEFAULT_FILE_MODE; AMTimeUnix: Int64 = 0);
    procedure AddDir(const AName: string; AMode: Cardinal = C_TAR_DEFAULT_DIR_MODE; AMTimeUnix: Int64 = 0);
    procedure Finish;
    destructor Destroy; override;
  end;

implementation

uses
  nextpas.core.exception,
  nextpas.core.tar.common;

const
  CBlockSize = C_TAR_BLOCK_SIZE;

function KindToTypeFlag(AKind: TTarEntryKind): Byte;
begin
  case AKind of
    tekHardLink: Result := Ord('1');
    tekSymlink: Result := Ord('2');
    tekCharDevice: Result := Ord('3');
    tekBlockDevice: Result := Ord('4');
    tekDirectory: Result := Ord('5');
    tekFifo: Result := Ord('6');
  else
    Result := Ord('0');
  end;
end;

{ TTarWriter }

constructor TTarWriter.Create(const ADst: IWriter);
begin
  inherited Create;
  if ADst = nil then
    raise EArgumentError.Create('tar: destination writer is nil');
  FDst := ADst;
end;

procedure TTarWriter.WriteBlock(const ABlock: array of Byte);
var
  Zero: array[0..C_TAR_BLOCK_SIZE - 1] of Byte;
  Len: SizeInt;
begin
  Len := Length(ABlock);
  if Len > CBlockSize then
    Len := CBlockSize;
  if Len > 0 then
  begin
    if FDst.Write(ABlock[0], SizeUInt(Len)) <> SizeUInt(Len) then
      raise EIOError.Create('tar: short write');
  end;
  if Len < CBlockSize then
  begin
    FillChar(Zero[0], SizeOf(Zero), 0);
    if FDst.Write(Zero[0], SizeUInt(CBlockSize - Len)) <> SizeUInt(CBlockSize - Len) then
      raise EIOError.Create('tar: short write');
  end;
end;

procedure TTarWriter.EmitEntry(const AHdr: TTarHeader; const AData: TBytes);
var
  Block: array[0..C_TAR_BLOCK_SIZE - 1] of Byte;
  PadBlock: array[0..C_TAR_BLOCK_SIZE - 1] of Byte;
  procedure PutText(AOfs, ALen: SizeInt; const AValue: string);
  var
    CopyLen: SizeInt;
  begin
    CopyLen := Length(AValue);
    if CopyLen > ALen then
      CopyLen := ALen;
    if CopyLen > 0 then
      Move(AValue[1], Block[AOfs], CopyLen);
  end;
  procedure PutOctal(AOfs, ALen: SizeInt; AValue: Int64);
  var
    I: SizeInt;
    MaxBase256: Int64;
  begin
    if AValue < 0 then
      raise EIOError.CreateFmt('tar: negative numeric field %d at offset %d', [AValue, AOfs]);
    if AValue >= (Int64(1) shl ((ALen - 1) * 3)) then
    begin
      if ALen <= 1 then
        raise EIOError.Create('tar: numeric field too small for base-256');
      // base-256 可表示范围：首字节 0x80 保留 1 位 + (ALen-1)*8 位
      if ALen - 1 >= 8 then
        MaxBase256 := High(Int64)
      else
        MaxBase256 := (Int64(1) shl ((ALen - 1) * 8 + 7)) - 1;
      if AValue > MaxBase256 then
        raise EIOError.CreateFmt('tar: numeric field %d exceeds base-256 capacity %d at offset %d', [AValue, MaxBase256, AOfs]);
      Block[AOfs] := C_TAR_BASE256_SENTINEL;
      for I := ALen - 1 downto 1 do
      begin
        Block[AOfs + I] := Byte(AValue and $FF);
        AValue := AValue shr 8;
      end;
      Exit;
    end;
    Block[AOfs + ALen - 1] := 0;
    for I := ALen - 2 downto 0 do
    begin
      Block[AOfs + I] := Byte(Ord('0') + (AValue and 7));
      AValue := AValue shr 3;
    end;
  end;
var
  Sum: Integer;
  I: Integer;
  PadLen: Int64;
  Name, LinkName: string;
  CutPos: SizeInt;
begin
  if FFinished then
    raise EInvalidOperationError.Create('tar: writer already finished');
  FillChar(Block[0], SizeOf(Block), 0);
  Name := AHdr.Name;
  LinkName := AHdr.LinkName;
  if (AHdr.Kind = tekDirectory) and (Name <> '') and (Name[Length(Name)] <> '/') then
    Name := Name + '/';
  ValidateTarEntryName(Name);
  if (LinkName <> '') and (Pos(#0, LinkName) > 0) then
    raise EArgumentError.Create('tar: linkname contains NUL');
  PutText(C_TAR_OFF_NAME, C_TAR_LEN_NAME, Name);
  if Length(Name) > C_TAR_LEN_NAME then
  begin
    CutPos := 0;
    I := C_TAR_LEN_PREFIX;
    while (I >= 1) and (CutPos = 0) do
    begin
      if (I < Length(Name)) and (Name[I + 1] = '/') and (Length(Name) - I - 1 <= C_TAR_LEN_NAME) then
        CutPos := I;
      Dec(I);
    end;
    if CutPos = 0 then
      raise EIOError.Create('tar: entry name too long for ustar');
    FillChar(Block[C_TAR_OFF_NAME], C_TAR_LEN_NAME, 0);
    PutText(C_TAR_OFF_PREFIX, C_TAR_LEN_PREFIX, Copy(Name, 1, CutPos));
    PutText(C_TAR_OFF_NAME, C_TAR_LEN_NAME, Copy(Name, CutPos + 2, MaxInt));
  end;
  PutOctal(C_TAR_OFF_MODE, C_TAR_LEN_MODE, AHdr.Mode);
  PutOctal(C_TAR_OFF_UID, C_TAR_LEN_UID, AHdr.UID);
  PutOctal(C_TAR_OFF_GID, C_TAR_LEN_GID, AHdr.GID);
  if AHdr.Kind = tekRegular then
    PutOctal(C_TAR_OFF_SIZE, C_TAR_LEN_SIZE, Length(AData))
  else
    PutOctal(C_TAR_OFF_SIZE, C_TAR_LEN_SIZE, 0);
  PutOctal(C_TAR_OFF_MTIME, C_TAR_LEN_MTIME, AHdr.MTimeUnix);
  FillChar(Block[C_TAR_OFF_CHKSUM], C_TAR_LEN_CHKSUM, Ord(' '));
  Block[C_TAR_OFF_TYPEFLAG] := Byte(KindToTypeFlag(AHdr.Kind));
  PutText(C_TAR_OFF_LINKNAME, C_TAR_LEN_LINKNAME, LinkName);
  Block[C_TAR_OFF_MAGIC] := Ord('u');
  Block[C_TAR_OFF_MAGIC + 1] := Ord('s');
  Block[C_TAR_OFF_MAGIC + 2] := Ord('t');
  Block[C_TAR_OFF_MAGIC + 3] := Ord('a');
  Block[C_TAR_OFF_MAGIC + 4] := Ord('r');
  Block[C_TAR_OFF_MAGIC + 5] := 0;
  Block[C_TAR_OFF_VERSION] := Ord('0');
  Block[C_TAR_OFF_VERSION + 1] := Ord('0');
  PutText(C_TAR_OFF_UNAME, C_TAR_LEN_UNAME, AHdr.UName);
  PutText(C_TAR_OFF_GNAME, C_TAR_LEN_GNAME, AHdr.GName);
  Sum := 0;
  for I := 0 to CBlockSize - 1 do
    Sum := Sum + Block[I];
  for I := 0 to 5 do
    Block[C_TAR_OFF_CHKSUM + I] := Byte(Ord('0') + ((Sum shr ((5 - I) * 3)) and 7));
  Block[C_TAR_OFF_CHKSUM + 6] := 0;
  Block[C_TAR_OFF_CHKSUM + 7] := Ord(' ');
  WriteBlock(Block);
  if (AHdr.Kind = tekRegular) and (Length(AData) > 0) then
  begin
    if FDst.Write(AData[0], SizeUInt(Length(AData))) <> SizeUInt(Length(AData)) then
      raise EIOError.Create('tar: short write');
    PadLen := TarPadToBlock(Length(AData));
    if PadLen > 0 then
    begin
      FillChar(PadBlock[0], SizeOf(PadBlock), 0);
      if FDst.Write(PadBlock[0], SizeUInt(PadLen)) <> SizeUInt(PadLen) then
        raise EIOError.Create('tar: short write');
    end;
  end;
end;

procedure TTarWriter.AddEntry(const AHdr: TTarHeader; const AData: TBytes);
begin
  EmitEntry(AHdr, AData);
end;

procedure TTarWriter.AddEntryWithOptions(const AName: string; const AData: TBytes; const AOpts: TTarAddOptions);
var
  H: TTarHeader;
begin
  H := Default(TTarHeader);
  H.Name := AName;
  H.Kind := tekRegular;
  H.Mode := AOpts.Mode;
  if H.Mode = 0 then
    H.Mode := C_TAR_DEFAULT_FILE_MODE;
  H.UID := AOpts.UID;
  H.GID := AOpts.GID;
  H.MTimeUnix := AOpts.MTimeUnix;
  H.UName := AOpts.UName;
  H.GName := AOpts.GName;
  H.Size := Length(AData);
  EmitEntry(H, AData);
end;

procedure TTarWriter.AddFile(const AName: string; const AData: TBytes; AMode: Cardinal; AMTimeUnix: Int64);
var
  H: TTarHeader;
begin
  H := Default(TTarHeader);
  H.Name := AName;
  H.Kind := tekRegular;
  H.Mode := AMode;
  H.MTimeUnix := AMTimeUnix;
  H.Size := Length(AData);
  EmitEntry(H, AData);
end;

procedure TTarWriter.AddDir(const AName: string; AMode: Cardinal; AMTimeUnix: Int64);
var
  H: TTarHeader;
begin
  H := Default(TTarHeader);
  H.Name := AName;
  H.Kind := tekDirectory;
  H.Mode := AMode;
  H.MTimeUnix := AMTimeUnix;
  EmitEntry(H, nil);
end;

procedure TTarWriter.Finish;
var
  Zero: array[0..C_TAR_BLOCK_SIZE - 1] of Byte;
begin
  if FFinished then
    Exit;
  FFinished := True;
  FillChar(Zero[0], SizeOf(Zero), 0);
  WriteBlock(Zero);
  WriteBlock(Zero);
end;

destructor TTarWriter.Destroy;
begin
  Finish;
  inherited Destroy;
end;

end.
