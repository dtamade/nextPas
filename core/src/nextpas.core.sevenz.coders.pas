unit nextpas.core.sevenz.coders;

{**
 * nextpas.core.sevenz.coders - coder 执行引擎与后端选择
 *
 * 按 folder 的 coder 有向图迭代解码（线性链为常见形态，实现支持任意绑定拓扑）。
 * LZMA 后端接口化：纯 Pascal 与 liblzma FFI 双实现运行时切换；
 * Copy 为本模块内置；BCJ/Delta 等过滤器由 nextpas.core.sevenz.filters 单源实现，
 * 本模块仅经 SevenZFilterConvert 分发，不再重复暴露 Delta 编解码入口。
 *}

{$I nextpas.core.settings.inc}
{$PUSH}{$WARN 5024 OFF}

interface

uses
  nextpas.core.base,
  nextpas.core.sevenz.base,
  nextpas.core.sevenz.intf,
  nextpas.core.sevenz.header;

{ 设置 LZMA 后端偏好；下次解码起生效 }
procedure SevenZSetLzmaBackend(ABackend: TSevenZLzmaBackend);
function SevenZRequestedBackend: TSevenZLzmaBackend;

{ 当前实际生效的后端（解析 Auto/FFI 不可用回落后的结果） }
function SevenZActiveBackend: TSevenZLzmaBackend;

{ 取当前生效的 LZMA 解码器实例 }
function SevenZAcquireDecoder: ISevenZLzmaDecoder;

{ 取当前生效的 LZMA 编码器实例 }
function SevenZAcquireEncoder: ISevenZLzmaEncoder;

{ 执行一个 folder 解码链：APackStreams 为该 folder 的 pack 流切片序列，
  返回主输出流字节。方法不支持或尺寸不符抛 ESevenZError。
  APassword 仅 AES256 coder 使用（无加密 coder 时忽略） }
function SevenZDecodeFolder(const AFolder: TSevenZFolder;
  const APackStreams: array of TBytes;
  const APassword: string): TBytes;

{ Deflate 解码测试钩子：直通内部分支，供回归测试验证 zlib/raw 双路径 }
function SevenZDeflateDecodeForTest(const AInput: TBytes; AOutSize: UInt64): TBytes;
{ BZip2 解码测试钩子 }
function SevenZBZip2DecodeForTest(const AInput: TBytes; AOutSize: UInt64): TBytes;

implementation

uses
  nextpas.core.errors,
  nextpas.core.compress,
  nextpas.core.compress.bzip2,
  nextpas.core.sevenz.bcj2,
  nextpas.core.sevenz.aes,
  nextpas.core.sevenz.filters,
  nextpas.core.sevenz.lzma.decoder,
  nextpas.core.sevenz.lzma.encoder,
  nextpas.core.sevenz.lzma.ffi;

var
  GRequestedBackend: TSevenZLzmaBackend = szlbAuto;
  GPascalDecoder: ISevenZLzmaDecoder;
  GFfiDecoder: ISevenZLzmaDecoder;
  GPascalEncoder: ISevenZLzmaEncoder;

procedure SevenZSetLzmaBackend(ABackend: TSevenZLzmaBackend);
begin
  GRequestedBackend := ABackend;
end;

function SevenZRequestedBackend: TSevenZLzmaBackend;
begin
  Result := GRequestedBackend;
end;

function SevenZActiveBackend: TSevenZLzmaBackend;
begin
  case GRequestedBackend of
    szlbPurePascal: Result := szlbPurePascal;
    szlbFfi:
      if SevenZLzmaFfiAvailable then
        Result := szlbFfi
      else
        Result := szlbPurePascal;
  else
    if SevenZLzmaFfiAvailable then
      Result := szlbFfi
    else
      Result := szlbPurePascal;
  end;
end;

function SevenZAcquireDecoder: ISevenZLzmaDecoder;
begin
  case SevenZActiveBackend of
    szlbFfi:
      begin
        if GFfiDecoder = nil then
          GFfiDecoder := TSevenZLzmaDecoderFfi.Create;
        Result := GFfiDecoder;
      end;
  else
    begin
      if GPascalDecoder = nil then
        GPascalDecoder := TSevenZLzmaDecoderPascal.Create;
      Result := GPascalDecoder;
    end;
  end;
