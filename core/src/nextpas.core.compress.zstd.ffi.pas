unit nextpas.core.compress.zstd.ffi;
{** @desc libzstd C ABI 绑定（c2pas888 --header-unit 自动生成）。
       来源：/usr/include/zstd.h（libzstd 1.5.x, linux-x86_64-lp64）。
       再生成命令与黄金对照见 test_compress_zstd。勿手工编辑。 *}

interface

type
  TSizeT = QWord;
  TPtrdiffT = Int64;
  TWcharT = LongInt;
  TXBuiltinVaList = Pointer;
  TZSTDErrorCode = LongInt;
  TZSTDStrategy = LongInt;
  TZSTDCParameter = LongInt;
  TZSTDResetDirective = LongInt;
  TZSTDDParameter = LongInt;
  TZSTDEndDirective = LongInt;
  PZSTDErrorCode = ^TZSTDErrorCode;
  PTZSTDErrorCode = PZSTDErrorCode;
  PZSTDCCtxS = ^TZSTDCCtxS;
  PZSTDCCtx = ^TZSTDCCtx;
  PTZSTDCCtx = PZSTDCCtx;
  PZSTDDCtxS = ^TZSTDDCtxS;
  PZSTDDCtx = ^TZSTDDCtx;
  PTZSTDDCtx = PZSTDDCtx;
  PZSTDStrategy = ^TZSTDStrategy;
  PTZSTDStrategy = PZSTDStrategy;
  PZSTDCParameter = ^TZSTDCParameter;
  PTZSTDCParameter = PZSTDCParameter;
  PZSTDBounds = ^TZSTDBounds;
  PTZSTDBounds = PZSTDBounds;
  PZSTDResetDirective = ^TZSTDResetDirective;
  PTZSTDResetDirective = PZSTDResetDirective;
  PZSTDDParameter = ^TZSTDDParameter;
  PTZSTDDParameter = PZSTDDParameter;
  PZSTDInBuffer = ^TZSTDInBuffer;
  PTZSTDInBuffer = PZSTDInBuffer;
  PZSTDOutBuffer = ^TZSTDOutBuffer;
  PTZSTDOutBuffer = PZSTDOutBuffer;
  PZSTDCStream = ^TZSTDCStream;
  PTZSTDCStream = PZSTDCStream;
  PZSTDEndDirective = ^TZSTDEndDirective;
  PTZSTDEndDirective = PZSTDEndDirective;
  PZSTDDStream = ^TZSTDDStream;
  PTZSTDDStream = PZSTDDStream;
  PZSTDCDictS = ^TZSTDCDictS;
  PZSTDCDict = ^TZSTDCDict;
  PTZSTDCDict = PZSTDCDict;
  PZSTDDDictS = ^TZSTDDDictS;
  PZSTDDDict = ^TZSTDDDict;
  PTZSTDDDict = PZSTDDDict;
  TZSTDCCtxS = record
  end;
  TZSTDDCtxS = record
  end;
  TZSTDBounds = record
    error: TSizeT;
    lowerBound: LongInt;
    upperBound: LongInt;
  end;
  TZSTDInBuffer = record
    src: Pointer;
    size: TSizeT;
    pos: TSizeT;
  end;
  TZSTDOutBuffer = record
    dst: Pointer;
    size: TSizeT;
    pos: TSizeT;
  end;
  TZSTDCDictS = record
  end;
  TZSTDDDictS = record
  end;
  TZSTDCCtx = TZSTDCCtxS;
  TZSTDDCtx = TZSTDDCtxS;
  TZSTDCDict = TZSTDCDictS;
  TZSTDDDict = TZSTDDDictS;
  TZSTDCStream = TZSTDCCtx;
  TZSTDDStream = TZSTDDCtx;

