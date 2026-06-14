{$mode ObjFPC}{$H+}

unit nextpas.core.tls.openssl.api.buffer;

interface

uses SysUtils, nextpas.core.tls.openssl.base, nextpas.core.tls.openssl.loader;

type
  // Buffer 结构体
  PBUF_MEM = ^BUF_MEM;
  BUF_MEM = record
    length: NativeUInt;
    data: PAnsiChar;
    max: NativeUInt;
    flags: Cardinal;
  end;

const
  // Buffer flags
  BUF_MEM_FLAG_SECURE = $01;
  
type
  // 函数类型定义
  TBUF_MEM_new = function(): PBUF_MEM; cdecl;
  TBUF_MEM_new_ex = function(flags: Cardinal): PBUF_MEM; cdecl;
  TBUF_MEM_free = procedure(a: PBUF_MEM); cdecl;
  TBUF_MEM_grow = function(str: PBUF_MEM; len: NativeUInt): NativeUInt; cdecl;
  TBUF_MEM_grow_clean = function(str: PBUF_MEM; len: NativeUInt): NativeUInt; cdecl;
  TBUF_strdup = function(const str: PAnsiChar): PAnsiChar; cdecl;
  TBUF_strndup = function(const str: PAnsiChar; siz: NativeUInt): PAnsiChar; cdecl;
  TBUF_memdup = function(const data: Pointer; siz: NativeUInt): Pointer; cdecl;
  TBUF_reverse = procedure(out_: PByte; const in_: PByte; siz: NativeUInt); cdecl;
  TBUF_strlcpy = function(dst: PAnsiChar; const src: PAnsiChar; siz: NativeUInt): NativeUInt; cdecl;
  TBUF_strlcat = function(dst: PAnsiChar; const src: PAnsiChar; siz: NativeUInt): NativeUInt; cdecl;

var
  // 函数指针
  BUF_MEM_new: TBUF_MEM_new = nil;
  BUF_MEM_new_ex: TBUF_MEM_new_ex = nil;
  BUF_MEM_free: TBUF_MEM_free = nil;
  BUF_MEM_grow: TBUF_MEM_grow = nil;
  BUF_MEM_grow_clean: TBUF_MEM_grow_clean = nil;
  BUF_strdup: TBUF_strdup = nil;
  BUF_strndup: TBUF_strndup = nil;
  BUF_memdup: TBUF_memdup = nil;
  BUF_reverse: TBUF_reverse = nil;
  BUF_strlcpy: TBUF_strlcpy = nil;
  BUF_strlcat: TBUF_strlcat = nil;

// 辅助函数
function CreateBuffer(InitialSize: NativeUInt): PBUF_MEM; overload;
function CreateBuffer: PBUF_MEM; overload;
function CreateSecureBuffer(InitialSize: NativeUInt): PBUF_MEM; overload;
function CreateSecureBuffer: PBUF_MEM; overload;
procedure FreeBuffer(var Buffer: PBUF_MEM);
function GrowBuffer(Buffer: PBUF_MEM; NewSize: NativeUInt): Boolean;
function AppendToBuffer(Buffer: PBUF_MEM; const Data: Pointer; DataLen: NativeUInt): Boolean;
function AppendStringToBuffer(Buffer: PBUF_MEM; const Str: string): Boolean;
function BufferToBytes(Buffer: PBUF_MEM): TBytes;
function BufferToString(Buffer: PBUF_MEM): string;
function DuplicateString(const Str: string): PAnsiChar;
function DuplicateData(const Data: TBytes): Pointer;

// 模块加载和卸载
procedure LoadBufferModule(ALibCrypto: THandle);
procedure UnloadBufferModule;

implementation

const
  { 函数绑定数组 - 用于批量加载 Buffer API 函数 }
  BufferBindings: array[0..10] of TFunctionBinding = (
    (Name: 'BUF_MEM_new';       FuncPtr: @BUF_MEM_new;       Required: False),
    (Name: 'BUF_MEM_new_ex';    FuncPtr: @BUF_MEM_new_ex;    Required: False),
    (Name: 'BUF_MEM_free';      FuncPtr: @BUF_MEM_free;      Required: False),
    (Name: 'BUF_MEM_grow';      FuncPtr: @BUF_MEM_grow;      Required: False),
    (Name: 'BUF_MEM_grow_clean'; FuncPtr: @BUF_MEM_grow_clean; Required: False),
    (Name: 'BUF_strdup';        FuncPtr: @BUF_strdup;        Required: False),
    (Name: 'BUF_strndup';       FuncPtr: @BUF_strndup;       Required: False),
    (Name: 'BUF_memdup';        FuncPtr: @BUF_memdup;        Required: False),
    (Name: 'BUF_reverse';       FuncPtr: @BUF_reverse;       Required: False),
    (Name: 'BUF_strlcpy';       FuncPtr: @BUF_strlcpy;       Required: False),
    (Name: 'BUF_strlcat';       FuncPtr: @BUF_strlcat;       Required: False)
  );

