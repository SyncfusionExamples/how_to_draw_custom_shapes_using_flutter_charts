import 'dart:math';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_core/theme.dart';

void main() {
  return runApp(_ChartAppWithCustomShape());
}

class _ChartAppWithCustomShape extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const _CustomShapePainter(),
    );
  }
}

enum Shapes { connectorLine, rectangle }

class _CustomShapePainter extends StatefulWidget {
  const _CustomShapePainter();

  @override
  _CustomShapePainterState createState() => _CustomShapePainterState();
}

class _CustomShapePainterState extends State<_CustomShapePainter> {
  final ValueNotifier<Shapes?> _selectedShape = ValueNotifier<Shapes?>(null);

  late List<_CandleStickData> _candleStickData;

  @override
  void initState() {
    _candleStickData = _candleStickSampleDataPoints();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final CrosshairBehaviorExt crosshairBehavior = CrosshairBehaviorExt();

    final List<void Function()?> buttonsOnPressedEvent = <void Function()?>[
      () => _selectedShape.value = Shapes.connectorLine,
      () => _selectedShape.value = Shapes.rectangle,
      () {
        crosshairBehavior.refreshDrawnShapes();
        _selectedShape.value = null;
      },
    ];

    final List<IconData> buttonIcons = <IconData>[
      Icons.linear_scale,
      Icons.rectangle,
      Icons.refresh,
    ];

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: <Widget>[
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: _selectedShape,
                builder: (BuildContext context, Shapes? selectedShape,
                    Widget? child) {
                  crosshairBehavior.selectedShape = selectedShape;
                  return SfCartesianChart(
                    crosshairBehavior: crosshairBehavior,
                    primaryXAxis: const DateTimeAxis(),
                    primaryYAxis: const NumericAxis(
                      interval: 10,
                    ),
                    series: [
                      CandleSeries<_CandleStickData, DateTime>(
                        dataSource: _candleStickData,
                        xValueMapper: (_CandleStickData data, int index) =>
                            data.x,
                        lowValueMapper: (_CandleStickData data, int index) =>
                            data.low,
                        highValueMapper: (_CandleStickData data, int index) =>
                            data.high,
                        openValueMapper: (_CandleStickData data, int index) =>
                            data.open,
                        closeValueMapper: (_CandleStickData data, int index) =>
                            data.close,
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            _ShapeButtons(
              selectedShape: _selectedShape,
              buttonIcons: buttonIcons,
              buttonsOnPressedEvent: buttonsOnPressedEvent,
            ),
          ],
        ),
      ),
    );
  }
}

class _ShapeButtons extends StatelessWidget {
  const _ShapeButtons({
    required this.selectedShape,
    required this.buttonIcons,
    required this.buttonsOnPressedEvent,
  });

  final ValueNotifier<Shapes?> selectedShape;

  final List<IconData> buttonIcons;
  final List<void Function()?> buttonsOnPressedEvent;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        buttonIcons.length,
        (int index) {
          return Padding(
            padding: const EdgeInsets.only(right: 10.0),
            child: FloatingActionButton.small(
              onPressed: buttonsOnPressedEvent[index],
              child: Icon(buttonIcons[index]),
            ),
          );
        },
      ),
    );
  }
}

// ignore: must_be_immutable
class CrosshairBehaviorExt extends CrosshairBehavior {
  final List<ShapeData> shapes = [];

  Shapes? selectedShape;
  ShapeData? _currentShapeData;

  Offset? startPosition;
  Offset? endPosition;

  @override
  bool get enable => true;

  void _drawShape(PaintingContext context, Paint paint, ShapeData shape) {
    switch (shape.shapeType) {
      case Shapes.connectorLine:
        return _drawConnectorLine(context, paint, shape);
      case Shapes.rectangle:
        return _drawRectangle(context, paint, shape);
      default:
        return;
    }
  }

  void _drawRectangle(PaintingContext context, Paint paint, ShapeData shape) {
    if (shape.endPosition != null) {
      final Rect rect =
          Rect.fromPoints(shape.startPosition, shape.endPosition!);
      context.canvas.drawRect(rect, paint);
    }
  }

  void _drawConnectorLine(
      PaintingContext context, Paint paint, ShapeData shape) {
    final Rect paintBounds = parentBox!.paintBounds;
    final double y = shape.startPosition.dy;
    final Offset start = Offset(paintBounds.left, y);
    final Offset end = Offset(paintBounds.right, y);
    context.canvas.drawLine(start, end, paint);
  }

  void refreshDrawnShapes() {
    shapes.clear();
    _currentShapeData = null;
  }

