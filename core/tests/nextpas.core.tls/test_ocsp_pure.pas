program test_ocsp_pure;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.time,
  nextpas.core.tls.ocsp.pure;

var
  TestsPassed, TestsFailed: Integer;

procedure Check(const ATestName: string; ACondition: Boolean);
begin
  if ACondition then
  begin
    WriteLn('[PASS] ', ATestName);
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('[FAIL] ', ATestName);
    Inc(TestsFailed);
  end;
end;

procedure TestTryParseOCSPResponseUtcProducedAt;
const
  OCSPSuccessfulWithBody: array[0..6] of Byte = (
    $30, $05,
    $0A, $01, $00,
    $A0, $00
  );
var
  LData: TBytes;
  LResponse: TOCSPBasicResponse;
  LError: string;
  LUtcNow: TDateTime;
begin
  WriteLn;
  WriteLn('=== TryParseOCSPResponse UTC 语义测试 ===');

  SetLength(LData, Length(OCSPSuccessfulWithBody));
  Move(OCSPSuccessfulWithBody[0], LData[0], Length(OCSPSuccessfulWithBody));

  Check('TryParseOCSPResponse 成功',
    TryParseOCSPResponse(LData, LResponse, LError));
  Check('Successful 响应状态',
    LResponse.ResponseStatus = orsSuccessful);
  Check('Successful 响应生成占位响应',
    Length(LResponse.Responses) = 1);

  LUtcNow := DateTimeUtcNow;
  Check('ProducedAt 使用 UTC 时间基准',
    (LResponse.ProducedAt >= DateTimeAddSeconds(LUtcNow, -5)) and
    (LResponse.ProducedAt <= DateTimeAddSeconds(LUtcNow, 5)));
end;

procedure TestIsOCSPResponseFreshUtcSemantics;
var
  LResponse: TOCSPBasicResponse;
begin
  WriteLn;
  WriteLn('=== IsOCSPResponseFresh UTC 语义测试 ===');

  FillChar(LResponse, SizeOf(LResponse), 0);
  SetLength(LResponse.Responses, 1);
  LResponse.Responses[0].HasNextUpdate := True;
  LResponse.Responses[0].NextUpdate := DateTimeAddSeconds(DateTimeUtcNow, 7200);

  Check('UTC future nextUpdate 应保持 fresh',
    IsOCSPResponseFresh(LResponse));

  LResponse.Responses[0].NextUpdate := DateTimeAddSeconds(DateTimeUtcNow, -5);
  Check('UTC past nextUpdate 应判定过期',
    not IsOCSPResponseFresh(LResponse));
end;

begin
  WriteLn('========================================');
  WriteLn('nextpas.core.tls.ocsp.pure 单元测试');
  WriteLn('========================================');

  TestsPassed := 0;
  TestsFailed := 0;

  TestTryParseOCSPResponseUtcProducedAt;
  TestIsOCSPResponseFreshUtcSemantics;

  WriteLn;
  WriteLn('========================================');
  WriteLn('测试结果: ', TestsPassed, ' 通过, ', TestsFailed, ' 失败');
  WriteLn('========================================');

  if TestsFailed > 0 then
    Halt(1);
end.
