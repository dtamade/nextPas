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
  public
    constructor Create;
    procedure Do_(const AProc: TOnceProc);
    function Done: Boolean;
  end;

constructor TOnce.Create;
begin
  inherited Create;
  FState := STATE_INIT;
end;

procedure TOnce.Do_(const AProc: TOnceProc);
var
  LOld, LCur: Int32;
begin
  while True do
  begin
    LCur := AtomicLoad32(FState, moAcquire);
    if LCur = STATE_DONE then
      Exit;
    if LCur = STATE_INIT then
    begin
      LOld := AtomicCompareExchange32(FState, STATE_INIT, STATE_RUNNING, moAcqRel);
      if LOld = STATE_INIT then
      begin
        try
          AProc();
          AtomicStore32(FState, STATE_DONE, moRelease);
          platform_wake_address_all(@FState);
        except
          AtomicStore32(FState, STATE_INIT, moRelease);
          platform_wake_address_all(@FState);
          raise;
        end;
        Exit;
      end;
    end;
    platform_wait_address32(@FState, STATE_RUNNING, -1);
  end;
end;

function TOnce.Done: Boolean;
begin
  Result := AtomicLoad32(FState, moAcquire) = STATE_DONE;
end;

function CreateOnce: IOnce;
begin
  Result := TOnce.Create;
end;

end.
