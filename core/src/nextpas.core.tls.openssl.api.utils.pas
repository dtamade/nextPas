unit nextpas.core.tls.openssl.api.utils;

{$mode ObjFPC}{$H+}

interface

uses nextpas.core.text.conv;

{ Library handle management }
function GetLibHandle: HMODULE;
procedure SetLibHandle(AHandle: HMODULE);

{ String conversion utilities }
function OpenSSLString(const S: string): PAnsiChar;
function PascalString(const S: PAnsiChar): string;

{ Memory utilities }
function AllocOpenSSLMem(Size: PtrUInt): Pointer;
procedure FreeOpenSSLMem(P: Pointer);

{ Error utilities }
function GetLastOpenSSLError: string;

implementation

uses nextpas.core.tls.openssl.api.core, nextpas.core.tls.openssl.api.err;

var
  GLibHandle: HMODULE = 0;

function GetLibHandle: HMODULE;
begin
  Result := GLibHandle;
end;

procedure SetLibHandle(AHandle: HMODULE);
begin
  GLibHandle := AHandle;
end;

function OpenSSLString(const S: string): PAnsiChar;
begin
  if S = '' then
    Result := nil
  else
    Result := PAnsiChar(AnsiString(S));
end;

function PascalString(const S: PAnsiChar): string;
begin
  if S = nil then
    Result := ''
  else
    Result := string(S);
end;

function AllocOpenSSLMem(Size: PtrUInt): Pointer;
begin
  Result := GetMem(Size);
  if Result <> nil then
    FillChar(Result^, Size, 0);
end;

procedure FreeOpenSSLMem(P: Pointer);
begin
  if P <> nil then
    FreeMem(P);
end;

function GetLastOpenSSLError: string;
var
  ErrCode: Cardinal;
  ErrStr: PAnsiChar;
begin
  Result := '';
  if @ERR_get_error <> nil then
  begin
    ErrCode := ERR_get_error();
    if ErrCode <> 0 then
    begin
      if @ERR_error_string <> nil then
      begin
        ErrStr := ERR_error_string(ErrCode);
        if ErrStr <> nil then
          Result := string(ErrStr);
      end
      else
        Result := Format('OpenSSL Error: 0x%x', [ErrCode]);
    end;
  end;
end;

initialization
  GLibHandle := 0;

finalization
  GLibHandle := 0;

end.
