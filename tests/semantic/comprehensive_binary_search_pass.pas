{ objfpc}{+}
program comprehensive_binary_search_pass;
function BinarySearch(const Arr: array of Integer; Target: Integer): Integer;
var Lo,Hi,Mid: Integer;
begin
  Lo:=0; Hi:=High(Arr);
  while Lo<=Hi do begin
    Mid:=(Lo+Hi) div 2;
    if Arr[Mid]=Target then Exit(Mid);
    if Arr[Mid]<Target then Lo:=Mid+1 else Hi:=Mid-1;
  end;
  BinarySearch:=-1;
end;
var A: array[0..4] of Integer; R: Integer;
begin
  A[0]:=10; A[1]:=20; A[2]:=30; A[3]:=40; A[4]:=50;
  R:=BinarySearch(A,30); if R<>2 then Halt(1);
  R:=BinarySearch(A,10); if R<>0 then Halt(2);
  R:=BinarySearch(A,50); if R<>4 then Halt(3);
  R:=BinarySearch(A,99); if R<>-1 then Halt(4);
end.
