# Moodlight

Demo project to remotely control an RPi Moodlight over Bluetooth via iOS and Android.

## Moodlight

In this demo, we are using the [Unicorn HAT Mini](https://learn.pimoroni.com/article/getting-started-with-unicorn-hat-mini) with the [Pimoroni Mood Light Kit](https://shop.pimoroni.com/products/mood-light-pi-zero-w-project-kit?variant=38477389450) which is powered by a [Raspbery Pi Zero WH](https://shop.pimoroni.com/products/raspberry-pi-zero-w?variant=39458414264403).

This demo uses pyo3 to call the python libraries from Pimoroni.

## Setup

1. Request an offline license token through the [Portal](https://portal.ditto.live) and replace "YOUR_OFFLINE_TOKEN" with that value in all apps (iOS, Android, and moodlight-rs).

2. Install Raspbery Pi OS and follow the [getting started guide](https://learn.pimoroni.com/article/getting-started-with-unicorn-hat-mini) for the Unicorn HAT Mini to install the required firmware for the light.

3. Cross compile `moodlight-rs` for Raspberry Pi:

```
cargo build --release
cd moodlight-rs
rustup target add armv7-unknown-linux-gnueabihf
PYO3_CROSS_LIB_DIR=/usr/lib DITTOFFI_SEARCH_PATH=/home/pi/ditto/target/arm-unknown-linux-gnueabihf/release LIBDITTO_STATIC=0 cargo build --target arm-unknown-linux-gnueabihf
```

4. Then copy `libdittoffi.so` and the `moodlight-rs` binary over to the RPi-Zero-W.


## Troubleshooting

Ensure you're using a high-quality SD card.
