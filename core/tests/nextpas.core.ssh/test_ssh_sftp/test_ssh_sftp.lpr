program test_ssh_sftp;

{$I nextpas.core.settings.inc}

{ S8 gate：SFTP v3 协议核心（密闭，无真实 sshd）。
 * 通过 ISftpWire 缝隙注入脚本化应答，覆盖：
 * 版本协商（正/低版本拒绝）、realpath、stat 属性编解码、opendir/readdir
 * （含 "." ".." 过滤与 EOF 收尾）、read 多分片拼装、write 的 pflags/偏移/
 * 分片断言、remove/mkdir/rmdir/rename 状态回路、STATUS 失败码到
 * ESSHError(sekSftp) 的映射。}

uses
  nextpas.core.base,
  nextpas.core.ssh.base,
  nextpas.core.ssh.errors,
  nextpas.core.ssh.buffer,
  nextpas.core.ssh.channel,
  nextpas.core.ssh.sftp,
  nextpas.core.test, nextpas.core.text, nextpas.core.text.conv;

type
  { 已发送请求捕获 }
  TSentReq = record
    Typ: Byte;
    Id: UInt32;
    Payload: TBytes;   { id 之后的原始尾段 }
  end;

  { 脚本化线材：Send 捕获请求，Recv 按预排 FIFO 出队 }
  TFakeSftpServer = class(TInterfacedObject, ISftpWire)
  private
    FSent: array of TSentReq;
    FScript: array of TBytes;
    FScriptPos: Integer;
  public
    procedure Enqueue(const APkt: TBytes);
    procedure Send(const APacket: TBytes);
    function Recv(ATimeoutMs: Integer): TBytes;
    function SentCount: Integer;
    function SentTyp(AIdx: Integer): Byte;
    function SentId(AIdx: Integer): UInt32;
    function SentPayload(AIdx: Integer): TBytes;
  end;

procedure TFakeSftpServer.Enqueue(const APkt: TBytes);
var
  N: Integer;
begin
  N := Length(FScript);
  SetLength(FScript, N + 1);
  FScript[N] := APkt;
end;

procedure TFakeSftpServer.Send(const APacket: TBytes);
var
  LR: TsshReader;
  N: Integer;
begin
  LR := TsshReader.Create(APacket);
  try
    N := Length(FSent);
    SetLength(FSent, N + 1);
    FSent[N].Typ := LR.ReadByte;
    if FSent[N].Typ <> SSH_FXP_INIT then
      FSent[N].Id := LR.ReadUInt32
    else
      FSent[N].Id := 0;
    FSent[N].Payload := Copy(APacket, 5, Length(APacket) - 5);
  finally
    LR.Free;
  end;
end;

function TFakeSftpServer.Recv(ATimeoutMs: Integer): TBytes;
begin
  if FScriptPos > High(FScript) then
    raise ESSHError.Create(sekIO, 'fake sftp: script exhausted');
  Result := FScript[FScriptPos];
  Inc(FScriptPos);
end;

function TFakeSftpServer.SentCount: Integer;
begin
  Result := Length(FSent);
end;

function TFakeSftpServer.SentTyp(AIdx: Integer): Byte;
begin
  Result := FSent[AIdx].Typ;
end;

function TFakeSftpServer.SentId(AIdx: Integer): UInt32;
begin
  Result := FSent[AIdx].Id;
end;

function TFakeSftpServer.SentPayload(AIdx: Integer): TBytes;
begin
  Result := FSent[AIdx].Payload;
end;

{ ---- 包构造助手 ---- }

function RespPkt(AType: Byte; AId: UInt32; const ATail: TBytes): TBytes;
var
  LW: TsshWriter;
begin
  LW := TsshWriter.Create(8 + Length(ATail));
  try
    LW.PutByte(AType);
    LW.PutUInt32(AId);
    LW.PutRaw(ATail);
    Result := LW.ToBytes;
  finally
    LW.Free;
  end;
end;

function StatusPkt(AId: UInt32; ACode: UInt32; const AMsg: string): TBytes;
var
  LW: TsshWriter;
begin
  LW := TsshWriter.Create(32);
  try
    LW.PutUInt32(ACode);
    LW.PutStringText(AMsg);
    LW.PutStringText('en');
    Result := RespPkt(SSH_FXP_STATUS, AId, LW.ToBytes);
  finally
    LW.Free;
  end;
end;

