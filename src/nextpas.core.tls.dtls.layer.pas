unit nextpas.core.tls.dtls.layer;

{$mode objfpc}{$H+}{$J-}

interface

uses
  SysUtils;

const
  DTLS_CONTENT_TYPE_CHANGE_CIPHER_SPEC = 20;
  DTLS_CONTENT_TYPE_ALERT = 21;
  DTLS_CONTENT_TYPE_HANDSHAKE = 22;
  DTLS_CONTENT_TYPE_APPLICATION_DATA = 23;

  DTLS_VERSION_1_0 = $FEFF;
  DTLS_VERSION_1_2 = $FEFD;

type
  TBytesArray = array of TBytes;

  TDTLSRecordHeader = record
    ContentType: Byte;
    Version: Word;
    Epoch: Word;
    SequenceNumber: array[0..5] of Byte;
    Length: Word;
  end;

  TDTLSHandshakeHeader = record
    MsgType: Byte;
    Length: Cardinal;
    MessageSeq: Word;
    FragmentOffset: Cardinal;
    FragmentLength: Cardinal;
  end;

  TDTLSRetransmitEntry = record
    Data: TBytes;
    Epoch: Word;
    MessageSeq: Word;
    SendCount: Integer;
    LastSentTime: TDateTime;
  end;

  TDTLSRecordLayer = class
  private
    FReadEpoch: Word;
    FWriteEpoch: Word;
    FReadSeq: QWord;
    FWriteSeq: QWord;
    FRetransmitQueue: array of TDTLSRetransmitEntry;
    FMTU: Integer;
  public
    constructor Create(AMTU: Integer = 1400);
    function BuildRecord(AContentType: Byte; const APayload: TBytes): TBytes;
    function ParseRecordHeader(const AData: TBytes; AOffset: Integer;
      out AHeader: TDTLSRecordHeader): Boolean;
    function ParseHandshakeHeader(const AData: TBytes; AOffset: Integer;
      out AHeader: TDTLSHandshakeHeader): Boolean;
    function FragmentHandshake(const AHandshake: TBytes; AMessageSeq: Word): TBytesArray;
    procedure IncrementWriteEpoch;
    procedure QueueForRetransmit(const AData: TBytes; AMessageSeq: Word);
    function GetRetransmitData: TBytes;
    property MTU: Integer read FMTU write FMTU;
    property ReadEpoch: Word read FReadEpoch;
    property WriteEpoch: Word read FWriteEpoch;
  end;

implementation

uses
  DateUtils;

constructor TDTLSRecordLayer.Create(AMTU: Integer);
begin
  inherited Create;
  FMTU := AMTU;
  FReadEpoch := 0;
  FWriteEpoch := 0;
  FReadSeq := 0;
  FWriteSeq := 0;
  SetLength(FRetransmitQueue, 0);
end;

function TDTLSRecordLayer.BuildRecord(AContentType: Byte; const APayload: TBytes): TBytes;
var
  LLen: Integer;
begin
  LLen := Length(APayload);
  SetLength(Result, 13 + LLen);
  Result[0] := AContentType;
  Result[1] := Hi(DTLS_VERSION_1_2);
  Result[2] := Lo(DTLS_VERSION_1_2);
  Result[3] := Hi(FWriteEpoch);
  Result[4] := Lo(FWriteEpoch);
  Result[5] := Byte(FWriteSeq shr 40);
  Result[6] := Byte(FWriteSeq shr 32);
  Result[7] := Byte(FWriteSeq shr 24);
  Result[8] := Byte(FWriteSeq shr 16);
  Result[9] := Byte(FWriteSeq shr 8);
  Result[10] := Byte(FWriteSeq);
  Result[11] := Byte(LLen shr 8);
  Result[12] := Byte(LLen);
  if LLen > 0 then
    Move(APayload[0], Result[13], LLen);
  Inc(FWriteSeq);
end;

function TDTLSRecordLayer.ParseRecordHeader(const AData: TBytes; AOffset: Integer;
  out AHeader: TDTLSRecordHeader): Boolean;
begin
  Result := False;
  if AOffset + 13 > Length(AData) then Exit;
  AHeader.ContentType := AData[AOffset];
  AHeader.Version := (Word(AData[AOffset + 1]) shl 8) or Word(AData[AOffset + 2]);
  AHeader.Epoch := (Word(AData[AOffset + 3]) shl 8) or Word(AData[AOffset + 4]);
  AHeader.SequenceNumber[0] := AData[AOffset + 5];
  AHeader.SequenceNumber[1] := AData[AOffset + 6];
  AHeader.SequenceNumber[2] := AData[AOffset + 7];
  AHeader.SequenceNumber[3] := AData[AOffset + 8];
  AHeader.SequenceNumber[4] := AData[AOffset + 9];
  AHeader.SequenceNumber[5] := AData[AOffset + 10];
  AHeader.Length := (Word(AData[AOffset + 11]) shl 8) or Word(AData[AOffset + 12]);
  Result := True;
