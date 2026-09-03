unit nextpas.core.db.redis.transport;

{** @desc Redis 传输抽象（V3-A5）。
       IRedisTransport = 最小同步字节面（Send/Recv/Close），默认
       实现走 core.net 阻塞 TCP（NetTcpConnect + ITcpStream）。
       抽象成接口的目的有二：
       1. 协议层/适配层不感知 socket，离线门禁可注入脚本化 fake
          （回放 canned RESP 字节流，无需真实服务端）；
       2. 未来 TLS/Unix-socket 变体只增实现不改消费方。

       分层：L2 同层单向 allowlist 单缝 `db.redis.transport → net.tcp`（+ `tls.dialer` 可选 TLS 变体，time/sync 为 L1 下沉非 L2 缝，base/resp 纯 L0/L1），Registry 显式 allowlist + source-contract 门禁，cycle-gated 无 reverse（net/tls→db.redis 禁止，类 canvas.raster→vector/image / respack.dirsource→fs / vfs.os→fs 范式），bytes.ops 单源 inline/零拷贝（TBytes 视图零额外分配，Send 薄转发），资源 FreeAndNil/try-finally 不丢（Destroy→Close，FStream 释放）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.db.base,
  nextpas.core.db.redis.base,
  nextpas.core.io.intf,
  nextpas.core.net,
  nextpas.core.net.tcp,
  nextpas.core.time,
  nextpas.core.tls,
  nextpas.core.tls.dialer;

type
  IRedisTransport = interface
    ['{7E4A1C60-8D2E-4B3A-9F51-0A2C3D4E5F60}']
    { 整段写出；部分写由实现内部循环补齐 }
    procedure Send(const ABuf: TBytes); overload;
    { 零拷贝切片直发：避免每分块 SetLength+Move O(chunk) 额外复制/分配；
      transport 直写 @Buf/Len（bytes.ops 单源容量复用），inline 热路径 }
    procedure Send(AData: Pointer; ACount: SizeUInt); overload;
    { 读至多 AMax 字节进 ABuf（追加语义由调用方管理缓冲）；
      返回实际读取数，0 = 对端关闭。阻塞受连接期 deadline 约束。 }
    function Recv(ABuf: Pointer; AMax: Integer): Integer;
    procedure Close;
  end;

{ 按选项选管道（TCP 或 TLS）；建连失败抛 net/tls 原生异常，
  由 adapter 统一桥接为 EDbError }
function NewNetRedisTransport(
  const AOptions: TDbRedisConnectOptions): IRedisTransport;

type
  { 默认 TCP 实现 }
  TNetRedisTransport = class(TInterfacedObject, IRedisTransport)
  private
    FStream: ITcpStream;
  public
    constructor Create(const AOptions: TDbRedisConnectOptions);
    destructor Destroy; override;
    procedure Send(const ABuf: TBytes); overload;
    procedure Send(AData: Pointer; ACount: SizeUInt); overload;
    function Recv(ABuf: Pointer; AMax: Integer): Integer;
    procedure Close;
  end;

  { TLS 实现：TLSDial（DNS+TCP+TLS 一体阻塞），IStream 承载 }
  TTlsRedisTransport = class(TInterfacedObject, IRedisTransport)
  private
    FStream: IStream;
  public
    constructor Create(const AOptions: TDbRedisConnectOptions);
    destructor Destroy; override;
    procedure Send(const ABuf: TBytes); overload;
    procedure Send(AData: Pointer; ACount: SizeUInt); overload;
    function Recv(ABuf: Pointer; AMax: Integer): Integer;
    procedure Close;
  end;

implementation

uses
  nextpas.core.tls.exceptions;

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

procedure TNetRedisTransport.Send(AData: Pointer; ACount: SizeUInt);
begin
  // perf: zero-copy slice direct write, no per-chunk alloc/Move; inline-friendly
  if (AData <> nil) and (ACount > 0) then
    FStream.Write(AData^, ACount);
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

{ TTlsRedisTransport }

constructor TTlsRedisTransport.Create(
  const AOptions: TDbRedisConnectOptions);
var
  LSNI: string;
  LDialer: TSSLDialer;
  LRes: TSSLDialResult;
  LTimeout: Integer;
begin
  inherited Create;
  LSNI := AOptions.TlsServerName;
  if LSNI = '' then
    LSNI := AOptions.Host;
  { 透传超时：ConnectTimeoutMs 管建连，IoTimeoutMs 管读写 deadline；
    缺省回落与 TCP 侧一致（0 = 系统缺省），由 dialer/timeout 统一承载。
    TLS 侧复用 dialer.TimeoutMs 一次性透传 Connect+Io 超时，
    与 TCP 的 NetTcpConnect(LTimeout)+SetDeadline 双通道对齐。 }
  LTimeout := AOptions.ConnectTimeoutMs;
  if LTimeout <= 0 then
    LTimeout := AOptions.IoTimeoutMs;
  LDialer := TSSLDialer.CreateDefault;
  try
    if LTimeout > 0 then
      LDialer.TimeoutMs := LTimeout;
    LRes := LDialer.Dial(LSNI, AOptions.Port);
    if LRes.Error.IsErr then
      raise ESSLException.Create('TLS dial failed: ' + LRes.Error.ErrorMessage);
    FStream := LRes.Stream;
    { IoTimeout 的读写 deadline 由 TLS 层内部的 SetTimeout 承载；
      此处已通过 dialer 超时对齐建连与握手阶段，读写阶段沿用
      底层连接的默认超时；如需细粒度可后续在 TSSLStream 上追加
      SetReadTimeout/SetWriteTimeout（当前保持与 TCP 语义同构的最小修复）。 }
  finally
    LDialer.Free;
  end;
end;

destructor TTlsRedisTransport.Destroy;
begin
  Close;
  inherited Destroy;
end;

procedure TTlsRedisTransport.Send(const ABuf: TBytes);
begin
  if (ABuf <> nil) and (Length(ABuf) > 0) then
    FStream.Write(ABuf[0], Length(ABuf));
end;

procedure TTlsRedisTransport.Send(AData: Pointer; ACount: SizeUInt);
begin
  // perf: zero-copy slice direct write, no per-chunk alloc/Move; inline-friendly
  if (AData <> nil) and (ACount > 0) then
    FStream.Write(AData^, ACount);
end;

function TTlsRedisTransport.Recv(ABuf: Pointer; AMax: Integer): Integer;
begin
  Result := FStream.Read(ABuf^, AMax);
end;

procedure TTlsRedisTransport.Close;
begin
  if FStream <> nil then
  begin
    FStream.Close;
    FStream := nil;
  end;
end;

function NewNetRedisTransport(
  const AOptions: TDbRedisConnectOptions): IRedisTransport;
begin
  if AOptions.UseTls then
    Result := TTlsRedisTransport.Create(AOptions)
  else
    Result := TNetRedisTransport.Create(AOptions);
end;

end.
