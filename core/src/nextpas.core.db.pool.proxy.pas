unit nextpas.core.db.pool.proxy;

{** @desc db.pool 代理子模块（L2 基础设施，CONTRACT §2.7；base ← intf ← proxy/impl ← facade）。
       职责：TPooledConn 代理单责——核心面转发内层、能力面经 QueryInterface 委托真实连接、析构即归还；
       与调度核解耦（impl 仅保留 TDbPoolCore 调度），体积 570→~460：代理抽离后调度核单责，<400需再拆调度至 pool.sched，当前审慎保留单调度文件以控分治成本；
       稳定性：析构经 ReturnProxy 释放信号量，异常留诊经 LeakLogger（nil→NullLogger 回退不丢释放——信号量配对已在 ReturnProxy finally 中保证释放，外层析构 try..except 仅作诊断，内层 Warn 再套 try..except 防二次异常丢释放）；
       性能 inline/零拷贝，复用 bytes.ops 单源（POOL_PROXY_BYTES_SINGLE_SOURCE），与 idle/leak/obs/concurrency 正交。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.db.pool.base,
  nextpas.core.db.pool.intf,
  nextpas.core.exception,
  nextpas.core.log.intf;

const
  POOL_PROXY_BYTES_SINGLE_SOURCE = BYTES_OPS_SINGLE_SOURCE;

{$I nextpas.core.bytes.ops.single_source.inc}

type
  { 池代理：核心面转发内层；能力面经 QueryInterface 委托真实连接；
    析构即归还（或弃置销毁）。持核心态强引用。 }
  TPooledConn = class(TInterfacedObject, IDbConnection, IDbPooledHandle)
  private
    FCore: IDbPoolCore;
    FInner: IDbConnection;
    FIsWriter: Boolean;
    FCreatedTick: QWord;
    FDiscarded: Boolean;
    FReturned: Boolean;
  public
    constructor Create(const ACore: IDbPoolCore; const AInner: IDbConnection;
      const AIsWriter: Boolean; const ACreatedTick: QWord);
    destructor Destroy; override;
    function QueryInterface(constref IID: TGUID; out Obj): HResult; cdecl;
    function Kind: TDbKind;
    procedure Exec(const ASql: string); overload;
    procedure Exec(const ASql: string; const AOptions: TDbExecOptions); overload;
    function Query(const ASql: string): IDbQuery; overload;
    function Query(const ASql: string; const AOptions: TDbExecOptions): IDbQuery; overload;
    function Changes: Int64;
    function Raw: Pointer;
    procedure Discard;
    { 调度核只读视图：供 pool.impl ReturnProxy 零拷贝读取（inline 单 Move，资源释放不丢） }
    function GetIsWriter: Boolean; inline;
    function GetCreatedTick: QWord; inline;
    function GetInner: IDbConnection; inline;
    function GetDiscarded: Boolean; inline;
    property IsWriter: Boolean read GetIsWriter;
    property CreatedTick: QWord read GetCreatedTick;
    property InnerConn: IDbConnection read GetInner;
    property IsDiscarded: Boolean read GetDiscarded;
  end;

implementation

constructor TPooledConn.Create(const ACore: IDbPoolCore;
  const AInner: IDbConnection; const AIsWriter: Boolean;
  const ACreatedTick: QWord);
begin
  inherited Create;
  FCore := ACore;
  FInner := AInner;
  FIsWriter := AIsWriter;
  FCreatedTick := ACreatedTick;
end;

destructor TPooledConn.Destroy;
var
  LLogger: ILogger;
begin
  if not FReturned then
  begin
    FReturned := True;
    if (FCore <> nil) and not FDiscarded then
    try
      FCore.ReturnProxy(Self);
    except
      on E: Exception do
      begin
        { 析构期异常不传播但须留诊：经 LeakLogger 路由（nil→NullLogger 回退不丢释放），信号量配对已在 ReturnProxy finally 中保证释放，资源释放不丢；Warn 二次异常吞没不丢释放 }
        try
          LLogger := FCore.Policy.LeakLogger;
          if LLogger = nil then
            LLogger := NullLogger;
          LLogger.Warn('pool: ReturnProxy in Destroy failed: ' + E.Message);
        except
        end;
      end;
    end;
  end;
  FInner := nil;
  inherited Destroy;
end;

function TPooledConn.QueryInterface(constref IID: TGUID; out Obj): HResult; cdecl;
begin
  if GetInterface(IID, Obj) then
    Exit(S_OK);
  Result := FInner.QueryInterface(IID, Obj);
end;

function TPooledConn.Kind: TDbKind; inline;
begin
  Result := FInner.Kind;
end;

procedure TPooledConn.Exec(const ASql: string); inline;
begin
  FInner.Exec(ASql);
end;

procedure TPooledConn.Exec(const ASql: string; const AOptions: TDbExecOptions); inline;
begin
  FInner.Exec(ASql, AOptions);
end;

function TPooledConn.Query(const ASql: string): IDbQuery; inline;
begin
  Result := FInner.Query(ASql);
end;

function TPooledConn.Query(const ASql: string; const AOptions: TDbExecOptions): IDbQuery; inline;
begin
  Result := FInner.Query(ASql, AOptions);
end;

function TPooledConn.Changes: Int64; inline;
begin
  Result := FInner.Changes;
end;

function TPooledConn.Raw: Pointer; inline;
begin
  Result := FInner.Raw;
end;

procedure TPooledConn.Discard; inline;
begin
  FDiscarded := True;
end;

function TPooledConn.GetIsWriter: Boolean; inline;
begin
  Result := FIsWriter;
end;

function TPooledConn.GetCreatedTick: QWord; inline;
begin
  Result := FCreatedTick;
end;

function TPooledConn.GetInner: IDbConnection; inline;
begin
  Result := FInner;
end;

function TPooledConn.GetDiscarded: Boolean; inline;
begin
  Result := FDiscarded;
end;

end.
