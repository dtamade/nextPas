unit nextpas.core.simd.nn.winograd;

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

uses
  nextpas.core.simd.alloc;

// Winograd F(2x2, 3x3): computes 2x2 output from 4x4 input tile and 3x3 kernel
// Reduces multiplications from 36 to 16 per 2x2 output block
procedure WinogradConv2D_F2x2_K3x3(AInput, AKernel, AOutput: PSingle;
  AInputH, AInputW, ANumFilters, AInputC: SizeUInt);

implementation

uses
  nextpas.core.simd;

// Transform 4x4 input tile to Winograd domain: BT * d * B
procedure TransformInput4x4(ASrc: PSingle; ASrcStride: SizeUInt; ADst: PSingle);
var
  LT: array[0..15] of Single;
  LI: Integer;
  LS0, LS1, LS2, LS3: Single;
begin
  // BT = [[1,0,-1,0],[0,1,1,0],[0,-1,1,0],[0,1,0,-1]]
  // Apply BT row-wise
  for LI := 0 to 3 do
  begin
    LS0 := ASrc[LI * ASrcStride + 0];
    LS1 := ASrc[LI * ASrcStride + 1];
    LS2 := ASrc[LI * ASrcStride + 2];
    LS3 := ASrc[LI * ASrcStride + 3];
    LT[LI * 4 + 0] := LS0 - LS2;
    LT[LI * 4 + 1] := LS1 + LS2;
    LT[LI * 4 + 2] := LS2 - LS1;
    LT[LI * 4 + 3] := LS1 - LS3;
  end;
  // Apply B column-wise (transpose of BT)
  for LI := 0 to 3 do
  begin
    LS0 := LT[0 * 4 + LI];
    LS1 := LT[1 * 4 + LI];
    LS2 := LT[2 * 4 + LI];
    LS3 := LT[3 * 4 + LI];
    ADst[0 * 4 + LI] := LS0 - LS2;
    ADst[1 * 4 + LI] := LS1 + LS2;
    ADst[2 * 4 + LI] := LS2 - LS1;
    ADst[3 * 4 + LI] := LS1 - LS3;
  end;
end;

// Transform 3x3 kernel to Winograd domain: G * g * GT
procedure TransformKernel3x3(ASrc: PSingle; ADst: PSingle);
var
  LT: array[0..11] of Single;
  LI: Integer;
  LS0, LS1, LS2: Single;
begin
  // G = [[1,0,0],[0.5,0.5,0.5],[0.5,-0.5,0.5],[0,0,1]]
  for LI := 0 to 2 do
  begin
    LS0 := ASrc[LI * 3 + 0];
    LS1 := ASrc[LI * 3 + 1];
    LS2 := ASrc[LI * 3 + 2];
    LT[0 * 3 + LI] := LS0;
    LT[1 * 3 + LI] := 0.5 * (LS0 + LS1 + LS2);
    LT[2 * 3 + LI] := 0.5 * (LS0 - LS1 + LS2);
    LT[3 * 3 + LI] := LS2;
  end;
  // Apply GT column-wise
  for LI := 0 to 3 do
  begin
    LS0 := LT[LI * 3 + 0];
    LS1 := LT[LI * 3 + 1];
    LS2 := LT[LI * 3 + 2];
    ADst[LI * 4 + 0] := LS0;
    ADst[LI * 4 + 1] := 0.5 * (LS0 + LS1 + LS2);
    ADst[LI * 4 + 2] := 0.5 * (LS0 - LS1 + LS2);
    ADst[LI * 4 + 3] := LS2;
  end;
end;

// Inverse transform: AT * M * A (4x4 → 2x2 output)
procedure TransformOutput4x4(ASrc: PSingle; ADst: PSingle; ADstStride: SizeUInt);
var
  LT: array[0..7] of Single;
  LI: Integer;
  LS0, LS1, LS2, LS3: Single;
