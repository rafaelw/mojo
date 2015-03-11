import '../../framework/animation/curves.dart';
import '../../framework/animation/generator.dart';
import '../../framework/components/menu_divider.dart';
import '../../framework/components/material.dart';
import '../../framework/fn.dart';
import 'dart:collection';

const double _kOffset = 60.0;
const double _kDuration = 45.0;
const double _kDurationStagger = 25.0;

class NumberPadAnimation {
  List<Animation> onValueChanged = [];

  NumberPadAnimation() {
    var labels = Dialer.numberLabels;
    for (var label in labels) {
      onValueChanged.add(new Animation()..value = _kOffset);
    }
  }

  void start() {
    var count = 0;
    double nextDelay = 0.0;
    for (var i = 0; i < onValueChanged.length; i++) {
      var animation = onValueChanged[i];
      animation.animateTo(0.0, _kDuration, initialDelay: nextDelay,
          curve: easeIn);
      nextDelay += _kDuration - _kDurationStagger;
    }
  }

  void reset() {
    onValueChanged.forEach((animation) {
      animation.value = _kOffset;
    });
  }
}

class NumberButton extends Component {
  String label;
  Function onTap;
  Animation animation;
  double _offset = 0.0;

  Style _style = new Style('''
    background-color: tomato;
    color: white;
    height: 50px;
    width: 40px;
    text-align: center;
    font-family: 'Roboto Regular', 'Helvetica';
    margin: 10px;
    line-height: 50px;
    border-radius: 8px;
    font-size: 40px;'''
  );

  NumberButton(String label, this.onTap, this.animation) : super(key: label) {
    this.label = label;
  }

  void didMount() {
    this.animation.onValueChanged.listen((value) {
      setState(() {
        _offset = value;
      });
    });
  }

  Node build() {
    return new Container(
      styles: [_style],
      inlineStyle: "transform: translateY(${_offset}px)",
      children: [new Text(this.label)]
    )..events.listen('gesturetap', (_) { onTap(this.label); });
  }
}

class Dialer extends Component {
  String _dialedNumber = '';

  static final List<String> numberLabels = [
    '1', '2', '3',
    '4', '5', '6',
    '7', '8', '9',
    '*', '0', '#'
  ];

  Style _style = new Style('''
    display: flex;
    background-color: white;
    flex-direction: column;
    justify-content: space-around;
    padding-bottom: 80px;
  ''');

  Style _rowStyle = new Style('''
    display: flex;
    flex-direction: row;
    justify-content: space-around;
  ''');


  Style _entryStyle = new Style('''
    height: 60px;
  ''');

  NumberPadAnimation animation;

  Dialer(this.animation): super();

  void _addNumber(String number) {
    setState(() {
      _dialedNumber += number;
    });
  }

  Node build() {
    List<Node> rows = [];

    Container makeRow(int start) {
      var index = (start - 1) * 3;
      var children = [];
      var labels = [];
      for (var i = 0; i < 3; i++) {
        var label = numberLabels[index + i];
        var anim = animation.onValueChanged[index + i];
        labels.add(label);
        children.add(new NumberButton(label, _addNumber, anim));
      }

      return new Container(
        key: labels.join('-'),
        styles: [_rowStyle],
        children: children
      );
    }

    return new Material(
      styles: [_style],
      children: [
        new MenuDivider(key: 'Divider1'),
        new Container(
          key: 'NumberEntry',
          styles: [_entryStyle],
          children: [ new Text(_dialedNumber) ]
        ),
        new MenuDivider(key: 'Divider2'),
        makeRow(1),
        makeRow(2),
        makeRow(3),
        makeRow(4)
      ]
    );
  }
}
