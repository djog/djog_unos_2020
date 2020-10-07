class Shell {
  static final int SIZE = 9;
  int x, y;
  int move_speed = 12;
  PImage shell_sprite;
  boolean up, down, left, right = false;

  public Shell(int tx, int ty, int direction) {
    x = tx;
    y = ty;
    if (direction == 1) {
      up = true;
      y -= Player.SIZE / 2;
    } else if (direction == 2) {
      down = true;
      y += Player.SIZE / 2;
    } else if (direction == 3) {
      left = true;
      x -= Player.SIZE / 2;
    } else if (direction == 4) { 
      right = true;
      x += Player.SIZE / 2;
    }
    shell_sprite = loadImage(SPRITES_FOLDER + "Shell.png");
  }

  void update() {
    if (up) {
      y -= move_speed;
    } else if (down) {
      y += move_speed;
    } else if (left) {
      x -= move_speed;
    } else if (right) {
      x += move_speed;
    }
  }

  void draw() {   
    imageMode(CENTER);
    image(shell_sprite, x, y, SIZE, SIZE);
  }
}
