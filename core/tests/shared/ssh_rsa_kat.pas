unit ssh_rsa_kat;

{** nextpas.core.ssh 测试共享：RSA PKCS#1 v1.5 黄金向量。
 *
 * openssl dgst -sha256/-sha512 -sign 对固定消息产出（2048-bit 专用测试
 * 密钥，无保密价值）。hostkey 门（验签路径）与 keys 门（签名路径）共
 * 用同一份常量，防止跨文件漂移。 *}

interface

uses
  nextpas.core.system.sysutils,
  nextpas.core.base;

const
  { 消息 = 'nextpas ssh rsa pkcs1 kat' }
  KAT_MSG_HEX = '6e657874706173207373682072736120706b637331206b6174';
  KAT_E_HEX = '010001';

{ 解码辅助：测试规模无需缓存 }
function HexToBytesKat(const AHex: string): TBytes;

function KatN: TBytes;
function KatD: TBytes;
function KatMsg: TBytes;
function KatSigSha256: TBytes;
function KatSigSha512: TBytes;

implementation

const
  N_HEX =
      'E3691DEEC2C4267FB4AC0A0EECF8928D1DE5B49F8B0049B63B6068BDBE603DBE'
    + 'DDCC807C193CB9803855D59FE7C2D85E8188E9940928E090AC9EA6E855023950'
    + '86B848980C50771E52905978E753BD933BA296A3E4A0793BDCEC422788224B25'
    + '0AFBF9F9BB62EBFE6448E60D347482E36AEFF2752E8D5CDC47E7A22A00D96E34'
    + '71450D1BA36613ED09A0B4FEBC0D5A0B3072B82659C706FF848A8638BFA08AAB'
    + 'F5FF4174A47CCFC0094BF55423AB51F5EAFB745847BAE471C00A4AAF4CD7D42D'
    + '526CAF9135684182BB92E9BE31139194B7436B83246386FC586592CF262E6643'
    + 'A0FCEC9FA63351A4E04595FC04B2FB1DA765FE75278C6233B53FCCF3B5C78A81';
  D_HEX =
      '1ce4f347adf98c46b7a710541b29ee3cfdea7ccbb4b6a1a704de58109bcad0ad'
    + '9ab2ec3458648dd14bd72420802b12a0d76694ff1936d769aa753211dd133e43'
    + '0c0b083641824bd04f7f45cf05dd6efdf11ad477188a873ce2f225e9adf36586'
    + 'dc616dbe9c5f924aad6551cda5b79415df3583a1fdfb3a2c46fa98712bd0749e'
    + 'f9cf80b011054c28b630a50535fd385fc85a3fbe9e3705790f82d1f41d559743'
    + 'e219357cf1d34a6a12bd58bdbfa4000f5f66c8ba8f85cb59990db807f8bcac7f'
    + '0cbf74336368692de09cdb0c075d6c662540ec7c0384ecd4bb1657a9895b8d0e'
    + 'd5bd62101e0af35b03d03974ae418a25d15ca2eca277f507a198a15384b39fd1';
  SIG256_HEX =
      'c7703263e3eef49b8fc17ea0728cdf8233afb58bdd24f360bebf1cd869c87efc'
    + '92ae6be6f591184db237e11d6a3b3d1c89d4ff8c442bc4bb43d5c2b73d198d77'
    + 'b826266cc144c44d0f417134aba10b6febfeac2327f368d10acbf26a3057cbe9'
    + 'ec765314f846c38d5fc3128e7d88ec4068d1cf26d7a964efa0d5fe83a583a4eb'
    + '0216f02c08de4633161bd8ffeabe6654a64569e620da3eb6b43e193f4bd9b547'
    + 'a16f99e1ebc92bcdc7e8e42f823bc2d82904b4a967d7d66f5a5eceb4509266d2'
    + '7908dfc2d0eebd7b170ca51705a33511e20eb47132690f082b8dbf630a122677'
    + '944fbd9ea936ae81f111aedfa30255f67ec02139e71aab0f90e831c6a6ec234c';
  SIG512_HEX =
      'ca7b27b68665557b522ef9a8f7db464fb35602d32a9b7efcbbeedb0c6da8b629'
    + '1ddf598c544e2098dcb4cad4ac37006731fb47bf6d074cd2717eb07ba561f95c'
    + '3ba76dc6923d7c6bf2f213ad824b87e930904884c0b8ec74e6281b59f61346f5'
    + '4afa80d304fa38f4bdf9721bfccdd277996ec2a576dde1bae316a5b396c0973c'
    + '27799dcfb3145e338c2dfcc693e99db9dd99fa6c496dff10b230e886bb7d1ae3'
    + '54ae1e20545a33d508f9eb3c64f9d9901bc08bd989c07e90ca4a7de884d943a0'
    + 'ba12c1f8df6be361454e55f220260fc4d87ab36faa7791e72607e6c8efa29afe'
    + '89b9ffc3ec3c101b7914b60d3915648818cebb1f6d04bc23d6ef64182c20be01';

function HexVal(ACh: Char): Byte;
begin
  case ACh of
    '0'..'9': Result := Ord(ACh) - Ord('0');
    'a'..'f': Result := Ord(ACh) - Ord('a') + 10;
    'A'..'F': Result := Ord(ACh) - Ord('A') + 10;
  else
    raise Exception.Create('ssh_rsa_kat: bad hex char');
  end;
end;

function HexToBytesKat(const AHex: string): TBytes;
var
  I: Integer;
begin
  if (Length(AHex) mod 2) <> 0 then
    raise Exception.Create('ssh_rsa_kat: odd hex length');
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do
    Result[I] := (HexVal(AHex[2 * I + 1]) shl 4) or HexVal(AHex[2 * I + 2]);
end;

function KatN: TBytes;
begin
  Result := HexToBytesKat(N_HEX);
end;

function KatD: TBytes;
begin
  Result := HexToBytesKat(D_HEX);
end;

function KatMsg: TBytes;
begin
  Result := HexToBytesKat(KAT_MSG_HEX);
end;

function KatSigSha256: TBytes;
begin
  Result := HexToBytesKat(SIG256_HEX);
end;

function KatSigSha512: TBytes;
begin
  Result := HexToBytesKat(SIG512_HEX);
end;

end.
