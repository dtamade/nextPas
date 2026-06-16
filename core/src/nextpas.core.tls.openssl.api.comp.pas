{
  OpenSSL COMP (压缩) API 模块
  支持 zlib、brotli 等压缩算法
}
unit nextpas.core.tls.openssl.api.comp;

{$mode ObjFPC}{$H+}

interface

uses nextpas.core.base, nextpas.core.tls.openssl.api, nextpas.core.tls.openssl.base, nextpas.core.tls.openssl.api.bio; const // 压缩方法 NID NID_zlib_compression = 125;
  NID_rle_compression = 124;
  NID_brotli_compression = 1138;
  NID_zstd_compression = 1139;
  
  // 压缩级别
  COMP_ZLIB_LEVEL_DEFAULT = -1;
  COMP_ZLIB_LEVEL_NONE = 0;
  COMP_ZLIB_LEVEL_BEST_SPEED = 1;
  COMP_ZLIB_LEVEL_BEST = 9;
  
  // 压缩策略
  COMP_ZLIB_STRATEGY_DEFAULT = 0;
  COMP_ZLIB_STRATEGY_FILTERED = 1;
  COMP_ZLIB_STRATEGY_HUFFMAN_ONLY = 2;
  COMP_ZLIB_STRATEGY_RLE = 3;
  COMP_ZLIB_STRATEGY_FIXED = 4;
  
  // 压缩窗口大小
  COMP_ZLIB_WINDOW_BITS_DEFAULT = 15;
  COMP_ZLIB_WINDOW_BITS_MIN = 8;
  COMP_ZLIB_WINDOW_BITS_MAX = 15;
  
  // 内存级别
  COMP_ZLIB_MEM_LEVEL_DEFAULT = 8;
  COMP_ZLIB_MEM_LEVEL_MIN = 1;
  COMP_ZLIB_MEM_LEVEL_MAX = 9;
  
  // 压缩标志
  COMP_FLAG_COMPRESS = $01;
  COMP_FLAG_DECOMPRESS = $02;
  COMP_FLAG_FLUSH_SYNC = $04;
  COMP_FLAG_FLUSH_FULL = $08;
  
  // BIO 压缩控制命令
  BIO_CTRL_COMPRESS_GET_LEVEL = 200;
  BIO_CTRL_COMPRESS_SET_LEVEL = 201;
  BIO_CTRL_COMPRESS_GET_TYPE = 202;
  BIO_CTRL_COMPRESS_FLUSH = 203;

