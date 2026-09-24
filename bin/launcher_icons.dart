import 'package:launcher_icons/src/cli.dart' as launcher_icons;

Future<void> main(final List<String> arguments) async {
  await launcher_icons.createIconsFromArguments(arguments);
}
