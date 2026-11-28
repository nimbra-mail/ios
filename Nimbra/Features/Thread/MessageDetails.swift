import SwiftUI
import UIKit

/// The details card under an open message's header (03 · Thread · Details): From, To, Cc,
/// Bcc (on the account's own messages), Reply-To and the date, each label in a 64 pt column.
/// Long-pressing an address offers to copy it.
struct MessageDetails: View {
    let message: Message
    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            row(Text("From")) { person(message.from) }
            if !message.to.isEmpty {
                row(Text("To")) { people(message.to) }
            }
            if !message.cc.isEmpty {
                row(Text("Cc")) { people(message.cc) }
            }
            if !message.bcc.isEmpty {
                row(Text("Bcc")) { people(message.bcc) }
            }
            if let replyTo = message.replyTo {
                row(Text("Reply-To")) { person(replyTo) }
            }
            row(Text("Date")) {
                Text(message.date, format: .dateTime.weekday(.wide).month(.abbreviated).day().year().hour().minute())
                    .nimbraText(.subhead)
                    .foregroundStyle(Color.textPrimary)
                    .frame(minHeight: 22)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceHover, in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.borderSubtle))
    }

    private func row<Value: View>(_ label: Text, @ViewBuilder value: () -> Value) -> some View {
        HStack(alignment: .top, spacing: 8) {
            label
                .nimbraText(.footnote)
                .foregroundStyle(Color.textTertiary)
                .lineLimit(1)
                .frame(width: 64, height: 22, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) { value() }
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func people(_ people: [Person]) -> some View {
        ForEach(Array(people.enumerated()), id: \.offset) { _, someone in
            person(someone)
        }
    }

    /// A name with its address after it, or the address alone; "You" after the account's own.
    private func person(_ person: Person) -> some View {
        let isMine = app.accounts.contains { $0.email.caseInsensitiveCompare(person.email) == .orderedSame }
        let named = !person.name.isEmpty && person.name != person.email
        return HStack(spacing: 6) {
            if named {
                Text(verbatim: person.name)
                    .nimbraText(.subheadMedium)
                    .foregroundStyle(Color.textPrimary)
                    .layoutPriority(1)
                Text(verbatim: person.email)
                    .nimbraText(.subhead)
                    .foregroundStyle(Color.textTertiary)
            } else {
                Text(verbatim: person.email)
                    .nimbraText(.subhead)
                    .foregroundStyle(Color.textPrimary)
            }
            if isMine {
                LabelPill(name: String(localized: "You"))
            }
        }
        .lineLimit(1)
        .frame(minHeight: 22)
        .contentShape(.rect)
        .contextMenu {
            Button {
                UIPasteboard.general.string = person.email
            } label: {
                Label { Text("Copy address") } icon: { Icon(.copy) }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
