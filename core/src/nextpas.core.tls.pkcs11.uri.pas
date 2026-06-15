unit nextpas.core.tls.pkcs11.uri;

{******************************************************************************}
{                                                                              }
{  fafafa.ssl - PKCS#11 URI Parser (RFC 7512)                                 }
{                                                                              }
{  Purpose: Parse and generate PKCS#11 URIs according to RFC 7512             }
{                                                                              }
{  RFC 7512: The PKCS #11 URI Scheme                                          }
{  https://tools.ietf.org/html/rfc7512                                        }
{                                                                              }
{  URI Format:                                                                 }
{    pkcs11:token=MyToken;object=MyKey?pin-value=1234&module-path=/lib/p11    }
{                                                                              }
{  Path Attributes (before '?'):                                              }
{    - Identify the cryptographic object                                      }
{    - token, manufacturer, serial, model, object, type, id, slot-id, etc.   }
{                                                                              }
{  Query Attributes (after '?'):                                              }
{    - Provide additional information                                         }
{    - pin-value, pin-source, module-name, module-path                       }
{                                                                              }
{******************************************************************************}

{$mode objfpc}{$H+}
{$WARN 5093 off}  // Function result variable of managed type does not seem initialized

interface

uses
  nextpas.core.exception, nextpas.core.text.conv, StrUtils,
  nextpas.core.tls.pkcs11.types;

type
  { TPKCS11URIParser - RFC 7512 URI parser }
  TPKCS11URIParser = class
  private
    class function DecodeURIComponent(const AValue: string): string;
    class function EncodeURIComponent(const AValue: string): string;
    class function ParsePathAttribute(const AName, AValue: string; var AURI: TPKCS11URI): Boolean;
    class function ParseQueryAttribute(const AName, AValue: string; var AURI: TPKCS11URI): Boolean;
    class function HexToBytes(const AHex: string): TBytes;
    class function BytesToHex(const ABytes: TBytes): string;
  public
    { Parse PKCS#11 URI string into structured format }
    class function Parse(const AURIString: string): TPKCS11URI;
    
    { Generate PKCS#11 URI string from structured format }
    class function Generate(const AURI: TPKCS11URI): string;
    
    { Validate URI format }
    class function Validate(const AURIString: string; out AError: string): Boolean;
    
    { Check if string is a PKCS#11 URI }
    class function IsPKCS11URI(const AURIString: string): Boolean;
  end;

implementation

uses
  nextpas.core.text.strings;


{ TPKCS11URIParser }

class function TPKCS11URIParser.IsPKCS11URI(const AURIString: string): Boolean;
begin
  Result := StartsStr('pkcs11:', LowerCase(Trim(AURIString)));
end;

class function TPKCS11URIParser.DecodeURIComponent(const AValue: string): string;
var
  I: Integer;
  HexStr: string;
begin
  Result := '';
  I := 1;
  while I <= Length(AValue) do
  begin
    if AValue[I] = '%' then
    begin
      if I + 2 <= Length(AValue) then
      begin
        HexStr := '$' + Copy(AValue, I + 1, 2);
        try
          Result := Result + Chr(StrToInt(HexStr));
          Inc(I, 3);
        except
          Result := Result + AValue[I];
          Inc(I);
        end;
      end
      else
      begin
        Result := Result + AValue[I];
        Inc(I);
      end;
    end
    else
    begin
      Result := Result + AValue[I];
      Inc(I);
    end;
  end;
end;

class function TPKCS11URIParser.EncodeURIComponent(const AValue: string): string;
const
  // RFC 7512 Section 2.3: Unreserved characters that don't need encoding
  Unreserved = ['A'..'Z', 'a'..'z', '0'..'9', '-', '.', '_', '~'];
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(AValue) do
  begin
    if AValue[I] in Unreserved then
      Result := Result + AValue[I]
    else
      Result := Result + '%' + IntToHex(Ord(AValue[I]), 2);
  end;
end;

class function TPKCS11URIParser.HexToBytes(const AHex: string): TBytes;
var
  I, Len: Integer;
begin
  Len := Length(AHex) div 2;
  SetLength(Result, Len);
  for I := 0 to Len - 1 do
  begin
    Result[I] := StrToInt('$' + Copy(AHex, I * 2 + 1, 2));
  end;
end;

class function TPKCS11URIParser.BytesToHex(const ABytes: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to Length(ABytes) - 1 do
    Result := Result + IntToHex(ABytes[I], 2);
end;

class function TPKCS11URIParser.ParsePathAttribute(const AName, AValue: string; 
  var AURI: TPKCS11URI): Boolean;
var
  DecodedValue: string;
begin
  Result := True;
  DecodedValue := DecodeURIComponent(AValue);
  
  // RFC 7512 Section 2.3 - Path attributes
  if AName = 'token' then
    AURI.Token := DecodedValue
  else if AName = 'manufacturer' then
    AURI.Manufacturer := DecodedValue
  else if AName = 'serial' then
    AURI.Serial := DecodedValue
  else if AName = 'model' then
    AURI.Model := DecodedValue
  else if AName = 'library-manufacturer' then
    AURI.LibraryManufacturer := DecodedValue
  else if AName = 'library-description' then
    AURI.LibraryDescription := DecodedValue
  else if AName = 'library-version' then
    AURI.LibraryVersion := DecodedValue
  else if AName = 'object' then
    AURI.ObjectLabel := DecodedValue
  else if AName = 'type' then
    AURI.ObjectType := DecodedValue
  else if AName = 'id' then
    AURI.ObjectID := DecodedValue
  else if AName = 'slot-manufacturer' then
    AURI.SlotManufacturer := DecodedValue
  else if AName = 'slot-description' then
    AURI.SlotDescription := DecodedValue
  else if AName = 'slot-id' then
    AURI.SlotID := DecodedValue
  else
    Result := False; // Unknown attribute
end;

class function TPKCS11URIParser.ParseQueryAttribute(const AName, AValue: string; 
  var AURI: TPKCS11URI): Boolean;
var
  DecodedValue: string;
begin
  Result := True;
  DecodedValue := DecodeURIComponent(AValue);
  
  // RFC 7512 Section 2.4 - Query attributes
  if AName = 'pin-value' then
    AURI.PINValue := DecodedValue
  else if AName = 'pin-source' then
    AURI.PINSource := DecodedValue
  else if AName = 'module-name' then
    AURI.ModuleName := DecodedValue
  else if AName = 'module-path' then
    AURI.ModulePath := DecodedValue
  else
    Result := False; // Unknown attribute
end;

class function TPKCS11URIParser.Parse(const AURIString: string): TPKCS11URI;
var
  URI: string;
  PathPart, QueryPart: string;
  Attributes: TStringArray;
  I, SepPos: Integer;
  AttrName, AttrValue: string;
begin
  FillChar(Result, SizeOf(Result), 0);
  
  // Trim and validate
  URI := Trim(AURIString);
  if not IsPKCS11URI(URI) then
    raise Exception.Create('Invalid PKCS#11 URI: must start with "pkcs11:"');
  
  // Remove "pkcs11:" prefix
  Delete(URI, 1, 7);
  
  // Split into path and query parts
  SepPos := Pos('?', URI);
  if SepPos > 0 then
  begin
    PathPart := Copy(URI, 1, SepPos - 1);
    QueryPart := Copy(URI, SepPos + 1, MaxInt);
  end
  else
  begin
    PathPart := URI;
    QueryPart := '';
  end;
  try
    // Parse path attributes (separated by ';')
    if PathPart <> '' then
    begin';
      
      for I := 0 to Length(Attributes) - 1 do
      begin
        SepPos := Pos('=', Attributes[I]);
        if SepPos > 0 then
        begin
          AttrName := LowerCase(Trim(Copy(Attributes[I], 1, SepPos - 1)));
          AttrValue := Copy(Attributes[I], SepPos + 1, MaxInt);
          ParsePathAttribute(AttrName, AttrValue, Result);
        end;
      end;
    end;
    
    // Parse query attributes (separated by '&')
    if QueryPart <> '' then
    begin
      Attributes.Clear;
      
      for I := 0 to Length(Attributes) - 1 do
      begin
        SepPos := Pos('=', Attributes[I]);
        if SepPos > 0 then
        begin
          AttrName := LowerCase(Trim(Copy(Attributes[I], 1, SepPos - 1)));
          AttrValue := Copy(Attributes[I], SepPos + 1, MaxInt);
          ParseQueryAttribute(AttrName, AttrValue, Result);
        end;
      end;
    end;
  finally
  end;
end;

class function TPKCS11URIParser.Generate(const AURI: TPKCS11URI): string;
var
  PathParts, QueryParts: TStringArray;
begin
  try
    // Build path attributes
    if AURI.Token <> '' then
      PathParts.Add('token=' + EncodeURIComponent(AURI.Token));
    if AURI.Manufacturer <> '' then
      PathParts.Add('manufacturer=' + EncodeURIComponent(AURI.Manufacturer));
    if AURI.Serial <> '' then
      PathParts.Add('serial=' + EncodeURIComponent(AURI.Serial));
    if AURI.Model <> '' then
      PathParts.Add('model=' + EncodeURIComponent(AURI.Model));
    if AURI.LibraryManufacturer <> '' then
      PathParts.Add('library-manufacturer=' + EncodeURIComponent(AURI.LibraryManufacturer));
    if AURI.LibraryDescription <> '' then
      PathParts.Add('library-description=' + EncodeURIComponent(AURI.LibraryDescription));
    if AURI.LibraryVersion <> '' then
      PathParts.Add('library-version=' + EncodeURIComponent(AURI.LibraryVersion));
    if AURI.ObjectLabel <> '' then
      PathParts.Add('object=' + EncodeURIComponent(AURI.ObjectLabel));
    if AURI.ObjectType <> '' then
      PathParts.Add('type=' + EncodeURIComponent(AURI.ObjectType));
    if AURI.ObjectID <> '' then
      PathParts.Add('id=' + EncodeURIComponent(AURI.ObjectID));
    if AURI.SlotManufacturer <> '' then
      PathParts.Add('slot-manufacturer=' + EncodeURIComponent(AURI.SlotManufacturer));
    if AURI.SlotDescription <> '' then
      PathParts.Add('slot-description=' + EncodeURIComponent(AURI.SlotDescription));
    if AURI.SlotID <> '' then
      PathParts.Add('slot-id=' + EncodeURIComponent(AURI.SlotID));
    
    // Build query attributes
    if AURI.PINValue <> '' then
      QueryParts.Add('pin-value=' + EncodeURIComponent(AURI.PINValue));
    if AURI.PINSource <> '' then
      QueryParts.Add('pin-source=' + EncodeURIComponent(AURI.PINSource));
    if AURI.ModuleName <> '' then
      QueryParts.Add('module-name=' + EncodeURIComponent(AURI.ModuleName));
    if AURI.ModulePath <> '' then
      QueryParts.Add('module-path=' + EncodeURIComponent(AURI.ModulePath));
    
    // Construct URI
    Result := 'pkcs11:';';
    Result := Result + PathParts.DelimitedText;
    
    if Length(QueryParts) > 0 then
    begin
      Result := Result + '?' + QueryParts.DelimitedText;
    end;
  finally
  end;
end;

class function TPKCS11URIParser.Validate(const AURIString: string; out AError: string): Boolean;
var
  URI: TPKCS11URI;
begin
  Result := False;
  AError := '';
  
  try
    // Check basic format
    if not IsPKCS11URI(AURIString) then
    begin
      AError := 'URI must start with "pkcs11:"';
      Exit;
    end;
    
    // Try to parse
    URI := Parse(AURIString);
    
    // Validate that at least one identifying attribute is present
    if not URI.IsValid then
    begin
      AError := 'URI must contain at least one identifying attribute (token, object, or id)';
      Exit;
    end;
    
    // Warn about insecure PIN usage
    if URI.PINValue <> '' then
    begin
      AError := 'WARNING: pin-value in URI is insecure. Use pin-source instead.';
      // Don't fail validation, just warn
    end;
    
    Result := True;
  except
    on E: Exception do
    begin
      AError := 'Parse error: ' + E.Message;
      Result := False;
    end;
  end;
end;

end.
