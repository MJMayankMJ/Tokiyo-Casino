//
//  JKConfettiView.swift
//  Tokiyo Casino — Jackaroo (Phase 6)
//
//  Brass-spark celebration emitter for a win (JACKAROO_DESIGN §6).
//  A short CAEmitterLayer burst, then it fades and removes itself.
//

import UIKit

final class JKConfettiView: UIView {
    private let emitter = CAEmitterLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        layer.addSublayer(emitter)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: -12)
        emitter.emitterSize = CGSize(width: bounds.width, height: 1)
        emitter.emitterShape = .line
    }

    /// Emit for `duration` seconds, then fade out and remove from the
    /// superview. `completion` fires when the burst window ends (not the
    /// fade), so the caller can sequence the summary modal.
    func burst(duration: TimeInterval = 1.5, completion: (() -> Void)? = nil) {
        let colors: [UIColor] = [
            UIColor(hex: 0xE8C170), UIColor(hex: 0xC9962F),
            UIColor(hex: 0xFFE6A8), UIColor(hex: 0xF2F2F2),
        ]
        emitter.emitterCells = colors.map { makeCell(color: $0) }
        emitter.birthRate = 1

        // Stop spawning after the window, then fade what's left.
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.emitter.birthRate = 0
            completion?()
            UIView.animate(withDuration: 0.6, animations: { self?.alpha = 0 }) { _ in
                self?.removeFromSuperview()
            }
        }
    }

    private func makeCell(color: UIColor) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.birthRate = 6
        cell.lifetime = 4.5
        cell.velocity = 220
        cell.velocityRange = 90
        cell.emissionLongitude = .pi          // downward
        cell.emissionRange = .pi / 6
        cell.spin = 3.2
        cell.spinRange = 4.0
        cell.scale = 0.5
        cell.scaleRange = 0.3
        cell.color = color.cgColor
        cell.contents = JKConfettiView.sparkImage.cgImage
        return cell
    }

    /// A tiny rounded rectangle used as the spark texture.
    private static let sparkImage: UIImage = {
        let size = CGSize(width: 8, height: 12)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.white.setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 2).fill()
        }
    }()
}
