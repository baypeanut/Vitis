//
//  SocialView.swift
//  Vitis
//
//  Community feed: Global / Following, statements, Cheers & Comments.
//

import SwiftUI

struct SocialView: View {
    var body: some View {
        NavigationStack {
            FeedView()
        }
    }
}

#Preview {
    SocialView()
}
