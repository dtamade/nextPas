unit nextpas.core.sevenz.reader;

{**
 * nextpas.core.sevenz.reader - 7z 归档读端实现
 *
 * 负责签名头/起始头校验、主头与编码头解析、条目装配（目录/空文件/流文件
 * 到 folder 子流的映射）、按需解码与 CRC 校验。签名头字段全部小端。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.base,
  nextpas.core.io.intf,
  nextpas.core.sevenz.base,
  nextpas.core.sevenz.intf,
  nextpas.core.sevenz.header;

type
  {** @desc ISevenZReader 默认实现 *}
  TSevenZReaderImpl = class(TInterfacedObject, ISevenZReader)
  private
    FArchive: TBytes;
    FRawFiles: TSevenZFilesRaw;
    FStreams: TSevenZStreamsInfo;
    FEntries: array of TSevenZEntryInfo;
    FFolderIdxOfEntry: array of Integer;   { 非空文件 -> folder 序号；空/目录为 -1 }
    FGlobalSubOfEntry: array of SizeInt;   { 非空文件 -> 全局子流序号 }
    FSubBaseOfFolder: array of SizeInt;    { folder -> 全局子流基址（前缀和） }
    FEntryOffInFolder: array of SizeInt;   { 非空文件 -> 子流在 folder 输出内偏移 }
    FPackStartOfFolder: array of Integer;  { folder -> 首 pack 流序号 }
    FPackOffsetOfFolder: array of UInt64;  { folder -> 首 pack 流绝对载荷偏移 }
    FCacheIdx: array[0..1] of Integer;     { 2-entry MRU 缓存：0 为 MRU }
    FCacheData: array[0..1] of TBytes;
    FPassword: string;
    procedure ParseArchive;
    procedure ParseHeaderBlock(const AHeaderData: TBytes);
    procedure AssembleEntries;
    procedure CopyPackSlices(APackPos: UInt64; var ASlices: array of TBytes);
    function DecodeFolder(AFolderIdx: Integer): TBytes;
    function EntrySlice(AIndex: Integer): TBytes;
  public
    constructor Create(const AArchive: TBytes);
    constructor CreateWithPassword(const AArchive: TBytes;
      const APassword: string);
    constructor CreateFromReader(const AReader: IReader);
    constructor CreateFromReaderWithPassword(const AReader: IReader;
      const APassword: string);
    destructor Destroy; override;
    function EntryCount: Integer;
    function Entry(AIndex: Integer): TSevenZEntryInfo;
    function Find(const AName: string): Integer;
    function FindIgnoreCase(const AName: string): Integer;
    function Contains(const AName: string): Boolean;
    function ContainsIgnoreCase(const AName: string): Boolean;
    function TryGetEntry(const AName: string; out AInfo: TSevenZEntryInfo): Boolean;
    function TryEntryByName(const AName: string; out AInfo: TSevenZEntryInfo): Boolean;
    function TryGetEntryIgnoreCase(const AName: string; out AInfo: TSevenZEntryInfo): Boolean;
    function EntryByName(const AName: string): TSevenZEntryInfo;
    function EntryByNameIgnoreCase(const AName: string): TSevenZEntryInfo;
    function GetIsEmpty: Boolean;
    function GetEntries: TSevenZEntryInfoArray;
    function Extract(AIndex: Integer): TBytes;
    function ExtractTo(const AWriter: IWriter; AIndex: Integer): Int64;
    function OpenStream(AIndex: Integer): IStream;
    function TryExtract(AIndex: Integer; out AData: TBytes): Boolean;
    function TryExtractTo(const AWriter: IWriter; AIndex: Integer;
      out ABytesWritten: Int64): Boolean;
    function TryExtractWithError(AIndex: Integer; out AData: TBytes;
      out AError: string): Boolean;
    function TryExtractToWithError(const AWriter: IWriter; AIndex: Integer;
      out ABytesWritten: Int64; out AError: string): Boolean;
    function TryOpenStream(AIndex: Integer; out AStream: IStream): Boolean;
    function TryOpenStreamWithError(AIndex: Integer; out AStream: IStream;
      out AError: string): Boolean;
    function GetEnumerator: TSevenZEntryEnumerator;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.exception,
  nextpas.core.base.utils,
  nextpas.core.checksum.crc32,
  nextpas.core.io.util,
  nextpas.core.sevenz.coders,
  nextpas.core.sevenz.limits;

type
  {** @desc 条目只读流：持有 Extract 产出的缓冲引用（不二次拷贝），
      Read/Seek/Size/Position 语义逐条对齐 TBytesStream：
      Close 后访问 raise、Close 幂等、Seek 负位抛参数错误。
      写入一律 ENotSupportedError——归档内容不可变 *}
  TSevenZEntryStream = class(TInterfacedObject, IStream)
  private
    FData: TBytes;
    FPosition: SizeUInt;
    FClosed: Boolean;
    procedure EnsureOpen(const AOperation: string);
  public
    constructor Create(const AData: TBytes);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
    procedure Close;
    function GetSize: Int64;
    function GetPosition: Int64;
    procedure SetPosition(const AValue: Int64);
  end;

constructor TSevenZEntryStream.Create(const AData: TBytes);
begin
  inherited Create;
  FData := AData;
  FPosition := 0;
  FClosed := False;
end;

procedure TSevenZEntryStream.EnsureOpen(const AOperation: string);
begin
  if FClosed then
    raise EIOError.Create('TSevenZEntryStream.' + AOperation +
      ': stream is closed');
end;

function TSevenZEntryStream.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LAvailable: SizeUInt;
begin
  EnsureOpen('Read');
  if ACount = 0 then
    Exit(0);
  if FPosition >= SizeUInt(Length(FData)) then
    Exit(0);
  LAvailable := SizeUInt(Length(FData)) - FPosition;
  if ACount < LAvailable then
    Result := ACount
  else
    Result := LAvailable;
  Move(FData[FPosition], ABuf, Result);
  Inc(FPosition, Result);
end;

function TSevenZEntryStream.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  EnsureOpen('Write');
  Result := 0;
  raise ENotSupportedError.Create(
    'TSevenZEntryStream.Write: entry stream is read-only');
end;

function TSevenZEntryStream.Seek(const AOffset: Int64;
  const AOrigin: TSeekOrigin): Int64;
var
  LNewPos: Int64;
begin
  EnsureOpen('Seek');
  case AOrigin of
    soBeginning: LNewPos := AOffset;
    soCurrent: LNewPos := Int64(FPosition) + AOffset;
    else LNewPos := Int64(Length(FData)) + AOffset;
  end;
  if LNewPos < 0 then
    raise EArgumentError.Create('TSevenZEntryStream.Seek: negative position');
  FPosition := SizeUInt(LNewPos);
  Result := LNewPos;
end;

procedure TSevenZEntryStream.Close;
begin
  if not FClosed then
  begin
    FClosed := True;
    FData := nil;
    FPosition := 0;
  end;
end;

function TSevenZEntryStream.GetSize: Int64;
begin
  Result := Int64(Length(FData));
end;

function TSevenZEntryStream.GetPosition: Int64;
begin
  Result := Int64(FPosition);
end;

procedure TSevenZEntryStream.SetPosition(const AValue: Int64);
begin
  EnsureOpen('SetPosition');
  if AValue < 0 then
    raise EArgumentError.Create(
      'TSevenZEntryStream.SetPosition: negative position');
  FPosition := SizeUInt(AValue);
end;

const
  C_DEFAULT_MAX_OUTPUT = SEVENZ_DEFAULT_MAX_OUTPUT;
  C_MAX_HEADER_SIZE = SEVENZ_MAX_HEADER_SIZE;
  C_EXTRACT_WINDOW = SEVENZ_EXTRACT_WINDOW;

constructor TSevenZReaderImpl.Create(const AArchive: TBytes);
begin
  inherited Create;
  FArchive := AArchive;
  FCacheIdx[0] := -1; FCacheIdx[1] := -1;
  ParseArchive;
end;

constructor TSevenZReaderImpl.CreateWithPassword(const AArchive: TBytes;
  const APassword: string);
begin
  inherited Create;
  FArchive := AArchive;
  FCacheIdx[0] := -1; FCacheIdx[1] := -1;
  FPassword := APassword;
  ParseArchive;
end;

constructor TSevenZReaderImpl.CreateFromReader(const AReader: IReader);
begin
  CreateFromReaderWithPassword(AReader, '');
end;

constructor TSevenZReaderImpl.CreateFromReaderWithPassword(const AReader: IReader;
  const APassword: string);
var
  LBytes: TBytes;
begin
  if AReader = nil then
    raise EArgumentError.Create('TSevenZReaderImpl.CreateFromReader: AReader is nil');
  LBytes := IoReadAll(AReader);
  inherited Create;
  FArchive := LBytes;
  FCacheIdx[0] := -1; FCacheIdx[1] := -1;
  FPassword := APassword;
  ParseArchive;
end;

destructor TSevenZReaderImpl.Destroy;
begin
  inherited Destroy;
end;

procedure TSevenZReaderImpl.ParseArchive;
var
  LP: PByte;
  LLen: SizeUInt;
  LStartCrcStored: UInt32;
  LNextCrcStored: UInt32;
  LOffset, LSize: UInt64;
  LHeaderRaw: TBytes;
begin
  LLen := SizeUInt(Length(FArchive));
  if LLen < C_SEVENZ_SIG_HEADER_SIZE then
    raise ESevenZError.Create('archive smaller than signature header');
  LP := @FArchive[0];
  if (LP[0] <> C_SEVENZ_MAGIC_0) or (LP[1] <> C_SEVENZ_MAGIC_1) or
     (LP[2] <> C_SEVENZ_MAGIC_2) or (LP[3] <> C_SEVENZ_MAGIC_3) or
     (LP[4] <> C_SEVENZ_MAGIC_4) or (LP[5] <> C_SEVENZ_MAGIC_5) then
    raise ESevenZError.Create('bad 7z signature');
  if (LP[6] <> C_SEVENZ_VERSION_MAJOR) or (LP[7] > C_SEVENZ_VERSION_MINOR) then
    raise ESevenZError.Create('unsupported 7z version');
  {$PUSH}{$Q-}{$R-}
  { 签名头布局（全小端）：[0..5]=magic [6..7]=版本 [8..11]=起始头CRC
    [12..19]=NextHeaderOffset [20..27]=NextHeaderSize [28..31]=NextHeaderCRC }
  LStartCrcStored := UInt32(LP[8]) or (UInt32(LP[9]) shl 8) or
    (UInt32(LP[10]) shl 16) or (UInt32(LP[11]) shl 24);
  LOffset := UInt64(LP[12]) or (UInt64(LP[13]) shl 8) or
    (UInt64(LP[14]) shl 16) or (UInt64(LP[15]) shl 24) or
    (UInt64(LP[16]) shl 32) or (UInt64(LP[17]) shl 40) or
    (UInt64(LP[18]) shl 48) or (UInt64(LP[19]) shl 56);
  LSize := UInt64(LP[20]) or (UInt64(LP[21]) shl 8) or
    (UInt64(LP[22]) shl 16) or (UInt64(LP[23]) shl 24) or
    (UInt64(LP[24]) shl 32) or (UInt64(LP[25]) shl 40) or
    (UInt64(LP[26]) shl 48) or (UInt64(LP[27]) shl 56);
  LNextCrcStored := UInt32(LP[28]) or (UInt32(LP[29]) shl 8) or
    (UInt32(LP[30]) shl 16) or (UInt32(LP[31]) shl 24);
  {$POP}
  { 起始头为签名头末 20 字节（偏移 12..31），其 CRC 存于偏移 8..11 }
  if Crc32Of((LP + 12)^, 20) <> LongWord(LStartCrcStored) then
    raise ESevenZError.Create('start header CRC mismatch');
  if LSize = 0 then
    raise ESevenZError.Create('archive has no header');
  if LSize > C_MAX_HEADER_SIZE then
    raise ESevenZLimitError.CreateFmt(
      'header size %d exceeds limit %d', [LSize, C_MAX_HEADER_SIZE]);
  if LOffset > LLen - C_SEVENZ_SIG_HEADER_SIZE then
    raise ESevenZError.Create('header offset past end of archive');
  if LSize > LLen - C_SEVENZ_SIG_HEADER_SIZE - LOffset then
    raise ESevenZError.Create('header extends past end of archive');
  SetLength(LHeaderRaw, SizeInt(LSize));
  Move((LP + SizeUInt(C_SEVENZ_SIG_HEADER_SIZE) + SizeUInt(LOffset))^,
    LHeaderRaw[0], SizeInt(LSize));
  if Crc32OfBytes(LHeaderRaw) <> LongWord(LNextCrcStored) then
    raise ESevenZError.Create('header CRC mismatch');
  ParseHeaderBlock(LHeaderRaw);
end;

procedure TSevenZReaderImpl.ParseHeaderBlock(const AHeaderData: TBytes);
var
  LR: TSevenZHeaderReader;
  LId: UInt64;
  LPropId: UInt64;
  LPropSize: UInt64;
  LEncodedStreams: TSevenZStreamsInfo;
  LI: SizeInt;
  LPackSlices: array of TBytes;
  LDecoded: TBytes;
begin
  LR := nil;
  try
    LR := TSevenZHeaderReader.Create(@AHeaderData[0],
      SizeUInt(Length(AHeaderData)));
    LId := LR.ReadNumber;
    if LId = SZ_ID_ENCODED_HEADER then
    begin
      SevenZParseStreamsInfo(LR, LEncodedStreams);
      if Length(LEncodedStreams.Folders) <> 1 then
        raise ESevenZError.Create('encoded header must have exactly one folder');
      SetLength(LPackSlices,
        Length(LEncodedStreams.Folders[0].PackedInIndices));
      for LI := 0 to High(LPackSlices) do
        SetLength(LPackSlices[LI],
          SizeInt(LEncodedStreams.Pack.Sizes[LI]));
      CopyPackSlices(LEncodedStreams.Pack.PackPos, LPackSlices);
      LDecoded := SevenZDecodeFolder(LEncodedStreams.Folders[0], LPackSlices,
        FPassword);
      if LEncodedStreams.Folders[0].HasCrc and
         (Crc32OfBytes(LDecoded) <>
          LongWord(LEncodedStreams.Folders[0].Crc)) then
        raise ESevenZError.Create('encoded header CRC mismatch');
      FreeAndNil(LR);
      LR := TSevenZHeaderReader.Create(@LDecoded[0],
        SizeUInt(Length(LDecoded)));
      LId := LR.ReadNumber;
    end;
    if LId <> SZ_ID_HEADER then
      raise ESevenZError.Create('expected header block');
    while True do
    begin
      LId := LR.ReadNumber;
      case LId of
        SZ_ID_END:
          Break;
        SZ_ID_ARCHIVE_PROPS:
          begin
            while True do
            begin
              LPropId := LR.ReadNumber;
              if LPropId = SZ_ID_END then
                Break;
              LPropSize := LR.ReadNumber;
              LR.Skip(SizeInt(LPropSize));
            end;
          end;
        SZ_ID_ADD_STREAMS_INFO:
          SevenZParseStreamsInfo(LR, LEncodedStreams);
        SZ_ID_MAIN_STREAMS:
          SevenZParseStreamsInfo(LR, FStreams);
        SZ_ID_FILES_INFO:
          begin
            LId := LR.ReadNumber;
            if LId > UInt64(SEVENZ_MAX_FILE_COUNT) then
              raise ESevenZLimitError.Create('file count out of range');
            SevenZParseFilesInfo(LR, SizeInt(LId), FRawFiles);
          end;
      else
        raise ESevenZError.CreateFmt('unknown header property %d', [LId]);
      end;
    end;
  finally
    LR.Free;
  end;
  AssembleEntries;
end;

procedure TSevenZReaderImpl.CopyPackSlices(APackPos: UInt64;
  var ASlices: array of TBytes);
var
  LI: SizeInt;
  LOpt: SizeUInt;
  LSrcOff: SizeUInt;
begin
  LSrcOff := SizeUInt(C_SEVENZ_SIG_HEADER_SIZE) + APackPos;
  for LI := 0 to High(ASlices) do
  begin
    LOpt := LSrcOff + SizeUInt(Length(ASlices[LI]));
    if LOpt > SizeUInt(Length(FArchive)) then
      raise ESevenZError.Create('pack stream overruns archive');
    if Length(ASlices[LI]) > 0 then
      Move(FArchive[LSrcOff], ASlices[LI][0], Length(ASlices[LI]));
    Inc(LSrcOff, SizeUInt(Length(ASlices[LI])));
  end;
end;

procedure TSevenZReaderImpl.AssembleEntries;
var
  LN: SizeInt;
  LI: SizeInt;
  LJ: SizeInt;
  LE: TSevenZEntryInfo;
  LSubCursor: SizeInt;
  LByteAcc: SizeInt;
  LBaseAcc: SizeInt;
  LAcc: SizeInt;
  LFolderScan: Integer;
begin
  LN := Length(FRawFiles.Names);
  if LN > SEVENZ_MAX_FILE_COUNT then
    raise ESevenZLimitError.CreateFmt(
      'file count %d exceeds limit %d', [LN, SEVENZ_MAX_FILE_COUNT]);
  for LI := 0 to LN - 1 do
    if Length(FRawFiles.Names[LI]) > SEVENZ_MAX_NAME_BYTES then
      raise ESevenZLimitError.CreateFmt(
        'name %d length %d exceeds limit', [LI, Length(FRawFiles.Names[LI])]);
  SetLength(FEntries, LN);
  SetLength(FFolderIdxOfEntry, LN);
  SetLength(FGlobalSubOfEntry, LN);
  SetLength(FEntryOffInFolder, LN);
  { folder 到 pack 流的静态分配（folder 按顺序消费 pack 流，
    每 folder 的载荷起点累加此前全部 pack 流尺寸） }
  SetLength(FPackStartOfFolder, Length(FStreams.Folders));
  SetLength(FPackOffsetOfFolder, Length(FStreams.Folders));
  LJ := 0;
  LAcc := 0;
  for LI := 0 to High(FStreams.Folders) do
  begin
    FPackStartOfFolder[LI] := LJ;
    FPackOffsetOfFolder[LI] := FStreams.Pack.PackPos + UInt64(LAcc);
    while LJ < Length(FStreams.Pack.Sizes) do
    begin
      if Length(FStreams.Folders[LI].PackedInIndices) = 0 then
        Break;
      if LJ >= FPackStartOfFolder[LI] +
         Length(FStreams.Folders[LI].PackedInIndices) then
        Break;
      LAcc := LAcc + SizeInt(FStreams.Pack.Sizes[LJ]);
      Inc(LJ);
    end;
  end;
  if LJ <> Length(FStreams.Pack.Sizes) then
    raise ESevenZError.Create('pack stream assignment mismatch');
  if UInt64(LAcc) > C_DEFAULT_MAX_OUTPUT then
    raise ESevenZLimitError.CreateFmt(
      'pack total %d exceeds limit %d', [UInt64(LAcc), C_DEFAULT_MAX_OUTPUT]);
  for LI := 0 to High(FStreams.Pack.Sizes) do
    if FStreams.Pack.Sizes[LI] > C_MAX_HEADER_SIZE then
      raise ESevenZLimitError.CreateFmt(
        'pack stream %d size %d exceeds limit', [LI, FStreams.Pack.Sizes[LI]]);
  { 子流基址前缀和：folder -> 全局子流基址，O(1) 定位条目窗口 }
  SetLength(FSubBaseOfFolder, Length(FStreams.Folders));
  LBaseAcc := 0;
  for LI := 0 to High(FStreams.Folders) do
  begin
    FSubBaseOfFolder[LI] := LBaseAcc;
    Inc(LBaseAcc, SizeInt(FStreams.SubCounts[LI]));
  end;
  { 条目装配：非空条目按顺序消费子流 }
  LSubCursor := 0;
  LByteAcc := 0;
  LFolderScan := 0;
  for LI := 0 to LN - 1 do
  begin
    LE := Default(TSevenZEntryInfo);
    LE.Name := FRawFiles.Names[LI];
    FFolderIdxOfEntry[LI] := -1;
    FGlobalSubOfEntry[LI] := -1;
    FEntryOffInFolder[LI] := -1;
    if FRawFiles.EmptyStream[LI] then
    begin
      if FRawFiles.EmptyFile[LI] or FRawFiles.Anti[LI] then
      begin
        LE.Kind := sekFile;
        if FRawFiles.HasAttributes[LI] then
        begin
          LE.HasAttributes := True;
          LE.Attributes := FRawFiles.Attributes[LI];
        end;
      end
      else
      begin
        LE.Kind := sekDirectory;
        if FRawFiles.HasAttributes[LI] then
        begin
          LE.HasAttributes := True;
          LE.Attributes :=
            FRawFiles.Attributes[LI] or SEVENZ_ATTR_DIRECTORY;
        end
        else
        begin
          LE.HasAttributes := True;
          LE.Attributes := SEVENZ_ATTR_DIRECTORY;
        end;
      end;
    end
    else
    begin
      LE.Kind := sekFile;
      while (LFolderScan < Length(FStreams.SubCounts)) and
            ((FSubBaseOfFolder[LFolderScan] +
              SizeInt(FStreams.SubCounts[LFolderScan])) <= LSubCursor) do
      begin
        Inc(LFolderScan);
        LByteAcc := 0;               { 进入新 folder：字节累加器归零 }
      end;
      if (LFolderScan >= Length(FStreams.SubCounts)) or
         (LSubCursor >= FSubBaseOfFolder[LFolderScan] +
            SizeInt(FStreams.SubCounts[LFolderScan])) then
        raise ESevenZError.Create('entry exceeds declared substream count');
      FFolderIdxOfEntry[LI] := LFolderScan;
      FGlobalSubOfEntry[LI] := LSubCursor;
      { folder 输出内字节偏移：此前同 folder 子流尺寸之和 }
      FEntryOffInFolder[LI] := LByteAcc;
      LE.Size := Int64(FStreams.Substreams[LSubCursor].Size);
      Inc(LByteAcc, SizeInt(FStreams.Substreams[LSubCursor].Size));
      LE.HasCrc := FStreams.Substreams[LSubCursor].HasCrc;
      LE.Crc32 := FStreams.Substreams[LSubCursor].Crc;
      if FRawFiles.HasAttributes[LI] then
      begin
        LE.HasAttributes := True;
        LE.Attributes := FRawFiles.Attributes[LI];
      end;
      Inc(LSubCursor);
    end;
    LE.HasMTime := FRawFiles.HasMTime[LI];
    if LE.HasMTime then
      LE.MTimeUnixSec := SevenZFILETIMEToUnix(FRawFiles.MTimesFILETIME[LI])
    else
      LE.MTimeUnixSec := 0;
    FEntries[LI] := LE;
  end;
end;

function TSevenZReaderImpl.DecodeFolder(AFolderIdx: Integer): TBytes;
var
  LFolder: TSevenZFolder;
  LSlices: array of TBytes;
  LI: SizeInt;
  LPackIdx: Integer;
  LTmpIdx: Integer;
  LTmpData: TBytes;
begin
  if FCacheIdx[0] = AFolderIdx then
    Exit(FCacheData[0]);
  if FCacheIdx[1] = AFolderIdx then
  begin
    LTmpIdx := FCacheIdx[1]; LTmpData := FCacheData[1];
    FCacheIdx[1] := FCacheIdx[0]; FCacheData[1] := FCacheData[0];
    FCacheIdx[0] := LTmpIdx; FCacheData[0] := LTmpData;
    Exit(FCacheData[0]);
  end;
  LFolder := FStreams.Folders[AfolderIdx];
  if LFolder.TotalUnpackSize > C_DEFAULT_MAX_OUTPUT then
    raise ESevenZLimitError.CreateFmt(
      'folder unpack size %d exceeds limit', [LFolder.TotalUnpackSize]);
  SetLength(LSlices, Length(LFolder.PackedInIndices));
  for LI := 0 to High(LSlices) do
  begin
    LPackIdx := FPackStartOfFolder[AfolderIdx] + LI;
    if (LPackIdx < 0) or (LPackIdx >= Length(FStreams.Pack.Sizes)) then
      raise ESevenZError.Create('pack stream index out of range');
    SetLength(LSlices[LI], SizeInt(FStreams.Pack.Sizes[LPackIdx]));
  end;
  CopyPackSlices(FPackOffsetOfFolder[AfolderIdx], LSlices);
  { 存在摘要则逐流校验 }
  if FStreams.Pack.HasDigests then
    for LI := 0 to High(LSlices) do
    begin
      LPackIdx := FPackStartOfFolder[AfolderIdx] + LI;
      if FStreams.Pack.DigestDefined[LPackIdx] and
         (Crc32OfBytes(LSlices[LI]) <>
          LongWord(FStreams.Pack.Digests[LPackIdx])) then
        raise ESevenZError.CreateFmt('pack stream %d CRC mismatch', [LPackIdx]);
    end;
  Result := SevenZDecodeFolder(LFolder, LSlices, FPassword);
  if LFolder.HasCrc and
     (Crc32OfBytes(Result) <> LongWord(LFolder.Crc)) then
    raise ESevenZError.Create('folder CRC mismatch after decode');
  FCacheIdx[1] := FCacheIdx[0]; FCacheData[1] := FCacheData[0];
  FCacheIdx[0] := AfolderIdx; FCacheData[0] := Result;
end;

function TSevenZReaderImpl.EntrySlice(AIndex: Integer): TBytes;
var
  LFolderIdx: Integer;
  LGsub: SizeInt;
  LData: TBytes;
  LOff: SizeInt;
  LLen: SizeInt;
begin
  Result := nil;
  LFolderIdx := FFolderIdxOfEntry[AIndex];
  if LFolderIdx < 0 then
    Exit(nil);
  LGsub := FGlobalSubOfEntry[AIndex];
  LData := DecodeFolder(LFolderIdx);
  LOff := FEntryOffInFolder[AIndex];
  LLen := SizeInt(FStreams.Substreams[LGsub].Size);
  if LOff + LLen > Length(LData) then
    raise ESevenZError.Create('substream window exceeds folder output');
  SetLength(Result, LLen);
  if LLen > 0 then
    Move(LData[LOff], Result[0], LLen);
  if FStreams.Substreams[LGsub].HasCrc and
     (Crc32OfBytes(Result) <> LongWord(FStreams.Substreams[LGsub].Crc)) then
    raise ESevenZError.CreateFmt('entry %d CRC mismatch', [AIndex]);
end;

function TSevenZReaderImpl.EntryCount: Integer;
begin
  Result := Length(FEntries);
end;

function TSevenZReaderImpl.Entry(AIndex: Integer): TSevenZEntryInfo;
begin
  if (AIndex < 0) or (AIndex >= Length(FEntries)) then
    raise EArgumentError.CreateFmt('entry index %d out of range', [AIndex]);
  Result := FEntries[AIndex];
end;

function TSevenZReaderImpl.Find(const AName: string): Integer;
var
  LI: Integer;
begin
  Result := -1;
  for LI := 0 to Length(FEntries) - 1 do
    if FEntries[LI].Name = AName then
      Exit(LI);
end;

function AsciiLower(C: Char): Char; inline;
begin
  if (C >= 'A') and (C <= 'Z') then Result := Chr(Ord(C) + 32) else Result := C;
end;

function SameIgnoreCase(const A, B: string): Boolean; inline;
var
  LI: Integer;
begin
  if Length(A) <> Length(B) then Exit(False);
  for LI := 1 to Length(A) do
    if (Ord(A[LI]) > 127) or (Ord(B[LI]) > 127) then
      Exit(LowerCase(A) = LowerCase(B));
  for LI := 1 to Length(A) do
    if AsciiLower(A[LI]) <> AsciiLower(B[LI]) then Exit(False);
  Result := True;
end;

function TSevenZReaderImpl.FindIgnoreCase(const AName: string): Integer;
var
  LI: Integer;
begin
  Result := -1;
  for LI := 0 to Length(FEntries) - 1 do
    if SameIgnoreCase(FEntries[LI].Name, AName) then
      Exit(LI);
end;

function TSevenZReaderImpl.Contains(const AName: string): Boolean;
begin
  Result := Find(AName) >= 0;
end;

function TSevenZReaderImpl.ContainsIgnoreCase(const AName: string): Boolean;
begin
  Result := FindIgnoreCase(AName) >= 0;
end;

function TSevenZReaderImpl.TryGetEntry(const AName: string; out AInfo: TSevenZEntryInfo): Boolean;
var LIdx: Integer;
begin
  LIdx := Find(AName);
  Result := LIdx >= 0;
  if Result then
    AInfo := FEntries[LIdx]
  else
    AInfo := Default(TSevenZEntryInfo);
end;

function TSevenZReaderImpl.TryEntryByName(const AName: string; out AInfo: TSevenZEntryInfo): Boolean;
begin
  Result := TryGetEntry(AName, AInfo);
end;

function TSevenZReaderImpl.TryGetEntryIgnoreCase(const AName: string; out AInfo: TSevenZEntryInfo): Boolean;
var LIdx: Integer;
begin
  LIdx := FindIgnoreCase(AName);
  Result := LIdx >= 0;
  if Result then
    AInfo := FEntries[LIdx]
  else
    AInfo := Default(TSevenZEntryInfo);
end;

function TSevenZReaderImpl.EntryByName(const AName: string): TSevenZEntryInfo;
var LIdx: Integer;
begin
  LIdx := Find(AName);
  if LIdx < 0 then
    raise EArgumentError.CreateFmt('entry "%s" not found', [AName]);
  Result := FEntries[LIdx];
end;

function TSevenZReaderImpl.EntryByNameIgnoreCase(const AName: string): TSevenZEntryInfo;
var LIdx: Integer;
begin
  LIdx := FindIgnoreCase(AName);
  if LIdx < 0 then
    raise EArgumentError.CreateFmt('entry "%s" not found', [AName]);
  Result := FEntries[LIdx];
end;

function TSevenZReaderImpl.GetIsEmpty: Boolean;
begin
  Result := Length(FEntries) = 0;
end;

function TSevenZReaderImpl.GetEntries: TSevenZEntryInfoArray;
var LI: Integer;
begin
  Result := nil;
  SetLength(Result, Length(FEntries));
  for LI := 0 to High(FEntries) do
    Result[LI] := FEntries[LI];
end;

function TSevenZReaderImpl.Extract(AIndex: Integer): TBytes;
begin
  if (AIndex < 0) or (AIndex >= Length(FEntries)) then
    raise EArgumentError.CreateFmt('entry index %d out of range', [AIndex]);
  Result := nil;
  if FFolderIdxOfEntry[AIndex] < 0 then
    Exit(nil);
  Result := EntrySlice(AIndex);
end;

function TSevenZReaderImpl.ExtractTo(const AWriter: IWriter;
  AIndex: Integer): Int64;
var
  LFolderIdx: Integer;
  LGsub: SizeInt;
  LData: TBytes;
  LOff: SizeInt;
  LLen: SizeInt;
  LTake: SizeInt;
  LCrc: LongWord;
  LHasCrc: Boolean;
begin
  if AWriter = nil then
    raise EArgumentError.Create('writer must not be nil');
  if (AIndex < 0) or (AIndex >= Length(FEntries)) then
    raise EArgumentError.CreateFmt('entry index %d out of range', [AIndex]);
  LFolderIdx := FFolderIdxOfEntry[AIndex];
  if LFolderIdx < 0 then
    Exit(0);
  { 单遍窗口化：边写边增量 CRC，减半内存扫描。
    CRC 失败时 sink 可能已写入脏数据，调用方以异常丢弃。 }
  LGsub := FGlobalSubOfEntry[AIndex];
  LData := DecodeFolder(LFolderIdx);
  LOff := FEntryOffInFolder[AIndex];
  LLen := SizeInt(FStreams.Substreams[LGsub].Size);
  if LOff + LLen > Length(LData) then
    raise ESevenZError.Create('substream window exceeds folder output');
  LHasCrc := FStreams.Substreams[LGsub].HasCrc;
  LCrc := 0;
  Result := 0;
  while LLen > 0 do
  begin
    LTake := LLen;
    if LTake > C_EXTRACT_WINDOW then
      LTake := C_EXTRACT_WINDOW;
    if LHasCrc then
      LCrc := Crc32Update(LCrc, @LData[LOff], SizeUInt(LTake));
    if AWriter.Write(LData[LOff], SizeUInt(LTake)) <> SizeUInt(LTake) then
      raise EIOError.Create('writer accepted fewer bytes than extracted');
    Inc(Result, LTake);
    Inc(LOff, LTake);
    Dec(LLen, LTake);
  end;
  if LHasCrc and (LCrc <> LongWord(FStreams.Substreams[LGsub].Crc)) then
    raise ESevenZError.CreateFmt('entry %d CRC mismatch', [AIndex]);
end;

function TSevenZReaderImpl.OpenStream(AIndex: Integer): IStream;
begin
  if (AIndex < 0) or (AIndex >= Length(FEntries)) then
    raise EArgumentError.CreateFmt('entry index %d out of range', [AIndex]);
  { Extract 走 folder 解码缓存与 CRC 校验；流仅持有其结果引用 }
  Result := TSevenZEntryStream.Create(Extract(AIndex));
end;

function TSevenZReaderImpl.TryExtract(AIndex: Integer; out AData: TBytes): Boolean;
var LErr: string;
begin
  Result := TryExtractWithError(AIndex, AData, LErr);
end;

function TSevenZReaderImpl.TryExtractTo(const AWriter: IWriter;
  AIndex: Integer; out ABytesWritten: Int64): Boolean;
var LErr: string;
begin
  Result := TryExtractToWithError(AWriter, AIndex, ABytesWritten, LErr);
end;

function TSevenZReaderImpl.TryExtractWithError(AIndex: Integer;
  out AData: TBytes; out AError: string): Boolean;
begin
  AData := nil;
  AError := '';
  Result := False;
  try
    AData := Extract(AIndex);
    Result := True;
  except
    on E: Exception do
    begin
      AError := E.ClassName + ': ' + E.Message;
      Exit(False);
    end;
  end;
end;

function TSevenZReaderImpl.TryExtractToWithError(const AWriter: IWriter;
  AIndex: Integer; out ABytesWritten: Int64; out AError: string): Boolean;
begin
  ABytesWritten := 0;
  AError := '';
  Result := False;
  if AWriter = nil then
  begin
    AError := 'EArgumentError: writer is nil';
    Exit(False);
  end;
  try
    ABytesWritten := ExtractTo(AWriter, AIndex);
    Result := True;
  except
    on E: Exception do
    begin
      AError := E.ClassName + ': ' + E.Message;
      Exit(False);
    end;
  end;
end;

function TSevenZReaderImpl.TryOpenStream(AIndex: Integer;
  out AStream: IStream): Boolean;
var LErr: string;
begin
  Result := TryOpenStreamWithError(AIndex, AStream, LErr);
end;

function TSevenZReaderImpl.TryOpenStreamWithError(AIndex: Integer;
  out AStream: IStream; out AError: string): Boolean;
begin
  AStream := nil;
  AError := '';
  Result := False;
  try
    AStream := OpenStream(AIndex);
    Result := True;
  except
    on E: Exception do
    begin
      AError := E.ClassName + ': ' + E.Message;
      Exit(False);
    end;
  end;
end;

function TSevenZReaderImpl.GetEnumerator: TSevenZEntryEnumerator;
begin
  Result.FReader := Self;
  Result.FIndex := -1;
end;

end.
