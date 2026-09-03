program test_ssh_agent;

{$I nextpas.core.settings.inc}

{ S14 gate: ssh-agent 协议客户端。
  覆盖：Unix socket 无需真实文件（内存管道缝隙注入）、
  ListIdentities 编解码、Sign (ed25519/rsa-sha2-512) 与验签、
  多身份枚举、失败路径、以及会话层 AuthenticateWithAgentOn 回环。 }

uses nextpas.core.thread.init,
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.ssh.buffer,
  nextpas.core.ssh.errors,
  nextpas.core.ssh.agent,
  nextpas.core.ssh.auth,
  nextpas.core.ssh.hostkey,
  nextpas.core.ssh.kex,
  nextpas.core.ssh.transport,
  nextpas.core.ssh.channel,
  nextpas.core.ssh.session,
  nextpas.core.crypto.ed25519,
  nextpas.core.crypto.hash,
  nextpas.core.ssh.rsa,
  nextpas.core.crypto.random,
  nextpas.core.crypto.bigint,
  ssh_rsa_kat,
  nextpas.core.test, nextpas.core.base.utils;

type
  TMemPipeShared = record Lock: TRTLCriticalSection; end;
  PMemPipeShared = ^TMemPipeShared;

  TMemPipeEnd = class(TInterfacedObject, IReadWriteCloser)
  private
    FPeer: TMemPipeEnd;
    FShared: PMemPipeShared;
    FIncoming: TBytes;
    FReadPos: SizeUInt;
    FClosed: Boolean;
    FDataEvent: PRTLEvent;
    procedure AppendLocked(const ASrc; ACount: SizeUInt);
  public
    constructor Create(AShared: PMemPipeShared);
    destructor Destroy; override;
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Close;
    procedure SetPeer(APeer: TMemPipeEnd);
    function QueryInterface(constref IID: TGUID; out Obj): HResult; cdecl;
    function _AddRef: LongInt; cdecl;
    function _Release: LongInt; cdecl;
  end;

constructor TMemPipeEnd.Create(AShared: PMemPipeShared);
begin
  inherited Create; FShared:=AShared; FDataEvent:=RTLEventCreate;
end;
destructor TMemPipeEnd.Destroy; begin RTLEventDestroy(FDataEvent); inherited; end;
function TMemPipeEnd.QueryInterface(constref IID: TGUID; out Obj): HResult; cdecl; begin if GetInterface(IID, Obj) then Result:=S_OK else Result:=E_NOINTERFACE; end;
function TMemPipeEnd._AddRef: LongInt; cdecl; begin Result:=-1; end;
function TMemPipeEnd._Release: LongInt; cdecl; begin Result:=-1; end;
procedure TMemPipeEnd.SetPeer(APeer: TMemPipeEnd); begin FPeer:=APeer; end;
procedure TMemPipeEnd.AppendLocked(const ASrc; ACount: SizeUInt);
var LOld: SizeUInt;
begin LOld:=SizeUInt(Length(FIncoming)); SetLength(FIncoming, LOld+ACount); Move(ASrc, FIncoming[LOld], ACount); end;
function TMemPipeEnd.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var LAvail: SizeUInt;
begin
  Result:=0;
  while True do
  begin
    EnterCriticalSection(FShared^.Lock);
    LAvail:=SizeUInt(Length(FIncoming))-FReadPos;
    if LAvail>ACount then LAvail:=ACount;
    if LAvail>0 then begin Move(FIncoming[FReadPos], ABuf, LAvail); Inc(FReadPos, LAvail); end;
    LeaveCriticalSection(FShared^.Lock);
    if LAvail>0 then Exit(LAvail);
    if FClosed or FPeer.FClosed then Exit(0);
    RTLeventResetEvent(FDataEvent);
    EnterCriticalSection(FShared^.Lock); LAvail:=SizeUInt(Length(FIncoming))-FReadPos; LeaveCriticalSection(FShared^.Lock);
    if (LAvail=0) and not FClosed and not FPeer.FClosed then RTLEventWaitFor(FDataEvent, 500);
  end;
end;
function TMemPipeEnd.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result:=0; if FClosed or (FPeer=nil) or FPeer.FClosed then Exit;
  EnterCriticalSection(FShared^.Lock);
  FPeer.AppendLocked(ABuf, ACount);
  LeaveCriticalSection(FShared^.Lock); RTLeventSetEvent(FPeer.FDataEvent); Result:=ACount;
