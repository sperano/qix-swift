// The game state and its fixed-step update.

/// The whole game, advanced one fixed step at a time.
public struct Game: Sendable {
    /// The number of steps run so far.
    public internal(set) var ticks: UInt64
    /// The level being played, from `Tuning.firstLevel` on.
    public internal(set) var level: UInt32
    /// The board.
    public internal(set) var board: Board
    /// The player's marker.
    public internal(set) var marker: Marker
    /// The stix being drawn, if the marker is drawing one: set exactly while the marker is
    /// `MarkerState.drawing`.
    public internal(set) var stix: Stix?
    /// Ticks a direction has been held since the marker's last step.
    var markerHeldTicks: UInt32
    /// The fuse of the stix, out while the marker steps.
    var fuseTimer: FuseTimer
    /// The Qix, one or two depending on the level.
    public internal(set) var qix: [Qix]
    /// The Sparx.
    public internal(set) var sparx: [Sparx]
    /// Ticks since the Sparx on the border last stepped.
    var sparxTicks: UInt32
    /// Ticks since the Sparx chasing along the stix last stepped.
    var stixSparxTicks: UInt32
    /// The kinds of the Sparx the level started with, the first of `sparx`: what a reset of the
    /// meter takes them back to.
    var levelSparx: [SparxKind]
    /// The Sparx meter. Its first expiry releases `Tuning.extraSparx` more Sparx at the top
    /// centre, its second turns every Sparx `SparxKind.super`. A death resets it and undoes both:
    /// the released Sparx are gone and the others are back to the kinds the level started them
    /// with.
    public internal(set) var sparxMeter: SparxMeter
    /// Every random choice of the game comes from here.
    var rng: Rng
    /// The lives left, the one being played included; the game is over at zero. See `score` for
    /// the extra ones.
    public internal(set) var lives: UInt32
    /// Ticks of the grace period after a death still to run, the next one included; zero outside
    /// it.
    public internal(set) var graceTicks: UInt32
    /// The points scored so far. Each time they cross a multiple of `Tuning.extraLifeEvery` the
    /// player earns a life, up to `Tuning.maxLives`, and the tick raises `Event.extraLife`.
    public internal(set) var score: Score
    /// The multiplier of the points every claim scores: from `Tuning.startingMultiplier`, one more
    /// for every level a stix ended by splitting the Qix apart, up to `Tuning.maxMultiplier`.
    public internal(set) var multiplier: UInt32
    /// The claimed fraction of the board that completes the level.
    public internal(set) var claimThreshold: ClaimThreshold
    /// The rules `restart` sets the next game up with: the default ones until `setRules`.
    public internal(set) var rules: Rules
    /// A claim reached the claim threshold, or a stix split the Qix apart (see `multiplier`): the
    /// game no longer ticks.
    public internal(set) var isLevelComplete: Bool
    /// The events the last tick raised, in the order they happened.
    public internal(set) var events: [Event]

    /// A game at `Tuning.firstLevel` on `board`, with the marker at the centre of its bottom edge,
    /// `qix`, which must lie on free cells, and `sparx`, which must lie on the border, drawing from
    /// `rng`; its Sparx meter counts down the first level's `Tuning.sparxMeterTicks`.
    public init(board: Board, qix: [Qix], sparx: [Sparx], rng: Rng) {
        ticks = 0
        level = Tuning.firstLevel
        self.board = board
        marker = Marker.start(board)
        stix = nil
        markerHeldTicks = 0
        fuseTimer = FuseTimer()
        self.qix = qix
        levelSparx = sparx.map(\.kind)
        self.sparx = sparx
        sparxTicks = 0
        stixSparxTicks = 0
        sparxMeter = SparxMeter(length: Tuning.sparxMeterTicks)
        self.rng = rng
        lives = Tuning.startingLives
        graceTicks = 0
        score = Score()
        multiplier = Tuning.startingMultiplier
        claimThreshold = ClaimThreshold()
        rules = Rules()
        isLevelComplete = false
        events = []
    }

