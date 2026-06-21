unit nextpas.core.tls.tls12.io;

{$mode objfpc}{$H+}{$J-}

interface

uses
  nextpas.core.base, nextpas.core.text.conv, nextpas.core.io.intf,
  nextpas.core.io.intf;

type
  TTLS12HandshakeReader = class
  private
    FStream: IStream;
    FBuffer: TBytes;
    FNonHandshakeContentType: Byte;
    FNonHandshakeData: TBytes;
    FHasNonHandshake: Boolean;
  public
    constructor Create(AStream: IStream); overload;
    constructor Create(AStream: IStream); overload;
    function ReadMessage(out AHandshakeType: Byte; out ABody: TBytes;
      out AFullMessage: TBytes; out AAlertDesc: string): Boolean;
    function HasPendingNonHandshake: Boolean;
    function GetNonHandshakeContentType: Byte;
    function GetNonHandshakeData: TBytes;
  end;

procedure TLS12AppendTranscript(var ATranscript: TBytes; const AData: TBytes);

function TLS12SendRecord(AStream: IStream; AContentType: Byte;
  const AData: TBytes): Boolean; overload;
function TLS12SendRecord(AStream: IStream; AContentType: Byte;
  const AData: TBytes): Boolean; overload;

function TLS12ReadExact(AStream: IStream; var ABuf: TBytes; AOffset,
  ACount: Integer): Boolean; overload;
function TLS12ReadExact(AStream: IStream; var ABuf: TBytes; AOffset,
  ACount: Integer): Boolean; overload;

function TLS12ReadRecord(AStream: IStream; out AContentType: Byte;
  out AData: TBytes): Boolean; overload;
function TLS12ReadRecord(AStream: IStream; out AContentType: Byte;
  out AData: TBytes): Boolean; overload;

function TLS12ReadHandshakeMessage(AStream: IStream; out AHandshakeType: Byte;
  out ABody: TBytes; out AFullMessage: TBytes; out AError: string): Boolean; overload;
function TLS12ReadHandshakeMessage(AStream: IStream; out AHandshakeType: Byte;
  out ABody: TBytes; out AFullMessage: TBytes; out AError: string): Boolean; overload;

implementation

uses
  nextpas.core.io.stream_adapter,
  nextpas.core.io.util,
  nextpas.core.tls.tls12.wire;

procedure TLS12AppendTranscript(var ATranscript: TBytes; const AData: TBytes);
var
  LOldLen: Integer;
begin
  LOldLen := Length(ATranscript);
  SetLength(ATranscript, LOldLen + Length(AData));
  if Length(AData) > 0 then
    Move(AData[0], ATranscript[LOldLen], Length(AData));
end;

function TLS12SendRecord(AStream: IStream; AContentType: Byte;
  const AData: TBytes): Boolean;
var
  LHeader: TBytes;
begin
  Result := AStream <> nil;
  if not Result then
    Exit;
  LHeader := TLS12BuildRecordHeader(AContentType, Length(AData));
  AStream.Write(LHeader[0], 5);
  if Length(AData) > 0 then
    AStream.Write(AData[0], SizeUInt(Length(AData)));
end;

function TLS12SendRecord(AStream: IStream; AContentType: Byte;
  const AData: TBytes): Boolean;
begin
  Result := TLS12SendRecord(WrapTStream(AStream, False), AContentType, AData);
end;

function TLS12ReadExact(AStream: IStream; var ABuf: TBytes; AOffset,
  ACount: Integer): Boolean;
begin
  Result := False;
  if (AStream = nil) or (AOffset < 0) or (ACount < 0) then
    Exit;
  if Length(ABuf) < AOffset + ACount then
    SetLength(ABuf, AOffset + ACount);
  if ACount = 0 then
    Exit(True);
  IoReadFull(AStream, ABuf[AOffset], SizeUInt(ACount));
  Result := True;
end;

function TLS12ReadExact(AStream: IStream; var ABuf: TBytes; AOffset,
  ACount: Integer): Boolean;
begin
  Result := TLS12ReadExact(WrapTStream(AStream, False), ABuf, AOffset, ACount);
end;

function TLS12ReadRecord(AStream: IStream; out AContentType: Byte;
  out AData: TBytes): Boolean;
var
  LHeader: TBytes;
  LLen: Integer;
begin
  Result := False;
  if AStream = nil then
    Exit;
  SetLength(LHeader, 5);
  if not TLS12ReadExact(AStream, LHeader, 0, 5) then
    Exit;
  AContentType := LHeader[0];
  LLen := (Integer(LHeader[3]) shl 8) or Integer(LHeader[4]);
  if (LLen < 0) or (LLen > TLS12_RECORD_MAX_LENGTH + 256) then
    Exit;
  SetLength(AData, LLen);
  if (LLen > 0) and (not TLS12ReadExact(AStream, AData, 0, LLen)) then
    Exit;
  Result := True;
end;

function TLS12ReadRecord(AStream: IStream; out AContentType: Byte;
  out AData: TBytes): Boolean;
begin
  Result := TLS12ReadRecord(WrapTStream(AStream, False), AContentType, AData);
end;

function TLS12ReadHandshakeMessage(AStream: IStream; out AHandshakeType: Byte;
  out ABody: TBytes; out AFullMessage: TBytes; out AError: string): Boolean;
var
  LBuffer: TBytes;
  LData: TBytes;
  LContentType: Byte;
  LBodyLen: Integer;
  LOldLen: Integer;
