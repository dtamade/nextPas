{**
 * nextpas.core.graphics.effect.graph - 滤镜图（Blur/Shadow/Hue/LUT，序列化，Bake tile并行）
 * L2，零 RTL，arena+AlignUp，tile halo 真并行，bytes.binary 复用。
 * 优化：Horz 全局预计算消除 per-tile halo 重复(O(W*H))，HH+CntH+CntInv 同 arena
 * (16B 对齐，NeedHH≈256MB@16M)，Scratch 经 GetMem 另分配按 WorkerCount 限界
 * 降低单 Arena 峰值；纵向 8-wide 纯 Pascal 累加+倒数乘法(每行 1div 求 VCInv，
 * 每像素 InvTotal=CntInv*VCInv>>32+ 1 次校正替代 4 次 div)，自适应 Tile≥4R。
 *}
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
  private
    FNodes: array of TEffectNode;
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

procedure BlurStripVertical(const HH_R, HH_G, HH_B, HH_A: PInteger; CntH: PInteger; CntInv: PCardinal; AW, AH, AR, AY0, AY1: Integer; var ADst: TBitmap; VSumR, VSumG, VSumB, VSumA: PInteger);
var
  X, Y, YRem, YAdd, VC, Total: Integer;
  VCInv, InvTotal: Cardinal;
  qR, qG, qB, qA: Cardinal;
  DstRow: PByte;
  RowPtr: PInteger;
begin
  if (AY0 >= AY1) or (AW <= 0) or (AH <= 0) then Exit;
  if (VSumR = nil) or (VSumG = nil) or (VSumB = nil) or (VSumA = nil) then Exit;
  for X := 0 to AW - 1 do
  begin
    VSumR[X] := 0; VSumG[X] := 0; VSumB[X] := 0; VSumA[X] := 0;
  end;
  for Y := AY0 - AR to AY0 + AR do if (Y >= 0) and (Y < AH) then
  begin
    RowPtr := HH_R + Y * AW; VecAddI32(VSumR, RowPtr, AW);
    RowPtr := HH_G + Y * AW; VecAddI32(VSumG, RowPtr, AW);
    RowPtr := HH_B + Y * AW; VecAddI32(VSumB, RowPtr, AW);
    RowPtr := HH_A + Y * AW; VecAddI32(VSumA, RowPtr, AW);
  end;
  for Y := AY0 to AY1 - 1 do
  begin
    VC := VertCount(Y, AH, AR);
    DstRow := ADst.RowPtr(Y);
    if VC <= 0 then
    begin
      for X := 0 to AW - 1 do
      begin
        DstRow[X * 4] := 0; DstRow[X * 4 + 1] := 0; DstRow[X * 4 + 2] := 0; DstRow[X * 4 + 3] := 0;
      end;
    end
    else
    begin
      VCInv := Cardinal((QWord(1) shl 32) div QWord(Cardinal(VC)));
      for X := 0 to AW - 1 do
      begin
        Total := CntH[X] * VC;
        if Total = 0 then
        begin
          DstRow[X * 4] := 0; DstRow[X * 4 + 1] := 0; DstRow[X * 4 + 2] := 0; DstRow[X * 4 + 3] := 0;
        end
        else
        begin
          InvTotal := Cardinal((QWord(CntInv[X]) * QWord(VCInv)) shr 32);
          if InvTotal = 0 then InvTotal := Cardinal((QWord(1) shl 32) div QWord(Cardinal(Total)));
          qR := Cardinal((QWord(Cardinal(VSumR[X])) * QWord(InvTotal)) shr 32);
          if QWord(qR) * QWord(Cardinal(Total)) > QWord(Cardinal(VSumR[X])) then Dec(qR)
          else if QWord(qR + 1) * QWord(Cardinal(Total)) <= QWord(Cardinal(VSumR[X])) then Inc(qR);
          qG := Cardinal((QWord(Cardinal(VSumG[X])) * QWord(InvTotal)) shr 32);
          if QWord(qG) * QWord(Cardinal(Total)) > QWord(Cardinal(VSumG[X])) then Dec(qG)
          else if QWord(qG + 1) * QWord(Cardinal(Total)) <= QWord(Cardinal(VSumG[X])) then Inc(qG);
          qB := Cardinal((QWord(Cardinal(VSumB[X])) * QWord(InvTotal)) shr 32);
          if QWord(qB) * QWord(Cardinal(Total)) > QWord(Cardinal(VSumB[X])) then Dec(qB)
          else if QWord(qB + 1) * QWord(Cardinal(Total)) <= QWord(Cardinal(VSumB[X])) then Inc(qB);
          qA := Cardinal((QWord(Cardinal(VSumA[X])) * QWord(InvTotal)) shr 32);
          if QWord(qA) * QWord(Cardinal(Total)) > QWord(Cardinal(VSumA[X])) then Dec(qA)
          else if QWord(qA + 1) * QWord(Cardinal(Total)) <= QWord(Cardinal(VSumA[X])) then Inc(qA);
          if qR > 255 then qR := 255; if qG > 255 then qG := 255; if qB > 255 then qB := 255; if qA > 255 then qA := 255;
          DstRow[X * 4] := Byte(qR);
          DstRow[X * 4 + 1] := Byte(qG);
          DstRow[X * 4 + 2] := Byte(qB);
          DstRow[X * 4 + 3] := Byte(qA);
        end;
      end;
    end;
    if Y = AY1 - 1 then Break;
    YRem := Y - AR;
    YAdd := Y + AR + 1;
    if (YRem >= 0) and (YRem < AH) then
    begin
      RowPtr := HH_R + YRem * AW; VecSubI32(VSumR, RowPtr, AW);
      RowPtr := HH_G + YRem * AW; VecSubI32(VSumG, RowPtr, AW);
      RowPtr := HH_B + YRem * AW; VecSubI32(VSumB, RowPtr, AW);
      RowPtr := HH_A + YRem * AW; VecSubI32(VSumA, RowPtr, AW);
    end;
    if (YAdd >= 0) and (YAdd < AH) then
    begin
      RowPtr := HH_R + YAdd * AW; VecAddI32(VSumR, RowPtr, AW);
      RowPtr := HH_G + YAdd * AW; VecAddI32(VSumG, RowPtr, AW);
      RowPtr := HH_B + YAdd * AW; VecAddI32(VSumB, RowPtr, AW);
      RowPtr := HH_A + YAdd * AW; VecAddI32(VSumA, RowPtr, AW);
    end;
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
    VSumR, VSumG, VSumB, VSumA: PInteger;
  end;

