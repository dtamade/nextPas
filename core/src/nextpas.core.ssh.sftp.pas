unit nextpas.core.ssh.sftp;

{** nextpas.core.ssh - SFTP v3 文件操作面（draft-ietf-secsh-filexfer-02 子集）。
 *
 * 运行在 session 类型的 "sftp" 子系统通道之上。协议核心（请求应答状态机、
 * 属性编解码、目录列举）通过 ISftpWire 缝隙与通道层解耦：生产实现
 * TSshChannelWire 走 CHANNEL_DATA 流；测试用脚本化假线材密闭覆盖。
 *
 * 语义约定：
 *  - 同步一问一答，无流水线（流水线属后续 slice）；request-id 单调递增，
 *    应答 id 不匹配视为迟滞帧跳过。
 *  - STATUS 失败码抛 ESSHError(sekSftp)，消息携带服务端原文与路径上下文；
 *    EOF 码由读取/列举路径内部消化为正常结束。
 *  - READ/WRITE 分片 32760 字节（≤ 常见对端 MaxPacket，留头部余量）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.ssh.base,
  nextpas.core.ssh.errors,
  nextpas.core.ssh.buffer,
  nextpas.core.ssh.channel,
  nextpas.core.ssh.transport;

const
  { SFTP 包类型 }
  SSH_FXP_INIT = 1;
  SSH_FXP_VERSION = 2;
  SSH_FXP_OPEN = 3;
  SSH_FXP_CLOSE = 4;
  SSH_FXP_READ = 5;
  SSH_FXP_WRITE = 6;
  SSH_FXP_LSTAT = 7;
  SSH_FXP_OPENDIR = 11;
  SSH_FXP_READDIR = 12;
  SSH_FXP_REMOVE = 13;
  SSH_FXP_MKDIR = 14;
  SSH_FXP_RMDIR = 15;
  SSH_FXP_REALPATH = 16;
  SSH_FXP_STAT = 17;
  SSH_FXP_RENAME = 18;
  SSH_FXP_STATUS = 101;
  SSH_FXP_HANDLE = 102;
  SSH_FXP_DATA = 103;
  SSH_FXP_NAME = 104;
  SSH_FXP_ATTRS = 105;

  { STATUS 码 }
  SSH_FX_OK = 0;
  SSH_FX_EOF = 1;
  SSH_FX_NO_SUCH_FILE = 2;
  SSH_FX_PERMISSION_DENIED = 3;
  SSH_FX_FAILURE = 4;
  SSH_FX_BAD_MESSAGE = 5;
  SSH_FX_OP_UNSUPPORTED = 8;

  { OPEN pflags }
  SSH_FXF_READ = $00000001;
  SSH_FXF_WRITE = $00000002;
  SSH_FXF_CREAT = $00000008;
  SSH_FXF_TRUNC = $00000010;

  { ATTRS 标志位 }
  SSH_FILEXFER_ATTR_SIZE = $00000001;
  SSH_FILEXFER_ATTR_UIDGID = $00000002;
  SSH_FILEXFER_ATTR_PERMISSIONS = $00000004;
  SSH_FILEXFER_ATTR_ACMODTIME = $00000008;
  SSH_FILEXFER_ATTR_EXTENDED = $80000000;

  { 单次 READ/WRITE 数据分片上限 }
  SFTP_CHUNK_SIZE = 32760;

type
  { 文件属性（v3 掩码子集）}
  TSftpAttrs = record
    Flags: UInt32;
    Size: UInt64;
    Uid: UInt32;
    Gid: UInt32;
    Permissions: UInt32;
    ATime: UInt32;
    MTime: UInt32;
    function IsDir: Boolean;
    function IsRegular: Boolean;
  end;

  { 目录项 }
  TSftpDirEntry = record
    Name: string;      { basename }
    LongName: string;  { ls -l 风格长行（服务端生成）}
    Attrs: TSftpAttrs;
  end;
  TSftpDirEntryArray = array of TSftpDirEntry;

  { SFTP 线材缝隙：一个完整 SFTP 包（不含长度前缀）的收发。
    生产实现走通道数据流；测试注入脚本化应答。}
  ISftpWire = interface
    ['{9C1E6E10-4A11-4F72-9D30-5B0000000001}']
    procedure Send(const APacket: TBytes);
    function Recv(ATimeoutMs: Integer): TBytes;
  end;

  { 文件系统门面。由 ISshSession.OpenFileSystem 构造；需已认证会话。}
  ISshFileSystem = interface
    ['{9C1E6E10-4A11-4F72-9D30-5B0000000002}']
    function RealPath(const APath: string): string;
    function Stat(const APath: string): TSftpAttrs;
    function Lstat(const APath: string): TSftpAttrs;
    function ListDir(const APath: string): TSftpDirEntryArray;
    function ReadFile(const APath: string): TBytes;
    procedure WriteFile(const APath: string; const AData: TBytes);
    procedure Remove(const APath: string);
    procedure Mkdir(const APath: string);
    procedure Rmdir(const APath: string);
    procedure Rename(const AOldPath, ANewPath: string);
  end;

{ 属性编解码（导出供测试与二次开发）}
procedure PutAttrs(var AW: TsshWriter; const AAttrs: TSftpAttrs);
function ReadAttrs(var AR: TsshReader): TSftpAttrs;

{ 在已打开并已通过 subsystem 请求的通道上建立 SFTP 连接：
  完成 INIT/VERSION 握手后返回文件系统门面。通道所有权随之移交。}
function SftpOpenOnChannel(AChannel: TSshChannel;
  ATimeoutMs: Integer): ISshFileSystem;

{ 线材级入口：在既有 ISftpWire 上握手并返回门面。
  测试注入脚本线材；嵌入方可自备线材接入非标准传输。}
function SftpOpenOnWire(AWire: ISftpWire;
  ATimeoutMs: Integer): ISshFileSystem;

{ 一步到位：开 session 通道 + sftp 子系统 + 版本握手。
  失败时回收通道；成功后通道由返回的门面持有。}
function SftpOpenOnTransport(ATransport: TSshClientTransport;
  AInitialWindow, AMaxPacket, ATimeoutMs: Integer): ISshFileSystem;

implementation

const
  PROTOCOL_VERSION = 3;
  MAX_PACKET_SIZE = 256 * 1024;   { 单个 SFTP 包硬上限（防对端滥用）}

{ ---- 属性 ---- }

function TSftpAttrs.IsDir: Boolean;
begin
  Result := False;
  if (Flags and SSH_FILEXFER_ATTR_PERMISSIONS) = 0 then
    Exit;
  Result := (Permissions and $F000) = $4000;   { S_IFDIR }
end;

function TSftpAttrs.IsRegular: Boolean;
begin
  Result := False;
  if (Flags and SSH_FILEXFER_ATTR_PERMISSIONS) = 0 then
    Exit;
  Result := (Permissions and $F000) = $8000;   { S_IFREG }
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
  { EXTENDED 对（extension-name, extension-data）按声明数量跳过 }
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

{ ---- 通道线材 ---- }

type
  { CHANNEL_DATA 流 → 长度前缀 SFTP 包流的重组器 }
  TSshChannelWire = class(TInterfacedObject, ISftpWire)
  private
    FChan: TSshChannel;
    FBuf: TBytes;      { 未消费的流字节 }
    function TakeFromBuffer(ACount: Integer): TBytes;
  public
    constructor Create(AChannel: TSshChannel);
    destructor Destroy; override;
    procedure Send(const APacket: TBytes);
    function Recv(ATimeoutMs: Integer): TBytes;
  end;

constructor TSshChannelWire.Create(AChannel: TSshChannel);
begin
  inherited Create;
  FChan := AChannel;
end;

destructor TSshChannelWire.Destroy;
begin
  { 通道所有权在 TSshFileSystem：线材仅引用 }
  inherited Destroy;
end;

procedure TSshChannelWire.Send(const APacket: TBytes);
var
  LW: TsshWriter;
begin
  LW := TsshWriter.Create(4 + Length(APacket));
  try
    LW.PutUInt32(UInt32(Length(APacket)));
    LW.PutRaw(APacket);
    FChan.SendData(LW.ToBytes);
  finally
    LW.Free;
  end;
end;

function TSshChannelWire.TakeFromBuffer(ACount: Integer): TBytes;
begin
  Result := Copy(FBuf, 0, ACount);
  FBuf := Copy(FBuf, ACount, Length(FBuf) - ACount);
end;

function TSshChannelWire.Recv(ATimeoutMs: Integer): TBytes;
var
  LChunk: TBytes;
  LExt: Boolean;
  LLen: UInt32;
begin
  while SizeUInt(Length(FBuf)) < 4 do
  begin
    if not FChan.PumpData(LChunk, LExt) then
      raise ESSHError.Create(sekIO, 'sftp: channel closed by peer');
    AppendChunk(FBuf, LChunk);
  end;
  LLen := (UInt32(FBuf[0]) shl 24) or (UInt32(FBuf[1]) shl 16) or
    (UInt32(FBuf[2]) shl 8) or UInt32(FBuf[3]);
  if (LLen < 1) or (LLen > MAX_PACKET_SIZE) then
    raise ESSHError.Create(sekProtocol,
      'sftp: unreasonable packet length ' + IntToStr(LLen));
  while SizeUInt(Length(FBuf)) < SizeUInt(4 + LLen) do
  begin
    if not FChan.PumpData(LChunk, LExt) then
      raise ESSHError.Create(sekIO, 'sftp: channel closed mid-packet');
    AppendChunk(FBuf, LChunk);
  end;
  FBuf := Copy(FBuf, 4, Length(FBuf) - 4);   { 去掉长度前缀 }
  Result := TakeFromBuffer(Integer(LLen));
end;

{ ---- 连接状态机 ---- }

type
  TSftpConnection = class
  private
    FWire: ISftpWire;
    FTimeoutMs: Integer;
    FNextId: UInt32;
    function AllocId: UInt32;
  public
    constructor Create(AWire: ISftpWire; ATimeoutMs: Integer);
    { INIT → VERSION 协商；服务端版本高于我方时按 v3 子集工作，
      低于我方时拒绝（无共同版本）。}
    procedure Handshake;
    { 发请求并等待同 id 应答。非 OK 的 STATUS 抛 sekSftp；
      应答类型不在可接受集内视为协议错误。返回完整原始包（含类型与 id）。}
    function RoundTrip(AType: Byte; const APayload: TBytes;
      const AAcceptable: array of Byte; out ARespType: Byte;
      const AContext: string): TBytes;
  end;

function SftpStatusName(ACode: UInt32): string;
begin
  case ACode of
    SSH_FX_OK:               Result := 'ok';
    SSH_FX_EOF:              Result := 'eof';
    SSH_FX_NO_SUCH_FILE:     Result := 'no-such-file';
    SSH_FX_PERMISSION_DENIED: Result := 'permission-denied';
    SSH_FX_FAILURE:          Result := 'failure';
    SSH_FX_BAD_MESSAGE:      Result := 'bad-message';
    SSH_FX_OP_UNSUPPORTED:   Result := 'op-unsupported';
  else
    Result := 'status-' + IntToStr(ACode);
  end;
end;

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

procedure TSftpConnection.Handshake;
var
  LW: TsshWriter;
  LR: TsshReader;
  LRaw: TBytes;
begin
  LW := TsshWriter.Create(5);
  try
    LW.PutByte(SSH_FXP_INIT);
    LW.PutUInt32(PROTOCOL_VERSION);
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
    if LR.ReadUInt32 < PROTOCOL_VERSION then
      raise ESSHError.Create(sekNegotiation,
        'sftp: server version below 3');
    { 服务端扩展对（可选）就地忽略：本实现只用 v3 公共子集 }
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
        Continue;   { 迟滞/错配应答：跳过等下一条 }
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
          { EOF 由调用方语义化处理：原样返回（调用方查类型+码）}
          Result := LRaw;
          Exit;
        end;
        LMsg := '';
        try
          LMsg := LR.ReadStringText;
        except
          on LE: ESSHError do
            LMsg := '';   { 错误消息与语言标签均可选 }
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

{ ---- 文件系统门面 ---- }

type
  TSshFileSystem = class(TInterfacedObject, ISshFileSystem)
  private
    FConn: TSftpConnection;
    FOwnsChan: Boolean;
    FChan: TSshChannel;
    function OpenHandle(const APath: string; APFlags: UInt32): TBytes;
    procedure CloseHandle(const AHandle: TBytes);
    function StatOf(AIsLstat: Boolean; const APath: string): TSftpAttrs;
  public
    constructor Create(AChannel: TSshChannel; ATimeoutMs: Integer);
    constructor CreateWithWire(AWire: ISftpWire; ATimeoutMs: Integer);
    destructor Destroy; override;
    function RealPath(const APath: string): string;
    function Stat(const APath: string): TSftpAttrs;
    function Lstat(const APath: string): TSftpAttrs;
    function ListDir(const APath: string): TSftpDirEntryArray;
    function ReadFile(const APath: string): TBytes;
    procedure WriteFile(const APath: string; const AData: TBytes);
    procedure Remove(const APath: string);
    procedure Mkdir(const APath: string);
    procedure Rmdir(const APath: string);
    procedure Rename(const AOldPath, ANewPath: string);
  end;

constructor TSshFileSystem.Create(AChannel: TSshChannel; ATimeoutMs: Integer);
var
  LConn: TSftpConnection;
begin
  inherited Create;
  FOwnsChan := True;
  { 风险操作全部完成才落字段：构造中途抛异常时 FPC 自动跑析构，
    字段尚为 nil 则不回收，所有权仍归调用方的 finally }
  LConn := TSftpConnection.Create(TSshChannelWire.Create(AChannel), ATimeoutMs);
  try
    LConn.Handshake;
  except
    LConn.Free;
    raise;
  end;
  FChan := AChannel;
  FConn := LConn;
end;

constructor TSshFileSystem.CreateWithWire(AWire: ISftpWire;
  ATimeoutMs: Integer);
var
  LConn: TSftpConnection;
begin
  inherited Create;
  FOwnsChan := False;
  FChan := nil;
  LConn := TSftpConnection.Create(AWire, ATimeoutMs);
  try
    LConn.Handshake;
  except
    LConn.Free;
    raise;
  end;
  FConn := LConn;
end;

destructor TSshFileSystem.Destroy;
begin
  FConn.Free;
  if FOwnsChan and (FChan <> nil) then
  begin
    FChan.TryClose;
    FChan.Free;
    FChan := nil;
  end;
  inherited Destroy;
end;

function TSshFileSystem.OpenHandle(const APath: string; APFlags: UInt32): TBytes;
var
  LTail: TsshWriter;
  LRaw: TBytes;
  LR: TsshReader;
  LRT: Byte;
begin
  LTail := TsshWriter.Create(64);
  try
    LTail.PutStringText(APath);
    LTail.PutUInt32(APFlags);
    PutAttrs(LTail, Default(TSftpAttrs));   { attrs.flags = 0 占位 }
    LRaw := FConn.RoundTrip(SSH_FXP_OPEN, LTail.ToBytes,
      [SSH_FXP_HANDLE], LRT, APath);
  finally
    LTail.Free;
  end;
  LR := TsshReader.Create(LRaw);
  try
    LR.ReadByte;
    LR.ReadUInt32;
    Result := LR.ReadStringBytes;
  finally
    LR.Free;
  end;
end;

procedure TSshFileSystem.CloseHandle(const AHandle: TBytes);
var
  LTail: TsshWriter;
  LRT: Byte;
begin
  LTail := TsshWriter.Create(16);
  try
    LTail.PutStringBytes(AHandle);
    FConn.RoundTrip(SSH_FXP_CLOSE, LTail.ToBytes, [SSH_FXP_STATUS], LRT, 'close');
  finally
    LTail.Free;
  end;
end;

function TSshFileSystem.StatOf(AIsLstat: Boolean; const APath: string): TSftpAttrs;
var
  LTail: TsshWriter;
  LRaw: TBytes;
  LR: TsshReader;
  LRT: Byte;
begin
  LTail := TsshWriter.Create(64);
  try
    LTail.PutStringText(APath);
    if AIsLstat then
      LRaw := FConn.RoundTrip(SSH_FXP_LSTAT, LTail.ToBytes,
        [SSH_FXP_ATTRS], LRT, APath)
    else
      LRaw := FConn.RoundTrip(SSH_FXP_STAT, LTail.ToBytes,
        [SSH_FXP_ATTRS], LRT, APath);
  finally
    LTail.Free;
  end;
  LR := TsshReader.Create(LRaw);
  try
    LR.ReadByte;
    LR.ReadUInt32;
    Result := ReadAttrs(LR);
  finally
    LR.Free;
  end;
end;

function TSshFileSystem.RealPath(const APath: string): string;
var
  LTail: TsshWriter;
  LRaw: TBytes;
  LR: TsshReader;
  LRT: Byte;
  LN, I: Integer;
begin
  Result := '';
  LTail := TsshWriter.Create(64);
  try
    LTail.PutStringText(APath);
    LRaw := FConn.RoundTrip(SSH_FXP_REALPATH, LTail.ToBytes,
      [SSH_FXP_NAME], LRT, APath);
  finally
    LTail.Free;
  end;
  LR := TsshReader.Create(LRaw);
  try
    LR.ReadByte;
    LR.ReadUInt32;
    LN := Integer(LR.ReadUInt32);
    for I := 1 to LN do
    begin
      if Result <> '' then
        Result := Result + ', ';
      Result := Result + LR.ReadStringText;   { 取第一个分量为主结果 }
      LR.ReadStringText;                       { longname }
      ReadAttrs(LR);
    end;
  finally
    LR.Free;
  end;
end;

function TSshFileSystem.Stat(const APath: string): TSftpAttrs;
begin
  Result := StatOf(False, APath);
end;

function TSshFileSystem.Lstat(const APath: string): TSftpAttrs;
begin
  Result := StatOf(True, APath);
end;

function TSshFileSystem.ListDir(const APath: string): TSftpDirEntryArray;
var
  LTail: TsshWriter;
  LRaw: TBytes;
  LR: TsshReader;
  LRT: Byte;
  LHandle: TBytes;
  LEof: Boolean;
  LN, I, LBase: Integer;
begin
  Result := nil;
  LTail := TsshWriter.Create(64);
  try
    LTail.PutStringText(APath);
    LRaw := FConn.RoundTrip(SSH_FXP_OPENDIR, LTail.ToBytes,
      [SSH_FXP_HANDLE], LRT, APath);
  finally
    LTail.Free;
  end;
  LR := TsshReader.Create(LRaw);
  try
    LR.ReadByte;
    LR.ReadUInt32;
    LHandle := LR.ReadStringBytes;
  finally
    LR.Free;
  end;

  try
    repeat
      LTail := TsshWriter.Create(16);
      try
        LTail.PutStringBytes(LHandle);
        LRaw := FConn.RoundTrip(SSH_FXP_READDIR, LTail.ToBytes,
          [SSH_FXP_NAME, SSH_FXP_STATUS], LRT, APath);
      finally
        LTail.Free;
      end;
      LEof := False;
      if LRT = SSH_FXP_STATUS then
      begin
        { 仅接受 EOF 收尾；其余失败码已在 RoundTrip 抛出 }
        LEof := True;
      end
      else
      begin
        LR := TsshReader.Create(LRaw);
        try
          LR.ReadByte;
          LR.ReadUInt32;
          LN := Integer(LR.ReadUInt32);
          for I := 1 to LN do
          begin
            LBase := Length(Result);
            SetLength(Result, LBase + 1);
            Result[LBase].Name := LR.ReadStringText;
            Result[LBase].LongName := LR.ReadStringText;
            Result[LBase].Attrs := ReadAttrs(LR);
            { "." 与 ".." 不进结果面（POSIX 惯例由调用方自行拼路径）}
            if (Result[LBase].Name = '.') or (Result[LBase].Name = '..') then
              SetLength(Result, LBase);
          end;
        finally
          LR.Free;
        end;
      end;
    until LEof;
  finally
    CloseHandle(LHandle);
  end;
end;

function TSshFileSystem.ReadFile(const APath: string): TBytes;
var
  LHandle: TBytes;
  LOffset: UInt64;
  LTail: TsshWriter;
  LRaw: TBytes;
  LR: TsshReader;
  LRT: Byte;
  LChunk: TBytes;
begin
  Result := nil;
  LHandle := OpenHandle(APath, SSH_FXF_READ);
  try
    LOffset := 0;
    repeat
      LTail := TsshWriter.Create(24);
      try
        LTail.PutStringBytes(LHandle);
        LTail.PutUInt64(LOffset);
        LTail.PutUInt32(SFTP_CHUNK_SIZE);
        LRaw := FConn.RoundTrip(SSH_FXP_READ, LTail.ToBytes,
          [SSH_FXP_DATA, SSH_FXP_STATUS], LRT, APath);
      finally
        LTail.Free;
      end;
      if LRT = SSH_FXP_STATUS then
        Break;   { EOF 收尾；其余失败码已抛 }
      LR := TsshReader.Create(LRaw);
      try
        LR.ReadByte;
        LR.ReadUInt32;
        LChunk := LR.ReadStringBytes;
      finally
        LR.Free;
      end;
      AppendChunk(Result, LChunk);
      Inc(LOffset, SizeUInt(Length(LChunk)));
      { 零长度 DATA 且未给 EOF：防呆，避免死循环 }
      if Length(LChunk) = 0 then
        Break;
    until False;
  finally
    CloseHandle(LHandle);
  end;
end;

procedure TSshFileSystem.WriteFile(const APath: string; const AData: TBytes);
var
  LHandle: TBytes;
  LOffset: UInt64;
  LOff: SizeUInt;
  LTake: SizeUInt;
  LTail: TsshWriter;
  LRT: Byte;
begin
  LHandle := OpenHandle(APath, SSH_FXF_WRITE or SSH_FXF_CREAT or SSH_FXF_TRUNC);
  try
    LOff := 0;
    LOffset := 0;
    while LOff < SizeUInt(Length(AData)) do
    begin
      LTake := SizeUInt(Length(AData)) - LOff;
      if LTake > SFTP_CHUNK_SIZE then
        LTake := SFTP_CHUNK_SIZE;
      LTail := TsshWriter.Create(24 + Integer(LTake));
      try
        LTail.PutStringBytes(LHandle);
        LTail.PutUInt64(LOffset);
        LTail.PutStringBytes(Copy(AData, LOff, LTake));
        FConn.RoundTrip(SSH_FXP_WRITE, LTail.ToBytes, [SSH_FXP_STATUS],
          LRT, APath);
      finally
        LTail.Free;
      end;
      Inc(LOff, LTake);
      Inc(LOffset, LTake);
    end;
  finally
    CloseHandle(LHandle);
  end;
end;

procedure TSshFileSystem.Remove(const APath: string);
var
  LTail: TsshWriter;
  LRT: Byte;
begin
  LTail := TsshWriter.Create(64);
  try
    LTail.PutStringText(APath);
    FConn.RoundTrip(SSH_FXP_REMOVE, LTail.ToBytes, [SSH_FXP_STATUS], LRT, APath);
  finally
    LTail.Free;
  end;
end;

procedure TSshFileSystem.Mkdir(const APath: string);
var
  LTail: TsshWriter;
  LRT: Byte;
begin
  LTail := TsshWriter.Create(80);
  try
    LTail.PutStringText(APath);
    PutAttrs(LTail, Default(TSftpAttrs));
    FConn.RoundTrip(SSH_FXP_MKDIR, LTail.ToBytes, [SSH_FXP_STATUS], LRT, APath);
  finally
    LTail.Free;
  end;
end;

procedure TSshFileSystem.Rmdir(const APath: string);
var
  LTail: TsshWriter;
  LRT: Byte;
begin
  LTail := TsshWriter.Create(64);
  try
    LTail.PutStringText(APath);
    FConn.RoundTrip(SSH_FXP_RMDIR, LTail.ToBytes, [SSH_FXP_STATUS], LRT, APath);
  finally
    LTail.Free;
  end;
end;

procedure TSshFileSystem.Rename(const AOldPath, ANewPath: string);
var
  LTail: TsshWriter;
  LRT: Byte;
begin
  LTail := TsshWriter.Create(128);
  try
    LTail.PutStringText(AOldPath);
    LTail.PutStringText(ANewPath);
    FConn.RoundTrip(SSH_FXP_RENAME, LTail.ToBytes, [SSH_FXP_STATUS],
      LRT, AOldPath + ' -> ' + ANewPath);
  finally
    LTail.Free;
  end;
end;

function SftpOpenOnChannel(AChannel: TSshChannel;
  ATimeoutMs: Integer): ISshFileSystem;
begin
  if AChannel = nil then
    raise ESSHError.Create(sekProtocol, 'sftp: nil channel');
  AChannel.RequestSubsystem('sftp');
  Result := TSshFileSystem.Create(AChannel, ATimeoutMs);
end;

function SftpOpenOnWire(AWire: ISftpWire;
  ATimeoutMs: Integer): ISshFileSystem;
begin
  if AWire = nil then
    raise ESSHError.Create(sekProtocol, 'sftp: nil wire');
  Result := TSshFileSystem.CreateWithWire(AWire, ATimeoutMs) as ISshFileSystem;
end;

function SftpOpenOnTransport(ATransport: TSshClientTransport;
  AInitialWindow, AMaxPacket, ATimeoutMs: Integer): ISshFileSystem;
var
  LChan: TSshChannel;
begin
  LChan := TSshChannel.Create(ATransport, AInitialWindow, AMaxPacket, ATimeoutMs);
  try
    LChan.OpenSession;
    { 所有权移交：成功后由 TSshFileSystem 持有并负责互关 }
    Result := SftpOpenOnChannel(LChan, ATimeoutMs);
    LChan := nil;
  finally
    if LChan <> nil then
      LChan.Free;
  end;
end;

end.
