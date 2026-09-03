unit nextpas.core.wallet.stream;

{ L3 wallet ledger stream: streaming iterator reuse candidate converging impl volume; avoids 100 prealloc AddRef/truncate churn via incremental doubling. bytes.ops single source, inline zero-copy. }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.db.intf,
  nextpas.core.wallet.base;

procedure FillLedgerEntry(const AQuery: IDbQuery; out AEntry: TWalletLedgerEntry); inline;
function WalletLedgerCollect(const AQuery: IDbQuery; const ALimit: Integer): TWalletLedgerArray; inline;

implementation

uses
  nextpas.core.bytes.ops;


procedure FillLedgerEntry(const AQuery: IDbQuery; out AEntry: TWalletLedgerEntry); inline;
begin
  AEntry.Id := AQuery.GetText(0);
  AEntry.UserId := AQuery.GetText(1);
  AEntry.DeltaCents := AQuery.GetInt64(2);
  AEntry.Reason := AQuery.GetText(3);
  AEntry.RefId := AQuery.GetText(4);
  AEntry.CreatedAt := AQuery.GetText(5);
end;

function WalletLedgerCollect(const AQuery: IDbQuery; const ALimit: Integer): TWalletLedgerArray; inline;
var
  LCount, LCap, LNewCap: Integer;
begin
  Result := nil;
  if (AQuery = nil) or (ALimit < 1) then Exit;
  LCount := 0;
  LCap := 0;
  while AQuery.Step do
  begin
    if LCount >= ALimit then Break;
    if LCount >= LCap then
    begin
      if LCap = 0 then
        LNewCap := 8
      else
        LNewCap := Integer(BytesGrowCapacity(SizeUInt(LCap), SizeUInt(LCount + 1)));
      if LNewCap > ALimit then LNewCap := ALimit;
      if LNewCap < LCount + 1 then LNewCap := LCount + 1;
      SetLength(Result, LNewCap);
      LCap := LNewCap;
    end;
    FillLedgerEntry(AQuery, Result[LCount]);
    Inc(LCount);
  end;
  if LCap <> LCount then
    SetLength(Result, LCount);
end;

end.
