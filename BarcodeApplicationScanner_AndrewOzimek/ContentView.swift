//This is the User Interface. It displays the "Scan Item" button and handles the logic for showing the scanner sheet.


import SwiftUI
struct ContentView: View {
    @State private var resultText = "Scan a product to begin"
    @State private var showingScanner = false
    @State private var selectedItem: ScannedItem? = nil
    @State private var showingDetails = false

    var body: some View {
        VStack(spacing: 30) {
            Text(resultText)
                .font(.title2)
                .padding()
                .multilineTextAlignment(.center)

            Button(action: { showingScanner = true }) {
                Label("Scan Item", systemImage: "barcode.viewfinder")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .sheet(isPresented: $showingScanner) {
            ZStack {
#if os(iOS)
    if #available(iOS 16.0, *) {
        #if targetEnvironment(simulator)
        // Use fallback in Simulator (VisionKit not available)
        DataScannerView(scannedCode: $resultText)
        #else
        // Use the real scanner on device
        LegacyDataScannerView(scannedCode: $resultText)
        #endif
    } else {
        // Fallback UI for older iOS versions
        DataScannerView(scannedCode: $resultText)
    }
#else
    // Non-iOS platforms
    DataScannerView(scannedCode: $resultText)
#endif
                // Viewfinder overlay
                viewfinderOverlay
            }
            .onAppear {
                // Reset the last result so onChange fires for the next scan
                resultText = "Scan a product to begin"
            }
        }
        .onChange(of: resultText) { old, newValue in
            // Ignore the initial placeholder
            guard newValue != "Scan a product to begin" else { return }
            // Build a richer model from the scanned string
            let item = ScannedItem.from(scanned: newValue)
            selectedItem = item
            showingDetails = true
            // Optionally dismiss the scanner when we have a value
            showingScanner = false
        }
        .sheet(isPresented: $showingDetails) {
            if let item = selectedItem {
                ScannedDetailsView(item: item)
            }
        }
    }
    
    private var viewfinderOverlay: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height) * 0.65
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 3, dash: [8, 8]))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 2)
                .blendMode(.overlay)
                .position(x: geo.size.width/2, y: geo.size.height/2)
                .accessibilityHidden(true)
        }
        .allowsHitTesting(false)
    }
}
// Lightweight model describing what was scanned
struct ScannedItem: Identifiable {
    let id = UUID()
    let raw: String
    let kind: Kind
    let title: String
    let subtitle: String?
    let actionableURL: URL?

    // Open Food Facts fields (if available)
    var offProduct: OFFProduct? = nil

    enum Kind: String {
        case url = "URL"
        case upc = "UPC/EAN"
        case qr = "QR Code"
        case text = "Text"
    }

    static func from(scanned: String) -> ScannedItem {
        // URL detection
        if let url = URL(string: scanned), url.scheme != nil {
            return ScannedItem(
                raw: scanned,
                kind: .url,
                title: url.host ?? "Link",
                subtitle: url.absoluteString,
                actionableURL: url,
                offProduct: nil
            )
        }
        // Numeric-only barcode heuristic (UPC/EAN)
        let digitsOnly = scanned.trimmingCharacters(in: .whitespacesAndNewlines)
        let isNumeric = !digitsOnly.isEmpty && digitsOnly.allSatisfy({ $0.isNumber })
        if isNumeric {
            let query = digitsOnly.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? digitsOnly
            let url = URL(string: "https://www.google.com/search?q=UPC+" + query)
            return ScannedItem(
                raw: scanned,
                kind: .upc,
                title: "Barcode: \(digitsOnly)",
                subtitle: "Tap to look up product details",
                actionableURL: url,
                offProduct: nil
            )
        }
        // Basic QR vs Text classification
        let kind: Kind = scanned.count > 20 ? .qr : .text
        return ScannedItem(
            raw: scanned,
            kind: kind,
            title: scanned,
            subtitle: nil,
            actionableURL: nil,
            offProduct: nil
        )
    }
}

// MARK: - Open Food Facts minimal models & client
nonisolated struct OFFResponse: Decodable {
    let status: Int?
    let product: OFFProduct?
}

