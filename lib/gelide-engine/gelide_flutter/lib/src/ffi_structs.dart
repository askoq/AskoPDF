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
