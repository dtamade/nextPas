unit nextpas.core.tar.writer;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.tar.base,
  nextpas.core.io.intf,
  nextpas.core.log.intf;

type
  {** @desc Tar 写器：以 IWriter 为目标产出 ustar 流（两零块收尾，可对接 gzip）。 *}
  TTarWriter = class
  private
    FDst: IWriter;
    FFinished: Boolean;
    FIOBuf: TBytes; // pooled 64K, bytes.ops single source, released on Finish
    FLogger: ILogger; // L0 single seam可观测（NullLogger默认零分配），不直触System.StdErr，平台抽象克制，复用builder同款
    procedure WriteBlock(const ABlock: array of Byte);
    procedure WritePaddedPayload(const AData: TBytes);
    procedure EmitPaxHeader(const APayload: TBytes);
    procedure EmitEntry(const AHdr: TTarHeader; const AData: TBytes);
    procedure WriteHeader(const AHdr: TTarHeader; ADataSize: Int64);
  public
    constructor Create(const ADst: IWriter);
    procedure AddEntry(const AHdr: TTarHeader; const AData: TBytes);
    procedure AddEntryWithOptions(const AName: string; const AData: TBytes; const AOpts: TTarAddOptions); overload;
    procedure AddFile(const AName: string; const AData: TBytes; AMode: Cardinal = C_TAR_DEFAULT_FILE_MODE; AMTimeUnix: Int64 = 0);
    procedure AddDir(const AName: string; AMode: Cardinal = C_TAR_DEFAULT_DIR_MODE; AMTimeUnix: Int64 = 0);
    procedure AddDirWithOptions(const AName: string; const AOpts: TTarAddOptions);
    procedure AddEntryFromReader(const AHdr: TTarHeader; const AReader: IReader);
    procedure Finish;
    function IsFinished: Boolean; inline;
    destructor Destroy; override;
  end;

implementation

uses
  nextpas.core.exception,
  nextpas.core.bytes.ops,
  nextpas.core.bytes.builder,
  nextpas.core.tar.common;

const
  C_STREAM_BUF_SIZE = 65536;

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

{ — pax 记录委托 common — }

{ TTarWriter }

constructor TTarWriter.Create(const ADst: IWriter);
begin
  inherited Create;
  if ADst = nil then
    raise EArgumentError.Create('tar: destination writer is nil');
  FDst := ADst;
  FLogger := NullLogger(); // L2经log.intf单缝可观测，默认no-op零分配inline薄转发，无StdErr直触，复用builder单源
end;

procedure TTarWriter.WriteBlock(const ABlock: array of Byte);
var
  Pad: array[0..C_TAR_BLOCK_SIZE - 1] of Byte;
  Len: SizeInt;
  PadLen: SizeUInt;
begin
  // no inline: 512B stack Pad minimal zero, bytes.ops single source zero-copy direct Write tail+pad (was extra 512 copy)
  // >512 raises; caller owns resources
  Len := Length(ABlock);
  if Len > C_TAR_BLOCK_SIZE then
    raise EArgumentError.CreateFmt('tar: block size %d exceeds %d', [Len, C_TAR_BLOCK_SIZE]);
  if Len = C_TAR_BLOCK_SIZE then
  begin
    if FDst.Write(ABlock[0], SizeUInt(Len)) <> SizeUInt(Len) then
      raise EIOError.Create('tar: short write');
  end
  else
  begin
    // perf: zero-copy direct Write data slice, FillChar only PadLen minimal zero (was 512), two Writes avoid 512B extra CopyMemory
    if Len > 0 then
      if FDst.Write(ABlock[0], SizeUInt(Len)) <> SizeUInt(Len) then
        raise EIOError.Create('tar: short write');
    PadLen := SizeUInt(C_TAR_BLOCK_SIZE - Len);
    FillChar(Pad[0], PadLen, 0);
    if FDst.Write(Pad[0], PadLen) <> PadLen then
      raise EIOError.Create('tar: short write');
  end;
end;

procedure TTarWriter.WritePaddedPayload(const AData: TBytes);
var
  Pad: array[0..C_TAR_BLOCK_SIZE - 1] of Byte;
  PadLen: Int64;
  TailLen, BulkLen: SizeUInt;
