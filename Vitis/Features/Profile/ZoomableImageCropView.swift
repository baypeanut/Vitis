//
//  ZoomableImageCropView.swift
//  Vitis
//
//  UIKit zoom/pan crop. Aspect-fill so image overflows → always scrollable. Output: JPEG for avatar.
//

import SwiftUI
import UIKit

struct ZoomableImageCropView: UIViewRepresentable {
    let image: UIImage
    @Binding var triggerCrop: Bool
    var onCropped: (Data) -> Void

    private let size: CGFloat = 280

    func makeUIView(context: Context) -> UIScrollView {
        let sv = UIScrollView()
        sv.delegate = context.coordinator
        sv.minimumZoomScale = 1
        sv.maximumZoomScale = 4
        sv.showsHorizontalScrollIndicator = false
        sv.showsVerticalScrollIndicator = false
        sv.bouncesZoom = true
        sv.bounces = true
        sv.backgroundColor = .clear
        sv.isScrollEnabled = true
        sv.delaysContentTouches = false
        sv.alwaysBounceVertical = true
        sv.alwaysBounceHorizontal = true
        sv.pinchGestureRecognizer?.isEnabled = true
        sv.panGestureRecognizer.isEnabled = true

        let container = UIView()
        container.backgroundColor = .clear
        let iv = UIImageView(image: image)
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.isUserInteractionEnabled = false
        container.addSubview(iv)
        sv.addSubview(container)
        context.coordinator.imageView = iv
        context.coordinator.containerView = container
        context.coordinator.scrollView = sv
        context.coordinator.applyLayout(image: image, fillSize: fillSize(for: image, cropSize: CGSize(width: size, height: size)))
        return sv
    }

    func updateUIView(_ sv: UIScrollView, context: Context) {
        if triggerCrop {
            performCrop(coordinator: context.coordinator)
            DispatchQueue.main.async { triggerCrop = false }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(size: size)
    }

    private func performCrop(coordinator: Coordinator) {
        guard let sv = coordinator.scrollView,
              let iv = coordinator.imageView,
              let im = iv.image else { return }
        let data = coordinator.cropToAvatarData(scrollView: sv, imageView: iv, image: im)
        if let data { onCropped(data) }
    }

    /// Aspect-fill + overflow both axes. Scale so image fills crop; then 1.5x so both dimensions exceed crop → scroll + zoom in all directions.
    private func fillSize(for image: UIImage, cropSize: CGSize) -> CGSize {
        let iw = image.size.width
        let ih = image.size.height
        guard iw > 0, ih > 0 else { return cropSize }
        let base = max(cropSize.width / iw, cropSize.height / ih)
        let scale = base * 1.5
        return CGSize(width: iw * scale, height: ih * scale)
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        let size: CGFloat
        weak var scrollView: UIScrollView?
        weak var imageView: UIImageView?
        weak var containerView: UIView?
        var lastFillSize: CGSize = .zero

        init(size: CGFloat) {
            self.size = size
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            containerView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard let c = containerView else { return }
            let f = lastFillSize
            let z = scrollView.zoomScale
            scrollView.contentSize = CGSize(width: f.width * z, height: f.height * z)
        }

        func applyLayout(image: UIImage, fillSize fill: CGSize) {
            guard let iv = imageView, let c = containerView, let sv = scrollView else { return }
            iv.image = image
            c.frame = CGRect(origin: .zero, size: fill)
            iv.frame = c.bounds
            sv.contentSize = fill
            sv.zoomScale = 1
            let ox = max(0, (fill.width - sv.bounds.width) / 2)
            let oy = max(0, (fill.height - sv.bounds.height) / 2)
            sv.contentOffset = CGPoint(x: ox, y: oy)
            lastFillSize = fill
        }

        func cropToAvatarData(scrollView sv: UIScrollView, imageView iv: UIImageView, image im: UIImage) -> Data? {
            let fill = lastFillSize
            let iw = im.size.width
            let ih = im.size.height
            guard iw > 0, ih > 0, fill.width > 0, fill.height > 0 else { return nil }
            let scale = max(fill.width / iw, fill.height / ih)
            let displayW = iw * scale
            let displayH = ih * scale
            let offset = CGPoint(
                x: (fill.width - displayW) / 2,
                y: (fill.height - displayH) / 2
            )
            let z = sv.zoomScale
            let visW = sv.bounds.width / z
            let visH = sv.bounds.height / z
            let visX = sv.contentOffset.x / z
            let visY = sv.contentOffset.y / z
            let ox = (visX - offset.x) / scale
            let oy = (visY - offset.y) / scale
            let cropW = visW / scale
            let cropH = visH / scale
            var r = CGRect(x: max(0, ox), y: max(0, oy), width: cropW, height: cropH)
            if r.maxX > iw { r.size.width = iw - r.origin.x }
            if r.maxY > ih { r.size.height = ih - r.origin.y }
            if r.width <= 0 || r.height <= 0 { return nil }
            let side = min(r.width, r.height)
            let cx = r.midX - side / 2
            let cy = r.midY - side / 2
            var sq = CGRect(x: max(0, cx), y: max(0, cy), width: side, height: side)
            if sq.maxX > iw { sq.origin.x = max(0, iw - side); sq.size.width = min(side, iw - sq.origin.x) }
            if sq.maxY > ih { sq.origin.y = max(0, ih - side); sq.size.height = min(side, ih - sq.origin.y) }
            let scalePx = im.scale
            let sqPx = CGRect(x: sq.origin.x * scalePx, y: sq.origin.y * scalePx, width: sq.width * scalePx, height: sq.height * scalePx)
            guard let cg = im.cgImage?.cropping(to: sqPx) else { return nil }
            let cropped = UIImage(cgImage: cg, scale: 1, orientation: im.imageOrientation)
            let resized = resizeForAvatar(cropped, maxSide: 512)
            return resized.jpegData(compressionQuality: 0.85)
        }

        private func resizeForAvatar(_ img: UIImage, maxSide: CGFloat) -> UIImage {
            let w = img.size.width
            let h = img.size.height
            let m = max(w, h)
            guard m > maxSide else { return img }
            let scale = maxSide / m
            let nw = w * scale
            let nh = h * scale
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: nw, height: nh), format: format)
            return renderer.image { _ in img.draw(in: CGRect(origin: .zero, size: CGSize(width: nw, height: nh))) }
        }
    }
}
