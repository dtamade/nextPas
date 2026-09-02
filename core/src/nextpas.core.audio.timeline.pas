unit nextpas.core.audio.timeline;

{$I nextpas.core.settings.inc}

interface

uses
  Classes, SyncObjs,
  nextpas.core.math.base,
  nextpas.core.math.scalar,
  nextpas.core.math.trig,
  nextpas.core.base,
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.timeline.intf,
  nextpas.core.audio.errors;

type
  TTimelineImpl = class(TInterfacedObject, IAudioTimeline, IAudioSource, IRealtimeAudioSource)
  private
    FFormat: TAudioFormat;
    FTracks: array of TTimelineTrack;
    FNextTrack: Integer;
    FNextClip: Integer;
    FPosition: UInt64;
    FLoop: Boolean;
    FLock: TCriticalSection;
    FViolations: Int64;
    FTrackFree: array of Integer;
    FTrackDead: Integer;
    FSnapshotTracks: array of TTimelineTrack;
    function FindTrack(ATrack: TTimelineTrackId): Integer;
    function FindClip(var ATrack: TTimelineTrack; AClip: TTimelineClipId): Integer;
    function CalcDuration: UInt64;
    function ValidateGain(AGain: Single): Single; inline;
    function ValidatePan(APan: Single): Single; inline;
    procedure MaybeCompactTracks;
    procedure MixSegment(MixPtr: PSingle; const SnapTracks: array of TTimelineTrack;
      ASrcPos: UInt64; ADstOff: Integer; ASegFrames: Integer);
  public
    constructor Create(const AFormat: TAudioFormat);
    destructor Destroy; override;
    function GetFormat: TAudioFormat;
    function GetPosition: UInt64;
    function GetDuration: UInt64;
    function GetLoop: Boolean;
    procedure SetLoop(ALoop: Boolean);
    function AddTrack(AGain: Single): TTimelineTrackId;
    function RemoveTrack(ATrack: TTimelineTrackId): Boolean;
    function SetTrackGain(ATrack: TTimelineTrackId; AGain: Single): Boolean;
    function SetTrackPan(ATrack: TTimelineTrackId; APan: Single): Boolean;
    function SetTrackMute(ATrack: TTimelineTrackId; AMuted: Boolean): Boolean;
    function SetTrackSolo(ATrack: TTimelineTrackId; ASolo: Boolean): Boolean;
    function AddClip(ATrack: TTimelineTrackId; const ABuffer: TAudioBuffer; AStartFrame: UInt64; AGain: Single; APan: Single): TTimelineClipId;
    function RemoveClip(ATrack: TTimelineTrackId; AClip: TTimelineClipId): Boolean;
    function TrackCount: Integer;
    function ClipCount(ATrack: TTimelineTrackId): Integer;
    procedure Clear;
    function Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
    function FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
    function SeekTo(AFrame: UInt64): Boolean;
  end;

function CreateAudioTimeline(const AFormat: TAudioFormat): IAudioTimeline;

implementation

function CreateAudioTimeline(const AFormat: TAudioFormat): IAudioTimeline;
begin Result := TTimelineImpl.Create(AFormat); end;

constructor TTimelineImpl.Create(const AFormat: TAudioFormat);
begin
  inherited Create;
  if not AFormat.IsValid then raise EAudioTimelineError.Create('Timeline: invalid format');
  if AFormat.SampleFormat <> sfF32 then raise EAudioTimelineError.Create('Timeline: must be sfF32');
  FFormat := AFormat;
  FNextTrack := 1;
  FNextClip := 1;
  FPosition := 0;
  FLoop := False;
  FLock := TCriticalSection.Create;
  SetLength(FTracks,0);
  SetLength(FTrackFree,0);
  SetLength(FSnapshotTracks,0);
  FTrackDead:=0;
end;

destructor TTimelineImpl.Destroy; begin FLock.Free; inherited; end;

