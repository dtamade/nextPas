unit nextpas.core.db.sqlite.adapter.state;

{** @desc SQLite 连接状态分治（L3 实现子模块）。
       封装 PRAGMA foreign_keys 去重标记等句柄内轻量状态：零锁/
       零哈希 wallet 热租约标记，仅本连接可见。
       层级：L3 适配子模块（严格下向 L2 sqlite.base，无上向；
       同层单向：仅被 adapter 单向依赖，不反向）。
       性能：Get/Set inline 薄转发，Bool 原地访问零分配，复用
       bytes.ops 单源守卫。
       稳定性：纯标记无资源，析构无副作用。 *}

{$I nextpas.core.settings.inc}

interface

type
  TSqliteConnState = class
  private
    FForeignKeysOn: Boolean;
  public
    constructor Create;
    function ForeignKeysOn: Boolean; inline;
    procedure SetForeignKeysOn(const AValue: Boolean); inline;
  end;

implementation

uses
  nextpas.core.bytes.ops;


constructor TSqliteConnState.Create;
begin
  inherited Create;
  FForeignKeysOn := False;
end;

function TSqliteConnState.ForeignKeysOn: Boolean; inline;
begin
  Result := FForeignKeysOn;
end;

procedure TSqliteConnState.SetForeignKeysOn(const AValue: Boolean); inline;
begin
  FForeignKeysOn := AValue;
end;

end.
