unit nextpas.core.tar.writer;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.tar.base,
  nextpas.core.io.intf;

type
  TTarWriter = class
  private
    FDst: IWriter;
    FFinished: Boolean;
    FIOBuf: PByte;
    FIOBufCap: SizeUInt;
    procedure EnsureIOBufCapacity(ANeed: SizeUInt);
    procedure WriteChecked(AData: PByte; ACount: SizeUInt); inline;
    procedure WritePadded(const AData: PByte; AUsed, ATotal: SizeUInt); inline;
    procedure MaybeReclaimIOBuf(const AHintSize: Int64); inline;
    procedure WriteBlock(const ABlock: array of Byte);
    procedure WritePaddedPayload(const AData: TBytes);
    procedure EmitPaxHeader(const APayload: TBytes);
    procedure EmitEntry(const AHdr: TTarHeader; const AData: TBytes);
    function FindPrefixCut(const AName: string): SizeInt;
    function NeedsPaxHeader(const AName, ALinkName: string; ACutPos: SizeInt): Boolean; inline;
    procedure ValidateAndCanonicalizeNames(var AName, ALinkName: string; AKind: TTarEntryKind);
    procedure EmitPaxIfNeeded(const AName, ALinkName: string; ACutPos: SizeInt);
    procedure FillNameFields(ABlock: PByte; const AName: string; ACutPos: SizeInt); inline;
    procedure FillLinkNameField(ABlock: PByte; const ALinkName: string); inline;
    procedure FillNumericFields(ABlock: PByte; const AHdr: TTarHeader; ADataSize: Int64); inline;
    procedure FillTrailerFields(ABlock: PByte; const AHdr: TTarHeader); inline;
    procedure WriteHeader(const AHdr: TTarHeader; ADataSize: Int64);
    procedure DoCopyAndPad(const AReader: IReader; ASize: Int64; ABuf: PByte; ABufCap: SizeUInt);
    procedure CopyReaderAndPad(const AReader: IReader; ASize: Int64; var ABuf: TBytes);
    procedure CopyReaderAndPadRaw(const AReader: IReader; ASize: Int64; ABuf: PByte; ABufCap: SizeUInt);
  public
    constructor Create(const ADst: IWriter);
    procedure AddEntry(const AHdr: TTarHeader; const AData: TBytes);
    procedure AddEntryWithOptions(const AName: string; const AData: TBytes; const AOpts: TTarAddOptions); overload;
    procedure AddFile(const AName: string; const AData: TBytes; AMode: Cardinal = C_TAR_DEFAULT_FILE_MODE; AMTimeUnix: Int64 = 0);
    procedure AddDir(const AName: string; AMode: Cardinal = C_TAR_DEFAULT_DIR_MODE; AMTimeUnix: Int64 = 0);
    procedure AddDirWithOptions(const AName: string; const AOpts: TTarAddOptions);
    procedure AddEntryFromReader(const AHdr: TTarHeader; const AReader: IReader);
    procedure AddEntryFromReaderWithSharedBuf(const AHdr: TTarHeader; const AReader: IReader; var ASharedBuf: TBytes);
    procedure AddEntryFromReaderWithRawBuf(const AHdr: TTarHeader; const AReader: IReader; ABuf: PByte; ABufCap: SizeUInt);
    procedure TrimIOBuf; inline;
    procedure TrimIOBufTo(const AHintSize: Int64); inline;
    procedure Finish;
    function IsFinished: Boolean; inline;
    destructor Destroy; override;
  end;

implementation

uses
  nextpas.core.exception,
  nextpas.core.bytes.ops,
  nextpas.core.bytes.builder,
  nextpas.core.tar.common,
  nextpas.core.log.intf;

const
  C_STREAM_BUF_SIZE = C_TAR_BUILDER_INITIAL_CAPACITY;
  C_STREAM_BUF_INIT = C_TAR_IOBUF_INIT;

var
  GZero512: array[0..C_TAR_BLOCK_SIZE - 1] of Byte;

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

