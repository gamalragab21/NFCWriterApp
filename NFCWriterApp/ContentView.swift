//
//  ContentView.swift
//  NFCWriterApp
//
//  Created by Gamal Ragab on 27/02/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = DoorAccessViewModel()

    var body: some View {
        NavigationStack {
            DoorAccessView(viewModel: viewModel)
        }
    }
}

#Preview {
    ContentView()
}
