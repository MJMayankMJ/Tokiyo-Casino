import UIKit

/// Add entries here; home flows them into one or two columns, with more rows
/// as the library grows. Routing and preview type travel with the entry.
struct HomeGameItem {
    let id: String
    let title: String
    let subtitle: String
    let detail: String
    let symbol: String
    let imageName: String
    let preview: HomeCardPreview.Kind
    let makeViewController: () -> UIViewController

    static let catalog: [HomeGameItem] = [
        .init(id: "home.poker", title: "Poker", subtitle: "Texas Hold’em",
              detail: "Read the room.\nPlay your hand.", symbol: "suit.spade.fill", imageName: "HomePokerGirl",
              preview: .royalFlush, makeViewController: { MenuViewController() }),
        .init(id: "home.532", title: "5 · 3 · 2", subtitle: "Teen Do Paanch",
              detail: "Three players.\nEvery trick counts.", symbol: "suit.club.fill", imageName: "HomeMarin",
              preview: .firstCut, makeViewController: { TDPEntryViewController() })
    ]
}
