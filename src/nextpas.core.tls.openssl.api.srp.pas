{******************************************************************************}
{                                                                              }
{  nextpas.core.tls.openssl.api.srp - OpenSSL SRP Module Pascal Binding                 }
{                                                                              }
{  Copyright (c) 2024 fafafa                                                  }
{                                                                              }
{******************************************************************************}
unit nextpas.core.tls.openssl.api.srp;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, Classes,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.bn,
  nextpas.core.tls.openssl.api.consts;

type
  { SRP types }
  SRP_gN_cache = record end;
  PSRP_gN_cache = ^SRP_gN_cache;
  
  SRP_user_pwd = record end;
  PSRP_user_pwd = ^SRP_user_pwd;
  
  SRP_VBASE = record end;
  PSRP_VBASE = ^SRP_VBASE;
  
  SRP_gN = record
    id: PChar;
    g: PBIGNUM;
    N: PBIGNUM;
  end;
  PSRP_gN = ^SRP_gN;
  
  { SRP callback types }
  TSRP_verify_param_callback = function(id: PChar; N: PBIGNUM; g: PBIGNUM): TOpenSSLInt; cdecl;
  TSRP_user_callback = function(user: PSRP_user_pwd; arg: Pointer): TOpenSSLInt; cdecl;
  TSRP_give_pwd_callback = function(login: PChar; user: PSRP_user_pwd): PChar; cdecl;
  
  { Function pointers for dynamic loading }
  { Basic SRP functions }
  TSRPBnbin2bn = function(const s: PByte; len: TOpenSSLInt; ret: PBIGNUM): PBIGNUM; cdecl;
  TSRPCalcB = function(b: PBIGNUM; N: PBIGNUM; g: PBIGNUM; v: PBIGNUM): PBIGNUM; cdecl;
  TSRPCalcServerKey = function(A: PBIGNUM; v: PBIGNUM; u: PBIGNUM; b: PBIGNUM; N: PBIGNUM): PBIGNUM; cdecl;
  TSRPCalcU = function(A: PBIGNUM; B: PBIGNUM; N: PBIGNUM): PBIGNUM; cdecl;
  TSRPCalcClientKey = function(N: PBIGNUM; B: PBIGNUM; g: PBIGNUM; x: PBIGNUM; a: PBIGNUM; u: PBIGNUM): PBIGNUM; cdecl;
  TSRPCalcX = function(s: PBIGNUM; const user: PChar; const pass: PChar): PBIGNUM; cdecl;
  TSRPCalcClient = function(a: PBIGNUM; N: PBIGNUM; g: PBIGNUM): PBIGNUM; cdecl;
  TSRPVerifyAPubKey = function(N: PBIGNUM; A: PBIGNUM): TOpenSSLInt; cdecl;
  TSRPVerifyBPubKey = function(N: PBIGNUM; B: PBIGNUM): TOpenSSLInt; cdecl;
  
  { VBASE functions }
  TSRPVBASEG = function: PSRP_VBASE; cdecl;
  TSRPVBASEFree = procedure(vb: PSRP_VBASE); cdecl;
  TSRPVBASEInit = function(vb: PSRP_VBASE; verifier_file: PChar): TOpenSSLInt; cdecl;
  TSRPVBASEAdd = function(vb: PSRP_VBASE; user_pwd: PSRP_user_pwd): TOpenSSLInt; cdecl;
  TSRPVBASEGetByUser = function(vb: PSRP_VBASE; const username: PChar): PSRP_user_pwd; cdecl;
  TSRPVBASEGet1ByUser = function(vb: PSRP_VBASE; const username: PChar): PSRP_user_pwd; cdecl;
  
  { User management functions }
  TSRPUserPwdNew = function(const username: PChar): PSRP_user_pwd; cdecl;
  TSRPUserPwdFree = procedure(user_pwd: PSRP_user_pwd); cdecl;
  TSRPUserPwdSetSalt = function(user_pwd: PSRP_user_pwd; salt: PBIGNUM): TOpenSSLInt; cdecl;
  TSRPUserPwdSetVerifier = function(user_pwd: PSRP_user_pwd; verifier: PBIGNUM): TOpenSSLInt; cdecl;
  TSRPUserPwdSetInfo = function(user_pwd: PSRP_user_pwd; const info: PChar): TOpenSSLInt; cdecl;
  TSRPUserPwdSetGN = function(user_pwd: PSRP_user_pwd; const g: PChar; const N: PChar): TOpenSSLInt; cdecl;
  TSRPUserPwdGet0Salt = function(user_pwd: PSRP_user_pwd): PBIGNUM; cdecl;
  TSRPUserPwdGet0Verifier = function(user_pwd: PSRP_user_pwd): PBIGNUM; cdecl;
  TSRPUserPwdGet0Username = function(user_pwd: PSRP_user_pwd): PChar; cdecl;
  
  { gN functions }
  TSRPGetDefaultGN = function(const id: PChar): PSRP_gN; cdecl;
  TSRPCheckKnownGNParam = function(g: PBIGNUM; N: PBIGNUM): PChar; cdecl;
  TSRPGet1KnownGN = function(const id: PChar): PSRP_gN; cdecl;
  
  { Password functions }
  TSRPCreateVerifier = function(const user: PChar; const pass: PChar; 
                                salt: PPBIGNUM; verifier: PPBIGNUM; 
                                const N: PChar; const g: PChar): PChar; cdecl;
  TSRPCreateVerifierBN = function(const user: PChar; const pass: PChar;
                                  salt: PPBIGNUM; verifier: PPBIGNUM;
                                  N: PBIGNUM; g: PBIGNUM): TOpenSSLInt; cdecl;

