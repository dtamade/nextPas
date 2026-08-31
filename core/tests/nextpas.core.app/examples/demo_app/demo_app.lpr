program demo_app;

{$I nextpas.core.settings.inc}

uses
  SysUtils, DateUtils,
  nextpas.core.base,
  nextpas.core.json,
  nextpas.core.webview.base,
  nextpas.core.webview,
  nextpas.core.app;

const
  PAGE_HTML: AnsiString =
    '<!DOCTYPE html><html><head><meta charset="utf-8"><style>body{font-family:system-ui;padding:20px;background:#0b0f1d;color:#e7ecf7}</style></head><body>'+
    '<h1>nextPas App Demo</h1><div id="log"></div>'+
    '<script>function log(s){var d=document.createElement("div");d.textContent=s;document.getElementById("log").prepend(d)}'+
    '__npw.ready.then(()=>{log("ready v"+__npw.version)}).catch(e=>log("err "+e));'+
    '__npw.listen("demo.event",p=>log("event "+JSON.stringify(p)));'+
    'function self(k){if(k==="sum")__npw.invoke("demo.sum",{a:19,b:23}).then(r=>__npw.invoke("demo.report",{step:"sum",body:r}))}'+
    '</script></body></html>';

function StrToBytes(const S: AnsiString): TBytes;
begin
  Result:=nil; SetLength(Result, Length(S)); if Length(S)>0 then Move(S[1], Result[0], Length(S));
end;

type
  TDemoPage = class(TInterfacedObject, IWebviewAssetProvider)
    function TryResolve(const APath: string; out ABytes: TBytes; out AMimeType: string): Boolean;
  end;

function TDemoPage.TryResolve(const APath: string; out ABytes: TBytes; out AMimeType: string): Boolean;
var L:string; begin L:=APath; while (Length(L)>0) and (L[1]='/') do Delete(L,1,1); if Copy(L,1,4)='app/' then Delete(L,1,4); if L<>'index.html' then Exit(False); ABytes:=StrToBytes(PAGE_HTML); AMimeType:='text/html; charset=utf-8'; Result:=True; end;

type
  TDemoApp = class
  private
    FSelftest:Boolean; FApp:IApp; FStage:Integer; FFailed,FFinished:Boolean; FStarted:TDateTime;
    procedure Pass(const S:string); procedure Fail(const S:string); procedure Log(const S:string);
    procedure RequireObj(const J:string; out D:IJsonDocument; out R:TJsonValue);
    function HSum(const P:string):string; function HReport(const P:string):string;
    procedure OnNav(const E:TWebviewNavigationEvent); procedure Advance(const Step,Body:string); procedure Kick(const K:string);
  public constructor Create(ASelf:Boolean); procedure Run; property Failed:Boolean read FFailed; end;

procedure Stamp(var P:TDateTime; out M:Int64); var N:TDateTime; begin N:=Now; M:=MilliSecondsBetween(N,P); P:=N; end;