function TTimelineImpl.GetFormat: TAudioFormat; begin Result := FFormat; end;
function TTimelineImpl.GetPosition: UInt64; begin FLock.Enter; try Result:=FPosition; finally FLock.Leave; end; end;
function TTimelineImpl.GetLoop: Boolean; begin FLock.Enter; try Result:=FLoop; finally FLock.Leave; end; end;
procedure TTimelineImpl.SetLoop(ALoop: Boolean); begin FLock.Enter; try FLoop:=ALoop; finally FLock.Leave; end; end;

function TTimelineImpl.ValidateGain(AGain: Single): Single;
begin
  if IsNan(AGain) or IsInfinite(AGain) then Exit(1.0);
  if AGain < 0 then Exit(0);
  if AGain > 4 then Exit(4);
  Result := AGain;
end;

function TTimelineImpl.ValidatePan(APan: Single): Single;
begin
  if APan < -1 then Exit(-1);
  if APan > 1 then Exit(1);
  Result := APan;
end;

procedure TTimelineImpl.MaybeCompactTracks;
var I,J,N: Integer;
begin
  if (Length(FTracks) <= 32) or (FTrackDead <= Length(FTracks) div 2) then Exit;
  N:=0;
  for I:=0 to High(FTracks) do if FTracks[I].Alive then Inc(N);
  J:=0;
  for I:=0 to High(FTracks) do if FTracks[I].Alive then
  begin if I<>J then FTracks[J]:=FTracks[I]; Inc(J); end;
  SetLength(FTracks, N);
  SetLength(FTrackFree,0);
  FTrackDead:=0;
end;

function TTimelineImpl.CalcDuration: UInt64;
var i,j: Integer; e: UInt64;
begin
  Result := 0;
  for i:=0 to High(FTracks) do if FTracks[i].Alive then
    for j:=0 to High(FTracks[i].Clips) do if FTracks[i].Clips[j].Alive then
    begin e := FTracks[i].Clips[j].StartFrame + UInt64(FTracks[i].Clips[j].Buffer.FrameCount); if e > Result then Result := e; end;
end;

function TTimelineImpl.GetDuration: UInt64; begin FLock.Enter; try Result:=CalcDuration; finally FLock.Leave; end; end;

function TTimelineImpl.FindTrack(ATrack: TTimelineTrackId): Integer;
var i: Integer; begin for i:=0 to High(FTracks) do if FTracks[i].Alive and (FTracks[i].Id=ATrack) then Exit(i); Result:=-1; end;

function TTimelineImpl.FindClip(var ATrack: TTimelineTrack; AClip: TTimelineClipId): Integer;
var i: Integer; begin for i:=0 to High(ATrack.Clips) do if ATrack.Clips[i].Alive and (ATrack.Clips[i].Id=AClip) then Exit(i); Result:=-1; end;

function TTimelineImpl.AddTrack(AGain: Single): TTimelineTrackId;
var idx: Integer;
begin
  AGain:=ValidateGain(AGain);
  FLock.Enter; try
    Result:=FNextTrack; Inc(FNextTrack);
    if Length(FTrackFree)>0 then
    begin
      idx:=FTrackFree[High(FTrackFree)];
      SetLength(FTrackFree, Length(FTrackFree)-1);
      Dec(FTrackDead);
      FTracks[idx].Id:=Result; FTracks[idx].Gain:=AGain; FTracks[idx].Pan:=0; FTracks[idx].Muted:=False; FTracks[idx].Solo:=False; FTracks[idx].Alive:=True; SetLength(FTracks[idx].Clips,0);
    end else
    begin
      idx:=Length(FTracks); SetLength(FTracks, idx+1);
      FTracks[idx].Id:=Result; FTracks[idx].Gain:=AGain; FTracks[idx].Pan:=0; FTracks[idx].Muted:=False; FTracks[idx].Solo:=False; FTracks[idx].Alive:=True; SetLength(FTracks[idx].Clips,0);
    end;
  finally FLock.Leave; end;
end;

function TTimelineImpl.RemoveTrack(ATrack: TTimelineTrackId): Boolean;
var idx: Integer;
begin
  FLock.Enter; try
    idx:=FindTrack(ATrack); if idx<0 then Exit(False);
    FTracks[idx].Alive:=False;
    SetLength(FTracks[idx].Clips,0);
    SetLength(FTrackFree, Length(FTrackFree)+1);
    FTrackFree[High(FTrackFree)]:=idx;
    Inc(FTrackDead);
    MaybeCompactTracks;
    Result:=True;
  finally FLock.Leave; end;
