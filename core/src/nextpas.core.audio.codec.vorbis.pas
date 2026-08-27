unit nextpas.core.audio.codec.vorbis;

{$mode objfpc}{$H+}
{$PACKRECORDS C}
{$linklib m}
{$linklib c}

{ 有手写 SIMD 内核的目标（x86_64 SSE2 / aarch64 NEON，均落在
  nextpas.core.audio.codec.vorbis.sse）。接口/调用点共用本判定；内核不可用时各
  调用点自动落回翻译体标量路径。-dC2P_NO_SIMD 强制整体关闭（应急
  开关；也是测试标量 oracle 的构建口径）。 }
{$if defined(cpux86_64) or defined(cpuaarch64)}
  {$ifndef C2P_NO_SIMD}
  {$define C2P_SIMD}
  {$ifend}
{$ifend}

interface

type
  TSTBVorbisError = LongInt;
  TUint32 = LongWord;
  TUint8 = Byte;
  TInt16 = SmallInt;
  TUint16 = Word;
  { C 的 size_t/ptrdiff_t 必须随目标位宽：arm32/i386 为 32 位，
    x86-64/aarch64 为 64 位。硬编码 64 位会让 32 位目标上所有带
    尾随参数的 libc 调用（如 qsort）寄存器错位 → 崩溃。}
  {$IFDEF CPU64}
  TSizeT = QWord;
  TPtrdiffT = Int64;
  {$ELSE}
  TSizeT = LongWord;
  TPtrdiffT = LongInt;
  {$ENDIF}
  TWcharT = LongInt;
  TXBuiltinVaList = Pointer;
  TInt8 = ShortInt;
  TInt32 = LongInt;
  TCodetype = Single;
  PStbVorbis = ^TStbVorbis;
  PPAnsiChar = ^PAnsiChar;
  PFILE = ^TFILE;
  PTFILE = PFILE;
  PUint8 = ^TUint8;
  PTUint8 = PUint8;
  PProbedPage = ^TProbedPage;
  PTProbedPage = PProbedPage;
  PStbVorbisAlloc = ^TStbVorbisAlloc;
  PTStbVorbisAlloc = PStbVorbisAlloc;
  PCodebook = ^TCodebook;
  PTCodebook = PCodebook;
  PCodetype = ^TCodetype;
  PTCodetype = PCodetype;
  PUint32 = ^TUint32;
  PTUint32 = PUint32;
  PFloor = ^TFloor;
  PTFloor = PFloor;
  PFloor0 = ^TFloor0;
  PTFloor0 = PFloor0;
  PFloor1 = ^TFloor1;
  PTFloor1 = PFloor1;
  PResidue = ^TResidue;
  PTResidue = PResidue;
  PPUint8 = ^PUint8;
  TArray8OfTInt16 = array[0..7] of TInt16;
  PArray8OfTInt16 = ^TArray8OfTInt16;
  PMapping = ^TMapping;
  PTMapping = PMapping;
  PMappingChannel = ^TMappingChannel;
  PTMappingChannel = PMappingChannel;
  PMode = ^TMode;
  PTMode = PMode;
  PInt16 = ^TInt16;
  PTInt16 = PInt16;
  PUint16 = ^TUint16;
  PTUint16 = PUint16;
  PCRCscan = ^TCRCscan;
  PTCRCscan = PCRCscan;
  PIOFILE = ^TIOFILE;
  PTStbVorbis = PStbVorbis;
  PStbVorbisInfo = ^TStbVorbisInfo;
  PTStbVorbisInfo = PStbVorbisInfo;
  PStbVorbisComment = ^TStbVorbisComment;
  PTStbVorbisComment = PStbVorbisComment;
  PVorb = ^TVorb;
  PTVorb = PVorb;
  PStbvXFloorOrdering = ^TStbvXFloorOrdering;
  PTStbvXFloorOrdering = PStbvXFloorOrdering;
  TYTYPE = TInt16;
  PYTYPE = ^TYTYPE;
  PTYTYPE = PYTYPE;
  PFloatConv = ^TFloatConv;
  PTFloatConv = PFloatConv;
  TStbVorbisFloatSizeTest = array[0..0] of AnsiChar;
  PWcharT = ^TWcharT;
  PTWcharT = PWcharT;
  PPSingle = ^PSingle;
  PPPSingle = ^PPSingle;
  PPSmallInt = ^PSmallInt;
  TRawProc9779B54A = function(p0: Pointer; p1: Pointer): LongInt; cdecl;
  TRawProcE21ED0E9 = procedure; cdecl;
  TIOFILE = record
  end;
  TProbedPage = record
    page_start: TUint32;
    page_end: TUint32;
    last_decoded_sample: TUint32;
  end;
  TStbVorbisAlloc = record
    alloc_buffer: PAnsiChar;
    alloc_buffer_length_in_bytes: LongInt;
  end;
  TStbVorbisCodebooks = record
    dimensions: LongInt;
    entries: LongInt;
    codeword_lengths: PUint8;
    minimum_value: Single;
    delta_value: Single;
    value_bits: TUint8;
    lookup_type: TUint8;
    sequence_p: TUint8;
    sparse: TUint8;
    lookup_values: TUint32;
    multiplicands: PCodetype;
    codewords: PUint32;
    fast_huffman: array[0..1023] of TInt16;
    sorted_codewords: PUint32;
    sorted_values: PLongInt;
    sorted_entries: LongInt;
  end;
  TFloor0 = record
    order: TUint8;
    rate: TUint16;
    bark_map_size: TUint16;
    amplitude_bits: TUint8;
    amplitude_offset: TUint8;
    number_of_books: TUint8;
    book_list: array[0..15] of TUint8;
  end;
  TFloor1 = record
    partitions: TUint8;
    partition_class_list: array[0..31] of TUint8;
    class_dimensions: array[0..15] of TUint8;
    class_subclasses: array[0..15] of TUint8;
    class_masterbooks: array[0..15] of TUint8;
    subclass_books: array[0..15] of array[0..7] of TInt16;
    Xlist: array[0..249] of TUint16;
    sorted_order: array[0..249] of TUint8;
    neighbors: array[0..249] of array[0..1] of TUint8;
    floor1_multiplier: TUint8;
    rangebits: TUint8;
    values: LongInt;
  end;
  TStbVorbisFloorConfig = record
    case Integer of
    0: (floor0: TFloor0);
    1: (floor1: TFloor1);
  end;
  TStbVorbisResidueConfig = record
    &begin: TUint32;
    &end: TUint32;
    part_size: TUint32;
    classifications: TUint8;
    classbook: TUint8;
    classdata: PPUint8;
    residue_books: PArray8OfTInt16;
  end;
  TStbVorbisMappingChan = record
    magnitude: TUint8;
    angle: TUint8;
    mux: TUint8;
  end;
  TStbVorbisMapping = record
    coupling_steps: TUint16;
    chan: PMappingChannel;
    submaps: TUint8;
    submap_floor: array[0..14] of TUint8;
    submap_residue: array[0..14] of TUint8;
  end;
  TMode = record
    blockflag: TUint8;
    mapping: TUint8;
    windowtype: TUint16;
    transformtype: TUint16;
  end;
  TCRCscan = record
    goal_crc: TUint32;
    bytes_left: LongInt;
    crc_so_far: TUint32;
    bytes_done: LongInt;
    sample_loc: TUint32;
  end;
  TStbVorbis = record
    sample_rate: LongWord;
    channels: LongInt;
    setup_memory_required: LongWord;
    temp_memory_required: LongWord;
    setup_temp_memory_required: LongWord;
    vendor: PAnsiChar;
    comment_list_length: LongInt;
    comment_list: PPAnsiChar;
    f: PFILE;
    f_start: TUint32;
    close_on_free: LongInt;
    stream: PUint8;
    stream_start: PUint8;
    stream_end: PUint8;
    stream_len: TUint32;
    push_mode: TUint8;
    first_audio_page_offset: TUint32;
    p_first: TProbedPage;
    p_last: TProbedPage;
    alloc: TStbVorbisAlloc;
    setup_offset: LongInt;
    temp_offset: LongInt;
    eof: LongInt;
    error: LongInt;
    blocksize: array[0..1] of LongInt;
    blocksize_0: LongInt;
    blocksize_1: LongInt;
    codebook_count: LongInt;
    codebooks: PCodebook;
    floor_count: LongInt;
    floor_types: array[0..63] of TUint16;
    floor_config: PFloor;
    residue_count: LongInt;
    residue_types: array[0..63] of TUint16;
    residue_config: PResidue;
    mapping_count: LongInt;
    mapping: PMapping;
    mode_count: LongInt;
    mode_config: array[0..63] of TMode;
    total_samples: TUint32;
    channel_buffers: array[0..15] of PSingle;
    outputs: array[0..15] of PSingle;
    previous_window: array[0..15] of PSingle;
    previous_length: LongInt;
    finalY: array[0..15] of PInt16;
    current_loc: TUint32;
    current_loc_valid: LongInt;
    A: array[0..1] of PSingle;
    B: array[0..1] of PSingle;
    C: array[0..1] of PSingle;
    window: array[0..1] of PSingle;
    bit_reverse: array[0..1] of PUint16;
    serial: TUint32;
    last_page: LongInt;
    segment_count: LongInt;
    segments: array[0..254] of TUint8;
    page_flag: TUint8;
    bytes_in_seg: TUint8;
    first_decode: TUint8;
    next_seg: LongInt;
    last_seg: LongInt;
    last_seg_which: LongInt;
    acc: TUint32;
    valid_bits: LongInt;
    packet_bytes: LongInt;
    end_seg_with_known_loc: LongInt;
    known_loc_for_packet: TUint32;
    discard_samples_deferred: LongInt;
    samples_output: TUint32;
    page_crc_tests: LongInt;
    scan: array[0..3] of TCRCscan;
    channel_buffer_start: LongInt;
    channel_buffer_end: LongInt;
  end;
  TStbVorbisInfo = record
    sample_rate: LongWord;
    channels: LongInt;
    setup_memory_required: LongWord;
    setup_temp_memory_required: LongWord;
    temp_memory_required: LongWord;
    max_frame_size: LongInt;
  end;
  TStbVorbisComment = record
    vendor: PAnsiChar;
    comment_list_length: LongInt;
    comment_list: PPAnsiChar;
  end;
  TStbvXFloorOrdering = record
    x: TUint16;
    id: TUint16;
  end;
  TFloatConv = record
    case Integer of
    0: (f: Single);
    1: (i: LongInt);
  end;
  TFILE = TIOFILE;
  TCodebook = TStbVorbisCodebooks;
  TFloor = TStbVorbisFloorConfig;
  TResidue = TStbVorbisResidueConfig;
  TMappingChannel = TStbVorbisMappingChan;
  TMapping = TStbVorbisMapping;
  TVorb = TStbVorbis;

const
  VORBIS__no_error = 0;
  VORBIS_need_more_data = 1;
  VORBIS_invalid_api_mixing = 2;
  VORBIS_outofmem = 3;
  VORBIS_feature_not_supported = 4;
  VORBIS_too_many_channels = 5;
  VORBIS_file_open_failure = 6;
  VORBIS_seek_without_length = 7;
  VORBIS_unexpected_eof = 10;
  VORBIS_seek_invalid = 11;
  VORBIS_invalid_setup = 20;
  VORBIS_invalid_stream = 21;
  VORBIS_missing_capture_pattern = 30;
  VORBIS_invalid_stream_structure_version = 31;
  VORBIS_continued_packet_flag_invalid = 32;
  VORBIS_incorrect_stream_serial_number = 33;
  VORBIS_invalid_first_page = 34;
  VORBIS_bad_packet_type = 35;
  VORBIS_cant_find_last_page = 36;
  VORBIS_seek_failed = 37;
  VORBIS_ogg_skeleton_not_supported = 38;
  VORBIS_packet_id = 1;
  VORBIS_packet_comment = 3;
  VORBIS_packet_setup = 5;
  STB_VORBIS_MAX_CHANNELS = 16;
  STB_VORBIS_PUSHDATA_CRC_COUNT = 4;
  STB_VORBIS_FAST_HUFFMAN_LENGTH = 10;
  STB_VORBIS_ENDIAN = 0;
  MAX_BLOCKSIZE_LOG = 13;
  CRC32_POLY = 79764919;
  NO_CODE = 255;
  PAGEFLAG_continued_packet = 1;
  PAGEFLAG_first_page = 2;
  PAGEFLAG_last_page = 4;
  EOP = -1;
  INVALID_BITS = -1;
  LIBVORBIS_MDCT = 0;
  SAMPLE_unknown = 4294967295;
  PLAYBACK_MONO = 1;
  PLAYBACK_LEFT = 2;
  PLAYBACK_RIGHT = 4;
  STB_BUFFER_SIZE = 32;

const
  { C 运行库按目标解析：Unix→libc，Windows→msvcrt（stdio 句柄不透明使用，
    数学函数 sin/cos/tan/sqrt/ldexp/roundf 均有导出） }
  {$ifdef windows}
  CLIB = 'msvcrt';
  {$else}
  CLIB = 'c';
  {$endif}

function memmove(dest: Pointer; src: Pointer; n_2: TSizeT): Pointer; cdecl; external CLIB name 'memmove';

function strlen(s_2: PAnsiChar): TSizeT; cdecl; external CLIB name 'strlen';

function strcmp(s1: PAnsiChar; s2: PAnsiChar): LongInt; cdecl; external CLIB name 'strcmp';

function printf(format: PAnsiChar): LongInt; cdecl; varargs; external CLIB name 'printf';

function fprintf(stream: PFILE; format: PAnsiChar): LongInt; cdecl; varargs; external CLIB name 'fprintf';

function sprintf(str: PAnsiChar; format: PAnsiChar): LongInt; cdecl; varargs; external CLIB name 'sprintf';

function snprintf(str: PAnsiChar; size: TSizeT; format: PAnsiChar): LongInt; cdecl; varargs; external CLIB name 'snprintf';

function sscanf(str: PAnsiChar; format: PAnsiChar): LongInt; cdecl; varargs; external CLIB name 'sscanf';

function scanf(format: PAnsiChar): LongInt; cdecl; varargs; external CLIB name 'scanf';

function fscanf(stream: PFILE; format: PAnsiChar): LongInt; cdecl; varargs; external CLIB name 'fscanf';

function vsnprintf(str: PAnsiChar; size: TSizeT; format: PAnsiChar; ap: Pointer): LongInt; cdecl; external CLIB name 'vsnprintf';

function vfprintf(stream: PFILE; format: PAnsiChar; ap: Pointer): LongInt; cdecl; external CLIB name 'vfprintf';

function fopen(path: PAnsiChar; mode: PAnsiChar): PFILE; cdecl; external CLIB name 'fopen';

procedure perror(s_2: PAnsiChar); cdecl; external CLIB name 'perror';

function fdopen(fd: LongInt; mode: PAnsiChar): PFILE; cdecl; external CLIB name 'fdopen';

function fclose(stream: PFILE): LongInt; cdecl; external CLIB name 'fclose';

function fread(ptr: Pointer; size: TSizeT; nmemb: TSizeT; stream: PFILE): TSizeT; cdecl; external CLIB name 'fread';

function fwrite(ptr: Pointer; size: TSizeT; nmemb: TSizeT; stream: PFILE): TSizeT; cdecl; external CLIB name 'fwrite';

function fflush(stream: PFILE): LongInt; cdecl; external CLIB name 'fflush';

function feof(stream: PFILE): LongInt; cdecl; external CLIB name 'feof';

function ferror(stream: PFILE): LongInt; cdecl; external CLIB name 'ferror';

function fgets(s_2: PAnsiChar; size: LongInt; stream: PFILE): PAnsiChar; cdecl; external CLIB name 'fgets';

function fgetc(stream: PFILE): LongInt; cdecl; external CLIB name 'fgetc';

function fputc(c: LongInt; stream: PFILE): LongInt; cdecl; external CLIB name 'fputc';

function putchar(c: LongInt): LongInt; cdecl; external CLIB name 'putchar';

function puts(s_2: PAnsiChar): LongInt; cdecl; external CLIB name 'puts';

function getc(stream: PFILE): LongInt; cdecl; external CLIB name 'getc';

function getchar(): LongInt; cdecl; external CLIB name 'getchar';

function putc(c: LongInt; stream: PFILE): LongInt; cdecl; external CLIB name 'putc';

function ungetc(c: LongInt; stream: PFILE): LongInt; cdecl; external CLIB name 'ungetc';

function fseek(stream: PFILE; offset: Int64; whence: LongInt): LongInt; cdecl; external CLIB name 'fseek';

function ftell(stream: PFILE): Int64; cdecl; external CLIB name 'ftell';

procedure rewind(stream: PFILE); cdecl; external CLIB name 'rewind';

function fputs(s_2: PAnsiChar; stream: PFILE): LongInt; cdecl; external CLIB name 'fputs';

function vsprintf(str: PAnsiChar; format: PAnsiChar; ap: Pointer): LongInt; cdecl; external CLIB name 'vsprintf';

function freopen(path: PAnsiChar; mode: PAnsiChar; stream: PFILE): PFILE; cdecl; external CLIB name 'freopen';

function tmpfile(): PFILE; cdecl; external CLIB name 'tmpfile';

function tmpnam(s_2: PAnsiChar): PAnsiChar; cdecl; external CLIB name 'tmpnam';

function remove(pathname: PAnsiChar): LongInt; cdecl; external CLIB name 'remove';

function rename(oldpath: PAnsiChar; newpath: PAnsiChar): LongInt; cdecl; external CLIB name 'rename';

function setvbuf(stream: PFILE; buf: PAnsiChar; mode: LongInt; size: TSizeT): LongInt; cdecl; external CLIB name 'setvbuf';

procedure setbuf(stream: PFILE; buf: PAnsiChar); cdecl; external CLIB name 'setbuf';

procedure clearerr(stream: PFILE); cdecl; external CLIB name 'clearerr';

function fileno(stream: PFILE): LongInt; cdecl; external CLIB name 'fileno';

function popen(command: PAnsiChar; &type: PAnsiChar): PFILE; cdecl; external CLIB name 'popen';

function pclose(stream: PFILE): LongInt; cdecl; external CLIB name 'pclose';

function calloc(nmemb: TSizeT; size: TSizeT): Pointer; cdecl; external CLIB name 'calloc';

procedure abort(); cdecl;

procedure exit_(status: LongInt); cdecl;

function atoi(nptr: PAnsiChar): LongInt; cdecl;

function atol(nptr: PAnsiChar): Int64; cdecl;

function atoll(nptr: PAnsiChar): Int64; cdecl;

function strtod(nptr: PAnsiChar; endptr: PPAnsiChar): Double; cdecl;

function strtof(nptr: PAnsiChar; endptr: PPAnsiChar): Single; cdecl;

function atof(nptr: PAnsiChar): Double; cdecl;

function strtol(nptr: PAnsiChar; endptr: PPAnsiChar; base: LongInt): Int64; cdecl;

function strtoul(nptr: PAnsiChar; endptr: PPAnsiChar; base: LongInt): QWord; cdecl;

function strtoll(nptr: PAnsiChar; endptr: PPAnsiChar; base: LongInt): Int64; cdecl;

function strtoull(nptr: PAnsiChar; endptr: PPAnsiChar; base: LongInt): QWord; cdecl;

function labs(j: Int64): Int64; cdecl; external CLIB name 'labs';

function rand(): LongInt; cdecl;

procedure srand(seed: LongWord); cdecl;

procedure qsort(base: Pointer; nmemb: TSizeT; size: TSizeT; compar: TRawProc9779B54A); cdecl; external CLIB name 'qsort';

function getenv(name: PAnsiChar): PAnsiChar; cdecl; external CLIB name 'getenv';

function _wgetenv(name: PWcharT): PWcharT; cdecl; external CLIB name '_wgetenv';

function wcslen(s_2: PWcharT): TSizeT; cdecl; external CLIB name 'wcslen';

function setenv(name: PAnsiChar; value: PAnsiChar; overwrite: LongInt): LongInt; cdecl; external CLIB name 'setenv';

function unsetenv(name: PAnsiChar): LongInt; cdecl; external CLIB name 'unsetenv';

function putenv(&string: PAnsiChar): LongInt; cdecl; external CLIB name 'putenv';

function system_(command: PAnsiChar): LongInt; cdecl; external CLIB name 'system';

function atexit(&function: TRawProcE21ED0E9): LongInt; cdecl; external CLIB name 'atexit';

function abs(j: LongInt): LongInt; cdecl; external CLIB name 'abs';

function realpath(path: PAnsiChar; resolved_path: PAnsiChar): PAnsiChar; cdecl; external CLIB name 'realpath';

function memcpy(dest: Pointer; src: Pointer; n_2: TSizeT): Pointer; cdecl; external CLIB name 'memcpy';

function memmem(haystack: Pointer; haystacklen: TSizeT; needle: Pointer; needlelen: TSizeT): Pointer; cdecl; external CLIB name 'memmem';

function memset(s_2: Pointer; c: LongInt; n_2: TSizeT): Pointer; cdecl; external CLIB name 'memset';

function memcmp(s1: Pointer; s2: Pointer; n_2: TSizeT): LongInt; cdecl; external CLIB name 'memcmp';

function strcpy(dest: PAnsiChar; src: PAnsiChar): PAnsiChar; cdecl; external CLIB name 'strcpy';

function strncpy(dest: PAnsiChar; src: PAnsiChar; n_2: TSizeT): PAnsiChar; cdecl; external CLIB name 'strncpy';

function strncmp(s1: PAnsiChar; s2: PAnsiChar; n_2: TSizeT): LongInt; cdecl; external CLIB name 'strncmp';

function strcat(dest: PAnsiChar; src: PAnsiChar): PAnsiChar; cdecl; external CLIB name 'strcat';

function strncat(dest: PAnsiChar; src: PAnsiChar; n_2: TSizeT): PAnsiChar; cdecl; external CLIB name 'strncat';

function strchr(s_2: PAnsiChar; c: LongInt): PAnsiChar; cdecl; external CLIB name 'strchr';

function strrchr(s_2: PAnsiChar; c: LongInt): PAnsiChar; cdecl; external CLIB name 'strrchr';

function strstr(haystack: PAnsiChar; needle: PAnsiChar): PAnsiChar; cdecl; external CLIB name 'strstr';

function strerror(errnum: LongInt): PAnsiChar; cdecl; external CLIB name 'strerror';

function strspn(s_2: PAnsiChar; accept: PAnsiChar): TSizeT; cdecl; external CLIB name 'strspn';

function strcspn(s_2: PAnsiChar; reject: PAnsiChar): TSizeT; cdecl; external CLIB name 'strcspn';

function strpbrk(s_2: PAnsiChar; accept: PAnsiChar): PAnsiChar; cdecl; external CLIB name 'strpbrk';

function strtok(str: PAnsiChar; delim: PAnsiChar): PAnsiChar; cdecl; external CLIB name 'strtok';

function memchr(s_2: Pointer; c: LongInt; n_2: TSizeT): Pointer; cdecl; external CLIB name 'memchr';

function strnlen(s_2: PAnsiChar; maxlen: TSizeT): TSizeT; cdecl; external CLIB name 'strnlen';

function strcoll(s1: PAnsiChar; s2: PAnsiChar): LongInt; cdecl; external CLIB name 'strcoll';

function fabs(x_2: Double): Double; cdecl; external CLIB name 'fabs';

function sqrt(x_2: Double): Double; cdecl; external CLIB name 'sqrt';

function log2(x_2: Double): Double; cdecl; external CLIB name 'log2';

function log10(x_2: Double): Double; cdecl; external CLIB name 'log10';

function ceil(x_2: Double): Double; cdecl; external CLIB name 'ceil';

function round(x_2: Double): Double; cdecl; external CLIB name 'round';

function trunc_(x_2: Double): Double; cdecl; external CLIB name 'trunc';

function fmod(x_2: Double; y_2: Double): Double; cdecl; external CLIB name 'fmod';

function tan(x_2: Double): Double; cdecl; external CLIB name 'tan';

function asin(x_2: Double): Double; cdecl; external CLIB name 'asin';

function acos(x_2: Double): Double; cdecl; external CLIB name 'acos';

function atan(x_2: Double): Double; cdecl; external CLIB name 'atan';

function atan2(y_2: Double; x_2: Double): Double; cdecl; external CLIB name 'atan2';

function sinh(x_2: Double): Double; cdecl;

function cosh(x_2: Double): Double; cdecl;

function tanh(x_2: Double): Double; cdecl;

function asinh(x_2: Double): Double; cdecl; external CLIB name 'asinh';

function acosh(x_2: Double): Double; cdecl; external CLIB name 'acosh';

function atanh(x_2: Double): Double; cdecl; external CLIB name 'atanh';

function ldexp(x_2: Double; exp_2: LongInt): Double; cdecl;

function frexp(x_2: Double; exp_2: PLongInt): Double; cdecl;

function modf(x_2: Double; iptr: PDouble): Double; cdecl;

function fabsf(x_2: Single): Single; cdecl;

function sqrtf(x_2: Single): Single; cdecl;

function floorf(x_2: Single): Single; cdecl;

function ceilf(x_2: Single): Single; cdecl;

function roundf(x_2: Single): Single; cdecl; external CLIB name 'roundf';

function isinf(x_2: Double): LongInt; cdecl;

function isnan(x_2: Double): LongInt; cdecl;

procedure stb_vorbis_close(p_2: PStbVorbis); cdecl;

function stb_vorbis_get_sample_offset(f: PStbVorbis): LongInt; cdecl;

function stb_vorbis_get_info(f: PStbVorbis): TStbVorbisInfo; cdecl;

function stb_vorbis_get_comment(f: PStbVorbis): TStbVorbisComment; cdecl;

function stb_vorbis_get_error(f: PStbVorbis): LongInt; cdecl;

procedure stb_vorbis_flush_pushdata(f: PStbVorbis); cdecl;

function stb_vorbis_decode_frame_pushdata(f: PStbVorbis; data: PUint8; data_len: LongInt; channels: PLongInt; output: PPPSingle; samples: PLongInt): LongInt; cdecl;

function stb_vorbis_open_pushdata(data: PByte; data_len: LongInt; data_used: PLongInt; error: PLongInt; alloc: PStbVorbisAlloc): PStbVorbis; cdecl;

function stb_vorbis_get_file_offset(f: PStbVorbis): LongWord; cdecl;

function stb_vorbis_seek_frame(f: PStbVorbis; sample_number: LongWord): LongInt; cdecl;

function stb_vorbis_seek(f: PStbVorbis; sample_number: LongWord): LongInt; cdecl;

function stb_vorbis_seek_start(f: PStbVorbis): LongInt; cdecl;

function stb_vorbis_stream_length_in_samples(f: PStbVorbis): LongWord; cdecl;

function stb_vorbis_stream_length_in_seconds(f: PStbVorbis): Single; cdecl;

function stb_vorbis_get_frame_float(f: PStbVorbis; channels: PLongInt; output: PPPSingle): LongInt; cdecl;

function stb_vorbis_open_file_section(&file: PFILE; close_on_free: LongInt; error: PLongInt; alloc: PStbVorbisAlloc; length: LongWord): PStbVorbis; cdecl;

function stb_vorbis_open_file(&file: PFILE; close_on_free: LongInt; error: PLongInt; alloc: PStbVorbisAlloc): PStbVorbis; cdecl;

function stb_vorbis_open_filename(filename: PAnsiChar; error: PLongInt; alloc: PStbVorbisAlloc): PStbVorbis; cdecl;

function stb_vorbis_open_memory(data: PByte; len_2: LongInt; error: PLongInt; alloc: PStbVorbisAlloc): PStbVorbis; cdecl;

function stb_vorbis_get_frame_short(f: PStbVorbis; num_c: LongInt; buffer: PPSmallInt; num_samples: LongInt): LongInt; cdecl;

function stb_vorbis_get_frame_short_interleaved(f: PStbVorbis; num_c: LongInt; buffer: PSmallInt; num_shorts: LongInt): LongInt; cdecl;

function stb_vorbis_get_samples_short_interleaved(f: PStbVorbis; channels: LongInt; buffer: PSmallInt; num_shorts: LongInt): LongInt; cdecl;

function stb_vorbis_get_samples_short(f: PStbVorbis; channels: LongInt; buffer: PPSmallInt; len_2: LongInt): LongInt; cdecl;

function stb_vorbis_decode_filename(filename: PAnsiChar; channels: PLongInt; sample_rate: PLongInt; output: PPSmallInt): LongInt; cdecl;

function stb_vorbis_decode_memory(mem: PUint8; len_2: LongInt; channels: PLongInt; sample_rate: PLongInt; output: PPSmallInt): LongInt; cdecl;

function stb_vorbis_get_samples_float_interleaved(f: PStbVorbis; channels: LongInt; buffer: PSingle; num_floats: LongInt): LongInt; cdecl;

function stb_vorbis_get_samples_float(f: PStbVorbis; channels: LongInt; buffer: PPSingle; num_samples: LongInt): LongInt; cdecl;

{ stdin/stdout/stderr 在本单元内无使用点；Windows 的 msvcrt 数据符号
  导入在 32 位 PE 上不可解引用，故 Windows 端不导入（声明保留给 C 形参表） }
{$ifndef windows}
var
  stdin: PFILE; external CLIB name 'stdin';
  stdout: PFILE; external CLIB name 'stdout';
  stderr: PFILE; external CLIB name 'stderr';
{$endif}

implementation

uses
  Math,
  nextpas.core.audio.codec.vorbis.sse
  ;

const
  {$ifdef C2P_NO_K1}
  use_k1 = False;
  {$else}
  use_k1 = True;
  {$endif}
  {$ifdef C2P_NO_K2}
  use_k2 = False;
  {$else}
  use_k2 = True;
  {$endif}
  {$ifdef C2P_NO_K4}
  use_k4 = False;
  {$else}
  use_k4 = True;
  {$endif}
  {$ifdef C2P_NO_MOVE}
  use_move = False;
  {$else}
  use_move = True;
  {$endif}
  {$ifdef C2P_NO_CB_SSE}
  use_cb_sse = False;
  {$else}
  use_cb_sse = True;
  {$endif}
  {$ifdef C2P_NO_MDCT_SSE}
  use_mdct_sse = False;
  {$else}
  use_mdct_sse = True;
  {$endif}

function __c2p_mem_malloc(Size: SizeUInt): Pointer; cdecl;
begin
  if Size = 0 then
    System.Exit(nil);
  GetMem(Result, Size);
end;

function __c2p_mem_calloc(Count, Size: SizeUInt): Pointer; cdecl;
var
  TotalSize: SizeUInt;
begin
  if (Count = 0) or (Size = 0) then
    System.Exit(nil);
  TotalSize := Count * Size;
  if (Size <> 0) and (TotalSize div Size <> Count) then
    System.Exit(nil);
  GetMem(Result, TotalSize);
  FillChar(Result^, TotalSize, 0);
end;

function __c2p_mem_realloc(Ptr: Pointer; Size: SizeUInt): Pointer; cdecl;
begin
  if Size = 0 then
  begin
    if Ptr <> nil then
      FreeMem(Ptr);
    System.Exit(nil);
  end;
  Result := Ptr;
  ReAllocMem(Result, Size);
end;

procedure __c2p_mem_free(Ptr: Pointer); cdecl;
begin
  if Ptr <> nil then
    FreeMem(Ptr);
end;

{ C 原版逐帧临时缓冲走 alloca（栈上复用，temp_free 为空操作）；堆翻译路径
  若照搬 GetMem 会逐帧泄漏并引发缺页抖动。此处用线程本地单槽容量缓存复现
  alloca 的复用语义：容量不足才扩容，常驻上限为最大块尺寸。 }
threadvar
  vdec_imdct_buf2: PSingle;
  vdec_imdct_n2cap: LongInt;
  vdec_res_pc: PPointer;
  vdec_res_pccap: SizeUInt;

function vdec_frame_buf2(n2: LongInt): Pointer;
begin
  if (vdec_imdct_n2cap < n2) then
  begin
    if (vdec_imdct_buf2 <> nil) then
      FreeMem(vdec_imdct_buf2);
    GetMem(vdec_imdct_buf2, SizeUInt(QWord(n2) * 4));
    vdec_imdct_n2cap := n2;
  end;
  Result := vdec_imdct_buf2;
end;

function vdec_frame_classdata(ch, part_read: LongInt): Pointer;
var
  need: SizeUInt;
begin
  need := SizeUInt(QWord(ch) * (8 + QWord(part_read) * 8));
  if (vdec_res_pccap < need) or (vdec_res_pc = nil) then
  begin
    if (vdec_res_pc <> nil) then
      FreeMem(vdec_res_pc);
    GetMem(vdec_res_pc, need);
    vdec_res_pccap := need;
  end;
  Result := vdec_res_pc;
end;

function __c2p_stdlib_memcpy(Dest, Src: Pointer; Size: SizeUInt): Pointer; cdecl;
begin
  Result := Dest;
  if Size = 0 then
    System.Exit;
  Move(Src^, Dest^, Size);
end;

function __c2p_stdlib_memmove(Dest, Src: Pointer; Size: SizeUInt): Pointer; cdecl;
begin
  Result := Dest;
  if Size = 0 then
    System.Exit;
  Move(Src^, Dest^, Size);
end;

function __c2p_stdlib_memset(Dest: Pointer; Value: LongInt; Size: SizeUInt): Pointer; cdecl;
begin
  Result := Dest;
  if Size = 0 then
    System.Exit;
  FillChar(Dest^, Size, Byte(Value));
end;

function __c2p_stdlib_memcmp(Left, Right: Pointer; Size: SizeUInt): LongInt; cdecl;
var
  I: SizeUInt;
  L: Byte;
  R: Byte;
begin
  if Size = 0 then
    System.Exit(0);
  for I := 0 to Size - 1 do
  begin
    L := PByte(Left)[I];
    R := PByte(Right)[I];
    if L <> R then
      System.Exit(LongInt(L) - LongInt(R));
  end;
  Result := 0;
end;

function __c2p_stdlib_strlen(S: PAnsiChar): SizeUInt; cdecl; inline;
begin
  Result := SizeUInt(System.StrLen(S));
end;

function __c2p_stdlib_strcmp(Left, Right: PAnsiChar): LongInt; cdecl;
var
  I: SizeUInt;
  L: Byte;
  R: Byte;
begin
  I := 0;
  repeat
    L := PByte(Left)[I];
    R := PByte(Right)[I];
    if L <> R then
      System.Exit(LongInt(L) - LongInt(R));
    if L = 0 then
      System.Exit(0);
    Inc(I);
  until False;
end;

function __c2p_stdlib_strcpy(Dest, Src: PAnsiChar): PAnsiChar; cdecl;
var
  I: SizeUInt;
begin
  I := 0;
  repeat
    Dest[I] := Src[I];
    if Src[I] = #0 then
      System.Exit(Dest);
    Inc(I);
  until False;
end;

function __c2p_stdlib_strcat(Dest, Src: PAnsiChar): PAnsiChar; cdecl;
var
  DestIndex: SizeUInt;
  SrcIndex: SizeUInt;
begin
  DestIndex := 0;
  while Dest[DestIndex] <> #0 do
    Inc(DestIndex);
  SrcIndex := 0;
  repeat
    Dest[DestIndex + SrcIndex] := Src[SrcIndex];
    if Src[SrcIndex] = #0 then
      System.Exit(Dest);
    Inc(SrcIndex);
  until False;
end;

function __c2p_stdlib_strncat(Dest, Src: PAnsiChar; Count: SizeUInt): PAnsiChar; cdecl;
var
  DestIndex: SizeUInt;
  SrcIndex: SizeUInt;
begin
  DestIndex := 0;
  while Dest[DestIndex] <> #0 do
    Inc(DestIndex);
  SrcIndex := 0;
  while (SrcIndex < Count) and (Src[SrcIndex] <> #0) do
  begin
    Dest[DestIndex + SrcIndex] := Src[SrcIndex];
    Inc(SrcIndex);
  end;
  Dest[DestIndex + SrcIndex] := #0;
  Result := Dest;
end;

function __c2p_stdlib_strncpy(Dest, Src: PAnsiChar; Count: SizeUInt): PAnsiChar; cdecl;
var
  I: SizeUInt;
begin
  Result := Dest;
  if Count = 0 then
    System.Exit;
  I := 0;
  repeat
    Dest[I] := Src[I];
    if Src[I] = #0 then
    begin
      Inc(I);
      while I < Count do
      begin
        Dest[I] := #0;
        Inc(I);
      end;
      System.Exit(Dest);
    end;
    Inc(I);
  until I = Count;
end;

function __c2p_stdlib_strchr(S: PAnsiChar; C: LongInt): PAnsiChar; cdecl;
var
  I: SizeUInt;
  Target: Byte;
begin
  Target := Byte(C);
  I := 0;
  repeat
    if Byte(S[I]) = Target then
      System.Exit(@S[I]);
    if S[I] = #0 then
      System.Exit(nil);
    Inc(I);
  until False;
end;

function __c2p_stdlib_strrchr(S: PAnsiChar; C: LongInt): PAnsiChar; cdecl;
var
  I: SizeUInt;
  Target: Byte;
begin
  Target := Byte(C);
  I := 0;
  Result := nil;
  repeat
    if Byte(S[I]) = Target then
      Result := @S[I];
    if S[I] = #0 then
      System.Exit(Result);
    Inc(I);
  until False;
end;

function __c2p_stdlib_strstr(Haystack, Needle: PAnsiChar): PAnsiChar; cdecl;
var
  I: SizeUInt;
  J: SizeUInt;
begin
  if Needle[0] = #0 then
    System.Exit(Haystack);
  I := 0;
  repeat
    J := 0;
    while (Needle[J] <> #0) and (Haystack[I + J] = Needle[J]) do
      Inc(J);
    if Needle[J] = #0 then
      System.Exit(@Haystack[I]);
    if Haystack[I] = #0 then
      System.Exit(nil);
    Inc(I);
  until False;
end;

function __c2p_stdlib_memchr(S: Pointer; C: LongInt; Size: SizeUInt): Pointer; cdecl;
var
  I: SizeUInt;
  Target: Byte;
begin
  Target := Byte(C);
  if Size = 0 then
    System.Exit(nil);
  for I := 0 to Size - 1 do
    if PByte(S)[I] = Target then
      System.Exit(@PByte(S)[I]);
  Result := nil;
end;

function __c2p_stdlib_strspn(S, Accept: PAnsiChar): SizeUInt; cdecl;
var
  I: SizeUInt;
  J: SizeUInt;
  Ch: Byte;
  Matched: Boolean;
begin
  I := 0;
  while S[I] <> #0 do
  begin
    Ch := Byte(S[I]);
    Matched := False;
    J := 0;
    while Accept[J] <> #0 do
    begin
      if Byte(Accept[J]) = Ch then
      begin
        Matched := True;
        Break;
      end;
      Inc(J);
    end;
    if not Matched then
      System.Exit(I);
    Inc(I);
  end;
  Result := I;
end;

function __c2p_stdlib_strpbrk(S, Accept: PAnsiChar): PAnsiChar; cdecl;
var
  I: SizeUInt;
  J: SizeUInt;
  Ch: Byte;
begin
  I := 0;
  while S[I] <> #0 do
  begin
    Ch := Byte(S[I]);
    J := 0;
    while Accept[J] <> #0 do
    begin
      if Byte(Accept[J]) = Ch then
        System.Exit(@S[I]);
      Inc(J);
    end;
    Inc(I);
  end;
  Result := nil;
end;

function __c2p_stdlib_strcspn(S, Reject: PAnsiChar): SizeUInt; cdecl;
var
  I: SizeUInt;
  J: SizeUInt;
  Ch: Byte;
begin
  I := 0;
  while S[I] <> #0 do
  begin
    Ch := Byte(S[I]);
    J := 0;
    while Reject[J] <> #0 do
    begin
      if Byte(Reject[J]) = Ch then
        System.Exit(I);
      Inc(J);
    end;
    Inc(I);
  end;
  Result := I;
end;

function __c2p_stdlib_isdigit(C: LongInt): LongInt; cdecl;
begin
  if (C >= Ord('0')) and (C <= Ord('9')) then
    System.Exit(1);
  Result := 0;
end;

function __c2p_stdlib_isxdigit(C: LongInt): LongInt; cdecl;
begin
  if ((C >= Ord('0')) and (C <= Ord('9'))) or
     ((C >= Ord('A')) and (C <= Ord('F'))) or
     ((C >= Ord('a')) and (C <= Ord('f'))) then
    System.Exit(1);
  Result := 0;
end;

function __c2p_stdlib_tolower(C: LongInt): LongInt; cdecl;
begin
  if (C >= Ord('A')) and (C <= Ord('Z')) then
    System.Exit(C + 32);
  Result := C;
end;

function __c2p_stdlib_toupper(C: LongInt): LongInt; cdecl;
begin
  if (C >= Ord('a')) and (C <= Ord('z')) then
    System.Exit(C - 32);
  Result := C;
end;

function __c2p_stdlib_isalpha(C: LongInt): LongInt; cdecl;
begin
  if ((C >= Ord('A')) and (C <= Ord('Z'))) or
     ((C >= Ord('a')) and (C <= Ord('z'))) then
    System.Exit(1);
  Result := 0;
end;

function __c2p_stdlib_isalnum(C: LongInt): LongInt; cdecl;
begin
  if ((C >= Ord('0')) and (C <= Ord('9'))) or
     ((C >= Ord('A')) and (C <= Ord('Z'))) or
     ((C >= Ord('a')) and (C <= Ord('z'))) then
    System.Exit(1);
  Result := 0;
end;

function __c2p_stdlib_isspace(C: LongInt): LongInt; cdecl;
begin
  if (C = Ord(' ')) or (C = Ord(#9)) or (C = Ord(#10)) or
     (C = Ord(#11)) or (C = Ord(#12)) or (C = Ord(#13)) then
    System.Exit(1);
  Result := 0;
end;

function __c2p_stdlib_isupper(C: LongInt): LongInt; cdecl;
begin
  if (C >= Ord('A')) and (C <= Ord('Z')) then
    System.Exit(1);
  Result := 0;
end;

function __c2p_stdlib_islower(C: LongInt): LongInt; cdecl;
begin
  if (C >= Ord('a')) and (C <= Ord('z')) then
    System.Exit(1);
  Result := 0;
end;

function __c2p_stdlib_isprint(C: LongInt): LongInt; cdecl;
begin
  if (C >= 32) and (C <= 126) then
    System.Exit(1);
  Result := 0;
end;

function __c2p_stdlib_ispunct(C: LongInt): LongInt; cdecl;
begin
  if ((C >= 33) and (C <= 47)) or ((C >= 58) and (C <= 64)) or
     ((C >= 91) and (C <= 96)) or ((C >= 123) and (C <= 126)) then
    System.Exit(1);
  Result := 0;
end;

function __c2p_stdlib_iscntrl(C: LongInt): LongInt; cdecl;
begin
  if ((C >= 0) and (C <= 31)) or (C = 127) then
    System.Exit(1);
  Result := 0;
end;

function __c2p_stdlib_isgraph(C: LongInt): LongInt; cdecl;
begin
  if (C >= 33) and (C <= 126) then
    System.Exit(1);
  Result := 0;
end;

function __c2p_stdlib_abs(N: LongInt): LongInt; cdecl;
begin
  if N < 0 then
    System.Exit(-N);
  Result := N;
end;

function __c2p_stdlib_labs(N: LongInt): LongInt; cdecl;
begin
  if N < 0 then
    System.Exit(-N);
  Result := N;
end;

function __c2p_stdlib_floor(X: Double): Double; cdecl;
begin
  Result := System.Int(X);
  if (X < 0.0) and (X <> Result) then
    Result := Result - 1.0;
end;

function __c2p_stdlib_ceil(X: Double): Double; cdecl;
begin
  Result := System.Int(X);
  if (X > 0.0) and (X <> Result) then
    Result := Result + 1.0;
end;

function __c2p_stdlib_round(X: Double): Double; cdecl;
var
  Q: Int64;
  T: Int64;
begin
  Move(X, Q, 8);
  if (Q and $7FF0000000000000) = $7FF0000000000000 then Result := X
  else if (Q and $7FF0000000000000) >= $4330000000000000 then Result := X
  else if Q = $8000000000000000 then Result := X
  else
  begin
    T := System.Trunc(X);
    if X >= 0 then
    begin
      if (X - T) >= 0.5 then Result := T + 1
      else Result := T;
    end
    else
    begin
      if (T - X) >= 0.5 then Result := T - 1
      else if T = 0 then Result := -0.0
      else Result := T;
    end;
  end;
end;

function __c2p_stdlib_trunc(X: Double): Double; cdecl;
begin
  Result := Double(System.Trunc(X));
end;

function __c2p_stdlib_fabs(X: Double): Double; cdecl;
begin
  if X < 0.0 then
    System.Exit(-X);
  Result := X;
end;

function __c2p_libc_sin(X: Double): Double; cdecl; external CLIB name 'sin';
{ 位精确要求：旋转因子/窗表与 C oracle 同源 glibc，禁用 FPC 内建三角 }
function __c2p_math_sin(X: Double): Double; cdecl;
begin
  Result := __c2p_libc_sin(X);
end;

function __c2p_libc_cos(X: Double): Double; cdecl; external CLIB name 'cos';
function __c2p_math_cos(X: Double): Double; cdecl;
begin
  Result := __c2p_libc_cos(X);
end;

function __c2p_libc_tan(X: Double): Double; cdecl; external CLIB name 'tan';
function __c2p_math_tan(X: Double): Double; cdecl;
begin
  Result := __c2p_libc_tan(X);
end;

function __c2p_math_asin(X: Double): Double; cdecl;
begin
  if (X >= 1.0) or (X <= -1.0) then
  begin
    if X > 0.0 then
      System.Exit(Double(System.arctan(1.0)) * 2.0);
    System.Exit(-Double(System.arctan(1.0)) * 2.0);
  end;
  Result := Double(System.arctan(X / System.sqrt(1.0 - X * X)));
end;

function __c2p_math_acos(X: Double): Double; cdecl;
begin
  Result := Double(System.arctan(1.0)) * 2.0 - __c2p_math_asin(X);
end;

function __c2p_math_atan(X: Double): Double; cdecl;
begin
  Result := Double(System.arctan(X));
end;

function __c2p_math_atan2(Y, X: Double): Double; cdecl;
begin
  if X * X > Y * Y then
  begin
    Result := Double(System.arctan(Y / X));
    if X < 0.0 then
    begin
      if Y >= 0.0 then
        Result := Result + Double(System.arctan(1.0)) * 4.0
      else
        Result := Result - Double(System.arctan(1.0)) * 4.0;
    end;
  end
  else if Y <> 0.0 then
  begin
    Result := -Double(System.arctan(X / Y));
    if Y > 0.0 then
      Result := Result + Double(System.arctan(1.0)) * 2.0
    else
      Result := Result - Double(System.arctan(1.0)) * 2.0;
  end
  else
    Result := 0.0;
end;

function __c2p_math_sqrt(X: Double): Double; cdecl;
begin
  Result := Double(System.sqrt(X));
end;

function __c2p_math_pow(Base, Exponent: Double): Double; cdecl;
begin
  if Base = 0.0 then
    System.Exit(0.0);
  if Exponent = 0.0 then
    System.Exit(1.0);
  Result := Double(System.exp(Exponent * System.ln(Base)));
end;

function __c2p_math_exp(X: Double): Double; cdecl;
begin
  Result := Double(System.exp(X));
end;

function __c2p_math_log(X: Double): Double; cdecl;
begin
  Result := Double(System.ln(X));
end;

function __c2p_math_log2(X: Double): Double; cdecl;
begin
  Result := Double(System.ln(X)) / Double(System.ln(2.0));
end;

function __c2p_math_log10(X: Double): Double; cdecl;
begin
  Result := Double(System.ln(X)) / Double(System.ln(10.0));
end;

function __c2p_math_fmod(Numerator, Denominator: Double): Double; cdecl;
begin
  if Denominator = 0.0 then
    System.Exit(0.0);
  Result := Numerator - Double(System.trunc(Numerator / Denominator)) * Denominator;
end;

function __c2p_stdlib_strncmp(Left, Right: PAnsiChar; Count: SizeUInt): LongInt; cdecl;
var
  I: SizeUInt;
  L: Byte;
  R: Byte;
begin
  if Count = 0 then
    System.Exit(0);
  for I := 0 to Count - 1 do
  begin
    L := PByte(Left)[I];
    R := PByte(Right)[I];
    if L <> R then
      System.Exit(LongInt(L) - LongInt(R));
    if L = 0 then
      System.Exit(0);
  end;
  Result := 0;
end;

function __c2p_bsf(X: SizeUInt): SizeUInt; cdecl;
begin
  if X = 0 then
    System.Exit(SizeOf(SizeUInt) * 8);
  Result := SizeUInt(System.BsfQWord(QWord(X)));
end;

function __c2p_bsr(X: SizeUInt): SizeUInt; cdecl;
begin
  if X = 0 then
    System.Exit(SizeOf(SizeUInt) * 8);
  Result := SizeUInt(System.BsrQWord(QWord(X)));
end;

procedure __c2p_memcpy_aligned(Dst, Src: Pointer; Size: SizeUInt); cdecl;
begin
  if Size = 0 then
    System.Exit;
  Move(Src^, Dst^, Size);
end;

procedure __c2p_memset_aligned(Dst: Pointer; Value: PtrUInt; Size: SizeUInt); cdecl;
begin
  if Size = 0 then
    System.Exit;
  FillChar(Dst^, Size, Byte(Value));
end;

function __c2p_sar_longint(Value: LongInt; Count: LongWord): LongInt; inline;
begin
  if Count = 0 then
    System.Exit(Value);
  if Count >= 32 then
  begin
    if Value < 0 then
      System.Exit(-1);
    System.Exit(0);
  end;
  if Value >= 0 then
    System.Exit(Value shr Count);
  Result := LongInt(LongWord(Value) shr Count) or LongInt(not ((not LongWord(0)) shr Count));
end;

function __c2p_sar_int64(Value: Int64; Count: LongWord): Int64; inline;
begin
  if Count = 0 then
    System.Exit(Value);
  if Count >= 64 then
  begin
    if Value < 0 then
      System.Exit(Int64(-1));
    System.Exit(Int64(0));
  end;
  if Value >= 0 then
    System.Exit(Value shr Count);
  Result := Int64(QWord(Value) shr Count) or Int64(not ((not QWord(0)) shr Count));
end;

procedure abort(); cdecl;
begin
  System.RunError(217);
end;

procedure exit_(status: LongInt); cdecl;
begin
  System.Halt(status);
end;

function atoi(nptr: PAnsiChar): LongInt; cdecl;
var
  P: PAnsiChar;
  Neg: Boolean;
  Acc: Int64;
begin
  Result := 0;
  if nptr = nil then Exit;
  P := nptr;
  while (P^ <> #0) and ((P^ = ' ') or (P^ = #9) or (P^ = #10) or
         (P^ = #11) or (P^ = #12) or (P^ = #13)) do Inc(P);
  Neg := False;
  if P^ = '+' then Inc(P)
  else if P^ = '-' then begin Neg := True; Inc(P); end;
  Acc := 0;
  while (P^ >= '0') and (P^ <= '9') do begin
    if Acc > (High(Int64) - (Ord(P^) - 48)) div 10 then begin
      if Neg then Acc := Low(Int64) else Acc := High(Int64);
      while (P^ >= '0') and (P^ <= '9') do Inc(P);
      break;
    end;
    Acc := Acc * 10 + (Ord(P^) - 48);
    Inc(P);
  end;
  if Neg then Acc := -Acc;
  Result := LongInt(Acc); { atoi 语义: strtol 随即截断为 int }
end;

function atol(nptr: PAnsiChar): Int64; cdecl;
var
  P: PAnsiChar;
  Neg: Boolean;
  Acc: Int64;
begin
  Result := 0;
  if nptr = nil then Exit;
  P := nptr;
  while (P^ <> #0) and ((P^ = ' ') or (P^ = #9) or (P^ = #10) or
         (P^ = #11) or (P^ = #12) or (P^ = #13)) do Inc(P);
  Neg := False;
  if P^ = '+' then Inc(P)
  else if P^ = '-' then begin Neg := True; Inc(P); end;
  Acc := 0;
  while (P^ >= '0') and (P^ <= '9') do begin
    if Acc > (High(Int64) - (Ord(P^) - 48)) div 10 then begin
      if Neg then Acc := Low(Int64) else Acc := High(Int64);
      while (P^ >= '0') and (P^ <= '9') do Inc(P);
      break;
    end;
    Acc := Acc * 10 + (Ord(P^) - 48);
    Inc(P);
  end;
  if Neg then Result := -Acc else Result := Acc;
end;

function atoll(nptr: PAnsiChar): Int64; cdecl;
var
  P: PAnsiChar;
  Neg: Boolean;
  Acc: Int64;
begin
  Result := 0;
  if nptr = nil then Exit;
  P := nptr;
  while (P^ <> #0) and ((P^ = ' ') or (P^ = #9) or (P^ = #10) or
         (P^ = #11) or (P^ = #12) or (P^ = #13)) do Inc(P);
  Neg := False;
  if P^ = '+' then Inc(P)
  else if P^ = '-' then begin Neg := True; Inc(P); end;
  Acc := 0;
  while (P^ >= '0') and (P^ <= '9') do begin
    if Acc > (High(Int64) - (Ord(P^) - 48)) div 10 then begin
      if Neg then Acc := Low(Int64) else Acc := High(Int64);
      while (P^ >= '0') and (P^ <= '9') do Inc(P);
      break;
    end;
    Acc := Acc * 10 + (Ord(P^) - 48);
    Inc(P);
  end;
  if Neg then Result := -Acc else Result := Acc;
end;

function __errno_location(): PLongInt; cdecl; external CLIB name '__errno_location';

const
  TENH: array[-307..308] of QWord = (
    $0031FA182C40C60D { 10^-307 hi },
    $0066789E3750F791 { 10^-306 hi },
    $009C16C5C5253575 { 10^-305 hi },
    $00D18E3B9B374169 { 10^-304 hi },
    $0105F1CA820511C3 { 10^-303 hi },
    $013B6E3D22865634 { 10^-302 hi },
    $017124E63593F5E1 { 10^-301 hi },
    $01A56E1FC2F8F359 { 10^-300 hi },
    $01DAC9A7B3B7302F { 10^-299 hi },
    $0210BE08D0527E1D { 10^-298 hi },
    $0244ED8B04671DA5 { 10^-297 hi },
    $027A28EDC580E50E { 10^-296 hi },
    $02B059949B708F29 { 10^-295 hi },
    $02E46FF9C24CB2F3 { 10^-294 hi },
    $03198BF832DFDFB0 { 10^-293 hi },
    $034FEEF63F97D79C { 10^-292 hi },
    $0383F559E7BEE6C1 { 10^-291 hi },
    $03B8F2B061AEA072 { 10^-290 hi },
    $03EF2F5C7A1A488E { 10^-289 hi },
    $04237D99CC506D59 { 10^-288 hi },
    $04585D003F6488AF { 10^-287 hi },
    $048E74404F3DAADB { 10^-286 hi },
    $04C308A831868AC9 { 10^-285 hi },
    $04F7CAD23DE82D7B { 10^-284 hi },
    $052DBD86CD6238D9 { 10^-283 hi },
    $05629674405D6388 { 10^-282 hi },
    $05973C115074BC6A { 10^-281 hi },
    $05CD0B15A491EB84 { 10^-280 hi },
    $060226ED86DB3333 { 10^-279 hi },
    $0636B0A8E891FFFF { 10^-278 hi },
    $066C5CD322B67FFF { 10^-277 hi },
    $06A1BA03F5B21000 { 10^-276 hi },
    $06D62884F31E93FF { 10^-275 hi },
    $070BB2A62FE638FF { 10^-274 hi },
    $07414FA7DDEFE3A0 { 10^-273 hi },
    $0775A391D56BDC87 { 10^-272 hi },
    $07AB0C764AC6D3A9 { 10^-271 hi },
    $07E0E7C9EEBC444A { 10^-270 hi },
    $081521BC6A6B555C { 10^-269 hi },
    $084A6A2B85062AB3 { 10^-268 hi },
    $0880825B3323DAB0 { 10^-267 hi },
    $08B4A2F1FFECD15C { 10^-266 hi },
    $08E9CBAE7FE805B3 { 10^-265 hi },
    $09201F4D0FF10390 { 10^-264 hi },
    $0954272053ED4474 { 10^-263 hi },
    $098930E868E89591 { 10^-262 hi },
    $09BF7D228322BAF5 { 10^-261 hi },
    $09F3AE3591F5B4D9 { 10^-260 hi },
    $0A2899C2F6732210 { 10^-259 hi },
    $0A5EC033B40FEA93 { 10^-258 hi },
    $0A9338205089F29C { 10^-257 hi },
    $0AC8062864AC6F43 { 10^-256 hi },
    $0AFE07B27DD78B14 { 10^-255 hi },
    $0B32C4CF8EA6B6EC { 10^-254 hi },
    $0B677603725064A8 { 10^-253 hi },
    $0B9D53844EE47DD1 { 10^-252 hi },
    $0BD25432B14ECEA3 { 10^-251 hi },
    $0C06E93F5DA2824C { 10^-250 hi },
    $0C3CA38F350B22DF { 10^-249 hi },
    $0C71E6398126F5CB { 10^-248 hi },
    $0CA65FC7E170B33E { 10^-247 hi },
    $0CDBF7B9D9CCE00D { 10^-246 hi },
    $0D117AD428200C08 { 10^-245 hi },
    $0D45D98932280F0A { 10^-244 hi },
    $0D7B4FEB7EB212CD { 10^-243 hi },
    $0DB111F32F2F4BC0 { 10^-242 hi },
    $0DE5566FFAFB1EB0 { 10^-241 hi },
    $0E1AAC0BF9B9E65C { 10^-240 hi },
    $0E50AB877C142FFA { 10^-239 hi },
    $0E84D6695B193BF8 { 10^-238 hi },
    $0EBA0C03B1DF8AF6 { 10^-237 hi },
    $0EF047824F2BB6DA { 10^-236 hi },
    $0F245962E2F6A490 { 10^-235 hi },
    $0F596FBB9BB44DB4 { 10^-234 hi },
    $0F8FCBAA82A16121 { 10^-233 hi },
    $0FC3DF4A91A4DCB5 { 10^-232 hi },
    $0FF8D71D360E13E2 { 10^-231 hi },
    $102F0CE4839198DB { 10^-230 hi },
    $1063680ED23AFF89 { 10^-229 hi },
    $1098421286C9BF6B { 10^-228 hi },
    $10CE5297287C2F45 { 10^-227 hi },
    $1102F39E794D9D8B { 10^-226 hi },
    $1137B08617A104EE { 10^-225 hi },
    $116D9CA79D89462A { 10^-224 hi },
    $11A281E8C275CBDA { 10^-223 hi },
    $11D72262F3133ED1 { 10^-222 hi },
    $120CEAFBAFD80E85 { 10^-221 hi },
    $124212DD4DE70913 { 10^-220 hi },
    $12769794A160CB58 { 10^-219 hi },
    $12AC3D79C9B8FE2E { 10^-218 hi },
    $12E1A66C1E139EDD { 10^-217 hi },
    $1316100725988694 { 10^-216 hi },
    $134B9408EEFEA839 { 10^-215 hi },
    $13813C85955F2923 { 10^-214 hi },
    $13B58BA6FAB6F36C { 10^-213 hi },
    $13EAEE90B964B047 { 10^-212 hi },
    $1420D51A73DEEE2D { 10^-211 hi },
    $14550A6110D6A9B8 { 10^-210 hi },
    $148A4CF9550C5426 { 10^-209 hi },
    $14C0701BD527B498 { 10^-208 hi },
    $14F48C22CA71A1BD { 10^-207 hi },
    $1529AF2B7D0E0A2D { 10^-206 hi },
    $15600D7B2E28C65C { 10^-205 hi },
    $159410D9F9B2F7F3 { 10^-204 hi },
    $15C91510781FB5F0 { 10^-203 hi },
    $15FF5A549627A36C { 10^-202 hi },
    $16339874DDD8C623 { 10^-201 hi },
    $16687E92154EF7AC { 10^-200 hi },
    $169E9E369AA2B597 { 10^-199 hi },
    $16D322E220A5B17E { 10^-198 hi },
    $1707EB9AA8CF1DDE { 10^-197 hi },
    $173DE6815302E556 { 10^-196 hi },
    $1772B010D3E1CF56 { 10^-195 hi },
    $17A75C1508DA432B { 10^-194 hi },
    $17DD331A4B10D3F6 { 10^-193 hi },
    $18123FF06EEA847A { 10^-192 hi },
    $1846CFEC8AA52598 { 10^-191 hi },
    $187C83E7AD4E6EFE { 10^-190 hi },
    $18B1D270CC51055F { 10^-189 hi },
    $18E6470CFF6546B6 { 10^-188 hi },
    $191BD8D03F3E9864 { 10^-187 hi },
    $1951678227871F3E { 10^-186 hi },
    $1985C162B168E70E { 10^-185 hi },
    $19BB31BB5DC320D2 { 10^-184 hi },
    $19F0FF151A99F483 { 10^-183 hi },
    $1A253EDA614071A4 { 10^-182 hi },
    $1A5A8E90F9908E0D { 10^-181 hi },
    $1A90991A9BFA58C8 { 10^-180 hi },
    $1AC4BF6142F8EEFA { 10^-179 hi },
    $1AF9EF3993B72AB8 { 10^-178 hi },
    $1B303583FC527AB3 { 10^-177 hi },
    $1B6442E4FB671960 { 10^-176 hi },
    $1B99539E3A40DFB8 { 10^-175 hi },
    $1BCFA885C8D117A6 { 10^-174 hi },
    $1C03C9539D82AEC8 { 10^-173 hi },
    $1C38BBA884E35A7A { 10^-172 hi },
    $1C6EEA92A61C3118 { 10^-171 hi },
    $1CA3529BA7D19EAF { 10^-170 hi },
    $1CD8274291C6065B { 10^-169 hi },
    $1D0E3113363787F2 { 10^-168 hi },
    $1D42DEAC01E2B4F7 { 10^-167 hi },
    $1D779657025B6235 { 10^-166 hi },
    $1DAD7BECC2F23AC2 { 10^-165 hi },
    $1DE26D73F9D764B9 { 10^-164 hi },
    $1E1708D0F84D3DE7 { 10^-163 hi },
    $1E4CCB0536608D61 { 10^-162 hi },
    $1E81FEE341FC585D { 10^-161 hi },
    $1EB67E9C127B6E74 { 10^-160 hi },
    $1EEC1E43171A4A11 { 10^-159 hi },
    $1F2192E9EE706E4B { 10^-158 hi },
    $1F55F7A46A0C89DD { 10^-157 hi },
    $1F8B758D848FAC55 { 10^-156 hi },
    $1FC1297872D9CBB5 { 10^-155 hi },
    $1FF573D68F903EA2 { 10^-154 hi },
    $202AD0CC33744E4B { 10^-153 hi },
    $2060C27FA028B0EF { 10^-152 hi },
    $2094F31F8832DD2A { 10^-151 hi },
    $20CA2FE76A3F9475 { 10^-150 hi },
    $21005DF0A267BCC9 { 10^-149 hi },
    $2134756CCB01ABFB { 10^-148 hi },
    $216992C7FDC216FA { 10^-147 hi },
    $219FF779FD329CB9 { 10^-146 hi },
    $21D3FAAC3E3FA1F3 { 10^-145 hi },
    $2208F9574DCF8A70 { 10^-144 hi },
    $223F37AD21436D0C { 10^-143 hi },
    $227382CC34CA2428 { 10^-142 hi },
    $22A8637F41FCAD32 { 10^-141 hi },
    $22DE7C5F127BD87E { 10^-140 hi },
    $23130DBB6B8D674F { 10^-139 hi },
    $2347D12A4670C123 { 10^-138 hi },
    $237DC574D80CF16B { 10^-137 hi },
    $23B29B69070816E3 { 10^-136 hi },
    $23E7424348CA1C9C { 10^-135 hi },
    $241D12D41AFCA3C3 { 10^-134 hi },
    $24522BC490DDE65A { 10^-133 hi },
    $2486B6B5B5155FF0 { 10^-132 hi },
    $24BC6463225AB7EC { 10^-131 hi },
    $24F1BEBDF578B2F4 { 10^-130 hi },
    $25262E6D72D6DFB0 { 10^-129 hi },
    $255BBA08CF8C979D { 10^-128 hi },
    $2591544581B7DEC2 { 10^-127 hi },
    $25C5A956E225D672 { 10^-126 hi },
    $25FB13AC9AAF4C0F { 10^-125 hi },
    $2630EC4BE0AD8F89 { 10^-124 hi },
    $2665275ED8D8F36C { 10^-123 hi },
    $269A71368F0F3047 { 10^-122 hi },
    $26D086C219697E2C { 10^-121 hi },
    $2704A8729FC3DDB7 { 10^-120 hi },
    $2739D28F47B4D525 { 10^-119 hi },
    $277023998CD10537 { 10^-118 hi },
    $27A42C7FF0054685 { 10^-117 hi },
    $27D9379FEC069826 { 10^-116 hi },
    $280F8587E7083E30 { 10^-115 hi },
    $2843B374F06526DE { 10^-114 hi },
    $2878A0522C7E7095 { 10^-113 hi },
    $28AEC866B79E0CBA { 10^-112 hi },
    $28E33D4032C2C7F5 { 10^-111 hi },
    $29180C903F7379F2 { 10^-110 hi },
    $294E0FB44F50586E { 10^-109 hi },
    $2982C9D0B1923745 { 10^-108 hi },
    $29B77C44DDF6C516 { 10^-107 hi },
    $29ED5B561574765B { 10^-106 hi },
    $2A225915CD68C9F9 { 10^-105 hi },
    $2A56EF5B40C2FC77 { 10^-104 hi },
    $2A8CAB3210F3BB95 { 10^-103 hi },
    $2AC1EAFF4A98553D { 10^-102 hi },
    $2AF665BF1D3E6A8D { 10^-101 hi },
    $2B2BFF2EE48E0530 { 10^-100 hi },
    $2B617F7D4ED8C33E { 10^-99 hi },
    $2B95DF5CA28EF40D { 10^-98 hi },
    $2BCB5733CB32B111 { 10^-97 hi },
    $2C0116805EFFAEAA { 10^-96 hi },
    $2C355C2076BF9A55 { 10^-95 hi },
    $2C6AB328946F80EA { 10^-94 hi },
    $2CA0AFF95CC5B092 { 10^-93 hi },
    $2CD4DBF7B3F71CB7 { 10^-92 hi },
    $2D0A12F5A0F4E3E5 { 10^-91 hi },
    $2D404BD984990E6F { 10^-90 hi },
    $2D745ECFE5BF520B { 10^-89 hi },
    $2DA97683DF2F268D { 10^-88 hi },
    $2DDFD424D6FAF031 { 10^-87 hi },
    $2E13E497065CD61F { 10^-86 hi },
    $2E48DDBCC7F40BA6 { 10^-85 hi },
    $2E7F152BF9F10E90 { 10^-84 hi },
    $2EB36D3B7C36A91A { 10^-83 hi },
    $2EE8488A5B445360 { 10^-82 hi },
    $2F1E5AACF2156838 { 10^-81 hi },
    $2F52F8AC174D6123 { 10^-80 hi },
    $2F87B6D71D20B96C { 10^-79 hi },
    $2FBDA48CE468E7C7 { 10^-78 hi },
    $2FF286D80EC190DC { 10^-77 hi },
    $3027288E1271F513 { 10^-76 hi },
    $305CF2B1970E7258 { 10^-75 hi },
    $309217AEFE690777 { 10^-74 hi },
    $30C69D9ABE034955 { 10^-73 hi },
    $30FC45016D841BAA { 10^-72 hi },
    $3131AB20E472914A { 10^-71 hi },
    $316615E91D8F359D { 10^-70 hi },
    $319B9B6364F30304 { 10^-69 hi },
    $31D1411E1F17E1E3 { 10^-68 hi },
    $32059165A6DDDA5B { 10^-67 hi },
    $323AF5BF109550F2 { 10^-66 hi },
    $3270D9976A5D5297 { 10^-65 hi },
    $32A50FFD44F4A73D { 10^-64 hi },
    $32DA53FC9631D10D { 10^-63 hi },
    $3310747DDDDF22A8 { 10^-62 hi },
    $3344919D5556EB52 { 10^-61 hi },
    $3379B604AAACA626 { 10^-60 hi },
    $33B011C2EAABE7D8 { 10^-59 hi },
    $33E41633A556E1CE { 10^-58 hi },
    $34191BC08EAC9A41 { 10^-57 hi },
    $344F62B0B257C0D2 { 10^-56 hi },
    $34839DAE6F76D883 { 10^-55 hi },
    $34B8851A0B548EA4 { 10^-54 hi },
    $34EEA6608E29B24D { 10^-53 hi },
    $352327FC58DA0F70 { 10^-52 hi },
    $3557F1FB6F10934C { 10^-51 hi },
    $358DEE7A4AD4B81F { 10^-50 hi },
    $35C2B50C6EC4F313 { 10^-49 hi },
    $35F7624F8A762FD8 { 10^-48 hi },
    $362D3AE36D13BBCE { 10^-47 hi },
    $366244CE242C5561 { 10^-46 hi },
    $3696D601AD376AB9 { 10^-45 hi },
    $36CC8B8218854567 { 10^-44 hi },
    $3701D7314F534B61 { 10^-43 hi },
    $37364CFDA3281E39 { 10^-42 hi },
    $376BE03D0BF225C7 { 10^-41 hi },
    $37A16C262777579C { 10^-40 hi },
    $37D5C72FB1552D83 { 10^-39 hi },
    $380B38FB9DAA78E4 { 10^-38 hi },
    $3841039D428A8B8F { 10^-37 hi },
    $38754484932D2E72 { 10^-36 hi },
    $38AA95A5B7F87A0F { 10^-35 hi },
    $38E09D8792FB4C49 { 10^-34 hi },
    $3914C4E977BA1F5C { 10^-33 hi },
    $3949F623D5A8A733 { 10^-32 hi },
    $398039D665896880 { 10^-31 hi },
    $39B4484BFEEBC2A0 { 10^-30 hi },
    $39E95A5EFEA6B347 { 10^-29 hi },
    $3A1FB0F6BE506019 { 10^-28 hi },
    $3A53CE9A36F23C10 { 10^-27 hi },
    $3A88C240C4AECB14 { 10^-26 hi },
    $3ABEF2D0F5DA7DD9 { 10^-25 hi },
    $3AF357C299A88EA7 { 10^-24 hi },
    $3B282DB34012B251 { 10^-23 hi },
    $3B5E392010175EE6 { 10^-22 hi },
    $3B92E3B40A0E9B4F { 10^-21 hi },
    $3BC79CA10C924223 { 10^-20 hi },
    $3BFD83C94FB6D2AC { 10^-19 hi },
    $3C32725DD1D243AC { 10^-18 hi },
    $3C670EF54646D497 { 10^-17 hi },
    $3C9CD2B297D889BC { 10^-16 hi },
    $3CD203AF9EE75616 { 10^-15 hi },
    $3D06849B86A12B9B { 10^-14 hi },
    $3D3C25C268497682 { 10^-13 hi },
    $3D719799812DEA11 { 10^-12 hi },
    $3DA5FD7FE1796495 { 10^-11 hi },
    $3DDB7CDFD9D7BDBB { 10^-10 hi },
    $3E112E0BE826D695 { 10^-9 hi },
    $3E45798EE2308C3A { 10^-8 hi },
    $3E7AD7F29ABCAF48 { 10^-7 hi },
    $3EB0C6F7A0B5ED8D { 10^-6 hi },
    $3EE4F8B588E368F1 { 10^-5 hi },
    $3F1A36E2EB1C432D { 10^-4 hi },
    $3F50624DD2F1A9FC { 10^-3 hi },
    $3F847AE147AE147B { 10^-2 hi },
    $3FB999999999999A { 10^-1 hi },
    $3FF0000000000000 { 10^0 hi },
    $4024000000000000 { 10^1 hi },
    $4059000000000000 { 10^2 hi },
    $408F400000000000 { 10^3 hi },
    $40C3880000000000 { 10^4 hi },
    $40F86A0000000000 { 10^5 hi },
    $412E848000000000 { 10^6 hi },
    $416312D000000000 { 10^7 hi },
    $4197D78400000000 { 10^8 hi },
    $41CDCD6500000000 { 10^9 hi },
    $4202A05F20000000 { 10^10 hi },
    $42374876E8000000 { 10^11 hi },
    $426D1A94A2000000 { 10^12 hi },
    $42A2309CE5400000 { 10^13 hi },
    $42D6BCC41E900000 { 10^14 hi },
    $430C6BF526340000 { 10^15 hi },
    $4341C37937E08000 { 10^16 hi },
    $4376345785D8A000 { 10^17 hi },
    $43ABC16D674EC800 { 10^18 hi },
    $43E158E460913D00 { 10^19 hi },
    $4415AF1D78B58C40 { 10^20 hi },
    $444B1AE4D6E2EF50 { 10^21 hi },
    $4480F0CF064DD592 { 10^22 hi },
    $44B52D02C7E14AF6 { 10^23 hi },
    $44EA784379D99DB4 { 10^24 hi },
    $45208B2A2C280291 { 10^25 hi },
    $4554ADF4B7320335 { 10^26 hi },
    $4589D971E4FE8402 { 10^27 hi },
    $45C027E72F1F1281 { 10^28 hi },
    $45F431E0FAE6D721 { 10^29 hi },
    $46293E5939A08CEA { 10^30 hi },
    $465F8DEF8808B024 { 10^31 hi },
    $4693B8B5B5056E17 { 10^32 hi },
    $46C8A6E32246C99C { 10^33 hi },
    $46FED09BEAD87C03 { 10^34 hi },
    $4733426172C74D82 { 10^35 hi },
    $476812F9CF7920E3 { 10^36 hi },
    $479E17B84357691B { 10^37 hi },
    $47D2CED32A16A1B1 { 10^38 hi },
    $48078287F49C4A1D { 10^39 hi },
    $483D6329F1C35CA5 { 10^40 hi },
    $48725DFA371A19E7 { 10^41 hi },
    $48A6F578C4E0A061 { 10^42 hi },
    $48DCB2D6F618C879 { 10^43 hi },
    $4911EFC659CF7D4C { 10^44 hi },
    $49466BB7F0435C9E { 10^45 hi },
    $497C06A5EC5433C6 { 10^46 hi },
    $49B18427B3B4A05C { 10^47 hi },
    $49E5E531A0A1C873 { 10^48 hi },
    $4A1B5E7E08CA3A8F { 10^49 hi },
    $4A511B0EC57E649A { 10^50 hi },
    $4A8561D276DDFDC0 { 10^51 hi },
    $4ABABA4714957D30 { 10^52 hi },
    $4AF0B46C6CDD6E3E { 10^53 hi },
    $4B24E1878814C9CE { 10^54 hi },
    $4B5A19E96A19FC41 { 10^55 hi },
    $4B905031E2503DA9 { 10^56 hi },
    $4BC4643E5AE44D13 { 10^57 hi },
    $4BF97D4DF19D6057 { 10^58 hi },
    $4C2FDCA16E04B86D { 10^59 hi },
    $4C63E9E4E4C2F344 { 10^60 hi },
    $4C98E45E1DF3B015 { 10^61 hi },
    $4CCF1D75A5709C1B { 10^62 hi },
    $4D03726987666191 { 10^63 hi },
    $4D384F03E93FF9F5 { 10^64 hi },
    $4D6E62C4E38FF872 { 10^65 hi },
    $4DA2FDBB0E39FB47 { 10^66 hi },
    $4DD7BD29D1C87A19 { 10^67 hi },
    $4E0DAC74463A989F { 10^68 hi },
    $4E428BC8ABE49F64 { 10^69 hi },
    $4E772EBAD6DDC73D { 10^70 hi },
    $4EACFA698C95390C { 10^71 hi },
    $4EE21C81F7DD43A7 { 10^72 hi },
    $4F16A3A275D49491 { 10^73 hi },
    $4F4C4C8B1349B9B5 { 10^74 hi },
    $4F81AFD6EC0E1411 { 10^75 hi },
    $4FB61BCCA7119916 { 10^76 hi },
    $4FEBA2BFD0D5FF5B { 10^77 hi },
    $502145B7E285BF99 { 10^78 hi },
    $50559725DB272F7F { 10^79 hi },
    $508AFCEF51F0FB5F { 10^80 hi },
    $50C0DE1593369D1B { 10^81 hi },
    $50F5159AF8044462 { 10^82 hi },
    $512A5B01B605557B { 10^83 hi },
    $516078E111C3556D { 10^84 hi },
    $5194971956342AC8 { 10^85 hi },
    $51C9BCDFABC1357A { 10^86 hi },
    $5200160BCB58C16C { 10^87 hi },
    $52341B8EBE2EF1C7 { 10^88 hi },
    $526922726DBAAE39 { 10^89 hi },
    $529F6B0F092959C7 { 10^90 hi },
    $52D3A2E965B9D81D { 10^91 hi },
    $53088BA3BF284E24 { 10^92 hi },
    $533EAE8CAEF261AD { 10^93 hi },
    $53732D17ED577D0C { 10^94 hi },
    $53A7F85DE8AD5C4F { 10^95 hi },
    $53DDF67562D8B363 { 10^96 hi },
    $5412BA095DC7701E { 10^97 hi },
    $5447688BB5394C25 { 10^98 hi },
    $547D42AEA2879F2E { 10^99 hi },
    $54B249AD2594C37D { 10^100 hi },
    $54E6DC186EF9F45C { 10^101 hi },
    $551C931E8AB87173 { 10^102 hi },
    $5551DBF316B346E8 { 10^103 hi },
    $558652EFDC6018A2 { 10^104 hi },
    $55BBE7ABD3781ECA { 10^105 hi },
    $55F170CB642B133F { 10^106 hi },
    $5625CCFE3D35D80E { 10^107 hi },
    $565B403DCC834E12 { 10^108 hi },
    $569108269FD210CB { 10^109 hi },
    $56C54A3047C694FE { 10^110 hi },
    $56FA9CBC59B83A3D { 10^111 hi },
    $5730A1F5B8132466 { 10^112 hi },
    $5764CA732617ED80 { 10^113 hi },
    $5799FD0FEF9DE8E0 { 10^114 hi },
    $57D03E29F5C2B18C { 10^115 hi },
    $58044DB473335DEF { 10^116 hi },
    $583961219000356B { 10^117 hi },
    $586FB969F40042C5 { 10^118 hi },
    $58A3D3E2388029BB { 10^119 hi },
    $58D8C8DAC6A0342A { 10^120 hi },
    $590EFB1178484135 { 10^121 hi },
    $59435CEAEB2D28C1 { 10^122 hi },
    $59783425A5F872F1 { 10^123 hi },
    $59AE412F0F768FAD { 10^124 hi },
    $59E2E8BD69AA19CC { 10^125 hi },
    $5A17A2ECC414A03F { 10^126 hi },
    $5A4D8BA7F519C84F { 10^127 hi },
    $5A827748F9301D32 { 10^128 hi },
    $5AB7151B377C247E { 10^129 hi },
    $5AECDA62055B2D9E { 10^130 hi },
    $5B22087D4358FC82 { 10^131 hi },
    $5B568A9C942F3BA3 { 10^132 hi },
    $5B8C2D43B93B0A8C { 10^133 hi },
    $5BC19C4A53C4E697 { 10^134 hi },
    $5BF6035CE8B6203D { 10^135 hi },
    $5C2B843422E3A84D { 10^136 hi },
    $5C6132A095CE4930 { 10^137 hi },
    $5C957F48BB41DB7C { 10^138 hi },
    $5CCADF1AEA12525B { 10^139 hi },
    $5D00CB70D24B7379 { 10^140 hi },
    $5D34FE4D06DE5057 { 10^141 hi },
    $5D6A3DE04895E46D { 10^142 hi },
    $5DA066AC2D5DAEC4 { 10^143 hi },
    $5DD4805738B51A75 { 10^144 hi },
    $5E09A06D06E26112 { 10^145 hi },
    $5E400444244D7CAB { 10^146 hi },
    $5E7405552D60DBD6 { 10^147 hi },
    $5EA906AA78B912CC { 10^148 hi },
    $5EDF485516E7577F { 10^149 hi },
    $5F138D352E5096AF { 10^150 hi },
    $5F48708279E4BC5B { 10^151 hi },
    $5F7E8CA3185DEB72 { 10^152 hi },
    $5FB317E5EF3AB327 { 10^153 hi },
    $5FE7DDDF6B095FF1 { 10^154 hi },
    $601DD55745CBB7ED { 10^155 hi },
    $6052A5568B9F52F4 { 10^156 hi },
    $60874EAC2E8727B1 { 10^157 hi },
    $60BD22573A28F19D { 10^158 hi },
    $60F2357684599702 { 10^159 hi },
    $6126C2D4256FFCC3 { 10^160 hi },
    $615C73892ECBFBF4 { 10^161 hi },
    $6191C835BD3F7D78 { 10^162 hi },
    $61C63A432C8F5CD6 { 10^163 hi },
    $61FBC8D3F7B3340C { 10^164 hi },
    $62315D847AD00087 { 10^165 hi },
    $6265B4E5998400A9 { 10^166 hi },
    $629B221EFFE500D4 { 10^167 hi },
    $62D0F5535FEF2084 { 10^168 hi },
    $630532A837EAE8A5 { 10^169 hi },
    $633A7F5245E5A2CF { 10^170 hi },
    $63708F936BAF85C1 { 10^171 hi },
    $63A4B378469B6732 { 10^172 hi },
    $63D9E056584240FE { 10^173 hi },
    $64102C35F729689F { 10^174 hi },
    $6444374374F3C2C6 { 10^175 hi },
    $647945145230B378 { 10^176 hi },
    $64AF965966BCE056 { 10^177 hi },
    $64E3BDF7E0360C36 { 10^178 hi },
    $6518AD75D8438F43 { 10^179 hi },
    $654ED8D34E547314 { 10^180 hi },
    $6583478410F4C7EC { 10^181 hi },
    $65B819651531F9E8 { 10^182 hi },
    $65EE1FBE5A7E7861 { 10^183 hi },
    $6622D3D6F88F0B3D { 10^184 hi },
    $665788CCB6B2CE0C { 10^185 hi },
    $668D6AFFE45F818F { 10^186 hi },
    $66C262DFEEBBB0F9 { 10^187 hi },
    $66F6FB97EA6A9D38 { 10^188 hi },
    $672CBA7DE5054486 { 10^189 hi },
    $6761F48EAF234AD4 { 10^190 hi },
    $679671B25AEC1D89 { 10^191 hi },
    $67CC0E1EF1A724EB { 10^192 hi },
    $680188D357087713 { 10^193 hi },
    $6835EB082CCA94D7 { 10^194 hi },
    $686B65CA37FD3A0D { 10^195 hi },
    $68A11F9E62FE4448 { 10^196 hi },
    $68D56785FBBDD55A { 10^197 hi },
    $690AC1677AAD4AB1 { 10^198 hi },
    $6940B8E0ACAC4EAF { 10^199 hi },
    $6974E718D7D7625A { 10^200 hi },
    $69AA20DF0DCD3AF1 { 10^201 hi },
    $69E0548B68A044D6 { 10^202 hi },
    $6A1469AE42C8560C { 10^203 hi },
    $6A498419D37A6B8F { 10^204 hi },
    $6A7FE52048590673 { 10^205 hi },
    $6AB3EF342D37A408 { 10^206 hi },
    $6AE8EB0138858D0A { 10^207 hi },
    $6B1F25C186A6F04C { 10^208 hi },
    $6B537798F4285630 { 10^209 hi },
    $6B88557F31326BBB { 10^210 hi },
    $6BBE6ADEFD7F06AA { 10^211 hi },
    $6BF302CB5E6F642A { 10^212 hi },
    $6C27C37E360B3D35 { 10^213 hi },
    $6C5DB45DC38E0C82 { 10^214 hi },
    $6C9290BA9A38C7D1 { 10^215 hi },
    $6CC734E940C6F9C6 { 10^216 hi },
    $6CFD022390F8B837 { 10^217 hi },
    $6D3221563A9B7323 { 10^218 hi },
    $6D66A9ABC9424FEB { 10^219 hi },
    $6D9C5416BB92E3E6 { 10^220 hi },
    $6DD1B48E353BCE70 { 10^221 hi },
    $6E0621B1C28AC20C { 10^222 hi },
    $6E3BAA1E332D728F { 10^223 hi },
    $6E714A52DFFC6799 { 10^224 hi },
    $6EA59CE797FB817F { 10^225 hi },
    $6EDB04217DFA61DF { 10^226 hi },
    $6F10E294EEBC7D2C { 10^227 hi },
    $6F451B3A2A6B9C76 { 10^228 hi },
    $6F7A6208B5068394 { 10^229 hi },
    $6FB07D457124123D { 10^230 hi },
    $6FE49C96CD6D16CC { 10^231 hi },
    $7019C3BC80C85C7F { 10^232 hi },
    $70501A55D07D39CF { 10^233 hi },
    $708420EB449C8843 { 10^234 hi },
    $70B9292615C3AA54 { 10^235 hi },
    $70EF736F9B3494E9 { 10^236 hi },
    $7123A825C100DD11 { 10^237 hi },
    $7158922F31411456 { 10^238 hi },
    $718EB6BAFD91596B { 10^239 hi },
    $71C33234DE7AD7E3 { 10^240 hi },
    $71F7FEC216198DDC { 10^241 hi },
    $722DFE729B9FF153 { 10^242 hi },
    $7262BF07A143F6D4 { 10^243 hi },
    $72976EC98994F489 { 10^244 hi },
    $72CD4A7BEBFA31AB { 10^245 hi },
    $73024E8D737C5F0B { 10^246 hi },
    $7336E230D05B76CD { 10^247 hi },
    $736C9ABD04725481 { 10^248 hi },
    $73A1E0B622C774D0 { 10^249 hi },
    $73D658E3AB795204 { 10^250 hi },
    $740BEF1C9657A686 { 10^251 hi },
    $74417571DDF6C814 { 10^252 hi },
    $7475D2CE55747A18 { 10^253 hi },
    $74AB4781EAD1989E { 10^254 hi },
    $74E10CB132C2FF63 { 10^255 hi },
    $75154FDD7F73BF3C { 10^256 hi },
    $754AA3D4DF50AF0B { 10^257 hi },
    $7580A6650B926D67 { 10^258 hi },
    $75B4CFFE4E7708C0 { 10^259 hi },
    $75EA03FDE214CAF1 { 10^260 hi },
    $7620427EAD4CFED6 { 10^261 hi },
    $7654531E58A03E8C { 10^262 hi },
    $768967E5EEC84E2F { 10^263 hi },
    $76BFC1DF6A7A61BB { 10^264 hi },
    $76F3D92BA28C7D15 { 10^265 hi },
    $7728CF768B2F9C5A { 10^266 hi },
    $775F03542DFB8370 { 10^267 hi },
    $779362149CBD3226 { 10^268 hi },
    $77C83A99C3EC7EB0 { 10^269 hi },
    $77FE494034E79E5C { 10^270 hi },
    $7832EDC82110C2F9 { 10^271 hi },
    $7867A93A2954F3B8 { 10^272 hi },
    $789D9388B3AA30A5 { 10^273 hi },
    $78D27C35704A5E67 { 10^274 hi },
    $79071B42CC5CF601 { 10^275 hi },
    $793CE2137F743382 { 10^276 hi },
    $79720D4C2FA8A031 { 10^277 hi },
    $79A6909F3B92C83D { 10^278 hi },
    $79DC34C70A777A4D { 10^279 hi },
    $7A11A0FC668AAC70 { 10^280 hi },
    $7A46093B802D578C { 10^281 hi },
    $7A7B8B8A6038AD6F { 10^282 hi },
    $7AB137367C236C65 { 10^283 hi },
    $7AE585041B2C477F { 10^284 hi },
    $7B1AE64521F7595E { 10^285 hi },
    $7B50CFEB353A97DB { 10^286 hi },
    $7B8503E602893DD2 { 10^287 hi },
    $7BBA44DF832B8D46 { 10^288 hi },
    $7BF06B0BB1FB384C { 10^289 hi },
    $7C2485CE9E7A065F { 10^290 hi },
    $7C59A742461887F6 { 10^291 hi },
    $7C9008896BCF54FA { 10^292 hi },
    $7CC40AABC6C32A38 { 10^293 hi },
    $7CF90D56B873F4C7 { 10^294 hi },
    $7D2F50AC6690F1F8 { 10^295 hi },
    $7D63926BC01A973B { 10^296 hi },
    $7D987706B0213D0A { 10^297 hi },
    $7DCE94C85C298C4C { 10^298 hi },
    $7E031CFD3999F7B0 { 10^299 hi },
    $7E37E43C8800759C { 10^300 hi },
    $7E6DDD4BAA009303 { 10^301 hi },
    $7EA2AA4F4A405BE2 { 10^302 hi },
    $7ED754E31CD072DA { 10^303 hi },
    $7F0D2A1BE4048F90 { 10^304 hi },
    $7F423A516E82D9BA { 10^305 hi },
    $7F76C8E5CA239029 { 10^306 hi },
    $7FAC7B1F3CAC7433 { 10^307 hi },
    $7FE1CCF385EBC8A0 { 10^308 hi }
  );
  TENL: array[-307..308] of Int64 = (
                        2 { 10^-307 lo },
     -9223372036854775802 { 10^-306 lo },
                        8 { 10^-305 lo },
                      587 { 10^-304 lo },
                    14064 { 10^-303 lo },
                    75109 { 10^-302 lo },
     -9223372036853429746 { 10^-301 lo },
     -9223372036849703791 { 10^-300 lo },
                 16388697 { 10^-299 lo },
               1774499711 { 10^-298 lo },
     -9223372028829969139 { 10^-297 lo },
     -9223372025326185851 { 10^-296 lo },
     -9223370822057248464 { 10^-295 lo },
     -9223368684972524575 { 10^-294 lo },
     -9223268149288085813 { 10^-293 lo },
     -9222333161187875860 { 10^-292 lo },
         7625641840482501 { 10^-291 lo },
     -9196612865613483899 { 10^-290 lo },
     -9193158972077837673 { 10^-289 lo },
     -9168126487163816472 { 10^-288 lo },
     -9159567556478990653 { 10^-287 lo },
     -9139021190299626438 { 10^-286 lo },
     -9121676111810153308 { 10^-285 lo },
     -9110995612505390181 { 10^-284 lo },
       129611968246199743 { 10^-283 lo },
     -9085782995664799326 { 10^-282 lo },
     -9070526033783629814 { 10^-281 lo },
       172912005781421181 { 10^-280 lo },
     -9033641515108289998 { 10^-279 lo },
       205315511206043970 { 10^-278 lo },
       216051202608657188 { 10^-277 lo },
     -8985206212962208763 { 10^-276 lo },
       250605974766649082 { 10^-275 lo },
       261466072743550649 { 10^-274 lo },
     -8940369019256394547 { 10^-273 lo },
       295890474250217472 { 10^-272 lo },
       306812698029584896 { 10^-271 lo },
     -8900948667801431680 { 10^-270 lo },
       337791449719276816 { 10^-269 lo },
       352433517924853332 { 10^-268 lo },
       360918037850841043 { 10^-267 lo },
       375712253555095495 { 10^-266 lo },
       390827323464885689 { 10^-265 lo },
     -8819067565059682087 { 10^-264 lo },
     -8804048555770133881 { 10^-263 lo },
     -8789289678046383319 { 10^-262 lo },
       450963315984297990 { 10^-261 lo },
       471566206793168388 { 10^-260 lo },
     -8732785731077775810 { 10^-259 lo },
       502533925459790387 { 10^-258 lo },
       513240875133344128 { 10^-257 lo },
       527941129817382896 { 10^-256 lo },
     -8688039948645490607 { 10^-255 lo },
       566796449001265530 { 10^-254 lo },
     -8643838104678395864 { 10^-253 lo },
       594011375692237774 { 10^-252 lo },
     -8623233848612830595 { 10^-251 lo },
     -8600105589081072441 { 10^-250 lo },
     -8585026465492974599 { 10^-249 lo },
       646928686026003986 { 10^-248 lo },
     -8561607616050813847 { 10^-247 lo },
       681815119974302879 { 10^-246 lo },
       699728127346696931 { 10^-245 lo },
       714782372411718556 { 10^-244 lo },
       712179856604746779 { 10^-243 lo },
       739389513124320548 { 10^-242 lo },
       754226005472164461 { 10^-241 lo },
       769393921186441481 { 10^-240 lo },
     -8433327747487827155 { 10^-239 lo },
       791504387155570747 { 10^-238 lo },
       806564516167638565 { 10^-237 lo },
     -8391744787821137259 { 10^-236 lo },
       846348282669347014 { 10^-235 lo },
       861108149186915964 { 10^-234 lo },
       875975003065657883 { 10^-233 lo },
     -8335631054736987298 { 10^-232 lo },
       897138486845911956 { 10^-231 lo },
     -8301829663439622174 { 10^-230 lo },
     -8284305333513558547 { 10^-229 lo },
     -8274072962800271663 { 10^-228 lo },
       967748299553233086 { 10^-227 lo },
       984833905780156278 { 10^-226 lo },
       995729301695086932 { 10^-225 lo },
     -8217901980252988242 { 10^-224 lo },
      1023276377962012179 { 10^-223 lo },
     -8181951212164995788 { 10^-222 lo },
     -8173561846573146878 { 10^-221 lo },
      1059419019484993404 { 10^-220 lo },
     -8139747247496079191 { 10^-219 lo },
     -8124457028393027734 { 10^-218 lo },
     -8103641642385194334 { 10^-217 lo },
     -8092799121503186101 { 10^-216 lo },
     -8078120070493833187 { 10^-215 lo },
      1165033315405014254 { 10^-214 lo },
      1175942567452454441 { 10^-213 lo },
      1190705032418597299 { 10^-212 lo },
     -8013563393791025168 { 10^-211 lo },
     -8002719308897327124 { 10^-210 lo },
     -7988038302873361945 { 10^-209 lo },
     -7967714443127485136 { 10^-208 lo },
      1268821672991141764 { 10^-207 lo },
     -7945869787490580169 { 10^-206 lo },
     -7952232640725206967 { 10^-205 lo },
     -7937314866633480612 { 10^-204 lo },
     -7899176346485036032 { 10^-203 lo },
     -7884505297715378432 { 10^-202 lo },
      1356461306567308192 { 10^-201 lo },
      1364476181109834273 { 10^-200 lo },
      1379155819642573141 { 10^-199 lo },
      1404608138080463210 { 10^-198 lo },
      1407051955071307540 { 10^-197 lo },
     -7793237502525671606 { 10^-196 lo },
     -7773343398918829426 { 10^-195 lo },
     -7769361567600872250 { 10^-194 lo },
     -7748084024683381634 { 10^-193 lo },
     -7728233976664758833 { 10^-192 lo },
     -7723958441425339126 { 10^-191 lo },
     -7709214837454533082 { 10^-190 lo },
     -7685941025099209620 { 10^-189 lo },
      1550486548008194681 { 10^-188 lo },
     -7666864347120933982 { 10^-187 lo },
      1584131222284665967 { 10^-186 lo },
      1582915802591669330 { 10^-185 lo },
     -7612123359789262573 { 10^-184 lo },
     -7612476066332640576 { 10^-183 lo },
     -7583466889431115369 { 10^-182 lo },
     -7568681469876961283 { 10^-181 lo },
     -7559121814836641800 { 10^-180 lo },
     -7543879626168082442 { 10^-179 lo },
      1699655362604722691 { 10^-178 lo },
      1714741637165188228 { 10^-177 lo },
      1713580448653192488 { 10^-176 lo },
      1728770295005247602 { 10^-175 lo },
      1743636479508585287 { 10^-174 lo },
     -7449773631068233795 { 10^-173 lo },
     -7434829489505242154 { 10^-172 lo },
      1797654312925896297 { 10^-171 lo },
      1812470527116117507 { 10^-170 lo },
     -7394486411352826818 { 10^-169 lo },
     -7373816329372311129 { 10^-168 lo },
     -7378349379204833017 { 10^-167 lo },
     -7345075913738045366 { 10^-166 lo },
     -7339392000097740429 { 10^-165 lo },
      1907657806960234508 { 10^-164 lo },
      1927498768518380039 { 10^-163 lo },
      1938747299587758217 { 10^-162 lo },
     -7272685023255879340 { 10^-161 lo },
      1959746700351171757 { 10^-160 lo },
      1974553614751377368 { 10^-159 lo },
     -7222534592737101370 { 10^-158 lo },
      2014937721198671816 { 10^-157 lo },
     -7195660364522599866 { 10^-156 lo },
     -7187267205058365010 { 10^-155 lo },
      2055031654800618483 { 10^-154 lo },
     -7150896248853878904 { 10^-153 lo },
     -7132626385169901387 { 10^-152 lo },
      2105214444971344158 { 10^-151 lo },
     -7118007202629126953 { 10^-150 lo },
      2128112808786557821 { 10^-149 lo },
      2150378704847931031 { 10^-148 lo },
      2160376628177293434 { 10^-147 lo },
     -7048696225447830680 { 10^-146 lo },
      2197369545894944623 { 10^-145 lo },
      2208531776897906507 { 10^-144 lo },
      2223610465558451486 { 10^-143 lo },
     -6985875133912107622 { 10^-142 lo },
     -6970941393175477888 { 10^-141 lo },
      2261481737768549439 { 10^-140 lo },
     -6943283478562891175 { 10^-139 lo },
     -6922929510352207753 { 10^-138 lo },
      2308085216923082454 { 10^-137 lo },
     -6917433106598114391 { 10^-136 lo },
     -6881320561845932811 { 10^-135 lo },
     -6866638945862932430 { 10^-134 lo },
     -6848568029603931873 { 10^-133 lo },
      2379872784373400165 { 10^-132 lo },
      2395002528442798846 { 10^-131 lo },
     -6801700238257017080 { 10^-130 lo },
      2435776599753213238 { 10^-129 lo },
     -6774827141061129859 { 10^-128 lo },
     -6763921467366679588 { 10^-127 lo },
      2478365411824158358 { 10^-126 lo },
     -6739809526770819311 { 10^-125 lo },
      2509728243035585317 { 10^-124 lo },
     -6699507609044543983 { 10^-123 lo },
     -6684408751134901354 { 10^-122 lo },
      2547201049757043466 { 10^-121 lo },
      2562504563619175885 { 10^-120 lo },
     -6649510319369241920 { 10^-119 lo },
      2589817179187686216 { 10^-118 lo },
     -6614253623653026573 { 10^-117 lo },
      2613423838358468417 { 10^-116 lo },
     -6580671501543130786 { 10^-115 lo },
     -6565692635521113125 { 10^-114 lo },
      2666993726254343773 { 10^-113 lo },
      2687499344461803514 { 10^-112 lo },
     -6517116040037961212 { 10^-111 lo },
     -6505958885777748348 { 10^-110 lo },
      2720468495323428714 { 10^-109 lo },
     -6477675614164716881 { 10^-108 lo },
     -6483645266140793429 { 10^-107 lo },
      2778484962396186215 { 10^-106 lo },
      2789684959541760001 { 10^-105 lo },
      2809780311493564929 { 10^-104 lo },
      2820922846565585025 { 10^-103 lo },
      2838874140091617873 { 10^-102 lo },
     -6371223741568980709 { 10^-101 lo },
     -6362413745387518268 { 10^-100 lo },
     -6347483914576816011 { 10^-99 lo },
      2898100922638176347 { 10^-98 lo },
     -6313526930651591794 { 10^-97 lo },
      2930955565638619335 { 10^-96 lo },
      2931907998147695589 { 10^-95 lo },
      2955788930666568248 { 10^-94 lo },
      2976082738276335715 { 10^-93 lo },
      2977399876241457645 { 10^-92 lo },
     -6227114761386606900 { 10^-91 lo },
      3001586934749545990 { 10^-90 lo },
     -6193495297407582961 { 10^-89 lo },
      3048464678931202519 { 10^-88 lo },
     -6168750817501021336 { 10^-87 lo },
     -6143385356664564080 { 10^-86 lo },
      3086154407076808599 { 10^-85 lo },
     -6119445957691251902 { 10^-84 lo },
     -6104572774925984750 { 10^-83 lo },
      3134751490642374261 { 10^-82 lo },
      3149449726929455634 { 10^-81 lo },
      3164444822567779478 { 10^-80 lo },
      3156645114622736260 { 10^-79 lo },
      3171423647473183410 { 10^-78 lo },
      3213423668297437269 { 10^-77 lo },
      3228649650581959787 { 10^-76 lo },
      3239800829089714566 { 10^-75 lo },
      3254865702131250663 { 10^-74 lo },
      3252741445267430150 { 10^-73 lo },
      3283565231004130844 { 10^-72 lo },
      3304228965786579666 { 10^-71 lo },
      3299896910559508579 { 10^-70 lo },
      3328766810794896232 { 10^-69 lo },
     -5875887842713295649 { 10^-68 lo },
      3361425932982415849 { 10^-67 lo },
      3370792248869510343 { 10^-66 lo },
      3393274059167405310 { 10^-65 lo },
      3403124768244593787 { 10^-64 lo },
     -5800764376180353229 { 10^-63 lo },
     -5789537391143715584 { 10^-62 lo },
     -5774377759941075904 { 10^-61 lo },
      3461970110699351216 { 10^-60 lo },
     -5747222420902737885 { 10^-59 lo },
     -5732349735972039402 { 10^-58 lo },
      3509535091037754066 { 10^-57 lo },
     -5699718155175692167 { 10^-56 lo },
      3525943175987022659 { 10^-55 lo },
     -5671380660079870914 { 10^-54 lo },
     -5656238187833260634 { 10^-53 lo },
     -5650602811629560768 { 10^-52 lo },
     -5635612432660503727 { 10^-51 lo },
     -5620372246814044654 { 10^-50 lo },
      3631430648259976141 { 10^-49 lo },
      3640480070600066433 { 10^-48 lo },
      3655509662310196961 { 10^-47 lo },
     -5553423596468199577 { 10^-46 lo },
      3682299265275852992 { 10^-45 lo },
      3704259509117775292 { 10^-44 lo },
     -5500895979609814165 { 10^-43 lo },
     -5490386432613360502 { 10^-42 lo },
     -5487876780380893516 { 10^-41 lo },
      3766752122278926810 { 10^-40 lo },
      3781824529517178960 { 10^-39 lo },
      3792783739217095781 { 10^-38 lo },
     -5412108435346033599 { 10^-37 lo },
      3825410887416450735 { 10^-36 lo },
     -5395845992869368529 { 10^-35 lo },
      3856671083969765240 { 10^-34 lo },
     -5353389510898767702 { 10^-33 lo },
     -5338405200598625580 { 10^-32 lo },
     -5320901836184265788 { 10^-31 lo },
     -5305676906553396554 { 10^-30 lo },
      3929936356769448093 { 10^-29 lo },
      3940768826356625604 { 10^-28 lo },
     -5265982804812254453 { 10^-27 lo },
     -5250868040867246105 { 10^-26 lo },
     -5236149060916603936 { 10^-25 lo },
      4006679902334268308 { 10^-24 lo },
      4017557959896326265 { 10^-23 lo },
     -5189706535989958807 { 10^-22 lo },
      4053088618013570910 { 10^-21 lo },
      4064309855427028278 { 10^-20 lo },
      4074159742176345351 { 10^-19 lo },
     -5127411775529120530 { 10^-18 lo },
     -5112228026728697815 { 10^-17 lo },
      4117896183574595481 { 10^-16 lo },
     -5081969668356835936 { 10^-15 lo },
      4129421565601463783 { 10^-14 lo },
     -5057879409136967787 { 10^-13 lo },
      4177509938886011014 { 10^-12 lo },
      4199597566440843434 { 10^-11 lo },
     -5011932077707260628 { 10^-10 lo },
     -4993570094577895365 { 10^-9 lo },
     -4985431856872862572 { 10^-8 lo },
      4257557416083959843 { 10^-7 lo },
      4272608056927624236 { 10^-6 lo },
     -4931749998473175452 { 10^-5 lo },
     -4920568101030369794 { 10^-4 lo },
     -4911013264060940550 { 10^-3 lo },
     -4895773082921918792 { 10^-2 lo },
     -4874696236665824870 { 10^-1 lo },
                        0 { 10^0 lo },
                        0 { 10^1 lo },
                        0 { 10^2 lo },
                        0 { 10^3 lo },
                        0 { 10^4 lo },
                        0 { 10^5 lo },
                        0 { 10^6 lo },
                        0 { 10^7 lo },
                        0 { 10^8 lo },
                        0 { 10^9 lo },
                        0 { 10^10 lo },
                        0 { 10^11 lo },
                        0 { 10^12 lo },
                        0 { 10^13 lo },
                        0 { 10^14 lo },
                        0 { 10^15 lo },
                        0 { 10^16 lo },
                        0 { 10^17 lo },
                        0 { 10^18 lo },
                        0 { 10^19 lo },
                        0 { 10^20 lo },
                        0 { 10^21 lo },
                        0 { 10^22 lo },
      4710765210229538816 { 10^23 lo },
      4715268809856909312 { 10^24 lo },
     -4482489004117196800 { 10^25 lo },
     -4471581848769658880 { 10^26 lo },
     -4465107924305313792 { 10^27 lo },
      4780645771244470272 { 10^28 lo },
      4800602457044418560 { 10^29 lo },
     -4417444370119131136 { 10^30 lo },
      4824677260566986752 { 10^31 lo },
     -4381139874854469632 { 10^32 lo },
      4857179894804643840 { 10^33 lo },
      4872391467718410240 { 10^34 lo },
      4883524634512719872 { 10^35 lo },
     -4322780941442351104 { 10^36 lo },
      4915961517140082688 { 10^37 lo },
      4926518402099445760 { 10^38 lo },
      4947636018668699648 { 10^39 lo },
     -4264885682169200640 { 10^40 lo },
     -4260289422739193856 { 10^41 lo },
     -4232661864668787200 { 10^42 lo },
     -4225271124803500544 { 10^43 lo },
     -4198339070503492880 { 10^44 lo },
      5038506455456638036 { 10^45 lo },
      5038319906572856136 { 10^46 lo },
     -4158041069000469699 { 10^47 lo },
     -4142947390359952378 { 10^48 lo },
      5096493544750428921 { 10^49 lo },
     -4109672288986812379 { 10^50 lo },
      5112961867177860753 { 10^51 lo },
      5127942638494901814 { 10^52 lo },
      5143200838688890850 { 10^53 lo },
     -4049453824984068859 { 10^54 lo },
     -4047821265268670184 { 10^55 lo },
     -4018616042527421396 { 10^56 lo },
     -4007708337187229897 { 10^57 lo },
      5231437703132034300 { 10^58 lo },
      5242260436232340027 { 10^59 lo },
      5260811358455337317 { 10^60 lo },
      5275599805665940926 { 10^61 lo },
     -3935124177120148269 { 10^62 lo },
     -3916930040107869436 { 10^63 lo },
     -3908372187110120567 { 10^64 lo },
      5323625835746936617 { 10^65 lo },
      5351038025413396254 { 10^66 lo },
      5358588297429754776 { 10^67 lo },
      5379895436365873951 { 10^68 lo },
     -3825742459394410996 { 10^69 lo },
     -3810526454637829233 { 10^70 lo },
     -3799387748040000397 { 10^71 lo },
      5441005738810886712 { 10^72 lo },
      5448138894227567384 { 10^73 lo },
      5469804492741534711 { 10^74 lo },
      5487468886786780795 { 10^75 lo },
     -3723704867926768153 { 10^76 lo },
      5508224084316221759 { 10^77 lo },
     -3705015043617495838 { 10^78 lo },
      5542071438375645305 { 10^79 lo },
     -3697297848379581936 { 10^80 lo },
      5577685379488012783 { 10^81 lo },
      5587784340134076631 { 10^82 lo },
     -3621667403428677900 { 10^83 lo },
     -3602558409137600212 { 10^84 lo },
     -3596769638475043363 { 10^85 lo },
     -3581731323737593516 { 10^86 lo },
      5663141587708117782 { 10^87 lo },
      5678307500522922971 { 10^88 lo },
      5679884581785203528 { 10^89 lo },
      5706896517143790083 { 10^90 lo },
     -3495878629083783490 { 10^91 lo },
     -3484890959576426898 { 10^92 lo },
     -3470030472785388535 { 10^93 lo },
     -3459907813468436970 { 10^94 lo },
     -3444842377311521842 { 10^95 lo },
     -3424167480645023647 { 10^96 lo },
     -3406742070601091780 { 10^97 lo },
      5809408818375143055 { 10^98 lo },
      5841511392415234258 { 10^99 lo },
     -3371801010376068620 { 10^100 lo },
      5869007220246249671 { 10^101 lo },
      5883848145480827129 { 10^102 lo },
     -3340623246721649085 { 10^103 lo },
     -3325724628735880237 { 10^104 lo },
      5935473250455630650 { 10^105 lo },
     -3270569817866145796 { 10^106 lo },
      5960653527999080458 { 10^107 lo },
     -3246900994591310086 { 10^108 lo },
      5987049862732030608 { 10^109 lo },
     -3219488607432541594 { 10^110 lo },
      6022635847818765184 { 10^111 lo },
      6040717016522513968 { 10^112 lo },
     -3177483718762223345 { 10^113 lo },
     -3162332615432932525 { 10^114 lo },
     -3147393787761911788 { 10^115 lo },
     -3132601501030441447 { 10^116 lo },
     -3109985017748389528 { 10^117 lo },
      6125770286988623422 { 10^118 lo },
      6144019587789745895 { 10^119 lo },
      6152439531315385665 { 10^120 lo },
     -3052078222701487433 { 10^121 lo },
     -3043279336276868406 { 10^122 lo },
      6197920679731074626 { 10^123 lo },
      6218386980831686121 { 10^124 lo },
      6235682018646938802 { 10^125 lo },
      6250993751027435998 { 10^126 lo },
      6262252117155159126 { 10^127 lo },
     -2942818903570211254 { 10^128 lo },
      6271183363525526621 { 10^129 lo },
     -2914089751168600236 { 10^130 lo },
      6326594571711135083 { 10^131 lo },
      6326935628266169905 { 10^132 lo },
     -2875916984470302703 { 10^133 lo },
      6370597604902122235 { 10^134 lo },
      6381114602043539315 { 10^135 lo },
     -2824579072555360168 { 10^136 lo },
     -2813525600035448722 { 10^137 lo },
     -2798582859478716790 { 10^138 lo },
     -2783282133503329748 { 10^139 lo },
     -2764665209935926738 { 10^140 lo },
     -2757981765230325019 { 10^141 lo },
     -2735929696574024216 { 10^142 lo },
     -2725785981832112445 { 10^143 lo },
     -2710733705315797446 { 10^144 lo },
      6522380884343060591 { 10^145 lo },
      6549120143124506321 { 10^146 lo },
      6557168882463097367 { 10^147 lo },
     -2646405176349729959 { 10^148 lo },
     -2631340626424745425 { 10^149 lo },
      6600869564198716042 { 10^150 lo },
     -2608076622153163565 { 10^151 lo },
     -2586908922816443134 { 10^152 lo },
      6617891749752725196 { 10^153 lo },
     -2558109114682113965 { 10^154 lo },
     -2553863620397432417 { 10^155 lo },
      6689635118904938366 { 10^156 lo },
      6704719235758830430 { 10^157 lo },
      6726332552995057677 { 10^158 lo },
      6743988035458870792 { 10^159 lo },
     -2479959329396673619 { 10^160 lo },
     -2453519974274445293 { 10^161 lo },
      6788024849156054516 { 10^162 lo },
      6802936600622187889 { 10^163 lo },
     -2428407539060103599 { 10^164 lo },
      6836307205845535296 { 10^165 lo },
      6847526947788242129 { 10^166 lo },
     -2363581497380342789 { 10^167 lo },
      6878180288986781571 { 10^168 lo },
      6893112902273744228 { 10^169 lo },
     -2319232948871384253 { 10^170 lo },
      6920755653331083244 { 10^171 lo },
     -2283652802272828403 { 10^172 lo },
     -2280460367429405632 { 10^173 lo },
     -2255152125300930006 { 10^174 lo },
      6982518012130186060 { 10^175 lo },
     -2239660513352827124 { 10^176 lo },
     -2224509502607739032 { 10^177 lo },
     -2197010944259824472 { 10^178 lo },
      7035010233023956060 { 10^179 lo },
     -2178459457511738085 { 10^180 lo },
      7074250895573587892 { 10^181 lo },
     -2135827874405473697 { 10^182 lo },
      7101326876339410185 { 10^183 lo },
     -2114567484804478102 { 10^184 lo },
      7125055747823104222 { 10^185 lo },
      7139782730942803221 { 10^186 lo },
      7164875495204004375 { 10^187 lo },
     -2052762650224809273 { 10^188 lo },
     -2037906256471820935 { 10^189 lo },
     -2015510141076237130 { 10^190 lo },
     -2000347819290846749 { 10^191 lo },
     -1989276216407007140 { 10^192 lo },
     -1971191925028135878 { 10^193 lo },
      7265953008968961208 { 10^194 lo },
      7275178623440543692 { 10^195 lo },
      7295308312253184992 { 10^196 lo },
      7310141167574771052 { 10^197 lo },
     -1904768273445174669 { 10^198 lo },
     -1878765979252208444 { 10^199 lo },
      7351786928465428502 { 10^200 lo },
     -1854989406989367310 { 10^201 lo },
      7389535513882014473 { 10^202 lo },
      7390553214977507116 { 10^203 lo },
      7405226470382092023 { 10^204 lo },
     -1800568927953557338 { 10^205 lo },
     -1780066375799959192 { 10^206 lo },
     -1765000480890275103 { 10^207 lo },
      7468193549396569294 { 10^208 lo },
     -1731172559048913408 { 10^209 lo },
      7507486656686235264 { 10^210 lo },
      7518742175219566113 { 10^211 lo },
      7538733424569326548 { 10^212 lo },
      7542067617601162022 { 10^213 lo },
      7563901724670788476 { 10^214 lo },
      7583846641578979885 { 10^215 lo },
     -1634268837453151601 { 10^216 lo },
      7607932478437570151 { 10^217 lo },
     -1595682660423078400 { 10^218 lo },
      7637122349227797761 { 10^219 lo },
      7637285979349467656 { 10^220 lo },
     -1554381575394684201 { 10^221 lo },
     -1539504987623781433 { 10^222 lo },
     -1524686767600595272 { 10^223 lo },
      7710998379181313434 { 10^224 lo },
      7731514096036767872 { 10^225 lo },
      7742481479065600672 { 10^226 lo },
     -1460225303981285796 { 10^227 lo },
      7776788537546717709 { 10^228 lo },
      7777443566502298754 { 10^229 lo },
     -1414812643094975834 { 10^230 lo },
     -1403724234051709617 { 10^231 lo },
     -1388737822840784221 { 10^232 lo },
      7844839795278712168 { 10^233 lo },
     -1366304042406080706 { 10^234 lo },
     -1344296962351928125 { 10^235 lo },
     -1329090432005011468 { 10^236 lo },
      7909777184276130567 { 10^237 lo },
     -1299982890856469961 { 10^238 lo },
      7927555536158797039 { 10^239 lo },
     -1278096064304659477 { 10^240 lo },
     -1254807474318889671 { 10^241 lo },
     -1239746570100565880 { 10^242 lo },
     -1222386819282796715 { 10^243 lo },
     -1207102050653348054 { 10^244 lo },
     -1195877389214435595 { 10^245 lo },
     -1178080082626325927 { 10^246 lo },
      8057988658405415185 { 10^247 lo },
     -1150854961185816405 { 10^248 lo },
      8091113990793215893 { 10^249 lo },
      8106412954591121275 { 10^250 lo },
     -1105550740174742361 { 10^251 lo },
     -1085597129957553688 { 10^252 lo },
      8149550550428492702 { 10^253 lo },
      8164821955346263173 { 10^254 lo },
      8168508878667849369 { 10^255 lo },
     -1033820050253003152 { 10^256 lo },
     -1018681385453496308 { 10^257 lo },
      -999507376594005116 { 10^258 lo },
      8240096742328358811 { 10^259 lo },
      -968662499998780802 { 10^260 lo },
      8269977678330400881 { 10^261 lo },
      -948096134511284791 { 10^262 lo },
      -932918589006358212 { 10^263 lo },
      -911626432758062109 { 10^264 lo },
      -894025693644464530 { 10^265 lo },
      -883984345900012526 { 10^266 lo },
      8353524032627828969 { 10^267 lo },
      8368405709970948498 { 10^268 lo },
      -836429182278502651 { 10^269 lo },
      -821482396386446138 { 10^270 lo },
      8417243843776749316 { 10^271 lo },
      -789276009973294789 { 10^272 lo },
      8447933695112687735 { 10^273 lo },
      8465129395903213130 { 10^274 lo },
      8475978919083309533 { 10^275 lo },
      -730964565005908052 { 10^276 lo },
      -734693648934921867 { 10^277 lo },
      8520154222361446403 { 10^278 lo },
      -685262872877450498 { 10^279 lo },
      -674182806188308034 { 10^280 lo },
      -659206822920037331 { 10^281 lo },
      -643939645134603876 { 10^282 lo },
      8596151911769212925 { 10^283 lo },
      -608349489051194622 { 10^284 lo },
      8620798535177573499 { 10^285 lo },
      -584347131941928141 { 10^286 lo },
      -563938291021428224 { 10^287 lo },
      -563826130167733248 { 10^288 lo },
      -535293119523626544 { 10^289 lo },
      -520497611701306812 { 10^290 lo },
      8715443047340349227 { 10^291 lo },
      -500284800902951895 { 10^292 lo },
      8749146895201199642 { 10^293 lo },
      -459934985830883232 { 10^294 lo },
      8769928034088087312 { 10^295 lo },
      8784919622776474324 { 10^296 lo },
      -423586102007307657 { 10^297 lo },
      8819814338074970427 { 10^298 lo },
      -386724635395810757 { 10^299 lo },
      -371941703467343670 { 10^300 lo },
      -356840738277287683 { 10^301 lo },
      -339556101781516386 { 10^302 lo },
      -364395930334296743 { 10^303 lo },
      8912599740500244377 { 10^304 lo },
      8927245410063936192 { 10^305 lo },
      -289281519602406847 { 10^306 lo },
      8947714589084859183 { 10^307 lo },
      -262288240075778555 { 10^308 lo }
  );
  BNH: array[-343..-303] of QWord = (
    $3BD7E53B957505FC { B(10^-343*2^1074) hi },
    $3C0DDE8A7AD2477B { B(10^-342*2^1074) hi },
    $3C42AB168CC36CAD { B(10^-341*2^1074) hi },
    $3C7755DC2FF447D8 { B(10^-340*2^1074) hi },
    $3CAD2B533BF159CE { B(10^-339*2^1074) hi },
    $3CE23B140576D821 { B(10^-338*2^1074) hi },
    $3D16C9D906D48E29 { B(10^-337*2^1074) hi },
    $3D4C7C4F4889B1B3 { B(10^-336*2^1074) hi },
    $3D81CDB18D560F10 { B(10^-335*2^1074) hi },
    $3DB6411DF0AB92D4 { B(10^-334*2^1074) hi },
    $3DEBD1656CD67789 { B(10^-333*2^1074) hi },
    $3E2162DF64060AB6 { B(10^-332*2^1074) hi },
    $3E55BB973D078D63 { B(10^-331*2^1074) hi },
    $3E8B2A7D0C4970BC { B(10^-330*2^1074) hi },
    $3EC0FA8E27ADE675 { B(10^-329*2^1074) hi },
    $3EF53931B1996013 { B(10^-328*2^1074) hi },
    $3F2A877E1DFFB817 { B(10^-327*2^1074) hi },
    $3F6094AED2BFD30F { B(10^-326*2^1074) hi },
    $3F94B9DA876FC7D2 { B(10^-325*2^1074) hi },
    $3FC9E851294BB9C7 { B(10^-324*2^1074) hi },
    $40003132B9CF541C { B(10^-323*2^1074) hi },
    $40343D7F68432923 { B(10^-322*2^1074) hi },
    $40694CDF4253F36C { B(10^-321*2^1074) hi },
    $409FA01712E8F047 { B(10^-320*2^1074) hi },
    $40D3C40E6BD1962C { B(10^-319*2^1074) hi },
    $4108B51206C5FBB8 { B(10^-318*2^1074) hi },
    $413EE25688777AA5 { B(10^-317*2^1074) hi },
    $41734D76154AACA7 { B(10^-316*2^1074) hi },
    $41A820D39A9D57D1 { B(10^-315*2^1074) hi },
    $41DE29088144ADC6 { B(10^-314*2^1074) hi },
    $4212D9A550CAEC9B { B(10^-313*2^1074) hi },
    $4247900EA4FDA7C2 { B(10^-312*2^1074) hi },
    $427D74124E3D11B3 { B(10^-311*2^1074) hi },
    $42B2688B70E62B10 { B(10^-310*2^1074) hi },
    $42E702AE4D1FB5D4 { B(10^-309*2^1074) hi },
    $431CC359E067A349 { B(10^-308*2^1074) hi },
    $4351FA182C40C60D { B(10^-307*2^1074) hi },
    $4386789E3750F791 { B(10^-306*2^1074) hi },
    $43BC16C5C5253575 { B(10^-305*2^1074) hi },
    $43F18E3B9B374169 { B(10^-304*2^1074) hi },
    $4425F1CA820511C3 { B(10^-303*2^1074) hi }
  );
  BNL: array[-343..-303] of Int64 = (
     -5159690598842135432 { B(10^-343*2^1074) lo },
     -5144695256522068074 { B(10^-342*2^1074) lo },
     -5125028576639503649 { B(10^-341*2^1074) lo },
     -5120253779779649958 { B(10^-340*2^1074) lo },
     -5105532331855544847 { B(10^-339*2^1074) lo },
     -5079114560109861970 { B(10^-338*2^1074) lo },
     -5070940431322719950 { B(10^-337*2^1074) lo },
      4163295982762877187 { B(10^-336*2^1074) lo },
     -5043573937215028386 { B(10^-335*2^1074) lo },
     -5028822827066092490 { B(10^-334*2^1074) lo },
     -5013761639100450493 { B(10^-333*2^1074) lo },
     -4986525345841316109 { B(10^-332*2^1074) lo },
     -4986883171666168455 { B(10^-331*2^1074) lo },
     -4961777912004831653 { B(10^-330*2^1074) lo },
      4279365447513825799 { B(10^-329*2^1074) lo },
     -4929246144139983497 { B(10^-328*2^1074) lo },
      4306074633698335019 { B(10^-327*2^1074) lo },
     -4896371613612738491 { B(10^-326*2^1074) lo },
      4334859888182940500 { B(10^-325*2^1074) lo },
     -4872704101112439828 { B(10^-324*2^1074) lo },
      4367127369014492441 { B(10^-323*2^1074) lo },
      4382275668879029808 { B(10^-322*2^1074) lo },
      4387872194296549103 { B(10^-321*2^1074) lo },
      4402850432394924715 { B(10^-320*2^1074) lo },
      4430436670406589163 { B(10^-319*2^1074) lo },
     -4779189300796307877 { B(10^-318*2^1074) lo },
      4457399451478370319 { B(10^-317*2^1074) lo },
      4474724517437917449 { B(10^-316*2^1074) lo },
      4485455048067495575 { B(10^-315*2^1074) lo },
     -4720816946395173406 { B(10^-314*2^1074) lo },
      4521140961542443859 { B(10^-313*2^1074) lo },
      4532281694526486568 { B(10^-312*2^1074) lo },
     -4687542359796783302 { B(10^-311*2^1074) lo },
     -4664101572729810878 { B(10^-310*2^1074) lo },
     -4649057963634351022 { B(10^-309*2^1074) lo },
     -4633917584274897228 { B(10^-308*2^1074) lo },
      4610944048293127120 { B(10^-307*2^1074) lo },
     -4605327493464365447 { B(10^-306*2^1074) lo },
      4620158362835091274 { B(10^-305*2^1074) lo },
      4648376717353203698 { B(10^-304*2^1074) lo },
      4668957652414722807 { B(10^-303*2^1074) lo }
  );

function strtod(nptr: PAnsiChar; endptr: PPAnsiChar): Double; cdecl;
{$IFDEF CPUX86_64}
procedure ClearFPUFlags;
{ 清除 MXCSR 的 6 个异常标志位而不改屏蔽掩码：
  FPC 的 try/except 不恢复 FPU 状态，异常后滞留的标志会让后续浮点运算误抛 }
begin
  asm
    subq $8, %rsp
    stmxcsr (%rsp)
    movl (%rsp), %eax
    andl $0xFFFFFFC0, %eax
    movl %eax, (%rsp)
    ldmxcsr (%rsp)
    addq $8, %rsp
  end;
end;
{$ELSE}
{$IFDEF CPUX86}
procedure ClearFPUFlags;
begin
  { i386：同 x86_64，但用 %esp 且不依赖红区（i386 无红区保证） }
  asm
    subl $8, %esp
    stmxcsr (%esp)
    movl (%esp), %eax
    andl $0xFFFFFFC0, %eax
    movl %eax, (%esp)
    ldmxcsr (%esp)
    addl $8, %esp
  end;
end;
{$ELSE}
procedure ClearFPUFlags;
begin
  { 非 x86 目标无 MXCSR：FPC 默认不陷浮点异常，无滞留标志需清 }
end;
{$ENDIF}
{$ENDIF}

{ 与溢出阈值 T=2^1024-2^970（= DBL_MAX + 0.5ulp，309 位十进制整数）
  的前 60 位比较：S 某位大于 T 同位列 → 1（溢）；小于或 S 是 T 的
  真前缀（T 尾部位非零）→ -1。前 60 位全等且更长（概率 <1e-60，
  判定差 < 0.5ulp×1e-40）按不溢处理 }
function CmpT60(const S: array of AnsiChar; SLen: LongInt): LongInt;
const T60 = '179769313486231580793728971405303415079934132710037826936173';
var J: LongInt;
begin
  for J := 1 to SLen do begin
    if S[J - 1] < T60[J] then begin Result := -1; Exit; end;
    if S[J - 1] > T60[J] then begin Result := 1; Exit; end;
  end;
  Result := -1;
end;

{ Dekker 双精度乘积：hi+lo = a*b 精确（无 FMA 版），用于 k=308 大值幂乘 }
procedure TwoProd(const a, b: Double; out hi, lo: Double);
var ah, al, bh, bl, c: Double;
begin
  c := 134217729.0 * a; { (2^27+1) }
  ah := c - (c - a);
  al := a - ah;
  c := 134217729.0 * b;
  bh := c - (c - b);
  bl := b - bh;
  hi := a * b;
  lo := ((ah * bh - hi) + ah * bl + al * bh) + al * bl;
end;


var
  P: PAnsiChar;
  Neg: Boolean;
  Buf: array[0..511] of AnsiChar;
  I: LongInt;
  D: LongInt;
  HasDigits: Boolean;
  AnyNonZero: Boolean;
  IsHex: Boolean;
  ValErr: Integer;
  X: Double;
  L: LongInt;
  Bits: QWord;
  Scale: Double;
  ExpNeg: Boolean;
  ExpBits: Int64;
  ExpNegDec: Boolean;
  C: AnsiChar;
  Di: LongInt;
  Df: LongInt;
  SigCount: LongInt;
  ExpSign: LongInt;
  HasDecPoint: Boolean;
  FirstSig: Boolean;
  FirstInt: Boolean;
  KIntBase: LongInt;
  R: Boolean;
  HasExp: Boolean;
  Mhi: Int64;  { 尾数高 15 位（Double 精确）}
  Mlo: Int64;  { 尾数低 5 位（第 16-20 位）}
  MHw: Int64;
  MLw: Int64;
  SCh: LongInt;
  SCl: LongInt;
  k: Int64;
  KTotal: Int64;
  Ei: Int64;
  Overflow: Boolean;
  Underflow: Boolean;
  S60: array[0..59] of AnsiChar;
  S60Len: LongInt;
  Beyond60: Boolean;
  Q64: QWord;
  { hex 分支整数尾数（≤64 bit）与拼装 }
  M: QWord;
  MBits: LongInt;
  DfHex: LongInt;
  HexLost: Boolean;
  CutHex: LongInt;
  { decimal 高精度幂乘 }
  KIntL: LongInt;
  QN: QWord;
  HexExact: Boolean;
  QW: QWord;
  EvalI: Int64;
  Rg: Int64;
  BL: LongInt;
  mant: QWord;
  remLW: QWord;
  half: QWord;
  g: QWord;
  { NAN(n-char) payload：base-0 strtoul 语义 }
  NBuf: array[0..63] of AnsiChar;
  NLen: LongInt;
  NVal: QWord;
  NBase: LongInt;
  Novf: Boolean;
  Novak: Boolean;
  T: Int64;
  Idx: LongInt;
  Cmp: LongInt;
  THd: Double;
  TLd: Double;
  E308: LongInt;
  E308L: LongInt;
  H1: Double;
  L1: Double;
  H2: Double;
  L2: Double;
  H1b: Double;
  L1b: Double;
  H2b: Double;
  L2b: Double;
  Wh: Double;
  Wl: Double;
  WlB: Double;
  F2: Double; { BN 缩放临时（2^-1074）}
  XN: Double;

  { 双 double 幂乘：W（Wh+Wl 精确对）× 10^K。
    TH+TL = 10^K（106 位双 double 表；TL 可负/次正规/0，不作
    指数拆解——次正规低段无 [1,2)×2^E 规范形，拆解会放大误差）。
    主段 TwoProd(TH,Wh) 精确，TH×Wl 与 TL×W 并入低段，每步只摊
    ~2^-106 相对误差，最终一次舍入即正确 }
  function Pmul(Wh, Wl: Double; K: LongInt): Double;
  var fH, fL, H1, L1, B1, B2: Double;
  begin
    Move(TENH[K], fH, 8);
    Move(TENL[K], fL, 8);
    TwoProd(fH, Wh, H1, L1);
    L1 := L1 + fH * Wl;
    B1 := fL * Wh;
    B2 := fL * Wl;
    L1 := L1 + B1;
    L1 := L1 + B2;
    Result := H1 + L1;
  end;

  { BN 网格倍数定点版（表 B = 10^K×2^1074，全正规域），同 Pmul 结构 }
  function PmulB(Wh, Wl: Double; K: LongInt): Double;
  var fH, fL, H1, L1, B1, B2: Double;
  begin
    Move(BNH[K], fH, 8);
    Move(BNL[K], fL, 8);
    TwoProd(fH, Wh, H1, L1);
    L1 := L1 + fH * Wl;
    B1 := fL * Wh;
    B2 := fL * Wl;
    L1 := L1 + B1;
    L1 := L1 + B2;
    Result := H1 + L1;
  end;

begin
  Result := 0.0;
  if nptr = nil then begin
    if endptr <> nil then endptr^ := nptr;
    Exit;
  end;
  P := nptr;
  while (P^ <> #0) and ((P^ = ' ') or (P^ = #9) or (P^ = #10) or
        (P^ = #11) or (P^ = #12) or (P^ = #13)) do Inc(P);
  Neg := False;
  if P^ = '+' then Inc(P)
  else if P^ = '-' then begin Neg := True; Inc(P); end;
  { INF / INFINITY (case-insensitive, must start at P) }
  if (P^ <> #0) and ((UpCase(P^) = 'I') and (P[1] <> #0) and
     (UpCase(P[1]) = 'N') and (P[2] <> #0) and (UpCase(P[2]) = 'F')) then
  begin
    L := 3;
    if (P[3] <> #0) and (UpCase(P[3]) = 'I') and (P[4] <> #0) and
       (UpCase(P[4]) = 'N') and (P[5] <> #0) and (UpCase(P[5]) = 'I') and
       (P[6] <> #0) and (UpCase(P[6]) = 'T') and (P[7] <> #0) and
       (UpCase(P[7]) = 'Y') then L := 8;
    { +Inf via bit pattern: avoids FPC EOverflow on literal overflow }
    Bits := $7FF0000000000000;
    Move(Bits, X, 8);
    if Neg then X := -X;
    if endptr <> nil then endptr^ := P + L;
    Result := X;
    Exit;
  end;
  { NAN / NAN(n-char-sequence) }
  if (P^ <> #0) and ((UpCase(P^) = 'N') and (P[1] <> #0) and
     (UpCase(P[1]) = 'A') and (P[2] <> #0) and (UpCase(P[2]) = 'N')) then
  begin
    L := 3;
    NLen := 0;
    if P[3] = '(' then begin
      Inc(L); { '(' consumed }
      while P[L] <> #0 do begin
        C := P[L];
        if ((C >= 'a') and (C <= 'z')) or ((C >= 'A') and (C <= 'Z')) or
           ((C >= '0') and (C <= '9')) or (C = '_') then begin
          if NLen < 64 then begin NBuf[NLen] := C; Inc(NLen); end;
          Inc(L)
        end
        else break;
      end;
      if P[L] = ')' then begin
        { glibc(含 GCC __builtin_nan) 的 payload 映射：
          base-0 strtoul 语义（0x → hex、前导 0 → oct、否则 dec），
          必须整体合法否则 payload=0；数值溢出（strtoul 给 ULONG_MAX）→ 52 位全 1 }
        Inc(L);
        Novak := False;
        NVal := 0;
        NBase := 10;
        Idx := 0;
        if NLen = 0 then Novak := True
        else if (NLen >= 2) and (NBuf[0] = '0') and
                ((NBuf[1] = 'x_2') or (NBuf[1] = 'X')) then begin
          NBase := 16;
          Idx := 2;
          if NLen = 2 then Novak := True; { '0x' 后无数字：整体不合法 }
        end
        else if NBuf[0] = '0' then NBase := 8; { 前导 0 → octal }
        if not Novak then begin
          Novf := False;
          while Idx < NLen do begin
            C := NBuf[Idx];
            D := -1;
            if (C >= '0') and (C <= '9') then D := Ord(C) - 48
            else if (C >= 'a') and (C <= 'f') then D := Ord(C) - 87
            else if (C >= 'A') and (C <= 'F') then D := Ord(C) - 55;
            if (D < 0) or (D >= NBase) then begin Novak := True; break; end;
            { 注意 D/NBase 为有符号：须显式转 QWord 强制无符号除法 }
            if NVal > (High(QWord) - QWord(D)) div QWord(NBase) then Novf := True;
            NVal := NVal * NBase + D;
            Inc(Idx);
          end;
        end;
        if Novak then NVal := 0
        else if Novf then NVal := $FFFFFFFFFFFFF
        else NVal := NVal and $FFFFFFFFFFFFF;
        Bits := $7FF8000000000000 or NVal;
      end
      else begin
        L := 3; { 无闭合括号：括号组整体不消费（C99/glibc）}
        Bits := $7FF8000000000000;
      end;
    end
    else begin
      Bits := $7FF8000000000000;
    end;
    Move(Bits, X, 8);
    if Neg then X := -X;
    if endptr <> nil then endptr^ := P + L;
    Result := X;
    Exit;
  end;
  { hex float: 0x/0X with >=1 hex digit (after optional '.') to confirm }
  IsHex := False;
  if (P^ = '0') and ((P[1] = 'x_2') or (P[1] = 'X')) then begin
    D := -1;
    if (P[2] >= '0') and (P[2] <= '9') then D := Ord(P[2]) - 48
    else if (P[2] >= 'a') and (P[2] <= 'f') then D := Ord(P[2]) - 87
    else if (P[2] >= 'A') and (P[2] <= 'F') then D := Ord(P[2]) - 55;
    if D >= 0 then IsHex := True
    else if P[2] = '.' then begin
      D := -1;
      if (P[3] >= '0') and (P[3] <= '9') then D := Ord(P[3]) - 48
      else if (P[3] >= 'a') and (P[3] <= 'f') then D := Ord(P[3]) - 87
      else if (P[3] >= 'A') and (P[3] <= 'F') then D := Ord(P[3]) - 55;
      if D >= 0 then IsHex := True;
    end;
  end;
  HasDigits := False;
  AnyNonZero := False;
  if IsHex then begin
    Inc(P, 2); { consume 0x prefix }
    M := 0;
    MBits := 0;
    DfHex := 0;
    HexLost := False;
    CutHex := 0;
    ExpBits := 0;
    try
      { integer hex digits }
      while P^ <> #0 do begin
        D := -1;
        if (P^ >= '0') and (P^ <= '9') then D := Ord(P^) - 48
        else if (P^ >= 'a') and (P^ <= 'f') then D := Ord(P^) - 87
        else if (P^ >= 'A') and (P^ <= 'F') then D := Ord(P^) - 55;
        if D < 0 then break;
        HasDigits := True;
        if D <> 0 then AnyNonZero := True;
        if MBits >= 64 then begin
          if D <> 0 then HexLost := True;
          Inc(CutHex); { 被截断的 hex 位：量级修正 4×CutHex }
        end else begin
          M := (M shl 4) or QWord(D);
          Inc(MBits, 4);
        end;
        Inc(P);
      end;
      if P^ = '.' then begin
        Inc(P);
        while P^ <> #0 do begin
          D := -1;
          if (P^ >= '0') and (P^ <= '9') then D := Ord(P^) - 48
          else if (P^ >= 'a') and (P^ <= 'f') then D := Ord(P^) - 87
          else if (P^ >= 'A') and (P^ <= 'F') then D := Ord(P^) - 55;
          if D < 0 then break;
          HasDigits := True;
          if D <> 0 then AnyNonZero := True;
          Inc(DfHex);
          if MBits >= 64 then begin
            if D <> 0 then HexLost := True;
            Inc(CutHex);
          end else begin
            M := (M shl 4) or QWord(D);
            Inc(MBits, 4);
          end;
          Inc(P);
        end;
      end;
      { hex exponent p[+-]digits }
      if ((P^ = 'p') or (P^ = 'P')) and (P[1] <> #0) and
         (((P[1] >= '0') and (P[1] <= '9')) or
          ((P[1] = '+') and (P[2] <> #0) and (P[2] >= '0') and (P[2] <= '9')) or
          ((P[1] = '-') and (P[2] <> #0) and (P[2] >= '0') and (P[2] <= '9'))) then
      begin
        Inc(P);
        ExpNeg := False;
        if P^ = '+' then Inc(P)
        else if P^ = '-' then begin ExpNeg := True; Inc(P); end;
        ExpBits := 0;
        while (P^ >= '0') and (P^ <= '9') do begin
          if ExpBits < 1000000 then ExpBits := ExpBits * 10 + (Ord(P^) - 48);
          Inc(P);
        end;
        if ExpNeg then ExpBits := -ExpBits;
        if ExpBits > 4096 then ExpBits := 4096
        else if ExpBits < -4096 then ExpBits := -4096;
      end;
    except
      { 防御兜底（不应触发）}
      X := 0.0;
      Bits := $7FF0000000000000;
      Move(Bits, X, 8); { +Inf }
      ClearFPUFlags;
      if Neg then X := -X;
      if endptr <> nil then endptr^ := P;
      __errno_location()^ := 34;
      Result := X;
      Exit;
    end;
    if endptr <> nil then endptr^ := P;
    if not AnyNonZero then begin
      { 全零 hex：不设 errno（glibc）}
      X := 0.0;
      if Neg then X := -X;
      Result := X;
      Exit;
    end;
    { 值 = M × 2^T，T = ExpBits - 4*DfHex + 4*CutHex（CutHex 补回
      被 64-bit 窗口截断的低位量级）；一次规格化 + round-to-nearest-even }
    T := ExpBits - 4 * DfHex + 4 * CutHex;
    QW := M;
    L := 0;
    while QW > 1 do begin QW := QW shr 1; Inc(L); end;
    EvalI := T + L;
    if EvalI > 1023 then begin
      Bits := $7FF0000000000000;
      Move(Bits, X, 8);
      if Neg then X := -X;
      __errno_location()^ := 34;
      Result := X;
      Exit;
    end;
    if EvalI >= -1022 then begin
      { 正规数：msb 移到 bit 52（隐含位），低位截断时 round-half-even }
      BL := L - 52;
      if BL <= 0 then
        mant := M shl (-BL)
      else begin
        remLW := M and ((QWord(1) shl BL) - 1);
        mant := M shr BL;
        half := QWord(1) shl (BL - 1);
        if (remLW > half) or ((remLW = half) and ((mant and 1) = 1)) then
          Inc(mant);
        if mant = (QWord(1) shl 53) then begin
          { 尾数进位：EvalI+1，回到 2^52 }
          mant := QWord(1) shl 52;
          Inc(EvalI);
          if EvalI > 1023 then begin
            Bits := $7FF0000000000000;
            Move(Bits, X, 8);
            if Neg then X := -X;
            __errno_location()^ := 34;
            Result := X;
            Exit;
          end;
        end;
      end;
      Bits := (QWord(EvalI + 1023) shl 52) or (mant and $FFFFFFFFFFFFF);
      Move(Bits, X, 8);
      if Neg then X := -X;
      Result := X;
      Exit;
    end;
    { 次正规：网格 2^-1074，网格数 = M × 2^Rg，Rg = T + 1074
      （glibc：仅当结果非精确才置 ERANGE）}
    Rg := T + 1074;
    HexExact := True;
    if Rg >= 0 then begin
      { Rg ≤ 51-L（次正规域）→ 网格数 < 2^52：QWord 无溢出、无舍入、精确 }
      g := M shl Rg;
      Bits := g;
    end else begin
      BL := LongInt(-Rg);
      if BL >= 64 then begin
        { 网格数 < 0.5：舍入到 0（M<2^BL ⇒ rem<half）}
        g := 0;
        HexExact := False;
      end else begin
        g := M shr BL;
        remLW := M and ((QWord(1) shl BL) - 1);
        half := QWord(1) shl (BL - 1);
        if (remLW > half) or ((remLW = half) and ((g and 1) = 1)) then
          Inc(g);
        if remLW <> 0 then HexExact := False;
      end;
      if HexLost then HexExact := False; { 64-bit 截断也属非精确 }
      if g >= (QWord(1) shl 52) then
        Bits := $0010000000000000 { 进位到 DBL_MIN（正规下边界）}
      else
        Bits := g;
    end;
    Move(Bits, X, 8);
    if Neg then X := -X;
    if not HexExact then __errno_location()^ := 34;
    Result := X;
    Exit;
  end;
  { decimal: 扫描有效数字结构，同时预判量级 k（首位有效数字的 10 次幂）}
  I := 0;
  SigCount := 0;
  Di := 0;
  Df := 0;
  HasDecPoint := False;
  FirstSig := False;
  FirstInt := False;
  KIntBase := 0;
  k := 0;
  Mhi := 0;
  Mlo := 0;
  R := False;
  S60Len := 0;
  Beyond60 := False;
  while P^ <> #0 do begin
    if (P^ >= '0') and (P^ <= '9') then begin
      if I < 480 then begin Buf[I] := P^; Inc(I); end;
      if P^ <> '0' then AnyNonZero := True;
      HasDigits := True;
      if HasDecPoint then Inc(Df) else Inc(Di);
      if not FirstSig then begin
        if P^ <> '0' then begin
          FirstSig := True;
          if HasDecPoint then k := -Df
          else begin
            FirstInt := True;
            KIntBase := Di; { 首位有效时的整数位数，扫描后再定 k }
          end;
        end;
      end;
      if FirstSig then begin
        Inc(SigCount);
        if SigCount <= 60 then begin
          S60[SigCount - 1] := P^;
          if SigCount <= 15 then Mhi := Mhi * 10 + (Ord(P^) - 48)
          else if SigCount <= 20 then Mlo := Mlo * 10 + (Ord(P^) - 48);
        end else if P^ <> '0' then Beyond60 := True;
      end;
      Inc(P);
    end else if (P^ = '.') and (not HasDecPoint) then begin
      if I < 480 then begin Buf[I] := '.'; Inc(I); end;
      HasDecPoint := True;
      Inc(P);
    end else break;
  end;
  if FirstInt then k := Di - KIntBase;
  { exponent: consume only if followed by a valid exponent }
  ExpNegDec := False;
  Ei := 0;
  ExpSign := 1;
  HasExp := False;
  if ((P^ = 'e') or (P^ = 'E')) and (P[1] <> #0) and
     (((P[1] >= '0') and (P[1] <= '9')) or
      ((P[1] = '+') and (P[2] <> #0) and (P[2] >= '0') and (P[2] <= '9')) or
      ((P[1] = '-') and (P[2] <> #0) and (P[2] >= '0') and (P[2] <= '9'))) then
  begin
    HasExp := True;
    if I < 480 then begin Buf[I] := 'e'; Inc(I); end;
    Inc(P);
    if P^ = '+' then begin if I < 480 then begin Buf[I] := '+'; Inc(I); end; Inc(P); end
    else if P^ = '-' then begin
      ExpNegDec := True;
      ExpSign := -1;
      if I < 480 then begin Buf[I] := '-'; Inc(I); end;
      Inc(P);
    end;
    while P^ <> #0 do begin
      if (P^ >= '0') and (P^ <= '9') then begin
        if I < 480 then begin Buf[I] := P^; Inc(I); end;
        if Ei < 100000000000000 then
          Ei := Ei * 10 + (Ord(P^) - 48); { 饱和防 Int64 溢出 }
        Inc(P);
      end else break;
    end;
  end;
  if not HasDigits then begin
    { no conversion: endptr = original nptr (C99) }
    if endptr <> nil then endptr^ := nptr;
    Result := 0.0;
    Exit;
  end;
  KTotal := k + ExpSign * Ei;
  { 溢出/下溢预判仅适用于非全零输入（全零不设 ERANGE、永不溢出/下溢）}
  if FirstSig then begin
    Overflow := KTotal > 308;
    if KTotal = 308 then begin
    if SigCount > 60 then S60Len := 60 else S60Len := SigCount;
    Cmp := CmpT60(S60, S60Len);
    Overflow := Cmp > 0;
  end;
    Underflow := KTotal < -324;
  end else begin
    Overflow := False;
    Underflow := False;
  end;
  Buf[I] := #0;
  if Overflow then begin
    X := 0.0;
    Bits := $7FF0000000000000;
    Move(Bits, X, 8); { +Inf }
    if Neg then X := -X;
    if endptr <> nil then endptr^ := P;
    __errno_location()^ := 34;
    Result := X;
    Exit;
  end;
  if Underflow then begin
    X := 0.0;
    if Neg then X := -X; { -0.0 保留符号（C99）}
    if endptr <> nil then endptr^ := P;
    __errno_location()^ := 34;
    Result := X;
    Exit;
  end;
  if not FirstSig then begin
    { 全零：±0，不设 errno（0e999 等）}
    X := 0.0;
    if Neg then X := -X;
    if endptr <> nil then endptr^ := P;
    Result := X;
    Exit;
  end;
  { 尾部补零：Mhi 15 位 / Mlo 5 位（M20 = MHw×1e5+MLw；SC>20 的
    截断误差 ≤ 10^-20 相对 << 0.5ulp，不影响舍入正确性）}
  if SigCount > 15 then begin SCh := 15; SCl := SigCount - 15; end
  else begin SCh := SigCount; SCl := 0; end;
  MHw := Mhi;
  MLw := Mlo;
  for I := SCh to 14 do MHw := MHw * 10;
  for I := SCl to 4 do MLw := MLw * 10;
  KIntL := KTotal - 19; { 表下标（值 = M20×10^KIntL）}
  { 合成双 double 尾数对：Wh+Wl = MHw×1e5 精确，WlB ≈ Wl + MLw = M20。
    单次幂乘吃全 20 位；两段独立幂乘相加会先丢 Mlo 低位再合并（1ulp 级）}
  TwoProd(Double(MHw), 100000.0, Wh, Wl);
  WlB := Wl + Double(MLw);
  if KIntL <= -308 then begin
    { BN 定点：网格数 = M20×B(KIntL)（B=10^K×2^1074 双 double，正规域），
      结果 = QN×2^-1074。覆盖次正规与 DBL_MIN 邻近（含舍入进位）}
    try
      XN := PmulB(Wh, WlB, KIntL);
    except
      ClearFPUFlags;
      XN := 0.0;
    end;
    { 直接 ×2^-1074 得结果：正规/次正规都由浮点精确舍入到网格。
      XN 误差 2^-104 相对 → 绝对 ~2^-1178 << 0.5 网格，舍入正确。
      不做网格整数拼接——QN 可达 2^114，Int64 的 Trunc 会硬件异常 }
    Bits := 1; { 2^-1074（最小次正规）}
    Move(Bits, F2, 8);
    X := XN * F2;
    Q64 := 0;
    Move(X, Q64, 8);
    if (Q64 and $7FF0000000000000) = 0 then
      __errno_location()^ := 34; { 十进制次正规无条件 ERANGE }
    if Neg then X := -X;
    if endptr <> nil then endptr^ := P;
    Result := X;
    Exit;
  end;
  { 主幂乘：值 = M20×10^KIntL（KIntL ∈ [-307, 289]，10^KIntL 正规 double）。
    双 double 单次幂乘 ~2^-106 相对误差，替代 FPC Val（其上溢/下溢/
    1ulp/MXCSR 均不可靠）}
  try
    X := Pmul(Wh, WlB, KIntL);
  except
    { 数学值 ∈ (DBL_MAX, DBL_MAX+0.5ulp]：C99 舍入到 DBL_MAX（不溢）}
    ClearFPUFlags;
    Q64 := $7FEFFFFFFFFFFFFF;
    Move(Q64, X, 8);
  end;
  if Neg then X := -X;
  if endptr <> nil then endptr^ := P;
  Q64 := 0;
  Move(X, Q64, 8);
  { 位模式后判定（幂乘正确性兜底；十进制仅次正规无条件 ERANGE）}
  if (Q64 = QWord($7FF0000000000000)) or (Q64 = QWord($FFF0000000000000)) then
    __errno_location()^ := 34
  else if (Q64 = 0) or (Q64 = QWord($8000000000000000)) then
    __errno_location()^ := 34
  else if (Q64 and $7FFFFFFFFFFFFFFF <> 0) and
          ((Q64 and $7FF0000000000000) = 0) then
    __errno_location()^ := 34;
  Result := X;
end;


function strtof(nptr: PAnsiChar; endptr: PPAnsiChar): Single; cdecl;
{$IFDEF CPUX86_64}
procedure ClearFPUFlags;
{ 清除 MXCSR 的 6 个异常标志位而不改屏蔽掩码：
  FPC 的 try/except 不恢复 FPU 状态，异常后滞留的标志会让后续浮点运算误抛 }
begin
  asm
    subq $8, %rsp
    stmxcsr (%rsp)
    movl (%rsp), %eax
    andl $0xFFFFFFC0, %eax
    movl %eax, (%rsp)
    ldmxcsr (%rsp)
    addq $8, %rsp
  end;
end;
{$ELSE}
{$IFDEF CPUX86}
procedure ClearFPUFlags;
begin
  { i386：同 x86_64，但用 %esp 且不依赖红区（i386 无红区保证） }
  asm
    subl $8, %esp
    stmxcsr (%esp)
    movl (%esp), %eax
    andl $0xFFFFFFC0, %eax
    movl %eax, (%esp)
    ldmxcsr (%esp)
    addl $8, %esp
  end;
end;
{$ELSE}
procedure ClearFPUFlags;
begin
  { 非 x86 目标无 MXCSR：FPC 默认不陷浮点异常，无滞留标志需清 }
end;
{$ENDIF}
{$ENDIF}

{ 与溢出阈值 T=2^1024-2^970（= DBL_MAX + 0.5ulp，309 位十进制整数）
  的前 60 位比较：S 某位大于 T 同位列 → 1（溢）；小于或 S 是 T 的
  真前缀（T 尾部位非零）→ -1。前 60 位全等且更长（概率 <1e-60，
  判定差 < 0.5ulp×1e-40）按不溢处理 }
function CmpT60(const S: array of AnsiChar; SLen: LongInt): LongInt;
const T60 = '179769313486231580793728971405303415079934132710037826936173';
var J: LongInt;
begin
  for J := 1 to SLen do begin
    if S[J - 1] < T60[J] then begin Result := -1; Exit; end;
    if S[J - 1] > T60[J] then begin Result := 1; Exit; end;
  end;
  Result := -1;
end;

{ Dekker 双精度乘积：hi+lo = a*b 精确（无 FMA 版），用于 k=308 大值幂乘 }
procedure TwoProd(const a, b: Double; out hi, lo: Double);
var ah, al, bh, bl, c: Double;
begin
  c := 134217729.0 * a; { (2^27+1) }
  ah := c - (c - a);
  al := a - ah;
  c := 134217729.0 * b;
  bh := c - (c - b);
  bl := b - bh;
  hi := a * b;
  lo := ((ah * bh - hi) + ah * bl + al * bh) + al * bl;
end;


var
  FBits: LongWord;
  QW64: QWord;
  AbsQ: QWord;
  S: LongInt;
  THo: Double;
  TLo: Double;
  P: PAnsiChar;
  Neg: Boolean;
  Buf: array[0..511] of AnsiChar;
  I: LongInt;
  D: LongInt;
  HasDigits: Boolean;
  AnyNonZero: Boolean;
  IsHex: Boolean;
  ValErr: Integer;
  X: Double;
  L: LongInt;
  Bits: QWord;
  Scale: Double;
  ExpNeg: Boolean;
  ExpBits: Int64;
  ExpNegDec: Boolean;
  C: AnsiChar;
  Di: LongInt;
  Df: LongInt;
  SigCount: LongInt;
  ExpSign: LongInt;
  HasDecPoint: Boolean;
  FirstSig: Boolean;
  FirstInt: Boolean;
  KIntBase: LongInt;
  R: Boolean;
  HasExp: Boolean;
  Mhi: Int64;  { 尾数高 15 位（Double 精确）}
  Mlo: Int64;  { 尾数低 5 位（第 16-20 位）}
  MHw: Int64;
  MLw: Int64;
  SCh: LongInt;
  SCl: LongInt;
  k: Int64;
  KTotal: Int64;
  Ei: Int64;
  Overflow: Boolean;
  Underflow: Boolean;
  S60: array[0..59] of AnsiChar;
  S60Len: LongInt;
  Beyond60: Boolean;
  Q64: QWord;
  { hex 分支整数尾数（≤64 bit）与拼装 }
  M: QWord;
  MBits: LongInt;
  DfHex: LongInt;
  HexLost: Boolean;
  CutHex: LongInt;
  { decimal 高精度幂乘 }
  KIntL: LongInt;
  QN: QWord;
  HexExact: Boolean;
  QW: QWord;
  EvalI: Int64;
  Rg: Int64;
  BL: LongInt;
  mant: QWord;
  remLW: QWord;
  half: QWord;
  g: QWord;
  { NAN(n-char) payload：base-0 strtoul 语义 }
  NBuf: array[0..63] of AnsiChar;
  NLen: LongInt;
  NVal: QWord;
  NBase: LongInt;
  Novf: Boolean;
  Novak: Boolean;
  T: Int64;
  Idx: LongInt;
  Cmp: LongInt;
  THd: Double;
  TLd: Double;
  E308: LongInt;
  E308L: LongInt;
  H1: Double;
  L1: Double;
  H2: Double;
  L2: Double;
  H1b: Double;
  L1b: Double;
  H2b: Double;
  L2b: Double;
  Wh: Double;
  Wl: Double;
  WlB: Double;
  F2: Double; { BN 缩放临时（2^-1074）}
  XN: Double;

  { 双 double 幂乘：W（Wh+Wl 精确对）× 10^K。
    TH+TL = 10^K（106 位双 double 表；TL 可负/次正规/0，不作
    指数拆解——次正规低段无 [1,2)×2^E 规范形，拆解会放大误差）。
    主段 TwoProd(TH,Wh) 精确，TH×Wl 与 TL×W 并入低段，每步只摊
    ~2^-106 相对误差，最终一次舍入即正确 }
  function Pmul(Wh, Wl: Double; K: LongInt): Double;
  var fH, fL, H1, L1, B1, B2: Double;
  begin
    Move(TENH[K], fH, 8);
    Move(TENL[K], fL, 8);
    TwoProd(fH, Wh, H1, L1);
    L1 := L1 + fH * Wl;
    B1 := fL * Wh;
    B2 := fL * Wl;
    L1 := L1 + B1;
    L1 := L1 + B2;
    THo := H1;
    TLo := L1;
    Result := H1 + L1;
  end;

  { BN 网格倍数定点版（表 B = 10^K×2^1074，全正规域），同 Pmul 结构 }
  function PmulB(Wh, Wl: Double; K: LongInt): Double;
  var fH, fL, H1, L1, B1, B2: Double;
  begin
    Move(BNH[K], fH, 8);
    Move(BNL[K], fL, 8);
    TwoProd(fH, Wh, H1, L1);
    L1 := L1 + fH * Wl;
    B1 := fL * Wh;
    B2 := fL * Wl;
    L1 := L1 + B1;
    L1 := L1 + B2;
    THo := H1;
    TLo := L1;
    Result := H1 + L1;
  end;

  { 106-bit double-double -> correct float rounding (round-half-even).
    Rounding through an intermediate double flips at the float 0.5ulp
    boundary (double rounding); use the exact residue R=(Hi-F)+Lo to
    pick the direction (error ~2^-105, tie misread ~2^-80) }
  function FloatR2(Hi, Lo: Double): Single;
  var FB, FB2: LongWord;
      Fv: Single;
      D, Up, Half, R: Double;
  begin
    Fv := Single(Hi);
    Move(Fv, FB, 4);
    if (FB and $7FFFFFFF) = 0 then begin
      { F = +-0: direction set by Hi+Lo vs half of min subnormal }
      FB2 := 1;
      Move(FB2, Fv, 4);
      Half := Double(Fv) * 0.5; { 2^-150 }
      R := Hi + Lo;
      if (FB shr 31) <> 0 then begin
        if R < -Half then FB := $80000001;
      end else begin
        if R > Half then FB := 1;
      end;
      Move(FB, Result, 4);
      Exit;
    end;
    D := Double(Fv);
    R := (Hi - D) + Lo;
    { next float toward +inf: FB2 = FB+1. At FLT_MAX it is +-Inf
      (Half not representable; use exact 2^103 double; tie only at
      float extremes) }
    FB2 := FB + 1;
    if (FB2 and $7F800000) = $7F800000 then begin
      if (FB shr 31) <> 0 then
        Bits := QWord($C660000000000000) { -2^103 }
      else
        Bits := QWord($4660000000000000); { +2^103 }
      Move(Bits, Half, 8);
    end else begin
      Move(FB2, Fv, 4);
      Up := Double(Fv);
      Half := (Up - D) * 0.5;
    end;
    if R > Half then
      FB := FB + 1
    else if R < -Half then
      FB := FB - 1;
    Move(FB, Result, 4);
  end;
begin
  Result := 0.0;
  IsHex := False;
  if nptr = nil then begin
    if endptr <> nil then endptr^ := nptr;
    Exit;
  end;
  P := nptr;
  while (P^ <> #0) and ((P^ = ' ') or (P^ = #9) or (P^ = #10) or
        (P^ = #11) or (P^ = #12) or (P^ = #13)) do Inc(P);
  Neg := False;
  if P^ = '+' then Inc(P)
  else if P^ = '-' then begin Neg := True; Inc(P); end;
  { INF / INFINITY (case-insensitive, must start at P) }
  if (P^ <> #0) and ((UpCase(P^) = 'I') and (P[1] <> #0) and
     (UpCase(P[1]) = 'N') and (P[2] <> #0) and (UpCase(P[2]) = 'F')) then
  begin
    L := 3;
    if (P[3] <> #0) and (UpCase(P[3]) = 'I') and (P[4] <> #0) and
       (UpCase(P[4]) = 'N') and (P[5] <> #0) and (UpCase(P[5]) = 'I') and
       (P[6] <> #0) and (UpCase(P[6]) = 'T') and (P[7] <> #0) and
       (UpCase(P[7]) = 'Y') then L := 8;
    { +Inf via bit pattern: avoids FPC EOverflow on literal overflow }
    Bits := $7FF0000000000000;
    Move(Bits, X, 8);
    if Neg then X := -X;
    if endptr <> nil then endptr^ := P + L;
    begin
      Move(X, QW64, 8);
      if (QW64 and QWord($7FF0000000000000)) = QWord($7FF0000000000000) then begin
        { Inf/NaN 输入：位级映射，不设 ERANGE }
        if (QW64 and QWord($FFFFFFFFFFFFF)) = 0 then begin
          FBits := $7F800000;
          if (QW64 shr 63) <> 0 then FBits := $FF800000;
          Move(FBits, Result, 4);
        end else begin
          FBits := $7FC00000 or LongWord(QW64 and QWord($3FFFFF));
          if (QW64 shr 63) <> 0 then FBits := FBits or $80000000;
          Move(FBits, Result, 4);
        end;
      end else if (QW64 and QWord($7FFFFFFFFFFFFFFF)) > QWord($47EFFFFFF0000000) then begin
        { |X| > FLT_MAX+0.5ulp：溢出 → ±Inf + ERANGE }
        __errno_location()^ := 34;
        FBits := $7F800000;
        if (QW64 shr 63) <> 0 then FBits := $FF800000;
        Move(FBits, Result, 4);
      end else begin
        if (QW64 and QWord($7FFFFFFFFFFFFFFF)) = 0 then
          Result := Single(X) { ±0：不经幂乘，双 double 未定义 }
        else begin
          Result := FloatR2(THo, TLo); { 106 位中间正确舍入 }
          Move(Result, FBits, 4);
          if Neg then FBits := FBits or $80000000; { Pmul 输入恒正，符号后补 }
          Move(FBits, Result, 4);
        end;
        Move(Result, FBits, 4);
        AbsQ := QW64 and QWord($7FFFFFFFFFFFFFFF);
        if (FBits and $7FFFFFFF) = 0 then begin
          if AbsQ <> 0 then
            __errno_location()^ := 34; { 下溢到 ±0（真 0 不设）}
        end else if IsHex then begin
          { hex：结果在 float 次正规域且舍入非精确才设 ERANGE
            （0x1p-149 精确 → 0；0x1.fffffep-127 进位非精确 → 34）}
          if AbsQ < QWord($3810000000000000) then begin
            if AbsQ < QWord($36A0000000000000) then
              __errno_location()^ := 34 { < 2^-149：float 不可表示 }
            else begin
              S := 926 - LongInt((AbsQ shr 52) and $7FF);
              if (AbsQ and ((QWord(1) shl S) - 1)) <> 0 then
                __errno_location()^ := 34; { 尾数落不出次正规网格 }
            end;
          end;
        end else if (FBits and $7F800000) = 0 then
          __errno_location()^ := 34; { decimal：次正规结果无条件 ERANGE }
      end;
    end;
    Exit;
  end;
  { NAN / NAN(n-char-sequence) }
  if (P^ <> #0) and ((UpCase(P^) = 'N') and (P[1] <> #0) and
     (UpCase(P[1]) = 'A') and (P[2] <> #0) and (UpCase(P[2]) = 'N')) then
  begin
    L := 3;
    NLen := 0;
    if P[3] = '(' then begin
      Inc(L); { '(' consumed }
      while P[L] <> #0 do begin
        C := P[L];
        if ((C >= 'a') and (C <= 'z')) or ((C >= 'A') and (C <= 'Z')) or
           ((C >= '0') and (C <= '9')) or (C = '_') then begin
          if NLen < 64 then begin NBuf[NLen] := C; Inc(NLen); end;
          Inc(L)
        end
        else break;
      end;
      if P[L] = ')' then begin
        { glibc(含 GCC __builtin_nan) 的 payload 映射：
          base-0 strtoul 语义（0x → hex、前导 0 → oct、否则 dec），
          必须整体合法否则 payload=0；数值溢出（strtoul 给 ULONG_MAX）→ 52 位全 1 }
        Inc(L);
        Novak := False;
        NVal := 0;
        NBase := 10;
        Idx := 0;
        if NLen = 0 then Novak := True
        else if (NLen >= 2) and (NBuf[0] = '0') and
                ((NBuf[1] = 'x_2') or (NBuf[1] = 'X')) then begin
          NBase := 16;
          Idx := 2;
          if NLen = 2 then Novak := True; { '0x' 后无数字：整体不合法 }
        end
        else if NBuf[0] = '0' then NBase := 8; { 前导 0 → octal }
        if not Novak then begin
          Novf := False;
          while Idx < NLen do begin
            C := NBuf[Idx];
            D := -1;
            if (C >= '0') and (C <= '9') then D := Ord(C) - 48
            else if (C >= 'a') and (C <= 'f') then D := Ord(C) - 87
            else if (C >= 'A') and (C <= 'F') then D := Ord(C) - 55;
            if (D < 0) or (D >= NBase) then begin Novak := True; break; end;
            { 注意 D/NBase 为有符号：须显式转 QWord 强制无符号除法 }
            if NVal > (High(QWord) - QWord(D)) div QWord(NBase) then Novf := True;
            NVal := NVal * NBase + D;
            Inc(Idx);
          end;
        end;
        if Novak then NVal := 0
        else if Novf then NVal := $FFFFFFFFFFFFF
        else NVal := NVal and $FFFFFFFFFFFFF;
        Bits := $7FF8000000000000 or NVal;
      end
      else begin
        L := 3; { 无闭合括号：括号组整体不消费（C99/glibc）}
        Bits := $7FF8000000000000;
      end;
    end
    else begin
      Bits := $7FF8000000000000;
    end;
    Move(Bits, X, 8);
    if Neg then X := -X;
    if endptr <> nil then endptr^ := P + L;
    begin
      Move(X, QW64, 8);
      if (QW64 and QWord($7FF0000000000000)) = QWord($7FF0000000000000) then begin
        { Inf/NaN 输入：位级映射，不设 ERANGE }
        if (QW64 and QWord($FFFFFFFFFFFFF)) = 0 then begin
          FBits := $7F800000;
          if (QW64 shr 63) <> 0 then FBits := $FF800000;
          Move(FBits, Result, 4);
        end else begin
          FBits := $7FC00000 or LongWord(QW64 and QWord($3FFFFF));
          if (QW64 shr 63) <> 0 then FBits := FBits or $80000000;
          Move(FBits, Result, 4);
        end;
      end else if (QW64 and QWord($7FFFFFFFFFFFFFFF)) > QWord($47EFFFFFF0000000) then begin
        { |X| > FLT_MAX+0.5ulp：溢出 → ±Inf + ERANGE }
        __errno_location()^ := 34;
        FBits := $7F800000;
        if (QW64 shr 63) <> 0 then FBits := $FF800000;
        Move(FBits, Result, 4);
      end else begin
        if (QW64 and QWord($7FFFFFFFFFFFFFFF)) = 0 then
          Result := Single(X) { ±0：不经幂乘，双 double 未定义 }
        else begin
          Result := FloatR2(THo, TLo); { 106 位中间正确舍入 }
          Move(Result, FBits, 4);
          if Neg then FBits := FBits or $80000000; { Pmul 输入恒正，符号后补 }
          Move(FBits, Result, 4);
        end;
        Move(Result, FBits, 4);
        AbsQ := QW64 and QWord($7FFFFFFFFFFFFFFF);
        if (FBits and $7FFFFFFF) = 0 then begin
          if AbsQ <> 0 then
            __errno_location()^ := 34; { 下溢到 ±0（真 0 不设）}
        end else if IsHex then begin
          { hex：结果在 float 次正规域且舍入非精确才设 ERANGE
            （0x1p-149 精确 → 0；0x1.fffffep-127 进位非精确 → 34）}
          if AbsQ < QWord($3810000000000000) then begin
            if AbsQ < QWord($36A0000000000000) then
              __errno_location()^ := 34 { < 2^-149：float 不可表示 }
            else begin
              S := 926 - LongInt((AbsQ shr 52) and $7FF);
              if (AbsQ and ((QWord(1) shl S) - 1)) <> 0 then
                __errno_location()^ := 34; { 尾数落不出次正规网格 }
            end;
          end;
        end else if (FBits and $7F800000) = 0 then
          __errno_location()^ := 34; { decimal：次正规结果无条件 ERANGE }
      end;
    end;
    Exit;
  end;
  { hex float: 0x/0X with >=1 hex digit (after optional '.') to confirm }
  IsHex := False;
  if (P^ = '0') and ((P[1] = 'x_2') or (P[1] = 'X')) then begin
    D := -1;
    if (P[2] >= '0') and (P[2] <= '9') then D := Ord(P[2]) - 48
    else if (P[2] >= 'a') and (P[2] <= 'f') then D := Ord(P[2]) - 87
    else if (P[2] >= 'A') and (P[2] <= 'F') then D := Ord(P[2]) - 55;
    if D >= 0 then IsHex := True
    else if P[2] = '.' then begin
      D := -1;
      if (P[3] >= '0') and (P[3] <= '9') then D := Ord(P[3]) - 48
      else if (P[3] >= 'a') and (P[3] <= 'f') then D := Ord(P[3]) - 87
      else if (P[3] >= 'A') and (P[3] <= 'F') then D := Ord(P[3]) - 55;
      if D >= 0 then IsHex := True;
    end;
  end;
  HasDigits := False;
  AnyNonZero := False;
  if IsHex then begin
    Inc(P, 2); { consume 0x prefix }
    M := 0;
    MBits := 0;
    DfHex := 0;
    HexLost := False;
    CutHex := 0;
    ExpBits := 0;
    try
      { integer hex digits }
      while P^ <> #0 do begin
        D := -1;
        if (P^ >= '0') and (P^ <= '9') then D := Ord(P^) - 48
        else if (P^ >= 'a') and (P^ <= 'f') then D := Ord(P^) - 87
        else if (P^ >= 'A') and (P^ <= 'F') then D := Ord(P^) - 55;
        if D < 0 then break;
        HasDigits := True;
        if D <> 0 then AnyNonZero := True;
        if MBits >= 64 then begin
          if D <> 0 then HexLost := True;
          Inc(CutHex); { 被截断的 hex 位：量级修正 4×CutHex }
        end else begin
          M := (M shl 4) or QWord(D);
          Inc(MBits, 4);
        end;
        Inc(P);
      end;
      if P^ = '.' then begin
        Inc(P);
        while P^ <> #0 do begin
          D := -1;
          if (P^ >= '0') and (P^ <= '9') then D := Ord(P^) - 48
          else if (P^ >= 'a') and (P^ <= 'f') then D := Ord(P^) - 87
          else if (P^ >= 'A') and (P^ <= 'F') then D := Ord(P^) - 55;
          if D < 0 then break;
          HasDigits := True;
          if D <> 0 then AnyNonZero := True;
          Inc(DfHex);
          if MBits >= 64 then begin
            if D <> 0 then HexLost := True;
            Inc(CutHex);
          end else begin
            M := (M shl 4) or QWord(D);
            Inc(MBits, 4);
          end;
          Inc(P);
        end;
      end;
      { hex exponent p[+-]digits }
      if ((P^ = 'p') or (P^ = 'P')) and (P[1] <> #0) and
         (((P[1] >= '0') and (P[1] <= '9')) or
          ((P[1] = '+') and (P[2] <> #0) and (P[2] >= '0') and (P[2] <= '9')) or
          ((P[1] = '-') and (P[2] <> #0) and (P[2] >= '0') and (P[2] <= '9'))) then
      begin
        Inc(P);
        ExpNeg := False;
        if P^ = '+' then Inc(P)
        else if P^ = '-' then begin ExpNeg := True; Inc(P); end;
        ExpBits := 0;
        while (P^ >= '0') and (P^ <= '9') do begin
          if ExpBits < 1000000 then ExpBits := ExpBits * 10 + (Ord(P^) - 48);
          Inc(P);
        end;
        if ExpNeg then ExpBits := -ExpBits;
        if ExpBits > 4096 then ExpBits := 4096
        else if ExpBits < -4096 then ExpBits := -4096;
      end;
    except
      { 防御兜底（不应触发）}
      X := 0.0;
      Bits := $7FF0000000000000;
      Move(Bits, X, 8); { +Inf }
      ClearFPUFlags;
      if Neg then X := -X;
      if endptr <> nil then endptr^ := P;
      __errno_location()^ := 34;
      begin
      Move(X, QW64, 8);
      if (QW64 and QWord($7FF0000000000000)) = QWord($7FF0000000000000) then begin
        { Inf/NaN 输入：位级映射，不设 ERANGE }
        if (QW64 and QWord($FFFFFFFFFFFFF)) = 0 then begin
          FBits := $7F800000;
          if (QW64 shr 63) <> 0 then FBits := $FF800000;
          Move(FBits, Result, 4);
        end else begin
          FBits := $7FC00000 or LongWord(QW64 and QWord($3FFFFF));
          if (QW64 shr 63) <> 0 then FBits := FBits or $80000000;
          Move(FBits, Result, 4);
        end;
      end else if (QW64 and QWord($7FFFFFFFFFFFFFFF)) > QWord($47EFFFFFF0000000) then begin
        { |X| > FLT_MAX+0.5ulp：溢出 → ±Inf + ERANGE }
        __errno_location()^ := 34;
        FBits := $7F800000;
        if (QW64 shr 63) <> 0 then FBits := $FF800000;
        Move(FBits, Result, 4);
      end else begin
        if (QW64 and QWord($7FFFFFFFFFFFFFFF)) = 0 then
          Result := Single(X) { ±0：不经幂乘，双 double 未定义 }
        else begin
          Result := FloatR2(THo, TLo); { 106 位中间正确舍入 }
          Move(Result, FBits, 4);
          if Neg then FBits := FBits or $80000000; { Pmul 输入恒正，符号后补 }
          Move(FBits, Result, 4);
        end;
        Move(Result, FBits, 4);
        AbsQ := QW64 and QWord($7FFFFFFFFFFFFFFF);
        if (FBits and $7FFFFFFF) = 0 then begin
          if AbsQ <> 0 then
            __errno_location()^ := 34; { 下溢到 ±0（真 0 不设）}
        end else if IsHex then begin
          { hex：结果在 float 次正规域且舍入非精确才设 ERANGE
            （0x1p-149 精确 → 0；0x1.fffffep-127 进位非精确 → 34）}
          if AbsQ < QWord($3810000000000000) then begin
            if AbsQ < QWord($36A0000000000000) then
              __errno_location()^ := 34 { < 2^-149：float 不可表示 }
            else begin
              S := 926 - LongInt((AbsQ shr 52) and $7FF);
              if (AbsQ and ((QWord(1) shl S) - 1)) <> 0 then
                __errno_location()^ := 34; { 尾数落不出次正规网格 }
            end;
          end;
        end else if (FBits and $7F800000) = 0 then
          __errno_location()^ := 34; { decimal：次正规结果无条件 ERANGE }
      end;
    end;
      Exit;
    end;
    if endptr <> nil then endptr^ := P;
    if not AnyNonZero then begin
      { 全零 hex：不设 errno（glibc）}
      X := 0.0;
      if Neg then X := -X;
      begin
      Move(X, QW64, 8);
      if (QW64 and QWord($7FF0000000000000)) = QWord($7FF0000000000000) then begin
        { Inf/NaN 输入：位级映射，不设 ERANGE }
        if (QW64 and QWord($FFFFFFFFFFFFF)) = 0 then begin
          FBits := $7F800000;
          if (QW64 shr 63) <> 0 then FBits := $FF800000;
          Move(FBits, Result, 4);
        end else begin
          FBits := $7FC00000 or LongWord(QW64 and QWord($3FFFFF));
          if (QW64 shr 63) <> 0 then FBits := FBits or $80000000;
          Move(FBits, Result, 4);
        end;
      end else if (QW64 and QWord($7FFFFFFFFFFFFFFF)) > QWord($47EFFFFFF0000000) then begin
        { |X| > FLT_MAX+0.5ulp：溢出 → ±Inf + ERANGE }
        __errno_location()^ := 34;
        FBits := $7F800000;
        if (QW64 shr 63) <> 0 then FBits := $FF800000;
        Move(FBits, Result, 4);
      end else begin
        if (QW64 and QWord($7FFFFFFFFFFFFFFF)) = 0 then
          Result := Single(X) { ±0：不经幂乘，双 double 未定义 }
        else begin
          Result := FloatR2(THo, TLo); { 106 位中间正确舍入 }
          Move(Result, FBits, 4);
          if Neg then FBits := FBits or $80000000; { Pmul 输入恒正，符号后补 }
          Move(FBits, Result, 4);
        end;
        Move(Result, FBits, 4);
        AbsQ := QW64 and QWord($7FFFFFFFFFFFFFFF);
        if (FBits and $7FFFFFFF) = 0 then begin
          if AbsQ <> 0 then
            __errno_location()^ := 34; { 下溢到 ±0（真 0 不设）}
        end else if IsHex then begin
          { hex：结果在 float 次正规域且舍入非精确才设 ERANGE
            （0x1p-149 精确 → 0；0x1.fffffep-127 进位非精确 → 34）}
          if AbsQ < QWord($3810000000000000) then begin
            if AbsQ < QWord($36A0000000000000) then
              __errno_location()^ := 34 { < 2^-149：float 不可表示 }
            else begin
              S := 926 - LongInt((AbsQ shr 52) and $7FF);
              if (AbsQ and ((QWord(1) shl S) - 1)) <> 0 then
                __errno_location()^ := 34; { 尾数落不出次正规网格 }
            end;
          end;
        end else if (FBits and $7F800000) = 0 then
          __errno_location()^ := 34; { decimal：次正规结果无条件 ERANGE }
      end;
    end;
      Exit;
    end;
    { value = M x_2 2^T, T = ExpBits - 4*DfHex + 4*CutHex.
      strtof version: round directly in the float domain (24-bit
      round-half-even); the double intermediate double-rounds
      boundary cases by 1ulp }
    T := ExpBits - 4 * DfHex + 4 * CutHex;
    QW := M;
    L := 0;
    while QW > 1 do begin QW := QW shr 1; Inc(L); end;
    EvalI := T + L;
    if EvalI > 127 then begin
      { float exponent overflow -> +-Inf + ERANGE }
      __errno_location()^ := 34;
      FBits := $7F800000;
      if Neg then FBits := $FF800000;
      Move(FBits, Result, 4);
    end else if EvalI >= -126 then begin
      { float normal: 24-bit round-half-even }
      if L <= 23 then
        mant := M shl (23 - L)
      else begin
        BL := L - 23;
        remLW := M and ((QWord(1) shl BL) - 1);
        mant := M shr BL;
        half := QWord(1) shl (BL - 1);
        if (remLW > half) or ((remLW = half) and ((mant and 1) = 1)) then
          Inc(mant);
        if mant = (QWord(1) shl 24) then begin
          { mantissa carry into 2^128: float overflow (FLT_MAX+0.5ulp tie) }
          mant := QWord(1) shl 23;
          Inc(EvalI);
          if EvalI > 127 then begin
            __errno_location()^ := 34;
            FBits := $7F800000;
            if Neg then FBits := $FF800000;
            Move(FBits, Result, 4);
            Exit;
          end;
        end;
      end;
      { mant in [2^23, 2^24): exponent field EvalI+127 }
      FBits := LongWord((EvalI + 127) shl 23) or LongWord(mant and $7FFFFF);
      if Neg then FBits := FBits or $80000000;
      Move(FBits, Result, 4);
    end else begin
      { float subnormal: grid 2^-149, grid count = M x_2 2^Rg, Rg = T + 149
        (ERANGE only when rounding inexact; 0x1p-149 exact -> 0) }
      Rg := T + 149;
      HexExact := True;
      if Rg >= 0 then begin
        { subnormal domain: Rg < 23-L -> grid < 2^24: no QWord overflow }
        mant := M shl Rg;
      end else begin
        BL := LongInt(-Rg);
        if BL >= 64 then begin
          { grid count < 0.5: rounds to 0 }
          mant := 0;
          HexExact := False;
        end else begin
          remLW := M and ((QWord(1) shl BL) - 1);
          mant := M shr BL;
          half := QWord(1) shl (BL - 1);
          if (remLW > half) or ((remLW = half) and ((mant and 1) = 1)) then
            Inc(mant);
          if remLW <> 0 then HexExact := False;
        end;
      end;
      if HexLost then HexExact := False; { 64-bit truncation also inexact }
      if mant >= (QWord(1) shl 23) then
        FBits := $00800000 { carry into 2^-126 (min normal) }
      else
        FBits := LongWord(mant);
      if Neg then FBits := FBits or $80000000;
      Move(FBits, Result, 4);
      IsHex := True;
    if not HexExact then __errno_location()^ := 34;
    end;
    Exit;
  end;
  { decimal: 扫描有效数字结构，同时预判量级 k（首位有效数字的 10 次幂）}
  I := 0;
  SigCount := 0;
  Di := 0;
  Df := 0;
  HasDecPoint := False;
  FirstSig := False;
  FirstInt := False;
  KIntBase := 0;
  k := 0;
  Mhi := 0;
  Mlo := 0;
  R := False;
  S60Len := 0;
  Beyond60 := False;
  while P^ <> #0 do begin
    if (P^ >= '0') and (P^ <= '9') then begin
      if I < 480 then begin Buf[I] := P^; Inc(I); end;
      if P^ <> '0' then AnyNonZero := True;
      HasDigits := True;
      if HasDecPoint then Inc(Df) else Inc(Di);
      if not FirstSig then begin
        if P^ <> '0' then begin
          FirstSig := True;
          if HasDecPoint then k := -Df
          else begin
            FirstInt := True;
            KIntBase := Di; { 首位有效时的整数位数，扫描后再定 k }
          end;
        end;
      end;
      if FirstSig then begin
        Inc(SigCount);
        if SigCount <= 60 then begin
          S60[SigCount - 1] := P^;
          if SigCount <= 15 then Mhi := Mhi * 10 + (Ord(P^) - 48)
          else if SigCount <= 20 then Mlo := Mlo * 10 + (Ord(P^) - 48);
        end else if P^ <> '0' then Beyond60 := True;
      end;
      Inc(P);
    end else if (P^ = '.') and (not HasDecPoint) then begin
      if I < 480 then begin Buf[I] := '.'; Inc(I); end;
      HasDecPoint := True;
      Inc(P);
    end else break;
  end;
  if FirstInt then k := Di - KIntBase;
  { exponent: consume only if followed by a valid exponent }
  ExpNegDec := False;
  Ei := 0;
  ExpSign := 1;
  HasExp := False;
  if ((P^ = 'e') or (P^ = 'E')) and (P[1] <> #0) and
     (((P[1] >= '0') and (P[1] <= '9')) or
      ((P[1] = '+') and (P[2] <> #0) and (P[2] >= '0') and (P[2] <= '9')) or
      ((P[1] = '-') and (P[2] <> #0) and (P[2] >= '0') and (P[2] <= '9'))) then
  begin
    HasExp := True;
    if I < 480 then begin Buf[I] := 'e'; Inc(I); end;
    Inc(P);
    if P^ = '+' then begin if I < 480 then begin Buf[I] := '+'; Inc(I); end; Inc(P); end
    else if P^ = '-' then begin
      ExpNegDec := True;
      ExpSign := -1;
      if I < 480 then begin Buf[I] := '-'; Inc(I); end;
      Inc(P);
    end;
    while P^ <> #0 do begin
      if (P^ >= '0') and (P^ <= '9') then begin
        if I < 480 then begin Buf[I] := P^; Inc(I); end;
        if Ei < 100000000000000 then
          Ei := Ei * 10 + (Ord(P^) - 48); { 饱和防 Int64 溢出 }
        Inc(P);
      end else break;
    end;
  end;
  if not HasDigits then begin
    { no conversion: endptr = original nptr (C99) }
    if endptr <> nil then endptr^ := nptr;
    Result := 0.0;
    Exit;
  end;
  KTotal := k + ExpSign * Ei;
  { 溢出/下溢预判仅适用于非全零输入（全零不设 ERANGE、永不溢出/下溢）}
  if FirstSig then begin
    Overflow := KTotal > 308;
    if KTotal = 308 then begin
    if SigCount > 60 then S60Len := 60 else S60Len := SigCount;
    Cmp := CmpT60(S60, S60Len);
    Overflow := Cmp > 0;
  end;
    Underflow := KTotal < -324;
  end else begin
    Overflow := False;
    Underflow := False;
  end;
  Buf[I] := #0;
  if Overflow then begin
    X := 0.0;
    Bits := $7FF0000000000000;
    Move(Bits, X, 8); { +Inf }
    if Neg then X := -X;
    if endptr <> nil then endptr^ := P;
    __errno_location()^ := 34;
    begin
      Move(X, QW64, 8);
      if (QW64 and QWord($7FF0000000000000)) = QWord($7FF0000000000000) then begin
        { Inf/NaN 输入：位级映射，不设 ERANGE }
        if (QW64 and QWord($FFFFFFFFFFFFF)) = 0 then begin
          FBits := $7F800000;
          if (QW64 shr 63) <> 0 then FBits := $FF800000;
          Move(FBits, Result, 4);
        end else begin
          FBits := $7FC00000 or LongWord(QW64 and QWord($3FFFFF));
          if (QW64 shr 63) <> 0 then FBits := FBits or $80000000;
          Move(FBits, Result, 4);
        end;
      end else if (QW64 and QWord($7FFFFFFFFFFFFFFF)) > QWord($47EFFFFFF0000000) then begin
        { |X| > FLT_MAX+0.5ulp：溢出 → ±Inf + ERANGE }
        __errno_location()^ := 34;
        FBits := $7F800000;
        if (QW64 shr 63) <> 0 then FBits := $FF800000;
        Move(FBits, Result, 4);
      end else begin
        if (QW64 and QWord($7FFFFFFFFFFFFFFF)) = 0 then
          Result := Single(X) { ±0：不经幂乘，双 double 未定义 }
        else begin
          Result := FloatR2(THo, TLo); { 106 位中间正确舍入 }
          Move(Result, FBits, 4);
          if Neg then FBits := FBits or $80000000; { Pmul 输入恒正，符号后补 }
          Move(FBits, Result, 4);
        end;
        Move(Result, FBits, 4);
        AbsQ := QW64 and QWord($7FFFFFFFFFFFFFFF);
        if (FBits and $7FFFFFFF) = 0 then begin
          if AbsQ <> 0 then
            __errno_location()^ := 34; { 下溢到 ±0（真 0 不设）}
        end else if IsHex then begin
          { hex：结果在 float 次正规域且舍入非精确才设 ERANGE
            （0x1p-149 精确 → 0；0x1.fffffep-127 进位非精确 → 34）}
          if AbsQ < QWord($3810000000000000) then begin
            if AbsQ < QWord($36A0000000000000) then
              __errno_location()^ := 34 { < 2^-149：float 不可表示 }
            else begin
              S := 926 - LongInt((AbsQ shr 52) and $7FF);
              if (AbsQ and ((QWord(1) shl S) - 1)) <> 0 then
                __errno_location()^ := 34; { 尾数落不出次正规网格 }
            end;
          end;
        end else if (FBits and $7F800000) = 0 then
          __errno_location()^ := 34; { decimal：次正规结果无条件 ERANGE }
      end;
    end;
    Exit;
  end;
  if Underflow then begin
    X := 0.0;
    if Neg then X := -X; { -0.0 保留符号（C99）}
    if endptr <> nil then endptr^ := P;
    __errno_location()^ := 34;
    begin
      Move(X, QW64, 8);
      if (QW64 and QWord($7FF0000000000000)) = QWord($7FF0000000000000) then begin
        { Inf/NaN 输入：位级映射，不设 ERANGE }
        if (QW64 and QWord($FFFFFFFFFFFFF)) = 0 then begin
          FBits := $7F800000;
          if (QW64 shr 63) <> 0 then FBits := $FF800000;
          Move(FBits, Result, 4);
        end else begin
          FBits := $7FC00000 or LongWord(QW64 and QWord($3FFFFF));
          if (QW64 shr 63) <> 0 then FBits := FBits or $80000000;
          Move(FBits, Result, 4);
        end;
      end else if (QW64 and QWord($7FFFFFFFFFFFFFFF)) > QWord($47EFFFFFF0000000) then begin
        { |X| > FLT_MAX+0.5ulp：溢出 → ±Inf + ERANGE }
        __errno_location()^ := 34;
        FBits := $7F800000;
        if (QW64 shr 63) <> 0 then FBits := $FF800000;
        Move(FBits, Result, 4);
      end else begin
        if (QW64 and QWord($7FFFFFFFFFFFFFFF)) = 0 then
          Result := Single(X) { ±0：不经幂乘，双 double 未定义 }
        else begin
          Result := FloatR2(THo, TLo); { 106 位中间正确舍入 }
          Move(Result, FBits, 4);
          if Neg then FBits := FBits or $80000000; { Pmul 输入恒正，符号后补 }
          Move(FBits, Result, 4);
        end;
        Move(Result, FBits, 4);
        AbsQ := QW64 and QWord($7FFFFFFFFFFFFFFF);
        if (FBits and $7FFFFFFF) = 0 then begin
          if AbsQ <> 0 then
            __errno_location()^ := 34; { 下溢到 ±0（真 0 不设）}
        end else if IsHex then begin
          { hex：结果在 float 次正规域且舍入非精确才设 ERANGE
            （0x1p-149 精确 → 0；0x1.fffffep-127 进位非精确 → 34）}
          if AbsQ < QWord($3810000000000000) then begin
            if AbsQ < QWord($36A0000000000000) then
              __errno_location()^ := 34 { < 2^-149：float 不可表示 }
            else begin
              S := 926 - LongInt((AbsQ shr 52) and $7FF);
              if (AbsQ and ((QWord(1) shl S) - 1)) <> 0 then
                __errno_location()^ := 34; { 尾数落不出次正规网格 }
            end;
          end;
        end else if (FBits and $7F800000) = 0 then
          __errno_location()^ := 34; { decimal：次正规结果无条件 ERANGE }
      end;
    end;
    Exit;
  end;
  if not FirstSig then begin
    { 全零：±0，不设 errno（0e999 等）}
    X := 0.0;
    if Neg then X := -X;
    if endptr <> nil then endptr^ := P;
    begin
      Move(X, QW64, 8);
      if (QW64 and QWord($7FF0000000000000)) = QWord($7FF0000000000000) then begin
        { Inf/NaN 输入：位级映射，不设 ERANGE }
        if (QW64 and QWord($FFFFFFFFFFFFF)) = 0 then begin
          FBits := $7F800000;
          if (QW64 shr 63) <> 0 then FBits := $FF800000;
          Move(FBits, Result, 4);
        end else begin
          FBits := $7FC00000 or LongWord(QW64 and QWord($3FFFFF));
          if (QW64 shr 63) <> 0 then FBits := FBits or $80000000;
          Move(FBits, Result, 4);
        end;
      end else if (QW64 and QWord($7FFFFFFFFFFFFFFF)) > QWord($47EFFFFFF0000000) then begin
        { |X| > FLT_MAX+0.5ulp：溢出 → ±Inf + ERANGE }
        __errno_location()^ := 34;
        FBits := $7F800000;
        if (QW64 shr 63) <> 0 then FBits := $FF800000;
        Move(FBits, Result, 4);
      end else begin
        if (QW64 and QWord($7FFFFFFFFFFFFFFF)) = 0 then
          Result := Single(X) { ±0：不经幂乘，双 double 未定义 }
        else begin
          Result := FloatR2(THo, TLo); { 106 位中间正确舍入 }
          Move(Result, FBits, 4);
          if Neg then FBits := FBits or $80000000; { Pmul 输入恒正，符号后补 }
          Move(FBits, Result, 4);
        end;
        Move(Result, FBits, 4);
        AbsQ := QW64 and QWord($7FFFFFFFFFFFFFFF);
        if (FBits and $7FFFFFFF) = 0 then begin
          if AbsQ <> 0 then
            __errno_location()^ := 34; { 下溢到 ±0（真 0 不设）}
        end else if IsHex then begin
          { hex：结果在 float 次正规域且舍入非精确才设 ERANGE
            （0x1p-149 精确 → 0；0x1.fffffep-127 进位非精确 → 34）}
          if AbsQ < QWord($3810000000000000) then begin
            if AbsQ < QWord($36A0000000000000) then
              __errno_location()^ := 34 { < 2^-149：float 不可表示 }
            else begin
              S := 926 - LongInt((AbsQ shr 52) and $7FF);
              if (AbsQ and ((QWord(1) shl S) - 1)) <> 0 then
                __errno_location()^ := 34; { 尾数落不出次正规网格 }
            end;
          end;
        end else if (FBits and $7F800000) = 0 then
          __errno_location()^ := 34; { decimal：次正规结果无条件 ERANGE }
      end;
    end;
    Exit;
  end;
  { 尾部补零：Mhi 15 位 / Mlo 5 位（M20 = MHw×1e5+MLw；SC>20 的
    截断误差 ≤ 10^-20 相对 << 0.5ulp，不影响舍入正确性）}
  if SigCount > 15 then begin SCh := 15; SCl := SigCount - 15; end
  else begin SCh := SigCount; SCl := 0; end;
  MHw := Mhi;
  MLw := Mlo;
  for I := SCh to 14 do MHw := MHw * 10;
  for I := SCl to 4 do MLw := MLw * 10;
  KIntL := KTotal - 19; { 表下标（值 = M20×10^KIntL）}
  { 合成双 double 尾数对：Wh+Wl = MHw×1e5 精确，WlB ≈ Wl + MLw = M20。
    单次幂乘吃全 20 位；两段独立幂乘相加会先丢 Mlo 低位再合并（1ulp 级）}
  TwoProd(Double(MHw), 100000.0, Wh, Wl);
  WlB := Wl + Double(MLw);
  if KIntL <= -308 then begin
    { BN 定点：网格数 = M20×B(KIntL)（B=10^K×2^1074 双 double，正规域），
      结果 = QN×2^-1074。覆盖次正规与 DBL_MIN 邻近（含舍入进位）}
    try
      XN := PmulB(Wh, WlB, KIntL);
    except
      ClearFPUFlags;
      XN := 0.0;
    end;
    { 直接 ×2^-1074 得结果：正规/次正规都由浮点精确舍入到网格。
      XN 误差 2^-104 相对 → 绝对 ~2^-1178 << 0.5 网格，舍入正确。
      不做网格整数拼接——QN 可达 2^114，Int64 的 Trunc 会硬件异常 }
    Bits := 1; { 2^-1074（最小次正规）}
    Move(Bits, F2, 8);
    X := XN * F2;
    THo := X;
    TLo := 0.0;
    Q64 := 0;
    Move(X, Q64, 8);
    if (Q64 and $7FF0000000000000) = 0 then
      __errno_location()^ := 34; { 十进制次正规无条件 ERANGE }
    if Neg then X := -X;
    if endptr <> nil then endptr^ := P;
    begin
      Move(X, QW64, 8);
      if (QW64 and QWord($7FF0000000000000)) = QWord($7FF0000000000000) then begin
        { Inf/NaN 输入：位级映射，不设 ERANGE }
        if (QW64 and QWord($FFFFFFFFFFFFF)) = 0 then begin
          FBits := $7F800000;
          if (QW64 shr 63) <> 0 then FBits := $FF800000;
          Move(FBits, Result, 4);
        end else begin
          FBits := $7FC00000 or LongWord(QW64 and QWord($3FFFFF));
          if (QW64 shr 63) <> 0 then FBits := FBits or $80000000;
          Move(FBits, Result, 4);
        end;
      end else if (QW64 and QWord($7FFFFFFFFFFFFFFF)) > QWord($47EFFFFFF0000000) then begin
        { |X| > FLT_MAX+0.5ulp：溢出 → ±Inf + ERANGE }
        __errno_location()^ := 34;
        FBits := $7F800000;
        if (QW64 shr 63) <> 0 then FBits := $FF800000;
        Move(FBits, Result, 4);
      end else begin
        if (QW64 and QWord($7FFFFFFFFFFFFFFF)) = 0 then
          Result := Single(X) { ±0：不经幂乘，双 double 未定义 }
        else begin
          Result := FloatR2(THo, TLo); { 106 位中间正确舍入 }
          Move(Result, FBits, 4);
          if Neg then FBits := FBits or $80000000; { Pmul 输入恒正，符号后补 }
          Move(FBits, Result, 4);
        end;
        Move(Result, FBits, 4);
        AbsQ := QW64 and QWord($7FFFFFFFFFFFFFFF);
        if (FBits and $7FFFFFFF) = 0 then begin
          if AbsQ <> 0 then
            __errno_location()^ := 34; { 下溢到 ±0（真 0 不设）}
        end else if IsHex then begin
          { hex：结果在 float 次正规域且舍入非精确才设 ERANGE
            （0x1p-149 精确 → 0；0x1.fffffep-127 进位非精确 → 34）}
          if AbsQ < QWord($3810000000000000) then begin
            if AbsQ < QWord($36A0000000000000) then
              __errno_location()^ := 34 { < 2^-149：float 不可表示 }
            else begin
              S := 926 - LongInt((AbsQ shr 52) and $7FF);
              if (AbsQ and ((QWord(1) shl S) - 1)) <> 0 then
                __errno_location()^ := 34; { 尾数落不出次正规网格 }
            end;
          end;
        end else if (FBits and $7F800000) = 0 then
          __errno_location()^ := 34; { decimal：次正规结果无条件 ERANGE }
      end;
    end;
    Exit;
  end;
  { 主幂乘：值 = M20×10^KIntL（KIntL ∈ [-307, 289]，10^KIntL 正规 double）。
    双 double 单次幂乘 ~2^-106 相对误差，替代 FPC Val（其上溢/下溢/
    1ulp/MXCSR 均不可靠）}
  try
    X := Pmul(Wh, WlB, KIntL);
  except
    { 数学值 ∈ (DBL_MAX, DBL_MAX+0.5ulp]：C99 舍入到 DBL_MAX（不溢）}
    ClearFPUFlags;
    Q64 := $7FEFFFFFFFFFFFFF;
    Move(Q64, X, 8);
  end;
  if Neg then X := -X;
  if endptr <> nil then endptr^ := P;
  Q64 := 0;
  Move(X, Q64, 8);
  { 位模式后判定（幂乘正确性兜底；十进制仅次正规无条件 ERANGE）}
  if (Q64 = QWord($7FF0000000000000)) or (Q64 = QWord($FFF0000000000000)) then
    __errno_location()^ := 34
  else if (Q64 = 0) or (Q64 = QWord($8000000000000000)) then
    __errno_location()^ := 34
  else if (Q64 and $7FFFFFFFFFFFFFFF <> 0) and
          ((Q64 and $7FF0000000000000) = 0) then
    __errno_location()^ := 34;
  begin
      Move(X, QW64, 8);
      if (QW64 and QWord($7FF0000000000000)) = QWord($7FF0000000000000) then begin
        { Inf/NaN 输入：位级映射，不设 ERANGE }
        if (QW64 and QWord($FFFFFFFFFFFFF)) = 0 then begin
          FBits := $7F800000;
          if (QW64 shr 63) <> 0 then FBits := $FF800000;
          Move(FBits, Result, 4);
        end else begin
          FBits := $7FC00000 or LongWord(QW64 and QWord($3FFFFF));
          if (QW64 shr 63) <> 0 then FBits := FBits or $80000000;
          Move(FBits, Result, 4);
        end;
      end else if (QW64 and QWord($7FFFFFFFFFFFFFFF)) > QWord($47EFFFFFF0000000) then begin
        { |X| > FLT_MAX+0.5ulp：溢出 → ±Inf + ERANGE }
        __errno_location()^ := 34;
        FBits := $7F800000;
        if (QW64 shr 63) <> 0 then FBits := $FF800000;
        Move(FBits, Result, 4);
      end else begin
        if (QW64 and QWord($7FFFFFFFFFFFFFFF)) = 0 then
          Result := Single(X) { ±0：不经幂乘，双 double 未定义 }
        else begin
          Result := FloatR2(THo, TLo); { 106 位中间正确舍入 }
          Move(Result, FBits, 4);
          if Neg then FBits := FBits or $80000000; { Pmul 输入恒正，符号后补 }
          Move(FBits, Result, 4);
        end;
        Move(Result, FBits, 4);
        AbsQ := QW64 and QWord($7FFFFFFFFFFFFFFF);
        if (FBits and $7FFFFFFF) = 0 then begin
          if AbsQ <> 0 then
            __errno_location()^ := 34; { 下溢到 ±0（真 0 不设）}
        end else if IsHex then begin
          { hex：结果在 float 次正规域且舍入非精确才设 ERANGE
            （0x1p-149 精确 → 0；0x1.fffffep-127 进位非精确 → 34）}
          if AbsQ < QWord($3810000000000000) then begin
            if AbsQ < QWord($36A0000000000000) then
              __errno_location()^ := 34 { < 2^-149：float 不可表示 }
            else begin
              S := 926 - LongInt((AbsQ shr 52) and $7FF);
              if (AbsQ and ((QWord(1) shl S) - 1)) <> 0 then
                __errno_location()^ := 34; { 尾数落不出次正规网格 }
            end;
          end;
        end else if (FBits and $7F800000) = 0 then
          __errno_location()^ := 34; { decimal：次正规结果无条件 ERANGE }
      end;
    end;
end;


function atof(nptr: PAnsiChar): Double; cdecl;
{$IFDEF CPUX86_64}
procedure ClearFPUFlags;
{ 清除 MXCSR 的 6 个异常标志位而不改屏蔽掩码：
  FPC 的 try/except 不恢复 FPU 状态，异常后滞留的标志会让后续浮点运算误抛 }
begin
  asm
    subq $8, %rsp
    stmxcsr (%rsp)
    movl (%rsp), %eax
    andl $0xFFFFFFC0, %eax
    movl %eax, (%rsp)
    ldmxcsr (%rsp)
    addq $8, %rsp
  end;
end;
{$ELSE}
{$IFDEF CPUX86}
procedure ClearFPUFlags;
begin
  { i386：同 x86_64，但用 %esp 且不依赖红区（i386 无红区保证） }
  asm
    subl $8, %esp
    stmxcsr (%esp)
    movl (%esp), %eax
    andl $0xFFFFFFC0, %eax
    movl %eax, (%esp)
    ldmxcsr (%esp)
    addl $8, %esp
  end;
end;
{$ELSE}
procedure ClearFPUFlags;
begin
  { 非 x86 目标无 MXCSR：FPC 默认不陷浮点异常，无滞留标志需清 }
end;
{$ENDIF}
{$ENDIF}

{ 与溢出阈值 T=2^1024-2^970（= DBL_MAX + 0.5ulp，309 位十进制整数）
  的前 60 位比较：S 某位大于 T 同位列 → 1（溢）；小于或 S 是 T 的
  真前缀（T 尾部位非零）→ -1。前 60 位全等且更长（概率 <1e-60，
  判定差 < 0.5ulp×1e-40）按不溢处理 }
function CmpT60(const S: array of AnsiChar; SLen: LongInt): LongInt;
const T60 = '179769313486231580793728971405303415079934132710037826936173';
var J: LongInt;
begin
  for J := 1 to SLen do begin
    if S[J - 1] < T60[J] then begin Result := -1; Exit; end;
    if S[J - 1] > T60[J] then begin Result := 1; Exit; end;
  end;
  Result := -1;
end;

{ Dekker 双精度乘积：hi+lo = a*b 精确（无 FMA 版），用于 k=308 大值幂乘 }
procedure TwoProd(const a, b: Double; out hi, lo: Double);
var ah, al, bh, bl, c: Double;
begin
  c := 134217729.0 * a; { (2^27+1) }
  ah := c - (c - a);
  al := a - ah;
  c := 134217729.0 * b;
  bh := c - (c - b);
  bl := b - bh;
  hi := a * b;
  lo := ((ah * bh - hi) + ah * bl + al * bh) + al * bl;
end;


var
  DummyEnd: PPAnsiChar;
  P: PAnsiChar;
  Neg: Boolean;
  Buf: array[0..511] of AnsiChar;
  I: LongInt;
  D: LongInt;
  HasDigits: Boolean;
  AnyNonZero: Boolean;
  IsHex: Boolean;
  ValErr: Integer;
  X: Double;
  L: LongInt;
  Bits: QWord;
  Scale: Double;
  ExpNeg: Boolean;
  ExpBits: Int64;
  ExpNegDec: Boolean;
  C: AnsiChar;
  Di: LongInt;
  Df: LongInt;
  SigCount: LongInt;
  ExpSign: LongInt;
  HasDecPoint: Boolean;
  FirstSig: Boolean;
  FirstInt: Boolean;
  KIntBase: LongInt;
  R: Boolean;
  HasExp: Boolean;
  Mhi: Int64;  { 尾数高 15 位（Double 精确）}
  Mlo: Int64;  { 尾数低 5 位（第 16-20 位）}
  MHw: Int64;
  MLw: Int64;
  SCh: LongInt;
  SCl: LongInt;
  k: Int64;
  KTotal: Int64;
  Ei: Int64;
  Overflow: Boolean;
  Underflow: Boolean;
  S60: array[0..59] of AnsiChar;
  S60Len: LongInt;
  Beyond60: Boolean;
  Q64: QWord;
  { hex 分支整数尾数（≤64 bit）与拼装 }
  M: QWord;
  MBits: LongInt;
  DfHex: LongInt;
  HexLost: Boolean;
  CutHex: LongInt;
  { decimal 高精度幂乘 }
  KIntL: LongInt;
  QN: QWord;
  HexExact: Boolean;
  QW: QWord;
  EvalI: Int64;
  Rg: Int64;
  BL: LongInt;
  mant: QWord;
  remLW: QWord;
  half: QWord;
  g: QWord;
  { NAN(n-char) payload：base-0 strtoul 语义 }
  NBuf: array[0..63] of AnsiChar;
  NLen: LongInt;
  NVal: QWord;
  NBase: LongInt;
  Novf: Boolean;
  Novak: Boolean;
  T: Int64;
  Idx: LongInt;
  Cmp: LongInt;
  THd: Double;
  TLd: Double;
  E308: LongInt;
  E308L: LongInt;
  H1: Double;
  L1: Double;
  H2: Double;
  L2: Double;
  H1b: Double;
  L1b: Double;
  H2b: Double;
  L2b: Double;
  Wh: Double;
  Wl: Double;
  WlB: Double;
  F2: Double; { BN 缩放临时（2^-1074）}
  XN: Double;

  { 双 double 幂乘：W（Wh+Wl 精确对）× 10^K。
    TH+TL = 10^K（106 位双 double 表；TL 可负/次正规/0，不作
    指数拆解——次正规低段无 [1,2)×2^E 规范形，拆解会放大误差）。
    主段 TwoProd(TH,Wh) 精确，TH×Wl 与 TL×W 并入低段，每步只摊
    ~2^-106 相对误差，最终一次舍入即正确 }
  function Pmul(Wh, Wl: Double; K: LongInt): Double;
  var fH, fL, H1, L1, B1, B2: Double;
  begin
    Move(TENH[K], fH, 8);
    Move(TENL[K], fL, 8);
    TwoProd(fH, Wh, H1, L1);
    L1 := L1 + fH * Wl;
    B1 := fL * Wh;
    B2 := fL * Wl;
    L1 := L1 + B1;
    L1 := L1 + B2;
    Result := H1 + L1;
  end;

  { BN 网格倍数定点版（表 B = 10^K×2^1074，全正规域），同 Pmul 结构 }
  function PmulB(Wh, Wl: Double; K: LongInt): Double;
  var fH, fL, H1, L1, B1, B2: Double;
  begin
    Move(BNH[K], fH, 8);
    Move(BNL[K], fL, 8);
    TwoProd(fH, Wh, H1, L1);
    L1 := L1 + fH * Wl;
    B1 := fL * Wh;
    B2 := fL * Wl;
    L1 := L1 + B1;
    L1 := L1 + B2;
    Result := H1 + L1;
  end;

begin
  DummyEnd := nil;
  Result := 0.0;
  if nptr = nil then begin
    if DummyEnd <> nil then DummyEnd^ := nptr;
    Exit;
  end;
  P := nptr;
  while (P^ <> #0) and ((P^ = ' ') or (P^ = #9) or (P^ = #10) or
        (P^ = #11) or (P^ = #12) or (P^ = #13)) do Inc(P);
  Neg := False;
  if P^ = '+' then Inc(P)
  else if P^ = '-' then begin Neg := True; Inc(P); end;
  { INF / INFINITY (case-insensitive, must start at P) }
  if (P^ <> #0) and ((UpCase(P^) = 'I') and (P[1] <> #0) and
     (UpCase(P[1]) = 'N') and (P[2] <> #0) and (UpCase(P[2]) = 'F')) then
  begin
    L := 3;
    if (P[3] <> #0) and (UpCase(P[3]) = 'I') and (P[4] <> #0) and
       (UpCase(P[4]) = 'N') and (P[5] <> #0) and (UpCase(P[5]) = 'I') and
       (P[6] <> #0) and (UpCase(P[6]) = 'T') and (P[7] <> #0) and
       (UpCase(P[7]) = 'Y') then L := 8;
    { +Inf via bit pattern: avoids FPC EOverflow on literal overflow }
    Bits := $7FF0000000000000;
    Move(Bits, X, 8);
    if Neg then X := -X;
    if DummyEnd <> nil then DummyEnd^ := P + L;
    Result := X;
    Exit;
  end;
  { NAN / NAN(n-char-sequence) }
  if (P^ <> #0) and ((UpCase(P^) = 'N') and (P[1] <> #0) and
     (UpCase(P[1]) = 'A') and (P[2] <> #0) and (UpCase(P[2]) = 'N')) then
  begin
    L := 3;
    NLen := 0;
    if P[3] = '(' then begin
      Inc(L); { '(' consumed }
      while P[L] <> #0 do begin
        C := P[L];
        if ((C >= 'a') and (C <= 'z')) or ((C >= 'A') and (C <= 'Z')) or
           ((C >= '0') and (C <= '9')) or (C = '_') then begin
          if NLen < 64 then begin NBuf[NLen] := C; Inc(NLen); end;
          Inc(L)
        end
        else break;
      end;
      if P[L] = ')' then begin
        { glibc(含 GCC __builtin_nan) 的 payload 映射：
          base-0 strtoul 语义（0x → hex、前导 0 → oct、否则 dec），
          必须整体合法否则 payload=0；数值溢出（strtoul 给 ULONG_MAX）→ 52 位全 1 }
        Inc(L);
        Novak := False;
        NVal := 0;
        NBase := 10;
        Idx := 0;
        if NLen = 0 then Novak := True
        else if (NLen >= 2) and (NBuf[0] = '0') and
                ((NBuf[1] = 'x_2') or (NBuf[1] = 'X')) then begin
          NBase := 16;
          Idx := 2;
          if NLen = 2 then Novak := True; { '0x' 后无数字：整体不合法 }
        end
        else if NBuf[0] = '0' then NBase := 8; { 前导 0 → octal }
        if not Novak then begin
          Novf := False;
          while Idx < NLen do begin
            C := NBuf[Idx];
            D := -1;
            if (C >= '0') and (C <= '9') then D := Ord(C) - 48
            else if (C >= 'a') and (C <= 'f') then D := Ord(C) - 87
            else if (C >= 'A') and (C <= 'F') then D := Ord(C) - 55;
            if (D < 0) or (D >= NBase) then begin Novak := True; break; end;
            { 注意 D/NBase 为有符号：须显式转 QWord 强制无符号除法 }
            if NVal > (High(QWord) - QWord(D)) div QWord(NBase) then Novf := True;
            NVal := NVal * NBase + D;
            Inc(Idx);
          end;
        end;
        if Novak then NVal := 0
        else if Novf then NVal := $FFFFFFFFFFFFF
        else NVal := NVal and $FFFFFFFFFFFFF;
        Bits := $7FF8000000000000 or NVal;
      end
      else begin
        L := 3; { 无闭合括号：括号组整体不消费（C99/glibc）}
        Bits := $7FF8000000000000;
      end;
    end
    else begin
      Bits := $7FF8000000000000;
    end;
    Move(Bits, X, 8);
    if Neg then X := -X;
    if DummyEnd <> nil then DummyEnd^ := P + L;
    Result := X;
    Exit;
  end;
  { hex float: 0x/0X with >=1 hex digit (after optional '.') to confirm }
  IsHex := False;
  if (P^ = '0') and ((P[1] = 'x_2') or (P[1] = 'X')) then begin
    D := -1;
    if (P[2] >= '0') and (P[2] <= '9') then D := Ord(P[2]) - 48
    else if (P[2] >= 'a') and (P[2] <= 'f') then D := Ord(P[2]) - 87
    else if (P[2] >= 'A') and (P[2] <= 'F') then D := Ord(P[2]) - 55;
    if D >= 0 then IsHex := True
    else if P[2] = '.' then begin
      D := -1;
      if (P[3] >= '0') and (P[3] <= '9') then D := Ord(P[3]) - 48
      else if (P[3] >= 'a') and (P[3] <= 'f') then D := Ord(P[3]) - 87
      else if (P[3] >= 'A') and (P[3] <= 'F') then D := Ord(P[3]) - 55;
      if D >= 0 then IsHex := True;
    end;
  end;
  HasDigits := False;
  AnyNonZero := False;
  if IsHex then begin
    Inc(P, 2); { consume 0x prefix }
    M := 0;
    MBits := 0;
    DfHex := 0;
    HexLost := False;
    CutHex := 0;
    ExpBits := 0;
    try
      { integer hex digits }
      while P^ <> #0 do begin
        D := -1;
        if (P^ >= '0') and (P^ <= '9') then D := Ord(P^) - 48
        else if (P^ >= 'a') and (P^ <= 'f') then D := Ord(P^) - 87
        else if (P^ >= 'A') and (P^ <= 'F') then D := Ord(P^) - 55;
        if D < 0 then break;
        HasDigits := True;
        if D <> 0 then AnyNonZero := True;
        if MBits >= 64 then begin
          if D <> 0 then HexLost := True;
          Inc(CutHex); { 被截断的 hex 位：量级修正 4×CutHex }
        end else begin
          M := (M shl 4) or QWord(D);
          Inc(MBits, 4);
        end;
        Inc(P);
      end;
      if P^ = '.' then begin
        Inc(P);
        while P^ <> #0 do begin
          D := -1;
          if (P^ >= '0') and (P^ <= '9') then D := Ord(P^) - 48
          else if (P^ >= 'a') and (P^ <= 'f') then D := Ord(P^) - 87
          else if (P^ >= 'A') and (P^ <= 'F') then D := Ord(P^) - 55;
          if D < 0 then break;
          HasDigits := True;
          if D <> 0 then AnyNonZero := True;
          Inc(DfHex);
          if MBits >= 64 then begin
            if D <> 0 then HexLost := True;
            Inc(CutHex);
          end else begin
            M := (M shl 4) or QWord(D);
            Inc(MBits, 4);
          end;
          Inc(P);
        end;
      end;
      { hex exponent p[+-]digits }
      if ((P^ = 'p') or (P^ = 'P')) and (P[1] <> #0) and
         (((P[1] >= '0') and (P[1] <= '9')) or
          ((P[1] = '+') and (P[2] <> #0) and (P[2] >= '0') and (P[2] <= '9')) or
          ((P[1] = '-') and (P[2] <> #0) and (P[2] >= '0') and (P[2] <= '9'))) then
      begin
        Inc(P);
        ExpNeg := False;
        if P^ = '+' then Inc(P)
        else if P^ = '-' then begin ExpNeg := True; Inc(P); end;
        ExpBits := 0;
        while (P^ >= '0') and (P^ <= '9') do begin
          if ExpBits < 1000000 then ExpBits := ExpBits * 10 + (Ord(P^) - 48);
          Inc(P);
        end;
        if ExpNeg then ExpBits := -ExpBits;
        if ExpBits > 4096 then ExpBits := 4096
        else if ExpBits < -4096 then ExpBits := -4096;
      end;
    except
      { 防御兜底（不应触发）}
      X := 0.0;
      Bits := $7FF0000000000000;
      Move(Bits, X, 8); { +Inf }
      ClearFPUFlags;
      if Neg then X := -X;
      if DummyEnd <> nil then DummyEnd^ := P;
      __errno_location()^ := 34;
      Result := X;
      Exit;
    end;
    if DummyEnd <> nil then DummyEnd^ := P;
    if not AnyNonZero then begin
      { 全零 hex：不设 errno（glibc）}
      X := 0.0;
      if Neg then X := -X;
      Result := X;
      Exit;
    end;
    { 值 = M × 2^T，T = ExpBits - 4*DfHex + 4*CutHex（CutHex 补回
      被 64-bit 窗口截断的低位量级）；一次规格化 + round-to-nearest-even }
    T := ExpBits - 4 * DfHex + 4 * CutHex;
    QW := M;
    L := 0;
    while QW > 1 do begin QW := QW shr 1; Inc(L); end;
    EvalI := T + L;
    if EvalI > 1023 then begin
      Bits := $7FF0000000000000;
      Move(Bits, X, 8);
      if Neg then X := -X;
      __errno_location()^ := 34;
      Result := X;
      Exit;
    end;
    if EvalI >= -1022 then begin
      { 正规数：msb 移到 bit 52（隐含位），低位截断时 round-half-even }
      BL := L - 52;
      if BL <= 0 then
        mant := M shl (-BL)
      else begin
        remLW := M and ((QWord(1) shl BL) - 1);
        mant := M shr BL;
        half := QWord(1) shl (BL - 1);
        if (remLW > half) or ((remLW = half) and ((mant and 1) = 1)) then
          Inc(mant);
        if mant = (QWord(1) shl 53) then begin
          { 尾数进位：EvalI+1，回到 2^52 }
          mant := QWord(1) shl 52;
          Inc(EvalI);
          if EvalI > 1023 then begin
            Bits := $7FF0000000000000;
            Move(Bits, X, 8);
            if Neg then X := -X;
            __errno_location()^ := 34;
            Result := X;
            Exit;
          end;
        end;
      end;
      Bits := (QWord(EvalI + 1023) shl 52) or (mant and $FFFFFFFFFFFFF);
      Move(Bits, X, 8);
      if Neg then X := -X;
      Result := X;
      Exit;
    end;
    { 次正规：网格 2^-1074，网格数 = M × 2^Rg，Rg = T + 1074
      （glibc：仅当结果非精确才置 ERANGE）}
    Rg := T + 1074;
    HexExact := True;
    if Rg >= 0 then begin
      { Rg ≤ 51-L（次正规域）→ 网格数 < 2^52：QWord 无溢出、无舍入、精确 }
      g := M shl Rg;
      Bits := g;
    end else begin
      BL := LongInt(-Rg);
      if BL >= 64 then begin
        { 网格数 < 0.5：舍入到 0（M<2^BL ⇒ rem<half）}
        g := 0;
        HexExact := False;
      end else begin
        g := M shr BL;
        remLW := M and ((QWord(1) shl BL) - 1);
        half := QWord(1) shl (BL - 1);
        if (remLW > half) or ((remLW = half) and ((g and 1) = 1)) then
          Inc(g);
        if remLW <> 0 then HexExact := False;
      end;
      if HexLost then HexExact := False; { 64-bit 截断也属非精确 }
      if g >= (QWord(1) shl 52) then
        Bits := $0010000000000000 { 进位到 DBL_MIN（正规下边界）}
      else
        Bits := g;
    end;
    Move(Bits, X, 8);
    if Neg then X := -X;
    if not HexExact then __errno_location()^ := 34;
    Result := X;
    Exit;
  end;
  { decimal: 扫描有效数字结构，同时预判量级 k（首位有效数字的 10 次幂）}
  I := 0;
  SigCount := 0;
  Di := 0;
  Df := 0;
  HasDecPoint := False;
  FirstSig := False;
  FirstInt := False;
  KIntBase := 0;
  k := 0;
  Mhi := 0;
  Mlo := 0;
  R := False;
  S60Len := 0;
  Beyond60 := False;
  while P^ <> #0 do begin
    if (P^ >= '0') and (P^ <= '9') then begin
      if I < 480 then begin Buf[I] := P^; Inc(I); end;
      if P^ <> '0' then AnyNonZero := True;
      HasDigits := True;
      if HasDecPoint then Inc(Df) else Inc(Di);
      if not FirstSig then begin
        if P^ <> '0' then begin
          FirstSig := True;
          if HasDecPoint then k := -Df
          else begin
            FirstInt := True;
            KIntBase := Di; { 首位有效时的整数位数，扫描后再定 k }
          end;
        end;
      end;
      if FirstSig then begin
        Inc(SigCount);
        if SigCount <= 60 then begin
          S60[SigCount - 1] := P^;
          if SigCount <= 15 then Mhi := Mhi * 10 + (Ord(P^) - 48)
          else if SigCount <= 20 then Mlo := Mlo * 10 + (Ord(P^) - 48);
        end else if P^ <> '0' then Beyond60 := True;
      end;
      Inc(P);
    end else if (P^ = '.') and (not HasDecPoint) then begin
      if I < 480 then begin Buf[I] := '.'; Inc(I); end;
      HasDecPoint := True;
      Inc(P);
    end else break;
  end;
  if FirstInt then k := Di - KIntBase;
  { exponent: consume only if followed by a valid exponent }
  ExpNegDec := False;
  Ei := 0;
  ExpSign := 1;
  HasExp := False;
  if ((P^ = 'e') or (P^ = 'E')) and (P[1] <> #0) and
     (((P[1] >= '0') and (P[1] <= '9')) or
      ((P[1] = '+') and (P[2] <> #0) and (P[2] >= '0') and (P[2] <= '9')) or
      ((P[1] = '-') and (P[2] <> #0) and (P[2] >= '0') and (P[2] <= '9'))) then
  begin
    HasExp := True;
    if I < 480 then begin Buf[I] := 'e'; Inc(I); end;
    Inc(P);
    if P^ = '+' then begin if I < 480 then begin Buf[I] := '+'; Inc(I); end; Inc(P); end
    else if P^ = '-' then begin
      ExpNegDec := True;
      ExpSign := -1;
      if I < 480 then begin Buf[I] := '-'; Inc(I); end;
      Inc(P);
    end;
    while P^ <> #0 do begin
      if (P^ >= '0') and (P^ <= '9') then begin
        if I < 480 then begin Buf[I] := P^; Inc(I); end;
        if Ei < 100000000000000 then
          Ei := Ei * 10 + (Ord(P^) - 48); { 饱和防 Int64 溢出 }
        Inc(P);
      end else break;
    end;
  end;
  if not HasDigits then begin
    { no conversion: DummyEnd = original nptr (C99) }
    if DummyEnd <> nil then DummyEnd^ := nptr;
    Result := 0.0;
    Exit;
  end;
  KTotal := k + ExpSign * Ei;
  { 溢出/下溢预判仅适用于非全零输入（全零不设 ERANGE、永不溢出/下溢）}
  if FirstSig then begin
    Overflow := KTotal > 308;
    if KTotal = 308 then begin
    if SigCount > 60 then S60Len := 60 else S60Len := SigCount;
    Cmp := CmpT60(S60, S60Len);
    Overflow := Cmp > 0;
  end;
    Underflow := KTotal < -324;
  end else begin
    Overflow := False;
    Underflow := False;
  end;
  Buf[I] := #0;
  if Overflow then begin
    X := 0.0;
    Bits := $7FF0000000000000;
    Move(Bits, X, 8); { +Inf }
    if Neg then X := -X;
    if DummyEnd <> nil then DummyEnd^ := P;
    __errno_location()^ := 34;
    Result := X;
    Exit;
  end;
  if Underflow then begin
    X := 0.0;
    if Neg then X := -X; { -0.0 保留符号（C99）}
    if DummyEnd <> nil then DummyEnd^ := P;
    __errno_location()^ := 34;
    Result := X;
    Exit;
  end;
  if not FirstSig then begin
    { 全零：±0，不设 errno（0e999 等）}
    X := 0.0;
    if Neg then X := -X;
    if DummyEnd <> nil then DummyEnd^ := P;
    Result := X;
    Exit;
  end;
  { 尾部补零：Mhi 15 位 / Mlo 5 位（M20 = MHw×1e5+MLw；SC>20 的
    截断误差 ≤ 10^-20 相对 << 0.5ulp，不影响舍入正确性）}
  if SigCount > 15 then begin SCh := 15; SCl := SigCount - 15; end
  else begin SCh := SigCount; SCl := 0; end;
  MHw := Mhi;
  MLw := Mlo;
  for I := SCh to 14 do MHw := MHw * 10;
  for I := SCl to 4 do MLw := MLw * 10;
  KIntL := KTotal - 19; { 表下标（值 = M20×10^KIntL）}
  { 合成双 double 尾数对：Wh+Wl = MHw×1e5 精确，WlB ≈ Wl + MLw = M20。
    单次幂乘吃全 20 位；两段独立幂乘相加会先丢 Mlo 低位再合并（1ulp 级）}
  TwoProd(Double(MHw), 100000.0, Wh, Wl);
  WlB := Wl + Double(MLw);
  if KIntL <= -308 then begin
    { BN 定点：网格数 = M20×B(KIntL)（B=10^K×2^1074 双 double，正规域），
      结果 = QN×2^-1074。覆盖次正规与 DBL_MIN 邻近（含舍入进位）}
    try
      XN := PmulB(Wh, WlB, KIntL);
    except
      ClearFPUFlags;
      XN := 0.0;
    end;
    { 直接 ×2^-1074 得结果：正规/次正规都由浮点精确舍入到网格。
      XN 误差 2^-104 相对 → 绝对 ~2^-1178 << 0.5 网格，舍入正确。
      不做网格整数拼接——QN 可达 2^114，Int64 的 Trunc 会硬件异常 }
    Bits := 1; { 2^-1074（最小次正规）}
    Move(Bits, F2, 8);
    X := XN * F2;
    Q64 := 0;
    Move(X, Q64, 8);
    if (Q64 and $7FF0000000000000) = 0 then
      __errno_location()^ := 34; { 十进制次正规无条件 ERANGE }
    if Neg then X := -X;
    if DummyEnd <> nil then DummyEnd^ := P;
    Result := X;
    Exit;
  end;
  { 主幂乘：值 = M20×10^KIntL（KIntL ∈ [-307, 289]，10^KIntL 正规 double）。
    双 double 单次幂乘 ~2^-106 相对误差，替代 FPC Val（其上溢/下溢/
    1ulp/MXCSR 均不可靠）}
  try
    X := Pmul(Wh, WlB, KIntL);
  except
    { 数学值 ∈ (DBL_MAX, DBL_MAX+0.5ulp]：C99 舍入到 DBL_MAX（不溢）}
    ClearFPUFlags;
    Q64 := $7FEFFFFFFFFFFFFF;
    Move(Q64, X, 8);
  end;
  if Neg then X := -X;
  if DummyEnd <> nil then DummyEnd^ := P;
  Q64 := 0;
  Move(X, Q64, 8);
  { 位模式后判定（幂乘正确性兜底；十进制仅次正规无条件 ERANGE）}
  if (Q64 = QWord($7FF0000000000000)) or (Q64 = QWord($FFF0000000000000)) then
    __errno_location()^ := 34
  else if (Q64 = 0) or (Q64 = QWord($8000000000000000)) then
    __errno_location()^ := 34
  else if (Q64 and $7FFFFFFFFFFFFFFF <> 0) and
          ((Q64 and $7FF0000000000000) = 0) then
    __errno_location()^ := 34;
  Result := X;
end;


function strtol(nptr: PAnsiChar; endptr: PPAnsiChar; base: LongInt): Int64; cdecl;
var
  P: PAnsiChar;
  Neg: Boolean;
  B: LongInt;
  Acc: QWord;
  D: LongInt;
  Lim: QWord;
  Converted: Boolean;
begin
  Result := 0;
  if nptr = nil then begin
    if endptr <> nil then endptr^ := nptr;
    Exit;
  end;
  P := nptr;
  while (P^ <> #0) and ((P^ = ' ') or (P^ = #9) or (P^ = #10) or
         (P^ = #11) or (P^ = #12) or (P^ = #13)) do Inc(P);
  Neg := False;
  if P^ = '+' then Inc(P)
  else if P^ = '-' then begin Neg := True; Inc(P); end;
  B := base;
  if B = 16 then begin
    if (P^ = '0') and ((P[1] = 'x_2') or (P[1] = 'X')) then Inc(P, 2);
  end else if B = 0 then begin
    if (P^ = '0') and ((P[1] = 'x_2') or (P[1] = 'X')) then begin B := 16; Inc(P, 2); end
    else if P^ = '0' then B := 8
    else B := 10;
  end;
  Converted := False;
  Acc := 0;
  if Neg then Lim := QWord(High(Int64)) + 1 { 2^63: LONG_MIN 幅度 }
  else Lim := QWord(High(Int64));
  while P^ <> #0 do begin
    D := -1;
    if (P^ >= '0') and (P^ <= '9') then D := Ord(P^) - 48
    else if (P^ >= 'a') and (P^ <= 'z') then D := Ord(P^) - 87
    else if (P^ >= 'A') and (P^ <= 'Z') then D := Ord(P^) - 55;
    if (D < 0) or (D >= B) then break;
    Converted := True;
    if Acc > (Lim - QWord(D)) div QWord(B) then begin
      __errno_location()^ := 34; { ERANGE (glibc/msvcrt 均为 34) }
      Acc := Lim;
      Inc(P);
      while P^ <> #0 do begin
        D := -1;
        if (P^ >= '0') and (P^ <= '9') then D := Ord(P^) - 48
        else if (P^ >= 'a') and (P^ <= 'z') then D := Ord(P^) - 87
        else if (P^ >= 'A') and (P^ <= 'Z') then D := Ord(P^) - 55;
        if (D < 0) or (D >= B) then break;
        Inc(P);
      end;
      break;
    end;
    Acc := Acc * QWord(B) + QWord(D);
    Inc(P);
  end;
  if endptr <> nil then begin
    if Converted then endptr^ := P
    else endptr^ := nptr; { C99: 无转换时 endptr = 原 nptr }
  end;
  if Neg then begin
    if Acc > QWord(High(Int64)) then Result := Low(Int64)
    else Result := -Int64(Acc);
  end else
    Result := Int64(Acc);
end;

function strtoul(nptr: PAnsiChar; endptr: PPAnsiChar; base: LongInt): QWord; cdecl;
var
  P: PAnsiChar;
  Neg: Boolean;
  B: LongInt;
  Acc: QWord;
  D: LongInt;
  Converted: Boolean;
begin
  Result := 0;
  if nptr = nil then begin
    if endptr <> nil then endptr^ := nptr;
    Exit;
  end;
  P := nptr;
  while (P^ <> #0) and ((P^ = ' ') or (P^ = #9) or (P^ = #10) or
         (P^ = #11) or (P^ = #12) or (P^ = #13)) do Inc(P);
  Neg := False;
  if P^ = '+' then Inc(P)
  else if P^ = '-' then begin Neg := True; Inc(P); end;
  B := base;
  if B = 16 then begin
    if (P^ = '0') and ((P[1] = 'x_2') or (P[1] = 'X')) then Inc(P, 2);
  end else if B = 0 then begin
    if (P^ = '0') and ((P[1] = 'x_2') or (P[1] = 'X')) then begin B := 16; Inc(P, 2); end
    else if P^ = '0' then B := 8
    else B := 10;
  end;
  Converted := False;
  Acc := 0;
  while P^ <> #0 do begin
    D := -1;
    if (P^ >= '0') and (P^ <= '9') then D := Ord(P^) - 48
    else if (P^ >= 'a') and (P^ <= 'z') then D := Ord(P^) - 87
    else if (P^ >= 'A') and (P^ <= 'Z') then D := Ord(P^) - 55;
    if (D < 0) or (D >= B) then break;
    Converted := True;
    if Acc > (High(QWord) - QWord(D)) div QWord(B) then begin
      __errno_location()^ := 34; { ERANGE }
      Acc := High(QWord);
      Inc(P);
      while P^ <> #0 do begin
        D := -1;
        if (P^ >= '0') and (P^ <= '9') then D := Ord(P^) - 48
        else if (P^ >= 'a') and (P^ <= 'z') then D := Ord(P^) - 87
        else if (P^ >= 'A') and (P^ <= 'Z') then D := Ord(P^) - 55;
        if (D < 0) or (D >= B) then break;
        Inc(P);
      end;
      break;
    end;
    Acc := Acc * QWord(B) + QWord(D);
    Inc(P);
  end;
  if endptr <> nil then begin
    if Converted then endptr^ := P
    else endptr^ := nptr; { C99: 无转换时 endptr = 原 nptr }
  end;
  if Neg then Result := 0 - Acc { 负号环绕: "-1" → ULONG_MAX }
  else Result := Acc;
end;

function strtoll(nptr: PAnsiChar; endptr: PPAnsiChar; base: LongInt): Int64; cdecl;
var
  P: PAnsiChar;
  Neg: Boolean;
  B: LongInt;
  Acc: QWord;
  D: LongInt;
  Lim: QWord;
  Converted: Boolean;
begin
  Result := 0;
  if nptr = nil then begin
    if endptr <> nil then endptr^ := nptr;
    Exit;
  end;
  P := nptr;
  while (P^ <> #0) and ((P^ = ' ') or (P^ = #9) or (P^ = #10) or
         (P^ = #11) or (P^ = #12) or (P^ = #13)) do Inc(P);
  Neg := False;
  if P^ = '+' then Inc(P)
  else if P^ = '-' then begin Neg := True; Inc(P); end;
  B := base;
  if B = 16 then begin
    if (P^ = '0') and ((P[1] = 'x_2') or (P[1] = 'X')) then Inc(P, 2);
  end else if B = 0 then begin
    if (P^ = '0') and ((P[1] = 'x_2') or (P[1] = 'X')) then begin B := 16; Inc(P, 2); end
    else if P^ = '0' then B := 8
    else B := 10;
  end;
  Converted := False;
  Acc := 0;
  if Neg then Lim := QWord(High(Int64)) + 1 { 2^63: LONG_MIN 幅度 }
  else Lim := QWord(High(Int64));
  while P^ <> #0 do begin
    D := -1;
    if (P^ >= '0') and (P^ <= '9') then D := Ord(P^) - 48
    else if (P^ >= 'a') and (P^ <= 'z') then D := Ord(P^) - 87
    else if (P^ >= 'A') and (P^ <= 'Z') then D := Ord(P^) - 55;
    if (D < 0) or (D >= B) then break;
    Converted := True;
    if Acc > (Lim - QWord(D)) div QWord(B) then begin
      __errno_location()^ := 34; { ERANGE (glibc/msvcrt 均为 34) }
      Acc := Lim;
      Inc(P);
      while P^ <> #0 do begin
        D := -1;
        if (P^ >= '0') and (P^ <= '9') then D := Ord(P^) - 48
        else if (P^ >= 'a') and (P^ <= 'z') then D := Ord(P^) - 87
        else if (P^ >= 'A') and (P^ <= 'Z') then D := Ord(P^) - 55;
        if (D < 0) or (D >= B) then break;
        Inc(P);
      end;
      break;
    end;
    Acc := Acc * QWord(B) + QWord(D);
    Inc(P);
  end;
  if endptr <> nil then begin
    if Converted then endptr^ := P
    else endptr^ := nptr; { C99: 无转换时 endptr = 原 nptr }
  end;
  if Neg then begin
    if Acc > QWord(High(Int64)) then Result := Low(Int64)
    else Result := -Int64(Acc);
  end else
    Result := Int64(Acc);
end;

function strtoull(nptr: PAnsiChar; endptr: PPAnsiChar; base: LongInt): QWord; cdecl;
var
  P: PAnsiChar;
  Neg: Boolean;
  B: LongInt;
  Acc: QWord;
  D: LongInt;
  Converted: Boolean;
begin
  Result := 0;
  if nptr = nil then begin
    if endptr <> nil then endptr^ := nptr;
    Exit;
  end;
  P := nptr;
  while (P^ <> #0) and ((P^ = ' ') or (P^ = #9) or (P^ = #10) or
         (P^ = #11) or (P^ = #12) or (P^ = #13)) do Inc(P);
  Neg := False;
  if P^ = '+' then Inc(P)
  else if P^ = '-' then begin Neg := True; Inc(P); end;
  B := base;
  if B = 16 then begin
    if (P^ = '0') and ((P[1] = 'x_2') or (P[1] = 'X')) then Inc(P, 2);
  end else if B = 0 then begin
    if (P^ = '0') and ((P[1] = 'x_2') or (P[1] = 'X')) then begin B := 16; Inc(P, 2); end
    else if P^ = '0' then B := 8
    else B := 10;
  end;
  Converted := False;
  Acc := 0;
  while P^ <> #0 do begin
    D := -1;
    if (P^ >= '0') and (P^ <= '9') then D := Ord(P^) - 48
    else if (P^ >= 'a') and (P^ <= 'z') then D := Ord(P^) - 87
    else if (P^ >= 'A') and (P^ <= 'Z') then D := Ord(P^) - 55;
    if (D < 0) or (D >= B) then break;
    Converted := True;
    if Acc > (High(QWord) - QWord(D)) div QWord(B) then begin
      __errno_location()^ := 34; { ERANGE }
      Acc := High(QWord);
      Inc(P);
      while P^ <> #0 do begin
        D := -1;
        if (P^ >= '0') and (P^ <= '9') then D := Ord(P^) - 48
        else if (P^ >= 'a') and (P^ <= 'z') then D := Ord(P^) - 87
        else if (P^ >= 'A') and (P^ <= 'Z') then D := Ord(P^) - 55;
        if (D < 0) or (D >= B) then break;
        Inc(P);
      end;
      break;
    end;
    Acc := Acc * QWord(B) + QWord(D);
    Inc(P);
  end;
  if endptr <> nil then begin
    if Converted then endptr^ := P
    else endptr^ := nptr; { C99: 无转换时 endptr = 原 nptr }
  end;
  if Neg then Result := 0 - Acc { 负号环绕: "-1" → ULONG_MAX }
  else Result := Acc;
end;

var __c2p_rand_state: array[0..30] of LongWord;
    __c2p_rand_fptr: LongInt;
    __c2p_rand_rptr: LongInt;

function rand(): LongInt; cdecl;
var
  Val: QWord;
begin
  Val := (__c2p_rand_state[__c2p_rand_fptr] + __c2p_rand_state[__c2p_rand_rptr]) and $ffffffff;
  __c2p_rand_state[__c2p_rand_fptr] := LongWord(Val);
  Result := LongInt(Val shr 1);
  __c2p_rand_fptr := (__c2p_rand_fptr + 1) mod 31;
  __c2p_rand_rptr := (__c2p_rand_rptr + 1) mod 31;
end;

procedure srand(seed: LongWord); cdecl;
var
  W: Int64;
  I: LongInt;
begin
  if Seed = 0 then Seed := 1;
  __c2p_rand_state[0] := Seed;
  W := Seed;
  for I := 1 to 30 do
  begin
    W := (16807 * W) mod 2147483647;
    __c2p_rand_state[I] := LongWord(W);
  end;
  __c2p_rand_fptr := 3;
  __c2p_rand_rptr := 0;
  for I := 1 to 310 do
    rand();
end;

function sinh(x_2: Double): Double; cdecl;
begin
  Result := (System.exp(x_2) - System.exp(-x_2)) / 2.0;
end;

function cosh(x_2: Double): Double; cdecl;
begin
  Result := (System.exp(x_2) + System.exp(-x_2)) / 2.0;
end;

function tanh(x_2: Double): Double; cdecl;
var
  E2X: Double;
begin
  if x_2 > 20.0 then Result := 1.0
  else if x_2 < -20.0 then Result := -1.0
  else begin
    E2X := System.exp(2.0 * x_2);
    Result := (E2X - 1.0) / (E2X + 1.0);
  end;
end;

{ 直连 libc 真实现：exp(ln2) 模拟在扩展精度后端（i386 x87）上会偏离
  glibc 的精确 2^e 缩放，导致 ±1 LSB 位精确性破坏 }
function ldexp(x_2: Double; exp_2: LongInt): Double; cdecl; external CLIB name 'ldexp';

function frexp(x_2: Double; exp_2: PLongInt): Double; cdecl;
var
  AbsX: Double;
  E: LongInt;
begin
  if x_2 = 0.0 then begin
    if exp_2 <> nil then exp_2^ := 0;
    System.Exit(0.0);
  end;
  AbsX := x_2;
  if AbsX < 0 then AbsX := -AbsX;
  E := 0;
  while AbsX >= 1.0 do begin AbsX := AbsX / 2.0; Inc(E); end;
  while AbsX < 0.5 do begin AbsX := AbsX * 2.0; Dec(E); end;
  if exp_2 <> nil then exp_2^ := E;
  if x_2 < 0 then Result := -AbsX else Result := AbsX;
end;

function modf(x_2: Double; iptr: PDouble): Double; cdecl;
var
  IntPart: Double;
begin
  IntPart := Double(System.Trunc(x_2));
  if iptr <> nil then iptr^ := IntPart;
  Result := x_2 - IntPart;
end;

function fabsf(x_2: Single): Single; cdecl;
begin
  if x_2 < 0 then Result := -x_2 else Result := x_2;
end;

function sqrtf(x_2: Single): Single; cdecl;
begin
  if x_2 <= 0 then Result := 0 else Result := Single(System.sqrt(x_2));
end;

function floorf(x_2: Single): Single; cdecl;
begin
  Result := Single(System.Trunc(x_2));
  if x_2 < Result then Result := Result - 1;
end;

function ceilf(x_2: Single): Single; cdecl;
begin
  Result := Single(System.Trunc(x_2));
  if x_2 > Result then Result := Result + 1;
end;

function isinf(x_2: Double): LongInt; cdecl;
begin
  if x_2 <> x_2 then Result := 0
  else if (x_2 = 1.0 / 0.0) or (x_2 = -1.0 / 0.0) then Result := 1
  else Result := 0;
end;

function isnan(x_2: Double): LongInt; cdecl;
begin
  if x_2 <> x_2 then Result := 1 else Result := 0;
end;

type
  PPPUint8 = ^PPUint8;

var
  crc_table: array[0..255] of TUint32;
  ogg_page_header: array[0..3] of TUint8 = (79, 103, 103, 83);
  inverse_db_table: array[0..255] of Single = (1.0649863e-07, 1.1341951e-07, 1.2079015e-07, 1.2863978e-07, 1.3699951e-07, 1.4590251e-07, 1.5538408e-07, 1.6548181e-07, 1.7623575e-07, 1.8768855e-07, 1.9988561e-07, 2.1287530e-07, 2.2670913e-07, 2.4144197e-07, 2.5713223e-07, 2.7384213e-07, 2.9163793e-07, 3.1059021e-07, 3.3077411e-07, 3.5226968e-07, 3.7516214e-07, 3.9954229e-07, 4.2550680e-07, 4.5315863e-07, 4.8260743e-07, 5.1396998e-07, 5.4737065e-07, 5.8294187e-07, 6.2082472e-07, 6.6116941e-07, 7.0413592e-07, 7.4989464e-07, 7.9862701e-07, 8.5052630e-07, 9.0579828e-07, 9.6466216e-07, 1.0273513e-06, 1.0941144e-06, 1.1652161e-06, 1.2409384e-06, 1.3215816e-06, 1.4074654e-06, 1.4989305e-06, 1.5963394e-06, 1.7000785e-06, 1.8105592e-06, 1.9282195e-06, 2.0535261e-06, 2.1869758e-06, 2.3290978e-06, 2.4804557e-06, 2.6416497e-06, 2.8133190e-06, 2.9961443e-06, 3.1908506e-06, 3.3982101e-06, 3.6190449e-06, 3.8542308e-06, 4.1047004e-06, 4.3714470e-06, 4.6555282e-06, 4.9580707e-06, 5.2802740e-06, 5.6234160e-06, 5.9888572e-06, 6.3780469e-06, 6.7925283e-06, 7.2339451e-06, 7.7040476e-06, 8.2047000e-06, 8.7378876e-06, 9.3057248e-06, 9.9104632e-06, 1.0554501e-05, 1.1240392e-05, 1.1970856e-05, 1.2748789e-05, 1.3577278e-05, 1.4459606e-05, 1.5399272e-05, 1.6400004e-05, 1.7465768e-05, 1.8600792e-05, 1.9809576e-05, 2.1096914e-05, 2.2467911e-05, 2.3928002e-05, 2.5482978e-05, 2.7139006e-05, 2.8902651e-05, 3.0780908e-05, 3.2781225e-05, 3.4911534e-05, 3.7180282e-05, 3.9596466e-05, 4.2169667e-05, 4.4910090e-05, 4.7828601e-05, 5.0936773e-05, 5.4246931e-05, 5.7772202e-05, 6.1526565e-05, 6.5524908e-05, 6.9783085e-05, 7.4317983e-05, 7.9147585e-05, 8.4291040e-05, 8.9768747e-05, 9.5602426e-05, 0.00010181521, 0.00010843174, 0.00011547824, 0.00012298267, 0.00013097477, 0.00013948625, 0.00014855085, 0.00015820453, 0.00016848555, 0.00017943469, 0.00019109536, 0.00020351382, 0.00021673929, 0.00023082423, 0.00024582449, 0.00026179955, 0.00027881276, 0.00029693158, 0.00031622787, 0.00033677814, 0.00035866388, 0.00038197188, 0.00040679456, 0.00043323036, 0.00046138411, 0.00049136745, 0.00052329927, 0.00055730621, 0.00059352311, 0.00063209358, 0.00067317058, 0.00071691700, 0.00076350630, 0.00081312324, 0.00086596457, 0.00092223983, 0.00098217216, 0.0010459992, 0.0011139742, 0.0011863665, 0.0012634633, 0.0013455702, 0.0014330129, 0.0015261382, 0.0016253153, 0.0017309374, 0.0018434235, 0.0019632195, 0.0020908006, 0.0022266726, 0.0023713743, 0.0025254795, 0.0026895994, 0.0028643847, 0.0030505286, 0.0032487691, 0.0034598925, 0.0036847358, 0.0039241906, 0.0041792066, 0.0044507950, 0.0047400328, 0.0050480668, 0.0053761186, 0.0057254891, 0.0060975636, 0.0064938176, 0.0069158225, 0.0073652516, 0.0078438871, 0.0083536271, 0.0088964928, 0.009474637, 0.010090352, 0.010746080, 0.011444421, 0.012188144, 0.012980198, 0.013823725, 0.014722068, 0.015678791, 0.016697687, 0.017782797, 0.018938423, 0.020169149, 0.021479854, 0.022875735, 0.024362330, 0.025945531, 0.027631618, 0.029427276, 0.031339626, 0.033376252, 0.035545228, 0.037855157, 0.040315199, 0.042935108, 0.045725273, 0.048696758, 0.051861348, 0.055231591, 0.058820850, 0.062643361, 0.066714279, 0.071049749, 0.075666962, 0.080584227, 0.085821044, 0.091398179, 0.097337747, 0.10366330, 0.11039993, 0.11757434, 0.12521498, 0.13335215, 0.14201813, 0.15124727, 0.16107617, 0.17154380, 0.18269168, 0.19456402, 0.20720788, 0.22067342, 0.23501402, 0.25028656, 0.26655159, 0.28387361, 0.30232132, 0.32196786, 0.34289114, 0.36517414, 0.38890521, 0.41417847, 0.44109412, 0.46975890, 0.50028648, 0.53279791, 0.56742212, 0.60429640, 0.64356699, 0.68538959, 0.72993007, 0.77736504, 0.82788260, 0.88168307, 0.9389798, 1.0);
  channel_position: array[0..6] of array[0..5] of TInt8 = ((0, 0, 0, 0, 0, 0), (7, 0, 0, 0, 0, 0), (3, 5, 0, 0, 0, 0), (3, 7, 5, 0, 0, 0), (3, 5, 3, 5, 0, 0), (3, 7, 5, 3, 5, 0), (3, 7, 5, 3, 5, 7));
  _static_ilog_log2_4: array[0..15] of ShortInt;
  _static_vorbis_validate_vorbis: array[0..5] of TUint8;
  _static_vorbis_decode_packet_rest_range_list: array[0..3] of LongInt;
  _static_convert_samples_short_channel_selector: array[0..2] of array[0..1] of LongInt;

var __c2p_static_filled_music888_vorbisdec: Boolean = False;

procedure __c2p_static_fill_music888_vorbisdec; forward;

function error(f: PVorb; e: LongInt): LongInt; inline;
begin
  f^.error := e;
  if ((f^.eof = 0) and (LongInt(e) <> VORBIS_need_more_data)) then
  begin
    f^.error := e;
  end;
  Result := 0;
end;

function make_block_array(mem: Pointer; count: LongInt; size: LongInt): Pointer; inline;
label _L__for0_step;
var
  i_2: LongInt;
  p_2: PPointer;
  q: PAnsiChar;
begin
  p_2 := PPointer(mem);
  q := PAnsiChar((p_2 + count));
  i_2 := 0;
  while (i_2 < count) do
  begin
    p_2[i_2] := q;
    q := (q + size);
    _L__for0_step:
    i_2 := (i_2 + 1);
  end;
  Result := p_2;
end;

function setup_malloc(f: PVorb; __c2p_arg_sz: LongInt): Pointer; inline;
var
  p_2: Pointer;
  sz: LongInt;
  __c2p_tmp1: Pointer;
begin
  sz := __c2p_arg_sz;
  sz := ((sz + 7) and LongInt(not 7));
  f^.setup_memory_required := (f^.setup_memory_required + LongWord(sz));
  if (f^.alloc.alloc_buffer <> nil) then
  begin
    p_2 := (PAnsiChar(f^.alloc.alloc_buffer) + f^.setup_offset);
    if ((f^.setup_offset + sz) > f^.temp_offset) then
    begin
      Result := nil;
      System.Exit;
    end;
    f^.setup_offset := (f^.setup_offset + sz);
    Result := p_2;
    System.Exit;
  end;
  if (sz <> 0) then
  begin
    __c2p_tmp1 := Pointer(__c2p_mem_malloc(TSizeT(sz)));
  end
  else
  begin
    __c2p_tmp1 := nil;
  end;
  Result := __c2p_tmp1;
end;

procedure setup_free(f: PVorb; p_2: Pointer); inline;
begin
  if (f^.alloc.alloc_buffer <> nil) then
  begin
    System.Exit;
  end;
  __c2p_mem_free(p_2);
end;

function setup_temp_malloc(f: PVorb; __c2p_arg_sz: LongInt): Pointer; inline;
var
  sz: LongInt;
begin
  sz := __c2p_arg_sz;
  sz := ((sz + 7) and LongInt(not 7));
  if (f^.alloc.alloc_buffer <> nil) then
  begin
    if ((f^.temp_offset - sz) < f^.setup_offset) then
    begin
      Result := nil;
      System.Exit;
    end;
    f^.temp_offset := (f^.temp_offset - sz);
    Result := (PAnsiChar(f^.alloc.alloc_buffer) + f^.temp_offset);
    System.Exit;
  end;
  Result := Pointer(__c2p_mem_malloc(TSizeT(sz)));
end;

procedure setup_temp_free(f: PVorb; p_2: Pointer; sz: LongInt); inline;
begin
  if (f^.alloc.alloc_buffer <> nil) then
  begin
    f^.temp_offset := (f^.temp_offset + ((sz + 7) and LongInt(not 7)));
    System.Exit;
  end;
  __c2p_mem_free(p_2);
end;

procedure crc32_init(); inline;
label _L__for0_step, _L__for1_step;
var
  i_2: LongInt;
  j: LongInt;
  s_2: TUint32;
  __c2p_tmp1: LongInt;
begin
  i_2 := 0;
  while (i_2 < 256) do
  begin
    s_2 := (TUint32(i_2) shl 24);
    j := 0;
    while (j < 8) do
    begin
      if (s_2 >= (1 shl 31)) then
      begin
        __c2p_tmp1 := 79764919;
      end
      else
      begin
        __c2p_tmp1 := 0;
      end;
      s_2 := ((s_2 shl 1) xor LongWord(__c2p_tmp1));
      _L__for1_step:
      j := (j + 1);
    end;
    crc_table[i_2] := s_2;
    _L__for0_step:
    i_2 := (i_2 + 1);
  end;
end;

function crc32_update(crc_2: TUint32; byte_: TUint8): TUint32; inline;
begin
  Result := ((crc_2 shl 8) xor crc_table[(LongWord(LongInt(byte_)) xor (crc_2 shr 24))]);
end;

function bit_reverse(__c2p_arg_n_2: LongWord): LongWord; inline;
var
  n_2: LongWord;
begin
  n_2 := __c2p_arg_n_2;
  n_2 := (((n_2 and LongWord(2863311530)) shr 1) or ((n_2 and LongWord(1431655765)) shl 1));
  n_2 := (((n_2 and LongWord(3435973836)) shr 2) or ((n_2 and LongWord(858993459)) shl 2));
  n_2 := (((n_2 and LongWord(4042322160)) shr 4) or ((n_2 and LongWord(252645135)) shl 4));
  n_2 := (((n_2 and LongWord(4278255360)) shr 8) or ((n_2 and LongWord(16711935)) shl 8));
  Result := ((n_2 shr 16) or (n_2 shl 16));
end;

function square(x_2: Single): Single;
begin
  Result := (x_2 * x_2);
end;

function ilog(n_2: TInt32): LongInt; inline;
begin
  if (n_2 < 0) then
  begin
    Result := 0;
    System.Exit;
  end;
  if (n_2 < (1 shl 14)) then
  begin
    if (n_2 < (1 shl 4)) then
    begin
      Result := (0 + LongInt(ShortInt(_static_ilog_log2_4[n_2])));
      System.Exit;
    end
    else
    begin
      if (n_2 < (1 shl 9)) then
      begin
        Result := (5 + LongInt(ShortInt(_static_ilog_log2_4[(n_2 shr 5)])));
        System.Exit;
      end
      else
      begin
        Result := (10 + LongInt(ShortInt(_static_ilog_log2_4[(n_2 shr 10)])));
        System.Exit;
      end;
    end;
  end
  else
  begin
    if (n_2 < (1 shl 24)) then
    begin
      if (n_2 < (1 shl 19)) then
      begin
        Result := (15 + LongInt(ShortInt(_static_ilog_log2_4[(n_2 shr 15)])));
        System.Exit;
      end
      else
      begin
        Result := (20 + LongInt(ShortInt(_static_ilog_log2_4[(n_2 shr 20)])));
        System.Exit;
      end;
    end
    else
    begin
      if (n_2 < (1 shl 29)) then
      begin
        Result := (25 + LongInt(ShortInt(_static_ilog_log2_4[(n_2 shr 25)])));
        System.Exit;
      end
      else
      begin
        Result := (30 + LongInt(ShortInt(_static_ilog_log2_4[(n_2 shr 30)])));
        System.Exit;
      end;
    end;
  end;
end;

function float32_unpack(x_2: TUint32): Single; inline;
var
  mantissa_2: TUint32;
  sign_2: TUint32;
  exp_2: TUint32;
  res_2: Double;
  __c2p_tmp1: Double;
begin
  mantissa_2 := (x_2 and LongWord(2097151));
  sign_2 := (x_2 and LongWord(2147483648));
  exp_2 := ((x_2 and LongWord(2145386496)) shr 21);
  if (sign_2 <> 0) then
  begin
    __c2p_tmp1 := -Double(mantissa_2);
  end
  else
  begin
    __c2p_tmp1 := Double(mantissa_2);
  end;
  res_2 := __c2p_tmp1;
  Result := Single(ldexp(Single(res_2), (LongInt(exp_2) - 788)));
end;

procedure add_entry(c: PCodebook; huff_code: TUint32; symbol: LongInt; count: LongInt; len_2: LongInt; values: PUint32); inline;
begin
  if (LongInt(c^.sparse) = 0) then
  begin
    c^.codewords[symbol] := huff_code;
  end
  else
  begin
    c^.codewords[count] := huff_code;
    c^.codeword_lengths[count] := TUint8(len_2);
    values[count] := TUint32(symbol);
  end;
end;

function compute_codewords(c: PCodebook; len_2: PUint8; n_2: LongInt; values: PUint32): LongInt; inline;
label _L__for0_step, _L__for1_step, _L__for2_step, _L__for3_step;
var
  i_2: LongInt;
  k: LongInt;
  m: LongInt;
  available: array[0..31] of TUint32;
  res_2: TUint32;
  z_2: LongInt;
  y_2: LongInt;
  __c2p_tmp1: LongInt;
  __c2p_tmp2: LongInt;
begin
  m := 0;
  __c2p_stdlib_memset(Pointer(@available[0]), 0, TSizeT(128));
  k := 0;
  while (k < n_2) do
  begin
    if (len_2[k] < 255) then
    begin
      Break;
    end;
    _L__for0_step:
    k := (k + 1);
  end;
  if (k = n_2) then
  begin
    Result := 1;
    System.Exit;
  end;
  __c2p_tmp1 := m;
  m := (m + 1);
  add_entry(c, TUint32(0), k, __c2p_tmp1, LongInt(len_2[k]), values);
  i_2 := 1;
  while (i_2 <= len_2[k]) do
  begin
    available[i_2] := (1 shl (32 - i_2));
    _L__for1_step:
    i_2 := (i_2 + 1);
  end;
  i_2 := (k + 1);
  while (i_2 < n_2) do
  begin
    z_2 := LongInt(len_2[i_2]);
    if (z_2 = 255) then
    begin
      goto _L__for2_step;
    end;
    while ((z_2 > 0) and (available[z_2] = 0)) do
    begin
      z_2 := (z_2 - 1);
    end;
    if (z_2 = 0) then
    begin
      Result := 0;
      System.Exit;
    end;
    res_2 := available[z_2];
    available[z_2] := TUint32(0);
    __c2p_tmp2 := m;
    m := (m + 1);
    add_entry(c, TUint32(bit_reverse(res_2)), i_2, __c2p_tmp2, LongInt(len_2[i_2]), values);
    if (z_2 <> len_2[i_2]) then
    begin
      y_2 := LongInt(len_2[i_2]);
      while (y_2 > z_2) do
      begin
        available[y_2] := LongWord((res_2 + (1 shl (32 - y_2))));
        _L__for3_step:
        y_2 := (y_2 - 1);
      end;
    end;
    _L__for2_step:
    i_2 := (i_2 + 1);
  end;
  Result := 1;
end;

procedure compute_accelerated_huffman(c: PCodebook); inline;
label _L__for0_step, _L__for1_step;
var
  i_2: LongInt;
  len_2: LongInt;
  z_2: TUint32;
  __c2p_tmp1: LongInt;
  __c2p_tmp2: LongWord;
begin
  i_2 := 0;
  while (i_2 < (1 shl 10)) do
  begin
    c^.fast_huffman[i_2] := TInt16(-1);
    _L__for0_step:
    i_2 := (i_2 + 1);
  end;
  if (LongInt(c^.sparse) <> 0) then
  begin
    __c2p_tmp1 := c^.sorted_entries;
  end
  else
  begin
    __c2p_tmp1 := c^.entries;
  end;
  len_2 := __c2p_tmp1;
  if (len_2 > 32767) then
  begin
    len_2 := 32767;
  end;
  i_2 := 0;
  while (i_2 < len_2) do
  begin
    if (c^.codeword_lengths[i_2] <= 10) then
    begin
      if (LongInt(c^.sparse) <> 0) then
      begin
        __c2p_tmp2 := bit_reverse(c^.sorted_codewords[i_2]);
      end
      else
      begin
        __c2p_tmp2 := c^.codewords[i_2];
      end;
      z_2 := __c2p_tmp2;
      while (z_2 < LongWord((1 shl 10))) do
      begin
        c^.fast_huffman[z_2] := TInt16(i_2);
        z_2 := (z_2 + LongWord((1 shl LongInt(c^.codeword_lengths[i_2]))));
      end;
    end;
    _L__for1_step:
    i_2 := (i_2 + 1);
  end;
end;

function uint32_compare(p_2: Pointer; q: Pointer): LongInt; cdecl; inline;
var
  x_2: TUint32;
  y_2: TUint32;
  __c2p_tmp1: LongInt;
begin
  x_2 := PUint32(p_2)^;
  y_2 := PUint32(q)^;
  if (x_2 < y_2) then
  begin
    __c2p_tmp1 := -1;
  end
  else
  begin
    __c2p_tmp1 := LongInt((x_2 > y_2));
  end;
  Result := __c2p_tmp1;
end;

function include_in_sort(c: PCodebook; len_2: TUint8): LongInt; inline;
begin
  if (LongInt(c^.sparse) <> 0) then
  begin
    Result := 1;
    System.Exit;
  end;
  if (len_2 = 255) then
  begin
    Result := 0;
    System.Exit;
  end;
  if (len_2 > 10) then
  begin
    Result := 1;
    System.Exit;
  end;
  Result := 0;
end;

procedure compute_sorted_huffman(c: PCodebook; lengths: PUint8; values: PUint32); inline;
label _L__for0_step, _L__for1_step, _L__for2_step;
var
  i_2: LongInt;
  len_2: LongInt;
  k: LongInt;
  huff_len: LongInt;
  code_2: TUint32;
  x_2: LongInt;
  n_2: LongInt;
  m: LongInt;
  __c2p_tmp2: LongInt;
  __c2p_tmp1: LongInt;
  __c2p_tmp3: LongInt;
begin
  if (LongInt(c^.sparse) = 0) then
  begin
    k := 0;
    i_2 := 0;
    while (i_2 < c^.entries) do
    begin
      if (include_in_sort(c, TUint8(lengths[i_2])) <> 0) then
      begin
        __c2p_tmp1 := k;
        k := (k + 1);
        c^.sorted_codewords[__c2p_tmp1] := bit_reverse(c^.codewords[i_2]);
      end;
      _L__for0_step:
      i_2 := (i_2 + 1);
    end;
  end
  else
  begin
    i_2 := 0;
    while (i_2 < c^.sorted_entries) do
    begin
      c^.sorted_codewords[i_2] := bit_reverse(c^.codewords[i_2]);
      _L__for1_step:
      i_2 := (i_2 + 1);
    end;
  end;
  qsort(c^.sorted_codewords, TSizeT(c^.sorted_entries), TSizeT(4), TRawProc9779B54A(Pointer(@uint32_compare)));
  c^.sorted_codewords[c^.sorted_entries] := TUint32(4294967295);
  if (LongInt(c^.sparse) <> 0) then
  begin
    __c2p_tmp2 := c^.sorted_entries;
  end
  else
  begin
    __c2p_tmp2 := c^.entries;
  end;
  len_2 := __c2p_tmp2;
  i_2 := 0;
  while (i_2 < len_2) do
  begin
    if (LongInt(c^.sparse) <> 0) then
    begin
      __c2p_tmp3 := LongInt(lengths[values[i_2]]);
    end
    else
    begin
      __c2p_tmp3 := LongInt(lengths[i_2]);
    end;
    huff_len := __c2p_tmp3;
    if (include_in_sort(c, TUint8(huff_len)) <> 0) then
    begin
      code_2 := bit_reverse(c^.codewords[i_2]);
      x_2 := 0;
      n_2 := c^.sorted_entries;
      while (n_2 > 1) do
      begin
        m := (x_2 + __c2p_sar_longint(n_2, 1));
        if (c^.sorted_codewords[m] <= code_2) then
        begin
          x_2 := m;
          n_2 := (n_2 - __c2p_sar_longint(n_2, 1));
        end
        else
        begin
          n_2 := __c2p_sar_longint(n_2, 1);
        end;
      end;
      if (LongInt(c^.sparse) <> 0) then
      begin
        c^.sorted_values[x_2] := LongInt(values[i_2]);
        c^.codeword_lengths[x_2] := TUint8(huff_len);
      end
      else
      begin
        c^.sorted_values[x_2] := i_2;
      end;
    end;
    _L__for2_step:
    i_2 := (i_2 + 1);
  end;
end;

function vorbis_validate(data: PUint8): LongInt; inline;
begin
  Result := LongInt((__c2p_stdlib_memcmp(data, Pointer(@_static_vorbis_validate_vorbis[0]), TSizeT(6)) = 0));
end;

function lookup1_values(entries: LongInt; dim: LongInt): LongInt; inline;
var
  r: LongInt;
begin
  r := LongInt(Trunc(__c2p_stdlib_floor(__c2p_math_exp((Single(__c2p_math_log(Single(entries))) / dim)))));
  if (LongInt(Trunc(__c2p_stdlib_floor(__c2p_math_pow((Single(r) + 1), dim)))) <= entries) then
  begin
    r := (r + 1);
  end;
  if (__c2p_math_pow((Single(r) + 1), dim) <= entries) then
  begin
    Result := -1;
    System.Exit;
  end;
  if (LongInt(Trunc(__c2p_stdlib_floor(__c2p_math_pow(Single(r), dim)))) > entries) then
  begin
    Result := -1;
    System.Exit;
  end;
  Result := r;
end;

procedure compute_twiddle_factors(n_2: LongInt; A: PSingle; B: PSingle; C: PSingle);
label _L__for0_step, _L__for1_step;
var
  n4: LongInt;
  n8: LongInt;
  k: LongInt;
  k2: LongInt;
  __c2p_tmp1: LongInt;
  __c2p_tmp2: LongInt;
begin
  n4 := __c2p_sar_longint(n_2, 2);
  n8 := __c2p_sar_longint(n_2, 3);
  __c2p_tmp1 := 0;
  k2 := __c2p_tmp1;
  k := __c2p_tmp1;
  while (k < n4) do
  begin
    A[k2] := Single(__c2p_math_cos((((4 * k) * Single(3.14159265358979323846264)) / n_2)));
    A[(k2 + 1)] := Single(-__c2p_math_sin((((4 * k) * Single(3.14159265358979323846264)) / n_2)));
    B[k2] := (Single(__c2p_math_cos(((((k2 + 1) * Single(3.14159265358979323846264)) / n_2) / 2))) * Single(0.5));
    B[(k2 + 1)] := (Single(__c2p_math_sin(((((k2 + 1) * Single(3.14159265358979323846264)) / n_2) / 2))) * Single(0.5));
    _L__for0_step:
    k := (k + 1);
    k2 := (k2 + 2);
  end;
  __c2p_tmp2 := 0;
  k2 := __c2p_tmp2;
  k := __c2p_tmp2;
  while (k < n8) do
  begin
    C[k2] := Single(__c2p_math_cos((((2 * (k2 + 1)) * Single(3.14159265358979323846264)) / n_2)));
    C[(k2 + 1)] := Single(-__c2p_math_sin((((2 * (k2 + 1)) * Single(3.14159265358979323846264)) / n_2)));
    _L__for1_step:
    k := (k + 1);
    k2 := (k2 + 2);
  end;
end;

procedure compute_window(n_2: LongInt; window: PSingle); inline;
label _L__for0_step;
var
  n2: LongInt;
  i_2: LongInt;
begin
  n2 := __c2p_sar_longint(n_2, 1);
  i_2 := 0;
  while (i_2 < n2) do
  begin
    { 位精确：C 端 M_PI 是 float 常量，参与运算取其 double 展宽值；每步显式
      钉扎 Double，避免扩展精度中间值造成对 gcc -O2 参考的 ±1LSB 窗表偏差 }
    window[i_2] := Single(__c2p_math_sin((0.5 * Double(Single(3.14159265358979323846264))) * Double(square(Single(__c2p_math_sin((((Double(i_2 - 0) + 0.5) / n2) * 0.5) * Double(Single(3.14159265358979323846264))))))));
    _L__for0_step:
    i_2 := (i_2 + 1);
  end;
end;

procedure compute_bitreverse(n_2: LongInt; rev: PUint16); inline;
label _L__for0_step;
var
  ld: LongInt;
  i_2: LongInt;
  n8: LongInt;
begin
  ld := (ilog(TInt32(n_2)) - 1);
  n8 := __c2p_sar_longint(n_2, 3);
  i_2 := 0;
  while (i_2 < n8) do
  begin
    rev[i_2] := TUint16(((bit_reverse(LongWord(i_2)) shr ((32 - ld) + 3)) shl 2));
    _L__for0_step:
    i_2 := (i_2 + 1);
  end;
end;

function init_blocksize(f: PVorb; b: LongInt; n_2: LongInt): LongInt; inline;
var
  n2: LongInt;
  n4: LongInt;
  n8: LongInt;
begin
  n2 := __c2p_sar_longint(n_2, 1);
  n4 := __c2p_sar_longint(n_2, 2);
  n8 := __c2p_sar_longint(n_2, 3);
  f^.A[b] := PSingle(setup_malloc(f, LongInt(QWord((4 * QWord(n2))))));
  f^.B[b] := PSingle(setup_malloc(f, LongInt(QWord((4 * QWord(n2))))));
  f^.C[b] := PSingle(setup_malloc(f, LongInt(QWord((4 * QWord(n4))))));
  if (((f^.A[b] = nil) or (f^.B[b] = nil)) or (f^.C[b] = nil)) then
  begin
    Result := error(f, VORBIS_outofmem);
    System.Exit;
  end;
  compute_twiddle_factors(n_2, f^.A[b], f^.B[b], f^.C[b]);
  f^.window[b] := PSingle(setup_malloc(f, LongInt(QWord((4 * QWord(n2))))));
  if (f^.window[b] = nil) then
  begin
    Result := error(f, VORBIS_outofmem);
    System.Exit;
  end;
  compute_window(n_2, f^.window[b]);
  f^.bit_reverse[b] := PUint16(setup_malloc(f, LongInt(QWord((2 * QWord(n8))))));
  if (f^.bit_reverse[b] = nil) then
  begin
    Result := error(f, VORBIS_outofmem);
    System.Exit;
  end;
  compute_bitreverse(n_2, f^.bit_reverse[b]);
  Result := 1;
end;

procedure neighbors(x_2: PUint16; n_2: LongInt; plow: PLongInt; phigh: PLongInt); inline;
label _L__for0_step;
var
  low: LongInt;
  high: LongInt;
  i_2: LongInt;
begin
  low := -1;
  high := 65536;
  i_2 := 0;
  while (i_2 < n_2) do
  begin
    if ((x_2[i_2] > low) and (x_2[i_2] < x_2[n_2])) then
    begin
      plow^ := i_2;
      low := LongInt(x_2[i_2]);
    end;
    if ((x_2[i_2] < high) and (x_2[i_2] > x_2[n_2])) then
    begin
      phigh^ := i_2;
      high := LongInt(x_2[i_2]);
    end;
    _L__for0_step:
    i_2 := (i_2 + 1);
  end;
end;

function point_compare(p_2: Pointer; q: Pointer): LongInt; cdecl; inline;
var
  a: PStbvXFloorOrdering;
  b: PStbvXFloorOrdering;
  __c2p_tmp1: LongInt;
begin
  a := PStbvXFloorOrdering(p_2);
  b := PStbvXFloorOrdering(q);
  if (a^.x < b^.x) then
  begin
    __c2p_tmp1 := -1;
  end
  else
  begin
    __c2p_tmp1 := LongInt((a^.x > b^.x));
  end;
  Result := __c2p_tmp1;
end;

function get8(z_2: PVorb): TUint8; inline;
var
  c: LongInt;
  __c2p_tmp1: PUint8;
begin
  if (z_2^.stream <> nil) then
  begin
    if (z_2^.stream >= z_2^.stream_end) then
    begin
      z_2^.eof := 1;
      Result := TUint8(0);
      System.Exit;
    end;
    __c2p_tmp1 := z_2^.stream;
    z_2^.stream := (z_2^.stream + 1);
    Result := TUint8(__c2p_tmp1^);
    System.Exit;
  end;
  c := fgetc(z_2^.f);
  if (c = -1) then
  begin
    z_2^.eof := 1;
    Result := TUint8(0);
    System.Exit;
  end;
  Result := TUint8(c);
end;

function get32(f: PVorb): TUint32; inline;
var
  x_2: TUint32;
begin
  x_2 := TUint32(get8(f));
  x_2 := (x_2 + LongWord((LongInt(get8(f)) shl 8)));
  x_2 := (x_2 + LongWord((LongInt(get8(f)) shl 16)));
  x_2 := (x_2 + (TUint32(get8(f)) shl 24));
  Result := x_2;
end;

function getn(z_2: PVorb; data: PUint8; n_2: LongInt): LongInt; inline;
begin
  if (z_2^.stream <> nil) then
  begin
    if ((z_2^.stream + n_2) > z_2^.stream_end) then
    begin
      z_2^.eof := 1;
      Result := 0;
      System.Exit;
    end;
    __c2p_stdlib_memcpy(data, z_2^.stream, TSizeT(n_2));
    z_2^.stream := (z_2^.stream + n_2);
    Result := 1;
    System.Exit;
  end;
  if (fread(data, TSizeT(n_2), TSizeT(1), z_2^.f) = QWord(1)) then
  begin
    Result := 1;
    System.Exit;
  end
  else
  begin
    z_2^.eof := 1;
    Result := 0;
    System.Exit;
  end;
end;

procedure skip(z_2: PVorb; n_2: LongInt); inline;
var
  x_2: Int64;
begin
  if (z_2^.stream <> nil) then
  begin
    z_2^.stream := (z_2^.stream + n_2);
    if (z_2^.stream >= z_2^.stream_end) then
    begin
      z_2^.eof := 1;
    end;
    System.Exit;
  end;
  x_2 := ftell(z_2^.f);
  fseek(z_2^.f, (x_2 + Int64(n_2)), 0);
end;

function set_file_offset(f: PStbVorbis; __c2p_arg_loc: LongWord): LongInt; inline;
var
  loc: LongWord;
begin
  loc := __c2p_arg_loc;
  if (LongInt(f^.push_mode) <> 0) then
  begin
    Result := 0;
    System.Exit;
  end;
  f^.eof := 0;
  if (f^.stream <> nil) then
  begin
    if (((f^.stream_start + loc) >= f^.stream_end) or ((f^.stream_start + loc) < f^.stream_start)) then
    begin
      f^.stream := f^.stream_end;
      f^.eof := 1;
      Result := 0;
      System.Exit;
    end
    else
    begin
      f^.stream := (f^.stream_start + loc);
      Result := 1;
      System.Exit;
    end;
  end;
  if ((LongWord((loc + f^.f_start)) < loc) or (loc >= LongWord(2147483648))) then
  begin
    loc := LongWord(2147483647);
    f^.eof := 1;
  end
  else
  begin
    loc := (loc + f^.f_start);
  end;
  if (fseek(f^.f, Int64(loc), 0) = 0) then
  begin
    Result := 1;
    System.Exit;
  end;
  f^.eof := 1;
  fseek(f^.f, Int64(f^.f_start), 2);
  Result := 0;
end;

function capture_pattern(f: PVorb): LongInt; inline;
begin
  if (79 <> get8(f)) then
  begin
    Result := 0;
    System.Exit;
  end;
  if (103 <> get8(f)) then
  begin
    Result := 0;
    System.Exit;
  end;
  if (103 <> get8(f)) then
  begin
    Result := 0;
    System.Exit;
  end;
  if (83 <> get8(f)) then
  begin
    Result := 0;
    System.Exit;
  end;
  Result := 1;
end;

function start_page_no_capturepattern(f: PVorb): LongInt; inline;
label _L__for0_step, _L__for1_step;
var
  loc0_2: TUint32;
  loc1_2: TUint32;
  n_2: TUint32;
  i_2: LongInt;
  i_3: LongInt;
  len_2: LongInt;
begin
  if ((LongInt(f^.first_decode) <> 0) and (LongInt(f^.push_mode) = 0)) then
  begin
    f^.p_first.page_start := LongWord((stb_vorbis_get_file_offset(f) - LongWord(4)));
  end;
  if (0 <> get8(f)) then
  begin
    Result := error(f, VORBIS_invalid_stream_structure_version);
    System.Exit;
  end;
  f^.page_flag := TUint8(get8(f));
  loc0_2 := get32(f);
  loc1_2 := get32(f);
  get32(f);
  n_2 := get32(f);
  f^.last_page := LongInt(n_2);
  get32(f);
  f^.segment_count := LongInt(get8(f));
  if (getn(f, PUint8(@f^.segments[0]), f^.segment_count) = 0) then
  begin
    Result := error(f, VORBIS_unexpected_eof);
    System.Exit;
  end;
  f^.end_seg_with_known_loc := -2;
  if ((loc0_2 <> LongWord(not 0)) or (loc1_2 <> LongWord(not 0))) then
  begin
    i_2 := (f^.segment_count - 1);
    while (i_2 >= 0) do
    begin
      if (f^.segments[i_2] < 255) then
      begin
        Break;
      end;
      _L__for0_step:
      i_2 := (i_2 - 1);
    end;
    if (i_2 >= 0) then
    begin
      f^.end_seg_with_known_loc := i_2;
      f^.known_loc_for_packet := loc0_2;
    end;
  end;
  if (LongInt(f^.first_decode) <> 0) then
  begin
    len_2 := 0;
    i_3 := 0;
    while (i_3 < f^.segment_count) do
    begin
      len_2 := (len_2 + f^.segments[i_3]);
      _L__for1_step:
      i_3 := (i_3 + 1);
    end;
    len_2 := (len_2 + (27 + f^.segment_count));
    f^.p_first.page_end := LongWord((f^.p_first.page_start + len_2));
    f^.p_first.last_decoded_sample := loc0_2;
  end;
  f^.next_seg := 0;
  Result := 1;
end;

function start_page(f: PVorb): LongInt; inline;
begin
  if (capture_pattern(f) = 0) then
  begin
    Result := error(f, VORBIS_missing_capture_pattern);
    System.Exit;
  end;
  Result := start_page_no_capturepattern(f);
end;

function start_packet(f: PVorb): LongInt; inline;
begin
  while (f^.next_seg = -1) do
  begin
    if (start_page(f) = 0) then
    begin
      Result := 0;
      System.Exit;
    end;
    if ((LongInt(f^.page_flag) and 1) <> 0) then
    begin
      Result := error(f, VORBIS_continued_packet_flag_invalid);
      System.Exit;
    end;
  end;
  f^.last_seg := 0;
  f^.valid_bits := 0;
  f^.packet_bytes := 0;
  f^.bytes_in_seg := TUint8(0);
  Result := 1;
end;

function maybe_start_packet(f: PVorb): LongInt; inline;
var
  x_2: LongInt;
begin
  if (f^.next_seg = -1) then
  begin
    x_2 := LongInt(get8(f));
    if (f^.eof <> 0) then
    begin
      Result := 0;
      System.Exit;
    end;
    if (79 <> x_2) then
    begin
      Result := error(f, VORBIS_missing_capture_pattern);
      System.Exit;
    end;
    if (103 <> get8(f)) then
    begin
      Result := error(f, VORBIS_missing_capture_pattern);
      System.Exit;
    end;
    if (103 <> get8(f)) then
    begin
      Result := error(f, VORBIS_missing_capture_pattern);
      System.Exit;
    end;
    if (83 <> get8(f)) then
    begin
      Result := error(f, VORBIS_missing_capture_pattern);
      System.Exit;
    end;
    if (start_page_no_capturepattern(f) = 0) then
    begin
      Result := 0;
      System.Exit;
    end;
    if ((LongInt(f^.page_flag) and 1) <> 0) then
    begin
      f^.last_seg := 0;
      f^.bytes_in_seg := TUint8(0);
      Result := error(f, VORBIS_continued_packet_flag_invalid);
      System.Exit;
    end;
  end;
  Result := start_packet(f);
end;

function next_segment(f: PVorb): LongInt; inline;
var
  len_2: LongInt;
  __c2p_tmp1: LongInt;
begin
  if (f^.last_seg <> 0) then
  begin
    Result := 0;
    System.Exit;
  end;
  if (f^.next_seg = -1) then
  begin
    f^.last_seg_which := (f^.segment_count - 1);
    if (start_page(f) = 0) then
    begin
      f^.last_seg := 1;
      Result := 0;
      System.Exit;
    end;
    if ((LongInt(f^.page_flag) and 1) = 0) then
    begin
      Result := error(f, VORBIS_continued_packet_flag_invalid);
      System.Exit;
    end;
  end;
  __c2p_tmp1 := f^.next_seg;
  f^.next_seg := (f^.next_seg + 1);
  len_2 := LongInt(f^.segments[__c2p_tmp1]);
  if (len_2 < 255) then
  begin
    f^.last_seg := 1;
    f^.last_seg_which := (f^.next_seg - 1);
  end;
  if (f^.next_seg >= f^.segment_count) then
  begin
    f^.next_seg := -1;
  end;
  f^.bytes_in_seg := TUint8(len_2);
  Result := len_2;
end;

function get8_packet_raw(f: PVorb): LongInt; inline;
begin
  if (LongInt(f^.bytes_in_seg) = 0) then
  begin
    if (f^.last_seg <> 0) then
    begin
      Result := -1;
      System.Exit;
    end
    else
    begin
      if (next_segment(f) = 0) then
      begin
        Result := -1;
        System.Exit;
      end;
    end;
  end;
  f^.bytes_in_seg := TUint8((LongInt(f^.bytes_in_seg) - 1));
  f^.packet_bytes := (f^.packet_bytes + 1);
  Result := LongInt(get8(f));
end;

function get8_packet(f: PVorb): LongInt; inline;
var
  x_2: LongInt;
begin
  x_2 := get8_packet_raw(f);
  f^.valid_bits := 0;
  Result := x_2;
end;

function get32_packet(f: PVorb): LongInt; inline;
var
  x_2: TUint32;
begin
  x_2 := TUint32(get8_packet(f));
  x_2 := (x_2 + LongWord((get8_packet(f) shl 8)));
  x_2 := (x_2 + LongWord((get8_packet(f) shl 16)));
  x_2 := (x_2 + (TUint32(get8_packet(f)) shl 24));
  Result := x_2;
end;

procedure flush_packet(f: PVorb); inline;
begin
  while (get8_packet_raw(f) <> -1) do
  begin
  end;
end;

function get_bits(f: PVorb; n_2: LongInt): TUint32; inline;
var
  z_2: TUint32;
  z_3: LongInt;
begin
  if (f^.valid_bits < 0) then
  begin
    Result := 0;
    System.Exit;
  end;
  if (f^.valid_bits < n_2) then
  begin
    if (n_2 > 24) then
    begin
      z_2 := get_bits(f, 24);
      z_2 := (z_2 + (get_bits(f, (n_2 - 24)) shl 24));
      Result := z_2;
      System.Exit;
    end;
    if (f^.valid_bits = 0) then
    begin
      f^.acc := TUint32(0);
    end;
    while (f^.valid_bits < n_2) do
    begin
      z_3 := get8_packet_raw(f);
      if (z_3 = -1) then
      begin
        f^.valid_bits := -1;
        Result := 0;
        System.Exit;
      end;
      f^.acc := (f^.acc + LongWord((z_3 shl f^.valid_bits)));
      f^.valid_bits := (f^.valid_bits + 8);
    end;
  end;
  z_2 := (f^.acc and LongWord(((1 shl n_2) - 1)));
  f^.acc := (f^.acc shr n_2);
  f^.valid_bits := (f^.valid_bits - n_2);
  Result := z_2;
end;

procedure prep_huffman(f: PVorb); inline;
var
  z_2: LongInt;
begin
  if (f^.valid_bits <= 24) then
  begin
    if (f^.valid_bits = 0) then
    begin
      f^.acc := TUint32(0);
    end;
    repeat
      if ((f^.last_seg <> 0) and (LongInt(f^.bytes_in_seg) = 0)) then
      begin
        System.Exit;
      end;
      z_2 := get8_packet_raw(f);
      if (z_2 = -1) then
      begin
        System.Exit;
      end;
      f^.acc := (f^.acc + (LongWord(z_2) shl f^.valid_bits));
      f^.valid_bits := (f^.valid_bits + 8);
    until ((f^.valid_bits <= 24) = False);
  end;
end;

function codebook_decode_scalar_raw(f: PVorb; c: PCodebook): LongInt; inline;
label _L__for0_step;
var
  i_2: LongInt;
  code_2: TUint32;
  x_2: LongInt;
  n_2: LongInt;
  len_2: LongInt;
  m: LongInt;
  __c2p_tmp1: LongInt;
begin
  prep_huffman(f);
  if ((c^.codewords = nil) and (c^.sorted_codewords = nil)) then
  begin
    Result := -1;
    System.Exit;
  end;
  if (c^.entries > 8) then
  begin
    __c2p_tmp1 := LongInt((c^.sorted_codewords <> nil));
  end
  else
  begin
    __c2p_tmp1 := LongInt((c^.codewords = nil));
  end;
  if (__c2p_tmp1 <> 0) then
  begin
    code_2 := bit_reverse(f^.acc);
    x_2 := 0;
    n_2 := c^.sorted_entries;
    while (n_2 > 1) do
    begin
      m := (x_2 + __c2p_sar_longint(n_2, 1));
      if (c^.sorted_codewords[m] <= code_2) then
      begin
        x_2 := m;
        n_2 := (n_2 - __c2p_sar_longint(n_2, 1));
      end
      else
      begin
        n_2 := __c2p_sar_longint(n_2, 1);
      end;
    end;
    if (LongInt(c^.sparse) = 0) then
    begin
      x_2 := c^.sorted_values[x_2];
    end;
    len_2 := LongInt(c^.codeword_lengths[x_2]);
    if (f^.valid_bits >= len_2) then
    begin
      f^.acc := (f^.acc shr len_2);
      f^.valid_bits := (f^.valid_bits - len_2);
      Result := x_2;
      System.Exit;
    end;
    f^.valid_bits := 0;
    Result := -1;
    System.Exit;
  end;
  i_2 := 0;
  while (i_2 < c^.entries) do
  begin
    if (c^.codeword_lengths[i_2] = 255) then
    begin
      goto _L__for0_step;
    end;
    if (c^.codewords[i_2] = (f^.acc and LongWord(((1 shl LongInt(c^.codeword_lengths[i_2])) - 1)))) then
    begin
      if (f^.valid_bits >= c^.codeword_lengths[i_2]) then
      begin
        f^.acc := (f^.acc shr c^.codeword_lengths[i_2]);
        f^.valid_bits := (f^.valid_bits - c^.codeword_lengths[i_2]);
        Result := i_2;
        System.Exit;
      end;
      f^.valid_bits := 0;
      Result := -1;
      System.Exit;
    end;
    _L__for0_step:
    i_2 := (i_2 + 1);
  end;
  error(f, VORBIS_invalid_stream);
  f^.valid_bits := 0;
  Result := -1;
end;

function codebook_decode_start(f: PVorb; c: PCodebook): LongInt; inline;
var
  z_2: LongInt;
  n_2: LongInt;
begin
  z_2 := -1;
  if (c^.lookup_type = 0) then
  begin
    error(f, VORBIS_invalid_stream);
  end
  else
  begin
    if (f^.valid_bits < 10) then
    begin
      prep_huffman(f);
    end;
    z_2 := LongInt((f^.acc and LongWord(((1 shl 10) - 1))));
    z_2 := LongInt(c^.fast_huffman[z_2]);
    if (z_2 >= 0) then
    begin
      n_2 := LongInt(c^.codeword_lengths[z_2]);
      f^.acc := (f^.acc shr n_2);
      f^.valid_bits := (f^.valid_bits - n_2);
      if (f^.valid_bits < 0) then
      begin
        f^.valid_bits := 0;
        z_2 := -1;
      end;
    end
    else
    begin
      z_2 := codebook_decode_scalar_raw(f, c);
    end;
    if (LongInt(c^.sparse) <> 0) then
    begin
    end;
    if (z_2 < 0) then
    begin
      if (LongInt(f^.bytes_in_seg) = 0) then
      begin
        if (f^.last_seg <> 0) then
        begin
          Result := z_2;
          System.Exit;
        end;
      end;
      error(f, VORBIS_invalid_stream);
    end;
  end;
  Result := z_2;
end;

function codebook_decode(f: PVorb; c: PCodebook; output: PSingle; len_2: LongInt): LongInt;
label _L__for0_step, _L__for1_step;
var
  i_2: LongInt;
  z_2: LongInt;
  last: Single;
  val: Single;
  last_2: Single;
begin
  z_2 := codebook_decode_start(f, c);
  if (z_2 < 0) then
  begin
    Result := 0;
    System.Exit;
  end;
  if (len_2 > c^.dimensions) then
  begin
    len_2 := c^.dimensions;
  end;
  z_2 := (z_2 * c^.dimensions);
  if (LongInt(c^.sequence_p) <> 0) then
  begin
    last := 0;
    i_2 := 0;
    while (i_2 < len_2) do
    begin
      val := (c^.multiplicands[(z_2 + i_2)] + last);
      output[i_2] := (output[i_2] + val);
      last := (val + c^.minimum_value);
      _L__for0_step:
      i_2 := (i_2 + 1);
    end;
  end
  else
  begin
    last_2 := 0;
    i_2 := 0;
    while (i_2 < len_2) do
    begin
      output[i_2] := (output[i_2] + (c^.multiplicands[(z_2 + i_2)] + last_2));
      _L__for1_step:
      i_2 := (i_2 + 1);
    end;
  end;
  Result := 1;
end;

function codebook_decode_step(f: PVorb; c: PCodebook; output: PSingle; len_2: LongInt; step: LongInt): LongInt;
label _L__for0_step;
var
  i_2: LongInt;
  z_2: LongInt;
  last: Single;
  val: Single;
  __c2p_tmp1: LongInt;
begin
  z_2 := codebook_decode_start(f, c);
  last := 0;
  if (z_2 < 0) then
  begin
    Result := 0;
    System.Exit;
  end;
  if (len_2 > c^.dimensions) then
  begin
    len_2 := c^.dimensions;
  end;
  z_2 := (z_2 * c^.dimensions);
  i_2 := 0;
  while (i_2 < len_2) do
  begin
    val := (c^.multiplicands[(z_2 + i_2)] + last);
    __c2p_tmp1 := (i_2 * step);
    output[__c2p_tmp1] := (output[__c2p_tmp1] + val);
    if (LongInt(c^.sequence_p) <> 0) then
    begin
      last := val;
    end;
    _L__for0_step:
    i_2 := (i_2 + 1);
  end;
  Result := 1;
end;

function codebook_decode_deinterleave_repeat_impl(f: PVorb; c: PCodebook; outputs: PPSingle; ch: LongInt; c_inter_p: PLongInt; p_inter_p: PLongInt; len_2: LongInt; total_decode: LongInt): LongInt;
label _L__for0_step, _L__for1_step;
var
  c_inter: LongInt;
  p_inter: LongInt;
  i_2: LongInt;
  z_2: LongInt;
  effective: LongInt;
  last: Single;
  n_2: LongInt;
  val: Single;
  val_2: Single;
  __c2p_tmp2: LongInt;
  __c2p_tmp1: PSingle;
  __c2p_tmp4: LongInt;
  __c2p_tmp3: PSingle;
begin
  c_inter := c_inter_p^;
  p_inter := p_inter_p^;
  effective := c^.dimensions;
  if (c^.lookup_type = 0) then
  begin
    Result := error(f, VORBIS_invalid_stream);
    System.Exit;
  end;
  while (total_decode > 0) do
  begin
    last := 0;
    if (f^.valid_bits < 10) then
    begin
      prep_huffman(f);
    end;
    z_2 := LongInt((f^.acc and LongWord(((1 shl 10) - 1))));
    z_2 := LongInt(c^.fast_huffman[z_2]);
    if (z_2 >= 0) then
    begin
      n_2 := LongInt(c^.codeword_lengths[z_2]);
      f^.acc := (f^.acc shr n_2);
      f^.valid_bits := (f^.valid_bits - n_2);
      if (f^.valid_bits < 0) then
      begin
        f^.valid_bits := 0;
        z_2 := -1;
      end;
    end
    else
    begin
      z_2 := codebook_decode_scalar_raw(f, c);
    end;
    if (z_2 < 0) then
    begin
      if (LongInt(f^.bytes_in_seg) = 0) then
      begin
        if (f^.last_seg <> 0) then
        begin
          Result := 0;
          System.Exit;
        end;
      end;
      Result := error(f, VORBIS_invalid_stream);
      System.Exit;
    end;
    if (((c_inter + (p_inter * ch)) + effective) > (len_2 * ch)) then
    begin
      effective := ((len_2 * ch) - ((p_inter * ch) - c_inter));
    end;
    z_2 := (z_2 * c^.dimensions);
    if (LongInt(c^.sequence_p) <> 0) then
    begin
      i_2 := 0;
      while (i_2 < effective) do
      begin
        val := (c^.multiplicands[(z_2 + i_2)] + last);
        if (outputs[c_inter] <> nil) then
        begin
          __c2p_tmp1 := outputs[c_inter];
          __c2p_tmp1[p_inter] := (__c2p_tmp1[p_inter] + val);
        end;
        c_inter := (c_inter + 1);
        __c2p_tmp2 := c_inter;
        if (__c2p_tmp2 = ch) then
        begin
          c_inter := 0;
          p_inter := (p_inter + 1);
        end;
        last := val;
        _L__for0_step:
        i_2 := (i_2 + 1);
      end;
    end
    else
    begin
      i_2 := 0;
      while (i_2 < effective) do
      begin
        val_2 := (c^.multiplicands[(z_2 + i_2)] + last);
        if (outputs[c_inter] <> nil) then
        begin
          __c2p_tmp3 := outputs[c_inter];
          __c2p_tmp3[p_inter] := (__c2p_tmp3[p_inter] + val_2);
        end;
        c_inter := (c_inter + 1);
        __c2p_tmp4 := c_inter;
        if (__c2p_tmp4 = ch) then
        begin
          c_inter := 0;
          p_inter := (p_inter + 1);
        end;
        _L__for1_step:
        i_2 := (i_2 + 1);
      end;
    end;
    total_decode := (total_decode - effective);
  end;
  c_inter_p^ := c_inter;
  p_inter_p^ := p_inter;
  Result := 1;
end;

{ 手工优化段：ch=2 非 sequence_p 特化。虚拟交织坐标 pos=p*2+c 统一追踪，
  头单/成对/尾单三段展开；muls/o0/o1 缓存到局部供寄存器化。
  浮点仍逐元素与通用版同序同 op（含 +last，last 恒 0，保 -0.0 位语义）。}
function codebook_ddr_stereo(f: PVorb; c: PCodebook; outputs: PPSingle; c_inter_p: PLongInt; p_inter_p: PLongInt; len_2: LongInt; total_decode: LongInt): LongInt;
var
  c_inter: LongInt;
  p_inter: LongInt;
  i_2: LongInt;
  j: LongInt;
  z_2: LongInt;
  effective: LongInt;
  eff_orig: LongInt;
  pos: LongInt;
  muls: PSingle;
  o0: PSingle;
  o1: PSingle;
  {$ifdef C2P_SIMD}
  v_pairs: LongInt;
  {$endif}
  v_acc: LongWord;
  v_vb: LongInt;
  v_fh: ^TInt16;
  v_cw: PUint8;
  v_mul0: PCodetype;
  v_dims: LongInt;
  v_len2x2: LongInt;
begin
  c_inter := c_inter_p^;
  p_inter := p_inter_p^;
  o0 := outputs[0];
  o1 := outputs[1];
  { 热循环寄存器缓存：位读状态与 codebook 不可变字段各取一次，
    进入会读写它们的调用前后才与内存同步；pos 恒 ≥0（p_inter≥0 且 c_inter∈{0,1} 归纳），
    故 pos and 1 ≡ pos mod 2、pos shr 1 ≡ pos div 2 }
  v_fh := @c^.fast_huffman[0];
  v_cw := c^.codeword_lengths;
  v_mul0 := c^.multiplicands;
  v_dims := c^.dimensions;
  v_len2x2 := (len_2 * 2);
  v_acc := f^.acc;
  v_vb := f^.valid_bits;
  while (total_decode > 0) do
  begin
    if (v_vb < 10) then
    begin
      f^.acc := v_acc;
      f^.valid_bits := v_vb;
      prep_huffman(f);
      v_acc := f^.acc;
      v_vb := f^.valid_bits;
    end;
    z_2 := LongInt(v_fh[(v_acc and LongWord(((1 shl 10) - 1)))]);
    if (z_2 >= 0) then
    begin
      i_2 := LongInt(v_cw[z_2]);
      v_acc := (v_acc shr i_2);
      v_vb := (v_vb - i_2);
      if (v_vb < 0) then
      begin
        v_vb := 0;
        z_2 := -1;
      end;
    end
    else
    begin
      f^.acc := v_acc;
      f^.valid_bits := v_vb;
      z_2 := codebook_decode_scalar_raw(f, c);
      v_acc := f^.acc;
      v_vb := f^.valid_bits;
    end;
    if (z_2 < 0) then
    begin
      { 两处返回都会让调用方继续使用位读状态，先同步 }
      f^.acc := v_acc;
      f^.valid_bits := v_vb;
      if (LongInt(f^.bytes_in_seg) = 0) then
        if (f^.last_seg <> 0) then
        begin
          Result := 0;
          System.Exit;
        end;
      Result := error(f, VORBIS_invalid_stream);
      System.Exit;
    end;
    effective := v_dims;
    if ((c_inter + (p_inter * 2)) + effective) > v_len2x2 then
      effective := (v_len2x2 - ((p_inter * 2) - c_inter));
    eff_orig := effective;
    pos := (p_inter * 2) + c_inter;
    muls := @(v_mul0[(z_2 * v_dims)]);
    j := 0;
    { 常见情形先行：双通道均有效（音乐恒真），热循环零判空、行号/指针递增 }
    if (o0 <> nil) and (o1 <> nil) then
    begin
      if ((pos and 1) <> 0) and (effective > 0) then
      begin
        o1[pos shr 1] := (o1[pos shr 1] + muls[0]);
        pos := (pos + 1);
        j := (j + 1);
        effective := (effective - 1);
      end;
      {$ifdef C2P_SIMD}
      if use_cb_sse then
      begin
        { 内核按 4 对块 + 单个 2 对半块消费，恰好用尽向下取偶的对数 }
        v_pairs := ((effective shr 1) and not 1);
        if (v_pairs >= 2) then
        begin
          vdec_ddr_pair_add(@(o0[pos shr 1]), @(o1[pos shr 1]), @(muls[j]), v_pairs);
          pos := (pos + (v_pairs * 2));
          j := (j + (v_pairs * 2));
          effective := (effective - (v_pairs * 2));
        end;
      end;
      {$endif}
      while (effective >= 2) do
      begin
        o0[pos shr 1] := (o0[pos shr 1] + muls[j]);
        o1[pos shr 1] := (o1[pos shr 1] + muls[(j + 1)]);
        pos := (pos + 2);
        j := (j + 2);
        effective := (effective - 2);
      end;
      if (effective >= 1) then
      begin
        o0[pos shr 1] := (o0[pos shr 1] + muls[j]);
        pos := (pos + 1);
      end;
    end
    else
    begin
      if ((pos and 1) <> 0) and (effective > 0) then
      begin
        if (o1 <> nil) then
          o1[pos shr 1] := (o1[pos shr 1] + muls[j]);
        pos := (pos + 1);
        j := (j + 1);
        effective := (effective - 1);
      end;
      while (effective >= 2) do
      begin
        if (o0 <> nil) then
          o0[pos shr 1] := (o0[pos shr 1] + muls[j]);
        if (o1 <> nil) then
          o1[pos shr 1] := (o1[pos shr 1] + muls[(j + 1)]);
        pos := (pos + 2);
        j := (j + 2);
        effective := (effective - 2);
      end;
      if (effective >= 1) then
      begin
        if (o0 <> nil) then
          o0[pos shr 1] := (o0[pos shr 1] + muls[j]);
        pos := (pos + 1);
      end;
    end;
    c_inter := (pos and 1);
    p_inter := (pos shr 1);
    total_decode := (total_decode - eff_orig);
  end;
  f^.acc := v_acc;
  f^.valid_bits := v_vb;
  c_inter_p^ := c_inter;
  p_inter_p^ := p_inter;
  Result := 1;
end;

{ 分发：音乐语料绝大多数命中 ch=2 非 sequence_p 特化 }
function codebook_decode_deinterleave_repeat(f: PVorb; c: PCodebook; outputs: PPSingle; ch: LongInt; c_inter_p: PLongInt; p_inter_p: PLongInt; len_2: LongInt; total_decode: LongInt): LongInt;
begin
  if use_k4 and (ch = 2) and (c^.lookup_type <> 0) and (c^.sequence_p = 0) then
    Result := codebook_ddr_stereo(f, c, outputs, c_inter_p, p_inter_p, len_2, total_decode)
  else
    Result := codebook_decode_deinterleave_repeat_impl(f, c, outputs, ch, c_inter_p, p_inter_p, len_2, total_decode);
end;

function predict_point(x_2: LongInt; x0: LongInt; x1: LongInt; y0: LongInt; y1: LongInt): LongInt;
var
  dy: LongInt;
  adx: LongInt;
  err: LongInt;
  off: LongInt;
  __c2p_tmp1: LongInt;
begin
  dy := (y1 - y0);
  adx := (x1 - x0);
  err := (__c2p_stdlib_abs(dy) * (x_2 - x0));
  off := (err div adx);
  if (dy < 0) then
  begin
    __c2p_tmp1 := (y0 - off);
  end
  else
  begin
    __c2p_tmp1 := (y0 + off);
  end;
  Result := __c2p_tmp1;
end;

procedure draw_line(output: PSingle; x0: LongInt; y0: LongInt; __c2p_arg_x1: LongInt; y1: LongInt; n_2: LongInt); inline;
label _L__for0_step;
var
  dy: LongInt;
  adx: LongInt;
  ady: LongInt;
  base: LongInt;
  x_2: LongInt;
  y_2: LongInt;
  err: LongInt;
  sy: LongInt;
  x1: LongInt;
begin
  x1 := __c2p_arg_x1;
  dy := (y1 - y0);
  adx := (x1 - x0);
  ady := __c2p_stdlib_abs(dy);
  x_2 := x0;
  y_2 := y0;
  err := 0;
  base := (dy div adx);
  if (dy < 0) then
  begin
    sy := (base - 1);
  end
  else
  begin
    sy := (base + 1);
  end;
  ady := (ady - (__c2p_stdlib_abs(base) * adx));
  if (x1 > n_2) then
  begin
    x1 := n_2;
  end;
  if (x_2 < x1) then
  begin
    output[x_2] := (output[x_2] * inverse_db_table[(y_2 and 255)]);
    x_2 := (x_2 + 1);
    while (x_2 < x1) do
    begin
      err := (err + ady);
      if (err >= adx) then
      begin
        err := (err - adx);
        y_2 := (y_2 + sy);
      end
      else
      begin
        y_2 := (y_2 + base);
      end;
      output[x_2] := (output[x_2] * inverse_db_table[(y_2 and 255)]);
      _L__for0_step:
      x_2 := (x_2 + 1);
    end;
  end;
end;

function residue_decode(f: PVorb; book: PCodebook; target: PSingle; offset: LongInt; n_2: LongInt; rtype: LongInt): LongInt;
label _L__for0_step;
var
  k: LongInt;
  step: LongInt;
begin
  if (rtype = 0) then
  begin
    step := (n_2 div book^.dimensions);
    k := 0;
    while (k < step) do
    begin
      if (codebook_decode_step(f, book, ((target + offset) + k), ((n_2 - offset) - k), step) = 0) then
      begin
        Result := 0;
        System.Exit;
      end;
      _L__for0_step:
      k := (k + 1);
    end;
  end
  else
  begin
    k := 0;
    while (k < n_2) do
    begin
      if (codebook_decode(f, book, (target + offset), (n_2 - k)) = 0) then
      begin
        Result := 0;
        System.Exit;
      end;
      k := (k + book^.dimensions);
      offset := (offset + book^.dimensions);
    end;
  end;
  Result := 1;
end;

procedure decode_residue(f: PVorb; residue_buffers: PPSingle; ch: LongInt; n_2: LongInt; rn: LongInt; do_not_decode: PUint8);
label _L_done, _L__for0_step, _L__for1_step, _L__for2_step, _L__for3_step, _L__for4_step, _L__for5_step, _L__for6_step, _L__for7_step, _L__for8_step;
var
  i_2: LongInt;
  j: LongInt;
  pass: LongInt;
  r: PResidue;
  rtype: LongInt;
  c: LongInt;
  classwords: LongInt;
  actual_size: LongWord;
  limit_r_begin: LongWord;
  limit_r_end: LongWord;
  n_read: LongInt;
  part_read: LongInt;
  temp_alloc_point: LongInt;
  part_classdata: PPPUint8;
  pcount: LongInt;
  class_set: LongInt;
  z_2: LongInt;
  c_inter: LongInt;
  p_inter: LongInt;
  c_2: PCodebook;
  q: LongInt;
  n_3: LongInt;
  z_3: LongInt;
  c_3: LongInt;
  b: LongInt;
  book: PCodebook;
  z_4: LongInt;
  c_inter_2: LongInt;
  p_inter_2: LongInt;
  c_4: PCodebook;
  q_2: LongInt;
  n_4: LongInt;
  z_5: LongInt;
  c_5: LongInt;
  b_2: LongInt;
  book_2: PCodebook;
  pcount_2: LongInt;
  class_set_2: LongInt;
  c_6: PCodebook;
  temp_2: LongInt;
  n_5: LongInt;
  c_7: LongInt;
  b_3: LongInt;
  target: PSingle;
  offset: LongInt;
  n_6: LongInt;
  book_3: PCodebook;
  __c2p_tmp1: LongInt;
  __c2p_tmp2: LongWord;
  __c2p_tmp3: LongWord;
  __c2p_tmp4: Pointer;
begin
  r := (f^.residue_config + rn);
  rtype := LongInt(f^.residue_types[rn]);
  c := LongInt(r^.classbook);
  classwords := f^.codebooks[c].dimensions;
  if (rtype = 2) then
  begin
    __c2p_tmp1 := (n_2 * 2);
  end
  else
  begin
    __c2p_tmp1 := n_2;
  end;
  actual_size := LongWord(__c2p_tmp1);
  if (r^.&begin < actual_size) then
  begin
    __c2p_tmp2 := r^.&begin;
  end
  else
  begin
    __c2p_tmp2 := actual_size;
  end;
  limit_r_begin := __c2p_tmp2;
  if (r^.&end < actual_size) then
  begin
    __c2p_tmp3 := r^.&end;
  end
  else
  begin
    __c2p_tmp3 := actual_size;
  end;
  limit_r_end := __c2p_tmp3;
  n_read := LongInt(LongWord((limit_r_end - limit_r_begin)));
  part_read := LongInt((LongWord(n_read) div r^.part_size));
  temp_alloc_point := f^.temp_offset;
  if (f^.alloc.alloc_buffer <> nil) then
  begin
    __c2p_tmp4 := Pointer(setup_temp_malloc(f, LongInt(QWord((QWord(f^.channels) * (8 + QWord((QWord(part_read) * 8))))))));
  end
  else
  begin
    __c2p_tmp4 := vdec_frame_classdata(f^.channels, part_read);
  end;
  part_classdata := PPPUint8(make_block_array(__c2p_tmp4, f^.channels, LongInt(QWord((QWord(part_read) * 8)))));
  i_2 := 0;
  while (i_2 < ch) do
  begin
    if (LongInt(do_not_decode[i_2]) = 0) then
    begin
      __c2p_stdlib_memset(residue_buffers[i_2], 0, TSizeT(QWord((4 * QWord(n_2)))));
    end;
    _L__for0_step:
    i_2 := (i_2 + 1);
  end;
  if ((rtype = 2) and (ch <> 1)) then
  begin
    j := 0;
    while (j < ch) do
    begin
      if (LongInt(do_not_decode[j]) = 0) then
      begin
        Break;
      end;
      _L__for1_step:
      j := (j + 1);
    end;
    if (j = ch) then
    begin
      f^.temp_offset := temp_alloc_point;
      System.Exit;
    end;
    pass := 0;
    while (pass < 8) do
    begin
      pcount := 0;
      class_set := 0;
      if (ch = 2) then
      begin
        while (pcount < part_read) do
        begin
          z_2 := LongInt(LongWord((r^.&begin + LongWord((LongWord(pcount) * r^.part_size)))));
          c_inter := (z_2 and 1);
          p_inter := __c2p_sar_longint(z_2, 1);
          if (pass = 0) then
          begin
            c_2 := (f^.codebooks + LongInt(r^.classbook));
            if (f^.valid_bits < 10) then
            begin
              prep_huffman(f);
            end;
            q := LongInt((f^.acc and LongWord(((1 shl 10) - 1))));
            q := LongInt(c_2^.fast_huffman[q]);
            if (q >= 0) then
            begin
              n_3 := LongInt(c_2^.codeword_lengths[q]);
              f^.acc := (f^.acc shr n_3);
              f^.valid_bits := (f^.valid_bits - n_3);
              if (f^.valid_bits < 0) then
              begin
                f^.valid_bits := 0;
                q := -1;
              end;
            end
            else
            begin
              q := codebook_decode_scalar_raw(f, c_2);
            end;
            if (LongInt(c_2^.sparse) <> 0) then
            begin
              q := c_2^.sorted_values[q];
            end;
            if (q = -1) then
            begin
              f^.temp_offset := temp_alloc_point;
              System.Exit;
            end;
            part_classdata[0][class_set] := r^.classdata[q];
          end;
          i_2 := 0;
          while ((i_2 < classwords) and (pcount < part_read)) do
          begin
            z_3 := LongInt(LongWord((r^.&begin + LongWord((LongWord(pcount) * r^.part_size)))));
            c_3 := LongInt(part_classdata[0][class_set][i_2]);
            b := LongInt(r^.residue_books[c_3][pass]);
            if (b >= 0) then
            begin
              book := (f^.codebooks + b);
              if (codebook_decode_deinterleave_repeat(f, book, residue_buffers, ch, @c_inter, @p_inter, n_2, LongInt(r^.part_size)) = 0) then
              begin
                f^.temp_offset := temp_alloc_point;
                System.Exit;
              end;
            end
            else
            begin
              z_3 := LongInt((LongWord(z_3) + r^.part_size));
              c_inter := (z_3 and 1);
              p_inter := __c2p_sar_longint(z_3, 1);
            end;
            _L__for3_step:
            i_2 := (i_2 + 1);
            pcount := (pcount + 1);
          end;
          class_set := (class_set + 1);
        end;
      end
      else
      begin
        if (ch > 2) then
        begin
          while (pcount < part_read) do
          begin
            z_4 := LongInt(LongWord((r^.&begin + LongWord((LongWord(pcount) * r^.part_size)))));
            c_inter_2 := (z_4 mod ch);
            p_inter_2 := (z_4 div ch);
            if (pass = 0) then
            begin
              c_4 := (f^.codebooks + LongInt(r^.classbook));
              if (f^.valid_bits < 10) then
              begin
                prep_huffman(f);
              end;
              q_2 := LongInt((f^.acc and LongWord(((1 shl 10) - 1))));
              q_2 := LongInt(c_4^.fast_huffman[q_2]);
              if (q_2 >= 0) then
              begin
                n_4 := LongInt(c_4^.codeword_lengths[q_2]);
                f^.acc := (f^.acc shr n_4);
                f^.valid_bits := (f^.valid_bits - n_4);
                if (f^.valid_bits < 0) then
                begin
                  f^.valid_bits := 0;
                  q_2 := -1;
                end;
              end
              else
              begin
                q_2 := codebook_decode_scalar_raw(f, c_4);
              end;
              if (LongInt(c_4^.sparse) <> 0) then
              begin
                q_2 := c_4^.sorted_values[q_2];
              end;
              if (q_2 = -1) then
              begin
                f^.temp_offset := temp_alloc_point;
                System.Exit;
              end;
              part_classdata[0][class_set] := r^.classdata[q_2];
            end;
            i_2 := 0;
            while ((i_2 < classwords) and (pcount < part_read)) do
            begin
              z_5 := LongInt(LongWord((r^.&begin + LongWord((LongWord(pcount) * r^.part_size)))));
              c_5 := LongInt(part_classdata[0][class_set][i_2]);
              b_2 := LongInt(r^.residue_books[c_5][pass]);
              if (b_2 >= 0) then
              begin
                book_2 := (f^.codebooks + b_2);
                if (codebook_decode_deinterleave_repeat(f, book_2, residue_buffers, ch, @c_inter_2, @p_inter_2, n_2, LongInt(r^.part_size)) = 0) then
                begin
                  f^.temp_offset := temp_alloc_point;
                  System.Exit;
                end;
              end
              else
              begin
                z_5 := LongInt((LongWord(z_5) + r^.part_size));
                c_inter_2 := (z_5 mod ch);
                p_inter_2 := (z_5 div ch);
              end;
              _L__for4_step:
              i_2 := (i_2 + 1);
              pcount := (pcount + 1);
            end;
            class_set := (class_set + 1);
          end;
        end;
      end;
      _L__for2_step:
      pass := (pass + 1);
    end;
    f^.temp_offset := temp_alloc_point;
    System.Exit;
  end;
  pass := 0;
  while (pass < 8) do
  begin
    pcount_2 := 0;
    class_set_2 := 0;
    while (pcount_2 < part_read) do
    begin
      if (pass = 0) then
      begin
        j := 0;
        while (j < ch) do
        begin
          if (LongInt(do_not_decode[j]) = 0) then
          begin
            c_6 := (f^.codebooks + LongInt(r^.classbook));
            if (f^.valid_bits < 10) then
            begin
              prep_huffman(f);
            end;
            temp_2 := LongInt((f^.acc and LongWord(((1 shl 10) - 1))));
            temp_2 := LongInt(c_6^.fast_huffman[temp_2]);
            if (temp_2 >= 0) then
            begin
              n_5 := LongInt(c_6^.codeword_lengths[temp_2]);
              f^.acc := (f^.acc shr n_5);
              f^.valid_bits := (f^.valid_bits - n_5);
              if (f^.valid_bits < 0) then
              begin
                f^.valid_bits := 0;
                temp_2 := -1;
              end;
            end
            else
            begin
              temp_2 := codebook_decode_scalar_raw(f, c_6);
            end;
            if (LongInt(c_6^.sparse) <> 0) then
            begin
              temp_2 := c_6^.sorted_values[temp_2];
            end;
            if (temp_2 = -1) then
            begin
              f^.temp_offset := temp_alloc_point;
              System.Exit;
            end;
            part_classdata[j][class_set_2] := r^.classdata[temp_2];
          end;
          _L__for6_step:
          j := (j + 1);
        end;
      end;
      i_2 := 0;
      while ((i_2 < classwords) and (pcount_2 < part_read)) do
      begin
        j := 0;
        while (j < ch) do
        begin
          if (LongInt(do_not_decode[j]) = 0) then
          begin
            c_7 := LongInt(part_classdata[j][class_set_2][i_2]);
            b_3 := LongInt(r^.residue_books[c_7][pass]);
            if (b_3 >= 0) then
            begin
              target := residue_buffers[j];
              offset := LongInt(LongWord((r^.&begin + LongWord((LongWord(pcount_2) * r^.part_size)))));
              n_6 := LongInt(r^.part_size);
              book_3 := (f^.codebooks + b_3);
              if (residue_decode(f, book_3, target, offset, n_6, rtype) = 0) then
              begin
                f^.temp_offset := temp_alloc_point;
                System.Exit;
              end;
            end;
          end;
          _L__for8_step:
          j := (j + 1);
        end;
        _L__for7_step:
        i_2 := (i_2 + 1);
        pcount_2 := (pcount_2 + 1);
      end;
      class_set_2 := (class_set_2 + 1);
    end;
    _L__for5_step:
    pass := (pass + 1);
  end;
  _L_done:
  f^.temp_offset := temp_alloc_point;
end;

procedure imdct_step3_iter0_loop(n_2: LongInt; e: PSingle; i_off: LongInt; k_off: LongInt; A: PSingle);
label _L__for0_step;
var
  ee0: PSingle;
  ee2: PSingle;
  i_2: LongInt;
  k00_20: Single;
  k01_21: Single;
  __c2p_tmp1: LongInt;
  __c2p_tmp2: LongInt;
  __c2p_tmp3: LongInt;
  __c2p_tmp4: LongInt;
  __c2p_tmp5: LongInt;
  __c2p_tmp6: LongInt;
  __c2p_tmp7: LongInt;
begin
  ee0 := (e + i_off);
  ee2 := (ee0 + k_off);
  i_2 := __c2p_sar_longint(n_2, 2);
  while (i_2 > 0) do
  begin
    k00_20 := (ee0[0] - ee2[0]);
    k01_21 := (ee0[-1] - ee2[-1]);
    ee0[0] := (ee0[0] + ee2[0]);
    __c2p_tmp1 := -1;
    ee0[__c2p_tmp1] := (ee0[__c2p_tmp1] + ee2[-1]);
    ee2[0] := ((k00_20 * A[0]) - (k01_21 * A[1]));
    ee2[-1] := ((k01_21 * A[0]) + (k00_20 * A[1]));
    A := (A + 8);
    k00_20 := (ee0[-2] - ee2[-2]);
    k01_21 := (ee0[-3] - ee2[-3]);
    __c2p_tmp2 := -2;
    ee0[__c2p_tmp2] := (ee0[__c2p_tmp2] + ee2[-2]);
    __c2p_tmp3 := -3;
    ee0[__c2p_tmp3] := (ee0[__c2p_tmp3] + ee2[-3]);
    ee2[-2] := ((k00_20 * A[0]) - (k01_21 * A[1]));
    ee2[-3] := ((k01_21 * A[0]) + (k00_20 * A[1]));
    A := (A + 8);
    k00_20 := (ee0[-4] - ee2[-4]);
    k01_21 := (ee0[-5] - ee2[-5]);
    __c2p_tmp4 := -4;
    ee0[__c2p_tmp4] := (ee0[__c2p_tmp4] + ee2[-4]);
    __c2p_tmp5 := -5;
    ee0[__c2p_tmp5] := (ee0[__c2p_tmp5] + ee2[-5]);
    ee2[-4] := ((k00_20 * A[0]) - (k01_21 * A[1]));
    ee2[-5] := ((k01_21 * A[0]) + (k00_20 * A[1]));
    A := (A + 8);
    k00_20 := (ee0[-6] - ee2[-6]);
    k01_21 := (ee0[-7] - ee2[-7]);
    __c2p_tmp6 := -6;
    ee0[__c2p_tmp6] := (ee0[__c2p_tmp6] + ee2[-6]);
    __c2p_tmp7 := -7;
    ee0[__c2p_tmp7] := (ee0[__c2p_tmp7] + ee2[-7]);
    ee2[-6] := ((k00_20 * A[0]) - (k01_21 * A[1]));
    ee2[-7] := ((k01_21 * A[0]) + (k00_20 * A[1]));
    A := (A + 8);
    ee0 := (ee0 - 8);
    ee2 := (ee2 - 8);
    _L__for0_step:
    i_2 := (i_2 - 1);
  end;
end;

procedure imdct_step3_inner_r_loop(lim: LongInt; e: PSingle; d0: LongInt; k_off: LongInt; A: PSingle; k1: LongInt);
label _L__for0_step;
var
  i_2: LongInt;
  k00_20: Single;
  k01_21: Single;
  e0: PSingle;
  e2: PSingle;
  __c2p_tmp1: LongInt;
  __c2p_tmp2: LongInt;
  __c2p_tmp3: LongInt;
  __c2p_tmp4: LongInt;
  __c2p_tmp5: LongInt;
  __c2p_tmp6: LongInt;
  __c2p_tmp7: LongInt;
  __c2p_tmp8: LongInt;
begin
  e0 := (e + d0);
  e2 := (e0 + k_off);
  i_2 := __c2p_sar_longint(lim, 2);
  while (i_2 > 0) do
  begin
    k00_20 := (e0[-0] - e2[-0]);
    k01_21 := (e0[-1] - e2[-1]);
    __c2p_tmp1 := -0;
    e0[__c2p_tmp1] := (e0[__c2p_tmp1] + e2[-0]);
    __c2p_tmp2 := -1;
    e0[__c2p_tmp2] := (e0[__c2p_tmp2] + e2[-1]);
    e2[-0] := ((k00_20 * A[0]) - (k01_21 * A[1]));
    e2[-1] := ((k01_21 * A[0]) + (k00_20 * A[1]));
    A := (A + k1);
    k00_20 := (e0[-2] - e2[-2]);
    k01_21 := (e0[-3] - e2[-3]);
    __c2p_tmp3 := -2;
    e0[__c2p_tmp3] := (e0[__c2p_tmp3] + e2[-2]);
    __c2p_tmp4 := -3;
    e0[__c2p_tmp4] := (e0[__c2p_tmp4] + e2[-3]);
    e2[-2] := ((k00_20 * A[0]) - (k01_21 * A[1]));
    e2[-3] := ((k01_21 * A[0]) + (k00_20 * A[1]));
    A := (A + k1);
    k00_20 := (e0[-4] - e2[-4]);
    k01_21 := (e0[-5] - e2[-5]);
    __c2p_tmp5 := -4;
    e0[__c2p_tmp5] := (e0[__c2p_tmp5] + e2[-4]);
    __c2p_tmp6 := -5;
    e0[__c2p_tmp6] := (e0[__c2p_tmp6] + e2[-5]);
    e2[-4] := ((k00_20 * A[0]) - (k01_21 * A[1]));
    e2[-5] := ((k01_21 * A[0]) + (k00_20 * A[1]));
    A := (A + k1);
    k00_20 := (e0[-6] - e2[-6]);
    k01_21 := (e0[-7] - e2[-7]);
    __c2p_tmp7 := -6;
    e0[__c2p_tmp7] := (e0[__c2p_tmp7] + e2[-6]);
    __c2p_tmp8 := -7;
    e0[__c2p_tmp8] := (e0[__c2p_tmp8] + e2[-7]);
    e2[-6] := ((k00_20 * A[0]) - (k01_21 * A[1]));
    e2[-7] := ((k01_21 * A[0]) + (k00_20 * A[1]));
    e0 := (e0 - 8);
    e2 := (e2 - 8);
    A := (A + k1);
    _L__for0_step:
    i_2 := (i_2 - 1);
  end;
end;

procedure imdct_step3_inner_s_loop(n_2: LongInt; e: PSingle; i_off: LongInt; k_off: LongInt; A: PSingle; a_off: LongInt; k0: LongInt);
label _L__for0_step;
var
  i_2: LongInt;
  A0: Single;
  A1: Single;
  A2: Single;
  A3: Single;
  A4: Single;
  A5: Single;
  A6: Single;
  A7: Single;
  k00: Single;
  k11: Single;
  ee0: PSingle;
  ee2: PSingle;
begin
  A0 := A[0];
  A1 := A[(0 + 1)];
  A2 := A[(0 + a_off)];
  A3 := A[((0 + a_off) + 1)];
  A4 := A[((0 + (a_off * 2)) + 0)];
  A5 := A[((0 + (a_off * 2)) + 1)];
  A6 := A[((0 + (a_off * 3)) + 0)];
  A7 := A[((0 + (a_off * 3)) + 1)];
  ee0 := (e + i_off);
  ee2 := (ee0 + k_off);
  i_2 := n_2;
  while (i_2 > 0) do
  begin
    k00 := (ee0[0] - ee2[0]);
    k11 := (ee0[-1] - ee2[-1]);
    ee0[0] := (ee0[0] + ee2[0]);
    ee0[-1] := (ee0[-1] + ee2[-1]);
    ee2[0] := ((k00 * A0) - (k11 * A1));
    ee2[-1] := ((k11 * A0) + (k00 * A1));
    k00 := (ee0[-2] - ee2[-2]);
    k11 := (ee0[-3] - ee2[-3]);
    ee0[-2] := (ee0[-2] + ee2[-2]);
    ee0[-3] := (ee0[-3] + ee2[-3]);
    ee2[-2] := ((k00 * A2) - (k11 * A3));
    ee2[-3] := ((k11 * A2) + (k00 * A3));
    k00 := (ee0[-4] - ee2[-4]);
    k11 := (ee0[-5] - ee2[-5]);
    ee0[-4] := (ee0[-4] + ee2[-4]);
    ee0[-5] := (ee0[-5] + ee2[-5]);
    ee2[-4] := ((k00 * A4) - (k11 * A5));
    ee2[-5] := ((k11 * A4) + (k00 * A5));
    k00 := (ee0[-6] - ee2[-6]);
    k11 := (ee0[-7] - ee2[-7]);
    ee0[-6] := (ee0[-6] + ee2[-6]);
    ee0[-7] := (ee0[-7] + ee2[-7]);
    ee2[-6] := ((k00 * A6) - (k11 * A7));
    ee2[-7] := ((k11 * A6) + (k00 * A7));
    ee0 := (ee0 - k0);
    ee2 := (ee2 - k0);
    _L__for0_step:
    i_2 := (i_2 - 1);
  end;
end;

procedure iter_54(z_2: PSingle); inline;
var
  k00: Single;
  k11: Single;
  k22: Single;
  k33: Single;
  y0: Single;
  y1: Single;
  y2: Single;
  y3: Single;
begin
  k00 := (z_2[0] - z_2[-4]);
  y0 := (z_2[0] + z_2[-4]);
  y2 := (z_2[-2] + z_2[-6]);
  k22 := (z_2[-2] - z_2[-6]);
  z_2[-0] := (y0 + y2);
  z_2[-2] := (y0 - y2);
  k33 := (z_2[-3] - z_2[-7]);
  z_2[-4] := (k00 + k33);
  z_2[-6] := (k00 - k33);
  k11 := (z_2[-1] - z_2[-5]);
  y1 := (z_2[-1] + z_2[-5]);
  y3 := (z_2[-3] + z_2[-7]);
  z_2[-1] := (y1 + y3);
  z_2[-3] := (y1 - y3);
  z_2[-5] := (k11 - k22);
  z_2[-7] := (k11 + k22);
end;

procedure imdct_step3_inner_s_loop_ld654(n_2: LongInt; e: PSingle; i_off: LongInt; A: PSingle; base_n: LongInt);
var
  a_off: LongInt;
  A2: Single;
  z_2: PSingle;
  base: PSingle;
  k00: Single;
  k11: Single;
  l00: Single;
  l11: Single;
begin
  a_off := __c2p_sar_longint(base_n, 3);
  A2 := A[(0 + a_off)];
  z_2 := (e + i_off);
  base := (z_2 - (16 * n_2));
  while (z_2 > base) do
  begin
    k00 := (z_2[-0] - z_2[-8]);
    k11 := (z_2[-1] - z_2[-9]);
    l00 := (z_2[-2] - z_2[-10]);
    l11 := (z_2[-3] - z_2[-11]);
    z_2[-0] := (z_2[-0] + z_2[-8]);
    z_2[-1] := (z_2[-1] + z_2[-9]);
    z_2[-2] := (z_2[-2] + z_2[-10]);
    z_2[-3] := (z_2[-3] + z_2[-11]);
    z_2[-8] := k00;
    z_2[-9] := k11;
    z_2[-10] := ((l00 + l11) * A2);
    z_2[-11] := ((l11 - l00) * A2);
    k00 := (z_2[-4] - z_2[-12]);
    k11 := (z_2[-5] - z_2[-13]);
    l00 := (z_2[-6] - z_2[-14]);
    l11 := (z_2[-7] - z_2[-15]);
    z_2[-4] := (z_2[-4] + z_2[-12]);
    z_2[-5] := (z_2[-5] + z_2[-13]);
    z_2[-6] := (z_2[-6] + z_2[-14]);
    z_2[-7] := (z_2[-7] + z_2[-15]);
    z_2[-12] := k11;
    z_2[-13] := -k00;
    z_2[-14] := ((l11 - l00) * A2);
    z_2[-15] := ((l00 + l11) * -A2);
    iter_54(z_2);
    iter_54((z_2 - 8));
    z_2 := (z_2 - 16);
  end;
end;

procedure inverse_mdct(buffer: PSingle; n_2: LongInt; f: PVorb; blocktype: LongInt);
label _L__for0_step, _L__for1_step, _L__for2_step, _L__for3_step;
var
  n2: LongInt;
  n4: LongInt;
  n8: LongInt;
  l: LongInt;
  ld: LongInt;
  save_point: LongInt;
  buf2: PSingle;
  u: PSingle;
  v: PSingle;
  A: PSingle;
  d_2: PSingle;
  e: PSingle;
  AA: PSingle;
  e_stop: PSingle;
  AA_2: PSingle;
  d0: PSingle;
  d1: PSingle;
  e0: PSingle;
  e1: PSingle;
  v40_20: Single;
  v41_21: Single;
  k0: LongInt;
  k0_2: LongInt;
  lim: LongInt;
  i_2: LongInt;
  k0_3: LongInt;
  k1: LongInt;
  k0_2_2: LongInt;
  rlim: LongInt;
  r: LongInt;
  lim_2: LongInt;
  i_off: LongInt;
  A0: PSingle;
  bitrev: PUint16;
  d0_2: PSingle;
  d1_2: PSingle;
  k4: LongInt;
  C: PSingle;
  d_3: PSingle;
  e_2: PSingle;
  a02: Single;
  a11: Single;
  b0: Single;
  b1: Single;
  b2: Single;
  b3: Single;
  d0_3: PSingle;
  d1_3: PSingle;
  d2: PSingle;
  d3: PSingle;
  B: PSingle;
  e_3: PSingle;
  p0: Single;
  p1: Single;
  p2: Single;
  p3: Single;
  __c2p_tmp1: Pointer;
begin
  n2 := __c2p_sar_longint(n_2, 1);
  n4 := __c2p_sar_longint(n_2, 2);
  n8 := __c2p_sar_longint(n_2, 3);
  save_point := f^.temp_offset;
  if (f^.alloc.alloc_buffer <> nil) then
  begin
    __c2p_tmp1 := Pointer(setup_temp_malloc(f, LongInt(QWord((QWord(n2) * 4)))));
  end
  else
  begin
    __c2p_tmp1 := vdec_frame_buf2(n2);
  end;
  buf2 := PSingle(__c2p_tmp1);
  u := nil;
  v := nil;
  A := f^.A[blocktype];
  {$ifdef C2P_SIMD}
  if use_mdct_sse then
  begin
    vdec_mdct_fold1(buf2, buffer, A, __c2p_sar_longint(n2, 2));
    vdec_mdct_fold2(buf2, buffer, @A[__c2p_sar_longint(n2, 1)], __c2p_sar_longint(n2, 2));
  end
  else
  {$endif}
  begin
    d_2 := @buf2[(n2 - 2)];
    AA := A;
    e := @buffer[0];
    e_stop := @buffer[n2];
    while (e <> e_stop) do
    begin
      d_2[1] := ((e[0] * AA[0]) - (e[2] * AA[1]));
      d_2[0] := ((e[0] * AA[1]) + (e[2] * AA[0]));
      d_2 := (d_2 - 2);
      AA := (AA + 2);
      e := (e + 4);
    end;
    e := @buffer[(n2 - 3)];
    while (d_2 >= buf2) do
    begin
      d_2[1] := ((-e[2] * AA[0]) - (-e[0] * AA[1]));
      d_2[0] := ((-e[2] * AA[1]) + (-e[0] * AA[0]));
      d_2 := (d_2 - 2);
      AA := (AA + 2);
      e := (e - 4);
    end;
  end;
  u := buffer;
  v := buf2;
  {$ifdef C2P_SIMD}
  if use_mdct_sse then
  begin
    vdec_mdct_step2(buffer, buf2, @A[(n2 - 8)], Int64(__c2p_sar_longint(n_2, 2)) or (Int64(__c2p_sar_longint(n2, 3)) shl 32));
  end
  else
  {$endif}
  begin
    AA_2 := @A[(n2 - 8)];
    e0 := @v[n4];
    e1 := @v[0];
    d0 := @u[n4];
    d1 := @u[0];
    while (AA_2 >= A) do
    begin
      v41_21 := (e0[1] - e1[1]);
      v40_20 := (e0[0] - e1[0]);
      d0[1] := (e0[1] + e1[1]);
      d0[0] := (e0[0] + e1[0]);
      d1[1] := ((v41_21 * AA_2[4]) - (v40_20 * AA_2[5]));
      d1[0] := ((v40_20 * AA_2[4]) + (v41_21 * AA_2[5]));
      v41_21 := (e0[3] - e1[3]);
      v40_20 := (e0[2] - e1[2]);
      d0[3] := (e0[3] + e1[3]);
      d0[2] := (e0[2] + e1[2]);
      d1[3] := ((v41_21 * AA_2[0]) - (v40_20 * AA_2[1]));
      d1[2] := ((v40_20 * AA_2[0]) + (v41_21 * AA_2[1]));
      AA_2 := (AA_2 - 8);
      d0 := (d0 + 4);
      d1 := (d1 + 4);
      e0 := (e0 + 4);
      e1 := (e1 + 4);
    end;
  end;
  ld := (ilog(TInt32(n_2)) - 1);
  {$ifdef C2P_SIMD}
  if use_mdct_sse then
  begin
    { iter0：即 k1=8 的 r 型蝶形（twiddle 每蝶形步进 8，指针每迭代降 8） }
    e0 := (u + ((n2 - 1) - (n4 * 0)));
    e1 := (e0 - __c2p_sar_longint(n_2, 3));
    vdec_mdct_bfly_r(e0, e1, A, Int64(8) or (Int64(__c2p_sar_longint(n_2, 6)) shl 32));
    e0 := (u + ((n2 - 1) - (n4 * 1)));
    e1 := (e0 - __c2p_sar_longint(n_2, 3));
    vdec_mdct_bfly_r(e0, e1, A, Int64(8) or (Int64(__c2p_sar_longint(n_2, 6)) shl 32));
    { 固定四路 r_loop，k1=16，内部迭代数 n>>7 }
    e0 := (u + ((n2 - 1) - (n8 * 0)));
    e1 := (e0 - __c2p_sar_longint(n_2, 4));
    vdec_mdct_bfly_r(e0, e1, A, Int64(16) or (Int64(__c2p_sar_longint(n_2, 7)) shl 32));
    e0 := (u + ((n2 - 1) - (n8 * 1)));
    e1 := (e0 - __c2p_sar_longint(n_2, 4));
    vdec_mdct_bfly_r(e0, e1, A, Int64(16) or (Int64(__c2p_sar_longint(n_2, 7)) shl 32));
    e0 := (u + ((n2 - 1) - (n8 * 2)));
    e1 := (e0 - __c2p_sar_longint(n_2, 4));
    vdec_mdct_bfly_r(e0, e1, A, Int64(16) or (Int64(__c2p_sar_longint(n_2, 7)) shl 32));
    e0 := (u + ((n2 - 1) - (n8 * 3)));
    e1 := (e0 - __c2p_sar_longint(n_2, 4));
    vdec_mdct_bfly_r(e0, e1, A, Int64(16) or (Int64(__c2p_sar_longint(n_2, 7)) shl 32));
    l := 2;
    while (l < __c2p_sar_longint((ld - 3), 1)) do
    begin
      k0 := __c2p_sar_longint(n_2, (l + 2));
      lim := (1 shl (l + 1));
      i_2 := 0;
      while (i_2 < lim) do
      begin
        e0 := (u + ((n2 - 1) - (k0 * i_2)));
        vdec_mdct_bfly_r(e0, (e0 - __c2p_sar_longint(k0, 1)), A, Int64(1 shl (l + 3)) or (Int64(__c2p_sar_longint(n_2, (l + 6))) shl 32));
        i_2 := (i_2 + 1);
      end;
      l := (l + 1);
    end;
    while (l < (ld - 6)) do
    begin
      k0_3 := __c2p_sar_longint(n_2, (l + 2));
      k1 := (1 shl (l + 3));
      k0_2_2 := __c2p_sar_longint(k0_3, 1);
      rlim := __c2p_sar_longint(n_2, (l + 6));
      lim_2 := (1 shl (l + 1));
      A0 := A;
      i_off := (n2 - 1);
      r := rlim;
      while (r > 0) do
      begin
        e0 := (u + i_off);
        vdec_mdct_bfly_s(e0, (e0 - k0_2_2), A0, (Int64(k0_3) or (Int64(k1) shl 16) or (Int64(lim_2) shl 32)));
        A0 := (A0 + (k1 * 4));
        i_off := (i_off - 8);
        r := (r - 1);
      end;
      l := (l + 1);
    end;
    vdec_mdct_ld654(@u[(n2 - 1)], @A[__c2p_sar_longint(n_2, 3)], __c2p_sar_longint(n_2, 5));
  end
  else
  {$endif}
  begin
    imdct_step3_iter0_loop(__c2p_sar_longint(n_2, 4), u, ((n2 - 1) - (n4 * 0)), -__c2p_sar_longint(n_2, 3), A);
    imdct_step3_iter0_loop(__c2p_sar_longint(n_2, 4), u, ((n2 - 1) - (n4 * 1)), -__c2p_sar_longint(n_2, 3), A);
  imdct_step3_inner_r_loop(__c2p_sar_longint(n_2, 5), u, ((n2 - 1) - (n8 * 0)), -__c2p_sar_longint(n_2, 4), A, 16);
  imdct_step3_inner_r_loop(__c2p_sar_longint(n_2, 5), u, ((n2 - 1) - (n8 * 1)), -__c2p_sar_longint(n_2, 4), A, 16);
  imdct_step3_inner_r_loop(__c2p_sar_longint(n_2, 5), u, ((n2 - 1) - (n8 * 2)), -__c2p_sar_longint(n_2, 4), A, 16);
  imdct_step3_inner_r_loop(__c2p_sar_longint(n_2, 5), u, ((n2 - 1) - (n8 * 3)), -__c2p_sar_longint(n_2, 4), A, 16);
  l := 2;
  while (l < __c2p_sar_longint((ld - 3), 1)) do
  begin
    k0 := __c2p_sar_longint(n_2, (l + 2));
    k0_2 := __c2p_sar_longint(k0, 1);
    lim := (1 shl (l + 1));
    i_2 := 0;
    while (i_2 < lim) do
    begin
      imdct_step3_inner_r_loop(__c2p_sar_longint(n_2, (l + 4)), u, ((n2 - 1) - (k0 * i_2)), -k0_2, A, (1 shl (l + 3)));
      _L__for1_step:
      i_2 := (i_2 + 1);
    end;
    _L__for0_step:
    l := (l + 1);
  end;
  while (l < (ld - 6)) do
  begin
    k0_3 := __c2p_sar_longint(n_2, (l + 2));
    k1 := (1 shl (l + 3));
    k0_2_2 := __c2p_sar_longint(k0_3, 1);
    rlim := __c2p_sar_longint(n_2, (l + 6));
    lim_2 := (1 shl (l + 1));
    A0 := A;
    i_off := (n2 - 1);
    r := rlim;
    while (r > 0) do
    begin
      imdct_step3_inner_s_loop(lim_2, u, i_off, -k0_2_2, A0, k1, k0_3);
      A0 := (A0 + (k1 * 4));
      i_off := (i_off - 8);
      _L__for3_step:
      r := (r - 1);
    end;
    _L__for2_step:
    l := (l + 1);
  end;
  imdct_step3_inner_s_loop_ld654(__c2p_sar_longint(n_2, 5), u, (n2 - 1), A, n_2);
  end;
  bitrev := f^.bit_reverse[blocktype];
  d0_2 := @v[(n4 - 4)];
  d1_2 := @v[(n2 - 4)];
  while (d0_2 >= v) do
  begin
    k4 := LongInt(bitrev[0]);
    d1_2[3] := u[(k4 + 0)];
    d1_2[2] := u[(k4 + 1)];
    d0_2[3] := u[(k4 + 2)];
    d0_2[2] := u[(k4 + 3)];
    k4 := LongInt(bitrev[1]);
    d1_2[1] := u[(k4 + 0)];
    d1_2[0] := u[(k4 + 1)];
    d0_2[1] := u[(k4 + 2)];
    d0_2[0] := u[(k4 + 3)];
    d0_2 := (d0_2 - 4);
    d1_2 := (d1_2 - 4);
    bitrev := (bitrev + 2);
  end;
  {$ifdef C2P_SIMD}
  if use_mdct_sse then
    vdec_mdct_step7(v, f^.C[blocktype], n2)
  else
  {$endif}
  begin
    C := f^.C[blocktype];
    d_3 := v;
    e_2 := ((v + n2) - 4);
    while (d_3 < e_2) do
  begin
    a02 := (d_3[0] - e_2[2]);
    a11 := (d_3[1] + e_2[3]);
    b0 := ((C[1] * a02) + (C[0] * a11));
    b1 := ((C[1] * a11) - (C[0] * a02));
    b2 := (d_3[0] + e_2[2]);
    b3 := (d_3[1] - e_2[3]);
    d_3[0] := (b2 + b0);
    d_3[1] := (b3 + b1);
    e_2[2] := (b2 - b0);
    e_2[3] := (b1 - b3);
    a02 := (d_3[2] - e_2[0]);
    a11 := (d_3[3] + e_2[1]);
    b0 := ((C[3] * a02) + (C[2] * a11));
    b1 := ((C[3] * a11) - (C[2] * a02));
    b2 := (d_3[2] + e_2[0]);
    b3 := (d_3[3] - e_2[1]);
    d_3[2] := (b2 + b0);
    d_3[3] := (b3 + b1);
    e_2[0] := (b2 - b0);
    e_2[1] := (b1 - b3);
    C := (C + 4);
    d_3 := (d_3 + 4);
    e_2 := (e_2 - 4);
  end;
  end;
  {$ifdef C2P_SIMD}
  if use_mdct_sse then
    vdec_mdct_step8(buffer, buf2, ((f^.B[blocktype] + n2) - 8), n2)
  else
  {$endif}
  begin
    B := ((f^.B[blocktype] + n2) - 8);
  e_3 := ((buf2 + n2) - 8);
  d0_3 := @buffer[0];
  d1_3 := @buffer[(n2 - 4)];
  d2 := @buffer[n2];
  d3 := @buffer[(n_2 - 4)];
  while (e_3 >= v) do
  begin
    p3 := ((e_3[6] * B[7]) - (e_3[7] * B[6]));
    p2 := ((-e_3[6] * B[6]) - (e_3[7] * B[7]));
    d0_3[0] := p3;
    d1_3[3] := -p3;
    d2[0] := p2;
    d3[3] := p2;
    p1 := ((e_3[4] * B[5]) - (e_3[5] * B[4]));
    p0 := ((-e_3[4] * B[4]) - (e_3[5] * B[5]));
    d0_3[1] := p1;
    d1_3[2] := -p1;
    d2[1] := p0;
    d3[2] := p0;
    p3 := ((e_3[2] * B[3]) - (e_3[3] * B[2]));
    p2 := ((-e_3[2] * B[2]) - (e_3[3] * B[3]));
    d0_3[2] := p3;
    d1_3[1] := -p3;
    d2[2] := p2;
    d3[1] := p2;
    p1 := ((e_3[0] * B[1]) - (e_3[1] * B[0]));
    p0 := ((-e_3[0] * B[0]) - (e_3[1] * B[1]));
    d0_3[3] := p1;
    d1_3[0] := -p1;
    d2[3] := p0;
    d3[0] := p0;
    B := (B - 8);
    e_3 := (e_3 - 8);
    d0_3 := (d0_3 + 4);
    d2 := (d2 + 4);
    d1_3 := (d1_3 - 4);
    d3 := (d3 - 4);
  end;
  end;
  f^.temp_offset := save_point;
end;

function get_window(f: PVorb; __c2p_arg_len_2: LongInt): PSingle; inline;
var
  len_2: LongInt;
begin
  len_2 := __c2p_arg_len_2;
  len_2 := (len_2 shl 1);
  if (len_2 = f^.blocksize_0) then
  begin
    Result := f^.window[0];
    System.Exit;
  end;
  if (len_2 = f^.blocksize_1) then
  begin
    Result := f^.window[1];
    System.Exit;
  end;
  Result := nil;
end;

function do_floor(f: PVorb; map: PMapping; i_2: LongInt; n_2: LongInt; target: PSingle; finalY: PYTYPE; step2_flag: PUint8): LongInt;
label _L__for0_step, _L__for1_step;
var
  n2: LongInt;
  s_2: LongInt;
  floor: LongInt;
  g: PFloor1;
  j: LongInt;
  q: LongInt;
  lx: LongInt;
  ly: LongInt;
  hy: LongInt;
  hx: LongInt;
begin
  n2 := __c2p_sar_longint(n_2, 1);
  s_2 := LongInt(map^.chan[i_2].mux);
  floor := LongInt(map^.submap_floor[s_2]);
  if (f^.floor_types[floor] = 0) then
  begin
    Result := error(f, VORBIS_invalid_stream);
    System.Exit;
  end
  else
  begin
    g := @f^.floor_config[floor].floor1;
    lx := 0;
    ly := (LongInt(finalY[0]) * LongInt(g^.floor1_multiplier));
    q := 1;
    while (q < g^.values) do
    begin
      j := LongInt(g^.sorted_order[q]);
      if (LongInt(finalY[j]) >= 0) then
      begin
        hy := (LongInt(finalY[j]) * LongInt(g^.floor1_multiplier));
        hx := LongInt(g^.Xlist[j]);
        if (lx <> hx) then
        begin
          draw_line(target, lx, ly, hx, hy, n2);
        end;
        lx := hx;
        ly := hy;
      end;
      _L__for0_step:
      q := (q + 1);
    end;
    if (lx < n2) then
    begin
      j := lx;
      while (j < n2) do
      begin
        target[j] := (target[j] * inverse_db_table[ly]);
        _L__for1_step:
        j := (j + 1);
      end;
    end;
  end;
  Result := 1;
end;

function vorbis_decode_initial(f: PVorb; p_left_start: PLongInt; p_left_end: PLongInt; p_right_start: PLongInt; p_right_end: PLongInt; mode: PLongInt): LongInt; inline;
label _L_retry;
var
  m: PMode;
  i_2: LongInt;
  n_2: LongInt;
  prev: LongInt;
  next: LongInt;
  window_center: LongInt;
  __c2p_tmp1: LongInt;
  __c2p_tmp2: LongInt;
begin
  __c2p_tmp1 := 0;
  f^.channel_buffer_end := __c2p_tmp1;
  f^.channel_buffer_start := __c2p_tmp1;
  _L_retry:
  if (f^.eof <> 0) then
  begin
    Result := 0;
    System.Exit;
  end;
  if (maybe_start_packet(f) = 0) then
  begin
    Result := 0;
    System.Exit;
  end;
  if (get_bits(f, 1) <> LongWord(0)) then
  begin
    if (LongInt(f^.push_mode) <> 0) then
    begin
      Result := error(f, VORBIS_bad_packet_type);
      System.Exit;
    end;
    while (-1 <> get8_packet(f)) do
    begin
    end;
    goto _L_retry;
  end;
  if (f^.alloc.alloc_buffer <> nil) then
  begin
  end;
  i_2 := LongInt(get_bits(f, ilog(TInt32((f^.mode_count - 1)))));
  if (i_2 = -1) then
  begin
    Result := 0;
    System.Exit;
  end;
  if (i_2 >= f^.mode_count) then
  begin
    Result := 0;
    System.Exit;
  end;
  mode^ := i_2;
  m := (PMode(@f^.mode_config[0]) + i_2);
  if (LongInt(m^.blockflag) <> 0) then
  begin
    n_2 := f^.blocksize_1;
    prev := LongInt(get_bits(f, 1));
    next := LongInt(get_bits(f, 1));
  end
  else
  begin
    __c2p_tmp2 := 0;
    next := __c2p_tmp2;
    prev := __c2p_tmp2;
    n_2 := f^.blocksize_0;
  end;
  window_center := __c2p_sar_longint(n_2, 1);
  if ((LongInt(m^.blockflag) <> 0) and (prev = 0)) then
  begin
    p_left_start^ := __c2p_sar_longint((n_2 - f^.blocksize_0), 2);
    p_left_end^ := __c2p_sar_longint((n_2 + f^.blocksize_0), 2);
  end
  else
  begin
    p_left_start^ := 0;
    p_left_end^ := window_center;
  end;
  if ((LongInt(m^.blockflag) <> 0) and (next = 0)) then
  begin
    p_right_start^ := __c2p_sar_longint(((n_2 * 3) - f^.blocksize_0), 2);
    p_right_end^ := __c2p_sar_longint(((n_2 * 3) + f^.blocksize_0), 2);
  end
  else
  begin
    p_right_start^ := window_center;
    p_right_end^ := n_2;
  end;
  Result := 1;
end;

function vorbis_decode_packet_rest(f: PVorb; len_2: PLongInt; m: PMode; left_start: LongInt; left_end: LongInt; right_start: LongInt; right_end: LongInt; p_left: PLongInt): LongInt;
label _L_error, _L__for0_step, _L__for1_step, _L__for2_step, _L__for3_step, _L__for4_step, _L__for5_step, _L__for6_step, _L__for7_step, _L__for8_step, _L__for9_step, _L__for10_step, _L__for11_step;
var
  map: PMapping;
  i_2: LongInt;
  j: LongInt;
  k: LongInt;
  n_2: LongInt;
  n2: LongInt;
  zero_channel: array[0..255] of LongInt;
  really_zero_channel: array[0..255] of LongInt;
  s_2: LongInt;
  floor: LongInt;
  g: PFloor1;
  finalY: PInt16;
  step2_flag: array[0..255] of TUint8;
  range: LongInt;
  offset: LongInt;
  pclass: LongInt;
  cdim: LongInt;
  cbits: LongInt;
  csub: LongInt;
  cval: LongInt;
  c: PCodebook;
  n_3: LongInt;
  book: LongInt;
  temp_2: LongInt;
  c_2: PCodebook;
  n_4: LongInt;
  low: LongInt;
  high: LongInt;
  pred: LongInt;
  highroom: LongInt;
  lowroom: LongInt;
  room: LongInt;
  val: LongInt;
  residue_buffers: array[0..15] of PSingle;
  r: LongInt;
  do_not_decode: array[0..255] of TUint8;
  ch: LongInt;
  n2_2: LongInt;
  m_2: PSingle;
  a: PSingle;
  a2: Single;
  m2: Single;
  current_end: TUint32;
  __c2p_tmp3: TUint8;
  __c2p_tmp1: LongInt;
  __c2p_tmp2: LongInt;
  __c2p_tmp4: TUint8;
  __c2p_tmp5: LongInt;
  __c2p_tmp6: LongInt;
begin
  n_2 := f^.blocksize[LongInt(m^.blockflag)];
  map := @f^.mapping[LongInt(m^.mapping)];
  n2 := __c2p_sar_longint(n_2, 1);
  i_2 := 0;
  while (i_2 < f^.channels) do
  begin
    s_2 := LongInt(map^.chan[i_2].mux);
    zero_channel[i_2] := 0;
    floor := LongInt(map^.submap_floor[s_2]);
    if (f^.floor_types[floor] = 0) then
    begin
      Result := error(f, VORBIS_invalid_stream);
      System.Exit;
    end
    else
    begin
      g := @f^.floor_config[floor].floor1;
      if (get_bits(f, 1) <> 0) then
      begin
        range := _static_vorbis_decode_packet_rest_range_list[(LongInt(g^.floor1_multiplier) - 1)];
        offset := 2;
        finalY := f^.finalY[i_2];
        finalY[0] := TInt16(get_bits(f, (ilog(TInt32(range)) - 1)));
        finalY[1] := TInt16(get_bits(f, (ilog(TInt32(range)) - 1)));
        j := 0;
        while (j < g^.partitions) do
        begin
          pclass := LongInt(g^.partition_class_list[j]);
          cdim := LongInt(g^.class_dimensions[pclass]);
          cbits := LongInt(g^.class_subclasses[pclass]);
          csub := ((1 shl cbits) - 1);
          cval := 0;
          if (cbits <> 0) then
          begin
            c := (f^.codebooks + LongInt(g^.class_masterbooks[pclass]));
            if (f^.valid_bits < 10) then
            begin
              prep_huffman(f);
            end;
            cval := LongInt((f^.acc and LongWord(((1 shl 10) - 1))));
            cval := LongInt(c^.fast_huffman[cval]);
            if (cval >= 0) then
            begin
              n_3 := LongInt(c^.codeword_lengths[cval]);
              f^.acc := (f^.acc shr n_3);
              f^.valid_bits := (f^.valid_bits - n_3);
              if (f^.valid_bits < 0) then
              begin
                f^.valid_bits := 0;
                cval := -1;
              end;
            end
            else
            begin
              cval := codebook_decode_scalar_raw(f, c);
            end;
            if (LongInt(c^.sparse) <> 0) then
            begin
              cval := c^.sorted_values[cval];
            end;
          end;
          k := 0;
          while (k < cdim) do
          begin
            book := LongInt(g^.subclass_books[pclass][(cval and csub)]);
            cval := __c2p_sar_longint(cval, cbits);
            if (book >= 0) then
            begin
              c_2 := (f^.codebooks + book);
              if (f^.valid_bits < 10) then
              begin
                prep_huffman(f);
              end;
              temp_2 := LongInt((f^.acc and LongWord(((1 shl 10) - 1))));
              temp_2 := LongInt(c_2^.fast_huffman[temp_2]);
              if (temp_2 >= 0) then
              begin
                n_4 := LongInt(c_2^.codeword_lengths[temp_2]);
                f^.acc := (f^.acc shr n_4);
                f^.valid_bits := (f^.valid_bits - n_4);
                if (f^.valid_bits < 0) then
                begin
                  f^.valid_bits := 0;
                  temp_2 := -1;
                end;
              end
              else
              begin
                temp_2 := codebook_decode_scalar_raw(f, c_2);
              end;
              if (LongInt(c_2^.sparse) <> 0) then
              begin
                temp_2 := c_2^.sorted_values[temp_2];
              end;
              __c2p_tmp1 := offset;
              offset := (offset + 1);
              finalY[__c2p_tmp1] := TInt16(temp_2);
            end
            else
            begin
              __c2p_tmp2 := offset;
              offset := (offset + 1);
              finalY[__c2p_tmp2] := TInt16(0);
            end;
            _L__for2_step:
            k := (k + 1);
          end;
          _L__for1_step:
          j := (j + 1);
        end;
        if (f^.valid_bits = -1) then
        begin
          goto _L_error;
        end;
        __c2p_tmp3 := TUint8(1);
        step2_flag[1] := __c2p_tmp3;
        step2_flag[0] := TUint8(__c2p_tmp3);
        j := 2;
        while (j < g^.values) do
        begin
          low := LongInt(g^.neighbors[j][0]);
          high := LongInt(g^.neighbors[j][1]);
          pred := predict_point(LongInt(g^.Xlist[j]), LongInt(g^.Xlist[low]), LongInt(g^.Xlist[high]), LongInt(finalY[low]), LongInt(finalY[high]));
          val := LongInt(finalY[j]);
          highroom := (range - pred);
          lowroom := pred;
          if (highroom < lowroom) then
          begin
            room := (highroom * 2);
          end
          else
          begin
            room := (lowroom * 2);
          end;
          if (val <> 0) then
          begin
            __c2p_tmp4 := TUint8(1);
            step2_flag[high] := __c2p_tmp4;
            step2_flag[low] := TUint8(__c2p_tmp4);
            step2_flag[j] := TUint8(1);
            if (val >= room) then
            begin
              if (highroom > lowroom) then
              begin
                finalY[j] := TInt16(((val - lowroom) + pred));
              end
              else
              begin
                finalY[j] := TInt16((((pred - val) + highroom) - 1));
              end;
            end
            else
            begin
              if ((val and 1) <> 0) then
              begin
                finalY[j] := TInt16((pred - __c2p_sar_longint((val + 1), 1)));
              end
              else
              begin
                finalY[j] := TInt16((pred + __c2p_sar_longint(val, 1)));
              end;
            end;
          end
          else
          begin
            step2_flag[j] := TUint8(0);
            finalY[j] := TInt16(pred);
          end;
          _L__for3_step:
          j := (j + 1);
        end;
        j := 0;
        while (j < g^.values) do
        begin
          if (LongInt(step2_flag[j]) = 0) then
          begin
            finalY[j] := TInt16(-1);
          end;
          _L__for4_step:
          j := (j + 1);
        end;
      end
      else
      begin
        _L_error:
        zero_channel[i_2] := 1;
      end;
    end;
    _L__for0_step:
    i_2 := (i_2 + 1);
  end;
  if (f^.alloc.alloc_buffer <> nil) then
  begin
  end;
  __c2p_stdlib_memcpy(Pointer(@really_zero_channel[0]), Pointer(@zero_channel[0]), TSizeT(QWord((4 * QWord(f^.channels)))));
  i_2 := 0;
  while (i_2 < map^.coupling_steps) do
  begin
    if ((zero_channel[LongInt(map^.chan[i_2].magnitude)] = 0) or (zero_channel[LongInt(map^.chan[i_2].angle)] = 0)) then
    begin
      __c2p_tmp6 := LongInt(map^.chan[i_2].angle);
      __c2p_tmp5 := 0;
      zero_channel[__c2p_tmp6] := __c2p_tmp5;
      zero_channel[LongInt(map^.chan[i_2].magnitude)] := __c2p_tmp5;
    end;
    _L__for5_step:
    i_2 := (i_2 + 1);
  end;
  i_2 := 0;
  while (i_2 < map^.submaps) do
  begin
    ch := 0;
    j := 0;
    while (j < f^.channels) do
    begin
      if (map^.chan[j].mux = i_2) then
      begin
        if (zero_channel[j] <> 0) then
        begin
          do_not_decode[ch] := TUint8(1);
          residue_buffers[ch] := nil;
        end
        else
        begin
          do_not_decode[ch] := TUint8(0);
          residue_buffers[ch] := f^.channel_buffers[j];
        end;
        ch := (ch + 1);
      end;
      _L__for7_step:
      j := (j + 1);
    end;
    r := LongInt(map^.submap_residue[i_2]);
    decode_residue(f, PPSingle(@residue_buffers[0]), ch, n2, r, PUint8(@do_not_decode[0]));
    _L__for6_step:
    i_2 := (i_2 + 1);
  end;
  if (f^.alloc.alloc_buffer <> nil) then
  begin
  end;
  i_2 := (LongInt(map^.coupling_steps) - 1);
  while (i_2 >= 0) do
  begin
    n2_2 := __c2p_sar_longint(n_2, 1);
    m_2 := f^.channel_buffers[LongInt(map^.chan[i_2].magnitude)];
    a := f^.channel_buffers[LongInt(map^.chan[i_2].angle)];
    j := 0;
    while (j < n2_2) do
    begin
      if (m_2[j] > 0) then
      begin
        if (a[j] > 0) then
        begin
          m2 := m_2[j];
          a2 := (m_2[j] - a[j]);
        end
        else
        begin
          a2 := m_2[j];
          m2 := (m_2[j] + a[j]);
        end;
      end
      else
      begin
        if (a[j] > 0) then
        begin
          m2 := m_2[j];
          a2 := (m_2[j] + a[j]);
        end
        else
        begin
          a2 := m_2[j];
          m2 := (m_2[j] - a[j]);
        end;
      end;
      m_2[j] := m2;
      a[j] := a2;
      _L__for9_step:
      j := (j + 1);
    end;
    _L__for8_step:
    i_2 := (i_2 - 1);
  end;
  i_2 := 0;
  while (i_2 < f^.channels) do
  begin
    if (really_zero_channel[i_2] <> 0) then
    begin
      __c2p_stdlib_memset(f^.channel_buffers[i_2], 0, TSizeT(QWord((4 * QWord(n2)))));
    end
    else
    begin
      do_floor(f, map, i_2, n_2, f^.channel_buffers[i_2], f^.finalY[i_2], PUint8(Pointer(0)));
    end;
    _L__for10_step:
    i_2 := (i_2 + 1);
  end;
  i_2 := 0;
  while (i_2 < f^.channels) do
  begin
    inverse_mdct(f^.channel_buffers[i_2], n_2, f, LongInt(m^.blockflag));
    _L__for11_step:
    i_2 := (i_2 + 1);
  end;
  flush_packet(f);
  if (LongInt(f^.first_decode) <> 0) then
  begin
    f^.current_loc := LongWord((0 - n2));
    f^.discard_samples_deferred := (n_2 - right_end);
    f^.current_loc_valid := 1;
    f^.first_decode := TUint8(0);
  end
  else
  begin
    if (f^.discard_samples_deferred <> 0) then
    begin
      if (f^.discard_samples_deferred >= (right_start - left_start)) then
      begin
        f^.discard_samples_deferred := (f^.discard_samples_deferred - (right_start - left_start));
        left_start := right_start;
        p_left^ := left_start;
      end
      else
      begin
        left_start := (left_start + f^.discard_samples_deferred);
        p_left^ := left_start;
        f^.discard_samples_deferred := 0;
      end;
    end
    else
    begin
      if ((f^.previous_length = 0) and (f^.current_loc_valid <> 0)) then
      begin
      end;
    end;
  end;
  if (f^.last_seg_which = f^.end_seg_with_known_loc) then
  begin
    if ((f^.current_loc_valid <> 0) and ((LongInt(f^.page_flag) and 4) <> 0)) then
    begin
      current_end := f^.known_loc_for_packet;
      if (current_end < LongWord((f^.current_loc + (right_end - left_start)))) then
      begin
        if (current_end < f^.current_loc) then
        begin
          len_2^ := 0;
        end
        else
        begin
          len_2^ := LongInt(LongWord((current_end - f^.current_loc)));
        end;
        len_2^ := (len_2^ + left_start);
        if (len_2^ > right_end) then
        begin
          len_2^ := right_end;
        end;
        f^.current_loc := (f^.current_loc + LongWord(len_2^));
        Result := 1;
        System.Exit;
      end;
    end;
    f^.current_loc := LongWord((f^.known_loc_for_packet - (n2 - left_start)));
    f^.current_loc_valid := 1;
  end;
  if (f^.current_loc_valid <> 0) then
  begin
    f^.current_loc := (f^.current_loc + LongWord((right_start - left_start)));
  end;
  if (f^.alloc.alloc_buffer <> nil) then
  begin
  end;
  len_2^ := right_end;
  Result := 1;
end;

function vorbis_decode_packet(f: PVorb; len_2: PLongInt; p_left: PLongInt; p_right: PLongInt): LongInt; inline;
var
  mode: LongInt;
  left_end: LongInt;
  right_end: LongInt;
begin
  if (vorbis_decode_initial(f, p_left, @left_end, p_right, @right_end, @mode) = 0) then
  begin
    Result := 0;
    System.Exit;
  end;
  Result := vorbis_decode_packet_rest(f, len_2, (PMode(@f^.mode_config[0]) + mode), p_left^, left_end, p_right^, right_end, p_left);
end;

{ 手工优化段（非翻译产物）：窗口混入逐元素独立，4-wide SSE2 与标量逐 op
  IEEE 等价，位精确不受影响；非 x86_64 目标不编入（调用点走标量回退）。
  注意必须是单元级过程：FPC 嵌套过程带隐藏 parent-frame 首参，会整体
  挤占参数寄存器槽位。}
{$ifdef cpux86_64}
procedure mix_window_simd(dst_: PSingle; src_: PSingle; w_: PSingle; n__: LongInt); assembler; nostackframe;
{ dst_[j] = dst_[j]*w_[j] + src_[j]*w_[n__-1-j]，j=0..n__-1。
  Linux 参数位：dst_=RDI src_=RSI w_=RDX n__=ECX；
  Windows 为 MS x64 位（RCX,RDX,R8,R9），序言搬移后主体共用 }
asm
{$ifdef windows}
  { Win64 ABI：RSI/RDI 非易失，须保存；成对 push 保持栈对齐 }
  push     %rdi
  push     %rsi
  movq     %rcx, %rdi
  movq     %rdx, %rsi
  movq     %r8, %rdx
  movl     %r9d, %ecx
{$endif}
  testl    %ecx, %ecx
  jle      .Lmw_done
  movl     %ecx, %eax                 { eax = n (>0) }
  movslq   %eax, %rax
  leaq     (%rdx,%rax,4), %r10
  subq     $16, %r10                  { r10 = &w[n-4-j]，随 j 每 4 元素下移 }
  movl     %ecx, %r11d
  andl     $-4, %r11d                 { r11d = n4 = n & ~3 }
  je       .Lmw_tail
  xorl     %r9d, %r9d                 { j = 0 }
.Lmw_main:
  movups   (%rdi,%r9,4), %xmm0
  movups   (%rsi,%r9,4), %xmm1
  mulps    (%rdx,%r9,4), %xmm0        { dst*w[j..j+3] }
  movups   (%r10), %xmm2              { 内存升序 [w[n-4-j .. n-1-j]] }
  pshufd   $0x1B, %xmm2, %xmm2        { 反转 lane 匹配 j 升序 }
  mulps    %xmm2, %xmm1
  addps    %xmm1, %xmm0
  movups   %xmm0, (%rdi,%r9,4)
  addq     $4, %r9
  subq     $16, %r10
  cmpq     %r11, %r9
  jb       .Lmw_main
.Lmw_tail:
  movslq   %r11d, %r11                { j = n4 }
  subq     %r11, %rax
  subq     $1, %rax                   { rax = n-1-n4 }
  leaq     (%rdx,%rax,4), %r10        { r10 = &w[n-1-j]，逐轮下移 }
  movl     %ecx, %r9d
  movslq   %r9d, %r9                  { r9 = n（终点） }
.Lmw_tloop:
  cmpq     %r9, %r11
  jae      .Lmw_done
  movss    (%rdi,%r11,4), %xmm0
  movss    (%rsi,%r11,4), %xmm1
  mulss    (%rdx,%r11,4), %xmm0
  mulss    (%r10), %xmm1              { w[n-1-j] }
  addss    %xmm1, %xmm0
  movss    %xmm0, (%rdi,%r11,4)
  incq     %r11
  subq     $4, %r10
  jmp      .Lmw_tloop
.Lmw_done:
{$ifdef windows}
  pop      %rsi
  pop      %rdi
{$endif}
end;
{$endif cpux86_64}

{$ifdef cpuaarch64}
procedure mix_window_simd(dst_: PSingle; src_: PSingle; w_: PSingle; n__: LongInt); assembler; nostackframe;
{ 与 x86 版逐 op 同构：每 4 元素一块，正向窗 w[j..j+3] 与反向窗
  [w[n-4-j..n-1-j]]（REV64+EXT 反转 lane 对齐 j 升序）各一 fmul，再
  单次 fadd 合并——禁 vfma 保位精确。尾部标量。只用 caller-saved 寄存器。
  x0=dst_ x1=src_ x2=w_ w3=n__ }
asm
  cmp      w3, #0
  b.le     .Lmw_done
  sxtw     x9, w3                    // n
  mov      x6, x2                    // 保存窗基址：主循环后索引会推进 x2，
                                     // 尾部反向游标须从原始基址重算（n4=0
                                     // 直跳尾部的路径同样依赖它）
  bic      w8, w3, #3                // n4 = n & ~3
  cbz      w8, .Lmw_tail_pre
  lsr      w10, w8, #2               // 块数
  add      x4, x2, x9, lsl #2
  sub      x4, x4, #16               // 反向窗游标 = &w[n-4]
.Lmw_main:
  ld1      {v0.4s}, [x0]             // dst[j..j+3]
  ld1      {v1.4s}, [x1]             // src
  ld1      {v2.4s}, [x2], #16        // w[j..j+3]
  ld1      {v3.4s}, [x4]             // 内存升序 [w[n-4-j..n-1-j]]
  rev64    v3.4s, v3.4s
  ext      v3.16b, v3.16b, v3.16b, #8 // lane k = w[n-1-j-k]
  fmul     v0.4s, v0.4s, v2.4s       // dst*w[j]
  fmul     v1.4s, v1.4s, v3.4s       // src*w[n-1-j]
  fadd     v0.4s, v0.4s, v1.4s
  st1      {v0.16b}, [x0], #16
  add      x1, x1, #16
  sub      x4, x4, #16
  subs     w10, w10, #1
  b.ne     .Lmw_main
.Lmw_tail_pre:
  and      x11, x9, #3               // 余数
  cbz      x11, .Lmw_done
  sub      x5, x9, x8                // n - n4（x86 版 rax 同式）
  sub      x5, x5, #1
  add      x4, x6, x5, lsl #2        // 首个尾部元素的 &w[n-1-j]，逐轮下移
.Lmw_tloop:
  ldr      s0, [x0]
  ldr      s1, [x1]
  ldr      s2, [x2]                  // w[j]
  ldr      s3, [x4]                  // w[n-1-j]
  fmul     s0, s0, s2
  fmul     s1, s1, s3
  fadd     s0, s0, s1
  str      s0, [x0], #4
  add      x1, x1, #4
  add      x2, x2, #4
  sub      x4, x4, #4
  subs     x11, x11, #1
  b.ne     .Lmw_tloop
.Lmw_done:
end;
{$endif cpuaarch64}

function vorbis_finish_frame(f: PStbVorbis; len_2: LongInt; left_2: LongInt; right_2: LongInt): LongInt;
label _L__for0_step, _L__for1_step, _L__for2_step, _L__for3_step;

var
  prev: LongInt;
  i_2: LongInt;
  j: LongInt;
  i_3: LongInt;
  j_2: LongInt;
  n_2: LongInt;
  w: PSingle;
begin
  if (f^.previous_length <> 0) then
  begin
    n_2 := f^.previous_length;
    w := PSingle(get_window(f, n_2));
    if (w = nil) then
    begin
      Result := 0;
      System.Exit;
    end;
    i_3 := 0;
    while (i_3 < f^.channels) do
    begin
      {$ifdef C2P_SIMD}
      if use_k1 then
        mix_window_simd(@(f^.channel_buffers[i_3][left_2]), @(f^.previous_window[i_3][0]), w, n_2)
      else
      begin
        { -dC2P_NO_K1 时回退标量而非跳过：混叠窗是解码必步，
          整体跳过会产生缺 overlap-add 的坏 PCM }
        j_2 := 0;
        while (j_2 < n_2) do
        begin
          f^.channel_buffers[i_3][(left_2 + j_2)] := ((f^.channel_buffers[i_3][(left_2 + j_2)] * w[j_2]) + (f^.previous_window[i_3][j_2] * w[((n_2 - 1) - j_2)]));
          _L__for1_step:
          j_2 := (j_2 + 1);
        end;
      end;
      {$else}
      j_2 := 0;
      while (j_2 < n_2) do
      begin
        f^.channel_buffers[i_3][(left_2 + j_2)] := ((f^.channel_buffers[i_3][(left_2 + j_2)] * w[j_2]) + (f^.previous_window[i_3][j_2] * w[((n_2 - 1) - j_2)]));
        _L__for1_step:
        j_2 := (j_2 + 1);
      end;
      {$endif}
      _L__for0_step:
      i_3 := (i_3 + 1);
    end;
  end;
  prev := f^.previous_length;
  f^.previous_length := (len_2 - right_2);
  i_2 := 0;
  while (i_2 < f^.channels) do
  begin
    { 手工优化段：连续平面拷贝走 System.Move（libc 级向量化），语义同逐元素 }
    if use_move and ((len_2 - right_2) > 0) then
      Move((f^.channel_buffers[i_2] + right_2)^, (f^.previous_window[i_2] + 0)^, LongInt(len_2 - right_2) * SizeOf(Single));
    {$ifdef C2P_NO_MOVE}
    j := 0;
    while (j + right_2 < len_2) do
    begin
      f^.previous_window[i_2][j] := f^.channel_buffers[i_2][(right_2 + j)];
      inc(j);
    end;
    {$endif}
    _L__for2_step:
    i_2 := (i_2 + 1);
  end;
  if (prev = 0) then
  begin
    Result := 0;
    System.Exit;
  end;
  if (len_2 < right_2) then
  begin
    right_2 := len_2;
  end;
  f^.samples_output := (f^.samples_output + LongWord((right_2 - left_2)));
  Result := (right_2 - left_2);
end;

function vorbis_pump_first_frame(f: PStbVorbis): LongInt; inline;
var
  len_2: LongInt;
  right_2: LongInt;
  left_2: LongInt;
  res_2: LongInt;
begin
  res_2 := vorbis_decode_packet(f, @len_2, @left_2, @right_2);
  if (res_2 <> 0) then
  begin
    vorbis_finish_frame(f, len_2, left_2, right_2);
  end;
  Result := res_2;
end;

function is_whole_packet_present(f: PStbVorbis): LongInt; inline;
label _L__for0_step, _L__for1_step;
var
  s_2: LongInt;
  first: LongInt;
  p_2: PUint8;
  q: PUint8;
  n_2: LongInt;
begin
  s_2 := f^.next_seg;
  first := 1;
  p_2 := f^.stream;
  if (s_2 <> -1) then
  begin
    while (s_2 < f^.segment_count) do
    begin
      p_2 := (p_2 + f^.segments[s_2]);
      if (f^.segments[s_2] < 255) then
      begin
        Break;
      end;
      _L__for0_step:
      s_2 := (s_2 + 1);
    end;
    if (s_2 = f^.segment_count) then
    begin
      s_2 := -1;
    end;
    if (p_2 > f^.stream_end) then
    begin
      Result := error(f, VORBIS_need_more_data);
      System.Exit;
    end;
    first := 0;
  end;
  while (s_2 = -1) do
  begin
    if ((p_2 + 26) >= f^.stream_end) then
    begin
      Result := error(f, VORBIS_need_more_data);
      System.Exit;
    end;
    if (__c2p_stdlib_memcmp(p_2, Pointer(@ogg_page_header[0]), TSizeT(4)) <> 0) then
    begin
      Result := error(f, VORBIS_invalid_stream);
      System.Exit;
    end;
    if (p_2[4] <> 0) then
    begin
      Result := error(f, VORBIS_invalid_stream);
      System.Exit;
    end;
    if (first <> 0) then
    begin
      if (f^.previous_length <> 0) then
      begin
        if ((LongInt(p_2[5]) and 1) <> 0) then
        begin
          Result := error(f, VORBIS_invalid_stream);
          System.Exit;
        end;
      end;
    end
    else
    begin
      if ((LongInt(p_2[5]) and 1) = 0) then
      begin
        Result := error(f, VORBIS_invalid_stream);
        System.Exit;
      end;
    end;
    n_2 := LongInt(p_2[26]);
    q := (p_2 + 27);
    p_2 := (q + n_2);
    if (p_2 > f^.stream_end) then
    begin
      Result := error(f, VORBIS_need_more_data);
      System.Exit;
    end;
    s_2 := 0;
    while (s_2 < n_2) do
    begin
      p_2 := (p_2 + q[s_2]);
      if (q[s_2] < 255) then
      begin
        Break;
      end;
      _L__for1_step:
      s_2 := (s_2 + 1);
    end;
    if (s_2 = n_2) then
    begin
      s_2 := -1;
    end;
    if (p_2 > f^.stream_end) then
    begin
      Result := error(f, VORBIS_need_more_data);
      System.Exit;
    end;
    first := 0;
  end;
  Result := 1;
end;

function start_decoder(f: PVorb): LongInt;
label _L_skip, _L__for0_step, _L__for1_step, _L__for2_step, _L__for3_step, _L__for4_step, _L__for5_step, _L__for6_step, _L__for7_step, _L__for8_step, _L__for9_step, _L__for10_step, _L__for11_step, _L__for12_step, _L__for13_step, _L__for14_step, _L__for15_step, _L__for16_step, _L__for17_step, _L__for18_step, _L__for19_step, _L__for20_step, _L__for21_step, _L__for22_step, _L__for23_step, _L__for24_step, _L__for25_step, _L__for26_step, _L__for27_step, _L__for28_step, _L__for29_step, _L__for30_step, _L__for31_step, _L__for32_step, _L__for33_step, _L__for34_step, _L__for35_step, _L__for36_step, _L__for37_step;
var
  header: array[0..5] of TUint8;
  x_2: TUint8;
  y_2: TUint8;
  len_2: LongInt;
  i_2: LongInt;
  j: LongInt;
  k: LongInt;
  max_submaps: LongInt;
  longest_floorlist: LongInt;
  log0: LongInt;
  log1: LongInt;
  values: PUint32;
  ordered: LongInt;
  sorted_count: LongInt;
  total: LongInt;
  lengths: PUint8;
  c: PCodebook;
  current_entry: LongInt;
  current_length: LongInt;
  limit: LongInt;
  n_2: LongInt;
  present: LongInt;
  size: LongWord;
  mults: PUint16;
  values_2: LongInt;
  q: LongInt;
  len_3: LongInt;
  sparse: LongInt;
  last: Single;
  z_2: LongWord;
  &div: LongWord;
  off: LongInt;
  val: Single;
  last_2: Single;
  val_2: Single;
  z_3: TUint32;
  g: PFloor0;
  p_2: array[0..249] of TStbvXFloorOrdering;
  g_2: PFloor1;
  max_class: LongInt;
  c_2: LongInt;
  low: LongInt;
  hi_2: LongInt;
  residue_cascade: array[0..63] of TUint8;
  r: PResidue;
  high_bits: TUint8;
  low_bits: TUint8;
  classwords: LongInt;
  temp_2: LongInt;
  m: PMapping;
  mapping_type: LongInt;
  m_2: PMode;
  imdct_mem: TUint32;
  classify_mem: TUint32;
  i_3: LongInt;
  max_part_read: LongInt;
  r_2: PResidue;
  actual_size: LongWord;
  limit_r_begin: LongWord;
  limit_r_end: LongWord;
  n_read: LongInt;
  part_read: LongInt;
  __c2p_tmp1: LongInt;
  __c2p_tmp2: LongInt;
  __c2p_tmp3: LongInt;
  __c2p_tmp4: LongInt;
  __c2p_tmp5: LongInt;
  __c2p_tmp6: LongInt;
  __c2p_tmp7: LongInt;
  __c2p_tmp8: LongInt;
  __c2p_tmp9: LongInt;
  __c2p_tmp10: LongWord;
  __c2p_tmp11: PUint8;
  __c2p_tmp12: LongWord;
  __c2p_tmp13: LongInt;
  __c2p_tmp14: LongInt;
  __c2p_tmp15: LongWord;
  __c2p_tmp16: LongWord;
begin
  max_submaps := 0;
  longest_floorlist := 0;
  f^.first_decode := TUint8(1);
  if (start_page(f) = 0) then
  begin
    Result := 0;
    System.Exit;
  end;
  if ((LongInt(f^.page_flag) and 2) = 0) then
  begin
    Result := error(f, VORBIS_invalid_first_page);
    System.Exit;
  end;
  if ((LongInt(f^.page_flag) and 4) <> 0) then
  begin
    Result := error(f, VORBIS_invalid_first_page);
    System.Exit;
  end;
  if ((LongInt(f^.page_flag) and 1) <> 0) then
  begin
    Result := error(f, VORBIS_invalid_first_page);
    System.Exit;
  end;
  if (f^.segment_count <> 1) then
  begin
    Result := error(f, VORBIS_invalid_first_page);
    System.Exit;
  end;
  if (f^.segments[0] <> 30) then
  begin
    __c2p_tmp1 := LongInt(0);
    __c2p_tmp2 := LongInt(0);
    __c2p_tmp3 := LongInt(0);
    __c2p_tmp4 := LongInt(0);
    __c2p_tmp5 := LongInt(0);
    __c2p_tmp6 := LongInt(0);
    __c2p_tmp7 := LongInt(0);
    __c2p_tmp8 := LongInt(0);
    __c2p_tmp9 := LongInt(0);
    if (f^.segments[0] = 64) then
    begin
      __c2p_tmp9 := LongInt((getn(f, PUint8(@header[0]), 6) <> 0));
    end;
    if (__c2p_tmp9 <> 0) then
    begin
      __c2p_tmp8 := LongInt((header[0] = 102));
    end;
    if (__c2p_tmp8 <> 0) then
    begin
      __c2p_tmp7 := LongInt((header[1] = 105));
    end;
    if (__c2p_tmp7 <> 0) then
    begin
      __c2p_tmp6 := LongInt((header[2] = 115));
    end;
    if (__c2p_tmp6 <> 0) then
    begin
      __c2p_tmp5 := LongInt((header[3] = 104));
    end;
    if (__c2p_tmp5 <> 0) then
    begin
      __c2p_tmp4 := LongInt((header[4] = 101));
    end;
    if (__c2p_tmp4 <> 0) then
    begin
      __c2p_tmp3 := LongInt((header[5] = 97));
    end;
    if (__c2p_tmp3 <> 0) then
    begin
      __c2p_tmp2 := LongInt((get8(f) = 100));
    end;
    if (__c2p_tmp2 <> 0) then
    begin
      __c2p_tmp1 := LongInt((get8(f) = 0));
    end;
    if (__c2p_tmp1 <> 0) then
    begin
      Result := error(f, VORBIS_ogg_skeleton_not_supported);
      System.Exit;
    end
    else
    begin
      Result := error(f, VORBIS_invalid_first_page);
      System.Exit;
    end;
  end;
  if (get8(f) <> VORBIS_packet_id) then
  begin
    Result := error(f, VORBIS_invalid_first_page);
    System.Exit;
  end;
  if (getn(f, PUint8(@header[0]), 6) = 0) then
  begin
    Result := error(f, VORBIS_unexpected_eof);
    System.Exit;
  end;
  if (vorbis_validate(PUint8(@header[0])) = 0) then
  begin
    Result := error(f, VORBIS_invalid_first_page);
    System.Exit;
  end;
  if (get32(f) <> LongWord(0)) then
  begin
    Result := error(f, VORBIS_invalid_first_page);
    System.Exit;
  end;
  f^.channels := LongInt(get8(f));
  if (f^.channels = 0) then
  begin
    Result := error(f, VORBIS_invalid_first_page);
    System.Exit;
  end;
  if (f^.channels > 16) then
  begin
    Result := error(f, VORBIS_too_many_channels);
    System.Exit;
  end;
  f^.sample_rate := get32(f);
  if (f^.sample_rate = 0) then
  begin
    Result := error(f, VORBIS_invalid_first_page);
    System.Exit;
  end;
  get32(f);
  get32(f);
  get32(f);
  x_2 := TUint8(get8(f));
  log0 := (LongInt(x_2) and 15);
  log1 := (LongInt(x_2) shr 4);
  f^.blocksize_0 := (1 shl log0);
  f^.blocksize_1 := (1 shl log1);
  if ((log0 < 6) or (log0 > 13)) then
  begin
    Result := error(f, VORBIS_invalid_setup);
    System.Exit;
  end;
  if ((log1 < 6) or (log1 > 13)) then
  begin
    Result := error(f, VORBIS_invalid_setup);
    System.Exit;
  end;
  if (log0 > log1) then
  begin
    Result := error(f, VORBIS_invalid_setup);
    System.Exit;
  end;
  x_2 := TUint8(get8(f));
  if ((LongInt(x_2) and 1) = 0) then
  begin
    Result := error(f, VORBIS_invalid_first_page);
    System.Exit;
  end;
  if (start_page(f) = 0) then
  begin
    Result := 0;
    System.Exit;
  end;
  if (start_packet(f) = 0) then
  begin
    Result := 0;
    System.Exit;
  end;
  if (next_segment(f) = 0) then
  begin
    Result := 0;
    System.Exit;
  end;
  if (get8_packet(f) <> VORBIS_packet_comment) then
  begin
    Result := error(f, VORBIS_invalid_setup);
    System.Exit;
  end;
  i_2 := 0;
  while (i_2 < 6) do
  begin
    header[i_2] := TUint8(get8_packet(f));
    _L__for0_step:
    i_2 := (i_2 + 1);
  end;
  if (vorbis_validate(PUint8(@header[0])) = 0) then
  begin
    Result := error(f, VORBIS_invalid_setup);
    System.Exit;
  end;
  len_2 := get32_packet(f);
  f^.vendor := PAnsiChar(setup_malloc(f, LongInt(QWord((1 * QWord((len_2 + 1)))))));
  if (f^.vendor = nil) then
  begin
    Result := error(f, VORBIS_outofmem);
    System.Exit;
  end;
  i_2 := 0;
  while (i_2 < len_2) do
  begin
    f^.vendor[i_2] := AnsiChar(get8_packet(f));
    _L__for1_step:
    i_2 := (i_2 + 1);
  end;
  f^.vendor[len_2] := AnsiChar(0);
  f^.comment_list_length := get32_packet(f);
  f^.comment_list := nil;
  if (f^.comment_list_length > 0) then
  begin
    f^.comment_list := PPAnsiChar(setup_malloc(f, LongInt(QWord((8 * QWord(f^.comment_list_length))))));
    if (f^.comment_list = nil) then
    begin
      Result := error(f, VORBIS_outofmem);
      System.Exit;
    end;
  end;
  i_2 := 0;
  while (i_2 < f^.comment_list_length) do
  begin
    len_2 := get32_packet(f);
    f^.comment_list[i_2] := PAnsiChar(setup_malloc(f, LongInt(QWord((1 * QWord((len_2 + 1)))))));
    if (f^.comment_list[i_2] = nil) then
    begin
      Result := error(f, VORBIS_outofmem);
      System.Exit;
    end;
    j := 0;
    while (j < len_2) do
    begin
      f^.comment_list[i_2][j] := AnsiChar(get8_packet(f));
      _L__for3_step:
      j := (j + 1);
    end;
    f^.comment_list[i_2][len_2] := AnsiChar(0);
    _L__for2_step:
    i_2 := (i_2 + 1);
  end;
  x_2 := TUint8(get8_packet(f));
  if ((LongInt(x_2) and 1) = 0) then
  begin
    Result := error(f, VORBIS_invalid_setup);
    System.Exit;
  end;
  skip(f, LongInt(f^.bytes_in_seg));
  f^.bytes_in_seg := TUint8(0);
  repeat
    len_2 := next_segment(f);
    skip(f, len_2);
    f^.bytes_in_seg := TUint8(0);
  until (len_2 = 0);
  if (start_packet(f) = 0) then
  begin
    Result := 0;
    System.Exit;
  end;
  if (LongInt(f^.push_mode) <> 0) then
  begin
    if (is_whole_packet_present(f) = 0) then
    begin
      if (LongInt(f^.error) = VORBIS_invalid_stream) then
      begin
        f^.error := VORBIS_invalid_setup;
      end;
      Result := 0;
      System.Exit;
    end;
  end;
  crc32_init();
  if (get8_packet(f) <> VORBIS_packet_setup) then
  begin
    Result := error(f, VORBIS_invalid_setup);
    System.Exit;
  end;
  i_2 := 0;
  while (i_2 < 6) do
  begin
    header[i_2] := TUint8(get8_packet(f));
    _L__for4_step:
    i_2 := (i_2 + 1);
  end;
  if (vorbis_validate(PUint8(@header[0])) = 0) then
  begin
    Result := error(f, VORBIS_invalid_setup);
    System.Exit;
  end;
  f^.codebook_count := LongInt(LongWord((get_bits(f, 8) + 1)));
  f^.codebooks := PCodebook(setup_malloc(f, LongInt(QWord((2120 * QWord(f^.codebook_count))))));
  if (f^.codebooks = nil) then
  begin
    Result := error(f, VORBIS_outofmem);
    System.Exit;
  end;
  __c2p_stdlib_memset(f^.codebooks, 0, TSizeT(QWord((2120 * QWord(f^.codebook_count)))));
  i_2 := 0;
  while (i_2 < f^.codebook_count) do
  begin
    total := 0;
    c := (f^.codebooks + i_2);
    x_2 := TUint8(get_bits(f, 8));
    if (x_2 <> 66) then
    begin
      Result := error(f, VORBIS_invalid_setup);
      System.Exit;
    end;
    x_2 := TUint8(get_bits(f, 8));
    if (x_2 <> 67) then
    begin
      Result := error(f, VORBIS_invalid_setup);
      System.Exit;
    end;
    x_2 := TUint8(get_bits(f, 8));
    if (x_2 <> 86) then
    begin
      Result := error(f, VORBIS_invalid_setup);
      System.Exit;
    end;
    x_2 := TUint8(get_bits(f, 8));
    c^.dimensions := LongInt(LongWord(((get_bits(f, 8) shl 8) + LongInt(x_2))));
    x_2 := TUint8(get_bits(f, 8));
    y_2 := TUint8(get_bits(f, 8));
    c^.entries := LongInt(LongWord((LongWord(((get_bits(f, 8) shl 16) + (LongInt(y_2) shl 8))) + LongInt(x_2))));
    ordered := LongInt(get_bits(f, 1));
    if (ordered <> 0) then
    begin
      __c2p_tmp10 := LongWord(0);
    end
    else
    begin
      __c2p_tmp10 := get_bits(f, 1);
    end;
    c^.sparse := TUint8(__c2p_tmp10);
    if ((c^.dimensions = 0) and (c^.entries <> 0)) then
    begin
      Result := error(f, VORBIS_invalid_setup);
      System.Exit;
    end;
    if (LongInt(c^.sparse) <> 0) then
    begin
      lengths := PUint8(setup_temp_malloc(f, c^.entries));
    end
    else
    begin
      __c2p_tmp11 := PUint8(setup_malloc(f, c^.entries));
      c^.codeword_lengths := __c2p_tmp11;
      lengths := __c2p_tmp11;
    end;
    if (lengths = nil) then
    begin
      Result := error(f, VORBIS_outofmem);
      System.Exit;
    end;
    if (ordered <> 0) then
    begin
      current_entry := 0;
      current_length := LongInt(LongWord((get_bits(f, 5) + 1)));
      while (current_entry < c^.entries) do
      begin
        limit := (c^.entries - current_entry);
        n_2 := LongInt(get_bits(f, ilog(TInt32(limit))));
        if (current_length >= 32) then
        begin
          Result := error(f, VORBIS_invalid_setup);
          System.Exit;
        end;
        if ((current_entry + n_2) > LongInt(c^.entries)) then
        begin
          Result := error(f, VORBIS_invalid_setup);
          System.Exit;
        end;
        __c2p_stdlib_memset((lengths + current_entry), current_length, TSizeT(n_2));
        current_entry := (current_entry + n_2);
        current_length := (current_length + 1);
      end;
    end
    else
    begin
      j := 0;
      while (j < c^.entries) do
      begin
        if (LongInt(c^.sparse) <> 0) then
        begin
          __c2p_tmp12 := get_bits(f, 1);
        end
        else
        begin
          __c2p_tmp12 := LongWord(1);
        end;
        present := LongInt(__c2p_tmp12);
        if (present <> 0) then
        begin
          lengths[j] := TUint8(LongWord((get_bits(f, 5) + 1)));
          total := (total + 1);
          if (lengths[j] = 32) then
          begin
            Result := error(f, VORBIS_invalid_setup);
            System.Exit;
          end;
        end
        else
        begin
          lengths[j] := TUint8(255);
        end;
        _L__for6_step:
        j := (j + 1);
      end;
    end;
    if ((LongInt(c^.sparse) <> 0) and (total >= __c2p_sar_longint(c^.entries, 2))) then
    begin
      if (c^.entries > LongInt(f^.setup_temp_memory_required)) then
      begin
        f^.setup_temp_memory_required := LongWord(c^.entries);
      end;
      c^.codeword_lengths := PUint8(setup_malloc(f, c^.entries));
      if (c^.codeword_lengths = nil) then
      begin
        Result := error(f, VORBIS_outofmem);
        System.Exit;
      end;
      __c2p_stdlib_memcpy(c^.codeword_lengths, lengths, TSizeT(c^.entries));
      setup_temp_free(f, lengths, c^.entries);
      lengths := c^.codeword_lengths;
      c^.sparse := TUint8(0);
    end;
    if (LongInt(c^.sparse) <> 0) then
    begin
      sorted_count := total;
    end
    else
    begin
      sorted_count := 0;
      j := 0;
      while (j < c^.entries) do
      begin
        if ((lengths[j] > 10) and (lengths[j] <> 255)) then
        begin
          sorted_count := (sorted_count + 1);
        end;
        _L__for7_step:
        j := (j + 1);
      end;
    end;
    c^.sorted_entries := sorted_count;
    values := nil;
    if (LongInt(c^.sparse) = 0) then
    begin
      c^.codewords := PUint32(setup_malloc(f, LongInt(QWord((4 * QWord(c^.entries))))));
      if (c^.codewords = nil) then
      begin
        Result := error(f, VORBIS_outofmem);
        System.Exit;
      end;
    end
    else
    begin
      if (c^.sorted_entries <> 0) then
      begin
        c^.codeword_lengths := PUint8(setup_malloc(f, c^.sorted_entries));
        if (c^.codeword_lengths = nil) then
        begin
          Result := error(f, VORBIS_outofmem);
          System.Exit;
        end;
        c^.codewords := PUint32(setup_temp_malloc(f, LongInt(QWord((4 * QWord(c^.sorted_entries))))));
        if (c^.codewords = nil) then
        begin
          Result := error(f, VORBIS_outofmem);
          System.Exit;
        end;
        values := PUint32(setup_temp_malloc(f, LongInt(QWord((4 * QWord(c^.sorted_entries))))));
        if (values = nil) then
        begin
          Result := error(f, VORBIS_outofmem);
          System.Exit;
        end;
      end;
      size := LongWord((c^.entries + QWord(((4 + 4) * QWord(c^.sorted_entries)))));
      if (size > f^.setup_temp_memory_required) then
      begin
        f^.setup_temp_memory_required := size;
      end;
    end;
    if (compute_codewords(c, lengths, c^.entries, values) = 0) then
    begin
      if (LongInt(c^.sparse) <> 0) then
      begin
        setup_temp_free(f, values, 0);
      end;
      Result := error(f, VORBIS_invalid_setup);
      System.Exit;
    end;
    if (c^.sorted_entries <> 0) then
    begin
      c^.sorted_codewords := PUint32(setup_malloc(f, LongInt(QWord((4 * QWord((c^.sorted_entries + 1)))))));
      if (c^.sorted_codewords = nil) then
      begin
        Result := error(f, VORBIS_outofmem);
        System.Exit;
      end;
      c^.sorted_values := PLongInt(setup_malloc(f, LongInt(QWord((4 * QWord((c^.sorted_entries + 1)))))));
      if (c^.sorted_values = nil) then
      begin
        Result := error(f, VORBIS_outofmem);
        System.Exit;
      end;
      c^.sorted_values := (c^.sorted_values + 1);
      c^.sorted_values[-1] := -1;
      compute_sorted_huffman(c, lengths, values);
    end;
    if (LongInt(c^.sparse) <> 0) then
    begin
      setup_temp_free(f, values, LongInt(QWord((4 * QWord(c^.sorted_entries)))));
      setup_temp_free(f, c^.codewords, LongInt(QWord((4 * QWord(c^.sorted_entries)))));
      setup_temp_free(f, lengths, c^.entries);
      c^.codewords := nil;
    end;
    compute_accelerated_huffman(c);
    c^.lookup_type := TUint8(get_bits(f, 4));
    if (c^.lookup_type > 2) then
    begin
      Result := error(f, VORBIS_invalid_setup);
      System.Exit;
    end;
    if (c^.lookup_type > 0) then
    begin
      c^.minimum_value := float32_unpack(TUint32(get_bits(f, 32)));
      c^.delta_value := float32_unpack(TUint32(get_bits(f, 32)));
      c^.value_bits := TUint8(LongWord((get_bits(f, 4) + 1)));
      c^.sequence_p := TUint8(get_bits(f, 1));
      if (c^.lookup_type = 1) then
      begin
        values_2 := lookup1_values(c^.entries, c^.dimensions);
        if (values_2 < 0) then
        begin
          Result := error(f, VORBIS_invalid_setup);
          System.Exit;
        end;
        c^.lookup_values := TUint32(values_2);
      end
      else
      begin
        c^.lookup_values := TUint32((c^.entries * c^.dimensions));
      end;
      if (c^.lookup_values = LongWord(0)) then
      begin
        Result := error(f, VORBIS_invalid_setup);
        System.Exit;
      end;
      mults := PUint16(setup_temp_malloc(f, LongInt(QWord((2 * QWord(c^.lookup_values))))));
      if (mults = nil) then
      begin
        Result := error(f, VORBIS_outofmem);
        System.Exit;
      end;
      j := 0;
      while (j < LongInt(c^.lookup_values)) do
      begin
        q := LongInt(get_bits(f, LongInt(c^.value_bits)));
        if (q = -1) then
        begin
          setup_temp_free(f, mults, LongInt(QWord((2 * QWord(c^.lookup_values)))));
          Result := error(f, VORBIS_invalid_setup);
          System.Exit;
        end;
        mults[j] := TUint16(q);
        _L__for8_step:
        j := (j + 1);
      end;
      if (c^.lookup_type = 1) then
      begin
        sparse := LongInt(c^.sparse);
        last := 0;
        if (sparse <> 0) then
        begin
          if (c^.sorted_entries = 0) then
          begin
            goto _L_skip;
          end;
          c^.multiplicands := PCodetype(setup_malloc(f, LongInt(QWord((QWord((4 * QWord(c^.sorted_entries))) * QWord(c^.dimensions))))));
        end
        else
        begin
          c^.multiplicands := PCodetype(setup_malloc(f, LongInt(QWord((QWord((4 * QWord(c^.entries))) * QWord(c^.dimensions))))));
        end;
        if (c^.multiplicands = nil) then
        begin
          setup_temp_free(f, mults, LongInt(QWord((2 * QWord(c^.lookup_values)))));
          Result := error(f, VORBIS_outofmem);
          System.Exit;
        end;
        if (sparse <> 0) then
        begin
          __c2p_tmp13 := c^.sorted_entries;
        end
        else
        begin
          __c2p_tmp13 := c^.entries;
        end;
        len_3 := __c2p_tmp13;
        j := 0;
        while (j < len_3) do
        begin
          if (sparse <> 0) then
          begin
            __c2p_tmp14 := c^.sorted_values[j];
          end
          else
          begin
            __c2p_tmp14 := j;
          end;
          z_2 := LongWord(__c2p_tmp14);
          &div := LongWord(1);
          k := 0;
          while (k < c^.dimensions) do
          begin
            off := LongInt(((z_2 div &div) mod c^.lookup_values));
            val := (((mults[off] * c^.delta_value) + c^.minimum_value) + last);
            c^.multiplicands[((j * c^.dimensions) + k)] := val;
            if (LongInt(c^.sequence_p) <> 0) then
            begin
              last := val;
            end;
            if ((k + 1) < c^.dimensions) then
            begin
              if (&div > (LongWord(4294967295) div LongWord(c^.lookup_values))) then
              begin
                setup_temp_free(f, mults, LongInt(QWord((2 * QWord(c^.lookup_values)))));
                Result := error(f, VORBIS_invalid_setup);
                System.Exit;
              end;
              &div := (&div * c^.lookup_values);
            end;
            _L__for10_step:
            k := (k + 1);
          end;
          _L__for9_step:
          j := (j + 1);
        end;
        c^.lookup_type := TUint8(2);
      end
      else
      begin
        last_2 := 0;
        c^.multiplicands := PCodetype(setup_malloc(f, LongInt(QWord((4 * QWord(c^.lookup_values))))));
        if (c^.multiplicands = nil) then
        begin
          setup_temp_free(f, mults, LongInt(QWord((2 * QWord(c^.lookup_values)))));
          Result := error(f, VORBIS_outofmem);
          System.Exit;
        end;
        j := 0;
        while (j < LongInt(c^.lookup_values)) do
        begin
          val_2 := (((mults[j] * c^.delta_value) + c^.minimum_value) + last_2);
          c^.multiplicands[j] := val_2;
          if (LongInt(c^.sequence_p) <> 0) then
          begin
            last_2 := val_2;
          end;
          _L__for11_step:
          j := (j + 1);
        end;
      end;
      _L_skip:
      setup_temp_free(f, mults, LongInt(QWord((2 * QWord(c^.lookup_values)))));
    end;
    _L__for5_step:
    i_2 := (i_2 + 1);
  end;
  x_2 := TUint8(LongWord((get_bits(f, 6) + 1)));
  i_2 := 0;
  while (i_2 < x_2) do
  begin
    z_3 := get_bits(f, 16);
    if (z_3 <> LongWord(0)) then
    begin
      Result := error(f, VORBIS_invalid_setup);
      System.Exit;
    end;
    _L__for12_step:
    i_2 := (i_2 + 1);
  end;
  f^.floor_count := LongInt(LongWord((get_bits(f, 6) + 1)));
  f^.floor_config := PFloor(setup_malloc(f, LongInt(QWord((QWord(f^.floor_count) * 1596)))));
  if (f^.floor_config = nil) then
  begin
    Result := error(f, VORBIS_outofmem);
    System.Exit;
  end;
  i_2 := 0;
  while (i_2 < f^.floor_count) do
  begin
    f^.floor_types[i_2] := TUint16(get_bits(f, 16));
    if (f^.floor_types[i_2] > 1) then
    begin
      Result := error(f, VORBIS_invalid_setup);
      System.Exit;
    end;
    if (f^.floor_types[i_2] = 0) then
    begin
      g := @f^.floor_config[i_2].floor0;
      g^.order := TUint8(get_bits(f, 8));
      g^.rate := TUint16(get_bits(f, 16));
      g^.bark_map_size := TUint16(get_bits(f, 16));
      g^.amplitude_bits := TUint8(get_bits(f, 6));
      g^.amplitude_offset := TUint8(get_bits(f, 8));
      g^.number_of_books := TUint8(LongWord((get_bits(f, 4) + 1)));
      j := 0;
      while (j < g^.number_of_books) do
      begin
        g^.book_list[j] := TUint8(get_bits(f, 8));
        _L__for14_step:
        j := (j + 1);
      end;
      Result := error(f, VORBIS_feature_not_supported);
      System.Exit;
    end
    else
    begin
      g_2 := @f^.floor_config[i_2].floor1;
      max_class := -1;
      g_2^.partitions := TUint8(get_bits(f, 5));
      j := 0;
      while (j < g_2^.partitions) do
      begin
        g_2^.partition_class_list[j] := TUint8(get_bits(f, 4));
        if (g_2^.partition_class_list[j] > max_class) then
        begin
          max_class := LongInt(g_2^.partition_class_list[j]);
        end;
        _L__for15_step:
        j := (j + 1);
      end;
      j := 0;
      while (j <= max_class) do
      begin
        g_2^.class_dimensions[j] := TUint8(LongWord((get_bits(f, 3) + 1)));
        g_2^.class_subclasses[j] := TUint8(get_bits(f, 2));
        if (LongInt(g_2^.class_subclasses[j]) <> 0) then
        begin
          g_2^.class_masterbooks[j] := TUint8(get_bits(f, 8));
          if (g_2^.class_masterbooks[j] >= f^.codebook_count) then
          begin
            Result := error(f, VORBIS_invalid_setup);
            System.Exit;
          end;
        end;
        k := 0;
        while (k < (1 shl LongInt(g_2^.class_subclasses[j]))) do
        begin
          g_2^.subclass_books[j][k] := TInt16((LongInt(TInt16(get_bits(f, 8))) - 1));
          if (LongInt(g_2^.subclass_books[j][k]) >= f^.codebook_count) then
          begin
            Result := error(f, VORBIS_invalid_setup);
            System.Exit;
          end;
          _L__for17_step:
          k := (k + 1);
        end;
        _L__for16_step:
        j := (j + 1);
      end;
      g_2^.floor1_multiplier := TUint8(LongWord((get_bits(f, 2) + 1)));
      g_2^.rangebits := TUint8(get_bits(f, 4));
      g_2^.Xlist[0] := TUint16(0);
      g_2^.Xlist[1] := TUint16((1 shl LongInt(g_2^.rangebits)));
      g_2^.values := 2;
      j := 0;
      while (j < g_2^.partitions) do
      begin
        c_2 := LongInt(g_2^.partition_class_list[j]);
        k := 0;
        while (k < g_2^.class_dimensions[c_2]) do
        begin
          g_2^.Xlist[g_2^.values] := TUint16(get_bits(f, LongInt(g_2^.rangebits)));
          g_2^.values := (g_2^.values + 1);
          _L__for19_step:
          k := (k + 1);
        end;
        _L__for18_step:
        j := (j + 1);
      end;
      j := 0;
      while (j < g_2^.values) do
      begin
        p_2[j].x := TUint16(g_2^.Xlist[j]);
        p_2[j].id := TUint16(j);
        _L__for20_step:
        j := (j + 1);
      end;
      qsort(Pointer(@p_2[0]), TSizeT(g_2^.values), TSizeT(4), TRawProc9779B54A(Pointer(@point_compare)));
      j := 0;
      while (j < (g_2^.values - 1)) do
      begin
        if (p_2[j].x = p_2[(j + 1)].x) then
        begin
          Result := error(f, VORBIS_invalid_setup);
          System.Exit;
        end;
        _L__for21_step:
        j := (j + 1);
      end;
      j := 0;
      while (j < g_2^.values) do
      begin
        g_2^.sorted_order[j] := TUint8(p_2[j].id);
        _L__for22_step:
        j := (j + 1);
      end;
      j := 2;
      while (j < g_2^.values) do
      begin
        low := 0;
        hi_2 := 0;
        neighbors(PUint16(@g_2^.Xlist[0]), j, @low, @hi_2);
        g_2^.neighbors[j][0] := TUint8(low);
        g_2^.neighbors[j][1] := TUint8(hi_2);
        _L__for23_step:
        j := (j + 1);
      end;
      if (g_2^.values > longest_floorlist) then
      begin
        longest_floorlist := g_2^.values;
      end;
    end;
    _L__for13_step:
    i_2 := (i_2 + 1);
  end;
  f^.residue_count := LongInt(LongWord((get_bits(f, 6) + 1)));
  f^.residue_config := PResidue(setup_malloc(f, LongInt(QWord((QWord(f^.residue_count) * 32)))));
  if (f^.residue_config = nil) then
  begin
    Result := error(f, VORBIS_outofmem);
    System.Exit;
  end;
  __c2p_stdlib_memset(f^.residue_config, 0, TSizeT(QWord((QWord(f^.residue_count) * 32))));
  i_2 := 0;
  while (i_2 < f^.residue_count) do
  begin
    r := (f^.residue_config + i_2);
    f^.residue_types[i_2] := TUint16(get_bits(f, 16));
    if (f^.residue_types[i_2] > 2) then
    begin
      Result := error(f, VORBIS_invalid_setup);
      System.Exit;
    end;
    r^.&begin := get_bits(f, 24);
    r^.&end := get_bits(f, 24);
    if (r^.&end < r^.&begin) then
    begin
      Result := error(f, VORBIS_invalid_setup);
      System.Exit;
    end;
    r^.part_size := LongWord((get_bits(f, 24) + 1));
    r^.classifications := TUint8(LongWord((get_bits(f, 6) + 1)));
    r^.classbook := TUint8(get_bits(f, 8));
    if (r^.classbook >= f^.codebook_count) then
    begin
      Result := error(f, VORBIS_invalid_setup);
      System.Exit;
    end;
    j := 0;
    while (j < r^.classifications) do
    begin
      high_bits := TUint8(0);
      low_bits := TUint8(get_bits(f, 3));
      if (get_bits(f, 1) <> 0) then
      begin
        high_bits := TUint8(get_bits(f, 5));
      end;
      residue_cascade[j] := TUint8(((LongInt(high_bits) * 8) + LongInt(low_bits)));
      _L__for25_step:
      j := (j + 1);
    end;
    r^.residue_books := PArray8OfTInt16(setup_malloc(f, LongInt(QWord((16 * QWord(LongInt(r^.classifications)))))));
    if (r^.residue_books = nil) then
    begin
      Result := error(f, VORBIS_outofmem);
      System.Exit;
    end;
    j := 0;
    while (j < r^.classifications) do
    begin
      k := 0;
      while (k < 8) do
      begin
        if ((LongInt(residue_cascade[j]) and (1 shl k)) <> 0) then
        begin
          r^.residue_books[j][k] := TInt16(get_bits(f, 8));
          if (LongInt(r^.residue_books[j][k]) >= f^.codebook_count) then
          begin
            Result := error(f, VORBIS_invalid_setup);
            System.Exit;
          end;
        end
        else
        begin
          r^.residue_books[j][k] := TInt16(-1);
        end;
        _L__for27_step:
        k := (k + 1);
      end;
      _L__for26_step:
      j := (j + 1);
    end;
    r^.classdata := PPUint8(setup_malloc(f, LongInt(QWord((8 * QWord(f^.codebooks[LongInt(r^.classbook)].entries))))));
    if (r^.classdata = nil) then
    begin
      Result := error(f, VORBIS_outofmem);
      System.Exit;
    end;
    __c2p_stdlib_memset(r^.classdata, 0, TSizeT(QWord((8 * QWord(f^.codebooks[LongInt(r^.classbook)].entries)))));
    j := 0;
    while (j < f^.codebooks[LongInt(r^.classbook)].entries) do
    begin
      classwords := f^.codebooks[LongInt(r^.classbook)].dimensions;
      temp_2 := j;
      r^.classdata[j] := PUint8(setup_malloc(f, LongInt(QWord((1 * QWord(classwords))))));
      if (r^.classdata[j] = nil) then
      begin
        Result := error(f, VORBIS_outofmem);
        System.Exit;
      end;
      k := (classwords - 1);
      while (k >= 0) do
      begin
        r^.classdata[j][k] := TUint8((temp_2 mod LongInt(r^.classifications)));
        temp_2 := (temp_2 div r^.classifications);
        _L__for29_step:
        k := (k - 1);
      end;
      _L__for28_step:
      j := (j + 1);
    end;
    _L__for24_step:
    i_2 := (i_2 + 1);
  end;
  f^.mapping_count := LongInt(LongWord((get_bits(f, 6) + 1)));
  f^.mapping := PMapping(setup_malloc(f, LongInt(QWord((QWord(f^.mapping_count) * 48)))));
  if (f^.mapping = nil) then
  begin
    Result := error(f, VORBIS_outofmem);
    System.Exit;
  end;
  __c2p_stdlib_memset(f^.mapping, 0, TSizeT(QWord((QWord(f^.mapping_count) * 48))));
  i_2 := 0;
  while (i_2 < f^.mapping_count) do
  begin
    m := (f^.mapping + i_2);
    mapping_type := LongInt(get_bits(f, 16));
    if (mapping_type <> 0) then
    begin
      Result := error(f, VORBIS_invalid_setup);
      System.Exit;
    end;
    m^.chan := PMappingChannel(setup_malloc(f, LongInt(QWord((QWord(f^.channels) * 3)))));
    if (m^.chan = nil) then
    begin
      Result := error(f, VORBIS_outofmem);
      System.Exit;
    end;
    if (get_bits(f, 1) <> 0) then
    begin
      m^.submaps := TUint8(LongWord((get_bits(f, 4) + 1)));
    end
    else
    begin
      m^.submaps := TUint8(1);
    end;
    if (m^.submaps > max_submaps) then
    begin
      max_submaps := LongInt(m^.submaps);
    end;
    if (get_bits(f, 1) <> 0) then
    begin
      m^.coupling_steps := TUint16(LongWord((get_bits(f, 8) + 1)));
      if (m^.coupling_steps > f^.channels) then
      begin
        Result := error(f, VORBIS_invalid_setup);
        System.Exit;
      end;
      k := 0;
      while (k < m^.coupling_steps) do
      begin
        m^.chan[k].magnitude := TUint8(get_bits(f, ilog(TInt32((f^.channels - 1)))));
        m^.chan[k].angle := TUint8(get_bits(f, ilog(TInt32((f^.channels - 1)))));
        if (m^.chan[k].magnitude >= f^.channels) then
        begin
          Result := error(f, VORBIS_invalid_setup);
          System.Exit;
        end;
        if (m^.chan[k].angle >= f^.channels) then
        begin
          Result := error(f, VORBIS_invalid_setup);
          System.Exit;
        end;
        if (m^.chan[k].magnitude = m^.chan[k].angle) then
        begin
          Result := error(f, VORBIS_invalid_setup);
          System.Exit;
        end;
        _L__for31_step:
        k := (k + 1);
      end;
    end
    else
    begin
      m^.coupling_steps := TUint16(0);
    end;
    if (get_bits(f, 2) <> 0) then
    begin
      Result := error(f, VORBIS_invalid_setup);
      System.Exit;
    end;
    if (m^.submaps > 1) then
    begin
      j := 0;
      while (j < f^.channels) do
      begin
        m^.chan[j].mux := TUint8(get_bits(f, 4));
        if (m^.chan[j].mux >= m^.submaps) then
        begin
          Result := error(f, VORBIS_invalid_setup);
          System.Exit;
        end;
        _L__for32_step:
        j := (j + 1);
      end;
    end
    else
    begin
      j := 0;
      while (j < f^.channels) do
      begin
        m^.chan[j].mux := TUint8(0);
        _L__for33_step:
        j := (j + 1);
      end;
    end;
    j := 0;
    while (j < m^.submaps) do
    begin
      get_bits(f, 8);
      m^.submap_floor[j] := TUint8(get_bits(f, 8));
      m^.submap_residue[j] := TUint8(get_bits(f, 8));
      if (m^.submap_floor[j] >= f^.floor_count) then
      begin
        Result := error(f, VORBIS_invalid_setup);
        System.Exit;
      end;
      if (m^.submap_residue[j] >= f^.residue_count) then
      begin
        Result := error(f, VORBIS_invalid_setup);
        System.Exit;
      end;
      _L__for34_step:
      j := (j + 1);
    end;
    _L__for30_step:
    i_2 := (i_2 + 1);
  end;
  f^.mode_count := LongInt(LongWord((get_bits(f, 6) + 1)));
  i_2 := 0;
  while (i_2 < f^.mode_count) do
  begin
    m_2 := (PMode(@f^.mode_config[0]) + i_2);
    m_2^.blockflag := TUint8(get_bits(f, 1));
    m_2^.windowtype := TUint16(get_bits(f, 16));
    m_2^.transformtype := TUint16(get_bits(f, 16));
    m_2^.mapping := TUint8(get_bits(f, 8));
    if (m_2^.windowtype <> 0) then
    begin
      Result := error(f, VORBIS_invalid_setup);
      System.Exit;
    end;
    if (m_2^.transformtype <> 0) then
    begin
      Result := error(f, VORBIS_invalid_setup);
      System.Exit;
    end;
    if (m_2^.mapping >= f^.mapping_count) then
    begin
      Result := error(f, VORBIS_invalid_setup);
      System.Exit;
    end;
    _L__for35_step:
    i_2 := (i_2 + 1);
  end;
  flush_packet(f);
  f^.previous_length := 0;
  i_2 := 0;
  while (i_2 < f^.channels) do
  begin
    f^.channel_buffers[i_2] := PSingle(setup_malloc(f, LongInt(QWord((4 * QWord(f^.blocksize_1))))));
    f^.previous_window[i_2] := PSingle(setup_malloc(f, LongInt((QWord((4 * QWord(f^.blocksize_1))) div QWord(2)))));
    f^.finalY[i_2] := PInt16(setup_malloc(f, LongInt(QWord((2 * QWord(longest_floorlist))))));
    if (((f^.channel_buffers[i_2] = nil) or (f^.previous_window[i_2] = nil)) or (f^.finalY[i_2] = nil)) then
    begin
      Result := error(f, VORBIS_outofmem);
      System.Exit;
    end;
    __c2p_stdlib_memset(f^.channel_buffers[i_2], 0, TSizeT(QWord((4 * QWord(f^.blocksize_1)))));
    _L__for36_step:
    i_2 := (i_2 + 1);
  end;
  if (init_blocksize(f, 0, f^.blocksize_0) = 0) then
  begin
    Result := 0;
    System.Exit;
  end;
  if (init_blocksize(f, 1, f^.blocksize_1) = 0) then
  begin
    Result := 0;
    System.Exit;
  end;
  f^.blocksize[0] := f^.blocksize_0;
  f^.blocksize[1] := f^.blocksize_1;
  imdct_mem := TUint32((QWord((QWord(f^.blocksize_1) * 4)) shr 1));
  max_part_read := 0;
  i_3 := 0;
  while (i_3 < f^.residue_count) do
  begin
    r_2 := (f^.residue_config + i_3);
    actual_size := LongWord((f^.blocksize_1 div 2));
    if (r_2^.&begin < actual_size) then
    begin
      __c2p_tmp15 := r_2^.&begin;
    end
    else
    begin
      __c2p_tmp15 := actual_size;
    end;
    limit_r_begin := __c2p_tmp15;
    if (r_2^.&end < actual_size) then
    begin
      __c2p_tmp16 := r_2^.&end;
    end
    else
    begin
      __c2p_tmp16 := actual_size;
    end;
    limit_r_end := __c2p_tmp16;
    n_read := LongInt(LongWord((limit_r_end - limit_r_begin)));
    part_read := LongInt((LongWord(n_read) div r_2^.part_size));
    if (part_read > max_part_read) then
    begin
      max_part_read := part_read;
    end;
    _L__for37_step:
    i_3 := (i_3 + 1);
  end;
  classify_mem := TUint32(QWord((QWord(f^.channels) * (8 + QWord((QWord(max_part_read) * 8))))));
  f^.temp_memory_required := classify_mem;
  if (imdct_mem > f^.temp_memory_required) then
  begin
    f^.temp_memory_required := imdct_mem;
  end;
  if (f^.alloc.alloc_buffer <> nil) then
  begin
    if (((f^.setup_offset + PtrUInt(SizeOf(TStbVorbis))) + f^.temp_memory_required) > QWord(LongWord(f^.temp_offset))) then
    begin
      Result := error(f, VORBIS_outofmem);
      System.Exit;
    end;
  end;
  if (f^.next_seg = -1) then
  begin
    f^.first_audio_page_offset := stb_vorbis_get_file_offset(f);
  end
  else
  begin
    f^.first_audio_page_offset := TUint32(0);
  end;
  Result := 1;
end;

procedure vorbis_deinit(p_2: PStbVorbis); inline;
label _L__for0_step, _L__for1_step, _L__for2_step, _L__for3_step, _L__for4_step, _L__for5_step, _L__for6_step;
var
  i_2: LongInt;
  j: LongInt;
  r: PResidue;
  c: PCodebook;
  __c2p_tmp1: PLongInt;
begin
  setup_free(p_2, p_2^.vendor);
  i_2 := 0;
  while (i_2 < p_2^.comment_list_length) do
  begin
    setup_free(p_2, p_2^.comment_list[i_2]);
    _L__for0_step:
    i_2 := (i_2 + 1);
  end;
  setup_free(p_2, p_2^.comment_list);
  if (p_2^.residue_config <> nil) then
  begin
    i_2 := 0;
    while (i_2 < p_2^.residue_count) do
    begin
      r := (p_2^.residue_config + i_2);
      if (r^.classdata <> nil) then
      begin
        j := 0;
        while (j < p_2^.codebooks[LongInt(r^.classbook)].entries) do
        begin
          setup_free(p_2, r^.classdata[j]);
          _L__for2_step:
          j := (j + 1);
        end;
        setup_free(p_2, r^.classdata);
      end;
      setup_free(p_2, r^.residue_books);
      _L__for1_step:
      i_2 := (i_2 + 1);
    end;
  end;
  if (p_2^.codebooks <> nil) then
  begin
    i_2 := 0;
    while (i_2 < p_2^.codebook_count) do
    begin
      c := (p_2^.codebooks + i_2);
      setup_free(p_2, c^.codeword_lengths);
      setup_free(p_2, c^.multiplicands);
      setup_free(p_2, c^.codewords);
      setup_free(p_2, c^.sorted_codewords);
      if (c^.sorted_values <> nil) then
      begin
        __c2p_tmp1 := (c^.sorted_values - 1);
      end
      else
      begin
        __c2p_tmp1 := nil;
      end;
      setup_free(p_2, __c2p_tmp1);
      _L__for3_step:
      i_2 := (i_2 + 1);
    end;
    setup_free(p_2, p_2^.codebooks);
  end;
  setup_free(p_2, p_2^.floor_config);
  setup_free(p_2, p_2^.residue_config);
  if (p_2^.mapping <> nil) then
  begin
    i_2 := 0;
    while (i_2 < p_2^.mapping_count) do
    begin
      setup_free(p_2, p_2^.mapping[i_2].chan);
      _L__for4_step:
      i_2 := (i_2 + 1);
    end;
    setup_free(p_2, p_2^.mapping);
  end;
  i_2 := 0;
  while ((i_2 < p_2^.channels) and (i_2 < 16)) do
  begin
    setup_free(p_2, p_2^.channel_buffers[i_2]);
    setup_free(p_2, p_2^.previous_window[i_2]);
    setup_free(p_2, p_2^.finalY[i_2]);
    _L__for5_step:
    i_2 := (i_2 + 1);
  end;
  i_2 := 0;
  while (i_2 < 2) do
  begin
    setup_free(p_2, p_2^.A[i_2]);
    setup_free(p_2, p_2^.B[i_2]);
    setup_free(p_2, p_2^.C[i_2]);
    setup_free(p_2, p_2^.window[i_2]);
    setup_free(p_2, p_2^.bit_reverse[i_2]);
    _L__for6_step:
    i_2 := (i_2 + 1);
  end;
  if (p_2^.close_on_free <> 0) then
  begin
    fclose(p_2^.f);
  end;
end;

procedure stb_vorbis_close(p_2: PStbVorbis); cdecl; public name 'stb_vorbis_close'; inline;
begin
  if (p_2 = nil) then
  begin
    System.Exit;
  end;
  vorbis_deinit(p_2);
  setup_free(p_2, p_2);
end;

procedure vorbis_init(p_2: PStbVorbis; z_2: PStbVorbisAlloc); inline;
begin
  __c2p_stdlib_memset(p_2, 0, TSizeT(SizeOf(TStbVorbis)));
  if (z_2 <> nil) then
  begin
    p_2^.alloc := z_2^;
    p_2^.alloc.alloc_buffer_length_in_bytes := (p_2^.alloc.alloc_buffer_length_in_bytes and LongInt(not 7));
    p_2^.temp_offset := p_2^.alloc.alloc_buffer_length_in_bytes;
  end;
  p_2^.eof := 0;
  p_2^.error := VORBIS__no_error;
  p_2^.stream := nil;
  p_2^.codebooks := nil;
  p_2^.page_crc_tests := -1;
  p_2^.close_on_free := 0;
  p_2^.f := nil;
end;

function stb_vorbis_get_sample_offset(f: PStbVorbis): LongInt; cdecl; public name 'stb_vorbis_get_sample_offset'; inline;
begin
  if (f^.current_loc_valid <> 0) then
  begin
    Result := f^.current_loc;
    System.Exit;
  end
  else
  begin
    Result := -1;
    System.Exit;
  end;
end;

function stb_vorbis_get_info(f: PStbVorbis): TStbVorbisInfo; cdecl; public name 'stb_vorbis_get_info'; inline;
var
  d_2: TStbVorbisInfo;
begin
  d_2.channels := f^.channels;
  d_2.sample_rate := f^.sample_rate;
  d_2.setup_memory_required := f^.setup_memory_required;
  d_2.setup_temp_memory_required := f^.setup_temp_memory_required;
  d_2.temp_memory_required := f^.temp_memory_required;
  d_2.max_frame_size := __c2p_sar_longint(f^.blocksize_1, 1);
  Result := d_2;
end;

function stb_vorbis_get_comment(f: PStbVorbis): TStbVorbisComment; cdecl; public name 'stb_vorbis_get_comment'; inline;
var
  d_2: TStbVorbisComment;
begin
  d_2.vendor := f^.vendor;
  d_2.comment_list_length := f^.comment_list_length;
  d_2.comment_list := f^.comment_list;
  Result := d_2;
end;

function stb_vorbis_get_error(f: PStbVorbis): LongInt; cdecl; public name 'stb_vorbis_get_error'; inline;
var
  e: LongInt;
begin
  e := f^.error;
  f^.error := VORBIS__no_error;
  Result := e;
end;

function vorbis_alloc(f: PStbVorbis): PStbVorbis; inline;
var
  p_2: PStbVorbis;
begin
  p_2 := PStbVorbis(setup_malloc(f, LongInt(SizeOf(TStbVorbis))));
  Result := p_2;
end;

procedure stb_vorbis_flush_pushdata(f: PStbVorbis); cdecl; public name 'stb_vorbis_flush_pushdata'; inline;
begin
  f^.previous_length := 0;
  f^.page_crc_tests := 0;
  f^.discard_samples_deferred := 0;
  f^.current_loc_valid := 0;
  f^.first_decode := TUint8(0);
  f^.samples_output := TUint32(0);
  f^.channel_buffer_start := 0;
  f^.channel_buffer_end := 0;
end;

function vorbis_search_for_page_pushdata(f: PVorb; data: PUint8; __c2p_arg_data_len: LongInt): LongInt; inline;
label _L__for0_step, _L__for1_step, _L__for2_step, _L__for3_step, _L__for4_step, _L__for5_step;
var
  i_2: LongInt;
  n_2: LongInt;
  j: LongInt;
  len_2: LongInt;
  crc_2: TUint32;
  crc_3: TUint32;
  j_2: LongInt;
  n_3: LongInt;
  m: LongInt;
  data_len: LongInt;
  __c2p_tmp1: LongInt;
  __c2p_tmp2: LongInt;
begin
  data_len := __c2p_arg_data_len;
  i_2 := 0;
  while (i_2 < f^.page_crc_tests) do
  begin
    f^.scan[i_2].bytes_done := 0;
    _L__for0_step:
    i_2 := (i_2 + 1);
  end;
  if (f^.page_crc_tests < 4) then
  begin
    if (data_len < 4) then
    begin
      Result := 0;
      System.Exit;
    end;
    data_len := (data_len - 3);
    i_2 := 0;
    while (i_2 < data_len) do
    begin
      if (data[i_2] = 79) then
      begin
        if (0 = __c2p_stdlib_memcmp((data + i_2), Pointer(@ogg_page_header[0]), TSizeT(4))) then
        begin
          if (((i_2 + 26) >= data_len) or (((i_2 + 27) + LongInt(data[(i_2 + 26)])) >= data_len)) then
          begin
            data_len := i_2;
            Break;
          end;
          len_2 := (27 + LongInt(data[(i_2 + 26)]));
          j := 0;
          while (j < data[(i_2 + 26)]) do
          begin
            len_2 := (len_2 + data[((i_2 + 27) + j)]);
            _L__for2_step:
            j := (j + 1);
          end;
          crc_2 := TUint32(0);
          j := 0;
          while (j < 22) do
          begin
            crc_2 := crc32_update(TUint32(crc_2), TUint8(data[(i_2 + j)]));
            _L__for3_step:
            j := (j + 1);
          end;
          while (j < 26) do
          begin
            crc_2 := crc32_update(TUint32(crc_2), TUint8(0));
            _L__for4_step:
            j := (j + 1);
          end;
          __c2p_tmp1 := f^.page_crc_tests;
          f^.page_crc_tests := (f^.page_crc_tests + 1);
          n_2 := __c2p_tmp1;
          f^.scan[n_2].bytes_left := (len_2 - j);
          f^.scan[n_2].crc_so_far := crc_2;
          f^.scan[n_2].goal_crc := TUint32((((LongInt(data[(i_2 + 22)]) + (LongInt(data[(i_2 + 23)]) shl 8)) + (LongInt(data[(i_2 + 24)]) shl 16)) + (LongInt(data[(i_2 + 25)]) shl 24)));
          if (data[(((i_2 + 27) + LongInt(data[(i_2 + 26)])) - 1)] = 255) then
          begin
            f^.scan[n_2].sample_loc := TUint32(LongInt(not 0));
          end
          else
          begin
            f^.scan[n_2].sample_loc := TUint32((((LongInt(data[(i_2 + 6)]) + (LongInt(data[(i_2 + 7)]) shl 8)) + (LongInt(data[(i_2 + 8)]) shl 16)) + (LongInt(data[(i_2 + 9)]) shl 24)));
          end;
          f^.scan[n_2].bytes_done := (i_2 + j);
          if (f^.page_crc_tests = 4) then
          begin
            Break;
          end;
        end;
      end;
      _L__for1_step:
      i_2 := (i_2 + 1);
    end;
  end;
  i_2 := 0;
  while (i_2 < f^.page_crc_tests) do
  begin
    n_3 := f^.scan[i_2].bytes_done;
    m := f^.scan[i_2].bytes_left;
    if (m > (data_len - n_3)) then
    begin
      m := (data_len - n_3);
    end;
    crc_3 := f^.scan[i_2].crc_so_far;
    j_2 := 0;
    while (j_2 < m) do
    begin
      crc_3 := crc32_update(TUint32(crc_3), TUint8(data[(n_3 + j_2)]));
      _L__for5_step:
      j_2 := (j_2 + 1);
    end;
    f^.scan[i_2].bytes_left := (f^.scan[i_2].bytes_left - m);
    f^.scan[i_2].crc_so_far := crc_3;
    if (f^.scan[i_2].bytes_left = 0) then
    begin
      if (f^.scan[i_2].crc_so_far = f^.scan[i_2].goal_crc) then
      begin
        data_len := (n_3 + m);
        f^.page_crc_tests := -1;
        f^.previous_length := 0;
        f^.next_seg := -1;
        f^.current_loc := f^.scan[i_2].sample_loc;
        f^.current_loc_valid := LongInt((f^.current_loc <> LongWord(not 0)));
        Result := data_len;
        System.Exit;
      end;
      f^.page_crc_tests := (f^.page_crc_tests - 1);
      __c2p_tmp2 := f^.page_crc_tests;
      f^.scan[i_2] := f^.scan[__c2p_tmp2];
    end
    else
    begin
      i_2 := (i_2 + 1);
    end;
  end;
  Result := data_len;
end;

function stb_vorbis_decode_frame_pushdata(f: PStbVorbis; data: PUint8; data_len: LongInt; channels: PLongInt; output: PPPSingle; samples: PLongInt): LongInt; cdecl; public name 'stb_vorbis_decode_frame_pushdata'; inline;
label _L__for0_step;
var
  i_2: LongInt;
  len_2: LongInt;
  right_2: LongInt;
  left_2: LongInt;
  LError: LongInt;
begin
  if (LongInt(f^.push_mode) = 0) then
  begin
    Result := error(f, VORBIS_invalid_api_mixing);
    System.Exit;
  end;
  if (f^.page_crc_tests >= 0) then
  begin
    samples^ := 0;
    Result := vorbis_search_for_page_pushdata(f, PUint8(data), data_len);
    System.Exit;
  end;
  f^.stream := PUint8(data);
  f^.stream_end := (PUint8(data) + data_len);
  f^.error := VORBIS__no_error;
  if (is_whole_packet_present(f) = 0) then
  begin
    samples^ := 0;
    Result := 0;
    System.Exit;
  end;
  if (vorbis_decode_packet(f, @len_2, @left_2, @right_2) = 0) then
  begin
    LError := f^.error;
    if (LongInt(LError) = VORBIS_bad_packet_type) then
    begin
      f^.error := VORBIS__no_error;
      while (get8_packet(f) <> -1) do
      begin
        if (f^.eof <> 0) then
        begin
          Break;
        end;
      end;
      samples^ := 0;
      Result := LongInt(Int64((PtrInt(f^.stream) - PtrInt(data))));
      System.Exit;
    end;
    if (LongInt(LError) = VORBIS_continued_packet_flag_invalid) then
    begin
      if (f^.previous_length = 0) then
      begin
        f^.error := VORBIS__no_error;
        while (get8_packet(f) <> -1) do
        begin
          if (f^.eof <> 0) then
          begin
            Break;
          end;
        end;
        samples^ := 0;
        Result := LongInt(Int64((PtrInt(f^.stream) - PtrInt(data))));
        System.Exit;
      end;
    end;
    stb_vorbis_flush_pushdata(f);
    f^.error := LError;
    samples^ := 0;
    Result := 1;
    System.Exit;
  end;
  len_2 := vorbis_finish_frame(f, len_2, left_2, right_2);
  i_2 := 0;
  while (i_2 < f^.channels) do
  begin
    f^.outputs[i_2] := (f^.channel_buffers[i_2] + left_2);
    _L__for0_step:
    i_2 := (i_2 + 1);
  end;
  if (channels <> nil) then
  begin
    channels^ := f^.channels;
  end;
  samples^ := len_2;
  output^ := PPSingle(@f^.outputs[0]);
  Result := LongInt(Int64((PtrInt(f^.stream) - PtrInt(data))));
end;

function stb_vorbis_open_pushdata(data: PByte; data_len: LongInt; data_used: PLongInt; error: PLongInt; alloc: PStbVorbisAlloc): PStbVorbis; cdecl; public name 'stb_vorbis_open_pushdata'; inline;
var
  f: PStbVorbis;
  p_2: TStbVorbis;
begin
  vorbis_init(@p_2, alloc);
  p_2.stream := PUint8(data);
  p_2.stream_end := (PUint8(data) + data_len);
  p_2.push_mode := TUint8(1);
  if (start_decoder(@p_2) = 0) then
  begin
    if (p_2.eof <> 0) then
    begin
      error^ := VORBIS_need_more_data;
    end
    else
    begin
      error^ := p_2.error;
    end;
    vorbis_deinit(@p_2);
    Result := nil;
    System.Exit;
  end;
  f := PStbVorbis(vorbis_alloc(@p_2));
  if (f <> nil) then
  begin
    f^ := p_2;
    data_used^ := LongInt(Int64((PtrInt(f^.stream) - PtrInt(data))));
    error^ := 0;
    Result := f;
    System.Exit;
  end
  else
  begin
    vorbis_deinit(@p_2);
    Result := nil;
    System.Exit;
  end;
end;

function stb_vorbis_get_file_offset(f: PStbVorbis): LongWord; cdecl; public name 'stb_vorbis_get_file_offset'; inline;
begin
  if (LongInt(f^.push_mode) <> 0) then
  begin
    Result := 0;
    System.Exit;
  end;
  if (f^.stream <> nil) then
  begin
    Result := LongWord(Int64((PtrInt(f^.stream) - PtrInt(f^.stream_start))));
    System.Exit;
  end;
  Result := LongWord((ftell(f^.f) - Int64(f^.f_start)));
end;

function vorbis_find_page(f: PStbVorbis; &end: PUint32; last: PUint32): TUint32; inline;
label _L_invalid, _L__for0_step, _L__for1_step, _L__for2_step, _L__for3_step, _L__for4_step, _L__for5_step, _L__for6_step;
var
  n_2: LongInt;
  retry_loc: LongWord;
  i_2: LongInt;
  header: array[0..26] of TUint8;
  i_3: TUint32;
  crc_2: TUint32;
  goal_2: TUint32;
  len_2: TUint32;
  s_2: LongInt;
begin
  while True do
  begin
    if (f^.eof <> 0) then
    begin
      Result := 0;
      System.Exit;
    end;
    n_2 := LongInt(get8(f));
    if (n_2 = 79) then
    begin
      retry_loc := stb_vorbis_get_file_offset(f);
      if (LongWord((retry_loc - LongWord(25))) > f^.stream_len) then
      begin
        Result := 0;
        System.Exit;
      end;
      i_2 := 1;
      while (i_2 < 4) do
      begin
        if (get8(f) <> ogg_page_header[i_2]) then
        begin
          Break;
        end;
        _L__for0_step:
        i_2 := (i_2 + 1);
      end;
      if (f^.eof <> 0) then
      begin
        Result := 0;
        System.Exit;
      end;
      if (i_2 = 4) then
      begin
        i_3 := TUint32(0);
        while (i_3 < LongWord(4)) do
        begin
          header[i_3] := TUint8(ogg_page_header[i_3]);
          _L__for1_step:
          i_3 := (i_3 + 1);
        end;
        while (i_3 < LongWord(27)) do
        begin
          header[i_3] := TUint8(get8(f));
          _L__for2_step:
          i_3 := (i_3 + 1);
        end;
        if (f^.eof <> 0) then
        begin
          Result := 0;
          System.Exit;
        end;
        if (header[4] <> 0) then
        begin
          goto _L_invalid;
        end;
        goal_2 := LongWord((((LongInt(header[22]) + (LongInt(header[23]) shl 8)) + (LongInt(header[24]) shl 16)) + (TUint32(header[25]) shl 24)));
        i_3 := TUint32(22);
        while (i_3 < LongWord(26)) do
        begin
          header[i_3] := TUint8(0);
          _L__for3_step:
          i_3 := (i_3 + 1);
        end;
        crc_2 := TUint32(0);
        i_3 := TUint32(0);
        while (i_3 < LongWord(27)) do
        begin
          crc_2 := crc32_update(TUint32(crc_2), TUint8(header[i_3]));
          _L__for4_step:
          i_3 := (i_3 + 1);
        end;
        len_2 := TUint32(0);
        i_3 := TUint32(0);
        while (i_3 < LongWord(header[26])) do
        begin
          s_2 := LongInt(get8(f));
          crc_2 := crc32_update(TUint32(crc_2), TUint8(s_2));
          len_2 := (len_2 + LongWord(s_2));
          _L__for5_step:
          i_3 := (i_3 + 1);
        end;
        if ((len_2 <> 0) and (f^.eof <> 0)) then
        begin
          Result := 0;
          System.Exit;
        end;
        i_3 := TUint32(0);
        while (i_3 < len_2) do
        begin
          crc_2 := crc32_update(TUint32(crc_2), TUint8(get8(f)));
          _L__for6_step:
          i_3 := (i_3 + 1);
        end;
        if (crc_2 = goal_2) then
        begin
          if (&end <> nil) then
          begin
            &end^ := stb_vorbis_get_file_offset(f);
          end;
          if (last <> nil) then
          begin
            if ((LongInt(header[5]) and 4) <> 0) then
            begin
              last^ := TUint32(1);
            end
            else
            begin
              last^ := TUint32(0);
            end;
          end;
          set_file_offset(f, LongWord((retry_loc - 1)));
          Result := 1;
          System.Exit;
        end;
      end;
      _L_invalid:
      set_file_offset(f, retry_loc);
    end;
  end;
end;

function get_seek_page_info(f: PStbVorbis; z_2: PProbedPage): LongInt; inline;
label _L__for0_step;
var
  header: array[0..26] of TUint8;
  lacing: array[0..254] of TUint8;
  i_2: LongInt;
  len_2: LongInt;
begin
  z_2^.page_start := stb_vorbis_get_file_offset(f);
  getn(f, PUint8(@header[0]), 27);
  if ((((header[0] <> 79) or (header[1] <> 103)) or (header[2] <> 103)) or (header[3] <> 83)) then
  begin
    Result := 0;
    System.Exit;
  end;
  getn(f, PUint8(@lacing[0]), LongInt(header[26]));
  len_2 := 0;
  i_2 := 0;
  while (i_2 < header[26]) do
  begin
    len_2 := (len_2 + lacing[i_2]);
    _L__for0_step:
    i_2 := (i_2 + 1);
  end;
  z_2^.page_end := LongWord((LongWord((LongWord((z_2^.page_start + LongWord(27))) + LongInt(header[26]))) + len_2));
  z_2^.last_decoded_sample := TUint32((((LongInt(header[6]) + (LongInt(header[7]) shl 8)) + (LongInt(header[8]) shl 16)) + (LongInt(header[9]) shl 24)));
  set_file_offset(f, z_2^.page_start);
  Result := 1;
end;

function go_to_page_before(f: PStbVorbis; limit_offset: LongWord): LongInt; inline;
var
  previous_safe: LongWord;
  &end: LongWord;
  __c2p_tmp1: LongInt;
begin
  if ((limit_offset >= LongWord(65536)) and (LongWord((limit_offset - LongWord(65536))) >= f^.first_audio_page_offset)) then
  begin
    previous_safe := LongWord((limit_offset - LongWord(65536)));
  end
  else
  begin
    previous_safe := f^.first_audio_page_offset;
  end;
  set_file_offset(f, previous_safe);
  while (vorbis_find_page(f, @&end, PUint32(Pointer(0))) <> 0) do
  begin
    __c2p_tmp1 := LongInt(0);
    if (&end >= limit_offset) then
    begin
      __c2p_tmp1 := LongInt((stb_vorbis_get_file_offset(f) < limit_offset));
    end;
    if (__c2p_tmp1 <> 0) then
    begin
      Result := 1;
      System.Exit;
    end;
    set_file_offset(f, &end);
  end;
  Result := 0;
end;

function seek_to_sample_coarse(f: PStbVorbis; sample_number: TUint32): LongInt;
label _L_error, _L__for0_step, _L__for1_step;
var
  left_2: TProbedPage;
  right_2: TProbedPage;
  mid_2: TProbedPage;
  i_2: LongInt;
  start_seg_with_known_loc: LongInt;
  end_pos: LongInt;
  page_start: LongInt;
  delta_2: TUint32;
  stream_length: TUint32;
  padding_2: TUint32;
  last_sample_limit: TUint32;
  offset: Double;
  bytes_per_sample: Double;
  probe: LongInt;
  data_bytes: Double;
  LError: Double;
begin
  offset := 0.0;
  bytes_per_sample := 0.0;
  probe := 0;
  stream_length := stb_vorbis_stream_length_in_samples(f);
  if (stream_length = LongWord(0)) then
  begin
    Result := error(f, VORBIS_seek_without_length);
    System.Exit;
  end;
  if (sample_number > stream_length) then
  begin
    Result := error(f, VORBIS_seek_invalid);
    System.Exit;
  end;
  padding_2 := TUint32(__c2p_sar_longint((f^.blocksize_1 - f^.blocksize_0), 2));
  if (sample_number < padding_2) then
  begin
    last_sample_limit := TUint32(0);
  end
  else
  begin
    last_sample_limit := LongWord((sample_number - padding_2));
  end;
  left_2 := f^.p_first;
  while (left_2.last_decoded_sample = LongWord(not 0)) do
  begin
    set_file_offset(f, left_2.page_end);
    if (get_seek_page_info(f, @left_2) = 0) then
    begin
      stb_vorbis_seek_start(f);
      Result := error(f, VORBIS_seek_failed);
      System.Exit;
    end;
  end;
  right_2 := f^.p_last;
  if (last_sample_limit <= left_2.last_decoded_sample) then
  begin
    if (stb_vorbis_seek_start(f) <> 0) then
    begin
      if (f^.current_loc > sample_number) then
      begin
        Result := error(f, VORBIS_seek_failed);
        System.Exit;
      end;
      Result := 1;
      System.Exit;
    end;
    Result := 0;
    System.Exit;
  end;
  while (left_2.page_end <> right_2.page_start) do
  begin
    delta_2 := LongWord((right_2.page_start - left_2.page_end));
    if (delta_2 <= LongWord(65536)) then
    begin
      set_file_offset(f, left_2.page_end);
    end
    else
    begin
      if (probe < 2) then
      begin
        if (probe = 0) then
        begin
          data_bytes := LongWord((right_2.page_end - left_2.page_start));
          bytes_per_sample := (data_bytes / right_2.last_decoded_sample);
          offset := (left_2.page_start + (bytes_per_sample * LongWord((last_sample_limit - left_2.last_decoded_sample))));
        end
        else
        begin
          LError := ((Double(last_sample_limit) - mid_2.last_decoded_sample) * bytes_per_sample);
          if ((LError >= 0) and (LError < 8000)) then
          begin
            LError := 8000;
          end;
          if ((LError < 0) and (LError > -8000)) then
          begin
            LError := -8000;
          end;
          offset := (offset + (LError * 2));
        end;
        if (offset < left_2.page_end) then
        begin
          offset := left_2.page_end;
        end;
        if (offset > LongWord((right_2.page_start - LongWord(65536)))) then
        begin
          offset := LongWord((right_2.page_start - LongWord(65536)));
        end;
        set_file_offset(f, LongWord(Trunc(offset)));
      end
      else
      begin
        set_file_offset(f, LongWord((LongWord((left_2.page_end + (delta_2 div LongWord(2)))) - LongWord(32768))));
      end;
      if (vorbis_find_page(f, PUint32(Pointer(0)), PUint32(Pointer(0))) = 0) then
      begin
        stb_vorbis_seek_start(f);
        Result := error(f, VORBIS_seek_failed);
        System.Exit;
      end;
    end;
    while True do
    begin
      if (get_seek_page_info(f, @mid_2) = 0) then
      begin
        stb_vorbis_seek_start(f);
        Result := error(f, VORBIS_seek_failed);
        System.Exit;
      end;
      if (mid_2.last_decoded_sample <> LongWord(not 0)) then
      begin
        Break;
      end;
      set_file_offset(f, mid_2.page_end);
    end;
    if (mid_2.page_start = right_2.page_start) then
    begin
      if ((probe >= 2) or (delta_2 <= LongWord(65536))) then
      begin
        Break;
      end;
    end
    else
    begin
      if (last_sample_limit < mid_2.last_decoded_sample) then
      begin
        right_2 := mid_2;
      end
      else
      begin
        left_2 := mid_2;
      end;
    end;
    probe := (probe + 1);
  end;
  page_start := LongInt(left_2.page_start);
  set_file_offset(f, LongWord(page_start));
  if (start_page(f) = 0) then
  begin
    Result := error(f, VORBIS_seek_failed);
    System.Exit;
  end;
  end_pos := f^.end_seg_with_known_loc;
  while True do
  begin
    i_2 := end_pos;
    while (i_2 > 0) do
    begin
      if (f^.segments[(i_2 - 1)] <> 255) then
      begin
        Break;
      end;
      _L__for0_step:
      i_2 := (i_2 - 1);
    end;
    start_seg_with_known_loc := i_2;
    if ((start_seg_with_known_loc > 0) or ((LongInt(f^.page_flag) and 1) = 0)) then
    begin
      Break;
    end;
    if (go_to_page_before(f, LongWord(page_start)) = 0) then
    begin
      stb_vorbis_seek_start(f);
      Result := error(f, VORBIS_seek_failed);
      System.Exit;
    end;
    page_start := LongInt(stb_vorbis_get_file_offset(f));
    if (start_page(f) = 0) then
    begin
      stb_vorbis_seek_start(f);
      Result := error(f, VORBIS_seek_failed);
      System.Exit;
    end;
    end_pos := (f^.segment_count - 1);
  end;
  f^.current_loc_valid := 0;
  f^.last_seg := 0;
  f^.valid_bits := 0;
  f^.packet_bytes := 0;
  f^.bytes_in_seg := TUint8(0);
  f^.previous_length := 0;
  f^.next_seg := start_seg_with_known_loc;
  i_2 := 0;
  while (i_2 < start_seg_with_known_loc) do
  begin
    skip(f, LongInt(f^.segments[i_2]));
    _L__for1_step:
    i_2 := (i_2 + 1);
  end;
  if (vorbis_pump_first_frame(f) = 0) then
  begin
    Result := 0;
    System.Exit;
  end;
  if (f^.current_loc > sample_number) then
  begin
    Result := error(f, VORBIS_seek_failed);
    System.Exit;
  end;
  Result := 1;
  System.Exit;
  _L_error:
  stb_vorbis_seek_start(f);
  Result := error(f, VORBIS_seek_failed);
end;

function peek_decode_initial(f: PVorb; p_left_start: PLongInt; p_left_end: PLongInt; p_right_start: PLongInt; p_right_end: PLongInt; mode: PLongInt): LongInt;
var
  bits_read: LongInt;
  bytes_read: LongInt;
begin
  if (vorbis_decode_initial(f, p_left_start, p_left_end, p_right_start, p_right_end, mode) = 0) then
  begin
    Result := 0;
    System.Exit;
  end;
  bits_read := (1 + ilog(TInt32((f^.mode_count - 1))));
  if (LongInt(f^.mode_config[mode^].blockflag) <> 0) then
  begin
    bits_read := (bits_read + 2);
  end;
  bytes_read := ((bits_read + 7) div 8);
  f^.bytes_in_seg := TUint8((f^.bytes_in_seg + bytes_read));
  f^.packet_bytes := (f^.packet_bytes - bytes_read);
  skip(f, -bytes_read);
  if (f^.next_seg = -1) then
  begin
    f^.next_seg := (f^.segment_count - 1);
  end
  else
  begin
    f^.next_seg := (f^.next_seg - 1);
  end;
  f^.valid_bits := 0;
  Result := 1;
end;

function stb_vorbis_seek_frame(f: PStbVorbis; sample_number: LongWord): LongInt; cdecl; public name 'stb_vorbis_seek_frame'; inline;
var
  max_frame_samples: TUint32;
  left_start: LongInt;
  left_end: LongInt;
  right_start: LongInt;
  right_end: LongInt;
  mode: LongInt;
  frame_samples: LongInt;
begin
  if (LongInt(f^.push_mode) <> 0) then
  begin
    Result := error(f, VORBIS_invalid_api_mixing);
    System.Exit;
  end;
  if (seek_to_sample_coarse(f, TUint32(sample_number)) = 0) then
  begin
    Result := 0;
    System.Exit;
  end;
  max_frame_samples := TUint32(__c2p_sar_longint(((f^.blocksize_1 * 3) - f^.blocksize_0), 2));
  while (f^.current_loc < sample_number) do
  begin
    if (peek_decode_initial(f, @left_start, @left_end, @right_start, @right_end, @mode) = 0) then
    begin
      Result := error(f, VORBIS_seek_failed);
      System.Exit;
    end;
    frame_samples := (right_start - left_start);
    if (LongWord((f^.current_loc + frame_samples)) > sample_number) then
    begin
      Result := 1;
      System.Exit;
    end
    else
    begin
      if (LongWord((LongWord((f^.current_loc + frame_samples)) + max_frame_samples)) > sample_number) then
      begin
        vorbis_pump_first_frame(f);
      end
      else
      begin
        f^.current_loc := (f^.current_loc + LongWord(frame_samples));
        f^.previous_length := 0;
        maybe_start_packet(f);
        flush_packet(f);
      end;
    end;
  end;
  if (f^.current_loc <> sample_number) then
  begin
    Result := error(f, VORBIS_seek_failed);
    System.Exit;
  end;
  Result := 1;
end;

function stb_vorbis_seek(f: PStbVorbis; sample_number: LongWord): LongInt; cdecl; public name 'stb_vorbis_seek'; inline;
var
  n_2: LongInt;
  frame_start: TUint32;
begin
  if (stb_vorbis_seek_frame(f, sample_number) = 0) then
  begin
    Result := 0;
    System.Exit;
  end;
  if (sample_number <> f^.current_loc) then
  begin
    frame_start := f^.current_loc;
    stb_vorbis_get_frame_float(f, @n_2, PPPSingle(Pointer(0)));
    f^.channel_buffer_start := LongInt((LongWord(f^.channel_buffer_start) + LongWord((sample_number - frame_start))));
  end;
  Result := 1;
end;

function stb_vorbis_seek_start(f: PStbVorbis): LongInt; cdecl; public name 'stb_vorbis_seek_start'; inline;
begin
  if (LongInt(f^.push_mode) <> 0) then
  begin
    Result := error(f, VORBIS_invalid_api_mixing);
    System.Exit;
  end;
  set_file_offset(f, f^.first_audio_page_offset);
  f^.previous_length := 0;
  f^.first_decode := TUint8(1);
  f^.next_seg := -1;
  Result := vorbis_pump_first_frame(f);
end;

function stb_vorbis_stream_length_in_samples(f: PStbVorbis): LongWord; cdecl; public name 'stb_vorbis_stream_length_in_samples'; inline;
label _L_done;
var
  restore_offset: LongWord;
  previous_safe: LongWord;
  &end: LongWord;
  last_page_loc: LongWord;
  last: LongWord;
  lo_2: TUint32;
  hi_2: TUint32;
  header: array[0..5] of AnsiChar;
  __c2p_tmp1: LongWord;
begin
  if (LongInt(f^.push_mode) <> 0) then
  begin
    Result := error(f, VORBIS_invalid_api_mixing);
    System.Exit;
  end;
  if (f^.total_samples = 0) then
  begin
    restore_offset := stb_vorbis_get_file_offset(f);
    if ((f^.stream_len >= LongWord(65536)) and (LongWord((f^.stream_len - LongWord(65536))) >= f^.first_audio_page_offset)) then
    begin
      previous_safe := LongWord((f^.stream_len - LongWord(65536)));
    end
    else
    begin
      previous_safe := f^.first_audio_page_offset;
    end;
    set_file_offset(f, previous_safe);
    if (vorbis_find_page(f, @&end, @last) = 0) then
    begin
      f^.error := VORBIS_cant_find_last_page;
      f^.total_samples := TUint32(4294967295);
      goto _L_done;
    end;
    last_page_loc := stb_vorbis_get_file_offset(f);
    while (last = 0) do
    begin
      set_file_offset(f, &end);
      if (vorbis_find_page(f, @&end, @last) = 0) then
      begin
        Break;
      end;
      last_page_loc := stb_vorbis_get_file_offset(f);
    end;
    set_file_offset(f, last_page_loc);
    getn(f, PByte(@header[0]), 6);
    lo_2 := get32(f);
    hi_2 := get32(f);
    if ((lo_2 = LongWord(4294967295)) and (hi_2 = LongWord(4294967295))) then
    begin
      f^.error := VORBIS_cant_find_last_page;
      f^.total_samples := TUint32(4294967295);
      goto _L_done;
    end;
    if (hi_2 <> 0) then
    begin
      lo_2 := TUint32(4294967294);
    end;
    f^.total_samples := lo_2;
    f^.p_last.page_start := last_page_loc;
    f^.p_last.page_end := &end;
    f^.p_last.last_decoded_sample := lo_2;
    _L_done:
    set_file_offset(f, restore_offset);
  end;
  if (f^.total_samples = LongWord(4294967295)) then
  begin
    __c2p_tmp1 := LongWord(0);
  end
  else
  begin
    __c2p_tmp1 := f^.total_samples;
  end;
  Result := __c2p_tmp1;
end;

function stb_vorbis_stream_length_in_seconds(f: PStbVorbis): Single; cdecl; public name 'stb_vorbis_stream_length_in_seconds';
begin
  Result := (stb_vorbis_stream_length_in_samples(f) / Single(f^.sample_rate));
end;

function stb_vorbis_get_frame_float(f: PStbVorbis; channels: PLongInt; output: PPPSingle): LongInt; cdecl; public name 'stb_vorbis_get_frame_float'; inline;
label _L__for0_step;
var
  len_2: LongInt;
  right_2: LongInt;
  left_2: LongInt;
  i_2: LongInt;
  __c2p_tmp1: LongInt;
begin
  if (LongInt(f^.push_mode) <> 0) then
  begin
    Result := error(f, VORBIS_invalid_api_mixing);
    System.Exit;
  end;
  if (vorbis_decode_packet(f, @len_2, @left_2, @right_2) = 0) then
  begin
    __c2p_tmp1 := 0;
    f^.channel_buffer_end := __c2p_tmp1;
    f^.channel_buffer_start := __c2p_tmp1;
    Result := 0;
    System.Exit;
  end;
  len_2 := vorbis_finish_frame(f, len_2, left_2, right_2);
  i_2 := 0;
  while (i_2 < f^.channels) do
  begin
    f^.outputs[i_2] := (f^.channel_buffers[i_2] + left_2);
    _L__for0_step:
    i_2 := (i_2 + 1);
  end;
  f^.channel_buffer_start := left_2;
  f^.channel_buffer_end := (left_2 + len_2);
  if (channels <> nil) then
  begin
    channels^ := f^.channels;
  end;
  if (output <> nil) then
  begin
    output^ := PPSingle(@f^.outputs[0]);
  end;
  Result := len_2;
end;

function stb_vorbis_open_file_section(&file: PFILE; close_on_free: LongInt; error: PLongInt; alloc: PStbVorbisAlloc; length: LongWord): PStbVorbis; cdecl; public name 'stb_vorbis_open_file_section'; inline;
var
  f: PStbVorbis;
  p_2: TStbVorbis;
begin
  vorbis_init(@p_2, alloc);
  p_2.f := &file;
  p_2.f_start := TUint32(ftell(&file));
  p_2.stream_len := length;
  p_2.close_on_free := close_on_free;
  if (start_decoder(@p_2) <> 0) then
  begin
    f := PStbVorbis(vorbis_alloc(@p_2));
    if (f <> nil) then
    begin
      f^ := p_2;
      vorbis_pump_first_frame(f);
      Result := f;
      System.Exit;
    end;
  end;
  if (error <> nil) then
  begin
    error^ := p_2.error;
  end;
  vorbis_deinit(@p_2);
  Result := nil;
end;

function stb_vorbis_open_file(&file: PFILE; close_on_free: LongInt; error: PLongInt; alloc: PStbVorbisAlloc): PStbVorbis; cdecl; public name 'stb_vorbis_open_file'; inline;
var
  len_2: LongWord;
  start: LongWord;
begin
  start := LongWord(ftell(&file));
  fseek(&file, Int64(0), 2);
  len_2 := LongWord((ftell(&file) - Int64(start)));
  fseek(&file, Int64(start), 0);
  Result := PStbVorbis(stb_vorbis_open_file_section(&file, close_on_free, error, alloc, len_2));
end;

function stb_vorbis_open_filename(filename: PAnsiChar; error: PLongInt; alloc: PStbVorbisAlloc): PStbVorbis; cdecl; public name 'stb_vorbis_open_filename'; inline;
var
  f: PFILE;
begin
  f := PFILE(fopen(filename, PAnsiChar('rb')));
  if (f <> nil) then
  begin
    Result := PStbVorbis(stb_vorbis_open_file(f, 1, error, alloc));
    System.Exit;
  end;
  if (error <> nil) then
  begin
    error^ := VORBIS_file_open_failure;
  end;
  Result := nil;
end;

function stb_vorbis_open_memory(data: PByte; len_2: LongInt; error: PLongInt; alloc: PStbVorbisAlloc): PStbVorbis; cdecl; public name 'stb_vorbis_open_memory'; inline;
var
  f: PStbVorbis;
  p_2: TStbVorbis;
begin
  if (data = nil) then
  begin
    if (error <> nil) then
    begin
      error^ := VORBIS_unexpected_eof;
    end;
    Result := nil;
    System.Exit;
  end;
  vorbis_init(@p_2, alloc);
  p_2.stream := PUint8(data);
  p_2.stream_end := (PUint8(data) + len_2);
  p_2.stream_start := PUint8(p_2.stream);
  p_2.stream_len := TUint32(len_2);
  p_2.push_mode := TUint8(0);
  if (start_decoder(@p_2) <> 0) then
  begin
    f := PStbVorbis(vorbis_alloc(@p_2));
    if (f <> nil) then
    begin
      f^ := p_2;
      vorbis_pump_first_frame(f);
      if (error <> nil) then
      begin
        error^ := VORBIS__no_error;
      end;
      Result := f;
      System.Exit;
    end;
  end;
  if (error <> nil) then
  begin
    error^ := p_2.error;
  end;
  vorbis_deinit(@p_2);
  Result := nil;
end;

procedure copy_samples(dest: PSmallInt; src: PSingle; len_2: LongInt);
label _L__for0_step;
var
  i_2: LongInt;
  temp_2: TFloatConv;
  v: LongInt;
  __c2p_tmp1: LongInt;
begin
  i_2 := 0;
  while (i_2 < len_2) do
  begin
    temp_2.f := (src[i_2] + ((Single(1.5) * (1 shl (23 - 15))) + (Single(0.5) / (1 shl 15))));
    v := (temp_2.i - (((150 - 15) shl 23) + (1 shl 22)));
    if (LongWord((v + 32768)) > LongWord(65535)) then
    begin
      if (v < 0) then
      begin
        __c2p_tmp1 := -32768;
      end
      else
      begin
        __c2p_tmp1 := 32767;
      end;
      v := __c2p_tmp1;
    end;
    dest[i_2] := SmallInt(v);
    _L__for0_step:
    i_2 := (i_2 + 1);
  end;
end;

procedure compute_samples(mask: LongInt; output: PSmallInt; num_c: LongInt; data: PPSingle; d_offset: LongInt; len_2: LongInt);
label _L__for0_step, _L__for1_step, _L__for2_step, _L__for3_step;
var
  buffer: array[0..31] of Single;
  i_2: LongInt;
  j: LongInt;
  o: LongInt;
  n_2: LongInt;
  temp_2: TFloatConv;
  v: LongInt;
  __c2p_tmp1: LongInt;
begin
  n_2 := 32;
  o := 0;
  while (o < len_2) do
  begin
    __c2p_stdlib_memset(Pointer(@buffer[0]), 0, TSizeT(128));
    if ((o + n_2) > len_2) then
    begin
      n_2 := (len_2 - o);
    end;
    j := 0;
    while (j < num_c) do
    begin
      if ((LongInt(ShortInt(channel_position[num_c][j])) and mask) <> 0) then
      begin
        i_2 := 0;
        while (i_2 < n_2) do
        begin
          buffer[i_2] := (buffer[i_2] + data[j][((d_offset + o) + i_2)]);
          _L__for2_step:
          i_2 := (i_2 + 1);
        end;
      end;
      _L__for1_step:
      j := (j + 1);
    end;
    i_2 := 0;
    while (i_2 < n_2) do
    begin
      temp_2.f := (buffer[i_2] + ((Single(1.5) * (1 shl (23 - 15))) + (Single(0.5) / (1 shl 15))));
      v := (temp_2.i - (((150 - 15) shl 23) + (1 shl 22)));
      if (LongWord((v + 32768)) > LongWord(65535)) then
      begin
        if (v < 0) then
        begin
          __c2p_tmp1 := -32768;
        end
        else
        begin
          __c2p_tmp1 := 32767;
        end;
        v := __c2p_tmp1;
      end;
      output[(o + i_2)] := SmallInt(v);
      _L__for3_step:
      i_2 := (i_2 + 1);
    end;
    _L__for0_step:
    o := (o + 32);
  end;
end;

procedure compute_stereo_samples(output: PSmallInt; num_c: LongInt; data: PPSingle; d_offset: LongInt; len_2: LongInt);
label _L__for0_step, _L__for1_step, _L__for2_step, _L__for3_step, _L__for4_step, _L__for5_step;
var
  buffer: array[0..31] of Single;
  i_2: LongInt;
  j: LongInt;
  o: LongInt;
  n_2: LongInt;
  o2: LongInt;
  m: LongInt;
  temp_2: TFloatConv;
  v: LongInt;
  __c2p_tmp1: LongInt;
  __c2p_tmp2: LongInt;
  __c2p_tmp3: LongInt;
  __c2p_tmp4: LongInt;
  __c2p_tmp5: LongInt;
begin
  n_2 := __c2p_sar_longint(32, 1);
  o := 0;
  while (o < len_2) do
  begin
    o2 := (o shl 1);
    __c2p_stdlib_memset(Pointer(@buffer[0]), 0, TSizeT(128));
    if ((o + n_2) > len_2) then
    begin
      n_2 := (len_2 - o);
    end;
    j := 0;
    while (j < num_c) do
    begin
      m := (LongInt(ShortInt(channel_position[num_c][j])) and (2 or 4));
      if (m = (2 or 4)) then
      begin
        i_2 := 0;
        while (i_2 < n_2) do
        begin
          __c2p_tmp1 := ((i_2 * 2) + 0);
          buffer[__c2p_tmp1] := (buffer[__c2p_tmp1] + data[j][((d_offset + o) + i_2)]);
          __c2p_tmp2 := ((i_2 * 2) + 1);
          buffer[__c2p_tmp2] := (buffer[__c2p_tmp2] + data[j][((d_offset + o) + i_2)]);
          _L__for2_step:
          i_2 := (i_2 + 1);
        end;
      end
      else
      begin
        if (m = 2) then
        begin
          i_2 := 0;
          while (i_2 < n_2) do
          begin
            __c2p_tmp3 := ((i_2 * 2) + 0);
            buffer[__c2p_tmp3] := (buffer[__c2p_tmp3] + data[j][((d_offset + o) + i_2)]);
            _L__for3_step:
            i_2 := (i_2 + 1);
          end;
        end
        else
        begin
          if (m = 4) then
          begin
            i_2 := 0;
            while (i_2 < n_2) do
            begin
              __c2p_tmp4 := ((i_2 * 2) + 1);
              buffer[__c2p_tmp4] := (buffer[__c2p_tmp4] + data[j][((d_offset + o) + i_2)]);
              _L__for4_step:
              i_2 := (i_2 + 1);
            end;
          end;
        end;
      end;
      _L__for1_step:
      j := (j + 1);
    end;
    i_2 := 0;
    while (i_2 < (n_2 shl 1)) do
    begin
      temp_2.f := (buffer[i_2] + ((Single(1.5) * (1 shl (23 - 15))) + (Single(0.5) / (1 shl 15))));
      v := (temp_2.i - (((150 - 15) shl 23) + (1 shl 22)));
      if (LongWord((v + 32768)) > LongWord(65535)) then
      begin
        if (v < 0) then
        begin
          __c2p_tmp5 := -32768;
        end
        else
        begin
          __c2p_tmp5 := 32767;
        end;
        v := __c2p_tmp5;
      end;
      output[(o2 + i_2)] := SmallInt(v);
      _L__for5_step:
      i_2 := (i_2 + 1);
    end;
    _L__for0_step:
    o := (o + __c2p_sar_longint(32, 1));
  end;
end;

procedure convert_samples_short(buf_c: LongInt; buffer: PPSmallInt; b_offset: LongInt; data_c: LongInt; data: PPSingle; d_offset: LongInt; samples: LongInt); inline;
label _L__for0_step, _L__for1_step, _L__for2_step;
var
  i_2: LongInt;
  limit: LongInt;
  __c2p_tmp1: LongInt;
begin
  if (((buf_c <> data_c) and (buf_c <= 2)) and (data_c <= 6)) then
  begin
    i_2 := 0;
    while (i_2 < buf_c) do
    begin
      compute_samples(_static_convert_samples_short_channel_selector[buf_c][i_2], (buffer[i_2] + b_offset), data_c, data, d_offset, samples);
      _L__for0_step:
      i_2 := (i_2 + 1);
    end;
  end
  else
  begin
    if (buf_c < data_c) then
    begin
      __c2p_tmp1 := buf_c;
    end
    else
    begin
      __c2p_tmp1 := data_c;
    end;
    limit := __c2p_tmp1;
    i_2 := 0;
    while (i_2 < limit) do
    begin
      copy_samples((buffer[i_2] + b_offset), (data[i_2] + d_offset), samples);
      _L__for1_step:
      i_2 := (i_2 + 1);
    end;
    while (i_2 < buf_c) do
    begin
      __c2p_stdlib_memset((buffer[i_2] + b_offset), 0, TSizeT(QWord((2 * QWord(samples)))));
      _L__for2_step:
      i_2 := (i_2 + 1);
    end;
  end;
end;

function stb_vorbis_get_frame_short(f: PStbVorbis; num_c: LongInt; buffer: PPSmallInt; num_samples: LongInt): LongInt; cdecl; public name 'stb_vorbis_get_frame_short'; inline;
var
  output: PPSingle;
  len_2: LongInt;
begin
  output := nil;
  len_2 := stb_vorbis_get_frame_float(f, PLongInt(Pointer(0)), @output);
  if (len_2 > num_samples) then
  begin
    len_2 := num_samples;
  end;
  if (len_2 <> 0) then
  begin
    convert_samples_short(num_c, buffer, 0, f^.channels, output, 0, len_2);
  end;
  Result := len_2;
end;

{ 手工优化段（非翻译产物）：s16 转换快路径。x*2^15 为 2 的幂精确缩放，
  cvtps2dq 的 round-to-nearest-even 与魔数加法取位模式在 |x*2^15|<2^23
  安全域逐位一致；入口先做 |x|<4 门控，不安全（含 NaN/Inf）整体走标量
  回退，溢出域语义保持与 C 一致。packssdw 饱和与 C 截断逐位等价。}
{$ifdef cpux86_64}
const
  C2P_SCALE15_4: array[0..3] of Single = (
    32768.0, 32768.0, 32768.0, 32768.0);
  C2P_ABS_MASK: array[0..3] of LongWord = (
    $7FFFFFFF, $7FFFFFFF, $7FFFFFFF, $7FFFFFFF);
  C2P_LIMIT4: array[0..3] of Single = (4.0, 4.0, 4.0, 4.0);

function conv_range_ok(c0_: PSingle; c1_: PSingle; n__: LongInt): Boolean; assembler; nostackframe;
{ 检查 c0_/c1_ 前 n__ 个元素全部 |x|<4.0（无 NaN/Inf）。RDI=c0_ RSI=c1_ RCX=n__
  返回 AL=1 表示安全 }
{ 3 参：RDI=c0_ RSI=c1_ RDX=n__ }
asm
{$ifdef windows}
  { Win64 ABI：RSI/RDI 非易失，须保存 }
  push     %rdi
  push     %rsi
  movl     %r8d, %eax
  movq     %rcx, %rdi
  movq     %rdx, %rsi
  movl     %eax, %edx
{$endif}
  xorl    %eax, %eax
  testl   %edx, %edx
  jle     .Lcr_ok
  movslq  %edx, %rcx
  xorl    %r9d, %r9d
  pxor    %xmm0, %xmm0
.Lcr_loop:
  movups  (%rdi,%r9,4), %xmm1
  andps   C2P_ABS_MASK(%rip), %xmm1
  maxps   %xmm1, %xmm0
  testq   %rsi, %rsi
  jz      .Lcr_next
  movups  (%rsi,%r9,4), %xmm1
  andps   C2P_ABS_MASK(%rip), %xmm1
  maxps   %xmm1, %xmm0
.Lcr_next:
  addq    $4, %r9
  cmpq    %rcx, %r9
  jb      .Lcr_loop
  { 尾部：n 非 4 倍数时余数逐个检查（避免 movups 越界读） }
  subq    $3, %rcx
.Lcr_tail:
  cmpq    %rcx, %r9
  jae     .Lcr_eval
  movss   (%rdi,%r9,4), %xmm1
  andps   C2P_ABS_MASK(%rip), %xmm1
  maxss   %xmm1, %xmm0
  testq   %rsi, %rsi
  jz      .Lcr_tnext
  movss   (%rsi,%r9,4), %xmm1
  andps   C2P_ABS_MASK(%rip), %xmm1
  maxss   %xmm1, %xmm0
.Lcr_tnext:
  addq    $1, %r9
  jmp     .Lcr_tail
.Lcr_eval:
  comiss  C2P_LIMIT4(%rip), %xmm0
  jp      .Lcr_bad
  jae     .Lcr_bad
.Lcr_ok:
  movl    $1, %eax
.Lcr_bad:
{$ifdef windows}
  pop      %rsi
  pop      %rdi
{$endif}
end;

procedure conv_mono_simd_s16(c0_: PSingle; out__: PSmallInt; n4_: LongInt); assembler; nostackframe;
{ out__[k]=saturate(round_nearest(c0_[k]*2^15)) k=0..n4_-1（n4_ 为 4 的倍数）
  3 参：RDI=c0_ RSI=out__ RDX=n4_ }
asm
{$ifdef windows}
  { Win64 ABI：RSI/RDI 非易失，须保存 }
  push     %rdi
  push     %rsi
  movl     %r8d, %eax
  movq     %rcx, %rdi
  movq     %rdx, %rsi
  movl     %eax, %edx
{$endif}
  testl   %edx, %edx
  jle     .Lcm_done
  movslq  %edx, %rcx
  xorl    %r9d, %r9d
.Lcm_loop:
  movups  (%rdi,%r9,4), %xmm0
  mulps   C2P_SCALE15_4(%rip), %xmm0
  cvtps2dq %xmm0, %xmm0
  packssdw %xmm0, %xmm0
  movq    %xmm0, (%rsi,%r9,2)
  addq    $4, %r9
  cmpq    %rcx, %r9
  jb      .Lcm_loop
.Lcm_done:
{$ifdef windows}
  pop      %rsi
  pop      %rdi
{$endif}
end;

procedure conv_stereo_simd_s16(c0_: PSingle; c1_: PSingle; out__: PSmallInt; n4_: LongInt); assembler; nostackframe;
{ out__ 交错 [c0[k],c1[k]]。Linux：RDI=c0_ RSI=c1_ RDX=out__ RCX=n4_；
  Windows 序言搬移 }
asm
{$ifdef windows}
  { Win64 ABI：RSI/RDI 非易失，须保存 }
  push     %rdi
  push     %rsi
  movq     %rcx, %rdi
  movq     %rdx, %rsi
  movq     %r8, %rdx
  movl     %r9d, %ecx
{$endif}
  testl   %ecx, %ecx
  jle     .Lcs_done
  movslq  %ecx, %rcx
  xorl    %r9d, %r9d
.Lcs_loop:
  movups  (%rdi,%r9,4), %xmm0
  mulps   C2P_SCALE15_4(%rip), %xmm0
  cvtps2dq %xmm0, %xmm0
  movups  (%rsi,%r9,4), %xmm2
  mulps   C2P_SCALE15_4(%rip), %xmm2
  cvtps2dq %xmm2, %xmm2
  packssdw %xmm0, %xmm0
  packssdw %xmm2, %xmm2
  punpcklwd %xmm2, %xmm0
  movups  %xmm0, (%rdx,%r9,4)
  addq    $4, %r9
  cmpq    %rcx, %r9
  jb      .Lcs_loop
.Lcs_done:
{$ifdef windows}
  pop      %rsi
  pop      %rdi
{$endif}
end;
{$endif cpux86_64}

{$ifdef cpuaarch64}
{ NEON 版本：函数名与调用点同 x86（互斥门控下二选一编译）。位精确映射：
  fcvtns ≙ cvtps2dq（RNE+饱和；门控保证 |x*2^15| 远离 i32 溢出域），
  sqxtn ≙ packssdw，zip1 .8h ≙ punpcklwd；常量一律寄存器内按位构造，
  不经内存字面量。 }
function conv_range_ok(c0_: PSingle; c1_: PSingle; n__: LongInt): Boolean; assembler; nostackframe;
{ 检查 c0_/c1_ 前 n__ 个元素全部 |x|<4.0 且无 NaN/Inf。运行 max 链用
  fmax——任一输入为 NaN 结果保持 NaN，末次 fcmp 落入 N=0 分支，与
  ≥4.0 一并拒绝（语义同 x86 jp 补丁后的标量回退判定）。
  注意 AAPCS64 首参与返回值共用 x0：结果寄存器只能在所有访存结束后
  才能写（x86 版开头 movl $1,%eax 的写法在此会毁掉 c0_）。
  x0=c0_ x1=c1_ w2=n__，w0=1 表示安全 }
asm
  cmp      w2, #0
  b.le     .Lcr_safe                 // n≤0 与 x86 同判为安全
  sxtw     x9, w2
  bic      w8, w2, #3                // 向量化元素数
  cbz      w8, .Lcr_tail_pre
  lsr      w10, w8, #2               // 块数
  movz     w4, #0x4080, lsl #16      // 4.0f = 0x40800000
  dup      v6.4s, w4                 // LIMIT 广播
  fmov     s7, w4                    // 标量比较端
  movi     v5.2d, #0                 // 运行 |max|（|x|≥0，初值合法）
.Lcr_loop:
  ld1      {v0.4s}, [x0], #16
  fabs     v0.4s, v0.4s
  fmax     v5.4s, v5.4s, v0.4s
  cbz      x1, .Lcr_next
  ld1      {v1.4s}, [x1], #16
  fabs     v1.4s, v1.4s
  fmax     v5.4s, v5.4s, v1.4s
.Lcr_next:
  subs     w10, w10, #1
  b.ne     .Lcr_loop
.Lcr_tail_pre:
  and      x11, x9, #3
  cbz      x11, .Lcr_eval
.Lcr_tloop:
  ldr      s0, [x0], #4
  fabs     s0, s0
  fmax     s5, s5, s0
  cbz      x1, .Lcr_tnext
  ldr      s1, [x1], #4
  fabs     s1, s1
  fmax     s5, s5, s1
.Lcr_tnext:
  subs     x11, x11, #1
  b.ne     .Lcr_tloop
.Lcr_eval:
  fmaxv    s5, v5.4s                 // 横向归约到 lane0
  movz     w4, #0x4080, lsl #16
  fmov     s6, w4                    // 4.0f
  fcmp     s5, s6
  b.pl     .Lcr_unsafe               // ≥4.0 与无序（NaN）一并拒绝
.Lcr_safe:
  mov      w0, #1
  b        .Lcr_out
.Lcr_unsafe:
  mov      w0, #0
.Lcr_out:
end;

procedure conv_mono_simd_s16(c0_: PSingle; out__: PSmallInt; n4_: LongInt); assembler; nostackframe;
{ out__[k]=saturate(round_nearest(c0_[k]*2^15))，n4_ 为 4 的倍数。
  32768.0f = 0x47000000 寄存器内构造。FPC 内部汇编器不认混合排列的
  窄化指令（sqxtn 等），改用 .4s 整数夹取 + uzp1 .8h 取低半字打包——
  与 packssdw 逐位等价。x0=c0_ x1=out__ w2=n4_ }
asm
  cmp      w2, #0
  b.le     .Lcm_done
  movz     w4, #0x4700, lsl #16
  dup      v1.4s, w4                 // ×2^15（2 的幂精确缩放）
  movn     w5, #32767                // -32768
  dup      v3.4s, w5
  movz     w6, #32767
  dup      v4.4s, w6                 // +32767
  lsr      w2, w2, #2                // 4 样本/轮
  cbz      w2, .Lcm_done             // 非 4 倍数的契约外输入不落循环体
.Lcm_loop:
  ld1      {v0.4s}, [x0], #16
  fmul     v0.4s, v0.4s, v1.4s
  fcvtns   v0.4s, v0.4s              // RNE + 饱和 → i32 ≙ cvtps2dq
  smax     v0.4s, v0.4s, v3.4s       // 夹取 [-32768, 32767]
  smin     v0.4s, v0.4s, v4.4s
  uzp1     v0.8h, v0.8h, v0.8h       // 各 i32 低半字 → 4×i16 ≙ packssdw
  st1      {v0.8b}, [x1], #8
  subs     w2, w2, #1
  b.ne     .Lcm_loop
.Lcm_done:
end;

procedure conv_stereo_simd_s16(c0_: PSingle; c1_: PSingle; out__: PSmallInt; n4_: LongInt); assembler; nostackframe;
{ out__ 交错 [c0[k],c1[k]]。窄化用 mono 版同款夹取+self-uzp1 方案，
  再 zip1 交错两通道低半字 ≙ packssdw+punpcklwd（注意双源 uzp1 是块状
  解压不是交错，直接 uzp1 v0,v0,v2 会得到 [L0..L3,R0..R3]）。
  x0=c0_ x1=c1_ x2=out__ w3=n4_ }
asm
  cmp      w3, #0
  b.le     .Lcs_done
  movz     w4, #0x4700, lsl #16
  dup      v1.4s, w4
  movn     w5, #32767
  dup      v3.4s, w5
  movz     w6, #32767
  dup      v4.4s, w6
  lsr      w3, w3, #2
  cbz      w3, .Lcs_done             // 非 4 倍数的契约外输入不落循环体
.Lcs_loop:
  ld1      {v0.4s}, [x0], #16
  fmul     v0.4s, v0.4s, v1.4s
  fcvtns   v0.4s, v0.4s
  ld1      {v2.4s}, [x1], #16
  fmul     v2.4s, v2.4s, v1.4s
  fcvtns   v2.4s, v2.4s
  smax     v0.4s, v0.4s, v3.4s
  smin     v0.4s, v0.4s, v4.4s
  smax     v2.4s, v2.4s, v3.4s
  smin     v2.4s, v2.4s, v4.4s
  uzp1     v0.8h, v0.8h, v0.8h       // 各自取低半字窄化（上半为重复垃圾）
  uzp1     v2.8h, v2.8h, v2.8h
  zip1     v0.8h, v0.8h, v2.8h       // [L0,R0,L1,R1,...] ≙ punpcklwd
  st1      {v0.16b}, [x2], #16
  subs     w3, w3, #1
  b.ne     .Lcs_loop
.Lcs_done:
end;
{$endif cpuaarch64}

procedure convert_channels_short_interleaved(buf_c: LongInt; buffer: PSmallInt; data_c: LongInt; data: PPSingle; d_offset: LongInt; len_2: LongInt);
label _L__for0_step, _L__for1_step, _L__for2_step, _L__for3_step;
var
  i_2: LongInt;
  limit: LongInt;
  j: LongInt;
  temp_2: TFloatConv;
  f: Single;
  v: LongInt;
  c2p_n4: LongInt;
  c2p_safe: Boolean;
  __c2p_tmp1: LongInt;
  __c2p_tmp3: PSmallInt;
  __c2p_tmp2: LongInt;
  __c2p_tmp4: PSmallInt;
begin
  if (((buf_c <> data_c) and (buf_c <= 2)) and (data_c <= 6)) then
  begin
    i_2 := 0;
    while (i_2 < buf_c) do
    begin
      compute_stereo_samples(buffer, data_c, data, d_offset, len_2);
      _L__for0_step:
      i_2 := (i_2 + 1);
    end;
  end
  else
  begin
    if (buf_c < data_c) then
    begin
      __c2p_tmp1 := buf_c;
    end
    else
    begin
      __c2p_tmp1 := data_c;
    end;
    limit := __c2p_tmp1;
    {$ifdef C2P_SIMD}
    { 手工优化段：等通道数 mono/stereo 快路径（无补零无 downmix），4 样本/轮，
      尾部标量回退 }
    if (buf_c = data_c) and ((buf_c = 1) or (buf_c = 2)) then
    begin
      if buf_c = 2 then
        c2p_safe := conv_range_ok(@(data[0][d_offset]), @(data[1][d_offset]), len_2)
      else
        c2p_safe := conv_range_ok(@(data[0][d_offset]), PSingle(nil), len_2);
    end
    else
      c2p_safe := False;
    if c2p_safe and use_k2 then
    begin
      c2p_n4 := (len_2 div 4) * 4;
      case buf_c of
        1: conv_mono_simd_s16(@(data[0][d_offset]), buffer, c2p_n4);
        2: conv_stereo_simd_s16(@(data[0][d_offset]), @(data[1][d_offset]), buffer, c2p_n4);
      end;
      j := c2p_n4;
      buffer := (buffer + (c2p_n4 * buf_c));
      while (j < len_2) do
      begin
        i_2 := 0;
        while (i_2 < limit) do
        begin
          f := data[i_2][(d_offset + j)];
          temp_2.f := (f + ((Single(1.5) * (1 shl (23 - 15))) + (Single(0.5) / (1 shl 15))));
          v := (temp_2.i - (((150 - 15) shl 23) + (1 shl 22)));
          if (LongWord((v + 32768)) > LongWord(65535)) then
          begin
            if (v < 0) then
              __c2p_tmp2 := -32768
            else
              __c2p_tmp2 := 32767;
            v := __c2p_tmp2;
          end;
          __c2p_tmp3 := buffer;
          buffer := (buffer + 1);
          __c2p_tmp3^ := SmallInt(v);
          i_2 := (i_2 + 1);
        end;
        j := (j + 1);
      end;
      System.Exit;
    end;
    {$endif}
    j := 0;
    while (j < len_2) do
    begin
      i_2 := 0;
      while (i_2 < limit) do
      begin
        f := data[i_2][(d_offset + j)];
        temp_2.f := (f + ((Single(1.5) * (1 shl (23 - 15))) + (Single(0.5) / (1 shl 15))));
        v := (temp_2.i - (((150 - 15) shl 23) + (1 shl 22)));
        if (LongWord((v + 32768)) > LongWord(65535)) then
        begin
          if (v < 0) then
          begin
            __c2p_tmp2 := -32768;
          end
          else
          begin
            __c2p_tmp2 := 32767;
          end;
          v := __c2p_tmp2;
        end;
        __c2p_tmp3 := buffer;
        buffer := (buffer + 1);
        __c2p_tmp3^ := SmallInt(v);
        _L__for2_step:
        i_2 := (i_2 + 1);
      end;
      while (i_2 < buf_c) do
      begin
        __c2p_tmp4 := buffer;
        buffer := (buffer + 1);
        __c2p_tmp4^ := SmallInt(0);
        _L__for3_step:
        i_2 := (i_2 + 1);
      end;
      _L__for1_step:
      j := (j + 1);
    end;
  end;
end;

function stb_vorbis_get_frame_short_interleaved(f: PStbVorbis; num_c: LongInt; buffer: PSmallInt; num_shorts: LongInt): LongInt; cdecl; public name 'stb_vorbis_get_frame_short_interleaved';
var
  output: PPSingle;
  len_2: LongInt;
begin
  if (num_c = 1) then
  begin
    Result := stb_vorbis_get_frame_short(f, num_c, @buffer, num_shorts);
    System.Exit;
  end;
  len_2 := stb_vorbis_get_frame_float(f, PLongInt(Pointer(0)), @output);
  if (len_2 <> 0) then
  begin
    if ((len_2 * num_c) > num_shorts) then
    begin
      len_2 := (num_shorts div num_c);
    end;
    convert_channels_short_interleaved(num_c, buffer, f^.channels, output, 0, len_2);
  end;
  Result := len_2;
end;

function stb_vorbis_get_samples_short_interleaved(f: PStbVorbis; channels: LongInt; buffer: PSmallInt; num_shorts: LongInt): LongInt; cdecl; public name 'stb_vorbis_get_samples_short_interleaved';
var
  outputs: PPSingle;
  len_2: LongInt;
  n_2: LongInt;
  k: LongInt;
begin
  len_2 := (num_shorts div channels);
  n_2 := 0;
  while (n_2 < len_2) do
  begin
    k := (f^.channel_buffer_end - f^.channel_buffer_start);
    if ((n_2 + k) >= len_2) then
    begin
      k := (len_2 - n_2);
    end;
    if (k <> 0) then
    begin
      convert_channels_short_interleaved(channels, buffer, f^.channels, PPSingle(@f^.channel_buffers[0]), f^.channel_buffer_start, k);
    end;
    buffer := (buffer + (k * channels));
    n_2 := (n_2 + k);
    f^.channel_buffer_start := (f^.channel_buffer_start + k);
    if (n_2 = len_2) then
    begin
      Break;
    end;
    if (stb_vorbis_get_frame_float(f, PLongInt(Pointer(0)), @outputs) = 0) then
    begin
      Break;
    end;
  end;
  Result := n_2;
end;

function stb_vorbis_get_samples_short(f: PStbVorbis; channels: LongInt; buffer: PPSmallInt; len_2: LongInt): LongInt; cdecl; public name 'stb_vorbis_get_samples_short'; inline;
var
  outputs: PPSingle;
  n_2: LongInt;
  k: LongInt;
begin
  n_2 := 0;
  while (n_2 < len_2) do
  begin
    k := (f^.channel_buffer_end - f^.channel_buffer_start);
    if ((n_2 + k) >= len_2) then
    begin
      k := (len_2 - n_2);
    end;
    if (k <> 0) then
    begin
      convert_samples_short(channels, buffer, n_2, f^.channels, PPSingle(@f^.channel_buffers[0]), f^.channel_buffer_start, k);
    end;
    n_2 := (n_2 + k);
    f^.channel_buffer_start := (f^.channel_buffer_start + k);
    if (n_2 = len_2) then
    begin
      Break;
    end;
    if (stb_vorbis_get_frame_float(f, PLongInt(Pointer(0)), @outputs) = 0) then
    begin
      Break;
    end;
  end;
  Result := n_2;
end;

function stb_vorbis_decode_filename(filename: PAnsiChar; channels: PLongInt; sample_rate: PLongInt; output: PPSmallInt): LongInt; cdecl; public name 'stb_vorbis_decode_filename';
var
  data_len: LongInt;
  offset: LongInt;
  total: LongInt;
  limit: LongInt;
  LError: LongInt;
  data: PSmallInt;
  v: PStbVorbis;
  n_2: LongInt;
  data2: PSmallInt;
  __c2p_tmp1: LongInt;
begin
  v := PStbVorbis(stb_vorbis_open_filename(filename, @LError, PStbVorbisAlloc(Pointer(0))));
  if (v = nil) then
  begin
    Result := -1;
    System.Exit;
  end;
  limit := (v^.channels * 4096);
  channels^ := v^.channels;
  if (sample_rate <> nil) then
  begin
    sample_rate^ := LongInt(v^.sample_rate);
  end;
  __c2p_tmp1 := 0;
  data_len := __c2p_tmp1;
  offset := __c2p_tmp1;
  total := limit;
  data := PSmallInt(__c2p_mem_malloc(TSizeT(QWord((QWord(total) * 2)))));
  if (data = nil) then
  begin
    stb_vorbis_close(v);
    Result := -2;
    System.Exit;
  end;
  while True do
  begin
    n_2 := stb_vorbis_get_frame_short_interleaved(v, v^.channels, (data + offset), (total - offset));
    if (n_2 = 0) then
    begin
      Break;
    end;
    data_len := (data_len + n_2);
    offset := (offset + (n_2 * v^.channels));
    if ((offset + limit) > total) then
    begin
      total := (total * 2);
      data2 := PSmallInt(__c2p_mem_realloc(data, TSizeT(QWord((QWord(total) * 2)))));
      if (data2 = nil) then
      begin
        __c2p_mem_free(data);
        stb_vorbis_close(v);
        Result := -2;
        System.Exit;
      end;
      data := data2;
    end;
  end;
  output^ := data;
  stb_vorbis_close(v);
  Result := data_len;
end;

function stb_vorbis_decode_memory(mem: PUint8; len_2: LongInt; channels: PLongInt; sample_rate: PLongInt; output: PPSmallInt): LongInt; cdecl; public name 'stb_vorbis_decode_memory';
var
  data_len: LongInt;
  offset: LongInt;
  total: LongInt;
  limit: LongInt;
  LError: LongInt;
  data: PSmallInt;
  v: PStbVorbis;
  n_2: LongInt;
  data2: PSmallInt;
  __c2p_tmp1: LongInt;
begin
  v := PStbVorbis(stb_vorbis_open_memory(mem, len_2, @LError, PStbVorbisAlloc(Pointer(0))));
  if (v = nil) then
  begin
    Result := -1;
    System.Exit;
  end;
  limit := (v^.channels * 4096);
  channels^ := v^.channels;
  if (sample_rate <> nil) then
  begin
    sample_rate^ := LongInt(v^.sample_rate);
  end;
  __c2p_tmp1 := 0;
  data_len := __c2p_tmp1;
  offset := __c2p_tmp1;
  total := limit;
  data := PSmallInt(__c2p_mem_malloc(TSizeT(QWord((QWord(total) * 2)))));
  if (data = nil) then
  begin
    stb_vorbis_close(v);
    Result := -2;
    System.Exit;
  end;
  while True do
  begin
    n_2 := stb_vorbis_get_frame_short_interleaved(v, v^.channels, (data + offset), (total - offset));
    if (n_2 = 0) then
    begin
      Break;
    end;
    data_len := (data_len + n_2);
    offset := (offset + (n_2 * v^.channels));
    if ((offset + limit) > total) then
    begin
      total := (total * 2);
      data2 := PSmallInt(__c2p_mem_realloc(data, TSizeT(QWord((QWord(total) * 2)))));
      if (data2 = nil) then
      begin
        __c2p_mem_free(data);
        stb_vorbis_close(v);
        Result := -2;
        System.Exit;
      end;
      data := data2;
    end;
  end;
  output^ := data;
  stb_vorbis_close(v);
  Result := data_len;
end;

function stb_vorbis_get_samples_float_interleaved(f: PStbVorbis; channels: LongInt; buffer: PSingle; num_floats: LongInt): LongInt; cdecl; public name 'stb_vorbis_get_samples_float_interleaved';
label _L__for0_step, _L__for1_step, _L__for2_step;
var
  outputs: PPSingle;
  len_2: LongInt;
  n_2: LongInt;
  z_2: LongInt;
  i_2: LongInt;
  j: LongInt;
  k: LongInt;
  __c2p_tmp1: PSingle;
  __c2p_tmp2: PSingle;
begin
  len_2 := (num_floats div channels);
  n_2 := 0;
  z_2 := f^.channels;
  if (z_2 > channels) then
  begin
    z_2 := channels;
  end;
  while (n_2 < len_2) do
  begin
    k := (f^.channel_buffer_end - f^.channel_buffer_start);
    if ((n_2 + k) >= len_2) then
    begin
      k := (len_2 - n_2);
    end;
    j := 0;
    while (j < k) do
    begin
      i_2 := 0;
      while (i_2 < z_2) do
      begin
        __c2p_tmp1 := buffer;
        buffer := (buffer + 1);
        __c2p_tmp1^ := f^.channel_buffers[i_2][(f^.channel_buffer_start + j)];
        _L__for1_step:
        i_2 := (i_2 + 1);
      end;
      while (i_2 < channels) do
      begin
        __c2p_tmp2 := buffer;
        buffer := (buffer + 1);
        __c2p_tmp2^ := 0;
        _L__for2_step:
        i_2 := (i_2 + 1);
      end;
      _L__for0_step:
      j := (j + 1);
    end;
    n_2 := (n_2 + k);
    f^.channel_buffer_start := (f^.channel_buffer_start + k);
    if (n_2 = len_2) then
    begin
      Break;
    end;
    if (stb_vorbis_get_frame_float(f, PLongInt(Pointer(0)), @outputs) = 0) then
    begin
      Break;
    end;
  end;
  Result := n_2;
end;

function stb_vorbis_get_samples_float(f: PStbVorbis; channels: LongInt; buffer: PPSingle; num_samples: LongInt): LongInt; cdecl; public name 'stb_vorbis_get_samples_float'; inline;
label _L__for0_step, _L__for1_step;
var
  outputs: PPSingle;
  n_2: LongInt;
  z_2: LongInt;
  i_2: LongInt;
  k: LongInt;
begin
  n_2 := 0;
  z_2 := f^.channels;
  if (z_2 > channels) then
  begin
    z_2 := channels;
  end;
  while (n_2 < num_samples) do
  begin
    k := (f^.channel_buffer_end - f^.channel_buffer_start);
    if ((n_2 + k) >= num_samples) then
    begin
      k := (num_samples - n_2);
    end;
    if (k <> 0) then
    begin
      i_2 := 0;
      while (i_2 < z_2) do
      begin
        __c2p_stdlib_memcpy((buffer[i_2] + n_2), (f^.channel_buffers[i_2] + f^.channel_buffer_start), TSizeT(QWord((4 * QWord(k)))));
        _L__for0_step:
        i_2 := (i_2 + 1);
      end;
      while (i_2 < channels) do
      begin
        __c2p_stdlib_memset((buffer[i_2] + n_2), 0, TSizeT(QWord((4 * QWord(k)))));
        _L__for1_step:
        i_2 := (i_2 + 1);
      end;
    end;
    n_2 := (n_2 + k);
    f^.channel_buffer_start := (f^.channel_buffer_start + k);
    if (n_2 = num_samples) then
    begin
      Break;
    end;
    if (stb_vorbis_get_frame_float(f, PLongInt(Pointer(0)), @outputs) = 0) then
    begin
      Break;
    end;
  end;
  Result := n_2;
end;

procedure __c2p_static_fill_music888_vorbisdec;
begin
  if __c2p_static_filled_music888_vorbisdec then Exit;
  __c2p_static_filled_music888_vorbisdec := True;
  FillChar(_static_ilog_log2_4, SizeOf(_static_ilog_log2_4), 0);
  _static_ilog_log2_4[0] := ShortInt(0);
  _static_ilog_log2_4[1] := ShortInt(1);
  _static_ilog_log2_4[2] := ShortInt(2);
  _static_ilog_log2_4[3] := ShortInt(2);
  _static_ilog_log2_4[4] := ShortInt(3);
  _static_ilog_log2_4[5] := ShortInt(3);
  _static_ilog_log2_4[6] := ShortInt(3);
  _static_ilog_log2_4[7] := ShortInt(3);
  _static_ilog_log2_4[8] := ShortInt(4);
  _static_ilog_log2_4[9] := ShortInt(4);
  _static_ilog_log2_4[10] := ShortInt(4);
  _static_ilog_log2_4[11] := ShortInt(4);
  _static_ilog_log2_4[12] := ShortInt(4);
  _static_ilog_log2_4[13] := ShortInt(4);
  _static_ilog_log2_4[14] := ShortInt(4);
  _static_ilog_log2_4[15] := ShortInt(4);
  FillChar(_static_vorbis_validate_vorbis, SizeOf(_static_vorbis_validate_vorbis), 0);
  _static_vorbis_validate_vorbis[0] := TUint8(118);
  _static_vorbis_validate_vorbis[1] := TUint8(111);
  _static_vorbis_validate_vorbis[2] := TUint8(114);
  _static_vorbis_validate_vorbis[3] := TUint8(98);
  _static_vorbis_validate_vorbis[4] := TUint8(105);
  _static_vorbis_validate_vorbis[5] := TUint8(115);
  FillChar(_static_vorbis_decode_packet_rest_range_list, SizeOf(_static_vorbis_decode_packet_rest_range_list), 0);
  _static_vorbis_decode_packet_rest_range_list[0] := 256;
  _static_vorbis_decode_packet_rest_range_list[1] := 128;
  _static_vorbis_decode_packet_rest_range_list[2] := 86;
  _static_vorbis_decode_packet_rest_range_list[3] := 64;
  FillChar(_static_convert_samples_short_channel_selector, SizeOf(_static_convert_samples_short_channel_selector), 0);
  _static_convert_samples_short_channel_selector[0][0] := 0;
  _static_convert_samples_short_channel_selector[1][0] := 1;
  _static_convert_samples_short_channel_selector[2][0] := 2;
  _static_convert_samples_short_channel_selector[2][1] := 4;
end;

initialization
  SetExceptionMask(GetExceptionMask + [exInvalidOp, exZeroDivide,
    exOverflow, exUnderflow, exPrecision]);
  __c2p_static_fill_music888_vorbisdec;
end.
