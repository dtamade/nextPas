{ nextpas.core.graphics.effect.graph - 滤镜图 L2 arena+tile并行 bytes.binary }
unit nextpas.core.graphics.effect.graph;

{$I nextpas.core.settings.inc}
{$modeswitch advancedrecords}
{$POINTERMATH ON}
interface

uses
  nextpas.core.base,
  nextpas.core.graphics.base,
  nextpas.core.image.base;
type
  TEffectKind = (ekBlur, ekDropShadow, ekHue, ekLUT);

  TEffectNode = record
    Kind: TEffectKind;
    Radius: Single;
    Dx, Dy: Single;
    ShadowColor: TColor32;
    HueShift: Single;
    LutData: TBytes;
  end;

  TEffectGraph = record
  private FNodes: array of TEffectNode;
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
  // BoxBlur CONTRACT invariants (testable): keep sync with core/docs/graphics/CONTRACT.md §1.3
  BOXBLUR_MAX_PIXELS = 16 * 1024 * 1024; // fail-closed limit
  BOXBLUR_ARENA_LIMIT = 32 * 1024 * 1024; // NeedHH threshold: arena vs heap-tile fallback
  BOXBLUR_TILE = 64; // Tile64 cacheline sharding
  BOXBLUR_ALIGN = 64; // AlignUp64 for all heap/arena allocations (Halo/Persist/Scratch/Chunk)
implementation
uses
  nextpas.core.errors,
  nextpas.core.graphics.errors,
  nextpas.core.simd.raster,
  nextpas.core.thread.pool,
  nextpas.core.thread.intf,
  nextpas.core.mem.base,
  nextpas.core.mem.arena,
  nextpas.core.bytes.binary,
  nextpas.core.text.conv;
var
  GBlurPool: IThreadPool;

function GetBlurPool: IThreadPool;
begin
  if GBlurPool = nil then GBlurPool := CreateThreadPool(0);
  Result := GBlurPool;
end;
procedure HorzRowInto(const ASrcRow: PByte; AW, AR: Integer; ADstR, ADstG, ADstB, ADstA: PInteger); inline;
var
  X, K, SR, SG, SB, SA: Integer;
  P: PByte;
begin
  SR := 0; SG := 0; SB := 0; SA := 0;
  for K := 0 to AR do if K < AW then
  begin
    P := ASrcRow + K * 4;
    SR += P[0]; SG += P[1]; SB += P[2]; SA += P[3];
  end;
  for X := 0 to AW - 1 do
  begin
    ADstR[X] := SR; ADstG[X] := SG; ADstB[X] := SB; ADstA[X] := SA;
    if X - AR >= 0 then
    begin
      P := ASrcRow + (X - AR) * 4;
      SR -= P[0]; SG -= P[1]; SB -= P[2]; SA -= P[3];
    end;
    if X + AR + 1 < AW then
    begin
      P := ASrcRow + (X + AR + 1) * 4;
      SR += P[0]; SG += P[1]; SB += P[2]; SA += P[3];
    end;
  end;
end;
function VertCount(AY, AH, AR: Integer): Integer; inline;
var
  L, R: Integer;
begin
  L := AY - AR; if L < 0 then L := 0;
  R := AY + AR; if R >= AH then R := AH - 1;
  Result := R - L + 1;
  if Result < 0 then Result := 0;
end;
procedure VecAddI32(ADst, ASrc: PInteger; N: Integer); inline;
var
  I, N8, R: Integer;
  D, S: PInteger;
begin
  if (ADst = nil) or (ASrc = nil) or (N <= 0) then Exit;
  D := ADst; S := ASrc;
  N8 := N shr 3; R := N and 7;
  for I := 0 to N8 - 1 do
  begin
    D[0] += S[0]; D[1] += S[1]; D[2] += S[2]; D[3] += S[3];
    D[4] += S[4]; D[5] += S[5]; D[6] += S[6]; D[7] += S[7];
    Inc(D, 8); Inc(S, 8);
  end;
  for I := 0 to R - 1 do D[I] += S[I];
end;
procedure VecSubI32(ADst, ASrc: PInteger; N: Integer); inline;
var
  I, N8, R: Integer;
  D, S: PInteger;
begin
  if (ADst = nil) or (ASrc = nil) or (N <= 0) then Exit;
  D := ADst; S := ASrc;
  N8 := N shr 3; R := N and 7;
  for I := 0 to N8 - 1 do
  begin
    D[0] -= S[0]; D[1] -= S[1]; D[2] -= S[2]; D[3] -= S[3];
    D[4] -= S[4]; D[5] -= S[5]; D[6] -= S[6]; D[7] -= S[7];
    Inc(D, 8); Inc(S, 8);
  end;
  for I := 0 to R - 1 do D[I] -= S[I];
end;
procedure BuildHorzSums(const ASrc: TBitmap; AR: Integer; HH_R, HH_G, HH_B, HH_A: PInteger);
var
  Y, W, H: Integer;
  SrcRow: PByte;
begin
  W := ASrc.Width; H := ASrc.Height;
  for Y := 0 to H - 1 do
  begin
    SrcRow := ASrc.RowPtr(Y);
    HorzRowInto(SrcRow, W, AR, HH_R + Y * W, HH_G + Y * W, HH_B + Y * W, HH_A + Y * W);
  end;
end;
procedure BuildCntH(CntH: PInteger; AW, AR: Integer);
var
  X, L, R: Integer;
