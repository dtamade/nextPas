unit nextpas.core.tar.writer;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.builder,
  nextpas.core.tar.base,
  nextpas.core.io.intf,
  nextpas.core.log.intf;

type
  TTarWriter = class
  private
    FDst: IWriter;
    FFinished: Boolean;
    FIOBuf: TBytes; // I/O buffer
    FPaxBuilder: IBytesBuilder; // pax 可复用 builder：256 初始，Clear 复用零每条目 Create(连续长名零放大分配)
    FLogger: ILogger;
    procedure EnsureIOBufForSize(ASize: Int64); inline;
    procedure WriteChecked(AData: PByte; ACount: SizeUInt); inline;
    procedure WritePadded(const AData: PByte; AUsed, ATotal: SizeUInt); inline;
    procedure WriteBlock(const ABlock: array of Byte);
    procedure WritePaddedPayload(const AData: TBytes);
    procedure EmitPaxHeader(const APayload: TBytes);
    procedure EmitEntry(const AHdr: TTarHeader; const AData: TBytes);
    function FindPrefixCut(const AName: string): SizeInt;
    function NeedsPaxHeader(const AName, ALinkName: string; ACutPos: SizeInt): Boolean; inline;
    procedure ValidateAndCanonicalizeNames(var AName, ALinkName: string; AKind: TTarEntryKind);
    procedure EmitPaxIfNeeded(const AName, ALinkName: string; ACutPos: SizeInt);
    procedure FillHeaderStringField(ABlock: PByte; AOff, ALen: SizeUInt; const AValue: string); inline;
    procedure FillNameFields(ABlock: PByte; const AName: string; ACutPos: SizeInt); inline;
    procedure FillLinkNameField(ABlock: PByte; const ALinkName: string); inline;
    procedure FillNumericFields(ABlock: PByte; const AHdr: TTarHeader; ADataSize: Int64); inline;
    procedure FillTrailerFields(ABlock: PByte; const AHdr: TTarHeader); inline;
    procedure WriteHeader(const AHdr: TTarHeader; ADataSize: Int64);
    procedure DoCopyAndPad(const AReader: IReader; ASize: Int64; ABuf: PByte; ABufCap: SizeUInt);
    procedure EmitSparse10Entry(const AName: string; const AData: TBytes; AMode: Cardinal; AUID, AGID: Cardinal; AMTimeUnix: Int64; const AUName, AGName: string);
  public
    constructor Create(const ADst: IWriter);
    procedure SetLogger(const ALogger: ILogger); inline;
    procedure AddEntry(const AHdr: TTarHeader; const AData: TBytes);
    procedure AddEntryWithOptions(const AName: string; const AData: TBytes; const AOpts: TTarAddOptions); overload;
    procedure AddFile(const AName: string; const AData: TBytes; AMode: Cardinal = C_TAR_DEFAULT_FILE_MODE; AMTimeUnix: Int64 = 0);
    procedure AddSparseFile(const AName: string; const AData: TBytes; AMode: Cardinal = C_TAR_DEFAULT_FILE_MODE; AMTimeUnix: Int64 = 0);
    procedure AddDir(const AName: string; AMode: Cardinal = C_TAR_DEFAULT_DIR_MODE; AMTimeUnix: Int64 = 0);
    procedure AddDirWithOptions(const AName: string; const AOpts: TTarAddOptions);
    procedure AddEntryFromReader(const AHdr: TTarHeader; const AReader: IReader);
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
  nextpas.core.tar.common,
  nextpas.core.tar.capacity,
  nextpas.core.tar.log,
  nextpas.core.text.number;

type
  TSparseWriteSeg = record Off, Len: Int64; end;
  TSparseWriteSegs = array of TSparseWriteSeg;

function DecOfInt64(AValue: Int64): string;
var
  Buf: array[0..19] of AnsiChar;
  N: Int32;
begin
  // decimal 单源 text.number.IntToBuffer
  N := IntToBuffer(AValue, @Buf[0]);
  if N <= 0 then
    Exit('0');
  SetString(Result, PAnsiChar(@Buf[0]), N);
end;

procedure CollectDataSegs(const AData: TBytes; out ASegs: TSparseWriteSegs);
var
  I, N, Start: Integer;
begin
  // 零洞扫描：非零 run 即段，全零/空得空集，外联
  ASegs := nil;
  N := Length(AData);
  I := 0;
  while I < N do
  begin
    if AData[I] = 0 then
    begin
      Inc(I);
      Continue;
    end;
    Start := I;
    repeat
      Inc(I);
    until (I >= N) or (AData[I] = 0);
    SetLength(ASegs, Length(ASegs) + 1);
    ASegs[High(ASegs)].Off := Start;
    ASegs[High(ASegs)].Len := I - Start;
  end;
