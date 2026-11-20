use axum::{routing::get, Router};

async fn health() -> &'static str {
    "ok"
}

#[tokio::main]
async fn main() {
    let app = Router::new().route("/health", get(health));

    let listener = tokio::net::TcpListener::bind("127.0.0.1:3001")
        .await
        .expect("failed to bind 127.0.0.1:3001");

    println!("backend listening on http://127.0.0.1:3001");
    axum::serve(listener, app).await.expect("server error");
}