begin
  for X := 0 to AW - 1 do
  begin
    L := X - AR; if L < 0 then L := 0;
    R := X + AR; if R >= AW then R := AW - 1;
    CntH[X] := R - L + 1;
  end;
end;
procedure BuildCntHAndInv(CntH: PInteger; CntInv: PCardinal; AW, AR: Integer);
var
  X, L, R, C: Integer;
begin
  for X := 0 to AW - 1 do
  begin
    L := X - AR; if L < 0 then L := 0;
    R := X + AR; if R >= AW then R := AW - 1;
    C := R - L + 1;
    CntH[X] := C;
    if C > 0 then CntInv[X] := Cardinal((QWord(1) shl 32) div QWord(Cardinal(C)))
    else CntInv[X] := 0;
  end;
end;
type
  PBlurStripTask = ^TBlurStripTask;
  TBlurStripTask = record
    Y0, Y1, W, H, R: Integer;
    Dst: ^TBitmap;
    HH_R, HH_G, HH_B, HH_A: PInteger;
    CntH: PInteger;
    CntInv: PCardinal;
    VCInvTab: PCardinal;
    VCInvLen: Integer;
    VSumR, VSumG, VSumB, VSumA: PInteger;
    ChunkY0, ChunkH: Integer;
  end;
  PHorzTask = ^THorzTask;
  THorzTask = record Src: ^TBitmap; R, Y0, Y1: Integer; HH_R, HH_G, HH_B, HH_A: PInteger; W: Integer; end;

procedure BuildHorzSumsRange(const ASrc: TBitmap; AR, AY0, AYCount: Integer; HH_R, HH_G, HH_B, HH_A: PInteger);
var
  Y, W: Integer;
  SrcRow: PByte;
begin
  W := ASrc.Width;
  for Y := 0 to AYCount - 1 do
  begin
    SrcRow := ASrc.RowPtr(AY0 + Y);
    HorzRowInto(SrcRow, W, AR, HH_R + Y * W, HH_G + Y * W, HH_B + Y * W, HH_A + Y * W);
  end;
end;
procedure HorzTaskProc(AData: Pointer);
var T: PHorzTask; Y: Integer; Row: PByte;
begin
  T := PHorzTask(AData);
  for Y := T^.Y0 to T^.Y1 - 1 do
  begin
    Row := T^.Src^.RowPtr(Y);
    HorzRowInto(Row, T^.W, T^.R, T^.HH_R + Y * T^.W, T^.HH_G + Y * T^.W, T^.HH_B + Y * T^.W, T^.HH_A + Y * T^.W);
  end;
end;
procedure BlurStripVerticalChunked(const HH_R, HH_G, HH_B, HH_A: PInteger; ChunkY0, ChunkH, AW, AH, AR, AY0, AY1: Integer; var ADst: TBitmap; VSumR, VSumG, VSumB, VSumA: PInteger; CntH: PInteger; CntInv: PCardinal; VCInvTab: PCardinal; VCInvLen: Integer);
var
  X, Y, YRem, YAdd, VC: Integer;
  VCInv: Cardinal;
  DstRow: PByte;
  RowPtr: PInteger;
begin
  if (AY0 >= AY1) or (AW <= 0) or (AH <= 0) then Exit;
  if (VSumR = nil) or (VSumG = nil) or (VSumB = nil) or (VSumA = nil) then Exit;
  if (VCInvTab = nil) or (VCInvLen <= 0) then Exit;
  for X := 0 to AW - 1 do
  begin
    VSumR[X] := 0; VSumG[X] := 0; VSumB[X] := 0; VSumA[X] := 0;
  end;
  for Y := AY0 - AR to AY0 + AR do if (Y >= 0) and (Y < AH) and (Y >= ChunkY0) and (Y < ChunkY0 + ChunkH) then
  begin
    RowPtr := HH_R + (Y - ChunkY0) * AW; VecAddI32(VSumR, RowPtr, AW);
    RowPtr := HH_G + (Y - ChunkY0) * AW; VecAddI32(VSumG, RowPtr, AW);
    RowPtr := HH_B + (Y - ChunkY0) * AW; VecAddI32(VSumB, RowPtr, AW);
    RowPtr := HH_A + (Y - ChunkY0) * AW; VecAddI32(VSumA, RowPtr, AW);
  end;
  for Y := AY0 to AY1 - 1 do
  begin
    VC := VertCount(Y, AH, AR);
    DstRow := ADst.RowPtr(Y);
    if VC <= 0 then VCInv := 0
    else if (VC >= 0) and (VC < VCInvLen) then VCInv := VCInvTab[VC]
    else VCInv := Cardinal((QWord(1) shl 32) div QWord(Cardinal(VC)));
    // vertical normalize batch via simd.raster (AVX2 8-wide when available, scalar 4-wide fallback)
    RasterBlurNormalizeRow(DstRow, VSumR, VSumG, VSumB, VSumA, CntH, CntInv, VC, VCInv, AW);
    if Y = AY1 - 1 then Break;
    YRem := Y - AR;
    YAdd := Y + AR + 1;
    if (YRem >= 0) and (YRem < AH) and (YRem >= ChunkY0) and (YRem < ChunkY0 + ChunkH) then
    begin
      RowPtr := HH_R + (YRem - ChunkY0) * AW; VecSubI32(VSumR, RowPtr, AW);
      RowPtr := HH_G + (YRem - ChunkY0) * AW; VecSubI32(VSumG, RowPtr, AW);
      RowPtr := HH_B + (YRem - ChunkY0) * AW; VecSubI32(VSumB, RowPtr, AW);
      RowPtr := HH_A + (YRem - ChunkY0) * AW; VecSubI32(VSumA, RowPtr, AW);
    end;
    if (YAdd >= 0) and (YAdd < AH) and (YAdd >= ChunkY0) and (YAdd < ChunkY0 + ChunkH) then
    begin
      RowPtr := HH_R + (YAdd - ChunkY0) * AW; VecAddI32(VSumR, RowPtr, AW);
      RowPtr := HH_G + (YAdd - ChunkY0) * AW; VecAddI32(VSumG, RowPtr, AW);
      RowPtr := HH_B + (YAdd - ChunkY0) * AW; VecAddI32(VSumB, RowPtr, AW);
      RowPtr := HH_A + (YAdd - ChunkY0) * AW; VecAddI32(VSumA, RowPtr, AW);
    end;
  end;
