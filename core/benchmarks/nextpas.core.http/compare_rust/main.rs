use std::env;
use std::io::{ErrorKind, Read, Write};
use std::net::{Shutdown, SocketAddr, TcpListener, TcpStream};
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::{Duration, Instant};

const REQUEST_NO_URL: &[u8] = b"GET / HTTP/1.1\r\nHost: localhost\r\nContent-Length: 0\r\n\r\n";
const REQUEST_URL_PATH: &[u8] =
    b"GET /api/v1/users HTTP/1.1\r\nHost: localhost\r\nContent-Length: 0\r\n\r\n";
const REQUEST_ADAPTER_NO_URL: &[u8] =
    b"GET / HTTP/1.1\r\nHost: localhost\r\nConnection: keep-alive\r\nContent-Length: 0\r\n\r\n";
const RESPONSE: &[u8] = b"HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 13\r\nConnection: keep-alive\r\n\r\nHello, World!";
const NOT_FOUND_RESPONSE: &[u8] =
    b"HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: keep-alive\r\n\r\n";
const RESPONSE_BODY_LEN: usize = 13;
const WORKLOAD_NO_URL: &str = "no_url";
const WORKLOAD_URL_PATH: &str = "url_path";
const WORKLOAD_ADAPTER_NO_URL: &str = "adapter_no_url";
const WORKLOAD_RESPONSE_1K: &str = "response_1k";

fn parse_options() -> (usize, usize, String) {
    let mut requests = 20_000usize;
    let mut threads = 4usize;
    let mut workload = WORKLOAD_NO_URL.to_string();
    let args: Vec<String> = env::args().collect();
    let mut index = 1usize;

    while index < args.len() {
        if args[index] == "--requests" && index + 1 < args.len() {
            if let Ok(value) = args[index + 1].parse::<usize>() {
                if value > 0 {
                    requests = value;
                }
            }
            index += 2;
        } else if args[index] == "--threads" && index + 1 < args.len() {
            if let Ok(value) = args[index + 1].parse::<usize>() {
                if value > 0 {
                    threads = value;
                }
            }
            index += 2;
        } else if args[index] == "--workload" && index + 1 < args.len() {
            if args[index + 1] == WORKLOAD_URL_PATH {
                workload = WORKLOAD_URL_PATH.to_string();
            } else if args[index + 1] == WORKLOAD_ADAPTER_NO_URL {
                workload = WORKLOAD_ADAPTER_NO_URL.to_string();
            } else if args[index + 1] == WORKLOAD_RESPONSE_1K {
                workload = WORKLOAD_RESPONSE_1K.to_string();
            } else {
                workload = WORKLOAD_NO_URL.to_string();
            }
            index += 2;
        } else {
            index += 1;
        }
    }

    if threads > requests {
        threads = requests;
    }

    (requests, threads, workload)
}

fn requests_for_thread(index: usize, total_requests: usize, threads: usize) -> usize {
    let mut count = total_requests / threads;
    if index < total_requests % threads {
        count += 1;
    }
    count
}

fn find_bytes(haystack: &[u8], needle: &[u8]) -> Option<usize> {
    haystack
        .windows(needle.len())
        .position(|window| window == needle)
}

fn read_from_stream(stream: &mut TcpStream, buffer: &mut Vec<u8>) -> bool {
    let mut chunk = [0u8; 1024];
    match stream.read(&mut chunk) {
        Ok(0) => false,
        Ok(read) => {
            buffer.extend_from_slice(&chunk[..read]);
            true
        }
        Err(ref err) if err.kind() == ErrorKind::WouldBlock => true,
        Err(ref err) if err.kind() == ErrorKind::TimedOut => false,
        Err(_) => false,
    }
}

fn read_one_request_matches_workload(
    stream: &mut TcpStream,
    buffer: &mut Vec<u8>,
    workload: &str,
) -> Option<bool> {
    loop {
        if let Some(end) = find_bytes(buffer, b"\r\n\r\n") {
            let request = &buffer[..end + 4];
            let matches_workload =
                workload != WORKLOAD_URL_PATH || request.starts_with(b"GET /api/v1/users ");
            buffer.drain(..end + 4);
            return Some(matches_workload);
        }
        if !read_from_stream(stream, buffer) {
            return None;
        }
    }
}

fn response_body_len_for_workload(workload: &str) -> usize {
    if workload == WORKLOAD_RESPONSE_1K {
        1024
    } else {
        RESPONSE_BODY_LEN
    }
}

fn build_response_1k() -> Vec<u8> {
    let mut response = Vec::with_capacity(96 + 1024);
    response.extend_from_slice(
        b"HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 1024\r\nConnection: keep-alive\r\n\r\n",
    );
    response.extend(std::iter::repeat(b'x').take(1024));
    response
}