constructor TTarWriter.Create(const ADst: IWriter);
begin
  inherited Create;
  if ADst = nil then
    raise EArgumentError.Create('tar: destination writer is nil');
  FDst := ADst;
  FIOBuf := nil;
  FIOBufCap := 0;
end;

procedure TTarWriter.EnsureIOBufCapacity(ANeed: SizeUInt);
var
  LNew: PByte;
begin
  if FIOBufCap >= ANeed then Exit;
  if FIOBuf <> nil then
    FreeMem(FIOBuf, FIOBufCap);
  GetMem(LNew, ANeed);
  FIOBuf := LNew;
  FIOBufCap := ANeed;
end;

procedure TTarWriter.WriteChecked(AData: PByte; ACount: SizeUInt); inline;
begin
  if (ACount = 0) or (AData = nil) then Exit;
  if FDst.Write(AData^, ACount) <> ACount then
    raise EIOError.Create('tar: short write');
end;

procedure TTarWriter.WritePadded(const AData: PByte; AUsed, ATotal: SizeUInt); inline;
begin
  if AUsed > 0 then
    WriteChecked(AData, AUsed);
  if ATotal > AUsed then
    WriteChecked(@GZero512[0], ATotal - AUsed);
end;

procedure TTarWriter.MaybeReclaimIOBuf(const AHintSize: Int64); inline;
var
  LNeed: SizeUInt;
  LNew: PByte;
begin
  if (FIOBuf = nil) or (FIOBufCap = 0) then Exit;
  LNeed := TarIOBufCapacityFor(AHintSize);
  if FIOBufCap > LNeed then
  begin
    if LNeed = 0 then
    begin
      FreeMem(FIOBuf, FIOBufCap);
      FIOBuf := nil;
      FIOBufCap := 0;
      Exit;
    end;
    GetMem(LNew, LNeed);
    FreeMem(FIOBuf, FIOBufCap);
    FIOBuf := LNew;
    FIOBufCap := LNeed;
  end;
end;

procedure TTarWriter.WriteBlock(const ABlock: array of Byte);
var
  Len: SizeInt;
begin
  Len := Length(ABlock);
  if Len > C_TAR_BLOCK_SIZE then
    raise EArgumentError.CreateFmt('tar: block size %d exceeds %d', [Len, C_TAR_BLOCK_SIZE]);
  if Len = C_TAR_BLOCK_SIZE then
    WriteChecked(@ABlock[0], SizeUInt(Len))
  else if Len > 0 then
    WritePadded(@ABlock[0], SizeUInt(Len), C_TAR_BLOCK_SIZE)
  else
    WritePadded(nil, 0, C_TAR_BLOCK_SIZE);
end;

procedure TTarWriter.WritePaddedPayload(const AData: TBytes);
var
  PadLen: Int64;
  TailLen, BulkLen: SizeUInt;
begin
  if Length(AData) = 0 then Exit;
  PadLen := TarPadToBlock(Length(AData));
  if PadLen = 0 then
    WriteChecked(@AData[0], SizeUInt(Length(AData)))
  else if SizeUInt(Length(AData)) <= C_TAR_BLOCK_SIZE then
    WritePadded(@AData[0], SizeUInt(Length(AData)), C_TAR_BLOCK_SIZE)
  else
  begin
    BulkLen := (SizeUInt(Length(AData)) div SizeUInt(C_TAR_BLOCK_SIZE)) * SizeUInt(C_TAR_BLOCK_SIZE);
    TailLen := SizeUInt(Length(AData)) - BulkLen;
    if BulkLen > 0 then
      WriteChecked(@AData[0], BulkLen);
    WritePadded(@AData[BulkLen], TailLen, C_TAR_BLOCK_SIZE);
  end;
end;

procedure TTarWriter.EmitPaxHeader(const APayload: TBytes);
var
  Block: array[0..C_TAR_BLOCK_SIZE - 1] of Byte;
