import 'package:sky/framework/shell.dart' as shell;
import 'package:sky/framework/fn.dart';
import 'package:sky/services/contacts/contacts.mojom.dart';

class ContactsApp extends App {
  ContactsApp() {
    onDidMount(() {
      var net = new ContactsServiceProxy.unbound();
      shell.requestService(net);
      net.ptr.getContact().then((response) {
        setState(() {
          _name = response.contact.name;
        });
      });
    });
  }
  String _name = '';

  Node build() {
    return new Text(_name);
  }
}
