import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/event_api_service.dart';
import 'camera_screen.dart';
import 'package:logger/logger.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

class CheckEventScreen extends StatefulWidget {
  final CameraDescription camera;
  const CheckEventScreen({super.key, required this.camera});

  @override
  State<CheckEventScreen> createState() => _CheckEventScreenState();
}

class _CheckEventScreenState extends State<CheckEventScreen>
    with SingleTickerProviderStateMixin {
  final EventApiService _eventApiService = EventApiService();
  late Future<List<Map<String, dynamic>>> _eventsFuture;
  final Logger logger = Logger();
  final TextEditingController _searchController = TextEditingController();

  // Pagination variables
  int _currentPage = 0;
  final int _itemsPerPage = 10;
  int _totalItems = 0;
  int _totalPages = 0;
  List<Map<String, dynamic>> _allEvents = [];
  List<Map<String, dynamic>> _filteredEvents = [];
  bool _isSearching = false;
  String _searchQuery = '';
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _eventsFuture = _loadEvents();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _searchController.addListener(() {
      _filterEvents(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadEvents() async {
    try {
      final events = await _eventApiService.fetchEventsFromApi();
      logger.i("Fetched ${events.length} events from backend");

      // Store all events for filtering and pagination
      setState(() {
        _allEvents = events;
        _filteredEvents = events;
        _totalItems = events.length;
        _totalPages = (_totalItems / _itemsPerPage).ceil();
      });

      return events;
    } catch (e, s) {
      logger.e("Error fetching events: $e\n$s");
      rethrow;
    }
  }

  void _filterEvents(String query) {
    setState(() {
      _searchQuery = query;
      _currentPage = 0; // Reset to first page when searching

      if (query.isEmpty) {
        _filteredEvents = _allEvents;
        _isSearching = false;
      } else {
        _isSearching = true;
        _filteredEvents =
            _allEvents.where((event) {
              final name = (event['name'] ?? '').toString().toLowerCase();
              final status =
                  (event['eventStatus'] ?? '').toString().toLowerCase();
              final time = (event['startTime'] ?? '').toString().toLowerCase();

              return name.contains(query.toLowerCase()) ||
                  status.contains(query.toLowerCase()) ||
                  time.contains(query.toLowerCase());
            }).toList();
      }

      _totalItems = _filteredEvents.length;
      _totalPages = math.max(1, (_totalItems / _itemsPerPage).ceil());

      // Reset animation for new results
      _animationController.reset();
      _animationController.forward();
    });
  }

  List<Map<String, dynamic>> _getPaginatedEvents() {
    if (_filteredEvents.isEmpty) return [];

    final startIndex = _currentPage * _itemsPerPage;

    // Safety check: if current page would be empty, reset to page 0
    if (startIndex >= _filteredEvents.length) {
      _currentPage = 0;
      final newStartIndex = 0;
      final newEndIndex = math.min(_itemsPerPage, _filteredEvents.length);
      return _filteredEvents.sublist(newStartIndex, newEndIndex);
    }

    final endIndex = math.min(
      startIndex + _itemsPerPage,
      _filteredEvents.length,
    );
    return _filteredEvents.sublist(startIndex, endIndex);
  }

  void _navigateToCameraScreen(String eventName) async {
    try {
      HapticFeedback.lightImpact();
      // Get the event ID
      final String? eventId = await _eventApiService.getEventIdByName(
        eventName,
      );
      logger.i(
        'Navigating to CameraScreen with event: $eventName (ID: $eventId)',
      );

      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (_) =>
                    CameraScreen(camera: widget.camera, eventName: eventName),
          ),
        );
      }
    } catch (e) {
      logger.e('Navigation error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error opening camera: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3E0),
      appBar: AppBar(
        title: const Text(
          'Danh sách sự kiện',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF7F50), Color(0xFFFF4500)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              HapticFeedback.mediumImpact();
              setState(() {
                _searchController.clear();
                _eventsFuture = _loadEvents();
                _isSearching = false;
              });
            },
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm sự kiện...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFFFF7F50)),
                suffixIcon:
                    _searchQuery.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                              _filteredEvents = _allEvents;
                              _isSearching = false;
                              _totalItems = _filteredEvents.length;
                              _totalPages =
                                  (_totalItems / _itemsPerPage).ceil();
                              _currentPage = 0;
                            });
                          },
                        )
                        : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFFFF7F50),
                    width: 2,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
              ),
              style: const TextStyle(fontSize: 16),
              onChanged: _filterEvents,
            ),
          ),

          // Event count indicator
          if (_isSearching && _filteredEvents.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.filter_list,
                    size: 16,
                    color: Color(0xFFFF7F50),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Tìm thấy ${_filteredEvents.length} kết quả cho "$_searchQuery"',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

          // Events list with FutureBuilder
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _eventsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFFF7F50),
                      ),
                    ),
                  );
                } else if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 60,
                          color: Colors.red.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Lỗi: ${snapshot.error}',
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _eventsFuture = _loadEvents();
                            });
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Thử lại'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF7F50),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                } else if (_filteredEvents.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isSearching ? Icons.search_off : Icons.event_busy,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isSearching
                              ? 'Không tìm thấy sự kiện cho "$_searchQuery"'
                              : 'Không có sự kiện nào',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_isSearching) ...[
                          const SizedBox(height: 16),
                          TextButton.icon(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _filteredEvents = _allEvents;
                                _isSearching = false;
                                _totalItems = _filteredEvents.length;
                                _totalPages =
                                    (_totalItems / _itemsPerPage).ceil();
                                _currentPage = 0;
                              });
                            },
                            icon: const Icon(Icons.clear, size: 18),
                            label: const Text('Xóa tìm kiếm'),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFFF7F50),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                // Get current page of events
                final events = _getPaginatedEvents();

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFFF3E0), Color(0xFFFFF8E1)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  // Replace AnimatedList with ListView.builder
                  child: ListView.builder(
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final event = events[index];
                      final name = event['name'] ?? 'Unnamed Event';
                      final status = event['eventStatus'] ?? 'UNKNOWN';
                      final isActive = status == "ACTIVE";

                      // Add animation with index-based delay for staggered effect
                      return AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          // Start the animation when this builder is called
                          _animationController.forward();

                          // Create a delayed animation for each item
                          final delay = index * 0.1;
                          final position = Tween<Offset>(
                            begin: const Offset(0.2, 0),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: _animationController,
                              curve: Interval(
                                delay.clamp(0.0, 0.9), // Start time with delay
                                math.min(delay + 0.6, 1.0), // End time
                                curve: Curves.easeOutQuad,
                              ),
                            ),
                          );

                          // Apply opacity animation too
                          final opacity = Tween<double>(
                            begin: 0.0,
                            end: 1.0,
                          ).animate(
                            CurvedAnimation(
                              parent: _animationController,
                              curve: Interval(
                                delay.clamp(0.0, 0.9),
                                math.min(delay + 0.4, 1.0),
                                curve: Curves.easeIn,
                              ),
                            ),
                          );

                          return FadeTransition(
                            opacity: opacity,
                            child: SlideTransition(
                              position: position,
                              child: _buildEventCard(event, name, isActive),
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),

          // Pagination controls
          if (_allEvents.isNotEmpty && _totalPages > 1)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    // Fix: Replace withOpacity with Color.fromARGB
                    color: Color(0x0D000000), // 5% black opacity
                    blurRadius: 3,
                    spreadRadius: 0,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Previous page button
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 18),
                    onPressed:
                        _currentPage > 0
                            ? () {
                              setState(() {
                                _currentPage--;
                              });
                            }
                            : null,
                    color:
                        _currentPage > 0
                            ? const Color(0xFFFF7F50)
                            : Colors.grey.shade400,
                  ),

                  // Page indicator
                  Text(
                    'Trang ${_currentPage + 1} / $_totalPages',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF555555),
                    ),
                  ),

                  // Next page button
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 18),
                    onPressed:
                        _currentPage < _totalPages - 1
                            ? () {
                              setState(() {
                                _currentPage++;
                              });
                            }
                            : null,
                    color:
                        _currentPage < _totalPages - 1
                            ? const Color(0xFFFF7F50)
                            : Colors.grey.shade400,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEventCard(
    Map<String, dynamic> event,
    String name,
    bool isActive,
  ) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12, top: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _navigateToCameraScreen(name),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      isActive
                          ? const Color(0x1A4CAF50) // 10% green
                          : const Color(0x1AFF5252), // 10% red
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.event,
                  color:
                      isActive
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFE53935),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF333333),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            // Fix 1: Replace withOpacity with Color.fromARGB
                            color:
                                isActive
                                    ? const Color(
                                      0x1A4CAF50,
                                    ) // 10% green opacity
                                    : const Color(
                                      0x1AE53935,
                                    ), // 10% red opacity
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              // Fix 2: Replace withOpacity with Color.fromARGB
                              color:
                                  isActive
                                      ? const Color(
                                        0x4D4CAF50,
                                      ) // 30% green opacity
                                      : const Color(
                                        0x4DE53935,
                                      ), // 30% red opacity
                              width: 1,
                            ),
                          ),
                          child: Text(
                            isActive ? "ACTIVE" : "NOT ACTIVE",
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  isActive
                                      ? const Color(0xFF2E7D32)
                                      : const Color(0xFFC62828),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Time information
                    if (event['startTime'] != null)
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 16,
                            color: Color(0xFF757575),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Start: ${event['startTime']}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF757575),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    if (event['endTime'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.event_busy,
                              size: 16,
                              color: Color(0xFF757575),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'End: ${event['endTime']}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF757575),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Color(0xFFBDBDBD),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
