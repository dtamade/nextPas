unit nextpas.core.db.redis;

{** @desc Redis 后端门面（V3-A5）。纯 re-export——连接入口
       ConnectRedis + 基本类型；统一层接口经 nextpas.core.db 获取。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.db.redis.base,
  nextpas.core.db.redis.resp,
  nextpas.core.db.redis.adapter;

type
  TDbRedisConnectOptions = nextpas.core.db.redis.base.TDbRedisConnectOptions;
  TRespValue = nextpas.core.db.redis.base.TRespValue;
  TRespValueKind = nextpas.core.db.redis.base.TRespValueKind;
  TRespArgs = nextpas.core.db.redis.resp.TRespArgs;

function ConnectRedis(const AAddr: string): IDbConnection; inline; overload;
function ConnectRedis(const AAddr: string;
  const APassword: string; const ADbIndex: Integer;
  const AOptions: TDbConnectOptions): IDbConnection; inline; overload;
function ConnectRedis(const AAddr: string;
  const AOptions: TDbRedisConnectOptions): IDbConnection; inline; overload;

implementation

function ConnectRedis(const AAddr: string): IDbConnection;
begin
  Result := nextpas.core.db.redis.adapter.ConnectRedis(AAddr);
end;

function ConnectRedis(const AAddr: string;
  const APassword: string; const ADbIndex: Integer;
  const AOptions: TDbConnectOptions): IDbConnection;
begin
  Result := nextpas.core.db.redis.adapter.ConnectRedis(AAddr, APassword,
    ADbIndex, AOptions);
end;

function ConnectRedis(const AAddr: string;
  const AOptions: TDbRedisConnectOptions): IDbConnection;
begin
  Result := nextpas.core.db.redis.adapter.ConnectRedis(AAddr, AOptions);
end;

end.
