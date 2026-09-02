{ nextpas.core.graphics.effect.graph - 滤镜图 DSL + Bake (boxblur/serialize 分离) }
unit nextpas.core.graphics.effect.graph;

{$I nextpas.core.settings.inc}
{$modeswitch advancedrecords}
{$POINTERMATH ON}

interface

uses
  nextpas.core.base,
  nextpas.core.graphics.base,
  nextpas.core.graphics.effect.graph.base,
  nextpas.core.image.base;

type
  TEffectKind = nextpas.core.graphics.effect.graph.base.TEffectKind;
  TEffectNode = nextpas.core.graphics.effect.graph.base.TEffectNode;
  TEffectNodeArray = nextpas.core.graphics.effect.graph.base.TEffectNodeArray;

  TEffectGraph = record
  private
    FNodes: TEffectNodeArray;
  public
    procedure Clear; inline;
    function IsEmpty: Boolean; inline;
    function Count: Integer; inline;
    function AddBlur(ARadius: Single): Integer;
    function AddDropShadow(ADx, ADy, ARadius: Single; AColor: TColor32): Integer;
    function AddHue(AShiftDegrees: Single): Integer;
    function AddLUT(const AData: TBytes): Integer;
    function Serialize: TBytes;
    procedure Deserialize(const AData: TBytes);
    function Bake(const ASrc: TBitmap): TBitmap;
  end;

const
  BOXBLUR_MAX_PIXELS = 16 * 1024 * 1024;
  BOXBLUR_ARENA_LIMIT = 32 * 1024 * 1024;
  BOXBLUR_TILE = 64;
  BOXBLUR_ALIGN = 64;

function BoxBlur(const ASrc: TBitmap; ARadius: Integer): TBitmap;

implementation

uses
  nextpas.core.errors,
  nextpas.core.graphics.errors,
  nextpas.core.graphics.effect.graph.boxblur,
  nextpas.core.graphics.effect.graph.serialize,
  nextpas.core.simd.raster,
  nextpas.core.text.conv;

function BoxBlur(const ASrc: TBitmap; ARadius: Integer): TBitmap;
begin
  Result := nextpas.core.graphics.effect.graph.boxblur.BoxBlur(ASrc, ARadius);
end;

procedure TEffectGraph.Clear;
begin
  SetLength(FNodes, 0);
end;

function TEffectGraph.IsEmpty: Boolean;
begin
  Result := Length(FNodes) = 0;
end;

function TEffectGraph.Count: Integer;
begin
  Result := Length(FNodes);
end;

function TEffectGraph.AddBlur(ARadius: Single): Integer;
var
  N: TEffectNode;
begin
  if ARadius < 0 then raise EArgumentError.Create('nextpas.core.graphics.effect.graph.pas: TEffectGraph.AddBlur: radius must be >= 0 (radius=' + FloatToStr(ARadius) + ')');
  N.Kind := ekBlur; N.Radius := ARadius;
  N.Dx := 0; N.Dy := 0; N.HueShift := 0; N.ShadowColor := 0; N.LutData := nil;
  SetLength(FNodes, Length(FNodes) + 1);
  Result := High(FNodes);
  FNodes[Result] := N;
end;

function TEffectGraph.AddDropShadow(ADx, ADy, ARadius: Single; AColor: TColor32): Integer;
var
  N: TEffectNode;
begin
  if ARadius < 0 then raise EArgumentError.Create('nextpas.core.graphics.effect.graph.pas: TEffectGraph.AddDropShadow: radius must be >= 0 (radius=' + FloatToStr(ARadius) + ' dx=' + FloatToStr(ADx) + ' dy=' + FloatToStr(ADy) + ')');
  N.Kind := ekDropShadow; N.Dx := ADx; N.Dy := ADy; N.Radius := ARadius; N.ShadowColor := AColor;
  N.HueShift := 0; N.LutData := nil;
  SetLength(FNodes, Length(FNodes) + 1);
  Result := High(FNodes);
  FNodes[Result] := N;
end;

function TEffectGraph.AddHue(AShiftDegrees: Single): Integer;
var
  N: TEffectNode;
begin
  N.Kind := ekHue; N.HueShift := AShiftDegrees;
  N.Radius := 0; N.Dx := 0; N.Dy := 0; N.ShadowColor := 0; N.LutData := nil;
  SetLength(FNodes, Length(FNodes) + 1);
  Result := High(FNodes);
  FNodes[Result] := N;
end;

function TEffectGraph.AddLUT(const AData: TBytes): Integer;
var
  N: TEffectNode;
