program demo_webview;

{** @desc nextpas.core.webview 消费者演示：真实桌面窗口 + 完整 IPC 矩阵。

    只依赖公共门面（nextpas.core.webview / nextpas.core.json），与真实
    应用写法一致：Builder 流式构造 → Assets.MountEmbedded 提供页面 →
    Invokes 注册同步/异步 handler → Eval/Emit/listen 双向通道。

    两种运行形态：
    - demo_webview               交互模式：打开窗口，人工点按；stdout 记录桥流量
    - demo_webview --selftest    自检模式：同一页面驱动全链路矩阵，
                                 全事件驱动（回调链推进，无 Sleep/轮询），
                                 打印 demo-pass 行，自动关窗，exit 0/1

    覆盖矩阵：
    1) native→web eval 回执（6*7=42）
    2) web→native 同步 invoke（JSON 解析 + JSON 返回）
    3) 有状态原生 handler（counter 连续自增，跨调用保持）
    4) 异步 invoke（Dispatcher.Post 延迟完成，completion.Ok 收口）
    5) web→native→web 全环（invoke 触发 native Emit，页面 listen 接收）

    无 GTK 后端时 --selftest 打印 demo-skip 优雅通过（CI 可跑）。 }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.text.view,
  nextpas.core.webview.utils,
  nextpas.core.json,
  nextpas.core.json.value,
  { 显式选后端时引 base（门面只 re-export 类型别名，不带枚举值） }
  nextpas.core.webview.base,
  nextpas.core.window.base,
  nextpas.core.webview, nextpas.core.exception, nextpas.core.text.format, nextpas.core.time;