fn read_one_response(stream: &mut TcpStream, buffer: &mut Vec<u8>, body_len: usize) -> bool {
    loop {
        if let Some(header_end) = find_bytes(buffer, b"\r\n\r\n") {
            let required = header_end + 4 + body_len;
            if buffer.len() >= required {
                buffer.drain(..required);
                return true;
            }
        }
        if !read_from_stream(stream, buffer) {
            return false;
        }
    }
}

fn handle_connection(mut stream: TcpStream, workload: String) {
    let _ = stream.set_read_timeout(Some(Duration::from_secs(10)));
    let _ = stream.set_write_timeout(Some(Duration::from_secs(10)));

    let mut buffer = Vec::with_capacity(1024);
    let response_1k = build_response_1k();
    while let Some(matches_workload) =
        read_one_request_matches_workload(&mut stream, &mut buffer, &workload)
    {
        let response = if matches_workload {
            if workload == WORKLOAD_RESPONSE_1K {
                response_1k.as_slice()
            } else {
                RESPONSE
            }
        } else {
            NOT_FOUND_RESPONSE
        };
        if stream.write_all(response).is_err() {
            break;
        }
    }
}

fn run_accept_loop(listener: TcpListener, stopping: Arc<AtomicBool>, workload: String) {
    let mut workers = Vec::new();

    while !stopping.load(Ordering::Relaxed) {
        match listener.accept() {
            Ok((stream, _)) => {
                let worker_workload = workload.clone();
                workers.push(thread::spawn(move || {
                    handle_connection(stream, worker_workload)
                }))
            }
            Err(ref err) if err.kind() == ErrorKind::WouldBlock => {
                thread::sleep(Duration::from_millis(1));
            }
            Err(_) => break,
        }
    }

    for worker in workers {
        let _ = worker.join();
    }
}

fn run_client(addr: SocketAddr, requests: usize, workload: String, completed: Arc<AtomicUsize>) {
    let mut stream = match TcpStream::connect(addr) {
        Ok(stream) => stream,
        Err(_) => return,
    };
    let _ = stream.set_nodelay(true);
    let _ = stream.set_read_timeout(Some(Duration::from_secs(10)));
    let _ = stream.set_write_timeout(Some(Duration::from_secs(10)));

    let mut buffer = Vec::with_capacity(1024);
    let response_body_len = response_body_len_for_workload(&workload);
    let request = match workload.as_str() {
        WORKLOAD_URL_PATH => REQUEST_URL_PATH,
        WORKLOAD_ADAPTER_NO_URL => REQUEST_ADAPTER_NO_URL,
        _ => REQUEST_NO_URL,
    };
    for _ in 0..requests {
        if stream.write_all(request).is_err() {
            break;
        }
        if !read_one_response(&mut stream, &mut buffer, response_body_len) {
            break;
        }
        completed.fetch_add(1, Ordering::Relaxed);
    }
    let _ = stream.shutdown(Shutdown::Both);
}

fn print_results(
    requests: usize,
    threads: usize,
    workload: &str,
    completed: usize,
    elapsed: Duration,
) {
    let elapsed_ns = elapsed.as_nanos() as u128;
    let ns_per_op = if completed > 0 {
        elapsed_ns / completed as u128
    } else {
        0
    };
    let req_per_sec = if elapsed_ns > 0 {
        completed as u128 * 1_000_000_000u128 / elapsed_ns
    } else {
        0
    };

    println!("operation=http.server.keepalive");
    println!("workload={}", workload);
    println!("impl=rust");
    println!("iterations={}", requests);
    println!("threads={}", threads);
    println!("completed={}", completed);
    println!("elapsed_ns={}", elapsed_ns);
    println!("ns/op={}", ns_per_op);
    println!("req/s={}", req_per_sec);
}

fn main() {
    let (requests, threads, workload) = parse_options();
    let listener = TcpListener::bind("127.0.0.1:0").expect("bind listener");
    listener.set_nonblocking(true).expect("set nonblocking");
    let addr = listener.local_addr().expect("local addr");
    let stopping = Arc::new(AtomicBool::new(false));
    let accept_stopping = Arc::clone(&stopping);
    let accept_workload = workload.clone();

    let accept_handle =
        thread::spawn(move || run_accept_loop(listener, accept_stopping, accept_workload));
    let completed = Arc::new(AtomicUsize::new(0));
    let mut clients = Vec::new();

    let start = Instant::now();
    for index in 0..threads {
        let client_completed = Arc::clone(&completed);
        let client_requests = requests_for_thread(index, requests, threads);
        let client_workload = workload.clone();
        clients.push(thread::spawn(move || {
            run_client(addr, client_requests, client_workload, client_completed)
        }));
    }

    for client in clients {
        let _ = client.join();
    }
    let elapsed = start.elapsed();

    stopping.store(true, Ordering::Relaxed);
    let _ = TcpStream::connect(addr);
    let _ = accept_handle.join();

    print_results(
        requests,
        threads,
        &workload,
        completed.load(Ordering::Relaxed),
        elapsed,
    );
}
