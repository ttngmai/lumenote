//

import SwiftUI

/// Replays due skills with the same quiz screens used for a normal session.
struct LearningReviewSessionView: View {
    let topic: LearningTopic
    let skillKeys: Set<String>
    @Environment(\.learningLog) private var learningLog

    var body: some View {
        Group {
            if skillKeys.isEmpty {
                Text("복습할 항목이 없습니다".l10n)
                    .font(LumenoteFont.body(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                switch topic {
                case .interval:
                    IntervalReviewHost(skillKeys: skillKeys, recorder: learningLog)
                case .scale:
                    ScaleReviewHost(skillKeys: skillKeys, recorder: learningLog)
                case .keySignature:
                    KeySignatureReviewHost(skillKeys: skillKeys, recorder: learningLog)
                case .chord:
                    ChordReviewHost(skillKeys: skillKeys, recorder: learningLog)
                case .diatonicChord:
                    DiatonicReviewHost(skillKeys: skillKeys, recorder: learningLog)
                case .fretboardNote:
                    FretboardNoteReviewHost(skillKeys: skillKeys, recorder: learningLog)
                case .fretboardDegree:
                    FretboardDegreeReviewHost(skillKeys: skillKeys, recorder: learningLog)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LearningReviewBackground())
        .lumenoteCompactHeader(title: "복습", showsBackButton: true)
    }
}

private struct LearningReviewResult: View {
    @Environment(\.appPalette) private var palette
    @Environment(\.dismiss) private var dismiss

    let correctCount: Int
    let incorrectCount: Int

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LumenoteSpacing.section) {
                Text("복습 풀이 결과".l10n)
                    .font(LumenoteFont.rounded(size: 22, weight: .bold))
                    .foregroundStyle(.primary)

                VStack(spacing: LumenoteSpacing.md) {
                    countRow(title: "정답", count: correctCount, color: palette.quizCorrect)
                    countRow(title: "오답", count: incorrectCount, color: palette.quizIncorrect)
                }

                Button {
                    dismiss()
                } label: {
                    Text("학습 기록으로 돌아가기".l10n)
                        .font(LumenoteFont.body(.bold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, LumenoteSpacing.xxl)
                        .lumenoteCard()
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, LumenoteSpacing.popupInset)
            .padding(.vertical, LumenoteSpacing.xxxl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
    }

    private func countRow(title: String, count: Int, color: Color) -> some View {
        HStack {
            Text(title.l10n)
                .font(LumenoteFont.body(.bold))
            Spacer()
            Text("\(count)")
                .font(LumenoteFont.body(.bold))
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .padding(LumenoteSpacing.xxl)
        .lumenoteCard()
    }
}

private struct LearningReviewBackground: View {
    @Environment(\.appPalette) private var palette

    var body: some View {
        LinearGradient(
            colors: palette.backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private func reviewQuestionLimit(for skillKeys: Set<String>) -> Int {
    min(10, max(skillKeys.count, 1))
}

private struct IntervalReviewHost: View {
    @State private var model: IntervalQuizModel

    init(skillKeys: Set<String>, recorder: (any LearningRecording)?) {
        _model = State(
            initialValue: IntervalQuizModel(
                difficulty: .hard,
                questionLimit: reviewQuestionLimit(for: skillKeys),
                recorder: recorder,
                focusSkillKeys: skillKeys
            )
        )
    }

    var body: some View {
        if model.isFinished {
            LearningReviewResult(
                correctCount: model.correctCount,
                incorrectCount: model.incorrectCount
            )
        } else {
            IntervalQuizView(model: model)
        }
    }
}

private struct ScaleReviewHost: View {
    @State private var model: ScaleQuizModel

    init(skillKeys: Set<String>, recorder: (any LearningRecording)?) {
        _model = State(
            initialValue: ScaleQuizModel(
                difficulty: .hard,
                questionLimit: reviewQuestionLimit(for: skillKeys),
                recorder: recorder,
                focusSkillKeys: skillKeys
            )
        )
    }

    var body: some View {
        if model.isFinished {
            LearningReviewResult(
                correctCount: model.correctCount,
                incorrectCount: model.incorrectCount
            )
        } else {
            ScaleQuizView(model: model)
        }
    }
}

private struct KeySignatureReviewHost: View {
    @State private var model: KeySignatureQuizModel

    init(skillKeys: Set<String>, recorder: (any LearningRecording)?) {
        _model = State(
            initialValue: KeySignatureQuizModel(
                difficulty: .hard,
                questionLimit: reviewQuestionLimit(for: skillKeys),
                recorder: recorder,
                focusSkillKeys: skillKeys
            )
        )
    }

    var body: some View {
        if model.isFinished {
            LearningReviewResult(
                correctCount: model.correctCount,
                incorrectCount: model.incorrectCount
            )
        } else {
            KeySignatureQuizView(model: model)
        }
    }
}

private struct ChordReviewHost: View {
    @State private var model: ChordQuizModel

    init(skillKeys: Set<String>, recorder: (any LearningRecording)?) {
        _model = State(
            initialValue: ChordQuizModel(
                difficulty: .hard,
                questionLimit: reviewQuestionLimit(for: skillKeys),
                recorder: recorder,
                focusSkillKeys: skillKeys
            )
        )
    }

    var body: some View {
        if model.isFinished {
            LearningReviewResult(
                correctCount: model.correctCount,
                incorrectCount: model.incorrectCount
            )
        } else {
            ChordQuizView(model: model)
        }
    }
}

private struct DiatonicReviewHost: View {
    @State private var model: DiatonicChordQuizModel

    init(skillKeys: Set<String>, recorder: (any LearningRecording)?) {
        _model = State(
            initialValue: DiatonicChordQuizModel(
                difficulty: .hard,
                questionLimit: reviewQuestionLimit(for: skillKeys),
                recorder: recorder,
                focusSkillKeys: skillKeys
            )
        )
    }

    var body: some View {
        if model.isFinished {
            LearningReviewResult(
                correctCount: model.correctCount,
                incorrectCount: model.incorrectCount
            )
        } else {
            DiatonicChordQuizView(model: model)
        }
    }
}

private struct FretboardNoteReviewHost: View {
    @State private var model: FretboardNoteQuizModel

    init(skillKeys: Set<String>, recorder: (any LearningRecording)?) {
        _model = State(
            initialValue: FretboardNoteQuizModel(
                difficulty: .hard,
                questionLimit: reviewQuestionLimit(for: skillKeys),
                recorder: recorder,
                focusSkillKeys: skillKeys
            )
        )
    }

    var body: some View {
        if model.isFinished {
            LearningReviewResult(
                correctCount: model.correctCount,
                incorrectCount: model.incorrectCount
            )
        } else {
            FretboardNoteQuizView(model: model)
        }
    }
}

private struct FretboardDegreeReviewHost: View {
    @State private var model: FretboardDegreeQuizModel

    init(skillKeys: Set<String>, recorder: (any LearningRecording)?) {
        _model = State(
            initialValue: FretboardDegreeQuizModel(
                difficulty: .hard,
                questionLimit: reviewQuestionLimit(for: skillKeys),
                recorder: recorder,
                focusSkillKeys: skillKeys
            )
        )
    }

    var body: some View {
        if model.isFinished {
            LearningReviewResult(
                correctCount: model.correctCount,
                incorrectCount: model.incorrectCount
            )
        } else {
            FretboardDegreeQuizView(model: model)
        }
    }
}
