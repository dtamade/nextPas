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
  nextpas.core.sevenz.header,
  nextpas.core.collections.hashmap.swiss.str;

type
  TSevenZIndexArray = array of Integer;

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
    FEntryOffInFolder: array of Int64;     { 非空文件 -> 子流在 folder 输出内偏移 (UInt64 宽度, -1 sentinel) }
    FPackStartOfFolder: array of Integer;  { folder -> 首 pack 流序号 }
    FPackOffsetOfFolder: array of UInt64;  { folder -> 首 pack 流绝对载荷偏移 }
    FCacheIdx: array[0..1] of Integer;     { 2-entry MRU 缓存：0 为 MRU，字节阈值见 DecodeFolder/ C_CACHE_MAX_BYTES }
    FCacheData: array[0..1] of TBytes;
    FPassword: string;
    FNameMap: specialize TSwissTableStr<Integer>;        { exact → first index }
    FNameMapIgnoreCase: specialize TSwissTableStr<Integer>; { lower → first index }
    FSortedIdx: array of Integer;                           { lexicographic order for prefix }
    FSortedIdxRev: array of Integer;                        { reversed order for suffix }
    FLowerNames: array of string;                           { lowercased names for ignore-case indexes }
    FSortedIdxIgnoreCase: array of Integer;
    FSortedIdxRevIgnoreCase: array of Integer;
    FIgnoreCaseBuilt: Boolean;
    procedure BuildNameMaps;
    { 单核排序：AUseLower 选 FLowerNames/Name，ARev 选 CompareReversed，去重 4 份 QuickSort }
    procedure BuildSorted(var ADest: TSevenZIndexArray; AUseLower, ARev: Boolean);
    procedure BuildSortedIdx;
    procedure BuildSortedIdxRev;
    procedure BuildSortedIdxIgnoreCase;
    procedure BuildSortedIdxRevIgnoreCase;
    procedure EnsureIgnoreCaseBuilt;
    function LowerBoundGeneric(const ASorted: TSevenZIndexArray; const AKey: string; AUseLower, ARev: Boolean): Integer; inline;
    function LowerBoundPrefix(const APrefix: string): Integer;
    function LowerBoundSuffix(const ASuffix: string): Integer;
    function LowerBoundPrefixIgnoreCase(const APrefix: string): Integer;
    function LowerBoundSuffixIgnoreCase(const ASuffix: string): Integer;
    function ReverseStr(const S: string): string;
    procedure ParseArchive;
    procedure ParseHeaderBlock(const AHeaderData: TBytes);
    procedure AssembleEntries;
    procedure CopyPackSlices(APackPos: UInt64; var ASlices: array of TBytes);
    function DecodeFolder(AFolderIdx: Integer): TBytes;
    function EntrySlice(AIndex: Integer): TBytes;
    function ExtractIndicesGrouped(const AIdx: array of Integer): TSevenZExtractedArray;
    function IndicesByPrefix(const APrefix: string): TSevenZIndexArray;
    function IndicesByPrefixIgnoreCase(const APrefix: string): TSevenZIndexArray;
    function FilterIndicesBySuffix(const AIndices: array of Integer; const APrefix, ASuffix: string): TSevenZIndexArray; inline;
    function FilterIndicesBySuffixIgnoreCase(const AIndices: array of Integer; const APrefix, ASuffix: string): TSevenZIndexArray; inline;
    function IndicesBySuffix(const ASuffix: string): TSevenZIndexArray;
    function IndicesBySuffixIgnoreCase(const ASuffix: string): TSevenZIndexArray;
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
    procedure ClearCache;
    function EntriesByPrefix(const APrefix: string): TSevenZEntryInfoArray;
    function EntriesBySuffix(const ASuffix: string): TSevenZEntryInfoArray;
    function FindByPrefix(const APrefix: string): Integer;
    function FindBySuffix(const ASuffix: string): Integer;
    function EntriesByGlob(const APattern: string): TSevenZEntryInfoArray;
    function FindByGlob(const APattern: string): Integer;
    function EntriesByPrefixIgnoreCase(const APrefix: string): TSevenZEntryInfoArray;
    function EntriesBySuffixIgnoreCase(const ASuffix: string): TSevenZEntryInfoArray;
    function FindByPrefixIgnoreCase(const APrefix: string): Integer;
    function FindBySuffixIgnoreCase(const ASuffix: string): Integer;
    function EntriesByGlobIgnoreCase(const APattern: string): TSevenZEntryInfoArray;
    function FindByGlobIgnoreCase(const APattern: string): Integer;
    function ExtractAll: TSevenZExtractedArray;
    function ExtractByPrefix(const APrefix: string): TSevenZExtractedArray;
    function ExtractBySuffix(const ASuffix: string): TSevenZExtractedArray;
    function ExtractByGlob(const APattern: string): TSevenZExtractedArray;
    function ExtractByPrefixIgnoreCase(const APrefix: string): TSevenZExtractedArray;
    function ExtractBySuffixIgnoreCase(const ASuffix: string): TSevenZExtractedArray;
    function ExtractByGlobIgnoreCase(const APattern: string): TSevenZExtractedArray;
    function TryExtractByGlob(const APattern: string; out AExtracted: TSevenZExtractedArray): Boolean;
    function TryExtractByGlobWithError(const APattern: string; out AExtracted: TSevenZExtractedArray; out AError: string): Boolean;
    function TryExtractByPrefix(const APrefix: string; out AExtracted: TSevenZExtractedArray): Boolean;
    function TryExtractByPrefixWithError(const APrefix: string; out AExtracted: TSevenZExtractedArray; out AError: string): Boolean;
    function TryExtractBySuffix(const ASuffix: string; out AExtracted: TSevenZExtractedArray): Boolean;
    function TryExtractBySuffixWithError(const ASuffix: string; out AExtracted: TSevenZExtractedArray; out AError: string): Boolean;
    function TryExtractByPrefixIgnoreCase(const APrefix: string; out AExtracted: TSevenZExtractedArray): Boolean;
    function TryExtractByPrefixIgnoreCaseWithError(const APrefix: string; out AExtracted: TSevenZExtractedArray; out AError: string): Boolean;
    function TryExtractBySuffixIgnoreCase(const ASuffix: string; out AExtracted: TSevenZExtractedArray): Boolean;
    function TryExtractBySuffixIgnoreCaseWithError(const ASuffix: string; out AExtracted: TSevenZExtractedArray; out AError: string): Boolean;
    function TryExtractByGlobIgnoreCase(const APattern: string; out AExtracted: TSevenZExtractedArray): Boolean;
    function TryExtractByGlobIgnoreCaseWithError(const APattern: string; out AExtracted: TSevenZExtractedArray; out AError: string): Boolean;
    function TryExtractAll(out AExtracted: TSevenZExtractedArray): Boolean;
    function TryExtractAllWithError(out AExtracted: TSevenZExtractedArray; out AError: string): Boolean;
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
  nextpas.core.sevenz.limits,
  nextpas.core.text.unicode.utils;

function CompareNames(const A, B: string): Integer; inline;
begin
  if A < B then Result := -1 else if A > B then Result := 1 else Result := 0;
end;

function CompareReversed(const A, B: string): Integer; forward;

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
  C_CACHE_MAX_BYTES = SEVENZ_CACHE_MAX_BYTES; { 单源复用 limits/base，不新增重复常量 }

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
  FreeAndNil(FNameMap);
  FreeAndNil(FNameMapIgnoreCase);
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
  if LSize > UInt64(High(SizeInt)) then
    raise ESevenZLimitError.CreateFmt('header size %d exceeds addressable limit %d', [LSize, UInt64(High(SizeInt))]);
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
      begin
        if LEncodedStreams.Pack.Sizes[LI] > UInt64(High(SizeInt)) then
          raise ESevenZLimitError.CreateFmt('pack slice %d size %d exceeds addressable limit %d', [LI, LEncodedStreams.Pack.Sizes[LI], UInt64(High(SizeInt))]);
        SetLength(LPackSlices[LI],
          SizeInt(LEncodedStreams.Pack.Sizes[LI]));
      end;
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
  LByteAcc: UInt64;
  LBaseAcc: SizeInt;
  LAcc: UInt64;
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
      if LAcc > High(UInt64) - FStreams.Pack.Sizes[LJ] then
        raise ESevenZLimitError.Create('pack total size overflow');
      LAcc := LAcc + FStreams.Pack.Sizes[LJ];
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
      { folder 输出内字节偏移：此前同 folder 子流尺寸之和 (UInt64 避免 32 位截断) }
      if LByteAcc > UInt64(High(Int64)) then
        raise ESevenZLimitError.CreateFmt('folder offset %d exceeds Int64 limit', [LByteAcc]);
      FEntryOffInFolder[LI] := Int64(LByteAcc);
      if FStreams.Substreams[LSubCursor].Size > UInt64(High(Int64)) then
        raise ESevenZLimitError.CreateFmt('substream %d size %d exceeds Int64 limit', [LSubCursor, FStreams.Substreams[LSubCursor].Size]);
      LE.Size := Int64(FStreams.Substreams[LSubCursor].Size);
      if LByteAcc > High(UInt64) - FStreams.Substreams[LSubCursor].Size then
        raise ESevenZLimitError.Create('folder byte offset overflow');
      Inc(LByteAcc, FStreams.Substreams[LSubCursor].Size);
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
  BuildNameMaps;