var
  { Function variables }
  SRP_Calc_server_key: TSRPCalcServerKey = nil;
  SRP_Calc_u: TSRPCalcU = nil;
  SRP_Calc_client_key: TSRPCalcClientKey = nil;
  SRP_Calc_x: TSRPCalcX = nil;
  SRP_Calc_B: TSRPCalcB = nil;
  SRP_Calc_A: TSRPCalcClient = nil;
  SRP_Verify_A_mod_N: TSRPVerifyAPubKey = nil;
  SRP_Verify_B_mod_N: TSRPVerifyBPubKey = nil;
  
  { VBASE functions }
  SRP_VBASE_new: TSRPVBASEG = nil;
  SRP_VBASE_free: TSRPVBASEFree = nil;
  SRP_VBASE_init: TSRPVBASEInit = nil;
  SRP_VBASE_add0_user: TSRPVBASEAdd = nil;
  SRP_VBASE_get_by_user: TSRPVBASEGetByUser = nil;
  SRP_VBASE_get1_by_user: TSRPVBASEGet1ByUser = nil;
  
  { User management }
  SRP_user_pwd_new: TSRPUserPwdNew = nil;
  SRP_user_pwd_free: TSRPUserPwdFree = nil;
  SRP_user_pwd_set_salt: TSRPUserPwdSetSalt = nil;
  SRP_user_pwd_set_verifier: TSRPUserPwdSetVerifier = nil;
  SRP_user_pwd_set_info: TSRPUserPwdSetInfo = nil;
  SRP_user_pwd_set_gN: TSRPUserPwdSetGN = nil;
  SRP_user_pwd_get0_salt: TSRPUserPwdGet0Salt = nil;
  SRP_user_pwd_get0_verifier: TSRPUserPwdGet0Verifier = nil;
  SRP_user_pwd_get0_name: TSRPUserPwdGet0Username = nil;
  
  { gN functions }
  SRP_get_default_gN: TSRPGetDefaultGN = nil;
  SRP_check_known_gN_param: TSRPCheckKnownGNParam = nil;
  SRP_get_1_by_id: TSRPGet1KnownGN = nil;
  
  { Password functions }
  SRP_create_verifier: TSRPCreateVerifier = nil;
  SRP_create_verifier_BN: TSRPCreateVerifierBN = nil;

{ Load/Unload functions }
function LoadSRP(const ALibCrypto: THandle): Boolean;
procedure UnloadSRP;

{ Helper functions }
function SRPCreateUser(const Username, Password: string; const gN_id: string = '1024'): PSRP_user_pwd;
function SRPVerifyUser(vbase: PSRP_VBASE; const Username, Password: string): Boolean;
function SRPGenerateVerifier(const Username, Password: string; out Salt, Verifier: string; const gN_id: string = '1024'): Boolean;

implementation

uses
  nextpas.core.tls.openssl.api.utils,
  nextpas.core.tls.openssl.api.crypto;

