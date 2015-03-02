part of widgets;

const String kAssetBase = '/sky/assets/material-design-icons';

class Icon extends Component {

  static Style _style = new Style('''
    padding: 8px;
    margin: 0 4px;'''
  );

  int size;
  String type;
  sky.EventListener onClick;

  Icon({
    String key,
    this.size,
    this.type: '',
    this.onClick
  }) : super(key: key);

  Node render() {
    String category = '';
    String subtype = '';
    List<String> parts = type.split('/');
    if (parts.length == 2) {
      category = parts[0];
      subtype = parts[1];
    }

    return new Image(
      style: _style,
      onClick: onClick,
      width: size,
      height: size,
      src: '${kAssetBase}/${category}/2x_web/ic_${subtype}_${size}dp.png'
    );
  }
}