const
  ZSTD_error_no_error = 0;
  ZSTD_error_GENERIC = 1;
  ZSTD_error_prefix_unknown = 10;
  ZSTD_error_version_unsupported = 12;
  ZSTD_error_frameParameter_unsupported = 14;
  ZSTD_error_frameParameter_windowTooLarge = 16;
  ZSTD_error_corruption_detected = 20;
  ZSTD_error_checksum_wrong = 22;
  ZSTD_error_literals_headerWrong = 24;
  ZSTD_error_dictionary_corrupted = 30;
  ZSTD_error_dictionary_wrong = 32;
  ZSTD_error_dictionaryCreation_failed = 34;
  ZSTD_error_parameter_unsupported = 40;
  ZSTD_error_parameter_combination_unsupported = 41;
  ZSTD_error_parameter_outOfBound = 42;
  ZSTD_error_tableLog_tooLarge = 44;
  ZSTD_error_maxSymbolValue_tooLarge = 46;
  ZSTD_error_maxSymbolValue_tooSmall = 48;
  ZSTD_error_cannotProduce_uncompressedBlock = 49;
  ZSTD_error_stabilityCondition_notRespected = 50;
  ZSTD_error_stage_wrong = 60;
  ZSTD_error_init_missing = 62;
  ZSTD_error_memory_allocation = 64;
  ZSTD_error_workSpace_tooSmall = 66;
  ZSTD_error_dstSize_tooSmall = 70;
  ZSTD_error_srcSize_wrong = 72;
  ZSTD_error_dstBuffer_null = 74;
  ZSTD_error_noForwardProgress_destFull = 80;
  ZSTD_error_noForwardProgress_inputEmpty = 82;
  ZSTD_error_frameIndex_tooLarge = 100;
  ZSTD_error_seekableIO = 102;
  ZSTD_error_dstBuffer_wrong = 104;
  ZSTD_error_srcBuffer_wrong = 105;
  ZSTD_error_sequenceProducer_failed = 106;
  ZSTD_error_externalSequences_invalid = 107;
  ZSTD_error_maxCode = 120;
  ZSTD_fast = 1;
  ZSTD_dfast = 2;
  ZSTD_greedy = 3;
  ZSTD_lazy = 4;
  ZSTD_lazy2 = 5;
  ZSTD_btlazy2 = 6;
  ZSTD_btopt = 7;
  ZSTD_btultra = 8;
  ZSTD_btultra2 = 9;
  ZSTD_c_compressionLevel = 100;
  ZSTD_c_windowLog = 101;
  ZSTD_c_hashLog = 102;
  ZSTD_c_chainLog = 103;
  ZSTD_c_searchLog = 104;
  ZSTD_c_minMatch = 105;
  ZSTD_c_targetLength = 106;
  ZSTD_c_strategy = 107;
  ZSTD_c_targetCBlockSize = 130;
  ZSTD_c_enableLongDistanceMatching = 160;
  ZSTD_c_ldmHashLog = 161;
  ZSTD_c_ldmMinMatch = 162;
  ZSTD_c_ldmBucketSizeLog = 163;
  ZSTD_c_ldmHashRateLog = 164;
  ZSTD_c_contentSizeFlag = 200;
  ZSTD_c_checksumFlag = 201;
  ZSTD_c_dictIDFlag = 202;
  ZSTD_c_nbWorkers = 400;
  ZSTD_c_jobSize = 401;
  ZSTD_c_overlapLog = 402;
  ZSTD_c_experimentalParam1 = 500;
  ZSTD_c_experimentalParam2 = 10;
  ZSTD_c_experimentalParam3 = 1000;
  ZSTD_c_experimentalParam4 = 1001;
  ZSTD_c_experimentalParam5 = 1002;
  ZSTD_c_experimentalParam7 = 1004;
  ZSTD_c_experimentalParam8 = 1005;
  ZSTD_c_experimentalParam9 = 1006;
  ZSTD_c_experimentalParam10 = 1007;
  ZSTD_c_experimentalParam11 = 1008;
  ZSTD_c_experimentalParam12 = 1009;
  ZSTD_c_experimentalParam13 = 1010;
  ZSTD_c_experimentalParam14 = 1011;
  ZSTD_c_experimentalParam15 = 1012;
  ZSTD_c_experimentalParam16 = 1013;
  ZSTD_c_experimentalParam17 = 1014;
  ZSTD_c_experimentalParam18 = 1015;
  ZSTD_c_experimentalParam19 = 1016;
  ZSTD_c_experimentalParam20 = 1017;
  ZSTD_reset_session_only = 1;
  ZSTD_reset_parameters = 2;
  ZSTD_reset_session_and_parameters = 3;
  ZSTD_d_windowLogMax = 100;
  ZSTD_d_experimentalParam1 = 1000;
  ZSTD_d_experimentalParam2 = 1001;
  ZSTD_d_experimentalParam3 = 1002;
  ZSTD_d_experimentalParam4 = 1003;
  ZSTD_d_experimentalParam5 = 1004;
  ZSTD_d_experimentalParam6 = 1005;
  ZSTD_e_continue = 0;
  ZSTD_e_flush = 1;
  ZSTD_e_end = 2;
  ZSTD_VERSION_MAJOR = 1;
  ZSTD_VERSION_MINOR = 5;
  ZSTD_VERSION_RELEASE = 7;
  ZSTD_CLEVEL_DEFAULT = 3;
  ZSTD_MAGICNUMBER = 4247762216;
  ZSTD_MAGIC_DICTIONARY = 3962610743;
  ZSTD_MAGIC_SKIPPABLE_START = 407710288;
  ZSTD_MAGIC_SKIPPABLE_MASK = 4294967280;
  ZSTD_BLOCKSIZELOG_MAX = 17;
  ZSTD_CONTENTSIZE_UNKNOWN = -1;
  ZSTD_CONTENTSIZE_ERROR = -2;







