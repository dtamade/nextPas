unit nextpas.core.ssh.sftp.conn;

{** nextpas.core.ssh.sftp.conn - SFTP 连接状态机（四件套 impl）。
 *
 * 单职责：INIT/VERSION 握手与一问一答 RoundTrip（含迟滞帧跳过与 STATUS 映射）。
 * 不触文件系统语义，仅管理 request-id 与线材收发。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.ssh.buffer,
  nextpas.core.ssh.sftp.base,
  nextpas.core.ssh.sftp.intf;

type
  TSftpConnection = class
  private
    FWire: ISftpWire;
    FTimeoutMs: Integer;
    FNextId: UInt32;
    function AllocId: UInt32;
  public
    constructor Create(AWire: ISftpWire; ATimeoutMs: Integer);
    procedure Handshake;
    function RoundTrip(AType: Byte; const APayload: TBytes;
      const AAcceptable: array of Byte; out ARespType: Byte;
      const AContext: string): TBytes;
  end;

{ 属性编解码（供 fs 与测试复用，单源于此）}
procedure PutAttrs(var AW: TsshWriter; const AAttrs: TSftpAttrs);
function ReadAttrs(var AR: TsshReader): TSftpAttrs;

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.ssh.errors;

constructor TSftpConnection.Create(AWire: ISftpWire; ATimeoutMs: Integer);
begin
  inherited Create;
  FWire := AWire;
  FTimeoutMs := ATimeoutMs;
  FNextId := 1;
end;

function TSftpConnection.AllocId: UInt32;
begin
  Result := FNextId;
  Inc(FNextId);
end;

procedure PutAttrs(var AW: TsshWriter; const AAttrs: TSftpAttrs);
begin
  AW.PutUInt32(AAttrs.Flags);
  if (AAttrs.Flags and SSH_FILEXFER_ATTR_SIZE) <> 0 then
    AW.PutUInt64(AAttrs.Size);
  if (AAttrs.Flags and SSH_FILEXFER_ATTR_UIDGID) <> 0 then
  begin
    AW.PutUInt32(AAttrs.Uid);
    AW.PutUInt32(AAttrs.Gid);
  end;
  if (AAttrs.Flags and SSH_FILEXFER_ATTR_PERMISSIONS) <> 0 then
    AW.PutUInt32(AAttrs.Permissions);
  if (AAttrs.Flags and SSH_FILEXFER_ATTR_ACMODTIME) <> 0 then
  begin
    AW.PutUInt32(AAttrs.ATime);
    AW.PutUInt32(AAttrs.MTime);
  end;
end;

function ReadAttrs(var AR: TsshReader): TSftpAttrs;
var
  LN, I: Integer;
begin
  Result := Default(TSftpAttrs);
  Result.Flags := AR.ReadUInt32;
  if (Result.Flags and SSH_FILEXFER_ATTR_SIZE) <> 0 then
    Result.Size := AR.ReadUInt64;
  if (Result.Flags and SSH_FILEXFER_ATTR_UIDGID) <> 0 then
  begin
    Result.Uid := AR.ReadUInt32;
    Result.Gid := AR.ReadUInt32;
  end;
  if (Result.Flags and SSH_FILEXFER_ATTR_PERMISSIONS) <> 0 then
    Result.Permissions := AR.ReadUInt32;
  if (Result.Flags and SSH_FILEXFER_ATTR_ACMODTIME) <> 0 then
  begin
    Result.ATime := AR.ReadUInt32;
    Result.MTime := AR.ReadUInt32;
  end;
  if (Result.Flags and SSH_FILEXFER_ATTR_EXTENDED) <> 0 then
  begin
    LN := Integer(AR.ReadUInt32);
    for I := 1 to LN do
    begin
      AR.ReadStringBytes;
      AR.ReadStringBytes;
    end;
  end;
end;

procedure TSftpConnection.Handshake;
var
  LW: TsshWriter;
  LR: TsshReader;
  LRaw: TBytes;
begin
  LW := TsshWriter.Create(5);
  try
    LW.PutByte(SSH_FXP_INIT);
    LW.PutUInt32(SFTP_PROTOCOL_VERSION);
    FWire.Send(LW.ToBytes);
  finally
    LW.Free;
  end;
  LRaw := FWire.Recv(FTimeoutMs);
  if (Length(LRaw) < 5) or (LRaw[0] <> SSH_FXP_VERSION) then
    raise ESSHError.Create(sekProtocol, 'sftp: expected VERSION packet');
  LR := TsshReader.Create(LRaw);
  try
    LR.ReadByte;
    if LR.ReadUInt32 < SFTP_PROTOCOL_VERSION then
      raise ESSHError.Create(sekNegotiation,
        'sftp: server version below 3');
  finally
    LR.Free;
  end;
end;

function TSftpConnection.RoundTrip(AType: Byte; const APayload: TBytes;
  const AAcceptable: array of Byte; out ARespType: Byte;
  const AContext: string): TBytes;
var
  LId: UInt32;
  LW: TsshWriter;
  LR: TsshReader;
  LRaw: TBytes;
  LRid: UInt32;
  LCode: UInt32;
  LMsg: string;
  I: Integer;
  LOk: Boolean;
begin
  LId := AllocId;
  LW := TsshWriter.Create(5 + Length(APayload));
  try
    LW.PutByte(AType);
    LW.PutUInt32(LId);
    LW.PutRaw(APayload);
    FWire.Send(LW.ToBytes);
  finally
    LW.Free;
  end;

  while True do
  begin
    LRaw := FWire.Recv(FTimeoutMs);
    if Length(LRaw) < 5 then
      raise ESSHError.Create(sekProtocol, 'sftp: truncated packet');
    LR := TsshReader.Create(LRaw);
    try
      ARespType := LR.ReadByte;
      LRid := LR.ReadUInt32;
      if LRid <> LId then
        Continue;
      if ARespType = SSH_FXP_STATUS then
      begin
        LCode := LR.ReadUInt32;
        if LCode = SSH_FX_OK then
        begin
          Result := LRaw;
          Exit;
        end;
        if LCode = SSH_FX_EOF then
        begin
          Result := LRaw;
          Exit;
        end;
        LMsg := '';
        try
          LMsg := LR.ReadStringText;
        except
          on LE: ESSHError do
            LMsg := '';
        end;
        if LMsg <> '' then
          raise ESSHError.Create(sekSftp,
            'sftp: ' + SftpStatusName(LCode) + ': ' + AContext +
            ' (' + LMsg + ')');
        raise ESSHError.Create(sekSftp,
          'sftp: ' + SftpStatusName(LCode) + ': ' + AContext);
      end;
      LOk := False;
      for I := Low(AAcceptable) to High(AAcceptable) do
        if AAcceptable[I] = ARespType then
        begin
          LOk := True;
          Break;
        end;
      if not LOk then
        raise ESSHError.Create(sekProtocol,
          'sftp: unexpected reply type ' + IntToStr(ARespType) +
          ' for context ' + AContext);
      Result := LRaw;
      Exit;
    finally
      LR.Free;
    end;
  end;
end;

end.
