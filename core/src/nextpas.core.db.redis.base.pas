unit nextpas.core.db.redis.base;

{** @desc Redis 后端基本类型（V3-A5）。
       连接选项、RESP 回复值种类、协议常量。纯类型单元——无 IO、
       无统一层依赖（对齐 db.pg.base/db.mysql.base 定位）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

const
  { 协议/缺省常量 }
  DB_REDIS_DEFAULT_PORT     = 6379;
  { RESP2 协议字节 }
  DB_REDIS_RESP_SIMPLE      = $2B;  { '+' simple string }
  DB_REDIS_RESP_ERROR       = $2D;  { '-' error }
  DB_REDIS_RESP_INTEGER     = $3A;  { ':' integer }
  DB_REDIS_RESP_BULK        = $24;  { '$' bulk string }
  DB_REDIS_RESP_ARRAY       = $2A;  { '*' array }
  { RESP3 空值（v1 仅识别，不承诺全量 RESP3）}
  DB_REDIS_RESP_NULL        = $5F;  { '_' }

type
  { RESP 回复值种类（解析产物；数组元素复用同枚举）}
  TRespValueKind = (
    rvkSimple,      { +OK }
    rvkError,       {-ERR ...（首词 = 错误类型）}
    rvkInteger,     { :123 }
    rvkBulk,        { $n\r\n<data>\r\n；nil bulk 归 rvkNull }
    rvkArray,       { *n 元素递归；nil array 归 rvkNull }
    rvkNull         { $-1 / *-1 / RESP3 _ }
  );

  { 单个 RESP 值（解析树节点）。数组元素存 Items。 }
  TRespValue = record
    Kind: TRespValueKind;
    Int: Int64;             { rvkInteger }
    Data: TBytes;           { rvkSimple/rvkError/rvkBulk 载荷（不含 CRLF）}
    Items: array of TRespValue;  { rvkArray }
  end;

  { Redis 连接选项（ConnectRedis 消费；TDbConnectOptions 的
    StatementTimeoutMs 映射为 socket 读写 deadline 上限，0=系统缺省）}
  TDbRedisConnectOptions = record
    Host: string;
    Port: Word;
    Password: string;       { 空 = 不发 AUTH }
    DbIndex: Integer;       { 0..15；0 = 不发 SELECT }
    ConnectTimeoutMs: Integer;   { 0 = NetTcpConnect 缺省 }
    IoTimeoutMs: Integer;        { >0 设读写 deadline（advisory）}
    UseTls: Boolean;             { true = TLSDial（DNS+TCP+TLS 一体）}
    TlsServerName: string;       { 空 = 取 Host（SNI/证书名校验名）}
    ProbeInfo: Boolean;          { 建连后 INFO server 探测版本（best-effort）}
    class function Default: TDbRedisConnectOptions; static;
  end;

implementation

class function TDbRedisConnectOptions.Default: TDbRedisConnectOptions;
begin
  Result.Host := '127.0.0.1';
  Result.Port := DB_REDIS_DEFAULT_PORT;
  Result.Password := '';
  Result.DbIndex := 0;
  Result.ConnectTimeoutMs := 0;
  Result.IoTimeoutMs := 0;
  Result.UseTls := False;
  Result.TlsServerName := '';
  Result.ProbeInfo := False;
end;

end.
