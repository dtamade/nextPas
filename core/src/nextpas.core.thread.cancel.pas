unit nextpas.core.thread.cancel;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.thread.intf;

function CreateCancellationSource: ICancellationSource;

implementation

uses
  nextpas.core.errors,
  nextpas.core.sync;

type
  TCancellationToken = class(TInterfacedObject, ICancellationToken)
  private
    FEvent: IEvent;
  public
    constructor Create(const AEvent: IEvent);
    function IsCancelled: Boolean;
    procedure ThrowIfCancelled;
    function WaitCancellation(const ATimeoutNs: Int64): Boolean;
  end;

  TCancellationSource = class(TInterfacedObject, ICancellationSource)
  private
    FEvent: IEvent;
    FToken: ICancellationToken;
  public
    constructor Create;
    function Token: ICancellationToken;
    procedure Cancel;
  end;

{ TCancellationToken }

constructor TCancellationToken.Create(const AEvent: IEvent);
begin
  inherited Create;
  FEvent := AEvent;
end;

function TCancellationToken.IsCancelled: Boolean;
begin
  Result := FEvent.IsSet;
end;

procedure TCancellationToken.ThrowIfCancelled;
begin
  if FEvent.IsSet then
    raise ECancelledError.Create('operation cancelled');
end;

function TCancellationToken.WaitCancellation(const ATimeoutNs: Int64): Boolean;
begin
  if FEvent.IsSet then
    Exit(True);
  Result := FEvent.WaitTimeout(ATimeoutNs);
end;

{ TCancellationSource }

constructor TCancellationSource.Create;
begin
  inherited Create;
  FEvent := nextpas.core.sync.Event(True);
  FToken := TCancellationToken.Create(FEvent);
end;

function TCancellationSource.Token: ICancellationToken;
begin
  Result := FToken;
end;

procedure TCancellationSource.Cancel;
begin
  FEvent.SetEvent;
end;

{ Factory }

function CreateCancellationSource: ICancellationSource;
begin
  Result := TCancellationSource.Create;
end;

end.
