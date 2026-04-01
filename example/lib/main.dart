import 'package:flutter/material.dart';
import 'package:rotation_ball_view/rotation_ball_view.dart';

void main() {
  runApp(const RotationBallDemoApp());
}

class RotationBallDemoApp extends StatelessWidget {
  const RotationBallDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'rotation_ball_view demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const DemoHomePage(),
    );
  }
}

class DemoHomePage extends StatefulWidget {
  const DemoHomePage({super.key});

  @override
  State<DemoHomePage> createState() => _DemoHomePageState();
}

class _DemoHomePageState extends State<DemoHomePage> {
  String _lastTap = '—';
  bool _isAnimate = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RotationBallView'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                Text(
                  'Last tap: $_lastTap\nDrag to rotate the ball.',
                  textAlign: TextAlign.center,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Idle rotation (isAnimate)'),
                  subtitle: const Text(
                    'Off: no auto spin after drag; on: idle animation + fling.',
                  ),
                  value: _isAnimate,
                  onChanged: (v) => setState(() => _isAnimate = v),
                ),
              ],
            ),
          ),
          SizedBox(height: 30),
          Center(
            child: SizedBox(
              width: 360,
              height: 360,
              child: RotationBallView(
                isAnimate: _isAnimate,
                itemCount: 30,
                itemBuilder: (context, index) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Item $index',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Icon(
                        Icons.star_outline,
                        size: 40,
                        color: Colors.primaries[index % Colors.primaries.length],
                      ),
                    ],
                  );
                },
                onItemTap: (index) {
                  setState(() => _lastTap = 'index $index');
                },
                decoration: BoxDecoration(
                  color: Colors.blue[400],
                  borderRadius: BorderRadius.circular(180),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red,
                      blurRadius: 20.0,
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
