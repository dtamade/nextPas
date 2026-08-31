unit nextpas.core.git.native.negotiate;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.git.native.base,
  nextpas.core.git.native.pktline,
  nextpas.core.git.native.util;

{ Fetch negotiation helpers (transports/smart_pkt.c + protocol-common.txt).

  Client → server:
    want <oid> [caps SP-separated] LF   (caps only on first want, space-joined)
    have <oid> LF
    done LF
  Each line is a pkt-line; wants block ends with flush (0000).
  Server → client:
    ACK <oid> [ SP status ] LF  where status in {continue, common, ready}
    NAK LF
  ACK/NAK are also pkt-lines. }

type
  TGitAckStatus = (gasNak, gasAck, gasCommon, gasContinue, gasReady);
  TGitAck = record
    Status: TGitAckStatus;
    Oid: TGitOid;
    HasOid: Boolean;
  end;
  TGitAckArray = array of TGitAck;

function GitEncodeWant(const AOid: TGitOid; const ACaps: TStringArray): TBytes; inline;
function GitEncodeWantSimple(const AOid: TGitOid): TBytes; inline;
function GitEncodeWants(const AOids: array of TGitOid; const ACaps: TStringArray): TBytes;
function GitEncodeHave(const AOid: TGitOid): TBytes; inline;
function GitEncodeDone: TBytes; inline;
function GitParseAck(const AData: TBytes; out AAck: TGitAck): Boolean;
function GitParseAckLine(const ALine: string; out AAck: TGitAck): Boolean;
function GitParseAckStream(const AStream: TBytes): TGitAckArray;

implementation

function CapsToStr(const ACaps: TStringArray): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(ACaps) do
  begin
    if I > 0 then Result := Result + ' ';
    Result := Result + ACaps[I];
  end;
end;

function GitEncodeWant(const AOid: TGitOid; const ACaps: TStringArray): TBytes;
var
  Line: string;
  Caps: string;
begin
  Caps := CapsToStr(ACaps);
  if Caps <> '' then
    Line := 'want ' + GitOidToHex(AOid) + ' ' + Caps + #10
  else
    Line := 'want ' + GitOidToHex(AOid) + #10;
  Result := GitPktEncodeStr(Line);
end;

function GitEncodeWantSimple(const AOid: TGitOid): TBytes;
begin
  Result := GitEncodeWant(AOid, nil);
end;

function GitEncodeWants(const AOids: array of TGitOid; const ACaps: TStringArray): TBytes;
var
  I: Integer;
  Part: TBytes;
  Total, Off: Integer;
  Pieces: array of TBytes;
begin
  if Length(AOids) = 0 then
    raise EGitError.Create('wants must not be empty');
  SetLength(Pieces, Length(AOids) + 1);
  for I := 0 to High(AOids) do
  begin
    if I = 0 then
      Pieces[I] := GitEncodeWant(AOids[I], ACaps)
    else
      Pieces[I] := GitEncodeWantSimple(AOids[I]);
  end;
  Pieces[High(Pieces)] := GitPktEncodeFlush;
  Total := 0;
  for I := 0 to High(Pieces) do
    Inc(Total, Length(Pieces[I]));
  SetLength(Result, Total);
  Off := 0;
  for I := 0 to High(Pieces) do
  begin
    Part := Pieces[I];
    if Length(Part) > 0 then
    begin
      Move(Part[0], Result[Off], Length(Part));
      Inc(Off, Length(Part));
    end;
  end;
end;

function GitEncodeHave(const AOid: TGitOid): TBytes;
begin
  Result := GitPktEncodeStr('have ' + GitOidToHex(AOid) + #10);
end;

function GitEncodeDone: TBytes;
begin
  Result := GitPktEncodeStr('done'#10);
end;

function GitParseAckLine(const ALine: string; out AAck: TGitAck): Boolean;
var
  S, OidHex, Rest: string;
  Sp: Integer;
begin
  Result := False;
  AAck.Status := gasNak;
  AAck.HasOid := False;
  AAck.Oid := Default(TGitOid);
  S := ALine;
  if (Length(S) > 0) and (S[Length(S)] = #10) then
    SetLength(S, Length(S) - 1);
  if S = 'NAK' then
  begin
    AAck.Status := gasNak;
    AAck.HasOid := False;
    Exit(True);
  end;
  if Copy(S, 1, 4) <> 'ACK ' then
    Exit(False);
  S := Copy(S, 5, MaxInt);
  if Length(S) < 40 then Exit(False);
  OidHex := Copy(S, 1, 40);
  if not GitOidIsValidHex(OidHex) then Exit(False);
  AAck.Oid := GitOidFromHex(OidHex);
  AAck.HasOid := True;
  Rest := Copy(S, 41, MaxInt);
  if Rest = '' then
  begin
    AAck.Status := gasAck;
    Exit(True);
  end;
  if Rest[1] <> ' ' then Exit(False);
  Rest := Copy(Rest, 2, MaxInt);
  if Rest = 'continue' then AAck.Status := gasContinue
  else if Rest = 'common' then AAck.Status := gasCommon
  else if Rest = 'ready' then AAck.Status := gasReady
  else Exit(False);
  Result := True;
end;

function GitParseAck(const AData: TBytes; out AAck: TGitAck): Boolean;
var
  Line: string;
begin
  Line := GitBytesToString(AData);
  Result := GitParseAckLine(Line, AAck);
  if not Result then
    raise EGitError.CreateFmt('invalid ACK/NAK line "%s"', [Line]);
end;

function GitParseAckStream(const AStream: TBytes): TGitAckArray;
var
  Pkts: TGitPktArray;
  I: Integer;
  Ack: TGitAck;
begin
  Result := nil;
  if Length(AStream) = 0 then Exit;
  Pkts := GitPktScan(AStream);
  for I := 0 to High(Pkts) do
  begin
    if Pkts[I].Kind = gpkFlush then Break;
    if Pkts[I].Kind = gpkDelim then Continue;
    if Pkts[I].Kind = gpkData then
    begin
      if GitParseAck(Pkts[I].Data, Ack) then
      begin
        SetLength(Result, Length(Result) + 1);
        Result[High(Result)] := Ack;
      end;
    end;
  end;
end;

end.
