import SwiftUI

/// Resim kırpma ve düzenleme ekranı
struct ImageCropView: View {
    // MARK: - Properties
    
    let originalImage: UIImage
    let onImageCropped: (UIImage) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    // Custom Crop Box
    @State private var cropRect: CGRect = .zero
    @State private var lastCropRect: CGRect = .zero
    @State private var isInitializing = true
    @State private var containerSize: CGSize = .zero
    
    // Filtreler
    @State private var brightness: Double = 0
    @State private var contrast: Double = 1.0
    @State private var saturation: Double = 1.0
    @State private var showingFilters = false
    
    // OCR
    @State private var isProcessing = false
    @State private var showingOCRResult = false
    @State private var ocrText: String = ""
    
    // Performance Optimization
    @State private var displayImage: UIImage? // Downsampled for UI performance
    private let context = CIContext(options: [.useSoftwareRenderer: false])
    
    // MARK: - Init
    
    init(image: UIImage, onImageCropped: @escaping (UIImage) -> Void) {
        self.originalImage = image
        self.onImageCropped = onImageCropped
        
        // Initial downsample for UI performance
        let targetSize = ImageCropView.calculatePreviewSize(for: image.size)
        let downsampled = ImageCropView.downsample(image, to: targetSize)
        _displayImage = State(initialValue: downsampled)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Preview area
                imagePreview
                
                // Filters (if visible)
                if showingFilters {
                    filterSliders
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Toolbar
                bottomToolbar
            }
            .background(Color.black)
            .navigationTitle(Text("common.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: saveAndClose) {
                        if isProcessing {
                            ProgressView()
                        } else {
                            Text("common.save")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundStyle(.white)
                    .disabled(isProcessing)
                }
            }
            .alert(Text("ocr.result"), isPresented: $showingOCRResult) {
                Button("common.ok", role: .cancel) {}
                Button("common.copy") {
                    UIPasteboard.general.string = ocrText
                }
            } message: {
                Text(ocrText.isEmpty ? String(localized: "ocr.noText") : ocrText)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Image Preview
    
    private var imagePreview: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Color.black
                
                // Image (Centered in background)
                if let display = displayImage {
                    Image(uiImage: display)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .rotationEffect(.degrees(rotation))
                        .offset(offset)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        .simultaneousGesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale = max(0.2, min(scale * delta, 10.0))
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                }
                        )
                        .simultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                }
                
                // Dimmed background overlay outside crop area
                Color.black.opacity(0.5)
                    .mask(
                        ZStack(alignment: .topLeading) {
                            Rectangle()
                            Rectangle()
                                .frame(width: cropRect.width, height: cropRect.height)
                                .offset(x: cropRect.origin.x, y: cropRect.origin.y)
                                .blendMode(.destinationOut)
                        }
                    )
                    .allowsHitTesting(false)
                
                // Resizable Crop Box (Stroke, Grid, Handles)
                ZStack(alignment: .topLeading) {
                    // Grid lines inside box
                    gridLines
                    
                    // Box Border
                    Rectangle()
                        .stroke(Color.white, lineWidth: 2)
                    
                    // Interactive Handles
                    cropHandles
                }
                .frame(width: cropRect.width, height: cropRect.height)
                .offset(x: cropRect.origin.x, y: cropRect.origin.y)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            cropRect.origin.x = lastCropRect.origin.x + value.translation.width
                            cropRect.origin.y = lastCropRect.origin.y + value.translation.height
                            limitCropRect(in: geometry.size)
                        }
                        .onEnded { _ in
                            lastCropRect = cropRect
                        }
                )
            }
            .onAppear {
                isProcessing = false
                updateInitialization(with: geometry.size)
            }
            .onChange(of: geometry.size) { _, newSize in
                updateInitialization(with: newSize)
            }
        }
    }
    
    private func updateInitialization(with size: CGSize) {
        guard size.width > 0 && size.height > 0 else { return }
        containerSize = size
        
        if isInitializing {
            // Initialize crop box to 9:16 aspect ratio
            let targetRatio: CGFloat = 9.0 / 16.0
            let availableW = size.width * 0.85
            let availableH = size.height * 0.85
            
            var w = availableW
            var h = w / targetRatio
            
            if h > availableH {
                h = availableH
                w = h * targetRatio
            }
            
            // Center the box in container coordinates
            let x = (size.width - w) / 2
            let y = (size.height - h) / 2
            
            cropRect = CGRect(x: x, y: y, width: w, height: h)
            lastCropRect = cropRect
            isInitializing = false
        }
    }
    
    // MARK: - Filter Sliders
    
    private var filterSliders: some View {
        VStack(spacing: 16) {
            // Brightness
            HStack {
                Image(systemName: "sun.min")
                    .foregroundStyle(.white)
                    .frame(width: 30)
                Slider(value: $brightness, in: -0.5...0.5)
                    .tint(.white)
                    .onChange(of: brightness) { _, _ in applyFilters() }
                Image(systemName: "sun.max")
                    .foregroundStyle(.white)
                    .frame(width: 30)
            }
            
            // Contrast
            HStack {
                Image(systemName: "circle.lefthalf.filled")
                    .foregroundStyle(.white)
                    .frame(width: 30)
                Slider(value: $contrast, in: 0.5...1.5)
                    .tint(.white)
                    .onChange(of: contrast) { _, _ in applyFilters() }
                Image(systemName: "circle.righthalf.filled")
                    .foregroundStyle(.white)
                    .frame(width: 30)
            }
            
            // Saturation
            HStack {
                Image(systemName: "paintpalette")
                    .foregroundStyle(.white)
                    .frame(width: 30)
                Slider(value: $saturation, in: 0...2)
                    .tint(.white)
                    .onChange(of: saturation) { _, _ in applyFilters() }
                Image(systemName: "paintpalette.fill")
                    .foregroundStyle(.white)
                    .frame(width: 30)
            }
        }
        .padding()
        .background(Color.black.opacity(0.8))
    }
    
    // MARK: - Bottom Toolbar
    
    private var bottomToolbar: some View {
        HStack(spacing: 0) {
            ToolButton(
                icon: "rotate.right",
                title: String(localized: "image.rotate"),
                isActive: false
            ) {
                withAnimation(.spring(response: 0.3)) {
                    rotation += 90
                    if rotation >= 360 { rotation = 0 }
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.3))
                .frame(height: 50)
            
            ToolButton(
                icon: "arrow.counterclockwise",
                title: String(localized: "image.reset"),
                isActive: false
            ) {
                resetImage()
            }
            
            Divider()
                .background(Color.white.opacity(0.3))
                .frame(height: 50)
            
            ToolButton(
                icon: "slider.horizontal.3",
                title: String(localized: "all.filter.title"),
                isActive: showingFilters
            ) {
                withAnimation(.spring(response: 0.3)) {
                    showingFilters.toggle()
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.3))
                .frame(height: 50)
            
            ToolButton(
                icon: "doc.text.viewfinder",
                title: String(localized: "ocr.title"),
                isActive: false
            ) {
                performOCR()
            }
        }
        .frame(height: 80)
        .background(Color.black)
    }
    
    // MARK: - Actions
    
    private func resetImage() {
        withAnimation(.spring(response: 0.3)) {
            rotation = 0
            scale = 1.0
            lastScale = 1.0
            offset = .zero
            lastOffset = .zero
            brightness = 0
            contrast = 1.0
            saturation = 1.0
            
            // Re-downsample original
            let targetSize = ImageCropView.calculatePreviewSize(for: originalImage.size)
            displayImage = ImageCropView.downsample(originalImage, to: targetSize)
            
            showingFilters = false
        }
    }
    
    private func applyFilters() {
        // Preview üzerinde hızlı filtre uygula
        guard let sourceImage = displayImage,
              let ciImage = CIImage(image: sourceImage) else { return }
        
        let filter = CIFilter(name: "CIColorControls")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(brightness, forKey: kCIInputBrightnessKey)
        filter?.setValue(contrast, forKey: kCIInputContrastKey)
        filter?.setValue(saturation, forKey: kCIInputSaturationKey)
        
        if let outputImage = filter?.outputImage,
           let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
            displayImage = UIImage(cgImage: cgImage)
        }
    }
    
    // Helper to calculate preview size (max 1080p for performance)
    private static func calculatePreviewSize(for size: CGSize) -> CGSize {
        let maxDimension: CGFloat = 1200.0
        if size.width <= maxDimension && size.height <= maxDimension { return size }
        let ratio = size.width / size.height
        if size.width > size.height {
            return CGSize(width: maxDimension, height: maxDimension / ratio)
        } else {
            return CGSize(width: maxDimension * ratio, height: maxDimension)
        }
    }
    
    private static func downsample(_ image: UIImage, to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    private func performOCR() {
        isProcessing = true
        
        Task {
            // Apply final crop/filter/rotate for OCR
            guard let processed = processFinalImage() else {
                isProcessing = false
                return
            }
            
            do {
                let result = try await OCRService.shared.recognizeText(from: processed)
                await MainActor.run {
                    ocrText = result.cleanText
                    showingOCRResult = true
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    let errorPrefix = String(localized: "common.error")
                    ocrText = "\(errorPrefix): \(error.localizedDescription)"
                    showingOCRResult = true
                    isProcessing = false
                }
            }
        }
    }
    
    private func saveAndClose() {
        isProcessing = true
        
        if let finalImage = processFinalImage() {
            onImageCropped(finalImage)
            dismiss()
        } else {
            isProcessing = false
        }
    }
    
    private func processFinalImage() -> UIImage? {
        // 1. Orijinal resmi döndür
        var imageToProcess = originalImage
        if rotation != 0 {
            imageToProcess = rotateImage(imageToProcess, degrees: rotation)
        }
        
        // 2. Filtreleri uygula
        if brightness != 0 || contrast != 1.0 || saturation != 1.0 {
            if let ciImage = CIImage(image: imageToProcess) {
                let filter = CIFilter(name: "CIColorControls")
                filter?.setValue(ciImage, forKey: kCIInputImageKey)
                filter?.setValue(brightness, forKey: kCIInputBrightnessKey)
                filter?.setValue(contrast, forKey: kCIInputContrastKey)
                filter?.setValue(saturation, forKey: kCIInputSaturationKey)
                
                if let outputImage = filter?.outputImage,
                   let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
                    imageToProcess = UIImage(cgImage: cgImage)
                }
            }
        }
        
        // 3. Kırpma işlemini uygula
        // Mapping from UI coordinates (scale/offset/cropRect) to Image coordinates
        return cropImage(imageToProcess)
    }
    
    private func cropImage(_ image: UIImage) -> UIImage {
        guard containerSize.width > 0 && containerSize.height > 0 else { return image }
        
        let imageSize = image.size
        let aspectWidth = containerSize.width / imageSize.width
        let aspectHeight = containerSize.height / imageSize.height
        let aspect = min(aspectWidth, aspectHeight)
        
        // Convert cropRect (top-left relative to container) to center-offset relative to image
        // Screen center is (0,0) for image offset and crop points.
        let containerCenterX = containerSize.width / 2
        let containerCenterY = containerSize.height / 2
        
        // Distance from screen center to box center
        let offX = cropRect.midX - containerCenterX
        let offY = cropRect.midY - containerCenterY
        
        // Box relative to image center (in screen pixels)
        let dx = offX - offset.width
        let dy = offY - offset.height
        
        // Box size in screen pixels
        let bw = cropRect.width
        let bh = cropRect.height
        
        // Convert to unscaled display pixels
        let relX = dx / scale
        let relY = dy / scale
        let relW = bw / scale
        let relH = bh / scale
        
        // Convert to original image pixels
        // (0,0) in unscaled display coords maps to (imageSize.width/2, imageSize.height/2) in image coords
        let imageX = (imageSize.width / 2) + (relX / aspect) - (relW / aspect / 2)
        let imageY = (imageSize.height / 2) + (relY / aspect) - (relH / aspect / 2)
        let imageW = relW / aspect
        let imageH = relH / aspect
        
        // Clamp to image bounds
        let finalX = max(0, min(imageX, imageSize.width - 10))
        let finalY = max(0, min(imageY, imageSize.height - 10))
        let finalW = max(10, min(imageW, imageSize.width - finalX))
        let finalH = max(10, min(imageH, imageSize.height - finalY))
        
        let cropZone = CGRect(x: finalX, y: finalY, width: finalW, height: finalH)
        
        guard let cgImage = image.cgImage?.cropping(to: cropZone) else {
            return image
        }
        
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
    
    private func rotateImage(_ image: UIImage, degrees: Double) -> UIImage {
        let radians = degrees * .pi / 180
        var newSize = CGRect(origin: .zero, size: image.size)
            .applying(CGAffineTransform(rotationAngle: radians))
            .size
        
        newSize.width = abs(newSize.width)
        newSize.height = abs(newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else { return image }
        
        context.translateBy(x: newSize.width / 2, y: newSize.height / 2)
        context.rotate(by: radians)
        image.draw(in: CGRect(
            x: -image.size.width / 2,
            y: -image.size.height / 2,
            width: image.size.width,
            height: image.size.height
        ))
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
    
    // MARK: - Crop Helpers
    
    private var cropHandles: some View {
        ZStack(alignment: .topLeading) {
            ForEach([HandlePosition.topLeading, .topTrailing, .bottomLeading, .bottomTrailing, .top, .bottom, .leading, .trailing], id: \.self) { pos in
                handleView(at: pos)
            }
        }
        .frame(width: cropRect.width, height: cropRect.height)
    }
    
    private func handleView(at position: HandlePosition) -> some View {
        let size: CGFloat = 44 // Larger hit target
        let visibleSize: CGFloat = 36
        let isEdge = position.isEdge
        let isHorizontal = position.isHorizontal
        
        return ZStack {
            if isEdge {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white)
                    .frame(width: isHorizontal ? 24 : 6,
                           height: isHorizontal ? 6 : 24)
                    .overlay(RoundedRectangle(cornerRadius: 1).stroke(Color.black.opacity(0.3), lineWidth: 0.5))
            } else {
                Circle()
                    .fill(Color.white)
                    .frame(width: visibleSize/1.5, height: visibleSize/1.5)
                    .overlay(Circle().stroke(Color.black.opacity(0.3), lineWidth: 1))
            }
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .position(position.point(for: cropRect))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    resizeCropRect(with: value.translation, at: position)
                }
                .onEnded { _ in
                    lastCropRect = cropRect
                }
        )
    }
    
    private var gridLines: some View {
        ZStack {
            // Vertical lines
            HStack(spacing: 0) {
                Spacer()
                Divider().background(Color.white.opacity(0.3)).frame(width: 1)
                Spacer()
                Divider().background(Color.white.opacity(0.3)).frame(width: 1)
                Spacer()
            }
            // Horizontal lines
            VStack(spacing: 0) {
                Spacer()
                Divider().background(Color.white.opacity(0.3)).frame(height: 1)
                Spacer()
                Divider().background(Color.white.opacity(0.3)).frame(height: 1)
                Spacer()
            }
        }
        .allowsHitTesting(false)
    }
    
    private func resizeCropRect(with translation: CGSize, at position: HandlePosition) {
        var newRect = lastCropRect
        let minSize: CGFloat = 60
        
        switch position {
        case .topLeading:
            newRect.origin.x = lastCropRect.origin.x + translation.width
            newRect.origin.y = lastCropRect.origin.y + translation.height
            newRect.size.width = lastCropRect.width - translation.width
            newRect.size.height = lastCropRect.height - translation.height
        case .topTrailing:
            newRect.origin.y = lastCropRect.origin.y + translation.height
            newRect.size.width = lastCropRect.width + translation.width
            newRect.size.height = lastCropRect.height - translation.height
        case .bottomLeading:
            newRect.origin.x = lastCropRect.origin.x + translation.width
            newRect.size.width = lastCropRect.width - translation.width
            newRect.size.height = lastCropRect.height + translation.height
        case .bottomTrailing:
            newRect.size.width = lastCropRect.width + translation.width
            newRect.size.height = lastCropRect.height + translation.height
        case .top:
            newRect.origin.y = lastCropRect.origin.y + translation.height
            newRect.size.height = lastCropRect.height - translation.height
        case .bottom:
            newRect.size.height = lastCropRect.height + translation.height
        case .leading:
            newRect.origin.x = lastCropRect.origin.x + translation.width
            newRect.size.width = lastCropRect.width - translation.width
        case .trailing:
            newRect.size.width = lastCropRect.width + translation.width
        }
        
        // Constraints
        if newRect.width >= minSize && newRect.height >= minSize {
            cropRect = newRect
        }
    }
    
    private func limitCropRect(in containerSize: CGSize) {
        // Standard bounds check for top-left origin
        cropRect.origin.x = max(0, min(cropRect.origin.x, containerSize.width - cropRect.width))
        cropRect.origin.y = max(0, min(cropRect.origin.y, containerSize.height - cropRect.height))
    }
    
    enum HandlePosition {
        case topLeading, topTrailing, bottomLeading, bottomTrailing
        case top, bottom, leading, trailing
        
        var isEdge: Bool {
            switch self {
            case .top, .bottom, .leading, .trailing: return true
            default: return false
            }
        }
        
        var isHorizontal: Bool {
            switch self {
            case .top, .bottom: return true
            default: return false
            }
        }
        
        func point(for rect: CGRect) -> CGPoint {
            switch self {
            case .topLeading: return CGPoint(x: 0, y: 0)
            case .topTrailing: return CGPoint(x: rect.width, y: 0)
            case .bottomLeading: return CGPoint(x: 0, y: rect.height)
            case .bottomTrailing: return CGPoint(x: rect.width, y: rect.height)
            case .top: return CGPoint(x: rect.width / 2, y: 0)
            case .bottom: return CGPoint(x: rect.width / 2, y: rect.height)
            case .leading: return CGPoint(x: 0, y: rect.height / 2)
            case .trailing: return CGPoint(x: rect.width, y: rect.height / 2)
            }
        }
    }
}

// MARK: - Tool Button

struct ToolButton: View {
    let icon: String
    let title: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(isActive ? .blue : .white)
        }
    }
}

// MARK: - Preview

#Preview {
    ImageCropView(image: UIImage(systemName: "photo.fill")!) { _ in }
}
