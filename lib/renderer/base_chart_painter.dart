import 'dart:math';

import 'package:flutter/material.dart'
    show Color, TextStyle, Rect, Canvas, Size, CustomPainter;
import 'package:k_chart_multiple/flutter_k_chart.dart';

export 'package:flutter/material.dart'
    show Color, required, TextStyle, Rect, Canvas, Size, CustomPainter;

abstract class BaseChartPainter extends CustomPainter {
  static double maxScrollX = 0.0;
  List<KLineEntity>? datas;
  MainState mainState;
  bool isShowMainState;
  // SecondaryState secondaryState;
  final List<SecondaryState> secondaryStates; // 替换原有单一字段

  bool volHidden;
  bool isTapShowInfoDialog;
  double scaleX = 1.0, scrollX = 0.0, selectX;
  bool isLongPress = false;
  bool isOnTap;
  bool isLine;

  //3块区域大小与位置
  late Rect mMainRect;
  Rect? mVolRect, mSecondaryRect;
  late double mDisplayHeight, mWidth;
  double mTopPadding = 30.0, mBottomPadding = 20.0, mChildPadding = 12.0;
  int mGridRows = 4, mGridColumns = 4;
  int mStartIndex = 0, mStopIndex = 0;
  double mMainMaxValue = double.minPositive, mMainMinValue = double.maxFinite;
  double mVolMaxValue = double.minPositive, mVolMinValue = double.maxFinite;
  // double mSecondaryMaxValue = double.minPositive,
  //     mSecondaryMinValue = double.maxFinite;

  // 用一个 Map<SecondaryState, double> 来存取相应的max/min
  late Map<SecondaryState, double> mSecondaryMaxMap;
  late Map<SecondaryState, double> mSecondaryMinMap;

  double mTranslateX = double.minPositive;
  int mMainMaxIndex = 0, mMainMinIndex = 0;
  double mMainHighMaxValue = double.minPositive,
      mMainLowMinValue = double.maxFinite;
  int mItemCount = 0;
  double mDataLen = 0.0; //数据占屏幕总长度
  final ChartStyle chartStyle;
  late double mPointWidth;
  List<String> mFormats = [yyyy, '-', mm, '-', dd, ' ', HH, ':', nn]; //格式化时间

  BaseChartPainter(
    this.chartStyle, {
    this.datas,
    required this.scaleX,
    required this.scrollX,
    required this.isLongPress,
    required this.selectX,
    this.isOnTap = false,
    this.isShowMainState = true,
    this.mainState = MainState.MA,
    this.volHidden = false,
    this.isTapShowInfoDialog = false,
    // this.secondaryState = SecondaryState.MACD,
    this.secondaryStates = const [SecondaryState.MACD], // 初始化为默认值

    this.isLine = false,
  }) {
    mItemCount = datas?.length ?? 0;
    mPointWidth = this.chartStyle.pointWidth;
    mTopPadding = this.chartStyle.topPadding;
    mBottomPadding = this.chartStyle.bottomPadding;
    mChildPadding = this.chartStyle.childPadding;
    mGridRows = this.chartStyle.gridRows;
    mGridColumns = this.chartStyle.gridColumns;
    mDataLen = mItemCount * mPointWidth;
    // 针对每种 secondaryState 初始化默认的 max/min
    mSecondaryMaxMap = {};
    mSecondaryMinMap = {};
    for (final st in secondaryStates) {
      // mSecondaryMaxMap[st] = double.minPositive;//导致TRIX线无效
      // mSecondaryMinMap[st] = double.maxFinite;
      mSecondaryMaxMap[st] = -double.infinity; // 或 -double.maxFinite
      mSecondaryMinMap[st] = double.infinity;
    }
    initFormats();
  }

  void initFormats() {
    if (this.chartStyle.dateTimeFormat != null) {
      mFormats = this.chartStyle.dateTimeFormat!;
      return;
    }

    if (mItemCount < 2) {
      mFormats = [yyyy, '-', mm, '-', dd, ' ', HH, ':', nn];
      return;
    }

    int firstTime = datas!.first.time ?? 0;
    int secondTime = datas![1].time ?? 0;
    int time = secondTime - firstTime;
    time ~/= 1000;
    //月线
    if (time >= 24 * 60 * 60 * 28)
      mFormats = [yy, '-', mm];
    //日线等
    else if (time >= 24 * 60 * 60)
      mFormats = [yy, '-', mm, '-', dd];
    //小时线等
    else
      mFormats = [mm, '-', dd, ' ', HH, ':', nn];
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Rect.fromLTRB(0, 0, size.width, size.height));
    mDisplayHeight = size.height - mTopPadding - mBottomPadding;
    mWidth = size.width;
    initRect(size);
    calculateValue();
    initChartRenderer();