const
  { SRP function bindings for batch loading }
  SRP_FUNCTION_COUNT = 28;
  SRPFunctionBindings: array[0..SRP_FUNCTION_COUNT - 1] of TFunctionBinding = (
    { Calculation functions }
    (Name: 'SRP_Calc_server_key';     FuncPtr: @SRP_Calc_server_key;     Required: False),
    (Name: 'SRP_Calc_u';              FuncPtr: @SRP_Calc_u;              Required: False),
    (Name: 'SRP_Calc_client_key';     FuncPtr: @SRP_Calc_client_key;     Required: False),
    (Name: 'SRP_Calc_x';              FuncPtr: @SRP_Calc_x;              Required: False),
    (Name: 'SRP_Calc_B';              FuncPtr: @SRP_Calc_B;              Required: False),
    (Name: 'SRP_Calc_A';              FuncPtr: @SRP_Calc_A;              Required: False),
    (Name: 'SRP_Verify_A_mod_N';      FuncPtr: @SRP_Verify_A_mod_N;      Required: False),
    (Name: 'SRP_Verify_B_mod_N';      FuncPtr: @SRP_Verify_B_mod_N;      Required: False),
    { VBASE functions }
    (Name: 'SRP_VBASE_new';           FuncPtr: @SRP_VBASE_new;           Required: False),
    (Name: 'SRP_VBASE_free';          FuncPtr: @SRP_VBASE_free;          Required: False),
    (Name: 'SRP_VBASE_init';          FuncPtr: @SRP_VBASE_init;          Required: False),
    (Name: 'SRP_VBASE_add0_user';     FuncPtr: @SRP_VBASE_add0_user;     Required: False),
    (Name: 'SRP_VBASE_get_by_user';   FuncPtr: @SRP_VBASE_get_by_user;   Required: False),
    (Name: 'SRP_VBASE_get1_by_user';  FuncPtr: @SRP_VBASE_get1_by_user;  Required: False),
    { User management functions }
    (Name: 'SRP_user_pwd_new';        FuncPtr: @SRP_user_pwd_new;        Required: False),
    (Name: 'SRP_user_pwd_free';       FuncPtr: @SRP_user_pwd_free;       Required: False),
    (Name: 'SRP_user_pwd_set_salt';   FuncPtr: @SRP_user_pwd_set_salt;   Required: False),
    (Name: 'SRP_user_pwd_set_verifier'; FuncPtr: @SRP_user_pwd_set_verifier; Required: False),
    (Name: 'SRP_user_pwd_set_info';   FuncPtr: @SRP_user_pwd_set_info;   Required: False),
    (Name: 'SRP_user_pwd_set_gN';     FuncPtr: @SRP_user_pwd_set_gN;     Required: False),
    (Name: 'SRP_user_pwd_get0_salt';  FuncPtr: @SRP_user_pwd_get0_salt;  Required: False),
    (Name: 'SRP_user_pwd_get0_verifier'; FuncPtr: @SRP_user_pwd_get0_verifier; Required: False),
    (Name: 'SRP_user_pwd_get0_name';  FuncPtr: @SRP_user_pwd_get0_name;  Required: False),
    { gN functions }
    (Name: 'SRP_get_default_gN';      FuncPtr: @SRP_get_default_gN;      Required: False),
    (Name: 'SRP_check_known_gN_param'; FuncPtr: @SRP_check_known_gN_param; Required: False),
    (Name: 'SRP_get_1_by_id';         FuncPtr: @SRP_get_1_by_id;         Required: False),
    { Password functions }
    (Name: 'SRP_create_verifier';     FuncPtr: @SRP_create_verifier;     Required: False),
    (Name: 'SRP_create_verifier_BN';  FuncPtr: @SRP_create_verifier_BN;  Required: False)
  );

function LoadSRP(const ALibCrypto: THandle): Boolean;
begin
  Result := False;
  if TOpenSSLLoader.IsModuleLoaded(osmSRP) then Exit(True);
  if ALibCrypto = 0 then Exit;

  { Batch load all SRP functions }
  TOpenSSLLoader.LoadFunctions(ALibCrypto, SRPFunctionBindings);

  { Basic functions are enough to consider the module loaded }
  Result := Assigned(SRP_VBASE_new);
  TOpenSSLLoader.SetModuleLoaded(osmSRP, Result);
end;

procedure UnloadSRP;
begin
  if not TOpenSSLLoader.IsModuleLoaded(osmSRP) then Exit;

  { Clear all function pointers }
  TOpenSSLLoader.ClearFunctions(SRPFunctionBindings);

  TOpenSSLLoader.SetModuleLoaded(osmSRP, False);
end;

{ Helper functions }

function SRPCreateUser(const Username, Password: string; const gN_id: string): PSRP_user_pwd;
var
  Salt, Verifier: PBIGNUM;
  gN: PSRP_gN;
begin
  Result := nil;
  if not Assigned(SRP_user_pwd_new) or
    not Assigned(SRP_user_pwd_free) or
    not Assigned(SRP_create_verifier_BN) then
    Exit;
  
  Result := SRP_user_pwd_new(PChar(Username));
  if Result = nil then Exit;
  
  gN := nil;
  if Assigned(SRP_get_default_gN) then
    gN := SRP_get_default_gN(PChar(gN_id));
    
  if gN = nil then
  begin
    SRP_user_pwd_free(Result);
    Result := nil;
    Exit;
  end;

  if not Assigned(SRP_user_pwd_set_salt) or
    not Assigned(SRP_user_pwd_set_verifier) then
  begin
    SRP_user_pwd_free(Result);
    Result := nil;
    Exit;
  end;
  
  Salt := nil;
  Verifier := nil;
  
  if SRP_create_verifier_BN(PChar(Username), PChar(Password), @Salt, @Verifier, gN^.N, gN^.g) = 1 then
  begin
    SRP_user_pwd_set_salt(Result, Salt);
    SRP_user_pwd_set_verifier(Result, Verifier);
  end
  else
  begin
    SRP_user_pwd_free(Result);
    Result := nil;
  end;
