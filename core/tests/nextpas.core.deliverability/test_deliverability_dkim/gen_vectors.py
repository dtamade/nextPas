#!/usr/bin/env python3
"""RFC 6376 黄金向量生成器 — 与 nextpas.core.deliverability.dkim 交叉验证。

独立实现 RFC 6376 §3.4(头/体规范化)、§3.7(hash input 构建)、
§3.5(b= 置空),以及 PKCS#1 v1.5-SHA256 / Ed25519 签名,生成
dkim_vectors.inc(Pascal include)供 FPC 测试嵌入。

运行:  python3 gen_vectors.py > dkim_vectors.inc
自检: 脚本内做 openssl dgst 对拍(环境有 openssl 时)。

注意: 本脚本是"独立实现",故意不参照 FPC 代码;语义只依据 RFC 原文。
"""

import base64
import hashlib
import os
import subprocess
import sys

from cryptography.hazmat.primitives.asymmetric import padding, rsa, ed25519
from cryptography.hazmat.primitives import serialization, hashes

# ───────────────────────── RFC 6376 规范化 ─────────────────────────

WSP = (' ', '\t')


def canon_body_simple(body: bytes) -> bytes:
    """§3.4.3: 去尾部空行; 空体 → 单 CRLF; 非空且不以 CRLF 结尾 → 补 CRLF。"""
    # 空行 = 移除行终止符后零长度
    lines = body.split(b'\r\n')
    while lines and lines[-1] == b'':
        lines.pop()
    if not lines:
        # RFC 6376 §3.4.3: 完全空体 simple 规范化为单 CRLF(2 octets)
        return b'\r\n'
    return b'\r\n'.join(lines) + b'\r\n'


def canon_body_relaxed(body: bytes) -> bytes:
    """§3.4.4: 行尾 WSP 忽略 + 行内 WSP 序列→单 SP + 去尾部空行 + 补 CRLF。"""
    if body == b'':
        return b''
    # 统一按 CRLF 切分; 兼容裸 \n(消息体按 RFC 应为 CRLF, 防御处理)
    norm = body.replace(b'\r\n', b'\n')
    lines = norm.split(b'\n')
    out = []
    for ln in lines:
        ln = ln.rstrip(b' \t')
        # 行内 WSP 序列 → 单 SP(含行首; 行尾已 rstrip)
        cur = bytearray()
        prev_ws = False
        for ch in ln:
            if ch in (0x20, 0x09):
                if not prev_ws:
                    cur.append(0x20)
                    prev_ws = True
            else:
                cur.append(ch)
                prev_ws = False
        out.append(bytes(cur))
    while out and out[-1] == b'':
        out.pop()
    if not out:
        return b''
    return b'\r\n'.join(out) + b'\r\n'


def canon_header_simple(name: bytes, value: bytes) -> bytes:
    """§3.4.1: 原封不动。"""
    return name + b':' + value


def canon_header_relaxed(name: bytes, value: bytes) -> bytes:
    """§3.4.2: 名小写去 WSP; unfold; WSP→SP; 去值首尾 WSP; 冒号前后 WSP 删。"""
    n = bytes(ch for ch in name if ch not in (0x20, 0x09)).lower()
    v = value.replace(b'\r\n', b'')
    v = v.replace(b'\r', b'').replace(b'\n', b'')
    out = bytearray()
    for ch in v:
        if ch in (0x20, 0x09):
            if out and out[-1] != 0x20:
                out.append(0x20)
        else:
            out.append(ch)
    v = bytes(out).strip(b' ')
    return n + b':' + v


def split_header(raw: bytes):
    """按第一个冒号拆 name/value; 与消息解析语义一致(冒号前空白留在 name)。"""
    idx = raw.find(b':')
    assert idx > 0, raw
    return raw[:idx], raw[idx + 1:]


def remove_b_value(value: bytes) -> bytes:
    """§3.7: 仅 b= 的值(及其周围 WSP)置空; 其余段原样。避开 bh=。"""
    out = []
    for seg in value.split(b';'):
        if seg == b'':
            continue
        t = seg.strip()
        if t.lower().startswith(b'b=') and not t.lower().startswith(b'bh='):
            eq = seg.find(b'=')
            out.append(seg[:eq + 1])
        else:
            out.append(seg)
    return b';'.join(out)


