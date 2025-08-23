//
//  255, alpha: 1).cgColor     } } CustomShapeView.swift
//  Tokiyo Casino
//
//  Created by Mayank Jangid on 5/29/25.
//

import UIKit

@IBDesignable
class CustomShapeView: UIView {
    
    @IBInspectable var slant: CGFloat = 30 {
        didSet { setNeedsLayout() }
    }

    @IBInspectable var cornerRadius: CGFloat = 20 {
        didSet { setNeedsLayout() }
    }

    @IBInspectable var fillColor: UIColor = UIColor(red: 49/255, green: 30/255, blue: 28/255, alpha: 1) {
        didSet { setNeedsLayout() }
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyCustomShape()
    }

    private func applyCustomShape() {
        let path = UIBezierPath()
        let width = bounds.width
        let height = bounds.height
        let π = CGFloat.pi

        path.move(to: CGPoint(x: slant, y: 0))
        path.addLine(to: CGPoint(x: width - cornerRadius, y: 0))
        path.addArc(withCenter: CGPoint(x: width - cornerRadius, y: cornerRadius),
                    radius: cornerRadius,
                    startAngle: -π / 2,
                    endAngle: 0,
                    clockwise: true)

        path.addLine(to: CGPoint(x: width, y: height - cornerRadius))
        path.addArc(withCenter: CGPoint(x: width - cornerRadius, y: height - cornerRadius),
                    radius: cornerRadius,
                    startAngle: 0,
                    endAngle: π / 2,
                    clockwise: true)

        path.addLine(to: CGPoint(x: 0, y: height))
        path.addLine(to: CGPoint(x: slant, y: 0))
        path.close()

        // Shape mask
        let mask = CAShapeLayer()
        mask.path = path.cgPath
        layer.mask = mask

        // Fill color layer (backgroundColor doesn't work with masks in Interface Builder)
        let fillLayer = CAShapeLayer()
        fillLayer.path = path.cgPath
        fillLayer.fillColor = fillColor.cgColor

        // Remove old fill layers to avoid duplication
        layer.sublayers?.removeAll(where: { $0.name == "FillLayer" })
        fillLayer.name = "FillLayer"
        layer.insertSublayer(fillLayer, at: 0)
    }
}
