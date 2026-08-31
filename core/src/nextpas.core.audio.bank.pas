unit nextpas.core.audio.bank;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils, Math,
  nextpas.core.base,
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.bank.intf,
  nextpas.core.audio.mix,
  nextpas.core.audio.pcm,
  nextpas.core.audio.errors,
  nextpas.core.sync.mutex;

type
  TBankVoiceSource = class(TInterfacedObject, IRealtimeAudioSource, IAudioSource)
  private
    FFormat: TAudioFormat;
    FData: TBytes;
    FFrames: Integer;
    FPos: Double;
    FGain: Single;
    FPan: Single;
    FPitch: Single;
    FLoop: Boolean;
    FEof: Boolean;
    FChannels: Integer;
  public
    constructor Create(const ABuffer: TAudioBuffer; AGain: Single; APan: Single; APitch: Single; ALoop: Boolean);
    constructor CreateWithParams(const ABuffer: TAudioBuffer; const AParams: TBankPlayParams);
    function GetFormat: TAudioFormat;
    function Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
    function FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
    function SeekTo(AFrame: UInt64): Boolean;
    property Eof: Boolean read FEof;
  end;

  TAudioBank = class(TInterfacedObject, IAudioBank, IAudioSource, IRealtimeAudioSource)
  private
    FFormat: TAudioFormat;
    FLock: TRecursiveMutex;
    FEntries: array of record Id: Integer; Name: string; Buffer: TAudioBuffer; RefCount: Integer; Alive: Boolean; end;
    FVoices: array of record VoiceId: Integer; BankId: Integer; Source: TBankVoiceSource; Alive: Boolean; end;
    FNextId: Integer;
    FNextVoice: Integer;
    FDead: Integer;
    FVoiceDead: Integer;
    FViolations: Int64;
    FScratchTmp: TBytes;
    FSnapshotVoices: array of TBankVoiceSource;
    procedure EnsureScratch(var AScratch: TBytes; ANeeded: Integer); inline;
    procedure EnsureBankCapacity(ANeeded: Integer); inline;
    procedure EnsureVoiceCapacity(ANeeded: Integer); inline;
    function FindEntry(AId: Integer): Integer;
    function FindByNameIdx(const AName: string): Integer;
    function FindVoice(AVoice: Integer): Integer;
    procedure MaybeCompactEntries;
    procedure MaybeCompactVoices;
    procedure ReapFinished;
  public
    constructor Create(const AFormat: TAudioFormat);
    destructor Destroy; override;
    function GetFormat: TAudioFormat;
    function Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
    function FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
    function SeekTo(AFrame: UInt64): Boolean;
    function GetCount: Integer;
    function FindByName(const AName: string): TAudioBankId;
    function TryGetBuffer(AId: TAudioBankId; out ABuffer: TAudioBuffer): Boolean;
    function GetRefCount(AId: TAudioBankId): Integer;
    function Add(const AName: string; const ABuffer: TAudioBuffer): TAudioBankId;
    function AcquireRef(AId: TAudioBankId): Integer;
    function ReleaseRef(AId: TAudioBankId): Integer;
    function Remove(AId: TAudioBankId): Boolean;
    procedure Clear;
    function Play(AId: TAudioBankId): TBankVoiceId; overload;
    function Play(AId: TAudioBankId; AGain: Single; APan: Single; APitch: Single; ALoop: Boolean): TBankVoiceId; overload;
    function Play(AId: TAudioBankId; const AParams: TBankPlayParams): TBankVoiceId; overload;
    function StopVoice(AVoice: TBankVoiceId): Boolean;
    procedure StopAll;
    function VoiceCount: Integer;
    function GetViolations: Int64; inline;
  end;

function CreateAudioBank(const AFormat: TAudioFormat): IAudioBank;

implementation

constructor TBankVoiceSource.Create(const ABuffer: TAudioBuffer; AGain: Single; APan: Single; APitch: Single; ALoop: Boolean);
begin
  inherited Create;
  if ABuffer.Format.SampleFormat <> sfF32 then
    raise EAudioGraphError.Create('BankVoice: buffer must be sfF32');
  FFormat := ABuffer.Format;
  FData := Copy(ABuffer.Data, 0, Length(ABuffer.Data));
  FFrames := ABuffer.FrameCount;
  FPos := 0;
  FGain := AGain;
  if FGain < 0 then FGain := 0 else if FGain > 4 then FGain := 4;
  FPan := APan;
  if FPan < -1 then FPan := -1 else if FPan > 1 then FPan := 1;
  FPitch := APitch;
  if FPitch < 0.25 then FPitch := 0.25 else if FPitch > 4 then FPitch := 4;
  FLoop := ALoop;
  FEof := False;
  FChannels := FFormat.Channels;