function ZSTD_getErrorString(code: TZSTDErrorCode): PAnsiChar; cdecl; external 'zstd' name 'ZSTD_getErrorString';

function ZSTD_versionNumber(): LongWord; cdecl; external 'zstd' name 'ZSTD_versionNumber';

function ZSTD_versionString(): PAnsiChar; cdecl; external 'zstd' name 'ZSTD_versionString';

function ZSTD_compress(dst: Pointer; dstCapacity: TSizeT; src: Pointer; srcSize: TSizeT; compressionLevel: LongInt): TSizeT; cdecl; external 'zstd' name 'ZSTD_compress';

function ZSTD_decompress(dst: Pointer; dstCapacity: TSizeT; src: Pointer; compressedSize: TSizeT): TSizeT; cdecl; external 'zstd' name 'ZSTD_decompress';

function ZSTD_getFrameContentSize(src: Pointer; srcSize: TSizeT): QWord; cdecl; external 'zstd' name 'ZSTD_getFrameContentSize';

function ZSTD_getDecompressedSize(src: Pointer; srcSize: TSizeT): QWord; cdecl; external 'zstd' name 'ZSTD_getDecompressedSize';

function ZSTD_findFrameCompressedSize(src: Pointer; srcSize: TSizeT): TSizeT; cdecl; external 'zstd' name 'ZSTD_findFrameCompressedSize';

function ZSTD_compressBound(srcSize: TSizeT): TSizeT; cdecl; external 'zstd' name 'ZSTD_compressBound';

function ZSTD_isError(result_2: TSizeT): LongWord; cdecl; external 'zstd' name 'ZSTD_isError';

function ZSTD_getErrorCode(functionResult: TSizeT): TZSTDErrorCode; cdecl; external 'zstd' name 'ZSTD_getErrorCode';

function ZSTD_getErrorName(result_2: TSizeT): PAnsiChar; cdecl; external 'zstd' name 'ZSTD_getErrorName';

function ZSTD_minCLevel(): LongInt; cdecl; external 'zstd' name 'ZSTD_minCLevel';

function ZSTD_maxCLevel(): LongInt; cdecl; external 'zstd' name 'ZSTD_maxCLevel';

function ZSTD_defaultCLevel(): LongInt; cdecl; external 'zstd' name 'ZSTD_defaultCLevel';

function ZSTD_createCCtx(): PZSTDCCtx; cdecl; external 'zstd' name 'ZSTD_createCCtx';

function ZSTD_freeCCtx(cctx: PZSTDCCtx): TSizeT; cdecl; external 'zstd' name 'ZSTD_freeCCtx';

function ZSTD_compressCCtx(cctx: PZSTDCCtx; dst: Pointer; dstCapacity: TSizeT; src: Pointer; srcSize: TSizeT; compressionLevel: LongInt): TSizeT; cdecl; external 'zstd' name 'ZSTD_compressCCtx';

function ZSTD_createDCtx(): PZSTDDCtx; cdecl; external 'zstd' name 'ZSTD_createDCtx';

function ZSTD_freeDCtx(dctx: PZSTDDCtx): TSizeT; cdecl; external 'zstd' name 'ZSTD_freeDCtx';

function ZSTD_decompressDCtx(dctx: PZSTDDCtx; dst: Pointer; dstCapacity: TSizeT; src: Pointer; srcSize: TSizeT): TSizeT; cdecl; external 'zstd' name 'ZSTD_decompressDCtx';

function ZSTD_cParam_getBounds(cParam: TZSTDCParameter): TZSTDBounds; cdecl; external 'zstd' name 'ZSTD_cParam_getBounds';