procedure BlurStripTaskProc(AData: Pointer);
var
  T: PBlurStripTask;
begin
  T := PBlurStripTask(AData);
  BlurStripVertical(T^.HH_R, T^.HH_G, T^.HH_B, T^.HH_A, T^.CntH, T^.CntInv, T^.W, T^.H, T^.R, T^.Y0, T^.Y1, T^.Dst^, T^.VSumR, T^.VSumG, T^.VSumB, T^.VSumA);
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
  W, H, I, Y0, Y1, NumStrips, Tile, NumWorkers: Integer;
  Pool: IThreadPool;
  UseParallel: Boolean;
  Arena: IArena;
  HH_Base, HH_R, HH_G, HH_B, HH_A, CntH: PInteger;
  CntInv: PCardinal;
  ScratchBase: PInteger;
  NeedHH, ScratchBytes: SizeUInt;
  Tasks: array of TBlurStripTask;
  VSumR, VSumG, VSumB, VSumA: PInteger;
begin
  if ASrc.IsEmpty then raise EEffectError.Create('nextpas.core.graphics.effect.graph.pas: BoxBlur: src empty');
  if ASrc.Width * ASrc.Height > 16 * 1024 * 1024 then raise EEffectError.Create('nextpas.core.graphics.effect.graph.pas: BoxBlur: image too large (limit 16M pixels, got ' + IntToStr(Int64(ASrc.Width) * Int64(ASrc.Height)) + ' W=' + IntToStr(ASrc.Width) + ' H=' + IntToStr(ASrc.Height) + ' radius=' + IntToStr(ARadius) + ')');
  if ARadius <= 0 then Exit(ASrc);
  W := ASrc.Width; H := ASrc.Height;
  Result := TBitmap.Create(W, H, ASrc.Format);
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
    Tile := 64;
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
    ScratchBytes := SizeUInt(NumWorkers) * SizeUInt(W) * 4 * SizeOf(Integer);
  end
  else
  begin
    NumWorkers := 1;
    ScratchBytes := SizeUInt(W) * 4 * SizeOf(Integer);
  end;
  NeedHH := AlignUp(SizeUInt(H) * SizeUInt(W) * 4 * SizeOf(Integer) + SizeUInt(W) * SizeOf(Integer) + SizeUInt(W) * SizeOf(Cardinal) + 16, 16);
  if NeedHH = 0 then NeedHH := 16;
  Arena := TLocalArena.Create(NeedHH);
  HH_Base := PInteger(Arena.AllocAligned(SizeUInt(H) * SizeUInt(W) * 4 * SizeOf(Integer), 16));
  if HH_Base = nil then raise EEffectError.Create('nextpas.core.graphics.effect.graph.pas: BoxBlur: arena alloc failed (need=' + IntToStr(Int64(H) * Int64(W) * 4 * SizeOf(Integer)) + ' W=' + IntToStr(W) + ' H=' + IntToStr(H) + ' radius=' + IntToStr(ARadius) + ')');
  HH_R := HH_Base;
  HH_G := HH_Base + H * W;
  HH_B := HH_Base + H * W * 2;
  HH_A := HH_Base + H * W * 3;
  CntH := PInteger(Arena.AllocAligned(SizeUInt(W) * SizeOf(Integer), 16));
  CntInv := PCardinal(Arena.AllocAligned(SizeUInt(W) * SizeOf(Cardinal), 16));
  if (CntH = nil) or (CntInv = nil) then raise EEffectError.Create('nextpas.core.graphics.effect.graph.pas: BoxBlur: arena alloc failed (cnt=' + IntToStr(Int64(W) * SizeOf(Integer)) + ' W=' + IntToStr(W) + ' H=' + IntToStr(H) + ' radius=' + IntToStr(ARadius) + ')');
  GetMem(ScratchBase, ScratchBytes);
  if ScratchBase = nil then raise EEffectError.Create('nextpas.core.graphics.effect.graph.pas: BoxBlur: scratch alloc failed (scratch=' + IntToStr(Int64(ScratchBytes)) + ' W=' + IntToStr(W) + ' H=' + IntToStr(H) + ' radius=' + IntToStr(ARadius) + ')');
  try
    BuildHorzSums(ASrc, ARadius, HH_R, HH_G, HH_B, HH_A);
    BuildCntHAndInv(CntH, CntInv, W, ARadius);
    if UseParallel then
    begin
      SetLength(Tasks, NumStrips);
      for I := 0 to NumStrips - 1 do
      begin
        Y0 := I * Tile; Y1 := Y0 + Tile; if Y1 > H then Y1 := H;
        Tasks[I].Y0 := Y0; Tasks[I].Y1 := Y1; Tasks[I].W := W; Tasks[I].H := H; Tasks[I].R := ARadius;
        Tasks[I].Dst := @Result;
        Tasks[I].HH_R := HH_R; Tasks[I].HH_G := HH_G; Tasks[I].HH_B := HH_B; Tasks[I].HH_A := HH_A;
        Tasks[I].CntH := CntH;
        Tasks[I].CntInv := CntInv;
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
      VSumR := ScratchBase;
      VSumG := ScratchBase + W;
      VSumB := ScratchBase + W * 2;
      VSumA := ScratchBase + W * 3;
      BlurStripVertical(HH_R, HH_G, HH_B, HH_A, CntH, CntInv, W, H, ARadius, 0, H, Result, VSumR, VSumG, VSumB, VSumA);
    end;
  finally
    FreeMem(ScratchBase);
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
