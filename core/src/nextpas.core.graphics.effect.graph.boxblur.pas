{**
 * nextpas.core.graphics.effect.graph.boxblur - BoxBlur arena+tile
 *}
unit nextpas.core.graphics.effect.graph.boxblur;

{$I nextpas.core.settings.inc}
{$POINTERMATH ON}
{$modeswitch advancedrecords}

interface

uses
  nextpas.core.base,
  nextpas.core.graphics.base,
  nextpas.core.graphics.effect.graph.base,
  nextpas.core.image.base;

function BoxBlur(const ASrc: TBitmap; ARadius: Integer): TBitmap;

implementation

uses
  nextpas.core.errors,
  nextpas.core.graphics.errors,
  nextpas.core.simd.base,
  nextpas.core.simd.inline,
  nextpas.core.simd.raster,
  nextpas.core.thread.pool,
  nextpas.core.thread.intf,
  nextpas.core.mem.base,
  nextpas.core.mem.arena,
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
  I: Integer;
  D, S: PInteger;
  VDst, VSrc: ^TVecI32x4;
begin
  if (ADst = nil) or (ASrc = nil) or (N <= 0) then Exit;
  D := ADst; S := ASrc;
  while N >= 4 do
  begin
    VDst := Pointer(D);
    VSrc := Pointer(S);
    VDst^ := InlineVecI32x4Add(VDst^, VSrc^);
    Inc(D, 4); Inc(S, 4); Dec(N, 4);
  end;
  for I := 0 to N - 1 do D[I] += S[I];
end;

procedure VecSubI32(ADst, ASrc: PInteger; N: Integer); inline;
var
  I: Integer;
  D, S: PInteger;
  VDst, VSrc: ^TVecI32x4;
begin
  if (ADst = nil) or (ASrc = nil) or (N <= 0) then Exit;
  D := ADst; S := ASrc;
  while N >= 4 do
  begin
    VDst := Pointer(D);
    VSrc := Pointer(S);
    VDst^ := InlineVecI32x4Sub(VDst^, VSrc^);
    Inc(D, 4); Inc(S, 4); Dec(N, 4);
  end;
  for I := 0 to N - 1 do D[I] -= S[I];
end;

procedure BuildHorzSums(const ASrc: TBitmap; AR: Integer; HH_R, HH_G, HH_B, HH_A: PInteger);
var
  Y, W, H: Integer;
  SrcRow: PByte;
begin
  W := ASrc.Width; H := ASrc.Height;
  for Y := 0 to H - 1 do
  begin
    SrcRow := ASrc.ConstRowPtr(Y);
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
    SrcRow := ASrc.ConstRowPtr(AY0 + Y);
    HorzRowInto(SrcRow, W, AR, HH_R + Y * W, HH_G + Y * W, HH_B + Y * W, HH_A + Y * W);
  end;
end;

procedure HorzTaskProc(AData: Pointer);
var T: PHorzTask; Y: Integer; Row: PByte;
begin
  T := PHorzTask(AData);
  for Y := T^.Y0 to T^.Y1 - 1 do
  begin
    Row := T^.Src^.ConstRowPtr(Y);
    HorzRowInto(Row, T^.W, T^.R, T^.HH_R + Y * T^.W, T^.HH_G + Y * T^.W, T^.HH_B + Y * T^.W, T^.HH_A + Y * T^.W);
  end;
end;

procedure BlurStripVerticalChunked(const HH_R, HH_G, HH_B, HH_A: PInteger; ChunkY0, ChunkH, AW, AH, AR, AY0, AY1: Integer; var ADst: TBitmap; VSumR, VSumG, VSumB, VSumA: PInteger; CntH: PInteger; CntInv: PCardinal; VCInvTab: PCardinal; VCInvLen: Integer);
var
  X, Y, YRem, YAdd, VC: Integer;
  VCInv: Cardinal;
  DstRow: PByte;
  RowPtr: PInteger;
  DstBase: PByte;
  DstStride: Integer;