  bool _isWithinBounds(details) {
    final Offset currentPosition =
        parentBox!.globalToLocal(details.globalPosition);
    final Rect paintBounds = parentBox!.paintBounds;
    final double x = currentPosition.dx;
    final double y = currentPosition.dy;
    final double left = max(x, paintBounds.left);
    final double right = min(x, paintBounds.right);
    final double top = max(y, paintBounds.top);
    final double bottom = min(y, paintBounds.bottom);
    return (left > paintBounds.left &&
        right < paintBounds.right &&
        top > paintBounds.top &&
        bottom < paintBounds.bottom);
  }

  @override
  void handleTapDown(TapDownDetails details) {
    if (_isWithinBounds(details)) {
      startPosition = parentBox!.globalToLocal(details.globalPosition);
      _currentShapeData = ShapeData(selectedShape, startPosition!);
    }
  }

  @override
  void handleTapUp(TapUpDetails details) {
    if (_isWithinBounds(details)) {
      endPosition = null;
      if (_currentShapeData != null) {
        shapes.add(_currentShapeData!);
        _currentShapeData = null;
      }
      parentBox!.markNeedsPaint();
    }
  }

  @override
  void handleLongPressStart(LongPressStartDetails details) {
    if (_isWithinBounds(details)) {
      startPosition = parentBox!.globalToLocal(details.globalPosition);
      _currentShapeData = ShapeData(selectedShape, startPosition!);
    }
  }

  @override
  void handleLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (_isWithinBounds(details)) {
      endPosition = parentBox!.globalToLocal(details.globalPosition);
      if (_currentShapeData != null) {
        _currentShapeData!.endPosition = endPosition!;
      }
      parentBox!.markNeedsPaint();
    }
  }

  @override
  void handleLongPressEnd(LongPressEndDetails details) {
    if (_isWithinBounds(details)) {
      if (_currentShapeData != null) {
        shapes.add(_currentShapeData!);
        _currentShapeData = null;
      }
      parentBox!.markNeedsPaint();
    }
  }

  @override
  void onPaint(PaintingContext context, Offset offset,
      SfChartThemeData chartThemeData, ThemeData themeData) {
    final Paint paint = Paint()
      ..color = themeData.primaryColor.withOpacity(0.5)
      ..strokeWidth = 2;

    // Loops through all the previously drawn shapes and paints them.
    for (final ShapeData shape in shapes) {
      _drawShape(context, paint, shape);
    }

    // Checks if a shape was being drawn currently while dragging and paints it.
    if (_currentShapeData != null) {
      _drawShape(context, paint, _currentShapeData!);
    }
  }
}

class ShapeData {
  ShapeData(this.shapeType, this.startPosition, [this.endPosition]);

  final Shapes? shapeType;
  Offset startPosition;
  Offset? endPosition;
}

class _CandleStickData {
  _CandleStickData({
    required this.x,
    required this.open,
    required this.close,
    required this.high,
    required this.low,
  });

  final DateTime x;
  final double open;
  final double close;
  final double high;
  final double low;
}