const
  { 自检推进阶段（严格线性，防乱序误判） }
  ST_WAIT_NAV   = 1;
  ST_WAIT_EVAL  = 2;
  ST_WAIT_SUM   = 3;
  ST_WAIT_CNT1  = 4;
  ST_WAIT_CNT2  = 5;
  ST_WAIT_TICK  = 6;
  ST_WAIT_PUSH  = 7;
  ST_WAIT_EVENT = 8;

  PAGE_HTML: AnsiString =
    '<!DOCTYPE html>'#10 +
    '<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'#10 +
    '<style>'#10 +
    ':root{--bg:#0b0f1d;--bg2:#0f1730;--panel:rgba(255,255,255,.06);--panel2:rgba(255,255,255,.035);--line:rgba(255,255,255,.10);--line2:rgba(255,255,255,.06);--txt:#e7ecf7;--dim:#8b95ad;--accent:#6d8bff;--accent2:#39c7ef;--ok:#43e5c8;--mono:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;--radius:16px;--shadow:0 10px 30px rgba(0,0,0,.35),0 1px 0 rgba(255,255,255,.06) inset}'#10 +
    '[data-theme="light"]{--bg:#f6f7fb;--bg2:#eef1f8;--panel:rgba(255,255,255,.82);--panel2:rgba(255,255,255,.6);--line:rgba(16,22,40,.10);--line2:rgba(16,22,40,.06);--txt:#0f1a33;--dim:#6b7894;--shadow:0 8px 24px rgba(16,22,40,.08),0 1px 0 rgba(255,255,255,.9) inset}'#10 +
    '*{box-sizing:border-box;margin:0;padding:0}'#10 +
    'html{color-scheme:dark light}'#10 +
    'body{font-family:-apple-system,"Segoe UI",Roboto,"Noto Sans SC",sans-serif;background:radial-gradient(1100px 620px at 12% -10%,#1c2749 0%,transparent 55%),radial-gradient(900px 520px at 100% 0%,#12304a 0%,transparent 50%),var(--bg);color:var(--txt);min-height:100vh;padding:34px 38px 74px;transition:background .35s ease,color .25s ease}'#10 +
    '[data-theme="light"] body{background:radial-gradient(1100px 620px at 12% -10%,#dbe6ff 0%,transparent 55%),radial-gradient(900px 520px at 100% 0%,#d6f0ff 0%,transparent 50%),var(--bg)}'#10 +
    '.wrap{max-width:980px;margin:0 auto}'#10 +
    '.top{display:flex;align-items:center;justify-content:space-between;gap:16px;flex-wrap:wrap}'#10 +
    'h1{font-size:27px;font-weight:800;letter-spacing:.2px;background:linear-gradient(92deg,var(--accent),var(--accent2) 60%,var(--ok));-webkit-background-clip:text;background-clip:text;color:transparent}'#10 +
    '.sub{color:var(--dim);font-size:13px;margin-top:6px}'#10 +
    '.pill{display:inline-flex;align-items:center;gap:8px;font-family:var(--mono);font-size:11px;letter-spacing:.08em;text-transform:uppercase;color:var(--dim);background:var(--panel2);border:1px solid var(--line2);padding:6px 10px;border-radius:999px;backdrop-filter:blur(10px)}'#10 +
    '.pill b{color:var(--txt);font-weight:700}.pill i{width:7px;height:7px;border-radius:50%;background:var(--ok);box-shadow:0 0 10px rgba(67,229,200,.7);display:inline-block}'#10 +
    '.icon-btn{appearance:none;border:1px solid var(--line);background:var(--panel);color:var(--txt);width:40px;height:40px;border-radius:12px;cursor:pointer;display:grid;place-items:center;font-size:16px;backdrop-filter:blur(12px) saturate(1.2);box-shadow:var(--shadow);transition:transform .15s ease,border-color .2s ease}'#10 +
    '.icon-btn:hover{transform:translateY(-1px);border-color:rgba(109,139,255,.35)}'#10 +
    '.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:16px;margin-top:24px}'#10 +
    '.card{position:relative;background:var(--panel);border:1px solid var(--line);border-radius:var(--radius);padding:18px;backdrop-filter:blur(16px) saturate(1.2);box-shadow:var(--shadow);overflow:hidden;transition:transform .18s ease,border-color .2s ease}'#10 +
    '.card::before{content:"";position:absolute;inset:0;border-radius:inherit;background:linear-gradient(180deg,rgba(255,255,255,.07),transparent 55%);pointer-events:none}'#10 +
    '.card:hover{transform:translateY(-1px);border-color:rgba(109,139,255,.22)}'#10 +
    '.card h2{position:relative;font-size:11px;font-weight:700;color:var(--dim);letter-spacing:.14em;text-transform:uppercase;margin-bottom:13px}'#10 +
    '.row{display:flex;align-items:center;gap:10px;flex-wrap:wrap;position:relative}'#10 +
    'button.primary{appearance:none;border:0;border-radius:11px;padding:9px 16px;font-size:13px;font-weight:700;color:#081020;cursor:pointer;background:linear-gradient(94deg,var(--accent),var(--accent2));transition:transform .12s ease,box-shadow .12s ease,filter .2s ease;box-shadow:0 2px 10px rgba(57,199,239,.22)}'#10 +
    'button.primary:hover{transform:translateY(-1px);box-shadow:0 6px 18px rgba(57,199,239,.32);filter:saturate(1.05)}'#10 +
    'button.primary:active{transform:none}button.primary:disabled{opacity:.45;cursor:default;transform:none}'#10 +
    'input{background:var(--panel2);border:1px solid var(--line);border-radius:10px;color:var(--txt);font-family:var(--mono);padding:8px 10px;width:78px;font-size:14px;outline:none;transition:border-color .2s ease,background .2s ease}'#10 +
    'input:focus{border-color:rgba(109,139,255,.55);background:var(--panel)}'#10 +
    '.val{font-family:var(--mono);font-size:15px;color:var(--ok);background:rgba(95,212,245,.08);border:1px solid rgba(95,212,245,.22);border-radius:10px;padding:7px 11px;min-width:68px;text-align:right;backdrop-filter:blur(6px)}'#10 +
    '[data-theme="light"] .val{background:rgba(57,199,239,.08);border-color:rgba(57,199,239,.18);color:#0a7a6b}'#10 +
    '.muted{color:var(--dim);font-size:12px;margin-top:10px;font-family:var(--mono)}'#10 +
    '.log{font-family:var(--mono);font-size:12px;line-height:1.75;max-height:150px;overflow:auto;color:var(--dim);position:relative}'#10 +
    '.log div{border-left:2px solid transparent;padding-left:8px;margin:2px 0;white-space:pre-wrap;word-break:break-all}'#10 +
    '.log div:first-child{border-color:var(--accent2);color:var(--txt)}'#10 +
    'footer{position:fixed;left:0;right:0;bottom:0;display:flex;justify-content:center;gap:18px;flex-wrap:wrap;padding:10px 16px;background:rgba(8,11,22,.72);backdrop-filter:blur(12px) saturate(1.2);border-top:1px solid var(--line);font-family:var(--mono);font-size:12px;color:var(--dim)}'#10 +
    '[data-theme="light"] footer{background:rgba(246,247,251,.78);border-top-color:rgba(16,22,40,.08)}'#10 +
    'footer b{color:var(--ok);font-weight:700}[data-theme="light"] footer b{color:#0a7a6b}'#10 +
    '@media(max-width:640px){body{padding:18px 16px 80px}.wrap{max-width:100%}h1{font-size:22px}}'#10 +
    '@media(prefers-reduced-motion:reduce){*{transition:none!important;animation:none!important}}'#10 +
    '.primary:focus-visible,.icon-btn:focus-visible,input:focus-visible{outline:2px solid var(--accent);outline-offset:2px}'#10 +
    '.card.skeleton{position:relative;overflow:hidden;background:linear-gradient(90deg,var(--panel) 25%,var(--panel2) 37%,var(--panel) 63%);background-size:400% 100%;animation:skeleton 1.2s ease-in-out infinite}'#10 +
    '@keyframes skeleton{0%{background-position:100% 0}100%{background-position:-100% 0}}'#10 +
    '.card.error{border-color:rgba(255,80,80,.35);background:rgba(255,80,80,.06)}[data-theme="light"] .card.error{background:rgba(255,80,80,.07)}'#10 +
    '.card.error h2{color:#ff6b6b}'#10 +
    '</style></head><body>'#10 +
    '<div class="wrap">'#10 +
    '<div class="top"><div><h1>nextPas WebView</h1><div class="sub">Pascal native &#8646; WebKitGTK &middot; full IPC round-trips, zero HTTP server</div></div>'#10 +
    '<div style="display:flex;gap:10px;align-items:center"><span class="pill"><i></i><b id="ver">…</b>&nbsp;bridge</span><button class="icon-btn" id="themeBtn" title="Toggle theme" aria-label="Toggle theme" aria-pressed="false">◐</button></div></div>'#10 +
    '<div class="grid" id="grid">'#10 +
    '<div class="card error" id="errCard" style="display:none" role="alert" aria-live="assertive"><h2>Load / Invoke error</h2><div class="muted" id="errMsg" style="margin-top:8px">—</div><div style="margin-top:12px"><button class="primary" id="errRetry">Dismiss</button></div></div>'#10 +
    '<div class="card"><h2>Sync invoke &middot; sum</h2>'#10 +
    '<div class="row"><input id="aIn" value="19" aria-label="a" inputmode="numeric"><span style="color:var(--dim)">+</span>' +
    '<input id="bIn" value="23" aria-label="b" inputmode="numeric"><button class="primary" id="sumBtn" aria-label="Compute sum">Compute</button>' +
    '<span class="val" id="sumOut">&#8212;</span></div>'#10 +
    '<div class="muted" id="sumMs">window.__npw.invoke("demo.sum")</div></div>'#10 +
    '<div class="card"><h2>Stateful native &middot; counter</h2>'#10 +
    '<div class="row"><button class="primary" id="cntBtn" aria-label="Increment counter">Increment</button>' +
    '<span class="val" id="cntOut" style="font-size:19px">0</span></div>'#10 +
    '<div class="muted">Int64 lives in the Pascal object across calls</div></div>'#10 +
    '<div class="card"><h2>Async invoke &middot; deferred</h2>'#10 +
    '<div class="row"><button class="primary" id="tickBtn" aria-label="Run async tick">Run async tick</button>' +
    '<span class="val" id="tickOut">&#8212;</span></div>'#10 +
    '<div class="muted">handler returns later via Dispatcher.Post</div></div>'#10 +
    '<div class="card"><h2>Native push</h2>'#10 +
    '<div class="row"><button class="primary" id="pushBtn" aria-label="Request native push">Request native push</button>' +
    '<span class="val" id="pushOut">&#8212;</span></div>'#10 +
    '<div class="muted">invoke triggers native Emit; page listens</div></div>'#10 +
    '<div class="card"><h2>Missing asset &#183; 404</h2>'#10 +
    '<div class="row"><button class="primary" id="missBtn" aria-label="Fetch missing asset">Fetch missing.txt (404)</button>' +
    '<span class="val" id="missOut">&#8212;</span></div>'#10 +
    '<div class="muted">npres:// 404 → text/plain empty body (namespace isolation)</div></div>'#10 +
    '<div class="card" style="grid-column:1/-1"><h2>Event log</h2>'#10 +
    '<div class="log" id="log" role="log" aria-live="polite" aria-atomic="false"></div></div>'#10 +
    '</div></div>'#10 +
    '<footer role="status" aria-live="polite"><span>state <b id="state">booting</b></span>' +
    '<span>last op <b id="lastms">&#8212;</b></span><span>theme <b id="themeLabel">auto</b></span></footer>'#10 +
    '<script>'#10 +
    'function $(id){return document.getElementById(id)}'#10 +
    'function lastOp(t0){var d=Math.round(performance.now()-t0);' +
    '$("lastms").textContent=d+" ms";return d}'#10 +
    'function logLine(s){var d=document.createElement("div");d.textContent=s;' +
    '$("log").prepend(d)}'#10 +
    'function report(step,body){__npw.invoke("demo.report",' +
    '{step:step,body:(body===undefined?null:body)})}'#10 +
    '(function(){var k="npw-theme";function apply(t){document.documentElement.setAttribute("data-theme",t);var l=$("themeLabel");if(l)l.textContent=t;var bb=$("themeBtn");if(bb)bb.setAttribute("aria-pressed",t==="light"?"true":"false");try{localStorage.setItem(k,t);}catch(e){}}var s=null;try{s=localStorage.getItem(k);}catch(e){}if(s==="light"||s==="dark")apply(s);else if(window.matchMedia&&window.matchMedia("(prefers-color-scheme: light)").matches)apply("light");else apply("dark");var b=$("themeBtn");if(b)b.addEventListener("click",function(){var cur=document.documentElement.getAttribute("data-theme");apply(cur==="dark"?"light":"dark")});try{var mq=window.matchMedia("(prefers-color-scheme: light)");if(mq&&mq.addEventListener)mq.addEventListener("change",function(e){var cur=null;try{cur=localStorage.getItem(k);}catch(ex){}if(cur!=="light"&&cur!=="dark")apply(e.matches?"light":"dark")});}catch(e){}var a=$("aIn"),bb2=$("bIn");function onEnter(e){if(e.key==="Enter")$("sumBtn").click();}if(a)a.addEventListener("keydown",onEnter);if(bb2)bb2.addEventListener("keydown",onEnter);})();'#10 +
    'var grid=$("grid");if(grid)grid.classList.add("skeleton");'#10 +
    'function showErr(m){var c=$("errCard"),e=$("errMsg");if(c&&e){e.textContent=m;c.style.display="";}}'#10 +
    'var er=$("errRetry");if(er)er.addEventListener("click",function(){var c=$("errCard");if(c)c.style.display="none";});'#10 +
    '__npw.ready.then(function(){' +
    '$("ver").textContent="v"+__npw.version;' +
    'var st=$("state");st.textContent="ready";st.style.color="#43e5c8";' +
    'if(grid)grid.classList.remove("skeleton");' +
    'logLine("bridge ready · protocol v"+__npw.version)}).catch(function(e){showErr("bridge init: "+e);if(grid)grid.classList.remove("skeleton");})'#10 +
    '__npw.listen("demo.event",function(p){' +
    'logLine("event ← "+JSON.stringify(p));' +
    '$("pushOut").textContent=(p&&p.note)?p.note:JSON.stringify(p);' +
    'report("event",p)})'#10 +
    '$("sumBtn").addEventListener("click",function(){' +
    'var t0=performance.now();$("sumBtn").disabled=true;' +
    '__npw.invoke("demo.sum",{a:Number($("aIn").value),b:Number($("bIn").value)})'#10 +
    '.then(function(r){$("sumOut").textContent=JSON.stringify(r);lastOp(t0);' +
    '$("sumMs").textContent="round-trip "+Math.round(performance.now()-t0)+" ms";' +
    'logLine("invoke demo.sum → "+JSON.stringify(r))},' +
    'function(e){$("sumOut").textContent="ERR";logLine("demo.sum failed: "+JSON.stringify(e));showErr("demo.sum: "+JSON.stringify(e))})'#10 +
    '.then(function(){$("sumBtn").disabled=false})})'#10 +
    '$("cntBtn").addEventListener("click",function(){' +
    'var t0=performance.now();' +
    '__npw.invoke("demo.counter",{})' +
    '.then(function(r){$("cntOut").textContent=r.count;lastOp(t0);' +
    'logLine("invoke demo.counter → "+r.count)},' +
    'function(e){logLine("demo.counter failed: "+JSON.stringify(e));showErr("counter: "+JSON.stringify(e))})})'#10 +
    '$("tickBtn").addEventListener("click",function(){' +
    'var t0=performance.now();$("tickBtn").disabled=true;$("tickOut").textContent="…";'#10 +
    '__npw.invoke("demo.tick",{}).then(function(r){' +
    '$("tickOut").textContent=r.deferred?"ok":"??";lastOp(t0);' +
    'logLine("async tick settled → "+JSON.stringify(r)+" (+"+' +
    'Math.round(performance.now()-t0)+" ms)")},' +
    'function(e){$("tickOut").textContent="ERR";logLine("demo.tick failed: "+JSON.stringify(e));showErr("tick: "+JSON.stringify(e))})'#10 +
    '.then(function(){$("tickBtn").disabled=false})})'#10 +
    '$("pushBtn").addEventListener("click",function(){' +
    'var t0=performance.now();' +
    '__npw.invoke("demo.push",{}).then(function(r){lastOp(t0);' +
    'logLine("invoke demo.push → "+JSON.stringify(r)+", awaiting event")},' +
    'function(e){logLine("demo.push failed: "+JSON.stringify(e));showErr("push: "+JSON.stringify(e))})})'#10 +
    '$("missBtn").addEventListener("click",function(){' +
    'var t0=performance.now();$("missOut").textContent="…";' +
    'fetch("npres://app/missing.txt").then(function(r){$("missOut").textContent=r.status;lastOp(t0);' +
    'logLine("fetch missing → "+r.status);if(!r.ok)showErr("404 as expected: "+r.status)}).catch(function(e){$("missOut").textContent="ERR";logLine("fetch missing failed: "+e);showErr(e)})})'#10 +
    'function __npwSelf(kind){var p=null;'#10 +
    'if(kind==="sum")p=__npw.invoke("demo.sum",{a:19,b:23});' +
    'else if(kind==="counter")p=__npw.invoke("demo.counter",{});' +
    'else if(kind==="tick")p=__npw.invoke("demo.tick",{});' +
    'else if(kind==="push")p=__npw.invoke("demo.push",{});'#10 +
    'if(!p)return;'#10 +
    'p.then(function(r){' +
    'if(kind==="sum"){logLine("[selftest] sum → "+JSON.stringify(r));report("sum",r)}' +
    'else if(kind==="counter"){report("counter",r)}' +
    'else if(kind==="tick"){logLine("[selftest] tick → "+JSON.stringify(r));report("tick",r)}' +
    'else if(kind==="push"){report("push",r)}},' +
    'function(e){report("selffail",{msg:JSON.stringify(e)})})}'#10 +
    '</script></body></html>';

