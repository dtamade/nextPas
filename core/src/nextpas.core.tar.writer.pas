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
    procedure AddFile(const AName: string; const AData: TBytes; AMode: Cardinal = $1A4; AMTimeUnix: Int64 = 0);
    procedure AddDir(const AName: string; AMode: Cardinal = $1ED; AMTimeUnix: Int64 = 0);
    procedure Finish;
    destructor Destroy; override;
  end;

implementation

uses
  nextpas.core.exception,
  nextpas.core.tar.common;

const
  CBlockSize = C_TAR_BLOCK_SIZE;

function PadToBlock(ASize: Int64): Int64; inline;
begin
  Result := TarPadToBlock(ASize);
end;

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
  begin
    if AValue >= (Int64(1) shl ((ALen - 1) * 3)) then
    begin
      Block[AOfs] := $80;
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
  PutText(0, 100, Name);
  if Length(Name) > 100 then
  begin
    CutPos := 0;
    I := 155;
    while (I >= 1) and (CutPos = 0) do
    begin
      if (I < Length(Name)) and (Name[I + 1] = '/') and (Length(Name) - I - 1 <= 100) then
        CutPos := I;
      Dec(I);
    end;
    if CutPos = 0 then
      raise EIOError.Create('tar: entry name too long for ustar');
    FillChar(Block[0], 100, 0);
    PutText(345, 155, Copy(Name, 1, CutPos));
    PutText(0, 100, Copy(Name, CutPos + 2, MaxInt));
  end;
  PutOctal(100, 8, AHdr.Mode);
  PutOctal(108, 8, AHdr.UID);
  PutOctal(116, 8, AHdr.GID);
  if AHdr.Kind = tekRegular then
    PutOctal(124, 12, Length(AData))
  else
    PutOctal(124, 12, 0);
  PutOctal(136, 12, AHdr.MTimeUnix);
  FillChar(Block[148], 8, Ord(' '));
  Block[156] := Byte(KindToTypeFlag(AHdr.Kind));
  PutText(157, 100, LinkName);
  Block[257] := Ord('u');
  Block[258] := Ord('s');
  Block[259] := Ord('t');
  Block[260] := Ord('a');
  Block[261] := Ord('r');
  Block[262] := 0;
  Block[263] := Ord('0');
  Block[264] := Ord('0');
  PutText(265, 32, AHdr.UName);
  PutText(297, 32, AHdr.GName);
  Sum := 0;
  for I := 0 to CBlockSize - 1 do
    Sum := Sum + Block[I];
  for I := 0 to 5 do
    Block[148 + I] := Byte(Ord('0') + ((Sum shr ((5 - I) * 3)) and 7));
  Block[154] := 0;
  Block[155] := Ord(' ');
  WriteBlock(Block);
  if (AHdr.Kind = tekRegular) and (Length(AData) > 0) then
  begin
    if FDst.Write(AData[0], SizeUInt(Length(AData))) <> SizeUInt(Length(AData)) then
      raise EIOError.Create('tar: short write');
    PadLen := PadToBlock(Length(AData));
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
    H.Mode := $1A4;
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
