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

    public class Task : GLib.Object {
        public int id { get; set; default = 0; }
        public bool complete { get; set; default = false; }
        public string title { get; set; default = ""; }
        public string description { get; set; default = ""; }
        public int position { get; set; default = 0; }
        public string subinfo { get; set; default = ""; }
        public int subtasksCount { get; set; default = 0; }

        public Task () {
        }

        public Task.with_attributes (int id, bool complete, string title) {
            Object (
                id: id,
                complete: complete,
                title: title);
        }

        public bool hasDescription(){
            return description != null && (description.replace (" ", "")).length > 0;
        }

        public string to_string () {
            string str = "id: ";

            str += id.to_string();
            str += ", title: ";
            str += title;
            str += " " + (complete ? " ✓": " ");

            return str;
        }
    }
}
