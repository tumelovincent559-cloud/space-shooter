// fixed_space_shooter.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const SpaceShooterApp());
}

class SpaceShooterApp extends StatelessWidget {
  const SpaceShooterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Space Shooter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  GameState gameState = GameState.menu;
  int score = 0;
  int highScore = 0;
  int wave = 1;
  List<String> achievements = [];
  String? newAchievement;

  Player? player;
  List<Bullet> bullets = [];
  List<Enemy> enemies = [];
  List<Particle> particles = [];
  List<Star> stars = [];
  List<PowerUp> powerUps = [];
  Boss? boss;

  Timer? gameTimer;
  int enemySpawnTimer = 0;
  int enemiesInWave = 5;
  int enemiesKilled = 0;
  int killStreak = 0;
  int comboTimer = 0;
  double screenShake = 0;
  Set<String> unlockedAchievements = {};

  Set<LogicalKeyboardKey> pressedKeys = {};

  // dynamic screen size (set after layout)
  double screenWidth = 0;
  double screenHeight = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Size s = MediaQuery.of(context).size;
    // set once (or when changed)
    screenWidth = s.width;
    screenHeight = s.height;
    // initialize stars with real screen size if empty
    if (stars.isEmpty) initStars();
  }

  void initStars() {
    stars.clear();
    final rnd = Random();
    for (int i = 0; i < 100; i++) {
      stars.add(Star(
        x: rnd.nextDouble() * screenWidth,
        y: rnd.nextDouble() * screenHeight,
        size: rnd.nextDouble() * 2 + 0.8,
        speed: rnd.nextDouble() * 2 + 0.2,
      ));
    }
  }

  void startGame() {
    setState(() {
      gameState = GameState.playing;
      score = 0;
      wave = 1;
      enemiesKilled = 0;
      enemiesInWave = 5;
      killStreak = 0;

      // position player relative to screen
      final px = (screenWidth / 2) - 20;
      final py = screenHeight - 120;
      player = Player(px, py, screenWidth, screenHeight);

      bullets.clear();
      enemies.clear();
      particles.clear();
      powerUps.clear();
      boss = null;

      // (re-)create stars for current size
      initStars();

      gameTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
        updateGame();
      });
    });
  }

  void updateGame() {
    if (gameState != GameState.playing) return;

    setState(() {
      // Update player
      player!.update(pressedKeys);

      // Update bullets
      bullets.removeWhere((b) {
        b.update();
        return b.y + b.height < 0;
      });

      // Update stars
      for (var star in stars) {
        star.y += star.speed;
        if (star.y > screenHeight) {
          star.y = 0;
          star.x = Random().nextDouble() * screenWidth;
        }
      }

      // Update particles
      particles.removeWhere((p) {
        p.update();
        return p.life <= 0;
      });

      // Spawn enemies
      if (boss == null) {
        enemySpawnTimer++;
        if (enemySpawnTimer > max(30, 60 - wave * 3) &&
            enemiesKilled < enemiesInWave) {
          enemySpawnTimer = 0;
          enemies.add(Enemy(
            x: Random().nextDouble() * max(1, screenWidth - 40),
            y: -40,
            health: 1 + (wave ~/ 3),
            speed: Random().nextDouble() * 2 + 1 + wave * 0.2,
            pattern: Random().nextInt(3),
          ));
        }
      }

      // Update enemies
      enemies.removeWhere((e) {
        e.update();

        // Check bullet collision
        for (int i = bullets.length - 1; i >= 0; i--) {
          if (checkCollision(bullets[i], e)) {
            e.health--;
            bullets.removeAt(i);
            createExplosion(
                e.x + e.width / 2, e.y + e.height / 2, Colors.cyan, 8);

            if (e.health <= 0) {
              createExplosion(
                  e.x + e.width / 2, e.y + e.height / 2, Colors.red, 16);
              score += 10;
              enemiesKilled++;
              killStreak++;
              comboTimer = 120;

              checkAchievement('first', 'First Blood', enemiesKilled == 1);
              checkAchievement('streak5', 'Hot Streak!', killStreak == 5);
              checkAchievement('streak10', 'Unstoppable!', killStreak == 10);
              checkAchievement('score100', 'Centurion', score >= 100);

              if (Random().nextDouble() < 0.2) {
                spawnPowerUp(e.x + e.width / 2, e.y + e.height / 2);
              }

              return true;
            }
          }
        }

        // Check player collision
        if (checkCollision(player!, e) && !e.isBossBullet) {
          if (player!.shield) {
            player!.shield = false;
            createExplosion(
                e.x + e.width / 2, e.y + e.height / 2, Colors.cyan, 12);
          } else {
            player!.health--;
            createExplosion(
                e.x + e.width / 2, e.y + e.height / 2, Colors.red, 18);
            screenShake = 10;

            if (player!.health <= 0) {
              gameOver();
            }
          }
          return true;
        }

        return e.y > screenHeight + 50;
      });

      // Update powerups
      powerUps.removeWhere((p) {
        p.y += 2;

        if (checkCollision(player!, p)) {
          applyPowerUp(p.type);
          createExplosion(
              p.x + p.width / 2, p.y + p.height / 2, p.getColor(), 8);
          return true;
        }

        return p.y > screenHeight + 50;
      });

      // Boss logic
      if (boss != null) {
        boss!.update();

        if (boss!.shootTimer <= 0) {
          boss!.shootTimer = 60;
          for (int i = 0; i < 3; i++) {
            enemies.add(Enemy(
              x: boss!.x + i * 40,
              y: boss!.y + 60,
              health: 1,
              speed: 4,
              pattern: 0,
              isBossBullet: true,
            ));
          }
        }

        // Check bullet collision with boss
        bullets.removeWhere((b) {
          if (checkCollision(b, boss!)) {
            boss!.health--;
            createExplosion(b.x, b.y, Colors.cyan, 10);

            if (boss!.health <= 0) {
              createExplosion(boss!.x + boss!.width / 2,
                  boss!.y + boss!.height / 2, Colors.purple, 40);
              score += 100;
              boss = null;
              enemiesInWave = 5 + wave * 2;
              spawnPowerUp(screenWidth / 2, screenHeight / 2);
              screenShake = 20;
              checkAchievement('boss1', 'Boss Slayer', true);
            }
            return true;
          }
          return false;
        });
      }

      // Wave progression
      if (boss == null && enemiesKilled >= enemiesInWave && enemies.isEmpty) {
        wave++;
        enemiesKilled = 0;

        if (wave % 3 == 0) {
          spawnBoss();
        } else {
          enemiesInWave = 5 + wave * 2;
        }
      }

      // Combo timer
      if (comboTimer > 0) {
        comboTimer--;
      } else if (killStreak > 0) {
        killStreak = 0;
      }

      // Screen shake
      if (screenShake > 0) screenShake--;
    });
  }

  void spawnBoss() {
    boss = Boss(
      x: max(20, screenWidth / 2 - 60),
      y: 50,
      health: 50 + wave * 20,
    );
  }

  void spawnPowerUp(double x, double y) {
    powerUps.add(PowerUp(
      x: x,
      y: y,
      type: PowerUpType.values[Random().nextInt(PowerUpType.values.length)],
    ));
  }

  void applyPowerUp(PowerUpType type) {
    switch (type) {
      case PowerUpType.health:
        player!.health = min(player!.health + 1, player!.maxHealth);
        break;
      case PowerUpType.shield:
        player!.shield = true;
        player!.shieldTime = 300;
        break;
      case PowerUpType.rapidFire:
        player!.rapidFire = true;
        player!.fireRate = 5;
        Future.delayed(const Duration(seconds: 5), () {
          if (player != null) {
            player!.rapidFire = false;
            player!.fireRate = 10;
          }
        });
        break;
      case PowerUpType.multiShot:
        player!.multiShot = min(player!.multiShot + 1, 3);
        break;
      case PowerUpType.bomb:
        enemies.clear();
        if (boss != null) boss!.health -= 20;
        createExplosion(screenWidth / 2, screenHeight / 2, Colors.orange, 50);
        screenShake = 20;
        break;
    }
  }

  void createExplosion(double x, double y, Color color, int count) {
    for (int i = 0; i < count; i++) {
      particles.add(Particle(
        x: x,
        y: y,
        vx: (Random().nextDouble() - 0.5) * 6,
        vy: (Random().nextDouble() - 0.5) * 6,
        color: color,
        size: Random().nextDouble() * 3 + 1,
      ));
    }
  }

  void checkAchievement(String id, String name, bool condition) {
    if (!unlockedAchievements.contains(id) && condition) {
      unlockedAchievements.add(id);
      setState(() {
        achievements.add(name);
        newAchievement = name;
      });

      Future.delayed(const Duration(seconds: 3), () {
        setState(() {
          newAchievement = null;
        });
      });
    }
  }

  bool checkCollision(GameObject a, GameObject b) {
    return a.x < b.x + b.width &&
        a.x + a.width > b.x &&
        a.y < b.y + b.height &&
        a.y + a.height > b.y;
  }

  void shoot() {
    if (player!.fireRateTimer <= 0) {
      for (int i = 0; i < player!.multiShot; i++) {
        double offsetX = 0;
        if (player!.multiShot == 2) offsetX = i == 0 ? -10 : 10;
        if (player!.multiShot == 3) offsetX = (i - 1) * 10;

        bullets.add(Bullet(
          x: player!.x + (player!.width / 2) - 2 + offsetX,
          y: player!.y,
        ));
      }
      player!.fireRateTimer = player!.fireRate;
    }
  }

  void gameOver() {
    gameTimer?.cancel();
    if (score > highScore) {
      highScore = score;
    }
    setState(() {
      gameState = GameState.gameOver;
    });
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // update screen size in case rotated/resized
    final Size s = MediaQuery.of(context).size;
    screenWidth = s.width;
    screenHeight = s.height;

    return Scaffold(
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            pressedKeys.add(event.logicalKey);
            if (event.logicalKey == LogicalKeyboardKey.space &&
                gameState == GameState.playing) {
              shoot();
            }
          } else if (event is KeyUpEvent) {
            pressedKeys.remove(event.logicalKey);
          }
          return KeyEventResult.handled;
        },
        child: Stack(
          children: [
            // background + game canvas
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                // simple tap to shoot on mobile
                if (gameState == GameState.playing) shoot();
              },
              child: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF0a0e27),
                      Color(0xFF1a1a2e),
                      Color(0xFF16213e)
                    ],
                  ),
                ),
                child: gameState == GameState.playing && player != null
                    ? GameCanvas(
                        player: player!,
                        bullets: bullets,
                        enemies: enemies,
                        particles: particles,
                        stars: stars,
                        powerUps: powerUps,
                        boss: boss,
                        score: score,
                        wave: wave,
                        killStreak: killStreak,
                        screenShake: screenShake,
                      )
                    : Container(),
              ),
            ),

            // overlays
            if (gameState == GameState.menu)
              MenuOverlay(
                highScore: highScore,
                achievements: achievements,
                onStart: startGame,
              ),
            if (gameState == GameState.gameOver)
              GameOverOverlay(
                score: score,
                wave: wave,
                highScore: highScore,
                achievements: achievements,
                onRestart: startGame,
                onMenu: () => setState(() => gameState = GameState.menu),
              ),
            if (newAchievement != null)
              AchievementNotification(text: newAchievement!),
          ],
        ),
      ),
    );
  }
}

