import Cocoa
import Foundation

class PreferencesWindow: NSWindow, NSWindowDelegate {
    let width = CGFloat(496)
    let height = CGFloat(256) // auto expands to content height (but does not auto shrink)
    let padding = CGFloat(40)
    var labelWidth: CGFloat {
        return (width - padding) * CGFloat(0.45)
    }
    var windowCloseRequested = false

    override init(contentRect: NSRect, styleMask style: StyleMask, backing backingStoreType: BackingStoreType, defer flag: Bool) {
        let initialRect = NSRect(x: 0, y: 0, width: width, height: height)
        super.init(contentRect: initialRect, styleMask: style, backing: backingStoreType, defer: flag)
        title = App.name + " Preferences"
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        styleMask.insert([.miniaturizable, .closable])
        contentView = makeContentView()
    }

    func show() {
        App.shared.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
    }

    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        windowCloseRequested = true
        challengeNextInvalidEditableTextField()
        return attachedSheet == nil // depends if user is challenged with a sheet
    }

    private func challengeNextInvalidEditableTextField() {
        let invalidFields = (contentView?
                .findNestedViews(subclassOf: TextField.self)
                .filter({ !$0.isValid() })
        )
        let focusedField = invalidFields?.filter({ $0.currentEditor() != nil }).first
        let fieldToNotify = focusedField ?? invalidFields?.first
        fieldToNotify?.delegate?.controlTextDidChange?(Notification(name: NSControl.textDidChangeNotification, object: fieldToNotify))

        if fieldToNotify != focusedField {
            makeFirstResponder(fieldToNotify)
        }
    }

    private func makeContentView() -> NSView {
        let wrappingView = NSStackView(views: makePreferencesViews())
        let contentView = NSView()
        contentView.addSubview(wrappingView)

        // visual setup
        wrappingView.orientation = .vertical
        wrappingView.alignment = .left
        wrappingView.spacing = padding * 0.3
        wrappingView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: padding * 0.5).isActive = true
        wrappingView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: padding * -0.5).isActive = true
        wrappingView.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: padding * 0.5).isActive = true
        wrappingView.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: padding * -0.5).isActive = true

        return contentView
    }

    private func makePreferencesViews() -> [NSView] {
        // TODO: make the validators be a part of each Preference
        let tabKeyCodeValidator: ((String) -> Bool) = {
            guard let int = Int($0) else {
                return false
            }
            // non-special keys (mac & pc keyboards): https://eastmanreference.com/complete-list-of-applescript-key-codes
            var whitelistedKeycodes: [Int] = Array(0...53)
            whitelistedKeycodes.append(contentsOf: [65, 67, 69, 75, 76, 78, ])
            whitelistedKeycodes.append(contentsOf: Array(81...89))
            whitelistedKeycodes.append(contentsOf: [91, 92, 115, 116, 117, 119, 121])
            whitelistedKeycodes.append(contentsOf: Array(123...126))
            return whitelistedKeycodes.contains(int)
        }

        return [
            makeLabelWithDropdown("Alt key", "metaKey", Preferences.metaKeyMacro.labels),
            makeLabelWithInput("Tab key", "tabKeyCode", 33, "KeyCodes Reference", "https://eastmanreference.com/complete-list-of-applescript-key-codes", tabKeyCodeValidator),
            makeHorizontalSeparator(),
            makeLabelWithDropdown("Theme", "theme", Preferences.themeMacro.labels),
            makeLabelWithSlider("Max size on screen", "maxScreenUsage", 10, 100, 10, true, "%"),
            makeLabelWithSlider("Min windows per row", "minCellsPerRow", 1, 20, 20, true),
            makeLabelWithSlider("Max windows per row", "maxCellsPerRow", 1, 40, 20, true),
            makeLabelWithSlider("Min rows of windows", "minRows", 1, 20, 20, true),
            makeLabelWithSlider("Window app icon size", "iconSize", 0, 64, 11, false, "px"),
            makeLabelWithSlider("Window title font size", "fontHeight", 0, 64, 11, false, "px"),
            makeLabelWithCheckbox("Hide space number labels", "hideSpaceNumberLabels"),
            makeHorizontalSeparator(),
            makeLabelWithSlider("Apparition delay", "windowDisplayDelay", 0, 2000, 11, false, "ms"),
            makeLabelWithDropdown("Show on", "showOnScreen", Preferences.showOnScreenMacro.labels)
        ]
    }

    private func makeHorizontalSeparator() -> NSView {
        let view = NSBox()
        view.boxType = .separator

        return view
    }

    private func makeLabelWithInput(_ labelText: String, _ rawName: String, _ width: CGFloat? = nil, _ suffixText: String? = nil, _ suffixUrl: String? = nil, _ validator: ((String) -> Bool)? = nil) -> NSStackView {
        let input = TextField(Preferences.rawValues[rawName]!)
        input.validationHandler = validator
        input.delegate = input
        input.visualizeValidationState()
        if width != nil {
            input.widthAnchor.constraint(equalToConstant: width!).isActive = true
        }

        return makeLabelWithProvidedControl(labelText, rawName, input, suffixText, nil, suffixUrl)
    }

    private func makeLabelWithCheckbox(_ labelText: String, _ rawName: String) -> NSStackView {
        let checkbox = NSButton.init(checkboxWithTitle: "", target: nil, action: nil)
        setControlValue(checkbox, Preferences.rawValues[rawName]!)
        return makeLabelWithProvidedControl(labelText, rawName, checkbox)
    }

    private func makeLabelWithDropdown(_ labelText: String, _ rawName: String, _ values: [String], _ suffixText: String? = nil) -> NSStackView {
        let popUp = NSPopUpButton()
        popUp.addItems(withTitles: values)
        popUp.selectItem(withTitle: Preferences.rawValues[rawName]!)

        return makeLabelWithProvidedControl(labelText, rawName, popUp, suffixText)
    }

    private func makeLabelWithSlider(_ labelText: String, _ rawName: String, _ minValue: Double, _ maxValue: Double, _ numberOfTickMarks: Int, _ allowsTickMarkValuesOnly: Bool, _ unitText: String = "") -> NSStackView {
        let value = Preferences.rawValues[rawName]!
        let suffixText = value + unitText
        let slider = NSSlider()
        slider.minValue = minValue
        slider.maxValue = maxValue
        slider.stringValue = value
        slider.numberOfTickMarks = numberOfTickMarks
        slider.allowsTickMarkValuesOnly = allowsTickMarkValuesOnly
        slider.tickMarkPosition = .below
        slider.isContinuous = true

        return makeLabelWithProvidedControl(labelText, rawName, slider, suffixText, 60)
    }

    private func makeLabelWithProvidedControl(_ labelText: String?, _ rawName: String, _ control: NSControl, _ suffixText: String? = nil, _ suffixWidth: CGFloat? = nil, _ suffixUrl: String? = nil) -> NSStackView {
        let label = NSTextField(wrappingLabelWithString: (labelText != nil ? labelText! + ": " : ""))
        label.alignment = .right
        label.widthAnchor.constraint(equalToConstant: labelWidth).isActive = true
        label.identifier = NSUserInterfaceItemIdentifier(rawName + ControlIdentifierDiscriminator.LABEL.rawValue)
        label.isSelectable = false

        control.identifier = NSUserInterfaceItemIdentifier(rawName)
        control.target = self
        control.action = #selector(controlWasChanged)
        let containerView = NSStackView(views: [label, control])

        if suffixText != nil {
            let suffix = makeSuffix(rawName, suffixText!, suffixWidth, suffixUrl)
            containerView.addView(suffix, in: .leading)
        }

        return containerView
    }

    private func makeSuffix(_ controlName: String, _ text: String, _ width: CGFloat? = nil, _ url: String? = nil) -> NSTextField {
        let suffix: NSTextField
        if url == nil {
            suffix = NSTextField(labelWithString: text)
        } else {
            suffix = HyperlinkLabel(labelWithUrl: text, nsUrl: NSURL(string: url!)!)
        }
        suffix.textColor = .gray
        suffix.identifier = NSUserInterfaceItemIdentifier(controlName + ControlIdentifierDiscriminator.SUFFIX.rawValue)
        if width != nil {
            suffix.widthAnchor.constraint(equalToConstant: width!).isActive = true
        }

        return suffix
    }

    private func updateSuffixWithValue(_ control: NSControl, _ value: String) {
        let suffixIdentifierPredicate = { (view: NSView) -> Bool in
            view.identifier?.rawValue == control.identifier!.rawValue + ControlIdentifierDiscriminator.SUFFIX.rawValue
        }

        if let suffixView: NSTextField = control.superview?.subviews.first(where: suffixIdentifierPredicate) as? NSTextField {
            let regex = try! NSRegularExpression(pattern: "^[0-9]+") // first decimal
            let range = NSMakeRange(0, suffixView.stringValue.count)
            suffixView.stringValue = regex.stringByReplacingMatches(in: suffixView.stringValue, range: range, withTemplate: value)
        }
    }

    @objc
    private func controlWasChanged(senderControl: NSControl) {
        let key: String = senderControl.identifier!.rawValue
        let previousValue: String = Preferences.rawValues[key]!
        let newValue: String = getControlValue(senderControl)
        let invalidTextField = senderControl is TextField && !(senderControl as! TextField).isValid()

        if (invalidTextField && !windowCloseRequested) || (newValue == previousValue && !invalidTextField) {
            return
        }

        updateControlExtras(senderControl, newValue)

        do {
            // TODO: remove conditional as soon a Preference does validation on its own
            if invalidTextField && windowCloseRequested {
                throw NSError.make(domain: "Preferences", message: "Please enter a valid value for '" + key + "'")
            }
            try Preferences.updateAndValidateFromString(key, newValue)
            (App.shared as! App).initPreferencesDependentComponents()
            try Preferences.saveRawToDisk()
        } catch let error {
            debugPrint("PreferencesWindow: save: error", key, newValue, error)
            showSaveErrorSheetModal(error as NSError, senderControl, key, previousValue) // allows recursive call by user choice
        }
    }

    private func showSaveErrorSheetModal(_ nsError: NSError, _ control: NSControl, _ key: String, _ previousValue: String) {
        let alert = NSAlert()
        alert.messageText = "Could not save Preference"
        alert.informativeText = nsError.localizedDescription + "\n"
        alert.addButton(withTitle: "Edit")
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Check again")

        alert.beginSheetModal(for: self, completionHandler: { (modalResponse: NSApplication.ModalResponse) -> Void in
            if modalResponse == NSApplication.ModalResponse.alertFirstButtonReturn {
                debugPrint("PreferencesWindow: save: error: user choice: edit")
                self.windowCloseRequested = false
            }
            if modalResponse == NSApplication.ModalResponse.alertSecondButtonReturn {
                debugPrint("PreferencesWindow: save: error: user choice: cancel -> revert value and eventually close window")
                try! Preferences.updateAndValidateFromString(key, previousValue)
                self.setControlValue(control, previousValue)
                self.updateControlExtras(control, previousValue)
                if self.windowCloseRequested {
                    self.close()
                }
            }
            if modalResponse == NSApplication.ModalResponse.alertThirdButtonReturn {
                debugPrint("PreferencesWindow: save: error: user choice: check again")
                self.controlWasChanged(senderControl: control)
            }
        })
    }

    private func getControlValue(_ control: NSControl) -> String {
        if control is NSPopUpButton {
            return (control as! NSPopUpButton).titleOfSelectedItem!
        } else if control is NSSlider {
            return String(format: "%.0f", control.doubleValue) // we are only interested in decimals of the provided double
        } else if control is NSButton {
            return String((control as! NSButton).state == NSButton.StateValue.on)
        } else {
            return control.stringValue
        }
    }

    private func setControlValue(_ control: NSControl, _ value: String) {
        if control is NSPopUpButton {
            (control as! NSPopUpButton).selectItem(withTitle: value)
        } else if control is NSTextField {
            control.stringValue = value
            (control as! NSTextField).delegate?.controlTextDidChange?(Notification(name: NSControl.textDidChangeNotification, object: control))
        } else if control is NSButton {
            (control as! NSButton).state = Bool(value) ?? false ? NSButton.StateValue.on : NSButton.StateValue.off
        } else {
            control.stringValue = value
        }
    }

    private func updateControlExtras(_ control: NSControl, _ value: String) {
        if control is NSSlider {
            updateSuffixWithValue(control as! NSSlider, value)
        }
    }
}

enum ControlIdentifierDiscriminator: String {
    case LABEL = "_label"
    case SUFFIX = "_suffix"
}
