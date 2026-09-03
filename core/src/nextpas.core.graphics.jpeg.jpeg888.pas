{**
 * nextpas.core.graphics.jpeg.jpeg888 - JPEG 纯Pas基线（DCT/Huffman Baseline, 复用 simd）
 * Baseline DCT sequential 8-bit, 1/3 分量, Huffman, SOI/SOF0/DQT/DHT/SOS/EOI,
 * 支持 4:4:4/4:2:0 采样，YCbCr→RGBA 复用 simd VecF32x4，零拷贝 Move 复用 bytes.ops。
 * 单文件 ≤600 行，L2 仅 L0-L1，无 FFI。
 *}
unit nextpas.core.graphics.jpeg.jpeg888;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

function JpegPureProbe(const AData: TBytes): Boolean; inline;
function JpegPureDecodeRgba(const AData: TBytes; out AWidth, AHeight: Integer): TBytes;

implementation

uses
  nextpas.core.errors,
  nextpas.core.graphics.errors,
  nextpas.core.bytes.ops,
  nextpas.core.simd;

const
  JPEG_MAX_DIM = 16384;
  JPEG_MAX_PIXELS = 16 * 1024 * 1024;
  ZIGZAG: array[0..63] of Byte = (
     0, 1, 8,16, 9, 2, 3,10,
    17,24,32,25,18,11, 4, 5,
    12,19,26,33,40,48,41,34,
    27,20,13, 6, 7,14,21,28,
    35,42,49,56,57,50,43,36,
    29,22,15,23,30,37,44,51,
    58,59,52,45,38,31,39,46,
    53,60,61,54,47,55,62,63);

type
  TQuantTab = array[0..63] of Integer;
  THuffTab = record
    Valid: Boolean;
    MinCode: array[1..16] of Integer;
    MaxCode: array[1..16] of Integer;
    ValPtr: array[1..16] of Integer;
    Values: array[0..255] of Byte;
  end;
  TCompInfo = record
    Id: Byte;
    H, V: Byte;
    QId: Byte;
    DcTbl, AcTbl: Byte;
  end;
  TBitReader = record
    Data: PByte;
    Len: Integer;
    Pos: Integer;
    Buf: Cardinal;
    Bits: Integer;
  end;

function ClampByte(I: Integer): Byte; inline;
begin
  if I < 0 then Exit(0);
  if I > 255 then Exit(255);
  Result := Byte(I);
end;

function BE16(P: PByte): Word; inline;
begin
  Result := (Word(P[0]) shl 8) or Word(P[1]);
end;

procedure BuildHuff(ACnt: PByte; ACntLen: Integer; ASym: PByte; ASymLen: Integer; out HT: THuffTab);
var
  I, Code, K, P: Integer;
begin
  FillChar(HT, SizeOf(HT), 0);
  for I := 0 to ASymLen - 1 do HT.Values[I] := ASym[I];
  Code := 0; P := 0;
  for I := 1 to 16 do
  begin
    if I <= ACntLen then K := ACnt[I-1] else K := 0;
    if K = 0 then
    begin
      HT.MinCode[I] := -1; HT.MaxCode[I] := -1;
    end
    else
    begin
      HT.ValPtr[I] := P;
      HT.MinCode[I] := Code;
      HT.MaxCode[I] := Code + K - 1;
      Inc(P, K);
      Code := Code + K;
    end;
    Code := Code shl 1;
  end;
  HT.Valid := True;
end;

procedure BrInit(var BR: TBitReader; AData: PByte; ALen, APos: Integer); inline;
begin
  BR.Data := AData; BR.Len := ALen; BR.Pos := APos; BR.Buf := 0; BR.Bits := 0;
end;

function BrEnsure(var BR: TBitReader; Need: Integer): Boolean; inline;
var
  B: Integer;
begin
  while BR.Bits < Need do
  begin
    if BR.Pos >= BR.Len then Exit(False);
    B := BR.Data[BR.Pos]; Inc(BR.Pos);
    if B = $FF then
    begin
      if BR.Pos < BR.Len then
      begin
        if BR.Data[BR.Pos] = $00 then Inc(BR.Pos)
        else if BR.Data[BR.Pos] = $D9 then Exit(False)
        else if (BR.Data[BR.Pos] >= $D0) and (BR.Data[BR.Pos] <= $D7) then Inc(BR.Pos)
        else Exit(False);
      end;
    end;
    BR.Buf := (BR.Buf shl 8) or Cardinal(B);
    Inc(BR.Bits, 8);
  end;
  Result := True;
