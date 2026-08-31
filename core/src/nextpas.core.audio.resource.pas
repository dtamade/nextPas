unit nextpas.core.audio.resource;

{$I nextpas.core.settings.inc}

interface

uses
  Classes, SysUtils,
  nextpas.core.base,
  nextpas.core.sync.mutex,
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.codec.registry,
  nextpas.core.audio.resource.intf,
  nextpas.core.audio.errors;

type
  TAudioResourceManagerImpl = class(TInterfacedObject, IAudioResourceManager)
  private
    type
      PResourceItem = ^TResourceItem;
      TResourceItem = record
        Id: TAudioResourceId;
        Path: string;
        State: TAudioResourceState;
        Buffer: TAudioBuffer;
        Tags: TAudioTags;
        Alive: Boolean;
        Thread: TThread;
      end;
  private
    FLock: TRecursiveMutex;
    FItems: array of TResourceItem;
    FNextId: TAudioResourceId;
    function FindIndexLocked(AId: TAudioResourceId): Integer;
    function FindByPathLocked(const APath: string): Integer;
    procedure EnsureCapacityLocked(ANeeded: Integer);
    procedure SetState(AIndex: Integer; AState: TAudioResourceState; const ABuffer: TAudioBuffer; const ATags: TAudioTags);
    procedure SetStateById(AId: TAudioResourceId; AState: TAudioResourceState; const ABuffer: TAudioBuffer; const ATags: TAudioTags);
  public
    constructor Create;
    destructor Destroy; override;
    function AsyncLoad(const APath: string): TAudioResourceId;
    function TryGetBuffer(AId: TAudioResourceId; out ABuffer: TAudioBuffer): Boolean;
    function TryGetTags(AId: TAudioResourceId; out ATags: TAudioTags): Boolean;
    function GetState(AId: TAudioResourceId): TAudioResourceState;
    function GetPath(AId: TAudioResourceId): string;
    function FindByPath(const APath: string): TAudioResourceId;
    function ResourceCount: Integer;
    function ProbeFile(const APath: string): TAudioProbeResult;
    procedure Release(AId: TAudioResourceId);
    procedure ReleaseAll;
  end;

function CreateAudioResourceManager: IAudioResourceManager;

implementation

uses
  nextpas.core.fs,
  nextpas.core.io.intf;

type
  TResourceLoadThread = class(TThread)
  private
    FManager: TAudioResourceManagerImpl;
    FId: TAudioResourceId;
    FPath: string;
  protected
    procedure Execute; override;
  public
    constructor Create(AManager: TAudioResourceManagerImpl; AId: TAudioResourceId; const APath: string);
  end;

constructor TResourceLoadThread.Create(AManager: TAudioResourceManagerImpl; AId: TAudioResourceId; const APath: string);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FManager := AManager;
  FId := AId;
  FPath := APath;
end;

procedure TResourceLoadThread.Execute;
var
  LBuffer: TAudioBuffer;
  LTags: TAudioTags;
  LProbe: TAudioProbeResult;
  LStream: IStream;
  LPrefix: TBytes;
  LRead: Integer;
  OK: Boolean;
begin
  // Reuse AudioDetectProbe for early reject (≤4KB prefix probe)
  LProbe := prUnknown;
  try
    try
      LStream := nextpas.core.fs.Open(FPath, [fmRead]);
    except
      on E: EAudioDecodeError do
      begin
        FManager.SetStateById(FId, arsFailed, Default(TAudioBuffer), Default(TAudioTags));
        Exit;
      end;
      else
      begin
        FManager.SetStateById(FId, arsFailed, Default(TAudioBuffer), Default(TAudioTags));
        Exit;
      end;
    end;
    if LStream <> nil then
    begin
      SetLength(LPrefix, 4096);
      LRead := Integer(LStream.Read(LPrefix[0], 4096));
      SetLength(LPrefix, LRead);
      LProbe := AudioDetectProbe(LPrefix);
      if LProbe = prUnknown then
      begin
        FManager.SetStateById(FId, arsFailed, Default(TAudioBuffer), Default(TAudioTags));
        Exit;
      end;
    end;
  except
    on E: EAudioDecodeError do
    begin
      FManager.SetStateById(FId, arsFailed, Default(TAudioBuffer), Default(TAudioTags));
      Exit;
    end;
  end;
  // Reuse TryDecodeWholeFile (internally uses TryDecodeWhole + probe)
  // Only EAudioDecodeError is swallowed; other errors propagate as failed.
  try
    OK := TryDecodeWholeFile(FPath, LBuffer, LTags);
    if OK then
      FManager.SetStateById(FId, arsReady, LBuffer, LTags)
    else
      FManager.SetStateById(FId, arsFailed, Default(TAudioBuffer), Default(TAudioTags));
  except
    on E: EAudioDecodeError do
      FManager.SetStateById(FId, arsFailed, Default(TAudioBuffer), Default(TAudioTags));
  end;
