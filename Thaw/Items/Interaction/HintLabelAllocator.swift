//
//  HintLabelAllocator.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

nonisolated enum HintLabelAllocator {
    static let alphabet = Array("asdfghjklqwertyuiopzxcvbnm")

    static func labels(for identifiers: [String], previous: [String: String] = [:]) -> [String: String] {
        var seen = Set<String>()
        let identifiers = identifiers.filter { seen.insert($0).inserted }
        var width = 1
        var capacity = alphabet.count
        while capacity < identifiers.count {
            width += 1
            capacity *= alphabet.count
        }
        var result = [String: String]()
        var used = Set<String>()
        for identifier in identifiers {
            if let label = previous[identifier], label.count == width, label.allSatisfy({ alphabet.contains($0) }), used.insert(label).inserted {
                result[identifier] = label
            }
        }
        var candidate = 0
        for identifier in identifiers where result[identifier] == nil {
            var label: String
            repeat {
                label = Self.label(at: candidate, width: width)
                candidate += 1
            } while used.contains(label)
            used.insert(label)
            result[identifier] = label
        }
        return result
    }

    private static func label(at index: Int, width: Int) -> String {
        var value = index
        var characters = Array(repeating: alphabet[0], count: width)
        for position in characters.indices.reversed() {
            characters[position] = alphabet[value % alphabet.count]
            value /= alphabet.count
        }
        return String(characters)
    }
}

nonisolated struct HintInputSession {
    enum Key {
        case text(String)
        case backspace
        case escape
    }

    enum Outcome: Equatable {
        case pending
        case choose(String)
        case cancelled
    }

    let labels: Set<String>
    private(set) var prefix = ""

    mutating func receive(_ key: Key) -> Outcome {
        switch key {
        case .escape:
            prefix = ""
            return .cancelled
        case .backspace:
            if !prefix.isEmpty {
                prefix.removeLast()
            }
            return .pending
        case let .text(text):
            prefix += text.lowercased()
            if labels.contains(prefix) {
                return .choose(prefix)
            }
            guard !text.isEmpty, labels.contains(where: { $0.hasPrefix(prefix) }) else {
                prefix = ""
                return .cancelled
            }
            return .pending
        }
    }
}
