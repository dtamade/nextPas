unit nextpas.core.tui.sixel;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.builder;

type
  TSixelPalette = array[0..255] of record R, G, B: Byte; end;
  TSixelIndices = array of Byte;

procedure EncodeSixelDCS(var Out_: nextpas.core.text.builder.TStringBuilder;
  Pixels: PByte; Width, Height: Integer; PaletteSize: Integer = 200);

implementation

uses
  SysUtils;

type
  TColorBox = record
    Pixels: array of Integer;
    Count: Integer;
    MinR, MaxR, MinG, MaxG, MinB, MaxB: Byte;
  end;

procedure ComputeBoxBounds(var Box: TColorBox; Src: PByte);
var
  I, Idx: Integer;
  R, G, B: Byte;
begin
  Box.MinR := 255; Box.MaxR := 0;
  Box.MinG := 255; Box.MaxG := 0;
  Box.MinB := 255; Box.MaxB := 0;
  for I := 0 to Box.Count - 1 do
  begin
    Idx := Box.Pixels[I];
    R := Src[Idx * 4];
    G := Src[Idx * 4 + 1];
    B := Src[Idx * 4 + 2];
    if R < Box.MinR then Box.MinR := R;
    if R > Box.MaxR then Box.MaxR := R;
    if G < Box.MinG then Box.MinG := G;
    if G > Box.MaxG then Box.MaxG := G;
    if B < Box.MinB then Box.MinB := B;
    if B > Box.MaxB then Box.MaxB := B;
  end;
end;

procedure MedianCutQuantize(Src: PByte; PixelCount: Integer;
  out Palette: TSixelPalette; out PalCount: Integer;
  var Indices: TSixelIndices; MaxColors: Integer);
var
  Boxes: array of TColorBox;
  BoxCount, I, J, SplitIdx: Integer;
  RangeR, RangeG, RangeB, MaxRange: Integer;
  Pivot: Byte;
  Left, Right: Integer;
  SumR, SumG, SumB: Int64;
  Idx: Integer;
  A: Byte;
begin
  SetLength(Boxes, MaxColors);
  BoxCount := 1;
  SetLength(Boxes[0].Pixels, PixelCount);
  Boxes[0].Count := 0;
  for I := 0 to PixelCount - 1 do
  begin
    A := Src[I * 4 + 3];
    if A > 128 then
    begin
      Boxes[0].Pixels[Boxes[0].Count] := I;
      Inc(Boxes[0].Count);
    end;
  end;
  if Boxes[0].Count = 0 then
  begin
    PalCount := 1;
    Palette[0].R := 0; Palette[0].G := 0; Palette[0].B := 0;
    FillChar(Indices[0], PixelCount, 0);
    Exit;
  end;
  SetLength(Boxes[0].Pixels, Boxes[0].Count);
  ComputeBoxBounds(Boxes[0], Src);

  while BoxCount < MaxColors do
  begin
    SplitIdx := -1;
    MaxRange := 0;
    for I := 0 to BoxCount - 1 do
    begin
      if Boxes[I].Count < 2 then Continue;
      RangeR := Boxes[I].MaxR - Boxes[I].MinR;
      RangeG := Boxes[I].MaxG - Boxes[I].MinG;
      RangeB := Boxes[I].MaxB - Boxes[I].MinB;
      if RangeR >= RangeG then
      begin
        if RangeR >= RangeB then J := RangeR else J := RangeB;
      end else
      begin
        if RangeG >= RangeB then J := RangeG else J := RangeB;
      end;
      if J > MaxRange then
      begin
        MaxRange := J;
        SplitIdx := I;
      end;
    end;
    if SplitIdx < 0 then Break;

    RangeR := Boxes[SplitIdx].MaxR - Boxes[SplitIdx].MinR;
    RangeG := Boxes[SplitIdx].MaxG - Boxes[SplitIdx].MinG;
    RangeB := Boxes[SplitIdx].MaxB - Boxes[SplitIdx].MinB;

    if (RangeR >= RangeG) and (RangeR >= RangeB) then
      Pivot := (Boxes[SplitIdx].MinR + Boxes[SplitIdx].MaxR) div 2
    else if RangeG >= RangeB then
      Pivot := (Boxes[SplitIdx].MinG + Boxes[SplitIdx].MaxG) div 2
    else
      Pivot := (Boxes[SplitIdx].MinB + Boxes[SplitIdx].MaxB) div 2;

    SetLength(Boxes[BoxCount].Pixels, Boxes[SplitIdx].Count);
    Boxes[BoxCount].Count := 0;
    Left := 0;
    for I := 0 to Boxes[SplitIdx].Count - 1 do
    begin
      Idx := Boxes[SplitIdx].Pixels[I];
      if (RangeR >= RangeG) and (RangeR >= RangeB) then
        A := Src[Idx * 4]
      else if RangeG >= RangeB then
        A := Src[Idx * 4 + 1]
      else
        A := Src[Idx * 4 + 2];

      if A <= Pivot then
      begin
        Boxes[SplitIdx].Pixels[Left] := Idx;
        Inc(Left);
      end
      else
      begin
        Boxes[BoxCount].Pixels[Boxes[BoxCount].Count] := Idx;
        Inc(Boxes[BoxCount].Count);
      end;
    end;

    if (Left = 0) or (Boxes[BoxCount].Count = 0) then Break;

    Boxes[SplitIdx].Count := Left;
    SetLength(Boxes[SplitIdx].Pixels, Left);
    SetLength(Boxes[BoxCount].Pixels, Boxes[BoxCount].Count);
    ComputeBoxBounds(Boxes[SplitIdx], Src);
    ComputeBoxBounds(Boxes[BoxCount], Src);
    Inc(BoxCount);
  end;

  PalCount := BoxCount;
  for I := 0 to BoxCount - 1 do
  begin
    SumR := 0; SumG := 0; SumB := 0;
    for J := 0 to Boxes[I].Count - 1 do
    begin
      Idx := Boxes[I].Pixels[J];
      Inc(SumR, Src[Idx * 4]);
      Inc(SumG, Src[Idx * 4 + 1]);
      Inc(SumB, Src[Idx * 4 + 2]);
    end;
    Palette[I].R := Byte(SumR div Boxes[I].Count);
    Palette[I].G := Byte(SumG div Boxes[I].Count);
    Palette[I].B := Byte(SumB div Boxes[I].Count);
    for J := 0 to Boxes[I].Count - 1 do
      Indices[Boxes[I].Pixels[J]] := Byte(I);
  end;

  for I := 0 to PixelCount - 1 do
    if Src[I * 4 + 3] <= 128 then
      Indices[I] := 0;