// Game Canvas Widget
class GameCanvas extends StatelessWidget {
  final Player player;
  final List<Bullet> bullets;
  final List<Enemy> enemies;
  final List<Particle> particles;
  final List<Star> stars;
  final List<PowerUp> powerUps;
  final Boss? boss;
  final int score;
  final int wave;
  final int killStreak;
  final double screenShake;

  const GameCanvas({
    super.key,
    required this.player,
    required this.bullets,
    required this.enemies,
    required this.particles,
    required this.stars,
    required this.powerUps,
    this.boss,
    required this.score,
    required this.wave,
    required this.killStreak,
    required this.screenShake,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(
        (Random().nextDouble() - 0.5) * screenShake,
        (Random().nextDouble() - 0.5) * screenShake,
      ),
      // SizedBox.expand ensures the painter gets the actual available size
      child: SizedBox.expand(
        child: CustomPaint(
          painter: GamePainter(
            player: player,
            bullets: bullets,
            enemies: enemies,
            particles: particles,
            stars: stars,
            powerUps: powerUps,
            boss: boss,
            score: score,
            wave: wave,
            killStreak: killStreak,
          ),
        ),
      ),
    );
  }
}

// Game Painter
class GamePainter extends CustomPainter {
  final Player player;
  final List<Bullet> bullets;
  final List<Enemy> enemies;
  final List<Particle> particles;
  final List<Star> stars;
  final List<PowerUp> powerUps;
  final Boss? boss;
  final int score;
  final int wave;
  final int killStreak;

