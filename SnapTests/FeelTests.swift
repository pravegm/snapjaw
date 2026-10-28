import CoreGraphics
import Foundation
import Testing
@testable import Snap

// MARK: - Helpers
// R8: the hinge, filter and touch tests (and their fake hinge) moved to InputTests.swift (Core + Input owner).

/// Renders `seconds` of `synth` in stereo and reports the RMS (both channels), each channel's RMS, the peak, the share
/// of samples over 0.6 and whether every sample was finite. `each` runs before every 512-frame block.
private func feelRender(_ synth: FeelSynth, seconds: Double,
                        each: (Int, Double) -> Void = { _, _ in })
    -> (rms: Double, left: Double, right: Double, peak: Float, hot: Double, finite: Bool) {
    let frames = 512
    let left = UnsafeMutablePointer<Float>.allocate(capacity: frames)
    let right = UnsafeMutablePointer<Float>.allocate(capacity: frames)
    defer {
        left.deallocate()
        right.deallocate()
    }
    let blocks = max(Int(seconds * Double(synth.sampleRate) / Double(frames)), 1)
    var sumL: Double = 0
    var sumR: Double = 0
    var peak: Float = 0
    var hot = 0
    var finite = true
    for block in 0..<blocks {
        each(block, Double(block * frames) / Double(synth.sampleRate))
        synth.render(frames: frames, left: left, right: right)
        for index in 0..<frames {
            let l = left[index]
            let r = right[index]
            if !l.isFinite || !r.isFinite { finite = false }
            peak = max(peak, max(abs(l), abs(r)))
            sumL += Double(l * l)
            sumR += Double(r * r)
            if abs(l) > 0.6 || abs(r) > 0.6 { hot += 1 }
        }
    }
    let count = Double(blocks * frames)
    let rmsL = (sumL / count).squareRoot()
    let rmsR = (sumR / count).squareRoot()
    return (((sumL + sumR) / (2 * count)).squareRoot(), rmsL, rmsR, peak, Double(hot) / count, finite)
}

private func feelBite(caught: [BugSpecies], stingers: [BugSpecies] = []) -> BiteReport {
    BiteReport(caught: caught, escaped: 1, stingers: stingers, points: 120, countMultiplier: max(caught.count, 1),
               chainMultiplier: 1.5, snapsBack: caught.count >= 3 ? 1 : 0, snapsLost: stingers.isEmpty ? 0 : 1,
               duration: 0.1, time: 12)
}

/// R6: a bite of `caught` houseflies scored at `chain` (for the FEAST CHOMP's rule).
private func feelChainBite(caught: Int, chain: Double) -> BiteReport {
    BiteReport(caught: Array(repeating: BugSpecies.housefly, count: max(caught, 0)), escaped: 0, stingers: [],
               points: 100, countMultiplier: max(caught, 1), chainMultiplier: chain,
               snapsBack: caught >= 5 ? 2 : (caught >= 3 ? 1 : 0), snapsLost: 0, duration: 0.1, time: 20)
}

/// R6: a whole bite frame's events: the bite, one `bugCaught` per bug and (3+) the Feast.
private func feelBiteFrame(caught: Int, chain: Double) -> [TrapEvent] {
    var events: [TrapEvent] = [.snapped(feelChainBite(caught: caught, chain: chain))]
    for index in 0..<max(caught, 0) {
        events.append(.bugCaught(id: index + 1, species: .housefly,
                                 position: CGPoint(x: 200 + 60 * CGFloat(index), y: 300)))
    }
    if caught >= 3 {
        events.append(.feast(count: caught, snapsBack: caught >= 5 ? 2 : 1))
    }
    return events
}

private func feelBuzzers(_ count: Int, flying: Bool = true) -> [Buzzer] {
    var buzzers: [Buzzer] = []
    for index in 0..<count {
        let species = BugSpecies.allCases[index % BugSpecies.allCases.count]
        let pan = -1 + 2 * Double(index) / Double(max(count - 1, 1))
        buzzers.append(Buzzer(id: index + 1, species: species, pan: pan, height: 0.3, flying: flying))
    }
    return buzzers
}

/// Every trap event, at least once.
private let feelEveryEvent: [TrapEvent] = [
    .waveStarted(index: 3, phase: .noon), .dayPhaseChanged(.morning), .dayPhaseChanged(.noon),
    .dayPhaseChanged(.dusk), .dayPhaseChanged(.night),
    .bugArrived(id: 1, species: .housefly),
    .bugLanded(id: 1, species: .housefly, position: CGPoint(x: 300, y: 300), inTrap: true),
    .bugLanded(id: 2, species: .dragonfly, position: CGPoint(x: 900, y: 100), inTrap: false),
    .bugSipping(id: 1, species: .housefly), .bugHopped(id: 3, species: .grasshopper),
    .bugLeft(id: 4, species: .moth), .bugSpooked(id: 5, species: .bluebottle),
    .snapStarted, .snapped(feelBite(caught: [.housefly, .gnat, .ladybird], stingers: [.bee])),
    .bugCaught(id: 1, species: .housefly, position: CGPoint(x: 400, y: 330)),
    .bugCaught(id: 6, species: .gnat, position: CGPoint(x: 520, y: 300)),
    .bugCaught(id: 7, species: .ladybird, position: CGPoint(x: 600, y: 360)),
    .bugEscaped(id: 8, species: .mosquito), .stung(id: 9, species: .bee, cost: 1),
    .stung(id: 10, species: .wasp, cost: 2), .stung(id: 11, species: .bumblebee, cost: 1), .drySnap,
    .feast(count: 3, snapsBack: 1), .luckySnap(species: .ladybird), .luckySnap(species: .goldenScarab),
    .chainUp(count: 3, multiplier: 2), .chainBroken(count: 4), .rearmed, .beeSpared(species: .bee),
    .beeSpared(species: .wasp), .lastSnap, .hungry(secondsLeft: 3), .wilted(snapsLeft: 4), .tired, .newBest, .finished,
]

private let feelPentatonic: Set<Int> = [0, 2, 4, 7, 9]

@MainActor
struct FeelTests {
    // R8: the snap path, filter, closing-gate and touch tests moved to InputTests.swift.

    // MARK: - Recipes

    @Test func everyRecipeIsSane() {
        var dice = FeelDice(seed: 11)
        var recipes: [[FeelSynthCommand]] = [
            FeelSoundBook.lastSnap(), FeelSoundBook.lastSnap(delay: 0.75), FeelSoundBook.tired(),
            FeelSoundBook.tired(delay: 0.9), FeelSoundBook.newBest(), FeelSoundBook.newBest(delay: 0.6),
            FeelSoundBook.uiTap(), FeelSoundBook.uiConfirm(),
        ]
        for caught in 0...9 {
            recipes.append(FeelSoundBook.chomp(caught: caught, dice: &dice))
        }
        recipes.append(FeelSoundBook.chomp(caught: 1, dice: &dice, scale: FeelSoundBook.homeChompScale))
        recipes.append(FeelSoundBook.drySnap(dice: &dice))
        for index in 0..<12 {
            recipes.append(FeelSoundBook.crunch(index: index, pan: -0.5, dice: &dice))
        }
        for count in [3, 4, 5, 9] {
            for back in 0...2 {
                recipes.append(FeelSoundBook.feast(count: count, snapsBack: back, dice: &dice))
            }
        }
        for count in [0, 1, 2, 5, 8, 40] {
            recipes.append(FeelSoundBook.chainUp(count: count, dice: &dice))
            recipes.append(FeelSoundBook.chainUp(count: count, delay: FeelSoundBook.chainAt, dice: &dice))
        }
        recipes.append(FeelSoundBook.chainBroken(dice: &dice))
        recipes.append(FeelSoundBook.chainBroken(delay: 0.75, dice: &dice))
        recipes.append(FeelSoundBook.snapWhoosh(dice: &dice))
        recipes.append(FeelSoundBook.rearmPluck(dice: &dice))
        recipes.append(FeelSoundBook.celebrate(dice: &dice))
        recipes.append(FeelSoundBook.sip(pan: 0.4, dice: &dice))
        recipes.append(FeelSoundBook.hop(pan: -0.4, dice: &dice))
        recipes.append(FeelSoundBook.whiff(pan: 0.8, delay: 0.05, dice: &dice))
        recipes.append(FeelSoundBook.spooked(pan: -0.8, dice: &dice))
        recipes.append(FeelSoundBook.hungry(dice: &dice))
        recipes.append(FeelSoundBook.wilted(dice: &dice))
        recipes.append(FeelSoundBook.wilted(delay: 0.4, dice: &dice))
        recipes.append(FeelSoundBook.crunch(index: 6, pan: 0.5, light: true, dice: &dice))
        for cost in [0, 1, 2, 5] {
            recipes.append(FeelSoundBook.snapLost(cost: cost, delay: 0.46, dice: &dice))
        }
        recipes.append(FeelSoundBook.snapLost(delay: Float.nan, dice: &dice))
        recipes.append(FeelSoundBook.oops(dice: &dice))
        recipes.append(FeelSoundBook.oops(delay: 0.46, dice: &dice))
        recipes.append(FeelSoundBook.chainFlare(dice: &dice))
        recipes.append(FeelSoundBook.chainFlare(delay: FeelSoundBook.chainAt + FeelSoundBook.flareAfter, dice: &dice))
        for phase in DayPhase.allCases {
            recipes.append(FeelSoundBook.dayChime(phase, dice: &dice))
        }
        // R6: the FEAST CHOMP and its parts, the goal chime and the variety fanfare.
        for caught in 0...9 {
            recipes.append(FeelSoundBook.feastChomp(caught: caught, dice: &dice))
        }
        for index in 0..<12 {
            recipes.append(FeelSoundBook.crunch(index: index, pan: 0.3, cascade: true, dice: &dice))
            recipes.append(FeelSoundBook.crunch(index: index, pan: -0.3, light: true, cascade: true, dice: &dice))
        }
        recipes.append(FeelSoundBook.feastSting(dice: &dice))
        recipes.append(FeelSoundBook.feastSting(delay: Float.nan, dice: &dice))
        recipes.append(FeelSoundBook.burp(dice: &dice))
        recipes.append(FeelSoundBook.burp(delay: -1, dice: &dice))
        recipes.append(FeelSoundBook.goalChime(dice: &dice))
        recipes.append(FeelSoundBook.goalChime(bonus: true, delay: FeelSoundBook.goalAfterBite, dice: &dice))
        recipes.append(FeelSoundBook.goalChime(delay: Float.nan, dice: &dice))
        recipes.append(FeelSoundBook.varietyFanfare(dice: &dice))
        recipes.append(FeelSoundBook.varietyFanfare(delay: 0.8, dice: &dice))
        for species in BugSpecies.allCases {
            recipes.append(FeelSoundBook.landingTik(species, inTrap: true, pan: 0.2, dice: &dice))
            recipes.append(FeelSoundBook.landingTik(species, inTrap: false, pan: -0.2, dice: &dice))
            recipes.append(FeelSoundBook.lucky(species, dice: &dice))
            recipes.append(FeelSoundBook.sting(species, pan: 0.3, delay: FeelSoundBook.stingAt, dice: &dice))
            recipes.append(FeelSoundBook.spared(species, pan: -0.3, dice: &dice))
        }
        for recipe in recipes {
            #expect(!recipe.isEmpty)
            for command in recipe {
                #expect(command.gain.isFinite)
                #expect(command.gain > 0)
                #expect(command.gain <= 0.4)
                #expect(command.delay >= 0)
                #expect(command.delay < 3)
                #expect(command.pan >= -1)
                #expect(command.pan <= 1)
            }
        }
    }

    @Test func theChompIsTheHeroAndGrowsWithTheBite() {
        var dice = FeelDice(seed: 3)
        let chompPeak = FeelSoundBook.chomp(caught: 1, dice: &dice).map { $0.gain }.max() ?? 0
        let tikPeak = FeelSoundBook.landingTik(.dragonfly, inTrap: true, pan: 0, dice: &dice).map { $0.gain }.max() ?? 1
        let sipPeak = FeelSoundBook.sip(pan: 0, dice: &dice).map { $0.gain }.max() ?? 1
        #expect(chompPeak > tikPeak * 3)
        #expect(chompPeak > sipPeak * 3)
        // The squelch tail: 120 ms + 60 ms per bug.
        #expect(abs(FeelSoundBook.squelchLength(caught: 1) - 0.18) < 1e-6)
        #expect(abs(FeelSoundBook.squelchLength(caught: 5) - 0.42) < 1e-6)
        func squelch(_ commands: [FeelSynthCommand]) -> FeelSquelchSpec? {
            for command in commands {
                if case .squelch(let spec) = command { return spec }
            }
            return nil
        }
        let one = squelch(FeelSoundBook.chomp(caught: 1, dice: &dice))
        let five = squelch(FeelSoundBook.chomp(caught: 5, dice: &dice))
        #expect(one != nil)
        #expect(five != nil)
        if let one, let five {
            #expect(five.duration > one.duration)
            #expect(five.gain >= one.gain)
        }
        // An empty clap has no squelch and no gulp, and is smaller.
        let dry = FeelSoundBook.drySnap(dice: &dice)
        #expect(squelch(dry) == nil)
        let dryPeak = dry.map { $0.gain }.max() ?? 1
        #expect(dryPeak < chompPeak)
    }