end;

function BuildSparseMapBytes(const ASegs: TSparseWriteSegs; AReal: Int64): TBytes;
var
  S: string;
  I: Integer;
begin
  // 1.0 文本 map：count + offset/size 对 + (realsize, 0) 终结符，读侧 ParseSparseMapText 严格对称
  S := DecOfInt64(Length(ASegs) + 1) + #10;
  for I := 0 to High(ASegs) do
    S := S + DecOfInt64(ASegs[I].Off) + #10 + DecOfInt64(ASegs[I].Len) + #10;
  S := S + DecOfInt64(AReal) + #10 + '0' + #10;
  Result := StringToBytes(S);
end;

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

constructor TTarWriter.Create(const ADst: IWriter);
begin
  inherited Create;
  if ADst = nil then
    raise EArgumentError.Create('tar: destination writer is nil');
  FDst := ADst;
  FIOBuf := nil;
  FLogger := NullLogger;
end;

procedure TTarWriter.SetLogger(const ALogger: ILogger); inline;
begin
  if ALogger <> nil then
    FLogger := ALogger
  else
    FLogger := NullLogger;
end;

procedure TTarWriter.EnsureIOBufForSize(ASize: Int64); inline;
var LNeed: SizeUInt;
begin
  // 单源容量策略：capacity.TarIOBufCapacityFor(4K~1M clamp+AlignUp4K inline 零拷贝)→bytes.ops.BytesEnsureCapacity 几何 2×单源，消除与 builder 双路径心智负担，双薄转发合一
  LNeed := nextpas.core.tar.capacity.TarIOBufCapacityFor(ASize);
  BytesEnsureCapacity(FIOBuf, LNeed);
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
    WriteChecked(ZeroBufPtr, ATotal - AUsed);
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
  LSpan: TByteSpan;
  LPos: SizeInt;
  LLimit: SizeUInt;
begin
  // 外联：真实循环体（while 扫描 '/' + SpanLastIndexOf 迭代）禁 inline，遵 design-conventions 红线2，避 I-Cache 复制膨胀，复用 bytes.ops 单源零拷贝视图
  Result := 0;
  if Length(AName) <= C_TAR_LAYOUT.Name.Len then Exit;
  LSpan := StringAsSpan(AName);
  LLimit := SizeUInt(C_TAR_LAYOUT.Prefix.Len + 1);
  if LSpan.Len < LLimit then LLimit := LSpan.Len;
  LPos := SpanLastIndexOf(LSpan.Slice(0, LLimit), Byte('/'));
  while LPos >= 0 do
  begin
    // 空后缀（名尾斜杠本身）不切：切出空 name 段会丢目录尾斜杠，留待更早斜杠或 pax 回退保真
    if (Length(AName) - LPos - 1 > 0) and (SizeUInt(Length(AName) - LPos - 1) <= C_TAR_LAYOUT.Name.Len) then
      Exit(LPos);
    if LPos = 0 then Break;
    LPos := SpanLastIndexOf(LSpan.Slice(0, SizeUInt(LPos)), Byte('/'));
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
  LPaxBytes: TBytes;
begin
  if not NeedsPaxHeader(AName, ALinkName, ACutPos) then Exit;
  // perf: FPaxBuilder 复用(256 初始 Clear 零每条目 CreateBytesBuilder 分配放大，连续长名零放大，ToBytes 单次 Move 零额外拷贝，IBytesBuilder 几何 2×单源)
  if FPaxBuilder = nil then
    FPaxBuilder := CreateBytesBuilder(256)
  else
    FPaxBuilder.Clear;
  if (Length(AName) > C_TAR_LAYOUT.Name.Len) and (ACutPos = 0) then
    TarAppendPaxRecord(FPaxBuilder, 'path', AName);
  if Length(ALinkName) > C_TAR_LAYOUT.LinkName.Len then
    TarAppendPaxRecord(FPaxBuilder, 'linkpath', ALinkName);
  LPaxBytes := FPaxBuilder.ToBytes;
  EmitPaxHeader(LPaxBytes);
end;