end;

constructor TBankVoiceSource.CreateWithParams(const ABuffer: TAudioBuffer; const AParams: TBankPlayParams);
begin
  Create(ABuffer, AParams.Gain, AParams.Pan, AParams.Pitch, AParams.Loop);
end;

function TBankVoiceSource.GetFormat: TAudioFormat;
begin
  Result := FFormat;
end;

function TBankVoiceSource.Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
begin
  Result := FillRealtime(ABuffer, AFrames);
end;

function TBankVoiceSource.SeekTo(AFrame: UInt64): Boolean;
begin
  FPos := AFrame;
  FEof := False;
  Result := True;
end;

function TBankVoiceSource.FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
var
  OutPtr: PSingle;
  I, Ch, Idx0, Idx1: Integer;
  Frac, V0, V1, V: Single;
  SrcPtr: PSingle;
  Gains: TAudioPanGains;
  Lgain, Rgain: Single;
  Needed: Integer;
begin
  Needed := AFrames * FFormat.BlockAlign;
  if Length(ABuffer.Data) < Needed then
  begin
    AFrames := Length(ABuffer.Data) div FFormat.BlockAlign;
    if AFrames <= 0 then Exit(0);
    Needed := AFrames * FFormat.BlockAlign;
  end;
  if FEof and not FLoop then
  begin
    FillChar(ABuffer.Data[0], Needed, 0);
    ABuffer.FrameCount := AFrames;
    Exit(0);
  end;
  OutPtr := PSingle(@ABuffer.Data[0]);
  SrcPtr := PSingle(@FData[0]);
  { PanLawGains0dB 复用：0dB center for bank loudness }
  if FChannels = 2 then
  begin
    Gains := PanLawGains0dB(FPan);
    Lgain := Gains.X; Rgain := Gains.Y;
  end else begin Lgain := 1; Rgain := 1; end;
  for I := 0 to AFrames - 1 do
  begin
    if FPos >= FFrames then
    begin
      if FLoop then FPos := FPos - FFrames
      else begin FEof := True; Break; end;
    end;
    Idx0 := Trunc(FPos);
    Frac := FPos - Idx0;
    Idx1 := Idx0 + 1;
    if Idx1 >= FFrames then
    begin
      if FLoop then Idx1 := 0 else Idx1 := Idx0;
    end;
    for Ch := 0 to FChannels - 1 do
    begin
      V0 := SrcPtr[Idx0*FChannels + Ch];
      V1 := SrcPtr[Idx1*FChannels + Ch];
      V := V0 + (V1 - V0)*Frac;
      V := V * FGain;
      if FChannels = 2 then
      begin
        if Ch = 0 then V := V * Lgain
        else V := V * Rgain;
      end;
      OutPtr[I*FChannels + Ch] := V;
    end;
    FPos := FPos + FPitch;
  end;
  if FEof then
  begin
    for I := I to AFrames -1 do
      for Ch := 0 to FChannels-1 do
        OutPtr[I*FChannels+Ch] := 0;
    ABuffer.FrameCount := AFrames;
    Result := 0;
    Exit;
  end;
  ABuffer.FrameCount := AFrames;
  ABuffer.Format := FFormat;
  Result := AFrames;
end;

constructor TAudioBank.Create(const AFormat: TAudioFormat);
begin
  inherited Create;
  if not AFormat.IsValid then raise EAudioGraphError.Create('Bank: invalid format');
  if AFormat.SampleFormat <> sfF32 then raise EAudioGraphError.Create('Bank: must be sfF32');
  FFormat := AFormat;
  FLock := TRecursiveMutex.Create;
  SetLength(FEntries, 0);
  SetLength(FVoices, 0);
  FNextId := 1;
  FNextVoice := 1;
  FDead := 0;
  FVoiceDead := 0;
  FViolations := 0;
  SetLength(FScratchTmp, 0);
  SetLength(FSnapshotVoices, 0);
end;

