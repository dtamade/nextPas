program Comprehensive_sema_pass;
type
  TStatus = (stOk, stError, stPending);
  TResult = record
    Status: TStatus;
    Value: Integer;
    Message: string;
  end;

const
  MaxRetries = 3;
  DefaultMessage = 'ok';

function MakeResult(AStatus: TStatus; AValue: Integer): TResult;
begin
  MakeResult.Status := AStatus;
  MakeResult.Value := AValue;
  MakeResult.Message := DefaultMessage;
end;

procedure Process(var R: TResult);
begin
  if R.Value < 0 then
    R.Status := stError
  else
    R.Status := stOk;
end;

var
  R: TResult;
  I: Integer;
begin
  R := MakeResult(stOk, 42);
  for I := 1 to MaxRetries do
    Process(R);
end.
