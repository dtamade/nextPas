unit nextpas.core.webview.utils;

{** @desc webview L3 共享工具（非 base 纯类型）：容量/路径/哈希等实现职责下沉，
       base 仅保留纯数据类型与校验；本单元复用 L1 单源零拷贝（text.view SliceToStr，
       单次 SetString+Move），非 inline 避免热路径代码膨胀，消除 base 工具函数混淆。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.text.view;

{ 资产路径归一：剥离前导 '/'，空串保持空（bridge TryResolve 与 gtk scheme 回调同源，零重复 Delete 扫描）。
  perf: out-of-line + TStringView zero-copy view (L1 text.view single source) + SliceToStr single SetString+Move;
  fast path zero alloc (CoW share) when no leading '/', single alloc+Move when trimmed; zero Delete scan; non-inline avoids bloat at 2 hot call sites (bridge/vfs/gtk) }
function NormalizeWebviewAssetPath(const APath: string): string;
{ 零拷贝视图版：TStringView 输入→输出，无堆分配，供 scheme/bridge 热点复用 TStringView 零拷贝直通（L1 text.view 单源，inline 零额外调用，PAnsiChar→view 无 AnsiPtrToStr 中间串） }
function NormalizeWebviewAssetView(const AView: TStringView): TStringView; inline;
function ViewFromPChar(const AP: PAnsiChar): TStringView; inline;

implementation

function NormalizeWebviewAssetPath(const APath: string): string;
var
  V: TStringView;
  LPos: SizeUInt;
begin
  { perf: out-of-line single instance + TStringView zero-copy view (L1 text.view single source) + SliceToStr single SetString+Move;
    fast path Exit(APath) zero alloc (CoW), trimmed via SliceToStr single alloc+Move; non-inline eliminates while+ToString bloat at call sites;
    discipline mirrors bytes.ops single-source (VecGrow/Slice) — zero duplicate Delete scan }
  V := TStringView.FromStr(APath);
  LPos := 0;
  while (LPos < V.Len) and (V.Data[LPos] = '/') do
    Inc(LPos);
  if LPos = 0 then
    Exit(APath);
  if LPos >= V.Len then
    Exit('');
  Result := SliceToStr(APath, LPos, V.Len - LPos);
end;

function NormalizeWebviewAssetView(const AView: TStringView): TStringView; inline;
var
  LPos: SizeUInt;
begin
  // perf: inline zero-copy view trim via TStringView.Slice (L1 text.view single source), 无堆分配，热点 scheme/bridge 直通 ViewFromPChar 零 AnsiPtrToStr 中间串
  LPos := 0;
  while (LPos < AView.Len) and (AView.Data[LPos] = '/') do
    Inc(LPos);
  if LPos = 0 then Exit(AView);
  if LPos >= AView.Len then
    Exit(TStringView.Empty);
  Result := AView.Slice(LPos, AView.Len - LPos);
end;

function ViewFromPChar(const AP: PAnsiChar): TStringView; inline;
var
  LLen: SizeUInt;
begin
  // perf: inline PAnsiChar→TStringView 零拷贝视图，无 SetString+Move 中间串，供 scheme 热点 AnsiPtrToStr 零分配替代
  if AP = nil then
    Exit(TStringView.Empty);
  LLen := 0;
  while AP[LLen] <> #0 do Inc(LLen);
  Result := TStringView.Create(AP, LLen);
end;

end.
