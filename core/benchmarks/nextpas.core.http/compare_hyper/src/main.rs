use bytes::Bytes;
use http_body_util::Full;
use hyper::body::Incoming;
use hyper::header::{CONNECTION, CONTENT_LENGTH, CONTENT_TYPE};
use hyper::server::conn::http1;
use hyper::service::service_fn;
use hyper::{Request, Response, StatusCode};
use hyper_util::rt::TokioIo;
use std::convert::Infallible;
use std::env;
use std::io::{ErrorKind, Read, Write};
use std::net::{Shutdown, SocketAddr, TcpListener as StdTcpListener, TcpStream};
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::{Duration, Instant};
use tokio::net::TcpListener as TokioTcpListener;
use tokio::runtime::Builder;
use tokio::time;

const REQUEST_NO_URL: &[u8] = b"GET / HTTP/1.1\r\nHost: localhost\r\nContent-Length: 0\r\n\r\n";
const REQUEST_URL_PATH: &[u8] =
    b"GET /api/v1/users HTTP/1.1\r\nHost: localhost\r\nContent-Length: 0\r\n\r\n";
const REQUEST_ADAPTER_NO_URL: &[u8] =
    b"GET / HTTP/1.1\r\nHost: localhost\r\nConnection: keep-alive\r\nContent-Length: 0\r\n\r\n";
const RESPONSE_BODY: &[u8] = b"Hello, World!";
const RESPONSE_BODY_1K: [u8; 1024] = [b'x'; 1024];
const WORKLOAD_NO_URL: &str = "no_url";
const WORKLOAD_URL_PATH: &str = "url_path";
const WORKLOAD_ADAPTER_NO_URL: &str = "adapter_no_url";
const WORKLOAD_RESPONSE_1K: &str = "response_1k";
const VALID_WORKLOADS_TEXT: &str = "no_url, url_path, adapter_no_url, or response_1k";
const CLIENT_READ_MODE: &str = "header_plus_content_length";

type ResponseBody = Full<Bytes>;

fn is_valid_workload(value: &str) -> bool {
    value == WORKLOAD_NO_URL
        || value == WORKLOAD_URL_PATH
        || value == WORKLOAD_ADAPTER_NO_URL
        || value == WORKLOAD_RESPONSE_1K
}

fn reject_invalid_workload(value: &str) -> ! {
    eprintln!(
        "invalid --workload: {}; expected one of: {}",
        value, VALID_WORKLOADS_TEXT
    );
    std::process::exit(2);
}

fn reject_invalid_positive_option(name: &str, value: &str) -> ! {
    eprintln!("invalid {}: {}; expected positive integer", name, value);
    std::process::exit(2);
}

