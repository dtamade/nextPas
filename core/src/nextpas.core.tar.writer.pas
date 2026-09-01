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
    procedure EmitPaxHeader(const APayload: TBytes);
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
  nextpas.core.bytes.ops,
  nextpas.core.text.conv,
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

{ — pax record：长度前缀十进制自洽，单次拼接，bytes.ops 单源 StringToBytes 零拷贝 Move — }
function MakePaxRecord(const AKey, AValue: string): string; inline;
var
  LBase, LLen, LDigits: Integer;
  SLen: string;
begin
  LBase := 1 + Length(AKey) + 1 + Length(AValue) + 1;
  LDigits := 1;
  LLen := LBase + LDigits;
  SLen := nextpas.core.text.conv.IntToStr(LLen);
  while Length(SLen) <> LDigits do
  begin
    LDigits := Length(SLen);
    LLen := LBase + LDigits;
    SLen := nextpas.core.text.conv.IntToStr(LLen);
  end;
  Result := SLen + ' ' + AKey + '=' + AValue + #10;
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

procedure TTarWriter.EmitPaxHeader(const APayload: TBytes);
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
  procedure PutOctal(AOfs, ALen: SizeInt; AValue: Int64); inline;
  begin
    // 单点：八进制/base-256 编码委托 common，inline 零拷贝
    TarFormatNumericField(@Block[0], SizeUInt(AOfs), SizeUInt(ALen), AValue);
  end;
var
  Sum: Integer;
  I: Integer;
  PadLen: Int64;
begin
  FillChar(Block[0], SizeOf(Block), 0);
  PutText(C_TAR_OFF_NAME, C_TAR_LEN_NAME, 'pax_header');
  PutOctal(C_TAR_OFF_MODE, C_TAR_LEN_MODE, 0);
  PutOctal(C_TAR_OFF_UID, C_TAR_LEN_UID, 0);
  PutOctal(C_TAR_OFF_GID, C_TAR_LEN_GID, 0);
  PutOctal(C_TAR_OFF_SIZE, C_TAR_LEN_SIZE, Length(APayload));
  PutOctal(C_TAR_OFF_MTIME, C_TAR_LEN_MTIME, 0);
  FillChar(Block[C_TAR_OFF_CHKSUM], C_TAR_LEN_CHKSUM, Ord(' '));
  Block[C_TAR_OFF_TYPEFLAG] := Ord('x');
  Block[C_TAR_OFF_MAGIC] := Ord('u');
  Block[C_TAR_OFF_MAGIC + 1] := Ord('s');
  Block[C_TAR_OFF_MAGIC + 2] := Ord('t');
  Block[C_TAR_OFF_MAGIC + 3] := Ord('a');
  Block[C_TAR_OFF_MAGIC + 4] := Ord('r');
  Block[C_TAR_OFF_MAGIC + 5] := 0;
  Block[C_TAR_OFF_VERSION] := Ord('0');
  Block[C_TAR_OFF_VERSION + 1] := Ord('0');
  // 单点：校验和计算委托 common，零拷贝 inline 单遍
  Sum := Integer(TarComputeChecksumUnsigned(@Block[0]));
  for I := 0 to 5 do
    Block[C_TAR_OFF_CHKSUM + I] := Byte(Ord('0') + ((Sum shr ((5 - I) * 3)) and 7));
  Block[C_TAR_OFF_CHKSUM + 6] := 0;
  Block[C_TAR_OFF_CHKSUM + 7] := Ord(' ');
  WriteBlock(Block);
  if Length(APayload) > 0 then
  begin
    if FDst.Write(APayload[0], SizeUInt(Length(APayload))) <> SizeUInt(Length(APayload)) then
      raise EIOError.Create('tar: short write');
    PadLen := TarPadToBlock(Length(APayload));
    if PadLen > 0 then
    begin
      FillChar(PadBlock[0], SizeOf(PadBlock), 0);
      if FDst.Write(PadBlock[0], SizeUInt(PadLen)) <> SizeUInt(PadLen) then
        raise EIOError.Create('tar: short write');
    end;
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
  procedure PutOctal(AOfs, ALen: SizeInt; AValue: Int64); inline;
  begin
    // 单点：八进制/base-256 编码委托 common，inline 零拷贝
    TarFormatNumericField(@Block[0], SizeUInt(AOfs), SizeUInt(ALen), AValue);
  end;
var
  Sum: Integer;
  I: Integer;
  PadLen: Int64;
  Name, LinkName: string;
  CutPos: SizeInt;
  LPaxText: string;
  LPaxBytes: TBytes;
begin
  if FFinished then
    raise EInvalidOperationError.Create('tar: writer already finished');
  Name := AHdr.Name;
  LinkName := AHdr.LinkName;
  if (AHdr.Kind = tekDirectory) and (Name <> '') and (Name[Length(Name)] <> '/') then
    Name := Name + '/';
  ValidateTarEntryName(Name);
  if (LinkName <> '') and (Pos(#0, LinkName) > 0) then
    raise EArgumentError.Create('tar: linkname contains NUL');
  CutPos := 0;
  if Length(Name) > C_TAR_LEN_NAME then
  begin
    I := C_TAR_LEN_PREFIX;
    while (I >= 1) and (CutPos = 0) do
    begin
      if (I < Length(Name)) and (Name[I + 1] = '/') and (Length(Name) - I - 1 <= C_TAR_LEN_NAME) then
        CutPos := I;
      Dec(I);
    end;
  end;
  if ((Length(Name) > C_TAR_LEN_NAME) and (CutPos = 0)) or (Length(LinkName) > C_TAR_LEN_LINKNAME) then
  begin
    LPaxText := '';
    if (Length(Name) > C_TAR_LEN_NAME) and (CutPos = 0) then
      LPaxText := LPaxText + MakePaxRecord('path', Name);
    if Length(LinkName) > C_TAR_LEN_LINKNAME then
      LPaxText := LPaxText + MakePaxRecord('linkpath', LinkName);
    LPaxBytes := StringToBytes(LPaxText);
    EmitPaxHeader(LPaxBytes);
  end;
  FillChar(Block[0], SizeOf(Block), 0);
  if (Length(Name) > C_TAR_LEN_NAME) and (CutPos = 0) then
    PutText(C_TAR_OFF_NAME, C_TAR_LEN_NAME, Copy(Name, 1, C_TAR_LEN_NAME))
  else if CutPos <> 0 then
  begin
    PutText(C_TAR_OFF_PREFIX, C_TAR_LEN_PREFIX, Copy(Name, 1, CutPos));
    PutText(C_TAR_OFF_NAME, C_TAR_LEN_NAME, Copy(Name, CutPos + 2, MaxInt));
  end
  else
    PutText(C_TAR_OFF_NAME, C_TAR_LEN_NAME, Name);
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
  if Length(LinkName) > C_TAR_LEN_LINKNAME then
    PutText(C_TAR_OFF_LINKNAME, C_TAR_LEN_LINKNAME, Copy(LinkName, 1, C_TAR_LEN_LINKNAME))
  else
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
  // 单点：校验和计算委托 common，零拷贝 inline 单遍
  Sum := Integer(TarComputeChecksumUnsigned(@Block[0]));
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