procedure TTarWriter.FillHeaderStringField(ABlock: PByte; AOff, ALen: SizeUInt; const AValue: string); inline;
var LSpan: TByteSpan;
begin
  if Length(AValue) = 0 then Exit;
  if Length(AValue) > Integer(ALen) then
  begin
    LSpan := StringAsSpan(AValue);
    TarPutHeaderField(ABlock, AOff, ALen, LSpan.Slice(0, ALen));
  end
  else
    TarPutHeaderString(ABlock, AOff, ALen, AValue);
end;

procedure TTarWriter.FillNameFields(ABlock: PByte; const AName: string; ACutPos: SizeInt); inline;
var LSpan: TByteSpan;
begin
  if (Length(AName) > Integer(C_TAR_LAYOUT.Name.Len)) and (ACutPos = 0) then
    FillHeaderStringField(ABlock, C_TAR_LAYOUT.Name.Off, C_TAR_LAYOUT.Name.Len, AName)
  else if ACutPos <> 0 then
  begin
    LSpan := StringAsSpan(AName);
    TarPutHeaderField(ABlock, C_TAR_LAYOUT.Prefix.Off, C_TAR_LAYOUT.Prefix.Len, LSpan.Slice(0, SizeUInt(ACutPos)));
    TarPutHeaderField(ABlock, C_TAR_LAYOUT.Name.Off, C_TAR_LAYOUT.Name.Len, LSpan.Slice(SizeUInt(ACutPos + 1), SizeUInt(Length(AName) - ACutPos - 1)));
  end
  else
    TarPutHeaderString(ABlock, C_TAR_LAYOUT.Name.Off, C_TAR_LAYOUT.Name.Len, AName);
end;

procedure TTarWriter.FillLinkNameField(ABlock: PByte; const ALinkName: string); inline;
begin
  FillHeaderStringField(ABlock, C_TAR_LAYOUT.LinkName.Off, C_TAR_LAYOUT.LinkName.Len, ALinkName);
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

procedure TTarWriter.EmitSparse10Entry(const AName: string; const AData: TBytes; AMode: Cardinal; AUID, AGID: Cardinal; AMTimeUnix: Int64; const AUName, AGName: string);
const
  C_SPARSE_PLACEHOLDER_PREFIX = './GNUSparseFile.0/';
var
  LSegs: TSparseWriteSegs;
  LMapBytes: TBytes;
  LPlaceName: string;
  LStored, LDense, LSegTotal, LPad: Int64;
  I: Integer;
  Block: array[0..C_TAR_BLOCK_SIZE - 1] of Byte;
  H: TTarHeader;
begin
  // 显式稀疏写出（pax 1.0）：占位名确定性取 .0 后缀；名过长/无收益/空数据回退 dense，字节与 AddFile 一致
  if FFinished then
    raise EInvalidOperationError.Create('tar: writer already finished');
  ValidateTarEntryName(AName);
  LPlaceName := C_SPARSE_PLACEHOLDER_PREFIX + AName;
  if Length(AData) = 0 then
  begin
    H := Default(TTarHeader);
    H.Name := AName;
    H.Kind := tekRegular;
    H.Mode := AMode;
    H.MTimeUnix := AMTimeUnix;
    EmitEntry(H, nil);
    Exit;
  end;
  CollectDataSegs(AData, LSegs);
  LMapBytes := BuildSparseMapBytes(LSegs, Length(AData));
  LSegTotal := 0;
  for I := 0 to High(LSegs) do
    LSegTotal := LSegTotal + LSegs[I].Len;
  LStored := (Length(LMapBytes) + TarPadToBlock(Length(LMapBytes))) + LSegTotal;
  LDense := Length(AData) + TarPadToBlock(Length(AData));
  if (Length(LPlaceName) > C_TAR_LAYOUT.Name.Len) or (LStored >= LDense) then
  begin
    H := Default(TTarHeader);
    H.Name := AName;
    H.Kind := tekRegular;
    H.Mode := AMode;
    H.UID := AUID;
    H.GID := AGID;
    H.MTimeUnix := AMTimeUnix;
    H.UName := AUName;
    H.GName := AGName;
    H.Size := Length(AData);
    EmitEntry(H, AData);
    Exit;
  end;
  if FPaxBuilder = nil then
    FPaxBuilder := CreateBytesBuilder(256)
  else
    FPaxBuilder.Clear;
  TarAppendPaxRecord(FPaxBuilder, 'GNU.sparse.major', '1');
  TarAppendPaxRecord(FPaxBuilder, 'GNU.sparse.minor', '0');
  TarAppendPaxRecord(FPaxBuilder, 'GNU.sparse.name', AName);
  TarAppendPaxRecord(FPaxBuilder, 'GNU.sparse.realsize', DecOfInt64(Length(AData)));
  EmitPaxHeader(FPaxBuilder.ToBytes);
  H := Default(TTarHeader);
  H.Kind := tekRegular;
  H.Mode := AMode;
  H.UID := AUID;
  H.GID := AGID;
  H.MTimeUnix := AMTimeUnix;
  H.UName := AUName;
  H.GName := AGName;
  SpanFill(TByteSpan.Create(@Block[0], SizeOf(Block)), 0);
  FillNameFields(@Block[0], LPlaceName, 0);
  FillNumericFields(@Block[0], H, LStored);
  SpanFill(TByteSpan.Create(@Block[C_TAR_LAYOUT.Chksum.Off], C_TAR_LAYOUT.Chksum.Len), Ord(' '));
  Block[C_TAR_LAYOUT.TypeFlag.Off] := Byte(KindToTypeFlag(H.Kind));
  FillTrailerFields(@Block[0], H);
  TarFinalizeHeaderChecksum(@Block[0]);
  WriteBlock(Block);
  WriteChecked(@LMapBytes[0], SizeUInt(Length(LMapBytes)));
  LPad := TarPadToBlock(Length(LMapBytes));
  if LPad > 0 then
    WriteChecked(ZeroBufPtr, SizeUInt(LPad));
  for I := 0 to High(LSegs) do
    WriteChecked(@AData[LSegs[I].Off], SizeUInt(LSegs[I].Len));
  LPad := TarPadToBlock(LStored);
  if LPad > 0 then
    WriteChecked(ZeroBufPtr, SizeUInt(LPad));
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
  if AOpts.Sparse then
  begin
    EmitSparse10Entry(AName, AData, H.Mode, H.UID, H.GID, H.MTimeUnix, H.UName, H.GName);
    Exit;
  end;
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

