import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:minutes_slider/meditation_selector_provider.dart';

const separatorGap = 12.0;
const separatorLineWidth = 3.0;
const separatorTotalWidth = (3 * separatorLineWidth) + (separatorGap * 2);

class MeditationDurationCarousel extends HookConsumerWidget {
  const MeditationDurationCarousel({super.key});

    int getIndexFromOffset(double itemWidth, double scrollOffset) {
      final scrollPosition = scrollOffset;
      final itemSpacing = itemWidth + separatorTotalWidth;
      final rawIndex = scrollPosition / itemSpacing;
      final currentCenterIndex = rawIndex.round();
      return currentCenterIndex;
    }

    double getOffsetFromIndex(double itemWidth, int index) {
      return index * (itemWidth + separatorTotalWidth);
    }

 @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectorState = ref.watch(meditationSelectorProvider);
    final meditationMinsOptions = selectorState.meditationMinsOptions;
    final selectedMins = selectorState.selectedMins;

    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = screenWidth / 3;
    final controller = useScrollController(
        initialScrollOffset: getOffsetFromIndex(
            itemWidth, meditationMinsOptions.indexOf(selectedMins)));
    final double centerOfScreen = screenWidth / 2;

    final listPadding = centerOfScreen - itemWidth / 2;
    final lastSelectedItem = useRef<int?>(null);
    final lastCallbackTime = useRef<DateTime>(DateTime.now());
    final isScrollSnapping = useRef<bool>(false);

    const minScrollThreshold = 20;

    // Dropdown to select the scale function
    final selectedFunction = useState<String>('Cosine');
    
    // Text editing controllers for minScale and maxScale
    final minScaleController = useTextEditingController(text: '0.2');
    final maxScaleController = useTextEditingController(text: '1.1');

    double getMinScale() {
      return double.tryParse(minScaleController.text) ?? 0.2;
    }

    double getMaxScale() {
      return double.tryParse(maxScaleController.text) ?? 1.1;
    }

    double calculateScale(String functionType, double distanceToCenter, double centerPosition) {
      final minScale = getMinScale();
      final maxScale = getMaxScale();

      final double normalizedDistance = distanceToCenter / centerPosition;

      switch (functionType) {
        case 'Cosine':
          final num scaleFactor = pow((1 + cos(pi * normalizedDistance)) / 2, 2);
          return minScale + scaleFactor * (maxScale - minScale);
        case 'Sigmoid':
          final double scaleFactor = 1 / (1 + exp(8 * (normalizedDistance - 0.5)));
          return minScale + scaleFactor * (maxScale - minScale);
        case 'Exponential':
          final double scaleFactor = exp(-3 * normalizedDistance);
          return minScale + scaleFactor * (maxScale - minScale);
        case 'Linear':
          final double linearDistance = (distanceToCenter * 2.5) / centerPosition;
          return maxScale - (linearDistance * (maxScale - minScale));
        default:
          return minScale;
      }
    }

    useEffect(() {
      if (!controller.hasClients) {
        return;
      }
      final initialOffset = getOffsetFromIndex(
          itemWidth, meditationMinsOptions.indexOf(selectedMins));
      controller.jumpTo(initialOffset);
    }, [
      meditationMinsOptions,
    ]);

