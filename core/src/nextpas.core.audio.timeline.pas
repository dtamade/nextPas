unit nextpas.core.audio.timeline;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils, Classes, SyncObjs, Math,
  nextpas.core.base,
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.timeline.intf,
  nextpas.core.audio.simd,
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
    function FindTrack(ATrack: TTimelineTrackId): Integer;
    function FindClip(var ATrack: TTimelineTrack; AClip: TTimelineClipId): Integer;
    function CalcDuration: UInt64;
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
end;

destructor TTimelineImpl.Destroy; begin FLock.Free; inherited; end;

function TTimelineImpl.GetFormat: TAudioFormat; begin Result := FFormat; end;
function TTimelineImpl.GetPosition: UInt64; begin FLock.Enter; try Result:=FPosition; finally FLock.Leave; end; end;
function TTimelineImpl.GetLoop: Boolean; begin FLock.Enter; try Result:=FLoop; finally FLock.Leave; end; end;
procedure TTimelineImpl.SetLoop(ALoop: Boolean); begin FLock.Enter; try FLoop:=ALoop; finally FLock.Leave; end; end;

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
  if IsNan(AGain) or IsInfinite(AGain) then AGain:=1.0;
  if AGain<0 then AGain:=0 else if AGain>4 then AGain:=4;
  FLock.Enter; try
    Result:=FNextTrack; Inc(FNextTrack);
    idx:=Length(FTracks); SetLength(FTracks, idx+1);
    FTracks[idx].Id:=Result; FTracks[idx].Gain:=AGain; FTracks[idx].Pan:=0; FTracks[idx].Muted:=False; FTracks[idx].Solo:=False; FTracks[idx].Alive:=True; SetLength(FTracks[idx].Clips,0);
  finally FLock.Leave; end;
end;

function TTimelineImpl.RemoveTrack(ATrack: TTimelineTrackId): Boolean;
var idx, k: Integer;
begin FLock.Enter; try idx:=FindTrack(ATrack); if idx<0 then Exit(False); for k:=idx to High(FTracks)-1 do FTracks[k]:=FTracks[k+1]; SetLength(FTracks, Length(FTracks)-1); Result:=True; finally FLock.Leave; end; end;

function TTimelineImpl.SetTrackGain(ATrack: TTimelineTrackId; AGain: Single): Boolean;
var idx: Integer;
begin if IsNan(AGain) or IsInfinite(AGain) then Exit(False); FLock.Enter; try idx:=FindTrack(ATrack); if idx<0 then Exit(False); FTracks[idx].Gain:=AGain; Result:=True; finally FLock.Leave; end; end;

function TTimelineImpl.SetTrackPan(ATrack: TTimelineTrackId; APan: Single): Boolean;
var idx: Integer;
begin if APan<-1 then APan:=-1 else if APan>1 then APan:=1; FLock.Enter; try idx:=FindTrack(ATrack); if idx<0 then Exit(False); FTracks[idx].Pan:=APan; Result:=True; finally FLock.Leave; end; end;

function TTimelineImpl.SetTrackMute(ATrack: TTimelineTrackId; AMuted: Boolean): Boolean;
var idx: Integer;
begin FLock.Enter; try idx:=FindTrack(ATrack); if idx<0 then Exit(False); FTracks[idx].Muted:=AMuted; Result:=True; finally FLock.Leave; end; end;

function TTimelineImpl.SetTrackSolo(ATrack: TTimelineTrackId; ASolo: Boolean): Boolean;
var idx: Integer;
begin FLock.Enter; try idx:=FindTrack(ATrack); if idx<0 then Exit(False); FTracks[idx].Solo:=ASolo; Result:=True; finally FLock.Leave; end; end;

