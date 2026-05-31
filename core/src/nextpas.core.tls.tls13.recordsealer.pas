unit nextpas.core.tls.tls13.recordsealer;

{$mode ObjFPC}{$H+}{$J-}
{$modeswitch advancedrecords}

interface

uses
  SysUtils;

type
  TTLS13SealerState = (tssReady, tssExhausted);

  TTLS13RecordSealer = record
    FKey: TBytes;
    FIV: TBytes;
    FCipherSuite: Word;
    FSequence: QWord;
    FState: TTLS13SealerState;
    procedure Init(ACipherSuite: Word; const AKey, AIV: TBytes);
    function Seal(const AFragment: TBytes; AContentType: Byte;
      out ARecord: TBytes; out AError: string): Boolean;
    procedure UpdateKey(const ANewKey, ANewIV: TBytes);
    procedure Clear;
    function IsExhausted: Boolean;
    function GetSequence: QWord;
  end;

  TTLS13RecordOpener = record
    FKey: TBytes;
    FIV: TBytes;
    FCipherSuite: Word;
    FSequence: QWord;
    FState: TTLS13SealerState;
    procedure Init(ACipherSuite: Word; const AKey, AIV: TBytes);
    function Open(const AEncryptedPayload: TBytes;
      out AFragment: TBytes; out AContentType: Byte;
      out AError: string): Boolean;
    procedure UpdateKey(const ANewKey, ANewIV: TBytes);
    procedure Clear;
    function IsExhausted: Boolean;
    function GetSequence: QWord;
  end;

implementation

uses
  nextpas.core.tls.tls13.aead,
  nextpas.core.tls.tls13.recordcrypto,
  nextpas.core.tls.tls13.wire;

{ TTLS13RecordSealer }

procedure TTLS13RecordSealer.Init(ACipherSuite: Word; const AKey, AIV: TBytes);
begin
  // Securely zero old key material before replacing
  if Length(FKey) > 0 then FillChar(FKey[0], Length(FKey), 0);
  if Length(FIV) > 0 then FillChar(FIV[0], Length(FIV), 0);
  FCipherSuite := ACipherSuite;
  FKey := Copy(AKey);
  FIV := Copy(AIV);
  FSequence := 0;
  FState := tssReady;
end;

function TTLS13RecordSealer.Seal(const AFragment: TBytes; AContentType: Byte;
  out ARecord: TBytes; out AError: string): Boolean;
var
  LInnerPlaintext, LNonce, LAAD, LEncrypted: TBytes;
  LEncLen: Word;
begin
  SetLength(ARecord, 0);
  AError := '';
  Result := False;

  if FState = tssExhausted then
  begin
    AError := 'TLS 1.3 record sealer: sequence number exhausted';
    Exit;
  end;

  if Length(FKey) = 0 then
  begin
    AError := 'TLS 1.3 record sealer: not initialized (no key)';
    Exit;
  end;

  if Length(FIV) <> 12 then
  begin
    AError := 'TLS 1.3 record sealer: IV must be 12 bytes (got ' + IntToStr(Length(FIV)) + ')';
    Exit;
  end;

  if Length(AFragment) > 16384 then
  begin
    AError := 'TLS 1.3 record sealer: fragment exceeds max size (16384 bytes)';
    Exit;
  end;

  LInnerPlaintext := BuildTLS13InnerPlaintext(AFragment, AContentType);
  LNonce := BuildTLS13RecordNonce(FIV, FSequence);
  LEncLen := Word(Length(LInnerPlaintext) + TLS13AEADTagLength(FCipherSuite));
  LAAD := BuildTLS13RecordAAD(LEncLen);

  if not TryTLS13AEADEncrypt(FCipherSuite, FKey, LNonce, LAAD,
    LInnerPlaintext, LEncrypted, AError) then
    Exit;

  SetLength(ARecord, 5 + Length(LEncrypted));
  ARecord[0] := TLS_CONTENT_TYPE_APPLICATION_DATA;
  ARecord[1] := Byte(TLS_LEGACY_VERSION shr 8);
  ARecord[2] := Byte(TLS_LEGACY_VERSION and $FF);
  ARecord[3] := Byte(Length(LEncrypted) shr 8);
  ARecord[4] := Byte(Length(LEncrypted) and $FF);
  if Length(LEncrypted) > 0 then
    Move(LEncrypted[0], ARecord[5], Length(LEncrypted));

  if not IncrementTLS13Sequence(FSequence) then
    FState := tssExhausted;

  Result := True;