function ZSTD_CCtx_setParameter(cctx: PZSTDCCtx; param: TZSTDCParameter; value: LongInt): TSizeT; cdecl; external 'zstd' name 'ZSTD_CCtx_setParameter';

function ZSTD_CCtx_setPledgedSrcSize(cctx: PZSTDCCtx; pledgedSrcSize: QWord): TSizeT; cdecl; external 'zstd' name 'ZSTD_CCtx_setPledgedSrcSize';

function ZSTD_CCtx_reset(cctx: PZSTDCCtx; reset: TZSTDResetDirective): TSizeT; cdecl; external 'zstd' name 'ZSTD_CCtx_reset';

function ZSTD_compress2(cctx: PZSTDCCtx; dst: Pointer; dstCapacity: TSizeT; src: Pointer; srcSize: TSizeT): TSizeT; cdecl; external 'zstd' name 'ZSTD_compress2';

function ZSTD_dParam_getBounds(dParam: TZSTDDParameter): TZSTDBounds; cdecl; external 'zstd' name 'ZSTD_dParam_getBounds';

function ZSTD_DCtx_setParameter(dctx: PZSTDDCtx; param: TZSTDDParameter; value: LongInt): TSizeT; cdecl; external 'zstd' name 'ZSTD_DCtx_setParameter';

function ZSTD_DCtx_reset(dctx: PZSTDDCtx; reset: TZSTDResetDirective): TSizeT; cdecl; external 'zstd' name 'ZSTD_DCtx_reset';

function ZSTD_createCStream(): PZSTDCStream; cdecl; external 'zstd' name 'ZSTD_createCStream';

function ZSTD_freeCStream(zcs: PZSTDCStream): TSizeT; cdecl; external 'zstd' name 'ZSTD_freeCStream';

function ZSTD_compressStream2(cctx: PZSTDCCtx; output: PZSTDOutBuffer; input: PZSTDInBuffer; endOp: TZSTDEndDirective): TSizeT; cdecl; external 'zstd' name 'ZSTD_compressStream2';

function ZSTD_CStreamInSize(): TSizeT; cdecl; external 'zstd' name 'ZSTD_CStreamInSize';

function ZSTD_CStreamOutSize(): TSizeT; cdecl; external 'zstd' name 'ZSTD_CStreamOutSize';

function ZSTD_initCStream(zcs: PZSTDCStream; compressionLevel: LongInt): TSizeT; cdecl; external 'zstd' name 'ZSTD_initCStream';

function ZSTD_compressStream(zcs: PZSTDCStream; output: PZSTDOutBuffer; input: PZSTDInBuffer): TSizeT; cdecl; external 'zstd' name 'ZSTD_compressStream';

function ZSTD_flushStream(zcs: PZSTDCStream; output: PZSTDOutBuffer): TSizeT; cdecl; external 'zstd' name 'ZSTD_flushStream';

function ZSTD_endStream(zcs: PZSTDCStream; output: PZSTDOutBuffer): TSizeT; cdecl; external 'zstd' name 'ZSTD_endStream';

function ZSTD_createDStream(): PZSTDDStream; cdecl; external 'zstd' name 'ZSTD_createDStream';

function ZSTD_freeDStream(zds: PZSTDDStream): TSizeT; cdecl; external 'zstd' name 'ZSTD_freeDStream';

function ZSTD_initDStream(zds: PZSTDDStream): TSizeT; cdecl; external 'zstd' name 'ZSTD_initDStream';

function ZSTD_decompressStream(zds: PZSTDDStream; output: PZSTDOutBuffer; input: PZSTDInBuffer): TSizeT; cdecl; external 'zstd' name 'ZSTD_decompressStream';

function ZSTD_DStreamInSize(): TSizeT; cdecl; external 'zstd' name 'ZSTD_DStreamInSize';

function ZSTD_DStreamOutSize(): TSizeT; cdecl; external 'zstd' name 'ZSTD_DStreamOutSize';

function ZSTD_compress_usingDict(ctx: PZSTDCCtx; dst: Pointer; dstCapacity: TSizeT; src: Pointer; srcSize: TSizeT; dict: Pointer; dictSize: TSizeT; compressionLevel: LongInt): TSizeT; cdecl; external 'zstd' name 'ZSTD_compress_usingDict';

function ZSTD_decompress_usingDict(dctx: PZSTDDCtx; dst: Pointer; dstCapacity: TSizeT; src: Pointer; srcSize: TSizeT; dict: Pointer; dictSize: TSizeT): TSizeT; cdecl; external 'zstd' name 'ZSTD_decompress_usingDict';

