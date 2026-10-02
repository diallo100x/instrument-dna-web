import Foundation

/// Edits mapping metadata without replacing analyzed measurements or original layers.
enum NoteMap {
    static let roles = ["sustain", "trill", "staccato", "accent", "breathy", "alternate"]
    struct Entry: Identifiable {
        let role: String
        let midi: Int
        let anchor: [String: Any]
        let hasAudio: Bool
        var id: String { "\(role):\(midi)" }
    }
    static func entries(_ document: [String: Any]) -> [Entry] {
        let dna = document["reflection"] as? [String: Any] ?? document
        let performance = dna["performance"] as? [String: Any] ?? [:]
        let layers = performance["layers"] as? [String: [[String: Any]]] ?? [:]
        var result: [Entry] = []
        for role in roles {
            var anchors = layers[role] ?? []
            if role == "sustain" {
                for anchor in dna["anchors"] as? [[String: Any]] ?? [] {
                    if !anchors.contains(where: { ($0["midi"] as? Int) == (anchor["midi"] as? Int) }) { anchors.append(anchor) }
                }
            }
            for anchor in anchors {
                guard let midi = anchor["midi"] as? Int, (0...127).contains(midi), !result.contains(where: { $0.role == role && $0.midi == midi }) else { continue }
                result.append(Entry(role: role, midi: midi, anchor: anchor, hasAudio: clip(document, role: role, midi: midi) != nil))
            }
        }
        return result.sorted { $0.midi == $1.midi ? roles.firstIndex(of: $0.role)! < roles.firstIndex(of: $1.role)! : $0.midi < $1.midi }
    }
    private static func clip(_ document: [String: Any], role: String, midi: Int) -> [String: Any]? {
        if let found = (document["audioLayers"] as? [[String: Any]] ?? []).last(where: { ($0["layer"] as? String) == role && ($0["midi"] as? Int) == midi }) { return found }
        return role == "sustain" ? (document["audio"] as? [[String: Any]] ?? []).last(where: { ($0["midi"] as? Int) == midi }) : nil
    }
    static func copy(_ entry: Entry, to role: String, in document: [String: Any]) throws -> [String: Any] {
        guard roles.contains(role), role != entry.role else { throw EditError("Choose a different articulation layer.") }
        guard !entries(document).contains(where: { $0.role == role && $0.midi == entry.midi }) else { throw EditError("That key already has a \(role) anchor. Its existing sound has been preserved.") }
        var document = document
        var dna = document["reflection"] as? [String: Any] ?? document
        var performance = dna["performance"] as? [String: Any] ?? [:]
        var layers = performance["layers"] as? [String: [[String: Any]]] ?? [:]
        var anchor = entry.anchor
        anchor["articulation"] = role
        // Retain the source classification alongside the editable mapping.
        anchor["originalArticulation"] = anchor["originalArticulation"] ?? entry.role
        layers[role, default: []].append(anchor)
        performance["layers"] = layers; dna["performance"] = performance
        if document["reflection"] != nil { document["reflection"] = dna } else { document = dna }
        if var audio = clip(document, role: entry.role, midi: entry.midi) {
            audio["layer"] = role
            var clips = document["audioLayers"] as? [[String: Any]] ?? []
            clips.append(audio); document["audioLayers"] = clips
        }
        return document
    }
    struct EditError: LocalizedError {
        let message: String
        init(_ message: String) { self.message = message }
        var errorDescription: String? { message }
    }
}
