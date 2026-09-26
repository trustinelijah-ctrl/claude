import SwiftData
import SwiftUI

/// Home: a full-bleed camera with three modes — Barcode, Label and Grocery.
struct ScannerScreen: View {
    @Environment(AppServices.self) private var services
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss

    enum Status: Equatable {
        case idle
        case searching(String)
        case reading
        case notFound(String)
        case error(String)
    }

    @State private var mode: ScanMode
    @State private var scanner = ScannerController()
    @State private var status: Status = .idle
    @State private var result: AnalysisModel?
    @State private var basket = GroceryBasket()
    @State private var ranking: [ScoredProduct]?
    @State private var labelShots: [UIImage] = []
    @State private var pendingBarcode: String?
    @State private var showManual = false
    @State private var torchOn = false
    @State private var lockPulse = 0
    @State private var lastCode: String?
    @State private var lastCodeAt: Date = .distantPast

    init(initialMode: ScanMode = .barcode) {
        _mode = State(initialValue: initialMode)
    }

    private var scanningActive: Bool {
        scenePhase == .active && result == nil && ranking == nil && !showManual
            && status != .reading && !isSearching
    }

    private var isSearching: Bool {
        if case .searching = status { return true }
        return false
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if ScannerController.isAvailable {
                BarcodeScannerView(isActive: scanningActive, controller: scanner, onBarcodes: handle)
                    .ignoresSafeArea()
            } else {
                CameraUnavailableBackdrop()
            }

            ViewfinderOverlay(mode: mode, pulse: lockPulse, busy: isSearching || status == .reading)

            VStack(spacing: 0) {
                topBar
                Spacer()
                statusArea
                    .padding(.bottom, 18)
                bottomControls
                    .padding(.bottom, 16)
                ScanModePicker(mode: $mode)
                    .padding(.bottom, 8)
            }
        }
        .onChange(of: mode) { _, newMode in
            status = .idle
            if newMode != .label { labelShots.removeAll() }
        }
        .onChange(of: torchOn) { _, on in scanner.setTorch(on) }
        .sheet(item: $result, onDismiss: { lastCodeAt = .now }) { model in
            ProductResultView(model: model)
                .presentationCornerRadius(38)
        }
        .sheet(isPresented: $showManual) {
            ManualEntrySheet { code in
                showManual = false
                Task { await open(barcode: code) }
            }
            .presentationDetents([.height(340)])
            .presentationCornerRadius(30)
        }
        .sheet(item: Binding(get: { ranking.map(RankingPayload.init) }, set: { ranking = $0?.items })) { payload in
            GroceryRankingView(ranked: payload.items) { basket.clear() }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            GlassIconButton(systemName: "xmark") { dismiss() }
                .accessibilityLabel("Close")
            Spacer()
            VStack(spacing: 2) {
                Text("Human Food")
                    .font(.system(size: 19, weight: .bold))
                    .tracking(-0.5)
                    .foregroundStyle(.white)
                if services.streak.days > 1 {
                    Label("\(services.streak.days)-day streak", systemImage: "flame.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            Spacer()
            GlassIconButton(systemName: "keyboard") { showManual = true }
                .accessibilityLabel("Type a barcode")
        }
        .padding(.horizontal, HF.Space.gutter)
        .padding(.top, 6)
    }

    // MARK: - Status

    @ViewBuilder
    private var statusArea: some View {
        switch status {
        case .idle:
            Text(labelHint)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .contentTransition(.opacity)
                .animation(HF.Motion.soft, value: mode)
        case .searching(let code):
            StatusPill(text: "Looking up \(code)", spinning: true)
        case .reading:
            StatusPill(text: "Reading the label…", spinning: true)
        case .notFound(let code):
            NotFoundCard(barcode: code,
                         canReadLabels: services.config.hasAI,
                         onSnapLabel: {
                             pendingBarcode = code
                             withAnimation(HF.Motion.snappy) { mode = .label }
                         },
                         onDismiss: { withAnimation(HF.Motion.soft) { status = .idle } })
            .padding(.horizontal, HF.Space.gutter)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        case .error(let message):
            StatusPill(text: message, spinning: false)
                .onTapGesture { status = .idle }
        }
    }

    private var labelHint: String {
        if mode == .label {
            switch labelShots.count {
            case 0: return pendingBarcode == nil ? "Photograph the ingredients list" : "Snap the ingredients to add this product"
            case 1: return "Add the nutrition table (optional)"
            default: return "Add the front of the pack (optional)"
            }
        }
        return mode.hint
    }

    // MARK: - Bottom controls

    @ViewBuilder
    private var bottomControls: some View {
        switch mode {
        case .barcode:
            GlassIconButton(systemName: torchOn ? "flashlight.on.fill" : "flashlight.off.fill") { torchOn.toggle() }
                .accessibilityLabel("Torch")
        case .label:
            labelControls
        case .grocery:
            GroceryTray(basket: basket,
                        onRank: {
                            Haptics.success()
                            ranking = basket.ranked
                        },
                        onClear: {
                            Haptics.tap()
                            withAnimation(HF.Motion.soft) { basket.clear() }
                        })
        }
    }

    private var labelControls: some View {
        HStack(alignment: .center) {
            HStack(spacing: -14) {
                ForEach(Array(labelShots.enumerated()), id: \.offset) { index, image in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.white, lineWidth: 2))
                        .rotationEffect(.degrees(Double(index) * 6 - 6))
                }
            }
            .frame(width: 90, alignment: .leading)

            Spacer()

            Button(action: captureLabel) {
                ZStack {
                    Circle().strokeBorder(.white, lineWidth: 4).frame(width: 78, height: 78)
                    Circle().fill(.white).frame(width: 64, height: 64)
                }
            }
            .buttonStyle(PressableStyle(scale: 0.9))
            .disabled(labelShots.count >= 3 || status == .reading)
            .accessibilityLabel("Take photo")

            Spacer()

            Button {
                Task { await analyseLabel() }
            } label: {
                Text("Analyse")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18)
                    .frame(height: 44)
                    .background(.white, in: Capsule())
            }
            .buttonStyle(PressableStyle())
            .opacity(labelShots.isEmpty ? 0 : 1)
            .disabled(labelShots.isEmpty || status == .reading)
            .frame(width: 90, alignment: .trailing)
        }
        .padding(.horizontal, HF.Space.gutter + 8)
        .animation(HF.Motion.bouncy, value: labelShots.count)
    }

    // MARK: - Actions

    private func handle(_ codes: [String]) {
        let normalised = codes.compactMap(AppServices.normalise(barcode:))
        switch mode {
        case .barcode:
            guard status == .idle, result == nil, let code = normalised.first else { return }
            if code == lastCode, Date.now.timeIntervalSince(lastCodeAt) < 4 { return }
            Task { await open(barcode: code) }
        case .grocery:
            for code in normalised where basket.add(code, services: services, context: context) {
                lockPulse += 1
                Haptics.lock()
            }
        case .label:
            break
        }
    }

    private func open(barcode code: String) async {
        lastCode = code
        lastCodeAt = .now
        lockPulse += 1
        Haptics.lock()
        withAnimation(HF.Motion.soft) { status = .searching(code) }

        switch await services.lookup(barcode: code, context: context) {
        case .found(let product, _):
            present(product)
        case .notFound:
            Haptics.warning()
            withAnimation(HF.Motion.bouncy) { status = .notFound(code) }
        case .failed:
            Haptics.warning()
            withAnimation(HF.Motion.soft) { status = .error("Couldn't reach the food database. Tap to retry.") }
        }
    }

    private func present(_ product: Product) {
        let score = services.score(product)
        let isRevisit = AppServices.record(for: product.barcode, in: context) != nil
        let record = services.remember(product, score: score, context: context)
        status = .idle
        result = AnalysisModel(product: product, score: score, verdict: record.cachedVerdict, isRevisit: isRevisit)
    }

    private func captureLabel() {
        Task {
            do {
                let image = try await scanner.capturePhoto()
                Haptics.lock()
                withAnimation(HF.Motion.bouncy) { labelShots.append(image) }
            } catch {
                Haptics.warning()
            }
        }
    }

    private func analyseLabel() async {
        guard !labelShots.isEmpty else { return }
        let payloads = labelShots.compactMap { $0.preparedForUpload() }
        withAnimation(HF.Motion.soft) { status = .reading }
        do {
            let product = try await services.verdicts.readLabel(images: payloads, barcode: pendingBarcode)
            labelShots.removeAll()
            pendingBarcode = nil
            mode = .barcode
            present(product)
        } catch {
            Haptics.warning()
            status = .error((error as? LocalizedError)?.errorDescription ?? "We couldn't read that label.")
        }
    }
}

