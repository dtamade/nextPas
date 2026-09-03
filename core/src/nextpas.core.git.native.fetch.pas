unit nextpas.core.git.native.fetch;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.git.native.base;

{ Fetch-pack client — stateless RPC against `git upload-pack`.

  Pure-Pascal counterpart of `fetch-pack.c` / `transport` fetch path.
  It speaks the smart protocol over a local `git upload-pack --stateless-rpc`
  subprocess (no network, no libgit2), reusing the pkt-line / negotiate /
  sideband / indexer primitives.

  Request: `want <oid> <caps>` (first want carries `side-band-64k ofs-delta
  multi_ack`), additional `want`s, optional `have`s, `done` + flush.
  Response: `ACK`/`NAK` pkt-lines followed by sideband-64k multiplexed pack
  (`chr(1)` pack bytes, `chr(2)` progress, `chr(3)` error) terminated by
  flush. The pack bytes are demuxed and returned; caller can feed them to
  `GitBuildPackIndex` and `TPackFile`.

  Thin packs (server requests missing bases) are rejected — the test fixtures
  are self-contained. Errors from the server's sideband channel 3 are
  surfaced as `EGitError`. }

function GitFetchPack(const ARemoteGitDir: string; const AWants: array of TGitOid): TBytes; overload;
function GitFetchPack(const ARemoteGitDir: string; const AWants: array of TGitOid; const AHaves: array of TGitOid): TBytes; overload;
function GitFetchPackSingle(const ARemoteGitDir: string; const AWant: TGitOid): TBytes; inline;

implementation

uses
  nextpas.core.fs,
  nextpas.core.process,
  nextpas.core.hash.sha1,
  nextpas.core.text.conv,
  nextpas.core.bytes.ops,
  nextpas.core.git.native.pktline,
  nextpas.core.git.native.negotiate,
  nextpas.core.git.native.sideband;

function GitFetchPack(const ARemoteGitDir: string; const AWants: array of TGitOid; const AHaves: array of TGitOid): TBytes;
var
  Request: TBytes;
  Caps: TStringArray;
  I: Integer;
  Out_: TProcessOutput;
  RespBytes: TBytes;
  Pkts: TGitPktArray;
  Pkt: TGitPkt;
  Demuxed: TGitSidebandDemuxed;
  HasPack: Boolean;
  ErrMsg: string;
  Kind: TGitSidebandKind;
  Payload: TBytes;
  Parts: array of TBytes;
  PartCount: Integer;
  DataParts: array of TBytes;
  DataPartCount: Integer;
  ProgressCount, ErrorCount, RawCount: Integer;