end;

procedure TSevenZReaderImpl.BuildNameMaps;
var
  LI: Integer;
begin
  FreeAndNil(FNameMap);
  FreeAndNil(FNameMapIgnoreCase);
  FSortedIdx := nil;
  FSortedIdxRev := nil;
  FSortedIdxIgnoreCase := nil;
  FSortedIdxRevIgnoreCase := nil;
  FLowerNames := nil;
  if Length(FEntries)=0 then Exit;
  FNameMap := specialize TSwissTableStr<Integer>.Create(SizeUInt(Length(FEntries)));
  // Lazy ignore-case: defer FLowerNames / FNameMapIgnoreCase / sorted ignore indexes
  FNameMapIgnoreCase := nil;
  FLowerNames := nil;
  FSortedIdxIgnoreCase := nil;
  FSortedIdxRevIgnoreCase := nil;
  FIgnoreCaseBuilt := False;
  for LI:=0 to High(FEntries) do
  begin
    if not FNameMap.ContainsKey(FEntries[LI].Name) then
      FNameMap.Put(FEntries[LI].Name, LI);
  end;
  BuildSortedIdx;
  BuildSortedIdxRev;
end;

procedure TSevenZReaderImpl.BuildSorted(var ADest: TSevenZIndexArray; AUseLower, ARev: Boolean);
var LI: Integer;
  { 单核去重：inline Cmp 按 AUseLower/ARev 分发，避免 4 份 QuickSort 拷贝 }
  procedure QuickSort(AL, AR: Integer);
  var LI2, LJ, LPivot: Integer; LTmp: Integer;
    function Cmp(const A, B: Integer): Integer; inline;
    begin
      if AUseLower then
      begin
        if ARev then Result := CompareReversed(FLowerNames[A], FLowerNames[B])
        else Result := CompareNames(FLowerNames[A], FLowerNames[B]);
      end else
      begin
        if ARev then Result := CompareReversed(FEntries[A].Name, FEntries[B].Name)
        else Result := CompareNames(FEntries[A].Name, FEntries[B].Name);
      end;
    end;
  begin
    LI2 := AL; LJ := AR; LPivot := ADest[(AL+AR) div 2];
    repeat
      while Cmp(ADest[LI2], LPivot) < 0 do Inc(LI2);
      while Cmp(ADest[LJ], LPivot) > 0 do Dec(LJ);
      if LI2 <= LJ then
      begin LTmp := ADest[LI2]; ADest[LI2] := ADest[LJ]; ADest[LJ] := LTmp; Inc(LI2); Dec(LJ); end;
    until LI2 > LJ;
    if AL < LJ then QuickSort(AL, LJ);
    if LI2 < AR then QuickSort(LI2, AR);
  end;
begin
  SetLength(ADest, Length(FEntries));
  for LI:=0 to High(ADest) do ADest[LI] := LI;
  if Length(ADest) > 1 then QuickSort(0, High(ADest));
end;

procedure TSevenZReaderImpl.BuildSortedIdx;
begin
  BuildSorted(FSortedIdx, False, False);
end;

procedure TSevenZReaderImpl.BuildSortedIdxRev;
begin
  BuildSorted(FSortedIdxRev, False, True);
end;

procedure TSevenZReaderImpl.BuildSortedIdxIgnoreCase;
begin
  BuildSorted(FSortedIdxIgnoreCase, True, False);
end;

procedure TSevenZReaderImpl.BuildSortedIdxRevIgnoreCase;
begin
  BuildSorted(FSortedIdxRevIgnoreCase, True, True);
end;

function CompareReversed(const A, B: string): Integer; inline;
var LI, LJ: Integer;
begin
  LI := Length(A); LJ := Length(B);
  while (LI > 0) and (LJ > 0) do
  begin
    if A[LI] < B[LJ] then Exit(-1);
    if A[LI] > B[LJ] then Exit(1);
    Dec(LI); Dec(LJ);
  end;
  if LI = 0 then
    if LJ = 0 then Exit(0) else Exit(-1)
  else Exit(1);
end;

function TSevenZReaderImpl.ReverseStr(const S: string): string;
var LI: Integer;
begin
  SetLength(Result, Length(S));
  for LI:=1 to Length(S) do Result[LI] := S[Length(S)-LI+1];
end;

procedure TSevenZReaderImpl.EnsureIgnoreCaseBuilt;
var LI: Integer; LLower: string;
begin
  if FIgnoreCaseBuilt then Exit;
  if Length(FEntries) = 0 then begin FIgnoreCaseBuilt := True; Exit; end;
  FNameMapIgnoreCase := specialize TSwissTableStr<Integer>.Create(SizeUInt(Length(FEntries)));
  SetLength(FLowerNames, Length(FEntries));
  for LI := 0 to High(FEntries) do
  begin
    if IsAsciiString(FEntries[LI].Name) then LLower := AsciiLowerStr(FEntries[LI].Name) else LLower := LowerCase(FEntries[LI].Name);
    FLowerNames[LI] := LLower;
    if not FNameMapIgnoreCase.ContainsKey(LLower) then
      FNameMapIgnoreCase.Put(LLower, LI);
  end;
  BuildSortedIdxIgnoreCase;
  BuildSortedIdxRevIgnoreCase;
  FIgnoreCaseBuilt := True;
end;

function TSevenZReaderImpl.LowerBoundGeneric(const ASorted: TSevenZIndexArray; const AKey: string; AUseLower, ARev: Boolean): Integer; inline;
var LLo, LHi, LMid, LCmp: Integer;
begin
  LLo := 0; LHi := Length(ASorted);
  while LLo < LHi do
  begin
    LMid := (LLo + LHi) div 2;
    if AUseLower then
    begin
      if ARev then LCmp := CompareReversed(FLowerNames[ASorted[LMid]], AKey)
      else LCmp := CompareNames(FLowerNames[ASorted[LMid]], AKey);
    end else
    begin
      if ARev then LCmp := CompareReversed(FEntries[ASorted[LMid]].Name, AKey)
      else LCmp := CompareNames(FEntries[ASorted[LMid]].Name, AKey);
    end;
    if LCmp < 0 then LLo := LMid + 1 else LHi := LMid;
  end;
  Result := LLo;
end;

function TSevenZReaderImpl.LowerBoundPrefix(const APrefix: string): Integer;
begin
  Result := LowerBoundGeneric(FSortedIdx, APrefix, False, False);
end;

function TSevenZReaderImpl.LowerBoundPrefixIgnoreCase(const APrefix: string): Integer;
var LLower: string;
begin
  EnsureIgnoreCaseBuilt;
  if IsAsciiString(APrefix) then LLower := AsciiLowerStr(APrefix) else LLower := LowerCase(APrefix);
  Result := LowerBoundGeneric(FSortedIdxIgnoreCase, LLower, True, False);
end;

function TSevenZReaderImpl.LowerBoundSuffixIgnoreCase(const ASuffix: string): Integer;
var LLower: string;
begin
  EnsureIgnoreCaseBuilt;
  if IsAsciiString(ASuffix) then LLower := AsciiLowerStr(ASuffix) else LLower := LowerCase(ASuffix);
  Result := LowerBoundGeneric(FSortedIdxRevIgnoreCase, LLower, True, True);
end;

function TSevenZReaderImpl.LowerBoundSuffix(const ASuffix: string): Integer;
begin
  Result := LowerBoundGeneric(FSortedIdxRev, ASuffix, False, True);
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
    if FStreams.Pack.Sizes[LPackIdx] > UInt64(High(SizeInt)) then
      raise ESevenZLimitError.CreateFmt('pack slice %d size %d exceeds addressable limit %d', [LPackIdx, FStreams.Pack.Sizes[LPackIdx], UInt64(High(SizeInt))]);
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
  // 性能：2-entry MRU 带字节阈值，极端 solid 2×大 folder 防翻倍；阈值单源 C_CACHE_MAX_BYTES(64MiB) 来自 limits/base。
  // 单 folder 超阈值不入缓存；双缓存总量超阈值仅保留新条目，淘汰旧 MRU。
  // bench 可观测：bench_sevenz container extract warm-cache 吞吐与 64MiB+ 双 folder RSS；ClearCache 后连续 Extract 测收敛。
  // 稳定性：解码异常在缓存更新前抛出，不污染 MRU；LSlices 为托管 TBytes 自动释放，无 FFI 句柄泄漏。
  if SizeUInt(Length(Result)) > C_CACHE_MAX_BYTES then
    Exit(Result);
  if (FCacheIdx[0] <> -1) and (SizeUInt(Length(FCacheData[0])) + SizeUInt(Length(Result)) > C_CACHE_MAX_BYTES) then
  begin
    FCacheIdx[1] := -1;
    FCacheData[1] := nil;
    FCacheIdx[0] := AfolderIdx;
    FCacheData[0] := Result;
  end
  else
  begin
    FCacheIdx[1] := FCacheIdx[0]; FCacheData[1] := FCacheData[0];
    FCacheIdx[0] := AfolderIdx; FCacheData[0] := Result;
  end;
end;

function BytesIsUniqueLocal(const A: TBytes): Boolean; inline;
begin
  if Pointer(A) = nil then Exit(True);
  Result := PSizeInt(Pointer(A) - 2 * SizeOf(Pointer))^ = 1;
