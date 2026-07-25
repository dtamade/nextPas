unit nextpas.core.http.impl.h2.client.streams;
{**
 * @desc Client active-stream table helpers (lookup/add/remove/window apply).
 *       Mechanical extract from impl.h2.client (behavior freeze).
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.http.impl.h2.types;

type
  TH2ClientActiveStreamState = record
    StreamID: UInt32;
    Flow: TH2StreamFlowControl;
  end;

  TH2ClientActiveStreams = record
    Items: array of TH2ClientActiveStreamState;
    Count: SizeInt;
  end;

procedure H2ClientStreamsInit(out AStreams: TH2ClientActiveStreams);
function H2ClientStreamsFindIndex(const AStreams: TH2ClientActiveStreams;
  const AStreamID: UInt32): SizeInt;
{ Adds a stream and inits flow with peer/local initial windows. }
function H2ClientStreamsAdd(var AStreams: TH2ClientActiveStreams;
  const AStreamID: UInt32; const ARemoteInitialWindowSize: UInt32;
  const ALocalInitialWindowSize: UInt32): SizeInt;
procedure H2ClientStreamsRemove(var AStreams: TH2ClientActiveStreams;
  const AStreamID: UInt32);
procedure H2ClientStreamsApplyPeerInitialWindow(
  var AStreams: TH2ClientActiveStreams; const ANewInitialWindowSize: UInt32);

implementation

uses
  nextpas.core.errors,
  nextpas.core.http.base;

procedure H2ClientStreamsInit(out AStreams: TH2ClientActiveStreams);
begin
  AStreams.Items := nil;
  AStreams.Count := 0;
end;

function H2ClientStreamsFindIndex(const AStreams: TH2ClientActiveStreams;
  const AStreamID: UInt32): SizeInt;
var
  LI: SizeInt;
begin
  for LI := 0 to AStreams.Count - 1 do
    if AStreams.Items[LI].StreamID = AStreamID then
      Exit(LI);
  Result := -1;
end;

function H2ClientStreamsAdd(var AStreams: TH2ClientActiveStreams;
  const AStreamID: UInt32; const ARemoteInitialWindowSize: UInt32;
  const ALocalInitialWindowSize: UInt32): SizeInt;
begin
  if H2ClientStreamsFindIndex(AStreams, AStreamID) >= 0 then
    raise EHttpError.Create(hekProtocol, 'HTTP/2 client stream is already active');
  if AStreams.Count >= Length(AStreams.Items) then
    SetLength(AStreams.Items, AStreams.Count + 4);
  Result := AStreams.Count;
  AStreams.Items[Result].StreamID := AStreamID;
  AStreams.Items[Result].Flow.Init(AStreamID, ARemoteInitialWindowSize,
    ALocalInitialWindowSize);
  Inc(AStreams.Count);
end;

procedure H2ClientStreamsRemove(var AStreams: TH2ClientActiveStreams;
  const AStreamID: UInt32);
var
  LIndex: SizeInt;
begin
  LIndex := H2ClientStreamsFindIndex(AStreams, AStreamID);
  if LIndex < 0 then
    Exit;
  Dec(AStreams.Count);
  if LIndex <> AStreams.Count then
    AStreams.Items[LIndex] := AStreams.Items[AStreams.Count];
  AStreams.Items[AStreams.Count] := Default(TH2ClientActiveStreamState);
end;

procedure H2ClientStreamsApplyPeerInitialWindow(
  var AStreams: TH2ClientActiveStreams; const ANewInitialWindowSize: UInt32);
var
  LI: SizeInt;
begin
  for LI := 0 to AStreams.Count - 1 do
    AStreams.Items[LI].Flow.ApplyPeerInitialWindowSize(ANewInitialWindowSize);
end;

end.