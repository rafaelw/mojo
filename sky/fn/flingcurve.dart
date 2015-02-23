part of widgets;

const double kDefaultAlpha = -5707.62;
const int kDefaultBeta = 172;
const double kDefaultGamma = 3.7;

double _positionAtTime(double t) {
  return kDefaultAlpha * Math.exp(-kDefaultGamma * t) - kDefaultBeta * t - kDefaultAlpha;
}

function velocityAtTime(t) {
  return -kDefaultAlpha * kDefaultGamma * Math.exp(-kDefaultGamma * t) - kDefaultBeta;
}

function timeAtVelocity(v) {
  return -Math.log((v + kDefaultBeta) / (-kDefaultAlpha * kDefaultGamma)) / kDefaultGamma;
}

var kMaxVelocity = velocityAtTime(0);
var kCurveDuration = timeAtVelocity(0);

class FlingCurve {
  int _velocity;
  int startTime;

  FlingCurve(velocity, startTime) {
    var startingVelocity = Math.min(kMaxVelocity, Math.abs(velocity));
    this.timeOffset_ = timeAtVelocity(startingVelocity);
    this.positionOffset_ = _positionAtTime(this.timeOffset_);
    this.startTime_ = startTime / 1000;
    this.previousPosition_ = 0;
    this.direction_ = Math.sign(velocity);
    Object.preventExtensions(this);
  }

  update(timeStamp) {
    var t = timeStamp / 1000 - this.startTime_ + this.timeOffset_;
    if (t >= kCurveDuration)
      return 0;
    var position = _positionAtTime(t) - this.positionOffset_;
    var positionDelta = position - this.previousPosition_;
    this.previousPosition_ = position;
    return this.direction_ * Math.max(0, positionDelta);
  }
}

