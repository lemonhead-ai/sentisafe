import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/the_user.dart';


class UserList extends StatefulWidget {
  const UserList({ Key? key }) : super(key: key);

  @override
  _UserListState createState() => _UserListState();
}

class _UserListState extends State<UserList> {
  @override
  Widget build(BuildContext context) {

    final users = Provider.of<List<TheUser>?>(context);
    // print(brews.docs);
    if (users != null) {
      // for (var doc in users.docs) {
      //   print('print #1:');
      //   print(doc.data());
      // }
    }

    return Container(
      
    );
  }
}