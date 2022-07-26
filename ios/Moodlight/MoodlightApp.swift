//
//  MoodlightApp.swift
//  Moodlight
//
//  Created by Adam Fish on 7/24/22.
//

import SwiftUI
import DittoSwift

@main
struct MoodlightApp: App {
    
    static var ditto = Ditto(identity: .offlinePlayground(appID: "dittomoodlight"))
    
    @State var isPresentingAlert = false
    @State var errorMessage = ""
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear(perform: {
                    do {
                        //DittoLogger.minimumLogLevel = .debug
                        try MoodlightApp.ditto.setOfflineOnlyLicenseToken("o2d1c2VyX2lkZURpdHRvZmV4cGlyeXgYMjAyMi0wOC0yNFQwNjo1OTo1OS45OTlaaXNpZ25hdHVyZXhYREVzSCtFeGliMVZ2L0p1WTJGcVJ0UXIrR0p4MDB2dHBKUW4vdzdwa3M1V1VNa2dnTUlPelgvSG1LZXVQWDFaWWhaamFxVElaWjNrczcvNHZlZE90R2c9PQ==")
                        try MoodlightApp.ditto.tryStartSync()
                    } catch (let err) {
                        isPresentingAlert = true
                        errorMessage = err.localizedDescription
                    }
                })
                .alert(isPresented: $isPresentingAlert) {
                    Alert(title: Text("Uh Oh"), message: Text("There was an error trying to start the sync. Here's the error \(errorMessage) Ditto will continue working as a local database."), dismissButton: .default(Text("Got it!")))
                }
        }
    }
}
