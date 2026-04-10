//
//  ContentView.swift
//  Typewriter
//
//  Created by mac on 10/4/26.
//

import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

// Represent each typewriter document
struct TypewriterDocument: Identifiable, Hashable, Codable {
    let id: UUID
    var attributedText: AttributedStringCodable
    var fileURL: URL?
    
    init(id: UUID = UUID(), attributedText: AttributedString, fileURL: URL? = nil) {
        self.id = id
        self.attributedText = AttributedStringCodable(attributedString: attributedText)
        self.fileURL = fileURL
    }
    
    var attributedString: AttributedString {
        attributedText.attributedString
    }
    
    mutating func setAttributedString(_ newValue: AttributedString) {
        attributedText = AttributedStringCodable(attributedString: newValue)
    }
}

// Codable wrapper for AttributedString via String
struct AttributedStringCodable: Codable, Hashable {
    var storage: String
    
    var attributedString: AttributedString {
        (try? AttributedString(storage)) ?? AttributedString(storage)
    }
    
    init(attributedString: AttributedString) {
        storage = String(attributedString.characters)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        storage = try container.decode(String.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(storage)
    }
}

struct ContentView: View {
    @State private var documents: [TypewriterDocument] = [
        TypewriterDocument(attributedText: AttributedString(""), fileURL: nil)
    ]
    @State private var selectedTab: TypewriterDocument.ID = UUID()
    @State private var errorMessage: String? = nil
    @State private var audioPlayer: AVAudioPlayer? = nil
    
    // New state for sound toggle
    @State private var soundOn: Bool = true
    @State private var clickVolume: Double = 0.5  // kept but will not be used after volume slider removal
    
    // Helper to locate the currently selected document index
    private var currentIndex: Int? {
        documents.firstIndex { $0.id == selectedTab }
    }
    