destructor TAudioBank.Destroy;
var I: Integer;
begin
  if Assigned(FLock) then
  begin
    FLock.Acquire;
    try
      for I := 0 to High(FVoices) do if Assigned(FVoices[I].Source) then FreeAndNil(FVoices[I].Source);
      for I := 0 to High(FEntries) do SetLength(FEntries[I].Buffer.Data, 0);
    finally FLock.Release; end;
  end;
  FLock.Free;
  inherited;
end;

procedure TAudioBank.EnsureScratch(var AScratch: TBytes; ANeeded: Integer);
begin
  AudioEnsureBytesCapacity(AScratch, ANeeded);
end;

procedure TAudioBank.EnsureBankCapacity(ANeeded: Integer);
var LCap: Integer;
begin
  LCap := Length(FEntries);
  AudioEnsureCapacity(LCap, ANeeded, 4);
  if Length(FEntries) <> LCap then SetLength(FEntries, LCap);
end;

procedure TAudioBank.EnsureVoiceCapacity(ANeeded: Integer);
var LCap: Integer;
begin
  LCap := Length(FVoices);
  AudioEnsureCapacity(LCap, ANeeded, 4);
  if Length(FVoices) <> LCap then SetLength(FVoices, LCap);
end;

function TAudioBank.FindEntry(AId: Integer): Integer;
var I: Integer;
begin
  for I := 0 to High(FEntries) do if FEntries[I].Alive and (FEntries[I].Id = AId) then Exit(I);
  Result := -1;
end;

function TAudioBank.FindByNameIdx(const AName: string): Integer;
var I: Integer;
begin
  for I := 0 to High(FEntries) do if FEntries[I].Alive and (FEntries[I].Name = AName) then Exit(I);
  Result := -1;
end;

function TAudioBank.FindVoice(AVoice: Integer): Integer;
var I: Integer;
begin
  for I := 0 to High(FVoices) do if FVoices[I].Alive and (FVoices[I].VoiceId = AVoice) then Exit(I);
  Result := -1;
end;

procedure TAudioBank.MaybeCompactEntries;
var I, J, AliveN: Integer;
begin
  if (Length(FEntries) <= 32) or (FDead <= Length(FEntries) div 2) then Exit;
  AliveN := 0;
  for I := 0 to High(FEntries) do if FEntries[I].Alive then Inc(AliveN);
  J := 0;
  for I := 0 to High(FEntries) do if FEntries[I].Alive then
  begin
    if I <> J then FEntries[J] := FEntries[I];
    Inc(J);
  end;
  SetLength(FEntries, AliveN);
  FDead := 0;
end;

procedure TAudioBank.MaybeCompactVoices;
var I, J, AliveN: Integer;
begin
  if (Length(FVoices) <= 32) or (FVoiceDead <= Length(FVoices) div 2) then Exit;
  AliveN := 0;
  for I := 0 to High(FVoices) do if FVoices[I].Alive then Inc(AliveN);
  J := 0;
  for I := 0 to High(FVoices) do if FVoices[I].Alive then
  begin
    if I <> J then FVoices[J] := FVoices[I];
    Inc(J);
  end;
  SetLength(FVoices, AliveN);
  FVoiceDead := 0;
end;

procedure TAudioBank.ReapFinished;
var I: Integer;
begin
  for I := High(FVoices) downto 0 do
    if FVoices[I].Alive and Assigned(FVoices[I].Source) and FVoices[I].Source.Eof then
    begin
      FreeAndNil(FVoices[I].Source);
      FVoices[I].Alive := False;
      Inc(FVoiceDead);
    end;
  MaybeCompactVoices;
end;

function TAudioBank.GetFormat: TAudioFormat;
begin
  Result := FFormat;
end;

function TAudioBank.Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
begin
  Result := FillRealtime(ABuffer, AFrames);
end;

function TAudioBank.SeekTo(AFrame: UInt64): Boolean;
var I: Integer;
begin
  FLock.Acquire;
  try
    for I := 0 to High(FVoices) do if FVoices[I].Alive and Assigned(FVoices[I].Source) then
      FVoices[I].Source.SeekTo(AFrame);
    Result := True;
  finally
    FLock.Release;
  end;
end;

function TAudioBank.GetCount: Integer;
var I, C: Integer;
begin
  FLock.Acquire;
  try
    C := 0;
    for I := 0 to High(FEntries) do if FEntries[I].Alive then Inc(C);
    Result := C;
  finally
    FLock.Release;
  end;
end;

