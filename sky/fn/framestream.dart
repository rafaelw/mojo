part of widgets;

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

class FrameStream {

  Stream<double> create() {
    bool valid = true;
    int animationId = 0;

    void scheduleTick() {
      assert(valid);
      assert(animationId == 0);
      animationId = sky.window.requestAnimationFrame(tick);
    }

    void tick(double timeStamp) {
      animationId = 0;
      controller.add(timeStamp);
      scheduleTick();
    }

    void stop() {
      if (animationId != 0) {
        sky.window.cancelAnimationFrame(animationId);
      }
      animationId = 0;
      valid = false;
    }

    void invalid() {
      stop();
      assert(false);
    }

    StreamController controller = new StreamController(
      sync: true,
      onListen: scheduleTick,
      onCancel: stop
      onPause: invalid,
      onResume: invalid
    );

    return controller.stream;
  }

  Stream<double> ofDuration(double duration) {
    double startTime = 0.0;
    return create().takeWhile((timeStamp) {
      if (startTime = 0.0) {
        startTime = timeStamp;
      }

      double elapsedTime = timeStamp - startTime;
      return math.max(0.0, math.min(1.0, elapsedTime / duration)) < 1.0;
    });
  }

  Stream<double> forAnimation({
      double begin: 0.0,
      double end: 0.0,
      Curve curve: linear,
      double duration: 0.0}) {

    return ofDuration(duration)
        .map((t) => begin + (end - begin) * curve.transform(t));
  }
}

class AnimationStream extends Stream<double> {
  Stream<String> _source;
  StreamSubscription<String> _subscription;
  StreamController<String> _controller;
  int _lineCount = 0;
  String _remainder = '';

  AnimationStream(Stream<String> source) : _source = source {
    bool valid = true;
    int animationId = 0;

    void scheduleTick() {
      assert(valid);
      assert(animationId == 0);
      animationId = sky.window.requestAnimationFrame(tick);
    }

    void tick(double timeStamp) {
      animationId = 0;
      controller.add(timeStamp);
      scheduleTick();
    }

    void stop() {
      if (animationId != 0) {
        sky.window.cancelAnimationFrame(animationId);
      }
      animationId = 0;
      valid = false;
    }

    void invalid() {
      stop();
      assert(false);
    }

    StreamController controller = new StreamController(
      sync: true,
      onListen: scheduleTick,
      onCancel: stop
      onPause: invalid,
      onResume: invalid
    );

    return controller.stream;


    _controller = new StreamController<String>(
      onListen: _onListen,
      onPause: _onPause,
      onResume: _onResume,
      onCancel: _onCancel);
  }

  int get lineCount => _lineCount;

  StreamSubscription<String> listen(void onData(String line),
                                    { void onError(Error error),
                                      void onDone(),
                                      bool cancelOnError }) {
    return _controller.stream.listen(onData,
                                     onError: onError,
                                     onDone: onDone,
                                     cancelOnError: cancelOnError);
  }

  void _onListen() {
    _subscription = _source.listen(_onData,
                                   onError: _controller.addError,
                                   onDone: _onDone);
  }

  void _onCancel() {
    _subscription.cancel();
    _subscription = null;
  }

  void _onPause() {
    _subscription.pause();
  }

  void _onResume() {
    _subscription.resume();
  }

  void _onData(String input) {
    List<String> splits = input.split('\n');
    splits[0] = _remainder + splits[0];
    _remainder = splits.removeLast();
    _lineCount += splits.length;
    splits.forEach(_controller.add);
  }

  void _onDone() {
    if (!_remainder.isEmpty) _controller.add(_remainder);
    _controller.close();
  }
}
