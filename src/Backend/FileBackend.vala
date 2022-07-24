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
        private Sqlite.Statement insertConnectionStatement;
        private Sqlite.Statement selectStatement;
        private Sqlite.Statement findStatement;
        private Sqlite.Statement updateStatement;
        private Sqlite.Statement markStatement;
        private Sqlite.Statement reorderStatement;
        private Sqlite.Statement deleteStatement;
        private Sqlite.Statement moveStatement;

        private Sqlite.Statement headStackStatement;
        private Sqlite.Statement popStackStatement;
        private Sqlite.Statement putStackStatement;

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

            query = "INSERT INTO tasks (id, description, completed_at, created_at, updated_at) VALUES ($id, $description, $completed_at, $created_at, $updated_at)";
            database.prepare_v2 (query, query.length, out insertStatement);

            query = "INSERT INTO edge (parent_id, child_id, position, updated_at) VALUES ($parent_id, $child_id, $position, $updated_at)";
            database.prepare_v2 (query, query.length, out insertConnectionStatement);

            query = "update tasks set description=$description, updated_at=$updated_at where id=$id";
            database.prepare_v2 (query, query.length, out updateStatement);

            query = "update edge set updated_at = $updated_at, deleted_at = $deleted_at where parent_id = $parent_id and child_id = $child_id";
            database.prepare_v2 (query, query.length, out deleteStatement);

            query = "update tasks set completed_at = $completed_at, updated_at = $updated_at where id=$id";
            database.prepare_v2 (query, query.length, out markStatement);

            query = "update edge set position = $position, updated_at = $updated_at where parent_id = $parent_id and child_id = $child_id";
            database.prepare_v2 (query, query.length, out reorderStatement);

            query = "select * from summary where parent_id = $id";
            database.prepare_v2 (query, query.length, out selectStatement);

            query = "select * from summary where id = $id and (parent_id = $parent_id or parent_id is null)";
            database.prepare_v2 (query, query.length, out findStatement);

            query = "update edge set parent_id = $parent_id, position = $position, updated_at = $datetime where child_id = $id";
            database.prepare_v2 (query, query.length, out moveStatement);

            query = "select task_id, parent_id from stack order by id desc limit 1";
            database.prepare_v2 (query, query.length, out headStackStatement);

            query = "delete from stack where id = (select id from stack order by id desc limit 1)";
            database.prepare_v2 (query, query.length, out popStackStatement);

            query = "insert into stack values ((select count (id) + 1 from stack), $task_id, $parent_id)";
            database.prepare_v2 (query, query.length, out putStackStatement);
        }

        public Task[] list (int parent_id) {
            Task[] tasks = {};
            int completed, count;
            selectStatement.bind_int (1, parent_id);
            while (selectStatement.step () == Sqlite.ROW) {
                Task task = new Task ();
                task.id =  selectStatement.column_int (0);
                task.text =  selectStatement.column_text (1);
                task.complete = selectStatement.column_text (2) != null;
                task.parent_id =  selectStatement.column_int (3);
                task.position =  selectStatement.column_int (4);
                completed = selectStatement.column_int (5);
                count = selectStatement.column_int (6);
                task.subinfo = count > 0 ? "(" + completed.to_string() + "/" + count.to_string() + ")": "";
                task.subtasksCount = count;
                tasks += task;
            }
            selectStatement.reset ();
            return tasks;
        }

        public Task find (int id, int parent_id){
            Task task = new Task ();
            findStatement.bind_int (1, id);
            findStatement.bind_int (2, parent_id);

            if(findStatement.step() == Sqlite.ROW){
                task.id = findStatement.column_int (0);
                task.text = findStatement.column_text (1);
                task.complete = findStatement.column_text (2) != null;
                task.parent_id = findStatement.column_int (3);
                task.position = findStatement.column_int (4);
                int completed = findStatement.column_int (5);
                int count = findStatement.column_int (6);
                task.subinfo = "(" + completed.to_string() + "/" + count.to_string() + ")";
                task.subtasksCount = count;
            }
            else{
                findStatement.reset ();
                findStatement.bind_int (0, 1);
                findStatement.step();

                task.id = findStatement.column_int (0);
                task.text = findStatement.column_text (1);
                task.complete = findStatement.column_text (2) != null;
                task.parent_id = findStatement.column_int (3);
                task.position = findStatement.column_int (4);
            }            
            findStatement.reset ();
            return task;
        }

        public void drop (Task task){
            string datetime = new DateTime.now_local ().to_string();
            deleteStatement.bind_text (1, datetime);
            deleteStatement.bind_text (2, datetime);
            deleteStatement.bind_int (3, task.parent_id);
            deleteStatement.bind_int (4, task.id);
            deleteStatement.step();
            deleteStatement.reset ();
        }

        public void create (Task task){
            string datetime = new DateTime.now_local ().to_string();
            insertStatement.bind_int (1, task.id);
            insertStatement.bind_text (2, task.text);
            insertStatement.bind_text (3, task.complete? datetime : null);
            insertStatement.bind_text (4, datetime);
            insertStatement.bind_text (5, datetime);
            insertStatement.step ();
            insertStatement.reset ();

            insertConnectionStatement.bind_int (1, task.parent_id);
            insertConnectionStatement.bind_int (2, task.id);
            insertConnectionStatement.bind_int (3, task.position);
            insertConnectionStatement.bind_text (4, datetime);
            insertConnectionStatement.step ();
            insertConnectionStatement.reset ();
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
            reorderStatement.bind_int (3, task.parent_id);
            reorderStatement.bind_int (4, task.id);
            reorderStatement.step ();
            reorderStatement.reset ();
        }

        public void changeParent(Task task) {
            string datetime = new DateTime.now_local ().to_string();
            moveStatement.bind_int (1, task.parent_id);
            moveStatement.bind_int (2, task.position);
            moveStatement.bind_text (3,  datetime);
            moveStatement.bind_int (4, task.id);
            moveStatement.step ();
            moveStatement.reset ();
        }

        public Task getHeadStack () {
            int id, parent_id;
            headStackStatement.step();
            id = headStackStatement.column_int (0);
            parent_id = headStackStatement.column_int (1);
            headStackStatement.reset();
            return find(id, parent_id);
        }

        public Task popStack () {
            Task task = getHeadStack();
            popStackStatement.step();
            popStackStatement.reset();
            return task;            
        }

        public void putStack (Task task) {
            putStackStatement.bind_int(1, task.id);
            putStackStatement.bind_int(2, task.parent_id);
            putStackStatement.step();
            putStackStatement.reset();
        }
    }
}
