unit nextpas.core.webview.mime deprecated 'use nextpas.core.mime.types - single source, will be removed next major';

{** @desc webview 家族：MIME 猜测兼容转发（deprecated 薄门面冗余）— 单一事实源已归一至 L2 nextpas.core.mime.types
       （65 项零分配 O(1) 哈希 128 槽，1-2 探测，LookupBySlice 直哈 PChar 段，无 Copy）。
       本单元仅为兼容保留的 inline 薄转发，新代码直接 uses nextpas.core.mime.types 的
       MimeTypeFromPath / MimeTypeFromPathView 单源 inline 零拷贝（复用 L0 base.utils
       HashFNV1aLower/CompareBytesIgnoreCase via bytes.ops 单源，热点零分配，View 零
       ToString 物化），与 L3 http.mime 同源，消除 L3 同层依赖；家族内 vfs/gtk/bridge
       已改直连 L2 单源，本单元不新增逻辑，释放不丢（无句柄/无分配）。
       性能：inline 零额外调用、零拷贝 View 直通、O(1) 哈希 1-2 探测无 Copy；稳定性：无资源、释放不丢。下一步主版本移除本单元（compat debt 下线，不再参与家族 glob/门面重导出）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view;

function GuessWebviewMime(const APath: string): string; inline; deprecated 'Use MimeTypeFromPath from nextpas.core.mime.types';
function GuessWebviewMimeView(const AView: TStringView): string; inline; deprecated 'Use MimeTypeFromPathView from nextpas.core.mime.types';

implementation

uses
  nextpas.core.mime.types;

function GuessWebviewMime(const APath: string): string; inline;
begin
  { perf: inline 直通 L2 mime.types MimeTypeFromPath O(1) 哈希 128槽 1-2探测零分配，PChar切片直哈无Copy；复用 L0 base.utils HashFNV1aLower/CompareBytesIgnoreCase via bytes.ops 单源；稳定性：无句柄无分配释放不丢 }
  Result := MimeTypeFromPath(APath);
end;

function GuessWebviewMimeView(const AView: TStringView): string; inline;
begin
  { perf: inline 零拷贝视图直通 L2 mime.types O(1) 哈希 128槽 1-2探测，无 ToString 堆分配，热点零分配；复用 L0 base.utils HashFNV1aLower/CompareBytesIgnoreCase via bytes.ops 单源，零重复；稳定性：无句柄无分配释放不丢 }
  Result := MimeTypeFromPathView(AView);
end;

end.
