program test_sha3_names;

{$mode Delphi}{$H+}

uses
  SysUtils, Dynlibs;

type
  PEVP_MD = Pointer;
  PEVP_MD_CTX = Pointer;
  
  TEVP_MD_CTX_new = function: PEVP_MD_CTX; cdecl;
  TEVP_MD_CTX_free = procedure(ctx: PEVP_MD_CTX); cdecl;
  TEVP_DigestInit_ex = function(ctx: PEVP_MD_CTX; const type_: PEVP_MD; impl: Pointer): Integer; cdecl;
  TEVP_get_digestbyname = function(const name: PAnsiChar): PEVP_MD; cdecl;
  TEVP_MD_fetch = function(ctx: Pointer; const algorithm: PAnsiChar; const properties: PAnsiChar): PEVP_MD; cdecl;
  TEVP_MD_free = procedure(md: PEVP_MD); cdecl;

var
  libHandle: TLibHandle;
  EVP_MD_CTX_new: TEVP_MD_CTX_new;
  EVP_MD_CTX_free: TEVP_MD_CTX_free;
  EVP_DigestInit_ex: TEVP_DigestInit_ex;
  EVP_get_digestbyname: TEVP_get_digestbyname;
  EVP_MD_fetch: TEVP_MD_fetch;
  EVP_MD_free: TEVP_MD_free;
  
  names: array[0..7] of AnsiString = (
    'SHA3-256', 'SHA3256', 'sha3-256', 'sha3_256',
    'SHA3-224', 'SHA3224', 'sha3-224', 'sha3_224'
  );
  i: Integer;
  md: PEVP_MD;
  ctx: PEVP_MD_CTX;
  algName: AnsiString;
  usesFetch: Boolean;

begin
  WriteLn('Testing SHA3 Algorithm Names');
  WriteLn('============================');
  WriteLn;
  
  libHandle := LoadLibrary('libcrypto-3-x64.dll');
  if libHandle = 0 then
  begin
    WriteLn('ERROR: Failed to load libcrypto-3-x64.dll');
    Halt(1);
  end;
  
  try
    // Load functions
    EVP_MD_CTX_new := TEVP_MD_CTX_new(GetProcAddress(libHandle, 'EVP_MD_CTX_new'));
    EVP_MD_CTX_free := TEVP_MD_CTX_free(GetProcAddress(libHandle, 'EVP_MD_CTX_free'));
    EVP_DigestInit_ex := TEVP_DigestInit_ex(GetProcAddress(libHandle, 'EVP_DigestInit_ex'));
    EVP_get_digestbyname := TEVP_get_digestbyname(GetProcAddress(libHandle, 'EVP_get_digestbyname'));
    EVP_MD_fetch := TEVP_MD_fetch(GetProcAddress(libHandle, 'EVP_MD_fetch'));
    EVP_MD_free := TEVP_MD_free(GetProcAddress(libHandle, 'EVP_MD_free'));
    
    if not (Assigned(EVP_MD_CTX_new) and Assigned(EVP_DigestInit_ex)) then
    begin
      WriteLn('ERROR: Failed to load EVP functions');
      Halt(1);
    end;
    
    WriteLn('Testing with EVP_MD_fetch (OpenSSL 3.x):');
    WriteLn('-----------------------------------------');
    if Assigned(EVP_MD_fetch) then
    begin
      for i := 0 to High(names) do
      begin
        algName := names[i];
        md := EVP_MD_fetch(nil, PAnsiChar(algName), nil);
        
        Write('  ', algName:20, ': ');
        if md <> nil then
        begin
          // Try to use it
          ctx := EVP_MD_CTX_new();
          if ctx <> nil then
          begin
            if EVP_DigestInit_ex(ctx, md, nil) = 1 then
              WriteLn('SUCCESS')
            else
              WriteLn('FOUND but Init failed');
            EVP_MD_CTX_free(ctx);
          end
          else
            WriteLn('FOUND but CTX create failed');
          
          if Assigned(EVP_MD_free) then
            EVP_MD_free(md);
        end
        else
          WriteLn('NOT FOUND');
      end;
    end
    else
      WriteLn('  EVP_MD_fetch not available');
    
    WriteLn;
    WriteLn('Testing with EVP_get_digestbyname (Legacy):');
    WriteLn('--------------------------------------------');
    if Assigned(EVP_get_digestbyname) then
    begin
      for i := 0 to High(names) do
      begin
        algName := names[i];
        md := EVP_get_digestbyname(PAnsiChar(algName));
        
        Write('  ', algName:20, ': ');
        if md <> nil then
        begin
          ctx := EVP_MD_CTX_new();
          if ctx <> nil then
          begin
            if EVP_DigestInit_ex(ctx, md, nil) = 1 then
              WriteLn('SUCCESS')
            else
              WriteLn('FOUND but Init failed');
            EVP_MD_CTX_free(ctx);
          end
          else
            WriteLn('FOUND but CTX create failed');
        end
        else
          WriteLn('NOT FOUND');
      end;
    end
    else
      WriteLn('  EVP_get_digestbyname not available');
    
  finally
    FreeLibrary(libHandle);
  end;
  
  WriteLn;
  WriteLn('Press Enter to exit...');
  ReadLn;
end.
