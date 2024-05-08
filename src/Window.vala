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

        private SqliteBackend backend;
        private Stack stack;

        private Granite.Widgets.Welcome agenda_welcome;
        private TaskView task_view;
        private TaskList task_list;
        private Gtk.TextView description_view;
        private Gtk.ScrolledWindow scrolled_window;
        private Gtk.Entry task_entry;
        private HistoryList history_list;
        private Gtk.Button removeCompletedTasksButton;
        private Gtk.Button backButton;
        private Gtk.Button sortButton;
        private Gtk.MenuItem description_menuitem ;

        private Gtk.HeaderBar header;

        private Gtk.ToggleButton search_toggle_button;
        private Gtk.Revealer search_revealer;
        private Gtk.SearchEntry search_entry;

        public Task openTask;
        private Task SEARCH_TASK;
        private Agenda app;

        private int xpos;
        private int ypos;
        private Gdk.Rectangle rect;
        private Gtk.Box layout;
        private bool showingTaskEntry = true;

        public signal void on_quit(AgendaWindow window);
        public signal void refresh_window(Task task, AgendaWindow source);
        public signal void broadcast_task(Task task, Task parent);
        public signal void broadcast_task_update(Task task);        

        public AgendaWindow (Agenda app) {
            Object (application: app);
            this.app = app;
            delete_event.connect (main_quit);

            var window_close_action = new SimpleAction ("close", null);
            var app_quit_action = new SimpleAction ("quit", null);
            var undo_action = new SimpleAction ("undo", null);
            var redo_action = new SimpleAction ("redo", null);
            var copy_action = new SimpleAction ("copy", null);
            var cut_action = new SimpleAction ("cut", null);
            var paste_action = new SimpleAction ("paste", null);
            var link_action = new SimpleAction ("link", null);

            add_action (window_close_action);
            add_action (app_quit_action);
            add_action (undo_action);
            add_action (redo_action);
            add_action (copy_action);
            add_action (cut_action);
            add_action (paste_action);
            add_action (link_action);

            app.set_accels_for_action ("win.close", {"<Ctrl>W"});
            app.set_accels_for_action ("win.quit", {"<Ctrl>Q"});
            app.set_accels_for_action ("win.undo", {"<Ctrl>Z"});
            app.set_accels_for_action ("win.redo", {"<Ctrl>Y"});
            app.set_accels_for_action ("win.cut", {"<Ctrl>X"});
            app.set_accels_for_action ("win.copy", {"<Ctrl>C"});
            app.set_accels_for_action ("win.paste", {"<Ctrl>V"});
            app.set_accels_for_action ("win.link", {"<Ctrl>L"});

            this.get_style_context ().add_class ("rounded");

            header = new Gtk.HeaderBar ();
            header.show_close_button = true;
            header.get_style_context ().add_class ("titlebar");
            header.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
            this.set_titlebar (header);

            SEARCH_TASK = new Task.with_attributes (-1, false, "Pesquisa");

            search_entry = new Gtk.SearchEntry ();
            search_entry.valign = Gtk.Align.CENTER;
            search_entry.expand = true;
            search_entry.visible = true;
            search_entry.placeholder_text = "Pesquise aqui";
            search_entry.activate.connect (search_tasks);
            
            Gtk.SearchBar searchbar = new Gtk.SearchBar();
            searchbar.search_mode_enabled = true;
            searchbar.visible = true;
            searchbar.expand = true;
            searchbar.show_close_button = false;

            Gtk.Box searchbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            searchbox.visible = true;
            searchbox.expand = true;   
            searchbox.margin_start = 5;
            searchbox.margin_end = 5;
            searchbox.margin_top = 6;
            searchbox.margin_bottom = 6;         

            search_revealer = new Gtk.Revealer();
            search_revealer.visible = true;
            search_revealer.expand = false;
            search_revealer.set_transition_type (Gtk.Revealer.SLIDE_DOWN);
            search_revealer.set_reveal_child(false);

            search_revealer.add(searchbox);
            searchbox.add(search_entry);

            search_toggle_button = new Gtk.ToggleButton();
            search_toggle_button.set_image(new Gtk.Image.from_icon_name("search", Gtk.IconSize.BUTTON));
            search_toggle_button.clicked.connect(toggle_search);

            removeCompletedTasksButton = new Gtk.Button.from_icon_name ("user-trash-symbolic", Gtk.IconSize.BUTTON);
            removeCompletedTasksButton.clicked.connect (() => {
                // Remove completed tasks
                if (task_list != null) {
                     task_list.remove_completed_tasks();
                }                
            });
            backButton = new Gtk.Button.from_icon_name ("go-previous", Gtk.IconSize.BUTTON);
            backButton.clicked.connect(back_to_parent);
            backButton.set_tooltip_text(_("Back"));
            header.pack_start(backButton);

            var preferences_menuitem = new Gtk.MenuItem.with_label (_("Generate graph in PDF"));
            preferences_menuitem.activate.connect (exportarPDF);

            description_menuitem = new Gtk.MenuItem.with_label (_("Add description"));
            description_menuitem.activate.connect (addDescription);

            var menu = new Gtk.Menu ();
            menu.append (preferences_menuitem);
            menu.append (description_menuitem);
            menu.show_all ();

            var menu_button = new Gtk.MenuButton ();
            menu_button.image = new Gtk.Image.from_icon_name ("overflow-menu", Gtk.IconSize.BUTTON);
            menu_button.popup = menu;

            header.pack_end(menu_button);
            header.pack_end(search_toggle_button);

            sortButton = new Gtk.Button.from_icon_name ("view-sort-ascending-symbolic");
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
            
            description_view = new Gtk.TextView ();
            description_view.set_wrap_mode (Gtk.WrapMode.WORD_CHAR);
            description_view.margin_start = 10;
            description_view.margin_end = 10;
            description_view.margin_top = 10;
            description_view.margin_bottom = 10;
            description_view.buffer.changed.connect((event)=> {
                if(description_view.has_focus) {
                    openTask.description = description_view.buffer.text;
                    backend.modify_description(openTask);
                    broadcast_task_update(openTask);
                }
            });

            description_view.focus_in_event.connect ((e) => {
                remove_accelerators_copy();
                return false;
            });

            description_view.focus_out_event.connect ((e) => {
                add_accelerators_copy();
                return false;
            });        

            history_list = new HistoryList ();

            if (first) {
                Agenda.settings.set_boolean ("first-time", false);
            }

            backend = new SqliteBackend ();
            stack = backend.readStack();
            load_list ();
            setup_ui ();

            window_close_action.activate.connect (this.close);
            app_quit_action.activate.connect (this.close);
            undo_action.activate.connect (task_list.undo);
            redo_action.activate.connect (task_list.redo);
            paste_action.activate.connect(paste_tasks);

            copy_action.activate.connect(copy_tasks);
            cut_action.activate.connect(() => {
                prepare_clipboard(Agenda.PasteMode.MOVE);
            });
            link_action.activate.connect(() => {
                prepare_clipboard(Agenda.PasteMode.LINK);
            });

            bool hasCompletedTasks = task_list.hasCompletedTasks();
            removeCompletedTasksButton.set_sensitive(hasCompletedTasks);
            sortButton.set_sensitive(false);

            var css_provider = new Gtk.CssProvider();
            string style = """
            textview {
                background-color: @bg_color;
                font-size: 1.05em;
            }
            .task-entry{
                font-size: 1.05em;
            }
            """;

            try {
                css_provider.load_from_data(style, -1);
            } catch (GLib.Error e) {
                warning ("Failed to parse css style : %s", e.message);
            }

            Gtk.StyleContext.add_provider_for_screen(
                Gdk.Screen.get_default(),
                css_provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );
        }

        private void exportarPDF () {
            // Gere o script Graphviz em uma variável string
            string graphviz_script = gerar_script_graphviz ();
        
            // Salve o script em um arquivo temporário na pasta Downloads
            string file_path = salvar_script_temporario (graphviz_script);
        
            //  Compile o arquivo usando a engine dot para gerar um arquivo PDF
            compilar_com_dot (file_path);
        
            // Abra o arquivo PDF com o visualizador padrão do sistema
            abrir_pdf_com_visualizador_padrao (file_path + ".pdf");
        }
        
        private string gerar_script_graphviz () {            
            string graph_code = "digraph G {\n";
            graph_code = graph_code + "rankdir=\"LR\";\n";
            graph_code = graph_code + "node[shape=rect, style=rounded];\n" ;

            HashMap visited_tasks = new HashMap<int, bool>();
            graph_code = generate_graph_code(openTask, graph_code, visited_tasks);
            graph_code = graph_code + "}\n" ;
            return graph_code;            
        }

        private string temp_path = "/tmp/hitaskly/";
        
        private string salvar_script_temporario (string script) {                        

            try { 
                DirUtils.create_with_parents (temp_path, 0775);

                File file = File.new_for_path (temp_path + openTask.title + ".dot");
                FileOutputStream writer;

                if (file.query_exists (null))
                    writer = file.replace (null, false, FileCreateFlags.NONE, null);
                else
                    writer = file.create (FileCreateFlags.PRIVATE);
                
                writer.write(script.data);
                writer.close(null);

                return file.get_path();
            } catch (Error e) {
                stderr.printf ("Erro ao salvar o script: %s\n", e.message);
            }
            return "Deu erro.dot";
        }
        
        private void compilar_com_dot (string file_path) {
            try {
                // Execute o comando dot para compilar o arquivo
                Process.spawn_command_line_sync ("dot -Tpdf -o \"" + temp_path + openTask.title + ".pdf\" \"" + file_path + "\"");
            } catch (Error e) {
                stderr.printf ("Erro ao compilar com dot: %s\n", e.message);
            }
        }
        
        private void abrir_pdf_com_visualizador_padrao (string pdf_path) {
            try {
                // Execute o comando para abrir o PDF com o visualizador padrão
                Process.spawn_command_line_sync ("xdg-open \"" + temp_path + openTask.title+ ".pdf\"");
            } catch (Error e) {
                stderr.printf ("Erro ao abrir o PDF: %s\n", e.message);
            }
        }

        private string generate_graph_code(Task task, owned string graph_code, HashMap<int, bool> visited_tasks) {
            if (visited_tasks.has_key(task.id))
                return graph_code;

            visited_tasks.set(task.id, true);
            graph_code = graph_code + task.id.to_string() + "[label=\"" + task.title.replace("\"", "\\\"") + "\"];\n";

            Task[] subtasks = backend.list(task);
            foreach(Task subtask in subtasks) {
                graph_code = graph_code + task.id.to_string() + " -> " + subtask.id.to_string() + ";\n";
                graph_code = generate_graph_code(subtask, graph_code, visited_tasks);
            }
            return graph_code;
        }

        private void toggle_search() {
            search_revealer.set_reveal_child(is_search_mode());
            if (is_search_mode())
                search_entry.grab_focus ();
        }

        private void disable_search() {
            search_toggle_button.set_active(false);
        }

        private bool is_search_mode () {
            return search_toggle_button.get_active();
        }

        private void addDescription(){
            description_view.buffer.text = _("Description: ");
            description_view.show();
            description_menuitem.hide();
        }

        private HashMap<int, bool> waiting_one_milisecond = new HashMap<int, bool>();
        private void emit_refresh_window(Task task){
            if (!waiting_one_milisecond.has_key(task.id) || !waiting_one_milisecond.get(task.id)) {
                waiting_one_milisecond.set(task.id, true);
                Timeout.add (1, () => {
                    refresh_window(task, this);
                    waiting_one_milisecond.set(task.id, false);
                    return false;
                });
            }   
        }

        private void load_list () {
            //disable_search();
            task_list.disable_undo_recording ();
            openTask = stack.peek();
            openTask = backend.find(openTask.id);
            this.set_title (openTask.title);
            
            backButton.set_sensitive(stack.size() > 1);
            
            Task[] tasks = {};

            if (openTask.id == SEARCH_TASK.id)
                tasks = backend.search(search_entry.text);
            else
                tasks = backend.list (openTask);
            
            openTask.subtasksCount = tasks.length;

            foreach (Task task in tasks) {
                task_list.append_task (task);
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

            task_entry.focus_in_event.connect ((e) => {
                remove_accelerators_copy();
                return false;
            });

            task_entry.focus_out_event.connect ((e) => {
                add_accelerators_copy();
                return false;
            });

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

            task_view.text_editing_started.connect(remove_accelerators_copy);
            task_view.text_editing_ended.connect(add_accelerators_copy);

            task_list.open_task.connect ((task) => {
                stack.push(task);
                load_list();
            });

            task_list.list_changed.connect (() => {
                bool hasCompletedTasks = task_list.hasCompletedTasks();
                removeCompletedTasksButton.set_sensitive(hasCompletedTasks);
                //sortButton.set_sensitive(hasCompletedTasks);
                update ();
            });

            task_list.task_edited.connect ((task) => {
                backend.update(task);
                update ();
                broadcast_task_update(task);
            });

            task_list.task_toggled.connect ((task) => {
                backend.mark(task);
                update ();
                broadcast_task_update(task);
            });

            task_list.task_removed.connect ((task) => {
                backend.drop(task, openTask);
                update ();
            });

            task_list.positions_changed.connect (() => {
                Task[] tasks = task_list.get_all_tasks();
                int position = 1;
                foreach (Task task in tasks) {
                    if (task.position != position){
                        task.position = position;
                        backend.reorder(task, openTask);
                    }
                    position++;
                }
                update ();
                emit_refresh_window(openTask);
            });

            this.key_press_event.connect (key_down_event);
            this.button_press_event.connect (button_down_event);
            description_view.button_press_event.connect (button_down_event);
            task_view.expand = true;
            scrolled_window.expand = true;
            scrolled_window.set_policy (
                Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);

            agenda_welcome.expand = true;

            Gtk.Box scrolled_panel = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            scrolled_panel.pack_start(description_view, false, true, 0);
            scrolled_panel.pack_start(task_view, true, true, 0);
            scrolled_panel.pack_start (agenda_welcome, true, true, 0);

            scrolled_window.add (scrolled_panel);

            layout = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            layout.pack_start (search_revealer, false, true, 0);
            layout.pack_start (scrolled_window, true, true, 0);
            layout.pack_start (task_entry, false, true, 0);
            this.add (layout);

            task_entry.margin_start = 10;
            task_entry.margin_end = 10;
            task_entry.margin_top = 10;
            task_entry.margin_bottom = 10;
            search_revealer.show();

            task_entry.grab_focus ();
            task_view.taskview_activated.connect(save_vertical_scroll);
            
            task_view.focus_in_event.connect((w,e) => {
                restore_vertical_scroll();
                return false;
            });

            task_view.text_editing_started.connect(() => {
                Timeout.add (1, () => {
                    restore_vertical_scroll();
                    return false;
                });                  
            });
        }

        private double vertical_scroll = 0;

        private void save_vertical_scroll() {
            vertical_scroll = scrolled_window.vadjustment.value;
        }

        private void restore_vertical_scroll() {
            scrolled_window.vadjustment.value = vertical_scroll;
        }

        public void update_task(Task task) {
            if (openTask.id == task.id) {
                if(openTask.title != task.title) {
                    openTask.title = task.title;
                    this.set_title(task.title);
                }
                if(openTask.description != task.description){
                    openTask.description = task.description;
                    update();
                }
            }
            task_list.update_task(task);
        }

        public void remove_accelerators_copy () {
            app.set_accels_for_action ("win.cut", {});
            app.set_accels_for_action ("win.copy", {});
            app.set_accels_for_action ("win.paste", {});
            app.set_accels_for_action ("win.link", {});
        }

        public void add_accelerators_copy () {
            app.set_accels_for_action ("win.cut", {"<Ctrl>X"});
            app.set_accels_for_action ("win.copy", {"<Ctrl>C"});
            app.set_accels_for_action ("win.paste", {"<Ctrl>V"});
            app.set_accels_for_action ("win.link", {"<Ctrl>L"});
        }

        public void back_to_parent(){
            Task task = stack.pop();
            if (task.id == SEARCH_TASK.id)
                disable_search();
            task_list.clear_tasks();
            load_list();
        }

        private void search_tasks () {            
            task_list.clear_tasks();
            remove_search_on_stack();
            stack.push(SEARCH_TASK);
            load_list();
        }

        private void remove_search_on_stack () {
            Stack inverse = new Stack();
            while(!stack.is_empty())
                inverse.push(stack.pop());

            while(!inverse.is_empty()){
                Task task = inverse.pop();
                if (task.id == SEARCH_TASK.id)
                    break;
                stack.push(task);
            }
        }

        private void copy_tasks(){
            prepare_clipboard(Agenda.PasteMode.CLONE);
            
            var external_clipboard = Gtk.Clipboard.get_default (Gdk.Display.get_default ());
            string text = "";
            foreach (Task task in Agenda.clipboard){
                text += task.title + "\n";
            }
            external_clipboard.set_text (text, text.length - 1);
        }

        public void prepare_clipboard (Agenda.PasteMode mode) {
            Agenda.clipboard = task_view.getSeletedTasks();
            Agenda.paste_mode = mode;
            Agenda.copy_source = openTask;
        }

        public void paste_tasks () {
            if (Agenda.clipboard.length > 0) {
                int position = task_view.get_selected_index() + 1;

                if (Agenda.paste_mode == Agenda.PasteMode.CLONE) {
                    cloneMap = new HashMap<int, Task>();
                    Agenda.clipboard = clone_tasks(openTask, Agenda.clipboard);
                }

                append_clipboard_at_position(position);

                if (Agenda.paste_mode == Agenda.PasteMode.MOVE) 
                    reorder_copy_source();
                
                emit_refresh_window(openTask);
                refresh_task();
                task_view.set_selected_tasks(Agenda.clipboard);
                Agenda.clipboard = {};
            }
            else {
                var external_clipboard = Gtk.Clipboard.get_for_display (Gdk.Display.get_default (),
                Gdk.SELECTION_CLIPBOARD);
                string tasks = external_clipboard.wait_for_text ();
                create_tasks_from_string(tasks);
            }
        }

        public void refresh_task() {
            task_list.clear_tasks();
            stack.pop();
            task_list.open_task(openTask);
        }

        private bool contains_ascending(Task task, Task possible_ascendant){
            int[] parent_ids = get_ascending_ids(task);
            foreach (int id in parent_ids){
                if(possible_ascendant.id == id)
                    return true;
            }
            return false;
        }

        private int[] get_ascending_ids(Task task){
            int[] ids = {};
            ids += task.id;
            //  Task tarefa = backend.find(task.id);
            //  while(tarefa.parent_id > 0) {
            //      ids += tarefa.id;
            //      tarefa = backend.find(tarefa.parent_id);
            //  }
            return ids;
        }

        private HashMap<int, Task> cloneMap;

        private Task[] clone_tasks(Task parent, Task[] tasks) {
            Task[] clone_subtasks = {};
            foreach(Task task in tasks) {
                Task clone;
                if (cloneMap.has_key(task.id)) {
                    clone = cloneMap.get(task.id);
                    backend.create_link(clone, parent);
                }
                else {
                    clone = create_clone(task, parent);
                    cloneMap.set(task.id, clone);
                    Task[] subtasks = backend.list(task);
                    clone_tasks(clone, subtasks);
                }
                clone_subtasks += clone;
            }
            return clone_subtasks;
        }

        private Task create_clone(Task task, Task parent){
            Task clone = new Task();
            clone.title = task.title;
            clone.description = task.description;
            clone.complete = false;
            backend.create(clone, parent);
            return clone;
        }

        private void append_clipboard_at_position(int position){
            if (contains_ascending(openTask, Agenda.clipboard[0]))
                return; 

            int index = 1;
            foreach (Task task in task_list.get_all_tasks()){
                if (index >= position){
                    task.position = index + Agenda.clipboard.length;
                    backend.reorder(task, openTask);
                }
                index++;
            }     
                   
            index = position;
            foreach (Task task in Agenda.clipboard) {
                switch(Agenda.paste_mode) {
                    case Agenda.PasteMode.MOVE:                    
                        backend.changeParent(task, Agenda.copy_source, openTask);
                        break;
                    case Agenda.PasteMode.LINK:                    
                        backend.create_link(task, openTask);
                        break;
                }
                task.position = index++;
                backend.reorder(task, openTask);
            }
        }

        private void reorder_copy_source() {
            Task[] sourcelist = backend.list (Agenda.copy_source);
            int position = 1;
            foreach (Task task in sourcelist) {
                task.position = position++;
                backend.reorder(task, Agenda.copy_source);
            }
            emit_refresh_window(Agenda.copy_source);
        }

        public void append_task () {
            create_tasks_from_string(task_entry.text);
        }

        private void create_tasks_from_string(string tasks){
            string[] lines = tasks.split("\n");
            foreach(string line in lines){
                Task task = new Task.with_attributes (
                    -1,
                    false,
                    line);
                create_task(task);
            }
        }

        public void create_task(Task task){
            backend.create(task, openTask);
            history_list.add_item (task.title);
            task_entry.text = "";
            broadcast_task(task, openTask);
        }

        public void create_task_view(Task task) {
            task_list.append_task (task);
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
            save_state();
            on_quit(this);
            this.destroy ();

            return true;
        }

        public void save_state () {
            Agenda.settings.set_value ("window-position", new int[] { xpos, ypos });
            Agenda.settings.set_value ("window-size", new int[] { rect.width, rect.height });
            backend.writeStack(stack);
        }

        public bool button_down_event(Gdk.EventButton e){
            if(e.button == 8 && backButton.get_sensitive()){ // mouse backforward
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
                    if (!(task_entry.has_focus || task_view.is_editing || description_view.has_focus)) {
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

            if (openTask.hasDescription() && openTask != SEARCH_TASK){
                description_view.show();
                description_menuitem.hide();
                description_view.buffer.text = openTask.description;
            }
            else {
                description_view.hide();
                description_menuitem.show();           
            }

            if (openTask.id == SEARCH_TASK.id && showingTaskEntry) {
                task_entry.hide();
                showingTaskEntry = false;
                task_view.reorderable = false;
            }
            else {
                task_entry.show();
                showingTaskEntry = true;
                task_view.reorderable = true;
            }
                
        }

        void show_welcome () {
            agenda_welcome.show ();
            
        }

        void hide_welcome () {
            agenda_welcome.hide ();
        }

        public override bool configure_event (Gdk.EventConfigure event) {
            if (configure_id != 0) {
                GLib.Source.remove (configure_id);
            }

            configure_id = Timeout.add (100, () => {
                configure_id = 0;

                get_position (out xpos, out ypos);
                get_allocation (out rect);

                return false;
            });

            return base.configure_event (event);
        }
    }
}
