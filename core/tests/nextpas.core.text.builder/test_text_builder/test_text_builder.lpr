program test_text_builder;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.builder,
  nextpas.core.text.view,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestBasicAppend;
var
  B: TStringBuilder;
begin
  B.Init(16);
  B.AppendChar('H');
  B.AppendStr('ello');
  B.AppendChar(' ');
  B.AppendView(TStringView.Create(PAnsiChar('World'), 5));
  CheckEqual('Hello World', B.ToString, 'basic append');
  CheckEqual(Int64(11), Int64(B.Len), 'len=11');
  B.Done;
end;

procedure TestAppendInt;
var
  B: TStringBuilder;
begin
  B.Init(32);
  B.AppendStr('x=');
  B.AppendInt(42);
  B.AppendStr(', y=');
  B.AppendInt(-100);
  CheckEqual('x=42, y=-100', B.ToString, 'append int');
  B.Done;
end;

procedure TestAppendUInt;
var
  B: TStringBuilder;
begin
  B.Init(32);
  B.AppendUInt(18446744073709551615);
  CheckEqual('18446744073709551615', B.ToString, 'max uint64');
  B.Done;
end;

procedure TestAppendHex;
var
  B: TStringBuilder;
begin
  B.Init(32);
  B.AppendStr('0x');
  B.AppendHex($CAFE, 4);
  CheckEqual('0xcafe', B.ToString, 'hex');
  B.Done;
end;

procedure TestAppendBool;
var
  B: TStringBuilder;
begin
  B.Init(16);
  B.AppendBool(True);
  B.AppendChar(',');
  B.AppendBool(False);
  CheckEqual('true,false', B.ToString, 'bool');
  B.Done;
end;

procedure TestGrow;
var
  B: TStringBuilder;
  I: Integer;
begin
  B.Init(4);
  for I := 1 to 1000 do
    B.AppendChar('x');
  CheckEqual(Int64(1000), Int64(B.Len), 'grew to 1000');
  Check(B.Cap >= 1000, 'cap >= 1000');
  B.Done;
end;

procedure TestClear;
var
  B: TStringBuilder;
begin
  B.Init(32);
  B.AppendStr('hello');
  B.Clear;
  CheckEqual(Int64(0), Int64(B.Len), 'cleared');
  B.AppendStr('world');
  CheckEqual('world', B.ToString, 'reuse after clear');
  B.Done;
end;

procedure TestAsView;
var
  B: TStringBuilder;
  V: TStringView;
begin
  B.Init(32);
  B.AppendStr('test');
  V := B.AsView;
  Check(V.Equals(TStringView.Create(PAnsiChar('test'), 4)), 'as view');
  B.Done;
end;

procedure TestAppendChars;
var
  B: TStringBuilder;
begin
  B.Init(16);
  B.AppendChars('=', 10);
  CheckEqual(Int64(10), Int64(B.Len), 'len=10');
  Check(B.AsView.Equals(TStringView.Create(PAnsiChar('=========='), 10)), 'content');
  B.Done;
end;

procedure TestReserve;
var
  B: TStringBuilder;
begin
  B.Init(8);
  B.Reserve(1024);
  Check(B.Cap >= 1024, 'reserved');
  CheckEqual(Int64(0), Int64(B.Len), 'len still 0');
  B.Done;
end;

begin
  T := TTestRunner.Create('nextpas.core.text.builder');
  T.Run('basic append', @TestBasicAppend);
  T.Run('append int', @TestAppendInt);
  T.Run('append uint', @TestAppendUInt);
  T.Run('append hex', @TestAppendHex);
  T.Run('append bool', @TestAppendBool);
  T.Run('grow', @TestGrow);
  T.Run('clear', @TestClear);
  T.Run('as view', @TestAsView);
  T.Run('append chars', @TestAppendChars);
  T.Run('reserve', @TestReserve);
  T.Summary;
end.
