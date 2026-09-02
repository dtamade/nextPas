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
    FIOBuf: TBytes; // pooled IO buffer for AddEntryFromReader: cross-entry reuse via TarIOBufCapacityFor, grows on demand, precise reclaim via TarIOBufCapacityFor/TrimIOBuf after short batch, released on Finish/Destroy (try..finally 必释，无长滞留)，inline zero-copy
    procedure WriteChecked(AData: PByte; ACount: SizeUInt); inline;
    procedure WritePadded(const AData: PByte; AUsed, ATotal: SizeUInt); inline;
    procedure MaybeReclaimIOBuf(const AHintSize: Int64); inline;
    procedure WriteBlock(const ABlock: array of Byte);
    procedure WritePaddedPayload(const AData: TBytes);
    procedure EmitPaxHeader(const APayload: TBytes);
    procedure EmitEntry(const AHdr: TTarHeader; const AData: TBytes);
    // WriteHeader 优雅拆分：单职责小函数，复用 bytes.ops 单源，薄路径 inline 零拷贝
    function FindPrefixCut(const AName: string): SizeInt;
    function NeedsPaxHeader(const AName, ALinkName: string; ACutPos: SizeInt): Boolean; inline;
    procedure ValidateAndCanonicalizeNames(var AName, ALinkName: string; AKind: TTarEntryKind);
    procedure EmitPaxIfNeeded(const AName, ALinkName: string; ACutPos: SizeInt);
    procedure FillNameFields(ABlock: PByte; const AName: string; ACutPos: SizeInt); inline;
    procedure FillLinkNameField(ABlock: PByte; const ALinkName: string); inline;
    procedure FillNumericFields(ABlock: PByte; const AHdr: TTarHeader; ADataSize: Int64); inline;
    procedure FillTrailerFields(ABlock: PByte; const AHdr: TTarHeader); inline;
    procedure WriteHeader(const AHdr: TTarHeader; ADataSize: Int64);
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
end;

procedure PadCopy(ASrc, ADst: PByte; AUsed, ATotal: SizeUInt); inline;
begin
  // bytes.ops single source CopyMemory+SpanFill/MemSet single seam, inline zero-copy TByteSpan view, minimal pad, 单缝纯度收敛（消除 FillChar 分叉）
  if (AUsed > 0) and (ASrc <> nil) and (ADst <> nil) then
    CopyMemory(ASrc, ADst, AUsed);
  if (ATotal > AUsed) and (ADst <> nil) then
    SpanFill(TByteSpan.Create(ADst + AUsed, ATotal - AUsed), 0);
end;

procedure TTarWriter.WriteChecked(AData: PByte; ACount: SizeUInt); inline;
begin
  // single source short-write guard, inline thin forward, zero-copy PByte single source
  if (ACount = 0) or (AData = nil) then
    Exit;
  if FDst.Write(AData^, ACount) <> ACount then
    raise EIOError.Create('tar: short write');
end;

procedure TTarWriter.WritePadded(const AData: PByte; AUsed, ATotal: SizeUInt); inline;
var
  Pad: array[0..C_TAR_BLOCK_SIZE - 1] of Byte;
begin
  // single source pad write helper: PadCopy (bytes.ops CopyMemory+SpanFill single seam) + single WriteChecked, inline zero-copy, eliminates WriteBlock/WritePaddedPayload 512-block duplicate pad paths
  PadCopy(AData, @Pad[0], AUsed, ATotal);
  WriteChecked(@Pad[0], ATotal);
end;

procedure TTarWriter.MaybeReclaimIOBuf(const AHintSize: Int64); inline;
var
  LNeed: SizeUInt;
begin
  // precise reclaim via TarIOBufCapacityFor (bytes.ops AlignUp4K single source): shrink pooled 64K after short batch to avoid long-lived peak retention, O(1) still, inline zero-copy, caller-visible via TrimIOBuf
  if Length(FIOBuf) = 0 then
    Exit;
  LNeed := TarIOBufCapacityFor(AHintSize);
  if SizeUInt(Length(FIOBuf)) > LNeed then
    SetLength(FIOBuf, LNeed);
end;

procedure TTarWriter.WriteBlock(const ABlock: array of Byte);
var
  Len: SizeInt;
