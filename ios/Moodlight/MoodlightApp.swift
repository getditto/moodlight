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
                        try MoodlightApp.ditto.setOfflineOnlyLicenseToken("YOUR_OFFLINE_TOKEN")
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
