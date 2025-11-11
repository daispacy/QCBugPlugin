//
//  QCScreenshotAnnotationViewController.swift
//  QCBugPlugin
//
//  Created by PayooMerchant on 11/4/25.
//

import UIKit
import AVFoundation

/// View controller that allows annotating captured screenshots before submission
final class QCScreenshotAnnotationViewController: UIViewController {

    // MARK: - Properties
    private let screenshotImage: UIImage
    private let originalURL: URL
    private let completion: (Result<URL, Error>) -> Void

    private let imageView = UIImageView()
    private let canvasView = AnnotationCanvasView()
    private let toolbar = UIStackView()
    private let undoButton = UIButton(type: .system)
    private let clearButton = UIButton(type: .system)
    private let colorControl = UISegmentedControl(items: ["🔴", "🟡", "🔵"])

    private var hasCompleted = false

    // MARK: - Initialization

    init(image: UIImage, originalURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        self.screenshotImage = image
        self.originalURL = originalURL
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let imageRect = AVMakeRect(aspectRatio: screenshotImage.size, insideRect: imageView.bounds)
        canvasView.imageFrame = imageRect
    }

    // MARK: - UI Configuration

    private func configureUI() {
        view.backgroundColor = .white
        title = "Annotate Screenshot"
        if #available(iOS 13.0, *) {
            isModalInPresentation = true
        }

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(doneTapped)
        )

        setupImageView()
        setupCanvasView()
        setupToolbar()
        updateActionButtons()
    }

    private func setupImageView() {
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = screenshotImage
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .black
        view.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }

    private func setupCanvasView() {
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        canvasView.backgroundColor = .clear
        canvasView.onStrokesChanged = { [weak self] in
            self?.updateActionButtons()
        }
        view.addSubview(canvasView)

        NSLayoutConstraint.activate([
            canvasView.topAnchor.constraint(equalTo: imageView.topAnchor),
            canvasView.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
            canvasView.bottomAnchor.constraint(equalTo: imageView.bottomAnchor)
        ])
    }

    private func setupToolbar() {
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.axis = .horizontal
        toolbar.alignment = .center
        toolbar.spacing = 12
        toolbar.distribution = .fill

        undoButton.setTitle("Undo", for: .normal)
        undoButton.addTarget(self, action: #selector(undoTapped), for: .touchUpInside)

        clearButton.setTitle("Clear", for: .normal)
        clearButton.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)

        colorControl.selectedSegmentIndex = 0
        colorControl.addTarget(self, action: #selector(colorChanged), for: .valueChanged)
        canvasView.currentColor = .systemRed

        toolbar.addArrangedSubview(undoButton)
        toolbar.addArrangedSubview(clearButton)
        toolbar.addArrangedSubview(colorControl)

        view.addSubview(toolbar)

        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 16),
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24)
        ])
    }

    // MARK: - Actions

    @objc private func cancelTapped() {
        complete(with: .failure(ScreenshotAnnotationError.cancelled))
    }

    @objc private func doneTapped() {
        view.layoutIfNeeded()

        let composition = canvasView.composedImage(with: screenshotImage)
        let resultImage = composition.image
        let wasModified = composition.modified

        if !wasModified {
            showSaveConfirmation(imageURL: originalURL)
            return
        }

        do {
            let annotatedURL = try saveAnnotatedImage(resultImage)
            showSaveConfirmation(imageURL: annotatedURL)
        } catch {
            presentErrorAlert(message: error.localizedDescription) { [weak self] in
                self?.complete(with: .failure(ScreenshotAnnotationError.failedToSaveImage))
            }
        }
    }

    private func showSaveConfirmation(imageURL: URL) {
        let alert = UIAlertController(
            title: "Add Screenshot",
            message: "Do you want to add this screenshot to the bug report?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Discard", style: .destructive) { [weak self] _ in
            self?.complete(with: .failure(ScreenshotAnnotationError.cancelled))
        })

        alert.addAction(UIAlertAction(title: "Add", style: .default) { [weak self] _ in
            self?.complete(with: .success(imageURL))
        })

        present(alert, animated: true)
    }

    @objc private func undoTapped() {
        canvasView.undo()
    }

    @objc private func clearTapped() {
        canvasView.clear()
    }

    @objc private func colorChanged() {
        switch colorControl.selectedSegmentIndex {
        case 0:
            canvasView.currentColor = .systemRed
        case 1:
            canvasView.currentColor = .systemYellow
        case 2:
            canvasView.currentColor = .systemBlue
        default:
            canvasView.currentColor = .systemRed
        }
    }

    // MARK: - Helpers

    private func saveAnnotatedImage(_ image: UIImage) throws -> URL {
        guard let pngData = image.pngData() else {
            throw ScreenshotAnnotationError.failedToSaveImage
        }

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let qcDirectory = documentsPath.appendingPathComponent("QCBugPlugin", isDirectory: true)
        let fileName = "qc_screenshot_annotated_\(Date().timeIntervalSince1970).png"
        try FileManager.default.createDirectory(at: qcDirectory, withIntermediateDirectories: true, attributes: nil)
        let fileURL = qcDirectory.appendingPathComponent(fileName)
        try pngData.write(to: fileURL, options: .atomic)
        return fileURL
    }

    private func presentErrorAlert(message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: "Annotation Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completion?()
        })
        present(alert, animated: true)
    }

    private func complete(with result: Result<URL, Error>) {
        guard !hasCompleted else { return }
        hasCompleted = true

        // Dismiss first, then call completion after dismissal is complete
        dismiss(animated: true) { [weak self] in
            self?.completion(result)
        }
    }

    private func updateActionButtons() {
        let hasStrokes = canvasView.hasStrokes
        undoButton.isEnabled = hasStrokes
        clearButton.isEnabled = hasStrokes
    }
}

