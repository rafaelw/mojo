part widgets;

const double _kDefaultAlpha = -5707.62;
const double _kDefaultBeta = 172.0;
const double _kDefaultGamma = 3.7;

double _positionAtTime(double t) {
  return kDefaultAlpha * math.exp(-kDefaultGamma * t) - kDefaultBeta * t - kDefaultAlpha;
}

double _velocityAtTime(double t) {
  return -kDefaultAlpha * kDefaultGamma * math.exp(-kDefaultGamma * t) - kDefaultBeta;
}

double _timeAtVelocity(double v) {
  return -math.log((v + kDefaultBeta) / (-kDefaultAlpha * kDefaultGamma)) / kDefaultGamma;
}

final double _kMaxVelocity = _velocityAtTime(0.0);
final double _kCurveDuration = _timeAtVelocity(0.0);

class FlingCurve {
  double _timeOffset;
  double _positionOffset;
  double _startTime;
  double _previousPosition;
  double _direction;

  FlingCurve(double velocity, double startTime) {
    double startingVelocity = math.min(_kMaxVelocity, velocity.abs());
    _timeOffset = _velocityAtTime(startingVelocity);
    _positionOffset = _positionAtTime(_timeOffset);
    _startTime = startTime / 1000.0;
    _previousPosition = 0.0;
    _direction = velocity.sign;
  }

  double update(double timeStamp) {
    double t = timeStamp / 1000.0 - _startTime + _timeOffset;
    if (t >= _kCurveDuration)
      return 0.0;
    double position = _positionAtTime(t) - _positionOffset;
    double positionDelta = position - _previousPosition;
    _previousPosition = position;
    return _direction * math.max(0.0, positionDelta);
  }
}