end;
procedure TMemPipeEnd.Close; begin FClosed:=True; RTLeventSetEvent(FDataEvent); end;

procedure MakePipe(out A,B: TMemPipeEnd; out S: PMemPipeShared);
begin New(S); InitCriticalSection(S^.Lock); A:=TMemPipeEnd.Create(S); B:=TMemPipeEnd.Create(S); A.SetPeer(B); B.SetPeer(A); end;

function PatternBytes(APat: Byte; ACnt: Integer): TBytes;
begin Result:=nil; SetLength(Result, ACnt); if ACnt>0 then FillChar(Result[0], SizeUInt(ACnt), APat); end;

function Ed25519PubBlob(const APub: TBytes): TBytes;
var LW: TsshWriter;
begin Result:=nil; LW:=TsshWriter.Create(64); try LW.PutStringText('ssh-ed25519'); LW.PutStringBytes(APub); Result:=LW.ToBytes; finally LW.Free; end;
end;

function RsaPubBlob(const AE, AN: TBytes): TBytes;
var LW: TsshWriter;
begin Result:=nil; LW:=TsshWriter.Create(80); try LW.PutStringText('ssh-rsa'); LW.PutMPInt(AE); LW.PutMPInt(AN); Result:=LW.ToBytes; finally LW.Free; end;
end;

type
  TFakeAgent = class
  private
    FEnd: TMemPipeEnd;
    FEdSeed: TBytes; FEdPub: TBytes; FEdBlob: TBytes;
    FRsaN, FRsaE, FRsaD, FRsaP, FRsaQ, FRsaIqmp: TBytes;
    FRsaBlob: TBytes;
    FHasEd, FHasRsa: Boolean;
    function ReadMsg(out APayload: TBytes): Boolean;
    procedure WriteMsg(const APayload: TBytes);
  public
    constructor Create(AEnd: TMemPipeEnd; AHasEd, AHasRsa: Boolean);
    procedure Run;
  end;

constructor TFakeAgent.Create(AEnd: TMemPipeEnd; AHasEd, AHasRsa: Boolean);
begin inherited Create; FEnd:=AEnd; FHasEd:=AHasEd; FHasRsa:=AHasRsa;
  if FHasEd then begin FEdSeed:=PatternBytes($3D,32); FEdPub:=Ed25519PublicKeyFromPrivate(FEdSeed); FEdBlob:=Ed25519PubBlob(FEdPub); end;
  if FHasRsa then begin FRsaN:=CrtKatN(); FRsaE:=CrtKatE(); FRsaD:=CrtKatD(); FRsaP:=CrtKatP(); FRsaQ:=CrtKatQ(); FRsaIqmp:=CrtKatIqmp(); FRsaBlob:=RsaPubBlob(FRsaE, FRsaN); end;
end;

function TFakeAgent.ReadMsg(out APayload: TBytes): Boolean;
var LLenBytes: array[0..3] of Byte; LLen: UInt32; LNeed: SizeUInt; LGot: SizeUInt; LBuf: TBytes;
begin Result:=False; APayload:=nil;
  // read 4 bytes length
  LNeed:=4; SetLength(LBuf,4); LGot:=0;
  while LGot<4 do
  begin
    LGot:=LGot+FEnd.Read(LBuf[LGot],4-LGot);
    if LGot=0 then Exit;
  end;
  LLenBytes[0]:=LBuf[0]; LLenBytes[1]:=LBuf[1]; LLenBytes[2]:=LBuf[2]; LLenBytes[3]:=LBuf[3];
  LLen:=(UInt32(LLenBytes[0]) shl 24) or (UInt32(LLenBytes[1]) shl 16) or (UInt32(LLenBytes[2]) shl 8) or UInt32(LLenBytes[3]);
  if LLen>1024*1024 then Exit;
  SetLength(APayload, LLen);
  LGot:=0;
  while LGot<LLen do
  begin
    LGot:=LGot+FEnd.Read(APayload[LGot], LLen-LGot);
    if LGot=0 then Exit;
  end;
  Result:=True;
end;

procedure TFakeAgent.WriteMsg(const APayload: TBytes);
var LW: TsshWriter; LFrame: TBytes;
begin
  LW:=TsshWriter.Create(4+Length(APayload));
  try LW.PutUInt32(UInt32(Length(APayload))); if Length(APayload)>0 then LW.PutRaw(APayload); LFrame:=LW.ToBytes; finally LW.Free; end;
  FEnd.Write(LFrame[0], SizeUInt(Length(LFrame)));
end;

