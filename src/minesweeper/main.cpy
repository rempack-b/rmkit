#include <csignal>
#define true 1
#define false 0

#include "../build/rmkit.h"
#include "assets.h"
#include <chrono>
#include <random>
#include <ctime>

using namespace std

// Randomisation
mt19937 rng(chrono::steady_clock::now().time_since_epoch().count());
inline int rand() {int r = rng(); return abs(r);}

MODE := 1
WON := false
GRID_SIZE := 15
NB_UNOPENED := 0
GAME_STARTED := true
FLAG_SCORE := 0
FIRST_CLICK := 0
NB_BOMBS := 0
START := time(NULL)
END := time(NULL)

void new_game()
void main_menu()
void resize_field(int)

SIZE_BUTTON_FS := 64
class SizeButton: public ui::Button:
  public:
  int n
  SizeButton(int x, y, w, h, n, string t="Back"): n(n), Button(x,y,w,h,t):
    self.textWidget->font_size = SIZE_BUTTON_FS

  void on_mouse_click(input::SynMouseEvent &ev):
    if GRID_SIZE != n:
      resize_field(n)

    new_game()

  void render():
    ui::Button::render()
    self.fb->draw_rect(self.x, self.y, self.w, self.h, BLACK, false /* fill */)



class GameOverDialog: public ui::ConfirmationDialog:
  public:
  ui::MultiText *textWidget
  GameOverDialog(int x, y, w, h): ui::ConfirmationDialog(x, y, w, h):
    self.set_title(string((WON?"You win!" : "You lose!")))
    self.buttons = { "TRY AGAIN", "MAIN MENU" }
    dt := difftime(END, START)
    score := FLAG_SCORE * !WON + WON * 600000 / dt
    score = round(score*100)/100
    text := "Time: " + to_string(int(dt)/60) + "m " + to_string(int(dt)%60) + "s\nDefused bombs: " + (WON? to_string(NB_BOMBS) : to_string(FLAG_SCORE/50)) + "/" + to_string(NB_BOMBS) + "\nScore: "+to_string(score)
    self.textWidget = new ui::MultiText(20, 20, self.w, self.h - 100, text)
    self.contentWidget = self.textWidget

  void on_button_selected(string text):
    if text == "TRY AGAIN":
      ui::MainLoop::hide_overlay()
      GAME_STARTED = false
      new_game() // TEMPORARY
    if text == "MAIN MENU":
      ui::MainLoop::hide_overlay()
      GAME_STARTED = false
      main_menu()


template<class T>
class Cell: public ui::Widget:
  public:
  T *grid
  int i, j
  bool flagged = false, is_bomb = 0, opened = 0, question = 0
  string neighbors = "0"
  ui::Text* textWidget

  Cell(int x, y, w, h, T *g, int i, j): grid(g), i(i), j(j), Widget(x, y, w, h):
    self.textWidget = new ui::Text(x, y, w, h, "")
    self.textWidget->justify = ui::Text::JUSTIFY::CENTER

  void reset():
    self.flagged = 0
    self.is_bomb = 0
    self.opened = 0
    self.neighbors = "0"

  void render():
    self.undraw()
    color := BLACK
    fill := 0
    if self.is_bomb && self.opened:
      color = WHITE
      fill = 1
    else if !self.is_bomb && self.opened:
      color = GRAY
      fill = 1
    else if self.flagged && !self.opened:
      color = WHITE
      fill =  1
    self.fb->draw_rect(self.x, self.y, self.w, self.h, color, fill)

    self.textWidget->text = self.neighbors
    // we need to turn int -> string here for self.neighbors
    text_width, text_height := self.textWidget->get_render_size()
    padding_y := (self.h - text_height) / 2 + text_height / 4
    if padding_y < 0:
      padding_y = 0

    self.textWidget->x = self.x
    self.textWidget->y = self.y + padding_y

    if self.opened && self.neighbors[0]-'0' > 0 && !self.is_bomb:
      self.textWidget->render()

    if opened && self.is_bomb && !self.flagged:
      pixmap := ui::Pixmap(self.x+5, self.y+5, self.w-10, self.h-10, ICON(assets::bomb_solid_png))
      pixmap.render()

    if self.flagged && !opened:
      pixmap := ui::Pixmap(self.x+5, self.y+5, self.w-20, self.h-20, ICON(assets::flag_solid_png))
      pixmap.render()

    if self.flagged && opened && self.is_bomb:
      pixmap := ui::Pixmap(self.x+5, self.y+5, self.w-10, self.h-10, ICON(assets::flag_bomb_solid_png))
      pixmap.render()
    if self.question && !opened:
      pixmap := ui::Pixmap(self.x+5, self.y+5, self.w-10, self.h-10, ICON(assets::question_solid_png))
      pixmap.render()


  void on_mouse_click(input::SynMouseEvent &ev):
    if MODE == 1
      grid->open_cell(self.i, self.j)
    else if MODE == 0
      grid->toggle_flag_cell(self.i, self.j)
    else grid->toggle_question_cell(self.i, self.j)

