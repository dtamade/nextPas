{**
 * test_tstring — TString 核心功能测试
 *
 * 覆盖: SizeOf / 零初始化 / SSO / Heap / CoW / Move / SetLength / UTF-8 / 比较 / 泄漏
 *}
{$mode objfpc}{$H+}
program test_tstring;
uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.text.tstring;

var
  T: TTestRunner;

{ helper: 从字面量创建 }
function S(const AStr: AnsiString): TString;
begin
  Result := TString.Create(@AStr[1], SizeUInt(System.Length(AStr)));
end;

{ ===== SizeOf ===== }
procedure TestSizeOf;
begin
  CheckEqual(SizeOf(TString), 24, 'SizeOf(TString) = 24');
  CheckEqual(SizeOf(TStringHeader), 24, 'SizeOf(TStringHeader) = 24');
end;

{ ===== 零初始化 / 空串 ===== }
procedure TestZeroInit;
var
  LS: TString;
begin
  FillChar(LS, SizeOf(LS), 0);
  Check(LS.IsSSO, 'zero-init is SSO');
  Check(LS.IsEmpty, 'zero-init is empty');
  CheckEqual(LS.Len, SizeUInt(0), 'zero-init len=0');
end;

procedure TestEmptyFactory;
var
  LS: TString;
begin
  LS := TString.Empty;
  Check(LS.IsSSO, 'Empty is SSO');
  Check(LS.IsEmpty, 'Empty is empty');
  CheckEqual(LS.Len, SizeUInt(0), 'Empty len=0');
end;

{ ===== SSO ===== }
procedure TestSSOShort;
var
  LS: TString;
begin
  LS := S('hello');
  Check(LS.IsSSO, '5-byte is SSO');
  Check(not LS.IsHeap, '5-byte not heap');
  CheckEqual(LS.Len, SizeUInt(5), 'len=5');
  Check(LS.Data <> nil, 'data not nil');
  CheckEqual(Chr(LS.Data[0]), 'h', 'first char');
  CheckEqual(Chr(LS.Data[4]), 'o', 'last char');
  LS.Done;
end;

procedure TestSSOExactly15;
var
  LS: TString;
begin
  LS := S('123456789012345');
  Check(LS.IsSSO, '15-byte is SSO');
  CheckEqual(LS.Len, SizeUInt(15), 'len=15');
  CheckEqual(StringToFPC(LS), '123456789012345', 'content');
  LS.Done;
end;

procedure TestSSOExactly16;
var
  LS: TString;
begin
  LS := S('1234567890123456');
  Check(LS.IsHeap, '16-byte is heap');
  Check(not LS.IsSSO, '16-byte not SSO');
  CheckEqual(LS.Len, SizeUInt(16), 'len=16');
  CheckEqual(StringToFPC(LS), '1234567890123456', 'content');
  LS.Done;
end;

{ ===== Heap ===== }
procedure TestHeapString;
var
  LS: TString;
  LSrc: AnsiString;
begin
  LSrc := 'this is a longer string that exceeds SSO capacity';
  LS := S(LSrc);
  Check(LS.IsHeap, 'long is heap');
  CheckEqual(LS.Len, SizeUInt(System.Length(LSrc)), 'len');
  CheckEqual(StringToFPC(LS), LSrc, 'content');
  LS.Done;
end;

{ ===== Fini ===== }
procedure TestFiniSSO;
var
  LS: TString;
begin
  LS := S('test');
  LS.Done;
  Check(LS.IsEmpty, 'Done SSO is empty');
end;

procedure TestFiniHeap;
var
  LS: TString;
begin
  LS := S('heap string for fini test - longer than 15 bytes');
  LS.Done;
  Check(LS.IsEmpty, 'Done heap is empty');
end;

{ ===== CoW Assign ===== }
procedure TestAssignSSO;
var
  LA, LB: TString;