begin
  if (AY0 >= AY1) or (AW <= 0) or (AH <= 0) then Exit;
  if (VSumR = nil) or (VSumG = nil) or (VSumB = nil) or (VSumA = nil) then Exit;
  if (VCInvTab = nil) or (VCInvLen <= 0) then Exit;
  if ADst.IsEmpty then Exit;
  ADst.EnsureUnique;
  DstBase := ADst.UnsafeMutableRowPtr(0);
  DstStride := ADst.Stride;
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
    DstRow := DstBase + Y * DstStride;
    if VC <= 0 then VCInv := 0
    else if (VC >= 0) and (VC < VCInvLen) then VCInv := VCInvTab[VC]
    else VCInv := Cardinal((QWord(1) shl 32) div QWord(Cardinal(VC)));
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
  if ASrc.IsEmpty then raise EEffectError.Create('nextpas.core.graphics.effect.graph.boxblur.pas: BoxBlur: src empty');
  if ASrc.Width * ASrc.Height > BOXBLUR_MAX_PIXELS then raise EEffectError.Create('nextpas.core.graphics.effect.graph.boxblur.pas: BoxBlur: image too large (limit 16M pixels, got ' + IntToStr(Int64(ASrc.Width) * Int64(ASrc.Height)) + ' W=' + IntToStr(ASrc.Width) + ' H=' + IntToStr(ASrc.Height) + ' radius=' + IntToStr(ARadius) + ')');
  if ARadius <= 0 then Exit(ASrc);
  W := ASrc.Width; H := ASrc.Height;
  Result := TBitmap.Create(W, H, ASrc.Format);
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
    Arena := TLocalArena.Create(NeedHH);
    HH_Base := PInteger(Arena.AllocAligned(SizeUInt(H) * SizeUInt(W) * 4 * SizeOf(Integer), BOXBLUR_ALIGN));
    if HH_Base = nil then raise EEffectError.Create('nextpas.core.graphics.effect.graph.boxblur.pas: BoxBlur: arena alloc failed (need=' + IntToStr(Int64(H) * Int64(W) * 4 * SizeOf(Integer)) + ' W=' + IntToStr(W) + ' H=' + IntToStr(H) + ' radius=' + IntToStr(ARadius) + ')');
    HH_R := HH_Base;
    HH_G := HH_Base + H * W;
    HH_B := HH_Base + H * W * 2;
    HH_A := HH_Base + H * W * 3;
    CntH := PInteger(Arena.AllocAligned(SizeUInt(W) * SizeOf(Integer), BOXBLUR_ALIGN));
    CntInv := PCardinal(Arena.AllocAligned(SizeUInt(W) * SizeOf(Cardinal), BOXBLUR_ALIGN));
    if (CntH = nil) or (CntInv = nil) then raise EEffectError.Create('nextpas.core.graphics.effect.graph.boxblur.pas: BoxBlur: arena alloc failed (cnt=' + IntToStr(Int64(W) * SizeOf(Integer)) + ' W=' + IntToStr(W) + ' H=' + IntToStr(H) + ' radius=' + IntToStr(ARadius) + ')');
    GetMem(ScratchBase, ScratchBytes);
    if ScratchBase = nil then raise EEffectError.Create('nextpas.core.graphics.effect.graph.boxblur.pas: BoxBlur: scratch alloc failed (scratch=' + IntToStr(Int64(ScratchBytes)) + ' W=' + IntToStr(W) + ' H=' + IntToStr(H) + ' radius=' + IntToStr(ARadius) + ')');
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
    try
      GetMem(CntH, AlignUp(SizeUInt(W) * SizeOf(Integer), BOXBLUR_ALIGN));
      if CntH = nil then raise EEffectError.Create('nextpas.core.graphics.effect.graph.boxblur.pas: BoxBlur: cnt alloc failed (W=' + IntToStr(W) + ')');
      GetMem(CntInv, AlignUp(SizeUInt(W) * SizeOf(Cardinal), BOXBLUR_ALIGN));
      if CntInv = nil then raise EEffectError.Create('nextpas.core.graphics.effect.graph.boxblur.pas: BoxBlur: cntinv alloc failed (W=' + IntToStr(W) + ')');
      GetMem(ScratchBase, ScratchBytes);
      if ScratchBase = nil then raise EEffectError.Create('nextpas.core.graphics.effect.graph.boxblur.pas: BoxBlur: scratch alloc failed (scratch=' + IntToStr(Int64(ScratchBytes)) + ')');
      BuildCntHAndInv(CntH, CntInv, W, ARadius);
      if not UseParallel then
      begin
        MaxCH := Tile + 2 * ARadius;
        if MaxCH > H then MaxCH := H;
        if MaxCH < 1 then MaxCH := 1;
        ChunkBytes := AlignUp(SizeUInt(MaxCH) * SizeUInt(W) * 4 * SizeOf(Integer), BOXBLUR_ALIGN);
        GetMem(HH_Base, ChunkBytes);
        if HH_Base = nil then raise EEffectError.Create('nextpas.core.graphics.effect.graph.boxblur.pas: BoxBlur: chunk alloc failed (need=' + IntToStr(Int64(ChunkBytes)) + ')');
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
        ChunkBytes := AlignUp(SizeUInt(MaxCH) * SizeUInt(W) * 4 * SizeOf(Integer), BOXBLUR_ALIGN);
        PersistBytes := AlignUp(ChunkBytes * SizeUInt(NumWorkers), BOXBLUR_ALIGN);
        GetMem(PersistBase, PersistBytes);
        if PersistBase = nil then raise EEffectError.Create('nextpas.core.graphics.effect.graph.boxblur.pas: BoxBlur: chunk alloc failed (persist=' + IntToStr(Int64(PersistBytes)) + ')');
        HaloBytes := 0; HaloBase := nil; PrevHHBase := nil;
        if (ARadius > 0) and (W > 0) then
        begin
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

end.