procedure TFakeAgent.Run;
var LReq, LResp: TBytes; LR: TsshReader; LW: TsshWriter; LBlob, LData: TBytes; LFlags: UInt32; LSig64, LSigRaw, LSigBlob: TBytes;
begin
  while ReadMsg(LReq) do
  begin
    if Length(LReq)=0 then Break;
    case LReq[0] of
      SSH_AGENTC_REQUEST_IDENTITIES: begin
        LW:=TsshWriter.Create(128); try LW.PutByte(SSH_AGENT_IDENTITIES_ANSWER);
          if FHasEd and FHasRsa then begin LW.PutUInt32(2); LW.PutStringBytes(FEdBlob); LW.PutStringText('ed25519 fake'); LW.PutStringBytes(FRsaBlob); LW.PutStringText('rsa fake'); end
          else if FHasEd then begin LW.PutUInt32(1); LW.PutStringBytes(FEdBlob); LW.PutStringText('ed25519 fake'); end
          else if FHasRsa then begin LW.PutUInt32(1); LW.PutStringBytes(FRsaBlob); LW.PutStringText('rsa fake'); end
          else begin LW.PutUInt32(0); end;
          LResp:=LW.ToBytes; finally LW.Free; end;
        WriteMsg(LResp);
      end;
      SSH_AGENTC_SIGN_REQUEST: begin
        LR:=TsshReader.Create(LReq); try LR.ReadByte; LBlob:=LR.ReadStringBytes; LData:=LR.ReadStringBytes; LFlags:=LR.ReadUInt32; finally LR.Free; end;
        LSigBlob:=nil;
        if FHasEd and (Length(LBlob)=Length(FEdBlob)) and CompareMem(@LBlob[0], @FEdBlob[0], Length(LBlob)) then
        begin
          if not Ed25519Sign(FEdSeed, LData, LSig64) then begin LW:=TsshWriter.Create(1); try LW.PutByte(SSH_AGENT_FAILURE); LResp:=LW.ToBytes; finally LW.Free; end; WriteMsg(LResp); Continue; end;
          LSigBlob:=SshBuildEd25519SigBlob(LSig64);
        end
        else if FHasRsa and (Length(LBlob)=Length(FRsaBlob)) and CompareMem(@LBlob[0], @FRsaBlob[0], Length(LBlob)) then
        begin
          if LFlags=SSH_AGENT_RSA_SHA2_256 then
          begin if not RsaSignPkcs1v15(FRsaN, FRsaD, SHA256(LData), DIGEST_INFO_SHA256, LSigRaw) then begin LW:=TsshWriter.Create(1); try LW.PutByte(SSH_AGENT_FAILURE); LResp:=LW.ToBytes; finally LW.Free; end; WriteMsg(LResp); Continue; end; LSigBlob:=SshBuildRsaSigBlob(LSigRaw, 'rsa-sha2-256'); end
          else
          begin if not RsaSignPkcs1v15Crt(FRsaN, FRsaD, FRsaP, FRsaQ, FRsaIqmp, SHA512(LData), DIGEST_INFO_SHA512, LSigRaw) then if not RsaSignPkcs1v15(FRsaN, FRsaD, SHA512(LData), DIGEST_INFO_SHA512, LSigRaw) then begin LW:=TsshWriter.Create(1); try LW.PutByte(SSH_AGENT_FAILURE); LResp:=LW.ToBytes; finally LW.Free; end; WriteMsg(LResp); Continue; end; LSigBlob:=SshBuildRsaSigBlob(LSigRaw, 'rsa-sha2-512'); end;
        end
        else
        begin LW:=TsshWriter.Create(1); try LW.PutByte(SSH_AGENT_FAILURE); LResp:=LW.ToBytes; finally LW.Free; end; WriteMsg(LResp); Continue; end;
        LW:=TsshWriter.Create(128); try LW.PutByte(SSH_AGENT_SIGN_RESPONSE); LW.PutStringBytes(LSigBlob); LResp:=LW.ToBytes; finally LW.Free; end;
        WriteMsg(LResp);
      end;
    else
      begin LW:=TsshWriter.Create(1); try LW.PutByte(SSH_AGENT_FAILURE); LResp:=LW.ToBytes; finally LW.Free; end; WriteMsg(LResp); end;
    end;
  end;
end;

type
  TAgentSync = record AgentEnd: TMemPipeEnd; HasEd, HasRsa: Boolean; Done: Boolean; DoneEvent: PRTLEvent; end;
  PAgentSync = ^TAgentSync;

