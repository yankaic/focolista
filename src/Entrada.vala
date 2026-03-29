namespace Agenda {

    public class Entrada : Gtk.Box {

        private Gtk.Button add_button;
        private Gtk.Entry input;
        private Gtk.EventBox spacer;        

        public Entrada () {
            // Configuração do VBox
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);

            // Botão
            add_button = new Gtk.Button.with_label("＋  Adicionar nova tarefa");
            add_button.hexpand = true;
            add_button.halign = Gtk.Align.FILL;
            add_button.get_style_context().add_class("flat");
            add_button.set_alignment(0.0f, 0.5f);
            add_button.margin_top = 2;
            add_button.margin_start = 6;
            add_button.margin_end = 6;
            add_button.margin_bottom = 6;
            add_button.get_style_context().add_class("accent-text");
            add_button.set_size_request(-1, 40);
            // Campo de entrada
            input = new Gtk.Entry();
            input.hexpand = true;
            input.halign = Gtk.Align.FILL;
            input.margin_top = 8;
            input.margin_start = 8;
            input.margin_end = 8;
            input.get_style_context().add_class("task-entry");

            // Adiciona ao container
            this.pack_start(add_button, false, false, 0);
            this.pack_start(input, false, false, 0);

            // Estado inicial
            input.hide();

            // Evento de clique no botão
            add_button.clicked.connect(() => {
                show_entry();
            });

            // Evento de perda de foco
            input.focus_out_event.connect((event) => {
                show_button();
                return false;
            });

            // Evento de tecla (ESC)
            input.key_press_event.connect((event) => {
                if (event.keyval == Gdk.Key.Escape) {
                    show_button();
                    return true;
                }
                return false;
            });

            // Área clicável vazia
            spacer = new Gtk.EventBox();

            spacer.set_size_request(-1, 10);
            spacer.hexpand = true;
            spacer.vexpand = true;
            spacer.can_focus = true;

            // Adiciona ao final ocupando espaço restante
            this.pack_start(spacer, true, true, 0);
            spacer.button_press_event.connect((event) => {
                // Força perda de foco do Entry
                spacer.grab_focus();
                return false;
            });
        }

        public void show_entry() {
            add_button.hide();
            input.show();
            input.grab_focus();
        }

        public void show_button() {
            input.hide();
            add_button.show();
        }
    }
}