begin
  // no inline: Bulk/Tail+Pad three branches, avoid I-Cache copy bloat per design-conventions; bytes.ops single source, zero-copy
  if Length(AData) = 0 then
    Exit;
  PadLen := TarPadToBlock(Length(AData));
  if PadLen = 0 then
  begin
    if FDst.Write(AData[0], SizeUInt(Length(AData))) <> SizeUInt(Length(AData)) then
      raise EIOError.Create('tar: short write');
  end
  else if SizeUInt(Length(AData)) <= C_TAR_BLOCK_SIZE then
  begin
    // perf: zero-copy direct Write tail, FillChar only PadLen (was 512) minimal zero, inline single source bytes.ops avoided copy
    if FDst.Write(AData[0], SizeUInt(Length(AData))) <> SizeUInt(Length(AData)) then
      raise EIOError.Create('tar: short write');
    FillChar(Pad[0], SizeUInt(PadLen), 0);
    if FDst.Write(Pad[0], SizeUInt(PadLen)) <> SizeUInt(PadLen) then
      raise EIOError.Create('tar: short write');
  end
  else
  begin
    // perf: Bulk zero-copy, Tail zero-copy direct slice, FillChar only PadLen (was 512) minimal zero, bytes.ops single source kept for data path
    BulkLen := (SizeUInt(Length(AData)) div SizeUInt(C_TAR_BLOCK_SIZE)) * SizeUInt(C_TAR_BLOCK_SIZE);
    TailLen := SizeUInt(Length(AData)) - BulkLen;
    if BulkLen > 0 then
      if FDst.Write(AData[0], BulkLen) <> BulkLen then
        raise EIOError.Create('tar: short write');
    if TailLen > 0 then
      if FDst.Write(AData[BulkLen], TailLen) <> TailLen then
        raise EIOError.Create('tar: short write');
    FillChar(Pad[0], SizeUInt(PadLen), 0);
    if FDst.Write(Pad[0], SizeUInt(PadLen)) <> SizeUInt(PadLen) then
      raise EIOError.Create('tar: short write');
  end;
end;

procedure TTarWriter.EmitPaxHeader(const APayload: TBytes);
var
  Block: array[0..C_TAR_BLOCK_SIZE - 1] of Byte;
begin
  FillChar(Block[0], SizeOf(Block), 0);
  TarPutHeaderString(@Block[0], C_TAR_LAYOUT.Name.Off, C_TAR_LAYOUT.Name.Len, C_TAR_PAX_HEADER_NAME);
  TarFormatNumericField(@Block[0], C_TAR_LAYOUT.Mode.Off, C_TAR_LAYOUT.Mode.Len, 0);
  TarFormatNumericField(@Block[0], C_TAR_LAYOUT.UID.Off, C_TAR_LAYOUT.UID.Len, 0);
  TarFormatNumericField(@Block[0], C_TAR_LAYOUT.GID.Off, C_TAR_LAYOUT.GID.Len, 0);
  TarFormatNumericField(@Block[0], C_TAR_LAYOUT.Size.Off, C_TAR_LAYOUT.Size.Len, Length(APayload));
  TarFormatNumericField(@Block[0], C_TAR_LAYOUT.MTime.Off, C_TAR_LAYOUT.MTime.Len, 0);
  FillChar(Block[C_TAR_LAYOUT.Chksum.Off], C_TAR_LAYOUT.Chksum.Len, Ord(' '));
  Block[C_TAR_LAYOUT.TypeFlag.Off] := Ord('x');
  TarWriteUStarMagic(@Block[0]);
  TarFinalizeHeaderChecksum(@Block[0]);
  WriteBlock(Block);
  // bytes.ops single source, inline
  WritePaddedPayload(APayload);
end;

procedure TTarWriter.WriteHeader(const AHdr: TTarHeader; ADataSize: Int64);
var
  Block: array[0..C_TAR_BLOCK_SIZE - 1] of Byte;
  Name, LinkName: string;
  CutPos: SizeInt;
  LPaxBytes: TBytes;
  LBuilder: IBytesBuilder;
  I: Integer;
