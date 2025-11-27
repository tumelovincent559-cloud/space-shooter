import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';

void main() {
  runApp(const SpaceShooterApp());
}

class SpaceShooterApp extends StatelessWidget {
  const SpaceShooterApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Space Shooter',
      theme: ThemeData.dark(),
      home: const GameScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({Key? key}) : super(key: key);

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // Player properties
  double playerX = 0;
  double playerY = 0;
  double playerSize = 60;

  // Game state
  int score = 0;
  int wave = 1;
  double health = 100;
  bool gameStarted = false;

  // Bullets and enemies
  List<Bullet> playerBullets = [];
  List<Enemy> enemies = [];
  List<Bullet> enemyBullets = [];

  // Stars for background
  List<Star> stars = [];

  // Timers
  Timer? gameLoop;
  Timer? enemySpawnTimer;
  Timer? enemyShootTimer;

  Random random = Random();

  @override
  void initState() {
    super.initState();
    initializeStars();
    startGame();
  }

  void initializeStars() {
    stars = List.generate(
        50,
        (index) => Star(
              x: random.nextDouble() * 400 - 200,
              y: random.nextDouble() * 800 - 400,
              size: random.nextDouble() * 2 + 1,
            ));
  }

  void startGame() {
    gameStarted = true;

    // Main game loop
    gameLoop = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (mounted) {
        setState(() {
          updateGame();
        });
      }
    });

    // Spawn enemies
    enemySpawnTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      spawnEnemy();
    });

    // Enemies shoot
    enemyShootTimer =
        Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      enemiesShoot();
    });
  }

  void spawnEnemy() {
    if (enemies.length < 8) {
      enemies.add(Enemy(
        x: random.nextDouble() * 300 - 150,
        y: -400,
        velocityY: 1 + (wave * 0.2),
        type: random.nextInt(3),
      ));
    }
  }

  void enemiesShoot() {
    for (var enemy in enemies) {
      if (enemy.y > -300 && enemy.y < 200 && random.nextDouble() > 0.5) {
        enemyBullets.add(Bullet(
          x: enemy.x,
          y: enemy.y,
          velocityY: 5,
          isEnemy: true,
        ));
      }
    }
  }

  void updateGame() {
    // Update stars
    for (var star in stars) {
      star.y += star.size * 0.5;
      if (star.y > 400) {
        star.y = -400;
        star.x = random.nextDouble() * 400 - 200;
      }
    }

    // Update player bullets
    playerBullets.removeWhere((bullet) {
      bullet.y -= bullet.velocityY;
      return bullet.y < -400;
    });

    // Update enemy bullets
    enemyBullets.removeWhere((bullet) {
      bullet.y += bullet.velocityY;

      // Check collision with player
      if ((bullet.x - playerX).abs() < playerSize / 2 &&
          (bullet.y - playerY).abs() < playerSize / 2) {
        health -= 10;
        if (health <= 0) {
          gameOver();
        }
        return true;
      }

      return bullet.y > 400;
    });

    // Update enemies
    enemies.removeWhere((enemy) {
      enemy.y += enemy.velocityY;
      enemy.x += sin(enemy.y * 0.02) * 2;

      // Check collision with player
      if ((enemy.x - playerX).abs() < playerSize / 2 &&
          (enemy.y - playerY).abs() < playerSize / 2) {
        health -= 20;
        if (health <= 0) {
          gameOver();
        }
        return true;
      }

      return enemy.y > 400;
    });

    // Check bullet-enemy collisions
    for (var bullet in List.from(playerBullets)) {
      for (var enemy in List.from(enemies)) {
        if ((bullet.x - enemy.x).abs() < 30 &&
            (bullet.y - enemy.y).abs() < 30) {
          score += 10;
          playerBullets.remove(bullet);
          enemies.remove(enemy);
          break;
        }
      }
    }

    // Check for wave completion
    if (score > 0 && score % 100 == 0 && enemies.isEmpty) {
      wave++;
      health = min(100, health + 20);
    }
  }

  void shoot() {
    playerBullets.add(Bullet(
      x: playerX,
      y: playerY - playerSize / 2,
      velocityY: 10,
      isEnemy: false,
    ));
  }

  void gameOver() {
    gameLoop?.cancel();
    enemySpawnTimer?.cancel();
    enemyShootTimer?.cancel();
    gameStarted = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Game Over!'),
        content: Text('Final Score: $score\nWave: $wave'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              resetGame();
            },
            child: const Text('Play Again'),
          ),
        ],
      ),
    );
  }

  void resetGame() {
    setState(() {
      score = 0;
      wave = 1;
      health = 100;
      playerX = 0;
      playerY = 0;
      playerBullets.clear();
      enemyBullets.clear();
      enemies.clear();
    });
    startGame();
  }

  @override
  void dispose() {
    gameLoop?.cancel();
    enemySpawnTimer?.cancel();
    enemyShootTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            playerX = (details.localPosition.dx -
                    MediaQuery.of(context).size.width / 2)
                .clamp(-MediaQuery.of(context).size.width / 2 + playerSize / 2,
                    MediaQuery.of(context).size.width / 2 - playerSize / 2);
            playerY = (details.localPosition.dy -
                    MediaQuery.of(context).size.height / 2)
                .clamp(-MediaQuery.of(context).size.height / 2 + playerSize / 2,
                    MediaQuery.of(context).size.height / 2 - playerSize / 2);
          });
        },
        onTapDown: (details) {
          shoot();
        },
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0a0e27), Color(0xFF1a1f3a)],
            ),
          ),
          child: Stack(
            children: [
              // Stars
              ...stars.map((star) => Positioned(
                    left: MediaQuery.of(context).size.width / 2 + star.x,
                    top: MediaQuery.of(context).size.height / 2 + star.y,
                    child: Container(
                      width: star.size,
                      height: star.size,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        shape: BoxShape.circle,
                      ),
                    ),
                  )),

              // Player bullets
              ...playerBullets.map((bullet) => Positioned(
                    left: MediaQuery.of(context).size.width / 2 + bullet.x - 3,
                    top: MediaQuery.of(context).size.height / 2 + bullet.y - 8,
                    child: Container(
                      width: 6,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.cyan,
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.cyan.withOpacity(0.6),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  )),

              // Enemy bullets
              ...enemyBullets.map((bullet) => Positioned(
                    left: MediaQuery.of(context).size.width / 2 + bullet.x - 3,
                    top: MediaQuery.of(context).size.height / 2 + bullet.y - 8,
                    child: Container(
                      width: 6,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.6),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  )),

              // Enemies
              ...enemies.map((enemy) => Positioned(
                    left: MediaQuery.of(context).size.width / 2 + enemy.x - 25,
                    top: MediaQuery.of(context).size.height / 2 + enemy.y - 25,
                    child: CustomPaint(
                      size: const Size(50, 50),
                      painter: EnemyPainter(type: enemy.type),
                    ),
                  )),

              // Player
              Positioned(
                left: MediaQuery.of(context).size.width / 2 +
                    playerX -
                    playerSize / 2,
                top: MediaQuery.of(context).size.height / 2 +
                    playerY -
                    playerSize / 2,
                child: CustomPaint(
                  size: Size(playerSize, playerSize),
                  painter: SpaceshipPainter(),
                ),
              ),

              // UI
              Positioned(
                top: 40,
                left: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Score: $score',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Wave: $wave',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: 200,
                      height: 20,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: health / 100,
                          backgroundColor: Colors.red.shade900,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            health > 50 ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Instructions
              if (score == 0 && wave == 1)
                const Positioned(
                  bottom: 100,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      'Drag to move • Tap to shoot',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Spaceship painter
class SpaceshipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Main body (gradient)
    final bodyRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.6,
      height: size.height * 0.8,
    );

    paint.shader = const LinearGradient(
      colors: [Color(0xFF00d4ff), Color(0xFF0077ff)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(bodyRect);

    // Draw ship body
    final path = Path();
    path.moveTo(size.width / 2, size.height * 0.1);
    path.lineTo(size.width * 0.3, size.height * 0.6);
    path.lineTo(size.width * 0.35, size.height * 0.9);
    path.lineTo(size.width * 0.65, size.height * 0.9);
    path.lineTo(size.width * 0.7, size.height * 0.6);
    path.close();
    canvas.drawPath(path, paint);

    // Wings
    paint.shader = null;
    paint.color = const Color(0xFF0099ff);

    final leftWing = Path();
    leftWing.moveTo(size.width * 0.3, size.height * 0.5);
    leftWing.lineTo(size.width * 0.1, size.height * 0.7);
    leftWing.lineTo(size.width * 0.3, size.height * 0.7);
    leftWing.close();
    canvas.drawPath(leftWing, paint);

    final rightWing = Path();
    rightWing.moveTo(size.width * 0.7, size.height * 0.5);
    rightWing.lineTo(size.width * 0.9, size.height * 0.7);
    rightWing.lineTo(size.width * 0.7, size.height * 0.7);
    rightWing.close();
    canvas.drawPath(rightWing, paint);

    // Cockpit
    paint.color = const Color(0xFF00ffff);
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.35),
      size.width * 0.15,
      paint,
    );

    // Engine glow
    paint.color = const Color(0xFFff6600);
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.92),
        width: size.width * 0.3,
        height: size.height * 0.15,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Enemy painter
class EnemyPainter extends CustomPainter {
  final int type;
  EnemyPainter({required this.type});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    switch (type) {
      case 0: // Red triangle enemy
        paint.color = const Color(0xFFff3333);
        final path = Path();
        path.moveTo(size.width / 2, size.height * 0.8);
        path.lineTo(size.width * 0.2, size.height * 0.2);
        path.lineTo(size.width * 0.8, size.height * 0.2);
        path.close();
        canvas.drawPath(path, paint);

        paint.color = const Color(0xFFff6666);
        canvas.drawCircle(Offset(size.width / 2, size.height * 0.4),
            size.width * 0.15, paint);
        break;

      case 1: // Purple diamond enemy
        paint.color = const Color(0xFFaa33ff);
        final path2 = Path();
        path2.moveTo(size.width / 2, size.height * 0.1);
        path2.lineTo(size.width * 0.8, size.height / 2);
        path2.lineTo(size.width / 2, size.height * 0.9);
        path2.lineTo(size.width * 0.2, size.height / 2);
        path2.close();
        canvas.drawPath(path2, paint);
        break;

      case 2: // Orange circle enemy
        paint.shader = RadialGradient(
          colors: [const Color(0xFFffaa00), const Color(0xFFff6600)],
        ).createShader(Rect.fromCircle(
            center: Offset(size.width / 2, size.height / 2),
            radius: size.width / 2));
        canvas.drawCircle(
            Offset(size.width / 2, size.height / 2), size.width * 0.4, paint);

        paint.shader = null;
        paint.color = const Color(0xFFff8800);
        canvas.drawCircle(Offset(size.width * 0.35, size.height * 0.4),
            size.width * 0.1, paint);
        canvas.drawCircle(Offset(size.width * 0.65, size.height * 0.4),
            size.width * 0.1, paint);
        break;
    }

    // Glow effect
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    paint.color = paint.color.withOpacity(0.3);
    canvas.drawCircle(
        Offset(size.width / 2, size.height / 2), size.width * 0.5, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Game objects
class Bullet {
  double x;
  double y;
  double velocityY;
  bool isEnemy;

  Bullet(
      {required this.x,
      required this.y,
      required this.velocityY,
      required this.isEnemy});
}

class Enemy {
  double x;
  double y;
  double velocityY;
  int type;

  Enemy(
      {required this.x,
      required this.y,
      required this.velocityY,
      required this.type});
}

class Star {
  double x;
  double y;
  double size;

  Star({required this.x, required this.y, required this.size});
}
