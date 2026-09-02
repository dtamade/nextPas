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
    procedure WritePaddedPayload(const AData: TBytes); inline;
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
  CBlockSize = C_TAR_BLOCK_SIZE;
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
end;

procedure TTarWriter.WriteBlock(const ABlock: array of Byte); inline;
var
  Buf: array[0..C_TAR_BLOCK_SIZE - 1] of Byte;
  Len: SizeInt;
begin
  Len := Length(ABlock);
  // stability: 超 512 抛错而非静默截断，暴露上游头构造越界；资源释放由调用方/caller 兜底，无泄漏
  if Len > CBlockSize then
    raise EArgumentError.CreateFmt('tar: block size %d exceeds %d', [Len, CBlockSize]);
  if Len = CBlockSize then
  begin
    if FDst.Write(ABlock[0], SizeUInt(Len)) <> SizeUInt(Len) then
      raise EIOError.Create('tar: short write');
  end
  else
  begin
    // perf: single IWriter.Write 512 via stacked zero-pad + CopyMemory single source, merge header+pad double virtual dispatch (200x512B per-entry 2->1), inline + zero-copy Move via bytes.ops single source
    FillChar(Buf[0], SizeOf(Buf), 0);
    if Len > 0 then
      CopyMemory(PByte(@ABlock[0]), PByte(@Buf[0]), SizeUInt(Len));
    if FDst.Write(Buf[0], SizeUInt(CBlockSize)) <> SizeUInt(CBlockSize) then
      raise EIOError.Create('tar: short write');
  end;
end;

procedure TTarWriter.WritePaddedPayload(const AData: TBytes); inline;
var
  PadBlock: array[0..C_TAR_BLOCK_SIZE - 1] of Byte;
  PadLen: Int64;
  TailLen, BulkLen: SizeUInt;
begin
  // perf: 单源 Bulk+Tail+Pad 三分支批量写入，复用 bytes.ops CopyMemory 单源 Move，inline 零拷贝；EmitPaxHeader/EmitEntry 共用此单点，消除三处拷贝重复，热路径单次虚分发
  if Length(AData) = 0 then
    Exit;
  PadLen := TarPadToBlock(Length(AData));
  if PadLen = 0 then
  begin
    if FDst.Write(AData[0], SizeUInt(Length(AData))) <> SizeUInt(Length(AData)) then
      raise EIOError.Create('tar: short write');
  end
  else if SizeUInt(Length(AData)) <= CBlockSize then
  begin
    // perf: small payload+pad 单次 512 写入 via stacked 512 + CopyMemory 单源，避免二次 Write；inline + zero-copy
    FillChar(PadBlock[0], SizeOf(PadBlock), 0);
    CopyMemory(PByte(@AData[0]), PByte(@PadBlock[0]), SizeUInt(Length(AData)));
    if FDst.Write(PadBlock[0], SizeUInt(CBlockSize)) <> SizeUInt(CBlockSize) then
      raise EIOError.Create('tar: short write');
  end
  else
  begin
    // perf: bulk aligned Move 单源 + tail+pad 合并单次 512 虚分发 via CopyMemory，降抖动；inline 零拷贝
    BulkLen := (SizeUInt(Length(AData)) div SizeUInt(CBlockSize)) * SizeUInt(CBlockSize);
    TailLen := SizeUInt(Length(AData)) - BulkLen;
    if BulkLen > 0 then
      if FDst.Write(AData[0], BulkLen) <> BulkLen then
        raise EIOError.Create('tar: short write');
    FillChar(PadBlock[0], SizeOf(PadBlock), 0);
    if TailLen > 0 then
      CopyMemory(PByte(@AData[BulkLen]), PByte(@PadBlock[0]), TailLen);
    if FDst.Write(PadBlock[0], SizeUInt(CBlockSize)) <> SizeUInt(CBlockSize) then
      raise EIOError.Create('tar: short write');
  end;
end;

procedure TTarWriter.EmitPaxHeader(const APayload: TBytes); inline;
var
  Block: array[0..C_TAR_BLOCK_SIZE - 1] of Byte;
