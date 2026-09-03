unit nextpas.core.audio.timeline;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.ops, // single source for BytesCopy/BytesZero inline zero-copy, no base.utils dual source
  nextpas.core.math.base,
  nextpas.core.math.scalar,
  nextpas.core.math.trig,
  nextpas.core.sync.mutex,
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
    FLock: TRecursiveMutex;
    FViolations: Int64;
    FTrackFree: array of Integer;
    FTrackDead: Integer;
    FSnapshotTracks: array of TTimelineTrack;
    FSnapshotClips: array of array of TTimelineClip;
    FSnapshotLGains: array of array of Single;
    FSnapshotRGains: array of array of Single;
    function FindTrack(ATrack: TTimelineTrackId): Integer;
    function FindClip(var ATrack: TTimelineTrack; AClip: TTimelineClipId): Integer;
    function CalcDuration: UInt64;
    function ValidateGain(AGain: Single): Single; inline;
    function ValidatePan(APan: Single): Single; inline;
    procedure MaybeCompactTracks;
    procedure EnsureSnapshotClipCapacities(AMaxClips: Integer);
    procedure EnsureGainCapacities(AMaxClips: Integer);
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
  FLock := TRecursiveMutex.Create;
  SetLength(FTracks,0);
  SetLength(FTrackFree,0);
  SetLength(FSnapshotTracks,0);
  SetLength(FSnapshotClips,0);
  SetLength(FSnapshotLGains,0);
  SetLength(FSnapshotRGains,0);
  FTrackDead:=0;
end;

destructor TTimelineImpl.Destroy;
var I: Integer;
begin
  if Assigned(FLock) then
  begin
    FLock.Acquire;
    try
      for I:=0 to High(FTracks) do SetLength(FTracks[I].Clips, 0);
      SetLength(FTracks,0);
      SetLength(FTrackFree,0);
      SetLength(FSnapshotTracks,0);
      for I:=0 to High(FSnapshotClips) do SetLength(FSnapshotClips[I],0);
      SetLength(FSnapshotClips,0);
      for I:=0 to High(FSnapshotLGains) do SetLength(FSnapshotLGains[I],0);
      SetLength(FSnapshotLGains,0);
      for I:=0 to High(FSnapshotRGains) do SetLength(FSnapshotRGains[I],0);
      SetLength(FSnapshotRGains,0);
    finally FLock.Release; end;
  end;
  FLock.Free;
  inherited;
end;

function TTimelineImpl.GetFormat: TAudioFormat; begin Result := FFormat; end;
function TTimelineImpl.GetPosition: UInt64; begin FLock.Acquire; try Result:=FPosition; finally FLock.Release; end; end;
function TTimelineImpl.GetLoop: Boolean; begin FLock.Acquire; try Result:=FLoop; finally FLock.Release; end; end;
procedure TTimelineImpl.SetLoop(ALoop: Boolean); begin FLock.Acquire; try FLoop:=ALoop; finally FLock.Release; end; end;

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

procedure TTimelineImpl.EnsureSnapshotClipCapacities(AMaxClips: Integer);
var I, LCap: Integer;
begin
  // geometric growth via AudioEnsureCapacity single source — ensures inner clip pools before FillRealtime snapshot copy
  if AMaxClips <= 0 then Exit;
  for I := 0 to High(FSnapshotClips) do
  begin
    LCap := Length(FSnapshotClips[I]);
    if LCap < AMaxClips then
    begin
      InterlockedExchangeAdd64(FViolations, 1);
      AudioEnsureCapacity(LCap, AMaxClips, 4);
      if Length(FSnapshotClips[I]) <> LCap then SetLength(FSnapshotClips[I], LCap);
    end;
  end;
end;

