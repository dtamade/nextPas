program test_net_error_classify;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.net.errors,
  nextpas.core.platform.error;

var
  T: TTestSuite;

procedure TestOkAndAbs;
var
  L: TNetErrorClass;
begin
  L := ClassifyNetError(0);
  Check(L.IsOK, '0 is ok');
  CheckEqual(Int64(Ord(nekOK)), Int64(Ord(L.Kind)), 'kind ok');
  L := ClassifyNetError(-PLATFORM_ERR_TIMEDOUT);
  Check(L.Timeout, 'neg timeout flag');
  CheckEqual(Int64(PLATFORM_ERR_TIMEDOUT), Int64(L.Code), 'abs code');
end;

procedure TestTimeoutCanceledRefused;
var
  L: TNetErrorClass;
begin
  L := ClassifyNetError(-110);
  CheckEqual(Int64(Ord(nekTimeout)), Int64(Ord(L.Kind)), 'timeout kind');
  Check(L.Timeout, 'timeout flag');
  Check(not L.Canceled, 'not canceled');

  L := ClassifyNetError(-NET_ERR_CANCELED);
  CheckEqual(Int64(Ord(nekCanceled)), Int64(Ord(L.Kind)), 'canceled kind');
  Check(L.Canceled, 'canceled flag');
  Check(not L.Timeout, 'not timeout');

  L := ClassifyNetError(-PLATFORM_ERR_CONNREFUSED);
  CheckEqual(Int64(Ord(nekRefused)), Int64(Ord(L.Kind)), 'refused kind');
  Check(not L.Timeout, 'refused not timeout');
end;

procedure TestResetTemporary;
var
  L: TNetErrorClass;
begin
  L := ClassifyNetError(PLATFORM_ERR_CONNRESET);
  CheckEqual(Int64(Ord(nekReset)), Int64(Ord(L.Kind)), 'reset');
  L := ClassifyNetError(PLATFORM_ERR_AGAIN);
  CheckEqual(Int64(Ord(nekTemporary)), Int64(Ord(L.Kind)), 'again temporary');
  Check(L.Temporary, 'temporary flag');
end;

procedure TestKindNames;
begin
  Check(NetErrorKindName(nekTimeout) = 'timeout', 'name timeout');
  Check(NetErrorKindName(nekCanceled) = 'canceled', 'name canceled');
  Check(NetErrorKindName(nekOK) = 'ok', 'name ok');
end;

procedure TestDialConventionRoundtrip;
var
  L: TNetErrorClass;
begin
  { Codes emitted by AsyncTcpDial FinishFail paths. }
  L := ClassifyNetError(-110);
  Check(L.Timeout, 'dial ETIMEDOUT');
  L := ClassifyNetError(-125);
  Check(L.Canceled, 'dial ECANCELED');
  L := ClassifyNetError(-111);
  CheckEqual(Int64(Ord(nekRefused)), Int64(Ord(L.Kind)), 'dial ECONNREFUSED');
end;

begin
  T := TTestSuite.Create('net_error_classify');
  T.Test('OkAndAbs', @TestOkAndAbs);
  T.Test('TimeoutCanceledRefused', @TestTimeoutCanceledRefused);
  T.Test('ResetTemporary', @TestResetTemporary);
  T.Test('KindNames', @TestKindNames);
  T.Test('DialConventionRoundtrip', @TestDialConventionRoundtrip);
  if not T.Run then
    Halt(1);
end.
