part of widgets;

const String kAssetBase = '/sky/assets/material-design-icons';

class Icon extends Component {

  int size;
  String type;
  sky.EventListener onClick;

  Icon({ String key, this.size, this.type, this.onClick }) : super(key:key);

  Node render() {
    List<String> parts = type.split('/');
    assert(parts.length == 2);
    String category = parts[0];
    String subtype = parts[1];

    return new Image(
      key: 'Icon',
      onClick: onClick,
      inlineStyle: 'height: ${size}px; width: ${size}px',
      src: ''${kAssetBase}/${category}/2x_web/ic_${subtype}_${size}dp.png''
    );
  }
}