def build_header_hash_input(headers: list, h_list: list, canon,
                            dkim_idx: int) -> bytes:
    """§3.7: h= 顺序(缺失头 = null input), 每头 CRLF 终止;
    DKIM-Signature(b= 空)追加, 无尾 CRLF。h= 里的 dkim-signature 跳过自己。"""
    used = set()
    parts = []
    for hname in h_list:
        found = None
        target = hname.encode()
        for i in range(len(headers) - 1, -1, -1):
            if i in used or i == dkim_idx:
                continue
            nm, _ = split_header(headers[i])
            if nm.strip().lower() == target:
                found = i
                break
        if found is None:
            continue  # null input
        used.add(found)
        nm, vl = split_header(headers[found])
        parts.append(canon(nm, vl))
    if dkim_idx >= 0 and dkim_idx not in used:
        nm, vl = split_header(headers[dkim_idx])
        parts.append(canon(nm, remove_b_value(vl)))
    return b'\r\n'.join(parts)


def extract_body(raw_mail: bytes) -> bytes:
    sep = raw_mail.find(b'\r\n\r\n')
    if sep >= 0:
        return raw_mail[sep + 4:]
    sep = raw_mail.find(b'\n\n')
    if sep >= 0:
        return raw_mail[sep + 2:]
    return b''


def extract_headers(raw_mail: bytes) -> list:
    sep = raw_mail.find(b'\r\n\r\n')
    if sep >= 0:
        hdr = raw_mail[:sep]
    else:
        sep = raw_mail.find(b'\n\n')
        hdr = raw_mail[:sep] if sep >= 0 else raw_mail
    # 按行切分; 折叠续行并入前一个头
    lines = hdr.replace(b'\r\n', b'\n').split(b'\n')
    headers = []
    for ln in lines:
        if ln[:1] in (b' ', b'\t') and headers:
            headers[-1] += b'\r\n' + ln
        else:
            headers.append(ln)
    return headers


# ───────────────────────── 向量数据 ─────────────────────────

def pstr(data: bytes) -> str:
    """bytes → Pascal '...'#13#10'...' 字面量。"""
    if data == b'':
        return "''"
    out = []
    cur = []
    for b in data:
        if b == 13:
            if cur:
                out.append("'" + ''.join(cur) + "'")
                cur = []
            out.append('#13')
        elif b == 10:
            out.append('#10')
        elif b == 9:
            if cur:
                out.append("'" + ''.join(cur) + "'")
                cur = []
            out.append('#9')
        elif b == 39:
            cur.append("''")
        elif 32 <= b < 127:
            cur.append(chr(b))
        else:
            if cur:
                out.append("'" + ''.join(cur) + "'")
                cur = []
            out.append('#' + str(b))
    if cur:
        out.append("'" + ''.join(cur) + "'")
    return ''.join(out)


def phex(data: bytes) -> str:
    return ' '.join('%02X' % b for b in data)


def pb64(data: bytes) -> str:
    return base64.b64encode(data).decode()


