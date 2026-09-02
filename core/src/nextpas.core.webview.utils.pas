unit nextpas.core.webview.utils;

{** @desc webview L3 共享工具（非 base 纯类型）：容量/路径/哈希等实现职责下沉，
       base 仅保留纯数据类型与校验；本单元复用 L1 单源 inline 零拷贝，
       消除 base 工具函数混淆。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

{ 资产路径归一：剥离前导 '/'，空串保持空（bridge TryResolve 与 gtk scheme 回调同源，零重复 Delete 扫描）。
  perf: inline + TStringView zero-copy view (L1 text.view single source) + single Move;
  fast path zero alloc when no leading '/', single SetString+Move when trimmed; zero Delete scan }
function NormalizeWebviewAssetPath(const APath: string): string; inline;

implementation

uses
  nextpas.core.text.view;

function NormalizeWebviewAssetPath(const APath: string): string; inline;
var
  V: TStringView;
  LPos: SizeUInt;
begin
  { perf: inline + TStringView zero-copy view (L1 text.view single source) + single Move;
    fast path zero alloc when no leading '/', single SetString+Move when trimmed; zero Delete scan }
  V := TStringView.FromStr(APath);
  LPos := 0;
  while (LPos < V.Len) and (V.Data[LPos] = '/') do
    Inc(LPos);
  if LPos = 0 then
    Exit(APath);
  if LPos >= V.Len then
    Exit('');
  Result := V.Slice(LPos, V.Len - LPos).ToString;
end;

end.