end;

function TSevenZReaderImpl.EntrySlice(AIndex: Integer): TBytes;
var
  LFolderIdx: Integer;
  LGsub: SizeInt;
  LData: TBytes;
  LOff: UInt64;
  LLen: UInt64;
begin
  Result := nil;
  LFolderIdx := FFolderIdxOfEntry[AIndex];
  if LFolderIdx < 0 then
    Exit(nil);
  LGsub := FGlobalSubOfEntry[AIndex];
  LData := DecodeFolder(LFolderIdx);
  if FEntryOffInFolder[AIndex] < 0 then
    raise ESevenZError.Create('entry offset poisoned');
  LOff := UInt64(FEntryOffInFolder[AIndex]);
  LLen := FStreams.Substreams[LGsub].Size;
  if LLen > UInt64(High(SizeInt)) then
    raise ESevenZLimitError.CreateFmt('substream %d size %d exceeds addressable limit %d', [LGsub, LLen, UInt64(High(SizeInt))]);
  if LOff > UInt64(High(SizeInt)) then
    raise ESevenZLimitError.CreateFmt('substream %d offset %d exceeds addressable limit %d', [LGsub, LOff, UInt64(High(SizeInt))]);
  if LOff > High(UInt64) - LLen then
    raise ESevenZError.Create('substream window overflow');
  if LOff + LLen > UInt64(Length(LData)) then
    raise ESevenZError.Create('substream window exceeds folder output');
  // perf: 单文件 folder 常见路径零拷贝 — LOff=0 且 LLen=Length(LData) 时复用解码缓存引用
  if (LOff = 0) and (LLen = UInt64(Length(LData))) then
  begin
    if BytesIsUniqueLocal(LData) then
      Result := LData
    else
    begin
      SetLength(Result, SizeInt(LLen));
      if LLen > 0 then Move(LData[0], Result[0], SizeInt(LLen));
    end;
  end
  else
  begin
    SetLength(Result, SizeInt(LLen));
    if LLen > 0 then
      Move(LData[SizeInt(LOff)], Result[0], SizeInt(LLen));
  end;
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
  LIdx: Integer;
begin
  if (FNameMap<>nil) and FNameMap.TryGetValue(AName, LIdx) then
    Exit(LIdx);
  Result := -1;
  for LI := 0 to Length(FEntries) - 1 do
    if FEntries[LI].Name = AName then
      Exit(LI);
end;

function SameIgnoreCase(const A, B: string): Boolean; inline;
var LI: Integer;
begin
  if Length(A) <> Length(B) then Exit(False);
  { ascii 路径零分配：IsAsciiString 8 字节并行预检 + AsciiLowerChar 逐字符；非 ascii 单次 LowerCase }
  if IsAsciiString(A) and IsAsciiString(B) then
  begin
    for LI := 1 to Length(A) do
      if AsciiLowerChar(A[LI]) <> AsciiLowerChar(B[LI]) then Exit(False);
    Exit(True);
  end;
  Result := LowerCase(A) = LowerCase(B);
end;

function TSevenZReaderImpl.FindIgnoreCase(const AName: string): Integer;
var
  LI: Integer;
  LIdx: Integer;
  LLower: string;
begin
  EnsureIgnoreCaseBuilt;
  if FNameMapIgnoreCase<>nil then
  begin
    if IsAsciiString(AName) then LLower := AsciiLowerStr(AName) else LLower := LowerCase(AName);
    if FNameMapIgnoreCase.TryGetValue(LLower, LIdx) then
      Exit(LIdx);
  end;
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
  EnsureIgnoreCaseBuilt;
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
  EnsureIgnoreCaseBuilt;
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

procedure TSevenZReaderImpl.ClearCache;
begin
  FCacheIdx[0] := -1; FCacheIdx[1] := -1;
  FCacheData[0] := nil; FCacheData[1] := nil;
end;

function TSevenZReaderImpl.EntriesByPrefix(const APrefix: string): TSevenZEntryInfoArray;
var LIndices: TSevenZIndexArray; LI: Integer;
begin
  LIndices := IndicesByPrefix(APrefix);
  SetLength(Result, Length(LIndices));
  for LI:=0 to High(LIndices) do Result[LI] := FEntries[LIndices[LI]];
end;

function TSevenZReaderImpl.EntriesBySuffix(const ASuffix: string): TSevenZEntryInfoArray;
var LIndices: TSevenZIndexArray; LI: Integer;
begin
  LIndices := IndicesBySuffix(ASuffix);
  SetLength(Result, Length(LIndices));
  for LI:=0 to High(LIndices) do Result[LI] := FEntries[LIndices[LI]];
end;

function TSevenZReaderImpl.FindByPrefix(const APrefix: string): Integer;
var LStart, LIdx: Integer;
begin
  Result := -1;
  if APrefix='' then
  begin
    if Length(FEntries)>0 then Exit(0) else Exit(-1);
  end;
  if Length(FSortedIdx)=0 then Exit(-1);
  LStart := LowerBoundPrefix(APrefix);
  if LStart >= Length(FSortedIdx) then Exit(-1);
  LIdx := FSortedIdx[LStart];
  if not StrHasPrefix(FEntries[LIdx].Name, APrefix) then Exit(-1);
  Result := LIdx;
end;

function TSevenZReaderImpl.FindBySuffix(const ASuffix: string): Integer;
var LStart, LIdx: Integer;
begin
  Result := -1;
  if ASuffix='' then
  begin
    if Length(FEntries)>0 then Exit(0) else Exit(-1);
  end;
  if Length(FSortedIdxRev)=0 then Exit(-1);
  LStart := LowerBoundSuffix(ASuffix);
  if LStart >= Length(FSortedIdxRev) then Exit(-1);
  LIdx := FSortedIdxRev[LStart];
  if not StrHasSuffix(FEntries[LIdx].Name, ASuffix) then Exit(-1);
  Result := LIdx;
end;

function MatchesGlobCore(const AName, APattern: string; AIgnoreCase: Boolean): Boolean; inline;
var LNameLen, LPatLen, LNi, LPi, LStarPos, LMatchPos: Integer;
begin
  LNameLen := Length(AName); LPatLen := Length(APattern);
  LNi := 1; LPi := 1; LStarPos := 0; LMatchPos := 0;
  while LNi <= LNameLen do
  begin
    if (LPi <= LPatLen) and ((APattern[LPi]='?') or
       (AIgnoreCase and (AsciiLowerChar(APattern[LPi])=AsciiLowerChar(AName[LNi])) or
        not AIgnoreCase and (APattern[LPi]=AName[LNi]))) then
    begin Inc(LNi); Inc(LPi); end
    else if (LPi <= LPatLen) and (APattern[LPi]='*') then
    begin LStarPos := LPi; LMatchPos := LNi; Inc(LPi); end
    else if LStarPos <> 0 then
    begin LPi := LStarPos + 1; Inc(LMatchPos); LNi := LMatchPos; end
    else Exit(False);
  end;
  while (LPi <= LPatLen) and (APattern[LPi]='*') do Inc(LPi);
  Result := LPi > LPatLen;
end;

function MatchesGlob(const AName, APattern: string): Boolean;
begin
  Result := MatchesGlobCore(AName, APattern, False);
end;

function SuffixMatchesIgnoreCaseAscii(const AName, ASuffixLower: string; const ANeed: Integer): Boolean; inline;
var I, LOff: Integer;
begin
  if ASuffixLower = '' then Exit(Length(AName) >= ANeed);
  if Length(AName) < ANeed then Exit(False);
  if Length(AName) < Length(ASuffixLower) then Exit(False);
  LOff := Length(AName) - Length(ASuffixLower);
  for I := 1 to Length(ASuffixLower) do
    if AsciiLowerChar(AName[LOff + I]) <> ASuffixLower[I] then Exit(False);
  Result := True;
end;

type TGlobKind = (gkEmpty, gkStar, gkExact, gkPrefix, gkSuffix, gkPrefixSuffix, gkComplex);

function ClassifyGlob(const APattern: string; out APrefix, ASuffix: string): TGlobKind; inline;
var LStarCount, LStarPos, LI: Integer; LHasQ: Boolean;
begin
  APrefix := ''; ASuffix := '';
  if APattern = '' then Exit(gkEmpty);
  if APattern = '*' then Exit(gkStar);
  LStarCount := 0; LStarPos := 0; LHasQ := False;
  for LI := 1 to Length(APattern) do
  begin
    if APattern[LI] = '*' then begin Inc(LStarCount); LStarPos := LI; end
    else if APattern[LI] = '?' then LHasQ := True;
  end;
  if LHasQ then Exit(gkComplex);
  if LStarCount = 0 then Exit(gkExact);
  if LStarCount = 1 then
  begin
    if (APattern[Length(APattern)] = '*') and (APattern[1] <> '*') then
    begin APrefix := Copy(APattern, 1, Length(APattern)-1); Exit(gkPrefix); end;
    if (APattern[1] = '*') and (APattern[Length(APattern)] <> '*') then
    begin ASuffix := Copy(APattern, 2, Length(APattern)-1); Exit(gkSuffix); end;
    if (LStarPos > 1) and (LStarPos < Length(APattern)) then
    begin APrefix := Copy(APattern, 1, LStarPos - 1); ASuffix := Copy(APattern, LStarPos + 1, Length(APattern)-LStarPos); Exit(gkPrefixSuffix); end;
  end;
  Result := gkComplex;
