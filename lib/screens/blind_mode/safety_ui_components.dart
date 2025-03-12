import 'package:flutter/material.dart';

class SafetyUIComponents {
  static Widget gestureHint(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  static Widget buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.indigo.shade900, Colors.black],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 100,
                height: 100,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 6,
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Personal Safety Assistant',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Initializing safety services...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget buildAnalysisOverlay({
    required bool isProcessing,
    required bool hazardDetected,
    required bool isContinuousMode,
    required String lastAnalysis,
    required VoidCallback onRefresh,
  }) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hazardDetected
                ? Colors.red.withOpacity(0.7)
                : Colors.indigo.withOpacity(0.5),
            width: hazardDetected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 5),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: hazardDetected
                          ? Colors.red.withOpacity(0.3)
                          : Colors.indigo.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      hazardDetected
                          ? Icons.warning_amber
                          : Icons.remove_red_eye,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      hazardDetected
                          ? 'Safety Alert'
                          : (isContinuousMode
                          ? 'Continuous Safety Monitoring'
                          : 'Tap to Analyze Surroundings'),
                      style: TextStyle(
                        color: hazardDetected
                            ? Colors.red[300]
                            : Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (lastAnalysis.isNotEmpty)
                    IconButton(
                      icon: const Icon(
                        Icons.refresh,
                        color: Colors.white70,
                      ),
                      onPressed: onRefresh,
                    ),
                ],
              ),
            ),
            if (lastAnalysis.isNotEmpty)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 5, 20, 20),
                child: Text(
                  lastAnalysis,
                  style: TextStyle(
                    color: hazardDetected ? Colors.red[100] : Colors.white,
                    fontSize: 16,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}