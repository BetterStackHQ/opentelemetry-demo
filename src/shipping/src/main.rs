// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

use actix_web::{App, HttpServer};
use std::env;
use tracing::info;

mod shipping_service;
use shipping_service::{get_quote, ship_order};

#[actix_web::main]
async fn main() -> std::io::Result<()> {

    let port: u16 = env::var("SHIPPING_PORT")
        .expect("$SHIPPING_PORT is not set")
        .parse()
        .expect("$SHIPPING_PORT is not a valid port");
    let addr = format!("0.0.0.0:{}", port);
    info!(
        name = "ServerStartedSuccessfully",
        addr = addr.as_str(),
        message = "Shipping service is running"
    );

    HttpServer::new(|| {
        App::new()
            .service(get_quote)
            .service(ship_order)
    })
    .bind(&addr)?
    .run()
    .await
}
