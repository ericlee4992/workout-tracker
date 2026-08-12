import Foundation

// Live scanning, decision half — pure: no UI, no camera, no Vision.
//
// A live scanner reads the same plate many times a second and gets a slightly
// different answer each time: a word drops out as the phone moves, glare eats a
// letter, an extra line appears at the frame edge. Something has to decide when
// the app has seen enough to stop and commit to an answer, and that decision is
// exactly the sort of thing that is miserable to test through a camera and
// trivial to test here.

/// Decides when successive live readings agree enough to stop scanning.
struct LiveScanStabilizer {

    /// How many consecutive readings must agree before the answer is taken.
    /// Two is enough to reject a single mangled frame while still settling in
    /// well under a second at ~3 readings/second — a scanner that takes four
    /// seconds to agree with itself feels broken.
    let agreementsNeeded: Int

    /// Readings with fewer distinctive words than this are treated as
    /// mid-focus noise rather than an answer. A plate that genuinely says one
    /// word still settles, because the *same* one word will keep arriving.
    let minimumTokens: Int

    private var currentKey: String?
    private var agreements = 0
    /// The richest reading seen for the current key. Frames disagree in what
    /// they *missed*, so the fullest one is the best evidence, not the last.
    private var best: LabelReading?

    init(agreementsNeeded: Int = 2, minimumTokens: Int = 1) {
        self.agreementsNeeded = agreementsNeeded
        self.minimumTokens = minimumTokens
    }

    /// Feeds one live reading in. Returns the reading to use once the scanner
    /// has settled, or nil to keep looking.
    ///
    /// `key` is what "the same answer" means to the caller — the top catalog
    /// match's id when there is one, so the scanner settles on a *decision*
    /// rather than on identical pixels, and the normalized text when there is
    /// not.
    mutating func observe(_ reading: LabelReading, key: String) -> LabelReading? {
        let tokens = MachineLabelText.readingTokens(reading.text)
        guard tokens.count >= minimumTokens, !key.isEmpty else {
            // Nothing usable in this frame: keep whatever streak exists rather
            // than punishing a good streak for one blurred frame.
            return nil
        }

        if key == currentKey {
            agreements += 1
            if MachineLabelText.readingTokens(best?.text ?? "").count < tokens.count {
                best = reading
            }
        } else {
            currentKey = key
            agreements = 1
            best = reading
        }

        guard agreements >= agreementsNeeded else { return nil }
        return best
    }

    /// Forgets the streak — used when the user aims at something else.
    mutating func reset() {
        currentKey = nil
        agreements = 0
        best = nil
    }
}
