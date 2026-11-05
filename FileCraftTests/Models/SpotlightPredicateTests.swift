/*
 * SpotlightPredicateTests.swift
 * FileCraftTests
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
import Testing
@testable import FileCraft

internal struct SpotlightPredicateTests {

  @Test
  internal func `The search text looks in file and display names`() {
    let format = SpotlightPredicate.predicate(for: SearchParameters(scope: .thisMac, text: "invoice")).predicateFormat

    #expect(format.contains("kMDItemFSName LIKE[cd] \"*invoice*\""))
    #expect(format.contains("kMDItemDisplayName LIKE[cd] \"*invoice*\""))
  }

  @Test
  internal func `Criteria become Spotlight attributes`() {
    let parameters = SearchParameters(
      scope: .thisMac,
      criteria: [
        SearchCriterion(attribute: .kind, kind: .image),
        SearchCriterion(attribute: .size, sizeComparison: .greaterThan, sizeValue: 5, sizeUnit: .megabytes),
        SearchCriterion(attribute: .contents, text: "Rechnung"),
        SearchCriterion(attribute: .pathExtension, text: "pdf"),
      ])
    let format = SpotlightPredicate.predicate(for: parameters).predicateFormat

    #expect(format.contains("kMDItemContentTypeTree == \"public.image\""))
    #expect(format.contains("kMDItemFSSize > 5000000"))
    #expect(format.contains("kMDItemTextContent LIKE[cd] \"*Rechnung*\""))
    #expect(format.contains("kMDItemFSName LIKE[c] \"*.pdf\""))
  }

  @Test
  internal func `Regular expressions are left to the matcher`() {
    let parameters = SearchParameters(
      scope: .thisMac, criteria: [SearchCriterion(attribute: .name, nameOperator: .matchesRegularExpression, text: "^a")])

    #expect(SpotlightPredicate.predicate(for: parameters).predicateFormat == "kMDItemFSName LIKE \"*\"")
  }

  @Test
  internal func `Wildcard characters in the text are escaped`() {
    #expect(SpotlightPredicate.escapedForLike("a*b?c") == "a\\*b\\?c")
  }
}
