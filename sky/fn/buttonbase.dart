part of widgets;

abstract class ButtonBase extends Component {

  bool _highlight = false;

  ButtonBase({ Object key }) : super(key:key);

  void _handlePointerDown(sky.Event e) {
    setState(() {
      _highlight = true;
    });
  }
  void _handlePointerUp(sky.Event e) {
    setState(() {
      _highlight = false;
    });
  }
  void _handlePointerCancel(sky.Event e) {
    setState(() {
      _highlight = false;
    });
  }
}
