// LAUNCHER FOR REMARKABLE
#include <time.h>
#include <thread>
#include <chrono>

#include <sys/types.h>
#include <dirent.h>
#include <algorithm>
#include <unordered_set>

#include "../shared/proc.h"
#include "../build/rmkit.h"

#define TIMEOUT 2

#include "config.launcher.h"

DIALOG_WIDTH  := 600
DIALOG_HEIGHT := 800

#ifdef REMARKABLE
#define BIN_DIR  "/home/root/apps/"
#define DRAFT_DIR "/etc/draft/"
#else
#define BIN_DIR  "./src/build/"
#define DRAFT_DIR "./src/remux/draft"
#endif

class AppBackground: public ui::Widget:
  public:
  char *buf
  int byte_size

  AppBackground(int x, y, w, h): ui::Widget(x, y, w, h):
    self.byte_size = w*h*sizeof(remarkable_color)
    buf = (char*) malloc(self.byte_size)

  def snapshot():
    fb := framebuffer::get()
    memcpy(buf, fb->fbmem, self.byte_size)

  void render():
    self.fb->waveform_mode = WAVEFORM_MODE_GC16
    memcpy(fb->fbmem, buf, self.byte_size)

template<class T>
class AppDialog: public ui::Pager<AppDialog<T>>:
  public:
    vector<string> binaries
    vector<RMApp> apps
    T* app

    AppDialog(int x, y, w, h, T* a): ui::Pager<AppDialog>(x, y, w, h, self):
      self.set_title("Select an app...")
      self.app = a
      self.apps = {}

    vector<RMApp> read_draft_from_dir(string bin_dir):
      DIR *dir
      struct dirent *ent

      vector<RMApp> apps
      char resolved_path[PATH_MAX];
      if ((dir = opendir (bin_dir.c_str())) != NULL):
        while ((ent = readdir (dir)) != NULL):
          str_d_name := string(ent->d_name)
          if str_d_name == "." or str_d_name == "..":
            continue

          path := string(bin_dir) + "/" + string(ent->d_name)
          ifstream filein(path)
          string line

          RMApp rmapp
          rmapp.bin = "";
          while filein.good():
            getline(filein, line)
            tokens := split(line, '=')
            if tokens.size() == 2:
              arg := tokens[0]
              val := tokens[1]
              if arg == "call":
                rmapp.bin = val
              else if arg == "desc":
                rmapp.desc = val
              else if arg == "name":
                rmapp.name = val
              else if arg == "term":
                rmapp.term = val

          if rmapp.bin != "":
            apps.push_back(rmapp)

        closedir (dir)
      else:
        perror ("")

      return apps

    def read_apps_from_dir(string bin_dir):
      DIR *dir
      struct dirent *ent

      vector<string> filenames
      char resolved_path[PATH_MAX];
      if ((dir = opendir (bin_dir.c_str())) != NULL):
        while ((ent = readdir (dir)) != NULL):
          str_d_name := string(ent->d_name)
          if str_d_name != "." and str_d_name != ".." and ends_with(str_d_name, ".exe"):
            path := string(bin_dir) + string(ent->d_name)
            _ := realpath(path.c_str(), resolved_path);
            str_d_name = string(resolved_path)
            filenames.push_back(str_d_name)
        closedir (dir)
      else:
        perror ("")
      sort(filenames.begin(),filenames.end())
      return filenames

    void populate():
      vector<string> skip_list = { "demo.exe", "remux.exe" }
      vector<string> binaries
      unordered_set<string> seen
      self.apps = {}

      for auto a : APPS:
        if a.always_show || proc::exe_exists(a.bin):
          self.apps.push_back(a)

      draft_binaries := read_draft_from_dir(DRAFT_DIR)
      for auto a : draft_binaries:
        dont_add := false
        for auto s : skip_list:
          if s == a.bin:
            dont_add = true
        if dont_add:
          continue

        self.apps.push_back(a)

      bin_binaries := read_apps_from_dir(BIN_DIR)
      for auto a : bin_binaries:
        bin_str := string(a)
        app_str := a.c_str()
        base := basename(app_str)

        dont_add := false
        for auto s : skip_list:
          if s == base:
            dont_add = true
        if dont_add:
          continue

        app := (RMApp) { .bin=bin_str, .name=base, .term="killall " + string(base) }
        self.apps.push_back(app)

      for auto a : self.apps:
        auto name = a.name
        if seen.find(a.bin) != seen.end():
          continue

        seen.insert(a.bin)
        if name == "":
          name = a.bin
        binaries.push_back(name)

      self.options = binaries

    void on_row_selected(string name):
      app->selected(name)
      ui::MainLoop::hide_overlay()

    void render_row(ui::HorizontalLayout *row, string option):
      d := new ui::DialogButton<ui::Dialog>(20, 0, self.w-200, self.opt_h, self, option)
      d->set_justification(ui::Text::JUSTIFY::LEFT)
      self.layout->pack_start(row)
      row->pack_start(d)