end;

procedure EncodeSixelDCS(var Out_: nextpas.core.text.builder.TStringBuilder;
  Pixels: PByte; Width, Height: Integer; PaletteSize: Integer);
var
  Palette: TSixelPalette;
  PalCount: Integer;
  Indices: TSixelIndices;
  I, X, Band, Bit, Y, BandCount: Integer;
  SixelByte: Byte;
  LastChar: Byte;
  RunLen: Integer;
  Header: AnsiString;
begin
  SetLength(Indices, Width * Height);
  MedianCutQuantize(Pixels, Width * Height, Palette, PalCount, Indices, PaletteSize);

  Out_.AppendByte(Ord(#27));
  Out_.AppendByte(Ord('P'));
  Out_.AppendStr('0;0;0q');
  Header := Format('"1;1;%d;%d', [Width, Height]);
  Out_.AppendStr(Header);

  for I := 0 to PalCount - 1 do
  begin
    Header := Format('#%d;2;%d;%d;%d', [I,
      Palette[I].R * 100 div 255,
      Palette[I].G * 100 div 255,
      Palette[I].B * 100 div 255]);
    Out_.AppendStr(Header);
  end;

  BandCount := (Height + 5) div 6;
  for Band := 0 to BandCount - 1 do
  begin
    for I := 0 to PalCount - 1 do
    begin
      Header := Format('#%d', [I]);
      Out_.AppendStr(Header);

      LastChar := 255;
      RunLen := 0;
      for X := 0 to Width - 1 do
      begin
        SixelByte := 0;
        for Bit := 0 to 5 do
        begin
          Y := Band * 6 + Bit;
          if (Y < Height) and (Indices[Y * Width + X] = I) then
            SixelByte := SixelByte or (1 shl Bit);
        end;
        SixelByte := SixelByte + 63;

        if SixelByte = LastChar then
          Inc(RunLen)
        else
        begin
          if RunLen > 0 then
          begin
            if RunLen >= 4 then
            begin
              Out_.AppendByte(Ord('!'));
              Out_.AppendUInt(LongWord(RunLen));
              Out_.AppendByte(LastChar);
            end
            else
              for Bit := 0 to RunLen - 1 do
                Out_.AppendByte(LastChar);
          end;
          LastChar := SixelByte;
          RunLen := 1;
        end;
      end;
      if RunLen > 0 then
      begin
        if RunLen >= 4 then
        begin
          Out_.AppendByte(Ord('!'));
          Out_.AppendUInt(LongWord(RunLen));
          Out_.AppendByte(LastChar);
        end
        else
          for Bit := 0 to RunLen - 1 do
            Out_.AppendByte(LastChar);
      end;
      Out_.AppendByte(Ord('$'));
    end;
    if Band < BandCount - 1 then
      Out_.AppendByte(Ord('-'));
  end;

  Out_.AppendByte(Ord(#27));
  Out_.AppendByte(Ord('\'));
end;

end.