function StrToBytes(const S: AnsiString): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(S));
  if Length(S) > 0 then
    Move(S[1], Result[0], Length(S));
end;

type
  { 内嵌页面 provider：前缀 '' 直挂，规范化后只认 index.html }
  TDemoPageProvider = class(TInterfacedObject, IWebviewAssetProvider)
  public
    function TryResolve(const APath: string;
      out ABytes: TBytes; out AMimeType: string): Boolean;
    function TryResolveView(const AView: TStringView;
      out ABytes: TBytes; out AMimeType: string): Boolean;
  end;

function TDemoPageProvider.TryResolve(const APath: string;
  out ABytes: TBytes; out AMimeType: string): Boolean;
begin
  Result := TryResolveView(TStringView.FromStr(APath), ABytes, AMimeType);
end;

function TDemoPageProvider.TryResolveView(const AView: TStringView;
  out ABytes: TBytes; out AMimeType: string): Boolean;
var
  LView: TStringView;
  LNorm: TStringView;
begin
  ABytes := nil;
  AMimeType := '';
  LView := AView;
  LNorm := NormalizeWebviewAssetView(LView);
  // strip optional app/ prefix zero-copy
  if (LNorm.Len >= 4) and (TStringView.FromStr('app/').Equals(LNorm.Left(4))) then
    LNorm := LNorm.Slice(4, LNorm.Len - 4);
  if not TStringView.FromStr('index.html').Equals(LNorm) then
    Exit(False);
  ABytes := StrToBytes(PAGE_HTML);
  AMimeType := 'text/html; charset=utf-8';
  Result := True;
