{******************************************************************************}
{                                                                              }
{  nextpas.core.tls.openssl.api.txt_db - OpenSSL TXT_DB Module Pascal Binding           }
{                                                                              }
{  Copyright (c) 2024 fafafa                                                  }
{                                                                              }
{******************************************************************************}
unit nextpas.core.tls.openssl.api.txt_db;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, Classes,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.consts;

type
  { TXT_DB types }
  TXT_DB = record
    num_fields: TOpenSSLInt;
    data: POPENSSL_STACK;
    index_: PPointer;
    index_comp: PPointer;
    index_comp_data: PPointer;
    qual: PPointer;
    error: TOpenSSLLong;
  end;
  PTXT_DB = ^TXT_DB;

  { TXT_DB callback types }
  TTXT_DB_qual_func = function(data: PPointer): TOpenSSLInt; cdecl;
  TTXT_DB_index_qual_func = function(data: PPChar; n: TOpenSSLInt): TOpenSSLInt; cdecl;
  TTXT_DB_comp_func = function(const a, b: PPointer): TOpenSSLInt; cdecl;
  TTXT_DB_hash_func = function(const a: PPointer): TOpenSSLULong; cdecl;

  { Error constants }
const
  DB_ERROR = 1;
  DB_ERROR_OK = 0;
  DB_ERROR_MALLOC = 1;
  DB_ERROR_INDEX_CLASH = 2;
  DB_ERROR_INDEX_OUT_OF_RANGE = 3;
  DB_ERROR_NO_INDEX = 4;
  DB_ERROR_INSERT_INDEX_CLASH = 5;
  DB_ERROR_WRONG_NUM_FIELDS = 6;

type
  { Function pointers for dynamic loading }
  TTXTDBNew = function(num_fields: TOpenSSLInt): PTXT_DB; cdecl;
  TTXTDBFree = procedure(db: PTXT_DB); cdecl;
  TTXTDBRead = function(bio_in: PBIO; num: TOpenSSLInt): PTXT_DB; cdecl;
  TTXTDBWrite = function(bio_out: PBIO; db: PTXT_DB): TOpenSSLLong; cdecl;
  TTXTDBInsert = function(db: PTXT_DB; row: PPChar): TOpenSSLInt; cdecl;
  TTXTDBDelete = function(db: PTXT_DB; row: PPChar): TOpenSSLInt; cdecl;
  TTXTDBUpdate = function(db: PTXT_DB; row: PPChar; old_row: PPChar): TOpenSSLInt; cdecl;
  TTXTDBGetByIndex = function(db: PTXT_DB; idx: TOpenSSLInt; value: PPChar): PPChar; cdecl;
  TTXTDBCreateIndex = function(db: PTXT_DB; field: TOpenSSLInt; 
                              qual: TTXT_DB_qual_func; hash: TTXT_DB_hash_func; 
                              cmp: TTXT_DB_comp_func): TOpenSSLInt; cdecl;

var
  { Function variables }
  TXT_DB_new: TTXTDBNew = nil;
  TXT_DB_free: TTXTDBFree = nil;
  TXT_DB_read: TTXTDBRead = nil;
  TXT_DB_write: TTXTDBWrite = nil;
  TXT_DB_insert: TTXTDBInsert = nil;
  TXT_DB_delete: TTXTDBDelete = nil;
  TXT_DB_update: TTXTDBUpdate = nil;
  TXT_DB_get_by_index: TTXTDBGetByIndex = nil;
  TXT_DB_create_index: TTXTDBCreateIndex = nil;

{ Load/Unload functions }
function LoadTXTDB(const ALibCrypto: THandle): Boolean;
procedure UnloadTXTDB;

{ Helper functions }
function TXTDBReadFromFile(const FileName: string; NumFields: Integer): PTXT_DB;
function TXTDBWriteToFile(db: PTXT_DB; const FileName: string): Boolean;
function TXTDBAddRow(db: PTXT_DB; const Fields: array of string): Boolean;
function TXTDBFindRow(db: PTXT_DB; FieldIndex: Integer; const Value: string): PPChar;

implementation

uses
  nextpas.core.tls.openssl.api.utils;