function TAudioBank.FindByName(const AName: string): TAudioBankId;
var Idx: Integer;
begin
  FLock.Acquire;
  try
    Idx := FindByNameIdx(AName);
    if Idx < 0 then Result := 0
    else Result := FEntries[Idx].Id;
  finally
    FLock.Release;
  end;
end;

function TAudioBank.TryGetBuffer(AId: TAudioBankId; out ABuffer: TAudioBuffer): Boolean;
var Idx: Integer;
begin
  FLock.Acquire;
  try
    Idx := FindEntry(AId);
    if Idx < 0 then Exit(False);
    { deep copy isolation for snapshot safety }
    ABuffer := FEntries[Idx].Buffer;
    ABuffer.Data := Copy(FEntries[Idx].Buffer.Data, 0, Length(FEntries[Idx].Buffer.Data));
    Result := True;
  finally
    FLock.Release;
  end;
end;

function TAudioBank.GetRefCount(AId: TAudioBankId): Integer;
var Idx: Integer;
begin
  FLock.Acquire;
  try
    Idx := FindEntry(AId);
    if Idx < 0 then Exit(0);
    Result := FEntries[Idx].RefCount;
  finally
    FLock.Release;
  end;
end;

function TAudioBank.Add(const AName: string; const ABuffer: TAudioBuffer): TAudioBankId;
var Idx, FreeIdx, I: Integer;
begin
  if AName = '' then raise EAudioGraphError.Create('Bank.Add: empty name');
  if not ABuffer.Format.IsValid then raise EAudioGraphError.Create('Bank.Add: invalid buffer format');
  if ABuffer.Format.SampleFormat <> sfF32 then raise EAudioGraphError.Create('Bank.Add: must be sfF32');
  if (ABuffer.Format.SampleRate <> FFormat.SampleRate) or (ABuffer.Format.Channels <> FFormat.Channels) then
    raise EAudioGraphError.Create('Bank.Add: format mismatch bank');
  FLock.Acquire;
  try
    Idx := FindByNameIdx(AName);
    if Idx >= 0 then
    begin
      Inc(FEntries[Idx].RefCount);
      Result := FEntries[Idx].Id;
      Exit;
    end;
    Result := FNextId; Inc(FNextId);
    FreeIdx := -1;
    for I := 0 to High(FEntries) do if not FEntries[I].Alive then begin FreeIdx := I; Break; end;
    if FreeIdx >= 0 then
    begin
      Dec(FDead);
      Idx := FreeIdx;
    end else
    begin
      EnsureBankCapacity(Length(FEntries) + 1);
      Idx := 0;
      while (Idx < Length(FEntries)) and FEntries[Idx].Alive do Inc(Idx);
      Idx := -1;
      for I := 0 to High(FEntries) do if not FEntries[I].Alive then begin Idx := I; Break; end;
      if Idx < 0 then
      begin
        Idx := Length(FEntries);
        SetLength(FEntries, Idx + 1);
      end;
    end;
    FEntries[Idx].Id := Result;
    FEntries[Idx].Name := AName;
    { deep copy TAudioBuffer Data for SoundBank preload }
    FEntries[Idx].Buffer := ABuffer;
    FEntries[Idx].Buffer.Data := Copy(ABuffer.Data, 0, Length(ABuffer.Data));
    FEntries[Idx].RefCount := 1;
    FEntries[Idx].Alive := True;
    MaybeCompactEntries;
  finally
    FLock.Release;
  end;
end;

function TAudioBank.AcquireRef(AId: TAudioBankId): Integer;
var Idx: Integer;
begin
  FLock.Acquire;
  try
    Idx := FindEntry(AId);
    if Idx < 0 then raise EAudioGraphError.CreateFmt('Bank.AcquireRef: unknown id %d', [AId]);
    Inc(FEntries[Idx].RefCount);
    Result := FEntries[Idx].RefCount;
  finally
    FLock.Release;
  end;
end;

function TAudioBank.ReleaseRef(AId: TAudioBankId): Integer;
var Idx: Integer;
begin
  FLock.Acquire;
  try
    Idx := FindEntry(AId);
    if Idx < 0 then raise EAudioGraphError.CreateFmt('Bank.ReleaseRef: unknown id %d', [AId]);
    Dec(FEntries[Idx].RefCount);
    if FEntries[Idx].RefCount <= 0 then
    begin
      FEntries[Idx].Alive := False;
      SetLength(FEntries[Idx].Buffer.Data, 0);
      FEntries[Idx].Name := '';
      FEntries[Idx].RefCount := 0;
      Inc(FDead);
      MaybeCompactEntries;
      Result := 0;
    end else
      Result := FEntries[Idx].RefCount;
  finally
    FLock.Release;
  end;