end;

type
  TDemoApp = class
  private
    FSelftest: Boolean;
    FStage: Integer;
    FCounter: Int64;
    FSeq: Int64;
    FFailed: Boolean;
    FFinished: Boolean;
    FPushQueued: Boolean;
    FEventSeen: Boolean;
    FStarted: TDateTime;
    FWindow: IWebviewWindow;
    procedure Pass(const AWhat: string);
    procedure Fail(const AWhy: string);
    procedure Log(const AMsg: string);
    procedure CloseWindow;
    { 解析并校验 object payload；ADoc 必须由调用方持有到取值结束——
      TJsonValue 指向文档内存，文档释放后继续读属悬垂访问 }
    procedure RequireJsonObject(const APayloadJson: string;
      out ADoc: IJsonDocument; out ARoot: TJsonValue);
    function HandleSum(const APayloadJson: string): string;
    function HandleCounter(const APayloadJson: string): string;
    procedure HandleTick(const APayloadJson: string;
      const ACompletion: IWebviewInvokeCompletion);
    procedure HandlePush(const APayloadJson: string;
      const ACompletion: IWebviewInvokeCompletion);
    function HandleReport(const APayloadJson: string): string;
    procedure OnNavFinished(const AEvent: TWebviewNavigationEvent);
    procedure KickSelftest(const AKind: string);
    procedure Advance(const AStep, ABodyJson: string);
    procedure FinishFullCircle;
  public
    constructor Create(ASelftest: Boolean);
    procedure Run;
    property Failed: Boolean read FFailed;
  end;

