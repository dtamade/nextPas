{**
 * nextpas.core.image.dispatch - 图像嗅探与统一调度（Probe+Factory 注册）
 * L2，仅 L0-L1 + graphics.errors + sync，零 RTL。门面 nextpas.core.image 纯转发此单元。
 * 注册式：ImageRegisterCodec 以 Probe+Decode 工厂注册取代硬编码 case，新增格式零侵入；
 *   各格式单元（png/bmp/jpeg/webp）通过 initialization 自注册，dispatch 不硬编码 uses。
 * 线程安全：GCodecs 下 TRecursiveMutex 保护；Detect/ImageDecode 采用 Copy-on-snapshot
 *   无锁嗅探/解码，并发注册与解码不竞态；ImageRegisterCodec 重复注册抛 EArgumentError。
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
  nextpas.core.sync.mutex;

type
  TCodecEntry = record
    Format: TImageFormat;
    Probe: TImageProbeFunc;
    Decode: TImageDecodeFunc;
    HasAlpha: Boolean;
  end;
  TCodecArray = array of TCodecEntry;

var
  GCodecs: TCodecArray;
  GLock: TRecursiveMutex;
  GInited: Boolean;

procedure EnsureInited;
begin
  if GInited then Exit;
  // GLock 在 initialization 已创建，此处仅需保护 GInited 翻转
  GLock.Acquire;
  try
    if GInited then Exit;
    GInited := True;
  finally
    GLock.Release;
  end;
end;

function SnapshotCodecs: TCodecArray;
begin
  EnsureInited;
  GLock.Acquire;
  try
    Result := Copy(GCodecs);
  finally
    GLock.Release;
  end;
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
  GLock.Acquire;
  try
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
  finally
    GLock.Release;
  end;
end;

function DetectImageFormat(const AData: TBytes): TImageFormat;
var
  Codecs: TCodecArray;
  I: Integer;
begin
  Result := ifUnknown;
  if Length(AData) < 2 then Exit;
  Codecs := SnapshotCodecs;
  for I := 0 to High(Codecs) do
    if Assigned(Codecs[I].Probe) and Codecs[I].Probe(AData) then
      Exit(Codecs[I].Format);
end;

function ImageDecode(const AData: TBytes; out AInfo: TImageInfo): TBytes;
var
  W, H: Integer;
  Fmt: TImageFormat;
  I: Integer;
  Codecs: TCodecArray;
  Entry: TCodecEntry;
  Found: Boolean;
begin
  FillChar(AInfo, SizeOf(AInfo), 0);
  Fmt := DetectImageFormat(AData);
  AInfo.Format := Fmt;
  if Fmt = ifUnknown then
    raise EImageDecodeError.Create('image: unknown format (need PNG/JPEG/WebP/BMP)');
  Codecs := SnapshotCodecs;
  Found := False;
  for I := 0 to High(Codecs) do
    if Codecs[I].Format = Fmt then
    begin
      Entry := Codecs[I];
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

initialization
  GLock := TRecursiveMutex.Create;
  GInited := False;

finalization
  if Assigned(GLock) then
    GLock.Free;

end.