end;

function TTimelineImpl.SetTrackGain(ATrack: TTimelineTrackId; AGain: Single): Boolean;
var idx: Integer;
begin if IsNan(AGain) or IsInfinite(AGain) then Exit(False); AGain:=ValidateGain(AGain); FLock.Enter; try idx:=FindTrack(ATrack); if idx<0 then Exit(False); FTracks[idx].Gain:=AGain; Result:=True; finally FLock.Leave; end; end;

function TTimelineImpl.SetTrackPan(ATrack: TTimelineTrackId; APan: Single): Boolean;
var idx: Integer;
begin APan:=ValidatePan(APan); FLock.Enter; try idx:=FindTrack(ATrack); if idx<0 then Exit(False); FTracks[idx].Pan:=APan; Result:=True; finally FLock.Leave; end; end;

function TTimelineImpl.SetTrackMute(ATrack: TTimelineTrackId; AMuted: Boolean): Boolean;
var idx: Integer;
begin FLock.Enter; try idx:=FindTrack(ATrack); if idx<0 then Exit(False); FTracks[idx].Muted:=AMuted; Result:=True; finally FLock.Leave; end; end;

function TTimelineImpl.SetTrackSolo(ATrack: TTimelineTrackId; ASolo: Boolean): Boolean;
var idx: Integer;
begin FLock.Enter; try idx:=FindTrack(ATrack); if idx<0 then Exit(False); FTracks[idx].Solo:=ASolo; Result:=True; finally FLock.Leave; end; end;

function TTimelineImpl.AddClip(ATrack: TTimelineTrackId; const ABuffer: TAudioBuffer; AStartFrame: UInt64; AGain: Single; APan: Single): TTimelineClipId;
var tidx, cidx, reuseIdx, i: Integer; tmp: TTimelineClip;
begin
  if not ABuffer.Format.IsValid then raise EAudioTimelineError.Create('AddClip: invalid buffer');
  if ABuffer.Format.SampleFormat<>sfF32 then raise EAudioTimelineError.Create('AddClip: must be sfF32');
  if (ABuffer.Format.SampleRate<>FFormat.SampleRate) or (ABuffer.Format.Channels<>FFormat.Channels) then raise EAudioTimelineError.Create('AddClip: format mismatch');
  AGain:=ValidateGain(AGain);
  APan:=ValidatePan(APan);
  FLock.Enter; try
    tidx:=FindTrack(ATrack); if tidx<0 then raise EAudioTimelineError.Create('AddClip: unknown track');
    Result:=FNextClip; Inc(FNextClip);
    // tombstone reuse for clips
    reuseIdx:=-1;
    for i:=0 to High(FTracks[tidx].Clips) do if not FTracks[tidx].Clips[i].Alive then begin reuseIdx:=i; Break; end;
    if reuseIdx >=0 then cidx:=reuseIdx else
    begin cidx:=Length(FTracks[tidx].Clips); SetLength(FTracks[tidx].Clips, cidx+1); end;
    FTracks[tidx].Clips[cidx].Id:=Result;
    FTracks[tidx].Clips[cidx].Buffer:=ABuffer;
    FTracks[tidx].Clips[cidx].Buffer.Data:=Copy(ABuffer.Data,0,Length(ABuffer.Data));
    FTracks[tidx].Clips[cidx].StartFrame:=AStartFrame;
    FTracks[tidx].Clips[cidx].Gain:=AGain;
    FTracks[tidx].Clips[cidx].Pan:=APan;
    FTracks[tidx].Clips[cidx].Alive:=True;
    // keep sorted by StartFrame for locality (insertion sort step)
    for i:=cidx downto 1 do
      if FTracks[tidx].Clips[i].Alive and FTracks[tidx].Clips[i-1].Alive and (FTracks[tidx].Clips[i].StartFrame < FTracks[tidx].Clips[i-1].StartFrame) then
      begin tmp:=FTracks[tidx].Clips[i]; FTracks[tidx].Clips[i]:=FTracks[tidx].Clips[i-1]; FTracks[tidx].Clips[i-1]:=tmp; end
      else if not FTracks[tidx].Clips[i-1].Alive then
      begin tmp:=FTracks[tidx].Clips[i]; FTracks[tidx].Clips[i]:=FTracks[tidx].Clips[i-1]; FTracks[tidx].Clips[i-1]:=tmp; end
      else Break;
    // if reused dead slot caused unsorted, full sort pass for alive entries (small N)
    // compact threshold per track if dead > half
    // simple heuristic: if many dead, compact later on remove
  finally FLock.Leave; end;