    /// Advances the game by one step of `1 / Tuning.tickHz` seconds: the marker moves, then the
    /// fuse burns, then each Qix moves, then the Sparx meter counts down (see `sparxMeter`), then
    /// the Sparx; a Qix touching the stix or the drawing marker kills the player, else a Sparx
    /// touching the marker does, else the fuse at the marker; one death at most per tick. A Qix
    /// touching the stix as the step onto the border would close it kills too: nothing is
    /// claimed. Once the game is over or the level complete, a tick does nothing.
    ///
    /// A death raises `Event.death` and takes a life, and the last one `Event.gameOver` too: the
    /// stix and its fuse are cleared, the marker is back on the border where the stix began and a
    /// Sparx left off the border snaps back to it. For `Tuning.respawnGraceTicks` ticks after it,
    /// the Sparx cannot kill and the marker cannot draw. A death also resets the Sparx meter.
    ///
    /// A stix that completes the level (a claim reaching the threshold, or a split; see
    /// `isLevelComplete`) ends the tick: nothing moves after it.
    public mutating func tick(_ input: InputState) {
        events.removeAll()
        if isOver || isLevelComplete {
            return
        }
        ticks += 1
        let grace = graceTicks > 0
        graceTicks = saturatingSubtract(graceTicks, 1)
        let markerFrom = marker.pos
        let closedAcrossQix = moveMarker(input, grace)
        if isLevelComplete {
            return
        }
        let fuseHit = burnFuse(markerFrom)
        for index in qix.indices {
            qix[index].tick(board, &rng)
        }
        runSparxMeter()
        let sparxHit = moveSparx(markerFrom) && !grace
        let cause: DeathCause? = if closedAcrossQix || qixHitsPlayer() {
            .qix
        } else if sparxHit {
            .sparx
        } else {
            fuseHit ? .fuse : nil
        }
        if let cause {
            die(cause)
        }
    }

    /// The fuse burning along the stix, if it is lit.
    public var fuse: Fuse? {
        fuseTimer.fuse
    }

    /// Replaces the Sparx meter, from the next tick on.
    public mutating func setSparxMeter(_ meter: SparxMeter) {
        sparxMeter = meter
    }

    /// Sets the claimed fraction of the board that completes the level, checked from the next
    /// claim on, until the next `restart`: see `setRules`.
    public mutating func setClaimThreshold(_ threshold: ClaimThreshold) {
        claimThreshold = threshold
    }

    /// The last life is lost: the game no longer ticks.
    public var isOver: Bool {
        lives == 0
    }
}

extension Game {
    /// Raises `Event.death` for `cause` and takes a life: the stix and its fuse are cleared, the
    /// marker is back on the border where the stix began (or stays where it is on the border), a
    /// Sparx that was on the stix snaps to the border and the grace period starts. Taking the last
    /// life raises `Event.gameOver` instead of starting a grace period.
    private mutating func die(_ cause: DeathCause) {
        events.append(.death(cause))
        lives -= 1
        if let stix {
            marker.pos = stix.start
        }
        stix = nil
        marker.state = .onBorder
        markerHeldTicks = 0
        fuseTimer.putOut()
        resetSparxMeter()
        snapSparxToBorder()
        if isOver {
            events.append(.gameOver)
        } else {
            graceTicks = Tuning.respawnGraceTicks
        }
    }

    /// Counts the Sparx meter down one tick and applies its expiry, if this tick brings one.
    private mutating func runSparxMeter() {
        switch sparxMeter.tick() {
        case .release:
            sparx += Sparx.spawnAtTop(board, Tuning.extraSparx)
        case .super:
            for index in sparx.indices {
                sparx[index].kind = .super
            }
        case nil:
            break
        }
    }

    /// Fills the Sparx meter again and undoes its expiries: the Sparx it released are removed and
    /// the level's own are back to their kinds.
    private mutating func resetSparxMeter() {
        sparxMeter.reset()
        if sparx.count > levelSparx.count {
            sparx.removeSubrange(levelSparx.count...)
        }
        for (index, kind) in zip(sparx.indices, levelSparx) {
            sparx[index].kind = kind
        }
    }

    /// A Qix touches the stix or the marker drawing it; a marker on the border has no stix and is
    /// never hit.
    private func qixHitsPlayer() -> Bool {
        stix.map { QixKit.qixHitsPlayer(qix, $0, marker.pos) } ?? false
    }

    /// Burns the fuse one tick of a marker standing still on the stix, or puts it out when the
    /// marker stepped from `markerFrom` this tick or has no stix; a marker caught in a dead end
    /// lights it at once. Returns whether the fuse is at the marker, which kills it.
    private mutating func burnFuse(_ markerFrom: Point) -> Bool {
        guard let stix else {
            fuseTimer.putOut()
            return false
        }
        let head = stix.points.count - 1
        if marker.pos == markerFrom {
            fuseTimer.stand(head)
        } else {
            fuseTimer.putOut()
        }
        if fuseTimer.fuse == nil, legalMoves(marker, stix, board).isEmpty {
            fuseTimer.light()
        }
        return fuseTimer.reached(head)
    }

