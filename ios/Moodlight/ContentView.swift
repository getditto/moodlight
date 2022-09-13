//
//  ContentView.swift
//  Moodlight
//
//  Created by Adam Fish on 7/24/22.
//

import SwiftUI
import DittoSwift
import Combine
import CouchbaseLiteSwift

struct ContentView: View {
    
    class ViewModel: ObservableObject {
        
        var cancellables = Set<AnyCancellable>()
            
        @Published var isOff: Bool = getPersistedIsOff()
                
        @Published var color : Color = {
            var red: Double = 39
            var green: Double = 103
            var blue: Double = 245
            
            if let persistedColors = getPersistedRGBColors() {
                red = persistedColors.red
                green = persistedColors.green
                blue = persistedColors.blue
            } else {
                insertDefaultColor(red: red, green: green, blue: blue)
            }
            
            ContentView.ViewModel.internalColor = Color(red: red/255, green: green/255, blue: blue/255)
            return ContentView.ViewModel.internalColor
            
//            return Color(red: red, green: green, blue: blue)
        }()
        
        // Need a way to compare and prevent duplicate updates to color state
        // For some reason mutations call `didSet` or `onChange` multiple times
        // for each single mutation?
        private static var internalColor = Color.blue

        static var internalIsOff = false
        
        // Used to differentiate between a local mutation and an incoming sync
        // mutation. This allows us to break the loop so local mutations don't
        // fire a live query to then mutate the color state again.
        static var isLocalChange = false
        
        var tapGesture: some Gesture {
            TapGesture()
                .onEnded {
                    withAnimation {
                        ContentView.ViewModel.isLocalChange = true
                        self.color = Color.random()
//                        self.upsert(color: self.color)

                    }
                }
        }
        
        init() {
            self.refreshData()
                        
            DataManger.shared.database.addChangeListener({ [weak self] listener in
                self?.refreshData()
            })
        }
        
        func refreshData() {
            let database = DataManger.shared.database
            if let doc = database.document(withID: "5"), !ContentView.ViewModel.isLocalChange {
                let red = doc.double(forKey: "red")
                let green = doc.double(forKey: "green")
                let blue = doc.double(forKey: "blue")
                let isOff = doc.boolean(forKey: "isOff")
                self.color = Color(red: red/255, green: green/255, blue: blue/255)
                self.isOff = isOff
            }
            else {
                ContentView.ViewModel.isLocalChange = false
            }
        }
        
        
        static func getPersistedRGBColors() -> (red: Double, green: Double, blue: Double)? {
            let database = DataManger.shared.database

            if let doc = database.document(withID: "5") {
                let red = doc.double(forKey: "red")
                let green = doc.double(forKey: "green")
                let blue = doc.double(forKey: "blue")
                return (red: red, green: green, blue: blue)
            }
            return nil
        }
        
        
        static func insertDefaultColor(red: Double, green: Double, blue: Double) {
            ContentView.ViewModel.isLocalChange = true
            DataManger.shared.sendData(id: "5", red: red, green: green, blue: blue, isOff: false)
        }
        
        static func getPersistedIsOff() -> Bool {
            let database = DataManger.shared.database
            if let doc = database.document(withID: "5") {
                let isOff = doc.boolean(forKey: "isOff")

                return isOff
            }
            return false
        }
        
        
        func upsert(color: Color) {
//            if let components = color.cgColor?.components, !Color.compareRGB(lhs: ContentView.ViewModel.internalColor, rhs: color) {
            let colors = ContentView.ViewModel.getRGBColors(components: (color.cgColor?.components)!)
                
            DataManger.shared.updateColors(id: "5", red: colors.red, green: colors.green, blue: colors.blue)
            
            ContentView.ViewModel.isLocalChange = true
            ContentView.ViewModel.internalColor = color
        }
        
        func upsert(isOff: Bool) {
            DataManger.shared.updateIsOFF(id: "5", isOff: self.isOff)
            
            ContentView.ViewModel.isLocalChange = true
        }
        
        static func getRGBColors(components: [CGFloat]) -> (red: Double, green: Double, blue: Double) {
            let red = (components[0] * 255).rounded()
            let green = (components[1] * 255).rounded()
            let blue = (components[2] * 255).rounded()
            return (red, green, blue)
        }
        
        
    }

    
    @ObservedObject var viewModel = ViewModel()

    var body: some View {
        VStack {
            Spacer()
            if !viewModel.isOff {
                if #available(macOS 13.0, *) {
                    ColorPicker("Pick a color", selection:$viewModel.color, supportsOpacity: false)
                        .foregroundColor(Color.white)
                        .font(.largeTitle)
                        .font(Font.headline.weight(.light))                        .padding()
                        // FOR SOME REASON didSet IS NOT CALLED BY COLOR PICKER
                        .onChange(of: viewModel.color) { newColor in
//                            if(ContentView.ViewModel.isLocalChange) {
                                viewModel.upsert(color: viewModel.color)
//                            }
                        }
                        .offset(y: 20)

                        
                } else {
                    // Fallback on earlier versions
                }
                Spacer()
                Text("Or tap below to change color")
                    .foregroundColor(Color.white)
                    .font(.title2)
                    .fontWeight(.bold)
                    .offset(y: 20)

                Spacer()
                Rectangle()
                    .foregroundColor(viewModel.color)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .gesture(viewModel.tapGesture)
                    .offset(y: 20)

            }
            else {
                Rectangle()
                    .foregroundColor(Color.black)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Spacer()
            Toggle("Turn Off", isOn: $viewModel.isOff)
                .foregroundColor(Color.white)
                .font(.subheadline)
                .font(Font.headline.weight(.bold))
                .padding()
                .onReceive(Just(viewModel.isOff)) { _ in
                    if ContentView.ViewModel.internalIsOff != viewModel.isOff {
                        ContentView.ViewModel.isLocalChange = true
                        viewModel.upsert(isOff: viewModel.isOff)
                        ContentView.ViewModel.internalIsOff = viewModel.isOff
                    }
                }
                .offset(y: -20)

        }
        .frame(
              minWidth: 0,
              maxWidth: .infinity,
              minHeight: 0,
              maxHeight: .infinity,
              alignment: .topLeading
            )
        .background(viewModel.isOff ? Color.black : viewModel.color)
        .ignoresSafeArea()
        .navigationTitle("Ditto Moodlight")

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
            let lhRGB = ContentView.ViewModel.getRGBColors(components: lhComponents)
            let rhRGB = ContentView.ViewModel.getRGBColors(components: rhComponents)

            return lhRGB.red == rhRGB.red && lhRGB.green == rhRGB.green && lhRGB.blue == rhRGB.blue
        }
        return lhs == rhs
    }
}
