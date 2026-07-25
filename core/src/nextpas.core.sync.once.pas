unit nextpas.core.sync.once;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.sync.base,
  nextpas.core.sync.intf;

function CreateOnce: IOnce;

implementation

uses
  nextpas.core.atomic,
  nextpas.core.platform.sync;

const
  STATE_INIT    = 0;
  STATE_RUNNING = 1;
  STATE_DONE    = 2;

type
  TOnce = class(TInterfacedObject, IOnce)
  private
    FState: Int32;
    procedure RunOnce(const AProc: TSyncProc);
  public
    constructor Create;
    procedure Do_(const AProc: TOnceProc);
    procedure DoOnce(const AProc: TOnceProc);
    procedure DoOnce(const AProc: TSyncProc);
    function Done: Boolean;
  end;

constructor TOnce.Create;
begin
  inherited Create;
  FState := STATE_INIT;
end;

procedure TOnce.RunOnce(const AProc: TSyncProc);
var
  LCur, LExpected: Int32;
begin
  while True do
  begin
    LCur := atomic_load(FState, mo_acquire);
    if LCur = STATE_DONE then
      Exit;
    if LCur = STATE_INIT then
    begin
      LExpected := STATE_INIT;
      if atomic_compare_exchange_strong(FState, LExpected, STATE_RUNNING, mo_acq_rel, mo_acquire) then
      begin
        try
          if Assigned(AProc) then
            AProc();
          atomic_store(FState, STATE_DONE, mo_release);
          platform_wake_address_all(@FState);
        except
          atomic_store(FState, STATE_INIT, mo_release);
          platform_wake_address_all(@FState);
          raise;
        end;
        Exit;
      end;
    end;
    platform_wait_address32(@FState, STATE_RUNNING, -1);
  end;
end;

procedure TOnce.Do_(const AProc: TOnceProc);
begin
  if not Assigned(AProc) then
  begin
    RunOnce(nil);
    Exit;
  end;
  RunOnce(procedure
  begin
    AProc();
  end);
end;

procedure TOnce.DoOnce(const AProc: TOnceProc);
begin
  Do_(AProc);
end;

procedure TOnce.DoOnce(const AProc: TSyncProc);
begin
  RunOnce(AProc);
end;

function TOnce.Done: Boolean;
begin
  Result := atomic_load(FState, mo_acquire) = STATE_DONE;
end;

function CreateOnce: IOnce;
begin
  Result := TOnce.Create;
end;

end.