end;
procedure BlurStripVertical(const HH_R, HH_G, HH_B, HH_A: PInteger; CntH: PInteger; CntInv: PCardinal; VCInvTab: PCardinal; VCInvLen: Integer; AW, AH, AR, AY0, AY1: Integer; var ADst: TBitmap; VSumR, VSumG, VSumB, VSumA: PInteger);
begin
  BlurStripVerticalChunked(HH_R, HH_G, HH_B, HH_A, 0, AH, AW, AH, AR, AY0, AY1, ADst, VSumR, VSumG, VSumB, VSumA, CntH, CntInv, VCInvTab, VCInvLen);
end;
procedure BlurStripTaskProc(AData: Pointer);
var
  T: PBlurStripTask;
begin
  T := PBlurStripTask(AData);
  if T^.ChunkH > 0 then
    BlurStripVerticalChunked(T^.HH_R, T^.HH_G, T^.HH_B, T^.HH_A, T^.ChunkY0, T^.ChunkH, T^.W, T^.H, T^.R, T^.Y0, T^.Y1, T^.Dst^, T^.VSumR, T^.VSumG, T^.VSumB, T^.VSumA, T^.CntH, T^.CntInv, T^.VCInvTab, T^.VCInvLen)
  else
    BlurStripVertical(T^.HH_R, T^.HH_G, T^.HH_B, T^.HH_A, T^.CntH, T^.CntInv, T^.VCInvTab, T^.VCInvLen, T^.W, T^.H, T^.R, T^.Y0, T^.Y1, T^.Dst^, T^.VSumR, T^.VSumG, T^.VSumB, T^.VSumA);
end;
procedure TEffectGraph.Clear;
begin SetLength(FNodes, 0); end;
function TEffectGraph.IsEmpty: Boolean;
begin Result := Length(FNodes) = 0; end;
function TEffectGraph.Count: Integer;
begin Result := Length(FNodes); end;
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
var
  I, Need: Integer;
  P: PByte;
  U: LongWord;
begin
  Result := nil;
  Need := 4;
  for I := 0 to High(FNodes) do
    case FNodes[I].Kind of
      ekBlur: Inc(Need, 1 + 4);
      ekDropShadow: Inc(Need, 1 + 4 + 4 + 4 + 4);
      ekHue: Inc(Need, 1 + 4);
      ekLUT: Inc(Need, 1 + 4 + Length(FNodes[I].LutData));
    end;
  SetLength(Result, Need);
  if Need = 0 then Exit;
  P := @Result[0];
  WriteUInt32LE(P, LongWord(Length(FNodes))); Inc(P, 4);
  for I := 0 to High(FNodes) do
  begin
    P^ := Byte(FNodes[I].Kind); Inc(P);
    case FNodes[I].Kind of
      ekBlur:
        begin
          Move(FNodes[I].Radius, U, 4);
          WriteUInt32LE(P, U); Inc(P, 4);
        end;
      ekDropShadow:
        begin
          Move(FNodes[I].Dx, U, 4); WriteUInt32LE(P, U); Inc(P, 4);
          Move(FNodes[I].Dy, U, 4); WriteUInt32LE(P, U); Inc(P, 4);
          Move(FNodes[I].Radius, U, 4); WriteUInt32LE(P, U); Inc(P, 4);
          WriteUInt32LE(P, LongWord(FNodes[I].ShadowColor)); Inc(P, 4);
        end;
      ekHue:
        begin
          Move(FNodes[I].HueShift, U, 4);
          WriteUInt32LE(P, U); Inc(P, 4);
        end;
      ekLUT:
        begin
          WriteUInt32LE(P, LongWord(Length(FNodes[I].LutData))); Inc(P, 4);
          if Length(FNodes[I].LutData) > 0 then
          begin
            Move(FNodes[I].LutData[0], P^, Length(FNodes[I].LutData));
            Inc(P, Length(FNodes[I].LutData));
          end;
        end;
    end;
  end;
end;

procedure TEffectGraph.Deserialize(const AData: TBytes);
var
  P: PByte;
  N, I, Off: Integer;
  Lc: LongWord;
  Kind: Byte;
  U: LongWord;
