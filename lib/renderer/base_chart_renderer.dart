import 'package:flutter/material.dart';

import '../flutter_k_chart.dart';

export '../chart_style.dart';

abstract class BaseChartRenderer<T> {
  double maxValue, minValue;
  late double scaleY;
  double topPadding;
  Rect chartRect;
  int fixedLength;
  Paint chartPaint = Paint()
    ..isAntiAlias = true
    ..filterQuality = FilterQuality.high
    ..strokeWidth = 1.0
    ..color = Colors.red;
  Paint gridPaint = Paint()
    ..isAntiAlias = true
    ..filterQuality = FilterQuality.high
    ..strokeWidth = 0.5
    ..color = Color(0xff4c5c74);

  BaseChartRenderer({
    required this.chartRect,
    required this.maxValue,
    required this.minValue,
    required this.topPadding,
    required this.fixedLength,
    required Color gridColor,
  }) {
    if (maxValue == minValue) {
      maxValue *= 1.5;
      minValue /= 2;
    }
    scaleY = chartRect.height / (maxValue - minValue);
    gridPaint.color = gridColor;
    // print("maxValue=====" + maxValue.toString() + "====minValue===" + minValue.toString() + "==scaleY==" + scaleY.toString());
  }

  double getY(double y) => (maxValue - y) * scaleY + chartRect.top;

  String format(double? n) {
    if (n == null || n.isNaN) {
      return "0.00";
    } else {
      return n.toStringAsFixed(fixedLength);
    }
  }

  void drawGrid(Canvas canvas, int gridRows, int gridColumns);

  // void drawText(Canvas canvas, T data, double x);

  void drawVerticalText(canvas, textStyle, int gridRows);

  // void drawChart(T lastPoint, T curPoint, double lastX, double curX, Size size,
  //     Canvas canvas);

  void drawChart(KLineEntity lastPoint, KLineEntity curPoint, double lastX,
      double curX, Size size, Canvas canvas);
  void drawText(Canvas canvas, KLineEntity data, double x);

  void drawLine(double? lastPrice, double? curPrice, Canvas canvas,
      double lastX, double curX, Color color) {
    if (lastPrice == null || curPrice == null) {
      return;
    }
    // 跳过无穷大
    if (!lastPrice.isFinite || !curPrice.isFinite) return;

    //("lasePrice==" + lastPrice.toString() + "==curPrice==" + curPrice.toString());
    double lastY = getY(lastPrice);
    double curY = getY(curPrice);

    // 在这里加一行检查
    if (!(lastX.isFinite && lastY.isFinite && curX.isFinite && curY.isFinite)) {
      // 表示出现了 NaN/Infinity，直接跳过这条线
      return;
    }
    //print("lastX-----==" + lastX.toString() + "==lastY==" + lastY.toString() + "==curX==" + curX.toString() + "==curY==" + curY.toString());
    canvas.drawLine(
        Offset(lastX, lastY), Offset(curX, curY), chartPaint..color = color);
  }

  TextStyle getTextStyle(Color color) {
    return TextStyle(fontSize: 10.0, color: color);
  }
}
