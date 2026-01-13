import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:signalr_netcore/signalr_client.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:flutter_background/flutter_background.dart';

import '../models/ticket.dart';
import '../models/user_session.dart';
import '../providers/theme_provider.dart';
import 'ticket_detail_screen.dart';
import 'create_ticket_screen.dart';
import 'login_screen.dart';
import 'reports_screen.dart';

class HomeScreen extends StatefulWidget {
  final String baseUrl;
  final UserSession userSession;

  const HomeScreen({super.key, required this.baseUrl, required this.userSession});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Ticket> allTickets = [];
  List<Ticket> filteredTickets = [];
  late HubConnection hubConnection;
  final AudioPlayer audioPlayer = AudioPlayer();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  bool isAlarmPlaying = false;
  bool isLoading = true;
  String searchQuery = "";
  int selectedStatusFilter = -1; // -1 = All

  @override
  void initState() {
    super.initState();
    initNotifications();
    fetchTickets();
    initSignalR();
  }

  Future<void> initNotifications() async {
    // Initialize Local Notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Initialize Background Execution
    try {
      if (Platform.isAndroid) {
        final androidConfig = FlutterBackgroundAndroidConfig(
          notificationTitle: "نظام التذاكر يعمل",
          notificationText: "التطبيق يعمل في الخلفية لتلقي التنبيهات",
          notificationImportance: AndroidNotificationImportance.normal,
          notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
        );
        bool hasPermissions = await FlutterBackground.hasPermissions;
        if (!hasPermissions) {
          hasPermissions = await FlutterBackground.initialize(androidConfig: androidConfig);
        }
        if (hasPermissions) {
          await FlutterBackground.enableBackgroundExecution();
        }
      }
    } catch (e) {
      print("Background Init Error: $e");
    }
    
    // Configure Audio Session for critical alerts
    await audioPlayer.setReleaseMode(ReleaseMode.loop);
    await audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);
  }

  void initSignalR() {
    hubConnection = HubConnectionBuilder()
        .withUrl('${widget.baseUrl}/ticketHub')
        .build();

    hubConnection.onclose(({error}) => print("Connection Closed"));

    hubConnection.on("ticket_created", (arguments) {
      print('SignalR Ticket Created: $arguments');
      triggerAlarm();
      showNotification('تذكرة جديدة', 'تم إضافة تذكرة جديدة للمستودع.');
      fetchTickets();
    });

    hubConnection.on("new_ticket", (arguments) {
      print('SignalR New Ticket: $arguments');
      triggerAlarm();
      showNotification('تذكرة جديدة', 'يوجد تذكرة جديدة بانتظارك.');
      fetchTickets();
    });

    hubConnection.on("comment_added", (arguments) {
      print('SignalR Comment Added: $arguments');
      _handleCommentNotification(arguments);
    });

    hubConnection.on("NewCommentNotification", (arguments) {
      print('SignalR New Comment (Web): $arguments');
      // For web, arguments are (ticketId, authorId, warehouseId)
      if (arguments != null && arguments.length >= 2) {
        final ticketId = arguments[0];
        final authorId = arguments[1];
        _handleCommentNotification([{'ticketId': ticketId, 'authorId': authorId}]);
      }
    });

    hubConnection.start()?.catchError((err) => print('SignalR Error: $err'));
  }

  void _handleCommentNotification(List<dynamic>? arguments) {
    if (arguments != null && arguments.isNotEmpty) {
      final data = arguments[0];
      int ticketId;
      String authorId;

      if (data is Map) {
        ticketId = data['ticketId'];
        authorId = data['authorId'].toString();
      } else {
        return;
      }
      
      if (authorId == widget.userSession.id) return;

      triggerAlarm();
      
      setState(() {
        for (var t in allTickets) {
          if (t.id == ticketId) {
            t.hasNewActivity = true;
          }
        }
        _applyFilters();
      });

      showNotification('تعليق جديد', 'يوجد نشاط جديد على التذكرة رقم #$ticketId');
    }
  }

  Future<void> fetchTickets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/api/mobile/tickets?userId=${widget.userSession.id}'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final fetchedTickets = data.map((json) => Ticket.fromJson(json)).toList();
        
        for (var ticket in fetchedTickets) {
          if (ticket.lastCommentDate != null) {
            String? lastViewedStr = prefs.getString('last_viewed_${ticket.id}');
            if (lastViewedStr != null) {
              DateTime lastViewed = DateTime.parse(lastViewedStr);
              DateTime lastComment = DateTime.parse(ticket.lastCommentDate!);
              if (lastComment.isAfter(lastViewed.add(const Duration(seconds: 1)))) {
                ticket.hasNewActivity = true;
              }
            } else if (ticket.commentCount > 0) {
              ticket.hasNewActivity = true;
            }
          }
        }

        setState(() {
          allTickets = fetchedTickets;
          _applyFilters();
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching tickets: $e');
      setState(() => isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      filteredTickets = allTickets.where((t) {
        final matchesSearch = t.problemType.toLowerCase().contains(searchQuery.toLowerCase()) || 
                             t.customerName.toLowerCase().contains(searchQuery.toLowerCase()) || 
                             t.billNumber.contains(searchQuery);
        final matchesStatus = selectedStatusFilter == -1 || t.status == selectedStatusFilter;
        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  Future<void> triggerAlarm() async {
    if (isAlarmPlaying) return;

    final prefs = await SharedPreferences.getInstance();
    final customRingtone = prefs.getString('custom_ringtone');

    setState(() {
      isAlarmPlaying = true;
    });

    try {
      if (customRingtone != null && customRingtone.isNotEmpty) {
        await audioPlayer.setSource(UrlSource(customRingtone)); 
      } else {
        await audioPlayer.setSource(AssetSource('alarm.mp3'));
      }
      await audioPlayer.resume();
    } catch (e) {
      print('Error playing alarm: $e');
      // Fallback
      await audioPlayer.play(AssetSource('alarm.mp3'));
    }
  }

  Future<void> stopAlarm() async {
    await audioPlayer.stop();
    setState(() {
      isAlarmPlaying = false;
    });
  }

  Future<void> selectRingtone() async {
    try {
      // Create channel to talk to Kotlin
      const platform = MethodChannel('com.example.app/ringtone');
      try {
        final String? result = await platform.invokeMethod('pickRingtone');
        if (result != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('custom_ringtone', result);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ نغمة التنبيه بنجاح')));
          }

          // Preview
          stopAlarm();
          await audioPlayer.setSource(UrlSource(result));
          await audioPlayer.resume();
          setState(() => isAlarmPlaying = true);
        }
      } on PlatformException catch (e) {
        print("Failed to pick ringtone: '${e.message}'.");
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل اختيار النغمة: غير مدعوم')));
        }
      }
    } catch (e) {
      print('Error picking ringtone: $e');
    }
  }

  Future<void> showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'warehouse_alerts',
      'تنبيهات المستودع',
      channelDescription: 'إشعارات هامة لموظفي المستودع',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      playSound: false,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    
    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecond, title, body, platformChannelSpecifics);
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userSession');
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LoginScreen(baseUrl: widget.baseUrl),
        ),
      );
    }
  }

  @override
  void dispose() {
    hubConnection.stop();
    audioPlayer.dispose();
    super.dispose();
  }

  Widget _buildStatCard(String title, String count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(count, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    int openCount = allTickets.where((t) => t.status == 0).length;
    int progressCount = allTickets.where((t) => t.status == 1).length;
    int resolvedCount = allTickets.where((t) => t.status == 2).length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(widget.userSession.username),
              accountEmail: const Text('موظف مستودع'),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 40, color: Colors.deepOrange),
              ),
              decoration: const BoxDecoration(color: Colors.deepOrange),
            ),
             ListTile(
              leading: const Icon(Icons.notifications_active),
              title: const Text('نغمة التنبيه'),
              subtitle: const Text('تغيير نغمة الإشعار الصوتية'),
              onTap: () {
                 Navigator.pop(context);
                 selectRingtone();
              },
            ),
             ListTile(
               leading: Icon(themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode),
               title: Text(themeProvider.isDarkMode ? 'الوضع النهاري' : 'الوضع الليلي'),
               onTap: () {
                 themeProvider.toggleTheme();
                 Navigator.pop(context);
               },
             ),
            const Divider(),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('معلومات'),
              subtitle: Text('الدور: ${widget.userSession.roles.join(", ")}'),
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.red),
              title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.red)),
              onTap: _logout,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      appBar: AppBar(
        title: const Text('تذاكر المستودع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded, color: Colors.deepOrange),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportsScreen(allTickets: allTickets))),
          ),
          IconButton(icon: const Icon(Icons.refresh, color: Colors.deepOrange), onPressed: fetchTickets),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: fetchTickets,
            child: Column(
              children: [
                // Quick Search Bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    onChanged: (val) {
                      searchQuery = val;
                      _applyFilters();
                    },
                    decoration: InputDecoration(
                      hintText: 'البحث برقم الفاتورة أو العميل...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
                
                // Stats Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      _buildStatCard('مفتوح', openCount.toString(), Colors.orange),
                      const SizedBox(width: 10),
                      _buildStatCard('قيد المعالجة', progressCount.toString(), Colors.blue),
                      const SizedBox(width: 10),
                      _buildStatCard('محلول', resolvedCount.toString(), Colors.green),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _filterChip('الكل', -1),
                      _filterChip('مفتوح', 0),
                      _filterChip('قيد المعالجة', 1),
                      _filterChip('محلول', 2),
                      _filterChip('مغلق', 3),
                    ],
                  ),
                ),

                const SizedBox(height: 10),
                
                // List of Tickets
                Expanded(
                  child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredTickets.isEmpty
                  ? Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        const Text('لا يوجد نتائج متطابقة', style: TextStyle(color: Colors.grey)),
                      ],
                    ))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: filteredTickets.length,
                      itemBuilder: (context, index) {
                        final ticket = filteredTickets[index];
                        return _buildTicketCard(ticket);
                      },
                    ),
                ),
              ],
            ),
          ),
          
          if (isAlarmPlaying)
            _buildAlarmOverlay(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
           final result = await Navigator.push(
              context, 
              MaterialPageRoute(
                builder: (_) => CreateTicketScreen(
                  baseUrl: widget.baseUrl,
                  userSession: widget.userSession,
                ),
              ),
            );
            if (result == true) fetchTickets();
        },
        backgroundColor: Colors.deepOrange,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _filterChip(String label, int status) {
    bool isSelected = selectedStatusFilter == status;
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            selectedStatusFilter = status;
            _applyFilters();
          });
        },
        selectedColor: Colors.deepOrange,
        labelStyle: TextStyle(color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color),
      ),
    );
  }

  Widget _buildTicketCard(Ticket ticket) {
    Color statusColor;
    String statusText;
    switch (ticket.status) {
      case 0: statusColor = Colors.red; statusText = 'مفتوح'; break;
      case 1: statusColor = Colors.orange; statusText = 'قيد المعالجة'; break;
      case 2: statusColor = Colors.green; statusText = 'محلول'; break;
      case 3: statusColor = Colors.green[800]!; statusText = 'مغلق'; break;
      default: statusColor = Colors.black; statusText = 'غير معروف';
    }

    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15), 
        side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1))
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('last_viewed_${ticket.id}', DateTime.now().toIso8601String());
          setState(() {
            ticket.hasNewActivity = false;
          });
          final result = await Navigator.push(
            context, 
            MaterialPageRoute(
              builder: (_) => TicketDetailScreen(
                ticket: ticket,
                baseUrl: widget.baseUrl,
                userSession: widget.userSession,
              ),
            ),
          );
          if (result == true) fetchTickets();
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  Text('#${ticket.id}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ticket.problemType,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (ticket.hasNewActivity)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                      child: const Text('نشط', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(ticket.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7))),
              const SizedBox(height: 12),
              Divider(height: 24, color: Theme.of(context).dividerColor.withOpacity(0.1)),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(ticket.customerName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(ticket.createdDate.split('T')[0], style: const TextStyle(fontSize: 12)),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlarmOverlay() {
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.all(30),
        margin: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 80),
            const SizedBox(height: 16),
            const Text(
              'تنبيه تذكرة جديدة!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('برجاء المراجعة الآن', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: stopAlarm,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: const Text('إيقاف التنبيه', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}
