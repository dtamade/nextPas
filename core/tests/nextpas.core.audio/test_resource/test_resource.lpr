program test_resource;
{$mode objfpc}{$H+}
uses cthreads, SysUtils, Classes, nextpas.core.base, nextpas.core.test, nextpas.core.audio.base, nextpas.core.audio.resource.base, nextpas.core.audio.resource.intf, nextpas.core.audio.resource, nextpas.core.audio;
function MakeBuf(AFrames: Integer; AVal: Single): TAudioBuffer;
var P: PSingle; I: Integer;
begin
  Result.Format:=AudioFormatCreate(48000,2,sfF32);
  Result.FrameCount:=AFrames;
  SetLength(Result.Data, AFrames*Result.Format.BlockAlign);
  P:=PSingle(@Result.Data[0]);
  for I:=0 to AFrames*2-1 do P[I]:=AVal;
end;
function TempWavPath(const AName: string): string;
begin
  Result:=IncludeTrailingPathDelimiter(GetTempDir)+AName+IntToStr(GetProcessID)+'.wav';
end;
function WaitState(AMgr: IAudioResourceManager; AId: TAudioResourceId; ATimeoutMs: Integer=2000): TAudioResourceState;
var Elapsed: Integer;
begin
  Elapsed:=0;
  repeat
    Result:=AMgr.GetState(AId);
    if Result<>arsLoading then Exit;
    Sleep(10); Inc(Elapsed,10);
  until Elapsed>=ATimeoutMs;
  Result:=AMgr.GetState(AId);
end;
type T=class
  procedure TestAsyncLoadReady;
  procedure TestDedupSamePath;
  procedure TestTryGetBuffer;
  procedure TestFindByPath;
  procedure TestResourceCount;
  procedure TestProbeFile;
  procedure TestProbeFileMissing;
  procedure TestRelease;
  procedure TestReleaseAll;
  procedure TestEmptyPathThrows;
  procedure TestGetStateUnknown;
  procedure TestRetryAfterFailed;
  procedure TestFacade;
end;
procedure T.TestAsyncLoadReady;
var Mgr: IAudioResourceManager; Path: string; Id: TAudioResourceId; St: TAudioResourceState; Buf: TAudioBuffer; Tags: TAudioTags;
begin
  Mgr:=CreateAudioResourceManager;
  Path:=TempWavPath('res_ready');
  try
    Buf:=MakeBuf(10,0.3);
    AudioEncodeWav(Buf, Path);
    Id:=Mgr.AsyncLoad(Path);
    CheckTrue(Id>0,'id>0');
    St:=WaitState(Mgr, Id, 2000);
    CheckEqual(Ord(arsReady), Ord(St),'ready');
    CheckTrue(Mgr.TryGetBuffer(Id, Buf),'try get buffer');
    CheckEqual(10, Buf.FrameCount,'framecount 10');
    CheckTrue(Mgr.TryGetTags(Id, Tags),'try tags');
  finally
    Mgr.ReleaseAll;
    if FileExists(Path) then DeleteFile(Path);
  end;
end;
procedure T.TestDedupSamePath;
var Mgr: IAudioResourceManager; Path: string; Id1, Id2: TAudioResourceId; Buf: TAudioBuffer;
begin
  Mgr:=CreateAudioResourceManager;
  Path:=TempWavPath('res_dedup');
  try
    Buf:=MakeBuf(5,0.1);
    AudioEncodeWav(Buf, Path);
    Id1:=Mgr.AsyncLoad(Path);
    Id2:=Mgr.AsyncLoad(Path);
    CheckEqual(Id1, Id2,'dedup same id');
    WaitState(Mgr, Id1, 2000);
    CheckEqual(1, Mgr.ResourceCount,'count 1');
  finally
    Mgr.ReleaseAll;
    if FileExists(Path) then DeleteFile(Path);
  end;
