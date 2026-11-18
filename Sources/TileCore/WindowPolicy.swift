/// Structural exclusions; never identify dialogs by localized titles.
public enum WindowPolicy {
    public static func allows(role: String, subrole: String, modal: Bool, resizable: Bool) -> Bool {
        role == "AXWindow" && subrole == "AXStandardWindow" && !modal && resizable
    }
}
