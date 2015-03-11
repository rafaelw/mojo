import '../../framework/components/bottom_drawer.dart';
import '../../framework/components/floating_action_button.dart';
import '../../framework/components/icon.dart';
import '../../framework/fn.dart';
import '../data/contacts.dart';
import 'contactlist.dart';
import 'dialer.dart';

class DialerApp extends App {

  Style _style = new Style('''
    display: flex;
    flex-direction: column;
    font-family: 'Roboto Regular', 'Helvetica';
    font-size: 16px;
    height: -webkit-fill-available;'''
  );

  Style _contactListStyle = new Style('flex: 1;');

  BottomDrawerAnimation _drawerAnimation = new BottomDrawerAnimation();
  NumberPadAnimation _numberAnimation = new NumberPadAnimation();

  void _openDialer(_) {
    _drawerAnimation.open(null);
    _numberAnimation.start();
  }

  DialerApp() {
    _drawerAnimation.onClosed = _numberAnimation.reset;
  }

  Node build() {
    var contactList = new ContactList(db: contactDB, style: _contactListStyle);

    var fab = new FloatingActionButton(
      content: new Icon (
        type: 'content/add_white', size: 24
      )
    )..events.listen('click', _openDialer);

    var drawer = new BottomDrawer(
      animation: _drawerAnimation,
      children: [ new Dialer(_numberAnimation) ]
    );

    return new Container(
      children: [
        new Container(
          styles: [_style],
          children: [ contactList ]
        ),
        fab, drawer,
      ]
    );
  }
}
