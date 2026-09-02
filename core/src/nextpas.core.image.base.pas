{**
 * nextpas.core.image.base - TBitmap 容器（COW，TBytes 持有，Stride 64B 对齐）+ 图像格式
 * L1 graphics.base 零依赖（仅 base/errors + mem.base.AlignUp）；AlignUp 复用 mem.base。
 * 封装：FWidth/FHeight/FStride/FPixels 私有，Stride 64B 对齐；ToCompact 去 pad 紧凑拷贝。
 * COW：Clone 浅拷贝共享 TBytes，EnsureUnique 写前 SetLength 深拷贝；GetPixelPtr/RowPtr
 *   为可写路径（内部触发 EnsureUnique），ConstPixelPtr/ConstRowPtr 为只读路径（不触发 COW）。
 * 线程：TBitmap 非线程安全；EnsureUnique 的 RC 读取为非原子 over-copy safe，
 *   并发 Clone+写入需外部同步，image.dispatch 的 mutex 不覆盖位图数据。
 * 指针生命周期：RowPtr/GetPixelPtr/Const* 返回裸 PByte 仅在下一次可写调用前有效
 *   （Clear/EnsureUnique/重分配即悬垂）；禁止跨调用缓存，需即用即弃。
 * 写循环应外提 EnsureUnique 一次后复用 UnsafeMutableRowPtr + Stride 偏移，
 *   禁止通过 Const* 野指针写入（COW 隔离绕过）。
 * 只读约束：Const* 返回只读视图，禁止写入；需紧凑数据用 ToCompact。
 * L2，仅 L0-L1，零 RTL；Premultiply 复用 simd.raster 批量接口。
 *}
unit nextpas.core.image.base;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  nextpas.core.base,
  nextpas.core.errors;

type
  TBitmapFormat = (bfRGBA, bfBGRA, bfGray8);
  TImageFormat = (ifUnknown, ifPng, ifJpeg, ifWebP, ifBmp, ifGif, ifQoi);

  TImageInfo = record
    Width, Height: Integer;
    Format: TImageFormat;
    HasAlpha: Boolean;
  end;

  TBitmap = record
  private
    FWidth, FHeight, FStride: Integer;
    FFormat: TBitmapFormat;
    FPixels: TBytes;
    function GetIsEmpty: Boolean; inline;
  public
    class function Create(AWidth, AHeight: Integer; AFormat: TBitmapFormat = bfRGBA): TBitmap; static;
    class function Empty: TBitmap; static;
    class function FromCompact(const AData: TBytes; AWidth, AHeight: Integer; AFormat: TBitmapFormat = bfRGBA): TBitmap; static;
    procedure Clear;
    function IsEmpty: Boolean; inline;
    function BytePerPixel: Integer; inline;
    // 可写路径：触发 EnsureUnique COW，返回指针仅至下一次写操作前有效，禁止跨调用缓存
    function GetPixelPtr(X, Y: Integer): PByte;
    // 只读路径：不触发 COW，返回只读视图禁止写入；批量读用 ConstRowPtr
    function ConstPixelPtr(X, Y: Integer): PByte; inline;
    // 可写行指针：触发 EnsureUnique；扫描行批量写应外提 EnsureUnique 后改用 UnsafeMutableRowPtr
    function RowPtr(Y: Integer): PByte;
    // 只读行指针：不触发 COW，禁止写入；配合 Stride 偏移批量访问，生命周期即用即弃
    function ConstRowPtr(Y: Integer): PByte; inline;
    // 可写行指针（不触发 COW）：仅在已 EnsureUnique 后调用，供批量写复用，避免 Const* 语义模糊
    function UnsafeMutableRowPtr(Y: Integer): PByte; inline;
    // 去 pad 紧凑拷贝（Width*Bpp 紧凑），避免绕过 ToCompact 直接野指针写
    function ToCompact: TBytes;
    procedure Premultiply;
    procedure Unpremultiply;
    function Clone: TBitmap;
    // 写前去重：共享时 SetLength 深拷贝；扫描行批量写应外提一次避免每行校验；非线程安全需外部同步
    procedure EnsureUnique; inline;
    property Width: Integer read FWidth;
    property Height: Integer read FHeight;
    property Stride: Integer read FStride;
    property Format: TBitmapFormat read FFormat;
    property IsEmptyProp: Boolean read GetIsEmpty;
  end;