end;
procedure T.TestTryGetBuffer;
var Mgr: IAudioResourceManager; Path: string; Id: TAudioResourceId; Buf, OutBuf: TAudioBuffer;
begin
  Mgr:=CreateAudioResourceManager;
  Path:=TempWavPath('res_trybuf');
  try
    Buf:=MakeBuf(8,0.5);
    AudioEncodeWav(Buf, Path);
    Id:=Mgr.AsyncLoad(Path);
    WaitState(Mgr, Id, 2000);
    CheckTrue(Mgr.TryGetBuffer(Id, OutBuf),'try get');
    CheckEqual(8, OutBuf.FrameCount,'8 frames');
    CheckFalse(Mgr.TryGetBuffer(9999, OutBuf),'bad id false');
    // loading not ready -> false: create unknown probe path
  finally
    Mgr.ReleaseAll;
    if FileExists(Path) then DeleteFile(Path);
  end;
end;
procedure T.TestFindByPath;
var Mgr: IAudioResourceManager; Path: string; Id: TAudioResourceId;
begin
  Mgr:=CreateAudioResourceManager;
  Path:=TempWavPath('res_find');
  try
    AudioEncodeWav(MakeBuf(4,0.2), Path);
    Id:=Mgr.AsyncLoad(Path);
    WaitState(Mgr, Id, 2000);
    CheckEqual(Id, Mgr.FindByPath(Path),'find path');
    CheckEqual(0, Mgr.FindByPath('/tmp/notfound_xyz.wav'),'missing 0');
    CheckEqual(Path, Mgr.GetPath(Id),'get path');
    CheckEqual('', Mgr.GetPath(9999),'bad path empty');
  finally
    Mgr.ReleaseAll;
    if FileExists(Path) then DeleteFile(Path);
  end;
end;
procedure T.TestResourceCount;
var Mgr: IAudioResourceManager; P1, P2: string;
begin
  Mgr:=CreateAudioResourceManager;
  P1:=TempWavPath('res_cnt1'); P2:=TempWavPath('res_cnt2');
  try
    AudioEncodeWav(MakeBuf(4,0.1), P1);
    AudioEncodeWav(MakeBuf(4,0.1), P2);
    Mgr.AsyncLoad(P1); Mgr.AsyncLoad(P2);
    Sleep(100);
    CheckEqual(2, Mgr.ResourceCount,'count 2');
    Mgr.ReleaseAll; CheckEqual(0, Mgr.ResourceCount,'0 after release all');
  finally
    Mgr.ReleaseAll;
    if FileExists(P1) then DeleteFile(P1);
    if FileExists(P2) then DeleteFile(P2);
  end;
end;
procedure T.TestProbeFile;
var Mgr: IAudioResourceManager; Path: string; Res: TAudioProbeResult;
begin
  Mgr:=CreateAudioResourceManager;
  Path:=TempWavPath('res_probe');
  try
    AudioEncodeWav(MakeBuf(10,0.2), Path);
    Res:=Mgr.ProbeFile(Path);
    CheckEqual(Ord(prWav), Ord(Res),'probe wav');
    CheckEqual(Ord(prUnknown), Ord(Mgr.ProbeFile('')),'empty unknown');
  finally
    Mgr.ReleaseAll;
    if FileExists(Path) then DeleteFile(Path);
  end;
end;
procedure T.TestProbeFileMissing;
var Mgr: IAudioResourceManager; Res: TAudioProbeResult;
begin
  Mgr:=CreateAudioResourceManager;
  Res:=Mgr.ProbeFile('/tmp/nextpas_no_such_probe_123.wav');
  CheckEqual(Ord(prUnknown), Ord(Res),'missing probe unknown');
end;
procedure T.TestRelease;
var Mgr: IAudioResourceManager; Path: string; Id: TAudioResourceId; Buf: TAudioBuffer;
begin
  Mgr:=CreateAudioResourceManager;
  Path:=TempWavPath('res_rel');
  try
    AudioEncodeWav(MakeBuf(10,0.1), Path);
    Id:=Mgr.AsyncLoad(Path);
    WaitState(Mgr, Id, 2000);
    Mgr.Release(Id);
    CheckEqual(0, Mgr.ResourceCount,'0 after release');
    CheckFalse(Mgr.TryGetBuffer(Id, Buf),'try after release false');
    CheckEqual(Ord(arsFailed), Ord(Mgr.GetState(Id)),'state failed after release');
  finally
    Mgr.ReleaseAll;
    if FileExists(Path) then DeleteFile(Path);
  end;
