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
using Sqlite;
namespace Agenda {
    public class FileBackend : GLib.Object, Backend {

        private Sqlite.Database database;
        private Sqlite.Statement insertStatement;
        private Sqlite.Statement selectStatement;
        private Sqlite.Statement findStatement;
        private Sqlite.Statement updateStatement;
        private Sqlite.Statement markStatement;
        private Sqlite.Statement reorderStatement;
        private Sqlite.Statement deleteStatement;

        public FileBackend () {
            string user_data = Environment.get_user_data_dir ();

            File dir = File.new_for_path (user_data).get_child ("agenda");

            try {
                dir.make_directory_with_parents ();
            } catch (Error e) {
                if (e is IOError.EXISTS) {
                    info ("%s", e.message);
                } else {
                    error ("Could not access or create directory '%s'.",
                           dir.get_path ());
                }
            }

            File databaseFile = dir.get_child ("tasks.db");

            // Open a database:
            int ec = Sqlite.Database.open (databaseFile.get_path (), out database);
            if (ec != Sqlite.OK) {
                stderr.printf ("Can't open database: %d: %s\n", database.errcode (), database.errmsg ());
                return ;
            }

            string errorMessage;
            string query = "CREATE TABLE IF NOT EXISTS tasks (id int PRIMARY KEY, description text, completed_at text, created_at text, updated_at text, deleted_at text, parent_id int, position int);";
            ec = database.exec (query, null, out errorMessage);
            if (ec != Sqlite.OK) {
                stderr.printf ("Error: %s\n", errorMessage);
                return;
	        }

            query = "INSERT INTO tasks (id, description, created_at, updated_at, parent_id, position) VALUES ($id, $description, $created_at, $updated_at, $parent_id, $position)";
            ec = database.prepare_v2 (query, query.length, out insertStatement);
            if (ec != Sqlite.OK) {
                stderr.printf ("Error: %d: %s\n", database.errcode (), database.errmsg ());
                return ;
            }

            query = "update tasks set description=$description, updated_at=$updated_at where id=$id";
            ec = database.prepare_v2 (query, query.length, out updateStatement);
            if (ec != Sqlite.OK) {
                stderr.printf ("Error: %d: %s\n", database.errcode (), database.errmsg ());
                return ;
            }

            query = "update tasks set updated_at = $updated_at, deleted_at = $deleted_at where id=$id";
            ec = database.prepare_v2 (query, query.length, out deleteStatement);
            if (ec != Sqlite.OK) {
                stderr.printf ("Error: %d: %s\n", database.errcode (), database.errmsg ());
                return ;
            }

            query = "update tasks set updated_at = $updated_at, completed_at = $completed_at where id=$id";
            ec = database.prepare_v2 (query, query.length, out markStatement);
            if (ec != Sqlite.OK) {
                stderr.printf ("Error: %d: %s\n", database.errcode (), database.errmsg ());
                return ;
            }

            query = "update tasks set position = $position, updated_at = $updated_at where id=$id";
            ec = database.prepare_v2 (query, query.length, out reorderStatement);
            if (ec != Sqlite.OK) {
                stderr.printf ("Error: %d: %s\n", database.errcode (), database.errmsg ());
                return ;
            }

            query = "select id, description, completed_at, parent_id, position from tasks where deleted_at is null order by position asc";
            ec = database.prepare_v2 (query, query.length, out selectStatement);
            if (ec != Sqlite.OK) {
                stderr.printf ("Error: %d: %s\n", database.errcode (), database.errmsg ());
                return ;
            }

            query = "select * from tasks where id = $id";
            ec = database.prepare_v2 (query, query.length, out findStatement);
            if (ec != Sqlite.OK) {
                stderr.printf ("Error: %d: %s\n", database.errcode (), database.errmsg ());
                return ;
            }
        }

        public Task[] list () {
            Task[] tasks = {};
            while (selectStatement.step () == Sqlite.ROW) {
                Task task = new Task ();
                task.id =  selectStatement.column_int (0);
                task.text =  selectStatement.column_text (1);
                task.complete = selectStatement.column_text (2) != null;
                task.parent_id =  selectStatement.column_int (3);
                task.position =  selectStatement.column_int (4);
                tasks += task;
            }
            return tasks;
        }

        public void drop (Task task){
            string datetime = new DateTime.now_local ().to_string();
            deleteStatement.bind_text (1, datetime);
            deleteStatement.bind_text (2, datetime);
            deleteStatement.bind_int (3, task.id);
            deleteStatement.step();
            deleteStatement.reset ();
        }

        public void create (Task task){
            string datetime = new DateTime.now_local ().to_string();
            insertStatement.bind_int (1, task.id);
            insertStatement.bind_text (2, task.text);
            insertStatement.bind_text (3, datetime);
            insertStatement.bind_text (4, datetime);
            insertStatement.bind_int (5, task.parent_id);
            insertStatement.bind_int (6, task.position);
            insertStatement.step ();
            insertStatement.reset ();
        }

        public void update(Task task){
            string datetime = new DateTime.now_local ().to_string();
            updateStatement.bind_text (1, task.text);
            updateStatement.bind_text (2, datetime);
            updateStatement.bind_int (3, task.id);
            updateStatement.step ();
            updateStatement.reset ();
        }

        public void mark(Task task){
            string datetime = new DateTime.now_local ().to_string();
            markStatement.bind_text (1, task.complete? datetime: null);
            markStatement.bind_text (2, datetime);
            markStatement.bind_int (3, task.id);
            markStatement.step ();
            markStatement.reset ();
        }

        public void reorder(Task task){
            string datetime = new DateTime.now_local ().to_string();
            reorderStatement.bind_int (1, task.position);
            reorderStatement.bind_text (2, datetime);
            reorderStatement.bind_int (3, task.id);
            reorderStatement.step ();
            reorderStatement.reset ();
        }

    }
}
