/*
 * SplitDivider.swift
 * FileCraft
 *
 * Created by Thomas Bonk on 2026-10-30.
 * Copyright 2026 Thomas Bonk <thomas@meandmymac.de>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *         http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import SwiftUI

/// A one-point separator that resizes the neighboring areas when dragged.
internal struct SplitDivider: View {

  // MARK: - Properties

  /// The axis along which the neighboring areas are arranged.
  internal let axis: Axis
  /// Receives the distance dragged since the previous call, in points.
  internal let onDrag: (CGFloat) -> Void

  @State private var lastTranslation: CGFloat = 0

  // MARK: - Body

  internal var body: some View {
    Rectangle()
      .fill(.separator)
      .frame(width: axis == .horizontal ? 1 : nil, height: axis == .vertical ? 1 : nil)
      .overlay {
        Color.clear
          .frame(width: axis == .horizontal ? 9 : nil, height: axis == .vertical ? 9 : nil)
          .contentShape(Rectangle())
          .pointerStyle(axis == .horizontal ? .columnResize : .rowResize)
          .gesture(drag)
      }
      .accessibilityHidden(true)
  }

  // MARK: - Private

  private var drag: some Gesture {
    DragGesture(minimumDistance: 1, coordinateSpace: .global)
      .onChanged { value in
        let translation = axis == .horizontal ? value.translation.width : value.translation.height
        onDrag(translation - lastTranslation)
        lastTranslation = translation
      }
      .onEnded { _ in
        lastTranslation = 0
      }
  }
}

/// Two areas side by side or stacked, separated by a draggable divider.
internal struct PaneSplitView<First: View, Second: View>: View {

  // MARK: - Properties

  internal let axis: Axis
  /// The share of the space taken by the first area.
  @Binding internal var fraction: Double
  internal let fractionRange: ClosedRange<Double>
  @ViewBuilder internal let first: First
  @ViewBuilder internal let second: Second

  // MARK: - Body

  internal var body: some View {
    GeometryReader { geometry in
      let length = axis == .horizontal ? geometry.size.width : geometry.size.height
      let firstLength = max(0, length * fraction)
      let stack = axis == .horizontal ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(VStackLayout(spacing: 0))
      stack {
        first
          .frame(width: axis == .horizontal ? firstLength : nil, height: axis == .vertical ? firstLength : nil)
        SplitDivider(axis: axis) { delta in
          guard length > 0 else {
            return
          }
          let proposed = (length * fraction + delta) / length
          fraction = min(max(proposed, fractionRange.lowerBound), fractionRange.upperBound)
        }
        second
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
  }
}

#Preview {
  @Previewable @State var fraction = 0.4

  PaneSplitView(axis: .horizontal, fraction: $fraction, fractionRange: 0.15...0.85) {
    Text("First").frame(maxWidth: .infinity, maxHeight: .infinity)
  } second: {
    Text("Second")
  }
  .frame(width: 500, height: 200)
}
