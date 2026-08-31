import UIKit

enum PediatricReport {
    static func make(profile: Profile, entries: [Entry], days: Int = 30) throws -> URL {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .distantPast
        let recent = entries.filter { $0.date >= cutoff }.sorted { $0.occurredAt > $1.occurredAt }
        let url = FileManager.default.temporaryDirectory
            .appending(path: "Nido-\(profile.babyName)-ultimos-\(days)-dias.pdf")
        let format = UIGraphicsPDFRendererFormat()
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842), format: format)
        try renderer.writePDF(to: url) { context in
            var y: CGFloat = 54
            func page() { context.beginPage(); y = 54 }
            func draw(_ text: String, font: UIFont, color: UIColor = .label, spacing: CGFloat = 9) {
                let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                let rect = (text as NSString).boundingRect(with: CGSize(width: 487, height: CGFloat.greatestFiniteMagnitude), options: [.usesLineFragmentOrigin], attributes: attributes, context: nil)
                if y + rect.height > 788 { page() }
                (text as NSString).draw(in: CGRect(x: 54, y: y, width: 487, height: rect.height + 2), withAttributes: attributes)
                y += rect.height + spacing
            }

            page()
            draw("Nido", font: .systemFont(ofSize: 15, weight: .semibold), color: UIColor(red: 0.32, green: 0.43, blue: 0.37, alpha: 1))
            draw("Resumen de \(profile.babyName)", font: .systemFont(ofSize: 28, weight: .bold), spacing: 5)
            draw("Últimos \(days) días · generado el \(Date.now.formatted(date: .long, time: .shortened))", font: .systemFont(ofSize: 11), color: .secondaryLabel, spacing: 24)

            let counts = Dictionary(grouping: recent, by: \.kind).mapValues(\.count)
            draw("Resumen", font: .systemFont(ofSize: 18, weight: .semibold))
            draw("Sueños: \(counts[.sleep, default: 0])   Tomas: \(counts[.feed, default: 0])   Pañales: \(counts[.diaper, default: 0])   Cuidados: \(counts[.health, default: 0])", font: .systemFont(ofSize: 12), spacing: 22)
            draw("Registro", font: .systemFont(ofSize: 18, weight: .semibold), spacing: 14)

            for entry in recent {
                let author = entry.caregiverName.map { " · por \($0)" } ?? ""
                draw("\(entry.date.formatted(date: .abbreviated, time: .shortened)) · \(entry.title)\(author)", font: .systemFont(ofSize: 11, weight: .semibold), spacing: 3)
                draw(entry.summary.isEmpty ? "Sin detalles" : entry.summary, font: .systemFont(ofSize: 10), color: .secondaryLabel, spacing: 11)
            }

            y += 10
            draw("Este documento resume registros introducidos por los familiares. No contiene diagnósticos ni sustituye la valoración de un profesional sanitario.", font: .systemFont(ofSize: 9), color: .secondaryLabel)
        }
        return url
    }
}