begin
  Result := False;
  AError := '';
  AHandshakeType := 0;
  SetLength(ABody, 0);
  SetLength(AFullMessage, 0);
  SetLength(LBuffer, 0);

  while True do
  begin
    if Length(LBuffer) >= 4 then
    begin
      LBodyLen := (Integer(LBuffer[1]) shl 16) or
        (Integer(LBuffer[2]) shl 8) or Integer(LBuffer[3]);
      if LBodyLen > 131072 then
      begin
        AError := 'Handshake message too large';
        Exit;
      end;
      if Length(LBuffer) >= 4 + LBodyLen then
      begin
        AHandshakeType := LBuffer[0];
        SetLength(ABody, LBodyLen);
        if LBodyLen > 0 then
          Move(LBuffer[4], ABody[0], LBodyLen);
        SetLength(AFullMessage, 4 + LBodyLen);
        Move(LBuffer[0], AFullMessage[0], Length(AFullMessage));
        Result := True;
        Exit;
      end;
    end;

    if not TLS12ReadRecord(AStream, LContentType, LData) then
    begin
      AError := 'Failed to read handshake record';
      Exit;
    end;

    if LContentType = TLS12_CONTENT_CHANGE_CIPHER_SPEC then
      Continue;

    if LContentType = TLS12_CONTENT_ALERT then
    begin
      if Length(LData) >= 2 then
        AError := Format('received alert: level=%d desc=%d', [LData[0], LData[1]])
      else
        AError := 'received malformed alert';
      Exit;
    end;

    if LContentType <> TLS12_CONTENT_HANDSHAKE then
    begin
      AError := Format('unexpected content type %d', [LContentType]);
      Exit;
    end;

    LOldLen := Length(LBuffer);
    SetLength(LBuffer, LOldLen + Length(LData));
    if Length(LData) > 0 then
      Move(LData[0], LBuffer[LOldLen], Length(LData));
  end;
end;

function TLS12ReadHandshakeMessage(AStream: IStream; out AHandshakeType: Byte;
  out ABody: TBytes; out AFullMessage: TBytes; out AError: string): Boolean;
begin
  Result := TLS12ReadHandshakeMessage(WrapTStream(AStream, False), AHandshakeType,
    ABody, AFullMessage, AError);
end;

constructor TTLS12HandshakeReader.Create(AStream: IStream);
begin
  inherited Create;
  FStream := AStream;
  SetLength(FBuffer, 0);
  FHasNonHandshake := False;
end;

constructor TTLS12HandshakeReader.Create(AStream: IStream);
begin
  Create(WrapTStream(AStream, False));
end;

function TTLS12HandshakeReader.ReadMessage(out AHandshakeType: Byte;
  out ABody: TBytes; out AFullMessage: TBytes; out AAlertDesc: string): Boolean;
var
  LContentType: Byte;
  LData: TBytes;
  LBodyLen: Integer;
  LOldLen: Integer;
begin
  Result := False;
  AAlertDesc := '';

  while True do
  begin
    if Length(FBuffer) >= 4 then
    begin
      LBodyLen := (Integer(FBuffer[1]) shl 16) or
        (Integer(FBuffer[2]) shl 8) or Integer(FBuffer[3]);
      if Length(FBuffer) >= 4 + LBodyLen then
      begin
        AHandshakeType := FBuffer[0];
        SetLength(ABody, LBodyLen);
        if LBodyLen > 0 then
          Move(FBuffer[4], ABody[0], LBodyLen);
        SetLength(AFullMessage, 4 + LBodyLen);
        Move(FBuffer[0], AFullMessage[0], 4 + LBodyLen);

        LOldLen := Length(FBuffer) - (4 + LBodyLen);
        if LOldLen > 0 then
        begin
          Move(FBuffer[4 + LBodyLen], FBuffer[0], LOldLen);
          SetLength(FBuffer, LOldLen);
        end
        else
          SetLength(FBuffer, 0);

        Result := True;
        Exit;
      end;
    end;

    if not TLS12ReadRecord(FStream, LContentType, LData) then
      Exit;

    if LContentType = TLS12_CONTENT_ALERT then
    begin
      if Length(LData) >= 2 then
        AAlertDesc := Format('server alert: level=%d desc=%d', [LData[0], LData[1]])
      else
        AAlertDesc := 'malformed alert';
      Exit;
    end;

    if LContentType = TLS12_CONTENT_CHANGE_CIPHER_SPEC then
      Continue;

    if LContentType <> TLS12_CONTENT_HANDSHAKE then
    begin
      FNonHandshakeContentType := LContentType;
      FNonHandshakeData := LData;
      FHasNonHandshake := True;
      AAlertDesc := Format('unexpected content type %d', [LContentType]);
      Exit;
    end;

    LOldLen := Length(FBuffer);
    SetLength(FBuffer, LOldLen + Length(LData));
    if Length(LData) > 0 then
      Move(LData[0], FBuffer[LOldLen], Length(LData));
  end;
end;

function TTLS12HandshakeReader.HasPendingNonHandshake: Boolean;
begin
  Result := FHasNonHandshake;
end;

function TTLS12HandshakeReader.GetNonHandshakeContentType: Byte;
begin
  Result := FNonHandshakeContentType;
  FHasNonHandshake := False;
end;

function TTLS12HandshakeReader.GetNonHandshakeData: TBytes;
begin
  Result := FNonHandshakeData;
  FHasNonHandshake := False;
end;

end.