procedure Stamp(var APrev: TDateTime; out AMs: Int64);
var
  LNow: TDateTime;
begin
  LNow := Now;
  AMs := MilliSecondsBetween(LNow, APrev);
  APrev := LNow;
end;

{ ---- TDemoApp ---- }

constructor TDemoApp.Create(ASelftest: Boolean);
begin
  inherited Create;
  FSelftest := ASelftest;
  FStage := ST_WAIT_NAV;
end;

procedure TDemoApp.Pass(const AWhat: string);
begin
  WriteLn('demo-pass ', AWhat);
end;

procedure TDemoApp.Fail(const AWhy: string);
begin
  if FFailed or FFinished then Exit;
  FFailed := True;
  WriteLn('demo-fail ', AWhy);
  CloseWindow;
end;

procedure TDemoApp.Log(const AMsg: string);
begin
  WriteLn(FormatDateTime('[hh:nn:ss.zzz]', Now), ' ', AMsg);
end;

procedure TDemoApp.CloseWindow;
begin
  if (FWindow <> nil) and not FWindow.IsClosed then
    FWindow.Close;
end;

{ payload 必须是 JSON object；否则抛 EWebviewInvokeError 走桥错误路径
  （演示错误语义：页面收到 reject）。文档生命周期归调用方。 }
