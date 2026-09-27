// Port of PianoCore's ChordTheory: spelled notes, ii–V–I, close voicings.
const LETTERS = ["C", "D", "E", "F", "G", "A", "B"];
const NATURAL = [0, 2, 4, 5, 7, 9, 11];

export interface Note { letter: number; accidental: number }
export const note = (letter: number, accidental = 0): Note => ({ letter: ((letter % 7) + 7) % 7, accidental });
export const pitchClass = (n: Note) => (((NATURAL[n.letter] + n.accidental) % 12) + 12) % 12;
export function noteName(n: Note): string {
  const marks: Record<number, string> = { [-2]: "𝄫", [-1]: "♭", 1: "♯", 2: "𝄪" };
  return LETTERS[n.letter] + (marks[n.accidental] ?? "");
}
export function spokenName(n: Note): string {
  const words: Record<number, string> = { [-2]: " double flat", [-1]: " flat", 1: " sharp", 2: " double sharp" };
  return LETTERS[n.letter] + (words[n.accidental] ?? "");
}
/** The note `steps` letters above, `semitones` away, spelled accordingly (a minor third above G is B♭). */
export function up(n: Note, steps: number, semitones: number): Note {
  const letter = (n.letter + steps) % 7;
  const target = (pitchClass(n) + semitones) % 12;
  let diff = (target - NATURAL[letter]) % 12;
  if (diff > 6) diff -= 12;
  if (diff < -6) diff += 12;
  return note(letter, diff);
}

type Quality = "minor7" | "dominant7" | "major7";
const QUALITIES: Record<Quality, { intervals: [number, number][]; suffix: string; spoken: string }> = {
  minor7: { intervals: [[0, 0], [2, 3], [4, 7], [6, 10]], suffix: "m7", spoken: " minor seven" },
  dominant7: { intervals: [[0, 0], [2, 4], [4, 7], [6, 10]], suffix: "7", spoken: " seven" },
  major7: { intervals: [[0, 0], [2, 4], [4, 7], [6, 11]], suffix: "maj7", spoken: " major seven" },
};

export interface Chord { root: Note; quality: Quality; fn: string }
export const chordName = (c: Chord) => noteName(c.root) + QUALITIES[c.quality].suffix;
export const chordSpoken = (c: Chord) => spokenName(c.root) + QUALITIES[c.quality].spoken;
export const chordTones = (c: Chord) => QUALITIES[c.quality].intervals.map(([st, se]) => up(c.root, st, se));

export interface Voiced { midi: number; name: Note }
/** Close voicing, lowest first: the bass is the lowest note at or above `anchor`. */
export function voicing(c: Chord, inversion: number, anchor = 53): Voiced[] {
  const tones = chordTones(c);
  const k = ((inversion % tones.length) + tones.length) % tones.length;
  const ordered = [...tones.slice(k), ...tones.slice(0, k)];
  const out: Voiced[] = [];
  let floor = anchor;
  for (const t of ordered) {
    const midi = floor + ((pitchClass(t) - (floor % 12) + 12) % 12);
    out.push({ midi, name: t });
    floor = midi + 1;
  }
  return out;
}

export const twoFiveOne = (key: Note): Chord[] => [
  { root: up(key, 1, 2), quality: "minor7", fn: "ii" },
  { root: up(key, 4, 7), quality: "dominant7", fn: "V" },
  { root: key, quality: "major7", fn: "I" },
];
export const smoothTwoFiveOne = [0, 2, 0];
/** Each checked by the tests: smooth voice leading holds, and every inversion fits the keyboard. */
export const keys: Note[] = [note(3), note(0), note(6, -1), note(4)];
export const keyboardRange: [number, number] = [53, 77];
export const inversionName = (i: number) => ["Root position", "1st inversion", "2nd inversion", "3rd inversion"][i] ?? "";