end;

{ gkComplex 前缀/后缀萃取：取首通配前与末通配后的字面量，用于 IgnoreCase 索引剪枝
  复用 FLowerNames/SortedIdxIgnoreCase/SortedIdxRevIgnoreCase，避免线性全表扫描
  O(N) -> O(log N + M)；空字面量回退全表；bench 见 bench_sevenz BenchGlobIgnoreCase }
procedure ExtractComplexBounds(const APattern: string; out APrefix, ASuffix: string); inline;
var LFirst, LLast, LI: Integer;
begin
  APrefix := ''; ASuffix := '';
  LFirst := 0; LLast := 0;
  for LI := 1 to Length(APattern) do
    if (APattern[LI] = '*') or (APattern[LI] = '?') then
    begin
      if LFirst = 0 then LFirst := LI;
      LLast := LI;
    end;
  if LFirst = 0 then Exit;
  if LFirst > 1 then APrefix := Copy(APattern, 1, LFirst - 1);
  if LLast < Length(APattern) then ASuffix := Copy(APattern, LLast + 1, Length(APattern) - LLast);
end;

function TSevenZReaderImpl.EntriesByGlob(const APattern: string): TSevenZEntryInfoArray;
var LI, LCnt: Integer;
    LPrefix, LSuffix: string;
    LIdx: Integer;
    LIdx2: TSevenZIndexArray;
begin
  Result := nil;
  case ClassifyGlob(APattern, LPrefix, LSuffix) of
    gkEmpty: Exit;
    gkStar: begin Result := GetEntries; Exit; end;
    gkExact: begin LIdx := Find(APattern); if LIdx >= 0 then begin SetLength(Result,1); Result[0] := FEntries[LIdx]; end; Exit; end;
    gkPrefix: begin Result := EntriesByPrefix(LPrefix); Exit; end;
    gkSuffix: begin Result := EntriesBySuffix(LSuffix); Exit; end;
    gkPrefixSuffix: begin LIdx2 := IndicesByPrefix(LPrefix); LIdx2 := FilterIndicesBySuffix(LIdx2, LPrefix, LSuffix); SetLength(Result, Length(LIdx2)); for LI:=0 to High(LIdx2) do Result[LI] := FEntries[LIdx2[LI]]; Exit; end;
    gkComplex: ;
  end;
  LCnt := 0;
  for LI:=0 to High(FEntries) do
    if MatchesGlob(FEntries[LI].Name, APattern) then Inc(LCnt);
  SetLength(Result, LCnt);
  LCnt := 0;
  for LI:=0 to High(FEntries) do
    if MatchesGlob(FEntries[LI].Name, APattern) then
    begin
      Result[LCnt] := FEntries[LI];
      Inc(LCnt);
    end;
end;

function TSevenZReaderImpl.FindByGlob(const APattern: string): Integer;
var LI: Integer; LPrefix, LSuffix: string; LPos, LIdx: Integer;
begin
  Result := -1;
  case ClassifyGlob(APattern, LPrefix, LSuffix) of
    gkEmpty: Exit(-1);
    gkStar: begin if Length(FEntries)>0 then Exit(0) else Exit(-1); end;
    gkExact: Exit(Find(APattern));
    gkPrefix: Exit(FindByPrefix(LPrefix));
    gkSuffix: Exit(FindBySuffix(LSuffix));
    gkPrefixSuffix:
    begin
      LPos := LowerBoundPrefix(LPrefix);
      while LPos < Length(FSortedIdx) do
      begin
        LIdx := FSortedIdx[LPos];
        if not StrHasPrefix(FEntries[LIdx].Name, LPrefix) then Break;
        if (Length(FEntries[LIdx].Name) >= Length(LPrefix)+Length(LSuffix)) and
           (StrHasSuffix(FEntries[LIdx].Name, LSuffix)) then
          Exit(LIdx);
        Inc(LPos);
      end;
      Exit(-1);
    end;
    gkComplex: ;
  end;
  for LI:=0 to High(FEntries) do
    if MatchesGlob(FEntries[LI].Name, APattern) then Exit(LI);
  Result := -1;
end;

function TSevenZReaderImpl.EntriesByPrefixIgnoreCase(const APrefix: string): TSevenZEntryInfoArray;
var LIndices: TSevenZIndexArray; LI: Integer;
begin
  LIndices := IndicesByPrefixIgnoreCase(APrefix);
  SetLength(Result, Length(LIndices));
  for LI:=0 to High(LIndices) do Result[LI] := FEntries[LIndices[LI]];
end;

function TSevenZReaderImpl.EntriesBySuffixIgnoreCase(const ASuffix: string): TSevenZEntryInfoArray;
var LIndices: TSevenZIndexArray; LI: Integer;
begin
  LIndices := IndicesBySuffixIgnoreCase(ASuffix);
  SetLength(Result, Length(LIndices));
  for LI:=0 to High(LIndices) do Result[LI] := FEntries[LIndices[LI]];
end;

function TSevenZReaderImpl.FindByPrefixIgnoreCase(const APrefix: string): Integer;
var LStart, LIdx: Integer; LLower, LEntryLower: string;
begin
  EnsureIgnoreCaseBuilt;
  Result := -1;
  if APrefix='' then begin if Length(FEntries)>0 then Exit(0) else Exit(-1); end;
  if Length(FSortedIdxIgnoreCase)=0 then Exit(-1);
  if IsAsciiString(APrefix) then LLower := AsciiLowerStr(APrefix) else LLower := LowerCase(APrefix);
  LStart := LowerBoundPrefixIgnoreCase(APrefix);
  if LStart >= Length(FSortedIdxIgnoreCase) then Exit(-1);
  LIdx := FSortedIdxIgnoreCase[LStart];
  LEntryLower := FLowerNames[LIdx];
  if not StrHasPrefix(LEntryLower, LLower) then Exit(-1);
  Result := LIdx;
end;

function TSevenZReaderImpl.FindBySuffixIgnoreCase(const ASuffix: string): Integer;
var LStart, LIdx: Integer; LLower, LEntryLower: string;
begin
  EnsureIgnoreCaseBuilt;
  Result := -1;
  if ASuffix='' then begin if Length(FEntries)>0 then Exit(0) else Exit(-1); end;
  if Length(FSortedIdxRevIgnoreCase)=0 then Exit(-1);
  if IsAsciiString(ASuffix) then LLower := AsciiLowerStr(ASuffix) else LLower := LowerCase(ASuffix);
  LStart := LowerBoundSuffixIgnoreCase(ASuffix);
  if LStart >= Length(FSortedIdxRevIgnoreCase) then Exit(-1);
  LIdx := FSortedIdxRevIgnoreCase[LStart];
  LEntryLower := FLowerNames[LIdx];
  if not StrHasSuffix(LEntryLower, LLower) then Exit(-1);
  Result := LIdx;
end;

function MatchesGlobIgnoreCase(const AName, APattern: string): Boolean;
var LLowerName, LLowerPat: string;
begin
  // ascii 快道零分配：单源 MatchesGlobCore，避免两份通配循环重复
  if IsAsciiString(AName) and IsAsciiString(APattern) then
    Exit(MatchesGlobCore(AName, APattern, True));
  if IsAsciiString(AName) then LLowerName := AsciiLowerStr(AName) else LLowerName := LowerCase(AName);
  if IsAsciiString(APattern) then LLowerPat := AsciiLowerStr(APattern) else LLowerPat := LowerCase(APattern);
  Result := MatchesGlob(LLowerName, LLowerPat);
end;

function MatchesGlobIgnoreCaseEx(const AName, APattern: string; APatIsAscii: Boolean): Boolean; inline;
var LLowerName, LLowerPat: string;
begin
  // 预计算 APattern IsAscii，避免每条目重复扫模式串（gkComplex 2k 次）
  if APatIsAscii and IsAsciiString(AName) then
    Exit(MatchesGlobCore(AName, APattern, True));
  if IsAsciiString(AName) then LLowerName := AsciiLowerStr(AName) else LLowerName := LowerCase(AName);
  if APatIsAscii then LLowerPat := AsciiLowerStr(APattern) else LLowerPat := LowerCase(APattern);
  Result := MatchesGlob(LLowerName, LLowerPat);
end;

function TSevenZReaderImpl.EntriesByGlobIgnoreCase(const APattern: string): TSevenZEntryInfoArray;
var LI, LCnt: Integer; LPrefix, LSuffix: string; LIdx: Integer; LIdx2: TSevenZIndexArray; LPatIsAscii: Boolean;
  LCpxPref, LCpxSuff: string; LCands: TSevenZIndexArray;