procedure TDemoApp.RequireJsonObject(const APayloadJson: string;
  out ADoc: IJsonDocument; out ARoot: TJsonValue);
begin
  ADoc := JsonParse(APayloadJson);
  ARoot := ADoc.Root;
  if ADoc.HasError or (not ARoot.IsObject) then
    raise EWebviewInvokeError.Create('payload must be a JSON object',
      'npw.demo.bad_payload');
end;

function TDemoApp.HandleSum(const APayloadJson: string): string;
var
  LDoc: IJsonDocument;
  R: TJsonValue;
begin
  RequireJsonObject(APayloadJson, LDoc, R);
  Result := TextFormat('{"sum":%d}', [R.Get('a').AsInt + R.Get('b').AsInt]);
end;

function TDemoApp.HandleCounter(const APayloadJson: string): string;
var
  LDoc: IJsonDocument;
  R: TJsonValue;
begin
  RequireJsonObject(APayloadJson, LDoc, R);
  Inc(FCounter);
  Result := TextFormat('{"count":%d}', [FCounter]);
end;

procedure TDemoApp.HandleTick(const APayloadJson: string;
  const ACompletion: IWebviewInvokeCompletion);
var
  LDoc: IJsonDocument;
  R: TJsonValue;
  LSeq: Int64;
begin
  RequireJsonObject(APayloadJson, LDoc, R);
  Inc(FSeq);
  LSeq := FSeq;
  { 不就地完成：投递回主循环下一拍，证明异步 completion 路径 }
  FWindow.Window.Dispatcher.Post(procedure
    begin
      if not FWindow.IsClosed then
        ACompletion.Ok(TextFormat('{"deferred":true,"seq":%d}', [LSeq]));
    end);
end;

