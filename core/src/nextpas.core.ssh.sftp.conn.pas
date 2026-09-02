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
  TSftpBuffered = record
    State: Byte; // 0 empty,1 occupied,2 tombstone
    Id: UInt32;
    Raw: TBytes;
    RespType: Byte;
  end;

  TSftpConnection = class
  private
    FWire: ISftpWire;
    FTimeoutMs: Integer;
    FNextId: UInt32;
    FBuffered: array of TSftpBuffered; { out-of-order stash: hash slots SFTP_PIPELINE_WINDOW*2=32, O(1) probe, zero-copy ref }
    FBufferedMask: Integer;
    FBufferedCount: Integer;
    function BufferedHash(AId: UInt32): Integer; inline;
    function FindBuffered(AId: UInt32): Integer; inline;
    function FindInsertSlot(AId: UInt32): Integer; inline;
  public
    constructor Create(AWire: ISftpWire; ATimeoutMs: Integer);
    destructor Destroy; override;
    procedure Handshake;
    function RoundTrip(AType: Byte; const APayload: TBytes;
      const AAcceptable: array of Byte; out ARespType: Byte;
      const AContext: string): TBytes;
    { pipeline: non-blocking send + ordered recv with disorder buffering; SFTP_PIPELINE_WINDOW=16 }
    function SendRequest(AType: Byte; const APayload: TBytes): UInt32;
    function RecvForId(AId: UInt32; const AAcceptable: array of Byte; out ARespType: Byte;
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
  // hash slots: fixed 32 (=SFTP_PIPELINE_WINDOW*2), load <=0.5, O(1) avg, no BytesEnsureCapacity churn
  FBufferedMask := 31;
  FBufferedCount := 0;
  SetLength(FBuffered, 32);
end;

destructor TSftpConnection.Destroy;
var I: Integer;
begin
  // stability: clear owned TBytes refs before finalization, avoid lingering refcount
  for I := 0 to High(FBuffered) do
    if FBuffered[I].State = 1 then
    begin
      FBuffered[I].Raw := nil;
      FBuffered[I].State := 0;
    end;
  SetLength(FBuffered, 0);
  FBufferedMask := 0;
  FBufferedCount := 0;
  inherited Destroy;
end;

function TSftpConnection.AllocId: UInt32;
begin
  Result := FNextId;
  Inc(FNextId);
end;

function TSftpConnection.BufferedHash(AId: UInt32): Integer; inline;
begin
  // perf: Knuth multiplicative 2654435761 spreads sequential ids across 32 slots, & mask O(1), inline, zero alloc
  Result := Integer((AId * 2654435761) and UInt32(FBufferedMask));
end;

function TSftpConnection.FindBuffered(AId: UInt32): Integer; inline;
var LIdx, LStart: Integer;
begin
  LIdx := BufferedHash(AId);
  LStart := LIdx;
  while True do
  begin
    case FBuffered[LIdx].State of
      0: Exit(-1);
      1: if FBuffered[LIdx].Id = AId then Exit(LIdx);
      2: ;
    end;
    LIdx := (LIdx + 1) and FBufferedMask;
    if LIdx = LStart then Exit(-1);
  end;
end;

function TSftpConnection.FindInsertSlot(AId: UInt32): Integer; inline;
var LIdx, LStart, LFirstTomb: Integer;
begin
  LIdx := BufferedHash(AId);
  LStart := LIdx;
  LFirstTomb := -1;
  while True do
  begin
    case FBuffered[LIdx].State of
      0: begin
           if LFirstTomb <> -1 then Exit(LFirstTomb);
           Exit(LIdx);
         end;
      1: if FBuffered[LIdx].Id = AId then Exit(LIdx);
      2: if LFirstTomb = -1 then LFirstTomb := LIdx;
    end;
    LIdx := (LIdx + 1) and FBufferedMask;
    if LIdx = LStart then
    begin
      if LFirstTomb <> -1 then Exit(LFirstTomb);
      Exit(-1);
    end;
  end;
end;

function TSftpConnection.SendRequest(AType: Byte; const APayload: TBytes): UInt32;
var LW: TsshWriter;
begin
  Result := AllocId;
  LW := TsshWriter.Create(5 + Length(APayload));
  try
    LW.PutByte(AType);
    LW.PutUInt32(Result);
    LW.PutRaw(APayload);
    FWire.Send(LW.ToBytes);
  finally
    LW.Free;
  end;
end;

function TSftpConnection.RecvForId(AId: UInt32; const AAcceptable: array of Byte; out ARespType: Byte;
  const AContext: string): TBytes;
var
  LR: TsshReader;
  LRaw: TBytes;
  LRid, LCode: UInt32;
  LMsg: string;
  I, LIdx, LSlot: Integer;
  LOk: Boolean;
begin
  LIdx := FindBuffered(AId);
  if LIdx >= 0 then
  begin
    // perf: O(1) hash hit, zero-copy ref move, tombstone O(1) (no Move/shift), inline
    LRaw := FBuffered[LIdx].Raw;
    ARespType := FBuffered[LIdx].RespType;
    FBuffered[LIdx].Raw := nil;
    FBuffered[LIdx].State := 2;
    Dec(FBufferedCount);
    // fall through to validation
  end
  else
  begin
    while True do
    begin
      LRaw := FWire.Recv(FTimeoutMs);
      if Length(LRaw) < 5 then
        raise ESSHError.Create(sekProtocol, 'sftp: truncated packet');
      LR := TsshReader.Create(LRaw);
      try
        ARespType := LR.ReadByte;
        LRid := LR.ReadUInt32;
      finally
        LR.Free;
      end;
      if LRid <> AId then
      begin
        // perf: O(1) hash insert, zero-copy ref, no SetLength/Move per packet, inline probe
        LSlot := FindInsertSlot(LRid);
        if LSlot < 0 then
          raise ESSHError.Create(sekProtocol, 'sftp: out-of-order buffer full');
        FBuffered[LSlot].State := 1;
        FBuffered[LSlot].Id := LRid;
        FBuffered[LSlot].Raw := LRaw;
        FBuffered[LSlot].RespType := ARespType;
        Inc(FBufferedCount);
        Continue;
      end;
      Break;
    end;
  end;
  // STATUS handling (OK/EOF vs error)
  if ARespType = SSH_FXP_STATUS then
  begin
    LR := TsshReader.Create(LRaw);
    try
      LR.ReadByte;
      LR.ReadUInt32;
      LCode := LR.ReadUInt32;
      if (LCode = SSH_FX_OK) or (LCode = SSH_FX_EOF) then
      begin
        Result := LRaw;
        Exit;
      end;
      LMsg := '';
      try
        LMsg := LR.ReadStringText;
      except
        on E: ESSHError do LMsg := '';
      end;
      if LMsg <> '' then
        raise ESSHError.Create(sekSftp,
          'sftp: ' + SftpStatusName(LCode) + ': ' + AContext + ' (' + LMsg + ')');
      raise ESSHError.Create(sekSftp,
        'sftp: ' + SftpStatusName(LCode) + ': ' + AContext);
    finally
      LR.Free;
    end;
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
      'sftp: unexpected reply type ' + nextpas.core.text.conv.IntToStr(Int64(ARespType)) +
      ' for context ' + AContext);
  Result := LRaw;
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
begin
  LId := SendRequest(AType, APayload);
  Result := RecvForId(LId, AAcceptable, ARespType, AContext);
end;

end.
