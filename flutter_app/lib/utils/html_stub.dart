// Stub file for non-web platforms
// This prevents dart:html import errors on Android/iOS

class FakeElement {
  set src(String value) {}
  set allow(String value) {}
  set allowFullscreen(bool value) {}
  void remove() {}
  dynamic get style => FakeStyle();
}

class FakeStyle {
  set width(String value) {}
  set height(String value) {}
  set border(String value) {}
  set pointerEvents(String value) {}
}

class FakeIFrameElement extends FakeElement {}

void registerViewFactory(String viewType, dynamic factory) {}

// File upload stub
class FileUploadInputElement {
  String? accept;
  void click() {}
  Stream<dynamic> get onChange => const Stream.empty();
  List<dynamic>? files;
}

class FileReader {
  void readAsText(dynamic file) {}
  Stream<dynamic> get onLoadEnd => const Stream.empty();
  dynamic result;
}
