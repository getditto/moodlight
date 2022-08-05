# Raspberry Pi Mood Light

Demo project to remotely control an Raspberry Pi Mood Light over Bluetooth via iOS and Android.

![trim 1EDE8B51-10E3-491E-B8B4-0F16D0B93A21](https://user-images.githubusercontent.com/1036685/182312590-3a52674a-fc47-4e9e-a9f4-605e22f63982.gif)

[📺 Watch the video](https://www.youtube.com/watch?v=JbuY6xy3VLA)

## Overview

In this demo, we are using the [Unicorn HAT](https://learn.pimoroni.com/article/getting-started-with-unicorn-phat) or [Unicorn HAT Mini](https://learn.pimoroni.com/article/getting-started-with-unicorn-hat-mini) with the [Pimoroni Mood Light Kit](https://shop.pimoroni.com/products/mood-light-pi-zero-w-project-kit?variant=38477389450) which is powered by a [Raspbery Pi Zero WH](https://shop.pimoroni.com/products/raspberry-pi-zero-w?variant=39458414264403).

There are two companion apps - one for iOS and Android - which offer the ability to control the mood light via Ditto's P2P data sync. The mood light itself is powered by a Rust application which listens for data change events from the companion apps and then changes the light color. The Rust app uses pyo3 to call the python libraries from Pimoroni to control the Unicorn HAT.

## Requirements

* [Pimoroni Mood Light Kit](https://shop.pimoroni.com/products/mood-light-pi-zero-w-project-kit?variant=38477389450)
* 32 bit Raspberry Pi OS
* iOS app requires iOS 16 as it is using a new SwiftUI Color Wheel component
* Python shared library installed

## Setup

1. Request an offline license token through the [Portal](https://portal.ditto.live) and replace "YOUR_OFFLINE_TOKEN" with that value in all apps (iOS, Android, and moodlight-rs).

2. Install Raspberry Pi OS (32 bit) and follow the [Unicorn HAT](https://learn.pimoroni.com/article/getting-started-with-unicorn-phat) or [Unicorn HAT Mini](https://learn.pimoroni.com/article/getting-started-with-unicorn-hat-mini) getting started guide to install the required firmware for the light.

3. Copy `moodlight-rs` to the Raspberry Pi.

```
scp -r moodlight-rs pi@raspberrypi.local:~/
```

4. Install rust on the Raspberry Pi

```
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

5. [Configure the Raspberry Pi to support Bluetooth Low Energy with Ditto](https://docs.ditto.live/raspberrypi/installation)

6. Compile `moodlight-rs` manually on the Raspberry Pi:

```
cd moodlight-rs

// If cross-compiling to original RPi-Zero-W
rustup target add arm-unknown-linux-gnueabihf

// Install the Python shared library
sudo apt install python3-dev python3-venv python3-pip

[PYO3_CROSS_LIB_DIR=/usr/lib] DITTOFFI_SEARCH_PATH=./ LIBDITTO_STATIC=0 cargo build [--target arm-unknown-linux-gnueabihf]
```

7. Run `moodlight-rs`:

```
// Pass --mini argument if Unicorn pHAT Mini
// Add additional RGB values to set initial light color
sudo LD_LIBRARY_PATH=./ ./target/debug/moodlight-rs [--mini true] [-- 0 0 0]
```

8. Run iOS or Android apps on a companion device to control the light!


## Troubleshooting

* Ensure you're using a high-quality SD card.
* If Rust installation fails, you may need to increase the [swap size](https://pimylifeup.com/raspberry-pi-swap-file/) on your Raspberry Pi. (see [this issue](https://github.com/rust-lang/rustup/issues/2717))