end;

function BrPeek(const BR: TBitReader; N: Integer): Integer; inline;
begin
  Result := Integer((BR.Buf shr (BR.Bits - N)) and ((1 shl N)-1));
end;

procedure BrSkip(var BR: TBitReader; N: Integer); inline;
begin
  Dec(BR.Bits, N);
  if BR.Bits > 0 then BR.Buf := BR.Buf and ((1 shl BR.Bits)-1) else BR.Buf := 0;
end;

function BrGetBits(var BR: TBitReader; N: Integer; out V: Integer): Boolean; inline;
begin
  if N = 0 then begin V := 0; Exit(True); end;
  if not BrEnsure(BR, N) then Exit(False);
  V := BrPeek(BR, N);
  BrSkip(BR, N);
  Result := True;
end;

function HuffDecode(var BR: TBitReader; const HT: THuffTab; out Sym: Integer): Boolean;
var
  I, Code: Integer;
begin
  Result := False;
  for I := 1 to 16 do
  begin
    if HT.MinCode[I] = -1 then Continue;
    if not BrEnsure(BR, I) then Exit(False);
    Code := BrPeek(BR, I);
    if (Code >= HT.MinCode[I]) and (Code <= HT.MaxCode[I]) then
    begin
      BrSkip(BR, I);
      Sym := HT.Values[HT.ValPtr[I] + (Code - HT.MinCode[I])];
      Exit(True);
    end;
  end;
end;

function ReceiveExtend(V, Sz: Integer): Integer; inline;
begin
  if Sz = 0 then Exit(0);
  if V < (1 shl (Sz-1)) then Result := V - (1 shl Sz) + 1 else Result := V;
end;

procedure Idct8x8(const Coef: TQuantTab; out Block: TQuantTab);
var
  Tmp: array[0..63] of Single;
  X, Y, U, V: Integer;
  S, Cu, Cv: Single;
  I: Integer;
begin
  for Y := 0 to 7 do
    for X := 0 to 7 do
    begin
      S := 0;
      for V := 0 to 7 do
        for U := 0 to 7 do
        begin
          if Coef[V*8+U] = 0 then Continue;
          if U = 0 then Cu := 0.70710678 else Cu := 1;
          if V = 0 then Cv := 0.70710678 else Cv := 1;
          S := S + Cu*Cv*Coef[V*8+U]*Cos((2*X+1)*U*3.14159265/16)*Cos((2*Y+1)*V*3.14159265/16);
        end;
      Tmp[Y*8+X] := S * 0.25 + 128;
    end;
  for I := 0 to 63 do
  begin
    if Tmp[I] < 0 then Block[I] := 0
    else if Tmp[I] > 255 then Block[I] := 255
    else Block[I] := Trunc(Tmp[I]);
  end;
end;

function JpegPureProbe(const AData: TBytes): Boolean;
begin
  Result := (Length(AData) >= 2) and (AData[0] = $FF) and (AData[1] = $D8);
end;

function JpegPureDecodeRgba(const AData: TBytes; out AWidth, AHeight: Integer): TBytes;
var
  Pos, Mk, Len, I, J, K, C, NumComp, SawSOF0, SosNum: Integer;
  W, H, MaxH, MaxV, McuW, McuH, McuCountX, McuCountY: Integer;
  Qtabs: array[0..3] of TQuantTab;
  QValid: array[0..3] of Boolean;
  DcTabs: array[0..3] of THuffTab;
  AcTabs: array[0..3] of THuffTab;
  Comps: array[0..3] of TCompInfo;
  SosIdx: array[0..3] of Integer;
  BR: TBitReader;
  OutPixels: TBytes;
  DcPred: array[0..3] of Integer;
  YCbCrBuf: TBytes;
  B: Byte;
  Coef, Block: TQuantTab;
  DcSym, AcSym, Run, Sz, Val, DcVal, Cp: Integer;
  Hf, Vf, BlkIdx, Bx, By, Px, Py, McuX, McuY, SubX, SubY, BaseX, BaseY, StepX, StepY, Dx, Dy, Off2: Integer;
  SrcV: Byte;
  CompIdx: Integer;
  DstOff, R, G, Bb: Integer;
  Yv, Cb, Cr: Single;
  Vec: TVecF32x4;

  function Need(N: Integer): Boolean; inline;
  begin Result := Pos + N <= Length(AData); end;

  function ReadMarker: Integer;
  begin
    while (Pos < Length(AData)) and (AData[Pos] <> $FF) do Inc(Pos);
    if Pos + 1 >= Length(AData) then Exit(-1);
    while (Pos < Length(AData)) and (AData[Pos] = $FF) do Inc(Pos);
    if Pos >= Length(AData) then Exit(-1);
    B := AData[Pos]; Inc(Pos);
    Result := $FF00 or B;
  end;