    @Test func everyChompIsALittleDifferent() {
        var dice = FeelDice(seed: 5)
        var thumps: [Float] = []
        var gaps: [Float] = []
        var all: [[FeelSynthCommand]] = []
        for _ in 0..<40 {
            let chomp = FeelSoundBook.chomp(caught: 2, dice: &dice)
            all.append(chomp)
            var woodDelays: [Float] = []
            for command in chomp {
                switch command {
                case .tone(let spec) where spec.delay == 0:
                    thumps.append(spec.start)
                case .ring(let spec) where spec.kind == .wood:
                    woodDelays.append(spec.delay)
                default:
                    break
                }
            }
            if woodDelays.count >= 2 {
                gaps.append(woodDelays[1] - woodDelays[0])
            }
        }
        #expect(thumps.count == 40)
        #expect(gaps.count == 40)
        // Pitch within ±4 % of 90 Hz, click spacing within 18 ± 3 ms, and they really vary.
        for f in thumps {
            #expect(f >= 90 * 0.96 - 0.001)
            #expect(f <= 90 * 1.04 + 0.001)
        }
        for gap in gaps {
            #expect(gap >= 0.015 - 1e-4)
            #expect(gap <= 0.021 + 1e-4)
        }
        let spread = (thumps.max() ?? 0) - (thumps.min() ?? 0)
        #expect(spread > 3)
        #expect(all[0] != all[1])
    }

    @Test func buzzTimbresFollowTheSpecies() {
        #expect(FeelSoundBook.timbre(.bee, flying: true) == .bee)
        #expect(FeelSoundBook.timbre(.bee, flying: false) == .bee)
        #expect(FeelSoundBook.timbre(.mosquito, flying: true) == .mosquito)
        #expect(FeelSoundBook.timbre(.ant, flying: false) == .silent)
        #expect(FeelSoundBook.timbre(.cricket, flying: false) == .cricket)
        #expect(FeelSoundBook.timbre(.cricket, flying: true) == .hopper)
        #expect(FeelSoundBook.timbre(.ladybird, flying: false) == .silent)
        // Flying and low is loudest; landed bugs are quieter.
        let high = FeelSoundBook.buzzLevel(.housefly, flying: true, height: 1)
        let low = FeelSoundBook.buzzLevel(.housefly, flying: true, height: 0)
        let landed = FeelSoundBook.buzzLevel(.housefly, flying: false, height: 0)
        #expect(low > high)
        #expect(high > landed)
        #expect(abs(low - 1) < 1e-9)
        for id in -5...200 {
            let pitch = FeelSoundBook.bugPitch(id: id)
            #expect(pitch >= 0.94)
            #expect(pitch <= 1.06)
        }
        #expect(FeelSoundBook.bugPitch(id: 3) == FeelSoundBook.bugPitch(id: 3))
        #expect(FeelSoundBook.pan(x: 0, width: 952) < -0.7)
        #expect(FeelSoundBook.pan(x: 952, width: 952) > 0.7)
        #expect(abs(FeelSoundBook.pan(x: 476, width: 952)) < 1e-6)
        #expect(FeelSoundBook.pan(x: Double.nan, width: 952) == 0)
        let gains = FeelSynth.panGains(0)
        #expect(abs(gains.left - 1) < 1e-6)
        #expect(abs(gains.right - 1) < 1e-6)
        let hard = FeelSynth.panGains(1)
        #expect(hard.left < 1e-6)
        #expect(FeelSynth.panGains(Float.nan).left == 1)
    }

    @Test func theBuzzMixerKeepsSlotsStableAndFadesBeforeReuse() {
        var mixer = FeelBuzzMixer()
        // Twelve flying bugs: only the eight loudest get a voice.
        var crowd: [Buzzer] = []
        for index in 0..<12 {
            let height = Double(index) / 12
            crowd.append(Buzzer(id: 100 + index, species: .housefly, pan: 0, height: height, flying: true))
        }
        let first = mixer.update(buzzers: crowd, share: 1, now: 0)
        #expect(first.count == FeelSynth.buzzSlots)
        let ids = mixer.ids.compactMap { $0 }
        #expect(ids.count == 8)
        #expect(ids.allSatisfy { $0 < 108 })
        // The same bugs next frame keep their slots.
        let before = mixer.ids
        _ = mixer.update(buzzers: crowd, share: 1, now: 0.016)
        #expect(mixer.ids == before)
        // One bug leaves: its slot fades and is not reused at once.
        let gone = crowd.filter { $0.id != 100 }
        let newcomer = Buzzer(id: 500, species: .bee, pan: 0.5, height: 0, flying: true)
        let slotOfGone = before.firstIndex(where: { $0 == 100 })
        _ = mixer.update(buzzers: gone + [newcomer], share: 1, now: 0.03)
        if let slot = slotOfGone {
            #expect(mixer.ids[slot] == nil)
            #expect(mixer.targets[slot].level == 0)
        }
        // After the fade the newcomer gets the slot.
        _ = mixer.update(buzzers: gone + [newcomer], share: 1, now: 0.2)
        #expect(mixer.ids.contains(where: { $0 == 500 }))
        // Silent species never take a slot; everyone gone → all fading.
        _ = mixer.update(buzzers: [Buzzer(id: 900, species: .ant, pan: 0, height: 0, flying: false)], share: 1,
                         now: 0.4)
        #expect(mixer.ids.allSatisfy { $0 == nil })
        #expect(mixer.targets.allSatisfy { $0.level == 0 })
    }

    // MARK: - The bed