end;

function TAudioBank.Remove(AId: TAudioBankId): Boolean;
var Idx: Integer;
begin
  FLock.Acquire;
  try
    Idx := FindEntry(AId);
    if Idx < 0 then Exit(False);
    FEntries[Idx].Alive := False;
    SetLength(FEntries[Idx].Buffer.Data, 0);
    FEntries[Idx].Name := '';
    FEntries[Idx].RefCount := 0;
    Inc(FDead);
    MaybeCompactEntries;
    Result := True;
  finally
    FLock.Release;
  end;
end;

procedure TAudioBank.Clear;
var I: Integer;
begin
  FLock.Acquire;
  try
    for I := 0 to High(FEntries) do
    begin
      FEntries[I].Alive := False;
      SetLength(FEntries[I].Buffer.Data, 0);
      FEntries[I].Name := '';
      FEntries[I].RefCount := 0;
    end;
    SetLength(FEntries, 0);
    FDead := 0;
    for I := 0 to High(FVoices) do
    begin
      if Assigned(FVoices[I].Source) then FreeAndNil(FVoices[I].Source);
      FVoices[I].Alive := False;
    end;
    SetLength(FVoices, 0);
    FVoiceDead := 0;
    FNextId := 1;
    FNextVoice := 1;
  finally
    FLock.Release;
  end;
end;

function TAudioBank.Play(AId: TAudioBankId): TBankVoiceId;
var P: TBankPlayParams;
begin
  P := TBankPlayParams.Default;
  Result := Play(AId, P);
end;

function TAudioBank.Play(AId: TAudioBankId; AGain: Single; APan: Single; APitch: Single; ALoop: Boolean): TBankVoiceId;
var P: TBankPlayParams;
begin
  P.Gain := AGain; P.Pan := APan; P.Pitch := APitch; P.Loop := ALoop;
  Result := Play(AId, P);
end;

function TAudioBank.Play(AId: TAudioBankId; const AParams: TBankPlayParams): TBankVoiceId;
var SIdx, VIdx, I: Integer;
  Buf: TAudioBuffer;
  Src: TBankVoiceSource;
begin
  FLock.Acquire;
  try
    ReapFinished;
    SIdx := FindEntry(AId);
    if SIdx < 0 then raise EAudioGraphError.CreateFmt('Bank.Play: unknown id %d', [AId]);
    Buf := FEntries[SIdx].Buffer;
    Src := TBankVoiceSource.CreateWithParams(Buf, AParams);
    Result := FNextVoice; Inc(FNextVoice);
    VIdx := -1;
    for I := 0 to High(FVoices) do if not FVoices[I].Alive then begin VIdx := I; Dec(FVoiceDead); Break; end;
    if VIdx < 0 then
    begin
      EnsureVoiceCapacity(Length(FVoices) + 1);
      VIdx := 0;
      while (VIdx < Length(FVoices)) and FVoices[VIdx].Alive do Inc(VIdx);
      if VIdx >= Length(FVoices) then
      begin
        VIdx := Length(FVoices);
        SetLength(FVoices, VIdx + 1);
      end;
    end;
    FVoices[VIdx].VoiceId := Result;
    FVoices[VIdx].BankId := AId;
    FVoices[VIdx].Source := Src;
    FVoices[VIdx].Alive := True;
    MaybeCompactVoices;
  finally
    FLock.Release;
  end;
end;

function TAudioBank.StopVoice(AVoice: TBankVoiceId): Boolean;
var Idx: Integer;
begin
  FLock.Acquire;
  try
    Idx := FindVoice(AVoice);
    if Idx < 0 then Exit(False);
    FreeAndNil(FVoices[Idx].Source);
    FVoices[Idx].Alive := False;
    Inc(FVoiceDead);
    MaybeCompactVoices;
    Result := True;
  finally
    FLock.Release;
  end;
end;

procedure TAudioBank.StopAll;
var I: Integer;
begin
  FLock.Acquire;
  try
    for I := 0 to High(FVoices) do if FVoices[I].Alive then
    begin FreeAndNil(FVoices[I].Source); FVoices[I].Alive := False; Inc(FVoiceDead); end;
    MaybeCompactVoices;
  finally
    FLock.Release;
  end;
