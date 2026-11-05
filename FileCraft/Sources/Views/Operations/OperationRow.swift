/*
 * OperationRow.swift
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

/// One operation in the Operations window: what it does, its progress with items, bytes, speed and remaining time,
/// and buttons to pause, resume or cancel it.
internal struct OperationRow: View {

  // MARK: - Properties

  internal let operation: FileOperationProgress
  internal let model: OperationQueueModel

  @Environment(\.locale) private var locale
  @AppStorage(SettingsKeys.sizeUnits.name) private var sizeUnits = SettingsKeys.sizeUnits.defaultValue

  // MARK: - Body

  internal var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: symbolName)
        .font(.title2)
        .foregroundStyle(.secondary)
        .frame(width: 28)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 4) {
        title
          .font(.headline)
          .lineLimit(1)
          .truncationMode(.middle)
        subtitle
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
        progressBar
        status
          .font(.caption)
          .foregroundStyle(operation.state == .failed ? Color.red : Color.secondary)
          .monospacedDigit()
      }
      Spacer(minLength: 8)
      controls
    }
    .padding(.vertical, 4)
  }

  // MARK: - Parts

  @ViewBuilder private var title: some View {
    if operation.sources.count == 1, let name = operation.sources.first?.lastPathComponent {
      switch operation.kind {
      case .copy:
        Text("Copying “\(name)”")
      case .move:
        Text("Moving “\(name)”")
      case .delete:
        Text("Deleting “\(name)”")
      case .compress:
        Text("Compressing “\(name)”")
      case .expand:
        Text("Expanding “\(name)”")
      }
    } else {
      switch operation.kind {
      case .copy:
        Text("Copying \(operation.sources.count) items")
      case .move:
        Text("Moving \(operation.sources.count) items")
      case .delete:
        Text("Deleting \(operation.sources.count) items")
      case .compress:
        Text("Compressing \(operation.sources.count) items")
      case .expand:
        Text("Expanding \(operation.sources.count) items")
      }
    }
  }

  private var subtitle: Text {
    switch operation.kind {
    case .copy, .move, .compress, .expand:
      Text("To “\(destinationName)”")
    case .delete:
      Text("In “\(destinationName)”")
    }
  }

  private var symbolName: String {
    switch operation.kind {
    case .copy:
      "doc.on.doc"
    case .move:
      "arrow.right.circle"
    case .delete:
      "trash"
    case .compress:
      "doc.zipper"
    case .expand:
      "shippingbox"
    }
  }

  @ViewBuilder private var progressBar: some View {
    switch operation.state {
    case .preparing:
      ProgressView()
        .progressViewStyle(.linear)
    case .running, .paused:
      ProgressView(value: operation.fractionCompleted)
    case .queued, .cancelled, .completed, .failed:
      EmptyView()
    }
  }

  private var status: Text {
    if operation.question != nil {
      return Text("Waiting for your decision")
    }
    switch operation.state {
    case .queued:
      return Text("Waiting…")
    case .preparing:
      return Text("Preparing…")
    case .paused:
      return Text("Paused")
    case .running:
      return Text(verbatim: progressSummary)
    case .completed:
      return Text("Completed")
    case .cancelled:
      return Text("Cancelled")
    case .failed:
      return Text("Finished with \(operation.errors.count) errors")
    }
  }

  @ViewBuilder private var controls: some View {
    if operation.state == .failed {
      Button("Show Errors") {
        model.showSummary(of: operation.id)
      }
    } else if operation.state.isFinished == false {
      HStack(spacing: 6) {
        if operation.state == .paused {
          Button("Resume", systemImage: "play.circle.fill") {
            Task { await model.resume(operation.id) }
          }
          .help("Resume")
        } else {
          Button("Pause", systemImage: "pause.circle.fill") {
            Task { await model.pause(operation.id) }
          }
          .help("Pause")
        }
        Button("Cancel", systemImage: "xmark.circle.fill") {
          Task { await model.cancel(operation.id) }
        }
        .help("Cancel")
      }
      .buttonStyle(.borderless)
      .labelStyle(.iconOnly)
      .font(.title3)
    }
  }

  // MARK: - Formatting

  private var destinationName: String {
    FileManager.default.displayName(atPath: operation.destination.path(percentEncoded: false))
  }

  /// For example "16 of 40 — 1.4 GB of 3.4 GB — 45 MB/s — About 1 minute remaining".
  private var progressSummary: String {
    let formatter = ByteSizeFormatter(units: sizeUnits, locale: locale)
    let processedBytes = formatter.string(for: operation.processedBytes)
    let totalBytes = formatter.string(for: operation.totalBytes)
    var parts = [
      String(localized: LocalizedStringResource("\(operation.processedItems) of \(operation.totalItems)", locale: locale)),
      String(localized: LocalizedStringResource("\(processedBytes) of \(totalBytes)", locale: locale)),
    ]
    if let bytesPerSecond = operation.bytesPerSecond {
      let speed = formatter.string(for: Int64(bytesPerSecond))
      parts.append(String(localized: LocalizedStringResource("\(speed)/s", locale: locale)))
    }
    if let seconds = operation.estimatedSecondsRemaining {
      let duration = Duration.seconds(max(seconds.rounded(.up), 1))
        .formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide, maximumUnitCount: 1).locale(locale))
      parts.append(String(localized: LocalizedStringResource("About \(duration) remaining", locale: locale)))
    }
    return parts.joined(separator: " — ")
  }
}

// MARK: - Previews

#Preview("English") {
  List {
    OperationRow(operation: OperationPreviewData.running, model: OperationQueueModel(engine: FileOperationEngine()))
    OperationRow(operation: OperationPreviewData.paused, model: OperationQueueModel(engine: FileOperationEngine()))
    OperationRow(operation: OperationPreviewData.failed, model: OperationQueueModel(engine: FileOperationEngine()))
    OperationRow(operation: OperationPreviewData.completed, model: OperationQueueModel(engine: FileOperationEngine()))
  }
  .frame(width: 520, height: 360)
}

#Preview("German") {
  List {
    OperationRow(operation: OperationPreviewData.running, model: OperationQueueModel(engine: FileOperationEngine()))
    OperationRow(operation: OperationPreviewData.queued, model: OperationQueueModel(engine: FileOperationEngine()))
    OperationRow(operation: OperationPreviewData.failed, model: OperationQueueModel(engine: FileOperationEngine()))
  }
  .frame(width: 520, height: 300)
  .environment(\.locale, Locale(identifier: "de"))
}
