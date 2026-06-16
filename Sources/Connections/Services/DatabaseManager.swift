import Foundation
import SQLite3
import CoreGraphics

final class DatabaseManager {
    static let shared = DatabaseManager()
    private var db: OpaquePointer?

    private init() {
        openDatabase()
        createTables()
    }

    deinit { sqlite3_close(db) }

    private func openDatabase() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Connections", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("connections.db").path
        guard sqlite3_open(path, &db) == SQLITE_OK else {
            print("Failed to open database at \(path)")
            return
        }
        sqlite3_exec(db, "PRAGMA foreign_keys = ON;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA journal_mode = WAL;", nil, nil, nil)
    }

    private func createTables() {
        let sql = """
        CREATE TABLE IF NOT EXISTS sessions (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            paragraph TEXT NOT NULL,
            created_at INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS nodes (
            id TEXT PRIMARY KEY,
            session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
            word TEXT NOT NULL,
            number INTEGER NOT NULL,
            position_x REAL NOT NULL,
            position_y REAL NOT NULL
        );
        CREATE TABLE IF NOT EXISTS edges (
            id TEXT PRIMARY KEY,
            session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
            from_node_id TEXT NOT NULL,
            to_node_id TEXT NOT NULL,
            style INTEGER NOT NULL
        );
        """
        sqlite3_exec(db, sql, nil, nil, nil)
        // Non-destructive migration: add color_index if the column doesn't exist yet
        sqlite3_exec(db, "ALTER TABLE nodes ADD COLUMN color_index INTEGER;", nil, nil, nil)
    }

    // MARK: - Sessions

    func loadAllSessions() -> [Session] {
        var sessions: [Session] = []
        var stmt: OpaquePointer?
        let sql = "SELECT id, name, paragraph, created_at FROM sessions ORDER BY created_at DESC;"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = UUID(uuidString: String(cString: sqlite3_column_text(stmt, 0))) ?? UUID()
            let name = String(cString: sqlite3_column_text(stmt, 1))
            let paragraph = String(cString: sqlite3_column_text(stmt, 2))
            let createdAt = Date(timeIntervalSince1970: Double(sqlite3_column_int64(stmt, 3)))
            var session = Session(id: id, name: name, paragraph: paragraph, createdAt: createdAt)
            session.nodes = loadNodes(sessionId: id)
            session.edges = loadEdges(sessionId: id)
            sessions.append(session)
        }
        return sessions
    }

    func saveSession(_ session: Session) {
        let sql = "INSERT OR REPLACE INTO sessions (id, name, paragraph, created_at) VALUES (?, ?, ?, ?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        let idStr = session.id.uuidString as NSString
        sqlite3_bind_text(stmt, 1, idStr.utf8String, -1, nil)
        let nameStr = session.name as NSString
        sqlite3_bind_text(stmt, 2, nameStr.utf8String, -1, nil)
        let paraStr = session.paragraph as NSString
        sqlite3_bind_text(stmt, 3, paraStr.utf8String, -1, nil)
        sqlite3_bind_int64(stmt, 4, Int64(session.createdAt.timeIntervalSince1970))
        sqlite3_step(stmt)

        deleteNodes(sessionId: session.id)
        deleteEdges(sessionId: session.id)
        for node in session.nodes { saveNode(node, sessionId: session.id) }
        for edge in session.edges { saveEdge(edge, sessionId: session.id) }
    }

    func deleteSession(id: UUID) {
        var stmt: OpaquePointer?
        let sql = "DELETE FROM sessions WHERE id = ?;"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        let s = id.uuidString as NSString
        sqlite3_bind_text(stmt, 1, s.utf8String, -1, nil)
        sqlite3_step(stmt)
    }

    func renameSession(id: UUID, name: String) {
        var stmt: OpaquePointer?
        let sql = "UPDATE sessions SET name = ? WHERE id = ?;"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        let n = name as NSString
        sqlite3_bind_text(stmt, 1, n.utf8String, -1, nil)
        let s = id.uuidString as NSString
        sqlite3_bind_text(stmt, 2, s.utf8String, -1, nil)
        sqlite3_step(stmt)
    }

    // MARK: - Nodes

    private func loadNodes(sessionId: UUID) -> [WordNode] {
        var nodes: [WordNode] = []
        var stmt: OpaquePointer?
        let sql = "SELECT id, word, number, position_x, position_y, color_index FROM nodes WHERE session_id = ? ORDER BY number;"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        let s = sessionId.uuidString as NSString
        sqlite3_bind_text(stmt, 1, s.utf8String, -1, nil)
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = UUID(uuidString: String(cString: sqlite3_column_text(stmt, 0))) ?? UUID()
            let word = String(cString: sqlite3_column_text(stmt, 1))
            let number = Int(sqlite3_column_int(stmt, 2))
            let x = sqlite3_column_double(stmt, 3)
            let y = sqlite3_column_double(stmt, 4)
            let colorIndex: Int? = sqlite3_column_type(stmt, 5) == SQLITE_NULL
                ? nil : Int(sqlite3_column_int(stmt, 5))
            nodes.append(WordNode(id: id, word: word, number: number,
                                  position: CGPoint(x: x, y: y), colorIndex: colorIndex))
        }
        return nodes
    }

    private func saveNode(_ node: WordNode, sessionId: UUID) {
        var stmt: OpaquePointer?
        let sql = "INSERT OR REPLACE INTO nodes (id, session_id, word, number, position_x, position_y, color_index) VALUES (?, ?, ?, ?, ?, ?, ?);"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        let idStr = node.id.uuidString as NSString
        sqlite3_bind_text(stmt, 1, idStr.utf8String, -1, nil)
        let sIdStr = sessionId.uuidString as NSString
        sqlite3_bind_text(stmt, 2, sIdStr.utf8String, -1, nil)
        let wordStr = node.word as NSString
        sqlite3_bind_text(stmt, 3, wordStr.utf8String, -1, nil)
        sqlite3_bind_int(stmt, 4, Int32(node.number))
        sqlite3_bind_double(stmt, 5, Double(node.position.x))
        sqlite3_bind_double(stmt, 6, Double(node.position.y))
        if let ci = node.colorIndex {
            sqlite3_bind_int(stmt, 7, Int32(ci))
        } else {
            sqlite3_bind_null(stmt, 7)
        }
        sqlite3_step(stmt)
    }

    private func deleteNodes(sessionId: UUID) {
        var stmt: OpaquePointer?
        let sql = "DELETE FROM nodes WHERE session_id = ?;"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        let s = sessionId.uuidString as NSString
        sqlite3_bind_text(stmt, 1, s.utf8String, -1, nil)
        sqlite3_step(stmt)
    }

    // MARK: - Edges

    private func loadEdges(sessionId: UUID) -> [Edge] {
        var edges: [Edge] = []
        var stmt: OpaquePointer?
        let sql = "SELECT id, from_node_id, to_node_id, style FROM edges WHERE session_id = ?;"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        let s = sessionId.uuidString as NSString
        sqlite3_bind_text(stmt, 1, s.utf8String, -1, nil)
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = UUID(uuidString: String(cString: sqlite3_column_text(stmt, 0))) ?? UUID()
            let fromId = UUID(uuidString: String(cString: sqlite3_column_text(stmt, 1))) ?? UUID()
            let toId = UUID(uuidString: String(cString: sqlite3_column_text(stmt, 2))) ?? UUID()
            let style = EdgeStyle(rawValue: Int(sqlite3_column_int(stmt, 3))) ?? .line
            edges.append(Edge(id: id, fromId: fromId, toId: toId, style: style))
        }
        return edges
    }

    private func saveEdge(_ edge: Edge, sessionId: UUID) {
        var stmt: OpaquePointer?
        let sql = "INSERT OR REPLACE INTO edges (id, session_id, from_node_id, to_node_id, style) VALUES (?, ?, ?, ?, ?);"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        let idStr = edge.id.uuidString as NSString
        sqlite3_bind_text(stmt, 1, idStr.utf8String, -1, nil)
        let sIdStr = sessionId.uuidString as NSString
        sqlite3_bind_text(stmt, 2, sIdStr.utf8String, -1, nil)
        let fromStr = edge.fromId.uuidString as NSString
        sqlite3_bind_text(stmt, 3, fromStr.utf8String, -1, nil)
        let toStr = edge.toId.uuidString as NSString
        sqlite3_bind_text(stmt, 4, toStr.utf8String, -1, nil)
        sqlite3_bind_int(stmt, 5, Int32(edge.style.rawValue))
        sqlite3_step(stmt)
    }

    private func deleteEdges(sessionId: UUID) {
        var stmt: OpaquePointer?
        let sql = "DELETE FROM edges WHERE session_id = ?;"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        let s = sessionId.uuidString as NSString
        sqlite3_bind_text(stmt, 1, s.utf8String, -1, nil)
        sqlite3_step(stmt)
    }
}