function TTimelineImpl.AddClip(ATrack: TTimelineTrackId; const ABuffer: TAudioBuffer; AStartFrame: UInt64; AGain: Single; APan: Single): TTimelineClipId;
var tidx, cidx: Integer; tmp: TTimelineClip; i: Integer;
begin
  if not AudioIsValidBuffer(ABuffer, True) then
    raise EAudioTimelineError.Create('AddClip: invalid buffer (F32 required)');
  if (ABuffer.Format.SampleRate<>FFormat.SampleRate) or (ABuffer.Format.Channels<>FFormat.Channels) then raise EAudioTimelineError.Create('AddClip: format mismatch');
  if AGain<0 then AGain:=0 else if AGain>4 then AGain:=4;
  if APan<-1 then APan:=-1 else if APan>1 then APan:=1;
  FLock.Enter; try
    tidx:=FindTrack(ATrack); if tidx<0 then raise EAudioTimelineError.Create('AddClip: unknown track');
    Result:=FNextClip; Inc(FNextClip);
    cidx:=Length(FTracks[tidx].Clips); SetLength(FTracks[tidx].Clips, cidx+1);
    FTracks[tidx].Clips[cidx].Id:=Result;
    FTracks[tidx].Clips[cidx].Buffer:=ABuffer;
    FTracks[tidx].Clips[cidx].Buffer.Data:=Copy(ABuffer.Data,0,Length(ABuffer.Data));
    FTracks[tidx].Clips[cidx].StartFrame:=AStartFrame;
    FTracks[tidx].Clips[cidx].Gain:=AGain;
    FTracks[tidx].Clips[cidx].Pan:=APan;
    FTracks[tidx].Clips[cidx].Alive:=True;
    for i:=cidx downto 1 do
      if FTracks[tidx].Clips[i].StartFrame < FTracks[tidx].Clips[i-1].StartFrame then
      begin tmp:=FTracks[tidx].Clips[i]; FTracks[tidx].Clips[i]:=FTracks[tidx].Clips[i-1]; FTracks[tidx].Clips[i-1]:=tmp; end else Break;
  finally FLock.Leave; end;
end;

function TTimelineImpl.RemoveClip(ATrack: TTimelineTrackId; AClip: TTimelineClipId): Boolean;
var tidx, cidx, k: Integer;
begin FLock.Enter; try tidx:=FindTrack(ATrack); if tidx<0 then Exit(False); cidx:=FindClip(FTracks[tidx], AClip); if cidx<0 then Exit(False); for k:=cidx to High(FTracks[tidx].Clips)-1 do FTracks[tidx].Clips[k]:=FTracks[tidx].Clips[k+1]; SetLength(FTracks[tidx].Clips, Length(FTracks[tidx].Clips)-1); Result:=True; finally FLock.Leave; end; end;

function TTimelineImpl.TrackCount: Integer;
var i,c: Integer;
begin FLock.Enter; try c:=0; for i:=0 to High(FTracks) do if FTracks[i].Alive then Inc(c); Result:=c; finally FLock.Leave; end; end;

function TTimelineImpl.ClipCount(ATrack: TTimelineTrackId): Integer;
var tidx,i,c: Integer;
begin FLock.Enter; try tidx:=FindTrack(ATrack); if tidx<0 then Exit(0); c:=0; for i:=0 to High(FTracks[tidx].Clips) do if FTracks[tidx].Clips[i].Alive then Inc(c); Result:=c; finally FLock.Leave; end; end;

procedure TTimelineImpl.Clear;
var i: Integer;
begin FLock.Enter; try for i:=0 to High(FTracks) do begin FTracks[i].Alive:=False; SetLength(FTracks[i].Clips,0); end; SetLength(FTracks,0); FPosition:=0; finally FLock.Leave; end; end;

function TTimelineImpl.Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer; begin Result:=FillRealtime(ABuffer, AFrames); end;
function TTimelineImpl.SeekTo(AFrame: UInt64): Boolean; begin FLock.Enter; try FPosition:=AFrame; Result:=True; finally FLock.Leave; end; end;

function TTimelineImpl.FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
var
  Needed, i, j, ch, srcOff, dstOff, copyFrames: Integer;
  MixPtr: PSingle;
  HasSolo: Boolean;
  TrackGain, ClipGain, Gain: Single;
  TrackPan, ClipPan, Pan: Single;
  Lgain, Rgain, LG, RG: Single;
  Clip: TTimelineClip;
  SrcPtr: PSingle;
  SnapPos: UInt64;
  SnapLoop: Boolean;
  SnapDur: UInt64;
