//
//  Sinfonia4YouWatchApp.swift
//  Sinfonia4YouWatch Watch App
//
//  Created by Dalle on 26/03/2026.
//

import SwiftUI

@main
struct Sinfonia4YouWatch_Watch_AppApp: App {
    @StateObject private var rapportoGaraStore = RapportoGaraWatchStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(rapportoGaraStore)
        }
    }
}
