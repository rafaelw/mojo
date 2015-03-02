part of widgets;

class FrameGenerator {

  StreamController _controller;

  Stream<double> get onTick => _controller.stream;

  int _animationId = 0;
  bool _closed = false;

  FrameGenerator() {
    _controller = new StreamController(
      sync: true,
      onListen: _scheduleTick,
      onCancel: close);
  }

  void close() {
    if (_animationId != 0) {
      sky.window.cancelAnimationFrame(_animationId);
    }
    _animationId = 0;
    _closed = true;
  }

  void _scheduleTick() {
    assert(_animationId == 0);
    _animationId = sky.window.requestAnimationFrame(_tick);
  }

  void _tick(double timeStamp) {
    _animationId = 0;
    _controller.add(timeStamp);
    if (!_closed) {
      _scheduleTick();
    }
  }
}

typedef AnimationDone(AnimationGenerator);

class AnimationGenerator extends FrameGenerator {

  Stream<double> get onTick => _stream;
  final double duration;
  final double begin;
  final double end;
  final Curve curve;
  final AnimationDone onDone;
  Stream<double> _stream;

  AnimationGenerator(this.duration, {
    this.begin: 0.0,
    this.end: 1.0,
    this.curve: linear,
    this.onDone
  }):super() {
    double startTime = 0.0;
    _stream = super.onTick.map((timeStamp) {
      if (startTime == 0.0) {
        startTime = timeStamp;
      }

      double elapsedTime = timeStamp - startTime;
      return math.max(0.0, math.min(1.0, elapsedTime / duration));
    })
    .takeWhile((t) => t < 1.0)
    .map((t) => begin + (end - begin) * curve.transform(t));
  }
}

double _evaluateCubic(double a, double b, double m) {
  // TODO(abarth): Would Math.pow be faster?
  return 3 * a * (1 - m) * (1 - m) * m + 3 * b * (1 - m) * m * m + m * m * m;
}

const double _kCubicErrorBound = 0.001;

abstract class Curve {
  double transform(double t);
}

class Linear implements Curve {
  const Linear();

  double transform(double t) {
    return t;
  }
}

class Cubic implements Curve {
  final double a;
  final double b;
  final double c;
  final double d;

  const Cubic(this.a, this.b, this.c, this.d);

  double transform(double t) {
    double start = 0.0;
    double end = 1.0;
    while (true) {
      double midpoint = (start + end) / 2;
      double estimate = _evaluateCubic(a, c, midpoint);

      if ((t - estimate).abs() < _kCubicErrorBound)
        return _evaluateCubic(b, d, midpoint);

      if (estimate < t)
        start = midpoint;
      else
        end = midpoint;
    }
  }
}

const Linear linear = const Linear();
const Cubic ease = const Cubic(0.25, 0.1, 0.25, 1.0);
const Cubic easeIn = const Cubic(0.42, 0.0, 1.0, 1.0);
const Cubic easeOut = const Cubic(0.0, 0.0, 0.58, 1.0);
const Cubic easeInOut = const Cubic(0.42, 0.0, 0.58, 1.0);
