unit nextpas.core.git.native.pktline;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.git.native.base;

{ Git pkt-line framing (transport/smart_protocol.c / Documentation/technical/protocol-common.txt).

  Frame layout:
    4 HEXDIG length including the 4-byte header, MANDATORY lower-case or
    upper-case hex.  `0000` flush-pkt, `0001` delim-pkt, otherwise
    `0004`+payload with payload length = len-4. Zero-length payload
    (len=4) is forbidden. Maximum len `ffff` (65535) caps payload at
    65531 bytes. Decoder rejects non-hex header, lengths <4 with non-zero,
    or truncated buffers. }

const
  GitPktMaxSize = $FFFF;
  GitPktHeaderSize = 4;
  GitPktFlushStr = '0000';
  GitPktDelimStr = '0001';

type
  TGitPktKind = (gpkFlush, gpkDelim, gpkData);
  TGitPkt = record
    Kind: TGitPktKind;
    Data: TBytes;
  end;
  TGitPktArray = array of TGitPkt;

function GitPktEncode(const AData: TBytes): TBytes; inline;
function GitPktEncodeStr(const AText: string): TBytes; inline;
function GitPktEncodeFlush: TBytes; inline;
function GitPktEncodeDelim: TBytes; inline;
function GitPktDecode(const AFrame: TBytes; out APkt: TGitPkt): Boolean; inline;
function GitPktIsFlush(const AFrame: TBytes): Boolean; inline;
function GitPktIsDelim(const AFrame: TBytes): Boolean; inline;
function GitPktScan(const AStream: TBytes): TGitPktArray; inline;
function GitPktJoin(const APkts: TGitPktArray): TBytes; inline;

implementation

uses
  nextpas.core.bytes.ops;

function HexNibble(AVal: Byte): Char; inline;
begin
  if AVal < 10 then Result := Chr(Ord('0') + AVal)
  else Result := Chr(Ord('a') + AVal - 10);
end;

function IsHexDigit(C: Char): Boolean; inline;
begin
  Result := ((C >= '0') and (C <= '9')) or ((C >= 'a') and (C <= 'f')) or ((C >= 'A') and (C <= 'F'));
end;

function HexVal(C: Char): Integer; inline;
begin
  if (C >= '0') and (C <= '9') then Exit(Ord(C) - Ord('0'));
  if (C >= 'a') and (C <= 'f') then Exit(Ord(C) - Ord('a') + 10);
  if (C >= 'A') and (C <= 'F') then Exit(Ord(C) - Ord('A') + 10);
  Result := -1;
end;

function GitPktEncode(const AData: TBytes): TBytes;
var
  L: Integer;
begin
  Result := nil;
  if Length(AData) = 0 then
    raise EGitError.Create('pkt-line data payload must not be empty (len 0004 forbidden)');
  L := Length(AData) + 4;
  if L > GitPktMaxSize then
    raise EGitError.CreateFmt('pkt-line too large %d > %d', [L, GitPktMaxSize]);
  SetLength(Result, L);
  Result[0] := Byte(HexNibble((L shr 12) and $F));
  Result[1] := Byte(HexNibble((L shr 8) and $F));
  Result[2] := Byte(HexNibble((L shr 4) and $F));
  Result[3] := Byte(HexNibble(L and $F));
  if Length(AData) > 0 then
    Move(AData[0], Result[4], Length(AData));
end;

function GitPktEncodeStr(const AText: string): TBytes;
var
  B: TBytes;
  I: Integer;
begin
  SetLength(B, Length(AText));
  for I := 1 to Length(AText) do
    B[I-1] := Byte(AText[I]);
  Result := GitPktEncode(B);
end;

function GitPktEncodeFlush: TBytes;
begin
  SetLength(Result, 4);
  Result[0] := Ord('0');
  Result[1] := Ord('0');
  Result[2] := Ord('0');
  Result[3] := Ord('0');
