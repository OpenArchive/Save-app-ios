//
//  OnboardingView.swift
//  Save
//
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI

// MARK: - Slide Model

struct OnboardingSlide: Identifiable {
    let id = UUID()
    let heading: String
    let body: AttributedString
    let illustration: String
    let imageAlignment: Alignment
    let imageTopPadding: CGFloat

    init(
        heading: String,
        body: AttributedString,
        illustration: String,
        imageAlignment: Alignment = .center,
        imageTopPadding: CGFloat = 18
    ) {
        self.heading = heading
        self.body = body
        self.illustration = illustration
        self.imageAlignment = imageAlignment
        self.imageTopPadding = imageTopPadding
    }
}

// MARK: - Layout Constants

enum OnboardingLayout {
    static let topBarHeight: CGFloat            = 0
    static let rightBarWidthMultiplier: CGFloat = 0.25
    static let skipTopPadding: CGFloat          = 0
    static let skipButtonHeight: CGFloat        = 32
    static let nextButtonSize: CGFloat          = 50
    static let nextBottomPadding: CGFloat       = 15  
    static let pageControlLeading: CGFloat      = 35
    static let contentLeading: CGFloat          = 35
    static let textTrailingGap: CGFloat         = 8

    static var screenHeight: CGFloat { UIScreen.main.bounds.height }
    static var isSmallScreen: Bool { screenHeight <= 667 }

    static var imageHeightRatio: CGFloat {
        isSmallScreen ? 0.5 : 0.6
    }
    static var imageToHeading: CGFloat {
        isSmallScreen ? 10 : 30
    }
    static var headingToBody: CGFloat {
        isSmallScreen ? 8 : 12
    }

    static var skipHeight: CGFloat { skipTopPadding + skipButtonHeight }
}

// MARK: - Slide View

struct SlideView: View {
    let slide: OnboardingSlide
    let slideHeight: CGFloat
    let trailingPadding: CGFloat

    private var imageHeight: CGFloat   { slideHeight * OnboardingLayout.imageHeightRatio }
    private var contentHeight: CGFloat { slideHeight * (1 - OnboardingLayout.imageHeightRatio) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            illustrationSection
            contentSection
        }
    }

    private var illustrationSection: some View {
        VStack(spacing: 0) {
            if slide.imageTopPadding > 0 {
                Color.clear.frame(height: slide.imageTopPadding)
            }
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: imageHeight - slide.imageTopPadding)
                .overlay(alignment: slide.imageAlignment) {
                    Image(slide.illustration)
                        .resizable()
                        .scaledToFit()
                }
                .clipped()
        }
        .frame(maxWidth: .infinity)
        .frame(height: imageHeight)
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(slide.heading)
                .font(.montserrat(.extraBold, for: .title))
                .kerning(1.2)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(slide.body)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .multilineTextAlignment(.leading)
                .padding(.top, OnboardingLayout.headingToBody)
        }
        .padding(.top, OnboardingLayout.imageToHeading)
        .frame(height: contentHeight, alignment: .topLeading)
        .padding(.leading, OnboardingLayout.contentLeading)
        .padding(.trailing, trailingPadding)
    }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    var onComplete: (Bool) -> Void

    @State private var currentPage = 0
    private let slides = OnboardingSlides.all

    private var isLastPage: Bool { currentPage >= slides.count - 1 }

    var body: some View {
        GeometryReader { geometry in
            let rightBarWidth   = geometry.size.width * OnboardingLayout.rightBarWidthMultiplier
            let safeAreaTop     = geometry.safeAreaInsets.top
            let safeAreaBottom  = geometry.safeAreaInsets.bottom
            let trailingPadding = rightBarWidth + OnboardingLayout.textTrailingGap + 8

            let slideHeight = geometry.size.height
                - OnboardingLayout.topBarHeight
                - OnboardingLayout.skipHeight
                - OnboardingLayout.nextButtonSize
                - OnboardingLayout.nextBottomPadding


            let bottomRowHeight = OnboardingLayout.nextButtonSize
                + OnboardingLayout.nextBottomPadding
                + safeAreaBottom

            ZStack(alignment: .topLeading) {

                Color.accent
                    .frame(width: rightBarWidth)
                    .frame(maxHeight: .infinity)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .ignoresSafeArea()

                VStack(spacing: 0) {

                    Color.accent
                        .frame(height: OnboardingLayout.topBarHeight + safeAreaTop)

                    HStack(spacing: 0) {
                        Spacer()
                        Group {
                            if !isLastPage {
                                Button(NSLocalizedString("Skip", comment: "")) {
                                    onComplete(false)
                                }
                                .font(.montserrat(.semibold, for: .headline))
                                .foregroundColor(.black)
                            } else {
                                Color.clear
                            }
                        }
                        .frame(width: rightBarWidth,
                               height: OnboardingLayout.skipButtonHeight)
                        .padding(.top, OnboardingLayout.skipTopPadding)
                    }
                    .frame(height: OnboardingLayout.skipHeight)

                    TabView(selection: $currentPage) {
                        ForEach(Array(slides.enumerated()), id: \.element.id) { index, slide in
                            SlideView(
                                slide: slide,
                                slideHeight: max(0, slideHeight),
                                trailingPadding: trailingPadding
                            )
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(maxWidth: .infinity)
                    .frame(height: max(0, slideHeight))

                   
                    ZStack {
                        HStack(spacing: 0) {
                            Color(UIColor.systemBackground).frame(maxWidth: .infinity)
                            Color.clear.frame(width: rightBarWidth)
                        }

                        HStack(spacing: 0) {
                           
                            VStack(spacing: 0) {
                                PageControlView(
                                    numberOfPages: slides.count,
                                    currentPage: currentPage
                                )
                                
                                .frame(height: OnboardingLayout.nextButtonSize)
                                .padding(.leading, OnboardingLayout.pageControlLeading)

                                Spacer()
                                    .frame(height: OnboardingLayout.nextBottomPadding)
                            }

                            Spacer()
                            VStack(spacing: 0) {
                                Button {
                                    if isLastPage {
                                        onComplete(true)
                                    } else {
                                        withAnimation {
                                            currentPage = min(currentPage + 1,
                                                              slides.count - 1)
                                        }
                                    }
                                } label: {
                                    Image(isLastPage ? "check" : "forward_arrow")
                                        .renderingMode(.template)
                                        .font(.system(size: 20, weight: .semibold))
                                }
                                .foregroundColor(.black)
                                .frame(width: OnboardingLayout.nextButtonSize,
                                       height: OnboardingLayout.nextButtonSize)
                                .background(Color("light-teal"))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .frame(width: rightBarWidth)
                                Spacer()
                                    .frame(height: OnboardingLayout.nextBottomPadding)
                            }
                        }
                    }
                    .frame(height: bottomRowHeight)
                    .ignoresSafeArea(edges: .bottom)
                }
                .frame(maxWidth: .infinity)
            }
            .ignoresSafeArea(edges: .top)
            .ignoresSafeArea(edges: .bottom)
        }
        .background(Color(UIColor.systemBackground))
    }
}

// MARK: - Page Control

private struct PageControlView: UIViewRepresentable {
    var numberOfPages: Int
    var currentPage: Int

    func makeUIView(context: Context) -> UIPageControl {
        let control = UIPageControl()
        control.numberOfPages = numberOfPages
        control.currentPage = currentPage
        control.backgroundStyle = .minimal
        control.allowsContinuousInteraction = false
        control.currentPageIndicatorTintColor = .label
        control.pageIndicatorTintColor = UIColor.lightGray
        return control
    }

    func updateUIView(_ uiView: UIPageControl, context: Context) {
        uiView.numberOfPages = numberOfPages
        uiView.currentPage = currentPage
    }

    // Intrinsic size — prevents SwiftUI stretching to fill width
    // so .padding(.leading, 35) places dots correctly from left edge
    @available(iOS 16.0, *)
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIPageControl, context: Context) -> CGSize? {
        uiView.size(forNumberOfPages: numberOfPages)
    }
}

