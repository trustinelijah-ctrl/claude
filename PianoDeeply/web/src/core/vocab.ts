// Port of PianoCore's vocabulary (SkillCatalog, PracticeVocabulary, Inventory,
// SessionStepKind). Raw values match the Swift enums so exports are identical.

export type SkillBranch =
  | "technique" | "rhythm" | "reading" | "ear" | "harmony" | "repertoire" | "improvisation" | "selfCoaching";

export const branches: SkillBranch[] = [
  "technique", "rhythm", "reading", "ear", "harmony", "repertoire", "improvisation", "selfCoaching",
];

export const branchInfo: Record<SkillBranch, { title: string; summary: string; icon: string }> = {
  technique: { title: "Technique & touch", summary: "Getting the sound you mean with a hand that stays free.", icon: "hand" },
  rhythm: { title: "Rhythm", summary: "Keeping time, feeling subdivision, landing together.", icon: "metronome" },
  reading: { title: "Reading", summary: "Turning the page into sound without stopping.", icon: "list" },
  ear: { title: "Ear", summary: "Hearing it, then finding it on the keys.", icon: "ear" },
  harmony: { title: "Harmony & chords", summary: "Knowing what the chords are and where your hands go.", icon: "keys" },
  repertoire: { title: "Repertoire", summary: "Pieces you can play, keep, and bring back.", icon: "note" },
  improvisation: { title: "Improvisation & creation", summary: "Making things up, arranging, writing.", icon: "sparkles" },
  selfCoaching: { title: "Self-coaching", summary: "Noticing what went wrong and choosing what to try next.", icon: "search" },
};

/** Starting subskills; they begin as "notExplored" so the map never shows progress nobody made. */
export const starterSubskills: Record<SkillBranch, [string, string][]> = {
  technique: [
    ["Five-finger evenness", "Five-note pattern, each hand, even at 80 bpm with no accents I didn't choose."],
    ["Scales & thumb crossings", "Two-octave scale hands separately without a bump at the crossing."],
    ["Voicing the melody", "Melody audibly louder than the accompaniment on a recording."],
    ["Staying relaxed", "Shoulders and wrist loose through a whole passage; I can check mid-phrase."],
  ],
  rhythm: [
    ["Steady pulse", "Play with a metronome for 16 bars and stay with it."],
    ["Subdivision", "Count and play eighths, triplets, and sixteenths against a beat."],
    ["Swing & syncopation", "Play a syncopated left-hand pattern against a steady right hand."],
  ],
  reading: [
    ["Easy sight-reading", "Read a new 8-bar piece a level below mine without stopping."],
    ["Reading both clefs", "Name and play bass-clef notes as quickly as treble."],
    ["Reading ahead", "Keep eyes a beat ahead of the hands through a phrase."],
  ],
  ear: [
    ["Melodies by ear", "Find a short familiar melody on the keys in under five minutes."],
    ["Hearing chord quality", "Tell major, minor, and dominant 7th apart when someone plays them."],
    ["Hearing bass lines", "Play the bass line of a song I know."],
  ],
  harmony: [
    ["Triads & inversions", "Play any major or minor triad in all three positions without stopping to think."],
    ["Seventh chords", "Play maj7, m7, and dominant 7 from any root."],
    ["ii–V–I", "Play ii–V–I in three keys with smooth voice leading."],
    ["Lead-sheet voicings", "Play a lead sheet with melody in the right hand and chords in the left."],
  ],
  repertoire: [
    ["Learning a new piece", "A new piece goes from reading to slowly playable in a few weeks."],
    ["Keeping old pieces", "Play a piece I haven't touched in a month, cold, through the hard spots."],
    ["Playing for someone", "Play one piece for a person, or into a recording, start to finish."],
  ],
  improvisation: [
    ["Free playing", "Play two minutes without stopping, on anything."],
    ["Improvising over changes", "Keep a right-hand line going over a repeated progression."],
    ["Arranging a song", "Make a simple arrangement of a song I love."],
  ],
  selfCoaching: [
    ["Naming the problem", "After a stumble, say what went wrong in one specific sentence."],
    ["Shrinking the problem", "Turn a failing passage into a smaller exercise that works."],
    ["Testing later", "Check a fix cold the next day instead of trusting today's version."],
  ],
};

export type SkillState = "notExplored" | "understood" | "slowlyPlayable" | "fluent" | "reliableLater" | "usableFreely";
export const skillStates: SkillState[] = ["notExplored", "understood", "slowlyPlayable", "fluent", "reliableLater", "usableFreely"];
export const stateInfo: Record<SkillState, { label: string; meaning: string }> = {
  notExplored: { label: "Not explored", meaning: "Haven't looked at it yet." },
  understood: { label: "Understood", meaning: "I know what it is and how it should go." },
  slowlyPlayable: { label: "Slowly playable", meaning: "I can do it slowly, with attention." },
  fluent: { label: "Fluent", meaning: "I can do it at tempo today." },
  reliableLater: { label: "Reliable later", meaning: "It still works cold, days later." },
  usableFreely: { label: "Usable freely", meaning: "I can use it in music I didn't prepare." },
};

export type AttemptPhase = "cold" | "afterPractice";
export const phaseLabel: Record<AttemptPhase, string> = { cold: "Cold first pass", afterPractice: "After practice" };

export type ErrorCategory =
  | "notes" | "rhythm" | "fingering" | "coordination" | "control" | "reading" | "memory" | "tension" | "sound" | "unsure";
