part of '../gelide.dart';

final class _GelideBitmapDataNative extends Struct {
  external Pointer<Uint8> data;
  @Uint32()
  external int len;
  @Uint32()
  external int width;
  @Uint32()
  external int height;
}

final class _GelidePageInfoNative extends Struct {
  @Float()
  external double width;
  @Float()
  external double height;
  @Int32()
  external int rotation;
}

final class _GelidePageInfosNative extends Struct {
  external Pointer<_GelidePageInfoNative> infos;
  @Uint32()
  external int count;
}

final class _GelideRectNative extends Struct {
  @Float()
  external double left;
  @Float()
  external double top;
  @Float()
  external double right;
  @Float()
  external double bottom;
}

final class _GelideSearchResultNative extends Struct {
  external Pointer<Utf8> text;
  @Uint32()
  external int startIndex;
  @Uint32()
  external int endIndex;
  external Pointer<_GelideRectNative> rects;
  @Uint32()
  external int rectCount;
}

final class _GelideSearchResultsNative extends Struct {
  external Pointer<_GelideSearchResultNative> results;
  @Uint32()
  external int count;
}
