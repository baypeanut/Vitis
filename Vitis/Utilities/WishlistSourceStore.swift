//
//  WishlistSourceStore.swift
//  Pari
//
//  Constants for trust hint: window size and threshold.
//

import Foundation

enum WishlistSourceStore {
    /// Number of recent wishlist sources to consider for trust hint.
    static let windowSize = 20
    /// Minimum saves from same user to show "You often save wines from X".
    static let threshold = 3
}
