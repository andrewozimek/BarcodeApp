import Foundation
import SQLite3

// SQLite Database Manager for storing scanned items
class DatabaseManager {
    static let shared = DatabaseManager()
    
    private var db: OpaquePointer?
    private let dbPath: String
    
    private init() {
        // Get the documents directory path
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("BarcodeScannerDB.sqlite")
        
        dbPath = fileURL.path
        
        // Open database connection
        openDatabase()
        
        // Create tables if they don't exist
        createTables()
    }
    
    deinit {
        closeDatabase()
    }
    
    // Open database connection
    private func openDatabase() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("Error opening database")
            return
        }
        print("Database opened successfully at: \(dbPath)")
    }
    
    // Close database connection
    private func closeDatabase() {
        if sqlite3_close(db) != SQLITE_OK {
            print("Error closing database")
        }
        db = nil
    }
    
    // Create necessary tables
    private func createTables() {
        let createTableQuery = """
        CREATE TABLE IF NOT EXISTS scanned_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            raw_value TEXT NOT NULL,
            kind TEXT NOT NULL,
            title TEXT NOT NULL,
            subtitle TEXT,
            timestamp REAL NOT NULL,
            product_name TEXT,
            brand TEXT,
            energy_kcal REAL,
            fat REAL,
            saturated_fat REAL,
            carbohydrates REAL,
            sugars REAL,
            fiber REAL,
            proteins REAL,
            salt REAL,
            sodium REAL,
            is_favorite INTEGER DEFAULT 0,
            notes TEXT
        );
        """
        
        var createTableStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, createTableQuery, -1, &createTableStatement, nil) == SQLITE_OK {
            if sqlite3_step(createTableStatement) == SQLITE_DONE {
                print("Table created successfully")
            } else {
                print("Table creation failed")
            }
        } else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("CREATE TABLE statement could not be prepared: \(errorMessage)")
        }
        
        sqlite3_finalize(createTableStatement)
    }
    
    // Insert a scanned item into the database
    func insertScannedItem(item: ScannedItem, product: OFFProduct? = nil) -> Int64? {
        let insertQuery = """
        INSERT INTO scanned_items (
            raw_value, kind, title, subtitle, timestamp,
            product_name, brand, energy_kcal, fat, saturated_fat,
            carbohydrates, sugars, fiber, proteins, salt, sodium
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        var insertStatement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, insertQuery, -1, &insertStatement, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("INSERT statement could not be prepared: \(errorMessage)")
            return nil
        }
        
        // Bind values
        let timestamp = Date().timeIntervalSince1970
        sqlite3_bind_text(insertStatement, 1, (item.raw as NSString).utf8String, -1, nil)
        sqlite3_bind_text(insertStatement, 2, (item.kind.rawValue as NSString).utf8String, -1, nil)
        sqlite3_bind_text(insertStatement, 3, (item.title as NSString).utf8String, -1, nil)
        
        if let subtitle = item.subtitle {
            sqlite3_bind_text(insertStatement, 4, (subtitle as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(insertStatement, 4)
        }
        
        sqlite3_bind_double(insertStatement, 5, timestamp)
        
        // Bind product information if available
        if let product = product {
            if let productName = product.productName {
                sqlite3_bind_text(insertStatement, 6, (productName as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(insertStatement, 6)
            }
            
            if let brand = product.brands {
                sqlite3_bind_text(insertStatement, 7, (brand as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(insertStatement, 7)
            }
            
            if let nutriments = product.nutriments {
                bindOptionalDouble(insertStatement, 8, nutriments.energyKcal100g)
                bindOptionalDouble(insertStatement, 9, nutriments.fat100g)
                bindOptionalDouble(insertStatement, 10, nutriments.saturatedFat100g)
                bindOptionalDouble(insertStatement, 11, nutriments.carbohydrates100g)
                bindOptionalDouble(insertStatement, 12, nutriments.sugars100g)
                bindOptionalDouble(insertStatement, 13, nutriments.fiber100g)
                bindOptionalDouble(insertStatement, 14, nutriments.proteins100g)
                bindOptionalDouble(insertStatement, 15, nutriments.salt100g)
                bindOptionalDouble(insertStatement, 16, nutriments.sodium100g)
            } else {
                for i in 8...16 {
                    sqlite3_bind_null(insertStatement, Int32(i))
                }
            }
        } else {
            for i in 6...16 {
                sqlite3_bind_null(insertStatement, Int32(i))
            }
        }
        
        guard sqlite3_step(insertStatement) == SQLITE_DONE else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("Could not insert item: \(errorMessage)")
            sqlite3_finalize(insertStatement)
            return nil
        }
        
        let rowID = sqlite3_last_insert_rowid(db)
        sqlite3_finalize(insertStatement)
        
        print("Successfully inserted item with ID: \(rowID)")
        return rowID
    }
    
    // Helper function to bind optional double values
    private func bindOptionalDouble(_ statement: OpaquePointer?, _ index: Int32, _ value: Double?) {
        if let value = value {
            sqlite3_bind_double(statement, index, value)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }
    
    // Retrieve all scanned items from the database
    func getAllScannedItems() -> [SavedScannedItem] {
        let queryString = """
        SELECT id, raw_value, kind, title, subtitle, timestamp,
               product_name, brand, energy_kcal, fat, saturated_fat,
               carbohydrates, sugars, fiber, proteins, salt, sodium,
               is_favorite, notes
        FROM scanned_items
        ORDER BY timestamp DESC;
        """
        
        var queryStatement: OpaquePointer?
        var items: [SavedScannedItem] = []
        
        guard sqlite3_prepare_v2(db, queryString, -1, &queryStatement, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("SELECT statement could not be prepared: \(errorMessage)")
            return items
        }
        
        while sqlite3_step(queryStatement) == SQLITE_ROW {
            let id = sqlite3_column_int64(queryStatement, 0)
            let rawValue = String(cString: sqlite3_column_text(queryStatement, 1))
            let kindString = String(cString: sqlite3_column_text(queryStatement, 2))
            let title = String(cString: sqlite3_column_text(queryStatement, 3))
            
            let subtitle: String? = {
                if let text = sqlite3_column_text(queryStatement, 4) {
                    return String(cString: text)
                }
                return nil
            }()
            
            let timestamp = sqlite3_column_double(queryStatement, 5)
            
            let productName: String? = {
                if let text = sqlite3_column_text(queryStatement, 6) {
                    return String(cString: text)
                }
                return nil
            }()
            
            let brand: String? = {
                if let text = sqlite3_column_text(queryStatement, 7) {
                    return String(cString: text)
                }
                return nil
            }()
            
            let energyKcal = getOptionalDouble(queryStatement, 8)
            let fat = getOptionalDouble(queryStatement, 9)
            let saturatedFat = getOptionalDouble(queryStatement, 10)
            let carbohydrates = getOptionalDouble(queryStatement, 11)
            let sugars = getOptionalDouble(queryStatement, 12)
            let fiber = getOptionalDouble(queryStatement, 13)
            let proteins = getOptionalDouble(queryStatement, 14)
            let salt = getOptionalDouble(queryStatement, 15)
            let sodium = getOptionalDouble(queryStatement, 16)
            
            let isFavorite = sqlite3_column_int(queryStatement, 17) == 1
            
            let notes: String? = {
                if let text = sqlite3_column_text(queryStatement, 18) {
                    return String(cString: text)
                }
                return nil
            }()
            
            let kind = ScannedItem.Kind(rawValue: kindString) ?? .text
            
            let savedItem = SavedScannedItem(
                id: id,
                rawValue: rawValue,
                kind: kind,
                title: title,
                subtitle: subtitle,
                timestamp: Date(timeIntervalSince1970: timestamp),
                productName: productName,
                brand: brand,
                energyKcal: energyKcal,
                fat: fat,
                saturatedFat: saturatedFat,
                carbohydrates: carbohydrates,
                sugars: sugars,
                fiber: fiber,
                proteins: proteins,
                salt: salt,
                sodium: sodium,
                isFavorite: isFavorite,
                notes: notes
            )
            
            items.append(savedItem)
        }
        
        sqlite3_finalize(queryStatement)
        return items
    }
    
    // Helper function to get optional double values
    private func getOptionalDouble(_ statement: OpaquePointer?, _ index: Int32) -> Double? {
        if sqlite3_column_type(statement, index) != SQLITE_NULL {
            return sqlite3_column_double(statement, index)
        }
        return nil
    }
    
    // Delete an item by ID
    func deleteItem(id: Int64) -> Bool {
        let deleteQuery = "DELETE FROM scanned_items WHERE id = ?;"
        var deleteStatement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, deleteQuery, -1, &deleteStatement, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("DELETE statement could not be prepared: \(errorMessage)")
            return false
        }
        
        sqlite3_bind_int64(deleteStatement, 1, id)
        
        let result = sqlite3_step(deleteStatement) == SQLITE_DONE
        sqlite3_finalize(deleteStatement)
        
        if result {
            print("Successfully deleted item with ID: \(id)")
        }
        
        return result
    }
    
    // Toggle favorite status
    func toggleFavorite(id: Int64) -> Bool {
        let updateQuery = """
        UPDATE scanned_items
        SET is_favorite = CASE WHEN is_favorite = 1 THEN 0 ELSE 1 END
        WHERE id = ?;
        """
        var updateStatement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, updateQuery, -1, &updateStatement, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("UPDATE statement could not be prepared: \(errorMessage)")
            return false
        }
        
        sqlite3_bind_int64(updateStatement, 1, id)
        
        let result = sqlite3_step(updateStatement) == SQLITE_DONE
        sqlite3_finalize(updateStatement)
        
        return result
    }
    
    // Update notes for an item
    func updateNotes(id: Int64, notes: String?) -> Bool {
        let updateQuery = "UPDATE scanned_items SET notes = ? WHERE id = ?;"
        var updateStatement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, updateQuery, -1, &updateStatement, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("UPDATE statement could not be prepared: \(errorMessage)")
            return false
        }
        
        if let notes = notes {
            sqlite3_bind_text(updateStatement, 1, (notes as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(updateStatement, 1)
        }
        
        sqlite3_bind_int64(updateStatement, 2, id)
        
        let result = sqlite3_step(updateStatement) == SQLITE_DONE
        sqlite3_finalize(updateStatement)
        
        return result
    }
}

// Model for saved scanned items retrieved from database
struct SavedScannedItem: Identifiable {
    let id: Int64
    let rawValue: String
    let kind: ScannedItem.Kind
    let title: String
    let subtitle: String?
    let timestamp: Date
    
    // Product information
    let productName: String?
    let brand: String?
    
    // Nutrition information
    let energyKcal: Double?
    let fat: Double?
    let saturatedFat: Double?
    let carbohydrates: Double?
    let sugars: Double?
    let fiber: Double?
    let proteins: Double?
    let salt: Double?
    let sodium: Double?
    
    // User data
    let isFavorite: Bool
    let notes: String?
    
    // Convert to ScannedItem for display in details view
    func toScannedItem() -> ScannedItem {
        let actionableURL: URL? = {
            if kind == .upc {
                let query = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
                let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
                return URL(string: "https://www.google.com/search?q=UPC+" + encoded)
            } else if kind == .url {
                return URL(string: rawValue)
            }
            return nil
        }()
        
        let offProduct: OFFProduct? = {
            guard productName != nil || brand != nil else { return nil }
            
            let nutriments: OFFNutriments? = {
                guard energyKcal != nil || fat != nil || carbohydrates != nil else { return nil }
                return OFFNutriments(
                    energyKcal100g: energyKcal,
                    fat100g: fat,
                    saturatedFat100g: saturatedFat,
                    carbohydrates100g: carbohydrates,
                    sugars100g: sugars,
                    fiber100g: fiber,
                    proteins100g: proteins,
                    salt100g: salt,
                    sodium100g: sodium
                )
            }()
            
            return OFFProduct(
                code: kind == .upc ? rawValue : nil,
                productName: productName,
                brands: brand,
                nutriments: nutriments
            )
        }()
        
        return ScannedItem(
            raw: rawValue,
            kind: kind,
            title: title,
            subtitle: subtitle,
            actionableURL: actionableURL,
            offProduct: offProduct
        )
    }
}
