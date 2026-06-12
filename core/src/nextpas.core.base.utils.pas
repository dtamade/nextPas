unit nextpas.core.base.utils;

{$I nextpas.core.settings.inc}

interface

{** 对象生命周期工具 *}
procedure FreeAndNil(var AObj);
procedure SafeFree(var AObj); inline;

{** 内存操作（System 内建的包装，确保接口一致） *}
procedure ZeroMem(ADst: Pointer; ASize: SizeUInt); inline;
procedure CopyMem(ADst: Pointer; ASrc: Pointer; ASize: SizeUInt); inline;
function CompareMem(A, B: Pointer; ASize: SizeUInt): Boolean; inline;

{** SizeUInt 边界与溢出 guard *}
function TryAddSizeUInt(const ALeft, ARight: SizeUInt; var ASum: SizeUInt): Boolean; inline;
function CheckedAddSizeUInt(const ALeft, ARight: SizeUInt): SizeUInt; inline;
function TryMulSizeUInt(const ALeft, ARight: SizeUInt; var AProduct: SizeUInt): Boolean; inline;
function CheckedMulSizeUInt(const ALeft, ARight: SizeUInt): SizeUInt; inline;
procedure CheckSizeRange(const AOffset, ALength, ASize: SizeUInt);

{** 接口查询 *}
function Supports(const AInstance: TObject; const AIID: TGuid; out AIntf): Boolean;
function Supports(const AInstance: IInterface; const AIID: TGuid; out AIntf): Boolean;

implementation

uses
  nextpas.core.base;

procedure FreeAndNil(var AObj);
var LTemp: TObject;
begin
  LTemp := TObject(AObj);
  Pointer(AObj) := nil;
  LTemp.Free;
end;

procedure SafeFree(var AObj);
begin
  FreeAndNil(AObj);
end;

procedure ZeroMem(ADst: Pointer; ASize: SizeUInt);
begin
  if ASize = 0 then
    Exit;
  if ADst = nil then
    raise EArgumentNil.Create('ZeroMem: destination is nil');
  FillChar(ADst^, ASize, 0);
end;

procedure CopyMem(ADst: Pointer; ASrc: Pointer; ASize: SizeUInt);
begin
  if ASize = 0 then
    Exit;
  if ADst = nil then
    raise EArgumentNil.Create('CopyMem: destination is nil');
  if ASrc = nil then
    raise EArgumentNil.Create('CopyMem: source is nil');
  Move(ASrc^, ADst^, ASize);
end;

function CompareMem(A, B: Pointer; ASize: SizeUInt): Boolean;
begin
  if ASize = 0 then Exit(True);
  if (A = nil) or (B = nil) then Exit(False);
  Result := System.CompareByte(A^, B^, ASize) = 0;
end;

function TryAddSizeUInt(const ALeft, ARight: SizeUInt; var ASum: SizeUInt): Boolean;
begin
  Result := ALeft <= MAX_SIZE_UINT - ARight;
  if Result then
    ASum := ALeft + ARight;
end;

function CheckedAddSizeUInt(const ALeft, ARight: SizeUInt): SizeUInt;
begin
  if not TryAddSizeUInt(ALeft, ARight, Result) then
    raise EOverflow.Create('CheckedAddSizeUInt: size overflow');
end;

function TryMulSizeUInt(const ALeft, ARight: SizeUInt; var AProduct: SizeUInt): Boolean;
begin
  if (ALeft = 0) or (ARight = 0) then
  begin
    AProduct := 0;
    Exit(True);
  end;

  Result := ALeft <= MAX_SIZE_UINT div ARight;
  if Result then
    AProduct := ALeft * ARight;
end;

function CheckedMulSizeUInt(const ALeft, ARight: SizeUInt): SizeUInt;
begin
  if not TryMulSizeUInt(ALeft, ARight, Result) then
    raise EOverflow.Create('CheckedMulSizeUInt: size overflow');
end;

procedure CheckSizeRange(const AOffset, ALength, ASize: SizeUInt);
begin
  if AOffset > ASize then
    raise EOutOfRange.CreateFmt(
      'CheckSizeRange: offset %d + length %d > size %d',
      [AOffset, ALength, ASize]);
  if ALength > ASize - AOffset then
    raise EOutOfRange.CreateFmt(
      'CheckSizeRange: offset %d + length %d > size %d',
      [AOffset, ALength, ASize]);
end;

function Supports(const AInstance: TObject; const AIID: TGuid; out AIntf): Boolean;
begin
  if AInstance = nil then Exit(False);
  Result := AInstance.GetInterface(AIID, AIntf);
end;

function Supports(const AInstance: IInterface; const AIID: TGuid; out AIntf): Boolean;
begin
  if AInstance = nil then Exit(False);
  Result := AInstance.QueryInterface(AIID, AIntf) = S_OK;
end;

end.
