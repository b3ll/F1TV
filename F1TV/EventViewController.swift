//
//  EventViewController.swift
//  F1TV
//
//  Created by Adam Bell on 9/28/20.
//

import SDWebImage
import SwiftUI
import UIKit
import TVUIKit

fileprivate let SessionCellIdentifier = "SessionCellIdentifier"

class EventViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    let partialEvent: Event
    private(set) var event: Event? {
        didSet {
            collectionView.reloadData()
        }
    }

    let collectionViewLayout = { () -> UICollectionViewLayout in
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 308.0, height: 200.0)
        layout.minimumLineSpacing = 100.0
        layout.minimumInteritemSpacing = 50.0
        return layout
    }()
    var collectionView: UICollectionView!

    init(partialEvent: Event) {
        self.partialEvent = partialEvent
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: collectionViewLayout)
        collectionView.dataSource = self
        collectionView.delegate = self
        self.view = collectionView

        collectionView.register(SessionCell.self, forCellWithReuseIdentifier: SessionCellIdentifier)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = partialEvent.name
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        loadEvent()
    }

    private func loadEvent() {
        if let v1ApiUrl = partialEvent.URL {
            F1TV.shared.getEvent(v1ApiUrl) { [weak self] event in
                self?.event = event
            }
        } else if let _ = partialEvent.pageId {
            F1TV.shared.getEvent_v2(partialEvent) { [weak self] event in
                self?.event = event
            }
        }
    }

    // MARK: - UICollectionViewDataSource

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return event?.sessions?.count ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SessionCellIdentifier, for: indexPath) as! SessionCell

        cell.session = event?.sessions?[indexPath.item]
        cell.sessionNamePrefix = partialEvent.sessionNamePrefix

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 40.0, left: 80.0, bottom: 40.0, right: 80.0)
    }

    func collectionView(_ collectionView: UICollectionView, canFocusItemAt indexPath: IndexPath) -> Bool {
        return true
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let session = event?.sessions?[indexPath.item] else { return }

        let sessionViewController = SessionViewController(session: session)
        navigationController?.pushViewController(sessionViewController, animated: true)
    }

}

class SessionCell: UICollectionViewCell {

    var session: Session? {
        didSet {
            updateSession()
        }
    }
    var sessionNamePrefix: String? {
        didSet {
            updateSession()
        }
    }

    private let titleLabel: UILabel
    private let backgroundImageView: UIImageView

    override init(frame: CGRect) {
        self.titleLabel = UILabel()
        self.backgroundImageView = UIImageView()
        super.init(frame: frame)

        contentView.addSubview(backgroundImageView)
        contentView.addSubview(titleLabel)

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

        titleLabel.numberOfLines = 2
        titleLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        titleLabel.textAlignment = .center
        titleLabel.lineBreakMode = .byWordWrapping
    }

    private func updateSession() {
        backgroundImageView.sd_setImage(with: session?.imageURLs.first?.URL, placeholderImage: UIImage.placeholder, completed: nil)
        backgroundImageView.sd_imageTransition = .fade

        // Smarter name formatting if we've got it. Drops the e.g. "2020 Eifel Grand Prix" from the session.
        if let sessionNamePrefix = sessionNamePrefix, let session = session, session.name.hasPrefix(sessionNamePrefix) {
            titleLabel.text = String(session.name.dropFirst(sessionNamePrefix.count))
        } else {
            titleLabel.text = session?.name
        }

        updateFocusedElements()

        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        backgroundImageView.frame = CGRect(origin: .zero, size: CGSize(width: bounds.size.width, height: bounds.size.width * (9.0/16.0)))

        let sizeDiff = ((backgroundImageView.focusedFrameGuide.layoutFrame.size.height - backgroundImageView.bounds.size.height) / 2.0)

        let titleLabelSize = titleLabel.sizeThatFits(bounds.size)
        titleLabel.bounds = CGRect(x: 0.0, y: 0.0, width: bounds.size.width, height: titleLabelSize.height)
        titleLabel.layer.position = CGPoint(x: bounds.size.width / 2.0, y: backgroundImageView.layer.position.y + (backgroundImageView.bounds.size.height / 2.0) + sizeDiff + (titleLabel.bounds.size.height / 2.0) + 8.0)
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
        titleLabel.alpha = isFocused ? 1.0 : 0.8
    }

}
