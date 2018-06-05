//  Copyright © 2017 SkeletonView. All rights reserved.

import UIKit

public extension UIView {
    
    func showSkeleton(usingColor color: UIColor = SkeletonAppearance.default.tintColor) {
        showSkeleton(withType: .solid, usingColors: [color])
    }
    
    func showGradientSkeleton(usingGradient gradient: SkeletonGradient = SkeletonAppearance.default.gradient) {
        showSkeleton(withType: .gradient, usingColors: gradient.colors)
    }
    
    func showAnimatedSkeleton(usingColor color: UIColor = SkeletonAppearance.default.tintColor, animation: SkeletonLayerAnimation? = nil) {
        showSkeleton(withType: .solid, usingColors: [color], animated: true, animation: animation)
    }
    
    func showAnimatedGradientSkeleton(usingGradient gradient: SkeletonGradient = SkeletonAppearance.default.gradient, animation: SkeletonLayerAnimation? = nil) {
        showSkeleton(withType: .gradient, usingColors: gradient.colors, animated: true, animation: animation)
    }

    func updateSkeleton(usingColor color: UIColor = SkeletonAppearance.default.tintColor) {
        updateSkeleton(withType: .solid, usingColors: [color])
    }

    func updateGradientSkeleton(usingGradient gradient: SkeletonGradient = SkeletonAppearance.default.gradient) {
        updateSkeleton(withType: .gradient, usingColors: gradient.colors)
    }

    func updateAnimatedSkeleton(usingColor color: UIColor = SkeletonAppearance.default.tintColor, animation: SkeletonLayerAnimation? = nil) {
        updateSkeleton(withType: .solid, usingColors: [color], animated: true, animation: animation)
    }

    func updateAnimatedGradientSkeleton(usingGradient gradient: SkeletonGradient = SkeletonAppearance.default.gradient, animation: SkeletonLayerAnimation? = nil) {
        updateSkeleton(withType: .gradient, usingColors: gradient.colors, animated: true, animation: animation)
    }
    
    func hideSkeleton(reloadDataAfter reload: Bool = true) {
        flowDelegate?.willBeginHidingSkeletons(withRootView: self)
        recursiveHideSkeleton(reloadDataAfter: reload, root: self)
    }
    
    func startSkeletonAnimation(_ anim: SkeletonLayerAnimation? = nil) {
        skeletonIsAnimated = true
        subviewsSkeletonables.recursiveSearch(leafBlock: startSkeletonLayerAnimationBlock(anim)) { subview in
            subview.startSkeletonAnimation(anim)
        }
    }

    func stopSkeletonAnimation() {
        skeletonIsAnimated = false
        subviewsSkeletonables.recursiveSearch(leafBlock: stopSkeletonLayerAnimationBlock) { subview in
            subview.stopSkeletonAnimation()
        }
    }
}

extension UIView {
    
    func showSkeleton(withType type: SkeletonType = .solid, usingColors colors: [UIColor], animated: Bool = false, animation: SkeletonLayerAnimation? = nil) {
        skeletonIsAnimated = animated
        flowDelegate = SkeletonFlowHandler()
        flowDelegate?.willBeginShowingSkeletons(withRootView: self)
        recursiveShowSkeleton(withType: type, usingColors: colors, animated: animated, animation: animation, root: self)
    }
    
    func updateSkeleton(withType type: SkeletonType = .solid, usingColors colors: [UIColor], animated: Bool = false, animation: SkeletonLayerAnimation? = nil) {
        skeletonIsAnimated = animated
        if flowDelegate == nil {
            flowDelegate = SkeletonFlowHandler()
            flowDelegate?.willBeginShowingSkeletons(withRootView: self)
        }
        flowDelegate?.willBeginUpdatingSkeletons(withRootView: self)
        recursiveUpdateSkeleton(withType: type, usingColors: colors, animated: animated, animation: animation)
    }

