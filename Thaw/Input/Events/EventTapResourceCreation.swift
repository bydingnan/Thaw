//
//  EventTapResourceCreation.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

nonisolated enum EventTapResourceCreation {
    static func create<Port, Source>(
        makePort: () -> Port?,
        makeSource: (Port) -> Source?,
        disable: (Port) -> Void,
        invalidate: (Port) -> Void,
        releaseContext: () -> Void
    ) -> (port: Port, source: Source)? {
        guard let port = makePort() else {
            releaseContext()
            return nil
        }
        disable(port)
        guard let source = makeSource(port) else {
            invalidate(port)
            releaseContext()
            return nil
        }
        return (port, source)
    }
}
