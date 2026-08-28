unit nextpas.core.zip.sequential;
{**
 * @desc ZIP 顺序读端：从纯顺序 IReader（HTTP body/管道）按 local header +
 *       data descriptor 前进，不整载、不要求 seek。支持 store/deflate、
 *       Zip64 宽度、UTF-8 名称、空/目录条目；描述符条目通过增量扫描定位
 *       描述符（有签名 16/24 与无签名 12/20 四形态），以 CRC/尺寸强校验
 *       + 次头部签名预检避免载荷内误判，并通过 pushback 保证跨条目字节级
 *       精确。与内存/定位流读端共享校验语义（GuardEntryReadable、
 *       DecompressEntryVerified 等价路径）。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.compress.intf,
  nextpas.core.io.intf,
  nextpas.core.zip.base,
  nextpas.core.zip.reader;

type
  {** @desc 顺序 ZIP 读器：Next 推进到下一条目，Open/CopyTo 消费当前条目载荷 *}
  ISequentialZipReader = interface
    ['{B7A9C3D1-E2F4-4A5B-8C6D-9E0F1A2B3C4D}']
    {** 推进到下一条目；False = 已到 central/EOCD，无更多条目 *}
    function Next(out AInfo: TZipEntryInfo): Boolean;
    {** 当前条目元数据（Next 成功后有效） *}
    function Current: TZipEntryInfo;
    {** 当前条目索引（首条 0） *}
    function EntryIndex: Integer;
    {** 是否已到末尾 *}
    function AtEnd: Boolean;
    {** 打开当前条目流（拉式，读到 0 为 EOF，EOF 处校验）；未 Next 或已打开流时 raise *}
    function Open: IDecompressReader;
    {** 泵送当前条目载荷到 ADst（EOF 处校验，返回字节数）；未 Next 或已打开流时 raise *}
    function CopyTo(const ADst: IWriter): SizeUInt;
    {** 跳过当前条目载荷（不解压，直接丢弃）；未 Next 或已打开流时 raise *}
    procedure Skip;
  end;

function NewZipSequentialReader(const ASource: IReader): ISequentialZipReader;
function NewZipSequentialReaderWithOptions(const ASource: IReader;
  const AOptions: TZipReadOptions): ISequentialZipReader;

implementation

uses
  nextpas.core.exception,
  nextpas.core.checksum.crc32,
  nextpas.core.compress.deflate,
  nextpas.core.bytes.builder,
  nextpas.core.zip.aes,
  nextpas.core.zip.common,
  nextpas.core.zip.extra;

const
  C_LOCAL_HEADER_LEN = 30;

type
  TSeqSliceReader = class(TInterfacedObject, IReader, IDecompressReader)
  private
    FParent: Pointer;
    FData: TBytes;
    FPos: SizeUInt;
    FClosed: Boolean;
    procedure NotifyParentClosed;
  public
    constructor Create(AParent: Pointer; const AData: TBytes);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Close;
  end;

  TSequentialZipReader = class(TInterfacedObject, ISequentialZipReader)
  private
    FSrc: IReader;
    FMaxOutput: SizeUInt;
    FMaxTotalOutput: UInt64;
    FMaxDescriptorBuffer: SizeUInt;
    FCumulative: UInt64;
    FPassword: TBytes;
    FIndex: Integer;
    FAtEnd: Boolean;
    FHasCurrent: Boolean;
    FCurrent: TZipEntryInfo;
    FCurrentFlags: Word;
    FCurrentIsDescriptor: Boolean;
    FCurrentRawMethod: Word;
    FStreamOpen: Boolean;
    FPushBack: TBytes;
    FPushPos: SizeUInt;
    FBufferedRaw: TBytes;
    FBufferedReady: Boolean;
    procedure CheckNoStream;
    procedure CheckTotalLimit;
    procedure ReadExactBytes(out ADst: TBytes; ACount: SizeUInt; const AWhat: string);
    procedure ReadExactBuf(var ABuf; ACount: SizeUInt; const AWhat: string);
    procedure PushBack(const AData: TBytes);
    function HasPushBack: Boolean; inline;
    procedure ParseCurrentLocal;
    function CollectDescriptorPayload: TBytes;
    function MakeDecompressedReader: IDecompressReader;
  public
    constructor Create(const ASource: IReader; AMaxOutput: SizeUInt;
      AMaxTotalOutput: UInt64; AMaxDescriptorBuffer: SizeUInt; const APassword: TBytes);
    function Next(out AInfo: TZipEntryInfo): Boolean;
    function Current: TZipEntryInfo;
    function EntryIndex: Integer;
    function AtEnd: Boolean;
    function Open: IDecompressReader;
    function CopyTo(const ADst: IWriter): SizeUInt;
    procedure Skip;
  end;

constructor TSeqSliceReader.Create(AParent: Pointer; const AData: TBytes);
begin
  inherited Create;
  FParent := AParent;
  FData := AData;
  FPos := 0;
  FClosed := False;
end;

procedure TSeqSliceReader.NotifyParentClosed;
var
  LParent: TSequentialZipReader;
begin
  if FParent <> nil then
  begin
    LParent := TSequentialZipReader(FParent);
    LParent.FStreamOpen := False;
    FParent := nil;
  end;
end;

function TSeqSliceReader.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LAvail: SizeUInt;
begin
  if FClosed then
    raise EIOError.Create('zip entry stream: read after close');
  if ACount = 0 then
    Exit(0);
  if FPos >= SizeUInt(Length(FData)) then
    Exit(0);
  LAvail := SizeUInt(Length(FData)) - FPos;
  if ACount < LAvail then
    Result := ACount
  else
    Result := LAvail;
  if Result > 0 then
  begin
    Move(FData[FPos], ABuf, Result);
    Inc(FPos, Result);
  end;
end;

procedure TSeqSliceReader.Close;
begin
  if not FClosed then
  begin
    FClosed := True;
    NotifyParentClosed;
  end;
end;

constructor TSequentialZipReader.Create(const ASource: IReader;
  AMaxOutput: SizeUInt; AMaxTotalOutput: UInt64; AMaxDescriptorBuffer: SizeUInt; const APassword: TBytes);
begin
  inherited Create;
  if ASource = nil then
    raise EArgumentError.Create('zip: nil source reader');
  FSrc := ASource;
  FMaxOutput := AMaxOutput;
  FMaxTotalOutput := AMaxTotalOutput;
  if AMaxDescriptorBuffer = 0 then
    FMaxDescriptorBuffer := C_ZIP_DEFAULT_MAX_DESCRIPTOR
  else
    FMaxDescriptorBuffer := AMaxDescriptorBuffer;
  FCumulative := 0;
  FPassword := Copy(APassword);
  FIndex := -1;
  FAtEnd := False;
  FHasCurrent := False;
  FStreamOpen := False;
  FCurrent := Default(TZipEntryInfo);
  FCurrentFlags := 0;
  FCurrentIsDescriptor := False;
  FPushBack := nil;
  FPushPos := 0;
  FBufferedRaw := nil;
  FBufferedReady := False;
end;

procedure TSequentialZipReader.CheckNoStream;
begin
  if FStreamOpen then
    raise EInvalidOperationError.Create(
      'zip sequential: previous entry stream not closed');
end;

procedure TSequentialZipReader.CheckTotalLimit;
begin
  if FMaxTotalOutput = 0 then
    Exit;
  if FCurrent.UncompressedSize > FMaxTotalOutput then
    raise EIOError.Create('zip: total uncompressed size exceeds limit');
  if FCumulative > FMaxTotalOutput - FCurrent.UncompressedSize then
    raise EIOError.Create('zip: total uncompressed size exceeds limit');
  Inc(FCumulative, FCurrent.UncompressedSize);
end;

function TSequentialZipReader.HasPushBack: Boolean;
begin
  Result := (FPushBack <> nil) and (FPushPos < SizeUInt(Length(FPushBack)));
end;

procedure TSequentialZipReader.PushBack(const AData: TBytes);
var
  LRem: TBytes;
  LOldLen, LRemLen: SizeUInt;
begin
  if Length(AData) = 0 then
    Exit;
  if not HasPushBack then
  begin
    FPushBack := AData;
    FPushPos := 0;
    Exit;
  end;
  LRemLen := SizeUInt(Length(FPushBack)) - FPushPos;
  SetLength(LRem, LRemLen);
  if LRemLen > 0 then
    Move(FPushBack[FPushPos], LRem[0], LRemLen);
  LOldLen := SizeUInt(Length(AData));
  FPushBack := AData;
  SetLength(FPushBack, LOldLen + LRemLen);
  if LRemLen > 0 then
    Move(LRem[0], FPushBack[LOldLen], LRemLen);
  FPushPos := 0;
end;

procedure TSequentialZipReader.ReadExactBuf(var ABuf; ACount: SizeUInt;
  const AWhat: string);
var
  LOff, LRead, LWant: SizeUInt;
  LP: PByte;
begin
  if ACount = 0 then
    Exit;
  LP := @ABuf;
  LOff := 0;
  while LOff < ACount do
  begin
    LWant := ACount - LOff;
    if HasPushBack then
    begin
      LRead := SizeUInt(Length(FPushBack)) - FPushPos;
      if LRead > LWant then
        LRead := LWant;
      Move(FPushBack[FPushPos], (LP + LOff)^, LRead);
      Inc(FPushPos, LRead);
      if FPushPos >= SizeUInt(Length(FPushBack)) then
      begin
        FPushBack := nil;
        FPushPos := 0;
      end;
      Inc(LOff, LRead);
      Continue;
    end;
    LRead := FSrc.Read((LP + LOff)^, LWant);
    if LRead = 0 then
      raise EParseError.Create('zip: truncated ' + AWhat);
    Inc(LOff, LRead);
  end;
end;

procedure TSequentialZipReader.ReadExactBytes(out ADst: TBytes;
  ACount: SizeUInt; const AWhat: string);
begin
  SetLength(ADst, ACount);
  if ACount = 0 then
    Exit;
  ReadExactBuf(ADst[0], ACount, AWhat);
end;

procedure TSequentialZipReader.ParseCurrentLocal;
var
  LFixed: TBytes;
  LVerNeeded, LFlags, LMethod, LDosTime, LDosDate, LNameLen, LExtraLen: Word;
  LCrc, LCSize32, LUSize32: LongWord;
  LNameBytes, LExtraBytes: TBytes;
  LName: string;
  LCSize, LUSize: UInt64;
  LHasAes, LIsDir: Boolean;
  LAesVersion, LAesVendor, LAesRealMethod: Word;
  LAesStrength: Byte;
begin
  ReadExactBytes(LFixed, 4, 'local header signature');
  if LE32At(LFixed, 0) <> C_ZIP_LOCAL_SIG then
  begin
    if IsKnownZipSig(LE32At(LFixed, 0)) then
    begin
      PushBack(LFixed);
      FAtEnd := True;
      FHasCurrent := False;
      Exit;
    end;
    raise EParseError.Create('zip: bad local header signature');
  end;
  ReadExactBytes(LFixed, 26, 'local header body');
  LVerNeeded := LE16At(LFixed, 0);
  LFlags := LE16At(LFixed, 2);
  LMethod := LE16At(LFixed, 4);
  LDosTime := LE16At(LFixed, 6);
  LDosDate := LE16At(LFixed, 8);
  LCrc := LE32At(LFixed, 10);
  LCSize32 := LE32At(LFixed, 14);
  LUSize32 := LE32At(LFixed, 18);
  LNameLen := LE16At(LFixed, 22);
  LExtraLen := LE16At(LFixed, 24);
  if LNameLen > 0 then
    ReadExactBytes(LNameBytes, LNameLen, 'local file name')
  else
    LNameBytes := nil;
  if LExtraLen > 0 then
    ReadExactBytes(LExtraBytes, LExtraLen, 'local extra field')
  else
    LExtraBytes := nil;
  LName := '';
  if LNameLen > 0 then
  begin
    SetLength(LName, LNameLen);
    Move(LNameBytes[0], PChar(LName)^, SizeUInt(LNameLen));
  end;
  LCSize := LCSize32;
  LUSize := LUSize32;
  DecodeLocalExtra(LExtraBytes, LUSize, LCSize, LHasAes, LAesVersion,
    LAesVendor, LAesRealMethod, LAesStrength);
  if ((LFlags and C_ZIP_FLAG_DESCRIPTOR) = 0) and
     ((LUSize = UInt64($FFFFFFFF)) or (LCSize = UInt64($FFFFFFFF))) then
    raise EParseError.Create('zip: missing Zip64 extra field: ' + LName);
  FCurrentFlags := LFlags;
  FCurrentIsDescriptor := (LFlags and C_ZIP_FLAG_DESCRIPTOR) <> 0;
  FCurrentRawMethod := LMethod;
  FCurrent := Default(TZipEntryInfo);
  FCurrent.Name := LName;
  FCurrent.IsEncrypted := (LFlags and C_ZIP_FLAG_ENCRYPTED) <> 0;
  FCurrent.AesVersion := 0;
  FCurrent.AesStrengthCode := 0;
  if LMethod = C_ZIP_METHOD_WINZIP_AES then
  begin
    if not FCurrent.IsEncrypted then
      raise EParseError.Create(
        'zip: method 99 without encryption flag: ' + LName);
    if not LHasAes then
      raise EParseError.Create(
        'zip: missing WinZip AES extra field: ' + LName);
    if (LAesVersion <> C_WINZIP_AES_VERSION_1) and
       (LAesVersion <> C_WINZIP_AES_VERSION_2) then
      raise ENotSupportedError.CreateFmt(
        'zip: unsupported WinZip AES version %d: %s',
        [LAesVersion, LName]);
    if (LAesStrength < 1) or (LAesStrength > 3) then
      raise EParseError.Create('zip: invalid WinZip AES strength code');
    FCurrent.AesVersion := LAesVersion;
    FCurrent.AesStrengthCode := LAesStrength;
    LMethod := LAesRealMethod;
  end;
  if LMethod = C_ZIP_METHOD_DEFLATE then
    FCurrent.Method := zmDeflate
  else
    FCurrent.Method := zmStore;
  FCurrent.MethodCode := LMethod;
  FCurrent.Crc32 := LCrc;
  if FCurrentIsDescriptor then
  begin
    FCurrent.CompressedSize := 0;
    FCurrent.UncompressedSize := 0;
  end
  else
  begin
    FCurrent.CompressedSize := LCSize;
    FCurrent.UncompressedSize := LUSize;
  end;
  FCurrent.ModTimeUnixSec := UnixFromDosDateTime(LDosDate, LDosTime);
  FCurrent.LocalHeaderOffset := 0;
  LIsDir := False;
  if (LNameLen > 0) and (LName[Length(LName)] = '/') then
    LIsDir := True;
  FCurrent.IsDirectory := LIsDir;
  FCurrent.ExternalAttrs := 0;
  FCurrent.IsSymlink := False;
  FHasCurrent := True;
end;

function TSequentialZipReader.CollectDescriptorPayload: TBytes;
var
  LBuilder: IBytesBuilder;
  LChunk: array[0..8191] of Byte;
  LRead: SizeUInt;
  LLen, LPrevLen: SizeUInt;
  LPos: Integer;
  LCandCrc: LongWord;
  LCandCSize, LCandUSize: UInt64;
  LCandCSize64, LCandUSize64: UInt64;
  LFound: Boolean;
  LFoundPos: SizeUInt;
  LFoundCrc: LongWord;
  LFoundCSize, LFoundUSize: UInt64;
  LFoundDescSize: SizeUInt;
  LExtraAfter: TBytes;
  LScanStart, LScanEnd: Integer;
  LPayload: TBytes;
  LNextSigNeed: SizeUInt;
  LData: PByte;
  function LE32Ptr(AOff: SizeUInt): LongWord; inline;
  begin
    Result := LongWord(LData[AOff]) or (LongWord(LData[AOff + 1]) shl 8) or
      (LongWord(LData[AOff + 2]) shl 16) or (LongWord(LData[AOff + 3]) shl 24);
  end;
  function LE64Ptr(AOff: SizeUInt): UInt64; inline;
  begin
    Result := UInt64(LE32Ptr(AOff)) or (UInt64(LE32Ptr(AOff + 4)) shl 32);
  end;
  function TryDescriptorAt(APos: SizeUInt; ADescSize: SizeUInt; out ACrc: LongWord;
    out ACSize, AUSize: UInt64): Boolean;
  var
    LCrcTmp: LongWord;
    LCSizeTmp, LUSizeTmp: UInt64;
    LPay, LPlain, LDec: TBytes;
    LCalc: LongWord;
  begin
    Result := False;
    if ADescSize = 16 then
    begin
      LCrcTmp := LE32Ptr(APos + 4);
      LCSizeTmp := LE32Ptr(APos + 8);
      LUSizeTmp := LE32Ptr(APos + 12);
    end
    else
    begin
      LCrcTmp := LE32Ptr(APos + 4);
      LCSizeTmp := LE64Ptr(APos + 8);
      LUSizeTmp := LE64Ptr(APos + 16);
    end;
    if LCSizeTmp <> APos then
      Exit;
    if (not FCurrent.IsEncrypted) and (FCurrent.Method = zmStore) and (LUSizeTmp <> APos) then
      Exit;
    if (FMaxOutput > 0) and (LUSizeTmp > UInt64(FMaxOutput)) then
      Exit;
    if APos > 0 then
    begin
      SetLength(LPay, APos);
      Move(LData^, LPay[0], APos);
    end
    else
      LPay := nil;
    if FCurrent.IsEncrypted then
    begin
      try
        LPlain := UnsealWinZipAesPayload(FPassword, LPay, FCurrent.AesStrengthCode, FCurrent.Name);
      except
        on E: EInvalidOperationError do raise;
        on E: EIOError do raise;
        on E: Exception do Exit;
      end;
      if FCurrent.Method = zmStore then
      begin
        if UInt64(Length(LPlain)) <> LUSizeTmp then Exit;
        if LUSizeTmp = 0 then LCalc := 0 else LCalc := Crc32OfBytes(LPlain);
        if LCalc <> LCrcTmp then Exit;
      end
      else
      begin
        try
          LDec := RawDeflateDecompressSized(LPlain, SizeUInt(LUSizeTmp), FMaxOutput);
        except
          on E: EIOError do raise;
          on E: Exception do Exit;
        end;
        if SizeUInt(Length(LDec)) <> LUSizeTmp then Exit;
        if Crc32OfBytes(LDec) <> LCrcTmp then Exit;
      end;
    end
    else
    begin
      if APos > 0 then LCalc := Crc32OfBytes(LPay) else LCalc := 0;
      if FCurrent.Method = zmStore then
      begin
        if LCalc <> LCrcTmp then Exit;
      end
      else
      begin
        try
          LDec := RawDeflateDecompressSized(LPay, SizeUInt(LUSizeTmp), FMaxOutput);
        except
          on E: EIOError do raise;
          on E: Exception do Exit;
        end;
        if SizeUInt(Length(LDec)) <> LUSizeTmp then Exit;
        if Crc32OfBytes(LDec) <> LCrcTmp then Exit;
      end;
    end;
    ACrc := LCrcTmp;
    ACSize := LCSizeTmp;
    AUSize := LUSizeTmp;
    Result := True;
  end;
  function TryNoSigAt(APos: SizeUInt; ADescSize: SizeUInt; out ACrc: LongWord;
    out ACSize, AUSize: UInt64): Boolean;
  var
    LCrcTmp: LongWord;
    LCSizeTmp, LUSizeTmp: UInt64;
    LPay, LPlain, LDec: TBytes;
    LCalc: LongWord;
  begin
    Result := False;
    if ADescSize = 12 then
    begin
      LCrcTmp := LE32Ptr(APos + 0);
      LCSizeTmp := LE32Ptr(APos + 4);
      LUSizeTmp := LE32Ptr(APos + 8);
    end
    else
    begin
      LCrcTmp := LE32Ptr(APos + 0);
      LCSizeTmp := LE64Ptr(APos + 4);
      LUSizeTmp := LE64Ptr(APos + 12);
    end;
    if LCSizeTmp <> APos then Exit;
    if (not FCurrent.IsEncrypted) and (FCurrent.Method = zmStore) and (LUSizeTmp <> APos) then Exit;
    if (FMaxOutput > 0) and (LUSizeTmp > UInt64(FMaxOutput)) then Exit;
    if APos > 0 then
    begin
      SetLength(LPay, APos);
      Move(LData^, LPay[0], APos);
    end
    else
      LPay := nil;
    if FCurrent.IsEncrypted then
    begin
      try
        LPlain := UnsealWinZipAesPayload(FPassword, LPay, FCurrent.AesStrengthCode, FCurrent.Name);
      except
        on E: EInvalidOperationError do raise;
        on E: EIOError do raise;
        on E: Exception do Exit;
      end;
      if FCurrent.Method = zmStore then
      begin
        if UInt64(Length(LPlain)) <> LUSizeTmp then Exit;
        if LUSizeTmp = 0 then LCalc := 0 else LCalc := Crc32OfBytes(LPlain);
        if LCalc <> LCrcTmp then Exit;
      end
      else
      begin
        try
          LDec := RawDeflateDecompressSized(LPlain, SizeUInt(LUSizeTmp), FMaxOutput);
        except
          on E: EIOError do raise;
          on E: Exception do Exit;
        end;
        if SizeUInt(Length(LDec)) <> LUSizeTmp then Exit;
        if Crc32OfBytes(LDec) <> LCrcTmp then Exit;
      end;
    end
    else
    begin
      if APos > 0 then LCalc := Crc32OfBytes(LPay) else LCalc := 0;
      if FCurrent.Method = zmStore then
      begin
        if LCalc <> LCrcTmp then Exit;
      end
      else
      begin
        try
          LDec := RawDeflateDecompressSized(LPay, SizeUInt(LUSizeTmp), FMaxOutput);
        except
          on E: EIOError do raise;
          on E: Exception do Exit;
        end;
        if SizeUInt(Length(LDec)) <> LUSizeTmp then Exit;
        if Crc32OfBytes(LDec) <> LCrcTmp then Exit;
      end;
    end;
    ACrc := LCrcTmp;
    ACSize := LCSizeTmp;
    AUSize := LUSizeTmp;
    Result := True;
  end;
begin
  if FCurrent.IsEncrypted and (Length(FPassword) = 0) then
    raise EInvalidOperationError.Create(
      'zip: entry is encrypted, no password configured: ' + FCurrent.Name);
  LBuilder := CreateBytesBuilder(8192);
  LFound := False;
  LFoundPos := 0;
  LFoundCrc := 0;
  LFoundCSize := 0;
  LFoundUSize := 0;
  LFoundDescSize := 16;
  repeat
    LRead := 0;
    if HasPushBack then
    begin
      LRead := SizeUInt(Length(FPushBack)) - FPushPos;
      if LRead > 8192 then
        LRead := 8192;
      Move(FPushBack[FPushPos], LChunk[0], LRead);
      Inc(FPushPos, LRead);
      if FPushPos >= SizeUInt(Length(FPushBack)) then
      begin
        FPushBack := nil;
        FPushPos := 0;
      end;
    end
    else
      LRead := FSrc.Read(LChunk[0], 8192);
    if LRead = 0 then
      raise EParseError.Create('zip: truncated descriptor payload for ' +
        FCurrent.Name);
    LPrevLen := LBuilder.Length;
    LBuilder.AppendBytes(@LChunk[0], LRead);
    LLen := LBuilder.Length;
    LData := LBuilder.Data;
    if LLen < 12 then
      Continue;
    if LPrevLen > 40 then
      LScanStart := Integer(LPrevLen) - 40
    else
      LScanStart := 0;
    LScanEnd := Integer(LLen) - 12;
    for LPos := LScanStart to LScanEnd do
    begin
      if LE32Ptr(SizeUInt(LPos)) = C_ZIP_DESCRIPTOR_SIG then
      begin
        if LLen - SizeUInt(LPos) >= 16 then
        begin
          { 先验 next sig 已知性与尺寸自洽，再进重校验（CRC/试解压），避免载荷
            内大量假签名触发 O(n·m) 试解压的 CPU bomb }
          if LLen - SizeUInt(LPos + 16) >= 4 then
          begin
            if not IsKnownZipSig(LE32Ptr(SizeUInt(LPos + 16))) then
            begin
              { 24 位描述符可能仍成立，延后至 24 分支再判 }
            end
            else if TryDescriptorAt(SizeUInt(LPos), 16, LCandCrc, LCandCSize, LCandUSize) then
            begin
              LFound := True;
              LFoundPos := SizeUInt(LPos);
              LFoundCrc := LCandCrc;
              LFoundCSize := LCandCSize;
              LFoundUSize := LCandUSize;
              LFoundDescSize := 16;
              Break;
            end;
          end
          else if TryDescriptorAt(SizeUInt(LPos), 16, LCandCrc, LCandCSize, LCandUSize) then
            Continue; { 尾部截断，待更多数据 }
        end;
        if LLen - SizeUInt(LPos) >= 24 then
        begin
          if LLen - SizeUInt(LPos + 24) >= 4 then
          begin
            if not IsKnownZipSig(LE32Ptr(SizeUInt(LPos + 24))) then
            begin
              { no-sig 分支延后 }
            end
            else if TryDescriptorAt(SizeUInt(LPos), 24, LCandCrc, LCandCSize64, LCandUSize64) then
            begin
              LFound := True;
              LFoundPos := SizeUInt(LPos);
              LFoundCrc := LCandCrc;
              LFoundCSize := LCandCSize64;
              LFoundUSize := LCandUSize64;
              LFoundDescSize := 24;
              Break;
            end;
          end
          else
            Continue;
        end;
        if LFound then Break;
      end;
      { 无签名描述符：12 字节 (crc+u32+u32) 与 20 字节 (crc+u64+u64)，以次头部签名预检为门 }
      if LLen - SizeUInt(LPos) >= 12 then
      begin
        if LLen - SizeUInt(LPos + 12) >= 4 then
        begin
          if IsKnownZipSig(LE32Ptr(SizeUInt(LPos + 12))) then
            if TryNoSigAt(SizeUInt(LPos), 12, LCandCrc, LCandCSize, LCandUSize) then
            begin
              LFound := True;
              LFoundPos := SizeUInt(LPos);
              LFoundCrc := LCandCrc;
              LFoundCSize := LCandCSize;
              LFoundUSize := LCandUSize;
              LFoundDescSize := 12;
              Break;
            end;
        end
        else
          Continue;
      end;
      if LLen - SizeUInt(LPos) >= 20 then
      begin
        if LLen - SizeUInt(LPos + 20) >= 4 then
        begin
          if IsKnownZipSig(LE32Ptr(SizeUInt(LPos + 20))) then
            if TryNoSigAt(SizeUInt(LPos), 20, LCandCrc, LCandCSize64, LCandUSize64) then
            begin
              LFound := True;
              LFoundPos := SizeUInt(LPos);
              LFoundCrc := LCandCrc;
              LFoundCSize := LCandCSize64;
              LFoundUSize := LCandUSize64;
              LFoundDescSize := 20;
              Break;
            end;
        end
        else
          Continue;
      end;
    end;
    if LFound then
      Break;
    if (LLen > 64 * 1024 * 1024) and (LLen > FMaxOutput) then
      raise EParseError.Create('zip: descriptor not found for ' +
        FCurrent.Name);
    if LLen > FMaxDescriptorBuffer then
      raise EParseError.Create('zip: descriptor not found for ' +
        FCurrent.Name);
  until False;
  SetLength(LPayload, LFoundPos);
  if LFoundPos > 0 then
    Move(LData^, LPayload[0], LFoundPos);
  if FCurrent.AesVersion = C_WINZIP_AES_VERSION_2 then
    FCurrent.Crc32 := 0
  else
    FCurrent.Crc32 := LFoundCrc;
  FCurrent.CompressedSize := LFoundCSize;
  FCurrent.UncompressedSize := LFoundUSize;
  if LLen > LFoundPos + LFoundDescSize then
  begin
    SetLength(LExtraAfter, LLen - LFoundPos - LFoundDescSize);
    Move((LData + LFoundPos + LFoundDescSize)^, LExtraAfter[0], Length(LExtraAfter));
    PushBack(LExtraAfter);
  end;
  Result := LPayload;
end;

function TSequentialZipReader.MakeDecompressedReader: IDecompressReader;
var
  LRaw, LDecompressed: TBytes;
begin
  GuardEntryReadable(FCurrent, FCurrentFlags);
  if FCurrent.IsEncrypted and (Length(FPassword) = 0) then
    raise EInvalidOperationError.Create(
      'zip: entry is encrypted, no password configured: ' + FCurrent.Name);
  if FCurrentIsDescriptor then
  begin
    if FBufferedReady then
    begin
      LRaw := FBufferedRaw;
      FBufferedRaw := nil;
      FBufferedReady := False;
    end
    else
      LRaw := CollectDescriptorPayload;
  end
  else
  begin
    if FCurrent.CompressedSize > 0 then
      ReadExactBytes(LRaw, SizeUInt(FCurrent.CompressedSize),
        'entry payload for ' + FCurrent.Name)
    else
      LRaw := nil;
  end;
  LDecompressed := DecompressEntryVerified(FCurrent, LRaw, FPassword,
    FMaxOutput);
  Result := TSeqSliceReader.Create(Pointer(Self), LDecompressed);
end;

function TSequentialZipReader.Next(out AInfo: TZipEntryInfo): Boolean;
var
  LRaw: TBytes;
begin
  CheckNoStream;
  if FAtEnd then
  begin
    AInfo := Default(TZipEntryInfo);
    Result := False;
    Exit;
  end;
  FCurrent := Default(TZipEntryInfo);
  FHasCurrent := False;
  FBufferedReady := False;
  FBufferedRaw := nil;
  ParseCurrentLocal;
  if FAtEnd then
  begin
    AInfo := Default(TZipEntryInfo);
    Result := False;
    Exit;
  end;
  if not FHasCurrent then
  begin
    FAtEnd := True;
    AInfo := Default(TZipEntryInfo);
    Result := False;
    Exit;
  end;
  if FCurrentIsDescriptor then
  begin
    LRaw := CollectDescriptorPayload;
    FBufferedRaw := LRaw;
    FBufferedReady := True;
  end;
  CheckTotalLimit;
  Inc(FIndex);
  AInfo := FCurrent;
  Result := True;
end;

function TSequentialZipReader.Current: TZipEntryInfo;
begin
  if not FHasCurrent then
    raise EInvalidOperationError.Create('zip sequential: no current entry');
  Result := FCurrent;
end;

function TSequentialZipReader.EntryIndex: Integer;
begin
  Result := FIndex;
end;

function TSequentialZipReader.AtEnd: Boolean;
begin
  Result := FAtEnd;
end;

function TSequentialZipReader.Open: IDecompressReader;
begin
  if not FHasCurrent then
    raise EInvalidOperationError.Create('zip sequential: no current entry');
  if FStreamOpen then
    raise EInvalidOperationError.Create(
      'zip sequential: entry stream already open');
  FStreamOpen := True;
  try
    Result := MakeDecompressedReader;
  except
    FStreamOpen := False;
    raise;
  end;
end;

function TSequentialZipReader.CopyTo(const ADst: IWriter): SizeUInt;
var
  LS: IDecompressReader;
  LBuf: array[0..65535] of Byte;
  LN: SizeUInt;
  LHold: IDecompressReader;
begin
  if ADst = nil then
    raise EArgumentError.Create('zip: destination writer is nil');
  LHold := Open;
  LS := LHold;
  Result := 0;
  try
    repeat
      LN := LS.Read(LBuf[0], SizeOf(LBuf));
      if LN > 0 then
      begin
        if ADst.Write(LBuf[0], LN) <> LN then
          raise EIOError.Create('zip: short write while pumping entry');
        Inc(Result, LN);
      end;
    until LN = 0;
  finally
    LS.Close;
  end;
end;

procedure TSequentialZipReader.Skip;
var
  LDummy: TBytes;
begin
  if not FHasCurrent then
    raise EInvalidOperationError.Create('zip sequential: no current entry');
  CheckNoStream;
  if FCurrentIsDescriptor then
  begin
    if FBufferedReady then
    begin
      FBufferedRaw := nil;
      FBufferedReady := False;
    end
    else
      LDummy := CollectDescriptorPayload;
  end
  else
  begin
    if FCurrent.CompressedSize > 0 then
    begin
      SetLength(LDummy, SizeUInt(FCurrent.CompressedSize));
      ReadExactBuf(LDummy[0], SizeUInt(FCurrent.CompressedSize),
        'skip payload for ' + FCurrent.Name);
    end;
  end;
  FHasCurrent := False;
end;

function NewZipSequentialReader(const ASource: IReader): ISequentialZipReader;
begin
  Result := NewZipSequentialReaderWithOptions(ASource,
    DefaultZipReadOptions);
end;

function NewZipSequentialReaderWithOptions(const ASource: IReader;
  const AOptions: TZipReadOptions): ISequentialZipReader;
var
  LMax, LDesc: SizeUInt;
begin
  LMax := AOptions.MaxOutputSize;
  if LMax = 0 then
    LMax := C_ZIP_DEFAULT_MAX_OUTPUT;
  LDesc := AOptions.MaxDescriptorBuffer;
  if LDesc = 0 then
    LDesc := C_ZIP_DEFAULT_MAX_DESCRIPTOR;
  Result := TSequentialZipReader.Create(ASource, LMax,
    AOptions.MaxTotalOutputSize, LDesc, AOptions.Password);
end;

end.