fn parse_options() -> (usize, usize, usize, String) {
    let mut requests = 20_000usize;
    let mut threads = 4usize;
    let mut workload = WORKLOAD_NO_URL.to_string();
    let args: Vec<String> = env::args().collect();
    let mut index = 1usize;

    while index < args.len() {
        if args[index] == "--requests" && index + 1 < args.len() {
            requests = match args[index + 1].parse::<usize>() {
                Ok(value) if value > 0 => value,
                _ => reject_invalid_positive_option("--requests", &args[index + 1]),
            };
            index += 2;
        } else if args[index] == "--threads" && index + 1 < args.len() {
            threads = match args[index + 1].parse::<usize>() {
                Ok(value) if value > 0 => value,
                _ => reject_invalid_positive_option("--threads", &args[index + 1]),
            };
            index += 2;
        } else if args[index] == "--workload" && index + 1 < args.len() {
            if is_valid_workload(&args[index + 1]) {
                workload = args[index + 1].clone();
            } else {
                reject_invalid_workload(&args[index + 1]);
            }
            index += 2;
        } else {
            index += 1;
        }
    }

    let requested_threads = threads;
    let effective_threads = requested_threads.min(requests);

    (requests, requested_threads, effective_threads, workload)
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

fn response_body_len_for_workload(workload: &str) -> usize {
    if workload == WORKLOAD_RESPONSE_1K {
        1024
    } else {
        RESPONSE_BODY.len()
    }
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

fn build_response(status: StatusCode, body: Bytes) -> Response<ResponseBody> {
    Response::builder()
        .status(status)
        .header(CONTENT_TYPE, "text/plain")
        .header(CONTENT_LENGTH, body.len().to_string())
        .header(CONNECTION, "keep-alive")
        .body(Full::new(body))
        .expect("build response")
}

async fn handle_hyper_request(
    request: Request<Incoming>,
    workload: Arc<String>,
) -> Result<Response<ResponseBody>, Infallible> {
    let matches_workload =
        workload.as_str() != WORKLOAD_URL_PATH || request.uri().path() == "/api/v1/users";

    let response = if !matches_workload {
        build_response(StatusCode::NOT_FOUND, Bytes::new())
    } else if workload.as_str() == WORKLOAD_RESPONSE_1K {
        build_response(StatusCode::OK, Bytes::from_static(&RESPONSE_BODY_1K))
    } else {
        build_response(StatusCode::OK, Bytes::from_static(RESPONSE_BODY))
    };
    Ok(response)
}

async fn run_accept_loop(
    listener: TokioTcpListener,
    stopping: Arc<AtomicBool>,
    workload: Arc<String>,
) {
    while !stopping.load(Ordering::Relaxed) {
        match time::timeout(Duration::from_millis(10), listener.accept()).await {
            Ok(Ok((stream, _))) => {
                let connection_workload = Arc::clone(&workload);
                tokio::spawn(async move {
                    let service_workload = Arc::clone(&connection_workload);
                    let service = service_fn(move |request| {
                        handle_hyper_request(request, Arc::clone(&service_workload))
                    });
                    let io = TokioIo::new(stream);
                    let _ = http1::Builder::new().serve_connection(io, service).await;
                });
            }
            Ok(Err(_)) => break,
            Err(_) => {}
        }
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
    requested_threads: usize,
    effective_threads: usize,
    workload: &str,
    completed: usize,
    elapsed: Duration,
) {
    let elapsed_ns = elapsed.as_nanos();
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
    println!("impl=rust_hyper");
    println!("rust_profile=hyper_tokio");
    println!("client_read_mode={}", CLIENT_READ_MODE);
    println!(
        "response_body_bytes={}",
        response_body_len_for_workload(workload)
    );
    println!("iterations={}", requests);
    println!("requested_threads={}", requested_threads);
    println!("effective_threads={}", effective_threads);
    println!("threads={}", effective_threads);
    println!("completed={}", completed);
    println!("elapsed_ns={}", elapsed_ns);
    println!("ns/op={}", ns_per_op);
    println!("req/s={}", req_per_sec);
}

fn main() {
    let (requests, requested_threads, effective_threads, workload) = parse_options();
    let std_listener = StdTcpListener::bind("127.0.0.1:0").expect("bind listener");
    std_listener
        .set_nonblocking(true)
        .expect("set nonblocking listener");
    let addr = std_listener.local_addr().expect("local addr");

    let stopping = Arc::new(AtomicBool::new(false));
    let server_stopping = Arc::clone(&stopping);
    let server_workload = Arc::new(workload.clone());
    let server_thread = thread::spawn(move || {
        let runtime = Builder::new_multi_thread()
            .enable_all()
            .build()
            .expect("tokio runtime");
        runtime.block_on(async move {
            let listener = TokioTcpListener::from_std(std_listener).expect("tokio listener");
            run_accept_loop(listener, server_stopping, server_workload).await;
        });
    });

    thread::sleep(Duration::from_millis(50));

    let completed = Arc::new(AtomicUsize::new(0));
    let start = Instant::now();
    let mut client_threads = Vec::new();
    for index in 0..effective_threads {
        let thread_requests = requests_for_thread(index, requests, effective_threads);
        let client_workload = workload.clone();
        let client_completed = Arc::clone(&completed);
        client_threads.push(thread::spawn(move || {
            run_client(addr, thread_requests, client_workload, client_completed)
        }));
    }

    for client in client_threads {
        let _ = client.join();
    }
    let elapsed = start.elapsed();

    stopping.store(true, Ordering::Relaxed);
    let _ = TcpStream::connect(addr);
    let _ = server_thread.join();

    print_results(
        requests,
        requested_threads,
        effective_threads,
        &workload,
        completed.load(Ordering::Relaxed),
        elapsed,
    );
}