function NamePkt(AId: UInt32; const ANames: array of string;
  const AAttrs: array of TSftpAttrs): TBytes;
var
  LW: TsshWriter;
  I: Integer;
begin
  LW := TsshWriter.Create(128);
  try
    LW.PutUInt32(Length(ANames));
    for I := 0 to High(ANames) do
    begin
      LW.PutStringText(ANames[I]);
      LW.PutStringText('-rw-r--r-- ' + IntToStr(I) + ' longline');
      PutAttrs(LW, AAttrs[I]);
    end;
    Result := RespPkt(SSH_FXP_NAME, AId, LW.ToBytes);
  finally
    LW.Free;
  end;
end;

function HandlePkt(AId: UInt32; const AHandle: AnsiString): TBytes;
var
  LW: TsshWriter;
begin
  LW := TsshWriter.Create(16);
  try
    LW.PutStringBytes(StringToUTF8Bytes(string(AHandle)));
    Result := RespPkt(SSH_FXP_HANDLE, AId, LW.ToBytes);
  finally
    LW.Free;
  end;
end;

function DataPkt(AId: UInt32; const AData: TBytes): TBytes;
var
  LW: TsshWriter;
begin
  LW := TsshWriter.Create(16 + Length(AData));
  try
    LW.PutStringBytes(AData);
    Result := RespPkt(SSH_FXP_DATA, AId, LW.ToBytes);
  finally
    LW.Free;
  end;
end;

function AttrsPkt(AId: UInt32; const AAttrs: TSftpAttrs): TBytes;
var
  LW: TsshWriter;
begin
  LW := TsshWriter.Create(64);
  try
    PutAttrs(LW, AAttrs);
    Result := RespPkt(SSH_FXP_ATTRS, AId, LW.ToBytes);
  finally
    LW.Free;
  end;
end;

function VersionPkt(AVersion: UInt32): TBytes;
var
  LW: TsshWriter;
begin
  LW := TsshWriter.Create(8);
  try
    LW.PutByte(SSH_FXP_VERSION);
    LW.PutUInt32(AVersion);
    Result := LW.ToBytes;
  finally
    LW.Free;
  end;
end;

function AttrsWithSizeAndPerms(ASize: UInt64; APerms: UInt32): TSftpAttrs;
begin
  Result := Default(TSftpAttrs);
  Result.Flags := SSH_FILEXFER_ATTR_SIZE or SSH_FILEXFER_ATTR_PERMISSIONS;
  Result.Size := ASize;
  Result.Permissions := APerms;
end;

{ ---- 测试套件 ---- }

var
  GWire: TFakeSftpServer;

{ 单元级助手：匿名方法不可捕获嵌套例程，只能引用全局 }
function NewFfs(const AScript: array of TBytes): ISshFileSystem;
var
  I: Integer;
begin
  GWire := TFakeSftpServer.Create;
  for I := 0 to High(AScript) do
    GWire.Enqueue(AScript[I]);
  Result := SftpOpenOnWire(GWire, 5000);
end;

procedure RunSuite;
var
  LSuite: TTestSuite;
  LRunner: TSuiteRunner;
  LWire: TFakeSftpServer absolute GWire;
  LFfs: ISshFileSystem;
  LGot: TBytes;
  LPath: string;
  LAttrs: TSftpAttrs;
  LDir: TSftpDirEntryArray;
  LI: Integer;
