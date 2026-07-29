import PDFKit
import SwiftUI

struct PDFPageReaderView: View {
    let fileURL: URL
    let pageNumber: Int

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PDFPageView(
                fileURL: fileURL,
                pageNumber: pageNumber
            )
            .navigationTitle("Original PDF · Page \(pageNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .accessibilityIdentifier("citation.pdf-page")
    }
}

private struct PDFPageView: UIViewRepresentable {
    let fileURL: URL
    let pageNumber: Int

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.displaysPageBreaks = true
        view.accessibilityLabel = "Original PDF page \(pageNumber)"
        configure(view)
        return view
    }

    func updateUIView(
        _ view: PDFView,
        context: Context
    ) {
        configure(view)
    }

    private func configure(_ view: PDFView) {
        guard view.document?.documentURL != fileURL,
              let document = PDFDocument(url: fileURL) else {
            return
        }
        view.document = document
        let index = max(0, min(pageNumber - 1, document.pageCount - 1))
        if let page = document.page(at: index) {
            view.go(to: page)
        }
    }
}
