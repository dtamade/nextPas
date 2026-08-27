unit nextpas.core.audio.codec.flac;

{ ============================================================================ }
{ 纯 Pascal FLAC 解码器（miniflac 语义）                                        }
{                                                                              }
{ 来源：miniflac 单文件 C 库（github.com/Aritile/miniflac 镜像，0BSD）经        }
{ c2pas888 翻译为 Pascal，随后手工润色修复：                                    }
{   - 修复 13 处 C switch 串落（fallthrough/goto）被错误翻译为提前返回的缺陷     }
{     （sync_internal ×2、frame_header_decode ×7、residual_decode ×4），        }
{     以及 cuesheet_read_index_point_offset 的重复桩块                          }
{   - 清理死标签声明（编译零警告）、内部助手改名 cflac_Sar32/Sar64              }
{ 与 C miniflac 解码输出逐位一致；C 输出又与 flac CLI 位一致。                  }
{ 测试矩阵：8/16/24 bit、1/2/4 声道、压缩级别 -0..-8、含 picture/seektable/     }
{ vorbis comment 元数据文件——全部 cmp 位精确。                                  }
{ 仅依赖 System（无 FPC RTL 直连）；算术右移助手为反哺 nextpas.core 的候选。     }
{ ============================================================================ }


{$mode objfpc}{$H+}
{$PACKRECORDS C}

interface

type
  TMINIFLACRESULT = LongInt;
  TMINIFLACOGGHEADERSTATE = LongInt;
  TMINIFLACOGGSTATE = LongInt;
  TMINIFLACSTREAMMARKERSTATE = LongInt;
  TMINIFLACMETADATATYPE = LongInt;
  TMINIFLACMETADATAHEADERSTATE = LongInt;
  TMINIFLACSTREAMINFOSTATE = LongInt;
  TMINIFLACVORBISCOMMENTSTATE = LongInt;
  TMINIFLACPICTURESTATE = LongInt;
  TMINIFLACCUESHEETSTATE = LongInt;
  TMINIFLACSEEKTABLESTATE = LongInt;
  TMINIFLACAPPLICATIONSTATE = LongInt;
  TMINIFLACMETADATASTATE = LongInt;
  TMINIFLACRESIDUALSTATE = LongInt;
  TMINIFLACSUBFRAMEFIXEDSTATE = LongInt;
  TMINIFLACSUBFRAMELPCSTATE = LongInt;
  TMINIFLACSUBFRAMECONSTANTSTATE = LongInt;
  TMINIFLACSUBFRAMEVERBATIMSTATE = LongInt;
  TMINIFLACSUBFRAMETYPE = LongInt;
  TMINIFLACSUBFRAMEHEADERSTATE = LongInt;
  TMINIFLACSUBFRAMESTATE = LongInt;
  TMINIFLACCHASSGN = LongInt;
  TMINIFLACFRAMEHEADERSTATE = LongInt;
  TMINIFLACFRAMESTATE = LongInt;
  TMINIFLACSTATE = LongInt;
  TMINIFLACCONTAINER = LongInt;
  TMFLACRESULT = LongInt;
  TUint64T = QWord;
  TUint8T = Byte;
  TUint16T = Word;
  TUint32T = LongWord;
  TInt64T = Int64;
  TInt32T = LongInt;
  TSizeT = QWord;
  TPtrdiffT = Int64;
  TWcharT = LongInt;
  TXBuiltinVaList = Pointer;
  TInt8T = ShortInt;
  TInt16T = SmallInt;
  TIntptrT = Int64;
  TUintptrT = QWord;
  TIntmaxT = Int64;
  TUintmaxT = QWord;
  PMiniflacBitreaderS = ^TMiniflacBitreaderS;
  PUint8T = ^TUint8T;
  PTUint8T = PUint8T;
  PMiniflacOggheaderS = ^TMiniflacOggheaderS;
  PMiniflacOggS = ^TMiniflacOggS;
  PMiniflacStreammarkerS = ^TMiniflacStreammarkerS;
  PMiniflacMetadataHeaderS = ^TMiniflacMetadataHeaderS;
  PMiniflacStreaminfoS = ^TMiniflacStreaminfoS;
  PMiniflacVorbisCommentS = ^TMiniflacVorbisCommentS;
  PMiniflacPictureS = ^TMiniflacPictureS;
  PMiniflacCuesheetS = ^TMiniflacCuesheetS;
  PMiniflacSeektableS = ^TMiniflacSeektableS;
  PMiniflacApplicationS = ^TMiniflacApplicationS;
  PMiniflacPaddingS = ^TMiniflacPaddingS;
  PMiniflacMetadataS = ^TMiniflacMetadataS;
  PMiniflacResidualS = ^TMiniflacResidualS;
  PMiniflacSubframeFixedS = ^TMiniflacSubframeFixedS;
  PMiniflacSubframeLpcS = ^TMiniflacSubframeLpcS;
  PMiniflacSubframeConstantS = ^TMiniflacSubframeConstantS;
  PMiniflacSubframeVerbatimS = ^TMiniflacSubframeVerbatimS;
  PMiniflacSubframeHeaderS = ^TMiniflacSubframeHeaderS;
  PMiniflacSubframeS = ^TMiniflacSubframeS;
  PMiniflacFrameHeaderS = ^TMiniflacFrameHeaderS;
  PMiniflacFrameS = ^TMiniflacFrameS;
  PMiniflacS = ^TMiniflacS;
  PMflacS = ^TMflacS;
  PMiniflacBitreaderT = ^TMiniflacBitreaderT;
  PTMiniflacBitreaderT = PMiniflacBitreaderT;
  PMiniflacOggheaderT = ^TMiniflacOggheaderT;
  PTMiniflacOggheaderT = PMiniflacOggheaderT;
  PMiniflacOggT = ^TMiniflacOggT;
  PTMiniflacOggT = PMiniflacOggT;
  PMiniflacStreammarkerT = ^TMiniflacStreammarkerT;
  PTMiniflacStreammarkerT = PMiniflacStreammarkerT;
  PMiniflacMetadataHeaderT = ^TMiniflacMetadataHeaderT;
  PTMiniflacMetadataHeaderT = PMiniflacMetadataHeaderT;
  PMiniflacStreaminfoT = ^TMiniflacStreaminfoT;
  PTMiniflacStreaminfoT = PMiniflacStreaminfoT;
  PMiniflacVorbisCommentT = ^TMiniflacVorbisCommentT;
  PTMiniflacVorbisCommentT = PMiniflacVorbisCommentT;
  PMiniflacPictureT = ^TMiniflacPictureT;
  PTMiniflacPictureT = PMiniflacPictureT;
  PMiniflacCuesheetT = ^TMiniflacCuesheetT;
  PTMiniflacCuesheetT = PMiniflacCuesheetT;
  PMiniflacSeektableT = ^TMiniflacSeektableT;
  PTMiniflacSeektableT = PMiniflacSeektableT;
  PMiniflacApplicationT = ^TMiniflacApplicationT;
  PTMiniflacApplicationT = PMiniflacApplicationT;
  PMiniflacPaddingT = ^TMiniflacPaddingT;
  PTMiniflacPaddingT = PMiniflacPaddingT;
  PMiniflacMetadataT = ^TMiniflacMetadataT;
  PTMiniflacMetadataT = PMiniflacMetadataT;
  PMiniflacResidualT = ^TMiniflacResidualT;
  PTMiniflacResidualT = PMiniflacResidualT;
  PMiniflacSubframeFixedT = ^TMiniflacSubframeFixedT;
  PTMiniflacSubframeFixedT = PMiniflacSubframeFixedT;
  PMiniflacSubframeLpcT = ^TMiniflacSubframeLpcT;
  PTMiniflacSubframeLpcT = PMiniflacSubframeLpcT;
  PMiniflacSubframeConstantT = ^TMiniflacSubframeConstantT;
  PTMiniflacSubframeConstantT = PMiniflacSubframeConstantT;
  PMiniflacSubframeVerbatimT = ^TMiniflacSubframeVerbatimT;
  PTMiniflacSubframeVerbatimT = PMiniflacSubframeVerbatimT;
  PMiniflacSubframeHeaderT = ^TMiniflacSubframeHeaderT;
  PTMiniflacSubframeHeaderT = PMiniflacSubframeHeaderT;
  PMiniflacSubframeT = ^TMiniflacSubframeT;
  PTMiniflacSubframeT = PMiniflacSubframeT;
  PMiniflacFrameHeaderT = ^TMiniflacFrameHeaderT;
  PTMiniflacFrameHeaderT = PMiniflacFrameHeaderT;
  PMiniflacFrameT = ^TMiniflacFrameT;
  PTMiniflacFrameT = PMiniflacFrameT;
  PMiniflacT = ^TMiniflacT;
  PTMiniflacT = PMiniflacT;
  PMflacT = ^TMflacT;
  PTMflacT = PMflacT;
  PMINIFLACRESULT = ^TMINIFLACRESULT;
  PTMINIFLACRESULT = PMINIFLACRESULT;
  PMINIFLACOGGHEADERSTATE = ^TMINIFLACOGGHEADERSTATE;
  PTMINIFLACOGGHEADERSTATE = PMINIFLACOGGHEADERSTATE;
  PMINIFLACOGGSTATE = ^TMINIFLACOGGSTATE;
  PTMINIFLACOGGSTATE = PMINIFLACOGGSTATE;
  PMINIFLACSTREAMMARKERSTATE = ^TMINIFLACSTREAMMARKERSTATE;
  PTMINIFLACSTREAMMARKERSTATE = PMINIFLACSTREAMMARKERSTATE;
  PMINIFLACMETADATATYPE = ^TMINIFLACMETADATATYPE;
  PTMINIFLACMETADATATYPE = PMINIFLACMETADATATYPE;
  PMINIFLACMETADATAHEADERSTATE = ^TMINIFLACMETADATAHEADERSTATE;
  PTMINIFLACMETADATAHEADERSTATE = PMINIFLACMETADATAHEADERSTATE;
  PMINIFLACSTREAMINFOSTATE = ^TMINIFLACSTREAMINFOSTATE;
  PTMINIFLACSTREAMINFOSTATE = PMINIFLACSTREAMINFOSTATE;
  PMINIFLACVORBISCOMMENTSTATE = ^TMINIFLACVORBISCOMMENTSTATE;
  PTMINIFLACVORBISCOMMENTSTATE = PMINIFLACVORBISCOMMENTSTATE;
  PMINIFLACPICTURESTATE = ^TMINIFLACPICTURESTATE;
  PTMINIFLACPICTURESTATE = PMINIFLACPICTURESTATE;
  PMINIFLACCUESHEETSTATE = ^TMINIFLACCUESHEETSTATE;
  PTMINIFLACCUESHEETSTATE = PMINIFLACCUESHEETSTATE;
  PMINIFLACSEEKTABLESTATE = ^TMINIFLACSEEKTABLESTATE;
  PTMINIFLACSEEKTABLESTATE = PMINIFLACSEEKTABLESTATE;
  PMINIFLACAPPLICATIONSTATE = ^TMINIFLACAPPLICATIONSTATE;
  PTMINIFLACAPPLICATIONSTATE = PMINIFLACAPPLICATIONSTATE;
  PMINIFLACMETADATASTATE = ^TMINIFLACMETADATASTATE;
  PTMINIFLACMETADATASTATE = PMINIFLACMETADATASTATE;
  PMINIFLACRESIDUALSTATE = ^TMINIFLACRESIDUALSTATE;
  PTMINIFLACRESIDUALSTATE = PMINIFLACRESIDUALSTATE;
  PMINIFLACSUBFRAMEFIXEDSTATE = ^TMINIFLACSUBFRAMEFIXEDSTATE;
  PTMINIFLACSUBFRAMEFIXEDSTATE = PMINIFLACSUBFRAMEFIXEDSTATE;
  PMINIFLACSUBFRAMELPCSTATE = ^TMINIFLACSUBFRAMELPCSTATE;
  PTMINIFLACSUBFRAMELPCSTATE = PMINIFLACSUBFRAMELPCSTATE;
  PMINIFLACSUBFRAMECONSTANTSTATE = ^TMINIFLACSUBFRAMECONSTANTSTATE;
  PTMINIFLACSUBFRAMECONSTANTSTATE = PMINIFLACSUBFRAMECONSTANTSTATE;
  PMINIFLACSUBFRAMEVERBATIMSTATE = ^TMINIFLACSUBFRAMEVERBATIMSTATE;
  PTMINIFLACSUBFRAMEVERBATIMSTATE = PMINIFLACSUBFRAMEVERBATIMSTATE;
  PMINIFLACSUBFRAMETYPE = ^TMINIFLACSUBFRAMETYPE;
  PTMINIFLACSUBFRAMETYPE = PMINIFLACSUBFRAMETYPE;
  PMINIFLACSUBFRAMEHEADERSTATE = ^TMINIFLACSUBFRAMEHEADERSTATE;
  PTMINIFLACSUBFRAMEHEADERSTATE = PMINIFLACSUBFRAMEHEADERSTATE;
  PMINIFLACSUBFRAMESTATE = ^TMINIFLACSUBFRAMESTATE;
  PTMINIFLACSUBFRAMESTATE = PMINIFLACSUBFRAMESTATE;
  PMINIFLACCHASSGN = ^TMINIFLACCHASSGN;
  PTMINIFLACCHASSGN = PMINIFLACCHASSGN;
  PMINIFLACFRAMEHEADERSTATE = ^TMINIFLACFRAMEHEADERSTATE;
  PTMINIFLACFRAMEHEADERSTATE = PMINIFLACFRAMEHEADERSTATE;
  PMINIFLACFRAMESTATE = ^TMINIFLACFRAMESTATE;
  PTMINIFLACFRAMESTATE = PMINIFLACFRAMESTATE;
  PMINIFLACSTATE = ^TMINIFLACSTATE;
  PTMINIFLACSTATE = PMINIFLACSTATE;
  PMINIFLACCONTAINER = ^TMINIFLACCONTAINER;
  PTMINIFLACCONTAINER = PMINIFLACCONTAINER;
  PMFLACRESULT = ^TMFLACRESULT;
  PTMFLACRESULT = PMFLACRESULT;
  PUint16T = ^TUint16T;
  PTUint16T = PUint16T;
  PUint32T = ^TUint32T;
  PTUint32T = PUint32T;
  PUint64T = ^TUint64T;
  PTUint64T = PUint64T;
  PInt32T = ^TInt32T;
  PTInt32T = PInt32T;
  PPInt32T = ^PInt32T;
  PPUint8T = ^PUint8T;
  TMflacReadcb = function(p0: PUint8T; p1: TSizeT; p2: Pointer): TSizeT; cdecl;
  TMiniflacBitreaderS = record
    val: TUint64T;
    bits: TUint8T;
    crc8: TUint8T;
    crc16: TUint16T;
    pos: TUint32T;
    len: TUint32T;
    buffer: PUint8T;
    tot: TUint32T;
  end;
  TMiniflacOggheaderS = record
    state: LongInt;
  end;
  TMiniflacOggS = record
    state: LongInt;
    br: TMiniflacBitreaderS;
    version: TUint8T;
    headertype: TUint8T;
    granulepos: TInt64T;
    serialno: TInt32T;
    pageno: TUint32T;
    segments: TUint8T;
    curseg: TUint8T;
    length: TUint16T;
    pos: TUint16T;
  end;
  TMiniflacStreammarkerS = record
    state: LongInt;
  end;
  TMiniflacMetadataHeaderS = record
    state: LongInt;
    is_last: TUint8T;
    type_raw: TUint8T;
    &type: LongInt;
    length: TUint32T;
  end;
  TMiniflacStreaminfoS = record
    state: LongInt;
    pos: TUint8T;
    sample_rate: TUint32T;
    bps: TUint8T;
  end;
  TMiniflacVorbisCommentS = record
    state: LongInt;
    len: TUint32T;
    pos: TUint32T;
    tot: TUint32T;
    cur: TUint32T;
  end;
  TMiniflacPictureS = record
    state: LongInt;
    len: TUint32T;
    pos: TUint32T;
  end;
  TMiniflacCuesheetS = record
    state: LongInt;
    pos: TUint32T;
    track: TUint8T;
    tracks: TUint8T;
    point: TUint8T;
    points: TUint8T;
  end;
  TMiniflacSeektableS = record
    state: LongInt;
    len: TUint32T;
    pos: TUint32T;
  end;
  TMiniflacApplicationS = record
    state: LongInt;
    len: TUint32T;
    pos: TUint32T;
  end;
  TMiniflacPaddingS = record
    len: TUint32T;
    pos: TUint32T;
  end;
  TMiniflacMetadataS = record
    state: LongInt;
    pos: TUint32T;
    header: TMiniflacMetadataHeaderS;
    streaminfo: TMiniflacStreaminfoS;
    vorbis_comment: TMiniflacVorbisCommentS;
    picture: TMiniflacPictureS;
    cuesheet: TMiniflacCuesheetS;
    seektable: TMiniflacSeektableS;
    application: TMiniflacApplicationS;
    padding: TMiniflacPaddingS;
  end;
  TMiniflacResidualS = record
    state: LongInt;
    coding_method: TUint8T;
    partition_order: TUint8T;
    rice_parameter: TUint8T;
    rice_size: TUint8T;
    msb: TUint32T;
    rice_parameter_size: TUint8T;
    value: TInt32T;
    partition: TUint32T;
    partition_total: TUint32T;
    residual: TUint32T;
    residual_total: TUint32T;
  end;
  TMiniflacSubframeFixedS = record
    state: LongInt;
    pos: TUint32T;
  end;
  TMiniflacSubframeLpcS = record
    state: LongInt;
    pos: TUint32T;
    precision: TUint8T;
    shift: TUint8T;
    coeff: TUint8T;
    coefficients: array[0..31] of TInt32T;
  end;
  TMiniflacSubframeConstantS = record
    state: LongInt;
  end;
  TMiniflacSubframeVerbatimS = record
    state: LongInt;
    pos: TUint32T;
  end;
  TMiniflacSubframeHeaderS = record
    state: LongInt;
    &type: LongInt;
    order: TUint8T;
    wasted_bits: TUint8T;
    type_raw: TUint8T;
  end;
  TMiniflacSubframeS = record
    state: LongInt;
    bps: TUint8T;
    header: TMiniflacSubframeHeaderS;
    constant: TMiniflacSubframeConstantS;
    verbatim: TMiniflacSubframeVerbatimS;
    fixed: TMiniflacSubframeFixedS;
    lpc: TMiniflacSubframeLpcS;
    residual: TMiniflacResidualS;
  end;
  TMiniflacFrameHeaderSXC2pAnon10 = record
    case Integer of
    0: (sample_number: TUint64T);
    1: (frame_number: TUint32T);
  end;
  TMiniflacFrameHeaderS = record
    state: LongInt;
    block_size_raw: TUint8T;
    sample_rate_raw: TUint8T;
    channel_assignment_raw: TUint8T;
    blocking_strategy: TUint8T;
    block_size: TUint16T;
    sample_rate: TUint32T;
    channel_assignment: LongInt;
    channels: TUint8T;
    bps: TUint8T;
    __c2p_anon10: TMiniflacFrameHeaderSXC2pAnon10;
    crc8: TUint8T;
    size: TSizeT;
  end;
  TMiniflacFrameS = record
    state: LongInt;
    cur_subframe: TUint8T;
    crc16: TUint16T;
    size: TSizeT;
    header: TMiniflacFrameHeaderS;
    subframe: TMiniflacSubframeS;
  end;
  TMiniflacS = record
    state: LongInt;
    container: LongInt;
    br: TMiniflacBitreaderS;
    ogg: TMiniflacOggS;
    oggheader: TMiniflacOggheaderS;
    streammarker: TMiniflacStreammarkerS;
    metadata: TMiniflacMetadataS;
    frame: TMiniflacFrameS;
    oggserial: TInt32T;
    oggserial_set: TUint8T;
    bytes_read_flac: TUint64T;
    bytes_read_ogg: TUint64T;
  end;
  TMflacS = record
    flac: TMiniflacS;
    read: TMflacReadcb;
    userdata: Pointer;
    bufpos: TSizeT;
    buflen: TSizeT;
    buffer: array[0..16383] of TUint8T;
  end;
  TMiniflacBitreaderT = TMiniflacBitreaderS;
  TMiniflacOggheaderT = TMiniflacOggheaderS;
  TMiniflacOggT = TMiniflacOggS;
  TMiniflacStreammarkerT = TMiniflacStreammarkerS;
  TMiniflacMetadataHeaderT = TMiniflacMetadataHeaderS;
  TMiniflacStreaminfoT = TMiniflacStreaminfoS;
  TMiniflacVorbisCommentT = TMiniflacVorbisCommentS;
  TMiniflacPictureT = TMiniflacPictureS;
  TMiniflacCuesheetT = TMiniflacCuesheetS;
  TMiniflacSeektableT = TMiniflacSeektableS;
  TMiniflacApplicationT = TMiniflacApplicationS;
  TMiniflacPaddingT = TMiniflacPaddingS;
  TMiniflacMetadataT = TMiniflacMetadataS;
  TMiniflacResidualT = TMiniflacResidualS;
  TMiniflacSubframeFixedT = TMiniflacSubframeFixedS;
  TMiniflacSubframeLpcT = TMiniflacSubframeLpcS;
  TMiniflacSubframeConstantT = TMiniflacSubframeConstantS;
  TMiniflacSubframeVerbatimT = TMiniflacSubframeVerbatimS;
  TMiniflacSubframeHeaderT = TMiniflacSubframeHeaderS;
  TMiniflacSubframeT = TMiniflacSubframeS;
  TMiniflacFrameHeaderT = TMiniflacFrameHeaderS;
  TMiniflacFrameT = TMiniflacFrameS;
  TMiniflacT = TMiniflacS;
  TMflacT = TMflacS;

const
  MINIFLAC_OGG_HEADER_NOTFLAC = -18;
  MINIFLAC_SUBFRAME_RESERVED_TYPE = -17;
  MINIFLAC_SUBFRAME_RESERVED_BIT = -16;
  MINIFLAC_STREAMMARKER_INVALID = -15;
  MINIFLAC_RESERVED_CODING_METHOD = -14;
  MINIFLAC_METADATA_TYPE_RESERVED = -13;
  MINIFLAC_METADATA_TYPE_INVALID = -12;
  MINIFLAC_FRAME_RESERVED_SAMPLE_SIZE = -11;
  MINIFLAC_FRAME_RESERVED_CHANNEL_ASSIGNMENT = -10;
  MINIFLAC_FRAME_INVALID_SAMPLE_SIZE = -9;
  MINIFLAC_FRAME_INVALID_SAMPLE_RATE = -8;
  MINIFLAC_FRAME_RESERVED_BLOCKSIZE = -7;
  MINIFLAC_FRAME_RESERVED_BIT2 = -6;
  MINIFLAC_FRAME_RESERVED_BIT1 = -5;
  MINIFLAC_FRAME_SYNCCODE_INVALID = -4;
  MINIFLAC_FRAME_CRC16_INVALID = -3;
  MINIFLAC_FRAME_CRC8_INVALID = -2;
  MINIFLAC_ERROR = -1;
  MINIFLAC_CONTINUE = 0;
  MINIFLAC_OK = 1;
  MINIFLAC_METADATA_END = 2;
  MINIFLAC_OGGHEADER_PACKETTYPE = 0;
  MINIFLAC_OGGHEADER_F = 1;
  MINIFLAC_OGGHEADER_L = 2;
  MINIFLAC_OGGHEADER_A = 3;
  MINIFLAC_OGGHEADER_C = 4;
  MINIFLAC_OGGHEADER_MAJOR = 5;
  MINIFLAC_OGGHEADER_MINOR = 6;
  MINIFLAC_OGGHEADER_HEADERPACKETS = 7;
  MINIFLAC_OGG_CAPTUREPATTERN_O = 0;
  MINIFLAC_OGG_CAPTUREPATTERN_G1 = 1;
  MINIFLAC_OGG_CAPTUREPATTERN_G2 = 2;
  MINIFLAC_OGG_CAPTUREPATTERN_S = 3;
  MINIFLAC_OGG_VERSION = 4;
  MINIFLAC_OGG_HEADERTYPE = 5;
  MINIFLAC_OGG_GRANULEPOS = 6;
  MINIFLAC_OGG_SERIALNO = 7;
  MINIFLAC_OGG_PAGENO = 8;
  MINIFLAC_OGG_CHECKSUM = 9;
  MINIFLAC_OGG_PAGESEGMENTS = 10;
  MINIFLAC_OGG_SEGMENTTABLE = 11;
  MINIFLAC_OGG_DATA = 12;
  MINIFLAC_OGG_SKIP = 13;
  MINIFLAC_STREAMMARKER_F = 0;
  MINIFLAC_STREAMMARKER_L = 1;
  MINIFLAC_STREAMMARKER_A = 2;
  MINIFLAC_STREAMMARKER_C = 3;
  MINIFLAC_METADATA_STREAMINFO = 0;
  MINIFLAC_METADATA_PADDING = 1;
  MINIFLAC_METADATA_APPLICATION = 2;
  MINIFLAC_METADATA_SEEKTABLE = 3;
  MINIFLAC_METADATA_VORBIS_COMMENT = 4;
  MINIFLAC_METADATA_CUESHEET = 5;
  MINIFLAC_METADATA_PICTURE = 6;
  MINIFLAC_METADATA_INVALID = 127;
  MINIFLAC_METADATA_UNKNOWN = 128;
  MINIFLAC_METADATA_LAST_FLAG = 0;
  MINIFLAC_METADATA_BLOCK_TYPE = 1;
  MINIFLAC_METADATA_LENGTH_CONST = 2;
  MINIFLAC_STREAMINFO_MINBLOCKSIZE = 0;
  MINIFLAC_STREAMINFO_MAXBLOCKSIZE = 1;
  MINIFLAC_STREAMINFO_MINFRAMESIZE = 2;
  MINIFLAC_STREAMINFO_MAXFRAMESIZE = 3;
  MINIFLAC_STREAMINFO_SAMPLERATE = 4;
  MINIFLAC_STREAMINFO_CHANNELS_CONST = 5;
  MINIFLAC_STREAMINFO_BPS_CONST = 6;
  MINIFLAC_STREAMINFO_TOTALSAMPLES = 7;
  MINIFLAC_STREAMINFO_MD5 = 8;
  MINIFLAC_VORBISCOMMENT_VENDOR_LENGTH = 0;
  MINIFLAC_VORBISCOMMENT_VENDOR_STRING = 1;
  MINIFLAC_VORBISCOMMENT_TOTAL_COMMENTS = 2;
  MINIFLAC_VORBISCOMMENT_COMMENT_LENGTH = 3;
  MINIFLAC_VORBISCOMMENT_COMMENT_STRING = 4;
  MINIFLAC_PICTURE_TYPE_CONST = 0;
  MINIFLAC_PICTURE_MIME_LENGTH_CONST = 1;
  MINIFLAC_PICTURE_MIME_STRING_CONST = 2;
  MINIFLAC_PICTURE_DESCRIPTION_LENGTH_CONST = 3;
  MINIFLAC_PICTURE_DESCRIPTION_STRING_CONST = 4;
  MINIFLAC_PICTURE_WIDTH_CONST = 5;
  MINIFLAC_PICTURE_HEIGHT_CONST = 6;
  MINIFLAC_PICTURE_COLORDEPTH_CONST = 7;
  MINIFLAC_PICTURE_TOTALCOLORS_CONST = 8;
  MINIFLAC_PICTURE_PICTURE_LENGTH = 9;
  MINIFLAC_PICTURE_PICTURE_DATA = 10;
  MINIFLAC_CUESHEET_CATALOG = 0;
  MINIFLAC_CUESHEET_LEADIN_CONST = 1;
  MINIFLAC_CUESHEET_CDFLAG = 2;
  MINIFLAC_CUESHEET_SHEET_RESERVE = 3;
  MINIFLAC_CUESHEET_TRACKS_CONST = 4;
  MINIFLAC_CUESHEET_TRACKOFFSET = 5;
  MINIFLAC_CUESHEET_TRACKNUMBER = 6;
  MINIFLAC_CUESHEET_TRACKISRC = 7;
  MINIFLAC_CUESHEET_TRACKTYPE = 8;
  MINIFLAC_CUESHEET_TRACKPREEMPH = 9;
  MINIFLAC_CUESHEET_TRACK_RESERVE = 10;
  MINIFLAC_CUESHEET_TRACKPOINTS = 11;
  MINIFLAC_CUESHEET_INDEX_OFFSET = 12;
  MINIFLAC_CUESHEET_INDEX_NUMBER = 13;
  MINIFLAC_CUESHEET_INDEX_RESERVE = 14;
  MINIFLAC_SEEKTABLE_SAMPLE_NUMBER_CONST = 0;
  MINIFLAC_SEEKTABLE_SAMPLE_OFFSET_CONST = 1;
  MINIFLAC_SEEKTABLE_SAMPLES_CONST = 2;
  MINIFLAC_APPLICATION_ID_CONST = 0;
  MINIFLAC_APPLICATION_DATA_CONST = 1;
  MINIFLAC_METADATA_HEADER = 0;
  MINIFLAC_METADATA_DATA = 1;
  MINIFLAC_RESIDUAL_CODING_METHOD = 0;
  MINIFLAC_RESIDUAL_PARTITION_ORDER = 1;
  MINIFLAC_RESIDUAL_RICE_PARAMETER = 2;
  MINIFLAC_RESIDUAL_RICE_SIZE = 3;
  MINIFLAC_RESIDUAL_RICE_VALUE = 4;
  MINIFLAC_RESIDUAL_MSB = 5;
  MINIFLAC_RESIDUAL_LSB = 6;
  MINIFLAC_SUBFRAME_FIXED_DECODE_CONST = 0;
  MINIFLAC_SUBFRAME_LPC_PRECISION = 0;
  MINIFLAC_SUBFRAME_LPC_SHIFT = 1;
  MINIFLAC_SUBFRAME_LPC_COEFF = 2;
  MINIFLAC_SUBFRAME_CONSTANT_DECODE_CONST = 0;
  MINIFLAC_SUBFRAME_VERBATIM_DECODE_CONST = 0;
  MINIFLAC_SUBFRAME_TYPE_UNKNOWN = 0;
  MINIFLAC_SUBFRAME_TYPE_CONSTANT = 1;
  MINIFLAC_SUBFRAME_TYPE_FIXED = 2;
  MINIFLAC_SUBFRAME_TYPE_LPC = 3;
  MINIFLAC_SUBFRAME_TYPE_VERBATIM = 4;
  MINIFLAC_SUBFRAME_HEADER_RESERVEBIT1 = 0;
  MINIFLAC_SUBFRAME_HEADER_KIND = 1;
  MINIFLAC_SUBFRAME_HEADER_WASTED_BITS = 2;
  MINIFLAC_SUBFRAME_HEADER_UNARY = 3;
  MINIFLAC_SUBFRAME_HEADER = 0;
  MINIFLAC_SUBFRAME_CONSTANT = 1;
  MINIFLAC_SUBFRAME_VERBATIM = 2;
  MINIFLAC_SUBFRAME_FIXED = 3;
  MINIFLAC_SUBFRAME_LPC = 4;
  MINIFLAC_CHASSGN_NONE = 0;
  MINIFLAC_CHASSGN_LEFT_SIDE = 1;
  MINIFLAC_CHASSGN_RIGHT_SIDE = 2;
  MINIFLAC_CHASSGN_MID_SIDE = 3;
  MINIFLAC_FRAME_HEADER_SYNC = 0;
  MINIFLAC_FRAME_HEADER_RESERVEBIT_1 = 1;
  MINIFLAC_FRAME_HEADER_BLOCKINGSTRATEGY = 2;
  MINIFLAC_FRAME_HEADER_BLOCKSIZE = 3;
  MINIFLAC_FRAME_HEADER_SAMPLERATE = 4;
  MINIFLAC_FRAME_HEADER_CHANNELASSIGNMENT = 5;
  MINIFLAC_FRAME_HEADER_SAMPLESIZE = 6;
  MINIFLAC_FRAME_HEADER_RESERVEBIT_2 = 7;
  MINIFLAC_FRAME_HEADER_SAMPLENUMBER_1 = 8;
  MINIFLAC_FRAME_HEADER_SAMPLENUMBER_2 = 9;
  MINIFLAC_FRAME_HEADER_SAMPLENUMBER_3 = 10;
  MINIFLAC_FRAME_HEADER_SAMPLENUMBER_4 = 11;
  MINIFLAC_FRAME_HEADER_SAMPLENUMBER_5 = 12;
  MINIFLAC_FRAME_HEADER_SAMPLENUMBER_6 = 13;
  MINIFLAC_FRAME_HEADER_SAMPLENUMBER_7 = 14;
  MINIFLAC_FRAME_HEADER_BLOCKSIZE_MAYBE = 15;
  MINIFLAC_FRAME_HEADER_SAMPLERATE_MAYBE = 16;
  MINIFLAC_FRAME_HEADER_CRC8 = 17;
  MINIFLAC_FRAME_HEADER = 0;
  MINIFLAC_FRAME_SUBFRAME = 1;
  MINIFLAC_FRAME_FOOTER = 2;
  MINIFLAC_OGGHEADER = 0;
  MINIFLAC_STREAMMARKER_OR_FRAME = 1;
  MINIFLAC_STREAMMARKER = 2;
  MINIFLAC_METADATA_OR_FRAME = 3;
  MINIFLAC_METADATA = 4;
  MINIFLAC_FRAME = 5;
  MINIFLAC_CONTAINER_UNKNOWN = 0;
  MINIFLAC_CONTAINER_NATIVE = 1;
  MINIFLAC_CONTAINER_OGG = 2;
  MFLAC_EOF = 0;
  MFLAC_OK = 1;
  MFLAC_METADATA_END = 2;
  MFLAC_BUFFER_SIZE = 16384;

function memcpy(dest: Pointer; src: Pointer; n: TSizeT): Pointer; cdecl; external 'c' name 'memcpy';

function memmove(dest: Pointer; src: Pointer; n: TSizeT): Pointer; cdecl; external 'c' name 'memmove';

function memset(s_2: Pointer; c_2: LongInt; n: TSizeT): Pointer; cdecl; external 'c' name 'memset';

function memcmp(s1: Pointer; s2: Pointer; n: TSizeT): LongInt; cdecl; external 'c' name 'memcmp';

function strlen(s_2: PAnsiChar): TSizeT; cdecl; external 'c' name 'strlen';

function strcmp(s1: PAnsiChar; s2: PAnsiChar): LongInt; cdecl; external 'c' name 'strcmp';

function mflac_size(): TSizeT; cdecl;

procedure mflac_init(m_2: PMflacT; container: TMINIFLACCONTAINER; read: TMflacReadcb; userdata: Pointer); cdecl;

procedure mflac_reset(m_2: PMflacT; state: TMINIFLACSTATE); cdecl;

function mflac_sync(m_2: PMflacT): TMFLACRESULT; cdecl;

function mflac_decode(m_2: PMflacT; p1: PPInt32T): TMFLACRESULT; cdecl;

function mflac_streaminfo_min_block_size(m_2: PMflacT; p1: PUint16T): TMFLACRESULT; cdecl;

function mflac_streaminfo_max_block_size(m_2: PMflacT; p1: PUint16T): TMFLACRESULT; cdecl;

function mflac_streaminfo_min_frame_size(m_2: PMflacT; p1: PUint32T): TMFLACRESULT; cdecl;

function mflac_streaminfo_max_frame_size(m_2: PMflacT; p1: PUint32T): TMFLACRESULT; cdecl;

function mflac_streaminfo_sample_rate(m_2: PMflacT; p1: PUint32T): TMFLACRESULT; cdecl;

function mflac_streaminfo_channels(m_2: PMflacT; p1: PUint8T): TMFLACRESULT; cdecl;

function mflac_streaminfo_bps(m_2: PMflacT; p1: PUint8T): TMFLACRESULT; cdecl;

function mflac_streaminfo_total_samples(m_2: PMflacT; p1: PUint64T): TMFLACRESULT; cdecl;

function mflac_streaminfo_md5_length(m_2: PMflacT; p1: PUint32T): TMFLACRESULT; cdecl;

function mflac_streaminfo_md5_data(m_2: PMflacT; p1: PUint8T; p2: TUint32T; p3: PUint32T): TMFLACRESULT; cdecl;

function mflac_vorbis_comment_vendor_length(m_2: PMflacT; p1: PUint32T): TMFLACRESULT; cdecl;

function mflac_vorbis_comment_vendor_string(m_2: PMflacT; p1: PAnsiChar; p2: TUint32T; p3: PUint32T): TMFLACRESULT; cdecl;

function mflac_vorbis_comment_total(m_2: PMflacT; p1: PUint32T): TMFLACRESULT; cdecl;

function mflac_vorbis_comment_length(m_2: PMflacT; p1: PUint32T): TMFLACRESULT; cdecl;

function mflac_vorbis_comment_string(m_2: PMflacT; p1: PAnsiChar; p2: TUint32T; p3: PUint32T): TMFLACRESULT; cdecl;

function mflac_padding_length(m_2: PMflacT; p1: PUint32T): TMFLACRESULT; cdecl;

function mflac_padding_data(m_2: PMflacT; p1: PUint8T; p2: TUint32T; p3: PUint32T): TMFLACRESULT; cdecl;

function mflac_application_id(m_2: PMflacT; p1: PUint32T): TMFLACRESULT; cdecl;

function mflac_application_length(m_2: PMflacT; p1: PUint32T): TMFLACRESULT; cdecl;

function mflac_application_data(m_2: PMflacT; p1: PUint8T; p2: TUint32T; p3: PUint32T): TMFLACRESULT; cdecl;

function mflac_seektable_seekpoints(m_2: PMflacT; p1: PUint32T): TMFLACRESULT; cdecl;

function mflac_seektable_sample_number(m_2: PMflacT; p1: PUint64T): TMFLACRESULT; cdecl;

function mflac_seektable_sample_offset(m_2: PMflacT; p1: PUint64T): TMFLACRESULT; cdecl;

function mflac_seektable_samples(m_2: PMflacT; p1: PUint16T): TMFLACRESULT; cdecl;

function mflac_cuesheet_catalog_length(m_2: PMflacT; p1: PUint32T): TMFLACRESULT; cdecl;

function mflac_cuesheet_catalog_string(m_2: PMflacT; p1: PAnsiChar; p2: TUint32T; p3: PUint32T): TMFLACRESULT; cdecl;

function mflac_cuesheet_leadin(m_2: PMflacT; p1: PUint64T): TMFLACRESULT; cdecl;

function mflac_cuesheet_cd_flag(m_2: PMflacT; p1: PUint8T): TMFLACRESULT; cdecl;

function mflac_cuesheet_tracks(m_2: PMflacT; p1: PUint8T): TMFLACRESULT; cdecl;

function mflac_cuesheet_track_offset(m_2: PMflacT; p1: PUint64T): TMFLACRESULT; cdecl;

function mflac_cuesheet_track_number(m_2: PMflacT; p1: PUint8T): TMFLACRESULT; cdecl;

function mflac_cuesheet_track_isrc_length(m_2: PMflacT; p1: PUint32T): TMFLACRESULT; cdecl;

function mflac_cuesheet_track_isrc_string(m_2: PMflacT; p1: PAnsiChar; p2: TUint32T; p3: PUint32T): TMFLACRESULT; cdecl;

function mflac_cuesheet_track_audio_flag(m_2: PMflacT; p1: PUint8T): TMFLACRESULT; cdecl;

function mflac_cuesheet_track_preemph_flag(m_2: PMflacT; p1: PUint8T): TMFLACRESULT; cdecl;

function mflac_cuesheet_track_indexpoints(m_2: PMflacT; p1: PUint8T): TMFLACRESULT; cdecl;

function mflac_cuesheet_index_point_offset(m_2: PMflacT; p1: PUint64T): TMFLACRESULT; cdecl;

function mflac_cuesheet_index_point_number(m_2: PMflacT; p1: PUint8T): TMFLACRESULT; cdecl;

function mflac_picture_type(m_2: PMflacT; p1: PUint32T): TMFLACRESULT; cdecl;

function mflac_picture_mime_length(m_2: PMflacT; p1: PUint32T): TMFLACRESULT; cdecl;

function mflac_picture_mime_string(m_2: PMflacT; p1: PAnsiChar; p2: TUint32T; p3: PUint32T): TMFLACRESULT; cdecl;

function mflac_picture_description_length(m_2: PMflacT; p1: PUint32T): TMFLACRESULT; cdecl;

function mflac_picture_description_string(m_2: PMflacT; p1: PAnsiChar; p2: TUint32T; p3: PUint32T): TMFLACRESULT; cdecl;

function mflac_picture_width(m_2: PMflacT; p1: PUint32T): TMFLACRESULT; cdecl;

function mflac_picture_height(m_2: PMflacT; p1: PUint32T): TMFLACRESULT; cdecl;

function mflac_picture_colordepth(m_2: PMflacT; p1: PUint32T): TMFLACRESULT; cdecl;

function mflac_picture_totalcolors(m_2: PMflacT; p1: PUint32T): TMFLACRESULT; cdecl;

function mflac_picture_length(m_2: PMflacT; p1: PUint32T): TMFLACRESULT; cdecl;

function mflac_picture_data(m_2: PMflacT; p1: PUint8T; p2: TUint32T; p3: PUint32T): TMFLACRESULT; cdecl;

function mflac_is_native(m_2: PMflacT): TUint8T; cdecl;

function mflac_is_ogg(m_2: PMflacT): TUint8T; cdecl;

function mflac_is_frame(m_2: PMflacT): TUint8T; cdecl;

function mflac_is_metadata(m_2: PMflacT): TUint8T; cdecl;

function mflac_metadata_is_last(m_2: PMflacT): TUint8T; cdecl;

function mflac_metadata_type(m_2: PMflacT): TMINIFLACMETADATATYPE; cdecl;

function mflac_metadata_length(m_2: PMflacT): TUint32T; cdecl;

function mflac_metadata_is_streaminfo(m_2: PMflacT): TUint8T; cdecl;

function mflac_metadata_is_padding(m_2: PMflacT): TUint8T; cdecl;

function mflac_metadata_is_application(m_2: PMflacT): TUint8T; cdecl;

function mflac_metadata_is_seektable(m_2: PMflacT): TUint8T; cdecl;

function mflac_metadata_is_vorbis_comment(m_2: PMflacT): TUint8T; cdecl;

function mflac_metadata_is_cuesheet(m_2: PMflacT): TUint8T; cdecl;

function mflac_metadata_is_picture(m_2: PMflacT): TUint8T; cdecl;

function mflac_frame_blocking_strategy(m_2: PMflacT): TUint8T; cdecl;

function mflac_frame_block_size(m_2: PMflacT): TUint16T; cdecl;

function mflac_frame_sample_rate(m_2: PMflacT): TUint32T; cdecl;

function mflac_frame_channels(m_2: PMflacT): TUint8T; cdecl;

function mflac_frame_bps(m_2: PMflacT): TUint8T; cdecl;

function mflac_frame_sample_number(m_2: PMflacT): TUint64T; cdecl;

function mflac_frame_frame_number(m_2: PMflacT): TUint32T; cdecl;

function mflac_frame_header_size(m_2: PMflacT): TUint32T; cdecl;

function mflac_ogg_serial(m_2: PMflacT): TInt32T; cdecl;

function mflac_bytes_read_flac(m_2: PMflacT): TUint64T; cdecl;

function mflac_bytes_read_ogg(m_2: PMflacT): TUint64T; cdecl;

function mflac_version_major(): LongWord; cdecl;

function mflac_version_minor(): LongWord; cdecl;

function mflac_version_patch(): LongWord; cdecl;

function mflac_version_string(): PAnsiChar; cdecl;

function miniflac_version_major(): LongWord; cdecl;

function miniflac_version_minor(): LongWord; cdecl;

function miniflac_version_patch(): LongWord; cdecl;

function miniflac_version_string(): PAnsiChar; cdecl;

function miniflac_size(): TSizeT; cdecl;

procedure miniflac_reset(pFlac: PMiniflacT; state: TMINIFLACSTATE); cdecl;

procedure miniflac_init(pFlac: PMiniflacT; container: TMINIFLACCONTAINER); cdecl;

function miniflac_decode(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; samples: PPInt32T): TMINIFLACRESULT; cdecl;

function miniflac_sync(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T): TMINIFLACRESULT; cdecl;

function miniflac_is_native(pFlac: PMiniflacT): TUint8T; cdecl;

function miniflac_is_ogg(pFlac: PMiniflacT): TUint8T; cdecl;

function miniflac_is_metadata(pFlac: PMiniflacT): TUint8T; cdecl;

function miniflac_is_frame(pFlac: PMiniflacT): TUint8T; cdecl;

function miniflac_metadata_is_last(pFlac: PMiniflacT): TUint8T; cdecl;

function miniflac_metadata_type(pFlac: PMiniflacT): TMINIFLACMETADATATYPE; cdecl;

function miniflac_metadata_length(pFlac: PMiniflacT): TUint32T; cdecl;

function miniflac_metadata_is_streaminfo(pFlac: PMiniflacT): TUint8T; cdecl;

function miniflac_metadata_is_padding(pFlac: PMiniflacT): TUint8T; cdecl;

function miniflac_metadata_is_application(pFlac: PMiniflacT): TUint8T; cdecl;

function miniflac_metadata_is_seektable(pFlac: PMiniflacT): TUint8T; cdecl;

function miniflac_metadata_is_vorbis_comment(pFlac: PMiniflacT): TUint8T; cdecl;

function miniflac_metadata_is_cuesheet(pFlac: PMiniflacT): TUint8T; cdecl;

function miniflac_metadata_is_picture(pFlac: PMiniflacT): TUint8T; cdecl;

function miniflac_frame_blocking_strategy(pFlac: PMiniflacT): TUint8T; cdecl;

function miniflac_frame_block_size(pFlac: PMiniflacT): TUint16T; cdecl;

function miniflac_frame_sample_rate(pFlac: PMiniflacT): TUint32T; cdecl;

function miniflac_frame_channels(pFlac: PMiniflacT): TUint8T; cdecl;

function miniflac_frame_bps(pFlac: PMiniflacT): TUint8T; cdecl;

function miniflac_frame_sample_number(pFlac: PMiniflacT): TUint64T; cdecl;

function miniflac_frame_frame_number(pFlac: PMiniflacT): TUint32T; cdecl;

function miniflac_frame_header_size(pFlac: PMiniflacT): TUint32T; cdecl;

function miniflac_ogg_serial(pFlac: PMiniflacT): TInt32T; cdecl;

function miniflac_bytes_read_flac(pFlac: PMiniflacT): TUint64T; cdecl;

function miniflac_bytes_read_ogg(pFlac: PMiniflacT): TUint64T; cdecl;

function miniflac_streaminfo_min_block_size(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint16T): TMINIFLACRESULT; cdecl;

function miniflac_streaminfo_max_block_size(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint16T): TMINIFLACRESULT; cdecl;

function miniflac_streaminfo_min_frame_size(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; cdecl;

function miniflac_streaminfo_max_frame_size(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; cdecl;

function miniflac_streaminfo_sample_rate(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; cdecl;

function miniflac_streaminfo_channels(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint8T): TMINIFLACRESULT; cdecl;

function miniflac_streaminfo_bps(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint8T): TMINIFLACRESULT; cdecl;

function miniflac_streaminfo_total_samples(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint64T): TMINIFLACRESULT; cdecl;

function miniflac_streaminfo_md5_length(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; cdecl;

function miniflac_streaminfo_md5_data(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; output: PUint8T; buffer_length: TUint32T; outlen: PUint32T): TMINIFLACRESULT; cdecl;

function miniflac_vorbis_comment_vendor_length(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; cdecl;

function miniflac_vorbis_comment_vendor_string(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; output: PAnsiChar; buffer_length: TUint32T; outlen: PUint32T): TMINIFLACRESULT; cdecl;

function miniflac_vorbis_comment_total(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; cdecl;

function miniflac_vorbis_comment_length(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; cdecl;

function miniflac_vorbis_comment_string(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; output: PAnsiChar; buffer_length: TUint32T; outlen: PUint32T): TMINIFLACRESULT; cdecl;

function miniflac_picture_type(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; cdecl;

function miniflac_picture_mime_length(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; cdecl;

function miniflac_picture_mime_string(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; output: PAnsiChar; buffer_length: TUint32T; outlen: PUint32T): TMINIFLACRESULT; cdecl;

function miniflac_picture_description_length(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; cdecl;

function miniflac_picture_description_string(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; output: PAnsiChar; buffer_length: TUint32T; outlen: PUint32T): TMINIFLACRESULT; cdecl;

function miniflac_picture_width(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; cdecl;

function miniflac_picture_height(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; cdecl;

function miniflac_picture_colordepth(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; cdecl;

function miniflac_picture_totalcolors(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; cdecl;

function miniflac_picture_length(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; cdecl;

function miniflac_picture_data(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; output: PUint8T; buffer_length: TUint32T; outlen: PUint32T): TMINIFLACRESULT; cdecl;

function miniflac_cuesheet_catalog_length(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; cdecl;

function miniflac_cuesheet_catalog_string(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; output: PAnsiChar; buffer_length: TUint32T; outlen: PUint32T): TMINIFLACRESULT; cdecl;

function miniflac_cuesheet_leadin(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint64T): TMINIFLACRESULT; cdecl;

function miniflac_cuesheet_cd_flag(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint8T): TMINIFLACRESULT; cdecl;

function miniflac_cuesheet_tracks(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint8T): TMINIFLACRESULT; cdecl;

function miniflac_cuesheet_track_offset(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint64T): TMINIFLACRESULT; cdecl;

function miniflac_cuesheet_track_number(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint8T): TMINIFLACRESULT; cdecl;

function miniflac_cuesheet_track_isrc_length(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; cdecl;

function miniflac_cuesheet_track_isrc_string(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; output: PAnsiChar; buffer_length: TUint32T; outlen: PUint32T): TMINIFLACRESULT; cdecl;

function miniflac_cuesheet_track_audio_flag(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint8T): TMINIFLACRESULT; cdecl;

function miniflac_cuesheet_track_preemph_flag(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint8T): TMINIFLACRESULT; cdecl;

function miniflac_cuesheet_track_indexpoints(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint8T): TMINIFLACRESULT; cdecl;

function miniflac_cuesheet_index_point_offset(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint64T): TMINIFLACRESULT; cdecl;

function miniflac_cuesheet_index_point_number(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint8T): TMINIFLACRESULT; cdecl;

function miniflac_seektable_seekpoints(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; cdecl;

function miniflac_seektable_sample_number(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint64T): TMINIFLACRESULT; cdecl;

function miniflac_seektable_sample_offset(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint64T): TMINIFLACRESULT; cdecl;

function miniflac_seektable_samples(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint16T): TMINIFLACRESULT; cdecl;

function miniflac_application_id(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; cdecl;

function miniflac_application_length(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; cdecl;

function miniflac_application_data(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; output: PUint8T; buffer_length: TUint32T; outlen: PUint32T): TMINIFLACRESULT; cdecl;

function miniflac_padding_length(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; cdecl;

function miniflac_padding_data(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; output: PUint8T; buffer_length: TUint32T; outlen: PUint32T): TMINIFLACRESULT; cdecl;

{ 算术右移（C 有符号 >>，floor 语义）：bps 缩放等场景复用 }
function FlacSar32(Value: LongInt; Count: LongWord): LongInt; inline;
function FlacSar64(Value: Int64; Count: LongWord): Int64; inline;

{$ifdef cpuaarch64}
{ ppcrossa64 3.3.1 快照在 -O2 下有寄存器分配错译（常量表基址寄存器被循环体
  复用，产出静默错误数据），本单元在 aarch64 上回退保守优化；
  x86-64 与其余架构不受影响 }
{$optimization off}
{$endif}
{$ifdef FLAC_NO_SIMD}
{$else}
{$if defined(cpuaarch64)}
{$define FLAC_SIMD_ON}
{$ifend}
{$endif}

implementation

{$ifdef FLAC_SIMD_ON}
uses nextpas.core.audio.codec.flac.sse;
{$endif}

function cflac_Sar32(Value: LongInt; Count: LongWord): LongInt; cdecl;
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

function cflac_Sar64(Value: Int64; Count: LongWord): Int64; cdecl;
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

function FlacSar32(Value: LongInt; Count: LongWord): LongInt; inline;
begin
  Result := cflac_Sar32(Value, Count);
end;

function FlacSar64(Value: Int64; Count: LongWord): Int64; inline;
begin
  Result := cflac_Sar64(Value, Count);
end;

type
  T__c2p_case_overlay_1 = record
    c_2: AnsiChar;
    __c2p_tmp2: LongWord;
  end;

var
  miniflac_crc8_table: array[0..255] of TUint8T = (0, 7, 14, 9, 28, 27, 18, 21, 56, 63, 54, 49, 36, 35, 42, 45, 112, 119, 126, 121, 108, 107, 98, 101, 72, 79, 70, 65, 84, 83, 90, 93, 224, 231, 238, 233, 252, 251, 242, 245, 216, 223, 214, 209, 196, 195, 202, 205, 144, 151, 158, 153, 140, 139, 130, 133, 168, 175, 166, 161, 180, 179, 186, 189, 199, 192, 201, 206, 219, 220, 213, 210, 255, 248, 241, 246, 227, 228, 237, 234, 183, 176, 185, 190, 171, 172, 165, 162, 143, 136, 129, 134, 147, 148, 157, 154, 39, 32, 41, 46, 59, 60, 53, 50, 31, 24, 17, 22, 3, 4, 13, 10, 87, 80, 89, 94, 75, 76, 69, 66, 111, 104, 97, 102, 115, 116, 125, 122, 137, 142, 135, 128, 149, 146, 155, 156, 177, 182, 191, 184, 173, 170, 163, 164, 249, 254, 247, 240, 229, 226, 235, 236, 193, 198, 207, 200, 221, 218, 211, 212, 105, 110, 103, 96, 117, 114, 123, 124, 81, 86, 95, 88, 77, 74, 67, 68, 25, 30, 23, 16, 5, 2, 11, 12, 33, 38, 47, 40, 61, 58, 51, 52, 78, 73, 64, 71, 82, 85, 92, 91, 118, 113, 120, 127, 106, 109, 100, 99, 62, 57, 48, 55, 34, 37, 44, 43, 6, 1, 8, 15, 26, 29, 20, 19, 174, 169, 160, 167, 178, 181, 188, 187, 150, 145, 152, 159, 138, 141, 132, 131, 222, 217, 208, 215, 194, 197, 204, 203, 230, 225, 232, 239, 250, 253, 244, 243);
  miniflac_crc16_table: array[0..255] of TUint16T = (0, 32773, 32783, 10, 32795, 30, 20, 32785, 32819, 54, 60, 32825, 40, 32813, 32807, 34, 32867, 102, 108, 32873, 120, 32893, 32887, 114, 80, 32853, 32863, 90, 32843, 78, 68, 32833, 32963, 198, 204, 32969, 216, 32989, 32983, 210, 240, 33013, 33023, 250, 33003, 238, 228, 32993, 160, 32933, 32943, 170, 32955, 190, 180, 32945, 32915, 150, 156, 32921, 136, 32909, 32903, 130, 33155, 390, 396, 33161, 408, 33181, 33175, 402, 432, 33205, 33215, 442, 33195, 430, 420, 33185, 480, 33253, 33263, 490, 33275, 510, 500, 33265, 33235, 470, 476, 33241, 456, 33229, 33223, 450, 320, 33093, 33103, 330, 33115, 350, 340, 33105, 33139, 374, 380, 33145, 360, 33133, 33127, 354, 33059, 294, 300, 33065, 312, 33085, 33079, 306, 272, 33045, 33055, 282, 33035, 270, 260, 33025, 33539, 774, 780, 33545, 792, 33565, 33559, 786, 816, 33589, 33599, 826, 33579, 814, 804, 33569, 864, 33637, 33647, 874, 33659, 894, 884, 33649, 33619, 854, 860, 33625, 840, 33613, 33607, 834, 960, 33733, 33743, 970, 33755, 990, 980, 33745, 33779, 1014, 1020, 33785, 1000, 33773, 33767, 994, 33699, 934, 940, 33705, 952, 33725, 33719, 946, 912, 33685, 33695, 922, 33675, 910, 900, 33665, 640, 33413, 33423, 650, 33435, 670, 660, 33425, 33459, 694, 700, 33465, 680, 33453, 33447, 674, 33507, 742, 748, 33513, 760, 33533, 33527, 754, 720, 33493, 33503, 730, 33483, 718, 708, 33473, 33347, 582, 588, 33353, 600, 33373, 33367, 594, 624, 33397, 33407, 634, 33387, 622, 612, 33377, 544, 33317, 33327, 554, 33339, 574, 564, 33329, 33299, 534, 540, 33305, 520, 33293, 33287, 514);
  escape_codes: array[0..1] of TUint8T = (15, 31);

function miniflac_unpack_uint32le(buffer: PUint8T): TUint32T; forward;

function miniflac_unpack_int32le(buffer: PUint8T): TInt32T; forward;

function miniflac_unpack_uint64le(buffer: PUint8T): TUint64T; forward;

function miniflac_unpack_int64le(buffer: PUint8T): TInt64T; forward;

procedure miniflac_bitreader_init(br: PMiniflacBitreaderT); forward;

function miniflac_bitreader_fill(br: PMiniflacBitreaderT; bits_2: TUint8T): LongInt; forward;

function miniflac_bitreader_fill_nocrc(br: PMiniflacBitreaderT; bits_2: TUint8T): LongInt; forward;

function miniflac_bitreader_read(br: PMiniflacBitreaderT; bits_2: TUint8T): TUint64T; forward;

function miniflac_bitreader_read_signed(br: PMiniflacBitreaderT; bits_2: TUint8T): TInt64T; forward;

function miniflac_bitreader_peek(br: PMiniflacBitreaderT; bits_2: TUint8T): TUint64T; forward;

procedure miniflac_bitreader_discard(br: PMiniflacBitreaderT; bits_2: TUint8T); forward;

procedure miniflac_bitreader_align(br: PMiniflacBitreaderT); forward;

procedure miniflac_bitreader_reset_crc(br: PMiniflacBitreaderT); forward;

procedure miniflac_oggheader_init(oggheader: PMiniflacOggheaderT); forward;

function miniflac_oggheader_decode(oggheader: PMiniflacOggheaderT; br: PMiniflacBitreaderT): TMINIFLACRESULT; forward;

procedure miniflac_ogg_init(ogg: PMiniflacOggT); forward;

function miniflac_ogg_sync(ogg: PMiniflacOggT; br: PMiniflacBitreaderT): TMINIFLACRESULT; forward;

procedure miniflac_streammarker_init(streammarker: PMiniflacStreammarkerT); forward;

function miniflac_streammarker_decode(streammarker: PMiniflacStreammarkerT; br: PMiniflacBitreaderT): TMINIFLACRESULT; forward;

procedure miniflac_metadata_header_init(header: PMiniflacMetadataHeaderT); forward;

function miniflac_metadata_header_decode(header: PMiniflacMetadataHeaderT; br: PMiniflacBitreaderT): TMINIFLACRESULT; forward;

procedure miniflac_streaminfo_init(streaminfo: PMiniflacStreaminfoT); forward;

function miniflac_streaminfo_read_min_block_size(streaminfo: PMiniflacStreaminfoT; br: PMiniflacBitreaderT; min_block_size: PUint16T): TMINIFLACRESULT; forward;

function miniflac_streaminfo_read_max_block_size(streaminfo: PMiniflacStreaminfoT; br: PMiniflacBitreaderT; max_block_size: PUint16T): TMINIFLACRESULT; forward;

function miniflac_streaminfo_read_min_frame_size(streaminfo: PMiniflacStreaminfoT; br: PMiniflacBitreaderT; min_frame_size: PUint32T): TMINIFLACRESULT; forward;

function miniflac_streaminfo_read_max_frame_size(streaminfo: PMiniflacStreaminfoT; br: PMiniflacBitreaderT; max_frame_size: PUint32T): TMINIFLACRESULT; forward;

function miniflac_streaminfo_read_sample_rate(streaminfo: PMiniflacStreaminfoT; br: PMiniflacBitreaderT; sample_rate: PUint32T): TMINIFLACRESULT; forward;

function miniflac_streaminfo_read_channels(streaminfo: PMiniflacStreaminfoT; br: PMiniflacBitreaderT; channels: PUint8T): TMINIFLACRESULT; forward;

function miniflac_streaminfo_read_bps(streaminfo: PMiniflacStreaminfoT; br: PMiniflacBitreaderT; bps_2: PUint8T): TMINIFLACRESULT; forward;

function miniflac_streaminfo_read_total_samples(streaminfo: PMiniflacStreaminfoT; br: PMiniflacBitreaderT; total_samples: PUint64T): TMINIFLACRESULT; forward;

function miniflac_streaminfo_read_md5_length(streaminfo: PMiniflacStreaminfoT; br: PMiniflacBitreaderT; md5_len: PUint32T): TMINIFLACRESULT; forward;

function miniflac_streaminfo_read_md5_data(streaminfo: PMiniflacStreaminfoT; br: PMiniflacBitreaderT; output: PUint8T; length: TUint32T; outlen: PUint32T): TMINIFLACRESULT; forward;

procedure miniflac_vorbis_comment_init(vorbis_comment: PMiniflacVorbisCommentT); forward;

function miniflac_vorbis_comment_read_vendor_length(vorbis_comment: PMiniflacVorbisCommentT; br: PMiniflacBitreaderT; length: PUint32T): TMINIFLACRESULT; forward;

function miniflac_vorbis_comment_read_vendor_string(vorbis_comment: PMiniflacVorbisCommentT; br: PMiniflacBitreaderT; output: PAnsiChar; length: TUint32T; outlen: PUint32T): TMINIFLACRESULT; forward;

function miniflac_vorbis_comment_read_total(vorbis_comment: PMiniflacVorbisCommentT; br: PMiniflacBitreaderT; total: PUint32T): TMINIFLACRESULT; forward;

function miniflac_vorbis_comment_read_length(vorbis_comment: PMiniflacVorbisCommentT; br: PMiniflacBitreaderT; length: PUint32T): TMINIFLACRESULT; forward;

function miniflac_vorbis_comment_read_string(vorbis_comment: PMiniflacVorbisCommentT; br: PMiniflacBitreaderT; output: PAnsiChar; length: TUint32T; outlen: PUint32T): TMINIFLACRESULT; forward;

procedure miniflac_picture_init(picture: PMiniflacPictureT); forward;

function miniflac_picture_read_type(picture: PMiniflacPictureT; br: PMiniflacBitreaderT; &type: PUint32T): TMINIFLACRESULT; forward;

function miniflac_picture_read_mime_length(picture: PMiniflacPictureT; br: PMiniflacBitreaderT; length: PUint32T): TMINIFLACRESULT; forward;

function miniflac_picture_read_mime_string(picture: PMiniflacPictureT; br: PMiniflacBitreaderT; output: PAnsiChar; length: TUint32T; outlen: PUint32T): TMINIFLACRESULT; forward;

function miniflac_picture_read_description_length(picture: PMiniflacPictureT; br: PMiniflacBitreaderT; length: PUint32T): TMINIFLACRESULT; forward;

function miniflac_picture_read_description_string(picture: PMiniflacPictureT; br: PMiniflacBitreaderT; output: PAnsiChar; length: TUint32T; outlen: PUint32T): TMINIFLACRESULT; forward;

function miniflac_picture_read_width(picture: PMiniflacPictureT; br: PMiniflacBitreaderT; width: PUint32T): TMINIFLACRESULT; forward;

function miniflac_picture_read_height(picture: PMiniflacPictureT; br: PMiniflacBitreaderT; height: PUint32T): TMINIFLACRESULT; forward;

function miniflac_picture_read_colordepth(picture: PMiniflacPictureT; br: PMiniflacBitreaderT; colordepth: PUint32T): TMINIFLACRESULT; forward;

function miniflac_picture_read_totalcolors(picture: PMiniflacPictureT; br: PMiniflacBitreaderT; totalcolors: PUint32T): TMINIFLACRESULT; forward;

function miniflac_picture_read_length(picture: PMiniflacPictureT; br: PMiniflacBitreaderT; length: PUint32T): TMINIFLACRESULT; forward;

function miniflac_picture_read_data(picture: PMiniflacPictureT; br: PMiniflacBitreaderT; output: PUint8T; length: TUint32T; outlen: PUint32T): TMINIFLACRESULT; forward;

procedure miniflac_cuesheet_init(cuesheet: PMiniflacCuesheetT); forward;

function miniflac_cuesheet_read_catalog_length(cuesheet: PMiniflacCuesheetT; br: PMiniflacBitreaderT; catalog_length: PUint32T): TMINIFLACRESULT; forward;

function miniflac_cuesheet_read_catalog_string(cuesheet: PMiniflacCuesheetT; br: PMiniflacBitreaderT; output: PAnsiChar; length: TUint32T; outlen: PUint32T): TMINIFLACRESULT; forward;

function miniflac_cuesheet_read_leadin(cuesheet: PMiniflacCuesheetT; br: PMiniflacBitreaderT; leadin: PUint64T): TMINIFLACRESULT; forward;

function miniflac_cuesheet_read_cd_flag(cuesheet: PMiniflacCuesheetT; br: PMiniflacBitreaderT; flag: PUint8T): TMINIFLACRESULT; forward;

function miniflac_cuesheet_read_tracks(cuesheet: PMiniflacCuesheetT; br: PMiniflacBitreaderT; tracks: PUint8T): TMINIFLACRESULT; forward;

function miniflac_cuesheet_read_track_offset(cuesheet: PMiniflacCuesheetT; br: PMiniflacBitreaderT; track_offset: PUint64T): TMINIFLACRESULT; forward;

function miniflac_cuesheet_read_track_number(cuesheet: PMiniflacCuesheetT; br: PMiniflacBitreaderT; track_number: PUint8T): TMINIFLACRESULT; forward;

function miniflac_cuesheet_read_track_isrc_length(cuesheet: PMiniflacCuesheetT; br: PMiniflacBitreaderT; isrc_length: PUint32T): TMINIFLACRESULT; forward;

function miniflac_cuesheet_read_track_isrc_string(cuesheet: PMiniflacCuesheetT; br: PMiniflacBitreaderT; output: PAnsiChar; length: TUint32T; outlen: PUint32T): TMINIFLACRESULT; forward;

function miniflac_cuesheet_read_track_audio_flag(cuesheet: PMiniflacCuesheetT; br: PMiniflacBitreaderT; track_audio_flag: PUint8T): TMINIFLACRESULT; forward;

function miniflac_cuesheet_read_track_preemph_flag(cuesheet: PMiniflacCuesheetT; br: PMiniflacBitreaderT; track_preemph_flag: PUint8T): TMINIFLACRESULT; forward;

function miniflac_cuesheet_read_track_indexpoints(cuesheet: PMiniflacCuesheetT; br: PMiniflacBitreaderT; track_indexpoints: PUint8T): TMINIFLACRESULT; forward;

function miniflac_cuesheet_read_index_point_offset(cuesheet: PMiniflacCuesheetT; br: PMiniflacBitreaderT; index_point_offset: PUint64T): TMINIFLACRESULT; forward;

function miniflac_cuesheet_read_index_point_number(cuesheet: PMiniflacCuesheetT; br: PMiniflacBitreaderT; index_point_number: PUint8T): TMINIFLACRESULT; forward;

procedure miniflac_seektable_init(seektable: PMiniflacSeektableT); forward;

function miniflac_seektable_read_seekpoints(seektable: PMiniflacSeektableT; br: PMiniflacBitreaderT; seekpoints: PUint32T): TMINIFLACRESULT; forward;

function miniflac_seektable_read_sample_number(seektable: PMiniflacSeektableT; br: PMiniflacBitreaderT; sample_number: PUint64T): TMINIFLACRESULT; forward;

function miniflac_seektable_read_sample_offset(seektable: PMiniflacSeektableT; br: PMiniflacBitreaderT; sample_offset: PUint64T): TMINIFLACRESULT; forward;

function miniflac_seektable_read_samples(seektable: PMiniflacSeektableT; br: PMiniflacBitreaderT; samples: PUint16T): TMINIFLACRESULT; forward;

procedure miniflac_application_init(application: PMiniflacApplicationT); forward;

function miniflac_application_read_id(application: PMiniflacApplicationT; br: PMiniflacBitreaderT; id: PUint32T): TMINIFLACRESULT; forward;

function miniflac_application_read_length(application: PMiniflacApplicationT; br: PMiniflacBitreaderT; length: PUint32T): TMINIFLACRESULT; forward;

function miniflac_application_read_data(application: PMiniflacApplicationT; br: PMiniflacBitreaderT; output: PUint8T; length: TUint32T; outlen: PUint32T): TMINIFLACRESULT; forward;

procedure miniflac_padding_init(padding: PMiniflacPaddingT); forward;

function miniflac_padding_read_length(padding: PMiniflacPaddingT; br: PMiniflacBitreaderT; length: PUint32T): TMINIFLACRESULT; forward;

function miniflac_padding_read_data(padding: PMiniflacPaddingT; br: PMiniflacBitreaderT; output: PUint8T; length: TUint32T; outlen: PUint32T): TMINIFLACRESULT; forward;

procedure miniflac_metadata_init(metadata: PMiniflacMetadataT); forward;

function miniflac_metadata_sync(metadata: PMiniflacMetadataT; br: PMiniflacBitreaderT): TMINIFLACRESULT; forward;

function miniflac_metadata_decode(metadata: PMiniflacMetadataT; br: PMiniflacBitreaderT): TMINIFLACRESULT; forward;

procedure miniflac_residual_init(residual: PMiniflacResidualT); forward;

function miniflac_residual_decode(residual: PMiniflacResidualT; br: PMiniflacBitreaderT; pos: PUint32T; block_size: TUint32T; predictor_order: TUint8T; output: PInt32T): TMINIFLACRESULT; forward;

procedure miniflac_subframe_fixed_init(f_2: PMiniflacSubframeFixedT); forward;

function miniflac_subframe_fixed_decode(f_2: PMiniflacSubframeFixedT; br: PMiniflacBitreaderT; output: PInt32T; block_size: TUint32T; bps_2: TUint8T; residual: PMiniflacResidualT; predictor_order: TUint8T): TMINIFLACRESULT; forward;

procedure miniflac_subframe_lpc_init(l: PMiniflacSubframeLpcT); forward;

function miniflac_subframe_lpc_decode(l: PMiniflacSubframeLpcT; br: PMiniflacBitreaderT; output: PInt32T; block_size: TUint32T; bps_2: TUint8T; residual: PMiniflacResidualT; predictor_order: TUint8T): TMINIFLACRESULT; forward;

procedure miniflac_subframe_constant_init(c_2: PMiniflacSubframeConstantT); forward;

function miniflac_subframe_constant_decode(c_2: PMiniflacSubframeConstantT; br: PMiniflacBitreaderT; output: PInt32T; block_size: TUint32T; bps_2: TUint8T): TMINIFLACRESULT; forward;

procedure miniflac_subframe_verbatim_init(c_2: PMiniflacSubframeVerbatimT); forward;

function miniflac_subframe_verbatim_decode(c_2: PMiniflacSubframeVerbatimT; br: PMiniflacBitreaderT; output: PInt32T; block_size: TUint32T; bps_2: TUint8T): TMINIFLACRESULT; forward;

procedure miniflac_subframe_header_init(subframeheader: PMiniflacSubframeHeaderT); forward;

function miniflac_subframe_header_decode(subframeheader: PMiniflacSubframeHeaderT; br: PMiniflacBitreaderT): TMINIFLACRESULT; forward;

procedure miniflac_subframe_init(subframe: PMiniflacSubframeT); forward;

function miniflac_subframe_decode(subframe: PMiniflacSubframeT; br: PMiniflacBitreaderT; output: PInt32T; block_size: TUint32T; bps_2: TUint8T): TMINIFLACRESULT; forward;

procedure miniflac_frame_header_init(header: PMiniflacFrameHeaderT); forward;

function miniflac_frame_header_decode(header: PMiniflacFrameHeaderT; br: PMiniflacBitreaderT): TMINIFLACRESULT; forward;

procedure miniflac_frame_init(frame: PMiniflacFrameT); forward;

function miniflac_frame_sync(frame: PMiniflacFrameT; br: PMiniflacBitreaderT; info: PMiniflacStreaminfoT): TMINIFLACRESULT; forward;

function miniflac_frame_decode(frame: PMiniflacFrameT; br: PMiniflacBitreaderT; info: PMiniflacStreaminfoT; output: PPInt32T): TMINIFLACRESULT; forward;

function mflac_size(): TSizeT; cdecl; public name 'mflac_size'; inline;
begin
  Result := 16976;
end;

procedure mflac_init(m_2: PMflacT; container: TMINIFLACCONTAINER; read: TMflacReadcb; userdata: Pointer); cdecl; public name 'mflac_init'; inline;
begin
  miniflac_init(@m_2^.flac, TMINIFLACCONTAINER(container));
  m_2^.read := TMflacReadcb(read);
  m_2^.userdata := userdata;
  m_2^.bufpos := TSizeT(0);
  m_2^.buflen := TSizeT(0);
end;

procedure mflac_reset(m_2: PMflacT; state: TMINIFLACSTATE); cdecl; public name 'mflac_reset'; inline;
begin
  miniflac_reset(@m_2^.flac, TMINIFLACSTATE(state));
  m_2^.bufpos := TSizeT(0);
  m_2^.buflen := TSizeT(0);
end;

function mflac_sync(m_2: PMflacT): TMFLACRESULT; cdecl; public name 'mflac_sync'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_sync(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_decode(m_2: PMflacT; p1: PPInt32T): TMFLACRESULT; cdecl; public name 'mflac_decode'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_decode(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_streaminfo_min_block_size(m_2: PMflacT; p1: PUint16T): TMFLACRESULT; cdecl; public name 'mflac_streaminfo_min_block_size'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_streaminfo_min_block_size(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_streaminfo_max_block_size(m_2: PMflacT; p1: PUint16T): TMFLACRESULT; cdecl; public name 'mflac_streaminfo_max_block_size'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_streaminfo_max_block_size(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_streaminfo_min_frame_size(m_2: PMflacT; p1: PUint32T): TMFLACRESULT; cdecl; public name 'mflac_streaminfo_min_frame_size'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_streaminfo_min_frame_size(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_streaminfo_max_frame_size(m_2: PMflacT; p1: PUint32T): TMFLACRESULT; cdecl; public name 'mflac_streaminfo_max_frame_size'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_streaminfo_max_frame_size(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_streaminfo_sample_rate(m_2: PMflacT; p1: PUint32T): TMFLACRESULT; cdecl; public name 'mflac_streaminfo_sample_rate'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_streaminfo_sample_rate(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_streaminfo_channels(m_2: PMflacT; p1: PUint8T): TMFLACRESULT; cdecl; public name 'mflac_streaminfo_channels'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_streaminfo_channels(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_streaminfo_bps(m_2: PMflacT; p1: PUint8T): TMFLACRESULT; cdecl; public name 'mflac_streaminfo_bps'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_streaminfo_bps(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_streaminfo_total_samples(m_2: PMflacT; p1: PUint64T): TMFLACRESULT; cdecl; public name 'mflac_streaminfo_total_samples'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_streaminfo_total_samples(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_streaminfo_md5_length(m_2: PMflacT; p1: PUint32T): TMFLACRESULT; cdecl; public name 'mflac_streaminfo_md5_length'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_streaminfo_md5_length(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_streaminfo_md5_data(m_2: PMflacT; p1: PUint8T; p2: TUint32T; p3: PUint32T): TMFLACRESULT; cdecl; public name 'mflac_streaminfo_md5_data'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_streaminfo_md5_data(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1, TUint32T(p2), p3));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_vorbis_comment_vendor_length(m_2: PMflacT; p1: PUint32T): TMFLACRESULT; cdecl; public name 'mflac_vorbis_comment_vendor_length'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_vorbis_comment_vendor_length(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_vorbis_comment_vendor_string(m_2: PMflacT; p1: PAnsiChar; p2: TUint32T; p3: PUint32T): TMFLACRESULT; cdecl; public name 'mflac_vorbis_comment_vendor_string'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_vorbis_comment_vendor_string(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1, TUint32T(p2), p3));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_vorbis_comment_total(m_2: PMflacT; p1: PUint32T): TMFLACRESULT; cdecl; public name 'mflac_vorbis_comment_total'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_vorbis_comment_total(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_vorbis_comment_length(m_2: PMflacT; p1: PUint32T): TMFLACRESULT; cdecl; public name 'mflac_vorbis_comment_length'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_vorbis_comment_length(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_vorbis_comment_string(m_2: PMflacT; p1: PAnsiChar; p2: TUint32T; p3: PUint32T): TMFLACRESULT; cdecl; public name 'mflac_vorbis_comment_string'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_vorbis_comment_string(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1, TUint32T(p2), p3));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_padding_length(m_2: PMflacT; p1: PUint32T): TMFLACRESULT; cdecl; public name 'mflac_padding_length'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_padding_length(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_padding_data(m_2: PMflacT; p1: PUint8T; p2: TUint32T; p3: PUint32T): TMFLACRESULT; cdecl; public name 'mflac_padding_data'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_padding_data(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1, TUint32T(p2), p3));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_application_id(m_2: PMflacT; p1: PUint32T): TMFLACRESULT; cdecl; public name 'mflac_application_id'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_application_id(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_application_length(m_2: PMflacT; p1: PUint32T): TMFLACRESULT; cdecl; public name 'mflac_application_length'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_application_length(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_application_data(m_2: PMflacT; p1: PUint8T; p2: TUint32T; p3: PUint32T): TMFLACRESULT; cdecl; public name 'mflac_application_data'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_application_data(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1, TUint32T(p2), p3));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_seektable_seekpoints(m_2: PMflacT; p1: PUint32T): TMFLACRESULT; cdecl; public name 'mflac_seektable_seekpoints'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_seektable_seekpoints(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_seektable_sample_number(m_2: PMflacT; p1: PUint64T): TMFLACRESULT; cdecl; public name 'mflac_seektable_sample_number'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_seektable_sample_number(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_seektable_sample_offset(m_2: PMflacT; p1: PUint64T): TMFLACRESULT; cdecl; public name 'mflac_seektable_sample_offset'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_seektable_sample_offset(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_seektable_samples(m_2: PMflacT; p1: PUint16T): TMFLACRESULT; cdecl; public name 'mflac_seektable_samples'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_seektable_samples(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_cuesheet_catalog_length(m_2: PMflacT; p1: PUint32T): TMFLACRESULT; cdecl; public name 'mflac_cuesheet_catalog_length'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_cuesheet_catalog_length(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_cuesheet_catalog_string(m_2: PMflacT; p1: PAnsiChar; p2: TUint32T; p3: PUint32T): TMFLACRESULT; cdecl; public name 'mflac_cuesheet_catalog_string'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_cuesheet_catalog_string(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1, TUint32T(p2), p3));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_cuesheet_leadin(m_2: PMflacT; p1: PUint64T): TMFLACRESULT; cdecl; public name 'mflac_cuesheet_leadin'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_cuesheet_leadin(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_cuesheet_cd_flag(m_2: PMflacT; p1: PUint8T): TMFLACRESULT; cdecl; public name 'mflac_cuesheet_cd_flag'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_cuesheet_cd_flag(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_cuesheet_tracks(m_2: PMflacT; p1: PUint8T): TMFLACRESULT; cdecl; public name 'mflac_cuesheet_tracks'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_cuesheet_tracks(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_cuesheet_track_offset(m_2: PMflacT; p1: PUint64T): TMFLACRESULT; cdecl; public name 'mflac_cuesheet_track_offset'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_cuesheet_track_offset(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_cuesheet_track_number(m_2: PMflacT; p1: PUint8T): TMFLACRESULT; cdecl; public name 'mflac_cuesheet_track_number'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_cuesheet_track_number(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_cuesheet_track_isrc_length(m_2: PMflacT; p1: PUint32T): TMFLACRESULT; cdecl; public name 'mflac_cuesheet_track_isrc_length'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_cuesheet_track_isrc_length(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_cuesheet_track_isrc_string(m_2: PMflacT; p1: PAnsiChar; p2: TUint32T; p3: PUint32T): TMFLACRESULT; cdecl; public name 'mflac_cuesheet_track_isrc_string'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_cuesheet_track_isrc_string(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1, TUint32T(p2), p3));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_cuesheet_track_audio_flag(m_2: PMflacT; p1: PUint8T): TMFLACRESULT; cdecl; public name 'mflac_cuesheet_track_audio_flag'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_cuesheet_track_audio_flag(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_cuesheet_track_preemph_flag(m_2: PMflacT; p1: PUint8T): TMFLACRESULT; cdecl; public name 'mflac_cuesheet_track_preemph_flag'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_cuesheet_track_preemph_flag(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_cuesheet_track_indexpoints(m_2: PMflacT; p1: PUint8T): TMFLACRESULT; cdecl; public name 'mflac_cuesheet_track_indexpoints'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_cuesheet_track_indexpoints(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_cuesheet_index_point_offset(m_2: PMflacT; p1: PUint64T): TMFLACRESULT; cdecl; public name 'mflac_cuesheet_index_point_offset'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_cuesheet_index_point_offset(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_cuesheet_index_point_number(m_2: PMflacT; p1: PUint8T): TMFLACRESULT; cdecl; public name 'mflac_cuesheet_index_point_number'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_cuesheet_index_point_number(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_picture_type(m_2: PMflacT; p1: PUint32T): TMFLACRESULT; cdecl; public name 'mflac_picture_type'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_picture_type(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_picture_mime_length(m_2: PMflacT; p1: PUint32T): TMFLACRESULT; cdecl; public name 'mflac_picture_mime_length'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_picture_mime_length(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_picture_mime_string(m_2: PMflacT; p1: PAnsiChar; p2: TUint32T; p3: PUint32T): TMFLACRESULT; cdecl; public name 'mflac_picture_mime_string'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_picture_mime_string(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1, TUint32T(p2), p3));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_picture_description_length(m_2: PMflacT; p1: PUint32T): TMFLACRESULT; cdecl; public name 'mflac_picture_description_length'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_picture_description_length(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_picture_description_string(m_2: PMflacT; p1: PAnsiChar; p2: TUint32T; p3: PUint32T): TMFLACRESULT; cdecl; public name 'mflac_picture_description_string'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_picture_description_string(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1, TUint32T(p2), p3));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_picture_width(m_2: PMflacT; p1: PUint32T): TMFLACRESULT; cdecl; public name 'mflac_picture_width'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_picture_width(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_picture_height(m_2: PMflacT; p1: PUint32T): TMFLACRESULT; cdecl; public name 'mflac_picture_height'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_picture_height(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_picture_colordepth(m_2: PMflacT; p1: PUint32T): TMFLACRESULT; cdecl; public name 'mflac_picture_colordepth'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_picture_colordepth(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_picture_totalcolors(m_2: PMflacT; p1: PUint32T): TMFLACRESULT; cdecl; public name 'mflac_picture_totalcolors'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_picture_totalcolors(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_picture_length(m_2: PMflacT; p1: PUint32T): TMFLACRESULT; cdecl; public name 'mflac_picture_length'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_picture_length(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_picture_data(m_2: PMflacT; p1: PUint8T; p2: TUint32T; p3: PUint32T): TMFLACRESULT; cdecl; public name 'mflac_picture_data'; inline;
var
  res_2: TMINIFLACRESULT;
  used_2: TUint32T;
  received_2: TSizeT;
  __c2p_tmp1: TMINIFLACRESULT;
  __c2p_tmp2: TMflacReadcb;
begin
  res_2 := TMINIFLACRESULT(MINIFLAC_OK);
  used_2 := TUint32T(0);
  received_2 := TSizeT(0);
  while True do
  begin
    __c2p_tmp1 := TMINIFLACRESULT(miniflac_picture_data(@m_2^.flac, @m_2^.buffer[m_2^.bufpos], TUint32T(m_2^.buflen), @used_2, p1, TUint32T(p2), p3));
    res_2 := __c2p_tmp1;
    if (LongInt(__c2p_tmp1) <> MINIFLAC_CONTINUE) then
    begin
      Break;
    end;
    __c2p_tmp2 := m_2^.read;
    received_2 := __c2p_tmp2(PUint8T(@m_2^.buffer[0]), TSizeT(16384), m_2^.userdata);
    if (received_2 = QWord(0)) then
    begin
      Result := MFLAC_EOF;
      System.Exit;
    end;
    m_2^.buflen := received_2;
    m_2^.bufpos := TSizeT(0);
  end;
  if (LongInt(res_2) < MINIFLAC_OK) then
  begin
    Result := TMFLACRESULT(res_2);
    System.Exit;
  end;
  m_2^.bufpos := (m_2^.bufpos + QWord(used_2));
  m_2^.buflen := (m_2^.buflen - QWord(used_2));
  Result := TMFLACRESULT(res_2);
end;

function mflac_is_native(m_2: PMflacT): TUint8T; cdecl; public name 'mflac_is_native'; inline;
begin
  Result := TUint8T(LongInt((LongInt(m_2^.flac.container) = MINIFLAC_CONTAINER_NATIVE)));
end;

function mflac_is_ogg(m_2: PMflacT): TUint8T; cdecl; public name 'mflac_is_ogg'; inline;
begin
  Result := TUint8T(LongInt((LongInt(m_2^.flac.container) = MINIFLAC_CONTAINER_OGG)));
end;

function mflac_is_frame(m_2: PMflacT): TUint8T; cdecl; public name 'mflac_is_frame'; inline;
begin
  Result := TUint8T(LongInt((LongInt(m_2^.flac.state) = MINIFLAC_FRAME)));
end;

function mflac_is_metadata(m_2: PMflacT): TUint8T; cdecl; public name 'mflac_is_metadata'; inline;
begin
  Result := TUint8T(LongInt((LongInt(m_2^.flac.state) = MINIFLAC_METADATA)));
end;

function mflac_metadata_is_last(m_2: PMflacT): TUint8T; cdecl; public name 'mflac_metadata_is_last'; inline;
begin
  Result := TUint8T(m_2^.flac.metadata.header.is_last);
end;

function mflac_metadata_type(m_2: PMflacT): TMINIFLACMETADATATYPE; cdecl; public name 'mflac_metadata_type'; inline;
begin
  Result := TMINIFLACMETADATATYPE(m_2^.flac.metadata.header.&type);
end;

function mflac_metadata_length(m_2: PMflacT): TUint32T; cdecl; public name 'mflac_metadata_length'; inline;
begin
  Result := m_2^.flac.metadata.header.length;
end;

function mflac_metadata_is_streaminfo(m_2: PMflacT): TUint8T; cdecl; public name 'mflac_metadata_is_streaminfo'; inline;
begin
  Result := TUint8T(LongInt((LongInt(m_2^.flac.metadata.header.&type) = MINIFLAC_METADATA_STREAMINFO)));
end;

function mflac_metadata_is_padding(m_2: PMflacT): TUint8T; cdecl; public name 'mflac_metadata_is_padding'; inline;
begin
  Result := TUint8T(LongInt((LongInt(m_2^.flac.metadata.header.&type) = MINIFLAC_METADATA_PADDING)));
end;

function mflac_metadata_is_application(m_2: PMflacT): TUint8T; cdecl; public name 'mflac_metadata_is_application'; inline;
begin
  Result := TUint8T(LongInt((LongInt(m_2^.flac.metadata.header.&type) = MINIFLAC_METADATA_APPLICATION)));
end;

function mflac_metadata_is_seektable(m_2: PMflacT): TUint8T; cdecl; public name 'mflac_metadata_is_seektable'; inline;
begin
  Result := TUint8T(LongInt((LongInt(m_2^.flac.metadata.header.&type) = MINIFLAC_METADATA_SEEKTABLE)));
end;

function mflac_metadata_is_vorbis_comment(m_2: PMflacT): TUint8T; cdecl; public name 'mflac_metadata_is_vorbis_comment'; inline;
begin
  Result := TUint8T(LongInt((LongInt(m_2^.flac.metadata.header.&type) = MINIFLAC_METADATA_VORBIS_COMMENT)));
end;

function mflac_metadata_is_cuesheet(m_2: PMflacT): TUint8T; cdecl; public name 'mflac_metadata_is_cuesheet'; inline;
begin
  Result := TUint8T(LongInt((LongInt(m_2^.flac.metadata.header.&type) = MINIFLAC_METADATA_CUESHEET)));
end;

function mflac_metadata_is_picture(m_2: PMflacT): TUint8T; cdecl; public name 'mflac_metadata_is_picture'; inline;
begin
  Result := TUint8T(LongInt((LongInt(m_2^.flac.metadata.header.&type) = MINIFLAC_METADATA_PICTURE)));
end;

function mflac_frame_blocking_strategy(m_2: PMflacT): TUint8T; cdecl; public name 'mflac_frame_blocking_strategy'; inline;
begin
  Result := TUint8T(m_2^.flac.frame.header.blocking_strategy);
end;

function mflac_frame_block_size(m_2: PMflacT): TUint16T; cdecl; public name 'mflac_frame_block_size'; inline;
begin
  Result := TUint16T(m_2^.flac.frame.header.block_size);
end;

function mflac_frame_sample_rate(m_2: PMflacT): TUint32T; cdecl; public name 'mflac_frame_sample_rate'; inline;
begin
  Result := m_2^.flac.frame.header.sample_rate;
end;

function mflac_frame_channels(m_2: PMflacT): TUint8T; cdecl; public name 'mflac_frame_channels'; inline;
begin
  Result := TUint8T(m_2^.flac.frame.header.channels);
end;

function mflac_frame_bps(m_2: PMflacT): TUint8T; cdecl; public name 'mflac_frame_bps'; inline;
begin
  Result := TUint8T(m_2^.flac.frame.header.bps);
end;

function mflac_frame_sample_number(m_2: PMflacT): TUint64T; cdecl; public name 'mflac_frame_sample_number'; inline;
begin
  Result := m_2^.flac.frame.header.__c2p_anon10.sample_number;
end;

function mflac_frame_frame_number(m_2: PMflacT): TUint32T; cdecl; public name 'mflac_frame_frame_number'; inline;
begin
  Result := m_2^.flac.frame.header.__c2p_anon10.frame_number;
end;

function mflac_frame_header_size(m_2: PMflacT): TUint32T; cdecl; public name 'mflac_frame_header_size'; inline;
begin
  Result := m_2^.flac.frame.header.size;
end;

function mflac_ogg_serial(m_2: PMflacT): TInt32T; cdecl; public name 'mflac_ogg_serial'; inline;
begin
  Result := m_2^.flac.oggserial;
end;

function mflac_bytes_read_flac(m_2: PMflacT): TUint64T; cdecl; public name 'mflac_bytes_read_flac'; inline;
begin
  Result := m_2^.flac.bytes_read_flac;
end;

function mflac_bytes_read_ogg(m_2: PMflacT): TUint64T; cdecl; public name 'mflac_bytes_read_ogg'; inline;
begin
  Result := m_2^.flac.bytes_read_ogg;
end;

function mflac_version_major(): LongWord; cdecl; public name 'mflac_version_major'; inline;
begin
  Result := miniflac_version_major();
end;

function mflac_version_minor(): LongWord; cdecl; public name 'mflac_version_minor'; inline;
begin
  Result := miniflac_version_minor();
end;

function mflac_version_patch(): LongWord; cdecl; public name 'mflac_version_patch'; inline;
begin
  Result := miniflac_version_patch();
end;

function mflac_version_string(): PAnsiChar; cdecl; public name 'mflac_version_string'; inline;
begin
  Result := PAnsiChar(miniflac_version_string());
end;

function miniflac_version_major(): LongWord; cdecl; public name 'miniflac_version_major'; inline;
begin
  Result := 1;
end;

function miniflac_version_minor(): LongWord; cdecl; public name 'miniflac_version_minor'; inline;
begin
  Result := 1;
end;

function miniflac_version_patch(): LongWord; cdecl; public name 'miniflac_version_patch'; inline;
begin
  Result := 1;
end;

function miniflac_version_string(): PAnsiChar; cdecl; public name 'miniflac_version_string'; inline;
begin
  Result := PAnsiChar('1.1.1');
end;

procedure miniflac_oggreset(pFlac: PMiniflacT); inline;
begin
  miniflac_bitreader_init(@pFlac^.br);
  miniflac_oggheader_init(@pFlac^.oggheader);
  miniflac_streammarker_init(@pFlac^.streammarker);
  miniflac_metadata_init(@pFlac^.metadata);
  miniflac_frame_init(@pFlac^.frame);
  pFlac^.state := MINIFLAC_OGGHEADER;
end;

function miniflac_oggfunction_start(pFlac: PMiniflacT; data: PUint8T; packet: PPUint8T; packet_length: PUint32T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
begin
  while (LongInt(pFlac^.ogg.state) <> MINIFLAC_OGG_DATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_ogg_sync(@pFlac^.ogg, @pFlac^.ogg.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (pFlac^.oggserial_set = 0) then
    begin
      if ((LongInt(pFlac^.ogg.headertype) and 2) <> 0) then
      begin
        miniflac_oggreset(pFlac);
      end;
    end
    else
    begin
      if (pFlac^.oggserial <> pFlac^.ogg.serialno) then
      begin
        pFlac^.ogg.state := MINIFLAC_OGG_SKIP;
      end;
    end;
  end;
  packet^ := @data[pFlac^.ogg.br.pos];
  packet_length^ := LongWord((pFlac^.ogg.br.len - pFlac^.ogg.br.pos));
  if (packet_length^ > TUint32T((LongInt(pFlac^.ogg.length) - LongInt(pFlac^.ogg.pos)))) then
  begin
    packet_length^ := LongWord((TUint32T(pFlac^.ogg.length) - LongInt(pFlac^.ogg.pos)));
  end;
  Result := MINIFLAC_OK;
end;

procedure miniflac_oggfunction_end(pFlac: PMiniflacT; packet_used: TUint32T); inline;
begin
  pFlac^.ogg.br.pos := (pFlac^.ogg.br.pos + packet_used);
  pFlac^.ogg.pos := TUint16T((LongWord(pFlac^.ogg.pos) + packet_used));
  if (pFlac^.ogg.pos = pFlac^.ogg.length) then
  begin
    pFlac^.ogg.state := MINIFLAC_OGG_CAPTUREPATTERN_O;
    if ((LongInt(pFlac^.ogg.headertype) and 4) <> 0) then
    begin
      if ((pFlac^.oggserial_set = 1) and (pFlac^.oggserial = pFlac^.ogg.serialno)) then
      begin
        pFlac^.oggserial_set := TUint8T(0);
        pFlac^.oggserial := TInt32T(0);
      end;
    end;
  end;
end;

function miniflac_size(): TSizeT; cdecl; public name 'miniflac_size'; inline;
begin
  Result := 560;
end;

procedure miniflac_reset(pFlac: PMiniflacT; state: TMINIFLACSTATE); cdecl; public name 'miniflac_reset'; inline;
var
  sample_rate: TUint32T;
  bps_2: TUint8T;
begin
  sample_rate := TUint32T(0);
  bps_2 := TUint8T(0);
  if (LongInt(state) = MINIFLAC_FRAME) then
  begin
    sample_rate := pFlac^.metadata.streaminfo.sample_rate;
    bps_2 := TUint8T(pFlac^.metadata.streaminfo.bps);
  end;
  miniflac_bitreader_init(@pFlac^.br);
  miniflac_ogg_init(@pFlac^.ogg);
  miniflac_oggheader_init(@pFlac^.oggheader);
  miniflac_streammarker_init(@pFlac^.streammarker);
  miniflac_metadata_init(@pFlac^.metadata);
  miniflac_frame_init(@pFlac^.frame);
  pFlac^.bytes_read_flac := TUint64T(0);
  pFlac^.bytes_read_ogg := TUint64T(0);
  pFlac^.state := state;
  if (LongInt(state) = MINIFLAC_FRAME) then
  begin
    pFlac^.metadata.streaminfo.sample_rate := sample_rate;
    pFlac^.metadata.streaminfo.bps := TUint8T(bps_2);
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_OGG) then
  begin
    pFlac^.state := MINIFLAC_OGGHEADER;
  end;
end;

procedure miniflac_init(pFlac: PMiniflacT; container: TMINIFLACCONTAINER); cdecl; public name 'miniflac_init'; inline;
label _sw0_end;
var
  __c2p_tmp1: LongInt;
begin
  pFlac^.container := container;
  pFlac^.oggserial := TInt32T(-1);
  pFlac^.oggserial_set := TUint8T(0);
  __c2p_tmp1 := pFlac^.container;
  case __c2p_tmp1 of
    MINIFLAC_CONTAINER_UNKNOWN:
    begin
      miniflac_reset(pFlac, TMINIFLACSTATE(MINIFLAC_STREAMMARKER));
      goto _sw0_end;
    end;
    MINIFLAC_CONTAINER_NATIVE:
    begin
      miniflac_reset(pFlac, TMINIFLACSTATE(MINIFLAC_STREAMMARKER_OR_FRAME));
      goto _sw0_end;
    end;
    MINIFLAC_CONTAINER_OGG:
    begin
      miniflac_reset(pFlac, TMINIFLACSTATE(MINIFLAC_OGGHEADER));
      goto _sw0_end;
    end;
  end;
  _sw0_end:
end;

function miniflac_sync_internal(pFlac: PMiniflacT; br: PMiniflacBitreaderT): TMINIFLACRESULT;
label _L_miniflac_sync_streammarker, _L_miniflac_sync_frame, _L_miniflac_sync_metadata_or_frame, _L_miniflac_sync_metadata, _sw1_end, _sw2_case0, _sw3_case1, _sw4_case2, _sw5_case3, _sw6_case4, _sw7_case5;
var
  r_2: TMINIFLACRESULT;
  c_2: Byte;
  peek_2: TUint16T;
  __c2p_tmp1: LongInt;
begin
  __c2p_tmp1 := pFlac^.state;
  if (__c2p_tmp1 = MINIFLAC_OGGHEADER) then
  begin
    goto _sw2_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMMARKER_OR_FRAME) then
  begin
    goto _sw3_case1;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMMARKER) then
  begin
    goto _sw4_case2;
  end;
  if (__c2p_tmp1 = MINIFLAC_METADATA_OR_FRAME) then
  begin
    goto _sw5_case3;
  end;
  if (__c2p_tmp1 = MINIFLAC_METADATA) then
  begin
    goto _sw6_case4;
  end;
  if (__c2p_tmp1 = MINIFLAC_FRAME) then
  begin
    goto _sw7_case5;
  end;
  goto _sw1_end;
  _sw2_case0:
  r_2 := TMINIFLACRESULT(miniflac_oggheader_decode(@pFlac^.oggheader, br));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  pFlac^.oggserial_set := TUint8T(1);
  pFlac^.oggserial := TInt32T(pFlac^.ogg.serialno);
  pFlac^.state := MINIFLAC_STREAMMARKER;
  { C: goto miniflac_sync_streammarker }
  goto _L_miniflac_sync_streammarker;
  _sw3_case1:
  if (miniflac_bitreader_fill(br, TUint8T(8)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  c_2 := Byte(miniflac_bitreader_peek(br, TUint8T(8)));
  if (ShortInt(AnsiChar(c_2)) = 102) then
  begin
    { C: goto miniflac_sync_streammarker（共享标签继续走 METADATA_OR_FRAME） }
    goto _L_miniflac_sync_streammarker;
  end
  else
  begin
    if (c_2 = 255) then
    begin
      pFlac^.state := MINIFLAC_FRAME;
      goto _L_miniflac_sync_frame;
    end;
  end;
  Result := MINIFLAC_ERROR;
  System.Exit;
  _sw4_case2:
  _L_miniflac_sync_streammarker:
  r_2 := TMINIFLACRESULT(miniflac_streammarker_decode(@pFlac^.streammarker, br));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  pFlac^.state := MINIFLAC_METADATA_OR_FRAME;
  goto _sw5_case3;
  _sw5_case3:
  _L_miniflac_sync_metadata_or_frame:
  if (miniflac_bitreader_fill(br, TUint8T(16)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  peek_2 := TUint16T(miniflac_bitreader_peek(br, TUint8T(14)));
  if (peek_2 = 16382) then
  begin
    pFlac^.state := MINIFLAC_FRAME;
    goto _L_miniflac_sync_frame;
  end;
  pFlac^.state := MINIFLAC_METADATA;
  goto _L_miniflac_sync_metadata;
  _sw6_case4:
  _L_miniflac_sync_metadata:
  while (LongInt(pFlac^.metadata.state) <> MINIFLAC_METADATA_HEADER) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_metadata_decode(@pFlac^.metadata, br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    pFlac^.state := MINIFLAC_METADATA_OR_FRAME;
    goto _L_miniflac_sync_metadata_or_frame;
  end;
  Result := TMINIFLACRESULT(miniflac_metadata_sync(@pFlac^.metadata, br));
  System.Exit;
  _sw7_case5:
  _L_miniflac_sync_frame:
  while (LongInt(pFlac^.frame.state) <> MINIFLAC_FRAME_HEADER) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_frame_decode(@pFlac^.frame, br, @pFlac^.metadata.streaminfo, PPInt32T(Pointer(0))));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  Result := TMINIFLACRESULT(miniflac_frame_sync(@pFlac^.frame, br, @pFlac^.metadata.streaminfo));
  System.Exit;
  _sw1_end:
  Result := MINIFLAC_ERROR;
end;

function miniflac_sync_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_decode_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; samples: PPInt32T): TMINIFLACRESULT; inline;
label _L_miniflac_decode_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_FRAME) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_frame_decode(@pFlac^.frame, @pFlac^.br, @pFlac^.metadata.streaminfo, samples));
  _L_miniflac_decode_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_sync_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_sync_native(pFlac, packet, TUint32T(packet_length), @packet_used));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
    if (LongInt(r_2) = MINIFLAC_OGG_HEADER_NOTFLAC) then
    begin
      pFlac^.ogg.state := MINIFLAC_OGG_SKIP;
      r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
    end;
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_decode_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; samples: PPInt32T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_decode_native(pFlac, packet, TUint32T(packet_length), @packet_used, samples));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_probe(pFlac: PMiniflacT; data: PUint8T; length: TUint32T): TMINIFLACRESULT; inline;
label _sw8_end;
var
  __c2p_tmp1: LongInt;
begin
  if (length = LongWord(0)) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  __c2p_tmp1 := LongInt(data[0]);
  case __c2p_tmp1 of
    102:
    begin
      pFlac^.container := MINIFLAC_CONTAINER_NATIVE;
      pFlac^.state := MINIFLAC_STREAMMARKER;
      goto _sw8_end;
    end;
    79:
    begin
      pFlac^.container := MINIFLAC_CONTAINER_OGG;
      pFlac^.state := MINIFLAC_OGGHEADER;
      goto _sw8_end;
    end;
  else
  begin
    Result := MINIFLAC_ERROR;
    System.Exit;
  end
  end;
  _sw8_end:
  Result := MINIFLAC_OK;
end;

function miniflac_decode(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; samples: PPInt32T): TMINIFLACRESULT; cdecl; public name 'miniflac_decode'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_decode_native(pFlac, data, TUint32T(length), out_length, samples));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_decode_ogg(pFlac, data, TUint32T(length), out_length, samples));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_sync(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T): TMINIFLACRESULT; cdecl; public name 'miniflac_sync'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_native(pFlac, data, TUint32T(length), out_length));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_ogg(pFlac, data, TUint32T(length), out_length));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_is_native(pFlac: PMiniflacT): TUint8T; cdecl; public name 'miniflac_is_native'; inline;
begin
  Result := TUint8T(LongInt((LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE)));
end;

function miniflac_is_ogg(pFlac: PMiniflacT): TUint8T; cdecl; public name 'miniflac_is_ogg'; inline;
begin
  Result := TUint8T(LongInt((LongInt(pFlac^.container) = MINIFLAC_CONTAINER_OGG)));
end;

function miniflac_is_metadata(pFlac: PMiniflacT): TUint8T; cdecl; public name 'miniflac_is_metadata'; inline;
begin
  Result := TUint8T(LongInt((LongInt(pFlac^.state) = MINIFLAC_METADATA)));
end;

function miniflac_is_frame(pFlac: PMiniflacT): TUint8T; cdecl; public name 'miniflac_is_frame'; inline;
begin
  Result := TUint8T(LongInt((LongInt(pFlac^.state) = MINIFLAC_FRAME)));
end;

function miniflac_metadata_is_last(pFlac: PMiniflacT): TUint8T; cdecl; public name 'miniflac_metadata_is_last'; inline;
begin
  Result := TUint8T(pFlac^.metadata.header.is_last);
end;

function miniflac_metadata_type(pFlac: PMiniflacT): TMINIFLACMETADATATYPE; cdecl; public name 'miniflac_metadata_type'; inline;
begin
  Result := TMINIFLACMETADATATYPE(pFlac^.metadata.header.&type);
end;

function miniflac_metadata_length(pFlac: PMiniflacT): TUint32T; cdecl; public name 'miniflac_metadata_length'; inline;
begin
  Result := pFlac^.metadata.header.length;
end;

function miniflac_metadata_is_streaminfo(pFlac: PMiniflacT): TUint8T; cdecl; public name 'miniflac_metadata_is_streaminfo'; inline;
begin
  Result := TUint8T(LongInt((LongInt(pFlac^.metadata.header.&type) = MINIFLAC_METADATA_STREAMINFO)));
end;

function miniflac_metadata_is_padding(pFlac: PMiniflacT): TUint8T; cdecl; public name 'miniflac_metadata_is_padding'; inline;
begin
  Result := TUint8T(LongInt((LongInt(pFlac^.metadata.header.&type) = MINIFLAC_METADATA_PADDING)));
end;

function miniflac_metadata_is_application(pFlac: PMiniflacT): TUint8T; cdecl; public name 'miniflac_metadata_is_application'; inline;
begin
  Result := TUint8T(LongInt((LongInt(pFlac^.metadata.header.&type) = MINIFLAC_METADATA_APPLICATION)));
end;

function miniflac_metadata_is_seektable(pFlac: PMiniflacT): TUint8T; cdecl; public name 'miniflac_metadata_is_seektable'; inline;
begin
  Result := TUint8T(LongInt((LongInt(pFlac^.metadata.header.&type) = MINIFLAC_METADATA_SEEKTABLE)));
end;

function miniflac_metadata_is_vorbis_comment(pFlac: PMiniflacT): TUint8T; cdecl; public name 'miniflac_metadata_is_vorbis_comment'; inline;
begin
  Result := TUint8T(LongInt((LongInt(pFlac^.metadata.header.&type) = MINIFLAC_METADATA_VORBIS_COMMENT)));
end;

function miniflac_metadata_is_cuesheet(pFlac: PMiniflacT): TUint8T; cdecl; public name 'miniflac_metadata_is_cuesheet'; inline;
begin
  Result := TUint8T(LongInt((LongInt(pFlac^.metadata.header.&type) = MINIFLAC_METADATA_CUESHEET)));
end;

function miniflac_metadata_is_picture(pFlac: PMiniflacT): TUint8T; cdecl; public name 'miniflac_metadata_is_picture'; inline;
begin
  Result := TUint8T(LongInt((LongInt(pFlac^.metadata.header.&type) = MINIFLAC_METADATA_PICTURE)));
end;

function miniflac_frame_blocking_strategy(pFlac: PMiniflacT): TUint8T; cdecl; public name 'miniflac_frame_blocking_strategy'; inline;
begin
  Result := TUint8T(pFlac^.frame.header.blocking_strategy);
end;

function miniflac_frame_block_size(pFlac: PMiniflacT): TUint16T; cdecl; public name 'miniflac_frame_block_size'; inline;
begin
  Result := TUint16T(pFlac^.frame.header.block_size);
end;

function miniflac_frame_sample_rate(pFlac: PMiniflacT): TUint32T; cdecl; public name 'miniflac_frame_sample_rate'; inline;
begin
  Result := pFlac^.frame.header.sample_rate;
end;

function miniflac_frame_channels(pFlac: PMiniflacT): TUint8T; cdecl; public name 'miniflac_frame_channels'; inline;
begin
  Result := TUint8T(pFlac^.frame.header.channels);
end;

function miniflac_frame_bps(pFlac: PMiniflacT): TUint8T; cdecl; public name 'miniflac_frame_bps'; inline;
begin
  Result := TUint8T(pFlac^.frame.header.bps);
end;

function miniflac_frame_sample_number(pFlac: PMiniflacT): TUint64T; cdecl; public name 'miniflac_frame_sample_number'; inline;
begin
  Result := pFlac^.frame.header.__c2p_anon10.sample_number;
end;

function miniflac_frame_frame_number(pFlac: PMiniflacT): TUint32T; cdecl; public name 'miniflac_frame_frame_number'; inline;
begin
  Result := pFlac^.frame.header.__c2p_anon10.frame_number;
end;

function miniflac_frame_header_size(pFlac: PMiniflacT): TUint32T; cdecl; public name 'miniflac_frame_header_size'; inline;
begin
  Result := pFlac^.frame.header.size;
end;

function miniflac_ogg_serial(pFlac: PMiniflacT): TInt32T; cdecl; public name 'miniflac_ogg_serial'; inline;
begin
  Result := pFlac^.oggserial;
end;

function miniflac_bytes_read_flac(pFlac: PMiniflacT): TUint64T; cdecl; public name 'miniflac_bytes_read_flac'; inline;
begin
  Result := pFlac^.bytes_read_flac;
end;

function miniflac_bytes_read_ogg(pFlac: PMiniflacT): TUint64T; cdecl; public name 'miniflac_bytes_read_ogg'; inline;
begin
  Result := pFlac^.bytes_read_ogg;
end;

function miniflac_streaminfo_min_block_size_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint16T): TMINIFLACRESULT; inline;
label _L_miniflac_streaminfo_min_block_size_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_STREAMINFO) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_streaminfo_read_min_block_size(@pFlac^.metadata.streaminfo, @pFlac^.br, outvar));
  _L_miniflac_streaminfo_min_block_size_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_streaminfo_min_block_size_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint16T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_streaminfo_min_block_size_native(pFlac, packet, TUint32T(packet_length), @packet_used, outvar));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_streaminfo_min_block_size(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint16T): TMINIFLACRESULT; cdecl; public name 'miniflac_streaminfo_min_block_size'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_streaminfo_min_block_size_native(pFlac, data, TUint32T(length), out_length, outvar));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_streaminfo_min_block_size_ogg(pFlac, data, TUint32T(length), out_length, outvar));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_streaminfo_max_block_size_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint16T): TMINIFLACRESULT; inline;
label _L_miniflac_streaminfo_max_block_size_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_STREAMINFO) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_streaminfo_read_max_block_size(@pFlac^.metadata.streaminfo, @pFlac^.br, outvar));
  _L_miniflac_streaminfo_max_block_size_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_streaminfo_max_block_size_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint16T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_streaminfo_max_block_size_native(pFlac, packet, TUint32T(packet_length), @packet_used, outvar));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_streaminfo_max_block_size(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint16T): TMINIFLACRESULT; cdecl; public name 'miniflac_streaminfo_max_block_size'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_streaminfo_max_block_size_native(pFlac, data, TUint32T(length), out_length, outvar));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_streaminfo_max_block_size_ogg(pFlac, data, TUint32T(length), out_length, outvar));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_streaminfo_min_frame_size_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; inline;
label _L_miniflac_streaminfo_min_frame_size_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_STREAMINFO) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_streaminfo_read_min_frame_size(@pFlac^.metadata.streaminfo, @pFlac^.br, outvar));
  _L_miniflac_streaminfo_min_frame_size_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_streaminfo_min_frame_size_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_streaminfo_min_frame_size_native(pFlac, packet, TUint32T(packet_length), @packet_used, outvar));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_streaminfo_min_frame_size(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; cdecl; public name 'miniflac_streaminfo_min_frame_size'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_streaminfo_min_frame_size_native(pFlac, data, TUint32T(length), out_length, outvar));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_streaminfo_min_frame_size_ogg(pFlac, data, TUint32T(length), out_length, outvar));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_streaminfo_max_frame_size_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; inline;
label _L_miniflac_streaminfo_max_frame_size_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_STREAMINFO) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_streaminfo_read_max_frame_size(@pFlac^.metadata.streaminfo, @pFlac^.br, outvar));
  _L_miniflac_streaminfo_max_frame_size_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_streaminfo_max_frame_size_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_streaminfo_max_frame_size_native(pFlac, packet, TUint32T(packet_length), @packet_used, outvar));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_streaminfo_max_frame_size(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; cdecl; public name 'miniflac_streaminfo_max_frame_size'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_streaminfo_max_frame_size_native(pFlac, data, TUint32T(length), out_length, outvar));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_streaminfo_max_frame_size_ogg(pFlac, data, TUint32T(length), out_length, outvar));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_streaminfo_sample_rate_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; inline;
label _L_miniflac_streaminfo_sample_rate_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_STREAMINFO) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_streaminfo_read_sample_rate(@pFlac^.metadata.streaminfo, @pFlac^.br, outvar));
  _L_miniflac_streaminfo_sample_rate_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_streaminfo_sample_rate_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_streaminfo_sample_rate_native(pFlac, packet, TUint32T(packet_length), @packet_used, outvar));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_streaminfo_sample_rate(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; cdecl; public name 'miniflac_streaminfo_sample_rate'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_streaminfo_sample_rate_native(pFlac, data, TUint32T(length), out_length, outvar));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_streaminfo_sample_rate_ogg(pFlac, data, TUint32T(length), out_length, outvar));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_streaminfo_channels_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint8T): TMINIFLACRESULT; inline;
label _L_miniflac_streaminfo_channels_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_STREAMINFO) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_streaminfo_read_channels(@pFlac^.metadata.streaminfo, @pFlac^.br, outvar));
  _L_miniflac_streaminfo_channels_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_streaminfo_channels_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint8T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_streaminfo_channels_native(pFlac, packet, TUint32T(packet_length), @packet_used, outvar));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_streaminfo_channels(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint8T): TMINIFLACRESULT; cdecl; public name 'miniflac_streaminfo_channels'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_streaminfo_channels_native(pFlac, data, TUint32T(length), out_length, outvar));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_streaminfo_channels_ogg(pFlac, data, TUint32T(length), out_length, outvar));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_streaminfo_bps_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint8T): TMINIFLACRESULT; inline;
label _L_miniflac_streaminfo_bps_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_STREAMINFO) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_streaminfo_read_bps(@pFlac^.metadata.streaminfo, @pFlac^.br, outvar));
  _L_miniflac_streaminfo_bps_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_streaminfo_bps_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint8T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_streaminfo_bps_native(pFlac, packet, TUint32T(packet_length), @packet_used, outvar));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_streaminfo_bps(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint8T): TMINIFLACRESULT; cdecl; public name 'miniflac_streaminfo_bps'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_streaminfo_bps_native(pFlac, data, TUint32T(length), out_length, outvar));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_streaminfo_bps_ogg(pFlac, data, TUint32T(length), out_length, outvar));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_streaminfo_total_samples_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint64T): TMINIFLACRESULT; inline;
label _L_miniflac_streaminfo_total_samples_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_STREAMINFO) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_streaminfo_read_total_samples(@pFlac^.metadata.streaminfo, @pFlac^.br, outvar));
  _L_miniflac_streaminfo_total_samples_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_streaminfo_total_samples_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint64T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_streaminfo_total_samples_native(pFlac, packet, TUint32T(packet_length), @packet_used, outvar));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_streaminfo_total_samples(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint64T): TMINIFLACRESULT; cdecl; public name 'miniflac_streaminfo_total_samples'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_streaminfo_total_samples_native(pFlac, data, TUint32T(length), out_length, outvar));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_streaminfo_total_samples_ogg(pFlac, data, TUint32T(length), out_length, outvar));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_streaminfo_md5_length_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; inline;
label _L_miniflac_streaminfo_md5_length_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_STREAMINFO) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_streaminfo_read_md5_length(@pFlac^.metadata.streaminfo, @pFlac^.br, outvar));
  _L_miniflac_streaminfo_md5_length_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_streaminfo_md5_length_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_streaminfo_md5_length_native(pFlac, packet, TUint32T(packet_length), @packet_used, outvar));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_streaminfo_md5_length(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; cdecl; public name 'miniflac_streaminfo_md5_length'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_streaminfo_md5_length_native(pFlac, data, TUint32T(length), out_length, outvar));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_streaminfo_md5_length_ogg(pFlac, data, TUint32T(length), out_length, outvar));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_streaminfo_md5_data_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; buffer: PUint8T; bufferlen: TUint32T; outlen: PUint32T): TMINIFLACRESULT; inline;
label _L_miniflac_streaminfo_md5_data_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_STREAMINFO) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_streaminfo_read_md5_data(@pFlac^.metadata.streaminfo, @pFlac^.br, buffer, TUint32T(bufferlen), outlen));
  _L_miniflac_streaminfo_md5_data_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_streaminfo_md5_data_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; buffer: PUint8T; bufferlen: TUint32T; outlen: PUint32T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_streaminfo_md5_data_native(pFlac, packet, TUint32T(packet_length), @packet_used, buffer, TUint32T(bufferlen), outlen));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_streaminfo_md5_data(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; output: PUint8T; buffer_length: TUint32T; outlen: PUint32T): TMINIFLACRESULT; cdecl; public name 'miniflac_streaminfo_md5_data'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_streaminfo_md5_data_native(pFlac, data, TUint32T(length), out_length, output, TUint32T(buffer_length), outlen));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_streaminfo_md5_data_ogg(pFlac, data, TUint32T(length), out_length, output, TUint32T(buffer_length), outlen));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_vorbis_comment_vendor_length_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; inline;
label _L_miniflac_vorbis_comment_vendor_length_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_VORBIS_COMMENT) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_vorbis_comment_read_vendor_length(@pFlac^.metadata.vorbis_comment, @pFlac^.br, outvar));
  _L_miniflac_vorbis_comment_vendor_length_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_vorbis_comment_vendor_length_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_vorbis_comment_vendor_length_native(pFlac, packet, TUint32T(packet_length), @packet_used, outvar));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_vorbis_comment_vendor_length(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; cdecl; public name 'miniflac_vorbis_comment_vendor_length'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_vorbis_comment_vendor_length_native(pFlac, data, TUint32T(length), out_length, outvar));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_vorbis_comment_vendor_length_ogg(pFlac, data, TUint32T(length), out_length, outvar));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_vorbis_comment_vendor_string_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; buffer: PAnsiChar; bufferlen: TUint32T; outlen: PUint32T): TMINIFLACRESULT; inline;
label _L_miniflac_vorbis_comment_vendor_string_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_VORBIS_COMMENT) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_vorbis_comment_read_vendor_string(@pFlac^.metadata.vorbis_comment, @pFlac^.br, buffer, TUint32T(bufferlen), outlen));
  _L_miniflac_vorbis_comment_vendor_string_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_vorbis_comment_vendor_string_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; buffer: PAnsiChar; bufferlen: TUint32T; outlen: PUint32T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_vorbis_comment_vendor_string_native(pFlac, packet, TUint32T(packet_length), @packet_used, buffer, TUint32T(bufferlen), outlen));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_vorbis_comment_vendor_string(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; output: PAnsiChar; buffer_length: TUint32T; outlen: PUint32T): TMINIFLACRESULT; cdecl; public name 'miniflac_vorbis_comment_vendor_string'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_vorbis_comment_vendor_string_native(pFlac, data, TUint32T(length), out_length, output, TUint32T(buffer_length), outlen));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_vorbis_comment_vendor_string_ogg(pFlac, data, TUint32T(length), out_length, output, TUint32T(buffer_length), outlen));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_vorbis_comment_total_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; inline;
label _L_miniflac_vorbis_comment_total_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_VORBIS_COMMENT) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_vorbis_comment_read_total(@pFlac^.metadata.vorbis_comment, @pFlac^.br, outvar));
  _L_miniflac_vorbis_comment_total_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_vorbis_comment_total_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_vorbis_comment_total_native(pFlac, packet, TUint32T(packet_length), @packet_used, outvar));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_vorbis_comment_total(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; cdecl; public name 'miniflac_vorbis_comment_total'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_vorbis_comment_total_native(pFlac, data, TUint32T(length), out_length, outvar));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_vorbis_comment_total_ogg(pFlac, data, TUint32T(length), out_length, outvar));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_vorbis_comment_length_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; inline;
label _L_miniflac_vorbis_comment_length_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_VORBIS_COMMENT) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_vorbis_comment_read_length(@pFlac^.metadata.vorbis_comment, @pFlac^.br, outvar));
  _L_miniflac_vorbis_comment_length_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_vorbis_comment_length_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_vorbis_comment_length_native(pFlac, packet, TUint32T(packet_length), @packet_used, outvar));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_vorbis_comment_length(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; cdecl; public name 'miniflac_vorbis_comment_length'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_vorbis_comment_length_native(pFlac, data, TUint32T(length), out_length, outvar));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_vorbis_comment_length_ogg(pFlac, data, TUint32T(length), out_length, outvar));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_vorbis_comment_string_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; buffer: PAnsiChar; bufferlen: TUint32T; outlen: PUint32T): TMINIFLACRESULT; inline;
label _L_miniflac_vorbis_comment_string_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_VORBIS_COMMENT) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_vorbis_comment_read_string(@pFlac^.metadata.vorbis_comment, @pFlac^.br, buffer, TUint32T(bufferlen), outlen));
  _L_miniflac_vorbis_comment_string_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_vorbis_comment_string_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; buffer: PAnsiChar; bufferlen: TUint32T; outlen: PUint32T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_vorbis_comment_string_native(pFlac, packet, TUint32T(packet_length), @packet_used, buffer, TUint32T(bufferlen), outlen));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_vorbis_comment_string(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; output: PAnsiChar; buffer_length: TUint32T; outlen: PUint32T): TMINIFLACRESULT; cdecl; public name 'miniflac_vorbis_comment_string'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_vorbis_comment_string_native(pFlac, data, TUint32T(length), out_length, output, TUint32T(buffer_length), outlen));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_vorbis_comment_string_ogg(pFlac, data, TUint32T(length), out_length, output, TUint32T(buffer_length), outlen));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_picture_type_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; inline;
label _L_miniflac_picture_type_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_PICTURE) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_picture_read_type(@pFlac^.metadata.picture, @pFlac^.br, outvar));
  _L_miniflac_picture_type_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_picture_type_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_picture_type_native(pFlac, packet, TUint32T(packet_length), @packet_used, outvar));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_picture_type(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; cdecl; public name 'miniflac_picture_type'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_picture_type_native(pFlac, data, TUint32T(length), out_length, outvar));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_picture_type_ogg(pFlac, data, TUint32T(length), out_length, outvar));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_picture_mime_length_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; inline;
label _L_miniflac_picture_mime_length_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_PICTURE) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_picture_read_mime_length(@pFlac^.metadata.picture, @pFlac^.br, outvar));
  _L_miniflac_picture_mime_length_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_picture_mime_length_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_picture_mime_length_native(pFlac, packet, TUint32T(packet_length), @packet_used, outvar));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_picture_mime_length(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; cdecl; public name 'miniflac_picture_mime_length'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_picture_mime_length_native(pFlac, data, TUint32T(length), out_length, outvar));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_picture_mime_length_ogg(pFlac, data, TUint32T(length), out_length, outvar));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_picture_mime_string_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; buffer: PAnsiChar; bufferlen: TUint32T; outlen: PUint32T): TMINIFLACRESULT; inline;
label _L_miniflac_picture_mime_string_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_PICTURE) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_picture_read_mime_string(@pFlac^.metadata.picture, @pFlac^.br, buffer, TUint32T(bufferlen), outlen));
  _L_miniflac_picture_mime_string_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_picture_mime_string_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; buffer: PAnsiChar; bufferlen: TUint32T; outlen: PUint32T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_picture_mime_string_native(pFlac, packet, TUint32T(packet_length), @packet_used, buffer, TUint32T(bufferlen), outlen));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_picture_mime_string(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; output: PAnsiChar; buffer_length: TUint32T; outlen: PUint32T): TMINIFLACRESULT; cdecl; public name 'miniflac_picture_mime_string'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_picture_mime_string_native(pFlac, data, TUint32T(length), out_length, output, TUint32T(buffer_length), outlen));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_picture_mime_string_ogg(pFlac, data, TUint32T(length), out_length, output, TUint32T(buffer_length), outlen));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_picture_description_length_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; inline;
label _L_miniflac_picture_description_length_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_PICTURE) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_picture_read_description_length(@pFlac^.metadata.picture, @pFlac^.br, outvar));
  _L_miniflac_picture_description_length_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_picture_description_length_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_picture_description_length_native(pFlac, packet, TUint32T(packet_length), @packet_used, outvar));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_picture_description_length(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; cdecl; public name 'miniflac_picture_description_length'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_picture_description_length_native(pFlac, data, TUint32T(length), out_length, outvar));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_picture_description_length_ogg(pFlac, data, TUint32T(length), out_length, outvar));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_picture_description_string_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; buffer: PAnsiChar; bufferlen: TUint32T; outlen: PUint32T): TMINIFLACRESULT; inline;
label _L_miniflac_picture_description_string_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_PICTURE) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_picture_read_description_string(@pFlac^.metadata.picture, @pFlac^.br, buffer, TUint32T(bufferlen), outlen));
  _L_miniflac_picture_description_string_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_picture_description_string_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; buffer: PAnsiChar; bufferlen: TUint32T; outlen: PUint32T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_picture_description_string_native(pFlac, packet, TUint32T(packet_length), @packet_used, buffer, TUint32T(bufferlen), outlen));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_picture_description_string(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; output: PAnsiChar; buffer_length: TUint32T; outlen: PUint32T): TMINIFLACRESULT; cdecl; public name 'miniflac_picture_description_string'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_picture_description_string_native(pFlac, data, TUint32T(length), out_length, output, TUint32T(buffer_length), outlen));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_picture_description_string_ogg(pFlac, data, TUint32T(length), out_length, output, TUint32T(buffer_length), outlen));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_picture_width_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; inline;
label _L_miniflac_picture_width_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_PICTURE) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_picture_read_width(@pFlac^.metadata.picture, @pFlac^.br, outvar));
  _L_miniflac_picture_width_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_picture_width_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_picture_width_native(pFlac, packet, TUint32T(packet_length), @packet_used, outvar));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_picture_width(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; cdecl; public name 'miniflac_picture_width'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_picture_width_native(pFlac, data, TUint32T(length), out_length, outvar));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_picture_width_ogg(pFlac, data, TUint32T(length), out_length, outvar));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_picture_height_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; inline;
label _L_miniflac_picture_height_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_PICTURE) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_picture_read_height(@pFlac^.metadata.picture, @pFlac^.br, outvar));
  _L_miniflac_picture_height_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_picture_height_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_picture_height_native(pFlac, packet, TUint32T(packet_length), @packet_used, outvar));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_picture_height(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; cdecl; public name 'miniflac_picture_height'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_picture_height_native(pFlac, data, TUint32T(length), out_length, outvar));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_picture_height_ogg(pFlac, data, TUint32T(length), out_length, outvar));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_picture_colordepth_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; inline;
label _L_miniflac_picture_colordepth_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_PICTURE) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_picture_read_colordepth(@pFlac^.metadata.picture, @pFlac^.br, outvar));
  _L_miniflac_picture_colordepth_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_picture_colordepth_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_picture_colordepth_native(pFlac, packet, TUint32T(packet_length), @packet_used, outvar));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_picture_colordepth(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; cdecl; public name 'miniflac_picture_colordepth'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_picture_colordepth_native(pFlac, data, TUint32T(length), out_length, outvar));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_picture_colordepth_ogg(pFlac, data, TUint32T(length), out_length, outvar));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_picture_totalcolors_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; inline;
label _L_miniflac_picture_totalcolors_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_PICTURE) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_picture_read_totalcolors(@pFlac^.metadata.picture, @pFlac^.br, outvar));
  _L_miniflac_picture_totalcolors_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_picture_totalcolors_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_picture_totalcolors_native(pFlac, packet, TUint32T(packet_length), @packet_used, outvar));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_picture_totalcolors(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; cdecl; public name 'miniflac_picture_totalcolors'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_picture_totalcolors_native(pFlac, data, TUint32T(length), out_length, outvar));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_picture_totalcolors_ogg(pFlac, data, TUint32T(length), out_length, outvar));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_picture_length_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; inline;
label _L_miniflac_picture_length_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_PICTURE) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_picture_read_length(@pFlac^.metadata.picture, @pFlac^.br, outvar));
  _L_miniflac_picture_length_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_picture_length_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_picture_length_native(pFlac, packet, TUint32T(packet_length), @packet_used, outvar));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_picture_length(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; cdecl; public name 'miniflac_picture_length'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_picture_length_native(pFlac, data, TUint32T(length), out_length, outvar));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_picture_length_ogg(pFlac, data, TUint32T(length), out_length, outvar));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_picture_data_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; buffer: PUint8T; bufferlen: TUint32T; outlen: PUint32T): TMINIFLACRESULT; inline;
label _L_miniflac_picture_data_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_PICTURE) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_picture_read_data(@pFlac^.metadata.picture, @pFlac^.br, buffer, TUint32T(bufferlen), outlen));
  _L_miniflac_picture_data_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_picture_data_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; buffer: PUint8T; bufferlen: TUint32T; outlen: PUint32T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_picture_data_native(pFlac, packet, TUint32T(packet_length), @packet_used, buffer, TUint32T(bufferlen), outlen));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_picture_data(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; output: PUint8T; buffer_length: TUint32T; outlen: PUint32T): TMINIFLACRESULT; cdecl; public name 'miniflac_picture_data'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_picture_data_native(pFlac, data, TUint32T(length), out_length, output, TUint32T(buffer_length), outlen));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_picture_data_ogg(pFlac, data, TUint32T(length), out_length, output, TUint32T(buffer_length), outlen));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_cuesheet_catalog_length_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; inline;
label _L_miniflac_cuesheet_catalog_length_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_CUESHEET) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_cuesheet_read_catalog_length(@pFlac^.metadata.cuesheet, @pFlac^.br, outvar));
  _L_miniflac_cuesheet_catalog_length_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_cuesheet_catalog_length_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_cuesheet_catalog_length_native(pFlac, packet, TUint32T(packet_length), @packet_used, outvar));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_cuesheet_catalog_length(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; cdecl; public name 'miniflac_cuesheet_catalog_length'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_cuesheet_catalog_length_native(pFlac, data, TUint32T(length), out_length, outvar));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_cuesheet_catalog_length_ogg(pFlac, data, TUint32T(length), out_length, outvar));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_cuesheet_catalog_string_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; buffer: PAnsiChar; bufferlen: TUint32T; outlen: PUint32T): TMINIFLACRESULT; inline;
label _L_miniflac_cuesheet_catalog_string_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_CUESHEET) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_cuesheet_read_catalog_string(@pFlac^.metadata.cuesheet, @pFlac^.br, buffer, TUint32T(bufferlen), outlen));
  _L_miniflac_cuesheet_catalog_string_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_cuesheet_catalog_string_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; buffer: PAnsiChar; bufferlen: TUint32T; outlen: PUint32T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_cuesheet_catalog_string_native(pFlac, packet, TUint32T(packet_length), @packet_used, buffer, TUint32T(bufferlen), outlen));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_cuesheet_catalog_string(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; output: PAnsiChar; buffer_length: TUint32T; outlen: PUint32T): TMINIFLACRESULT; cdecl; public name 'miniflac_cuesheet_catalog_string'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_cuesheet_catalog_string_native(pFlac, data, TUint32T(length), out_length, output, TUint32T(buffer_length), outlen));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_cuesheet_catalog_string_ogg(pFlac, data, TUint32T(length), out_length, output, TUint32T(buffer_length), outlen));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_cuesheet_leadin_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint64T): TMINIFLACRESULT; inline;
label _L_miniflac_cuesheet_leadin_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_CUESHEET) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_cuesheet_read_leadin(@pFlac^.metadata.cuesheet, @pFlac^.br, outvar));
  _L_miniflac_cuesheet_leadin_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_cuesheet_leadin_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint64T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_cuesheet_leadin_native(pFlac, packet, TUint32T(packet_length), @packet_used, outvar));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_cuesheet_leadin(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint64T): TMINIFLACRESULT; cdecl; public name 'miniflac_cuesheet_leadin'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_cuesheet_leadin_native(pFlac, data, TUint32T(length), out_length, outvar));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_cuesheet_leadin_ogg(pFlac, data, TUint32T(length), out_length, outvar));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_cuesheet_cd_flag_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint8T): TMINIFLACRESULT; inline;
label _L_miniflac_cuesheet_cd_flag_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_CUESHEET) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_cuesheet_read_cd_flag(@pFlac^.metadata.cuesheet, @pFlac^.br, outvar));
  _L_miniflac_cuesheet_cd_flag_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_cuesheet_cd_flag_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint8T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_cuesheet_cd_flag_native(pFlac, packet, TUint32T(packet_length), @packet_used, outvar));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_cuesheet_cd_flag(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint8T): TMINIFLACRESULT; cdecl; public name 'miniflac_cuesheet_cd_flag'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_cuesheet_cd_flag_native(pFlac, data, TUint32T(length), out_length, outvar));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_cuesheet_cd_flag_ogg(pFlac, data, TUint32T(length), out_length, outvar));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_cuesheet_tracks_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint8T): TMINIFLACRESULT; inline;
label _L_miniflac_cuesheet_tracks_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_CUESHEET) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_cuesheet_read_tracks(@pFlac^.metadata.cuesheet, @pFlac^.br, outvar));
  _L_miniflac_cuesheet_tracks_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_cuesheet_tracks_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint8T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_cuesheet_tracks_native(pFlac, packet, TUint32T(packet_length), @packet_used, outvar));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_cuesheet_tracks(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint8T): TMINIFLACRESULT; cdecl; public name 'miniflac_cuesheet_tracks'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_cuesheet_tracks_native(pFlac, data, TUint32T(length), out_length, outvar));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_cuesheet_tracks_ogg(pFlac, data, TUint32T(length), out_length, outvar));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_cuesheet_track_offset_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint64T): TMINIFLACRESULT; inline;
label _L_miniflac_cuesheet_track_offset_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_CUESHEET) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_cuesheet_read_track_offset(@pFlac^.metadata.cuesheet, @pFlac^.br, outvar));
  _L_miniflac_cuesheet_track_offset_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_cuesheet_track_offset_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint64T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_cuesheet_track_offset_native(pFlac, packet, TUint32T(packet_length), @packet_used, outvar));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_cuesheet_track_offset(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint64T): TMINIFLACRESULT; cdecl; public name 'miniflac_cuesheet_track_offset'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_cuesheet_track_offset_native(pFlac, data, TUint32T(length), out_length, outvar));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_cuesheet_track_offset_ogg(pFlac, data, TUint32T(length), out_length, outvar));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_cuesheet_track_number_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint8T): TMINIFLACRESULT; inline;
label _L_miniflac_cuesheet_track_number_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_CUESHEET) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_cuesheet_read_track_number(@pFlac^.metadata.cuesheet, @pFlac^.br, outvar));
  _L_miniflac_cuesheet_track_number_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_cuesheet_track_number_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint8T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_cuesheet_track_number_native(pFlac, packet, TUint32T(packet_length), @packet_used, outvar));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_cuesheet_track_number(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint8T): TMINIFLACRESULT; cdecl; public name 'miniflac_cuesheet_track_number'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_cuesheet_track_number_native(pFlac, data, TUint32T(length), out_length, outvar));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_cuesheet_track_number_ogg(pFlac, data, TUint32T(length), out_length, outvar));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_cuesheet_track_isrc_length_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; inline;
label _L_miniflac_cuesheet_track_isrc_length_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_CUESHEET) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_cuesheet_read_track_isrc_length(@pFlac^.metadata.cuesheet, @pFlac^.br, outvar));
  _L_miniflac_cuesheet_track_isrc_length_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_cuesheet_track_isrc_length_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_cuesheet_track_isrc_length_native(pFlac, packet, TUint32T(packet_length), @packet_used, outvar));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_cuesheet_track_isrc_length(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; cdecl; public name 'miniflac_cuesheet_track_isrc_length'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_cuesheet_track_isrc_length_native(pFlac, data, TUint32T(length), out_length, outvar));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_cuesheet_track_isrc_length_ogg(pFlac, data, TUint32T(length), out_length, outvar));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_cuesheet_track_isrc_string_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; buffer: PAnsiChar; bufferlen: TUint32T; outlen: PUint32T): TMINIFLACRESULT; inline;
label _L_miniflac_cuesheet_track_isrc_string_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_CUESHEET) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_cuesheet_read_track_isrc_string(@pFlac^.metadata.cuesheet, @pFlac^.br, buffer, TUint32T(bufferlen), outlen));
  _L_miniflac_cuesheet_track_isrc_string_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_cuesheet_track_isrc_string_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; buffer: PAnsiChar; bufferlen: TUint32T; outlen: PUint32T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_cuesheet_track_isrc_string_native(pFlac, packet, TUint32T(packet_length), @packet_used, buffer, TUint32T(bufferlen), outlen));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_cuesheet_track_isrc_string(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; output: PAnsiChar; buffer_length: TUint32T; outlen: PUint32T): TMINIFLACRESULT; cdecl; public name 'miniflac_cuesheet_track_isrc_string'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_cuesheet_track_isrc_string_native(pFlac, data, TUint32T(length), out_length, output, TUint32T(buffer_length), outlen));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_cuesheet_track_isrc_string_ogg(pFlac, data, TUint32T(length), out_length, output, TUint32T(buffer_length), outlen));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_cuesheet_track_audio_flag_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint8T): TMINIFLACRESULT; inline;
label _L_miniflac_cuesheet_track_audio_flag_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_CUESHEET) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_cuesheet_read_track_audio_flag(@pFlac^.metadata.cuesheet, @pFlac^.br, outvar));
  _L_miniflac_cuesheet_track_audio_flag_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_cuesheet_track_audio_flag_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint8T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_cuesheet_track_audio_flag_native(pFlac, packet, TUint32T(packet_length), @packet_used, outvar));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_cuesheet_track_audio_flag(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint8T): TMINIFLACRESULT; cdecl; public name 'miniflac_cuesheet_track_audio_flag'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_cuesheet_track_audio_flag_native(pFlac, data, TUint32T(length), out_length, outvar));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_cuesheet_track_audio_flag_ogg(pFlac, data, TUint32T(length), out_length, outvar));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_cuesheet_track_preemph_flag_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint8T): TMINIFLACRESULT; inline;
label _L_miniflac_cuesheet_track_preemph_flag_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_CUESHEET) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_cuesheet_read_track_preemph_flag(@pFlac^.metadata.cuesheet, @pFlac^.br, outvar));
  _L_miniflac_cuesheet_track_preemph_flag_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_cuesheet_track_preemph_flag_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint8T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_cuesheet_track_preemph_flag_native(pFlac, packet, TUint32T(packet_length), @packet_used, outvar));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_cuesheet_track_preemph_flag(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint8T): TMINIFLACRESULT; cdecl; public name 'miniflac_cuesheet_track_preemph_flag'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_cuesheet_track_preemph_flag_native(pFlac, data, TUint32T(length), out_length, outvar));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_cuesheet_track_preemph_flag_ogg(pFlac, data, TUint32T(length), out_length, outvar));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_cuesheet_track_indexpoints_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint8T): TMINIFLACRESULT; inline;
label _L_miniflac_cuesheet_track_indexpoints_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_CUESHEET) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_cuesheet_read_track_indexpoints(@pFlac^.metadata.cuesheet, @pFlac^.br, outvar));
  _L_miniflac_cuesheet_track_indexpoints_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_cuesheet_track_indexpoints_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint8T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_cuesheet_track_indexpoints_native(pFlac, packet, TUint32T(packet_length), @packet_used, outvar));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_cuesheet_track_indexpoints(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint8T): TMINIFLACRESULT; cdecl; public name 'miniflac_cuesheet_track_indexpoints'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_cuesheet_track_indexpoints_native(pFlac, data, TUint32T(length), out_length, outvar));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_cuesheet_track_indexpoints_ogg(pFlac, data, TUint32T(length), out_length, outvar));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_cuesheet_index_point_offset_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint64T): TMINIFLACRESULT; inline;
label _L_miniflac_cuesheet_index_point_offset_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_CUESHEET) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_cuesheet_read_index_point_offset(@pFlac^.metadata.cuesheet, @pFlac^.br, outvar));
  _L_miniflac_cuesheet_index_point_offset_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_cuesheet_index_point_offset_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint64T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_cuesheet_index_point_offset_native(pFlac, packet, TUint32T(packet_length), @packet_used, outvar));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_cuesheet_index_point_offset(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint64T): TMINIFLACRESULT; cdecl; public name 'miniflac_cuesheet_index_point_offset'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_cuesheet_index_point_offset_native(pFlac, data, TUint32T(length), out_length, outvar));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_cuesheet_index_point_offset_ogg(pFlac, data, TUint32T(length), out_length, outvar));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_cuesheet_index_point_number_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint8T): TMINIFLACRESULT; inline;
label _L_miniflac_cuesheet_index_point_number_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_CUESHEET) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_cuesheet_read_index_point_number(@pFlac^.metadata.cuesheet, @pFlac^.br, outvar));
  _L_miniflac_cuesheet_index_point_number_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_cuesheet_index_point_number_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint8T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_cuesheet_index_point_number_native(pFlac, packet, TUint32T(packet_length), @packet_used, outvar));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_cuesheet_index_point_number(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint8T): TMINIFLACRESULT; cdecl; public name 'miniflac_cuesheet_index_point_number'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_cuesheet_index_point_number_native(pFlac, data, TUint32T(length), out_length, outvar));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_cuesheet_index_point_number_ogg(pFlac, data, TUint32T(length), out_length, outvar));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_seektable_seekpoints_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; inline;
label _L_miniflac_seektable_seekpoints_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_SEEKTABLE) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_seektable_read_seekpoints(@pFlac^.metadata.seektable, @pFlac^.br, outvar));
  _L_miniflac_seektable_seekpoints_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_seektable_seekpoints_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_seektable_seekpoints_native(pFlac, packet, TUint32T(packet_length), @packet_used, outvar));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_seektable_seekpoints(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; cdecl; public name 'miniflac_seektable_seekpoints'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_seektable_seekpoints_native(pFlac, data, TUint32T(length), out_length, outvar));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_seektable_seekpoints_ogg(pFlac, data, TUint32T(length), out_length, outvar));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_seektable_sample_number_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint64T): TMINIFLACRESULT; inline;
label _L_miniflac_seektable_sample_number_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_SEEKTABLE) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_seektable_read_sample_number(@pFlac^.metadata.seektable, @pFlac^.br, outvar));
  _L_miniflac_seektable_sample_number_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_seektable_sample_number_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint64T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_seektable_sample_number_native(pFlac, packet, TUint32T(packet_length), @packet_used, outvar));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_seektable_sample_number(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint64T): TMINIFLACRESULT; cdecl; public name 'miniflac_seektable_sample_number'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_seektable_sample_number_native(pFlac, data, TUint32T(length), out_length, outvar));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_seektable_sample_number_ogg(pFlac, data, TUint32T(length), out_length, outvar));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_seektable_sample_offset_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint64T): TMINIFLACRESULT; inline;
label _L_miniflac_seektable_sample_offset_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_SEEKTABLE) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_seektable_read_sample_offset(@pFlac^.metadata.seektable, @pFlac^.br, outvar));
  _L_miniflac_seektable_sample_offset_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_seektable_sample_offset_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint64T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_seektable_sample_offset_native(pFlac, packet, TUint32T(packet_length), @packet_used, outvar));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_seektable_sample_offset(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint64T): TMINIFLACRESULT; cdecl; public name 'miniflac_seektable_sample_offset'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_seektable_sample_offset_native(pFlac, data, TUint32T(length), out_length, outvar));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_seektable_sample_offset_ogg(pFlac, data, TUint32T(length), out_length, outvar));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_seektable_samples_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint16T): TMINIFLACRESULT; inline;
label _L_miniflac_seektable_samples_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_SEEKTABLE) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_seektable_read_samples(@pFlac^.metadata.seektable, @pFlac^.br, outvar));
  _L_miniflac_seektable_samples_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_seektable_samples_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint16T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_seektable_samples_native(pFlac, packet, TUint32T(packet_length), @packet_used, outvar));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_seektable_samples(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint16T): TMINIFLACRESULT; cdecl; public name 'miniflac_seektable_samples'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_seektable_samples_native(pFlac, data, TUint32T(length), out_length, outvar));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_seektable_samples_ogg(pFlac, data, TUint32T(length), out_length, outvar));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_application_id_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; inline;
label _L_miniflac_application_id_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_APPLICATION) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_application_read_id(@pFlac^.metadata.application, @pFlac^.br, outvar));
  _L_miniflac_application_id_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_application_id_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_application_id_native(pFlac, packet, TUint32T(packet_length), @packet_used, outvar));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_application_id(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; cdecl; public name 'miniflac_application_id'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_application_id_native(pFlac, data, TUint32T(length), out_length, outvar));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_application_id_ogg(pFlac, data, TUint32T(length), out_length, outvar));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_application_length_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; inline;
label _L_miniflac_application_length_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_APPLICATION) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_application_read_length(@pFlac^.metadata.application, @pFlac^.br, outvar));
  _L_miniflac_application_length_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_application_length_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_application_length_native(pFlac, packet, TUint32T(packet_length), @packet_used, outvar));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_application_length(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; cdecl; public name 'miniflac_application_length'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_application_length_native(pFlac, data, TUint32T(length), out_length, outvar));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_application_length_ogg(pFlac, data, TUint32T(length), out_length, outvar));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_application_data_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; buffer: PUint8T; bufferlen: TUint32T; outlen: PUint32T): TMINIFLACRESULT; inline;
label _L_miniflac_application_data_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_APPLICATION) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_application_read_data(@pFlac^.metadata.application, @pFlac^.br, buffer, TUint32T(bufferlen), outlen));
  _L_miniflac_application_data_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_application_data_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; buffer: PUint8T; bufferlen: TUint32T; outlen: PUint32T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_application_data_native(pFlac, packet, TUint32T(packet_length), @packet_used, buffer, TUint32T(bufferlen), outlen));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_application_data(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; output: PUint8T; buffer_length: TUint32T; outlen: PUint32T): TMINIFLACRESULT; cdecl; public name 'miniflac_application_data'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_application_data_native(pFlac, data, TUint32T(length), out_length, output, TUint32T(buffer_length), outlen));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_application_data_ogg(pFlac, data, TUint32T(length), out_length, output, TUint32T(buffer_length), outlen));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_padding_length_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; inline;
label _L_miniflac_padding_length_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_PADDING) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_padding_read_length(@pFlac^.metadata.padding, @pFlac^.br, outvar));
  _L_miniflac_padding_length_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_padding_length_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_padding_length_native(pFlac, packet, TUint32T(packet_length), @packet_used, outvar));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_padding_length(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; outvar: PUint32T): TMINIFLACRESULT; cdecl; public name 'miniflac_padding_length'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_padding_length_native(pFlac, data, TUint32T(length), out_length, outvar));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_padding_length_ogg(pFlac, data, TUint32T(length), out_length, outvar));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_padding_data_native(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; buffer: PUint8T; bufferlen: TUint32T; outlen: PUint32T): TMINIFLACRESULT; inline;
label _L_miniflac_padding_data_exit;
var
  r_2: TMINIFLACRESULT;
begin
  pFlac^.br.buffer := data;
  pFlac^.br.len := length;
  pFlac^.br.pos := TUint32T(0);
  while (LongInt(pFlac^.state) <> MINIFLAC_METADATA) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  while (LongInt(pFlac^.metadata.header.&type) <> MINIFLAC_METADATA_PADDING) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_sync_internal(pFlac, @pFlac^.br));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    if (LongInt(pFlac^.state) <> MINIFLAC_METADATA) then
    begin
      r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
      out_length^ := pFlac^.br.pos;
      pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_padding_read_data(@pFlac^.metadata.padding, @pFlac^.br, buffer, TUint32T(bufferlen), outlen));
  _L_miniflac_padding_data_exit:
  out_length^ := pFlac^.br.pos;
  pFlac^.bytes_read_flac := (pFlac^.bytes_read_flac + QWord(pFlac^.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_padding_data_ogg(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; buffer: PUint8T; bufferlen: TUint32T; outlen: PUint32T): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
  packet: PUint8T;
  packet_length: TUint32T;
  packet_used: TUint32T;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_CONTINUE);
  packet := nil;
  packet_length := TUint32T(0);
  packet_used := TUint32T(0);
  pFlac^.ogg.br.buffer := data;
  pFlac^.ogg.br.len := length;
  pFlac^.ogg.br.pos := TUint32T(0);
  repeat
    r_2 := TMINIFLACRESULT(miniflac_oggfunction_start(pFlac, data, @packet, @packet_length));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
    r_2 := TMINIFLACRESULT(miniflac_padding_data_native(pFlac, packet, TUint32T(packet_length), @packet_used, buffer, TUint32T(bufferlen), outlen));
    miniflac_oggfunction_end(pFlac, TUint32T(packet_used));
  until (((LongInt(r_2) = MINIFLAC_CONTINUE) and (pFlac^.ogg.br.pos < length)) = False);
  out_length^ := pFlac^.ogg.br.pos;
  pFlac^.bytes_read_ogg := (pFlac^.bytes_read_ogg + QWord(pFlac^.ogg.br.pos));
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_padding_data(pFlac: PMiniflacT; data: PUint8T; length: TUint32T; out_length: PUint32T; output: PUint8T; buffer_length: TUint32T; outlen: PUint32T): TMINIFLACRESULT; cdecl; public name 'miniflac_padding_data'; inline;
var
  r_2: TMINIFLACRESULT;
begin
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_UNKNOWN) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_probe(pFlac, data, TUint32T(length)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
  end;
  if (LongInt(pFlac^.container) = MINIFLAC_CONTAINER_NATIVE) then
  begin
    r_2 := TMINIFLACRESULT(miniflac_padding_data_native(pFlac, data, TUint32T(length), out_length, output, TUint32T(buffer_length), outlen));
  end
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_padding_data_ogg(pFlac, data, TUint32T(length), out_length, output, TUint32T(buffer_length), outlen));
  end;
  Result := TMINIFLACRESULT(r_2);
end;

function miniflac_unpack_uint32le(buffer: PUint8T): TUint32T; inline;
begin
  Result := ((((TUint32T(buffer[0]) shl 0) or (TUint32T(buffer[1]) shl 8)) or (TUint32T(buffer[2]) shl 16)) or (TUint32T(buffer[3]) shl 24));
end;

function miniflac_unpack_int32le(buffer: PUint8T): TInt32T; inline;
begin
  Result := TInt32T(miniflac_unpack_uint32le(buffer));
end;

function miniflac_unpack_uint64le(buffer: PUint8T): TUint64T; inline;
begin
  Result := ((((((((TUint64T(buffer[0]) shl 0) or (TUint64T(buffer[1]) shl 8)) or (TUint64T(buffer[2]) shl 16)) or (TUint64T(buffer[3]) shl 24)) or (TUint64T(buffer[4]) shl 32)) or (TUint64T(buffer[5]) shl 40)) or (TUint64T(buffer[6]) shl 48)) or (TUint64T(buffer[7]) shl 56));
end;

function miniflac_unpack_int64le(buffer: PUint8T): TInt64T; inline;
begin
  Result := TInt64T(miniflac_unpack_uint64le(buffer));
end;

procedure miniflac_bitreader_init(br: PMiniflacBitreaderT); inline;
begin
  br^.val := TUint64T(0);
  br^.bits := TUint8T(0);
  br^.crc8 := TUint8T(0);
  br^.crc16 := TUint16T(0);
  br^.pos := TUint32T(0);
  br^.len := TUint32T(0);
  br^.buffer := nil;
  br^.tot := TUint32T(0);
end;

function miniflac_bitreader_fill(br: PMiniflacBitreaderT; bits_2: TUint8T): LongInt; inline;
var
  byte_: TUint8T;
  __c2p_tmp1: TUint32T;
begin
  byte_ := TUint8T(0);
  if (bits_2 = 0) then
  begin
    Result := 0;
    System.Exit;
  end;
  while ((br^.bits < bits_2) and (br^.pos < br^.len)) do
  begin
    __c2p_tmp1 := br^.pos;
    br^.pos := (br^.pos + 1);
    byte_ := TUint8T(br^.buffer[__c2p_tmp1]);
    br^.val := ((br^.val shl 8) or QWord(LongInt(byte_)));
    br^.bits := TUint8T((br^.bits + 8));
    br^.crc8 := TUint8T(miniflac_crc8_table[(LongInt(br^.crc8) xor LongInt(byte_))]);
    br^.crc16 := TUint16T((LongInt(miniflac_crc16_table[((LongInt(br^.crc16) shr 8) xor LongInt(byte_))]) xor ((LongInt(br^.crc16) and 255) shl 8)));
    br^.tot := (br^.tot + 1);
  end;
  Result := LongInt((br^.bits < bits_2));
end;

function miniflac_bitreader_fill_nocrc(br: PMiniflacBitreaderT; bits_2: TUint8T): LongInt; inline;
var
  byte_: TUint8T;
  __c2p_tmp1: TUint32T;
begin
  byte_ := TUint8T(0);
  if (bits_2 = 0) then
  begin
    Result := 0;
    System.Exit;
  end;
  while ((br^.bits < bits_2) and (br^.pos < br^.len)) do
  begin
    __c2p_tmp1 := br^.pos;
    br^.pos := (br^.pos + 1);
    byte_ := TUint8T(br^.buffer[__c2p_tmp1]);
    br^.val := ((br^.val shl 8) or QWord(LongInt(byte_)));
    br^.bits := TUint8T((br^.bits + 8));
    br^.tot := (br^.tot + 1);
  end;
  Result := LongInt((br^.bits < bits_2));
end;

function miniflac_bitreader_read(br: PMiniflacBitreaderT; bits_2: TUint8T): TUint64T; inline;
var
  mask_2: TUint64T;
  imask_2: TUint64T;
  r_2: TUint64T;
begin
  mask_2 := TUint64T(-Int64(1));
  imask_2 := TUint64T(-Int64(1));
  if (bits_2 = 0) then
  begin
    Result := 0;
    System.Exit;
  end;
  mask_2 := (mask_2 shr (64 - LongInt(bits_2)));
  br^.bits := TUint8T((br^.bits - bits_2));
  r_2 := ((br^.val shr LongInt(br^.bits)) and mask_2);
  if (br^.bits = 0) then
  begin
    imask_2 := TUint64T(0);
  end
  else
  begin
    imask_2 := (imask_2 shr (64 - LongInt(br^.bits)));
  end;
  br^.val := (br^.val and imask_2);
  Result := r_2;
end;

function miniflac_bitreader_read_signed(br: PMiniflacBitreaderT; bits_2: TUint8T): TInt64T; inline;
var
  t_2: TUint64T;
  mask_2: TUint64T;
begin
  mask_2 := TUint64T(-Int64(1));
  if (bits_2 = 0) then
  begin
    Result := 0;
    System.Exit;
  end;
  mask_2 := (mask_2 shl bits_2);
  t_2 := miniflac_bitreader_read(br, TUint8T(bits_2));
  if ((t_2 and QWord((1 shl (LongInt(bits_2) - 1)))) <> 0) then
  begin
    t_2 := (t_2 or mask_2);
  end;
  Result := t_2;
end;

function miniflac_bitreader_peek(br: PMiniflacBitreaderT; bits_2: TUint8T): TUint64T; inline;
var
  mask_2: TUint64T;
  r_2: TUint64T;
begin
  mask_2 := TUint64T(-Int64(1));
  if (bits_2 = 0) then
  begin
    Result := 0;
    System.Exit;
  end;
  mask_2 := (mask_2 shr (64 - LongInt(bits_2)));
  r_2 := ((br^.val shr (LongInt(br^.bits) - LongInt(bits_2))) and mask_2);
  Result := r_2;
end;

procedure miniflac_bitreader_discard(br: PMiniflacBitreaderT; bits_2: TUint8T); inline;
var
  imask_2: TUint64T;
begin
  imask_2 := TUint64T(-Int64(1));
  if (bits_2 = 0) then
  begin
    System.Exit;
  end;
  br^.bits := TUint8T((br^.bits - bits_2));
  if (br^.bits = 0) then
  begin
    imask_2 := TUint64T(0);
  end
  else
  begin
    imask_2 := (imask_2 shr (64 - LongInt(br^.bits)));
  end;
  br^.val := (br^.val and imask_2);
end;

procedure miniflac_bitreader_align(br: PMiniflacBitreaderT); inline;
begin
  br^.bits := TUint8T(0);
  br^.val := TUint64T(0);
end;

procedure miniflac_bitreader_reset_crc(br: PMiniflacBitreaderT); inline;
var
  val_2: TUint64T;
  bits_2: TUint8T;
  byte_: TUint8T;
  mask_2: TUint64T;
  imask_2: TUint64T;
begin
  val_2 := br^.val;
  bits_2 := TUint8T(br^.bits);
  br^.crc8 := TUint8T(0);
  br^.crc16 := TUint16T(0);
  br^.tot := TUint32T(0);
  while (bits_2 > 0) do
  begin
    mask_2 := TUint64T(-Int64(1));
    imask_2 := TUint64T(-Int64(1));
    mask_2 := (mask_2 shr (64 - 8));
    bits_2 := TUint8T((bits_2 - 8));
    byte_ := TUint8T(((val_2 shr LongInt(bits_2)) and mask_2));
    if (bits_2 = 0) then
    begin
      imask_2 := TUint64T(0);
    end
    else
    begin
      imask_2 := (imask_2 shr (64 - LongInt(bits_2)));
    end;
    val_2 := (val_2 and imask_2);
    br^.crc8 := TUint8T(miniflac_crc8_table[(LongInt(br^.crc8) xor LongInt(byte_))]);
    br^.crc16 := TUint16T((LongInt(miniflac_crc16_table[((LongInt(br^.crc16) shr 8) xor LongInt(byte_))]) xor ((LongInt(br^.crc16) and 255) shl 8)));
    br^.tot := (br^.tot + 1);
  end;
end;

procedure miniflac_oggheader_init(oggheader: PMiniflacOggheaderT); inline;
begin
  oggheader^.state := MINIFLAC_OGGHEADER_PACKETTYPE;
end;

function miniflac_oggheader_decode(oggheader: PMiniflacOggheaderT; br: PMiniflacBitreaderT): TMINIFLACRESULT;
label _sw9_end, _sw10_case0, _sw11_case1, _sw12_case2, _sw13_case3, _sw14_case4, _sw15_case5, _sw16_case6, _sw17_case7, _sw18_default;
var
  __c2p_tmp1: LongInt;
begin
  __c2p_tmp1 := oggheader^.state;
  if (__c2p_tmp1 = MINIFLAC_OGGHEADER_PACKETTYPE) then
  begin
    goto _sw10_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_OGGHEADER_F) then
  begin
    goto _sw11_case1;
  end;
  if (__c2p_tmp1 = MINIFLAC_OGGHEADER_L) then
  begin
    goto _sw12_case2;
  end;
  if (__c2p_tmp1 = MINIFLAC_OGGHEADER_A) then
  begin
    goto _sw13_case3;
  end;
  if (__c2p_tmp1 = MINIFLAC_OGGHEADER_C) then
  begin
    goto _sw14_case4;
  end;
  if (__c2p_tmp1 = MINIFLAC_OGGHEADER_MAJOR) then
  begin
    goto _sw15_case5;
  end;
  if (__c2p_tmp1 = MINIFLAC_OGGHEADER_MINOR) then
  begin
    goto _sw16_case6;
  end;
  if (__c2p_tmp1 = MINIFLAC_OGGHEADER_HEADERPACKETS) then
  begin
    goto _sw17_case7;
  end;
  goto _sw18_default;
  _sw10_case0:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(8)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  if (TUint8T(miniflac_bitreader_read(br, TUint8T(8))) <> 127) then
  begin
    Result := MINIFLAC_OGG_HEADER_NOTFLAC;
    System.Exit;
  end;
  oggheader^.state := MINIFLAC_OGGHEADER_F;
  goto _sw11_case1;
  _sw11_case1:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(8)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  if (ShortInt(AnsiChar(miniflac_bitreader_read(br, TUint8T(8)))) <> 70) then
  begin
    Result := MINIFLAC_ERROR;
    System.Exit;
  end;
  oggheader^.state := MINIFLAC_OGGHEADER_L;
  goto _sw12_case2;
  _sw12_case2:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(8)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  if (ShortInt(AnsiChar(miniflac_bitreader_read(br, TUint8T(8)))) <> 76) then
  begin
    Result := MINIFLAC_ERROR;
    System.Exit;
  end;
  oggheader^.state := MINIFLAC_OGGHEADER_A;
  goto _sw13_case3;
  _sw13_case3:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(8)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  if (ShortInt(AnsiChar(miniflac_bitreader_read(br, TUint8T(8)))) <> 65) then
  begin
    Result := MINIFLAC_ERROR;
    System.Exit;
  end;
  oggheader^.state := MINIFLAC_OGGHEADER_C;
  goto _sw14_case4;
  _sw14_case4:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(8)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  if (ShortInt(AnsiChar(miniflac_bitreader_read(br, TUint8T(8)))) <> 67) then
  begin
    Result := MINIFLAC_ERROR;
    System.Exit;
  end;
  oggheader^.state := MINIFLAC_OGGHEADER_MAJOR;
  goto _sw15_case5;
  _sw15_case5:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(8)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  if (TUint8T(miniflac_bitreader_read(br, TUint8T(8))) <> 1) then
  begin
    Result := MINIFLAC_ERROR;
    System.Exit;
  end;
  oggheader^.state := MINIFLAC_OGGHEADER_MINOR;
  goto _sw16_case6;
  _sw16_case6:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(8)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  if (TUint8T(miniflac_bitreader_read(br, TUint8T(8))) <> 0) then
  begin
    Result := MINIFLAC_ERROR;
    System.Exit;
  end;
  oggheader^.state := MINIFLAC_OGGHEADER_HEADERPACKETS;
  goto _sw17_case7;
  _sw17_case7:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(16)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  miniflac_bitreader_discard(br, TUint8T(16));
  oggheader^.state := MINIFLAC_OGGHEADER_PACKETTYPE;
  goto _sw18_default;
  _sw18_default:
  goto _sw9_end;
  _sw9_end:
  Result := MINIFLAC_OK;
end;

procedure miniflac_ogg_init(ogg: PMiniflacOggT); inline;
begin
  ogg^.state := MINIFLAC_OGG_CAPTUREPATTERN_O;
  ogg^.version := TUint8T(0);
  ogg^.headertype := TUint8T(0);
  ogg^.granulepos := TInt64T(0);
  ogg^.serialno := TInt32T(0);
  ogg^.pageno := TUint32T(0);
  ogg^.segments := TUint8T(0);
  ogg^.curseg := TUint8T(0);
  ogg^.length := TUint16T(0);
  ogg^.pos := TUint16T(0);
  miniflac_bitreader_init(@ogg^.br);
end;

function miniflac_ogg_sync(ogg: PMiniflacOggT; br: PMiniflacBitreaderT): TMINIFLACRESULT;
label _sw19_end, _sw20_case0, _sw21_case1, _sw22_case2, _sw23_case3, _sw24_case4, _sw25_case5, _sw26_case6, _sw27_case7, _sw28_case8, _sw29_case9, _sw30_case10, _sw31_case11, _sw32_case12, _sw33_case13;
var
  c_2: Byte;
  buffer: array[0..7] of TUint8T;
  __c2p_tmp1: LongInt;
begin
  __c2p_tmp1 := ogg^.state;
  if (__c2p_tmp1 = MINIFLAC_OGG_SKIP) then
  begin
    goto _sw20_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_OGG_DATA) then
  begin
    goto _sw21_case1;
  end;
  if (__c2p_tmp1 = MINIFLAC_OGG_CAPTUREPATTERN_O) then
  begin
    goto _sw22_case2;
  end;
  if (__c2p_tmp1 = MINIFLAC_OGG_CAPTUREPATTERN_G1) then
  begin
    goto _sw23_case3;
  end;
  if (__c2p_tmp1 = MINIFLAC_OGG_CAPTUREPATTERN_G2) then
  begin
    goto _sw24_case4;
  end;
  if (__c2p_tmp1 = MINIFLAC_OGG_CAPTUREPATTERN_S) then
  begin
    goto _sw25_case5;
  end;
  if (__c2p_tmp1 = MINIFLAC_OGG_VERSION) then
  begin
    goto _sw26_case6;
  end;
  if (__c2p_tmp1 = MINIFLAC_OGG_HEADERTYPE) then
  begin
    goto _sw27_case7;
  end;
  if (__c2p_tmp1 = MINIFLAC_OGG_GRANULEPOS) then
  begin
    goto _sw28_case8;
  end;
  if (__c2p_tmp1 = MINIFLAC_OGG_SERIALNO) then
  begin
    goto _sw29_case9;
  end;
  if (__c2p_tmp1 = MINIFLAC_OGG_PAGENO) then
  begin
    goto _sw30_case10;
  end;
  if (__c2p_tmp1 = MINIFLAC_OGG_CHECKSUM) then
  begin
    goto _sw31_case11;
  end;
  if (__c2p_tmp1 = MINIFLAC_OGG_PAGESEGMENTS) then
  begin
    goto _sw32_case12;
  end;
  if (__c2p_tmp1 = MINIFLAC_OGG_SEGMENTTABLE) then
  begin
    goto _sw33_case13;
  end;
  goto _sw19_end;
  _sw20_case0:
  goto _sw21_case1;
  _sw21_case1:
  while (ogg^.pos < ogg^.length) do
  begin
    if (miniflac_bitreader_fill_nocrc(br, TUint8T(8)) <> 0) then
    begin
      Result := MINIFLAC_CONTINUE;
      System.Exit;
    end;
    miniflac_bitreader_discard(br, TUint8T(8));
    ogg^.pos := TUint16T((LongInt(ogg^.pos) + 1));
  end;
  ogg^.state := MINIFLAC_OGG_CAPTUREPATTERN_O;
  goto _sw22_case2;
  _sw22_case2:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(8)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  c_2 := Byte(miniflac_bitreader_read(br, TUint8T(8)));
  if (c_2 <> 79) then
  begin
    Result := MINIFLAC_ERROR;
    System.Exit;
  end;
  ogg^.state := MINIFLAC_OGG_CAPTUREPATTERN_G1;
  goto _sw23_case3;
  _sw23_case3:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(8)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  c_2 := Byte(miniflac_bitreader_read(br, TUint8T(8)));
  if (c_2 <> 103) then
  begin
    Result := MINIFLAC_ERROR;
    System.Exit;
  end;
  ogg^.state := MINIFLAC_OGG_CAPTUREPATTERN_G2;
  goto _sw24_case4;
  _sw24_case4:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(8)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  c_2 := Byte(miniflac_bitreader_read(br, TUint8T(8)));
  if (c_2 <> 103) then
  begin
    Result := MINIFLAC_ERROR;
    System.Exit;
  end;
  ogg^.state := MINIFLAC_OGG_CAPTUREPATTERN_S;
  goto _sw25_case5;
  _sw25_case5:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(8)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  c_2 := Byte(miniflac_bitreader_read(br, TUint8T(8)));
  if (c_2 <> 83) then
  begin
    Result := MINIFLAC_ERROR;
    System.Exit;
  end;
  ogg^.state := MINIFLAC_OGG_VERSION;
  goto _sw26_case6;
  _sw26_case6:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(8)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  ogg^.version := TUint8T(miniflac_bitreader_read(br, TUint8T(8)));
  if (ogg^.version <> 0) then
  begin
    Result := MINIFLAC_ERROR;
    System.Exit;
  end;
  ogg^.state := MINIFLAC_OGG_HEADERTYPE;
  goto _sw27_case7;
  _sw27_case7:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(8)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  ogg^.headertype := TUint8T(miniflac_bitreader_read(br, TUint8T(8)));
  ogg^.state := MINIFLAC_OGG_GRANULEPOS;
  goto _sw28_case8;
  _sw28_case8:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(64)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  buffer[0] := TUint8T(miniflac_bitreader_read(br, TUint8T(8)));
  buffer[1] := TUint8T(miniflac_bitreader_read(br, TUint8T(8)));
  buffer[2] := TUint8T(miniflac_bitreader_read(br, TUint8T(8)));
  buffer[3] := TUint8T(miniflac_bitreader_read(br, TUint8T(8)));
  buffer[4] := TUint8T(miniflac_bitreader_read(br, TUint8T(8)));
  buffer[5] := TUint8T(miniflac_bitreader_read(br, TUint8T(8)));
  buffer[6] := TUint8T(miniflac_bitreader_read(br, TUint8T(8)));
  buffer[7] := TUint8T(miniflac_bitreader_read(br, TUint8T(8)));
  ogg^.granulepos := TInt64T(miniflac_unpack_int64le(PUint8T(@buffer[0])));
  ogg^.state := MINIFLAC_OGG_SERIALNO;
  goto _sw29_case9;
  _sw29_case9:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(32)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  buffer[0] := TUint8T(miniflac_bitreader_read(br, TUint8T(8)));
  buffer[1] := TUint8T(miniflac_bitreader_read(br, TUint8T(8)));
  buffer[2] := TUint8T(miniflac_bitreader_read(br, TUint8T(8)));
  buffer[3] := TUint8T(miniflac_bitreader_read(br, TUint8T(8)));
  ogg^.serialno := TInt32T(miniflac_unpack_int32le(PUint8T(@buffer[0])));
  ogg^.state := MINIFLAC_OGG_PAGENO;
  goto _sw30_case10;
  _sw30_case10:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(32)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  buffer[0] := TUint8T(miniflac_bitreader_read(br, TUint8T(8)));
  buffer[1] := TUint8T(miniflac_bitreader_read(br, TUint8T(8)));
  buffer[2] := TUint8T(miniflac_bitreader_read(br, TUint8T(8)));
  buffer[3] := TUint8T(miniflac_bitreader_read(br, TUint8T(8)));
  ogg^.pageno := miniflac_unpack_uint32le(PUint8T(@buffer[0]));
  ogg^.state := MINIFLAC_OGG_CHECKSUM;
  goto _sw31_case11;
  _sw31_case11:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(32)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  miniflac_bitreader_discard(br, TUint8T(32));
  ogg^.state := MINIFLAC_OGG_PAGESEGMENTS;
  goto _sw32_case12;
  _sw32_case12:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(8)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  ogg^.segments := TUint8T(miniflac_bitreader_read(br, TUint8T(8)));
  ogg^.curseg := TUint8T(0);
  ogg^.length := TUint16T(0);
  ogg^.state := MINIFLAC_OGG_SEGMENTTABLE;
  goto _sw33_case13;
  _sw33_case13:
  while (ogg^.curseg < ogg^.segments) do
  begin
    if (miniflac_bitreader_fill_nocrc(br, TUint8T(8)) <> 0) then
    begin
      Result := MINIFLAC_CONTINUE;
      System.Exit;
    end;
    ogg^.length := TUint16T((QWord(ogg^.length) + miniflac_bitreader_read(br, TUint8T(8))));
    ogg^.curseg := TUint8T((LongInt(ogg^.curseg) + 1));
  end;
  ogg^.pos := TUint16T(0);
  ogg^.state := MINIFLAC_OGG_DATA;
  Result := MINIFLAC_OK;
  System.Exit;
  _sw19_end:
  Result := MINIFLAC_ERROR;
end;

procedure miniflac_frame_init(frame: PMiniflacFrameT); inline;
begin
  frame^.crc16 := TUint16T(0);
  frame^.cur_subframe := TUint8T(0);
  frame^.state := MINIFLAC_FRAME_HEADER;
  miniflac_frame_header_init(@frame^.header);
  miniflac_subframe_init(@frame^.subframe);
end;

function miniflac_frame_sync(frame: PMiniflacFrameT; br: PMiniflacBitreaderT; info: PMiniflacStreaminfoT): TMINIFLACRESULT; inline;
var
  r_2: TMINIFLACRESULT;
begin
  r_2 := TMINIFLACRESULT(miniflac_frame_header_decode(@frame^.header, br));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  if (frame^.header.sample_rate = LongWord(0)) then
  begin
    if (info^.sample_rate = LongWord(0)) then
    begin
      Result := MINIFLAC_FRAME_INVALID_SAMPLE_RATE;
      System.Exit;
    end;
    frame^.header.sample_rate := info^.sample_rate;
  end;
  if (frame^.header.bps = 0) then
  begin
    if (info^.bps = 0) then
    begin
      Result := MINIFLAC_FRAME_INVALID_SAMPLE_SIZE;
      System.Exit;
    end;
    frame^.header.bps := TUint8T(info^.bps);
  end;
  frame^.state := MINIFLAC_FRAME_SUBFRAME;
  frame^.cur_subframe := TUint8T(0);
  miniflac_subframe_init(@frame^.subframe);
  Result := MINIFLAC_OK;
end;

{$push}
{$hints off}
{$warnings off}
procedure miniflac_frame_decode__c2p_case_helper_1(frame: PMiniflacFrameT; var output: PPInt32T; var i_2: TUint32T); inline;
label _L__for2_step;
var
  m_2: TUint64T;
  s_2: TUint64T;
begin
{$ifdef FLAC_SIMD_ON}
{$ifdef cpuaarch64}
  flac_mid_side_neon(PInt32T(output[0]), PInt32T(output[1]), LongWord(frame^.header.block_size));
  i_2 := TUint32T(frame^.header.block_size);
  System.Exit;
{$endif}
{$endif}
  i_2 := TUint32T(0);
  while (i_2 < LongWord(frame^.header.block_size)) do
  begin
    m_2 := TUint64T(output[0][i_2]);
    s_2 := TUint64T(output[1][i_2]);
    m_2 := ((m_2 shl 1) or (s_2 and QWord(1)));
    output[0][i_2] := TInt32T(((m_2 + s_2) shr 1));
    output[1][i_2] := TInt32T(((m_2 - s_2) shr 1));
    _L__for2_step:
    i_2 := (i_2 + 1);
  end;
end;
{$pop}

function miniflac_frame_decode(frame: PMiniflacFrameT; br: PMiniflacBitreaderT; info: PMiniflacStreaminfoT; output: PPInt32T): TMINIFLACRESULT;
label _sw34_end, _sw35_case0, _sw36_case1, _sw37_case2, _sw38_default, _L__for0_step, _sw39_end, _L__for1_step;
var
  r_2: TMINIFLACRESULT;
  bps_2: TUint32T;
  i_2: TUint32T;
  t_2: TUint16T;
  __c2p_tmp1: LongInt;
  __c2p_tmp2: PInt32T;
  __c2p_tmp3: LongInt;
begin
  __c2p_tmp1 := frame^.state;
  if (__c2p_tmp1 = MINIFLAC_FRAME_HEADER) then
  begin
    goto _sw35_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_FRAME_SUBFRAME) then
  begin
    goto _sw36_case1;
  end;
  if (__c2p_tmp1 = MINIFLAC_FRAME_FOOTER) then
  begin
    goto _sw37_case2;
  end;
  goto _sw38_default;
  _sw35_case0:
  r_2 := TMINIFLACRESULT(miniflac_frame_sync(frame, br, info));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _sw36_case1;
  _sw36_case1:
  while (frame^.cur_subframe < frame^.header.channels) do
  begin
    bps_2 := TUint32T(frame^.header.bps);
    if ((LongInt(frame^.header.channel_assignment) = MINIFLAC_CHASSGN_LEFT_SIDE) or (LongInt(frame^.header.channel_assignment) = MINIFLAC_CHASSGN_MID_SIDE)) then
    begin
      if (frame^.cur_subframe = 1) then
      begin
        bps_2 := (bps_2 + LongWord(1));
      end;
    end
    else
    begin
      if (LongInt(frame^.header.channel_assignment) = MINIFLAC_CHASSGN_RIGHT_SIDE) then
      begin
        if (frame^.cur_subframe = 0) then
        begin
          bps_2 := (bps_2 + LongWord(1));
        end;
      end;
    end;
    if (output = nil) then
    begin
      __c2p_tmp2 := nil;
    end
    else
    begin
      __c2p_tmp2 := output[LongInt(frame^.cur_subframe)];
    end;
    r_2 := TMINIFLACRESULT(miniflac_subframe_decode(@frame^.subframe, br, __c2p_tmp2, TUint32T(frame^.header.block_size), TUint8T(bps_2)));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Result := TMINIFLACRESULT(r_2);
      System.Exit;
    end;
    miniflac_subframe_init(@frame^.subframe);
    frame^.cur_subframe := TUint8T((LongInt(frame^.cur_subframe) + 1));
  end;
  miniflac_bitreader_align(br);
  frame^.crc16 := TUint16T(br^.crc16);
  frame^.state := MINIFLAC_FRAME_FOOTER;
  goto _sw37_case2;
  _sw37_case2:
  if (miniflac_bitreader_fill(br, TUint8T(16)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  t_2 := TUint16T(miniflac_bitreader_read(br, TUint8T(16)));
  if (frame^.crc16 <> t_2) then
  begin
    Result := MINIFLAC_FRAME_CRC16_INVALID;
    System.Exit;
  end;
  frame^.size := TSizeT(br^.tot);
  if (output <> nil) then
  begin
    __c2p_tmp3 := frame^.header.channel_assignment;
    case __c2p_tmp3 of
      MINIFLAC_CHASSGN_LEFT_SIDE:
      begin
{$ifdef FLAC_SIMD_ON}
{$ifdef cpuaarch64}
        flac_left_side_neon(PInt32T(output[1]), PInt32T(output[0]), LongWord(frame^.header.block_size));
{$else}
        i_2 := TUint32T(0);
        while (i_2 < LongWord(frame^.header.block_size)) do
        begin
          output[1][i_2] := TInt32T((output[0][i_2] - output[1][i_2]));
          _L__for0_step:
          i_2 := (i_2 + 1);
        end;
{$endif}
{$else}
        i_2 := TUint32T(0);
        while (i_2 < LongWord(frame^.header.block_size)) do
        begin
          output[1][i_2] := TInt32T((output[0][i_2] - output[1][i_2]));
          _L__for0_step:
          i_2 := (i_2 + 1);
        end;
{$endif}
      end;
      MINIFLAC_CHASSGN_RIGHT_SIDE:
      begin
{$ifdef FLAC_SIMD_ON}
{$ifdef cpuaarch64}
        flac_right_side_neon(PInt32T(output[0]), PInt32T(output[1]), LongWord(frame^.header.block_size));
{$else}
        i_2 := TUint32T(0);
        while (i_2 < LongWord(frame^.header.block_size)) do
        begin
          output[0][i_2] := TInt32T((output[0][i_2] + output[1][i_2]));
          _L__for1_step:
          i_2 := (i_2 + 1);
        end;
{$endif}
{$else}
        i_2 := TUint32T(0);
        while (i_2 < LongWord(frame^.header.block_size)) do
        begin
          output[0][i_2] := TInt32T((output[0][i_2] + output[1][i_2]));
          _L__for1_step:
          i_2 := (i_2 + 1);
        end;
{$endif}
      end;
      MINIFLAC_CHASSGN_MID_SIDE:
      begin
        miniflac_frame_decode__c2p_case_helper_1(frame, output, i_2);
      end;
    else
    begin
    end
    end;
    _sw39_end:
  end;
  goto _sw34_end;
  _sw38_default:
  Result := MINIFLAC_ERROR;
  System.Exit;
  _sw34_end:
  br^.crc8 := TUint8T(0);
  br^.crc16 := TUint16T(0);
  frame^.cur_subframe := TUint8T(0);
  frame^.state := MINIFLAC_FRAME_HEADER;
  miniflac_subframe_init(@frame^.subframe);
  Result := MINIFLAC_OK;
end;

procedure miniflac_frame_header_init(header: PMiniflacFrameHeaderT); inline;
begin
  header^.state := MINIFLAC_FRAME_HEADER_SYNC;
  header^.block_size_raw := TUint8T(0);
  header^.sample_rate_raw := TUint8T(0);
  header^.channel_assignment_raw := TUint8T(0);
  header^.sample_rate := TUint32T(0);
  header^.blocking_strategy := TUint8T(0);
  header^.block_size := TUint16T(0);
  header^.sample_rate := TUint32T(0);
  header^.channel_assignment := MINIFLAC_CHASSGN_NONE;
  header^.channels := TUint8T(0);
  header^.bps := TUint8T(0);
  header^.__c2p_anon10.sample_number := TUint64T(0);
  header^.crc8 := TUint8T(0);
  header^.size := TSizeT(0);
end;

function miniflac_frame_header_decode(header: PMiniflacFrameHeaderT; br: PMiniflacBitreaderT): TMINIFLACRESULT;
label _L_flac_frame_blocksize_maybe, _L_flac_frame_samplenumber_7, _L_flac_frame_samplenumber_6, _L_flac_frame_samplenumber_5, _L_flac_frame_samplenumber_4, _L_flac_frame_samplenumber_3, _L_flac_frame_samplenumber_2, _sw40_end, _sw41_case0, _sw42_case1, _sw43_case2, _sw44_case3, _sw45_case4, _sw46_case5, _sw47_case6, _sw48_case7, _sw49_case8, _sw50_case9, _sw51_case10, _sw52_case11, _sw53_case12, _sw54_case13, _sw55_case14, _sw56_case15, _sw57_case16, _sw58_case17, _sw59_default, _sw60_end, _sw61_end, _sw62_end, _sw63_end, _sw64_end, _sw65_end;
var
  t_2: TUint64T;
  __c2p_tmp1: LongInt;
  __c2p_tmp2: LongInt;
  __c2p_tmp3: LongInt;
  __c2p_tmp5: TUint64T;
  __c2p_tmp6: LongInt;
  __c2p_tmp7: LongInt;
  __c2p_tmp4: TUint64T;
begin
  __c2p_tmp1 := header^.state;
  if (__c2p_tmp1 = MINIFLAC_FRAME_HEADER_SYNC) then
  begin
    goto _sw41_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_FRAME_HEADER_RESERVEBIT_1) then
  begin
    goto _sw42_case1;
  end;
  if (__c2p_tmp1 = MINIFLAC_FRAME_HEADER_BLOCKINGSTRATEGY) then
  begin
    goto _sw43_case2;
  end;
  if (__c2p_tmp1 = MINIFLAC_FRAME_HEADER_BLOCKSIZE) then
  begin
    goto _sw44_case3;
  end;
  if (__c2p_tmp1 = MINIFLAC_FRAME_HEADER_SAMPLERATE) then
  begin
    goto _sw45_case4;
  end;
  if (__c2p_tmp1 = MINIFLAC_FRAME_HEADER_CHANNELASSIGNMENT) then
  begin
    goto _sw46_case5;
  end;
  if (__c2p_tmp1 = MINIFLAC_FRAME_HEADER_SAMPLESIZE) then
  begin
    goto _sw47_case6;
  end;
  if (__c2p_tmp1 = MINIFLAC_FRAME_HEADER_RESERVEBIT_2) then
  begin
    goto _sw48_case7;
  end;
  if (__c2p_tmp1 = MINIFLAC_FRAME_HEADER_SAMPLENUMBER_1) then
  begin
    goto _sw49_case8;
  end;
  if (__c2p_tmp1 = MINIFLAC_FRAME_HEADER_SAMPLENUMBER_2) then
  begin
    goto _sw50_case9;
  end;
  if (__c2p_tmp1 = MINIFLAC_FRAME_HEADER_SAMPLENUMBER_3) then
  begin
    goto _sw51_case10;
  end;
  if (__c2p_tmp1 = MINIFLAC_FRAME_HEADER_SAMPLENUMBER_4) then
  begin
    goto _sw52_case11;
  end;
  if (__c2p_tmp1 = MINIFLAC_FRAME_HEADER_SAMPLENUMBER_5) then
  begin
    goto _sw53_case12;
  end;
  if (__c2p_tmp1 = MINIFLAC_FRAME_HEADER_SAMPLENUMBER_6) then
  begin
    goto _sw54_case13;
  end;
  if (__c2p_tmp1 = MINIFLAC_FRAME_HEADER_SAMPLENUMBER_7) then
  begin
    goto _sw55_case14;
  end;
  if (__c2p_tmp1 = MINIFLAC_FRAME_HEADER_BLOCKSIZE_MAYBE) then
  begin
    goto _sw56_case15;
  end;
  if (__c2p_tmp1 = MINIFLAC_FRAME_HEADER_SAMPLERATE_MAYBE) then
  begin
    goto _sw57_case16;
  end;
  if (__c2p_tmp1 = MINIFLAC_FRAME_HEADER_CRC8) then
  begin
    goto _sw58_case17;
  end;
  goto _sw59_default;
  _sw41_case0:
  miniflac_bitreader_reset_crc(br);
  if (miniflac_bitreader_fill(br, TUint8T(14)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  t_2 := miniflac_bitreader_read(br, TUint8T(14));
  if (t_2 <> QWord(16382)) then
  begin
    Result := MINIFLAC_FRAME_SYNCCODE_INVALID;
    System.Exit;
  end;
  miniflac_frame_header_init(header);
  header^.state := MINIFLAC_FRAME_HEADER_RESERVEBIT_1;
  goto _sw42_case1;
  _sw42_case1:
  if (miniflac_bitreader_fill(br, TUint8T(1)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  t_2 := miniflac_bitreader_read(br, TUint8T(1));
  if (t_2 <> QWord(0)) then
  begin
    Result := MINIFLAC_FRAME_RESERVED_BIT1;
    System.Exit;
  end;
  header^.state := MINIFLAC_FRAME_HEADER_BLOCKINGSTRATEGY;
  goto _sw43_case2;
  _sw43_case2:
  if (miniflac_bitreader_fill(br, TUint8T(1)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  t_2 := miniflac_bitreader_read(br, TUint8T(1));
  header^.blocking_strategy := TUint8T(t_2);
  header^.state := MINIFLAC_FRAME_HEADER_BLOCKSIZE;
  header^.size := (header^.size + QWord(2));
  goto _sw44_case3;
  _sw44_case3:
  if (miniflac_bitreader_fill(br, TUint8T(4)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  t_2 := miniflac_bitreader_read(br, TUint8T(4));
  header^.block_size_raw := TUint8T(t_2);
  header^.block_size := TUint16T(0);
  __c2p_tmp2 := LongInt(header^.block_size_raw);
  case __c2p_tmp2 of
    0:
    begin
      Result := MINIFLAC_FRAME_RESERVED_BLOCKSIZE;
      System.Exit;
    end;
    1:
    begin
      header^.block_size := TUint16T(192);
      goto _sw60_end;
    end;
    2:
    begin
      header^.block_size := TUint16T(576);
      goto _sw60_end;
    end;
    3:
    begin
      header^.block_size := TUint16T(1152);
      goto _sw60_end;
    end;
    4:
    begin
      header^.block_size := TUint16T(2304);
      goto _sw60_end;
    end;
    5:
    begin
      header^.block_size := TUint16T(4608);
      goto _sw60_end;
    end;
    8:
    begin
      header^.block_size := TUint16T(256);
      goto _sw60_end;
    end;
    9:
    begin
      header^.block_size := TUint16T(512);
      goto _sw60_end;
    end;
    10:
    begin
      header^.block_size := TUint16T(1024);
      goto _sw60_end;
    end;
    11:
    begin
      header^.block_size := TUint16T(2048);
      goto _sw60_end;
    end;
    12:
    begin
      header^.block_size := TUint16T(4096);
      goto _sw60_end;
    end;
    13:
    begin
      header^.block_size := TUint16T(8192);
      goto _sw60_end;
    end;
    14:
    begin
      header^.block_size := TUint16T(16384);
      goto _sw60_end;
    end;
    15:
    begin
      header^.block_size := TUint16T(32768);
      goto _sw60_end;
    end;
  else
  begin
    goto _sw60_end;
  end
  end;
  _sw60_end:
  header^.state := MINIFLAC_FRAME_HEADER_SAMPLERATE;
  goto _sw45_case4;
  _sw45_case4:
  if (miniflac_bitreader_fill(br, TUint8T(4)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  t_2 := miniflac_bitreader_read(br, TUint8T(4));
  header^.sample_rate_raw := TUint8T(t_2);
  __c2p_tmp3 := LongInt(header^.sample_rate_raw);
  case __c2p_tmp3 of
    0:
    begin
      header^.sample_rate := TUint32T(0);
      goto _sw61_end;
    end;
    1:
    begin
      header^.sample_rate := TUint32T(88200);
      goto _sw61_end;
    end;
    2:
    begin
      header^.sample_rate := TUint32T(176400);
      goto _sw61_end;
    end;
    3:
    begin
      header^.sample_rate := TUint32T(192000);
      goto _sw61_end;
    end;
    4:
    begin
      header^.sample_rate := TUint32T(8000);
      goto _sw61_end;
    end;
    5:
    begin
      header^.sample_rate := TUint32T(16000);
      goto _sw61_end;
    end;
    6:
    begin
      header^.sample_rate := TUint32T(22050);
      goto _sw61_end;
    end;
    7:
    begin
      header^.sample_rate := TUint32T(24000);
      goto _sw61_end;
    end;
    8:
    begin
      header^.sample_rate := TUint32T(32000);
      goto _sw61_end;
    end;
    9:
    begin
      header^.sample_rate := TUint32T(44100);
      goto _sw61_end;
    end;
    10:
    begin
      header^.sample_rate := TUint32T(48000);
      goto _sw61_end;
    end;
    11:
    begin
      header^.sample_rate := TUint32T(96000);
      goto _sw61_end;
    end;
    12, 13, 14:
    begin
      header^.sample_rate := TUint32T(0);
      goto _sw61_end;
    end;
    15:
    begin
      Result := MINIFLAC_FRAME_INVALID_SAMPLE_RATE;
      System.Exit;
    end;
  else
  begin
    goto _sw61_end;
  end
  end;
  _sw61_end:
  header^.state := MINIFLAC_FRAME_HEADER_CHANNELASSIGNMENT;
  header^.size := (header^.size + QWord(1));
  goto _sw46_case5;
  _sw46_case5:
  if (miniflac_bitreader_fill(br, TUint8T(4)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  t_2 := miniflac_bitreader_read(br, TUint8T(4));
  if (t_2 > QWord(10)) then
  begin
    Result := MINIFLAC_FRAME_RESERVED_CHANNEL_ASSIGNMENT;
    System.Exit;
  end;
  if (t_2 < QWord(8)) then
  begin
    header^.channels := TUint8T((t_2 + 1));
    header^.channel_assignment := MINIFLAC_CHASSGN_NONE;
  end
  else
  begin
    __c2p_tmp4 := t_2;
    case __c2p_tmp4 of
      8:
      begin
        header^.channel_assignment := MINIFLAC_CHASSGN_LEFT_SIDE;
      end;
      9:
      begin
        header^.channel_assignment := MINIFLAC_CHASSGN_RIGHT_SIDE;
      end;
      10:
      begin
        header^.channel_assignment := MINIFLAC_CHASSGN_MID_SIDE;
      end;
    else
    begin
    end
    end;
    _sw62_end:
    header^.channels := TUint8T(2);
  end;
  header^.channel_assignment_raw := TUint8T(t_2);
  header^.state := MINIFLAC_FRAME_HEADER_SAMPLESIZE;
  goto _sw47_case6;
  _sw47_case6:
  if (miniflac_bitreader_fill(br, TUint8T(3)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  t_2 := miniflac_bitreader_read(br, TUint8T(3));
  __c2p_tmp5 := t_2;
  case __c2p_tmp5 of
    0:
    begin
      header^.bps := TUint8T(0);
      goto _sw63_end;
    end;
    1:
    begin
      header^.bps := TUint8T(8);
      goto _sw63_end;
    end;
    2:
    begin
      header^.bps := TUint8T(12);
      goto _sw63_end;
    end;
    3:
    begin
      Result := MINIFLAC_FRAME_RESERVED_SAMPLE_SIZE;
      System.Exit;
    end;
    4:
    begin
      header^.bps := TUint8T(16);
      goto _sw63_end;
    end;
    5:
    begin
      header^.bps := TUint8T(20);
      goto _sw63_end;
    end;
    6:
    begin
      header^.bps := TUint8T(24);
      goto _sw63_end;
    end;
    7:
    begin
      Result := MINIFLAC_FRAME_RESERVED_SAMPLE_SIZE;
      System.Exit;
    end;
  end;
  _sw63_end:
  header^.state := MINIFLAC_FRAME_HEADER_RESERVEBIT_2;
  goto _sw48_case7;
  _sw48_case7:
  if (miniflac_bitreader_fill(br, TUint8T(1)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  t_2 := miniflac_bitreader_read(br, TUint8T(1));
  if (t_2 <> QWord(0)) then
  begin
    Result := MINIFLAC_FRAME_RESERVED_BIT2;
    System.Exit;
  end;
  header^.state := MINIFLAC_FRAME_HEADER_SAMPLENUMBER_1;
  header^.size := (header^.size + QWord(1));
  goto _sw49_case8;
  _sw49_case8:
  if (miniflac_bitreader_fill(br, TUint8T(8)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  t_2 := miniflac_bitreader_read(br, TUint8T(8));
  if ((t_2 and QWord(128)) = QWord(0)) then
  begin
    header^.__c2p_anon10.sample_number := t_2;
    header^.state := MINIFLAC_FRAME_HEADER_BLOCKSIZE_MAYBE;
    header^.size := (header^.size + QWord(1));
    { C: goto flac_frame_blocksize_maybe }
    goto _L_flac_frame_blocksize_maybe;
  end
  else
  begin
    if ((t_2 and QWord(224)) = QWord(192)) then
    begin
      header^.__c2p_anon10.sample_number := ((t_2 and QWord(31)) shl 6);
      header^.state := MINIFLAC_FRAME_HEADER_SAMPLENUMBER_7;
      header^.size := (header^.size + QWord(2));
      if (miniflac_bitreader_fill(br, TUint8T(8)) <> 0) then
      begin
        Result := MINIFLAC_CONTINUE;
        System.Exit;
      end
      else
      begin
      end;
      t_2 := miniflac_bitreader_read(br, TUint8T(8));
      header^.__c2p_anon10.sample_number := (header^.__c2p_anon10.sample_number + (t_2 and QWord(63)));
      header^.state := MINIFLAC_FRAME_HEADER_BLOCKSIZE_MAYBE;
      goto _L_flac_frame_blocksize_maybe;
    end
    else
    begin
      if ((t_2 and QWord(240)) = QWord(224)) then
      begin
        header^.__c2p_anon10.sample_number := ((t_2 and QWord(15)) shl 12);
        header^.state := MINIFLAC_FRAME_HEADER_SAMPLENUMBER_6;
        header^.size := (header^.size + QWord(3));
        if (miniflac_bitreader_fill(br, TUint8T(8)) <> 0) then
        begin
          Result := MINIFLAC_CONTINUE;
          System.Exit;
        end
        else
        begin
        end;
        t_2 := miniflac_bitreader_read(br, TUint8T(8));
        header^.__c2p_anon10.sample_number := (header^.__c2p_anon10.sample_number + ((t_2 and QWord(63)) shl 6));
        header^.state := MINIFLAC_FRAME_HEADER_SAMPLENUMBER_7;
        goto _L_flac_frame_samplenumber_7;
      end
      else
      begin
        if ((t_2 and QWord(248)) = QWord(240)) then
        begin
          header^.__c2p_anon10.sample_number := ((t_2 and QWord(7)) shl 18);
          header^.state := MINIFLAC_FRAME_HEADER_SAMPLENUMBER_5;
          header^.size := (header^.size + QWord(4));
          if (miniflac_bitreader_fill(br, TUint8T(8)) <> 0) then
          begin
            Result := MINIFLAC_CONTINUE;
            System.Exit;
          end
          else
          begin
          end;
          t_2 := miniflac_bitreader_read(br, TUint8T(8));
          header^.__c2p_anon10.sample_number := (header^.__c2p_anon10.sample_number + ((t_2 and QWord(63)) shl 12));
          header^.state := MINIFLAC_FRAME_HEADER_SAMPLENUMBER_6;
          goto _L_flac_frame_samplenumber_6;
        end
        else
        begin
          if ((t_2 and QWord(252)) = QWord(248)) then
          begin
            header^.__c2p_anon10.sample_number := ((t_2 and QWord(3)) shl 24);
            header^.state := MINIFLAC_FRAME_HEADER_SAMPLENUMBER_4;
            header^.size := (header^.size + QWord(5));
            if (miniflac_bitreader_fill(br, TUint8T(8)) <> 0) then
            begin
              Result := MINIFLAC_CONTINUE;
              System.Exit;
            end
            else
            begin
            end;
            t_2 := miniflac_bitreader_read(br, TUint8T(8));
            header^.__c2p_anon10.sample_number := (header^.__c2p_anon10.sample_number + ((t_2 and QWord(63)) shl 18));
            header^.state := MINIFLAC_FRAME_HEADER_SAMPLENUMBER_5;
            goto _L_flac_frame_samplenumber_5;
          end
          else
          begin
            if ((t_2 and QWord(254)) = QWord(252)) then
            begin
              header^.__c2p_anon10.sample_number := ((t_2 and QWord(1)) shl 30);
              header^.state := MINIFLAC_FRAME_HEADER_SAMPLENUMBER_3;
              header^.size := (header^.size + QWord(6));
              if (miniflac_bitreader_fill(br, TUint8T(8)) <> 0) then
              begin
                Result := MINIFLAC_CONTINUE;
                System.Exit;
              end
              else
              begin
              end;
              t_2 := miniflac_bitreader_read(br, TUint8T(8));
              header^.__c2p_anon10.sample_number := (header^.__c2p_anon10.sample_number + ((t_2 and QWord(63)) shl 24));
              header^.state := MINIFLAC_FRAME_HEADER_SAMPLENUMBER_4;
              goto _L_flac_frame_samplenumber_4;
            end
            else
            begin
              if ((t_2 and QWord(255)) = QWord(254)) then
              begin
                header^.__c2p_anon10.sample_number := TUint64T(0);
                header^.state := MINIFLAC_FRAME_HEADER_SAMPLENUMBER_2;
                header^.size := (header^.size + QWord(7));
                if (miniflac_bitreader_fill(br, TUint8T(8)) <> 0) then
                begin
                  Result := MINIFLAC_CONTINUE;
                  System.Exit;
                end
                else
                begin
                end;
                t_2 := miniflac_bitreader_read(br, TUint8T(8));
                header^.__c2p_anon10.sample_number := (header^.__c2p_anon10.sample_number + ((t_2 and QWord(63)) shl 30));
                header^.state := MINIFLAC_FRAME_HEADER_SAMPLENUMBER_3;
                goto _L_flac_frame_samplenumber_3;
              end;
            end;
          end;
        end;
      end;
    end;
  end;
  goto _sw50_case9;
  _sw50_case9:
  _L_flac_frame_samplenumber_2:
  if (miniflac_bitreader_fill(br, TUint8T(8)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  t_2 := miniflac_bitreader_read(br, TUint8T(8));
  header^.__c2p_anon10.sample_number := (header^.__c2p_anon10.sample_number + ((t_2 and QWord(63)) shl 30));
  header^.state := MINIFLAC_FRAME_HEADER_SAMPLENUMBER_3;
  goto _sw51_case10;
  _sw51_case10:
  _L_flac_frame_samplenumber_3:
  if (miniflac_bitreader_fill(br, TUint8T(8)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  t_2 := miniflac_bitreader_read(br, TUint8T(8));
  header^.__c2p_anon10.sample_number := (header^.__c2p_anon10.sample_number + ((t_2 and QWord(63)) shl 24));
  header^.state := MINIFLAC_FRAME_HEADER_SAMPLENUMBER_4;
  goto _sw52_case11;
  _sw52_case11:
  _L_flac_frame_samplenumber_4:
  if (miniflac_bitreader_fill(br, TUint8T(8)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  t_2 := miniflac_bitreader_read(br, TUint8T(8));
  header^.__c2p_anon10.sample_number := (header^.__c2p_anon10.sample_number + ((t_2 and QWord(63)) shl 18));
  header^.state := MINIFLAC_FRAME_HEADER_SAMPLENUMBER_5;
  goto _sw53_case12;
  _sw53_case12:
  _L_flac_frame_samplenumber_5:
  if (miniflac_bitreader_fill(br, TUint8T(8)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  t_2 := miniflac_bitreader_read(br, TUint8T(8));
  header^.__c2p_anon10.sample_number := (header^.__c2p_anon10.sample_number + ((t_2 and QWord(63)) shl 12));
  header^.state := MINIFLAC_FRAME_HEADER_SAMPLENUMBER_6;
  goto _sw54_case13;
  _sw54_case13:
  _L_flac_frame_samplenumber_6:
  if (miniflac_bitreader_fill(br, TUint8T(8)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  t_2 := miniflac_bitreader_read(br, TUint8T(8));
  header^.__c2p_anon10.sample_number := (header^.__c2p_anon10.sample_number + ((t_2 and QWord(63)) shl 6));
  header^.state := MINIFLAC_FRAME_HEADER_SAMPLENUMBER_7;
  goto _sw55_case14;
  _sw55_case14:
  _L_flac_frame_samplenumber_7:
  if (miniflac_bitreader_fill(br, TUint8T(8)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  t_2 := miniflac_bitreader_read(br, TUint8T(8));
  header^.__c2p_anon10.sample_number := (header^.__c2p_anon10.sample_number + (t_2 and QWord(63)));
  header^.state := MINIFLAC_FRAME_HEADER_BLOCKSIZE_MAYBE;
  goto _sw56_case15;
  _sw56_case15:
  _L_flac_frame_blocksize_maybe:
  __c2p_tmp6 := LongInt(header^.block_size_raw);
  case __c2p_tmp6 of
    6:
    begin
      if (miniflac_bitreader_fill(br, TUint8T(8)) <> 0) then
      begin
        Result := MINIFLAC_CONTINUE;
        System.Exit;
      end;
      t_2 := (miniflac_bitreader_read(br, TUint8T(8)) + 1);
      header^.block_size := TUint16T(t_2);
      header^.size := (header^.size + QWord(1));
      goto _sw64_end;
    end;
    7:
    begin
      if (miniflac_bitreader_fill(br, TUint8T(16)) <> 0) then
      begin
        Result := MINIFLAC_CONTINUE;
        System.Exit;
      end;
      t_2 := (miniflac_bitreader_read(br, TUint8T(16)) + 1);
      header^.block_size := TUint16T(t_2);
      header^.size := (header^.size + QWord(2));
      goto _sw64_end;
    end;
  else
  begin
    goto _sw64_end;
  end
  end;
  _sw64_end:
  header^.state := MINIFLAC_FRAME_HEADER_SAMPLERATE_MAYBE;
  goto _sw57_case16;
  _sw57_case16:
  __c2p_tmp7 := LongInt(header^.sample_rate_raw);
  case __c2p_tmp7 of
    12:
    begin
      if (miniflac_bitreader_fill(br, TUint8T(8)) <> 0) then
      begin
        Result := MINIFLAC_CONTINUE;
        System.Exit;
      end;
      t_2 := miniflac_bitreader_read(br, TUint8T(8));
      header^.sample_rate := TUint32T(QWord((t_2 * QWord(1000))));
      header^.size := (header^.size + QWord(1));
      goto _sw65_end;
    end;
    13:
    begin
      if (miniflac_bitreader_fill(br, TUint8T(16)) <> 0) then
      begin
        Result := MINIFLAC_CONTINUE;
        System.Exit;
      end;
      t_2 := miniflac_bitreader_read(br, TUint8T(16));
      header^.sample_rate := TUint32T(t_2);
      header^.size := (header^.size + QWord(2));
      goto _sw65_end;
    end;
    14:
    begin
      if (miniflac_bitreader_fill(br, TUint8T(16)) <> 0) then
      begin
        Result := MINIFLAC_CONTINUE;
        System.Exit;
      end;
      t_2 := miniflac_bitreader_read(br, TUint8T(16));
      header^.sample_rate := TUint32T(QWord((t_2 * QWord(10))));
      header^.size := (header^.size + QWord(2));
      goto _sw65_end;
    end;
  else
  begin
    goto _sw65_end;
  end
  end;
  _sw65_end:
  header^.crc8 := TUint8T(br^.crc8);
  header^.state := MINIFLAC_FRAME_HEADER_CRC8;
  goto _sw58_case17;
  _sw58_case17:
  if (miniflac_bitreader_fill(br, TUint8T(8)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  t_2 := miniflac_bitreader_read(br, TUint8T(8));
  if (QWord(header^.crc8) <> t_2) then
  begin
    Result := MINIFLAC_FRAME_CRC8_INVALID;
    System.Exit;
  end;
  header^.size := (header^.size + QWord(1));
  goto _sw59_default;
  _sw59_default:
  goto _sw40_end;
  _sw40_end:
  header^.state := MINIFLAC_FRAME_HEADER_SYNC;
  Result := MINIFLAC_OK;
end;

procedure miniflac_vorbis_comment_init(vorbis_comment: PMiniflacVorbisCommentT); inline;
begin
  vorbis_comment^.state := MINIFLAC_VORBISCOMMENT_VENDOR_LENGTH;
  vorbis_comment^.len := TUint32T(0);
  vorbis_comment^.pos := TUint32T(0);
  vorbis_comment^.tot := TUint32T(0);
  vorbis_comment^.cur := TUint32T(0);
end;

function miniflac_vorbis_comment_read_vendor_length(vorbis_comment: PMiniflacVorbisCommentT; br: PMiniflacBitreaderT; length: PUint32T): TMINIFLACRESULT; inline;
label _sw66_end;
var
  buffer: array[0..3] of TUint8T;
  __c2p_tmp1: LongInt;
begin
  __c2p_tmp1 := vorbis_comment^.state;
  case __c2p_tmp1 of
    MINIFLAC_VORBISCOMMENT_VENDOR_LENGTH:
    begin
      if (miniflac_bitreader_fill_nocrc(br, TUint8T(32)) <> 0) then
      begin
        Result := MINIFLAC_CONTINUE;
        System.Exit;
      end;
      buffer[0] := TUint8T(miniflac_bitreader_read(br, TUint8T(8)));
      buffer[1] := TUint8T(miniflac_bitreader_read(br, TUint8T(8)));
      buffer[2] := TUint8T(miniflac_bitreader_read(br, TUint8T(8)));
      buffer[3] := TUint8T(miniflac_bitreader_read(br, TUint8T(8)));
      vorbis_comment^.len := miniflac_unpack_uint32le(PUint8T(@buffer[0]));
      if (length <> nil) then
      begin
        length^ := vorbis_comment^.len;
      end;
      vorbis_comment^.state := MINIFLAC_VORBISCOMMENT_VENDOR_STRING;
      Result := MINIFLAC_OK;
      System.Exit;
    end;
  else
  begin
    goto _sw66_end;
  end
  end;
  _sw66_end:
  Result := MINIFLAC_ERROR;
end;

function miniflac_vorbis_comment_read_vendor_string(vorbis_comment: PMiniflacVorbisCommentT; br: PMiniflacBitreaderT; output: PAnsiChar; length: TUint32T; outlen: PUint32T): TMINIFLACRESULT; inline;
label _sw67_end, _sw68_case0, _sw69_case1, _sw70_default;
var
  r_2: TMINIFLACRESULT;
  c_2: AnsiChar;
  __c2p_tmp1: LongInt;
  __c2p_tmp2: LongWord;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
  __c2p_tmp1 := vorbis_comment^.state;
  if (__c2p_tmp1 = MINIFLAC_VORBISCOMMENT_VENDOR_LENGTH) then
  begin
    goto _sw68_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_VORBISCOMMENT_VENDOR_STRING) then
  begin
    goto _sw69_case1;
  end;
  goto _sw70_default;
  _sw68_case0:
  r_2 := TMINIFLACRESULT(miniflac_vorbis_comment_read_vendor_length(vorbis_comment, br, PUint32T(Pointer(0))));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _sw69_case1;
  _sw69_case1:
  while (vorbis_comment^.pos < vorbis_comment^.len) do
  begin
    if (miniflac_bitreader_fill_nocrc(br, TUint8T(8)) <> 0) then
    begin
      Result := MINIFLAC_CONTINUE;
      System.Exit;
    end;
    c_2 := AnsiChar(miniflac_bitreader_read(br, TUint8T(8)));
    if ((output <> nil) and (vorbis_comment^.pos < length)) then
    begin
      output[vorbis_comment^.pos] := AnsiChar(c_2);
    end;
    vorbis_comment^.pos := (vorbis_comment^.pos + 1);
  end;
  if (outlen <> nil) then
  begin
    if (vorbis_comment^.len <= length) then
    begin
      __c2p_tmp2 := vorbis_comment^.len;
    end
    else
    begin
      __c2p_tmp2 := length;
    end;
    outlen^ := __c2p_tmp2;
  end;
  vorbis_comment^.state := MINIFLAC_VORBISCOMMENT_TOTAL_COMMENTS;
  Result := MINIFLAC_OK;
  System.Exit;
  _sw70_default:
  goto _sw67_end;
  _sw67_end:
  Result := MINIFLAC_ERROR;
end;

function miniflac_vorbis_comment_read_total(vorbis_comment: PMiniflacVorbisCommentT; br: PMiniflacBitreaderT; total: PUint32T): TMINIFLACRESULT;
label _sw71_end, _sw72_case0, _sw73_case1, _sw74_case2, _sw75_default;
var
  buffer: array[0..3] of TUint8T;
  r_2: TMINIFLACRESULT;
  __c2p_tmp1: LongInt;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
  __c2p_tmp1 := vorbis_comment^.state;
  if (__c2p_tmp1 = MINIFLAC_VORBISCOMMENT_VENDOR_LENGTH) then
  begin
    goto _sw72_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_VORBISCOMMENT_VENDOR_STRING) then
  begin
    goto _sw73_case1;
  end;
  if (__c2p_tmp1 = MINIFLAC_VORBISCOMMENT_TOTAL_COMMENTS) then
  begin
    goto _sw74_case2;
  end;
  goto _sw75_default;
  _sw72_case0:
  goto _sw73_case1;
  _sw73_case1:
  r_2 := TMINIFLACRESULT(miniflac_vorbis_comment_read_vendor_string(vorbis_comment, br, PAnsiChar(Pointer(0)), TUint32T(0), PUint32T(Pointer(0))));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _sw74_case2;
  _sw74_case2:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(32)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  buffer[0] := TUint8T(miniflac_bitreader_read(br, TUint8T(8)));
  buffer[1] := TUint8T(miniflac_bitreader_read(br, TUint8T(8)));
  buffer[2] := TUint8T(miniflac_bitreader_read(br, TUint8T(8)));
  buffer[3] := TUint8T(miniflac_bitreader_read(br, TUint8T(8)));
  vorbis_comment^.tot := miniflac_unpack_uint32le(PUint8T(@buffer[0]));
  if (total <> nil) then
  begin
    total^ := vorbis_comment^.tot;
  end;
  vorbis_comment^.state := MINIFLAC_VORBISCOMMENT_COMMENT_LENGTH;
  Result := MINIFLAC_OK;
  System.Exit;
  _sw75_default:
  goto _sw71_end;
  _sw71_end:
  Result := MINIFLAC_ERROR;
end;

function miniflac_vorbis_comment_read_length(vorbis_comment: PMiniflacVorbisCommentT; br: PMiniflacBitreaderT; length: PUint32T): TMINIFLACRESULT;
label _L_case_miniflac_vorbis_comment_comment_length, _sw76_end, _sw77_case0, _sw78_case1, _sw79_case2, _sw80_case3, _sw81_case4, _sw82_default;
var
  buffer: array[0..3] of TUint8T;
  r_2: TMINIFLACRESULT;
  __c2p_tmp1: LongInt;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
  __c2p_tmp1 := vorbis_comment^.state;
  if (__c2p_tmp1 = MINIFLAC_VORBISCOMMENT_VENDOR_LENGTH) then
  begin
    goto _sw77_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_VORBISCOMMENT_VENDOR_STRING) then
  begin
    goto _sw78_case1;
  end;
  if (__c2p_tmp1 = MINIFLAC_VORBISCOMMENT_TOTAL_COMMENTS) then
  begin
    goto _sw79_case2;
  end;
  if (__c2p_tmp1 = MINIFLAC_VORBISCOMMENT_COMMENT_LENGTH) then
  begin
    goto _sw80_case3;
  end;
  if (__c2p_tmp1 = MINIFLAC_VORBISCOMMENT_COMMENT_STRING) then
  begin
    goto _sw81_case4;
  end;
  goto _sw82_default;
  _sw77_case0:
  goto _sw78_case1;
  _sw78_case1:
  goto _sw79_case2;
  _sw79_case2:
  r_2 := TMINIFLACRESULT(miniflac_vorbis_comment_read_total(vorbis_comment, br, PUint32T(Pointer(0))));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _sw80_case3;
  _sw80_case3:
  _L_case_miniflac_vorbis_comment_comment_length:
  if (vorbis_comment^.cur = vorbis_comment^.tot) then
  begin
    Result := MINIFLAC_METADATA_END;
    System.Exit;
  end;
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(32)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  buffer[0] := TUint8T(miniflac_bitreader_read(br, TUint8T(8)));
  buffer[1] := TUint8T(miniflac_bitreader_read(br, TUint8T(8)));
  buffer[2] := TUint8T(miniflac_bitreader_read(br, TUint8T(8)));
  buffer[3] := TUint8T(miniflac_bitreader_read(br, TUint8T(8)));
  vorbis_comment^.len := miniflac_unpack_uint32le(PUint8T(@buffer[0]));
  vorbis_comment^.pos := TUint32T(0);
  if (length <> nil) then
  begin
    length^ := vorbis_comment^.len;
  end;
  vorbis_comment^.state := MINIFLAC_VORBISCOMMENT_COMMENT_STRING;
  Result := MINIFLAC_OK;
  System.Exit;
  _sw81_case4:
  r_2 := TMINIFLACRESULT(miniflac_vorbis_comment_read_string(vorbis_comment, br, PAnsiChar(Pointer(0)), TUint32T(0), PUint32T(Pointer(0))));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _L_case_miniflac_vorbis_comment_comment_length;
  _sw82_default:
  goto _sw76_end;
  _sw76_end:
  Result := MINIFLAC_ERROR;
end;

function miniflac_vorbis_comment_read_string(vorbis_comment: PMiniflacVorbisCommentT; br: PMiniflacBitreaderT; output: PAnsiChar; length: TUint32T; outlen: PUint32T): TMINIFLACRESULT;
label _sw83_end, _sw84_case0, _sw85_case1, _sw86_case2, _sw87_case3, _sw88_case4, _sw89_default;
var
  r_2: TMINIFLACRESULT;
  c_2: AnsiChar;
  __c2p_tmp1: LongInt;
  __c2p_tmp2: LongWord;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
  __c2p_tmp1 := vorbis_comment^.state;
  if (__c2p_tmp1 = MINIFLAC_VORBISCOMMENT_VENDOR_LENGTH) then
  begin
    goto _sw84_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_VORBISCOMMENT_VENDOR_STRING) then
  begin
    goto _sw85_case1;
  end;
  if (__c2p_tmp1 = MINIFLAC_VORBISCOMMENT_TOTAL_COMMENTS) then
  begin
    goto _sw86_case2;
  end;
  if (__c2p_tmp1 = MINIFLAC_VORBISCOMMENT_COMMENT_LENGTH) then
  begin
    goto _sw87_case3;
  end;
  if (__c2p_tmp1 = MINIFLAC_VORBISCOMMENT_COMMENT_STRING) then
  begin
    goto _sw88_case4;
  end;
  goto _sw89_default;
  _sw84_case0:
  goto _sw85_case1;
  _sw85_case1:
  goto _sw86_case2;
  _sw86_case2:
  goto _sw87_case3;
  _sw87_case3:
  r_2 := TMINIFLACRESULT(miniflac_vorbis_comment_read_length(vorbis_comment, br, PUint32T(Pointer(0))));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _sw88_case4;
  _sw88_case4:
  while (vorbis_comment^.pos < vorbis_comment^.len) do
  begin
    if (miniflac_bitreader_fill_nocrc(br, TUint8T(8)) <> 0) then
    begin
      Result := MINIFLAC_CONTINUE;
      System.Exit;
    end;
    c_2 := AnsiChar(miniflac_bitreader_read(br, TUint8T(8)));
    if ((output <> nil) and (vorbis_comment^.pos < length)) then
    begin
      output[vorbis_comment^.pos] := AnsiChar(c_2);
    end;
    vorbis_comment^.pos := (vorbis_comment^.pos + 1);
  end;
  if (outlen <> nil) then
  begin
    if (vorbis_comment^.len <= length) then
    begin
      __c2p_tmp2 := vorbis_comment^.len;
    end
    else
    begin
      __c2p_tmp2 := length;
    end;
    outlen^ := __c2p_tmp2;
  end;
  vorbis_comment^.cur := (vorbis_comment^.cur + 1);
  vorbis_comment^.state := MINIFLAC_VORBISCOMMENT_COMMENT_LENGTH;
  Result := MINIFLAC_OK;
  System.Exit;
  _sw89_default:
  goto _sw83_end;
  _sw83_end:
  Result := MINIFLAC_ERROR;
end;

procedure miniflac_picture_init(picture: PMiniflacPictureT); inline;
begin
  picture^.state := MINIFLAC_PICTURE_TYPE_CONST;
  picture^.len := TUint32T(0);
  picture^.pos := TUint32T(0);
end;

function miniflac_picture_read_type(picture: PMiniflacPictureT; br: PMiniflacBitreaderT; &type: PUint32T): TMINIFLACRESULT; inline;
label _sw90_end;
var
  t_2: TUint32T;
  __c2p_tmp1: LongInt;
begin
  t_2 := TUint32T(0);
  __c2p_tmp1 := picture^.state;
  case __c2p_tmp1 of
    MINIFLAC_PICTURE_TYPE_CONST:
    begin
      if (miniflac_bitreader_fill_nocrc(br, TUint8T(32)) <> 0) then
      begin
        Result := MINIFLAC_CONTINUE;
        System.Exit;
      end;
      t_2 := TUint32T(miniflac_bitreader_read(br, TUint8T(32)));
      if (&type <> nil) then
      begin
        &type^ := t_2;
      end;
      picture^.state := MINIFLAC_PICTURE_MIME_LENGTH_CONST;
      Result := MINIFLAC_OK;
      System.Exit;
    end;
  else
  begin
    goto _sw90_end;
  end
  end;
  _sw90_end:
  Result := MINIFLAC_ERROR;
end;

function miniflac_picture_read_mime_length(picture: PMiniflacPictureT; br: PMiniflacBitreaderT; length: PUint32T): TMINIFLACRESULT; inline;
label _sw91_end, _sw92_case0, _sw93_case1, _sw94_default;
var
  r_2: TMINIFLACRESULT;
  __c2p_tmp1: LongInt;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
  __c2p_tmp1 := picture^.state;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_TYPE_CONST) then
  begin
    goto _sw92_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_MIME_LENGTH_CONST) then
  begin
    goto _sw93_case1;
  end;
  goto _sw94_default;
  _sw92_case0:
  r_2 := TMINIFLACRESULT(miniflac_picture_read_type(picture, br, PUint32T(Pointer(0))));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _sw93_case1;
  _sw93_case1:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(32)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  picture^.len := TUint32T(miniflac_bitreader_read(br, TUint8T(32)));
  picture^.pos := TUint32T(0);
  if (length <> nil) then
  begin
    length^ := picture^.len;
  end;
  picture^.state := MINIFLAC_PICTURE_MIME_STRING_CONST;
  Result := MINIFLAC_OK;
  System.Exit;
  _sw94_default:
  goto _sw91_end;
  _sw91_end:
  Result := MINIFLAC_ERROR;
end;

function miniflac_picture_read_mime_string(picture: PMiniflacPictureT; br: PMiniflacBitreaderT; output: PAnsiChar; length: TUint32T; outlen: PUint32T): TMINIFLACRESULT; inline;
label _sw95_end, _sw96_case0, _sw97_case1, _sw98_case2, _sw99_default;
var
  r_2: TMINIFLACRESULT;
  c_2: AnsiChar;
  __c2p_tmp1: LongInt;
  __c2p_tmp2: LongWord;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
  __c2p_tmp1 := picture^.state;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_TYPE_CONST) then
  begin
    goto _sw96_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_MIME_LENGTH_CONST) then
  begin
    goto _sw97_case1;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_MIME_STRING_CONST) then
  begin
    goto _sw98_case2;
  end;
  goto _sw99_default;
  _sw96_case0:
  goto _sw97_case1;
  _sw97_case1:
  r_2 := TMINIFLACRESULT(miniflac_picture_read_mime_length(picture, br, PUint32T(Pointer(0))));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _sw98_case2;
  _sw98_case2:
  while (picture^.pos < picture^.len) do
  begin
    if (miniflac_bitreader_fill_nocrc(br, TUint8T(8)) <> 0) then
    begin
      Result := MINIFLAC_CONTINUE;
      System.Exit;
    end;
    c_2 := AnsiChar(miniflac_bitreader_read(br, TUint8T(8)));
    if ((output <> nil) and (picture^.pos < length)) then
    begin
      output[picture^.pos] := AnsiChar(c_2);
    end;
    picture^.pos := (picture^.pos + 1);
  end;
  if (outlen <> nil) then
  begin
    if (picture^.len <= length) then
    begin
      __c2p_tmp2 := picture^.len;
    end
    else
    begin
      __c2p_tmp2 := length;
    end;
    outlen^ := __c2p_tmp2;
  end;
  picture^.state := MINIFLAC_PICTURE_DESCRIPTION_LENGTH_CONST;
  Result := MINIFLAC_OK;
  System.Exit;
  _sw99_default:
  goto _sw95_end;
  _sw95_end:
  Result := MINIFLAC_ERROR;
end;

function miniflac_picture_read_description_length(picture: PMiniflacPictureT; br: PMiniflacBitreaderT; length: PUint32T): TMINIFLACRESULT;
label _sw100_end, _sw101_case0, _sw102_case1, _sw103_case2, _sw104_case3, _sw105_default;
var
  r_2: TMINIFLACRESULT;
  __c2p_tmp1: LongInt;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
  __c2p_tmp1 := picture^.state;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_TYPE_CONST) then
  begin
    goto _sw101_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_MIME_LENGTH_CONST) then
  begin
    goto _sw102_case1;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_MIME_STRING_CONST) then
  begin
    goto _sw103_case2;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_DESCRIPTION_LENGTH_CONST) then
  begin
    goto _sw104_case3;
  end;
  goto _sw105_default;
  _sw101_case0:
  goto _sw102_case1;
  _sw102_case1:
  goto _sw103_case2;
  _sw103_case2:
  r_2 := TMINIFLACRESULT(miniflac_picture_read_mime_string(picture, br, PAnsiChar(Pointer(0)), TUint32T(0), PUint32T(Pointer(0))));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _sw104_case3;
  _sw104_case3:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(32)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  picture^.len := TUint32T(miniflac_bitreader_read(br, TUint8T(32)));
  picture^.pos := TUint32T(0);
  if (length <> nil) then
  begin
    length^ := picture^.len;
  end;
  picture^.state := MINIFLAC_PICTURE_DESCRIPTION_STRING_CONST;
  Result := MINIFLAC_OK;
  System.Exit;
  _sw105_default:
  goto _sw100_end;
  _sw100_end:
  Result := MINIFLAC_ERROR;
end;

function miniflac_picture_read_description_string(picture: PMiniflacPictureT; br: PMiniflacBitreaderT; output: PAnsiChar; length: TUint32T; outlen: PUint32T): TMINIFLACRESULT;
label _sw106_end, _sw107_case0, _sw108_case1, _sw109_case2, _sw110_case3, _sw111_case4, _sw112_default;
var
  r_2: TMINIFLACRESULT;
  c_2: AnsiChar;
  __c2p_tmp1: LongInt;
  __c2p_tmp2: LongWord;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
  __c2p_tmp1 := picture^.state;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_TYPE_CONST) then
  begin
    goto _sw107_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_MIME_LENGTH_CONST) then
  begin
    goto _sw108_case1;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_MIME_STRING_CONST) then
  begin
    goto _sw109_case2;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_DESCRIPTION_LENGTH_CONST) then
  begin
    goto _sw110_case3;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_DESCRIPTION_STRING_CONST) then
  begin
    goto _sw111_case4;
  end;
  goto _sw112_default;
  _sw107_case0:
  goto _sw108_case1;
  _sw108_case1:
  goto _sw109_case2;
  _sw109_case2:
  goto _sw110_case3;
  _sw110_case3:
  r_2 := TMINIFLACRESULT(miniflac_picture_read_description_length(picture, br, PUint32T(Pointer(0))));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _sw111_case4;
  _sw111_case4:
  while (picture^.pos < picture^.len) do
  begin
    if (miniflac_bitreader_fill_nocrc(br, TUint8T(8)) <> 0) then
    begin
      Result := MINIFLAC_CONTINUE;
      System.Exit;
    end;
    c_2 := AnsiChar(miniflac_bitreader_read(br, TUint8T(8)));
    if ((output <> nil) and (picture^.pos < length)) then
    begin
      output[picture^.pos] := AnsiChar(c_2);
    end;
    picture^.pos := (picture^.pos + 1);
  end;
  if (outlen <> nil) then
  begin
    if (picture^.len <= length) then
    begin
      __c2p_tmp2 := picture^.len;
    end
    else
    begin
      __c2p_tmp2 := length;
    end;
    outlen^ := __c2p_tmp2;
  end;
  picture^.state := MINIFLAC_PICTURE_WIDTH_CONST;
  Result := MINIFLAC_OK;
  System.Exit;
  _sw112_default:
  goto _sw106_end;
  _sw106_end:
  Result := MINIFLAC_ERROR;
end;

function miniflac_picture_read_width(picture: PMiniflacPictureT; br: PMiniflacBitreaderT; width: PUint32T): TMINIFLACRESULT;
label _sw113_end, _sw114_case0, _sw115_case1, _sw116_case2, _sw117_case3, _sw118_case4, _sw119_case5, _sw120_default;
var
  t_2: TUint32T;
  r_2: TMINIFLACRESULT;
  __c2p_tmp1: LongInt;
begin
  t_2 := TUint32T(0);
  r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
  __c2p_tmp1 := picture^.state;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_TYPE_CONST) then
  begin
    goto _sw114_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_MIME_LENGTH_CONST) then
  begin
    goto _sw115_case1;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_MIME_STRING_CONST) then
  begin
    goto _sw116_case2;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_DESCRIPTION_LENGTH_CONST) then
  begin
    goto _sw117_case3;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_DESCRIPTION_STRING_CONST) then
  begin
    goto _sw118_case4;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_WIDTH_CONST) then
  begin
    goto _sw119_case5;
  end;
  goto _sw120_default;
  _sw114_case0:
  goto _sw115_case1;
  _sw115_case1:
  goto _sw116_case2;
  _sw116_case2:
  goto _sw117_case3;
  _sw117_case3:
  goto _sw118_case4;
  _sw118_case4:
  r_2 := TMINIFLACRESULT(miniflac_picture_read_description_string(picture, br, PAnsiChar(Pointer(0)), TUint32T(0), PUint32T(Pointer(0))));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _sw119_case5;
  _sw119_case5:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(32)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  t_2 := TUint32T(miniflac_bitreader_read(br, TUint8T(32)));
  if (width <> nil) then
  begin
    width^ := t_2;
  end;
  picture^.state := MINIFLAC_PICTURE_HEIGHT_CONST;
  Result := MINIFLAC_OK;
  System.Exit;
  _sw120_default:
  goto _sw113_end;
  _sw113_end:
  Result := MINIFLAC_ERROR;
end;

function miniflac_picture_read_height(picture: PMiniflacPictureT; br: PMiniflacBitreaderT; height: PUint32T): TMINIFLACRESULT;
label _sw121_end, _sw122_case0, _sw123_case1, _sw124_case2, _sw125_case3, _sw126_case4, _sw127_case5, _sw128_case6, _sw129_default;
var
  t_2: TUint32T;
  r_2: TMINIFLACRESULT;
  __c2p_tmp1: LongInt;
begin
  t_2 := TUint32T(0);
  r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
  __c2p_tmp1 := picture^.state;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_TYPE_CONST) then
  begin
    goto _sw122_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_MIME_LENGTH_CONST) then
  begin
    goto _sw123_case1;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_MIME_STRING_CONST) then
  begin
    goto _sw124_case2;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_DESCRIPTION_LENGTH_CONST) then
  begin
    goto _sw125_case3;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_DESCRIPTION_STRING_CONST) then
  begin
    goto _sw126_case4;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_WIDTH_CONST) then
  begin
    goto _sw127_case5;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_HEIGHT_CONST) then
  begin
    goto _sw128_case6;
  end;
  goto _sw129_default;
  _sw122_case0:
  goto _sw123_case1;
  _sw123_case1:
  goto _sw124_case2;
  _sw124_case2:
  goto _sw125_case3;
  _sw125_case3:
  goto _sw126_case4;
  _sw126_case4:
  goto _sw127_case5;
  _sw127_case5:
  r_2 := TMINIFLACRESULT(miniflac_picture_read_width(picture, br, PUint32T(Pointer(0))));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _sw128_case6;
  _sw128_case6:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(32)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  t_2 := TUint32T(miniflac_bitreader_read(br, TUint8T(32)));
  if (height <> nil) then
  begin
    height^ := t_2;
  end;
  picture^.state := MINIFLAC_PICTURE_COLORDEPTH_CONST;
  Result := MINIFLAC_OK;
  System.Exit;
  _sw129_default:
  goto _sw121_end;
  _sw121_end:
  Result := MINIFLAC_ERROR;
end;

function miniflac_picture_read_colordepth(picture: PMiniflacPictureT; br: PMiniflacBitreaderT; colordepth: PUint32T): TMINIFLACRESULT;
label _sw130_end, _sw131_case0, _sw132_case1, _sw133_case2, _sw134_case3, _sw135_case4, _sw136_case5, _sw137_case6, _sw138_case7, _sw139_default;
var
  t_2: TUint32T;
  r_2: TMINIFLACRESULT;
  __c2p_tmp1: LongInt;
begin
  t_2 := TUint32T(0);
  r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
  __c2p_tmp1 := picture^.state;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_TYPE_CONST) then
  begin
    goto _sw131_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_MIME_LENGTH_CONST) then
  begin
    goto _sw132_case1;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_MIME_STRING_CONST) then
  begin
    goto _sw133_case2;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_DESCRIPTION_LENGTH_CONST) then
  begin
    goto _sw134_case3;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_DESCRIPTION_STRING_CONST) then
  begin
    goto _sw135_case4;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_WIDTH_CONST) then
  begin
    goto _sw136_case5;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_HEIGHT_CONST) then
  begin
    goto _sw137_case6;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_COLORDEPTH_CONST) then
  begin
    goto _sw138_case7;
  end;
  goto _sw139_default;
  _sw131_case0:
  goto _sw132_case1;
  _sw132_case1:
  goto _sw133_case2;
  _sw133_case2:
  goto _sw134_case3;
  _sw134_case3:
  goto _sw135_case4;
  _sw135_case4:
  goto _sw136_case5;
  _sw136_case5:
  goto _sw137_case6;
  _sw137_case6:
  r_2 := TMINIFLACRESULT(miniflac_picture_read_height(picture, br, PUint32T(Pointer(0))));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _sw138_case7;
  _sw138_case7:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(32)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  t_2 := TUint32T(miniflac_bitreader_read(br, TUint8T(32)));
  if (colordepth <> nil) then
  begin
    colordepth^ := t_2;
  end;
  picture^.state := MINIFLAC_PICTURE_TOTALCOLORS_CONST;
  Result := MINIFLAC_OK;
  System.Exit;
  _sw139_default:
  goto _sw130_end;
  _sw130_end:
  Result := MINIFLAC_ERROR;
end;

function miniflac_picture_read_totalcolors(picture: PMiniflacPictureT; br: PMiniflacBitreaderT; totalcolors: PUint32T): TMINIFLACRESULT;
label _sw140_end, _sw141_case0, _sw142_case1, _sw143_case2, _sw144_case3, _sw145_case4, _sw146_case5, _sw147_case6, _sw148_case7, _sw149_case8, _sw150_default;
var
  t_2: TUint32T;
  r_2: TMINIFLACRESULT;
  __c2p_tmp1: LongInt;
begin
  t_2 := TUint32T(0);
  r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
  __c2p_tmp1 := picture^.state;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_TYPE_CONST) then
  begin
    goto _sw141_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_MIME_LENGTH_CONST) then
  begin
    goto _sw142_case1;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_MIME_STRING_CONST) then
  begin
    goto _sw143_case2;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_DESCRIPTION_LENGTH_CONST) then
  begin
    goto _sw144_case3;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_DESCRIPTION_STRING_CONST) then
  begin
    goto _sw145_case4;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_WIDTH_CONST) then
  begin
    goto _sw146_case5;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_HEIGHT_CONST) then
  begin
    goto _sw147_case6;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_COLORDEPTH_CONST) then
  begin
    goto _sw148_case7;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_TOTALCOLORS_CONST) then
  begin
    goto _sw149_case8;
  end;
  goto _sw150_default;
  _sw141_case0:
  goto _sw142_case1;
  _sw142_case1:
  goto _sw143_case2;
  _sw143_case2:
  goto _sw144_case3;
  _sw144_case3:
  goto _sw145_case4;
  _sw145_case4:
  goto _sw146_case5;
  _sw146_case5:
  goto _sw147_case6;
  _sw147_case6:
  goto _sw148_case7;
  _sw148_case7:
  r_2 := TMINIFLACRESULT(miniflac_picture_read_colordepth(picture, br, PUint32T(Pointer(0))));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _sw149_case8;
  _sw149_case8:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(32)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  t_2 := TUint32T(miniflac_bitreader_read(br, TUint8T(32)));
  if (totalcolors <> nil) then
  begin
    totalcolors^ := t_2;
  end;
  picture^.state := MINIFLAC_PICTURE_PICTURE_LENGTH;
  Result := MINIFLAC_OK;
  System.Exit;
  _sw150_default:
  goto _sw140_end;
  _sw140_end:
  Result := MINIFLAC_ERROR;
end;

function miniflac_picture_read_length(picture: PMiniflacPictureT; br: PMiniflacBitreaderT; length: PUint32T): TMINIFLACRESULT;
label _sw151_end, _sw152_case0, _sw153_case1, _sw154_case2, _sw155_case3, _sw156_case4, _sw157_case5, _sw158_case6, _sw159_case7, _sw160_case8, _sw161_case9, _sw162_default;
var
  r_2: TMINIFLACRESULT;
  __c2p_tmp1: LongInt;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
  __c2p_tmp1 := picture^.state;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_TYPE_CONST) then
  begin
    goto _sw152_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_MIME_LENGTH_CONST) then
  begin
    goto _sw153_case1;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_MIME_STRING_CONST) then
  begin
    goto _sw154_case2;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_DESCRIPTION_LENGTH_CONST) then
  begin
    goto _sw155_case3;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_DESCRIPTION_STRING_CONST) then
  begin
    goto _sw156_case4;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_WIDTH_CONST) then
  begin
    goto _sw157_case5;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_HEIGHT_CONST) then
  begin
    goto _sw158_case6;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_COLORDEPTH_CONST) then
  begin
    goto _sw159_case7;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_TOTALCOLORS_CONST) then
  begin
    goto _sw160_case8;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_PICTURE_LENGTH) then
  begin
    goto _sw161_case9;
  end;
  goto _sw162_default;
  _sw152_case0:
  goto _sw153_case1;
  _sw153_case1:
  goto _sw154_case2;
  _sw154_case2:
  goto _sw155_case3;
  _sw155_case3:
  goto _sw156_case4;
  _sw156_case4:
  goto _sw157_case5;
  _sw157_case5:
  goto _sw158_case6;
  _sw158_case6:
  goto _sw159_case7;
  _sw159_case7:
  goto _sw160_case8;
  _sw160_case8:
  r_2 := TMINIFLACRESULT(miniflac_picture_read_totalcolors(picture, br, PUint32T(Pointer(0))));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _sw161_case9;
  _sw161_case9:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(32)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  picture^.len := TUint32T(miniflac_bitreader_read(br, TUint8T(32)));
  picture^.pos := TUint32T(0);
  if (length <> nil) then
  begin
    length^ := picture^.len;
  end;
  picture^.state := MINIFLAC_PICTURE_PICTURE_DATA;
  Result := MINIFLAC_OK;
  System.Exit;
  _sw162_default:
  goto _sw151_end;
  _sw151_end:
  Result := MINIFLAC_ERROR;
end;

function miniflac_picture_read_data(picture: PMiniflacPictureT; br: PMiniflacBitreaderT; output: PUint8T; length: TUint32T; outlen: PUint32T): TMINIFLACRESULT;
label _sw163_end, _sw164_case0, _sw165_case1, _sw166_case2, _sw167_case3, _sw168_case4, _sw169_case5, _sw170_case6, _sw171_case7, _sw172_case8, _sw173_case9, _sw174_case10, _sw175_default;
var
  r_2: TMINIFLACRESULT;
  c_2: TUint8T;
  __c2p_tmp1: LongInt;
  __c2p_tmp2: LongWord;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
  __c2p_tmp1 := picture^.state;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_TYPE_CONST) then
  begin
    goto _sw164_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_MIME_LENGTH_CONST) then
  begin
    goto _sw165_case1;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_MIME_STRING_CONST) then
  begin
    goto _sw166_case2;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_DESCRIPTION_LENGTH_CONST) then
  begin
    goto _sw167_case3;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_DESCRIPTION_STRING_CONST) then
  begin
    goto _sw168_case4;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_WIDTH_CONST) then
  begin
    goto _sw169_case5;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_HEIGHT_CONST) then
  begin
    goto _sw170_case6;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_COLORDEPTH_CONST) then
  begin
    goto _sw171_case7;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_TOTALCOLORS_CONST) then
  begin
    goto _sw172_case8;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_PICTURE_LENGTH) then
  begin
    goto _sw173_case9;
  end;
  if (__c2p_tmp1 = MINIFLAC_PICTURE_PICTURE_DATA) then
  begin
    goto _sw174_case10;
  end;
  goto _sw175_default;
  _sw164_case0:
  goto _sw165_case1;
  _sw165_case1:
  goto _sw166_case2;
  _sw166_case2:
  goto _sw167_case3;
  _sw167_case3:
  goto _sw168_case4;
  _sw168_case4:
  goto _sw169_case5;
  _sw169_case5:
  goto _sw170_case6;
  _sw170_case6:
  goto _sw171_case7;
  _sw171_case7:
  goto _sw172_case8;
  _sw172_case8:
  goto _sw173_case9;
  _sw173_case9:
  r_2 := TMINIFLACRESULT(miniflac_picture_read_length(picture, br, PUint32T(Pointer(0))));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _sw174_case10;
  _sw174_case10:
  if (picture^.pos = picture^.len) then
  begin
    Result := MINIFLAC_METADATA_END;
    System.Exit;
  end;
  while (picture^.pos < picture^.len) do
  begin
    if (miniflac_bitreader_fill_nocrc(br, TUint8T(8)) <> 0) then
    begin
      Result := MINIFLAC_CONTINUE;
      System.Exit;
    end;
    c_2 := TUint8T(miniflac_bitreader_read(br, TUint8T(8)));
    if ((output <> nil) and (picture^.pos < length)) then
    begin
      output[picture^.pos] := TUint8T(c_2);
    end;
    picture^.pos := (picture^.pos + 1);
  end;
  if (outlen <> nil) then
  begin
    if (picture^.len <= length) then
    begin
      __c2p_tmp2 := picture^.len;
    end
    else
    begin
      __c2p_tmp2 := length;
    end;
    outlen^ := __c2p_tmp2;
  end;
  Result := MINIFLAC_OK;
  System.Exit;
  _sw175_default:
  goto _sw163_end;
  _sw163_end:
  Result := MINIFLAC_ERROR;
end;

procedure miniflac_cuesheet_init(cuesheet: PMiniflacCuesheetT); inline;
begin
  cuesheet^.state := MINIFLAC_CUESHEET_CATALOG;
  cuesheet^.pos := TUint32T(0);
  cuesheet^.track := TUint8T(0);
  cuesheet^.tracks := TUint8T(0);
  cuesheet^.point := TUint8T(0);
  cuesheet^.points := TUint8T(0);
end;

function miniflac_cuesheet_read_catalog_length(cuesheet: PMiniflacCuesheetT; br: PMiniflacBitreaderT; catalog_length: PUint32T): TMINIFLACRESULT; inline;
label _sw176_end;
var
  __c2p_tmp1: LongInt;
begin
  __c2p_tmp1 := cuesheet^.state;
  case __c2p_tmp1 of
    MINIFLAC_CUESHEET_CATALOG:
    begin
      if (catalog_length <> nil) then
      begin
        catalog_length^ := TUint32T(128);
      end;
      Result := MINIFLAC_OK;
      System.Exit;
    end;
  else
  begin
    goto _sw176_end;
  end
  end;
  _sw176_end:
  Result := MINIFLAC_ERROR;
end;

function miniflac_cuesheet_read_catalog_string(cuesheet: PMiniflacCuesheetT; br: PMiniflacBitreaderT; output: PAnsiChar; length: TUint32T; outlen: PUint32T): TMINIFLACRESULT; inline;
label _sw177_end;
var
  __c2p_tmp1: LongInt;
  __c2p_case_overlay_1: T__c2p_case_overlay_1;
begin
  __c2p_tmp1 := cuesheet^.state;
  case __c2p_tmp1 of
    MINIFLAC_CUESHEET_CATALOG:
    begin
      while (cuesheet^.pos < LongWord(128)) do
      begin
        if (miniflac_bitreader_fill_nocrc(br, TUint8T(8)) <> 0) then
        begin
          Result := MINIFLAC_CONTINUE;
          System.Exit;
        end;
        __c2p_case_overlay_1.c_2 := AnsiChar(miniflac_bitreader_read(br, TUint8T(8)));
        if ((output <> nil) and (cuesheet^.pos < length)) then
        begin
          output[cuesheet^.pos] := AnsiChar(__c2p_case_overlay_1.c_2);
        end;
        cuesheet^.pos := (cuesheet^.pos + 1);
      end;
      if (outlen <> nil) then
      begin
        if (cuesheet^.pos < length) then
        begin
          __c2p_case_overlay_1.__c2p_tmp2 := cuesheet^.pos;
        end
        else
        begin
          __c2p_case_overlay_1.__c2p_tmp2 := length;
        end;
        outlen^ := __c2p_case_overlay_1.__c2p_tmp2;
      end;
      cuesheet^.pos := TUint32T(0);
      cuesheet^.state := MINIFLAC_CUESHEET_LEADIN_CONST;
      Result := MINIFLAC_OK;
      System.Exit;
    end;
  else
  begin
    goto _sw177_end;
  end
  end;
  _sw177_end:
  Result := MINIFLAC_ERROR;
end;

function miniflac_cuesheet_read_leadin(cuesheet: PMiniflacCuesheetT; br: PMiniflacBitreaderT; leadin: PUint64T): TMINIFLACRESULT; inline;
label _sw178_end, _sw179_case0, _sw180_case1, _sw181_default;
var
  r_2: TMINIFLACRESULT;
  t_2: TUint64T;
  __c2p_tmp1: LongInt;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
  t_2 := TUint64T(0);
  __c2p_tmp1 := cuesheet^.state;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_CATALOG) then
  begin
    goto _sw179_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_LEADIN_CONST) then
  begin
    goto _sw180_case1;
  end;
  goto _sw181_default;
  _sw179_case0:
  r_2 := TMINIFLACRESULT(miniflac_cuesheet_read_catalog_string(cuesheet, br, PAnsiChar(Pointer(0)), TUint32T(0), PUint32T(Pointer(0))));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _sw180_case1;
  _sw180_case1:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(64)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  t_2 := miniflac_bitreader_read(br, TUint8T(64));
  if (leadin <> nil) then
  begin
    leadin^ := t_2;
  end;
  cuesheet^.state := MINIFLAC_CUESHEET_CDFLAG;
  Result := MINIFLAC_OK;
  System.Exit;
  _sw181_default:
  goto _sw178_end;
  _sw178_end:
  Result := MINIFLAC_ERROR;
end;

function miniflac_cuesheet_read_cd_flag(cuesheet: PMiniflacCuesheetT; br: PMiniflacBitreaderT; flag: PUint8T): TMINIFLACRESULT;
label _sw182_end, _sw183_case0, _sw184_case1, _sw185_case2, _sw186_default;
var
  r_2: TMINIFLACRESULT;
  f_2: TUint8T;
  __c2p_tmp1: LongInt;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
  f_2 := TUint8T(0);
  __c2p_tmp1 := cuesheet^.state;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_CATALOG) then
  begin
    goto _sw183_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_LEADIN_CONST) then
  begin
    goto _sw184_case1;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_CDFLAG) then
  begin
    goto _sw185_case2;
  end;
  goto _sw186_default;
  _sw183_case0:
  goto _sw184_case1;
  _sw184_case1:
  r_2 := TMINIFLACRESULT(miniflac_cuesheet_read_leadin(cuesheet, br, PUint64T(Pointer(0))));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _sw185_case2;
  _sw185_case2:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(1)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  f_2 := TUint8T(miniflac_bitreader_read(br, TUint8T(1)));
  if (flag <> nil) then
  begin
    flag^ := TUint8T(f_2);
  end;
  miniflac_bitreader_discard(br, TUint8T(7));
  cuesheet^.state := MINIFLAC_CUESHEET_SHEET_RESERVE;
  Result := MINIFLAC_OK;
  System.Exit;
  _sw186_default:
  goto _sw182_end;
  _sw182_end:
  Result := MINIFLAC_ERROR;
end;

function miniflac_cuesheet_read_tracks(cuesheet: PMiniflacCuesheetT; br: PMiniflacBitreaderT; tracks: PUint8T): TMINIFLACRESULT;
label _sw187_end, _sw188_case0, _sw189_case1, _sw190_case2, _sw191_case3, _sw192_case4, _sw193_default;
var
  r_2: TMINIFLACRESULT;
  __c2p_tmp1: LongInt;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
  __c2p_tmp1 := cuesheet^.state;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_CATALOG) then
  begin
    goto _sw188_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_LEADIN_CONST) then
  begin
    goto _sw189_case1;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_CDFLAG) then
  begin
    goto _sw190_case2;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_SHEET_RESERVE) then
  begin
    goto _sw191_case3;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKS_CONST) then
  begin
    goto _sw192_case4;
  end;
  goto _sw193_default;
  _sw188_case0:
  goto _sw189_case1;
  _sw189_case1:
  goto _sw190_case2;
  _sw190_case2:
  r_2 := TMINIFLACRESULT(miniflac_cuesheet_read_cd_flag(cuesheet, br, PUint8T(Pointer(0))));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _sw191_case3;
  _sw191_case3:
  while (cuesheet^.pos < LongWord(258)) do
  begin
    if (miniflac_bitreader_fill_nocrc(br, TUint8T(8)) <> 0) then
    begin
      Result := MINIFLAC_CONTINUE;
      System.Exit;
    end;
    miniflac_bitreader_discard(br, TUint8T(8));
    cuesheet^.pos := (cuesheet^.pos + 1);
  end;
  cuesheet^.pos := TUint32T(0);
  cuesheet^.state := MINIFLAC_CUESHEET_TRACKS_CONST;
  goto _sw192_case4;
  _sw192_case4:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(8)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  cuesheet^.tracks := TUint8T(miniflac_bitreader_read(br, TUint8T(8)));
  if (tracks <> nil) then
  begin
    tracks^ := TUint8T(cuesheet^.tracks);
  end;
  cuesheet^.track := TUint8T(0);
  cuesheet^.state := MINIFLAC_CUESHEET_TRACKOFFSET;
  Result := MINIFLAC_OK;
  System.Exit;
  _sw193_default:
  goto _sw187_end;
  _sw187_end:
  Result := MINIFLAC_ERROR;
end;

function miniflac_cuesheet_read_track_offset(cuesheet: PMiniflacCuesheetT; br: PMiniflacBitreaderT; track_offset: PUint64T): TMINIFLACRESULT;
label _L_case_miniflac_cuesheet_trackoffset, _sw194_end, _sw195_case0, _sw196_case1, _sw197_case2, _sw198_case3, _sw199_case4, _sw200_case5, _sw201_case6, _sw202_case7, _sw203_case8, _sw204_default;
var
  r_2: TMINIFLACRESULT;
  t_2: TUint64T;
  __c2p_tmp1: LongInt;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
  t_2 := TUint64T(0);
  __c2p_tmp1 := cuesheet^.state;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_CATALOG) then
  begin
    goto _sw195_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_LEADIN_CONST) then
  begin
    goto _sw196_case1;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_CDFLAG) then
  begin
    goto _sw197_case2;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_SHEET_RESERVE) then
  begin
    goto _sw198_case3;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKS_CONST) then
  begin
    goto _sw199_case4;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKOFFSET) then
  begin
    goto _sw200_case5;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_INDEX_OFFSET) then
  begin
    goto _sw201_case6;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_INDEX_NUMBER) then
  begin
    goto _sw202_case7;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_INDEX_RESERVE) then
  begin
    goto _sw203_case8;
  end;
  goto _sw204_default;
  _sw195_case0:
  goto _sw196_case1;
  _sw196_case1:
  goto _sw197_case2;
  _sw197_case2:
  goto _sw198_case3;
  _sw198_case3:
  goto _sw199_case4;
  _sw199_case4:
  r_2 := TMINIFLACRESULT(miniflac_cuesheet_read_tracks(cuesheet, br, PUint8T(Pointer(0))));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _sw200_case5;
  _sw200_case5:
  _L_case_miniflac_cuesheet_trackoffset:
  if (cuesheet^.track = cuesheet^.tracks) then
  begin
    Result := MINIFLAC_METADATA_END;
    System.Exit;
  end;
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(64)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  t_2 := miniflac_bitreader_read(br, TUint8T(64));
  if (track_offset <> nil) then
  begin
    track_offset^ := t_2;
  end;
  cuesheet^.state := MINIFLAC_CUESHEET_TRACKNUMBER;
  Result := MINIFLAC_OK;
  System.Exit;
  _sw201_case6:
  goto _sw202_case7;
  _sw202_case7:
  goto _sw203_case8;
  _sw203_case8:
  r_2 := TMINIFLACRESULT(miniflac_cuesheet_read_index_point_offset(cuesheet, br, PUint64T(Pointer(0))));
  if (LongInt(r_2) <> MINIFLAC_METADATA_END) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _L_case_miniflac_cuesheet_trackoffset;
  _sw204_default:
  goto _sw194_end;
  _sw194_end:
  Result := MINIFLAC_ERROR;
end;

function miniflac_cuesheet_read_track_number(cuesheet: PMiniflacCuesheetT; br: PMiniflacBitreaderT; track_number: PUint8T): TMINIFLACRESULT;
label _sw205_end, _sw206_case0, _sw207_case1, _sw208_case2, _sw209_case3, _sw210_case4, _sw211_case5, _sw212_case6, _sw213_default;
var
  r_2: TMINIFLACRESULT;
  t_2: TUint8T;
  __c2p_tmp1: LongInt;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
  t_2 := TUint8T(0);
  __c2p_tmp1 := cuesheet^.state;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_CATALOG) then
  begin
    goto _sw206_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_LEADIN_CONST) then
  begin
    goto _sw207_case1;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_CDFLAG) then
  begin
    goto _sw208_case2;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_SHEET_RESERVE) then
  begin
    goto _sw209_case3;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKS_CONST) then
  begin
    goto _sw210_case4;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKOFFSET) then
  begin
    goto _sw211_case5;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKNUMBER) then
  begin
    goto _sw212_case6;
  end;
  goto _sw213_default;
  _sw206_case0:
  goto _sw207_case1;
  _sw207_case1:
  goto _sw208_case2;
  _sw208_case2:
  goto _sw209_case3;
  _sw209_case3:
  goto _sw210_case4;
  _sw210_case4:
  goto _sw211_case5;
  _sw211_case5:
  r_2 := TMINIFLACRESULT(miniflac_cuesheet_read_track_offset(cuesheet, br, PUint64T(Pointer(0))));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _sw212_case6;
  _sw212_case6:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(8)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  t_2 := TUint8T(miniflac_bitreader_read(br, TUint8T(8)));
  if (track_number <> nil) then
  begin
    track_number^ := TUint8T(t_2);
  end;
  cuesheet^.pos := TUint32T(0);
  cuesheet^.state := MINIFLAC_CUESHEET_TRACKISRC;
  Result := MINIFLAC_OK;
  System.Exit;
  _sw213_default:
  goto _sw205_end;
  _sw205_end:
  Result := MINIFLAC_ERROR;
end;

function miniflac_cuesheet_read_track_isrc_length(cuesheet: PMiniflacCuesheetT; br: PMiniflacBitreaderT; isrc_length: PUint32T): TMINIFLACRESULT;
label _sw214_end, _sw215_case0, _sw216_case1, _sw217_case2, _sw218_case3, _sw219_case4, _sw220_case5, _sw221_case6, _sw222_case7, _sw223_default;
var
  r_2: TMINIFLACRESULT;
  __c2p_tmp1: LongInt;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
  __c2p_tmp1 := cuesheet^.state;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_CATALOG) then
  begin
    goto _sw215_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_LEADIN_CONST) then
  begin
    goto _sw216_case1;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_CDFLAG) then
  begin
    goto _sw217_case2;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_SHEET_RESERVE) then
  begin
    goto _sw218_case3;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKS_CONST) then
  begin
    goto _sw219_case4;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKOFFSET) then
  begin
    goto _sw220_case5;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKNUMBER) then
  begin
    goto _sw221_case6;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKISRC) then
  begin
    goto _sw222_case7;
  end;
  goto _sw223_default;
  _sw215_case0:
  goto _sw216_case1;
  _sw216_case1:
  goto _sw217_case2;
  _sw217_case2:
  goto _sw218_case3;
  _sw218_case3:
  goto _sw219_case4;
  _sw219_case4:
  goto _sw220_case5;
  _sw220_case5:
  goto _sw221_case6;
  _sw221_case6:
  r_2 := TMINIFLACRESULT(miniflac_cuesheet_read_track_number(cuesheet, br, PUint8T(Pointer(0))));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _sw222_case7;
  _sw222_case7:
  if (isrc_length <> nil) then
  begin
    isrc_length^ := TUint32T(12);
  end;
  Result := MINIFLAC_OK;
  System.Exit;
  _sw223_default:
  goto _sw214_end;
  _sw214_end:
  Result := MINIFLAC_ERROR;
end;

function miniflac_cuesheet_read_track_isrc_string(cuesheet: PMiniflacCuesheetT; br: PMiniflacBitreaderT; output: PAnsiChar; length: TUint32T; outlen: PUint32T): TMINIFLACRESULT;
label _sw224_end, _sw225_case0, _sw226_case1, _sw227_case2, _sw228_case3, _sw229_case4, _sw230_case5, _sw231_case6, _sw232_case7, _sw233_default;
var
  r_2: TMINIFLACRESULT;
  c_2: AnsiChar;
  __c2p_tmp1: LongInt;
  __c2p_tmp2: LongWord;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
  __c2p_tmp1 := cuesheet^.state;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_CATALOG) then
  begin
    goto _sw225_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_LEADIN_CONST) then
  begin
    goto _sw226_case1;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_CDFLAG) then
  begin
    goto _sw227_case2;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_SHEET_RESERVE) then
  begin
    goto _sw228_case3;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKS_CONST) then
  begin
    goto _sw229_case4;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKOFFSET) then
  begin
    goto _sw230_case5;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKNUMBER) then
  begin
    goto _sw231_case6;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKISRC) then
  begin
    goto _sw232_case7;
  end;
  goto _sw233_default;
  _sw225_case0:
  goto _sw226_case1;
  _sw226_case1:
  goto _sw227_case2;
  _sw227_case2:
  goto _sw228_case3;
  _sw228_case3:
  goto _sw229_case4;
  _sw229_case4:
  goto _sw230_case5;
  _sw230_case5:
  goto _sw231_case6;
  _sw231_case6:
  r_2 := TMINIFLACRESULT(miniflac_cuesheet_read_track_number(cuesheet, br, PUint8T(Pointer(0))));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _sw232_case7;
  _sw232_case7:
  while (cuesheet^.pos < LongWord(12)) do
  begin
    if (miniflac_bitreader_fill_nocrc(br, TUint8T(8)) <> 0) then
    begin
      Result := MINIFLAC_CONTINUE;
      System.Exit;
    end;
    c_2 := AnsiChar(miniflac_bitreader_read(br, TUint8T(8)));
    if ((output <> nil) and (cuesheet^.pos < length)) then
    begin
      output[cuesheet^.pos] := AnsiChar(c_2);
    end;
    cuesheet^.pos := (cuesheet^.pos + 1);
  end;
  if (outlen <> nil) then
  begin
    if (cuesheet^.pos < length) then
    begin
      __c2p_tmp2 := cuesheet^.pos;
    end
    else
    begin
      __c2p_tmp2 := length;
    end;
    outlen^ := __c2p_tmp2;
  end;
  cuesheet^.pos := TUint32T(0);
  cuesheet^.state := MINIFLAC_CUESHEET_TRACKTYPE;
  Result := MINIFLAC_OK;
  System.Exit;
  _sw233_default:
  goto _sw224_end;
  _sw224_end:
  Result := MINIFLAC_ERROR;
end;

function miniflac_cuesheet_read_track_audio_flag(cuesheet: PMiniflacCuesheetT; br: PMiniflacBitreaderT; track_audio_flag: PUint8T): TMINIFLACRESULT;
label _sw234_end, _sw235_case0, _sw236_case1, _sw237_case2, _sw238_case3, _sw239_case4, _sw240_case5, _sw241_case6, _sw242_case7, _sw243_case8, _sw244_default;
var
  r_2: TMINIFLACRESULT;
  f_2: TUint8T;
  __c2p_tmp1: LongInt;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
  f_2 := TUint8T(0);
  __c2p_tmp1 := cuesheet^.state;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_CATALOG) then
  begin
    goto _sw235_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_LEADIN_CONST) then
  begin
    goto _sw236_case1;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_CDFLAG) then
  begin
    goto _sw237_case2;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_SHEET_RESERVE) then
  begin
    goto _sw238_case3;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKS_CONST) then
  begin
    goto _sw239_case4;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKOFFSET) then
  begin
    goto _sw240_case5;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKNUMBER) then
  begin
    goto _sw241_case6;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKISRC) then
  begin
    goto _sw242_case7;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKTYPE) then
  begin
    goto _sw243_case8;
  end;
  goto _sw244_default;
  _sw235_case0:
  goto _sw236_case1;
  _sw236_case1:
  goto _sw237_case2;
  _sw237_case2:
  goto _sw238_case3;
  _sw238_case3:
  goto _sw239_case4;
  _sw239_case4:
  goto _sw240_case5;
  _sw240_case5:
  goto _sw241_case6;
  _sw241_case6:
  goto _sw242_case7;
  _sw242_case7:
  r_2 := TMINIFLACRESULT(miniflac_cuesheet_read_track_isrc_string(cuesheet, br, PAnsiChar(Pointer(0)), TUint32T(0), PUint32T(Pointer(0))));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _sw243_case8;
  _sw243_case8:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(1)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  f_2 := TUint8T(miniflac_bitreader_read(br, TUint8T(1)));
  if (track_audio_flag <> nil) then
  begin
    track_audio_flag^ := TUint8T(f_2);
  end;
  cuesheet^.state := MINIFLAC_CUESHEET_TRACKPREEMPH;
  Result := MINIFLAC_OK;
  System.Exit;
  _sw244_default:
  goto _sw234_end;
  _sw234_end:
  Result := MINIFLAC_ERROR;
end;

function miniflac_cuesheet_read_track_preemph_flag(cuesheet: PMiniflacCuesheetT; br: PMiniflacBitreaderT; track_preemph_flag: PUint8T): TMINIFLACRESULT;
label _sw245_end, _sw246_case0, _sw247_case1, _sw248_case2, _sw249_case3, _sw250_case4, _sw251_case5, _sw252_case6, _sw253_case7, _sw254_case8, _sw255_case9, _sw256_default;
var
  r_2: TMINIFLACRESULT;
  f_2: TUint8T;
  __c2p_tmp1: LongInt;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
  f_2 := TUint8T(0);
  __c2p_tmp1 := cuesheet^.state;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_CATALOG) then
  begin
    goto _sw246_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_LEADIN_CONST) then
  begin
    goto _sw247_case1;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_CDFLAG) then
  begin
    goto _sw248_case2;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_SHEET_RESERVE) then
  begin
    goto _sw249_case3;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKS_CONST) then
  begin
    goto _sw250_case4;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKOFFSET) then
  begin
    goto _sw251_case5;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKNUMBER) then
  begin
    goto _sw252_case6;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKISRC) then
  begin
    goto _sw253_case7;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKTYPE) then
  begin
    goto _sw254_case8;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKPREEMPH) then
  begin
    goto _sw255_case9;
  end;
  goto _sw256_default;
  _sw246_case0:
  goto _sw247_case1;
  _sw247_case1:
  goto _sw248_case2;
  _sw248_case2:
  goto _sw249_case3;
  _sw249_case3:
  goto _sw250_case4;
  _sw250_case4:
  goto _sw251_case5;
  _sw251_case5:
  goto _sw252_case6;
  _sw252_case6:
  goto _sw253_case7;
  _sw253_case7:
  goto _sw254_case8;
  _sw254_case8:
  r_2 := TMINIFLACRESULT(miniflac_cuesheet_read_track_audio_flag(cuesheet, br, PUint8T(Pointer(0))));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _sw255_case9;
  _sw255_case9:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(1)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  f_2 := TUint8T(miniflac_bitreader_read(br, TUint8T(1)));
  if (track_preemph_flag <> nil) then
  begin
    track_preemph_flag^ := TUint8T(f_2);
  end;
  miniflac_bitreader_discard(br, TUint8T(6));
  cuesheet^.pos := TUint32T(0);
  cuesheet^.state := MINIFLAC_CUESHEET_TRACK_RESERVE;
  Result := MINIFLAC_OK;
  System.Exit;
  _sw256_default:
  goto _sw245_end;
  _sw245_end:
  Result := MINIFLAC_ERROR;
end;

function miniflac_cuesheet_read_track_indexpoints(cuesheet: PMiniflacCuesheetT; br: PMiniflacBitreaderT; track_indexpoints: PUint8T): TMINIFLACRESULT;
label _sw257_end, _sw258_case0, _sw259_case1, _sw260_case2, _sw261_case3, _sw262_case4, _sw263_case5, _sw264_case6, _sw265_case7, _sw266_case8, _sw267_case9, _sw268_case10, _sw269_case11, _sw270_case12, _sw271_case13, _sw272_case14, _sw273_default;
var
  r_2: TMINIFLACRESULT;
  __c2p_tmp1: LongInt;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
  __c2p_tmp1 := cuesheet^.state;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_INDEX_OFFSET) then
  begin
    goto _sw258_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_INDEX_NUMBER) then
  begin
    goto _sw259_case1;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_INDEX_RESERVE) then
  begin
    goto _sw260_case2;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_CATALOG) then
  begin
    goto _sw261_case3;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_LEADIN_CONST) then
  begin
    goto _sw262_case4;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_CDFLAG) then
  begin
    goto _sw263_case5;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_SHEET_RESERVE) then
  begin
    goto _sw264_case6;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKS_CONST) then
  begin
    goto _sw265_case7;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKOFFSET) then
  begin
    goto _sw266_case8;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKNUMBER) then
  begin
    goto _sw267_case9;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKISRC) then
  begin
    goto _sw268_case10;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKTYPE) then
  begin
    goto _sw269_case11;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKPREEMPH) then
  begin
    goto _sw270_case12;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACK_RESERVE) then
  begin
    goto _sw271_case13;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKPOINTS) then
  begin
    goto _sw272_case14;
  end;
  goto _sw273_default;
  _sw258_case0:
  goto _sw259_case1;
  _sw259_case1:
  goto _sw260_case2;
  _sw260_case2:
  while (LongInt(cuesheet^.state) <> MINIFLAC_CUESHEET_TRACKOFFSET) do
  begin
    r_2 := TMINIFLACRESULT(miniflac_cuesheet_read_index_point_offset(cuesheet, br, PUint64T(Pointer(0))));
    if (LongInt(r_2) <> MINIFLAC_OK) then
    begin
      Break;
    end;
  end;
  if (LongInt(r_2) <> MINIFLAC_METADATA_END) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _sw261_case3;
  _sw261_case3:
  goto _sw262_case4;
  _sw262_case4:
  goto _sw263_case5;
  _sw263_case5:
  goto _sw264_case6;
  _sw264_case6:
  goto _sw265_case7;
  _sw265_case7:
  goto _sw266_case8;
  _sw266_case8:
  goto _sw267_case9;
  _sw267_case9:
  goto _sw268_case10;
  _sw268_case10:
  goto _sw269_case11;
  _sw269_case11:
  goto _sw270_case12;
  _sw270_case12:
  r_2 := TMINIFLACRESULT(miniflac_cuesheet_read_track_preemph_flag(cuesheet, br, PUint8T(Pointer(0))));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _sw271_case13;
  _sw271_case13:
  while (cuesheet^.pos < LongWord(13)) do
  begin
    if (miniflac_bitreader_fill_nocrc(br, TUint8T(8)) <> 0) then
    begin
      Result := MINIFLAC_CONTINUE;
      System.Exit;
    end;
    miniflac_bitreader_discard(br, TUint8T(8));
    cuesheet^.pos := (cuesheet^.pos + 1);
  end;
  cuesheet^.state := MINIFLAC_CUESHEET_TRACKPOINTS;
  goto _sw272_case14;
  _sw272_case14:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(8)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  cuesheet^.points := TUint8T(miniflac_bitreader_read(br, TUint8T(8)));
  if (track_indexpoints <> nil) then
  begin
    track_indexpoints^ := TUint8T(cuesheet^.points);
  end;
  cuesheet^.point := TUint8T(0);
  cuesheet^.state := MINIFLAC_CUESHEET_INDEX_OFFSET;
  Result := MINIFLAC_OK;
  System.Exit;
  _sw273_default:
  goto _sw257_end;
  _sw257_end:
  Result := MINIFLAC_ERROR;
end;

function miniflac_cuesheet_read_index_point_offset(cuesheet: PMiniflacCuesheetT; br: PMiniflacBitreaderT; index_point_offset: PUint64T): TMINIFLACRESULT;
label _L_case_miniflac_cuesheet_index_offset, _sw274_end, _sw275_case0, _sw276_case1, _sw277_case2, _sw278_case3, _sw279_case4, _sw280_case5, _sw281_case6, _sw282_case7, _sw283_case8, _sw284_case9, _sw285_case10, _sw286_case11, _sw287_case12, _sw288_case13, _sw289_case14, _sw290_default;
var
  r_2: TMINIFLACRESULT;
  t_2: TUint64T;
  __c2p_tmp1: LongInt;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
  t_2 := TUint64T(0);
  __c2p_tmp1 := cuesheet^.state;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_INDEX_NUMBER) then
  begin
    goto _sw275_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_INDEX_RESERVE) then
  begin
    goto _sw276_case1;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_CATALOG) then
  begin
    goto _sw277_case2;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_LEADIN_CONST) then
  begin
    goto _sw278_case3;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_CDFLAG) then
  begin
    goto _sw279_case4;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_SHEET_RESERVE) then
  begin
    goto _sw280_case5;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKS_CONST) then
  begin
    goto _sw281_case6;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKOFFSET) then
  begin
    goto _sw282_case7;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKNUMBER) then
  begin
    goto _sw283_case8;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKISRC) then
  begin
    goto _sw284_case9;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKTYPE) then
  begin
    goto _sw285_case10;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKPREEMPH) then
  begin
    goto _sw286_case11;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACK_RESERVE) then
  begin
    goto _sw287_case12;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKPOINTS) then
  begin
    goto _sw288_case13;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_INDEX_OFFSET) then
  begin
    goto _sw289_case14;
  end;
  goto _sw290_default;
  _sw275_case0:
  r_2 := TMINIFLACRESULT(miniflac_cuesheet_read_index_point_number(cuesheet, br, PUint8T(Pointer(0))));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _sw276_case1;
  _sw276_case1:
  while (cuesheet^.pos < LongWord(3)) do
  begin
    if (miniflac_bitreader_fill_nocrc(br, TUint8T(8)) <> 0) then
    begin
      Result := MINIFLAC_CONTINUE;
      System.Exit;
    end;
    miniflac_bitreader_discard(br, TUint8T(8));
    cuesheet^.pos := (cuesheet^.pos + 1);
  end;
  cuesheet^.point := TUint8T((LongInt(cuesheet^.point) + 1));
  cuesheet^.state := MINIFLAC_CUESHEET_INDEX_OFFSET;
  { C: goto case_miniflac_cuesheet_index_offset }
  goto _L_case_miniflac_cuesheet_index_offset;
  _sw277_case2:
  goto _sw278_case3;
  _sw278_case3:
  goto _sw279_case4;
  _sw279_case4:
  goto _sw280_case5;
  _sw280_case5:
  goto _sw281_case6;
  _sw281_case6:
  goto _sw282_case7;
  _sw282_case7:
  goto _sw283_case8;
  _sw283_case8:
  goto _sw284_case9;
  _sw284_case9:
  goto _sw285_case10;
  _sw285_case10:
  goto _sw286_case11;
  _sw286_case11:
  goto _sw287_case12;
  _sw287_case12:
  goto _sw288_case13;
  _sw288_case13:
  r_2 := TMINIFLACRESULT(miniflac_cuesheet_read_track_indexpoints(cuesheet, br, PUint8T(Pointer(0))));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _sw289_case14;
  _sw289_case14:
  _L_case_miniflac_cuesheet_index_offset:
  if (cuesheet^.point = cuesheet^.points) then
  begin
    cuesheet^.track := TUint8T((LongInt(cuesheet^.track) + 1));
    cuesheet^.state := MINIFLAC_CUESHEET_TRACKOFFSET;
    Result := MINIFLAC_METADATA_END;
    System.Exit;
  end;
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(64)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  t_2 := miniflac_bitreader_read(br, TUint8T(64));
  if (index_point_offset <> nil) then
  begin
    index_point_offset^ := t_2;
  end;
  cuesheet^.state := MINIFLAC_CUESHEET_INDEX_NUMBER;
  Result := MINIFLAC_OK;
  System.Exit;
  _sw290_default:
  goto _sw274_end;
  _sw274_end:
  Result := MINIFLAC_ERROR;
end;

function miniflac_cuesheet_read_index_point_number(cuesheet: PMiniflacCuesheetT; br: PMiniflacBitreaderT; index_point_number: PUint8T): TMINIFLACRESULT;
label _sw291_end, _sw292_case0, _sw293_case1, _sw294_case2, _sw295_case3, _sw296_case4, _sw297_case5, _sw298_case6, _sw299_case7, _sw300_case8, _sw301_case9, _sw302_case10, _sw303_case11, _sw304_case12, _sw305_case13, _sw306_default;
var
  r_2: TMINIFLACRESULT;
  t_2: TUint8T;
  __c2p_tmp1: LongInt;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
  t_2 := TUint8T(0);
  __c2p_tmp1 := cuesheet^.state;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_CATALOG) then
  begin
    goto _sw292_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_LEADIN_CONST) then
  begin
    goto _sw293_case1;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_CDFLAG) then
  begin
    goto _sw294_case2;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_SHEET_RESERVE) then
  begin
    goto _sw295_case3;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKS_CONST) then
  begin
    goto _sw296_case4;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKOFFSET) then
  begin
    goto _sw297_case5;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKNUMBER) then
  begin
    goto _sw298_case6;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKISRC) then
  begin
    goto _sw299_case7;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKTYPE) then
  begin
    goto _sw300_case8;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKPREEMPH) then
  begin
    goto _sw301_case9;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACK_RESERVE) then
  begin
    goto _sw302_case10;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_TRACKPOINTS) then
  begin
    goto _sw303_case11;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_INDEX_OFFSET) then
  begin
    goto _sw304_case12;
  end;
  if (__c2p_tmp1 = MINIFLAC_CUESHEET_INDEX_NUMBER) then
  begin
    goto _sw305_case13;
  end;
  goto _sw306_default;
  _sw292_case0:
  goto _sw293_case1;
  _sw293_case1:
  goto _sw294_case2;
  _sw294_case2:
  goto _sw295_case3;
  _sw295_case3:
  goto _sw296_case4;
  _sw296_case4:
  goto _sw297_case5;
  _sw297_case5:
  goto _sw298_case6;
  _sw298_case6:
  goto _sw299_case7;
  _sw299_case7:
  goto _sw300_case8;
  _sw300_case8:
  goto _sw301_case9;
  _sw301_case9:
  goto _sw302_case10;
  _sw302_case10:
  goto _sw303_case11;
  _sw303_case11:
  goto _sw304_case12;
  _sw304_case12:
  r_2 := TMINIFLACRESULT(miniflac_cuesheet_read_index_point_offset(cuesheet, br, PUint64T(Pointer(0))));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _sw305_case13;
  _sw305_case13:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(8)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  t_2 := TUint8T(miniflac_bitreader_read(br, TUint8T(8)));
  if (index_point_number <> nil) then
  begin
    index_point_number^ := TUint8T(t_2);
  end;
  cuesheet^.pos := TUint32T(0);
  cuesheet^.state := MINIFLAC_CUESHEET_INDEX_RESERVE;
  Result := MINIFLAC_OK;
  System.Exit;
  _sw306_default:
  goto _sw291_end;
  _sw291_end:
  Result := MINIFLAC_ERROR;
end;

procedure miniflac_seektable_init(seektable: PMiniflacSeektableT); inline;
begin
  seektable^.state := MINIFLAC_SEEKTABLE_SAMPLE_NUMBER_CONST;
  seektable^.len := TUint32T(0);
  seektable^.pos := TUint32T(0);
end;

function miniflac_seektable_read_seekpoints(seektable: PMiniflacSeektableT; br: PMiniflacBitreaderT; seekpoints: PUint32T): TMINIFLACRESULT; inline;
label _sw307_end;
var
  __c2p_tmp1: LongInt;
begin
  __c2p_tmp1 := seektable^.state;
  case __c2p_tmp1 of
    MINIFLAC_SEEKTABLE_SAMPLE_NUMBER_CONST:
    begin
      if (seekpoints <> nil) then
      begin
        seekpoints^ := seektable^.len;
      end;
      Result := MINIFLAC_OK;
      System.Exit;
    end;
  else
  begin
    goto _sw307_end;
  end
  end;
  _sw307_end:
  Result := MINIFLAC_ERROR;
end;

function miniflac_seektable_read_sample_number(seektable: PMiniflacSeektableT; br: PMiniflacBitreaderT; sample_number: PUint64T): TMINIFLACRESULT; inline;
label _sw308_end;
var
  t_2: TUint64T;
  __c2p_tmp1: LongInt;
begin
  t_2 := TUint64T(0);
  __c2p_tmp1 := seektable^.state;
  case __c2p_tmp1 of
    MINIFLAC_SEEKTABLE_SAMPLE_NUMBER_CONST:
    begin
      if (seektable^.pos = seektable^.len) then
      begin
        Result := MINIFLAC_METADATA_END;
        System.Exit;
      end;
      if (miniflac_bitreader_fill_nocrc(br, TUint8T(64)) <> 0) then
      begin
        Result := MINIFLAC_CONTINUE;
        System.Exit;
      end;
      t_2 := miniflac_bitreader_read(br, TUint8T(64));
      if (sample_number <> nil) then
      begin
        sample_number^ := t_2;
      end;
      seektable^.state := MINIFLAC_SEEKTABLE_SAMPLE_OFFSET_CONST;
      Result := MINIFLAC_OK;
      System.Exit;
    end;
  else
  begin
    goto _sw308_end;
  end
  end;
  _sw308_end:
  Result := MINIFLAC_ERROR;
end;

function miniflac_seektable_read_sample_offset(seektable: PMiniflacSeektableT; br: PMiniflacBitreaderT; sample_offset: PUint64T): TMINIFLACRESULT; inline;
label _sw309_end, _sw310_case0, _sw311_case1, _sw312_default;
var
  r_2: TMINIFLACRESULT;
  t_2: TUint64T;
  __c2p_tmp1: LongInt;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
  t_2 := TUint64T(0);
  __c2p_tmp1 := seektable^.state;
  if (__c2p_tmp1 = MINIFLAC_SEEKTABLE_SAMPLE_NUMBER_CONST) then
  begin
    goto _sw310_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_SEEKTABLE_SAMPLE_OFFSET_CONST) then
  begin
    goto _sw311_case1;
  end;
  goto _sw312_default;
  _sw310_case0:
  r_2 := TMINIFLACRESULT(miniflac_seektable_read_sample_number(seektable, br, PUint64T(Pointer(0))));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _sw311_case1;
  _sw311_case1:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(64)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  t_2 := miniflac_bitreader_read(br, TUint8T(64));
  if (sample_offset <> nil) then
  begin
    sample_offset^ := t_2;
  end;
  seektable^.state := MINIFLAC_SEEKTABLE_SAMPLES_CONST;
  Result := MINIFLAC_OK;
  System.Exit;
  _sw312_default:
  goto _sw309_end;
  _sw309_end:
  Result := MINIFLAC_ERROR;
end;

function miniflac_seektable_read_samples(seektable: PMiniflacSeektableT; br: PMiniflacBitreaderT; samples: PUint16T): TMINIFLACRESULT;
label _sw313_end, _sw314_case0, _sw315_case1, _sw316_case2, _sw317_default;
var
  r_2: TMINIFLACRESULT;
  t_2: TUint16T;
  __c2p_tmp1: LongInt;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
  t_2 := TUint16T(0);
  __c2p_tmp1 := seektable^.state;
  if (__c2p_tmp1 = MINIFLAC_SEEKTABLE_SAMPLE_NUMBER_CONST) then
  begin
    goto _sw314_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_SEEKTABLE_SAMPLE_OFFSET_CONST) then
  begin
    goto _sw315_case1;
  end;
  if (__c2p_tmp1 = MINIFLAC_SEEKTABLE_SAMPLES_CONST) then
  begin
    goto _sw316_case2;
  end;
  goto _sw317_default;
  _sw314_case0:
  goto _sw315_case1;
  _sw315_case1:
  r_2 := TMINIFLACRESULT(miniflac_seektable_read_sample_offset(seektable, br, PUint64T(Pointer(0))));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _sw316_case2;
  _sw316_case2:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(16)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  t_2 := TUint16T(miniflac_bitreader_read(br, TUint8T(16)));
  if (samples <> nil) then
  begin
    samples^ := TUint16T(t_2);
  end;
  seektable^.pos := (seektable^.pos + 1);
  seektable^.state := MINIFLAC_SEEKTABLE_SAMPLE_NUMBER_CONST;
  Result := MINIFLAC_OK;
  System.Exit;
  _sw317_default:
  goto _sw313_end;
  _sw313_end:
  Result := MINIFLAC_ERROR;
end;

procedure miniflac_application_init(application: PMiniflacApplicationT); inline;
begin
  application^.state := MINIFLAC_APPLICATION_ID_CONST;
  application^.len := TUint32T(0);
  application^.pos := TUint32T(0);
end;

function miniflac_application_read_id(application: PMiniflacApplicationT; br: PMiniflacBitreaderT; id: PUint32T): TMINIFLACRESULT; inline;
label _sw318_end;
var
  t_2: TUint32T;
  __c2p_tmp1: LongInt;
begin
  __c2p_tmp1 := application^.state;
  case __c2p_tmp1 of
    MINIFLAC_APPLICATION_ID_CONST:
    begin
      if (miniflac_bitreader_fill_nocrc(br, TUint8T(32)) <> 0) then
      begin
        Result := MINIFLAC_CONTINUE;
        System.Exit;
      end;
      t_2 := TUint32T(miniflac_bitreader_read(br, TUint8T(32)));
      if (id <> nil) then
      begin
        id^ := t_2;
      end;
      application^.state := MINIFLAC_APPLICATION_DATA_CONST;
      Result := MINIFLAC_OK;
      System.Exit;
    end;
  else
  begin
    goto _sw318_end;
  end
  end;
  _sw318_end:
  Result := MINIFLAC_ERROR;
end;

function miniflac_application_read_length(application: PMiniflacApplicationT; br: PMiniflacBitreaderT; length: PUint32T): TMINIFLACRESULT; inline;
label _sw319_end, _sw320_case0, _sw321_case1, _sw322_default;
var
  r_2: TMINIFLACRESULT;
  __c2p_tmp1: LongInt;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
  __c2p_tmp1 := application^.state;
  if (__c2p_tmp1 = MINIFLAC_APPLICATION_ID_CONST) then
  begin
    goto _sw320_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_APPLICATION_DATA_CONST) then
  begin
    goto _sw321_case1;
  end;
  goto _sw322_default;
  _sw320_case0:
  r_2 := TMINIFLACRESULT(miniflac_application_read_id(application, br, PUint32T(Pointer(0))));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _sw321_case1;
  _sw321_case1:
  if (length <> nil) then
  begin
    length^ := application^.len;
  end;
  Result := MINIFLAC_OK;
  System.Exit;
  _sw322_default:
  goto _sw319_end;
  _sw319_end:
  Result := MINIFLAC_ERROR;
end;

function miniflac_application_read_data(application: PMiniflacApplicationT; br: PMiniflacBitreaderT; output: PUint8T; length: TUint32T; outlen: PUint32T): TMINIFLACRESULT; inline;
label _sw323_end, _sw324_case0, _sw325_case1, _sw326_default;
var
  r_2: TMINIFLACRESULT;
  d_2: TUint8T;
  __c2p_tmp1: LongInt;
  __c2p_tmp2: LongWord;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
  __c2p_tmp1 := application^.state;
  if (__c2p_tmp1 = MINIFLAC_APPLICATION_ID_CONST) then
  begin
    goto _sw324_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_APPLICATION_DATA_CONST) then
  begin
    goto _sw325_case1;
  end;
  goto _sw326_default;
  _sw324_case0:
  r_2 := TMINIFLACRESULT(miniflac_application_read_id(application, br, PUint32T(Pointer(0))));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _sw325_case1;
  _sw325_case1:
  while (application^.pos < application^.len) do
  begin
    if (miniflac_bitreader_fill_nocrc(br, TUint8T(8)) <> 0) then
    begin
      Result := MINIFLAC_CONTINUE;
      System.Exit;
    end;
    d_2 := TUint8T(miniflac_bitreader_read(br, TUint8T(8)));
    if ((output <> nil) and (application^.pos < length)) then
    begin
      output[application^.pos] := TUint8T(d_2);
    end;
    application^.pos := (application^.pos + 1);
  end;
  if (outlen <> nil) then
  begin
    if (application^.len <= length) then
    begin
      __c2p_tmp2 := application^.len;
    end
    else
    begin
      __c2p_tmp2 := length;
    end;
    outlen^ := __c2p_tmp2;
  end;
  Result := MINIFLAC_OK;
  System.Exit;
  _sw326_default:
  goto _sw323_end;
  _sw323_end:
  Result := MINIFLAC_ERROR;
end;

procedure miniflac_padding_init(padding: PMiniflacPaddingT); inline;
begin
  padding^.len := TUint32T(0);
  padding^.pos := TUint32T(0);
end;

function miniflac_padding_read_length(padding: PMiniflacPaddingT; br: PMiniflacBitreaderT; length: PUint32T): TMINIFLACRESULT; inline;
begin
  if (length <> nil) then
  begin
    length^ := padding^.len;
  end;
  Result := MINIFLAC_OK;
end;

function miniflac_padding_read_data(padding: PMiniflacPaddingT; br: PMiniflacBitreaderT; output: PUint8T; length: TUint32T; outlen: PUint32T): TMINIFLACRESULT; inline;
var
  d_2: TUint8T;
  __c2p_tmp1: LongWord;
begin
  while (padding^.pos < padding^.len) do
  begin
    if (miniflac_bitreader_fill_nocrc(br, TUint8T(8)) <> 0) then
    begin
      Result := MINIFLAC_CONTINUE;
      System.Exit;
    end;
    d_2 := TUint8T(miniflac_bitreader_read(br, TUint8T(8)));
    if ((output <> nil) and (padding^.pos < length)) then
    begin
      output[padding^.pos] := TUint8T(d_2);
    end;
    padding^.pos := (padding^.pos + 1);
  end;
  if (outlen <> nil) then
  begin
    if (padding^.len <= length) then
    begin
      __c2p_tmp1 := padding^.len;
    end
    else
    begin
      __c2p_tmp1 := length;
    end;
    outlen^ := __c2p_tmp1;
  end;
  Result := MINIFLAC_OK;
end;

procedure miniflac_metadata_init(metadata: PMiniflacMetadataT); inline;
begin
  metadata^.state := MINIFLAC_METADATA_HEADER;
  metadata^.pos := TUint32T(0);
  miniflac_metadata_header_init(@metadata^.header);
  miniflac_streaminfo_init(@metadata^.streaminfo);
  miniflac_vorbis_comment_init(@metadata^.vorbis_comment);
  miniflac_picture_init(@metadata^.picture);
  miniflac_seektable_init(@metadata^.seektable);
  miniflac_application_init(@metadata^.application);
  miniflac_cuesheet_init(@metadata^.cuesheet);
end;

function miniflac_metadata_sync(metadata: PMiniflacMetadataT; br: PMiniflacBitreaderT): TMINIFLACRESULT; inline;
label _sw327_end;
var
  r_2: TMINIFLACRESULT;
  __c2p_tmp1: LongInt;
begin
  r_2 := TMINIFLACRESULT(miniflac_metadata_header_decode(@metadata^.header, br));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  __c2p_tmp1 := metadata^.header.&type;
  case __c2p_tmp1 of
    MINIFLAC_METADATA_STREAMINFO:
    begin
      miniflac_streaminfo_init(@metadata^.streaminfo);
      goto _sw327_end;
    end;
    MINIFLAC_METADATA_VORBIS_COMMENT:
    begin
      miniflac_vorbis_comment_init(@metadata^.vorbis_comment);
      goto _sw327_end;
    end;
    MINIFLAC_METADATA_PICTURE:
    begin
      miniflac_picture_init(@metadata^.picture);
      goto _sw327_end;
    end;
    MINIFLAC_METADATA_CUESHEET:
    begin
      miniflac_cuesheet_init(@metadata^.cuesheet);
      goto _sw327_end;
    end;
    MINIFLAC_METADATA_SEEKTABLE:
    begin
      miniflac_seektable_init(@metadata^.seektable);
      metadata^.seektable.len := (metadata^.header.length div LongWord(18));
      goto _sw327_end;
    end;
    MINIFLAC_METADATA_APPLICATION:
    begin
      miniflac_application_init(@metadata^.application);
      metadata^.application.len := LongWord((metadata^.header.length - LongWord(4)));
      goto _sw327_end;
    end;
    MINIFLAC_METADATA_PADDING:
    begin
      miniflac_padding_init(@metadata^.padding);
      metadata^.padding.len := metadata^.header.length;
      goto _sw327_end;
    end;
  else
  begin
    goto _sw327_end;
  end
  end;
  _sw327_end:
  metadata^.state := MINIFLAC_METADATA_DATA;
  metadata^.pos := TUint32T(0);
  Result := MINIFLAC_OK;
end;

function miniflac_metadata_skip(metadata: PMiniflacMetadataT; br: PMiniflacBitreaderT): TMINIFLACRESULT; inline;
begin
  while (metadata^.pos < metadata^.header.length) do
  begin
    if (miniflac_bitreader_fill_nocrc(br, TUint8T(8)) <> 0) then
    begin
      Result := MINIFLAC_CONTINUE;
      System.Exit;
    end;
    miniflac_bitreader_discard(br, TUint8T(8));
    metadata^.pos := (metadata^.pos + 1);
  end;
  Result := MINIFLAC_OK;
end;

function miniflac_metadata_decode(metadata: PMiniflacMetadataT; br: PMiniflacBitreaderT): TMINIFLACRESULT;
label _sw328_end, _sw329_case0, _sw330_case1, _sw331_default, _sw332_end;
var
  r_2: TMINIFLACRESULT;
  __c2p_tmp1: LongInt;
  __c2p_tmp2: LongInt;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
  __c2p_tmp1 := metadata^.state;
  if (__c2p_tmp1 = MINIFLAC_METADATA_HEADER) then
  begin
    goto _sw329_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_METADATA_DATA) then
  begin
    goto _sw330_case1;
  end;
  goto _sw331_default;
  _sw329_case0:
  r_2 := TMINIFLACRESULT(miniflac_metadata_sync(metadata, br));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _sw330_case1;
  _sw330_case1:
  __c2p_tmp2 := metadata^.header.&type;
  case __c2p_tmp2 of
    MINIFLAC_METADATA_STREAMINFO:
    begin
      r_2 := TMINIFLACRESULT(miniflac_streaminfo_read_md5_data(@metadata^.streaminfo, br, PUint8T(Pointer(0)), TUint32T(0), PUint32T(Pointer(0))));
      goto _sw332_end;
    end;
    MINIFLAC_METADATA_VORBIS_COMMENT:
    begin
      repeat
        r_2 := TMINIFLACRESULT(miniflac_vorbis_comment_read_length(@metadata^.vorbis_comment, br, PUint32T(Pointer(0))));
      until (LongInt(r_2) <> MINIFLAC_OK);
      goto _sw332_end;
    end;
    MINIFLAC_METADATA_PICTURE:
    begin
      r_2 := TMINIFLACRESULT(miniflac_picture_read_data(@metadata^.picture, br, PUint8T(Pointer(0)), TUint32T(0), PUint32T(Pointer(0))));
      goto _sw332_end;
    end;
    MINIFLAC_METADATA_CUESHEET:
    begin
      repeat
        r_2 := TMINIFLACRESULT(miniflac_cuesheet_read_track_indexpoints(@metadata^.cuesheet, br, PUint8T(Pointer(0))));
      until (LongInt(r_2) <> MINIFLAC_OK);
      goto _sw332_end;
    end;
    MINIFLAC_METADATA_SEEKTABLE:
    begin
      repeat
        r_2 := TMINIFLACRESULT(miniflac_seektable_read_samples(@metadata^.seektable, br, PUint16T(Pointer(0))));
      until (LongInt(r_2) <> MINIFLAC_OK);
      goto _sw332_end;
    end;
    MINIFLAC_METADATA_APPLICATION:
    begin
      r_2 := TMINIFLACRESULT(miniflac_application_read_data(@metadata^.application, br, PUint8T(Pointer(0)), TUint32T(0), PUint32T(Pointer(0))));
      goto _sw332_end;
    end;
    MINIFLAC_METADATA_PADDING:
    begin
      r_2 := TMINIFLACRESULT(miniflac_padding_read_data(@metadata^.padding, br, PUint8T(Pointer(0)), TUint32T(0), PUint32T(Pointer(0))));
      goto _sw332_end;
    end;
  else
  begin
    r_2 := TMINIFLACRESULT(miniflac_metadata_skip(metadata, br));
  end
  end;
  _sw332_end:
  goto _sw331_default;
  _sw331_default:
  goto _sw328_end;
  _sw328_end:
  if (LongInt(r_2) = MINIFLAC_METADATA_END) then
  begin
    r_2 := TMINIFLACRESULT(MINIFLAC_OK);
  end;
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  br^.crc8 := TUint8T(0);
  br^.crc16 := TUint16T(0);
  metadata^.state := MINIFLAC_METADATA_HEADER;
  metadata^.pos := TUint32T(0);
  Result := MINIFLAC_OK;
end;

procedure miniflac_metadata_header_init(header: PMiniflacMetadataHeaderT); inline;
begin
  header^.state := MINIFLAC_METADATA_LAST_FLAG;
  header^.&type := MINIFLAC_METADATA_UNKNOWN;
  header^.is_last := TUint8T(0);
  header^.type_raw := TUint8T(0);
  header^.length := TUint32T(0);
end;

function miniflac_metadata_header_decode(header: PMiniflacMetadataHeaderT; br: PMiniflacBitreaderT): TMINIFLACRESULT;
label _sw333_end, _sw334_case0, _sw335_case1, _sw336_case2, _sw337_default, _sw338_end;
var
  __c2p_tmp1: LongInt;
  __c2p_tmp2: LongInt;
begin
  __c2p_tmp1 := header^.state;
  if (__c2p_tmp1 = MINIFLAC_METADATA_LAST_FLAG) then
  begin
    goto _sw334_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_METADATA_BLOCK_TYPE) then
  begin
    goto _sw335_case1;
  end;
  if (__c2p_tmp1 = MINIFLAC_METADATA_LENGTH_CONST) then
  begin
    goto _sw336_case2;
  end;
  goto _sw337_default;
  _sw334_case0:
  if (miniflac_bitreader_fill(br, TUint8T(1)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  miniflac_metadata_header_init(header);
  header^.is_last := TUint8T(miniflac_bitreader_read(br, TUint8T(1)));
  header^.state := MINIFLAC_METADATA_BLOCK_TYPE;
  goto _sw335_case1;
  _sw335_case1:
  if (miniflac_bitreader_fill(br, TUint8T(7)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  header^.type_raw := TUint8T(miniflac_bitreader_read(br, TUint8T(7)));
  __c2p_tmp2 := LongInt(header^.type_raw);
  case __c2p_tmp2 of
    0:
    begin
      header^.&type := MINIFLAC_METADATA_STREAMINFO;
      goto _sw338_end;
    end;
    1:
    begin
      header^.&type := MINIFLAC_METADATA_PADDING;
      goto _sw338_end;
    end;
    2:
    begin
      header^.&type := MINIFLAC_METADATA_APPLICATION;
      goto _sw338_end;
    end;
    3:
    begin
      header^.&type := MINIFLAC_METADATA_SEEKTABLE;
      goto _sw338_end;
    end;
    4:
    begin
      header^.&type := MINIFLAC_METADATA_VORBIS_COMMENT;
      goto _sw338_end;
    end;
    5:
    begin
      header^.&type := MINIFLAC_METADATA_CUESHEET;
      goto _sw338_end;
    end;
    6:
    begin
      header^.&type := MINIFLAC_METADATA_PICTURE;
      goto _sw338_end;
    end;
    127:
    begin
      header^.&type := MINIFLAC_METADATA_INVALID;
      Result := MINIFLAC_METADATA_TYPE_INVALID;
      System.Exit;
    end;
  else
  begin
    header^.&type := MINIFLAC_METADATA_UNKNOWN;
    Result := MINIFLAC_METADATA_TYPE_RESERVED;
    System.Exit;
  end
  end;
  _sw338_end:
  header^.state := MINIFLAC_METADATA_LENGTH_CONST;
  goto _sw336_case2;
  _sw336_case2:
  if (miniflac_bitreader_fill(br, TUint8T(24)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  header^.length := TUint32T(miniflac_bitreader_read(br, TUint8T(24)));
  header^.state := MINIFLAC_METADATA_LAST_FLAG;
  goto _sw333_end;
  _sw337_default:
  goto _sw333_end;
  _sw333_end:
  Result := MINIFLAC_OK;
end;

procedure miniflac_residual_init(residual: PMiniflacResidualT); inline;
begin
  residual^.coding_method := TUint8T(0);
  residual^.partition_order := TUint8T(0);
  residual^.rice_parameter := TUint8T(0);
  residual^.rice_size := TUint8T(0);
  residual^.msb := TUint32T(0);
  residual^.rice_parameter_size := TUint8T(0);
  residual^.value := TInt32T(0);
  residual^.partition := TUint32T(0);
  residual^.partition_total := TUint32T(0);
  residual^.residual := TUint32T(0);
  residual^.residual_total := TUint32T(0);
  residual^.state := MINIFLAC_RESIDUAL_CODING_METHOD;
end;

function miniflac_residual_decode(residual: PMiniflacResidualT; br: PMiniflacBitreaderT; pos: PUint32T; block_size: TUint32T; predictor_order: TUint8T; output: PInt32T): TMINIFLACRESULT;
label _L_miniflac_residual_rice_parameter, _L_miniflac_residual_rice_size, _L_miniflac_residual_msb, _L_miniflac_residual_rice_value, _L_miniflac_residual_nextpart, _L_miniflac_residual_lsb, _sw339_end, _sw340_case0, _sw341_case1, _sw342_case2, _sw343_case3, _sw344_case4, _sw345_case5, _sw346_case6, _sw347_default, _sw348_end;
var
  temp_2: TUint64T;
  temp_32: TUint32T;
  __c2p_tmp1: LongInt;
  __c2p_tmp2: LongInt;
begin
  __c2p_tmp1 := residual^.state;
  if (__c2p_tmp1 = MINIFLAC_RESIDUAL_CODING_METHOD) then
  begin
    goto _sw340_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_RESIDUAL_PARTITION_ORDER) then
  begin
    goto _sw341_case1;
  end;
  if (__c2p_tmp1 = MINIFLAC_RESIDUAL_RICE_PARAMETER) then
  begin
    goto _sw342_case2;
  end;
  if (__c2p_tmp1 = MINIFLAC_RESIDUAL_RICE_SIZE) then
  begin
    goto _sw343_case3;
  end;
  if (__c2p_tmp1 = MINIFLAC_RESIDUAL_RICE_VALUE) then
  begin
    goto _sw344_case4;
  end;
  if (__c2p_tmp1 = MINIFLAC_RESIDUAL_MSB) then
  begin
    goto _sw345_case5;
  end;
  if (__c2p_tmp1 = MINIFLAC_RESIDUAL_LSB) then
  begin
    goto _sw346_case6;
  end;
  goto _sw347_default;
  _sw340_case0:
  if (miniflac_bitreader_fill(br, TUint8T(2)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  temp_2 := miniflac_bitreader_read(br, TUint8T(2));
  if (temp_2 > QWord(1)) then
  begin
    Result := MINIFLAC_RESERVED_CODING_METHOD;
    System.Exit;
  end;
  residual^.coding_method := TUint8T(temp_2);
  __c2p_tmp2 := LongInt(residual^.coding_method);
  case __c2p_tmp2 of
    0:
    begin
      residual^.rice_parameter_size := TUint8T(4);
      goto _sw348_end;
    end;
    1:
    begin
      residual^.rice_parameter_size := TUint8T(5);
      goto _sw348_end;
    end;
  end;
  _sw348_end:
  residual^.msb := TUint32T(0);
  residual^.state := MINIFLAC_RESIDUAL_PARTITION_ORDER;
  goto _sw341_case1;
  _sw341_case1:
  if (miniflac_bitreader_fill(br, TUint8T(4)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  residual^.partition_order := TUint8T(miniflac_bitreader_read(br, TUint8T(4)));
  residual^.partition_total := TUint32T((1 shl LongInt(residual^.partition_order)));
  residual^.state := MINIFLAC_RESIDUAL_RICE_PARAMETER;
  goto _sw342_case2;
  _sw342_case2:
  _L_miniflac_residual_rice_parameter:
  if (miniflac_bitreader_fill(br, TUint8T(residual^.rice_parameter_size)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  residual^.rice_parameter := TUint8T(miniflac_bitreader_read(br, TUint8T(residual^.rice_parameter_size)));
  residual^.residual := TUint32T(0);
  residual^.residual_total := (block_size shr LongInt(residual^.partition_order));
  if (residual^.partition = LongWord(0)) then
  begin
    residual^.residual_total := (residual^.residual_total - LongWord(predictor_order));
  end;
  if (residual^.rice_parameter = escape_codes[LongInt(residual^.coding_method)]) then
  begin
    residual^.state := MINIFLAC_RESIDUAL_RICE_SIZE;
    if (miniflac_bitreader_fill(br, TUint8T(5)) <> 0) then
    begin
      Result := MINIFLAC_CONTINUE;
      System.Exit;
    end
    else
    begin
    end;
    residual^.rice_size := TUint8T(miniflac_bitreader_read(br, TUint8T(5)));
    residual^.state := MINIFLAC_RESIDUAL_RICE_VALUE;
    { C: 落入 RICE_VALUE }
    goto _L_miniflac_residual_rice_value;
  end;
  residual^.state := MINIFLAC_RESIDUAL_MSB;
  goto _L_miniflac_residual_msb;
  _sw343_case3:
  _L_miniflac_residual_rice_size:
  if (miniflac_bitreader_fill(br, TUint8T(5)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  residual^.rice_size := TUint8T(miniflac_bitreader_read(br, TUint8T(5)));
  residual^.state := MINIFLAC_RESIDUAL_RICE_VALUE;
  goto _sw344_case4;
  _sw344_case4:
  _L_miniflac_residual_rice_value:
  if (miniflac_bitreader_fill(br, TUint8T(residual^.rice_size)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  residual^.value := TInt32T(miniflac_bitreader_read_signed(br, TUint8T(residual^.rice_size)));
  if (output <> nil) then
  begin
    output[pos^] := TInt32T(residual^.value);
  end;
  pos^ := (pos^ + LongWord(1));
  residual^.residual := (residual^.residual + 1);
  if (residual^.residual < residual^.residual_total) then
  begin
    residual^.state := MINIFLAC_RESIDUAL_RICE_VALUE;
    goto _L_miniflac_residual_rice_value;
  end;
  { C: goto miniflac_residual_nextpart }
  goto _L_miniflac_residual_nextpart;
  _sw345_case5:
  _L_miniflac_residual_msb:
  while (miniflac_bitreader_fill(br, TUint8T(1)) = 0) do
  begin
    if (miniflac_bitreader_read(br, TUint8T(1)) <> 0) then
    begin
      residual^.state := MINIFLAC_RESIDUAL_LSB;
      if (miniflac_bitreader_fill(br, TUint8T(residual^.rice_parameter)) <> 0) then
      begin
        Result := MINIFLAC_CONTINUE;
        System.Exit;
      end
      else
      begin
      end;
      temp_32 := ((residual^.msb shl LongInt(residual^.rice_parameter)) or TUint32T(miniflac_bitreader_read(br, TUint8T(residual^.rice_parameter))));
      residual^.value := TInt32T(((temp_32 shr 1) xor -(temp_32 and LongWord(1))));
      if (output <> nil) then
      begin
        output[pos^] := TInt32T(residual^.value);
      end
      else
      begin
      end;
      pos^ := (pos^ + LongWord(1));
      residual^.msb := TUint32T(0);
      residual^.residual := (residual^.residual + 1);
      if (residual^.residual < residual^.residual_total) then
      begin
        residual^.state := MINIFLAC_RESIDUAL_MSB;
        { C: goto miniflac_residual_msb }
        goto _L_miniflac_residual_msb;
      end;
      { C: 落到 nextpart }
      residual^.residual := TUint32T(0);
      residual^.partition := (residual^.partition + 1);
      if (residual^.partition < residual^.partition_total) then
      begin
        residual^.state := MINIFLAC_RESIDUAL_RICE_PARAMETER;
        goto _L_miniflac_residual_rice_parameter;
      end;
      goto _sw339_end;
    end;
    residual^.msb := (residual^.msb + 1);
  end;
  Result := MINIFLAC_CONTINUE;
  System.Exit;
  _sw346_case6:
  _L_miniflac_residual_lsb:
  if (miniflac_bitreader_fill(br, TUint8T(residual^.rice_parameter)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  temp_32 := ((residual^.msb shl LongInt(residual^.rice_parameter)) or TUint32T(miniflac_bitreader_read(br, TUint8T(residual^.rice_parameter))));
  residual^.value := TInt32T(((temp_32 shr 1) xor -(temp_32 and LongWord(1))));
  if (output <> nil) then
  begin
    output[pos^] := TInt32T(residual^.value);
  end;
  pos^ := (pos^ + LongWord(1));
  residual^.msb := TUint32T(0);
  residual^.residual := (residual^.residual + 1);
  if (residual^.residual < residual^.residual_total) then
  begin
    residual^.state := MINIFLAC_RESIDUAL_MSB;
    goto _L_miniflac_residual_msb;
  end;
  _L_miniflac_residual_nextpart:
  residual^.residual := TUint32T(0);
  residual^.partition := (residual^.partition + 1);
  if (residual^.partition < residual^.partition_total) then
  begin
    residual^.state := MINIFLAC_RESIDUAL_RICE_PARAMETER;
    goto _L_miniflac_residual_rice_parameter;
  end;
  goto _sw339_end;
  _sw347_default:
  goto _sw339_end;
  _sw339_end:
  miniflac_residual_init(residual);
  Result := MINIFLAC_OK;
end;

procedure miniflac_streaminfo_init(streaminfo: PMiniflacStreaminfoT); inline;
begin
  streaminfo^.state := MINIFLAC_STREAMINFO_MINBLOCKSIZE;
  streaminfo^.pos := TUint8T(0);
  streaminfo^.sample_rate := TUint32T(0);
  streaminfo^.bps := TUint8T(0);
end;

function miniflac_streaminfo_read_min_block_size(streaminfo: PMiniflacStreaminfoT; br: PMiniflacBitreaderT; min_block_size: PUint16T): TMINIFLACRESULT; inline;
label _sw349_end;
var
  t_2: TUint16T;
  __c2p_tmp1: LongInt;
begin
  __c2p_tmp1 := streaminfo^.state;
  case __c2p_tmp1 of
    MINIFLAC_STREAMINFO_MINBLOCKSIZE:
    begin
      if (miniflac_bitreader_fill_nocrc(br, TUint8T(16)) <> 0) then
      begin
        Result := MINIFLAC_CONTINUE;
        System.Exit;
      end;
      t_2 := TUint16T(miniflac_bitreader_read(br, TUint8T(16)));
      if (min_block_size <> nil) then
      begin
        min_block_size^ := TUint16T(t_2);
      end;
      streaminfo^.state := MINIFLAC_STREAMINFO_MAXBLOCKSIZE;
      Result := MINIFLAC_OK;
      System.Exit;
    end;
  else
  begin
    goto _sw349_end;
  end
  end;
  _sw349_end:
  Result := MINIFLAC_ERROR;
end;

function miniflac_streaminfo_read_max_block_size(streaminfo: PMiniflacStreaminfoT; br: PMiniflacBitreaderT; max_block_size: PUint16T): TMINIFLACRESULT; inline;
label _sw350_end, _sw351_case0, _sw352_case1, _sw353_default;
var
  t_2: TUint16T;
  r_2: TMINIFLACRESULT;
  __c2p_tmp1: LongInt;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
  __c2p_tmp1 := streaminfo^.state;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_MINBLOCKSIZE) then
  begin
    goto _sw351_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_MAXBLOCKSIZE) then
  begin
    goto _sw352_case1;
  end;
  goto _sw353_default;
  _sw351_case0:
  r_2 := TMINIFLACRESULT(miniflac_streaminfo_read_min_block_size(streaminfo, br, PUint16T(Pointer(0))));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _sw352_case1;
  _sw352_case1:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(16)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  t_2 := TUint16T(miniflac_bitreader_read(br, TUint8T(16)));
  if (max_block_size <> nil) then
  begin
    max_block_size^ := TUint16T(t_2);
  end;
  streaminfo^.state := MINIFLAC_STREAMINFO_MINFRAMESIZE;
  Result := MINIFLAC_OK;
  System.Exit;
  _sw353_default:
  goto _sw350_end;
  _sw350_end:
  Result := MINIFLAC_ERROR;
end;

function miniflac_streaminfo_read_min_frame_size(streaminfo: PMiniflacStreaminfoT; br: PMiniflacBitreaderT; min_frame_size: PUint32T): TMINIFLACRESULT; inline;
label _sw354_end, _sw355_case0, _sw356_case1, _sw357_case2, _sw358_default;
var
  t_2: TUint32T;
  r_2: TMINIFLACRESULT;
  __c2p_tmp1: LongInt;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
  __c2p_tmp1 := streaminfo^.state;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_MINBLOCKSIZE) then
  begin
    goto _sw355_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_MAXBLOCKSIZE) then
  begin
    goto _sw356_case1;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_MINFRAMESIZE) then
  begin
    goto _sw357_case2;
  end;
  goto _sw358_default;
  _sw355_case0:
  goto _sw356_case1;
  _sw356_case1:
  r_2 := TMINIFLACRESULT(miniflac_streaminfo_read_max_block_size(streaminfo, br, PUint16T(Pointer(0))));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _sw357_case2;
  _sw357_case2:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(24)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  t_2 := TUint32T(miniflac_bitreader_read(br, TUint8T(24)));
  if (min_frame_size <> nil) then
  begin
    min_frame_size^ := t_2;
  end;
  streaminfo^.state := MINIFLAC_STREAMINFO_MAXFRAMESIZE;
  Result := MINIFLAC_OK;
  System.Exit;
  _sw358_default:
  goto _sw354_end;
  _sw354_end:
  Result := MINIFLAC_ERROR;
end;

function miniflac_streaminfo_read_max_frame_size(streaminfo: PMiniflacStreaminfoT; br: PMiniflacBitreaderT; max_frame_size: PUint32T): TMINIFLACRESULT;
label _sw359_end, _sw360_case0, _sw361_case1, _sw362_case2, _sw363_case3, _sw364_default;
var
  t_2: TUint32T;
  r_2: TMINIFLACRESULT;
  __c2p_tmp1: LongInt;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
  __c2p_tmp1 := streaminfo^.state;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_MINBLOCKSIZE) then
  begin
    goto _sw360_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_MAXBLOCKSIZE) then
  begin
    goto _sw361_case1;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_MINFRAMESIZE) then
  begin
    goto _sw362_case2;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_MAXFRAMESIZE) then
  begin
    goto _sw363_case3;
  end;
  goto _sw364_default;
  _sw360_case0:
  goto _sw361_case1;
  _sw361_case1:
  goto _sw362_case2;
  _sw362_case2:
  r_2 := TMINIFLACRESULT(miniflac_streaminfo_read_min_frame_size(streaminfo, br, PUint32T(Pointer(0))));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _sw363_case3;
  _sw363_case3:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(24)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  t_2 := TUint32T(miniflac_bitreader_read(br, TUint8T(24)));
  if (max_frame_size <> nil) then
  begin
    max_frame_size^ := t_2;
  end;
  streaminfo^.state := MINIFLAC_STREAMINFO_SAMPLERATE;
  Result := MINIFLAC_OK;
  System.Exit;
  _sw364_default:
  goto _sw359_end;
  _sw359_end:
  Result := MINIFLAC_ERROR;
end;

function miniflac_streaminfo_read_sample_rate(streaminfo: PMiniflacStreaminfoT; br: PMiniflacBitreaderT; sample_rate: PUint32T): TMINIFLACRESULT;
label _sw365_end, _sw366_case0, _sw367_case1, _sw368_case2, _sw369_case3, _sw370_case4, _sw371_default;
var
  r_2: TMINIFLACRESULT;
  __c2p_tmp1: LongInt;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
  __c2p_tmp1 := streaminfo^.state;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_MINBLOCKSIZE) then
  begin
    goto _sw366_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_MAXBLOCKSIZE) then
  begin
    goto _sw367_case1;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_MINFRAMESIZE) then
  begin
    goto _sw368_case2;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_MAXFRAMESIZE) then
  begin
    goto _sw369_case3;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_SAMPLERATE) then
  begin
    goto _sw370_case4;
  end;
  goto _sw371_default;
  _sw366_case0:
  goto _sw367_case1;
  _sw367_case1:
  goto _sw368_case2;
  _sw368_case2:
  goto _sw369_case3;
  _sw369_case3:
  r_2 := TMINIFLACRESULT(miniflac_streaminfo_read_max_frame_size(streaminfo, br, PUint32T(Pointer(0))));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _sw370_case4;
  _sw370_case4:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(20)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  streaminfo^.sample_rate := TUint32T(miniflac_bitreader_read(br, TUint8T(20)));
  if (sample_rate <> nil) then
  begin
    sample_rate^ := streaminfo^.sample_rate;
  end;
  streaminfo^.state := MINIFLAC_STREAMINFO_CHANNELS_CONST;
  Result := MINIFLAC_OK;
  System.Exit;
  _sw371_default:
  goto _sw365_end;
  _sw365_end:
  Result := MINIFLAC_ERROR;
end;

function miniflac_streaminfo_read_channels(streaminfo: PMiniflacStreaminfoT; br: PMiniflacBitreaderT; channels: PUint8T): TMINIFLACRESULT;
label _sw372_end, _sw373_case0, _sw374_case1, _sw375_case2, _sw376_case3, _sw377_case4, _sw378_case5, _sw379_default;
var
  t_2: TUint8T;
  r_2: TMINIFLACRESULT;
  __c2p_tmp1: LongInt;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
  __c2p_tmp1 := streaminfo^.state;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_MINBLOCKSIZE) then
  begin
    goto _sw373_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_MAXBLOCKSIZE) then
  begin
    goto _sw374_case1;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_MINFRAMESIZE) then
  begin
    goto _sw375_case2;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_MAXFRAMESIZE) then
  begin
    goto _sw376_case3;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_SAMPLERATE) then
  begin
    goto _sw377_case4;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_CHANNELS_CONST) then
  begin
    goto _sw378_case5;
  end;
  goto _sw379_default;
  _sw373_case0:
  goto _sw374_case1;
  _sw374_case1:
  goto _sw375_case2;
  _sw375_case2:
  goto _sw376_case3;
  _sw376_case3:
  goto _sw377_case4;
  _sw377_case4:
  r_2 := TMINIFLACRESULT(miniflac_streaminfo_read_sample_rate(streaminfo, br, PUint32T(Pointer(0))));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _sw378_case5;
  _sw378_case5:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(3)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  t_2 := TUint8T((LongInt(TUint8T(miniflac_bitreader_read(br, TUint8T(3)))) + 1));
  if (channels <> nil) then
  begin
    channels^ := TUint8T(t_2);
  end;
  streaminfo^.state := MINIFLAC_STREAMINFO_BPS_CONST;
  Result := MINIFLAC_OK;
  System.Exit;
  _sw379_default:
  goto _sw372_end;
  _sw372_end:
  Result := MINIFLAC_ERROR;
end;

function miniflac_streaminfo_read_bps(streaminfo: PMiniflacStreaminfoT; br: PMiniflacBitreaderT; bps_2: PUint8T): TMINIFLACRESULT;
label _sw380_end, _sw381_case0, _sw382_case1, _sw383_case2, _sw384_case3, _sw385_case4, _sw386_case5, _sw387_case6, _sw388_default;
var
  r_2: TMINIFLACRESULT;
  __c2p_tmp1: LongInt;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
  __c2p_tmp1 := streaminfo^.state;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_MINBLOCKSIZE) then
  begin
    goto _sw381_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_MAXBLOCKSIZE) then
  begin
    goto _sw382_case1;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_MINFRAMESIZE) then
  begin
    goto _sw383_case2;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_MAXFRAMESIZE) then
  begin
    goto _sw384_case3;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_SAMPLERATE) then
  begin
    goto _sw385_case4;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_CHANNELS_CONST) then
  begin
    goto _sw386_case5;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_BPS_CONST) then
  begin
    goto _sw387_case6;
  end;
  goto _sw388_default;
  _sw381_case0:
  goto _sw382_case1;
  _sw382_case1:
  goto _sw383_case2;
  _sw383_case2:
  goto _sw384_case3;
  _sw384_case3:
  goto _sw385_case4;
  _sw385_case4:
  goto _sw386_case5;
  _sw386_case5:
  r_2 := TMINIFLACRESULT(miniflac_streaminfo_read_channels(streaminfo, br, PUint8T(Pointer(0))));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _sw387_case6;
  _sw387_case6:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(5)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  streaminfo^.bps := TUint8T((LongInt(TUint8T(miniflac_bitreader_read(br, TUint8T(5)))) + 1));
  if (bps_2 <> nil) then
  begin
    bps_2^ := TUint8T(streaminfo^.bps);
  end;
  streaminfo^.state := MINIFLAC_STREAMINFO_TOTALSAMPLES;
  Result := MINIFLAC_OK;
  System.Exit;
  _sw388_default:
  goto _sw380_end;
  _sw380_end:
  Result := MINIFLAC_ERROR;
end;

function miniflac_streaminfo_read_total_samples(streaminfo: PMiniflacStreaminfoT; br: PMiniflacBitreaderT; total_samples: PUint64T): TMINIFLACRESULT;
label _sw389_end, _sw390_case0, _sw391_case1, _sw392_case2, _sw393_case3, _sw394_case4, _sw395_case5, _sw396_case6, _sw397_case7, _sw398_default;
var
  t_2: TUint64T;
  r_2: TMINIFLACRESULT;
  __c2p_tmp1: LongInt;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
  __c2p_tmp1 := streaminfo^.state;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_MINBLOCKSIZE) then
  begin
    goto _sw390_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_MAXBLOCKSIZE) then
  begin
    goto _sw391_case1;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_MINFRAMESIZE) then
  begin
    goto _sw392_case2;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_MAXFRAMESIZE) then
  begin
    goto _sw393_case3;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_SAMPLERATE) then
  begin
    goto _sw394_case4;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_CHANNELS_CONST) then
  begin
    goto _sw395_case5;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_BPS_CONST) then
  begin
    goto _sw396_case6;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_TOTALSAMPLES) then
  begin
    goto _sw397_case7;
  end;
  goto _sw398_default;
  _sw390_case0:
  goto _sw391_case1;
  _sw391_case1:
  goto _sw392_case2;
  _sw392_case2:
  goto _sw393_case3;
  _sw393_case3:
  goto _sw394_case4;
  _sw394_case4:
  goto _sw395_case5;
  _sw395_case5:
  goto _sw396_case6;
  _sw396_case6:
  r_2 := TMINIFLACRESULT(miniflac_streaminfo_read_bps(streaminfo, br, PUint8T(Pointer(0))));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _sw397_case7;
  _sw397_case7:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(36)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  t_2 := TUint64T(miniflac_bitreader_read(br, TUint8T(36)));
  if (total_samples <> nil) then
  begin
    total_samples^ := t_2;
  end;
  streaminfo^.state := MINIFLAC_STREAMINFO_MD5;
  Result := MINIFLAC_OK;
  System.Exit;
  _sw398_default:
  goto _sw389_end;
  _sw389_end:
  Result := MINIFLAC_ERROR;
end;

function miniflac_streaminfo_read_md5_length(streaminfo: PMiniflacStreaminfoT; br: PMiniflacBitreaderT; md5_len: PUint32T): TMINIFLACRESULT;
label _sw399_end, _sw400_case0, _sw401_case1, _sw402_case2, _sw403_case3, _sw404_case4, _sw405_case5, _sw406_case6, _sw407_case7, _sw408_default;
var
  r_2: TMINIFLACRESULT;
  __c2p_tmp1: LongInt;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
  __c2p_tmp1 := streaminfo^.state;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_MINBLOCKSIZE) then
  begin
    goto _sw400_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_MAXBLOCKSIZE) then
  begin
    goto _sw401_case1;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_MINFRAMESIZE) then
  begin
    goto _sw402_case2;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_MAXFRAMESIZE) then
  begin
    goto _sw403_case3;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_SAMPLERATE) then
  begin
    goto _sw404_case4;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_CHANNELS_CONST) then
  begin
    goto _sw405_case5;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_BPS_CONST) then
  begin
    goto _sw406_case6;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_TOTALSAMPLES) then
  begin
    goto _sw407_case7;
  end;
  goto _sw408_default;
  _sw400_case0:
  goto _sw401_case1;
  _sw401_case1:
  goto _sw402_case2;
  _sw402_case2:
  goto _sw403_case3;
  _sw403_case3:
  goto _sw404_case4;
  _sw404_case4:
  goto _sw405_case5;
  _sw405_case5:
  goto _sw406_case6;
  _sw406_case6:
  goto _sw407_case7;
  _sw407_case7:
  r_2 := TMINIFLACRESULT(miniflac_streaminfo_read_total_samples(streaminfo, br, PUint64T(Pointer(0))));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _sw408_default;
  _sw408_default:
  goto _sw399_end;
  _sw399_end:
  if (md5_len <> nil) then
  begin
    md5_len^ := TUint32T(16);
  end;
  Result := MINIFLAC_OK;
end;

function miniflac_streaminfo_read_md5_data(streaminfo: PMiniflacStreaminfoT; br: PMiniflacBitreaderT; output: PUint8T; length: TUint32T; outlen: PUint32T): TMINIFLACRESULT;
label _sw409_end, _sw410_case0, _sw411_case1, _sw412_case2, _sw413_case3, _sw414_case4, _sw415_case5, _sw416_case6, _sw417_case7, _sw418_case8, _sw419_default;
var
  r_2: TMINIFLACRESULT;
  t_2: TUint8T;
  __c2p_tmp1: LongInt;
  __c2p_tmp2: LongWord;
begin
  r_2 := TMINIFLACRESULT(MINIFLAC_ERROR);
  __c2p_tmp1 := streaminfo^.state;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_MINBLOCKSIZE) then
  begin
    goto _sw410_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_MAXBLOCKSIZE) then
  begin
    goto _sw411_case1;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_MINFRAMESIZE) then
  begin
    goto _sw412_case2;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_MAXFRAMESIZE) then
  begin
    goto _sw413_case3;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_SAMPLERATE) then
  begin
    goto _sw414_case4;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_CHANNELS_CONST) then
  begin
    goto _sw415_case5;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_BPS_CONST) then
  begin
    goto _sw416_case6;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_TOTALSAMPLES) then
  begin
    goto _sw417_case7;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMINFO_MD5) then
  begin
    goto _sw418_case8;
  end;
  goto _sw419_default;
  _sw410_case0:
  goto _sw411_case1;
  _sw411_case1:
  goto _sw412_case2;
  _sw412_case2:
  goto _sw413_case3;
  _sw413_case3:
  goto _sw414_case4;
  _sw414_case4:
  goto _sw415_case5;
  _sw415_case5:
  goto _sw416_case6;
  _sw416_case6:
  goto _sw417_case7;
  _sw417_case7:
  r_2 := TMINIFLACRESULT(miniflac_streaminfo_read_total_samples(streaminfo, br, PUint64T(Pointer(0))));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  goto _sw418_case8;
  _sw418_case8:
  if (streaminfo^.pos = 16) then
  begin
    Result := MINIFLAC_METADATA_END;
    System.Exit;
  end;
  while (streaminfo^.pos < 16) do
  begin
    if (miniflac_bitreader_fill_nocrc(br, TUint8T(8)) <> 0) then
    begin
      Result := MINIFLAC_CONTINUE;
      System.Exit;
    end;
    t_2 := TUint8T(miniflac_bitreader_read(br, TUint8T(8)));
    if ((output <> nil) and (LongWord(streaminfo^.pos) < length)) then
    begin
      output[LongInt(streaminfo^.pos)] := TUint8T(t_2);
    end;
    streaminfo^.pos := TUint8T((LongInt(streaminfo^.pos) + 1));
  end;
  if (outlen <> nil) then
  begin
    if (LongWord(16) < length) then
    begin
      __c2p_tmp2 := LongWord(16);
    end
    else
    begin
      __c2p_tmp2 := length;
    end;
    outlen^ := __c2p_tmp2;
  end;
  Result := MINIFLAC_OK;
  System.Exit;
  _sw419_default:
  goto _sw409_end;
  _sw409_end:
  Result := MINIFLAC_ERROR;
end;

procedure miniflac_streammarker_init(streammarker: PMiniflacStreammarkerT); inline;
begin
  streammarker^.state := MINIFLAC_STREAMMARKER_F;
end;

function miniflac_streammarker_decode(streammarker: PMiniflacStreammarkerT; br: PMiniflacBitreaderT): TMINIFLACRESULT;
label _sw420_end, _sw421_case0, _sw422_case1, _sw423_case2, _sw424_case3, _sw425_default;
var
  t_2: AnsiChar;
  __c2p_tmp1: LongInt;
begin
  __c2p_tmp1 := streammarker^.state;
  if (__c2p_tmp1 = MINIFLAC_STREAMMARKER_F) then
  begin
    goto _sw421_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMMARKER_L) then
  begin
    goto _sw422_case1;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMMARKER_A) then
  begin
    goto _sw423_case2;
  end;
  if (__c2p_tmp1 = MINIFLAC_STREAMMARKER_C) then
  begin
    goto _sw424_case3;
  end;
  goto _sw425_default;
  _sw421_case0:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(8)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  t_2 := AnsiChar(miniflac_bitreader_read(br, TUint8T(8)));
  if (t_2 <> AnsiChar(102)) then
  begin
    Result := MINIFLAC_STREAMMARKER_INVALID;
    System.Exit;
  end;
  streammarker^.state := MINIFLAC_STREAMMARKER_L;
  goto _sw422_case1;
  _sw422_case1:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(8)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  t_2 := AnsiChar(miniflac_bitreader_read(br, TUint8T(8)));
  if (t_2 <> AnsiChar(76)) then
  begin
    Result := MINIFLAC_STREAMMARKER_INVALID;
    System.Exit;
  end;
  streammarker^.state := MINIFLAC_STREAMMARKER_A;
  goto _sw423_case2;
  _sw423_case2:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(8)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  t_2 := AnsiChar(miniflac_bitreader_read(br, TUint8T(8)));
  if (t_2 <> AnsiChar(97)) then
  begin
    Result := MINIFLAC_STREAMMARKER_INVALID;
    System.Exit;
  end;
  streammarker^.state := MINIFLAC_STREAMMARKER_C;
  goto _sw424_case3;
  _sw424_case3:
  if (miniflac_bitreader_fill_nocrc(br, TUint8T(8)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  t_2 := AnsiChar(miniflac_bitreader_read(br, TUint8T(8)));
  if (t_2 <> AnsiChar(67)) then
  begin
    Result := MINIFLAC_STREAMMARKER_INVALID;
    System.Exit;
  end;
  goto _sw420_end;
  _sw425_default:
  Result := MINIFLAC_ERROR;
  System.Exit;
  _sw420_end:
  miniflac_streammarker_init(streammarker);
  br^.crc8 := TUint8T(0);
  br^.crc16 := TUint16T(0);
  Result := MINIFLAC_OK;
end;

procedure miniflac_subframe_init(subframe: PMiniflacSubframeT); inline;
begin
  subframe^.bps := TUint8T(0);
  subframe^.state := MINIFLAC_SUBFRAME_HEADER;
  miniflac_subframe_header_init(@subframe^.header);
  miniflac_subframe_constant_init(@subframe^.constant);
  miniflac_subframe_verbatim_init(@subframe^.verbatim);
  miniflac_subframe_fixed_init(@subframe^.fixed);
  miniflac_subframe_lpc_init(@subframe^.lpc);
  miniflac_residual_init(@subframe^.residual);
end;

function miniflac_subframe_decode(subframe: PMiniflacSubframeT; br: PMiniflacBitreaderT; output: PInt32T; block_size: TUint32T; bps_2: TUint8T): TMINIFLACRESULT; inline;
label _L_miniflac_subframe_constant, _L_miniflac_subframe_verbatim, _L_miniflac_subframe_fixed, _L_miniflac_subframe_lpc, _sw426_end, _L__for0_step;
var
  r_2: TMINIFLACRESULT;
  i_2: TUint32T;
  __c2p_tmp1: LongInt;
  __c2p_tmp2: LongInt;
begin
  __c2p_tmp1 := subframe^.state;
  case __c2p_tmp1 of
    MINIFLAC_SUBFRAME_HEADER:
    begin
      r_2 := TMINIFLACRESULT(miniflac_subframe_header_decode(@subframe^.header, br));
      if (LongInt(r_2) <> MINIFLAC_OK) then
      begin
        Result := TMINIFLACRESULT(r_2);
        System.Exit;
      end;
      subframe^.bps := TUint8T((LongInt(bps_2) - LongInt(subframe^.header.wasted_bits)));
      __c2p_tmp2 := subframe^.header.&type;
      case __c2p_tmp2 of
        MINIFLAC_SUBFRAME_TYPE_CONSTANT:
        begin
          miniflac_subframe_constant_init(@subframe^.constant);
          subframe^.state := MINIFLAC_SUBFRAME_CONSTANT;
          goto _L_miniflac_subframe_constant;
        end;
        MINIFLAC_SUBFRAME_TYPE_VERBATIM:
        begin
          miniflac_subframe_verbatim_init(@subframe^.verbatim);
          subframe^.state := MINIFLAC_SUBFRAME_VERBATIM;
          goto _L_miniflac_subframe_verbatim;
        end;
        MINIFLAC_SUBFRAME_TYPE_FIXED:
        begin
          miniflac_residual_init(@subframe^.residual);
          miniflac_subframe_fixed_init(@subframe^.fixed);
          subframe^.state := MINIFLAC_SUBFRAME_FIXED;
          goto _L_miniflac_subframe_fixed;
        end;
        MINIFLAC_SUBFRAME_TYPE_LPC:
        begin
          miniflac_residual_init(@subframe^.residual);
          miniflac_subframe_lpc_init(@subframe^.lpc);
          subframe^.state := MINIFLAC_SUBFRAME_LPC;
          goto _L_miniflac_subframe_lpc;
        end;
      else
      begin
        Result := MINIFLAC_ERROR;
        System.Exit;
      end
      end;
      goto _sw426_end;
    end;
    MINIFLAC_SUBFRAME_CONSTANT:
    begin
      _L_miniflac_subframe_constant:
      r_2 := TMINIFLACRESULT(miniflac_subframe_constant_decode(@subframe^.constant, br, output, TUint32T(block_size), TUint8T(subframe^.bps)));
      if (LongInt(r_2) <> MINIFLAC_OK) then
      begin
        Result := TMINIFLACRESULT(r_2);
        System.Exit;
      end;
      goto _sw426_end;
    end;
    MINIFLAC_SUBFRAME_VERBATIM:
    begin
      _L_miniflac_subframe_verbatim:
      r_2 := TMINIFLACRESULT(miniflac_subframe_verbatim_decode(@subframe^.verbatim, br, output, TUint32T(block_size), TUint8T(subframe^.bps)));
      if (LongInt(r_2) <> MINIFLAC_OK) then
      begin
        Result := TMINIFLACRESULT(r_2);
        System.Exit;
      end;
      goto _sw426_end;
    end;
    MINIFLAC_SUBFRAME_FIXED:
    begin
      _L_miniflac_subframe_fixed:
      r_2 := TMINIFLACRESULT(miniflac_subframe_fixed_decode(@subframe^.fixed, br, output, TUint32T(block_size), TUint8T(subframe^.bps), @subframe^.residual, TUint8T(subframe^.header.order)));
      if (LongInt(r_2) <> MINIFLAC_OK) then
      begin
        Result := TMINIFLACRESULT(r_2);
        System.Exit;
      end;
      goto _sw426_end;
    end;
    MINIFLAC_SUBFRAME_LPC:
    begin
      _L_miniflac_subframe_lpc:
      r_2 := TMINIFLACRESULT(miniflac_subframe_lpc_decode(@subframe^.lpc, br, output, TUint32T(block_size), TUint8T(subframe^.bps), @subframe^.residual, TUint8T(subframe^.header.order)));
      if (LongInt(r_2) <> MINIFLAC_OK) then
      begin
        Result := TMINIFLACRESULT(r_2);
        System.Exit;
      end;
      goto _sw426_end;
    end;
  else
  begin
    goto _sw426_end;
  end
  end;
  _sw426_end:
  if ((output <> nil) and (subframe^.header.wasted_bits > 0)) then
  begin
{$ifdef FLAC_SIMD_ON}
{$ifdef cpuaarch64}
    flac_wasted_bits_neon(output, block_size, LongWord(subframe^.header.wasted_bits));
{$else}
    i_2 := TUint32T(0);
    while (i_2 < block_size) do
    begin
      output[i_2] := (output[i_2] shl subframe^.header.wasted_bits);
      _L__for0_step:
      i_2 := (i_2 + 1);
    end;
{$endif}
{$else}
    i_2 := TUint32T(0);
    while (i_2 < block_size) do
    begin
      output[i_2] := (output[i_2] shl subframe^.header.wasted_bits);
      _L__for0_step:
      i_2 := (i_2 + 1);
    end;
{$endif}
  end;
  miniflac_subframe_init(subframe);
  Result := MINIFLAC_OK;
end;

procedure miniflac_subframe_constant_init(c_2: PMiniflacSubframeConstantT); inline;
begin
  c_2^.state := MINIFLAC_SUBFRAME_CONSTANT_DECODE_CONST;
end;

function miniflac_subframe_constant_decode(c_2: PMiniflacSubframeConstantT; br: PMiniflacBitreaderT; output: PInt32T; block_size: TUint32T; bps_2: TUint8T): TMINIFLACRESULT; inline;
label _L__for0_step;
var
  sample_2: TInt32T;
  i_2: TUint32T;
begin
  if (miniflac_bitreader_fill(br, TUint8T(bps_2)) <> 0) then
  begin
    Result := MINIFLAC_CONTINUE;
    System.Exit;
  end;
  sample_2 := TInt32T(miniflac_bitreader_read_signed(br, TUint8T(bps_2)));
  if (output <> nil) then
  begin
    i_2 := TUint32T(0);
    while (i_2 < block_size) do
    begin
      output[i_2] := TInt32T(sample_2);
      _L__for0_step:
      i_2 := (i_2 + 1);
    end;
  end;
  Result := MINIFLAC_OK;
end;

procedure miniflac_subframe_fixed_init(f_2: PMiniflacSubframeFixedT); inline;
begin
  f_2^.pos := TUint32T(0);
  f_2^.state := MINIFLAC_SUBFRAME_FIXED_DECODE_CONST;
end;

procedure miniflac_subframe_fixed_decode__c2p_case_helper_2(var f_2: PMiniflacSubframeFixedT; var output: PInt32T; block_size: TUint32T; predictor_order: TUint8T; var sample1_2: TInt64T; var current_residual: TInt64T); inline;
label _L__for0_step;
begin
  f_2^.pos := TUint32T(predictor_order);
  while (f_2^.pos < block_size) do
  begin
    current_residual := TInt64T(output[f_2^.pos]);
    sample1_2 := TInt64T(output[LongWord((f_2^.pos - 1))]);
    output[f_2^.pos] := TInt32T((sample1_2 + current_residual));
    _L__for0_step:
    f_2^.pos := (f_2^.pos + 1);
  end;
end;

procedure miniflac_subframe_fixed_decode__c2p_case_helper_3(var f_2: PMiniflacSubframeFixedT; var output: PInt32T; block_size: TUint32T; predictor_order: TUint8T; var sample1_2: TInt64T; var sample2_2: TInt64T; var current_residual: TInt64T); inline;
label _L__for1_step;
begin
  f_2^.pos := TUint32T(predictor_order);
  while (f_2^.pos < block_size) do
  begin
    current_residual := TInt64T(output[f_2^.pos]);
    sample1_2 := TInt64T(output[LongWord((f_2^.pos - 1))]);
    sample2_2 := TInt64T(output[LongWord((f_2^.pos - LongWord(2)))]);
    sample1_2 := (sample1_2 * Int64(2));
    output[f_2^.pos] := TInt32T(((sample1_2 - sample2_2) + current_residual));
    _L__for1_step:
    f_2^.pos := (f_2^.pos + 1);
  end;
end;

procedure miniflac_subframe_fixed_decode__c2p_case_helper_4(var f_2: PMiniflacSubframeFixedT; var output: PInt32T; block_size: TUint32T; predictor_order: TUint8T; var sample1_2: TInt64T; var sample2_2: TInt64T; var sample3_2: TInt64T; var current_residual: TInt64T); inline;
label _L__for2_step;
begin
  f_2^.pos := TUint32T(predictor_order);
  while (f_2^.pos < block_size) do
  begin
    current_residual := TInt64T(output[f_2^.pos]);
    sample1_2 := TInt64T(output[LongWord((f_2^.pos - 1))]);
    sample2_2 := TInt64T(output[LongWord((f_2^.pos - LongWord(2)))]);
    sample3_2 := TInt64T(output[LongWord((f_2^.pos - LongWord(3)))]);
    sample1_2 := (sample1_2 * Int64(3));
    sample2_2 := (sample2_2 * Int64(3));
    output[f_2^.pos] := TInt32T((((sample1_2 - sample2_2) + sample3_2) + current_residual));
    _L__for2_step:
    f_2^.pos := (f_2^.pos + 1);
  end;
end;

procedure miniflac_subframe_fixed_decode__c2p_case_helper_5(var f_2: PMiniflacSubframeFixedT; var output: PInt32T; block_size: TUint32T; predictor_order: TUint8T; var sample1_2: TInt64T; var sample2_2: TInt64T; var sample3_2: TInt64T; var current_residual: TInt64T); inline;
label _L__for3_step;
var
  sample4_2: TInt64T;
begin
  f_2^.pos := TUint32T(predictor_order);
  while (f_2^.pos < block_size) do
  begin
    current_residual := TInt64T(output[f_2^.pos]);
    sample1_2 := TInt64T(output[LongWord((f_2^.pos - 1))]);
    sample2_2 := TInt64T(output[LongWord((f_2^.pos - LongWord(2)))]);
    sample3_2 := TInt64T(output[LongWord((f_2^.pos - LongWord(3)))]);
    sample4_2 := TInt64T(output[LongWord((f_2^.pos - LongWord(4)))]);
    sample1_2 := (sample1_2 * Int64(4));
    sample2_2 := (sample2_2 * Int64(6));
    sample3_2 := (sample3_2 * Int64(4));
    output[f_2^.pos] := TInt32T(((((sample1_2 - sample2_2) + sample3_2) - sample4_2) + current_residual));
    _L__for3_step:
    f_2^.pos := (f_2^.pos + 1);
  end;
end;

function miniflac_subframe_fixed_decode(f_2: PMiniflacSubframeFixedT; br: PMiniflacBitreaderT; output: PInt32T; block_size: TUint32T; bps_2: TUint8T; residual: PMiniflacResidualT; predictor_order: TUint8T): TMINIFLACRESULT; inline;
label _sw428_end;
var
  sample_2: TInt32T;
  sample1_2: TInt64T;
  sample2_2: TInt64T;
  sample3_2: TInt64T;
  current_residual: TInt64T;
  r_2: TMINIFLACRESULT;
  __c2p_tmp1: LongInt;
begin
  while (f_2^.pos < LongWord(predictor_order)) do
  begin
    if (miniflac_bitreader_fill(br, TUint8T(bps_2)) <> 0) then
    begin
      Result := MINIFLAC_CONTINUE;
      System.Exit;
    end;
    sample_2 := TInt32T(miniflac_bitreader_read_signed(br, TUint8T(bps_2)));
    if (output <> nil) then
    begin
      output[f_2^.pos] := TInt32T(sample_2);
    end;
    f_2^.pos := (f_2^.pos + 1);
  end;
  r_2 := TMINIFLACRESULT(miniflac_residual_decode(residual, br, @f_2^.pos, TUint32T(block_size), TUint8T(predictor_order), output));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  if (output <> nil) then
  begin
    __c2p_tmp1 := LongInt(predictor_order);
    case __c2p_tmp1 of
      0:
      begin
      end;
      1:
      begin
        miniflac_subframe_fixed_decode__c2p_case_helper_2(f_2, output, block_size, predictor_order, sample1_2, current_residual);
      end;
      2:
      begin
        miniflac_subframe_fixed_decode__c2p_case_helper_3(f_2, output, block_size, predictor_order, sample1_2, sample2_2, current_residual);
      end;
      3:
      begin
        miniflac_subframe_fixed_decode__c2p_case_helper_4(f_2, output, block_size, predictor_order, sample1_2, sample2_2, sample3_2, current_residual);
      end;
      4:
      begin
        miniflac_subframe_fixed_decode__c2p_case_helper_5(f_2, output, block_size, predictor_order, sample1_2, sample2_2, sample3_2, current_residual);
      end;
    else
    begin
    end
    end;
    _sw428_end:
  end;
  Result := MINIFLAC_OK;
end;

procedure miniflac_subframe_header_init(subframeheader: PMiniflacSubframeHeaderT); inline;
begin
  subframeheader^.state := MINIFLAC_SUBFRAME_HEADER_RESERVEBIT1;
  subframeheader^.&type := MINIFLAC_SUBFRAME_TYPE_UNKNOWN;
  subframeheader^.order := TUint8T(0);
  subframeheader^.wasted_bits := TUint8T(0);
  subframeheader^.type_raw := TUint8T(0);
end;

function miniflac_subframe_header_decode(subframeheader: PMiniflacSubframeHeaderT; br: PMiniflacBitreaderT): TMINIFLACRESULT;
label _sw429_end, _sw430_case0, _sw431_case1, _sw432_case2, _sw433_case3, _sw434_default;
var
  t_2: TUint64T;
  __c2p_tmp1: LongInt;
begin
  t_2 := TUint64T(0);
  __c2p_tmp1 := subframeheader^.state;
  if (__c2p_tmp1 = MINIFLAC_SUBFRAME_HEADER_RESERVEBIT1) then
  begin
    goto _sw430_case0;
  end;
  if (__c2p_tmp1 = MINIFLAC_SUBFRAME_HEADER_KIND) then
  begin
    goto _sw431_case1;
  end;
  if (__c2p_tmp1 = MINIFLAC_SUBFRAME_HEADER_WASTED_BITS) then
  begin
    goto _sw432_case2;
  end;
  if (__c2p_tmp1 = MINIFLAC_SUBFRAME_HEADER_UNARY) then
  begin
    goto _sw433_case3;
  end;
  goto _sw434_default;
  _sw430_case0:
  if (miniflac_bitreader_fill(br, TUint8T(1)) <> 0) then
  begin
    goto _sw429_end;
  end;
  t_2 := miniflac_bitreader_read(br, TUint8T(1));
  if (t_2 <> QWord(0)) then
  begin
    Result := MINIFLAC_SUBFRAME_RESERVED_BIT;
    System.Exit;
  end;
  subframeheader^.state := MINIFLAC_SUBFRAME_HEADER_KIND;
  goto _sw431_case1;
  _sw431_case1:
  if (miniflac_bitreader_fill(br, TUint8T(6)) <> 0) then
  begin
    goto _sw429_end;
  end;
  t_2 := TUint64T(TUint8T(miniflac_bitreader_read(br, TUint8T(6))));
  subframeheader^.type_raw := TUint8T(t_2);
  if (t_2 = QWord(0)) then
  begin
    subframeheader^.&type := MINIFLAC_SUBFRAME_TYPE_CONSTANT;
  end
  else
  begin
    if (t_2 = QWord(1)) then
    begin
      subframeheader^.&type := MINIFLAC_SUBFRAME_TYPE_VERBATIM;
    end
    else
    begin
      if (t_2 < QWord(8)) then
      begin
        Result := MINIFLAC_SUBFRAME_RESERVED_TYPE;
        System.Exit;
      end
      else
      begin
        if (t_2 < QWord(13)) then
        begin
          subframeheader^.&type := MINIFLAC_SUBFRAME_TYPE_FIXED;
          subframeheader^.order := TUint8T((t_2 - QWord(8)));
        end
        else
        begin
          if (t_2 < QWord(32)) then
          begin
            Result := MINIFLAC_SUBFRAME_RESERVED_TYPE;
            System.Exit;
          end
          else
          begin
            subframeheader^.&type := MINIFLAC_SUBFRAME_TYPE_LPC;
            subframeheader^.order := TUint8T((t_2 - QWord(31)));
          end;
        end;
      end;
    end;
  end;
  subframeheader^.state := MINIFLAC_SUBFRAME_HEADER_WASTED_BITS;
  goto _sw432_case2;
  _sw432_case2:
  if (miniflac_bitreader_fill(br, TUint8T(1)) <> 0) then
  begin
    goto _sw429_end;
  end;
  subframeheader^.wasted_bits := TUint8T(0);
  t_2 := miniflac_bitreader_read(br, TUint8T(1));
  if (t_2 = QWord(0)) then
  begin
    subframeheader^.state := MINIFLAC_SUBFRAME_HEADER_RESERVEBIT1;
    Result := MINIFLAC_OK;
    System.Exit;
  end;
  subframeheader^.state := MINIFLAC_SUBFRAME_HEADER_UNARY;
  goto _sw433_case3;
  _sw433_case3:
  while (miniflac_bitreader_fill(br, TUint8T(1)) = 0) do
  begin
    subframeheader^.wasted_bits := TUint8T((LongInt(subframeheader^.wasted_bits) + 1));
    t_2 := miniflac_bitreader_read(br, TUint8T(1));
    if (t_2 = QWord(1)) then
    begin
      subframeheader^.state := MINIFLAC_SUBFRAME_HEADER_RESERVEBIT1;
      Result := MINIFLAC_OK;
      System.Exit;
    end;
  end;
  goto _sw434_default;
  _sw434_default:
  goto _sw429_end;
  _sw429_end:
  Result := MINIFLAC_CONTINUE;
end;

procedure miniflac_subframe_lpc_init(l: PMiniflacSubframeLpcT); inline;
label _L__for0_step;
var
  i_2: LongWord;
begin
  l^.pos := TUint32T(0);
  l^.precision := TUint8T(0);
  l^.shift := TUint8T(0);
  l^.coeff := TUint8T(0);
  i_2 := LongWord(0);
  while (i_2 < LongWord(32)) do
  begin
    l^.coefficients[i_2] := TInt32T(0);
    _L__for0_step:
    i_2 := (i_2 + 1);
  end;
  l^.state := MINIFLAC_SUBFRAME_LPC_PRECISION;
end;

{$push}
{$hints off}
{$warnings off}
function miniflac_subframe_lpc_decode(l: PMiniflacSubframeLpcT; br: PMiniflacBitreaderT; output: PInt32T; block_size: TUint32T; bps_2: TUint8T; residual: PMiniflacResidualT; predictor_order: TUint8T): TMINIFLACRESULT;
label _L__for0_step, _L__for1_step;
var
  sample_2: TInt32T;
  temp_2: TInt64T;
  prediction_2: TInt64T;
  i_2: TUint32T;
  j_2: TUint32T;
  r_2: TMINIFLACRESULT;
  __c2p_tmp1: TUint8T;
begin
  while (l^.pos < LongWord(predictor_order)) do
  begin
    if (miniflac_bitreader_fill(br, TUint8T(bps_2)) <> 0) then
    begin
      Result := MINIFLAC_CONTINUE;
      System.Exit;
    end;
    sample_2 := TInt32T(miniflac_bitreader_read_signed(br, TUint8T(bps_2)));
    if (output <> nil) then
    begin
      output[l^.pos] := TInt32T(sample_2);
    end;
    l^.pos := (l^.pos + 1);
    l^.state := MINIFLAC_SUBFRAME_LPC_PRECISION;
  end;
  if (LongInt(l^.state) = MINIFLAC_SUBFRAME_LPC_PRECISION) then
  begin
    if (miniflac_bitreader_fill(br, TUint8T(4)) <> 0) then
    begin
      Result := MINIFLAC_CONTINUE;
      System.Exit;
    end;
    l^.precision := TUint8T((miniflac_bitreader_read(br, TUint8T(4)) + 1));
    l^.state := MINIFLAC_SUBFRAME_LPC_SHIFT;
  end;
  if (LongInt(l^.state) = MINIFLAC_SUBFRAME_LPC_SHIFT) then
  begin
    if (miniflac_bitreader_fill(br, TUint8T(5)) <> 0) then
    begin
      Result := MINIFLAC_CONTINUE;
      System.Exit;
    end;
    temp_2 := TInt64T(miniflac_bitreader_read_signed(br, TUint8T(5)));
    if (temp_2 < Int64(0)) then
    begin
      temp_2 := TInt64T(0);
    end;
    l^.shift := TUint8T(temp_2);
    l^.state := MINIFLAC_SUBFRAME_LPC_COEFF;
  end;
  if (LongInt(l^.state) = MINIFLAC_SUBFRAME_LPC_COEFF) then
  begin
    while (l^.coeff < predictor_order) do
    begin
      if (miniflac_bitreader_fill(br, TUint8T(l^.precision)) <> 0) then
      begin
        Result := MINIFLAC_CONTINUE;
        System.Exit;
      end;
      sample_2 := TInt32T(miniflac_bitreader_read_signed(br, TUint8T(l^.precision)));
      __c2p_tmp1 := l^.coeff;
      l^.coeff := TUint8T((LongInt(l^.coeff) + 1));
      l^.coefficients[LongInt(__c2p_tmp1)] := TInt32T(sample_2);
    end;
  end;
  r_2 := TMINIFLACRESULT(miniflac_residual_decode(residual, br, @l^.pos, TUint32T(block_size), TUint8T(predictor_order), output));
  if (LongInt(r_2) <> MINIFLAC_OK) then
  begin
    Result := TMINIFLACRESULT(r_2);
    System.Exit;
  end;
  if (output <> nil) then
  begin
{$ifdef FLAC_SIMD_ON}
{$ifdef cpuaarch64}
    flac_lpc_restore_neon(PInt32T(output), PInt32T(@l^.coefficients[0]), LongWord(predictor_order), LongWord(l^.shift), LongWord(block_size));
{$else}
    i_2 := TUint32T(predictor_order);
    while (i_2 < block_size) do
    begin
      prediction_2 := TInt64T(0);
      j_2 := TUint32T(0);
      while (j_2 < LongWord(predictor_order)) do
      begin
        temp_2 := TInt64T(output[LongWord((LongWord((i_2 - j_2)) - 1))]);
        temp_2 := (temp_2 * Int64(l^.coefficients[j_2]));
        prediction_2 := (prediction_2 + temp_2);
        _L__for1_step:
        j_2 := (j_2 + 1);
      end;
      prediction_2 := cflac_Sar64(prediction_2, l^.shift);
      prediction_2 := (prediction_2 + Int64(output[i_2]));
      output[i_2] := TInt32T(prediction_2);
      _L__for0_step:
      i_2 := (i_2 + 1);
    end;
{$endif}
{$else}
    i_2 := TUint32T(predictor_order);
    while (i_2 < block_size) do
    begin
      prediction_2 := TInt64T(0);
      j_2 := TUint32T(0);
      while (j_2 < LongWord(predictor_order)) do
      begin
        temp_2 := TInt64T(output[LongWord((LongWord((i_2 - j_2)) - 1))]);
        temp_2 := (temp_2 * Int64(l^.coefficients[j_2]));
        prediction_2 := (prediction_2 + temp_2);
        _L__for1_step:
        j_2 := (j_2 + 1);
      end;
      prediction_2 := cflac_Sar64(prediction_2, l^.shift);
      prediction_2 := (prediction_2 + Int64(output[i_2]));
      output[i_2] := TInt32T(prediction_2);
      _L__for0_step:
      i_2 := (i_2 + 1);
    end;
{$endif}
  end;
  Result := MINIFLAC_OK;
end;
{$pop}

procedure miniflac_subframe_verbatim_init(c_2: PMiniflacSubframeVerbatimT); inline;
begin
  c_2^.pos := TUint32T(0);
  c_2^.state := MINIFLAC_SUBFRAME_VERBATIM_DECODE_CONST;
end;

function miniflac_subframe_verbatim_decode(c_2: PMiniflacSubframeVerbatimT; br: PMiniflacBitreaderT; output: PInt32T; block_size: TUint32T; bps_2: TUint8T): TMINIFLACRESULT; inline;
var
  sample_2: TInt32T;
begin
  while (c_2^.pos < block_size) do
  begin
    if (miniflac_bitreader_fill(br, TUint8T(bps_2)) <> 0) then
    begin
      Result := MINIFLAC_CONTINUE;
      System.Exit;
    end;
    sample_2 := TInt32T(miniflac_bitreader_read_signed(br, TUint8T(bps_2)));
    if (output <> nil) then
    begin
      output[c_2^.pos] := TInt32T(sample_2);
    end;
    c_2^.pos := (c_2^.pos + 1);
  end;
  c_2^.pos := TUint32T(0);
  Result := MINIFLAC_OK;
end;

end.