procedure TDemoApp.HandlePush(const APayloadJson: string;
  const ACompletion: IWebviewInvokeCompletion);
var
  LDoc: IJsonDocument;
  R: TJsonValue;
  LSeq: Int64;
begin
  RequireJsonObject(APayloadJson, LDoc, R);
  Inc(FSeq);
  LSeq := FSeq;
  FWindow.Window.Dispatcher.Post(procedure
    begin
      if FWindow.IsClosed then Exit;
      { 先 ack 后 emit：WebKit 同视图按序执行 eval，页面回报次序确定，
        自检状态机按 push→event 线性推进 }
      ACompletion.Ok('{"queued":true}');
      FWindow.Emit('demo.event',
        TextFormat('{"note":"pushed from Pascal","seq":%d}', [LSeq]));
    end);
end;

function TDemoApp.HandleReport(const APayloadJson: string): string;
var
  LDoc: IJsonDocument;
  R: TJsonValue;
  LStep: string;
  LMono: Int64;
begin
  RequireJsonObject(APayloadJson, LDoc, R);
  LStep := JsonStrField(R, 'step');
  if FSelftest then
  begin
    if LStep = 'selffail' then
    begin
      Fail('page-side failure: ' + JsonStrField(R.Get('body'), 'msg'));
      Exit('{}');
    end;
    Stamp(FStarted, LMono);
    Log(TextFormat('report %-8s %s (%dms)', [LStep, APayloadJson, LMono]));
    Advance(LStep, APayloadJson);
  end
  else
    Log('report ' + LStep + ' ' + APayloadJson);
  Result := '{}';
end;

procedure TDemoApp.OnNavFinished(const AEvent: TWebviewNavigationEvent);
var
  LMs: Int64;
begin
  if FSelftest then
  begin
    if FStage <> ST_WAIT_NAV then Exit;
    Stamp(FStarted, LMs);
    Log(TextFormat('navigation finished (%dms)', [LMs]));
    Pass('window up, asset served over npres://');
    FStage := ST_WAIT_EVAL;
    FWindow.Eval('6*7',
      procedure(const AResultJson: string)
      begin
        if FFailed or FFinished then Exit;
        if AResultJson <> '42' then
        begin
          Fail('eval 6*7 got: ' + AResultJson);
          Exit;
        end;
        Pass('native->web eval roundtrip (6*7=42)');
        FStage := ST_WAIT_SUM;
        KickSelftest('sum');
      end,
      procedure(const AErr: Exception)
      begin
        Fail('eval error: ' + AErr.Message);
      end);
  end
  else
  begin
    Log('page loaded, bridge injected');
    FWindow.Emit('demo.event', '{"note":"hello from native","seq":0}');
  end;
end;

procedure TDemoApp.KickSelftest(const AKind: string);
begin
  FWindow.Eval('__npwSelf("' + AKind + '")',
    procedure(const AResultJson: string)
    begin
      { 结果恒为 undefined；真正断言在 demo.report 回报里做 }
    end,
    procedure(const AErr: Exception)
    begin
      Fail('kick ' + AKind + ' eval error: ' + AErr.Message);
    end);
end;

procedure TDemoApp.Advance(const AStep, ABodyJson: string);
var
  LDoc: IJsonDocument;
  LBody: TJsonValue;
  LCount: Int64;
