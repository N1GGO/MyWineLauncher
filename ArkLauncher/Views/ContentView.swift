//
//  ContentView.swift
//  WineLauncher
//
//  Created by Nico Werner on 30.09.26.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {

    @State private var viewModel: ContentViewModel
    @State private var showingFileImporter = false
    @State private var fileImporterMode: FileImporterMode = .installer
    @State private var fileImporterDirectory: URL?
    @State private var steamSetupWindow: NSWindow?
    @State private var showingSteamGamesSheet = false


    init() {

        let configuration = Configuration(gamePath: nil)

        _viewModel = State(
            initialValue: ContentViewModel(
                config: configuration
            )
        )
    }

    private let columns = [
        GridItem(.adaptive(minimum: 180), spacing: 16)
    ]

    var body: some View {

        VStack(spacing: 20) {

            Text("Wine Launcher")
                .font(.largeTitle)
                .bold()

            Text(viewModel.state.stateText)
            
            ScrollView {
                LazyVGrid(
                    columns: columns,
                    spacing: 16
                ) {

                    ForEach(viewModel.applications) { application in
                        applicationTile(application)
                    }

                    addApplicationTile()
                }
                .padding()
            }

        }
        .padding()
        .fileDialogDefaultDirectory(fileImporterDirectory)
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.exe],
            allowsMultipleSelection: false
        ) { result in

            switch result {

            case .success(let urls):
                guard let url = urls.first else {
                    return
                }

                switch fileImporterMode {

                case .installer:
                    Task {
                        await viewModel.selectApplication(
                            url: url
                        )
                    }

                case .installedApplication:
                    Task {
                        await viewModel.selectInstalledApplication(
                            url: url
                        )
                    }
                }

            case .failure(let error):
                print(
                    "WineLauncher: Dateiauswahl fehlgeschlagen – \(error)"
                )
            }
        }




    }

    @ViewBuilder
    private func applicationTile(
        _ application: WindowsApplication
    ) -> some View {
        ZStack(alignment: .bottomTrailing) {

            Button {
                viewModel.selectApplication(
                    application: application
                )
            } label: {

                VStack(alignment: .leading, spacing: 8) {

                    Text(application.name)
                        .font(.headline)
                        .lineLimit(2)
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )

                    Text(application.prefixName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                }
                .padding()
                .frame(
                    maxWidth: .infinity,
                    minHeight: 140
                )
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            viewModel.selectedApplication?.id == application.id
                            ? Color.accentColor.opacity(0.15)
                            : Color.secondary.opacity(0.08)
                        )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            viewModel.selectedApplication?.id == application.id
                            ? Color.accentColor
                            : Color.secondary.opacity(0.2),
                            lineWidth: 1
                        )
                }
            }
            .buttonStyle(.plain)

            HStack {
                if viewModel.selectedApplication?.id == application.id {
                    switch viewModel.state {

                    case .starting:
                        ProgressView()
                            .controlSize(.small)
                            .frame(
                                width: 28,
                                height: 28
                            )

                    case .running:
                        Button {
                            viewModel.stop()
                        } label: {
                            Image(systemName: "stop.fill")
                                .frame(
                                    width: 28,
                                    height: 28
                                )
                        }
                        .buttonStyle(.borderless)

                    case .ready, .ended, .killed:
                        Button {
                            viewModel.selectApplication(
                                application: application
                            )
                            viewModel.start()
                        } label: {
                            Image(systemName: "play.fill")
                                .frame(
                                    width: 28,
                                    height: 28
                                )
                        }
                        .buttonStyle(.borderless)
                    }

                } else {
                    Button {
                        viewModel.selectApplication(
                            application: application
                        )
                        viewModel.start()
                    } label: {
                        Image(systemName: "play.fill")
                            .frame(
                                width: 28,
                                height: 28
                            )
                    }
                    .buttonStyle(.borderless)
                }

                Spacer()

                Menu {
                    Button("EXE auswählen") {
                        viewModel.selectApplication(
                            application: application
                        )

                        selectInstalledExecutable(
                            for: application
                        )
                    }
                    

                    Divider()

                    Button("Löschen") {
                        viewModel.removeApplication(application)
                    }
                } label: {
                    Image(systemName: "gearshape")
                        .frame(
                            width: 28,
                            height: 28
                        )
                }
                .menuStyle(.borderlessButton)

            }
            .padding(8)

        }
    }

    @ViewBuilder
    private func addApplicationTile() -> some View {

        Button {
            fileImporterMode = .installer
            showingFileImporter = true
        } label: {

            VStack(spacing: 10) {

                Image(systemName: "plus")
                    .font(.system(size: 28))

                Text("Anwendung hinzufügen")
                    .font(.headline)
            }
            .frame(
                maxWidth: .infinity,
                minHeight: 140
            )
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        Color.secondary.opacity(0.05)
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        Color.secondary.opacity(0.2),
                        style: StrokeStyle(
                            lineWidth: 1,
                            dash: [6]
                        )
                    )
            }
        }
        .buttonStyle(.plain)
    }
    
    private func selectInstalledExecutable(
        for application: WindowsApplication
    ) {
        let panel = NSOpenPanel()

        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.exe]
        panel.directoryURL = application.prefixURL
            .appendingPathComponent(
                "drive_c",
                isDirectory: true
            )

        if panel.runModal() == .OK,
           let url = panel.url {

            Task {
                await viewModel.selectInstalledApplication(
                    url: url
                )
            }
        }
    }
    
}
