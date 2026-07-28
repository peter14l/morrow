import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:oasis/features/settings/presentation/providers/decoy_provider.dart';

class DecoyCalendarScreen extends StatefulWidget {
  const DecoyCalendarScreen({super.key});

  @override
  State<DecoyCalendarScreen> createState() => _DecoyCalendarScreenState();
}

class _DecoyCalendarScreenState extends State<DecoyCalendarScreen> {
  late DateTime _focusedMonth;
  late DateTime _selectedDay;

  // Predefined events for realistic calendar look
  final Map<int, List<String>> _dummyEvents = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  List<String> _getEventsForDay(DateTime date) {
    return [];
  }

  void _showPinDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const DecoyPinSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Calculate days in the month
    final daysInMonth = DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    final firstDayOffset = DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday % 7; // Sunday = 0

    // Month Names
    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    return TripleFingerSwipeDownDetector(
      onSwipe: _showPinDialog,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Calendar',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          centerTitle: true,
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Calendar Month/Year Navigator Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${monthNames[_focusedMonth.month - 1]} ${_focusedMonth.year}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () {
                            setState(() {
                              _focusedMonth = DateTime(
                                _focusedMonth.year,
                                _focusedMonth.month - 1,
                              );
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () {
                            setState(() {
                              _focusedMonth = DateTime(
                                _focusedMonth.year,
                                _focusedMonth.month + 1,
                              );
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Weekdays headers
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((day) {
                    return SizedBox(
                      width: 40,
                      child: Text(
                        day,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 8),

              // Calendar Days Grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: daysInMonth + firstDayOffset,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemBuilder: (context, index) {
                    if (index < firstDayOffset) {
                      return const SizedBox.shrink();
                    }

                    final dayNumber = index - firstDayOffset + 1;
                    final date = DateTime(_focusedMonth.year, _focusedMonth.month, dayNumber);
                    final isSelected = DateUtils.isSameDay(date, _selectedDay);
                    final isToday = DateUtils.isSameDay(date, DateTime.now());
                    final hasEvents = _getEventsForDay(date).isNotEmpty;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDay = date;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colorScheme.primary
                              : isToday
                                  ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                                  : Colors.transparent,
                          shape: BoxShape.circle,
                          border: isToday && !isSelected
                              ? Border.all(color: colorScheme.primary, width: 1)
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              dayNumber.toString(),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: isSelected || isToday
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? colorScheme.onPrimary
                                    : colorScheme.onSurface,
                              ),
                            ),
                            if (hasEvents)
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? colorScheme.onPrimary
                                      : colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const Divider(height: 32, indent: 16, endIndent: 16),

              // Events Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Events',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Events List
              Expanded(
                child: Builder(
                  builder: (context) {
                    final events = _getEventsForDay(_selectedDay);
                    if (events.isEmpty) {
                      return Center(
                        child: Text(
                          'No events scheduled for today',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: events.length,
                      itemBuilder: (context, index) {
                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 8),
                          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    events[index],
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Triple Finger Swipe Down Detector
// ---------------------------------------------------------------------------

class TripleFingerSwipeDownDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback onSwipe;

  const TripleFingerSwipeDownDetector({
    super.key,
    required this.child,
    required this.onSwipe,
  });

  @override
  State<TripleFingerSwipeDownDetector> createState() =>
      _TripleFingerSwipeDownDetectorState();
}

class _TripleFingerSwipeDownDetectorState extends State<TripleFingerSwipeDownDetector> {
  final Map<int, _PointerTrack> _tracks = {};
  bool _swipeTriggered = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (PointerDownEvent event) {
        _tracks[event.pointer] = _PointerTrack(
          startY: event.position.dy,
          currentY: event.position.dy,
        );
      },
      onPointerMove: (PointerMoveEvent event) {
        if (_swipeTriggered) return;

        final track = _tracks[event.pointer];
        if (track != null) {
          track.currentY = event.position.dy;
        }

        // If we have at least 3 active pointers
        if (_tracks.length >= 3) {
          bool allSwipedDown = true;
          for (final t in _tracks.values) {
            final deltaY = t.currentY - t.startY;
            if (deltaY < 80) { // 80 logical pixels threshold
              allSwipedDown = false;
              break;
            }
          }

          if (allSwipedDown) {
            _swipeTriggered = true;
            widget.onSwipe();
          }
        }
      },
      onPointerUp: (PointerUpEvent event) {
        _tracks.remove(event.pointer);
        if (_tracks.isEmpty) {
          _swipeTriggered = false;
        }
      },
      onPointerCancel: (PointerCancelEvent event) {
        _tracks.remove(event.pointer);
        if (_tracks.isEmpty) {
          _swipeTriggered = false;
        }
      },
      child: widget.child,
    );
  }
}

class _PointerTrack {
  final double startY;
  double currentY;
  _PointerTrack({required this.startY, required this.currentY});
}

// ---------------------------------------------------------------------------
// Decoy PIN Dialog Bottom Sheet
// ---------------------------------------------------------------------------

class DecoyPinSheet extends StatefulWidget {
  const DecoyPinSheet({super.key});

  @override
  State<DecoyPinSheet> createState() => _DecoyPinSheetState();
}

class _DecoyPinSheetState extends State<DecoyPinSheet> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 6; i++) {
      _focusNodes[i].onKeyEvent = (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace &&
            _controllers[i].text.isEmpty &&
            i > 0) {
          _focusNodes[i - 1].requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      };
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _currentPin => _controllers.map((c) => c.text).join();

  void _onChanged(String value, int index) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (_currentPin.length == 6) {
      _handleSubmit();
    }
  }

  Future<void> _handleSubmit() async {
    final pin = _currentPin;
    if (pin.length < 6) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final decoyProvider = context.read<DecoyProvider>();
      final navigator = Navigator.of(context);
      final success = await decoyProvider.unlock(pin);

      if (success) {
        if (mounted) {
          navigator.pop(); // Close bottom sheet
        }
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Incorrect PIN. Try again.';
          for (var c in _controllers) {
            c.clear();
          }
          _focusNodes[0].requestFocus();
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'An error occurred. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 32, 24, 32 + bottomPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Security Unlock',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter 6-digit PIN to unlock',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              6,
              (index) => SizedBox(
                width: 45,
                child: TextField(
                  controller: _controllers[index],
                  focusNode: _focusNodes[index],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 1,
                  style: theme.textTheme.headlineMedium,
                  decoration: InputDecoration(
                    counterText: '',
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: colorScheme.outlineVariant,
                        width: 2,
                      ),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) => _onChanged(value, index),
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          if (_isLoading)
            const CircularProgressIndicator()
          else
            const SizedBox(height: 48), // maintain height
        ],
      ),
    );
  }
}
