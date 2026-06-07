program test_slice_contract;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.collections.slice,
  nextpas.core.testing;

type
  TByteReadOnlySpan = specialize TReadOnlySpan<Byte>;
  TByteReadOnlySpan2 = specialize TReadOnlySpan2<Byte>;
  TExceptionProc = procedure;

var
  T: TTestRunner;

procedure CheckRaisesOutOfRange(const AProc: TExceptionProc; const AName: string);
var
  LCaught: Boolean;
begin
  LCaught := False;
  try
    AProc;
  except
    on E: EOutOfRange do
      LCaught := True;
  end;
  Check(LCaught, AName + ' should raise EOutOfRange');
end;

procedure RaiseSpanSubSpanOffsetLengthOverflow;
var
  LData: Byte;
  LOffset: SizeUInt;
  LCount: SizeUInt;
  LSpan: TByteReadOnlySpan;
begin
  LOffset := MAX_SIZE_UINT - 1;
  LCount := MAX_SIZE_UINT;
  LSpan := TByteReadOnlySpan.FromPointer(@LData, LCount, SizeOf(Byte));
  LSpan.SubSpan(LOffset, 2);
end;

procedure RaiseSpanSubSpanOffsetPastEnd;
var
  LData: array[0..1] of Byte;
  LOffset: SizeUInt;
  LSpan: TByteReadOnlySpan;
begin
  LSpan := TByteReadOnlySpan.FromPointer(@LData[0], 2, SizeOf(Byte));
  LOffset := MAX_SIZE_UINT;
  LSpan.SubSpan(LOffset, 2);
end;

procedure RaiseSpan2SubSpanOffsetLengthOverflow;
var
  LData: array[0..1] of Byte;
  LA: TByteReadOnlySpan;
  LB: TByteReadOnlySpan;
  LOffset: SizeUInt;
  LSpan: TByteReadOnlySpan2;
begin
  LA := TByteReadOnlySpan.FromPointer(@LData[0], 1, SizeOf(Byte));
  LB := TByteReadOnlySpan.FromPointer(@LData[1], 1, SizeOf(Byte));
  LSpan := TByteReadOnlySpan2.FromTwo(LA, LB);
  LOffset := MAX_SIZE_UINT;
  LSpan.SubSpan(LOffset, 2);
end;

procedure TestSpanSubSpanRejectsOverflow;
begin
  CheckRaisesOutOfRange(@RaiseSpanSubSpanOffsetLengthOverflow,
    'TReadOnlySpan.SubSpan offset+length overflow');
  CheckRaisesOutOfRange(@RaiseSpanSubSpanOffsetPastEnd,
    'TReadOnlySpan.SubSpan offset past end');
end;

procedure TestSpan2SubSpanRejectsOverflow;
begin
  CheckRaisesOutOfRange(@RaiseSpan2SubSpanOffsetLengthOverflow,
    'TReadOnlySpan2.SubSpan offset+length overflow');
end;

procedure TestSpan2CountSaturatesOnOverflow;
var
  LData: Byte;
  LA: TByteReadOnlySpan;
  LB: TByteReadOnlySpan;
  LSpan: TByteReadOnlySpan2;
  LMax: SizeUInt;
begin
  LMax := MAX_SIZE_UINT;
  LA := TByteReadOnlySpan.FromPointer(@LData, LMax, SizeOf(Byte));
  LB := TByteReadOnlySpan.FromPointer(@LData, 1, SizeOf(Byte));
  LSpan := TByteReadOnlySpan2.FromTwo(LA, LB);
  Check(LSpan.Count = LMax, 'TReadOnlySpan2.Count should saturate on overflow');
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.slice contract');
  T.Run('span subspan rejects overflow', @TestSpanSubSpanRejectsOverflow);
  T.Run('span2 subspan rejects overflow', @TestSpan2SubSpanRejectsOverflow);
  T.Run('span2 count saturates on overflow', @TestSpan2CountSaturatesOnOverflow);
  T.Summary;
end.