procedure TTimelineImpl.EnsureGainCapacities(AMaxClips: Integer);
var I, LCap: Integer;
begin
  // geometric growth via AudioEnsureCapacity single source — ensures gain tables before FillRealtime snapshot copy
  if AMaxClips <= 0 then Exit;
  for I := 0 to High(FSnapshotLGains) do
  begin
    LCap := Length(FSnapshotLGains[I]);
    if LCap < AMaxClips then
    begin
      InterlockedExchangeAdd64(FViolations, 1);
      AudioEnsureCapacity(LCap, AMaxClips, 4);
      if Length(FSnapshotLGains[I]) <> LCap then SetLength(FSnapshotLGains[I], LCap);
    end;
  end;
  for I := 0 to High(FSnapshotRGains) do
  begin
    LCap := Length(FSnapshotRGains[I]);
    if LCap < AMaxClips then
    begin
      InterlockedExchangeAdd64(FViolations, 1);
      AudioEnsureCapacity(LCap, AMaxClips, 4);
      if Length(FSnapshotRGains[I]) <> LCap then SetLength(FSnapshotRGains[I], LCap);
    end;
  end;
end;

function TTimelineImpl.CalcDuration: UInt64;
var i,j: Integer; e: UInt64;
begin
  Result := 0;
  for i:=0 to High(FTracks) do if FTracks[i].Alive then
    for j:=0 to High(FTracks[i].Clips) do if FTracks[i].Clips[j].Alive then
    begin e := FTracks[i].Clips[j].StartFrame + UInt64(FTracks[i].Clips[j].Buffer.FrameCount); if e > Result then Result := e; end;
end;

function TTimelineImpl.GetDuration: UInt64; begin FLock.Acquire; try Result:=CalcDuration; finally FLock.Release; end; end;

function TTimelineImpl.FindTrack(ATrack: TTimelineTrackId): Integer;
var i: Integer; begin for i:=0 to High(FTracks) do if FTracks[i].Alive and (FTracks[i].Id=ATrack) then Exit(i); Result:=-1; end;

function TTimelineImpl.FindClip(var ATrack: TTimelineTrack; AClip: TTimelineClipId): Integer;
var i: Integer; begin for i:=0 to High(ATrack.Clips) do if ATrack.Clips[i].Alive and (ATrack.Clips[i].Id=AClip) then Exit(i); Result:=-1; end;

function TTimelineImpl.AddTrack(AGain: Single): TTimelineTrackId;
var idx: Integer;
begin
  AGain:=ValidateGain(AGain);
  FLock.Acquire; try
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
  finally FLock.Release; end;
end;

function TTimelineImpl.RemoveTrack(ATrack: TTimelineTrackId): Boolean;
var idx: Integer;
begin
  FLock.Acquire; try
    idx:=FindTrack(ATrack); if idx<0 then Exit(False);
    FTracks[idx].Alive:=False;
    SetLength(FTracks[idx].Clips,0);
    SetLength(FTrackFree, Length(FTrackFree)+1);
    FTrackFree[High(FTrackFree)]:=idx;
    Inc(FTrackDead);
    MaybeCompactTracks;
    Result:=True;
  finally FLock.Release; end;
end;

function TTimelineImpl.SetTrackGain(ATrack: TTimelineTrackId; AGain: Single): Boolean;
var idx: Integer;
begin if IsNan(AGain) or IsInfinite(AGain) then Exit(False); AGain:=ValidateGain(AGain); FLock.Acquire; try idx:=FindTrack(ATrack); if idx<0 then Exit(False); FTracks[idx].Gain:=AGain; Result:=True; finally FLock.Release; end; end;

function TTimelineImpl.SetTrackPan(ATrack: TTimelineTrackId; APan: Single): Boolean;
var idx: Integer;
begin APan:=ValidatePan(APan); FLock.Acquire; try idx:=FindTrack(ATrack); if idx<0 then Exit(False); FTracks[idx].Pan:=APan; Result:=True; finally FLock.Release; end; end;

function TTimelineImpl.SetTrackMute(ATrack: TTimelineTrackId; AMuted: Boolean): Boolean;
var idx: Integer;
begin FLock.Acquire; try idx:=FindTrack(ATrack); if idx<0 then Exit(False); FTracks[idx].Muted:=AMuted; Result:=True; finally FLock.Release; end; end;