end;

procedure TTLS13RecordSealer.UpdateKey(const ANewKey, ANewIV: TBytes);
begin
  if Length(FKey) > 0 then
    FillChar(FKey[0], Length(FKey), 0);
  if Length(FIV) > 0 then
    FillChar(FIV[0], Length(FIV), 0);
  FKey := Copy(ANewKey);
  FIV := Copy(ANewIV);
  FSequence := 0;
  FState := tssReady;
end;

procedure TTLS13RecordSealer.Clear;
begin
  if Length(FKey) > 0 then
    FillChar(FKey[0], Length(FKey), 0);
  if Length(FIV) > 0 then
    FillChar(FIV[0], Length(FIV), 0);
  SetLength(FKey, 0);
  SetLength(FIV, 0);
  FSequence := 0;
  FState := tssExhausted;
end;

function TTLS13RecordSealer.IsExhausted: Boolean;
begin
  Result := FState = tssExhausted;
end;

function TTLS13RecordSealer.GetSequence: QWord;
begin
  Result := FSequence;
end;

{ TTLS13RecordOpener }

procedure TTLS13RecordOpener.Init(ACipherSuite: Word; const AKey, AIV: TBytes);
begin
  if Length(FKey) > 0 then FillChar(FKey[0], Length(FKey), 0);
  if Length(FIV) > 0 then FillChar(FIV[0], Length(FIV), 0);
  FCipherSuite := ACipherSuite;
  FKey := Copy(AKey);
  FIV := Copy(AIV);
  FSequence := 0;
  FState := tssReady;
end;

function TTLS13RecordOpener.Open(const AEncryptedPayload: TBytes;
  out AFragment: TBytes; out AContentType: Byte;
  out AError: string): Boolean;
var
  LNonce, LAAD, LPlaintext: TBytes;
begin
  SetLength(AFragment, 0);
  AContentType := 0;
  AError := '';
  Result := False;

  if FState = tssExhausted then
  begin
    AError := 'TLS 1.3 record opener: sequence number exhausted';
    Exit;
  end;

  LNonce := BuildTLS13RecordNonce(FIV, FSequence);
  LAAD := BuildTLS13RecordAAD(Word(Length(AEncryptedPayload)));

  if not TryTLS13AEADDecrypt(FCipherSuite, FKey, LNonce, LAAD,
    AEncryptedPayload, LPlaintext, AError) then
    Exit;

  if not TryParseTLS13InnerPlaintext(LPlaintext, AFragment, AContentType) then
  begin
    AError := 'TLS 1.3 record opener: invalid inner plaintext';
    Exit;
  end;

  if not IncrementTLS13Sequence(FSequence) then
    FState := tssExhausted;

  Result := True;
end;

procedure TTLS13RecordOpener.UpdateKey(const ANewKey, ANewIV: TBytes);
begin
  if Length(FKey) > 0 then
    FillChar(FKey[0], Length(FKey), 0);
  if Length(FIV) > 0 then
    FillChar(FIV[0], Length(FIV), 0);
  FKey := Copy(ANewKey);
  FIV := Copy(ANewIV);
  FSequence := 0;
  FState := tssReady;
end;

procedure TTLS13RecordOpener.Clear;
begin
  if Length(FKey) > 0 then
    FillChar(FKey[0], Length(FKey), 0);
  if Length(FIV) > 0 then
    FillChar(FIV[0], Length(FIV), 0);
  SetLength(FKey, 0);
  SetLength(FIV, 0);
  FSequence := 0;
  FState := tssExhausted;
end;

function TTLS13RecordOpener.IsExhausted: Boolean;
begin
  Result := FState = tssExhausted;
end;

function TTLS13RecordOpener.GetSequence: QWord;
begin
  Result := FSequence;
end;

end.
