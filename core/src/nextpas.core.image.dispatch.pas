{**
 * nextpas.core.image.dispatch - 图像嗅探与统一调度（Probe+Factory 注册，复用 registry.factory / audio.codec.registry 范式）
 * L2，仅 L0-L1 + graphics.errors，零 RTL。门面 nextpas.core.image 纯转发此单元。
 * 注册式：ImageRegisterCodec 以 Probe+Decode 工厂注册取代硬编码 case，新增格式零侵入。
 *}
unit nextpas.core.image.dispatch;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.image.base;

type
  TImageProbeFunc = function(const AData: TBytes): Boolean;
  TImageDecodeFunc = function(const AData: TBytes; out AWidth, AHeight: Integer): TBytes;

procedure ImageRegisterCodec(AFormat: TImageFormat; AProbe: TImageProbeFunc;
  ADecode: TImageDecodeFunc; AHasAlpha: Boolean);
function DetectImageFormat(const AData: TBytes): TImageFormat;
function ImageDecode(const AData: TBytes; out AInfo: TImageInfo): TBytes;
function TryImageDecode(const AData: TBytes; out ABitmap: TBytes; out AInfo: TImageInfo): Boolean;

implementation

uses
  nextpas.core.errors,
  nextpas.core.graphics.errors,
  nextpas.core.image.png,
  nextpas.core.image.bmp,
  nextpas.core.image.jpeg,
  nextpas.core.image.webp;

type
  TCodecEntry = record
    Format: TImageFormat;
    Probe: TImageProbeFunc;
    Decode: TImageDecodeFunc;
    HasAlpha: Boolean;
  end;

var
  GCodecs: array of TCodecEntry;
  GInited: Boolean;

function PngProbe(const AData: TBytes): Boolean;
begin
  Result := (Length(AData) >= 8) and (AData[0] = $89) and (AData[1] = $50)
    and (AData[2] = $4E) and (AData[3] = $47);
end;

function JpegProbe(const AData: TBytes): Boolean;
begin
  Result := (Length(AData) >= 2) and (AData[0] = $FF) and (AData[1] = $D8);
end;

function BmpProbe(const AData: TBytes): Boolean;
begin
  Result := (Length(AData) >= 2) and (AData[0] = Ord('B')) and (AData[1] = Ord('M'));
end;

function WebPProbe(const AData: TBytes): Boolean;
begin
  Result := (Length(AData) >= 12) and (AData[0] = Ord('R')) and (AData[1] = Ord('I'))
    and (AData[2] = Ord('F')) and (AData[3] = Ord('F')) and (AData[8] = Ord('W'))
    and (AData[9] = Ord('E')) and (AData[10] = Ord('B')) and (AData[11] = Ord('P'));
end;

procedure AppendCodec(AFormat: TImageFormat; AProbe: TImageProbeFunc;
  ADecode: TImageDecodeFunc; AHasAlpha: Boolean);
var
  L: Integer;
begin
  L := Length(GCodecs);
  SetLength(GCodecs, L + 1);
  GCodecs[L].Format := AFormat;
  GCodecs[L].Probe := AProbe;
  GCodecs[L].Decode := ADecode;
  GCodecs[L].HasAlpha := AHasAlpha;
end;

procedure EnsureInited;
begin
  if GInited then Exit;
  GInited := True;
  SetLength(GCodecs, 0);
  AppendCodec(ifPng, @PngProbe, @nextpas.core.image.png.PngDecodeRgba, True);
  AppendCodec(ifJpeg, @JpegProbe, @nextpas.core.image.jpeg.JpegDecodeRgba, False);
  AppendCodec(ifBmp, @BmpProbe, @nextpas.core.image.bmp.BmpDecodeRgba, True);
  AppendCodec(ifWebP, @WebPProbe, @nextpas.core.image.webp.WebPDecodeRgba, True);
end;

procedure ImageRegisterCodec(AFormat: TImageFormat; AProbe: TImageProbeFunc;
  ADecode: TImageDecodeFunc; AHasAlpha: Boolean);
var
  I: Integer;
  L: Integer;
begin
  if not Assigned(AProbe) then
    raise EArgumentError.Create('image: probe is nil');
  if not Assigned(ADecode) then
    raise EArgumentError.Create('image: decode is nil');
  if AFormat = ifUnknown then
    raise EArgumentError.Create('image: cannot register ifUnknown');
  EnsureInited;
  for I := 0 to High(GCodecs) do
    if GCodecs[I].Format = AFormat then
      raise EArgumentError.Create('image: codec already registered');
  L := Length(GCodecs);
  SetLength(GCodecs, L + 1);
  if L > 0 then
    Move(GCodecs[0], GCodecs[1], L * SizeOf(TCodecEntry));
  GCodecs[0].Format := AFormat;
  GCodecs[0].Probe := AProbe;
  GCodecs[0].Decode := ADecode;
  GCodecs[0].HasAlpha := AHasAlpha;
end;

function DetectImageFormat(const AData: TBytes): TImageFormat;
var
  I: Integer;
begin
  Result := ifUnknown;
  if Length(AData) < 2 then Exit;
  EnsureInited;
  for I := 0 to High(GCodecs) do
    if Assigned(GCodecs[I].Probe) and GCodecs[I].Probe(AData) then
      Exit(GCodecs[I].Format);
end;

function ImageDecode(const AData: TBytes; out AInfo: TImageInfo): TBytes;
var
  W, H: Integer;
  Fmt: TImageFormat;
  I: Integer;
  Entry: TCodecEntry;
  Found: Boolean;
begin
  FillChar(AInfo, SizeOf(AInfo), 0);
  Fmt := DetectImageFormat(AData);
  AInfo.Format := Fmt;
  if Fmt = ifUnknown then
    raise EImageDecodeError.Create('image: unknown format (need PNG/JPEG/WebP/BMP)');
  EnsureInited;
  Found := False;
  for I := 0 to High(GCodecs) do
    if GCodecs[I].Format = Fmt then
    begin
      Entry := GCodecs[I];
      Found := True;
      Break;
    end;
  if not Found then
    raise EImageDecodeError.Create('image: unknown format (need PNG/JPEG/WebP/BMP)');
  try
    Result := Entry.Decode(AData, W, H);
    AInfo.Width := W;
    AInfo.Height := H;
    AInfo.HasAlpha := Entry.HasAlpha;
  except
    on E: EImageDecodeError do raise;
    on E: ENotImplementedError do raise EImageDecodeError.Create('image: ' + E.Message);
    on E: EArgumentError do raise EImageDecodeError.Create('image: ' + E.Message);
    on E: EIOError do raise EImageDecodeError.Create('image: ' + E.Message);
  end;
end;

function TryImageDecode(const AData: TBytes; out ABitmap: TBytes; out AInfo: TImageInfo): Boolean;
begin
  ABitmap := nil;
  FillChar(AInfo, SizeOf(AInfo), 0);
  try
    ABitmap := ImageDecode(AData, AInfo);
    Result := True;
  except
    on E: EImageDecodeError do Result := False;
    on E: ENotImplementedError do Result := False;
    on E: Exception do
      Result := False;
  end;
  if not Result then
  begin
    ABitmap := nil;
    FillChar(AInfo, SizeOf(AInfo), 0);
  end;
end;

end.
