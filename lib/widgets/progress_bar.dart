import 'package:flutter/material.dart';

class ProgressBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  const ProgressBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  @override
  State<ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<ProgressBar> {
  late double _sliderValue;
  bool _userIsSliding = false;

  @override
  void initState() {
    super.initState();
    _sliderValue = widget.position.inSeconds.toDouble();
  }

  @override
  void didUpdateWidget(ProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update slider value if user isn't actively sliding
    if (!_userIsSliding) {
      _sliderValue = widget.position.inSeconds.toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: Colors.white.withOpacity(0.8),
            inactiveTrackColor: Colors.white.withOpacity(0.3),
            thumbColor: Colors.white,
          ),
          child: Slider(
            value: _sliderValue,
            max: widget.duration.inSeconds.toDouble(),
            onChanged: (value) {
              setState(() {
                _sliderValue = value;
                _userIsSliding = true;
              });
            },
            onChangeEnd: (value) {
              _userIsSliding = false;
              widget.onSeek(Duration(seconds: value.toInt()));
            },
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(widget.position),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              Text(
                _formatDuration(widget.duration),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
}