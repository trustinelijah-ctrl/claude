# Product

Written from Eli's build brief ("Piano, Deeply — Claude Code megaprompt"), not from an interview: the brief asked for no questions unless a decision blocked the build. Lines marked *(inferred)* are my reading of the brief, not something Eli confirmed.

## Platform

ios

## Stack

SwiftUI + SwiftData, iOS 17+, iPhone first with an adaptive iPad layout. Pure logic lives in the `PianoCore` Swift package. Offline: no account, backend, analytics, paywall, or paid AI service.

## Users

One person: Eli, 30. Played for about four years, stopped during a difficult period, and is coming back seriously. A visual learner. Harsh self-judgment has made practice tense before. Not after exams or a concert career.

## Product Purpose

A personal practice studio: decide what to work on, practise one problem deliberately, keep evidence of progress, and enjoy playing. The home screen answers "What can I play today?" within five seconds.

## Positioning

A quiet instrument companion. It isn't a course, a game, or a grader.

## Operating Context

A phone on a music stand or the piano lid, often in the evening *(inferred)*, used between playing. Short glances, one hand free at most, and the screen shouldn't lock mid-session.

## Capabilities and Constraints

- Records audio on device when asked. Microphone audio can't grade notes, tone, dynamics, or technique, and the app never claims to.
- No MIDI in v1. `PianoCore` is the place for a future Core MIDI seam.
- No copyrighted sheet music. Only original short exercises and verified theory (ii–V–I spelling and voicings are unit-tested).
- Suggestions come from plain ordered rules, are shown with their reason, and are never called AI.

## Brand Commitments

Warm ivory and graphite surfaces, a deep forest-green accent, a restrained brass highlight. The system serif (New York) appears occasionally for display; SF carries the UI. The keyboard is a recurring motif, used sparingly. No glass everywhere, no gradients on cards, no confetti, no dashboard charts.

## Evidence on Hand

Progress is shown only through the user's own like-for-like entries: cold compared with cold, after-practice with after-practice, same task. Tempo appears only where the user typed it.

## Product Principles

- Make it easy to begin. Start practice is at most three taps from Today.
- Reward finished experiments, never taps. No streaks, XP, guilt copy, or missed-day counts.
- A gap is ordinary. Coming back says "Welcome back." and leads straight to music.
- Honest empty states that offer a useful action instead of invented progress.
- Never silently lose a note, a session, or a recording.

## Accessibility & Inclusion

Dynamic Type through accessibility sizes, VoiceOver labels on the drawn keyboard and chords, Reduce Motion alternatives, separate high-contrast colors, and 44 pt touch targets.