begin
  // AT = [[1,1,1,0],[0,1,-1,-1]]
  for LI := 0 to 3 do
  begin
    LS0 := ASrc[LI * 4 + 0];
    LS1 := ASrc[LI * 4 + 1];
    LS2 := ASrc[LI * 4 + 2];
    LS3 := ASrc[LI * 4 + 3];
    LT[0 * 4 + LI] := LS0 + LS1 + LS2;
    LT[1 * 4 + LI] := LS1 - LS2 - LS3;
  end;
  for LI := 0 to 1 do
  begin
    LS0 := LT[LI * 4 + 0];
    LS1 := LT[LI * 4 + 1];
    LS2 := LT[LI * 4 + 2];
    LS3 := LT[LI * 4 + 3];
    ADst[LI * ADstStride + 0] := LS0 + LS1 + LS2;
    ADst[LI * ADstStride + 1] := LS1 - LS2 - LS3;
  end;
end;

procedure WinogradConv2D_F2x2_K3x3(AInput, AKernel, AOutput: PSingle;
  AInputH, AInputW, ANumFilters, AInputC: SizeUInt);
var
  LOutputH, LOutputW: SizeUInt;
  LTileH, LTileW: SizeUInt;
  LNumTilesH, LNumTilesW, LNumTiles: SizeUInt;
  LF, LC, LTile, LTy, LTx, LI: SizeUInt;
  LInputTile: array[0..15] of Single;
  LKernelTrans: PSingle;
  LInputTrans, LM: array[0..15] of Single;
  LOutputTile: array[0..3] of Single;
  LOy, LOx: SizeUInt;
  LChannelSize: SizeUInt;
begin
  if (AInputH < 4) or (AInputW < 4) then Exit;

  LOutputH := AInputH - 2;
  LOutputW := AInputW - 2;
  LNumTilesH := (LOutputH + 1) div 2;
  LNumTilesW := (LOutputW + 1) div 2;
  LChannelSize := AInputH * AInputW;

  // Pre-transform all kernels
  LKernelTrans := PSingle(SimdAlloc(ANumFilters * AInputC * 16 * SizeOf(Single)));
  for LF := 0 to ANumFilters - 1 do
    for LC := 0 to AInputC - 1 do
      TransformKernel3x3(@AKernel[(LF * AInputC + LC) * 9],
        @LKernelTrans[(LF * AInputC + LC) * 16]);

  // Process each output tile
  FillChar(AOutput^, ANumFilters * LOutputH * LOutputW * SizeOf(Single), 0);

  for LTy := 0 to LNumTilesH - 1 do
    for LTx := 0 to LNumTilesW - 1 do
    begin
      LOy := LTy * 2;
      LOx := LTx * 2;

      for LF := 0 to ANumFilters - 1 do
      begin
        FillChar(LM, SizeOf(LM), 0);

        for LC := 0 to AInputC - 1 do
        begin
          // Extract 4x4 input tile
          for LI := 0 to 3 do
            Move(AInput[LC * LChannelSize + (LOy + LI) * AInputW + LOx],
                 LInputTile[LI * 4], 4 * SizeOf(Single));

          // Transform input
          TransformInput4x4(@LInputTile[0], 4, @LInputTrans[0]);

          // Element-wise multiply-accumulate in Winograd domain
          for LI := 0 to 15 do
            LM[LI] := LM[LI] + LInputTrans[LI] * LKernelTrans[(LF * AInputC + LC) * 16 + LI];
        end;

        // Inverse transform → 2x2 output
        TransformOutput4x4(@LM[0], @LOutputTile[0], 2);

        // Write output (clamp to valid region)
        if LOy < LOutputH then
        begin
          if LOx < LOutputW then
            AOutput[LF * LOutputH * LOutputW + LOy * LOutputW + LOx] := LOutputTile[0];
          if LOx + 1 < LOutputW then
            AOutput[LF * LOutputH * LOutputW + LOy * LOutputW + LOx + 1] := LOutputTile[1];
        end;
        if LOy + 1 < LOutputH then
        begin
          if LOx < LOutputW then
            AOutput[LF * LOutputH * LOutputW + (LOy+1) * LOutputW + LOx] := LOutputTile[2];
          if LOx + 1 < LOutputW then
            AOutput[LF * LOutputH * LOutputW + (LOy+1) * LOutputW + LOx + 1] := LOutputTile[3];
        end;
      end;
    end;

  SimdFree(LKernelTrans);
end;

end.
