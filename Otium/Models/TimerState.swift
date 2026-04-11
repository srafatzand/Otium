// Otium/Models/TimerState.swift
import Foundation

enum TimerState: Equatable, Hashable {
    case idle
    case running
    case breakPending   // animating overlay in
    case breakActive    // overlay visible, break countdown running
    case extended       // 5-min extension countdown
}
