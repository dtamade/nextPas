unit nextpas.core.db.sqlite.adapter.cancel;

{** @desc SQLite 适配器取消分治（L3 实现子模块，V3-B6）。
       封装原子取消标志与 sqlite3_progress_handler 挂卸：跨线程
       RequestCancel 原子置位，执行线程 progress 回调原子读取。
       层级：L3 适配子模块（严格下向 L2 sqlite.base/ffi，无上向；
       同层单向：仅被 adapter 单向依赖，不反向）。
       性能：Arm/Disarm/Request  inline 薄转发，零拷贝（标志为 Integer
       原地原子，无串分配），复用 bytes.ops 单源守卫。
       稳定性：Disarm 先清标志再卸 handler，析构链先于句柄关闭调用。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.sqlite.base;

type
  TSqliteCancel = class
  private
    FHandle: TSqliteHandle;
    FCancelFlag: Integer; { 0=无取消,1=已请求；原子访问 }
  public
    constructor Create(AHandle: TSqliteHandle);
    function Arm: Boolean; inline;
    procedure Disarm; inline;
    procedure RequestCancel; inline;
    function FlagPtr: PInteger; inline;
  end;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.atomic,
  nextpas.core.db.sqlite.ffi;

{$IF not BYTES_OPS_SINGLE_SOURCE}
  {$FATAL 'bytes.ops single source drift: sqlite.adapter.cancel must reuse bytes.ops'}
{$IFEND}

{ progress handler 桩：探测取消标志（非零=中断）。
  sqlite 在执行线程回调；RequestCancel 可从任意线程写标志。 }
function SqliteCancelProbe(AUser: Pointer): Integer; cdecl;
begin
  Result := Ord(atomic_load(PInteger(AUser)^, mo_acquire) <> 0);
end;

constructor TSqliteCancel.Create(AHandle: TSqliteHandle);
begin
  inherited Create;
  FHandle := AHandle;
  FCancelFlag := 0;
end;

function TSqliteCancel.Arm: Boolean;
begin
  FCancelFlag := 0;
  sqlite3_progress_handler(FHandle, 10000, @SqliteCancelProbe, @FCancelFlag);
  Result := True;
end;

procedure TSqliteCancel.Disarm;
begin
  atomic_exchange(FCancelFlag, 0, mo_acq_rel);
  sqlite3_progress_handler(FHandle, 0, nil, nil);
end;

procedure TSqliteCancel.RequestCancel;
begin
  atomic_exchange(FCancelFlag, 1, mo_acq_rel);
end;

function TSqliteCancel.FlagPtr: PInteger;
begin
  Result := @FCancelFlag;
end;

end.