class App:
  int lastpress
  int is_pressed = false
  AppDialog<App> *app_dialog
  AppBackground *app_bg
  shared_ptr<framebuffer::FB> fb

  public:
  App():
    fb := framebuffer::get()

    // on resize, we exit and trust our service to restart us
    fb->resize += [=](auto &e):
      exit(1)
    ;

    w, h = fb->get_display_size()

    if app_dialog != NULL:
      delete app_dialog
    if app_bg != NULL:
      delete app_bg

    app_dialog = new AppDialog<App>(0, 0, DIALOG_WIDTH, DIALOG_HEIGHT, self)
    app_bg = new AppBackground(0, 0, w, h)

    notebook := ui::make_scene()
    notebook->add(app_bg)
    ui::MainLoop::set_scene(notebook)

  def handle_key_event(input::SynKeyEvent ev):
    static int lastpress = RAND_MAX
    static int event_press_id = 0
    ui::MainLoop::handle_key_event(ev)

    if is_pressed && ev.is_pressed:
      return

    switch ev.key:
      case KEY_HOME:

        if ev.is_pressed:
          lastpress = time(NULL)
          event_press_id = ev.id

          thread *th = new thread([=]() {
              this_thread::sleep_for(chrono::seconds(TIMEOUT));
              if is_pressed && event_press_id == ev.id
                now := time(NULL)
                if now - lastpress > 1:
                  ui::TaskQueue::add_task([=] {
                    app_bg->visible = true
                    app_bg->snapshot()
                    app_dialog->populate()
                    app_dialog->setup_for_render()
                    app_dialog->show()
                    ui::MainLoop::in.grab()
                    app_dialog->scene->pinned = true
                  });
          });
        else:
          event_press_id = 0

        is_pressed = ev.is_pressed

    last_ev := &ev

  void term_apps(string name=""):
    for auto a : app_dialog->apps:
      if a.name != name && a.term != "":
        proc::launch_process(a.term, false)

  def selected(string name):
    print "LAUNCHING APP", name
    string bin
    string which

    for auto a : app_dialog->apps:
      if a.name == name:
        bin = a.bin
        which = a.which

    term_apps(name)

    ui::MainLoop::in.ungrab()
    if !proc::check_process(which):
      proc::launch_process(bin, true /* check running */, true /* background */)
    ui::MainLoop::hide_overlay()
    ui::MainLoop::redraw()

    app_bg->render()
    app_bg->visible = false

  def run():
    ui::Text::DEFAULT_FS = 32

    ui::MainLoop::key_event += PLS_DELEGATE(self.handle_key_event)
    while true:
      ui::MainLoop::main()
      ui::MainLoop::check_resize()
      if app_bg->visible:
        ui::MainLoop::redraw()

      ui::MainLoop::read_input()

App app
def main():
  app.run()
