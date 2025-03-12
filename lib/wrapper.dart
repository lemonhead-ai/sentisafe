import 'package:SentiSafe/user_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';

import 'app.dart';
import 'models/the_user.dart';
import 'screens/authentication/authenticate.dart';

class Wrapper extends StatelessWidget {
  final List<CameraDescription> cameras;

  const Wrapper({
    Key? key,
    required this.cameras,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<TheUser?>(context);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: user == null
          ? const Authenticate()
          : UserModeSelectionScreen(), // Start with mode selection after authentication
    );
  }
}