begin
  if FFinished then
    raise EInvalidOperationError.Create('tar: writer already finished');
  if ADataSize < 0 then
    raise EArgumentError.Create('tar: negative size');
  Name := AHdr.Name;
  LinkName := AHdr.LinkName;
  if (AHdr.Kind = tekDirectory) and (Name <> '') and (Name[Length(Name)] <> '/') then
    Name := Name + '/';
  ValidateTarEntryName(Name);
  if (LinkName <> '') and (Pos(#0, LinkName) > 0) then
    raise EArgumentError.Create('tar: linkname contains NUL');
  CutPos := 0;
  if Length(Name) > C_TAR_LAYOUT.Name.Len then
  begin
    I := C_TAR_LAYOUT.Prefix.Len;
    while (I >= 1) and (CutPos = 0) do
    begin
      if (I < Length(Name)) and (Name[I + 1] = '/') and (Length(Name) - I - 1 <= C_TAR_LAYOUT.Name.Len) then
        CutPos := I;
      Dec(I);
    end;
  end;
  if ((Length(Name) > C_TAR_LAYOUT.Name.Len) and (CutPos = 0)) or (Length(LinkName) > C_TAR_LAYOUT.LinkName.Len) then
  begin
    LBuilder := CreateBytesBuilder(256);
    if (Length(Name) > C_TAR_LAYOUT.Name.Len) and (CutPos = 0) then
      TarAppendPaxRecord(LBuilder, 'path', Name);
    if Length(LinkName) > C_TAR_LAYOUT.LinkName.Len then
      TarAppendPaxRecord(LBuilder, 'linkpath', LinkName);
    LPaxBytes := LBuilder.ToBytes;
    EmitPaxHeader(LPaxBytes);
  end;
  FillChar(Block[0], SizeOf(Block), 0);
  if (Length(Name) > C_TAR_LAYOUT.Name.Len) and (CutPos = 0) then
    // bytes.ops single source, zero-copy slice
    TarPutHeaderSlice(@Block[0], C_TAR_LAYOUT.Name.Off, C_TAR_LAYOUT.Name.Len, PByte(PAnsiChar(Name)), SizeUInt(C_TAR_LAYOUT.Name.Len))
  else if CutPos <> 0 then
  begin
    // bytes.ops single source, zero-copy slice
    TarPutHeaderSlice(@Block[0], C_TAR_LAYOUT.Prefix.Off, C_TAR_LAYOUT.Prefix.Len, PByte(PAnsiChar(Name)), SizeUInt(CutPos));
    TarPutHeaderSlice(@Block[0], C_TAR_LAYOUT.Name.Off, C_TAR_LAYOUT.Name.Len, PByte(PAnsiChar(Name) + CutPos + 1), SizeUInt(Length(Name) - CutPos - 1));
  end
  else
    TarPutHeaderString(@Block[0], C_TAR_LAYOUT.Name.Off, C_TAR_LAYOUT.Name.Len, Name);
  TarFormatNumericField(@Block[0], C_TAR_LAYOUT.Mode.Off, C_TAR_LAYOUT.Mode.Len, AHdr.Mode);
  TarFormatNumericField(@Block[0], C_TAR_LAYOUT.UID.Off, C_TAR_LAYOUT.UID.Len, AHdr.UID);
  TarFormatNumericField(@Block[0], C_TAR_LAYOUT.GID.Off, C_TAR_LAYOUT.GID.Len, AHdr.GID);
  if AHdr.Kind = tekRegular then
    TarFormatNumericField(@Block[0], C_TAR_LAYOUT.Size.Off, C_TAR_LAYOUT.Size.Len, ADataSize)
  else
    TarFormatNumericField(@Block[0], C_TAR_LAYOUT.Size.Off, C_TAR_LAYOUT.Size.Len, 0);
  TarFormatNumericField(@Block[0], C_TAR_LAYOUT.MTime.Off, C_TAR_LAYOUT.MTime.Len, AHdr.MTimeUnix);
  FillChar(Block[C_TAR_LAYOUT.Chksum.Off], C_TAR_LAYOUT.Chksum.Len, Ord(' '));
  Block[C_TAR_LAYOUT.TypeFlag.Off] := Byte(KindToTypeFlag(AHdr.Kind));
  if Length(LinkName) > C_TAR_LAYOUT.LinkName.Len then
    // bytes.ops single source, zero-copy slice
    TarPutHeaderSlice(@Block[0], C_TAR_LAYOUT.LinkName.Off, C_TAR_LAYOUT.LinkName.Len, PByte(PAnsiChar(LinkName)), SizeUInt(C_TAR_LAYOUT.LinkName.Len))
  else
    TarPutHeaderString(@Block[0], C_TAR_LAYOUT.LinkName.Off, C_TAR_LAYOUT.LinkName.Len, LinkName);
  TarWriteUStarMagic(@Block[0]);
  TarPutHeaderString(@Block[0], C_TAR_LAYOUT.UName.Off, C_TAR_LAYOUT.UName.Len, AHdr.UName);
  TarPutHeaderString(@Block[0], C_TAR_LAYOUT.GName.Off, C_TAR_LAYOUT.GName.Len, AHdr.GName);
  // bytes.ops single source
  TarFormatNumericField(@Block[0], C_TAR_LAYOUT.DevMajor.Off, C_TAR_LAYOUT.DevMajor.Len, AHdr.DevMajor);
  TarFormatNumericField(@Block[0], C_TAR_LAYOUT.DevMinor.Off, C_TAR_LAYOUT.DevMinor.Len, AHdr.DevMinor);
  TarFinalizeHeaderChecksum(@Block[0]);
  WriteBlock(Block);
end;

procedure TTarWriter.EmitEntry(const AHdr: TTarHeader; const AData: TBytes); inline;
begin
  // bytes.ops single source, inline
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
  // 单源：DefaultTarAddOptions 判零 + TarDirectoryMode 单点换算目录权限，零拷贝无需 bytes.ops；收敛三分支+二次 IFDIR 归一至单点，极简叙事
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

procedure TTarWriter.AddEntryFromReader(const AHdr: TTarHeader; const AReader: IReader);
var
  LRead, LToRead, LBufSize: SizeUInt;
  LRemaining: Int64;
  PadBlock: array[0..C_TAR_BLOCK_SIZE - 1] of Byte;
  PadLen: Int64;
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
  // bytes.ops single source, inline
  WriteHeader(AHdr, AHdr.Size);
  if AHdr.Size = 0 then
    Exit;
  // pooled 64K FIOBuf, bytes.ops single source; lifecycle bound to Finish (released on Finish, amortized 1 alloc)
  // perf: pooled reuse via CopyMemory zero-copy (bytes.ops single source), inline thin forwarding; exception-safe, no leak
  LBufSize := SizeUInt(AHdr.Size);
  if LBufSize > C_STREAM_BUF_SIZE then
    LBufSize := C_STREAM_BUF_SIZE;
  if Length(FIOBuf) < SizeInt(LBufSize) then
    SetLength(FIOBuf, LBufSize);
  LRemaining := AHdr.Size;
  while LRemaining > 0 do
  begin
    LToRead := SizeUInt(LRemaining);
    if LToRead > SizeUInt(Length(FIOBuf)) then
      LToRead := SizeUInt(Length(FIOBuf));
    LRead := AReader.Read(FIOBuf[0], LToRead);
    if LRead = 0 then
      raise EIOError.Create('tar: short read');
    if FDst.Write(FIOBuf[0], LRead) <> LRead then
      raise EIOError.Create('tar: short write');
    Dec(LRemaining, Int64(LRead));
  end;
  PadLen := TarPadToBlock(AHdr.Size);
  if PadLen > 0 then
  begin
    FillChar(PadBlock[0], SizeOf(PadBlock), 0);
    if FDst.Write(PadBlock[0], SizeUInt(PadLen)) <> SizeUInt(PadLen) then
      raise EIOError.Create('tar: short write');
  end;
end;

procedure TTarWriter.Finish;
var
  Zero: array[0..C_TAR_BLOCK_SIZE - 1] of Byte;
begin
  if FFinished then
    Exit;
  FFinished := True;
  try
    FillChar(Zero[0], SizeOf(Zero), 0);
    WriteBlock(Zero);
    WriteBlock(Zero);
  finally
    // release pooled 64K immediately, avoid linger peak Finish->Free (continuous reuse saves 64K)
    FIOBuf := nil;
  end;
end;

function TTarWriter.IsFinished: Boolean; inline;
begin
  Result := FFinished;
end;

destructor TTarWriter.Destroy;
var
  LUnwinding: Boolean;
begin
  // fail-closed: IsExceptionUnwinding判unwind期抑制次生以保原始异常上下文并经log.intf ILogger.Warn单源薄转发（NullLogger no-op零拷贝inline），非unwind期硬失败透传Finish异常防缺两零块截断静默丢数据（EIOError/short-write透传）；bytes.ops单源retained；FIOBuf于Finish即释+析构finally双保险无linger峰值；try..finally必释，复用builder同款LUnwinding单源
  LUnwinding := IsExceptionUnwinding;
  try
    if not FFinished then
    begin
      if LUnwinding then
      begin
        try
          Finish;
        except
          // unwind期抑制次生以保原始异常上下文，不透传
        end;
        // unwind期仅可观测，不抛次生覆盖原始异常；L2经log.intf单缝，无RTL控制台直触，NullLogger零分配inline薄转发
        if FLogger <> nil then
          FLogger.Warn('tar: writer destroyed without Finish (missing two zero blocks, data truncated)');
      end
      else
        Finish; // 非unwind硬失败：透传EIOError/short-write，fail-closed防截断
    end;
  finally
    FIOBuf := nil;
    FDst := nil;
    FLogger := nil;
    inherited Destroy;
  end;
end;

end.
