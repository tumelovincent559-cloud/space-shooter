import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

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
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  GameState gameState = GameState.menu;

  late double dpiScale;
  Player? player;

  List<Bullet> bullets = [];
  List<Enemy> enemies = [];
  List<Particle> particles = [];
  List<Star> stars = [];
  List<PowerUp> powerUps = [];
  Boss? boss;

  int score = 0;
  int highScore = 0;
  int wave = 1;

  Timer? loop;
  int spawnTimer = 0;
  int enemiesKilled = 0;
  int enemiesInWave = 5;

  double joystickX = 0;
  double joystickY = 0;
  bool isTouchingJoystick = false;
  bool isPressingShoot = false;

  @override
  void initState() {
    super.initState();
    initStars();
  }

  void initStars() {
    for (int i = 0; i < 100; i++) {
      stars.add(Star(
        x: Random().nextDouble() * 400,
        y: Random().nextDouble() * 800,
        size: Random().nextDouble() * 2 + 1,
        speed: Random().nextDouble() * 2 + 0.5,
      ));
    }
  }

  Future<void> startGame() async {
    final size = MediaQuery.of(context).size;
    dpiScale = size.height / 800;

    await loadAssets();

    player = Player(size.width / 2 - 20, size.height - 140, dpiScale);
    bullets.clear();
    enemies.clear();
    particles.clear();
    powerUps.clear();
    boss = null;

    score = 0;
    wave = 1;
    enemiesKilled = 0;
    enemiesInWave = 5;

    loop?.cancel();
    loop = Timer.periodic(const Duration(milliseconds: 16), (_) => update());

    setState(() => gameState = GameState.playing);
  }

  void update() {
    if (gameState != GameState.playing) return;

    setState(() {
      if (isTouchingJoystick) player!.moveFromJoystick(joystickX, joystickY);
      player!.update();
      if (isPressingShoot) shoot();

      bullets.removeWhere((b) => b.update());

      for (var s in stars) {
        s.y += s.speed;
        if (s.y > 900) {
          s.y = 0;
          s.x = Random().nextDouble() * 400;
        }
      }

      spawnTimer++;
      if (spawnTimer > max(25, 60 - wave * 2) &&
          enemiesKilled < enemiesInWave) {
        spawnTimer = 0;
        enemies.add(Enemy.spawnRandom(dpiScale));
      }

      enemies.removeWhere((e) => e.update(player!, bullets, this));

      powerUps.removeWhere((p) => p.update(player!, this));

      boss?.update(enemies, dpiScale);

      if (boss == null && enemiesKilled >= enemiesInWave && enemies.isEmpty) {
        wave++;
        enemiesKilled = 0;
        enemiesInWave += 4;
      }
    });
  }

  void shoot() {
    if (player!.canShoot()) bullets.addAll(player!.shoot());
  }

  void gameOver() {
    loop?.cancel();
    highScore = max(highScore, score);
    setState(() => gameState = GameState.gameOver);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (gameState == GameState.playing)
            GameCanvas(
              player: player!,
              bullets: bullets,
              enemies: enemies,
              stars: stars,
              particles: particles,
              powerUps: powerUps,
              boss: boss,
              score: score,
              wave: wave,
            ),
          if (gameState == GameState.menu)
            Center(
              child: ElevatedButton(
                onPressed: startGame,
                child: const Text("START"),
              ),
            ),
          if (gameState == GameState.gameOver)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("GAME OVER", style: TextStyle(fontSize: 40)),
                  Text("Score: $score"),
                  ElevatedButton(
                    onPressed: startGame,
                    child: const Text("RESTART"),
                  ),
                ],
              ),
            ),
          if (gameState == GameState.playing) buildTouchControls(),
        ],
      ),
    );
  }

  Widget buildTouchControls() {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            left: 20,
            bottom: 40,
            child: GestureDetector(
              onPanStart: (_) => isTouchingJoystick = true,
              onPanUpdate: (d) {
                joystickX = (d.localPosition.dx - 40) / 40;
                joystickY = (d.localPosition.dy - 40) / 40;
                joystickX = joystickX.clamp(-1, 1);
                joystickY = joystickY.clamp(-1, 1);
              },
              onPanEnd: (_) {
                isTouchingJoystick = false;
                joystickX = joystickY = 0;
              },
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white38, width: 2),
                ),
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: 70,
            child: GestureDetector(
              onTapDown: (_) => isPressingShoot = true,
              onTapUp: (_) => isPressingShoot = false,
              onTapCancel: () => isPressingShoot = false,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(color: Colors.red, blurRadius: 20)
                  ],
                ),
                child: const Icon(Icons.bolt, color: Colors.white, size: 40),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------- GAME OBJECTS --------------------

enum GameState { menu, playing, gameOver }

abstract class GameObject {
  double x, y, w, h;
  GameObject(this.x, this.y, this.w, this.h);
}

class Player extends GameObject {
  int hp = 3;
  int fireCooldown = 0;
  double speed;
  final double dpi;

  Player(double x, double y, this.dpi)
      : speed = 7 * dpi,
        super(x, y, 50 * dpi, 50 * dpi);