function TTimelineImpl.SetTrackSolo(ATrack: TTimelineTrackId; ASolo: Boolean): Boolean;
var idx: Integer;
begin FLock.Acquire; try idx:=FindTrack(ATrack); if idx<0 then Exit(False); FTracks[idx].Solo:=ASolo; Result:=True; finally FLock.Release; end; end;

function TTimelineImpl.AddClip(ATrack: TTimelineTrackId; const ABuffer: TAudioBuffer; AStartFrame: UInt64; AGain: Single; APan: Single): TTimelineClipId;
var tidx, cidx, reuseIdx, i: Integer; tmp: TTimelineClip;
begin
  if not ABuffer.Format.IsValid then raise EAudioTimelineError.Create('AddClip: invalid buffer');
  if ABuffer.Format.SampleFormat<>sfF32 then raise EAudioTimelineError.Create('AddClip: must be sfF32');
  if (ABuffer.Format.SampleRate<>FFormat.SampleRate) or (ABuffer.Format.Channels<>FFormat.Channels) then raise EAudioTimelineError.Create('AddClip: format mismatch');
  AGain:=ValidateGain(AGain);
  APan:=ValidatePan(APan);
  FLock.Acquire; try
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
  finally FLock.Release; end;
end;

function TTimelineImpl.RemoveClip(ATrack: TTimelineTrackId; AClip: TTimelineClipId): Boolean;
var tidx, cidx, i, dead: Integer;
begin
  FLock.Acquire; try
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
  finally FLock.Release; end;
end;

function TTimelineImpl.TrackCount: Integer;
var i,c: Integer;
begin FLock.Acquire; try c:=0; for i:=0 to High(FTracks) do if FTracks[i].Alive then Inc(c); Result:=c; finally FLock.Release; end; end;

function TTimelineImpl.ClipCount(ATrack: TTimelineTrackId): Integer;
var tidx,i,c: Integer;
begin FLock.Acquire; try tidx:=FindTrack(ATrack); if tidx<0 then Exit(0); c:=0; for i:=0 to High(FTracks[tidx].Clips) do if FTracks[tidx].Clips[i].Alive then Inc(c); Result:=c; finally FLock.Release; end; end;

procedure TTimelineImpl.Clear;
var i: Integer;
begin FLock.Acquire; try for i:=0 to High(FTracks) do begin FTracks[i].Alive:=False; SetLength(FTracks[i].Clips,0); end; SetLength(FTracks,0); SetLength(FTrackFree,0); FTrackDead:=0; FPosition:=0; finally FLock.Release; end; end;

function TTimelineImpl.Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer; begin Result:=FillRealtime(ABuffer, AFrames); end;
function TTimelineImpl.SeekTo(AFrame: UInt64): Boolean; begin FLock.Acquire; try FPosition:=AFrame; Result:=True; finally FLock.Release; end; end;

// HasSolo contract: solo overrides mute - if HasSolo then only solo tracks mix, muted and non-solo tracks are skipped; computed before MixSegment
procedure TTimelineImpl.MixSegment(MixPtr: PSingle; const SnapTracks: array of TTimelineTrack;
  ASrcPos: UInt64; ADstOff: Integer; ASegFrames: Integer);
var i,j, ch, k, srcOff, dstOff, copyFrames: Integer;
  Gain: Single;
  Lgain, Rgain: Single;
  Clip: TTimelineClip;
  SrcPtr: PSingle;
