unit nextpas.core.webview.registry;

{** @desc webview 后端探测注册表（独立探测职责单源）。

       S* 匠心修复：factory 原承载"后端探测 + 创建分发"双职责，
       WEBVIEW_BACKENDS 表内 Probe/Create 耦合；本单元抽离探测侧
       为独立注册模块候选单源（Probe 单表），与 factory 创建分发
       分离，守四件套与 L0-L3、复用 loader 双检锁已缓存 + bytes.ops
       单源思想。

       工厂只管创建分发（Create/CreateOn 单表）；探测有无/默认 kind
       统一走本单元薄转发，热点路径快照复用零重复 TryLoad* 双检锁。

       依赖：仅 L3 loaders (gtk/webview2/wk) + base；不触 window/
       bridge/factory 循环。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.webview.base;

{ 后端可用性（编译内建 + 运行时可装载合并事实，热点快照复用）。
  perf: inline + 零拷贝 view 思想 + 快照缓存数组 O(1) 命中零额外双检锁，
        未命中单次 Probe 落 loader 双检锁幂等缓存（atomic+mutex），零堆分配。 }
function WebviewProbeAvailable(AKind: TWebviewKind): Boolean; inline;

{ 能力驱动默认 kind（探测优先，热点快照复用）。
  perf: inline + 快照复用 GDefaultSnapshot，零重复 RawProbe/双检锁，零拷贝。 }
function WebviewDefaultKind: TWebviewKind; inline;

{ 原始探测（无快照，供测试/诊断对比）；inline 薄转发单表。 }
function WebviewRawProbe(AKind: TWebviewKind): Boolean; inline;

implementation

uses
  nextpas.core.webview.gtk.loader,
  nextpas.core.webview.webview2.loader,
  nextpas.core.webview.wk.loader;

type
  TWebviewProbe = function: Boolean;

{ ---- 探测函数：单源薄转发 loader 双检锁已缓存探针（零堆分配） ---- }

function ProbeFake: Boolean; inline;
begin
  Result := True;
end;

function ProbeGtk: Boolean; inline;
var L: TGtkLoadInfo;
begin
  // perf: inline zero-copy thin-forward to loader TryLoadGtkWebkit (atomic acquire快路径 + mutex双检锁幂等缓存，零堆分配)
  Result := TryLoadGtkWebkit(L);
end;

function ProbeWebView2: Boolean; inline;
var L: TWebView2LoadInfo;
begin
  Result := TryLoadWebView2(L);
end;

function ProbeWk: Boolean; inline;
var L: TWkLoadInfo;
begin
  Result := TryLoadWk(L);
end;

type
  TWebviewProbeDesc = record
    Kind: TWebviewKind;
    Probe: TWebviewProbe;
  end;

const
  WEBVIEW_PROBES: array[0..3] of TWebviewProbeDesc = (
    (Kind: wvFake; Probe: @ProbeFake),
    (Kind: wvGtk; Probe: @ProbeGtk),
    (Kind: wvWebview2; Probe: @ProbeWebView2),
    (Kind: wvWk; Probe: @ProbeWk)
  );

{ ---- 快照缓存：热点路径零重复双检锁（进程级稳定，loader 已幂等） ---- }

var
  GProbeSnapshot: array[TWebviewKind] of ShortInt = (-1, -1, -1, -1);
  GDefaultSnapshot: ShortInt = -1; { -1 unknown, else Ord(TWebviewKind) }

function FindProbe(AKind: TWebviewKind): TWebviewProbe; inline;
var I: Integer;
begin
  for I := Low(WEBVIEW_PROBES) to High(WEBVIEW_PROBES) do
    if WEBVIEW_PROBES[I].Kind = AKind then
      Exit(WEBVIEW_PROBES[I].Probe);
  Result := nil;
end;

function WebviewRawProbe(AKind: TWebviewKind): Boolean; inline;
var P: TWebviewProbe;
begin
  if AKind = wvFake then Exit(True);
  P := FindProbe(AKind);
  if not Assigned(P) then Exit(False);
  Result := P();
end;

function WebviewProbeAvailable(AKind: TWebviewKind): Boolean; inline;
var LSnap: ShortInt;
begin
  if (AKind < Low(TWebviewKind)) or (AKind > High(TWebviewKind)) then Exit(False);
  if AKind = wvFake then Exit(True);
  // perf: inline 快照 O(1) 复用，命中零 Probe/零双检锁/零堆分配；未命中单次 RawProbe 落 loader 缓存
  LSnap := GProbeSnapshot[AKind];
  if LSnap <> -1 then Exit(LSnap = 1);
  Result := WebviewRawProbe(AKind);
  GProbeSnapshot[AKind] := ShortInt(Ord(Result));
end;

function WebviewDefaultKind: TWebviewKind; inline;
var
  I: Integer;
  LKind: TWebviewKind;
begin
  // perf: inline 快照复用，命中零循环零 Probe/零双检锁，零拷贝
  if GDefaultSnapshot <> -1 then Exit(TWebviewKind(GDefaultSnapshot));
  for I := Low(WEBVIEW_PROBES) to High(WEBVIEW_PROBES) do
  begin
    LKind := WEBVIEW_PROBES[I].Kind;
    if LKind = wvFake then Continue;
    if WebviewProbeAvailable(LKind) then
    begin
      GDefaultSnapshot := ShortInt(Ord(LKind));
      Exit(LKind);
    end;
  end;
  GDefaultSnapshot := ShortInt(Ord(wvFake));
  Result := wvFake;
end;

end.