end;

function SevenZAcquireEncoder: ISevenZLzmaEncoder;
begin
  { 写端编码器当前仅纯 Pascal 实现；FFI 编码器后续接入同一契约 }
  if GPascalEncoder = nil then
    GPascalEncoder := TSevenZLzmaEncoderPascal.Create;
  Result := GPascalEncoder;
end;

function CopyOfBytes(const ASrc: TBytes): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(ASrc));
  if Length(ASrc) > 0 then
    Move(ASrc[0], Result[0], Length(ASrc));
end;

{ 无 SysUtils 的 UInt64 十进制转字符串；用于错误消息拼接——
  本工具链 CreateFmt 对 %d 传 UInt64 实参会渲染为 0 }
function UIntToDecStr(AVal: UInt64): string;
var
  LTmp: string;
begin
  Str(AVal, LTmp);
  Result := LTmp;
end;

function UInt64ToHex12(AVal: QWord): string;
const
  HD: array[0..15] of Char = '0123456789ABCDEF';
var
  LI: Integer;
begin
  SetLength(Result, 12);
  for LI := 11 downto 0 do
  begin
    Result[LI + 1] := HD[AVal and $F];
    AVal := AVal shr 4;
  end;
end;

{ Deflate 解码：7z 容器中的 Deflate 可能为 zlib 包裹或 raw 流（p7zip 用 -15），
  依次尝试 zlib 与 raw per-message 路径，AOutSize 用作输出上限以防炸弹。
  raw 路径的 inflate 实现对精确上限需 +1 探测字节（否则恰好填满时误判越界），
  这里以 LMax+1 探测后回校验真实上界。超限统一抛 ESevenZLimitError 供上层区分炸弹与损坏 }
{$PUSH}{$WARNINGS OFF}
function DeflateDecodeSevenZ(const AInput: TBytes; AOutSize: UInt64): TBytes;
var
  LMax, LRawMax: SizeUInt;
begin
  if SizeUInt(AOutSize) <> AOutSize then
    LMax := High(SizeUInt)
  else
    LMax := SizeUInt(AOutSize);
  if LMax = 0 then
    LMax := 1; { Raw 路径要求 >0，上层已校验空输出直接短路 }
  try
    Result := DeflateDecompressWithMaxOutputSize(AInput, LMax);
    Exit;
  except
    on E: ESevenZLimitError do raise;
    on E: EIOError do
      { zlib path failed — fall through to raw message path; not swallowed }
      ;
  end;
  if LMax < High(SizeUInt) then
    LRawMax := LMax + 1
  else
    LRawMax := LMax;
  try
    Result := RawDeflateMessageDecompress(AInput, LRawMax);
  except
    on E: ESevenZLimitError do raise;
    on E: EIOError do
      if Pos('exceeds limit', E.Message) > 0 then
        raise ESevenZLimitError.Create(E.Message)
      else
        raise EParseError.Create('deflate decode failed: ' + E.Message);
    on E: Exception do
      if Pos('exceeds limit', E.Message) > 0 then
        raise ESevenZLimitError.Create(E.Message)
      else
        raise EParseError.Create('deflate decode failed: ' + E.Message);
  end;
  if SizeUInt(Length(Result)) > LMax then
    raise ESevenZLimitError.Create('raw inflate: decompressed size exceeds limit');
end;

function SevenZDeflateDecodeForTest(const AInput: TBytes; AOutSize: UInt64): TBytes;
begin
  Result := DeflateDecodeSevenZ(AInput, AOutSize);
end;

function BZip2DecodeSevenZ(const AInput: TBytes; AOutSize: UInt64): TBytes;
var
  LMax: SizeUInt;
