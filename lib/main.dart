import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  const MyApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI视频智能分析',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: AIAnalyzerPage(cameras: cameras),
    );
  }
}

class AIAnalyzerPage extends StatefulWidget {
  final List<CameraDescription> cameras;
  const AIAnalyzerPage({super.key, required this.cameras});

  @override
  State<AIAnalyzerPage> createState() => _AIAnalyzerPageState();
}

class _AIAnalyzerPageState extends State<AIAnalyzerPage> {
  late CameraController _controller;
  bool isAnalyzing = false;
  String aiResult = "";
  List<String> keywordList = ["火灾", "烟雾", "打架", "危险", "违规"];
  String apiKey = "sk-3da449b3fec74b2582956d26438b5a80";
  int alertCount = 0;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  // 初始化摄像头
  Future<void> _initCamera() async {
    _controller = CameraController(
      widget.cameras[0],
      ResolutionPreset.medium,
      imageFormat: ImageFormat.yuv420,
    );
    await _controller.initialize();
    setState(() {});
  }

  // 调用DeepSeek AI分析图像
  Future<String> analyzeImage(XFile image) async {
    final bytes = await image.readAsBytes();
    final base64Img = base64Encode(bytes);

    try {
      final response = await http.post(
        Uri.parse("https://api.deepseek.com/v1/chat/completions"),
        headers: {
          "Authorization": "Bearer $apiKey",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model": "deepseek-vision",
          "messages": [
            {
              "role": "user",
              "content": [
                {"type": "text", "text": "详细描述画面内容，检测是否有危险"},
                {
                  "type": "image_url",
                  "image_url": {"url": "data:image/jpeg;base64,$base64Img"}
                }
              ]
            }
          ]
        }),
      );

      final data = jsonDecode(response.body);
      return data["choices"][0]["message"]["content"];
    } catch (e) {
      return "AI分析失败：$e";
    }
  }

  // 关键词匹配
  bool matchKeywords(String text) {
    for (var kw in keywordList) {
      if (text.contains(kw)) return true;
    }
    return false;
  }

  // 开始实时AI分析
  Future<void> startAnalyze() async {
    if (isAnalyzing) return;
    setState(() => isAnalyzing = true);

    while (isAnalyzing) {
      try {
        final image = await _controller.takePicture();
        final result = await analyzeImage(image);
        setState(() => aiResult = result);

        if (matchKeywords(result)) {
          setState(() => alertCount++);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("⚠️ AI告警：检测到目标内容！")),
          );
        }
        await Future.delayed(const Duration(seconds: 1));
      } catch (e) {
        break;
      }
    }
  }

  // 停止分析
  void stopAnalyze() {
    setState(() => isAnalyzing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI视频智能分析系统")),
      body: Column(
        children: [
          // 摄像头预览
          Expanded(
            child: _controller.value.isInitialized
                ? CameraPreview(_controller)
                : const Center(child: CircularProgressIndicator()),
          ),

          // AI状态
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text("AI识别结果：$aiResult", maxLines: 2),
          ),

          // 告警计数
          Text("告警次数：$alertCount", style: const TextStyle(fontSize: 16)),

          // 控制按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: startAnalyze,
                child: const Text("▶️ 开始AI分析"),
              ),
              ElevatedButton(
                onPressed: stopAnalyze,
                child: const Text("⏹️ 停止"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
