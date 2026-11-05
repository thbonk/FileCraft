/*
 * HelperFileSystem.swift
 * Shared
 *
 * Created by Thomas Bonk on 2026-11-05.
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

/// The file operations of the privileged helper (design decision D11), on file descriptors.
///
/// Every path must be absolute and free of "." and "..". Its folder is resolved once with `realpath` and then opened
/// from "/" component by component without following symbolic links, so that a folder swapped for a link meanwhile
/// makes the request fail. The item itself is never followed: a symbolic link is changed, copied or deleted itself.
/// Locations protected by System Integrity Protection are refused before anything happens.
nonisolated internal enum HelperFileSystem {

  // MARK: - Types

  /// An open folder and the name of an item in it; the descriptor is closed with the value.
  internal final class Location {
    internal let folder: Int32
    internal let name: String

    internal init(folder: Int32, name: String) {
      self.folder = folder
      self.name = name
    }

    deinit {
      close(folder)
    }
  }

  // MARK: - Paths

  /// Locations protected by System Integrity Protection.
  private static let protectedPrefixes = ["/System", "/bin", "/sbin", "/usr", "/Library/Apple"]
  /// Locations inside protected ones that are not protected.
  private static let unprotectedPrefixes = ["/usr/local"]

  /// Whether System Integrity Protection protects `path`.
  internal static func isProtected(_ path: String) -> Bool {
    func isInside(_ prefix: String) -> Bool {
      path == prefix || path.hasPrefix(prefix + "/")
    }
    return unprotectedPrefixes.contains(where: isInside) == false && protectedPrefixes.contains(where: isInside)
  }

  /// Checks `path` without touching the file system.
  internal static func validate(_ path: String) throws(HelperFailure) {
    _ = try components(of: path)
    if isProtected(path) {
      throw .protectedLocation
    }
  }

  /// Opens the folder of `path` and names the item in it.
  internal static func locate(_ path: String) throws(HelperFailure) -> Location {
    try validate(path)
    let parts = try components(of: path)
    guard let name = parts.last else {
      throw .invalidPath
    }
    let parentPath = "/" + parts.dropLast().joined(separator: "/")
    guard let resolved = realpath(parentPath, nil) else {
      throw .posix(errno)
    }
    let resolvedParent = String(cString: resolved)
    free(resolved)
    if isProtected(resolvedParent == "/" ? "/" + name : resolvedParent + "/" + name) {
      throw .protectedLocation
    }
    var folder = open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
    guard folder >= 0 else {
      throw .posix(errno)
    }
    for component in resolvedParent.split(separator: "/") {
      let next = openat(folder, String(component), O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
      let code = errno
      close(folder)
      guard next >= 0 else {
        // A component that became a symbolic link after resolving.
        throw code == ELOOP || code == ENOTDIR ? .invalidPath : .posix(code)
      }
      folder = next
    }
    return Location(folder: folder, name: String(name))
  }

  // MARK: - Commands

  internal static func createFolder(_ path: String) throws(HelperFailure) {
    let location = try locate(path)
    try check(mkdirat(location.folder, location.name, 0o755))
  }

  /// Renames the item within its folder, never replacing an existing item.
  internal static func rename(_ path: String, to newName: String) throws(HelperFailure) {
    guard newName.isEmpty == false, newName.contains("/") == false, newName != ".", newName != ".." else {
      throw .invalidPath
    }
    let location = try locate(path)
    try check(renameatx_np(location.folder, location.name, location.folder, newName, UInt32(RENAME_EXCL)))
  }

  internal static func setOwner(_ path: String, owner: UInt32, group: UInt32) throws(HelperFailure) {
    let location = try locate(path)
    try check(fchownat(location.folder, location.name, owner, group, AT_SYMLINK_NOFOLLOW))
  }

  internal static func setMode(_ path: String, mode: UInt16) throws(HelperFailure) {
    let location = try locate(path)
    try check(fchmodat(location.folder, location.name, mode_t(mode), AT_SYMLINK_NOFOLLOW))
  }

  internal static func setFlags(_ path: String, flags: UInt32) throws(HelperFailure) {
    let location = try locate(path)
    // O_SYMLINK opens a symbolic link itself instead of what it points to.
    let descriptor = openat(location.folder, location.name, O_RDONLY | O_SYMLINK | O_CLOEXEC)
    guard descriptor >= 0 else {
      throw .posix(errno)
    }
    defer {
      close(descriptor)
    }
    try check(fchflags(descriptor, flags))
  }

  /// The items in the folder at `path`.
  internal static func list(_ path: String) throws(HelperFailure) -> [HelperListedItem] {
    let location = try locate(path)
    let folder = openat(location.folder, location.name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
    guard folder >= 0 else {
      throw .posix(errno)
    }
    defer {
      close(folder)
    }
    return try entryNames(of: folder).compactMap { name in
      var status = stat()
      guard fstatat(folder, name, &status, AT_SYMLINK_NOFOLLOW) == 0 else {
        return nil
      }
      let type = status.st_mode & S_IFMT
      let modification = status.st_mtimespec
      return HelperListedItem(
        name: name,
        isDirectory: type == S_IFDIR,
        isSymbolicLink: type == S_IFLNK,
        size: Int64(status.st_size),
        modificationDate: Date(timeIntervalSince1970: Double(modification.tv_sec) + Double(modification.tv_nsec) / 1e9))
    }
  }

  // MARK: - Jobs

  /// Runs `job`, reporting to `context`; a copy that fails or is cancelled is removed.
  ///
  /// - Throws: `.posix(ECANCELED)` when the context was cancelled.
  internal static func run(_ job: HelperJob, context: HelperJobContext) throws(HelperFailure) {
    switch job {
    case .copy(let source, let destination):
      try copy(try locate(source), to: try locate(destination), context: context)
    case .move(let source, let destination):
      let from = try locate(source)
      let to = try locate(destination)
      if renameatx_np(from.folder, from.name, to.folder, to.name, UInt32(RENAME_EXCL)) == 0 {
        context.finishItem(bytes: 0)
        return
      }
      guard errno == EXDEV else {
        throw .posix(errno)
      }
      // Across volumes: the source goes only after its copy completed.
      try copy(from, to: to, context: context)
      try deleteItem(named: from.name, in: from.folder, context: context)
    case .delete(let path):
      let location = try locate(path)
      try deleteItem(named: location.name, in: location.folder, context: context)
    }
  }

  // MARK: - Private

  private static func components(of path: String) throws(HelperFailure) -> [Substring] {
    guard path.hasPrefix("/") else {
      throw .invalidPath
    }
    var trimmed = path.dropFirst()
    if trimmed.hasSuffix("/") {
      trimmed = trimmed.dropLast()
    }
    let parts = trimmed.split(separator: "/", omittingEmptySubsequences: false)
    guard parts.isEmpty == false, parts.allSatisfy({ $0.isEmpty == false && $0 != "." && $0 != ".." }) else {
      throw .invalidPath
    }
    return parts
  }

  private static func check(_ result: Int32) throws(HelperFailure) {
    guard result == 0 else {
      throw .posix(errno)
    }
  }

  /// The names in the open folder `folder`, which stays open.
  private static func entryNames(of folder: Int32) throws(HelperFailure) -> [String] {
    let copy = dup(folder)
    guard copy >= 0, let directory = fdopendir(copy) else {
      let code = errno
      if copy >= 0 {
        close(copy)
      }
      throw .posix(code)
    }
    defer {
      closedir(directory)
    }
    var names: [String] = []
    while let entry = readdir(directory) {
      let name = withUnsafeBytes(of: entry.pointee.d_name) { bytes in
        bytes.baseAddress.map { String(cString: $0.assumingMemoryBound(to: CChar.self)) } ?? ""
      }
      if name.isEmpty == false, name != ".", name != ".." {
        names.append(name)
      }
    }
    return names
  }

  /// Copies a whole item; a partial copy goes when the copy fails or is cancelled.
  private static func copy(_ source: Location, to destination: Location, context: HelperJobContext) throws(HelperFailure) {
    do throws(HelperFailure) {
      try copyItem(named: source.name, in: source.folder, to: destination.name, in: destination.folder, context: context)
    } catch {
      try? deleteItem(named: destination.name, in: destination.folder, context: HelperJobContext())
      throw error
    }
  }

  private static func copyItem(
    named name: String, in sourceFolder: Int32, to destinationName: String, in destinationFolder: Int32,
    context: HelperJobContext
  ) throws(HelperFailure) {
    guard context.isCancelled == false else {
      throw .posix(ECANCELED)
    }
    var status = stat()
    guard fstatat(sourceFolder, name, &status, AT_SYMLINK_NOFOLLOW) == 0 else {
      throw .posix(errno)
    }
    switch status.st_mode & S_IFMT {
    case S_IFDIR:
      try check(mkdirat(destinationFolder, destinationName, 0o700))
      let source = try openFolder(name, in: sourceFolder)
      defer {
        close(source)
      }
      let destination = try openFolder(destinationName, in: destinationFolder)
      defer {
        close(destination)
      }
      for child in try entryNames(of: source) {
        try copyItem(named: child, in: source, to: child, in: destination, context: context)
      }
      // The folder's permissions and dates come last, after its contents changed it.
      guard fcopyfile(source, destination, nil, copyfile_flags_t(COPYFILE_METADATA)) == 0 else {
        throw .posix(errno)
      }
      context.finishItem(bytes: 0)
    case S_IFLNK:
      var buffer = [CChar](repeating: 0, count: Int(PATH_MAX) + 1)
      let length = readlinkat(sourceFolder, name, &buffer, buffer.count - 1)
      guard length >= 0 else {
        throw .posix(errno)
      }
      let target = String(decoding: buffer[..<length].map { UInt8(bitPattern: $0) }, as: UTF8.self)
      try check(symlinkat(target, destinationFolder, destinationName))
      context.finishItem(bytes: 0)
    case S_IFREG:
      let source = openat(sourceFolder, name, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
      guard source >= 0 else {
        throw .posix(errno)
      }
      defer {
        close(source)
      }
      let destination = openat(destinationFolder, destinationName, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
      guard destination >= 0 else {
        throw .posix(errno)
      }
      defer {
        close(destination)
      }
      try copyData(from: source, to: destination, context: context)
      context.finishItem(bytes: Int64(status.st_size))
    default:
      throw .posix(ENOTSUP)
    }
  }

  private static func openFolder(_ name: String, in folder: Int32) throws(HelperFailure) -> Int32 {
    let descriptor = openat(folder, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
    guard descriptor >= 0 else {
      throw .posix(errno)
    }
    return descriptor
  }

  /// Copies data, extended attributes, access control list, permissions and dates of an open file.
  private static func copyData(from source: Int32, to destination: Int32, context: HelperJobContext) throws(HelperFailure) {
    guard let state = copyfile_state_alloc() else {
      throw .posix(ENOMEM)
    }
    defer {
      copyfile_state_free(state)
    }
    let callback: copyfile_callback_t = { what, stage, state, _, _, info in
      guard let info else {
        return COPYFILE_CONTINUE
      }
      let context = Unmanaged<HelperJobContext>.fromOpaque(info).takeUnretainedValue()
      guard context.isCancelled == false else {
        return COPYFILE_QUIT
      }
      if what == COPYFILE_COPY_DATA, stage == COPYFILE_PROGRESS, let state {
        var copied: off_t = 0
        if copyfile_state_get(state, UInt32(COPYFILE_STATE_COPIED), &copied) == 0 {
          context.setCurrentFileBytes(Int64(copied))
        }
      }
      return COPYFILE_CONTINUE
    }
    copyfile_state_set(state, UInt32(COPYFILE_STATE_STATUS_CB), unsafeBitCast(callback, to: UnsafeRawPointer.self))
    copyfile_state_set(state, UInt32(COPYFILE_STATE_STATUS_CTX), Unmanaged.passUnretained(context).toOpaque())
    let result = withExtendedLifetime(context) {
      fcopyfile(source, destination, state, copyfile_flags_t(COPYFILE_ALL))
    }
    guard context.isCancelled == false else {
      throw .posix(ECANCELED)
    }
    guard result == 0 else {
      throw .posix(errno)
    }
  }

  /// Deletes `name` in `folder`: a folder's contents first, a symbolic link itself.
  private static func deleteItem(named name: String, in folder: Int32, context: HelperJobContext) throws(HelperFailure) {
    guard context.isCancelled == false else {
      throw .posix(ECANCELED)
    }
    var status = stat()
    guard fstatat(folder, name, &status, AT_SYMLINK_NOFOLLOW) == 0 else {
      throw .posix(errno)
    }
    if status.st_mode & S_IFMT == S_IFDIR {
      let child = try openFolder(name, in: folder)
      defer {
        close(child)
      }
      for entry in try entryNames(of: child) {
        try deleteItem(named: entry, in: child, context: context)
      }
      try check(unlinkat(folder, name, AT_REMOVEDIR))
      context.finishItem(bytes: 0)
    } else {
      try check(unlinkat(folder, name, 0))
      context.finishItem(bytes: status.st_mode & S_IFMT == S_IFREG ? Int64(status.st_size) : 0)
    }
  }
}