class Grid: public ui::Widget:
  public:
  vector<vector<Cell<Grid>*>> cells
  shared_ptr<GameOverDialog> gd
  int n
  Grid(int x, y, w, h, n): n(n), Widget(x, y, w, h):
    pass

  void flood(int i, int j):
    queue<pair<int,int>> qe
    qe.push({i,j})
    while (qe.size()):
      t := qe.front()
      qe.pop()
      if min(t.first,t.second) < 0 || max(t.first,t.second) >= n || cells[t.first][t.second]->opened || cells[t.first][t.second]->is_bomb:
        continue
      cells[t.first][t.second]->opened = 1
      NB_UNOPENED--
      print NB_UNOPENED
      if cells[t.first][t.second]->neighbors[0]-'0'
        continue
      for int f = -1; f <= 1; f++:
        for int g = -1; g <= 1; g++:
          qe.push({t.first+f,t.second+g})

  void open_cell(int row, col):
    if cells[row][col]->opened:
      return
    print "OPENING CELL", row, col
    if cells[row][col]->is_bomb:
      cells[row][col]->opened = 1
      END = time(NULL)
      end_game(0)
    if FIRST_CLICK:
      START = time(NULL)
      FIRST_CLICK = 0
      for int i = 0; i < n; i++
        for int j = 0; j < n; j++:
          if abs(j - col) <= 1 && abs(i - row) <= 1:
            NB_UNOPENED++
            continue
          int temp = rand()%100
          if temp < 15:
            cells[i][j]->is_bomb = 1
            NB_BOMBS++
            for int  f = -1; f <= 1; f++:
              for int g = -1; g <= 1; g++:
                if min(i+f,j+g) < 0 || max(i+f,j+g) >= n:
                  continue
                cells[i+f][j+g]->neighbors[0]++
          else:
            NB_UNOPENED++
    flood(row, col)
    if !NB_UNOPENED && WON:
      END = time(NULL)
      end_game(1)

  void toggle_flag_cell(int row, col):
    cells[row][col]->flagged ^= 1
    if cells[row][col]->flagged
      cells[row][col]->question = 0
    if cells[row][col]->flagged && cells[row][col]->is_bomb:
      FLAG_SCORE += 50
    else if cells[row][col]->is_bomb:
      FLAG_SCORE -= 50
    print "FLAGGED CELL", row, col, cells[row][col]->flagged

  void toggle_question_cell(int row, col):
    cells[row][col]->question ^= 1
    if cells[row][col]->question
      cells[row][col]->flagged = 0

    print "DOUBT CELL", row, col

  void make_cells(ui::Scene s):
    cells = vector<vector<Cell<Grid>*>> (n, vector<Cell<Grid>*>(n))
    jump := w/(n + 1)
    remainder := (w - jump * n) / (n + 1)

    for (int i = 0; i < n; i++)
      for (int j = 0; j < n; j++)
        cells[i][j] = new Cell<Grid>(
          x + jump * j + remainder * (j + 1) + 2 + 7 * (n == 20),
          y + jump * i + remainder * (i + 1) + 2 + 7 * (n == 20),
          jump,
          jump,
          self,
          i,
          j)
        s->add(cells[i][j])

  void end_game(bool win):
    WON = win
    print WON
    self.gd = make_shared<GameOverDialog>(0, 0, 800, 800)
    if !win:
      for int i = 0; i < n; i++:
        for int j = 0; j < n; j++:
          open_cell(i, j)
    gd->show()

  void render():
    self.fb->draw_rect(self.x, self.y, self.w, self.h, BLACK, false /* fill */)

  void on_mouse_click(input::SynMouseEvent &ev):
    print "CLICKED IN GRID"

class MenuButton: public ui::Button:
  public:
  MenuButton(int x, y, w, h, string t="Back"): Button(x,y,w,h,t):
    pass

  void on_mouse_click(input::SynMouseEvent &ev):
    main_menu()

class RadioButton: public ui::Button:
  public:
  string option
  string *selected = NULL
  RadioButton(int x, y, w, h, string t): Button(x, y, w, h, t):
    self.option = t

  void set_group(string *s):
    self.selected = s

  void render():
    self.undraw()
    ui::Button::render()
    if self.selected != NULL:
      self.fb->draw_rect(self.x, self.y, self.w, self.h, GRAY, (*self.selected == self.option))
      self.textWidget->render()

  void on_mouse_click(input::SynMouseEvent &ev):
    *self.selected = self.option
    self.on_button_selected(self.option)

  virtual void on_button_selected(string t):
    pass

class BombButton: public RadioButton:
  public:
  BombButton(int x, y, w, h, string t="Open"): RadioButton(x,y,w,h,t):
    pass // 1

  void on_button_selected(string t):
    MODE = 1

class FlagButton: public RadioButton:
  public:
  FlagButton(int x, y, w, h, string t="Flag"): RadioButton(x,y,w,h,t):
    pass // 0

  void on_button_selected(string t):
    MODE = 0

