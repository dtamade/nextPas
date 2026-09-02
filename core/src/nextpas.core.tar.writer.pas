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
    FStreamBuf: TBytes; // pooled 64K buffer for AddEntryFromReader, amortized allocs, inline zero-copy
    procedure WriteBlock(const ABlock: array of Byte);
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

{ — pax record 单点已收敛至 common.TarFormatPaxRecord（复用 bytes.ops 单源编解码，零拷贝 PAnsiChar 视图，外联禁 inline），writer 仅薄委托，不再手写十进制自洽逻辑 — }

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
  // stability: 超 512 抛错而非静默截断，暴露上游头构造越界；资源释放由调用方/caller 兜底，无泄漏
  if Len > CBlockSize then
    raise EArgumentError.CreateFmt('tar: block size %d exceeds %d', [Len, CBlockSize]);
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
  PadLen: Int64;
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

procedure TTarWriter.WriteHeader(const AHdr: TTarHeader; ADataSize: Int64);
var
  Block: array[0..C_TAR_BLOCK_SIZE - 1] of Byte;
  Name, LinkName: string;
  CutPos: SizeInt;
  LPaxBytes: TBytes;
  LBuilder: IBytesBuilder;
  LRec: string;
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
    // perf: bytes.builder 单源几何扩容单次 ToBytes 一次 Move 单源 bytes.ops，消除 LPaxText 字符串拼接累加后 StringToBytes 多次分配，复用 common.TarFormatPaxRecord 单源编解码；零拷贝 PAnsiChar 视图 AppendBytes 单源 Move
    // stability: builder 接口生命周期局部持有，异常安全不丢，LPaxBytes 由托管 TBytes 释放
    LBuilder := CreateBytesBuilder(256);
    if (Length(Name) > C_TAR_LEN_NAME) and (CutPos = 0) then
    begin
      LRec := TarFormatPaxRecord('path', Name);
      if Length(LRec) > 0 then
        LBuilder.AppendBytes(PByte(PAnsiChar(LRec)), SizeUInt(Length(LRec)));
    end;
    if Length(LinkName) > C_TAR_LEN_LINKNAME then
    begin
      LRec := TarFormatPaxRecord('linkpath', LinkName);
      if Length(LRec) > 0 then
        LBuilder.AppendBytes(PByte(PAnsiChar(LRec)), SizeUInt(Length(LRec)));
    end;
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
  TarFinalizeHeaderChecksum(@Block[0]);
  WriteBlock(Block);
end;

procedure TTarWriter.EmitEntry(const AHdr: TTarHeader; const AData: TBytes);
var
  PadBlock: array[0..C_TAR_BLOCK_SIZE - 1] of Byte;
  PadLen: Int64;
begin
  // perf: header 单源复用 WriteHeader inline，零拷贝 Move 经 bytes.ops 单源
  WriteHeader(AHdr, Length(AData));
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
const
  C_STREAM_BUF = 65536;
var
  LRead, LToRead, LNeeded: SizeUInt;
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
  // perf: 头单源 WriteHeader inline 零拷贝，内容 64K 分块 Move 单源 bytes.ops，无 TBytes 全量拷贝
  WriteHeader(AHdr, AHdr.Size);
  if AHdr.Size = 0 then
    Exit;
  // perf: pooled buffer reuse via FStreamBuf (instance-level pool), lazy min(Size,64K) cold-start, amortized single alloc across entries, inline zero-copy Move via bytes.ops semantics; growth on demand + 4x-threshold shrink (avoid 64K peak retention for small-file burst), no per-entry SetLength/Free churn
  // stability: threshold shrink retains reuse for nearby sizes, 8K floor avoids thrash, exception-safe, freed on Finish/Destroy;资源释放由 TBytes 生命周期兜底，无泄漏
  LNeeded := SizeUInt(AHdr.Size);
  if LNeeded > C_STREAM_BUF then
    LNeeded := C_STREAM_BUF;
  if SizeUInt(Length(FStreamBuf)) < LNeeded then
    SetLength(FStreamBuf, LNeeded)
  else if (SizeUInt(Length(FStreamBuf)) > 8192) and (SizeUInt(Length(FStreamBuf)) > LNeeded * 4) then
    SetLength(FStreamBuf, LNeeded);
  LRemaining := AHdr.Size;
  while LRemaining > 0 do
  begin
    LToRead := SizeUInt(LRemaining);
    if LToRead > SizeUInt(Length(FStreamBuf)) then
      LToRead := SizeUInt(Length(FStreamBuf));
    LRead := AReader.Read(FStreamBuf[0], LToRead);
    if LRead = 0 then
      raise EIOError.Create('tar: short read');
    if FDst.Write(FStreamBuf[0], LRead) <> LRead then
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
  // stability: pooled buffer peak release on Finish, avoid 64K lingering after last large entry; amortized reuse already done, no thrash
  SetLength(FStreamBuf, 0);
end;

function TTarWriter.IsFinished: Boolean; inline;
begin
  Result := FFinished;
end;

destructor TTarWriter.Destroy;
begin
  // stability: fail-closed — propagate EIOError/short write from Finish to avoid silent two-zero truncation masking; buffer release guaranteed via finally
  // perf: threshold-shrink + Finish release already handled, Destroy only ensures final free without extra alloc
  try
    if not FFinished then
      Finish;
  finally
    SetLength(FStreamBuf, 0);
    inherited Destroy;
  end;
end;

end.
