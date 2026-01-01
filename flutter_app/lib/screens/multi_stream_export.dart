// Platform-conditional export for MultiStreamScreen
// Web uses original dart:html version, Mobile uses WebView version

export 'multi_stream_screen_mobile.dart'
    if (dart.library.html) 'multi_stream_screen.dart';
