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
using Gee;

namespace Agenda {

    const int MIN_WIDTH = 500;
    const int MIN_HEIGHT = 600;
    // Limit for any edited text
    const int EDITED_TEXT_MAX_LEN = -1;

    const string HINT_STRING = _("Add a new task…");

    public class AgendaWindow : Gtk.ApplicationWindow {

        private uint configure_id;

        private GLib.Settings privacy_setting = new GLib.Settings (
            "org.gnome.desktop.privacy");

        private FileBackend backend;

        private Granite.Widgets.Welcome agenda_welcome;
        private TaskView task_view;
        private TaskList task_list;
        private Gtk.ScrolledWindow scrolled_window;
        private Gtk.Entry task_entry;
        private HistoryList history_list;
        private Gtk.Button removeCompletedTasksButton;
        private Gtk.Button backButton;
        private Gtk.Button sortButton;

        private HashMap<int, Task> taskMap;
        private Task openTask;

        public AgendaWindow (Agenda app) {
            Object (application: app);
            taskMap = new HashMap<int, Task> ();

            var window_close_action = new SimpleAction ("close", null);
            var app_quit_action = new SimpleAction ("quit", null);
            var undo_action = new SimpleAction ("undo", null);
            var redo_action = new SimpleAction ("redo", null);

            add_action (window_close_action);
            add_action (app_quit_action);
            add_action (undo_action);
            add_action (redo_action);

            app.set_accels_for_action ("win.close", {"<Ctrl>W"});
            app.set_accels_for_action ("win.quit", {"<Ctrl>Q"});
            app.set_accels_for_action ("win.undo", {"<Ctrl>Z"});
            app.set_accels_for_action ("win.redo", {"<Ctrl>Y"});

            this.get_style_context ().add_class ("rounded");

            var header = new Gtk.HeaderBar ();
            header.show_close_button = true;
            header.get_style_context ().add_class ("titlebar");
            header.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
            this.set_titlebar (header);

            removeCompletedTasksButton = new Gtk.Button.from_icon_name ("user-trash-symbolic", Gtk.IconSize.BUTTON);
            removeCompletedTasksButton.clicked.connect (() => {
                // Remove completed tasks
                if (task_list != null) {
                     task_list.remove_completed_tasks();
                }                
            });
            backButton = new Gtk.Button.from_icon_name ("go-previous", Gtk.IconSize.BUTTON);
            backButton.clicked.connect(back_to_parent);
            header.pack_start(backButton);

            //header.pack_end(removeCompletedTasksButton);

            sortButton = new Gtk.Button.from_icon_name ("view-sort-ascending-symbolic", Gtk.IconSize.BUTTON);
            sortButton.clicked.connect (() => {
                if (task_list != null) {
                    task_list.sort_tasks ();
                }                
            });
            //header.pack_end(sortButton);

            restore_window_position ();

            var first = Agenda.settings.get_boolean ("first-time");
            agenda_welcome = new Granite.Widgets.Welcome (
                _("No Tasks!"),
                first ? _("(add one below)") : _("(way to go)"));
            task_list = new TaskList ();
            task_view = new TaskView.with_list (task_list);
            scrolled_window = new Gtk.ScrolledWindow (null, null);
            task_entry = new Gtk.Entry ();

            history_list = new HistoryList ();

            if (first) {
                Agenda.settings.set_boolean ("first-time", false);
            }

            backend = new FileBackend ();

            load_list ();
            setup_ui ();

            window_close_action.activate.connect (this.close);
            app_quit_action.activate.connect (this.close);
            undo_action.activate.connect (task_list.undo);
            redo_action.activate.connect (task_list.redo);

            bool hasCompletedTasks = task_list.hasCompletedTasks();
            removeCompletedTasksButton.set_sensitive(hasCompletedTasks);
            sortButton.set_sensitive(false);
        }

