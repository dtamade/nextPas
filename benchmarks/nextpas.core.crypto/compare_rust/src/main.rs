use aes_gcm::{Aes128Gcm, Aes256Gcm, KeyInit, Nonce};
use aes_gcm::aead::Aead;
use ed25519_dalek::{SigningKey, Signer, Verifier, VerifyingKey};
use x25519_dalek::{EphemeralSecret, PublicKey};
use pbkdf2::pbkdf2_hmac;
use sha2::Sha256;
use std::time::{Duration, Instant};

fn bench_aesgcm(key_bits: usize, data_len: usize, duration: Duration) {
    let key = vec![0x42u8; key_bits / 8];
    let nonce_bytes = [0xA0u8; 12];
    let nonce = Nonce::from_slice(&nonce_bytes);
    let plaintext = vec![0x55u8; data_len];

    match key_bits {
        128 => {
            let cipher = Aes128Gcm::new_from_slice(&key).unwrap();
            // warmup
            for _ in 0..20 { let _ = cipher.encrypt(nonce, plaintext.as_ref()); }
            let mut ops = 0u64;
            let start = Instant::now();
            while start.elapsed() < duration {
                let _ = cipher.encrypt(nonce, plaintext.as_ref());
                ops += 1;
            }
            let elapsed = start.elapsed();
            let mbps = (data_len as f64 * ops as f64) / 1048576.0 / elapsed.as_secs_f64();
            println!("  AES-{}-GCM {:5}B: {:8.1} MB/s  ({} ops)", key_bits, data_len, mbps, ops);
        }
        256 => {
            let cipher = Aes256Gcm::new_from_slice(&key).unwrap();
            for _ in 0..20 { let _ = cipher.encrypt(nonce, plaintext.as_ref()); }
            let mut ops = 0u64;
            let start = Instant::now();
            while start.elapsed() < duration {
                let _ = cipher.encrypt(nonce, plaintext.as_ref());
                ops += 1;
            }
            let elapsed = start.elapsed();
            let mbps = (data_len as f64 * ops as f64) / 1048576.0 / elapsed.as_secs_f64();
            println!("  AES-{}-GCM {:5}B: {:8.1} MB/s  ({} ops)", key_bits, data_len, mbps, ops);
        }
        _ => {}
    }
}

fn bench_x25519(duration: Duration) {
    let mut ops = 0u64;
    let start = Instant::now();
    while start.elapsed() < duration {
        let secret = EphemeralSecret::random_from_rng(rand::thread_rng());
        let public = PublicKey::from(&secret);
        let peer_secret = EphemeralSecret::random_from_rng(rand::thread_rng());
        let peer_public = PublicKey::from(&peer_secret);
        let _ = secret.diffie_hellman(&peer_public);
        let _ = peer_secret.diffie_hellman(&public);
        ops += 2;
    }
    let elapsed = start.elapsed();
    let ops_per_sec = (ops as f64 / elapsed.as_secs_f64()) as u64;
    println!("  X25519 ECDH:       {:8} ops/s  ({:.1} us/op)", ops_per_sec, elapsed.as_micros() as f64 / ops as f64);
}

fn bench_ed25519(duration: Duration) {
    let signing_key = SigningKey::from_bytes(&[0x10u8; 32]);
    let verifying_key = VerifyingKey::from(&signing_key);
    let msg = b"benchmark message for ed25519";
    let sig = signing_key.sign(msg);

    // Sign
    for _ in 0..20 { let _ = signing_key.sign(msg); }
    let mut ops = 0u64;
    let start = Instant::now();
    while start.elapsed() < duration {
        let _ = signing_key.sign(msg);
        ops += 1;
    }
    let elapsed = start.elapsed();
    println!("  Ed25519 Sign:      {:8} ops/s  ({:.1} us/op)",
        (ops as f64 / elapsed.as_secs_f64()) as u64,
        elapsed.as_micros() as f64 / ops as f64);

    // Verify
    for _ in 0..20 { let _ = verifying_key.verify(msg, &sig); }
    ops = 0;
    let start = Instant::now();
    while start.elapsed() < duration {
        let _ = verifying_key.verify(msg, &sig);
        ops += 1;
    }
    let elapsed = start.elapsed();
    println!("  Ed25519 Verify:    {:8} ops/s  ({:.1} us/op)",
        (ops as f64 / elapsed.as_secs_f64()) as u64,
        elapsed.as_micros() as f64 / ops as f64);
}

fn bench_pbkdf2(iterations: u32, duration: Duration) {
    let password = b"password";
    let salt = b"salt";
    let mut key = [0u8; 32];

    let mut ops = 0u64;
    let start = Instant::now();
    while start.elapsed() < duration {
        pbkdf2_hmac::<Sha256>(password, salt, iterations, &mut key);
        ops += 1;
    }
    let elapsed = start.elapsed();
    println!("  PBKDF2-SHA256 i={}: {:6} ops/s  ({:.1} ms/op)",
        iterations,
        (ops as f64 / elapsed.as_secs_f64()) as u64,
        elapsed.as_millis() as f64 / ops as f64);
}

fn main() {
    println!("=== Rust Crypto Benchmark (reference) ===\n");
    let dur = Duration::from_secs(2);

    println!("--- AES-GCM ---");
    bench_aesgcm(128, 1024, dur);
    bench_aesgcm(128, 8192, dur);
    bench_aesgcm(256, 1024, dur);
    bench_aesgcm(256, 8192, dur);

    println!("\n--- X25519 ---");
    bench_x25519(dur);

    println!("\n--- Ed25519 ---");
    bench_ed25519(dur);

    println!("\n--- PBKDF2-SHA256 ---");
    bench_pbkdf2(1000, dur);
    bench_pbkdf2(10000, dur);
    bench_pbkdf2(100000, dur);
}
