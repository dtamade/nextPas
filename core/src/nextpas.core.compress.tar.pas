unit nextpas.core.compress.tar;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.io.intf;

{ Tar archive codec (POSIX ustar writer; reader also understands GNU
  longname 'L'/'K', pax 'x'/'g' path/linkpath overrides and GNU base-256
  numeric fields). Errors follow the family convention: EIOError. }

type
  TTarEntryKind = (
    tekRegular, tekHardLink, tekSymlink, tekCharDevice, tekBlockDevice,
    tekDirectory, tekFifo);

  TTarHeader = record
    Name: string;
    LinkName: string;
    Kind: TTarEntryKind;
    Mode: Cardinal;
    UID: Cardinal;
    GID: Cardinal;
    Size: Int64;
    MTimeUnix: Int64;
    UName: string;
    GName: string;
  end;

  { Iterates entries of a tar image held in memory. The pointer overload
    accepts externally owned memory (e.g. io.mapped regions); it must stay
    valid while the reader is used. }
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
    { Advances to the next real entry; False at end of archive }
    function Next(out AHeader: TTarHeader): Boolean;
    { Payload bytes of the current entry (valid after Next = True) }
    function EntryData: TBytes;
    function EntryDataOfs: SizeUInt;
  end;

  { Writes a ustar stream to an arbitrary sink }
  TTarWriter = class
  private
    FDst: IWriter;
    FFinished: Boolean;
    procedure WriteBlock(const ABlock: array of Byte);
    procedure EmitEntry(const AHdr: TTarHeader; const AData: TBytes);
  public
    constructor Create(const ADst: IWriter);
    { Generic entry; AData is used for tekRegular only }
    procedure AddEntry(const AHdr: TTarHeader; const AData: TBytes);
    procedure AddFile(const AName: string; const AData: TBytes;
      AMode: Cardinal = $1A4; AMTimeUnix: Int64 = 0);
    procedure AddDir(const AName: string; AMode: Cardinal = $1ED;
      AMTimeUnix: Int64 = 0);
    { Two zero blocks; called automatically from Destroy if omitted }
    procedure Finish;
    destructor Destroy; override;
  end;

implementation

uses
  nextpas.core.errors;

const
  CBlockSize = 512;

function PadToBlock(ASize: Int64): Int64;
begin
  Result := (CBlockSize - (ASize mod CBlockSize)) mod CBlockSize;
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
    raise EIOError.CreateFmt('tar: unsupported type flag "%c"',
      [Chr(AFlag)]);
  end;
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

{ TTarReader }

constructor TTarReader.Create(const AData: TBytes);
begin
  inherited Create;
  FBuf := AData;
  if Length(AData) > 0 then
    FData := @AData[0]
  else
    FData := nil;
  FCount := SizeUInt(Length(AData));
  FPos := 0;
end;

constructor TTarReader.Create(AData: PByte; ACount: SizeUInt);
begin
  inherited Create;
  FData := AData;
  FCount := ACount;
  FPos := 0;
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
  // GNU base-256 extension for values that do not fit octal
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
        // per-entry overrides win over global ones; stash accordingly
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
      FillChar(AHeader, SizeOf(AHeader), 0);
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
      if AHeader.Kind = tekRegular then
        FEntrySize := Size
      else
        FEntrySize := 0;
      FEntryDataOfs := FPos + CBlockSize;
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
  N := SizeInt(FEntrySize);
  SetLength(Result, N);
  Move(FData[FEntryDataOfs], Result[0], N);
end;

function TTarReader.EntryDataOfs: SizeUInt;
begin
  Result := FEntryDataOfs;
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
  Zero: array[0..CBlockSize - 1] of Byte;
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
    if FDst.Write(Zero[0], SizeUInt(CBlockSize - Len))
      <> SizeUInt(CBlockSize - Len) then
      raise EIOError.Create('tar: short write');
  end;
end;

procedure TTarWriter.EmitEntry(const AHdr: TTarHeader; const AData: TBytes);
var
  Block: array[0..CBlockSize - 1] of Byte;
  PadBlock: array[0..CBlockSize - 1] of Byte;
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
    // GNU base-256 escape when the value exceeds the octal capacity
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
  FillChar(Block[0], SizeOf(Block), 0);
  Name := AHdr.Name;
  LinkName := AHdr.LinkName;
  if (AHdr.Kind = tekDirectory) and (Name <> '')
    and (Name[Length(Name)] <> '/') then
    Name := Name + '/';
  PutText(0, 100, Name);
  if Length(Name) > 100 then
  begin
    // ustar prefix split: largest cut at '/' keeping suffix <= 100
    CutPos := 0;
    I := 155;
    while (I >= 1) and (CutPos = 0) do
    begin
      if (I < Length(Name)) and (Name[I + 1] = '/')
        and (Length(Name) - I - 1 <= 100) then
        CutPos := I;
      Dec(I);
    end;
    if CutPos = 0 then
      raise EIOError.Create('tar: entry name too long for ustar');
    // ustar composes the full path as prefix + '/' + name; clear the short
    // name bytes first so the truncated full name cannot leak through
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
  // POSIX ustar layout: magic "ustar\0" at 257 (6 bytes), version "00" at 263;
  // any other magic makes readers ignore the prefix field entirely
  Block[262] := 0;
  Block[263] := Ord('0');
  Block[264] := Ord('0');
  PutText(265, 32, AHdr.UName);
  PutText(297, 32, AHdr.GName);
  Sum := 0;
  for I := 0 to CBlockSize - 1 do
    Sum := Sum + Block[I];
  // classic layout: 6 octal digits at 148..153, NUL at 154, space at 155
  for I := 0 to 5 do
    Block[148 + I] := Byte(Ord('0') + ((Sum shr ((5 - I) * 3)) and 7));
  Block[154] := 0;
  Block[155] := Ord(' ');
  WriteBlock(Block);
  if (AHdr.Kind = tekRegular) and (Length(AData) > 0) then
  begin
    if FDst.Write(AData[0], SizeUInt(Length(AData)))
      <> SizeUInt(Length(AData)) then
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

procedure TTarWriter.AddFile(const AName: string; const AData: TBytes;
  AMode: Cardinal; AMTimeUnix: Int64);
var
  H: TTarHeader;
begin
  FillChar(H, SizeOf(H), 0);
  H.Name := AName;
  H.Kind := tekRegular;
  H.Mode := AMode;
  H.MTimeUnix := AMTimeUnix;
  H.Size := Length(AData);
  EmitEntry(H, AData);
end;

procedure TTarWriter.AddDir(const AName: string; AMode: Cardinal;
  AMTimeUnix: Int64);
var
  H: TTarHeader;
begin
  FillChar(H, SizeOf(H), 0);
  H.Name := AName;
  H.Kind := tekDirectory;
  H.Mode := AMode;
  H.MTimeUnix := AMTimeUnix;
  EmitEntry(H, nil);
end;

procedure TTarWriter.Finish;
var
  Zero: array[0..CBlockSize - 1] of Byte;
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
