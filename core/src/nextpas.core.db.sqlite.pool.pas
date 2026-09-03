unit nextpas.core.db.sqlite.pool;

{** @desc SQLite 池工厂：组合通用池（db.pool）与统一层 sqlite 适配器
       （db.sqlite.adapter）的开箱形态，消费方不再各自手拼策略。
       Usage:
         Pool := OpenSqlitePool('/var/lib/app/app.db', 4);
         try
           WithTransaction(Pool.Writer,
             procedure(const C: IDbConnection) begin C.Exec('...') end);
         finally
           Pool.Free;
         end;
       两形态：
         - OpenSqlitePool(Path, MaxRead)：缺省池策略仅覆盖读上限，
           连接选项烘入生产级 busy_timeout（见 DefaultSqliteBusyTimeoutMs，
           F-10：sqlite 缺省 0 在文件锁竞争下立即 SQLITE_BUSY）。
         - OpenSqlitePool(Path, Policy, Options)：全控，逐字采用。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.db.pool,
  nextpas.core.db.sqlite.base;

{ F-10：文件库并发读写依赖 busy_timeout 排队；0 = 立即 SQLITE_BUSY。
  单源于 sqlite.base.DefaultSqliteBusyTimeoutMs（本单元 re-export 保持 API 兼容，零漂移）。 }
const
  DefaultSqliteBusyTimeoutMs = nextpas.core.db.sqlite.base.DefaultSqliteBusyTimeoutMs;

{ 便利形态：TDbPoolPolicy.Default 仅覆盖 MaxReadConnections；
  连接选项 = TDbConnectOptions.Default 但 BusyTimeoutMs 取
  DefaultSqliteBusyTimeoutMs。覆盖单机应用绝大多数场景。 }
function OpenSqlitePool(const APath: string;
  AMaxReadConnections: Integer): TDbPool; overload;

{ 全控形态：池策略与连接选项逐字采用，不做任何隐式补齐——
  需要自定生命周期/泄漏检测等高级策略时使用。 }
function OpenSqlitePool(const APath: string; const APolicy: TDbPoolPolicy;
  const AOptions: TDbConnectOptions): TDbPool; overload;

implementation

uses
  nextpas.core.db.sqlite.adapter;

function OpenSqlitePool(const APath: string;
  AMaxReadConnections: Integer): TDbPool;
var
  P: TDbPoolPolicy;
  O: TDbConnectOptions;
begin
  P := TDbPoolPolicy.Default;
  P.MaxReadConnections := AMaxReadConnections;
  O := TDbConnectOptions.Default;
  O.BusyTimeoutMs := DefaultSqliteBusyTimeoutMs;
  Result := OpenSqlitePool(APath, P, O);
end;

function OpenSqlitePool(const APath: string; const APolicy: TDbPoolPolicy;
  const AOptions: TDbConnectOptions): TDbPool;
begin
  Result := TDbPool.Create(
    function: IDbConnection
    begin
      Result := ConnectSqlite(APath, AOptions);
    end, APolicy);
end;

end.
