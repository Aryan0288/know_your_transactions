import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CustomNavigation {
  CustomNavigation._();

  static dynamic to(BuildContext context, Widget navigation) {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => navigation),
    );
  }
}