const
  { TXT_DB function bindings for batch loading }
  TXTDB_BINDINGS: array[0..8] of TFunctionBinding = (
    (Name: 'TXT_DB_new';          FuncPtr: @TXT_DB_new;          Required: True),
    (Name: 'TXT_DB_free';         FuncPtr: @TXT_DB_free;         Required: True),
    (Name: 'TXT_DB_read';         FuncPtr: @TXT_DB_read;         Required: False),
    (Name: 'TXT_DB_write';        FuncPtr: @TXT_DB_write;        Required: False),
    (Name: 'TXT_DB_insert';       FuncPtr: @TXT_DB_insert;       Required: False),
    (Name: 'TXT_DB_delete';       FuncPtr: @TXT_DB_delete;       Required: False),
    (Name: 'TXT_DB_update';       FuncPtr: @TXT_DB_update;       Required: False),
    (Name: 'TXT_DB_get_by_index'; FuncPtr: @TXT_DB_get_by_index; Required: False),
    (Name: 'TXT_DB_create_index'; FuncPtr: @TXT_DB_create_index; Required: False)
  );

function LoadTXTDB(const ALibCrypto: THandle): Boolean;
begin
  Result := False;
  if TOpenSSLLoader.IsModuleLoaded(osmTXTDB) then Exit(True);
  if ALibCrypto = 0 then Exit;

  { Batch load all TXT_DB functions }
  TOpenSSLLoader.LoadFunctions(ALibCrypto, TXTDB_BINDINGS);

  Result := Assigned(TXT_DB_new) and Assigned(TXT_DB_free);
  TOpenSSLLoader.SetModuleLoaded(osmTXTDB, Result);
end;

procedure UnloadTXTDB;
begin
  if not TOpenSSLLoader.IsModuleLoaded(osmTXTDB) then Exit;

  { Clear all function pointers }
  TOpenSSLLoader.ClearFunctions(TXTDB_BINDINGS);

  TOpenSSLLoader.SetModuleLoaded(osmTXTDB, False);
end;

{ Helper functions }

function TXTDBReadFromFile(const FileName: string; NumFields: Integer): PTXT_DB;
var
  bio: PBIO;
begin
  Result := nil;
  if not FileExists(FileName) then Exit;
  if not Assigned(BIO_new_file) or not Assigned(BIO_free) then Exit;
  
  bio := BIO_new_file(PChar(FileName), 'r');
  if bio = nil then Exit;
  
  try
    if Assigned(TXT_DB_read) then
      Result := TXT_DB_read(bio, NumFields);
  finally
    BIO_free(bio);
  end;
end;

function TXTDBWriteToFile(db: PTXT_DB; const FileName: string): Boolean;
var
  bio: PBIO;
begin
  Result := False;
  if db = nil then Exit;
  if not Assigned(BIO_new_file) or not Assigned(BIO_free) then Exit;
  
  bio := BIO_new_file(PChar(FileName), 'w');
  if bio = nil then Exit;
  
  try
    if Assigned(TXT_DB_write) then
      Result := TXT_DB_write(bio, db) > 0;
  finally
    BIO_free(bio);
  end;
end;

function TXTDBAddRow(db: PTXT_DB; const Fields: array of string): Boolean;
var
  Row: PPChar;
  i: Integer;
begin
  Result := False;
  if (db = nil) or (Length(Fields) = 0) then Exit;
  
  GetMem(Row, SizeOf(PChar) * Length(Fields));
  try
    for i := 0 to High(Fields) do
      Row[i] := StrAlloc(Length(Fields[i]) + 1);
      
    for i := 0 to High(Fields) do
      StrPCopy(Row[i], Fields[i]);
      
    if Assigned(TXT_DB_insert) then
      Result := TXT_DB_insert(db, Row) = 1;
      
    if not Result then
    begin
      for i := 0 to High(Fields) do
        StrDispose(Row[i]);
    end;
  finally
    FreeMem(Row);
  end;
end;

function TXTDBFindRow(db: PTXT_DB; FieldIndex: Integer; const Value: string): PPChar;
var
  SearchVal: PChar;
begin
  Result := nil;
  if (db = nil) or not Assigned(TXT_DB_get_by_index) then Exit;
  
  SearchVal := StrAlloc(Length(Value) + 1);
  try
    StrPCopy(SearchVal, Value);
    Result := TXT_DB_get_by_index(db, FieldIndex, @SearchVal);
  finally
    StrDispose(SearchVal);
  end;
end;

initialization

finalization
  UnloadTXTDB;

end.
