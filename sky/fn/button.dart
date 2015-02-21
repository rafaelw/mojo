part of widgets;

class Button extends Component {

  static Style _style = new Style('''
    display: inline-flex;
    border-radius: 4px;
    justify-content: center;
    align-items: center;
    border: 1px solid blue;
    -webkit-user-select: none;
    margin: 5px;'''
  );

  static Style _depressedStyle = new Style('''
    display: inline-flex;
    border-radius: 4px;
    justify-content: center;
    align-items: center;
    border: 1px solid blue;
    -webkit-user-select: none;
    margin: 5px;
    background-color: orange;'''
  );

  Node content;
  sky.EventListener onClick;

  bool _depressed = false;

  Button({ Object key, this.content, this.onClick }) : super(key:key);

  Node render() {
    return new Container(
      key: 'Button',
      style: _depressed ? _depressedStyle : _style,
      onClick: onClick,
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      children: [content]
    );
  }

  void _handlePointerDown(sky.Event e) {
    setState(() {
      _depressed = true;
    });
  }
  void _handlePointerUp(sky.Event e) {
    setState(() {
      _depressed = false;
    });
  }
  void _handlePointerCancel(sky.Event e) {
    setState(() {
      _depressed = false;
    });
  }
}