List<_CandleStickData> _candleStickSampleDataPoints() {
  return <_CandleStickData>[
    _CandleStickData(
        x: DateTime(2016, 01, 11),
        open: 58.97,
        high: 61.19,
        low: 55.36,
        close: 57.13),
    _CandleStickData(
        x: DateTime(2016, 01, 18),
        open: 58.41,
        high: 61.46,
        low: 53.42,
        close: 61.42),
    _CandleStickData(
        x: DateTime(2016, 01, 25),
        open: 61.52,
        high: 61.53,
        low: 52.39,
        close: 57.34),
    _CandleStickData(
        x: DateTime(2016, 02),
        open: 56.47,
        high: 57.33,
        low: 53.69,
        close: 64.02),
    _CandleStickData(
        x: DateTime(2016, 02, 08),
        open: 53.13,
        high: 56.35,
        low: 52.59,
        close: 53.99),
    _CandleStickData(
        x: DateTime(2016, 02, 15),
        open: 55.02,
        high: 58.89,
        low: 54.61,
        close: 56.04),
    _CandleStickData(
        x: DateTime(2016, 02, 22),
        open: 56.31,
        high: 58.0237,
        low: 53.32,
        close: 56.91),
    _CandleStickData(
        x: DateTime(2016, 02, 29),
        open: 56.86,
        high: 63.75,
        low: 56.65,
        close: 63.01),
    _CandleStickData(
        x: DateTime(2016, 03, 07),
        open: 62.39,
        high: 62.83,
        low: 60.15,
        close: 62.26),
    _CandleStickData(
        x: DateTime(2016, 03, 14),
        open: 66.5,
        high: 66.5,
        low: 66.5,
        close: 66.5),
    _CandleStickData(
        x: DateTime(2016, 03, 21),
        open: 65.93,
        high: 67.65,
        low: 64.89,
        close: 65.67),
    _CandleStickData(
        x: DateTime(2016, 03, 28),
        open: 66,
        high: 71.42,
        low: 64.88,
        close: 69.99),
    _CandleStickData(
        x: DateTime(2016, 04, 04),
        open: 70.42,
        high: 72.19,
        low: 68.121,
        close: 68.66),
    _CandleStickData(
        x: DateTime(2016, 04, 11),
        open: 68.97,
        high: 72.39,
        low: 68.66,
        close: 69.85),
    _CandleStickData(
        x: DateTime(2016, 04, 18),
        open: 68.89,
        high: 68.95,
        low: 64.62,
        close: 65.68),
    _CandleStickData(
        x: DateTime(2016, 04, 25),
        open: 65,
        high: 65.65,
        low: 52.51,
        close: 53.74),
    _CandleStickData(
        x: DateTime(2016, 05, 02),
        open: 53.965,
        high: 55.9,
        low: 51.85,
        close: 52.72),
    _CandleStickData(
        x: DateTime(2016, 05, 09),
        open: 53,
        high: 53.77,
        low: 49.47,
        close: 50.52),
    _CandleStickData(
        x: DateTime(2016, 05, 16),
        open: 52.39,
        high: 55.43,
        low: 51.65,
        close: 55.22),
    _CandleStickData(
        x: DateTime(2016, 05, 23),
        open: 55.87,
        high: 60.73,
        low: 55.67,
        close: 60.35),
    _CandleStickData(
        x: DateTime(2016, 05, 30),
        open: 59.6,
        high: 60.4,
        low: 56.63,
        close: 57.92),
    _CandleStickData(
        x: DateTime(2016, 06, 06),
        open: 57.99,
        high: 61.89,
        low: 57.55,
        close: 58.83),
    _CandleStickData(
        x: DateTime(2016, 06, 13),
        open: 58.69,
        high: 59.12,
        low: 55.3,
        close: 55.33),
    _CandleStickData(
        x: DateTime(2016, 06, 20),
        open: 56,
        high: 56.89,
        low: 52.65,
        close: 53.4),
    _CandleStickData(
        x: DateTime(2016, 06, 27),
        open: 53,
        high: 56.465,
        low: 51.5,
        close: 55.89),
    _CandleStickData(
        x: DateTime(2016, 07, 04),
        open: 55.39,
        high: 56.89,
        low: 54.37,
        close: 56.68),
    _CandleStickData(
        x: DateTime(2016, 07, 11),
        open: 56.75,
        high: 59.3,
        low: 56.73,
        close: 58.78),
    _CandleStickData(
        x: DateTime(2016, 07, 18),
        open: 58.7,
        high: 61,
        low: 58.31,
        close: 58.66),
    _CandleStickData(
        x: DateTime(2016, 07, 25),
        open: 58.25,
        high: 64.55,
        low: 56.42,
        close: 64.21),
    _CandleStickData(
        x: DateTime(2016, 08), open: 64.41, high: 67.65, low: 64, close: 67.48),
    _CandleStickData(
        x: DateTime(2016, 08, 08),
        open: 67.52,
        high: 68.94,
        low: 67.16,
        close: 68.18),
    _CandleStickData(
        x: DateTime(2016, 08, 15),
        open: 68.14,
        high: 70.23,
        low: 68.08,
        close: 69.36),
    _CandleStickData(
        x: DateTime(2016, 08, 22),
        open: 68.86,
        high: 69.32,
        low: 66.31,
        close: 66.94),
    _CandleStickData(
        x: DateTime(2016, 08, 29),
        open: 69.74,
        high: 69.74,
        low: 69.74,
        close: 69.74),
    _CandleStickData(
        x: DateTime(2016, 09, 05),
        open: 67.9,
        high: 68.76,
        low: 63.13,
        close: 63.13),
    _CandleStickData(
        x: DateTime(2016, 09, 12),
        open: 62.65,
        high: 76.13,
        low: 62.53,
        close: 74.92),
    _CandleStickData(
        x: DateTime(2016, 09, 19),
        open: 75.19,
        high: 76.18,
        low: 71.55,
        close: 72.71),
    _CandleStickData(
        x: DateTime(2016, 09, 26),
        open: 71.64,
        high: 74.64,
        low: 71.55,
        close: 73.05),
  ];
}