private struct RankingPayload: Identifiable {
    let items: [ScoredProduct]
    var id: String { items.map(\.id).joined() }
}

// MARK: - Small pieces

private struct StatusPill: View {
    var text: String
    var spinning: Bool

    var body: some View {
        HStack(spacing: 10) {
            if spinning { ProgressView().tint(.white) }
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .environment(\.colorScheme, .dark)
        .padding(.horizontal, HF.Space.gutter)
    }
}

private struct NotFoundCard: View {
    var barcode: String
    var canReadLabels: Bool
    var onSnapLabel: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("New to us").eyebrow()
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .bold))
                        .foregroundStyle(HF.Palette.inkSecondary)
                }
            }
            Text("This product isn't in the database yet.")
                .hfDisplay(20)
                .foregroundStyle(HF.Palette.ink)
            Text(canReadLabels
                 ? "Photograph the label and we'll add it for everyone who scans it next."
                 : "Barcode \(barcode). You can add it to Open Food Facts to help everyone.")
                .font(HF.Font.callout)
                .foregroundStyle(HF.Palette.inkSecondary)
            if canReadLabels {
                Button("Snap the label", action: onSnapLabel)
                    .buttonStyle(PrimaryButtonStyle())
            } else {
                Link("Open Food Facts", destination: URL(string: "https://world.openfoodfacts.org/cgi/product.pl?code=\(barcode)")!)
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(20)
        .background(HF.Palette.surface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

struct ManualEntrySheet: View {
    var onSubmit: (String) -> Void
    @State private var code = ""
    @FocusState private var focused: Bool

    private var valid: String? { AppServices.normalise(barcode: code) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Type a barcode").hfDisplay(26)
            TextField("e.g. 3017620422003", text: $code)
                .keyboardType(.numberPad)
                .font(.system(size: 22, weight: .medium, design: .monospaced))
                .padding(16)
                .background(HF.Palette.surfaceRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .focused($focused)
            #if DEBUG
            HStack(spacing: 8) {
                ForEach(["3017620422003", "5449000000996"], id: \.self) { sample in
                    Button(sample.suffix(6).description) { code = sample }
                        .font(HF.Font.caption)
                        .buttonStyle(.bordered)
                }
            }
            #endif
            Button("Look up") {
                if let valid { onSubmit(valid) }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(valid == nil)
            .opacity(valid == nil ? 0.5 : 1)
        }
        .padding(HF.Space.l)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(HF.Palette.canvas.ignoresSafeArea())
        .onAppear { focused = true }
    }
}

private extension UIImage {
    /// Downscales to at most 1400 px and JPEG-encodes — plenty for label OCR, cheap to upload.
    func preparedForUpload(maxDimension: CGFloat = 1400) -> Data? {
        let longest = max(size.width, size.height)
        let scale = min(1, maxDimension / longest)
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: 0.7)
    }
}