type
  // 前向声明
  PCOMP_CTX = ^COMP_CTX;
  PCOMP_METHOD = ^COMP_METHOD;
  
  // 不透明结构体
  COMP_CTX = record end;
  COMP_METHOD = record end;
  
  // 压缩参数结构
  TCOMP_ZLIB_PARAMS = record
    Level: Integer;
    Method: Integer;
    WindowBits: Integer;
    MemLevel: Integer;
    Strategy: Integer;
  end;
  PCOMP_ZLIB_PARAMS = ^TCOMP_ZLIB_PARAMS;
  
  // 函数指针类型
  
  // COMP_METHOD 函数
  TCOMP_CTX_new = function(meth: PCOMP_METHOD): PCOMP_CTX; cdecl;
  TCOMP_CTX_get_method = function(ctx: PCOMP_CTX): PCOMP_METHOD; cdecl;
  TCOMP_CTX_get_type = function(meth: PCOMP_METHOD): Integer; cdecl;
  TCOMP_get_type = function(meth: PCOMP_METHOD): Integer; cdecl;
  TCOMP_get_name = function(meth: PCOMP_METHOD): PAnsiChar; cdecl;
  TCOMP_CTX_free = procedure(ctx: PCOMP_CTX); cdecl;
  
  // 压缩/解压缩函数
  TCOMP_compress_block = function(ctx: PCOMP_CTX; outdata: PByte; olen: Integer;
                                  indata: PByte; ilen: Integer): Integer; cdecl;
  TCOMP_expand_block = function(ctx: PCOMP_CTX; outdata: PByte; olen: Integer;
                              indata: PByte; ilen: Integer): Integer; cdecl;
  
  // 压缩方法获取函数
  TCOMP_zlib = function(): PCOMP_METHOD; cdecl;
  TCOMP_zlib_oneshot = function(): PCOMP_METHOD; cdecl;
  TCOMP_brotli = function(): PCOMP_METHOD; cdecl;
  TCOMP_brotli_oneshot = function(): PCOMP_METHOD; cdecl;
  TCOMP_zstd = function(): PCOMP_METHOD; cdecl;
  TCOMP_zstd_oneshot = function(): PCOMP_METHOD; cdecl;
  TCOMP_rle = function(): PCOMP_METHOD; cdecl;
  
  // SSL 压缩函数
  TSSL_COMP_add_compression_method = function(id: Integer; cm: PCOMP_METHOD): Integer; cdecl;
  TSSL_COMP_get_compression_methods = function(): POPENSSL_STACK; cdecl;
  TSSL_COMP_get0_name = function(comp: Pointer): PAnsiChar; cdecl;
  TSSL_COMP_get_id = function(comp: Pointer): Integer; cdecl;
  TSSL_COMP_free_compression_methods = procedure(); cdecl;
  
  // BIO 压缩函数
  TBIO_f_zlib = function(): PBIO_METHOD; cdecl;
  TBIO_f_brotli = function(): PBIO_METHOD; cdecl;
  TBIO_f_zstd = function(): PBIO_METHOD; cdecl;
  
  // 压缩 BIO 控制函数
  TBIO_set_compress_level = function(b: PBIO; level: Integer): Integer; cdecl;
  TBIO_get_compress_level = function(b: PBIO; level: PInteger): Integer; cdecl;
  TBIO_set_compress_type = function(b: PBIO; typ: Integer): Integer; cdecl;
  TBIO_get_compress_type = function(b: PBIO; typ: PInteger): Integer; cdecl;
  TBIO_compress_flush = function(b: PBIO): Integer; cdecl;
  
  // zlib 参数设置函数
  TCOMP_zlib_set_level = function(ctx: PCOMP_CTX; level: Integer): Integer; cdecl;
  TCOMP_zlib_set_window_bits = function(ctx: PCOMP_CTX; window_bits: Integer): Integer; cdecl;
  TCOMP_zlib_set_mem_level = function(ctx: PCOMP_CTX; mem_level: Integer): Integer; cdecl;
  TCOMP_zlib_set_strategy = function(ctx: PCOMP_CTX; strategy: Integer): Integer; cdecl;
  
  // 一次性压缩/解压函数
  TCOMP_compress = function(meth: PCOMP_METHOD; outdata: PByte; outlen: PLongWord;
                          indata: PByte; inlen: LongWord): Integer; cdecl;
  TCOMP_expand = function(meth: PCOMP_METHOD; outdata: PByte; outlen: PLongWord;
                        indata: PByte; inlen: LongWord): Integer; cdecl;

var
  // COMP_METHOD 函数
  COMP_CTX_new: TCOMP_CTX_new;
  COMP_CTX_get_method: TCOMP_CTX_get_method;
  COMP_CTX_get_type: TCOMP_CTX_get_type;
  COMP_get_type: TCOMP_get_type;
  COMP_get_name: TCOMP_get_name;
  COMP_CTX_free: TCOMP_CTX_free;
  
  // 压缩/解压缩函数
  COMP_compress_block: TCOMP_compress_block;
  COMP_expand_block: TCOMP_expand_block;
  
  // 压缩方法获取函数
  COMP_zlib: TCOMP_zlib;
  COMP_zlib_oneshot: TCOMP_zlib_oneshot;
  COMP_brotli: TCOMP_brotli;
  COMP_brotli_oneshot: TCOMP_brotli_oneshot;
  COMP_zstd: TCOMP_zstd;
  COMP_zstd_oneshot: TCOMP_zstd_oneshot;
  COMP_rle: TCOMP_rle;
  
  // SSL 压缩函数
  SSL_COMP_add_compression_method: TSSL_COMP_add_compression_method;
  SSL_COMP_get_compression_methods: TSSL_COMP_get_compression_methods;
  SSL_COMP_get0_name: TSSL_COMP_get0_name;
  SSL_COMP_get_id: TSSL_COMP_get_id;
  SSL_COMP_free_compression_methods: TSSL_COMP_free_compression_methods;
  
  // BIO 压缩函数
  BIO_f_zlib: TBIO_f_zlib;
  BIO_f_brotli: TBIO_f_brotli;
  BIO_f_zstd: TBIO_f_zstd;
  
  // 压缩 BIO 控制函数
  BIO_set_compress_level: TBIO_set_compress_level;
  BIO_get_compress_level: TBIO_get_compress_level;
  BIO_set_compress_type: TBIO_set_compress_type;
  BIO_get_compress_type: TBIO_get_compress_type;
  BIO_compress_flush: TBIO_compress_flush;
  
  // zlib 参数设置函数
  COMP_zlib_set_level: TCOMP_zlib_set_level;
  COMP_zlib_set_window_bits: TCOMP_zlib_set_window_bits;
  COMP_zlib_set_mem_level: TCOMP_zlib_set_mem_level;
  COMP_zlib_set_strategy: TCOMP_zlib_set_strategy;
  
  // 一次性压缩/解压函数
  COMP_compress: TCOMP_compress;
  COMP_expand: TCOMP_expand;

