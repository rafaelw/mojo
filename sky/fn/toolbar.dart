part of widgets;

class Toolbar extends Component {

  List<Node> children;

  static Style _style = new Style('''
    display: flex;
    align-items: center;
    height: 56px;
    z-index: 1;
    background-color: #3F51B5;
    color: white;'''
  );

  Toolbar({ String key, this.children }) : super(key:key);

  Node render() {
    return new Container(
      key: 'Toolbar',
      style: _style,
      children: children
    );
  }
}
