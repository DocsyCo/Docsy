//
//  AsyncButton.swift
//  DocSee
//
//  Created by Noah Kamara on 10.11.24.
//

import SwiftUI


/// A button with an asynchronous, throwing action
public struct AsyncButton<Label: View>: View {
    enum Phase: Animatable {
        case initial
        case loading
        case success
        case failed
    }

    let action: () async throws -> Void
    let label: Label

    public init(
        action: @escaping () async throws -> Void,
        label: Label
    ) {
        self.action = action
        self.label = label
    }

    public init(
        action: @escaping () async throws -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.init(action: action, label: label())
    }

    public init(
        _ title: LocalizedStringKey,
        action: @escaping () async throws -> Void
    ) where Label == Text {
        self.init(action: action, label: Text(title))
    }

    @State var phase: Phase = .initial
    @State var invalidAttempts: Int = 0

    public var body: some View {
        Button {
            self.phase = .loading
            Task {
                do {
                    try await action()
                    self.phase = .success
                } catch {
                    self.phase = .failed
                    self.invalidAttempts += 1
                    print("AsyncButton: error ", error)
                }
            }
        } label: {
            label
                .opacity(phase == .loading ? 0 : 1)
                .overlay {
                    if phase == .loading {
                        ProgressView()
                    }
                }
        }
        .disabled(phase == .loading)
        .sensoryFeedback(trigger: phase, { oldValue, newValue in
            guard oldValue != newValue, newValue == .failed else {
                return .none
            }

            return .error
        })
        .modifier(ShakeEffect(shakes: phase == .failed ? 2 : 0))
        .animation(.linear.speed(1.5), value: invalidAttempts)
    }
}


#Preview {
    AsyncButton("Hello", action: {
        try await Task.sleep(for: .seconds(0.5))
        throw MockError()
    })
    .buttonStyle(.bordered)
}

fileprivate struct ShakeEffect: GeometryEffect {
    func effectValue(size: CGSize) -> ProjectionTransform {
        return ProjectionTransform(CGAffineTransform(
            translationX: -5 * sin(position * 2 * .pi),
            y: 0)
        )
    }

    init(shakes: Int) {
        position = CGFloat(shakes)
    }

    var position: CGFloat
    var animatableData: CGFloat {
        get { position }
        set { position = newValue }
    }
}

struct MockError: Error {}
