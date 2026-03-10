//
//  WineLabelScanViewModel.swift
//  Vitis
//
//  State machine for the wine label scan flow.
//

import UIKit
import Observation

@MainActor
@Observable
final class WineLabelScanViewModel {

    enum Step {
        case camera
        case processing(UIImage)
        case result(LabelScanResult, Wine?)
        case rating(Wine)
        case notWine
        case error(String)
    }

    var step: Step = .camera

    // MARK: - Actions

    func processImage(_ image: UIImage) {
        step = .processing(image)
        Task {
            do {
                let scanResult = try await ClaudeVisionService.analyzeLabel(image: image)
                guard scanResult.isWine else {
                    step = .notWine
                    return
                }
                let wine: Wine?
                do {
                    wine = try await WineService.upsertFromScan(result: scanResult)
                } catch {
                    wine = nil
                }
                step = .result(scanResult, wine)
            } catch {
                step = .error(error.localizedDescription)
            }
        }
    }

    func proceedToRating(_ wine: Wine) {
        step = .rating(wine)
    }

    func reset() {
        step = .camera
    }
}