        private void load_list () {
            task_list.disable_undo_recording ();
            int id = Agenda.settings.get_int ("open-task");
            openTask = backend.find(id);
            this.set_title (openTask.text);
            backButton.set_sensitive(openTask.parent_id > 0);
            var tasks = backend.list (openTask);
            foreach (Task task in tasks) {
                task_list.append_task (task);
                taskMap.set(task.id, task);
            }

            string[] history = {};
            if (privacy_mode_off ()) {
                foreach (string line in history) {
                    history_list.add_item (line);
                }
            }

            task_list.enable_undo_recording ();
            task_list.clear_undo ();
            update();
        }

        private void setup_ui () {
            task_entry.name = "TaskEntry";
            task_entry.get_style_context ().add_class ("task-entry");
            task_entry.placeholder_text = HINT_STRING;
            task_entry.max_length = EDITED_TEXT_MAX_LEN;
            task_entry.hexpand = true;
            task_entry.valign = Gtk.Align.START;
            task_entry.set_icon_tooltip_text (
                Gtk.EntryIconPosition.SECONDARY, _("Add to list…"));

            Gtk.EntryCompletion completion = new Gtk.EntryCompletion ();
            completion.set_model (history_list);
            completion.set_text_column (0);

            task_entry.set_completion (completion);

            task_entry.activate.connect (append_task);
            task_entry.icon_press.connect (append_task);

            task_entry.changed.connect (() => {
                var str = task_entry.get_text ();
                if ( str == "" ) {
                    task_entry.set_icon_from_icon_name (
                        Gtk.EntryIconPosition.SECONDARY, null);
                } else {
                    task_entry.set_icon_from_icon_name (
                        Gtk.EntryIconPosition.SECONDARY, "list-add-symbolic");
                }
            });

            task_entry.populate_popup.connect ((menu) => {
                Gtk.TreeIter iter;
                bool valid = history_list.get_iter_first (out iter);
                var separator = new Gtk.SeparatorMenuItem ();
                var item_clear_history = new Gtk.MenuItem.with_label (_("Clear history"));

                menu.insert (separator, 6);
                menu.insert (item_clear_history, 7);

                item_clear_history.activate.connect (() => {
                    history_list.clear ();
                });

                if (valid) {
                    item_clear_history.set_sensitive (true);
                } else {
                    item_clear_history.set_sensitive (false);
                }

                menu.show_all ();
            });

            task_view.focus_out_event.connect ((e) => {
                Gtk.TreeSelection selected;
                selected = task_view.get_selection ();
                selected.unselect_all ();
                return false;
            });

            task_list.open_task.connect ((task) => {
                Agenda.settings.set_int ("open-task", task.id);
                taskMap.clear();
                load_list();
            });

            task_list.list_changed.connect (() => {
                bool hasCompletedTasks = task_list.hasCompletedTasks();
                removeCompletedTasksButton.set_sensitive(hasCompletedTasks);
                //sortButton.set_sensitive(hasCompletedTasks);
                update ();
            });

            task_list.task_edited.connect ((task) => {
                taskMap.get(task.id).text = task.text;
                backend.update(task);
                update ();
            });

            task_list.task_toggled.connect ((task) => {
                backend.mark(task);
                taskMap.get(task.id).complete = task.complete;
                update ();
            });

            task_list.task_removed.connect ((task) => {
                taskMap.unset(task.id);
                backend.drop(task);
                update ();
            });

            task_list.positions_changed.connect (() => {
                Task[] tasks = task_list.get_all_tasks();
                int position = 1;
                foreach (Task viewTask in tasks) {
                    Task task = taskMap.get(viewTask.id);
                    if (task.position != position){
                        task.position = position;
                        backend.reorder(task);
                    }
                    position++;
                }
                update ();
            });

            this.key_press_event.connect (key_down_event);
            this.button_press_event.connect (button_down_event);
            task_view.expand = true;
            scrolled_window.expand = true;
            scrolled_window.set_policy (
                Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
            scrolled_window.add (task_view);

            agenda_welcome.expand = true;

            var grid = new Gtk.Grid ();
            grid.expand = true;
            grid.row_homogeneous = false;
            grid.attach (agenda_welcome, 0, 0, 1, 1);
            grid.attach (scrolled_window, 0, 1, 1, 1);
            grid.attach (task_entry, 0, 2, 1, 1);

            this.add (grid);

            task_entry.margin_start = 10;
            task_entry.margin_end = 10;
            task_entry.margin_top = 10;
            task_entry.margin_bottom = 10;

            task_entry.grab_focus ();
        }

        public void back_to_parent(){
            Agenda.settings.set_int ("open-task", openTask.parent_id);
            task_list.clear_tasks();
            taskMap.clear();
            load_list();
        }

        public void append_task () {
            int id = Agenda.settings.get_int ("task-sequence");
            Task task = new Task.with_attributes (
                id,
                false,
                task_entry.text);
            taskMap.set(task.id, task);
            task.position = taskMap.size;
            task.parent_id = openTask.id;

            task_list.append_task (task);
            history_list.add_item (task.text);
            // When adding a new task rearrange the tasks
            task_entry.text = "";
            Agenda.settings.set_value ("task-sequence", ++id);
            backend.create(task);
            update ();
        }

        public bool privacy_mode_off () {
            bool remember_app_usage = privacy_setting.get_boolean ("remember-app-usage");
            bool remember_recent_files = privacy_setting.get_boolean ("remember-recent-files");

            return remember_app_usage || remember_recent_files;
        }

        public void restore_window_position () {
            var size = Agenda.settings.get_value ("window-size");
            var position = Agenda.settings.get_value ("window-position");

            if (position.n_children () == 2) {
                var x = (int) position.get_child_value (0);
                var y = (int) position.get_child_value (1);

                debug ("Moving window to coordinates %d, %d", x, y);
                move (x, y);
            } else {
                debug ("Moving window to the centre of the screen");
                window_position = Gtk.WindowPosition.CENTER;
            }

            if (size.n_children () == 2) {
                var rect = Gtk.Allocation ();
                rect.width = (int) size.get_child_value (0);
                rect.height = (int) size.get_child_value (1);

                debug ("Resizing to width and height: %d, %d", rect.width, rect.height);
                set_allocation (rect);
            } else {
                debug ("Not resizing window");
            }
        }

        public bool main_quit () {
            this.destroy ();

            return false;
        }

        public bool button_down_event(Gdk.EventButton e){
            if(e.button == 8 && openTask.parent_id > 0){ // mouse backforward
                back_to_parent();
            }
            return false;
        }

        public bool key_down_event (Gdk.EventKey e) {
            switch (e.keyval) {
                case Gdk.Key.Escape:
                    if (!task_view.is_editing) {
                        main_quit ();
                    }
                    break;
                case Gdk.Key.Delete:
                    if (!task_entry.has_focus && !task_view.is_editing) {
                        task_view.remove_selected_tasks ();
                        update ();
                    }
                    break;
                case Gdk.Key.BackForward:
                    if (!task_entry.has_focus && !task_view.is_editing) {
                        update ();
                    }
                    break;
            }

            return false;
        }

        public void update () {
            if ( task_list.is_empty () )
                show_welcome ();
            else
                hide_welcome ();
        }

        void show_welcome () {
            scrolled_window.hide ();
            agenda_welcome.show ();
        }

        void hide_welcome () {
            agenda_welcome.hide ();
            scrolled_window.show ();
        }

        public override bool configure_event (Gdk.EventConfigure event) {
            if (configure_id != 0) {
                GLib.Source.remove (configure_id);
            }

            configure_id = Timeout.add (100, () => {
                configure_id = 0;

                int x, y;
                Gdk.Rectangle rect;

                get_position (out x, out y);
                get_allocation (out rect);

                debug ("Saving window position to %d, %d", x, y);
                Agenda.settings.set_value (
                    "window-position", new int[] { x, y });

                debug (
                    "Saving window size of width and height: %d, %d",
                    rect.width, rect.height);
                Agenda.settings.set_value (
                    "window-size", new int[] { rect.width, rect.height });

                return false;
            });

            return base.configure_event (event);
        }
    }
}
