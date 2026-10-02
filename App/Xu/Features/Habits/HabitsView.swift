import SwiftUI
import SwiftData
import XuCore

/// Thói quen tài chính (docs/05): chốt ngày, sức mạnh thói quen không reset về 0, chuỗi mềm, ngày nghỉ.
struct HabitsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<MoneyHabit> { $0.isArchived == false }, sort: \MoneyHabit.createdAt)
    private var habits: [MoneyHabit]
    @Query private var closures: [DayClosure]
    @Query private var records: [TransactionRecord]
    @AppStorage(AppSettings.Key.language, store: AppSettings.defaults) private var language: AppLanguage = .vi
    @State private var showPaywall = false
    private let store = ProStore.shared

    var body: some View {
        let calendar = Calendar.current
        let today = DayKey(Date(), calendar: calendar)
        let closedDays = Set(closures.map(\.dayKey))
        let entries = records.map {
            LedgerEntry(amount: $0.amount, isIncome: $0.isIncome, categoryID: $0.categoryID,
                        day: DayKey($0.occurredAt, calendar: calendar))
        }

        NavigationStack {
            List {
                Section {
                    let isClosed = closedDays.contains(today)
                    Button {
                        try? Ledger.setDayClosed(today, closed: !isClosed, in: context)
                    } label: {
                        Label(language.t(isClosed ? .dayClosed : .closeDay),
                              systemImage: isClosed ? "checkmark.circle.fill" : "moon.stars")
                    }
                    .sensoryFeedback(.success, trigger: isClosed)
                } footer: {
                    Text(language.t(.closeDayFooter))
                }

                Section {
                    ForEach(habits) { habit in
                        HabitRow(habit: habit, today: today, language: language,
                                 progress: progress(for: habit, entries: entries, closedDays: closedDays,
                                                    today: today, calendar: calendar),
                                 onToggleDone: { toggleCheckIn(habit, rest: false, today: today) },
                                 onToggleRest: { toggleCheckIn(habit, rest: true, today: today) })
                    }
                    .onDelete { offsets in
                        for i in offsets { habits[i].isArchived = true }
                        try? context.save()
                    }
                }

                let available = HabitTemplate.allCases.filter { template in !habits.contains { $0.template == template } }
                if !available.isEmpty {
                    if ProPlan.canAddHabit(activeHabits: habits.count, isPro: store.isPro) {
                        Section {
                            Menu {
                                ForEach(available, id: \.self) { template in
                                    Button(template.emoji + " " + template.title(in: language)) { add(template) }
                                }
                            } label: {
                                Label(language.t(.addHabit), systemImage: "plus")
                            }
                        }
                    } else {
                        // Bản miễn phí đã đủ thói quen: nói rõ, cho chọn bỏ bớt hoặc xem Xu Pro. Thói quen cũ không bị tắt.
                        Section {
                            Button { showPaywall = true } label: {
                                Label(language.t(.addHabit), systemImage: "plus")
                            }
                        } footer: {
                            Text(language.t(.proHabitLimit, "\(ProPlan.freeHabitLimit)"))
                        }
                    }
                }
            }
            .navigationTitle(language.t(.habitsTitle))
            .toolbar { Button(language.t(.done)) { dismiss() } }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private func progress(for habit: MoneyHabit, entries: [LedgerEntry], closedDays: Set<DayKey>,
                          today: DayKey, calendar: Calendar) -> HabitProgress {
        let checkIns = habit.checkIns ?? []
        return HabitProgress.compute(template: habit.template, entries: entries, closedDays: closedDays,
                                     manualDays: Set(checkIns.filter { !$0.isRest }.map(\.dayKey)),
                                     restDays: Set(checkIns.filter(\.isRest).map(\.dayKey)),
                                     from: DayKey(habit.createdAt, calendar: calendar), today: today, calendar: calendar)
    }

    /// Bấm lần nữa là bỏ đánh dấu. Đánh dấu "nghỉ" thay cho đánh dấu "xong" của cùng ngày và ngược lại.
    private func toggleCheckIn(_ habit: MoneyHabit, rest: Bool, today: DayKey) {
        let todays = (habit.checkIns ?? []).filter { $0.dayKey == today }
        let alreadySame = todays.contains { $0.isRest == rest }
        for checkIn in todays { context.delete(checkIn) }
        if !alreadySame {
            context.insert(HabitCheckIn(day: today, isRest: rest, habit: habit))
        }
        try? context.save()
    }

    private func add(_ template: HabitTemplate) {
        if let archived = (try? context.fetch(FetchDescriptor<MoneyHabit>()))?.first(where: { $0.template == template }) {
            archived.isArchived = false   // bật lại thì giữ lịch sử cũ
        } else {
            context.insert(MoneyHabit(template: template))
        }
        try? context.save()
    }
}

private struct HabitRow: View {
    let habit: MoneyHabit
    let today: DayKey
    let language: AppLanguage
    let progress: HabitProgress
    let onToggleDone: () -> Void
    let onToggleRest: () -> Void

    private var isRestingToday: Bool {
        (habit.checkIns ?? []).contains { $0.isRest && $0.dayKey == today }
    }

    var body: some View {
        HStack(spacing: 12) {
            StrengthRing(value: progress.strength)
            VStack(alignment: .leading, spacing: 2) {
                // Chưa có tên tự đặt: hiện tên mẫu theo ngôn ngữ đang chọn.
                Text(habit.template.emoji + " " + habit.template.title(in: language))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if !habit.template.isAutomatic && !isRestingToday {
                Button(language.t(progress.isDoneToday ? .doneToday : .markDone), action: onToggleDone)
                    .buttonStyle(.bordered)
            }
        }
        .swipeActions(edge: .leading) {
            Button(language.t(.restToday), action: onToggleRest).tint(.indigo)
        }
    }

    private var detail: String {
        if isRestingToday { return language.t(.restingToday) }
        let percent = "\(Int((progress.strength * 100).rounded()))%"
        if progress.streak > 0 {
            return language.t(.streakDays, "\(progress.streak)") + " · " + language.t(.strength, percent)
        }
        if progress.strength > 0 { return language.t(.streakRestart, percent) }
        return habit.template.isAutomatic ? language.t(.automaticHabitHint) : language.t(.streakNone)
    }
}

/// Vòng sức mạnh thói quen. Màu nhấn của app, không bao giờ đỏ (docs/05).
private struct StrengthRing: View {
    let value: Double

    var body: some View {
        ZStack {
            Circle().stroke(.quaternary, lineWidth: 5)
            Circle()
                .trim(from: 0, to: max(0.02, value))
                .stroke(.tint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int((value * 100).rounded()))")
                .font(.caption2.monospacedDigit())
        }
        .frame(width: 40, height: 40)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Int((value * 100).rounded()))%")
    }
}