class QuestionButton: public RadioButton:
  public:
  QuestionButton(int x, y, w, h, string t="???"): RadioButton(x,y,w,h,t):
    pass // 2

  void on_button_selected(string t):
    MODE = 2


class App:
  public:
  shared_ptr<framebuffer::FB> fb

  ui::Scene field_scene, title_menu
  Grid *grid

  App():
    fb = framebuffer::get()
    fb->clear_screen()
    fb->redraw_screen()

    w, h = fb->get_display_size()

    title_menu = ui::make_scene()
    // center align minesweeper text at top
    // center align the size buttons
    h_layout := ui::HorizontalLayout(0, 0, w, h, title_menu)

    image := stbtext::get_text_size("MineSweeper", 64)
    text := new ui::Text(0, 0, image.w, 50, "MineSweeper")
    text->font_size = 64
    h_layout.pack_center(text)

    size_button_container := ui::VerticalLayout(0, 0, 800, 200*4, title_menu)

    vector<pair<int, string>> sizes{ {8, "8x8" }, {12, "12x12"}, {16, "16x16"}, {20, "20x20"}};
    button_height := 200
    for auto p : sizes:
      btn := new SizeButton(w/2-400, 500, 800, button_height, p.first, p.second)
      btn->set_justification(ui::Text::JUSTIFY::CENTER)
      btn->y_padding = (button_height - SIZE_BUTTON_FS) / 2
      size_button_container.pack_start(btn)

//    size_button_container.pack_start(new SizeButton(w/2-400, 500, 800, 200, 8, "8x8"))
//    size_button_container.pack_start(new SizeButton(w/2-400, 50, 800, 200, 12, "12x12"))
//    size_button_container.pack_start(new SizeButton(w/2-400, 50, 800, 200, 16, "16x16"))
//    size_button_container.pack_start(new SizeButton(w/2-400, 50, 800, 200, 20, "20x20"))


    make_field()

    ui::MainLoop::set_scene(title_menu)
    ui::MainLoop::refresh()

  void main_menu():
    ui::MainLoop::set_scene(title_menu)
    ui::MainLoop::refresh()

  void make_field():
    field_scene = ui::make_scene()
    w, h = fb->get_display_size()

    m := new MenuButton(0, 0, 200, 50)
    field_scene->add(m)

    // create the grid component and add it to the field
    grid = new Grid(0, 300, 1100, 1100, GRID_SIZE)
    NB_UNOPENED = 0

    h_layout := ui::HorizontalLayout(0, 0, w, h, field_scene)
    text := new ui::Text(0, 0, w, 50, "MineSweeper")
    text->font_size = SIZE_BUTTON_FS
    h_layout.pack_center(text)
    h_layout.pack_center(grid)
    // pack cells after centering grid
    grid->make_cells(field_scene)
    // create the mouse1/mouse2 buttons
    // next steps:
    // controls for the bottom half of screen (flag vs. open bomb)
    // generate a bomb field
    // opening a bomb

    a := new BombButton((w - 200) / 2 - 300, 1450, 200, 50)
    b := new FlagButton((w - 200) / 2, 1450, 200, 50)
    c := new QuestionButton((w - 200) / 2 + 300, 1450, 200, 50)

    static string s
    a->set_group(&s)
    b->set_group(&s)
    c->set_group(&s)
    field_scene->add(a)
    field_scene->add(b)
    field_scene->add(c)

  def reset():
    MODE = 1
    NB_UNOPENED = 0
    FLAG_SCORE = 0
    FIRST_CLICK = 1
    NB_BOMBS = 0
    WON = 1
    n := GRID_SIZE
    for int i = 0; i < n; i++
      for int j = 0; j < n; j++:
        grid->cells[i][j]->is_bomb = 0
        grid->cells[i][j]->opened = 0
        grid->cells[i][j]->flagged = 0
        grid->cells[i][j]->neighbors = "0"
        grid->cells[i][j]->question = 0

  def handle_key_event(input::SynKeyEvent &key_ev):
    // print "KEY PRESSED", key_ev.key
    pass

  def handle_motion_event(input::SynMouseEvent &syn_ev):
    if !GAME_STARTED:
      if syn_ev.left == 0:
        GAME_STARTED = true
      else:
        syn_ev.stop_propagation()

  def run():
    ui::MainLoop::key_event += PLS_DELEGATE(self.handle_key_event)
    ui::MainLoop::motion_event += PLS_DELEGATE(self.handle_motion_event)
    while true:
      ui::MainLoop::main()
      // TODO: have widgets mark themselves dirty instead when interacted with
      ui::MainLoop::redraw()
      ui::MainLoop::refresh()
      ui::MainLoop::read_input()


App app
void resize_field(int size):
  GRID_SIZE = size
  app.make_field()

void main_menu():
  app.reset()
  app.main_menu()
  app.fb->clear_screen()
void new_game():
  app.reset()
  app.fb->clear_screen()
  ui::MainLoop::set_scene(app.field_scene)
  ui::MainLoop::refresh()

def main():
  ui::Text::DEFAULT_FS = 32
  app.run()

// vim:syntax=cpp
