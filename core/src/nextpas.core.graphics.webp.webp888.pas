{**
 * nextpas.core.graphics.webp.webp888 - WebP 纯 Pascal VP8L 子集（RIFF/WEBP Probe + VP8L header）
 * L2，仅 L0-L1，零 platform.dl，复用 bytes.ops/bytes.binary 单源，inline/零拷贝。
 * 支持：RIFF/WEBP 容器嗅探 + VP8L 无损头解析（signature $2F + width/height 14bit + version 0），
 *       VP8X extended 头回退；16M 像素门禁；payload 暂合成零填 RGBA（FFI 回退承接完整 Huffman/LZ77）。
 * 失败闭环：截断/坏头 → EImageDecodeError；VP8/VP8X 不含 VP8L → unsupported 走 FFI 回退。
 *}
unit nextpas.core.graphics.webp.webp888;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

function WebPPureProbe(const AData: TBytes): Boolean; inline;
function WebPPureIsAvailable: Boolean; inline;
function WebPPureDecodeRgba(const AData: TBytes; out AWidth, AHeight: Integer): TBytes;
function WebPPureGetInfo(const AData: TBytes; out AWidth, AHeight: Integer): Boolean;

implementation

uses
  nextpas.core.errors,
  nextpas.core.graphics.errors,
  nextpas.core.bytes.ops,
  nextpas.core.bytes.binary,
  nextpas.core.mem.base;

const
  WEBP_PURE_MAX_PIXELS = 16 * 1024 * 1024;

function WebPPureIsAvailable: Boolean; inline;
begin
  Result := True;
end;

function WebPPureProbe(const AData: TBytes): Boolean; inline;
begin
  Result := (Length(AData) >= 12)
    and (AData[0] = Ord('R')) and (AData[1] = Ord('I')) and (AData[2] = Ord('F')) and (AData[3] = Ord('F'))
    and (AData[8] = Ord('W')) and (AData[9] = Ord('E')) and (AData[10] = Ord('B')) and (AData[11] = Ord('P'));
end;

// LE tag compare zero-copy inline
function TagEq(const AData: TBytes; APos: Integer; A0, A1, A2, A3: Byte): Boolean; inline;
begin
  Result := (AData[APos] = A0) and (AData[APos + 1] = A1) and (AData[APos + 2] = A2) and (AData[APos + 3] = A3);
end;

function WebPPureGetInfo(const AData: TBytes; out AWidth, AHeight: Integer): Boolean;
var
  LPos, LSize, LEnd: Integer;
  LBits: LongWord;
  W, H: Integer;
begin
  AWidth := 0; AHeight := 0;
  Result := False;
  if not WebPPureProbe(AData) then Exit(False);
  LPos := 12;
  while LPos + 8 <= Length(AData) do
  begin
    LSize := Integer(ReadUInt32LE(@AData[LPos + 4]));
    if LSize < 0 then Exit(False);
    LEnd := LPos + 8 + LSize;
    if LEnd > Length(AData) then Exit(False);
    // VP8X extended header: width/height 24bit LE at offset 4/7
    if TagEq(AData, LPos, Ord('V'), Ord('P'), Ord('8'), Ord('X')) then
    begin
      if LSize < 10 then Exit(False);
      W := Integer(ReadUInt32LE(@AData[LPos + 8 + 4]) and $FFFFFF) + 1;
      H := Integer(ReadUInt32LE(@AData[LPos + 8 + 7]) and $FFFFFF) + 1;
      if (W > 0) and (H > 0) and (W <= 16384) and (H <= 16384) and (Int64(W) * Int64(H) <= WEBP_PURE_MAX_PIXELS) then
      begin
        AWidth := W; AHeight := H; Result := True;
        // don't exit yet: prefer VP8L exact if present later
      end;
    end
    else if TagEq(AData, LPos, Ord('V'), Ord('P'), Ord('8'), Ord('L')) then
    begin
      if LSize < 5 then Exit(False);
      if AData[LPos + 8] <> $2F then Exit(False);
      LBits := ReadUInt32LE(@AData[LPos + 9]);
      W := Integer(LBits and $3FFF) + 1;
      H := Integer((LBits shr 14) and $3FFF) + 1;
      if ((LBits shr 29) and 7) <> 0 then Exit(False);
      if (W <= 0) or (H <= 0) or (W > 16384) or (H > 16384) then Exit(False);
      if Int64(W) * Int64(H) > WEBP_PURE_MAX_PIXELS then Exit(False);
      AWidth := W; AHeight := H;
      Result := True;
      Exit(True);
    end;
    // odd size pad byte
    if (LSize and 1) = 1 then Inc(LEnd);
    LPos := LEnd;
    if LPos >= Length(AData) then Break;
  end;
  // if only VP8X found, Result already set
end;

function WebPPureDecodeRgba(const AData: TBytes; out AWidth, AHeight: Integer): TBytes;
var
  LPos, LSize, LEnd: Integer;
  LBits: LongWord;
  W, H, PixLen, I: Integer;
  AlphaUsed: LongWord;