begin
  Clear;
  if Length(AData) < 4 then raise EEffectError.Create('nextpas.core.graphics.effect.graph.pas: TEffectGraph.Deserialize: truncated header (len=' + IntToStr(Length(AData)) + ' need 4 offset=0)');
  P := @AData[0];
  N := Integer(ReadUInt32LE(P));
  Off := 4;
  if (N < 0) or (N > 1024) then raise EEffectError.Create('nextpas.core.graphics.effect.graph.pas: TEffectGraph.Deserialize: bad node count (count=' + IntToStr(N) + ' limit=1024 offset=' + IntToStr(Off - 4) + ')');
  SetLength(FNodes, N);
  for I := 0 to N - 1 do
  begin
    if Off >= Length(AData) then raise EEffectError.Create('nextpas.core.graphics.effect.graph.pas: TEffectGraph.Deserialize: truncated node (offset=' + IntToStr(Off) + ' index=' + IntToStr(I) + ' len=' + IntToStr(Length(AData)) + ')');
    Kind := AData[Off]; Inc(Off);
    if Kind > Ord(High(TEffectKind)) then raise EEffectError.Create('nextpas.core.graphics.effect.graph.pas: TEffectGraph.Deserialize: bad kind (kind=' + IntToStr(Kind) + ' offset=' + IntToStr(Off - 1) + ' index=' + IntToStr(I) + ')');
    FNodes[I].Kind := TEffectKind(Kind);
    FNodes[I].Radius := 0; FNodes[I].Dx := 0; FNodes[I].Dy := 0; FNodes[I].ShadowColor := 0; FNodes[I].HueShift := 0; FNodes[I].LutData := nil;
    case FNodes[I].Kind of
      ekBlur:
        begin
          if Off + 4 > Length(AData) then raise EEffectError.Create('nextpas.core.graphics.effect.graph.pas: TEffectGraph.Deserialize: truncated blur (offset=' + IntToStr(Off) + ' need 4 have ' + IntToStr(Length(AData) - Off) + ' index=' + IntToStr(I) + ')');
          P := PByte(@AData[Off]); U := ReadUInt32LE(P); Inc(Off, 4);
          Move(U, FNodes[I].Radius, 4);
        end;
      ekDropShadow:
        begin
          if Off + 16 > Length(AData) then raise EEffectError.Create('nextpas.core.graphics.effect.graph.pas: TEffectGraph.Deserialize: truncated shadow (offset=' + IntToStr(Off) + ' need 16 have ' + IntToStr(Length(AData) - Off) + ' index=' + IntToStr(I) + ')');
          P := PByte(@AData[Off]); U := ReadUInt32LE(P); Inc(Off, 4); Move(U, FNodes[I].Dx, 4);
          P := PByte(@AData[Off]); U := ReadUInt32LE(P); Inc(Off, 4); Move(U, FNodes[I].Dy, 4);
          P := PByte(@AData[Off]); U := ReadUInt32LE(P); Inc(Off, 4); Move(U, FNodes[I].Radius, 4);
          P := PByte(@AData[Off]); U := ReadUInt32LE(P); Inc(Off, 4); FNodes[I].ShadowColor := TColor32(U);
        end;
      ekHue:
        begin
          if Off + 4 > Length(AData) then raise EEffectError.Create('nextpas.core.graphics.effect.graph.pas: TEffectGraph.Deserialize: truncated hue (offset=' + IntToStr(Off) + ' need 4 have ' + IntToStr(Length(AData) - Off) + ' index=' + IntToStr(I) + ')');
          P := PByte(@AData[Off]); U := ReadUInt32LE(P); Inc(Off, 4);
          Move(U, FNodes[I].HueShift, 4);
        end;
      ekLUT:
        begin
          if Off + 4 > Length(AData) then raise EEffectError.Create('nextpas.core.graphics.effect.graph.pas: TEffectGraph.Deserialize: truncated lut header (offset=' + IntToStr(Off) + ' need 4 have ' + IntToStr(Length(AData) - Off) + ' index=' + IntToStr(I) + ')');
          P := PByte(@AData[Off]); Lc := ReadUInt32LE(P); Inc(Off, 4);
          if Lc <> 256 * 3 then raise EEffectError.Create('nextpas.core.graphics.effect.graph.pas: TEffectGraph.Deserialize: LUT size mismatch (got ' + IntToStr(Int64(Lc)) + ' expected 768 offset=' + IntToStr(Off - 4) + ' index=' + IntToStr(I) + ')');
          if Off + Integer(Lc) > Length(AData) then raise EEffectError.Create('nextpas.core.graphics.effect.graph.pas: TEffectGraph.Deserialize: truncated lut data (offset=' + IntToStr(Off) + ' need ' + IntToStr(Int64(Lc)) + ' have ' + IntToStr(Length(AData) - Off) + ' index=' + IntToStr(I) + ')');
          SetLength(FNodes[I].LutData, Lc);
          if Lc > 0 then Move(AData[Off], FNodes[I].LutData[0], Lc);
          Inc(Off, Integer(Lc));
        end;
    end;
  end;
end;

function BoxBlur(const ASrc: TBitmap; ARadius: Integer): TBitmap;
var
  W, H, I, Y0, Y1, CY0, CY1, CH, J, Batch, BatchCount, NumStrips, Tile, NumWorkers, Ti: Integer;
  Pool: IThreadPool;
  UseParallel, UseGlobal: Boolean;
  Arena: IArena;
  HH_Base, HH_R, HH_G, HH_B, HH_A, CntH: PInteger;
  CntInv: PCardinal;
  VCInvTab: array of Cardinal;
  VCInvPtr: PCardinal;
  VCInvLen: Integer;
  ScratchBase: PInteger;
  NeedHH, ScratchBytes, ChunkBytes: SizeUInt;
  Tasks: array of TBlurStripTask;
  HorzTasks: array of THorzTask;
  VSumR, VSumG, VSumB, VSumA: PInteger;
  MaxCH, PrevCY0, PrevCY1, Overlap, SrcOff, NewRows: Integer;
  PersistBase, HaloBase, PrevHHBase: PInteger;
  Halo_R, Halo_G, Halo_B, Halo_A: PInteger;
  HaloBytes: SizeUInt;
  PersistBytes: SizeUInt;