begin
  LA := S('hello');
  StringAssign(LB, LA);
  Check(LB.IsSSO, 'assigned SSO is SSO');
  CheckEqual(LB.Len, SizeUInt(5), 'assigned len=5');
  CheckEqual(StringToFPC(LB), 'hello', 'assigned content');
  LA.Done;
  CheckEqual(StringToFPC(LB), 'hello', 'LB survives LA.Done');
  LB.Done;
end;

procedure TestAssignHeap;
var
  LA, LB: TString;
  LSrc: AnsiString;
begin
  LSrc := 'heap string for cow test - longer than 15';
  LA := S(LSrc);
  StringAssign(LB, LA);
  Check(LB.IsHeap, 'assigned heap is heap');
  CheckEqual(LA.RefCount, 2, 'LA refcount=2');
  CheckEqual(LB.RefCount, 2, 'LB refcount=2');
  CheckEqual(StringToFPC(LB), LSrc, 'assigned content');
  LA.Done;
  CheckEqual(LB.RefCount, 1, 'LB refcount=1 after LA.Done');
  CheckEqual(StringToFPC(LB), LSrc, 'LB content survives');
  LB.Done;
end;

procedure TestAssignMixed1;
var
  LSSO, LHeap: TString;
  LSrc: AnsiString;
begin
  LSrc := 'long heap string for mixed test scenario';
  LSSO := S('hi');
  LHeap := S(LSrc);
  StringAssign(LSSO, LHeap);
  Check(LSSO.IsHeap, 'SSO assigned from heap is now heap');
  CheckEqual(StringToFPC(LSSO), LSrc, 'content');
  LHeap.Done;
  CheckEqual(LSSO.RefCount, 1, 'refcount=1 after source done');
  LSSO.Done;
end;

procedure TestAssignMixed2;
var
  LHeap, LSSO: TString;
begin
  LHeap := S('long heap string for mixed2 test');
  LSSO := S('ab');
  StringAssign(LHeap, LSSO);
  Check(LHeap.IsSSO, 'heap assigned from SSO is now SSO');
  CheckEqual(StringToFPC(LHeap), 'ab', 'content');
  LSSO.Done;
  Check(LHeap.IsSSO, 'still SSO after source done');
  LHeap.Done;
end;

{ ===== CoW refcount ===== }
procedure TestCoWRefcount;
var
  LA, LB, LC: TString;
  LSrc: AnsiString;
begin
  LSrc := 'shared cow string that is long enough for heap path';
  LA := S(LSrc);
  StringAssign(LB, LA);
  StringAssign(LC, LA);
  CheckEqual(LA.RefCount, 3, 'refcount=3');
  LA.Done;
  CheckEqual(LB.RefCount, 2, 'refcount=2');
  LB.Done;
  CheckEqual(LC.RefCount, 1, 'refcount=1');
  LC.Done;
end;

procedure TestCoWSelfAssign;
var
  LS: TString;
  LSrc: AnsiString;
begin
  LSrc := 'self assign test string for heap path verification';
  LS := S(LSrc);
  StringAssign(LS, LS);
  Check(LS.IsHeap, 'still heap after self-assign');
  CheckEqual(LS.Len, SizeUInt(System.Length(LSrc)), 'len unchanged');
  CheckEqual(StringToFPC(LS), LSrc, 'content unchanged');
  LS.Done;
end;

procedure TestCoWUnique;
var
  LS: TString;
begin
  LS := S('unique string test for refcount one path');
  CheckEqual(LS.RefCount, 1, 'refcount=1');
  StringSetLength(LS, 6);
  Check(LS.IsHeap, 'still heap after setlength');
  CheckEqual(LS.Len, SizeUInt(6), 'len=6');
  CheckEqual(StringToFPC(LS), 'unique', 'content truncated');
  LS.Done;
end;

procedure TestCoWCopyOnWrite;
var
  LA, LB: TString;
  LSrc: AnsiString;