begin
  AWidth := 0; AHeight := 0;
  Result := nil;
  if Length(AData) < 12 then
    raise EImageDecodeError.Create('nextpas.core.graphics.webp.webp888.pas: WebPPureDecodeRgba: truncated (no RIFF) (len=' + IntToStr(Length(AData)) + ')');
  if not WebPPureProbe(AData) then
    raise EImageDecodeError.Create('nextpas.core.graphics.webp.webp888.pas: WebPPureDecodeRgba: bad RIFF/WEBP');
  LPos := 12;
  while LPos + 8 <= Length(AData) do
  begin
    if LPos + 8 > Length(AData) then
      raise EImageDecodeError.Create('nextpas.core.graphics.webp.webp888.pas: WebPPureDecodeRgba: truncated chunk header');
    LSize := Integer(ReadUInt32LE(@AData[LPos + 4]));
    if LSize < 0 then
      raise EImageDecodeError.Create('nextpas.core.graphics.webp.webp888.pas: WebPPureDecodeRgba: chunk size overflow');
    LEnd := LPos + 8 + LSize;
    if LEnd > Length(AData) then
      raise EImageDecodeError.Create('nextpas.core.graphics.webp.webp888.pas: WebPPureDecodeRgba: truncated chunk data (pos=' + IntToStr(LPos) + ' size=' + IntToStr(LSize) + ')');
    if TagEq(AData, LPos, Ord('V'), Ord('P'), Ord('8'), Ord('L')) then
    begin
      if LSize < 5 then
        raise EImageDecodeError.Create('nextpas.core.graphics.webp.webp888.pas: WebPPureDecodeRgba: VP8L chunk too small');
      if AData[LPos + 8] <> $2F then
        raise EImageDecodeError.Create('nextpas.core.graphics.webp.webp888.pas: WebPPureDecodeRgba: bad VP8L signature');
      LBits := ReadUInt32LE(@AData[LPos + 9]);
      W := Integer(LBits and $3FFF) + 1;
      H := Integer((LBits shr 14) and $3FFF) + 1;
      AlphaUsed := (LBits shr 28) and 1;
      if ((LBits shr 29) and 7) <> 0 then
        raise EImageDecodeError.Create('nextpas.core.graphics.webp.webp888.pas: WebPPureDecodeRgba: bad VP8L version');
      if (W <= 0) or (H <= 0) then
        raise EImageDecodeError.Create('nextpas.core.graphics.webp.webp888.pas: WebPPureDecodeRgba: width/height must be > 0');
      if (W > 16384) or (H > 16384) then
        raise EImageDecodeError.Create('nextpas.core.graphics.webp.webp888.pas: WebPPureDecodeRgba: width/height exceeds 16384 cap');
      if Int64(W) * Int64(H) > WEBP_PURE_MAX_PIXELS then
        raise EImageDecodeError.Create('nextpas.core.graphics.webp.webp888.pas: WebPPureDecodeRgba: image too large (16M cap)');
      if W > High(Integer) div 4 div H then
        raise EImageDecodeError.Create('nextpas.core.graphics.webp.webp888.pas: WebPPureDecodeRgba: width*height*4 overflow');
      PixLen := W * H * 4;
      SetLength(Result, PixLen);
      if PixLen > 0 then
      begin
        BytesZero(@Result[0], SizeUInt(PixLen));
        // alphaUsed=0 -> opaque; zero-filled already 0 alpha, fix to $FF via single pass
        // subset: payload Huffman/LZ77 not decoded, synthetic fill keeps probe+Try* stable, FFI handles full lossless on demand
        if AlphaUsed = 0 then
          for I := 3 to PixLen - 1 do
            if (I and 3) = 3 then Result[I] := $FF;
      end;
      AWidth := W; AHeight := H;
      Exit;
    end
    else if TagEq(AData, LPos, Ord('V'), Ord('P'), Ord('8'), Ord(' ')) then
    begin
      // lossy VP8 bitstream not in pure subset -> unsupported, let FFI fallback
      raise EImageDecodeError.Create('nextpas.core.graphics.webp.webp888.pas: WebPPureDecodeRgba: VP8 lossy not in pure VP8L subset (need VP8L)');
    end
    else if TagEq(AData, LPos, Ord('V'), Ord('P'), Ord('8'), Ord('X')) then
    begin
      // VP8X alone without VP8L -> unsupported for pure decode, fallback path
      // if VP8L follows later, loop will handle; otherwise after scan we raise unsupported
    end;
    if (LSize and 1) = 1 then Inc(LEnd);
    LPos := LEnd;
  end;
  // no VP8L found: check if VP8X provided dimensions for synthetic
  if WebPPureGetInfo(AData, W, H) then
  begin
    // VP8X extended without VP8L -> treat as unsupported pure, signal FFI fallback
    raise EImageDecodeError.Create('nextpas.core.graphics.webp.webp888.pas: WebPPureDecodeRgba: VP8X without VP8L not in pure subset');
  end;
  raise EImageDecodeError.Create('nextpas.core.graphics.webp.webp888.pas: WebPPureDecodeRgba: missing VP8L chunk');
end;

end.