    fileprivate func recursiveShowSkeleton(withType type: SkeletonType, usingColors colors: [UIColor], animated: Bool, animation: SkeletonLayerAnimation?, root: UIView? = nil) {
        addDummyDataSourceIfNeeded()
        subviewsSkeletonables.recursiveSearch(
            leafBlock: showSkeletonLeafBlock(withType: type, usingColors:colors, animated: animated, animation: animation)
        ) { subview in
            subview.recursiveShowSkeleton(withType: type, usingColors: colors, animated: animated, animation: animation)
        }

        if let root = root {
            flowDelegate?.didShowSkeletons(withRootView: root)
        }
    }

    fileprivate func recursiveUpdateSkeleton(withType type: SkeletonType, usingColors colors: [UIColor], animated: Bool, animation: SkeletonLayerAnimation?) {
        updateDummyDataSourceIfNeeded()
        subviewsSkeletonables.recursiveSearch(leafBlock: {
            if skeletonLayer?.type != type {
                hideSkeleton()
            }

            if isSkeletonActive {
                updateSkeletonLayer(usingColors: colors, animated: animated, animation: animation)
            } else {
                showSkeletonLeafBlock(withType: type, usingColors: colors, animated: animated, animation: animation)()
            }
        }) { view in
            view.recursiveUpdateSkeleton(withType: type, usingColors: colors, animated: animated, animation: animation)
        }
    }

    fileprivate func showSkeletonLeafBlock(withType type: SkeletonType, usingColors colors: [UIColor], animated: Bool, animation: SkeletonLayerAnimation?) -> VoidBlock {
        return {
            guard !self.isSkeletonActive else { return }
            self.isUserInteractionEnabled = false
            self.saveViewState()
            (self as? PrepareForSkeleton)?.prepareViewForSkeleton()
            self.addSkeletonLayer(withType: type, usingColors: colors, animated: animated, animation: animation)
        }
    }
    
    fileprivate func recursiveHideSkeleton(reloadDataAfter reload: Bool, root: UIView? = nil) {
        removeDummyDataSourceIfNeeded()
        isUserInteractionEnabled = true
        subviewsSkeletonables.recursiveSearch(leafBlock: {
            recoverViewState(forced: false)
            removeSkeletonLayer()
        }) { subview in
            subview.recursiveHideSkeleton(reloadDataAfter: reload)
        }
        if let root = root {
            flowDelegate?.didHideSkeletons(withRootView: root)
        }
    }
    
    fileprivate func startSkeletonLayerAnimationBlock(_ anim: SkeletonLayerAnimation? = nil) -> VoidBlock {
        return {
            guard let layer = self.skeletonLayer else { return }
            layer.start(anim)
        }
    }
    
    fileprivate var stopSkeletonLayerAnimationBlock: VoidBlock {
        return {
            guard let layer = self.skeletonLayer else { return }
            layer.stopAnimation()
        }
    }
}

extension UIView {
    
    func addSkeletonLayer(withType type: SkeletonType, usingColors colors: [UIColor], gradientDirection direction: GradientDirection? = nil, animated: Bool, animation: SkeletonLayerAnimation? = nil) {
        guard let skeletonLayer = SkeletonLayerBuilder()
            .setSkeletonType(type)
            .addColors(colors)
            .setHolder(self)
            .build()
            else { return }

        self.skeletonLayer = skeletonLayer
        layer.insertSublayer(skeletonLayer.contentLayer, at: UInt32.max)
        if animated { skeletonLayer.start(animation) }
        status = .on
    }
    
    func updateSkeletonLayer(usingColors colors: [UIColor], gradientDirection direction: GradientDirection? = nil, animated: Bool, animation: SkeletonLayerAnimation? = nil) {
        guard skeletonLayer != nil else { return }
        self.skeletonLayer!.update(usingColors: colors)
        if animated { skeletonLayer!.start(animation) }else{skeletonLayer!.stopAnimation()}
        status = .on
    }
    
    func removeSkeletonLayer() {
        guard isSkeletonActive,
            let layer = skeletonLayer else { return }
        layer.stopAnimation()
        layer.removeLayer()
        skeletonLayer = nil
        status = .off
    }
}

