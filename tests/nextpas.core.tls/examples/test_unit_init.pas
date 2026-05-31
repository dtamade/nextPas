program test_unit_init;

{$mode objfpc}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

unit TestUnit1;

interface

implementation

initialization
  WriteLn('[TestUnit1] Initialization');

end.

unit TestUnit2;

interface

uses TestUnit1;

implementation

initialization
  WriteLn('[TestUnit2] Initialization');

end.

uses
  TestUnit2;

begin
  WriteLn('Main program');
end.