end;

{ TAudioResourceManagerImpl }

constructor TAudioResourceManagerImpl.Create;
begin
  inherited Create;
  FLock := TRecursiveMutex.Create;
  FNextId := 1;
  SetLength(FItems, 0);
end;

destructor TAudioResourceManagerImpl.Destroy;
var
  I: Integer;
  LThreads: array of TThread;
begin
  // Collect threads before lock release to avoid dead lock on Wait
  FLock.Acquire;
  try
    SetLength(LThreads, 0);
    for I := 0 to High(FItems) do
      if Assigned(FItems[I].Thread) then
      begin
        SetLength(LThreads, Length(LThreads) + 1);
        LThreads[High(LThreads)] := FItems[I].Thread;
      end;
  finally
    FLock.Release;
  end;
  for I := 0 to High(LThreads) do
  begin
    try
      LThreads[I].WaitFor;
      LThreads[I].Free;
    except
    end;
  end;
  FLock.Free;
  inherited;
end;

function TAudioResourceManagerImpl.FindIndexLocked(AId: TAudioResourceId): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FItems) do
    if FItems[I].Alive and (FItems[I].Id = AId) then
      Exit(I);
  Result := -1;
end;

function TAudioResourceManagerImpl.FindByPathLocked(const APath: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FItems) do
    if FItems[I].Alive and (FItems[I].Path = APath) then
      Exit(I);
  Result := -1;
end;

procedure TAudioResourceManagerImpl.EnsureCapacityLocked(ANeeded: Integer);
var
  Cap: Integer;
begin
  if Length(FItems) >= ANeeded then Exit;
  Cap := Length(FItems);
  if Cap < 4 then Cap := 4;
  while Cap < ANeeded do Cap := Cap * 2;
  SetLength(FItems, Cap);
end;

procedure TAudioResourceManagerImpl.SetState(AIndex: Integer; AState: TAudioResourceState; const ABuffer: TAudioBuffer; const ATags: TAudioTags);
begin
  FLock.Acquire;
  try
    if (AIndex < 0) or (AIndex > High(FItems)) then Exit;
    if not FItems[AIndex].Alive then Exit;
    FItems[AIndex].State := AState;
    if AState = arsReady then
    begin
      FItems[AIndex].Buffer := ABuffer;
      FItems[AIndex].Tags := ATags;
    end
    else
    begin
      FItems[AIndex].Buffer := Default(TAudioBuffer);
      FItems[AIndex].Tags := Default(TAudioTags);
    end;
  finally
    FLock.Release;
  end;
end;

procedure TAudioResourceManagerImpl.SetStateById(AId: TAudioResourceId; AState: TAudioResourceState; const ABuffer: TAudioBuffer; const ATags: TAudioTags);
var
  Idx: Integer;
begin
  FLock.Acquire;
  try
    Idx := FindIndexLocked(AId);
    if Idx < 0 then Exit;
    if not FItems[Idx].Alive then Exit;
    FItems[Idx].State := AState;
    if AState = arsReady then
    begin
      FItems[Idx].Buffer := ABuffer;
      FItems[Idx].Tags := ATags;
    end
    else
    begin
      FItems[Idx].Buffer := Default(TAudioBuffer);
      FItems[Idx].Tags := Default(TAudioTags);
    end;
  finally
    FLock.Release;
  end;
