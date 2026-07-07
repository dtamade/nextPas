{**
 * @desc Memory operations for the nextPas system kernel.
 *
 * Defines memory management functions (GetMem, FreeMem, ReAllocMem, etc.),
 * memory utilities (FreeAndNil, ZeroMem, FillMem, CopyMem, CompareMem),
 * interface support (Supports), and runtime helpers (Halt, Assert, Assigned).
 *
 * Depends on base.inc, cls.inc, intf.inc.
 *
 * NOTE: This file is only included under nextPas.
 * For FPC, functions are provided by FPC System.
 *}

{ === Memory Management === }

{**
 * Allocate ASize bytes of uninitialized memory.
 * Returns nil if ASize <= 0.
 *}
function GetMem(ASize: SizeInt): Pointer;

{**
 * Free memory previously allocated by GetMem/ReAllocMem/AllocMem.
 * Returns 0 on success, non-zero on error.
 *}
function FreeMem(AP: Pointer): SizeInt;

{**
 * Resize a memory block. If AP is nil, behaves like GetMem.
 * If ASize <= 0, frees the block and returns nil.
 *}
function ReAllocMem(AP: Pointer; ASize: SizeInt): Pointer;

{**
 * Allocate ASize bytes of zero-initialized memory.
 * Returns nil if ASize <= 0.
 *}
function AllocMem(ASize: SizeInt): Pointer;

{**
 * Return the allocated size of memory block AP.
 * Returns 0 if AP is nil.
 *}
function MemSize(AP: Pointer): SizeInt;

{ === Memory Utilities === }

{**
 * Free AObj and set the reference to nil.
 * Safe to call with nil reference.
 *}
procedure FreeAndNil(var AObj); inline;

{**
 * Fill ASize bytes at ADst with zero.
 *}
procedure ZeroMem(ADst: Pointer; ASize: SizeInt); inline;

{**
 * Fill ASize bytes at ADst with AValue.
 *}
procedure FillMem(ADst: Pointer; ASize: SizeInt; AValue: Byte); inline;

{**
 * Copy ASize bytes from ASrc to ADst.
 * Regions must not overlap.
 *}
procedure CopyMem(ADst: Pointer; ASrc: Pointer; ASize: SizeInt); inline;

{**
 * Compare ASize bytes at A and B.
 * Returns True if equal.
 *}
function CompareMem(A, B: Pointer; ASize: SizeInt): Boolean; inline;

{ === Interface Support === }

{**
 * Query interface AIID from AInstance.
 * Returns True and sets AIntf if supported.
 *}
function Supports(const AInstance: TObject; const AIID: TGUID; out AIntf): Boolean; overload;
function Supports(const AInstance: IUnknown; const AIID: TGUID; out AIntf): Boolean; overload;
function Supports(const AInstance: TObject; const AIID: TGUID): Boolean; overload;
function Supports(const AInstance: IUnknown; const AIID: TGUID): Boolean; overload;

{ === Runtime Helpers === }

{**
 * Terminate program with exit code ACode.
 *}
procedure Halt(ACode: LongInt); inline;

{**
 * Terminate program with exit code 0.
 *}
procedure Halt; inline;

{**
 * Runtime error with error code ACode.
 * Terminates the program.
 *}
procedure RunError(ACode: Word); inline;

{**
 * Raise EAssertionFailed if ACondition is False.
 *}
procedure Assert(ACondition: Boolean); overload;
procedure Assert(ACondition: Boolean; const AMsg: string); overload;

{**
 * Check if AP is not nil.
 * Works with pointers, TObject, and IUnknown.
 *}
function Assigned(const AP: Pointer): Boolean; overload; inline;
function Assigned(const AObj: TObject): Boolean; overload; inline;
function Assigned(const AIntf: IUnknown): Boolean; overload; inline;

{ === Variant Utilities === }

{**
 * Variant operation codes for binary operations.
 *}
type
  TVarOp = (
    opAdd, opSubtract, opMultiply, opDivide,
    opIntDivide, opModulus, opShiftLeft, opShiftRight,
    opAnd, opOr, opXor, opCompare,
    opNegate, opNot
  );

{**
 * Return the type code of V.
 * Returns varEmpty if V is unassigned.
 *}
function VarType(const V: Variant): TVarType; inline;

{**
 * Return True if V is Null.
 *}
function VarIsNull(const V: Variant): Boolean; inline;

{**
 * Return True if V is Unassigned (varEmpty).
 *}
function VarIsEmpty(const V: Variant): Boolean; inline;