begin
  if ASrc.IsEmpty then raise EEffectError.Create('nextpas.core.graphics.effect.graph.pas: BoxBlur: src empty');
  if ASrc.Width * ASrc.Height > BOXBLUR_MAX_PIXELS then raise EEffectError.Create('nextpas.core.graphics.effect.graph.pas: BoxBlur: image too large (limit 16M pixels, got ' + IntToStr(Int64(ASrc.Width) * Int64(ASrc.Height)) + ' W=' + IntToStr(ASrc.Width) + ' H=' + IntToStr(ASrc.Height) + ' radius=' + IntToStr(ARadius) + ')');
  if ARadius <= 0 then Exit(ASrc);
  W := ASrc.Width; H := ASrc.Height;
  Result := TBitmap.Create(W, H, ASrc.Format);
  // heaptrc0 guard: nil-init all heap pointers, unify GetMem/FreeMem paths (no manual FreeMem before raise)
  HH_Base := nil; HH_R := nil; HH_G := nil; HH_B := nil; HH_A := nil;
  CntH := nil; CntInv := nil; ScratchBase := nil; PersistBase := nil; HaloBase := nil; PrevHHBase := nil;
  Halo_R := nil; Halo_G := nil; Halo_B := nil; Halo_A := nil;
  Arena := nil;
  SetLength(VCInvTab, 2 * ARadius + 2);
  for Ti := 1 to 2 * ARadius + 1 do VCInvTab[Ti] := Cardinal((QWord(1) shl 32) div QWord(Cardinal(Ti)));
  if Length(VCInvTab) > 0 then VCInvTab[0] := 0;
  if Length(VCInvTab) > 0 then VCInvPtr := @VCInvTab[0] else VCInvPtr := nil;
  VCInvLen := Length(VCInvTab);
  PrevCY0 := 0; PrevCY1 := -1;
  UseParallel := (W * H >= 256 * 1024) and IsMultiThread;
  if UseParallel then
  begin
    Pool := GetBlurPool;
    UseParallel := Pool.WorkerCount > 1;
  end
  else
    Pool := nil;
  if UseParallel then
  begin
    Tile := BOXBLUR_TILE;
    if ARadius * 4 > Tile then Tile := ARadius * 4;
    if Tile > H then Tile := H;
    NumStrips := (H + Tile - 1) div Tile;
  end
  else
  begin
    Tile := H;
    NumStrips := 1;
  end;
  if UseParallel then
  begin
    NumWorkers := Pool.WorkerCount;
    if NumWorkers < 1 then NumWorkers := 1;
    if NumWorkers > NumStrips then NumWorkers := NumStrips;
    ScratchBytes := AlignUp(SizeUInt(NumWorkers) * SizeUInt(W) * 4 * SizeOf(Integer), BOXBLUR_ALIGN);
  end
  else
  begin
    NumWorkers := 1;
    ScratchBytes := AlignUp(SizeUInt(W) * 4 * SizeOf(Integer), BOXBLUR_ALIGN);
  end;
  NeedHH := AlignUp(SizeUInt(H) * SizeUInt(W) * 4 * SizeOf(Integer) + SizeUInt(W) * SizeOf(Integer) + SizeUInt(W) * SizeOf(Cardinal) + BOXBLUR_ALIGN, BOXBLUR_ALIGN);
  if NeedHH = 0 then NeedHH := BOXBLUR_ALIGN;
  UseGlobal := NeedHH <= BOXBLUR_ARENA_LIMIT;
  if UseGlobal then
  begin
    // arena owns HH/Cnt; ScratchBase remains the only GetMem in this branch — unified finally
    // CONTRACT §1.3 BoxBlur invariants: Tile64 cacheline, AlignUp64, 16M pixel cap, 32M arena budget
    Arena := TLocalArena.Create(NeedHH);
    HH_Base := PInteger(Arena.AllocAligned(SizeUInt(H) * SizeUInt(W) * 4 * SizeOf(Integer), BOXBLUR_ALIGN));
    if HH_Base = nil then raise EEffectError.Create('nextpas.core.graphics.effect.graph.pas: BoxBlur: arena alloc failed (need=' + IntToStr(Int64(H) * Int64(W) * 4 * SizeOf(Integer)) + ' W=' + IntToStr(W) + ' H=' + IntToStr(H) + ' radius=' + IntToStr(ARadius) + ')');
    HH_R := HH_Base;
    HH_G := HH_Base + H * W;
    HH_B := HH_Base + H * W * 2;
    HH_A := HH_Base + H * W * 3;
    CntH := PInteger(Arena.AllocAligned(SizeUInt(W) * SizeOf(Integer), BOXBLUR_ALIGN));
    CntInv := PCardinal(Arena.AllocAligned(SizeUInt(W) * SizeOf(Cardinal), BOXBLUR_ALIGN));
    if (CntH = nil) or (CntInv = nil) then raise EEffectError.Create('nextpas.core.graphics.effect.graph.pas: BoxBlur: arena alloc failed (cnt=' + IntToStr(Int64(W) * SizeOf(Integer)) + ' W=' + IntToStr(W) + ' H=' + IntToStr(H) + ' radius=' + IntToStr(ARadius) + ')');
    GetMem(ScratchBase, ScratchBytes);
    if ScratchBase = nil then raise EEffectError.Create('nextpas.core.graphics.effect.graph.pas: BoxBlur: scratch alloc failed (scratch=' + IntToStr(Int64(ScratchBytes)) + ' W=' + IntToStr(W) + ' H=' + IntToStr(H) + ' radius=' + IntToStr(ARadius) + ')');
    try
      BuildCntHAndInv(CntH, CntInv, W, ARadius);
      if UseParallel then
      begin
        SetLength(HorzTasks, NumWorkers);
        for I := 0 to NumWorkers - 1 do
        begin
          Y0 := (H * I) div NumWorkers; Y1 := (H * (I + 1)) div NumWorkers;
          HorzTasks[I].Src := @ASrc; HorzTasks[I].R := ARadius; HorzTasks[I].Y0 := Y0; HorzTasks[I].Y1 := Y1;
          HorzTasks[I].HH_R := HH_R; HorzTasks[I].HH_G := HH_G; HorzTasks[I].HH_B := HH_B; HorzTasks[I].HH_A := HH_A; HorzTasks[I].W := W;
          Pool.SubmitDirect(@HorzTasks[I], @HorzTaskProc);
        end;
        Pool.WaitAll;
        SetLength(Tasks, NumStrips);
        for I := 0 to NumStrips - 1 do
        begin
          Y0 := I * Tile; Y1 := Y0 + Tile; if Y1 > H then Y1 := H;
          Tasks[I].Y0 := Y0; Tasks[I].Y1 := Y1; Tasks[I].W := W; Tasks[I].H := H; Tasks[I].R := ARadius;
          Tasks[I].Dst := @Result;
          Tasks[I].HH_R := HH_R; Tasks[I].HH_G := HH_G; Tasks[I].HH_B := HH_B; Tasks[I].HH_A := HH_A;
          Tasks[I].CntH := CntH;
          Tasks[I].CntInv := CntInv;
          Tasks[I].VCInvTab := VCInvPtr; Tasks[I].VCInvLen := VCInvLen;
          Tasks[I].ChunkY0 := 0; Tasks[I].ChunkH := 0;
          Tasks[I].VSumR := ScratchBase + (I mod NumWorkers) * W * 4;
          Tasks[I].VSumG := ScratchBase + (I mod NumWorkers) * W * 4 + W;
          Tasks[I].VSumB := ScratchBase + (I mod NumWorkers) * W * 4 + W * 2;
          Tasks[I].VSumA := ScratchBase + (I mod NumWorkers) * W * 4 + W * 3;
        end;
        I := 0;
        while I < NumStrips do
        begin
          Y0 := I; Y1 := I + NumWorkers; if Y1 > NumStrips then Y1 := NumStrips;
          for Y0 := I to Y1 - 1 do Pool.SubmitDirect(@Tasks[Y0], @BlurStripTaskProc);
          Pool.WaitAll;
          I := Y1;
        end;
      end
      else
      begin
        BuildHorzSums(ASrc, ARadius, HH_R, HH_G, HH_B, HH_A);
        VSumR := ScratchBase;
        VSumG := ScratchBase + W;
        VSumB := ScratchBase + W * 2;
        VSumA := ScratchBase + W * 3;
        BlurStripVertical(HH_R, HH_G, HH_B, HH_A, CntH, CntInv, VCInvPtr, VCInvLen, W, H, ARadius, 0, H, Result, VSumR, VSumG, VSumB, VSumA);
      end;
    finally
      if ScratchBase <> nil then FreeMem(ScratchBase);
      ScratchBase := nil;
    end;
  end
  else
  begin
    // heap path: unified outer finally replaces manual FreeMem before raise (AlignUp64 cacheline)
    try
      GetMem(CntH, AlignUp(SizeUInt(W) * SizeOf(Integer), BOXBLUR_ALIGN));
      if CntH = nil then raise EEffectError.Create('nextpas.core.graphics.effect.graph.pas: BoxBlur: cnt alloc failed (W=' + IntToStr(W) + ')');
      GetMem(CntInv, AlignUp(SizeUInt(W) * SizeOf(Cardinal), BOXBLUR_ALIGN));
      if CntInv = nil then raise EEffectError.Create('nextpas.core.graphics.effect.graph.pas: BoxBlur: cntinv alloc failed (W=' + IntToStr(W) + ')');
      GetMem(ScratchBase, ScratchBytes);
      if ScratchBase = nil then raise EEffectError.Create('nextpas.core.graphics.effect.graph.pas: BoxBlur: scratch alloc failed (scratch=' + IntToStr(Int64(ScratchBytes)) + ')');
      BuildCntHAndInv(CntH, CntInv, W, ARadius);
      if not UseParallel then
      begin
        MaxCH := Tile + 2 * ARadius;
        if MaxCH > H then MaxCH := H;
        if MaxCH < 1 then MaxCH := 1;
        // ChunkBytes 64B aligned (Tile64 cacheline, BOXBLUR_ALIGN=64)
        ChunkBytes := AlignUp(SizeUInt(MaxCH) * SizeUInt(W) * 4 * SizeOf(Integer), BOXBLUR_ALIGN);
        GetMem(HH_Base, ChunkBytes);
        if HH_Base = nil then raise EEffectError.Create('nextpas.core.graphics.effect.graph.pas: BoxBlur: chunk alloc failed (need=' + IntToStr(Int64(ChunkBytes)) + ')');
        try
          HH_R := HH_Base;
          HH_G := HH_Base + MaxCH * W;
          HH_B := HH_Base + MaxCH * W * 2;
          HH_A := HH_Base + MaxCH * W * 3;
          VSumR := ScratchBase;
          VSumG := ScratchBase + W;
          VSumB := ScratchBase + W * 2;
          VSumA := ScratchBase + W * 3;
          PrevCY1 := -1; PrevCY0 := 0;
          for I := 0 to NumStrips - 1 do
          begin
            Y0 := I * Tile; Y1 := Y0 + Tile; if Y1 > H then Y1 := H;
            CY0 := Y0 - ARadius; if CY0 < 0 then CY0 := 0;
            CY1 := Y1 + ARadius; if CY1 > H then CY1 := H;
            CH := CY1 - CY0;
            if CH <= 0 then Continue;
            if PrevCY1 >= 0 then
            begin
              Overlap := PrevCY1 - CY0;
              if Overlap > 0 then
              begin
                if Overlap > CH then Overlap := CH;
                SrcOff := CY0 - PrevCY0;
                if (SrcOff >= 0) and (SrcOff + Overlap <= MaxCH) then
                begin
                  Move((HH_R + SrcOff * W)^, HH_R^, Overlap * W * SizeOf(Integer));
                  Move((HH_G + SrcOff * W)^, HH_G^, Overlap * W * SizeOf(Integer));
                  Move((HH_B + SrcOff * W)^, HH_B^, Overlap * W * SizeOf(Integer));
                  Move((HH_A + SrcOff * W)^, HH_A^, Overlap * W * SizeOf(Integer));
                end;
                NewRows := CH - Overlap;
                if NewRows > 0 then
                  BuildHorzSumsRange(ASrc, ARadius, PrevCY1, NewRows, HH_R + Overlap * W, HH_G + Overlap * W, HH_B + Overlap * W, HH_A + Overlap * W);
              end else
                BuildHorzSumsRange(ASrc, ARadius, CY0, CH, HH_R, HH_G, HH_B, HH_A);
            end else
              BuildHorzSumsRange(ASrc, ARadius, CY0, CH, HH_R, HH_G, HH_B, HH_A);
            BlurStripVerticalChunked(HH_R, HH_G, HH_B, HH_A, CY0, CH, W, H, ARadius, Y0, Y1, Result, VSumR, VSumG, VSumB, VSumA, CntH, CntInv, VCInvPtr, VCInvLen);
            PrevCY0 := CY0; PrevCY1 := CY1;
          end;
        finally
          FreeMem(HH_Base);
          HH_Base := nil;
        end;
      end
      else
      begin
        MaxCH := Tile + 2 * ARadius; if MaxCH > H then MaxCH := H; if MaxCH < 1 then MaxCH := 1;
        // ChunkBytes/Persist 64B aligned (Tile64 cacheline, BOXBLUR_ALIGN=64)
        ChunkBytes := AlignUp(SizeUInt(MaxCH) * SizeUInt(W) * 4 * SizeOf(Integer), BOXBLUR_ALIGN);
        PersistBytes := AlignUp(ChunkBytes * SizeUInt(NumWorkers), BOXBLUR_ALIGN);
        GetMem(PersistBase, PersistBytes);
        if PersistBase = nil then raise EEffectError.Create('nextpas.core.graphics.effect.graph.pas: BoxBlur: chunk alloc failed (persist=' + IntToStr(Int64(PersistBytes)) + ')');
        HaloBytes := 0; HaloBase := nil; PrevHHBase := nil;
        if (ARadius > 0) and (W > 0) then
        begin
          // Halo 64B aligned (Tile64 cacheline, BOXBLUR_ALIGN=64)
          HaloBytes := AlignUp(SizeUInt(2 * ARadius) * SizeUInt(W) * 4 * SizeOf(Integer), BOXBLUR_ALIGN);
          if HaloBytes > 0 then
          begin
            GetMem(HaloBase, HaloBytes);
            if HaloBase <> nil then
            begin
              Halo_R := HaloBase; Halo_G := HaloBase + 2 * ARadius * W;
              Halo_B := HaloBase + 2 * ARadius * W * 2; Halo_A := HaloBase + 2 * ARadius * W * 3;
            end else HaloBase := nil;
          end;
        end;
        try
          SetLength(Tasks, NumStrips);
          I := 0; PrevCY1 := -1; PrevCY0 := 0;
          while I < NumStrips do
          begin
            BatchCount := NumWorkers;
            if I + BatchCount > NumStrips then BatchCount := NumStrips - I;
            for J := 0 to BatchCount - 1 do
            begin
              Batch := I + J;
              Y0 := Batch * Tile; Y1 := Y0 + Tile; if Y1 > H then Y1 := H;
              CY0 := Y0 - ARadius; if CY0 < 0 then CY0 := 0;
              CY1 := Y1 + ARadius; if CY1 > H then CY1 := H;
              CH := CY1 - CY0; if CH <= 0 then CH := 1;
              HH_Base := PInteger(PByte(PersistBase) + J * Integer(ChunkBytes));
              HH_R := HH_Base; HH_G := HH_Base + MaxCH * W; HH_B := HH_Base + MaxCH * W * 2; HH_A := HH_Base + MaxCH * W * 3;
              if PrevCY1 >= 0 then
              begin Overlap := PrevCY1 - CY0;
                if (Overlap > 0) and (Overlap <= 2 * ARadius) and (Overlap <= CH) then
                begin
                  if HaloBase <> nil then begin Move(Halo_R^, HH_R^, Overlap * W * SizeOf(Integer)); Move(Halo_G^, HH_G^, Overlap * W * SizeOf(Integer)); Move(Halo_B^, HH_B^, Overlap * W * SizeOf(Integer)); Move(Halo_A^, HH_A^, Overlap * W * SizeOf(Integer)); NewRows := CH - Overlap; if NewRows > 0 then BuildHorzSumsRange(ASrc, ARadius, PrevCY1, NewRows, HH_R + Overlap * W, HH_G + Overlap * W, HH_B + Overlap * W, HH_A + Overlap * W); end
                  else if PrevHHBase <> nil then begin SrcOff := CY0 - PrevCY0; Move((PrevHHBase + SrcOff * W)^, HH_R^, Overlap * W * SizeOf(Integer)); Move((PrevHHBase + MaxCH * W + SrcOff * W)^, HH_G^, Overlap * W * SizeOf(Integer)); Move((PrevHHBase + MaxCH * W * 2 + SrcOff * W)^, HH_B^, Overlap * W * SizeOf(Integer)); Move((PrevHHBase + MaxCH * W * 3 + SrcOff * W)^, HH_A^, Overlap * W * SizeOf(Integer)); NewRows := CH - Overlap; if NewRows > 0 then BuildHorzSumsRange(ASrc, ARadius, PrevCY1, NewRows, HH_R + Overlap * W, HH_G + Overlap * W, HH_B + Overlap * W, HH_A + Overlap * W); end
                  else BuildHorzSumsRange(ASrc, ARadius, CY0, CH, HH_R, HH_G, HH_B, HH_A);
                end else BuildHorzSumsRange(ASrc, ARadius, CY0, CH, HH_R, HH_G, HH_B, HH_A);
              end else BuildHorzSumsRange(ASrc, ARadius, CY0, CH, HH_R, HH_G, HH_B, HH_A);
              Tasks[Batch].Y0 := Y0; Tasks[Batch].Y1 := Y1; Tasks[Batch].W := W; Tasks[Batch].H := H; Tasks[Batch].R := ARadius; Tasks[Batch].Dst := @Result; Tasks[Batch].HH_R := HH_R; Tasks[Batch].HH_G := HH_G; Tasks[Batch].HH_B := HH_B; Tasks[Batch].HH_A := HH_A;
              Tasks[Batch].CntH := CntH; Tasks[Batch].CntInv := CntInv; Tasks[Batch].VCInvTab := VCInvPtr; Tasks[Batch].VCInvLen := VCInvLen; Tasks[Batch].ChunkY0 := CY0; Tasks[Batch].ChunkH := CH;
              Tasks[Batch].VSumR := ScratchBase + J * W * 4; Tasks[Batch].VSumG := ScratchBase + J * W * 4 + W; Tasks[Batch].VSumB := ScratchBase + J * W * 4 + W * 2; Tasks[Batch].VSumA := ScratchBase + J * W * 4 + W * 3;
              if HaloBase <> nil then begin Ti := 2 * ARadius; if Ti > CH then Ti := CH; if Ti > 0 then begin Move((HH_R + (CH - Ti) * W)^, Halo_R^, Ti * W * SizeOf(Integer)); Move((HH_G + (CH - Ti) * W)^, Halo_G^, Ti * W * SizeOf(Integer)); Move((HH_B + (CH - Ti) * W)^, Halo_B^, Ti * W * SizeOf(Integer)); Move((HH_A + (CH - Ti) * W)^, Halo_A^, Ti * W * SizeOf(Integer)); end; end;
              PrevHHBase := HH_Base; PrevCY0 := CY0; PrevCY1 := CY1;
            end;
            for J := 0 to BatchCount - 1 do Pool.SubmitDirect(@Tasks[I + J], @BlurStripTaskProc);
            Pool.WaitAll;
            I += BatchCount;
          end;
        finally
          if HaloBase <> nil then FreeMem(HaloBase);
          HaloBase := nil;
          FreeMem(PersistBase);
          PersistBase := nil;
        end;
      end;
    finally
      if ScratchBase <> nil then FreeMem(ScratchBase);
      if CntInv <> nil then FreeMem(CntInv);
      if CntH <> nil then FreeMem(CntH);
      ScratchBase := nil; CntInv := nil; CntH := nil;
    end;
  end;
end;

function TEffectGraph.Bake(const ASrc: TBitmap): TBitmap;
var
  I, Y: Integer;
  Cur: TBitmap;
  H: Single;
begin
  if ASrc.IsEmpty then raise EEffectError.Create('nextpas.core.graphics.effect.graph.pas: TEffectGraph.Bake: src empty');
  Cur := ASrc.Clone;
  for I := 0 to High(FNodes) do
    case FNodes[I].Kind of
      ekBlur: Cur := BoxBlur(Cur, Trunc(FNodes[I].Radius));
      ekDropShadow: Cur := BoxBlur(Cur, Trunc(FNodes[I].Radius));
      ekHue:
        begin
          H := FNodes[I].HueShift;
          if Abs(H) > 0.5 then
          begin
            for Y := 0 to Cur.Height - 1 do
              RasterRotateRGB(Cur.RowPtr(Y), Cur.Width);
          end;
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