begin
  if SizeUInt(AOutSize) <> AOutSize then
    LMax := High(SizeUInt)
  else
    LMax := SizeUInt(AOutSize);
  if LMax = 0 then
  begin
    if Length(AInput) = 0 then
      Exit(nil);
    { non-empty bz2 must not decode to empty - let decompressor raise limit error }
    LMax := 0;
  end;
  try
    Result := BZip2DecompressWithMaxOutputSize(AInput, LMax);
  except
    on E: ESevenZLimitError do raise;
    on E: EIOError do
      if Pos('exceeds limit', E.Message) > 0 then
        raise ESevenZLimitError.Create(E.Message)
      else
        raise EParseError.Create('bzip2 decode failed: ' + E.Message);
    on E: Exception do
      if Pos('exceeds limit', E.Message) > 0 then
        raise ESevenZLimitError.Create(E.Message)
      else
        raise EParseError.Create('bzip2 decode failed: ' + E.Message);
  end;
end;

function SevenZBZip2DecodeForTest(const AInput: TBytes; AOutSize: UInt64): TBytes;
begin
  Result := BZip2DecodeSevenZ(AInput, AOutSize);
end;
{$POP}

{ 单个 coder 执行：AInputs 为其全部输入流 }

procedure ExecuteCoder(const ACoder: TSevenZCoderDesc; AOutSize: UInt64;
  const AInputs: array of TBytes; const APassword: string;
  out AOut: TBytes);
var
  LFilter: TSevenZFilter;
begin
  if SevenZFilterFromMethodId(ACoder.MethodId, LFilter) then
  begin
    if Length(AInputs) <> 1 then
      raise EParseError.Create('filter coder expects one input');
    AOut := CopyOfBytes(AInputs[0]);
    SevenZFilterConvert(AOut, LFilter, ACoder.Props, False);
  end
  else
  case ACoder.MethodId of
    SEVENZ_METHOD_COPY:
      begin
        if Length(AInputs) <> 1 then
          raise EParseError.Create('copy coder expects one input');
        AOut := CopyOfBytes(AInputs[0]);
      end;
    SEVENZ_METHOD_LZMA2:
      begin
        if Length(AInputs) <> 1 then
          raise EParseError.Create('lzma2 coder expects one input');
        AOut := SevenZAcquireDecoder.DecodeLzma2(ACoder.Props, AInputs[0],
          SizeUInt(AOutSize));
      end;
    SEVENZ_METHOD_LZMA1:
      begin
        if Length(AInputs) <> 1 then
          raise EParseError.Create('lzma coder expects one input');
        AOut := SevenZAcquireDecoder.DecodeLzma1(ACoder.Props, AInputs[0],
          SizeUInt(AOutSize));
      end;
    SEVENZ_METHOD_BCJ2:
      begin
        { 四流序：MAIN / CALL / JUMP / RC（与参考实现绑定顺序一致） }
        if Length(AInputs) <> 4 then
          raise EParseError.Create('bcj2 coder expects four inputs');
        SevenZBcj2Decode(AInputs[0], AInputs[1], AInputs[2], AInputs[3],
          AOutSize, AOut);
      end;
    SEVENZ_METHOD_AES256_CRC:
      begin
        if Length(AInputs) <> 1 then
          raise EParseError.Create('aes256 coder expects one input');
        SevenZAesDecryptProps(ACoder.Props, APassword, AInputs[0], AOut);
        { pack 流按 16 字节块取整加密：解密尾部可能多出填充块，
          按头部声明的逻辑尺寸截断；不足则由下方统一判损 }
        if SizeUInt(Length(AOut)) > AOutSize then
          SetLength(AOut, SizeInt(AOutSize));
      end;
    SEVENZ_METHOD_DEFLATE:
      begin
        if Length(AInputs) <> 1 then
          raise ESevenZError.Create('deflate coder expects one input');
        try
          AOut := DeflateDecodeSevenZ(AInputs[0], AOutSize);
        except
          on E: ESevenZLimitError do raise;
          on E: Exception do raise ESevenZError.Create('deflate decode failed: ' + E.Message);
        end;
      end;
    SEVENZ_METHOD_BZIP2:
      begin
        if Length(AInputs) <> 1 then
          raise ESevenZError.Create('bzip2 coder expects one input');
        try
          AOut := BZip2DecodeSevenZ(AInputs[0], AOutSize);
        except
          on E: ESevenZLimitError do raise;
          on E: Exception do raise ESevenZError.Create('bzip2 decode failed: ' + E.Message);
        end;
      end;
    SEVENZ_METHOD_PPMD:
      raise ESevenZError.Create('ppmd coder not supported (' + SevenZMethodName(QWord(ACoder.MethodId)) + ')');
  else
    raise ESevenZError.Create('unknown coder method ' + SevenZMethodName(QWord(ACoder.MethodId)));
  end;
  if SizeUInt(Length(AOut)) <> SizeUInt(AOutSize) then
    raise ESevenZError.Create(
      'coder produced ' + UIntToDecStr(Length(AOut)) +
      ' bytes, header declared ' + UIntToDecStr(AOutSize));
