import SwiftUI

// View for displaying scan history from the database
struct ScanHistoryView: View {
    @State private var savedItems: [SavedScannedItem] = []
    @State private var selectedItem: SavedScannedItem? = nil
    @State private var showingDetails = false
    @State private var searchText = ""
    @State private var showingFavoritesOnly = false
    
    var filteredItems: [SavedScannedItem] {
        var items = savedItems
        
        // Filter by favorites if toggled
        if showingFavoritesOnly {
            items = items.filter { $0.isFavorite }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            items = items.filter { item in
                item.title.localizedCaseInsensitiveContains(searchText) ||
                item.rawValue.localizedCaseInsensitiveContains(searchText) ||
                (item.productName?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (item.brand?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        return items
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if savedItems.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(filteredItems) { item in
                            HistoryItemRow(item: item)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedItem = item
                                    showingDetails = true
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteItem(item)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        toggleFavorite(item)
                                    } label: {
                                        Label(
                                            item.isFavorite ? "Unfavorite" : "Favorite",
                                            systemImage: item.isFavorite ? "star.slash.fill" : "star.fill"
                                        )
                                    }
                                    .tint(item.isFavorite ? .gray : .yellow)
                                }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search scans")
                }
            }
            .navigationTitle("Scan History")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingFavoritesOnly.toggle()
                    } label: {
                        Image(systemName: showingFavoritesOnly ? "star.fill" : "star")
                            .foregroundStyle(showingFavoritesOnly ? .yellow : .gray)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        loadItems()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                loadItems()
            }
            .sheet(isPresented: $showingDetails) {
                if let item = selectedItem {
                    ScannedDetailsView(item: item.toScannedItem())
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundStyle(.gray)
            
            Text("No Scans Yet")
                .font(.title2)
                .bold()
            
            Text("Scan items to see them appear here")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func loadItems() {
        savedItems = DatabaseManager.shared.getAllScannedItems()
    }
    
    private func deleteItem(_ item: SavedScannedItem) {
        withAnimation {
            if DatabaseManager.shared.deleteItem(id: item.id) {
                savedItems.removeAll { $0.id == item.id }
            }
        }
    }
    
    private func toggleFavorite(_ item: SavedScannedItem) {
        if DatabaseManager.shared.toggleFavorite(id: item.id) {
            loadItems()
        }
    }
}

// Row view for each history item
struct HistoryItemRow: View {
    let item: SavedScannedItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon based on item kind
            Image(systemName: iconName)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(displayTitle)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if item.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                }
                
                if let subtitle = displaySubtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Text(formatDate(item.timestamp))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
    
    private var iconName: String {
        switch item.kind {
        case .url: return "link"
        case .upc: return "barcode"
        case .qr: return "qrcode"
        case .text: return "doc.text"
        }
    }
    
    private var displayTitle: String {
        if let productName = item.productName, !productName.isEmpty {
            return productName
        }
        return item.title
    }
    
    private var displaySubtitle: String? {
        if let brand = item.brand, !brand.isEmpty {
            return brand
        }
        return item.subtitle
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
