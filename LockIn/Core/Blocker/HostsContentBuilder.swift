import Foundation

enum HostsMarkers {
    static let begin = "# BEGIN LOCKIN BLOCK"
    static let end = "# END LOCKIN BLOCK"
}

/// Builds the new /etc/hosts content for the website-domain blocker.
///
/// Contract: only the section between (and including) the LOCKIN marker lines
/// is ever rewritten; everything outside is preserved byte-for-byte. Domains
/// never enter shell arguments — they only appear inside the built content
/// file, which the privileged applier moves into place.
struct HostsContentBuilder {

    /// Build the new /etc/hosts content: everything outside the managed marker
    /// section preserved byte-for-byte; managed section replaced with entries
    /// for the enabled domains (domain + www.domain -> 0.0.0.0). Idempotent.
    static func build(currentHosts: String, enabledDomains: [String]) -> String {
        let block = managedSection(for: enabledDomains)

        if let beginRange = currentHosts.range(of: HostsMarkers.begin),
           let endRange = currentHosts.range(of: HostsMarkers.end),
           beginRange.lowerBound < endRange.lowerBound {
            var head = String(currentHosts[currentHosts.startIndex..<beginRange.lowerBound])
            var tail = String(currentHosts[endRange.upperBound...])

            // Normalize the boundaries so the spliced result ends lines cleanly.
            while head.hasSuffix("\n") { head.removeLast() }
            if !head.isEmpty { head += "\n" }
            while tail.hasPrefix("\n") { tail.removeFirst() }
            if !tail.isEmpty {
                tail = "\n" + tail
                if !tail.hasSuffix("\n") { tail += "\n" }
            }

            return head + block + tail
        }

        // No usable managed section. If orphan markers exist (unpaired, or
        // END before BEGIN), the base is corrupted: strip only the marker
        // lines themselves — every other line is foreign content that must
        // survive — then rebuild via the append path. (Appending without
        // stripping would leave an orphan BEGIN eating foreign lines or an
        // orphan END that makes every later build append again.)
        var base = currentHosts
        if base.contains(HostsMarkers.begin) || base.contains(HostsMarkers.end) {
            base = base
                .components(separatedBy: "\n")
                .filter {
                    let line = $0.trimmingCharacters(in: .whitespaces)
                    return line != HostsMarkers.begin && line != HostsMarkers.end
                }
                .joined(separator: "\n")
        }

        // No managed section yet: append one, with exactly one separating newline.
        while base.hasSuffix("\n") { base.removeLast() }
        return base.isEmpty ? block : base + "\n" + block
    }

    /// The managed block: BEGIN marker, one 0.0.0.0 line per domain (plus its
    /// www variant), END marker. Always ends with exactly one newline.
    private static func managedSection(for domains: [String]) -> String {
        let sorted = Array(Set(domains.map { $0.lowercased() })).sorted()
        var lines = [HostsMarkers.begin]
        for domain in sorted where !domain.isEmpty {
            lines.append("0.0.0.0 \(domain)")
            if !domain.hasPrefix("www.") {
                lines.append("0.0.0.0 www.\(domain)")
            }
        }
        lines.append(HostsMarkers.end)
        return lines.joined(separator: "\n") + "\n"
    }

    /// "https://www.YouTube.com/watch?v=1" -> "youtube.com"; strips scheme/path/port,
    /// lowercases; returns nil for empty/invalid (no dot, spaces).
    static func normalizeDomain(_ raw: String) -> String? {
        var input = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return nil }

        // Strip scheme if present.
        if let schemeRange = input.range(of: "://") {
            input = String(input[schemeRange.upperBound...])
        }
        // Cut at the first slash: kills path + query leftovers.
        if let slashIdx = input.firstIndex(where: { $0 == "/" }) {
            input = String(input[..<slashIdx])
        }
        // Strip userinfo (user:pass@host) and port.
        if let atIdx = input.lastIndex(of: "@") {
            input = String(input[input.index(after: atIdx)...])
        }
        if let colonIdx = input.firstIndex(of: ":") {
            input = String(input[..<colonIdx])
        }

        input = input.lowercased()
        while input.hasSuffix(".") { input.removeLast() }
        // The bare domain is canonical: "www.youtube.com" -> "youtube.com"
        // (build() re-adds the www variant for hosts entries).
        if input.hasPrefix("www.") { input = String(input.dropFirst(4)) }

        // Strict charset whitelist: a hosts entry is one token on one line, so
        // anything outside [a-z0-9.-] (newlines, spaces, '#', '/', …) could
        // inject extra hosts lines or shell/host syntax and is rejected.
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789.-")
        guard !input.isEmpty,
              input.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
        // Empty labels ("a..b") are not hostnames; neither are labels whose
        // edges are dashes ("-a.com", "a-.com").
        let labels = input.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2,
              labels.allSatisfy({
                  !$0.isEmpty && $0.first != "-" && $0.last != "-"
              }) else { return nil }
        return input
    }
}
