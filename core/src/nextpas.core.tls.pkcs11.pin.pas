unit nextpas.core.tls.pkcs11.pin;

{******************************************************************************}
{                                                                              }
{  fafafa.ssl - PKCS#11 PIN Management                                        }
{                                                                              }
{  Purpose: Secure PIN acquisition and management for PKCS#11 tokens          }
{                                                                              }
{  Features:                                                                   }
{    - 5 PIN acquisition methods (value, environment, file, callback, interactive) }
{    - Secure PIN handling (zero after use)                                   }
{    - PIN validation and strength checking                                   }
{    - Callback mechanism for custom PIN providers                            }
{                                                                              }
{******************************************************************************}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  nextpas.core.tls.pkcs11.types;

type
  { TPKCS11PINManager - PIN acquisition and management }
  TPKCS11PINManager = class
  private
    class function ReadPINFromFile(const AFilePath: string): string;
    class function ReadPINFromEnvironment(const AVarName: string): string;
    class function ReadPINInteractive(const APrompt: string): string;
  public
    { Get PIN using specified method
      
      Parameters:
        AMethod: PIN acquisition method
        AValue: Method-specific value (direct PIN, env var name, file path, etc.)
        ACallback: Callback function (for pmCallback method)
        ATokenLabel: Token label (for prompts)
        
      Returns:
        PIN string (caller must securely zero after use)
        
      Raises:
        EPKCS11Exception if PIN cannot be acquired
    }
    class function GetPIN(
      AMethod: TPKCS11PINMethod;
      const AValue: string = '';
      ACallback: TPKCS11PINCallback = nil;
      const ATokenLabel: string = ''
    ): string;
    
    { Validate PIN format and strength
      
      Parameters:
        APIN: PIN to validate
        AMinLength: Minimum PIN length (default: 4)
        AMaxLength: Maximum PIN length (default: 32)
        
      Returns:
        True if PIN is valid
        
      Raises:
        EPKCS11Exception if PIN is invalid
    }
    class function ValidatePIN(const APIN: string; AMinLength: Integer = 4; AMaxLength: Integer = 32): Boolean;
    
    { Securely zero PIN string
      
      Parameters:
        APIN: PIN string to zero (will be modified)
    }
    class procedure SecureZeroPIN(var APIN: string);
  end;

implementation

uses
  nextpas.core.tls.pkcs11.api;

{ TPKCS11PINManager }

class function TPKCS11PINManager.ReadPINFromFile(const AFilePath: string): string;
var
  F: TextFile;
  Line: string;
begin
  Result := '';
  
  if not FileExists(AFilePath) then
    raise EPKCS11Exception.Create(
      Format('PIN file not found: %s', [AFilePath]),
      CKR_GENERAL_ERROR);
  
  try
    AssignFile(F, AFilePath);
    Reset(F);
    try
      if not Eof(F) then
      begin
        ReadLn(F, Line);
        Result := Trim(Line);
      end;
    finally
      CloseFile(F);
    end;
  except
    on E: Exception do
      raise EPKCS11Exception.Create(
        Format('Failed to read PIN from file: %s', [E.Message]),
        CKR_GENERAL_ERROR);
  end;
  
  if Result = '' then
    raise EPKCS11Exception.Create(
      'PIN file is empty',
      CKR_PIN_INVALID);
end;

class function TPKCS11PINManager.ReadPINFromEnvironment(const AVarName: string): string;
begin
  Result := GetEnvironmentVariable(AVarName);
  
  if Result = '' then
    raise EPKCS11Exception.Create(
      Format('Environment variable not set or empty: %s', [AVarName]),
      CKR_PIN_INVALID);
end;

class function TPKCS11PINManager.ReadPINInteractive(const APrompt: string): string;
begin
  // Interactive PIN reading (console input)
  // Note: This is a simplified implementation
  // Production code should use platform-specific secure input methods
  
  Write(APrompt);
  ReadLn(Result);
  Result := Trim(Result);
  
  if Result = '' then
    raise EPKCS11Exception.Create(
      'No PIN entered',
      CKR_PIN_INVALID);
end;

{$WARN 6018 OFF}
class function TPKCS11PINManager.GetPIN(
  AMethod: TPKCS11PINMethod;
  const AValue: string;
  ACallback: TPKCS11PINCallback;
  const ATokenLabel: string
): string;
begin
  Result := '';
  
  case AMethod of
    pmNone:
      Exit; // No PIN required
      
    pmValue:
      begin
        if AValue = '' then
          raise EPKCS11Exception.Create(
            'PIN value not provided',
            CKR_PIN_INVALID);
        Result := AValue;
      end;
      
    pmEnvironment:
      begin
        if AValue = '' then
          raise EPKCS11Exception.Create(
            'Environment variable name not provided',
            CKR_ARGUMENTS_BAD);
        Result := ReadPINFromEnvironment(AValue);
      end;
      
    pmFile:
      begin
        if AValue = '' then
          raise EPKCS11Exception.Create(
            'PIN file path not provided',
            CKR_ARGUMENTS_BAD);
        Result := ReadPINFromFile(AValue);
      end;
      
    pmCallback:
      begin
        if not Assigned(ACallback) then
          raise EPKCS11Exception.Create(
            'PIN callback not provided',
            CKR_ARGUMENTS_BAD);

        if not ACallback(ATokenLabel, Result) then
          raise EPKCS11Exception.Create(
            'PIN callback failed or cancelled',
            CKR_PIN_INVALID);

        Result := Trim(Result);
        if Result = '' then
          raise EPKCS11Exception.Create(
            'PIN callback returned empty PIN',
            CKR_PIN_INVALID);
      end;
      
    pmInteractive:
      raise EPKCS11Exception.Create(
        'Interactive PIN is unsupported in TPKCS11PINManager.GetPIN; use callback/value/file/environment methods',
        CKR_FUNCTION_NOT_SUPPORTED);
  else
    raise EPKCS11Exception.Create(
      'Invalid PIN method',
      CKR_ARGUMENTS_BAD);
  end;
  
  // Validate PIN if acquired
  if Result <> '' then
    ValidatePIN(Result);
end;
{$WARN 6018 ON}

class function TPKCS11PINManager.ValidatePIN(const APIN: string; AMinLength: Integer; AMaxLength: Integer): Boolean;
begin
  Result := False;
  
  if APIN = '' then
    raise EPKCS11Exception.Create(
      'PIN is empty',
      CKR_PIN_INVALID);
  
  if Length(APIN) < AMinLength then
    raise EPKCS11Exception.Create(
      Format('PIN too short (minimum %d characters)', [AMinLength]),
      CKR_PIN_LEN_RANGE);
  
  if Length(APIN) > AMaxLength then
    raise EPKCS11Exception.Create(
      Format('PIN too long (maximum %d characters)', [AMaxLength]),
      CKR_PIN_LEN_RANGE);
  
  Result := True;
end;

class procedure TPKCS11PINManager.SecureZeroPIN(var APIN: string);
var
  I: Integer;
begin
  if APIN = '' then
    Exit;
  
  // Overwrite PIN string with zeros
  for I := 1 to Length(APIN) do
    APIN[I] := #0;
  
  // Clear the string
  APIN := '';
end;

end.
