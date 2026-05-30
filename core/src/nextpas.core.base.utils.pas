unit nextpas.core.base.utils;

{$I nextpas.core.settings.inc}

interface

{** 对象生命周期工具 *}
procedure FreeAndNil(var AObj);
procedure SafeFree(var AObj); inline;

{** 内存操作（System 内建的包装，确保接口一致） *}
procedure ZeroMem(ADst: Pointer; ASize: SizeUInt); inline;
procedure CopyMem(ADst: Pointer; ASrc: Pointer; ASize: SizeUInt); inline;

implementation

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
  FillChar(ADst^, ASize, 0);
end;

procedure CopyMem(ADst: Pointer; ASrc: Pointer; ASize: SizeUInt);
begin
  Move(ASrc^, ADst^, ASize);
end;

end.
