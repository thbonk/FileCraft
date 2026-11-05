/*
 * InspectorLoader.swift
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

import AVFoundation
import CoreMedia
import Darwin
import Foundation
import UniformTypeIdentifiers

/// Reads the inspector's details of an item off the caller's actor.
nonisolated internal enum InspectorLoader {

  // MARK: - Details

  /// Reads `url` with all details the inspector shows, except the folder size, which takes longer.
  @concurrent
  internal static func details(of url: URL) async throws -> ItemDetails {
    let item = try await FileSystemService().item(at: url)
    async let lastOpenedDates = SpotlightAttributes.lastOpenedDates(of: [url])
    async let info = ItemInfoProvider.info(for: item)
    async let duration = mediaDuration(of: item)
    async let original = OriginalResolver.original(of: item)
    let version = item.isPackage ? await SpotlightAttributes.bundleVersion(of: url) : nil
    let isLocked = (try? url.resourceValues(forKeys: [.isUserImmutableKey]).isUserImmutable) ?? false
    var pixelSize: PixelSize?
    if case .dimensions(let width, let height) = await info {
      pixelSize = PixelSize(width: width, height: height)
    }
    return ItemDetails(
      item: item,
      isLocked: isLocked == true,
      lastOpenedDate: await lastOpenedDates[url.path(percentEncoded: false)],
      version: version,
      pixelSize: pixelSize,
      duration: await duration,
      original: await original,
      ownerName: item.ownerID.map(AccountNames.userName(for:)),
      groupName: item.groupID.map(AccountNames.groupName(for:)),
      accessControlEntries: accessControlEntries(of: url),
      extendedAttributes: extendedAttributes(of: url))
  }

  /// The names of the items in the folder that contains `url`, for validating a new name.
  @concurrent
  internal static func siblingNames(of url: URL) async -> [String] {
    (try? FileManager.default.contentsOfDirectory(atPath: url.deletingLastPathComponent().path(percentEncoded: false))) ?? []
  }

  // MARK: - Private

  /// The duration of an audio or video file, or nil for other items.
  private static func mediaDuration(of item: FileItem) async -> TimeInterval? {
    guard item.contentType?.conforms(to: .audiovisualContent) == true else {
      return nil
    }
    guard let duration = try? await AVURLAsset(url: item.url).load(.duration), duration.isNumeric else {
      return nil
    }
    return duration.seconds
  }

  /// The extended attributes of `url` with the sizes of their values; links are not followed.
  internal static func extendedAttributes(of url: URL) -> [ExtendedAttribute] {
    let path = url.path(percentEncoded: false)
    let length = listxattr(path, nil, 0, XATTR_NOFOLLOW)
    guard length > 0 else {
      return []
    }
    var buffer = [CChar](repeating: 0, count: length)
    let read = listxattr(path, &buffer, length, XATTR_NOFOLLOW)
    guard read > 0 else {
      return []
    }
    let names = buffer.prefix(read).split(separator: 0).map { String(decoding: $0.map(UInt8.init(bitPattern:)), as: UTF8.self) }
    return names.map { name in
      ExtendedAttribute(name: name, size: max(getxattr(path, name, nil, 0, 0, XATTR_NOFOLLOW), 0))
    }
  }

  /// The access control entries of `url`, for example "staff (group): allow read, write".
  internal static func accessControlEntries(of url: URL) -> [String] {
    guard let acl = acl_get_link_np(url.path(percentEncoded: false), ACL_TYPE_EXTENDED) else {
      return []
    }
    defer {
      acl_free(UnsafeMutableRawPointer(acl))
    }
    guard let text = acl_to_text(acl, nil) else {
      return []
    }
    defer {
      acl_free(text)
    }
    // The first line is the header "!#acl 1"; each further line is "kind:uuid:name:id:allow|deny:rights".
    return String(cString: text).split(separator: "\n").dropFirst().map { line in
      let fields = line.split(separator: ":", omittingEmptySubsequences: false)
      guard fields.count >= 6 else {
        return String(line)
      }
      let rights = fields[5].split(separator: ",").joined(separator: ", ")
      return "\(fields[2]) (\(fields[0])): \(fields[4]) \(rights)"
    }
  }
}
