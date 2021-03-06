import java.util.Iterator;

// Game state consts
static final int ARENA_BORDER = 32;
static final int ARENA_X = 200 + ARENA_BORDER;
static final int ARENA_Y = ARENA_BORDER;
static final int ARENA_SIZE = WINDOW_HEIGHT - 2*ARENA_BORDER;
static final int ARENA_CENTER_X = ARENA_X + ARENA_SIZE / 2;
static final int ARENA_CENTER_Y = ARENA_Y + ARENA_SIZE / 2;
static final float MIN_SPAWN_DEALY = 2.0f;
static final float MAX_SPAWN_DEALY = 4.0f;
static final int LIVES_PER_ROUND = 2;

class GameState extends State
{
  int round = 1;
  int n_lives = LIVES_PER_ROUND;
  int opponents_left = 0;

  PImage background_image;
  PImage tank_image;
  PImage enemy_image;
  PFont game_font;

  Grid grid;
  Player player;
  Flag flag;
  ArrayList<Enemy> enemies = new ArrayList<Enemy>();
  ArrayList<Shell> shells = new ArrayList<Shell>();
  ArrayList<ScorePopup> score_popups = new ArrayList<ScorePopup>();
  ArrayList<Explosion> explosions = new ArrayList<Explosion>();

  float enemy_spawn_timer = random(MIN_SPAWN_DEALY, MAX_SPAWN_DEALY);
  float game_over_timer = 3f;
  boolean spawn_opponents = true;

  @Override
    void on_start() {
    // Load files
    background_image = loadImage(SPRITES_FOLDER + "Background.png");
    tank_image = loadImage(SPRITES_FOLDER + "PlayerUp.png");
    enemy_image = loadImage(SPRITES_FOLDER + "EnemyUp.png");
    game_font = createFont(FONTS_FOLDER + "RetroGaming.ttf", 48.0);
    game_data.reset_score();

    if (ENABLE_DEBUG_MODE) println("Playing difficulty: " + game_data.difficulty);

    setup_round();
  }

  // Setup the round according the the round variable
  void setup_round() {
    opponents_left = 10 + round * 3;
    n_lives = LIVES_PER_ROUND;
    grid = new Grid(round);
    spawn_player();
    flag = new Flag(ARENA_CENTER_X, ARENA_Y + ARENA_SIZE - ARENA_BORDER);
    enemies.clear();
    physics_manager.cleanup();
  }

  @Override
    void on_input(boolean is_key_down) {
    if(flag.game_over){
      return;
    }
    
    player.input(keyCode, is_key_down);

    if (is_key_down)
    {
      if (keyCode == 'B' && ENABLE_EASTER_EGGS) {
        audio_manager.play_sound("bruh.mp3");
      }
      if (keyCode == DELETE || keyCode == 'K' && ENABLE_DEBUG_MODE)
      {
        // kill all enemies - for debugging purposses
        while (enemies.size() > 0)
        {
          enemies.get(0).die();
          enemies.remove(0); 
          game_data.add_score(10);
          opponents_left--;
        }
      }
      // Toggle physics debug mode
      if ((keyCode == 'P' || keyCode == 'p') && ENABLE_DEBUG_MODE)
      {
        physics_manager.is_debugging = !physics_manager.is_debugging;
      }
      if ((keyCode == 'I' || keyCode == 'i') && ENABLE_DEBUG_MODE)
      {
        spawn_enemy();
      }
      if ((keyCode == 'Y' || keyCode == 'y') && ENABLE_DEBUG_MODE)
      {
        spawn_opponents = !spawn_opponents;
        println("Toggle opponent spawning: " + spawn_opponents);
      }
      if ((keyCode == 'U' || keyCode == 'u') && ENABLE_DEBUG_MODE)
      {
        player.upgrade();
      }
    }
  }

  @Override
    void on_update(float delta_time)
  {
    for (Iterator<Explosion> explosion_it = explosions.iterator(); explosion_it.hasNext(); ) 
    {
      Explosion explosion = explosion_it.next();
      explosion.update(delta_time);
      if (explosion.finished)
      {
        if (explosion.add_score) {
          int min_score = 1;
          int score = 100 + 100 * floor(random(min_score, 15));
          score_popups.add(new ScorePopup(explosion.x, explosion.y, score));
          game_data.add_score(score);
        }
        explosion_it.remove();
      }
    }
    
    if (flag.game_over){
      game_over_timer -= delta_time;
      if(game_over_timer < 0){
        state_manager.switch_state(StateType.GAME_OVER);
      }
      if(explosions.size() == 0){
        flag.white_flag = true;
      }
      return;
    }
    
    // Maybe spawn some new enemies
    if (opponents_left - enemies.size() > 0 && spawn_opponents)
      spawn_enemies(delta_time);

    if (opponents_left <= 0 && enemies.size() == 0)
    {
      round++;
      setup_round();
    }
    
    // Update flag
    flag.update();
    
    for (Iterator<ScorePopup> popup_it = score_popups.iterator(); popup_it.hasNext(); ) 
    {
      ScorePopup popup = popup_it.next();
      popup.update(delta_time);
      if (popup.is_destroyed)
      {
        popup_it.remove();
      }
    }

    // Update enemies
    for (Iterator<Enemy> iterator = enemies.iterator(); iterator.hasNext(); ) {
      Enemy enemy = iterator.next();
      if (enemy.is_dead) {
        opponents_left--;

        iterator.remove();
        continue;
      }
      enemy.update(shells, delta_time, new PVector(player.x, player.y), new PVector(flag.x, flag.y));
    }

    for (Iterator<Shell> iterator = shells.iterator(); iterator.hasNext(); ) {
      Shell shell = iterator.next();
      shell.update(enemies);
      if (shell.is_destroyed) {
        if (shell.hit_from_back)
        {
          player.upgrade();
        }
        if (shell.hit_tank)
        {
          explosions.add(new Explosion(shell.x, shell.y, 1, !shell.hit_player));
        } else if (shell.hit_level) {
          explosions.add(new Explosion(shell.x, shell.y, 0, false));
        } else if (shell.hit_flag) {
          flag.hits++;
          if(flag.hits == 2){
            explosions.add(new Explosion(flag.x, flag.y, 1, false));
            flag.game_over = true;
          }
        }
        iterator.remove();
      }
    }

    // Update player
    if (player.is_dead)
    {
      if (n_lives > 0)
      {
        // Respawn player
        spawn_player();
        n_lives--;
      } else
      {
        state_manager.switch_state(StateType.GAME_OVER);
      }
    } else
    {
      player.update(shells, delta_time);
    }
  }

