{**
 * @desc Memory operations for the nextPas system kernel.
 *
 * Defines FreeAndNil, ZeroMem, Supports, etc.
 * Depends on base.inc, cls.inc.
 *
 * NOTE: This file is only included under nextPas.
 * For FPC, functions are provided by nextpas.core.base.utils.
 *}

{ Memory utility functions }
procedure FreeAndNil(var Obj);
function Supports(const Intf: IUnknown; const IID: TGUID; out Obj): Boolean; overload;
function Supports(Obj: TObject; const IID: TGUID; out Intf): Boolean; overload;
function Supports(const Intf: IUnknown; const IID: TGUID): Boolean; overload;
function Supports(Obj: TObject; const IID: TGUID): Boolean; overload;

{ Memory fill/copy/compare }
procedure ZeroMem(P: Pointer; Size: SizeInt);
procedure FillMem(P: Pointer; Size: SizeInt; Value: Byte);
procedure CopyMem(Dest, Src: Pointer; Size: SizeInt);
function CompareMem(P1, P2: Pointer; Size: SizeInt): Boolean;

implementation

{ FreeAndNil implementation }
procedure FreeAndNil(var Obj);
var
  LTemp: TObject;
begin
  LTemp := TObject(Obj);
  Pointer(Obj) := nil;
  LTemp.Free;
end;

{ Supports implementation }
function Supports(const Intf: IUnknown; const IID: TGUID; out Obj): Boolean;
begin
  if Intf <> nil then
    Result := Intf.QueryInterface(IID, Obj) = 0
  else
  begin
    Pointer(Obj) := nil;
    Result := False;
  end;
end;

function Supports(Obj: TObject; const IID: TGUID; out Intf): Boolean;
begin
  if Obj <> nil then
    Result := Obj.GetInterface(IID, Intf)
  else
  begin
    Pointer(Intf) := nil;
    Result := False;
  end;
end;

function Supports(const Intf: IUnknown; const IID: TGUID): Boolean;
var
  LTemp: Pointer;
begin
  Result := Supports(Intf, IID, LTemp);
end;

function Supports(Obj: TObject; const IID: TGUID): Boolean;
var
  LTemp: Pointer;
begin
  Result := Supports(Obj, IID, LTemp);
end;

{ Memory operations implementation }
procedure ZeroMem(P: Pointer; Size: SizeInt);
begin
  FillChar(P^, Size, 0);
end;

procedure FillMem(P: Pointer; Size: SizeInt; Value: Byte);
begin
  FillChar(P^, Size, Value);
end;

procedure CopyMem(Dest, Src: Pointer; Size: SizeInt);
begin
  Move(Src^, Dest^, Size);
end;

function CompareMem(P1, P2: Pointer; Size: SizeInt): Boolean;
begin
  Result := System.CompareMem(P1, P2, Size);
end;
