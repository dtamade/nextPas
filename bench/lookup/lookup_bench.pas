program lookup_bench;

{$mode objfpc}{$H+}

uses nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.intf;

const
  N = 100000;
  TABLE_SIZE = 256;

  CharToDigit: array[0..255] of Int8 = (
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
     0, 1, 2, 3, 4, 5, 6, 7, 8, 9,-1,-1,-1,-1,-1,-1,
    -1,10,11,12,13,14,15,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,10,11,12,13,14,15,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1
  );

  ToUpper: array[0..255] of Byte = (
    $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0A,$0B,$0C,$0D,$0E,$0F,
    $10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$1A,$1B,$1C,$1D,$1E,$1F,
    $20,$21,$22,$23,$24,$25,$26,$27,$28,$29,$2A,$2B,$2C,$2D,$2E,$2F,
    $30,$31,$32,$33,$34,$35,$36,$37,$38,$39,$3A,$3B,$3C,$3D,$3E,$3F,
    $40,$41,$42,$43,$44,$45,$46,$47,$48,$49,$4A,$4B,$4C,$4D,$4E,$4F,
    $50,$51,$52,$53,$54,$55,$56,$57,$58,$59,$5A,$5B,$5C,$5D,$5E,$5F,
    $60,$41,$42,$43,$44,$45,$46,$47,$48,$49,$4A,$4B,$4C,$4D,$4E,$4F,
    $50,$51,$52,$53,$54,$55,$56,$57,$58,$59,$5A,$7B,$7C,$7D,$7E,$7F,
    $80,$81,$82,$83,$84,$85,$86,$87,$88,$89,$8A,$8B,$8C,$8D,$8E,$8F,
    $90,$91,$92,$93,$94,$95,$96,$97,$98,$99,$9A,$9B,$9C,$9D,$9E,$9F,
    $A0,$A1,$A2,$A3,$A4,$A5,$A6,$A7,$A8,$A9,$AA,$AB,$AC,$AD,$AE,$AF,
    $B0,$B1,$B2,$B3,$B4,$B5,$B6,$B7,$B8,$B9,$BA,$BB,$BC,$BD,$BE,$BF,
    $C0,$C1,$C2,$C3,$C4,$C5,$C6,$C7,$C8,$C9,$CA,$CB,$CC,$CD,$CE,$CF,
    $D0,$D1,$D2,$D3,$D4,$D5,$D6,$D7,$D8,$D9,$DA,$DB,$DC,$DD,$DE,$DF,
    $E0,$E1,$E2,$E3,$E4,$E5,$E6,$E7,$E8,$E9,$EA,$EB,$EC,$ED,$EE,$EF,
    $F0,$F1,$F2,$F3,$F4,$F5,$F6,$F7,$F8,$F9,$FA,$FB,$FC,$FD,$FE,$FF
  );

var
  GText: AnsiString;
  GResult: array[0..N-1] of Byte;
  GSink: Integer;

procedure InitText;
var
  I: Integer;
begin
  SetLength(GText, N);
  for I := 1 to N do
    GText[I] := Chr(32 + (I mod 95));
end;

procedure BenchHexLookup(const ACtx: IBenchContext);
var
  I, LSum: Integer;
  LVal: Int8;
begin
  LSum := 0;
  for I := 1 to Length(GText) do
  begin
    LVal := CharToDigit[Ord(GText[I])];
    if LVal >= 0 then
      LSum += LVal;
  end;
  GSink := LSum;
  ACtx.SetBytes(N);
end;

procedure BenchToUpperTable(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 1 to Length(GText) do
    GResult[I-1] := ToUpper[Ord(GText[I])];
  GSink := GResult[0];
  ACtx.SetBytes(N);
end;

procedure BenchToUpperBranch(const ACtx: IBenchContext);
var
  I: Integer;
  LCh: Byte;
begin
  for I := 1 to Length(GText) do
  begin
    LCh := Byte(GText[I]);
    if (LCh >= Ord('a')) and (LCh <= Ord('z')) then
      Dec(LCh, 32);
    GResult[I-1] := LCh;
  end;
  GSink := GResult[0];
  ACtx.SetBytes(N);
end;

procedure BenchToUpperSet(const ACtx: IBenchContext);
var
  I: Integer;
  LCh: Byte;
begin
  for I := 1 to Length(GText) do
  begin
    LCh := Byte(GText[I]);
    if Chr(LCh) in ['a'..'z'] then
      Dec(LCh, 32);
    GResult[I-1] := LCh;
  end;
  GSink := GResult[0];
  ACtx.SetBytes(N);
end;

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  InitText;

  LSuite := TBenchSuite.Create('lookup');
  LSuite.SetMinDuration(TDuration.FromMilliseconds(200));
  LSuite.SetMaxIterations(1000);
  LSuite.SetMinSamples(6);
  LSuite.SetWarmupIters(3);

  LSuite.Add('HexLookup/100K', @BenchHexLookup);
  LSuite.Add('ToUpper/Table/100K', @BenchToUpperTable);
  LSuite.Add('ToUpper/Branch/100K', @BenchToUpperBranch);
  LSuite.Add('ToUpper/Set/100K', @BenchToUpperSet);

  LResults := LSuite.Run;
  LResults.ToBenchStat;
end.