begin
  if AFrames<=0 then Exit(0);
  if (AFrames>0) and (AudioBytesForFrames(FFormat, AFrames)>High(Integer)) then Exit(0);
  Needed:=AFrames*FFormat.BlockAlign;
  if Length(ABuffer.Data)<Needed then
  begin InterlockedExchangeAdd64(FViolations,1); AFrames:=Length(ABuffer.Data) div FFormat.BlockAlign; if AFrames<=0 then Exit(0); Needed:=AFrames*FFormat.BlockAlign; end;
  AudioSilentFill(ABuffer, FFormat, AFrames);
  MixPtr:=PSingle(@ABuffer.Data[0]);
  // realtime: lock-free snapshot (control plane uses lock)
  SnapPos:=FPosition;
  SnapLoop:=FLoop;
  SnapDur:=CalcDuration;
  HasSolo:=False; for i:=0 to High(FTracks) do if FTracks[i].Alive and FTracks[i].Solo then HasSolo:=True;
  for i:=0 to High(FTracks) do
  begin
    if not FTracks[i].Alive then Continue;
    if FTracks[i].Muted then Continue;
    if HasSolo and not FTracks[i].Solo then Continue;
    TrackGain:=FTracks[i].Gain;
    TrackPan:=FTracks[i].Pan;
    for j:=0 to High(FTracks[i].Clips) do
    begin
      Clip:=FTracks[i].Clips[j];
      if not Clip.Alive then Continue;
      if (Clip.StartFrame + UInt64(Clip.Buffer.FrameCount) <= SnapPos) then Continue;
      if (Clip.StartFrame >= SnapPos + UInt64(AFrames)) then Continue;
      if Clip.StartFrame < SnapPos then
      begin srcOff := Integer(SnapPos - Clip.StartFrame); dstOff := 0; copyFrames := Min(Clip.Buffer.FrameCount - srcOff, AFrames);
      end else begin srcOff := 0; dstOff := Integer(Clip.StartFrame - SnapPos); copyFrames := Min(Clip.Buffer.FrameCount, AFrames - dstOff); end;
      if copyFrames<=0 then Continue;
      ClipGain:=Clip.Gain; Pan:=(TrackPan+ClipPan)/2;
      Gain:=TrackGain*ClipGain;
      if FFormat.Channels=2 then begin Lgain:=Cos((Pan+1)*Pi/4)*1.414213562; Rgain:=Sin((Pan+1)*Pi/4)*1.414213562; end else begin Lgain:=1; Rgain:=1; end;
      LG:=Gain*Lgain; RG:=Gain*Rgain;
      SrcPtr:=PSingle(@Clip.Buffer.Data[0]);
      if FFormat.Channels=2 then
      begin
        for ch:=0 to copyFrames-1 do
        begin
          MixPtr[(dstOff+ch)*2] := MixPtr[(dstOff+ch)*2] + SrcPtr[(srcOff+ch)*2]*LG;
          MixPtr[(dstOff+ch)*2+1] := MixPtr[(dstOff+ch)*2+1] + SrcPtr[(srcOff+ch)*2+1]*RG;
        end;
      end else if FFormat.Channels=1 then
      begin
        for ch:=0 to copyFrames-1 do
          MixPtr[dstOff+ch] := MixPtr[dstOff+ch] + SrcPtr[srcOff+ch]*Gain;
      end else
      begin
        for ch:=0 to copyFrames-1 do
          for Needed:=0 to FFormat.Channels-1 do
            MixPtr[(dstOff+ch)*FFormat.Channels + Needed] := MixPtr[(dstOff+ch)*FFormat.Channels + Needed] + SrcPtr[(srcOff+ch)*FFormat.Channels + Needed]*Gain;
      end;
    end;
  end;
  SimdClampF32(MixPtr, AFrames*FFormat.Channels, -1.0, 1.0);
  FPosition:=SnapPos+UInt64(AFrames);
  if SnapLoop and (SnapDur>0) and (FPosition >= SnapDur) then FPosition:=FPosition mod SnapDur;
  ABuffer.FrameCount:=AFrames;
  ABuffer.Format:=FFormat;
  Result:=AFrames;
end;

end.
