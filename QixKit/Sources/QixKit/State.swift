// The game state machine: the title screen, play, the pause, the end of a level, the end of the
// game and the entry of a high score, around one `Game` and the `HighScores` table.

/// Where the session stands, which decides what a tick does.
public enum GameState: Equatable, Sendable {
    /// The title screen, before a game starts: confirm starts it.
    case title
    /// The game ticks: pause pauses it, a completed level or the loss of the last life ends it.
    case playing
    /// The game is paused and does not tick: pause resumes it.
    case paused
    /// The level is complete, as its `Event.levelComplete` reported: confirm starts the next one.
    ///
    /// - `fraction`: the board's claimed fraction at the end, from 0 to 1.
    /// - `bonus`: the level bonus scored, zero after a split.
    /// - `split`: the level ended by splitting the Qix apart.
    case levelComplete(fraction: Float, bonus: UInt32, split: Bool)
    /// The last life is lost: confirm enters the initials of a score that makes the high score
    /// table, or goes back to the title screen with a new game.
    case gameOver
    /// The initials of the game's score are being entered: once they are, the score goes into the
    /// table and the title screen shows a new game.
    case highScoreEntry(InitialsEntry)
}

/// A `Game`, the `GameState` it is in, the high score table and the best score so far.
public struct Session: Sendable {
    /// The state the session is in.
    public private(set) var state: GameState
    /// The game being played, or about to be on the title screen.
    public private(set) var game: Game
    /// The high score table, with the scores entered this session.
    public private(set) var highScores: HighScores
    /// The best score of the high score table and of every game of the session, the one being
    /// played included: it rises with the score as soon as the score passes it.
    public private(set) var highScore: UInt32
    /// The last tick of the session ticked the game: `events` are that tick's.
    private(set) var played: Bool

    /// A session on the title screen, which starts `game` on confirm, with the table `highScores`
    /// of earlier sessions; an empty one by default, as Rust's `Session::new`.
    public init(game: Game, highScores: HighScores = HighScores()) {
        state = .title
        self.game = game
        highScore = highScores.best
        self.highScores = highScores
        played = false
    }

    /// The events the game raised during the last tick of the session, in the order they happened;
    /// none when that tick did not tick the game, even though `Game.events` still holds those of
    /// its last tick.
    public var events: [Event] {
        played ? game.events : []
    }

    /// Sets the rules of the games to come (see `Game.setRules`): on the title screen, the game it
    /// shows restarts with them; any other game keeps playing by its own.
    public mutating func setRules(_ rules: Rules) {
        game.setRules(rules)
        if state == .title {
            game.restart()
        }
    }

    /// Enters `name` at once as the initials of the game's score, as the iPhone's text field types
    /// them: in `GameState.highScoreEntry`, the score goes into the table and the title screen
    /// shows a new game, as when the entry's last letter is confirmed; any other state is left
    /// alone. Returns the score's rank in the table, nil when nothing was entered. qix-rs has no
    /// such call: its entry takes the letters one by one, through `tick`.
    @discardableResult
    public mutating func enterInitials(_ name: Initials) -> Int? {
        guard case .highScoreEntry = state else { return nil }
        let rank = highScores.insert(HighScore(name: name, score: game.score.points))
        state = restart()
        return rank
    }

    /// Advances the session by one step: `Game.tick` with `input` while `GameState.playing`, or the
    /// transition `input` asks for.
    ///
    /// A tick that changes the state with a press does not tick the game: the pause stops it
    /// before it moves, and the game a confirm starts (from the title, or the next level) first
    /// moves on the tick after it. A tick of the game raising `Event.gameOver` or
    /// `Event.levelComplete` ends play. Out of play, only those presses do anything, but for
    /// `GameState.highScoreEntry`, which hands every tick's input to its `InitialsEntry`: nothing
    /// ticks in `GameState.paused`. Every tick raises the high score to the game's score if that
    /// is higher.
    public mutating func tick(_ input: InputState) {
        played = false
        state = nextState(input)
        highScore = max(highScore, game.score.points)
    }

    /// The state this tick of `input` leads to, from `state`.
    private mutating func nextState(_ input: InputState) -> GameState {
        switch state {
        case .title where input.confirm:
            return .playing
        case .playing where input.pause:
            return .paused
        case .playing:
            return play(input)
        case .paused where input.pause:
            return .playing
        case .levelComplete where input.confirm:
            game.startLevel(game.level + 1)
            return .playing
        case .gameOver where input.confirm:
            return endGame()
        case var .highScoreEntry(entry):
            guard let name = entry.tick(input) else { return .highScoreEntry(entry) }
            highScores.insert(HighScore(name: name, score: game.score.points))
            return restart()
        case .title, .paused, .levelComplete, .gameOver:
            return state
        }
    }

    /// The state after the game over screen: the initials entry when the score makes the table,
    /// the title with a new game otherwise.
    private mutating func endGame() -> GameState {
        highScores.qualifies(game.score.points) ? .highScoreEntry(InitialsEntry()) : restart()
    }

    /// Starts a new game and returns the title screen that shows it.
    private mutating func restart() -> GameState {
        game.restart()
        return .title
    }

    /// Ticks the game with `input` and returns the state its events lead to.
    private mutating func play(_ input: InputState) -> GameState {
        game.tick(input)
        played = true
        for event in game.events {
            switch event {
            case .gameOver:
                return .gameOver
            case let .levelComplete(fraction, bonus, split):
                return .levelComplete(fraction: fraction, bonus: bonus, split: split)
            case .draw, .claim, .death, .extraLife:
                continue
            }
        }
        return .playing
    }
}
