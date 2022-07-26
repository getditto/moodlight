//
//  ContentView.swift
//  Moodlight
//
//  Created by Adam Fish on 7/24/22.
//

import SwiftUI
import DittoSwift

struct ContentView: View {
    
    @State var liveQuery: DittoLiveQuery?
    
    @State private var color : Color = {
        var red: Double = 39
        var green: Double = 103
        var blue: Double = 245
        
        let colorDoc = MoodlightApp.ditto.store["lights"].findByID(DittoDocumentID(5)).exec()
        
        if let colorDoc = colorDoc {
            red = colorDoc["red"].doubleValue
            green = colorDoc["green"].doubleValue
            blue = colorDoc["blue"].doubleValue
        } else {
            ContentView.insertDefaultColor(red: red, green: green, blue: blue)
        }
        return Color(red: red/255, green: green/255, blue: blue/255)
    }() {
        didSet {
            ContentView.upsert(color: color)
        }
    }
    
    // Need a way to compare and prevent duplicate updates to color state
    // For some reason mutations call `didSet` or `onChange` multiple times
    // for each single mutation?
    private static var internalColor = Color.blue
    
    // Used to differentiate between a local mutation and an incoming sync
    // mutation. This allows us to break the loop so local mutations don't
    // fire a live query to then mutate the color state again.
    private static var isLocalChange = false
    
    var tapGesture: some Gesture {
        TapGesture()
            .onEnded {
                withAnimation {
                    color = Color.random()
                }
            }
    }
    
    var body: some View {
        VStack {
            Spacer()
            if #available(macOS 13.0, *) {
                ColorPicker("Pick a color", selection:$color, supportsOpacity: false)
                    .foregroundColor(Color.white)
                    .font(.largeTitle)
                    .fontWeight(.black)
                    .padding()
                    // FOR SOME REASON didSet IS NOT CALLED BY COLOR PICKER
                    //
                    .onChange(of: color) { newColor in
                        ContentView.upsert(color: color)
                    }
            } else {
                // Fallback on earlier versions
            }
            Spacer()
            Text("Or tap below to change color")
                .foregroundColor(Color.white)
                .font(.title2)
                .fontWeight(.bold)
            Spacer()
            Rectangle()
                .foregroundColor(color)
                .frame(maxWidth: .infinity, maxHeight: 600)
                .gesture(tapGesture)
        }
        .frame(
              minWidth: 0,
              maxWidth: .infinity,
              minHeight: 0,
              maxHeight: .infinity,
              alignment: .topLeading
            )
        .background(color.ignoresSafeArea())
        .navigationTitle("Ditto Moodlight")
        .onAppear {
            if liveQuery == nil {
                liveQuery = MoodlightApp.ditto.store["lights"].findByID(DittoDocumentID(5)).observe { colorDoc, _ in
                    if let colorDoc = colorDoc, !ContentView.isLocalChange {
                        let red = colorDoc["red"].doubleValue
                        let green = colorDoc["green"].doubleValue
                        let blue = colorDoc["blue"].doubleValue
                        
                        color = Color(red: red/255, green: green/255, blue: blue/255)
                    } else {
                        ContentView.isLocalChange = false
                    }
                }
            }
        }
    }
    
    static func insertDefaultColor(red: Double, green: Double, blue: Double) {
        ContentView.isLocalChange = true
        let _ = try! MoodlightApp.ditto.store["lights"].insert(
            [
                "red": red,
                "green": green,
                "blue": blue,
                "disabled": false
            ],
            id: 5,
            isDefault: true)
    }
    
    static func upsert(color: Color) {
        if let components = color.cgColor?.components, !Color.compareRGB(lhs: ContentView.internalColor, rhs: color) {
            let colors = ContentView.getRGBColor(components: components)
            
            ContentView.isLocalChange = true
            let _ = try! MoodlightApp.ditto.store["lights"].upsert([
                "_id": 5,
                "red": colors.red,
                "green": colors.green,
                "blue": colors.blue,
                "disabled": false
            ])
            ContentView.internalColor = color
            
        }
    }
    
    static func getRGBColor(components: [CGFloat]) -> (red: Double, green: Double, blue: Double) {
        let red = (components[0] * 255).rounded()
        let green = (components[1] * 255).rounded()
        let blue = (components[2] * 255).rounded()
        return (red, green, blue)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

extension Color {
    static func random() -> Color {
        return Color(red: Double.random(in: 0...1), green: Double.random(in: 0...1), blue: Double.random(in: 0...1))
    }
    
    // Add custom compare to look at only the RGB values
    static func compareRGB (lhs: Color, rhs: Color) -> Bool {
        if let lhComponents = lhs.cgColor?.components, let rhComponents = rhs.cgColor?.components {
            let lhRGB = ContentView.getRGBColor(components: lhComponents)
            let rhRGB = ContentView.getRGBColor(components: rhComponents)
            return lhRGB.red == rhRGB.red && lhRGB.green == rhRGB.green && lhRGB.blue == rhRGB.blue
        }
        return lhs == rhs
    }
}