function ZSTD_createCDict(dictBuffer: Pointer; dictSize: TSizeT; compressionLevel: LongInt): PZSTDCDict; cdecl; external 'zstd' name 'ZSTD_createCDict';

function ZSTD_freeCDict(CDict: PZSTDCDict): TSizeT; cdecl; external 'zstd' name 'ZSTD_freeCDict';

function ZSTD_compress_usingCDict(cctx: PZSTDCCtx; dst: Pointer; dstCapacity: TSizeT; src: Pointer; srcSize: TSizeT; cdict: PZSTDCDict): TSizeT; cdecl; external 'zstd' name 'ZSTD_compress_usingCDict';

function ZSTD_createDDict(dictBuffer: Pointer; dictSize: TSizeT): PZSTDDDict; cdecl; external 'zstd' name 'ZSTD_createDDict';

function ZSTD_freeDDict(ddict: PZSTDDDict): TSizeT; cdecl; external 'zstd' name 'ZSTD_freeDDict';

function ZSTD_decompress_usingDDict(dctx: PZSTDDCtx; dst: Pointer; dstCapacity: TSizeT; src: Pointer; srcSize: TSizeT; ddict: PZSTDDDict): TSizeT; cdecl; external 'zstd' name 'ZSTD_decompress_usingDDict';

function ZSTD_getDictID_fromDict(dict: Pointer; dictSize: TSizeT): LongWord; cdecl; external 'zstd' name 'ZSTD_getDictID_fromDict';

function ZSTD_getDictID_fromCDict(cdict: PZSTDCDict): LongWord; cdecl; external 'zstd' name 'ZSTD_getDictID_fromCDict';

function ZSTD_getDictID_fromDDict(ddict: PZSTDDDict): LongWord; cdecl; external 'zstd' name 'ZSTD_getDictID_fromDDict';

function ZSTD_getDictID_fromFrame(src: Pointer; srcSize: TSizeT): LongWord; cdecl; external 'zstd' name 'ZSTD_getDictID_fromFrame';

function ZSTD_CCtx_loadDictionary(cctx: PZSTDCCtx; dict: Pointer; dictSize: TSizeT): TSizeT; cdecl; external 'zstd' name 'ZSTD_CCtx_loadDictionary';

function ZSTD_CCtx_refCDict(cctx: PZSTDCCtx; cdict: PZSTDCDict): TSizeT; cdecl; external 'zstd' name 'ZSTD_CCtx_refCDict';

function ZSTD_CCtx_refPrefix(cctx: PZSTDCCtx; prefix: Pointer; prefixSize: TSizeT): TSizeT; cdecl; external 'zstd' name 'ZSTD_CCtx_refPrefix';

function ZSTD_DCtx_loadDictionary(dctx: PZSTDDCtx; dict: Pointer; dictSize: TSizeT): TSizeT; cdecl; external 'zstd' name 'ZSTD_DCtx_loadDictionary';

function ZSTD_DCtx_refDDict(dctx: PZSTDDCtx; ddict: PZSTDDDict): TSizeT; cdecl; external 'zstd' name 'ZSTD_DCtx_refDDict';

function ZSTD_DCtx_refPrefix(dctx: PZSTDDCtx; prefix: Pointer; prefixSize: TSizeT): TSizeT; cdecl; external 'zstd' name 'ZSTD_DCtx_refPrefix';

function ZSTD_sizeof_CCtx(cctx: PZSTDCCtx): TSizeT; cdecl; external 'zstd' name 'ZSTD_sizeof_CCtx';

function ZSTD_sizeof_DCtx(dctx: PZSTDDCtx): TSizeT; cdecl; external 'zstd' name 'ZSTD_sizeof_DCtx';

function ZSTD_sizeof_CStream(zcs: PZSTDCStream): TSizeT; cdecl; external 'zstd' name 'ZSTD_sizeof_CStream';

function ZSTD_sizeof_DStream(zds: PZSTDDStream): TSizeT; cdecl; external 'zstd' name 'ZSTD_sizeof_DStream';

function ZSTD_sizeof_CDict(cdict: PZSTDCDict): TSizeT; cdecl; external 'zstd' name 'ZSTD_sizeof_CDict';

function ZSTD_sizeof_DDict(ddict: PZSTDDDict): TSizeT; cdecl; external 'zstd' name 'ZSTD_sizeof_DDict';

implementation

end.
