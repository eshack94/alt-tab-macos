import Cocoa

class StackView: NSStackView {
    var alignmentRectInsets_: NSEdgeInsets!

    convenience init(_ views: [NSView], _ orientation: NSUserInterfaceLayoutOrientation = .horizontal, top: CGFloat = 0, right: CGFloat = 0, bottom: CGFloat = 0, left: CGFloat = 0) {
        self.init(views: views)
        alignmentRectInsets_ = NSEdgeInsets(top: top, left: left, bottom: bottom, right: right)
        alignment = orientation == .horizontal ? .firstBaseline : .left
        // workaround: for some reason, horizontal stackviews with a RecorderControl have extra fittingSize.height
        if orientation == .horizontal && views.first(where: { $0 is UnclearableRecorderControl }) != nil {
            fit(fittingSize.width, fittingSize.height - 7)
        } else {
            fit()
        }
    }

    override var alignmentRectInsets: NSEdgeInsets { alignmentRectInsets_ }
}