begin
  if Length(AData) <> 256 * 3 then raise EArgumentError.Create('nextpas.core.graphics.effect.graph.pas: TEffectGraph.AddLUT: LUT must be 256*3 bytes (got ' + IntToStr(Length(AData)) + ' expected 768)');
  N.Kind := ekLUT; N.LutData := Copy(AData, 0, Length(AData));
  N.Radius := 0; N.Dx := 0; N.Dy := 0; N.ShadowColor := 0; N.HueShift := 0;
  SetLength(FNodes, Length(FNodes) + 1);
  Result := High(FNodes);
  FNodes[Result] := N;
end;

function TEffectGraph.Serialize: TBytes;
begin
  Result := EffectGraphSerialize(FNodes);
end;

procedure TEffectGraph.Deserialize(const AData: TBytes);
begin
  Clear;
  FNodes := EffectGraphDeserialize(AData);
end;

function TEffectGraph.Bake(const ASrc: TBitmap): TBitmap;
var
  I, Y, Steps, S: Integer;
  Cur, Shadow, OutBmp: TBitmap;
  H: Single;
  SrcRow, DstRow: PByte;
  SC: TColor32;
  SR, SG, SB, SA: Byte;
begin
  if ASrc.IsEmpty then raise EEffectError.Create('nextpas.core.graphics.effect.graph.pas: TEffectGraph.Bake: src empty');
  Cur := ASrc.Clone;
  for I := 0 to High(FNodes) do
    case FNodes[I].Kind of
      ekBlur: Cur := nextpas.core.graphics.effect.graph.boxblur.BoxBlur(Cur, Trunc(FNodes[I].Radius));
      ekDropShadow:
        begin
          Shadow := nextpas.core.graphics.effect.graph.boxblur.BoxBlur(Cur, Trunc(FNodes[I].Radius));
          SC := FNodes[I].ShadowColor;
          SR := Byte((SC shr 16) and $FF); SG := Byte((SC shr 8) and $FF); SB := Byte(SC and $FF); SA := Byte((SC shr 24) and $FF);
          for Y := 0 to Shadow.Height - 1 do
          begin
            DstRow := Shadow.RowPtr(Y);
            for S := 0 to Shadow.Width - 1 do
            begin
              SrcRow := DstRow + S * 4;
              SrcRow[0] := Byte((Integer(SB) * Integer(SrcRow[3]) * Integer(SA) + 127) div (255 * 255));
              SrcRow[1] := Byte((Integer(SG) * Integer(SrcRow[3]) * Integer(SA) + 127) div (255 * 255));
              SrcRow[2] := Byte((Integer(SR) * Integer(SrcRow[3]) * Integer(SA) + 127) div (255 * 255));
              SrcRow[3] := Byte((Integer(SrcRow[3]) * Integer(SA) + 127) div 255);
            end;
          end;
          OutBmp := TBitmap.Create(Cur.Width, Cur.Height, Cur.Format);
          for Y := 0 to OutBmp.Height - 1 do
          begin
            DstRow := OutBmp.RowPtr(Y);
            if (Y - Trunc(FNodes[I].Dy) >= 0) and (Y - Trunc(FNodes[I].Dy) < Shadow.Height) then
            begin
              SrcRow := Shadow.ConstRowPtr(Y - Trunc(FNodes[I].Dy));
              for S := 0 to OutBmp.Width - 1 do
                if (S - Trunc(FNodes[I].Dx) >= 0) and (S - Trunc(FNodes[I].Dx) < Shadow.Width) then
                  Move((SrcRow + (S - Trunc(FNodes[I].Dx)) * 4)^, (DstRow + S * 4)^, 4);
            end;
          end;
          for Y := 0 to Cur.Height - 1 do
            RasterBlendVaried(OutBmp.RowPtr(Y), PLongWord(Cur.ConstRowPtr(Y)), Cur.Width);
          Cur := OutBmp;
        end;
      ekHue:
        begin
          H := FNodes[I].HueShift;
          Steps := 0;
          if Abs(H) > 0.5 then
          begin
            Steps := (Trunc(Abs(H)) div 120) mod 3;
            if Steps = 0 then Steps := 1;
            if H < 0 then Steps := (3 - Steps) mod 3;
          end;
          for S := 0 to Steps - 1 do
            for Y := 0 to Cur.Height - 1 do
              RasterRotateRGB(Cur.RowPtr(Y), Cur.Width);
        end;
      ekLUT:
        begin
          if Length(FNodes[I].LutData) <> 256 * 3 then raise EEffectError.Create('nextpas.core.graphics.effect.graph.pas: TEffectGraph.Bake: lut size mismatch (got ' + IntToStr(Length(FNodes[I].LutData)) + ' expected 768 index=' + IntToStr(I) + ')');
          for Y := 0 to Cur.Height - 1 do
            RasterApplyLut(Cur.RowPtr(Y), Cur.Width, @FNodes[I].LutData[0]);
        end;
    end;
  Result := Cur;
end;

end.