end;

function SRPVerifyUser(vbase: PSRP_VBASE; const Username, Password: string): Boolean;
var
  User: PSRP_user_pwd;
  Salt, StoredVerifier, ComputedX: PBIGNUM;
  gN: PSRP_gN;
  ComputedVerifier: PBIGNUM;
begin
  Result := False;
  if (vbase = nil) or not Assigned(SRP_VBASE_get_by_user) then Exit;
  
  User := SRP_VBASE_get_by_user(vbase, PChar(Username));
  if User = nil then Exit;
  
  // Get stored salt and verifier from user record
  if not Assigned(SRP_user_pwd_get0_salt) or not Assigned(SRP_user_pwd_get0_verifier) then
    Exit;
    
  Salt := SRP_user_pwd_get0_salt(User);
  StoredVerifier := SRP_user_pwd_get0_verifier(User);
  
  if (Salt = nil) or (StoredVerifier = nil) then
    Exit;
  
  // Compute x = H(salt | H(username | ':' | password))
  if Assigned(SRP_Calc_x) then
  begin
    ComputedX := SRP_Calc_x(Salt, PChar(Username), PChar(Password));
    if ComputedX = nil then Exit;
    
    try
      // Get default gN parameters (typically use same as stored user)
      if Assigned(SRP_get_default_gN) then
      begin
        gN := SRP_get_default_gN('1024');
        if gN <> nil then
        begin
          // Compute v = g^x mod N
          ComputedVerifier := BN_new();
          if ComputedVerifier <> nil then
          begin
            try
              // Use BN_mod_exp to compute g^x mod N
              if Assigned(BN_mod_exp) then
              begin
                if BN_mod_exp(ComputedVerifier, gN^.g, ComputedX, gN^.N, nil) = 1 then
                begin
                  // Compare computed verifier with stored verifier
                  if Assigned(BN_cmp) then
                    Result := BN_cmp(ComputedVerifier, StoredVerifier) = 0;
                end;
              end;
            finally
              BN_free(ComputedVerifier);
            end;
          end;
        end;
      end;
    finally
      BN_free(ComputedX);
    end;
  end;
end;

function SRPGenerateVerifier(const Username, Password: string; out Salt, Verifier: string; const gN_id: string): Boolean;
var
  SaltBN, VerifierBN: PBIGNUM;
  SaltStr, VerifierStr: PChar;
begin
  Result := False;
  Salt := '';
  Verifier := '';
  
  if not Assigned(SRP_create_verifier) then Exit;
  
  SaltBN := nil;
  VerifierBN := nil;
  
  SaltStr := SRP_create_verifier(PChar(Username), PChar(Password), @SaltBN, @VerifierBN, PChar(gN_id), nil);
  
  if (SaltBN <> nil) and (VerifierBN <> nil) then
  begin
    // Convert BIGNUM to hex strings
    if Assigned(BN_bn2hex) then
    begin
      SaltStr := BN_bn2hex(SaltBN);
      if SaltStr <> nil then
      begin
        Salt := string(SaltStr);
        // BN_bn2hex returns a string allocated with OPENSSL_malloc
        // Must use OPENSSL_free to release it properly
        // Note: Never use FreeMem - it would cause heap corruption
        if Assigned(OPENSSL_free) then
          OPENSSL_free(SaltStr);
        // If OPENSSL_free unavailable, accept small leak over corruption
      end;

      VerifierStr := BN_bn2hex(VerifierBN);
      if VerifierStr <> nil then
      begin
        Verifier := string(VerifierStr);
        // BN_bn2hex returns a string allocated with OPENSSL_malloc
        // Must use OPENSSL_free to release it properly
        // Note: Never use FreeMem - it would cause heap corruption
        if Assigned(OPENSSL_free) then
          OPENSSL_free(VerifierStr);
        // If OPENSSL_free unavailable, accept small leak over corruption
      end;
      
      Result := (Salt <> '') and (Verifier <> '');
    end;
    
    BN_free(SaltBN);
    BN_free(VerifierBN);
  end;
end;

initialization

finalization
  UnloadSRP;

end.