{**
 * Return True if V is Null or Unassigned.
 *}
function VarIsClear(const V: Variant): Boolean; inline;

implementation

{ === Memory Management === }

function GetMem(ASize: SizeInt): Pointer;
begin
  if ASize > 0 then
    Result := System.GetMem(ASize)
  else
    Result := nil;
end;

function FreeMem(AP: Pointer): SizeInt;
begin
  if AP <> nil then
    Result := System.FreeMem(AP)
  else
    Result := 0;
end;

function ReAllocMem(AP: Pointer; ASize: SizeInt): Pointer;
begin
  if ASize > 0 then
  begin
    if AP <> nil then
      Result := System.ReAllocMem(AP, ASize)
    else
      Result := System.GetMem(ASize);
  end
  else
  begin
    if AP <> nil then
      System.FreeMem(AP);
    Result := nil;
  end;
end;

function AllocMem(ASize: SizeInt): Pointer;
begin
  if ASize > 0 then
  begin
    Result := System.GetMem(ASize);
    if Result <> nil then
      FillChar(Result^, ASize, 0);
  end
  else
    Result := nil;
end;

function MemSize(AP: Pointer): SizeInt;
begin
  if AP <> nil then
    Result := System.MemSize(AP)
  else
    Result := 0;
end;

{ === Memory Utilities === }

procedure FreeAndNil(var AObj);
var
  LTemp: TObject;
begin
  LTemp := TObject(AObj);
  Pointer(AObj) := nil;
  LTemp.Free;
end;

procedure ZeroMem(ADst: Pointer; ASize: SizeInt);
begin
  FillChar(ADst^, ASize, 0);
end;

procedure FillMem(ADst: Pointer; ASize: SizeInt; AValue: Byte);
begin
  FillChar(ADst^, ASize, AValue);
end;

procedure CopyMem(ADst: Pointer; ASrc: Pointer; ASize: SizeInt);
begin
  Move(ASrc^, ADst^, ASize);
end;

function CompareMem(A, B: Pointer; ASize: SizeInt): Boolean;
begin
  Result := System.CompareMem(A, B, ASize);
end;

{ === Interface Support === }

function Supports(const AInstance: TObject; const AIID: TGUID; out AIntf): Boolean;
begin
  if AInstance <> nil then
    Result := AInstance.GetInterface(AIID, AIntf)
  else
  begin
    Pointer(AIntf) := nil;
    Result := False;
  end;
end;

function Supports(const AInstance: IUnknown; const AIID: TGUID; out AIntf): Boolean;
begin
  if AInstance <> nil then
    Result := AInstance.QueryInterface(AIID, AIntf) = 0
  else
  begin
    Pointer(AIntf) := nil;
    Result := False;
  end;
end;

function Supports(const AInstance: TObject; const AIID: TGUID): Boolean;
var
  LTemp: Pointer;
begin
  Result := Supports(AInstance, AIID, LTemp);
end;

function Supports(const AInstance: IUnknown; const AIID: TGUID): Boolean;
var
  LTemp: Pointer;
begin
  Result := Supports(AInstance, AIID, LTemp);
end;

{ === Runtime Helpers === }

procedure Halt(ACode: LongInt);
begin
  System.Halt(ACode);
end;

procedure Halt;
begin
  System.Halt(0);
end;

procedure RunError(ACode: Word);
begin
  System.RunError(ACode);
end;

procedure Assert(ACondition: Boolean);
begin
  if not ACondition then
    raise EAssertionFailed.Create('Assertion failed');
end;

procedure Assert(ACondition: Boolean; const AMsg: string);
begin
  if not ACondition then
    raise EAssertionFailed.Create(AMsg);
end;

function Assigned(const AP: Pointer): Boolean;
begin
  Result := AP <> nil;
end;

function Assigned(const AObj: TObject): Boolean;
begin
  Result := AObj <> nil;
end;

function Assigned(const AIntf: IUnknown): Boolean;
begin
  Result := AIntf <> nil;
end;

{ === Variant Utilities === }

function VarType(const V: Variant): TVarType;
begin
  Result := TVarData(V).VType;
end;

function VarIsNull(const V: Variant): Boolean;
begin
  Result := TVarData(V).VType = varNull;
end;

function VarIsEmpty(const V: Variant): Boolean;
begin
  Result := TVarData(V).VType = varEmpty;
end;

function VarIsClear(const V: Variant): Boolean;
begin
  Result := TVarData(V).VType in [varEmpty, varNull];
end;

end.
