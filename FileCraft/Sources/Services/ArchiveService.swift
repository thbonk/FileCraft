/*
 * ArchiveService.swift
 * FileCraft
 *
 * Created by Thomas Bonk on 2026-11-04.
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

import Darwin
import Foundation

/// Creates and expands archives with the tools included with macOS (design decision D10): `/usr/bin/ditto` for
/// Finder-compatible ZIP archives, `/usr/bin/tar` for the tar formats and `/usr/bin/gzip` for single gzip files.
///
/// The calls block while the tool runs, so they run on an operation's thread. Pausing the operation suspends the
/// tool; cancelling it terminates the tool and removes the partial output.
nonisolated internal enum ArchiveService {

  // MARK: - Types

  /// The kinds of archives that Expand understands.
  internal enum ArchiveKind: Hashable, Sendable {
    case zip
    case tar
    case tarGzip
    case tarBzip2
    case tarXz
    /// A single gzip-compressed file.
    case gzip
  }

  /// A failure of an archive tool, with its message.
  internal struct ToolError: LocalizedError, Hashable, Sendable {
    internal let message: String

    internal var errorDescription: String? {
      message.isEmpty ? String(localized: "The archive could not be processed.") : message
    }
  }

  // MARK: - Recognizing

  /// The kind of the archive at `url`, judged by its name, or nil when Expand does not understand it.
  internal static func kind(of url: URL) -> ArchiveKind? {
    let name = url.lastPathComponent.lowercased()
    let suffixes: [(String, ArchiveKind)] = [
      (".tar.gz", .tarGzip), (".tgz", .tarGzip), (".tar.bz2", .tarBzip2), (".tbz2", .tarBzip2), (".tbz", .tarBzip2),
      (".tar.xz", .tarXz), (".txz", .tarXz), (".tar", .tar), (".zip", .zip), (".gz", .gzip),
    ]
    return suffixes.first { name.hasSuffix($0.0) && name.count > $0.0.count }?.1
  }

  internal static func isArchive(_ url: URL) -> Bool {
    kind(of: url) != nil && FileCopier.isDirectory(url) == false
  }

  /// The extension of archives in `format`.
  internal static func pathExtension(of format: CompressionFormat) -> String {
    switch format {
    case .zip:
      "zip"
    case .tarGzip:
      "tar.gz"
    case .tarBzip2:
      "tar.bz2"
    case .tarXz:
      "tar.xz"
    }
  }

  // MARK: - Compressing

  /// Puts `items` into a new archive at `archive` in `format`. One item keeps its own folder in the archive; several
  /// items sit at the archive's top level, as in Finder's "Archive.zip".
  internal static func compress(_ items: [URL], into archive: URL, format: CompressionFormat, control: OperationControl) throws {
    let parents = Set(items.map { $0.deletingLastPathComponent().comparablePath })
    do {
      if items.count == 1, let item = items.first {
        try compress(single: item, into: archive, format: format, control: control)
      } else if parents.count == 1, let parent = items.first?.deletingLastPathComponent(), format != .zip {
        try runTar(format, archive: archive, folder: parent, names: items.map(\.lastPathComponent), control: control)
      } else {
        try withStagingFolder(near: archive) { stage in
          for item in items {
            try clone(item, to: stage.appending(path: item.lastPathComponent))
          }
          if format == .zip {
            try run("/usr/bin/ditto", ["-c", "-k", "--sequesterRsrc", path(stage), path(archive)], control: control)
          } else {
            let names = try FileCopier.childNames(of: stage)
            try runTar(format, archive: archive, folder: stage, names: names, control: control)
          }
        }
      }
    } catch {
      try? FileManager.default.removeItem(at: archive)
      throw error
    }
  }

  // MARK: - Expanding

  /// Expands `archive` into `folder`. Each item at the archive's top level gets a free name there, such as
  /// "photos 2" when "photos" exists.
  ///
  /// - Returns: The expanded top-level items.
  internal static func expand(_ archive: URL, into folder: URL, control: OperationControl) throws -> [URL] {
    guard let kind = kind(of: archive) else {
      throw ToolError(message: String(localized: "FileCraft can’t expand archives of this kind."))
    }
    return try withStagingFolder(near: folder.appending(path: archive.lastPathComponent)) { stage in
      switch kind {
      case .zip:
        try run("/usr/bin/ditto", ["-x", "-k", path(archive), path(stage)], control: control)
      case .tar, .tarGzip, .tarBzip2, .tarXz:
        try run("/usr/bin/tar", ["-x", "-f", path(archive), "-C", path(stage)], control: control)
      case .gzip:
        let name = (archive.lastPathComponent as NSString).deletingPathExtension
        let output = stage.appending(path: name)
        guard FileManager.default.createFile(atPath: path(output), contents: nil),
          let handle = FileHandle(forWritingAtPath: path(output))
        else {
          throw ToolError(message: "")
        }
        defer {
          try? handle.close()
        }
        try run("/usr/bin/gzip", ["-d", "-c", path(archive)], standardOutput: handle, control: control)
      }
      // The expanded items move into the folder under free names; the staging folder is on the same volume.
      var expanded: [URL] = []
      for name in try FileCopier.childNames(of: stage) {
        let item = stage.appending(path: name)
        let existing = (try? FileManager.default.contentsOfDirectory(atPath: path(folder))) ?? []
        let freeName = UniqueNameGenerator().availableName(for: name, isFolder: FileCopier.isDirectory(item), existingNames: existing)
        let destination = folder.appending(path: freeName)
        guard try FileOperationWorker.renameWithinVolume(item, destination) else {
          try FileManager.default.moveItem(at: item, to: destination)
          expanded.append(destination)
          continue
        }
        expanded.append(destination)
      }
      return expanded
    }
  }

  // MARK: - Private

  private static func compress(single item: URL, into archive: URL, format: CompressionFormat, control: OperationControl) throws {
    switch format {
    case .zip:
      try run("/usr/bin/ditto", ["-c", "-k", "--sequesterRsrc", "--keepParent", path(item), path(archive)], control: control)
    case .tarGzip, .tarBzip2, .tarXz:
      try runTar(format, archive: archive, folder: item.deletingLastPathComponent(), names: [item.lastPathComponent], control: control)
    }
  }

  private static func runTar(_ format: CompressionFormat, archive: URL, folder: URL, names: [String], control: OperationControl) throws {
    let compression: String
    switch format {
    case .tarGzip:
      compression = "-z"
    case .tarBzip2:
      compression = "-j"
    case .tarXz, .zip:
      compression = "-J"
    }
    // "--" keeps names that start with a hyphen from being read as options.
    try run("/usr/bin/tar", ["-c", compression, "-f", path(archive), "-C", path(folder), "--"] + names, control: control)
  }

  /// Runs `body` with a hidden temporary folder next to `location`, on the same volume, and removes it afterwards.
  private static func withStagingFolder<Result>(near location: URL, _ body: (URL) throws -> Result) throws -> Result {
    let stage = location.deletingLastPathComponent().appending(path: ".FileCraft-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: stage, withIntermediateDirectories: false)
    defer {
      FileCopier.removePartialCopy(at: stage)
    }
    return try body(stage)
  }

  /// Clones `item` on APFS, which costs no space; elsewhere it is copied.
  private static func clone(_ item: URL, to destination: URL) throws {
    let result = item.withUnsafeFileSystemRepresentation { source in
      destination.withUnsafeFileSystemRepresentation { target -> Int32 in
        guard let source, let target else {
          return -1
        }
        return clonefile(source, target, UInt32(CLONE_NOFOLLOW))
      }
    }
    if result != 0 {
      try FileManager.default.copyItem(at: item, to: destination)
    }
  }

  /// Runs `tool` until it ends; pausing `control` suspends it, cancelling terminates it.
  ///
  /// - Throws: `CancellationError` when cancelled, `ToolError` with the tool's message when it fails.
  private static func run(
    _ tool: String, _ arguments: [String], standardOutput: FileHandle? = nil, control: OperationControl
  ) throws {
    let process = Process()
    process.executableURL = URL(filePath: tool)
    process.arguments = arguments
    process.standardOutput = standardOutput ?? FileHandle.nullDevice
    // A file instead of a pipe, so that a long message never blocks the tool.
    let messages = FileManager.default.temporaryDirectory.appending(path: "FileCraft-\(UUID().uuidString).log")
    FileManager.default.createFile(atPath: path(messages), contents: nil)
    defer {
      try? FileManager.default.removeItem(at: messages)
    }
    let messageHandle = FileHandle(forWritingAtPath: path(messages))
    process.standardError = messageHandle ?? FileHandle.nullDevice
    try process.run()
    var isSuspended = false
    while process.isRunning {
      if control.isCancelled {
        if isSuspended {
          process.resume()
        }
        process.terminate()
        process.waitUntilExit()
        throw CancellationError()
      }
      if control.isPaused != isSuspended {
        isSuspended = control.isPaused
        _ = isSuspended ? process.suspend() : process.resume()
      }
      Thread.sleep(forTimeInterval: 0.05)
    }
    try? messageHandle?.close()
    guard process.terminationStatus == 0 else {
      let message = (try? String(contentsOf: messages, encoding: .utf8)) ?? ""
      throw ToolError(message: message.trimmingCharacters(in: .whitespacesAndNewlines))
    }
  }

  private static func path(_ url: URL) -> String {
    url.path(percentEncoded: false)
  }
}
