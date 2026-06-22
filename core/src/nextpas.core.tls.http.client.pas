unit nextpas.core.tls.http.client;

{$mode ObjFPC}{$H+}
{$WARN 5093 off} // Suppress false-positive "Function result not initialized" for managed types

{
  简单的 HTTP 客户端
  
  为 OCSP Stapling 提供基础的 HTTP POST 支持。
  注意：fafafa.ssl 不实现网络通信。本单元仅作为兼容/桥接层，
  实际 HTTP 传输必须由上层注入（见 nextpas.core.tls.net.hooks）。
  
  @author fafafa.ssl team
  @version 1.0.0
}

interface

uses
  nextpas.core.base;

type
  // 简单 HTTP 客户端
  TSimpleHTTPClient = class
  private
    FTimeout: Integer; // 超时时间 (毫秒)
    FContentType: string;        // Content-Type 头
    FUserAgent: string;          // User-Agent 头
  public
    constructor Create;
    destructor Destroy; override;

    // HTTP POST 请求
    function Post(const AURL: string; const AData: TBytes): TBytes;

    property Timeout: Integer read FTimeout write FTimeout;
    property ContentType: string read FContentType write FContentType;
    property UserAgent: string read FUserAgent write FUserAgent;
  end;

implementation

uses
  nextpas.core.tls.base,
  nextpas.core.tls.net.hooks,
  nextpas.core.errors;

constructor TSimpleHTTPClient.Create;
begin
  inherited Create;
  FTimeout := 10000;  // 10 秒
  FContentType := 'application/ocsp-request';
  FUserAgent := 'fafafa.ssl/1.0';
end;

destructor TSimpleHTTPClient.Destroy;
begin
  inherited Destroy;
end;

function TSimpleHTTPClient.Post(const AURL: string; const AData: TBytes): TBytes;
var
  LRes: TSSLDataResult;
begin
  SetLength(Result, 0);

  LRes := SSLHTTPPost(AURL, FContentType, AData, FTimeout);
  if LRes.Success then
    Result := LRes.Data
  else
    raise Exception.Create(LRes.ErrorMessage);
end;

end.