begin
  // no inline: 512B stack guard, single source via WritePadded helper (PadCopy+SpanFill single seam, single Write)
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
  // no inline: I-Cache guard, Bulk+Tail single Write, single source via WritePadded helper (PadCopy single seam)
  if Length(AData) = 0 then
    Exit;
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
  // bytes.ops single source SpanFill/MemSet single seam, inline zero-copy TByteSpan view, 单缝纯度收敛（消除 FillChar 分叉，与 PadCopy 单源一致）
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
  // bytes.ops single source, inline
  WritePaddedPayload(APayload);
end;

function TTarWriter.FindPrefixCut(const AName: string): SizeInt;
var
  I: Integer;
begin
  // no inline: loop body (design-conventions), bytes.ops single source is caller via TarPutHeaderSlice zero-copy
  Result := 0;
  if Length(AName) <= C_TAR_LAYOUT.Name.Len then
    Exit;
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
  // inline: thin predicate, no alloc
  Result := ((Length(AName) > C_TAR_LAYOUT.Name.Len) and (ACutPos = 0)) or (Length(ALinkName) > C_TAR_LAYOUT.LinkName.Len);
end;

procedure TTarWriter.ValidateAndCanonicalizeNames(var AName, ALinkName: string; AKind: TTarEntryKind);
begin
  // no inline: validation branches + exception paths, fail-closed
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
  // out-of-line: builder alloc path
  if not NeedsPaxHeader(AName, ALinkName, ACutPos) then
    Exit;
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
  // bytes.ops single source, inline zero-copy slice
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
  // bytes.ops single source, inline zero-copy slice
  if Length(ALinkName) > C_TAR_LAYOUT.LinkName.Len then
    TarPutHeaderSlice(ABlock, C_TAR_LAYOUT.LinkName.Off, C_TAR_LAYOUT.LinkName.Len, PByte(PAnsiChar(ALinkName)), SizeUInt(C_TAR_LAYOUT.LinkName.Len))
  else
    TarPutHeaderString(ABlock, C_TAR_LAYOUT.LinkName.Off, C_TAR_LAYOUT.LinkName.Len, ALinkName);
end;

procedure TTarWriter.FillNumericFields(ABlock: PByte; const AHdr: TTarHeader; ADataSize: Int64); inline;
begin
  // bytes.ops single source, inline numeric single point TarFormatNumericField
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
  // bytes.ops single source, inline
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
  // orchestration only: validate -> prefix cut -> pax -> fill -> checksum, each step single-responsibility
  if FFinished then
    raise EInvalidOperationError.Create('tar: writer already finished');
  if ADataSize < 0 then
    raise EArgumentError.Create('tar: negative size');
  Name := AHdr.Name;
  LinkName := AHdr.LinkName;
  ValidateAndCanonicalizeNames(Name, LinkName, AHdr.Kind);
  CutPos := FindPrefixCut(Name);
  EmitPaxIfNeeded(Name, LinkName, CutPos);
  // bytes.ops single source SpanFill single seam, inline zero-copy TByteSpan view, 单缝纯度收敛（消除 FillChar 分叉）
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

procedure TTarWriter.CopyReaderAndPad(const AReader: IReader; ASize: Int64; var ABuf: TBytes);
var
  LRead, LToRead: SizeUInt;
  LRemaining: Int64;
  PadLen: Int64;
  LNeed: SizeUInt;
begin
  // no inline: loop body (design-conventions I-Cache guard), bytes.ops single source SpanFill/MemSet single seam via WritePadded helper, inline zero-copy TByteSpan view, 单缝纯度收敛
  // single source helper for AddEntryFromReader / AddEntryFromReaderWithSharedBuf: 40行读-写-补零循环单源收敛，仅缓冲来源不同，零拷贝 PByte single source, TarIOBufCapacityFor AlignUp4K single source
  if ASize = 0 then
    Exit;
  LNeed := TarIOBufCapacityFor(ASize);
  if SizeUInt(Length(ABuf)) < LNeed then
    SetLength(ABuf, LNeed);
  LRemaining := ASize;
  while LRemaining > 0 do
  begin
    LToRead := SizeUInt(LRemaining);
    if LToRead > SizeUInt(Length(ABuf)) then
      LToRead := SizeUInt(Length(ABuf));
    LRead := AReader.Read(ABuf[0], LToRead);
    if LRead = 0 then
      raise EIOError.Create('tar: short read');
    WriteChecked(@ABuf[0], LRead);
    Dec(LRemaining, Int64(LRead));
  end;
  PadLen := TarPadToBlock(ASize);
  if PadLen > 0 then
    WritePadded(nil, 0, SizeUInt(PadLen));
