part of widgets;

class MenuItem extends Component {

  static Style _style = new Style('''
    display: flex;
    align-items: center;
    height: 48px;
    -webkit-user-select: none;'''
  );

  static Style _labelStyle = new Style('''
      font-family: 'Roboto Medium', 'Helvetica';
      color: #212121;
      padding: 0px 16px;
      flex: 1;'''
  );

  List<Node> children;

  MenuItem({ Object key, this.children }) : super(key: key);

  Node render() {
    return new Container(
      style: _style,
      children: [
        new Icon(
          size: 24
        ),
        new Container(
          style: _labelStyle,
          children: children
        )
      ]
    );
  }
}
