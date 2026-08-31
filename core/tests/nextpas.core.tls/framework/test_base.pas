unit test_base;

{$mode objfpc}{$H+}

interface

uses
  nextpas.core.system.classes, nextpas.core.system.sysutils, nextpas.core.test;

type
  { TTestBase - 所有单元测试的基类 }
  TTestBase = class(TTestFixture)
  protected
    // Setup - 在每个测试方法前调用
    procedure BeforeEach; override;

    // TearDown - 在每个测试方法后调用
    procedure AfterEach; override;

    // 辅助方法：比较字节数组
    procedure AssertBytesEqual(const Expected, Actual: array of Byte; const Msg: string = '');

    // 辅助方法：比较字节数组（带长度）
    procedure AssertBytesEqualLen(const Expected, Actual: PByte; Len: Integer; const Msg: string = '');

    // 辅助方法：断言异常
    procedure AssertException(AExceptionClass: ExceptClass; AMethod: TTestProc; const Msg: string = '');

    // 辅助方法：将字节数组转为十六进制字符串
    function BytesToHex(const Bytes: array of Byte): string; overload;
    function BytesToHex(Bytes: PByte; Len: Integer): string; overload;
  end;

implementation

{ TTestBase }

procedure TTestBase.BeforeEach;
begin
  inherited BeforeEach;
  // 子类可以覆盖此方法进行自定义初始化
end;

procedure TTestBase.AfterEach;
begin
  // 子类可以覆盖此方法进行自定义清理
  inherited AfterEach;
end;

procedure TTestBase.AssertBytesEqual(const Expected, Actual: array of Byte; const Msg: string);
var
  i: Integer;
  ErrorMsg: string;
begin
  if Length(Expected) <> Length(Actual) then
  begin
    ErrorMsg := Format('Byte array length mismatch: Expected %d, got %d',
                      [Length(Expected), Length(Actual)]);
    if Msg <> '' then
      ErrorMsg := Msg + ': ' + ErrorMsg;
    Fail(ErrorMsg);
    Exit;
  end;

  for i := 0 to High(Expected) do
  begin
    if Expected[i] <> Actual[i] then
    begin
      ErrorMsg := Format('Byte mismatch at position %d: Expected $%s, got $%s',
                        [i, IntToHex(Expected[i], 2), IntToHex(Actual[i], 2)]);
      if Msg <> '' then
        ErrorMsg := Msg + ': ' + ErrorMsg;
      ErrorMsg := ErrorMsg + LineEnding +
                  'Expected: ' + BytesToHex(Expected) + LineEnding +
                  'Actual:   ' + BytesToHex(Actual);
      Fail(ErrorMsg);
      Exit;
    end;
  end;
end;

procedure TTestBase.AssertBytesEqualLen(const Expected, Actual: PByte; Len: Integer; const Msg: string);
var
  i: Integer;
  ErrorMsg: string;
  ExpPtr, ActPtr: PByte;
begin
  ExpPtr := Expected;
  ActPtr := Actual;

  for i := 0 to Len - 1 do
  begin
    if ExpPtr^ <> ActPtr^ then
    begin
      ErrorMsg := Format('Byte mismatch at position %d: Expected $%s, got $%s',
                        [i, IntToHex(ExpPtr^, 2), IntToHex(ActPtr^, 2)]);
      if Msg <> '' then
        ErrorMsg := Msg + ': ' + ErrorMsg;
      Fail(ErrorMsg);
      Exit;
    end;
    Inc(ExpPtr);
    Inc(ActPtr);
  end;
end;

procedure TTestBase.AssertException(AExceptionClass: ExceptClass; AMethod: TTestProc; const Msg: string);
var
  ErrorMsg: string;
begin
  try
    AMethod();
    ErrorMsg := Format('Expected exception %s was not raised', [AExceptionClass.ClassName]);
    if Msg <> '' then
      ErrorMsg := Msg + ': ' + ErrorMsg;
    Fail(ErrorMsg);
  except
    on E: Exception do
    begin
      if not (E is AExceptionClass) then
      begin
        ErrorMsg := Format('Expected exception %s, but got %s: %s',
                          [AExceptionClass.ClassName, E.ClassName, E.Message]);
        if Msg <> '' then
          ErrorMsg := Msg + ': ' + ErrorMsg;
        Fail(ErrorMsg);
      end;
    end;
  end;
end;

function TTestBase.BytesToHex(const Bytes: array of Byte): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to High(Bytes) do
    Result := Result + IntToHex(Bytes[i], 2);
end;

function TTestBase.BytesToHex(Bytes: PByte; Len: Integer): string;
var
  i: Integer;
  P: PByte;
begin
  Result := '';
  P := Bytes;
  for i := 0 to Len - 1 do
  begin
    Result := Result + IntToHex(P^, 2);
    Inc(P);
  end;
end;

end.