    canvas.save();
    canvas.scale(1, 1);
    drawBg(canvas, size);
    drawGrid(canvas);
    if (datas != null && datas!.isNotEmpty) {
      drawChart(canvas, size);
      drawVerticalText(canvas);
      drawDate(canvas, size);

      drawText(canvas, datas!.last, 5);
      drawMaxAndMin(canvas);
      drawNowPrice(canvas);

      if (isLongPress == true || (isTapShowInfoDialog && isOnTap)) {
        drawCrossLineText(canvas, size);
      }
    }
    canvas.restore();
  }

  void initChartRenderer();

  //画背景
  void drawBg(Canvas canvas, Size size);

  //画网格
  void drawGrid(canvas);

  //画图表
  void drawChart(Canvas canvas, Size size);

  //画右边值
  void drawVerticalText(canvas);

  //画时间
  void drawDate(Canvas canvas, Size size);

  //画值
  void drawText(Canvas canvas, KLineEntity data, double x);

  //画最大最小值
  void drawMaxAndMin(Canvas canvas);

  //画当前价格
  void drawNowPrice(Canvas canvas);

  //画交叉线
  void drawCrossLine(Canvas canvas, Size size);

  //交叉线值
  void drawCrossLineText(Canvas canvas, Size size);

  void initRect(Size size) {
    double volHeight = volHidden != true ? mDisplayHeight * 0.2 : 0;
    double secondaryHeight =
        secondaryStates.isNotEmpty ? mDisplayHeight * 0.2 : 0;

    // 主图表高度计算
    double mainHeight =
        mDisplayHeight - volHeight - (secondaryHeight * secondaryStates.length);

    // 主图表区域
    mMainRect = Rect.fromLTRB(0, mTopPadding, mWidth, mTopPadding + mainHeight);

    // 成交量图表区域
    if (volHidden != true) {
      mVolRect = Rect.fromLTRB(0, mMainRect.bottom + mChildPadding, mWidth,
          mMainRect.bottom + volHeight);
    }

    // 副图区域
    if (secondaryStates.isNotEmpty) {
      mSecondaryRect = Rect.fromLTRB(
          0,
          mVolRect?.bottom ?? mMainRect.bottom + mChildPadding,
          mWidth,
          (mVolRect?.bottom ?? mMainRect.bottom) + secondaryHeight);
    }

    // 添加日志
    print('[initRect] Main Rect: $mMainRect');
    print('[initRect] Vol Rect: $mVolRect');
    print('[initRect] Secondary Rect: $mSecondaryRect');
  }

  /// 计算 Percentage Price Oscillator (PPO)
  /// [fastPeriod]   PPO 快周期，常见默认 12
  /// [slowPeriod]   PPO 慢周期，常见默认 26
  /// [signalPeriod] PPO 信号线周期，常见默认 9
  void _computePPO(List<KLineEntity> data,
      {int fastPeriod = 12, int slowPeriod = 26, int signalPeriod = 9}) {
    if (data.isEmpty) return;

    final length = data.length;
    // Step1: 先计算快/慢两条 EMA
    List<double> emaFast = List.filled(length, 0);
    List<double> emaSlow = List.filled(length, 0);

    double alphaFast = 2.0 / (fastPeriod + 1);
    double alphaSlow = 2.0 / (slowPeriod + 1);

    // 初始化
    emaFast[0] = data[0].close;
    emaSlow[0] = data[0].close;
    data[0].ppo = 0;
    data[0].ppoSignal = 0;

    // 计算快周期EMA和慢周期EMA
    for (int i = 1; i < length; i++) {
      double c = data[i].close;

      emaFast[i] = emaFast[i - 1] + alphaFast * (c - emaFast[i - 1]);
      emaSlow[i] = emaSlow[i - 1] + alphaSlow * (c - emaSlow[i - 1]);
    }

    // Step2: 计算 PPO 主线: ((EMAfast - EMAslow) / EMAslow) * 100
    List<double> ppoLine = List.filled(length, 0);
    for (int i = 0; i < length; i++) {
      double slow = emaSlow[i];
      if (slow.abs() < 1e-12) {
        // 防止除 0 或极端爆炸 => 设为0
        ppoLine[i] = 0;
      } else {
        double ratio = (emaFast[i] - slow) / slow * 100;
        // 可做一下防爆保护
        if (ratio.isInfinite || ratio.isNaN) {
          ratio = 0;
        } else if (ratio.abs() > 1e5) {
          // 你可以自定义一个最大绝对值
          ratio = ratio > 0 ? 1e5 : -1e5;
        }
        ppoLine[i] = ratio;
      }
      data[i].ppo = ppoLine[i];
    }

    // Step3: 计算 PPO信号线 (再对ppoLine做EMA平滑)
    final double alphaSignal = 2.0 / (signalPeriod + 1);
    if (length > 1) {
      data[1].ppoSignal = ppoLine[1]; // 初始化
      for (int i = 2; i < length; i++) {
        double prevSignal = data[i - 1].ppoSignal ?? 0;
        double curPPO = ppoLine[i];
        double sig = prevSignal + alphaSignal * (curPPO - prevSignal);

        // 防止溢出
        if (!sig.isFinite) sig = 0;

        data[i].ppoSignal = sig;
      }
    }
  }

  /// 计算 TRIX 指标和信号线
  /// [period]       计算TRIX的周期(常见默认12)
  /// [signalPeriod] 信号线周期(常见默认9)
  void _computeTRIX(List<KLineEntity> data,
      {int period = 12, int signalPeriod = 9}) {
    if (data.isEmpty) return;

    // 1) 先建3个临时数组保存中间结果(三次EMA)
    final int length = data.length;
    List<double> ema1 = List.filled(length, 0);
    List<double> ema2 = List.filled(length, 0);
    List<double> ema3 = List.filled(length, 0);

    // EMA参数 (2/(period+1))，也可做Wilder等其它平滑
    final double alpha = 2.0 / (period + 1);

    // 初始化(第一条无从计算, 先直接等于close)
    ema1[0] = data[0].close;
    ema2[0] = data[0].close;
    ema3[0] = data[0].close;
    data[0].trix = 0; // 第0条没法算TRIX
    data[0].trixSignal = 0; // 信号线也初始化

    // 2) 计算三重EMA
    for (int i = 1; i < length; i++) {
      double c = data[i].close;

      // 第一次EMA
      ema1[i] = ema1[i - 1] + alpha * (c - ema1[i - 1]);

      // 第二次EMA
      ema2[i] = ema2[i - 1] + alpha * (ema1[i] - ema2[i - 1]);

      // 第三次EMA
      ema3[i] = ema3[i - 1] + alpha * (ema2[i] - ema3[i - 1]);
    }

    // 3) 根据第三次EMA来计算 TRIX
    // for (int i = 1; i < length; i++) {
    //   double prev3 = ema3[i - 1];
    //   // if (prev3 != 0) {
    //   //   double trixVal = (ema3[i] - prev3) / prev3 * 100;
    //   //   data[i].trix = trixVal;
    //   // } else {
    //   //   data[i].trix = 0;
    //   // }

    //   // 如果 |(ema3[i] - prev3)/prev3| 超过某阈值，就直接截断
    //   if (prev3.abs() > 1e-12) {
    //     double ratio = (ema3[i] - prev3) / prev3;
    //     if (ratio.abs() > 1e4) {
    //       // 说明波动太大，直接截断
    //       ratio = ratio > 0 ? 1e4 : -1e4;
    //     }
    //     data[i].trix = ratio * 100;
    //   } else {
    //     data[i].trix = 0;
    //   }

    //   // 调试打印
    //   print('TRIX[$i]: ${data[i].trix}');
    // }
    for (int i = 1; i < length; i++) {
      double prev3 = ema3[i - 1];
      if (prev3.abs() < 1e-12) {
        // 防止分母过小 => 爆炸
        data[i].trix = 0;
      } else {
        double ratio = (ema3[i] - prev3) / prev3;
        // 如果你想做强行截断:
        if (ratio.isInfinite || ratio.isNaN) {
          ratio = 0;
        } else if (ratio.abs() > 1e4) {
          // 自定义最大绝对值，避免过大
          ratio = ratio > 0 ? 1e4 : -1e4;
        }
        data[i].trix = ratio * 100;
      }
    }

    // 4) 计算信号线(对 TRIX 做一条EMA)
    double alphaSignal = 2.0 / (signalPeriod + 1);
    // 让第0条 or 第1条初始化
    // 这里让第1条 = data[1].trix, 再从第2条开始
    if (length > 1) {
      data[1].trixSignal = data[1].trix ?? 0;
      for (int i = 2; i < length; i++) {
        double prevSignal = data[i - 1].trixSignal ?? 0;
        double currTrix = data[i].trix ?? 0;
        double signal = prevSignal + alphaSignal * (currTrix - prevSignal);
        data[i].trixSignal = signal;
      }
    }
  }

  /// 计算 DMI/ADX 的增强版
  /// [period]        常见默认14
  /// [useAdxr]       是否计算并保存ADXR
  /// [smoothMethod]  使用何种平滑算法:
  ///                  - "wilder"   经典Wilder平滑 (默认)
  ///                  - "ema"      指数平滑(EMA)
  ///                  - "double"   先Wilder后EMA的双重平滑
  ///
  /// [adxrPeriod]    当 useAdxr=true 时，用于计算 ADXR(i) = (ADX(i) + ADX(i - adxrPeriod)) / 2
  void _computeDMIAdvanced(
    List<KLineEntity> data, {
    int period = 14,
    bool useAdxr = true,
    int adxrPeriod = 14,
    String smoothMethod = 'wilder',
  }) {
    if (data.isEmpty) return;

    // --- 第一条数据无法算DM, 先给默认0 ---
    data[0].pdi = 0;
    data[0].mdi = 0;
    data[0].adx = 0;
    data[0].adxr = 0;

    // 平滑序列: TR14, +DM14, -DM14
    // 用于保存累计值, 后续根据 smoothMethod 进行不同的平滑处理
    double trAccum = 0;
    double plusDMAccum = 0;
    double minusDMAccum = 0;

    // 上一个 KLine（用于计算DM/TR）
    double prevHigh = data[0].high;
    double prevLow = data[0].low;
    double prevClose = data[0].close;

    // ------------------------------
    //  第一次循环: 初步计算 DI 和 DX, 并做指定的平滑
    // ------------------------------
    for (int i = 1; i < data.length; i++) {
      final cur = data[i];

      final curHigh = cur.high;
      final curLow = cur.low;

      // 1) +DM / -DM
      double upMove = curHigh - prevHigh;
      double downMove = prevLow - curLow;
      double plusDM = 0, minusDM = 0;
      if (upMove > downMove && upMove > 0) {
        plusDM = upMove;
      }
      if (downMove > upMove && downMove > 0) {
        minusDM = downMove;
      }

      // 2) TR
      final range1 = (curHigh - curLow).abs();
      final range2 = (curHigh - prevClose).abs();
      final range3 = (curLow - prevClose).abs();
      final tr = [range1, range2, range3].reduce((a, b) => a > b ? a : b);

      // ============= 根据选择的平滑方式，累加/衰减 =============
      if (i == 1) {
        // 初始化
        trAccum = tr;
        plusDMAccum = plusDM;
        minusDMAccum = minusDM;
        // 直接给第二条的pdi/mdi=0, 这条会在下一步中算
        data[1].pdi = 0;
        data[1].mdi = 0;
        data[1].adx = 0;
      } else {
        switch (smoothMethod) {
          case 'ema':
            // ======== 直接用EMA衰减 ========
            // 由于EMA需要一个alpha(2/(period+1))，可根据经验选
            final alpha = 2.0 / (period + 1);
            trAccum = trAccum + alpha * (tr - trAccum);
            plusDMAccum = plusDMAccum + alpha * (plusDM - plusDMAccum);
            minusDMAccum = minusDMAccum + alpha * (minusDM - minusDMAccum);
            break;

          case 'double':
            // ======== 先Wilder再EMA（双重） ========
            // 先用Wilder公式更新, 再对累加量做一次EMA平滑
            double oldTR = trAccum,
                oldPlus = plusDMAccum,
                oldMinus = minusDMAccum;
            // (a) Wilder
            oldTR = oldTR - (oldTR / period) + tr;
            oldPlus = oldPlus - (oldPlus / period) + plusDM;
            oldMinus = oldMinus - (oldMinus / period) + minusDM;

            // (b) 在Wilder结果上再做EMA
            final alpha = 2.0 / (period + 1);
            trAccum = trAccum + alpha * (oldTR - trAccum);
            plusDMAccum = plusDMAccum + alpha * (oldPlus - plusDMAccum);
            minusDMAccum = minusDMAccum + alpha * (oldMinus - minusDMAccum);
            break;

          case 'wilder':
          default:
            // ======== Wilder经典处理 ========
            trAccum = trAccum - (trAccum / period) + tr;
            plusDMAccum = plusDMAccum - (plusDMAccum / period) + plusDM;
            minusDMAccum = minusDMAccum - (minusDMAccum / period) + minusDM;
            break;
        }
      }

      // 3) 计算 +DI / -DI
      double plusDI = trAccum == 0 ? 0 : (100 * plusDMAccum / trAccum);
      double minusDI = trAccum == 0 ? 0 : (100 * minusDMAccum / trAccum);

      // 4) 计算DX
      double sumDI = plusDI + minusDI;
      double diffDI = (plusDI - minusDI).abs();
      double dx = (sumDI == 0) ? 0 : (100 * diffDI / sumDI);

      // 5) 计算或平滑 ADX
      if (i == 1) {
        // 对第二条先初始化
        cur.adx = dx;
      } else {
        double prevAdx = data[i - 1].adx ?? 0;
        // 这里也可根据smoothMethod来衰减 ADX，示例中继续Wilder:
        cur.adx = ((prevAdx * (period - 1)) + dx) / period;
      }

      // 赋值到实体
      cur.pdi = plusDI;
      cur.mdi = minusDI;

      // 更新 prev
      prevHigh = curHigh;
      prevLow = curLow;
      prevClose = cur.close;
    }

    // ---------------------------------
    // 如果需要计算 ADXR
    // ADXR(i) = (ADX(i) + ADX(i - adxrPeriod)) / 2
    // ---------------------------------
    if (useAdxr) {
      for (int i = adxrPeriod; i < data.length; i++) {
        double adxI = data[i].adx ?? 0;
        double adxIMinusPeriod = data[i - adxrPeriod].adx ?? 0;
        data[i].adxr = (adxI + adxIMinusPeriod) / 2.0;
      }
    }
  }

  void _computeDMI(List<KLineEntity> data, {int period = 14}) {
    if (data.isEmpty) return;

    double tr14 = 0; // 14周期的 TR 平滑
    double plusDM14 = 0; // 14周期的 +DM 平滑
    double minusDM14 = 0; // 14周期的 -DM 平滑

    // 第一个点无法算DMI，先记录当前值
    double prevHigh = data[0].high;
    double prevLow = data[0].low;
    double prevClose = data[0].close;

    // 让第0条暂时为 0
    data[0].pdi = 0;
    data[0].mdi = 0;
    data[0].adx = 0;
    data[0].adxr = 0;

    for (int i = 1; i < data.length; i++) {
      final cur = data[i];
      final curHigh = cur.high;
      final curLow = cur.low;

      // ============ 1) 计算 +DM / -DM ============
      double upMove = curHigh - prevHigh;
      double downMove = prevLow - curLow;
      double plusDM = 0, minusDM = 0;
      if (upMove > downMove && upMove > 0) {
        plusDM = upMove;
      }
      if (downMove > upMove && downMove > 0) {
        minusDM = downMove;
      }

      // ============ 2) 计算 TR ============
      double range1 = (curHigh - curLow).abs();
      double range2 = (curHigh - prevClose).abs();
      double range3 = (curLow - prevClose).abs();
      double tr = [range1, range2, range3].reduce((a, b) => a > b ? a : b);

      // ============ 3) Wilder 平滑处理 ============
      if (i == 1) {
        // 初始化
        tr14 = tr;
        plusDM14 = plusDM;
        minusDM14 = minusDM;
      } else {
        tr14 = tr14 - (tr14 / period) + tr;
        plusDM14 = plusDM14 - (plusDM14 / period) + plusDM;
        minusDM14 = minusDM14 - (minusDM14 / period) + minusDM;
      }

      // ============ 4) +DI / -DI ============
      double plusDI = tr14 == 0 ? 0 : (100 * plusDM14 / tr14);
      double minusDI = tr14 == 0 ? 0 : (100 * minusDM14 / tr14);

      // ============ 5) 计算当日 DX ============
      double sumDI = plusDI + minusDI;
      double diffDI = (plusDI - minusDI).abs();
      double dx = sumDI == 0 ? 0 : (100 * diffDI / sumDI);

      // ============ 6) 平滑 ADX ============
      if (i == 1) {
        cur.adx = dx; // 第二条先初始化
      } else {
        double prevAdx = data[i - 1].adx ?? 0;
        cur.adx = ((prevAdx * (period - 1)) + dx) / period;
      }

      // ============ 如果还需 ADXR, 这里或单独一轮再算 ============

      // 存到 KLineEntity
      cur.pdi = plusDI;
      cur.mdi = minusDI;
      // cur.adxr = ...

      // 记录上一条
      prevHigh = curHigh;
      prevLow = curLow;
      prevClose = cur.close;
    }
  }

  /// 计算 TSI (True Strength Index) 指标
  /// [r]            第一次EMA的周期(常用25)
  /// [s]            第二次EMA的周期(常用13)
  /// [signalPeriod] 信号线EMA周期(常用9)
  void _computeTSI(List<KLineEntity> data,
      {int r = 25, int s = 13, int signalPeriod = 9}) {
    if (data.length < 2) return;

    final length = data.length;
    // 第1步: 计算每根K线的 mom(i) = close(i) - close(i-1)
    List<double> mom = List.filled(length, 0);
    List<double> absMom = List.filled(length, 0);

    for (int i = 1; i < length; i++) {
      double diff = data[i].close - data[i - 1].close;
      mom[i] = diff;
      absMom[i] = diff.abs();
    }

    // 第2步: 对 mom 和 absMom 各做 "双重EMA"：先周期r，再周期s
    // 先建数组, 分两轮
    List<double> emaR_mom = List.filled(length, 0);
    List<double> emaR_abs = List.filled(length, 0);
    double alphaR = 2.0 / (r + 1);

    // (a) 第一次EMA(周期r)
    emaR_mom[0] = mom[0]; // 第0条mom=0
    emaR_abs[0] = absMom[0]; // 第0条absMom=0

    for (int i = 1; i < length; i++) {
      emaR_mom[i] = emaR_mom[i - 1] + alphaR * (mom[i] - emaR_mom[i - 1]);
      emaR_abs[i] = emaR_abs[i - 1] + alphaR * (absMom[i] - emaR_abs[i - 1]);
    }

    // (b) 第二次EMA(周期s)
    List<double> emaRS_mom = List.filled(length, 0);
    List<double> emaRS_abs = List.filled(length, 0);
    double alphaS = 2.0 / (s + 1);

    emaRS_mom[0] = emaR_mom[0];
    emaRS_abs[0] = emaR_abs[0];
    for (int i = 1; i < length; i++) {
      emaRS_mom[i] =
          emaRS_mom[i - 1] + alphaS * (emaR_mom[i] - emaRS_mom[i - 1]);
      emaRS_abs[i] =
          emaRS_abs[i - 1] + alphaS * (emaR_abs[i] - emaRS_abs[i - 1]);
    }

    // 第3步: 计算 TSI 主线: 100 * (emaRS_mom / emaRS_abs)
    for (int i = 0; i < length; i++) {
      double denom = emaRS_abs[i];
      double tsiValue;
      if (denom.abs() < 1e-12) {
        tsiValue = 0;
      } else {
        tsiValue = (emaRS_mom[i] / denom) * 100;
      }
      // 防爆保护
      if (!tsiValue.isFinite) tsiValue = 0;
      data[i].tsi = tsiValue;
    }

    // 第4步: 计算 TSI 的信号线(对 TSI 做个 EMA)
    double alphaSignal = 2.0 / (signalPeriod + 1);
    data[0].tsiSignal = data[0].tsi ?? 0; // 初始化
    for (int i = 1; i < length; i++) {
      double prevSig = data[i - 1].tsiSignal ?? 0;
      double curTsi = data[i].tsi ?? 0;
      double sig = prevSig + alphaSignal * (curTsi - prevSig);
      if (!sig.isFinite) sig = 0;
      data[i].tsiSignal = sig;
    }
  }

  /// 计算 Ichimoku (一目均衡表/云图)
  /// [tenkanPeriod]  默认9
  /// [kijunPeriod]   默认26
  /// [senkouBPeriod] 默认52
  /// [shift]         通常26，用于云图前移/后移，但在此仅计算值，不做实际数组越界写入
  void _computeIchimoku(
    List<KLineEntity> data, {
    int tenkanPeriod = 9,
    int kijunPeriod = 26,
    int senkouBPeriod = 52,
    int shift = 26,
  }) {
    final length = data.length;
    if (length == 0) return;

    // 函数: 取得[i-period+1 .. i]区间的最高价、最低价
    double highestHigh(List<KLineEntity> list, int endIndex, int period) {
      double hh = -double.infinity;
      int start = endIndex - period + 1; // 包含endIndex
      if (start < 0) start = 0;
      for (int idx = start; idx <= endIndex; idx++) {
        if (list[idx].high > hh) hh = list[idx].high;
      }
      return hh;
    }

    double lowestLow(List<KLineEntity> list, int endIndex, int period) {
      double ll = double.infinity;
      int start = endIndex - period + 1;
      if (start < 0) start = 0;
      for (int idx = start; idx <= endIndex; idx++) {
        if (list[idx].low < ll) ll = list[idx].low;
      }
      return ll;
    }

    for (int i = 0; i < length; i++) {
      // 1) 计算Tenkan(转换线)= (9日最高+9日最低)/2
      if (i >= tenkanPeriod - 1) {
        double hh = highestHigh(data, i, tenkanPeriod);
        double ll = lowestLow(data, i, tenkanPeriod);
        data[i].ichimokuTenkan = (hh + ll) / 2.0;
      } else {
        data[i].ichimokuTenkan = null; // 数据不够，无法计算
      }

      // 2) 计算Kijun(基准线)= (26日最高+26日最低)/2
      if (i >= kijunPeriod - 1) {
        double hh = highestHigh(data, i, kijunPeriod);
        double ll = lowestLow(data, i, kijunPeriod);
        data[i].ichimokuKijun = (hh + ll) / 2.0;
      } else {
        data[i].ichimokuKijun = null;
      }

      // 3) 先行Span A = (Tenkan + Kijun)/2 (一般要前移26)
      //   这里为了避免下标越界，不对 i+shift 写入
      //   只是在当前 i 存 "Span A" 的数值
      if (data[i].ichimokuTenkan != null && data[i].ichimokuKijun != null) {
        data[i].ichimokuSpanA =
            (data[i].ichimokuTenkan! + data[i].ichimokuKijun!) / 2.0;
      } else {
        data[i].ichimokuSpanA = null;
      }

      // 4) 先行Span B= (52日最高+52日最低)/2 (一般要前移26)
      if (i >= senkouBPeriod - 1) {
        double hh = highestHigh(data, i, senkouBPeriod);
        double ll = lowestLow(data, i, senkouBPeriod);
        data[i].ichimokuSpanB = (hh + ll) / 2.0;
      } else {
        data[i].ichimokuSpanB = null;
      }

      // 5) 遁行线(Chikou)= 收盘价 (一般要后移26)
      //   简化写法：存到当前 i
      data[i].ichimokuChikou = data[i].close;
    }
  }

  /// 计算Parabolic SAR(抛物线转向指标)
  /// [accInit]    初始加速因子(默认0.02)
  /// [accStep]    每次更新的加速步长(默认0.02)
  /// [accMax]     最大加速因子(默认0.2)
  void _computePSAR(
    List<KLineEntity> data, {
    double accInit = 0.02,
    double accStep = 0.02,
    double accMax = 0.2,
  }) {
    final length = data.length;
    if (length < 2) return;

    // 第1步：根据前两根K线判断初始趋势:
    // 如果 close(1) > close(0)，就Up，否则Down
    bool isUp = data[1].close > data[0].close;
    // 初始psar等
    // sar指示值, ep表示极点(最高价或最低价), af=加速因子
    double sar = isUp ? data[0].low : data[0].high;
    double ep = isUp ? data[0].high : data[0].low;
    double af = accInit;

    // 先给第0条、1条一个初始值
    data[0].psar = sar; // 或设置为null也可
    data[1].psar = sar; // 这样第1条不会缺失

    for (int i = 2; i < length; i++) {
      data[i].psarIsUp = isUp;
      final cur = data[i];

      // 2) 计算新的sar
      double newSar = sar + af * (ep - sar);

      // 防止溢出
      if (!newSar.isFinite) {
        newSar = sar;
      }

      // 3) 判断趋势(如果当前是上升趋势)
      if (isUp) {
        // 新的SAR不能高于 前2根k线的最低价
        double min1 = data[i - 1].low;
        double min2 = data[i - 2].low;
        if (newSar > min1) newSar = min1;
        if (newSar > min2) newSar = min2;

        // 如果现在的SAR >= 当前k线的low(说明趋势可能翻转)
        if (newSar > cur.low) {
          // 趋势翻转
          isUp = false;
          newSar = ep; // sar重置为上一轮的ep
          // ep改为当前的low
          ep = cur.low;
          af = accInit; // 加速因子重置
        } else {
          // 趋势未翻转
          // 如果当前high > 旧的ep => ep=high & 加速因子+=step
          if (cur.high > ep) {
            ep = cur.high;
            af += accStep;
            if (af > accMax) af = accMax;
          }
        }
      } else {
        // 当前是下行趋势
        // 新的SAR不能低于 前2根k线的最高价
        double max1 = data[i - 1].high;
        double max2 = data[i - 2].high;
        if (newSar < max1) newSar = max1;
        if (newSar < max2) newSar = max2;

        // 如果新的SAR <= 当前k线的high => 趋势翻转
        if (newSar < cur.high) {
          isUp = true;
          newSar = ep; // sar重置
          ep = cur.high;
          af = accInit;
        } else {
          // 下行趋势继续
          if (cur.low < ep) {
            ep = cur.low;
            af += accStep;
            if (af > accMax) af = accMax;
          }
        }
      }

      sar = newSar;
      cur.psar = sar;
    }
  }

  /// 计算 Aroon 指标
  /// [period] 常见默认14
  ///  - AroonUp = ((period - (i - idxOfRecentHigh)) / period)*100
  ///  - AroonDown = ((period - (i - idxOfRecentLow)) / period)*100
  ///  - AroonOsc = AroonUp - AroonDown (可选)
  void _computeAroon(List<KLineEntity> data,
      {int period = 14, bool calcOsc = true}) {
    final length = data.length;
    if (length < period) {
      // 少于period，计算不出来或只给默认值
      for (int i = 0; i < length; i++) {
        data[i].aroonUp = 0;
        data[i].aroonDown = 0;
        if (calcOsc) data[i].aroonOsc = 0;
      }
      return;
    }

    for (int i = 0; i < length; i++) {
      // 计算区间 [i - period + 1 .. i]，需判越界
      int start = i - period + 1;
      if (start < 0) start = 0; // 不够周期就从0开始
      double highest = -double.infinity;
      double lowest = double.infinity;
      int idxHigh = i;
      int idxLow = i;

      // 在过去 period 根(或到0)里找最高价/最低价以及它们所在索引
      for (int j = start; j <= i; j++) {
        double h = data[j].high;
        double l = data[j].low;
        if (h > highest) {
          highest = h;
          idxHigh = j;
        }
        if (l < lowest) {
          lowest = l;
          idxLow = j;
        }
      }

      // 计算 Up / Down
      double up = 100.0 * (period - (i - idxHigh)) / period;
      double down = 100.0 * (period - (i - idxLow)) / period;

      // 防止溢出
      if (!up.isFinite) up = 0;
      if (!down.isFinite) down = 0;

      data[i].aroonUp = up.clamp(0, 100); // 一般区间[0,100]
      data[i].aroonDown = down.clamp(0, 100);

      // 如果要 AroonOsc
      if (calcOsc) {
        double osc = up - down;
        if (!osc.isFinite) osc = 0;
        data[i].aroonOsc = osc;
      }
    }
  }

  calculateValue() {
    if (datas == null) return;
    if (datas!.isEmpty) return;

    // 如果勾选了 AROON
    if (secondaryStates.contains(SecondaryState.AROON)) {
      _computeAroon(datas!, period: 14, calcOsc: true);
    }

    // 如果用户勾选了SAR
    if (secondaryStates.contains(SecondaryState.SAR)) {
      _computePSAR(datas!, accInit: 0.02, accStep: 0.02, accMax: 0.2);
    }

    if (secondaryStates.contains(SecondaryState.ICHIMOKU)) {
      _computeIchimoku(datas!,
          tenkanPeriod: 9, kijunPeriod: 26, senkouBPeriod: 52);
    }

    //如果包含 TSI，就做 TSI 计算
    if (secondaryStates.contains(SecondaryState.TSI)) {
      _computeTSI(datas!, r: 25, s: 13, signalPeriod: 9);
    }

    // 如果选了 PPO
    if (secondaryStates.contains(SecondaryState.PPO)) {
      _computePPO(datas!, fastPeriod: 12, slowPeriod: 26, signalPeriod: 9);
    }

    // 如果用户选择了TRIX做副图,则计算
    if (secondaryStates.contains(SecondaryState.TRIX)) {
      _computeTRIX(datas!, period: 12, signalPeriod: 9);
    }

    // 如果用户配置了要显示DMI，则先计算DMI
    // if (secondaryStates.contains(SecondaryState.DMI)) {
    //   _computeDMI(datas!); // period可自定义
    // }
    // 如果用户勾选了DMI, 就内部计算DMI
    if (secondaryStates.contains(SecondaryState.DMI)) {
      _computeDMIAdvanced(
        datas!,
        period: 14,
        useAdxr: true, // 要不要计算ADXR
        adxrPeriod: 14,
        smoothMethod: 'ema', // 这里演示"双重平滑"
      );
    }

    maxScrollX = getMinTranslateX().abs();
    setTranslateXFromScrollX(scrollX);
    mStartIndex = indexOfTranslateX(xToTranslateX(0));
    mStopIndex = indexOfTranslateX(xToTranslateX(mWidth));
    for (int i = mStartIndex; i <= mStopIndex; i++) {
      var item = datas![i];
      getMainMaxMinValue(item, i);
      getVolMaxMinValue(item);
      // getSecondaryMaxMinValue(item);
      // 3）更新每个 SecondaryState 的最大最小值
      for (final st in secondaryStates) {
        double oldMax = mSecondaryMaxMap[st] ?? double.minPositive;
        double oldMin = mSecondaryMinMap[st] ?? double.maxFinite;
        double newMax = oldMax;
        double newMin = oldMin;
        if (st == SecondaryState.AROON) {
          // item.aroonUp, item.aroonDown, item.aroonOsc
          double? up = item.aroonUp;
          double? down = item.aroonDown;
          double? osc = item.aroonOsc; // 若calcOsc=true

          // 依次更新
          if (up != null && up.isFinite) {
            if (up > newMax) newMax = up;
            if (up < newMin) newMin = up;
          }
          if (down != null && down.isFinite) {
            if (down > newMax) newMax = down;
            if (down < newMin) newMin = down;
          }
          if (osc != null && osc.isFinite) {
            if (osc > newMax) newMax = osc;
            if (osc < newMin) newMin = osc;
          }
        } else if (st == SecondaryState.SAR) {
          // 只存一条 psar
          final psarVal = item.psar;
          if (psarVal != null && psarVal.isFinite) {
            if (psarVal > newMax) newMax = psarVal;
            if (psarVal < newMin) newMin = psarVal;
          }
        } else if (st == SecondaryState.ICHIMOKU) {
          // 5条线: Tenkan, Kijun, SpanA, SpanB, Chikou
          final lines = [
            item.ichimokuTenkan,
            item.ichimokuKijun,
            item.ichimokuSpanA,
            item.ichimokuSpanB,
            item.ichimokuChikou,
          ];
          for (var val in lines) {
            if (val != null && val.isFinite) {
              if (val > newMax) newMax = val;
              if (val < newMin) newMin = val;
            }
          }
        } else if (st == SecondaryState.TSI) {
          // TSI + 信号线
          if (item.tsi != null && item.tsiSignal != null) {
            if (item.tsi!.isFinite) {
              newMax = newMax > item.tsi! ? newMax : item.tsi!;
              newMin = newMin < item.tsi! ? newMin : item.tsi!;
            }
            if (item.tsiSignal!.isFinite) {
              newMax = newMax > item.tsiSignal! ? newMax : item.tsiSignal!;
              newMin = newMin < item.tsiSignal! ? newMin : item.tsiSignal!;
            }
          }
        } else if (st == SecondaryState.PPO) {
          // 这里给PPO主线 + PPO信号线 做max/min
          if (item.ppo != null && item.ppoSignal != null) {
            double ppoVal = item.ppo!;
            double ppoSig = item.ppoSignal!;
            if (ppoVal.isFinite) {
              newMax = newMax > ppoVal ? newMax : ppoVal;
              newMin = newMin < ppoVal ? newMin : ppoVal;
            }
            if (ppoSig.isFinite) {
              newMax = newMax > ppoSig ? newMax : ppoSig;
              newMin = newMin < ppoSig ? newMin : ppoSig;
            }
          }
        } else if (st == SecondaryState.TRIX) {
          // 和MACD/KDJ类似，获取TRIX和其Signal线的值
          if (item.trix != null && item.trixSignal != null) {
            // 这里只示例主线/信号线各一个
            // 如果你自己还想多画别的线，可以都加进reduce
            newMax = [oldMax, item.trix!, item.trixSignal!]
                .reduce((a, b) => a > b ? a : b);

            newMin = [oldMin, item.trix!, item.trixSignal!]
                .reduce((a, b) => a < b ? a : b);
          }
        } else if (st == SecondaryState.DMI) {
          // pdi, mdi, adx, adxr
          if (item.pdi != null && item.mdi != null && item.adx != null) {
            // 这里假设你还需要adxr，可以一起写，否则省略
            newMax = [
              oldMax,
              item.pdi!,
              item.mdi!,
              item.adx!,
              if (item.adxr != null) item.adxr!
            ].reduce((a, b) => a > b ? a : b);

            newMin = [
              oldMin,
              item.pdi!,
              item.mdi!,
              item.adx!,
              if (item.adxr != null) item.adxr!
            ].reduce((a, b) => a < b ? a : b);
          }
        } else if (st == SecondaryState.MACD) {
          // item.macd, item.dif, item.dea
          if (item.macd != null && item.dif != null && item.dea != null) {
            newMax = [oldMax, item.macd!, item.dif!, item.dea!]
                .reduce((a, b) => a > b ? a : b);
            newMin = [oldMin, item.macd!, item.dif!, item.dea!]
                .reduce((a, b) => a < b ? a : b);
          }
        } else if (st == SecondaryState.KDJ) {
          // item.k, item.d, item.j
          if (item.k != null && item.d != null && item.j != null) {
            newMax = [oldMax, item.k!, item.d!, item.j!]
                .reduce((a, b) => a > b ? a : b);
            newMin = [oldMin, item.k!, item.d!, item.j!]
                .reduce((a, b) => a < b ? a : b);
          }
        } else if (st == SecondaryState.RSI) {
          // item.rsi
          if (item.rsi != null) {
            newMax = newMax > item.rsi! ? newMax : item.rsi!;
            newMin = newMin < item.rsi! ? newMin : item.rsi!;
          }
        } else if (st == SecondaryState.WR) {
          // WR 通常范围 [-100, 0], 也可自行判定
          newMax = newMax > 0 ? newMax : 0;
          newMin = newMin < -100 ? newMin : -100;
        } else if (st == SecondaryState.CCI) {
          if (item.cci != null) {
            newMax = max(newMax, item.cci!);
            newMin = min(newMin, item.cci!);
          }
        }
        // 回写到 Map
        mSecondaryMaxMap[st] = newMax;
        mSecondaryMinMap[st] = newMin;

        print('[getSecondaryMaxMinValue] Max: $newMax, Min: $newMin');
      }
    }
  }

  void getMainMaxMinValue(KLineEntity item, int i) {
    double maxPrice, minPrice;
    if (mainState == MainState.MA) {
      maxPrice = max(item.high, _findMaxMA(item.maValueList ?? [0]));
      minPrice = min(item.low, _findMinMA(item.maValueList ?? [0]));
    } else if (mainState == MainState.BOLL) {
      maxPrice = max(item.up ?? 0, item.high);
      minPrice = min(item.dn ?? 0, item.low);
    } else {
      maxPrice = item.high;
      minPrice = item.low;
    }
    mMainMaxValue = max(mMainMaxValue, maxPrice);
    mMainMinValue = min(mMainMinValue, minPrice);

    if (mMainHighMaxValue < item.high) {
      mMainHighMaxValue = item.high;
      mMainMaxIndex = i;
    }
    if (mMainLowMinValue > item.low) {
      mMainLowMinValue = item.low;
      mMainMinIndex = i;
    }

    if (isLine == true) {
      mMainMaxValue = max(mMainMaxValue, item.close);
      mMainMinValue = min(mMainMinValue, item.close);
    }
  }

  double _findMaxMA(List<double> a) {
    double result = double.minPositive;
    for (double i in a) {
      result = max(result, i);
    }
    return result;
  }

  double _findMinMA(List<double> a) {
    double result = double.maxFinite;
    for (double i in a) {
      result = min(result, i == 0 ? double.maxFinite : i);
    }
    return result;
  }

  void getVolMaxMinValue(KLineEntity item) {
    mVolMaxValue = max(mVolMaxValue,
        max(item.vol, max(item.MA5Volume ?? 0, item.MA10Volume ?? 0)));
    mVolMinValue = min(mVolMinValue,
        min(item.vol, min(item.MA5Volume ?? 0, item.MA10Volume ?? 0)));
  }

  void getSecondaryMaxMinValue(KLineEntity item) {
    for (var secondaryState in secondaryStates) {
      print(
          'State: $secondaryState, MACD: ${item.macd}, DIF: ${item.dif}, DEA: ${item.dea}');
      print('Calculating SecondaryState: $secondaryState');
      print('MACD: ${item.macd}, DIF: ${item.dif}, DEA: ${item.dea}');
      print('KDJ: K=${item.k}, D=${item.d}, J=${item.j}');
      print('RSI: ${item.rsi}, WR: ${item.r}, CCI: ${item.cci}');

      double mSecondaryMaxValue = double.minPositive;
      double mSecondaryMinValue = double.maxFinite;

      if (secondaryState == SecondaryState.MACD) {
        if (item.macd != null) {
          mSecondaryMaxValue = max(
              mSecondaryMaxValue, max(item.macd!, max(item.dif!, item.dea!)));
          mSecondaryMinValue = min(
              mSecondaryMinValue, min(item.macd!, min(item.dif!, item.dea!)));
        }
      } else if (secondaryState == SecondaryState.KDJ) {
        if (item.d != null) {
          mSecondaryMaxValue =
              max(mSecondaryMaxValue, max(item.k!, max(item.d!, item.j!)));
          mSecondaryMinValue =
              min(mSecondaryMinValue, min(item.k!, min(item.d!, item.j!)));
        }
      } else if (secondaryState == SecondaryState.RSI) {
        if (item.rsi != null) {
          mSecondaryMaxValue = max(mSecondaryMaxValue, item.rsi!);
          mSecondaryMinValue = min(mSecondaryMinValue, item.rsi!);
        }
      } else if (secondaryState == SecondaryState.WR) {
        mSecondaryMaxValue = 0;
        mSecondaryMinValue = -100;
      } else if (secondaryState == SecondaryState.CCI) {
        if (item.cci != null) {
          mSecondaryMaxValue = max(mSecondaryMaxValue, item.cci!);
          mSecondaryMinValue = min(mSecondaryMinValue, item.cci!);
        }
      } else {
        mSecondaryMaxValue = 0;
        mSecondaryMinValue = 0;
      }
      // 添加日志
      print('[getSecondaryMaxMinValue] State: $secondaryState, '
          'Max: $mSecondaryMaxValue, Min: $mSecondaryMinValue');
    }
  }

  double xToTranslateX(double x) => -mTranslateX + x / scaleX;

  int indexOfTranslateX(double translateX) =>
      _indexOfTranslateX(translateX, 0, mItemCount - 1);

  ///二分查找当前值的index
  int _indexOfTranslateX(double translateX, int start, int end) {
    if (end == start || end == -1) {
      return start;
    }
    if (end - start == 1) {
      double startValue = getX(start);
      double endValue = getX(end);
      return (translateX - startValue).abs() < (translateX - endValue).abs()
          ? start
          : end;
    }
    int mid = start + (end - start) ~/ 2;
    double midValue = getX(mid);
    if (translateX < midValue) {
      return _indexOfTranslateX(translateX, start, mid);
    } else if (translateX > midValue) {
      return _indexOfTranslateX(translateX, mid, end);
    } else {
      return mid;
    }
  }

  ///根据索引索取x坐标
  ///+ mPointWidth / 2防止第一根和最后一根k线显示不���
  ///@param position 索引值
  double getX(int position) => position * mPointWidth + mPointWidth / 2;

  KLineEntity getItem(int position) {
    return datas![position];
    // if (datas != null) {
    //   return datas[position];
    // } else {
    //   return null;
    // }
  }

  ///scrollX 转换为 TranslateX
  void setTranslateXFromScrollX(double scrollX) =>
      mTranslateX = scrollX + getMinTranslateX();

  ///获取平移的最小值
  double getMinTranslateX() {
    var x = -mDataLen + mWidth / scaleX - mPointWidth / 2;
    return x >= 0 ? 0.0 : x;
  }

  ///计算长按后x的值，转换为index
  int calculateSelectedX(double selectX) {
    int mSelectedIndex = indexOfTranslateX(xToTranslateX(selectX));
    if (mSelectedIndex < mStartIndex) {
      mSelectedIndex = mStartIndex;
    }
    if (mSelectedIndex > mStopIndex) {
      mSelectedIndex = mStopIndex;
    }
    return mSelectedIndex;
  }

  ///translateX转化为view中的x
  double translateXtoX(double translateX) =>
      (translateX + mTranslateX) * scaleX;

  TextStyle getTextStyle(Color color) {
    return TextStyle(fontSize: 10.0, color: color);
  }

  @override
  bool shouldRepaint(BaseChartPainter oldDelegate) {
    return true;
//    return oldDelegate.datas != datas ||
//        oldDelegate.datas?.length != datas?.length ||
//        oldDelegate.scaleX != scaleX ||
//        oldDelegate.scrollX != scrollX ||
//        oldDelegate.isLongPress != isLongPress ||
//        oldDelegate.selectX != selectX ||
//        oldDelegate.isLine != isLine ||
//        oldDelegate.mainState != mainState ||
//        oldDelegate.secondaryState != secondaryState;
  }
}