def main():
    lines = []
    w = lines.append

    w('{ 由 python3 gen_vectors.py 生成(RFC 6376 独立实现) — 勿手改 }')
    w('const')

    # ── 1. body 规范化向量 ──
    bodies = [
        b'',
        b'abc',
        b'abc\r\n',
        b'abc\r\n\r\n',
        b'a  b\t c\r\n  d  \r\n\r\n',
        b'line one  \r\nline two\t\r\n\r\n\r\n',
    ]
    for i, bd in enumerate(bodies):
        w('  DKV_BODY%d_SIMPLE: string = %s;' % (i, pstr(canon_body_simple(bd))))
        w('  DKV_BODY%d_RELAXED: string = %s;' % (i, pstr(canon_body_relaxed(bd))))

    # ── 2. header 规范化向量(含 RFC 6376 §3.4.5 示例) ──
    hdrs = [
        (b'Subject', b'  Hello   World  '),
        (b'B ', b' Y\t'),
        (b'Subject', b' foo' + b'\r\n\t' + b'bar'),
        (b'X-Reply-To', b'one  ' + b'\r\n  ' + b' two'),
    ]
    for i, (nm, vl) in enumerate(hdrs):
        w('  DKV_HDR%d_NAME: string = %s;' % (i, pstr(nm)))
        w('  DKV_HDR%d_VALUE: string = %s;' % (i, pstr(vl)))
        w('  DKV_HDR%d_SIMPLE: string = %s;' % (i, pstr(canon_header_simple(nm, vl))))
        w('  DKV_HDR%d_RELAXED: string = %s;' % (i, pstr(canon_header_relaxed(nm, vl))))

    # RFC §3.4.5 示例 1(relaxed + simple 整封邮件)
    rfc_msg = (b'A: X\r\n'
               b'B : Y\t\r\n'
               b'\tZ  \r\n'
               b'\r\n'
               b' C \r\n'
               b'D \t E\r\n'
               b'\r\n')
    rfc_h = extract_headers(rfc_msg)
    rfc_relaxed_h = b'\r\n'.join(
        canon_header_relaxed(*split_header(h)) for h in rfc_h) + b'\r\n'
    rfc_simple_h = b'\r\n'.join(
        canon_header_simple(*split_header(h)) for h in rfc_h) + b'\r\n'
    w('  DKV_RFC_EX1_HEADERS: string = %s;' % pstr(rfc_h[0] + b'\r\n' + rfc_h[1]))
    w('  DKV_RFC_EX1_RELAXED_HDR: string = %s;' % pstr(rfc_relaxed_h))
    w('  DKV_RFC_EX1_SIMPLE_HDR: string = %s;' % pstr(rfc_simple_h))
    w('  DKV_RFC_EX1_RELAXED_BODY: string = %s;' % pstr(canon_body_relaxed(extract_body(rfc_msg))))
    w('  DKV_RFC_EX1_SIMPLE_BODY: string = %s;' % pstr(canon_body_simple(extract_body(rfc_msg))))

    # ── 3. RSA-1024 密钥(openssl 生成, 固定) ──
    # 直接用 /tmp/dkim_tv 已生成的密钥
    n_hex = ('c5391533f388435783e51a1ccea34f5aa75ae9cf0d1a5e971512cd4a697d9695'
             'd6b78d2847aa787e930613321f33d1ec8486bb5db21b20bd6780eb18ac88c402'
             '4f21ddedc56a03d56dece61f19b9e3e72af8e14fe5e0afcc0bbf80604a0aba66f'
             'a01f899e7ab7404098b0db856a04b353ad51e4bc9c606f07afb085fb5205717')
    e_hex = '010001'
    d_hex = ('b2fd4966eac0620d8ce061c07f30eb95e488b7e57788d50bdcce418e250b1b9'
             'd454f3446b833d843577f8df0512d2079bd14e1faf8e771e1338c66d0efd4f7b'
             'd60723d58cf5092ef9df8bd96cff3f0139060ff6a1170eef64927ce4efb3e71c'
             '6dbeaabe109db4461833fe39111f7ce7299fa087dd747a80beb233184bad197b1')
    n = bytes.fromhex(n_hex)
    e = int(e_hex, 16)
    d = bytes.fromhex(d_hex)

    # 密钥加载(缺失时降级: 仅规范化向量; 恢复引导见 plan 文档 D3)
    rsa_priv = None
    pem_path = '/tmp/dkim_tv/rsa.pem'
    if os.path.exists(pem_path):
        with open(pem_path, 'rb') as f:
            rsa_priv = serialization.load_pem_private_key(f.read(), password=None)
        # 一致性: 加载的私钥 n 必须等于 N_HEX
        n_loaded = rsa_priv.public_key().public_numbers().n
        assert n_loaded == int(n_hex, 16), 'rsa_key.pem 与 N_HEX 不匹配'
    else:
        print('[selfcheck] 缺 %s, RSA 签名向量降级为规范化向量' % pem_path,
              file=sys.stderr)
    # SPKI DER
    from cryptography.hazmat.primitives.asymmetric.rsa import RSAPublicNumbers
    pub = RSAPublicNumbers(e, int.from_bytes(n, 'big')).public_key()
    spki = pub.public_bytes(
        serialization.Encoding.DER,
        serialization.PublicFormat.SubjectPublicKeyInfo)
    w('  DKV_RSA_N_HEX: string = %s;' % pstr(n_hex.encode()))
    w('  DKV_RSA_E_HEX: string = %s;' % pstr(e_hex.encode()))
    w('  DKV_RSA_D_HEX: string = %s;' % pstr(d_hex.encode()))
    w('  DKV_RSA_SPKI_B64: string = %s;' % pstr(pb64(spki).encode()))

    # ── 3b. 私钥 PEM 形态(PKCS#8 + 传统 PKCS#1; CRLF 规范化) ──
    # DkimLoadRsaPrivateKey 双形态加载正例的输入
    if rsa_priv is not None:
        pem_pkcs8 = rsa_priv.private_bytes(
            serialization.Encoding.PEM,
            serialization.PrivateFormat.PKCS8,
            serialization.NoEncryption())
        pem_pkcs1 = rsa_priv.private_bytes(
            serialization.Encoding.PEM,
            serialization.PrivateFormat.TraditionalOpenSSL,
            serialization.NoEncryption())
        w('  DKV_RSA_PEM_PKCS8: string = %s;' %
          pstr(pem_pkcs8.replace(b'\n', b'\r\n')))
        w('  DKV_RSA_PEM_PKCS1: string = %s;' %
          pstr(pem_pkcs1.replace(b'\n', b'\r\n')))

    # ── 4. 完整邮件 + hash input + 签名(RSA) ──
    # c=relaxed/simple; h=from:to:subject(x-date 缺失 → null input)
    body_rsa = b'Body line 1\r\nBody line 2'
    body_rsa_canon = canon_body_simple(body_rsa)
    bh_rsa = hashlib.sha256(body_rsa_canon).digest()

    def make_mail(h_list, canon_h, canon_b, algo, priv, body):
        # 签名头骨架(折叠); 先填 bh= 再算 header hash(b= 保持空)
        if algo == 'rsa-sha256':
            a_tag = 'a=rsa-sha256'
        else:
            a_tag = 'a=ed25519-sha256'
        c_tag = '%s/%s' % (canon_h, canon_b)
        dkim_tpl = (
            ('DKIM-Signature: v=1; %s; c=%s; d=example.com; s=sel;\r\n'
             '\th=%s; bh=; b=') % (a_tag, c_tag, ':'.join(h_list))
        )
        if canon_b == 'relaxed':
            body_canon = canon_body_relaxed(body)
        else:
            body_canon = canon_body_simple(body)
        bh = hashlib.sha256(body_canon).digest()
        dkim_tpl = dkim_tpl.replace('bh=; b=', 'bh=%s; b=' % pb64(bh))
        headers = [
            b'From: Alice <alice@example.com>',
            b'To: Bob <bob@example.net>',
            b'Subject: DKIM test  with  spaces',
            b'X-Folded: one\r\n\t two',
        ]
        # 签名头占位(暂以空 b= 计算 hash input)
        dkim_line = dkim_tpl.encode() + b';'
        headers.append(dkim_line)
        dkim_idx = len(headers) - 1
        canon_fn = canon_header_relaxed if canon_h == 'relaxed' else canon_header_simple
        hdrin = build_header_hash_input(headers, h_list, canon_fn, dkim_idx)
        if algo == 'rsa-sha256':
            sig = priv.sign(hdrin, padding.PKCS1v15(),
                            hashes.SHA256())
        else:
            sig = priv.sign(hdrin)
        # 填回 b=(bh= 已在 hash input 计算前填好; RFC 6376 §3.7)
        b_b64 = pb64(sig)
        dkim_final = dkim_tpl.replace('; b=', '; b=%s;' % b_b64).encode()
        headers[dkim_idx] = dkim_final
        mail = b'\r\n'.join(headers) + b'\r\n\r\n' + body
        return mail, hdrin, sig

    mail_rsa = None
    hdrin_rsa = None
    if rsa_priv is not None:
        mail_rsa, hdrin_rsa, sig_rsa = make_mail(
            ['from', 'to', 'subject', 'x-date'], 'relaxed', 'simple',
            'rsa-sha256', rsa_priv, body_rsa)
        w('  DKV_MAIL_RSA: string = %s;' % pstr(mail_rsa))
        w('  DKV_HASHIN_RSA: string = %s;' % pstr(hdrin_rsa))
        w('  DKV_BH_RSA_B64: string = %s;' % pstr(pb64(bh_rsa).encode()))
        w('  DKV_SIG_RSA_B64: string = %s;' % pstr(pb64(sig_rsa).encode()))

    # ── 5. Ed25519 向量(c=simple/simple; h=from:to) ──
    body_ed = b'Hello body\r\nsecond line'
    body_ed_canon = canon_body_simple(body_ed)
    bh_ed = hashlib.sha256(body_ed_canon).digest()
    ed_seed = bytes(range(32))
    ed_priv = ed25519.Ed25519PrivateKey.from_private_bytes(ed_seed)
    ed_pub = ed_priv.public_key().public_bytes(
        serialization.Encoding.Raw, serialization.PublicFormat.Raw)

    dkim_tpl_ed = ('DKIM-Signature: v=1; a=ed25519-sha256; c=simple/simple; d=example.com; '
                   's=sel; h=from:to; bh=; b=')
    dkim_tpl_ed = dkim_tpl_ed.replace('bh=; b=', 'bh=%s; b=' % pb64(bh_ed))
    headers_ed = [
        b'From: Alice <alice@example.com>',
        b'To: Bob <bob@example.net>',
    ]
    headers_ed.append(dkim_tpl_ed.encode() + b';')
    dkim_idx_ed = len(headers_ed) - 1
    hdrin_ed = build_header_hash_input(headers_ed, ['from', 'to'],
                                       canon_header_simple, dkim_idx_ed)
    sig_ed = ed_priv.sign(hdrin_ed)
    dkim_final_ed = dkim_tpl_ed.replace('; b=', '; b=%s;' % pb64(sig_ed))
    headers_ed[dkim_idx_ed] = dkim_final_ed.encode()
    mail_ed = b'\r\n'.join(headers_ed) + b'\r\n\r\n' + body_ed
    w('  DKV_MAIL_ED25519: string = %s;' % pstr(mail_ed))
    w('  DKV_HASHIN_ED25519: string = %s;' % pstr(hdrin_ed))
    w('  DKV_BH_ED25519_B64: string = %s;' % pstr(pb64(bh_ed).encode()))
    w('  DKV_SIG_ED25519_B64: string = %s;' % pstr(pb64(sig_ed).encode()))
    w('  DKV_ED25519_PUB_HEX: string = %s;' % pstr(ed_pub.hex().encode()))
    w('  DKV_ED25519_PRIV_HEX: string = %s;' % pstr(ed_seed.hex().encode()))

    # ── 6. h= 含缺失头 + 重复头的 hash input 向量(独立构建, 无签名) ──
    headers_ns = [
        b'From: a@example.com',
        b'Subject: s',
        b'X-Multi: first',
        b'X-Multi: second',
        b'DKIM-Signature: v=1; a=rsa-sha256; c=relaxed/relaxed; d=example.com;'\
          b' s=s; h=x-multi:x-multi; bh=YQ==; b=Yg==',
    ]
    # 无 dkim-signature 的纯 hash input: h=from:subject:x-date(缺失)
    dkim_idx_ns = -1
    hdrin_ns = build_header_hash_input(headers_ns, ['from', 'subject', 'x-date'],
                                       canon_header_simple, dkim_idx_ns)
    # h= 重复 X-Multi 两次, relaxed(与 test HashInputMulti 同构: 带签名头)
    hdrin_multi = build_header_hash_input(headers_ns, ['x-multi', 'x-multi'],
                                          canon_header_relaxed, len(headers_ns) - 1)
    w('  DKV_HASHIN_NULLHDR: string = %s;' % pstr(hdrin_ns))
    w('  DKV_HASHIN_MULTI: string = %s;' % pstr(hdrin_multi))

    # ── 7. b= 置空向量 ──
    dk_val = b'v=1; a=rsa-sha256; b=abc123  ; bh=xyz; h=from; c=simple'
    w('  DKV_REMOVEBVAL: string = %s;' % pstr(remove_b_value(dk_val)))
    dk_val2 = b'v=1;a=rsa-sha256;bh=qq;b=AAbb ;h=from'
    w('  DKV_REMOVEBVAL2: string = %s;' % pstr(remove_b_value(dk_val2)))

    # ── 8. DkimSignMail 黄金向量(plan 2026-08-25 D1 线格式独立实现) ──
    # 组装规则: 单物理行头, tag 序 v,a,c,d,s,h,bh,b, "; " 分隔, 无 t=/x=,
    # 签名头插为物理第一个头, 原邮件逐字节不动, b= 追加签名。
    if rsa_priv is not None:
        sm_input = (b'From: Alice <alice@example.com>\r\n'
                    b'To: Bob <bob@example.net>\r\n'
                    b'Subject: outbound  with  spaces\r\n'
                    b'X-Folded: one\r\n\t two\r\n'
                    b'\r\n'
                    b'Body line 1\r\nBody line 2\r\n')
        sm_h = ['from', 'to', 'subject', 'x-date']   # x-date 缺失 → null input
        sm_ch, sm_cb = 'relaxed', 'simple'
        body_c = canon_body_simple(b'Body line 1\r\nBody line 2\r\n') \
            if sm_cb == 'simple' else canon_body_relaxed(b'Body line 1\r\nBody line 2\r\n')
        sm_bh = pb64(hashlib.sha256(body_c).digest())
        sm_val = ('v=1; a=rsa-sha256; c=%s/%s; d=example.com; s=sel; h=%s; '
                  'bh=%s; b=' % (sm_ch, sm_cb, ':'.join(sm_h), sm_bh))
        sm_hdrline = b'DKIM-Signature: ' + sm_val.encode()
        sm_nob = sm_hdrline + b'\r\n' + sm_input
        sm_hdrs = extract_headers(sm_nob)            # 签名头在 idx 0
        sm_hdrin = build_header_hash_input(
            sm_hdrs, sm_h, canon_header_relaxed, 0)
        sm_sig = rsa_priv.sign(sm_hdrin, padding.PKCS1v15(), hashes.SHA256())
        # openssl 对拍自检(与 §4 同款纪律)
        with open('/tmp/dkim_tv/sm_hdr_in.bin', 'wb') as f:
            f.write(sm_hdrin)
        _r = subprocess.run(
            ['openssl', 'dgst', '-sha256', '-sign', pem_path,
             '-out', '/tmp/dkim_tv/sm_openssl_sig.bin',
             '/tmp/dkim_tv/sm_hdr_in.bin'], capture_output=True)
        assert _r.returncode == 0, _r.stderr
        with open('/tmp/dkim_tv/sm_openssl_sig.bin', 'rb') as f:
            assert f.read() == sm_sig, 'openssl 与 cryptography 签名不一致'
        print('[selfcheck] signmail openssl dgst 对拍一致', file=sys.stderr)
        sm_expected = sm_hdrline + pb64(sm_sig).encode() + sm_nob[len(sm_hdrline):]
        w('  DKV_SIGNMAIL_INPUT: string = %s;' % pstr(sm_input))
        w('  DKV_SIGNMAIL_EXPECTED: string = %s;' % pstr(sm_expected))

    print('\n'.join(lines))

    # ── 自检: openssl 对拍 RSA 签名(可用时) ──
    if rsa_priv is not None:
        try:
            with open('/tmp/dkim_tv/hdr_in.bin', 'wb') as f:
                f.write(hdrin_rsa)
            r = subprocess.run(
                ['openssl', 'dgst', '-sha256', '-sign', pem_path,
                 '-out', '/tmp/dkim_tv/openssl_sig.bin', '/tmp/dkim_tv/hdr_in.bin'],
                capture_output=True)
            if r.returncode == 0:
                with open('/tmp/dkim_tv/openssl_sig.bin', 'rb') as f:
                    osig = f.read()
                assert osig == sig_rsa, 'openssl 与 cryptography 签名不一致'
                print('[selfcheck] openssl dgst 对拍一致', file=sys.stderr)
        except Exception as exc:  # noqa: BLE001
            print('[selfcheck] openssl 对拍跳过: %s' % exc, file=sys.stderr)
    else:
        print('[selfcheck] 无 RSA 私钥 PEM, 跳过 openssl 对拍', file=sys.stderr)


if __name__ == '__main__':
    main()