procedure TTarWriter.AddSparseFile(const AName: string; const AData: TBytes; AMode: Cardinal; AMTimeUnix: Int64);
begin
  // 显式稀疏写出：需全量洞扫描，流式入口不支持
  EmitSparse10Entry(AName, AData, AMode, 0, 0, AMTimeUnix, '', '');
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
  if AHdr.Size = 0 then Exit;
  // perf: 高水位缓冲复用 via FIOBuf（capacity.TarIOBufCapacityFor→AlignUp4K 位掩码 inline 零拷贝/BytesEnsureCapacity 几何 2× 高水位 4K~1M clamp，跨条目复用零每条目分配，单次高水位分配跨 200×512B 复用零每条目 GetMem 抖动，DoCopyAndPad PByte 视图零拷贝直达 bytes.ops.CopyMemory 单源，消除对称量小文件系统调用放大，外联遵设计公约红线 2 循环/IO 分发禁 inline 避 I-Cache 膨胀，资源 try..finally 必释不丢，Finish/TrimIOBuf 统一释放）
  EnsureIOBufForSize(AHdr.Size);
  DoCopyAndPad(AReader, AHdr.Size, @FIOBuf[0], SizeUInt(Length(FIOBuf)));
end;

procedure TTarWriter.TrimIOBuf; inline;
begin
  BytesRelease(FIOBuf);
end;

procedure TTarWriter.TrimIOBufTo(const AHintSize: Int64); inline;
var
  LNeed: SizeUInt;
begin
  if Length(FIOBuf) = 0 then Exit;
  if AHintSize <= 0 then
  begin
    BytesRelease(FIOBuf);
    Exit;
  end;
  LNeed := nextpas.core.tar.capacity.TarIOBufCapacityFor(AHintSize);
  BytesShrinkTo(FIOBuf, LNeed);
end;

procedure TTarWriter.Finish;
begin
  if FFinished then Exit;
  FFinished := True;
  WriteChecked(ZeroBufPtr, 2 * C_TAR_BLOCK_SIZE);
  TrimIOBuf;
  FPaxBuilder := nil;
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
      if FLogger = nil then
        FLogger := NullLogger;
      FLogger.Warn(C_TAR_WARN_WRITER_DESTROYED_WITHOUT_FINISH);
      // 语义：未 Finish 即析构不补写两零块，仅 Warn 可观测后释放资源；
      // 调用方必须显式 Finish 取规范收尾，析构永不抛异常，资源 try..finally 必释
    end;
  finally
    BytesRelease(FIOBuf);
    FPaxBuilder := nil;
    FDst := nil;
    inherited Destroy;
  end;
end;

end.