begin
  EnsureIgnoreCaseBuilt;
  Result := nil;
  case ClassifyGlob(APattern, LPrefix, LSuffix) of
    gkEmpty: Exit;
    gkStar: begin Result := GetEntries; Exit; end;
    gkExact: begin LIdx := FindIgnoreCase(APattern); if LIdx >= 0 then begin SetLength(Result,1); Result[0] := FEntries[LIdx]; end; Exit; end;
    gkPrefix: begin Result := EntriesByPrefixIgnoreCase(LPrefix); Exit; end;
    gkSuffix: begin Result := EntriesBySuffixIgnoreCase(LSuffix); Exit; end;
    gkPrefixSuffix: begin LIdx2 := IndicesByPrefixIgnoreCase(LPrefix); LIdx2 := FilterIndicesBySuffixIgnoreCase(LIdx2, LPrefix, LSuffix); SetLength(Result, Length(LIdx2)); for LI:=0 to High(LIdx2) do Result[LI] := FEntries[LIdx2[LI]]; Exit; end;
    gkComplex: ;
  end;
  LPatIsAscii := IsAsciiString(APattern);
  // gkComplex: 复用 FLowerNames/SortedIdxIgnoreCase 索引剪枝 O(log N+M)，bench 见 BenchGlobIgnoreCase
  ExtractComplexBounds(APattern, LCpxPref, LCpxSuff);
  if (LCpxPref <> '') or (LCpxSuff <> '') then
  begin
    if LCpxPref <> '' then
    begin
      LCands := IndicesByPrefixIgnoreCase(LCpxPref);
      if LCpxSuff <> '' then
        LCands := FilterIndicesBySuffixIgnoreCase(LCands, LCpxPref, LCpxSuff);
    end else
      LCands := IndicesBySuffixIgnoreCase(LCpxSuff);
    LCnt := 0;
    for LI:=0 to High(LCands) do if MatchesGlobIgnoreCaseEx(FEntries[LCands[LI]].Name, APattern, LPatIsAscii) then Inc(LCnt);
    SetLength(Result, LCnt);
    LCnt := 0;
    for LI:=0 to High(LCands) do if MatchesGlobIgnoreCaseEx(FEntries[LCands[LI]].Name, APattern, LPatIsAscii) then begin Result[LCnt] := FEntries[LCands[LI]]; Inc(LCnt); end;
    Exit;
  end;
  LCnt := 0;
  for LI:=0 to High(FEntries) do if MatchesGlobIgnoreCaseEx(FEntries[LI].Name, APattern, LPatIsAscii) then Inc(LCnt);
  SetLength(Result, LCnt);
  LCnt := 0;
  for LI:=0 to High(FEntries) do if MatchesGlobIgnoreCaseEx(FEntries[LI].Name, APattern, LPatIsAscii) then begin Result[LCnt] := FEntries[LI]; Inc(LCnt); end;
end;

function TSevenZReaderImpl.FindByGlobIgnoreCase(const APattern: string): Integer;
var LI, LPos, LIdx, LBest: Integer; LPrefix, LSuffix, LLowerPref, LLowerSuff, LEntryLower: string; LPatIsAscii: Boolean;
  LCpxPref, LCpxSuff: string; LCands: TSevenZIndexArray;
begin
  EnsureIgnoreCaseBuilt;
  Result := -1;
  case ClassifyGlob(APattern, LPrefix, LSuffix) of
    gkEmpty: Exit(-1);
    gkStar: begin if Length(FEntries)>0 then Exit(0) else Exit(-1); end;
    gkExact: Exit(FindIgnoreCase(APattern));
    gkPrefix: Exit(FindByPrefixIgnoreCase(LPrefix));
    gkSuffix: Exit(FindBySuffixIgnoreCase(LSuffix));
    gkPrefixSuffix:
    begin
      if IsAsciiString(LPrefix) then LLowerPref := AsciiLowerStr(LPrefix) else LLowerPref := LowerCase(LPrefix);
      if IsAsciiString(LSuffix) then LLowerSuff := AsciiLowerStr(LSuffix) else LLowerSuff := LowerCase(LSuffix);
      LPos := LowerBoundPrefixIgnoreCase(LPrefix);
      while LPos < Length(FSortedIdxIgnoreCase) do
      begin
        LIdx := FSortedIdxIgnoreCase[LPos];
        LEntryLower := FLowerNames[LIdx];
        if not StrHasPrefix(LEntryLower, LLowerPref) then Break;
        if (Length(LEntryLower) >= Length(LLowerPref)+Length(LLowerSuff)) and
           StrHasSuffix(LEntryLower, LLowerSuff) then
          Exit(LIdx);
        Inc(LPos);
      end;
      Exit(-1);
    end;
    gkComplex: ;
  end;
  LPatIsAscii := IsAsciiString(APattern);
  // gkComplex: 复用 IgnoreCase 索引剪枝，避免全表扫描
  ExtractComplexBounds(APattern, LCpxPref, LCpxSuff);
  if (LCpxPref <> '') or (LCpxSuff <> '') then
  begin
    if LCpxPref <> '' then
    begin
      LCands := IndicesByPrefixIgnoreCase(LCpxPref);
      if LCpxSuff <> '' then
        LCands := FilterIndicesBySuffixIgnoreCase(LCands, LCpxPref, LCpxSuff);
    end else
      LCands := IndicesBySuffixIgnoreCase(LCpxSuff);
    LBest := MaxInt;
    for LI:=0 to High(LCands) do
      if MatchesGlobIgnoreCaseEx(FEntries[LCands[LI]].Name, APattern, LPatIsAscii) then
        if LCands[LI] < LBest then LBest := LCands[LI];
    if LBest <> MaxInt then Exit(LBest) else Exit(-1);
  end;
  for LI:=0 to High(FEntries) do if MatchesGlobIgnoreCaseEx(FEntries[LI].Name, APattern, LPatIsAscii) then Exit(LI);
  Result := -1;
end;

function TSevenZReaderImpl.ExtractAll: TSevenZExtractedArray;
var LI: Integer; LIdx: array of Integer;
begin
  SetLength(LIdx, Length(FEntries));
  for LI:=0 to High(FEntries) do LIdx[LI] := LI;
  Result := ExtractIndicesGrouped(LIdx);
end;

function TSevenZReaderImpl.ExtractByPrefixIgnoreCase(const APrefix: string): TSevenZExtractedArray;
var LIndices: TSevenZIndexArray;
begin
  EnsureIgnoreCaseBuilt;
  LIndices := IndicesByPrefixIgnoreCase(APrefix);
  Result := ExtractIndicesGrouped(LIndices);
end;

function TSevenZReaderImpl.ExtractBySuffixIgnoreCase(const ASuffix: string): TSevenZExtractedArray;
var LIndices: TSevenZIndexArray;
begin
  EnsureIgnoreCaseBuilt;
  LIndices := IndicesBySuffixIgnoreCase(ASuffix);
  Result := ExtractIndicesGrouped(LIndices);
end;

function TSevenZReaderImpl.ExtractByGlobIgnoreCase(const APattern: string): TSevenZExtractedArray;
var LErr: string;
begin
  if not TryExtractByGlobIgnoreCaseWithError(APattern, Result, LErr) then
    raise ESevenZError.Create(LErr);
end;

function TSevenZReaderImpl.TryExtractAll(out AExtracted: TSevenZExtractedArray): Boolean;
var Err: string;
begin
  Result := TryExtractAllWithError(AExtracted, Err);
end;

function TSevenZReaderImpl.TryExtractAllWithError(out AExtracted: TSevenZExtractedArray; out AError: string): Boolean;
begin
  AExtracted := nil; AError := ''; Result := False;
  try AExtracted := ExtractAll; Result := True;
  except on E: Exception do begin AError := E.ClassName+': '+E.Message; AExtracted := nil; Result := False; end; end;
end;

type
  TExtractPair = record OrigPos, Folder, EntryIdx: Integer; end;

function TSevenZReaderImpl.ExtractIndicesGrouped(const AIdx: array of Integer): TSevenZExtractedArray;
var LI, LFolderCount, LUseSparse: Integer;
    LDecodedByFolder: array of TBytes; LDecodedValid: array of Boolean;
    LOff, LLen: UInt64; LSub: SizeInt; LData: TBytes;
    LPairs: array of TExtractPair;

  procedure QuickSortPairs(AL, AR: Integer);
  var I, J, P: Integer; T: TExtractPair;
  begin
    I:=AL; J:=AR; P:=LPairs[(AL+AR) div 2].Folder;
    repeat
      while LPairs[I].Folder < P do Inc(I);
      while LPairs[J].Folder > P do Dec(J);
      if I<=J then begin T:=LPairs[I]; LPairs[I]:=LPairs[J]; LPairs[J]:=T; Inc(I); Dec(J); end;
    until I>J;
    if AL<J then QuickSortPairs(AL,J);
    if I<AR then QuickSortPairs(I,AR);
  end;