end;

function TAudioBank.VoiceCount: Integer;
var I, C: Integer;
begin
  FLock.Acquire;
  try
    ReapFinished;
    C := 0;
    for I := 0 to High(FVoices) do if FVoices[I].Alive then Inc(C);
    Result := C;
  finally
    FLock.Release;
  end;
end;

function TAudioBank.GetViolations: Int64;
begin
  Result := FViolations;
end;

function TAudioBank.FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
var
  Needed, AliveN, I, J: Integer;
  Snap: array of TBankVoiceSource;
  Tmp: TAudioBuffer;
  MixPtr, TmpPtr: PSingle;
  HasData: Boolean;
begin
  if AFrames <= 0 then Exit(0);
  Needed := Integer(Int64(AFrames) * Int64(FFormat.BlockAlign));
  if Length(ABuffer.Data) < Needed then
  begin
    InterlockedExchangeAdd64(FViolations, 1);
    AFrames := Length(ABuffer.Data) div FFormat.BlockAlign;
    if AFrames <= 0 then Exit(0);
    Needed := Integer(Int64(AFrames) * Int64(FFormat.BlockAlign));
  end;
  FillChar(ABuffer.Data[0], Needed, 0);
  { two-phase snapshot + EnsureScratch 零分配：与 graph/timeline 同 discipline }
  FLock.Acquire;
  try
    AliveN := 0;
    for I := 0 to High(FVoices) do if FVoices[I].Alive and Assigned(FVoices[I].Source) and not FVoices[I].Source.Eof then Inc(AliveN);
  finally
    FLock.Release;
  end;
  EnsureScratch(FScratchTmp, Needed);
  if Length(FSnapshotVoices) < AliveN then
    SetLength(FSnapshotVoices, AliveN);
  if AliveN = 0 then
  begin
    ABuffer.FrameCount := AFrames;
    ABuffer.Format := FFormat;
    Result := AFrames;
    Exit;
  end;
  if AliveN > 0 then
  begin
    FLock.Acquire;
    try
      AliveN := 0;
      for I := 0 to High(FVoices) do if FVoices[I].Alive and Assigned(FVoices[I].Source) and not FVoices[I].Source.Eof then
      begin
        if AliveN < Length(FSnapshotVoices) then
        begin
          FSnapshotVoices[AliveN] := FVoices[I].Source;
          Inc(AliveN);
        end;
      end;
    finally
      FLock.Release;
    end;
  end;
  Snap := FSnapshotVoices;
  { snapshot mixing - lock free }
  Tmp.Data := FScratchTmp;
  Tmp.Format := FFormat;
  Tmp.FrameCount := AFrames;
  MixPtr := PSingle(@ABuffer.Data[0]);
  HasData := False;
  for I := 0 to AliveN - 1 do
  begin
    FillChar(Tmp.Data[0], Needed, 0);
    try
      J := Snap[I].FillRealtime(Tmp, AFrames);
    except
      InterlockedExchangeAdd64(FViolations, 1);
      Continue;
    end;
    if J < 0 then
    begin
      InterlockedExchangeAdd64(FViolations, 1);
      Continue;
    end;
    if J = 0 then Continue;
    if J < AFrames then
    begin
      FillChar((PByte(@Tmp.Data[0]) + J * FFormat.BlockAlign)^, (AFrames - J) * FFormat.BlockAlign, 0);
      J := AFrames;
    end;
    HasData := True;
    TmpPtr := PSingle(@Tmp.Data[0]);
    for J := 0 to AFrames * FFormat.Channels - 1 do
      MixPtr[J] := MixPtr[J] + TmpPtr[J];
  end;
  if not HasData then
  begin
    FillChar(ABuffer.Data[0], Needed, 0);
    ABuffer.FrameCount := AFrames;
    ABuffer.Format := FFormat;
    Result := AFrames;
    Exit;
  end;
  for I := 0 to AFrames * FFormat.Channels - 1 do
  begin
    if MixPtr[I] > 1.0 then MixPtr[I] := 1.0
    else if MixPtr[I] < -1.0 then MixPtr[I] := -1.0;
  end;
  ABuffer.FrameCount := AFrames;
  ABuffer.Format := FFormat;
  Result := AFrames;
end;

function CreateAudioBank(const AFormat: TAudioFormat): IAudioBank;
begin
  Result := TAudioBank.Create(AFormat);
end;

end.
