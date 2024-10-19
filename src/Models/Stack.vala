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

    public class Stack<T> {
        private T[] list;

        public Stack () {
            list = {};
        }

        public T? pop() {
            T task  = peek();
            list = list[0 : list.length - 1];
            return task;
        }

        public void push(T task) {
            list += task;
        }

        public T? peek () {
            return list[list.length - 1 : list.length][0];
        }

        public int size () {
            return list.length;
        }

        public bool is_empty() {
            return list.length == 0;
        }
    }
}
