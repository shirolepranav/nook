import NookKit

// NookAI: CapabilityRouter, AIEngine and ClassicEngine (04_Architecture.md §2).
// P6 ships the ClassicEngine and the scanners; the router arrives in P8 and replaces each
// `NookAI.classic` call with `router.engine()` (D48).
public enum NookAI {
    public static let appGroupID = NookKit.appGroupID
    public static let classic = ClassicEngine()
}