    var body: some View {
        ZStack {
            // Vintage warm background
            LinearGradient(
                colors: [Color(red:0.93, green:0.89, blue:0.80), Color(red:0.85, green:0.74, blue:0.58)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar with + button and sound toggle button
                HStack {
                    // New Tab Button
                    Button("+") { newTab() }
                        .font(.title2.bold())
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                        .foregroundStyle(Color(red: 0.58, green: 0.36, blue: 0.20))
                    
                    Spacer()
                    
                    // Sound toggle button top-right
                    Button {
                        soundOn.toggle()
                    } label: {
                        Image(systemName: soundOn ? "speaker.wave.3.fill" : "speaker.slash.fill")
                            .font(.title3)
                            .foregroundStyle(Color(red: 0.58, green: 0.36, blue: 0.20))
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 16)
                }
                .padding(.top, 14)
                .padding(.bottom, 8)

                // Custom tab bar with tabs as buttons
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(documents) { doc in
                            Button(action: { selectedTab = doc.id }) {
                                HStack(spacing: 6) {
                                    Text(doc.fileURL?.lastPathComponent.isEmpty == false ? doc.fileURL!.lastPathComponent : "Untitled")
                                        .lineLimit(1)
                                        .foregroundColor(selectedTab == doc.id ? Color.white : Color(red: 0.58, green: 0.36, blue: 0.20))
                                        .font(.system(size: 15, weight: selectedTab == doc.id ? .semibold : .regular, design: .monospaced))
                                    if documents.count > 1 {
                                        Button(action: { closeTab(doc.id) }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(selectedTab == doc.id ? Color.white.opacity(0.85) : Color(red: 0.58, green: 0.36, blue: 0.20).opacity(0.7))
                                                .padding(.leading, 2)
                                        }
                                        .buttonStyle(.plain)
                                        .contentShape(Rectangle())
                                    }
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(selectedTab == doc.id ? Color(red: 0.58, green: 0.36, blue: 0.20) : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 28)
                }
                .padding(.bottom, 10)

                // Place formatting toolbar above the paper area (outside the ZStack)
                if let idx = currentIndex {
                    formattingToolbar(for: Binding(get: {
                        documents[idx].attributedString
                    }, set: { newValue in
                        documents[idx].setAttributedString(newValue)
                    }))
                    .padding(.horizontal, 32)
                    .padding(.bottom, 4)
                }

                // Editor area with paper-like background and buttons
                if let idx = currentIndex {
                    VStack(spacing: 0) {
                        Spacer()
                        ZStack(alignment: .top) {
                            // Paper-like area
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(red: 1.0, green: 0.98, blue: 0.92))
                                .shadow(color: Color.black.opacity(0.10), radius: 12, y: 6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color(red: 0.80, green: 0.68, blue: 0.54), lineWidth: 1.3)
                                )
                                .padding(.top, 30)

                            VStack {
                                HStack(spacing: 20) {
                                    Button(action: { openDocument(for: documents[idx].id) }) {
                                        Label("Open", systemImage: "folder")
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 22)
                                    }
                                    .background(.ultraThinMaterial)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color(red: 0.80, green: 0.68, blue: 0.54), lineWidth: 1.1))

                                    Button(action: { Task { await saveDocument(for: documents[idx].id) } }) {
                                        Label("Save", systemImage: "square.and.arrow.down")
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 22)
                                    }
                                    .background(.ultraThinMaterial)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color(red: 0.80, green: 0.68, blue: 0.54), lineWidth: 1.1))
                                    
                                    Spacer()
                                    
                                    // Close tab button aligned top-right with floating buttons
                                    if documents.count > 1 {
                                        Button(role: .destructive) {
                                            closeTab(documents[idx].id)
                                        } label: {
                                            Image(systemName: "xmark.circle")
                                                .font(.system(size: 18, weight: .bold))
                                        }
                                        .help("Close Tab")
                                        .foregroundStyle(Color(red: 0.70, green: 0.38, blue: 0.22))
                                    }
                                }
                                .padding(.top, 10)
                                .padding(.horizontal, 16)

                                if let fileURL = documents[idx].fileURL {
                                    Text(fileURL.lastPathComponent)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .padding(.bottom, 4)
                                }
                            }
                            .zIndex(1)

                            // Editor
                            if #available(macOS 14.0, *) {
                                TextEditor(text: Binding(get: {
                                    String(documents[idx].attributedString.characters)
                                }, set: { newValue in
                                    var newAttr = AttributedString(newValue)
                                    // Preserve formatting by replacing text only, preserve existing attributes if possible
                                    // But here we replace completely with plain string
                                    documents[idx].setAttributedString(newAttr)
                                }))
                                .font(.custom("Menlo", size: 19).monospaced())
                                .foregroundColor(Color(red:0.33, green:0.24, blue:0.16))
                                .scrollContentBackground(.hidden)
                                .padding(.top, 68)
                                .padding([.horizontal, .bottom], 30)
                                .frame(maxWidth: .infinity, maxHeight: 360)
                                .onChange(of: documents[idx].attributedString) { _ in playClick() }
                            } else {
                                TextEditor(text: .constant(String(documents[idx].attributedString.characters)))
                                    .disabled(true)
                                    .padding(.top, 68)
                                    .padding([.horizontal, .bottom], 30)
                                    .frame(maxWidth: .infinity, maxHeight: 360)
                            }
                        }
                        .frame(maxWidth: 720)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 26)
                        Spacer()
                    }
                    .tag(documents[idx].id)
                } else {
                    Spacer()
                }
            }
            .frame(minWidth: 900, minHeight: 650)
            .onAppear {
                loadAutoSavedDocuments()
                selectedTab = documents.first?.id ?? UUID()
            }
            .onChange(of: documents) { _ in
                autoSaveAllDocuments()
            }
        }
        // Alert for errors
        .alert("Error", isPresented: Binding<Bool>(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            if let errorMessage = errorMessage { Text(errorMessage) }
        }
    }

    // Formatting toolbar for AttributedString
    // Moved above paper area for visual separation
    @ViewBuilder
    func formattingToolbar(for attributedText: Binding<AttributedString>) -> some View {
        HStack(spacing: 18) {
            Button("B") { toggleTrait(for: attributedText, trait: .bold) }
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
            Button("I") { toggleTrait(for: attributedText, trait: .italic) }
                .font(.system(size: 18, weight: .regular, design: .monospaced)).italic()
                .foregroundStyle(.primary)
            Button("U") { toggleTrait(for: attributedText, trait: .underline) }
                .font(.system(size: 18, weight: .regular, design: .monospaced)).underline()
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 4)
    }

    // MARK: - Tab and Document Management
    func newTab() {
        let newDoc = TypewriterDocument(attributedText: AttributedString(""), fileURL: nil)
        documents.append(newDoc)
        selectedTab = newDoc.id
    }
    func closeTab(_ id: UUID) {
        // Keep at least one tab open
        if documents.count > 1, let idx = documents.firstIndex(where: { $0.id == id }) {
            documents.remove(at: idx)
            selectedTab = documents.last?.id ?? UUID()
        }
    }

    // MARK: - Text Formatting (Apply to whole doc)
    enum TextTrait { case bold, italic, underline }
    func toggleTrait(for text: Binding<AttributedString>, trait: TextTrait) {
        var t = text.wrappedValue
        let fullRange = t.startIndex..<t.endIndex

        switch trait {
        case .bold:
            // Toggle bold: if bold, remove; otherwise, apply
            if t[fullRange].font == .system(size: 19, weight: .bold, design: .monospaced) {
                t[fullRange].font = .system(size: 19, design: .monospaced)
            } else {
                t[fullRange].font = .system(size: 19, weight: .bold, design: .monospaced)
            }
        case .italic:
            // Toggle italic: if italic, remove; otherwise, apply
            if t[fullRange].font == .system(size: 19, design: .monospaced).italic() {
                t[fullRange].font = .system(size: 19, design: .monospaced)
            } else {
                t[fullRange].font = .system(size: 19, design: .monospaced).italic()
            }
        case .underline:
            // Toggle underline
            let isUnderlined = t[fullRange].underlineStyle == .single
            t[fullRange].underlineStyle = isUnderlined ? nil : .single
        }
        text.wrappedValue = t
    }

    // MARK: - File Operations per Tab
    func openDocument(for id: UUID) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let contents = try String(contentsOf: url, encoding: .utf8)
                    let attributed = AttributedString(contents)
                    DispatchQueue.main.async {
                        if let idx = documents.firstIndex(where: { $0.id == id }) {
                            documents[idx].setAttributedString(attributed)
                            documents[idx].fileURL = url
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.errorMessage = "Could not open file: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    // Updated async saveDocument method with modern NSSavePanel API
    func saveDocument(for id: UUID) async {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true
        
        guard let idx = documents.firstIndex(where: { $0.id == id }), idx < documents.count else {
            return // fallback safe exit if index not found or out of bounds
        }
        
        let doc = documents[idx]
        let defaultName: String = {
            if let url = doc.fileURL, !url.lastPathComponent.isEmpty {
                return url.deletingPathExtension().lastPathComponent + ".txt"
            } else {
                return "Untitled.txt"
            }
        }()
        panel.nameFieldStringValue = defaultName
        
        await MainActor.run {
            panel.begin { response in
                if response == .OK, var url = panel.url {
                    // Ensure .txt extension
                    if url.pathExtension.lowercased() != "txt" {
                        if url.pathExtension.isEmpty {
                            url.appendPathExtension("txt")
                        } else {
                            url.deletePathExtension()
                            url.appendPathExtension("txt")
                        }
                    }
                    DispatchQueue.global(qos: .userInitiated).async {
                        do {
                            let text = String(documents[idx].attributedString.characters)
                            try text.write(to: url, atomically: true, encoding: .utf8)
                            DispatchQueue.main.async {
                                documents[idx].fileURL = url
                            }
                        } catch {
                            DispatchQueue.main.async {
                                errorMessage = "Could not save file: \(error.localizedDescription)"
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Autosave Helpers
    
    private func appSupportDirectory() -> URL? {
        let fm = FileManager.default
        do {
            let appSupport = try fm.url(for: .applicationSupportDirectory,
                                        in: .userDomainMask,
                                        appropriateFor: nil,
                                        create: true)
            let bundleID = Bundle.main.bundleIdentifier ?? "Typewriter"
            let appDir = appSupport.appendingPathComponent(bundleID, isDirectory: true)
            if !fm.fileExists(atPath: appDir.path) {
                try fm.createDirectory(at: appDir, withIntermediateDirectories: true, attributes: nil)
            }
            return appDir
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to access Application Support directory: \(error.localizedDescription)"
            }
            return nil
        }
    }
    
    func autoSaveAllDocuments() {
        guard let dir = appSupportDirectory() else { return }
        let fileURL = dir.appendingPathComponent("autosave.json")
        let docsToSave = documents.map { doc -> TypewriterDocument in
            // Strip fileURL to nil for autosave to avoid overwriting user file locations
            TypewriterDocument(id: doc.id, attributedText: doc.attributedString, fileURL: nil)
        }
        DispatchQueue.global(qos: .background).async {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(docsToSave)
                try data.write(to: fileURL, options: [.atomic])
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Auto-save failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func loadAutoSavedDocuments() {
        guard let dir = appSupportDirectory() else { return }
        let fileURL = dir.appendingPathComponent("autosave.json")
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let data = try Data(contentsOf: fileURL)
                let decoder = JSONDecoder()
                let loadedDocs = try decoder.decode([TypewriterDocument].self, from: data)
                if loadedDocs.isEmpty {
                    return
                }
                DispatchQueue.main.async {
                    self.documents = loadedDocs
                    // Select first document or preserve selectedTab if possible
                    if let first = loadedDocs.first {
                        self.selectedTab = first.id
                    }
                }
            } catch {
                // If file doesn't exist or can't be decoded, silently ignore
            }
        }
    }

    // MARK: - Sound
    func playClick() {
        guard soundOn else { return }
        // Always create a new player for current selected sound
        audioPlayer = nil
        if let url = Bundle.main.url(forResource: "typewriter", withExtension: "wav") {
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.volume = Float(clickVolume)
                player.prepareToPlay()
                player.play()
                audioPlayer = player
            } catch {
                NSSound.beep()
            }
        } else {
            NSSound.beep()
        }
    }
}

#Preview {
    ContentView()
}

