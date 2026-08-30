unit nextpas.core.compress.errors;

{$I nextpas.core.settings.inc}

interface

{ 单源错误码：中文主文 + 英文裸串兼容后缀，便于旧 Pos 检测与新中文诊断并存。 }
const
  S_COMPRESS_LZ4_INPUT_SIZE_EXCEEDS_LIMIT        = '[COMPRESS-LZ4-001] lz4输入尺寸超出上限 (lz4: input size exceeds limit)';
  S_COMPRESS_LZ4_ORIGINAL_SIZE_EXCEEDS_LIMIT     = '[COMPRESS-LZ4-002] lz4原始尺寸超出上限 (lz4: original size exceeds limit)';
  S_COMPRESS_LZ4_COMPRESSED_SIZE_EXCEEDS_LIMIT   = '[COMPRESS-LZ4-003] lz4压缩输入尺寸超出上限 (lz4: compressed input size exceeds limit)';
  S_COMPRESS_LZ4_DECOMPRESSED_SIZE_EXCEEDS_LIMIT = '[COMPRESS-LZ4-004] lz4解压尺寸超出上限 (lz4: decompressed size exceeds limit)';
  S_COMPRESS_LZ4_INVALID_ORIGINAL_SIZE           = '[COMPRESS-LZ4-005] lz4原始尺寸无效 (lz4: invalid original size)';
  S_COMPRESS_LZ4_EMPTY_WITH_NONZERO_ORIGINAL     = '[COMPRESS-LZ4-006] lz4空输入但原始尺寸非零 (lz4: empty input with nonzero original size)';
  S_COMPRESS_LZ4_NONEMPTY_WITH_ZERO_ORIGINAL     = '[COMPRESS-LZ4-007] lz4非空输入但原始尺寸为零 (lz4: non-empty input with zero original size)';
  S_COMPRESS_LZ4_UNSUPPORTED_FRAME               = '[COMPRESS-LZ4-008] lz4不支持的帧头 (lz4: unsupported frame/header)';
  S_COMPRESS_LZ4_COMPRESSED_OUTPUT_EXCEEDS_BOUND = '[COMPRESS-LZ4-009] lz4压缩输出超出预估边界 (lz4: compressed output exceeds bound)';
  S_COMPRESS_LZ4_TRUNCATED_LITERAL_LEN           = '[COMPRESS-LZ4-010] lz4截断的字面量长度 (lz4: truncated literal length)';
  S_COMPRESS_LZ4_LITERAL_LEN_OVERFLOW            = '[COMPRESS-LZ4-011] lz4字面量长度溢出 (lz4: literal length overflow)';
  S_COMPRESS_LZ4_LITERAL_OVERFLOW                = '[COMPRESS-LZ4-012] lz4字面量溢出 (lz4: literal overflow)';
  S_COMPRESS_LZ4_OUTPUT_OVERFLOW                 = '[COMPRESS-LZ4-013] lz4输出溢出 (lz4: output overflow)';
  S_COMPRESS_LZ4_TRUNCATED_OFFSET                = '[COMPRESS-LZ4-014] lz4截断的偏移 (lz4: truncated offset)';
  S_COMPRESS_LZ4_ZERO_OFFSET                     = '[COMPRESS-LZ4-015] lz4零偏移 (lz4: zero offset)';
  S_COMPRESS_LZ4_OFFSET_BEFORE_START             = '[COMPRESS-LZ4-016] lz4偏移指向起始前 (lz4: offset before start)';
  S_COMPRESS_LZ4_TRUNCATED_MATCH_LEN             = '[COMPRESS-LZ4-017] lz4截断的匹配长度 (lz4: truncated match length)';
  S_COMPRESS_LZ4_MATCH_LEN_OVERFLOW              = '[COMPRESS-LZ4-018] lz4匹配长度溢出 (lz4: match length overflow)';
  S_COMPRESS_LZ4_SIZE_MISMATCH                   = '[COMPRESS-LZ4-019] lz4解压尺寸不匹配 (lz4: decompressed size mismatch)';
  S_COMPRESS_LZ4_FINAL_LITERAL_TAIL_MISSING      = '[COMPRESS-LZ4-020] lz4最终字面量尾缺失 (lz4: final literal tail missing)';
  S_COMPRESS_LZ4_FINAL_MATCH_TOO_CLOSE           = '[COMPRESS-LZ4-021] lz4最终匹配过于靠近末尾 (lz4: final match too close to end)';
  S_COMPRESS_LZ4_NATIVE_INVALID_INPUT_SIZE       = '[COMPRESS-LZ4-101] lz4 native输入尺寸无效 (lz4 native: invalid input size)';
  S_COMPRESS_LZ4_NATIVE_INVALID_BOUND            = '[COMPRESS-LZ4-102] lz4 native压缩边界无效 (lz4 native: invalid compression bound)';
  S_COMPRESS_LZ4_NATIVE_COMPRESS_FAILED          = '[COMPRESS-LZ4-103] lz4 native压缩失败 (lz4 native: compress failed)';
  S_COMPRESS_LZ4_NATIVE_DECOMPRESS_FAILED        = '[COMPRESS-LZ4-104] lz4 native解压失败 (lz4 native: decompress failed)';
  S_COMPRESS_LZ4_NATIVE_SIZE_MISMATCH            = '[COMPRESS-LZ4-105] lz4 native尺寸不匹配 (lz4 native: size mismatch)';

implementation

end.