begin
  if Length(AWants) = 0 then
    raise EGitError.Create('fetch: want list empty');
  if not DirectoryExists(ARemoteGitDir) then
    if not FileExists(ARemoteGitDir) then
      raise EGitError.CreateFmt('fetch: remote not found %s', [ARemoteGitDir]);
  SetLength(Caps, 3);
  Caps[0] := 'side-band-64k';
  Caps[1] := 'ofs-delta';
  Caps[2] := 'multi_ack';
  { 单次直连：先收集 Parts 再 BytesConcatMany 一次分配，替代循环 ConcatBytes O(n²) }
  SetLength(Parts, Length(AWants) + Length(AHaves) + 4);
  PartCount := 0;
  for I := 0 to High(AWants) do
  begin
    if I = 0 then
      Parts[PartCount] := GitEncodeWant(AWants[I], Caps)
    else
      Parts[PartCount] := GitEncodeWantSimple(AWants[I]);
    Inc(PartCount);
  end;
  Parts[PartCount] := GitPktEncodeFlush; Inc(PartCount);
  for I := 0 to High(AHaves) do
  begin
    Parts[PartCount] := GitEncodeHave(AHaves[I]); Inc(PartCount);
  end;
  Parts[PartCount] := GitEncodeDone; Inc(PartCount);
  Parts[PartCount] := GitPktEncodeFlush; Inc(PartCount);
  SetLength(Parts, PartCount);
  Request := BytesConcatMany(Parts);

  Out_ := RunWithInput('git', ['upload-pack', '--stateless-rpc', ARemoteGitDir], Request);
  if not ProcessSucceeded(Out_) then
  begin
    ErrMsg := Out_.StdErr;
    if ErrMsg = '' then ErrMsg := Out_.StdOut;
    raise EGitError.CreateFmt('upload-pack failed (%d): %s', [Out_.ExitCode, Trim(ErrMsg)]);
  end;
  RespBytes := StringToBytes(Out_.StdOut);
  if Length(RespBytes) = 0 then
    raise EGitError.Create('fetch: empty response from upload-pack');
  Pkts := GitPktScan(RespBytes);
  Demuxed.DataBytes := nil;
  Demuxed.Progress := nil;
  Demuxed.Errors := nil;
  Demuxed.Raw := nil;
  HasPack := False;
  { 响应侧与请求侧一致：收集 DataParts 再 BytesConcatMany 一次分配，消除循环内 SetLength+Move O(n²) }
  SetLength(DataParts, Length(Pkts));
  DataPartCount := 0;
  SetLength(Demuxed.Progress, Length(Pkts));
  ProgressCount := 0;
  SetLength(Demuxed.Errors, Length(Pkts));
  ErrorCount := 0;
  SetLength(Demuxed.Raw, Length(Pkts));
  RawCount := 0;
  for I := 0 to High(Pkts) do
  begin
    Pkt := Pkts[I];
    if Pkt.Kind = gpkFlush then Continue;
    if Pkt.Kind = gpkDelim then Continue;
    if Pkt.Kind <> gpkData then Continue;
    if Length(Pkt.Data) = 0 then Continue;
    if (Length(Pkt.Data) >= 3) and (Pkt.Data[0] = Ord('E')) and (Pkt.Data[1] = Ord('R')) and (Pkt.Data[2] = Ord('R')) then
      raise EGitError.Create('fetch: server ERR: ' + Trim(BytesToString(Pkt.Data)));
    if (Length(Pkt.Data) >= 3) and (Pkt.Data[0] = Ord('N')) and (Pkt.Data[1] = Ord('A')) and (Pkt.Data[2] = Ord('K')) then
      Continue;
    if (Length(Pkt.Data) >= 3) and (Pkt.Data[0] = Ord('A')) and (Pkt.Data[1] = Ord('C')) and (Pkt.Data[2] = Ord('K')) then
      Continue;
    if (Pkt.Data[0] >= 1) and (Pkt.Data[0] <= 3) then
    begin
      if not GitSidebandDecode(Pkt.Data, Kind, Payload) then
        raise EGitError.CreateFmt('fetch: bad sideband channel %d', [Pkt.Data[0]]);
      case Kind of
        gsbData:
          begin
            DataParts[DataPartCount] := Payload;
            Inc(DataPartCount);
            Demuxed.Raw[RawCount].Kind := Kind;
            Demuxed.Raw[RawCount].Data := Payload;
            Inc(RawCount);
            HasPack := True;
          end;
        gsbProgress:
          begin
            Demuxed.Progress[ProgressCount] := BytesToString(Payload);
            Inc(ProgressCount);
            Demuxed.Raw[RawCount].Kind := Kind;
            Demuxed.Raw[RawCount].Data := Payload;
            Inc(RawCount);
          end;
        gsbError:
          begin
            Demuxed.Errors[ErrorCount] := BytesToString(Payload);
            Inc(ErrorCount);
            Demuxed.Raw[RawCount].Kind := Kind;
            Demuxed.Raw[RawCount].Data := Payload;
            Inc(RawCount);
          end;
      end;
    end;
  end;
  SetLength(DataParts, DataPartCount);
  Demuxed.DataBytes := BytesConcatMany(DataParts);
  SetLength(Demuxed.Progress, ProgressCount);
  SetLength(Demuxed.Errors, ErrorCount);
  SetLength(Demuxed.Raw, RawCount);
  if not HasPack then
  begin
    Result := nil;
    Exit;
  end;
  if Length(Demuxed.Errors) > 0 then
  begin
    ErrMsg := Demuxed.Errors[0];
    for I := 1 to High(Demuxed.Errors) do ErrMsg := ErrMsg + LineEnding + Demuxed.Errors[I];
    raise EGitError.Create('fetch: server error: ' + Trim(ErrMsg));
  end;
  Result := Demuxed.DataBytes;
  if Length(Result) > 0 then
  begin
    if (Length(Result) < 12 + 20) or (Result[0] <> Ord('P')) then
      raise EGitError.Create('fetch: invalid pack header');
  end;
end;

function GitFetchPack(const ARemoteGitDir: string; const AWants: array of TGitOid): TBytes;
var
  Empty: array of TGitOid;
begin
  SetLength(Empty, 0);
  Result := GitFetchPack(ARemoteGitDir, AWants, Empty);
end;

function GitFetchPackSingle(const ARemoteGitDir: string; const AWant: TGitOid): TBytes;
var
  Arr: array[0..0] of TGitOid;
begin
  Arr[0] := AWant;
  Result := GitFetchPack(ARemoteGitDir, Arr);
end;

end.
