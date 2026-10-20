import AppKit
import QuartzCore
import SwoopCore

/// Glides windows to their new frames. Several windows can animate at once; a new target for a
/// window that's mid-flight starts from where it currently is, so rapid commands chain smoothly.
/// Apps that respond slowly to Accessibility calls skip straight to the end instead of stuttering.
final class FrameAnimator {
    private struct Job {
        let window: AXWindow
        let from: CGRect
        let to: CGRect
        let start: CFTimeInterval
        let duration: CFTimeInterval
        var current: CGRect
        var completions: [() -> Void]
    }

    private var jobs: [CGWindowID: Job] = [:]
    private var timer: Timer?

    func animate(_ window: AXWindow, to target: CGRect, duration: Double, completion: (() -> Void)? = nil) {
        let carried = jobs[window.id]?.completions ?? []
        let from = jobs[window.id]?.current ?? window.frame ?? target

        guard duration > 0.01, !from.approximatelyEquals(target, tolerance: 1) else {
            jobs[window.id] = nil
            window.setFrame(target)
            carried.forEach { $0() }
            completion?()
            return
        }

        jobs[window.id] = Job(window: window, from: from, to: target,
                              start: CACurrentMediaTime(), duration: duration,
                              current: from, completions: carried + (completion.map { [$0] } ?? []))
        if timer == nil {
            let t = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in self?.tick() }
            RunLoop.main.add(t, forMode: .common)
            timer = t
        }
        tick()
    }

    func cancelAll() {
        for job in jobs.values { job.window.setFrame(job.to) }
        jobs.removeAll()
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let now = CACurrentMediaTime()
        for (id, var job) in jobs {
            let progress = (now - job.start) / job.duration
            if progress >= 1 {
                finish(id)
                continue
            }
            let eased = CGFloat(easeOutCubic(progress))
            let next = job.from.interpolated(to: job.to, progress: eased).pixelAligned
            let sizeChanged = next.size != job.current.size
            let before = CACurrentMediaTime()
            job.window.setFrameStep(next, sizeChanged: sizeChanged)
            job.current = next
            jobs[id] = job
            // This app is too slow for smooth animation: jump to the end.
            if CACurrentMediaTime() - before > 0.03 { finish(id) }
        }
        if jobs.isEmpty {
            timer?.invalidate()
            timer = nil
        }
    }

    private func finish(_ id: CGWindowID) {
        guard let job = jobs.removeValue(forKey: id) else { return }
        job.window.setFrame(job.to)
        job.completions.forEach { $0() }
    }
}
