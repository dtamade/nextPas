unit nextpas.core.net.async.tlsfp;
{$mode objfpc}{$H+}
{$WARN 5025 off}
{ Deprecated alias — tlsfp → tlspas 软改名（FPC/nextpas 双编译器兼容）。
  保留本单元仅为历史 `uses tlsfp` 编译通过，新代码请 `uses tlspas`。 }

interface

uses
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.async.base,
  nextpas.core.async.loop,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.net.async.tcp,
  nextpas.core.net.async.tlspas;

const
  ASYNC_TLSFP_ERR_IO = nextpas.core.net.async.tlspas.ASYNC_TLSFP_ERR_IO;
  ASYNC_TLSFP_ERR_HANDSHAKE = nextpas.core.net.async.tlspas.ASYNC_TLSFP_ERR_HANDSHAKE;
  ASYNC_TLSPAS_ERR_IO = nextpas.core.net.async.tlspas.ASYNC_TLSPAS_ERR_IO;
  ASYNC_TLSPAS_ERR_HANDSHAKE = nextpas.core.net.async.tlspas.ASYNC_TLSPAS_ERR_HANDSHAKE;

type
  TFpTlsResumptionSession = nextpas.core.net.async.tlspas.TFpTlsResumptionSession;
  TTlsPasResumptionSession = nextpas.core.net.async.tlspas.TTlsPasResumptionSession;
  ITlsFpResumeInfo = nextpas.core.net.async.tlspas.ITlsFpResumeInfo;
  ITlsPasResumeInfo = nextpas.core.net.async.tlspas.ITlsPasResumeInfo;
  TAsyncTlsFpSessionCache = nextpas.core.net.async.tlspas.TAsyncTlsFpSessionCache;
  TAsyncTlsPasSessionCache = nextpas.core.net.async.tlspas.TAsyncTlsPasSessionCache;
  TAsyncTlsFpClientOptions = nextpas.core.net.async.tlspas.TAsyncTlsFpClientOptions;
  TAsyncTlsPasClientOptions = nextpas.core.net.async.tlspas.TAsyncTlsPasClientOptions;
  TAsyncTlsFpConnectCallback = nextpas.core.net.async.tlspas.TAsyncTlsFpConnectCallback;
  TAsyncTlsPasConnectCallback = nextpas.core.net.async.tlspas.TAsyncTlsPasConnectCallback;

function DefaultAsyncTlsFpClientOptions: TAsyncTlsFpClientOptions; inline;
function AsyncTlsFpUpgrade(const ALoop: TAsyncLoop; const AStream: IAsyncTcpStream;
  const AOptions: TAsyncTlsFpClientOptions; ACallback: TAsyncTlsFpConnectCallback;
  AContext: Pointer = nil): Boolean; inline;
function AsyncTlsFpConnect(const ALoop: TAsyncLoop; const AHost: string;
  const APort: UInt16; const AOptions: TAsyncTlsFpClientOptions;
  ACallback: TAsyncTlsFpConnectCallback; AContext: Pointer = nil): Boolean; inline;

function DefaultAsyncTlsPasClientOptions: TAsyncTlsFpClientOptions; inline;
function AsyncTlsPasUpgrade(const ALoop: TAsyncLoop; const AStream: IAsyncTcpStream;
  const AOptions: TAsyncTlsFpClientOptions; ACallback: TAsyncTlsFpConnectCallback;
  AContext: Pointer = nil): Boolean; inline;
function AsyncTlsPasConnect(const ALoop: TAsyncLoop; const AHost: string;
  const APort: UInt16; const AOptions: TAsyncTlsFpClientOptions;
  ACallback: TAsyncTlsFpConnectCallback; AContext: Pointer = nil): Boolean; inline;

implementation

function DefaultAsyncTlsFpClientOptions: TAsyncTlsFpClientOptions;
begin
  Result := nextpas.core.net.async.tlspas.DefaultAsyncTlsFpClientOptions;
end;

function AsyncTlsFpUpgrade(const ALoop: TAsyncLoop; const AStream: IAsyncTcpStream;
  const AOptions: TAsyncTlsFpClientOptions; ACallback: TAsyncTlsFpConnectCallback;
  AContext: Pointer): Boolean;
begin
  Result := nextpas.core.net.async.tlspas.AsyncTlsFpUpgrade(ALoop, AStream, AOptions, ACallback, AContext);
end;

function AsyncTlsFpConnect(const ALoop: TAsyncLoop; const AHost: string;
  const APort: UInt16; const AOptions: TAsyncTlsFpClientOptions;
  ACallback: TAsyncTlsFpConnectCallback; AContext: Pointer): Boolean;
begin
  Result := nextpas.core.net.async.tlspas.AsyncTlsFpConnect(ALoop, AHost, APort, AOptions, ACallback, AContext);
end;

function DefaultAsyncTlsPasClientOptions: TAsyncTlsFpClientOptions;
begin
  Result := nextpas.core.net.async.tlspas.DefaultAsyncTlsPasClientOptions;
end;

function AsyncTlsPasUpgrade(const ALoop: TAsyncLoop; const AStream: IAsyncTcpStream;
  const AOptions: TAsyncTlsFpClientOptions; ACallback: TAsyncTlsFpConnectCallback;
  AContext: Pointer): Boolean;
begin
  Result := nextpas.core.net.async.tlspas.AsyncTlsPasUpgrade(ALoop, AStream, AOptions, ACallback, AContext);
end;

function AsyncTlsPasConnect(const ALoop: TAsyncLoop; const AHost: string;
  const APort: UInt16; const AOptions: TAsyncTlsFpClientOptions;
  ACallback: TAsyncTlsFpConnectCallback; AContext: Pointer): Boolean;
begin
  Result := nextpas.core.net.async.tlspas.AsyncTlsPasConnect(ALoop, AHost, APort, AOptions, ACallback, AContext);
end;

end.
