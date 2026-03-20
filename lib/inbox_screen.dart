import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Telso Inbox',
      debugShowCheckedModeBanner: false,
      home: const InboxScreen(),
    );
  }
}

const kPink = Color(0xFFD70F64);

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPink,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
                  const Text(
                    'Inbox',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  // chat_bubble logo area
                  Row(
                    children: [
                      const Text(
                        'chat_bubb',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Stack(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Tab Bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                indicatorWeight: 2.5,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withOpacity(0.5),
                labelStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
                dividerColor: Colors.white.withOpacity(0.2),
                tabs: [
                  const Tab(text: 'Activity'),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Messages'),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            '3',
                            style: TextStyle(
                              color: kPink,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Tab Content ──
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_ActivityTab(), _MessagesTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Activity Tab
// ─────────────────────────────────────────
class _ActivityTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TODAY section
          _SectionLabel(label: 'TODAY'),

          // Sarah Jenkins
          _ActivityItem(
            avatarColor: const Color(0xFFE8C8B0),
            avatarIcon: _PersonAvatar(
              skin: Color(0xFFE8C8B0),
              hair: Color(0xFF3A2010),
            ),
            badgeIcon: Icons.favorite,
            badgeColor: const Color(0xFFE82020),
            richText: [
              const TextSpan(
                text: 'Sarah Jenkins',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const TextSpan(
                text: ' liked your post about the new Telso features.',
                style: TextStyle(color: Colors.white),
              ),
            ],
            time: '2m ago',
            trailing: _PostThumbnail(color: Color(0xFF1A2A1A)),
          ),

          _Divider(),

          // Mike Ross
          _ActivityItem(
            avatarColor: const Color(0xFFD0C8C0),
            avatarIcon: _PersonAvatar(
              skin: Color(0xFFD0C0A8),
              hair: Color(0xFF1A1A1A),
            ),
            badgeIcon: Icons.person_add,
            badgeColor: const Color(0xFF2080E0),
            richText: [
              const TextSpan(
                text: 'Mike Ross',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const TextSpan(
                text: ' followed you.',
                style: TextStyle(color: Colors.white),
              ),
            ],
            time: '15m ago',
            trailing: _FollowBackButton(),
          ),

          _Divider(),

          // Elena Gilbert
          _ActivityItem(
            avatarColor: const Color(0xFF5A3020),
            avatarIcon: _PersonAvatar(
              skin: Color(0xFFB87840),
              hair: Color(0xFF1A0A00),
            ),
            badgeIcon: Icons.chat_bubble,
            badgeColor: const Color(0xFF20A060),
            richText: [
              const TextSpan(
                text: 'Elena Gilbert',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const TextSpan(
                text:
                    ' mentioned you in a comment: "This is exactly what we need!"',
                style: TextStyle(color: Colors.white),
              ),
            ],
            time: '1h ago',
            trailing: null,
          ),

          _Divider(),

          // EARLIER
          _SectionLabel(label: 'EARLIER'),

          // Alex and 12 others
          _GroupActivityItem(),

          const SizedBox(height: 20),

          // People you might know
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: _PeopleYouMightKnow(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Widgets
// ─────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withOpacity(0.6),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      color: Colors.white.withOpacity(0.15),
      height: 1,
      indent: 20,
      endIndent: 20,
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final Color avatarColor;
  final Widget avatarIcon;
  final IconData badgeIcon;
  final Color badgeColor;
  final List<TextSpan> richText;
  final String time;
  final Widget? trailing;

  const _ActivityItem({
    required this.avatarColor,
    required this.avatarIcon,
    required this.badgeIcon,
    required this.badgeColor,
    required this.richText,
    required this.time,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar with badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: avatarColor,
                ),
                clipBehavior: Clip.hardEdge,
                child: avatarIcon,
              ),
              Positioned(
                bottom: -2,
                left: -2,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: kPink, width: 2),
                  ),
                  child: Icon(badgeIcon, color: Colors.white, size: 11),
                ),
              ),
            ],
          ),

          const SizedBox(width: 12),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 14, height: 1.4),
                    children: richText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
  }
}

class _PostThumbnail extends StatelessWidget {
  final Color color;
  const _PostThumbnail({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Center(
        child: Icon(Icons.videocam_rounded, color: Colors.white54, size: 22),
      ),
    );
  }
}

class _FollowBackButton extends StatefulWidget {
  @override
  State<_FollowBackButton> createState() => _FollowBackButtonState();
}

class _FollowBackButtonState extends State<_FollowBackButton> {
  bool _following = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _following = !_following),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _following ? Colors.white.withOpacity(0.25) : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _following ? 'Following' : 'Follow back',
          style: TextStyle(
            color: _following ? Colors.white : kPink,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _GroupActivityItem extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          // Overlapping avatars
          SizedBox(
            width: 70,
            height: 46,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF4A4A4A),
                      border: Border.all(color: kPink, width: 2),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white60,
                      size: 26,
                    ),
                  ),
                ),
                Positioned(
                  left: 24,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFE8D0B0),
                      border: Border.all(color: kPink, width: 2),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white60,
                      size: 26,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 14, height: 1.4),
                    children: [
                      TextSpan(
                        text: 'Alex and 12 others',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      TextSpan(
                        text: ' liked your story.',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '5h ago',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// People You Might Know
// ─────────────────────────────────────────
class _PeopleYouMightKnow extends StatelessWidget {
  final _people = const [
    _Person(name: 'James.T', bgColor: Color(0xFF3A3A3A)),
    _Person(name: 'Linda_K', bgColor: Color(0xFF4A6A8A)),
    _Person(name: 'Sonia.W', bgColor: Color(0xFFE8C8A0)),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'People you might know',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _people.map((p) => _PersonCard(person: p)).toList(),
          ),
        ],
      ),
    );
  }
}

