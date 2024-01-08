/***

    Copyright (C) 2014-2020 Agenda Developers

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

namespace Agenda {


    public class TaskView : Gtk.TreeView {

        private TaskList task_list;
        public bool is_editing;

        public signal void text_editing_started();
        public signal void text_editing_ended();
        public signal void taskview_activated();

        public TaskView.with_list (TaskList list) {
            task_list = list;
            model = task_list;
        }

        construct {
            name = "TaskView";
            activate_on_single_click = true;
            headers_visible = false;
            enable_search = false;
            hexpand = true;
            valign = Gtk.Align.FILL;
            reorderable = true;

            var column = new Gtk.TreeViewColumn ();
            var text = new Gtk.CellRendererText ();
            var toggle = new Gtk.CellRendererToggle ();
            var subinfo = new Gtk.CellRendererText ();
            var enterbutton = new Gtk.CellRendererPixbuf ();

            // Setup the TOGGLE column
            toggle.xpad = 6;
            column = new Gtk.TreeViewColumn.with_attributes ("Toggle",
                                                             toggle,
                                                             "active",
                                                             TaskList.Columns.TOGGLE);
            append_column (column);

            // Setup the TEXT column
            text.ypad = 6;
            text.editable = false;
            text.max_width_chars = 10;
            text.wrap_width = 50;
            text.wrap_mode = Pango.WrapMode.WORD_CHAR;
            text.ellipsize_set = true;
            text.ellipsize = Pango.EllipsizeMode.END;
            text.scale = 1.03;

            column = new Gtk.TreeViewColumn.with_attributes ("Task", text,
                "text", TaskList.Columns.TEXT,
                "strikethrough", TaskList.Columns.STRIKETHROUGH);
            column.expand = true;
            var colunaTexto = column;
            append_column (column);

            subinfo.ypad = 6;
            subinfo.editable = false;
            
            /*  
            var foreground_color = subinfo.foreground_rgba.copy();
            foreground_color.alpha = 0.5;
            subinfo.foreground_rgba = foreground_color;
            */

            column = new Gtk.TreeViewColumn.with_attributes ("SUBINFO", subinfo,
                "text", TaskList.Columns.SUBINFO);     
            append_column (column);

            // Setup the DRAGHANDLE column
            enterbutton.xpad = 6;
            column = new Gtk.TreeViewColumn.with_attributes (
                "Enter", enterbutton, "icon_name", TaskList.Columns.ENTER);
            append_column (column);

            set_tooltip_column (TaskList.Columns.TOOLTIP);

            text.editing_started.connect ( (editable, path) => {
                debug ("Editing started");
                is_editing = true;
                text_editing_started();
            });

            text.editing_canceled.connect ( () => {
                is_editing = false;
                text_editing_ended();
            });

            text.edited.connect (text_edited);
            toggle.toggled.connect (toggle_clicked);
            row_activated.connect (list_row_activated);

            button_press_event.connect ((event) => {
                if (event.button == 8)  // mouse backforward
                    return false;
                taskview_activated();
                Gtk.TreePath path = new Gtk.TreePath ();
                get_path_at_pos((int) event.x, (int) event.y, out path, null, null, null);

                if (event.type == Gdk.EventType.DOUBLE_BUTTON_PRESS && event.button == 1) {
                    if (path != null) {
                        text.editable = true;
                        set_cursor(path, colunaTexto, true);
                    }
                }
                text.editable = false;
                
                if (path == null)
                    get_selection ().unselect_all ();
                
                path.free ();
                return false;
            });

            get_selection().set_mode(Gtk.SelectionMode.MULTIPLE);
        }

        public void toggle_selected_task () {
            Gtk.TreeIter iter;

            var tree_selection = get_selection ();
            tree_selection.get_selected (null, out iter);
            Gtk.TreePath path = task_list.get_path (iter);
            if (path != null) {
                task_list.toggle_task (path);
            }

            path.free ();
        }

        public Task[] getSeletedTasks(){
            Gtk.TreeIter iter;
            bool valid = task_list.get_iter_first (out iter);
            var tree_selection = get_selection ();
            Task[] selectedTasks = {};

            while (valid) {
                if(tree_selection.iter_is_selected(iter)){
                    task_list.get_path (iter);
                    Task task = task_list.get_task(iter);
                    selectedTasks += task;
                }
                valid = task_list.iter_next (ref iter);
            }
            return selectedTasks;
        }

        public void remove_selected_tasks () {
            Task[] selectedTasks = getSeletedTasks();

            foreach(Task task in selectedTasks){
                task_list.remove_task_object(task);
            }
            get_selection ().unselect_all ();
        }

        private void list_row_activated (Gtk.TreePath path, Gtk.TreeViewColumn column) {
            if (column.title == "Enter") {
                task_list.enter_task (path);
            }
        }

        /**
         * Check if the task is an empty string, or only has white space.
         *
         * @return True if task is empty
         */
        private bool task_is_empty (string task) {
            if (task == "" || (task.replace (" ", "")).length == 0) {
                return true;
            } else {
                return false;
            }
        }

        public int get_selected_index(){
            Gtk.TreeIter iter;
            bool valid = task_list.get_iter_first (out iter);
            var tree_selection = get_selection ();
            int index = 1;
            while (valid) {
                if(tree_selection.iter_is_selected(iter))
                    return index;
                valid = task_list.iter_next (ref iter);
                index++;
            }
            return index;
        }

        public void set_selected_tasks(Task[] tasks) {
            Gtk.TreeIter iter;
            var tree_selection = get_selection ();

            foreach(Task selected_task in tasks) {
                bool valid = task_list.get_iter_first (out iter);
                while (valid) {
                    Task task = task_list.get_task(iter);
                    if (task.id == selected_task.id)
                        tree_selection.select_iter(iter);
                    valid = task_list.iter_next (ref iter);
                }
            }            
        }

        private void toggle_clicked (Gtk.CellRendererToggle toggle, string path) {
            var tree_path = new Gtk.TreePath.from_string (path);
            task_list.toggle_task (tree_path);
        }

        private void text_edited (string path, string edited_text) {
            /* If the user accidentally blanks a task, abort the edit */

            debug ("String: %s length: %d", edited_text, edited_text.length);
            if (task_is_empty (edited_text)) {
                return;
            }
            task_list.set_task_text (path, edited_text);
            is_editing = false;
            text_editing_ended();
        }
    }
}
