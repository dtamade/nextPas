unit nextpas.core.ssh.agent;

{** nextpas.core.ssh - ssh-agent 协议客户端。
 *
 * OpenSSH agent 协议：Unix socket 上的长度前缀帧
 *   request:  uint32(len) || byte(type) || ...（string/uint32 均按 RFC4251
 *            串编码，bE uint32 前缀）
 *   reply:    uint32(len) || byte(type) || ...
 * 关键消息：
 *   11 SSH_AGENTC_REQUEST_IDENTITIES  → 12 SSH_AGENT_IDENTITIES_ANSWER
 *   13 SSH_AGENTC_SIGN_REQUEST        → 14 SSH_AGENT_SIGN_RESPONSE / 5 FAILURE
 * 本单元只依赖 L0-L1（base, errors, net, io.intf, buffer），不触碰 platform
 * 原始套接字；Unix socket 复用 net.UnixConnect（AF_UNIX），Windows 上该
 * 调用会抛 unsupported → 上层落 sekIO。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.os.env,
  nextpas.core.text.conv,
  nextpas.core.io.intf,
  nextpas.core.ssh.buffer,
  nextpas.core.ssh.errors;

const
  SSH_AGENTC_REQUEST_IDENTITIES = 11;
  SSH_AGENT_IDENTITIES_ANSWER   = 12;
  SSH_AGENTC_SIGN_REQUEST       = 13;
  SSH_AGENT_SIGN_RESPONSE       = 14;
  SSH_AGENT_FAILURE             = 5;
  SSH_AGENT_SUCCESS             = 6;

  SSH_AGENT_RSA_SHA2_256 = 2;
  SSH_AGENT_RSA_SHA2_512 = 4;

type
  TSshAgentIdentity = record
    Blob: TBytes;
    Comment: string;
    AlgName: string;
  end;
  TSshAgentIdentityArray = array of TSshAgentIdentity;

function SshAgentKeyBlobToAlgName(const ABlob: TBytes): string;
function SshAgentKeyBlobToSignFlags(const ABlob: TBytes): UInt32;

type
  TSshAgentClient = class
  private
    FIO: IReadWriteCloser;
    FOwnsIO: Boolean;
    procedure WriteMessage(const APayload: TBytes);
    function ReadMessage(out APayload: TBytes): Boolean;
    function ReadExact(var ABuf; ACount: SizeUInt): Boolean;
    function WriteExact(const ABuf; ACount: SizeUInt): Boolean;
  public
    constructor Create(const AIO: IReadWriteCloser); overload;
    constructor CreateForPath(const APath: string); overload;
    destructor Destroy; override;
    procedure Close;

    function ListIdentities(out AIds: TSshAgentIdentityArray): Boolean;
    function Sign(const AKeyBlob, AData: TBytes; AFlags: UInt32;
      out ASigBlob: TBytes): Boolean;

    property IO: IReadWriteCloser read FIO;
  end;

function SshAgentConnect(const APath: string): TSshAgentClient;
function SshAgentConnectFromEnv: TSshAgentClient;

implementation

uses
  nextpas.core.exception,
  nextpas.core.ssh.intf,
  nextpas.core.ssh.net.ffi;

function SshAgentKeyBlobToAlgName(const ABlob: TBytes): string;
var
  LR: TsshReader;
begin
  Result := '';
  if Length(ABlob) = 0 then Exit;
  LR := TsshReader.Create(ABlob);
  try
    Result := LR.ReadStringText;
    if Result = 'ssh-rsa' then
      Result := 'rsa-sha2-512'
    else if Result = 'ssh-ed25519' then
      Result := 'ssh-ed25519'
    else if Result = 'ecdsa-sha2-nistp256' then
      Result := 'ecdsa-sha2-nistp256';
  except
    Result := '';
  end;
  if LR <> nil then LR.Free;
end;

function SshAgentKeyBlobToSignFlags(const ABlob: TBytes): UInt32;
var
  LAlg: string;
begin
  LAlg := SshAgentKeyBlobToAlgName(ABlob);
  if LAlg = 'rsa-sha2-512' then Exit(SSH_AGENT_RSA_SHA2_512);
  if LAlg = 'rsa-sha2-256' then Exit(SSH_AGENT_RSA_SHA2_256);
  Result := 0;
end;

constructor TSshAgentClient.Create(const AIO: IReadWriteCloser);
begin
  inherited Create;
  if AIO = nil then
    raise ESSHError.Create(sekIO, 'ssh agent: nil IO');
  FIO := AIO;
  FOwnsIO := False;
end;

constructor TSshAgentClient.CreateForPath(const APath: string);
var
  LIO: IReadWriteCloser;
  LDialer: ISshAgentDialer;
begin
  inherited Create;
  if APath = '' then
    raise ESSHError.Create(sekIO, 'ssh agent: empty socket path');
  LDialer := SshDefaultAgentDialer;
  try
    LIO := LDialer.DialAgent(APath);
  except
    on E: Exception do
      raise ESSHError.Create(sekIO, 'ssh agent: connect failed (' + APath + '): ' + E.Message);
  end;
  FIO := LIO;
  FOwnsIO := True;
end;

destructor TSshAgentClient.Destroy;
begin
  Close;
  inherited;
end;

procedure TSshAgentClient.Close;
begin
  if (FIO <> nil) and FOwnsIO then
  try
    FIO.Close;
  except
  end;
  FIO := nil;
end;

function TSshAgentClient.ReadExact(var ABuf; ACount: SizeUInt): Boolean;
var
  LNeed, LGot: SizeUInt;
  P: PByte;
begin
  Result := False;
  if ACount = 0 then Exit(True);
  P := PByte(@ABuf);
  LNeed := ACount;
  while LNeed > 0 do
  begin
    LGot := FIO.Read(P^, LNeed);
    if LGot = 0 then Exit(False);
    Inc(P, LGot);
    Dec(LNeed, LGot);
  end;
  Result := True;
end;

function TSshAgentClient.WriteExact(const ABuf; ACount: SizeUInt): Boolean;
var
  LNeed, LGot: SizeUInt;
  P: PByte;
begin
  Result := False;
  if ACount = 0 then Exit(True);
  P := PByte(@ABuf);
  LNeed := ACount;
  while LNeed > 0 do
  begin
    LGot := FIO.Write(P^, LNeed);
    if LGot = 0 then Exit(False);
    Inc(P, LGot);
    Dec(LNeed, LGot);
  end;
  Result := True;
end;

procedure TSshAgentClient.WriteMessage(const APayload: TBytes);
var
  LLen: UInt32;
  LW: TsshWriter;
  LFrame: TBytes;
begin
  LLen := UInt32(Length(APayload));
  LW := TsshWriter.Create(4 + Length(APayload));
  try
    LW.PutUInt32(LLen);
    if Length(APayload) > 0 then
      LW.PutRaw(APayload);
    LFrame := LW.ToBytes;
  finally
    LW.Free;
  end;
  if not WriteExact(LFrame[0], SizeUInt(Length(LFrame))) then
    raise ESSHError.Create(sekIO, 'ssh agent: write failed');
end;

function TSshAgentClient.ReadMessage(out APayload: TBytes): Boolean;
var
  LLenBytes: array[0..3] of Byte;
  LLen: UInt32;
begin
  APayload := nil;
  Result := False;
  if not ReadExact(LLenBytes[0], 4) then
    raise ESSHError.Create(sekIO, 'ssh agent: read length failed');
  LLen := (UInt32(LLenBytes[0]) shl 24) or (UInt32(LLenBytes[1]) shl 16)
        or (UInt32(LLenBytes[2]) shl 8) or UInt32(LLenBytes[3]);
  if LLen > 1024 * 1024 then
    raise ESSHError.Create(sekProtocol, 'ssh agent: message too large');
  SetLength(APayload, LLen);
  if LLen = 0 then Exit(True);
  if not ReadExact(APayload[0], LLen) then
    raise ESSHError.Create(sekIO, 'ssh agent: read payload failed');
  Result := True;
end;

function TSshAgentClient.ListIdentities(out AIds: TSshAgentIdentityArray): Boolean;
var
  LReq, LResp: TBytes;
  LR: TsshReader;
  LCount: UInt32;
  I: Integer;
  LBlob: TBytes;
  LComment: string;
begin
  AIds := nil;
  SetLength(LReq, 1);
  LReq[0] := SSH_AGENTC_REQUEST_IDENTITIES;
  WriteMessage(LReq);
  if not ReadMessage(LResp) then Exit(False);
  if Length(LResp) = 0 then
    raise ESSHError.Create(sekProtocol, 'ssh agent: empty identities answer');
  if LResp[0] = SSH_AGENT_FAILURE then Exit(False);
  if LResp[0] <> SSH_AGENT_IDENTITIES_ANSWER then
    raise ESSHError.Create(sekProtocol, 'ssh agent: unexpected answer type ' + IntToStr(LResp[0]) + ' len=' + IntToStr(Length(LResp)));
  LR := TsshReader.Create(LResp);
  try
    LR.ReadByte;
    LCount := LR.ReadUInt32;
    if LCount > 1024 then
      raise ESSHError.Create(sekProtocol, 'ssh agent: too many identities');
    SetLength(AIds, LCount);
    for I := 0 to Integer(LCount) - 1 do
    begin
      LBlob := LR.ReadStringBytes;
      LComment := LR.ReadStringText;
      AIds[I].Blob := LBlob;
      AIds[I].Comment := LComment;
      AIds[I].AlgName := SshAgentKeyBlobToAlgName(LBlob);
    end;
  finally
    LR.Free;
  end;
  Result := True;
end;

function TSshAgentClient.Sign(const AKeyBlob, AData: TBytes; AFlags: UInt32;
  out ASigBlob: TBytes): Boolean;
var
  LW: TsshWriter;
  LReq, LResp: TBytes;
  LR: TsshReader;
begin
  ASigBlob := nil;
  Result := False;
  if (Length(AKeyBlob) = 0) or (Length(AData) = 0) then Exit;
  LW := TsshWriter.Create(128 + Length(AKeyBlob) + Length(AData));
  try
    LW.PutByte(SSH_AGENTC_SIGN_REQUEST);
    LW.PutStringBytes(AKeyBlob);
    LW.PutStringBytes(AData);
    LW.PutUInt32(AFlags);
    LReq := LW.ToBytes;
  finally
    LW.Free;
  end;
  WriteMessage(LReq);
  if not ReadMessage(LResp) then Exit(False);
  if Length(LResp) = 0 then
    raise ESSHError.Create(sekProtocol, 'ssh agent: empty sign response');
  if LResp[0] = SSH_AGENT_FAILURE then Exit(False);
  if LResp[0] <> SSH_AGENT_SIGN_RESPONSE then
    raise ESSHError.Create(sekProtocol, 'ssh agent: unexpected sign response ' + IntToStr(LResp[0]) + ' len=' + IntToStr(Length(LResp)));
  LR := TsshReader.Create(LResp);
  try
    LR.ReadByte;
    ASigBlob := LR.ReadStringBytes;
  finally
    LR.Free;
  end;
  Result := Length(ASigBlob) > 0;
end;

function SshAgentConnect(const APath: string): TSshAgentClient;
begin
  Result := TSshAgentClient.CreateForPath(APath);
end;

function SshAgentConnectFromEnv: TSshAgentClient;
var
  LPath: string;
begin
  LPath := GetEnv('SSH_AUTH_SOCK');
  if LPath = '' then
    raise ESSHError.Create(sekIO, 'ssh agent: SSH_AUTH_SOCK not set');
  Result := SshAgentConnect(LPath);
end;

end.
