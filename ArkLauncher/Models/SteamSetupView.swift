//
//  SteamSetupView.swift
//  WineLauncher
//
//  Created by Nico Werner on 04.10.26.
//

import SwiftUI

struct SteamSetupView: View {
    
    @StateObject private var setupService = SteamSetupService()
    @Environment(\.dismiss) private var dismiss
    
    let prefixURL: URL
    let onComplete: () -> Void
    
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        VStack(spacing: 24) {
            
            // Header
            VStack(spacing: 8) {
                Image(systemName: "gearshape.2.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)
                
                Text("Steam-Optimierungen")
                    .font(.largeTitle)
                    .bold()
                
                Text("Installiert DXMT und Steam Wrapper für optimale Performance")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 32)
            
            Divider()
            
            // Status
            VStack(alignment: .leading, spacing: 16) {
                
                switch setupService.setupProgress {
                case .notStarted:
                    setupInfoView
                    
                case .downloadingDXMT, .installingDXMT, .compilingWrapper,
                     .installingWrapper, .applyingRegistryTweaks, .verifying:
                    progressView
                    
                case .completed:
                    completionView
                    
                case .failed(let error):
                    errorView(error: error)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.1))
            )
            
            Spacer()
            
            // Buttons
            HStack(spacing: 16) {
                Button("Abbrechen") {
                    dismiss()
                }
                .buttonStyle(.borderless)
                .disabled(isSetupInProgress)
                
                Spacer()
                
                if case .notStarted = setupService.setupProgress {
                    Button("Installation starten") {
                        startSetup()
                    }
                    .buttonStyle(.borderedProminent)
                } else if case .completed = setupService.setupProgress {
                    Button("Fertig") {
                        onComplete()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(32)
        .frame(minWidth: 600, maxWidth: 600,
               minHeight: 500, maxHeight: .infinity)
        .alert("Fehler", isPresented: $showError) {
            Button("OK", role: .cancel) {
                dismiss()
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Views
    
    private var setupInfoView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Was wird installiert:")
                .font(.headline)
            
            FeatureRow(
                icon: "cube.fill",
                title: "DXMT",
                description: "DirectX-zu-Metal Translation für GPU-Beschleunigung"
            )
            
            FeatureRow(
                icon: "doc.text.fill",
                title: "Steam Wrapper",
                description: "Behebt schwarzes Fenster und CEF-Rendering-Probleme"
            )
            
            FeatureRow(
                icon: "slider.horizontal.3",
                title: "Registry-Optimierungen",
                description: "Verbesserte Fenster-Verwaltung und Kompatibilität"
            )
            
            Divider()
                .padding(.vertical, 8)
            
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                
                Text("Benötigt MinGW: brew install mingw-w64")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var progressView: some View {
        VStack(spacing: 20) {
            ProgressView(value: setupService.progressPercent) {
                HStack {
                    Text(setupService.currentStep)
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("\(Int(setupService.progressPercent * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                StepRow(
                    title: "DXMT herunterladen",
                    state: stepState(for: [.downloadingDXMT, .installingDXMT])
                )
                
                StepRow(
                    title: "DXMT installieren",
                    state: stepState(for: [.installingDXMT])
                )
                
                StepRow(
                    title: "Wrapper kompilieren",
                    state: stepState(for: [.compilingWrapper])
                )
                
                StepRow(
                    title: "Wrapper installieren",
                    state: stepState(for: [.installingWrapper])
                )
                
                StepRow(
                    title: "Registry-Tweaks anwenden",
                    state: stepState(for: [.applyingRegistryTweaks])
                )
                
                StepRow(
                    title: "Verifizieren",
                    state: stepState(for: [.verifying])
                )
            }
        }
    }
    
    private var completionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            
            Text("Installation abgeschlossen!")
                .font(.title2)
                .bold()
            
            Text("Steam ist jetzt vollständig optimiert und kann gestartet werden.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
    
    private func errorView(error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.red)
            
            Text("Installation fehlgeschlagen")
                .font(.title2)
                .bold()
            
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
    
    // MARK: - Helper Views
    
    private struct FeatureRow: View {
        let icon: String
        let title: String
        let description: String
        
        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.blue)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .bold()
                    
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private struct StepRow: View {
        let title: String
        let state: StepState
        
        enum StepState {
            case pending
            case active
            case completed
        }
        
        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.body)
                    .foregroundStyle(iconColor)
                    .frame(width: 20)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(state == .pending ? .secondary : .primary)
            }
        }
        
        private var iconName: String {
            switch state {
            case .pending:
                return "circle"
            case .active:
                return "arrow.right.circle.fill"
            case .completed:
                return "checkmark.circle.fill"
            }
        }
        
        private var iconColor: Color {
            switch state {
            case .pending:
                return .secondary
            case .active:
                return .blue
            case .completed:
                return .green
            }
        }
    }
    
    // MARK: - Helpers
    
    private var isSetupInProgress: Bool {
        switch setupService.setupProgress {
        case .downloadingDXMT, .installingDXMT, .compilingWrapper,
             .installingWrapper, .applyingRegistryTweaks, .verifying:
            return true
        default:
            return false
        }
    }
    
    private func stepState(for steps: [SteamSetupService.SetupProgress]) -> StepRow.StepState {
        switch setupService.setupProgress {
        case .downloadingDXMT, .installingDXMT, .compilingWrapper,
             .installingWrapper, .applyingRegistryTweaks, .verifying:
            // Prüfe ob einer der Schritte der aktuelle ist
            for step in steps {
                if isCurrentStep(step) {
                    return .active
                }
            }
            // Sonst prüfe ob der Schritt abgeschlossen ist
            if let firstStep = steps.first, isStepCompleted(firstStep) {
                return .completed
            } else {
                return .pending
            }
        case .completed:
            return .completed
        default:
            return .pending
        }
    }
    
    private func isCurrentStep(_ step: SteamSetupService.SetupProgress) -> Bool {
        // Vergleiche nur die enum case, nicht die associated values
        return isSameCase(setupService.setupProgress, step)
    }
    
    private func isSameCase(_ lhs: SteamSetupService.SetupProgress, _ rhs: SteamSetupService.SetupProgress) -> Bool {
        switch (lhs, rhs) {
        case (.notStarted, .notStarted),
             (.downloadingDXMT, .downloadingDXMT),
             (.installingDXMT, .installingDXMT),
             (.compilingWrapper, .compilingWrapper),
             (.installingWrapper, .installingWrapper),
             (.applyingRegistryTweaks, .applyingRegistryTweaks),
             (.verifying, .verifying),
             (.completed, .completed),
             (.failed, .failed):
            return true
        default:
            return false
        }
    }
    
    private func isStepCompleted(_ step: SteamSetupService.SetupProgress) -> Bool {
        let order: [SteamSetupService.SetupProgress] = [
            .downloadingDXMT,
            .installingDXMT,
            .compilingWrapper,
            .installingWrapper,
            .applyingRegistryTweaks,
            .verifying
        ]
        
        // Finde den Index des aktuellen Steps
        var currentIndex: Int?
        for (index, orderStep) in order.enumerated() {
            if isSameCase(setupService.setupProgress, orderStep) {
                currentIndex = index
                break
            }
        }
        
        // Finde den Index des zu prüfenden Steps
        var stepIndex: Int?
        for (index, orderStep) in order.enumerated() {
            if isSameCase(step, orderStep) {
                stepIndex = index
                break
            }
        }
        
        guard let current = currentIndex, let stepIdx = stepIndex else {
            return false
        }
        
        return stepIdx < current
    }
    
    private func startSetup() {
        Task {
            do {
                try await setupService.setupSteamOptimizations(for: prefixURL)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

#Preview {
    SteamSetupView(
        prefixURL: URL(fileURLWithPath: "/tmp/test"),
        onComplete: {}
    )
}
