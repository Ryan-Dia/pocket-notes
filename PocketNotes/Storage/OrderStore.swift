import Foundation

struct OrderStore {
    struct Order: Codable {
        var folders: [String] = []
        var notes: [String] = []
    }

    static func load(for parentURL: URL) -> Order {
        let file = parentURL.appendingPathComponent(".order")
        guard let data = try? Data(contentsOf: file),
              let order = try? JSONDecoder().decode(Order.self, from: data)
        else { return Order() }
        return order
    }

    static func save(_ order: Order, for parentURL: URL) {
        let file = parentURL.appendingPathComponent(".order")
        guard let data = try? JSONEncoder().encode(order) else { return }
        try? data.write(to: file)
    }
}
