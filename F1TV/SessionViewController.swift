//
//  SessionViewController.swift
//  F1TV
//
//  Created by Adam Bell on 9/28/20.
//

import AVKit
import AVFoundation
import SDWebImage
import SwiftUI
import UIKit
import TVUIKit

fileprivate let DriverCellIdentifier = "DriverCellIdentifier"

class SessionViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    var player: AVPlayer!

    let session: Session
    private(set) var channels: [Channel]?

    let collectionViewLayout = { () -> UICollectionViewLayout in
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 300.0, height: 300.0)
        return layout
    }()
    var collectionView: UICollectionView!
    var driverCollectionViewHeader: UILabel!

    var raceChannel: Channel? = nil {
        didSet {
            raceView?.isUserInteractionEnabled = raceChannel != nil
            raceView?.alpha = (raceChannel != nil ? 1.0 : 0.5)
        }
    }
    var driverChannels: [Channel]? = nil {
        didSet {
            if let driverChannels = driverChannels, driverChannels.count > 0 {
                collectionView.performBatchUpdates {
                    let indexPaths = (0..<driverChannels.count).map { IndexPath(item: $0, section: 0) }
                    collectionView.insertItems(at: indexPaths)
                } completion: { (_) in

                }
            } else {
                collectionView.reloadData()
            }
        }
    }

    var raceView: TVPosterView!

    var activityIndicator: UIActivityIndicatorView!

    init(session: Session) {
        self.session = session
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        super.loadView()
//        raceImageView.contentMode = .scaleAspectFill
//        raceImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
//        raceImageView.adjustsImageWhenAncestorFocused = true
//        raceView.contentView.addSubview(raceImageView)
        self.raceView = TVPosterView(frame: .zero)
        raceView.imageView.sd_setImage(with: session.imageURLs.first?.URL)
        raceView.imageView.sd_imageTransition = .fade
        raceView.contentSize = CGSize(width: 420.0, height: 420.0 * (9.0 / 16.0))
        raceView.title = "Main Stream"
        raceView.isUserInteractionEnabled = true
        raceView.alpha = 1
        raceView.addTarget(self, action: #selector(openPrimaryRaceStream(_:)), for: [.touchUpInside, .primaryActionTriggered])
        view.addSubview(raceView)

        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: collectionViewLayout)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.clipsToBounds = false
        view.addSubview(collectionView)

        self.driverCollectionViewHeader = UILabel(frame: .zero)
        driverCollectionViewHeader.text = NSLocalizedString("Driver Streams", comment: "Driver Streams")
        driverCollectionViewHeader.font = UIFont.preferredFont(forTextStyle: .title2)
        driverCollectionViewHeader.alpha = 0.0
        view.addSubview(driverCollectionViewHeader)

        self.activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)

        collectionView.register(DriverCell.self, forCellWithReuseIdentifier: DriverCellIdentifier)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = session.name
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        loadEvent()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let raceViewSize = raceView.sizeThatFits(view.bounds.size)
        raceView.frame = CGRect(x: 80.0, y: 200.0, width: raceViewSize.width, height: raceViewSize.height)
        collectionView.frame = CGRect(x: 0.0, y: view.bounds.size.height - 300.0 - 160.0, width: view.bounds.size.width, height: 300.0)

        driverCollectionViewHeader.sizeToFit()
        driverCollectionViewHeader.frame.origin = CGPoint(x: raceView.frame.minX, y: collectionView.frame.minY - driverCollectionViewHeader.bounds.size.height - 12.0)
        driverCollectionViewHeader.alpha = ((driverChannels?.count ?? 0) > 0) ? 1.0 : 0.0

        activityIndicator.sizeToFit()
        activityIndicator.center = raceView.center
    }

    private func loadEvent() {
        // TODO: load additional_streams
//        activityIndicator.startAnimating()
//        F1TV.shared.getStream_v2(session.URL) { [weak self] _ in
//            self?.activityIndicator.stopAnimating()
//        }

//
//        F1TV.shared.getEpisodesForSession(session.URL) { [weak self] channels in
//
//
//            guard let channels = channels else {
//                return
//            }
//
//            self?.raceChannel = channels.first { $0.channelType == "wif" }
//            self?.driverChannels = channels.filter { $0.channelType == "driver" }
//        }
    }

    // MARK: - UICollectionViewDataSource

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return driverChannels?.count ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: DriverCellIdentifier, for: indexPath) as! DriverCell

        cell.driver = driverChannels?[indexPath.item].drivers.first

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 40.0, left: 0.0, bottom: 0.0, right: 80.0)
    }

    func collectionView(_ collectionView: UICollectionView, canFocusItemAt indexPath: IndexPath) -> Bool {
        return true
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let contentURL = driverChannels?[indexPath.item].URL else {
            return
        }

        guard let cell = collectionView.cellForItem(at: indexPath) else { return }
        cell.isUserInteractionEnabled = false
        openStream(contentURL, sender: cell)
    }

    private func openStream(_ urlString: String, sender: UIView?) {
        F1TV.shared.getStream_v2(urlString) { [weak self] assetURL in
            sender?.isUserInteractionEnabled = true

            guard let assetURL = assetURL else { return }

            let player = AVPlayer(url: assetURL)

            let streamViewController = AVPlayerViewController()
            streamViewController.player = player
            self?.present(streamViewController, animated: true) { [weak streamViewController] in
                streamViewController?.player?.play()
            }
        }
    }

    @objc private func openPrimaryRaceStream(_ sender: UIView?) {
        // TODO: no URL as it seems
//        guard let contentURL = session.URL else {
//            print("[Error] No Channel URL")
//            return
//        }

        sender?.isUserInteractionEnabled = false
        openStream(session.URL, sender: sender)
    }

}

class DriverCell: UICollectionViewCell {

    var driver: Driver? {
        didSet {
            updateEpisode()
        }
    }

    fileprivate let driverImageView: TVMonogramView

    override init(frame: CGRect) {
        self.driverImageView = TVMonogramView(frame: .zero)
        super.init(frame: frame)

        driverImageView.clipsToBounds = false
        driverImageView.contentSize = CGSize(width: 200.0, height: 200.0)
        contentView.addSubview(driverImageView)

        contentView.clipsToBounds = false
        self.clipsToBounds = false

        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
    }

    private func updateEpisode() {
        let driverImageURL = driver?.imageURLs.first(where: { (driverImage) -> Bool in
            return driverImage.imageType == "Headshot"
        })?.URL

        SDWebImageManager.shared.loadImage(with: driverImageURL, options: [], progress: nil) { [weak self] (image, data, error, _, _, _) in
            self?.driverImageView.image = image
            self?.setNeedsLayout()
        }

        let name = driver?.name.components(separatedBy: " - ").first
        let teamName = driver?.name.components(separatedBy: " - ").last

        driverImageView.title = name
        driverImageView.subtitle = teamName

        var nameComponents = PersonNameComponents()
        nameComponents.givenName = name?.components(separatedBy: " ").first
        nameComponents.familyName = name?.components(separatedBy: " ").last
        driverImageView.personNameComponents = nameComponents

        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        driverImageView.frame = self.bounds
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
    }

}