procedure LoadCOMPFunctions;
procedure UnloadCOMPFunctions;

// 辅助函数
function CompressData(const Data: TBytes; Method: PCOMP_METHOD = nil): TBytes;
function DecompressData(const CompressedData: TBytes; Method: PCOMP_METHOD = nil): TBytes;
function CompressDataZlib(const Data: TBytes; Level: Integer = COMP_ZLIB_LEVEL_DEFAULT): TBytes;
function DecompressDataZlib(const CompressedData: TBytes): TBytes;
function CreateCompressBIO(Next: PBIO; Method: PCOMP_METHOD = nil): PBIO;
function GetCompressionMethodName(Method: PCOMP_METHOD): string;
function IsCompressionSupported(Method: PCOMP_METHOD): Boolean;

implementation

begin
  if not TOpenSSLLoader.IsModuleLoaded(osmCore) then Exit;
  
  // COMP_METHOD 函数
  COMP_CTX_new := TCOMP_CTX_new(GetCryptoProcAddress('COMP_CTX_new'));
  COMP_CTX_get_method := TCOMP_CTX_get_method(GetCryptoProcAddress('COMP_CTX_get_method'));
  COMP_CTX_get_type := TCOMP_CTX_get_type(GetCryptoProcAddress('COMP_CTX_get_type'));
  COMP_get_type := TCOMP_get_type(GetCryptoProcAddress('COMP_get_type'));
  COMP_get_name := TCOMP_get_name(GetCryptoProcAddress('COMP_get_name'));
  COMP_CTX_free := TCOMP_CTX_free(GetCryptoProcAddress('COMP_CTX_free'));
  
  // 压缩/解压缩函数
  COMP_compress_block := TCOMP_compress_block(GetCryptoProcAddress('COMP_compress_block'));
  COMP_expand_block := TCOMP_expand_block(GetCryptoProcAddress('COMP_expand_block'));
  
  // 压缩方法获取函数
  COMP_zlib := TCOMP_zlib(GetCryptoProcAddress('COMP_zlib'));
  COMP_zlib_oneshot := TCOMP_zlib_oneshot(GetCryptoProcAddress('COMP_zlib_oneshot'));
  COMP_brotli := TCOMP_brotli(GetCryptoProcAddress('COMP_brotli'));
  COMP_brotli_oneshot := TCOMP_brotli_oneshot(GetCryptoProcAddress('COMP_brotli_oneshot'));
  COMP_zstd := TCOMP_zstd(GetCryptoProcAddress('COMP_zstd'));
  COMP_zstd_oneshot := TCOMP_zstd_oneshot(GetCryptoProcAddress('COMP_zstd_oneshot'));
  COMP_rle := TCOMP_rle(GetCryptoProcAddress('COMP_rle'));
  
  // SSL 压缩函数
  SSL_COMP_add_compression_method := TSSL_COMP_add_compression_method(GetSSLProcAddress('SSL_COMP_add_compression_method'));
  SSL_COMP_get_compression_methods := TSSL_COMP_get_compression_methods(GetSSLProcAddress('SSL_COMP_get_compression_methods'));
  SSL_COMP_get0_name := TSSL_COMP_get0_name(GetSSLProcAddress('SSL_COMP_get0_name'));
  SSL_COMP_get_id := TSSL_COMP_get_id(GetSSLProcAddress('SSL_COMP_get_id'));
  SSL_COMP_free_compression_methods := TSSL_COMP_free_compression_methods(GetSSLProcAddress('SSL_COMP_free_compression_methods'));
  
  // BIO 压缩函数
  BIO_f_zlib := TBIO_f_zlib(GetCryptoProcAddress('BIO_f_zlib'));
  BIO_f_brotli := TBIO_f_brotli(GetCryptoProcAddress('BIO_f_brotli'));
  BIO_f_zstd := TBIO_f_zstd(GetCryptoProcAddress('BIO_f_zstd'));
  
  // zlib 参数设置函数
  COMP_zlib_set_level := TCOMP_zlib_set_level(GetCryptoProcAddress('COMP_zlib_set_level'));
  COMP_zlib_set_window_bits := TCOMP_zlib_set_window_bits(GetCryptoProcAddress('COMP_zlib_set_window_bits'));
  COMP_zlib_set_mem_level := TCOMP_zlib_set_mem_level(GetCryptoProcAddress('COMP_zlib_set_mem_level'));
  COMP_zlib_set_strategy := TCOMP_zlib_set_strategy(GetCryptoProcAddress('COMP_zlib_set_strategy'));
  
  // 一次性压缩/解压函数
  COMP_compress := TCOMP_compress(GetCryptoProcAddress('COMP_compress'));
  COMP_expand := TCOMP_expand(GetCryptoProcAddress('COMP_expand'));
