//
//  EggCell.swift
//  Spin Royale
//
//  Created by Mayank Jangid on 3/26/25.
//

//import UIKit
//
//enum CellState {
//    case normal  
//    case diamond
//    case mine
//}
//
//class Cell: UICollectionViewCell {
//    
//    // MARK: - Outlets (connect these in your Cell.xib)
//    @IBOutlet weak var tileImageView: UIImageView!
//    @IBOutlet weak var centerImageView: UIImageView!
//    
//    // MARK: - Lifecycle
//    override func awakeFromNib() {
//        super.awakeFromNib()
//        configureCell(state: .normal)
//        
//        // subtle shadow for better visual depth
//        layer.shadowColor = UIColor.black.cgColor
//        layer.shadowOffset = CGSize(width: 0, height: 2)
//        layer.shadowRadius = 3
//        layer.shadowOpacity = 0.1
//        layer.masksToBounds = false
////        
////        // Rounded corners
////        layer.cornerRadius = 8
//    }
//    
//    override func prepareForReuse() {
//        super.prepareForReuse()
//        // Reset any animations or transformations
//        transform = .identity
//        alpha = 1.0
//    }
//    
//    // MARK: - Configuration
//    func configureCell(state: CellState) {
//        switch state {
//        case .normal:
//            tileImageView.image = UIImage(named: K.lightTile)
//            centerImageView.isHidden = true
//            backgroundColor = UIColor.systemGray5
//            
//        case .diamond:
//            tileImageView.image = UIImage(named: K.darkTile)
//            centerImageView.isHidden = false
//            centerImageView.image = UIImage(named: K.diamondPNG)
//            backgroundColor = UIColor.systemGreen.withAlphaComponent(0.3)
//            
//            // Add a subtle scale animation for discovered diamonds
//            UIView.animate(withDuration: 0.2, animations: {
//                self.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
//            }) { _ in
//                UIView.animate(withDuration: 0.1) {
//                    self.transform = .identity
//                }
//            }
//            
//        case .mine:
//            tileImageView.image = UIImage(named: K.darkTile)
//            centerImageView.isHidden = false
//            centerImageView.image = UIImage(named: K.bombPNG)
//            backgroundColor = UIColor.systemRed.withAlphaComponent(0.3)
//            
//            // shake animation for mines
//            let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
//            animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
//            animation.duration = 0.6
//            animation.values = [-10.0, 10.0, -8.0, 8.0, -6.0, 6.0, -4.0, 4.0, 0.0]
//            layer.add(animation, forKey: "shake")
//        }
//    }
//}

import UIKit

// MARK: – CellState & Cell

enum CellState {
    case normal   // un‐tapped (light tile)
    case diamond  // tapped, turned out to be a diamond (dark tile + diamond image)
    case mine     // tapped, turned out to be a mine  (dark tile + bomb image)
}

/// A single grid cell (6×4 board).
/// In Storyboard, this should be a UICollectionViewCell subclass
/// with a xib/nib (e.g. “Cell.xib”) that has:
///   • tileImageView (UIImageView)
///   • centerImageView (UIImageView)
///
/// The images named in `K.*` are assumed to exist in Assets:
///   • K.lightTile, K.darkTile
///   • K.diamondPNG, K.bombPNG
class Cell: UICollectionViewCell {
    @IBOutlet weak var tileImageView: UIImageView!
    @IBOutlet weak var centerImageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        configureCell(state: .normal)
        
        // subtle drop shadow for depth
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 3
        layer.shadowOpacity = 0.1
        layer.masksToBounds = false
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        transform = .identity
        alpha = 1.0
    }
    
    func configureCell(state: CellState) {
        switch state {
        case .normal:
            tileImageView.image = UIImage(named: K.lightTile)
            centerImageView.isHidden = true
            backgroundColor = UIColor.systemGray5
            
        case .diamond:
            tileImageView.image = UIImage(named: K.darkTile)
            centerImageView.isHidden = false
            centerImageView.image = UIImage(named: K.diamondPNG)
            backgroundColor = UIColor.systemGreen.withAlphaComponent(0.3)
            
            // small pop animation
            UIView.animate(withDuration: 0.2, animations: {
                self.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
            }) { _ in
                UIView.animate(withDuration: 0.1) {
                    self.transform = .identity
                }
            }
            
        case .mine:
            tileImageView.image = UIImage(named: K.darkTile)
            centerImageView.isHidden = false
            centerImageView.image = UIImage(named: K.bombPNG)
            backgroundColor = UIColor.systemRed.withAlphaComponent(0.3)
            
            // shake animation
            let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
            animation.timingFunction = CAMediaTimingFunction(name: .linear)
            animation.duration = 0.6
            animation.values = [-10.0, 10.0, -8.0, 8.0, -6.0, 6.0, -4.0, 4.0, 0.0]
            layer.add(animation, forKey: "shake")
        }
    }
}