var LFolderIdx, LPos, LStart, LEnd: Integer;
begin
  Result := nil;
  if Length(AIdx)=0 then Exit;
  SetLength(Result, Length(AIdx));
  LFolderCount := Length(FStreams.Folders);
  // 性能：稠密路径按 FolderCount 分配双数组（1M→~16MB 瞬时），阈值外仍大额分配；
  // 稀疏路径零 FolderCount 分配，按 folder 排序后分组单解码，避免瞬时 RSS 尖峰。
  // 收敛阈值：4096→1024 且因子 8→4；>64k 强制稀疏，避免 500k 级仍走稠密。
  // bench 可观测：bench_sevenz container extract 吞吐与 1M folder RSS 对比验证。
  LUseSparse := 0;
  if LFolderCount > 1024 then
  begin
    if Length(AIdx) * 4 < LFolderCount then LUseSparse := 1
    else if (LFolderCount > 65536) and (Length(AIdx) < LFolderCount) then LUseSparse := 1;
  end;
  if LUseSparse = 0 then
  begin
    SetLength(LDecodedByFolder, LFolderCount);
    SetLength(LDecodedValid, LFolderCount);
    for LI:=0 to High(AIdx) do
    begin
      Result[LI].Info := FEntries[AIdx[LI]];
      LFolderIdx := FFolderIdxOfEntry[AIdx[LI]];
      if LFolderIdx < 0 then begin Result[LI].Data:=nil; Continue; end;
      if (LFolderIdx < 0) or (LFolderIdx >= LFolderCount) then
        raise ESevenZError.CreateFmt('folder idx %d out of range', [LFolderIdx]);
      if not LDecodedValid[LFolderIdx] then
      begin LDecodedByFolder[LFolderIdx]:=DecodeFolder(LFolderIdx); LDecodedValid[LFolderIdx]:=True; end;
      LData := LDecodedByFolder[LFolderIdx];
      if FEntryOffInFolder[AIdx[LI]] < 0 then raise ESevenZError.Create('entry offset poisoned');
      LOff := UInt64(FEntryOffInFolder[AIdx[LI]]);
      LSub := FGlobalSubOfEntry[AIdx[LI]];
      LLen := FStreams.Substreams[LSub].Size;
      if LLen > UInt64(High(SizeInt)) then raise ESevenZLimitError.CreateFmt('substream %d size %d exceeds addressable limit %d', [LSub, LLen, UInt64(High(SizeInt))]);
      if LOff > UInt64(High(SizeInt)) then raise ESevenZLimitError.CreateFmt('substream %d offset %d exceeds addressable limit %d', [LSub, LOff, UInt64(High(SizeInt))]);
      if LOff > High(UInt64) - LLen then raise ESevenZError.Create('substream window overflow');
      if LOff + LLen > UInt64(Length(LData)) then raise ESevenZError.Create('substream window exceeds folder output');
      SetLength(Result[LI].Data, SizeInt(LLen));
      if LLen>0 then Move(LData[SizeInt(LOff)], Result[LI].Data[0], SizeInt(LLen));
      if FStreams.Substreams[LSub].HasCrc and (Crc32OfBytes(Result[LI].Data) <> LongWord(FStreams.Substreams[LSub].Crc)) then
        raise ESevenZError.CreateFmt('entry %d CRC mismatch', [AIdx[LI]]);
    end;
    Exit;
  end;
  // 稀疏路径：按 Folder 排序后分组单解码，零 FolderCount 分配
  SetLength(LPairs, Length(AIdx));
  for LI:=0 to High(AIdx) do
  begin LPairs[LI].OrigPos:=LI; LPairs[LI].EntryIdx:=AIdx[LI]; LPairs[LI].Folder:=FFolderIdxOfEntry[AIdx[LI]]; end;
  if Length(LPairs)>1 then QuickSortPairs(0, High(LPairs));
  LPos:=0;
  while LPos < Length(LPairs) do
  begin
    LFolderIdx := LPairs[LPos].Folder;
    LStart := LPos;
    while (LPos < Length(LPairs)) and (LPairs[LPos].Folder = LFolderIdx) do Inc(LPos);
    LEnd := LPos-1;
    if LFolderIdx < 0 then
    begin
      for LI:=LStart to LEnd do
      begin LSub:=LPairs[LI].OrigPos; Result[LSub].Info:=FEntries[LPairs[LI].EntryIdx]; Result[LSub].Data:=nil; end;
      Continue;
    end;
    if (LFolderIdx < 0) or (LFolderIdx >= LFolderCount) then
      raise ESevenZError.CreateFmt('folder idx %d out of range', [LFolderIdx]);
    LData := DecodeFolder(LFolderIdx);
    for LI:=LStart to LEnd do
    begin
      LSub:=LPairs[LI].EntryIdx;
      Result[LPairs[LI].OrigPos].Info:=FEntries[LSub];
      if FEntryOffInFolder[LSub] < 0 then raise ESevenZError.Create('entry offset poisoned');
      LOff := UInt64(FEntryOffInFolder[LSub]);
      LLen := FStreams.Substreams[FGlobalSubOfEntry[LSub]].Size;
      if LLen > UInt64(High(SizeInt)) then raise ESevenZLimitError.CreateFmt('substream %d size %d exceeds addressable limit %d', [FGlobalSubOfEntry[LSub], LLen, UInt64(High(SizeInt))]);
      if LOff > UInt64(High(SizeInt)) then raise ESevenZLimitError.CreateFmt('substream %d offset %d exceeds addressable limit %d', [FGlobalSubOfEntry[LSub], LOff, UInt64(High(SizeInt))]);
      if LOff > High(UInt64) - LLen then raise ESevenZError.Create('substream window overflow');
      if LOff + LLen > UInt64(Length(LData)) then raise ESevenZError.Create('substream window exceeds folder output');
      SetLength(Result[LPairs[LI].OrigPos].Data, SizeInt(LLen));
      if LLen>0 then Move(LData[SizeInt(LOff)], Result[LPairs[LI].OrigPos].Data[0], SizeInt(LLen));
      if FStreams.Substreams[FGlobalSubOfEntry[LSub]].HasCrc and
         (Crc32OfBytes(Result[LPairs[LI].OrigPos].Data) <> LongWord(FStreams.Substreams[FGlobalSubOfEntry[LSub]].Crc)) then
        raise ESevenZError.CreateFmt('entry %d CRC mismatch', [LSub]);
    end;
  end;
end;

function TSevenZReaderImpl.IndicesByPrefix(const APrefix: string): TSevenZIndexArray;
var LStart, LPos, LIdx, LCnt, LLen: Integer;
begin
  Result := nil;
  LLen := Length(APrefix);
  if LLen = 0 then
  begin
    SetLength(Result, Length(FEntries));
    for LPos := 0 to High(FEntries) do Result[LPos] := LPos;
    Exit;
  end;
  if Length(FSortedIdx) = 0 then Exit;
  LStart := LowerBoundPrefix(APrefix);
  LCnt := 0;
  for LPos := LStart to High(FSortedIdx) do
  begin
    LIdx := FSortedIdx[LPos];
    if not StrHasPrefix(FEntries[LIdx].Name, APrefix) then Break;
    Inc(LCnt);
  end;
  SetLength(Result, LCnt);
  LCnt := 0;
  for LPos := LStart to High(FSortedIdx) do
  begin
    LIdx := FSortedIdx[LPos];
    if not StrHasPrefix(FEntries[LIdx].Name, APrefix) then Break;
    Result[LCnt] := LIdx; Inc(LCnt);
  end;
end;

function TSevenZReaderImpl.IndicesByPrefixIgnoreCase(const APrefix: string): TSevenZIndexArray;
var LStart, LPos, LIdx, LCnt: Integer; LLower: string;
begin
  EnsureIgnoreCaseBuilt;
  Result := nil;
  if APrefix = '' then
  begin
    SetLength(Result, Length(FEntries));
    for LPos := 0 to High(FEntries) do Result[LPos] := LPos;
    Exit;
  end;
  if Length(FSortedIdxIgnoreCase) = 0 then Exit;
  if IsAsciiString(APrefix) then LLower := AsciiLowerStr(APrefix) else LLower := LowerCase(APrefix);
  LStart := LowerBoundPrefixIgnoreCase(APrefix);
  LCnt := 0;
  for LPos := LStart to High(FSortedIdxIgnoreCase) do
  begin
    LIdx := FSortedIdxIgnoreCase[LPos];
    if not StrHasPrefix(FLowerNames[LIdx], LLower) then Break;
    Inc(LCnt);
  end;
  SetLength(Result, LCnt);
  LCnt := 0;
  for LPos := LStart to High(FSortedIdxIgnoreCase) do
  begin
    LIdx := FSortedIdxIgnoreCase[LPos];
    if not StrHasPrefix(FLowerNames[LIdx], LLower) then Break;
    Result[LCnt] := LIdx; Inc(LCnt);
  end;
end;

function TSevenZReaderImpl.FilterIndicesBySuffix(const AIndices: array of Integer; const APrefix, ASuffix: string): TSevenZIndexArray; inline;
var LI, LCnt, LIdx, LNeed: Integer;
begin
  Result := nil;
  LNeed := Length(APrefix) + Length(ASuffix);
  LCnt := 0;
  for LI := 0 to High(AIndices) do
    if (Length(FEntries[AIndices[LI]].Name) >= LNeed) and
       ((Length(ASuffix) = 0) or (StrHasSuffix(FEntries[AIndices[LI]].Name, ASuffix))) then Inc(LCnt);
  SetLength(Result, LCnt);
  LIdx := 0;
  for LI := 0 to High(AIndices) do
    if (Length(FEntries[AIndices[LI]].Name) >= LNeed) and
       ((Length(ASuffix) = 0) or (StrHasSuffix(FEntries[AIndices[LI]].Name, ASuffix))) then
    begin Result[LIdx] := AIndices[LI]; Inc(LIdx); end;
end;

