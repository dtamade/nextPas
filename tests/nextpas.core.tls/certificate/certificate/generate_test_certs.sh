#!/bin/bash

# PKCS7 测试证书生成脚本
# 生成用于 PKCS7 签名、验证、加密、解密测试的证书和密钥

set -e

CERT_DIR="./tests/certificate/test_certs"
mkdir -p "$CERT_DIR"

echo "生成测试证书和密钥..."

# 1. 生成 CA 证书（用于签名测试证书）
echo "1. 生成 CA 证书..."
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "$CERT_DIR/ca_key.pem" \
  -out "$CERT_DIR/ca_cert.pem" \
  -days 365 \
  -subj "/C=CN/ST=Beijing/L=Beijing/O=Test CA/CN=Test CA"

# 2. 生成签名者证书和私钥
echo "2. 生成签名者证书..."
openssl req -newkey rsa:2048 -nodes \
  -keyout "$CERT_DIR/signer_key.pem" \
  -out "$CERT_DIR/signer_req.pem" \
  -subj "/C=CN/ST=Beijing/L=Beijing/O=Test Org/CN=Test Signer"

openssl x509 -req -in "$CERT_DIR/signer_req.pem" \
  -CA "$CERT_DIR/ca_cert.pem" \
  -CAkey "$CERT_DIR/ca_key.pem" \
  -CAcreateserial \
  -out "$CERT_DIR/signer_cert.pem" \
  -days 365

# 3. 生成接收者证书和私钥（用于加密测试）
echo "3. 生成接收者证书..."
openssl req -newkey rsa:2048 -nodes \
  -keyout "$CERT_DIR/recipient_key.pem" \
  -out "$CERT_DIR/recipient_req.pem" \
  -subj "/C=CN/ST=Beijing/L=Beijing/O=Test Org/CN=Test Recipient"

openssl x509 -req -in "$CERT_DIR/recipient_req.pem" \
  -CA "$CERT_DIR/ca_cert.pem" \
  -CAkey "$CERT_DIR/ca_key.pem" \
  -CAcreateserial \
  -out "$CERT_DIR/recipient_cert.pem" \
  -days 365

# 4. 创建测试数据文件
echo "4. 创建测试数据..."
echo "This is test data for PKCS7 signing and encryption." > "$CERT_DIR/test_data.txt"

# 5. 清理临时文件
rm -f "$CERT_DIR/signer_req.pem" "$CERT_DIR/recipient_req.pem"

echo "✅ 测试证书生成完成！"
echo ""
echo "生成的文件："
echo "  - CA 证书: $CERT_DIR/ca_cert.pem"
echo "  - CA 私钥: $CERT_DIR/ca_key.pem"
echo "  - 签名者证书: $CERT_DIR/signer_cert.pem"
echo "  - 签名者私钥: $CERT_DIR/signer_key.pem"
echo "  - 接收者证书: $CERT_DIR/recipient_cert.pem"
echo "  - 接收者私钥: $CERT_DIR/recipient_key.pem"
echo "  - 测试数据: $CERT_DIR/test_data.txt"
