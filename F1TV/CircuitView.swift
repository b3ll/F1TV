//
//  CircuitView.swift
//  F1TV
//
//  Created by Adam Bell on 9/28/20.
//

import SceneKit
import SceneKit.ModelIO
import SwiftUI

struct CircuitView: View {

    @Environment(\.isFocused) var isFocused: Bool

    let event: Event

    var body: some View {
        VStack(alignment: .leading) {
            ZStack(alignment: .bottomLeading) {
                Rectangle()
                    .foregroundColor(.black)
                    .opacity(0.2)
                ModelViewerView(name: "converted")
                EventTitleBar(flagImage: UIImage(), title: event.officialName, subtitle: event.name)
            }
            .background(
                SwiftUI.Image(uiImage: UIImage(contentsOfFile: event.imageURLs.first?.URL.path ?? "") ?? .init())
                    .resizable()
            )
        }
        .background(Color.clear)
        .focusable()
    }

}

struct EventTitleBar: View, Equatable {

//    let flagName: String
    let flagImage: UIImage
    let title: String
    let subtitle: String

    init(flagImage: UIImage = UIImage(), title: String = "", subtitle: String = "") {
        self.flagImage = flagImage
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12.0) {
//            SVGView(svgName: flagName)
            SwiftUI.Image(uiImage: flagImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
//                .mask(RoundedRectangle(cornerRadius: 2.0, style: .continuous))
                .shadow(radius: 4.0)
                .padding([.leading, .top, .bottom], 12.0)
                .frame(maxWidth: 100.0, maxHeight: 80.0)

            VStack(alignment: .leading, spacing: 6.0) {
                Text(title)
                    .font(Font.system(size: 20.0))
                    .bold()

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(Font.system(size: 16.0))
                }
            }

            Spacer()
        }
        .background(BlurView())
        .frame(maxHeight: 80.0)
        .edgesIgnoringSafeArea(.all)
    }

}

struct SVGView: UIViewRepresentable {

    let svgName: String

    func makeUIView(context: Context) -> UIView {
        return UIImageView(image: UIImage(named: svgName))
    }

    func updateUIView(_ uiView: UIView, context: Context) {

    }

}

struct BlurView: UIViewRepresentable {

    var style: UIBlurEffect.Style = .dark

    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }

}

struct CircuitView_Previews: PreviewProvider {

    static var previews: some View {
        let event = Event(URL: "",
                          name: "Emilia Romagna",
                          imageURLs: [Image(URL: Bundle.main.url(forResource: "italygrandprix", withExtension: "jpg")!, title: "image")],
                          startDate: "",
                          endDate: "",
                          officialName: "Emilia Romagna Grand Prix",
                          sessions: [],
                          nation: Nation(URL: "", name: "", countryCode: "", imageURLs: []))
        CircuitView(event: event)
            .frame(width: 500.0, height: 300.0)
            .aspectRatio(contentMode: .fill)
            .previewLayout(.sizeThatFits)
    }

}

class ModelViewer: SCNView {

    let name: String

    init(name: String) {
        self.name = name

        super.init(frame: .zero, options: nil)

        self.autoenablesDefaultLighting = true

        let scene = try! SCNScene(url: Bundle.main.url(forResource: name, withExtension: "usdz")!, options: [.checkConsistency: true])
        scene.background.contents = nil
        self.scene = scene

        self.backgroundColor = .clear
        self.clipsToBounds = false

        let node = scene.rootNode.childNode(withName: "converted", recursively: true)!

        node.centerPivot(for: scene.rootNode)
        node.runAction(SCNAction.repeatForever(SCNAction.rotate(by: 2.0 * .pi, around: SCNVector3(0.0, 1.0, 0.0), duration: 3.0)))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)

        guard let scene = scene else { return }

        let node = scene.rootNode.childNode(withName: "converted", recursively: true)!

        if isFocused {
            node.centerPivot(for: scene.rootNode)
            node.runAction(SCNAction.repeatForever(SCNAction.rotate(by: 2.0 * .pi, around: SCNVector3(0.0, 1.0, 0.0), duration: 3.0)))
        } else {
            node.removeAllActions()
        }
    }

}

struct ModelViewerView: UIViewRepresentable {

    let name: String

    func makeUIView(context: Context) -> ModelViewer {
        return ModelViewer(name: name)
    }

    func updateUIView(_ uiView: ModelViewer, context: Context) {

    }

}
//
//struct ModelViewerView_Previews: PreviewProvider {
//
//    static var previews: some View {
//        ModelViewerView(name: "converted")
//            .frame(width: 512, height: 512, alignment: .center)
//            .previewLayout(.sizeThatFits)
//    }
//
//}

extension SCNNode {

    func centerPivot(for node: SCNNode) {
        let (minVec, maxVec) = node.boundingBox
        self.pivot = SCNMatrix4MakeTranslation((maxVec.x - minVec.x) / 2 + minVec.x, (maxVec.y - minVec.y) / 2 + minVec.y, 0)
        self.position = SCNVector3((maxVec.x - minVec.x) / 2, (maxVec.y - minVec.y), 0.0)
    }

}