function TSevenZReaderImpl.FilterIndicesBySuffixIgnoreCase(const AIndices: array of Integer; const APrefix, ASuffix: string): TSevenZIndexArray; inline;
var LI, LCnt, LIdx, LNeed: Integer; LLowerSuff: string; LIsAsciiSuff: Boolean;
begin
  EnsureIgnoreCaseBuilt;
  Result := nil;
  LNeed := Length(APrefix) + Length(ASuffix);
  LIsAsciiSuff := IsAsciiString(ASuffix);
  if LIsAsciiSuff then LLowerSuff := AsciiLowerStr(ASuffix) else LLowerSuff := LowerCase(ASuffix);
  LCnt := 0;
  for LI := 0 to High(AIndices) do
  begin
    if LIsAsciiSuff and IsAsciiString(FEntries[AIndices[LI]].Name) then
    begin
      if SuffixMatchesIgnoreCaseAscii(FEntries[AIndices[LI]].Name, LLowerSuff, LNeed) then Inc(LCnt);
    end else
    begin
      // fallback: lower the name
      // For non-ascii, use LowerCase
      if (Length(FLowerNames[AIndices[LI]]) >= LNeed) and
         StrHasSuffix(FLowerNames[AIndices[LI]], LLowerSuff) then Inc(LCnt);
    end;
  end;
  SetLength(Result, LCnt);
  LIdx := 0;
  for LI := 0 to High(AIndices) do
  begin
    if LIsAsciiSuff and IsAsciiString(FEntries[AIndices[LI]].Name) then
    begin
      if SuffixMatchesIgnoreCaseAscii(FEntries[AIndices[LI]].Name, LLowerSuff, LNeed) then begin Result[LIdx] := AIndices[LI]; Inc(LIdx); end;
    end else
    begin
      if (Length(FLowerNames[AIndices[LI]]) >= LNeed) and
         StrHasSuffix(FLowerNames[AIndices[LI]], LLowerSuff) then
      begin Result[LIdx] := AIndices[LI]; Inc(LIdx); end;
    end;
  end;
end;

function TSevenZReaderImpl.IndicesBySuffix(const ASuffix: string): TSevenZIndexArray;
var LStart, LPos, LIdx, LCnt, LLen: Integer;
begin
  Result := nil;
  LLen := Length(ASuffix);
  if LLen = 0 then
  begin
    SetLength(Result, Length(FEntries));
    for LPos := 0 to High(FEntries) do Result[LPos] := LPos;
    Exit;
  end;
  if Length(FSortedIdxRev) = 0 then Exit;
  LStart := LowerBoundSuffix(ASuffix);
  LCnt := 0;
  for LPos := LStart to High(FSortedIdxRev) do
  begin
    LIdx := FSortedIdxRev[LPos];
    if not StrHasSuffix(FEntries[LIdx].Name, ASuffix) then Break;
    Inc(LCnt);
  end;
  SetLength(Result, LCnt);
  LCnt := 0;
  for LPos := LStart to High(FSortedIdxRev) do
  begin
    LIdx := FSortedIdxRev[LPos];
    if not StrHasSuffix(FEntries[LIdx].Name, ASuffix) then Break;
    Result[LCnt] := LIdx; Inc(LCnt);
  end;
end;

function TSevenZReaderImpl.IndicesBySuffixIgnoreCase(const ASuffix: string): TSevenZIndexArray;
var LStart, LPos, LIdx, LCnt: Integer; LLower: string;
begin
  EnsureIgnoreCaseBuilt;
  Result := nil;
  if ASuffix = '' then
  begin
    SetLength(Result, Length(FEntries));
    for LPos := 0 to High(FEntries) do Result[LPos] := LPos;
    Exit;
  end;
  if Length(FSortedIdxRevIgnoreCase) = 0 then Exit;
  if IsAsciiString(ASuffix) then LLower := AsciiLowerStr(ASuffix) else LLower := LowerCase(ASuffix);
  LStart := LowerBoundSuffixIgnoreCase(ASuffix);
  LCnt := 0;
  for LPos := LStart to High(FSortedIdxRevIgnoreCase) do
  begin
    LIdx := FSortedIdxRevIgnoreCase[LPos];
    if not StrHasSuffix(FLowerNames[LIdx], LLower) then Break;
    Inc(LCnt);
  end;
  SetLength(Result, LCnt);
  LCnt := 0;
  for LPos := LStart to High(FSortedIdxRevIgnoreCase) do
  begin
    LIdx := FSortedIdxRevIgnoreCase[LPos];
    if not StrHasSuffix(FLowerNames[LIdx], LLower) then Break;
    Result[LCnt] := LIdx; Inc(LCnt);
  end;
end;

function TSevenZReaderImpl.ExtractByPrefix(const APrefix: string): TSevenZExtractedArray;
var LIndices: TSevenZIndexArray;
begin
  LIndices := IndicesByPrefix(APrefix);
  Result := ExtractIndicesGrouped(LIndices);
end;

function TSevenZReaderImpl.ExtractBySuffix(const ASuffix: string): TSevenZExtractedArray;
var LIndices: TSevenZIndexArray;
begin
  LIndices := IndicesBySuffix(ASuffix);
  Result := ExtractIndicesGrouped(LIndices);
end;

function TSevenZReaderImpl.ExtractByGlob(const APattern: string): TSevenZExtractedArray;
var LErr: string;
begin
  if not TryExtractByGlobWithError(APattern, Result, LErr) then
    raise ESevenZError.Create(LErr);
end;

function TSevenZReaderImpl.TryExtractByGlob(const APattern: string; out AExtracted: TSevenZExtractedArray): Boolean;
var LErr: string;
begin
  Result := TryExtractByGlobWithError(APattern, AExtracted, LErr);
end;

function TSevenZReaderImpl.TryExtractByGlobWithError(const APattern: string; out AExtracted: TSevenZExtractedArray; out AError: string): Boolean;
var LI, LCnt, LIdx: Integer; LPrefix, LSuffix: string; LIndices: array of Integer; LFill: Integer;
begin
  AExtracted := nil; AError := ''; Result := False;
  try
    case ClassifyGlob(APattern, LPrefix, LSuffix) of
      gkEmpty: begin Result := True; Exit; end;
      gkStar: begin AExtracted := ExtractAll; Result := True; Exit; end;
      gkExact:
      begin
        LIdx := Find(APattern);
        if LIdx >= 0 then begin SetLength(AExtracted,1); AExtracted[0].Info := FEntries[LIdx]; AExtracted[0].Data := Extract(LIdx); end;
        Result := True; Exit;
      end;
      gkPrefix: begin AExtracted := ExtractByPrefix(LPrefix); Result := True; Exit; end;
      gkSuffix: begin AExtracted := ExtractBySuffix(LSuffix); Result := True; Exit; end;
      gkPrefixSuffix:
      begin
        LIndices := IndicesByPrefix(LPrefix);
        LIndices := FilterIndicesBySuffix(LIndices, LPrefix, LSuffix);
        AExtracted := ExtractIndicesGrouped(LIndices);
        Result := True; Exit;
      end;
      gkComplex: ;
    end;
    SetLength(AExtracted, 0);
    LCnt := 0;
    for LI:=0 to High(FEntries) do
      if MatchesGlob(FEntries[LI].Name, APattern) then Inc(LCnt);
    if LCnt > 0 then
    begin
      SetLength(LIndices, LCnt);
      LFill := 0;
      for LI:=0 to High(FEntries) do
        if MatchesGlob(FEntries[LI].Name, APattern) then
        begin LIndices[LFill] := LI; Inc(LFill); end;
      AExtracted := ExtractIndicesGrouped(LIndices);
    end;
    Result := True;
  except
    on E: Exception do
    begin
      AError := E.ClassName+': '+E.Message;
      AExtracted := nil;
      Result := False;
    end;
  end;
end;

function TSevenZReaderImpl.TryExtractByPrefix(const APrefix: string; out AExtracted: TSevenZExtractedArray): Boolean;
var LErr: string;
begin
  Result := TryExtractByPrefixWithError(APrefix, AExtracted, LErr);
end;

function TSevenZReaderImpl.TryExtractByPrefixWithError(const APrefix: string; out AExtracted: TSevenZExtractedArray; out AError: string): Boolean;
begin
  AExtracted := nil; AError := ''; Result := False;
  try AExtracted := ExtractByPrefix(APrefix); Result := True;
  except on E: Exception do begin AError := E.ClassName+': '+E.Message; AExtracted := nil; Result := False; end; end;
end;

function TSevenZReaderImpl.TryExtractBySuffix(const ASuffix: string; out AExtracted: TSevenZExtractedArray): Boolean;
var LErr: string;
begin
  Result := TryExtractBySuffixWithError(ASuffix, AExtracted, LErr);
end;

function TSevenZReaderImpl.TryExtractBySuffixWithError(const ASuffix: string; out AExtracted: TSevenZExtractedArray; out AError: string): Boolean;
begin
  AExtracted := nil; AError := ''; Result := False;
  try AExtracted := ExtractBySuffix(ASuffix); Result := True;
  except on E: Exception do begin AError := E.ClassName+': '+E.Message; AExtracted := nil; Result := False; end; end;
end;

function TSevenZReaderImpl.TryExtractByPrefixIgnoreCase(const APrefix: string; out AExtracted: TSevenZExtractedArray): Boolean;
var LErr: string;
begin
  Result := TryExtractByPrefixIgnoreCaseWithError(APrefix, AExtracted, LErr);
end;

