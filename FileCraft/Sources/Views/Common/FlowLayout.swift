/*
 * FlowLayout.swift
 * FileCraft
 *
 * Created by Thomas Bonk on 2026-11-03.
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

/// Places its subviews in rows from leading to trailing, starting a new row when one is full, like tag chips.
internal struct FlowLayout: Layout {

  // MARK: - Properties

  internal var spacing: CGFloat = 6

  // MARK: - Layout

  internal func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let rows = rows(for: subviews, width: proposal.width ?? .infinity)
    let width: CGFloat = rows.map(\.width).max() ?? 0
    let rowHeights: CGFloat = rows.reduce(0) { $0 + $1.height }
    let gaps: CGFloat = spacing * CGFloat(max(rows.count - 1, 0))
    return CGSize(width: width, height: rowHeights + gaps)
  }

  internal func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    var y = bounds.minY
    for row in rows(for: subviews, width: bounds.width) {
      var x = bounds.minX
      for index in row.indices {
        let size = subviews[index].sizeThatFits(.unspecified)
        subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: ProposedViewSize(size))
        x += size.width + spacing
      }
      y += row.height + spacing
    }
  }

  // MARK: - Private

  private struct Row {
    var indices: [Int] = []
    var width: CGFloat = 0
    var height: CGFloat = 0
  }

  private func rows(for subviews: Subviews, width: CGFloat) -> [Row] {
    var rows: [Row] = []
    var current = Row()
    for index in subviews.indices {
      let size = subviews[index].sizeThatFits(.unspecified)
      let neededWidth = current.indices.isEmpty ? size.width : current.width + spacing + size.width
      if neededWidth > width, current.indices.isEmpty == false {
        rows.append(current)
        current = Row()
      }
      current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
      current.height = max(current.height, size.height)
      current.indices.append(index)
    }
    if current.indices.isEmpty == false {
      rows.append(current)
    }
    return rows
  }
}

#Preview {
  FlowLayout {
    ForEach(["Red", "Work", "Archive", "Important", "Travel", "Invoices"], id: \.self) { name in
      Text(verbatim: name)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(.quaternary, in: .capsule)
    }
  }
  .frame(width: 200)
  .padding()
}