end;

function GitPktEncodeDelim: TBytes;
begin
  SetLength(Result, 4);
  Result[0] := Ord('0');
  Result[1] := Ord('0');
  Result[2] := Ord('0');
  Result[3] := Ord('1');
end;

function GitPktIsFlush(const AFrame: TBytes): Boolean;
begin
  Result := (Length(AFrame) = 4) and (AFrame[0] = Ord('0')) and (AFrame[1] = Ord('0')) and (AFrame[2] = Ord('0')) and (AFrame[3] = Ord('0'));
end;

function GitPktIsDelim(const AFrame: TBytes): Boolean;
begin
  Result := (Length(AFrame) = 4) and (AFrame[0] = Ord('0')) and (AFrame[1] = Ord('0')) and (AFrame[2] = Ord('0')) and (AFrame[3] = Ord('1'));
end;

function GitPktDecode(const AFrame: TBytes; out APkt: TGitPkt): Boolean;
var
  Len: Integer;
  I: Integer;
  H: Integer;
begin
  Result := False;
  APkt.Kind := gpkFlush;
  APkt.Data := nil;
  if Length(AFrame) < 4 then
    raise EGitError.CreateFmt('pkt-line truncated header %d < 4', [Length(AFrame)]);
  for I := 0 to 3 do
    if not IsHexDigit(Char(AFrame[I])) then
      raise EGitError.CreateFmt('pkt-line bad hex "%s"', [Chr(AFrame[0])+Chr(AFrame[1])+Chr(AFrame[2])+Chr(AFrame[3])]);
  H := 0;
  for I := 0 to 3 do
    H := (H shl 4) or HexVal(Char(AFrame[I]));
  Len := H;
  if Len = 0 then
  begin
    if Length(AFrame) <> 4 then
      raise EGitError.Create('pkt-line flush must be exactly 0000');
    APkt.Kind := gpkFlush;
    APkt.Data := nil;
    Exit(True);
  end;
  if Len = 1 then
  begin
    if Length(AFrame) <> 4 then
      raise EGitError.Create('pkt-line delim must be exactly 0001');
    APkt.Kind := gpkDelim;
    APkt.Data := nil;
    Exit(True);
  end;
  if Len < 4 then
    raise EGitError.CreateFmt('pkt-line invalid length %d < 4', [Len]);
  if Len > GitPktMaxSize then
    raise EGitError.CreateFmt('pkt-line length %d > max', [Len]);
  if Length(AFrame) < Len then
    raise EGitError.CreateFmt('pkt-line truncated payload %d < %d', [Length(AFrame), Len]);
  if Length(AFrame) > Len then
    raise EGitError.CreateFmt('pkt-line excess bytes %d > %d', [Length(AFrame), Len]);
  if Len = 4 then
    raise EGitError.Create('pkt-line empty payload (0004) forbidden');
  APkt.Kind := gpkData;
  SetLength(APkt.Data, Len - 4);
  if Len - 4 > 0 then
    Move(AFrame[4], APkt.Data[0], Len - 4);
  Result := True;
end;

function GitPktScan(const AStream: TBytes): TGitPktArray; inline;
var
  Pos, Len, H, I, Count, Idx: Integer;