end;
procedure T.TestReleaseAll;
var Mgr: IAudioResourceManager; P1, P2: string;
begin
  Mgr:=CreateAudioResourceManager;
  P1:=TempWavPath('res_relall1'); P2:=TempWavPath('res_relall2');
  try
    AudioEncodeWav(MakeBuf(4,0.1), P1);
    AudioEncodeWav(MakeBuf(4,0.1), P2);
    Mgr.AsyncLoad(P1); Mgr.AsyncLoad(P2);
    Sleep(100);
    Mgr.ReleaseAll; CheckEqual(0, Mgr.ResourceCount,'0 after release all');
  finally
    if FileExists(P1) then DeleteFile(P1);
    if FileExists(P2) then DeleteFile(P2);
  end;
end;
procedure T.TestEmptyPathThrows;
var Mgr: IAudioResourceManager; OK: Boolean;
begin
  Mgr:=CreateAudioResourceManager;
  OK:=False; try Mgr.AsyncLoad(''); except OK:=True; end;
  CheckTrue(OK,'empty path throws');
  Mgr.ReleaseAll;
end;
procedure T.TestGetStateUnknown;
var Mgr: IAudioResourceManager;
begin
  Mgr:=CreateAudioResourceManager;
  CheckEqual(Ord(arsFailed), Ord(Mgr.GetState(9999)),'unknown state failed');
  Mgr.ReleaseAll;
end;
procedure T.TestRetryAfterFailed;
var Mgr: IAudioResourceManager; Path: string; Id: TAudioResourceId; St: TAudioResourceState;
begin
  Mgr:=CreateAudioResourceManager;
  Path:=TempWavPath('res_retry_bad');
  try
    // first load with non-wav probe -> will fail
    with TFileStream.Create(Path, fmCreate) do try WriteBuffer('BAD!'[1],4); finally Free; end;
    Id:=Mgr.AsyncLoad(Path);
    St:=WaitState(Mgr, Id, 2000);
    CheckEqual(Ord(arsFailed), Ord(St),'first failed');
    // overwrite with valid wav and retry via AsyncLoad dedup path that resets failed
    DeleteFile(Path);
    AudioEncodeWav(MakeBuf(6,0.2), Path);
    Id:=Mgr.AsyncLoad(Path);
    St:=WaitState(Mgr, Id, 2000);
    CheckEqual(Ord(arsReady), Ord(St),'retry ready');
  finally
    Mgr.ReleaseAll;
    if FileExists(Path) then DeleteFile(Path);
  end;
end;
procedure T.TestFacade;
var Mgr: IAudioResourceManager;
begin
  Mgr:=nextpas.core.audio.resource.CreateAudioResourceManager;
  CheckTrue(Assigned(Mgr),'facade resource');
end;
var S:TTestSuite; C:T;
begin
  C:=T.Create;
  S:=TTestSuite.Create('nextpas.core.audio.resource');
  S.Test('async load ready', @C.TestAsyncLoadReady);
  S.Test('dedup same path', @C.TestDedupSamePath);
  S.Test('try get buffer', @C.TestTryGetBuffer);
  S.Test('find by path', @C.TestFindByPath);
  S.Test('resource count', @C.TestResourceCount);
  S.Test('probe file', @C.TestProbeFile);
  S.Test('probe missing', @C.TestProbeFileMissing);
  S.Test('release', @C.TestRelease);
  S.Test('release all', @C.TestReleaseAll);
  S.Test('empty path throws', @C.TestEmptyPathThrows);
  S.Test('get state unknown', @C.TestGetStateUnknown);
  S.Test('retry after failed', @C.TestRetryAfterFailed);
  S.Test('facade', @C.TestFacade);
  C.Free;
  if not S.Run then Halt(1);
end.
