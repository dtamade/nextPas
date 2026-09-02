unit nextpas.core.js.host;
{ Host facade — independent L2 host owner (复用下沉): thin re-export pure.host single source, per-Context buckets instance-isolated, inline zero-copy via text.view, bytes.ops FNV1a single source. Threshold >800时 pure.base Host职责可彻底迁至本单元，当前pure.host为单源owner，本单元为js.host独立门面 alias, 守 L0-L3, 四件套 base←intf←impl←门面. }
{$I nextpas.core.settings.inc}
interface
uses
  nextpas.core.js.base,
  nextpas.core.js.intf,
  nextpas.core.text.view,
  nextpas.core.js.pure.host;
type
  TJsHostRec = TJsPureHostRec;
  TJsHostArray = TJsPureHostArray;
  TJsHostBuckets = TJsPureHostBuckets;
  TJsHostState = TJsPureHostState;
const
  JS_HOST_THRESHOLD = JS_PURE_HOST_THRESHOLD;
function JsHostValidateName(const AName: string): Boolean; inline;
function JsHostFind(const Hosts: TJsHostArray; const AName: string): Integer; inline; overload;
function JsHostFind(const Hosts: TJsHostArray; var Buckets: TJsHostBuckets; const AName: string): Integer; inline; overload;
function JsHostFindView(const Hosts: TJsHostArray; const AName: TStringView): Integer; inline; overload;
function JsHostFindView(const Hosts: TJsHostArray; var Buckets: TJsHostBuckets; const AName: TStringView): Integer; inline; overload;
procedure JsHostSetFunc(var Hosts: TJsHostArray; const AName: string; AHandler: TJsHostFunction; ABackend: TJsBackendKind); inline; overload;
procedure JsHostSetFunc(var Hosts: TJsHostArray; var Buckets: TJsHostBuckets; const AName: string; AHandler: TJsHostFunction; ABackend: TJsBackendKind); inline; overload;
procedure JsHostRemove(var Hosts: TJsHostArray; const AName: string); inline; overload;
procedure JsHostRemove(var Hosts: TJsHostArray; var Buckets: TJsHostBuckets; const AName: string); inline; overload;
procedure JsHostBucketsInvalidate(var Buckets: TJsHostBuckets); inline;
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
