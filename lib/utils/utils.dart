
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

num wpx(num i) {
  return ScreenUtil.getInstance().setWidth(i);
}
num wpx100() {
  return wpx(750);
}
num hpx(num i) {
  return ScreenUtil.getInstance().setHeight(i);
}
num hpx100() {
  return hpx(1334);
}

class HexColor extends Color {
  static int _getColorFromHex(String hexColor) {
    hexColor = hexColor.toUpperCase().replaceAll("#", "");
    if (hexColor.length == 6) {
      hexColor = "FF" + hexColor;
    }
    return int.parse(hexColor, radix: 16);
  }

  HexColor(final String hexColor) : super(_getColorFromHex(hexColor));
}

String printDuration(Duration duration) {
  String twoDigits(int n) {
    if (n >= 10) return "$n";
    return "0$n";
  }

  String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
  String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
  return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
}