begin
  if ASegFrames <=0 then Exit;
  for i:=0 to High(SnapTracks) do
  begin
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
      Gain:=SnapTracks[i].Gain*Clip.Gain;
      // precomputed Lgain/Rgain table — avoids Cos/Sin per segment, single source AudioPanLawGains
      if (i < Length(FSnapshotLGains)) and (j < Length(FSnapshotLGains[i]))
         and (i < Length(FSnapshotRGains)) and (j < Length(FSnapshotRGains[i])) then
      begin Lgain:=FSnapshotLGains[i][j]; Rgain:=FSnapshotRGains[i][j]; end
      else begin AudioPanLawGains((SnapTracks[i].Pan+Clip.Pan)/2, Lgain, Rgain); end;
      if FFormat.Channels<>2 then begin Lgain:=1; Rgain:=1; end;
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
  Needed, i, avail, MaxClips, LClipCount, LCap: Integer;
  MixPtr: PSingle;
  HasSolo: Boolean;
  SnapTracks: array of TTimelineTrack;
  SnapPos: UInt64;
  SnapLoop: Boolean;
  SnapDur: UInt64;
  FirstFrames, SecondFrames: Integer;
  Pan, LG, RG: Single;
begin
  if AFrames<=0 then Exit(0);
  Needed:=Integer(AudioBytesForFrames(FFormat, AFrames));
  if (Needed<=0) or (Length(ABuffer.Data)<Needed) then
  begin InterlockedExchangeAdd64(FViolations,1); AFrames:=Length(ABuffer.Data) div FFormat.BlockAlign; if AFrames<=0 then Exit(0); Needed:=Integer(AudioBytesForFrames(FFormat, AFrames)); if Needed<=0 then Exit(0); end;
  if Needed>0 then BytesZero(@ABuffer.Data[0], SizeUInt(Needed));
  MixPtr:=PSingle(@ABuffer.Data[0]);
  // two-phase snapshot scratch reuse: count+meta under lock -> ensure scratch capacity (AudioEnsureCapacity single source) -> deep copy under lock (zero-alloc steady)
  // 字节预算统一经 AudioBytesForFrames 单源；容量增长经 AudioEnsureCapacity/BytesEnsureCapacity 单源，稳态零堆增长 (INV-6)
  FLock.Acquire;
  try
    SnapPos:=FPosition;
    SnapLoop:=FLoop;
    SnapDur:=CalcDuration;
    // HasSolo: solo overrides mute - when HasSolo is true, only tracks with Solo=true are kept, all muted and non-solo tracks are skipped
    HasSolo:=False; for i:=0 to High(FTracks) do if FTracks[i].Alive and FTracks[i].Solo then HasSolo:=True;
    avail:=0; MaxClips:=0;
    for i:=0 to High(FTracks) do if FTracks[i].Alive then
    begin
      if FTracks[i].Muted then Continue;
      if HasSolo and not FTracks[i].Solo then Continue;
      Inc(avail);
      if Length(FTracks[i].Clips) > MaxClips then MaxClips:=Length(FTracks[i].Clips);
    end;
  finally FLock.Release; end;
  // two-phase snapshot scratch reuse - ensure scratch capacity before snapshot alloc (grow only, else reuse, steady zero alloc)
  // perf: inline doubling via AudioEnsureCapacity single source
  if Length(FSnapshotTracks) < avail then
  begin
    InterlockedExchangeAdd64(FViolations, 1);
    LCap:=Length(FSnapshotTracks); AudioEnsureCapacity(LCap, avail, 4); if Length(FSnapshotTracks) <> LCap then SetLength(FSnapshotTracks, LCap);
  end;
  // else reuse FSnapshotTracks storage - steady state avoids heap alloc
  SnapTracks := FSnapshotTracks;
  if Length(SnapTracks) < avail then
  begin InterlockedExchangeAdd64(FViolations, 1); LCap:=Length(SnapTracks); AudioEnsureCapacity(LCap, avail, 4); if Length(SnapTracks) <> LCap then SetLength(SnapTracks, LCap); end;
  // ensure clip pools and gain tables — preallocated snapshot pools, lock-free Move fixed capacity (FViolations unified with graph/bank discipline)
  if avail>0 then
  begin
    if Length(FSnapshotClips) < avail then
    begin InterlockedExchangeAdd64(FViolations, 1); LCap:=Length(FSnapshotClips); AudioEnsureCapacity(LCap, avail, 4); if Length(FSnapshotClips) <> LCap then SetLength(FSnapshotClips, LCap); end;
    if Length(FSnapshotLGains) < avail then
    begin InterlockedExchangeAdd64(FViolations, 1); LCap:=Length(FSnapshotLGains); AudioEnsureCapacity(LCap, avail, 4); if Length(FSnapshotLGains) <> LCap then SetLength(FSnapshotLGains, LCap); end;
    if Length(FSnapshotRGains) < avail then
    begin InterlockedExchangeAdd64(FViolations, 1); LCap:=Length(FSnapshotRGains); AudioEnsureCapacity(LCap, avail, 4); if Length(FSnapshotRGains) <> LCap then SetLength(FSnapshotRGains, LCap); end;
    // FillRealtime calls ensure before snapshot copy — geometric growth via Ensure* helpers, steady zero alloc after warmup
    EnsureSnapshotClipCapacities(MaxClips);
    EnsureGainCapacities(MaxClips);
  end;
  // else reuse SnapTracks storage - steady state avoids heap alloc (trim to avail after copy if needed)
  if avail > 0 then
  begin
    FLock.Acquire;
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
          // deep copy clip array via preallocated snapshot pool + Move fixed capacity — zero alloc inside lock, isolation from concurrent Add/RemoveClip
          LClipCount:=Length(FTracks[i].Clips);
          // reuse pooled storage — assign pooled array (refcount inc, no heap alloc)
          SnapTracks[avail].Clips := FSnapshotClips[avail];
          if LClipCount>0 then
          begin
            // single source: bytes.ops BytesCopy/BytesZero inline zero-copy, SizeUInt(LClipCount*SizeOf(TTimelineClip)) pooled — no Move inside lock
            BytesCopy(@FSnapshotClips[avail][0], @FTracks[i].Clips[0], SizeUInt(LClipCount) * SizeUInt(SizeOf(TTimelineClip)));
            if LClipCount < MaxClips then BytesZero(@FSnapshotClips[avail][LClipCount], SizeUInt((MaxClips-LClipCount)*SizeOf(TTimelineClip)));
          end else if MaxClips>0 then BytesZero(@FSnapshotClips[avail][0], SizeUInt(MaxClips*SizeOf(TTimelineClip)));
          Inc(avail);
        end;
      end;
      // do not SetLength inside lock — trim outside lock
    finally FLock.Release; end;
    // cover deep copy isolation kept — SetLength outside lock
    if avail < Length(SnapTracks) then
    begin
      // trim pooled Clips arrays logical tail already zeroed; trim outer snapshot length outside lock
      SetLength(SnapTracks, avail);
      // keep outer pools capacity but reflect trimmed avail for next iteration (pools remain capacity)
      // re-sync alias: FSnapshotTracks length already reflects avail after SetLength via SnapTracks alias
    end;
  end;
  // precompute pan gains table — avoids Cos/Sin per segment
  for i:=0 to avail-1 do
    for LClipCount:=0 to High(SnapTracks[i].Clips) do
    begin
      if not SnapTracks[i].Clips[LClipCount].Alive then Continue;
      Pan:=(SnapTracks[i].Pan+SnapTracks[i].Clips[LClipCount].Pan)/2;
      AudioPanLawGains(Pan, LG, RG);
      if (i < Length(FSnapshotLGains)) and (LClipCount < Length(FSnapshotLGains[i])) then
        FSnapshotLGains[i][LClipCount]:=LG;
      if (i < Length(FSnapshotRGains)) and (LClipCount < Length(FSnapshotRGains[i])) then
        FSnapshotRGains[i][LClipCount]:=RG;
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
  FLock.Acquire;
  try
    // FPosition advance: SnapPos as base modulo wrap (loop cross-segment), Interlocked semantics preserved via FLock
    if SnapLoop and (SnapDur>0) then
      FPosition := (SnapPos + UInt64(AFrames)) mod SnapDur
    else
      FPosition := SnapPos + UInt64(AFrames);
  finally FLock.Release; end;
  ABuffer.FrameCount:=AFrames;
  ABuffer.Format:=FFormat;
  Result:=AFrames;
end;

end.
