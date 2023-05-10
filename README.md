<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/guides/libraries/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-library-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/developing-packages).
-->

[Lumin](https://www.uselumin.co/) is hassle-free, privacy-focused analytics made and hosted in the EU. Use this SDK in your Flutter app.

## Features

- Automatic tracking of DAUs, WAUs, MAUs & YAUs
- Stats on OS & country of origin
- All without saving any personally identifiying information about your users
  - So full GDPR compliance out of the box
- Custom KPIs

## Getting started

Add the Lumin SDK to your dependencies:

```sh
dart pub add lumin_flutter
```

Then, intialize Lumin in your `main` function:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Lumin.init("<Your Lumin App Token>");

  runApp(const MyApp());
}
```

Finally, wrap your app in the `LuminLifecycleLogger` widget:

```dart
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return LuminLifecycleLogger(
      child: MaterialApp(
        // ...
      )
    );
  }
}
```

## Usage

If you want to send a custom event, use the `instance` attribute on `Lumin`:

```dart
Lumin.instance.trackCustomEvent("EVENT_NAME");
```

<!--
## Additional information

TODO: Tell users more about the package: where to find more information, how to
contribute to the package, how to file issues, what response they can expect
from the package authors, and more.
-->
