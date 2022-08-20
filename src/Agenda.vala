/***

    Copyright (C) 2014-2021 Agenda Developers

    This file is part of Agenda.

    Agenda is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Agenda is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Agenda.  If not, see <http://www.gnu.org/licenses/>.

***/

using Gtk;
using Granite;

namespace Agenda {

    public class Agenda : Gtk.Application {
        public static GLib.Settings settings;
        private static Agenda app;
        private AgendaWindow[] windows = {};        
        public static Task[] clipboard = {};

        public static PasteMode paste_mode;
        public static Task copy_source;

        public enum PasteMode {
            CLONE,
            MOVE,
            LINK
        }

        static construct {
            settings = new GLib.Settings ("com.github.dahenson.agenda");
        }

        public Agenda () {
            Object (application_id: "com.github.dahenson.agenda",
            flags: ApplicationFlags.FLAGS_NONE);
        }

        protected override void activate () {
            if(windows.length > 0)
                windows[windows.length - 1].save_state();
            AgendaWindow window = new AgendaWindow (this);
            window.show_all ();
            window.update ();
            window.refresh_window.connect(refresh_windows);
            windows += window;

            window.on_quit.connect(close_window);

            window.broadcast_task.connect(append_task);
            window.broadcast_task_update.connect(update_task);

            if (elementary_stylesheet ()) {
                var elementary_provider = new Gtk.CssProvider ();
                elementary_provider.load_from_resource (
                    "com/github/dahenson/agenda/Agenda.css");
                Gtk.StyleContext.add_provider_for_screen (
                    Gdk.Screen.get_default (),
                    elementary_provider,
                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            }
        }

        private void close_window (AgendaWindow window) {
            AgendaWindow[] window_list = {};
            foreach(AgendaWindow window_in_list in windows){
                if(window_in_list != window)
                    window_list += window_in_list;
            }
            windows = window_list;
        }

        private void append_task(Task task, Task parent) {
            Timeout.add (100, () => {
                foreach(AgendaWindow window in windows){
                    if(window.openTask.id == parent.id)
                        window.create_task_view(task);
                }
                return false;
            });            
        }

        private void update_task(Task task) {
            Timeout.add (100, () => {
                foreach(AgendaWindow window in windows) {
                    window.update_task(task);
                }
                return false;
            });            
        }

        private void refresh_windows(Task task, AgendaWindow source) {
            Timeout.add (100, () => {
                foreach(AgendaWindow window in windows){
                    if(window != source && window.openTask.id == task.id){
                        window.refresh_task();
                    }
                }
                return false;
            });
            
        }

        public static Agenda get_instance () {
            if (app == null) {
                app = new Agenda ();
            }

            return app;
        }

        public static int main (string[] args) {
            app = new Agenda ();

            if (args[1] == "-s") {
                return 0;
            }

            return app.run (args);
        }

        public static bool elementary_stylesheet () {
            return Gtk.Settings.get_default ().gtk_theme_name.contains
                ("elementary");
        }
    }
}