function AlignUp64(AValue: Integer): Integer; inline;

implementation

uses
  nextpas.core.mem.base,
  nextpas.core.simd.raster;

function AlignUp64(AValue: Integer): Integer;
begin
  if AValue <= 0 then Exit(0);
  Result := Integer(AlignUp(SizeUInt(AValue), 64));
  if Result = 0 then
    raise EArgumentError.Create('nextpas.core.image.base.pas: AlignUp64 overflow');
end;

class function TBitmap.Create(AWidth, AHeight: Integer; AFormat: TBitmapFormat): TBitmap;
var
  Bpp: Integer;
  RawStride: Integer;
begin
  if (AWidth <= 0) or (AHeight <= 0) then
    raise EArgumentError.Create('nextpas.core.image.base.pas: TBitmap width/height must be > 0');
  if (AWidth > 16384) or (AHeight > 16384) then
    raise EArgumentError.Create('nextpas.core.image.base.pas: TBitmap width/height exceeds 16384 cap');
  Result.FWidth := AWidth;
  Result.FHeight := AHeight;
  Result.FFormat := AFormat;
  case AFormat of
    bfRGBA, bfBGRA: Bpp := 4;
    bfGray8: Bpp := 1;
  end;
  if AWidth > High(Integer) div Bpp then
    raise EArgumentError.Create('nextpas.core.image.base.pas: TBitmap width*bpp overflow');
  RawStride := AWidth * Bpp;
  try
    Result.FStride := AlignUp64(RawStride);
  except
    on E: EArgumentError do
      raise EArgumentError.Create('nextpas.core.image.base.pas: TBitmap Stride AlignUp overflow: ' + E.Message);
  end;
  if Result.FStride = 0 then
    raise EArgumentError.Create('nextpas.core.image.base.pas: TBitmap Stride AlignUp overflow');
  if (Result.FStride > 0) and (AHeight > High(Integer) div Result.FStride) then
    raise EArgumentError.Create('nextpas.core.image.base.pas: TBitmap Stride*Height overflow');
  SetLength(Result.FPixels, Result.FStride * AHeight);
end;

class function TBitmap.Empty: TBitmap;
begin
  Result.FWidth := 0; Result.FHeight := 0; Result.FStride := 0;
  Result.FFormat := bfRGBA; Result.FPixels := nil;
end;

procedure TBitmap.Clear;
begin
  FWidth := 0; FHeight := 0; FStride := 0; FPixels := nil;
end;

function TBitmap.GetIsEmpty: Boolean;
begin
  Result := (FWidth <= 0) or (FHeight <= 0) or (Length(FPixels) = 0);
end;

procedure TBitmap.EnsureUnique;
var
  P: PByte;
  RC: SizeInt;
  PRC: ^SizeInt;
begin
  if Length(FPixels) = 0 then Exit;
  // FPC TBytes header = refcount+high before data.
  // Over-copy safe but not thread-safe: RC read is non-atomic; concurrent Clone+EnsureUnique
  // requires external synchronization. image.dispatch mutex does not cover bitmap data.
  // Single-thread correctness: RC<>1 triggers SetLength deep copy; literal RC<0 also copies.
  P := @FPixels[0];
  PRC := Pointer(NativeUInt(P) - SizeOf(SizeInt) * 2);
  RC := PRC^;
  if RC <> 1 then
    SetLength(FPixels, Length(FPixels));
end;

function TBitmap.IsEmpty: Boolean;
begin
  Result := GetIsEmpty;
end;

function TBitmap.BytePerPixel: Integer;
begin
  case FFormat of
    bfGray8: Result := 1;
  else Result := 4;
  end;
end;

function TBitmap.GetPixelPtr(X, Y: Integer): PByte;
var
  Off, Bpp: Integer;
