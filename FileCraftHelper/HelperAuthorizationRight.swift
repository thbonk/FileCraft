/*
 * HelperAuthorizationRight.swift
 * FileCraftHelper
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

import Foundation
import os
import Security

/// The authorization right of the helper (design decision D11): "authenticate as admin" with a 300-second
/// timeout. The helper defines it when it first starts and checks it for every privileged request.
internal enum HelperAuthorizationRight {

  // MARK: - Defining

  /// Defines the right in the authorization database, unless it exists.
  internal static func defineIfNeeded(logger: Logger) {
    guard AuthorizationRightGet(HelperIdentity.rightName, nil) != errAuthorizationSuccess else {
      return
    }
    var authorization: AuthorizationRef?
    guard AuthorizationCreate(nil, nil, [], &authorization) == errAuthorizationSuccess, let authorization else {
      logger.error("Creating an authorization to define the right failed")
      return
    }
    defer {
      AuthorizationFree(authorization, [])
    }
    let definition: [String: Any] = [
      "class": "user",
      "group": "admin",
      "authenticate-user": true,
      "timeout": HelperIdentity.rightTimeout,
      "shared": false,
      "version": 1,
      "comment": "Lets FileCraft change protected files through its privileged helper.",
    ]
    let status = AuthorizationRightSet(
      authorization, HelperIdentity.rightName, definition as CFDictionary,
      "FileCraft wants to make changes to protected files." as CFString, nil, nil)
    if status == errAuthorizationSuccess {
      logger.info("Defined the authorization right")
    } else {
      logger.error("Defining the authorization right failed with status \(status, privacy: .public)")
    }
  }

  // MARK: - Checking

  /// Whether `externalForm` grants the right now, without asking the user.
  internal static func isAuthorized(_ externalForm: Data?) -> Bool {
    guard let externalForm, externalForm.count == Int(kAuthorizationExternalFormLength) else {
      return false
    }
    var form = AuthorizationExternalForm()
    _ = withUnsafeMutableBytes(of: &form.bytes) { buffer in
      externalForm.copyBytes(to: buffer)
    }
    var authorization: AuthorizationRef?
    guard AuthorizationCreateFromExternalForm(&form, &authorization) == errAuthorizationSuccess, let authorization else {
      return false
    }
    defer {
      AuthorizationFree(authorization, [])
    }
    return HelperIdentity.rightName.withCString { name in
      var item = AuthorizationItem(name: name, valueLength: 0, value: nil, flags: 0)
      return withUnsafeMutablePointer(to: &item) { pointer in
        var rights = AuthorizationRights(count: 1, items: pointer)
        return AuthorizationCopyRights(authorization, &rights, nil, [.extendRights], nil) == errAuthorizationSuccess
      }
    }
  }
}
