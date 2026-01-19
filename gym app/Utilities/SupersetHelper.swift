//
//  SupersetHelper.swift
//  gym app
//
//  Shared utility for superset-related calculations
//  Eliminates duplication across SessionViewModel, SessionNavigator, Module
//

import Foundation

/// Protocol for items that can be part of a superset
protocol SupersetGroupable {
    var supersetGroupId: UUID? { get }
}

/// Shared utilities for working with supersets
enum SupersetHelper {

    // MARK: - Index-Based Queries

    /// Returns the indices of all items in a superset
    /// - Parameters:
    ///   - items: Collection of items that may be in supersets
    ///   - supersetId: The superset group ID to find
    /// - Returns: Array of indices where items belong to the given superset
    static func indices<T: SupersetGroupable>(in items: [T], for supersetId: UUID) -> [Int] {
        items.enumerated()
            .filter { $0.element.supersetGroupId == supersetId }
            .map { $0.offset }
    }

    /// Returns the position (0-based) of an item within its superset
    /// - Parameters:
    ///   - itemIndex: The index of the current item in the collection
    ///   - items: Collection of items
    ///   - supersetId: The superset group ID
    /// - Returns: Position within superset, or nil if not found
    static func position<T: SupersetGroupable>(of itemIndex: Int, in items: [T], for supersetId: UUID) -> Int? {
        let supersetIndices = indices(in: items, for: supersetId)
        return supersetIndices.firstIndex(of: itemIndex)
    }

    /// Returns the 1-based display position within a superset
    static func displayPosition<T: SupersetGroupable>(of itemIndex: Int, in items: [T], for supersetId: UUID) -> Int? {
        guard let pos = position(of: itemIndex, in: items, for: supersetId) else { return nil }
        return pos + 1
    }

    /// Checks if an item is the last in its superset
    static func isLastInSuperset<T: SupersetGroupable>(itemIndex: Int, in items: [T], for supersetId: UUID) -> Bool {
        let supersetIndices = indices(in: items, for: supersetId)
        guard let pos = supersetIndices.firstIndex(of: itemIndex) else { return false }
        return pos == supersetIndices.count - 1
    }

    // MARK: - Item-Based Queries

    /// Returns all items that share the same superset as the given item
    static func itemsInSuperset<T: SupersetGroupable>(of item: T, in items: [T]) -> [T]? {
        guard let supersetId = item.supersetGroupId else { return nil }
        return items.filter { $0.supersetGroupId == supersetId }
    }

    /// Returns the count of items in a superset
    static func supersetCount<T: SupersetGroupable>(for supersetId: UUID, in items: [T]) -> Int {
        items.filter { $0.supersetGroupId == supersetId }.count
    }

    // MARK: - Grouping

    /// Groups items by superset, maintaining original order.
    /// Items not in a superset are returned as single-item groups.
    /// - Parameter items: Collection of items to group
    /// - Returns: Array of groups, where each group is an array of items in the same superset (or single item)
    static func grouped<T: SupersetGroupable & Identifiable>(items: [T]) -> [[T]] where T.ID == UUID {
        var groups: [[T]] = []
        var processedIds: Set<UUID> = []

        for item in items {
            guard !processedIds.contains(item.id) else { continue }

            if let supersetId = item.supersetGroupId {
                // Find all items in this superset
                let supersetItems = items.filter { $0.supersetGroupId == supersetId }
                groups.append(supersetItems)
                supersetItems.forEach { processedIds.insert($0.id) }
            } else {
                // Single item (not in a superset)
                groups.append([item])
                processedIds.insert(item.id)
            }
        }

        return groups
    }

    // MARK: - Validation

    /// Returns superset IDs that have only one member (orphaned)
    static func orphanedSupersetIds<T: SupersetGroupable>(in items: [T]) -> Set<UUID> {
        var supersetCounts: [UUID: Int] = [:]

        for item in items {
            if let supersetId = item.supersetGroupId {
                supersetCounts[supersetId, default: 0] += 1
            }
        }

        return Set(supersetCounts.filter { $0.value < 2 }.keys)
    }
}

// MARK: - Protocol Conformances

extension ExerciseInstance: SupersetGroupable {}
extension SessionExercise: SupersetGroupable {}