// MARK: - Annotation Canvas View

private final class AnnotationCanvasView: UIView {

    // MARK: - Stroke Definition

    private struct Stroke {
        let path: UIBezierPath
        let color: UIColor
        let lineWidth: CGFloat
    }

    // MARK: - Properties

    var imageFrame: CGRect = .zero
    var currentColor: UIColor = .systemRed
    var onStrokesChanged: (() -> Void)?

    private var strokes: [Stroke] = []
    private let defaultLineWidth: CGFloat = 4.0

    private var activeStrokePath: UIBezierPath?

    var hasStrokes: Bool {
        return !strokes.isEmpty
    }

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        isOpaque = false
        backgroundColor = .clear
        isMultipleTouchEnabled = false
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        guard imageFrame.contains(point) else { return }

        let clampedPoint = clamp(point)
        let path = UIBezierPath()
        path.move(to: clampedPoint)
        path.lineWidth = defaultLineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        let stroke = Stroke(path: path, color: currentColor, lineWidth: defaultLineWidth)
        strokes.append(stroke)
        activeStrokePath = path
        setNeedsDisplay()
        onStrokesChanged?()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self), let path = activeStrokePath else { return }
        let clampedPoint = clamp(point)
        path.addLine(to: clampedPoint)
        setNeedsDisplay()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        finishCurrentStroke()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        finishCurrentStroke()
    }

    private func finishCurrentStroke() {
        activeStrokePath = nil
        setNeedsDisplay()
    }

    // MARK: - Drawing

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)

        if imageFrame != .zero {
            let clipPath = UIBezierPath(rect: imageFrame)
            clipPath.addClip()
        }

        for stroke in strokes {
            stroke.color.setStroke()
            stroke.path.lineWidth = stroke.lineWidth
            stroke.path.stroke()
        }
    }

    // MARK: - Annotation Helpers

    func undo() {
        guard !strokes.isEmpty else { return }
        strokes.removeLast()
        setNeedsDisplay()
        onStrokesChanged?()
    }

    func clear() {
        strokes.removeAll()
        activeStrokePath = nil
        setNeedsDisplay()
        onStrokesChanged?()
    }

    func composedImage(with baseImage: UIImage) -> (image: UIImage, modified: Bool) {
        guard hasStrokes, imageFrame.width > 0, imageFrame.height > 0 else {
            return (baseImage, false)
        }

        let renderer = UIGraphicsImageRenderer(size: baseImage.size)
        let annotatedImage = renderer.image { context in
            baseImage.draw(in: CGRect(origin: .zero, size: baseImage.size))

            let scaleX = baseImage.size.width / imageFrame.width
            let scaleY = baseImage.size.height / imageFrame.height
            let offsetX = imageFrame.origin.x
            let offsetY = imageFrame.origin.y

            for stroke in strokes {
                var transform = CGAffineTransform(translationX: -offsetX, y: -offsetY)
                transform = transform.scaledBy(x: scaleX, y: scaleY)
                guard let cgPath = stroke.path.cgPath.copy(using: &transform) else { continue }

                let path = UIBezierPath(cgPath: cgPath)
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                let scaledLineWidth = stroke.lineWidth * ((scaleX + scaleY) / 2.0)
                path.lineWidth = scaledLineWidth
                stroke.color.setStroke()
                path.stroke()
            }
        }

        return (annotatedImage, true)
    }

    // MARK: - Helpers

    private func clamp(_ point: CGPoint) -> CGPoint {
        guard imageFrame.width > 0, imageFrame.height > 0 else { return point }

        let x = min(max(point.x, imageFrame.minX), imageFrame.maxX)
        let y = min(max(point.y, imageFrame.minY), imageFrame.maxY)
        return CGPoint(x: x, y: y)
    }
}