constructor TDemoApp.Create(ASelf:Boolean); begin inherited Create; FSelftest:=ASelf; FStage:=1; end;
procedure TDemoApp.Pass(const S:string); begin WriteLn('demo-pass ',S); end;
procedure TDemoApp.Fail(const S:string); begin if FFailed or FFinished then Exit; FFailed:=True; WriteLn('demo-fail ',S); if (FApp<>nil) and not FApp.IsClosed then FApp.Close; end;
procedure TDemoApp.Log(const S:string); begin WriteLn(FormatDateTime('[hh:nn:ss.zzz]',Now),' ',S); end;
procedure TDemoApp.RequireObj(const J:string; out D:IJsonDocument; out R:TJsonValue); begin D:=JsonParse(J); R:=D.Root; if D.HasError or not R.IsObject then raise EWebviewInvokeError.Create('payload must be object','npw.demo.bad_payload'); end;
function TDemoApp.HSum(const P:string):string; var D:IJsonDocument; R:TJsonValue; begin RequireObj(P,D,R); Result:=Format('{"sum":%d}',[R.Get('a').AsInt+R.Get('b').AsInt]); end;
function TDemoApp.HReport(const P:string):string; var D:IJsonDocument; R:TJsonValue; S:string; M:Int64; begin RequireObj(P,D,R); S:=JsonStrField(R,'step'); if FSelftest then begin if S='selffail' then begin Fail('page fail '+JsonStrField(R.Get('body'),'msg')); Exit('{}'); end; Stamp(FStarted,M); Log(Format('report %-8s %s (%dms)',[S,P,M])); Advance(S,P); end else Log('report '+S+' '+P); Result:='{}'; end;
procedure TDemoApp.OnNav(const E:TWebviewNavigationEvent); var LMs:Int64; begin if FSelftest then begin if FStage<>1 then Exit; Stamp(FStarted,LMs); Log(Format('nav finished %dms',[LMs])); Pass('window up'); FStage:=2; FApp.MainWindow.Eval('6*7',procedure(const J:string) begin if J<>'42' then begin Fail('eval got '+J); Exit; end; Pass('eval 6*7=42'); FStage:=3; Kick('sum'); end, procedure(const E:Exception) begin Fail('eval err '+E.Message); end); end else begin Log('page loaded'); FApp.MainWindow.Emit('demo.event','{"note":"hello from app"}'); end; end;
procedure TDemoApp.Kick(const K:string); begin FApp.MainWindow.Eval('self("'+K+'")',procedure(const J:string) begin end, procedure(const E:Exception) begin Fail('kick '+K+' '+E.Message); end); end;
procedure TDemoApp.Advance(const Step,Body:string); var D:IJsonDocument; B:TJsonValue; begin if FFailed or FFinished then Exit; D:=JsonParse(Body); if D.HasError then begin Fail('report not json '+Body); Exit; end; B:=D.Root.Get('body'); if (FStage=3) and (Step='sum') then begin if JsonIntField(B,'sum')<>42 then begin Fail('sum exp 42 got '+Body); Exit; end; Pass('sum 42'); FFinished:=True; Pass('all steps'); if not FApp.IsClosed then FApp.Close; end; end;
procedure TDemoApp.Run; var W2:IWebviewWindow; begin FStarted:=Now; FApp:=TAppBuilder.New.Title('nextPas App Demo').Size(900,600).Kind(wvGtk).MountEmbedded('',TDemoPage.Create).RegisterInvoke('demo.sum',@HSum).RegisterInvoke('demo.report',@HReport).Build; FApp.MainWindow.OnNavigationFinished(@OnNav); FApp.MainWindow.OnWindowClosed(procedure begin FApp.Quit; end); FApp.MainWindow.Show; Log('app up count='+IntToStr(FApp.WindowCount));
  if not FSelftest then
    FApp.MainWindow.Dispatcher.Post(procedure begin W2:=FApp.NewWindowBuilder.Title('Second').Build; FApp.AddWindow(W2); Log('second window added count='+IntToStr(FApp.WindowCount)); W2.Assets.MountEmbedded('',TDemoPage.Create); W2.Show; W2.Navigate('npres://app/index.html'); end);
  FApp.MainWindow.Navigate('npres://app/index.html'); FApp.Run; FApp:=nil; if FSelftest and not FFinished and not FFailed then begin FFailed:=True; WriteLn('demo-fail interrupted'); end; end;

var A:TDemoApp; Selft:Boolean;
begin
  Selft:=(ParamCount>=1) and (ParamStr(1)='--selftest');
  if not AppBackendAvailable(wvGtk) then begin if Selft then WriteLn('demo-skip no-gtk') else begin WriteLn('no gtk'); ExitCode:=1; end; Exit; end;
  A:=TDemoApp.Create(Selft); try A.Run; if Selft and A.Failed then ExitCode:=1; finally A.Free; end;
end.