begin
  LSrc := 'cow copy on write test - longer than 15 bytes';
  LA := S(LSrc);
  StringAssign(LB, LA);
  CheckEqual(LA.RefCount, 2, 'shared refcount=2');
  LA.Done;
  CheckEqual(LB.RefCount, 1, 'LB independent');
  CheckEqual(StringToFPC(LB), LSrc, 'LB content intact');
  LB.Done;
end;

procedure TestAssignReplacesOld;
var
  LA, LB: TString;
begin
  LA := S('old value that is long enough for heap');
  LB := S('new value that is long enough for heap');
  CheckEqual(LA.RefCount, 1, 'LA refcount=1');
  StringAssign(LA, LB);
  CheckEqual(LA.RefCount, 2, 'LA now shares with LB');
  CheckEqual(StringToFPC(LA), 'new value that is long enough for heap', 'new content');
  LA.Done;
  LB.Done;
end;

{ ===== Move ===== }
procedure TestMoveSSO;
var
  LA, LB: TString;
begin
  LA := S('move');
  StringMove(LB, LA);
  Check(LA.IsEmpty, 'source cleared after move');
  Check(LB.IsSSO, 'dest is SSO');
  CheckEqual(StringToFPC(LB), 'move', 'content moved');
  LB.Done;
end;

procedure TestMoveHeap;
var
  LA, LB: TString;
  LSrc: AnsiString;
begin
  LSrc := 'heap string for move test - longer than 15 bytes here';
  LA := S(LSrc);
  CheckEqual(LA.RefCount, 1, 'refcount=1 before move');
  StringMove(LB, LA);
  Check(LA.IsEmpty, 'source cleared');
  Check(LB.IsHeap, 'dest is heap');
  CheckEqual(LB.RefCount, 1, 'refcount transferred (not bumped)');
  CheckEqual(StringToFPC(LB), LSrc, 'content moved');
  LB.Done;
end;

{ ===== SetLength ===== }
procedure TestSetLengthSSO;
var
  LS: TString;
begin
  LS := S('hello');
  StringSetLength(LS, 3);
  Check(LS.IsSSO, 'still SSO after shorten');
  CheckEqual(LS.Len, SizeUInt(3), 'len=3');
  CheckEqual(StringToFPC(LS), 'hel', 'content truncated');
  LS.Done;
end;

procedure TestSetLengthPromote;
var
  LS: TString;
begin
  LS := S('hi');
  Check(LS.IsSSO, 'starts SSO');
  StringSetLength(LS, 20);
  Check(LS.IsHeap, 'promoted to heap');
  CheckEqual(LS.Len, SizeUInt(20), 'len=20');
  Check(LS.Data[0] = Byte('h'), 'first byte preserved');
  Check(LS.Data[1] = Byte('i'), 'second byte preserved');
  LS.Done;
end;

{ ===== UTF-8 ===== }
procedure TestUTF8Chinese;
var
  LS: TString;
  LSrc: AnsiString;
begin
  LSrc := '你好世界Hi'; { 6+6+2 = 14 bytes }
  LS := S(LSrc);
  Check(LS.IsSSO, '14-byte chinese is SSO');
  CheckEqual(LS.Len, SizeUInt(14), 'len=14');
  CheckEqual(StringToFPC(LS), LSrc, 'UTF-8 roundtrip');
  LS.Done;
end;

procedure TestUTF8Long;
var
  LS: TString;
  LSrc: AnsiString;
begin
  LSrc := '这是一段较长的中文字符串用于测试堆分配路径的UTF-8透传';
  LS := S(LSrc);
  Check(LS.IsHeap, 'long chinese is heap');
  CheckEqual(LS.Len, SizeUInt(System.Length(LSrc)), 'len');
  CheckEqual(StringToFPC(LS), LSrc, 'UTF-8 roundtrip heap');
  LS.Done;
end;

{ ===== Null terminator ===== }
procedure TestNullTerminator;
var
  LS: TString;