export const errorCategories: ErrorCategory[] = [
  "notes", "rhythm", "fingering", "coordination", "control", "reading", "memory", "tension", "sound", "unsure",
];
export const errorInfo: Record<ErrorCategory, { label: string; shrink: string }> = {
  notes: { label: "Wrong notes", shrink: "Play just the notes that went wrong, slowly, then add one note either side." },
  rhythm: { label: "Rhythm or pulse", shrink: "Clap or tap the rhythm, then play it on one note before using the real notes." },
  fingering: { label: "Fingering", shrink: "Choose a fingering, write it down, and play only the crossing three times." },
  coordination: { label: "Hands together", shrink: "Hands separately until each is easy, then together at half tempo." },
  control: { label: "Too fast to control", shrink: "Drop the metronome 20 bpm and play it until it feels boring." },
  reading: { label: "Lost my place reading", shrink: "Say the note names aloud for the bar, then play it without stopping." },
  memory: { label: "Memory slip", shrink: "Play from the slip point three times, then start one phrase earlier." },
  tension: { label: "Tension or effort", shrink: "Play it softer and slower, checking shoulders and wrist on each downbeat." },
  sound: { label: "Sound or balance", shrink: "Play the melody alone, then add the accompaniment as quietly as you can." },
  unsure: { label: "Not sure yet", shrink: "Play it once more, slowly, and listen for the first moment it stops feeling easy." },
};

export type Outcome = "worked" | "partly" | "notYet";
export const outcomes: Outcome[] = ["worked", "partly", "notYet"];
export const outcomeLabel: Record<Outcome, string> = { worked: "It worked", partly: "Partly", notYet: "Not yet" };

export interface Feedback {
  message: string;
  celebrate: boolean;
}

/** Only a finished experiment that worked gets the warm response; tapping around never does. */
export function feedbackAfter(outcome: Outcome, tempo: number | null, phase: AttemptPhase): Feedback {
  if (outcome === "worked") {
    const tempoPart = tempo != null ? `Even at ${tempo} bpm.` : "That worked.";
    const next = phase === "cold" ? "It held up cold. Try it a notch faster next time." : "Try it cold next time.";
    return { message: `${tempoPart} ${next}`, celebrate: true };
  }
  if (outcome === "partly") return { message: "Part of it's there. Shrink the bit that isn't and try again.", celebrate: false };
  return { message: "Useful to know. Make it smaller or slower and try again.", celebrate: false };
}

export type StepKind = "arrival" | "technique" | "reading" | "focus" | "application" | "ear" | "improvisation" | "closing";
export const stepInfo: Record<StepKind, { title: string; prompt: string; icon: string }> = {
  arrival: { title: "Arrive", prompt: "Play anything you like. No goals yet.", icon: "sparkles" },
  technique: { title: "Technique", prompt: "A scale, arpeggio, or pattern, slow and loose.", icon: "hand" },
  reading: { title: "Easy reading", prompt: "Something new and easy. Keep going; don't fix mistakes.", icon: "list" },
  focus: { title: "One focused problem", prompt: "Pick one thing that doesn't work yet and work on it.", icon: "scope" },
  application: { title: "Back into music", prompt: "Put what you just fixed back into the piece around it.", icon: "note" },
  ear: { title: "Ear", prompt: "Find a melody or bass line you know, by ear.", icon: "ear" },
  improvisation: { title: "Play freely", prompt: "Make something up. Nothing to get right.", icon: "sparkles" },
  closing: { title: "Leave a note", prompt: "One sentence for next time: what's easier, what's next.", icon: "pencil" },
};

export type InventorySample = "familiarPiece" | "easyReading" | "scaleInversion" | "chordProgression" | "melodyByEar" | "freePlaying";
export const inventorySamples: InventorySample[] = [
  "familiarPiece", "easyReading", "scaleInversion", "chordProgression", "melodyByEar", "freePlaying",
];
export const inventoryInfo: Record<InventorySample, { title: string; instruction: string; branch: SkillBranch; taskTitle: string; prompt?: string }> = {
  familiarPiece: { title: "A familiar piece", instruction: "Play something you used to know, from wherever you can start. No warm-up on it first.", branch: "repertoire", taskTitle: "Familiar piece, cold", prompt: "Which piece, and from where?" },
  easyReading: { title: "Easy unseen reading", instruction: "Pick something you've never seen that looks easy. Play it through once without stopping to fix.", branch: "reading", taskTitle: "Easy unseen reading", prompt: "What did you read?" },
  scaleInversion: { title: "A scale or inversion", instruction: "One scale, hands separately then together, or one triad through its inversions.", branch: "technique", taskTitle: "Scale or inversion check" },
  chordProgression: { title: "A chord progression", instruction: "Any progression you know, or ii–V–I in F: Gm7, C7, Fmaj7.", branch: "harmony", taskTitle: "Chord progression check", prompt: "Which progression, in which key?" },
  melodyByEar: { title: "A short melody by ear", instruction: "A tune you can sing, like a folk song or a theme. Find it on the keys.", branch: "ear", taskTitle: "Melody by ear", prompt: "Which melody?" },
  freePlaying: { title: "Two minutes of free playing", instruction: "Play anything for two minutes without stopping. This one has nothing to get right.", branch: "improvisation", taskTitle: "Two minutes of free playing" },
};