  void spawn_player()
  {
    player = new Player(ARENA_X + Player.SIZE/2 + 4, ARENA_Y + ARENA_SIZE - Player.SIZE / 2 - 4);
  }

  void spawn_enemies(float delta_time)
  {
    // Spawn an enemy if timer is over
    enemy_spawn_timer -= delta_time;
    if (enemy_spawn_timer < 0) {
      spawn_enemy();
    }
  }

  void spawn_enemy()
  {
    // Check all possible locations for an enemy to spawn
    int step_size = Enemy.SIZE / 8;
    ArrayList<PVector> possibilities = new ArrayList<PVector>();
    for (int x = ARENA_X; x < ARENA_X + ARENA_SIZE; x += step_size) {
      int test_x = x;
      int test_y = ARENA_Y + ARENA_BORDER + 10;
      if (!physics_manager.check_collision(test_x, test_y, Enemy.SIZE, Enemy.SIZE, -1, ALL_LAYERS)) {
        possibilities.add(new PVector(test_x, test_y));
      }
    }
    if (possibilities.size() > 0)
    { 
      // Pick a random possibility
      int random_index = int(random(0, possibilities.size()));
      PVector spawn_pos = possibilities.get(random_index);

      // Spawn a new enemy
      enemy_spawn_timer = random(MIN_SPAWN_DEALY, MAX_SPAWN_DEALY);
      int type_chance =(int)random(0, 100);
      boolean is_rainbow = false;
      boolean is_red = false;
      // 15% chance to be a rainbow tank or red tank
      if (type_chance <= 15) {
        is_rainbow=true;
      } else if (type_chance <= 30) {
        is_red = true;
      }
      TankType type;
      if (is_rainbow)
      {
        type = TankType.RAINBOW;
      } else if (is_red) {
        type = TankType.RED;
      } else {
        type = TankType.NORMAL;
      }
      enemies.add(new Enemy((int)spawn_pos.x, (int)spawn_pos.y, type));
    } else
    {
      println("ERROR: There is not enough room to spawn a new tank!");
    }
  }

  @Override
    void on_draw()
  {
    background(#060606);

    // Draw background
    imageMode(CORNER);
    image(background_image, 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT);

    // Draw the grid
    grid.draw();

    // Draw enemies
    for (Enemy enemy : enemies) {
      enemy.draw();
    }

    // Flag draw
    flag.draw();

    for (Shell shell : shells) {
      shell.draw();
    }

    // Draw the player
    player.draw();

    for (Explosion explosion : explosions) {
      explosion.draw();
    }


    for (ScorePopup popup : score_popups)
    {
      popup.draw();
    }


    physics_manager.draw_debug();

    // Draw the HUD
    draw_hud();
  }

  // Draw the HUD - Heads up display
  void draw_hud() {
    // Draw text settings
    textFont(game_font);
    textSize(24);
    textAlign(LEFT, CENTER);

    // Draw the highscore
    fill(255, 0, 0);
    text("HIGH-", width - 350, 50); 
    text("SCORE", width - 350, 75);
    fill(255);
    text(game_data.high_score, width - 350, 100);

    // Draw the score
    fill(255, 0, 0);
    text("SCORE", width - 350, 150);
    fill(255);
    text(game_data.score, width - 350, 175);

    // Draw the Round
    fill(255, 255, 255);
    text("ROUND " + round, width - 300, height - 100);

    // Draw the lives left
    for (int i = 0; i < n_lives; i++)
    {
      image(tank_image, width - 340 + i * (Player.SIZE + 10), height - 200, Player.SIZE, Player.SIZE);
    }

    // Draw enemies left
    tint(color(64, 232, 240), 255);
    int x = 0;
    int y = 0;
    final float IMAGE_SIZE = Enemy.SIZE / 1.5;
    final int IMAGE_SPACING = 6;
    for (int j = 0; j < opponents_left; j++)
    {
      if (x == 4)
      {
        y++;
        x = 0;
      }
      image(enemy_image, 
        width - 340 - IMAGE_SPACING + x * (IMAGE_SIZE + IMAGE_SPACING), 
        400 + y * (IMAGE_SIZE + IMAGE_SPACING), 
        IMAGE_SIZE, IMAGE_SIZE);
      x++;
    }
    tint(255, 255, 255, 255);
  }
}