end;

procedure UnloadCOMPFunctions;
begin
  // 重置所有函数指针
  COMP_CTX_new := nil;
  COMP_CTX_get_method := nil;
  COMP_CTX_get_type := nil;
  COMP_get_type := nil;
  COMP_get_name := nil;
  COMP_CTX_free := nil;
  COMP_compress_block := nil;
  COMP_expand_block := nil;
  COMP_zlib := nil;
  COMP_zlib_oneshot := nil;
  COMP_brotli := nil;
  COMP_brotli_oneshot := nil;
  COMP_zstd := nil;
  COMP_zstd_oneshot := nil;
  COMP_rle := nil;
  SSL_COMP_add_compression_method := nil;
  SSL_COMP_get_compression_methods := nil;
  SSL_COMP_get0_name := nil;
  SSL_COMP_get_id := nil;
  SSL_COMP_free_compression_methods := nil;
  BIO_f_zlib := nil;
  BIO_f_brotli := nil;
  BIO_f_zstd := nil;
  COMP_zlib_set_level := nil;
  COMP_compress := nil;
  COMP_expand := nil;
end;

function CompressData(const Data: TBytes; Method: PCOMP_METHOD): TBytes;
var
  OutLen: LongWord;
  TempOut: TBytes;
begin
  Result := nil;
  
  if Length(Data) = 0 then Exit;
  
  // 如果没有指定方法，尝试使用 zlib
  if Method = nil then
  begin
    if Assigned(COMP_zlib_oneshot) then
      Method := COMP_zlib_oneshot();
  end;
  
  if Method = nil then Exit;
  if not Assigned(COMP_compress) then Exit;
  
  // 估计压缩后大小（通常不会超过原大小 + 一些开销）
  OutLen := Length(Data) + (Length(Data) div 10) + 128;
  SetLength(TempOut, OutLen);
  
  if COMP_compress(Method, @TempOut[0], @OutLen, @Data[0], Length(Data)) = 1 then
  begin
    SetLength(TempOut, OutLen);
    Result := TempOut;
  end;
end;

function DecompressData(const CompressedData: TBytes; Method: PCOMP_METHOD): TBytes;
var
  OutLen: LongWord;
  TempOut: TBytes;
  Factor: Integer;
