import SwiftUI

/// Resim kırpma ve düzenleme ekranı
struct ImageCropView: View {
    // MARK: - Properties
    
    let originalImage: UIImage
    let onImageCropped: (UIImage) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    
    @State private var currentImage: UIImage
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    // Filtreler
    @State private var brightness: Double = 0
    @State private var contrast: Double = 1.0
    @State private var saturation: Double = 1.0
    @State private var showingFilters = false
    
    // OCR
    @State private var isProcessing = false
    @State private var showingOCRResult = false
    @State private var ocrText: String = ""
    
    // MARK: - Init
    
    init(image: UIImage, onImageCropped: @escaping (UIImage) -> Void) {
        self.originalImage = image
        self.onImageCropped = onImageCropped
        _currentImage = State(initialValue: image)
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
            .navigationTitle("Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                        .foregroundStyle(.white)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: saveAndClose) {
                        if isProcessing {
                            ProgressView()
                        } else {
                            Text("Kaydet")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundStyle(.white)
                    .disabled(isProcessing)
                }
            }
            .alert("OCR Sonucu", isPresented: $showingOCRResult) {
                Button("Tamam", role: .cancel) {}
                Button("Kopyala") {
                    UIPasteboard.general.string = ocrText
                }
            } message: {
                Text(ocrText.isEmpty ? "Metin bulunamadı" : ocrText)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Image Preview
    
    private var imagePreview: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                
                Image(uiImage: currentImage)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .rotationEffect(.degrees(rotation))
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / lastScale
                                lastScale = value
                                scale = max(0.5, min(scale * delta, 5.0))
                            }
                            .onEnded { _ in
                                lastScale = 1.0
                            }
                    )
                    .gesture(
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
                
                // Crop overlay
                Rectangle()
                    .stroke(Color.white.opacity(0.8), style: StrokeStyle(lineWidth: 2, dash: [10]))
                    .frame(
                        width: geometry.size.width * 0.85,
                        height: geometry.size.height * 0.85
                    )
                
                // Grid lines
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: geometry.size.height * 0.85 / 3)
                    Divider()
                        .background(Color.white.opacity(0.3))
                    Color.clear
                        .frame(height: geometry.size.height * 0.85 / 3)
                    Divider()
                        .background(Color.white.opacity(0.3))
                    Color.clear
                        .frame(height: geometry.size.height * 0.85 / 3)
                }
                .frame(width: geometry.size.width * 0.85)
                
                HStack(spacing: 0) {
                    Color.clear
                        .frame(width: geometry.size.width * 0.85 / 3)
                    Divider()
                        .background(Color.white.opacity(0.3))
                    Color.clear
                        .frame(width: geometry.size.width * 0.85 / 3)
                    Divider()
                        .background(Color.white.opacity(0.3))
                    Color.clear
                        .frame(width: geometry.size.width * 0.85 / 3)
                }
                .frame(height: geometry.size.height * 0.85)
            }
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
                title: "Döndür",
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
                title: "Sıfırla",
                isActive: false
            ) {
                resetImage()
            }
            
            Divider()
                .background(Color.white.opacity(0.3))
                .frame(height: 50)
            
            ToolButton(
                icon: "slider.horizontal.3",
                title: "Filtreler",
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
                title: "OCR",
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
            currentImage = originalImage
            showingFilters = false
        }
    }
    
    private func applyFilters() {
        guard let ciImage = CIImage(image: originalImage) else { return }
        
        let context = CIContext()
        let filter = CIFilter(name: "CIColorControls")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(brightness, forKey: kCIInputBrightnessKey)
        filter?.setValue(contrast, forKey: kCIInputContrastKey)
        filter?.setValue(saturation, forKey: kCIInputSaturationKey)
        
        if let outputImage = filter?.outputImage,
           let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
            currentImage = UIImage(cgImage: cgImage)
        }
    }
    
    private func performOCR() {
        isProcessing = true
        
        Task {
            do {
                let result = try await OCRService.shared.recognizeText(from: currentImage)
                await MainActor.run {
                    ocrText = result.cleanText
                    showingOCRResult = true
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    ocrText = "Hata: \(error.localizedDescription)"
                    showingOCRResult = true
                    isProcessing = false
                }
            }
        }
    }
    
    private func saveAndClose() {
        isProcessing = true
        
        // Rotasyonu uygula
        var finalImage = currentImage
        
        if rotation != 0 {
            finalImage = rotateImage(finalImage, degrees: rotation)
        }
        
        onImageCropped(finalImage)
        dismiss()
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
