program run_ocsp_tests;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Classes, SysUtils, CustApp,
  fpcunit, testreport, testregistry,
  // OCSP Stapling 单元测试
  test_ocsp_stapling;

type
  { TTestRunner }
  TTestRunner = class(TCustomApplication)
  protected
    procedure DoRun; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
  end;

{ TTestRunner }

procedure TTestRunner.DoRun;
var
  TestResult: TTestResult;
  ResultsWriter: TPlainResultsWriter;
  TestSuite: TTest;
begin
  WriteLn('=======================================');
  WriteLn('  OCSP Stapling 单元测试运行器');
  WriteLn('=======================================');
  WriteLn;
  
  // 创建测试结果对象
  TestResult := TTestResult.Create;
  try
    // 创建结果输出器
    ResultsWriter := TPlainResultsWriter.Create;
    try
      TestResult.AddListener(ResultsWriter);
      
      // 获取所有注册的测试
      TestSuite := GetTestRegistry;
      
      WriteLn('发现 ', TestSuite.CountTestCases, ' 个测试用例');
      WriteLn;
      
      // 运行所有测试
      WriteLn('开始运行测试...');
      WriteLn;
      TestSuite.Run(TestResult);
      
      WriteLn;
      WriteLn('=======================================');
      WriteLn('  测试结果');
      WriteLn('=======================================');
      WriteLn('运行的测试:     ', TestResult.RunTests);
      WriteLn('通过的测试:     ', TestResult.RunTests - TestResult.NumberOfFailures - TestResult.NumberOfErrors);
      WriteLn('失败的测试:     ', TestResult.NumberOfFailures);
      WriteLn('错误的测试:     ', TestResult.NumberOfErrors);
      WriteLn('跳过的测试:     ', TestResult.NumberOfSkippedTests);
      WriteLn;
      
      // 显示失败的测试
      if TestResult.NumberOfFailures > 0 then
      begin
        WriteLn('失败的测试详情:');
        WriteLn('  (部分测试需要真实的证书和 OCSP 响应数据)');
        WriteLn;
      end;
      
      // 显示错误的测试
      if TestResult.NumberOfErrors > 0 then
      begin
        WriteLn('错误的测试详情:');
        WriteLn('  (部分测试需要真实的证书和 OCSP 响应数据)');
        WriteLn;
      end;
      
      // 计算成功率
      if TestResult.RunTests > 0 then
      begin
        WriteLn('成功率: ', 
                Format('%.1f%%', 
                      [100.0 * (TestResult.RunTests - TestResult.NumberOfFailures - TestResult.NumberOfErrors) / TestResult.RunTests]));
      end;
      
      WriteLn;
      
      // 如果有失败或错误，返回非零退出码
      if (TestResult.NumberOfFailures > 0) or (TestResult.NumberOfErrors > 0) then
        ExitCode := 1
      else
        ExitCode := 0;
        
    finally
      ResultsWriter.Free;
    end;
  finally
    TestResult.Free;
  end;
  
  // 停止程序
  Terminate;
end;

constructor TTestRunner.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  StopOnException := True;
end;

destructor TTestRunner.Destroy;
begin
  inherited Destroy;
end;

var
  Application: TTestRunner;

begin
  Application := TTestRunner.Create(nil);
  try
    Application.Title := 'OCSP Stapling Unit Test Runner';
    Application.Run;
  finally
    Application.Free;
  end;
end.
