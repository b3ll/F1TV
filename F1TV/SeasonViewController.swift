//
//  SeasonViewController.swift
//  F1TV
//
//  Created by Adam Bell on 9/28/20.
//

import SDWebImage
import SwiftUI
import UIKit
import TVUIKit

fileprivate let EventCellIdentifier = "EventCellIdentifier"

class SeasonViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    let partialSeason: SeasonsResponse.Season
    private(set) var season: Season? {
        didSet {
            collectionView.reloadData()
        }
    }

    let collectionViewLayout = { () -> UICollectionViewLayout in
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 548.0, height: 548.0 * (9.0 / 16.0))
        layout.minimumInteritemSpacing = 48.0
        layout.minimumLineSpacing = 100.0
        return layout
    }()
    var collectionView: UICollectionView!

    init(partialSeason: SeasonsResponse.Season) {
        self.partialSeason = partialSeason
        super.init(nibName: nil, bundle: nil)

        self.tabBarItem = UITabBarItem(title: "\(partialSeason.year)", image: nil, tag: partialSeason.year)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: collectionViewLayout)
        collectionView.dataSource = self
        collectionView.delegate = self
        self.view = collectionView

        collectionView.register(EventCell.self, forCellWithReuseIdentifier: EventCellIdentifier)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        loadSeason()
    }

    private func loadSeason() {
        F1TV.shared.getSeason(partialSeason.URL) { [weak self] season in
            self?.season = season
        }
    }

    // MARK: - UICollectionViewDataSource

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return season?.events.count ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: EventCellIdentifier, for: indexPath) as! EventCell

        cell.event = season?.events[indexPath.item]
        cell.parentViewController = self

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 40.0, left: 80.0, bottom: 40.0, right: 80.0)
    }

    func collectionView(_ collectionView: UICollectionView, canFocusItemAt indexPath: IndexPath) -> Bool {
        return true
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let eventViewController = EventViewController(partialEvent: season!.events[indexPath.item])
        navigationController?.pushViewController(eventViewController, animated: true)
    }

}

class EventCell: UICollectionViewCell {

    var event: Event? {
        didSet {
            updateEvent()
        }
    }

    private let titleLabel: UILabel
    private let backgroundImageView: UIImageView

    private var hostingViewController: UIHostingController<EventTitleBar>!

    weak var parentViewController: UIViewController? = nil {
        didSet {
            mountSwiftUIViewsIfNeeded()
        }
    }

    override init(frame: CGRect) {
        self.titleLabel = UILabel()
        self.backgroundImageView = UIImageView()
        super.init(frame: frame)

        contentView.addSubview(backgroundImageView)
//        contentView.addSubview(titleLabel)

        contentView.clipsToBounds = false
        self.clipsToBounds = false

        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.adjustsImageWhenAncestorFocused = true

        titleLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        titleLabel.textAlignment = .center
    }

    private func updateEvent() {
        backgroundImageView.sd_setImage(with: event?.imageURLs.first?.URL, placeholderImage: UIImage.placeholder, completed: nil)
        backgroundImageView.sd_imageTransition = .fade

        titleLabel.text = event?.name

        updateFocusedElements()

        mountSwiftUIViewsIfNeeded()

        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        backgroundImageView.frame = bounds

        if let hostingViewController = hostingViewController {
            let hostingViewControllerSize = hostingViewController.sizeThatFits(in: bounds.size)

            let imageFrame: CGRect
            if isFocused {
                var frame = backgroundImageView.focusedFrameGuide.layoutFrame
                frame.origin.x = ceil(frame.origin.x)
                frame.origin.y = ceil(frame.origin.y)
                frame.size.width = ceil(frame.size.width)
                frame.size.height = ceil(frame.size.height)
                imageFrame = frame
            } else {
                imageFrame = backgroundImageView.bounds
            }
            hostingViewController.view.frame = CGRect(x: imageFrame.origin.x, y: imageFrame.size.height - hostingViewControllerSize.height + imageFrame.origin.y, width: imageFrame.size.width, height: hostingViewControllerSize.height)
            backgroundImageView.bringSubviewToFront(hostingViewController.view)
        }
    }

    // MARK: - SwiftUI Support

    private func mountSwiftUIViewsIfNeeded() {
        guard let parentViewController = parentViewController, let event = event else {
            hostingViewController?.removeFromParent()
            hostingViewController?.view.removeFromSuperview()
            hostingViewController = nil
            return
        }

        let hostingViewController = self.hostingViewController ?? UIHostingController<EventTitleBar>(rootView: EventTitleBar())
        self.hostingViewController = hostingViewController

        if hostingViewController.parent != parentViewController {
            hostingViewController.willMove(toParent: parentViewController)
            parentViewController.addChild(hostingViewController)
            backgroundImageView.addSubview(hostingViewController.view)
        }

        // Gotta use the 2 character code.
        SDWebImageManager.shared.loadImage(with: event.nation?.imageURLs.first?.URL, options: [], progress: nil) { [weak self, weak hostingViewController] (image, _, _, _, _, _) in
            let titleBar = EventTitleBar(flagImage: image ?? UIImage(), title: event.name, subtitle: "")
            if titleBar != hostingViewController?.rootView {
                hostingViewController?.rootView = titleBar
            }

            self?.setNeedsLayout()
        }
    }

    // MARK: - Focus

    override var canBecomeFocused: Bool {
        return true
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)

        coordinator.addCoordinatedAnimations {
            self.updateFocusedElements()
        } completion: {
            //
        }
    }

    private func updateFocusedElements() {
        titleLabel.alpha = isFocused ? 1.0 : 0.0

        if let hostingViewController = hostingViewController {
            // Weird bug where sometimes the hosting view goes to the back? This fixes it I guess...

            let _ = hostingViewController.sizeThatFits(in: bounds.size)
            setNeedsLayout()
            layoutIfNeeded()
            backgroundImageView.bringSubviewToFront(hostingViewController.view)
        }
    }

}

struct SeasonCell_: UIViewRepresentable {

    let event: Event

    func makeUIView(context: Context) -> EventCell {
        let cell = EventCell(frame: .zero)
        cell.event = event
        return cell
    }

    func updateUIView(_ uiView: EventCell, context: Context) {

    }

}
//
//struct SeasonCell_Previews: PreviewProvider {
//
//    static var previews: some View {
//        let event = Event(URL: "",
//                          name: "Emilia Romagna",
//                          imageURLs: [Image(URL: Bundle.main.url(forResource: "italygrandprix", withExtension: "jpg")!, width: nil, height: nil, title: "image")],
//                          startDate: "",
//                          endDate: "",
//                          officialName: "Emilia Romagna Grand Prix",
//                          sessions: [])
//        SeasonCell_(event: event)
//            .frame(width: 400.0, height: 200.0 + 64.0)
//            .aspectRatio(contentMode: .fill)
//            .previewLayout(.sizeThatFits)
//    }
//
//}