end;

function TTimelineImpl.RemoveClip(ATrack: TTimelineTrackId; AClip: TTimelineClipId): Boolean;
var tidx, cidx, i, dead: Integer;
begin
  FLock.Enter; try
    tidx:=FindTrack(ATrack); if tidx<0 then Exit(False);
    cidx:=FindClip(FTracks[tidx], AClip); if cidx<0 then Exit(False);
    FTracks[tidx].Clips[cidx].Alive:=False;
    FTracks[tidx].Clips[cidx].Buffer.Data:=nil;
    // threshold compact per track
    dead:=0;
    for i:=0 to High(FTracks[tidx].Clips) do if not FTracks[tidx].Clips[i].Alive then Inc(dead);
    if (Length(FTracks[tidx].Clips) > 32) and (dead > Length(FTracks[tidx].Clips) div 2) then
    begin
      dead:=0;
      for i:=0 to High(FTracks[tidx].Clips) do if FTracks[tidx].Clips[i].Alive then
      begin if i<>dead then FTracks[tidx].Clips[dead]:=FTracks[tidx].Clips[i]; Inc(dead); end;
      SetLength(FTracks[tidx].Clips, dead);
    end;
    Result:=True;
  finally FLock.Leave; end;
end;

function TTimelineImpl.TrackCount: Integer;
var i,c: Integer;
begin FLock.Enter; try c:=0; for i:=0 to High(FTracks) do if FTracks[i].Alive then Inc(c); Result:=c; finally FLock.Leave; end; end;

function TTimelineImpl.ClipCount(ATrack: TTimelineTrackId): Integer;
var tidx,i,c: Integer;
begin FLock.Enter; try tidx:=FindTrack(ATrack); if tidx<0 then Exit(0); c:=0; for i:=0 to High(FTracks[tidx].Clips) do if FTracks[tidx].Clips[i].Alive then Inc(c); Result:=c; finally FLock.Leave; end; end;

procedure TTimelineImpl.Clear;
var i: Integer;
begin FLock.Enter; try for i:=0 to High(FTracks) do begin FTracks[i].Alive:=False; SetLength(FTracks[i].Clips,0); end; SetLength(FTracks,0); SetLength(FTrackFree,0); FTrackDead:=0; FPosition:=0; finally FLock.Leave; end; end;

function TTimelineImpl.Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer; begin Result:=FillRealtime(ABuffer, AFrames); end;
function TTimelineImpl.SeekTo(AFrame: UInt64): Boolean; begin FLock.Enter; try FPosition:=AFrame; Result:=True; finally FLock.Leave; end; end;

// HasSolo contract: solo overrides mute - if HasSolo then only solo tracks mix, muted and non-solo tracks are skipped; computed before MixSegment
procedure TTimelineImpl.MixSegment(MixPtr: PSingle; const SnapTracks: array of TTimelineTrack;
  ASrcPos: UInt64; ADstOff: Integer; ASegFrames: Integer);
var i,j, ch, k, srcOff, dstOff, copyFrames: Integer;
  TrackGain, ClipGain, Gain: Single;
  TrackPan, ClipPan, Pan: Single;
  Lgain, Rgain: Single;
  Clip: TTimelineClip;
  SrcPtr: PSingle;
