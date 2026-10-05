import 'package:flutter/material.dart';
import 'analysis_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isOverlayActive = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('홈')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            color: _isOverlayActive ? const Color(0xFFE8EAF6) : Colors.white,
            child: SwitchListTile(
              title: const Text('AI 분석 오버레이 켜기'),
              value: _isOverlayActive,
              onChanged: (val) {
                setState(() => _isOverlayActive = val);
              },
            ),
          ),
          const SizedBox(height: 24),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildMenuCard(Icons.person, '내 정보'),
              _buildMenuCard(Icons.people_alt, '상대방 관리'),
              _buildMenuCard(Icons.history, '분석 로그'),
              GestureDetector(
                onTap: () {
                  // 테스트용: 버튼 클릭 시 상대방을 '선배님'으로 가정하고 분석 화면으로 이동
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AnalysisScreen(contact: '선배님')),
                  );
                },
                child: _buildMenuCard(Icons.touch_app, '오버레이 실행 테스트', color: Colors.orange.shade100),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(IconData icon, String title, {Color? color}) {
    return Card(
      color: color ?? Colors.white,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: const Color(0xFF5C6BC0)),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
