# Moodlight

Demo project to remotely control an RPi Moodlight over Bluetooth via iOS and Android.

![trim 1EDE8B51-10E3-491E-B8B4-0F16D0B93A21](https://user-images.githubusercontent.com/1036685/182312590-3a52674a-fc47-4e9e-a9f4-605e22f63982.gif)


## Moodlight

In this demo, we are using the [Unicorn HAT](https://learn.pimoroni.com/article/getting-started-with-unicorn-phat) with the [Pimoroni Mood Light Kit](https://shop.pimoroni.com/products/mood-light-pi-zero-w-project-kit?variant=38477389450) which is powered by a [Raspbery Pi Zero WH](https://shop.pimoroni.com/products/raspberry-pi-zero-w?variant=39458414264403).

There are two companion apps - one for iOS and Android - which offer the ability to control the mood light via Ditto's P2P data sync. The mood light itself is powered by a Rust application which listens for data change events from the companion apps and then changes the light color. The Rust app uses pyo3 to call the python libraries from Pimoroni to control the Unicorn HAT.

## Requirements

* [Pimoroni Mood Light Kit](https://shop.pimoroni.com/products/mood-light-pi-zero-w-project-kit?variant=38477389450)
* iOS app requires iOS 16 as it is using a new SwiftUI Color Wheel component

## Setup

1. Request an offline license token through the [Portal](https://portal.ditto.live) and replace "YOUR_OFFLINE_TOKEN" with that value in all apps (iOS, Android, and moodlight-rs).

2. Install Raspbery Pi OS and follow the [getting started guide](https://learn.pimoroni.com/article/getting-started-with-unicorn-phat) for the Unicorn HAT to install the required firmware for the light:

```
https://learn.pimoroni.com/article/getting-started-with-unicorn-phat
```

3. [Configure the Raspberry Pi to support Bluetooth Low Energy with Ditto](https://docs.ditto.live/raspberrypi/installation)

4. Run the pre-compiled `moodlight-rs`:

```
cd moodlight-rs
sudo LD_LIBRARY_PATH=./ ./moodlight-rs [optional RGB value to immediately configure light - 0 0 0 to turn light off]
```

5. Run iOS or Android apps on a companion device to control the light!

6. Compile `moodlight-rs` manually:

```
cd moodlight-rs
rustup target add armv7-unknown-linux-gnueabihf
PYO3_CROSS_LIB_DIR=/usr/lib DITTOFFI_SEARCH_PATH=./ LIBDITTO_STATIC=0 cargo build --target arm-unknown-linux-gnueabihf
```

## Troubleshooting

Ensure you're using a high-quality SD card.