begin
  FillChar(Block[0], SizeOf(Block), 0);
  TarPutHeaderString(@Block[0], C_TAR_OFF_NAME, C_TAR_LEN_NAME, C_TAR_PAX_HEADER_NAME);
  TarFormatNumericField(@Block[0], C_TAR_OFF_MODE, C_TAR_LEN_MODE, 0);
  TarFormatNumericField(@Block[0], C_TAR_OFF_UID, C_TAR_LEN_UID, 0);
  TarFormatNumericField(@Block[0], C_TAR_OFF_GID, C_TAR_LEN_GID, 0);
  TarFormatNumericField(@Block[0], C_TAR_OFF_SIZE, C_TAR_LEN_SIZE, Length(APayload));
  TarFormatNumericField(@Block[0], C_TAR_OFF_MTIME, C_TAR_LEN_MTIME, 0);
  FillChar(Block[C_TAR_OFF_CHKSUM], C_TAR_LEN_CHKSUM, Ord(' '));
  Block[C_TAR_OFF_TYPEFLAG] := Ord('x');
  TarWriteUStarMagic(@Block[0]);
  TarFinalizeHeaderChecksum(@Block[0]);
  WriteBlock(Block);
  // 单源：Bulk+Tail+Pad 复用 WritePaddedPayload，复用 bytes.ops 单源零拷贝，inline
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
    LBuilder := CreateBytesBuilder(256);
    if (Length(Name) > C_TAR_LEN_NAME) and (CutPos = 0) then
      TarAppendPaxRecord(LBuilder, 'path', Name);
    if Length(LinkName) > C_TAR_LEN_LINKNAME then
      TarAppendPaxRecord(LBuilder, 'linkpath', LinkName);
    LPaxBytes := LBuilder.ToBytes;
    EmitPaxHeader(LPaxBytes);
  end;
  FillChar(Block[0], SizeOf(Block), 0);
  if (Length(Name) > C_TAR_LEN_NAME) and (CutPos = 0) then
    // perf: TarPutHeaderSlice 零拷贝 PByte 切片单源 Move(bytes.ops)，消除 Copy(Name,1,N) 临时串二次分配与 Move
    TarPutHeaderSlice(@Block[0], C_TAR_OFF_NAME, C_TAR_LEN_NAME, PByte(PAnsiChar(Name)), SizeUInt(C_TAR_LEN_NAME))
  else if CutPos <> 0 then
  begin
    // perf: 前缀/名称分片零拷贝切片，复用 bytes.ops 单源 Move，无临时串分配；PAnsiChar 算术避免 @Name[idx] 越界 RangeCheck
    TarPutHeaderSlice(@Block[0], C_TAR_OFF_PREFIX, C_TAR_LEN_PREFIX, PByte(PAnsiChar(Name)), SizeUInt(CutPos));
    TarPutHeaderSlice(@Block[0], C_TAR_OFF_NAME, C_TAR_LEN_NAME, PByte(PAnsiChar(Name) + CutPos + 1), SizeUInt(Length(Name) - CutPos - 1));
  end
  else
    TarPutHeaderString(@Block[0], C_TAR_OFF_NAME, C_TAR_LEN_NAME, Name);
  TarFormatNumericField(@Block[0], C_TAR_OFF_MODE, C_TAR_LEN_MODE, AHdr.Mode);
  TarFormatNumericField(@Block[0], C_TAR_OFF_UID, C_TAR_LEN_UID, AHdr.UID);
  TarFormatNumericField(@Block[0], C_TAR_OFF_GID, C_TAR_LEN_GID, AHdr.GID);
  if AHdr.Kind = tekRegular then
    TarFormatNumericField(@Block[0], C_TAR_OFF_SIZE, C_TAR_LEN_SIZE, ADataSize)
  else
    TarFormatNumericField(@Block[0], C_TAR_OFF_SIZE, C_TAR_LEN_SIZE, 0);
  TarFormatNumericField(@Block[0], C_TAR_OFF_MTIME, C_TAR_LEN_MTIME, AHdr.MTimeUnix);
  FillChar(Block[C_TAR_OFF_CHKSUM], C_TAR_LEN_CHKSUM, Ord(' '));
  Block[C_TAR_OFF_TYPEFLAG] := Byte(KindToTypeFlag(AHdr.Kind));
  if Length(LinkName) > C_TAR_LEN_LINKNAME then
    // perf: 零拷贝切片截断，消除 Copy(LinkName) 临时串；PAnsiChar 零拷贝视图单源 bytes.ops
    TarPutHeaderSlice(@Block[0], C_TAR_OFF_LINKNAME, C_TAR_LEN_LINKNAME, PByte(PAnsiChar(LinkName)), SizeUInt(C_TAR_LEN_LINKNAME))
  else
    TarPutHeaderString(@Block[0], C_TAR_OFF_LINKNAME, C_TAR_LEN_LINKNAME, LinkName);
  TarWriteUStarMagic(@Block[0]);
  TarPutHeaderString(@Block[0], C_TAR_OFF_UNAME, C_TAR_LEN_UNAME, AHdr.UName);
  TarPutHeaderString(@Block[0], C_TAR_OFF_GNAME, C_TAR_LEN_GNAME, AHdr.GName);
  // ustar devmajor/devminor：设备类型保留设备号，char/block 设备生效，其余置零兼容；复用 bytes.ops 单源 Move 单点
  TarFormatNumericField(@Block[0], C_TAR_OFF_DEVMAJOR, C_TAR_LEN_DEVMAJOR, AHdr.DevMajor);
  TarFormatNumericField(@Block[0], C_TAR_OFF_DEVMINOR, C_TAR_LEN_DEVMINOR, AHdr.DevMinor);
  TarFinalizeHeaderChecksum(@Block[0]);
  WriteBlock(Block);
