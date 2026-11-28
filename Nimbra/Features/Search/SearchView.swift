import SwiftUI

/// Search, as the Mac's finder: the account shown, the threads the device has listed at
/// once, then the server's (Gmail's search words) merged in, more as the list scrolls. The
/// field's clear button empties it; with nothing typed, the search tips (Gmail's search
/// words, which the engine also understands for an account with its own servers).
struct SearchView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if query.trimmingCharacters(in: .whitespaces).isEmpty {
                        tips
                    } else {
                        results
                    }
                }
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.immediately)
            .background(Color.bgList)
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Search mail"))
            .navigationDestination(for: MailThread.ID.self) { ThreadView(id: $0) }
            .task(id: query) {
                // The device's matches at once; the server once typing pauses.
                guard let account = app.accountID else { return }
                app.searchResults = app.localMatches(query, in: account)
                do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
                await app.find(query)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var results: some View {
        if !app.searchResults.isEmpty {
            overline("CONVERSATIONS")
            ForEach(app.searchResults) { thread in
                NavigationLink(value: thread.id) {
                    ThreadRow(thread: thread)
                }
                .buttonStyle(.plain)
            }
        }
        if app.isFinding {
            HStack(spacing: 8) {
                ProgressView()
                Text(app.account?.kind == .gmail ? "Searching Gmail" : "Searching")
                    .nimbraText(.subhead)
                    .foregroundStyle(Color.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        } else if app.searchNextPage != nil {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .task { await app.findMore(query) }
        } else if app.searchResults.isEmpty {
            VStack(spacing: 6) {
                Text("No results")
                    .nimbraText(.headline)
                    .foregroundStyle(Color.textPrimary)
                Text("Nothing matches “\(query)”.")
                    .nimbraText(.subhead)
                    .foregroundStyle(Color.textTertiary)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 40)
            .padding(.top, 60)
            .accessibilityElement(children: .combine)
        }
    }

    /// The search words, as the Mac's finder lists them.
    private var tips: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("SEARCH TIPS")
            GroupCard {
                ForEach(Array(SearchTip.all.enumerated()), id: \.element.words) { index, tip in
                    self.tip(tip, divider: index > 0)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private func tip(_ tip: SearchTip, divider: Bool) -> some View {
        Button {
            query = tip.query
        } label: {
            HStack(spacing: 12) {
                Text(verbatim: tip.words)
                    .nimbraText(.mono)
                    .foregroundStyle(Color.textPrimary)
                Spacer(minLength: 8)
                Text(tip.meaning)
                    .nimbraText(.subhead)
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .frame(minHeight: 50)
            .contentShape(.rect)
            .overlay(alignment: .top) {
                if divider { Rectangle().fill(Color.borderSubtle).frame(height: 1) }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private func overline(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .nimbraText(.overline)
            .foregroundStyle(Color.textFaint)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 6)
            .accessibilityAddTraits(.isHeader)
    }
}
