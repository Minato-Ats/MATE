/// A trivial, injectable source of "now".
///
/// Exists solely so time-dependent logic (Phase 6.6's serious-mode
/// escalation, in particular the 1-hour reset window) can be tested with
/// fixed instants instead of a real wall-clock wait. Production code always
/// uses [Clock.system]; tests construct a [Clock.fixed] (optionally
/// advancing it) instead.
abstract class Clock {
  const Clock();

  DateTime now();

  static const Clock system = _SystemClock();

  factory Clock.fixed(DateTime initial) = _FixedClock;
}

class _SystemClock extends Clock {
  const _SystemClock();

  @override
  DateTime now() => DateTime.now();
}

class _FixedClock extends Clock {
  _FixedClock(this._now);

  DateTime _now;

  @override
  DateTime now() => _now;

  void advance(Duration by) => _now = _now.add(by);

  void set(DateTime value) => _now = value;
}