end;

function TAudioResourceManagerImpl.AsyncLoad(const APath: string): TAudioResourceId;
var
  Idx, FreeIdx: Integer;
  I: Integer;
  LThread: TResourceLoadThread;
  LCapNeeded: Integer;
begin
  if APath = '' then
    raise EInvalidArgument.Create('AsyncLoad: empty path');
  // Deduplication: Bank协同 — 同路径复用已加载或加载中资源
  FLock.Acquire;
  try
    Idx := FindByPathLocked(APath);
    if Idx >= 0 then
    begin
      // If previously failed, allow retry by releasing and reloading
      if FItems[Idx].State = arsFailed then
      begin
        // reset to loading for retry
        FItems[Idx].State := arsLoading;
        FItems[Idx].Buffer := Default(TAudioBuffer);
        FItems[Idx].Tags := Default(TAudioTags);
        // restart thread
        if Assigned(FItems[Idx].Thread) then
        begin
          try FItems[Idx].Thread.WaitFor; FItems[Idx].Thread.Free; except end;
          FItems[Idx].Thread := nil;
        end;
        LThread := TResourceLoadThread.Create(Self, FItems[Idx].Id, APath);
        FItems[Idx].Thread := LThread;
        Result := FItems[Idx].Id;
        LThread.Start;
        Exit;
      end;
      Result := FItems[Idx].Id;
      Exit;
    end;
    // Allocate slot (geometric growth, no alloc inside critical section beyond SetLength)
    FreeIdx := -1;
    for I := 0 to High(FItems) do
      if not FItems[I].Alive then
      begin
        FreeIdx := I;
        Break;
      end;
    if FreeIdx < 0 then
    begin
      FreeIdx := Length(FItems);
      // Ensure capacity outside? we are inside lock but keep Ensure logic
      LCapNeeded := FreeIdx + 1;
      EnsureCapacityLocked(LCapNeeded);
    end;
    Result := FNextId;
    Inc(FNextId);
    FItems[FreeIdx].Id := Result;
    FItems[FreeIdx].Path := APath;
    FItems[FreeIdx].State := arsLoading;
    FItems[FreeIdx].Buffer := Default(TAudioBuffer);
    FItems[FreeIdx].Tags := Default(TAudioTags);
    FItems[FreeIdx].Alive := True;
    FItems[FreeIdx].Thread := nil;
    LThread := TResourceLoadThread.Create(Self, Result, APath);
    FItems[FreeIdx].Thread := LThread;
  finally
    FLock.Release;
  end;
  LThread.Start;
end;

function TAudioResourceManagerImpl.TryGetBuffer(AId: TAudioResourceId; out ABuffer: TAudioBuffer): Boolean;
var
  Idx: Integer;
begin
  ABuffer := Default(TAudioBuffer);
  Result := False;
  FLock.Acquire;
  try
    Idx := FindIndexLocked(AId);
    if Idx < 0 then Exit;
    if FItems[Idx].State <> arsReady then Exit;
    // Non-blocking query: share via refcount, no SetLength inside lock
    ABuffer := FItems[Idx].Buffer;
    Result := True;
  finally
    FLock.Release;
  end;
end;

function TAudioResourceManagerImpl.TryGetTags(AId: TAudioResourceId; out ATags: TAudioTags): Boolean;
var
  Idx: Integer;
begin
  ATags := Default(TAudioTags);
  Result := False;
  FLock.Acquire;
  try
    Idx := FindIndexLocked(AId);
    if Idx < 0 then Exit;
    if FItems[Idx].State <> arsReady then Exit;
    ATags := FItems[Idx].Tags;
    Result := True;
  finally
    FLock.Release;
  end;
end;

function TAudioResourceManagerImpl.GetState(AId: TAudioResourceId): TAudioResourceState;
var
  Idx: Integer;
begin
  FLock.Acquire;
  try
    Idx := FindIndexLocked(AId);
    if Idx < 0 then Exit(arsFailed);
    Result := FItems[Idx].State;
  finally
    FLock.Release;
  end;