end;

{ folder 图执行：迭代解析直到主输出可用 }

function SevenZDecodeFolder(const AFolder: TSevenZFolder;
  const APackStreams: array of TBytes;
  const APassword: string): TBytes;
var
  LResolved: array of TBytes;
  LDone: array of Boolean;
  LCoderInBase: array of SizeInt;
  LTotalIn: SizeInt;
  LI: SizeInt;
  LJ: SizeInt;
  LInGlobal: SizeInt;
  LPackIdx: SizeInt;
  LSrcCoder: SizeInt;
  LProgress: Boolean;
  LAllIn: Boolean;
  LCoderInputs: array of TBytes;

  function PackIndexForIn(AIdx: SizeInt): SizeInt;
  var
    LK: SizeInt;
  begin
    Result := -1;
    for LK := 0 to High(AFolder.PackedInIndices) do
      if SizeInt(AFolder.PackedInIndices[LK]) = AIdx then
        Exit(LK);
  end;

  function BindSourceOut(AIdx: SizeInt): SizeInt;
  var
    LK: SizeInt;
  begin
    Result := -1;
    for LK := 0 to High(AFolder.BindPairs) do
      if SizeInt(AFolder.BindPairs[LK].InIndex) = AIdx then
        Exit(SizeInt(AFolder.BindPairs[LK].OutIndex));
  end;

begin
  Result := nil;
  LTotalIn := 0;
  SetLength(LCoderInBase, Length(AFolder.Coders));
  for LI := 0 to High(AFolder.Coders) do
  begin
    LCoderInBase[LI] := LTotalIn;
    Inc(LTotalIn, SizeInt(AFolder.Coders[LI].NumInStreams));
  end;
  if Length(APackStreams) <> Length(AFolder.PackedInIndices) then
    raise ESevenZError.Create('pack stream count mismatch');
  SetLength(LResolved, Length(AFolder.Coders));
  SetLength(LDone, Length(AFolder.Coders));
  FillChar(LDone[0], Length(LDone) * SizeOf(Boolean), 0);
  repeat
    LProgress := False;
    for LI := 0 to High(AFolder.Coders) do
    begin
      if LDone[LI] then
        Continue;
      SetLength(LCoderInputs, SizeInt(AFolder.Coders[LI].NumInStreams));
      LAllIn := True;
      for LJ := 0 to SizeInt(AFolder.Coders[LI].NumInStreams) - 1 do
      begin
        LInGlobal := LCoderInBase[LI] + LJ;
        LCoderInputs[LJ] := nil;
        LPackIdx := PackIndexForIn(LInGlobal);
        if LPackIdx >= 0 then
          LCoderInputs[LJ] := APackStreams[LPackIdx]
        else
        begin
          LSrcCoder := BindSourceOut(LInGlobal);
          if (LSrcCoder >= 0) and LDone[LSrcCoder] then
            LCoderInputs[LJ] := LResolved[LSrcCoder]
          else
          begin
            LAllIn := False;
            Break;
          end;
        end;
      end;
      if LAllIn then
      begin
        ExecuteCoder(AFolder.Coders[LI], AFolder.OutSizes[LI],
          LCoderInputs, APassword, LResolved[LI]);
        LDone[LI] := True;
        LProgress := True;
      end;
    end;
  until LDone[Afolder.MainOutIndex] or (not LProgress);
  if not LDone[Afolder.MainOutIndex] then
    raise ESevenZError.Create('folder decode chain unsatisfiable');
  Result := LResolved[Afolder.MainOutIndex];
end;
{$POP}
end.
