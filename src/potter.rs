use std::env;

fn main() {
    dotenvy::dotenv().ok();
    let secret = env::var("POTTER_SECRET").expect("secret not found");
    println!("Potter Secret: {}", secret);
}