begin
  AWidth := 0; AHeight := 0; Result := nil;
  if Length(AData) < 4 then raise EImageDecodeError.Create('jpeg: truncated (no SOI)');
  if (AData[0] <> $FF) or (AData[1] <> $D8) then raise EImageDecodeError.Create('jpeg: bad SOI');
  for I := 0 to 3 do QValid[I] := False;
  for I := 0 to 3 do begin DcTabs[I].Valid:=False; AcTabs[I].Valid:=False; end;
  SawSOF0:=0; NumComp:=0; W:=0; H:=0; Pos:=2;
  while Pos < Length(AData) do
  begin
    Mk := ReadMarker;
    if Mk=-1 then Break;
    if Mk=$FFD8 then Continue;
    if Mk=$FFD9 then Break;
    if (Mk>=$FFD0) and (Mk<=$FFD7) then Continue;
    if Mk=$FF01 then Continue;
    if not Need(2) then raise EImageDecodeError.Create('jpeg: truncated marker len');
    Len := BE16(@AData[Pos]); Inc(Pos,2);
    if Len<2 then raise EImageDecodeError.Create('jpeg: bad marker len');
    Dec(Len,2);
    if Pos+Len>Length(AData) then raise EImageDecodeError.Create('jpeg: truncated marker data');
    case Mk of
      $FFC0: begin
        if Len<6 then raise EImageDecodeError.Create('jpeg: bad SOF0');
        if SawSOF0<>0 then raise EImageDecodeError.Create('jpeg: duplicate SOF0');
        SawSOF0:=1;
        if AData[Pos]<>8 then raise EImageDecodeError.Create('jpeg: only 8-bit baseline');
        H:=BE16(@AData[Pos+1]); W:=BE16(@AData[Pos+3]);
        NumComp:=AData[Pos+5];
        if (W<=0)or(H<=0)or(W>JPEG_MAX_DIM)or(H>JPEG_MAX_DIM) then raise EImageDecodeError.Create('jpeg: width/height out of range');
        if Int64(W)*H>JPEG_MAX_PIXELS then raise EImageDecodeError.Create('jpeg: image too large (16M cap)');
        if not (NumComp in [1,3]) then raise EImageDecodeError.Create('jpeg: unsupported components');
        if Len<6+NumComp*3 then raise EImageDecodeError.Create('jpeg: truncated SOF0 comp');
        for C:=0 to NumComp-1 do
        begin
          Comps[C].Id:=AData[Pos+6+C*3];
          Comps[C].H:=AData[Pos+6+C*3+1] shr 4;
          Comps[C].V:=AData[Pos+6+C*3+1] and $0F;
          Comps[C].QId:=AData[Pos+6+C*3+2];
          if not (Comps[C].H in [1..4]) or not (Comps[C].V in [1..4]) then raise EImageDecodeError.Create('jpeg: bad sampling');
          if Comps[C].QId>3 then raise EImageDecodeError.Create('jpeg: bad qtable id');
        end;
        AWidth:=W; AHeight:=H;
      end;
      $FFDB: begin
        I:=0;
        while I<Len do
        begin
          K:=AData[Pos+I]; Inc(I);
          J:=K and $0F;
          if J>3 then raise EImageDecodeError.Create('jpeg: bad qtable id');
          if (K shr 4)=0 then
          begin
            if I+64>Len then raise EImageDecodeError.Create('jpeg: truncated DQT 8-bit');
            for K:=0 to 63 do Qtabs[J][ZIGZAG[K]]:=AData[Pos+I+K];
            Inc(I,64);
          end else
          begin
            if I+128>Len then raise EImageDecodeError.Create('jpeg: truncated DQT 16-bit');
            for K:=0 to 63 do Qtabs[J][ZIGZAG[K]]:=BE16(@AData[Pos+I+K*2]);
            Inc(I,128);
          end;
          QValid[J]:=True;
        end;
      end;
      $FFC4: begin
        I:=0;
        while I<Len do
        begin
          K:=AData[Pos+I]; Inc(I);
          if I+16>Len then raise EImageDecodeError.Create('jpeg: truncated DHT counts');
          J:=0; for C:=0 to 15 do J:=J+AData[Pos+I+C];
          if I+16+J>Len then raise EImageDecodeError.Create('jpeg: truncated DHT symbols');
          if (K and $10)=0 then BuildHuff(@AData[Pos+I],16,@AData[Pos+I+16],J,DcTabs[K and $0F])
          else BuildHuff(@AData[Pos+I],16,@AData[Pos+I+16],J,AcTabs[K and $0F]);
          Inc(I,16+J);
        end;
      end;
      $FFDA: begin
        if SawSOF0=0 then raise EImageDecodeError.Create('jpeg: SOS before SOF0');
        SosNum:=AData[Pos];
        if SosNum<>NumComp then raise EImageDecodeError.Create('jpeg: SOS comp mismatch');
        if Len<1+SosNum*2+3 then raise EImageDecodeError.Create('jpeg: truncated SOS');
        for C:=0 to SosNum-1 do
        begin
          K:=AData[Pos+1+C*2]; J:=-1;
          for I:=0 to NumComp-1 do if Comps[I].Id=K then J:=I;
          if J=-1 then raise EImageDecodeError.Create('jpeg: SOS unknown comp');
          SosIdx[C]:=J;
          Comps[J].DcTbl:=AData[Pos+1+C*2+1] shr 4;
          Comps[J].AcTbl:=AData[Pos+1+C*2+1] and $0F;
          if (Comps[J].DcTbl>3)or(Comps[J].AcTbl>3) then raise EImageDecodeError.Create('jpeg: bad huff sel');
        end;
        Inc(Pos,Len);
        MaxH:=0; MaxV:=0;
        for C:=0 to NumComp-1 do
        begin if MaxH<Comps[C].H then MaxH:=Comps[C].H; if MaxV<Comps[C].V then MaxV:=Comps[C].V; end;
        McuW:=MaxH*8; McuH:=MaxV*8;
        McuCountX:=(W+McuW-1) div McuW; McuCountY:=(H+McuH-1) div McuH;
        for C:=0 to NumComp-1 do if not QValid[Comps[C].QId] then raise EImageDecodeError.Create('jpeg: missing quant');
        for C:=0 to SosNum-1 do
        begin J:=SosIdx[C]; if not DcTabs[Comps[J].DcTbl].Valid then raise EImageDecodeError.Create('jpeg: missing dc huff'); if not AcTabs[Comps[J].AcTbl].Valid then raise EImageDecodeError.Create('jpeg: missing ac huff'); end;
        SetLength(OutPixels,W*H*4);
        if Length(OutPixels)=0 then raise EImageDecodeError.Create('jpeg: alloc failed');
        SetLength(YCbCrBuf,W*H*3);
        if Length(YCbCrBuf)>0 then BytesZero(@YCbCrBuf[0], Length(YCbCrBuf));
        for C:=0 to 3 do DcPred[C]:=0;
        BrInit(BR,@AData[0],Length(AData),Pos);
        for J:=0 to McuCountY-1 do
          for I:=0 to McuCountX-1 do
            for C:=0 to SosNum-1 do
            begin
              for K:=0 to Comps[SosIdx[C]].H*Comps[SosIdx[C]].V-1 do
              begin
                for Cp:=0 to 63 do Coef[Cp]:=0;
                if not HuffDecode(BR,DcTabs[Comps[SosIdx[C]].DcTbl],DcSym) then raise EImageDecodeError.Create('jpeg: huffman dc');
                if not BrGetBits(BR,DcSym,Val) then raise EImageDecodeError.Create('jpeg: truncated dc diff');
                DcVal:=ReceiveExtend(Val,DcSym);
                DcPred[C]:=DcPred[C]+DcVal;
                Coef[0]:=DcPred[C]*Qtabs[Comps[SosIdx[C]].QId][0];
                Cp:=1;
                while Cp<64 do
                begin
                  if not HuffDecode(BR,AcTabs[Comps[SosIdx[C]].AcTbl],AcSym) then raise EImageDecodeError.Create('jpeg: huffman ac');
                  if AcSym=0 then Break
                  else if AcSym=$F0 then Cp:=Cp+16
                  else
                  begin
                    Run:=AcSym shr 4; Sz:=AcSym and $0F;
                    Cp:=Cp+Run;
                    if Cp>=64 then raise EImageDecodeError.Create('jpeg: ac overflow');
                    if Sz>0 then
                    begin
                      if not BrGetBits(BR,Sz,Val) then raise EImageDecodeError.Create('jpeg: truncated ac');
                      Coef[ZIGZAG[Cp]]:=ReceiveExtend(Val,Sz)*Qtabs[Comps[SosIdx[C]].QId][Cp];
                    end;
                    Inc(Cp);
                  end;
                end;
                Idct8x8(Coef,Block);
                CompIdx:=SosIdx[C]; Hf:=Comps[CompIdx].H; Vf:=Comps[CompIdx].V; BlkIdx:=K;
                McuX:=I*McuW; McuY:=J*McuH; SubX:=BlkIdx mod Hf; SubY:=BlkIdx div Hf;
                BaseX:=McuX+SubX*8; BaseY:=McuY+SubY*8; StepX:=MaxH div Hf; StepY:=MaxV div Vf;
                for By:=0 to 7 do for Bx:=0 to 7 do
                begin
                  SrcV:=Byte(Block[By*8+Bx]);
                  for Py:=0 to StepY-1 do for Px:=0 to StepX-1 do
                  begin
                    Dx:=BaseX+Bx*StepX+Px; Dy:=BaseY+By*StepY+Py;
                    if (Dx<W)and(Dy<H) then
                    begin
                      Off2:=(Dy*W+Dx)*3;
                      if CompIdx=0 then YCbCrBuf[Off2]:=SrcV
                      else if NumComp=3 then
                      begin if C=1 then YCbCrBuf[Off2+1]:=SrcV else if C=2 then YCbCrBuf[Off2+2]:=SrcV; end;
                      if NumComp=1 then begin YCbCrBuf[Off2+1]:=128; YCbCrBuf[Off2+2]:=128; end;
                    end;
                  end;
                end;
              end;
            end;
        Pos:=BR.Pos;
        for J:=0 to H-1 do
          for I:=0 to W-1 do
          begin
            Off2:=(J*W+I)*3; DstOff:=(J*W+I)*4;
            if NumComp=1 then
            begin Yv:=YCbCrBuf[Off2]; OutPixels[DstOff]:=ClampByte(Trunc(Yv)); OutPixels[DstOff+1]:=ClampByte(Trunc(Yv)); OutPixels[DstOff+2]:=ClampByte(Trunc(Yv)); OutPixels[DstOff+3]:=255; end
            else
            begin Yv:=Single(YCbCrBuf[Off2]); Cb:=Single(YCbCrBuf[Off2+1])-128; Cr:=Single(YCbCrBuf[Off2+2])-128; Vec:=VecF32x4Make(Yv,Cb,Cr,0);
              R:=Round(VecF32x4Extract(Vec,0)+1.402*VecF32x4Extract(Vec,2));
              G:=Round(VecF32x4Extract(Vec,0)-0.34414*VecF32x4Extract(Vec,1)-0.71414*VecF32x4Extract(Vec,2));
              Bb:=Round(VecF32x4Extract(Vec,0)+1.772*VecF32x4Extract(Vec,1));
              OutPixels[DstOff]:=ClampByte(R); OutPixels[DstOff+1]:=ClampByte(G); OutPixels[DstOff+2]:=ClampByte(Bb); OutPixels[DstOff+3]:=255;
            end;
          end;
        AWidth:=W; AHeight:=H; Result:=OutPixels; Exit;
      end;
    else Inc(Pos,Len);
    end;
  end;
  raise EImageDecodeError.Create('jpeg: missing SOS/EOI');
end;

end.