begin
  if GetIsEmpty or (Length(FPixels) = 0) or (FWidth <= 0) or (FHeight <= 0) then
    raise EArgumentError.Create('nextpas.core.image.base.pas: GetPixelPtr on empty bitmap');
  if (X < 0) or (X >= FWidth) or (Y < 0) or (Y >= FHeight) then
    raise EArgumentError.Create('nextpas.core.image.base.pas: GetPixelPtr out of bounds');
  Bpp := BytePerPixel;
  if Y > High(Integer) div FStride then
    raise EArgumentError.Create('nextpas.core.image.base.pas: GetPixelPtr Y*Stride overflow');
  Off := Y * FStride + X * Bpp;
  if (Off < 0) or (Off + Bpp > Length(FPixels)) then
    raise EArgumentError.Create('nextpas.core.image.base.pas: GetPixelPtr offset out of bounds');
  EnsureUnique;
  Result := @FPixels[Off];
end;

function TBitmap.ConstPixelPtr(X, Y: Integer): PByte;
var
  Off, Bpp: Integer;
begin
  if GetIsEmpty or (Length(FPixels) = 0) or (FWidth <= 0) or (FHeight <= 0) then
    raise EArgumentError.Create('nextpas.core.image.base.pas: ConstPixelPtr on empty bitmap');
  if (X < 0) or (X >= FWidth) or (Y < 0) or (Y >= FHeight) then
    raise EArgumentError.Create('nextpas.core.image.base.pas: ConstPixelPtr out of bounds');
  Bpp := BytePerPixel;
  if Y > High(Integer) div FStride then
    raise EArgumentError.Create('nextpas.core.image.base.pas: ConstPixelPtr Y*Stride overflow');
  Off := Y * FStride + X * Bpp;
  if (Off < 0) or (Off + Bpp > Length(FPixels)) then
    raise EArgumentError.Create('nextpas.core.image.base.pas: ConstPixelPtr offset out of bounds');
  Result := @FPixels[Off];
end;

function TBitmap.RowPtr(Y: Integer): PByte;
var
  Off, RowBytes: Integer;
begin
  if GetIsEmpty or (Length(FPixels) = 0) or (FWidth <= 0) or (FHeight <= 0) then
    raise EArgumentError.Create('nextpas.core.image.base.pas: RowPtr on empty bitmap');
  if (Y < 0) or (Y >= FHeight) then
    raise EArgumentError.Create('nextpas.core.image.base.pas: RowPtr out of bounds');
  if Y > High(Integer) div FStride then
    raise EArgumentError.Create('nextpas.core.image.base.pas: RowPtr Y*Stride overflow');
  Off := Y * FStride;
  RowBytes := FWidth * BytePerPixel;
  if (Off < 0) or (Off + RowBytes > Length(FPixels)) then
    raise EArgumentError.Create('nextpas.core.image.base.pas: RowPtr offset out of bounds');
  EnsureUnique;
  Result := @FPixels[Off];
end;

function TBitmap.ConstRowPtr(Y: Integer): PByte;
var
  Off, RowBytes: Integer;
begin
  if GetIsEmpty or (Length(FPixels) = 0) or (FWidth <= 0) or (FHeight <= 0) then
    raise EArgumentError.Create('nextpas.core.image.base.pas: ConstRowPtr on empty bitmap');
  if (Y < 0) or (Y >= FHeight) then
    raise EArgumentError.Create('nextpas.core.image.base.pas: ConstRowPtr out of bounds');
  if Y > High(Integer) div FStride then
    raise EArgumentError.Create('nextpas.core.image.base.pas: ConstRowPtr Y*Stride overflow');
  Off := Y * FStride;
  RowBytes := FWidth * BytePerPixel;
  if (Off < 0) or (Off + RowBytes > Length(FPixels)) then
    raise EArgumentError.Create('nextpas.core.image.base.pas: ConstRowPtr offset out of bounds');
  Result := @FPixels[Off];
end;

function TBitmap.UnsafeMutableRowPtr(Y: Integer): PByte;
var
  Off, RowBytes: Integer;
begin
  if GetIsEmpty or (Length(FPixels) = 0) or (FWidth <= 0) or (FHeight <= 0) then
    raise EArgumentError.Create('nextpas.core.image.base.pas: UnsafeMutableRowPtr on empty bitmap');
  if (Y < 0) or (Y >= FHeight) then
    raise EArgumentError.Create('nextpas.core.image.base.pas: UnsafeMutableRowPtr out of bounds');
  if Y > High(Integer) div FStride then
    raise EArgumentError.Create('nextpas.core.image.base.pas: UnsafeMutableRowPtr Y*Stride overflow');
  Off := Y * FStride;
  RowBytes := FWidth * BytePerPixel;
  if (Off < 0) or (Off + RowBytes > Length(FPixels)) then
    raise EArgumentError.Create('nextpas.core.image.base.pas: UnsafeMutableRowPtr offset out of bounds');
  Result := @FPixels[Off];
