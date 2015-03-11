import '../../framework/components/fixed_height_scrollable.dart';
import '../../framework/components/material.dart';
import '../../framework/fn.dart';
import '../data/contacts.dart';

class LetterCircle extends Component {
  static final Style _style = new Style('''
    width: 32px;
    height: 32px;
    font-size: 22px;
    background-color: red;
    display: flex;
    justify-content: center;
    align-items: center;
    color: white;
    border-radius: 16px;'''
  );

  Node content;

  LetterCircle({ Object key, this.content }) : super(key: key);

  Node build() {
    return new Container(
      key: "Container",
      styles: [_style],
      children: [ content ]
    );
  }
}

class ContactItem extends Component {

  static Style _style = new Style('''
    display: flex;
    padding: 8px 0px 8px 20px;
    flex-direction: row;
    justify-content: left;
    align-items: center;'''
  );

  static Style _nameStyle = new Style('''
    padding-left: 16px;
  ''');

  Contact contact;

  ContactItem(Contact contact)
      : this.contact = contact,
        super(key: contact.id);

  Node build() {
    return new Container(
      styles: [_style],
      children: [
        new LetterCircle(
          content: new Text(contact.firstName[0])
        ),
        new Container(
          styles: [_nameStyle],
          children: [new Text("${contact.firstName} ${contact.lastName} ")]
        )
      ]
    );
  }
}

class ContactList extends FixedHeightScrollable {

  ContactDB db;

  ContactList({ ContactDB db, Style style })
      : this.db = db,
        super(minItem: 0, maxItem: db.contacts.length, style: style);

  List<Node> buildItems(int start, int count) {
    var items = [];
    for (var i = 0; i < count; i++) {
      items.add(new ContactItem(db.contacts[start + i]));
    }

    return items;
  }
}
