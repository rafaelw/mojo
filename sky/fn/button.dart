import 'fn.dart';
import 'dart:sky' as sky;

var style = new Style('''
  display: inline-flex;
  border-radius: 4px;
  justify-content: center;
  align-items: center;
  border: 1px solid blue;
  -webkit-user-select: none;
  margin: 5px;
''');

var depressedStyle = new Style('''
  display: inline-flex;
  border-radius: 4px;
  justify-content: center;
  align-items: center;
  border: 1px solid blue;
  -webkit-user-select: none;
  margin: 5px;
  background-color: orange;
''');

class Button extends Component {
  // Configuration
  Node content;
  sky.EventListener onClick;

  // Private
  bool _depressed = false;

  Button({ Object key, this.content, this.onClick }) : super(key:key);

  Node render() {
    return new Container(
      children: [content],
      style: _depressed ? depressedStyle : style,
      onClick: handleClick
    );
  }

  void handleClick(sky.Event e) {

    setState(() { _depressed = !_depressed; });
    onClick(e);
  }
}