// MARK: - Slide Content

private enum OnboardingSlides {
    static var all: [OnboardingSlide] {
        [shareSlide, archiveSlide, verifySlide, encryptSlide]
    }

    private static var shareSlide: OnboardingSlide {
        let text = NSLocalizedString(
            "Send your media securely to private servers and lock the app with a pin.",
            comment: ""
        )

        let baseSize = UIFont.preferredFont(forTextStyle: .subheadline).pointSize
        let font = UIFont(name: "Montserrat-Regular", size: baseSize)
            ?? UIFont.systemFont(ofSize: baseSize)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.minimumLineHeight = 22
        paragraphStyle.maximumLineHeight = 22

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font, .paragraphStyle: paragraphStyle, .foregroundColor: UIColor.label
        ]
        let result = NSAttributedString(string: text, attributes: attrs)

        return OnboardingSlide(
            heading: NSLocalizedString("Share", comment: "").localizedUppercase,
            body: (try? AttributedString(result, including: \.uiKit)) ?? AttributedString(text),
            illustration: "onboarding-hand",
            imageAlignment: .center,
            imageTopPadding: 18
        )
    }

    private static var archiveSlide: OnboardingSlide {
        let localizedString = NSLocalizedString(
            "Upload media to Nextcloud or the Internet Archive to keep your media verifiable, safe, and organized for the long term.\n\nChoose %@.",
            comment: "Archive message"
        )
        let licenseText = NSLocalizedString("Creative Commons Licensing", comment: "")
        let licenseUrl  = URL(string: "https://creativecommons.org")!

        let baseSize = UIFont.preferredFont(forTextStyle: .subheadline).pointSize
        let letterSpacing = baseSize * 0.02
        let font = UIFont(name: "Montserrat-Regular", size: baseSize)
            ?? UIFont.systemFont(ofSize: baseSize)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        if UIScreen.main.bounds.height > 812 {
            paragraphStyle.minimumLineHeight = 22
            paragraphStyle.maximumLineHeight = 22
        }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font, .paragraphStyle: paragraphStyle, .foregroundColor: UIColor.label
        ]
        let linkAttrs = attrs.merging([
            .kern: letterSpacing,
            .underlineStyle: NSUnderlineStyle.single.rawValue, .link: licenseUrl
        ]) { _, new in new }

        let components = localizedString.components(separatedBy: "%@")
        let result = NSMutableAttributedString(string: components[0], attributes: attrs)
        result.append(NSAttributedString(string: licenseText, attributes: linkAttrs))

        return OnboardingSlide(
            heading: NSLocalizedString("Archive", comment: "").localizedUppercase,
            body: (try? AttributedString(result, including: \.uiKit)) ?? AttributedString(),
            illustration: "onboarding-laptop",
            imageAlignment: .topLeading,
            imageTopPadding: 0
        )
    }

    private static var verifySlide: OnboardingSlide {
        let localizedString = NSLocalizedString(
            "Authenticate and verify your media with sha256 hashes and %@",
            comment: "Verification message"
        )
        let proofModeText = NSLocalizedString("ProofMode.", comment: "ProofMode")
        let proofModeUrl  = URL(string: "https://proofmode.org")!

        let baseSize = UIFont.preferredFont(forTextStyle: .subheadline).pointSize
        let letterSpacing = baseSize * 0.02
        let font = UIFont(name: "Montserrat-Regular", size: baseSize)
            ?? UIFont.systemFont(ofSize: baseSize)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = 22
        paragraphStyle.maximumLineHeight = 22
        paragraphStyle.alignment = .left

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font, .kern: letterSpacing,
            .paragraphStyle: paragraphStyle, .foregroundColor: UIColor.label
        ]
        let linkAttrs = attrs.merging([
            .underlineStyle: NSUnderlineStyle.single.rawValue, .link: proofModeUrl
        ]) { _, new in new }

        let components = localizedString.components(separatedBy: "%@")
        let result = NSMutableAttributedString(string: components[0], attributes: attrs)
        result.append(NSAttributedString(string: proofModeText, attributes: linkAttrs))

        return OnboardingSlide(
            heading: NSLocalizedString("Verify", comment: "").localizedUppercase,
            body: (try? AttributedString(result, including: \.uiKit)) ?? AttributedString(),
            illustration: "onboarding-handheld",
            imageAlignment: .topLeading,
            imageTopPadding: 18
        )
    }

    private static var encryptSlide: OnboardingSlide {
        let localizedString = NSLocalizedString(
            "%@ always uploads over TLS (Transport Layer Security) to protect your media in transit. \nTo further enhance security, enable %@ to prevent interception of your media from your phone to the server.",
            comment: "Describes the encryption feature"
        )
        let saveText = NSLocalizedString("Save", comment: "")
        let torText  = NSLocalizedString("Tor", comment: "")
        let torUrl   = URL(string: "https://www.torproject.org")!

        let baseSize = UIFont.preferredFont(forTextStyle: .subheadline).pointSize
        let letterSpacing = baseSize * 0.02
        let font     = UIFont(name: "Montserrat-Regular", size: baseSize)
            ?? UIFont.systemFont(ofSize: baseSize)
        let descriptor     = font.fontDescriptor.withSymbolicTraits([.traitBold, .traitItalic])
        let boldItalicFont = UIFont(descriptor: descriptor ?? font.fontDescriptor, size: baseSize)

        let lineHeight: CGFloat = UIScreen.main.bounds.height <= 780 ? 18 : 22
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = lineHeight
        paragraphStyle.maximumLineHeight = lineHeight
        paragraphStyle.alignment = .left

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font, .kern: letterSpacing,
            .paragraphStyle: paragraphStyle, .foregroundColor: UIColor.label
        ]
        let saveAttrs: [NSAttributedString.Key: Any] = [
            .font: boldItalicFont, .kern: letterSpacing,
            .paragraphStyle: paragraphStyle, .foregroundColor: UIColor.label
        ]
        let torAttrs = attrs.merging([
            .underlineStyle: NSUnderlineStyle.single.rawValue, .link: torUrl
        ]) { _, new in new }

        let components = String(format: localizedString, "%@", "%@")
            .components(separatedBy: "%@")
        let result = NSMutableAttributedString()
        result.append(NSAttributedString(string: components[0], attributes: attrs))
        result.append(NSAttributedString(string: saveText,      attributes: saveAttrs))
        result.append(NSAttributedString(string: components[1], attributes: attrs))
        result.append(NSAttributedString(string: torText,       attributes: torAttrs))
        result.append(NSAttributedString(string: components[2], attributes: attrs))

        return OnboardingSlide(
            heading: NSLocalizedString("Encrypt", comment: "").localizedUppercase,
            body: (try? AttributedString(result, including: \.uiKit)) ?? AttributedString(),
            illustration: "onboarding-onion",
            imageAlignment: .center,
            imageTopPadding: 18
        )
    }
}