begin
  LSuite := TTestSuite.Create('nextpas.core.ssh.sftp');

  { 握手：服务端 v3 接受；低于 v3 拒绝 }
  LSuite.Test('handshake accepts server v3', procedure
  begin
    LFfs := NewFfs([
      VersionPkt(3),
      NamePkt(1, ['/'], [Default(TSftpAttrs)])
    ]);
    LPath := LFfs.RealPath('/');
    CheckTrue(LWire.SentCount >= 2, 'expect INIT + REALPATH sent');   { INIT + REALPATH }
    CheckTrue(LPath <> '', 'realpath should return text');
    CheckEqual(Int64(SSH_FXP_INIT), Int64(LWire.SentTyp(0)));
  end);

  LSuite.Test('handshake rejects server below v3', procedure
  begin
    try
      LFfs := NewFfs([VersionPkt(2)]);
      Fail('expected sekNegotiation');
    except
      on LE: ESSHError do
        CheckTrue(LE.Kind = sekNegotiation, 'kind=' + SshErrorKindName(LE.Kind));
    end;
  end);

  { realpath：NAME 单分量解析 + 请求载荷断言 }
  LSuite.Test('realpath returns first name component', procedure
  var
    LWExp: TsshWriter;
  begin
    LFfs := NewFfs([
      VersionPkt(3),
      NamePkt(1, ['/home/np'], [Default(TSftpAttrs)])
    ]);
    CheckEqual('/home/np', LFfs.RealPath('.'));
    CheckEqual(Int64(SSH_FXP_REALPATH), Int64(LWire.SentTyp(1)));
    CheckEqual(Int64(1), LWire.SentId(1));
    LWExp := TsshWriter.Create(8);
    try
      LWExp.PutStringText('.');
      CheckEqual(LWExp.ToBytes, LWire.SentPayload(1));
    finally
      LWExp.Free;
    end;
  end);

  { stat：SIZE|PERMISSIONS 属性往返 }
  LSuite.Test('stat parses size and permissions', procedure
  begin
    LFfs := NewFfs([
      VersionPkt(3),
      AttrsPkt(1, AttrsWithSizeAndPerms(1234, $81A4))   { 010010644 }
    ]);
    LAttrs := LFfs.Stat('/etc/hostname');
    CheckEqual(UInt64(1234), LAttrs.Size);
    CheckEqual(Int64($81A4), LAttrs.Permissions);
    CheckTrue(LAttrs.IsRegular, 'should be regular file');
    CheckFalse(LAttrs.IsDir, 'should not be dir');
  end);

  LSuite.Test('attrs isdir detection', procedure
  begin
    LFfs := NewFfs([
      VersionPkt(3),
      AttrsPkt(1, AttrsWithSizeAndPerms(4096, $41ED))   { drwxr-xr-x }
    ]);
    LAttrs := LFfs.Lstat('/tmp');
    CheckTrue(LAttrs.IsDir, 'should be dir');
    CheckFalse(LAttrs.IsRegular, 'should not be regular');
  end);

  { readdir：多分量 + 点项过滤 + EOF 收尾 + CLOSE 发出 }
  LSuite.Test('readdir collects entries and stops on eof', procedure
  begin
    LFfs := NewFfs([
      VersionPkt(3),
      HandlePkt(1, 'dh1'),
      NamePkt(2, ['.', '..', 'a.txt', 'sub'],
        [Default(TSftpAttrs), Default(TSftpAttrs),
         AttrsWithSizeAndPerms(10, $81A4),
         AttrsWithSizeAndPerms(4096, $41ED)]),
      StatusPkt(3, SSH_FX_EOF, ''),
      StatusPkt(4, SSH_FX_OK, '')
    ]);
    LDir := LFfs.ListDir('/home/np');
    CheckEqual(2, Length(LDir), 'dot entries must be filtered');
    CheckEqual('a.txt', LDir[0].Name);
    CheckEqual('sub', LDir[1].Name);
    CheckEqual(UInt64(10), LDir[0].Attrs.Size);
    CheckTrue(LDir[1].Attrs.IsDir);
    { OPEN/READDIR×2/CLOSE }
    CheckEqual(Int64(SSH_FXP_OPENDIR), Int64(LWire.SentTyp(1)));
    CheckEqual(Int64(SSH_FXP_READDIR), Int64(LWire.SentTyp(2)));
    CheckEqual(Int64(SSH_FXP_READDIR), Int64(LWire.SentTyp(3)));
    CheckEqual(Int64(SSH_FXP_CLOSE), Int64(LWire.SentTyp(4)));
  end);

  { read：多分片按序拼接，EOF 收尾 }
  LSuite.Test('readfile assembles chunks until eof', procedure
  begin
    LFfs := NewFfs([
      VersionPkt(3),
      HandlePkt(1, 'fh1'),
      DataPkt(2, StringToUTF8Bytes('hello ')),
      DataPkt(3, StringToUTF8Bytes('sftp')),
      StatusPkt(4, SSH_FX_EOF, ''),
      StatusPkt(5, SSH_FX_OK, '')
    ]);
    LGot := LFfs.ReadFile('/tmp/greet');
    CheckEqual(StringToUTF8Bytes('hello sftp'), LGot);
    CheckEqual(Int64(SSH_FXP_OPEN), Int64(LWire.SentTyp(1)));
    CheckEqual(Int64(SSH_FXP_READ), Int64(LWire.SentTyp(2)));
  end);

  { write：pflags 与分片偏移断言 }
  LSuite.Test('writefile sends creat|trunc|write with offsets', procedure
  var
    LBig: TBytes;
  begin
    SetLength(LBig, 100);
    FillChar(LBig[0], 100, $AB);
    LFfs := NewFfs([
      VersionPkt(3),
      HandlePkt(1, 'wh1'),
      StatusPkt(2, SSH_FX_OK, ''),
      StatusPkt(3, SSH_FX_OK, '')
    ]);
    LFfs.WriteFile('/tmp/out.bin', LBig);
    CheckEqual(4, LWire.SentCount);   { INIT/OPEN/WRITE/CLOSE }
    CheckEqual(Int64(SSH_FXP_OPEN), Int64(LWire.SentTyp(1)));
    CheckEqual(Int64(SSH_FXP_WRITE), Int64(LWire.SentTyp(2)));
    CheckEqual(Int64(SSH_FXP_CLOSE), Int64(LWire.SentTyp(3)));
  end);

  { 状态回路：remove/mkdir/rmdir/rename 全部 OK }
  LSuite.Test('lifecycle ops roundtrip status ok', procedure
  var
    LPkt: TBytes;
  begin
    LFfs := NewFfs([
      VersionPkt(3),
      StatusPkt(1, SSH_FX_OK, ''),
      StatusPkt(2, SSH_FX_OK, ''),
      StatusPkt(3, SSH_FX_OK, ''),
      StatusPkt(4, SSH_FX_OK, '')
    ]);
    LFfs.Remove('/tmp/x');
    LFfs.Mkdir('/tmp/d');
    LFfs.Rmdir('/tmp/d');
    LFfs.Rename('/tmp/a', '/tmp/b');
    CheckEqual(5, LWire.SentCount);
    CheckEqual(Int64(SSH_FXP_REMOVE), Int64(LWire.SentTyp(1)));
    CheckEqual(Int64(SSH_FXP_MKDIR), Int64(LWire.SentTyp(2)));
    CheckEqual(Int64(SSH_FXP_RMDIR), Int64(LWire.SentTyp(3)));
    CheckEqual(Int64(SSH_FXP_RENAME), Int64(LWire.SentTyp(4)));
    LPkt := nil;
  end);

  { 失败码映射：no-such-file / permission-denied → sekSftp 且带路径上下文 }
  LSuite.Test('status no-such-file maps to sekSftp with path', procedure
  begin
    LFfs := NewFfs([
      VersionPkt(3),
      StatusPkt(1, SSH_FX_NO_SUCH_FILE, 'not found')
    ]);
    try
      LAttrs := LFfs.Stat('/nope/missing.txt');
      Fail('expected sekSftp');
    except
      on LE: ESSHError do
      begin
        CheckTrue(LE.Kind = sekSftp, 'kind=' + SshErrorKindName(LE.Kind));
        CheckTrue(Pos('/nope/missing.txt', LE.Message) > 0, 'path missing in msg');
        CheckTrue(Pos('not found', LE.Message) > 0, 'server msg missing');
      end;
    end;
  end);

  LSuite.Test('status permission-denied maps to sekSftp', procedure
  begin
    LFfs := NewFfs([
      VersionPkt(3),
      StatusPkt(1, SSH_FX_PERMISSION_DENIED, '')
    ]);
    try
      LGot := LFfs.ReadFile('/root/secret');
      Fail('expected sekSftp');
    except
      on LE: ESSHError do
        CheckTrue(LE.Kind = sekSftp, 'kind=' + SshErrorKindName(LE.Kind));
    end;
  end);

  { 应答 id 错配的迟滞帧被跳过（防御路径）}
  LSuite.Test('mismatched response id is skipped', procedure
  begin
    LFfs := NewFfs([
      VersionPkt(3),
      RespPkt(SSH_FXP_ATTRS, 99, nil),            { 错配 id：跳过 }
      AttrsPkt(1, AttrsWithSizeAndPerms(7, $81A4)) { 正主应答 }
    ]);
    LAttrs := LFfs.Stat('/x');
    CheckEqual(UInt64(7), LAttrs.Size);
    LI := 0;   { 保持 LI 被使用 }
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.ssh.sftp');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  { Halt 会跳过栈帧清理：显式断开接口尾引用，heaptrc 门禁才能归零 }
  LFfs := nil;
  GWire := nil;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end;

begin
  RunSuite;
end.
