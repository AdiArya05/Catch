import SwiftUI

struct FeedbackBoardView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var posts: [FeedbackPost] = []
    @State private var error: String?
    @State private var loading = false
    @State private var composing = false
    @State private var draft = ""
    @State private var requestID = UUID()
    @State private var submitting = false
    @State private var newestFirst = true
    @State private var submitted = false
    @State private var votingIDs: Set<UUID> = []
    private var sortedPosts: [FeedbackPost] { newestFirst ? posts : posts.reversed() }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Shape Catch together").font(.largeTitle.bold())
                    Text("Ideas, bugs, little things. Tell us what would make Catch better.").foregroundStyle(.secondary)
                    if loading && posts.isEmpty { ProgressView().frame(maxWidth: .infinity) }
                    if let error {
                        Text(error).foregroundStyle(.secondary)
                        Button("Try again") { Task { await load() } }
                    } else if !loading && posts.isEmpty {
                        ContentUnavailableView("Be the first to share", systemImage: "bubble.left.and.text.bubble.right", description: Text("Tap + to give feedback."))
                    }
                    ForEach(sortedPosts) { post in
                        VStack(alignment: .leading, spacing: 16) {
                            Text(post.body).font(.body).textSelection(.enabled)
                            HStack {
                                Text(String(post.created_at.prefix(10))).font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Button {
                                    Task { await toggleUpvote(post) }
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: post.did_upvote == true ? "arrowtriangle.up.fill" : "arrowtriangle.up")
                                        Text("\(post.upvote_count ?? 0)")
                                    }
                                    .font(.caption.bold())
                                    .foregroundStyle(post.did_upvote == true ? .blue : .secondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(.primary.opacity(0.06), in: Capsule())
                                }
                                .buttonStyle(.plain)
                                .disabled(votingIDs.contains(post.id))
                                Text(post.status.capitalized).font(.caption.bold())
                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                    .background(.blue.opacity(0.14), in: Capsule())
                            }
                            if let reply = post.developer_response, !reply.isEmpty {
                                Text("Developer response").font(.caption.bold()).foregroundStyle(.secondary)
                                Text(reply).foregroundStyle(.secondary)
                            }
                        }
                        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 28))
                        .overlay(RoundedRectangle(cornerRadius: 28).stroke(.primary.opacity(0.1)))
                    }
                }.padding(24).padding(.bottom, 72)
            }
            .refreshable { await load() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close", systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly) }
                ToolbarItem(placement: .topBarTrailing) { Button("Reverse date order", systemImage: "arrow.up.arrow.down") { Haptics.tap(); withAnimation(.smooth) { newestFirst.toggle() } }.labelStyle(.iconOnly) }
            }
            .overlay(alignment: .bottomTrailing) {
                Button { Haptics.tap(); composing = true } label: {
                    Image(systemName: "plus").font(.system(size: 28, weight: .medium)).frame(width: 60, height: 60)
                }.buttonStyle(.borderedProminent).buttonBorderShape(.circle).padding(24).accessibilityLabel("Give feedback")
            }
            .task { await load() }
            .sheet(isPresented: $composing) {
                NavigationStack {
                    Form {
                        Section("What’s on your mind?") {
                            TextEditor(text: $draft).frame(minHeight: 180).accessibilityLabel("Your feedback")
                            Text("\(draft.count)/4,000").font(.caption).foregroundStyle(.secondary)
                        }
                        Text("No email needed. Feedback may appear publicly after review. Please leave out personal information.").font(.footnote).foregroundStyle(.secondary)
                        if let error { Text(error).foregroundStyle(.red) }
                    }
                    .navigationTitle("Give feedback")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { composing = false }.disabled(submitting) }
                        ToolbarItem(placement: .confirmationAction) {
                            Button(submitting ? "Sending…" : "Send") { Task { await send() } }
                                .disabled(submitting || !(10...4000).contains(draft.trimmingCharacters(in: .whitespacesAndNewlines).count))
                        }
                    }.interactiveDismissDisabled(submitting)
                }
            }
            .alert("Thanks for your feedback", isPresented: $submitted) { Button("Done", role: .cancel) {} } message: { Text("It’s been received and is awaiting review.") }
        }
    }
    @MainActor private func load() async {
        guard !loading else { return }; loading = true; defer { loading = false }
        do { posts = try await FeedbackService.shared.posts(); error = nil }
        catch { self.error = error.localizedDescription }
    }
    @MainActor private func send() async {
        guard !submitting else { return }; submitting = true; defer { submitting = false }
        do {
            try await FeedbackService.shared.submit(draft, id: requestID)
            draft = ""; requestID = UUID(); error = nil; composing = false; submitted = true; Haptics.tap(.medium)
            await load()
        } catch { self.error = error.localizedDescription }
    }

    @MainActor private func toggleUpvote(_ post: FeedbackPost) async {
        guard !votingIDs.contains(post.id) else { return }
        votingIDs.insert(post.id)
        defer { votingIDs.remove(post.id) }
        do {
            try await FeedbackService.shared.toggleUpvote(postID: post.id)
            Haptics.tap(.light)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