  void update() {
    if (fireCooldown > 0) fireCooldown--;
  }

  void moveFromJoystick(double jx, double jy) {
    x += jx * speed;
    y += jy * speed;
  }

  bool canShoot() => fireCooldown <= 0;

  List<Bullet> shoot() {
    fireCooldown = 10;
    return [Bullet(x + w / 2 - 3, y - 10, dpi)];
  }
}

class Bullet extends GameObject {
  final double speed;
  Bullet(double x, double y, double dpi)
      : speed = 14 * dpi,
        super(x, y, 6 * dpi, 18 * dpi);

  bool update() {
    y -= speed;
    return y < -20;
  }
}

class Enemy extends GameObject {
  int hp;
  double speed;

  Enemy(double x, double y, this.hp, this.speed, double dpi)
      : super(x, y, 40 * dpi, 40 * dpi);

  static Enemy spawnRandom(double dpi) {
    return Enemy(
      Random().nextDouble() * 300,
      -40,
      1,
      (2 + Random().nextDouble() * 2) * dpi,
      dpi,
    );
  }

  bool update(Player player, List<Bullet> bullets, _GameScreenState game) {
    y += speed;

    for (int i = bullets.length - 1; i >= 0; i--) {
      var b = bullets[i];
      if (rectOverlap(b, this)) {
        bullets.removeAt(i);
        hp--;
        game.score += 10;
        if (hp <= 0) {
          game.enemiesKilled++;
          return true;
        }
      }
    }

    if (rectOverlap(player, this)) {
      player.hp--;
      if (player.hp <= 0) game.gameOver();
      return true;
    }

    return y > 1000;
  }
}

class PowerUp extends GameObject {
  final double speed;

  PowerUp(double x, double y, double dpi)
      : speed = 2 * dpi,
        super(x, y, 30 * dpi, 30 * dpi);

  bool update(Player player, _GameScreenState game) {
    y += speed;
    if (rectOverlap(player, this)) {
      player.hp = min(player.hp + 1, 5);
      return true;
    }
    return y > 1000;
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

class Particle {
  double x, y, size, speed;
  Particle(
      {required this.x,
      required this.y,
      required this.size,
      required this.speed});
  bool update() {
    y += speed;
    return y > 1000;
  }
}

class Boss {
  double x = 100, y = -100, w = 80, h = 80;
  void update(List<Enemy> enemies, double dpi) {
    y += 1 * dpi;
  }
}

bool rectOverlap(GameObject a, GameObject b) {
  return a.x < b.x + b.w &&
      a.x + a.w > b.x &&
      a.y < b.y + b.h &&
      a.h + a.y > b.y;
}

// -------------------- CANVAS --------------------

class GameCanvas extends StatelessWidget {
  final Player player;
  final List<Bullet> bullets;
  final List<Enemy> enemies;
  final List<Star> stars;
  final List<Particle> particles;
  final List<PowerUp> powerUps;
  final Boss? boss;
  final int score;
  final int wave;

  const GameCanvas({
    super.key,
    required this.player,
    required this.bullets,
    required this.enemies,
    required this.stars,
    required this.particles,
    required this.powerUps,
    required this.boss,
    required this.score,
    required this.wave,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _Painter(
        player: player,
        bullets: bullets,
        enemies: enemies,
        stars: stars,
        powerUps: powerUps,
        score: score,
        wave: wave,
      ),
    );
  }
}

class _Painter extends CustomPainter {
  final Player player;
  final List<Bullet> bullets;
  final List<Enemy> enemies;
  final List<Star> stars;
  final List<PowerUp> powerUps;
  final int score;
  final int wave;

  _Painter({
    required this.player,
    required this.bullets,
    required this.enemies,
    required this.stars,
    required this.powerUps,
    required this.score,
    required this.wave,
  });

  @override
  void paint(Canvas c, Size s) {
    final paint = Paint();

    for (var st in stars) {
      c.drawCircle(Offset(st.x, st.y), st.size, paint..color = Colors.white70);
    }

    for (var b in bullets) {
      c.drawRect(Rect.fromLTWH(b.x, b.y, b.w, b.h), paint..color = Colors.cyan);
    }

    for (var e in enemies) {
      c.drawRect(Rect.fromLTWH(e.x, e.y, e.w, e.h), paint..color = Colors.red);
    }

    paint.color = Colors.white;
    c.drawImageRect(
      playerSprite,
      const Rect.fromLTWH(0, 0, 128, 128),
      Rect.fromLTWH(player.x, player.y, player.w, player.h),
      paint,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: "Score: $score\nWave: $wave",
        style: const TextStyle(color: Colors.white, fontSize: 22),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(c, const Offset(10, 20));
  }

  @override
  bool shouldRepaint(_) => true;
}

// -------------------- LOAD SPRITE --------------------

late ui.Image playerSprite;

Future<void> loadAssets() async {
  final bytes = await rootBundle.load('assets/images/player.png');
  final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
  final frame = await codec.getNextFrame();
  playerSprite = frame.image;
}