end;

function TBitmap.ToCompact: TBytes;
var
  ByRow, Y: Integer;
  Src: PByte;
begin
  Result := nil;
  if GetIsEmpty or (Length(FPixels) = 0) or (FWidth <= 0) or (FHeight <= 0) then Exit(nil);
  ByRow := FWidth * BytePerPixel;
  if ByRow <= 0 then Exit(nil);
  if FHeight > High(Integer) div ByRow then
    raise EArgumentError.Create('nextpas.core.image.base.pas: ToCompact overflow');
  SetLength(Result, ByRow * FHeight);
  if FStride = ByRow then
    Move(FPixels[0], Result[0], NativeUInt(ByRow) * NativeUInt(FHeight))
  else
    for Y := 0 to FHeight - 1 do
    begin
      Src := @FPixels[Y * FStride];
      Move(Src^, Result[Y * ByRow], ByRow);
    end;
end;

class function TBitmap.FromCompact(const AData: TBytes; AWidth, AHeight: Integer; AFormat: TBitmapFormat): TBitmap;
var
  Bpp, RowLen, Y: Integer;
  Dst: PByte;
begin
  if (AWidth <= 0) or (AHeight <= 0) then
    raise EArgumentError.Create('nextpas.core.image.base.pas: FromCompact width/height must be > 0');
  if (AWidth > 16384) or (AHeight > 16384) then
    raise EArgumentError.Create('nextpas.core.image.base.pas: FromCompact width/height exceeds 16384 cap');
  case AFormat of
    bfRGBA, bfBGRA: Bpp := 4;
    bfGray8: Bpp := 1;
  end;
  if AWidth > High(Integer) div Bpp then
    raise EArgumentError.Create('nextpas.core.image.base.pas: FromCompact width*bpp overflow');
  RowLen := AWidth * Bpp;
  if RowLen <= 0 then
    raise EArgumentError.Create('nextpas.core.image.base.pas: FromCompact RowLen overflow');
  if AHeight > High(Integer) div RowLen then
    raise EArgumentError.Create('nextpas.core.image.base.pas: FromCompact compact size overflow');
  if Length(AData) <> RowLen * AHeight then
    raise EArgumentError.Create('nextpas.core.image.base.pas: FromCompact data length mismatch');
  Result := TBitmap.Create(AWidth, AHeight, AFormat);
  if Result.FStride = RowLen then
    Move(AData[0], Result.FPixels[0], NativeUInt(RowLen) * NativeUInt(AHeight))
  else
    for Y := 0 to AHeight - 1 do
    begin
      Dst := @Result.FPixels[Y * Result.FStride];
      Move(AData[Y * RowLen], Dst^, RowLen);
    end;
end;

procedure TBitmap.Premultiply;
var
  Y: Integer;
  Row: PByte;
begin
  if FFormat = bfGray8 then Exit;
  if GetIsEmpty or (Length(FPixels) = 0) or (FWidth <= 0) or (FHeight <= 0) then Exit;
  EnsureUnique;
  for Y := 0 to FHeight - 1 do
  begin
    Row := @FPixels[Y * FStride];
    RasterPremultiply(Row, FWidth);
  end;
end;

function TBitmap.Clone: TBitmap;
begin
  Result := Self;
  // COW share: O(1) shallow copy, deep copy deferred to EnsureUnique on write
end;

procedure TBitmap.Unpremultiply;
var
  Y: Integer;
  Row: PByte;
begin
  if FFormat = bfGray8 then Exit;
  if GetIsEmpty or (Length(FPixels) = 0) or (FWidth <= 0) or (FHeight <= 0) then Exit;
  EnsureUnique;
  for Y := 0 to FHeight - 1 do
  begin
    Row := @FPixels[Y * FStride];
    RasterUnpremultiply(Row, FWidth);
  end;
end;

end.