begin
  LS := S('null term test that is longer than 15 bytes for heap');
  Check(LS.Data[LS.Len] = 0, 'heap null terminator');
  LS.Done;
  LS := S('short');
  Check(LS.Data[LS.Len] = 0, 'SSO null terminator');
  LS.Done;
end;

{ ===== Create ===== }
procedure TestStringCreate;
var
  LS: TString;
  LA: AnsiString;
begin
  LA := 'create';
  LS := TString.Create(@LA[1], 6);
  Check(LS.IsSSO, 'created SSO');
  CheckEqual(StringToFPC(LS), 'create', 'content');
  LS.Done;
end;

procedure TestStringCreateZero;
var
  LS: TString;
begin
  LS := TString.Create(nil, 0);
  Check(LS.IsEmpty, 'create nil,0 is empty');
  LS.Done;
end;

{ ===== FPC roundtrip ===== }
procedure TestFPCRoundtrip;
var
  LS: TString;
  LFPC: string;
  LSrc: AnsiString;
begin
  LSrc := 'FPC roundtrip test that is longer than SSO capacity limit';
  LS := StringFromFPC(LSrc);
  Check(LS.IsHeap, 'from FPC is heap');
  LFPC := StringToFPC(LS);
  CheckEqual(LFPC, LSrc, 'roundtrip content');
  LS.Done;
end;

{ ===== Compare ===== }
procedure TestCompareEqual;
var
  LA, LB, LC: TString;
begin
  LA := S('hello');
  LB := S('hello');
  LC := S('world');
  Check(LA.Equals(LB), 'hello = hello');
  Check(not LA.Equals(LC), 'hello <> world');
  Check(StringEqual(LA, LB), 'StringEqual hello=hello');
  Check(StringCompare(LA, LB) = 0, 'Compare hello=hello');
  Check(StringCompare(LA, LC) < 0, 'Compare hello<world');
  Check(StringCompare(LC, LA) > 0, 'Compare world>hello');
  LA.Done;
  LB.Done;
  LC.Done;
end;

{ ===== 主程序 ===== }
begin
  T := TTestRunner.Create('nextpas.core.text.tstring');
  T.Run('SizeOf', @TestSizeOf);
  T.Run('ZeroInit', @TestZeroInit);
  T.Run('EmptyFactory', @TestEmptyFactory);
  T.Run('SSOShort', @TestSSOShort);
  T.Run('SSOExactly15', @TestSSOExactly15);
  T.Run('SSOExactly16', @TestSSOExactly16);
  T.Run('HeapString', @TestHeapString);
  T.Run('FiniSSO', @TestFiniSSO);
  T.Run('FiniHeap', @TestFiniHeap);
  T.Run('AssignSSO', @TestAssignSSO);
  T.Run('AssignHeap', @TestAssignHeap);
  T.Run('AssignMixed1', @TestAssignMixed1);
  T.Run('AssignMixed2', @TestAssignMixed2);
  T.Run('CoWRefcount', @TestCoWRefcount);
  T.Run('CoWSelfAssign', @TestCoWSelfAssign);
  T.Run('CoWUnique', @TestCoWUnique);
  T.Run('CoWCopyOnWrite', @TestCoWCopyOnWrite);
  T.Run('AssignReplacesOld', @TestAssignReplacesOld);
  T.Run('MoveSSO', @TestMoveSSO);
  T.Run('MoveHeap', @TestMoveHeap);
  T.Run('SetLengthSSO', @TestSetLengthSSO);
  T.Run('SetLengthPromote', @TestSetLengthPromote);
  T.Run('UTF8Chinese', @TestUTF8Chinese);
  T.Run('UTF8Long', @TestUTF8Long);
  T.Run('NullTerminator', @TestNullTerminator);
  T.Run('StringCreate', @TestStringCreate);
  T.Run('StringCreateZero', @TestStringCreateZero);
  T.Run('FPCRoundtrip', @TestFPCRoundtrip);
  T.Run('CompareEqual', @TestCompareEqual);
  T.Summary;
end.
