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

{** 接口查询 *}
function Supports(const AInstance: TObject; const AIID: TGuid; out AIntf): Boolean;
function Supports(const AInstance: IInterface; const AIID: TGuid; out AIntf): Boolean;

implementation

uses
  nextpas.core.base;

procedure ClearOutInterface(out AIntf);
begin
  IInterface(AIntf) := nil;
end;

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
  if (A = nil) or (B = nil) then Exit(A = B);
  Result := System.CompareByte(A^, B^, ASize) = 0;
end;

function Supports(const AInstance: TObject; const AIID: TGuid; out AIntf): Boolean;
begin
  if AInstance = nil then
  begin
    ClearOutInterface(AIntf);
    Exit(False);
  end;
  Result := AInstance.GetInterface(AIID, AIntf);
  if not Result then
    ClearOutInterface(AIntf);
end;

function Supports(const AInstance: IInterface; const AIID: TGuid; out AIntf): Boolean;
begin
  if AInstance = nil then
  begin
    ClearOutInterface(AIntf);
    Exit(False);
  end;
  Result := AInstance.QueryInterface(AIID, AIntf) = S_OK;
  if not Result then
    ClearOutInterface(AIntf);
end;

end.
