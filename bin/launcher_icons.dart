import 'package:launcher_icons/src/cli.dart' as launcher_icons;
import 'package:launcher_icons/src/core/constants.dart';

void main(List<String> arguments) {
  print(introMessage());
  launcher_icons.createIconsFromArguments(arguments);
}
