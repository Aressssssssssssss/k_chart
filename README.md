# k_chart_multiple
Maybe this is the best k chart in Flutter.Support drag,scale,long press,fling.And easy to use.
Based on the https://github.com/OpenFlutter/k_chart_multiple
Added support for multiple secondary chart and hiding main chart

## display

#### image

<img src="https://github.com/mafanwei/k_chart_multiple/blob/master/example/images/Screenshot1.jpg" width="375" alt="Screenshot"/>

<img src="https://github.com/mafanwei/k_chart_multiple/blob/master/example/images/Screenshot2.jpg" width="375" alt="Screenshot"/>

<img src="https://github.com/mafanwei/k_chart_multiple/blob/master/example/images/Screenshot3.jpeg" width="375" alt="Screenshot"/>

#### gif

![demo](https://github.com/mafanwei/k_chart_multiple/blob/master/example/images/demo.gif)

![demo](https://github.com/mafanwei/k_chart_multiple/blob/master/example/images/demo2.gif)

## Getting Started
#### Install
```
dependencies:
  k_chart_multiple: ^1.0.0
```
or use latest：
```
k_chart_multiple:
    git:
      url: https://github.com/mafanwei/k_chart_multiple
```
#### Usage

**When you change the data, you must call this:**
```dart
DataUtil.calculate(datas); //This function has some optional parameters: n is BOLL N-day closing price. k is BOLL param.
```

use k line chart:
```dart
Container(
              height: 450,
              width: double.infinity,
              child: KChartWidget(
                chartStyle, // Required for styling purposes
                chartColors,// Required for styling purposes
                datas,// Required，Data must be an ordered list，(history=>now)
                isLine: isLine,// Decide whether it is k-line or time-sharing
                mainState: _mainState,// Decide what the main view shows
                secondaryStates: _secondaryStates,// Decide what the sub views shows
                fixedLength: 2,// Displayed decimal precision
                timeFormat: TimeFormat.YEAR_MONTH_DAY,
                onLoadMore: (bool a) {},// Called when the data scrolls to the end. When a is true, it means the user is pulled to the end of the right side of the data. When a
                // is false, it means the user is pulled to the end of the left side of the data.
                maDayList: [5,10,20],// Display of MA,This parameter must be equal to DataUtil.calculate‘s maDayList
                translations: kChartTranslations,// Graphic language
                volHidden: false,// hide volume
                showNowPrice: true,// show now price
                isOnDrag: (isDrag){},// true is on Drag.Don't load data while Draging.
                onSecondaryTap:(){},// on secondary rect taped.
                isTrendLine: false, // You can use Trendline by long-pressing and moving your finger after setting true to isTrendLine property. 
                xFrontPadding: 100 // padding in front
              ),
            ),
```
use depth chart:
```dart
DepthChart(_bids, _asks, chartColors) //Note: Datas must be an ordered list，
```

#### Thanks
[gwhcn/flutter_k_chart](https://github.com/gwhcn/flutter_k_chart)