function TSevenZReaderImpl.TryExtractByPrefixIgnoreCaseWithError(const APrefix: string; out AExtracted: TSevenZExtractedArray; out AError: string): Boolean;
begin
  EnsureIgnoreCaseBuilt;
  AExtracted := nil; AError := ''; Result := False;
  try AExtracted := ExtractByPrefixIgnoreCase(APrefix); Result := True;
  except on E: Exception do begin AError := E.ClassName+': '+E.Message; AExtracted := nil; Result := False; end; end;
end;

function TSevenZReaderImpl.TryExtractBySuffixIgnoreCase(const ASuffix: string; out AExtracted: TSevenZExtractedArray): Boolean;
var LErr: string;
begin
  Result := TryExtractBySuffixIgnoreCaseWithError(ASuffix, AExtracted, LErr);
end;

function TSevenZReaderImpl.TryExtractBySuffixIgnoreCaseWithError(const ASuffix: string; out AExtracted: TSevenZExtractedArray; out AError: string): Boolean;
begin
  EnsureIgnoreCaseBuilt;
  AExtracted := nil; AError := ''; Result := False;
  try AExtracted := ExtractBySuffixIgnoreCase(ASuffix); Result := True;
  except on E: Exception do begin AError := E.ClassName+': '+E.Message; AExtracted := nil; Result := False; end; end;
end;

function TSevenZReaderImpl.TryExtractByGlobIgnoreCase(const APattern: string; out AExtracted: TSevenZExtractedArray): Boolean;
var LErr: string;
begin
  Result := TryExtractByGlobIgnoreCaseWithError(APattern, AExtracted, LErr);
end;

function TSevenZReaderImpl.TryExtractByGlobIgnoreCaseWithError(const APattern: string; out AExtracted: TSevenZExtractedArray; out AError: string): Boolean;
var LI, LCnt, LIdx: Integer; LPrefix, LSuffix: string; LIndices: array of Integer; LFill: Integer; LPatIsAscii: Boolean;
  LCpxPref, LCpxSuff: string; LCands: TSevenZIndexArray;
begin
  EnsureIgnoreCaseBuilt;
  AExtracted := nil; AError := ''; Result := False;
  try
    case ClassifyGlob(APattern, LPrefix, LSuffix) of
      gkEmpty: begin Result := True; Exit; end;
      gkStar: begin AExtracted := ExtractAll; Result := True; Exit; end;
      gkExact:
      begin
        LIdx := FindIgnoreCase(APattern);
        if LIdx >= 0 then begin SetLength(AExtracted,1); AExtracted[0].Info := FEntries[LIdx]; AExtracted[0].Data := Extract(LIdx); end;
        Result := True; Exit;
      end;
      gkPrefix: begin AExtracted := ExtractByPrefixIgnoreCase(LPrefix); Result := True; Exit; end;
      gkSuffix: begin AExtracted := ExtractBySuffixIgnoreCase(LSuffix); Result := True; Exit; end;
      gkPrefixSuffix:
      begin
        LIndices := IndicesByPrefixIgnoreCase(LPrefix);
        LIndices := FilterIndicesBySuffixIgnoreCase(LIndices, LPrefix, LSuffix);
        AExtracted := ExtractIndicesGrouped(LIndices);
        Result := True; Exit;
      end;
      gkComplex: ;
    end;
    LPatIsAscii := IsAsciiString(APattern);
    // gkComplex: 复用 IgnoreCase 索引剪枝，O(log N+M)
    ExtractComplexBounds(APattern, LCpxPref, LCpxSuff);
    if (LCpxPref <> '') or (LCpxSuff <> '') then
    begin
      if LCpxPref <> '' then
      begin
        LCands := IndicesByPrefixIgnoreCase(LCpxPref);
        if LCpxSuff <> '' then
          LCands := FilterIndicesBySuffixIgnoreCase(LCands, LCpxPref, LCpxSuff);
      end else
        LCands := IndicesBySuffixIgnoreCase(LCpxSuff);
      LCnt := 0;
      for LI:=0 to High(LCands) do if MatchesGlobIgnoreCaseEx(FEntries[LCands[LI]].Name, APattern, LPatIsAscii) then Inc(LCnt);
      SetLength(LIndices, LCnt);
      LFill := 0;
      for LI:=0 to High(LCands) do if MatchesGlobIgnoreCaseEx(FEntries[LCands[LI]].Name, APattern, LPatIsAscii) then begin LIndices[LFill] := LCands[LI]; Inc(LFill); end;
      if LCnt > 0 then AExtracted := ExtractIndicesGrouped(LIndices) else SetLength(AExtracted,0);
      Result := True;
      Exit;
    end;
    LCnt := 0;
    for LI:=0 to High(FEntries) do if MatchesGlobIgnoreCaseEx(FEntries[LI].Name, APattern, LPatIsAscii) then Inc(LCnt);
    SetLength(LIndices, LCnt);
    LFill := 0;
    for LI:=0 to High(FEntries) do if MatchesGlobIgnoreCaseEx(FEntries[LI].Name, APattern, LPatIsAscii) then begin LIndices[LFill] := LI; Inc(LFill); end;
    if LCnt > 0 then AExtracted := ExtractIndicesGrouped(LIndices) else SetLength(AExtracted,0);
    Result := True;
  except on E: Exception do begin AError := E.ClassName+': '+E.Message; AExtracted := nil; Result := False; end; end;
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
  LOff: UInt64;
  LLen: UInt64;
  LTake: UInt64;
  LCrc: LongWord;
  LHasCrc: Boolean;
  LStream: IStream;
  LInitialPos: Int64;
  LHasStream: Boolean;
  LScanOff: UInt64;
  LScanRem: UInt64;
begin
  if AWriter = nil then
    raise EArgumentError.Create('writer must not be nil');
  if (AIndex < 0) or (AIndex >= Length(FEntries)) then
    raise EArgumentError.CreateFmt('entry index %d out of range', [AIndex]);
  LFolderIdx := FFolderIdxOfEntry[AIndex];
  if LFolderIdx < 0 then
    Exit(0);
  LGsub := FGlobalSubOfEntry[AIndex];
  LData := DecodeFolder(LFolderIdx);
  if FEntryOffInFolder[AIndex] < 0 then
    raise ESevenZError.Create('entry offset poisoned');
  LOff := UInt64(FEntryOffInFolder[AIndex]);
  LLen := FStreams.Substreams[LGsub].Size;
  if LLen > UInt64(High(SizeInt)) then
    raise ESevenZLimitError.CreateFmt('substream %d size %d exceeds addressable limit %d', [LGsub, LLen, UInt64(High(SizeInt))]);
  if LOff > UInt64(High(SizeInt)) then
    raise ESevenZLimitError.CreateFmt('substream %d offset %d exceeds addressable limit %d', [LGsub, LOff, UInt64(High(SizeInt))]);
  if LOff > High(UInt64) - LLen then
    raise ESevenZError.Create('substream window overflow');
  if LOff + LLen > UInt64(Length(LData)) then
    raise ESevenZError.Create('substream window exceeds folder output');
  LHasCrc := FStreams.Substreams[LGsub].HasCrc;
  { CRC 预检 + 截断保护：先窗口化校验再触及 IWriter，避免单遍边写边算在 CRC 失配时已向 sink 写入脏数据
    性能：由单遍增量改为两遍窗口扫描（CRC 遍 + 写遍），复用 SEVENZ_EXTRACT_WINDOW 单源常量，窗口化保持 O(1) 额外内存；
    吞吐回退可通过 bench_sevenz 的 ExtractTo/extract 吞吐观测，正确性优先于半程扫描收益 }
  if LHasCrc then
  begin
    LCrc := 0;
    LScanOff := LOff;
    LScanRem := LLen;
    while LScanRem > 0 do
    begin
      if LScanRem > C_EXTRACT_WINDOW then
        LTake := C_EXTRACT_WINDOW
      else
        LTake := LScanRem;
      LCrc := Crc32Update(LCrc, @LData[SizeInt(LScanOff)], SizeUInt(LTake));
      Inc(LScanOff, LTake);
      Dec(LScanRem, LTake);
    end;
    if LCrc <> LongWord(FStreams.Substreams[LGsub].Crc) then
      raise ESevenZError.CreateFmt('entry %d CRC mismatch', [AIndex]);
  end;
  LHasStream := False;
  LStream := nil;
  LInitialPos := -1;
  if AWriter.QueryInterface(IStream, LStream) = 0 then
  begin
    try
      LInitialPos := LStream.GetPosition;
      LHasStream := True;
    except
      LHasStream := False;
      LStream := nil;
    end;
  end;
  Result := 0;
  try
    while LLen > 0 do
    begin
      LTake := LLen;
      if LTake > C_EXTRACT_WINDOW then
        LTake := C_EXTRACT_WINDOW;
      if AWriter.Write(LData[SizeInt(LOff)], SizeUInt(LTake)) <> SizeUInt(LTake) then
        raise EIOError.Create('writer accepted fewer bytes than extracted');
      Inc(Result, Int64(LTake));
      Inc(LOff, LTake);
      Dec(LLen, LTake);
    end;
  except
    on E: Exception do
    begin
      if LHasStream and (LStream <> nil) then
      begin
        try
          LStream.SetPosition(LInitialPos);
        except
        end;
      end;
      raise;
    end;
  end;
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