begin
  Result := nil;
  // Pass 1: count packets + validate headers — no per-packet alloc, preserves EGitError semantics
  Pos := 0;
  Count := 0;
  while Pos < Length(AStream) do
  begin
    if Pos + 4 > Length(AStream) then
      raise EGitError.CreateFmt('pkt-line scan truncated at %d', [Pos]);
    for I := 0 to 3 do
      if not IsHexDigit(Char(AStream[Pos+I])) then
        raise EGitError.CreateFmt('pkt-line scan bad hex at %d', [Pos]);
    H := 0;
    for I := 0 to 3 do
      H := (H shl 4) or HexVal(Char(AStream[Pos+I]));
    Len := H;
    if Len = 0 then
      Inc(Pos, 4)
    else if Len = 1 then
      Inc(Pos, 4)
    else
    begin
      if Len < 4 then
        raise EGitError.CreateFmt('pkt-line scan invalid len %d at %d', [Len, Pos]);
      if Len > GitPktMaxSize then
        raise EGitError.CreateFmt('pkt-line length %d > max', [Len]);
      if Len = 4 then
        raise EGitError.Create('pkt-line empty payload (0004) forbidden');
      if Pos + Len > Length(AStream) then
        raise EGitError.CreateFmt('pkt-line scan truncated payload need %d have %d', [Len, Length(AStream)-Pos]);
      Inc(Pos, Len);
    end;
    Inc(Count);
  end;
  if Count = 0 then Exit;
  // Single allocation — eliminates O(n²) growth; resource released by managed array on exception
  SetLength(Result, Count);
  // Pass 2: zero-copy fill — single Move per data payload directly from stream slice, no Frame temp
  Pos := 0;
  Idx := 0;
  while Pos < Length(AStream) do
  begin
    H := 0;
    for I := 0 to 3 do
      H := (H shl 4) or HexVal(Char(AStream[Pos+I]));
    Len := H;
    if Len = 0 then
    begin
      Result[Idx].Kind := gpkFlush;
      Result[Idx].Data := nil;
      Inc(Pos, 4);
    end
    else if Len = 1 then
    begin
      Result[Idx].Kind := gpkDelim;
      Result[Idx].Data := nil;
      Inc(Pos, 4);
    end
    else
    begin
      Result[Idx].Kind := gpkData;
      SetLength(Result[Idx].Data, Len - 4);
      if Len - 4 > 0 then
        Move(AStream[Pos + 4], Result[Idx].Data[0], Len - 4);
      Inc(Pos, Len);
    end;
    Inc(Idx);
  end;
end;

function GitPktJoin(const APkts: TGitPktArray): TBytes; inline;
var
  I, Total, Off, L: Integer;
begin
  Total := 0;
  for I := 0 to High(APkts) do
    case APkts[I].Kind of
      gpkFlush: Inc(Total, 4);
      gpkDelim: Inc(Total, 4);
      gpkData:
        begin
          if Length(APkts[I].Data) = 0 then
            raise EGitError.Create('pkt-line data payload must not be empty (len 0004 forbidden)');
          L := Length(APkts[I].Data) + 4;
          if L > GitPktMaxSize then
            raise EGitError.CreateFmt('pkt-line too large %d > %d', [L, GitPktMaxSize]);
          Inc(Total, L);
        end;
    end;
  SetLength(Result, Total);
  Off := 0;
  // zero-copy: single allocation + direct header encode + single Move per payload (no Enc temp)
  for I := 0 to High(APkts) do
    case APkts[I].Kind of
      gpkFlush:
        begin
          Result[Off] := Ord('0'); Result[Off+1] := Ord('0');
          Result[Off+2] := Ord('0'); Result[Off+3] := Ord('0');
          Inc(Off, 4);
        end;
      gpkDelim:
        begin
          Result[Off] := Ord('0'); Result[Off+1] := Ord('0');
          Result[Off+2] := Ord('0'); Result[Off+3] := Ord('1');
          Inc(Off, 4);
        end;
      gpkData:
        begin
          L := Length(APkts[I].Data) + 4;
          Result[Off] := Byte(HexNibble((L shr 12) and $F));
          Result[Off+1] := Byte(HexNibble((L shr 8) and $F));
          Result[Off+2] := Byte(HexNibble((L shr 4) and $F));
          Result[Off+3] := Byte(HexNibble(L and $F));
          if Length(APkts[I].Data) > 0 then
            Move(APkts[I].Data[0], Result[Off+4], Length(APkts[I].Data));
          Inc(Off, L);
        end;
    end;
end;

end.
