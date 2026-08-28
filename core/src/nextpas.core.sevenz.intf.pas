unit nextpas.core.sevenz.intf;

{**
 * nextpas.core.sevenz.intf - 7z 模块对外契约
 *
 * 定义读端/写端接口与 LZMA 编解码器后端契约。编解码器按用户要求接口化：
 * 纯 Pascal 实现与 liblzma FFI 实现都满足同一契约，运行时可切换。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.sevenz.base,
  nextpas.core.compress.base,
  nextpas.core.sevenz.levels;

const
  {** @desc 过滤链深度上限：远超实际收益，同时远离读端 64 coder 解析上限 *}
  C_MAX_FILTERS = 16;

type
  {** @desc 写端进度回调：ADone / ATotal 为已完成/总 folder 数 *}
  TSevenZProgressEvent = procedure (Sender: TObject; ADone, ATotal: Integer) of object;

  ISevenZReader = interface; { forward for enumerator }

  {** @desc 读端 for..in 枚举器 *}
  TSevenZEntryEnumerator = record
    FReader: ISevenZReader;
    FIndex: Integer;
    function GetCurrent: TSevenZEntryInfo;
    function MoveNext: Boolean;
    property Current: TSevenZEntryInfo read GetCurrent;
  end;

  {** @desc LZMA 编解码后端选择：Auto 按 FFI 可用性自动降级 *}
  TSevenZLzmaBackend = (szlbAuto, szlbPurePascal, szlbFfi);

  {** @desc 写端预过滤器：按声明顺序逐级作用于 solid 数据后再进压缩器。
      均为保长变换，读端按 folder 拓扑自动逆序还原 *}
  TSevenZFilter = (szfBcjX86, szfBcjArm, szfBcjArm64, szfBcjPpc,
    szfBcjIa64, szfBcjSparc, szfBcjArmt, szfBcjRiscv, szfDelta);

  {** @desc LZMA 压缩级别（与 compress 家族语义对齐的子集） *}
  TSevenZCompressionLevel = (szclNone, szclFastest, szclDefault, szclBest);

  {** @desc 编码产物：压缩数据 + coder 属性（LZMA2 一字节 / LZMA1 五字节） *}
  TSevenZLzmaEncoded = record
    PackedData: TBytes;
    Props: TBytes;
  end;

  {** @desc 一次性 LZMA1/LZMA2 解码契约：输入完整码流与精确输出尺寸 *}
  ISevenZLzmaDecoder = interface
    ['{7E1A6E11-3F42-4C8B-9A17-0DE07A000001}']
    function DecodeLzma2(const AProps: TBytes; const APacked: TBytes;
      const AOutSize: SizeUInt): TBytes;
    function DecodeLzma1(const AProps: TBytes; const APacked: TBytes;
      const AOutSize: SizeUInt): TBytes;
  end;

  {** @desc 一次性 LZMA2 编码契约：输出完整 LZMA2 chunk 流与属性字节 *}
  ISevenZLzmaEncoder = interface
    ['{7E1A6E11-3F42-4C8B-9A17-0DE07A000002}']
    function EncodeLzma2(const ARaw: TBytes;
      ALevel: TSevenZCompressionLevel): TSevenZLzmaEncoded;
  end;

  {** @desc 条目信息数组快照 *}
  TSevenZEntryInfoArray = array of TSevenZEntryInfo;

  {** @desc 7z 归档读端：条目枚举与按索引提取（内容以字节返回） *}
  ISevenZReader = interface
    ['{7E1A6E11-3F42-4C8B-9A17-0DE07A000003}']
    {** 条目总数（含目录与空文件） *}
    function EntryCount: Integer;
    {** 第 AIndex 个条目元数据；越界抛参数错误 *}
    function Entry(AIndex: Integer): TSevenZEntryInfo;
    {** 按名称查条目索引；不存在返回 -1 *}
    function Find(const AName: string): Integer;
    {** 大小写不敏感按名称查条目索引；不存在返回 -1 *}
    function FindIgnoreCase(const AName: string): Integer;
    {** 是否包含指定名称的条目 *}
    function Contains(const AName: string): Boolean;
    {** 按名称查条目信息；存在返回 True 并填充 AInfo *}
    function TryGetEntry(const AName: string; out AInfo: TSevenZEntryInfo): Boolean;
    {** TryGetEntry 别名，语义一致 *}
    function TryEntryByName(const AName: string; out AInfo: TSevenZEntryInfo): Boolean;
    {** 按名称直接取条目信息；不存在抛 EArgumentError *}
    function EntryByName(const AName: string): TSevenZEntryInfo;
    function GetIsEmpty: Boolean;
    property IsEmpty: Boolean read GetIsEmpty;
    function GetEntries: TSevenZEntryInfoArray;
    property Entries: TSevenZEntryInfoArray read GetEntries;
    {** 提取文件条目内容并校验 CRC；目录/空文件返回 nil；
        AIndex 越界抛参数错误。重复提取同一 solid 文件夹走缓存 *}
    function Extract(AIndex: Integer): TBytes;
    {** 将文件条目解压流式写入 AWriter，返回写入字节数并校验 CRC *}
    function ExtractTo(const AWriter: IWriter; AIndex: Integer): Int64;
    {** 以只读 IStream 视角打开条目内容：支持 Seek/Size/Position，
        语义与 TBytesStream 对齐（Close 后访问 raise，Close 幂等）。
        目录/空条目得到长度 0 的流；AIndex 越界抛参数错误 *}
    function OpenStream(AIndex: Integer): IStream;
    {** 无异常探针：越界/损坏返回 False，不抛 EArgumentError/ESevenZError；
        成功时 AData 为提取内容（目录/空为 nil），ABytesWritten 为写入数 *}
    function TryExtract(AIndex: Integer; out AData: TBytes): Boolean;
    function TryExtractTo(const AWriter: IWriter; AIndex: Integer;
      out ABytesWritten: Int64): Boolean;
    function TryExtractWithError(AIndex: Integer; out AData: TBytes;
      out AError: string): Boolean;
    function TryExtractToWithError(const AWriter: IWriter; AIndex: Integer;
      out ABytesWritten: Int64; out AError: string): Boolean;
    function TryOpenStream(AIndex: Integer; out AStream: IStream): Boolean;
    function TryOpenStreamWithError(AIndex: Integer; out AStream: IStream;
      out AError: string): Boolean;
    function GetEnumerator: TSevenZEntryEnumerator;
    property Count: Integer read EntryCount;
    property Items[AIndex: Integer]: TSevenZEntryInfo read Entry; default;
  end;

  {** @desc 7z 归档写端：顺序追加条目，Finish 一次性终结产出完整归档 *}
  ISevenZWriter = interface
    ['{7E1A6E11-3F42-4C8B-9A17-0DE07A000004}']
    {** 追加文件条目；未指定时间戳取确定性缺省（同输入同输出） *}
    procedure AddFile(const AName: string; const AData: TBytes);
    {** 追加文件条目并携带修改时间（unix 秒） *}
    procedure AddFileWithTime(const AName: string; const AData: TBytes;
      const AMTimeUnixSec: Int64);
    {** 从 IReader 流追加文件：Finish 时恰好读取 ASize 字节，未指定时间戳取确定性缺省；
        AReader 为 nil 抛参数错误，ASize 按声明参与 folder 切分与头信息；
        数据在 Finish 前不立即物化，重复读取同一源需调用方保证可重读或已缓存 *}
    procedure AddFileFromReader(const AName: string; const AReader: IReader;
      ASize: UInt64);
    {** 从 IReader 流追加文件并携带修改时间（unix 秒） *}
    procedure AddFileFromReaderWithTime(const AName: string; const AReader: IReader;
      ASize: UInt64; const AMTimeUnixSec: Int64);
    {** 追加目录条目 *}
    procedure AddDirectory(const AName: string);
    {** 追加目录条目并携带修改时间（unix 秒） *}
    procedure AddDirectoryWithTime(const AName: string; const AMTimeUnixSec: Int64);
    {** 已追加条目数 *}
    function EntryCount: Integer;
    {** 编码头开关：开启时主头经 LZMA2 压缩为 kEncodedHeader（与参考
        实现生态一致，条目多时显著减小档体）；关闭写明文 kHeader。
        默认开启；Finish 后切换抛错 *}
    procedure SetEncodeHeader(AEnabled: Boolean);
    {** 设置 solid 数据进压缩器前的预过滤器链（按声明顺序逐级作用，
        读端逆序还原）。空数组恢复默认直压。BCJ 面向 x86 可执行内容；
        Delta 面向增量平滑数据（如 WAV）。最多 C_MAX_FILTERS 级；
        Finish 后设置抛错 *}
    procedure SetFilters(const AFilters: array of TSevenZFilter);
    {** 压缩级别：作用于 solid 与 kEncodedHeader 的全部 LZMA2 编码。
        szclNone 走未压缩 chunk 存储（最快，档体接近原大小）；
        默认 szclDefault。Finish 后设置抛错 *}
    procedure SetLevel(ALevel: TSevenZCompressionLevel);
    {** 显式指定 solid 流 coder 方法（Copy/LZMA2/Deflate/BZip2）。默认跟随 SetLevel；
        指定后 BuildArchive 按该方法压缩 solid（Deflate 走 zlib 包裹，BZip2 走 libbz2，与读端双路径兼容）。
        暂不支持 PPMD 写入，传其余方法抛 EArgumentError。Finish 后设置抛错 *}
    procedure SetMethod(AMethodId: UInt64);
    {** 设置口令启用 AES-256 加密：solid folder 与 kEncodedHeader 的
        头 folder 均在编码链末端追加 AES256 coder（随机 IV、无盐、
        19 轮 KDF，与参考写端缺省一致）。传空串清除恢复明文输出。
        加密档含随机 IV，不再逐字节确定。Finish 后设置抛错 *}
    procedure SetPassword(const APassword: string);
    {** 设置 folder 切分阈值：当累计未压缩字节或条目数超过阈值时
        起新 folder；两阈值同时为 0 时保持单 solid folder（默认）。
        阈值为 0 表示该维度不限制；Finish 后设置抛错 *}
    procedure SetFolderLimits(AMaxUncompressedBytes: UInt64;
      AMaxFilesPerFolder: Integer);
    {** 终结并返回完整归档字节；此后任何 Add*/Finish 均 raise *}
    function Finish: TBytes;
    {** 终结并把签名头/pack 流/头部顺序写入 ASink，返回总字节数；
        免去整档二次拼接。ASink 拒收即抛 EIOError。此后同 Finish 锁定 *}
    function FinishTo(const ASink: IWriter): Int64;
  end;

  {** @desc 7z 写端流式 Builder：链式装配，Finish 一次性产出 *}
  ISevenZWriterBuilder = interface
    ['{7E1A6E11-3F42-4C8B-9A17-0DE07A000005}']
    function AddFile(const AName: string; const AData: TBytes): ISevenZWriterBuilder;
    function AddFileWithTime(const AName: string; const AData: TBytes;
      const AMTimeUnixSec: Int64): ISevenZWriterBuilder;
    function AddFileFromReader(const AName: string; const AReader: IReader;
      ASize: UInt64): ISevenZWriterBuilder;
    function AddFileFromReaderWithTime(const AName: string; const AReader: IReader;
      ASize: UInt64; const AMTimeUnixSec: Int64): ISevenZWriterBuilder;
    function AddDirectory(const AName: string): ISevenZWriterBuilder;
    function AddDirectoryWithTime(const AName: string;
      const AMTimeUnixSec: Int64): ISevenZWriterBuilder;
    function WithFilters(const AFilters: array of TSevenZFilter): ISevenZWriterBuilder;
    function WithLevel(ALevel: TSevenZCompressionLevel): ISevenZWriterBuilder;
    function WithMethod(AMethodId: UInt64): ISevenZWriterBuilder;
    function WithPassword(const APassword: string): ISevenZWriterBuilder;
    function WithFolderLimits(AMaxUncompressedBytes: UInt64;
      AMaxFilesPerFolder: Integer): ISevenZWriterBuilder;
    function WithEncodeHeader(AEnabled: Boolean): ISevenZWriterBuilder;
    function WithProgress(AProgress: TSevenZProgressEvent): ISevenZWriterBuilder;
    function AddTree(const AHostDir: string; const AArchivePrefix: string): ISevenZWriterBuilder;
    function AddTreeWithFilter(const AHostDir: string; const AArchivePrefix: string;
      const AFilter: string): ISevenZWriterBuilder;
    function AddFileFromFs(const AHostPath: string; const AArchiveName: string): ISevenZWriterBuilder;
    function Build: ISevenZWriter;
    function Finish: TBytes;
    function FinishTo(const ASink: IWriter): Int64;
  end;

{ 级别→底层压缩参数的纯映射，供 writer/bench 复用 }
function SevenZLevelToDeflateLevel(ALevel: TSevenZCompressionLevel): TCompressionLevel; inline;
function SevenZLevelToBZip2BlockSize(ALevel: TSevenZCompressionLevel): Integer; inline;

implementation

function SevenZLevelToDeflateLevel(ALevel: TSevenZCompressionLevel): TCompressionLevel;
begin
  Result := SevenZLevelOrdToDeflateLevel(Ord(ALevel));
end;

function SevenZLevelToBZip2BlockSize(ALevel: TSevenZCompressionLevel): Integer;
begin
  Result := SevenZLevelOrdToBZip2BlockSize(Ord(ALevel));
end;

function TSevenZEntryEnumerator.GetCurrent: TSevenZEntryInfo;
begin
  Result := FReader.Entry(FIndex);
end;

function TSevenZEntryEnumerator.MoveNext: Boolean;
begin
  Inc(FIndex);
  Result := FIndex < FReader.EntryCount;
end;

end.