    /// Steps every Sparx on the border once every `Tuning.sparxStepTicks` ticks and every one
    /// chasing along the stix (see `Sparx.chasesAlong`) once every `Tuning.superSparxStepTicks`.
    /// Returns whether one of them touched the marker, which moved from `markerFrom` this tick:
    /// see `Sparx.hitsMarker`.
    private mutating func moveSparx(_ markerFrom: Point) -> Bool {
        let borderDue = countTo(&sparxTicks, Tuning.sparxStepTicks)
        let stixDue = countTo(&stixSparxTicks, Tuning.superSparxStepTicks)
        var hit = false
        for index in sparx.indices {
            let from = sparx[index].pos
            if let stix, sparx[index].chasesAlong(stix) {
                if stixDue {
                    sparx[index].stepAlongStix(stix)
                }
            } else if borderDue {
                sparx[index].step(board, &rng)
            }
            hit = sparx[index].hitsMarker(from, markerFrom, marker.pos) || hit
        }
        return hit
    }

    /// Moves every Sparx off the border to the border point nearest it.
    private mutating func snapSparxToBorder() {
        for index in sparx.indices {
            sparx[index].snapToBorder(board)
        }
    }

    /// Steps the marker once every `stepTicks` ticks the direction is held.
    ///
    /// While drawing, the marker stands still on the stix as long as no draw button is held;
    /// pressing one again restarts the step count. During the `grace` period the draw buttons are
    /// ignored. Returns whether a stix step reached the border across a Qix (see `draw`).
    private mutating func moveMarker(_ input: InputState, _ grace: Bool) -> Bool {
        let draw = grace ? nil : input.drawKind
        let stopped = marker.state == .drawing && draw == nil
        guard let dir = input.dir, !stopped else {
            markerHeldTicks = 0
            return false
        }
        markerHeldTicks += 1
        if markerHeldTicks < stepTicks(dir, draw) {
            return false
        }
        markerHeldTicks = 0
        let alongBorder = marker.state == .onBorder && marker.stepAlongBorder(board, dir)
        guard let kind = draw, !alongBorder else { return false }
        return self.draw(dir, kind)
    }

    /// The ticks a step towards `dir` takes with the draw button `draw` held:
    /// `Tuning.markerStepTicks` along the border, whatever the button, and the speed of the button
    /// for a step of the stix.
    private func stepTicks(_ dir: Dir, _ draw: DrawKind?) -> UInt32 {
        let alongBorder = marker.state == .onBorder && marker.borderStep(board, dir) != nil
        return draw == .slow && !alongBorder ? Tuning.slowStepTicks : Tuning.markerStepTicks
    }

    /// Draws one step of the stix towards `dir` with `kind`, starting a stix when the marker is on
    /// the border, and raises `Event.draw`; an illegal step leaves the marker where it is.
    ///
    /// A step onto a border point closes the stix (see `close`), unless a Qix touches the stix
    /// where it is now (see `qixTouchesStix`): it would lie across the closing segment, on cells
    /// the claim takes. The stix then stays, unclosed, and `draw` returns true: the step kills the
    /// player. Where the Qix was a tick ago does not count: the rest of the stix was checked
    /// against that move in the last tick, and the closing segment did not exist then.
    private mutating func draw(_ dir: Dir, _ kind: DrawKind) -> Bool {
        var stix = stix ?? Stix(start: marker.pos)
        self.stix = nil
        guard let next = legalStep(marker, stix, board, dir) else {
            self.stix = marker.state == .drawing ? stix : nil
            return false
        }
        stix.push(next, kind)
        marker.pos = next
        events.append(.draw(kind))
        let closes = board.isBorder(next)
        if closes, !qix.contains(where: { qixTouchesStix($0, stix) }) {
            close(stix)
            return false
        }
        marker.state = .drawing
        self.stix = stix
        return closes
    }

    /// Closes `stix`, which the marker has just drawn onto the border: the area it cuts off from
    /// every Qix is claimed and scored, raising `Event.claim` when it claims cells, the fuse is put
    /// out, the marker is back on the border, at the closing point, and a Sparx the claim left off
    /// the border (one that was on the stix, or one the claim cut off) snaps back to it. A stix
    /// leaving the Qix in different areas, or a claim taking the board to the threshold, completes
    /// the level.
    private mutating func close(_ stix: Stix) {
        let close = board.closeStix(stix, qix)
        if let claim = close.claim {
            events.append(.claim(cells: claim.cells, kind: claim.kind))
            addScore(scoreForClaim(claim, multiplier))
        }
        endLevelAfter(close)
        marker.state = .onBorder
        fuseTimer.putOut()
        snapSparxToBorder()
    }
}

/// Counts one more tick on `ticks` and returns whether it reached `period`, which starts the count
/// again.
private func countTo(_ ticks: inout UInt32, _ period: UInt32) -> Bool {
    ticks += 1
    let due = ticks >= period
    if due {
        ticks = 0
    }
    return due
}