end;

function TDTLSRecordLayer.ParseHandshakeHeader(const AData: TBytes; AOffset: Integer;
  out AHeader: TDTLSHandshakeHeader): Boolean;
begin
  Result := False;
  if AOffset + 12 > Length(AData) then Exit;
  AHeader.MsgType := AData[AOffset];
  AHeader.Length := (Cardinal(AData[AOffset + 1]) shl 16) or
                    (Cardinal(AData[AOffset + 2]) shl 8) or
                    Cardinal(AData[AOffset + 3]);
  AHeader.MessageSeq := (Word(AData[AOffset + 4]) shl 8) or Word(AData[AOffset + 5]);
  AHeader.FragmentOffset := (Cardinal(AData[AOffset + 6]) shl 16) or
                            (Cardinal(AData[AOffset + 7]) shl 8) or
                            Cardinal(AData[AOffset + 8]);
  AHeader.FragmentLength := (Cardinal(AData[AOffset + 9]) shl 16) or
                            (Cardinal(AData[AOffset + 10]) shl 8) or
                            Cardinal(AData[AOffset + 11]);
  Result := True;
end;

function TDTLSRecordLayer.FragmentHandshake(const AHandshake: TBytes; AMessageSeq: Word): TBytesArray;
var
  LMaxFrag, LOffset, LRemaining, LFragLen: Integer;
  LFrag: TBytes;
begin
  SetLength(Result, 0);
  LMaxFrag := FMTU - 13 - 12;
  if LMaxFrag < 1 then LMaxFrag := 1;
  LOffset := 0;
  LRemaining := Length(AHandshake);

  while LOffset < Length(AHandshake) do
  begin
    LFragLen := LRemaining;
    if LFragLen > LMaxFrag then
      LFragLen := LMaxFrag;

    SetLength(LFrag, 12 + LFragLen);
    LFrag[0] := AHandshake[0];
    LFrag[1] := Byte(Length(AHandshake) shr 16);
    LFrag[2] := Byte(Length(AHandshake) shr 8);
    LFrag[3] := Byte(Length(AHandshake));
    LFrag[4] := Hi(AMessageSeq);
    LFrag[5] := Lo(AMessageSeq);
    LFrag[6] := Byte(LOffset shr 16);
    LFrag[7] := Byte(LOffset shr 8);
    LFrag[8] := Byte(LOffset);
    LFrag[9] := Byte(LFragLen shr 16);
    LFrag[10] := Byte(LFragLen shr 8);
    LFrag[11] := Byte(LFragLen);
    if LFragLen > 0 then
      Move(AHandshake[LOffset], LFrag[12], LFragLen);

    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := BuildRecord(DTLS_CONTENT_TYPE_HANDSHAKE, LFrag);

    Inc(LOffset, LFragLen);
    Dec(LRemaining, LFragLen);
  end;
end;

procedure TDTLSRecordLayer.IncrementWriteEpoch;
begin
  Inc(FWriteEpoch);
  FWriteSeq := 0;
end;

procedure TDTLSRecordLayer.QueueForRetransmit(const AData: TBytes; AMessageSeq: Word);
var
  LIdx: Integer;
begin
  LIdx := Length(FRetransmitQueue);
  SetLength(FRetransmitQueue, LIdx + 1);
  FRetransmitQueue[LIdx].Data := AData;
  FRetransmitQueue[LIdx].Epoch := FWriteEpoch;
  FRetransmitQueue[LIdx].MessageSeq := AMessageSeq;
  FRetransmitQueue[LIdx].SendCount := 1;
  FRetransmitQueue[LIdx].LastSentTime := Now;
end;

function TDTLSRecordLayer.GetRetransmitData: TBytes;
var
  I, LTotal, LPos: Integer;
begin
  LTotal := 0;
  for I := 0 to High(FRetransmitQueue) do
    Inc(LTotal, Length(FRetransmitQueue[I].Data));
  SetLength(Result, LTotal);
  LPos := 0;
  for I := 0 to High(FRetransmitQueue) do
  begin
    Move(FRetransmitQueue[I].Data[0], Result[LPos], Length(FRetransmitQueue[I].Data));
    Inc(LPos, Length(FRetransmitQueue[I].Data));
    Inc(FRetransmitQueue[I].SendCount);
    FRetransmitQueue[I].LastSentTime := Now;
  end;
end;

end.
