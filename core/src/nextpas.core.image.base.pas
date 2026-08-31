{**
 * nextpas.core.image.base - TBitmap 容器（COW，TBytes 持有，Stride 64B 对齐）+ 图像格式
 * L2，仅 L0-L1，零 RTL。
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
  TImageFormat = (ifUnknown, ifPng, ifJpeg, ifWebP, ifBmp, ifGif);

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
    function GetPixelPtr(X, Y: Integer): PByte; inline;
    function RowPtr(Y: Integer): PByte; inline;
    function ToCompact: TBytes;
    procedure Premultiply;
    procedure Unpremultiply;
    function Clone: TBitmap;
    procedure EnsureUnique; inline;
    property Width: Integer read FWidth;
    property Height: Integer read FHeight;
    property Format: TBitmapFormat read FFormat;
    property IsEmptyProp: Boolean read GetIsEmpty;
  end;

function AlignUp64(AValue: Integer): Integer; inline;

implementation

uses
  nextpas.core.mem.base;

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
begin
  if Length(FPixels) > 0 then SetLength(FPixels, Length(FPixels));
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
  for Y := 0 to AHeight - 1 do
  begin
    Dst := @Result.FPixels[Y * Result.FStride];
    Move(AData[Y * RowLen], Dst^, RowLen);
  end;
end;

procedure TBitmap.Premultiply;
var
  Y, X: Integer;
  P: PByte;
  A: Byte;
begin
  if FFormat = bfGray8 then Exit;
  if GetIsEmpty or (Length(FPixels) = 0) then Exit;
  EnsureUnique;
  for Y := 0 to FHeight - 1 do
  begin
    P := RowPtr(Y);
    for X := 0 to FWidth - 1 do
    begin
      A := P[3];
      if A = 0 then begin P[0]:=0; P[1]:=0; P[2]:=0; end
      else if A <> 255 then
      begin
        P[0] := Byte((P[0] * A) div 255);
        P[1] := Byte((P[1] * A) div 255);
        P[2] := Byte((P[2] * A) div 255);
      end;
      Inc(P, 4);
    end;
  end;
end;

function TBitmap.Clone: TBitmap;
begin
  Result := Self;
  if Length(Result.FPixels) > 0 then SetLength(Result.FPixels, Length(Result.FPixels));
end;

procedure TBitmap.Unpremultiply;
var
  Y, X: Integer;
  P: PByte;
  A: Byte;
begin
  if FFormat = bfGray8 then Exit;
  if GetIsEmpty or (Length(FPixels) = 0) then Exit;
  EnsureUnique;
  for Y := 0 to FHeight - 1 do
  begin
    P := RowPtr(Y);
    for X := 0 to FWidth - 1 do
    begin
      A := P[3];
      if (A <> 0) and (A <> 255) then
      begin
        P[0] := Byte((P[0] * 255) div A);
        P[1] := Byte((P[1] * 255) div A);
        P[2] := Byte((P[2] * 255) div A);
      end;
      Inc(P, 4);
    end;
  end;
end;

end.
