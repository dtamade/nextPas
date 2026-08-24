unit nextpas.core.db.redis.transport;

{** @desc Redis 传输抽象（V3-A5）。
       IRedisTransport = 最小同步字节面（Send/Recv/Close），默认
       实现走 core.net 阻塞 TCP（NetTcpConnect + ITcpStream）。
       抽象成接口的目的有二：
       1. 协议层/适配层不感知 socket，离线门禁可注入脚本化 fake
          （回放 canned RESP 字节流，无需真实服务端）；
       2. 未来 TLS/Unix-socket 变体只增实现不改消费方。

       分层：db(L2) → net(L2) 同层单向依赖，符合 design-conventions
       「同层内允许单向依赖」。 *}

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.db.base,
  nextpas.core.db.redis.base,
  nextpas.core.net,
  nextpas.core.net.tcp,
  nextpas.core.time;

type
  IRedisTransport = interface
    ['{7E4A1C60-8D2E-4B3A-9F51-0A2C3D4E5F60}']
    { 整段写出；部分写由实现内部循环补齐 }
    procedure Send(const ABuf: TBytes);
    { 读至多 AMax 字节进 ABuf（追加语义由调用方管理缓冲）；
      返回实际读取数，0 = 对端关闭。阻塞受连接期 deadline 约束。 }
    function Recv(ABuf: Pointer; AMax: Integer): Integer;
    procedure Close;
  end;

type
  { 默认 TCP 实现 }
  TNetRedisTransport = class(TInterfacedObject, IRedisTransport)
  private
    FStream: ITcpStream;
  public
    constructor Create(const AOptions: TDbRedisConnectOptions);
    destructor Destroy; override;
    procedure Send(const ABuf: TBytes);
    function Recv(ABuf: Pointer; AMax: Integer): Integer;
    procedure Close;
  end;

implementation

{ TNetRedisTransport }

constructor TNetRedisTransport.Create(
  const AOptions: TDbRedisConnectOptions);
var
  LTimeout: Int64;
begin
  inherited Create;
  LTimeout := AOptions.ConnectTimeoutMs;
  if LTimeout <= 0 then
    FStream := NetTcpConnect(AOptions.Host, AOptions.Port)
  else
    FStream := NetTcpConnect(AOptions.Host, AOptions.Port, LTimeout);
  if AOptions.IoTimeoutMs > 0 then
  begin
    FStream.SetReadDeadline(
      TDeadline.After(TDuration.FromMilliseconds(AOptions.IoTimeoutMs)));
    FStream.SetWriteDeadline(
      TDeadline.After(TDuration.FromMilliseconds(AOptions.IoTimeoutMs)));
  end;
end;

destructor TNetRedisTransport.Destroy;
begin
  Close;
  inherited Destroy;
end;

procedure TNetRedisTransport.Send(const ABuf: TBytes);
begin
  if (ABuf <> nil) and (Length(ABuf) > 0) then
    FStream.Write(ABuf[0], Length(ABuf));
end;

function TNetRedisTransport.Recv(ABuf: Pointer; AMax: Integer): Integer;
begin
  Result := FStream.Read(ABuf^, AMax);
end;

procedure TNetRedisTransport.Close;
begin
  if FStream <> nil then
  begin
    FStream.Close;
    FStream := nil;
  end;
end;

end.
