import 'package:flutter/material.dart';

import '../../../app/routing/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/app_buttons.dart';
import '../domain/video_summary_time_utils.dart';
import '../video_summary_models.dart';

Future<void> showTimestampIntervalPickerSheet({
  required BuildContext context,
  required int initialStartSeconds,
  required int initialEndSeconds,
  required int totalDurationSeconds,
  required ValueChanged<TimestampRangeSelection> onRangeChanged,
}) async {
  var draftStart = initialStartSeconds.toDouble();
  var draftEnd = initialEndSeconds.toDouble();

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return SafeArea(
        top: false,
        child: StatefulBuilder(
          builder: (context, setModalState) {
            final currentSeconds = (draftEnd - draftStart).round();

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '自定义时间区间',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '用户可自由设置开始和结束时间，最短 10 秒，最长不超过视频总长度。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9FC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFD7DFE7)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatVideoSummaryTimestampRange(
                            draftStart.round(),
                            draftEnd.round(),
                          ),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '当前区间长度 ${formatVideoSummaryRangeLength(currentSeconds)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 10.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        RangeSlider(
                          values: RangeValues(draftStart, draftEnd),
                          min: 0,
                          max: totalDurationSeconds.toDouble(),
                          divisions: totalDurationSeconds,
                          activeColor: const Color(0xFF2B63EB),
                          inactiveColor: const Color(0xFFDCE6FA),
                          labels: RangeLabels(
                            formatVideoSummaryClockLabel(draftStart.round()),
                            formatVideoSummaryClockLabel(draftEnd.round()),
                          ),
                          onChanged: (values) {
                            var nextStart = values.start.round();
                            var nextEnd = values.end.round();

                            if (nextEnd - nextStart < 10) {
                              if ((nextStart - draftStart).abs() >
                                  (nextEnd - draftEnd).abs()) {
                                nextStart = nextEnd - 10;
                              } else {
                                nextEnd = nextStart + 10;
                              }
                            }

                            nextStart = nextStart.clamp(
                              0,
                              totalDurationSeconds - 10,
                            );
                            nextEnd = nextEnd.clamp(
                              nextStart + 10,
                              totalDurationSeconds,
                            );

                            setModalState(() {
                              draftStart = nextStart.toDouble();
                              draftEnd = nextEnd.toDouble();
                            });
                          },
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _RangeValueTile(
                                label: '开始',
                                value: formatVideoSummaryClockLabel(
                                  draftStart.round(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _RangeValueTile(
                                label: '结束',
                                value: formatVideoSummaryClockLabel(
                                  draftEnd.round(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppPrimaryButton(
                    label: '应用这个时间区间',
                    onPressed: () {
                      onRangeChanged(
                        TimestampRangeSelection(
                          startSeconds: draftStart.round(),
                          endSeconds: draftEnd.round(),
                        ),
                      );
                      AppNavigator.popCurrent(context);
                    },
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}

class _RangeValueTile extends StatelessWidget {
  const _RangeValueTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD7DFE7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}