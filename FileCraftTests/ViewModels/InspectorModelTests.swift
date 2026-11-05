/*
 * InspectorModelTests.swift
 * FileCraftTests
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

import CoreGraphics
import Darwin
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import FileCraft

/// Undo groups are opened and closed explicitly, so that the tests do not depend on the run loop.
internal struct InspectorModelTests {

  // MARK: - Loading

  @Test
  internal func `A folder shows its recursive item count and size`() async throws {
    let directory = try TemporaryDirectory()
    let folder = try directory.createFolder("Project")
    try directory.createFolder("Project/Sources")
    try directory.createFile("Project/Sources/main.swift", contents: "print(1)")
    try directory.createFile("Project/README.md", contents: "# Project")
    let model = InspectorModel()

    await model.show([folder])

    #expect(model.details?.item.name == "Project")
    #expect(model.totalSize?.itemCount == 3)
    #expect(model.totalSize?.logicalBytes == 17)
    #expect(model.isCalculatingSize == false)
  }

  @Test
  internal func `Details include pixel size, original of a link and extended attributes`() async throws {
    let directory = try TemporaryDirectory()
    let image = directory.url.appending(path: "dot.png")
    try writePNG(width: 4, height: 3, to: image)
    let link = directory.url.appending(path: "dot link")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: image)
    let value = Array("hello".utf8)
    #expect(setxattr(image.path(percentEncoded: false), "de.meandmymac.test", value, value.count, 0, 0) == 0)

    let imageDetails = try await InspectorLoader.details(of: image)
    let linkDetails = try await InspectorLoader.details(of: link)

    #expect(imageDetails.pixelSize == PixelSize(width: 4, height: 3))
    #expect(imageDetails.extendedAttributes.contains(ExtendedAttribute(name: "de.meandmymac.test", size: 5)))
    #expect(imageDetails.original == nil)
    guard case .original(let target) = linkDetails.original else {
      Issue.record("Expected the original of the link, got \(String(describing: linkDetails.original))")
      return
    }
    #expect(target.path(percentEncoded: false) == image.path(percentEncoded: false))
  }

  @Test
  internal func `Several items show their number, total size and kinds`() async throws {
    let directory = try TemporaryDirectory()
    let first = try directory.createFile("a.txt", contents: "1234")
    let second = try directory.createFile("b.txt", contents: "56")
    let folder = try directory.createFolder("Folder")
    try directory.createFile("Folder/c.txt", contents: "789")
    let model = InspectorModel()

    await model.show([first, second, folder])

    #expect(model.items.count == 3)
    #expect(model.totalSize?.logicalBytes == 9)
    #expect(model.totalSize?.itemCount == 4)
  }

  // MARK: - Renaming

  @Test
  internal func `Renaming from the inspector can be undone`() async throws {
    let directory = try TemporaryDirectory()
    let file = try directory.createFile("Draft.pdf")
    let model = InspectorModel()
    let undoManager = UndoManager()
    undoManager.groupsByEvent = false
    await model.show([file])

    undoManager.beginUndoGrouping()
    model.rename(to: "Summary.pdf", undoManager: undoManager)
    await model.waitForPendingEdits()
    undoManager.endUndoGrouping()
    let renamedExists = exists("Summary.pdf", in: directory)
    undoManager.undo()
    await model.waitForPendingEdits()

    #expect(renamedExists)
    #expect(exists("Draft.pdf", in: directory))
    #expect(exists("Summary.pdf", in: directory) == false)
    #expect(model.details?.item.name == "Draft.pdf")
    #expect(undoManager.canRedo)
  }

  @Test
  internal func `An invalid or taken name shows an error and renames nothing`() async throws {
    let directory = try TemporaryDirectory()
    let file = try directory.createFile("Draft.pdf")
    try directory.createFile("Taken.pdf")
    let model = InspectorModel()
    await model.show([file])

    model.rename(to: "a/b", undoManager: nil)
    await model.waitForPendingEdits()
    let invalidError = model.editError
    model.rename(to: "taken.pdf", undoManager: nil)
    await model.waitForPendingEdits()

    #expect(invalidError == .invalidName(.invalidCharacter))
    #expect(model.editError == .invalidName(.alreadyExists("taken.pdf")))
    #expect(exists("Draft.pdf", in: directory))
  }

  // MARK: - Tags and Attributes

  @Test
  internal func `Removing a tag in the inspector can be undone`() async throws {
    let directory = try TemporaryDirectory()
    let file = try directory.createFile("report.txt")
    try setTags(["Work", "Blue"], of: file)
    let model = InspectorModel()
    let undoManager = groupedUndoManager()
    await model.show([file])

    try await edit(with: undoManager) {
      model.removeTag("Work", undoManager: undoManager)
      await model.waitForPendingEdits()
    }
    let tagsAfterRemoval = try tags(of: file)
    undoManager.undo()
    await model.waitForPendingEdits()

    #expect(tagsAfterRemoval == ["Blue"])
    #expect(try tags(of: file) == ["Work", "Blue"])
  }

  @Test
  internal func `A tag added to several items shows as theirs and undoes in one step`() async throws {
    let directory = try TemporaryDirectory()
    let first = try directory.createFile("a.txt")
    let second = try directory.createFile("b.txt")
    try setTags(["Archive"], of: first)
    let model = InspectorModel()
    let undoManager = groupedUndoManager()
    await model.show([first, second])
    let partialBefore = model.partialTags

    try await edit(with: undoManager) {
      model.addTag("Archive", undoManager: undoManager)
      await model.waitForPendingEdits()
    }
    let partialAfter = model.partialTags
    let secondTags = try tags(of: second)
    undoManager.undo()
    await model.waitForPendingEdits()

    #expect(partialBefore == ["Archive"])
    #expect(partialAfter.isEmpty)
    #expect(secondTags == ["Archive"])
    #expect(try tags(of: second).isEmpty)
    #expect(try tags(of: first) == ["Archive"])
  }

  @Test
  internal func `A mixed toggle sets an attribute of several items as one undoable edit`() async throws {
    let directory = try TemporaryDirectory()
    let first = try directory.createFile("a.txt")
    let second = try directory.createFile("b.txt")
    try setHidden(true, of: first)
    let model = InspectorModel()
    let undoManager = groupedUndoManager()
    await model.show([first, second])

    try await edit(with: undoManager) {
      for item in model.items {
        model.queueAttribute(.hidden, of: item, to: true, undoManager: undoManager)
      }
      await model.waitForPendingEdits()
    }
    let hiddenAfterToggle = try [first, second].map(isHidden)
    undoManager.undo()
    await model.waitForPendingEdits()

    #expect(hiddenAfterToggle == [true, true])
    #expect(try [first, second].map(isHidden) == [true, false])
  }

  // MARK: - Permissions

  @Test
  internal func `Turning on execute for the owner changes the mode and can be undone`() async throws {
    let directory = try TemporaryDirectory()
    let script = try directory.createFile("build.sh", contents: "#!/bin/sh")
    try setMode(0o644, of: script)
    let model = InspectorModel()
    let undoManager = groupedUndoManager()
    await model.show([script])

    try await edit(with: undoManager) {
      model.setPermission(0o100, to: true, undoManager: undoManager)
      await model.waitForPendingEdits()
    }
    let modeAfterToggle = try mode(of: script)
    let shownMode = model.details?.item.permissions
    undoManager.undo()
    await model.waitForPendingEdits()

    #expect(modeAfterToggle == 0o744)
    #expect(shownMode == 0o744)
    #expect(try mode(of: script) == 0o644)
  }

  @Test
  internal func `Enclosed items get the folder's read and write, and execute only where it belongs`() {
    #expect(ItemEditor.enclosedMode(current: 0o600, isDirectory: false, folderMode: 0o755) == 0o644)
    #expect(ItemEditor.enclosedMode(current: 0o700, isDirectory: false, folderMode: 0o755) == 0o755)
    #expect(ItemEditor.enclosedMode(current: 0o700, isDirectory: true, folderMode: 0o750) == 0o750)
    #expect(ItemEditor.enclosedMode(current: 0o4700, isDirectory: false, folderMode: 0o755) == 0o4755)
  }

  @Test
  internal func `Apply to Enclosed Items changes every item inside and undoes in one step`() async throws {
    let directory = try TemporaryDirectory()
    let folder = try directory.createFolder("Shared")
    let subfolder = try directory.createFolder("Shared/Sub")
    let file = try directory.createFile("Shared/Sub/notes.txt")
    try setMode(0o755, of: folder)
    try setMode(0o700, of: subfolder)
    try setMode(0o600, of: file)
    let model = InspectorModel()
    let undoManager = groupedUndoManager()
    await model.show([folder])

    try await edit(with: undoManager) {
      model.applyPermissionsToEnclosedItems(undoManager: undoManager)
      await model.waitForPendingEdits()
    }
    let modesAfterApply = try [subfolder, file].map(mode)
    undoManager.undo()
    await model.waitForPendingEdits()

    #expect(modesAfterApply == [0o755, 0o644])
    #expect(try [subfolder, file].map(mode) == [0o700, 0o600])
  }

  // MARK: - Helpers

  private func groupedUndoManager() -> UndoManager {
    let undoManager = UndoManager()
    undoManager.groupsByEvent = false
    return undoManager
  }

  /// Runs `body` inside one undo group.
  private func edit(with undoManager: UndoManager, _ body: () async throws -> Void) async throws {
    undoManager.beginUndoGrouping()
    try await body()
    undoManager.endUndoGrouping()
  }

  private func setTags(_ tags: [String], of url: URL) throws {
    var url = url
    var values = URLResourceValues()
    values.tagNames = tags
    try url.setResourceValues(values)
  }

  private func tags(of url: URL) throws -> [String] {
    var url = url
    url.removeAllCachedResourceValues()
    return try url.resourceValues(forKeys: [.tagNamesKey]).tagNames ?? []
  }

  private func setHidden(_ isHidden: Bool, of url: URL) throws {
    var url = url
    var values = URLResourceValues()
    values.isHidden = isHidden
    try url.setResourceValues(values)
  }

  private func isHidden(_ url: URL) throws -> Bool {
    var url = url
    url.removeAllCachedResourceValues()
    return try url.resourceValues(forKeys: [.isHiddenKey]).isHidden ?? false
  }

  private func setMode(_ mode: UInt16, of url: URL) throws {
    try FileManager.default.setAttributes([.posixPermissions: NSNumber(value: mode)], ofItemAtPath: url.path(percentEncoded: false))
  }

  private func mode(of url: URL) throws -> UInt16 {
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path(percentEncoded: false))
    return (attributes[.posixPermissions] as? NSNumber)?.uint16Value ?? 0
  }

  private func exists(_ name: String, in directory: TemporaryDirectory) -> Bool {
    FileManager.default.fileExists(atPath: directory.url.appending(path: name).path(percentEncoded: false))
  }

  private func writePNG(width: Int, height: Int, to url: URL) throws {
    let context = CGContext(
      data: nil,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    let image = try #require(context?.makeImage())
    let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, nil)
    #expect(CGImageDestinationFinalize(destination))
  }
}
