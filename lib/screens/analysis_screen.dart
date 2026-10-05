import 'package:flutter/material.dart';

class AnalysisScreen extends StatelessWidget {
  final String contact;
  const AnalysisScreen({super.key, required this.contact});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('$contact 분석 결과'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '추천 (답장)'),
              Tab(text: '문철 (갈등 분석)'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildRecommendTab(),
            _buildMoonchulTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: const [
        Text('💡 다음 답장 추천', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 12),
        Card(child: ListTile(title: Text('네, 알겠습니다. 바로 처리하겠습니다.'))),
        Card(child: ListTile(title: Text('확인했습니다. 언제까지 드리면 될까요?'))),
      ],
    );
  }

  Widget _buildMoonchulTab() {
    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('⚖️ 갈등 진단 결과', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent)),
          SizedBox(height: 12),
          Text('현재 대화에서 오해가 발생한 것으로 보입니다. 부드러운 대화 전환이 필요합니다.'),
        ],
      ),
    );
  }
}
