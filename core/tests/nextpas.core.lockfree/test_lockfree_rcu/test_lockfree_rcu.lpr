program test_lockfree_rcu;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.lockfree.rcu,
  nextpas.core.lockfree,
  nextpas.core.atomic,
  nextpas.core.test;

type
  TIntPublisher = specialize TRcuPublisher<Int64>;

procedure TestRcuDomainBasic;
var
  LDomain: TRcuDomain;
  LGuard: TRcuGuard;
begin
  LDomain := TRcuDomain.Create;
  try
    LDomain.EnterRead(LGuard);
    Check(LGuard.ReaderIndex >= 0, 'Reader index should be valid');
    Check(LGuard.ReaderIndex < 64, 'Reader index should be < 64');
    LDomain.ExitRead(LGuard);

    Check(not LDomain.IsClosed, 'Should not be closed');
  finally
    LDomain.Free;
  end;
end;

procedure TestRcuDomainClose;
var
  LDomain: TRcuDomain;
begin
  LDomain := TRcuDomain.Create;
  try
    LDomain.Close;
    Check(LDomain.IsClosed, 'Should be closed');
  finally
    LDomain.Free;
  end;
end;

procedure TestRcuDomainSynchronize;
var
  LDomain: TRcuDomain;
  LGuard: TRcuGuard;
begin
  LDomain := TRcuDomain.Create;
  try
    LDomain.EnterRead(LGuard);
    LDomain.ExitRead(LGuard);
    LDomain.Synchronize;
    // Should complete without hanging
    Check(True, 'Synchronize completed');
  finally
    LDomain.Free;
  end;
end;

procedure TestRcuPublisherBasic;
var
  LPublisher: TIntPublisher;
  LValue: Int64;
begin
  LPublisher := TIntPublisher.Create(42);
  try
    Check(LPublisher.Read(LValue), 'Should read successfully');
    CheckEqual(Int64(42), LValue);

    LPublisher.Update(100);
    Check(LPublisher.Read(LValue), 'Should read after update');
    CheckEqual(Int64(100), LValue);
  finally
    LPublisher.Free;
  end;
end;

procedure TestRcuPublisherMultipleUpdates;
var
  LPublisher: TIntPublisher;
  LValue: Int64;
  LI: Integer;
begin
  LPublisher := TIntPublisher.Create(0);
  try
    for LI := 1 to 10 do
      LPublisher.Update(LI);

    Check(LPublisher.Read(LValue), 'Should read');
    CheckEqual(Int64(10), LValue);
  finally
    LPublisher.Free;
  end;
end;

procedure TestRcuPublisherClose;
var
  LPublisher: TIntPublisher;
  LValue: Int64;
begin
  LPublisher := TIntPublisher.Create(42);
  try
    LPublisher.Close;
    Check(LPublisher.IsClosed, 'Should be closed');
    Check(not LPublisher.Read(LValue), 'Should not read after close');
  finally
    LPublisher.Free;
  end;
end;

procedure TestRcuPublisherDefault;
var
  LPublisher: TIntPublisher;
  LValue: Int64;
begin
  LPublisher := TIntPublisher.Create(0);
  try
    Check(LPublisher.Read(LValue), 'Should read default');
    CheckEqual(Int64(0), LValue);
  finally
    LPublisher.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_rcu ===');
  WriteLn;

  TestRcuDomainBasic;
  WriteLn('  + Domain basic');

  TestRcuDomainClose;
  WriteLn('  + Domain close');

  TestRcuDomainSynchronize;
  WriteLn('  + Domain synchronize');

  TestRcuPublisherBasic;
  WriteLn('  + Publisher basic');

  TestRcuPublisherMultipleUpdates;
  WriteLn('  + Publisher multiple updates');

  TestRcuPublisherClose;
  WriteLn('  + Publisher close');

  TestRcuPublisherDefault;
  WriteLn('  + Publisher default');

  WriteLn;
  WriteLn('All RCU tests passed!');
end.
