unit nextpas.core.reflect.dynarray;

{$I nextpas.core.settings.inc}

interface

function DynArrayGetLength(AArray: Pointer): SizeInt;
procedure DynArrayResize(var AArray: Pointer; ATypeInfo: Pointer; ALen: SizeInt);
procedure DynArrayFree(var AArray: Pointer; ATypeInfo: Pointer);
function DynArrayElementPtr(AArray: Pointer; AIndex: SizeInt;
  AElementSize: SizeUInt): Pointer;

implementation

function DynArrayGetLength(AArray: Pointer): SizeInt;
begin
  if AArray = nil then
    Exit(0);
  Result := System.DynArraySize(AArray);
end;

procedure DynArrayResize(var AArray: Pointer; ATypeInfo: Pointer; ALen: SizeInt);
var
  LLen: SizeInt;
begin
  if (ATypeInfo = nil) or (ALen < 0) then
    Exit;
  LLen := ALen;
  System.DynArraySetLength(AArray, ATypeInfo, 1, @LLen);
end;

procedure DynArrayFree(var AArray: Pointer; ATypeInfo: Pointer);
begin
  if ATypeInfo = nil then
    Exit;
  System.DynArrayClear(AArray, ATypeInfo);
end;

function DynArrayElementPtr(AArray: Pointer; AIndex: SizeInt;
  AElementSize: SizeUInt): Pointer;
begin
  if (AArray = nil) or (AIndex < 0) or (AElementSize = 0) then
    Exit(nil);
  Result := Pointer(PtrUInt(AArray) + PtrUInt(AIndex) * AElementSize);
end;

end.
