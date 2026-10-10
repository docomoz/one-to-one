import Core

extension SexEntry {
    /// Строка в списке записей: «Без презерватива · внутрь». Ничего не отмечено — `nil`.
    var protectionText: String? {
        var parts: [String] = []
        if let condom { parts.append(condom ? "С презервативом" : "Без презерватива") }
        if let finish { parts.append(parts.isEmpty ? finish.title : finish.title.lowercased()) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
