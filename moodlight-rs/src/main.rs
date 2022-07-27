use dittolive_ditto::{identity, prelude::*};

use pyo3::{
    prelude::*,
    types::{PyModule, PyTuple},
};
use std::env;
use std::io;
use std::io::prelude::*;
use std::str::FromStr;
use std::sync::Arc;

// NOTE THIS BINARY MUST BE RUN AS ROOT
// LIMITATION OF THE PYTHON GPIO LIBRARY
fn main() {
    // Default Ditto Blue
    let mut arg1 = 39;
    let mut arg2 = 103;
    let mut arg3 = 245;

    if let Some(c_arg1) = env::args().nth(1) {
        arg1 = c_arg1.parse::<i32>().unwrap();
    }
    if let Some(c_arg2) = env::args().nth(2) {
        arg2 = c_arg2.parse::<i32>().unwrap();
    }
    if let Some(c_arg3) = env::args().nth(3) {
        arg3 = c_arg3.parse::<i32>().unwrap();
    }

    // Try out the light
    configure_light(arg1, arg2, arg3);

    // Setup Ditto
    let ditto = Ditto::builder()
    .with_root(Arc::new(PersistentRoot::from_current_exe().unwrap()))
        .with_identity(|ditto_root| {
            // expected by other apps
            let app_id = AppId::from_str("dittomoodlight").unwrap();
            // We don't want a fully random OfflinePlayground Identity as we
            // need to make sure we have a specific AppId shared by all peers
            identity::OfflinePlayground::new(ditto_root, app_id)
        }).unwrap()
        .with_transport_config(|_identity| -> TransportConfig {
            let mut transport_config = TransportConfig::new();
            transport_config.peer_to_peer.bluetooth_le.enabled = true;
            transport_config.peer_to_peer.lan.enabled = true;
            transport_config
        }).unwrap()
        .build().unwrap();

    ditto.set_offline_only_license_token("o2d1c2VyX2lkZURpdHRvZmV4cGlyeXgYMjAyMi0wOC0yNFQwNjo1OTo1OS45OTlaaXNpZ25hdHVyZXhYREVzSCtFeGliMVZ2L0p1WTJGcVJ0UXIrR0p4MDB2dHBKUW4vdzdwa3M1V1VNa2dnTUlPelgvSG1LZXVQWDFaWWhaamFxVElaWjNrczcvNHZlZE90R2c9PQ==").unwrap();
    ditto.start_sync();

    let store = ditto.store();
    let collection = store.collection("lights").unwrap();
    let light_id = DocumentId::new(&5).unwrap();

    let handler = move |docs: Vec<BoxedDocument>, _event| {
        if let Some(light_doc) = docs.first() {
            let red = light_doc.get::<f32>("red").unwrap();
            let green = light_doc.get::<f32>("green").unwrap();
            let blue = light_doc.get::<f32>("blue").unwrap();
            let is_off = light_doc.get::<bool>("isOff").unwrap();

            if is_off {
                configure_light(0, 0, 0);
            } else {
                configure_light(red as i32, green as i32, blue as i32);
            }
        }
    };
    let _lq = collection.find_by_id(light_id).observe(handler).unwrap();

    // downgrade our logging output before running the query
    Ditto::set_minimum_log_level(LogLevel::Debug);

    pause();
}

fn pause() {
    let mut stdin = io::stdin();
    let mut stdout = io::stdout();

    // We want the cursor to stay at the end of the line, so we print without a newline and flush manually.
    write!(stdout, "Running Ditto Moodlight - press any key to close!").unwrap();
    stdout.flush().unwrap();

    // Read a single byte and discard
    let _ = stdin.read(&mut [0u8]).unwrap();
}

fn configure_light(red: i32, green: i32, blue: i32) {
    Python::with_gil(|py| {
        let moodlight = PyModule::from_code(
            py,
            r#"

from random import randint
from time import sleep

import unicornhat as unicorn


#setup the unicorn hat
unicorn.set_layout(unicorn.AUTO)
unicorn.brightness(1)

#get the width and height of the hardware
width, height = unicorn.get_shape()

def toggle(r,g,b):
    #print the relevant message
    print('Setting RGA values: ' + str(r) + ', ' + str(g) + ', ' + str(b))
    #set the LEDs to the relevant lighting (all on/off)
    for y in range(height):
            for x in range(width):
                    unicorn.set_pixel(x,y,r,g,b)
                    unicorn.show()
    return True
    "#,
            "moodlight.py",
            "moodlight",
        ).unwrap();

        let args = PyTuple::new(py, &[red, green, blue]);
        let result: bool = moodlight.getattr("toggle").unwrap().call1(args).unwrap().extract().unwrap();
        assert_eq!(result, true);
    });
}