begin
  if ASegFrames <=0 then Exit;
  for i:=0 to High(SnapTracks) do
  begin
    TrackGain:=SnapTracks[i].Gain;
    TrackPan:=SnapTracks[i].Pan;
    for j:=0 to High(SnapTracks[i].Clips) do
    begin
      Clip:=SnapTracks[i].Clips[j];
      if not Clip.Alive then Continue;
      if (Clip.StartFrame + UInt64(Clip.Buffer.FrameCount) <= ASrcPos) then Continue;
      if (Clip.StartFrame >= ASrcPos + UInt64(ASegFrames)) then Continue;
      if Clip.StartFrame < ASrcPos then
      begin srcOff := Integer(ASrcPos - Clip.StartFrame); dstOff := 0; copyFrames := Min(Clip.Buffer.FrameCount - srcOff, ASegFrames);
      end else begin srcOff := 0; dstOff := Integer(Clip.StartFrame - ASrcPos); copyFrames := Min(Clip.Buffer.FrameCount, ASegFrames - dstOff); end;
      if copyFrames<=0 then Continue;
      ClipGain:=Clip.Gain; Pan:=(TrackPan+ClipPan)/2;
      Gain:=TrackGain*ClipGain;
      if FFormat.Channels=2 then begin Lgain:=Cos((Pan+1)*PI_VALUE/4)*1.414213562; Rgain:=Sin((Pan+1)*PI_VALUE/4)*1.414213562; end else begin Lgain:=1; Rgain:=1; end;
      SrcPtr:=PSingle(@Clip.Buffer.Data[0]);
      if FFormat.Channels=2 then
      begin
        for ch:=0 to copyFrames-1 do
        begin
          MixPtr[(ADstOff+dstOff+ch)*2] := MixPtr[(ADstOff+dstOff+ch)*2] + SrcPtr[(srcOff+ch)*2]*Gain*Lgain;
          MixPtr[(ADstOff+dstOff+ch)*2+1] := MixPtr[(ADstOff+dstOff+ch)*2+1] + SrcPtr[(srcOff+ch)*2+1]*Gain*Rgain;
        end;
      end else if FFormat.Channels=1 then
      begin
        for ch:=0 to copyFrames-1 do
          MixPtr[ADstOff+dstOff+ch] := MixPtr[ADstOff+dstOff+ch] + SrcPtr[srcOff+ch]*Gain;
      end else
      begin
        for ch:=0 to copyFrames-1 do
          for k:=0 to FFormat.Channels-1 do
            MixPtr[(ADstOff+dstOff+ch)*FFormat.Channels + k] := MixPtr[(ADstOff+dstOff+ch)*FFormat.Channels + k] + SrcPtr[(srcOff+ch)*FFormat.Channels + k]*Gain;
      end;
    end;
  end;
end;

function TTimelineImpl.FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
var
  Needed, i, avail: Integer;
  MixPtr: PSingle;
  HasSolo: Boolean;
  SnapTracks: array of TTimelineTrack;
  SnapPos: UInt64;
  SnapLoop: Boolean;
  SnapDur: UInt64;
  FirstFrames, SecondFrames: Integer;