begin
  if FFailed or FFinished then Exit;
  LDoc := JsonParse(ABodyJson);
  if LDoc.HasError then
  begin
    Fail('report payload not json: ' + ABodyJson);
    Exit;
  end;
  LBody := LDoc.Root.Get('body');

  case FStage of

    ST_WAIT_SUM:
      if AStep = 'sum' then
      begin
        if JsonIntField(LBody, 'sum') <> 42 then
        begin
          Fail('sum roundtrip expected 42, got: ' + ABodyJson);
          Exit;
        end;
        Pass('sync invoke roundtrip sum(19,23)=42');
        FStage := ST_WAIT_CNT1;
        KickSelftest('counter');
      end;

    ST_WAIT_CNT1:
      if AStep = 'counter' then
      begin
        LCount := JsonIntField(LBody, 'count');
        if LCount <> 1 then
        begin
          Fail('counter first increment expected 1, got: ' + ABodyJson);
          Exit;
        end;
        Pass('stateful counter -> 1');
        FStage := ST_WAIT_CNT2;
        KickSelftest('counter');
      end;

    ST_WAIT_CNT2:
      if AStep = 'counter' then
      begin
        LCount := JsonIntField(LBody, 'count');
        if LCount <> 2 then
        begin
          Fail('counter second increment expected 2, got: ' + ABodyJson);
          Exit;
        end;
        Pass('stateful counter -> 2 (state kept in native object)');
        FStage := ST_WAIT_TICK;
        KickSelftest('tick');
      end;

    ST_WAIT_TICK:
      if AStep = 'tick' then
      begin
        if not JsonBoolField(LBody, 'deferred') then
        begin
          Fail('async tick expected deferred:true, got: ' + ABodyJson);
          Exit;
        end;
        Pass('async invoke completed via Dispatcher.Post');
        FStage := ST_WAIT_PUSH;
        KickSelftest('push');
      end;

    { 收尾阶段 push-ack 与 event 回报跨通道无全局次序保证（两条独立
      异步链），按集合语义双到即成 }
    ST_WAIT_PUSH, ST_WAIT_EVENT:
      if AStep = 'push' then
      begin
        if not JsonBoolField(LBody, 'queued') then
        begin
          Fail('push expected queued:true, got: ' + ABodyJson);
          Exit;
        end;
        FPushQueued := True;
        Pass('push ack queued:true');
        FStage := ST_WAIT_EVENT;
        if FEventSeen then
          FinishFullCircle;
      end
      else if AStep = 'event' then
      begin
        if JsonStrField(LBody, 'note') <> 'pushed from Pascal' then
        begin
          Fail('event note mismatch, got: ' + ABodyJson);
          Exit;
        end;
        FEventSeen := True;
        Pass('native->web event received');
        if FPushQueued then
          FinishFullCircle;
      end;
  end;
end;

procedure TDemoApp.FinishFullCircle;
begin
  if FFinished or FFailed then Exit;
  FFinished := True;
  Pass('full circle web->native->web complete');
  Pass('all steps');
  CloseWindow;
end;

procedure TDemoApp.Run;
begin
  FStarted := Now;
  FWindow := TWebviewBuilder.New
    .Title('nextPas WebView Demo')
    .Size(1040, 700)
    .Resizable(True)
    .Kind(wvGtk)
    .Build;

  { 页面资产经自身 scheme 提供：npres://app/index.html }
  FWindow.Assets.MountEmbedded('', TDemoPageProvider.Create);

  { IPC 面：同步 / 有状态同步 / 回报 / 异步 }
  FWindow.Invokes.Register('demo.sum', @HandleSum);
  FWindow.Invokes.Register('demo.counter', @HandleCounter);
  FWindow.Invokes.Register('demo.report', @HandleReport);
  FWindow.Invokes.RegisterAsync('demo.tick', @HandleTick);
  FWindow.Invokes.RegisterAsync('demo.push', @HandlePush);

  FWindow.OnNavigationFinished(@OnNavFinished);
  FWindow.OnNavigationFailed(
    procedure(const AEvent: TWebviewNavigationEvent)
    begin
      if FSelftest then
        Fail('navigation failed: ' + AEvent.Url)
      else
        Log('navigation failed: ' + AEvent.Url);
    end);
  FWindow.Window.OnEvent(
    procedure(const AEvent: TWindowEvent)
    begin
      if AEvent.Kind = weCloseRequested then
        WebviewExitLoop;
    end);

  FWindow.Window.Show;
  if FSelftest then
    Log('selftest window up, driving matrix...')
  else
    Log('window up; close it to exit');
  FWindow.Navigate('npres://app/index.html');

  WebviewRunLoop;
  FWindow := nil;

  if FSelftest and (not FFinished) and (not FFailed) then
  begin
    FFailed := True;
    WriteLn('demo-fail interrupted before completion');
  end;
end;

var
  LApp: TDemoApp;
  LSelftest: Boolean;
begin
  LSelftest := (ParamCount >= 1) and (ParamStr(1) = '--selftest');

  if not WebviewBackendAvailable(wvGtk) then
  begin
    if LSelftest then
      WriteLn('demo-skip no-gtk-backend')
    else
    begin
      WriteLn('no GTK/WebKitGTK backend available on this machine');
      ExitCode := 1;
    end;
    Exit;
  end;

  LApp := TDemoApp.Create(LSelftest);
  try
    LApp.Run;
    if LSelftest and LApp.Failed then
      ExitCode := 1;
  finally
    LApp.Free;
  end;
end.
