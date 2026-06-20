unit Variants;

{$mode objfpc}{$H+}

interface

type
  TVarType = Word;
  Variant = type Pointer;

function VarIsNull(const V: Variant): Boolean;
function VarIsEmpty(const V: Variant): Boolean;

implementation

function VarIsNull(const V: Variant): Boolean;
begin Result := True; end;

function VarIsEmpty(const V: Variant): Boolean;
begin Result := True; end;

end.
