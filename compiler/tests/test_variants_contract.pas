program test_variants_contract;

{$mode objfpc}{$H+}

uses
  Variants;

var
  EmptyValue: Variant;
  NullValue: Variant;
  LeftValue: Variant;
  RightValue: Variant;
begin
  TVarData(EmptyValue).VType := varEmpty;
  if not VarIsEmpty(EmptyValue) then
    Halt(1);

  TVarData(NullValue).VType := varNull;
  if not VarIsNull(NullValue) then
    Halt(2);

  TVarData(LeftValue).VType := varInteger;
  TVarData(LeftValue).VInteger := 1;
  TVarData(RightValue).VType := varInteger;
  TVarData(RightValue).VInteger := 2;

  if VarCompareValue(LeftValue, RightValue) <> vrLessThan then
    Halt(3);
  if VarCompareValue(RightValue, LeftValue) <> vrGreaterThan then
    Halt(4);

  TVarData(RightValue).VInteger := 1;
  if VarCompareValue(LeftValue, RightValue) <> vrEqual then
    Halt(5);
end.