begin
  if AFrames<=0 then Exit(0);
  Needed:=AFrames*FFormat.BlockAlign;
  if Length(ABuffer.Data)<Needed then
  begin InterlockedExchangeAdd64(FViolations,1); AFrames:=Length(ABuffer.Data) div FFormat.BlockAlign; if AFrames<=0 then Exit(0); Needed:=AFrames*FFormat.BlockAlign; end;
  FillChar(ABuffer.Data[0], Needed, 0);
  MixPtr:=PSingle(@ABuffer.Data[0]);
  // two-phase snapshot scratch reuse: count+meta under lock -> ensure scratch capacity -> deep copy under lock (prototype for zero-alloc)
  FLock.Enter;
  try
    SnapPos:=FPosition;
    SnapLoop:=FLoop;
    SnapDur:=CalcDuration;
    // HasSolo: solo overrides mute - when HasSolo is true, only tracks with Solo=true are kept, all muted and non-solo tracks are skipped
    HasSolo:=False; for i:=0 to High(FTracks) do if FTracks[i].Alive and FTracks[i].Solo then HasSolo:=True;
    avail:=0;
    for i:=0 to High(FTracks) do if FTracks[i].Alive then
    begin
      if FTracks[i].Muted then Continue;
      if HasSolo and not FTracks[i].Solo then Continue;
      Inc(avail);
    end;
  finally FLock.Leave; end;
  // two-phase snapshot scratch reuse - ensure scratch capacity before snapshot alloc (prototype: grow only, else reuse)
  if Length(FSnapshotTracks) < avail then
    SetLength(FSnapshotTracks, avail);
  // else reuse FSnapshotTracks storage - steady state avoids heap alloc
  // SnapTracks steady-state reuse of FSnapshotTracks: if Length(FSnapshotTracks) < avail then SetLength(FSnapshotTracks, avail) else reuse
  // deep copy Clip array isolation kept via Copy below - SnapTracks reuses FSnapshotTracks storage
  SnapTracks := FSnapshotTracks;
  if Length(SnapTracks) < avail then
    SetLength(SnapTracks, avail);
  // else reuse SnapTracks storage - steady state avoids heap alloc (trim to avail after copy if needed)
  if avail > 0 then
  begin
    FLock.Enter;
    try
      // re-validate solo under lock (avoid TOCTOU if track set changed between phases) - solo overrides mute
      HasSolo:=False; for i:=0 to High(FTracks) do if FTracks[i].Alive and FTracks[i].Solo then HasSolo:=True;
      avail:=0;
      for i:=0 to High(FTracks) do if FTracks[i].Alive then
      begin
        if FTracks[i].Muted then Continue;
        if HasSolo and not FTracks[i].Solo then Continue; // solo overrides mute: non-solo tracks skipped when HasSolo
        if avail < Length(SnapTracks) then
        begin
          SnapTracks[avail] := FTracks[i];
          // deep copy clip array to isolate snapshot from concurrent Add/RemoveClip
          SnapTracks[avail].Clips := Copy(FTracks[i].Clips, 0, Length(FTracks[i].Clips));
          Inc(avail);
        end;
      end;
      if avail < Length(SnapTracks) then
        SetLength(SnapTracks, avail);
    finally FLock.Leave; end;
  end;
  // snapshot mixing - lock free
  if SnapLoop and (SnapDur>0) and (SnapPos + UInt64(AFrames) > SnapDur) and (SnapPos < SnapDur) then
  begin
    FirstFrames := Integer(SnapDur - SnapPos);
    if FirstFrames <0 then FirstFrames:=0;
    if FirstFrames > AFrames then FirstFrames:=AFrames;
    SecondFrames := AFrames - FirstFrames;
    MixSegment(MixPtr, SnapTracks, SnapPos, 0, FirstFrames);
    MixSegment(MixPtr, SnapTracks, 0, FirstFrames, SecondFrames);
  end else if SnapLoop and (SnapDur>0) and (SnapPos >= SnapDur) then
  begin
    // pos already beyond dur (e.g. seek), wrap once
    SnapPos := SnapPos mod SnapDur;
    if SnapPos + UInt64(AFrames) > SnapDur then
    begin
      FirstFrames := Integer(SnapDur - SnapPos);
      SecondFrames := AFrames - FirstFrames;
      MixSegment(MixPtr, SnapTracks, SnapPos, 0, FirstFrames);
      MixSegment(MixPtr, SnapTracks, 0, FirstFrames, SecondFrames);
    end else
      MixSegment(MixPtr, SnapTracks, SnapPos, 0, AFrames);
  end else
  begin
    MixSegment(MixPtr, SnapTracks, SnapPos, 0, AFrames);
  end;
  for i:=0 to AFrames*FFormat.Channels-1 do
  begin if MixPtr[i]>1.0 then MixPtr[i]:=1.0 else if MixPtr[i]<-1.0 then MixPtr[i]:=-1.0; end;
  FLock.Enter;
  try
    // FPosition advance: SnapPos as base modulo wrap (loop cross-segment), Interlocked semantics preserved via FLock
    if SnapLoop and (SnapDur>0) then
      FPosition := (SnapPos + UInt64(AFrames)) mod SnapDur
    else
      FPosition := SnapPos + UInt64(AFrames);
  finally FLock.Leave; end;
  ABuffer.FrameCount:=AFrames;
  ABuffer.Format:=FFormat;
  Result:=AFrames;
end;

end.