begin
  SpanFill(TByteSpan.Create(@Block[0], SizeOf(Block)), 0);
  TarPutHeaderString(@Block[0], C_TAR_LAYOUT.Name.Off, C_TAR_LAYOUT.Name.Len, C_TAR_PAX_HEADER_NAME);
  TarFormatNumericField(@Block[0], C_TAR_LAYOUT.Mode.Off, C_TAR_LAYOUT.Mode.Len, 0);
  TarFormatNumericField(@Block[0], C_TAR_LAYOUT.UID.Off, C_TAR_LAYOUT.UID.Len, 0);
  TarFormatNumericField(@Block[0], C_TAR_LAYOUT.GID.Off, C_TAR_LAYOUT.GID.Len, 0);
  TarFormatNumericField(@Block[0], C_TAR_LAYOUT.Size.Off, C_TAR_LAYOUT.Size.Len, Length(APayload));
  TarFormatNumericField(@Block[0], C_TAR_LAYOUT.MTime.Off, C_TAR_LAYOUT.MTime.Len, 0);
  SpanFill(TByteSpan.Create(@Block[C_TAR_LAYOUT.Chksum.Off], C_TAR_LAYOUT.Chksum.Len), Ord(' '));
  Block[C_TAR_LAYOUT.TypeFlag.Off] := Ord('x');
  TarWriteUStarMagic(@Block[0]);
  TarFinalizeHeaderChecksum(@Block[0]);
  WriteBlock(Block);
  WritePaddedPayload(APayload);
end;

function TTarWriter.FindPrefixCut(const AName: string): SizeInt;
var
  I: Integer;
begin
  Result := 0;
  if Length(AName) <= C_TAR_LAYOUT.Name.Len then Exit;
  I := C_TAR_LAYOUT.Prefix.Len;
  while (I >= 1) and (Result = 0) do
  begin
    if (I < Length(AName)) and (AName[I + 1] = '/') and (Length(AName) - I - 1 <= C_TAR_LAYOUT.Name.Len) then
      Result := I;
    Dec(I);
  end;
end;

function TTarWriter.NeedsPaxHeader(const AName, ALinkName: string; ACutPos: SizeInt): Boolean; inline;
begin
  Result := ((Length(AName) > C_TAR_LAYOUT.Name.Len) and (ACutPos = 0)) or (Length(ALinkName) > C_TAR_LAYOUT.LinkName.Len);
end;

