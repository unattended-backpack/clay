use std::env;

fn main() {
    dotenvy::dotenv().ok();
    let secret = env::var("CLAY_SECRET").expect("secret not found");
    println!("Secret: {}", secret);
}
