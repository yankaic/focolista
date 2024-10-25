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
    public class SqliteBackend : GLib.Object, Backend {

        private Sqlite.Database database;
        private Sqlite.Statement insertStatement;
        private Sqlite.Statement insertConnectionStatement;
        private Sqlite.Statement selectStatement;
        private Sqlite.Statement searchStatement;
        private Sqlite.Statement findStatement;
        private Sqlite.Statement updateStatement;
        private Sqlite.Statement updateDescriptionStatement;
        private Sqlite.Statement markStatement;
        private Sqlite.Statement reorderStatement;
        private Sqlite.Statement deleteStatement;
        private Sqlite.Statement moveStatement;
        private Sqlite.Statement sequenceStatement;

        private Sqlite.Statement readStackStatement;
        private Sqlite.Statement clearStackStatement;
        private Sqlite.Statement putStackStatement;

        public SqliteBackend () {
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

            string errorMessage, query;
            
            int ec = Sqlite.Database.open (databaseFile.get_path (), out database);
            if (ec != Sqlite.OK) {
                stderr.printf ("Can't open database: %d: %s\n", database.errcode (), database.errmsg ());
                return ;
            }

            query = "select id from tasks where id = 1;";
            ec = database.exec (query, null, out errorMessage);
            if (ec != Sqlite.OK) {
                query = """
                    CREATE TABLE tasks (id int PRIMARY KEY, title text, completed_at text, created_at text, updated_at text, description text);

                    CREATE TABLE "stack" (
                    id int primary key not null,
                        task_id int not null,
                        foreign key(task_id) references tasks(id)
                    );
                    
                    CREATE TABLE edge (
                    parent_id int not null,
                    child_id int not null,
                    position int not null,
                    updated_at text,
                    deleted_at text,
                    foreign key(parent_id) references tasks(id),
                    foreign key(child_id) references tasks(id)
                    );
                    
                    insert into tasks (id,title,completed_at,created_at,updated_at,description) values
                    (1,'Tarefas',NULL,NULL,NULL,NULL),
                    (-1,'Pesquisa',NULL,NULL,NULL,'');
                    
                    insert into stack (id,task_id) values
                    (1,1);
                """;
    
                database.exec (query, null, out errorMessage);
                print("Database created\n");
	        }

            query = "INSERT INTO tasks (id, title, description, completed_at, created_at, updated_at) VALUES ($id, $title, $description, $completed_at, $created_at, $updated_at)";
            database.prepare_v2 (query, query.length, out insertStatement);

            query = "INSERT INTO edge (parent_id, child_id, position, updated_at) VALUES ($parent_id, $child_id, $position, $updated_at)";
            database.prepare_v2 (query, query.length, out insertConnectionStatement);

            query = "update tasks set title=$title, updated_at=$updated_at where id=$id";
            database.prepare_v2 (query, query.length, out updateStatement);

            query = "update tasks set description=$description, updated_at=$updated_at where id=$id";
            database.prepare_v2 (query, query.length, out updateDescriptionStatement);

            query = "update edge set updated_at = $updated_at, deleted_at = $deleted_at where parent_id = $parent_id and child_id = $child_id";
            database.prepare_v2 (query, query.length, out deleteStatement);

            query = "update tasks set completed_at = $completed_at, updated_at = $updated_at where id=$id";
            database.prepare_v2 (query, query.length, out markStatement);

            query = "update edge set position = $position, updated_at = $updated_at where parent_id = $parent_id and child_id = $child_id";
            database.prepare_v2 (query, query.length, out reorderStatement);

            query = "select task.id, task.title, task.description, task.completed_at, parent_connection.position as position, count (child_task.completed_at) as completed_count, COUNT(child_task.id) as subtasks_count from tasks task left join edge parent_connection on parent_connection.child_id = task.id and parent_connection.deleted_at is null left join edge child_connection on child_connection.parent_id = task.id and child_connection.deleted_at is null left join tasks child_task on child_connection.child_id = child_task.id where parent_connection.parent_id = $parentId GROUP by task.id ORDER by parent_connection.position";
            database.prepare_v2 (query, query.length, out selectStatement);

            query = "select task.id, task.title, task.description, task.completed_at, parent_connection.position as position, count (child_task.completed_at) as completed_count, COUNT(child_task.id) as subtasks_count from tasks task join edge parent_connection on parent_connection.child_id = task.id and parent_connection.deleted_at is null left join edge child_connection on child_connection.parent_id = task.id and child_connection.deleted_at is null left join tasks child_task on child_connection.child_id = child_task.id where task.title like $search GROUP by task.id ORDER by task.id asc";
            database.prepare_v2 (query, query.length, out searchStatement);

            query = "select id, title, description, completed_at from tasks where id = $id";
            database.prepare_v2 (query, query.length, out findStatement);

            query = "update edge set parent_id = $new_parent_id, position = $position, updated_at = $datetime where child_id = $id and parent_id = $parent_id";
            database.prepare_v2 (query, query.length, out moveStatement);

            query = "delete from stack";
            database.prepare_v2 (query, query.length, out clearStackStatement);

            query = "select task_id from stack order by id";
            database.prepare_v2 (query, query.length, out readStackStatement);

            query = "insert into stack values ((select count (id) + 1 from stack), $id)";
            database.prepare_v2 (query, query.length, out putStackStatement);

            query = "select max(id) + 1 from tasks";
            database.prepare_v2 (query, query.length, out sequenceStatement);
        }

        public Task[] list (Task parent) {
            selectStatement.bind_int (1, parent.id);
            return load_tasks(selectStatement);
        }

        public Task[] search(string text){
            string search = "%" + text + "%";
            searchStatement.bind_text(1, search);
            return load_tasks(searchStatement);
        }

        private Task[] load_tasks(Sqlite.Statement statement){
            Task[] tasks = {};
            int completed, count;
            while (statement.step () == Sqlite.ROW) {
                Task task = new Task ();
                task.id =  statement.column_int (0);
                task.title =  statement.column_text (1);
                task.description =  statement.column_text (2);
                task.complete = statement.column_text (3) != null;
                task.position =  statement.column_int (4);
                completed = statement.column_int (5);
                count = statement.column_int (6);
                task.subinfo = count > 0 ? "(" + completed.to_string() + "/" + count.to_string() + ")": "";
                task.subtasksCount = count;
                tasks += task;
            }
            statement.reset ();
            return tasks;
        }

        public Task find (int id){
            Task task = new Task ();
            findStatement.bind_int (1, id);
            findStatement.step();
            task.id = findStatement.column_int (0);
            task.title = findStatement.column_text (1);
            task.description = findStatement.column_text (2);
            task.complete = findStatement.column_text (3) != null;
                   
            findStatement.reset ();
            return task;
        }

        public void drop (Task task, Task parent){
            string datetime = new DateTime.now_local ().to_string();
            parent.subtasksCount--;
            deleteStatement.bind_text (1, datetime);
            deleteStatement.bind_text (2, datetime);
            deleteStatement.bind_int (3, parent.id);
            deleteStatement.bind_int (4, task.id);
            deleteStatement.step();
            deleteStatement.reset ();
        }

        public void create (Task task, Task parent){
            string datetime = new DateTime.now_local ().to_string();
            parent.subtasksCount++;

            sequenceStatement.step();
            task.id = sequenceStatement.column_int (0);
            sequenceStatement.reset();

            insertStatement.bind_int (1, task.id);
            insertStatement.bind_text (2, task.title);
            insertStatement.bind_text (3, task.description);
            insertStatement.bind_text (4, task.complete? datetime : null);
            insertStatement.bind_text (5, datetime);
            insertStatement.bind_text (6, datetime);
            insertStatement.step ();
            insertStatement.reset ();

            insertConnectionStatement.bind_int (1, parent.id);
            insertConnectionStatement.bind_int (2, task.id);
            insertConnectionStatement.bind_int (3, parent.subtasksCount);
            insertConnectionStatement.bind_text (4, datetime);
            insertConnectionStatement.step ();
            insertConnectionStatement.reset ();
        }

        public void update(Task task){
            string datetime = new DateTime.now_local ().to_string();
            updateStatement.bind_text (1, task.title);
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

        public void reorder(Task task, Task parent){
            string datetime = new DateTime.now_local ().to_string();
            reorderStatement.bind_int (1, task.position);
            reorderStatement.bind_text (2, datetime);
            reorderStatement.bind_int (3, parent.id);
            reorderStatement.bind_int (4, task.id);
            reorderStatement.step ();
            reorderStatement.reset ();
        }

        public void changeParent(Task task, Task old_parent, Task new_parent) {
            string datetime = new DateTime.now_local ().to_string();
            old_parent.subtasksCount--;
            new_parent.subtasksCount++;
            moveStatement.bind_int (1, new_parent.id);
            moveStatement.bind_int (2, new_parent.subtasksCount);
            moveStatement.bind_text (3, datetime);
            moveStatement.bind_int (4, task.id);
            moveStatement.bind_int (5, old_parent.id);
            moveStatement.step ();
            moveStatement.reset ();
        }

        public void create_link (Task task, Task new_parent) {
            new_parent.subtasksCount++;
            string datetime = new DateTime.now_local ().to_string();
            insertConnectionStatement.bind_int (1, new_parent.id);
            insertConnectionStatement.bind_int (2, task.id);
            insertConnectionStatement.bind_int (3, new_parent.subtasksCount);
            insertConnectionStatement.bind_text (4, datetime);
            insertConnectionStatement.step ();
            insertConnectionStatement.reset ();
        }

        public Stack<Task> readStack () {
            Stack<Task> stack = new Stack<Task>();
            while (readStackStatement.step () == Sqlite.ROW) {
                Task task = new Task ();
                task.id =  readStackStatement.column_int (0);
                stack.push(task);
            }
            readStackStatement.reset ();
            return stack;
        }
        
        public void writeStack (Stack<Task> stack){
            Stack<Task> inverse = new Stack<Task>();
            while(!stack.is_empty())
                inverse.push(stack.pop());
            
            clearStackStatement.step();
            clearStackStatement.reset();

            while(!inverse.is_empty()){
                Task task = inverse.pop();
                stack.push(task);
                store_in_stack(task);
            }
        }

        private void store_in_stack (Task task) {
            putStackStatement.bind_int(1, task.id);            
            putStackStatement.step();
            putStackStatement.reset();
        }

        private bool waiting_one_second = false;

        public void modify_description(Task task) {
            if (!waiting_one_second) {
                waiting_one_second = true;
                Timeout.add (1000, () => {
                    string datetime = new DateTime.now_local ().to_string();
                    updateDescriptionStatement.bind_text (1, task.description);
                    updateDescriptionStatement.bind_text (2, datetime);
                    updateDescriptionStatement.bind_int (3, task.id);
                    updateDescriptionStatement.step ();
                    updateDescriptionStatement.reset ();
                    waiting_one_second = false;
                    return false;
                });
            }            
        }
    }
}