procedure TTarWriter.ValidateAndCanonicalizeNames(var AName, ALinkName: string; AKind: TTarEntryKind);
begin
  if (AKind = tekDirectory) and (AName <> '') and (AName[Length(AName)] <> '/') then
    AName := AName + '/';
  ValidateTarEntryName(AName);
  if (ALinkName <> '') and (Pos(#0, ALinkName) > 0) then
    raise EArgumentError.Create('tar: linkname contains NUL');
end;

procedure TTarWriter.EmitPaxIfNeeded(const AName, ALinkName: string; ACutPos: SizeInt);
var
  LBuilder: IBytesBuilder;
  LPaxBytes: TBytes;
begin
  if not NeedsPaxHeader(AName, ALinkName, ACutPos) then Exit;
  LBuilder := CreateBytesBuilder(256);
  if (Length(AName) > C_TAR_LAYOUT.Name.Len) and (ACutPos = 0) then
    TarAppendPaxRecord(LBuilder, 'path', AName);
  if Length(ALinkName) > C_TAR_LAYOUT.LinkName.Len then
    TarAppendPaxRecord(LBuilder, 'linkpath', ALinkName);
  LPaxBytes := LBuilder.ToBytes;
  EmitPaxHeader(LPaxBytes);
end;

procedure TTarWriter.FillNameFields(ABlock: PByte; const AName: string; ACutPos: SizeInt); inline;
begin
  if (Length(AName) > C_TAR_LAYOUT.Name.Len) and (ACutPos = 0) then
    TarPutHeaderSlice(ABlock, C_TAR_LAYOUT.Name.Off, C_TAR_LAYOUT.Name.Len, PByte(PAnsiChar(AName)), SizeUInt(C_TAR_LAYOUT.Name.Len))
  else if ACutPos <> 0 then
  begin
    TarPutHeaderSlice(ABlock, C_TAR_LAYOUT.Prefix.Off, C_TAR_LAYOUT.Prefix.Len, PByte(PAnsiChar(AName)), SizeUInt(ACutPos));
    TarPutHeaderSlice(ABlock, C_TAR_LAYOUT.Name.Off, C_TAR_LAYOUT.Name.Len, PByte(PAnsiChar(AName) + ACutPos + 1), SizeUInt(Length(AName) - ACutPos - 1));
  end
  else
    TarPutHeaderString(ABlock, C_TAR_LAYOUT.Name.Off, C_TAR_LAYOUT.Name.Len, AName);
end;

procedure TTarWriter.FillLinkNameField(ABlock: PByte; const ALinkName: string); inline;
begin
  if Length(ALinkName) > C_TAR_LAYOUT.LinkName.Len then
    TarPutHeaderSlice(ABlock, C_TAR_LAYOUT.LinkName.Off, C_TAR_LAYOUT.LinkName.Len, PByte(PAnsiChar(ALinkName)), SizeUInt(C_TAR_LAYOUT.LinkName.Len))
  else
    TarPutHeaderString(ABlock, C_TAR_LAYOUT.LinkName.Off, C_TAR_LAYOUT.LinkName.Len, ALinkName);
end;

procedure TTarWriter.FillNumericFields(ABlock: PByte; const AHdr: TTarHeader; ADataSize: Int64); inline;
begin
  TarFormatNumericField(ABlock, C_TAR_LAYOUT.Mode.Off, C_TAR_LAYOUT.Mode.Len, AHdr.Mode);
  TarFormatNumericField(ABlock, C_TAR_LAYOUT.UID.Off, C_TAR_LAYOUT.UID.Len, AHdr.UID);
  TarFormatNumericField(ABlock, C_TAR_LAYOUT.GID.Off, C_TAR_LAYOUT.GID.Len, AHdr.GID);
  if AHdr.Kind = tekRegular then
    TarFormatNumericField(ABlock, C_TAR_LAYOUT.Size.Off, C_TAR_LAYOUT.Size.Len, ADataSize)
  else
    TarFormatNumericField(ABlock, C_TAR_LAYOUT.Size.Off, C_TAR_LAYOUT.Size.Len, 0);
  TarFormatNumericField(ABlock, C_TAR_LAYOUT.MTime.Off, C_TAR_LAYOUT.MTime.Len, AHdr.MTimeUnix);
end;

procedure TTarWriter.FillTrailerFields(ABlock: PByte; const AHdr: TTarHeader); inline;
begin
  TarWriteUStarMagic(ABlock);
  TarPutHeaderString(ABlock, C_TAR_LAYOUT.UName.Off, C_TAR_LAYOUT.UName.Len, AHdr.UName);
  TarPutHeaderString(ABlock, C_TAR_LAYOUT.GName.Off, C_TAR_LAYOUT.GName.Len, AHdr.GName);
  TarFormatNumericField(ABlock, C_TAR_LAYOUT.DevMajor.Off, C_TAR_LAYOUT.DevMajor.Len, AHdr.DevMajor);
  TarFormatNumericField(ABlock, C_TAR_LAYOUT.DevMinor.Off, C_TAR_LAYOUT.DevMinor.Len, AHdr.DevMinor);
end;

procedure TTarWriter.WriteHeader(const AHdr: TTarHeader; ADataSize: Int64);
var
  Block: array[0..C_TAR_BLOCK_SIZE - 1] of Byte;
  Name, LinkName: string;
  CutPos: SizeInt;
begin
  if FFinished then
    raise EInvalidOperationError.Create('tar: writer already finished');
  if ADataSize < 0 then
    raise EArgumentError.Create('tar: negative size');
  Name := AHdr.Name;
  LinkName := AHdr.LinkName;
  ValidateAndCanonicalizeNames(Name, LinkName, AHdr.Kind);
  CutPos := FindPrefixCut(Name);
  EmitPaxIfNeeded(Name, LinkName, CutPos);
  SpanFill(TByteSpan.Create(@Block[0], SizeOf(Block)), 0);
  FillNameFields(@Block[0], Name, CutPos);
  FillNumericFields(@Block[0], AHdr, ADataSize);
  SpanFill(TByteSpan.Create(@Block[C_TAR_LAYOUT.Chksum.Off], C_TAR_LAYOUT.Chksum.Len), Ord(' '));
  Block[C_TAR_LAYOUT.TypeFlag.Off] := Byte(KindToTypeFlag(AHdr.Kind));
  FillLinkNameField(@Block[0], LinkName);
  FillTrailerFields(@Block[0], AHdr);
  TarFinalizeHeaderChecksum(@Block[0]);
  WriteBlock(Block);
end;

procedure TTarWriter.EmitEntry(const AHdr: TTarHeader; const AData: TBytes); inline;
begin
  WriteHeader(AHdr, Length(AData));
  if (AHdr.Kind = tekRegular) and (Length(AData) > 0) then
    WritePaddedPayload(AData);
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

procedure TTarWriter.AddDirWithOptions(const AName: string; const AOpts: TTarAddOptions);
var
  H: TTarHeader;
  LDef: TTarAddOptions;
begin
  LDef := DefaultTarAddOptions;
  H := Default(TTarHeader);
  H.Name := AName;
  H.Kind := tekDirectory;
  if AOpts.Mode = LDef.Mode then
    H.Mode := C_TAR_DEFAULT_DIR_MODE
  else
    H.Mode := TarDirectoryMode(AOpts.Mode and C_TAR_UNIX_PERM_MASK);
  H.UID := AOpts.UID;
  H.GID := AOpts.GID;
  H.MTimeUnix := AOpts.MTimeUnix;
  H.UName := AOpts.UName;
  H.GName := AOpts.GName;
  EmitEntry(H, nil);
end;

procedure TTarWriter.DoCopyAndPad(const AReader: IReader; ASize: Int64; ABuf: PByte; ABufCap: SizeUInt);
var
  LRead, LToRead: SizeUInt;
  LRemaining: Int64;
  PadLen: Int64;
begin
  if ASize = 0 then Exit;
  if (ABuf = nil) or (ABufCap = 0) then
    raise EArgumentError.Create('tar: buffer is nil');
  LRemaining := ASize;
  while LRemaining > 0 do
  begin
    LToRead := SizeUInt(LRemaining);
    if LToRead > ABufCap then LToRead := ABufCap;
    LRead := AReader.Read(ABuf^, LToRead);
    if LRead = 0 then raise EIOError.Create('tar: short read');
    WriteChecked(ABuf, LRead);
    Dec(LRemaining, Int64(LRead));
  end;
  PadLen := TarPadToBlock(ASize);
  if PadLen > 0 then
    WritePadded(nil, 0, SizeUInt(PadLen));
end;

procedure TTarWriter.CopyReaderAndPad(const AReader: IReader; ASize: Int64; var ABuf: TBytes);
var
  LNeed: SizeUInt;
begin
  if ASize = 0 then Exit;
  LNeed := TarIOBufCapacityFor(ASize);
  if SizeUInt(Length(ABuf)) < LNeed then
    SetLength(ABuf, LNeed);
  DoCopyAndPad(AReader, ASize, @ABuf[0], SizeUInt(Length(ABuf)));
end;

procedure TTarWriter.CopyReaderAndPadRaw(const AReader: IReader; ASize: Int64; ABuf: PByte; ABufCap: SizeUInt);
begin
  DoCopyAndPad(AReader, ASize, ABuf, ABufCap);
end;

procedure TTarWriter.AddEntryFromReader(const AHdr: TTarHeader; const AReader: IReader);
var
  LNeed: SizeUInt;
begin
  if FFinished then
    raise EInvalidOperationError.Create('tar: writer already finished');
  if AHdr.Kind <> tekRegular then
  begin
    WriteHeader(AHdr, 0);
    Exit;
  end;
  if AHdr.Size < 0 then
    raise EArgumentError.Create('tar: negative size');
  if (AHdr.Size > 0) and (AReader = nil) then
    raise EArgumentError.Create('tar: reader is nil');
  WriteHeader(AHdr, AHdr.Size);
  if AHdr.Size = 0 then Exit;
  LNeed := TarIOBufCapacityFor(AHdr.Size);
  EnsureIOBufCapacity(LNeed);
  DoCopyAndPad(AReader, AHdr.Size, FIOBuf, FIOBufCap);
  MaybeReclaimIOBuf(AHdr.Size);
end;

procedure TTarWriter.AddEntryFromReaderWithSharedBuf(const AHdr: TTarHeader; const AReader: IReader; var ASharedBuf: TBytes);
begin
  if FFinished then
    raise EInvalidOperationError.Create('tar: writer already finished');
  if AHdr.Kind <> tekRegular then
  begin
    WriteHeader(AHdr, 0);
    Exit;
  end;
  if AHdr.Size < 0 then
    raise EArgumentError.Create('tar: negative size');
  if (AHdr.Size > 0) and (AReader = nil) then
    raise EArgumentError.Create('tar: reader is nil');
  WriteHeader(AHdr, AHdr.Size);
  if AHdr.Size = 0 then Exit;
  CopyReaderAndPad(AReader, AHdr.Size, ASharedBuf);
end;

procedure TTarWriter.AddEntryFromReaderWithRawBuf(const AHdr: TTarHeader; const AReader: IReader; ABuf: PByte; ABufCap: SizeUInt);
begin
  if FFinished then raise EInvalidOperationError.Create('tar: writer already finished');
  if AHdr.Kind <> tekRegular then begin WriteHeader(AHdr, 0); Exit; end;
  if AHdr.Size < 0 then raise EArgumentError.Create('tar: negative size');
  if (AHdr.Size > 0) and (AReader = nil) then raise EArgumentError.Create('tar: reader is nil');
  WriteHeader(AHdr, AHdr.Size);
  if AHdr.Size = 0 then Exit;
  CopyReaderAndPadRaw(AReader, AHdr.Size, ABuf, ABufCap);
end;

procedure TTarWriter.TrimIOBuf; inline;
begin
  MaybeReclaimIOBuf(0);
end;

procedure TTarWriter.TrimIOBufTo(const AHintSize: Int64); inline;
begin
  MaybeReclaimIOBuf(AHintSize);
end;

procedure TTarWriter.Finish;
var
  Zero: array[0..C_TAR_BLOCK_SIZE - 1] of Byte;
begin
  if FFinished then Exit;
  FFinished := True;
  SpanFill(TByteSpan.Create(@Zero[0], SizeOf(Zero)), 0);
  WriteBlock(Zero);
  WriteBlock(Zero);
  if FIOBuf <> nil then
  begin
    FreeMem(FIOBuf, FIOBufCap);
    FIOBuf := nil;
    FIOBufCap := 0;
  end;
end;

function TTarWriter.IsFinished: Boolean; inline;
begin
  Result := FFinished;
end;

destructor TTarWriter.Destroy;
begin
  try
    if not FFinished then
    begin
      NullLogger.Warn('tar: writer destroyed without Finish (missing two zero blocks, data truncated)');
      try
        Finish;
      except
        on E: Exception do
          NullLogger.Warn('tar: writer destroy suppress finish failure');
      end;
    end;
  finally
    if FIOBuf <> nil then
    begin
      FreeMem(FIOBuf, FIOBufCap);
      FIOBuf := nil;
      FIOBufCap := 0;
    end;
    FDst := nil;
    inherited Destroy;
  end;
end;

end.