    useEffect(() {
      void scrollListener() {
        final scrollPosition = controller.offset;
        final itemSpacing = itemWidth + separatorTotalWidth;
        final rawIndex = scrollPosition / itemSpacing;
        final currentCenterIndex = rawIndex.round();
        final differenceBetweenIndex = currentCenterIndex - rawIndex;

        if (differenceBetweenIndex.abs() < 0.2 &&
            currentCenterIndex != lastSelectedItem.value &&
            DateTime.now()
                    .difference(lastCallbackTime.value)
                    .inMilliseconds >
                minScrollThreshold) {
          lastSelectedItem.value = currentCenterIndex;
          lastCallbackTime.value = DateTime.now();

          Future.delayed(Duration.zero, () {
            ref
                .read(meditationSelectorProvider.notifier)
                .updateSelectedMins(currentCenterIndex);
          });

          HapticFeedback.lightImpact();
        }
      }

      controller.addListener(scrollListener);
      return () => controller.removeListener(scrollListener);
    }, []);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 60.0, left: 8.0, right: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              DropdownButton<String>(
                value: selectedFunction.value,
                items: <String>['Cosine', 'Sigmoid', 'Exponential', 'Linear']
                    .map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  selectedFunction.value = newValue!;
                },
              ),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: minScaleController,
                  decoration: const InputDecoration(labelText: 'minScale'),
                  keyboardType: TextInputType.number,
                ),
              ),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: maxScaleController,
                  decoration: const InputDecoration(labelText: 'maxScale'),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SizedBox(
            height: 200,
            child: NotificationListener<ScrollEndNotification>(
              onNotification: (notification) {
                if (!isScrollSnapping.value) {
                  final scrollPosition = controller.offset;
                  final itemSpacing = itemWidth + separatorTotalWidth;
                  final rawIndex = scrollPosition / itemSpacing;
                  final targetIndex = rawIndex.round();

                  final targetOffset = targetIndex * itemSpacing -
                      (centerOfScreen - listPadding - itemWidth / 2);

                  Future.delayed(Duration.zero, () async {
                    isScrollSnapping.value = true;
                    await controller.animateTo(
                      targetOffset,
                      duration: const Duration(milliseconds: 100),
                      curve: Curves.easeIn,
                    );
                    isScrollSnapping.value = false;
                  });
                }
                return false;
              },
              child: ListView.separated(
                controller: controller,
                padding: EdgeInsets.only(left: listPadding, right: listPadding),
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  return SizedBox(
                    width: itemWidth,
                    child: Center(
                      child: AnimatedBuilder(
                        animation: controller,
                        builder: (context, child) {
                          final itemPosition = index *
                                  (itemWidth + separatorTotalWidth) +
                              listPadding -
                              controller.offset;
                          final distanceToCenter =
                              (itemPosition - centerOfScreen + itemWidth / 2)
                                  .abs();
                          final scale = calculateScale(
                              selectedFunction.value,
                              distanceToCenter,
                              centerOfScreen);
                          return Transform.scale(
                            scale: scale,
                            child: Opacity(
                              opacity: scale.clamp(0, 1),
                              child: child!,
                            ),
                          );
                        },
                        child: Text(
                          '${meditationMinsOptions[index].minutes}',
                          style: const TextStyle(
                            fontFamily: 'Commissioner',
                            fontSize: 72,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                },
                separatorBuilder: (context, index) {
                  return TimeSeparatorLines(
                    scrollController: controller,
                    index: index,
                    selectedFunction: selectedFunction.value,
                    minScale: getMinScale(),
                    maxScale: getMaxScale(),
                  );
                },
                itemCount: meditationMinsOptions.length,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class TimeSeparatorLines extends StatelessWidget {
  final ScrollController scrollController;
  final int index;
  final String selectedFunction;
  final double minScale;
  final double maxScale;

  const TimeSeparatorLines({
    super.key,
    required this.scrollController,
    required this.index,
    required this.selectedFunction,
    required this.minScale,
    required this.maxScale,
  });

  double calculateScale(
      double distanceToCenter, double centerPosition, double screenWidth) {
    final double normalizedDistance = distanceToCenter / centerPosition;

    switch (selectedFunction) {
      case 'Cosine':
        final num scaleFactor = pow((1 + cos(pi * normalizedDistance)) / 2, 2);
        return minScale + scaleFactor * (maxScale - minScale);
      case 'Sigmoid':
        final double scaleFactor = 1 / (1 + exp(8 * (normalizedDistance - 0.5)));
        return minScale + scaleFactor * (maxScale - minScale);
      case 'Exponential':
        final double scaleFactor = exp(-3 * normalizedDistance);
        return minScale + scaleFactor * (maxScale - minScale);
      case 'Linear':
        final double linearDistance =
            (distanceToCenter * 2.5) / centerPosition;
        return maxScale - (linearDistance * (maxScale - minScale));
      default:
        return minScale;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = screenWidth / 3;
    final double centerOfScreen = screenWidth / 2;
    final listPadding = centerOfScreen - itemWidth / 2;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (separatorIndex) => Row(
          children: [
            AnimatedBuilder(
              animation: scrollController,
              builder: (context, child) {
                final itemPosition = index * (itemWidth + separatorTotalWidth) +
                    listPadding -
                    scrollController.offset;

                final separatorBlockPosition = itemPosition + itemWidth;
                final separatorRelativePosition =
                    (separatorIndex * separatorLineWidth) +
                        (separatorIndex * separatorGap);

                final separatorPosition =
                    separatorBlockPosition + separatorRelativePosition;

                final distanceToCenter =
                    (separatorPosition - centerOfScreen).abs();

                final double scale = calculateScale(
                    distanceToCenter, centerOfScreen, screenWidth);

                final double height = 20 * scale;

                return Transform.scale(
                  scaleY: scale,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    height: height,
                    width: 3,
                  ),
                );
              },
            ),
            if (separatorIndex < 2) const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}