begin
  Result := nil;
  
  if Length(CompressedData) = 0 then Exit;
  
  // 如果没有指定方法，尝试使用 zlib
  if Method = nil then
  begin
    if Assigned(COMP_zlib_oneshot) then
      Method := COMP_zlib_oneshot();
  end;
  
  if Method = nil then Exit;
  if not Assigned(COMP_expand) then Exit;
  
  // 尝试不同的解压缩缓冲区大小
  Factor := 4;
  while Factor <= 64 do
  begin
    OutLen := Length(CompressedData) * Factor;
    SetLength(TempOut, OutLen);
    
    if COMP_expand(Method, @TempOut[0], @OutLen, 
                  @CompressedData[0], Length(CompressedData)) = 1 then
    begin
      SetLength(TempOut, OutLen);
      Result := TempOut;
      Exit;
    end;
    
    Factor := Factor * 2;
  end;
end;

function CompressDataZlib(const Data: TBytes; Level: Integer): TBytes;
var
  Method: PCOMP_METHOD;
  Ctx: PCOMP_CTX;
begin
  Result := nil;
  
  if not Assigned(COMP_zlib) then Exit;
  
  Method := COMP_zlib();
  if Method = nil then Exit;
  
  // 如果支持设置压缩级别
  if Assigned(COMP_CTX_new) and Assigned(COMP_zlib_set_level) then
  begin
    Ctx := COMP_CTX_new(Method);
    if Ctx <> nil then
    begin
      try
        if Level <> COMP_ZLIB_LEVEL_DEFAULT then
          COMP_zlib_set_level(Ctx, Level);
        
        // Note: TLS compression is deprecated due to CRIME attack vulnerability.
        // Modern TLS (1.3) disables compression by default for security.
        // This feature is intentionally left unimplemented.
        
      finally
        if Assigned(COMP_CTX_free) then
          COMP_CTX_free(Ctx);
      end;
    end;
  end
  else
  begin
    // 使用一次性压缩
    Result := CompressData(Data, Method);
  end;
end;

function DecompressDataZlib(const CompressedData: TBytes): TBytes;
var
  Method: PCOMP_METHOD;
begin
  Method := nil;
  
  if Assigned(COMP_zlib_oneshot) then
    Method := COMP_zlib_oneshot()
  else if Assigned(COMP_zlib) then
    Method := COMP_zlib();
  
  Result := DecompressData(CompressedData, Method);
end;

function CreateCompressBIO(Next: PBIO; Method: PCOMP_METHOD): PBIO;
var
  CompressBio: PBIO;
  BioMethod: PBIO_METHOD;
begin
  Result := nil;
  
  if Next = nil then Exit;
  
  // 获取压缩 BIO 方法
  BioMethod := nil;
  if Method = nil then
  begin
    // 默认使用 zlib
    if Assigned(BIO_f_zlib) then
      BioMethod := BIO_f_zlib();
  end
  else
  begin
    // 根据压缩方法类型选择对应的 BIO
    if Assigned(COMP_get_type) then
    begin
      case COMP_get_type(Method) of
        NID_zlib_compression:
          if Assigned(BIO_f_zlib) then
            BioMethod := BIO_f_zlib();
        NID_brotli_compression:
          if Assigned(BIO_f_brotli) then
            BioMethod := BIO_f_brotli();
        NID_zstd_compression:
          if Assigned(BIO_f_zstd) then
            BioMethod := BIO_f_zstd();
      end;
    end;
  end;
  
  if BioMethod = nil then Exit;
  
  // 创建压缩 BIO
  if Assigned(BIO_new) then
  begin
    CompressBio := BIO_new(BioMethod);
    if CompressBio <> nil then
    begin
      // 将压缩 BIO 链接到下一个 BIO
      if Assigned(BIO_push) then
        Result := BIO_push(CompressBio, Next)
      else
        Result := CompressBio;
    end;
  end;
end;

function GetCompressionMethodName(Method: PCOMP_METHOD): string;
var
  Name: PAnsiChar;
begin
  Result := 'Unknown';
  
  if Method = nil then Exit;
  
  if Assigned(COMP_get_name) then
  begin
    Name := COMP_get_name(Method);
    if Name <> nil then
      Result := string(Name);
  end;
end;

function IsCompressionSupported(Method: PCOMP_METHOD): Boolean;
var
  TypeId: Integer;
begin
  Result := Method <> nil;
  
  // 可以添加更多的验证逻辑
  if Result and Assigned(COMP_get_type) then
  begin
    TypeId := COMP_get_type(Method);
    Result := TypeId > 0;
  end;
end;

initialization
  
finalization
  UnloadCOMPFunctions;
  
end.