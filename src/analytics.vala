/* analytics.vala
 *
 * Copyright 2022 JCWasmx86 <JCWasmx86@t-online.de>
 *
 * This file is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation; either version 3 of the
 * License, or (at your option) any later version.
 *
 * This file is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * SPDX-License-Identifier: LGPL-3.0-or-later
 */
class Vls.Analytics {
    public string label;
    public uint64 count;
    // Microseconds
    public double total_execution_time;

    public Analytics (string label) {
        this.label = label;
    }

    public void add_measurement (double microseconds) requires (microseconds >= 0) {
        this.count++;
        this.total_execution_time += microseconds;
    }
    public double average () {
        return this.total_execution_time / this.count;
    }
}
