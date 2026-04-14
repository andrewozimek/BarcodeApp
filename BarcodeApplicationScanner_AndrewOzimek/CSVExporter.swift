import Foundation

// CSV Export functionality for scanned items
class CSVExporter {
    
    // Export all scanned items to CSV format
    static func exportToCSV(items: [SavedScannedItem]) -> String {
        var csv = ""
        
        // Add header row
        csv += "ID,Barcode,Type,Product Name,Brand,Scanned Date,Category,Favorite,"
        csv += "Calories (per 100g),Fat (g),Saturated Fat (g),Carbohydrates (g),"
        csv += "Sugars (g),Fiber (g),Protein (g),Salt (g),Sodium (g),Notes\n"
        
        // Add data rows
        for item in items {
            let row = [
                "\(item.id)",
                escapeCSV(item.rawValue),
                escapeCSV(item.kind.rawValue),
                escapeCSV(item.productName ?? item.title),
                escapeCSV(item.brand ?? ""),
                formatDate(item.timestamp),
                "", // Category - for future use
                item.isFavorite ? "Yes" : "No",
                formatDouble(item.energyKcal),
                formatDouble(item.fat),
                formatDouble(item.saturatedFat),
                formatDouble(item.carbohydrates),
                formatDouble(item.sugars),
                formatDouble(item.fiber),
                formatDouble(item.proteins),
                formatDouble(item.salt),
                formatDouble(item.sodium),
                escapeCSV(item.notes ?? "")
            ]
            
            csv += row.joined(separator: ",") + "\n"
        }
        
        return csv
    }
    
    // Export favorites only
    static func exportFavoritesToCSV(items: [SavedScannedItem]) -> String {
        let favorites = items.filter { $0.isFavorite }
        return exportToCSV(items: favorites)
    }
    
    // Save CSV to file and return URL
    static func saveCSVToFile(csvContent: String, filename: String = "BarcodeScanHistory.csv") -> URL? {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        guard let documentsDirectory = paths.first else { return nil }
        
        let fileURL = documentsDirectory.appendingPathComponent(filename)
        
        do {
            try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
            print("✅ CSV file saved to: \(fileURL.path)")
            return fileURL
        } catch {
            print("❌ Error saving CSV file: \(error)")
            return nil
        }
    }
    
    // Helper: Escape CSV special characters
    private static func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
    
    // Helper: Format date for CSV
    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Helper: Format optional double values
    private static func formatDouble(_ value: Double?) -> String {
        guard let value = value else { return "" }
        return String(format: "%.2f", value)
    }
}

// Extension to share CSV files
#if canImport(UIKit)
import UIKit

extension CSVExporter {
    static func shareCSV(from viewController: UIViewController, fileURL: URL) {
        let activityViewController = UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: nil
        )
        
        // For iPad support
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(x: viewController.view.bounds.midX,
                                       y: viewController.view.bounds.midY,
                                       width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        viewController.present(activityViewController, animated: true)
    }
}
#endif

#if canImport(AppKit)
import AppKit

extension CSVExporter {
    static func shareCSV(fileURL: URL) {
        let sharingPicker = NSSharingServicePicker(items: [fileURL])
        
        // Show the share menu at the center of the screen
        if let window = NSApp.keyWindow,
           let contentView = window.contentView {
            let rect = CGRect(x: contentView.bounds.midX - 100,
                            y: contentView.bounds.midY,
                            width: 200, height: 40)
            sharingPicker.show(relativeTo: rect, of: contentView, preferredEdge: .minY)
        }
    }
}
#endif
