unit np_llvm_utils;

{$mode objfpc}{$H+}

interface

function NpBitWidthToLlvmIntType(ABitWidth: LongInt): string;
function NpBitWidthToLlvmType(ABitWidth: LongInt): string; overload;
function NpBitWidthToLlvmType(ABitWidth: LongInt; AIsSigned: Boolean): string; overload;

implementation

uses
  SysUtils;

function NpBitWidthToLlvmIntType(ABitWidth: LongInt): string;
begin
  case ABitWidth of
    1: Result := 'i1';
    8: Result := 'i8';
    16: Result := 'i16';
    32: Result := 'i32';
    64: Result := 'i64';
  else
    Result := 'i' + IntToStr(ABitWidth);
  end;
end;

function NpBitWidthToLlvmType(ABitWidth: LongInt): string;
begin
  case ABitWidth of
    0: Result := 'void';
    1: Result := 'i1';
    8: Result := 'i8';
    16: Result := 'i16';
    32: Result := 'i32';
    64: Result := 'i64';
  else
    Result := 'i' + IntToStr(ABitWidth);
  end;
end;

function NpBitWidthToLlvmType(ABitWidth: LongInt; AIsSigned: Boolean): string;
begin
  Result := NpBitWidthToLlvmType(ABitWidth);
end;

end.