end;

function TAudioResourceManagerImpl.GetPath(AId: TAudioResourceId): string;
var
  Idx: Integer;
begin
  Result := '';
  FLock.Acquire;
  try
    Idx := FindIndexLocked(AId);
    if Idx < 0 then Exit;
    Result := FItems[Idx].Path;
  finally
    FLock.Release;
  end;
end;

function TAudioResourceManagerImpl.FindByPath(const APath: string): TAudioResourceId;
var
  Idx: Integer;
begin
  FLock.Acquire;
  try
    Idx := FindByPathLocked(APath);
    if Idx < 0 then Exit(0);
    Result := FItems[Idx].Id;
  finally
    FLock.Release;
  end;
end;

function TAudioResourceManagerImpl.ResourceCount: Integer;
var
  I, C: Integer;
begin
  FLock.Acquire;
  try
    C := 0;
    for I := 0 to High(FItems) do
      if FItems[I].Alive then Inc(C);
    Result := C;
  finally
    FLock.Release;
  end;
end;

function TAudioResourceManagerImpl.ProbeFile(const APath: string): TAudioProbeResult;
var
  LStream: IStream;
  LPrefix: TBytes;
  LRead: Integer;
begin
  Result := prUnknown;
  if APath = '' then Exit;
  try
    LStream := nextpas.core.fs.Open(APath, [fmRead]);
  except
    on E: EAudioDecodeError do Exit(prUnknown);
    else Exit(prUnknown);
  end;
  if LStream = nil then Exit(prUnknown);
  SetLength(LPrefix, 4096);
  try
    LRead := Integer(LStream.Read(LPrefix[0], 4096));
  except
    on E: EAudioDecodeError do Exit(prUnknown);
    else Exit(prUnknown);
  end;
  SetLength(LPrefix, LRead);
  // Reuse AudioDetectProbe (≤4KB)
  Result := AudioDetectProbe(LPrefix);
end;

procedure TAudioResourceManagerImpl.Release(AId: TAudioResourceId);
var
  Idx: Integer;
  LThread: TThread;
begin
  LThread := nil;
  FLock.Acquire;
  try
    Idx := FindIndexLocked(AId);
    if Idx < 0 then Exit;
    LThread := FItems[Idx].Thread;
    FItems[Idx].Thread := nil;
    FItems[Idx].Alive := False;
    FItems[Idx].State := arsFailed;
    SetLength(FItems[Idx].Buffer.Data, 0);
    FItems[Idx].Buffer := Default(TAudioBuffer);
    FItems[Idx].Tags := Default(TAudioTags);
    FItems[Idx].Path := '';
  finally
    FLock.Release;
  end;
  if Assigned(LThread) then
  begin
    try
      LThread.WaitFor;
      LThread.Free;
    except
      on E: EAudioDecodeError do ;
      else ;
    end;
  end;
end;

procedure TAudioResourceManagerImpl.ReleaseAll;
var
  I: Integer;
  LThreads: array of TThread;
begin
  FLock.Acquire;
  try
    SetLength(LThreads, 0);
    for I := 0 to High(FItems) do
      if FItems[I].Alive then
      begin
        if Assigned(FItems[I].Thread) then
        begin
          SetLength(LThreads, Length(LThreads) + 1);
          LThreads[High(LThreads)] := FItems[I].Thread;
          FItems[I].Thread := nil;
        end;
        FItems[I].Alive := False;
        SetLength(FItems[I].Buffer.Data, 0);
        FItems[I].Buffer := Default(TAudioBuffer);
        FItems[I].Tags := Default(TAudioTags);
        FItems[I].Path := '';
        FItems[I].State := arsFailed;
      end;
  finally
    FLock.Release;
  end;
  for I := 0 to High(LThreads) do
  begin
    try
      LThreads[I].WaitFor;
      LThreads[I].Free;
    except
      on E: EAudioDecodeError do ;
      else ;
    end;
  end;
end;

function CreateAudioResourceManager: IAudioResourceManager;
begin
  Result := TAudioResourceManagerImpl.Create;
end;

end.