  GamePainter({
    required this.player,
    required this.bullets,
    required this.enemies,
    required this.particles,
    required this.stars,
    required this.powerUps,
    this.boss,
    required this.score,
    required this.wave,
    required this.killStreak,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw stars
    for (var star in stars) {
      canvas.drawCircle(
        Offset(star.x, star.y),
        star.size,
        Paint()..color = Colors.white.withOpacity(0.8),
      );
    }

    // Draw particles
    for (var particle in particles) {
      canvas.drawCircle(
        Offset(particle.x, particle.y),
        particle.size,
        Paint()..color = particle.color.withOpacity(particle.life),
      );
    }

    // Draw power-ups
    for (var powerUp in powerUps) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(powerUp.x, powerUp.y, powerUp.width, powerUp.height),
          const Radius.circular(8),
        ),
        Paint()
          ..color = powerUp.getColor()
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );

      TextPainter tp = TextPainter(
        text: TextSpan(
          text: powerUp.getIcon(),
          style: const TextStyle(
              color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(powerUp.x + 8, powerUp.y + 5));
    }

    // Draw bullets
    for (var bullet in bullets) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(bullet.x, bullet.y, bullet.width, bullet.height),
          const Radius.circular(4),
        ),
        Paint()
          ..color = Colors.cyan
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    // Draw enemies
    for (var enemy in enemies) {
      if (enemy.isBossBullet) {
        canvas.drawCircle(
          Offset(enemy.x, enemy.y),
          8,
          Paint()
            ..color = Colors.purple
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(enemy.x, enemy.y, enemy.width, enemy.height),
            const Radius.circular(5),
          ),
          Paint()
            ..color = enemy.health > 1 ? Colors.orange : Colors.red
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
        );
      }
    }

    // Draw boss
    if (boss != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(boss!.x, boss!.y, boss!.width, boss!.height),
          const Radius.circular(10),
        ),
        Paint()
          ..color = Colors.purple
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15),
      );

      // Boss health bar
      canvas.drawRect(
        Rect.fromLTWH(boss!.x, boss!.y - 10, boss!.width, 5),
        Paint()..color = Colors.red,
      );
      canvas.drawRect(
        Rect.fromLTWH(boss!.x, boss!.y - 10,
            boss!.width * (boss!.health / boss!.maxHealth), 5),
        Paint()..color = Colors.green,
      );
    }

    // Draw player (triangle)
    Path playerPath = Path();
    playerPath.moveTo(player.x + player.width / 2, player.y);
    playerPath.lineTo(player.x, player.y + player.height);
    playerPath.lineTo(
        player.x + player.width / 2, player.y + player.height - 10);
    playerPath.lineTo(player.x + player.width, player.y + player.height);
    playerPath.close();

    canvas.drawPath(
      playerPath,
      Paint()
        ..color = player.rapidFire ? Colors.yellow : Colors.cyan
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15),
    );

    if (player.shield) {
      canvas.drawCircle(
        Offset(player.x + player.width / 2, player.y + player.height / 2),
        30,
        Paint()
          ..color = Colors.cyan.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }

    // Draw UI
    TextPainter scoreText = TextPainter(
      text: TextSpan(
        text: 'Score: $score',
        style: const TextStyle(
            color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    scoreText.layout();
    scoreText.paint(canvas, const Offset(10, 30));

    TextPainter waveText = TextPainter(
      text: TextSpan(
        text: 'Wave: $wave',
        style: const TextStyle(
            color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    waveText.layout();
    waveText.paint(canvas, const Offset(10, 60));

    // Health bar
    canvas.drawRect(
      const Rect.fromLTWH(10, 90, 150, 20),
      Paint()..color = Colors.red,
    );
    canvas.drawRect(
      Rect.fromLTWH(10, 90, 150 * (player.health / player.maxHealth), 20),
      Paint()..color = Colors.green,
    );

    // Combo
    if (killStreak > 1) {
      TextPainter comboText = TextPainter(
        text: TextSpan(
          text: '${killStreak}x COMBO!',
          style: TextStyle(
            color: killStreak >= 10
                ? Colors.purple
                : killStreak >= 5
                    ? Colors.yellow
                    : Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      comboText.layout();
      comboText.paint(canvas, Offset(size.width - 150, 30));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Menu Overlay
class MenuOverlay extends StatelessWidget {
  final int highScore;
  final List<String> achievements;
  final VoidCallback onStart;

  const MenuOverlay(
      {super.key,
      required this.highScore,
      required this.achievements,
      required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.6),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Colors.cyan, Colors.purple],
              ).createShader(bounds),
              child: const Text(
                'SPACE SHOOTER',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 36),
            ElevatedButton(
              onPressed: onStart,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('START GAME',
                  style: TextStyle(fontSize: 20, color: Colors.white)),
            ),
            const SizedBox(height: 20),
            const Text('Tap: Shoot (mobile)',
                style: TextStyle(color: Colors.cyan, fontSize: 16)),
            const SizedBox(height: 10),
            Text('High Score: $highScore',
                style: const TextStyle(color: Colors.yellow, fontSize: 18)),
          ],
        ),
      ),
    );
  }
}

// Game Over Overlay
class GameOverOverlay extends StatelessWidget {
  final int score;
  final int wave;
  final int highScore;
  final List<String> achievements;
  final VoidCallback onRestart;
  final VoidCallback onMenu;

  const GameOverOverlay({
    super.key,
    required this.score,
    required this.wave,
    required this.highScore,
    required this.achievements,
    required this.onRestart,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('GAME OVER',
                style: TextStyle(
                    fontSize: 46,
                    color: Colors.red,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Text('Score: $score',
                style: const TextStyle(fontSize: 24, color: Colors.white)),
            Text('Wave: $wave',
                style: const TextStyle(fontSize: 20, color: Colors.cyan)),
            Text('High Score: $highScore',
                style: const TextStyle(fontSize: 20, color: Colors.yellow)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onRestart,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding:
                    const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
              ),
              child: const Text('PLAY AGAIN',
                  style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: onMenu,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
              ),
              child: const Text('MAIN MENU',
                  style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// Achievement Notification
class AchievementNotification extends StatelessWidget {
  final String text;

  const AchievementNotification({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 50,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient:
              const LinearGradient(colors: [Colors.yellow, Colors.orange]),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Colors.orange, blurRadius: 20)],
        ),
        child: Column(
          children: [
            const Text('🏆 ACHIEVEMENT!',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            Text(text,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// Game Models
enum GameState { menu, playing, gameOver }

enum PowerUpType { health, shield, rapidFire, multiShot, bomb }

class GameObject {
  double x, y, width, height;
  GameObject(this.x, this.y, this.width, this.height);
}

class Player extends GameObject {
  int health = 3;
  int maxHealth = 3;
  bool shield = false;
  int shieldTime = 0;
  int fireRate = 10;
  int fireRateTimer = 0;
  int multiShot = 1;
  bool rapidFire = false;
  double speed = 8;

  // provide screen bounds to clamp movement
  double screenWidth;
  double screenHeight;

  Player(double x, double y, this.screenWidth, this.screenHeight)
      : super(x, y, 40, 40);

  void update(Set<LogicalKeyboardKey> keys) {
    if (keys.contains(LogicalKeyboardKey.arrowLeft) && x > 0) x -= speed;
    if (keys.contains(LogicalKeyboardKey.arrowRight) && x < screenWidth - width)
      x += speed;
    if (keys.contains(LogicalKeyboardKey.arrowUp) && y > 0) y -= speed;
    if (keys.contains(LogicalKeyboardKey.arrowDown) &&
        y < screenHeight - height) y += speed;

    // ensure within bounds
    x = x.clamp(0.0, screenWidth - width);
    y = y.clamp(0.0, screenHeight - height);

    if (fireRateTimer > 0) fireRateTimer--;
    if (shield && shieldTime > 0) {
      shieldTime--;
      if (shieldTime <= 0) shield = false;
    }
  }
}

class Bullet extends GameObject {
  double speed = 12;

  Bullet({required double x, required double y}) : super(x, y, 4, 15);

  void update() {
    y -= speed;
  }
}

class Enemy extends GameObject {
  int health;
  int maxHealth;
  double speed;
  int pattern;
  bool isBossBullet;

  Enemy({
    required double x,
    required double y,
    required this.health,
    required this.speed,
    required this.pattern,
    this.isBossBullet = false,
  })  : maxHealth = health,
        super(x, y, 40, 40);

  void update() {
    if (!isBossBullet) {
      if (pattern == 1) {
        x += sin(y * 0.05) * 2;
      } else if (pattern == 2) {
        x += cos(y * 0.03) * 3;
      }
    }
    y += speed;
  }
}

class Boss extends GameObject {
  int health;
  int maxHealth;
  double speed = 2;
  int direction = 1;
  int shootTimer = 60;

  Boss({required double x, required double y, required this.health})
      : maxHealth = health,
        super(x, y, 120, 80);

  void update() {
    x += speed * direction;
    if (x <= 0 || x >= 280) direction *= -1;
    shootTimer--;
  }
}

class Particle {
  double x, y, vx, vy, size;
  Color color;
  double life = 1.0;

  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
  });

  void update() {
    x += vx;
    y += vy;
    life -= 0.02;
  }
}

class Star {
  double x, y, size, speed;

  Star(
      {required this.x,
      required this.y,
      required this.size,
      required this.speed});
}

class PowerUp extends GameObject {
  PowerUpType type;

  PowerUp({required double x, required double y, required this.type})
      : super(x, y, 30, 30);

  Color getColor() {
    switch (type) {
      case PowerUpType.health:
        return Colors.green;
      case PowerUpType.shield:
        return Colors.cyan;
      case PowerUpType.rapidFire:
        return Colors.yellow;
      case PowerUpType.multiShot:
        return Colors.purple;
      case PowerUpType.bomb:
        return Colors.red;
    }
  }

  String getIcon() {
    switch (type) {
      case PowerUpType.health:
        return '+';
      case PowerUpType.shield:
        return 'S';
      case PowerUpType.rapidFire:
        return 'R';
      case PowerUpType.multiShot:
        return 'M';
      case PowerUpType.bomb:
        return 'B';
    }
  }
}
