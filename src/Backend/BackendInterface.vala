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
    public interface Backend : GLib.Object {
        public abstract Task[] list (Task openTask);
        public abstract Task find (int id);
        public abstract void create (Task task);
        public abstract void update (Task task);
        public abstract void drop (Task task);
        public abstract void mark (Task task);
        public abstract void reorder (Task task);
    }
}