    @Test func theBedFollowsTheTrapAndTheDay() {
        let creep = TrapTelemetry(closure: 14, creeping: true, buzzers: [], chain: 5, dayClock: 0.5, playing: true)
        let bed = FeelSoundBook.playBed(telemetry: creep, master: 1, ambience: 1)
        #expect(bed.groan > 0.55)
        #expect(bed.groanHz > 70)
        #expect(bed.groanHz < 140)
        #expect(bed.music == 1)
        #expect(bed.musicVoices == 3)
        #expect(bed.wind > 0)
        #expect(bed.crickets == 0)
        let calm = TrapTelemetry(closure: 14, creeping: false, buzzers: [], chain: 0, dayClock: 3.6, playing: true)
        let night = FeelSoundBook.playBed(telemetry: calm, master: 1, ambience: 1)
        #expect(night.groan == 0)
        #expect(night.musicVoices == 1)
        #expect(night.crickets > 0.9)
        #expect(night.wind < bed.wind)
        let menu = FeelSoundBook.playBed(telemetry: TrapTelemetry(), master: 1, ambience: 0)
        #expect(menu.hasLayers == false)
        #expect(FeelSoundBook.musicVoices(chain: 2) == 2)
        #expect(FeelSoundBook.musicVoices(chain: 6) == 4)
        #expect(FeelSoundBook.musicVoices(chain: 7) == 4)
        #expect(FeelSoundBook.musicVoices(chain: 8) == 5)
        #expect(FeelSoundBook.musicVoices(chain: 60) == 5)
        #expect(FeelSoundBook.groanLevel(closure: 30, creeping: false) == 0)
        // R8: the groan stretches over the whole close (8° … 120°).
        #expect(abs(FeelSoundBook.groanLevel(closure: FeelSoundBook.closeFull, creeping: true) - 1) < 1e-9)
        #expect(abs(FeelSoundBook.groanLevel(closure: FeelSoundBook.closeFrom, creeping: true) - 0.55) < 1e-9)
        #expect(FeelSoundBook.groanLevel(closure: 60, creeping: true)
                < FeelSoundBook.groanLevel(closure: 100, creeping: true))
        #expect(FeelSoundBook.groanLevel(closure: Double.nan, creeping: true) == 0)
        let weird = TrapTelemetry(closure: Double.nan, creeping: true, buzzers: [], chain: -3,
                                  dayClock: Double.infinity, playing: true)
        let safe = FeelSoundBook.playBed(telemetry: weird, master: 1, ambience: 1)
        #expect(safe.groan.isFinite)
        #expect(safe.groanHz.isFinite)
        #expect(safe.crickets.isFinite)
        #expect(safe.wind.isFinite)
    }

    @Test func theMarimbaLoopIsPentatonicAndGrowsAVoiceAtATime() {
        for voice in 0..<FeelSynth.musicVoiceCount {
            var notes = 0
            for step in 0..<FeelSynth.musicSteps {
                if let note = FeelSynth.musicNote(voice: voice, step: step) {
                    notes += 1
                    let pitchClass = ((note % 12) + 12) % 12
                    #expect(feelPentatonic.contains(pitchClass))
                }
            }
            #expect(notes >= 8)
        }
        #expect(FeelSynth.musicNote(voice: FeelSynth.musicVoiceCount, step: 0) == nil)
        #expect(FeelSynth.musicNote(voice: 0, step: FeelSynth.musicSteps) == nil)
        for chain in 0...9 {
            let voices = FeelSoundBook.musicVoices(chain: chain)
            #expect(voices >= 1)
            #expect(voices <= Float(FeelSynth.musicVoiceCount))
        }
    }

    // MARK: - The synth

    @Test func tenSecondsOfMixedEventsNeverClipOrNaN() {
        let synth = FeelSynth(sampleRate: 48_000)
        var dice = FeelDice(seed: 9)
        var mixer = FeelBuzzMixer()
        let blocksPerSecond = 48_000.0 / 512
        var nextCue = 0.0
        var cueIndex = 0
        let result = feelRender(synth, seconds: 10) { block, t in
            // A whole day in 10 s: the bog, a crowd buzzing, a creep, the chain climbing, bites of every size.
            let creeping = t > 2 && t < 3.5
            let telemetry = TrapTelemetry(closure: creeping ? 6 + 10 * (t - 2) : 2, creeping: creeping,
                                          buzzers: feelBuzzers(1 + Int(t) % 9), chain: Int(t) % 8,
                                          dayClock: t * 0.4, playing: true)
            if block % max(Int(blocksPerSecond / 60), 1) == 0 {
                synth.send(.bed(FeelSoundBook.playBed(telemetry: telemetry, master: FeelAudioEngine.masterGain,
                                                      ambience: 1)))
                let targets = mixer.update(buzzers: telemetry.buzzers, share: 1, now: t)
                for (slot, target) in targets.enumerated() {
                    synth.send(.buzz(slot: slot, buzz: target))
                }
            }
            if t >= nextCue {
                nextCue += 0.3
                cueIndex += 1
                var cue: [FeelSynthCommand]
                switch cueIndex % 8 {
                case 0: cue = FeelSoundBook.chomp(caught: 1 + cueIndex % 7, dice: &dice)
                case 1: cue = FeelSoundBook.drySnap(dice: &dice)
                case 2: cue = FeelSoundBook.feast(count: 5, snapsBack: 2, dice: &dice)
                case 3: cue = FeelSoundBook.sting(.wasp, pan: 0.5, delay: FeelSoundBook.stingAt, dice: &dice)
                case 4: cue = FeelSoundBook.lucky(.goldenScarab, dice: &dice)
                case 5: cue = FeelSoundBook.landingTik(.bumblebee, inTrap: true, pan: -0.6, dice: &dice)
                case 6: cue = FeelSoundBook.chainUp(count: cueIndex, delay: FeelSoundBook.chainAt, dice: &dice)
                default: cue = FeelSoundBook.celebrate(dice: &dice)
                }
                for index in 0..<3 {
                    cue.append(contentsOf: FeelSoundBook.crunch(index: index, pan: 0.2, dice: &dice))
                }
                for command in cue { synth.send(command) }
            }
        }
        #expect(result.finite)
        #expect(result.peak < 1.0)
        #expect(synth.peak < 1.0)
        #expect(result.rms > 0.01)
        // The limiter is a safety net, not the mix: almost nothing sits above 0.6.
        #expect(result.hot < 0.02)
    }

    @Test func aHotPileUpStillNeverClips() {
        let synth = FeelSynth(sampleRate: 44_100)
        let telemetry = TrapTelemetry(closure: 21, creeping: true, buzzers: feelBuzzers(8), chain: 9, dayClock: 3.5,
                                      playing: true)
        var bed = FeelSoundBook.playBed(telemetry: telemetry, master: FeelAudioEngine.masterGain, ambience: 1)
        bed.glide = 0.01
        synth.send(.bed(bed))
        for slot in 0..<FeelSynth.buzzSlots {
            synth.send(.buzz(slot: slot, buzz: FeelBuzz(timbre: .bluebottle, level: 1, pan: 0, pitch: 1)))
        }
        var dice = FeelDice(seed: 5)
        for _ in 0..<4 {
            for command in FeelSoundBook.chomp(caught: 8, dice: &dice) { synth.send(command) }
        }
        for index in 0..<20 {
            synth.send(.ring(FeelRingSpec(.bell, fundamental: 300 + Float(index) * 37, partials: 6, decay: 0.5,
                                          gain: 2)))
            synth.send(.squelch(FeelSquelchSpec(duration: 0.5, gain: 2)))
        }
        let result = feelRender(synth, seconds: 2)
        #expect(result.finite)
        #expect(result.peak < 1)
        #expect(synth.peak < 1)
        #expect(synth.renderCallbacks > 0)
    }

    @Test func synthIsSilentWithMasterAtZero() {
        let synth = FeelSynth(sampleRate: 48_000)
        let telemetry = TrapTelemetry(closure: 12, creeping: true, buzzers: feelBuzzers(4), chain: 4, dayClock: 3.5,
                                      playing: true)
        var bed = FeelSoundBook.playBed(telemetry: telemetry, master: 0, ambience: 1)
        bed.glide = 0.01
        synth.send(.bed(bed))
        synth.send(.buzz(slot: 0, buzz: FeelBuzz(timbre: .bee, level: 1, pan: 0, pitch: 1)))
        var dice = FeelDice(seed: 1)
        for command in FeelSoundBook.chomp(caught: 3, dice: &dice) { synth.send(command) }
        let result = feelRender(synth, seconds: 0.5)
        #expect(result.peak < 0.0001)
    }

    @Test func eachContinuousLayerIsAudibleButGentle() {
        var beds: [FeelBed] = []
        var groan = FeelSoundBook.idleBed(master: FeelAudioEngine.masterGain, glide: 0.01)
        groan.groan = 1
        groan.groanHz = 110
        beds.append(groan)
        var wind = FeelSoundBook.idleBed(master: FeelAudioEngine.masterGain, glide: 0.01)
        wind.wind = 1
        beds.append(wind)
        var frogs = FeelSoundBook.idleBed(master: FeelAudioEngine.masterGain, glide: 0.01)
        frogs.frogs = 1
        frogs.dripRate = 2
        beds.append(frogs)
        var crickets = FeelSoundBook.idleBed(master: FeelAudioEngine.masterGain, glide: 0.01)
        crickets.crickets = 1
        beds.append(crickets)
        var music = FeelSoundBook.idleBed(master: FeelAudioEngine.masterGain, glide: 0.01)
        music.music = 1
        music.musicVoices = 5
        beds.append(music)
        for bed in beds {
            let synth = FeelSynth(sampleRate: 48_000)
            synth.send(.bed(bed))
            let result = feelRender(synth, seconds: 4.5)
            #expect(result.finite)
            #expect(result.rms > 0.0005)
            // A bed, not a moment: under −20 dBFS RMS.
            #expect(result.rms < 0.1)
            #expect(result.peak < 0.9)
        }
    }

    @Test func everyBuzzTimbreSoundsAndThePanIsHeard() {
        for timbre in FeelBuzzTimbre.allCases where timbre != .silent {
            let synth = FeelSynth(sampleRate: 48_000)
            synth.send(.bed(FeelSoundBook.idleBed(master: FeelAudioEngine.masterGain, glide: 0.01)))
            synth.send(.buzz(slot: 3, buzz: FeelBuzz(timbre: timbre, level: 1, pan: 0, pitch: 1)))
            let result = feelRender(synth, seconds: 1.5)
            #expect(result.finite)
            #expect(result.rms > 0.0005)
            #expect(result.rms < 0.1)
            #expect(result.peak < 0.9)
        }
        // A bee at the right is louder on the right.
        let synth = FeelSynth(sampleRate: 48_000)
        synth.send(.bed(FeelSoundBook.idleBed(master: FeelAudioEngine.masterGain, glide: 0.01)))
        synth.send(.buzz(slot: 0, buzz: FeelBuzz(timbre: .bee, level: 1, pan: 0.8, pitch: 1)))
        let panned = feelRender(synth, seconds: 1)
        #expect(panned.right > panned.left * 2)
        // Switching a slot's timbre goes through silence and never blows up.
        synth.send(.buzz(slot: 0, buzz: FeelBuzz(timbre: .mosquito, level: 1, pan: -0.8, pitch: 1.05)))
        let switched = feelRender(synth, seconds: 1)
        #expect(switched.finite)
        #expect(switched.left > switched.right)
        synth.send(.stopAll)
        let stopped = feelRender(synth, seconds: 0.3)
        #expect(stopped.peak < 0.01)
    }

    @Test func monoRenderMatchesTheStereoSum() {
        let synth = FeelSynth(sampleRate: 48_000)
        synth.send(.bed(FeelSoundBook.idleBed(master: FeelAudioEngine.masterGain, glide: 0.01)))
        var dice = FeelDice(seed: 2)
        for command in FeelSoundBook.chomp(caught: 2, dice: &dice) { synth.send(command) }
        let buffer = UnsafeMutablePointer<Float>.allocate(capacity: 512)
        defer { buffer.deallocate() }
        var finite = true
        var peak: Float = 0
        for _ in 0..<60 {
            synth.render(frames: 512, into: buffer)
            for index in 0..<512 {
                if !buffer[index].isFinite { finite = false }
                peak = max(peak, abs(buffer[index]))
            }
        }
        #expect(finite)
        #expect(peak > 0.01)
        #expect(peak < 1)
    }

    @Test func commandQueueDropsInsteadOfBlockingWhenFull() {
        let synth = FeelSynth(sampleRate: 48_000)
        var accepted = 0
        for _ in 0..<(FeelSynth.queueCapacity * 2) {
            if synth.send(.stopAll) { accepted += 1 }
        }
        #expect(accepted == FeelSynth.queueCapacity - 1)
    }

    @Test func theCricketChirpGateHasThreePulses() {
        var edges = 0
        var last: Float = 0
        var t: Float = 0
        while t < 0.6 {
            let gate = FeelSynth.chirpGate(t)
            if gate > 0.5 && last < 0.5 { edges += 1 }
            last = gate
            t += 0.0005
        }
        #expect(edges == 3)
        #expect(FeelSynth.chirpGate(-1) == 0)
    }

    // MARK: - Haptics

    @Test func theChompIsTheHeaviestHapticAndGrowsWithTheBite() {
        let one = FeelHapticBook.chomp(caught: 1)
        let five = FeelHapticBook.chomp(caught: 5)
        let peak = one.notes.map { $0.intensity }.max() ?? 0
        #expect(peak == 1)
        #expect(five.length > one.length - 1e-9)
        #expect(FeelHapticBook.rumbleLength(caught: 5) > FeelHapticBook.rumbleLength(caught: 1))
        #expect(abs(FeelHapticBook.rumbleLength(caught: 0) - 0.09) < 1e-9)
        let fiveRumble = five.notes.filter { $0.kind == .continuous }.map { $0.intensity }.max() ?? 0
        let oneRumble = one.notes.filter { $0.kind == .continuous }.map { $0.intensity }.max() ?? 0
        #expect(fiveRumble > oneRumble)
        let cues: [FeelHapticCue] = [
            FeelHapticBook.drySnap, FeelHapticBook.feast, FeelHapticBook.sting(), FeelHapticBook.sting(at: 0.06),
            FeelHapticBook.lucky(), FeelHapticBook.rearm, FeelHapticBook.spared, FeelHapticBook.lastSnap(),
            FeelHapticBook.tired(), FeelHapticBook.newBest(), FeelHapticBook.uiTap, FeelHapticBook.uiConfirm,
            FeelHapticBook.celebrate, FeelHapticBook.landing(.gnat), FeelHapticBook.landing(.dragonfly),
            FeelHapticBook.chomp(caught: 0), one, five, FeelHapticBook.chomp(caught: 99), FeelHapticBook.hungry,
            FeelHapticBook.wilted(), FeelHapticBook.wilted(at: 0.7), FeelHapticBook.sting(at: 0.06, heavy: true),
            FeelHapticBook.snapLost(), FeelHapticBook.snapLost(at: 0.46), FeelHapticBook.oops(at: 0.46),
            FeelHapticBook.chainFlare(at: 0.56), FeelHapticBook.chomp(caught: 2),
        ]
        for cue in cues {
            #expect(!cue.notes.isEmpty)
            #expect(cue.curve.count <= 16)
            for note in cue.notes {
                #expect(note.intensity >= 0 && note.intensity <= 1)
                #expect(note.sharpness >= 0 && note.sharpness <= 1)
                #expect(note.time >= 0)
            }
            // Nothing else hits harder on its first tap than the CHOMP.
            let first = cue.notes.first { $0.kind == .transient }?.intensity ?? 0
            #expect(first <= peak)
        }
        // A dry snap is lighter than a CHOMP's slam.
        let dryFirst = FeelHapticBook.drySnap.notes.first { $0.kind == .transient }?.intensity ?? 1
        #expect(dryFirst < peak)
        // Landing ticks scale with the bug.
        let gnat = FeelHapticBook.landing(.gnat).notes.first?.intensity ?? 1
        let dragonfly = FeelHapticBook.landing(.dragonfly).notes.first?.intensity ?? 0
        #expect(dragonfly > gnat)
        // Strong turns taps into bursts the Duo's weak actuator can push.
        let strong = FeelHapticBook.adapt(one, to: .strong)
        #expect(strong.notes.allSatisfy { $0.kind == .continuous })
        #expect(FeelHapticBook.adapt(FeelHapticBook.rearm, to: .normal) == FeelHapticBook.rearm)
        #expect(FeelHapticProfile.defaultFor(hasFold: true) == .strong)
        // Delaying a cue shifts every note.
        let later = FeelHapticBook.rearm.delayed(by: 0.25)
        #expect(abs((later.notes.first?.time ?? 0) - 0.25) < 1e-9)
    }

    @Test func theCreepTextureFollowsTheClosure() {
        #expect(FeelHapticBook.creepLevel(closure: 20, creeping: false) == 0)
        #expect(FeelHapticBook.creepLevel(closure: Double.nan, creeping: true) == 0)
        var previous: Float = 0
        // R8: over the whole close, from Core's close start to near the shut.
        var closure = FeelSoundBook.closeFrom
        while closure <= FeelSoundBook.closeFull + 10 {
            let level = FeelHapticBook.creepLevel(closure: closure, creeping: true)
            #expect(level >= previous)
            #expect(level > 0)
            #expect(level <= 1)
            previous = level
            closure += 2
        }
        #expect(FeelHapticBook.creepLevel(closure: 15, creeping: true, profile: .off) == 0)
        let normal = FeelHapticBook.creepLevel(closure: 15, creeping: true, profile: .normal)
        let strong = FeelHapticBook.creepLevel(closure: 15, creeping: true, profile: .strong)
        #expect(strong > normal)
        #expect(FeelHapticBook.stretchLevel(2, profile: .strong) <= 1)
    }

    // MARK: - Home's title trap

    @Test func theHomeStretchFollowsAClosingHingeOnly() {
        var meter = FeelStretchMeter()
        var t = 0.0
        _ = meter.update(closure: 0, at: t)
        // Held open: silent.
        for _ in 0..<60 {
            t += 1.0 / 60
            let level = meter.update(closure: 0, at: t)
            #expect(level == 0)
        }
        // Closing at 60°/s: it stretches.
        var closure = 0.0
        var loudest = 0.0
        for _ in 0..<20 {
            t += 1.0 / 60
            closure += 1
            loudest = max(loudest, meter.update(closure: closure, at: t))
        }
        #expect(loudest > 0.2)
        #expect(loudest <= 1)
        // Opening again: it fades to nothing.
        var level = 1.0
        for _ in 0..<60 {
            t += 1.0 / 60
            closure = max(closure - 1, 0)
            level = meter.update(closure: closure, at: t)
        }
        #expect(level < 0.01)
        let nan = meter.update(closure: Double.nan, at: t)
        #expect(nan == 0)
    }

    // MARK: - The director

    /// Sound and haptics off: the director takes a whole run's worth of events and frames, Home's trap, the menu
    /// sounds, idling and silences without starting any engine or crashing.
    @Test func directorHandlesEverythingWithFeedbackOff() {
        let director = FeedbackDirector()
        director.soundOn = false
        director.hapticsOn = false
        director.respectSilentSwitch = true
        director.sceneWidth = 1120
        director.start()
        director.start()
        director.handle([], telemetry: TrapTelemetry())
        for frame in 0..<360 {
            let t = Double(frame) / 120
            let creeping = frame > 100 && frame < 200
            let telemetry = TrapTelemetry(closure: creeping ? 10 : 1, creeping: creeping,
                                          buzzers: feelBuzzers(frame % 11), chain: frame / 60, dayClock: t,
                                          playing: true)
            director.handle(frame == 30 ? feelEveryEvent : [], telemetry: telemetry)
        }
        director.handle([.snapped(feelBite(caught: [])), .drySnap], telemetry: TrapTelemetry(playing: true))
        director.handle([.tired], telemetry: TrapTelemetry(playing: false))
        director.handle([.finished], telemetry: TrapTelemetry())
        director.idle = true
        for frame in 0..<60 {
            director.homeTrap(closure: Double(frame % 30), snapped: frame == 25 || frame == 26)
        }
        director.uiTap()
        director.uiConfirm()
        director.celebrate()
        director.silence()
        director.silence()
        director.idle = false
        #expect(director.soundOn == false)
        #expect(director.hapticsOn == false)
        #expect(director.respectSilentSwitch)
        #expect(director.idle == false)
        // The bite with three caught, and Home's one chomp (the refractory swallowed the second frame).
        #expect(director.chomps == 2)
    }

    @Test func directorEdgeCasesDoNotCrash() {
        let director = FeedbackDirector()
        director.soundOn = false
        director.hapticsOn = false
        director.sceneWidth = Double.nan
        let weird = TrapTelemetry(closure: Double.nan, creeping: true,
                                  buzzers: [Buzzer(id: -1, species: .bee, pan: Double.nan, height: Double.infinity,
                                                   flying: true)],
                                  chain: Int.max, dayClock: -Double.infinity, playing: true)
        var burst: [TrapEvent] = []
        for id in 0..<40 {
            burst.append(.bugLanded(id: id, species: .gnat, position: CGPoint(x: CGFloat(id * 30), y: 10),
                                    inTrap: id % 2 == 0))
            burst.append(.bugSpooked(id: id, species: .gnat))
            burst.append(.bugEscaped(id: id, species: .gnat))
        }
        burst.append(.snapped(feelBite(caught: Array(repeating: .housefly, count: 30))))
        director.handle(burst, telemetry: weird)
        director.homeTrap(closure: Double.nan, snapped: true)
        director.homeTrap(closure: -40, snapped: false)
        director.silence()
        director.handle([], telemetry: weird)
        let bed = FeelSoundBook.playBed(telemetry: weird, master: 1, ambience: 1)
        #expect(bed.groan.isFinite)
        #expect(bed.musicVoices == 5)
        let buzz = FeelSoundBook.buzz(for: weird.buzzers[0], share: 1)
        #expect(buzz.level.isFinite)
        #expect(buzz.pan == 0)
    }

    @Test func hapticsToggleRestoresTheProfile() {
        let director = FeedbackDirector()
        director.soundOn = false
        director.hapticsOn = false
        #expect(director.hapticsOn == false)
        director.deviceHasFold = true
        director.hapticsOn = true
        #expect(director.hapticProfile == .strong)
        director.hapticProfile = .normal
        director.hapticsOn = false
        director.hapticsOn = true
        #expect(director.hapticProfile == .normal)
        director.hapticsOn = false
    }

    // MARK: - R2: voices (QA-1 #4)

    @Test func theSynthStealsByStartOrderAndNeverFromItsOwnDrain() {
        #expect(FeelSynth.voiceCount == 128)
        let synth = FeelSynth(sampleRate: 48_000)
        let left = UnsafeMutablePointer<Float>.allocate(capacity: 512)
        let right = UnsafeMutablePointer<Float>.allocate(capacity: 512)
        defer {
            left.deallocate()
            right.deallocate()
        }
        func ring(_ index: Int) -> FeelSynthCommand {
            .ring(FeelRingSpec(.bell, fundamental: 300 + Float(index), partials: 2, decay: 1, gain: 0.002))
        }
        for index in 0..<FeelSynth.voiceCount { synth.send(ring(index)) }
        synth.render(frames: 512, left: left, right: right)
        #expect(synth.stolenVoices == 0)
        #expect(synth.droppedVoices == 0)
        // R4: past the 30 ms protection (QA-2 #16).
        _ = feelRender(synth, seconds: 0.04)
        // All 128 ring on; ten more in a later drain take over the ten oldest.
        for index in 0..<10 { synth.send(ring(index)) }
        synth.render(frames: 512, left: left, right: right)
        #expect(synth.stolenVoices == 10)
        #expect(synth.droppedVoices == 0)
        _ = feelRender(synth, seconds: 0.04)
        // 200 in one drain: they take every older voice, then drop the rest instead of cutting each other off.
        for index in 0..<200 { synth.send(ring(index)) }
        synth.render(frames: 512, left: left, right: right)
        #expect(synth.stolenVoices == 10 + FeelSynth.voiceCount)
        #expect(synth.droppedVoices == 200 - FeelSynth.voiceCount)
    }

    @Test func ringVoicesEndAfterFiveTimeConstants() {
        let synth = FeelSynth(sampleRate: 48_000)
        for index in 0..<FeelSynth.voiceCount {
            synth.send(.ring(FeelRingSpec(.chime, fundamental: 500 + Float(index), partials: 2, decay: 0.1,
                                          gain: 0.002)))
        }
        // 0.6 s > 5 τ (0.5 s): every voice has ended, so 128 new ones steal nothing.
        let first = feelRender(synth, seconds: 0.6)
        #expect(first.finite)
        for index in 0..<FeelSynth.voiceCount {
            synth.send(.ring(FeelRingSpec(.chime, fundamental: 500 + Float(index), partials: 2, decay: 0.1,
                                          gain: 0.002)))
        }
        _ = feelRender(synth, seconds: 0.02)
        #expect(synth.stolenVoices == 0)
        #expect(abs(FeelSynth.ringLengthTaus - 5) < 1e-6)
    }

    @Test func aBigFeastKeepsItsRewardSounds() {
        // An 8-bug Feast with a Golden Scarab, a chain step and a new best on top of a playing marimba bed.
        let synth = FeelSynth(sampleRate: 48_000)
        var bed = FeelSoundBook.idleBed(master: FeelAudioEngine.masterGain, glide: 0.01)
        bed.music = 1
        bed.musicVoices = 5
        synth.send(.bed(bed))
        _ = feelRender(synth, seconds: 2)
        var dice = FeelDice(seed: 4)
        var bite: [FeelSynthCommand] = FeelSoundBook.chomp(caught: 8, dice: &dice)
        for index in 0..<8 {
            bite += FeelSoundBook.crunch(index: index, pan: 0, light: index >= FeedbackDirector.fullCrunches,
                                         dice: &dice)
        }
        bite += FeelSoundBook.feast(count: 8, snapsBack: 2, dice: &dice)
        bite += FeelSoundBook.lucky(.goldenScarab, dice: &dice)
        bite += FeelSoundBook.chainUp(count: 3, delay: FeelSoundBook.chainAt, dice: &dice)
        bite += FeelSoundBook.newBest(delay: FeedbackDirector.newBestAt)
        bite += FeelSoundBook.chainFlare(delay: FeelSoundBook.chainAt + FeelSoundBook.flareAfter, dice: &dice)
        #expect(bite.count < FeelSynth.voiceCount)
        for command in bite { synth.send(command) }
        let result = feelRender(synth, seconds: 1)
        #expect(result.finite)
        #expect(result.peak < 1)
        #expect(synth.droppedVoices == 0)
    }

    @Test func aNaNBedNeverLatchesTheSynthSilent() {
        let synth = FeelSynth(sampleRate: 48_000)
        var bad = FeelBed()
        bad.master = Float.nan
        bad.groan = Float.infinity
        bad.groanHz = Float.nan
        bad.wind = -Float.infinity
        bad.dripRate = Float.nan
        bad.musicVoices = Float.nan
        bad.glide = Float.nan
        synth.send(.bed(bad))
        let poisoned = feelRender(synth, seconds: 0.3)
        #expect(poisoned.finite)
        let clean = FeelSynth.sanitised(bad)
        #expect(clean.master == 0)
        #expect(clean.groan == 0)
        #expect(clean.groanHz.isFinite)
        #expect(clean.wind == 0)
        #expect(clean.dripRate == 0)
        #expect(clean.musicVoices == 1)
        // A good bed and a CHOMP afterwards are heard.
        synth.send(.bed(FeelSoundBook.idleBed(master: FeelAudioEngine.masterGain, glide: 0.01)))
        _ = feelRender(synth, seconds: 0.1)
        var dice = FeelDice(seed: 8)
        for command in FeelSoundBook.chomp(caught: 2, dice: &dice) { synth.send(command) }
        let after = feelRender(synth, seconds: 0.4)
        #expect(after.finite)
        #expect(after.peak > 0.01)
    }

    // MARK: - R2: the heavier CHOMP (50 ms hit-stop)

    @Test func theChompSlamsAtOnceAndItsTailWaitsOutTheHitStop() {
        var dice = FeelDice(seed: 21)
        for n in 1...8 {
            let chomp = FeelSoundBook.chomp(caught: n, dice: &dice)
            var squelches = 0
            for command in chomp {
                if case .squelch(let spec) = command {
                    squelches += 1
                    #expect(spec.delay >= FeelSoundBook.hitStop - 1e-6)
                }
            }
            #expect(squelches == 1)
            // The impact is all there in the first 10 ms.
            let impact = chomp.filter { $0.delay < 0.01 }.map { $0.gain }.reduce(0, +)
            #expect(impact > 0.8)
            let tail = chomp.filter { $0.delay >= FeelSoundBook.hitStop - 1e-6 }
            #expect(!tail.isEmpty)
        }
        for index in 0..<8 {
            #expect(FeelSoundBook.crunchDelay(index: index) >= FeelSoundBook.hitStop)
        }
        #expect(FeelSoundBook.gulpAt > FeelSoundBook.hitStop + FeelSoundBook.squelchLength(caught: 1))
        // The haptic: the slam, a deep hold through the hit-stop, crunch taps after it.
        let cue = FeelHapticBook.chomp(caught: 3)
        let hold = cue.notes.first { $0.kind == .continuous && $0.time == 0 }
        #expect(hold != nil)
        if let hold {
            #expect(abs(hold.duration - Double(FeelSoundBook.hitStop)) < 1e-6)
            #expect(hold.intensity >= 0.9)
        }
        let crunches = cue.notes.filter { $0.kind == .transient && $0.sharpness == 1.0 }
        #expect(crunches.count == 3)
        #expect(crunches.allSatisfy { $0.time >= Double(FeelSoundBook.hitStop) })
        // Light crunches are smaller.
        var d2 = FeelDice(seed: 2)
        let full = FeelSoundBook.crunch(index: 1, pan: 0, dice: &d2)
        let light = FeelSoundBook.crunch(index: 5, pan: 0, light: true, dice: &d2)
        #expect(light.count < full.count)
    }

    // MARK: - R2: hunger

    @Test func hungerSoundsAreSoftAndTheDroopSinks() {
        var dice = FeelDice(seed: 17)
        let rumble = FeelSoundBook.hungry(dice: &dice)
        let droop = FeelSoundBook.wilted(dice: &dice)
        let chompPeak = FeelSoundBook.chomp(caught: 1, dice: &dice).map { $0.gain }.max() ?? 0
        let lastPeak = FeelSoundBook.lastSnap().map { $0.gain }.max() ?? 0
        #expect((rumble.map { $0.gain }.max() ?? 1) < chompPeak)
        #expect((droop.map { $0.gain }.max() ?? 1) < lastPeak)
        // The rumble is low (its fundamentals under 130 Hz); the droop falls.
        for command in rumble {
            if case .tone(let spec) = command { #expect(spec.start < 130) }
        }
        var falls = false
        for command in droop {
            if case .tone(let spec) = command, spec.end < spec.start { falls = true }
        }
        #expect(falls)
        // Their haptics: round and soft; the wilt weaker than the last-snap nudge.
        let rumbleHaptic = FeelHapticBook.hungry.notes
        #expect(rumbleHaptic.allSatisfy { $0.sharpness <= 0.2 && $0.intensity <= 0.5 })
        let wiltPeak = FeelHapticBook.wilted().notes.map { $0.intensity }.max() ?? 1
        let lastSnapPeak = FeelHapticBook.lastSnap().notes.map { $0.intensity }.max() ?? 0
        #expect(wiltPeak < lastSnapPeak)
        let later = FeelHapticBook.wilted(at: 0.7)
        #expect(abs((later.notes.first?.time ?? 0) - 0.7) < 1e-9)
    }

    @Test func theDirectorRumblesOnHungryAndDroopsOnWilted() {
        let director = FeedbackDirector()
        director.soundOn = false
        director.hapticsOn = false
        let playing = TrapTelemetry(closure: 0, creeping: false, buzzers: [], chain: 0, dayClock: 1, playing: true)
        director.handle([.hungry(secondsLeft: 3)], telemetry: playing)
        #expect(director.rumbles == 1)
        director.handle([.wilted(snapsLeft: 1), .lastSnap], telemetry: playing)
        #expect(director.droops == 1)
        director.handle([.wilted(snapsLeft: 0), .tired], telemetry: TrapTelemetry(playing: false))
        #expect(director.droops == 2)
        // A whole bite frame builds one haptic pattern (QA-1 #18).
        let before = director.hapticPatterns
        let bite: [TrapEvent] = [
            .snapped(feelBite(caught: [.housefly, .gnat, .goldenScarab])),
            .bugCaught(id: 1, species: .housefly, position: CGPoint(x: 300, y: 300)),
            .bugCaught(id: 2, species: .gnat, position: CGPoint(x: 400, y: 300)),
            .bugCaught(id: 3, species: .goldenScarab, position: CGPoint(x: 500, y: 300)),
            .feast(count: 3, snapsBack: 1), .luckySnap(species: .goldenScarab), .chainUp(count: 2, multiplier: 1.5),
            .newBest,
        ]
        director.handle(bite, telemetry: playing)
        #expect(director.hapticPatterns == before + 1)
    }

    // MARK: - R2: haptic merging, buzz hysteresis, audio rules

    @Test func oneFramesHapticCuesMergeIntoOnePattern() {
        let chomp = FeelHapticBook.chomp(caught: 3)
        let merged = FeelHapticBook.merge([chomp, FeelHapticBook.feast, FeelHapticCue(notes: []), FeelHapticBook.lucky()])
        #expect(merged.count == 1)
        let total = chomp.notes.count + FeelHapticBook.feast.notes.count + FeelHapticBook.lucky().notes.count
        #expect(merged.first?.notes.count == total)
        let times = merged.first?.notes.map { $0.time } ?? []
        #expect(times == times.sorted())
        let curved = FeelHapticCue(notes: [.tap(0.5, 0.5)], curve: [FeelHapticPoint(time: 0, value: 1)])
        #expect(FeelHapticBook.merge([curved, FeelHapticBook.rearm]).count == 2)
        #expect(FeelHapticBook.merge([]).isEmpty)
    }

    @Test func theBuzzMixerKeepsItsEightUnlessANewcomerIsMuchLouder() {
        var mixer = FeelBuzzMixer()
        var eight: [Buzzer] = []
        for index in 0..<FeelSynth.buzzSlots {
            eight.append(Buzzer(id: 10 + index, species: .housefly, pan: 0, height: 0.5, flying: true))
        }
        _ = mixer.update(buzzers: eight, share: 1, now: 0)
        let seated = Set(mixer.ids.compactMap { $0 })
        #expect(seated.count == FeelSynth.buzzSlots)
        // A ninth bug a little louder: nobody loses a seat, frame after frame.
        let ninth = Buzzer(id: 99, species: .housefly, pan: 0, height: 0.4, flying: true)
        for frame in 1...30 {
            _ = mixer.update(buzzers: eight + [ninth], share: 1, now: Double(frame) / 60)
            #expect(Set(mixer.ids.compactMap { $0 }) == seated)
        }
        // A much louder one (more than 1.3×) takes the quietest seat after its fade.
        let loud = Buzzer(id: 100, species: .housefly, pan: 0, height: 0, flying: true)
        _ = mixer.update(buzzers: eight + [loud], share: 1, now: 1)
        _ = mixer.update(buzzers: eight + [loud], share: 1, now: 1.2)
        #expect(mixer.ids.contains(where: { $0 == 100 }))
    }

    // MARK: - R3: the new moments

    /// Renders one cue alone (after the bed has settled) and returns its peak.
    private func feelPeakAlone(_ commands: [FeelSynthCommand], seconds: Double = 1.2) -> (peak: Float, finite: Bool) {
        let synth = FeelSynth(sampleRate: 48_000)
        synth.send(.bed(FeelSoundBook.idleBed(master: FeelAudioEngine.masterGain, glide: 0.01)))
        _ = feelRender(synth, seconds: 0.1)
        for command in commands { synth.send(command) }
        let result = feelRender(synth, seconds: seconds)
        return (result.peak, result.finite)
    }

    @Test func theNewMomentsAreAudibleButNeverDrownTheChomp() {
        var dice = FeelDice(seed: 31)
        let chomp = feelPeakAlone(FeelSoundBook.chomp(caught: 1, dice: &dice), seconds: 0.6)
        #expect(chomp.finite)
        let cues: [[FeelSynthCommand]] = [
            FeelSoundBook.snapLost(cost: 1, dice: &dice), FeelSoundBook.snapLost(cost: 2, dice: &dice),
            FeelSoundBook.oops(dice: &dice), FeelSoundBook.chainFlare(dice: &dice), FeelSoundBook.wilted(dice: &dice),
        ]
        for cue in cues {
            let alone = feelPeakAlone(cue)
            #expect(alone.finite)
            #expect(alone.peak > 0.005)
            // Clearly under the CHOMP (whose peak the output stage holds near tanh(0.9)).
            #expect(alone.peak * 1.3 < chomp.peak)
            // Command by command too: nothing new comes near the CHOMP's thump.
            #expect((cue.map { $0.gain }.max() ?? 1) < 0.2)
        }
    }

    @Test func aStingerBiteAndATopChainBiteNeverClip() {
        // Two whole R3 bite frames, each over the playing bed with all five marimba voices and a buzzing crowd.
        for frame in 0..<2 {
            let synth = FeelSynth(sampleRate: 48_000)
            let telemetry = TrapTelemetry(closure: 2, creeping: false, buzzers: feelBuzzers(8), chain: 9,
                                          dayClock: 3.4, playing: true)
            var bed = FeelSoundBook.playBed(telemetry: telemetry, master: FeelAudioEngine.masterGain, ambience: 1)
            bed.glide = 0.01
            synth.send(.bed(bed))
            var mixer = FeelBuzzMixer()
            let targets = mixer.update(buzzers: telemetry.buzzers, share: 1, now: 0)
            for (slot, target) in targets.enumerated() {
                synth.send(.buzz(slot: slot, buzz: target))
            }
            _ = feelRender(synth, seconds: 0.5)
            var dice = FeelDice(seed: UInt64(40 + frame))
            var bite: [FeelSynthCommand]
            if frame == 0 {
                // A bee and a wasp in a 2-bug bite: two "Bzzt!"s, the loss blip, the chain's "bwoop", the last snap.
                bite = FeelSoundBook.chomp(caught: 2, dice: &dice)
                for index in 0..<2 {
                    bite += FeelSoundBook.crunch(index: index, pan: -0.2, dice: &dice)
                }
                bite += FeelSoundBook.sting(.bee, pan: 0.3, delay: FeelSoundBook.stingAt, dice: &dice)
                bite += FeelSoundBook.sting(.wasp, pan: -0.3, delay: FeelSoundBook.stingAt + 0.12, dice: &dice)
                // R4 (QA-2 #9): the blip lands with the numeral's drop, on the "Bzzt!"s' tail.
                let verdict = FeelSoundBook.numeralDropAt
                bite += FeelSoundBook.snapLost(cost: 3, delay: verdict, dice: &dice)
                bite += FeelSoundBook.chainBroken(delay: verdict + FeelSoundBook.lostLength, dice: &dice)
                bite += FeelSoundBook.lastSnap(delay: verdict + FeelSoundBook.lostLength)
            } else {
                // A 5-bug Feast that takes the chain to x5: the flare on top of the sparkle, the pop and a new best.
                bite = FeelSoundBook.chomp(caught: 5, dice: &dice)
                for index in 0..<5 {
                    bite += FeelSoundBook.crunch(index: index, pan: 0.1, light: index >= FeedbackDirector.fullCrunches,
                                                 dice: &dice)
                }
                bite += FeelSoundBook.feast(count: 5, snapsBack: 1, dice: &dice)
                bite += FeelSoundBook.chainUp(count: 8, delay: FeelSoundBook.chainAt, dice: &dice)
                bite += FeelSoundBook.chainFlare(delay: FeelSoundBook.chainAt + FeelSoundBook.flareAfter, dice: &dice)
                bite += FeelSoundBook.newBest(delay: FeedbackDirector.newBestAt)
            }
            for command in bite { synth.send(command) }
            let result = feelRender(synth, seconds: 3)
            #expect(result.finite)
            #expect(result.peak < 1.0)
            #expect(synth.peak < 1.0)
            #expect(result.hot < 0.02)
            #expect(synth.droppedVoices == 0)
        }
    }

    @Test func aCostlyStingSaysYouLostSomethingAndAFreeOneSaysOops() {
        var dice = FeelDice(seed: 33)
        // The loss blip: two notes, falling; a wasp's falls further.
        func tones(_ commands: [FeelSynthCommand]) -> [FeelToneSpec] {
            var found: [FeelToneSpec] = []
            for command in commands {
                if case .tone(let spec) = command { found.append(spec) }
            }
            return found.sorted { (a: FeelToneSpec, b: FeelToneSpec) -> Bool in a.delay < b.delay }
        }
        let bee = tones(FeelSoundBook.snapLost(cost: 1, dice: &dice))
        let wasp = tones(FeelSoundBook.snapLost(cost: 2, dice: &dice))
        #expect(bee.count == 2)
        #expect(wasp.count == 2)
        if bee.count == 2 && wasp.count == 2 {
            #expect(bee[1].start < bee[0].start)
            #expect(wasp[1].start < bee[1].start)
            #expect(abs(bee[1].delay - bee[0].delay - FeelSoundBook.lostSpacing) < 1e-6)
            #expect(FeelSoundBook.lostSpacing + bee[1].duration <= FeelSoundBook.lostLength)
        }
        // The oops rises (a gasp up a fifth) and ends higher than it starts: nothing was lost.
        let oops = FeelSoundBook.oops(dice: &dice)
        var rises = false
        var lastRing: Float = 0
        var firstTone: Float = 0
        for command in oops {
            switch command {
            case .tone(let spec):
                if spec.end > spec.start { rises = true }
                if firstTone == 0 { firstTone = spec.start }
            case .ring(let spec):
                lastRing = spec.fundamental
            default:
                break
            }
        }
        #expect(rises)
        #expect(lastRing > firstTone)
        // The verdict lands after the spit, so after the "Bzzt!" (a wasp zaps twice, so later).
        let beeVerdict = FeelSoundBook.stingVerdictAt(.bee, delay: FeelSoundBook.stingAt)
        let waspVerdict = FeelSoundBook.stingVerdictAt(.wasp, delay: FeelSoundBook.stingAt)
        #expect(beeVerdict > FeelSoundBook.stingAt + FeelSoundBook.spitAfter)
        #expect(waspVerdict > beeVerdict)
        #expect(FeelSoundBook.stingVerdictAt(.bee, delay: Float.nan).isFinite)
        let waspSting = FeelSoundBook.sting(.wasp, delay: FeelSoundBook.stingAt, dice: &dice)
        let lastSting = waspSting.map { $0.delay }.max() ?? 9
        #expect(lastSting < waspVerdict)
        // The costly sting's haptic hits harder; the blip's two taps fall (a duller second); the oops is light.
        let plain = FeelHapticBook.sting(at: 0.06).notes.map { $0.intensity }.reduce(0, +)
        let heavy = FeelHapticBook.sting(at: 0.06, heavy: true).notes.map { $0.intensity }.reduce(0, +)
        #expect(heavy > plain)
        let blip = FeelHapticBook.snapLost(at: 0.5).notes
        #expect(blip.count == 2)
        if blip.count == 2 {
            #expect(blip[1].sharpness < blip[0].sharpness)
            #expect(abs(blip[0].time - 0.5) < 1e-9)
        }
        #expect(FeelHapticBook.oops().notes.allSatisfy { $0.intensity <= 0.35 })
    }

    @Test func theDirectorJudgesEachStingFrameOnce() {
        let director = FeedbackDirector()
        director.soundOn = false
        director.hapticsOn = false
        let playing = TrapTelemetry(closure: 0, creeping: false, buzzers: [], chain: 0, dayClock: 1, playing: true)
        // Sprout's free first bee: the usual Bzzt and an "oops", no loss blip.
        director.handle([.snapped(feelBite(caught: [], stingers: [.bee])), .stung(id: 1, species: .bee, cost: 0)],
                        telemetry: playing)
        #expect(director.oopses == 1)
        #expect(director.lossBlips == 0)
        // A wasp that costs two snaps: the loss blip.
        director.handle([.snapped(feelBite(caught: [.housefly], stingers: [.wasp])),
                         .bugCaught(id: 2, species: .housefly, position: CGPoint(x: 300, y: 300)),
                         .stung(id: 3, species: .wasp, cost: 2), .chainBroken(count: 3)], telemetry: playing)
        #expect(director.lossBlips == 1)
        #expect(director.oopses == 1)
        // Two bees in one bite (one free, one not): still one verdict for the frame, and it is the loss.
        director.handle([.snapped(feelBite(caught: [], stingers: [.bee, .bee])),
                         .stung(id: 4, species: .bee, cost: 0), .stung(id: 5, species: .bee, cost: 1), .lastSnap],
                        telemetry: playing)
        #expect(director.lossBlips == 2)
        #expect(director.oopses == 1)
        // Frames without a sting judge nothing.
        director.handle([.snapped(feelBite(caught: [.gnat, .gnat])), .chainUp(count: 1, multiplier: 1.5)],
                        telemetry: playing)
        #expect(director.lossBlips == 2)
        #expect(director.oopses == 1)
    }

    @Test func theChainFlaresOnceAtTimesFive() {
        let director = FeedbackDirector()
        director.soundOn = false
        director.hapticsOn = false
        let playing = TrapTelemetry(closure: 0, creeping: false, buzzers: [], chain: 0, dayClock: 1, playing: true)
        func step(_ count: Int, _ multiplier: Double) {
            director.handle([.snapped(feelBite(caught: [.gnat, .gnat])),
                             .chainUp(count: count, multiplier: multiplier)], telemetry: playing)
        }
        for count in 1...7 {
            step(count, 1 + 0.5 * Double(count))
        }
        #expect(director.flares == 0)
        step(8, 5)
        #expect(director.flares == 1)
        // Staying at the cap is not a new flare.
        step(9, 5)
        step(10, 5)
        #expect(director.flares == 1)
        // A break re-arms it; the next climb to x5 flares again.
        director.handle([.snapped(feelBite(caught: [])), .drySnap, .chainBroken(count: 10)], telemetry: playing)
        step(1, 1.5)
        step(8, 5)
        #expect(director.flares == 2)
        // A new run (its chain restarts low without a break event) re-arms it too; a NaN never flares.
        step(1, 1.5)
        step(2, Double.nan)
        #expect(director.flares == 2)
        step(8, 5.5)
        #expect(director.flares == 3)
        // The flare: a rising chime roll after the gulp; and the fifth marimba voice at a chain of 8.
        var dice = FeelDice(seed: 35)
        let flare = FeelSoundBook.chainFlare(dice: &dice)
        var rolls: [FeelRingSpec] = []
        for command in flare {
            if case .ring(let spec) = command, spec.kind == .chime { rolls.append(spec) }
        }
        #expect(rolls.count == 4)
        let pitches = rolls.map { $0.fundamental }
        let starts = rolls.map { $0.delay }
        #expect(pitches == pitches.sorted())
        #expect(starts == starts.sorted())
        #expect(FeelSoundBook.chainAt + FeelSoundBook.flareAfter > FeelSoundBook.gulpAt)
        let top = FeelSoundBook.playBed(telemetry: TrapTelemetry(chain: 8, playing: true), master: 1, ambience: 1)
        #expect(top.musicVoices == 5)
        let taps = FeelHapticBook.chainFlare().notes.map { $0.intensity }
        #expect(taps == taps.sorted())
    }

    @Test func aSmallBiteStillHasWeight() {
        var dice = FeelDice(seed: 37)
        let hitStop = FeelSoundBook.hitStop
        func nom(_ commands: [FeelSynthCommand]) -> FeelToneSpec? {
            for command in commands {
                if case .tone(let spec) = command, abs(spec.delay - hitStop) < 1e-6 { return spec }
            }
            return nil
        }
        let one = nom(FeelSoundBook.chomp(caught: 1, dice: &dice))
        let two = nom(FeelSoundBook.chomp(caught: 2, dice: &dice))
        #expect(one != nil)
        #expect(two != nil)
        if let one {
            // In the band a phone speaker plays, and falling (a mouthful, not a beep).
            #expect(one.start > 180)
            #expect(one.end < one.start)
            #expect(one.harmonics >= 4)
        }
        #expect(nom(FeelSoundBook.chomp(caught: 5, dice: &dice)) == nil)
        // The haptic: a firmer rumble than R2's 0.84 and a settle tap on the "nom"; a big bite still rumbles harder.
        let hold = Double(hitStop)
        let small = FeelHapticBook.chomp(caught: 1).notes
        let big = FeelHapticBook.chomp(caught: 5).notes
        let rumble = small.first { $0.kind == .continuous && abs($0.time - hold) < 1e-9 }?.intensity ?? 0
        let bigRumble = big.first { $0.kind == .continuous && abs($0.time - hold) < 1e-9 }?.intensity ?? 0
        #expect(rumble >= FeelHapticBook.smallBiteStrength - 1e-6)
        #expect(bigRumble > rumble)
        let settle = small.contains { $0.kind == .transient && abs($0.time - hold) < 1e-9 }
        #expect(settle)
    }

    @Test func theWiltIsTwoSadLittleSighs() {
        var dice = FeelDice(seed: 39)
        let droop = FeelSoundBook.wilted(dice: &dice)
        var sighs: [FeelToneSpec] = []
        for command in droop {
            if case .tone(let spec) = command { sighs.append(spec) }
        }
        sighs.sort { (a: FeelToneSpec, b: FeelToneSpec) -> Bool in a.delay < b.delay }
        #expect(sighs.count == 2)
        if sighs.count == 2 {
            #expect(sighs.allSatisfy { $0.end < $0.start })
            #expect(sighs[1].start < sighs[0].start)
            #expect(sighs[1].duration > sighs[0].duration)
            #expect(abs(sighs[1].delay - FeelSoundBook.wiltSecondSigh) < 1e-6)
        }
        // It settles before the last-snap knocks or the yawn that wait for it.
        let end = droop.map { $0.delay }.max() ?? 9
        #expect(end < FeedbackDirector.afterWiltAt)
        // Still soft: under the last-snap knocks, and its haptic under the last-snap nudge.
        let droopPeak = droop.map { $0.gain }.max() ?? 1
        let knockPeak = FeelSoundBook.lastSnap().map { $0.gain }.max() ?? 0
        #expect(droopPeak < knockPeak)
        let wiltPeak = FeelHapticBook.wilted().notes.map { $0.intensity }.max() ?? 1
        let nudgePeak = FeelHapticBook.lastSnap().notes.map { $0.intensity }.max() ?? 0
        #expect(wiltPeak < nudgePeak)
        let secondSigh = Double(FeelSoundBook.wiltSecondSigh)
        let second = FeelHapticBook.wilted().notes.contains { abs($0.time - secondSigh) < 1e-9 }
        #expect(second)
    }

    // MARK: - R4: stolen voices fade (QA-2 #16) and the loss blip meets the numeral (QA-2 #9)

    @Test func aStolenVoiceFadesOutOverAtLeastFiveMilliseconds() {
        #expect(FeelSynth.stealFade >= 0.005)
        let one: Float = 1
        let zero: Float = 0
        #expect(abs(FeelSynth.fadeCurve(1) - one) < 1e-6)
        #expect(abs(FeelSynth.fadeCurve(0) - zero) < 1e-6)
        #expect(abs(FeelSynth.fadeCurve(Float.nan) - zero) < 1e-6)
        #expect(FeelSynth.fadeCurve(0.25) < FeelSynth.fadeCurve(0.75))
        let synth = FeelSynth(sampleRate: 48_000)
        var bed = FeelBed()
        bed.master = 1
        bed.glide = 0.004
        synth.send(.bed(bed))
        // The oldest voice is a loud, steady 1 kHz sine; 127 near-silent ones fill the rest of the pool.
        synth.send(.tone(FeelToneSpec(start: 1000, duration: 3, attack: 0.002, decay: 100, gain: 0.3)))
        for index in 0..<(FeelSynth.voiceCount - 1) {
            synth.send(.tone(FeelToneSpec(start: 300 + Float(index), duration: 3, attack: 0.002, decay: 100,
                                          gain: 0.000005)))
        }
        let count = 4_800
        let out = UnsafeMutablePointer<Float>.allocate(capacity: count)
        defer { out.deallocate() }
        // 0.1 s: the master is up and every voice is past the protection window.
        synth.render(frames: count, into: out)
        let lastBefore = out[count - 1]
        var steady: Float = 0
        for index in (count / 2)..<count {
            steady = max(steady, abs(out[index] - out[index - 1]))
        }
        #expect(steady > 0.02)
        #expect(synth.stolenVoices == 0)
        // One more command takes the loud voice: it fades out, never cuts.
        synth.send(.tone(FeelToneSpec(start: 400, duration: 1, attack: 0.002, decay: 100, gain: 0.000005)))
        let fadeFrames = 960
        synth.render(frames: fadeFrames, into: out)
        #expect(synth.stolenVoices == 1)
        #expect(synth.droppedVoices == 0)
        // No step: the steepest sample-to-sample change stays the sine's own.
        var jump = abs(out[0] - lastBefore)
        for index in 1..<fadeFrames {
            jump = max(jump, abs(out[index] - out[index - 1]))
        }
        #expect(jump < steady * 1.3)
        // Still sounding 4.75–5 ms after the steal (so the fade lasts at least 5 ms), and gone by 6.5 ms.
        var lateLevel: Float = 0
        for index in 228..<240 {
            lateLevel = max(lateLevel, abs(out[index]))
        }
        #expect(lateLevel > 0.004)
        var afterLevel: Float = 0
        for index in 312..<fadeFrames {
            afterLevel = max(afterLevel, abs(out[index]))
        }
        #expect(afterLevel < 0.002)
        #expect(synth.loudestVoiceEnd < 0.001)
    }

    @Test func aBiteSplitAcrossTwoCallbacksNeverTakesItsOwnVoices() {
        #expect(FeelSynth.protectWindow >= 0.02)
        let synth = FeelSynth(sampleRate: 48_000)
        let out = UnsafeMutablePointer<Float>.allocate(capacity: 960)
        defer { out.deallocate() }
        func ring(_ index: Int) -> FeelSynthCommand {
            .ring(FeelRingSpec(.glass, fundamental: 900 + Float(index), partials: 2, decay: 1, gain: 0.002))
        }
        // One bite fills the pool in one 10 ms callback; its second half arrives in the next one.
        for index in 0..<FeelSynth.voiceCount { synth.send(ring(index)) }
        synth.render(frames: 480, into: out)
        for index in 0..<12 { synth.send(ring(index)) }
        synth.render(frames: 480, into: out)
        #expect(synth.stolenVoices == 0)
        #expect(synth.droppedVoices == 12)
        // 40 ms on, a later bite may take the oldest voices (each fades out first).
        synth.render(frames: 960, into: out)
        for index in 0..<12 { synth.send(ring(index)) }
        synth.render(frames: 960, into: out)
        #expect(synth.stolenVoices == 12)
        #expect(synth.droppedVoices == 12)
        #expect(synth.loudestVoiceEnd < 0.001)
    }

    @Test func twoBigBitesCloseTogetherNeverClick() {
        // QA-2 #16: two 8-bug Feasts 0.45 s apart (the touch re-arm) over the playing bed, a buzzing crowd and a bog
        // already ringing with 90 bells, so both bites must take voices from older ones.
        let synth = FeelSynth(sampleRate: 48_000)
        let telemetry = TrapTelemetry(closure: 2, creeping: false, buzzers: feelBuzzers(8), chain: 9, dayClock: 3.4,
                                      playing: true)
        var bed = FeelSoundBook.playBed(telemetry: telemetry, master: FeelAudioEngine.masterGain, ambience: 1)
        bed.glide = 0.01
        synth.send(.bed(bed))
        var mixer = FeelBuzzMixer()
        let targets = mixer.update(buzzers: telemetry.buzzers, share: 1, now: 0)
        for (slot, target) in targets.enumerated() {
            synth.send(.buzz(slot: slot, buzz: target))
        }
        for index in 0..<90 {
            synth.send(.ring(FeelRingSpec(.bell, fundamental: 300 + Float(index) * 7, partials: 3, decay: 1.5,
                                          gain: 0.003, seed: UInt32(index + 1), pan: Float(index % 9) / 4 - 1)))
        }
        _ = feelRender(synth, seconds: 0.3)
        var dice = FeelDice(seed: 61)
        func feastFrame() -> [FeelSynthCommand] {
            var bite: [FeelSynthCommand] = FeelSoundBook.chomp(caught: 8, dice: &dice)
            for index in 0..<8 {
                bite += FeelSoundBook.crunch(index: index, pan: 0.1, light: index >= FeedbackDirector.fullCrunches,
                                             dice: &dice)
            }
            bite += FeelSoundBook.feast(count: 8, snapsBack: 2, dice: &dice)
            bite += FeelSoundBook.lucky(.goldenScarab, delay: FeelSoundBook.luckyAt, dice: &dice)
            bite += FeelSoundBook.chainUp(count: 8, delay: FeelSoundBook.chainAt, dice: &dice)
            bite += FeelSoundBook.chainFlare(delay: FeelSoundBook.chainAt + FeelSoundBook.flareAfter, dice: &dice)
            bite += FeelSoundBook.newBest(delay: FeedbackDirector.newBestAt)
            return bite
        }
        let first = feastFrame()
        #expect(first.count < FeelSynth.voiceCount)
        for command in first { synth.send(command) }
        let between = feelRender(synth, seconds: 0.45)
        for command in feastFrame() { synth.send(command) }
        let result = feelRender(synth, seconds: 2.5)
        #expect(between.finite)
        #expect(result.finite)
        #expect(between.peak < 1.0)
        #expect(result.peak < 1.0)
        #expect(synth.peak < 1.0)
        #expect(result.hot < 0.02)
        #expect(synth.stolenVoices > 0)
        #expect(synth.droppedVoices == 0)
        // Every voice that stopped (ended, or was taken and faded) left at most a hair-thin step; cutting a ringing
        // sparkle dead leaves ten times this.
        #expect(synth.loudestVoiceEnd < 0.003)
    }

    @Test func aCostlyStingsBlipLandsWithTheNumeralDrop() {
        let director = FeedbackDirector()
        director.soundOn = false
        director.hapticsOn = false
        let playing = TrapTelemetry(closure: 0, creeping: false, buzzers: [], chain: 0, dayClock: 1, playing: true)
        director.handle([.snapped(feelBite(caught: [.housefly], stingers: [.wasp])),
                         .bugCaught(id: 2, species: .housefly, position: CGPoint(x: 300, y: 300)),
                         .stung(id: 3, species: .wasp, cost: 2), .chainBroken(count: 3)], telemetry: playing)
        #expect(director.lossBlips == 1)
        #expect(abs(director.lastLossBlipAt - FeelSoundBook.numeralDropAt) < 1e-6)
        // After the "Bzzt!" starts, and at the Scene's drop: its 50 ms hit-stop, then the crack's lead.
        #expect(FeelSoundBook.numeralDropAt > FeelSoundBook.stingAt)
        let sceneDrop = BogScene.hitStopTime + BogEconomy.crackLead
        let feelDrop = Double(FeelSoundBook.numeralDropAt)
        #expect(abs(feelDrop - sceneDrop) < 0.02)
        // A free sting drops nothing: its "oops" still waits for the spit, and no blip is scheduled.
        director.handle([.snapped(feelBite(caught: [], stingers: [.bee])), .stung(id: 4, species: .bee, cost: 0)],
                        telemetry: playing)
        #expect(director.oopses == 1)
        #expect(director.lossBlips == 1)
    }

    @Test func theTiredYawnWaitsForTheNumeralAndTheBlip() {
        // R5 (REVIEW-4 #4): the last bite drops the numeral (and plays a costly sting's blip) at 0.20 s; the yawn
        // comes at least 0.45 s after the bite, after the blip and any chain "bwoop", with the App's tired banner.
        let plain = FeelSoundBook.tiredDelay(biting: true, wilting: false, stingCost: 0)
        #expect(abs(plain - FeelSoundBook.tiredAfterBite) < 1e-6)
        #expect(plain >= 0.45 - 1e-6)
        #expect(plain > FeelSoundBook.numeralDropAt)
        #expect(abs(Double(FeelSoundBook.tiredAfterBite) - AppRules.tiredBannerDelay) < 1e-6,
                "the yawn and the banner share the beat")
        let costly = FeelSoundBook.tiredDelay(biting: true, wilting: false, stingCost: 2)
        let blipOver = FeelSoundBook.numeralDropAt + FeelSoundBook.lostLength
        #expect(costly >= blipOver - 1e-6, "after the loss blip: \(costly)")
        #expect(costly >= 0.45 - 1e-6)
        let afterBwoop = FeelSoundBook.tiredDelay(biting: true, wilting: false, stingCost: 0, bwoopAt: 0.45)
        #expect(afterBwoop >= 0.45 + FeelSoundBook.chainBrokenLength - 1e-6)
        let wilt = FeelSoundBook.tiredDelay(biting: false, wilting: true, stingCost: 0)
        #expect(abs(wilt - FeelSoundBook.wiltLength) < 1e-6, "a wilt to zero: after the droop")
        #expect(FeelSoundBook.tiredDelay(biting: false, wilting: false, stingCost: 0) == 0)
        #expect(FeelSoundBook.tiredDelay(biting: true, wilting: false, stingCost: 0, bwoopAt: Float.nan).isFinite)
        // The director, on three last bites.
        let director = FeedbackDirector()
        director.soundOn = false
        director.hapticsOn = false
        let playing = TrapTelemetry(closure: 0, creeping: false, buzzers: [], chain: 0, dayClock: 1, playing: true)
        director.handle([.snapped(feelBite(caught: [.housefly])),
                         .bugCaught(id: 1, species: .housefly, position: CGPoint(x: 300, y: 300)), .tired],
                        telemetry: playing)
        #expect(director.yawns == 1)
        #expect(abs(director.lastYawnAt - FeelSoundBook.tiredAfterBite) < 1e-6)
        director.handle([.snapped(feelBite(caught: [], stingers: [.wasp])), .stung(id: 2, species: .wasp, cost: 2),
                         .tired], telemetry: playing)
        #expect(director.yawns == 2)
        #expect(director.lossBlips == 1)
        #expect(director.lastYawnAt >= director.lastLossBlipAt + FeelSoundBook.lostLength - 1e-6,
                "the yawn \(director.lastYawnAt) after the blip at \(director.lastLossBlipAt)")
        director.handle([.snapped(feelBite(caught: [])), .chainBroken(count: 3), .drySnap, .tired],
                        telemetry: playing)
        #expect(director.yawns == 3)
        #expect(director.lastYawnAt >= FeedbackDirector.chainBrokenAt + FeelSoundBook.chainBrokenLength - 1e-6)
    }

    @Test func aDrySnapIsAHollowClopWithNoSquelch() {
        // R5 (REVIEW-4 #10): the dry snap was silent in frames and thin by ear. Now a hollow "clop": a ringing wooden
        // knock at clopPitch, a square-ish body and an empty-cavity band, with no squelch, bubbles or gulp.
        var dice = FeelDice(seed: 51)
        for _ in 0..<12 {
            let dry = FeelSoundBook.drySnap(dice: &dice)
            var clops = 0
            var hollow = 0
            var wet = 0
            var deep = 0
            for command in dry {
                switch command {
                case .ring(let spec):
                    if spec.kind == .wood && spec.decay >= FeelSoundBook.clopRing - 1e-6
                        && spec.fundamental > 300 && spec.fundamental < 700 && spec.delay < 0.02 {
                        clops += 1
                    }
                case .tone(let spec):
                    if spec.odd && spec.delay < 0.02 { hollow += 1 }
                    if spec.start < 120 { deep += 1 }
                    if abs(spec.delay - FeelSoundBook.gulpAt) < 1e-6 { wet += 1 }
                case .squelch, .drop:
                    wet += 1
                case .noise, .fm, .bed, .buzz, .stopAll:
                    break
                }
            }
            #expect(clops == 1, "one hollow knock")
            #expect(hollow >= 1, "a square-ish body")
            #expect(wet == 0, "no squelch, bubbles or gulp")
            #expect(deep == 0, "no deep wet thump")
        }
        // Smaller than any CHOMP, and clearly heard.
        var chompDice = FeelDice(seed: 52)
        let chompPeak = FeelSoundBook.chomp(caught: 1, dice: &chompDice).map { $0.gain }.max() ?? 0
        let sample = FeelSoundBook.drySnap(dice: &dice)
        let samplePeak: Float = sample.map { $0.gain }.max() ?? 1
        #expect(samplePeak < chompPeak)
        let synth = FeelSynth(sampleRate: 48_000)
        synth.send(.bed(FeelSoundBook.idleBed(master: FeelAudioEngine.masterGain, glide: 0.01)))
        _ = feelRender(synth, seconds: 0.1)
        for command in sample { synth.send(command) }
        let heard = feelRender(synth, seconds: 0.6)
        #expect(heard.finite)
        #expect(heard.peak > 0.02, "audible: peak \(heard.peak)")
        #expect(heard.peak < 1.0)
    }

    @Test func aWaspStingWobblesHeavierThanABee() {
        // R5 (REVIEW-4 #7): a wasp's −2 is felt: a tap on each of its two zaps, a longer and deeper wobble, two thuds.
        func energy(_ cue: FeelHapticCue) -> Double {
            cue.notes.map { Double($0.intensity) * max($0.duration, 0.01) }.reduce(0, +)
        }
        let bee = FeelHapticBook.sting(at: 0.06, heavy: true)
        let wasp = FeelHapticBook.sting(at: 0.06, heavy: true, wasp: true)
        #expect(energy(wasp) > energy(bee))
        #expect(wasp.length > bee.length)
        let beeTaps = bee.notes.filter { $0.kind == .transient }
        let waspTaps = wasp.notes.filter { $0.kind == .transient }
        #expect(waspTaps.count == 2, "a tap on each zap")
        if waspTaps.count == 2 {
            #expect(abs(waspTaps[0].time - 0.06) < 1e-9)
            #expect(abs(waspTaps[1].time - waspTaps[0].time - FeelHapticBook.waspZapGap) < 1e-9)
            #expect(waspTaps[0].intensity >= (beeTaps.first?.intensity ?? 1))
        }
        // The haptic's zaps follow the sound's (the wasp's verdict lands one zap gap after a bee's).
        let gap = FeelSoundBook.stingVerdictAt(.wasp, delay: 0) - FeelSoundBook.stingVerdictAt(.bee, delay: 0)
        #expect(abs(Double(gap) - FeelHapticBook.waspZapGap) < 1e-6)
        let wobble = wasp.notes.filter { $0.kind == .continuous }.map { $0.intensity }.max() ?? 0
        let beeWobble = bee.notes.filter { $0.kind == .continuous }.map { $0.intensity }.max() ?? 1
        #expect(wobble >= beeWobble)
        // A free wasp still wobbles harder than a free bee; no note is out of range or before its start.
        let freeWasp = FeelHapticBook.sting(at: 0, wasp: true)
        #expect(energy(freeWasp) > energy(FeelHapticBook.sting(at: 0)))
        for cue in [wasp, freeWasp, FeelHapticBook.sting(at: Double.nan, wasp: true)] {
            #expect(cue.curve.count <= 16)
            for note in cue.notes {
                #expect(note.intensity >= 0 && note.intensity <= 1)
                #expect(note.sharpness >= 0 && note.sharpness <= 1)
                #expect(note.time >= 0)
            }
        }
    }

    // MARK: - R6: the FEAST CHOMP

    @Test func aFeastChompIsABiggerEventThanAnyChomp() {
        // Who gets it: a bite of 5+ bugs, or one at ×4+ chain; never a dry snap. A 3–4 bug Feast keeps the CHOMP.
        #expect(FeelSoundBook.feastChompCount == 5)
        #expect(FeelSoundBook.isFeastChomp(feelChainBite(caught: 5, chain: 1)))
        #expect(FeelSoundBook.isFeastChomp(feelChainBite(caught: 8, chain: 1.5)))
        #expect(FeelSoundBook.isFeastChomp(feelChainBite(caught: 1, chain: 4)))
        #expect(FeelSoundBook.isFeastChomp(feelChainBite(caught: 2, chain: 5)))
        #expect(FeelSoundBook.isFeastChomp(feelChainBite(caught: 4, chain: 3.5)) == false)
        #expect(FeelSoundBook.isFeastChomp(feelChainBite(caught: 3, chain: 1)) == false)
        #expect(FeelSoundBook.isFeastChomp(feelChainBite(caught: 0, chain: 5)) == false)
        #expect(FeelSoundBook.isFeastChomp(feelChainBite(caught: 2, chain: Double.nan)) == false)

        var dice = FeelDice(seed: 71)
        for n in [1, 5, 8, 12] {
            let feastSound = FeelSoundBook.feastChomp(caught: n, dice: &dice)
            let plainSound = FeelSoundBook.chomp(caught: min(n, 8), dice: &dice)
            var subs = 0
            var squelchAt: Float = -1
            var runNotes = 0
            var choir = 0
            var burps = 0
            var gulps = 0
            for command in feastSound {
                #expect(command.gain > 0)
                #expect(command.gain <= 0.4)
                #expect(command.delay >= 0)
                #expect(command.delay < 3)
                switch command {
                case .tone(let spec):
                    if spec.start < 70 && spec.delay < 0.01 { subs += 1 }
                    if spec.vibratoRate > 4 && spec.vibratoRate < 7
                        && abs(spec.delay - FeelSoundBook.feastStingAt) < 1e-6 {
                        choir += 1
                    }
                    if abs(spec.delay - FeelSoundBook.burpAt) < 1e-6 && spec.vibratoRate > 20 && spec.end < spec.start {
                        burps += 1
                    }
                    if abs(spec.delay - FeelSoundBook.gulpAt) < 0.05 { gulps += 1 }
                case .ring(let spec):
                    if spec.kind == .marimba && spec.delay >= FeelSoundBook.feastStingAt - 1e-6
                        && spec.delay < FeelSoundBook.burpAt {
                        runNotes += 1
                    }
                case .squelch(let spec):
                    squelchAt = spec.delay
                case .noise, .drop, .fm, .bed, .buzz, .stopAll:
                    break
                }
            }
            #expect(subs == 1, "a deeper body")
            #expect(squelchAt >= FeelSoundBook.feastHitStop - 1e-6, "the wet tail waits out the FEAST hit-stop")
            #expect(runNotes >= 4, "the sting's marimba run")
            #expect(choir >= 3, "the sting's choir")
            #expect(burps == 1, "a burp")
            #expect(gulps == 0, "the burp replaces the plain gulp")
            // The plain CHOMP has no sub body.
            var plainSubs = 0
            for command in plainSound {
                if case .tone(let spec) = command, spec.start < 70 { plainSubs += 1 }
            }
            #expect(plainSubs == 0)
            // Under the master: heavier than the plain CHOMP's slam, but by at most a quarter.
            let impact = feastSound.filter { $0.delay < 0.01 }.map { $0.gain }.reduce(0, +)
            let plainImpact = plainSound.filter { $0.delay < 0.01 }.map { $0.gain }.reduce(0, +)
            #expect(impact > plainImpact)
            #expect(impact <= plainImpact * 1.25, "impact \(impact) against \(plainImpact)")
        }

        // The cascade: one countable crunch per bug, wider apart than a plain bite's, rising, all before the sting.
        for index in 0..<10 {
            #expect(FeelSoundBook.cascadeDelay(index: index + 1) > FeelSoundBook.cascadeDelay(index: index))
        }
        #expect(FeelSoundBook.cascadeDelay(index: 0) >= FeelSoundBook.feastHitStop)
        #expect(FeelSoundBook.cascadeSpacing > FeelSoundBook.crunchSpacing)
        #expect(FeelSoundBook.cascadeDelay(index: 7) + 0.03 < FeelSoundBook.feastStingAt)
        #expect(FeelSoundBook.feastStingAt > FeelSoundBook.popAt + 0.12, "the sting after the snaps' pops")
        #expect(FeelSoundBook.burpAt > FeelSoundBook.feastStingAt + 0.2)
        var crunchDice = FeelDice(seed: 72)
        let lowCrunch = FeelSoundBook.crunch(index: 0, pan: 0, cascade: true, dice: &crunchDice)
        let highCrunch = FeelSoundBook.crunch(index: 7, pan: 0, cascade: true, dice: &crunchDice)
        func shellPitch(_ commands: [FeelSynthCommand]) -> Float {
            for command in commands {
                if case .ring(let spec) = command { return spec.fundamental }
            }
            return 0
        }
        #expect(shellPitch(highCrunch) > shellPitch(lowCrunch), "the cascade rises")
        #expect(abs((lowCrunch.first?.delay ?? -1) - FeelSoundBook.cascadeDelay(index: 0)) < 1e-6)
        // The shift helper never moves a voice before 0.
        let moved = FeelSynthCommand.ring(FeelRingSpec(.wood, fundamental: 900, decay: 0.01, gain: 0.1, delay: 0.02))
        #expect(abs(moved.delayed(by: 0.03).delay - 0.05) < 1e-6)
        #expect(moved.delayed(by: -1).delay == 0)
        #expect(abs(moved.delayed(by: Float.nan).delay - 0.02) < 1e-6)
    }

    @Test func aWholeFeastFrameStaysUnderTheMasterPeak() {
        // An 8-bug FEAST CHOMP with its full cascade, the Feast sparkle and two pops, a Golden Scarab, the chain's ×5
        // flare and a new best, over the playing bed with all five marimba voices and a buzzing crowd.
        let synth = FeelSynth(sampleRate: 48_000)
        let telemetry = TrapTelemetry(closure: 2, creeping: false, buzzers: feelBuzzers(8), chain: 9, dayClock: 3.4,
                                      playing: true)
        var bed = FeelSoundBook.playBed(telemetry: telemetry, master: FeelAudioEngine.masterGain, ambience: 1)
        bed.glide = 0.01
        synth.send(.bed(bed))
        var mixer = FeelBuzzMixer()
        let targets = mixer.update(buzzers: telemetry.buzzers, share: 1, now: 0)
        for (slot, target) in targets.enumerated() {
            synth.send(.buzz(slot: slot, buzz: target))
        }
        _ = feelRender(synth, seconds: 0.5)
        var dice = FeelDice(seed: 73)
        var bite: [FeelSynthCommand] = FeelSoundBook.feastChomp(caught: 8, dice: &dice)
        for index in 0..<8 {
            bite += FeelSoundBook.crunch(index: index, pan: 0.1, light: index >= FeedbackDirector.feastFullCrunches,
                                         cascade: true, dice: &dice)
        }
        bite += FeelSoundBook.feast(count: 8, snapsBack: 2, dice: &dice)
        bite += FeelSoundBook.lucky(.goldenScarab, delay: FeelSoundBook.luckyAt, dice: &dice)
        bite += FeelSoundBook.chainUp(count: 8, delay: FeelSoundBook.chainAt, dice: &dice)
        bite += FeelSoundBook.chainFlare(delay: FeelSoundBook.chainAt + FeelSoundBook.flareAfter, dice: &dice)
        bite += FeelSoundBook.newBest(delay: FeedbackDirector.newBestAt)
        #expect(bite.count < FeelSynth.voiceCount)
        for command in bite { synth.send(command) }
        let result = feelRender(synth, seconds: 3)
        let ceilingOut: Float = tanh(FeelSynth.ceiling)
        #expect(result.finite)
        #expect(result.peak < 1.0)
        #expect(result.peak <= ceilingOut + 0.001, "under the master's peak: \(result.peak)")
        #expect(synth.peak < 1.0)
        #expect(result.hot < 0.05, "never a wall of limiter: \(result.hot)")
        #expect(synth.droppedVoices == 0)
        // Alone, it is as loud as the output stage allows: the biggest moment in the game.
        var aloneDice = FeelDice(seed: 74)
        let alone = feelPeakAlone(FeelSoundBook.feastChomp(caught: 5, dice: &aloneDice), seconds: 1.8)
        #expect(alone.finite)
        #expect(alone.peak > 0.3)
    }

    @Test func aFeastChompHapticIsHeavierAndLongerThanAnyChomp() {
        func energy(_ cue: FeelHapticCue) -> Double {
            cue.notes.map { Double($0.intensity) * max($0.duration, 0.01) }.reduce(0, +)
        }
        let biggest = FeelHapticBook.chomp(caught: 8)
        for n in [1, 5, 8, 20] {
            let cue = FeelHapticBook.feastChomp(caught: n)
            #expect(energy(cue) > energy(biggest))
            #expect(cue.length > biggest.length)
            #expect(cue.curve.isEmpty, "it merges with the frame's other cues")
            let hold = cue.notes.first { $0.kind == .continuous && $0.time == 0 }
            #expect(hold != nil)
            if let hold {
                #expect(hold.intensity >= 1 - 1e-6)
                #expect(abs(hold.duration - Double(FeelSoundBook.feastHitStop)) < 1e-9)
            }
            // The double slam: two full-strength taps, the second as the hit-stop ends.
            let slams = cue.notes.filter { $0.kind == .transient && $0.intensity >= 1 - 1e-6 }
            #expect(slams.count == 2)
            if slams.count == 2 {
                #expect(abs(slams[1].time - Double(FeelSoundBook.feastHitStop)) < 1e-9)
            }
            // One keen tap per bug on the cascade (up to 8), then the sting's and the burp's.
            let stingStart = Double(FeelSoundBook.feastStingAt)
            let crunches = cue.notes.filter { $0.kind == .transient && $0.sharpness >= 1 - 1e-6 && $0.time < stingStart }
            #expect(crunches.count == min(n, 8))
            #expect(cue.notes.contains { $0.time >= Double(FeelSoundBook.burpAt) - 1e-9 })
            for note in cue.notes {
                #expect(note.intensity >= 0 && note.intensity <= 1)
                #expect(note.sharpness >= 0 && note.sharpness <= 1)
                #expect(note.time >= 0)
            }
        }
    }

    @Test func theDirectorPlaysTheFeastChompOnlyForABigBite() {
        let director = FeedbackDirector()
        director.soundOn = false
        director.hapticsOn = false
        let playing = TrapTelemetry(closure: 0, creeping: false, buzzers: [], chain: 0, dayClock: 1, playing: true)
        let before = director.hapticPatterns
        director.handle(feelBiteFrame(caught: 5, chain: 1.5), telemetry: playing)
        #expect(director.feastChomps == 1)
        #expect(director.chomps == 1)
        #expect(director.hapticPatterns == before + 1, "one merged pattern for the whole frame")
        director.handle(feelBiteFrame(caught: 3, chain: 2), telemetry: playing)
        #expect(director.feastChomps == 1, "a 3-bug Feast keeps the plain CHOMP")
        #expect(director.chomps == 2)
        director.handle(feelBiteFrame(caught: 1, chain: 4), telemetry: playing)
        #expect(director.feastChomps == 2, "a ×4 chain bite is a FEAST")
        director.handle(feelBiteFrame(caught: 0, chain: 5) + [.drySnap], telemetry: playing)
        #expect(director.feastChomps == 2)
        #expect(director.chomps == 3)
    }

    // MARK: - R6: goals and the Garden

    @Test func aGoalChimesAfterItsBiteAndANewVarietyGetsAFanfare() {
        // The pure timing: after a plain bite's chain chime and pops; after a FEAST CHOMP's burp; at once otherwise.
        #expect(abs(FeelSoundBook.goalDelay(sinceBite: 0, feast: false) - FeelSoundBook.goalAfterBite) < 1e-6)
        #expect(abs(FeelSoundBook.goalDelay(sinceBite: 0, feast: true) - FeelSoundBook.feastChompLength) < 1e-6)
        #expect(abs(FeelSoundBook.goalDelay(sinceBite: 0.2, feast: false) - (FeelSoundBook.goalAfterBite - 0.2)) < 1e-5)
        #expect(FeelSoundBook.goalDelay(sinceBite: 5, feast: true) == 0)
        #expect(FeelSoundBook.goalDelay(sinceBite: Double.infinity, feast: false) == 0)
        #expect(FeelSoundBook.goalDelay(sinceBite: Double.nan, feast: false) == 0)
        #expect(abs(FeelSoundBook.goalDelay(sinceBite: -1, feast: false) - FeelSoundBook.goalAfterBite) < 1e-6)
        #expect(FeelSoundBook.goalAfterBite > FeelSoundBook.chainAt + 0.1)
        #expect(FeelSoundBook.goalAfterBite >= FeelSoundBook.popAt + 0.12 - 1e-6)
        #expect(FeelSoundBook.feastChompLength >= FeelSoundBook.burpAt + FeelSoundBook.burpPopAfter)

        // The sounds: heard, small beside the CHOMP; the bonus has a third note; the fanfare is the longer moment.
        var dice = FeelDice(seed: 75)
        let chompAlone = feelPeakAlone(FeelSoundBook.chomp(caught: 1, dice: &dice), seconds: 0.6)
        let chime = FeelSoundBook.goalChime(dice: &dice)
        let bonusChime = FeelSoundBook.goalChime(bonus: true, dice: &dice)
        let fanfareSound = FeelSoundBook.varietyFanfare(dice: &dice)
        #expect(bonusChime.count > chime.count)
        func lastStart(_ commands: [FeelSynthCommand]) -> Float {
            commands.map { $0.delay }.max() ?? 0
        }
        #expect(lastStart(fanfareSound) > lastStart(bonusChime))
        for cue in [chime, bonusChime, fanfareSound] {
            let alone = feelPeakAlone(cue, seconds: 1.6)
            #expect(alone.finite)
            #expect(alone.peak > 0.005)
            #expect(alone.peak * 1.3 < chompAlone.peak)
            #expect((cue.map { $0.gain }.max() ?? 1) < 0.2)
        }
        let late = FeelSoundBook.goalChime(delay: 0.62, dice: &dice)
        #expect(late.allSatisfy { $0.delay >= 0.62 - 1e-6 })

        // The haptics.
        let goalTouch = FeelHapticBook.goal()
        let bonusTouch = FeelHapticBook.goal(bonus: true)
        let fanfareTouch = FeelHapticBook.fanfare()
        #expect(bonusTouch.notes.count > goalTouch.notes.count)
        #expect(fanfareTouch.length > goalTouch.length)
        #expect(FeelHapticBook.goal(at: 0.62).notes.allSatisfy { $0.time >= 0.62 - 1e-9 })
        for cue in [goalTouch, bonusTouch, fanfareTouch, FeelHapticBook.goal(at: Double.nan),
                    FeelHapticBook.fanfare(at: -3)] {
            #expect(!cue.notes.isEmpty)
            for note in cue.notes {
                #expect(note.intensity >= 0 && note.intensity <= 1)
                #expect(note.sharpness >= 0 && note.sharpness <= 1)
                #expect(note.time >= 0)
            }
        }

        // The director: at once with no bite; after the bite's sounds when a bite just landed.
        let director = FeedbackDirector()
        director.soundOn = false
        director.hapticsOn = false
        director.goalCompleted()
        #expect(director.goalChimes == 1)
        #expect(director.lastGoalChimeAt == 0, "no bite: at once")
        let playing = TrapTelemetry(closure: 0, creeping: false, buzzers: [], chain: 0, dayClock: 1, playing: true)
        director.handle(feelBiteFrame(caught: 1, chain: 1), telemetry: playing)
        director.goalCompleted()
        #expect(director.lastGoalChimeAt > 0.3, "after the bite: \(director.lastGoalChimeAt)")
        #expect(director.lastGoalChimeAt <= FeelSoundBook.goalAfterBite + 1e-6)
        director.handle(feelBiteFrame(caught: 6, chain: 2), telemetry: playing)
        director.goalCompleted(bonus: true)
        #expect(director.goalChimes == 3)
        #expect(director.lastGoalChimeAt > FeelSoundBook.goalAfterBite + 0.2, "after the FEAST's burp")
        director.varietyUnlocked()
        director.varietyUnlocked(after: Double.nan)
        director.varietyUnlocked(after: 0.8)
        #expect(director.fanfares == 3)
    }

    // MARK: - R6: the Zen Bog

    @Test func zenIsAGentleBedWithNoHungerOrWarnings() {
        #expect(FeelSoundBook.isZen(.zen))
        #expect(FeedbackDirector.wantsZen(.zen))
        let others: [RunMode] = [.feed, .daily(day: 300, scored: true), .daily(day: 300, scored: false), .attract,
                                 .lesson]
        for mode in others {
            #expect(FeelSoundBook.isZen(mode) == false)
            #expect(FeedbackDirector.wantsZen(mode) == false)
        }

        // The bed: softer everywhere, the creep groan still there, the master unchanged.
        let telemetry = TrapTelemetry(closure: 18, creeping: true, buzzers: feelBuzzers(4), chain: 9, dayClock: 3.4,
                                      playing: true)
        let loud = FeelSoundBook.playBed(telemetry: telemetry, master: 1, ambience: 1)
        let soft = FeelSoundBook.playBed(telemetry: telemetry, master: 1, ambience: 1, zen: true)
        #expect(soft.music > 0)
        #expect(soft.music < loud.music)
        #expect(soft.musicVoices <= FeelSoundBook.zenMaxMusicVoices)
        #expect(soft.musicVoices < loud.musicVoices)
        #expect(soft.wind < loud.wind)
        #expect(soft.frogs < loud.frogs)
        #expect(soft.dripRate < loud.dripRate)
        #expect(soft.crickets < loud.crickets)
        #expect(soft.groan > 0, "the creep still speaks")
        #expect(soft.groan < loud.groan)
        #expect(soft.master == loud.master)
        func bedRMS(_ wanted: FeelBed) -> Double {
            let synth = FeelSynth(sampleRate: 48_000)
            var settled = wanted
            settled.glide = 0.01
            synth.send(.bed(settled))
            return feelRender(synth, seconds: 2).rms
        }
        let loudRMS = bedRMS(loud)
        let softRMS = bedRMS(soft)
        #expect(softRMS > 0.001, "still a living bog")
        #expect(softRMS < loudRMS)

        // The director: no hunger, no warnings, no "oops"; the CHOMP and the FEAST are unchanged.
        let director = FeedbackDirector()
        director.soundOn = false
        director.hapticsOn = false
        director.zen = FeedbackDirector.wantsZen(.zen)
        let playing = TrapTelemetry(closure: 0, creeping: false, buzzers: [], chain: 0, dayClock: 1, playing: true)
        director.handle([.hungry(secondsLeft: 3)], telemetry: playing)
        director.handle([.wilted(snapsLeft: 3), .lastSnap], telemetry: playing)
        director.handle([.snapped(feelBite(caught: [], stingers: [.bee])), .stung(id: 4, species: .bee, cost: 0),
                         .chainBroken(count: 3)], telemetry: playing)
        director.handle([.tired], telemetry: TrapTelemetry(playing: false))
        #expect(director.rumbles == 0)
        #expect(director.droops == 0)
        #expect(director.yawns == 0)
        #expect(director.oopses == 0)
        #expect(director.hushed == 5)
        director.handle(feelBiteFrame(caught: 5, chain: 1), telemetry: playing)
        #expect(director.chomps == 1)
        #expect(director.feastChomps == 1)
        // Back to a Feed run: everything speaks again.
        director.zen = FeedbackDirector.wantsZen(.feed)
        director.handle([.hungry(secondsLeft: 3)], telemetry: playing)
        #expect(director.rumbles == 1)
        #expect(director.hushed == 5)
    }

    @Test func aRefusedAudioStartIsNotAnEngineFailure() {
        #expect(FeelAudioRules.isBlocked(code: 561_015_905))   // '!pla'
        #expect(FeelAudioRules.isBlocked(code: 561_017_449))   // '!pri'
        #expect(FeelAudioRules.isBlocked(code: -10_851) == false)
        #expect(FeelAudioRules.isBlocked(code: 0) == false)
        #expect(FeelAudioRules.blockedBackoff > 1)
    }

    #if DEBUG
    @Test func demoLogIsDebugAndSnapDemoOnly() {
        let wanted = ProcessInfo.processInfo.arguments.contains("-snapDemo")
        #expect(FeelDemoLog.isEnabled == wanted)
        #expect(FeelHingeLog.isEnabled == wanted)
    }
    #endif
}