end;

procedure TTarWriter.AddEntryFromReader(const AHdr: TTarHeader; const AReader: IReader);
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
  if AHdr.Size = 0 then
    Exit;
  // bytes.ops single source via TarIOBufCapacityFor (AlignUp4K), cross-entry pooled buffer FIOBuf: grow on demand, precise reclaim via TarIOBufCapacityFor/TrimIOBuf after short batch, released on Finish/Destroy (无长滞留), inline zero-copy, 200×512B 仅1次分配，单缝 helper CopyReaderAndPad
  CopyReaderAndPad(AReader, AHdr.Size, FIOBuf);
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
  if AHdr.Size = 0 then
    Exit;
  // single source helper: 复用 CopyReaderAndPad 单缝，共享缓冲由调用方持有，零拷贝 PByte single source
  CopyReaderAndPad(AReader, AHdr.Size, ASharedBuf);
end;

procedure TTarWriter.CopyReaderAndPadRaw(const AReader: IReader; ASize: Int64; ABuf: PByte; ABufCap: SizeUInt);
var
  LRead, LToRead: SizeUInt;
  LRemaining: Int64;
  PadLen: Int64;
begin
  if ASize = 0 then Exit;
  if (ABuf = nil) or (ABufCap = 0) then
    raise EArgumentError.Create('tar: raw buffer is nil');
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
  // precise reclaim: shrink pooled 64K peak to C_TAR_IOBUF_INIT for long-lived writer short-batch, bytes.ops TarIOBufCapacityFor single source, inline zero-copy, O(1) still, explicit caller reclaim to avoid Finish-only retention
  if Length(FIOBuf) = 0 then
    Exit;
  if SizeUInt(Length(FIOBuf)) > C_TAR_IOBUF_INIT then
    SetLength(FIOBuf, C_TAR_IOBUF_INIT);
end;

procedure TTarWriter.TrimIOBufTo(const AHintSize: Int64); inline;
begin
  // precise reclaim to TarIOBufCapacityFor hint, caller can hint next batch size, e.g., after large file TrimIOBufTo(0) or TrimIOBufTo(smallSize), bytes.ops AlignUp4K single source, inline zero-copy
  MaybeReclaimIOBuf(AHintSize);
end;

procedure TTarWriter.Finish;
var
  Zero: array[0..C_TAR_BLOCK_SIZE - 1] of Byte;
begin
  if FFinished then
    Exit;
  FFinished := True;
  // bytes.ops single source SpanFill single seam, inline zero-copy TByteSpan view, 单缝纯度收敛（消除 FillChar 分叉）
  SpanFill(TByteSpan.Create(@Zero[0], SizeOf(Zero)), 0);
  WriteBlock(Zero);
  WriteBlock(Zero);
  // stability: pooled 64K timely release on Finish, no long-lived retention, try..finally 必释 in Destroy remains fail-safe
  FIOBuf := nil;
end;

function TTarWriter.IsFinished: Boolean; inline;
begin
  Result := FFinished;
end;

destructor TTarWriter.Destroy;
begin
  // best-effort Finish 失败 Warn 抑制次生；bytes.ops 单源 zero-copy SpanFill single seam, try..finally 必释, NullLogger 零分配 inline（常量串无拼接，避免 E.Message 分配），FIOBuf 池化跨条目复用、Finish/Destroy 统一释放消除长滞留/抖动
  try
    if not FFinished then
      try
        Finish;
      except
        on E: Exception do
          NullLogger.Warn('tar: writer destroy suppress finish failure (short write)');
      end;
  finally
    FIOBuf := nil;
    FDst := nil;
    inherited Destroy;
  end;
end;

end.
