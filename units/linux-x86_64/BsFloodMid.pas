unit BsFloodMid;

{$mode objfpc}{$H+}

{ Body-seed budget flood mid: depends on leaf; own dead free funcs; live entry. }

interface

uses
  BsFloodLeaf;

function LiveMid: Integer;
function DeadM01: Integer;
function DeadM02: Integer;
function DeadM03: Integer;
function DeadM04: Integer;
function DeadM05: Integer;
function DeadM06: Integer;
function DeadM07: Integer;
function DeadM08: Integer;
function DeadM09: Integer;
function DeadM10: Integer;
function DeadM11: Integer;
function DeadM12: Integer;
function DeadM13: Integer;
function DeadM14: Integer;
function DeadM15: Integer;
function DeadM16: Integer;
function DeadM17: Integer;
function DeadM18: Integer;
function DeadM19: Integer;
function DeadM20: Integer;
function DeadM21: Integer;
function DeadM22: Integer;
function DeadM23: Integer;
function DeadM24: Integer;
function DeadM25: Integer;
function DeadM26: Integer;
function DeadM27: Integer;
function DeadM28: Integer;
function DeadM29: Integer;
function DeadM30: Integer;
function DeadM31: Integer;
function DeadM32: Integer;
function DeadM33: Integer;
function DeadM34: Integer;
function DeadM35: Integer;
function DeadM36: Integer;
function DeadM37: Integer;
function DeadM38: Integer;
function DeadM39: Integer;
function DeadM40: Integer;
function DeadM41: Integer;
function DeadM42: Integer;
function DeadM43: Integer;
function DeadM44: Integer;
function DeadM45: Integer;
function DeadM46: Integer;
function DeadM47: Integer;
function DeadM48: Integer;
function DeadM49: Integer;
function DeadM50: Integer;
function DeadM51: Integer;
function DeadM52: Integer;
function DeadM53: Integer;
function DeadM54: Integer;
function DeadM55: Integer;
function DeadM56: Integer;
function DeadM57: Integer;
function DeadM58: Integer;
function DeadM59: Integer;
function DeadM60: Integer;

implementation

function LiveMid: Integer;
begin
  { Passthrough only — avoid i8/i64 add mix in current lowerer. }
  Result := LiveLeaf;
end;

function DeadM01: Integer;
begin
  Result := DeadM02;
end;

function DeadM02: Integer;
begin
  Result := DeadM03;
end;

function DeadM03: Integer;
begin
  Result := DeadM04;
end;

function DeadM04: Integer;
begin
  Result := DeadM05;
end;

function DeadM05: Integer;
begin
  Result := DeadM06;
end;

function DeadM06: Integer;
begin
  Result := DeadM07;
end;

function DeadM07: Integer;
begin
  Result := DeadM08;
end;

function DeadM08: Integer;
begin
  Result := DeadM09;
end;

function DeadM09: Integer;
begin
  Result := DeadM10;
end;

function DeadM10: Integer;
begin
  Result := DeadM11;
end;

function DeadM11: Integer;
begin
  Result := DeadM12;
end;

function DeadM12: Integer;
begin
  Result := DeadM13;
end;

function DeadM13: Integer;
begin
  Result := DeadM14;
end;

function DeadM14: Integer;
begin
  Result := DeadM15;
end;

function DeadM15: Integer;
begin
  Result := DeadM16;
end;

function DeadM16: Integer;
begin
  Result := DeadM17;
end;

function DeadM17: Integer;
begin
  Result := DeadM18;
end;

function DeadM18: Integer;
begin
  Result := DeadM19;
end;

function DeadM19: Integer;
begin
  Result := DeadM20;
end;

function DeadM20: Integer;
begin
  Result := DeadM21;
end;

function DeadM21: Integer;
begin
  Result := DeadM22;
end;

function DeadM22: Integer;
begin
  Result := DeadM23;
end;

function DeadM23: Integer;
begin
  Result := DeadM24;
end;

function DeadM24: Integer;
begin
  Result := DeadM25;
end;

function DeadM25: Integer;
begin
  Result := DeadM26;
end;

function DeadM26: Integer;
begin
  Result := DeadM27;
end;

function DeadM27: Integer;
begin
  Result := DeadM28;
end;

function DeadM28: Integer;
begin
  Result := DeadM29;
end;

function DeadM29: Integer;
begin
  Result := DeadM30;
end;

function DeadM30: Integer;
begin
  Result := DeadM31;
end;

function DeadM31: Integer;
begin
  Result := DeadM32;
end;

function DeadM32: Integer;
begin
  Result := DeadM33;
end;

function DeadM33: Integer;
begin
  Result := DeadM34;
end;

function DeadM34: Integer;
begin
  Result := DeadM35;
end;

function DeadM35: Integer;
begin
  Result := DeadM36;
end;

function DeadM36: Integer;
begin
  Result := DeadM37;
end;

function DeadM37: Integer;
begin
  Result := DeadM38;
end;

function DeadM38: Integer;
begin
  Result := DeadM39;
end;

function DeadM39: Integer;
begin
  Result := DeadM40;
end;

function DeadM40: Integer;
begin
  Result := DeadM41;
end;

function DeadM41: Integer;
begin
  Result := DeadM42;
end;

function DeadM42: Integer;
begin
  Result := DeadM43;
end;

function DeadM43: Integer;
begin
  Result := DeadM44;
end;

function DeadM44: Integer;
begin
  Result := DeadM45;
end;

function DeadM45: Integer;
begin
  Result := DeadM46;
end;

function DeadM46: Integer;
begin
  Result := DeadM47;
end;

function DeadM47: Integer;
begin
  Result := DeadM48;
end;

function DeadM48: Integer;
begin
  Result := DeadM49;
end;

function DeadM49: Integer;
begin
  Result := DeadM50;
end;

function DeadM50: Integer;
begin
  Result := DeadM51;
end;

function DeadM51: Integer;
begin
  Result := DeadM52;
end;

function DeadM52: Integer;
begin
  Result := DeadM53;
end;

function DeadM53: Integer;
begin
  Result := DeadM54;
end;

function DeadM54: Integer;
begin
  Result := DeadM55;
end;

function DeadM55: Integer;
begin
  Result := DeadM56;
end;

function DeadM56: Integer;
begin
  Result := DeadM57;
end;

function DeadM57: Integer;
begin
  Result := DeadM58;
end;

function DeadM58: Integer;
begin
  Result := DeadM59;
end;

function DeadM59: Integer;
begin
  Result := DeadM60;
end;

function DeadM60: Integer;
begin
  Result := DeadM01;
end;

end.
