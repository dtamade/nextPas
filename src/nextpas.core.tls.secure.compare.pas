{
  nextpas.core.tls.secure.compare - Lightweight constant-time compare helpers

  Purpose:
    Provide the small compare surface needed by WinSSL and other units
    without depending on the heavier OpenSSL-backed secure storage module.
}

unit nextpas.core.tls.secure.compare;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, Classes,
  nextpas.core.tls.crypto.constant_time;

function SecureCompare(const A, B: TBytes): Boolean;
function SecureCompareStrings(const A, B: string): Boolean;

implementation

function SecureCompare(const A, B: TBytes): Boolean;
begin
  Result := TConstantTime.CompareBytes(A, B) = 1;
end;

function SecureCompareStrings(const A, B: string): Boolean;
begin
  Result := TConstantTime.CompareStrings(A, B);
end;

end.
