unit nextpas.core.sevenz.header;

{**
 * nextpas.core.sevenz.header - 7z 容器头解析与序列化
 *
 * 拥有 StreamsInfo/FoldersInfo/FilesInfo 的结构定义、varint 编解码、
 * 头部字节级解析与写端序列化。数字编码严格对齐 7-Zip 参考实现：
 * 首字节高位前缀指示总长，低位续字节按小端拼接。
 * 本单元不做解压：编码头由 reader 解码后重入解析。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.sevenz.base;

type
  {** @desc 单个 coder 描述：方法 ID + 属性 + 输入流数 *}
  TSevenZCoderDesc = record
    MethodId: UInt64;
    Props: TBytes;
    NumInStreams: Cardinal;
  end;

  {** @desc 绑定对：某 coder 的输入流 ← 另一 coder 的输出流 *}
  TSevenZBindPair = record
    InIndex: Cardinal;
    OutIndex: Cardinal;
  end;

  {** @desc 一个 folder：完整解码链 + 派生信息 *}
  TSevenZFolder = record
    Coders: array of TSevenZCoderDesc;
    BindPairs: array of TSevenZBindPair;
    PackedInIndices: array of Cardinal;
    OutSizes: array of UInt64;
    MainOutIndex: Cardinal;
    TotalUnpackSize: UInt64;
    HasCrc: Boolean;
    Crc: UInt32;
  end;

  {** @desc folder 内子流（solid 归档按文件切分）元数据 *}
  TSevenZSubstream = record
    Size: UInt64;
    HasCrc: Boolean;
    Crc: UInt32;
  end;

  {** @desc pack 区信息：归档载荷的物理流布局 *}
  TSevenZPackInfo = record
    PackPos: UInt64;
    Sizes: array of UInt64;
    HasDigests: Boolean;
    DigestDefined: array of Boolean;
    Digests: array of UInt32;
  end;

  {** @desc 完整流信息：pack 布局 + 解码链 + 子流切分 *}
  TSevenZStreamsInfo = record
    Pack: TSevenZPackInfo;
    Folders: array of TSevenZFolder;
    SubCounts: array of UInt64;
    Substreams: array of TSevenZSubstream;
  end;

  {** @desc FilesInfo 解析产物：名称/标志/属性/时间戳原始位图 *}
  TSevenZFilesRaw = record
    Names: array of string;
    EmptyStream: array of Boolean;
    EmptyFile: array of Boolean;
    Anti: array of Boolean;
    HasAttributes: array of Boolean;
    Attributes: array of UInt32;
    HasMTime: array of Boolean;
    MTimesFILETIME: array of UInt64;
  end;

{ varint 解码：严格对齐 7-Zip ReadNumber 参考实现 }
function SevenZReadNumber(const ABuf: PByte; ALen: SizeUInt; var APos: SizeUInt): UInt64;

{ varint 编码：最小合法形式；AValue ≥ 2^56 走 FF + 8 字节小端 }
procedure SevenZWriteNumber(var AOut: TBytes; AValue: UInt64);

{ 追加单字节 / 定长整数到输出缓冲 — 单源复用 bytes 体系，单次扩容 + inline }
procedure SevenZAppendByte(var AOut: TBytes; AValue: Byte); inline;
procedure SevenZAppendUInt32BE(var AOut: TBytes; AValue: UInt32); inline;
procedure SevenZAppendUInt32LE(var AOut: TBytes; AValue: UInt32); inline;
procedure SevenZAppendUInt64LE(var AOut: TBytes; AValue: UInt64); inline;
procedure SevenZAppendBytes(var AOut: TBytes; const AData: PByte; ACount: SizeInt); inline;

type
  { 头部顺序读取器：越界统一抛 ESevenZError }
  TSevenZHeaderReader = class
private
  FBuf: PByte;
  FLen: SizeUInt;
  FPos: SizeUInt;
  procedure Need(ACount: SizeUInt);
public
  constructor Create(const ABuf: PByte; ALen: SizeUInt);
  function ReadByte: Byte;
  procedure Skip(ACount: SizeInt);
  { 切出定长子读取器（FilesInfo 的 TLV 属性载荷）；同时前进主位置 }
  function Slice(ACount: SizeInt): TSevenZHeaderReader;
  function ReadNumber: UInt64;
  function ReadUInt32: UInt32;
  function ReadUInt64: UInt64;
  procedure ReadBytes(out ADst: TBytes; ACount: SizeInt);
  { 位向量：每字节 8 位，高位在前 }
  procedure ReadBoolVector(ACount: SizeInt; out AVec: array of Boolean);
  { 带全定义捷径的位向量：首字节非零表示全真 }
  procedure ReadBoolVector2(ACount: SizeInt; out AVec: array of Boolean);
  function Remaining: SizeInt;
end;

{ 解析 StreamsInfo（PackInfo + UnpackInfo + SubStreamsInfo），直到并消费 kEnd }
procedure SevenZParseStreamsInfo(AReader: TSevenZHeaderReader;
  out AInfo: TSevenZStreamsInfo);

{ 解析 FilesInfo 属性区，直到并消费 kEnd }
procedure SevenZParseFilesInfo(AReader: TSevenZHeaderReader; ANumFiles: SizeInt;
  out ARaw: TSevenZFilesRaw);

implementation

uses
  nextpas.core.bytes.binary,
  nextpas.core.errors,
  nextpas.core.exception,
  nextpas.core.checksum.crc32,
  nextpas.core.sevenz.limits;



{ varint 解码：严格对齐 7-Zip ReadNumber 参考实现 }
function SevenZReadNumber(const ABuf: PByte; ALen: SizeUInt; var APos: SizeUInt): UInt64;
var
  LFirst: Byte;
  LMask: Byte;
  LI: Integer;
begin
  if APos >= ALen then
    raise ESevenZError.Create('header truncated');
  LFirst := ABuf[APos];
  Inc(APos);
  LMask := $80;
  Result := 0;
  {$PUSH}{$Q-}{$R-}
  for LI := 0 to 7 do
  begin
    if (LFirst and LMask) = 0 then
    begin
      Inc(Result, UInt64(LFirst and (LMask - 1)) shl (LI * 8));
      Exit;
    end;
    if APos >= ALen then
      raise ESevenZError.Create('header truncated');
    Result := Result or (UInt64(ABuf[APos]) shl (8 * LI));
    Inc(APos);
    LMask := LMask shr 1;
  end;
  {$POP}
end;

{ varint 编码实现 }

procedure SevenZWriteNumber(var AOut: TBytes; AValue: UInt64);
var
  LBase: SizeInt;
  LI: Integer;
  LT: Integer;
  LPayloadBits: Integer;
  LFirstPayload: UInt64;
begin
  { 总长 T 的容量为 2^(7T)；T=9（首字节 FF）覆盖全部 64 位。
    首字节负载位数为 8-T（T=8 时为 0），低字节一律小端。 }
  LT := 1;
  while (LT < 9) and (AValue >= (UInt64(1) shl (7 * LT))) do
    Inc(LT);
  LBase := Length(AOut);
  if LT <= 8 then
  begin
    LPayloadBits := 8 - LT;
    SetLength(AOut, LBase + LT);
    LFirstPayload := (AValue shr (8 * (LT - 1))) and
      ((UInt64(1) shl LPayloadBits) - 1);
    AOut[LBase] := Byte((Byte($FF shl (9 - LT)) and $FF) or Byte(LFirstPayload));
    for LI := 0 to LT - 2 do
      AOut[LBase + 1 + LI] := Byte((AValue shr (8 * LI)) and $FF);
    Exit;
  end;
  SetLength(AOut, LBase + 9);
  AOut[LBase] := $FF;
  for LI := 0 to 7 do
    AOut[LBase + 1 + LI] := Byte((AValue shr (8 * LI)) and $FF);
end;

procedure SevenZAppendByte(var AOut: TBytes; AValue: Byte); inline;
var
  LLen: SizeUInt;
begin
  LLen := Length(AOut);
  SetLength(AOut, LLen + 1);
  AOut[LLen] := AValue;
end;

procedure SevenZAppendUInt32BE(var AOut: TBytes; AValue: UInt32); inline;
var
  LLen: SizeUInt;
begin
  LLen := Length(AOut);
  SetLength(AOut, LLen + 4);
  WriteUInt32BE(@AOut[LLen], AValue);
end;

procedure SevenZAppendUInt32LE(var AOut: TBytes; AValue: UInt32); inline;
var
  LLen: SizeUInt;
begin
  LLen := Length(AOut);
  SetLength(AOut, LLen + 4);
  WriteUInt32LE(@AOut[LLen], AValue);
end;

procedure SevenZAppendUInt64LE(var AOut: TBytes; AValue: UInt64); inline;
var
  LLen: SizeUInt;
begin
  LLen := Length(AOut);
  SetLength(AOut, LLen + 8);
  WriteUInt64LE(@AOut[LLen], AValue);
end;

procedure SevenZAppendBytes(var AOut: TBytes; const AData: PByte; ACount: SizeInt); inline;
var
  LLen: SizeUInt;
begin
  if (ACount <= 0) or (AData = nil) then
    Exit;
  LLen := Length(AOut);
  SetLength(AOut, LLen + SizeUInt(ACount));
  Move(AData^, AOut[LLen], SizeUInt(ACount));
end;

{ TSevenZHeaderReader }

constructor TSevenZHeaderReader.Create(const ABuf: PByte; ALen: SizeUInt);
begin
  inherited Create;
  FBuf := ABuf;
  FLen := ALen;
  FPos := 0;
end;

procedure TSevenZHeaderReader.Need(ACount: SizeUInt);
begin
  if FPos + ACount > FLen then
    raise ESevenZError.Create('header truncated');
end;

function TSevenZHeaderReader.ReadByte: Byte;
begin
  Need(1);
  Result := FBuf[FPos];
  Inc(FPos);
end;

function TSevenZHeaderReader.ReadNumber: UInt64;
begin
  Result := SevenZReadNumber(FBuf, FLen, FPos);
end;

function TSevenZHeaderReader.ReadUInt32: UInt32;
var
  LI: Integer;
begin
  Need(4);
  Result := 0;
  { 头部多字节整数（含摘要）一律小端存储 }
  {$PUSH}{$Q-}{$R-}
  for LI := 0 to 3 do
    Result := Result or (UInt32(FBuf[FPos + LI]) shl (8 * LI));
  {$POP}
  Inc(FPos, 4);
end;

function TSevenZHeaderReader.ReadUInt64: UInt64;
var
  LI: Integer;
begin
  Need(8);
  Result := 0;
  {$PUSH}{$Q-}{$R-}
  for LI := 0 to 7 do
    Result := Result or (UInt64(FBuf[FPos + LI]) shl (8 * LI));
  {$POP}
  Inc(FPos, 8);
end;

procedure TSevenZHeaderReader.ReadBytes(out ADst: TBytes; ACount: SizeInt);
begin
  ADst := nil;
  if ACount < 0 then
    raise ESevenZError.Create('negative byte count in header');
  if ACount = 0 then
    Exit;
  Need(SizeUInt(ACount));
  SetLength(ADst, ACount);
  Move((FBuf + FPos)^, ADst[0], ACount);
  Inc(FPos, SizeUInt(ACount));
end;

procedure TSevenZHeaderReader.ReadBoolVector(ACount: SizeInt;
  out AVec: array of Boolean);
var
  LI: SizeInt;
  LByte: Byte;
  LBitIdx: Integer;
begin
  LI := 0;
  while LI < ACount do
  begin
    LByte := ReadByte;
    for LBitIdx := 7 downto 0 do
    begin
      if LI >= ACount then
        Break;
      {$PUSH}{$Q-}{$R-}
      AVec[LI] := ((LByte shr LBitIdx) and 1) <> 0;
      {$POP}
      Inc(LI);
    end;
  end;
end;

procedure TSevenZHeaderReader.ReadBoolVector2(ACount: SizeInt;
  out AVec: array of Boolean);
var
  LAllDefined: Byte;
  LI: SizeInt;
begin
  LAllDefined := ReadByte;
  if LAllDefined <> 0 then
  begin
    for LI := 0 to ACount - 1 do
      AVec[LI] := True;
    Exit;
  end;
  ReadBoolVector(ACount, AVec);
end;

function TSevenZHeaderReader.Remaining: SizeInt;
begin
  Result := SizeInt(FLen) - SizeInt(FPos);
end;

function TSevenZHeaderReader.Slice(ACount: SizeInt): TSevenZHeaderReader;
begin
  if (ACount < 0) or (SizeUInt(FPos) + SizeUInt(ACount) > FLen) then
    raise ESevenZError.Create('slice exceeds header bounds');
  Result := TSevenZHeaderReader.Create(FBuf + FPos, SizeUInt(ACount));
  Inc(FPos, SizeUInt(ACount));
end;


procedure TSevenZHeaderReader.Skip(ACount: SizeInt);
begin
  if ACount < 0 then
    raise ESevenZError.Create('negative skip count');
  Need(SizeUInt(ACount));
  Inc(FPos, SizeUInt(ACount));
end;

{ 内部小工具 }

function FlagsComplex(AFlags: Byte): Boolean; inline;
begin
  Result := (AFlags and $10) <> 0;
end;

function SubBaseOf(const AInfo: TSevenZStreamsInfo; AFolder: SizeInt): SizeInt;
var
  LI: SizeInt;
begin
  Result := 0;
  for LI := 0 to AFolder - 1 do
    Result := Result + SizeInt(AInfo.SubCounts[LI]);
end;

{ PackInfo }

procedure ParsePackInfo(AReader: TSevenZHeaderReader; out APack: TSevenZPackInfo);
var
  LNum: UInt64;
  LI: SizeInt;
  LId: UInt64;
  LDigestDefined: array of Boolean;
begin
  APack := Default(TSevenZPackInfo);
  APack.PackPos := AReader.ReadNumber;
  LNum := AReader.ReadNumber;
  if LNum > SEVENZ_MAX_PACK_STREAMS then
    raise ESevenZLimitError.Create('pack stream count out of range');
  if LNum > SEVENZ_MAX_CRC_COUNT then
    raise ESevenZLimitError.Create('pack crc count out of range');
  SetLength(APack.Sizes, LNum);
  SetLength(APack.DigestDefined, LNum);
  SetLength(APack.Digests, LNum);
  SetLength(LDigestDefined, LNum);
  while True do
  begin
    LId := AReader.ReadNumber;
    if LId = SZ_ID_END then
      Break;
    case LId of
      SZ_ID_SIZE:
        for LI := 0 to SizeInt(LNum) - 1 do
          APack.Sizes[LI] := AReader.ReadNumber;
      SZ_ID_CRC:
        begin
          AReader.ReadBoolVector2(SizeInt(LNum), LDigestDefined);
          for LI := 0 to SizeInt(LNum) - 1 do
            if LDigestDefined[LI] then
              APack.Digests[LI] := AReader.ReadUInt32;
          if LNum > 0 then
            Move(LDigestDefined[0], APack.DigestDefined[0], LNum * SizeOf(Boolean));
          APack.HasDigests := True;
        end
    else
      raise ESevenZError.CreateFmt('unknown pack info property %d', [LId]);
    end;
  end;
end;

{ Folder }

procedure ParseFolder(AReader: TSevenZHeaderReader; out AFolder: TSevenZFolder);
var
  LNumCoders: UInt64;
  LTotalIn: UInt64;
  LNumBindPairs: UInt64;
  LNumPacked: UInt64;
  LPropsSize: UInt64;
  LI: SizeInt;
  LJ: Integer;
  LFlags: Byte;
  LIdSize: Byte;
  LMethodBytes: TBytes;
  LUsedIn: array of Boolean;
  LFound: Boolean;
begin
  AFolder := Default(TSevenZFolder);
  LNumCoders := AReader.ReadNumber;
  if (LNumCoders = 0) or (LNumCoders > 64) then
    raise ESevenZError.Create('folder coder count out of range');
  SetLength(AFolder.Coders, LNumCoders);
  LTotalIn := 0;
  for LI := 0 to SizeInt(LNumCoders) - 1 do
  begin
    LFlags := AReader.ReadByte;
    LIdSize := LFlags and $0F;
    if LIdSize = 0 then
      raise ESevenZError.Create('empty method id');
    if (LFlags and $C0) <> 0 then
      raise ESevenZError.Create('coder flags high bits set (unsupported)');
    AFolder.Coders[LI].MethodId := 0;
    AReader.ReadBytes(LMethodBytes, LIdSize);
    for LJ := 0 to LIdSize - 1 do
      AFolder.Coders[LI].MethodId :=
        (AFolder.Coders[LI].MethodId shl 8) or LMethodBytes[LJ];
    if FlagsComplex(LFlags) then
    begin
      AFolder.Coders[LI].NumInStreams := Cardinal(AReader.ReadNumber);
      { 输出流数恒为 1，但字段存在必须消费 }
      if AReader.ReadNumber <> 1 then
        raise ESevenZError.Create('multi-output coder not supported');
    end
    else
      AFolder.Coders[LI].NumInStreams := 1;
    if AFolder.Coders[LI].NumInStreams = 0 then
      raise ESevenZError.Create('coder with zero input streams');
    Inc(LTotalIn, AFolder.Coders[LI].NumInStreams);
    AFolder.Coders[LI].Props := nil;
    if (LFlags and $20) <> 0 then
    begin
      LPropsSize := AReader.ReadNumber;
      if LPropsSize > SEVENZ_MAX_CODER_PROPS then
        raise ESevenZLimitError.Create('coder props too large');
      AReader.ReadBytes(AFolder.Coders[LI].Props, SizeInt(LPropsSize));
    end;
  end;
  { 绑定对数与 pack 流数均由 coder 拓扑推导（格式不存这两个字段）：
    绑定对数 = 输出流总数 - 1；pack 流数 = 总输入 - 绑定对 }
  if LNumCoders = 0 then
    raise ESevenZError.Create('empty folder');
  LNumBindPairs := LNumCoders - 1;
  SetLength(AFolder.BindPairs, LNumBindPairs);
  for LI := 0 to SizeInt(LNumBindPairs) - 1 do
  begin
    AFolder.BindPairs[LI].InIndex := Cardinal(AReader.ReadNumber);
    AFolder.BindPairs[LI].OutIndex := Cardinal(AReader.ReadNumber);
    if AFolder.BindPairs[LI].InIndex >= LTotalIn then
      raise ESevenZError.Create('bind pair InIndex out of range');
    if AFolder.BindPairs[LI].OutIndex >= LNumCoders then
      raise ESevenZError.Create('bind pair OutIndex out of range');
    for LJ := 0 to LI - 1 do
      if (AFolder.BindPairs[LJ].InIndex = AFolder.BindPairs[LI].InIndex) or
         (AFolder.BindPairs[LJ].OutIndex = AFolder.BindPairs[LI].OutIndex) then
        raise ESevenZError.Create('duplicate bind pair index');
  end;
  LNumPacked := LTotalIn - LNumBindPairs;
  SetLength(AFolder.PackedInIndices, LNumPacked);
  if LNumPacked = 1 then
  begin
    SetLength(LUsedIn, LTotalIn);
    for LI := 0 to SizeInt(LTotalIn) - 1 do
      LUsedIn[LI] := False;
    for LI := 0 to SizeInt(LNumBindPairs) - 1 do
      LUsedIn[AFolder.BindPairs[LI].InIndex] := True;
    LFound := False;
    for LI := 0 to SizeInt(LTotalIn) - 1 do
      if not LUsedIn[LI] then
      begin
        AFolder.PackedInIndices[0] := Cardinal(LI);
        LFound := True;
        Break;
      end;
    if not LFound then
      raise ESevenZError.Create('folder has no free input stream for pack data');
  end
  else
    for LI := 0 to SizeInt(LNumPacked) - 1 do
      AFolder.PackedInIndices[LI] := Cardinal(AReader.ReadNumber);
end;

procedure FinalizeFolder(var AFolder: TSevenZFolder);
var
  LI: SizeInt;
  LMainCandidates: array of Boolean;
  LFound: Integer;
begin
  if Length(AFolder.OutSizes) <> Length(AFolder.Coders) then
    raise ESevenZError.Create('folder output sizes missing');
  { 主输出流：未被任何绑定对引用的输出流 }
  SetLength(LMainCandidates, Length(AFolder.Coders));
  for LI := 0 to High(AFolder.Coders) do
    LMainCandidates[LI] := True;
  for LI := 0 to High(AFolder.BindPairs) do
  begin
    if AFolder.BindPairs[LI].OutIndex >= Cardinal(Length(LMainCandidates)) then
      raise ESevenZError.Create('bind pair out index out of range');
    LMainCandidates[AFolder.BindPairs[LI].OutIndex] := False;
  end;
  LFound := -1;
  for LI := 0 to High(AFolder.Coders) do
    if LMainCandidates[LI] then
    begin
      if LFound >= 0 then
        raise ESevenZError.Create('multiple main output streams in folder');
      LFound := LI;
    end;
  if LFound < 0 then
    raise ESevenZError.Create('no main output stream in folder');
  AFolder.MainOutIndex := Cardinal(LFound);
  AFolder.TotalUnpackSize := AFolder.OutSizes[LFound];
end;

procedure ParseUnpackInfo(AReader: TSevenZHeaderReader; var AInfo: TSevenZStreamsInfo);
var
  LNumFolders: UInt64;
  LExternal: Byte;
  LI: SizeInt;
  LJ: SizeInt;
  LId: UInt64;
  LCrcDefined: array of Boolean;
begin
  if AReader.ReadNumber <> SZ_ID_FOLDER then
    raise ESevenZError.Create('expected kFolder');
  LNumFolders := AReader.ReadNumber;
  if LNumFolders > SEVENZ_MAX_FOLDERS then
    raise ESevenZLimitError.Create('folder count out of range');
  if LNumFolders > SEVENZ_MAX_CRC_COUNT then
    raise ESevenZLimitError.Create('folder crc count out of range');
  LExternal := AReader.ReadByte;
  if LExternal <> 0 then
    raise ESevenZError.Create('external folders not supported');
  SetLength(AInfo.Folders, LNumFolders);
  for LI := 0 to SizeInt(LNumFolders) - 1 do
    ParseFolder(AReader, AInfo.Folders[LI]);
  while True do
  begin
    LId := AReader.ReadNumber;
    if LId = SZ_ID_END then
      Break;
    case LId of
      SZ_ID_CODERS_UNPACK_SZ:
        for LI := 0 to SizeInt(LNumFolders) - 1 do
        begin
          SetLength(AInfo.Folders[LI].OutSizes, Length(AInfo.Folders[LI].Coders));
          for LJ := 0 to High(AInfo.Folders[LI].Coders) do
            AInfo.Folders[LI].OutSizes[LJ] := AReader.ReadNumber;
          FinalizeFolder(AInfo.Folders[LI]);
        end;
      SZ_ID_CRC:
        begin
          SetLength(LCrcDefined, LNumFolders);
          AReader.ReadBoolVector2(SizeInt(LNumFolders), LCrcDefined);
          for LI := 0 to SizeInt(LNumFolders) - 1 do
          begin
            AInfo.Folders[LI].HasCrc := LCrcDefined[LI];
            if LCrcDefined[LI] then
              AInfo.Folders[LI].Crc := AReader.ReadUInt32;
          end;
        end;
    else
      raise ESevenZError.CreateFmt('unknown unpack info property %d', [LId]);
    end;
  end;
end;

{ SubStreamsInfo }

procedure AssignSubSizesFromFolders(var AInfo: TSevenZStreamsInfo);
var
  LI: SizeInt;
  LJ: SizeInt;
  LBase: SizeInt;
begin
  SetLength(AInfo.Substreams, 0);
  for LI := 0 to Length(AInfo.Folders) - 1 do
  begin
    LBase := Length(AInfo.Substreams);
    SetLength(AInfo.Substreams, LBase + SizeInt(AInfo.SubCounts[LI]));
    if AInfo.SubCounts[LI] = 0 then
      Continue;
    if AInfo.SubCounts[LI] = 1 then
    begin
      AInfo.Substreams[LBase].Size := AInfo.Folders[LI].TotalUnpackSize;
      AInfo.Substreams[LBase].HasCrc := AInfo.Folders[LI].HasCrc;
      AInfo.Substreams[LBase].Crc := AInfo.Folders[LI].Crc;
      Continue;
    end;
    for LJ := 0 to SizeInt(AInfo.SubCounts[LI]) - 1 do
      AInfo.Substreams[LBase + LJ].HasCrc := False;
  end;
end;

procedure ParseSubStreamsInfo(AReader: TSevenZHeaderReader;
  var AInfo: TSevenZStreamsInfo);
var
  LNumFolders: SizeInt;
  LI: SizeInt;
  LJ: SizeInt;
  LId: UInt64;
  LBase: SizeInt;
  LSum: UInt64;
  LHaveSizes: Boolean;
  LUnknownIndices: array of SizeInt;
  LCrcDefinedVec: array of Boolean;
begin
  LNumFolders := Length(AInfo.Folders);
  SetLength(AInfo.SubCounts, LNumFolders);
  for LI := 0 to LNumFolders - 1 do
    AInfo.SubCounts[LI] := 1;
  LHaveSizes := False;
  while True do
  begin
    LId := AReader.ReadNumber;
    if LId = SZ_ID_END then
      Break;
    case LId of
      SZ_ID_NUM_UNPACK_STREAM:
        begin
          for LI := 0 to LNumFolders - 1 do
          begin
            AInfo.SubCounts[LI] := AReader.ReadNumber;
            if AInfo.SubCounts[LI] > SEVENZ_MAX_FILE_COUNT then
              raise ESevenZLimitError.Create('substream count out of range');
          end;
          LSum := 0;
          for LI := 0 to LNumFolders - 1 do
          begin
            if LSum > High(UInt64) - AInfo.SubCounts[LI] then
              raise ESevenZLimitError.Create('substream count overflow');
            LSum := LSum + AInfo.SubCounts[LI];
            if LSum > SEVENZ_MAX_FILE_COUNT then
              raise ESevenZLimitError.Create('total substream count out of range');
          end;
        end;
      SZ_ID_SIZE:
        begin
          AssignSubSizesFromFolders(AInfo);
          for LI := 0 to LNumFolders - 1 do
          begin
            if AInfo.SubCounts[LI] <= 1 then
              Continue;
            LBase := SubBaseOf(AInfo, LI);
            LSum := 0;
            for LJ := 0 to SizeInt(AInfo.SubCounts[LI]) - 2 do
            begin
              AInfo.Substreams[LBase + LJ].Size := AReader.ReadNumber;
              if LSum > High(UInt64) - AInfo.Substreams[LBase + LJ].Size then
                raise ESevenZError.Create('substream size overflow');
              LSum := LSum + AInfo.Substreams[LBase + LJ].Size;
            end;
            if LSum > AInfo.Folders[LI].TotalUnpackSize then
              raise ESevenZError.Create('substream sizes exceed folder size');
            AInfo.Substreams[LBase + SizeInt(AInfo.SubCounts[LI]) - 1].Size :=
              AInfo.Folders[LI].TotalUnpackSize - LSum;
          end;
          LHaveSizes := True;
        end;
      SZ_ID_CRC:
        begin
          if not LHaveSizes then
            AssignSubSizesFromFolders(AInfo);
          { 收集尚无 CRC 的子流全局索引 }
          SetLength(LUnknownIndices, 0);
          for LI := 0 to Length(AInfo.Substreams) - 1 do
            if not AInfo.Substreams[LI].HasCrc then
            begin
              SetLength(LUnknownIndices, Length(LUnknownIndices) + 1);
              LUnknownIndices[High(LUnknownIndices)] := LI;
            end;
          if Length(LUnknownIndices) > SEVENZ_MAX_CRC_COUNT then
            raise ESevenZLimitError.Create('crc count out of range');
          SetLength(LCrcDefinedVec, Length(LUnknownIndices));
          AReader.ReadBoolVector2(Length(LUnknownIndices), LCrcDefinedVec);
          for LI := 0 to High(LUnknownIndices) do
            if LCrcDefinedVec[LI] then
            begin
              AInfo.Substreams[LUnknownIndices[LI]].Crc := AReader.ReadUInt32;
              AInfo.Substreams[LUnknownIndices[LI]].HasCrc := True;
            end;
        end;
    else
      raise ESevenZError.CreateFmt('unknown substream property %d', [LId]);
    end;
  end;
  if not LHaveSizes then
    AssignSubSizesFromFolders(AInfo);
end;

procedure SevenZParseStreamsInfo(AReader: TSevenZHeaderReader;
  out AInfo: TSevenZStreamsInfo);
var
  LId: UInt64;
  LI: SizeInt;
begin
  AInfo := Default(TSevenZStreamsInfo);
  while True do
  begin
    LId := AReader.ReadNumber;
    case LId of
      SZ_ID_END:             Break;
      SZ_ID_PACK_INFO:       ParsePackInfo(AReader, AInfo.Pack);
      SZ_ID_UNPACK_INFO:     ParseUnpackInfo(AReader, AInfo);
      SZ_ID_SUBSTREAMS_INFO: ParseSubStreamsInfo(AReader, AInfo);
    else
      raise ESevenZError.CreateFmt('unknown streams info property %d', [LId]);
    end;
  end;
  { 缺 kCodersUnpackSize 的 folder 无法执行解码链，在此统一拦截 }
  for LI := 0 to Length(AInfo.Folders) - 1 do
    if Length(AInfo.Folders[LI].OutSizes) <>
       Length(AInfo.Folders[LI].Coders) then
      raise ESevenZError.Create('folder output sizes missing');
end;

{ FilesInfo }

{ FilesInfo 自 7-Zip 新版起为 TLV 结构：[id][varint size][定长载荷]。
  载荷内部保持经典布局；载荷尾部未消费字节按规范容忍（对齐填充）。 }
procedure SevenZParseFilesInfo(AReader: TSevenZHeaderReader; ANumFiles: SizeInt;
  out ARaw: TSevenZFilesRaw);
var
  LId: UInt64;
  LSize: UInt64;
  LSub: TSevenZHeaderReader;
  LExternal: Byte;
  LI: SizeInt;
  LMapCount: SizeInt;
  LMapIdx: SizeInt;
  LEmptyFileVec: array of Boolean;
  LAntiVec: array of Boolean;
  LWAttrDef: array of Boolean;
  LTimeDef: array of Boolean;

  procedure ParseNames(ASub: TSevenZHeaderReader);
  var
    LN: SizeInt;
    LW: SizeInt;
    LUnitBuf: TBytes;
    LUsed: SizeInt;
    LCap: SizeInt;
  begin
    if ASub.ReadByte <> 0 then
      raise ESevenZError.Create('external names not supported');
    LUnitBuf := nil;
    for LN := 0 to ANumFiles - 1 do
    begin
      { 手动容量跟踪的几何扩容：逐单元 SetLength 会退化为平方级拷贝 }
      LUsed := 0;
      LCap := 0;
      while True do
      begin
        if ASub.Remaining < 2 then
          raise ESevenZError.Create('unterminated entry name');
        LW := SizeInt(ASub.ReadByte) or (SizeInt(ASub.ReadByte) shl 8);
        if LW = 0 then
          Break;
        if LCap < LUsed + 2 then
        begin
          LCap := LUsed * 2 + 64;
          SetLength(LUnitBuf, LCap);
        end;
        LUnitBuf[LUsed] := Byte(LW and $FF);
        LUnitBuf[LUsed + 1] := Byte((LW shr 8) and $FF);
        Inc(LUsed, 2);
      end;
      SetLength(LUnitBuf, LUsed);
      ARaw.Names[LN] := SevenZUtf16LeToUtf8(LUnitBuf);
    end;
  end;

begin
  ARaw := Default(TSevenZFilesRaw);
  SetLength(ARaw.Names, ANumFiles);
  SetLength(ARaw.EmptyStream, ANumFiles);
  SetLength(ARaw.EmptyFile, ANumFiles);
  SetLength(ARaw.Anti, ANumFiles);
  SetLength(ARaw.HasAttributes, ANumFiles);
  SetLength(ARaw.Attributes, ANumFiles);
  SetLength(ARaw.HasMTime, ANumFiles);
  SetLength(ARaw.MTimesFILETIME, ANumFiles);
  while True do
  begin
    LId := AReader.ReadNumber;
    if LId = SZ_ID_END then
      Break;
    LSize := AReader.ReadNumber;
    if LSize > UInt64(AReader.Remaining) then
      raise ESevenZError.CreateFmt(
        'file property %d payload overruns header', [LId]);
    LSub := AReader.Slice(SizeInt(LSize));
    try
      case LId of
        SZ_ID_EMPTY_STREAM:
          LSub.ReadBoolVector(ANumFiles, ARaw.EmptyStream);
        SZ_ID_EMPTY_FILE, SZ_ID_ANTI:
          begin
            { 位图覆盖 empty-stream 条目集合，顺序映射回全局条目。
              kEmptyFile 为纯位向量；kAnti 带 allDefined 前缀（与 7z 一致） }
            LMapCount := 0;
            for LI := 0 to ANumFiles - 1 do
              if ARaw.EmptyStream[LI] then
                Inc(LMapCount);
            SetLength(LEmptyFileVec, LMapCount);
            SetLength(LAntiVec, LMapCount);
            if LId = SZ_ID_EMPTY_FILE then
              LSub.ReadBoolVector(LMapCount, LEmptyFileVec)
            else
              LSub.ReadBoolVector2(LMapCount, LAntiVec);
            LMapIdx := 0;
            for LI := 0 to ANumFiles - 1 do
              if ARaw.EmptyStream[LI] then
              begin
                if LId = SZ_ID_EMPTY_FILE then
                  ARaw.EmptyFile[LI] := LEmptyFileVec[LMapIdx]
                else
                  ARaw.Anti[LI] := LAntiVec[LMapIdx];
                Inc(LMapIdx);
              end;
          end;
        SZ_ID_NAME:
          ParseNames(LSub);
        SZ_ID_WIN_ATTRIBUTES:
          begin
            SetLength(LWAttrDef, ANumFiles);
            LSub.ReadBoolVector2(ANumFiles, LWAttrDef);
            LExternal := LSub.ReadByte;
            if LExternal <> 0 then
              raise ESevenZError.Create('external attributes not supported');
            for LI := 0 to ANumFiles - 1 do
            begin
              ARaw.HasAttributes[LI] := LWAttrDef[LI];
              if LWAttrDef[LI] then
                ARaw.Attributes[LI] := LSub.ReadUInt32;
            end;
          end;
        SZ_ID_MTIME, SZ_ID_CTIME, SZ_ID_ATIME:
          begin
            SetLength(LTimeDef, ANumFiles);
            LSub.ReadBoolVector2(ANumFiles, LTimeDef);
            LExternal := LSub.ReadByte;
            if LExternal <> 0 then
              raise ESevenZError.Create('external times not supported');
            SetLength(ARaw.MTimesFILETIME, ANumFiles);
            for LI := 0 to ANumFiles - 1 do
            begin
              if LId = SZ_ID_MTIME then
                ARaw.HasMTime[LI] := LTimeDef[LI];
              if LTimeDef[LI] then
                ARaw.MTimesFILETIME[LI] := LSub.ReadUInt64;
            end;
          end;
        SZ_ID_DUMMY:
          ;  { 对齐填充，零字节 }
      end;
      { 载荷尾部未消费字节：对齐填充，按规范容忍并丢弃 }
    finally
      LSub.Free;
    end;
  end;
end;

end.
