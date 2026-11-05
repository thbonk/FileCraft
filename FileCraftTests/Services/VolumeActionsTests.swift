/*
 * VolumeActionsTests.swift
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

import Foundation
import Testing
@testable import FileCraft

/// Ejecting needs a real volume, so only the error mapping is tested.
internal struct VolumeActionsTests {

  // MARK: - Tests

  @Test
  internal func `A volume in use is recognized, also inside wrapping errors`() {
    let busy = NSError(domain: NSOSStatusErrorDomain, code: -47)
    let posixBusy = NSError(domain: NSPOSIXErrorDomain, code: Int(EBUSY))
    let wrapped = NSError(domain: NSCocoaErrorDomain, code: 4, userInfo: [NSUnderlyingErrorKey: busy])

    #expect(VolumeActions.isBusy(busy))
    #expect(VolumeActions.isBusy(posixBusy))
    #expect(VolumeActions.isBusy(wrapped))
  }

  @Test
  internal func `Other failures are not taken for a busy volume`() {
    let notFound = NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError)
    let permission = NSError(domain: NSPOSIXErrorDomain, code: Int(EPERM))

    #expect(VolumeActions.isBusy(notFound) == false)
    #expect(VolumeActions.isBusy(permission) == false)
  }
}
