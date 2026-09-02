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

{ — pax record：长度前缀十进制自洽，复用 bytes.ops Move 单源语义（零拷贝 PAnsiChar 视图），单次 SetLength 分配闭合 common SpanToString 审计；含循环/分配不 inline — }
function MakePaxRecord(const AKey, AValue: string): string;
var
  LBase, LLen, LDigits: Integer;
  SLen: string;
  LPos: SizeInt;
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
  // perf: 单次 SetLength(Result,LLen)+顺序 CopyStringToBuffer（bytes.ops 单源 Move，零拷贝 PAnsiChar 视图，外联单次 Move 规避 FPC 3.3.1 inline+Move 单字节缺陷），消除 SpanConcatMany->TBytes + BytesToString 双堆分配与二次 Move；长名冷路径少一次堆分配，极小记录亦零额外 Move；循环/分配外联禁 inline
  // stability: 空键/值守零长不 Copy，PAnsiChar 非空断言由 Length>0 保障，块零初始化由调用方兜底，单源闭合 bytes.ops CopyStringToBuffer 审计（同 common.pas SpanToString/TarPutHeaderString 单源），资源由托管 string 释放不丢
  SetLength(Result, LLen);
  LPos := 1;
  if Length(SLen) > 0 then
  begin
    CopyStringToBuffer(SLen, PByte(PAnsiChar(Result) + LPos - 1), SizeUInt(Length(SLen)));
    Inc(LPos, Length(SLen));
  end;
  Result[LPos] := ' ';
  Inc(LPos);
  if Length(AKey) > 0 then
  begin
    CopyStringToBuffer(AKey, PByte(PAnsiChar(Result) + LPos - 1), SizeUInt(Length(AKey)));
    Inc(LPos, Length(AKey));
  end;
  Result[LPos] := '=';
  Inc(LPos);
  if Length(AValue) > 0 then
  begin
    CopyStringToBuffer(AValue, PByte(PAnsiChar(Result) + LPos - 1), SizeUInt(Length(AValue)));
    Inc(LPos, Length(AValue));
  end;
  Result[LPos] := #10;
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
  LPaxText: string;
  LPaxBytes: TBytes;
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
  // perf: pooled buffer reuse via FStreamBuf (instance-level pool), lazy min(Size,64K) cold-start, amortized single alloc across entries, inline zero-copy Move via bytes.ops semantics; growth on demand, no per-entry SetLength/Free
  // stability: buffer retains capacity across calls, exception-safe, freed on Destroy;资源释放由 TBytes 生命周期兜底，无泄漏
  LNeeded := SizeUInt(AHdr.Size);
  if LNeeded > C_STREAM_BUF then
    LNeeded := C_STREAM_BUF;
  if SizeUInt(Length(FStreamBuf)) < LNeeded then
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
end;

function TTarWriter.IsFinished: Boolean; inline;
begin
  Result := FFinished;
end;

destructor TTarWriter.Destroy;
begin
  try
    Finish;
  except
    // best-effort: 两零块收尾可抛 EIOError，析构期吞掉避免异常逃逸（builder 层 fail-closed 显式校验）
  end;
  inherited Destroy;
end;

end.
