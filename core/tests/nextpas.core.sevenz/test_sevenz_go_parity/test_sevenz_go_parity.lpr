program test_sevenz_go_parity;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.sevenz,
  nextpas.core.sevenz.coders,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestGoParityLzma2Golden;
var
  Raw, Decoded: TBytes;
  Enc: TSevenZLzmaEncoded;
begin
  SetLength(Raw, 1024);
  FillChar(Raw[0], 1024, $5A);
  Enc := SevenZAcquireEncoder.EncodeLzma2(Raw, szclDefault);
  Decoded := SevenZAcquireDecoder.DecodeLzma2(Enc.Props, Enc.PackedData, Length(Raw));
  CheckEqual(Int64(Length(Raw)), Int64(Length(Decoded)), 'go parity lzma2 len');
  Check(CompareMem(@Raw[0], @Decoded[0], Length(Raw)), 'go parity lzma2 bytes');
end;

procedure TestGoParityWriterDeterminism;
var
  Raw: TBytes;
  A,B: TBytes;
  W: ISevenZWriter;
begin
  SetLength(Raw, 4096);
  FillChar(Raw[0], 4096, $33);
  W := TSevenZWriterImpl.Create;
  W.AddFile('a.bin', Raw);
  A := W.Finish;
  W := TSevenZWriterImpl.Create;
  W.AddFile('a.bin', Raw);
  B := W.Finish;
  Check(Length(A)=Length(B), 'go parity determinism len');
  Check(CompareMem(@A[0], @B[0], Length(A)), 'go parity determinism bytes');
end;

procedure TestGoParityBzip2Golden;
var
  Arch: TBytes;
  R: ISevenZReader;
  Got: TBytes;
  S: string;
begin
  // 与 Go/ p7zip 互通的 BZip2 黄金档（同 test_sevenz）
  Arch := TBytes.Create(
    $37,$7A,$BC,$AF,$27,$1C,$00,$04,$66,$E0,$2B,$DA,$35,$00,$00,$00,
    $00,$00,$00,$00,$5A,$00,$00,$00,$00,$00,$00,$00,$97,$7C,$83,$33,
    $42,$5A,$68,$39,$31,$41,$59,$26,$53,$59,$2C,$41,$D3,$C0,$00,$00,
    $05,$91,$80,$40,$00,$06,$44,$90,$80,$20,$00,$21,$B5,$46,$7A,$81,
    $03,$03,$D1,$11,$2A,$E6,$18,$30,$D3,$44,$E1,$77,$24,$53,$85,$09,
    $02,$C4,$1D,$3C,$00,$01,$04,$06,$00,$01,$09,$35,$00,$07,$0B,$01,
    $00,$01,$03,$04,$02,$02,$0C,$23,$00,$08,$0A,$01,$BB,$FE,$42,$0F,
    $00,$00,$05,$01,$19,$0C,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,
    $00,$00,$11,$15,$00,$68,$00,$65,$00,$6C,$00,$6C,$00,$6F,$00,$2E,
    $00,$74,$00,$78,$00,$74,$00,$00,$00,$14,$0A,$01,$00,$80,$6F,$1E,
    $AD,$66,$36,$DD,$01,$15,$06,$01,$00,$20,$80,$B4,$81,$00,$00);
  R := TSevenZReaderImpl.Create(Arch);
  Got := R.Extract(0);
  SetLength(S, Length(Got));
  if Length(Got)>0 then Move(Got[0], S[1], Length(Got));
  CheckEqual('hello world hello world hello world', S, 'go parity bzip2 golden');
end;

begin
  T := TTestSuite.Create('nextpas.core.sevenz.go_parity');
  T.Test('go parity lzma2 roundtrip', @TestGoParityLzma2Golden);
  T.Test('go parity writer determinism', @TestGoParityWriterDeterminism);
  T.Test('go parity bzip2 golden', @TestGoParityBzip2Golden);
  if not T.Run then Halt(1);
end.