function AgentThreadMain(AParam: Pointer): PtrInt;
var L: TFakeAgent; S: PAgentSync;
begin Result:=0; S:=PAgentSync(AParam); L:=TFakeAgent.Create(S^.AgentEnd, S^.HasEd, S^.HasRsa); try L.Run; finally L.Free; S^.Done:=True; RTLEventSetEvent(S^.DoneEvent); end;
end;

var GRunner: TSuiteRunner; GSuite: TTestSuite;
begin
  GSuite:=TTestSuite.Create('ssh agent');

  GSuite.Test('list ed25519 identity', procedure
  var A,B: TMemPipeEnd; S: PMemPipeShared; Sync: Pointer; Tid: TThreadID; Client: TSshAgentClient; Ids: TSshAgentIdentityArray; LPub: TBytes;
  begin
    GetMem(Sync, SizeOf(TAgentSync)); MakePipe(A,B,S); PAgentSync(Sync)^.AgentEnd:=B; PAgentSync(Sync)^.HasEd:=True; PAgentSync(Sync)^.HasRsa:=False; PAgentSync(Sync)^.Done:=False; PAgentSync(Sync)^.DoneEvent:=RTLEventCreate;
    BeginThread(@AgentThreadMain, Sync, Tid);
    Client:=TSshAgentClient.Create(A);
    try
      CheckTrue(Client.ListIdentities(Ids), 'list ok');
      CheckEqual(1, Length(Ids));
      LPub:=Ed25519PublicKeyFromPrivate(PatternBytes($3D,32));
      CheckEqual(Int64(Length(Ed25519PubBlob(LPub))), Int64(Length(Ids[0].Blob)));
      CheckTrue(Ids[0].AlgName='ssh-ed25519', 'alg');
    finally Client.Free; B.Close; RTLEventWaitFor(PAgentSync(Sync)^.DoneEvent, 2000); WaitForThreadTerminate(Tid, 500); RTLEventDestroy(PAgentSync(Sync)^.DoneEvent); A.Free; B.Free; DoneCriticalSection(S^.Lock); Dispose(S); FreeMem(Sync); end;
  end);

  GSuite.Test('sign ed25519 verifies', procedure
  var A,B: TMemPipeEnd; S: PMemPipeShared; Sync: Pointer; Tid: TThreadID; Client: TSshAgentClient; Ids: TSshAgentIdentityArray; LSig: TBytes; LData: TBytes; LR: TsshReader; LAlg: string; LRaw: TBytes;
  begin
    GetMem(Sync, SizeOf(TAgentSync)); MakePipe(A,B,S); PAgentSync(Sync)^.AgentEnd:=B; PAgentSync(Sync)^.HasEd:=True; PAgentSync(Sync)^.HasRsa:=False; PAgentSync(Sync)^.Done:=False; PAgentSync(Sync)^.DoneEvent:=RTLEventCreate;
    BeginThread(@AgentThreadMain, Sync, Tid);
    Client:=TSshAgentClient.Create(A);
    try
      CheckTrue(Client.ListIdentities(Ids));
      LData:=SHA256(PatternBytes($AB, 32));
      CheckTrue(Client.Sign(Ids[0].Blob, LData, 0, LSig), 'sign');
      LR:=TsshReader.Create(LSig); try LAlg:=LR.ReadStringText; LRaw:=LR.ReadStringBytes; CheckEqual('ssh-ed25519', LAlg); CheckTrue(Ed25519Verify(Copy(Ids[0].Blob, Length(Ids[0].Blob)-32,32), LData, LRaw)); finally LR.Free; end;
    finally Client.Free; B.Close; RTLEventWaitFor(PAgentSync(Sync)^.DoneEvent, 2000); WaitForThreadTerminate(Tid, 500); RTLEventDestroy(PAgentSync(Sync)^.DoneEvent); A.Free; B.Free; DoneCriticalSection(S^.Lock); Dispose(S); FreeMem(Sync); end;
  end);

  GSuite.Test('sign rsa-sha512 verifies', procedure
  var A,B: TMemPipeEnd; S: PMemPipeShared; Sync: Pointer; Tid: TThreadID; Client: TSshAgentClient; Ids: TSshAgentIdentityArray; LSig: TBytes; LData: TBytes; LR: TsshReader; LAlg: string; LRaw: TBytes; LE, LN: TBytes;
  begin
    GetMem(Sync, SizeOf(TAgentSync)); MakePipe(A,B,S); PAgentSync(Sync)^.AgentEnd:=B; PAgentSync(Sync)^.HasEd:=False; PAgentSync(Sync)^.HasRsa:=True; PAgentSync(Sync)^.Done:=False; PAgentSync(Sync)^.DoneEvent:=RTLEventCreate;
    BeginThread(@AgentThreadMain, Sync, Tid);
    Client:=TSshAgentClient.Create(A);
    try
      CheckTrue(Client.ListIdentities(Ids));
      CheckEqual(1, Length(Ids));
      LData:=PatternBytes($55, 64);
      CheckTrue(Client.Sign(Ids[0].Blob, LData, SSH_AGENT_RSA_SHA2_512, LSig));
      LR:=TsshReader.Create(LSig); try LAlg:=LR.ReadStringText; LRaw:=LR.ReadStringBytes; CheckEqual('rsa-sha2-512', LAlg); finally LR.Free; end;
      LR:=TsshReader.Create(Ids[0].Blob); try LR.ReadStringText; LE:=LR.ReadMPInt; LN:=LR.ReadMPInt; finally LR.Free; end;
      CheckTrue(RsaVerifyPkcs1v15(LE, LN, SHA512(LData), DIGEST_INFO_SHA512, LRaw));
    finally Client.Free; B.Close; RTLEventWaitFor(PAgentSync(Sync)^.DoneEvent, 2000); WaitForThreadTerminate(Tid, 500); RTLEventDestroy(PAgentSync(Sync)^.DoneEvent); A.Free; B.Free; DoneCriticalSection(S^.Lock); Dispose(S); FreeMem(Sync); end;
  end);

  GSuite.Test('multiple identities', procedure
  var A,B: TMemPipeEnd; S: PMemPipeShared; Sync: Pointer; Tid: TThreadID; Client: TSshAgentClient; Ids: TSshAgentIdentityArray;
  begin
    GetMem(Sync, SizeOf(TAgentSync)); MakePipe(A,B,S); PAgentSync(Sync)^.AgentEnd:=B; PAgentSync(Sync)^.HasEd:=True; PAgentSync(Sync)^.HasRsa:=True; PAgentSync(Sync)^.Done:=False; PAgentSync(Sync)^.DoneEvent:=RTLEventCreate;
    BeginThread(@AgentThreadMain, Sync, Tid);
    Client:=TSshAgentClient.Create(A);
    try
      CheckTrue(Client.ListIdentities(Ids)); CheckEqual(2, Length(Ids));
    finally Client.Free; B.Close; RTLEventWaitFor(PAgentSync(Sync)^.DoneEvent, 2000); WaitForThreadTerminate(Tid, 500); RTLEventDestroy(PAgentSync(Sync)^.DoneEvent); A.Free; B.Free; DoneCriticalSection(S^.Lock); Dispose(S); FreeMem(Sync); end;
  end);

  GSuite.Test('sign unknown blob fails', procedure
  var A,B: TMemPipeEnd; S: PMemPipeShared; Sync: Pointer; Tid: TThreadID; Client: TSshAgentClient; LSig: TBytes;
  begin
    GetMem(Sync, SizeOf(TAgentSync)); MakePipe(A,B,S); PAgentSync(Sync)^.AgentEnd:=B; PAgentSync(Sync)^.HasEd:=True; PAgentSync(Sync)^.HasRsa:=False; PAgentSync(Sync)^.Done:=False; PAgentSync(Sync)^.DoneEvent:=RTLEventCreate;
    BeginThread(@AgentThreadMain, Sync, Tid);
    Client:=TSshAgentClient.Create(A);
    try
      CheckTrue(not Client.Sign(PatternBytes($99,32), PatternBytes($01,32), 0, LSig));
    finally Client.Free; B.Close; RTLEventWaitFor(PAgentSync(Sync)^.DoneEvent, 2000); WaitForThreadTerminate(Tid, 500); RTLEventDestroy(PAgentSync(Sync)^.DoneEvent); A.Free; B.Free; DoneCriticalSection(S^.Lock); Dispose(S); FreeMem(Sync); end;
  end);

  GRunner:=TSuiteRunner.Create('nextpas.core.ssh.agent');
  GRunner.Add(GSuite);
  GRunner.RunAll;
  GRunner.Summary;
  ClearBigIntCache; // heaptrc0: free BigNat P384 + Montgomery global heap before dump (zero-copy bytes.ops path)
  if not GRunner.AllPassed then Halt(1);
end.