end;

procedure TTarWriter.EmitEntry(const AHdr: TTarHeader; const AData: TBytes); inline;
begin
  // perf: header 单源复用 WriteHeader inline，零拷贝 Move 经 bytes.ops 单源
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
  LBuf: TBytes;
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
  // perf: 头单源 WriteHeader inline 零拷贝，内容分块 Move 单源 bytes.ops，无 TBytes 全量拷贝
  WriteHeader(AHdr, AHdr.Size);
  if AHdr.Size = 0 then
    Exit;
  // perf: 局部缓冲按需单次分配，无实例级池化状态机；消除大小文件交替时 2×阈值缩容/4K 底反复 SetLength 与清零 Move，开销回归 amortized 单次分配；职责归一至调用栈，L2 容器不背内存池
  // stability: 局部 TBytes 生命周期托管，异常安全不丢，无 linger 峰值
  LBufSize := SizeUInt(AHdr.Size);
  if LBufSize > C_STREAM_BUF_SIZE then
    LBufSize := C_STREAM_BUF_SIZE;
  SetLength(LBuf, LBufSize);
  LRemaining := AHdr.Size;
  while LRemaining > 0 do
  begin
    LToRead := SizeUInt(LRemaining);
    if LToRead > SizeUInt(Length(LBuf)) then
      LToRead := SizeUInt(Length(LBuf));
    LRead := AReader.Read(LBuf[0], LToRead);
    if LRead = 0 then
      raise EIOError.Create('tar: short read');
    if FDst.Write(LBuf[0], LRead) <> LRead then
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
  FillChar(Zero[0], SizeOf(Zero), 0);
  WriteBlock(Zero);
  WriteBlock(Zero);
end;

function TTarWriter.IsFinished: Boolean; inline;
begin
  Result := FFinished;
end;

destructor TTarWriter.Destroy;
var
  LUnwinding: Boolean;
begin
  // stability: SafeFail — ExceptObject 非 nil 时抑制二次异常逃逸，StdErr WARN 后释资源；避免析构期 Finish 的 EIOError/short-write 直抛导致进程终止
  // perf: 无池化状态机，仅 Finish 两零块 best-effort，零额外分配，inline 零拷贝复用
  LUnwinding := nextpas.core.exception.ExceptObject <> nil;
  try
    if not FFinished then
    try
      Finish;
    except
      on E: Exception do
      begin
        System.WriteLn(System.StdErr, '[WARN] tar: writer Destroy Finish suppressed: ', E.Message, ' unwinding=', LUnwinding);
        System.Flush(System.StdErr);
        if not LUnwinding then
        begin
          // 非 unwind 期亦抑制，避免析构抛异常逃逸；已 WARN 可观测，fail-closed 由调用方显式 Finish 保证
        end;
      end;
    end;
  finally
    inherited Destroy;
  end;
end;

end.