nonisolated struct OFFProduct: Decodable {
    let code: String?
    let productName: String?
    let brands: String?
    let nutriments: OFFNutriments?

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case brands
        case nutriments
    }
}

nonisolated struct OFFNutriments: Decodable {
    let energyKcal100g: Double?
    let fat100g: Double?
    let saturatedFat100g: Double?
    let carbohydrates100g: Double?
    let sugars100g: Double?
    let fiber100g: Double?
    let proteins100g: Double?
    let salt100g: Double?
    let sodium100g: Double?

    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case fat100g = "fat_100g"
        case saturatedFat100g = "saturated-fat_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case sugars100g = "sugars_100g"
        case fiber100g = "fiber_100g"
        case proteins100g = "proteins_100g"
        case salt100g = "salt_100g"
        case sodium100g = "sodium_100g"
    }
}

actor OpenFoodFactsClient {
    func fetchProduct(for barcode: String) async throws -> OFFProduct? {
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("BarcodeScannerApp/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        let res = try decoder.decode(OFFResponse.self, from: data)
        return res.product
    }
}

// A simple details sheet presenting richer info and actions
struct ScannedDetailsView: View {
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    let item: ScannedItem
    @Environment(\.openURL) private var openURL
    private let client = OpenFoodFactsClient()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.body)
                            .textSelection(.enabled)
                    }

                    if isLoading {
                        ProgressView("Fetching nutrition facts…")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let message = errorMessage {
                        Text(message)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }

                    if let product = item.offProduct ?? cachedProduct {
                        nutritionSection(for: product)
                    }
                    
                    if item.kind == .upc {
                        priceEstimatesSection()
                    }
                    
                    if item.kind == .upc || item.kind == .qr || item.kind == .text {
                        whereToBuySection()
                    }

                    if let url = item.actionableURL {
                        Button {
                            openURL(url)
                        } label: {
                            Label("Open in Browser", systemImage: "safari")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    GroupBox("Raw Value") {
                        Text(item.raw)
                            .font(.footnote)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            .navigationTitle("Scan Details")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await maybeFetchOFF()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName(for: item.kind))
                .font(.largeTitle)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 4) {
                Text(displayTitle)
                    .font(.title2)
                    .bold()
                Text(item.kind.rawValue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var displayTitle: String {
        if let product = item.offProduct ?? cachedProduct, let name = product.productName, !name.isEmpty {
            if let brand = product.brands, !brand.isEmpty {
                return "\(name) — \(brand)"
            }
            return name
        }
        return item.title
    }

    private func maybeFetchOFF() async {
        guard item.kind == .upc else { return }
        // Extract digits from the barcode
        let barcode = item.raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !barcode.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        do {
            if let product = try await client.fetchProduct(for: barcode) {
                // Cache the product for display
                self.cachedProduct = product
            } else {
                errorMessage = "No product found for this barcode."
            }
        } catch {
            errorMessage = "Failed to fetch product info. Please try again."
        }
        isLoading = false
    }

    // Local cache state for the fetched product
    @State private var cachedProduct: OFFProduct? = nil

    private func nutritionSection(for product: OFFProduct) -> some View {
        GroupBox("Nutrition Facts (per 100g)") {
            VStack(alignment: .leading, spacing: 8) {
                if let name = product.productName, !name.isEmpty {
                    Text(name).bold()
                }
                if let brand = product.brands, !brand.isEmpty {
                    Text("Brand: \(brand)")
                }
                if let n = product.nutriments {
                    nutrientRow(label: "Energy", value: n.energyKcal100g, unit: "kcal")
                    nutrientRow(label: "Fat", value: n.fat100g, unit: "g")
                    nutrientRow(label: "Saturated Fat", value: n.saturatedFat100g, unit: "g")
                    nutrientRow(label: "Carbohydrates", value: n.carbohydrates100g, unit: "g")
                    nutrientRow(label: "Sugars", value: n.sugars100g, unit: "g")
                    nutrientRow(label: "Fiber", value: n.fiber100g, unit: "g")
                    nutrientRow(label: "Protein", value: n.proteins100g, unit: "g")
                    // Prefer salt if available, otherwise show sodium (converted to salt ~ *2.5) or raw sodium
                    if let salt = n.salt100g {
                        nutrientRow(label: "Salt", value: salt, unit: "g")
                    } else if let sodium = n.sodium100g {
                        nutrientRow(label: "Sodium", value: sodium, unit: "g")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            // No additional action needed here, cachedProduct drives display
        }
    }
    
    // MARK: - Price estimates (demo wiring)
    struct PriceOffer: Identifiable {
        let id = UUID()
        let retailer: String
        let price: String
        let url: URL?
    }

    @State private var priceOffers: [PriceOffer] = []
    @State private var isLoadingPrices = false

    @ViewBuilder
    private func priceEstimatesSection() -> some View {
        GroupBox("Price Estimates") {
            VStack(alignment: .leading, spacing: 8) {
                if isLoadingPrices {
                    ProgressView("Fetching prices…")
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if priceOffers.isEmpty {
                    Text("No prices available right now.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(priceOffers) { offer in
                        if let url = offer.url {
                            Link(destination: url) {
                                HStack {
                                    Text(offer.retailer)
                                    Spacer()
                                    Text(offer.price)
                                        .bold()
                                }
                            }
                        } else {
                            HStack {
                                Text(offer.retailer)
                                Spacer()
                                Text(offer.price)
                                    .bold()
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .task {
                await loadPriceOffersIfNeeded()
            }
        }
    }

    private func loadPriceOffersIfNeeded() async {
        guard priceOffers.isEmpty, !isLoadingPrices, item.kind == .upc else { return }
        isLoadingPrices = true
        defer { isLoadingPrices = false }
        // Demo: synthesize a couple of example offers based on the barcode.
        // Replace this with a real API lookup (e.g., retailer APIs) in production.
        let barcode = item.raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let encoded = barcode.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? barcode
        let google = URL(string: "https://www.google.com/search?tbm=shop&q=UPC+" + encoded)
        let amazon = URL(string: "https://www.amazon.com/s?k=" + encoded)
        // Create a couple of example offers
        await MainActor.run {
            self.priceOffers = [
                PriceOffer(retailer: "Google Shopping", price: "Tap to view", url: google),
                PriceOffer(retailer: "Amazon", price: "Tap to view", url: amazon)
            ]
        }
    }
    
    @ViewBuilder
    private func whereToBuySection() -> some View {
        GroupBox("Where to Buy") {
            VStack(alignment: .leading, spacing: 8) {
                if let google = whereToBuyGoogleURL() {
                    Link(destination: google) {
                        Label("Search on Google Shopping", systemImage: "cart")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if let amazon = whereToBuyAmazonURL() {
                    Link(destination: amazon) {
                        Label("Search on Amazon", systemImage: "shippingbox")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func whereToBuyGoogleURL() -> URL? {
        switch item.kind {
        case .upc:
            let q = item.raw.trimmingCharacters(in: .whitespacesAndNewlines)
            let encoded = ("UPC " + q).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q
            return URL(string: "https://www.google.com/search?tbm=shop&q=" + encoded)
        case .qr, .text:
            let q = item.title
            let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q
            return URL(string: "https://www.google.com/search?tbm=shop&q=" + encoded)
        case .url:
            return nil
        }
    }

    private func whereToBuyAmazonURL() -> URL? {
        switch item.kind {
        case .upc:
            let q = item.raw.trimmingCharacters(in: .whitespacesAndNewlines)
            let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q
            return URL(string: "https://www.amazon.com/s?k=" + encoded)
        case .qr, .text:
            let q = item.title
            let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q
            return URL(string: "https://www.amazon.com/s?k=" + encoded)
        case .url:
            return nil
        }
    }

    private func nutrientRow(label: String, value: Double?, unit: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value.map { String(format: "%.1f %@", $0, unit) } ?? "–")
                .foregroundStyle(.secondary)
        }
    }

    private func iconName(for kind: ScannedItem.Kind) -> String {
        switch kind {
        case .url: return "link"
        case .upc: return "barcode"
        case .qr: return "qrcode"
        case .text: return "doc.text"
        }
    }
}

