import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:minutes_slider/meditation_selector_provider.dart';
// import 'package:miracle_of_mind/common/extensions/extensions.dart';
// import 'package:miracle_of_mind/home/screens/meditation_selector_screen/meditation_selector_provider.dart';

const separatorGap = 12.0;
const separatorLineWidth = 3.0;
const separatorTotalWidth = (3 * separatorLineWidth) + (separatorGap * 2);

class MeditationDurationCarousel extends HookConsumerWidget {
  const MeditationDurationCarousel({super.key});

  final double maxScale = 1.1;
  final double minScale = 0.2;

  double calculateScale(double distanceToCenter, double centerPosition) {
    final double normalizedDistance = distanceToCenter / centerPosition;
    final double scale =
        maxScale - (normalizedDistance * (maxScale - minScale));
    return scale.clamp(minScale, maxScale);
  }

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

        if (
            // if less than 0.2 difference between the current index and the raw index, then user has almost scrolled to the item.
            differenceBetweenIndex.abs() < 0.2 &&
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

    return SizedBox(
      height: 200,
      child: NotificationListener<ScrollEndNotification>(
        onNotification: (notification) {
          if (!isScrollSnapping.value) {
            final scrollPosition = controller.offset;
            final itemSpacing = itemWidth + separatorTotalWidth;
            final rawIndex = scrollPosition / itemSpacing;
            final targetIndex = rawIndex.round();

            // print('Debug: scrollPosition = $scrollPosition');
            // print('Debug: rawIndex = $rawIndex');
            // print('Debug: targetIndex = $targetIndex');

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
                    final itemPosition =
                        index * (itemWidth + separatorTotalWidth) +
                            listPadding -
                            controller.offset;
                    final distanceToCenter =
                        (itemPosition - centerOfScreen + itemWidth / 2).abs();
                    final scale =
                        calculateScale(distanceToCenter, centerOfScreen);
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
                    style: Theme.of(context)
                        .textTheme
                        .headlineLarge
                        ?.copyWith(fontSize: 54),
                  ),
                ),
              ),
            );
          },
          separatorBuilder: (context, index) {
            return TimeSeparatorLines(scrollController: controller, index: index);
          },
          itemCount: meditationMinsOptions.length,
        ),
      ),
    );
  }
}

class TimeSeparatorLines extends StatelessWidget {
  final ScrollController scrollController;
  final int index;

  const TimeSeparatorLines({
    super.key,
    required this.scrollController,
    required this.index,
  });

  final double maxScale = 1.3;
  final double minScale = 0.8;

  double calculateScale(double distanceToCenter, double centerPosition, double screenWidth) {
    if (distanceToCenter > screenWidth / 2) {
      return minScale;
    }

    final double normalizedDistance = (distanceToCenter) / centerPosition;
    final double scale =
        maxScale - (normalizedDistance * (maxScale - minScale));
    return scale.clamp(minScale, maxScale);
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
                final separatorPosition = (index + separatorIndex / 3) *
                        (itemWidth + separatorTotalWidth) +
                    listPadding -
                    scrollController.offset;
                final distanceToCenter =
                    (separatorPosition - centerOfScreen + itemWidth / 2 + separatorTotalWidth).abs();
                final double scale =
                    calculateScale(distanceToCenter, centerOfScreen, screenWidth);

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

