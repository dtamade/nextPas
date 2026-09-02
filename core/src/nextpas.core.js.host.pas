unit nextpas.core.js.host deprecated 'use nextpas.core.js.pure.host - canonical Host owner pure.host L2, thin re-export inline zero-copy via text.view+bytes.ops FNV1a';
{ Host facade — deprecated compat alias: canonical single source is nextpas.core.js.pure.host (Owner pure.host, L2). Thin re-export pure.host inline zero-copy via text.view + bytes.ops FNV1a single source, per-Context buckets instance-isolated. New code import via pure.host or pure.base aggregated; do not add new js.host entry. Threshold >800时 Host职责可迁至 js.host 届时 pure.host 转薄转发, 当前 pure.host 单源 owner. 守 L0-L3, 四件套 base←intf←impl←门面, 资源幂等不丢. }
{$I nextpas.core.settings.inc}
interface
uses
  nextpas.core.js.base,
  nextpas.core.js.intf,
  nextpas.core.text.view,
  nextpas.core.js.pure.host;
type
  TJsHostRec = TJsPureHostRec deprecated 'use TJsPureHostRec from nextpas.core.js.pure.host';
  TJsHostArray = TJsPureHostArray deprecated 'use TJsPureHostArray from nextpas.core.js.pure.host';
  TJsHostBuckets = TJsPureHostBuckets deprecated 'use TJsPureHostBuckets from nextpas.core.js.pure.host';
  TJsHostState = TJsPureHostState deprecated 'use TJsPureHostState from nextpas.core.js.pure.host';
const
  JS_HOST_THRESHOLD = JS_PURE_HOST_THRESHOLD deprecated 'use JS_PURE_HOST_THRESHOLD from nextpas.core.js.pure.host';
function JsHostValidateName(const AName: string): Boolean; inline; deprecated 'use JsPureValidateHostName from nextpas.core.js.pure.host';
function JsHostFind(const Hosts: TJsHostArray; const AName: string): Integer; inline; overload; deprecated 'use JsPureFindHost from nextpas.core.js.pure.host';
function JsHostFind(const Hosts: TJsHostArray; var Buckets: TJsHostBuckets; const AName: string): Integer; inline; overload; deprecated 'use JsPureFindHost from nextpas.core.js.pure.host';
function JsHostFindView(const Hosts: TJsHostArray; const AName: TStringView): Integer; inline; overload; deprecated 'use JsPureFindHostView from nextpas.core.js.pure.host';
function JsHostFindView(const Hosts: TJsHostArray; var Buckets: TJsHostBuckets; const AName: TStringView): Integer; inline; overload; deprecated 'use JsPureFindHostView from nextpas.core.js.pure.host';
procedure JsHostSetFunc(var Hosts: TJsHostArray; const AName: string; AHandler: TJsHostFunction; ABackend: TJsBackendKind); inline; overload; deprecated 'use JsPureHostSetFunc from nextpas.core.js.pure.host';
procedure JsHostSetFunc(var Hosts: TJsHostArray; var Buckets: TJsHostBuckets; const AName: string; AHandler: TJsHostFunction; ABackend: TJsBackendKind); inline; overload; deprecated 'use JsPureHostSetFunc from nextpas.core.js.pure.host';
procedure JsHostRemove(var Hosts: TJsHostArray; const AName: string); inline; overload; deprecated 'use JsPureHostRemove from nextpas.core.js.pure.host';
procedure JsHostRemove(var Hosts: TJsHostArray; var Buckets: TJsHostBuckets; const AName: string); inline; overload; deprecated 'use JsPureHostRemove from nextpas.core.js.pure.host';
procedure JsHostBucketsInvalidate(var Buckets: TJsHostBuckets); inline; deprecated 'use JsPureHostBucketsInvalidate from nextpas.core.js.pure.host';
implementation
function JsHostValidateName(const AName: string): Boolean; inline;
begin Result := JsPureValidateHostName(AName); end;
function JsHostFind(const Hosts: TJsHostArray; const AName: string): Integer; inline;
begin Result := JsPureFindHost(Hosts, AName); end;
function JsHostFind(const Hosts: TJsHostArray; var Buckets: TJsHostBuckets; const AName: string): Integer; inline;
begin Result := JsPureFindHost(Hosts, Buckets, AName); end;
function JsHostFindView(const Hosts: TJsHostArray; const AName: TStringView): Integer; inline;
begin Result := JsPureFindHostView(Hosts, AName); end;
function JsHostFindView(const Hosts: TJsHostArray; var Buckets: TJsHostBuckets; const AName: TStringView): Integer; inline;
begin Result := JsPureFindHostView(Hosts, Buckets, AName); end;
procedure JsHostSetFunc(var Hosts: TJsHostArray; const AName: string; AHandler: TJsHostFunction; ABackend: TJsBackendKind); inline;
begin JsPureHostSetFunc(Hosts, AName, AHandler, ABackend); end;
procedure JsHostSetFunc(var Hosts: TJsHostArray; var Buckets: TJsHostBuckets; const AName: string; AHandler: TJsHostFunction; ABackend: TJsBackendKind); inline;
begin JsPureHostSetFunc(Hosts, Buckets, AName, AHandler, ABackend); end;
procedure JsHostRemove(var Hosts: TJsHostArray; const AName: string); inline;
begin JsPureHostRemove(Hosts, AName); end;
procedure JsHostRemove(var Hosts: TJsHostArray; var Buckets: TJsHostBuckets; const AName: string); inline;
begin JsPureHostRemove(Hosts, Buckets, AName); end;
procedure JsHostBucketsInvalidate(var Buckets: TJsHostBuckets); inline;
begin JsPureHostBucketsInvalidate(Buckets); end;
end.
