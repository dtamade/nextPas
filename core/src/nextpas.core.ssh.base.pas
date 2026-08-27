unit nextpas.core.ssh.base;

{** nextpas.core.ssh - 基础类型：协议常量、消息号、连接选项。
 *
 * 纯数据单元，不依赖本模块其他文件（模块依赖链最底层）。
 * 消息号来源：RFC 4250/4253/4254 及 OpenSSH 扩展。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

const
  { 协议版本串（RFC 4253 §4.2，版本交换时发送）}
  SSH_PROTOCOL_VERSION = 'SSH-2.0-nextpas.core.ssh_0.1';

  { 版本交换行上限（RFC 4253 §4.2：最大 255 字符含 CRLF）}
  SSH_IDENT_MAX_LINE = 255;

  { 默认参数 }
  SSH_DEFAULT_PORT = 22;
  SSH_DEFAULT_WINDOW_SIZE = $200000;   { 通道初始窗口 2 MiB }
  SSH_DEFAULT_MAX_PACKET = 32768;      { 单包载荷上限 }
  SSH_MAX_RECEIVE_PACKET = $40000;     { 接收包体硬上限 256 KiB（防对端滥用）}
  SSH_MIN_PADDING = 4;                 { RFC 4253 §6：padding 至少 4 字节 }
  SSH_MIN_PAD_BLOCK = 8;               { 未加密时总长对齐块下限 }

  { RFC 4250 消息号（通用）}
  SSH_MSG_DISCONNECT = 1;
  SSH_MSG_IGNORE = 2;
  SSH_MSG_UNIMPLEMENTED = 3;
  SSH_MSG_DEBUG = 4;
  SSH_MSG_SERVICE_REQUEST = 5;
  SSH_MSG_SERVICE_ACCEPT = 6;
  SSH_MSG_EXT_INFO = 7;

  { 密钥交换（RFC 4253 §7）}
  SSH_MSG_KEXINIT = 20;
  SSH_MSG_NEWKEYS = 21;
  { curve25519-sha256 复用 ECDH 消息号（draft-ietf-curdle-ssh-curves §4）}
  SSH_MSG_KEX_ECDH_INIT = 30;
  SSH_MSG_KEX_ECDH_REPLY = 31;

  { 用户认证（RFC 4252）}
  SSH_MSG_USERAUTH_REQUEST = 50;
  SSH_MSG_USERAUTH_FAILURE = 51;
  SSH_MSG_USERAUTH_SUCCESS = 52;
  SSH_MSG_USERAUTH_BANNER = 53;
  { PK_OK 与 PASSWD_CHANGEREQ 共用 60 }
  SSH_MSG_USERAUTH_PK_OK = 60;

  { 连接协议（RFC 4254）}
  SSH_EXTENDED_DATA_STDERR = 1;        { extended_data_type_code：stderr }
  SSH_MSG_GLOBAL_REQUEST = 80;
  SSH_MSG_REQUEST_SUCCESS = 81;
  SSH_MSG_REQUEST_FAILURE = 82;
  SSH_MSG_CHANNEL_OPEN = 90;
  SSH_MSG_CHANNEL_OPEN_CONFIRMATION = 91;
  SSH_MSG_CHANNEL_OPEN_FAILURE = 92;
  SSH_MSG_CHANNEL_WINDOW_ADJUST = 93;
  SSH_MSG_CHANNEL_DATA = 94;
  SSH_MSG_CHANNEL_EXTENDED_DATA = 95;
  SSH_MSG_CHANNEL_EOF = 96;
  SSH_MSG_CHANNEL_CLOSE = 97;
  SSH_MSG_CHANNEL_REQUEST = 98;
  SSH_MSG_CHANNEL_SUCCESS = 99;
  SSH_MSG_CHANNEL_FAILURE = 100;

  { 服务名（RFC 4254）}
  SSH_SERVICE_USERAUTH = 'ssh-userauth';
  SSH_SERVICE_CONNECTION = 'ssh-connection';

  { 通道类型 }
  SSH_CHANNEL_SESSION = 'session';

  { exec 时我方声明给对端的通道请求名 }
  SSH_REQ_EXEC = 'exec';
  SSH_REQ_SUBSYSTEM = 'subsystem';
  SSH_REQ_EXIT_STATUS = 'exit-status';

type
  { 模块级动态数组别名（本工具链快照在类型位置不支持 system.TArray 泛型）}
  TStringArray = array of string;
  TBlobArray = array of TBytes;

  { 认证方式 }
  TSshAuthMethod = (
    amPassword,
    amPublicKey
  );

  { 主机密钥算法类别 }
  TSshHostKeyAlg = (
    hkEd25519,
    hkRsa,
    hkEcdsaP256      { 预留：ecdsa-sha2-nistp256，当前不参与协商 }
  );

  { 连接选项。由门面 builder 填充，session 消费。}
  TSshConnectOptions = record
    Host: string;
    Port: Word;
    User: string;
    Password: string;
    PrivateKeyData: string;          { openssh-key-v1 容器内容（未加密或 aes256-ctr+bcrypt 加密）}
    PrivateKeyPassphrase: string;    { 加密私钥口令；未加密时忽略 }
    AgentSocketPath: string;         { ssh-agent Unix socket 路径；为空则不走 agent }
    KnownHostsFile: string;          { 为空则跳过 known_hosts 校验 }
    StrictHostKeyChecking: Boolean;  { True：未知主机密钥直接拒绝 }
    ConnectTimeoutMs: Integer;       { 预留：当前阻塞 IO 未接入超时 }
    ExecTimeoutMs: Integer;          { Exec 输出收集超时，<=0 表示无限等待 }
    InitialWindowSize: UInt32;
    MaxPacket: UInt32;
  end;

{** 构造默认连接选项（端口 22、窗口 2 MiB、MaxPacket 32 KiB）。 *}
function DefaultSshConnectOptions(const AHost: string): TSshConnectOptions;

implementation

function DefaultSshConnectOptions(const AHost: string): TSshConnectOptions;
begin
  Result := Default(TSshConnectOptions);
  Result.Host := AHost;
  Result.Port := SSH_DEFAULT_PORT;
  Result.StrictHostKeyChecking := False;
  Result.ConnectTimeoutMs := 10000;
  Result.ExecTimeoutMs := 120000;
  Result.InitialWindowSize := SSH_DEFAULT_WINDOW_SIZE;
  Result.MaxPacket := SSH_DEFAULT_MAX_PACKET;
end;

end.
