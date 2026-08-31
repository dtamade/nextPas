unit nextpas.core.git.native.sideband;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.git.native.base,
  nextpas.core.git.native.pktline,
  nextpas.core.git.native.util;

{ Sideband multiplex demux (transports/smart_pkt.c + pack-protocol.txt).

  When capabilities include side-band / side-band-64k, the server
  multiplexes the packfile:
    pkt-line payload = chr(channel) + data
      channel 1 = packfile bytes (binary, may contain NUL)
      channel 2 = progress messages (text)
      channel 3 = error messages (text)
  Each pkt-line is still framed with 4-hex length. Flush terminates.
  This unit provides encode/decode for a single channel packet and a
  stream demuxer that separates channels while preserving binary fidelity
  for channel 1. }

type
  TGitSidebandKind = (gsbData = 1, gsbProgress = 2, gsbError = 3);
  TGitSideband = record
    Kind: TGitSidebandKind;
    Data: TBytes;
  end;
  TGitSidebandArray = array of TGitSideband;
  TGitSidebandDemuxed = record
    DataBytes: TBytes;
    Progress: TStringArray;
    Errors: TStringArray;
    Raw: TGitSidebandArray;
  end;

function GitSidebandEncode(AKind: TGitSidebandKind; const AData: TBytes): TBytes; inline;
function GitSidebandEncodeStr(AKind: TGitSidebandKind; const AText: string): TBytes; inline;
function GitSidebandDecode(const APktData: TBytes; out AKind: TGitSidebandKind; out APayload: TBytes): Boolean; inline;
procedure GitSidebandDemux(const AStream: TBytes; out ADemuxed: TGitSidebandDemuxed); inline;
function GitSidebandDemuxRaw(const AStream: TBytes): TGitSidebandArray; inline;
function GitSidebandJoin(const AEntries: TGitSidebandArray): TBytes;

implementation

function GitSidebandEncode(AKind: TGitSidebandKind; const AData: TBytes): TBytes;
var
  Payload: TBytes;
begin
  if (Ord(AKind) < 1) or (Ord(AKind) > 3) then
    raise EGitError.CreateFmt('sideband invalid channel %d', [Ord(AKind)]);
  SetLength(Payload, Length(AData) + 1);
  Payload[0] := Byte(AKind);
  if Length(AData) > 0 then
    Move(AData[0], Payload[1], Length(AData));
  Result := GitPktEncode(Payload);
end;

function GitSidebandEncodeStr(AKind: TGitSidebandKind; const AText: string): TBytes;
begin
  Result := GitSidebandEncode(AKind, GitStringToBytes(AText));
end;

function GitSidebandDecode(const APktData: TBytes; out AKind: TGitSidebandKind; out APayload: TBytes): Boolean;
var
  C: Byte;
begin
  Result := False;
  AKind := gsbData;
  APayload := nil;
  if Length(APktData) < 1 then
    raise EGitError.Create('sideband packet empty (no channel byte)');
  C := APktData[0];
  if (C < 1) or (C > 3) then
    raise EGitError.CreateFmt('sideband invalid channel %d', [C]);
  AKind := TGitSidebandKind(C);
  SetLength(APayload, Length(APktData) - 1);
  if Length(APayload) > 0 then
    Move(APktData[1], APayload[0], Length(APayload));
  Result := True;
end;

function GitSidebandDemuxRaw(const AStream: TBytes): TGitSidebandArray;
var
  Pkts: TGitPktArray;
  I: Integer;
  Kind: TGitSidebandKind;
  Payload: TBytes;
  Item: TGitSideband;
begin
  Result := nil;
  if Length(AStream) = 0 then Exit;
  Pkts := GitPktScan(AStream);
  for I := 0 to High(Pkts) do
  begin
    if Pkts[I].Kind = gpkFlush then Break;
    if Pkts[I].Kind = gpkDelim then Continue;
    // gpkData -> must be sideband packet
    GitSidebandDecode(Pkts[I].Data, Kind, Payload);
    Item.Kind := Kind;
    Item.Data := Payload;
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := Item;
  end;
end;

procedure GitSidebandDemux(const AStream: TBytes; out ADemuxed: TGitSidebandDemuxed); inline;
var
  Arr: TGitSidebandArray;
  I: Integer;
  LTotal, LOff: SizeUInt;
  Txt: string;
begin
  Arr := GitSidebandDemuxRaw(AStream);
  ADemuxed.Raw := Arr;
  ADemuxed.DataBytes := nil;
  ADemuxed.Progress := nil;
  ADemuxed.Errors := nil;
  // single allocation zero-copy: pre-sum avoids O(n²) SetLength/Move and heap fragmentation
  LTotal := 0;
  for I := 0 to High(Arr) do
    if Arr[I].Kind = gsbData then
      Inc(LTotal, Length(Arr[I].Data));
  SetLength(ADemuxed.DataBytes, LTotal);
  LOff := 0;
  for I := 0 to High(Arr) do
  begin
    case Arr[I].Kind of
      gsbData:
        begin
          if Length(Arr[I].Data) > 0 then
            Move(Arr[I].Data[0], ADemuxed.DataBytes[LOff], Length(Arr[I].Data));
          Inc(LOff, Length(Arr[I].Data));
        end;
      gsbProgress:
        begin
          Txt := GitBytesToString(Arr[I].Data);
          SetLength(ADemuxed.Progress, Length(ADemuxed.Progress) + 1);
          ADemuxed.Progress[High(ADemuxed.Progress)] := Txt;
        end;
      gsbError:
        begin
          Txt := GitBytesToString(Arr[I].Data);
          SetLength(ADemuxed.Errors, Length(ADemuxed.Errors) + 1);
          ADemuxed.Errors[High(ADemuxed.Errors)] := Txt;
        end;
    end;
  end;
end;

function GitSidebandJoin(const AEntries: TGitSidebandArray): TBytes;
var
  I, Total, Off: Integer;
  Enc: TBytes;
begin
  // single-encode: first pass sums frame sizes (4 header + 1 channel + payload)
  // without allocating Enc; second pass encodes once and zero-copies via Move
  Total := 0;
  for I := 0 to High(AEntries) do
  begin
    if (Ord(AEntries[I].Kind) < 1) or (Ord(AEntries[I].Kind) > 3) then
      raise EGitError.CreateFmt('sideband invalid channel %d', [Ord(AEntries[I].Kind)]);
    Inc(Total, 5 + Length(AEntries[I].Data));
  end;
  SetLength(Result, Total);
  Off := 0;
  for I := 0 to High(AEntries) do
  begin
    Enc := GitSidebandEncode(AEntries[I].Kind, AEntries[I].Data);
    if Length(Enc) > 0 then
      Move(Enc[0], Result[Off], Length(Enc));
    Inc(Off, Length(Enc));
  end;
end;

end.
