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

    public class Stack : GLib.Object {
        private Task[] tasks;

        public Stack () {
            tasks = {};
        }

        public Task pop() {
            Task task  = peek();
            tasks = tasks[0 : tasks.length - 1];
            return task;
        }

        public void push(Task task) {
            tasks += task;
        }

        public Task peek () {
            return tasks[tasks.length - 1 : tasks.length][0];
        }

        public int size () {
            return tasks.length;
        }

        public bool is_empty() {
            return tasks.length == 0;
        }
    }
}