procedure LoadBufferModule(ALibCrypto: THandle);
begin
  if ALibCrypto = 0 then Exit;
  TOpenSSLLoader.LoadFunctions(ALibCrypto, BufferBindings);
end;

procedure UnloadBufferModule;
begin
  TOpenSSLLoader.ClearFunctions(BufferBindings);
end;

// 辅助函数实现
function CreateBuffer: PBUF_MEM;
begin
  Result := CreateBuffer(0);
end;

function CreateBuffer(InitialSize: NativeUInt): PBUF_MEM;
begin
  Result := nil;
  if not Assigned(BUF_MEM_new) then Exit;
  
  Result := BUF_MEM_new();
  if Assigned(Result) and (InitialSize > 0) then
  begin
    if Assigned(BUF_MEM_grow) then
    begin
      if BUF_MEM_grow(Result, InitialSize) = 0 then
      begin
        if Assigned(BUF_MEM_free) then
          BUF_MEM_free(Result);
        Result := nil;
      end;
    end;
  end;
end;

function CreateSecureBuffer: PBUF_MEM;
begin
  Result := CreateSecureBuffer(0);
end;

function CreateSecureBuffer(InitialSize: NativeUInt): PBUF_MEM;
begin
  Result := nil;
  if not Assigned(BUF_MEM_new_ex) then Exit;
  
  Result := BUF_MEM_new_ex(BUF_MEM_FLAG_SECURE);
  if Assigned(Result) and (InitialSize > 0) then
  begin
    if Assigned(BUF_MEM_grow_clean) then
    begin
      if BUF_MEM_grow_clean(Result, InitialSize) = 0 then
      begin
        if Assigned(BUF_MEM_free) then
          BUF_MEM_free(Result);
        Result := nil;
      end;
    end;
  end;
end;

procedure FreeBuffer(var Buffer: PBUF_MEM);
begin
  if Assigned(Buffer) and Assigned(BUF_MEM_free) then
  begin
    BUF_MEM_free(Buffer);
    Buffer := nil;
  end;
end;

function GrowBuffer(Buffer: PBUF_MEM; NewSize: NativeUInt): Boolean;
begin
  Result := False;
  if not Assigned(Buffer) or not Assigned(BUF_MEM_grow) then Exit;
  
  Result := BUF_MEM_grow(Buffer, NewSize) <> 0;
end;

function AppendToBuffer(Buffer: PBUF_MEM; const Data: Pointer; DataLen: NativeUInt): Boolean;
var
  OldLen: NativeUInt;
begin
  Result := False;
  if not Assigned(Buffer) or not Assigned(Data) or (DataLen = 0) then Exit;
  if not Assigned(BUF_MEM_grow) then Exit;
  
  OldLen := Buffer^.length;
  if BUF_MEM_grow(Buffer, OldLen + DataLen) <> 0 then
  begin
    Move(Data^, (Buffer^.data + OldLen)^, DataLen);
    Result := True;
  end;
end;

function AppendStringToBuffer(Buffer: PBUF_MEM; const Str: string): Boolean;
var
  StrBytes: TBytes;
begin
  Result := False;
  if not Assigned(Buffer) or (Str = '') then Exit;
  
  StrBytes := TEncoding.UTF8.GetBytes(UnicodeString(Str));
  Result := AppendToBuffer(Buffer, @StrBytes[0], Length(StrBytes));
end;

function BufferToBytes(Buffer: PBUF_MEM): TBytes;
begin
  Result := nil;
  if not Assigned(Buffer) or (Buffer^.length = 0) then Exit;
  
  SetLength(Result, Buffer^.length);
  Move(Buffer^.data^, Result[0], Buffer^.length);
end;

function BufferToString(Buffer: PBUF_MEM): string;
var
  Bytes: TBytes;
begin
  Result := '';
  if not Assigned(Buffer) or (Buffer^.length = 0) then Exit;
  
  SetLength(Bytes, Buffer^.length);
  Move(Buffer^.data^, Bytes[0], Buffer^.length);
  Result := AnsiString(TEncoding.UTF8.GetString(Bytes));
end;

function DuplicateString(const Str: string): PAnsiChar;
var
  StrBytes: TBytes;
begin
  Result := nil;
  if not Assigned(BUF_strdup) then Exit;
  
  StrBytes := TEncoding.UTF8.GetBytes(UnicodeString(Str));
  Result := BUF_strdup(PAnsiChar(StrBytes));
end;

function DuplicateData(const Data: TBytes): Pointer;
begin
  Result := nil;
  if not Assigned(BUF_memdup) or (Length(Data) = 0) then Exit;
  
  Result := BUF_memdup(@Data[0], Length(Data));
end;

end.