class _Person {
  final String name;
  final Color bgColor;
  const _Person({required this.name, required this.bgColor});
}

class _PersonCard extends StatefulWidget {
  final _Person person;
  const _PersonCard({required this.person});

  @override
  State<_PersonCard> createState() => _PersonCardState();
}

class _PersonCardState extends State<_PersonCard> {
  bool _following = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.person.bgColor,
            border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
          ),
          child: const Icon(Icons.person, color: Colors.white70, size: 38),
        ),
        const SizedBox(height: 8),
        Text(
          widget.person.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => setState(() => _following = !_following),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            decoration: BoxDecoration(
              color: _following ? Colors.white.withOpacity(0.25) : Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _following ? '✓' : 'Follow',
              style: TextStyle(
                color: _following ? Colors.white : kPink,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
// Simple avatar painter
// ─────────────────────────────────────────
class _PersonAvatar extends StatelessWidget {
  final Color skin;
  final Color hair;
  const _PersonAvatar({required this.skin, required this.hair});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FacePainter(skin: skin, hair: hair),
    );
  }
}

class _FacePainter extends CustomPainter {
  final Color skin;
  final Color hair;
  const _FacePainter({required this.skin, required this.hair});

  @override
  void paint(Canvas canvas, Size s) {
    // bg
    canvas.drawRect(
      Rect.fromLTWH(0, 0, s.width, s.height),
      Paint()..color = skin.withOpacity(0.3),
    );
    // face
    canvas.drawOval(
      Rect.fromLTWH(
        s.width * 0.2,
        s.height * 0.2,
        s.width * 0.6,
        s.height * 0.6,
      ),
      Paint()..color = skin,
    );
    // hair
    final hp = Path()
      ..moveTo(s.width * 0.15, s.height * 0.38)
      ..quadraticBezierTo(
        s.width * 0.15,
        s.height * 0.08,
        s.width * 0.5,
        s.height * 0.1,
      )
      ..quadraticBezierTo(
        s.width * 0.85,
        s.height * 0.08,
        s.width * 0.85,
        s.height * 0.38,
      )
      ..quadraticBezierTo(
        s.width * 0.78,
        s.height * 0.2,
        s.width * 0.5,
        s.height * 0.18,
      )
      ..quadraticBezierTo(
        s.width * 0.22,
        s.height * 0.2,
        s.width * 0.15,
        s.height * 0.38,
      )
      ..close();
    canvas.drawPath(hp, Paint()..color = hair);
    // eyes
    canvas.drawOval(
      Rect.fromLTWH(
        s.width * 0.28,
        s.height * 0.42,
        s.width * 0.12,
        s.height * 0.07,
      ),
      Paint()..color = const Color(0xFF222222),
    );
    canvas.drawOval(
      Rect.fromLTWH(
        s.width * 0.58,
        s.height * 0.42,
        s.width * 0.12,
        s.height * 0.07,
      ),
      Paint()..color = const Color(0xFF222222),
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────
// Messages Tab (placeholder)
// ─────────────────────────────────────────
class _MessagesTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '3 new messages',
        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
      ),
    );
  }
}
